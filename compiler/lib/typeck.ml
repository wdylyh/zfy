(* 类型检查 + 类型推断 *)
open Tokens
open Ast
open Hir

exception TypeError of pos * string

let terr p fmt =
  Printf.ksprintf (fun s -> raise (TypeError (p, s))) fmt

(* 多错误收集（n3）：check_program 期间语句级/函数级恢复时收集的错误。
   driver 在检查结束后统一读取报告；非空时不进入后续阶段 *)
let collected : (pos * string) list ref = ref []

(* 9d：extern "C" 函数名名单（i128 参数按引用传、返回值按 <2 x i64> 接收，
   与 clang win32 的 __int128 ABI 一致） *)
let extern_fns : (string, unit) Hashtbl.t = Hashtbl.create 8

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
  | TPtr t -> TPtr (resolve t)
  | TErr t -> TErr (resolve t)
  | TFunSig (ptys, ret) -> TFunSig (List.map resolve ptys, resolve ret)
  | t -> t

let rec occurs n = function
  | TVar m -> m = n
  | TFrac t -> occurs n t
  | TArray (t, _) | TList t -> occurs n t
  | TPtr t -> occurs n t
  | TErr t -> occurs n t
  | TFunSig (ptys, ret) -> List.exists (occurs n) ptys || occurs n ret
  | _ -> false

(* 严格 unify：数值类型间不做隐式兼容（转换必须显式 cast），
   仅字面量的 TVar 可被约束求解 *)
let rec unify p a b =
  let a = resolve a and b = resolve b in
  if a = b then ()
  else
    match a, b with
    | TVar n, t | t, TVar n ->
      if occurs n t then terr p "circular type inference constraint"
      else Hashtbl.replace subs n t
    | TFrac ta, TFrac tb -> unify p ta tb
    | TArray (ta, na), TArray (tb, nb) ->
      if na <> nb then terr p "array lengths differ: %d vs %d" na nb;
      unify p ta tb
    | TList ta, TList tb -> unify p ta tb
    | TErr ta, TErr tb -> unify p ta tb
    | _ ->
      terr p "type mismatch: expected %s, got %s (numeric conversion requires an explicit cast)"
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

type fn_sig = { params : zty list; prefs : bool list; ret : zty }
  (* prefs：各参数是否为 ref（传引用，new2.md #1）——ref 参数的 params 元素
     已降为 TPtr（调用方 f(ref y) 传地址，函数体内自动解引用） *)

(* struct 声明信息（字段 default 为 AST 表达式，构造时检查） *)
type sdefk = { spacked : bool; sfields : (string * zty * expr option) list }

type genv = { fns : (string, fn_sig) Hashtbl.t;
              structs : (string, sdefk) Hashtbl.t;
              aliases : (string, zty) Hashtbl.t }   (* type 别名 *)

type local = { lconst : bool; lty : zty; lslot : string; lunred : bool;
               lconstp : bool }   (* 指向 const 的指针（T const*，9c）：解引用写报错 *)
