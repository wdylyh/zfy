(* 类型检查 + 类型推断 *)
open Tokens
open Ast
open Hir

exception TypeError of pos * string

let terr p fmt =
  Printf.ksprintf (fun s -> raise (TypeError (p, s))) fmt

(* ---------- TVar 求解 ---------- *)

let subs : (int, zty) Hashtbl.t = Hashtbl.create 16
let var_counter = ref 0
let fresh_var () = incr var_counter; TVar !var_counter

let rec resolve = function
  | TVar n as v ->
    (match Hashtbl.find_opt subs n with
     | Some t -> resolve t
     | None -> v)
  | TFrac t -> TFrac (resolve t)
  | TArray (t, n) -> TArray (resolve t, n)
  | TList t -> TList (resolve t)
  | t -> t

let rec occurs n = function
  | TVar m -> m = n
  | TFrac t -> occurs n t
  | TArray (t, _) | TList t -> occurs n t
  | _ -> false

(* 严格 unify：数值类型间不做隐式兼容（转换必须显式 cast），
   仅字面量的 TVar 可被约束求解 *)
let rec unify p a b =
  let a = resolve a and b = resolve b in
  if a = b then ()
  else
    match a, b with
    | TVar n, t | t, TVar n ->
      if occurs n t then terr p "类型推断出现循环依赖"
      else Hashtbl.replace subs n t
    | TFrac ta, TFrac tb -> unify p ta tb
    | TArray (ta, na), TArray (tb, nb) ->
      if na <> nb then terr p "数组长度不一致：%d 与 %d" na nb;
      unify p ta tb
    | TList ta, TList tb -> unify p ta tb
    | _ ->
      terr p "类型不匹配：期望 %s，得到 %s（数值转换需显式 cast(表达式, 类型)）"
        (pp_zty b) (pp_zty a)

let is_numeric = function
  | TInt _ | TUint _ | TFloat _ | TFrac _ | TVar _ -> true
  | _ -> false

(* 整数混合宽度/符号的自动宽化目标（保守：保证两侧值域都能表示）。
   同符号取较宽者；异符号时若无符宽度的一半不大于有符宽度则用有符，
   否则用无符（如 u64 + i64 -> i128? 否：取 TUint 64，负值语义同 C） *)
let widen_target (a : zty) (b : zty) : zty =
  let info = function
    | TInt w -> (w, true)
    | TUint w -> (w, false)
    | _ -> (64, true)
  in
  let (wa, sa) = info a and (wb, sb) = info b in
  if sa = sb then
    if wa >= wb then a else b
  else
    let (ws, wu) = if sa then (wa, wb) else (wb, wa) in
    if ws >= 2 * wu then (if sa then a else b) else TUint (max ws wu)

(* ---------- 环境 ---------- *)

type fn_sig = { params : zty list; ret : zty }

type genv = { fns : (string, fn_sig) Hashtbl.t }

type local = { lconst : bool; lty : zty; lslot : string; lunred : bool }
type env = {
  g : genv;
  mutable scopes : (string, local) Hashtbl.t list;
  mutable fncur_ret : zty;
  mutable slotn : int;                       (* shadowing 改名计数 *)
  mutable fnvars : (string, unit) Hashtbl.t; (* 函数内已用过的变量名（兄弟作用域同名也要新槽） *)
  const_vals : (string, int64) Hashtbl.t;    (* const 整数变量的编译期值（按槽名） *)
}

(* 内建函数表（与 hir.ml builtin_fns 同步） *)
let builtin_fns_aux : (string * (zty list * zty)) list =
  List.map (fun (n, ps, r) -> (n, (ps, r)))
    [ ("str_len", [ TString ], TInt 64) ]

let lookup_var env name =
  let rec go = function
    | [] -> None
    | sc :: rest ->
      (match Hashtbl.find_opt sc name with
       | Some l -> Some l
       | None -> go rest)
  in
  go env.scopes

let push_scope env = env.scopes <- Hashtbl.create 8 :: env.scopes
let pop_scope env = env.scopes <- List.tl env.scopes

(* 声明变量：同名 shadowing 或兄弟作用域重用时分配新槽位名
   （不同声明绝不能共享 LLVM 槽位：宽度不同会 stack 腐败，RAII 槽位冲突） *)
let declare env name l =
  let fresh () =
    env.slotn <- env.slotn + 1;
    Printf.sprintf "%s$%d" name env.slotn
  in
  let slot =
    if not (Hashtbl.mem env.fnvars name) then begin
      Hashtbl.replace env.fnvars name ();
      name
    end
    else fresh ()
  in
  match env.scopes with
  | sc :: _ -> Hashtbl.replace sc name { l with lslot = slot }
  | [] -> assert false

(* ---------- 类型转换 ---------- *)

let rec conv_ty (g : genv) p (t : ty) : zty =
  match t with
  | TNamed (s, pp) ->
    (match prim_type s with
     | Some t' -> t'
     | None -> terr pp "未定义的类型：%s" s)

let pos_of_expr = function
  | EInt (_, p) | EFloat (_, p) | EStr (_, p) | EChar (_, p) | EBool (_, p)
  | EVar (_, p) | EBin (_, _, _, p) | EUn (_, _, p) | ECall (_, _, p)
  | EIndex (_, _, p) | ESlice (_, _, _, _, p)
  | ECast (_, _, p)
  | EBlock (_, p) -> p

(* ---------- 表达式检查 ---------- *)

(* 编译期常量求值（const 整数变量 / 字面量四则） *)
let rec const_eval (env : env) (e : texpr) : int64 option =
  match e.e with
  | EIntK n -> Some n
  | EVarK slot ->
    (match Hashtbl.find_opt env.const_vals slot with
     | Some v -> Some v
     | None -> None)
  | EUnK (UNeg, a) ->
    (match const_eval env a with Some v -> Some (Int64.neg v) | None -> None)
  | ECastK (a, _) -> const_eval env a
  | EBinK (op, a, b) ->
    (match const_eval env a, const_eval env b with
     | Some x, Some y ->
       (match op with
        | BAdd -> Some (Int64.add x y)
        | BSub -> Some (Int64.sub x y)
        | BMul -> Some (Int64.mul x y)
        | BDiv when y <> 0L -> Some (Int64.div x y)
        | BMod when y <> 0L -> Some (Int64.rem x y)
        | _ -> None)
     | _ -> None)
  | _ -> None

(* 标量提升为分数：EFracNewK (x cast e, 1) *)
and mk_frac_from (x : texpr) (e : zty) (p : pos) : texpr =
  let xc =
    if resolve x.ety = e then x
    else { e = ECastK (x, e); ety = e; epos = x.epos }
  in
  let one = { e = EIntK 1L; ety = e; epos = p } in
  { e = EFracNewK (xc, one); ety = TFrac e; epos = p }

(* 任意可打印值 -> string（sep/end/delim/内建参数的强转） *)
and to_string_of (t : texpr) : texpr =
  let p = t.epos in
  let mk k ty = { e = k; ety = ty; epos = p } in
  match resolve t.ety with
  | TString -> t
  | TChar -> mk (ECallK ("zfy_tostr_char", [ t ])) TString
  | TBool -> mk (ECallK ("zfy_tostr_bool", [ t ])) TString
  | TInt 64 -> mk (ECallK ("zfy_tostr_i64", [ t ])) TString
  | TUint 64 -> mk (ECallK ("zfy_tostr_u64", [ t ])) TString
  | TInt 128 -> mk (ECallK ("zfy_tostr_i128", [ t ])) TString
  | TUint 128 -> mk (ECallK ("zfy_tostr_u128", [ t ])) TString
  | TInt _ ->
    let c = mk (ECastK (t, TInt 64)) (TInt 64) in
    mk (ECallK ("zfy_tostr_i64", [ c ])) TString
  | TUint _ ->
    let c = mk (ECastK (t, TUint 64)) (TUint 64) in
    mk (ECallK ("zfy_tostr_u64", [ c ])) TString
  | TFloat _ ->
    let c = mk (ECastK (t, TFloat 64)) (TFloat 64) in
    mk (ECallK ("zfy_tostr_f64", [ c ])) TString
  | TFrac _ | TArray _ | TList _ | TVoid | TVar _ ->
    terr p "该类型不能转为 string：%s" (pp_zty t.ety)

