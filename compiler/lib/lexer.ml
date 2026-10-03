(* zfy 词法分析器：缩进系，产出 INDENT/DEDENT/Newline/Eof *)
open Tokens

exception LexError of pos * string

let err pos msg = raise (LexError (pos, msg))

type lexer = {
  src : string;
  mutable i : int;              (* 字节游标 *)
  mutable line : int;
  mutable col : int;
  mutable indents : int list;   (* 缩进栈，栈顶在前 *)
  mutable paren_depth : int;    (* 括号深度 > 0 时忽略换行与缩进 *)
  mutable at_line_start : bool; (* 当前是否处于行首缩进判定点 *)
}

let make src =
  { src; i = 0; line = 1; col = 1; indents = [ 0 ];
    paren_depth = 0; at_line_start = true }

let peek l k =
  let j = l.i + k in
  if j < String.length l.src then l.src.[j] else '\000'

let advance l n =
  for _ = 1 to n do
    if l.i < String.length l.src then begin
      if l.src.[l.i] = '\n' then begin
        l.line <- l.line + 1;
        l.col <- 1
      end
      else l.col <- l.col + 1;
      l.i <- l.i + 1
    end
  done

let is_digit c = c >= '0' && c <= '9'
let is_ident_start c =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_'
let is_ident_char c = is_ident_start c || is_digit c

let pos l = { line = l.line; col = l.col }

let punct2 =
  [ "==", Eq; "!=", Ne; "<=", Le; ">=", Ge;
    "+=", PlusAssign; "-=", MinusAssign; "*=", StarAssign; "/=", SlashAssign;
    "++", PlusPlus; "--", MinusMinus;
    "%=", PercentAssign;
    "=>", FatArrow; "->", ThinArrow ]

let punct1 =
  [ '(', LParen; ')', RParen; '[', LBracket; ']', RBracket; '{', LBrace;
    '}', RBrace; ',', Comma; ';', Semicolon; ':', Colon; '=', Assign;
    '+', Plus; '-', Minus; '*', Star; '/', Slash; '%', Percent; '<', Lt;
    '>', Gt; '.', Dot ]

(* ---------- 子扫描器 ---------- *)

(* 前置条件：游标在 '"' 上。返回字符串内容并消耗整个字面量 *)
let scan_string l =
  let pos0 = pos l in
  advance l 1;
  let buf = Buffer.create 16 in
  let rec go () =
    if l.i >= String.length l.src then
      err pos0 "未闭合的字符串字面量"
    else
      match l.src.[l.i] with
      | '"' -> advance l 1
      | '\\' ->
        let p = pos l in
        advance l 1;
        if l.i >= String.length l.src then err p "悬空的转义符";
        (match l.src.[l.i] with
         | 'n' -> Buffer.add_char buf '\n'; advance l 1
         | 't' -> Buffer.add_char buf '\t'; advance l 1
         | 'r' -> Buffer.add_char buf '\r'; advance l 1
         | '0' -> Buffer.add_char buf '\000'; advance l 1
         | 'a' -> Buffer.add_char buf '\007'; advance l 1
         | 'b' -> Buffer.add_char buf '\b'; advance l 1
         | 'f' -> Buffer.add_char buf '\012'; advance l 1
         | 'v' -> Buffer.add_char buf '\011'; advance l 1
         | '\\' -> Buffer.add_char buf '\\'; advance l 1
         | '"' -> Buffer.add_char buf '"'; advance l 1
         | '\'' -> Buffer.add_char buf '\''; advance l 1
         | c -> err p (Printf.sprintf "未知转义符 \\%c" c));
        go ()
      | '\n' -> err (pos l) "字符串字面量中不允许裸换行"
      | c -> Buffer.add_char buf c; advance l 1; go ()
  in
  go ();
  Buffer.contents buf

(* 前置条件：游标在 '\'' 上 *)
let scan_char l p0 =
  advance l 1;
  if l.i >= String.length l.src then err p0 "未闭合的字符字面量";
  let c =
    match l.src.[l.i] with
    | '\\' ->
      advance l 1;
      if l.i >= String.length l.src then err p0 "悬空的转义符";
      (match l.src.[l.i] with
       | 'n' -> '\n' | 't' -> '\t' | 'r' -> '\r' | '0' -> '\000'
       | 'a' -> '\007' | 'b' -> '\b' | 'f' -> '\012' | 'v' -> '\011'
       | '\\' -> '\\' | '\'' -> '\'' | '"' -> '"'
       | c -> err (pos l) (Printf.sprintf "未知转义符 \\%c" c))
    | c -> c
  in
  advance l 1;
  if l.i >= String.length l.src || l.src.[l.i] <> '\'' then
    err p0 "字符字面量必须以 ' 结尾";
  advance l 1;
  c