type env = {
  g : genv;
  mutable scopes : (string, local) Hashtbl.t list;
  mutable fncur_ret : zty;
  mutable slotn : int;                       (* shadowing 改名计数 *)
  mutable fnvars : (string, unit) Hashtbl.t; (* 函数内已用过的变量名（兄弟作用域同名也要新槽） *)
  const_vals : (string, int64) Hashtbl.t;    (* const 整数变量的编译期值（按槽名） *)
  mutable in_unsafe : bool;                  (* 是否在 unsafe 块内（指针算术门禁） *)
  mutable moved : (string, unit) Hashtbl.t;  (* 已被显式 move 的变量槽（使用报错；写回解除） *)
  mutable uses : (string * pos) list;        (* 当前函数体内全部 EVar 出现位置
                                                （自动 move 后向判定用，new2.md #1） *)
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
     | None ->
       (match Hashtbl.find_opt g.aliases s with
        | Some t' -> t'
        | None ->
          (match Hashtbl.find_opt g.structs s with
           | Some _ -> TStruct s
           | None -> terr pp "undefined type: %s" s)))
  | TPtr (t', pp) -> TPtr (conv_ty g pp t')
  | TPtrC (t', pp) -> TPtr (conv_ty g pp t')   (* const 性在槽级跟踪（lconstp） *)
  | TErr (t', pp) -> TErr (conv_ty g pp t')
  | TFun (ret, ptys, pp) ->
    (* 函数类型统一表示为指针：TPtr (TFunSig ...)（与函数名引用/函数指针
       变量一致，LLVM 层均为 ptr） *)
    TPtr (TFunSig (List.map (fun pt -> conv_ty g pp pt) ptys, conv_ty g pp ret))

let pos_of_expr = function
  | EInt (_, p) | EFloat (_, p) | EStr (_, p) | EChar (_, p) | EBool (_, p)
  | EVar (_, p) | EBin (_, _, _, p) | EUn (_, _, p) | ECall (_, _, p)
  | EIndex (_, _, p) | ESlice (_, _, _, _, p)
  | ECast (_, _, p)
  | EStructNew (_, _, p) | EField (_, _, p)
  | EAddrOf (_, p) | EDeref (_, p) | ENull p
  | EFail (_, _, p) | EPanic (_, _, p) | EUnwrap (_, _, p) | EPropagate (_, p)
  | EBlock (_, p) -> p

(* "a.b.c" -> Some ("a", ["b"; "c"])；不含 '.'、首尾为 '.' 或有空段时 None *)
let split_field_path (name : string) : (string * string list) option =
  match String.index_opt name '.' with
  | Some i when i > 0 && i < String.length name - 1 ->
    let rest =
      String.split_on_char '.' (String.sub name (i + 1) (String.length name - i - 1))
    in
    if List.exists (fun s -> s = "") rest then None
    else Some (String.sub name 0 i, rest)
  | _ -> None

(* genv.structs -> sdef 列表（布局计算/sizeof 用） *)
let structs_list (g : genv) : Hir.sdef list =
  Hashtbl.fold
    (fun k v acc ->
      { Hir.sname = k; Hir.spacked = v.spacked;
        Hir.sfields = List.map (fun (n, t, _) -> (n, t)) v.sfields } :: acc)
    g.structs []

(* ErrCode 标准错误码常量（ErrCode.<名>；自定义码直接写字面量，须 ≥100） *)
let errcode_const = function
  | "OK" -> Some 0L | "DIV_ZERO" -> Some 1L | "OOB" -> Some 2L
  | "NOT_FOUND" -> Some 3L | "IO" -> Some 4L | "CAST" -> Some 5L
  | "INPUT" -> Some 6L | "CUSTOM" -> Some 100L
  | _ -> None

(* ---------- 表达式检查 ---------- *)

(* 类型零值表达式（声明省略初值时使用；struct 递归为全字段零值/default 构造） *)
let rec zero_of (env : env) (p : pos) (t : zty) : texpr =
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
  | TStruct s ->
    (* 裸构造等同 Name() 全默认构造：字段 default 优先、缺省退零值
       （与 check_decl 裸声明路径一致；此前只取零值会丢失嵌套字段的
       非零 default，如 Outer 裸声明丢 Inner.msg="im"） *)
    check_struct_new env p s []
  | TPtr _ -> mk ENullK
  | TErr et ->
    (* T! 裸声明：成功包元素零值（code=0 误读安全）；
       ety 须为外层 TErr（模式变量 et 避免遮蔽外层 t） *)
    { e = EErrOkK (zero_of env p et); ety = t; epos = p }
  | _ -> terr p "type %s cannot omit an initializer" (pp_zty t)

(* struct 字段缺省值：数组/列表填空 seq，其余按类型零值（递归含 struct） *)
and field_zero (env : env) (p : pos) (ft : zty) : texpr =
  let ft = resolve ft in
  match ft with
  | TArray _ | TList _ -> { e = EEmptySeqK; ety = ft; epos = p }
  | _ -> zero_of env p ft

(* 查 struct 字段：返回 (序号, 字段类型)。
   base 为指针 TPtr(TStruct) 时自动解引用（p.x 等同于先解引用再取字段 x） *)
and find_field (env : env) p (s : string) (seg : string) : int * zty =
  match Hashtbl.find_opt env.g.structs s with
  | None -> terr p "undefined type: %s" s
  | Some sd ->
    let rec go i = function
      | [] -> terr p "struct %s has no field %s" s seg
      | (fn, ft, _) :: rest -> if fn = seg then (i, ft) else go (i + 1) rest
    in
    go 0 sd.sfields

(* 字段读取表达式：base 为 struct 类型（或指针，自动解引用），seg 为字段名 *)
and field_of (env : env) p (base : texpr) (seg : string) : texpr =
  match resolve base.ety with
  | TPtr (TStruct s) | TStruct s ->
    let (idx, fty) = find_field env p s seg in
    { e = EFieldK (base, idx); ety = fty; epos = p }
  | t -> terr p "type %s has no field %s (dot access is only for structs)" (pp_zty t) seg

(* 编译期常量求值（const 整数变量 / 字面量四则） *)
and const_eval (env : env) (e : texpr) : int64 option =
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
  | TChar -> mk (ECallK ("zfy_tostr_char", [ t ], [])) TString
  | TBool -> mk (ECallK ("zfy_tostr_bool", [ t ], [])) TString
  | TInt 64 -> mk (ECallK ("zfy_tostr_i64", [ t ], [])) TString
  | TUint 64 -> mk (ECallK ("zfy_tostr_u64", [ t ], [])) TString
  | TInt 128 -> mk (ECallK ("zfy_tostr_i128", [ t ], [])) TString
  | TUint 128 -> mk (ECallK ("zfy_tostr_u128", [ t ], [])) TString
  | TInt _ ->
    let c = mk (ECastK (t, TInt 64)) (TInt 64) in
    mk (ECallK ("zfy_tostr_i64", [ c ], [])) TString
  | TUint _ ->
    let c = mk (ECastK (t, TUint 64)) (TUint 64) in
    mk (ECallK ("zfy_tostr_u64", [ c ], [])) TString
  | TFloat _ ->
    let c = mk (ECastK (t, TFloat 64)) (TFloat 64) in
    mk (ECallK ("zfy_tostr_f64", [ c ], [])) TString
  | TFrac _ | TArray _ | TList _ | TStruct _ | TVoid | TVar _
   | TPtr _ | TFunSig _ | TErr _ ->
     terr p "type %s cannot convert to string" (pp_zty t.ety)

and check_expr env (e : expr) : texpr =
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
       if Hashtbl.mem env.moved l.lslot then
         terr p' "variable %s has been moved and cannot be used (reassign to revive it)" name;
       (* const 整数：使用处直接内联编译期值（含顶层 const） *)
       (match l.lty, Hashtbl.find_opt env.const_vals l.lslot with
        | (TInt _ | TUint _), Some v when l.lconst ->
          { e = EIntK v; ety = l.lty; epos = p' }
        | _ -> mk (EVarK l.lslot) l.lty)
     | None ->
       (* 名字含 '.' 且整体 lookup 失败：首段为 struct 变量时构字段链
          （parser 把 a.b.c 合并成 EVar "a.b.c"） *)
       (match split_field_path name with
        | Some (first, segs) ->
          (match lookup_var env first with
           | Some l ->
             let root = { e = EVarK l.lslot; ety = l.lty; epos = p' } in
             field_chain env p' root segs
           | None ->
             (* ErrCode.<名>：标准错误码编译期常量（i32） *)
             (match first, segs with
              | "ErrCode", [ seg ] ->
                (match errcode_const seg with
                 | Some v -> mk (EIntK v) (TInt 32)
                 | None -> terr p' "undefined error code: ErrCode.%s" seg)
              | _ -> terr p' "undefined variable: %s" name))
        | None ->
          (* 名字是函数（本文件/extern 声明）：引用为函数指针值 *)
          (match Hashtbl.find_opt env.g.fns name with
           | Some sig' ->
             mk (EFunPtrK name) (TPtr (TFunSig (sig'.params, sig'.ret)))
           | None -> terr p' "undefined variable: %s" name)))
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
          terr p' "string concatenation requires both sides to be string, got %s and %s"
            (pp_zty rl) (pp_zty rr);
        mk (ECallK ("zfy_str_concat", [ tl; tr ], [])) TString
      end
      else if isf rl || isf rr then begin
        (* 分数运算：同元素类型 frac 相运算，或标量提升为分数。
           运算结果由运行时自动约分到最简 *)
        if bop = BMod then
          terr p' "frac does not support modulo";
        let elem, a', b' =
          match rl, rr with
          | TFrac e1, TFrac e2 ->
            if e1 = e2 then (e1, tl, tr)
            else
              terr p' "mismatched frac element types: %s vs %s"
                (pp_zty (TFrac e1)) (pp_zty (TFrac e2))
          | TFrac e, _ ->
            (match e, rr with
             | (TInt _ | TUint _), (TInt _ | TUint _ | TVar _) ->
               (e, tl, mk_frac_from tr e p')
             | TFloat _, (TFloat _ | TVar _) -> (e, tl, mk_frac_from tr e p')
             | _ ->
               terr p' "%s cannot be mixed with %s in this operation" (pp_zty (TFrac e)) (pp_zty rr))
          | _, TFrac e ->
            (match e, rl with
             | (TInt _ | TUint _), (TInt _ | TUint _ | TVar _) ->
               (e, mk_frac_from tl e p', tr)
             | TFloat _, (TFloat _ | TVar _) -> (e, mk_frac_from tl e p', tr)
             | _ ->
               terr p' "%s cannot be mixed with %s in this operation" (pp_zty rl) (pp_zty (TFrac e)))
          | _ -> assert false
        in
        let res_ty =
          match bop with
          | BEq | BNe | BLt | BGt | BLe | BGe -> TBool
          | _ -> TFrac elem
        in
        mk (EBinK (bop, a', b')) res_ty
      end
      else if (match rl with TPtr _ -> true | _ -> false)
            || (match rr with TPtr _ -> true | _ -> false) then begin
        (* 指针运算/比较：
           - 算术（p+n / p-n / p2-p1）仅 unsafe 块内（门禁）
           - == != 任意处允许（指针与指针/null 比较）
           - 其余运算不支持 *)
        let is_ptr = function TPtr _ -> true | _ -> false in
        match bop with
        | BAdd ->
          (match rl with
           | TPtr _ ->
             if not env.in_unsafe then
               terr p' "pointer arithmetic is only allowed inside an unsafe block";
             if is_ptr rr then terr p' "cannot add two pointers";
             let tn = to_i64 tr in
             mk (EBinK (BAdd, tl, tn)) tl.ety
           | _ -> terr p' "cannot add an integer to a pointer")
        | BSub ->
          (match rl, rr with
           | TPtr _, TPtr _ ->
             if not env.in_unsafe then
               terr p' "pointer arithmetic is only allowed inside an unsafe block";
             unify p' tl.ety tr.ety;
             mk (EBinK (BSub, tl, tr)) (TInt 64)   (* 元素差（i64） *)
           | TPtr _, _ ->
             if not env.in_unsafe then
               terr p' "pointer arithmetic is only allowed inside an unsafe block";
             let tn = to_i64 tr in
             mk (EBinK (BSub, tl, tn)) tl.ety
           | _ -> terr p' "cannot subtract a pointer from an integer")
        | BEq | BNe ->
          (match rl, rr with
           | TPtr _, TPtr _ | TPtr _, TVar _ | TVar _, TPtr _ | TVar _, TVar _ ->
             unify p' tl.ety tr.ety;
             mk (EBinK (bop, tl, tr)) TBool
           | _ ->
             terr p' "pointer comparison requires both sides to be pointers or null, got %s and %s"
               (pp_zty rl) (pp_zty rr))
        | _ ->
          terr p' "unsupported pointer operation: %s (only + - inside unsafe and == !=)"
            (pp_binop bop)
      end
      else
        let res_ty =
          match bop with
          | BEq | BNe | BLt | BGt | BLe | BGe ->
            if not (is_numeric rl && is_numeric rr) then
              terr p' "comparison requires numeric types, got %s and %s"
                (pp_zty tl.ety) (pp_zty tr.ety);
            TBool
          | _ ->
            if not (is_numeric rl && is_numeric rr) then
              terr p' "arithmetic requires numeric types, got %s and %s"
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
            terr p' "unary minus requires a numeric type, got %s" (pp_zty t1');
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
        | "panic_handler" ->
          (* panic_handler(f)：注册 panic 处理器（f 签名须 (i32, string) -> void；
             panic 时先调 f 再以退出码 101 终止） *)
          (match args with
           | [ CPos (EVar (fname, fp)) ] ->
             (match Hashtbl.find_opt env.g.fns fname with
              | Some { params = [ TInt 32; TString ]; prefs = _; ret = TVoid } ->
                mk (ECallK ("zfy_set_panic_handler",
                            [ { e = EFunPtrK fname;
                               ety = TPtr (TFunSig ([ TInt 32; TString ], TVoid));
                               epos = fp } ], [])) TVoid
              | Some s ->
                terr p' "panic_handler signature must be (i32, string) -> void, got (%s) -> %s"
                  (String.concat ", " (List.map pp_zty s.params)) (pp_zty s.ret)
              | None -> terr fp "undefined function: %s" fname)
           | _ -> terr p' "panic_handler expects a function name argument: panic_handler(fn)")
        | "push" ->
          (* push(列表, 值)：追加到末尾（自动扩长），无返回值 *)
          (match args with
           | [ CPos b; CPos v ] ->
             let tb = check_expr env b and tv0 = check_expr env v in
             (match resolve tb.ety with
              | TList e ->
                let tv0 = coerce p' tv0 e in
                mk (EPushK (tb, { tv0 with ety = resolve e })) TVoid
              | t -> terr p' "push target must be a list, got %s" (pp_zty t))
           | _ -> terr p' "push takes two arguments: push(list, value)")
        | "sizeof" | "alignof" ->
          (* 编译期内建：sizeof(类型) / alignof(类型)，返回 i64 常量 *)
          (match args with
           | [ CPos (EVar (tname, tpp)) ] ->
             let t = conv_ty env.g p' (TNamed (tname, tpp)) in
             let (sz, al) = Hir.ty_size_align (structs_list env.g) t in
             if sz < 0 then
               terr p' "sizeof/alignof does not support type %s" (Hir.pp_zty t);
             let v = if name = "sizeof" then sz else al in
             mk (EIntK (Int64.of_int v)) (TInt 64)
           | _ ->
             terr p' "%s expects a type name argument, e.g. %s(Point)" name name)
        | _ ->
          (match Hashtbl.find_opt env.g.structs name with
           | Some _ ->
             (* struct 构造：位置参数按字段序，命名参数按字段名，
                未给字段用 default，再退零值（数组/列表字段填空 seq） *)
             check_struct_new env p' name args
           | None ->
             (match lookup_var env name with
              | Some l when (match resolve l.lty with
                             | TPtr (TFunSig _) -> true | _ -> false) ->
               (* 局部函数指针调用：f(args) 间接调用 *)
               let tfnexpr = { e = EVarK l.lslot; ety = l.lty; epos = p' } in
               let (ptys, ret) =
                 match resolve l.lty with
                 | TPtr (TFunSig (pt, rt)) -> (pt, rt) | _ -> assert false
               in
               if List.length ptys <> List.length args then
                 terr p' "function pointer expects %d arguments, got %d"
                   (List.length ptys) (List.length args);
               let targs =
                 List.map2
                   (fun (ca : call_arg) pt ->
                     match ca with
                     | CPos e -> coerce p' (check_expr env e) pt
                     | CCopy e -> coerce p' (check_expr env e) pt
                     | CMove _ -> terr p' "function pointer calls do not support move arguments"
                     | CRef _ -> terr p' "function pointer calls do not support ref arguments"
                     | CNamed (n, _) -> terr p' "function pointer calls do not support named argument %s=" n)
                   args ptys
               in
               mk (EIndirectCallK (tfnexpr, targs)) ret
              | _ ->
               (* 字段链 callee（h.op(...)，new2.md 9a）：根为局部变量且
                  字段链为函数指针时间接调用；否则按普通函数调用处理
                  （模块扁平化后的点名 math.add 走 check_call） *)
               (match split_field_path name with
                | Some (first, _) ->
                  (match lookup_var env first with
                   | Some _ ->
                     let tcallee = check_expr env callee in
                     (match resolve tcallee.ety with
                      | TPtr (TFunSig (ptys, ret)) ->
                        if List.length ptys <> List.length args then
                          terr p' "function pointer expects %d arguments, got %d"
                            (List.length ptys) (List.length args);
                        let targs =
                          List.map2
                            (fun (ca : call_arg) pt ->
                              match ca with
                              | CPos e -> coerce p' (check_expr env e) pt
                              | CCopy e -> coerce p' (check_expr env e) pt
                              | CMove _ -> terr p' "function pointer calls do not support move arguments"
                              | CRef _ -> terr p' "function pointer calls do not support ref arguments"
                              | CNamed (n, _) -> terr p' "function pointer calls do not support named argument %s=" n)
                            args ptys
                        in
                        mk (EIndirectCallK (tcallee, targs)) ret
                      | _ ->
                        (* 普通/未知函数调用：走统一实参分派（自动 move/copy/ref） *)
                        let (targs, modes) = check_args_modes env args in
                        check_call env p' name targs modes)
                   | None ->
                     (* 普通函数调用：走统一实参分派（自动 move/copy/ref） *)
                     let (targs, modes) = check_args_modes env args in
                     check_call env p' name targs modes)
                | None ->
                 (* 普通函数调用：走统一实参分派（自动 move/copy/ref） *)
                 let (targs, modes) = check_args_modes env args in
                 check_call env p' name targs modes))))
     | _ -> terr p' "unsupported callee expression")
  | EIndex (base, idx, p') ->
    let tb = check_expr env base in
    let ti = to_i64 (check_expr env idx) in
    (match resolve tb.ety with
     | TArray (e, _) | TList e ->
       (* 数组/列表读取：结果为元素类型（越界运行时报错） *)
       mk (ESeqGetK (tb, ti)) e
     | TString ->
       (* s[i] 读字符：越界运行时报错，结果直接是 char *)
       mk (ECallK ("zfy_str_char", [ tb; ti ], [])) TChar
     | TPtr t ->
       (* 指针下标（自动解引用，无越界检查）：p[i] 等同于先按元素步进
          地址再解引用；绕过类型系统，强制 unsafe 块（new2.md #8） *)
       if not env.in_unsafe then
         terr p' "pointer subscript p[i] is only allowed inside an unsafe block";
       let addr = mk (EBinK (BAdd, tb, ti)) (TPtr t) in
       mk (EDerefK addr) t
     | t -> terr p' "type %s does not support index access" (pp_zty t))
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
       mk (ECallK ("zfy_str_slice", [ tb; ta; tb'; ts ], [])) TString
     | TArray (e, _) | TList e ->
       (* 数组/列表切片：返回同元素类型的动态序列（可赋给数组或列表变量） *)
       let ta = to_i64 (check_expr env a) and tb' = to_i64 (check_expr env b) in
       let ts =
         match step with
         | None -> { e = EIntK 1L; ety = TInt 64; epos = p' }
         | Some s -> to_i64 (check_expr env s)
       in
       mk (ESeqSliceK (tb, ta, tb', ts)) (TList e)
     | t -> terr p' "slicing is only for string/array/list, got %s" (pp_zty t))
  | EField (b, seg, p') ->
    (* 点号字段访问（parser 直出 EField 时） *)
    let tb = check_expr env b in
    field_of env p' tb seg
  | EStructNew (name, args, p') ->
    check_struct_new env p' name args
  | ENull p' -> mk ENullK (fresh_var ())
  | EAddrOf (e1, p') ->
    (match e1 with
     | EDeref (inner, _) ->
       (* 取地址解引用相互抵消：& (解引用 p) == p，直接化简为 p 本身 *)
       check_expr env inner
     | _ ->
       (* 可定位性：变量 / 字段链 / 元素 / 解引用（底层为变量名） *)
       let rec locatable (e : expr) =
         match e with
         | EVar _ -> true
         | EField (b, _, _) -> locatable b
         | EIndex (b, _, _) -> locatable b
         | EDeref (b, _) -> locatable b
         | _ -> false
       in
       if not (locatable e1) then
         terr p' "'&' can only take the address of a variable/field/element";
       let t1 = check_expr env e1 in
       if resolve t1.ety = TVoid then terr p' "cannot take the address of a void value";
       mk (EAddrOfK t1) (TPtr t1.ety))
  | EDeref (pe, p') ->
    let tp = check_expr env pe in
    (match resolve tp.ety with
     | TPtr t -> mk (EDerefK tp) t
     | t -> terr p' "dereference requires a pointer type, got %s" (pp_zty t))
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
      | TPtr _, TPtr _ -> true                  (* 指针间转换（void* 兼容） *)
      | (TInt 64 | TUint 64), TPtr _ | TPtr _, (TInt 64 | TUint 64) -> true
      | TVar _, _ | _, TVar _ -> true
      | _ -> false
    in
    if not ok then
      terr p' "unsupported cast: %s -> %s"
        (pp_zty a) (pp_zty b);
    (* string -> 数值：运行时解析可能失败，结果为 T!（错误值）；
       128 位目标无 8 字节 value 容器，保留旧 fail-fast 语义 *)
    let wide = match b with TInt 128 | TUint 128 | TFloat 128 -> true | _ -> false in
    if a = TString && b <> TString && num b && not wide then
      mk (ECastK (t1, t')) (TErr t')
    else mk (ECastK (t1, t')) t'
  | EBlock (_, p') -> terr p' "block expressions are not supported here"
  | EFail (c, m, p') ->
    (* fail(code, msg)：构造 T! 错误值；元素类型为 fresh TVar，由上下文
       （声明/赋值/返回/解包）统一求解 *)
    let tc = coerce p' (check_expr env c) (TInt 32) in
    let tm = to_string_of (check_expr env m) in
    mk (EFailK (tc, tm)) (TErr (fresh_var ()))
  | EPanic (code, msg, p') ->
    (* panic(code?, msg)：不可恢复终止（运行时 exit，无返回） *)
    let tc =
      match code with
      | None -> None
      | Some c -> Some (coerce p' (check_expr env c) (TInt 32))
    in
    let tm = to_string_of (check_expr env msg) in
    mk (EPanicK (tc, tm)) TVoid
  | EUnwrap (a, rhs, p') ->
    (* a ?? b：a 为 TErr t；b（或解包块值）为 t，结果 t *)
    let ta = check_expr env a in
    let elem =
      match resolve ta.ety with
      | TErr t -> t
      | t -> terr p' "left side of ?? must be a fallible value (T!), got %s" (pp_zty t)
    in
    (match rhs with
     | EBlock (_, bp) ->
       terr bp "??-block form (a ?? indented block) is only allowed as the RHS of a declaration or assignment"
     | _ ->
       let tb = coerce p' (check_expr env rhs) elem in
       mk (EUnwrapK (ta, tb)) elem)
  | EPropagate (a, p') ->
    (* a?：失败时从当前函数传播返回（函数返回类型须 T! 且元素一致） *)
    let ta = check_expr env a in
    let elem =
      match resolve ta.ety with
      | TErr t -> t
      | t -> terr p' "? left side must be a fallible value (T!), got %s" (pp_zty t)
    in
    (match resolve env.fncur_ret with
     | TErr rt -> unify p' elem rt
     | TVoid -> terr p' "? propagation requires the enclosing function to return T! (current: void)"
     | rt ->
       terr p' "? propagation requires the enclosing function to return %s! (current: %s)" (pp_zty elem) (pp_zty rt));
    mk (EPropagateK ta) elem

and check_call env p name targs modes =
  let sig_ =
    match List.assoc_opt name builtin_fns_aux with
    | Some (ptys, ret) -> { params = ptys; prefs = List.map (fun _ -> false) ptys; ret }
    | None ->
      (match Hashtbl.find_opt env.g.fns name with
       | Some s -> s
       | None -> terr p "undefined function: %s" name)
  in
  if List.length sig_.params <> List.length targs then
    terr p "function %s expects %d arguments, got %d"
      name (List.length sig_.params) (List.length targs);
  (* ref 参数/实参匹配（new2.md #1）：ref 参数必须 f(ref x)，反之亦然 *)
  List.iteri
    (fun i m ->
      let pref = try List.nth sig_.prefs i with _ -> false in
      if m = 2 && not pref then
        terr p "argument %d of %s is passed by ref, but the parameter is not declared ref" (i + 1) name
      else if pref && m <> 2 then
        terr p "parameter %d of %s is ref, pass the argument with ref (f(ref x))" (i + 1) name)
    modes;
  let targs =
    List.map2 (fun ta pt -> coerce p ta pt) targs sig_.params in
  let moves = List.map (fun m -> m = 1) modes in
  { e = ECallK (name, targs, moves); ety = sig_.ret; epos = p }

(* 显式 move 实参（f(move p)，change.md 1.6）：仅局部 owned 变量
   （string/数组/列表，非 const、非全局、未被 move 过）；标记该变量
   已 move——此后使用报错，重新赋值/写入解除 *)
and check_move_arg env (e : expr) : texpr =
  match e with
  | EVar (name, p) ->
    (match lookup_var env name with
     | Some l ->
       if l.lconst then
         terr p "cannot move constant %s" name;
       if l.lslot.[0] = '@' then
         terr p "cannot move global variable %s" name;
       if Hashtbl.mem env.moved l.lslot then
         terr p "variable %s has already been moved" name;
       (match resolve l.lty with
        | TString | TArray _ | TList _ ->
          (* 先按普通读检查实参（此时尚未标记 moved），再标记已 move *)
          let te = check_expr env e in
          Hashtbl.replace env.moved l.lslot ();
          te
        | t ->
          terr p "move supports only string/array/list arguments, %s has type %s"
            name (pp_zty t))
     | None -> check_expr env e)
  | _ -> terr (pos_of_expr e) "move can only apply to a local variable"

(* ---------- move/ref/copy 三选一与自动 move（new2.md #1） ---------- *)

(* 位置先后比较（同一函数体内，行/列序） *)
and pos_after (a : pos) (b : pos) =
  a.file = b.file && (a.line > b.line || (a.line = b.line && a.col > b.col))

(* 收集 AST 内全部 EVar 出现（名字, 位置）——含 callee/写目标/in_target，
   保守估计：任何出现都算"之后仍在使用" *)
and uses_of_expr (acc : (string * pos) list) (e : expr) : (string * pos) list =
  match e with
  | EVar (n, p) -> (n, p) :: acc
  | EInt _ | EFloat _ | EStr _ | EChar _ | EBool _ | ENull _ -> acc
  | EBin (_, a, b, _) -> uses_of_expr (uses_of_expr acc a) b
  | EUn (_, a, _) -> uses_of_expr acc a
  | ECall (callee, args, _) ->
    let acc = uses_of_expr acc callee in
    List.fold_left
      (fun acc (ca : call_arg) ->
        match ca with
        | CPos e | CMove e | CCopy e | CRef e -> uses_of_expr acc e
        | CNamed (_, e) -> uses_of_expr acc e)
      acc args
  | EIndex (b, i, _) -> uses_of_expr (uses_of_expr acc b) i
  | ESlice (b, a, c, s, _) ->
    let acc = uses_of_expr (uses_of_expr (uses_of_expr acc b) a) c in
    (match s with Some s -> uses_of_expr acc s | None -> acc)
  | ECast (a, _, _) -> uses_of_expr acc a
  | EStructNew (_, args, _) ->
    List.fold_left
      (fun acc (ca : call_arg) ->
        match ca with
        | CPos e | CMove e | CCopy e | CRef e -> uses_of_expr acc e
        | CNamed (_, e) -> uses_of_expr acc e)
      acc args
  | EField (b, _, _) -> uses_of_expr acc b
  | EBlock (blk, _) -> List.fold_left uses_of_stmt acc blk
  | EAddrOf (a, _) -> uses_of_expr acc a
  | EDeref (a, _) -> uses_of_expr acc a
  | EFail (a, b, _) -> uses_of_expr (uses_of_expr acc a) b
  | EPanic (a, b, _) ->
    let acc = (match a with Some a -> uses_of_expr acc a | None -> acc) in
    uses_of_expr acc b
  | EUnwrap (a, b, _) -> uses_of_expr (uses_of_expr acc a) b
  | EPropagate (a, _) -> uses_of_expr acc a

and uses_of_stmt (acc : (string * pos) list) (s : stmt) : (string * pos) list =
  match s with
  | SDecl (_, _, _, _, _, init, _) ->
    (match init with Some e -> uses_of_expr acc e | None -> acc)
  | SSeqDecl (_, _, _, len, _, inits, _) ->
    let acc = (match len with Some e -> uses_of_expr acc e | None -> acc) in
    List.fold_left uses_of_expr acc inits
  | SAssign (a, b, _) -> uses_of_expr (uses_of_expr acc a) b
  | SAug (_, a, b, _) -> uses_of_expr (uses_of_expr acc a) b
  | SInc (a, _) | SDec (a, _) -> uses_of_expr acc a
  | SExpr e -> uses_of_expr acc e
  | SReturn (e, _) -> (match e with Some e -> uses_of_expr acc e | None -> acc)
  | SIf (c, a, b, _) ->
    let acc = uses_of_expr acc c in
    let acc = List.fold_left uses_of_stmt acc a in
    (match b with Some b -> List.fold_left uses_of_stmt acc b | None -> acc)
  | SWhile (c, b, _) -> List.fold_left uses_of_stmt (uses_of_expr acc c) b
  | SFor (inits, c, ups, b, _) ->
    let acc =
      List.fold_left
        (fun acc (fi : for_init) ->
          match fi with
          | FIDecl (_, _, _, e, _) ->
            (match e with Some e -> uses_of_expr acc e | None -> acc)
          | FIExpr (e, _) -> uses_of_expr acc e)
        acc inits
    in
    let acc = uses_of_expr acc c in
    let acc =
      List.fold_left
        (fun acc (fu : for_update) ->
          match fu with
          | FUAssign (a, b, _) -> uses_of_expr (uses_of_expr acc a) b
          | FUOp (_, a, b, _) -> uses_of_expr (uses_of_expr acc a) b
          | FUInc (a, _) | FUDec (a, _) -> uses_of_expr acc a)
        acc ups
    in
    List.fold_left uses_of_stmt acc b
  | SOutput (es, sep, endl, _) ->
    let acc = List.fold_left uses_of_expr acc es in
    let acc = (match sep with Some e -> uses_of_expr acc e | None -> acc) in
    (match endl with Some e -> uses_of_expr acc e | None -> acc)
  | SInput (tgts, delim, _) ->
    let acc =
      List.fold_left
        (fun acc (t : in_target) ->
          match t with InNew _ -> acc | InUse (_, p) -> (p.line, p.col) |> fun _ -> acc)
        acc tgts
    in
    (* InUse 目标也是使用（读写） *)
    let acc =
      List.fold_left
        (fun acc (t : in_target) ->
          match t with InUse (n, p) -> (n, p) :: acc | InNew _ -> acc)
        acc tgts
    in
    (match delim with Some e -> uses_of_expr acc e | None -> acc)
  | SReduce (a, b, c, _) -> uses_of_expr (uses_of_expr (uses_of_expr acc a) b) c
  | SRemove (a, b, _) -> uses_of_expr (uses_of_expr acc a) b
  | SBreak _ | SContinue _ -> acc
  | SUnsafe (blk, _) -> List.fold_left uses_of_stmt acc blk

(* 变量 n 在位置 p 之后是否不再出现（最后使用判定，保守） *)
and last_use env n (p : pos) =
  not (List.exists (fun (m, q) -> m = n && pos_after q p) env.uses)

(* 自动 move 候选：聚合类型（string/数组/列表）局部非 const 变量、
   未被 move 过、且此后不再出现 *)
and auto_moveable env n (p : pos) =
  match lookup_var env n with
  | Some l ->
    (not l.lconst) && l.lslot.[0] <> '@'
    && (match resolve l.lty with
        | TString | TArray _ | TList _ -> true | _ -> false)
    && not (Hashtbl.mem env.moved l.lslot)
    && last_use env n p
  | None -> false

(* 显式 copy 实参：f(copy p)——与默认值语义相同（深拷贝）。
   若编译器能确定此处为最后使用（应自动 move），与显式 copy 冲突 → 报错 *)
and check_copy_arg env (e : expr) : texpr =
  (match e with
   | EVar (n, p) ->
     (match lookup_var env n with
      | Some l when (not l.lconst) && l.lslot.[0] <> '@'
                    && (match resolve l.lty with
                        | TString | TArray _ | TList _ -> true | _ -> false) ->
        if last_use env n p then
          terr p "explicit copy conflicts with automatic move: %s is not used after this point, the value is moved automatically (remove 'copy')" n
      | _ -> ())
   | _ -> ());
  check_expr env e

(* 显式 ref 实参：f(ref y)——传引用（对应参数须声明 ref）。
   y 须为可定位的局部变量；const/已 move 变量不可传 ref *)
and check_ref_arg env (e : expr) : texpr =
  match e with
  | EVar (n, p) ->
    (match lookup_var env n with
     | Some l ->
       if l.lconst then terr p "cannot pass constant %s by ref" n;
       if Hashtbl.mem env.moved l.lslot then
         terr p "variable %s has been moved and cannot be passed by ref" n;
       check_expr env (EAddrOf (e, p))
     | None -> check_expr env (EAddrOf (e, p)))
  | _ ->
    terr (pos_of_expr e) "ref can only apply to a variable (pass-by-reference needs an addressable variable)"

(* 实参列表 → (类型化实参, 模式列表)：0=值 1=move（含自动 move） 2=ref 3=copy *)
and check_args_modes env (args : call_arg list) : texpr list * int list =
  List.split
    (List.map
    (function
      | CPos e ->
        (match e with
         | EVar (n, p) when auto_moveable env n p ->
           (* 自动 move（new2.md #1：最后使用即 move）——免拷贝移交 *)
           (check_move_arg env e, 1)
         | _ -> (check_expr env e, 0))
      | CMove e -> (check_move_arg env e, 1)
      | CCopy e -> (check_copy_arg env e, 3)
      | CRef e -> (check_ref_arg env e, 2)
      | CNamed (n, e) ->
        terr (pos_of_expr e) "function calls do not support named argument %s=" n)
    args)

(* ref 参数体内改写（new2.md #1）：ref 参数在体内自动解引用——
   读 x → (x)^、写 x = v → (x)^ = v、x op= / x++ 同理；
   取地址 &x → &((x)^)（typeck 化简为指针本身）。
   ECall 的 callee 位置不改写（必为函数名/字段路径） *)
and deref_refs (refs : string list) (body : block) : block =
  let in_refs n = List.mem n refs in
  let rec re (e : expr) : expr =
    match e with
    | EVar (n, p) when in_refs n -> EDeref (EVar (n, p), p)
    | EVar _ -> e
    | EInt _ | EFloat _ | EStr _ | EChar _ | EBool _ | ENull _ -> e
    | EBin (o, a, b, p) -> EBin (o, re a, re b, p)
    | EUn (o, a, p) -> EUn (o, re a, p)
    | ECall (callee, args, p) ->
      ECall (callee,
             List.map
               (function
                 | CPos a -> CPos (re a)
                 | CMove a -> CMove (re a)
                 | CCopy a -> CCopy (re a)
                 | CRef a -> CRef a   (* ref 实参取原变量地址，不改写 *)
                 | CNamed (n2, a) -> CNamed (n2, re a))
               args, p)
    | EIndex (b, i, p) -> EIndex (re b, re i, p)
    | ESlice (b, a, c, s, p) ->
      ESlice (re b, re a, re c, (match s with Some s -> Some (re s) | None -> None), p)
    | ECast (a, t, p) -> ECast (re a, t, p)
    | EStructNew (n2, args, p) ->
      EStructNew (n2,
                  List.map
                    (function
                      | CPos a -> CPos (re a)
                      | CMove a -> CMove (re a)
                      | CCopy a -> CCopy (re a)
                      | CRef a -> CRef a
                      | CNamed (n3, a) -> CNamed (n3, re a))
                    args, p)
    | EField (b, s, p) -> EField (re b, s, p)
    | EBlock (blk, p) -> EBlock (List.map rs blk, p)
    | EAddrOf (a, p) -> EAddrOf (re a, p)
    | EDeref (a, p) -> EDeref (re a, p)
    | EFail (a, b, p) -> EFail (re a, re b, p)
    | EPanic (a, b, p) -> EPanic ((match a with Some a -> Some (re a) | None -> None), re b, p)
    | EUnwrap (a, b, p) ->
      EUnwrap (re a, (match b with EBlock (blk, bp) -> EBlock (List.map rs blk, bp) | b2 -> b2), p)
    | EPropagate (a, p) -> EPropagate (re a, p)
  (* 赋值类左值：EVar ∈ refs → EDeref（解引用写） *)
  and lhs (e : expr) : expr =
    match e with
    | EVar (n, p) when in_refs n -> EDeref (EVar (n, p), p)
    | e2 -> re e2
  and rs (s : stmt) : stmt =
    match s with
    | SAssign (l, r, p) -> SAssign (lhs l, re r, p)
    | SAug (o, l, r, p) -> SAug (o, lhs l, re r, p)
    | SInc (l, p) -> SInc (lhs l, p)
    | SDec (l, p) -> SDec (lhs l, p)
    | SDecl (c, f, u, n, t, init, p) -> SDecl (c, f, u, n, t, (match init with Some e -> Some (re e) | None -> None), p)
    | SSeqDecl (c, n, t, len, isl, inits, p) ->
      SSeqDecl (c, n, t, (match len with Some e -> Some (re e) | None -> None), isl,
                List.map re inits, p)
    | SExpr e -> SExpr (re e)
    | SReturn (e, p) -> SReturn ((match e with Some e -> Some (re e) | None -> None), p)
    | SIf (c, a, b, p) ->
      SIf (re c, List.map rs a,
           (match b with Some b -> Some (List.map rs b) | None -> None), p)
    | SWhile (c, b, p) -> SWhile (re c, List.map rs b, p)
    | SFor (inits, c, ups, b, p) ->
      SFor (List.map
              (function
                | FIDecl (ic, n2, t, e, fp) ->
                  FIDecl (ic, n2, t, (match e with Some e -> Some (re e) | None -> None), fp)
                | FIExpr (e, fp) -> FIExpr (re e, fp))
              inits,
            re c,
            List.map
              (function
                | FUAssign (l, r, fp) -> FUAssign (lhs l, re r, fp)
                | FUOp (o, l, r, fp) -> FUOp (o, lhs l, re r, fp)
                | FUInc (l, fp) -> FUInc (lhs l, fp)
                | FUDec (l, fp) -> FUDec (lhs l, fp))
              ups,
            List.map rs b, p)
    | SOutput (es, sep, endl, p) ->
      SOutput (List.map re es,
               (match sep with Some e -> Some (re e) | None -> None),
               (match endl with Some e -> Some (re e) | None -> None), p)
    | SInput (tgts, delim, p) ->
      (* ref 参数暂不支持作 input 目标（in_target 无法表达解引用写） *)
      List.iter
        (fun (t : in_target) ->
          match t with
          | InUse (n, ip) when in_refs n ->
            raise (TypeError (ip, "input does not support ref parameters (for now)"))
          | _ -> ())
        tgts;
      SInput (tgts, (match delim with Some e -> Some (re e) | None -> None), p)
    | SReduce (a, b, c, p) -> SReduce (re a, re b, re c, p)
    | SRemove (a, b, p) -> SRemove (re a, re b, p)
    | SUnsafe (blk, p) -> SUnsafe (List.map rs blk, p)
    | SBreak _ | SContinue _ -> s
  in
  List.map rs body

(* 字段链读取：base 为根 struct 表达式（可为指针，自动解引用），逐段展开 *)
and field_chain env p (base : texpr) (segs : string list) : texpr =
  let rec go base ty = function
    | [] -> base
    | seg :: rest ->
      (match resolve ty with
       | TPtr (TStruct s) | TStruct s ->
         let (idx, fty) = find_field env p s seg in
         go { e = EFieldK (base, idx); ety = fty; epos = p } fty rest
       | t -> terr p "type %s does not support field access %s" (pp_zty t) seg)
  in
  go base base.ety segs

(* 字段链序号列表与最终字段类型（写目标/复合赋值目标解析用） *)
and chain_fields env p (ty0 : zty) (segs : string list) : int list * zty =
  match segs with
  | [] -> ([], ty0)
  | seg :: rest ->
    (match resolve ty0 with
     | TPtr (TStruct s) | TStruct s ->
       let (idx, fty) = find_field env p s seg in
       let (r, ft2) = chain_fields env p fty rest in
       (idx :: r, ft2)
     | t -> terr p "type %s does not support field access %s" (pp_zty t) seg)

(* struct 构造：Name(位置参数..., 命名参数...) → 全字段补全
   （位置按序 + 命名按字段名 + default + 零值；数组/列表字段缺省填空 seq） *)
and check_struct_new env p name (args : call_arg list) : texpr =
  let mk k ty = { e = k; ety = ty; epos = p } in
  match Hashtbl.find_opt env.g.structs name with
  | None -> terr p "undefined type: %s" name
  | Some sd ->
    let nfields = List.length sd.sfields in
    let pos_args =
      List.filter_map
        (function
          | CPos e -> Some e
          | CCopy e -> Some e
          | CRef _ -> terr p "struct constructor does not support ref arguments"
          | CMove _ -> terr p "struct constructor does not support move arguments"
          | _ -> None)
        args in
    let named = List.filter_map (function CNamed (nm, e) -> Some (nm, e) | _ -> None) args in
    if List.length pos_args > nfields then
      terr p "struct %s has %d fields, got %d positional arguments"
        name nfields (List.length pos_args);
    let vals = Array.make nfields None in
    List.iteri (fun i a -> vals.(i) <- Some a) pos_args;
    List.iter
      (fun (nm, a) ->
        let rec go i = function
          | [] -> terr p "struct %s has no field %s" name nm
          | (fn, _, _) :: rest ->
            if fn = nm then begin
              if vals.(i) <> None then terr p "field %s initialized twice" nm;
              vals.(i) <- Some a
            end
            else go (i + 1) rest
        in
        go 0 sd.sfields)
      named;
    let tvals =
      List.mapi
        (fun i (_, ft, fdef) ->
          match vals.(i) with
          | Some a -> coerce p (check_expr env a) ft
          | None ->
            (match fdef with
             | Some de -> coerce p (check_expr env de) ft
             | None -> field_zero env p ft))
        sd.sfields
    in
    mk (EStructNewK (name, tvals)) (TStruct name)

(* 下标/整数参数统一转成 i64（小整数隐式拓宽） *)
and to_i64 (ti : texpr) : texpr =
  match resolve ti.ety with
  | TInt 64 | TUint 64 -> ti
  | TInt _ | TUint _ | TVar _ ->
    { e = ECastK (ti, TInt 64); ety = TInt 64; epos = ti.epos }
  | t -> terr ti.epos "an integer type is required, got %s" (pp_zty t)

(* 目标驱动的自动数值转换（消除跨宽度赋值/传参/返回处的 cast）：
   - 同型直接通过；含类型变量时回退到 unify（字面量求解）
   - 整数↔整数（跨宽度/符号）：目标宽度明确时自动 cast（窄化截断同 C 语义）
   - 其余（浮点↔整数、string 等）仍需显式 cast *)
and coerce p (te : texpr) (want : zty) : texpr =
  let a = resolve te.ety and b = resolve want in
  if a = b then te
  else
    match a, b with
    | TVar _, TErr t ->
      (* 目标为 T! 且值类型未定（整型/浮点面值 ety=TVar）：按元素类型
         求解后自动包装成功值（否则面值会以裸 OInt 落进 TErr 槽） *)
      unify p te.ety t;
      let te2 = coerce p te t in
      { e = EErrOkK te2; ety = want; epos = te.epos }
    | TVar _, _ | _, TVar _ -> unify p te.ety want; te
    | (TInt _ | TUint _), (TInt _ | TUint _) ->
      (* new2.md #5：宽化自动、窄化必须显式 cast。
         安全判定：同符号 dst 不窄于 src；u→i 需 dst 更宽（u8→i16 ✓）；
         i→u 目标无符号必有负值不可表示 → 一律显式 *)
      let width = function TInt w | TUint w -> w | _ -> 0 in
      let signed = function TInt _ -> true | _ -> false in
      let safe =
        if signed a = signed b then width a <= width b
        else if signed b then width b > width a
        else false
      in
      if safe then
        { e = ECastK (te, want); ety = want; epos = te.epos }
      else
        terr p "narrowing conversion from %s to %s requires an explicit cast"
          (pp_zty a) (pp_zty b)
    (* 定长数组 -> 动态长度数组参数（TList 运行期与 TArray 同构） *)
    | TArray (ea, _), TList eb when ea = eb ->
      if (match resolve ea with TStruct _ -> true | _ -> false) then
        terr p "struct is not yet supported as an array/list element";
      te
    (* T! 与 T 的互转：T! 不能当普通值用；T 自动包装为成功值 *)
    | TErr _, TErr _ -> unify p te.ety want; te
    | TErr _, _ ->
      terr p "fallible value used directly as a plain value (unwrap with ?? or propagate with ?): got %s, expected %s"
        (pp_zty a) (pp_zty b)
    | _, TErr _ when a <> TVoid ->
      { e = EErrOkK te; ety = want; epos = te.epos }
    | _ ->
      terr p "type mismatch: expected %s, got %s (numeric conversion requires an explicit cast)"
        (pp_zty b) (pp_zty a)

(* 函数式内建：length / find / trim / split / replace。
   char/string 参数传变量直接用；其他类型强制转 string *)
and check_builtin env p name (args : call_arg list) =
  let mk k ty = { e = k; ety = ty; epos = p } in
  let pos_args =
    List.filter_map
      (function
        | CPos e -> Some e
        | CCopy e -> Some e
        | CRef _ -> terr p "builtin %s does not support ref arguments" name
        | CMove _ -> terr p "builtin %s does not support move arguments" name
        | _ -> None)
      args in
  let named = List.filter_map (function CNamed (n, e) -> Some (n, e) | _ -> None) args in
  let str_of (e : expr) what =
    let t = check_expr env e in
    if resolve t.ety <> TString then
      terr p "%s expects a string for its %s parameter, got %s" name what (pp_zty t.ety);
    t
  in
  (* 第二参数：char -> 字符语义；string -> 子串语义；其他类型 -> 强转 string *)
  let char_or_str (e : expr) what =
    let t = check_expr env e in
    match resolve t.ety with
    | TChar -> `Char t
    | TString -> `Str t
    | TFrac _ | TArray _ | TList _ | TVoid ->
      terr p "%s does not accept type %s for its %s parameter" name what (pp_zty t.ety)
    | _ -> `Str (to_string_of t)
  in
  match name, pos_args, named with
  | "length", [ x ], [] ->
    let tx = check_expr env x in
    (match resolve tx.ety with
     | TString -> mk (ECallK ("strlen", [ tx ], [])) (TInt 64)
     | TArray _ | TList _ -> mk (ESeqLenK tx) (TInt 64)
     | t -> terr p "length expects string/array/list, got %s" (pp_zty t))
  | "find", [ s; c ], [] ->
    (* find(s, 'l')：找第 1 次出现；找不到返回 NOT_FOUND 错误值（T!） *)
    let ts = str_of s "argument 1" and tc = char_of_expr env c "argument 2" in
    let one = { e = EIntK 1L; ety = TInt 64; epos = p } in
    { e = EFindK (ts, tc, one); ety = TErr (TInt 64); epos = p }
  | "find", [ s; c ], [ ("count", k) ] ->
    (* find(s, 'l', count=k)：找第 k 次出现（k 从 1 起）；找不到 = NOT_FOUND（T!） *)
    let ts = str_of s "argument 1" and tc = char_of_expr env c "argument 2" in
    let tk = to_i64 (check_expr env k) in
    (match const_eval env tk with
     | Some v when Int64.compare v 1L < 0 ->
       terr p "find's count must be > 0, got %Ld" v
     | _ -> ());
    { e = EFindK (ts, tc, tk); ety = TErr (TInt 64); epos = p }
  | "trim", [ s; x ], [] ->
    let ts = str_of s "argument 1" in
    (match char_or_str x "argument 2" with
     | `Char tc -> { e = ECallK ("zfy_str_trim", [ ts; tc ], []); ety = TString; epos = p }
     | `Str tx -> { e = ECallK ("zfy_str_trim_str", [ ts; tx ], []); ety = TString; epos = p })
  | "split", [ s; x ], [] ->
    (* split(s, x)：按分隔符切分，返回 string 列表（一等值，可 length/下标/遍历） *)
    let ts = str_of s "argument 1" in
    (match char_or_str x "argument 2" with
     | `Char tc -> { e = ESplitK (ts, tc); ety = TList TString; epos = p }
     | `Str tx -> { e = ESplitK (ts, tx); ety = TList TString; epos = p })
  | "replace", [ s; a; b; rep ], [] ->
    (* replace(s, a, b, rep)：把下标 a..b（两端含）替换为 rep（任意 string 表达式） *)
    let ts = str_of s "argument 1" in
    let ta = to_i64 (check_expr env a) and tb' = to_i64 (check_expr env b) in
    let trep =
      match char_or_str rep "argument 4" with
      | `Char tc -> to_string_of tc
      | `Str tx -> tx
    in
    { e = ECallK ("zfy_str_replace", [ ts; ta; tb'; trep ], []); ety = TString; epos = p }
  | "replace", [ s; a; rep ], [] ->
    (* replace(s, a, rep)：从下标 a 起替换到串尾 *)
    let ts = str_of s "argument 1" in
    let ta = to_i64 (check_expr env a) in
    let trep =
      match char_or_str rep "argument 3" with
      | `Char tc -> to_string_of tc
      | `Str tx -> tx
    in
    { e = ECallK ("zfy_str_replace_from", [ ts; ta; trep ], []); ety = TString; epos = p }
  | "prec", [ v; n ], [] ->
    (* prec(v, n)：输出长度控制（总字符数），返回 string。
       v：string 截断/补空格；其他可打印类型先按输出格式转 string。
       n：整数/bool/char（数字字符转数值）/浮点（向零截断）。 *)
    let tv = check_expr env v in
    (match resolve tv.ety with
     | TArray _ | TList _ | TVoid ->
       terr p "prec does not support type %s" (pp_zty tv.ety)
     | _ -> ());
    let tn = check_expr env n in
    (match resolve tn.ety with
     | TInt _ | TUint _ | TBool | TChar | TFloat _ | TVar _ -> ()
     | t -> terr p "prec's length parameter must be integer/char/float, got %s" (pp_zty t));
    mk (ECallK ("zfy.prec", [ tv; tn ], [])) TString
  | _ ->
    terr p "malformed argument list for builtin %s (positional arguments must precede named ones)" name

(* char 参数（find 用） *)
and char_of_expr env (e : expr) what =
  let t = check_expr env e in
  if resolve t.ety <> TChar then
    terr t.epos "a char is required (%s), got %s" what (pp_zty t.ety);
  t

(* ---------- 语句检查 ---------- *)

(* input 目标支持的类型：string / 整数 / 浮点 / bool / char（可带 T! 包装：
   T! 目标按错误值写入，失败置 err 而非 fail-fast） *)
let rec check_input_ty p = function
  | TString | TInt _ | TUint _ | TFloat _ | TBool | TChar -> ()
  | TErr t -> check_input_ty p t
  | t -> terr p "input target must be string/integer/float/bool/char, got %s" (pp_zty t)

(* 解包块形式识别（parser 把 a ?? 缩进块解析为 EUnwrap (a, EBlock ...)） *)
let is_unwrap_block (e : expr) =
  match e with EUnwrap (_, EBlock _, _) -> true | _ -> false

let rec check_decl env p isconst is_frac is_unred name ty init =
  let base = conv_ty env.g p ty in
  let want =
    if is_frac then begin
      if not (frac_elem_ok base) then
        terr p "frac does not support element type %s (supported: i8..i128 / u8..u128 / f32 / f64 / f128)"
          (pp_zty base);
      TFrac base
    end
    else base
  in
  let tinit =
    match init with
    | None ->
      (* 裸声明 struct：等同 Name() 全默认构造，字段默认值生效（change.md 1.2） *)
      (match resolve want with
       | TStruct s -> check_struct_new env p s []
       | _ -> zero_of env p want)
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
        terr p "bool can only be initialized with true/false, 0/1, or a boolean expression";
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
       | TFrac _ -> terr p "mismatched frac element types"
       | TInt _ | TUint _ | TFloat _ | TVar _ -> mk_frac_from t (match resolve want with TFrac e -> e | _ -> assert false) p
       | _ -> terr p "cannot initialize %s as frac" (pp_zty t.ety))
    | _, _ -> check_expr env init)
  in
  let tinit = coerce p tinit want in
  declare env name { lconst = isconst; lty = want; lslot = ""; lunred = is_unred;
                     lconstp = (match ty with TPtrC _ -> true | _ -> false) };
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
      terr p "cannot assign to constant %s (declared const)" name;
    l.lslot
  | None -> terr p "undefined variable: %s" name

(* 9c：解引用写目标若为指向 const 的指针变量（T const*）则报错 *)
and check_constp env (pe : expr) p =
  match pe with
  | EVar (name, _) ->
    (match lookup_var env name with
     | Some l when l.lconstp ->
       terr p "cannot write through pointer-to-const %s (declared T const*)" name
     | _ -> ())
  | _ -> ()

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
       if Hashtbl.mem env.moved l.lslot then
         terr ap "array %s has been moved and cannot be written" arr;
       (match resolve l.lty with
        | TArray (e, _) | TList e as seqty ->
          if l.lconst then terr ap "cannot modify elements of constant %s" arr;
          let ti = to_i64 (check_expr env idx) in
          let trhs = check_expr env rhs in
          let grow = (match seqty with TList _ -> true | _ -> false) in
          let trhs = coerce ip trhs e in
          SAugIndexK (l.lslot, e, ti, bop, trhs, grow)
        | TPtr t ->
          (* 指针下标复合赋值（自动解引用，无越界检查）：p[i] op= v，
             地址 p+i 只求值一次；强制 unsafe 块（new2.md #8） *)
          if l.lconstp then
            terr ap "cannot write through pointer-to-const %s (declared T const*)" arr;
          if not env.in_unsafe then
            terr ap "pointer subscript p[i] is only allowed inside an unsafe block";
          let ti = to_i64 (check_expr env idx) in
          let tp = { e = EVarK l.lslot; ety = l.lty; epos = ap } in
          let addr = { e = EBinK (BAdd, tp, ti); ety = l.lty; epos = ip } in
          let trhs = check_expr env rhs in
          let trhs = coerce ip trhs t in
          SAugDerefK (addr, bop, trhs)
        | t -> terr ap "augmented assignment target does not support indexing: %s" (pp_zty t))
     | None -> terr ap "undefined variable: %s" arr)
  | ESlice (EVar (arr, ap), a, b, step, sp) ->
     (* a[x,y:st] op= v：原地作用于原数组的区间元素（string/frac/f16/f128 不支持） *)
     (match lookup_var env arr with
      | Some l ->
        if Hashtbl.mem env.moved l.lslot then
          terr ap "array %s has been moved and cannot be written" arr;
        (match resolve l.lty with
        | TArray (e, _) | TList e ->
          if l.lconst then terr ap "cannot modify elements of constant %s" arr;
          (match resolve e with
           | TString -> terr sp "string slices do not support augmented assignment"
           | TFrac _ -> terr sp "frac slices do not support augmented assignment"
           | TFloat 16 | TFloat 128 -> terr sp "f16/f128 slices do not support augmented assignment"
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
        | t -> terr ap "augmented assignment target does not support slicing: %s" (pp_zty t))
     | None -> terr ap "undefined variable: %s" arr)
  | EVar (name, p') ->
    (match lookup_var env name with
     | Some l ->
       if l.lconst then
         terr p' "cannot assign to constant %s (declared const)" name;
       Hashtbl.remove env.moved l.lslot;  (* 复合赋值/自增自减：move 状态解除 *)
       (match resolve l.lty with
        | TPtr _ ->
          terr p' "pointers do not support augmented assignment/inc/dec (arithmetic only as p = p + n inside unsafe)"
        | _ -> ());
       let slot = l.lslot in
       (match resolve l.lty, bop with
        | TString, BAdd ->
          (* s += v：string 拼接后重新赋值（结果为独立堆串） *)
          let tself = { e = EVarK slot; ety = TString; epos = p' } in
          let trhs = check_expr env rhs in
          if resolve trhs.ety <> TString then
            terr p' "string concatenation requires both sides to be string, got %s" (pp_zty trhs.ety);
          let cat =
            { e = ECallK ("zfy_str_concat", [ tself; trhs ], []);
              ety = TString; epos = p' }
          in
          SAssignK (tself, cat, false, false)
        | _ ->
          let lty = l.lty in
          let trhs = check_expr env rhs in
          let needs_norm =
            (match resolve lty with TFrac _ -> not l.lunred | _ -> false) in
          let trhs = coerce p' trhs lty in
          SAugVarK (slot, lty, bop, trhs, needs_norm))
     | None ->
       (* 整体 lookup 失败且名字含 '.'：struct 字段链复合赋值
          （p.x += v / p.hp++ 等；const 根在此报错） *)
       (match split_field_path name with
        | Some (first, segs) ->
          (match lookup_var env first with
           | Some l ->
             (match resolve l.lty with
              | TStruct _ | TPtr (TStruct _) ->
                if l.lconst then
                  terr p' "cannot assign to field of constant %s (const is deeply immutable)" first;
                let (idxs, fty) = chain_fields env p' l.lty segs in
                (match resolve fty with
                 | TInt _ | TUint _ | TFloat _ ->
                   let trhs = check_expr env rhs in
                   let trhs = coerce p' trhs fty in
                   SAugFieldK (l.lslot, idxs, l.lty, bop, trhs)
                 | t ->
                   terr p' "struct field augmented assignment supports only numeric scalar fields, got %s"
                     (pp_zty t))
              | t -> terr p' "type %s does not support field assignment %s" (pp_zty t) name)
           | None -> terr p' "undefined variable: %s" name)
        | None -> terr p' "undefined variable: %s" name))
  | EDeref (pe, dp) ->
    (* p* op= v / p*++ / p*--：解引用复合赋值（仅数值标量/指针目标） *)
    check_constp env pe dp;
    let tp = check_expr env pe in
    (match resolve tp.ety with
     | TPtr t ->
       (match resolve t with
        | TInt _ | TUint _ | TFloat _ | TPtr _ ->
          let trhs = check_expr env rhs in
          let trhs = coerce dp trhs t in
          SAugDerefK (tp, bop, trhs)
        | t' ->
          terr dp "dereferenced augmented assignment supports only numeric/pointer types, got %s" (pp_zty t'))
     | t -> terr dp "augmented/inc/dec target must be a pointer dereference, got %s" (pp_zty t))
  | _ -> terr p "augmented/inc/dec target must be a variable or array/list element"

(* 解包块公共检查：a（须为 TErr elem）+ 缩进块；块作用域注入 err（Err struct）。
   块末值表达式改写为对目标槽的赋值（Discard 形式保留原样）。
   target：`Decl (isconst, 名, 类型) / `Assign 槽主名 / `Discard *)
and check_unwrap env p (a : expr) (blk : block) target =
  let ta = check_expr env a in
  let elem =
    match resolve ta.ety with
    | TErr t -> t
    | _ -> terr p "left side of ?? must be a fallible value (T!), got %s" (pp_zty ta.ety)
  in
  let slot, tgt_ty =
    match target with
    | `Decl (isconst, name, ty) ->
      let want = conv_ty env.g p ty in
      (match resolve want with
       | TErr _ ->
         terr p "??-block declaration type must be the element type T (without '!')"
       | _ -> ());
      unify p elem want;
      declare env name { lconst = isconst; lty = want; lslot = ""; lunred = false; lconstp = false };
      let s = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
      (s, want)
    | `Assign name ->
      (match lookup_var env name with
       | Some l ->
         if l.lconst then terr p "cannot assign to constant %s (declared const)" name;
         unify p elem l.lty;
         (l.lslot, l.lty)
       | None -> terr p "undefined variable: %s" name)
    | `Discard -> ("", elem)
  in
  push_scope env;
  declare env "err" { lconst = true; lty = TStruct "Err"; lslot = ""; lunred = false; lconstp = false };
  let errslot = (match lookup_var env "err" with Some l -> l.lslot | None -> assert false) in
  let tblk = check_block env blk in
  pop_scope env;
  let tblk =
    match target, List.rev tblk with
    | `Discard, _ -> tblk
    | _, { s = SExprK v; spos = vp } :: rest_rev ->
      let v = coerce vp v tgt_ty in
      List.rev
        ({ s = SAssignK ({ e = EVarK slot; ety = v.ety; epos = vp }, v, false, false);
           spos = vp } :: rest_rev)
    | _, _ -> tblk   (* 块以 return/break/continue/panic 等结束：目标不写 *)
  in
  let is_decl = (match target with `Decl _ -> true | _ -> false) in
  SUnwrapBlockK (is_decl, slot, elem, ta, errslot, tblk)

and check_unwrap_decl env p isconst name ty init =
  match init with
  | EUnwrap (a, EBlock (blk, _), _) -> check_unwrap env p a blk (`Decl (isconst, name, ty))
  | _ -> assert false

(* 语句块检查。语句级错误恢复：单条语句检查失败时记录错误并继续下一条
   （多错误收集）；恢复作用域栈深度（异常会跳过配对的 pop_scope）。
   moved 表/fnvars 的残留可能引起级联报错，可接受（不掩盖首个错误） *)
and check_block env (stmts : stmt list) : tblock =
  let recover s =
    let depth = List.length env.scopes in
    let r =
      try Some (check_stmt env s)
      with TypeError (p, m) ->
        collected := (p, m) :: !collected;
        None
    in
    while List.length env.scopes > depth do pop_scope env done;
    r
  in
  List.filter_map recover stmts

(* 数组/列表声明检查（不含 split 初值特判）：返回语句种类 *)
and check_seq_decl env p isconst name e len is_list inits =
  (match resolve e with
   | TFrac _ -> terr p "frac arrays/lists are not yet supported"
   | TStruct _ -> terr p "struct is not yet supported as an array/list element"
   | TErr _ -> terr p "T! cannot be an array/list element (error values are aggregates and cannot be loaded by index)"
   | _ -> ());
  let vlen =
    match len, is_list with
    | None, true -> 0L
    | Some le, false ->
      let tl = check_expr env le in
      (match resolve tl.ety with
       | TInt _ | TUint _ | TVar _ -> ()
       | t -> terr p "array length must be an integer, got %s" (pp_zty t));
      (match const_eval env tl with
       | Some n when Int64.compare n 0L >= 0 -> n
       | _ ->
         terr p "array length must be a compile-time constant (a literal or const integer variable)")
    | Some _, true -> terr p "lists take no length"
    | None, false -> terr p "arrays require a length"
  in
  if (not is_list) && List.length inits > Int64.to_int vlen then
    terr p "%d initial values exceed array length %Ld" (List.length inits) vlen;
  (match inits, is_list with
  (* 列表整体初值：T list b = 源（源为同元素类型列表/数组 → 深拷贝） *)
   | [ ie ], true ->
     let ti = check_expr env ie in
     let copy_list () =
       declare env name
         { lconst = isconst; lty = TList e; lslot = ""; lunred = false; lconstp = false };
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
          { lconst = isconst; lty = TList e; lslot = ""; lunred = false; lconstp = false };
        let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
        SSeqDeclK (isconst, slot, e, 0L, true, tinits))
  (* 数组整体初值：T array b[N] = 源（源为同元素类型数组/列表 → 深拷贝） *)
   | [ ie ], false ->
     let ti = check_expr env ie in
     (match resolve ti.ety with
      | TArray (e2, n2) when resolve e2 = resolve e && n2 = Int64.to_int vlen ->
        declare env name
          { lconst = isconst; lty = TArray (e, Int64.to_int vlen);
            lslot = ""; lunred = false; lconstp = false };
        let slot =
          (match lookup_var env name with
           | Some l -> l.lslot
           | None -> assert false)
        in
        SSeqCopyK (isconst, slot, e, vlen, ti, false)
      | TList e2 when resolve e2 = resolve e ->
        declare env name
          { lconst = isconst; lty = TList e;
            lslot = ""; lunred = false; lconstp = false };
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
            lslot = ""; lunred = false; lconstp = false };
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
         lslot = ""; lunred = false; lconstp = false };
     let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
     SSeqDeclK (isconst, slot, e, vlen, is_list, tinits))

and check_stmt env (st : stmt) : tstmt =
  let mk k = { s = k; spos = pos_of_stmt st } in
  match st with
  | SDecl (isconst, is_frac, is_unred, name, ty, init, p) when init <> None && is_unwrap_block (Option.get init) ->
    if is_frac || is_unred then
      terr p "frac/unred does not support ??-block initialization";
    mk (check_unwrap_decl env p isconst name ty (Option.get init))
  | SDecl (isconst, is_frac, is_unred, name, ty, init, p) ->
    mk (check_decl env p isconst is_frac is_unred name ty init)
  | SSeqDecl (isconst, name, ety, len, is_list, inits, p) ->
    mk (check_seq_decl env p isconst name (conv_ty env.g p ety) len is_list inits)
  | SAssign (lhs, rhs, p) when is_unwrap_block rhs ->
    (* x = a ?? 缩进块 *)
    (match lhs, rhs with
     | EVar (name, _), EUnwrap (a, EBlock (blk, _), _) ->
       mk (check_unwrap env p a blk (`Assign name))
     | _ -> terr p "??-block assignment target must be a variable (for now)")
  | SAssign (lhs, rhs, p) ->
    (match lhs, rhs with
     | EIndex (EVar (arr, ap), idx, ip), _ ->
       (* arr[i] = v：元素写入（下标只求值一次） *)
       (match lookup_var env arr with
        | Some l ->
          if Hashtbl.mem env.moved l.lslot then
            terr ap "array %s has been moved and cannot be written" arr;
          (match resolve l.lty with
           | TArray (e, _) | TList e as seqty ->
             if l.lconst then
               terr ap "cannot modify elements of constant %s" arr;
             let ti = to_i64 (check_expr env idx) in
             let trhs = check_expr env rhs in
             let grow = (match seqty with TList _ -> true | _ -> false) in
             let trhs = coerce ip trhs e in
             mk (SSeqSetK (l.lslot, e, ti, trhs, grow))
           | TString ->
             terr ip "strings do not support index assignment (use replace for ranges)"
           | TPtr t ->
             (* 指针下标写入（自动解引用，无越界检查）：p[i] = v 等同于
                先按元素步进地址（p+i）再解引用写入；强制 unsafe（new2.md #8） *)
             if l.lconstp then
               terr ap "cannot write through pointer-to-const %s (declared T const*)" arr;
             if not env.in_unsafe then
               terr ip "pointer subscript p[i] is only allowed inside an unsafe block";
             (match resolve t with
              | TInt _ | TUint _ | TFloat _ | TBool | TChar | TPtr _ ->
                let ti = to_i64 (check_expr env idx) in
                let tp = { e = EVarK l.lslot; ety = l.lty; epos = ap } in
                let addr = { e = EBinK (BAdd, tp, ti); ety = l.lty; epos = ip } in
                let trhs = check_expr env rhs in
                let trhs = coerce ip trhs t in
                mk (SDerefSetK (addr, trhs))
              | t' ->
                terr ap "dereference assignment supports only scalar/pointer types (for now), got %s" (pp_zty t'))
           | t -> terr ap "type %s does not support index assignment" (pp_zty t))
        | None ->
          (* 第 7 条顺带修：字段链下数组/列表元素写入 b.data[i] = v *)
          (match split_field_path arr with
           | Some (first, segs) ->
             (match lookup_var env first with
              | Some l ->
                (match resolve l.lty with
                 | TStruct _ | TPtr (TStruct _) ->
                   if l.lconst then
                     terr ap "cannot modify elements of constant %s (const is deeply immutable)" first;
                   if Hashtbl.mem env.moved l.lslot then
                     terr ap "array %s has been moved and cannot be written" arr;
                   let (fidxs, fty) = chain_fields env ap l.lty segs in
                   (match resolve fty with
                    | TArray (e, _) | TList e as seqty ->
                      let grow = (match seqty with TList _ -> true | _ -> false) in
                      let ti = to_i64 (check_expr env idx) in
                      let trhs = check_expr env rhs in
                      let trhs = coerce ip trhs e in
                      mk (SFieldSeqSetK (l.lslot, fidxs, l.lty, e, ti, trhs, grow))
                    | t' ->
                      terr ap "type %s does not support index assignment" (pp_zty t'))
                 | t -> terr ap "type %s does not support index assignment %s" (pp_zty t) arr)
              | None -> terr ap "undefined variable: %s" first)
           | None -> terr ap "undefined variable: %s" arr))
     | EIndex (_, _, ip), _ ->
       terr ip "index-assignment target must be an array/list variable, e.g. n[3] = value"
     | EDeref (pe, dp), _ ->
       (* p* = v：解引用写入（仅标量/指针目标；聚合类型暂不支持） *)
       check_constp env pe dp;
       let tp = check_expr env pe in
       (match resolve tp.ety with
        | TPtr t ->
          (match resolve t with
           | TInt _ | TUint _ | TFloat _ | TBool | TChar | TPtr _ ->
             let trhs = check_expr env rhs in
             let trhs = coerce dp trhs t in
             mk (SDerefSetK (tp, trhs))
           | t' ->
             terr dp "dereference assignment supports only scalar/pointer types (for now), got %s" (pp_zty t'))
        | t -> terr dp "assignment target must be a pointer dereference, got %s" (pp_zty t))
     | EVar (name, p'), rhs' ->
       (match lookup_var env name with
        | Some l ->
          if l.lconst then
            terr p' "cannot assign to constant %s (declared const)" name;
          Hashtbl.remove env.moved l.lslot;  (* 重新赋值：move 状态解除 *)
          let slot = l.lslot in
          let lty = l.lty in
          (match rhs' with
           | EVar (n2, p2) when n2 <> name && auto_moveable env n2 p2 ->
             (* 自动 move 赋值（new2.md #1）：源变量此后不再出现——
                所有权转移免克隆（deep copy → move），源槽置空防双释放 *)
             let trhs0 = check_expr env rhs' in
             ignore (coerce p' trhs0 lty);
             let src_slot =
               (match lookup_var env n2 with
                | Some s -> s.lslot | None -> assert false) in
             Hashtbl.replace env.moved src_slot ();
             mk (SAssignK ({ e = EVarK slot; ety = lty; epos = p' },
                           { e = EVarK src_slot; ety = lty; epos = p2 }, false, true))
           | _ ->
             let trhs = check_expr env rhs' in
             let needs_norm =
               (match resolve lty with TFrac _ -> not l.lunred | _ -> false) in
             (match resolve trhs.ety, resolve lty with
              | TList e2, TArray (e, _) when resolve e2 = resolve e ->
                (* 数组/列表切片（TList 元素类型）赋给数组变量：运行时同为 seq，深拷贝 *)
                mk (SAssignK ({ e = EVarK slot; ety = trhs.ety; epos = p' }, trhs, false, false))
              | _, _ ->
                let trhs = coerce p' trhs lty in
                mk (SAssignK ({ e = EVarK slot; ety = trhs.ety; epos = p' }, trhs, needs_norm, false))))
        | None ->
          (* 名字含 '.'：struct 字段链写入（p.x = v / p.pos.x = v / r.x = v 指针自动解引用） *)
          (match split_field_path name with
           | Some (first, segs) ->
             (match lookup_var env first with
              | Some l ->
                (match resolve l.lty with
                 | TStruct _ | TPtr (TStruct _) ->
                   if l.lconst then
                     terr p' "cannot assign to field of constant %s (const is deeply immutable)" first;
                   let (idxs, fty) = chain_fields env p' l.lty segs in
                   let trhs = check_expr env rhs' in
                   let trhs = coerce p' trhs fty in
                   mk (SFieldSetK (l.lslot, idxs, l.lty, trhs))
                 | t -> terr p' "type %s does not support field assignment %s" (pp_zty t) name)
              | None -> terr p' "undefined variable: %s" name)
           | None -> terr p' "undefined variable: %s" name))
     | _ -> terr p "unsupported assignment target")
  | SAug (op, lhs, rhs, p) ->
    mk (check_aug env p lhs op rhs)
  | SInc (e, p) ->
    let one = Ast.EInt (1L, p) in
    mk (check_aug env p e Ast.Add one)
  | SDec (e, p) ->
    let one = Ast.EInt (1L, p) in
    mk (check_aug env p e Ast.Sub one)
  | SExpr e when is_unwrap_block e ->
    (* 裸解包块：a ?? 缩进块（块内通常 return/break/panic） *)
    (match e with
     | EUnwrap (a, EBlock (blk, _), wp) -> mk (check_unwrap env wp a blk `Discard)
     | _ -> assert false)
  | SExpr e ->
    (match e with
     | ECast (EVar (name, np), _, _) ->
       (* cast(a, T) 单独成句：把 a 重绑定为 T 类型新槽（值转换，原槽保留） *)
       (match lookup_var env name with
        | None -> terr np "undefined variable: %s" name
        | Some _ ->
          let te = check_expr env e in
          declare env name { lconst = false; lty = te.ety; lslot = ""; lunred = false; lconstp = false };
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
        | t -> terr p "output does not support argument type: %s" (pp_zty t))
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
           terr p "input's delim must be char or string, got %s" (pp_zty td.ety)
         | _ -> ());
        Some (to_string_of td)
    in
    let ttargets =
      List.map
        (function
          | InNew (name, ty, p') ->
            let t = conv_ty env.g p' ty in
            check_input_ty p' t;
            declare env name { lconst = false; lty = t; lslot = ""; lunred = false; lconstp = false };
            let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
            { tname = slot; tnew = true; tty = t }
          | InUse (name, p') ->
            (match lookup_var env name with
             | Some l ->
               if l.lconst then
                 terr p' "cannot input into constant %s" name;
               Hashtbl.remove env.moved l.lslot;  (* 写入：move 状态解除 *)
               check_input_ty p' l.lty;
               { tname = l.lslot; tnew = false; tty = l.lty }
             | None -> terr p' "undefined variable: %s" name))
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
               terr p' "cannot reduce constant %s" name;
             let tc = check_expr env cnt and ts = check_expr env start in
             unify p tc.ety (TInt 64);
             unify p ts.ety (TInt 64);
             let tx = { e = EVarK l.lslot; ety = TFrac e; epos = p' } in
             mk (SReduceK (tx, tc, ts))
           | t -> terr p' "reduce requires a frac-typed variable, got %s" (pp_zty t))
        | None -> terr p' "undefined variable: %s" name)
     | _ -> terr p "reduce's first argument must be a frac-typed local variable")
  | SRemove (lhs, idx, p) ->
    (* remove(数组/列表名, 下标)：数组=槽位填零值（长度不变）；列表=删除并左移（长度-1） *)
    (match lhs with
     | EVar (name, p') ->
       (match lookup_var env name with
        | Some l ->
          if Hashtbl.mem env.moved l.lslot then
            terr p' "array %s has been moved and cannot be removed from" name;
          (match resolve l.lty with
           | TArray (e, _) | TList e as seqty ->
             if l.lconst then
               terr p' "cannot remove from constant %s" name;
             let ti = to_i64 (check_expr env idx) in
             let isl = (match seqty with TList _ -> true | _ -> false) in
             mk (SRemoveK (l.lslot, e, ti, isl))
           | t -> terr p' "remove only works on arrays/lists, got %s" (pp_zty t))
        | None -> terr p' "undefined variable: %s" name)
     | _ -> terr p "remove's first argument must be an array/list variable")
  | SBreak p ->
    ignore p;
    mk SBreakK
  | SContinue p ->
    ignore p;
    mk SContinueK
  | SUnsafe (b, p) ->
    (* unsafe 块：块级作用域；块内放开指针算术门禁，降码时透明展开 *)
    ignore p;
    push_scope env;
    let saved = env.in_unsafe in
    env.in_unsafe <- true;
    let tb = check_block env b in
    env.in_unsafe <- saved;
    pop_scope env;
    mk (SUnsafeK tb)

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
  | SUnsafe (_, p)
  | SBreak p
  | SContinue p -> p
  | SExpr e -> pos_of_expr e

(* ---------- 收尾：未求解 TVar 默认值 ---------- *)

let rec subst_ty (t : zty) : zty =
  match resolve t with
  | TArray (t', n) -> TArray (subst_ty t', n)
  | TList t' -> TList (subst_ty t')
  | TPtr t' -> TPtr (subst_ty t')
  | TErr t' -> TErr (subst_ty t')
  | TFunSig (ptys, ret) -> TFunSig (List.map subst_ty ptys, subst_ty ret)
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
        terr pos "frac parameter does not support element type %s" (pp_zty base);
      TFrac base
    end else base
  | PList -> TList base
  | PArray len ->
    (match len with
     | EInt (n, _) when n >= 0L -> TArray (base, Int64.to_int n)
     | EVar (nm, npp) ->
       if List.mem nm prev_names then TList base
       else terr npp "array parameter length must be a literal or a previously declared parameter: %s" nm
     | _ ->
       terr pos "array parameter length must be a literal or a previously declared parameter")

let check_program (prog : program) : hir =
  collected := [];                             (* 多错误收集：每次检查重置 *)
  let g : genv =
    { fns = Hashtbl.create 16; structs = Hashtbl.create 16;
      aliases = Hashtbl.create 16 } in
  (* 内建 Err struct（解包块内 err 变量的类型）：code + msg。
     ErrCode 为虚拟常量命名空间（编译期查表），无对应 struct *)
  Hashtbl.replace g.structs "Err"
    { spacked = false;
      sfields = [ ("code", TInt 32, None); ("msg", TString, None) ] };
  (* 收集函数名（struct 名与函数名冲突检查用） *)
  let fn_names = Hashtbl.create 16 in
  List.iter
    (function IFn { name; pos; _ } -> Hashtbl.replace fn_names name pos | _ -> ())
    prog;
  (* 第一遍 A0：预登记所有 struct 名（空字段占位），使指针形态的字段
     （Node* next / B* b）可自引用与前向引用——conv_ty 只需名字存在；
     非指针自引用仍由下方 E3098 检查拦截（无限大小） *)
  let seen_structs : (string, unit) Hashtbl.t = Hashtbl.create 8 in
  List.iter
    (function
      | IStruct { name; pos; _ } ->
        if Hashtbl.mem seen_structs name then
          terr pos "duplicate struct definition: %s" name
        else begin
          Hashtbl.add seen_structs name ();
          Hashtbl.replace g.structs name { spacked = false; sfields = [] }
        end
      | _ -> ())
    prog;
  (* 第一遍 A：按声明序登记 struct（字段类型只展开已声明 struct 的字段；
     函数签名引用 struct 同样要求已声明） *)
  let struct_pos : (string, pos) Hashtbl.t = Hashtbl.create 8 in
  List.iter
    (function
      | IStruct { name; packed; fields; pos } ->
        if List.mem name builtin_names then
          terr pos "struct name %s conflicts with a builtin, rename it" name;
        if Hashtbl.mem fn_names name then
          terr pos "%s is already a function and cannot also be a struct name" name;
        let sfields =
          List.map
            (fun (sf : Ast.sfield) ->
              let base = conv_ty g sf.fpos sf.fty in
              let ft =
                match sf.fseq with
                | Ast.PScalar -> base
                | Ast.PList -> TList base
                | Ast.PArray len ->
                  (match len with
                   | EInt (n, _) when n >= 0L -> TArray (base, Int64.to_int n)
                   | _ ->
                     terr sf.fpos "struct field array length must be a compile-time literal")
              in
              (match resolve ft with
               | TStruct s2 when s2 = name ->
                 terr sf.fpos "struct %s field type cannot be itself (infinite size)" name
               | TErr _ ->
                 terr sf.fpos "T! cannot be a struct field (error values are aggregates and cannot be loaded as a field)"
               | _ -> ());
              (sf.fname, ft, sf.fdefault))
            fields
        in
        (* 字段重名检查 *)
        let seen = ref [] in
        List.iter
          (fun (fn2, _, _) ->
            if List.mem fn2 !seen then
              terr pos "struct %s has duplicate field %s" name fn2;
            seen := fn2 :: !seen)
          sfields;
        Hashtbl.replace g.structs name { spacked = packed; sfields };
        Hashtbl.replace struct_pos name pos
      | _ -> ())
    prog;
  (* struct 循环嵌套检测（A 含 B、B 含 A → 递归展开无限大小） *)
  let rec deps_of ty acc =
    match ty with
    | TStruct s -> s :: acc
    | TArray (t, _) | TList t | TFrac t -> deps_of t acc
    | _ -> acc
  in
  let visiting : (string, unit) Hashtbl.t = Hashtbl.create 8 in
  let finished : (string, unit) Hashtbl.t = Hashtbl.create 8 in
  let rec visit name =
    if Hashtbl.mem finished name then ()
    else if Hashtbl.mem visiting name then
      terr (Hashtbl.find struct_pos name)
        "struct %s has circular nesting (infinite size)" name
    else begin
      Hashtbl.replace visiting name ();
      let sd = Hashtbl.find g.structs name in
      List.iter
        (fun (_, ft, _) -> List.iter visit (deps_of ft []))
        sd.sfields;
      Hashtbl.remove visiting name;
      Hashtbl.replace finished name ()
    end
  in
  Hashtbl.iter (fun name _ -> visit name) g.structs;
  (* type 别名收集：按声明序展开（可引用已声明的 struct/别名；函数类型仅此处） *)
  List.iter
    (function
      | ITypeAlias { name; ty; pos } ->
        if prim_type name <> None || Hashtbl.mem g.aliases name
           || Hashtbl.mem g.structs name || Hashtbl.mem fn_names name
           || List.mem name builtin_names then
          terr pos "type alias %s conflicts with an existing type/function" name;
        Hashtbl.replace g.aliases name (conv_ty g pos ty)
      | _ -> ())
    prog;
  (* 第一遍 B：收集函数签名（参数含数组/列表/frac） *)
  List.iter
    (function
      | IFn { name; params; ret; rfrac; pos; _ } ->
        if List.mem name builtin_names then
          terr pos "function name %s conflicts with a builtin, rename it" name;
        if Hashtbl.mem g.fns name then
          terr pos "duplicate function definition: %s" name;
        let prev = ref [] in
        let ptys =
          List.map
            (fun (pd : param) ->
              let t = conv_param g pos !prev pd in
              prev := pd.pname :: !prev;
              if pd.pref then begin
                (* ref 参数（new2.md #1）：签名侧降为指针（调用方传地址），
                   仅标量/string；函数体内由 deref_refs 自动解引用 *)
                if pd.pseq <> Ast.PScalar then
                  terr pd.ppos "ref parameters support scalar/string types only";
                (match resolve t with
                 | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString -> ()
                 | _ ->
                   terr pd.ppos "ref parameters support scalar/string types only (got %s)"
                     (pp_zty t));
                TPtr t
              end else t)
            params
        in
        let prefs = List.map (fun (pd : param) -> pd.pref) params in
        let rty =
          match ret with
          | None -> TVoid
          | Some t ->
            let base = conv_ty g pos t in
            if rfrac then begin
              if not (frac_elem_ok base) then
                terr pos "frac return type does not support element type %s" (pp_zty base);
              TFrac base
            end else base
        in
        Hashtbl.replace g.fns name { params = ptys; prefs; ret = rty }
      | IExtern { funcs; pos = _ } ->
        (* extern "C"：登记签名（调用直通 LLVM 符号，与 C 链接一致） *)
        List.iter
          (fun (f : Ast.extern_fn) ->
            if Hashtbl.mem g.fns f.ename then
              terr f.epos "duplicate function definition: %s (extern conflicts with an existing function)" f.ename;
            if List.mem f.ename builtin_names then
              terr f.epos "extern function name %s conflicts with a builtin" f.ename;
            let ptys =
              List.map
                (fun (pd : param) ->
                  if pd.pseq <> Ast.PScalar then
                    terr pd.ppos "extern parameters do not support arrays/lists";
                  if pd.pref then
                    terr pd.ppos "extern parameters do not support ref";
                  let t = conv_ty g pd.ppos pd.pty in
                  (match t with
                   | TErr _ -> terr pd.ppos "extern parameters do not support T!"
                   | _ -> ());
                  t)
                f.eparams
            in
            let rty = conv_ty g f.epos f.eret in
            (match rty with
             | TErr _ -> terr f.epos "extern functions do not support a T! return type (the error model is for zfy functions only)"
             | _ -> ());
            Hashtbl.replace g.fns f.ename
              { params = ptys; prefs = List.map (fun _ -> false) ptys; ret = rty };
            (* 9d：登记 extern 名单——llvmgen 对 i128 参数/返回值做 ABI 适配 *)
            Hashtbl.replace extern_fns f.ename ())
          funcs
      | IUse _ | IUseP _ | IMod _ | IModFile _ | IPub _ | IDecl _
      | IStruct _ | ITypeAlias _ -> ())
    prog;
  (* 第二遍：函数体检查 *)
  let env =
    { g; scopes = []; fncur_ret = TVoid; slotn = 0;
      fnvars = Hashtbl.create 8; const_vals = Hashtbl.create 16;
      in_unsafe = false; moved = Hashtbl.create 8; uses = [] }
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
  (* 顶层声明逐项处理：单条出错记录后继续（多错误收集） *)
  List.iter
    (function
      | IDecl (d, _) ->
        (try
           (match d with
            | SDecl (true, is_frac, is_unred, name, ty, init, p) ->
              (* 顶层 const：编译期常量（整数使用处内联，保持原语义） *)
              if is_frac || is_unred then
                terr p "top-level const does not support frac/unred";
              if lookup_var env name <> None then
                terr p "duplicate top-level constant: %s" name;
              let _t : tstmt = { s = check_decl env p true false false name ty init; spos = p } in
              (match lookup_var env name with
               | Some l ->
                 (match resolve l.lty with
                  | TInt _ | TUint _ -> ()
                  | _ -> terr p "top-level const currently supports only integer types, got %s" (pp_zty l.lty))
               | None -> ())
            | SDecl (is_const, is_frac, is_unred, name, ty, init, p) ->
              (* 非 const 标量（含 frac）：全局可变变量 *)
              if lookup_var env name <> None then
                terr p "duplicate top-level variable: %s" name;
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
            | SSeqDecl (isconst, name, ety, len, is_list, inits, p) ->
              (* 顶层数组/列表：全局可变变量（const 也可，元素修改受 const 约束） *)
              if lookup_var env name <> None then
                terr p "duplicate top-level variable: %s" name;
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
            | _ -> ())
         with TypeError (p, m) -> collected := (p, m) :: !collected)
      | _ -> ())
    prog;
  let hfns =
    List.filter_map
      (function
        | IFn { name; params; ret; body; pos } ->
          (* 函数级错误恢复：签名/返回检查失败记录后跳过该函数 *)
          let depth = List.length env.scopes in
          let r =
            try
              let sig_ = Hashtbl.find g.fns name in
              env.fncur_ret <- sig_.ret;
              env.fnvars <- Hashtbl.create 8;   (* 槽名按函数隔离 *)
              env.moved <- Hashtbl.create 8;    (* move 跟踪按函数隔离 *)
              push_scope env;
              let tparams =
                List.map2
                  (fun (pd : param) pty ->
                    declare env pd.pname
                      { lconst = false; lty = pty; lslot = ""; lunred = false;
                        lconstp = (match pd.pty with TPtrC _ -> true | _ -> false) };
                    let slot = (match lookup_var env pd.pname with
                                | Some l -> l.lslot | None -> assert false) in
                    (false, slot, pty))
                  params sig_.params
              in
              let refnames =
                List.filter_map (fun (pd : param) -> if pd.pref then Some pd.pname else None) params in
              let body' =
                if refnames = [] then body else deref_refs refnames body in
              (* 自动 move 判定数据：函数体内全部变量出现位置（new2.md #1） *)
              env.uses <- List.rev (List.fold_left uses_of_stmt [] body');
              let tbody = check_block env body' in
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
                  terr pos "function %s declares return type %s but may not return a value"
                    name (pp_zty sig_.ret)
              end;
              Some { fname = name; fparams = tparams; fret = sig_.ret; fbody = tbody }
            with TypeError (p, m) ->
              collected := (p, m) :: !collected;
              None
          in
          while List.length env.scopes > depth do pop_scope env done;
          r
        | _ -> None)
      prog
  in
  (* 必须有 main *)
  if not (Hashtbl.mem g.fns "main") then
    terr { file = ""; line = 1; col = 1 } "missing main()";
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
      | ECallK (c, args, moves) -> ECallK (c, List.map fix_texpr args, moves)
      | ECastK (a, t) -> ECastK (fix_texpr a, subst_ty t)
      | EFracNewK (a, b) -> EFracNewK (fix_texpr a, fix_texpr b)
      | ESeqGetK (a, i) -> ESeqGetK (fix_texpr a, fix_texpr i)
      | ESeqLenK a -> ESeqLenK (fix_texpr a)
      | ESeqSliceK (a, b, c, d) ->
        ESeqSliceK (fix_texpr a, fix_texpr b, fix_texpr c, fix_texpr d)
      | ESplitK (a, c) -> ESplitK (fix_texpr a, fix_texpr c)
      | EPushK (a, v) -> EPushK (fix_texpr a, fix_texpr v)
      | EStructNewK (s, args) -> EStructNewK (s, List.map fix_texpr args)
      | EFieldK (b, i) -> EFieldK (fix_texpr b, i)
      | ENullK -> ENullK
      | EAddrOfK a -> EAddrOfK (fix_texpr a)
      | EDerefK a -> EDerefK (fix_texpr a)
      | EIndirectCallK (f, args) ->
        EIndirectCallK (fix_texpr f, List.map fix_texpr args)
      | EFailK (c, m) -> EFailK (fix_texpr c, fix_texpr m)
      | EPanicK (c, m) -> EPanicK (Option.map fix_texpr c, fix_texpr m)
      | EUnwrapK (a, b) -> EUnwrapK (fix_texpr a, fix_texpr b)
      | EPropagateK a -> EPropagateK (fix_texpr a)
      | EErrOkK a -> EErrOkK (fix_texpr a)
      | EFindK (s, c, k) -> EFindK (fix_texpr s, fix_texpr c, fix_texpr k)
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
      | SAssignK (a, b, nn, mv) -> SAssignK (fix_texpr a, fix_texpr b, nn, mv)
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
      | SUnwrapBlockK (d, n, t, a, es, b) ->
        SUnwrapBlockK (d, n, subst_ty t, fix_texpr a, es, List.map fix_stmt b)
      | SFieldSetK (n, idxs, rt, v) ->
        SFieldSetK (n, idxs, subst_ty rt, fix_texpr v)
      | SFieldSeqSetK (n, idxs, rt, e, i, v, g) ->
        SFieldSeqSetK (n, idxs, subst_ty rt, subst_ty e, fix_texpr i, fix_texpr v, g)
      | SAugFieldK (n, idxs, rt, op, v) ->
        SAugFieldK (n, idxs, subst_ty rt, op, fix_texpr v)
      | SDerefSetK (p, v) -> SDerefSetK (fix_texpr p, fix_texpr v)
      | SAugDerefK (p, op, v) -> SAugDerefK (fix_texpr p, op, fix_texpr v)
      | SUnsafeK b -> SUnsafeK (List.map fix_stmt b)
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
  { hfns; hglobals = List.rev !gdeclared; ginit = List.map fix_stmt (List.rev !ginit);
    hstructs = structs_list g }
