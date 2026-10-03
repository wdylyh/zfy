(* zfy 语法分析器：手写递归下降，基于缩进块 *)
open Tokens
open Ast

exception ParseError of pos * string

let err p msg = raise (ParseError (p, msg))

type parser = { mutable toks : (token * pos) list }

let make toks = { toks = toks }

let pos_of (t, p) = p
let peek p = match p.toks with [] -> (Eof, { line = 0; col = 0 }) | x :: _ -> x
let peek2 p = match p.toks with _ :: x :: _ -> x | _ -> (Eof, { line = 0; col = 0 })
let next p = match p.toks with [] -> (Eof, { line = 0; col = 0 }) | x :: r -> p.toks <- r; x

(* 跳过空行（Newline）；分号在语句位置非法（只允许出现在 for 头部） *)
let rec skip_trivia p =
  match peek p with
  | (Newline, _) -> ignore (next p); skip_trivia p
  | (Semicolon, sp) ->
    err sp "分号不允许出现在语句末尾（只允许在 for 头部使用）"
  | _ -> ()

let expect p t what =
  let (tk, tp) = peek p in
  if tk = t then ignore (next p)
  else
    err tp (Printf.sprintf "期望 %s（%s），得到 %s" what (pp_token t) (pp_token tk))

let expect_ident p what =
  let (tk, tp) = peek p in
  match tk with
  | Ident s -> ignore (next p); s
  | _ -> err tp (Printf.sprintf "期望 %s（标识符），得到 %s" what (pp_token tk))

let expect_kw p k what =
  let (tk, tp) = peek p in
  match tk with
  | Keyword k' when k' = k -> ignore (next p)
  | _ -> err tp (Printf.sprintf "期望 %s（%s），得到 %s" what (pp_keyword k) (pp_token tk))