(* 数字：支持 123 0x1A 0b1010 1.5 1e-3；返回 token *)
let scan_number l =
  let p0 = pos l in
  let buf = Buffer.create 16 in
  let is_hex c =
    is_digit c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') in
  let base = ref 10 in
  if peek l 0 = '0' && (peek l 1 = 'x' || peek l 1 = 'X') then begin
    base := 16; advance l 2
  end
  else if peek l 0 = '0' && (peek l 1 = 'b' || peek l 1 = 'B') then begin
    base := 2; advance l 2
  end;
  let valid c =
    match !base with
    | 16 -> is_hex c | 2 -> c = '0' || c = '1' | _ -> is_digit c in
  let all_digits = ref false in
  while l.i < String.length l.src && valid l.src.[l.i] do
    Buffer.add_char buf l.src.[l.i]; advance l 1; all_digits := true
  done;
  if not !all_digits then err p0 "数字字面量缺少有效数位";
  let text = Buffer.contents buf in
  (* 检测浮点：小数点或指数（仅十进制） *)
  let is_float =
    !base = 10
    && ((peek l 0 = '.' && is_digit (peek l 1))
        || ((peek l 0 = 'e' || peek l 0 = 'E')
            && (is_digit (peek l 1)
                || ((peek l 1 = '+' || peek l 1 = '-') && is_digit (peek l 2)))))
  in
  if is_float then begin
    Buffer.add_char buf '.'; advance l 1;
    while l.i < String.length l.src && is_digit l.src.[l.i] do
      Buffer.add_char buf l.src.[l.i]; advance l 1
    done;
    (* 指数部分 *)
    if peek l 0 = 'e' || peek l 0 = 'E' then begin
      Buffer.add_char buf 'e'; advance l 1;
      if peek l 0 = '+' || peek l 0 = '-' then begin
        Buffer.add_char buf l.src.[l.i]; advance l 1
      end;
      while l.i < String.length l.src && is_digit l.src.[l.i] do
        Buffer.add_char buf l.src.[l.i]; advance l 1
      done
    end;
    (try FloatLit (float_of_string (Buffer.contents buf))
     with _ -> err p0 "非法的浮点字面量")
  end
  else begin
    match !base with
    | 16 ->
      (try IntLit (Int64.of_string ("0x" ^ text))
       with _ -> err p0 "十六进制字面量溢出 i64")
    | 2 ->
      (try IntLit (Int64.of_string ("0b" ^ text))
       with _ -> err p0 "二进制字面量溢出 i64")
    | _ ->
      (match Int64.of_string_opt text with
       | Some n -> IntLit n
       | None -> err p0 "整数字面量溢出 i64")
  end

(* ---------- 注释与空白 ---------- *)

(* 返回 true 表示这一行是空白/注释行（无 token） *)
let rec skip_line_noise l =
  (* 先吞掉本行行首空白，测量缩进在主循环做 *)
  if l.i >= String.length l.src then ()
  else
    match l.src.[l.i] with
    | ' ' | '\t' | '\r' -> advance l 1; skip_line_noise l
    | '/' when peek l 1 = '/' ->
      while l.i < String.length l.src && l.src.[l.i] <> '\n' do
        advance l 1
      done;
      skip_line_noise l
    | '/' when peek l 1 = '*' ->
      let p0 = pos l in
      let rec go depth =
        if l.i >= String.length l.src then err p0 "未闭合的块注释"
        else if l.src.[l.i] = '/' && peek l 1 = '*' then begin
          advance l 2; go (depth + 1)
        end
        else if l.src.[l.i] = '*' && peek l 1 = '/' then begin
          advance l 2;
          if depth > 1 then go (depth - 1)
        end
        else begin
          if l.src.[l.i] = '\n' then ();
          advance l 1; go depth
        end
      in
      go 0;
      skip_line_noise l
    | _ -> ()

(* ---------- 主入口 ---------- *)

let keyword_lookup s = List.assoc_opt s Tokens.keyword_table

