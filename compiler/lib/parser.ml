(* zfy 语法分析器：手写递归下降，基于缩进块 *)
open Tokens
open Ast

exception ParseError of pos * string

let err p msg = raise (ParseError (p, msg))

type parser =
  { mutable toks : (token * pos) list;
    mutable tynames : string list;  (* 已知类型名：内建 + 本文件 struct/type 别名 *)
    mutable errs : (pos * string) list }  (* 已收集待恢复的错误（多错误报告） *)

let make toks = { toks = toks; tynames = type_names; errs = [] }

let pos_of (t, p) = p
let eof_pos = { file = ""; line = 0; col = 0 }
let peek p = match p.toks with [] -> (Eof, eof_pos) | x :: _ -> x
let peek2 p = match p.toks with _ :: x :: _ -> x | _ -> (Eof, eof_pos)
let peek3 p = match p.toks with _ :: _ :: x :: _ -> x | _ -> (Eof, eof_pos)
let next p = match p.toks with [] -> (Eof, eof_pos) | x :: r -> p.toks <- r; x

(* 记录错误（供语句级恢复后统一报告） *)
let record_err p pos msg = p.errs <- (pos, msg) :: p.errs

(* 语句级恢复：丢弃 token 直到语句边界（Newline/Dedent/Eof），至少消耗一个 *)
let rec sync_stmt p =
  match next p with
  | (Newline, _) | (Dedent, _) | (Eof, _) -> ()
  | _ -> sync_stmt p

(* 顶层项级恢复：丢弃 token 直到下一个顶层项开头（Newline 后不缩进） *)
let rec sync_top p =
  match next p with
  | (Eof, _) -> ()
  | (Newline, _) ->
    (match peek p with
     | (Indent, _) -> sync_top p   (* 仍在出错项的块内，继续跳 *)
     | _ -> ())
  | _ -> sync_top p

(* 跳过空行（Newline）；分号在语句位置非法（只允许出现在 for 头部） *)
let rec skip_trivia p =
  match peek p with
  | (Newline, _) -> ignore (next p); skip_trivia p
  | (Semicolon, sp) ->
    err sp "semicolon is only allowed in for headers"
  | _ -> ()

let expect p t what =
  let (tk, tp) = peek p in
  if tk = t then ignore (next p)
  else
    err tp (Printf.sprintf "expected %s (%s), got %s" what (pp_token t) (pp_token tk))

let expect_ident p what =
  let (tk, tp) = peek p in
  match tk with
  | Ident s -> ignore (next p); s
  | _ -> err tp (Printf.sprintf "expected %s (identifier), got %s" what (pp_token tk))

let expect_kw p k what =
  let (tk, tp) = peek p in
  match tk with
  | Keyword k' when k' = k -> ignore (next p)
  | _ -> err tp (Printf.sprintf "expected %s (%s), got %s" what (pp_keyword k) (pp_token tk))

