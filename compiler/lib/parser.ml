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

(* ui 语句唯一编号（v3.18）：合成隐藏变量名防碰撞 *)
let ui_seq = ref 0

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

let expect_ident_pos p what =
  let (tk, tp) = peek p in
  match tk with
  | Ident s -> ignore (next p); (s, tp)
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

(* 类型词长度（0 = 不是类型开头）。类型为单词 Ident：
   内建宽度类型或用户 struct/type 名（后者由 typeck 校验）。
   （new.md 2026-10-10：int/long/short 等传统别名关键词已全部删除） *)
let ty_kws_len (toks : (token * pos) list) : int =
  match toks with
  | (Ident _, _) :: _ -> 1
  | _ -> 0

(* 类型词后紧跟另一类型词：重复报错（如 i32 i32） *)
let check_no_dup_ty p =
  match peek p with
  | (Ident s, tp) when List.mem s type_names ->
    err tp "duplicate base type: a declaration has exactly one base type"
  | _ -> ()

(* token 层跳过类型后缀：* 指针、!、T* const、const/frac/unred/ref 修饰、
   类型侧 []/[N] 组（长度表达式内的中括号按平衡计数跳过）。
   供 looks_like_decl / top_is_fn 前瞻判定使用（w-014 #1） *)
let rec skip_ty_suffix_toks (l : (Tokens.token * Tokens.pos) list)
    : (Tokens.token * Tokens.pos) list =
  match l with
  | (Star, _) :: r | (Bang, _) :: r -> skip_ty_suffix_toks r
  | (Keyword (KConst | KFrac | KUnreduced | KRef), _) :: r -> skip_ty_suffix_toks r
  | (LBracket, _) :: _ ->
    let rec skip_balanced depth l =
      match l with
      | (LBracket, _) :: r -> skip_balanced (depth + 1) r
      | (RBracket, _) :: r -> if depth <= 1 then r else skip_balanced (depth - 1) r
      | [] -> []
      | _ :: r -> skip_balanced depth r
    in
    skip_ty_suffix_toks (skip_balanced 0 l)
  | _ -> l

(* 类型实参 <...> 平衡跳过（泛型实例化 Box<i32>/Box<Box<i32>>）。
   仅在"类型词已确认"的前瞻上下文（top_is_fn）使用——类型词不能开始
   表达式，此处 < 只能是类型实参列表，不与比较运算混淆 *)
let skip_tyargs_toks (l : (Tokens.token * Tokens.pos) list)
    : (Tokens.token * Tokens.pos) list =
  match l with
  | (Tokens.Lt, _) :: _ ->
    let rec go depth l =
      match l with
      | (Tokens.Lt, _) :: r -> go (depth + 1) r
      | (Tokens.Gt, _) :: r -> if depth <= 1 then r else go (depth - 1) r
      | [] -> []
      | _ :: r -> go depth r
    in
    go 0 l
  | _ -> l

(* 前瞻综合跳过：类型后缀与类型实参交替（Box<i32>[] f(...) 等形态） *)
let rec skip_ty_lookahead_toks (l : (Tokens.token * Tokens.pos) list)
    : (Tokens.token * Tokens.pos) list =
  let l2 = skip_ty_suffix_toks l in
  let l3 = skip_tyargs_toks l2 in
  if l3 == l2 then l2 else skip_ty_lookahead_toks l3

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
      (* T* const：指向 const 的指针（用户拍板：const 移到星号后；
         T* const* 逐层叠加为 TPtr(TPtrC(...))）。
         const 后无星号时留给声明修饰符处理（如 T const 常量变量） *)
      (match peek p with
       | (Keyword KConst, cp) ->
         ignore (next p);
         suffixes (TPtrC (base, cp))
       | _ -> suffixes (TPtr (base, tp)))
    | (Bang, _) ->
      ignore (next p);
      suffixes (TErr (base, tp))
    | (LBracket, lp) ->
      (* 类型后缀数组/列表形式（w-014 #1）：T[] 动态、T[N] 定长；
         可叠加（T[][] = 列表的列表，T[3][4] = 定长二维）。
         类型侧长度限整数字面量（parse_ty 链先于表达式层；与 conv_ty
         对类型位置 TSeqN 的字面量要求一致），完整表达式长度仅在
         名字侧组（声明/参数）可用 *)
      ignore (next p);
      (match peek p with
       | (RBracket, _) ->
         ignore (next p);
         suffixes (TSeq (base, lp))
       | (IntLit n, np) ->
         ignore (next p);
         expect p RBracket "]";
         if n < 0L then err np "array length must be non-negative";
         suffixes (TSeqN (base, EInt (n, np), lp))
       | (_, np) -> err np "type-position array length must be an integer literal (T[N])")
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
    (* 泛型实例化 Box<i32>（仅类型位置）：Ident 后跟 < 走类型实参 *)
    let base =
      match peek p with
      | (Lt, _) -> parse_tyargs p s tp
      | _ -> TNamed (s, tp)
    in
    suffixes base
  | Keyword KFrac ->
    (* frac 作类型（cast 目标等类型位置）：单写 = i32 frac（v3 2026-10-11）；
       conv_ty 侧把 TNamed "frac" 解为 TFrac (TInt 32) *)
    ignore (next p);
    TNamed ("frac", tp)
  | Keyword KFn ->
    (* 闭包类型（v3.7 函数式轮）：fn(T1, T2) -> R——与函数指针类型
       T(params)（无 fn 前缀，仅 type 别名处）并存；闭包值 = {code, env} *)
    ignore (next p);
    expect p LParen "(";
    let ptys =
      let rec go acc =
        match peek p with
        | (RParen, _) -> ignore (next p); List.rev acc
        | _ ->
          let t = parse_ty p in
          (match peek p with
           | (Comma, _) -> ignore (next p); go (t :: acc)
           | (RParen, _) -> ignore (next p); List.rev (t :: acc)
           | (_, tp') -> err tp' "expected ',' or ')' to end the closure parameter type list")
      in
      go []
    in
    expect p ThinArrow "->";
    let ret = parse_ty p in
    TClo (ptys, ret, tp)
  | Keyword (KArray | KList) ->
    err tp "'array'/'list' keywords removed: arrays are written T a[N], lists T a[]"
  | Star ->
    err tp "'*' must follow a type to form a pointer (syntax T*, e.g. i32* p)"
  | LBracket ->
    err tp "'[]T' / '[T;N]' (slice/array type) syntax removed"
  | _ -> err tp (Printf.sprintf "expected a type, got %s" (pp_token tk))

(* 泛型类型参数列表 <T, U> / <T: num, U: cmp>（v3.15 约束）：泛型函数/struct
   声明处（仅 Ident 名单 + 可选 `: 约束名`，约束 ∈ num/cmp/any） *)
and parse_tparams p =
  expect p Lt "<";
  let parse_constr npos =
    match peek p with
    | (Ident c, _) when c = "num" || c = "cmp" || c = "any" ->
      ignore (next p); c
    | (_, cp) ->
      err cp "expected a constraint (num/cmp/any) after ':' for type parameter"
  in
  let rec go acc =
    let n = expect_ident p "type parameter" in
    let c =
      match peek p with
      | (Colon, _) -> ignore (next p); parse_constr n
      | _ -> "any"
    in
    let acc = (n, c) :: acc in
    match peek p with
    | (Comma, _) -> ignore (next p); go acc
    | (Gt, _) -> ignore (next p); List.rev acc
    | (_, tp) -> err tp "expected ',' or '>' to end the type parameter list"
  in
  let tps = go [] in
  (* 泛型参数注册为已知类型名：fn <T> 的返回类型/参数/函数体内 let T 声明、
     struct Box<T> 的字段类型都按类型名识别 *)
  p.tynames <- List.map fst tps @ p.tynames;
  tps

(* 泛型实参列表 <i32, T*>：类型位置 T 后跟 <（仅类型位置无歧义，表达式
   比较不受影响） *)
and parse_tyargs p base_name npos =
  expect p Lt "<";
  let rec go acc =
    let t = parse_ty p in
    let acc = t :: acc in
    match peek p with
    | (Comma, _) -> ignore (next p); go acc
    | (Gt, _) -> ignore (next p); List.rev acc
    | (Shr, _) ->
      (* 嵌套泛型闭包 Box<Box<i32>>：词法的 >> 在此拆半——只消耗一层 >，
         把单个 > 塞回 token 流供外层闭合 *)
      ignore (next p);
      p.toks <- (Gt, npos) :: p.toks;
      List.rev acc
    | (_, tp) -> err tp "expected ',' or '>' to end the type argument list"
  in
  let targs = go [] in
  TApp (base_name, targs, npos)

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
  | _ -> parse_bor p

(* 位运算层级（C 优先级）：| < xor < & ，均低于 ==/!= 高于 or/and。
   xor 用关键字（用户拍板 2026-10-11），^ 仍为解引用后缀；
   & 一元取地址在 parse_unary，二元位与在此按位置区分（左值完整后遇 & ） *)
and parse_bor p =
  let l = parse_bxor p in
  let rec go l =
    match peek p with
    | (Pipe, tp) ->
      ignore (next p);
      go (EBin (BitOr, l, parse_bxor p, tp))
    | _ -> l
  in
  go l

and parse_bxor p =
  let l = parse_band p in
  let rec go l =
    match peek p with
    | (Keyword KXor, tp) ->
      ignore (next p);
      go (EBin (Xor, l, parse_band p, tp))
    | _ -> l
  in
  go l

and parse_band p =
  let l = parse_eq p in
  let rec go l =
    match peek p with
    | (Amp, tp) ->
      ignore (next p);
      go (EBin (BitAnd, l, parse_eq p, tp))
    | _ -> l
  in
  go l

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
  let l = parse_shift p in
  let (tk, tp) = peek p in
  let op =
    match tk with
    | Lt -> Some Lt | Gt -> Some Gt | Le -> Some Le | Ge -> Some Ge | _ -> None
  in
  match op with
  | None -> l
  | Some op ->
    ignore (next p);
    let r = parse_shift p in
    EBin (op, l, r, tp) (* 不结合 *)

(* 移位（C 优先级：低于加减、高于比较） *)
and parse_shift p =
  let l = parse_add p in
  let rec go l =
    let (tk, tp) = peek p in
    match tk with
    | Shl ->
      ignore (next p);
      go (EBin (Shl, l, parse_add p, tp))
    | Shr ->
      ignore (next p);
      go (EBin (Shr, l, parse_add p, tp))
    | _ -> l
  in
  go l

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
  let l = parse_pow p in
  let rec go l =
    let (tk, tp) = peek p in
    match tk with
    | Star ->
      ignore (next p);
      let r = parse_pow p in
      go (EBin (Mul, l, r, tp))
    | Slash ->
      ignore (next p);
      let r = parse_pow p in
      go (EBin (Div, l, r, tp))
    | Percent ->
      ignore (next p);
      let r = parse_pow p in
      go (EBin (Mod, l, r, tp))
    | _ -> l
  in
  go l

(* ** 幂（v3.3）：右结合——x**2**3 == x**(2**3)；数学优先级：
   高于 * /，且一元负号左侧绑定更松：-x**2 == -(x**2)。
   底数经 parse_unary（允许 |x|**2 / (-x)**2 写法），
   指数递归 parse_pow（右结合 + 允许 2**-3） *)
and parse_pow p =
  let l = parse_unary p in
  match peek p with
  | (Pow, tp) ->
    ignore (next p);
    EBin (Pow, l, parse_pow p, tp)
  | _ -> l

and parse_unary p =
  match peek p with
  | (Minus, tp) ->
    (* 负号操作数取 parse_pow 层：-x**2 == -(x**2)（数学约定） *)
    ignore (next p);
    EUn (Neg, parse_pow p, tp)
  | (Pipe, tp) ->
    (* |e| 绝对值（v3.3）：脱糖为内建 abs(e)（复用 abs 重载：
       整数同宽取非负、浮点 @fabs/@fabsf）。
       内层解析到 & 层为止——xor/| 层会把闭 | 吃成按位或；
       需要按位或作被绝对值时用括号：|(a | b)| *)
    ignore (next p);
    let e = parse_band p in
    expect p Pipe "|";
    ECall (EVar ("abs", tp), [ CPos e ], tp)
  | (Amp, tp) -> ignore (next p); EAddrOf (parse_unary p, tp)
  | (Tilde, tp) -> ignore (next p); EUn (BitNot, parse_unary p, tp)
  | (Keyword KCopy, tp) ->
    (* copy x：显式深拷贝标记（struct 赋值必须，new.md #1）。
       操作数取 postfix 层：copy x + y == (copy x) + y *)
    ignore (next p);
    ECopyOf (parse_postfix p, tp)
  | (Keyword KMove, tp) ->
    (* move x：显式所有权转移标记（源变量此后不可用） *)
    ignore (next p);
    EMoveOf (parse_postfix p, tp)
  | (Keyword KBorrow, tp) ->
    (* borrow e：只读借用（T* const），借用期内源不可被 move；
       borrow(x) 与 borrow x 均合法（parse_postfix 吃掉括号） *)
    ignore (next p);
    EBorrow (parse_postfix p, tp)
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
         | (Comma, tp3) ->
           (* s[a, b, step] 三参逗号形式不存在（w-021 DX） *)
           err tp3 "slice takes at most 2 positions: s[a, b] or s[a, b:step] (step uses ':', not a third ',')"
         | _ -> None
       in
       expect p RBracket "]";
       parse_postfix_rest p (ESlice (e, e1, e2, step, tp))
     | (RBracket, _) ->
       ignore (next p);
       parse_postfix_rest p (EIndex (e, e1, tp))
     | (_, tp') -> err tp' "expected ',' or ']'")
  | Dot ->
    (* 点号访问（w-014 #8）：
       - 基为 EVar：合并为 dotted 名（既有编码——struct 字段链 a.b.c 与
         use 命名空间 t.item 共用，typeck 按变量/命名空间分派）
       - 基为其他表达式（ps[1].x / f().x / p^.x）：产出 EField 节点，
         typeck 对基求值后取字段 *)
    (match e with
     | EInt _ ->
       (* `1..3` 会被切成 `1` `.` `.`——用户把 Python/C 切片语法带进来了，
          提前拦截并给出本语言切片语法（w-020 DX） *)
       err tp "invalid syntax 'a..b': slice syntax is s[a,b:step] (comma-separated, both ends inclusive)"
     | _ -> ());
    ignore (next p);
    (* 段名允许关键字拼写字面（如内建 timer.remove 的 "remove"——点号后
       跟关键字按其拼写当普通段名，避免与语句关键字冲突） *)
    let seg =
      let (tk, tp) = peek p in
      match tk with
      | Ident s -> ignore (next p); s
      | Keyword KRemove -> ignore (next p); "remove"
      | _ -> err tp (Printf.sprintf "expected namespace member or field name (identifier), got %s" (pp_token tk))
    in
    (match e with
     | EVar (base, _) -> parse_postfix_rest p (EVar (base ^ "." ^ seg, tp))
     | _ -> parse_postfix_rest p (EField (e, seg, tp)))
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
  | BigIntLit s -> ignore (next p); EBigInt (s, tp)
  | RDecLit (num, den) ->
    (* 循环小数字面量 (前缀,循节,)：词法已折算为分数 num/den——
       与 (n/d) 分数字面量同语义（v3.29）：frac 期望精确构造、float 期望
       实数除、int 期望常量截断（"按目标宽度截取不四舍五入"） *)
    ignore (next p);
    EFracLit (num, den, tp)
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
  | Keyword KRemove ->
    (* remove(数组/列表, 下标)：表达式（v3 2026-10-11）——返回被删元素
       （深拷贝副本），数组槽位填零、列表删除并左移；裸语句由 typeck 拒绝 *)
    ignore (next p);
    expect p LParen "(";
    let a = parse_expr p in
    expect p Comma ",";
    let b = parse_expr p in
    expect p RParen ")";
    ERemove (a, b, tp)
  | Keyword KFn ->
    (* lambda（v3.7 函数式轮），解析体见 parse_lambda_after_fn *)
    ignore (next p);
    parse_lambda_after_fn p tp
  | Ident s ->
    ignore (next p);
    let s = qpath_extend p s in    (* 模块路径引用 m::f / m::Point(...) *)
    parse_postfix_rest p (EVar (s, tp))
  | LParen ->
    ignore (next p);
    let e = parse_expr p in
    expect p RParen ")";
    (* (n/d) 分数字面量（v3.29 语义反转）：括号包住的两个整数字面量除式
       升级为分数字面量 EFracLit——不带括号的 1/4 永远是普通除法。
       仅匹配裸整数字面量两侧：(-1/4)（一元负号）与 (1/-4) 不匹配
       （保持除法语义）；分母为 0 同样保持除法（由 typeck 报除零） *)
    (match e with
     | EBin (Ast.Div, EInt (a, _), EInt (b, ep), _) when b <> 0L ->
       EFracLit (a, b, ep)
     | _ -> e)
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
   仅 extern "C" 行（C 签名）仍用旧式；zfy 声明/参数一律走 parse_let_head *)
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

(* let 声明头（new.md 2026-10-10）：let (类型)? (frac)? (const)? (unred)? 名字。
   固定顺序：类型 → frac → const → unred；类型可省（由初值推断，
   或 frac 修饰隐含 i32 基）；返回 (类型, is_frac, is_const, is_unred) *)
and parse_let_head p =
  let ty_opt =
    match peek p with
    | (Keyword KFn, _) when (match peek2 p with (LParen, _) -> true | _ -> false) ->
      (* 闭包类型变量（v3.7）：let fn(T...) -> R 名 = ... *)
      Some (parse_ty p)
    | (Ident s, _) when List.mem s p.tynames -> Some (parse_ty ~allow_fun:true p)
    (* 跨文件类型名（模块导入的 struct/type 别名）：Ident 后紧跟 Ident
       只能是"类型 名字"形状（无类型推断形式名字后必须是 = 或修饰符） *)
    | (Ident _, _) ->
      (match peek2 p with
       | (Ident _, _) -> Some (parse_ty ~allow_fun:true p)
       (* 跨文件类型名的数组/列表/指针/错误值/泛型后缀：Video[] / T* / T! / Box<i32> *)
       | (LBracket, _) | (Star, _) | (Bang, _) | (Lt, _) ->
         Some (parse_ty ~allow_fun:true p)
       | _ -> None)
    | _ when is_qpath_start p.toks && looks_like_ty_path p -> Some (parse_ty ~allow_fun:true p)
    | _ -> None
  in
  let is_frac =
    match peek p with
    | (Keyword KFrac, _) -> ignore (next p); true
    | _ -> false
  in
  let is_const =
    match peek p with
    | (Keyword KConst, _) -> ignore (next p); true
    | _ -> false
  in
  let is_unred =
    match peek p with
    | (Keyword KUnreduced, _) -> ignore (next p); true
    | _ -> false
  in
  (* 修饰符乱序（如 let unred frac x）：头部提前结束会误报 "expected
     variable name"，这里给出顺序提示（w-021 DX） *)
  (match peek p with
   | (Keyword (KFrac | KConst | KUnreduced), tp) ->
     err tp "declaration modifier order must be: [TYPE] frac const unred (e.g. let i32 frac const unred x)"
   | (Ident s, tp) when List.mem s p.tynames ->
     (* let const Outer o：const 在类型前，类型词被当变量名（w-021 DX） *)
     (match peek2 p with
      | (Ident _, _) ->
        err tp "declaration order: the type must come right after 'let' (let [TYPE] frac const unred NAME)"
      | _ -> ())
   | _ -> ());
  (ty_opt, is_frac, is_const, is_unred)

(* qpath 类型（m::Point）：Ident '::' Ident 形状且首段非调用（无 '('） *)
and looks_like_ty_path p =
  if is_qpath_start p.toks then
    let (_segs, rest) = scan_qpath p.toks in
    match rest with
    | (LParen, _) :: _ -> false
    | (Ident _, _) :: _ -> true
    | (Star, _) :: _ | (Bang, _) :: _ | (LBracket, _) :: _ -> true
    | _ -> false
  else false

(* 类型侧中括号组收集（w-014 #1）：TSeq/TSeqN 包装逐层剥出，
   返回 (基础类型, 组列表)（组按从外到内序；None = []，Some len = [len]） *)
and collect_ty_groups (ty : ty) : ty * (expr option list) =
  match ty with
  | TSeq (t, _) -> let (b, gs) = collect_ty_groups t in (b, None :: gs)
  | TSeqN (t, len, _) -> let (b, gs) = collect_ty_groups t in (b, Some len :: gs)
  | _ -> (ty, [])

(* 组 -> 类型包装（折元素类型用）：None → TSeq，Some len → TSeqN。
   位置用组内原 pos（len 表达式自带位置，包装 pos 仅诊断用，取 {0;0;0}） *)
and wrap_ty_group (g : expr option) (b : ty) : ty =
  match g with
  | None -> TSeq (b, { file = ""; line = 0; col = 0 })
  | Some len -> TSeqN (b, len, { file = ""; line = 0; col = 0 })

(* 声明语法（new.md 2026-10-10，let 形式）：
   标量：let (类型)? (frac)? (const)? (unred)? 名字 (= 初值)?
   数组：let 类型 (frac)? (const)? (unred)? 名字[长度] (= 值1,值2,...)?
   列表：let 类型 (frac)? (const)? (unred)? 名字[] (= 值1,值2,...)?
   类型后缀（T[] x）与名字侧组（x[3][]）可混用叠加；
   类型省略仅标量合法（由初值推断） *)
and parse_let_stmt p tp =
  ignore (next p);   (* 消费 let *)
  (* v3.26 P0-3：可选 shared 修饰（仅顶层合法，typeck 侧校验） *)
  let is_shared =
    match peek p with
    | (Keyword KShared, _) -> ignore (next p); true
    | _ -> false
  in
  let (ty_opt, is_frac, is_const, is_unred) = parse_let_head p in
  let rec go acc =
    let st = parse_declarator p tp ty_opt is_shared is_const is_frac is_unred in
    let acc = st :: acc in
    match peek p with
    | (Comma, _) -> ignore (next p); go acc
    | _ -> List.rev acc
  in
  let stmts = go [] in
  end_of_stmt p;
  (match stmts with
   | [ st ] -> st
   | _ -> SDeclList stmts)

(* 声明器的数组/列表形状归一：总组数列表（外->内）、变量维度、元素类型 *)
and decl_shape (base : ty) (groups : expr option list) :
    ty * expr option * bool * (expr option list) =
  match groups with
  | [] -> (base, None, false, [])
  | g :: rest ->
    let ety = List.fold_left (fun b g' -> wrap_ty_group g' b) base (List.rev rest) in
    let (len, is_list) = (match g with None -> (None, true) | Some le -> (Some le, false)) in
    (ety, len, is_list, rest)

(* 名字侧中括号组：a[3][] → [Some 3; None]（外->内） *)
and parse_name_groups p : expr option list =
  match peek p with
  | (LBracket, lp) ->
    ignore (next p);
    (match peek p with
     | (RBracket, _) -> ignore (next p); let rest = parse_name_groups p in None :: rest
     | _ ->
       let len = parse_expr p in
       expect p RBracket "]";
       let rest = parse_name_groups p in
       Some len :: rest)
  | _ -> []

(* 单个声明器：名字 + 数组/列表组（类型侧+名字侧可叠加）+ 可选初值。
   类型可省（推断路径，仅标量）；frac 数组/列表合法（new.md：
   let f64 frac y[128]），元素存入后自动约分（unred 数组不约分） *)
and parse_declarator p tp ty_opt is_shared is_const is_frac is_unred =
  let (base_ty, tgroups) =
    match ty_opt with
    | Some ty -> collect_ty_groups ty
    | None -> (TNamed ("i32", tp), [])   (* 推断路径仅标量：seq 形状在下方报错 *)
  in
  let name = expect_ident p "variable name" in
  let groups = tgroups @ parse_name_groups p in
  match decl_shape base_ty groups with
  | (_, _, _, _ :: _) when (match p.toks with (Assign, _) :: _ -> true | _ -> false) ->
    err tp "nested array/list declarations do not support initializers yet"
  | (ety, len, true, _) ->
    (* 列表：[]（变量维度为动态） *)
    (match ty_opt with
     | None -> err tp "let without a type only supports scalar declarations"
     | Some _ -> ());
    let inits = parse_seq_inits p in
    SSeqDecl (is_const, is_frac, is_unred, is_shared, name, ety, None, true, inits, tp)
  | (ety, Some len, false, _) ->
    (* 定长数组：[长度]（变量维度为定长） *)
    (match ty_opt with
     | None -> err tp "let without a type only supports scalar declarations"
     | Some _ -> ());
    let inits = parse_seq_inits p in
    SSeqDecl (is_const, is_frac, is_unred, is_shared, name, ety, Some len, false, inits, tp)
  | (ety, None, false, []) ->
    (* 标量：类型与初值二选一或都写（都无时 frac 修饰可顶替类型，
       由 typeck 校验）；初值可省略（省略时填零值）；const 必须带初值。
       v3.11：`let T x = match ...` 直接脱糖返回合成透明块 *)
    (match p.toks with
     | (Assign, _) :: _ ->
       let (_t, _tp) = next p in
       (match peek p with
        | (Keyword KMatch, mp) ->
          parse_match_decl p mp name ty_opt is_const is_frac is_unred
        | _ ->
          let e = parse_expr p in
          (match is_const, Some e with
           | true, None -> err tp "const requires an initializer"
           | _ -> ());
          SDecl (is_const, is_frac, is_unred, is_shared, name, ty_opt, Some e, tp))
     | _ ->
       (match is_const with
        | true -> err tp "const requires an initializer"
        | false -> ());
       SDecl (is_const, is_frac, is_unred, is_shared, name, ty_opt, None, tp))

(* 语句位置 let 声明：一行多声明器——let i32 a, b = 1, c[3], d[]，逗号分隔，
   共享类型与前缀修饰符，初值各自独立 *)
and parse_decl_stmt p tp = parse_let_stmt p tp

(* 判断当前是否为旧式声明形状（类型词开头）——仅用于给出"声明须以 let 开头"
   的迁移提示错误；let 形式的声明由 parse_stmt 的 KLet 分支直接分发 *)
and looks_like_decl p =
  if is_qpath_start p.toks then begin
    let (_segs, rest) = scan_qpath p.toks in
    match skip_ty_suffix_toks rest with
    | (Ident _, _) :: (LParen, _) :: _ -> false
    | (Ident _, _) :: _ -> true
    | _ -> false
  end
  else
  match ty_kws_len p.toks with
  | 0 -> false
  | n ->
    let rec drop k l = if k <= 0 then l else match l with _ :: r -> drop (k - 1) r | [] -> [] in
    let after_ty = drop n p.toks in
    let tyname_ok =
      match drop (n - 1) p.toks with
      | (Ident s, _) :: _ -> List.mem s p.tynames
      | _ -> false
    in
    (match after_ty with
     | (Star, _) :: _ | (Bang, _) :: _ | (LBracket, _) :: _ ->
       tyname_ok &&
       (match skip_ty_suffix_toks after_ty with
        | (Ident _, _) :: _ -> true
        | (Keyword (KConst | KFrac | KUnreduced | KRef), _) :: _ -> true
        | _ -> false)
     | (Lt, _) :: _ -> tyname_ok   (* 泛型实例化声明 Box<i32> x = ... *)
     | (Ident _, _) :: _ -> true
     | (Keyword (KConst | KFrac | KUnreduced | KRef), _) :: _ -> true
     | _ -> false)

(* for 头部 let 声明（const/frac/unred 允许；类型可省时由初值推断） *)
and parse_for_decl p tp =
  (* 消费 for 头声明段的 let 关键字（for let i32 i = 0, ...） *)
  (match peek p with
   | (Keyword KLet, _) -> ignore (next p)
   | _ -> ());
  let (ty_opt, is_frac, is_const, is_unred) = parse_let_head p in
  (match ty_opt with
   | Some (TSeq _ | TSeqN _) ->
     err tp "for header declarations do not support arrays/lists"
   | _ -> ());
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
  FIDecl (is_const, is_frac, is_unred, name, ty_opt, init, tp)

(* 判断是否为"裸声明"形状错误（类型名开头但后续不构成合法声明） *)
and check_bare_decl p =
  let second_ty =
    match peek2 p with
    | (Ident s, _) -> List.mem s type_names
    | _ -> false
  in
  match p.toks with
  | (_, tp) :: _ when second_ty ->
    err tp "duplicate base type: a declaration has exactly one base type"
  | (Ident s, tp) :: _ when List.mem s type_names && s <> "void" ->
    err tp (Printf.sprintf
              "declaration syntax: let TYPE (frac)? (const)? (unred)? NAME [= init] (e.g. let %s x = 1 / let %s x / let %s const k = 2 / let %s arr[8] = 1,2 / let %s lst[])"
              s s s s s)
  | _ -> ()

(* match 模式（v3.9）：_ 通配 / 字面量（parse_expr，含负数）/ 枚举变体
   （ident 或点路径，可选 (绑定名...) 载荷绑定） *)
and parse_mpat p =
  let (tk, tp) = peek p in
  match tk with
  | Ident "_" ->
    ignore (next p); PWild
  | Ident s ->
    ignore (next p);
    let name = ref s in
    let rec dots () =
      match peek p with
      | (Dot, _) ->
        ignore (next p);
        name := !name ^ "." ^ expect_ident p "variant name";
        dots ()
      | _ -> ()
    in
    dots ();
    (match peek p with
     | (LParen, _) ->
       ignore (next p);
       let rec binds acc =
         match peek p with
         | (RParen, _) -> ignore (next p); List.rev acc
         | _ ->
           let n = expect_ident p "pattern binding name" in
           (match peek p with
            | (Comma, _) -> ignore (next p); binds (n :: acc)
            | (RParen, _) -> ignore (next p); List.rev (n :: acc)
            | (_, ep) -> err ep "expected ',' or ')' in pattern bindings")
       in
       PVar (!name, binds [], tp)
     | _ -> PVar (!name, [], tp))
  | IntLit _ | FloatLit _ | StrLit _ | CharLit _ | Keyword KTrue | Keyword KFalse
  | Minus ->
    PLit (parse_expr p)
  | _ -> err tp "expected pattern: literal, enum variant, or '_'"

and parse_match_arms p tp =
  (* match 头（v3.9）：`match <scrutinee>` 换行缩进 arm 块。
     v3.11 抽取复用：语句位置（SMatch）与 let 初始化脱糖共用 *)
  ignore (next p);
  let scrut = parse_expr p in
  let rec skip_nl () =
    match peek p with
    | (Newline, _) -> ignore (next p); skip_nl ()
    | _ -> ()
  in
  skip_nl ();
  (match peek p with
   | (Indent, _) ->
     ignore (next p);
     let rec arms acc =
       match peek p with
       | (Dedent, _) -> ignore (next p); List.rev acc
       | (Eof, _) -> List.rev acc
       | (Newline, _) -> ignore (next p); arms acc
       | _ ->
         let pat = parse_mpat p in
         expect p FatArrow "=>";
         (match peek p with
          | (Newline, _) ->
            ignore (next p);
            let blk = parse_block p in
            arms ({ mpat = pat; mbody = blk; mpos = tp } :: acc)
          | _ ->
            let st = parse_stmt p in
            arms ({ mpat = pat; mbody = [ st ]; mpos = tp } :: acc))
     in
     (scrut, arms [])
   | (_, ep) ->
     err ep "match requires a newline and an indented arm block (one 'pattern => body' per arm)")

(* let x = match ...（v3.11）：match 初始化表达式，脱糖为透明块——
   目标变量零值声明 + 每个 arm 体转为对目标的赋值。
   目标类型由 let 头给出或由 typeck 按 arm 体公共类型推断（省略类型）；
   限标量/struct/string 形状（零初始化）；arm 体须为单表达式语句，
   缩进块体（多语句）时末表达式作为 arm 值（其余语句照常执行） *)
and parse_match_decl p tp name ty_opt is_const is_frac is_unred =
  if is_const then
    err tp "const does not support a match initializer";
  let (scrut, arms) = parse_match_arms p tp in
  (* arm 体末语句改写为对目标的赋值；块体保留前序语句（作用域同 arm） *)
  let arms2 =
    List.map
      (fun (a : marm) ->
        let rec go acc = function
          | [] -> err a.mpos "match initializer arm must end with an expression"
          | [ SExpr e ] ->
            List.rev (SAssign (EVar (name, tp), e, a.mpos) :: acc)
          | st :: rest -> go (st :: acc) rest
        in
        { a with mbody = go [] a.mbody })
      arms
  in
  SBlock ([ SDecl (false, is_frac, is_unred, false, name, ty_opt, None, tp);
            SMatch (scrut, arms2, tp) ],
          tp)

(* ui 语句（v3.18，new2.md「元素+标签」模型）：ui <kind> <名> [in <app>]
   缩进标签块。标签：x/y/w/h（坐标大小，注册时合成 pos/size）、
   pos/size/text/color/text_color/radius/value/rows/checked、items 列表、
   on_click/on_change/on_select/on_input/on_value -> 块（每帧边沿检查）。
   脱糖（SBlock 透明承载，状态全部存 app.uis，循环内安全）：
     let i32 ui_k_N = -1
     let UI <名> = UI("<kind>")
     <名>.uname = "<名>"                       -- 注册查重键
     <标签方法调用...>
     ui_k_N = <app>.find_ui("<名>")
     if ui_k_N == -1
         ui_k_N = <app>.add(<名>)              -- 首帧注册一次
         <app>.uis[ui_k_N].p_sel = -1          -- 防边沿首帧误触发
         <app>.uis[ui_k_N].p_value = -999
     if <app>.uis[ui_k_N].clicks != <app>.uis[ui_k_N].p_clicks
         <app>.uis[ui_k_N].p_clicks = <app>.uis[ui_k_N].clicks
         <on_click 体>                         -- 其余 on_xxx 同理 *)
and parse_ui_stmt p tp =
  (* kind 位置兼容关键字 input（KInput） *)
  let kind =
    match peek p with
    | (Ident k, _) -> ignore (next p); k
    | (Keyword KInput, _) -> ignore (next p); "input"
    | (Keyword KList, _) -> ignore (next p); "list"
    | (_, kp) -> err kp "element kind expected (label/button/input/slider/progress/list/check/menu/textarea)"
  in
  (match kind with
   | "label" | "button" | "input" | "slider" | "progress"
   | "list" | "check" | "menu" | "textarea" -> ()
   | _ ->
     err tp ("unknown ui element kind '" ^ kind ^ "' (label/button/input/slider/progress/list/check/menu/textarea)"));
  let name = expect_ident p "element name" in
  let appname =
    match peek p with
    | (Keyword KIn, _) -> ignore (next p); expect_ident p "app variable name"
    | _ -> "app"
  in
  end_of_stmt p;
  (match peek p with
   | (Indent, _) -> ignore (next p)
   | (_, ep) -> err ep "ui requires a newline and an indented tag block");
  incr ui_seq;
  let uid = string_of_int !ui_seq in
  let vk = "ui_k_" ^ uid in
  let xr = ref None and yr = ref None and wr = ref None and hr = ref None in
  let props = ref [] in       (* 标签方法调用，逆序 *)
  let texpr = ref None in     (* text 标签表达式（on_input 初值对齐） *)
  let vexpr = ref None in     (* value 标签表达式（on_value 初值对齐） *)
  let dynv = ref [] in        (* (visible/enable, expr)：运行期动态标签，逆序 *)
  let evs = ref [] in         (* (事件名, 块, pos)，逆序 *)
  let tag_call m args =
    (* 方法调用在 AST 中为点路径 EVar "obj.method"（typeck try_method 分派） *)
    SExpr (ECall (EVar (name ^ "." ^ m, tp), List.map (fun e -> CPos e) args, tp))
  in
  let app_call m args =
    ECall (EVar (appname ^ "." ^ m, tp), List.map (fun e -> CPos e) args, tp)
  in
  let rec tags () =
    skip_trivia p;
    match peek p with
    | (Dedent, _) -> ignore (next p)
    | (Eof, ep) -> err ep "unterminated ui tag block"
    | (Comma, _) -> ignore (next p); tags ()   (* 同行多标签：逗号分隔 *)
    | _ ->
      (match peek p with
       | (Ident tname, tpos) ->
         ignore (next p);
         (match tname with
          | "x" | "y" | "w" | "h" ->
            let e = parse_expr p in
            end_of_stmt p;
            (match tname with
             | "x" -> xr := Some e
             | "y" -> yr := Some e
             | "w" -> wr := Some e
             | _ -> hr := Some e)
          | "pos" | "size" ->
            let a = parse_expr p in
            expect p Comma ",";
            let b = parse_expr p in
            end_of_stmt p;
            props := tag_call tname [ a; b ] :: !props
          | "text" | "color" | "text_color" | "radius" | "value" | "rows" | "checked"
          | "visible" | "enable" ->
            let e = parse_expr p in
            end_of_stmt p;
            (match tname with
             | "text" -> texpr := Some e
             | "value" -> vexpr := Some e
             | "visible" | "enable" -> dynv := (tname, e) :: !dynv
             | _ -> ());
            props := tag_call tname [ e ] :: !props
          | "items" ->
            let rec items acc =
              let e = parse_expr p in
              let acc = e :: acc in
              match peek p with
              | (Comma, _) -> ignore (next p); items acc
              | _ -> List.rev acc
            in
            let es = items [] in
            end_of_stmt p;
            List.iter (fun e -> props := tag_call "add_item" [ e ] :: !props) es
          | ("on_click" | "on_change" | "on_select" | "on_input" | "on_value") as ev ->
            expect p ThinArrow "->";
            (match peek p with
             | (Newline, _) -> ignore (next p)
             | _ -> ());
            let blk = parse_block p in
            evs := (ev, blk, tpos) :: !evs
          | _ -> err tpos ("unknown ui tag '" ^ tname ^ "'"));
         tags ()
       | (_, ep) -> err ep "expect a ui tag (x/y/w/h/pos/size/text/color/...)")
  in
  tags ();
  let uis fld =
    EField (EIndex (EField (EVar (appname, tp), "uis", tp), EVar (vk, tp), tp), fld, tp)
  in
  (* 注册块：find/add → 边沿初值（标签每帧已应用于 <名>，注册时随 add 存入） *)
  let register_stmts =
    [ SAssign (EVar (vk, tp), app_call "add" [ EVar (name, tp) ], tp);
        SAssign (uis "p_text",
                 (match !texpr with Some e -> e | None -> EStr ("", tp)), tp);
        SAssign (uis "p_value",
                 (match !vexpr with Some e -> e | None -> EInt (0L, tp)), tp) ]
  in
  let edge_stmts =
    List.flatten
      (List.map
         (fun (ev, blk, epos) ->
           (* on_change：changed 本身已是单帧边沿标志，直接作条件；
              其余：当前输出 != 持久 prev（存于 app.uis[k].p_*，跨帧） *)
           match ev with
           | "on_change" -> [ SIf (uis "changed", blk, None, epos) ]
           | _ ->
             let (fld, pfld) =
               match ev with
               | "on_click" -> ("clicks", "p_clicks")
               | "on_select" -> ("sel", "p_sel")
               | "on_input" -> ("text_out", "p_text")
               | _ -> ("value", "p_value")
             in
             [ SIf (EBin (Ne, uis fld, uis pfld, epos),
                    [ SAssign (uis pfld, uis fld, epos) ] @ blk,
                    None, epos) ])
         (List.rev !evs))
  in
  SBlock ([ SDecl (false, false, false, false, vk, None, Some (EInt (-1L, tp)), tp);
            SDecl (false, false, false, false, name, Some (TNamed ("UI", tp)),
                   Some (EStructNew ("UI", [ CPos (EStr (kind, tp)) ], tp)), tp) ]
           @ List.rev !props
           @ (match !xr, !yr with
              | Some a, Some b -> [ tag_call "pos" [ a; b ] ]
              | _ -> [])
           @ (match !wr, !hr with
              | Some a, Some b -> [ tag_call "size" [ a; b ] ]
              | _ -> [])
           @ tag_call "uname" [ EStr (name, tp) ] :: [ SAssign (EVar (vk, tp),
                        app_call "find_ui" [ EStr (name, tp) ], tp);
               SIf (EBin (Eq, EVar (vk, tp), EInt (-1L, tp), tp),
                    register_stmts, None, tp) ]
           (* visible/enable 动态标签：注册后每帧写穿（k=-1 未注册时跳过） *)
           @ List.map
               (fun (tn, e) ->
                 SIf (EBin (Ne, EVar (vk, tp), EInt (-1L, tp), tp),
                      [ SExpr (app_call ("set_" ^ tn) [ EVar (vk, tp); e ]) ],
                      None, tp))
               (List.rev !dynv)
           @ edge_stmts,
          tp)

and parse_stmt p =
  let (tk, tp) = peek p in
  match tk with
  | Keyword KLet -> parse_let_stmt p tp
  | Ident _ when
      (match tk with
       | Ident "lock" -> false   (* lock 块语句（下方分支），非声明 *)
       | _ -> looks_like_decl p) ->
    err tp "declaration syntax: let TYPE (frac)? (const)? (unred)? NAME [= init] (declarations must start with 'let')"
  | Keyword (KConst | KFrac | KUnreduced) when looks_like_decl p ->
    err tp "declaration syntax: let TYPE (frac)? (const)? (unred)? NAME [= init] (declarations must start with 'let')"
  | Keyword KReturn ->
    ignore (next p);
    (match peek p with
     | (Newline, _) | (Dedent, _) | (Eof, _) ->
       end_of_stmt p;
       SReturn (None, tp)
     | (Keyword KMatch, _) ->
       (* return match（v3.30 表达式位置 match，最常见形态）：
          脱糖 = 语句位置 SMatch，arm 体为单表达式时改写为 `return expr`。
          arm 体为缩进块时保留原块（须在块内显式 return）；
          穷尽性检查与语句位置一致（enum scrutinee 须覆盖全部变体或 `_`） *)
       let (scrut, arms) = parse_match_arms p tp in
       let arms2 =
         List.map
           (fun (a : marm) ->
             match a.mbody with
             | [ SExpr e ] -> { a with mbody = [ SReturn (Some e, a.mpos) ] }
             | _ -> a)
           arms
       in
       SMatch (scrut, arms2, tp)
     | _ ->
       let e = parse_expr p in
       end_of_stmt p;
       SReturn (Some e, tp))
  | Keyword KIf ->
    ignore (next p);
    parse_if p tp
  | Keyword KMatch ->
    (* match 分发（v3.9）：match scrut 换行缩进块；
       arm：`模式 => 语句` 或 `模式 =>` 换行缩进块 *)
    let (scrut, arms) = parse_match_arms p tp in
    SMatch (scrut, arms, tp)
  | Keyword KWhile ->
    ignore (next p);
    let cond = parse_expr p in
    let body = parse_block p in
    SWhile (cond, body, tp)
  | Keyword KFor ->
    ignore (next p);
    (* for-in 遍历（v3.6）：for x in seq { }（与三段式 for 并存）；
       v3.10 带下标：for x in seq, i { }——逗号后接索引变量名 *)
    (match peek p, peek2 p with
     | (Ident name, _), (Keyword KIn, _) ->
       ignore (next p); ignore (next p);
       let seqx = parse_expr p in
       let idx =
         match peek p with
         | (Comma, _) ->
           ignore (next p);
           (match peek p with
            | (Ident iname, _) -> ignore (next p); Some iname
            | (_, tp') -> err tp' "for-in index position expects a variable name (e.g. `for x in xs, i`)")
         | _ -> None
       in
       let body = parse_block p in
       SForIn (name, idx, seqx, body, tp)
     | _ -> parse_for p tp)
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
  | Keyword KAsm ->
    (* 内联汇编语句（语句一）：asm("模板", out=变量, in=变量, clobber="...")。
       命名实参 out=/in= 可重复且顺序任意；模板 $0.. 对应 out（先）再 in。
       是否在 unsafe 块内由 typeck 检查（parser 只负责形状） *)
    ignore (next p);
    expect p LParen "(";
    let tmpl =
      (match peek p with
       | (StrLit s, _) -> ignore (next p); s
       | (tk, tpos) ->
         err tpos (Printf.sprintf "asm expects a string literal template, got %s" (pp_token tk)))
    in
    let outs = ref [] and ins = ref [] and clob = ref None in
    (* 命名实参分派：in 是关键字（KIn），out/clobber 为普通标识符 *)
    let named key kp =
      expect p Assign "=";
      match key with
      | "out" ->
        let (v, vp) = expect_ident_pos p "asm out= variable" in
        outs := (v, vp) :: !outs
      | "in" ->
        let (v, vp) = expect_ident_pos p "asm in= variable" in
        ins := (v, vp) :: !ins
      | "clobber" ->
        (match peek p with
         | (StrLit s, _) -> ignore (next p); clob := Some s
         | (tk, tpos) ->
           err tpos (Printf.sprintf "asm clobber= expects a string literal, got %s" (pp_token tk)))
      | _ -> err kp "asm named arguments are out=/in=/clobber="
    in
    let rec args () =
      match peek p with
      | (RParen, _) -> ignore (next p)
      | (Comma, _) -> ignore (next p); args ()
      | (Ident key, kp) ->
        ignore (next p);
        named key kp;
        args ()
      | (Keyword KIn, kp) ->
        ignore (next p);
        named "in" kp;
        args ()
      | (tk, tpos) ->
        err tpos (Printf.sprintf "asm expects out=/in=/clobber= or ')', got %s" (pp_token tk))
    in
    args ();
    end_of_stmt p;
    SAsm (tmpl, List.rev !outs, List.rev !ins, !clob, tp)
  | Ident "lock" when (match peek2 p with (LParen, _) | (Dot, _) -> false | _ -> true) ->
    (* lock 块（v3.26 P0-3）：lock m { }——m 为 mutex 句柄变量表达式。
       `lock(` 保持表达式调用（zfy_mutex_lock 语句形式）；`lock m {` 为块形式，
       自动配对解锁（含提前 return/break 路径） *)
    ignore (next p);
    let m = parse_expr p in
    let b = parse_block p in
    SLock (m, b, tp)
  | Keyword KFn ->
    (* 语句位置 fn（v3.7）：`fn 类型? 名(...)` = 嵌套函数定义；
       `fn (` / `fn [` / `fn =>` = lambda 表达式（落表达式语句）。
       先消费 KFn 再按后续形状分派 *)
    ignore (next p);
    (match peek p, peek2 p with
     | (Ident _, _), (Ident _, _) -> parse_nested_fn p tp
     | (Ident _, _), ((LParen | LBracket | ThinArrow), _) -> parse_nested_fn p tp
     | _ ->
       let e = parse_lambda_after_fn p tp in
       end_of_stmt p;
       SExpr e)
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
  | Keyword KUi ->
    (* ui 语句（v3.18，new2.md「元素+标签」）：ui <kind> <名> [in <app>]
       缩进标签块 → 脱糖为统一元素 UI 代码（SBlock 透明承载）：
       注册（app.find_ui 查重，首帧一次）+ on_xxx 边沿检查（每帧） *)
    ignore (next p);
    parse_ui_stmt p tp
  | Semicolon -> skip_trivia p; parse_stmt p
  | _ -> parse_expr_stmt p

(* 嵌套函数定义（v3.7 函数式轮）：fn 返回类型 (frac)? (unred)? 名(参数) 块——
   按命名 lambda 处理（隐式值捕获所在函数局部变量）；无泛型参数、无 main 特例 *)
and parse_lambda_after_fn p tp =
  (* KFn 已消费。lambda（v3.7 函数式轮）：
     fn [caps] (params) => expr   简写（返回类型由表达式推断）
     fn [caps] (params) -> T      换行 + 缩进块（块形式，体内 return）；
     捕获列表可省 = 体内自由变量默认值捕获，[&x, y] 显式逐变量指定 *)
  let caps =
    match peek p with
    | (LBracket, _) ->
      ignore (next p);
      let rec go acc =
        let is_ref =
          match peek p with
          | (Amp, _) -> ignore (next p); true
          | _ -> false
        in
        let n = expect_ident p "capture name" in
        let acc = (is_ref, n, tp) :: acc in
        match peek p with
        | (Comma, _) -> ignore (next p); go acc
        | (RBracket, _) -> ignore (next p); List.rev acc
        | (_, ep) -> err ep "expected ',' or ']' to end the capture list"
      in
      go []
    | _ -> []
  in
  expect p LParen "(";
  let lparams =
    let rec go acc =
      match peek p with
      | (RParen, _) -> ignore (next p); List.rev acc
      | _ ->
        (* 两种形状：名（推断类型）/ 类型 名（显式） *)
        let (n0, np0) = expect_ident_pos p "lambda parameter" in
        let lp =
          match peek p with
          | (Ident n1, _) ->
            ignore (next p);
            { lpname = n1; lpty = Some (TNamed (n0, np0)); lppos = np0 }
          | _ -> { lpname = n0; lpty = None; lppos = np0 }
        in
        (match peek p with
         | (Comma, _) -> ignore (next p); go (lp :: acc)
         | (RParen, _) -> ignore (next p); List.rev (lp :: acc)
         | (_, tp') -> err tp' "expected ',' or ')' to end the lambda parameter list")
    in
    go []
  in
  (match peek p with
   | (FatArrow, _) ->
     ignore (next p);
     let e = parse_expr p in
     ELambda ({ lparams; lcaps = caps; lbody = LExpr e }, tp)
   | (ThinArrow, _) ->
     ignore (next p);
     let ret = parse_ty p in
     (* 块形式：-> T 后换行 + 缩进块（与 ?? 块形式同机制） *)
     (match peek p with
      | (Newline, _) ->
        ignore (next p);
        let blk = parse_block p in
        ELambda ({ lparams; lcaps = caps; lbody = LBlock (blk, Some ret) }, tp)
      | (_, bp) ->
        err bp "lambda block body requires a newline and an indented block (or use '=>' for a single expression)")
   | (_, ap) ->
     err ap "expected '=>' or '->' after lambda parameters")

and parse_nested_fn p tp =
  let ty_opt =
    match peek p with
    | (Ident s, _) when List.mem s p.tynames -> Some (parse_ty p)
    | (Ident _, _) ->
      (match peek2 p with
       | (Ident _, _) -> Some (parse_ty p)
       | (LBracket, _) | (Star, _) | (Bang, _) | (Lt, _) -> Some (parse_ty p)
       | _ -> None)
    (* v3.30：嵌套函数返回闭包类型 *)
    | (Keyword KFn, _) -> Some (parse_ty p)
    | _ when is_qpath_start p.toks && looks_like_ty_path p -> Some (parse_ty p)
    | _ -> None
  in
  let is_frac =
    match peek p with
    | (Keyword KFrac, _) -> ignore (next p); true
    | _ -> false
  in
  let is_unred =
    match peek p with
    | (Keyword KUnreduced, _) -> ignore (next p); true
    | _ -> false
  in
  let name = expect_ident p "function name" in
  expect p LParen "(";
  let params =
    let rec go acc =
      match peek p with
      | (RParen, _) -> ignore (next p); List.rev acc
      | _ ->
        (* 参数形状：let (类型)? 名——与顶层 fn 参数一致；
           类型可省（须 frac）但嵌套 fn 限标量参数，此处要求显式类型 *)
        (match peek p with
         | (Keyword KLet, _) -> ignore (next p)
         | _ -> ());
        let (n0, np0) = expect_ident_pos p "parameter type" in
        let (pn, pp) = expect_ident_pos p "parameter name" in
        let lp = { lpname = pn; lpty = Some (TNamed (n0, np0)); lppos = pp } in
        (match peek p with
         | (Comma, _) -> ignore (next p); go (lp :: acc)
         | (RParen, _) -> ignore (next p); List.rev (lp :: acc)
         | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
    in
    go []
  in
  let body = parse_block p in
  let ret =
    match ty_opt with
    | Some ty -> Some ty
    | None -> err tp "nested function declaration requires a return type (or use void)"
  in
  SFn (name, params, ret, is_frac || is_unred, body, tp)

(* 表达式语句 / 赋值 / 复合赋值 / 自增自减 *)
and parse_expr_stmt p =
  let e = parse_expr p in
  let tp' = pos_of (peek p) in
  match peek p with
  | (Assign, ap) ->
    ignore (next p);
    let rhs = parse_expr p in
    (* 序列字面量整体赋值（w-014 #3）：a = 1, 2, 3 / bag.xs = 1, 2——
       赋值右值后跟逗号时贪婪收集为元素列表（行内逗号无其他含义，
       与声明处 parse_seq_inits 一致） *)
    (match peek p with
     | (Comma, _) ->
       let rec go acc =
         match peek p with
         | (Comma, _) -> ignore (next p); go (parse_expr p :: acc)
         | _ -> List.rev acc
       in
       let rest = go [ rhs ] in
       end_of_stmt p;
       SAssignList (e, rest, ap)
     | _ ->
       end_of_stmt p;
       SAssign (e, rhs, ap))
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
        if is_kw p KLet then begin
          ignore (next p);
          (* input 新声明目标：let TYPE 名（类型必须显式给出） *)
          let ty_opt =
            match peek p with
            | (Ident s, _) when List.mem s p.tynames -> Some (parse_ty p)
            | (Ident _, _) ->
              (match peek2 p with
               | (Ident _, _) -> Some (parse_ty p)
               | (LBracket, _) | (Star, _) | (Bang, _) | (Lt, _) -> Some (parse_ty p)
               | _ -> None)
            | _ -> None
          in
          let ty =
            match ty_opt with
            | Some ty -> ty
            | None -> err tp "input target declaration requires a type (let TYPE NAME)"
          in
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
    | (Keyword KLet, ltp) ->
      let item = parse_for_decl p ltp in
      inits := item :: !inits;
      (match peek p with
       | (Comma, _) -> ignore (next p); go ()
       | _ -> ())
    | _ ->
      if looks_like_decl p then
        err (snd (peek p))
          "for header declaration syntax: for let TYPE (frac)? (const)? (unred)? NAME = init, ..."
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
  (* 更新段不可为空（w-021，grammar.md §7 约定）：缺失时条件永不变化，
     静默死循环——无更新把更新写进块内或改用 while *)
  (match !updates with
   | [] ->
     err tp "for header requires an update segment (e.g. `, i++`): without it the condition never changes (infinite loop); put the update in the body or use while"
   | _ -> ());
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

(* 函数参数（new.md 2026-10-10，let 形式）：
   (ref)? let (类型)? (frac)? (const)? (unred)? 名字 (名字侧 [N]/[]组)?
   类型可省但须有 frac（隐含 i32 基），否则报错（参数无初值可推断）；
   move/copy 是调用点修饰，参数处非法；ref 支持标量/string/数组/列表 *)
let parse_param p =
  let (_tk0, tp0) = peek p in
  let is_ref =
    match peek p with
    | (Keyword KRef, _) -> ignore (next p); true
    | (Keyword (KMove | KCopy), pp) ->
      err pp "move/copy are call-site argument modifiers, not parameter modifiers"
    | _ -> false
  in
  (match peek p with
   | (Keyword KLet, _) -> ignore (next p)
   | (_, tp) ->
     err tp "parameter syntax: (ref)? let (TYPE)? (frac)? (const)? (unred)? NAME (e.g. let i32 x / let frac y / ref let string s)")
  ;
  let (ty_opt, is_frac, is_const, is_unred) = parse_let_head p in
  if is_ref && is_frac then
    err tp0 "ref parameters do not support the frac modifier";
  let ty =
    match ty_opt with
    | Some ty -> ty
    | None when is_frac -> TNamed ("i32", tp0)   (* let frac y → i32 frac *)
    | None ->
      err tp0 "parameter requires a type (or the frac modifier: let frac y)"
  in
  let (base_ty, tgroups) = collect_ty_groups ty in
  let name = expect_ident p "parameter name" in
  let groups = tgroups @ parse_name_groups p in
  match decl_shape base_ty groups with
  | (pty, None, false, []) ->
    { pname = name; pty; pfrac = is_frac; pseq = PScalar;
      pconst = is_const; punred = is_unred; pref = is_ref; ppos = tp0 }
  | (pty, None, true, _) ->
    (* 列表参数 *)
    if is_frac then err tp0 "array/list parameters do not support the frac modifier";
    if is_const || is_unred then err tp0 "array/list parameters do not support const/unred";
    { pname = name; pty; pfrac = false; pseq = PList;
      pconst = false; punred = false; pref = is_ref; ppos = tp0 }
  | (pty, Some len, false, _) ->
    (* 定长数组参数 *)
    if is_frac then err tp0 "array/list parameters do not support the frac modifier";
    if is_const || is_unred then err tp0 "array/list parameters do not support const/unred";
    { pname = name; pty; pfrac = false; pseq = PArray len;
      pconst = false; punred = false; pref = is_ref; ppos = tp0 }
  | (_, _, _, _ :: _) -> err tp0 "unsupported parameter shape"

(* 位域宽度尾缀 `: N`（v3.32）：N 为整数字面量（正数，≤ 字段类型位宽由
   typeck 校验）。无冒号返回 None，冒号后非法则报错 *)
let parse_field_bits p : int option =
  match peek p with
  | (Colon, cp) ->
    ignore (next p);
    (match next p with
     | (IntLit n, _) when n > 0L && n <= 128L ->
       Some (Int64.to_int n)
     | (IntLit _, bp) -> err bp "bitfield width must be between 1 and 128"
     | (_, bp) -> err bp "bitfield width must be an integer literal")
  | _ -> None

(* struct 字段块：每行一个字段（或 fn 方法，v3.2）；块以 DEDENT 结束。
   返回 (字段, 方法) 对 *)
let rec parse_struct_fields p facc macc =
  skip_trivia p;
  match peek p with
  | (Indent, _) -> ignore (next p); parse_struct_fields p facc macc
  | (Dedent, _) -> ignore (next p); (List.rev facc, List.rev macc)
  | (Eof, _) -> (List.rev facc, List.rev macc)
  | (Keyword KFn, ftp) ->
    (* struct 方法（v3.2 随机数模块）：fn (返回类型)? (frac)? 名字(参数) 块；
       隐式首参 self = ref 接收者（脱糖在 driver 展开） *)
    ignore (next p);
    let ty_opt =
      match peek p with
      | (Ident s, _) when List.mem s p.tynames -> Some (parse_ty p)
      | (Ident _, _) ->
        (match peek2 p with
         | (Ident _, _) -> Some (parse_ty p)
         | (LBracket, _) | (Star, _) | (Bang, _) | (Lt, _) -> Some (parse_ty p)
         | _ -> None)
      | _ when is_qpath_start p.toks && looks_like_ty_path p -> Some (parse_ty p)
      | _ -> None
    in
    let is_frac =
      match peek p with
      | (Keyword KFrac, _) -> ignore (next p); true
      | _ -> false
    in
    let name = expect_ident p "method name" in
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
    let ret =
      match ty_opt with
      | Some ty -> Some ty
      | None -> err ftp "method declaration requires a return type (or use void)"
    in
    parse_struct_fields p facc
      ({ mname = name; mparams = params; mret = ret; mrfrac = is_frac;
         mbody = body; mpos = ftp } :: macc)
  | (Ident _, ftp) ->
    (* 字段类型：任意标识符（基础宽度类型或已声明 struct 名，typeck 校验），
       可带 * 指针后缀与类型侧 []/[N] 组；
       函数类型允许（9a）；名字侧组可叠加（i32 m[3][4] 字段） *)
    let fty0 = parse_ty ~allow_fun:true p in
    let (base_ty, tgroups) = collect_ty_groups fty0 in
    let name = expect_ident p "field name" in
    let (fty, _flen, _isl, _rest) = decl_shape base_ty (tgroups @ parse_name_groups p) in
    let fseq =
      match _flen, _isl with
      | None, true -> PList
      | Some len, false -> PArray len
      | _ -> PScalar
    in
    (* rest ≠ []（嵌套元素类型，如 i32 m[3][4]）经 conv_ty 展开（w-14 #4） *)
    let fdefault =
      match peek p with
      | (Assign, _) -> ignore (next p); Some (parse_expr p)
      | _ -> None
    in
    (* 位域（v3.32，方案甲）：`TYPE name : N` —— 仅标量整型字段、且无默认值 *)
    let fbits = parse_field_bits p in
    (match fseq with
     | PScalar -> ()
     | _ ->
       (match fdefault with
        | Some _ -> err ftp "array/list struct fields cannot have default values"
        | None -> ()));
    (match fbits with
     | Some _ when fseq <> PScalar ->
       err ftp "bitfield width is only allowed on scalar fields"
     | Some _ when fdefault <> None ->
       err ftp "bitfield fields cannot have default values"
     | _ -> ());
    end_of_stmt p;
    parse_struct_fields p
      ({ fname = name; fty; fseq; fdefault; fpos = ftp; fbits } :: facc) macc
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
  | Lt ->
    (* 旧泛型函数形式 <T> ret name(...) 已废止（new.md 2026-10-10）：
       泛型函数写作 fn <T, U> ret name(...) *)
    err tp "generic function syntax: fn <T, U> RET name(params) (the old '<T> ret name(...)' form was removed)"
  | Keyword KPub ->
    (* pub 修饰：仅模块内顶层合法（root 顶层 pub 由 resolve 忽略并告警容忍） *)
    ignore (next p);
    IPub (parse_item p, tp)
  | Keyword KExport | Keyword KSection | Keyword KInternal ->
    (* 符号属性前缀（v3.32）：export "sym" / section "seg" / internal，
       可叠加；作用于其后 fn（pub fn 亦可）。*)
    let rec read_attrs ex sec intl =
      match peek p with
      | (Keyword KExport, _) ->
        ignore (next p);
        (match next p with
         | (StrLit s, _) -> read_attrs (Some s) sec intl
         | (_, sp) -> err sp "export requires a string literal symbol name")
      | (Keyword KSection, _) ->
        ignore (next p);
        (match next p with
         | (StrLit s, _) -> read_attrs ex (Some s) intl
         | (_, sp) -> err sp "section requires a string literal section name")
      | (Keyword KInternal, _) ->
        ignore (next p);
        read_attrs ex sec true
      | _ -> (ex, sec, intl)
    in
    let (ex, sec, intl) = read_attrs None None false in
    let rec apply it =
      match it with
      | IFn f -> IFn { f with fexport = ex; fsection = sec; finternal = intl }
      | IPub (inner, pp) -> IPub (apply inner, pp)
      | _ ->
        err tp "export/section/internal attributes apply to top-level functions only"
    in
    apply (parse_item p)
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
               | (Comma, _) ->
                 ignore (next p);
                 (* 允许尾逗号（v3.5 DX）：{ a, b, } —— 与折行配合 *)
                 (match fst (peek p) with
                  | RBrace -> ignore (next p); List.rev acc
                  | _ -> go_binds acc)
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
          (* ---- 单段整模块绑定（w-015 #2）：`use 模块名 [as 别名]` ----
             后跟 as → 带别名绑定；否则整段名为绑定名。路径解析（子模块
             存在性/可见性）由 resolve 的 resolve_path 统一处理；
             含 '.' 的旧文件名（use 名字.zfy）走下方 legacy 分支 ---- *)
          let buf = Buffer.create 16 in
          (match fst (peek p) with
           | Keyword KAs ->
             ignore (next p);
             let alias = expect_ident p "alias" in
             end_of_stmt p;
             IUseP { binds = [ (alias, [ first ], tp) ]; pos = tp }
           | Dot ->
             (* legacy：use 文件名.zfy [import 模块名] [as 别名] *)
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
             finish_legacy_use p tp buf
           | _ ->
             end_of_stmt p;
             IUseP { binds = [ (first, [ first ], tp) ]; pos = tp })))

  | Keyword KInterface ->
    (* interface 接口（v3.13）：interface 名 缩进块——每行一个方法签名
       `fn (返回类型)? 名(参数)`，无方法体。struct 方法同名同签名即隐式实现；
       接口类型 = struct iface$<名> { ptr data; ptr vt }，vtable 分派 *)
    ignore (next p);
    let iname = expect_ident p "interface name" in
    (* 继承（v3.20）：interface A: B——B 的方法并入 A（父在前） *)
    let iparent =
      match peek p with
      | (Colon, _) -> ignore (next p); Some (expect_ident p "parent interface name")
      | _ -> None
    in
    let defaults = ref [] in
    let rec skip_nl () =
      match peek p with
      | (Newline, _) -> ignore (next p); skip_nl ()
      | _ -> ()
    in
    let rec methods acc =
      skip_nl ();
      match peek p with
      | (Dedent, _) -> ignore (next p); List.rev acc
      | (Eof, _) -> List.rev acc
      | (Keyword KFn, mp) ->
        ignore (next p);
        let ret =
          match peek p with
          | (Ident _, _) -> Some (parse_ty p)
          | _ -> None
        in
        let mname = expect_ident p "interface method name" in
        expect p LParen "(";
        let rec pparams acc =
          match peek p with
          | (RParen, _) -> ignore (next p); List.rev acc
          | _ ->
            let pd = parse_param p in
            (match peek p with
             | (Comma, _) -> ignore (next p); pparams (pd :: acc)
             | (RParen, _) -> ignore (next p); List.rev (pd :: acc)
             | (_, tp') -> err tp' "expected ',' or ')' to end the parameter list")
        in
        let params = pparams [] in
        end_of_stmt p;
        (* 默认实现（v3.20）：签名后跟缩进块——struct 未实现时按实现者合成 *)
        (match peek p with
         | (Indent, _) ->
           let body = parse_block p in
           defaults := (mname, params, ret, body, mp) :: !defaults
         | _ -> ());
        methods ((ret, mname, params, mp) :: acc)
      | (_, tp') ->
        err tp' "interface body expects one method signature per line (fn ret? name(params))"
    in
    (skip_nl ();
     (match peek p with
      | (Indent, _) -> ignore (next p)
      | (_, tp') -> err tp' "interface requires a newline and an indented method-signature block"));
    let ms = methods [] in
    let defs = List.rev !defaults in
    IIf { name = iname; methods = ms; parent = iparent;
          defaults = defs; pos = tp }

  | Keyword KEnum ->
    (* enum 枚举与和类型（v3.9）：enum 名 缩进块——每行一个变体：
       `变体名`（零载荷）或 `变体名(类型, ...)`（带载荷）；
       统一编译为 tag+载荷 struct，变体序号即 tag（见 ast.IEnum 注释） *)
    ignore (next p);
    let name = expect_ident p "enum name" in
    let rec go acc =
      skip_trivia p;
      match peek p with
      | (Indent, _) -> ignore (next p); go acc
      | (Dedent, _) -> ignore (next p); List.rev acc
      | (Eof, _) -> List.rev acc
      | (Newline, _) -> ignore (next p); go acc
      | _ ->
        let vname = expect_ident p "enum variant name" in
        let payload =
          match peek p with
          | (LParen, _) ->
            ignore (next p);
            let rec go2 acc2 =
              match peek p with
              | (RParen, _) -> ignore (next p); List.rev acc2
              | _ ->
                let t = parse_ty p in
                (match peek p with
                 | (Comma, _) -> ignore (next p); go2 (t :: acc2)
                 | (RParen, _) -> ignore (next p); List.rev (t :: acc2)
                 | (_, tp') -> err tp' "expected ',' or ')' to end the payload type list")
            in
            go2 []
          | _ -> []
        in
        end_of_stmt p;
        go ((vname, payload) :: acc)
    in
    IEnum { name; variants = go []; pos = tp }
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
    (* 泛型 struct：struct Box<T, U>（名字后跟类型参数列表） *)
    let (tparams, tcons) =
      match peek p with
      | (Lt, _) ->
        let ps = parse_tparams p in
        (List.map fst ps, List.map snd ps)
      | _ -> ([], [])
    in
    let (fields, methods) =
      match peek p with
      | (Ident _, _) ->
        (* v3.11 修复：泛型 struct 声明行尾 '>' 是续行符（is_line_cont），
           吞掉了声明行的 Newline——首字段行与头相连、无 INDENT 前缀，
           曾致字段循环误吞后续顶层项（单字段模板 E2024 + missing main）。
           先按单行字段解析；第二字段起仍带 INDENT，续缩进块循环 *)
        let ftp = snd (peek p) in
        let fty0 = parse_ty ~allow_fun:true p in
        let (base_ty, tgroups) = collect_ty_groups fty0 in
        let fname = expect_ident p "field name" in
        let (fty, _flen, _isl, _rest) =
          decl_shape base_ty (tgroups @ parse_name_groups p) in
        let fseq =
          match _flen, _isl with
          | None, true -> PList
          | Some len, false -> PArray len
          | _ -> PScalar
        in
        let fdefault =
          match peek p with
          | (Assign, _) -> ignore (next p); Some (parse_expr p)
          | _ -> None
        in
        (match fdefault with
         | None -> ()
         | _ when fseq = PScalar -> ()
         | _ -> err ftp "array/list struct fields cannot have default values");
        let fbits = parse_field_bits p in
        (match fbits with
         | Some _ when fseq <> PScalar ->
           err ftp "bitfield width is only allowed on scalar fields"
         | Some _ when fdefault <> None ->
           err ftp "bitfield fields cannot have default values"
         | _ -> ());
        end_of_stmt p;
        let f0 = { fname; fty; fseq; fdefault; fpos = ftp; fbits } in
        (match peek p with
         | (Indent, _) -> parse_struct_fields p [ f0 ] []
         | _ -> ([ f0 ], []))
      | _ -> parse_struct_fields p [] []
    in
    p.tynames <- name :: p.tynames;
    IStruct { name; packed; fields; pos = tp; tparams; tcons; methods;
              is_union = false }
  | Keyword KUnion ->
    (* union（v3.32）：union 名 缩进块——每行一个字段（类型 名字），
       全部字段共享偏移 0；字段限标量（typeck 校验）。无方法。 *)
    ignore (next p);
    let name = expect_ident p "union name" in
    skip_trivia p;
    (match peek p with
     | (Indent, _) ->
       let (fields, methods) = parse_struct_fields p [] [] in
       if methods <> [] then err tp "union cannot have methods";
       p.tynames <- name :: p.tynames;
       IStruct { name; packed = false; fields; pos = tp; tparams = [];
                 tcons = []; methods = []; is_union = true }
     | (_, fp) ->
       err fp "union requires a newline and an indented field block")
  | Keyword KExtern ->
    (* extern "ABI"：缩进块内每行一个 C 函数声明（类型 (frac)? 名字(参数[,...])），
       解析为多个 IExtern 函数（块结构不保留）。
       ABI 变体（v3.32）：C/stdcall/fastcall/vectorcall/thiscall；
       参数列表末尾 ... 表示可变参数（printf 风格）。 *)
    ignore (next p);
    let abi =
      match peek p with
      | (StrLit s, sp) ->
        ignore (next p);
        if s = "C" || s = "c" then "C"
        else if List.mem s [ "stdcall"; "fastcall"; "vectorcall"; "thiscall" ] then s
        else
          err sp
            (Printf.sprintf
               "unsupported extern ABI \"%s\" (expected C, stdcall, fastcall, vectorcall or thiscall)"
               s)
      | (_, sp) -> err sp "expected an ABI string after extern (e.g. extern \"C\")"
    in
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
        let varargs = ref false in
        let params =
          let rec go2 acc2 =
            match peek p with
            | (RParen, _) -> ignore (next p); List.rev acc2
            | (Ellipsis, _) ->
              ignore (next p);
              varargs := true;
              (match peek p with
               | (RParen, _) -> ignore (next p); List.rev acc2
               | (_, tp') -> err tp' "variadic ... must end the argument list")
            | _ ->
              let pd = parse_param p in
              (match peek p with
               | (Comma, _) -> ignore (next p); go2 (pd :: acc2)
               | (RParen, _) -> ignore (next p); List.rev (pd :: acc2)
               | (Ellipsis, _) -> go2 (pd :: acc2)
               | (_, tp') -> err tp' "expected ',' or ')' to end the argument list")
          in
          go2 []
        in
        end_of_stmt p;
        go ({ ename = name; eparams = params; eret = rt; erfrac = rf; epos = tp;
              eabi = abi; evarargs = !varargs } :: acc)
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
  | Keyword KLet ->
    (* 顶层 let 声明（new.md：代码顶部可写任意变量/数组/列表声明） *)
    let d = parse_let_stmt p tp in
    IDecl (d, tp)
  | Keyword KFn ->
    (* fn 函数定义（new.md 2026-10-10）：
       fn (返回类型)? (frac)? (const)? (unred)? 名字(参数) 块
       main 特例：fn main()——不给返回类型（隐含 i32）、无参数、return 可省 *)
    ignore (next p);
    let (tparams, tcons) =
      match peek p with
      | (Lt, _) ->
        let ps = parse_tparams p in
        (List.map fst ps, List.map snd ps)
      | _ -> ([], [])
    in
    let ty_opt =
      match peek p with
      | (Ident s, _) when List.mem s p.tynames -> Some (parse_ty p)
      | (Ident _, _) ->
        (match peek2 p with
         | (Ident _, _) -> Some (parse_ty p)
         | (LBracket, _) | (Star, _) | (Bang, _) | (Lt, _) -> Some (parse_ty p)
         | _ -> None)
      (* v3.30：返回类型为闭包 fn(T...) -> R（前置 fn 已消费，此处 KFn
         只可能是返回类型，无歧义） *)
      | (Keyword KFn, _) -> Some (parse_ty p)
      | _ when is_qpath_start p.toks && looks_like_ty_path p -> Some (parse_ty p)
      | _ -> None
    in
    let is_frac =
      match peek p with
      | (Keyword KFrac, _) -> ignore (next p); true
      | _ -> false
    in
    let is_const =
      match peek p with
      | (Keyword KConst, cp) ->
        err cp "const is not a valid return-type modifier"
      | _ -> false
    in
    let is_unred =
      match peek p with
      | (Keyword KUnreduced, _) -> ignore (next p); true
      | _ -> false
    in
    let name = expect_ident p "function name" in
    if name = "main" then begin
      if ty_opt <> None then
        err tp "main must not declare a return type (fn main() — implicitly i32)";
      if is_frac || is_unred then
        err tp "main must not have frac/unred modifiers"
    end;
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
    if name = "main" && params <> [] then
      err tp "main takes no parameters";
    let body = parse_block p in
    let ret =
      match ty_opt with
      | Some ty -> Some ty
      | None when name = "main" -> Some (TNamed ("i32", tp))   (* main 隐含 i32 *)
      (* freestanding 入口与 panic 钩子允许省略返回类型，缺省 void *)
      | None when name = "_start" || name = "panic_handler" ->
        Some (TNamed ("void", tp))
      | None -> err tp "function declaration requires a return type (or use void)"
    in
    IFn { name; params; ret; rfrac = is_frac; runred = is_unred;
          body; pos = tp; tparams; tcons;
          fexport = None; fsection = None; finternal = false }
  | Ident _ ->
    if looks_like_decl p then
      err tp "declaration syntax: let TYPE (frac)? (const)? (unred)? NAME [= init] (declarations must start with 'let')"
    else
      err tp (Printf.sprintf "expected a top-level item (fn/use/let/struct/mod), got %s" (pp_token tk))
  | _ ->
    (* 顶层不允许出现语句关键字等（原为此处 Match_failure 崩溃，改为报错） *)
    err tp (Printf.sprintf "expected a top-level item (fn/use/let/struct/mod), got %s" (pp_token tk))

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
