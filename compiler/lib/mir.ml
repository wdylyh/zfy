(* MIR：基本块 + 三地址码；含常量折叠与死代码消除 *)
open Tokens
open Hir

exception MirError of pos * string

let merr p fmt = Printf.ksprintf (fun s -> raise (MirError (p, s))) fmt

type operand = { o : op_kind; oty : zty }
and op_kind =
  | OInt of int64
  | OFloat of float
  | OStr of string
  | OBool of bool
  | OChar of char
  | OLocal of string

type term =
  | TBr of int
  | TCondBr of operand * int * int
  | TRet of operand option
  | TUnreachable

type instr =
  | MCopy of string * operand * zty              (* 槽位写入（聚合为 memcpy/克隆） *)
  | MMoveSeq of string * operand * zty           (* 所有权转移：释放目标旧值后直接接管临时指针（免克隆）；string/数组/列表 *)
  | MClear of string * zty                       (* move 后清空变量槽（store null，防 RAII 双释放） *)
  | MBinop of string * binop * operand * operand
  | MUnop of string * unop * operand
  | MCast of string * operand * zty
  | MCall of string option * string * operand list * zty
  | MCallOwn of string option * string * (operand * bool) list * zty * (string * zty) list
    (* 用户函数调用（所有权传参）：每个 string/数组/列表实参带 move 标志——
       true 直接移交（免克隆），false 由调用方克隆（保持值语义）；
       最后一项为 move 的变量实参（调用后需清槽）；frac 始终借传 *)
  | MThrow of operand                            (* throw：抛出 string 消息 *)
  | MTryFrame of string                          (* try 帧缓冲（入口 alloca） *)
  | MTrySetup of string * string                 (* setjmp：结果（非 0=异常路径）, 帧 *)
  | MTryLeave                                    (* 正常离开 try：弹出异常帧 *)
  | MTryMsg of string * zty                      (* catch 取异常消息（所有权移交目标槽） *)
  | MAlloca of string * zty                      (* 变量槽（入口块统一分配�?*)
  | MFracNew of string * zty * operand * operand (* 分数字面量：�? frac 类型, 分子, 分母 *)
  | MNorm of string * zty                        (* frac 槽约分：调用 zfy_frac_norm_<suf> *)
  | MSeqRemove of string * zty * operand * bool  (* remove：槽, 元素类型, 下标, 是否列表 *)
  | MAugSlice of string * zty * operand * operand * operand * binop * operand
    (* a[x,y:st] op= v：槽, 元素类型, 起点, 终点, 步长, 运算, 右值（逐元素原地） *)
  | MReduce of string * zty * operand * operand  (* reduce(root, frac 类型, 次数, 起始除数) *)
  | MPrintStr of string                          (* output：输出字符串字面�?*)
  | MPrintVal of operand                         (* output：按类型输出一个�?*)
  | MInput of string * zty * operand             (* input：delim 是 string 值（空串 = 默认换行和空白字符集） *)
  | MFreeVar of string * zty                     (* RAII：作用域退出释放变量持有的资源 *)
  | MFreeTemp of string                          (* 语句末释放临时堆�?*)
  | MFreeSeqTemp of string * bool                (* 语句末释放临�?seq（bool=元素是否 string�?*)
  | MSeqAlloc of string * zty * int64 * bool
    (* 数组/列表分配：槽, 元素类型, 长度(列表�?0→编译器自选初始容�?, 是否列表 *)
  | MSeqSet of string * zty * operand * operand * bool
    (* arr[i]=v：槽, 元素类型(决定写入宽度), 下标, �? 可扩�?*)
  | MSeqGet of string * operand * operand * zty  (* 读元素到临时：目�? 数组, 下标, 元素类型 *)
  | MSeqLen of string * operand                  (* length(x)：目标临�? 数组/列表 *)
  | MSeqSlice of string * operand * operand * operand * operand * bool
    (* base[a,b:step]：目标临�?seq 指针), �? 起点, 终点, 步长, 元素是否 string *)

type block = { bid : int; mutable body : instr list; mutable term : term option }

type mfn = {
  mname : string;
  mparams : (string * zty) list;
  mret : zty;
  mentry : int;
  mblocks : block list;
}

type mir = { mfns : mfn list }

(* ---------- 降码上下�?---------- *)

type lctx = {
  blocks : (int, block) Hashtbl.t;
  mutable nb : int;
  mutable nt : int;
  mutable cur : block;
  mutable loops : (int * int * int) list;  (* (break 目标, continue 目标, 循环体作用域深度) *)
  mutable scopes : (string * zty) list ref list;  (* RAII 作用域栈：每层收集需释放变量 *)
  mutable stmt_temps : (string * bool * bool) list;  (* 当前语句拥有的临时：(名, 是否 seq, seq 元素是否 string) *)
  mutable loop_ids : int list;             (* 循环体标识栈（move 分析用：当前处于哪些循环体内） *)
  occ_tbl : (string, int) Hashtbl.t;       (* 全函数变量出现次数（move 分析用） *)
  fresh_tbl : (string, int) Hashtbl.t;     (* 变量名 -> 声明时所在循环体标识 *)
}

let new_block l =
  let b = { bid = l.nb; body = []; term = None } in
  Hashtbl.replace l.blocks b.bid b;
  l.nb <- l.nb + 1;
  b

let emit l i = l.cur.body <- i :: l.cur.body

let set_term l t = if l.cur.term = None then l.cur.term <- Some t

let fresh l = l.nt <- l.nt + 1; Printf.sprintf "%%t%d" l.nt

(* 循环体标识（move 分析：判定变量是否为循环体内每轮重新声明的"新鲜"变量） *)
let loop_counter = ref 0
let fresh_loop_id () = incr loop_counter; !loop_counter