let is_kw p k =
  match peek p with (Keyword k', _) -> k' = k | _ -> false

(* 消耗当前行剩余的换行，保证语句边界干净 *)
let end_of_stmt p = skip_trivia p

(* ---------- 模块路径（::） ---------- *)

(* token 列表是否以 Ident (:: Ident)+ 开头（模块路径形状，如 m::Point） *)
let is_qpath_start (toks : (token * pos) list) : bool =
  match toks with
  | (Ident _, _) :: (Colon, _) :: (Colon, _) :: _ -> true
  | _ -> false

(* 从 token 列表扫描 Ident (:: Ident)* 段，返回 (段名列表, 剩余 tokens)。
   调用前须 is_qpath_start 成立 *)
let scan_qpath (toks : (token * pos) list) : string list * (token * pos) list =
  let rec go acc l =
    match l with
    | (Ident s, _) :: (Colon, _) :: (Colon, _) :: (Ident _, _) :: r ->
      go (s :: acc) r
    | (Ident s, _) :: r -> (List.rev (s :: acc), r)
    | _ -> (List.rev acc, l)
  in
  match toks with
  | (Ident s, _) :: r -> go [ s ] r
  | _ -> assert false

(* 表达式/类型位置：消耗 Ident 后的 :: 后缀（相邻两个 Colon），拼接为
   "a::b::c" 形式的名字（resolve 阶段解析改写） *)
let rec qpath_extend p s =
  match fst (peek p), fst (peek2 p) with
  | Colon, Colon ->
    ignore (next p); ignore (next p);
    let seg = expect_ident p "path segment" in
    qpath_extend p (s ^ "::" ^ seg)
  | _ -> s

(* ---------- 类型 ---------- *)

(* 类型别名关键词（多词序列的组成词） *)
let is_alias_kw = function
  | KShort | KLong | KUshort | KUlong | KInt | KUint | KHalf | KFloat | KDouble | KQuad -> true
  | _ -> false

(* 传统多词类型别名 → 内部宽度名（new.md：与传统宽度名并存，两者皆合法）。
   贪婪匹配最长合法序列；返回 (归一化名, 消耗词数)。
   long=i128、ulong=u128（用户拍板：long int/long long/ulong int/ulong long
   已废止——long 后跟另一类型词由 check_no_dup_ty 报"类型重复"）：
   short=i8 short int=i16 int=i32 long=i128
   ushort=u8 ushort int=u16 uint=u32 ulong=u128
   half=f16 float=f32 double=f64 quad=f128 *)
let alias_ty (toks : (token * pos) list) : (string * int) option =
  match toks with
  | (Keyword KShort, _) :: (Keyword KInt, _) :: _ -> Some ("i16", 2)
  | (Keyword KShort, _) :: _ -> Some ("i8", 1)
  | (Keyword KLong, _) :: _ -> Some ("i128", 1)
  | (Keyword KUshort, _) :: (Keyword KInt, _) :: _ -> Some ("u16", 2)
  | (Keyword KUshort, _) :: _ -> Some ("u8", 1)
  | (Keyword KUlong, _) :: _ -> Some ("u128", 1)
  | (Keyword KInt, _) :: _ -> Some ("i32", 1)
  | (Keyword KUint, _) :: _ -> Some ("u32", 1)
  | (Keyword KHalf, _) :: _ -> Some ("f16", 1)
  | (Keyword KFloat, _) :: _ -> Some ("f32", 1)
  | (Keyword KDouble, _) :: _ -> Some ("f64", 1)
  | (Keyword KQuad, _) :: _ -> Some ("f128", 1)
  | _ -> None

(* 类型词长度（0 = 不是类型开头）。类型为：
   - 单词 Ident：内建宽度类型或用户 struct 名（后者由 typeck 校验）
   - 多词 Keyword 序列：short int 等传统别名（贪婪最长匹配） *)
let ty_kws_len (toks : (token * pos) list) : int =
  match toks with
  | (Ident _, _) :: _ -> 1
  | (Keyword k, _) :: _ when is_alias_kw k ->
    (match alias_ty toks with
     | Some (_, n) -> n
     | None -> 1)   (* 防御：当前全部别名词均有映射，不可达 *)
  | _ -> 0

(* 类型词后紧跟另一类型词：重复/混写报错（如 int int、i32 int） *)
let check_no_dup_ty p =
  match peek p with
  | (Keyword k, tp) when is_alias_kw k ->
    err tp "duplicate base type: a declaration has exactly one base type (alias and width names cannot be mixed)"
  | (Ident s, tp) when List.mem s type_names ->
    err tp "duplicate base type: a declaration has exactly one base type (alias and width names cannot be mixed)"
  | _ -> ()

(* 类型：单词 Ident（bool/char/string/void + i8..f128 宽度类型 + struct 名）
   或多词传统别名（short int 等，归一化为宽度名）+
   指针后缀 T*（可叠加，T** 由 typeck 限制）；函数类型 T(参数类型列表)
   仅在 type 别名处允许（~allow_fun） *)
let rec parse_ty ?(allow_fun = false) p =
  let (tk, tp) = peek p in
  let rec suffixes base =
    match peek p with
    | (Star, _) ->
      ignore (next p);
      suffixes (TPtr (base, tp))
    (* T const*：指向 const 的指针（new2.md 9c）；const 后跟其它 token 时
       留给声明修饰符处理（如 T const 常量变量） *)
    | (Keyword KConst, cp) when fst (peek2 p) = Star ->
      ignore (next p); ignore (next p);
      suffixes (TPtrC (base, cp))
    | (Bang, _) ->
      ignore (next p);
      suffixes (TErr (base, tp))
    | (LParen, lp) when allow_fun ->
      ignore (next p);
      let ptys =
        let rec go acc =
          match peek p with
          | (RParen, _) -> ignore (next p); List.rev acc
          | _ ->
            let t = parse_ty p in
            (match peek p with
             | (Comma, _) -> ignore (next p); go (t :: acc)
             | (RParen, _) -> ignore (next p); List.rev (t :: acc)
             | (_, tp') -> err tp' "expected ',' or ')' to end the parameter type list")
        in
        go []
      in
      suffixes (TFun (base, ptys, lp))
    | _ -> base
  in
  match tk with
  | Ident s ->
    ignore (next p);
    let s = qpath_extend p s in    (* 模块路径类型 m::Point *)
    check_no_dup_ty p;
    suffixes (TNamed (s, tp))
  | Keyword k when is_alias_kw k ->
    (* 传统类型别名：归一化为内部宽度名（short int→i16 等，零后端改动） *)
    (match alias_ty p.toks with
     | Some (name, n) ->
       for _ = 1 to n do ignore (next p) done;
       check_no_dup_ty p;
       suffixes (TNamed (name, tp))
     | None -> err tp "expected a type")
  | Keyword (KArray | KList) ->
    err tp "'array'/'list' keywords removed: arrays are written T a[N], lists T a[]"
  | Star ->
    err tp "'*' must follow a type to form a pointer (syntax T*, e.g. i32* p)"
  | LBracket ->
    err tp "'[]T' / '[T;N]' (slice/array type) syntax removed"
  | _ -> err tp (Printf.sprintf "expected a type, got %s" (pp_token tk))

(* ---------- 表达式 ---------- *)
(* 优先级（低->高）：?? < or < and < not < 比较 < 加减 < 乘除模 < 一元负号 < 后缀 *)

let rec parse_expr p = parse_unwrap p

(* ?? 解包：a ?? b（值形式）或 a ?? + 缩进块（块形式，块内可用 err） *)
and parse_unwrap p =
  let l = parse_or p in
  match peek p with
  | (QuestionQuestion, tp) ->
    ignore (next p);
    (match peek p with
     | (Newline, _) ->
       (* 块形式：换行后跟缩进块 *)
       ignore (next p);
       let blk = parse_block p in
       EUnwrap (l, EBlock (blk, tp), tp)
     | _ ->
       let r = parse_or p in
       EUnwrap (l, r, tp))
  | _ -> l

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
  | (Amp, tp) -> ignore (next p); EAddrOf (parse_unary p, tp)
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
     | (_, tp') -> err tp' "expected ',' or ']'")
  | Dot ->
    (* 命名空间访问：t.item（仅用于 use 导入的文件命名空间） *)
    (match e with
     | EVar (base, _) when (match peek2 p with (Ident _, _) -> true | _ -> false) ->
       ignore (next p);
       let item = expect_ident p "namespace member" in
       parse_postfix_rest p (EVar (base ^ "." ^ item, tp))
     | _ -> err tp "dot syntax removed: '.' is only for use-namespace access (e.g. t.item)")
  | Question ->
    (* 后缀错误传播 a?（ZEM 错误模型） *)
    ignore (next p);
    parse_postfix_rest p (EPropagate (e, tp))
  | Caret ->
    (* 后缀解引用 p^（new2.md #10：替代 p*，消除与乘法的歧义） *)
    ignore (next p);
    parse_postfix_rest p (EDeref (e, tp))
  | Star when (match fst (peek2 p) with
               (* p* 旧解引用写法已移除：* 后是收尾符/运算符时按解引用意图报错提示；
                  后随表达式时按乘法处理（p * -b 等正常解析） *)
               | Assign | PlusAssign | MinusAssign | StarAssign | SlashAssign
               | PercentAssign | RParen | Comma | RBracket | Newline | Dedent
               | Eof | Colon | Semicolon | PlusPlus | MinusMinus
               | Eq | Ne | Lt | Gt | Le | Ge | Dot -> true
               | _ -> false) ->
    err tp "pointer dereference syntax is now 'p^' (the 'p*' form was removed to avoid ambiguity with multiplication)"
  | _ -> e

and parse_expr_list p =
  (* 已消耗 '('；到 ')' 为止；支持命名参数（count=2 等），一律逗号分隔 *)
  let rec go acc =
    match peek p with
    | (RParen, _) -> ignore (next p); List.rev acc
    | (Semicolon, tp') ->
      err tp' "';' is not allowed between call arguments; use ','"
    | (Keyword KMove, _) ->
      (* 显式 move 实参：f(move p)——所有权移交（change.md 1.6） *)
      ignore (next p);
      let e = parse_expr p in
      (match peek p with
       | (Comma, _) -> ignore (next p); go (CMove e :: acc)
       | (RParen, _) -> ignore (next p); List.rev (CMove e :: acc)
       | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
    | (Keyword KCopy, _) ->
      (* 显式深拷贝实参：f(copy p)——与默认值语义相同，显式声明意图（new2.md #1） *)
      ignore (next p);
      let e = parse_expr p in
      (match peek p with
       | (Comma, _) -> ignore (next p); go (CCopy e :: acc)
       | (RParen, _) -> ignore (next p); List.rev (CCopy e :: acc)
       | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
    | (Keyword KRef, _) ->
      (* 传引用实参：f(ref y)——y 须为可定位变量，对应参数须为 ref（new2.md #1） *)
      ignore (next p);
      let e = parse_expr p in
      (match peek p with
       | (Comma, _) -> ignore (next p); go (CRef e :: acc)
       | (RParen, _) -> ignore (next p); List.rev (CRef e :: acc)
       | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
    | (Ident nm, _) when (match peek2 p with (Assign, _) -> true | _ -> false) ->
      ignore (next p); ignore (next p);
      let e = parse_expr p in
      (match peek p with
       | (Comma, _) -> ignore (next p); go (CNamed (nm, e) :: acc)
       | (RParen, _) -> ignore (next p); List.rev (CNamed (nm, e) :: acc)
       | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
    | _ ->
      let e = parse_expr p in
      (match peek p with
       | (Comma, _) -> ignore (next p); go (CPos e :: acc)
       | (RParen, _) -> ignore (next p); List.rev (CPos e :: acc)
       | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
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
  | Keyword KNull -> ignore (next p); ENull tp
  | Keyword KErr ->
    (* err：解包块内的错误信息变量（typeck 在 ?? 块作用域注入；外部报未定义） *)
    ignore (next p);
    parse_postfix_rest p (EVar ("err", tp))
  | Keyword KFail ->
    (* fail(code, msg)：构造 T! 错误值（元素类型由上下文推断） *)
    ignore (next p);
    expect p LParen "(";
    let c = parse_expr p in
    expect p Comma ",";
    let m = parse_expr p in
    expect p RParen ")";
    EFail (c, m, tp)
  | Keyword KPanic ->
    (* panic(msg) 或 panic(code, msg)：不可恢复终止 *)
    ignore (next p);
    expect p LParen "(";
    (match peek p with
     | (RParen, _) -> err tp "panic requires a message argument: panic(msg) or panic(code, msg)"
     | _ ->
       let e1 = parse_expr p in
       (match peek p with
        | (RParen, _) -> ignore (next p); EPanic (None, e1, tp)
        | (Comma, _) ->
          ignore (next p);
          let e2 = parse_expr p in
          expect p RParen ")";
          EPanic (Some e1, e2, tp)
        | (_, tp') -> err tp' "expected ',' or ')' to end the panic arguments"))
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
    let s = qpath_extend p s in    (* 模块路径引用 m::f / m::Point(...) *)
    parse_postfix_rest p (EVar (s, tp))
  | LParen ->
    ignore (next p);
    let e = parse_expr p in
    expect p RParen ")";
    e
  | _ -> err tp (Printf.sprintf "expected an expression, got %s" (pp_token tk))

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
      | (Eof, tp') -> err tp' "unexpected end of input (unclosed block)"
      | _ ->
        (* 语句级错误恢复：记录后跳到下一条语句继续（多错误收集） *)
        (try let s = parse_stmt p in go (s :: acc)
         with ParseError (ep, em) ->
           record_err p ep em;
           sync_stmt p;
           go acc)
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

(* 解析 const/frac/unred/ref 修饰（可任意顺序，位于类型后名字前）；
   ref 仅函数参数合法（其他位置由调用方报错） *)
and parse_modifiers p =
  let is_const = ref false and is_frac = ref false and is_unred = ref false
  and is_ref = ref false in
  let rec go () =
    match peek p with
    | (Keyword KConst, _) when not !is_const ->
      ignore (next p); is_const := true; go ()
    | (Keyword KFrac, _) when not !is_frac ->
      ignore (next p); is_frac := true; go ()
    | (Keyword KUnreduced, _) when not !is_unred ->
      ignore (next p); is_unred := true; go ()
    | (Keyword KRef, _) when not !is_ref ->
      ignore (next p); is_ref := true; go ()
    | _ -> ()
  in
  go ();
  (!is_const, !is_frac, !is_unred, !is_ref)

(* 声明语法：
   标量：<类型> (const)? (frac)? 名字 [= 初值]
   数组：<类型> (const)? 名字[长度] (= 值1,值2,...)?
   列表：<类型> (const)? 名字[] (= 值1,值2,...)?（中括号必须为空） *)
and parse_decl p tp =
  let ty = parse_ty p in
  parse_decl_ty p tp ty

and parse_decl_ty p tp ty =
  let (is_const, is_frac, is_unred, is_ref) = parse_modifiers p in
  if is_ref then err tp "ref is only allowed on function parameters";
  let name = expect_ident p "variable name" in
  (match peek p with
   | (LBracket, lp) ->
     (* 数组 / 列表：名字后跟 [长度]（数组）或 []（列表） *)
     ignore (next p);
     (match peek p with
      | (RBracket, _) ->
        ignore (next p);
        if is_frac then err lp "lists do not support the frac modifier";
        let inits = parse_seq_inits p in
        end_of_stmt p;
        SSeqDecl (is_const, name, ty, None, true, inits, lp)
      | _ ->
        if is_frac then err lp "arrays do not support the frac modifier";
        let len = parse_expr p in
        expect p RBracket "]";
        let inits = parse_seq_inits p in
        end_of_stmt p;
        SSeqDecl (is_const, name, ty, Some len, false, inits, lp))
   | _ ->
     (* 标量：初值可省略（省略时填零值）；const 必须带初值 *)
     let init =
       (match p.toks with
        | (Assign, _) :: _ ->
          let (_t, _tp) = next p in
          Some (parse_expr p)
        | _ -> None)
     in
     (match is_const, init with
      | true, None -> err tp "const requires an initializer"
      | _ -> ());
     end_of_stmt p;
     SDecl (is_const, is_frac, is_unred, name, ty, init, tp))

(* 判断当前是否为声明语句开头：类型词 + 名字/const/frac/unred。
   类型位后跟 *（指针声明 T* p 与乘法 x * y 形状相同）：仅当类型位是
   已知类型名（内建/本文件 struct/type 别名）才视为指针声明。
   模块路径类型 m::Point p：qpath 后（跳过 */!/修饰）跟标识符（非调用
   形状）即声明；数组/列表声明 m::Point arr[8] 与下标表达式 m::arr[0]
   无法句法区分，取表达式（用 type 别名绕过） *)
and looks_like_decl p =
  if is_qpath_start p.toks then begin
    let (_segs, rest) = scan_qpath p.toks in
    let rec skip l =
      match l with
      | (Star, _) :: r | (Bang, _) :: r -> skip r
      | (Keyword (KConst | KFrac | KUnreduced | KRef), _) :: r -> skip r
      | _ -> l
    in
    match skip rest with
    | (Ident _, _) :: (LParen, _) :: _ -> false
    | (Ident _, _) :: _ -> true
    | _ -> false
  end
  else
  match ty_kws_len p.toks with
  | 0 -> false
  | n ->
    let rec drop k l = if k <= 0 then l else match l with _ :: r -> drop (k - 1) r | [] -> [] in
    let rec skip_stars l = match l with (Star, _) :: r -> skip_stars r | _ -> l in
    let rec skip_bangs l = match l with (Bang, _) :: r -> skip_bangs r | _ -> l in
    let after_ty = drop n p.toks in
    let tyname_ok =
      match drop (n - 1) p.toks with
      | (Ident s, _) :: _ -> List.mem s p.tynames
      | (Keyword _, _) :: _ -> true   (* 多词别名（short int 等）：必为类型 *)
      | _ -> false
    in
    (match after_ty with
     | (Star, _) :: _ | (Bang, _) :: _ ->
       tyname_ok &&
       (match skip_bangs (skip_stars after_ty) with
        | (Ident _, _) :: _ -> true
        | (Keyword (KConst | KFrac | KUnreduced | KRef), _) :: _ -> true
        | _ -> false)
     | (Ident _, _) :: _ -> true
     | (Keyword (KConst | KFrac | KUnreduced | KRef), _) :: _ -> true
     | _ -> false)
(* for 头部声明（const/frac/unred 允许，无 variable） *)
and parse_for_decl p tp =
  let ty = parse_ty p in
  let (is_const, _is_frac, _is_unred, _is_ref) = parse_modifiers p in
  let name = expect_ident p "variable name" in
  let init =
    (match p.toks with
     | (Assign, _) :: _ ->
       let (_t, _tp) = next p in
       Some (parse_expr p)
     | _ -> None)
  in
  (match is_const, init with
   | true, None -> err tp "const requires an initializer"
   | _ -> ());
  FIDecl (is_const, name, ty, init, tp)

(* 判断是否为"裸声明"形状错误（类型名开头但后续不构成合法声明） *)
and check_bare_decl p =
  (* 类型词后紧跟另一类型词：重复/混写（int int、i32 int）单独提示 *)
  let second_ty =
    match peek2 p with
    | (Keyword k, _) -> is_alias_kw k
    | (Ident s, _) -> List.mem s type_names
    | _ -> false
  in
  match p.toks with
  | (_, tp) :: _ when second_ty ->
    err tp "duplicate base type: a declaration has exactly one base type (alias and width names cannot be mixed)"
  | (Ident s, tp) :: _ when List.mem s type_names && s <> "void" ->
    err tp (Printf.sprintf
              "declaration syntax: TYPE (const)? (frac)? NAME [= init] (e.g. %s x = 1 / %s x / %s const k = 2 / %s arr[8] = 1,2 / %s lst[])"
              s s s s s)
  | (Keyword (KShort | KLong | KUshort | KUlong | KInt | KUint | KHalf | KFloat | KDouble | KQuad), tp) :: _ ->
    err tp (Printf.sprintf
              "declaration syntax: TYPE (const)? (frac)? NAME [= init] (e.g. int x = 1 / short k / long const frac r = 1/2 / double arr[8] = 1,2 / uint lst[])")
  | _ -> ()

and parse_stmt p =
  let (tk, tp) = peek p in
  match tk with
  | Ident _ when looks_like_decl p -> parse_decl p tp
  | Keyword k when is_alias_kw k && looks_like_decl p -> parse_decl p tp
  | Keyword k when is_alias_kw k ->
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
  | Keyword KUnsafe ->
    (* unsafe 块：允许指针算术（块内语句平铺，语义与普通块一致） *)
    ignore (next p);
    let b = parse_block p in
    SUnsafe (b, tp)
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
      if !sep <> None then err tp "duplicate sep parameter in output";
      sep := Some v
    end
    else begin
      if !end_ <> None then err tp "duplicate end parameter in output";
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
       | (_, tp') -> err tp' "named output parameters (sep/end) must come last")
    | (_, tp') -> err tp' "expected ',' or ')' to end the output argument list"
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
       | (_, tp') -> err tp' "expected ',' or ')' to end the output argument list")
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
       | (_, tp') -> err tp' "input's delim parameter must come last")
    | _ ->
      let t =
        if looks_like_decl p then begin
          let ty = parse_ty p in
          let (_c, _f, _u, _r) = parse_modifiers p in
          let name = expect_ident p "variable name" in
          InNew (name, ty, tp)
        end
        else begin
          let name = expect_ident p "variable name" in
          InUse (name, tp)
        end
      in
      targets := t :: !targets;
      (match peek p with
       | (Comma, _) -> ignore (next p); go ()
       | (RParen, _) -> ignore (next p)
       | (_, tp') -> err tp' "expected ',' or ')' to end the input target list")
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

(* 顶层项是函数定义还是声明：类型词后（可跳过 * 指针后缀与
   const/frac/unred 修饰）跟标识符，标识符后是 '(' 为函数定义
   （i32 f(...) / i32* f(...)），是 '[' 为数组/列表声明。
   模块路径返回类型 m::Point f(...)：qpath + 修饰 + 名字 + '(' *)
let top_is_fn p =
  if is_qpath_start p.toks then begin
    let (_segs, rest) = scan_qpath p.toks in
    let rec skip l =
      match l with
      | (Star, _) :: r | (Bang, _) :: r -> skip r
      | (Keyword (KConst | KFrac | KUnreduced | KRef), _) :: r -> skip r
      | _ -> l
    in
    match skip rest with
    | (Ident _, _) :: (LParen, _) :: _ -> true
    | _ -> false
  end
  else
  let toks = p.toks in
  let n = ty_kws_len toks in
  if n = 0 then false
  else begin
    let rec drop k l = if k <= 0 then l else match l with _ :: r -> drop (k - 1) r | [] -> [] in
    let rec skip_stars l = match l with (Star, _) :: r -> skip_stars r | _ -> l in
    let rec skip_bangs l = match l with (Bang, _) :: r -> skip_bangs r | _ -> l in
    let rec skip_mods l =
      match l with
      | (Keyword (KConst | KFrac | KUnreduced | KRef), _) :: r -> skip_mods r
      | _ -> l
    in
    let tyname_ok =
      match drop (n - 1) toks with
      | (Ident s, _) :: _ -> List.mem s p.tynames
      | (Keyword _, _) :: _ -> true   (* 多词别名（short int 等）：必为类型 *)
      | _ -> false
    in
    tyname_ok &&
    (match skip_mods (skip_bangs (skip_stars (drop n toks))) with
     | (Ident _, _) :: (LParen, _) :: _ -> true
     | _ -> false)
  end

(* 函数参数：
   标量：<类型> (frac)? 名字
   数组：<类型> 名字[长度]（长度为字面量或之前的参数名）
   列表：<类型> 名字[]（中括号必须为空） *)
let parse_param p =
  let (tk0, tp0) = peek p in
  (* 函数类型允许作参数类型（new2.md 9a）：i32(i32,i32) g *)
  let pt = parse_ty ~allow_fun:true p in
  let (isc, is_frac, is_unred, is_ref) = parse_modifiers p in
  if isc then err tp0 "parameters do not support const";
  if is_unred then err tp0 "parameters do not support unred";
  if is_ref && is_frac then err tp0 "ref parameters do not support the frac modifier";
  let name = expect_ident p "parameter name" in
  match peek p with
  | (LBracket, lp) ->
    ignore (next p);
    if is_frac then err lp "array/list parameters do not support the frac modifier";
    if is_ref then err lp "ref parameters support scalar/string types only (arrays/lists use move for zero-copy)";
    (match peek p with
     | (RBracket, _) ->
       ignore (next p);
       { pname = name; pty = pt; pfrac = false; pseq = PList; pref = false; ppos = lp }
     | _ ->
       let len = parse_expr p in
       expect p RBracket "]";
       { pname = name; pty = pt; pfrac = false; pseq = PArray len; pref = false; ppos = lp })
  | _ ->
    { pname = name; pty = pt; pfrac = is_frac; pseq = PScalar; pref = is_ref; ppos = tp0 }

(* struct 字段块：每行一个字段；块以 DEDENT 结束 *)
let rec parse_struct_fields p acc =
  skip_trivia p;
  match peek p with
  | (Indent, _) -> ignore (next p); parse_struct_fields p acc
  | (Dedent, _) -> ignore (next p); List.rev acc
  | (Eof, _) -> List.rev acc
  | (Ident _, ftp)
  | (Keyword (KShort | KLong | KUshort | KUlong | KInt | KUint | KHalf | KFloat | KDouble | KQuad), ftp) ->
    (* 字段类型：任意标识符（基础宽度类型或已声明 struct 名，typeck 校验）
       或多词传统别名（short int 等），可带 * 指针后缀；函数类型允许（9a） *)
    let fty = parse_ty ~allow_fun:true p in
    let name = expect_ident p "field name" in
    let fseq =
      match peek p with
      | (LBracket, lp) ->
        ignore (next p);
        (match peek p with
         | (RBracket, _) -> ignore (next p); PList
         | _ ->
           let len = parse_expr p in
           expect p RBracket "]";
           PArray len)
      | _ -> PScalar
    in
    let fdefault =
      match peek p with
      | (Assign, _) -> ignore (next p); Some (parse_expr p)
      | _ -> None
    in
    (match fseq with
     | PScalar -> ()
     | _ ->
       (match fdefault with
        | Some _ -> err ftp "array/list struct fields cannot have default values"
        | None -> ()));
    end_of_stmt p;
    parse_struct_fields p ({ fname = name; fty; fseq; fdefault; fpos = ftp } :: acc)
  | (_, tp) -> err tp "struct field syntax: TYPE NAME [= default]"

(* 模块体：缩进块内每行一个顶层项（fn/struct/mod/use/...；可嵌套 mod） *)
and parse_item_block p =
  skip_trivia p;
  match peek p with
  | (Indent, _) ->
    ignore (next p);
    let rec go acc =
      skip_trivia p;
      match peek p with
      | (Dedent, _) -> ignore (next p); List.rev acc
      | (Eof, tp') -> err tp' "unexpected end of input (unclosed module body)"
      | _ ->
        (try go (parse_item p :: acc)
         with ParseError (ep, em) ->
           record_err p ep em;
           sync_top p;
           go acc)
    in
    go []
  | (_, tp') -> err tp' "expected an indented module body (mod name + newline + indent)"

(* 旧 use 文件语法尾部：校验 .zfy 后缀与 import/as 修饰 *)
and finish_legacy_use p tp buf =
  if not (Filename.check_suffix (Buffer.contents buf) ".zfy") then
    err tp "use file name must end with .zfy";
  let import =
    if is_kw p KImport then begin
      ignore (next p);
      Some (expect_ident p "module name")
    end else None
  in
  let alias =
    if is_kw p KAs then begin
      ignore (next p);
      Some (expect_ident p "alias")
    end else None
  in
  end_of_stmt p;
  IUse { path = Buffer.contents buf; import; alias; pos = tp }

and parse_item p =
  skip_trivia p;
  let (tk, tp) = peek p in
  match tk with
  | Keyword KPub ->
    (* pub 修饰：仅模块内顶层合法（root 顶层 pub 由 resolve 忽略并告警容忍） *)
    ignore (next p);
    IPub (parse_item p, tp)
  | Keyword KMod ->
    (* mod name;  → 文件模块（body 在 name.zfy / name/mod.zfy，resolve 加载）
       mod name（换行缩进块）→ 内联模块，块内为顶层项，可嵌套 *)
    ignore (next p);
    let name = expect_ident p "module name" in
    (match peek p with
     | (Semicolon, _) ->
       (* mod name;：文件模块，显式分号收尾 *)
       ignore (next p);
       end_of_stmt p;
       IModFile (name, tp)
     | _ ->
       let rec skip_nl () =
         match peek p with
         | (Newline, _) -> ignore (next p); skip_nl ()
         | _ -> ()
       in
       skip_nl ();
       (match peek p with
        | (Indent, _) ->
          let items = parse_item_block p in
          IMod (name, items, tp)
        | _ ->
          (* 文件模块：语句随换行结束 *)
          IModFile (name, tp)))
  | Keyword KUse ->
    (* use 目标两态：
       - 新路径语法 use a::b::item [as x] / use a::b::{x, y as z} / use a::b [as m]
         （Ident 后跟相邻两个 Colon）
       - 旧文件语法 use 文件名.zfy [import 模块名] [as 别名]（legacy），
         支持 ./ ../ 前缀（相对路径） *)
    ignore (next p);
    (match fst (peek p) with
     | Dot ->
       (* ---- 旧文件语法（legacy）：./ ../ 前缀 ---- *)
       let buf = Buffer.create 16 in
       let rec dots n =
         match peek p with
         | (Dot, _) when n < 2 -> ignore (next p); dots (n + 1)
         | _ -> n
       in
       let n = dots 0 in
       expect p Slash "/";
       for _ = 1 to n do Buffer.add_string buf "../" done;
       Buffer.add_string buf (expect_ident p "file name");
       let rec ext () =
         match peek p with
         | (Dot, _) ->
           ignore (next p);
           Buffer.add_char buf '.';
           Buffer.add_string buf (expect_ident p "extension");
           ext ()
         | _ -> ()
       in
       ext ();
       finish_legacy_use p tp buf
     | _ ->
       let first = expect_ident p "use target" in
       (match fst (peek p) with
        | Colon ->
          (* ---- 新路径语法 ---- *)
          let rec go_segs acc =
            match fst (peek p), fst (peek2 p) with
            | Colon, Colon ->
              (match fst (peek3 p) with
               | Ident _ ->
                 ignore (next p); ignore (next p);
                 go_segs (expect_ident p "path segment" :: acc)
               | LBrace -> List.rev acc   (* a::b::{x}：停在 '{' 前的 '::' *)
               | _ ->
                 err (snd (peek3 p))
                   "expected a path segment or '{' after '::'")
            | _ -> List.rev acc
          in
          let segs = first :: go_segs [] in
          (match peek p with
           | (Colon, _) ->
             (* 分组 use a::b::{x, y as z}；go_segs 停在 '::' 前 *)
             ignore (next p); ignore (next p);
             expect p LBrace "'{'";
             let rec go_binds acc =
               let (orig, opos) =
                 match peek p with
                 | (Ident s, sp) -> ignore (next p); (s, sp)
                 | (_, tp') -> err tp' "expected a use binding (identifier)"
               in
               let local =
                 if is_kw p KAs then begin
                   ignore (next p); expect_ident p "alias"
                 end else orig
               in
               let acc = (local, segs @ [ orig ], opos) :: acc in
               match peek p with
               | (Comma, _) -> ignore (next p); go_binds acc
               | (RBrace, _) -> ignore (next p); List.rev acc
               | (_, tp') -> err tp' "expected ',' or '}' to end the use group"
             in
             let binds = go_binds [] in
             end_of_stmt p;
             IUseP { binds; pos = tp }
           | _ ->
             (* 单路径 use a::b::item [as x]；无 as 时绑定最后一段名 *)
             let local =
               if is_kw p KAs then begin
                 ignore (next p); expect_ident p "alias"
               end else List.nth segs (List.length segs - 1)
             in
             end_of_stmt p;
             IUseP { binds = [ (local, segs, tp) ]; pos = tp })
        | _ ->
          (* ---- 旧文件语法（legacy）：首段文件名 + .zfy ---- *)
          let buf = Buffer.create 16 in
          Buffer.add_string buf first;
          let rec ext () =
            match peek p with
            | (Dot, _) ->
              ignore (next p);
              Buffer.add_char buf '.';
              Buffer.add_string buf (expect_ident p "extension");
              ext ()
            | _ -> ()
          in
          ext ();
          finish_legacy_use p tp buf))

  | Keyword KStruct ->
    (* struct 声明：struct [packed] 名字 缩进块（字段：类型 名字 [= 默认值]，
       或 类型 名字[N] / 类型 名字[]） *)
    ignore (next p);
    let packed =
      match peek p with
      | (Keyword KPacked, _) -> ignore (next p); true
      | _ -> false
    in
    let name = expect_ident p "struct name" in
    let fields = parse_struct_fields p [] in
    p.tynames <- name :: p.tynames;
    IStruct { name; packed; fields; pos = tp }
  | Keyword KExtern ->
    (* extern "C"：缩进块内每行一个 C 函数声明（类型 (frac)? 名字(参数)），
       解析为多个 IExtern 函数（块结构不保留） *)
    ignore (next p);
    (match peek p with
     | (StrLit "C", _) -> ignore (next p)
     | (StrLit s, sp) ->
       err sp (Printf.sprintf "extern supports only \"C\", got \"%s\"" s)
     | (_, sp) -> err sp "expected \"C\" after extern");
    skip_trivia p;
    let rec go acc =
      match peek p with
      | (Indent, _) -> ignore (next p); go acc
      | (Dedent, _) -> ignore (next p); List.rev acc
      | (Eof, _) -> List.rev acc
      | _ ->
        let rt = parse_ty p in
        let (_c, rf, _u, _r2) = parse_modifiers p in
        let name = expect_ident p "extern function name" in
        expect p LParen "(";
        let params =
          let rec go2 acc2 =
            match peek p with
            | (RParen, _) -> ignore (next p); List.rev acc2
            | _ ->
              let pd = parse_param p in
              (match peek p with
               | (Comma, _) -> ignore (next p); go2 (pd :: acc2)
               | (RParen, _) -> ignore (next p); List.rev (pd :: acc2)
               | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
          in
          go2 []
        in
        end_of_stmt p;
        go ({ ename = name; eparams = params; eret = rt; erfrac = rf; epos = tp } :: acc)
    in
    IExtern { funcs = go []; pos = tp }
  | Keyword KType ->
    (* type 别名：type 名 = 类型（类型可含 * 指针后缀与函数类型） *)
    ignore (next p);
    let name = expect_ident p "type alias" in
    expect p Assign "=";
    let t = parse_ty ~allow_fun:true p in
    end_of_stmt p;
    p.tynames <- name :: p.tynames;
    ITypeAlias { name; ty = t; pos = tp }
  | Ident _ | Keyword (KShort | KLong | KUshort | KUlong | KInt | KUint | KHalf | KFloat | KDouble | KQuad | KFrac | KConst | KUnreduced) ->
    if top_is_fn p then begin
      (* 函数定义：类型 (frac)? 名字(参数) 块 *)
      let ty0 = parse_ty p in
      let (_c, rf, _u, _r3) = parse_modifiers p in
      let name = expect_ident p "function name" in
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
             | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
        in
        go []
      in
      let body = parse_block p in
      IFn { name; params; ret = Some ty0; rfrac = rf; body; pos = tp }
    end
    else begin
      (* 顶层声明：const/frac/unred 标量、数组、列表均可 *)
      let d = parse_decl p tp in
      IDecl (d, tp)
    end
  | _ -> err tp (Printf.sprintf "expected a top-level item (function/use/declaration), got %s" (pp_token tk))

let parse_program p =
  let rec go acc =
    skip_trivia p;
    match peek p with
    | (Eof, _) -> List.rev acc
    | _ ->
      (* 顶层项级错误恢复：记录后跳到下一顶层项继续（多错误收集） *)
      (try go (parse_item p :: acc)
       with ParseError (ep, em) ->
         record_err p ep em;
         sync_top p;
         go acc)
  in
  go []
