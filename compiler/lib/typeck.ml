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

(* 自动修复（本轮）：
   ① 语义级修复（编译继续）：字面量窄化/char→整数 在 coerce 内插入 cast，
      登记进 autofixed（报告 pos, 补丁 pos, 文案, 目标类型名）——driver
      可据补丁 pos 把 cast 写回源文件（交互模式）；
   ② 改名修复（源码补丁重跑）：undefined variable/function 唯一候选、
      undefined type 传统别名 —— 登记进 fix_pos，driver 据此把对应错误
      移入 fixes、对源码打补丁（内存重跑或写回文件） *)
let autofixed : (pos * pos * string * string) list ref = ref []
let fix_pos : (string * int * int, int * string) Hashtbl.t = Hashtbl.create 8

(* 整数值是否落在目标整数类型范围内（自动窄化判据） *)
let int_fits (v : int64) (t : zty) : bool =
  match t with
  | TInt 8 -> v >= -128L && v <= 127L
  | TInt 16 -> v >= -32768L && v <= 32767L
  | TInt 32 -> v >= -2147483648L && v <= 2147483647L
  | TInt 64 -> true
  | TInt 128 | TUint 128 -> true
  | TUint 8 -> v >= 0L && v <= 255L
  | TUint 16 -> v >= 0L && v <= 65535L
  | TUint 32 -> v >= 0L && v <= 4294967295L
  (* u64/u128：位型语义——≥2^63 的 hex 字面量以负 int64 存储，不查符号 *)
  | TUint 64 -> true
  | TUint 128 -> true
  | _ -> false

(* 9d：extern "C" 函数名名单（i128 参数按引用传、返回值按 <2 x i64> 接收，
   与 clang win32 的 __int128 ABI 一致） *)
let extern_fns : (string, unit) Hashtbl.t = Hashtbl.create 8

(* struct 方法表（v3.2 随机数模块）：(struct 名, 方法名) → 脱糖后全局函数名。
   driver 在 expand_uses（导入文件）/脱糖 pass（主文件）里填充；
   check_program 开头清空（单文件单进程，防御性重置） *)
let method_tbl : (string * string, string) Hashtbl.t = Hashtbl.create 16

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

type fn_sig = { params : zty list; prefs : bool list; ret : zty; runred : bool }
  (* prefs：各参数是否为 ref（传引用，new2.md #1）——ref 参数的 params 元素
     已降为 TPtr（调用方 f(ref y) 传地址，函数体内自动解引用）；
     runred：返回类型带 unred（返回值不做 frac 归一，new.md 2026-10-10） *)

(* struct 声明信息（字段 default 为 AST 表达式，构造时检查） *)
type sdefk = { spacked : bool; sfields : (string * zty * expr option) list }

(* 泛型声明模板（new2.md 第2条 方案B）：tparams 非空才入表 *)
type gstructk = { gtp : string list; gpacked : bool; gfields : sfield list; gpos : pos }
type gfnk = { gtp : string list; gparams : param list; gret : ty option;
              grfrac : bool; gbody : block; gpos : pos }

type genv = { fns : (string, fn_sig) Hashtbl.t;
              structs : (string, sdefk) Hashtbl.t;
              aliases : (string, zty) Hashtbl.t;   (* type 别名 *)
              gstructs : (string, gstructk) Hashtbl.t;
              gfns : (string, gfnk) Hashtbl.t;
              gtargs : (string, zty list) Hashtbl.t;
                (* 已实例化 struct 的类型实参（mangled 名 -> zty 列表），
                   泛型构造/调用推断时反向匹配用 *)
              gstructpos : (string, pos) Hashtbl.t;
                (* 循环嵌套检测报错位置 *)
              closigs : (string, zty list * zty) Hashtbl.t }
                (* 闭包类型签名（v3.7）：closure$... mangled 名 -> (参数, 返回) *)

type local = { lconst : bool; lty : zty; lslot : string; lunred : bool;
               lconstp : bool }   (* 指向 const 的指针（T const*，9c）：解引用写报错 *)

(* lambda 捕获上下文（v3.7）：caps = 名字 -> (clenv 字段序号, 是否引用捕获,
   类型, 使用位置)；clenv = env 块 struct 名；base = lambda 检查起点的
   scopes 深度（EVar 外层查找跳过 lambda 自身作用域） *)
type capctxk = { caps : (string, int * bool * zty * pos) Hashtbl.t;
                 clenv : string; base : int }