let tokenize src =
  let l = make src in
  let acc = ref [] in
  let push tok p = acc := (tok, p) :: !acc in
  let rec loop () =
    if l.i >= String.length l.src then begin
      (* EOF：收尾所有未闭合缩进 *)
      (match List.rev !acc with
       | (Newline, _) :: _ | [] -> ()
       | _ -> push Newline (pos l));
      let rec close () =
        match l.indents with
        | 0 :: _ -> push Eof (pos l)
        | _ :: rest ->
          l.indents <- rest;
          push Dedent (pos l);
          close ()
        | [] -> assert false
      in
      close ()
    end
    else if l.at_line_start && l.paren_depth = 0 then begin
      (* 行首：测量缩进 *)
      let col0 = l.col in
      skip_line_noise l;
      if l.i >= String.length l.src then begin
        l.at_line_start <- true; loop ()
      end
      else if l.src.[l.i] = '\n' then begin
        (* 空行 *)
        advance l 1; l.at_line_start <- true; loop ()
      end
      else begin
        let indent = l.col - col0 in
        let top = List.hd l.indents in
        if indent > top then begin
          l.indents <- indent :: l.indents;
          push Indent (pos l)
        end
        else if indent < top then begin
          (* 弹栈至匹配；不匹配则报错 *)
          let rec pop () =
            match l.indents with
            | top' :: rest when top' > indent ->
              l.indents <- rest;
              push Dedent (pos l);
              (match l.indents with
               | top'' :: _ when top'' = indent -> ()
               | top'' :: _ when top'' < indent ->
                 err (pos l)
                   (Printf.sprintf "缩进不一致：期望 %d，得到 %d" top'' indent)
               | _ -> ());
              if List.hd l.indents <> indent then pop ()
            | _ -> ()
          in
          pop ()
        end;
        l.at_line_start <- false;
        loop ()
      end
    end
    else begin
      skip_line_noise l;
      if l.i >= String.length l.src then begin l.at_line_start <- true; loop () end
      else
        match l.src.[l.i] with
        | '\n' ->
          if l.paren_depth = 0 then begin
            (* 抑制连续换行 *)
            (match !acc with
             | (Newline, _) :: _ | (Indent, _) :: _ | (Dedent, _) :: _ -> ()
             | _ -> push Newline (pos l));
            l.at_line_start <- true
          end;
          advance l 1;
          loop ()
        | c when is_digit c ->
          push (scan_number l) (pos l); loop ()
        | '"' ->
          let p = pos l in
          push (StrLit (scan_string l)) p; loop ()
        | '\'' ->
          let p = pos l in
          push (CharLit (scan_char l p)) p; loop ()
        | c when is_ident_start c ->
          let p = pos l in
          let rec go acc =
            if l.i < String.length l.src && is_ident_char l.src.[l.i] then begin
              let ch = l.src.[l.i] in
              advance l 1;
              go (ch :: acc)
            end
            else acc
          in
          let cs = List.rev (go []) in
          let s = String.of_seq (List.to_seq cs) in
          (match keyword_lookup s with
           | Some k -> push (Keyword k) p
           | None -> push (Ident s) p);
          loop ()
        | _ ->
          (* 算符/标点 *)
          let two = String.sub l.src l.i (min 2 (String.length l.src - l.i)) in
          (match List.assoc_opt two punct2 with
           | Some t ->
             let p = pos l in
             advance l 2;
             (match t with
              | LParen | LBracket -> l.paren_depth <- l.paren_depth + 1
              | RParen | RBracket -> l.paren_depth <- max 0 (l.paren_depth - 1)
              | _ -> ());
             push t p
           | None ->
             (match List.assoc_opt l.src.[l.i] punct1 with
              | Some t ->
                let p = pos l in
                advance l 1;
                (match t with
                 | LParen | LBracket -> l.paren_depth <- l.paren_depth + 1
                 | RParen | RBracket -> l.paren_depth <- max 0 (l.paren_depth - 1)
                 | _ -> ());
                push t p
              | None ->
                let c = l.src.[l.i] in
                if c = '&' then
                  err (pos l) "'&'（引用）语法已删除"
                else if c = '?' then
                  err (pos l) "'?'（错误传播）语法已删除"
                else
                  err (pos l)
                    (Printf.sprintf "非法字符 '%c' (0x%02X)" c (Char.code c))));
          loop ()
    end
  in
  (try loop () with
   | LexError (p, m) -> err p m);
  List.rev !acc