let op k t = { o = k; oty = t }

(* 需 RAII 释放的变量类型：string（堆串）、数组/列表（seq 资源）。
   全局变量槽（'@' 前缀）不属于函数作用域，永不释放 *)
let owned_ty (name : string) (t : zty) =
  match t with
  | TString | TArray _ | TList _ -> name.[0] <> '@'
  | _ -> false

(* 在当前作用域登记需 RAII 释放的变量（后声明先释放） *)
let declare_owned l name ty =
  if owned_ty name ty then
    match l.scopes with
    | top :: _ -> top := (name, ty) :: !top
    | [] -> ()

(* 登记本语句产生的临时（语句末统一释放） *)
let add_temp l name is_seq is_str =
  l.stmt_temps <- (name, is_seq, is_str) :: l.stmt_temps

(* 临时 move 优化：若 v 是本语句产生的 owned 临时（string/seq，语句末才释放、
   此后不再被引用），则将所有权直接转移给目标变量——释放目标旧值后
   store 临时指针，免去整体克隆。临时从 stmt_temps 移除（不再释放）。
   返回是否发生了 move（发生时调用方不再 emit MCopy）。 *)
let move_owned_temp l (name : string) (v : operand) (ty : zty) : bool =
  match v.o, ty with
  | OLocal d, (TString | TArray _ | TList _) ->
    let rec go acc = function
      | [] -> false
      | (n, is_seq, is_str) :: rest when n = d ->
        l.stmt_temps <- List.rev_append acc rest;
        emit l (MMoveSeq (name, v, ty));
        true
      | x :: rest -> go (x :: acc) rest
    in
    go [] l.stmt_temps
  | _ -> false

(* 用户调用实参的可移动性：string/数组/列表实参若满足
   ① 是本语句临时（split/切片/调用结果等），或
   ② 是全函数仅出现一次的局部变量，且不在循环内（或在最内层循环体内声明，
      每轮迭代重新初始化）
   则可 move（免克隆，所有权移交被调函数）。返回 (move?, 变量清槽项) *)
let arg_moveable l (v : operand) : bool * (string * zty) option =
  let owned = match v.oty with TString | TArray _ | TList _ -> true | _ -> false in
  if not owned then (false, None)
  else
    match v.o with
    | OLocal d when String.length d > 0 && d.[0] = '%' ->
      (* 本语句临时（%临时名）：直接移交 *)
      let rec go acc = function
        | [] -> (false, None)
        | (n, _, _) :: rest when n = d ->
          l.stmt_temps <- List.rev_append acc rest;
          (true, None)
        | x :: rest -> go (x :: acc) rest
      in
      go [] l.stmt_temps
    | OLocal n when n.[0] <> '@' ->
      let occ = match Hashtbl.find_opt l.occ_tbl n with Some c -> c | None -> 0 in
      let loop_fresh =
        match l.loop_ids with
        | [] -> true
        | top :: _ -> Hashtbl.find_opt l.fresh_tbl n = Some top
      in
      if occ = 1 && loop_fresh then (true, Some (n, v.oty)) else (false, None)
    | _ -> (false, None)

(* 语句结束：释放本语句拥有的临时（若当前块已终结则放弃——控制流边界�?   return 路径的所有权随返回转移，由调用方先行清空�?*)
let finish_stmt_temps l =
  let ts = List.rev l.stmt_temps in
  l.stmt_temps <- [];
  if l.cur.term = None then
    List.iter
      (fun (n, is_seq, is_str) ->
        if is_seq then emit l (MFreeSeqTemp (n, is_str)) else emit l (MFreeTemp n))
      ts

(* RAII：从作用域栈顶释放到深度 depth（不含），内层作用域先释放�?   层内后声明先释放；skip 中的变量名不释放（如�?return 转移的返回值） *)
let emit_frees_from_skip l depth skip =
  let rec go = function
    | [] -> ()
    | top :: rest when List.length rest >= depth ->
      List.iter
        (fun (n, t) -> if not (List.mem n skip) then emit l (MFreeVar (n, t)))
        !top;
      go rest
    | _ -> ()
  in
  go l.scopes

let emit_frees_from l depth = emit_frees_from_skip l depth []

(* frac 运行时函数名（运算结果由运行时自动约分到最简�?*)
let frac_rt_name (bop : binop) (elem : zty) : string =
  let opname =
    match bop with
    | BAdd -> "add" | BSub -> "sub" | BMul -> "mul" | BDiv -> "div"
    | BEq -> "eq" | BNe -> "ne" | BLt -> "lt" | BGt -> "gt" | BLe -> "le"
    | BGe -> "ge"
    | _ -> merr { line = 0; col = 0 } "frac 不支持该运算"
  in
  Printf.sprintf "zfy_frac_%s_%s" opname (Hir.suffix_of elem)

(* ---------- 表达式降�?---------- *)