let is_kw p k =
  match peek p with (Keyword k', _) -> k' = k | _ -> false

(* 消耗当前行剩余的换行，保证语句边界干净 *)
let end_of_stmt p = skip_trivia p

(* ---------- 类型 ---------- *)

(* 类型词序列长度（0 = 不是类型开头）。数值类型为关键字多词序列，
   bool/char/string 为 Ident（void 不作为声明类型起始）。
   uint 作为后缀（int uint / long long uint / short int uint ...）+1 长度 *)
let ty_kws_len (toks : (token * pos) list) : int =
  let uint_suf n = function
    | (Keyword KUint, _) :: _ -> n + 1
    | _ -> n
  in
  match toks with
  | (Ident s, _) :: _ when List.mem s type_names && s <> "void" -> 1
  | (Ident "void", _) :: _ -> 1   (* void 仅用于函数返回类型 *)
  | (Keyword (KHalf | KFloat | KDouble), _) :: rest -> uint_suf 1 rest
  | (Keyword KInt, _) :: rest -> uint_suf 1 rest
  | (Keyword KShort, _) :: rest ->
    (match rest with
     | (Keyword (KShort | KInt), _) :: rest2 -> uint_suf 2 rest2
     | _ -> 0)
  | (Keyword KLong, _) :: rest ->
    (match rest with
     | (Keyword (KInt | KLong | KDouble), _) :: rest2 -> uint_suf 2 rest2
     | _ -> 0)
  | _ -> 0

(* 多词数值类型：short short / short int / int / long int / long long /
   half / float / double / long double；整数词序列后可跟 uint 后缀
   （int uint / long long uint / short int uint ...）表示无符号。
   解析后规范化为内部宽度名（i8..i128 / u8..u128 / f16..f128），
   单词类型 bool/char/string/void 保持原名。 *)
let rec parse_ty p =
  let (tk, tp) = peek p in
  match tk with
  | Ident s ->
    ignore (next p);
    if not (List.mem s type_names) then
      err tp (Printf.sprintf "未定义的类型：%s（数值类型：short short / short int / int / long int / long long / ... uint 后缀 / half / float / double / long double）" s);
    TNamed (s, tp)
  | Keyword (KShort | KLong | KInt | KUint | KHalf | KFloat | KDouble) as k ->
    let (nm, tp') = parse_numeric_ty p (k, tp) in
    TNamed (nm, tp')
  | Star ->
    err tp "'*'（指针类型）语法已删除"
  | LBracket ->
    err tp "'[]T' / '[T;N]'（切片/数组类型）语法已删除"
  | _ -> err tp (Printf.sprintf "期望类型，得到 %s" (pp_token tk))

(* 解析数值类型词序列，返回内部宽度名与起始位置。
   整数：宽度词序列（short short / short int / int / long int / long long）
   后可跟 uint 后缀（int uint / long long uint ...）表示无符号；
   浮点（half / float / double / long double）不支持 uint 后缀 *)
and parse_numeric_ty p ((tk0, tp0) : token * pos) : string * pos =
  let single = function
    | Keyword KHalf -> Some "f16"
    | Keyword KFloat -> Some "f32"
    | Keyword KDouble -> Some "f64"
    | _ -> None
  in
  (* uint 后缀：iN -> uN；浮点词序列后跟 uint 报错 *)
  let uint_suffix (nm : string) : string =
    match peek p with
    | (Keyword KUint, _) ->
      ignore (next p);
      if nm.[0] = 'f' then err tp0 "浮点类型不支持 uint 修饰";
      "u" ^ String.sub nm 1 (String.length nm - 1)
    | _ -> nm
  in
  match tk0 with
  | Keyword (KHalf | KFloat | KDouble) ->
    ignore (next p);
    (uint_suffix (Option.get (single tk0)), tp0)
  | Keyword KInt ->
    ignore (next p);
    (uint_suffix "i32", tp0)
  | Keyword KShort ->
    ignore (next p);
    let nm =
      (match peek p with
       | (Keyword KShort, _) -> ignore (next p); "i8"
       | (Keyword KInt, _) -> ignore (next p); "i16"
       | (_, sp) -> err sp "short 后应为 short（i8）或 int（i16）")
    in
    (uint_suffix nm, tp0)
  | Keyword KLong ->
    ignore (next p);
    let nm =
      (match peek p with
       | (Keyword KInt, _) -> ignore (next p); "i64"
       | (Keyword KLong, _) -> ignore (next p); "i128"
       | (Keyword KDouble, _) -> ignore (next p); "f128"
       | (_, sp) -> err sp "long 后应为 int（i64）/ long（i128）/ double（f128）")
    in
    (uint_suffix nm, tp0)
  | _ -> err tp0 "期望数值类型"

(* ---------- 表达式 ---------- *)
(* 优先级（低->高）：or < and < not < 比较 < 加减 < 乘除模 < 一元负号 < 后缀 *)

let rec parse_expr p = parse_or p

and parse_or p =
  let l = parse_and p in
  let rec go l =
    match peek p with
    | (Keyword KOr, tp) ->
      ignore (next p);
      go (EBin (Or, l, parse_and p, tp))
    | _ -> l
  in
  go l

and parse_and p =
  let l = parse_not p in
  let rec go l =
    match peek p with
    | (Keyword KAnd, tp) ->
      ignore (next p);
      go (EBin (And, l, parse_not p, tp))
    | _ -> l
  in
  go l

(* not 在逻辑内部优先级最高：not a and b == (not a) and b；
   比较又高于 not：not y==1 == not (y==1) *)
and parse_not p =
  match peek p with
  | (Keyword KNot, tp) ->
    ignore (next p);
    EUn (Not, parse_not p, tp)
  | _ -> parse_eq p

(* 关系比较（高）与相等判断（低）分两层：a < b == c 解析为 (a<b)==c *)
and parse_eq p =
  let l = parse_rel p in
  let (tk, tp) = peek p in
  match tk with
  | Eq | Ne ->
    ignore (next p);
    EBin ((if tk = Eq then Eq else Ne), l, parse_rel p, tp) (* 不结合 *)
  | _ -> l

and parse_rel p =
  let l = parse_add p in
  let (tk, tp) = peek p in
  let op =
    match tk with
    | Lt -> Some Lt | Gt -> Some Gt | Le -> Some Le | Ge -> Some Ge | _ -> None
  in
  match op with
  | None -> l
  | Some op ->
    ignore (next p);
    let r = parse_add p in
    EBin (op, l, r, tp) (* 不结合 *)

and parse_add p =
  let l = parse_mul p in
  let rec go l =
    let (tk, tp) = peek p in
    match tk with
    | Plus ->
      ignore (next p);
      let r = parse_mul p in
      go (EBin (Add, l, r, tp))
    | Minus ->
      ignore (next p);
      let r = parse_mul p in
      go (EBin (Sub, l, r, tp))
    | _ -> l
  in
  go l

and parse_mul p =
  let l = parse_unary p in
  let rec go l =
    let (tk, tp) = peek p in
    match tk with
    | Star ->
      ignore (next p);
      let r = parse_unary p in
      go (EBin (Mul, l, r, tp))
    | Slash ->
      ignore (next p);
      let r = parse_unary p in
      go (EBin (Div, l, r, tp))
    | Percent ->
      ignore (next p);
      let r = parse_unary p in
      go (EBin (Mod, l, r, tp))
    | _ -> l
  in
  go l

and parse_unary p =
  match peek p with
  | (Minus, tp) -> ignore (next p); EUn (Neg, parse_unary p, tp)
  | _ -> parse_postfix p

and parse_postfix p =
  let e = parse_primary p in
  parse_postfix_rest p e

and parse_postfix_rest p e =
  let (tk, tp) = peek p in
  match tk with
  | LParen ->
    (* 调用 *)
    ignore (next p);
    let args = parse_expr_list p in
    parse_postfix_rest p (ECall (e, args, tp))
  | LBracket ->
    (* 下标 arr[i] 或切片 s[a,b] / s[a,b:step]（两端含，步长用冒号） *)
    ignore (next p);
    let e1 = parse_expr p in
    (match peek p with
     | (Comma, _) ->
       ignore (next p);
       let e2 = parse_expr p in
       let step =
         match peek p with
         | (Colon, _) ->
           ignore (next p);
           Some (parse_expr p)
         | _ -> None
       in
       expect p RBracket "]";
       parse_postfix_rest p (ESlice (e, e1, e2, step, tp))
     | (RBracket, _) ->
       ignore (next p);
       parse_postfix_rest p (EIndex (e, e1, tp))
     | (_, tp') -> err tp' "期望 ',' 或 ']'")
  | Dot ->
    (* 命名空间访问：t.item（仅用于 use 导入的文件命名空间） *)
    (match e with
     | EVar (base, _) when (match peek2 p with (Ident _, _) -> true | _ -> false) ->
       ignore (next p);
       let item = expect_ident p "命名空间成员" in
       parse_postfix_rest p (EVar (base ^ "." ^ item, tp))
     | _ -> err tp "点语法已移除：'.' 仅用于 use 导入的命名空间访问（如 t.item）")
  | _ -> e

and parse_expr_list p =
  (* 已消耗 '('；到 ')' 为止；支持命名参数（count=2 等），一律逗号分隔 *)
  let rec go acc =
    match peek p with
    | (RParen, _) -> ignore (next p); List.rev acc
    | (Semicolon, tp') ->
      err tp' "函数调用参数不允许 ';' 分隔，请一律使用 ','"
    | (Ident nm, _) when (match peek2 p with (Assign, _) -> true | _ -> false) ->
      ignore (next p); ignore (next p);
      let e = parse_expr p in
      (match peek p with
       | (Comma, _) -> ignore (next p); go (CNamed (nm, e) :: acc)
       | (RParen, _) -> ignore (next p); List.rev (CNamed (nm, e) :: acc)
       | (_, tp') -> err tp' "期望 ',' 或 ')' 结束参数列表")
    | _ ->
      let e = parse_expr p in
      (match peek p with
       | (Comma, _) -> ignore (next p); go (CPos e :: acc)
       | (RParen, _) -> ignore (next p); List.rev (CPos e :: acc)
       | (_, tp') -> err tp' "期望 ',' 或 ')' 结束参数列表")
  in
  go []

and parse_primary p =
  let (tk, tp) = peek p in
  match tk with
  | IntLit n -> ignore (next p); EInt (n, tp)
  | FloatLit f -> ignore (next p); EFloat (f, tp)
  | StrLit s -> ignore (next p); EStr (s, tp)
  | CharLit c -> ignore (next p); EChar (c, tp)
  | Keyword KTrue -> ignore (next p); EBool (true, tp)
  | Keyword KFalse -> ignore (next p); EBool (false, tp)
  | Keyword KCast ->
    (* cast(表达式, 目标类型)：唯一的显式数值转换语法 *)
    ignore (next p);
    expect p LParen "(";
    let e = parse_expr p in
    expect p Comma ",";
    let t = parse_ty p in
    expect p RParen ")";
    ECast (e, t, tp)
  | Ident s ->
    ignore (next p);
    parse_postfix_rest p (EVar (s, tp))
  | LParen ->
    ignore (next p);
    let e = parse_expr p in
    expect p RParen ")";
    e
  | _ -> err tp (Printf.sprintf "期望表达式，得到 %s" (pp_token tk))

(* ---------- 块与语句 ---------- *)

(* 解析缩进块：Newline? INDENT stmts DEDENT；空块也允许 *)
and parse_block p =
  skip_trivia p;
  let (tk, tp) = peek p in
  if tk = Indent then begin
    ignore (next p);
    let rec go acc =
      skip_trivia p;
      match peek p with
      | (Dedent, _) -> ignore (next p); List.rev acc
      | (Eof, tp') -> err tp' "意外的文件结尾（块未闭合）"
      | _ -> let s = parse_stmt p in go (s :: acc)
    in
    go []
  end
  else
    (* 单语句块：if cond  stmt  （同行跟一条语句） *)
    if
      match tk with
      | Newline | Dedent | Eof | Semicolon -> false
      | _ -> true
    then [ parse_stmt p ]
    else []

(* 数组/列表初始化列表：= 值1,值2,...（未给出的槽位填零值） *)
and parse_seq_inits p =
  match peek p with
  | (Assign, _) ->
    ignore (next p);
    let rec go acc =
      let e = parse_expr p in
      (match peek p with
       | (Comma, _) -> ignore (next p); go (e :: acc)
       | _ -> List.rev (e :: acc))
    in
    go []
  | _ -> []  (* 无初始化：全部填零值 *)

(* 解析 const/frac/unreduced 修饰（可任意顺序，位于类型后名字前） *)
and parse_modifiers p =
  let is_const = ref false and is_frac = ref false and is_unred = ref false in
  let rec go () =
    match peek p with
    | (Keyword KConst, _) when not !is_const ->
      ignore (next p); is_const := true; go ()
    | (Keyword KFrac, _) when not !is_frac ->
      ignore (next p); is_frac := true; go ()
    | (Keyword KUnreduced, _) when not !is_unred ->
      ignore (next p); is_unred := true; go ()
    | _ -> ()
  in
  go ();
  (!is_const, !is_frac, !is_unred)

(* 声明语法（variable 关键字已删除）：
   标量：<类型> (const)? (frac)? 名字 = 值
   数组：<类型> (const)? array 名字 [长度] (= 值1,值2,...)?
   列表：<类型> (const)? list 名字 (= 值1,值2,...)? *)
and parse_decl p tp =
  let ty = parse_ty p in
  parse_decl_ty p tp ty

and parse_decl_ty p tp ty =
  let (is_const, is_frac, is_unred) = parse_modifiers p in
  (match peek p with
   | (Keyword KArray, lp) ->
     ignore (next p);
     (* const 可位于 array 关键字之后、变量名之前：i64 array const carr[3] *)
     let (is_const, is_unred) =
       match peek p with
       | (Keyword KConst, _) -> ignore (next p); (true, is_unred)
       | _ -> (is_const, is_unred)
     in
     let name = expect_ident p "数组名" in
     expect p LBracket "[";
     let len = parse_expr p in
     expect p RBracket "]";
     let inits = parse_seq_inits p in
     end_of_stmt p;
     SSeqDecl (is_const, name, ty, Some len, false, inits, lp)
   | (Keyword KList, lp) ->
     ignore (next p);
     let (is_const, is_unred) =
       match peek p with
       | (Keyword KConst, _) -> ignore (next p); (true, is_unred)
       | _ -> (is_const, is_unred)
     in
     let name = expect_ident p "列表名" in
     let inits = parse_seq_inits p in
     end_of_stmt p;
     SSeqDecl (is_const, name, ty, None, true, inits, lp)
   | _ ->
     (* 标量：初值可省略（省略时填零值）；const 必须带初值 *)
     let name = expect_ident p "变量名" in
     let init =
       (match p.toks with
        | (Assign, _) :: _ ->
          let (_t, _tp) = next p in
          Some (parse_expr p)
        | _ -> None)
     in
     (match is_const, init with
      | true, None -> err tp "const 变量必须带初值"
      | _ -> ());
     end_of_stmt p;
     SDecl (is_const, is_frac, is_unred, name, ty, init, tp))

(* 判断当前是否为声明语句开头：类型词序列 + 名字/const/frac/unreduced/array/list *)
and looks_like_decl p =
  match ty_kws_len p.toks with
  | 0 -> false
  | n ->
    let rec drop k l = if k <= 0 then l else match l with _ :: r -> drop (k - 1) r | [] -> [] in
    (match drop n p.toks with
     | (Ident _, _) :: _ -> true
     | (Keyword (KConst | KFrac | KUnreduced | KArray | KList), _) :: _ -> true
     | _ -> false)
(* for 头部声明（const/frac/unreduced 允许，无 variable） *)
and parse_for_decl p tp =
  let ty = parse_ty p in
  let (is_const, _is_frac, _is_unred) = parse_modifiers p in
  let name = expect_ident p "变量名" in
  let init =
    (match p.toks with
     | (Assign, _) :: _ ->
       let (_t, _tp) = next p in
       Some (parse_expr p)
     | _ -> None)
  in
  (match is_const, init with
   | true, None -> err tp "const 变量必须带初值"
   | _ -> ());
  FIDecl (is_const, name, ty, init, tp)

(* 判断是否为"裸声明"形状错误（类型名开头但后续不构成合法声明） *)
and check_bare_decl p =
  match p.toks with
  | (Ident s, tp) :: _ when List.mem s type_names && s <> "void" ->
    err tp (Printf.sprintf
              "声明语法：类型 (const)? (frac)? 名字 [= 初值]（如 %s x = 1 / %s x / %s const k = 2 / %s array n[8]）"
              s s s s)
  | toks when ty_kws_len toks > 0 ->
    let (tk, tp) = List.nth toks 0 in
    err tp (Printf.sprintf
              "声明语法：类型 (const)? (frac)? 名字 [= 初值]（如 %s x = 1 / %s x / %s const k = 2 / %s array n[8]）"
              (pp_token tk) (pp_token tk) (pp_token tk) (pp_token tk))
  | _ -> ()

and parse_stmt p =
  let (tk, tp) = peek p in
  match tk with
  | Ident _ when looks_like_decl p -> parse_decl p tp
  | Keyword (KShort | KLong | KInt | KUint | KHalf | KFloat | KDouble)
    when looks_like_decl p -> parse_decl p tp
  | Ident _ -> check_bare_decl p; parse_expr_stmt p
  | Keyword (KShort | KLong | KInt | KUint | KHalf | KFloat | KDouble) ->
    check_bare_decl p; parse_expr_stmt p
  | Keyword KReturn ->
    ignore (next p);
    (match peek p with
     | (Newline, _) | (Dedent, _) | (Eof, _) ->
       end_of_stmt p;
       SReturn (None, tp)
     | _ ->
       let e = parse_expr p in
       end_of_stmt p;
       SReturn (Some e, tp))
  | Keyword KIf ->
    ignore (next p);
    parse_if p tp
  | Keyword KWhile ->
    ignore (next p);
    let cond = parse_expr p in
    let body = parse_block p in
    SWhile (cond, body, tp)
  | Keyword KFor ->
    ignore (next p);
    parse_for p tp
  | Keyword KOutput ->
    ignore (next p);
    parse_output p tp
  | Keyword KInput ->
    ignore (next p);
    parse_input p tp
  | Keyword KBreak -> ignore (next p); end_of_stmt p; SBreak tp
  | Keyword KContinue -> ignore (next p); end_of_stmt p; SContinue tp
  | Keyword KThrow ->
    ignore (next p);
    let e = parse_expr p in
    end_of_stmt p;
    SThrow (e, tp)
  | Keyword KTry ->
    ignore (next p);
    let try_b = parse_block p in
    skip_trivia p;
    expect p (Keyword KCatch) "catch";
    let binding =
      match peek p with
      | (Ident nm, _) -> ignore (next p); Some nm
      | _ -> None
    in
    let catch_b = parse_block p in
    STry (try_b, (binding, catch_b), tp)
  | Keyword KReduce ->
    ignore (next p);
    expect p LParen "(";
    let a = parse_expr p in
    expect p Comma ",";
    let b = parse_expr p in
    expect p Comma ",";
    let c = parse_expr p in
    expect p RParen ")";
    end_of_stmt p;
    SReduce (a, b, c, tp)
  | Keyword KRemove ->
    ignore (next p);
    expect p LParen "(";
    let a = parse_expr p in
    expect p Comma ",";
    let b = parse_expr p in
    expect p RParen ")";
    end_of_stmt p;
    SRemove (a, b, tp)
  | Semicolon -> skip_trivia p; parse_stmt p
  | _ -> parse_expr_stmt p

(* 表达式语句 / 赋值 / 复合赋值 / 自增自减 *)
and parse_expr_stmt p =
  let e = parse_expr p in
  let tp' = pos_of (peek p) in
  match peek p with
  | (Assign, ap) ->
    ignore (next p);
    let rhs = parse_expr p in
    end_of_stmt p;
    SAssign (e, rhs, ap)
  | (PlusAssign, _) | (MinusAssign, _) | (StarAssign, _) | (SlashAssign, _)
  | (PercentAssign, _) ->
    let op =
      match peek p with
      | (PlusAssign, _) -> Add | (MinusAssign, _) -> Sub
      | (StarAssign, _) -> Mul | (PercentAssign, _) -> Mod
      | _ -> Div
    in
    ignore (next p);
    let rhs = parse_expr p in
    end_of_stmt p;
    SAug (op, e, rhs, tp')
  | (PlusPlus, _) -> ignore (next p); end_of_stmt p; SInc (e, tp')
  | (MinusMinus, _) -> ignore (next p); end_of_stmt p; SDec (e, tp')
  | _ ->
    end_of_stmt p;
    SExpr e

(* output(参数..., sep=?, end=?)：sep/end 为命名参数（表达式），必须放在最后；
   sep 默认 ""，end 默认 "\n"；非 char/string 值在 typeck 强制转 string *)
and parse_output p tp =
  expect p LParen "(";
  let args = ref [] and sep = ref None and end_ = ref None in
  (* 命名参数阶段：记录表达式，之后只允许另一个命名参数或 ')' *)
  let rec go_named nm v =
    if nm = "sep" then begin
      if !sep <> None then err tp "output 的 sep 参数重复";
      sep := Some v
    end
    else begin
      if !end_ <> None then err tp "output 的 end 参数重复";
      end_ := Some v
    end;
    match peek p with
    | (RParen, _) -> ignore (next p)
    | (Comma, _) ->
      ignore (next p);
      (match peek p with
       | (Keyword (KSep | KEnd as kw), _) when (match peek2 p with (Assign, _) -> true | _ -> false) ->
         ignore (next p); ignore (next p);
         let v' = parse_expr p in
         go_named (if kw = KSep then "sep" else "end") v'
       | (_, tp') -> err tp' "output 的命名参数（sep/end）必须放在最后")
    | (_, tp') -> err tp' "期望 ',' 或 ')' 结束 output 参数列表"
  in
  (* 普通参数阶段 *)
  let rec go_args () =
    match peek p with
    | (RParen, _) -> ignore (next p)
    | (Comma, _) -> ignore (next p); go_args ()
    | (Keyword (KSep | KEnd as kw), _) when (match peek2 p with (Assign, _) -> true | _ -> false) ->
      ignore (next p); ignore (next p);
      let v = parse_expr p in
      go_named (if kw = KSep then "sep" else "end") v
    | _ ->
      let e = parse_expr p in
      args := e :: !args;
      (match peek p with
       | (Comma, _) -> ignore (next p); go_args ()
       | (RParen, _) -> ignore (next p)
       | (_, tp') -> err tp' "期望 ',' 或 ')' 结束 output 参数列表")
  in
  go_args ();
  end_of_stmt p;
  SOutput (List.rev !args, !sep, !end_, tp)

(* input(目标..., delim=?)：目标为 <类型> 名（新声明）或 名（已有变量）；
   delim 默认为"换行和空格"字符集 *)
and parse_input p tp =
  expect p LParen "(";
  let targets = ref [] and delim = ref None in
  let rec go () =
    match peek p with
    | (RParen, _) -> ignore (next p)
    | (Comma, _) -> ignore (next p); go ()
    | (Keyword KDelim, _) when (match peek2 p with (Assign, _) -> true | _ -> false) ->
      (* delim= 命名参数：char/string 表达式（变量亦可），必须是最后一个参数 *)
      ignore (next p); ignore (next p);
      let e = parse_expr p in
      delim := Some e;
      (match peek p with
       | (RParen, _) -> ignore (next p)
       | (_, tp') -> err tp' "input 的 delim 必须是最后一个参数")
    | _ ->
      let t =
        if looks_like_decl p then begin
          let ty = parse_ty p in
          let (_c, _f, _u) = parse_modifiers p in
          let name = expect_ident p "变量名" in
          InNew (name, ty, tp)
        end
        else begin
          let name = expect_ident p "变量名" in
          InUse (name, tp)
        end
      in
      targets := t :: !targets;
      (match peek p with
       | (Comma, _) -> ignore (next p); go ()
       | (RParen, _) -> ignore (next p)
       | (_, tp') -> err tp' "期望 ',' 或 ')' 结束 input 目标列表")
  in
  go ();
  end_of_stmt p;
  SInput (List.rev !targets, !delim, tp)

(* for 逗号化头部：for 项,项,...  —— 编译器按形状分类：
   声明（类型开头）→ 初始化；比较/布尔表达式 → 条件（多项用 and 连接）；
   赋值/复合赋值/自增自减 → 更新。如 for i,j,i<5 and j>7,i--,j+=i *)
and parse_for p tp =
  let inits = ref [] and conds = ref [] and updates = ref [] in
  let rec go () =
    match peek p with
    | (Newline, _) | (Indent, _) | (Dedent, _) | (Eof, _) -> ()
    | _ ->
      if looks_like_decl p then begin
        let item = parse_for_decl p tp in
        inits := item :: !inits;
        (match peek p with
         | (Comma, _) -> ignore (next p); go ()
         | _ -> ())
      end
      else begin
        let lhs = parse_expr p in
        let item_or_cond =
          match peek p with
          | (Assign, up) ->
            ignore (next p); `U (FUAssign (lhs, parse_expr p, up))
          | (PlusAssign, up) ->
            ignore (next p); `U (FUOp (Add, lhs, parse_expr p, up))
          | (MinusAssign, up) ->
            ignore (next p); `U (FUOp (Sub, lhs, parse_expr p, up))
          | (StarAssign, up) ->
            ignore (next p); `U (FUOp (Mul, lhs, parse_expr p, up))
          | (SlashAssign, up) ->
            ignore (next p); `U (FUOp (Div, lhs, parse_expr p, up))
          | (PercentAssign, up) ->
            ignore (next p); `U (FUOp (Mod, lhs, parse_expr p, up))
          | (PlusPlus, up) -> ignore (next p); `U (FUInc (lhs, up))
          | (MinusMinus, up) -> ignore (next p); `U (FUDec (lhs, up))
          (* 孤立变量名（for i, ...）：占位表达式，进入初始化段执行一次 *)
          | _ ->
            (match lhs with
             | EVar (_, _) -> `I (FIExpr (lhs, tp))
             | _ -> `C lhs)
        in
        (match item_or_cond with
         | `U u -> updates := u :: !updates
         | `I i -> inits := i :: !inits
         | `C c -> conds := c :: !conds);
        (match peek p with
         | (Comma, _) -> ignore (next p); go ()
         | _ -> ())
      end
  in
  go ();
  (* 多个条件用 and 连接；无条件恒真 *)
  let cond =
    match List.rev !conds with
    | [] -> EBool (true, tp)
    | c :: rest -> List.fold_left (fun acc c -> EBin (And, acc, c, tp)) c rest
  in
  let body = parse_block p in
  SFor (List.rev !inits, cond, List.rev !updates, body, tp)

and parse_if p tp =
  let cond = parse_expr p in
  let then_b = parse_block p in
  (* else 可能跟在 DEDENT 后的下一行（同级缩进） *)
  let else_b =
    skip_trivia p;
    if is_kw p KElse then begin
      ignore (next p);
      if is_kw p KIf then begin
        let (_, itp) = peek p in
        ignore (next p);
        Some [ parse_if p itp ]
      end
      else Some (parse_block p)
    end
    else None
  in
  SIf (cond, then_b, else_b, tp)

(* ---------- 顶层项 ---------- *)

(* 顶层项是函数定义还是声明：类型词后（可跳过 const/frac/unreduced 修饰，
   但出现 array/list 关键字则为声明）跟标识符，标识符后是 '(' 为函数定义 *)
let top_is_fn (toks : (token * pos) list) : bool =
  let n = ty_kws_len toks in
  if n = 0 then false
  else begin
    let rec drop k l = if k <= 0 then l else match l with _ :: r -> drop (k - 1) r | [] -> [] in
    let rec skip_mods l =
      match l with
      | (Keyword (KConst | KFrac | KUnreduced), _) :: r -> skip_mods r
      | _ -> l
    in
    match skip_mods (drop n toks) with
    | (Keyword (KArray | KList), _) :: _ -> false
    | (Ident _, _) :: (LParen, _) :: _ -> true
    | _ -> false
  end

(* 函数参数：
   标量：<类型> (frac)? 名字
   数组：<类型> array 名字 [长度]（长度为字面量或之前的参数名）
   列表：<类型> list 名字 *)
let parse_param p =
  let (tk0, tp0) = peek p in
  let pt = parse_ty p in
  let (isc, is_frac, is_unred) = parse_modifiers p in
  if isc then err tp0 "参数不支持 const 修饰";
  if is_unred then err tp0 "参数不支持 unreduced 修饰";
  match peek p with
  | (Keyword KArray, lp) ->
    ignore (next p);
    if is_frac then err lp "数组参数不支持 frac 修饰";
    let name = expect_ident p "数组参数名" in
    expect p LBracket "[";
    let len = parse_expr p in
    expect p RBracket "]";
    { pname = name; pty = pt; pfrac = false; pseq = PArray len; ppos = lp }
  | (Keyword KList, lp) ->
    ignore (next p);
    if is_frac then err lp "列表参数不支持 frac 修饰";
    let name = expect_ident p "列表参数名" in
    { pname = name; pty = pt; pfrac = false; pseq = PList; ppos = lp }
  | _ ->
    let name = expect_ident p "参数名" in
    { pname = name; pty = pt; pfrac = is_frac; pseq = PScalar; ppos = tp0 }

let rec parse_item p =
  skip_trivia p;
  let (tk, tp) = peek p in
  match tk with
  | Keyword KUse ->
    (* use 文件名.zfy [import 模块名] [as 别名]
       路径：无 / 从当前目录找；./ 当前目录；../ 上一级 *)
    ignore (next p);
    (* 解析文件路径：('.' | '.' '.')? '/'? ident ('.' ident)*，拼接为字符串 *)
    let buf = Buffer.create 16 in
    let rec path_parts () =
      (* 前导 ./ 或 ../ *)
      let rec dots n =
        match peek p with
        | (Dot, _) when n < 2 -> ignore (next p); dots (n + 1)
        | _ -> n
      in
      let n = dots 0 in
      if n > 0 then begin
        (* ./ 与 ../ 需要 / 跟进 *)
        expect p Slash "/";
        for _ = 1 to n do Buffer.add_string buf "../" done
      end;
      let first = expect_ident p "文件名" in
      Buffer.add_string buf first;
      (* 文件名中的 .zfy 后缀：. 后跟标识符 *)
      let rec ext () =
        match peek p with
        | (Dot, _) ->
          ignore (next p);
          Buffer.add_char buf '.';
          Buffer.add_string buf (expect_ident p "扩展名");
          ext ()
        | _ -> ()
      in
      ext ()
    in
    path_parts ();
    if not (Filename.check_suffix (Buffer.contents buf) ".zfy") then
      err tp "use 的文件名必须带 .zfy 后缀";
    let import =
      if is_kw p KImport then begin
        ignore (next p);
        Some (expect_ident p "模块名")
      end else None
    in
    let alias =
      if is_kw p KAs then begin
        ignore (next p);
        Some (expect_ident p "别名")
      end else None
    in
    end_of_stmt p;
    IUse { path = Buffer.contents buf; import; alias; pos = tp }
  | Ident _ | Keyword (KShort | KLong | KInt | KUint | KHalf | KFloat | KDouble | KFrac | KConst | KUnreduced) ->
    if top_is_fn p.toks then begin
      (* 函数定义：类型 (frac)? 名字(参数) 块 *)
      let ty0 = parse_ty p in
      let (_c, rf, _u) = parse_modifiers p in
      let name = expect_ident p "函数名" in
      expect p LParen "(";
      let params =
        let rec go acc =
          match peek p with
          | (RParen, _) -> ignore (next p); List.rev acc
          | _ ->
            let pd = parse_param p in
            (match peek p with
             | (Comma, _) -> ignore (next p); go (pd :: acc)
             | (RParen, _) -> ignore (next p); List.rev (pd :: acc)
             | (_, tp') -> err tp' "期望 ',' 或 ')' 结束参数列表")
        in
        go []
      in
      let body = parse_block p in
      IFn { name; params; ret = Some ty0; rfrac = rf; body; pos = tp }
    end
    else begin
      (* 顶层声明：const/frac/unreduced 标量、数组、列表均可 *)
      let d = parse_decl p tp in
      IDecl (d, tp)
    end
  | _ -> err tp (Printf.sprintf "期望顶层项（函数定义/use/声明），得到 %s" (pp_token tk))

let parse_program p =
  let rec go acc =
    skip_trivia p;
    match peek p with
    | (Eof, _) -> List.rev acc
    | _ -> go (parse_item p :: acc)
  in
  go []