let rec check_expr env (e : expr) : texpr =
  let p = pos_of_expr e in
  let mk k ty = { e = k; ety = ty; epos = p } in
  match e with
  | EInt (n, _) -> mk (EIntK n) (fresh_var ())
  | EFloat (f, _) -> mk (EFloatK f) (fresh_var ())
  | EStr (s, _) -> mk (EStrK s) TString
  | EChar (c, _) -> mk (ECharK c) TChar
  | EBool (b, _) -> mk (EBoolK b) TBool
  | EVar (name, p') ->
    (match lookup_var env name with
     | Some l ->
       (* const 整数：使用处直接内联编译期值（含顶层 const） *)
       (match l.lty, Hashtbl.find_opt env.const_vals l.lslot with
        | (TInt _ | TUint _), Some v when l.lconst ->
          { e = EIntK v; ety = l.lty; epos = p' }
        | _ -> mk (EVarK l.lslot) l.lty)
     | None -> terr p' "未定义的变量：%s" name)
  | EBin (op, l, r, p') ->
    let tl = check_expr env l in
    let tr = check_expr env r in
    let bop =
      match op with
      | Add -> BAdd | Sub -> BSub | Mul -> BMul | Div -> BDiv | Mod -> BMod
      | Eq -> BEq | Ne -> BNe | Lt -> BLt | Gt -> BGt | Le -> BLe | Ge -> BGe
      | And -> BAnd | Or -> BOr
    in
    if bop = BAnd || bop = BOr then begin
      unify p' tl.ety TBool;
      unify p' tr.ety TBool;
      mk (EBinK (bop, tl, tr)) TBool
    end
    else
      let rl = resolve tl.ety and rr = resolve tr.ety in
      let isf = function TFrac _ -> true | _ -> false in
      (* 字符串拼接：+ 对 string 是拼接（两边都必须是 string） *)
      if bop = BAdd && (rl = TString || rr = TString) then begin
        if rl <> TString || rr <> TString then
          terr p' "string 拼接要求两侧都是 string，得到 %s 与 %s"
            (pp_zty rl) (pp_zty rr);
        mk (ECallK ("zfy_str_concat", [ tl; tr ])) TString
      end
      else if isf rl || isf rr then begin
        (* 分数运算：同元素类型 frac 相运算，或标量提升为分数。
           运算结果由运行时自动约分到最简 *)
        if bop = BMod then
          terr p' "frac 类型不支持取模运算";
        let elem, a', b' =
          match rl, rr with
          | TFrac e1, TFrac e2 ->
            if e1 = e2 then (e1, tl, tr)
            else
              terr p' "frac 元素类型不一致：%s 与 %s"
                (pp_zty (TFrac e1)) (pp_zty (TFrac e2))
          | TFrac e, _ ->
            (match e, rr with
             | (TInt _ | TUint _), (TInt _ | TUint _ | TVar _) ->
               (e, tl, mk_frac_from tr e p')
             | TFloat _, (TFloat _ | TVar _) -> (e, tl, mk_frac_from tr e p')
             | _ ->
               terr p' "%s 不能与 %s 运算" (pp_zty (TFrac e)) (pp_zty rr))
          | _, TFrac e ->
            (match e, rl with
             | (TInt _ | TUint _), (TInt _ | TUint _ | TVar _) ->
               (e, mk_frac_from tl e p', tr)
             | TFloat _, (TFloat _ | TVar _) -> (e, mk_frac_from tl e p', tr)
             | _ ->
               terr p' "%s 不能与 %s 运算" (pp_zty rl) (pp_zty (TFrac e)))
          | _ -> assert false
        in
        let res_ty =
          match bop with
          | BEq | BNe | BLt | BGt | BLe | BGe -> TBool
          | _ -> TFrac elem
        in
        mk (EBinK (bop, a', b')) res_ty
      end
      else
        let res_ty =
          match bop with
          | BEq | BNe | BLt | BGt | BLe | BGe ->
            if not (is_numeric rl && is_numeric rr) then
              terr p' "比较运算要求数值类型，得到 %s 与 %s"
                (pp_zty tl.ety) (pp_zty tr.ety);
            TBool
          | _ ->
            if not (is_numeric rl && is_numeric rr) then
              terr p' "算术运算要求数值类型，得到 %s 与 %s"
                (pp_zty tl.ety) (pp_zty tr.ety);
            tl.ety
        in
        (* 整数自动宽化：两侧都是具体整数类型且不同时，窄侧提升到宽侧 *)
        let tl, tr, res_ty =
          match rl, rr with
          | (TInt _ | TUint _), (TInt _ | TUint _) when rl <> rr ->
            let tgt = widen_target rl rr in
            let tl = mk (ECastK (tl, tgt)) tgt in
            let tr = mk (ECastK (tr, tgt)) tgt in
            let res_ty =
              (match bop with
               | BEq | BNe | BLt | BGt | BLe | BGe -> TBool
               | _ -> tgt)
            in
            (tl, tr, res_ty)
          | _ ->
            (match bop with
             | BEq | BNe | BLt | BGt | BLe | BGe ->
               unify p' tl.ety tr.ety
             | _ -> unify p' tl.ety tr.ety);
            (tl, tr, res_ty)
        in
        mk (EBinK (bop, tl, tr)) res_ty
  | EUn (op, e1, p') ->
    let t1 = check_expr env e1 in
    (match op with
     | Neg ->
       (match resolve t1.ety with
        | TFrac e ->
          (* -x 生成 0 - x *)
          let zero = mk_frac_from { e = EIntK 0L; ety = e; epos = p' } e p' in
          mk (EBinK (BSub, zero, t1)) (TFrac e)
        | t1' ->
          if not (is_numeric t1') then
            terr p' "取负要求数值类型，得到 %s" (pp_zty t1');
          mk (EUnK (UNeg, t1)) t1')
     | Not ->
       unify p' t1.ety TBool;
       mk (EUnK (UNot, t1)) TBool)
  | ECall (callee, args, p') ->
    (match callee with
     | EVar (name, _) ->
       (match name with
        | "length" | "find" | "trim" | "split" | "replace" | "prec" ->
          (* 函数式内建：支持命名参数 count=，位置参数在前 *)
          check_builtin env p' name args
        | "push" ->
          (* push(列表, 值)：追加到末尾（自动扩长），无返回值 *)
          (match args with
           | [ CPos b; CPos v ] ->
             let tb = check_expr env b and tv0 = check_expr env v in
             (match resolve tb.ety with
              | TList e ->
                let tv0 = coerce p' tv0 e in
                mk (EPushK (tb, { tv0 with ety = resolve e })) TVoid
              | t -> terr p' "push 的目标必须是列表，得到 %s" (pp_zty t))
           | _ -> terr p' "push 需要两个参数：push(列表, 值)")
        | _ ->
          (* 普通函数调用：要求全部位置参数 *)
          let targs =
            List.map
              (function
                | CPos e -> check_expr env e
                | CNamed (n, _) -> terr p' "函数调用不支持命名参数 %s=" n)
              args
          in
          check_call env p' name targs)
     | _ -> terr p' "不支持的表达式作为被调者")
  | EIndex (base, idx, p') ->
    let tb = check_expr env base in
    let ti = to_i64 (check_expr env idx) in
    (match resolve tb.ety with
     | TArray (e, _) | TList e ->
       (* 数组/列表读取：结果为元素类型（越界运行时报错） *)
       mk (ESeqGetK (tb, ti)) e
     | TString ->
       (* s[i] 读字符：越界运行时报错，结果直接是 char *)
       mk (ECallK ("zfy_str_char", [ tb; ti ])) TChar
     | t -> terr p' "该类型不支持下标访问：%s" (pp_zty t))
  | ESlice (base, a, b, step, p') ->
    let tb = check_expr env base in
    (match resolve tb.ety with
     | TString ->
       (* string 切片：返回新串（两端含，步长默认 1） *)
       let ta = to_i64 (check_expr env a) and tb' = to_i64 (check_expr env b) in
       let ts =
         match step with
         | None -> { e = EIntK 1L; ety = TInt 64; epos = p' }
         | Some s -> to_i64 (check_expr env s)
       in
       mk (ECallK ("zfy_str_slice", [ tb; ta; tb'; ts ])) TString
     | TArray (e, _) | TList e ->
       (* 数组/列表切片：返回同元素类型的动态序列（可赋给数组或列表变量） *)
       let ta = to_i64 (check_expr env a) and tb' = to_i64 (check_expr env b) in
       let ts =
         match step with
         | None -> { e = EIntK 1L; ety = TInt 64; epos = p' }
         | Some s -> to_i64 (check_expr env s)
       in
       mk (ESeqSliceK (tb, ta, tb', ts)) (TList e)
     | t -> terr p' "切片只能用于 string/数组/列表类型，得到 %s" (pp_zty t))
  | ECast (e1, t, p') ->
    (* cast(表达式, 目标类型)：
       - 数值类型间互转（float->int 向零截断）
       - string -> 数值/bool：运行时解析（stoi/stod，非零为 true）
       - 数值/bool/char -> string：运行时格式化 *)
    let t1 = check_expr env e1 in
    let t' = conv_ty env.g p' t in
    let a = resolve t1.ety in
    let b = resolve t' in
    let num = function
      | TInt _ | TUint _ | TFloat _ | TBool | TChar -> true
      | _ -> false
    in
    let ok =
      match a, b with
      | TString, TString -> true
      | _ when num a && num b -> true
      | TString, _ when num b -> true
      | _ when num a && b = TString -> true
      | TVar _, _ | _, TVar _ -> true
      | _ -> false
    in
    if not ok then
      terr p' "不支持的 cast：%s -> %s"
        (pp_zty a) (pp_zty b);
    mk (ECastK (t1, t')) t'
  | EBlock (_, p') -> terr p' "此处不支持块表达式"

and check_call env p name targs =
  let sig_ =
    match List.assoc_opt name builtin_fns_aux with
    | Some (ptys, ret) -> { params = ptys; ret }
    | None ->
      (match Hashtbl.find_opt env.g.fns name with
       | Some s -> s
       | None -> terr p "未定义的函数：%s" name)
  in
  if List.length sig_.params <> List.length targs then
    terr p "函数 %s 期望 %d 个参数，得到 %d 个"
      name (List.length sig_.params) (List.length targs);
  let targs =
    List.map2 (fun ta pt -> coerce p ta pt) targs sig_.params in
  { e = ECallK (name, targs); ety = sig_.ret; epos = p }

(* 下标/整数参数统一转成 i64（小整数隐式拓宽） *)
and to_i64 (ti : texpr) : texpr =
  match resolve ti.ety with
  | TInt 64 | TUint 64 -> ti
  | TInt _ | TUint _ | TVar _ ->
    { e = ECastK (ti, TInt 64); ety = TInt 64; epos = ti.epos }
  | t -> terr ti.epos "要求整数类型，得到 %s" (pp_zty t)

(* 目标驱动的自动数值转换（消除跨宽度赋值/传参/返回处的 cast）：
   - 同型直接通过；含类型变量时回退到 unify（字面量求解）
   - 整数↔整数（跨宽度/符号）：目标宽度明确时自动 cast（窄化截断同 C 语义）
   - 其余（浮点↔整数、string 等）仍需显式 cast *)
and coerce p (te : texpr) (want : zty) : texpr =
  let a = resolve te.ety and b = resolve want in
  if a = b then te
  else
    match a, b with
    | TVar _, _ | _, TVar _ -> unify p te.ety want; te
    | (TInt _ | TUint _), (TInt _ | TUint _) ->
      { e = ECastK (te, want); ety = want; epos = te.epos }
    (* 定长数组 -> 动态长度数组参数（TList 运行期与 TArray 同构） *)
    | TArray (ea, _), TList eb when ea = eb -> te
    | _ ->
      terr p "类型不匹配：期望 %s，得到 %s（数值转换需显式 cast(表达式, 类型)）"
        (pp_zty b) (pp_zty a)

(* 函数式内建：length / find / trim / split / replace。
   char/string 参数传变量直接用；其他类型强制转 string *)
and check_builtin env p name (args : call_arg list) =
  let mk k ty = { e = k; ety = ty; epos = p } in
  let pos_args = List.filter_map (function CPos e -> Some e | _ -> None) args in
  let named = List.filter_map (function CNamed (n, e) -> Some (n, e) | _ -> None) args in
  let str_of (e : expr) what =
    let t = check_expr env e in
    if resolve t.ety <> TString then
      terr p "%s 的 %s 参数要求 string 类型，得到 %s" name what (pp_zty t.ety);
    t
  in
  (* 第二参数：char -> 字符语义；string -> 子串语义；其他类型 -> 强转 string *)
  let char_or_str (e : expr) what =
    let t = check_expr env e in
    match resolve t.ety with
    | TChar -> `Char t
    | TString -> `Str t
    | TFrac _ | TArray _ | TList _ | TVoid ->
      terr p "%s 的 %s 参数不能是 %s 类型" name what (pp_zty t.ety)
    | _ -> `Str (to_string_of t)
  in
  match name, pos_args, named with
  | "length", [ x ], [] ->
    let tx = check_expr env x in
    (match resolve tx.ety with
     | TString -> mk (ECallK ("strlen", [ tx ])) (TInt 64)
     | TArray _ | TList _ -> mk (ESeqLenK tx) (TInt 64)
     | t -> terr p "length 的参数必须是 string/数组/列表，得到 %s" (pp_zty t))
  | "find", [ s; c ], [] ->
    (* find(s, 'l')：找第 1 次出现；找不到返回 -1 *)
    let ts = str_of s "第 1 个" and tc = char_of_expr env c "第 2 个" in
    let one = { e = EIntK 1L; ety = TInt 64; epos = p } in
    { e = ECallK ("zfy_str_find", [ ts; tc; one ]); ety = TInt 64; epos = p }
  | "find", [ s; c ], [ ("count", k) ] ->
    (* find(s, 'l', count=k)：找第 k 次出现（k 从 1 起）；找不到返回 -1 *)
    let ts = str_of s "第 1 个" and tc = char_of_expr env c "第 2 个" in
    let tk = to_i64 (check_expr env k) in
    (match const_eval env tk with
     | Some v when Int64.compare v 1L < 0 ->
       terr p "find 的 count 必须 > 0，得到 %Ld" v
     | _ -> ());
    { e = ECallK ("zfy_str_find", [ ts; tc; tk ]); ety = TInt 64; epos = p }
  | "trim", [ s; x ], [] ->
    let ts = str_of s "第 1 个" in
    (match char_or_str x "第 2 个" with
     | `Char tc -> { e = ECallK ("zfy_str_trim", [ ts; tc ]); ety = TString; epos = p }
     | `Str tx -> { e = ECallK ("zfy_str_trim_str", [ ts; tx ]); ety = TString; epos = p })
  | "split", [ s; x ], [] ->
    (* split(s, x)：按分隔符切分，返回 string 列表（一等值，可 length/下标/遍历） *)
    let ts = str_of s "第 1 个" in
    (match char_or_str x "第 2 个" with
     | `Char tc -> { e = ESplitK (ts, tc); ety = TList TString; epos = p }
     | `Str tx -> { e = ESplitK (ts, tx); ety = TList TString; epos = p })
  | "replace", [ s; a; b; rep ], [] ->
    (* replace(s, a, b, rep)：把下标 a..b（两端含）替换为 rep（任意 string 表达式） *)
    let ts = str_of s "第 1 个" in
    let ta = to_i64 (check_expr env a) and tb' = to_i64 (check_expr env b) in
    let trep =
      match char_or_str rep "第 4 个" with
      | `Char tc -> to_string_of tc
      | `Str tx -> tx
    in
    { e = ECallK ("zfy_str_replace", [ ts; ta; tb'; trep ]); ety = TString; epos = p }
  | "replace", [ s; a; rep ], [] ->
    (* replace(s, a, rep)：从下标 a 起替换到串尾 *)
    let ts = str_of s "第 1 个" in
    let ta = to_i64 (check_expr env a) in
    let trep =
      match char_or_str rep "第 3 个" with
      | `Char tc -> to_string_of tc
      | `Str tx -> tx
    in
    { e = ECallK ("zfy_str_replace_from", [ ts; ta; trep ]); ety = TString; epos = p }
  | "prec", [ v; n ], [] ->
    (* prec(v, n)：输出长度控制（总字符数），返回 string。
       v：string 截断/补空格；其他可打印类型先按输出格式转 string。
       n：整数/bool/char（数字字符转数值）/浮点（向零截断）。 *)
    let tv = check_expr env v in
    (match resolve tv.ety with
     | TArray _ | TList _ | TVoid ->
       terr p "prec 不能用于 %s 类型" (pp_zty tv.ety)
     | _ -> ());
    let tn = check_expr env n in
    (match resolve tn.ety with
     | TInt _ | TUint _ | TBool | TChar | TFloat _ | TVar _ -> ()
     | t -> terr p "prec 的长度参数必须是整数/char/浮点，得到 %s" (pp_zty t));
    mk (ECallK ("zfy.prec", [ tv; tn ])) TString
  | _ ->
    terr p "内建函数 %s 的参数形状不正确（位置参数在前，命名参数在后）" name

(* char 参数（find 用） *)
and char_of_expr env (e : expr) what =
  let t = check_expr env e in
  if resolve t.ety <> TChar then
    terr t.epos "要求 char 类型（%s），得到 %s" what (pp_zty t.ety);
  t

(* ---------- 语句检查 ---------- *)

(* input 目标支持的类型：string / 整数 / 浮点 / bool / char *)
let check_input_ty p = function
  | TString | TInt _ | TUint _ | TFloat _ | TBool | TChar -> ()
  | t -> terr p "input 目标类型必须是 string/整数/浮点/bool/char，得到 %s" (pp_zty t)

(* frac 声明：初值 a/b（两侧均非 frac）解释为分数字面量（不执行除法）；
   非 unreduced 的 frac 槽在存入后自动约分（needs_norm） *)
(* 类型零值表达式（声明省略初值时使用） *)
and zero_of (p : pos) (t : zty) : texpr =
  let t = resolve t in
  let mk k = { e = k; ety = t; epos = p } in
  match t with
  | TInt _ | TUint _ -> mk (EIntK 0L)
  | TFloat _ -> mk (EFloatK 0.0)
  | TBool -> mk (EBoolK false)
  | TChar -> mk (ECharK '\000')
  | TString -> mk (EStrK "")
  | TFrac e ->
    { e = EFracNewK ({ e = EIntK 0L; ety = e; epos = p },
                     { e = EIntK 1L; ety = e; epos = p });
      ety = TFrac e; epos = p }
  | _ -> terr p "类型 %s 不能省略初值" (pp_zty t)

let rec check_decl env p isconst is_frac is_unred name ty init =
  let base = conv_ty env.g p ty in
  let want =
    if is_frac then begin
      if not (frac_elem_ok base) then
        terr p "frac 不支持元素类型 %s（支持 i8..i128 / u8..u128 / f32 / f64）"
          (pp_zty base);
      TFrac base
    end
    else base
  in
  let tinit =
    match init with
    | None -> zero_of p want
    | Some init ->
    (match resolve want, init with
     | TBool, EBool (b, _) ->
      { e = EBoolK b; ety = TBool; epos = p }
    | TBool, EInt (n, _) ->
      (* bool flag = 0/1 *)
      { e = EBoolK (n = 1L); ety = TBool; epos = p }
    | TBool, ECast _ ->
      (* bool b = cast(x, bool)：数值/字符串非零（非空）为 true *)
      check_expr env init
    | TBool, _ ->
      (* 布尔表达式初值：比较、and/or 等结果本就是 TBool *)
      let t = check_expr env init in
      if resolve t.ety <> TBool then
        terr p "bool 类型只能用 true/false、0/1 或布尔表达式初始化";
      t
    | TFrac e, EBin (Div, a, b, _) ->
      (* frac 字面量：分子 / 分母（不执行除法、不自动约分）；
         但若两侧本身已是 frac，则按普通分数除法处理（结果自动约分） *)
      let ta = check_expr env a and tb = check_expr env b in
      let ta_is_frac =
        (match resolve ta.ety with TFrac _ -> true | _ -> false) in
      if ta_is_frac then begin
        unify p tb.ety ta.ety;
        { e = EBinK (BDiv, ta, tb); ety = resolve ta.ety; epos = p }
      end
      else begin
        let ac =
          if resolve ta.ety = e then ta
          else { e = ECastK (ta, e); ety = e; epos = ta.epos }
        in
        let bc =
          if resolve tb.ety = e then tb
          else { e = ECastK (tb, e); ety = e; epos = tb.epos }
        in
        { e = EFracNewK (ac, bc); ety = TFrac e; epos = p }
      end
    | TFrac _, _ ->
      (* 单表达式初值：标量提升为分数（不约分） *)
      let t = check_expr env init in
      (match resolve t.ety with
       | TFrac e2 when resolve want = TFrac e2 -> t
       | TFrac _ -> terr p "frac 元素类型不一致"
       | TInt _ | TUint _ | TFloat _ | TVar _ -> mk_frac_from t (match resolve want with TFrac e -> e | _ -> assert false) p
       | _ -> terr p "不能把 %s 初始化为 frac" (pp_zty t.ety))
    | _, _ -> check_expr env init)
  in
  let tinit = coerce p tinit want in
  declare env name { lconst = isconst; lty = want; lslot = ""; lunred = is_unred };
  (* const 整数变量记录编译期值（数组长度用；非 const 不算常量） *)
  let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
  if isconst then
    (match resolve want, const_eval env tinit with
     | (TInt _ | TUint _), Some v -> Hashtbl.replace env.const_vals slot v
     | _ -> ());
  let needs_norm =
    (match resolve want with TFrac _ -> true | _ -> false) && not is_unred
  in
  SDeclK (isconst, slot, want, tinit, needs_norm)

(* 赋值目标为变量槽时的公共检查，返回槽名 *)
and assign_var env p name =
  match lookup_var env name with
  | Some l ->
    if l.lconst then
      terr p "不能给常量 %s 赋值（声明时用了 const）" name;
    l.lslot
  | None -> terr p "未定义的变量：%s" name

(* 复合赋值 / 自增自减（左值地址只求值一次）：
   - 数组/列表元素：SAugIndexK（下标只求值一次）
   - 标量变量：SAugVarK *)
and conv_binop (o : Ast.binop) : Hir.binop =
  match o with
  | Ast.Add -> BAdd | Ast.Sub -> BSub | Ast.Mul -> BMul | Ast.Div -> BDiv
  | Ast.Mod -> BMod | Ast.Eq -> BEq | Ast.Ne -> BNe | Ast.Lt -> BLt
  | Ast.Gt -> BGt | Ast.Le -> BLe | Ast.Ge -> BGe
  | Ast.And -> BAnd | Ast.Or -> BOr

and check_aug env p (lhs : expr) (bop : Ast.binop) (rhs : expr) =
  let bop = conv_binop bop in
  match lhs with
  | EIndex (EVar (arr, ap), idx, ip) ->
    (match lookup_var env arr with
     | Some l ->
       (match resolve l.lty with
        | TArray (e, _) | TList e as seqty ->
          if l.lconst then terr ap "不能修改常量 %s 的元素" arr;
          let ti = to_i64 (check_expr env idx) in
          let trhs = check_expr env rhs in
          let grow = (match seqty with TList _ -> true | _ -> false) in
          let trhs = coerce ip trhs e in
          SAugIndexK (l.lslot, e, ti, bop, trhs, grow)
        | t -> terr ap "复合赋值目标不支持下标：%s" (pp_zty t))
     | None -> terr ap "未定义的变量：%s" arr)
  | ESlice (EVar (arr, ap), a, b, step, sp) ->
    (* a[x,y:st] op= v：原地作用于原数组的区间元素（string/frac/f16/f128 不支持） *)
    (match lookup_var env arr with
     | Some l ->
       (match resolve l.lty with
        | TArray (e, _) | TList e ->
          if l.lconst then terr ap "不能修改常量 %s 的元素" arr;
          (match resolve e with
           | TString -> terr sp "string 切片不支持复合赋值"
           | TFrac _ -> terr sp "frac 切片不支持复合赋值"
           | TFloat 16 | TFloat 128 -> terr sp "f16/f128 切片不支持复合赋值"
           | _ ->
             let ta = to_i64 (check_expr env a) in
             let tb' = to_i64 (check_expr env b) in
             let ts =
               match step with
               | None -> { e = EIntK 1L; ety = TInt 64; epos = sp }
               | Some s -> to_i64 (check_expr env s)
             in
             let trhs = check_expr env rhs in
             let trhs = coerce sp trhs e in
             SAugSliceK (l.lslot, e, ta, tb', ts, bop, trhs))
        | t -> terr ap "复合赋值目标不支持切片：%s" (pp_zty t))
     | None -> terr ap "未定义的变量：%s" arr)
  | EVar (name, p') ->
    let slot = assign_var env p' name in
    let l = (match lookup_var env name with Some l -> l | None -> assert false) in
    (match resolve l.lty, bop with
     | TString, BAdd ->
       (* s += v：string 拼接后重新赋值（结果为独立堆串） *)
       let tself = { e = EVarK slot; ety = TString; epos = p' } in
       let trhs = check_expr env rhs in
       if resolve trhs.ety <> TString then
         terr p' "string 拼接要求两侧都是 string，得到 %s" (pp_zty trhs.ety);
       let cat =
         { e = ECallK ("zfy_str_concat", [ tself; trhs ]);
           ety = TString; epos = p' }
       in
       SAssignK (tself, cat, false)
     | _ ->
       let lty = l.lty in
       let trhs = check_expr env rhs in
       let needs_norm =
         (match resolve lty with TFrac _ -> not l.lunred | _ -> false) in
       let trhs = coerce p' trhs lty in
       SAugVarK (slot, lty, bop, trhs, needs_norm))
  | _ -> terr p "复合赋值/自增自减的目标必须是变量或数组/列表元素"

(* 语句块检查 *)
and check_block env (stmts : stmt list) : tblock =
  List.map (check_stmt env) stmts

(* 数组/列表声明检查（不含 split 初值特判）：返回语句种类 *)
and check_seq_decl env p isconst name e len is_list inits =
  (match resolve e with
   | TFrac _ -> terr p "frac 数组/列表暂不支持"
   | _ -> ());
  let vlen =
    match len, is_list with
    | None, true -> 0L
    | Some le, false ->
      let tl = check_expr env le in
      (match resolve tl.ety with
       | TInt _ | TUint _ | TVar _ -> ()
       | t -> terr p "数组长度要求整数类型，得到 %s" (pp_zty t));
      (match const_eval env tl with
       | Some n when Int64.compare n 0L >= 0 -> n
       | _ ->
         terr p "数组长度必须是编译期常量（字面量或 const 整数变量）")
    | Some _, true -> terr p "列表不写长度"
    | None, false -> terr p "数组必须写长度"
  in
  if (not is_list) && List.length inits > Int64.to_int vlen then
    terr p "初始值个数（%d）超过数组长度 %Ld" (List.length inits) vlen;
  (match inits, is_list with
  (* 列表整体初值：T list b = 源（源为同元素类型列表/数组 → 深拷贝） *)
   | [ ie ], true ->
     let ti = check_expr env ie in
     let copy_list () =
       declare env name
         { lconst = isconst; lty = TList e; lslot = ""; lunred = false };
       let slot =
         (match lookup_var env name with
          | Some l -> l.lslot
          | None -> assert false)
       in
       SSeqCopyK (isconst, slot, e, 0L, ti, true)
     in
     (match resolve ti.ety with
      | TList e2 when resolve e2 = resolve e -> copy_list ()
      | TArray (e2, _) when resolve e2 = resolve e -> copy_list ()
      | _ ->
        (* 回退：逐元素初值 *)
        let tinits =
          List.map
            (fun ie2 ->
              let ti2 = check_expr env ie2 in
              coerce p ti2 e)
            inits
        in
        declare env name
          { lconst = isconst; lty = TList e; lslot = ""; lunred = false };
        let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
        SSeqDeclK (isconst, slot, e, 0L, true, tinits))
  (* 数组整体初值：T array b[N] = 源（源为同元素类型数组/列表 → 深拷贝） *)
   | [ ie ], false ->
     let ti = check_expr env ie in
     (match resolve ti.ety with
      | TArray (e2, n2) when resolve e2 = resolve e && n2 = Int64.to_int vlen ->
        declare env name
          { lconst = isconst; lty = TArray (e, Int64.to_int vlen);
            lslot = ""; lunred = false };
        let slot =
          (match lookup_var env name with
           | Some l -> l.lslot
           | None -> assert false)
        in
        SSeqCopyK (isconst, slot, e, vlen, ti, false)
      | TList e2 when resolve e2 = resolve e ->
        declare env name
          { lconst = isconst; lty = TList e;
            lslot = ""; lunred = false };
        let slot =
          (match lookup_var env name with
           | Some l -> l.lslot
           | None -> assert false)
        in
        SSeqCopyK (isconst, slot, e, vlen, ti, true)
      | _ ->
        let tinits =
          List.map
            (fun ie2 ->
              let ti2 = check_expr env ie2 in
              coerce p ti2 e)
            inits
        in
        declare env name
          { lconst = isconst;
            lty = TArray (e, Int64.to_int vlen);
            lslot = ""; lunred = false };
        let slot =
          (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
        SSeqDeclK (isconst, slot, e, vlen, is_list, tinits))
   | _ ->
     let tinits =
       List.map
         (fun ie ->
           let ti = check_expr env ie in
           coerce p ti e)
         inits
     in
     declare env name
       { lconst = isconst;
         lty = if is_list then TList e else TArray (e, Int64.to_int vlen);
         lslot = ""; lunred = false };
     let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
     SSeqDeclK (isconst, slot, e, vlen, is_list, tinits))

and check_stmt env (st : stmt) : tstmt =
  let mk k = { s = k; spos = pos_of_stmt st } in
  match st with
  | SDecl (isconst, is_frac, is_unred, name, ty, init, p) ->
    mk (check_decl env p isconst is_frac is_unred name ty init)
  | SSeqDecl (isconst, name, ety, len, is_list, inits, p) ->
    mk (check_seq_decl env p isconst name (conv_ty env.g p ety) len is_list inits)
  | SAssign (lhs, rhs, p) ->
    (match lhs, rhs with
     | EIndex (EVar (arr, ap), idx, ip), _ ->
       (* arr[i] = v：元素写入（下标只求值一次） *)
       (match lookup_var env arr with
        | Some l ->
          (match resolve l.lty with
           | TArray (e, _) | TList e as seqty ->
             if l.lconst then
               terr ap "不能修改常量 %s 的元素" arr;
             let ti = to_i64 (check_expr env idx) in
             let trhs = check_expr env rhs in
             let grow = (match seqty with TList _ -> true | _ -> false) in
             let trhs = coerce ip trhs e in
             mk (SSeqSetK (l.lslot, e, ti, trhs, grow))
           | TString ->
             terr ip "字符串不支持按下标赋值（可用 replace 替换区间）"
           | t -> terr ap "该类型不支持下标赋值：%s" (pp_zty t))
        | None -> terr ap "未定义的变量：%s" arr)
     | EIndex (_, _, ip), _ ->
       terr ip "下标赋值目标必须是 数组/列表 变量，如 n[3] = 值"
     | EVar (name, p'), rhs' ->
       let slot = assign_var env p' name in
       let l = (match lookup_var env name with Some l -> l | None -> assert false) in
       let lty = l.lty in
       let trhs = check_expr env rhs' in
       let needs_norm =
         (match resolve lty with TFrac _ -> not l.lunred | _ -> false) in
       (match resolve trhs.ety, resolve lty with
        | TList e2, TArray (e, _) when resolve e2 = resolve e ->
          (* 数组/列表切片（TList 元素类型）赋给数组变量：运行时同为 seq，深拷贝 *)
          mk (SAssignK ({ e = EVarK slot; ety = trhs.ety; epos = p' }, trhs, false))
        | _, _ ->
          let trhs = coerce p' trhs lty in
          mk (SAssignK ({ e = EVarK slot; ety = trhs.ety; epos = p' }, trhs, needs_norm)))
     | _ -> terr p "不支持的赋值目标")
  | SAug (op, lhs, rhs, p) ->
    mk (check_aug env p lhs op rhs)
  | SInc (e, p) ->
    let one = Ast.EInt (1L, p) in
    mk (check_aug env p e Ast.Add one)
  | SDec (e, p) ->
    let one = Ast.EInt (1L, p) in
    mk (check_aug env p e Ast.Sub one)
  | SExpr e ->
    (match e with
     | ECast (EVar (name, np), _, _) ->
       (* cast(a, T) 单独成句：把 a 重绑定为 T 类型新槽（值转换，原槽保留） *)
       (match lookup_var env name with
        | None -> terr np "未定义的变量：%s" name
        | Some _ ->
          let te = check_expr env e in
          declare env name { lconst = false; lty = te.ety; lslot = ""; lunred = false };
          let slot =
            (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
          mk (SDeclK (false, slot, te.ety, te, false)))
     | _ ->
       let te = check_expr env e in
       mk (SExprK te))
  | SReturn (e, p) ->
    (match e with
     | None ->
       unify p env.fncur_ret TVoid;
       mk (SReturnK None)
     | Some e' ->
       let te = check_expr env e' in
       let te = coerce p te env.fncur_ret in
       mk (SReturnK (Some te)))
  | SIf (cond, then_b, else_b, p) ->
    let tc = check_expr env cond in
    unify p tc.ety TBool;
    push_scope env;
    let tb = check_block env then_b in
    pop_scope env;
    let eb =
      match else_b with
      | None -> []
      | Some b ->
        push_scope env;
        let r = check_block env b in
        pop_scope env;
        r
    in
    mk (SIfK (tc, tb, eb))
  | SWhile (cond, body, p) ->
    let tc = check_expr env cond in
    unify p tc.ety TBool;
    push_scope env;
    let tb = check_block env body in
    pop_scope env;
    mk (SWhileK (tc, tb))
  | SFor (inits, cond, updates, body, p) ->
    (* for 头部声明的变量作用域覆盖循环所在的整个块：
       不再为 for 单开作用域，循环结束后变量仍然可见（可直接复用索引） *)
    let init_stmts =
      List.map
        (function
          | FIDecl (isc, name, ty, e, p') ->
            { s = check_decl env p' isc false false name ty e; spos = p' }
          | FIExpr (e, p') -> { s = SExprK (check_expr env e); spos = p' })
        inits
    in
    let tc = check_expr env cond in
    unify p tc.ety TBool;
    let up_stmts = List.map (check_for_update env) updates in
    let tb = check_block env body in
    mk (SForK (init_stmts, tc, up_stmts, tb))
  | SOutput (args, sep, end_, p) ->
    let targs = List.map (check_expr env) args in
    List.iter
      (fun (ta : texpr) ->
        match resolve ta.ety with
        | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString | TFrac _ | TVar _ -> ()
        | t -> terr p "output 不支持该参数类型：%s" (pp_zty t))
      targs;
    (* sep 默认 ""，end 默认 "\n"；非 char/string 值强制转 string *)
    let ioval default (e : expr option) =
      match e with
      | None -> { e = EStrK default; ety = TString; epos = p }
      | Some e' -> to_string_of (check_expr env e')
    in
    mk (SOutputK (targs, ioval "" sep, ioval "\n" end_))
  | SInput (targets, delim, p) ->
    (* delim：char/string 表达式（变量亦可，其他类型强转 string）；
       None 默认"换行和空格"字符集 *)
    let tdelim =
      match delim with
      | None -> None
      | Some de ->
        let td = check_expr env de in
        (match resolve td.ety with
         | TChar | TString -> ()
         | TFrac _ | TArray _ | TList _ | TVoid ->
           terr p "input 的 delim 必须是 char 或 string，得到 %s" (pp_zty td.ety)
         | _ -> ());
        Some (to_string_of td)
    in
    let ttargets =
      List.map
        (function
          | InNew (name, ty, p') ->
            let t = conv_ty env.g p' ty in
            check_input_ty p' t;
            declare env name { lconst = false; lty = t; lslot = ""; lunred = false };
            let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
            { tname = slot; tnew = true; tty = t }
          | InUse (name, p') ->
            (match lookup_var env name with
             | Some l ->
               if l.lconst then
                 terr p' "不能向常量 %s 输入" name;
               check_input_ty p' l.lty;
               { tname = l.lslot; tnew = false; tty = l.lty }
             | None -> terr p' "未定义的变量：%s" name))
        targets
    in
    mk (SInputK (ttargets, tdelim))
  | SReduce (x, cnt, start, p) ->
    (* reduce(x, 次数, 起始除数)：x 必须是 frac 类型的（可变）局部变量 *)
    (match x with
     | EVar (name, p') ->
       (match lookup_var env name with
        | Some l ->
          (match resolve l.lty with
           | TFrac e ->
             if l.lconst then
               terr p' "不能对常量 %s 执行 reduce" name;
             let tc = check_expr env cnt and ts = check_expr env start in
             unify p tc.ety (TInt 64);
             unify p ts.ety (TInt 64);
             let tx = { e = EVarK l.lslot; ety = TFrac e; epos = p' } in
             mk (SReduceK (tx, tc, ts))
           | t -> terr p' "reduce 要求 frac 类型的变量，得到 %s" (pp_zty t))
        | None -> terr p' "未定义的变量：%s" name)
     | _ -> terr p "reduce 的第一个参数必须是 frac 类型的局部变量")
  | SRemove (lhs, idx, p) ->
    (* remove(数组/列表名, 下标)：数组=槽位填零值（长度不变）；列表=删除并左移（长度-1） *)
    (match lhs with
     | EVar (name, p') ->
       (match lookup_var env name with
        | Some l ->
          (match resolve l.lty with
           | TArray (e, _) | TList e as seqty ->
             if l.lconst then
               terr p' "不能对常量 %s 执行 remove" name;
             let ti = to_i64 (check_expr env idx) in
             let isl = (match seqty with TList _ -> true | _ -> false) in
             mk (SRemoveK (l.lslot, e, ti, isl))
           | t -> terr p' "remove 只能作用于数组/列表，得到 %s" (pp_zty t))
        | None -> terr p' "未定义的变量：%s" name)
     | _ -> terr p "remove 的第一个参数必须是数组/列表变量")
  | SBreak p ->
    ignore p;
    mk SBreakK
  | SContinue p ->
    ignore p;
    mk SContinueK
  | SThrow (e, p) ->
    (* throw 消息：char/string（其他可打印类型统一转 string） *)
    let te = to_string_of (check_expr env e) in
    mk (SThrowK te)
  | STry (try_b, (binding, catch_b), p) ->
    ignore p;
    push_scope env;
    let tb = check_block env try_b in
    pop_scope env;
    push_scope env;
    (match binding with
     | Some nm ->
       declare env nm { lconst = false; lty = TString; lslot = ""; lunred = false }
     | None -> ());
    let cb = check_block env catch_b in
    pop_scope env;
    mk (STryK (tb, binding, cb))

(* for 更新项 -> 赋值语句 *)
and check_for_update env (u : for_update) : tstmt =
  match u with
  | FUAssign (l, r, p) -> check_stmt env (SAssign (l, r, p))
  | FUOp (op, l, r, p) -> check_stmt env (SAug (op, l, r, p))
  | FUInc (e, p) -> check_stmt env (SInc (e, p))
  | FUDec (e, p) -> check_stmt env (SDec (e, p))

and pos_of_stmt = function
  | SDecl (_, _, _, _, _, _, p) | SAssign (_, _, p) | SAug (_, _, _, p)
  | SInc (_, p) | SDec (_, p)
  | SReturn (_, p) | SIf (_, _, _, p)
  | SWhile (_, _, p) | SFor (_, _, _, _, p) | SReduce (_, _, _, p)
  | SRemove (_, _, p)
  | SOutput (_, _, _, p) | SInput (_, _, p)
  | SSeqDecl (_, _, _, _, _, _, p)
  | SThrow (_, p)
  | STry (_, _, p)
  | SBreak p
  | SContinue p -> p
  | SExpr e -> pos_of_expr e

(* ---------- 收尾：未求解 TVar 默认值 ---------- *)

let rec subst_ty (t : zty) : zty =
  match resolve t with
  | TArray (t', n) -> TArray (subst_ty t', n)
  | TList t' -> TList (subst_ty t')
  | TVar n ->
    (match Hashtbl.find_opt subs n with
     | Some t' -> subst_ty t'
     | None ->
       (* 默认整型 i64 *)
       Hashtbl.replace subs n (TInt 64);
       TInt 64)
  | t' -> t'

(* ---------- 程序级检查 ---------- *)

(* 函数式内建名（用户自定义函数不得与之冲突） *)
let builtin_names = [ "length"; "find"; "trim"; "split"; "replace"; "prec" ]

(* 参数 -> zty：
   - 标量：可带 frac 修饰
   - 列表：TList elem
   - 数组：长度为字面量 → TArray(elem, n)（调用点静态校验长度）；
     长度为之前的参数名 → TList elem（动态长度，运行期任意） *)
let conv_param g pos prev_names (pd : param) : zty =
  let base = conv_ty g pos pd.pty in
  match pd.pseq with
  | PScalar ->
    if pd.pfrac then begin
      if not (frac_elem_ok base) then
        terr pos "frac 参数不支持元素类型 %s" (pp_zty base);
      TFrac base
    end else base
  | PList -> TList base
  | PArray len ->
    (match len with
     | EInt (n, _) when n >= 0L -> TArray (base, Int64.to_int n)
     | EVar (nm, npp) ->
       if List.mem nm prev_names then TList base
       else terr npp "数组参数的长度必须是字面量或之前声明的参数名：%s" nm
     | _ ->
       terr pos "数组参数的长度必须是字面量或之前声明的参数名")

let check_program (prog : program) : hir =
  let g : genv = { fns = Hashtbl.create 16 } in
  (* 第一遍：收集函数签名（参数含数组/列表/frac） *)
  List.iter
    (function
      | IFn { name; params; ret; rfrac; pos; _ } ->
        if List.mem name builtin_names then
          terr pos "函数名 %s 与内建函数冲突，请换名" name;
        if Hashtbl.mem g.fns name then
          terr pos "重复定义的函数：%s" name;
        let prev = ref [] in
        let ptys =
          List.map
            (fun (pd : param) ->
              let t = conv_param g pos !prev pd in
              prev := pd.pname :: !prev;
              t)
            params
        in
        let rty =
          match ret with
          | None -> TVoid
          | Some t ->
            let base = conv_ty g pos t in
            if rfrac then begin
              if not (frac_elem_ok base) then
                terr pos "frac 返回类型不支持元素类型 %s" (pp_zty base);
              TFrac base
            end else base
        in
        Hashtbl.replace g.fns name { params = ptys; ret = rty }
      | IUse _ | IMod _ | IDecl _ -> ())
    prog;
  (* 第二遍：函数体检查 *)
  let env =
    { g; scopes = []; fncur_ret = TVoid; slotn = 0;
      fnvars = Hashtbl.create 8; const_vals = Hashtbl.create 16 }
  in
  (* 全局作用域：顶层声明（const 内联；非 const 为全局可变变量） *)
  push_scope env;
  (* 顶层作用域中把变量槽改写为全局槽名 @g.<名字>（LLVM 全局变量） *)
  let set_global_slot name slot =
    match env.scopes with
    | sc :: _ ->
      (match Hashtbl.find_opt sc name with
       | Some l -> Hashtbl.replace sc name { l with lslot = slot }
       | None -> ())
    | [] -> ()
  in
  let ginit = ref [] in                       (* 全局初始化语句（zfy.globals 执行） *)
  let gdeclared = ref [] in                   (* (槽名, 类型) *)
  List.iter
    (function
      | IDecl (SDecl (true, is_frac, is_unred, name, ty, init, p), _) ->
        (* 顶层 const：编译期常量（整数使用处内联，保持原语义） *)
        if is_frac || is_unred then
          terr p "顶层 const 不支持 frac/unreduced 修饰";
        if lookup_var env name <> None then
          terr p "重复声明的顶层常量：%s" name;
        let _t : tstmt = { s = check_decl env p true false false name ty init; spos = p } in
        (match lookup_var env name with
         | Some l ->
           (match resolve l.lty with
            | TInt _ | TUint _ -> ()
            | _ -> terr p "顶层 const 目前仅支持整数类型，得到 %s" (pp_zty l.lty))
         | None -> ())
      | IDecl (SDecl (is_const, is_frac, is_unred, name, ty, init, p), _) ->
        (* 非 const 标量（含 frac）：全局可变变量 *)
        if lookup_var env name <> None then
          terr p "重复声明的顶层变量：%s" name;
        let st = { s = check_decl env p is_const is_frac is_unred name ty init; spos = p } in
        let lty = (match lookup_var env name with Some l -> l.lty | None -> assert false) in
        let slot = "@g." ^ name in
        set_global_slot name slot;
        gdeclared := (slot, lty) :: !gdeclared;
        ginit :=
          { st with
            s = (match st.s with
                 | SDeclK (c, _, t, e, nn) -> SDeclK (c, slot, t, e, nn)
                 | s' -> s') } :: !ginit
      | IDecl (SSeqDecl (isconst, name, ety, len, is_list, inits, p), _) ->
        (* 顶层数组/列表：全局可变变量（const 也可，元素修改受 const 约束） *)
        if lookup_var env name <> None then
          terr p "重复声明的顶层变量：%s" name;
        let st =
          { s = check_seq_decl env p isconst name (conv_ty env.g p ety) len
                    is_list inits; spos = p } in
        let lty = (match lookup_var env name with Some l -> l.lty | None -> assert false) in
        let slot = "@g." ^ name in
        set_global_slot name slot;
        gdeclared := (slot, lty) :: !gdeclared;
        ginit :=
          { st with
            s = (match st.s with
                 | SSeqDeclK (c, _, t, l2, isl, inits') -> SSeqDeclK (c, slot, t, l2, isl, inits')
                 | SSeqCopyK (c, _, t, l2, src, isl) -> SSeqCopyK (c, slot, t, l2, src, isl)
                 | s' -> s') } :: !ginit
      | IDecl _ -> ()
      | _ -> ())
    prog;
  let hfns =
    List.filter_map
      (function
        | IFn { name; params; ret; body; pos } ->
          let sig_ = Hashtbl.find g.fns name in
          env.fncur_ret <- sig_.ret;
          env.fnvars <- Hashtbl.create 8;   (* 槽名按函数隔离 *)
          push_scope env;
          let tparams =
            List.map2
              (fun (pd : param) pty ->
                declare env pd.pname
                  { lconst = false; lty = pty; lslot = ""; lunred = false };
                let slot = (match lookup_var env pd.pname with
                            | Some l -> l.lslot | None -> assert false) in
                (false, slot, pty))
              params sig_.params
          in
          let tbody = check_block env body in
          pop_scope env;
          (* 返回类型非 void 时，要求有 return 或尾表达式 *)
          if (match sig_.ret with TVoid -> false | _ -> true) then begin
            let has_ret =
              List.exists (fun (s : tstmt) -> match s.s with SReturnK _ -> true | _ -> false) tbody
              ||
              (match List.rev tbody with
               | { s = SExprK _; _ } :: _ -> true
               | _ -> false)
            in
            if not has_ret then
              terr pos "函数 %s 声明了返回类型 %s，但函数体可能不返回值"
                name (pp_zty sig_.ret)
          end;
          Some { fname = name; fparams = tparams; fret = sig_.ret; fbody = tbody }
        | _ -> None)
      prog
  in
  (* 必须有 main *)
  if not (Hashtbl.mem g.fns "main") then
    terr { line = 1; col = 1 } "程序缺少 main()";
  (* 类型变量求解落地 *)
  let rec fix_texpr (e : texpr) : texpr =
    let ety0 = subst_ty e.ety in
    (* 浮点字面量未被上下文约束时，默认应为 f64 而非 i64 *)
    let ety =
      match e.e, ety0 with
      | EFloatK _, TInt 64 -> TFloat 64
      | _, _ -> ety0
    in
    let e' =
      match e.e with
      | EBinK (op, a, b) -> EBinK (op, fix_texpr a, fix_texpr b)
      | EUnK (op, a) -> EUnK (op, fix_texpr a)
      | ECallK (c, args) -> ECallK (c, List.map fix_texpr args)
      | ECastK (a, t) -> ECastK (fix_texpr a, subst_ty t)
      | EFracNewK (a, b) -> EFracNewK (fix_texpr a, fix_texpr b)
      | ESeqGetK (a, i) -> ESeqGetK (fix_texpr a, fix_texpr i)
      | ESeqLenK a -> ESeqLenK (fix_texpr a)
      | ESeqSliceK (a, b, c, d) ->
        ESeqSliceK (fix_texpr a, fix_texpr b, fix_texpr c, fix_texpr d)
      | ESplitK (a, c) -> ESplitK (fix_texpr a, fix_texpr c)
      | EPushK (a, v) -> EPushK (fix_texpr a, fix_texpr v)
      | k -> k
    in
    { e = e'; ety; epos = e.epos }
  in
  let rec fix_stmt (s : tstmt) : tstmt =
    let s' =
      match s.s with
      | SDeclK (c, n, t, e, nn) ->
        SDeclK (c, n, subst_ty t, fix_texpr e, nn)
      | SSeqDeclK (c, n, t, len, isl, inits) ->
        SSeqDeclK (c, n, subst_ty t, len, isl, List.map fix_texpr inits)
      | SSeqCopyK (c, n, t, len, src, isl) ->
        SSeqCopyK (c, n, subst_ty t, len, fix_texpr src, isl)
      | SAssignK (a, b, nn) -> SAssignK (fix_texpr a, fix_texpr b, nn)
      | SAugIndexK (n, t, i, op, v, g) ->
        SAugIndexK (n, subst_ty t, fix_texpr i, op, fix_texpr v, g)
      | SAugVarK (n, t, op, v, nn) ->
        SAugVarK (n, subst_ty t, op, fix_texpr v, nn)
      | SAugSliceK (n, t, a, b, st, op, v) ->
        SAugSliceK (n, subst_ty t, fix_texpr a, fix_texpr b, fix_texpr st, op,
                    fix_texpr v)
      | SSeqSetK (n, t, i, v, g) ->
        SSeqSetK (n, subst_ty t, fix_texpr i, fix_texpr v, g)
      | SRemoveK (n, t, i, b) -> SRemoveK (n, subst_ty t, fix_texpr i, b)
      | SExprK e -> SExprK (fix_texpr e)
      | SReturnK e -> SReturnK (Option.map fix_texpr e)
      | SIfK (c, a, b) -> SIfK (fix_texpr c, List.map fix_stmt a, List.map fix_stmt b)
      | SWhileK (c, b) -> SWhileK (fix_texpr c, List.map fix_stmt b)
      | SForK (inits, c, ups, b) ->
        SForK (List.map fix_stmt inits, fix_texpr c, List.map fix_stmt ups,
               List.map fix_stmt b)
      | SOutputK (args, sep, end_) ->
        SOutputK (List.map fix_texpr args, fix_texpr sep, fix_texpr end_)
      | SInputK (ts, d) ->
        SInputK (List.map (fun t -> { t with tty = subst_ty t.tty }) ts,
                 Option.map fix_texpr d)
      | SReduceK (x, n, st) -> SReduceK (fix_texpr x, fix_texpr n, fix_texpr st)
      | SThrowK e -> SThrowK (fix_texpr e)
      | STryK (tb, b, cb) ->
        STryK (List.map fix_stmt tb, b, List.map fix_stmt cb)
      | k -> k
    in
    { s = s'; spos = s.spos }
  in
  let hfns =
    List.map
      (fun (f : tfn) ->
        { f with
          fparams = List.map (fun (m, n, t) -> (m, n, subst_ty t)) f.fparams;
          fret = subst_ty f.fret;
          fbody = List.map fix_stmt f.fbody })
      hfns
  in
  { hfns; hglobals = List.rev !gdeclared; ginit = List.map fix_stmt (List.rev !ginit) }