let rec lexpr l (e : texpr) : operand =
  match e.e with
  | EIntK n ->
    (match e.ety with
     | TFloat _ -> op (OFloat (Int64.to_float n)) e.ety
     | _ -> op (OInt n) e.ety)
  | EFloatK f -> op (OFloat f) e.ety
  | EStrK s -> op (OStr s) e.ety
  | ECharK c -> op (OChar c) e.ety
  | EBoolK b -> op (OBool b) e.ety
  | EVarK n -> op (OLocal n) e.ety
  | EFracNewK (a, b) ->
    let oa = lexpr l a and ob = lexpr l b in
    let d = fresh l in
    emit l (MFracNew (d, e.ety, oa, ob));
    op (OLocal d) e.ety
  | EBinK (b, a, b') ->
    (* and/or 短路求值：b' 只在需要时求值（避免 arr[i] 越界等副作用�?*)
    if e.ety = TBool && (b = BAnd || b = BOr) then begin
      let slot = fresh l in
      emit l (MAlloca (slot, TBool));
      let oa = lexpr l a in
      let brhs = new_block l and bshort = new_block l and bend = new_block l in
      (if b = BAnd then
         set_term l (TCondBr (oa, brhs.bid, bshort.bid))
       else
         set_term l (TCondBr (oa, bshort.bid, brhs.bid)));
      l.cur <- brhs;
      let ob = lexpr l b' in
      emit l (MCopy (slot, ob, TBool));
      set_term l (TBr bend.bid);
      l.cur <- bshort;
      emit l (MCopy (slot, op (OBool (b = BOr)) TBool, TBool));
      set_term l (TBr bend.bid);
      l.cur <- bend;
      op (OLocal slot) TBool
    end
    else
    let oa = lexpr l a and ob = lexpr l b' in
    (match e.ety with
     | TFrac elem ->
       (* 分数四则：调用运行时函数（sret），结果自动约分 *)
       let d = fresh l in
       emit l (MCall (Some d, frac_rt_name b elem, [ oa; ob ], e.ety));
       op (OLocal d) e.ety
     | TBool when List.mem b [ BEq; BNe; BLt; BGt; BLe; BGe ]
                  && (match a.ety with TFrac _ -> true | _ -> false) ->
       (* 分数比较 *)
       let elem = (match a.ety with TFrac x -> x | _ -> assert false) in
       let d = fresh l in
       emit l (MCall (Some d, frac_rt_name b elem, [ oa; ob ], TBool));
       op (OLocal d) TBool
     | _ ->
       let d = fresh l in
       emit l (MBinop (d, b, oa, ob));
       op (OLocal d) e.ety)
  | EUnK (u, a) ->
    let oa = lexpr l a in
    let d = fresh l in
    emit l (MUnop (d, u, oa));
    op (OLocal d) e.ety
  | ECastK (a, t) ->
    let oa = lexpr l a in
    let d = fresh l in
    emit l (MCast (d, oa, t));
    op (OLocal d) e.ety
  | ECallK (f, args) ->
    (* 用户函数：所有权传参。先求值全部实参，再逐个判定可移动性
       （临时 / 单次出现变量直接移交，其余由调用方克隆保持值语义） *)
    let oargs = List.map (lexpr l) args in
    let decisions = List.map (arg_moveable l) oargs in
    let pairs = List.combine oargs decisions in
    let call_args = List.map (fun (o, (mv, _)) -> (o, mv)) pairs in
    let clears = List.filter_map (fun (_, (_, c)) -> c) pairs in
    let d = if e.ety = TVoid then None else Some (fresh l) in
    emit l (MCallOwn (d, f, call_args, e.ety, clears));
    (* 拥有堆串的调用结果登记为语句临时（语句末释放�?*)
    (match d with
     | Some d' when e.ety = TString -> add_temp l d' false false
     | _ -> ());
    (match d with
     | Some d' -> op (OLocal d') e.ety
     | None -> op (OInt 0L) TVoid)
  | ESeqGetK (b, i) ->
    (* arr[i]：结果写入元素类型临时（越界运行时报错） *)
    let ob = lexpr l b and oi = lexpr l i in
    let elem = e.ety in
    let d = fresh l in
    emit l (MSeqGet (d, ob, oi, elem));
    op (OLocal d) elem
  | ESeqLenK b ->
    (* length(x)：数�?列表长度（string �?length �?typeck 已转�?strlen 调用�?*)
    let ob = lexpr l b in
    let d = fresh l in
    emit l (MSeqLen (d, ob));
    op (OLocal d) e.ety
  | ESeqSliceK (b, a, b', st) ->
    (* 数组/列表切片：调用运行时 zfy_seq_slice 生成�?seq（深拷贝元素�?*)
    let ob = lexpr l b and oa = lexpr l a and ob' = lexpr l b' and ost = lexpr l st in
    let is_str = (match e.ety with TList TString -> true | _ -> false) in
    let d = fresh l in
    emit l (MSeqSlice (d, ob, oa, ob', ost, is_str));
    add_temp l d true is_str;  (* 临时 seq：语句末释放 *)
    op (OLocal d) e.ety
  | ESplitK (a, c) ->
    (* split(s, x)：调用运行时切分，返回新分配的 string 列表 seq。
       结果登记为语句临时：语句末释放，或在整体赋值时 move 接管（免克隆） *)
    let oa = lexpr l a and oc = lexpr l c in
    let d = fresh l in
    (match oc.oty with
     | TChar ->
       emit l (MCall (Some d, "zfy_str_split", [ oa; oc ], TList TString))
     | _ ->
       emit l (MCall (Some d, "zfy_str_split_str", [ oa; oc ], TList TString)));
    add_temp l d true true;
    op (OLocal d) (TList TString)
  | EPushK (base, v) ->
    (* push(列表, 值)：下标 = 当前长度，写入时自动扩长 *)
    (match base.e with
     | EVarK name ->
       let elem = (match base.ety with TList t -> t | _ -> assert false) in
       let dl = fresh l in
       emit l (MSeqLen (dl, op (OLocal name) base.ety));
       let ov = lexpr l v in
       emit l (MSeqSet (name, elem, op (OLocal dl) (TInt 64), ov, true));
       op (OInt 0L) TVoid
     | _ -> merr e.epos "push 的目标必须是列表变量")

(* ---------- 语句降码 ---------- *)

let rec lblock l (stmts : tblock) : unit =
  List.iter (lstmt l) stmts

and lstmt l (s : tstmt) : unit =
  l.stmt_temps <- [];
  lstmt_inner l s;
  finish_stmt_temps l

and lstmt_inner l (s : tstmt) : unit =
  match s.s with
  | SDeclK (_, name, ty, init, nn) ->
    (* 标量声明：变量永远有值，必有初值；非 unreduced frac 存入后约分。
       初值是本语句的 seq 临时（如 split 结果）时直接 move 所有权免克隆 *)
    declare_owned l name ty;
    let v = lexpr l init in
    if l.loop_ids <> [] then
      Hashtbl.replace l.fresh_tbl name (List.hd l.loop_ids);
    let moved =
      match ty with TString | TArray _ | TList _ -> move_owned_temp l name v ty | _ -> false
    in
    if not moved then begin
      emit l (MCopy (name, v, ty));
      if nn then emit l (MNorm (name, ty))
    end
  | SSeqDeclK (_, name, elem, len, is_list, inits) ->
    (* 数组/列表：先分配（未初始化槽位为全零位模式），再逐个写入初始元素 *)
    declare_owned l name
      (if is_list then TList elem
       else TArray (elem, Int64.to_int len));
    emit l (MSeqAlloc (name, elem, len, is_list));
    List.iteri
      (fun i t ->
        let v = lexpr l t in
        emit l (MSeqSet (name, elem, op (OInt (Int64.of_int i)) (TInt 64),
                         v, is_list)))
      inits
  | SSeqCopyK (_, name, elem, len, src, is_list) ->
    (* 数组/列表整体初值：目标槽位无需预分配（初值直接覆盖，
       旧值释放语义不变）；若初值是本语句的 seq 临时（如切片结果）
       则直接 move 所有权，免去克隆 *)
    let tgt = if is_list then TList elem else TArray (elem, Int64.to_int len) in
    declare_owned l name tgt;
    let v = lexpr l src in
    if l.loop_ids <> [] then
      Hashtbl.replace l.fresh_tbl name (List.hd l.loop_ids);
    if not (move_owned_temp l name v tgt) then
      emit l (MCopy (name, v, tgt))
  | SAssignK (lhs, rhs, nn) ->
    let v = lexpr l rhs in
    (match lhs.e with
     | EVarK name ->
       (* 聚合整体赋值：值为本语句临时（切片/split/调用结果等）时 move 免克隆 *)
       let moved =
         match lhs.ety with
         | TString | TArray _ | TList _ -> move_owned_temp l name v lhs.ety
         | _ -> false
       in
       if not moved then begin
         emit l (MCopy (name, v, lhs.ety));
         if nn then emit l (MNorm (name, lhs.ety))
       end
     | _ -> merr lhs.epos "不支持的赋值目标")
  | SAugIndexK (name, elem, idx, bop, v, grow) ->
    (* a[i] op= v：下标只求值一次（load + op + store 同一槽位�?*)
    let oi = lexpr l idx in
    let old = fresh l in
    emit l (MSeqGet (old, op (OLocal name) (TList elem), oi, elem));
    let ov = lexpr l v in
    let r = fresh l in
    emit l (MBinop (r, bop, op (OLocal old) elem, ov));
    emit l (MSeqSet (name, elem, oi, op (OLocal r) elem, grow))
  | SAugVarK (name, ty, bop, v, nn) ->
    (* x op= v：load + op + store 同一槽位 *)
    let ov = lexpr l v in
    let r = fresh l in
    emit l (MBinop (r, bop, op (OLocal name) ty, ov));
    emit l (MCopy (name, op (OLocal r) ty, ty));
    if nn then emit l (MNorm (name, ty))
  | SSeqSetK (name, elem, idx, v, grow) ->
    (* 元素写入：元素类型决定写入宽度；grow 允许列表扩长 *)
    emit l (MSeqSet (name, elem, lexpr l idx, lexpr l v, grow))
  | SRemoveK (name, elem, idx, is_list) ->
    (* remove(数组/列表, i)：数组槽位填零值；列表删除并左移，长度-1 *)
    emit l (MSeqRemove (name, elem, lexpr l idx, is_list))
  | SAugSliceK (name, elem, a, b, st, bop, v) ->
    (* a[x,y:st] op= v：运行时逐元素原地运算 *)
    emit l (MAugSlice (name, elem, lexpr l a, lexpr l b, lexpr l st, bop,
                       lexpr l v))
  | SExprK e -> ignore (lexpr l e)
  | SReturnK e ->
    (* 先求返回值，再释放全部局部资源（RAII）；
       若返回值本身就�?owned 局部变量，跳过其释放（所有权随返回转移）�?       本语句的临时串所有权同样随返回转移，不再释放 *)
    let v = Option.map (lexpr l) e in
    l.stmt_temps <- [];
    let skip =
      match v with
      | Some { o = OLocal n; _ } -> [ n ]
      | _ -> []
    in
    emit_frees_from_skip l 0 skip;
    set_term l (TRet v)
  | SIfK (c, tb, eb) ->
    let cv = lexpr l c in
    let bthen = new_block l and belse = new_block l and bend = new_block l in
    set_term l (TCondBr (cv, bthen.bid, belse.bid));
    (* 两个分支各自作为独立 RAII 作用�?*)
    l.scopes <- ref [] :: l.scopes;
    let outer = List.length (List.tl l.scopes) in
    l.cur <- bthen;
    lblock l tb;
    emit_frees_from l outer;
    set_term l (TBr bend.bid);
    l.cur <- belse;
    lblock l eb;
    emit_frees_from l outer;
    set_term l (TBr bend.bid);
    l.scopes <- List.tl l.scopes;
    l.cur <- bend
  | SWhileK (c, body) ->
    let bcond = new_block l and bbody = new_block l and bend = new_block l in
    set_term l (TBr bcond.bid);
    l.cur <- bcond;
    let cv = lexpr l c in
    set_term l (TCondBr (cv, bbody.bid, bend.bid));
    (* 循环体单独作用域：每轮结束（�?break/continue 路径）释�?*)
    l.scopes <- ref [] :: l.scopes;
    let body_depth = List.length (List.tl l.scopes) in
    l.loops <- (bend.bid, bcond.bid, body_depth) :: l.loops;
    l.loop_ids <- fresh_loop_id () :: l.loop_ids;
    l.cur <- bbody;
    lblock l body;
    emit_frees_from l body_depth;
    set_term l (TBr bcond.bid);
    l.loop_ids <- List.tl l.loop_ids;
    l.loops <- List.tl l.loops;
    l.scopes <- List.tl l.scopes;
    l.cur <- bend
  | SForK (inits, cond, updates, body) ->
    (* C 风格 for：init; cond; update；init 在外层作用域，body 单独作用�?*)
    List.iter (lstmt l) inits;
    let bcond = new_block l and bbody = new_block l in
    let bupd = new_block l and bend = new_block l in
    set_term l (TBr bcond.bid);
    l.cur <- bcond;
    let cv = lexpr l cond in
    set_term l (TCondBr (cv, bbody.bid, bend.bid));
    l.scopes <- ref [] :: l.scopes;
    let body_depth = List.length (List.tl l.scopes) in
    (* 循环上下文：break -> bend；continue -> bupd（continue/break 前
       需先释放 body 层，bupd/bend 都在 body 作用域之外） *)
    l.loops <- (bend.bid, bupd.bid, body_depth) :: l.loops;
    l.loop_ids <- fresh_loop_id () :: l.loop_ids;
    l.cur <- bbody;
    lblock l body;
    emit_frees_from l body_depth;
    set_term l (TBr bupd.bid);
    l.cur <- bupd;
    List.iter (lstmt l) updates;
    set_term l (TBr bcond.bid);
    l.loop_ids <- List.tl l.loop_ids;
    l.loops <- List.tl l.loops;
    l.scopes <- List.tl l.scopes;
    l.cur <- bend
  | SOutputK (args, sep, end_) ->
    (* 逐参数输出：sep 只出现在相邻参数之间，最后输�?end *)
    List.iteri
      (fun i a ->
        if i > 0 then emit l (MPrintVal (lexpr l sep));
        emit l (MPrintVal (lexpr l a)))
      args;
    emit l (MPrintVal (lexpr l end_))
  | SInputK (targets, delim) ->
    (* 逐目标读入：第 i 个目标读取第 i 段输入。
       delim 是 string 操作数；空串表示默认"换行和空白"字符集；
       新声明的 string 目标登记为 owned *)
    let d =
      match delim with
      | None -> op (OStr "") TString
      | Some de -> lexpr l de
    in
    List.iter
      (fun t ->
        if t.Hir.tnew then declare_owned l t.Hir.tname t.Hir.tty;
        emit l (MInput (t.Hir.tname, t.Hir.tty, d)))
      targets
  | SReduceK (x, cnt, start) ->
    (match x.e with
     | EVarK root ->
       let vc = lexpr l cnt in
       let c64 = fresh l in
       emit l (MCast (c64, vc, TInt 64));
       let vs = lexpr l start in
       let s64 = fresh l in
       emit l (MCast (s64, vs, TInt 64));
       emit l (MReduce (root, x.ety, op (OLocal c64) (TInt 64),
                        op (OLocal s64) (TInt 64)))
     | _ -> merr x.epos "reduce 的对象必须是 frac 类型的局部变量")
  | SBreakK ->
    (match l.loops with
     | (bk, _, body_depth) :: _ ->
       (* 跳出前释放循环体内层作用域的全部资源 *)
       emit_frees_from l body_depth;
       set_term l (TBr bk);
       l.cur <- new_block l            (* 后续死代码放入孤立块 *)
     | [] -> merr s.spos "break 只能出现在循环内")
  | SContinueK ->
    (match l.loops with
     | (_, ck, body_depth) :: _ ->
       emit_frees_from l body_depth;
       set_term l (TBr ck);
       l.cur <- new_block l
     | [] -> merr s.spos "continue 只能出现在循环内")
  | SThrowK e ->
    (* throw：运行时 strdup 消息后长跳到最近异常帧；无帧则报错退出 *)
    let v = lexpr l e in
    emit l (MThrow v)
  | STryK (tb, binding, cb) ->
    (* try/catch：setjmp 双返回。0=try 路径（正常离开时弹帧），
       非 0=异常路径（先释放 try 作用域资源，再取消息、执行 catch 块） *)
    let frame = fresh l in
    emit l (MTryFrame frame);
    let res = fresh l in
    emit l (MTrySetup (res, frame));
    let btry = new_block l and bcatch = new_block l and bend = new_block l in
    set_term l (TCondBr (op (OLocal res) TBool, bcatch.bid, btry.bid));
    (* try 路径：独立 RAII 作用域 *)
    l.scopes <- ref [] :: l.scopes;
    let try_scope = List.hd l.scopes in
    let outer = List.length (List.tl l.scopes) in
    l.cur <- btry;
    lblock l tb;
    emit_frees_from l outer;
    emit l MTryLeave;
    set_term l (TBr bend.bid);
    l.scopes <- List.tl l.scopes;
    (* 异常路径：先释放 try 作用域变量（异常时未走正常释放路径），
       再绑定异常消息并执行 catch 块 *)
    l.cur <- bcatch;
    List.iter (fun (n, t) -> emit l (MFreeVar (n, t))) (List.rev !try_scope);
    l.scopes <- ref [] :: l.scopes;
    let couter = List.length (List.tl l.scopes) in
    (match binding with
     | Some nm ->
       declare_owned l nm TString;
       emit l (MTryMsg (nm, TString))
     | None -> ());
    lblock l cb;
    emit_frees_from l couter;
    set_term l (TBr bend.bid);
    l.scopes <- List.tl l.scopes;
    l.cur <- bend

(* ---------- 函数降码 ---------- *)

(* ---------- 出现次数统计（move 分析） ---------- *)

let add_occ (occ : (string, int) Hashtbl.t) (n : string) =
  let c = match Hashtbl.find_opt occ n with Some c -> c | None -> 0 in
  Hashtbl.replace occ n (c + 1)

let rec count_uses_expr occ (e : texpr) =
  match e.e with
  | EVarK n -> add_occ occ n
  | EBinK (_, a, b) -> count_uses_expr occ a; count_uses_expr occ b
  | EUnK (_, a) -> count_uses_expr occ a
  | ECallK (_, args) -> List.iter (count_uses_expr occ) args
  | ECastK (a, _) -> count_uses_expr occ a
  | EFracNewK (a, b) -> count_uses_expr occ a; count_uses_expr occ b
  | ESeqGetK (a, b) -> count_uses_expr occ a; count_uses_expr occ b
  | ESeqLenK a -> count_uses_expr occ a
  | ESeqSliceK (a, b, c, d) -> List.iter (count_uses_expr occ) [ a; b; c; d ]
  | ESplitK (a, b) -> count_uses_expr occ a; count_uses_expr occ b
  | EPushK (a, b) -> count_uses_expr occ a; count_uses_expr occ b
  | EIntK _ | EFloatK _ | EStrK _ | ECharK _ | EBoolK _ -> ()

let rec count_uses_stmt occ (s : tstmt) =
  match s.s with
  | SDeclK (_, _, _, init, _) -> count_uses_expr occ init
  | SSeqDeclK (_, _, _, _, _, inits) -> List.iter (count_uses_expr occ) inits
  | SSeqCopyK (_, _, _, _, src, _) -> count_uses_expr occ src
  | SAssignK (lhs, rhs, _) -> count_uses_expr occ lhs; count_uses_expr occ rhs
  | SAugIndexK (n, _, idx, _, v, _) ->
    add_occ occ n; count_uses_expr occ idx; count_uses_expr occ v
  | SAugVarK (n, _, _, v, _) -> add_occ occ n; count_uses_expr occ v
  | SAugSliceK (n, _, a, b, st, _, v) ->
    add_occ occ n; List.iter (count_uses_expr occ) [ a; b; st; v ]
  | SSeqSetK (n, _, idx, v, _) ->
    add_occ occ n; count_uses_expr occ idx; count_uses_expr occ v
  | SExprK e -> count_uses_expr occ e
  | SReturnK (Some e) -> count_uses_expr occ e
  | SReturnK None -> ()
  | SIfK (c, a, b) ->
    count_uses_expr occ c; count_uses_stmts occ a; count_uses_stmts occ b
  | SWhileK (c, b) -> count_uses_expr occ c; count_uses_stmts occ b
  | SForK (inits, c, ups, b) ->
    List.iter (count_uses_stmt occ) inits; count_uses_expr occ c;
    List.iter (count_uses_stmt occ) ups; count_uses_stmts occ b
  | SOutputK (args, sep, end_) -> List.iter (count_uses_expr occ) (sep :: end_ :: args)
  | SInputK (targets, delim) ->
    List.iter (fun (t : tin_target) -> if not t.tnew then add_occ occ t.tname) targets;
    (match delim with Some d -> count_uses_expr occ d | None -> ())
  | SReduceK (x, c, st) ->
    count_uses_expr occ x; count_uses_expr occ c; count_uses_expr occ st
  | SRemoveK (n, _, idx, _) -> add_occ occ n; count_uses_expr occ idx
  | SThrowK e -> count_uses_expr occ e
  | STryK (tb, _, cb) -> count_uses_stmts occ tb; count_uses_stmts occ cb
  | SBreakK | SContinueK -> ()

and count_uses_stmts occ stmts = List.iter (count_uses_stmt occ) stmts

let rec collect_lets acc (stmts : tblock) =
  List.iter
    (fun (s : tstmt) ->
      match s.s with
      | SDeclK (_, n, t, _, _) ->
        if n.[0] <> '@' then acc := (n, t) :: !acc
      | SSeqDeclK (_, n, elem, len, is_list, _) ->
        (* 数组/列表槽：槽内是指向 zfy_seq 的指针（LLVM 层为 ptr） *)
        if n.[0] <> '@' then begin
          let t = if is_list then TList elem
                  else TArray (elem, Int64.to_int len) in
          acc := (n, t) :: !acc
        end
      | SSeqCopyK (_, n, elem, len, _, is_list) ->
        if n.[0] <> '@' then
          acc := (n, if is_list then TList elem else TArray (elem, Int64.to_int len)) :: !acc
      | SInputK (targets, _) ->
        (* input 声明的新变量也需要入口槽 *)
        List.iter
          (fun (t : tin_target) -> if t.tnew then acc := (t.tname, t.tty) :: !acc)
          targets
      | SIfK (_, a, b) -> collect_lets acc a; collect_lets acc b
      | STryK (tb2, binding, cb2) ->
        (match binding with
         | Some n -> acc := (n, TString) :: !acc
         | None -> ());
        collect_lets acc tb2; collect_lets acc cb2
      | SWhileK (_, b) -> collect_lets acc b
      | SForK (inits, _, _, b) ->
        List.iter
          (fun (s : tstmt) ->
            match s.s with
            | SDeclK (_, n, t, _, _) ->
              if n.[0] <> '@' then acc := (n, t) :: !acc
            | SSeqDeclK (_, n, elem, len, is_list, _) ->
              if n.[0] <> '@' then begin
                let t = if is_list then TList elem
                        else TArray (elem, Int64.to_int len) in
                acc := (n, t) :: !acc
              end
            | SSeqCopyK (_, n, elem, len, _, is_list) ->
              if n.[0] <> '@' then
                acc := (n, if is_list then TList elem else TArray (elem, Int64.to_int len)) :: !acc
            | SInputK (targets, _) ->
              List.iter
                (fun (t : tin_target) -> if t.tnew then acc := (t.tname, t.tty) :: !acc)
                targets
            | _ -> ())
          inits;
        collect_lets acc b
      | _ -> ())
    stmts

let lower_fn (h : hir) (f : tfn) : mfn =
  let l =
    { blocks = Hashtbl.create 8; nb = 0; nt = 0; cur = Obj.magic 0;
      loops = []; scopes = []; stmt_temps = []; loop_ids = [];
      occ_tbl = Hashtbl.create 16; fresh_tbl = Hashtbl.create 16 }
  in
  (* 全函数出现次数（move 分析：单次出现的变量可安全 move） *)
  count_uses_stmts l.occ_tbl f.fbody;
  let entry = new_block l in
  l.cur <- entry;
  (* 全局变量槽先于一切局部槽（'@' 前缀，llvmgen 落为模块级 global） *)
  List.iter (fun (n, t) -> emit l (MAlloca (n, t))) h.hglobals;
  (* 所有 let 变量在入口块统一分配槽位 *)
  let lets = ref [] in
  collect_lets lets f.fbody;
  let seen = Hashtbl.create 8 in
  List.iter (fun (n, _) -> Hashtbl.replace seen n ()) h.hglobals;
  List.iter
    (fun (n, t) ->
      if not (Hashtbl.mem seen n) then begin
        Hashtbl.replace seen n ();
        emit l (MAlloca (n, t))
      end)
    !lets;
  (* 函数体整体作为顶层 RAII 作用域；string 参数在入口 strdup、数组/列表参数
     在入口 clone（一律拷贝语义，gen_fn 落槽），参数槽登记为 owned 以便函数退出时释放 *)
  l.scopes <- ref [] :: l.scopes;
  List.iter
    (fun (_, n, t) -> declare_owned l n t)
    f.fparams;
  lblock l f.fbody;
  if l.cur.term = None then begin
    (* 隐式返回：先释放全部资源 *)
    emit_frees_from l 0;
    set_term l (TRet None)
  end;
  let blocks =
    Hashtbl.fold
      (fun _ (b : block) acc ->
        { b with body = List.rev b.body;
                 term = (match b.term with Some t -> Some t | None -> Some TUnreachable) }
        :: acc)
      l.blocks []
  in
  let blocks = List.sort (fun a b -> compare a.bid b.bid) blocks in
  { mname = f.fname;
    mparams = List.map (fun (_, n, t) -> (n, t)) f.fparams;
    mret = f.fret;
    mentry = entry.bid; mblocks = blocks }

(* ---------- 常量折叠 ---------- *)

let fold_binop (bop : binop) (a : operand) (b : operand) : operand option =
  match bop, a.o, b.o with
  | BAdd, OInt x, OInt y -> Some (op (OInt (Int64.add x y)) a.oty)
  | BSub, OInt x, OInt y -> Some (op (OInt (Int64.sub x y)) a.oty)
  | BMul, OInt x, OInt y -> Some (op (OInt (Int64.mul x y)) a.oty)
  | BDiv, OInt x, OInt y when y <> 0L -> Some (op (OInt (Int64.div x y)) a.oty)
  | BMod, OInt x, OInt y when y <> 0L -> Some (op (OInt (Int64.rem x y)) a.oty)
  | BAdd, OFloat x, OFloat y -> Some (op (OFloat (x +. y)) a.oty)
  | BSub, OFloat x, OFloat y -> Some (op (OFloat (x -. y)) a.oty)
  | BMul, OFloat x, OFloat y -> Some (op (OFloat (x *. y)) a.oty)
  | BDiv, OFloat x, OFloat y when y <> 0.0 -> Some (op (OFloat (x /. y)) a.oty)
  | BEq, OInt x, OInt y -> Some (op (OBool (x = y)) TBool)
  | BNe, OInt x, OInt y -> Some (op (OBool (x <> y)) TBool)
  | BLt, OInt x, OInt y -> Some (op (OBool (x < y)) TBool)
  | BGt, OInt x, OInt y -> Some (op (OBool (x > y)) TBool)
  | BLe, OInt x, OInt y -> Some (op (OBool (x <= y)) TBool)
  | BGe, OInt x, OInt y -> Some (op (OBool (x >= y)) TBool)
  | BEq, OFloat x, OFloat y -> Some (op (OBool (x = y)) TBool)
  | BNe, OFloat x, OFloat y -> Some (op (OBool (x <> y)) TBool)
  | BLt, OFloat x, OFloat y -> Some (op (OBool (x < y)) TBool)
  | BGt, OFloat x, OFloat y -> Some (op (OBool (x > y)) TBool)
  | BLe, OFloat x, OFloat y -> Some (op (OBool (x <= y)) TBool)
  | BGe, OFloat x, OFloat y -> Some (op (OBool (x >= y)) TBool)
  | BEq, OBool x, OBool y -> Some (op (OBool (x = y)) TBool)
  | BNe, OBool x, OBool y -> Some (op (OBool (x <> y)) TBool)
  | BEq, OChar x, OChar y -> Some (op (OBool (x = y)) TBool)
  | BNe, OChar x, OChar y -> Some (op (OBool (x <> y)) TBool)
  | BAnd, OBool x, OBool y -> Some (op (OBool (x && y)) TBool)
  | BOr, OBool x, OBool y -> Some (op (OBool (x || y)) TBool)
  | _ -> None

let fold_fn (f : mfn) : mfn =
  let fold_instr = function
    | MBinop (d, op, a, b) ->
      (match fold_binop op a b with
       | Some v -> MCopy (d, v, v.oty)
       | None -> MBinop (d, op, a, b))
    | MUnop (d, UNeg, { o = OInt x; oty = t; _ }) ->
      MCopy (d, op (OInt (Int64.neg x)) t, t)
    | MUnop (d, UNeg, { o = OFloat x; oty = t; _ }) ->
      MCopy (d, op (OFloat (-.x)) t, t)
    | MUnop (d, UNot, { o = OBool x; oty = t; _ }) ->
      MCopy (d, op (OBool (not x)) t, t)
    | i -> i
  in
  { f with
    mblocks =
      List.map (fun (b : block) -> { b with body = List.map fold_instr b.body }) f.mblocks }

(* ---------- 死代码消�?---------- *)

let uses_of (i : instr) : string list =
  let operand_names (o : operand) =
    match o.o with OLocal n -> [ n ] | _ -> []
  in
  match i with
  | MCopy (_, v, _) -> operand_names v
  | MMoveSeq (_, v, _) -> operand_names v
  | MClear _ -> []
  | MBinop (_, _, a, b) -> operand_names a @ operand_names b
  | MUnop (_, _, a) -> operand_names a
  | MCast (_, a, _) -> operand_names a
  | MCall (_, _, args, _) -> List.concat_map operand_names args
  | MCallOwn (_, _, args, _, _) ->
    List.concat_map (fun (o, _) -> operand_names o) args
  | MThrow o -> operand_names o
  | MTryFrame _ | MTryLeave | MTryMsg _ -> []
  | MTrySetup _ -> []
  | MAlloca _ -> []
  | MFracNew (_, _, a, b) -> operand_names a @ operand_names b
  | MNorm _ -> []
  | MSeqRemove (_, _, idx, _) -> operand_names idx
  | MAugSlice (_, _, a, b, st, _, v) ->
    operand_names a @ operand_names b @ operand_names st @ operand_names v
  | MReduce (r, _, a, b) -> r :: operand_names a @ operand_names b
  | MPrintStr _ -> []
  | MPrintVal o -> operand_names o
  | MInput (_, _, d) -> operand_names d
  | MSeqAlloc _ -> []
  | MSeqSet (_, _, idx, v, _) -> operand_names idx @ operand_names v
  | MFreeVar _ -> []
  | MFreeTemp _ -> []
  | MFreeSeqTemp _ -> []
  | MSeqGet (_, base, idx, _) -> operand_names base @ operand_names idx
  | MSeqLen (_, base) -> operand_names base
  | MSeqSlice (_, src, a, b, st, _) ->
    operand_names src @ operand_names a @ operand_names b @ operand_names st

let pure_dst (i : instr) : string option =
  match i with
  | MBinop (d, _, _, _) | MUnop (d, _, _) | MCast (d, _, _) ->
    if String.length d > 0 && d.[0] = '%' then Some d else None
  | _ -> None

let cleanup_fn (f : mfn) : mfn =
  (* 可达�?*)
  let rec dfs bid seen =
    if List.mem bid seen then seen
    else begin
      let seen = bid :: seen in
      let b = List.find (fun (b : block) -> b.bid = bid) f.mblocks in
      match b.term with
      | Some (TBr n) -> dfs n seen
      | Some (TCondBr (_, a, b')) -> dfs a (dfs b' seen)
      | _ -> seen
    end
  in
  let reach = dfs f.mentry [] in
  let kept = List.filter (fun (b : block) -> List.mem b.bid reach) f.mblocks in
  (* 迭代删除无使用的纯临�?*)
  let kept = Array.of_list kept in
  let changed = ref true in
  while !changed do
    changed := false;
    let used = Hashtbl.create 16 in
    let add_use n = Hashtbl.replace used n () in
    Array.iter
      (fun (b : block) ->
        List.iter (fun i -> List.iter add_use (uses_of i)) b.body;
        (match b.term with
         | Some (TCondBr (o, _, _)) -> List.iter add_use (uses_of (MCopy ("", o, TVoid)))
         | Some (TRet (Some o)) -> List.iter add_use (uses_of (MCopy ("", o, TVoid)))
         | _ -> ()))
      kept;
    Array.iter
      (fun (b : block) ->
        let before = List.length b.body in
        b.body <-
          List.filter
            (fun i ->
              match pure_dst i with
              | Some d -> Hashtbl.mem used d
              | None -> true)
            b.body;
        if List.length b.body <> before then changed := true)
      kept
  done;
  { f with mblocks = Array.to_list kept }

(* ---------- 程序入口 ---------- *)

let lower (h : hir) : mir =
  (* 全局初始化块 -> 隐藏函数 zfy.globals（main 包装最先调用；
     空 ginit 也生成，保证符号存在） *)
  let gfn : tfn =
    { fname = "zfy.globals"; fparams = []; fret = TVoid; fbody = h.ginit }
  in
  let mfns =
    List.map (fun (f : tfn) -> cleanup_fn (fold_fn (lower_fn h f))) (gfn :: h.hfns)
  in
  { mfns }