type env = {
  g : genv;
  mutable scopes : (string, local) Hashtbl.t list;
  mutable fncur_ret : zty;
  mutable slotn : int;                       (* shadowing 改名计数 *)
  mutable fnvars : (string, unit) Hashtbl.t; (* 函数内已用过的变量名（兄弟作用域同名也要新槽） *)
  const_vals : (string, int64) Hashtbl.t;    (* const 整数变量的编译期值（按槽名） *)
  mutable in_unsafe : bool;                  (* 是否在 unsafe 块内（指针算术门禁） *)
  mutable in_unwrap : bool;                  (* 是否在 ?? 解包块内（块末兜底值表达式合法） *)
  mutable moved : (string, unit) Hashtbl.t;  (* 已被显式 move 的变量槽（使用报错；写回解除） *)
  mutable uses : (string * pos) list;        (* 当前函数体内全部 EVar 出现位置
                                                （自动 move 后向判定用，new2.md #1） *)
  mutable ldepth : int;                      (* 循环嵌套深度（while/for 体检查时 +1）：
                                                自动 move 门禁——循环内实参/赋值一律
                                                克隆（new.md 2026-10-11 bug 报告） *)
  mutable capctx : capctxk option;
    (* lambda 体检查上下文（v3.7）：Some cc = 正在检查 lambda 体——
       本地 miss 的 EVar 逐个登记为捕获（与 clenv$N 字段序一致，0=code 头）；
       EVar 直接改写为 env 字段访问 texpr *)
}

(* 内建函数表（与 hir.ml builtin_fns 同步） *)
let builtin_fns_aux : (string * (zty list * zty)) list =
  List.map (fun (n, ps, r) -> (n, (ps, r)))
    [ ("str_len", [ TString ], TInt 64);
      (* 数学内建（v3.2）：直接落 libm 符号，实参经 coerce 自动宽化到 f64 *)
      ("sqrt", [ TFloat 64 ], TFloat 64);
      ("log", [ TFloat 64 ], TFloat 64);
      ("exp", [ TFloat 64 ], TFloat 64);
      ("sin", [ TFloat 64 ], TFloat 64);
      ("cos", [ TFloat 64 ], TFloat 64);
      ("tan", [ TFloat 64 ], TFloat 64);
      ("floor", [ TFloat 64 ], TFloat 64);
      ("ceil", [ TFloat 64 ], TFloat 64);
      ("pow", [ TFloat 64; TFloat 64 ], TFloat 64);
      (* 时间内建（v3.3.6）：时间戳/单调计时/阻塞/日历拆解与构造。
         localtime 返回内建 datetime struct（8×i32，见 genv 初始化处注册）；
         mktime 各分量 i64（整数实参天然落 i64，免窄化 cast），允许越界归一化 *)
      ("now", [ ], TInt 64);
      ("tick_ms", [ ], TInt 64);
      ("sleep_ms", [ TInt 64 ], TVoid);
      ("localtime", [ TInt 64 ], TStruct "datetime");
      ("mktime", [ TInt 64; TInt 64; TInt 64; TInt 64; TInt 64; TInt 64 ], TInt 64) ]

(* 时间内建的用户名 -> 运行时符号：zfy_ 前缀使 llvmgen 豁免自动 declare
   （聚合返回的 declare 收集器签名不匹配 sret 调用形态），由 prelude 统一声明 *)
let time_rt_name = function
  | "now" -> "zfy_time_now"
  | "tick_ms" -> "zfy_time_tick"
  | "sleep_ms" -> "zfy_time_sleep"
  | "localtime" -> "zfy_time_local"
  | "mktime" -> "zfy_time_mktime"
  | n -> n
(* abs 不在此表：整数/f64 双重载，check_call 特判（同宽整数内联 sub+select，
   浮点走 @fabs） *)

(* 字符串内建名（EField 误用提示与 ECall 分派共用，w-020 DX）。
   须定义在下方 let rec 大递归链之前（field_chain 会引用它） *)
let str_builtin_names =
  [ "length"; "find"; "trim"; "split"; "replace"; "prec";
    "utf8_len"; "utf8_char_at"; "utf8_sub" ]

(* 期望类型提示（new2.md 第2条）：声明/字段上下文把已知的期望类型传给
   泛型推断，字面量实参按期望落型（如 Box<i32> a = Box(7) 中 7 → i32
   而非默认 i64）。仅在"即将检查的顶层表达式是对泛型函数/泛型 struct
   的调用"时置位，由消费者（hook_impl / check_struct_new_generic）读取
   并立即清除 *)
let expect_hint : zty option ref = ref None

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

(* ---------- did you mean（n4） ---------- *)

(* Damerau-Levenshtein 编辑距离（含相邻转置；OCaml int 数组 DP） *)
let edit_distance (a : string) (b : string) =
  let n = String.length a and m = String.length b in
  let d = Array.make_matrix (n + 1) (m + 1) 0 in
  for i = 0 to n do d.(i).(0) <- i done;
  for j = 0 to m do d.(0).(j) <- j done;
  for i = 1 to n do
    for j = 1 to m do
      let c = if a.[i - 1] = b.[j - 1] then 0 else 1 in
      let best = min (d.(i - 1).(j) + 1) (d.(i).(j - 1) + 1) in
      let best = min best (d.(i - 1).(j - 1) + c) in
      let best =
        if i > 1 && j > 1 && a.[i - 1] = b.[j - 2] && a.[i - 2] = b.[j - 1]
        then min best (d.(i - 2).(j - 2) + 1)
        else best
      in
      d.(i).(j) <- best
    done
  done;
  d.(n).(m)

(* 从给定候选里找最接近的：距离上限按长度缩放（≤3 字符容 1 错，
   其余容 2 错），完全无相近候选返回 None（不硬凑建议） *)
let edit_close name (cands : string list) =
  let lim_of k = if String.length k <= 3 then 1 else 2 in
  let best = ref None and bestd = ref max_int in
  List.iter
    (fun k ->
      if k <> name then
        let lim = lim_of k in
        let d = edit_distance name k in
        if d > 0 && d <= lim && d < !bestd then begin
          bestd := d; best := Some k
        end)
    cands;
  !best

(* 从可见名字里找最接近的候选：作用域链 + 全局/泛型函数 + struct +
   类型别名 *)
let suggest_name env name =
  let cands = Hashtbl.create 32 in
  let add k = if k <> name then Hashtbl.replace cands k () in
  List.iter (fun sc -> Hashtbl.iter (fun k _ -> add k) sc) env.scopes;
  Hashtbl.iter (fun k _ -> add k) env.g.fns;
  Hashtbl.iter (fun k _ -> add k) env.g.gfns;
  Hashtbl.iter (fun k _ -> add k) env.g.structs;
  Hashtbl.iter (fun k _ -> add k) env.g.aliases;
  List.iter (fun (k, _) -> add k) builtin_fns_aux;   (* 内建函数也是候选（n4） *)
  List.iter add str_builtin_names;                   (* 函数式 string 内建（length/find/...） *)
  edit_close name (Hashtbl.fold (fun k _ acc -> k :: acc) cands [])

(* 报错文案组装：有建议则追加 (did you mean 'x'?) *)
let with_suggestion env name base =
  match suggest_name env name with
  | Some s -> Printf.sprintf "%s (did you mean '%s'?)" base s
  | None -> base

(* 唯一语义建议（自动修复判据）：候选集合同 suggest_name，取最小编辑
   距离且该距离上候选唯一（并列 ≥2 个语义不明，不自动修） *)
let suggest_unique env name =
  let cands = Hashtbl.create 32 in
  let add k = if k <> name then Hashtbl.replace cands k () in
  List.iter (fun sc -> Hashtbl.iter (fun k _ -> add k) sc) env.scopes;
  Hashtbl.iter (fun k _ -> add k) env.g.fns;
  Hashtbl.iter (fun k _ -> add k) env.g.gfns;
  Hashtbl.iter (fun k _ -> add k) env.g.structs;
  Hashtbl.iter (fun k _ -> add k) env.g.aliases;
  List.iter (fun (k, _) -> add k) builtin_fns_aux;
  List.iter add str_builtin_names;
  let lim_of k = if String.length k <= 3 then 1 else 2 in
  let best = ref None and bestd = ref max_int and ties = ref 0 in
  Hashtbl.iter
    (fun k () ->
      let lim = lim_of k in
      let d = edit_distance name k in
      if d > 0 && d <= lim then
        if d < !bestd then begin bestd := d; best := Some k; ties := 1 end
        else if d = !bestd then incr ties)
    cands;
  if !ties = 1 then !best else None

(* undefined variable/function：唯一候选 → 登记改名修复（报错文案带
   auto-fixed，driver 将其移入 fixes 并打源码补丁重跑）；否则原文案 *)
let undef_fix env p name kind =
  let base = Printf.sprintf "undefined %s: %s" kind name in
  match suggest_unique env name with
  | Some s ->
    Hashtbl.replace fix_pos (p.file, p.line, p.col) (String.length name, s);
    terr p "%s (did you mean '%s'? auto-fixed)" base s
  | None ->
    terr p "%s" (with_suggestion env name base)

(* 传统标量类型别名 → 现行宽度名（w-015 别名废止的唯一映射迁移） *)
let legacy_type_alias =
  [ "int", "i32"; "short", "i16"; "long", "i128"; "signed", "i32";
    "unsigned", "u32"; "ulong", "u128"; "float", "f32"; "double", "f64";
    "byte", "i8" ]

(* undefined type：传统别名 → 登记改名修复；否则原文案 *)
let undef_type_fix p s =
  match List.assoc_opt s legacy_type_alias with
  | Some newname ->
    Hashtbl.replace fix_pos (p.file, p.line, p.col) (String.length s, newname);
    terr p "undefined type: %s (legacy alias for '%s'; auto-fixed)" s newname
  | None -> terr p "undefined type: %s" s

(* 泛型函数调用钩子（check_program 内装配）：按已检查实参（texpr）推断
   实例化后返回 mangled 名；未装配时（不应发生）直接报未定义 *)
let generic_call_hook
    : (env -> string -> texpr list -> pos -> string) ref =
  ref (fun env name _ p ->
    terr p "%s" (undef_fix env p name "function"))

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

(* 实例化 mangle：名字 $ tag（多类型实参再以 $ 连接）。LLVM 未引号标识符
   允许 $，而源码标识符不能写 $，故与用户名无碰撞：
   Box<i32> -> "Box$i32"，Pair<A, i32> -> "Pair$A$i32" *)
let rec tag_of_zty (z : zty) : string =
  match resolve z with
  | TInt n -> "i" ^ string_of_int n
  | TUint n -> "u" ^ string_of_int n
  | TFloat n -> "f" ^ string_of_int n
  | TBool -> "bool" | TChar -> "char" | TString -> "string" | TVoid -> "void"
  | TStruct s -> s
  | TPtr t -> "p" ^ tag_of_zty t
  | TFrac e -> "frac" ^ tag_of_zty e
  | TArray (t, n) -> "a" ^ string_of_int n ^ "$" ^ tag_of_zty t
  | TList t -> "l$" ^ tag_of_zty t
  | TErr _ | TFunSig _ | TVar _ | TError ->
    assert false   (* 类型实参校验拦截；TError 不做泛型实参 *)

(* ---------- 内建容器 map<K,V> / set<T>（v3.6） ----------
 * 表示：单 ptr 字段的不透明句柄 struct（h = zfy_map*，null 起步惰性分配）。
 * K/V 类型记入 gtargs；下标读写/内建由 typeck 分派为 runtime 调用。
 * 键限 string/整数(≤64)；值限 ≤64 位标量/string；set 元素同键。 *)
let is_map_struct (s : string) : bool =
  String.length s > 4 && String.sub s 0 4 = "map$"

let cont_kind (s : string) : string option =
  if String.length s > 4 && String.sub s 0 4 = "map$" then Some "map"
  else if String.length s > 4 && String.sub s 0 4 = "set$" then Some "set"
  else None

(* ---------- 闭包（v3.7 函数式轮） ----------
 * 闭包类型 fn(T...) -> R：单 ptr 字段句柄 struct closure$<ret>$<params>
 * （h 指向堆块 [code; caps...]，code = lambda 函数，首参 env = 堆块地址）。
 * 类型按签名单例（声明/实参类型匹配自然成立）；lambda 实例的捕获字段
 * 布局在堆块内（clenv$N），调用方不可见。env 块生命周期 = 进程（v1 不回收）。 *)
let clo_mangle (ret : zty) (ptys : zty list) : string =
  "closure$" ^ tag_of_zty ret ^ "$" ^
  (match ptys with [] -> "void" | _ -> String.concat "_" (List.map tag_of_zty ptys))

let is_clo_struct (s : string) : bool =
  String.length s > 8 && String.sub s 0 8 = "closure$"

(* 注册闭包句柄 struct（幂等），记录签名；返回 mangle 名 *)
let ensure_clo_struct (g : genv) (ret : zty) (ptys : zty list) : string =
  let mangle = clo_mangle ret ptys in
  if not (Hashtbl.mem g.structs mangle) then begin
    Hashtbl.replace g.structs mangle
      { spacked = false; sfields = [ ("h", TPtr (TUint 8), None) ] };
    Hashtbl.replace g.closigs mangle (ptys, ret)
  end;
  mangle

(* ---------- 并发（v3.8）----------
 * thread$ / mutex$ / chan$<elem>：单 ptr 字段不透明句柄 struct
 * （h = Win32 HANDLE / CRITICAL_SECTION* / zfy_chan*）。
 * chan<T> 元素限 ≤64 位标量/string（同 map 值限制）。
 * 句柄可被闭包捕获（spawn(fn() => chan_send(ch, ...)) 的关键路径）。 *)
let is_thr_struct (s : string) = s = "thread$"
let is_mtx_struct (s : string) = s = "mutex$"
let is_chan_struct (s : string) =
  String.length s > 5 && String.sub s 0 5 = "chan$"

(* 注册不透明句柄 struct（幂等；thread$/mutex$ 无类型实参，
   chan$<elem> 的元素实参由 conv_ty 侧另行写入） *)
let ensure_handle_struct (g : genv) (mangle : string) : string =
  if not (Hashtbl.mem g.structs mangle) then begin
    Hashtbl.replace g.structs mangle
      { spacked = false; sfields = [ ("h", TPtr (TUint 8), None) ] };
    if not (Hashtbl.mem g.gtargs mangle) then
      Hashtbl.replace g.gtargs mangle []
  end;
  mangle

(* zty 是否可作捕获字段（v1 限标量/string/bool/char/指针/闭包句柄；
   seq/struct/frac 捕获不支持——struct 捕获的深拷贝所有权链待后续） *)
let rec cap_ty_ok (z : zty) : bool =
  match resolve z with
  | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString -> true
  | TPtr _ -> true
  | TStruct s ->
    is_clo_struct s || is_map_struct s || cont_kind s <> None
    || is_thr_struct s || is_mtx_struct s || is_chan_struct s
  | _ -> false

(* struct 名 -> 闭包签名 *)
let clo_sig (g : genv) (s : string) (p : pos) : zty list * zty =
  match Hashtbl.find_opt g.closigs s with
  | Some ps -> ps
  | None -> terr p "internal error: %s is not a closure struct" s

(* lambda 实例计数与函数体输出（v3.7）：check_lambda 产出的 tfn 在
   check_program 末尾并入 hfns 下传代码生成 *)
let lambda_cnt = ref 0
let lambda_out_acc : tfn list ref = ref []

(* struct 名 -> (键类型, 值类型 option)（set 为 None） *)
let cont_kv (g : genv) (s : string) (p : pos) : zty * zty option =
  match Hashtbl.find_opt g.gtargs s, cont_kind s with
  | Some (k :: v :: _), Some "map" -> (k, Some v)
  | Some [ k ], Some "set" -> (k, None)
  | _ -> terr p "internal error: %s is not a container struct" s

(* zty -> AST 类型叶子（实例化 subst 用；数组/列表形态由 pseq 单独携带，
   不经 fty/pty 表达，故不会到达） *)
let rec ast_of_zty (p : pos) (z : zty) : ty =
  match resolve z with
  | TInt n -> TNamed (Printf.sprintf "i%d" n, p)
  | TUint n -> TNamed (Printf.sprintf "u%d" n, p)
  | TFloat n -> TNamed (Printf.sprintf "f%d" n, p)
  | TBool -> TNamed ("bool", p) | TChar -> TNamed ("char", p)
  | TString -> TNamed ("string", p) | TVoid -> TNamed ("void", p)
  | TStruct s -> TNamed (s, p)
  | TPtr t -> TPtr (ast_of_zty p t, p)
  | TErr t -> TErr (ast_of_zty p t, p)
  | TFrac _ | TArray _ | TList _ | TFunSig _ | TVar _ | TError ->
    terr p "this type cannot be used as a generic type argument"

(* AST 类型层替换：TNamed（类型参数名）-> 实参类型的 AST 形态 *)
let rec subst_ty_ast (map : (string * zty) list) (t : ty) : ty =
  match t with
  | TNamed (s, sp) ->
    (match List.assoc_opt s map with
     | Some z -> ast_of_zty sp z
     | None -> t)
  | TPtr (t2, sp) -> TPtr (subst_ty_ast map t2, sp)
  | TPtrC (t2, sp) -> TPtrC (subst_ty_ast map t2, sp)
  | TErr (t2, sp) -> TErr (subst_ty_ast map t2, sp)
  | TSeq (t2, sp) -> TSeq (subst_ty_ast map t2, sp)
  | TSeqN (t2, len, sp) -> TSeqN (subst_ty_ast map t2, len, sp)
  | TFun (r, ts, sp) -> TFun (subst_ty_ast map r, List.map (subst_ty_ast map) ts, sp)
  | TApp (n, ts, sp) -> TApp (n, List.map (subst_ty_ast map) ts, sp)

let rec conv_ty (g : genv) p (t : ty) : zty =
  match t with
  | TNamed ("frac", pp) ->
    (* frac 作类型（cast 目标等类型位置）：单写 = i32 frac（v3 2026-10-11） *)
    TFrac (TInt 32)
  | TNamed (s, pp) ->
    (match prim_type s with
     | Some t' -> t'
     | None ->
       (match Hashtbl.find_opt g.aliases s with
        | Some t' -> t'
        | None ->
          (match Hashtbl.find_opt g.structs s with
           | Some _ -> TStruct s
           | None -> undef_type_fix pp s)))
  | TPtr (t', pp) -> TPtr (conv_ty g pp t')
  | TPtrC (t', pp) -> TPtr (conv_ty g pp t')   (* const 性在槽级跟踪（lconstp） *)
  | TErr (t', pp) -> TErr (conv_ty g pp t')
  | TFun (ret, ptys, pp) ->
    (* 函数类型统一表示为指针：TPtr (TFunSig ...)（与函数名引用/函数指针
       变量一致，LLVM 层均为 ptr） *)
    TPtr (TFunSig (List.map (fun pt -> conv_ty g pp pt) ptys, conv_ty g pp ret))
  | TApp (("map" | "set") as kn, targs, pp) ->
    (* 内建容器（v3.6）：map<K,V> / set<T>——单 ptr 字段句柄 struct，
       幂等注册；变量裸声明（let map<string,i32> m）即全默认构造 h=null *)
    let arg_zty ta =
      let z = resolve (conv_ty g pp ta) in
      (match z with
       | TErr _ -> terr pp "T! cannot be a container type argument"
       | TFrac _ -> terr pp "frac cannot be a container type argument"
       | TFile -> terr pp "File cannot be a container type argument"
       | TVar _ -> terr pp "a container type argument must be a concrete type"
       | _ -> ());
      z
    in
    let (kt, vt) =
      match kn, targs with
      | "map", [ kta; vta ] ->
        let kz = arg_zty kta in
        (match kz with
         | TInt w when w <= 64 -> ()
         | TUint w when w <= 64 -> ()
         | TString -> ()
         | _ -> terr pp "map key must be an integer (<=64-bit) or string");
        let vz = arg_zty vta in
        (match vz with
         | TInt w when w <= 64 -> ()
         | TUint w when w <= 64 -> ()
         | TFloat 32 | TFloat 64 | TString -> ()
         | _ -> terr pp "map value must be a scalar (<=64-bit) or string");
        (kz, Some vz)
      | "set", [ eta ] ->
        let ez = arg_zty eta in
        (match ez with
         | TInt w when w <= 64 -> ()
         | TUint w when w <= 64 -> ()
         | TString -> ()
         | _ -> terr pp "set element must be an integer (<=64-bit) or string");
        (ez, None)
      | "map", _ -> terr pp "map expects 2 type arguments: map<K, V>"
      | _ -> terr pp "set expects 1 type argument: set<T>"
    in
    let mangle =
      match vt with
      | Some v -> "map$" ^ tag_of_zty kt ^ "$" ^ tag_of_zty v
      | None -> "set$" ^ tag_of_zty kt
    in
    if not (Hashtbl.mem g.structs mangle) then begin
      Hashtbl.replace g.structs mangle
        { spacked = false; sfields = [ ("h", TPtr (TUint 8), None) ] };
      Hashtbl.replace g.gtargs mangle
        (match vt with Some v -> [ kt; v ] | None -> [ kt ])
    end;
    TStruct mangle
  | TClo (ptys, ret, pp) ->
    (* 闭包类型（v3.7）：fn(T...) -> R——单 ptr 句柄 struct（按签名单例） *)
    let ptys' = List.map (fun pt -> resolve (conv_ty g pp pt)) ptys in
    let ret' = resolve (conv_ty g pp ret) in
    (match resolve ret' with
     | TVoid | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString -> ()
     | _ -> terr pp "closure return type must be a scalar, string or void");
    List.iter
      (fun z ->
        if not (cap_ty_ok z) then
          terr pp "closure parameter type %s is not supported (v1: scalar/string/pointer/closure)"
            (pp_zty z))
      ptys';
    TStruct (ensure_clo_struct g ret' ptys')
  | TApp ("chan", [ cta ], pp) ->
    (* chan<T>（v3.8）：类型限同 map 值（≤64 位标量/string）；
       单 ptr 句柄 struct，元素类型记 gtargs 供内建分派 *)
    let ez = resolve (conv_ty g pp cta) in
    (match ez with
     | TInt w when w <= 64 -> ()
     | TUint w when w <= 64 -> ()
     | TFloat 32 | TFloat 64 | TString -> ()
     | TErr _ | TFrac _ | TFile | TVar _ ->
       terr pp "chan element cannot be %s" (pp_zty ez)
     | _ -> terr pp "chan element must be a scalar (<=64-bit) or string");
    let mangle = "chan$" ^ tag_of_zty ez in
    ignore (ensure_handle_struct g mangle);
    Hashtbl.replace g.gtargs mangle [ ez ];
    TStruct mangle
  | TApp (n, targs, pp) ->
    (* 泛型实例化 Box<i32, T*>（new2.md 第2条）：按模板展开注册具体
       struct，monomorphization 完全在 typeck 内完成 *)
    (match Hashtbl.find_opt g.gstructs n with
     | None -> terr pp "undefined generic struct: %s" n
     | Some gs ->
       if List.length targs <> List.length gs.gtp then
         terr pp "generic struct %s expects %d type arguments, got %d"
           n (List.length gs.gtp) (List.length targs);
       let ztys =
         List.map
           (fun ta ->
             let z = resolve (conv_ty g pp ta) in
             (match z with
              | TErr _ -> terr pp "T! cannot be a type argument"
              | TFrac _ -> terr pp "frac cannot be a type argument"
              | TFile -> terr pp "File cannot be a type argument (move-only handle)"
              | TVar _ -> terr pp "a generic type argument must be a concrete type"
              | _ -> ());
             z)
           targs
       in
       instantiate_struct_zty g n (List.combine gs.gtp ztys) pp)
  | TSeq (t', pp) ->
    (* T[]：动态数组/列表（类型后缀形式，w-014 #1）；
       声明/参数/字段的数组形状由 parser 归一到 pseq/fseq，此处兜底
       元素类型位置的嵌套（i32 a[][] 的元素 TSeq） *)
    let e = conv_ty g pp t' in
    (match resolve e with
     | TFile -> terr pp "File cannot be an array/list element (move-only handle)"
     | _ -> ());
    TList e
  | TSeqN (t', len, pp) ->
    (* T[N]：定长数组（类型后缀形式）。类型位置（返回类型/字段元素/别名）
       长度须整数字面量；声明/参数处完整表达式长度由 pseq/PArray 承载 *)
    (match len with
     | EInt (n, _) when n >= 0L ->
       let e = conv_ty g pp t' in
       (match resolve e with
        | TFile -> terr pp "File cannot be an array element (move-only handle)"
        | _ -> ());
       TArray (e, Int64.to_int n)
     | _ -> terr pp "fixed array type length must be a non-negative integer literal here")

(* 注册具体实例（幂等）：先占位再展开字段（自引用指针字段可引用）；
   值形态自引用由字段自查拦截，跨实例值环由检查末尾的循环嵌套复检拦截 *)
and instantiate_struct_zty (g : genv) (gname : string)
    (map : (string * zty) list) (p : pos) : zty =
  let gs = Hashtbl.find g.gstructs gname in
  let mangle =
    gname ^ "$" ^ String.concat "$" (List.map (fun (_, z) -> tag_of_zty z) map) in
  if Hashtbl.mem g.structs mangle then TStruct mangle
  else begin
    Hashtbl.replace g.structs mangle { spacked = gs.gpacked; sfields = [] };
    Hashtbl.replace g.gstructpos mangle p;
    let seen = ref [] in
    let sfields =
      List.map
        (fun (sf : sfield) ->
          let fty2 = subst_ty_ast map sf.fty in
          let base = conv_ty g sf.fpos fty2 in
          let ft =
            match sf.fseq with
            | PScalar -> base
            | PList -> TList base
            | PArray len ->
              (match len with
               | EInt (n, _) when n >= 0L -> TArray (base, Int64.to_int n)
               | _ ->
                 terr sf.fpos "struct field array length must be a compile-time literal")
          in
          (match resolve ft with
           | TStruct s2 when s2 = mangle ->
             terr sf.fpos "struct %s field type cannot be itself (infinite size)" mangle
           | TErr _ ->
             terr sf.fpos "T! cannot be a struct field (error values are aggregates and cannot be loaded as a field)"
           | TFile ->
             terr sf.fpos "File cannot be a struct field (move-only handle)"
           | _ -> ());
          if List.mem sf.fname !seen then
            terr p "struct %s has duplicate field %s" mangle sf.fname;
          seen := sf.fname :: !seen;
          (sf.fname, ft, sf.fdefault))
        gs.gfields
    in
    Hashtbl.replace g.structs mangle { spacked = gs.gpacked; sfields };
    Hashtbl.replace g.gtargs mangle (List.map snd map);
    TStruct mangle
  end

(* 泛型实参推断：AST 参数类型（含类型参数名）匹配实参 zty，绑定写入 map。
   重复绑定时要求一致；结构性不匹配返回 false（由调用方报错） *)
let rec match_gty (g : genv) (tparams : string list) (p : pos)
    (t : ty) (z0 : zty) (mref : (string * zty) list ref) : bool =
  let z = resolve z0 in
  match t with
  | TNamed (s, _) when List.mem s tparams ->
    (match List.assoc_opt s !mref with
     | Some z' -> resolve z' = z
     | None -> mref := (s, z) :: !mref; true)
  | TNamed _ -> resolve (conv_ty g p t) = z
  | TPtr (t2, _) -> (match z with TPtr z2 -> match_gty g tparams p t2 z2 mref | _ -> false)
  | TPtrC (t2, _) -> (match z with TPtr z2 -> match_gty g tparams p t2 z2 mref | _ -> false)
  | TErr (t2, _) ->
    (* T! 返回类型下钻：声明期望 i32! 与返回 T! 反绑 T=i32（w-011 后续） *)
    (match z with TErr z2 -> match_gty g tparams p t2 z2 mref | _ -> false)
  | TFun (r, ps, _) ->
    (match z with
     | TPtr (TFunSig (zs, rz)) ->
       List.length ps = List.length zs &&
       match_gty g tparams p r rz mref &&
       List.for_all2 (fun pa zb -> match_gty g tparams p pa zb mref) ps zs
     | _ -> false)
  | TApp (n, targs, _) ->
    (match z with
     | TStruct m ->
       (match Hashtbl.find_opt g.gtargs m with
        | Some zs when List.length zs = List.length targs ->
          List.for_all2 (fun ta zb -> match_gty g tparams p ta zb mref) targs zs
        | _ -> false)
     | _ -> false)

(* 参数级匹配（数组/列表形态由 pseq 携带：T x[] 匹配 TList（元素比对）） *)
let match_param (g : genv) (tparams : string list) (p : pos)
    (pd : param) (z : zty) (mref : (string * zty) list ref) : bool =
  let z = resolve z in
  match pd.pseq, pd.pfrac with
  | PScalar, false -> match_gty g tparams p pd.pty z mref
  | PScalar, true ->
    (match z with TFrac z2 -> match_gty g tparams p pd.pty z2 mref | _ -> false)
  | PList, _ ->
    (match z with TList z2 -> match_gty g tparams p pd.pty z2 mref | _ -> false)
  | PArray _, _ ->
    (match z with TArray (z2, _) -> match_gty g tparams p pd.pty z2 mref | _ -> false)

let pos_of_expr = function
  | EInt (_, p) | EBigInt (_, p) | EFloat (_, p) | EStr (_, p) | EChar (_, p) | EBool (_, p)
  | EVar (_, p) | EBin (_, _, _, p) | EUn (_, _, p) | ECall (_, _, p)
  | EIndex (_, _, p) | ESlice (_, _, _, _, p)
  | ECast (_, _, p)
  | EStructNew (_, _, p) | EField (_, _, p)
  | EAddrOf (_, p) | EDeref (_, p) | ENull p
  | EFail (_, _, p) | EPanic (_, _, p) | EUnwrap (_, _, p) | EPropagate (_, p)
  | ERemove (_, _, p)
  | ELambda (_, p)
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
  | "INPUT" -> Some 6L | "EOF" -> Some 7L | "CUSTOM" -> Some 100L
  | _ -> None

(* ---------- 表达式检查 ---------- *)

(* 子树是否含浮点字面量（EFloatK 叶子；v3.3.1 混合字面量修复）：
   含 EFloatK 的未定 TVar 子树只能整体按浮点定型，绝不能落整数型 *)
let rec floaty_texpr (x : texpr) : bool =
  match x.e with
  | EFloatK _ -> true
  | EUnK (_, u) -> floaty_texpr u
  | EBinK (_, a, b) -> floaty_texpr a || floaty_texpr b
  | _ -> false

(* 类型零值表达式（声明省略初值时使用；struct 递归为全字段零值/default 构造） *)
exception ZtyToAstFail
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
  | TStruct s when is_chan_struct s ->
    (* chan/mutex 句柄声明即构造（v3.8）：不做惰性 null 起步——句柄会被
       闭包按值捕获，声明后再初始化会与捕获副本错开对象（死锁/失效） *)
    { e = ECallK ("zfy_chan_new", [], []); ety = t; epos = p }
  | TStruct s when is_mtx_struct s ->
    { e = ECallK ("zfy_mutex_new", [], []); ety = t; epos = p }
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
  | None -> undef_type_fix p s
  | Some sd ->
    let rec go i = function
      | [] ->
        (* did you mean：字段名候选（n4） *)
        let cands = List.map (fun (fn, _, _) -> fn) sd.sfields in
        (match edit_close seg cands with
         | Some f ->
           terr p "struct %s has no field %s (did you mean '%s'?)" s seg f
         | None -> terr p "struct %s has no field %s" s seg)
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
  | EUnK (UBitNot, a) ->
    (match const_eval env a with Some v -> Some (Int64.lognot v) | None -> None)
  | ECastK (a, _) -> const_eval env a
  | ECallK ("abs", [ a ], _) ->
    (* abs 常量折叠（v3.3.2）：无符号=恒等（与 llvmgen 一致）、
       有符号=负取反。|n| 可作数组长度 *)
    (match const_eval env a with
     | Some v ->
       (match resolve e.ety with
        | TUint _ -> Some v
        | _ -> Some (if v < 0L then Int64.neg v else v))
     | None -> None)
  | EBinK (op, a, b) ->
    (match const_eval env a, const_eval env b with
     | Some x, Some y ->
       (match op with
        | BAdd -> Some (Int64.add x y)
        | BSub -> Some (Int64.sub x y)
        | BMul -> Some (Int64.mul x y)
        | BDiv when y <> 0L -> Some (Int64.div x y)
        | BMod when y <> 0L -> Some (Int64.rem x y)
        | BBitAnd -> Some (Int64.logand x y)
        | BBitOr -> Some (Int64.logor x y)
        | BBitXor -> Some (Int64.logxor x y)
        | BShl when y >= 0L && y < 64L -> Some (Int64.shift_left x (Int64.to_int y))
        | BShr when y >= 0L && y < 64L ->
          (* 与 llvmgen 一致：有符号 ashr、无符号 lshr *)
          (match resolve e.ety with
           | TUint _ -> Some (Int64.shift_right_logical x (Int64.to_int y))
           | _ -> Some (Int64.shift_right x (Int64.to_int y)))
        | BPow ->
          (** 幂常量折叠（v3.3.2）：与 runtime zfy_pow_ll/ull 语义一致——
              负指数 = 0、乘法按 64 位回绕（Int64.mul 天然回绕），
              平方乘迭代 *)
          if y < 0L then Some 0L
          else begin
            let rec go acc b e =
              if e = 0L then acc
              else
                let acc =
                  if Int64.logand e 1L = 1L then Int64.mul acc b else acc in
                go acc (Int64.mul b b) (Int64.shift_right_logical e 1)
            in
            Some (go 1L x y)
          end
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

(* float 字面量精确转整数元素 frac（new.md 2026-10-11 用户拍板"把 0.5 改存为
   1/2"）：二进制分解 v = m·2^k（frexp），奇化后 v = n/d——0.5→1/2、
   0.75→3/4。den 超 i64（如 0.1 的二进制表示）或 n/d 超出目标宽度报错：
   提示改用 f64 frac 或 n/d/循环小数字面量 *)
and frac_of_float_lit (v : float) (elem : zty) (p : pos) : texpr =
  if not (Float.is_finite v) then
    terr p "float literal is not finite and cannot become a frac";
  let neg = v < 0.0 in
  let a = Float.abs v in
  let num_pos, den =
    if a = 0.0 then (0L, 1L)
    else begin
      let (m0, k0) = frexp a in                        (* a = m0 * 2^k0 *)
      let m = ref (Int64.of_float (m0 *. 9007199254740992.0)) in (* *2^53 取整 *)
      let k = ref (k0 - 53) in
      while !k < 0 && Int64.equal (Int64.logand !m 1L) 0L do
        m := Int64.shift_right !m 1;
        incr k
      done;                                            (* 奇化：v = m * 2^k *)
      if !k >= 0 then begin
        if !k >= 63
           || Int64.equal !m 0L
           || Int64.compare (Int64.shift_right (Int64.shift_left !m !k) !k) !m <> 0 then
          terr p
            "float literal %h does not fit a 64-bit frac numerator (use f64 frac or write n/d)" v;
        (Int64.shift_left !m !k, 1L)
      end
      else begin
        if - !k >= 63 then
          terr p
            "float literal %h is not exactly representable as an integer frac (use f64 frac, n/d, or a repeating decimal literal)" v;
        (!m, Int64.shift_left 1L (- !k))
      end
    end
  in
  let num = if neg then Int64.neg num_pos else num_pos in
  let width = (match elem with TInt w | TUint w -> w | _ -> 0) in
  let fits_signed w x =
    match w with
    | 8 -> Int64.compare x 127L <= 0 && Int64.compare x (-128L) >= 0
    | 16 -> Int64.compare x 32767L <= 0 && Int64.compare x (-32768L) >= 0
    | 32 -> Int64.compare x 2147483647L <= 0 && Int64.compare x (-2147483648L) >= 0
    | _ -> true in
  let fits_unsigned w x =
    match w with
    | 8 -> Int64.compare x 255L <= 0
    | 16 -> Int64.compare x 65535L <= 0
    | 32 -> Int64.compare x 4294967295L <= 0
    | _ -> true in
  let ok =
    match elem with
    | TInt w -> fits_signed w num && fits_signed w den
    | TUint w -> fits_unsigned w num && fits_unsigned w den
    | _ -> true
  in
  if not ok then
    terr p "float literal %h overflows %s frac (use a wider frac or write n/d)" v (pp_zty (TFrac elem));
  let np = { e = EIntK num; ety = elem; epos = p } in
  let dp = { e = EIntK den; ety = elem; epos = p } in
  { e = EFracNewK (np, dp); ety = TFrac elem; epos = p }

(* 判断 AST 是否为 frac 期望适用的算术形态（含 / 的四则或取负） *)
and is_frac_arith (e : expr) : bool =
  match e with
  | EBin ((Ast.Add | Ast.Sub | Ast.Mul | Ast.Div), _, _, _) -> true
  | EUn (Ast.Neg, _, _) -> true
  | _ -> false

(* frac 期望表达式（new.md 2026-10-11 用户拍板：frac 上下文里只要是有
   / 号都直接用分数）：整棵算术表达式按分数计算——
   - n/d 字面量形式仍按分数构造（不执行除法，unred 声明保留原分子分母）
   - 其余除法两侧转 frac 走运行时分数除法（结果自动约分）
   - 整数字面量/标量表达式自动提升为分数（x → x/1）
   - float 字面量在整数 frac 中精确转二进制分数（0.5 → 1/2）
   非 frac 目标路径完全不经过此函数（i32 目标整数除法、f64 目标实数除法
   维持现状）。 *)
and check_frac_expr env (e : expr) (elem : zty) : texpr =
  let p = pos_of_expr e in
  match e with
  | EBin (Ast.Div, a, b, p')
    when (match a, b with
          | (EInt _ | EFloat _), (EInt _ | EFloat _) -> true
          | _ -> false) ->
    (* n/d 字面量：按分数构造，不执行除法（与既有声明/实参语义一致） *)
    let ta = check_expr env a and tb = check_expr env b in
    let conv (x : expr) (t : texpr) =
      match x, elem with
      | EFloat (v, _), (TInt _ | TUint _) -> frac_of_float_lit v elem p'
      | _ ->
        if resolve t.ety = elem then t
        else { e = ECastK (t, elem); ety = elem; epos = t.epos }
    in
    { e = EFracNewK (conv a ta, conv b tb); ety = TFrac elem; epos = p' }
  | EBin ((Ast.Add | Ast.Sub | Ast.Mul | Ast.Div) as op, a, b, p') ->
    let ta = check_frac_expr env a elem in
    let tb = check_frac_expr env b elem in
    let bop =
      match op with
      | Ast.Add -> BAdd | Ast.Sub -> BSub | Ast.Mul -> BMul | _ -> BDiv
    in
    (match resolve ta.ety, resolve tb.ety with
     | TFrac e1, TFrac e2 ->
       if e1 = e2 then { e = EBinK (bop, ta, tb); ety = TFrac e1; epos = p' }
       else
         terr p' "mismatched frac element types: %s vs %s"
           (pp_zty (TFrac e1)) (pp_zty (TFrac e2))
     | _ -> assert false)
  | EUn (Ast.Neg, a, _) ->
    let t = check_frac_expr env a elem in
    (match resolve t.ety with
     | TFrac e2 ->
       let zero = mk_frac_from { e = EIntK 0L; ety = e2; epos = p } e2 p in
       { e = EBinK (BSub, zero, t); ety = TFrac e2; epos = p }
     | _ -> t)
  | _ ->
    (* 叶子/其他表达式：正常检查后标量提升为分数 *)
    let t = check_expr env e in
    (match resolve t.ety, t.e with
     | TFrac e2, _ when e2 = elem -> t
     | TFrac _, _ -> terr p "mismatched frac element types"
     | _, EFloatK v when (match elem with TInt _ | TUint _ -> true | _ -> false) ->
       (* float 字面量精确转整数 frac（ety 可能为 TVar，先看节点形态） *)
       frac_of_float_lit v elem p
     | (TInt _ | TUint _ | TFloat _ | TVar _), _ -> mk_frac_from t elem p
     | _ ->
       terr p "cannot use %s in a frac expression" (pp_zty t.ety))


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

(* 大字面量范围校验（w-014 #6）：去前导零后与 i128/u128 十进制上限比较 *)
and big_ok (digits : string) (unsigned : bool) : bool =
  let mx =
    if unsigned then "340282366920938463463374607431768211455"
    else "170141183460469231731687303715884105727" in
  let rec strip s =
    if String.length s > 1 && s.[0] = '0'
    then strip (String.sub s 1 (String.length s - 1)) else s in
  let d = strip digits in
  if d = "" then false
  else if String.length d < String.length mx then true
  else if String.length d > String.length mx then false
  else String.compare d mx <= 0

(* map 键实参分派：string 原样；整数统一拓宽到 i64（运行时键槽 8 字节） *)
and map_key_arg env p (tidx : texpr) : string * texpr =
  match resolve tidx.ety with
  | TString -> ("s", coerce p tidx TString)
  | _ -> ("i", to_i64 tidx)

(* map 值种类标签（运行时函数后缀）：整数统一 i64 位模式 *)
and map_vtag p (vt : zty) : string =
  match resolve vt with
  | TInt _ | TUint _ -> "i64"
  | TFloat 32 -> "f32"
  | TFloat 64 -> "f64"
  | TString -> "str"
  | t -> terr p "unsupported map value type %s" (pp_zty t)

(* map 实参（须为局部变量槽：struct 值传槽地址，即 zfy_map**） *)
and map_self_arg env p (tb : texpr) : texpr =
  match tb.e with
  | EVarK _ -> tb
  | _ -> terr p "map/set operations currently require a local variable (not a field chain or expression)"

(* 内建容器调用分派（v3.6）：map/set 操作与列表算法内建。
   返回 (运行时函数名, 签名)；None 走原路径。用户自定义同名函数优先 *)
and container_call env p name0 (targs : texpr list) : (string * fn_sig) option =
  if Hashtbl.mem env.g.fns name0 || Hashtbl.mem env.g.gfns name0 then None
  else begin
    let sig1 ps r =
      Some (name0, { params = ps; prefs = List.map (fun _ -> false) ps;
                     ret = r; runred = false })
    in
    let mkf nm ps r = match sig1 ps r with Some (_, s) -> Some (nm, s) | None -> None in
    let seq_elem xs =
      match resolve xs.ety with
      | TList e -> e
      | t -> terr p "%s expects a list as first argument, got %s" name0 (pp_zty t)
    in
    (* 整数键/值实参统一 i64 槽（运行时 8 字节） *)
    let key_param kt =
      match resolve kt with TString -> TString | _ -> TInt 64
    in
    match name0, targs with
    | "set_add", [ s; x ] ->
      (match resolve s.ety with
       | TStruct sn when cont_kind sn = Some "set" ->
         let (kt, _) = cont_kv env.g sn p in
         let kf = (match resolve kt with TString -> "s" | _ -> "i") in
         mkf ("zfy_set_add_" ^ kf) [ TStruct sn; key_param kt ] TVoid
       | t -> terr p "set_add expects a set, got %s" (pp_zty t))
    | ("map_len" | "set_len"), [ m ] ->
      (match resolve m.ety with
       | TStruct s when cont_kind s <> None -> mkf "zfy_map_len" [ TStruct s ] (TInt 64)
       | t -> terr p "%s expects a map/set, got %s" name0 (pp_zty t))
    | ("map_has" | "set_has" | "contains"), [ m; k ] ->
      (match resolve m.ety with
       | TStruct s when cont_kind s <> None ->
         let (kt, _) = cont_kv env.g s p in
         let kf = (match resolve kt with TString -> "s" | _ -> "i") in
         mkf ("zfy_map_has_" ^ kf) [ TStruct s; key_param kt ] TBool
       | TList _ ->
         let e = seq_elem m in
         let tag =
           match resolve e with
           | TInt w -> "i" ^ string_of_int w
           | TUint w -> "u" ^ string_of_int w
           | TFloat 32 -> "f32" | TFloat 64 -> "f64" | TString -> "str"
           | t -> terr p "contains does not support element type %s" (pp_zty t)
         in
         (* 值实参按元素精确宽度（槽宽匹配运行时） *)
         mkf ("zfy_contains_" ^ tag) [ TList e; e ] TBool
       | t -> terr p "%s expects a map/set/list, got %s" name0 (pp_zty t))
    | ("map_del" | "set_del"), [ m; k ] ->
      (match resolve m.ety with
       | TStruct s when cont_kind s <> None ->
         let (kt, _) = cont_kv env.g s p in
         let kf = (match resolve kt with TString -> "s" | _ -> "i") in
         mkf ("zfy_map_del_" ^ kf) [ TStruct s; key_param kt ] TBool
       | t -> terr p "%s expects a map/set, got %s" name0 (pp_zty t))
    | "keys", [ m ] ->
      (match resolve m.ety with
       | TStruct s when cont_kind s <> None ->
         let (kt, _) = cont_kv env.g s p in
         mkf "zfy_map_keys" [ TStruct s ] (TList kt)
       | t -> terr p "keys expects a map/set, got %s" (pp_zty t))
    | "values", [ m ] ->
      (match resolve m.ety with
       | TStruct s when is_map_struct s ->
         let (_, Some vt) = cont_kv env.g s p in
         mkf "zfy_map_values" [ TStruct s ] (TList vt)
       | t -> terr p "values expects a map, got %s" (pp_zty t))
    (* ---------- 并发内建（v3.8）：线程/互斥/原子/sleep/channel ---------- *)
    | "spawn", [ f ] ->
      (* spawn(闭包或函数名) -> thread$ 句柄；裸函数名（EFunPtrK）先注册
         签名对应的闭包 struct，对齐处自动包 wrapper（与容器谓词同机制） *)
      let cs =
        match resolve f.ety with
        | TStruct s when is_clo_struct s -> s
        | TPtr (TFunSig (ps, r)) -> ensure_clo_struct env.g r ps
        | _ -> terr p "spawn expects a lambda or function name (fn() -> void)"
      in
      mkf "zfy_thread_spawn" [ TStruct cs ]
        (TStruct (ensure_handle_struct env.g "thread$"))
    | "join", [ t ] ->
      (match resolve t.ety with
       | TStruct s when is_thr_struct s -> mkf "zfy_thread_join" [ TStruct s ] TVoid
       | _ -> terr p "join expects a thread handle (the value returned by spawn)")
    | "mutex_new", [] ->
      mkf "zfy_mutex_new" [] (TStruct (ensure_handle_struct env.g "mutex$"))
    | ("lock" | "unlock") as kn, [ m ] ->
      (match resolve m.ety with
       | TStruct s when is_mtx_struct s ->
         mkf ("zfy_mutex_" ^ kn) [ TStruct s ] TVoid
       | _ -> terr p "%s expects a mutex handle (from mutex_new)" kn)
    | "atomic_load", [ x ] ->
      (* 原子读：实参 &var（TPtr），限 32/64 位整数；返回变量类型 *)
      (match resolve x.ety with
       | TPtr ((TInt 32 | TUint 32) as e) -> mkf "zfy_atomic_load_32" [ x.ety ] e
       | TPtr ((TInt 64 | TUint 64) as e) -> mkf "zfy_atomic_load_64" [ x.ety ] e
       | _ -> terr p "atomic_load expects &var of a 32/64-bit integer")
    | "atomic_store", [ x; v ] ->
      (match resolve x.ety with
       | TPtr ((TInt 32 | TUint 32) as e) ->
         mkf "zfy_atomic_store_32" [ x.ety; e ] TVoid
       | TPtr ((TInt 64 | TUint 64) as e) ->
         mkf "zfy_atomic_store_64" [ x.ety; e ] TVoid
       | _ -> terr p "atomic_store expects &var of a 32/64-bit integer")
    | "atomic_add", [ x; v ] ->
      (* 原子加：返回加前旧值（fetch_add 语义） *)
      (match resolve x.ety with
       | TPtr ((TInt 32 | TUint 32) as e) ->
         mkf "zfy_atomic_add_32" [ x.ety; e ] e
       | TPtr ((TInt 64 | TUint 64) as e) ->
         mkf "zfy_atomic_add_64" [ x.ety; e ] e
       | _ -> terr p "atomic_add expects &var of a 32/64-bit integer")
    | "atomic_inc", [ x ] ->
      (* 原子自增：void 返回（语句级可用，免值丢弃检查） *)
      (match resolve x.ety with
       | TPtr (TInt 32 | TUint 32) -> mkf "zfy_atomic_inc_32" [ x.ety ] TVoid
       | TPtr (TInt 64 | TUint 64) -> mkf "zfy_atomic_inc_64" [ x.ety ] TVoid
       | _ -> terr p "atomic_inc expects &var of a 32/64-bit integer")
    | "sleep", [ ms ] -> mkf "zfy_sleep_ms" [ TInt 64 ] TVoid
    | "chan_send", [ c; v ] ->
      (match resolve c.ety with
       | TStruct s when is_chan_struct s ->
         (match Hashtbl.find_opt env.g.gtargs s with
          | Some [ et ] ->
            let vtag = map_vtag p et in
            let vparam = (match resolve et with TString -> TString | _ -> TInt 64) in
            mkf ("zfy_chan_send_" ^ vtag) [ TStruct s; vparam ] TVoid
          | _ -> terr p "internal error: chan struct missing element type")
       | _ -> terr p "chan_send expects a chan handle")
    | "chan_recv", [ c ] ->
      (* 阻塞接收：产 T!（closed 且排空 = NOT_FOUND），须 ?? 解包 *)
      (match resolve c.ety with
       | TStruct s when is_chan_struct s ->
         (match Hashtbl.find_opt env.g.gtargs s with
          | Some [ et ] ->
            mkf (Printf.sprintf "zfy_chan_recv_err_%s" (map_vtag p et))
              [ TStruct s ] (TErr et)
          | _ -> terr p "internal error: chan struct missing element type")
       | _ -> terr p "chan_recv expects a chan handle")
    | "chan_close", [ c ] ->
      (match resolve c.ety with
       | TStruct s when is_chan_struct s -> mkf "zfy_chan_close" [ TStruct s ] TVoid
       | _ -> terr p "chan_close expects a chan handle")
    | "chan_len", [ c ] ->
      (match resolve c.ety with
       | TStruct s when is_chan_struct s -> mkf "zfy_chan_len" [ TStruct s ] (TInt 64)
       | _ -> terr p "chan_len expects a chan handle")
    | "sort", [ xs ] ->
      let e = seq_elem xs in
      let tag =
        match resolve e with
        | TInt w -> "i" ^ string_of_int w
        | TUint w -> "u" ^ string_of_int w
        | TFloat 32 -> "f32" | TFloat 64 -> "f64" | TString -> "str"
        | t -> terr p "sort does not support element type %s" (pp_zty t)
      in
      mkf ("zfy_sort_" ^ tag) [ TList e ] (TList e)
    | "reverse", [ xs ] ->
      let e = seq_elem xs in
      mkf "zfy_reverse" [ TList e ] (TList e)
    | "join", [ xs; sep ] ->
      (match resolve xs.ety, resolve sep.ety with
       | TList TString, TString -> mkf "zfy_join" [ TList TString; TString ] TString
       | _ -> terr p "join expects (list<string>, string)")
    | ("filter" | "any" | "all") as kn, [ xs; pred ] ->
      let e = seq_elem xs in
      (match resolve e with
       | TInt _ | TUint _ | TFloat _ | TString -> ()
       | t -> terr p "%s does not support element type %s (predicate receives elements by value)" kn (pp_zty t));
      let ret = if kn = "filter" then TList e else TBool in
      (* 谓词 = 闭包句柄（v3.7）：函数名/lambda 实参在 coerce 处统一包装 *)
      mkf ("zfy_" ^ kn) [ TList e; TStruct (ensure_clo_struct env.g TBool [ e ]) ] ret
    | "sort_by", [ xs; cmp ] ->
      let e = seq_elem xs in
      (match resolve e with
       | TInt _ | TUint _ | TFloat _ | TString -> ()
       | t -> terr p "sort_by does not support element type %s" (pp_zty t));
      mkf "zfy_sort_by"
        [ TList e; TStruct (ensure_clo_struct env.g (TInt 32) [ e; e ]) ] (TList e)
    | "map", [ xs; f ] ->
      (* map(xs, f) -> list<B>（v3.7）：B 由 f 返回类型定（限标量/string） *)
      let e = seq_elem xs in
      (match resolve e with
       | TInt _ | TUint _ | TFloat _ | TString -> ()
       | t -> terr p "map does not support element type %s" (pp_zty t));
      let bty =
        match resolve f.ety with
        | TStruct s when is_clo_struct s ->
          let (_, r) = clo_sig env.g s p in
          (match resolve r with
           | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString -> r
           | _ -> terr p "map's function must return a scalar or string")
        | _ -> terr p "map's second argument must be a lambda or function name"
      in
      mkf "zfy_map_seq" [ TList e; TStruct (ensure_clo_struct env.g bty [ e ]) ] (TList bty)
    | "fold", [ xs; f; init ] ->
      (* 列表归并（v3.6）：reduce 是 frac 缩减关键字，故名 fold *)
      let e = seq_elem xs in
      let tag =
        match resolve e with
        | TInt w -> "i" ^ string_of_int w
        | TUint w -> "u" ^ string_of_int w
        | TFloat 32 -> "f32" | TFloat 64 -> "f64" | TString -> "str"
        | t ->
          terr p "fold supports integer/float/string elements, got %s" (pp_zty t)
      in
      (* 归并函数 = 闭包句柄（v3.7）：签名 (T, T) -> T *)
      mkf ("zfy_fold_" ^ tag)
        [ TList e; TStruct (ensure_clo_struct env.g e [ e; e ]); e ] e
    | _ -> None
  end

(* ---------- lambda / 嵌套函数（v3.7 函数式轮） ---------- *)

(* env 字段访问 texpr：值捕获 = EField(deref env, idx)；
   引用捕获 = deref(EField(deref env, idx))（字段类型 TPtr，idx 0 = code 头） *)
and cap_ref env idx is_ref ty p' =
  match env.capctx with
  | Some cc ->
    let envp = { e = EVarK "$env"; ety = TPtr (TStruct cc.clenv); epos = p' } in
    let deref_env = { e = EDerefK envp; ety = TStruct cc.clenv; epos = p' } in
    let fld = { e = EFieldK (deref_env, idx);
                ety = (if is_ref then TPtr ty else ty); epos = p' } in
    if is_ref then { e = EDerefK fld; ety = ty; epos = p' } else fld
  | None -> assert false

(* lambda 捕获尝试：本地 miss 且在 lambda 体上下文 → 外层局部变量登记
   捕获（隐式值捕获；显式 [&x] 引用捕获在 check_lambda 入口预登记）。
   全局('@')/const(内联)/不可捕获类型返回 None 落普通路径 *)
and try_capture env name p' =
  match env.capctx with
  | None -> None
  | Some cc ->
    if String.contains name '.' || name = "err" then None
    else begin
      let skip = List.length env.scopes - cc.base in
      let rec go n = function
        | [] -> None
        | sc :: rest ->
          if n < skip then go (n + 1) rest
          else match Hashtbl.find_opt sc name with
               | Some l -> Some l
               | None -> go (n + 1) rest
      in
      match go 0 env.scopes with
      | Some l
        when not (String.length l.lslot > 0 && l.lslot.[0] = '@')
             && not l.lconst && cap_ty_ok l.lty ->
        (match Hashtbl.find_opt cc.caps name with
         | Some (idx, is_ref, ty, _) -> Some (cap_ref env idx is_ref ty p')
         | None ->
           let idx = Hashtbl.length cc.caps + 1 in
           Hashtbl.replace cc.caps name (idx, false, l.lty, p');
           Some (cap_ref env idx false l.lty p'))
      | _ -> None
    end

(* lambda 检查（v3.7）：ELambda 表达式与 SFn 嵌套函数共用。
   nmopt = Some 名（嵌套函数，实例名用其名）；产 EClNewK（h 句柄）。
   实例 tfn（env 参数 + 捕获改写后的 body）进 lambda_out_acc。
   v1 约定：lambda 参数必须显式类型；捕获字段限标量/string/bool/char/
   指针/句柄（seq/struct 捕获不支持）；env 堆块生命周期 = 进程。 *)
and check_lambda env (lam : lambda) (lp : pos) (nmopt : string option) =
  let mk k ty = { e = k; ety = ty; epos = lp } in
  let ptys =
    List.map
      (fun (prm : lparam) ->
        match prm.lpty with
        | Some t -> resolve (conv_ty env.g prm.lppos t)
        | None ->
          terr prm.lppos
            "lambda parameter '%s' needs an explicit type, e.g. fn(i32 x) => x * 2 (context inference is not supported yet)"
            prm.lpname)
      lam.lparams
  in
  List.iter
    (fun z ->
      if not (cap_ty_ok z) then
        terr lp "lambda parameter type %s is not supported (v1: scalar/string/pointer)"
          (pp_zty z))
    ptys;
  let ret0 =
    match lam.lbody with
    | LBlock (_, Some rt) -> Some (resolve (conv_ty env.g lp rt))
    | LBlock (_, None) -> assert false
    | LExpr _ -> None   (* 由体表达式类型决定 *)
  in
  (match ret0 with
   | Some r ->
     (match resolve r with
      | TVoid | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString -> ()
      | _ -> terr lp "lambda return type %s is not supported (v1: scalar/string/void)" (pp_zty r))
   | None -> ());
  incr lambda_cnt;
  let n = !lambda_cnt in
  let clenv_name = Printf.sprintf "clenv$%d" n in
  let fname =
    match nmopt with
    | Some nm -> Printf.sprintf "lambda$%s$%d" nm n
    | None -> Printf.sprintf "lambda$%d" n
  in
  let cc = { caps = Hashtbl.create 4; clenv = clenv_name;
             base = List.length env.scopes } in
  let saved_uses = env.uses in
  let saved_fnvars = env.fnvars in
  let saved_moved = env.moved in
  let saved_ret = env.fncur_ret in
  let saved_cap = env.capctx in
  let saved_ldepth = env.ldepth in
  let saved_slotn = env.slotn in
  let r =
    try
      env.fnvars <- Hashtbl.create 8;
      env.moved <- Hashtbl.create 8;
      env.uses <- [];
      env.ldepth <- 0;
      env.capctx <- Some cc;
      (* 显式引用捕获预登记（名字须为外层局部变量；字段序随登记序） *)
      List.iter
        (fun (is_ref, cn, cp) ->
          if Hashtbl.mem cc.caps cn then
            terr cp "capture '%s' listed twice" cn;
          let skip = List.length env.scopes - cc.base in
          let rec go k = function
            | [] ->
              terr cp "captured variable '%s' is not a local variable of the enclosing function" cn
            | sc :: rest ->
              if k < skip then go (k + 1) rest
              else match Hashtbl.find_opt sc cn with
                   | Some l -> l
                   | None -> go (k + 1) rest
          in
          let l = go 0 env.scopes in
          if String.length l.lslot > 0 && l.lslot.[0] = '@' then
            terr cp "cannot capture global '%s' by reference (globals are always accessible directly)" cn;
          if l.lconst then
            terr cp "cannot capture const '%s'" cn;
          if not (cap_ty_ok l.lty) then
            terr cp "captured variable '%s' has unsupported type %s" cn (pp_zty l.lty);
          let idx = Hashtbl.length cc.caps + 1 in
          Hashtbl.replace cc.caps cn (idx, is_ref, l.lty, cp))
        lam.lcaps;
      push_scope env;
      declare env "$env"
        { lconst = false; lty = TPtr (TStruct clenv_name); lslot = "";
          lunred = false; lconstp = false };
      let envslot =
        match lookup_var env "$env" with
        | Some l -> l.lslot | None -> assert false
      in
      let param_slots =
        List.map2
          (fun (prm : lparam) z ->
            declare env prm.lpname
              { lconst = false; lty = z; lslot = ""; lunred = false; lconstp = false };
            let slot =
              match lookup_var env prm.lpname with
              | Some l -> l.lslot | None -> assert false
            in
            (false, slot, z, false))
          lam.lparams ptys
      in
      let (tret, tbody) =
        match lam.lbody with
        | LExpr e ->
          let te = check_expr env e in
          let rt0 = resolve te.ety in
          (* 未求解 TVar（无期望上下文，如 fn(x) => x）：立即默认化，
             与收尾 subst_ty 同规则（含浮点字面量子树落 f64）——
             闭包 mangle 按此型生成，必须先于收尾定型 *)
          let rt =
            match rt0 with
            | TVar _ -> if floaty_texpr te then TFloat 64 else TInt 64
            | _ -> rt0
          in
          (* 尾表达式 → SReturnK（普通函数体同约定：SExprK 不产返回值）；
             void 尾表达式保留 SExprK（epilogue 产 ret void，避免
             TRet (Some void) 发射非法 IR `ret void 0`） *)
          (rt,
           if resolve rt = TVoid then [ { s = SExprK te; spos = lp } ]
           else [ { s = SReturnK (Some te); spos = lp } ])
        | LBlock (blk, Some _) ->
          env.fncur_ret <- (match ret0 with Some r -> r | None -> assert false);
          let tb = check_block env blk in
          (* 块尾表达式隐式返回：末条 SExprK 转 SReturnK（void 除外） *)
          let tb =
            match List.rev tb with
            | ({ s = SExprK te; _ } as last) :: rest
              when (match ret0 with Some r -> resolve r | None -> TVoid) <> TVoid ->
              List.rev_append rest [ { last with s = SReturnK (Some te) } ]
            | _ -> tb
          in
          ((match ret0 with Some r -> r | None -> assert false), tb)
      in
      pop_scope env;
      (* 缺 return 检查（非 void） *)
      (match ret0 with
       | Some r ->
         (match resolve r with
          | TVoid -> ()
          | _ ->
            let has_ret =
              List.exists (fun (st : tstmt) ->
                match st.s with
                | SReturnK _ -> true
                | SUnwrapBlockK (_, true, _, _, _, _, _) -> true
                | _ -> false) tbody
              ||
              (match List.rev tbody with
               | { s = SExprK _; _ } :: _ -> true
               | _ -> false)
            in
            if not has_ret then
              terr lp "lambda declares return type %s but may not return a value" (pp_zty r))
       | None -> ());
      env.capctx <- saved_cap;
      env.fncur_ret <- saved_ret;
      env.uses <- saved_uses;
      env.fnvars <- saved_fnvars;
      env.moved <- saved_moved;
      env.ldepth <- saved_ldepth;
      env.slotn <- saved_slotn;
      while List.length env.scopes > cc.base do pop_scope env done;
      (* 冻结捕获表 → 注册 clenv$N struct（字段 0 = code 头） *)
      let caps_list =
        List.sort
          (fun a b ->
            compare (let (i, _, _, _, _) = a in i) (let (i, _, _, _, _) = b in i))
          (Hashtbl.fold (fun cn (idx, is_ref, ty, cpos) acc ->
             (idx, cn, is_ref, ty, cpos) :: acc) cc.caps [])
      in
      let env_fields =
        [ ("code", TPtr (TUint 8)) ] @
        List.map (fun (_, cn, is_ref, ty, _) ->
            (cn, if is_ref then TPtr ty else ty)) caps_list
      in
      if not (Hashtbl.mem env.g.structs clenv_name) then
        Hashtbl.replace env.g.structs clenv_name
          { spacked = false;
            sfields = List.map (fun (fn2, ft) -> (fn2, ft, None)) env_fields };
      (* 组装 tfn 并登记 lambda 函数签名（首参 env 指针） *)
      let sig_params = TPtr (TStruct clenv_name) :: ptys in
      Hashtbl.replace env.g.fns fname
        { params = sig_params;
          prefs = List.map (fun _ -> false) sig_params;
          ret = tret; runred = false };
      let tf = { fname;
                 fparams = (false, envslot, TPtr (TStruct clenv_name), false) :: param_slots;
                 fret = tret; frunred = false; fbody = tbody } in
      lambda_out_acc := !lambda_out_acc @ [ tf ];
      (tret, ptys, fname, caps_list)
    with TypeError (p2, m2) ->
      env.capctx <- saved_cap;
      env.fncur_ret <- saved_ret;
      env.uses <- saved_uses;
      env.fnvars <- saved_fnvars;
      env.moved <- saved_moved;
      env.ldepth <- saved_ldepth;
      env.slotn <- saved_slotn;
      while List.length env.scopes > cc.base do pop_scope env done;
      raise (TypeError (p2, m2))
  in
  let (tret, ptys, code_name, caps_list) = r in
  let mangle = ensure_clo_struct env.g tret ptys in
  (* 堆块内容：首元素 code（函数名），其后捕获值——值捕获读槽，
     引用捕获取地址；深拷贝由 llvmgen MClNew 按类型完成 *)
  let code_op = mk (EFunPtrK code_name) (TPtr (TUint 8)) in
  let cap_ops =
    List.map
      (fun (_, cn, is_ref, _, cpos) ->
        let v = check_expr env (EVar (cn, cpos)) in
        if is_ref then
          { e = EAddrOfK v; ety = TPtr v.ety; epos = cpos }
        else v)
      caps_list
  in
  mk (EClNewK (mangle, clenv_name, code_op :: cap_ops)) (TStruct mangle)

(* 函数名 → 闭包句柄包装（v3.7）：wrapper（首参 env 丢弃，实参透传）进
   lambda_out_acc；产空捕获 EClNewK。槽名 $a0.. 与 fparams 手工一致 *)
and wrap_fn_as_clo env p fname (ptys : zty list) (ret : zty) =
  incr lambda_cnt;
  let n = !lambda_cnt in
  let clenv_name = Printf.sprintf "clenv$%d" n in
  let wname = Printf.sprintf "lambda$w_%s$%d" fname n in
  if not (Hashtbl.mem env.g.structs clenv_name) then
    Hashtbl.replace env.g.structs clenv_name
      { spacked = false; sfields = [ ("code", TPtr (TUint 8), None) ] };
  let sig_params = TPtr (TStruct clenv_name) :: ptys in
  Hashtbl.replace env.g.fns wname
    { params = sig_params; prefs = List.map (fun _ -> false) sig_params;
      ret; runred = false };
  let args =
    List.mapi (fun i t -> { e = EVarK (Printf.sprintf "$a%d" i); ety = t; epos = p })
      ptys
  in
  let tf = { fname = wname;
             fparams = (false, "$env", TPtr (TStruct clenv_name), false) ::
                        List.mapi (fun i t -> (false, Printf.sprintf "$a%d" i, t, false)) ptys;
             fret = ret; frunred = false;
             (* void 返回：尾调用保留 SExprK（SReturnK (Some void) 会发射
                非法 IR `ret void 0`；与 check_lambda LExpr 同约定） *)
             fbody = [ (if resolve ret = TVoid then
                          { s = SExprK { e = ECallK (fname, args, []); ety = ret; epos = p }; spos = p }
                        else
                          { s = SReturnK (Some { e = ECallK (fname, args, []); ety = ret; epos = p });
                            spos = p }) ] } in
  lambda_out_acc := !lambda_out_acc @ [ tf ];
  let mangle = ensure_clo_struct env.g ret ptys in
  { e = EClNewK (mangle, clenv_name,
                 [ { e = EFunPtrK wname; ety = TPtr (TUint 8); epos = p } ]);
    ety = TStruct mangle; epos = p }

and check_expr env (e : expr) : texpr =
  let p = pos_of_expr e in
  let mk k ty = { e = k; ety = ty; epos = p } in
  match e with
  | EInt (n, _) -> mk (EIntK n) (fresh_var ())
  | EBigInt (digits, _) ->
    (* 超出 i64 的大字面量（w-014 #6）：ety 未定（TVar），由期望上下文
       反绑到 i128/u128（coerce 校验范围）；其余上下文报错 *)
    mk (EBigK digits) (fresh_var ())
  | EFloat (f, _) -> mk (EFloatK f) (fresh_var ())
  | EStr (s, _) -> mk (EStrK s) TString
  | EChar (c, _) -> mk (ECharK c) TChar
  | EBool (b, _) -> mk (EBoolK b) TBool
  | EVar (name, p') ->
    let direct =
      match env.capctx with
      | Some cc ->
        (* lambda/嵌套函数体内（v3.7）：只搜内部作用域（cc.base 之上被
           push 的 skip 层）；外层变量走捕获或下方全量兜底，绝不能直接
           引用外层槽（lambda 是独立函数） *)
        let skip = List.length env.scopes - cc.base in
        let rec go k = function
          | [] -> None
          | sc :: rest ->
            if k >= skip then None
            else match Hashtbl.find_opt sc name with
                 | Some l -> Some l
                 | None -> go (k + 1) rest
        in
        go 0 env.scopes
      | None -> lookup_var env name
    in
    let norm l =
      if Hashtbl.mem env.moved l.lslot then
        terr p' "variable %s has been moved and cannot be used (reassign to revive it)" name;
      (* const 整数：使用处直接内联编译期值（含顶层 const） *)
      (match l.lty, Hashtbl.find_opt env.const_vals l.lslot with
       | (TInt _ | TUint _), Some v when l.lconst ->
         { e = EIntK v; ety = l.lty; epos = p' }
       | _ -> mk (EVarK l.lslot) l.lty)
    in
    (match direct with
     | Some l -> norm l
     | None ->
       (* lambda 体上下文（v3.7）：外层局部变量捕获改写（先于字段路径/
          函数名路径） *)
       (match try_capture env name p' with
        | Some te -> te
        | None ->
          (* 全量 lookup 兜底：全局('@')/const/顶层名（不可捕获，直接
             访问）——lambda 体同样可见 *)
          (match lookup_var env name with
           | Some l -> norm l
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
              | _ -> terr p' "%s" (undef_fix env p' name "variable")))
        | None ->
          (* 名字是函数（本文件/extern 声明）：引用为函数指针值 *)
          (match Hashtbl.find_opt env.g.fns name with
           | Some sig' ->
             mk (EFunPtrK name) (TPtr (TFunSig (sig'.params, sig'.ret)))
           | None -> terr p' "%s" (undef_fix env p' name "variable"))))))
  | EBin (op, l, r, p') ->
    let tl = check_expr env l in
    let tr = check_expr env r in
    let bop =
      match op with
      | Add -> BAdd | Sub -> BSub | Mul -> BMul | Div -> BDiv | Mod -> BMod
      | Eq -> BEq | Ne -> BNe | Lt -> BLt | Gt -> BGt | Le -> BLe | Ge -> BGe
      | And -> BAnd | Or -> BOr
      | BitAnd -> BBitAnd | BitOr -> BBitOr | Xor -> BBitXor
      | Shl -> BShl | Shr -> BShr | Pow -> BPow
    in
    if bop = BAnd || bop = BOr then begin
      (* 条件位走 coerce（v3.3.2）：延迟定型算术树（2**0）得正规错误，
         而非静默 unify 成 TBool 致 codegen E4025 *)
      ignore (coerce p' tl TBool);
      ignore (coerce p' tr TBool);
      mk (EBinK (bop, tl, tr)) TBool
    end
    else
      let rl = resolve tl.ety and rr = resolve tr.ety in
      (* poison 传播（n4）：任一侧含错子表达式 → 静默通过不再判定，
         比较结果 bool、其余保持 poison，杜绝连带噪声 *)
      if rl = TError || rr = TError then
        mk (EBinK (bop, tl, tr))
          (match bop with
           | BEq | BNe | BLt | BGt | BLe | BGe -> TBool
           | _ -> TError)
      else
      let isf = function TFrac _ -> true | _ -> false in
      (* 字符串拼接：+ 对 string 是拼接；char 侧提升单字符 string
         （v3.3.4：s + 'c' / 'c' + s，复用 to_string_of 的运行时格式化） *)
      if bop = BAdd && (rl = TString || rr = TString) then begin
        let tl, tr =
          match rl, rr with
          | TString, TString -> (tl, tr)
          | TString, TChar -> (tl, to_string_of tr)
          | TChar, TString -> (to_string_of tl, tr)
          | _ ->
            terr p' "string concatenation requires string or char operands, got %s and %s"
              (pp_zty rl) (pp_zty rr)
        in
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
      (* 位运算/移位（v3.2）：仅整数（char 提升为 i32）；& | xor 两侧宽化
         到公共宽度，移位结果取左操作数类型（移位量任意整数） *)
      else if (match bop with
               | BBitAnd | BBitOr | BBitXor | BShl | BShr -> true
               | _ -> false) then begin
        let is_bit_int = function
          | TInt _ | TUint _ | TChar | TVar _ -> true | _ -> false in
        if not (is_bit_int rl && is_bit_int rr) then
          terr p' "bitwise operations require integer operands, got %s and %s"
            (pp_zty rl) (pp_zty rr);
        let tl, tr =
          match rl, rr with
          | TChar, _ -> mk (ECastK (tl, TInt 32)) (TInt 32), tr
          | _, TChar -> tl, mk (ECastK (tr, TInt 32)) (TInt 32)
          | _ -> tl, tr
        in
        let res_ty =
          match bop with
          | BShl | BShr -> tl.ety
          | _ ->
            (match resolve tl.ety, resolve tr.ety with
             | (TInt _ | TUint _ as a), (TInt _ | TUint _ as b) when a <> b ->
               widen_target a b
             | _ -> tl.ety)
        in
        let tl = coerce p' tl res_ty and tr = coerce p' tr res_ty in
        mk (EBinK (bop, tl, tr)) res_ty
      end
      (* ** 幂（v3.3）：数学优先级（parser 层右结合）。类型规则：
         浮点参与 → f64（双侧均 f32 则 f32）走 libm pow/powf；
         整数 → 运行时快速幂 zfy_pow_ll/ull（≤64 位，负整数指数得 0，
         溢出回绕与其他整数运算一致）；128 位走 zfy_pow_u128/i128
         64 位对接口（v3.3.3）；char 提升 i32 *)
      else if bop = BPow then begin
        let is_int = function
          | TInt _ | TUint _ | TVar _ | TChar -> true | _ -> false in
        (* 子树是否含浮点字面量（未定型 TVar 的形态判别） *)
        let rec floaty e =
          match e with
          | EFloatK _ -> true
          | EUnK (_, u) -> floaty u.e
          | EBinK (_, x, y) -> floaty x.e || floaty y.e
          | _ -> false
        in
        let floaty_side t e =
          match resolve t with
          | TFloat _ -> true
          | TVar _ -> floaty e
          | _ -> false
        in
        if floaty_side rl tl.e || floaty_side rr tr.e then begin
          (* 浮点幂：任一侧是浮点或含浮点字面量的未定子树 → 整树按同宽
             浮点算（fix_texpr 会把未约束浮点字面量独立翻 f64，混合
             int/float 字面量树必须在此统一，否则 f64/i64 混算发坏 IR）。
             数学语义：2.0**10、2**0.5、x**0.5 均为浮点结果 *)
          let w =
            match resolve rl, resolve rr with
            | TFloat 32, (TFloat 32 | TVar _) | (TVar _), TFloat 32 -> 32
            | _ -> 64
          in
          let tof x =
            match resolve x.ety with
            | TFloat w0 when w0 = w -> x
            | TFloat _ -> mk (ECastK (x, TFloat w)) (TFloat w)
            | TVar _ -> coerce p' x (TFloat w)
            | TInt _ | TUint _ | TChar ->
              mk (ECastK (x, TFloat w)) (TFloat w)
            | _ ->
              terr p' "** requires numeric operands, got %s" (pp_zty x.ety)
          in
          let tl = tof tl and tr = tof tr in
          mk (EBinK (BPow, tl, tr)) (TFloat w)
        end
        else begin
          if not (is_int rl && is_int rr) then
            terr p' "** requires numeric operands, got %s and %s"
              (pp_zty rl) (pp_zty rr);
          (* char 数值化（与算术路径一致的 C 整数提升） *)
          let tl = if rl = TChar then mk (ECastK (tl, TInt 32)) (TInt 32) else tl in
          let tr = if rr = TChar then mk (ECastK (tr, TInt 32)) (TInt 32) else tr in
          let rl = if rl = TChar then TInt 32 else rl in
          let rr = if rr = TChar then TInt 32 else rr in
          (match rl, rr with
           | (TInt _ | TUint _ as a), (TInt _ | TUint _ as b) when a <> b ->
             (* v3.3.3：128 位支持；跨宽度用隐式宽化 cast（ECastK 免检，
                与通用算术一致——i32→u64 这类同宽异符提升不报 narrowing） *)
             let tgt = widen_target a b in
             let tl = mk (ECastK (tl, tgt)) tgt in
             let tr = mk (ECastK (tr, tgt)) tgt in
             mk (EBinK (BPow, tl, tr)) tgt
           | _ ->
             unify p' tl.ety tr.ety;
             let t = resolve tl.ety in
             mk (EBinK (BPow, tl, tr)) t)
        end
      end
      else
      (* char 数值化（w-014 #5）：算术运算中 char 与 char/整数混合 →
         双方提升为 i32（C 整数提升语义），结果 i32；
         比较仍要求同型（==/!= 同型 char 已支持） *)
      let is_char = function TChar -> true | _ -> false in
      let is_intish = function TInt _ | TUint _ | TVar _ -> true | _ -> false in
      let is_cmp = match bop with
        | BEq | BNe | BLt | BGt | BLe | BGe -> true | _ -> false in
      if (not is_cmp)
         && ((is_char rl && (is_char rr || is_intish rr))
          || (is_char rr && is_intish rl)) then begin
        let ti = TInt 32 in
        let tl = mk (ECastK (tl, ti)) ti in
        let tr = mk (ECastK (tr, ti)) ti in
        mk (EBinK (bop, tl, tr)) ti
      end
      (* 字符串比较（w-020 用户拍板）：string 与 string/char 可做全部六种
         比较；char 侧提升为单字符 string（ASCII），逐字符比到第一个
         不同字符即断（strcmp 语义，mir 侧 zfy_str_eq/ne/cmp） *)
      else if is_cmp
         && ((rl = TString && (rr = TString || rr = TChar))
          || (rr = TString && rl = TChar)) then begin
        let tl = if rl = TChar then to_string_of tl else tl in
        let tr = if rr = TChar then to_string_of tr else tr in
        mk (EBinK (bop, tl, tr)) TBool
      end
      else begin
        (* v3.3.1：含浮点字面量的未定子树（ety=TVar）与具体整数/char 混算
           → 报错。zfy 无 int→float 隐式转换；此前 unify 把浮点字面量
           静默绑成整数型，fix_texpr 再翻 f64 产 f64/i64 混算坏 IR
           （2.0 * x、2.5 < q） *)
        let floaty_side t x =
          match resolve t with
          | TFloat _ -> true
          | TVar _ -> floaty_texpr x
          | _ -> false
        in
        let other_int t =
          match t with TInt _ | TUint _ | TChar -> true | _ -> false in
        (if (floaty_side rl tl && other_int rr)
        || (floaty_side rr tr && other_int rl) then begin
          let show t x =
            match resolve t with
            | TVar _ when floaty_texpr x -> "f64"  (* 未定浮点字面量子树 *)
            | t -> pp_zty t
          in
          terr p' "floating-point and integer operands cannot be mixed without an explicit cast, got %s and %s"
            (show rl tl) (show rr tr)
        end);
        let res_ty =
          match bop with
          | BEq | BNe | BLt | BGt | BLe | BGe ->
            let ok =
              if is_numeric rl && is_numeric rr then true
              else if rl = rr && rl = TChar then true
              else
                (* ==/!= 额外支持同型 bool / string（内容比较）/ 泛型 T；
                   char 全部六种比较（v3.3.4：码点序，< <= > >= 新增） *)
                (match bop with
                 | BEq | BNe ->
                   rl = rr
                   && (match rl with
                       | TBool | TString | TVar _ -> true
                       | _ -> false)
                 | _ -> false)
            in
            if not ok then
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
      end
  | EUn (op, e1, p') ->
    let t1 = check_expr env e1 in
    (* poison：毒操作数静默通过（n4） *)
    if resolve t1.ety = TError then
      let uo = match op with Neg -> UNeg | Not -> UNot | BitNot -> UBitNot in
      mk (EUnK (uo, t1)) TError
    else
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
       (match resolve t1.ety with
        | TBool -> ()
        | TVar _ ->
          (* 延迟定型的算术/调用树（2**0、|3|）不可当 bool 用——
             直接 unify 会静默绑成 TBool 致 codegen E4025（同 coerce 守卫） *)
          (match t1.e with
           | EBinK _ | EUnK _ | ECallK _ ->
             terr p' "not requires a bool operand, got %s (wrap the comparison explicitly)"
               (pp_zty t1.ety)
           | _ -> unify p' t1.ety TBool)
        | _ -> unify p' t1.ety TBool);
       mk (EUnK (UNot, t1)) TBool
     | BitNot ->
       (* ~ 按位取反（v3.2）：仅整数/char（char 提升为 i32） *)
       let ti =
         match resolve t1.ety with
         | TChar -> Some (TInt 32)
         | TInt _ | TUint _ -> Some t1.ety
         | _ -> None
       in
       (match ti with
        | Some t ->
          let t1 = if t = t1.ety then t1 else mk (ECastK (t1, t)) t in
          mk (EUnK (UBitNot, t1)) t
        | None ->
          terr p' "bitwise not (~) requires an integer type, got %s" (pp_zty t1.ety);
          mk (EUnK (UBitNot, t1)) t1.ety))
  | ECall (callee, args, p') ->
    (match callee with
     | EVar (name, np) ->
       (match name with
        | "length" | "find" | "trim" | "split" | "replace" | "prec"
        | "utf8_len" | "utf8_char_at" | "utf8_sub" ->
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
              | None -> terr fp "%s" (undef_fix env fp fname "function"))
           | _ -> terr p' "panic_handler expects a function name argument: panic_handler(fn)")
        | "open" ->
          (* open(path, mode) -> File!（design_fileio.md）：失败产 ErrCode.IO
             错误值；mode 字面量编译期校验（r/w/a），变量实参运行期校验 *)
          (match args with
           | [ CPos path; CPos mode ] ->
             let tp = check_expr env path in
             (match resolve tp.ety with
              | TString -> ()
              | t -> terr p' "open's path must be a string, got %s" (pp_zty t));
             let tm = check_expr env mode in
             (match resolve tm.ety with
              | TString -> ()
              | t -> terr p' "open's mode must be a string, got %s" (pp_zty t));
             (match tm.e, resolve tm.ety with
              | EStrK m, TString ->
                if not (List.mem m [ "r"; "w"; "a" ]) then
                  terr p' "invalid open mode \"%s\" (expected \"r\", \"w\" or \"a\")" m
              | _ -> ());
             mk (ECallK ("zfy_file_open_err", [ tp; tm ], [])) (TErr TFile)
           | _ -> terr p' "open takes two arguments: open(path, mode)")
        | "read_all" | "read_line" ->
          (* read_all(f) / read_line(f) -> string!：IO 错误产 ErrCode.IO，
             read_line 的文件结束产 ErrCode.EOF *)
          (match args with
           | [ CPos f ] ->
             let tf = check_expr env f in
             (match resolve tf.ety with
              | TFile -> ()
              | t -> terr p' "%s expects a File, got %s" name (pp_zty t));
             mk (ECallK ((if name = "read_all" then "zfy_file_read_all_err"
                          else "zfy_file_read_line_err"), [ tf ], []))
               (TErr TString)
           | _ -> terr p' "%s takes one argument: %s(f)" name name)
        | "read_lines" ->
          (* read_lines(f) -> string[]：读全部行（去行尾换行），EOF 正常结束；
             IO 错误 panic（与 write/close 一致，design_fileio.md 第二阶段）。
             结果为运行时新分配 seq：ECallK 临时所有权由 mir 登记接管 *)
          (match args with
           | [ CPos f ] ->
             let tf = check_expr env f in
             (match resolve tf.ety with
              | TFile -> ()
              | t -> terr p' "read_lines expects a File, got %s" (pp_zty t));
             mk (ECallK ("zfy_file_read_lines", [ tf ], [])) (TList TString)
           | _ -> terr p' "read_lines takes one argument: read_lines(f)")
        | "write" | "writeln" ->
          (* write(f, s) / writeln(f, s)：写失败 panic（不产 T!，design_fileio.md）；
             writeln = write + '\n'（nl 标志） *)
          (match args with
           | [ CPos f; CPos s ] ->
             let tf = check_expr env f in
             (match resolve tf.ety with
              | TFile -> ()
              | t -> terr p' "%s expects a File as first argument, got %s" name (pp_zty t));
             let ts = to_string_of (check_expr env s) in
             let nl = { e = EIntK (if name = "writeln" then 1L else 0L);
                        ety = TInt 32; epos = p' } in
             mk (ECallK ("zfy_file_write", [ tf; ts; nl ], [])) TVoid
           | _ -> terr p' "%s takes two arguments: %s(f, s)" name name)
        | "close" ->
          (* close(f)：幂等；close 失败 / 使用已关闭句柄 → panic *)
          (match args with
           | [ CPos f ] ->
             let tf = check_expr env f in
             (match resolve tf.ety with
              | TFile -> ()
              | t -> terr p' "close expects a File, got %s" (pp_zty t));
             mk (ECallK ("zfy_file_close", [ tf ], [])) TVoid
           | _ -> terr p' "close takes one argument: close(f)")
        | "exists" ->
          (* exists(path) -> bool：文件是否存在 *)
          (match args with
           | [ CPos path ] ->
             let tp = check_expr env path in
             (match resolve tp.ety with
              | TString -> ()
              | t -> terr p' "exists expects a string path, got %s" (pp_zty t));
             mk (ECallK ("zfy_file_exists", [ tp ], [])) TBool
           | _ -> terr p' "exists takes one argument: exists(path)")
        | "read_file" ->
          (* read_file(path) -> string!：一步式整读（open+read_all+close） *)
          (match args with
           | [ CPos path ] ->
             let tp = check_expr env path in
             (match resolve tp.ety with
              | TString -> ()
              | t -> terr p' "read_file expects a string path, got %s" (pp_zty t));
             mk (ECallK ("zfy_file_read_file_err", [ tp ], [])) (TErr TString)
           | _ -> terr p' "read_file takes one argument: read_file(path)")
        | "write_file" ->
          (* write_file(path, s) -> i64!：一步式覆盖写，成功返回写入字节数 *)
          (match args with
           | [ CPos path; CPos s ] ->
             let tp = check_expr env path in
             (match resolve tp.ety with
              | TString -> ()
              | t -> terr p' "write_file's path must be a string, got %s" (pp_zty t));
             let ts = to_string_of (check_expr env s) in
             mk (ECallK ("zfy_file_write_file_err", [ tp; ts ], [])) (TErr (TInt 64))
           | _ -> terr p' "write_file takes two arguments: write_file(path, s)")
        | "ord" ->
          (* ord(c)：char 的码值（i32），w-014 #5 *)
          (match args with
           | [ CPos e ] ->
             let tc = check_expr env e in
             (match resolve tc.ety with
              | TChar -> mk (ECastK (tc, TInt 32)) (TInt 32)
              | t -> terr p' "ord expects a char, got %s" (pp_zty t))
           | _ -> terr p' "ord takes one argument: ord(c)")
        | "chr" ->
          (* chr(n)：码值转 char（w-014 #5） *)
          (match args with
           | [ CPos e ] ->
             let tn = to_i64 (check_expr env e) in
             mk (ECastK (tn, TChar)) TChar
           | _ -> terr p' "chr takes one argument: chr(n)")
        | "push" ->
          (* push(列表, 值)：追加到末尾（自动扩长），返回列表本身
             （v3 2026-10-11 表达式化：xs = push(xs, v)；裸语句由 SExpr 拒绝）。
             目标槽根泛化（w-014 #3）：变量/字段链（bag.xs）/ref 参数
             解引用/嵌套元素槽（push(a[i], v)——内层列表为真实槽） *)
          (match args with
           | [ CPos b; CPos v ] ->
             let root = seq_slot_root env b "push target" in
             (match resolve root.ety with
              | TList e | TPtr (TList e) ->
                let tv0 = coerce p' (check_expr env v) e in
                (* 返回列表本身（指针根解引用：push(a[i], v) 返回 a[i] 的列表值） *)
                mk (EPushK (root, { tv0 with ety = resolve e }))
                  (match resolve root.ety with
                   | TPtr t -> t
                   | t -> t)
              | TArray _ | TPtr (TArray _) ->
                terr p' "push target must be a list, not a fixed-length array"
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
           | None when Hashtbl.mem env.g.gstructs name ->
             (* 泛型 struct 构造：推断类型实参后按实例构造（new2.md 第2条） *)
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
              | Some l when (match resolve l.lty with
                             | TStruct s -> is_clo_struct s | _ -> false) ->
               (* 局部闭包调用（v3.7）：cb(args) = call code(env=&cb, args) *)
               let (ptys, ret) = clo_sig env.g (match resolve l.lty with TStruct s -> s | _ -> assert false) p' in
               if List.length ptys <> List.length args then
                 terr p' "closure expects %d arguments, got %d"
                   (List.length ptys) (List.length args);
               let targs =
                 List.map2
                   (fun (ca : call_arg) pt ->
                     match ca with
                     | CPos e -> coerce p' (check_expr env e) pt
                     | CCopy e -> coerce p' (check_expr env e) pt
                     | CMove _ -> terr p' "closure calls do not support move arguments"
                     | CRef _ -> terr p' "closure calls do not support ref arguments"
                     | CNamed (n, _) -> terr p' "closure calls do not support named argument %s=" n)
                   args ptys
               in
               let tcl = { e = EVarK l.lslot; ety = l.lty; epos = p' } in
               mk (EClCallK (tcl, targs)) ret
              | _ ->
               (* 字段链 callee（h.op(...)，new2.md 9a）：根为局部变量且
                  字段链为函数指针时间接调用；否则按普通函数调用处理
                  （模块扁平化后的点名 math.add 走 check_call）。
                  v3.2：dotted 末端命中 struct 方法表 → 方法调用脱糖 *)
               let mres =
                 match split_field_path name with
                 | Some (first, _ :: _) ->
                   (match lookup_var env first with
                    | Some _ -> try_method env name p' args
                    | None -> None)
                 | _ -> None
               in
               (match mres with
                | Some te -> te
                | None ->
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
                           let (targs, origs, modes) = check_args_modes env args in
                           check_call env p' np name targs origs modes)
                      | None ->
                        (* 普通函数调用：走统一实参分派（自动 move/copy/ref） *)
                        let (targs, origs, modes) = check_args_modes env args in
                        check_call env p' np name targs origs modes)
                   | None ->
                     (* 普通函数调用：走统一实参分派（自动 move/copy/ref） *)
                     let (targs, origs, modes) = check_args_modes env args in
                     check_call env p' np name targs origs modes)))))
     | EField (b, seg, pp) ->
       (* 元素/表达式接收者的方法调用（v3.3.8）：arr[i].m(...) / a.b[i].m(...)。
          基为 struct（或 struct 指针）且 seg 命中方法表 → 脱糖为
          <S>__m(ref recv, args)（接收者按引用传：值 struct 走 CRef 取
          元素地址，指针接收者直接传指针值）；否则维持 unsupported callee *)
       let tb = check_expr env b in
       (match resolve tb.ety with
        | TStruct s ->
          (match Hashtbl.find_opt method_tbl (s, seg) with
           | Some gname ->
             check_expr env (ECall (EVar (gname, pp), CRef b :: args, pp))
           | None -> terr pp "unsupported callee expression")
        | TPtr (TStruct s) ->
          (match Hashtbl.find_opt method_tbl (s, seg) with
           | Some gname ->
             check_expr env (ECall (EVar (gname, pp), CPos b :: args, pp))
           | None -> terr pp "unsupported callee expression")
        | _ -> terr pp "unsupported callee expression")
     | ELambda (lam, lp) ->
       (* lambda 立即调用（v3.7）：fn(x) => e(args) = (闭包)(args) *)
       let tcl = check_lambda env lam lp None in
       (match resolve tcl.ety with
        | TStruct s when is_clo_struct s ->
          let (ptys, ret) = clo_sig env.g s p' in
          if List.length ptys <> List.length args then
            terr p' "closure expects %d arguments, got %d"
              (List.length ptys) (List.length args);
          let targs =
            List.map2
              (fun (ca : call_arg) pt ->
                match ca with
                | CPos e -> coerce p' (check_expr env e) pt
                | CCopy e -> coerce p' (check_expr env e) pt
                | CMove _ -> terr p' "closure calls do not support move arguments"
                | CRef _ -> terr p' "closure calls do not support ref arguments"
                | CNamed (n, _) -> terr p' "closure calls do not support named argument %s=" n)
              args ptys
          in
          mk (EClCallK (tcl, targs)) ret
        | _ -> terr p' "unsupported callee expression")
     | _ -> terr p' "unsupported callee expression")
  | EIndex (base, idx, p') ->
    let tb = check_expr env base in
    (* map 读：m[k] 产 V!（缺失 = NOT_FOUND），须 ?? 解包后使用（v3.6） *)
    (match resolve tb.ety with
     | TStruct s when is_map_struct s ->
       let marg = map_self_arg env p' tb in
       (match cont_kv env.g s p' with
        | (kt, Some vt) ->
          ignore kt;
          let tidx = check_expr env idx in
          let (kf, karg) = map_key_arg env p' tidx in
          let vtag = map_vtag p' vt in
          mk (ECallK (Printf.sprintf "zfy_map_get_err_%s_%s" kf vtag,
                      [ marg; karg ], [])) (TErr vt)
        | (_, None) ->
          terr p' "set does not support index read (use contains(s, x) / set_has)")
     | _ ->
    let ti = to_i64 (check_expr env idx) in
    (* poison：毒底数/毒下标静默通过（n4） *)
    if resolve tb.ety = TError then mk (ESeqGetK (tb, ti)) TError
    else
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
     | t -> terr p' "type %s does not support index access" (pp_zty t)))
  | ESlice (base, a, b, step, p') ->
    let tb = check_expr env base in
    (match resolve tb.ety with
     | TString ->
       (* string 切片：返回新串（两端含，步长默认 1）。
          字面量/常量步长 ≤ 0 编译期拒绝（w-020：与 find count 同款检查；
          变量步长仍由运行时 panic 兜底） *)
       let ta = to_i64 (check_expr env a) and tb' = to_i64 (check_expr env b) in
       let ts =
         match step with
         | None -> { e = EIntK 1L; ety = TInt 64; epos = p' }
         | Some s ->
           let ts = to_i64 (check_expr env s) in
           (match const_eval env ts with
            | Some v when Int64.equal v 0L ->
              terr p' "slice step must not be 0, got %Ld" v
            | _ -> ());
           ts
       in
       mk (ECallK ("zfy_str_slice", [ tb; ta; tb'; ts ], [])) TString
     | TArray (e, _) | TList e ->
       (* 数组/列表切片：返回同元素类型的动态序列（可赋给数组或列表变量） *)
       let ta = to_i64 (check_expr env a) and tb' = to_i64 (check_expr env b) in
       let ts =
         match step with
         | None -> { e = EIntK 1L; ety = TInt 64; epos = p' }
         | Some s ->
           let ts = to_i64 (check_expr env s) in
           (match const_eval env ts with
            | Some v when Int64.equal v 0L ->
              terr p' "slice step must not be 0, got %Ld" v
            | _ -> ());
           ts
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
    (* cast(e, frac)（v3 2026-10-11）：整数/bool/char → 分数 n/1（不失败，
       不产错误值）；float 字面量按二进制精确值转分数（0.5→1/2）；运行期
       float 值与 frac 跨宽不支持 *)
    (match b with
     | TFrac elem ->
       let tv =
         match t1.e, resolve a with
         | EFloatK v, (TFloat _ | TVar _) ->
           (* 浮点字面量（含 TVar 未定型）：按二进制精确值转分数（0.5→1/2） *)
           frac_of_float_lit v elem p'
         | _, TFloat _ ->
           terr p'
             "cannot cast a non-literal float to frac (floats have no exact fraction form; write n/d or use a frac literal)"
         | _, TFrac e2 ->
           if resolve e2 <> resolve elem then
             terr p' "cast between frac widths is not supported: %s -> %s"
               (pp_zty a) (pp_zty b);
           t1
         | _, t when num t -> mk_frac_from t1 elem p'
         | _, t ->
           terr p' "unsupported cast: %s -> %s (int/bool/char/float-literal -> frac only)"
             (pp_zty t) (pp_zty b)
       in
       { e = tv.e; ety = TFrac elem; epos = p' }
     | _ ->
       if not ok then
         terr p' "unsupported cast: %s -> %s"
           (pp_zty a) (pp_zty b);
       (* string -> 数值：运行时解析可能失败，结果为 T!（错误值）；
          128 位整数目标同样产错误值（32 字节宽容器，new.md 2026-10-11 用户
          拍板）；f128 无 T! 包装，保持 fail-fast 语义 *)
       let wide128 = match b with TFloat 128 -> true | _ -> false in
       if a = TString && b <> TString && num b && not wide128 then
         mk (ECastK (t1, t')) (TErr t')
       else mk (ECastK (t1, t')) t')
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
     | EPanic _ as prhs ->
       (* a ?? panic(...)：失败即终止（panic 永不产生值，类型取 elem） *)
       let tb = check_expr env prhs in
       mk (EUnwrapK (ta, tb)) elem
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
  | ERemove (b, i, p') ->
    (* remove(数组/列表, 下标)：表达式（v3 2026-10-11），返回被删元素
       （深拷贝副本）。数组=槽位填零（长度不变）；列表=删除并左移（长度-1）。
       槽根泛化同 push：变量/字段链/ref 解引用/元素槽 *)
    let root = seq_slot_root env b "remove target" in
    (match resolve root.ety with
     | TArray (e, _) | TList e | TPtr (TArray (e, _)) | TPtr (TList e) as seqty ->
       let ti = to_i64 (check_expr env i) in
       let isl = (match seqty with TList _ | TPtr (TList _) -> true | _ -> false) in
       mk (ERemoveK (root, ti, isl)) e
     | t -> terr p' "remove only works on arrays/lists, got %s" (pp_zty t))
  | ELambda (lam, lp) ->
    (* lambda（v3.7）：检查体 + 实例函数收集 + 产闭包句柄构造 *)
    check_lambda env lam lp None

(* 方法调用尝试（v3.2 随机数模块）：dotted 名 a.b.m(...)，末端 m 命中
   接收者 struct 的方法表 → 改写为脱糖函数调用 <S>__m(ref recv, args)。
   未命中（普通字段链/函数指针字段/模块函数）返回 None 走原路径 *)
and try_method env name p' args =
  match split_field_path name with
  | Some (first, segs) when segs <> [] ->
    let mname = List.hd (List.rev segs) in
    let front = String.concat "." (first :: List.rev (List.tl (List.rev segs))) in
    (match lookup_var env front with
     | Some l ->
       (match resolve l.lty with
        | TStruct s | TPtr (TStruct s) ->
          (match Hashtbl.find_opt method_tbl (s, mname) with
           | Some gname ->
             if l.lconst then
               terr p' "cannot call method %s on const value %s (methods may mutate the receiver)"
                 mname front;
             (* self 按引用传：TPtr 接收者直接传指针值，TStruct 传槽地址 *)
             let rarg =
               match resolve l.lty with
               | TPtr _ -> CPos (EVar (front, p'))
               | _ -> CRef (EVar (front, p'))
             in
             Some (check_expr env (ECall (EVar (gname, p'), rarg :: args, p')))
           | None -> None)
        | _ -> None)
     | None -> None)
  | _ -> None

and check_call env p np name0 targs origs modes =
  let name = ref name0 in
  let sig_ =
    match container_call env p name0 targs with
    | Some (n2, s2) -> name := n2; s2
    | None ->
    if name0 = "abs" then begin
      (* abs 重载（v3.2）：整数→同宽整数（llvmgen 内联 sub+select），
         浮点→同宽浮点（llvmgen 走 @fabs/@fabsf）；其余类型报错。
         纯字面量实参树（ety=TVar）延迟定型（v3.3.2，与 BPow 字面量树
         同机制）：实参自身的 TVar 直接作 sig 参数/返回——调用结果与
         实参树共享同一 TVar，由外层 coerce（声明/赋值/实参/return 的
         目标型）统一求解，无约束时 fix 阶段按默认型收口。此前
         lit_default 提前定 i64/f64，|3| 落 i32 期望报 E3155 窄化、
         |2.5| 落 f32 期望报 E3005——期望无法传播进调用 *)
      match targs with
      | [ a ] ->
        (match resolve a.ety with
         | (TInt _ | TUint _ | TFloat _) as t ->
           { params = [ t ]; prefs = [ false ]; ret = t; runred = false }
         | TVar _ ->
           { params = [ a.ety ]; prefs = [ false ]; ret = a.ety; runred = false }
         | _ ->
           terr p "abs expects an integer or float argument, got %s" (pp_zty (resolve a.ety)))
      | _ -> terr p "abs expects exactly 1 argument"
    end
    else
    match List.assoc_opt name0 builtin_fns_aux with
    | Some (ptys, ret) -> { params = ptys; prefs = List.map (fun _ -> false) ptys; ret; runred = false }
    | None ->
      (match Hashtbl.find_opt env.g.fns name0 with
       | Some s -> s
       | None ->
         if Hashtbl.mem env.g.gfns name0 then begin
           (* 泛型函数：按实参类型推断实例化，再按普通函数调用（new2.md 第2条）；
              调用目标用 mangled 名（first$i32 等）落 ECallK *)
           let mangled = !generic_call_hook env name0 targs p in
           name := mangled;
           Hashtbl.find env.g.fns mangled
         end else terr np "%s" (undef_fix env np name0 "function"))
  in  if List.length sig_.params <> List.length targs then
    terr p "function %s expects %d arguments, got %d"
      !name (List.length sig_.params) (List.length targs);
  (* ref 参数/实参匹配（new2.md #1）：ref 参数必须 f(ref x)，反之亦然。
     例外（v3.2 struct 方法）：实参本身已是同型指针（方法内 self 转发）时
     CPos 值传等价于传地址，放行 *)
  List.iteri
    (fun i m ->
      let pref = try List.nth sig_.prefs i with _ -> false in
      if m = 2 && not pref then
        terr p "argument %d of %s is passed by ref, but the parameter is not declared ref" (i + 1) !name
      else if pref && m <> 2 then begin
        let already_ptr =
          match m, (try List.nth origs i with _ -> None) with
          | 0, Some (EVar (n, _)) ->
            (match lookup_var env n with
             | Some l ->
               (match resolve l.lty with
                | TPtr _ ->
                  (match try List.nth sig_.params i with _ -> TVoid with
                   | TPtr _ -> true | _ -> false)
                | _ -> false)
             | None -> false)
          | _ -> false
        in
        if not already_ptr then
          terr p "parameter %d of %s is ref, pass the argument with ref (f(ref x))" (i + 1) !name
      end)
    modes;
  (* File 参数 move-only（design_fileio.md）：只能 f(move f) 所有权移交；
     值传/copy/ref 一律报错（句柄共享会破坏"谁持有谁关闭"约定） *)
  List.iteri
    (fun i pt ->
      if resolve pt = TFile then
        let m = try List.nth modes i with _ -> 0 in
        if m <> 1 then
          terr p "File parameters are move-only: pass with %s(move x)" !name)
    sig_.params;
  let targs =
    List.map2
      (fun ta (pt, orig) ->
        match resolve pt, orig with
        | TFrac w, Some rhs when is_frac_arith rhs ->
          (* frac 参数位置含 / 的算术实参（new.md 2026-10-11）：整棵按分数算
             （n/d 字面量形式仍按分数构造，与既有语义一致） *)
          check_frac_expr env rhs w
        | TStruct ps, Some (EVar (fn, fp))
          when is_clo_struct ps && (match ta.e with EFunPtrK _ -> true | _ -> false) ->
          (* 函数名 → 闭包句柄（v3.7）：谓词/比较器/归并参数接受裸函数名，
             经 wrapper 包装（首参 env 丢弃，实参透传） *)
          let (cptys, cret) = clo_sig env.g ps p in
          (match resolve ta.ety with
           | TPtr (TFunSig (fps, fret)) when fps = cptys && fret = cret ->
             wrap_fn_as_clo env fp fn cptys cret
           | TPtr (TFunSig (fps, fret)) ->
             terr fp "function %s signature (%s) -> %s does not match the expected closure (%s) -> %s"
               fn (String.concat ", " (List.map pp_zty fps)) (pp_zty fret)
               (String.concat ", " (List.map pp_zty cptys)) (pp_zty cret)
           | _ -> coerce p ta pt)
        | _ -> coerce p ta pt)
      targs
      (List.combine sig_.params origs)
  in
  let moves = List.map (fun m -> m = 1) modes in
  { e = ECallK (time_rt_name !name, targs, moves); ety = sig_.ret; epos = p }

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
        | TString | TArray _ | TList _ | TFile ->
          (* 先按普通读检查实参（此时尚未标记 moved），再标记已 move *)
          let te = check_expr env e in
          Hashtbl.replace env.moved l.lslot ();
          te
        | t ->
          terr p "move supports only string/array/list/File arguments, %s has type %s"
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
  | EInt _ | EBigInt _ | EFloat _ | EStr _ | EChar _ | EBool _ | ENull _ -> acc
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
  | ERemove (b, i, _) -> uses_of_expr (uses_of_expr acc b) i
  | ELambda (lam, _) ->
    (* lambda 体独立成函数（不走本函数 move 分析），捕获登记在
       check_lambda 内完成；此处跳过体，仅避免匹配失败 *)
    ignore lam;
    acc

and uses_of_stmt (acc : (string * pos) list) (s : stmt) : (string * pos) list =
  match s with
  | SDecl (_, _, _, _, _, init, _) ->
    (match init with Some e -> uses_of_expr acc e | None -> acc)
  | SSeqDecl (_, _, _, _, _, len, _, inits, _) ->
    let acc = (match len with Some e -> uses_of_expr acc e | None -> acc) in
    List.fold_left uses_of_expr acc inits
  | SDeclList ss -> List.fold_left uses_of_stmt acc ss
  | SAssign (a, b, _) -> uses_of_expr (uses_of_expr acc a) b
  | SForIn (_, sx, b, _) ->
    List.fold_left uses_of_stmt (uses_of_expr acc sx) b
  | SAssignList (a, bs, _) ->
    List.fold_left uses_of_expr (uses_of_expr acc a) bs
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
          | FIDecl (_, _, _, _, _, e, _) ->
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
  | SBreak _ | SContinue _ -> acc
  | SUnsafe (blk, _) -> List.fold_left uses_of_stmt acc blk
  (* 嵌套函数体在自身作用域内检查；捕获不触发外层 auto move *)
  | SFn _ -> acc

(* 变量 n 在位置 p 之后是否不再出现（最后使用判定，保守） *)
and last_use env n (p : pos) =
  not (List.exists (fun (m, q) -> m = n && pos_after q p) env.uses)

(* 自动 move 候选：聚合类型（string/数组/列表）局部非 const 变量、
   未被 move 过、且此后不再出现。
   循环门禁（new.md 2026-10-11 bug 报告；2026-10-16 扩展到循环条件/update）：
   last_use 按源码位置判"之后"，而循环条件/循环体内的使用每次运行期迭代
   都执行——把循环内的使用点判成"最后使用"并 move（store null 清槽）后，
   下一轮迭代读到 null 崩溃（静态位置相同，pos_after 不成立）。
   故循环体、while/for 条件、for update（任意深度）内的实参/赋值
   一律不自动 move，走克隆 *)
and auto_moveable env n (p : pos) =
  env.ldepth = 0
  && (match lookup_var env n with
      | Some l ->
        (not l.lconst) && l.lslot.[0] <> '@'
        && (match resolve l.lty with
            | TString | TArray _ | TList _ -> true | _ -> false)
        && not (Hashtbl.mem env.moved l.lslot)
        && last_use env n p
      | None -> false)

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
    (* v3.3.8：字段链/元素等可定位表达式也可 ref（元素方法调用的接收者，
       如 self.buttons[i].hit(...) 的接收者取元素地址） *)
    let rec locatable (x : expr) =
      match x with
      | EVar _ -> true
      | EField (bx, _, _) -> locatable bx
      | EIndex (bx, _, _) -> locatable bx
      | EDeref (bx, _) -> locatable bx
      | _ -> false
    in
    if not (locatable e) then
      terr (pos_of_expr e)
        "ref can only apply to a variable/field/element (pass-by-reference needs an addressable location)";
    check_expr env (EAddrOf (e, pos_of_expr e))

(* 实参列表 → (类型化实参, 模式列表)：0=值 1=move（含自动 move） 2=ref 3=copy *)
and check_args_modes env (args : call_arg list) : texpr list * expr option list * int list =
  let triples =
    List.map
    (function
      | CPos e ->
        (match e with
         | EVar (n, p) when auto_moveable env n p ->
           (* 自动 move（new2.md #1：最后使用即 move）——免拷贝移交 *)
           (check_move_arg env e, None, 1)
         | _ -> (check_expr env e, Some e, 0))
      | CMove e -> (check_move_arg env e, None, 1)
      | CCopy e -> (check_copy_arg env e, None, 3)
      | CRef e -> (check_ref_arg env e, None, 2)
      | CNamed (n, e) ->
        terr (pos_of_expr e) "function calls do not support named argument %s=" n)
    args
  in
  (List.map (fun (a, _, _) -> a) triples,
   List.map (fun (_, b, _) -> b) triples,
   List.map (fun (_, _, c) -> c) triples)

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
    | ERemove (b, i, p) -> ERemove (re b, re i, p)
    (* 不会出现在普通 fn 参数体中，保守原样透传 *)
    | EBigInt _ -> e
    | ELambda _ -> e
  (* 赋值类左值：EVar ∈ refs → EDeref（解引用写） *)
  and lhs (e : expr) : expr =
    match e with
    | EVar (n, p) when in_refs n -> EDeref (EVar (n, p), p)
    | e2 -> re e2
  and rs (s : stmt) : stmt =
    match s with
    | SAssign (l, r, p) -> SAssign (lhs l, re r, p)
    | SAssignList (l, rl, p) -> SAssignList (lhs l, List.map re rl, p)
    | SAug (o, l, r, p) -> SAug (o, lhs l, re r, p)
    | SInc (l, p) -> SInc (lhs l, p)
    | SDec (l, p) -> SDec (lhs l, p)
    | SDecl (c, f, u, n, t, init, p) ->
      (* deref_refs 不改类型（仅解引用改写），ty option 原样透传 *)
      SDecl (c, f, u, n, t, (match init with Some e -> Some (re e) | None -> None), p)
    | SSeqDecl (c, f2, u2, n, t, len, isl, inits, p) ->
      SSeqDecl (c, f2, u2, n, t, (match len with Some e -> Some (re e) | None -> None), isl,
                List.map re inits, p)
    | SDeclList ss -> SDeclList (List.map rs ss)
    | SExpr e -> SExpr (re e)
    | SReturn (e, p) -> SReturn ((match e with Some e -> Some (re e) | None -> None), p)
    | SIf (c, a, b, p) ->
      SIf (re c, List.map rs a,
           (match b with Some b -> Some (List.map rs b) | None -> None), p)
    | SWhile (c, b, p) -> SWhile (re c, List.map rs b, p)
    | SFor (inits, c, ups, b, p) ->
      SFor (List.map
              (function
                | FIDecl (ic, f2, u2, n2, t, e, fp) ->
                  FIDecl (ic, f2, u2, n2, t,
                          (match e with Some e -> Some (re e) | None -> None), fp)
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
    | SUnsafe (blk, p) -> SUnsafe (List.map rs blk, p)
    | SBreak _ | SContinue _ -> s
    | SForIn _ | SFn _ -> s
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
       | t ->
         if List.mem seg str_builtin_names then
           terr p "type %s does not support field access %s (string builtins are functional: %s(s, ...))"
             (pp_zty t) seg seg
         else terr p "type %s does not support field access %s" (pp_zty t) seg)
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
     | t ->
       if List.mem seg str_builtin_names then
         terr p "type %s does not support field access %s (string builtins are functional: %s(s, ...))"
           (pp_zty t) seg seg
       else terr p "type %s does not support field access %s" (pp_zty t) seg)

(* 可写 seq 槽根（w-014 #3）：把写目标（元素写/push/整体赋值）的基表达式
   求值为"持有 seq 指针的槽"形态 texpr：
   - EVarK 槽（变量）
   - EFieldK 链（dotted 字段，根为 EVarK；const 根拒绝写）
   - EDerefK（ref 参数解引用：槽地址 = 指针值）
   - EAddrOfK (ESeqGetK _)（元素槽地址：嵌套写 a[i][j] / push(a[i], v)）
   其余形态（整体为副本的表达式等）报错 *)
and seq_slot_root env (base : expr) (what : string) : texpr =
  match base with
  | EVar (name, p') ->
    (match lookup_var env name with
     | Some l ->
       if l.lconst then
         terr p' "cannot modify %s of constant %s (const is deeply immutable)" what name;
       if Hashtbl.mem env.moved l.lslot then
         terr p' "%s has been moved and cannot be written" name;
       { e = EVarK l.lslot; ety = l.lty; epos = p' }
     | None ->
       (* dotted 字段链（bag.xs）：const 根不可变检查后走读路径求值 *)
       (match split_field_path name with
        | Some (first, _) ->
          (match lookup_var env first with
           | Some l when l.lconst ->
             terr p' "cannot modify %s of constant %s (const is deeply immutable)" what first
           | _ -> ())
        | None -> ());
       let tb = check_expr env base in
       (match tb.e with
        | EFieldK _ | EDerefK _ -> tb
        | _ ->
          terr (pos_of_expr base) "%s must be a list variable or field" what;
          tb))
  | _ ->
    (match base with
     | EIndex (EVar (arr, ap), _, _) ->
       (* 元素槽地址路径：外层 const 数组深不可变 *)
       (match lookup_var env arr with
        | Some l when l.lconst ->
          terr ap "cannot modify elements of constant %s (const is deeply immutable)" arr
        | _ -> ())
     | _ -> ());
    let tb = check_expr env base in
    (match tb.e with
     | EFieldK _ | EDerefK _ -> tb
     | ESeqGetK (b, i) ->
       (* 元素槽地址：读副本形态改取地址（嵌套 seq 槽写） *)
       { e = EAddrOfK { e = ESeqGetK (b, i); ety = tb.ety; epos = tb.epos };
         ety = TPtr tb.ety; epos = tb.epos }
     | _ ->
       terr (pos_of_expr base)
         "%s must be a list variable, field, ref parameter, or element slot" what)

(* 槽根的元素类型（TList/TArray 或其指针形态） *)
and seq_elem_of_root env (root : texpr) (p : pos) : zty =
  match resolve root.ety with
  | TList e | TArray (e, _) -> e
  | TPtr (TList e) | TPtr (TArray (e, _)) -> e
  | t -> terr p "index/push target is not an array or list: %s" (pp_zty t)

(* struct 构造：Name(位置参数..., 命名参数...) → 全字段补全
   （位置按序 + 命名按字段名 + default + 零值；数组/列表字段缺省填空 seq） *)
and check_struct_new env p name (args : call_arg list) : texpr =
  let mk k ty = { e = k; ety = ty; epos = p } in
  match Hashtbl.find_opt env.g.structs name with
  | None ->
    if Hashtbl.mem env.g.gstructs name then
      check_struct_new_generic env p name args
    else undef_type_fix p name
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
          | Some a ->
            (* 字段实参为泛型构造/泛型函数调用时传期望（嵌套
               Box<Box<i32>> n = Box(Box(4)) 的内层 Box(4) 需要） *)
            let ta =
              (match a with
               | ECall (EVar _, _, _) -> expect_hint := Some ft
               | _ -> ())
            in
            let ta2 = check_expr env a in
            expect_hint := None;
            coerce p ta2 ft
          | None ->
            (match fdef with
             | Some de -> coerce p (check_expr env de) ft
             | None -> field_zero env p ft))
        sd.sfields
    in
    mk (EStructNewK (name, tvals)) (TStruct name)

(* 泛型 struct 构造（new2.md 第2条）：从实参推断类型实参 → 实例化 →
   按实例字段构造。每个实参只检查一次（推断与构造共用检查结果） *)
and check_struct_new_generic env p name (args : call_arg list) : texpr =
  let mk k ty = { e = k; ety = ty; epos = p } in
  let gs = Hashtbl.find env.g.gstructs name in
  (* 期望类型提示：声明上下文（Box<i32> a = Box(7)）已给出实例
     （gtargs 中有该 mangle 名的实参表），以其为准（字面量按期望落型） *)
  let hint = !expect_hint in
  expect_hint := None;
  let hint_mapl =
    match hint with
    | Some z0 ->
      (match resolve z0 with
       | TStruct m
         when String.length m > String.length name + 1
              && String.sub m 0 (String.length name + 1) = name ^ "$"
              && Hashtbl.mem env.g.gtargs m ->
         let zs = Hashtbl.find env.g.gtargs m in
         if List.length zs = List.length gs.gtp then
           Some (List.combine gs.gtp zs)
         else None
       | _ -> None)
    | None -> None
  in
  let mref = ref [] in
  let match_field (sf : sfield) z =
    match_param env.g gs.gtp p
      { pname = sf.fname; pty = sf.fty; pfrac = false;
        pseq = sf.fseq; pconst = false; punred = false; pref = false;
        ppos = sf.fpos } z mref
  in
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
  let nfields = List.length gs.gfields in
  if List.length pos_args > nfields then
    terr p "struct %s has %d fields, got %d positional arguments"
      name nfields (List.length pos_args);
  let checked : texpr option array = Array.make nfields None in
  let arg_zty (ta : texpr) =
    (* 字面量实参 ety 为未求解 TVar：推断时落默认类型（int→i64、float→f64） *)
    match ta.e, resolve ta.ety with
    | EIntK _, TVar _ -> TInt 64
    | EFloatK _, TVar _ -> TFloat 64
    | _, z -> z
  in
  List.iteri
    (fun i a ->
      let sf = List.nth gs.gfields i in
      let ta =
        (* 实参为泛型构造/泛型函数调用时下传期望（嵌套构造需要；
           期望字段类型 = 模板字段类型按 hint 实参 subst 后的具体型） *)
        (match a, hint_mapl with
         | ECall (EVar _, _, _), Some hl ->
           expect_hint := Some (conv_ty env.g sf.fpos (subst_ty_ast hl sf.fty))
         | _ -> ());
        let ta = check_expr env a in
        expect_hint := None;
        ta
      in
      if not (match_field sf (arg_zty ta)) then
        terr p "cannot infer type argument for field %s of %s (got %s)"
          sf.fname name (pp_zty (resolve ta.ety));
      checked.(i) <- Some ta)
    pos_args;
  List.iter
    (fun (nm, a) ->
      let rec go i = function
        | [] -> terr p "struct %s has no field %s" name nm
        | (sf : sfield) :: rest ->
          if sf.fname = nm then begin
            if checked.(i) <> None then terr p "field %s initialized twice" nm;
            let ta = check_expr env a in
            if not (match_field sf (arg_zty ta)) then
              terr p "cannot infer type argument for field %s of %s (got %s)"
                sf.fname name (pp_zty (resolve ta.ety));
            checked.(i) <- Some ta
          end
          else go (i + 1) rest
      in
      go 0 gs.gfields)
    named;
  List.iter
    (fun tp ->
      let from_hint = match hint_mapl with Some hl -> List.assoc_opt tp hl | None -> None in
      if List.assoc_opt tp !mref = None && from_hint = None then
        terr p "cannot infer type argument for %s (constructor of %s)" tp name)
    gs.gtp;
  let mapl =
    match hint_mapl with
    | Some hl -> hl
    | None -> List.map (fun tp -> (tp, List.assoc tp !mref)) gs.gtp
  in
  let mangled =
    match instantiate_struct_zty env.g name mapl p with
    | TStruct m -> m
    | _ -> assert false
  in
  let sd = Hashtbl.find env.g.structs mangled in
  let tvals =
    List.mapi
      (fun i (_, ft, fdef) ->
        match checked.(i) with
        | Some ta -> coerce p ta ft
        | None ->
          (match fdef with
           | Some de -> coerce p (check_expr env de) ft
           | None -> field_zero env p ft))
      sd.sfields
  in
  mk (EStructNewK (mangled, tvals)) (TStruct mangled)

(* 下标/整数参数统一转成 i64（小整数隐式拓宽） *)
and to_i64 (ti : texpr) : texpr =
  match resolve ti.ety with
  | TError -> ti   (* poison：含错下标静默通过（n4） *)
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
  else if a = TError then te   (* poison：含错表达式落任意槽静默通过（n4） *)
  else
    match a, b with
    | TVar _, (TInt 128 | TUint 128 as tgt)
      when (match te.e with EBigK _ -> true | _ -> false) ->
      (* 大字面量反绑（w-014 #6）：i128/u128 期望上下文 + 范围校验 *)
      let digits = (match te.e with EBigK d -> d | _ -> assert false) in
      if not (big_ok digits (match tgt with TUint _ -> true | _ -> false)) then
        terr p "integer literal %s overflows %s" digits (pp_zty tgt);
      { te with ety = tgt }
    | TVar _, _ when (match te.e with EBigK _ -> true | _ -> false) ->
      terr p "large integer literal %s requires an i128/u128 context, got %s"
        (match te.e with EBigK d -> d | _ -> "")
        (pp_zty b)
    | TVar _, TErr t ->
      (* 目标为 T! 且值类型未定（整型/浮点面值 ety=TVar）：按元素类型
         求解后自动包装成功值（否则面值会以裸 OInt 落进 TErr 槽） *)
      unify p te.ety t;
      let te2 = coerce p te t in
      { e = EErrOkK te2; ety = want; epos = te.epos }
    | TVar _, TFrac e ->
      (* 未求解字面量表达式 → frac（return/赋值/实参上下文）：
         值侧同步改写——n/d 字面量除式按分数构造（分子/分母不除法），
         其他整数字面量表达式整体标量提升为分数。此前走 unify 仅改类型
         不改值，OInt 直接落 frac 聚合槽致 E4021 内部错误（w-021） *)
      (match te.e with
       | EBinK (BDiv, ta, tb) ->
         let is_num = function EIntK _ | EFloatK _ -> true | _ -> false in
         if is_num ta.e && is_num tb.e then begin
           let ac = { e = ECastK (ta, e); ety = e; epos = ta.epos } in
           let bc = { e = ECastK (tb, e); ety = e; epos = tb.epos } in
           { e = EFracNewK (ac, bc); ety = TFrac e; epos = te.epos }
         end
         else mk_frac_from te e p
       | _ -> mk_frac_from te e p)
    | TVar _, (TList _ | TArray _ | TStruct _ | TFile | TString) ->
      (* 字面量（ety=TVar）不能落聚合/句柄/串类型：此前 unify 把字面量
         直接重打型（如 push(ll, 1) 中 1 变 TList → store ptr 1 非法 IR，
         w-021） *)
      terr p "a literal value cannot have type %s (build it via a variable or constructor first)"
        (pp_zty want)
    | TVar _, ((TInt _ | TUint _ | TChar) as tgt) when floaty_texpr te ->
      (* v3.3.1：浮点字面量子树不可隐式落整数/char——此前静默 unify 绑成
         整数型，fix_texpr 再把 EFloatK 叶子翻 f64，产 f64/i64 混算坏 IR
         （x += 2.5 落整型槽、2.5 作 i64 实参等） *)
      terr p "floating-point literal cannot be used as %s (explicit cast required)"
        (pp_zty tgt)
    | TVar _, (TBool | TChar)
      when (match te.e with
            | EBinK _ | EUnK _ | ECallK _ -> true | _ -> false) ->
      (* v3.3.2：延迟定型的算术/调用树（2**0、|3| 等，ety=TVar）不可落
         bool/char 目标——此前 unify 静默把共享 TVar 绑成 TBool/TChar，
         codegen 无对应分发报 E4025 内部错误（if 2**0） *)
      terr p "arithmetic result cannot be used as %s (explicit comparison or conversion required)"
        (pp_zty b)
    | TVar _, ((TInt _ | TUint _) as tgt) ->
      (* 自动修复①补：整数字面量的范围守卫——超界不再静默回绕报 E3155；
         char 字面量落整数槽登记自动 cast（ord 语义） *)
      (match te.e with
       | EIntK v when not (int_fits v tgt) ->
         terr p
           "narrowing conversion from %Ld to %s requires an explicit cast (literal out of range)"
           v (pp_zty tgt)
       | ECharK _ ->
         autofixed := !autofixed @
           [(p, te.epos, Printf.sprintf
               "type mismatch: expected %s, got char (char code used as ord(c); auto-fixed: cast inserted)"
               (pp_zty tgt), pp_zty tgt)];
         { e = ECastK (te, want); ety = want; epos = te.epos }
       | _ -> unify p te.ety want; te)
    | TVar _, _ | _, TVar _ -> unify p te.ety want; te
    | _, TFrac e when (match te.e with EIntK _ | EFloatK _ -> true | _ -> false) ->
      (* 数值字面量提升为分数（实参/返回等表达式上下文，与声明初值一致；
         此前经 TVar 路径静默重打型，标量常量落进 frac 聚合槽致 E4021） *)
      mk_frac_from te e p
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
        (* 自动修复①：整数字面量窄化但值落在目标范围内 → 插入 cast
           继续编译（登记 autofixed，driver 报告为自动修复项） *)
        (match te.e with
         | EIntK v when int_fits v b ->
           autofixed := !autofixed @
             [(p, te.epos, Printf.sprintf
                 "narrowing conversion from %s to %s (literal %Ld fits target range; auto-fixed: cast inserted)"
                 (pp_zty a) (pp_zty b) v, pp_zty b)];
           { e = ECastK (te, want); ety = want; epos = te.epos }
         | _ ->
           terr p "narrowing conversion from %s to %s requires an explicit cast"
             (pp_zty a) (pp_zty b))
    (* 定长数组 -> 动态长度数组参数（TList 运行期与 TArray 同构） *)
    | TArray (ea, _), TList eb when ea = eb ->
      (* 定长数组 -> 列表（TList 运行期与 TArray 同构；struct/嵌套元素
         亦合法，w-014 #2/#4） *)
      te
    (* T! 与 T 的互转：T! 不能当普通值用；T 自动包装为成功值 *)
    | TErr _, TErr _ -> unify p te.ety want; te
    | TErr _, _ ->
      terr p "fallible value used directly as a plain value (unwrap with ?? or propagate with ?): got %s, expected %s"
        (pp_zty a) (pp_zty b)
    | _, TErr _ when a <> TVoid ->
      { e = EErrOkK te; ety = want; epos = te.epos }
    | TChar, (TInt _ | TUint _) ->
      (* 自动修复②：char → 整数槽：插入 cast（码点数值，ord 语义）继续编译 *)
      autofixed := !autofixed @
        [(p, te.epos, Printf.sprintf
            "type mismatch: expected %s, got %s (char code used as ord(c); auto-fixed: cast inserted)"
            (pp_zty b) (pp_zty a), pp_zty b)];
      { e = ECastK (te, want); ety = want; epos = te.epos }
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
    if resolve t.ety = TError then t   (* poison：静默通过（n4） *)
    else begin
      if resolve t.ety <> TString then
        terr p "%s expects a string for its %s parameter, got %s" name what (pp_zty t.ety);
      t
    end
  in
  (* 第二参数：char -> 字符语义；string -> 子串语义；其他类型报错
     （w-020：不再走 to_string_of 兜底——trim(s, 65) 这类调用语义含糊，
     报错文案明确化，与 find 的 char 报错风格统一） *)
  let char_or_str (e : expr) what =
    let t = check_expr env e in
    match resolve t.ety with
    | TChar -> `Char t
    | TError -> `Str t   (* poison：按 string 侧继续装配，不再报错（n4） *)
    | TString -> `Str t
    | _ ->
      terr p "%s's %s must be char or string, got %s" name what (pp_zty t.ety)
  in
  match name, pos_args, named with
  | "length", [ x ], [] ->
    let tx = check_expr env x in
    (* v3.3.4：长度/下标类内建返回 i32（此前 i64，落 i32 槽需显式 cast） *)
    (match resolve tx.ety with
     | TError -> mk (ESeqLenK tx) TError   (* poison（n4） *)
     | TString ->
       let c = mk (ECallK ("strlen", [ tx ], [])) (TInt 64) in
       mk (ECastK (c, TInt 32)) (TInt 32)
     | TArray _ | TList _ -> mk (ESeqLenK tx) (TInt 32)
     | t -> terr p "length expects string/array/list, got %s" (pp_zty t))
  | "find", [ s; c ], [] ->
    (* find(s, x)：x 为 char 找第 1 次出现的字符；为 string 找子串
       （w-020 用户拍板补子串形态）。找不到返回 NOT_FOUND 错误值（T!） *)
    let ts = str_of s "argument 1" in
    let one = { e = EIntK 1L; ety = TInt 64; epos = p } in
    (match char_or_str c "argument 2" with
     | `Char tc -> { e = EFindK (ts, tc, one); ety = TErr (TInt 32); epos = p }
     | `Str tx -> { e = EFindK (ts, tx, one); ety = TErr (TInt 32); epos = p })
  | "find", [ s; c ], [ ("count", k) ] ->
    (* find(s, x, count=k)：找第 k 次出现（k 从 1 起）；找不到 = NOT_FOUND（T!）；
       k < 1 编译期拒绝（字面量/常量），运行期 panic（runtime 统一，w-020） *)
    let ts = str_of s "argument 1" in
    let tk = to_i64 (check_expr env k) in
    (match const_eval env tk with
     | Some v when Int64.compare v 1L < 0 ->
       terr p "find's count must be > 0, got %Ld" v
     | _ -> ());
    (match char_or_str c "argument 2" with
     | `Char tc -> { e = EFindK (ts, tc, tk); ety = TErr (TInt 32); epos = p }
     | `Str tx -> { e = EFindK (ts, tx, tk); ety = TErr (TInt 32); epos = p })
  | "trim", [ s; x ], [] ->
    let ts = str_of s "argument 1" in
    (match char_or_str x "argument 2" with
     | `Char tc -> { e = ECallK ("zfy_str_trim", [ ts; tc ], []); ety = TString; epos = p }
     | `Str tx -> { e = ECallK ("zfy_str_trim_str", [ ts; tx ], []); ety = TString; epos = p })
  | "split", [ s; x ], [] ->
    (* split(s, x)：按分隔符切分，返回 string 列表（一等值，可 length/下标/遍历）。
       '\0' 分隔符编译期拒绝：C 串无内嵌 NUL，永远匹配不到（w-020） *)
    let ts = str_of s "argument 1" in
    (match char_or_str x "argument 2" with
     | `Char tc ->
       (match tc.e with
        | ECharK '\000' ->
          terr p "split does not accept '\\000' as the delimiter (a C string can never contain NUL)"
        | _ -> ());
       { e = ESplitK (ts, tc); ety = TList TString; epos = p }
     | `Str tx -> { e = ESplitK (ts, tx); ety = TList TString; epos = p })
  | "replace", [ _; _; _ ], [] ->
    (* w-020 用户拍板：两参 replace(s, a, rep) 已删除。
       "替换到串尾"用四参闭区间 replace(s, a, length(s) - 1, rep) 表达 *)
    terr p "replace requires (s, a, b, rep): replace the closed interval [a, b] with rep; to replace to the end use b = length(s) - 1 (the two-argument form was removed)"
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
  | "utf8_len", [ s ], [] ->
    (* utf8_len(s)：码点数（string 底层仍是字节串，length 按字节不变；
       本组 UTF-8 API 为 w-020 用户拍板扩展集）。v3.3.4：返回 i32 对齐 length *)
    let ts = str_of s "argument 1" in
    let c = mk (ECallK ("zfy_utf8_len", [ ts ], [])) (TInt 64) in
    mk (ECastK (c, TInt 32)) (TInt 32)
  | "utf8_char_at", [ s; i ], [] ->
    (* utf8_char_at(s, i)：第 i 个码点（0 起），返回单码点 string（可能多字节；
       越界运行期 panic）。返回 string 而非 char：char 是单字节，装不下中文码点 *)
    let ts = str_of s "argument 1" in
    let ti = to_i64 (check_expr env i) in
    mk (ECallK ("zfy_utf8_char_at", [ ts; ti ], [])) TString
  | "utf8_sub", [ s; a; b ], [] ->
    (* utf8_sub(s, a, b)：按码点闭区间 [a, b] 切片（两端含），返回新 string *)
    let ts = str_of s "argument 1" in
    let ta = to_i64 (check_expr env a) and tb' = to_i64 (check_expr env b) in
    mk (ECallK ("zfy_utf8_sub", [ ts; ta; tb' ], [])) TString
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
and check_input_ty p = function
  | TString | TInt _ | TUint _ | TFloat _ | TBool | TChar -> ()
  | TErr t -> check_input_ty p t
  | t -> terr p "input target must be string/integer/float/bool/char, got %s" (pp_zty t)

(* 解包块形式识别（parser 把 a ?? 缩进块解析为 EUnwrap (a, EBlock ...)） *)
and is_unwrap_block (e : expr) =
  match e with EUnwrap (_, EBlock _, _) -> true | _ -> false

(* zty → ast ty（let 无类型推断用；无法用 ast 类型表达的返回 None） *)
and zty_to_ast (p : pos) (t : Hir.zty) : ty =
  let open Hir in
  let named w () = TNamed (w, p) in
  match t with
  | TInt 8 -> named "i8" () | TInt 16 -> named "i16" () | TInt 32 -> named "i32" ()
  | TInt 64 -> named "i64" () | TInt 128 -> named "i128" ()
  | TUint 8 -> named "u8" () | TUint 16 -> named "u16" () | TUint 32 -> named "u32" ()
  | TUint 64 -> named "u64" () | TUint 128 -> named "u128" ()
  | TFloat 16 -> named "f16" () | TFloat 32 -> named "f32" ()
  | TFloat 64 -> named "f64" () | TFloat 128 -> named "f128" ()
  | TBool -> named "bool" () | TString -> named "string" () | TChar -> named "char" ()
  | TStruct s -> named s () | TFile -> named "File" ()
  | TPtr t -> TPtr (zty_to_ast p t, p)
  | TErr t -> TErr (zty_to_ast p t, p)
  | TArray (e, n) -> TSeqN (zty_to_ast p e, EInt (Int64.of_int n, p), p)
  | TList e -> TSeq (zty_to_ast p e, p)
  | _ -> raise ZtyToAstFail

and check_decl env p isconst is_frac0 is_unred name (ty_opt : ty option) init =
  (* ---- let 类型省略推断（new.md 2026-10-10）----
     字面量形式直接定型：整数字面量→i32（超 i64 十进制→i128）、浮点→f64、
     n/d 数值字面量除式→i32 frac（分数字面量语义）、string/char/bool 按字面量；
     frac 修饰无类型 → 基类型 i32；非字面量：check_expr 一次取表达式自身类型
     （结果经 checked 透传，避免二次检查重复标记 move 等副作用）；
     类型与初值都无（且无 frac 修饰）报错。unred 须 frac（修饰或 n/d 推断） *)
  let is_frac, ty, checked =
    match ty_opt with
    | Some ty -> is_frac0, ty, None
    | None ->
      let rec lit_ty = function
        | EInt _ -> Some ("i32", false)
        | EBigInt _ -> Some ("i128", false)
        | EFloat _ -> Some ("f64", false)
        | EStr _ -> Some ("string", false)
        | EChar _ -> Some ("char", false)
        | EBool _ -> Some ("bool", false)
        | EUn (Ast.Neg, e1, _) -> lit_ty e1
        | EBin (Ast.Div, (EInt _ | EFloat _), (EInt _ | EFloat _), _) -> Some ("i32", true)
        | _ -> None
      in
      (match init with
       | None when is_frac0 -> is_frac0, TNamed ("i32", p), None
       | None ->
         terr p "let declaration requires a type or an initializer (let TYPE x / let x = v / let frac x)"
       | Some e ->
         (match lit_ty e with
          | Some (b, nd) -> (nd || is_frac0), TNamed (b, p), None
          | None ->
            let t = check_expr env e in
            (match resolve t.ety with
             | TVar _ ->
               terr p "cannot infer the declaration type from this initializer; give an explicit type"
             | _ when is_frac0 ->
               (* frac 修饰 + 表达式初值：基类型按修饰（i32），表达式走
                  常规 frac 提升/校验路径 *)
               (true, TNamed ("i32", p), Some t)
             | ety ->
               (match (try Some (zty_to_ast p ety) with ZtyToAstFail -> None) with
                | Some aty -> (false, aty, Some t)
                | None ->
                  terr p "cannot infer the declaration type from this initializer; give an explicit type"))))
  in
  if is_unred && not is_frac then
    terr p "unred requires the frac modifier or a n/d literal initializer (let unred x = 0/1)";
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
      (* 裸声明 struct：等同 Name() 全默认构造，字段默认值生效（change.md 1.2）；
         chan$/mutex$ 句柄例外——声明即构造（zero_of 特判，避免与闭包
         按值捕获的句柄副本错开对象） *)
      (match resolve want with
       | TStruct s when is_chan_struct s || is_mtx_struct s -> zero_of env p want
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
      let t = (match checked with Some t -> t | None -> check_expr env init) in
      if resolve t.ety <> TBool then
        terr p "bool can only be initialized with true/false, 0/1, or a boolean expression";
      t
    | TFrac e, EBin (Div, a, b, _)
      when (match a, b with
            | (EInt _ | EFloat _), (EInt _ | EFloat _) -> true
            | _ -> false) ->
      (* frac 字面量：分子 / 分母（不执行除法、不自动约分） *)
      let ta = check_expr env a and tb = check_expr env b in
      let ac =
        if resolve ta.ety = e then ta
        else { e = ECastK (ta, e); ety = e; epos = ta.epos }
      in
      let bc =
        if resolve tb.ety = e then tb
        else { e = ECastK (tb, e); ety = e; epos = tb.epos }
      in
      { e = EFracNewK (ac, bc); ety = TFrac e; epos = p }
    | TFrac e, EBin (Ast.Div, a, b, _)
      when is_frac_arith a || is_frac_arith b ->
      (* 非 n/d 形式的除式（new.md 2026-10-11）：两侧按 frac 期望检查——
         含变量的除法按分数除法执行（运行时自动约分），已 frac 侧保持 *)
      let ta = check_frac_expr env a e in
      let tb = check_frac_expr env b e in
      (match resolve ta.ety, resolve tb.ety with
       | TFrac e1, TFrac e2 when e1 = e2 ->
         { e = EBinK (BDiv, ta, tb); ety = TFrac e1; epos = p }
       | _ -> terr p "mismatched frac element types in division")
    | TFrac _, _ ->
      (* 单表达式初值：含 / 的算术整棵按分数算（check_frac_expr）；
         其他表达式标量提升为分数（不约分） *)
      (match checked with
       | Some t ->
         (match resolve t.ety with
          | TFrac e2 when resolve want = TFrac e2 -> t
          | TFrac _ -> terr p "mismatched frac element types"
          | TInt _ | TUint _ | TFloat _ | TVar _ -> mk_frac_from t (match resolve want with TFrac e -> e | _ -> assert false) p
          | _ -> terr p "cannot initialize %s as frac" (pp_zty t.ety))
       | None ->
         if is_frac_arith init then check_frac_expr env init (match resolve want with TFrac e -> e | _ -> assert false)
         else
           let t = check_expr env init in
           (match resolve t.ety with
            | TFrac e2 when resolve want = TFrac e2 -> t
            | TFrac _ -> terr p "mismatched frac element types"
            | TInt _ | TUint _ | TFloat _ | TVar _ -> mk_frac_from t (match resolve want with TFrac e -> e | _ -> assert false) p
            | _ -> terr p "cannot initialize %s as frac" (pp_zty t.ety)))
    | _, ECall (EVar (n, _), _, _)
        when checked = None
             && (Hashtbl.mem env.g.gstructs n || Hashtbl.mem env.g.gfns n) ->
      (* 泛型构造/泛型函数调用在声明上下文：把声明类型作为期望提示
         传给推断（字面量实参按期望落型，而非默认 i64/f64）；
         let 无类型推断路径已预检查（checked），不再重复 *)
      expect_hint := Some want;
      let t = check_expr env init in
      expect_hint := None;
      t
    | _, _ ->
      (match checked with
       | Some t -> t
       | None -> check_expr env init))
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
  (* File move-only（design_fileio.md）：声明初始化 `File g = f` 为所有权
     转移（mir 侧清空源槽，运行期失效兜底）；编译期标记源变量已 move，
     同块复用报错 *)
  (match resolve want, init with
   | TFile, Some (EVar (n2, _)) ->
     (match lookup_var env n2 with
      | Some src when resolve src.lty = TFile -> Hashtbl.replace env.moved src.lslot ()
      | _ -> ())
   | _ -> ());
  SDeclK (isconst, slot, want, tinit, needs_norm)

(* 赋值目标为变量槽时的公共检查，返回槽名 *)
and assign_var env p name =
  match lookup_var env name with
  | Some l ->
    if l.lconst then
      terr p "cannot assign to constant %s (declared const)" name;
    l.lslot
  | None -> terr p "%s" (undef_fix env p name "variable")

(* 9c：解引用写目标若为指向 const 的指针变量（T const*）则报错 *)
and check_constp env (pe : expr) p =
  match pe with
  | EVar (name, _) ->
    (match lookup_var env name with
     | Some l when l.lconstp ->
       terr p "cannot write through pointer-to-const %s (declared T* const)" name
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
  | EIndex (EVar (arr, ap), idx, ip) when lookup_var env arr <> None ->
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
          (* string 元素 +=（w-020）：只支持拼接，rhs 为 string/char（char 提升）；
             concat 降码在 mir SAugIndexK（下标仍只求值一次） *)
          let trhs =
            if resolve e = TString then begin
              if bop <> BAdd then
                terr ap "string elements only support += (concatenation)";
              (match resolve trhs.ety with
               | TChar -> to_string_of trhs
               | TString -> trhs
               | t -> terr ip "string element concatenation requires string or char, got %s" (pp_zty t))
            end
            else if (match resolve e with TErr _ -> true | _ -> false) then
              terr ip "T! elements do not support augmented assignment (unwrap with ?? then reassign)"
            else coerce ip trhs e in
          SAugIndexK ({ e = EVarK l.lslot; ety = l.lty; epos = ap },
                      e, ti, bop, trhs, grow)
        | TPtr t ->
          (* 指针下标复合赋值（自动解引用，无越界检查）：p[i] op= v，
             地址 p+i 只求值一次；强制 unsafe 块（new2.md #8） *)
          if l.lconstp then
            terr ap "cannot write through pointer-to-const %s (declared T* const)" arr;
          if not env.in_unsafe then
            terr ap "pointer subscript p[i] is only allowed inside an unsafe block";
          let ti = to_i64 (check_expr env idx) in
          let tp = { e = EVarK l.lslot; ety = l.lty; epos = ap } in
          let addr = { e = EBinK (BAdd, tp, ti); ety = l.lty; epos = ip } in
          let trhs = check_expr env rhs in
          let trhs = coerce ip trhs t in
          SAugDerefK (addr, bop, trhs)
        | t -> terr ap "augmented assignment target does not support indexing: %s" (pp_zty t))
     | None -> terr ap "%s" (undef_fix env ap arr "variable"))
  | EIndex (base, idx, ip) ->
    (* 元素复合赋值槽根泛化（w-014 #3）：bag.xs[i] += v / xs[i]++（ref）等 *)
    let root = seq_slot_root env base "augmented index-assignment target" in
    let e = seq_elem_of_root env root ip in
    let grow = (match resolve root.ety with
                | TList _ | TPtr (TList _) -> true | _ -> false) in
    let ti = to_i64 (check_expr env idx) in
    let trhs = check_expr env rhs in
    (* string 元素 +=（w-020）：同变量元素路径；concat 降码在 mir SAugIndexK *)
    let trhs =
      if resolve e = TString then begin
        if bop <> BAdd then
          terr ip "string elements only support += (concatenation)";
        (match resolve trhs.ety with
         | TChar -> to_string_of trhs
         | TString -> trhs
         | t -> terr ip "string element concatenation requires string or char, got %s" (pp_zty t))
      end
      else if (match resolve e with TErr _ -> true | _ -> false) then
        terr ip "T! elements do not support augmented assignment (unwrap with ?? then reassign)"
      else coerce ip trhs e in
    SAugIndexK (root, e, ti, bop, trhs, grow)
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
     | None -> terr ap "%s" (undef_fix env ap arr "variable"))
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
          (* s += v：原地追加（T7 优化，realloc 扩容免全量拷贝）；
             槽独占堆串（MCopy strdup 保证），语义同 s = s + v；
             rhs 为 char 时提升为单字符 string（w-020） *)
          let trhs = check_expr env rhs in
          let trhs = (match resolve trhs.ety with
                      | TChar -> to_string_of trhs
                      | TString -> trhs
                      | t -> terr p' "string concatenation requires string or char, got %s" (pp_zty t)) in
          SStrAppendK (slot, [ trhs ])
        | _ ->
          let lty = l.lty in
          let trhs =
            (match resolve lty with
             | TFrac e when is_frac_arith rhs ->
               (* frac 变量复合赋值含 / 的算术（new.md 2026-10-11）：按分数算 *)
               check_frac_expr env rhs e
             | _ -> check_expr env rhs)
          in
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
           | None -> terr p' "%s" (undef_fix env p' name "variable"))
        | None -> terr p' "%s" (undef_fix env p' name "variable")))
  | EDeref (pe, dp) ->
    (* p* op= v / p*++ / p*--：解引用复合赋值（仅数值标量/指针目标；
       string 例外：p^ += v 走 concat + 引用槽整体替换，w-020） *)
    check_constp env pe dp;
    let tp = check_expr env pe in
    (match resolve tp.ety with
     | TPtr t ->
       (match resolve t with
        | TString when bop = BAdd ->
          (* p^ += v 改写为 p^ = p^ + v：SDerefSetK 语义 = 释放旧串 +
             接管新串（引用槽整体替换），与 deref 整体赋值一致 *)
          let trhs = check_expr env rhs in
          let trhs = (match resolve trhs.ety with
                      | TChar -> to_string_of trhs
                      | TString -> trhs
                      | t -> terr dp "string concatenation requires string or char, got %s" (pp_zty t)) in
          let cur = { e = EDerefK tp; ety = TString; epos = dp } in
          let nv = { e = ECallK ("zfy_str_concat", [ cur; trhs ], []); ety = TString; epos = dp } in
          SDerefSetK (tp, nv)
        | TInt _ | TUint _ | TFloat _ | TPtr _ ->
          let trhs = check_expr env rhs in
          let trhs = coerce dp trhs t in
          SAugDerefK (tp, bop, trhs)
        | TString ->
          terr dp "dereferenced string only supports += (concatenation)"
        | t' ->
          terr dp "dereferenced augmented assignment supports only numeric/pointer types, got %s" (pp_zty t'))
     | t -> terr dp "augmented/inc/dec target must be a pointer dereference, got %s" (pp_zty t))
  | EField _ | EIndex _ ->
    (* v3.3.8：元素/字段链元素的复合赋值与 inc/dec（self.buttons[i].clicks++、
       arr[i].v += 1 等）——取可定位目标的地址后按解引用复合赋值处理 *)
    let fp = pos_of_expr lhs in
    (match check_expr env (EAddrOf (lhs, fp)) with
     | { ety = TPtr (TInt _ | TUint _ | TFloat _); _ } as tp ->
       let t0 = (match resolve tp.ety with TPtr t0 -> t0 | _ -> assert false) in
       let trhs = check_expr env rhs in
       let trhs = coerce fp trhs t0 in
       SAugDerefK (tp, bop, trhs)
     | { ety = t; _ } ->
       terr fp "augmented/inc/dec target must be a numeric scalar, got %s" (pp_zty t))
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
       | None -> terr p "%s" (undef_fix env p name "variable"))
    | `Discard -> ("", elem)
    | `Return ->
      (* return a ?? 块：函数须返回 T!，块元素与 T! 元素一致 *)
      (match resolve env.fncur_ret with
       | TErr rt -> unify p elem rt
       | rt ->
         terr p "return a ?? block requires the enclosing function to return T! (current: %s)"
           (pp_zty rt));
      ("", elem)
  in
  push_scope env;
  declare env "err" { lconst = true; lty = TStruct "Err"; lslot = ""; lunred = false; lconstp = false };
  let errslot = (match lookup_var env "err" with Some l -> l.lslot | None -> assert false) in
  let saved_unwrap = env.in_unwrap in
  env.in_unwrap <- true;
  let tblk = check_block env blk in
  env.in_unwrap <- saved_unwrap;
  pop_scope env;
  let tblk =
    match target, List.rev tblk with
    | `Discard, _ -> tblk
    | `Return, [] ->
      terr p "??-block after return requires a final value expression (or an explicit return)"
    | `Return, { s = SExprK v; spos = vp } :: rest_rev ->
      (* 块末值经 coerce 包装为函数返回类型（T!），改写为 SReturnK *)
      let v = coerce vp v env.fncur_ret in
      List.rev ({ s = SReturnK (Some v); spos = vp } :: rest_rev)
    | _, { s = SExprK v; spos = vp } :: rest_rev ->
      let v = coerce vp v tgt_ty in
      List.rev
        ({ s = SAssignK ({ e = EVarK slot; ety = v.ety; epos = vp }, v, false, false);
           spos = vp } :: rest_rev)
    | _, _ -> tblk   (* 块以 return/break/continue/panic 等结束：目标不写 *)
  in
  let is_decl = (match target with `Decl _ -> true | _ -> false) in
  let is_ret = (match target with `Return -> true | _ -> false) in
  SUnwrapBlockK (is_decl, is_ret, slot, elem, ta, errslot, tblk)

and check_unwrap_decl env p isconst name ty init =
  match init with
  | EUnwrap (a, EBlock (blk, _), _) -> check_unwrap env p a blk (`Decl (isconst, name, ty))
  | _ -> assert false

(* 语句块检查。语句级错误恢复：单条语句检查失败时记录错误并继续下一条
   （多错误收集）；恢复作用域栈深度（异常会跳过配对的 pop_scope）。
   moved 表/fnvars 的残留可能引起级联报错，可接受（不掩盖首个错误） *)
and check_block env (stmts : stmt list) : tblock =
  (* 一行多声明器（SDeclList）展开为逐条语句（w-012），共享同一作用域：
     声明按序生效，同行后续声明器与语句可见前面的名字 *)
  let rec expand (st : stmt) : stmt list =
    match st with
    | SDeclList ss -> List.concat_map expand ss
    | s -> [ s ]
  in
  let recover s =
    let depth = List.length env.scopes in
    let r =
      try Some (check_stmt env s)
      with TypeError (p, m) ->
        collected := (p, m) :: !collected;
        None
    in
    while List.length env.scopes > depth do pop_scope env done;
    (* poison（n4）：声明失败的变量以 TError 入作用域（在恢复后的语句级
       scope 声明），后续引用静默通过——否则每个引用点都报 undefined/
       类型错（级联噪声）。变量可能已被声明到一半（报错点在右值），查重后再补 *)
    (match s with
     | SDecl (_, _, _, name, _, _, _) | SSeqDecl (_, _, _, name, _, _, _, _, _) ->
       if lookup_var env name = None then
         declare env name
           { lconst = false; lty = TError; lslot = "<err>";
             lunred = false; lconstp = false }
     | _ -> ());
    r
  in
  List.filter_map recover (List.concat_map expand stmts)

(* 数组/列表声明检查（不含 split 初值特判）：返回语句种类。
   frac 数组/列表（new.md）：元素初值/存入自动约分（unred 数组不约分，
   enn 透传给 mir 做元素归一） *)
and check_seq_decl env p isconst is_frac is_unred name e len is_list inits =
  (match resolve e with
   | TFrac _ -> ()   (* frac 元素合法（new.md 2026-10-10）：存入自动约分 *)
   | TErr _ -> ()    (* T! 元素合法（new.md 2026-10-11）：24/32 字节聚合槽，
                        clone=memcpy、free=no-op（msg 按 strdup 泄漏约定） *)
   | TFile -> terr p "File cannot be an array/list element (move-only handle)"
   | _ -> ());   (* struct/嵌套 seq 元素合法（w-014 #2/#4），运行时按头部 kind 深拷贝 *)
  let enn = is_frac && not is_unred in   (* 元素需归一（存入/初值） *)
  (* frac 元素初值：n/d 字面量按分数构造（不除法），其他走 coerce 提升 *)
  let check_elem (ie : expr) : texpr =
    match resolve e, ie with
    | TFrac w, _ when is_frac_arith ie ->
      (* frac 元素初值含 / 的算术（new.md 2026-10-11）：整棵按分数算
         （n/d 字面量形式仍按分数构造不除法，存入时按 enn 归一） *)
      check_frac_expr env ie w
    | _ ->
      let ti2 = check_expr env ie in
      coerce p ti2 e
  in
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
         { lconst = isconst; lty = TList e; lslot = ""; lunred = is_unred; lconstp = false };
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
        let tinits = List.map check_elem inits in
        declare env name
          { lconst = isconst; lty = TList e; lslot = ""; lunred = is_unred; lconstp = false };
        let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
        SSeqDeclK (isconst, slot, e, 0L, true, tinits, enn))
  (* 数组整体初值：T array b[N] = 源（源为同元素类型数组/列表 → 深拷贝） *)
   | [ ie ], false ->
     let ti = check_expr env ie in
     (match resolve ti.ety with
      | TArray (e2, n2) when resolve e2 = resolve e && n2 = Int64.to_int vlen ->
        declare env name
          { lconst = isconst; lty = TArray (e, Int64.to_int vlen);
            lslot = ""; lunred = is_unred; lconstp = false };
        let slot =
          (match lookup_var env name with
           | Some l -> l.lslot
           | None -> assert false)
        in
        SSeqCopyK (isconst, slot, e, vlen, ti, false)
      | TList e2 when resolve e2 = resolve e ->
        declare env name
          { lconst = isconst; lty = TList e;
            lslot = ""; lunred = is_unred; lconstp = false };
        let slot =
          (match lookup_var env name with
           | Some l -> l.lslot
           | None -> assert false)
        in
        SSeqCopyK (isconst, slot, e, vlen, ti, true)
      | _ ->
        let tinits = List.map check_elem inits in
        declare env name
          { lconst = isconst;
            lty = TArray (e, Int64.to_int vlen);
            lslot = ""; lunred = is_unred; lconstp = false };
        let slot =
          (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
        SSeqDeclK (isconst, slot, e, vlen, is_list, tinits, enn))
   | _ ->
     let tinits = List.map check_elem inits
     in
     declare env name
       { lconst = isconst;
         lty = if is_list then TList e else TArray (e, Int64.to_int vlen);
         lslot = ""; lunred = is_unred; lconstp = false };
     let slot = (match lookup_var env name with Some l -> l.lslot | None -> assert false) in
     SSeqDeclK (isconst, slot, e, vlen, is_list, tinits, enn))

and check_stmt env (st : stmt) : tstmt =
  let mk k = { s = k; spos = pos_of_stmt st } in
  match st with
  | SDecl (isconst, is_frac, is_unred, name, ty_opt, init, p) when init <> None && is_unwrap_block (Option.get init) ->
    (match ty_opt with
     | Some ty ->
       if is_frac || is_unred then
         terr p "frac/unred does not support ??-block initialization";
       mk (check_unwrap_decl env p isconst name ty (Option.get init))
     | None ->
       terr p "??-block initialization requires an explicit type (let T x = a ?? ...)")
  | SDecl (isconst, is_frac, is_unred, name, ty_opt, init, p) ->
    mk (check_decl env p isconst is_frac is_unred name ty_opt init)
  | SSeqDecl (isconst, is_frac, is_unred, name, ety, len, is_list, inits, p) ->
    mk (check_seq_decl env p isconst is_frac is_unred name (conv_ty env.g p ety) len is_list inits)
  | SAssign (lhs, rhs, p) when is_unwrap_block rhs ->
    (* x = a ?? 缩进块 *)
    (match lhs, rhs with
     | EVar (name, _), EUnwrap (a, EBlock (blk, _), _) ->
       mk (check_unwrap env p a blk (`Assign name))
     | _ -> terr p "??-block assignment target must be a variable (for now)")
  | SAssign (lhs, rhs, p) ->
    (match lhs, rhs with
     | EIndex (EVar (arr, ap), idx, ip), _ when lookup_var env arr <> None ->
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
             mk (SSeqSetK ({ e = EVarK l.lslot; ety = l.lty; epos = ap },
                           e, ti, trhs, grow))
           | TString ->
             (* s[i] = c：string 下标写（w-014 #5）——槽内堆串原地写，
                越界运行时报错；槽独占堆串由 MCopy strdup 保证 *)
             if l.lconst then
               terr ap "cannot modify a constant string %s" arr;
             let ti = to_i64 (check_expr env idx) in
             let trhs = check_expr env rhs in
             (match resolve trhs.ety with
              | TChar -> ()
              | t -> terr ip "string index assignment requires a char, got %s" (pp_zty t));
             mk (SStrSetK ({ e = EVarK l.lslot; ety = l.lty; epos = ap },
                           ti, trhs))
           | TStruct s when is_map_struct s ->
             (* m[k] = v（v3.6）：分派 runtime put（键 int→i64/string；
                整数值统一按 i64 位模式） *)
             if l.lconst then
               terr ap "cannot modify a constant map %s" arr;
             let marg = { e = EVarK l.lslot; ety = l.lty; epos = ap } in
             let tidx = check_expr env idx in
             let trhs = check_expr env rhs in
             (match cont_kv env.g s ap with
              | (_, Some vt) ->
                let (kf, karg) = map_key_arg env ap tidx in
                let vtag = map_vtag ap vt in
                let varg =
                  match resolve vt with
                  | TInt _ | TUint _ ->
                    let tv = coerce ip trhs vt in
                    { e = ECastK (tv, TInt 64); ety = TInt 64; epos = ip }
                  | _ -> coerce ip trhs vt
                in
                mk (SExprK { e = ECallK (Printf.sprintf "zfy_map_put_%s_%s" kf vtag,
                                          [ marg; karg; varg ], []);
                             ety = TVoid; epos = p })
              | (_, None) ->
                terr ap "set does not support index assignment (use set_add(s, x))")
           | TPtr t ->
             if l.lconstp then
               terr ap "cannot write through pointer-to-const %s (declared T* const)" arr;
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
        | None -> terr ap "%s" (undef_fix env ap arr "variable"))
     | EIndex (base, idx, ip), _ ->
       (* 元素写入槽根泛化（w-014 #3）：字段链 bag.xs[i] / ref 参数解引用
          xs[i] / 嵌套元素槽 a[i][j]（EAddrOfK 元素槽地址）。
          string 字段/ref（bag.s[i] = c）走 SStrSetK 原地写 *)
       let root = seq_slot_root env base "index-assignment target" in
       (match resolve root.ety with
        | TString | TPtr TString ->
          let ti = to_i64 (check_expr env idx) in
          let trhs = check_expr env rhs in
          (match resolve trhs.ety with
           | TChar -> ()
           | t -> terr ip "string index assignment requires a char, got %s" (pp_zty t));
          mk (SStrSetK (root, ti, trhs))
        | _ ->
          let e = seq_elem_of_root env root ip in
          let grow = (match resolve root.ety with
                      | TList _ | TPtr (TList _) -> true | _ -> false) in
          let ti = to_i64 (check_expr env idx) in
          let trhs = check_expr env rhs in
          let trhs = coerce ip trhs e in
          mk (SSeqSetK (root, e, ti, trhs, grow)))
     | EField (b, seg, fp), _ ->
       (* 元素槽字段写入（w-014 #8）：ps[1].x = v——元素读求值后取槽地址
          （ESeqGetK → EAddrOfK），字段链写入该元素 *)
       (match b with
        | EIndex (EVar (arr, ap), _, _) ->
          (match lookup_var env arr with
           | Some l when l.lconst ->
             terr ap "cannot modify elements of constant %s (const is deeply immutable)" arr
           | _ -> ())
        | _ -> ());
       let tb = check_expr env b in
       (match tb.e with
        | ESeqGetK _ when (match resolve tb.ety with TStruct _ -> true | _ -> false) ->
          let root = { e = EAddrOfK tb; ety = TPtr tb.ety; epos = tb.epos } in
          let rootty = (match resolve tb.ety with
                        | TStruct s -> TStruct s | _ -> assert false) in
          let (fidxs, fty) = chain_fields env fp rootty [ seg ] in
          let trhs = check_expr env rhs in
          let trhs = coerce fp trhs fty in
          mk (SFieldSetK (root, fidxs, rootty, trhs))
        | _ ->
          terr fp "field assignment target must be a struct array/list element (ps[i].x = v)")
     | EDeref (pe, dp), _ ->
       (* p* = v：解引用写入。标量/指针目标直接 store；聚合目标
          （string/数组/列表，ref 参数整体赋值，w-014 #3）为引用槽
          整体替换：释放旧值 + 接管新值 *)
       check_constp env pe dp;
       let tp = check_expr env pe in
       (match resolve tp.ety with
        | TPtr t ->
          (match resolve t with
           | TInt _ | TUint _ | TFloat _ | TBool | TChar | TPtr _ ->
             let trhs = check_expr env rhs in
             let trhs = coerce dp trhs t in
             mk (SDerefSetK (tp, trhs))
           | TString | TList _ | TArray _ ->
             let trhs = check_expr env rhs in
             let trhs = coerce dp trhs t in
             mk (SDerefSetK (tp, trhs))
           | t' ->
             terr dp "dereference assignment supports only scalar/pointer/aggregate types, got %s" (pp_zty t'))
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
             let lty = l.lty in
             let trhs =
               (match resolve lty with
                | TFrac e when is_frac_arith rhs' ->
                  (* frac 变量赋值含 / 的算术（new.md 2026-10-11）：整棵按分数算 *)
                  check_frac_expr env rhs' e
                | _ -> check_expr env rhs')
             in
             let needs_norm =
               (match resolve lty with TFrac _ -> not l.lunred | _ -> false) in
             (match resolve trhs.ety, resolve lty with
              | TList e2, TArray (e, _) when resolve e2 = resolve e ->
                (* 数组/列表切片（TList 元素类型）赋给数组变量：运行时同为 seq，深拷贝 *)
                mk (SAssignK ({ e = EVarK slot; ety = trhs.ety; epos = p' }, trhs, false, false))
              | _, _ ->
                let trhs = coerce p' trhs lty in
                (* File move-only：变量到变量赋值 = 所有权转移（mir 侧清源槽） *)
                (match resolve lty, rhs' with
                 | TFile, EVar (n2, _) ->
                   (match lookup_var env n2 with
                    | Some src when resolve src.lty = TFile ->
                      Hashtbl.replace env.moved src.lslot ()
                    | _ -> ())
                 | _ -> ());
                (* s = s + p1 + ... + pn（T7 优化）：concat 链根为槽本身时
                   改原地追加（realloc 扩容，O(追加量) 免 O(总长) 全量拷贝）；
                   任一操作数引用槽本身则回退（realloc 可能移动缓冲区，
                   旧指针读悬垂）。texpr_uses_slot 对未知复合节点保守回退 *)
                let rec flat (te : texpr) acc =
                  match te.e with
                  | ECallK ("zfy_str_concat", [ l; r ], _) -> flat l (r :: acc)
                  | EVarK s when s = slot -> Some acc
                  | _ -> None
                in
                let rec uses_slot (te : texpr) : bool =
                  match te.e with
                  | EVarK s -> s = slot
                  | EIntK _ | EFloatK _ | EStrK _ | ECharK _ | EBoolK _ | ENullK _ -> false
                  | ECallK (_, args, _) | EIndirectCallK (_, args) ->
                    List.exists uses_slot args
                  | EBinK (_, a, b) | EUnwrapK (a, b) | EFracNewK (a, b) ->
                    uses_slot a || uses_slot b
                  | EUnK (_, a) | ECastK (a, _) | EFieldK (a, _) | EDerefK a
                  | EAddrOfK a | ESeqGetK (a, _) | ESeqLenK a | EErrOkK a
                  | EPropagateK a | ESplitK (a, _) | ESeqSliceK (a, _, _, _) ->
                    uses_slot a
                  | _ -> true
                in
                (match resolve lty, flat trhs [] with
                 | TString, Some (_ :: _ as parts) when not (List.exists uses_slot parts) ->
                   mk (SStrAppendK (slot, parts))
                 | _ ->
                   mk (SAssignK ({ e = EVarK slot; ety = trhs.ety; epos = p' }, trhs, needs_norm, false)))))
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
                   mk (SFieldSetK ({ e = EVarK l.lslot; ety = l.lty; epos = p' },
                                   idxs, l.lty, trhs))
                 | t -> terr p' "type %s does not support field assignment %s" (pp_zty t) name)
              | None -> terr p' "%s" (undef_fix env p' name "variable"))
           | None -> terr p' "%s" (undef_fix env p' name "variable")))
     | _ -> terr p "unsupported assignment target")
  | SAssignList (lhs, exprs, p) ->
    (* 序列字面量整体赋值（w-014 #3）：a = 1, 2, 3 / bag.xs = 1, 2 /
       ref 参数 xs = 新表——构造 ESeqLitK 临时 seq，走整体赋值路径 *)
    let mk_lit elem elems =
      { e = ESeqLitK (elem, elems); ety = TList elem; epos = p } in
    (match lhs with
     | EVar (name, p') ->
       (match lookup_var env name with
        | Some l ->
          if l.lconst then
            terr p' "cannot assign to constant %s (declared const)" name;
          Hashtbl.remove env.moved l.lslot;
          (match resolve l.lty with
           | TArray (e, _) | TList e as seqty ->
             let elems =
               List.map (fun ie -> coerce p (check_expr env ie) e) exprs in
             (match seqty with
              | TList _ -> mk (SAssignK ({ e = EVarK l.lslot; ety = TList e; epos = p' },
                                         mk_lit e elems, false, false))
              | TArray _ ->
                (* 定长数组目标：字面量长度须一致（整体替换语义） *)
                (match resolve l.lty with
                 | TArray (_, n) when List.length exprs <> n ->
                   terr p "array literal has %d elements but target length is %d"
                     (List.length exprs) n
                 | _ ->
                   mk (SAssignK ({ e = EVarK l.lslot; ety = TList e; epos = p' },
                                 mk_lit e elems, false, false))))
           | t -> terr p' "sequence literal assignment requires an array/list target, got %s" (pp_zty t))
        | None ->
          (* dotted 字段链目标：bag.xs = 1, 2 *)
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
                    | TList e ->
                      let elems =
                        List.map (fun ie -> coerce p (check_expr env ie) e) exprs in
                      mk (SFieldSetK ({ e = EVarK l.lslot; ety = l.lty; epos = p' },
                                      idxs, l.lty, mk_lit e elems))
                    | TArray (e, n) ->
                      if List.length exprs <> n then
                        terr p "array literal has %d elements but field length is %d"
                          (List.length exprs) n;
                      let elems =
                        List.map (fun ie -> coerce p (check_expr env ie) e) exprs in
                      mk (SFieldSetK ({ e = EVarK l.lslot; ety = l.lty; epos = p' },
                                      idxs, l.lty, mk_lit e elems))
                    | t -> terr p' "sequence literal assignment requires an array/list field, got %s" (pp_zty t))
                 | t -> terr p' "type %s does not support field assignment %s" (pp_zty t) name)
              | None -> terr p' "%s" (undef_fix env p' name "variable"))
           | None -> terr p' "%s" (undef_fix env p' name "variable")))
     | EDeref (pe, dp) ->
       (* ref 参数整体赋值：xs = 1, 2 / xs = 新表 *)
       check_constp env pe dp;
       let tp = check_expr env pe in
       (match resolve tp.ety with
        | TPtr (TList e) | TPtr (TArray (e, _)) ->
          let elems = List.map (fun ie -> coerce p (check_expr env ie) e) exprs in
          mk (SDerefSetK (tp, mk_lit e elems))
        | t ->
          terr dp "sequence literal assignment through ref requires a list parameter, got %s" (pp_zty t))
     | _ ->
       terr p "sequence literal assignment target must be a list variable, field, or ref parameter")
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
     | EUnwrap (a, EBlock (blk, _), wp) ->
       (* 裸解包块：a ?? 缩进块（块内通常 return/break/panic） *)
       (match e with
        | EUnwrap (a, EBlock (blk, _), wp) -> mk (check_unwrap env wp a blk `Discard)
        | _ -> assert false)
     | _ ->
       (* v3 2026-10-11 语句逻辑大改：表达式语句丢弃值即报错——cast/find/
          push/remove 等产值内建与用户函数只能作为表达式（赋给变量），
          output/input/close/write/writeln 等无返回值内建仍可裸用。
          例外：fail/panic（非局部退出，丢弃值即本意）；
          ?? 解包块内（块末兜底值表达式是块值来源） *)
       let te = check_expr env e in
       (match e, resolve te.ety with
        | (EFail _ | EPanic _), _ -> mk (SExprK te)
        | _, TVoid -> mk (SExprK te)
        | _, _ when env.in_unwrap -> mk (SExprK te)
        | _, t ->
          terr te.epos
            "statement discards a value of type %s (cast/find/push/remove and user functions return values; assign it to a variable: x = f(...))"
            (pp_zty t);
          mk (SExprK te)))
  | SReturn (e, p) ->
    (match e with
     | None ->
       unify p env.fncur_ret TVoid;
       mk (SReturnK None)
     | Some (EUnwrap (_, EBlock _, _) as e') ->
       (* return a ?? 缩进块：成功 → 直接返回成功聚合；失败 → 执行块，
          块末值 coerce 包装为返回类型后返回（w-015 #4） *)
       (match e' with
        | EUnwrap (a, EBlock (blk, wp), _) -> mk (check_unwrap env wp a blk `Return)
        | _ -> assert false)
     | Some e' ->
       let te =
         (match resolve env.fncur_ret with
          | TFrac e when is_frac_arith e' ->
            (* frac 函数 return 含 / 的算术（new.md 2026-10-11）：按分数算 *)
            check_frac_expr env e' e
          | _ -> check_expr env e')
       in
       let te = coerce p te env.fncur_ret in
       mk (SReturnK (Some te)))
  | SIf (cond, then_b, else_b, p) ->
    let tc = check_expr env cond in
    ignore (coerce p tc TBool);
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
    (* 条件与循环体一样每轮迭代执行：自动 move 门禁（ldepth）必须覆盖，
       否则"最后使用"误判清槽 → 下一轮迭代读到 null 崩溃（2026-10-16） *)
    env.ldepth <- env.ldepth + 1;
    let tc = check_expr env cond in
    env.ldepth <- env.ldepth - 1;
    ignore (coerce p tc TBool);
    push_scope env;
    env.ldepth <- env.ldepth + 1;
    let tb = check_block env body in
    env.ldepth <- env.ldepth - 1;
    pop_scope env;
    mk (SWhileK (tc, tb))
  | SFor (inits, cond, updates, body, p) ->
    (* for 头部声明的变量作用域覆盖循环所在的整个块：
       不再为 for 单开作用域，循环结束后变量仍然可见（可直接复用索引） *)
    let init_stmts =
      List.map
        (function
          | FIDecl (isc, f2, u2, name, ty_opt, e, p') ->
            { s = check_decl env p' isc f2 u2 name ty_opt e; spos = p' }
          | FIExpr (e, p') -> { s = SExprK (check_expr env e); spos = p' })
        inits
    in
    let tc =
      (* 同 SWhile：for 条件每轮执行，自动 move 门禁覆盖 *)
      env.ldepth <- env.ldepth + 1;
      let t = check_expr env cond in
      env.ldepth <- env.ldepth - 1;
      t
    in
    ignore (coerce p tc TBool);
    let up_stmts =
      (* update 子句同样每轮执行 *)
      env.ldepth <- env.ldepth + 1;
      let us = List.map (check_for_update env) updates in
      env.ldepth <- env.ldepth - 1;
      us
    in
    env.ldepth <- env.ldepth + 1;
    let tb = check_block env body in
    env.ldepth <- env.ldepth - 1;
    mk (SForK (init_stmts, tc, up_stmts, tb))
  | SForIn (name, seqx, body, p) ->
    (* for x in xs { }（v3.6）：xs 支持 列表/数组(变量)/string/map(产键)。
       降码：序列入临时槽（表达式只求值一次）+ 索引循环；循环变量每轮
       由元素读深拷贝（循环体内不自动 move），与手写三段式等价 *)
    let mkx k ety = { e = k; ety; epos = p } in
    let fresh nm lty : local =
      declare env nm { lconst = false; lty; lslot = ""; lunred = false;
                       lconstp = false };
      (match lookup_var env nm with Some l -> l | None -> assert false)
    in
    let ts = check_expr env seqx in
    let hoists, itv, elem =
      match resolve ts.ety with
      | TList e ->
        let it = fresh (name ^ "$seq") (TList e) in
        let h =
          match ts.e with
          | ECallK _ ->
            (* 运行时返回的新 seq：所有权接管，免深拷贝 *)
            SDeclK (false, it.lslot, TList e, ts, false)
          | _ ->
            SSeqCopyK (false, it.lslot, e, 0L, ts, true)
        in
        ([ { s = h; spos = p } ], mkx (EVarK it.lslot) (TList e), e)
      | TArray (e, _) ->
        (match ts.e with
         | EVarK _ -> ([], ts, e)
         | _ ->
           terr p "for-in over an array requires an array variable")
      | TString ->
        let it = fresh (name ^ "$seq") TString in
        ([ { s = SDeclK (false, it.lslot, TString, ts, false); spos = p } ],
         mkx (EVarK it.lslot) TString, TChar)
      | TStruct s when cont_kind s <> None ->
        let (kt, _) = cont_kv env.g s p in
        let marg = map_self_arg env p ts in
        let keys_call =
          mkx (ECallK ("zfy_map_keys", [ marg ], [])) (TList kt) in
        let ks = fresh (name ^ "$keys") (TList kt) in
        ([ { s = SDeclK (false, ks.lslot, TList kt, keys_call, false);
             spos = p } ],
         mkx (EVarK ks.lslot) (TList kt), kt)
      | t ->
        terr p "for-in requires a list/array/string/map, got %s" (pp_zty t)
    in
    let iv = fresh (name ^ "$i") (TInt 64) in
    let ivx = mkx (EVarK iv.lslot) (TInt 64) in
    let ev = fresh name elem in
    (* 索引变量声明（槽分配 + 初始化 0）必须落在 inits *)
    let hoists =
      hoists @ [ { s = SDeclK (false, iv.lslot, TInt 64,
                               mkx (EIntK 0L) (TInt 64), false);
                  spos = p } ]
    in
    let cond =
      (* length 语义：列表/数组 = ESeqLenK（i32，升位）；string = str_len
         调用（i64）——与手写 length() 的降码一致 *)
      let lenx =
        match resolve itv.ety with
        | TString ->
          mkx (ECallK ("str_len", [ itv ], [])) (TInt 64)
        | _ ->
          let len32 = mkx (ESeqLenK itv) (TInt 32) in
          mkx (ECastK (len32, TInt 64)) (TInt 64)
      in
      mkx (EBinK (BLt, ivx, lenx)) TBool in
    env.ldepth <- env.ldepth + 1;
    let tb = check_block env body in
    env.ldepth <- env.ldepth - 1;
    let elem_get =
      match resolve itv.ety with
      | TString -> mkx (ECallK ("zfy_str_char", [ itv; ivx ], [])) TChar
      | _ -> mkx (ESeqGetK (itv, ivx)) elem
    in
    mk (SForK (hoists, cond,
               [ { s = SAugVarK (iv.lslot, TInt 64, BAdd,
                                 mkx (EIntK 1L) (TInt 64), false);
                  spos = p } ],
               { s = SDeclK (false, ev.lslot, elem, elem_get, false);
                 spos = p } :: tb))
  | SOutput (args, sep, end_, p) ->
    let targs = List.map (check_expr env) args in
    List.iter
      (fun (ta : texpr) ->
        match resolve ta.ety with
        | TError -> ()   (* poison：不检查不转 string（n4） *)
        | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString | TFrac _ | TVar _ -> ()
        | TArray (_, _) | TList _ ->
          (* 数组/列表整体打印（w-013；w-015 #6 支持嵌套）：叶元素须为
             可打印标量/string；f16/f128 无打印运行时；列表的 i128 叶
             （8 字节槽放不下，定长数组可以）与 struct 叶不支持 *)
            let rec elem_ok depth (t : zty) =
              match t with
              | TBool | TChar | TString | TVar _ -> true
              | TInt w -> w <= 128
              | TUint w -> w <= 128
              | TFloat w -> w = 32 || w = 64
              | TArray (e, _) -> depth < 8 && elem_ok (depth + 1) e
              | TList e ->
                depth < 8 &&
                (match resolve e with
                 | TInt 128 | TUint 128 -> false
                 | e2 -> elem_ok (depth + 1) e2)
              | _ -> false
            in
            let rec first_bad depth (t : zty) : zty option =
              match t with
              | TBool | TChar | TString | TVar _ -> None
              | TInt _ | TUint _ | TFloat _ -> None
              | TArray (e, _) | TList e ->
                (match resolve e with
                 | (TInt 128 | TUint 128) when (match t with TList _ -> true | _ -> false) ->
                   Some (TInt 128)
                 | e2 -> first_bad (depth + 1) e2)
              | t2 -> Some t2
            in
            if not (elem_ok 0 (resolve ta.ety)) then
              (match first_bad 0 (resolve ta.ety) with
               | Some (TInt 128) ->
                 terr p "output does not support element type: %s (128-bit list elements are not supported)"
                   (pp_zty (TInt 128))
               | Some (TErr _) ->
                 terr p "output does not support element type: T! (error values are not printable)"
               | Some bad -> terr p "output does not support element type: %s" (pp_zty bad)
               | None -> terr p "output does not support this argument type")
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
             | None -> terr p' "%s" (undef_fix env p' name "variable")))
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
        | None -> terr p' "%s" (undef_fix env p' name "variable"))
     | _ -> terr p "reduce's first argument must be a frac-typed local variable")
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
  | SFn (nm, params, ret, is_frac, body, p') ->
    (* 嵌套函数（v3.7）：按命名 lambda 处理——注册闭包（隐式值捕获所在
       函数局部变量），名字绑定为局部闭包句柄变量。
       param -> lparam 形状复用 check_lambda；返回类型显式（parser 已保证） *)
    let lam =
      { lparams = List.map (fun (lp : lparam) ->
            match lp.lpty with
            | Some (TSeq _ | TSeqN _) -> terr lp.lppos "nested function parameters must be scalars"
            | t -> { lpname = lp.lpname; lpty = t; lppos = lp.lppos })
          params;
        lcaps = [];
        lbody = LBlock (body, ret) }
    in
    if is_frac then terr p' "nested functions do not support frac";
    let tcl = check_lambda env lam p' (Some nm) in
    (* 名字绑定为局部变量（闭包句柄）：声明即初始化 *)
    declare env nm
      { lconst = false; lty = tcl.ety; lslot = ""; lunred = false; lconstp = false };
    let slot =
      match lookup_var env nm with
      | Some l -> l.lslot | None -> assert false
    in
    mk (SDeclK (false, slot, tcl.ety, tcl, false))

(* for 更新项 -> 赋值语句 *)
and check_for_update env (u : for_update) : tstmt =
  match u with
  | FUAssign (l, r, p) -> check_stmt env (SAssign (l, r, p))
  | FUOp (op, l, r, p) -> check_stmt env (SAug (op, l, r, p))
  | FUInc (e, p) -> check_stmt env (SInc (e, p))
  | FUDec (e, p) -> check_stmt env (SDec (e, p))

and pos_of_stmt = function
  | SDecl (_, _, _, _, _, _, p) | SAssign (_, _, p) | SAssignList (_, _, p)
  | SAug (_, _, _, p)
  | SInc (_, p) | SDec (_, p)
  | SReturn (_, p) | SIf (_, _, _, p)
  | SWhile (_, _, p) | SFor (_, _, _, _, p) | SForIn (_, _, _, p) | SReduce (_, _, _, p)
  | SOutput (_, _, _, p) | SInput (_, _, p)
  | SSeqDecl (_, _, _, _, _, _, _, _, p)
  | SUnsafe (_, p)
  | SFn (_, _, _, _, _, p)
  | SBreak p
  | SContinue p -> p
  | SDeclList ss -> (match ss with s :: _ -> pos_of_stmt s | [] -> { file = ""; line = 0; col = 0 })
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
let builtin_names = [ "length"; "find"; "trim"; "split"; "replace"; "prec";
                      "open"; "read_all"; "read_line"; "write"; "writeln";
                      "close"; "exists"; "read_file"; "write_file"; "read_lines";
                      (* 时间内建（v3.3.6）+ 内建 datetime struct 名 *)
                      "now"; "tick_ms"; "sleep_ms"; "localtime"; "mktime";
                      "datetime" ]

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
      aliases = Hashtbl.create 16;
      gstructs = Hashtbl.create 8; gfns = Hashtbl.create 8;
      gtargs = Hashtbl.create 8; gstructpos = Hashtbl.create 8;
      closigs = Hashtbl.create 16 } in
  (* 内建 Err struct（解包块内 err 变量的类型）：code + msg。
     ErrCode 为虚拟常量命名空间（编译期查表），无对应 struct *)
  Hashtbl.replace g.structs "Err"
    { spacked = false;
      sfields = [ ("code", TInt 32, None); ("msg", TString, None) ] };
  (* 内建 datetime struct（v3.3.6 时间内建）：localtime 的返回类型，
     8×i32 与 runtime.c zfy_datetime 布局一致；用户不得重名（见 builtin_names） *)
  Hashtbl.replace g.structs "datetime"
    { spacked = false;
      sfields = [ ("year", TInt 32, None); ("month", TInt 32, None);
                  ("day", TInt 32, None); ("hour", TInt 32, None);
                  ("minute", TInt 32, None); ("second", TInt 32, None);
                  ("weekday", TInt 32, None); ("yday", TInt 32, None) ] };
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
      | IStruct { name; pos; tparams; _ } ->
        if Hashtbl.mem seen_structs name then
          terr pos "duplicate struct definition: %s" name
        else begin
          Hashtbl.add seen_structs name ();
          (* 泛型 struct 不入普通表（裸名 Box 报 undefined type） *)
          if tparams = [] then
            Hashtbl.replace g.structs name { spacked = false; sfields = [] }
        end
      | _ -> ())
    prog;
  (* 第一遍 A：按声明序登记 struct（字段类型只展开已声明 struct 的字段；
     函数签名引用 struct 同样要求已声明） *)
  let struct_pos : (string, pos) Hashtbl.t = g.gstructpos in
  List.iter
    (function
      | IStruct { name; packed; fields; pos; tparams } ->
        if List.mem name builtin_names then
          terr pos "struct name %s conflicts with a builtin, rename it" name;
        if Hashtbl.mem fn_names name then
          terr pos "%s is already a function and cannot also be a struct name" name;
        if tparams <> [] then begin
          (* 泛型 struct：存模板（实例化在 conv_ty/构造时惰性展开） *)
          if List.length (List.sort_uniq compare tparams) <> List.length tparams then
            terr pos "duplicate type parameter in %s" name;
          Hashtbl.replace g.gstructs name
            { gtp = tparams; gpacked = packed; gfields = fields; gpos = pos };
          Hashtbl.replace struct_pos name pos
        end
        else begin
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
               | TFile ->
                 terr sf.fpos "File cannot be a struct field (move-only handle)"
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
        end
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
      | IFn { name; params; ret; rfrac; runred; pos; body; tparams } ->
        if List.mem name builtin_names then
          terr pos "function name %s conflicts with a builtin, rename it" name;
        if tparams <> [] then begin
          (* 泛型函数：存模板（调用时按实参类型推断实例化，new2.md 第2条） *)
          if name = "main" then
            terr pos "main cannot be a generic function";
          if Hashtbl.mem g.fns name || Hashtbl.mem g.gfns name then
            terr pos "duplicate function definition: %s" name;
          if List.length (List.sort_uniq compare tparams) <> List.length tparams then
            terr pos "duplicate type parameter in %s" name;
          if runred then
            terr pos "generic functions do not support an unred return type";
          List.iter
            (fun (pd : param) ->
              if pd.pref then
                terr pd.ppos "generic functions do not support ref parameters";
              match pd.pseq with
              | PArray len ->
                (match len with
                 | EInt _ -> ()
                 | _ ->
                   terr pd.ppos "generic function array parameter length must be a literal")
              | _ -> ())
            params;
          Hashtbl.replace g.gfns name
            { gtp = tparams; gparams = params; gret = ret; grfrac = rfrac;
              gbody = body; gpos = pos }
        end
        else begin
        if Hashtbl.mem g.fns name then
          terr pos "duplicate function definition: %s" name;
        let prev = ref [] in
        let ptys =
          List.map
            (fun (pd : param) ->
              let t = conv_param g pos !prev pd in
              prev := pd.pname :: !prev;
              if pd.pref then begin
                (* ref 参数（new2.md #1 / w-014 #1）：签名侧降为指针（调用方
                   传地址）；标量/string/数组/列表——seq 槽引用使函数内
                   push/元素写直接作用于调用方列表。
                   v3.2：struct 也支持 ref（随机数模块方法依赖）——字段
                   访问经指针自动解引用 *)
                (match resolve t with
                 | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString
                 | TList _ | TArray _ | TStruct _ -> ()
                 | _ ->
                   terr pd.ppos "ref parameters support scalar/string/array/list/struct types only (got %s)"
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
        Hashtbl.replace g.fns name { params = ptys; prefs; ret = rty; runred }
        end
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
             | TList _ | TArray _ ->
               terr f.epos "extern functions do not support array/list return types (zfy seq is not a C type)"
             | _ -> ());
            Hashtbl.replace g.fns f.ename
              { params = ptys; prefs = List.map (fun _ -> false) ptys; ret = rty; runred = false };
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
      in_unsafe = false; in_unwrap = false; moved = Hashtbl.create 8; uses = [];
      ldepth = 0; capctx = None }
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
            | SDecl (true, false, false, name, ty, init, p) ->
              (* 顶层 const：编译期常量（整数使用处内联，保持原语义） *)
              if lookup_var env name <> None then
                terr p "duplicate top-level constant: %s" name;
              let _t : tstmt = { s = check_decl env p true false false name ty init; spos = p } in
              (match lookup_var env name with
               | Some l ->
                 (match resolve l.lty with
                  | TInt _ | TUint _ -> ()
                  | _ -> terr p "top-level const currently supports only integer types, got %s" (pp_zty l.lty))
               | None -> ())
            | SDecl (true, is_frac, is_unred, name, ty, init, p) ->
              (* 顶层 const frac/unred（w-015 #5）：按全局常量槽处理——
                 槽名 @g.<名>、lconst=true（赋值被拒）、ginit 初始化，
                 不做整数内联。const+frac 在函数内已合法（check_decl 支持） *)
              if lookup_var env name <> None then
                terr p "duplicate top-level constant: %s" name;
              let st = { s = check_decl env p true is_frac is_unred name ty init; spos = p } in
              let lty = (match lookup_var env name with Some l -> l.lty | None -> assert false) in
              let slot = "@g." ^ name in
              set_global_slot name slot;
              gdeclared := (slot, lty) :: !gdeclared;
              ginit :=
                { st with
                  s = (match st.s with
                       | SDeclK (c, _, t, e, nn) -> SDeclK (c, slot, t, e, nn)
                       | s' -> s') } :: !ginit
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
            | SSeqDecl (isconst, is_frac, is_unred, name, ety, len, is_list, inits, p) ->
              (* 顶层数组/列表：全局可变变量（const 也可，元素修改受 const 约束） *)
              if lookup_var env name <> None then
                terr p "duplicate top-level variable: %s" name;
              let st =
                { s = check_seq_decl env p isconst is_frac is_unred name
                          (conv_ty env.g p ety) len is_list inits; spos = p } in
              let lty = (match lookup_var env name with Some l -> l.lty | None -> assert false) in
              let slot = "@g." ^ name in
              set_global_slot name slot;
              gdeclared := (slot, lty) :: !gdeclared;
              ginit :=
                { st with
                  s = (match st.s with
                       | SSeqDeclK (c, _, t, l2, isl, inits', enn) -> SSeqDeclK (c, slot, t, l2, isl, inits', enn)
                       | SSeqCopyK (c, _, t, l2, src, isl) -> SSeqCopyK (c, slot, t, l2, src, isl)
                       | s' -> s') } :: !ginit
            | _ -> ())
         with TypeError (p, m) -> collected := (p, m) :: !collected)
      | _ -> ())
    prog;
  (* 函数体检查（普通函数与泛型实例共用）：独立成函数，供泛型调用钩子
     在任意检查点按需实例化并立即检查（检查期间保存/恢复外层状态，
     避免污染进行中的函数体） *)
  let check_one_fn name (params : param list) body pos : tfn option =
    let depth = List.length env.scopes in
    let saved_uses = env.uses in
    let saved_fnvars = env.fnvars in
    let saved_moved = env.moved in
    let saved_ret = env.fncur_ret in
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
                      { lconst = pd.pconst; lty = pty; lslot = "";
                        lunred = pd.punred;
                        lconstp = (match pd.pty with TPtrC _ -> true | _ -> false) };
                    let slot = (match lookup_var env pd.pname with
                                | Some l -> l.lslot | None -> assert false) in
                    (false, slot, pty, pd.punred))
                  params sig_.params
              in
              let refnames =
                List.filter_map (fun (pd : param) -> if pd.pref then Some pd.pname else None) params in
              let body1 =
                if refnames = [] then body else deref_refs refnames body in
              (* main 特例（new.md）：返回类型隐含 i32，裸 return 等价 return 0，
                 落到函数末尾由 MIR 隐式 TRet None → ret i32 0 *)
              let body' =
                if name = "main" then
                  List.map
                    (function
                      | SReturn (None, p) -> SReturn (Some (EInt (0L, p)), p)
                      | st -> st)
                    body1
                else body1 in
              (* 自动 move 判定数据：函数体内全部变量出现位置（new2.md #1） *)
              env.uses <- List.rev (List.fold_left uses_of_stmt [] body');
              let tbody = check_block env body' in
              pop_scope env;
              (* 返回类型非 void 时，要求有 return 或尾表达式（main 豁免：
                 隐式 return 0） *)
              if name <> "main" &&
                 (match sig_.ret with TVoid -> false | _ -> true) then begin
                let has_ret =
                  List.exists (fun (s : tstmt) ->
                    match s.s with
                    | SReturnK _ -> true
                    | SUnwrapBlockK (_, true, _, _, _, _, _) -> true   (* return a ?? 块 *)
                    | _ -> false) tbody
                  ||
                  (match List.rev tbody with
                   | { s = SExprK _; _ } :: _ -> true
                   | _ -> false)
                in
                if not has_ret then
                  terr pos "function %s declares return type %s but may not return a value"
                    name (pp_zty sig_.ret)
              end;
              Some { fname = name; fparams = tparams; fret = sig_.ret;
                     frunred = sig_.runred; fbody = tbody }
            with TypeError (p, m) ->
              collected := (p, m) :: !collected;
              None
          in
    env.uses <- saved_uses;
    env.fnvars <- saved_fnvars;
    env.moved <- saved_moved;
    env.fncur_ret <- saved_ret;
    while List.length env.scopes > depth do pop_scope env done;
    r
  in
  (* 泛型函数调用钩子：按实参 zty 推断类型实参 → 实例化签名注册
     （mangled 名，如 first$i32）→ 检查实例函数体；幂等（递归调用
     直接命中已注册签名）。实例函数体收集到 generic_fns_acc，
     随 hfns 一起下传代码生成 *)
  let generic_fns_acc = ref [] in
  let hook_impl env name argtys p =
      let gf = Hashtbl.find env.g.gfns name in
      if List.length argtys <> List.length gf.gparams then
        terr p "function %s expects %d arguments, got %d"
          name (List.length gf.gparams) (List.length argtys);
      (* 字面量实参 ety 为未求解 TVar：推断时落默认类型（int→i64、float→f64） *)
      let argtys =
        List.map
          (fun (t : texpr) ->
            match t.e, resolve t.ety with
            | EIntK _, TVar _ -> TInt 64
            | EFloatK _, TVar _ -> TFloat 64
            | _, z -> z)
          argtys
      in
      let mref = ref [] in
      (* 期望类型提示：先从声明的返回类型（如 Box<i32>）反推类型实参
         （返回类型 Box<T> 匹配期望 Box$i32 → T=i32），参数推断随之校验 *)
      let expect = !expect_hint in
      expect_hint := None;
      (match expect, gf.gret with
       | Some ez, Some rt ->
         ignore (match_gty env.g gf.gtp p rt ez mref)
       | _ -> ());
      let lit_default z = match resolve z with TInt 64 | TFloat 64 -> true | _ -> false in
      List.iter2
        (fun (pd : param) z ->
          if not (match_param env.g gf.gtp p pd z mref) then begin
            (* 字面量默认型（int→i64/float→f64）与期望绑定的实参冲突：
               字面量可按实例参数类型重解释，放行（coerce 处对字面量 unify） *)
            if lit_default z && List.for_all (fun tp -> List.assoc_opt tp !mref <> None) gf.gtp then ()
            else terr p "cannot infer type argument for parameter %s of %s (got %s)"
              pd.pname name (pp_zty (resolve z))
          end)
        gf.gparams argtys;
      List.iter
        (fun tp ->
          if List.assoc_opt tp !mref = None then
            terr p "cannot infer type argument for %s (in call to %s)" tp name)
        gf.gtp;
      let mapl = List.map (fun tp -> (tp, List.assoc tp !mref)) gf.gtp in
      let mangle =
        name ^ "$" ^ String.concat "$" (List.map (fun (_, z) -> tag_of_zty z) mapl) in
      if not (Hashtbl.mem g.fns mangle) then begin
        let iparams =
          List.map
            (fun (pd : param) -> { pd with pty = subst_ty_ast mapl pd.pty })
            gf.gparams
        in
        let prev = ref [] in
        let ptys =
          List.map
            (fun (pd : param) ->
              let t = conv_param g p !prev pd in
              prev := pd.pname :: !prev;
              t)
            iparams
        in
        let rty =
          match gf.gret with
          | None -> TVoid
          | Some t ->
            let base = conv_ty g gf.gpos (subst_ty_ast mapl t) in
            if gf.grfrac then begin
              if not (frac_elem_ok base) then
                terr gf.gpos "frac return type does not support element type %s" (pp_zty base);
              TFrac base
            end else base
        in
        Hashtbl.replace g.fns mangle
          { params = ptys; prefs = List.map (fun _ -> false) ptys; ret = rty;
            runred = false };
        (match check_one_fn mangle iparams gf.gbody gf.gpos with
         | Some tf -> generic_fns_acc := !generic_fns_acc @ [ tf ]
         | None -> ())
      end;
      mangle
  in
  generic_call_hook := hook_impl;
  let hfns =
    List.filter_map
      (function
        | IFn { name; params; body; pos; tparams; _ } when tparams = [] ->
          check_one_fn name params body pos
        | _ -> None)
      prog
  in
  (* 必须有 main *)
  if not (Hashtbl.mem g.fns "main") then
    terr { file = ""; line = 1; col = 1 } "missing main()";
  (* 泛型实例化可能新增 struct（Box<i32> 等）：复检循环嵌套
     （A<i32> 含 B<i32>、B<i32> 含 A<i32> 的跨实例值环） *)
  Hashtbl.reset visiting;
  Hashtbl.reset finished;
  Hashtbl.iter (fun name _ -> visit name) g.structs;
  (* 类型变量求解落地 *)
  let is_fl = function TFloat _ -> true | _ -> false in
  let is_ii = function TInt _ | TUint _ | TChar -> true | _ -> false in
  let flw = function TFloat w -> w | _ -> 64 in
  (* 把整型字面量子树重打为 w 位浮点：子树仅含字面量节点（typeck 已保证
     变量侧不会与浮点混算），重打型安全——后端按 ety 发对应常量 *)
  let rec floatify (w : int) (x : texpr) : texpr =
    let x' =
      match x.e with
      | EBinK (op, a, b) -> EBinK (op, floatify w a, floatify w b)
      | EUnK (op, u) -> EUnK (op, floatify w u)
      | _ -> x.e
    in
    let ety =
      match subst_ty x.ety with
      | TFloat _ -> x.ety
      | _ -> TFloat w
    in
    { x with e = x'; ety }
  in
  let rec fix_texpr (e : texpr) : texpr =
    let ety0 = subst_ty e.ety in
    (* 浮点字面量未被上下文约束时，默认应为 f64 而非 i64 *)
    let ety =
      match e.e, ety0 with
      | EFloatK _, TInt 64 -> TFloat 64
      | _, _ -> ety0
    in
    let e', ety =
      match e.e with
      | EBigK d ->
        (* 大字面量（w-014 #6）：期望上下文未落到 i128/u128（如裸表达式
           语句/算术操作数）即报错；合法时保留由后端按 i128 字面量发射 *)
        let e' =
          (match ety with
           | TInt 128 | TUint 128 -> EBigK d
           | _ ->
             terr e.epos "large integer literal %s requires an i128/u128 context" d)
        in
        (e', ety)
      | EBinK (op, a, b) ->
        (* v3.3.1：子节点混浮点/整型（typeck 已保证整型侧必为字面量子树）
           → 整型侧重打浮点；节点自身落默认整数型（未约束 TVar 组：
           output 实参/裸表达式语句等无约束上下文）时提升为同宽浮点，
           消除 f64/i64 混算坏 IR *)
        let a' = fix_texpr a and b' = fix_texpr b in
        let lift t = match ety with TInt _ | TUint _ -> t | _ -> ety in
        if is_fl a'.ety && is_ii b'.ety then
          let w = flw a'.ety in
          (EBinK (op, a', floatify w b'), lift (TFloat w))
        else if is_ii a'.ety && is_fl b'.ety then
          let w = flw b'.ety in
          (EBinK (op, floatify w a', b'), lift (TFloat w))
        else if is_fl a'.ety && is_fl b'.ety then
          (EBinK (op, a', b'), lift a'.ety)
        else (EBinK (op, a', b'), ety)
      | EUnK (op, u) ->
        (* 一元负号同理：子节点浮点而节点落默认整数型 → 节点提升浮点 *)
        let u' = fix_texpr u in
        if is_fl u'.ety && (match ety with TInt _ | TUint _ -> true | _ -> false)
        then (EUnK (op, u'), u'.ety)
        else (EUnK (op, u'), ety)
      | ECallK (c, args, moves) ->
        (* abs 延迟定型（v3.3.2）：调用未被上下文约束（ety 落默认 i64）
           而实参为浮点时，调用型随实参对齐（llvmgen 的 abs 按实参分发、
           output 按实参选打印器——错位会产 print_i64(double) 非法 IR） *)
        let args' = List.map fix_texpr args in
        let ety =
          match c, args', ety with
          | "abs", [ a ], TInt 64 when is_fl a.ety -> a.ety
          | _, _, _ -> ety
        in
        (ECallK (c, args', moves), ety)
      | ECastK (a, t) -> (ECastK (fix_texpr a, subst_ty t), ety)
      | EFracNewK (a, b) -> (EFracNewK (fix_texpr a, fix_texpr b), ety)
      | ESeqGetK (a, i) -> (ESeqGetK (fix_texpr a, fix_texpr i), ety)
      | ESeqLenK a -> (ESeqLenK (fix_texpr a), ety)
      | ESeqSliceK (a, b, c, d) ->
        (ESeqSliceK (fix_texpr a, fix_texpr b, fix_texpr c, fix_texpr d), ety)
      | ESplitK (a, c) -> (ESplitK (fix_texpr a, fix_texpr c), ety)
      | ESeqLitK (t, es) -> (ESeqLitK (subst_ty t, List.map fix_texpr es), ety)
      | EPushK (a, v) -> (EPushK (fix_texpr a, fix_texpr v), ety)
      | ERemoveK (a, i, isl) -> (ERemoveK (fix_texpr a, fix_texpr i, isl), ety)
      | EStructNewK (s, args) -> (EStructNewK (s, List.map fix_texpr args), ety)
      | EFieldK (b, i) -> (EFieldK (fix_texpr b, i), ety)
      | ENullK -> (ENullK, ety)
      | EAddrOfK a -> (EAddrOfK (fix_texpr a), ety)
      | EDerefK a -> (EDerefK (fix_texpr a), ety)
      | EIndirectCallK (f, args) ->
        (EIndirectCallK (fix_texpr f, List.map fix_texpr args), ety)
      | EFailK (c, m) -> (EFailK (fix_texpr c, fix_texpr m), ety)
      | EPanicK (c, m) -> (EPanicK (Option.map fix_texpr c, fix_texpr m), ety)
      | EUnwrapK (a, b) -> (EUnwrapK (fix_texpr a, fix_texpr b), ety)
      | EPropagateK a -> (EPropagateK (fix_texpr a), ety)
      | EErrOkK a -> (EErrOkK (fix_texpr a), ety)
      | EFindK (s, c, k) -> (EFindK (fix_texpr s, fix_texpr c, fix_texpr k), ety)
      | EClNewK (m, ce, items) ->
        (EClNewK (m, ce, List.map fix_texpr items), ety)
      | EClCallK (cb, args) ->
        (EClCallK (fix_texpr cb, List.map fix_texpr args), ety)
      | k -> (k, ety)
    in
    { e = e'; ety; epos = e.epos }
  in
  let rec fix_stmt (s : tstmt) : tstmt =
    let s' =
      match s.s with
      | SDeclK (c, n, t, e, nn) ->
        SDeclK (c, n, subst_ty t, fix_texpr e, nn)
      | SSeqDeclK (c, n, t, len, isl, inits, enn) ->
        SSeqDeclK (c, n, subst_ty t, len, isl, List.map fix_texpr inits, enn)
      | SSeqCopyK (c, n, t, len, src, isl) ->
        SSeqCopyK (c, n, subst_ty t, len, fix_texpr src, isl)
      | SAssignK (a, b, nn, mv) -> SAssignK (fix_texpr a, fix_texpr b, nn, mv)
      | SStrAppendK (n, parts) -> SStrAppendK (n, List.map fix_texpr parts)
      | SAugIndexK (r, t, i, op, v, g) ->
        SAugIndexK (fix_texpr r, subst_ty t, fix_texpr i, op, fix_texpr v, g)
      | SAugVarK (n, t, op, v, nn) ->
        SAugVarK (n, subst_ty t, op, fix_texpr v, nn)
      | SAugSliceK (n, t, a, b, st, op, v) ->
        SAugSliceK (n, subst_ty t, fix_texpr a, fix_texpr b, fix_texpr st, op,
                    fix_texpr v)
      | SSeqSetK (r, t, i, v, g) ->
        SSeqSetK (fix_texpr r, subst_ty t, fix_texpr i, fix_texpr v, g)
      | SStrSetK (r, i, v) -> SStrSetK (fix_texpr r, fix_texpr i, fix_texpr v)
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
      | SUnwrapBlockK (d, r, n, t, a, es, b) ->
        SUnwrapBlockK (d, r, n, subst_ty t, fix_texpr a, es, List.map fix_stmt b)
      | SFieldSetK (r, idxs, rt, v) ->
        SFieldSetK (fix_texpr r, idxs, subst_ty rt, fix_texpr v)
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
    (* 泛型实例化（first$i32 等）与 lambda 实例（lambda$N / wrapper）一并下传；
       检查期间嵌套 lambda 可能继续追加——循环取空 *)
    let rec drain acc =
      let newfns = !lambda_out_acc in
      lambda_out_acc := [];
      let all = acc @ newfns in
      if newfns = [] then all else drain all
    in
    List.map
      (fun (f : tfn) ->
        { f with
          fparams = List.map (fun (m, n, t, u) -> (m, n, subst_ty t, u)) f.fparams;
          fret = subst_ty f.fret;
          fbody = List.map fix_stmt f.fbody })
      (hfns @ !generic_fns_acc @ drain [])
  in
  { hfns; hglobals = List.rev !gdeclared; ginit = List.map fix_stmt (List.rev !ginit);
    hstructs = structs_list g }
