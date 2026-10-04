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
  | MMoveSeq of string * operand * zty           (* 所有权转移：释放目标旧值后直接接管临时（免克隆）；string/数组/列表=指针接管，struct=槽 memcpy *)
  | MClear of string * zty                       (* move 后清空变量槽（store null，防 RAII 双释放） *)
  | MBinop of string * binop * operand * operand
  | MUnop of string * unop * operand
  | MCast of string * operand * zty
  | MCall of string option * string * operand list * zty
  | MCallOwn of string option * string * (operand * bool) list * zty * (string * zty) list
    (* 用户函数调用（所有权传参）：每个 string/数组/列表实参带 move 标志——
       true 直接移交（免克隆），false 由调用方克隆（保持值语义）；
       最后一项为 move 的变量实参（调用后需清槽）；frac 始终借传 *)
  | MErrNew of string * zty * operand * operand
    (* fail(code, msg)：目标槽（TErr 聚合 alloca）, TErr 类型, code（i32）, msg
       （string，运行时 strdup 永不释放）；value 字段不初始化（code≠0 不读） *)
  | MErrOk of string * zty * operand
    (* 成功包装（T → TErr T）：目标槽（TErr 聚合 alloca）, TErr 类型, 元素值
       （标量/string/指针，string 深拷贝）；code=0, msg=null *)
  | MErrIsOk of string * operand * zty
    (* 判定成功：目标寄存器（i1）, TErr 槽操作数, TErr 类型 *)
  | MErrValue of string * operand * zty
    (* 取成功值：目标寄存器（元素类型）, TErr 槽操作数, TErr 类型 *)
  | MErrFillErr of string * operand * zty
    (* TErr 值 → Err struct 槽（拷 code/msg 两字段）：目标槽, TErr 槽操作数, TErr 类型 *)
  | MErrFillOut of operand * zty
    (* a? 失败路径：错误值 memcpy 到本函数 sret 返回槽 %out（块终结由 TRet None
       生成 ret void；仅 TErr 返回类型的函数） *)
  | MPanic of operand option * operand
    (* panic(code?, msg)：调用 zfy_panic 不可恢复终止（不返回）；后继为死块 *)
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
  | MSeqSet of string * zty * operand * operand * bool * bool
    (* arr[i]=v：槽, 元素类型(决定写入宽度), 下标, �? 可扩�?*)
  | MSeqGet of string * operand * operand * zty * bool  (* 读元素到临时：目标, 数组, 下标, 元素类型, unchecked(关闭越界检查) *)
  | MSeqLen of string * operand                  (* length(x)：目标临�? 数组/列表 *)
  | MSeqSlice of string * operand * operand * operand * operand * bool
    (* base[a,b:step]：目标临时(seq 指针), 基, 起点, 终点, 步长, 元素是否 string *)
  | MStructNew of string * zty * (int * operand) list
    (* struct 构造：目标槽（聚合 alloca）, struct 类型, (字段序号, 值) 列表 *)
  | MFieldGet of string * operand * zty * int list * zty
    (* 字段读取：目标, 根槽, 根 struct 类型, 字段序号链, 字段类型；
       标量/string/seq 字段为 load（借用语义），嵌套 struct 字段深拷贝到目标槽 *)
  | MFieldStore of operand * zty * int list * operand
    (* 字段写入：根槽, 根 struct 类型, 字段序号链, 新值（深拷贝新值+释放旧值） *)
  | MEmptySeq of string * zty
    (* 数组/列表字段缺省分配：目标临时, 完整 seq 类型
       （TArray (t,n) → 定长 n 全零；TList t → 空列表、初始容量 8） *)
  | MFreeStructTemp of string * zty
    (* 语句末释放临时 struct 槽持有的资源 *)
  | MAddrOf of string * string
    (* 取地址：dst 寄存器 = 变量槽地址（槽名含全局 @g.x） *)
  | MLoadK of string * operand * zty
    (* 解引用读：dst = load <ty>, ptr <op>（op 为指针值） *)
  | MStoreK of operand * zty * operand
    (* 解引用写：store <值>, ptr <地址>（地址, 目标类型, 值；仅标量/指针目标） *)
  | MFieldAddr of string * operand * zty * int list * zty
    (* 字段地址：dst = GEP 链地址（root 操作数, 根类型(可为 TPtr), 字段链, 字段类型） *)
  | MElemAddr of string * operand * operand * zty
    (* 元素地址（裸指针，无越界检查）：dst = getelementptr（base ptr, 下标, 元素类型） *)
  | MIndirectCall of string option * operand * operand list * zty
    (* 函数指针间接调用：dst, 被调指针值, 实参（标量语义借传）, 返回类型 *)
  | MFunAddr of string * string
    (* 函数入口地址：dst 寄存器持有 LLVM 符号文本（@名），作函数指针值 *)

type block = { bid : int; mutable body : instr list; mutable term : term option }

type mfn = {
  mname : string;
  mparams : (string * zty) list;
  mret : zty;
  mentry : int;
  mblocks : block list;
}

type mir = { mfns : mfn list; mstructs : sdef list }

(* 临时资源的释放类别（语句末统一释放） *)
type free_kind =
  | FStr                          (* 寄存器堆串（regs）：zfy_free_str *)
  | FSeq of bool                  (* 寄存器 seq（regs）：zfy_seq_free（元素是否 string） *)
  | FStruct of zty                (* 槽 struct（allocas）：zfy_struct_free_<名> *)

(* ---------- 降码上下�?---------- *)

type lctx = {
  blocks : (int, block) Hashtbl.t;
  mutable nb : int;
  mutable nt : int;
  mutable cur : block;
  mutable loops : (int * int * int) list;  (* (break 目标, continue 目标, 循环体作用域深度) *)
  mutable scopes : (string * zty) list ref list;  (* RAII 作用域栈：每层收集需释放变量 *)
  mutable stmt_temps : (string * free_kind) list;  (* 当前语句拥有的临时：(名, 释放类别) *)
  mutable unchecked : bool;  (* unsafe 块内：下标读写关闭越界检查（new2.md #3/@unchecked） *)
}

let new_block l =
  let b = { bid = l.nb; body = []; term = None } in
  Hashtbl.replace l.blocks b.bid b;
  l.nb <- l.nb + 1;
  b

let emit l i = l.cur.body <- i :: l.cur.body

let set_term l t = if l.cur.term = None then l.cur.term <- Some t

let fresh l = l.nt <- l.nt + 1; Printf.sprintf "%%t%d" l.nt

let op k t = { o = k; oty = t }

(* 需 RAII 释放的变量类型：string（堆串）、数组/列表（seq 资源）、struct（内含堆资源）。
   全局变量槽（'@' 前缀）不属于函数作用域，永不释放 *)
let owned_ty (name : string) (t : zty) =
  match t with
  | TString | TArray _ | TList _ | TStruct _ -> name.[0] <> '@'
  | _ -> false

(* 在当前作用域登记需 RAII 释放的变量（后声明先释放） *)
let declare_owned l name ty =
  if owned_ty name ty then
    match l.scopes with
    | top :: _ -> top := (name, ty) :: !top
    | [] -> ()

(* 登记本语句产生的临时（语句末统一释放） *)
let add_temp l name kind =
  l.stmt_temps <- (name, kind) :: l.stmt_temps

(* 临时 move 优化：若 v 是本语句产生的 owned 临时（string/seq/struct 槽，
   语句末才释放、此后不再被引用），则将所有权直接转移给目标变量——
   string/seq 为指针接管，struct 为释放目标旧值后槽 memcpy。临时从
   stmt_temps 移除（不再释放）。返回是否发生了 move（发生时调用方不再 emit MCopy）。 *)
let move_owned_temp l (name : string) (v : operand) (ty : zty) : bool =
  let kind_matches kind =
    match kind, ty with
    | FStr, TString -> true
    | FSeq _, (TArray _ | TList _) -> true
    | FStruct _, TStruct _ -> true
    | _ -> false
  in
  match v.o, ty with
  | OLocal d, (TString | TArray _ | TList _ | TStruct _) ->
    let rec go acc = function
      | [] -> false
      | (n, kind) :: rest when n = d && kind_matches kind ->
        l.stmt_temps <- List.rev_append acc rest;
        emit l (MMoveSeq (name, v, ty));
        true
      | x :: rest -> go (x :: acc) rest
    in
    go [] l.stmt_temps
  | _ -> false

(* 调用实参的可移动性：string/数组/列表实参若为本语句产生的临时
   （split/切片/调用结果等，语句末才释放、此后不再被引用）则可 move
   （免克隆，所有权移交被调函数）。返回 (move?, 变量清槽项)。
   （t6 起：全函数单次出现变量的自动 move 已删除——一律显式 move。） *)
let arg_moveable l (v : operand) : bool * (string * zty) option =
  let owned = match v.oty with TString | TArray _ | TList _ -> true | _ -> false in
  if not owned then (false, None)
  else
    match v.o with
    | OLocal d when String.length d > 0 && d.[0] = '%' ->
      (* 本语句临时（%临时名）：直接移交 *)
      let rec go acc = function
        | [] -> (false, None)
        | (n, _) :: rest when n = d ->
          l.stmt_temps <- List.rev_append acc rest;
          (true, None)
        | x :: rest -> go (x :: acc) rest
      in
      go [] l.stmt_temps
    | _ -> (false, None)

(* 语句结束：释放本语句拥有的临时（若当前块已终结则放弃——控制流边界�?   return 路径的所有权随返回转移，由调用方先行清空�?*)
let finish_stmt_temps l =
  let ts = List.rev l.stmt_temps in
  l.stmt_temps <- [];
  if l.cur.term = None then
    List.iter
      (fun (n, kind) ->
        match kind with
        | FStr -> emit l (MFreeTemp n)
        | FSeq is_str -> emit l (MFreeSeqTemp (n, is_str))
        | FStruct t -> emit l (MFreeStructTemp (n, t)))
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
    | _ -> merr { file = ""; line = 0; col = 0 } "unsupported frac operation"
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
  | ECastK (a, t) when a.ety = TString ->
    (* string → 数值 cast：错误值路径（失败产 TErr 值，code=CAST）；
       zfy_stoi_err / zfy_stod_err 以 sret 写 TErr 聚合 *)
    let oa = lexpr l a in
    let fn = match t with TFloat _ -> "zfy_stod_err" | _ -> "zfy_stoi_err" in
    let d = fresh l in
    emit l (MCall (Some d, fn, [ oa ], e.ety));
    op (OLocal d) e.ety
  | ECastK (a, t) ->
    let oa = lexpr l a in
    let d = fresh l in
    emit l (MCast (d, oa, t));
    op (OLocal d) e.ety
  | ECallK (f, args, moves) ->
    (* 用户函数：所有权传参。先求值全部实参，再逐个判定可移动性
       （本语句临时直接移交；显式 move 实参（f(move x)）移交并清槽，
       其余由调用方克隆保持值语义）。
       moves 与实参等长标记显式 move；typeck 内建/runtime 辅助调用
       构造空表时按缺省 false（无显式 move）处理 *)
    let oargs = List.map (lexpr l) args in
    let decisions =
      List.mapi
        (fun i o ->
          match List.nth_opt moves i with
          | Some true ->
            (* 显式 move：typeck 已保证局部 owned 变量（string/数组/列表） *)
            (match o.o, o.oty with
             | OLocal n, (TString | TArray _ | TList _) when n.[0] <> '@' ->
               (true, Some (n, o.oty))
             | _ -> (false, None))
          | _ -> arg_moveable l o)
        oargs
    in
    let pairs = List.combine oargs decisions in
    let call_args = List.map (fun (o, (mv, _)) -> (o, mv)) pairs in
    let clears = List.filter_map (fun (_, (_, c)) -> c) pairs in
    let d = if e.ety = TVoid then None else Some (fresh l) in
    emit l (MCallOwn (d, f, call_args, e.ety, clears));
    (* 拥有堆资源的调用结果登记为语句临时（语句末释放；struct 可被 move 接管） *)
    (match d with
     | Some d' when e.ety = TString -> add_temp l d' FStr
     | Some d' ->
       (match e.ety with
        | TStruct _ -> add_temp l d' (FStruct e.ety)
        | _ -> ())
     | _ -> ());
    (match d with
     | Some d' -> op (OLocal d') e.ety
     | None -> op (OInt 0L) TVoid)
  | ESeqGetK (b, i) ->
    (* arr[i]：结果写入元素类型临时（越界运行时报错） *)
    let ob = lexpr l b and oi = lexpr l i in
    let elem = e.ety in
    let d = fresh l in
    emit l (MSeqGet (d, ob, oi, elem, l.unchecked));
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
    add_temp l d (FSeq is_str);  (* 临时 seq：语句末释放 *)
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
    add_temp l d (FSeq true);
    op (OLocal d) (TList TString)
  | EPushK (base, v) ->
    (* push(列表, 值)：下标 = 当前长度，写入时自动扩长 *)
    (match base.e with
     | EVarK name ->
       let elem = (match base.ety with TList t -> t | _ -> assert false) in
       let dl = fresh l in
       emit l (MSeqLen (dl, op (OLocal name) base.ety));
       let ov = lexpr l v in
       emit l (MSeqSet (name, elem, op (OLocal dl) (TInt 64), ov, true, l.unchecked));
       op (OInt 0L) TVoid
     | _ -> merr e.epos "push target must be a list variable")
  | EStructNewK (_, fields) ->
    (* struct 构造：逐字段求值后写入聚合目标槽（llvmgen 负责 alloca 与
       深拷贝语义）。目标登记为语句临时：语句末释放，或整体赋值时 move 接管 *)
    let d = fresh l in
    let vals = List.mapi (fun i f -> (i, lexpr l f)) fields in
    emit l (MStructNew (d, e.ety, vals));
    add_temp l d (FStruct e.ety);
    op (OLocal d) e.ety
  | EFieldK (base, idx) ->
    (* 字段读取：字段链展平为 (根槽, 序号链)，一次 GEP 直达最终字段。
       标量/string/seq 字段 load 值（借用语义，赋值时才深拷贝）；
       嵌套 struct 字段深拷贝到临时槽（值语义） *)
    let rec flatten acc b =
      match b.e with
      | EFieldK (b', i) -> flatten (i :: acc) b'
      | EVarK n -> Some (n, acc, b.ety)
      | _ -> None
    in
    (match flatten [ idx ] base with
     | Some (root, idxs, rootty) ->
       let d = fresh l in
       emit l (MFieldGet (d, op (OLocal root) rootty, rootty, idxs, e.ety));
       (match e.ety with
        | TStruct _ -> add_temp l d (FStruct e.ety)  (* 深拷贝副本：语句末释放 *)
        | _ -> ());
       op (OLocal d) e.ety
     | None -> merr e.epos "unsupported field-access target")
  | ENullK ->
    (* null：0 值（llvmgen 对指针类型的 OInt 0 落为 null 常量） *)
    op (OInt 0L) e.ety
  | EAddrOfK a ->
    (* 取地址：&x。按目标形态分派：
       变量 → 槽地址（MAddrOf，全局槽同样适用）；
       字段链 → GEP 链地址（MFieldAddr，根可为 TStruct 或 TPtr(TStruct)）；
       数组/列表元素 → 裸元素地址（MElemAddr，无越界检查）；
       解引用 → 取地址与解引用相互抵消，即 p 本身（直接化简） *)
    (match a.e with
     | EVarK n ->
       let d = fresh l in
       emit l (MAddrOf (d, n));
       op (OLocal d) e.ety
     | EDerefK p -> lexpr l p
     | EFieldK _ ->
       let rec flatten acc b =
         match b.e with
         | EFieldK (b', i) -> flatten (i :: acc) b'
         | EVarK n -> Some (n, acc, b.ety)
         | _ -> None
       in
       (match flatten [] a with
        | Some (root, idxs, rootty) ->
          let d = fresh l in
          emit l (MFieldAddr (d, op (OLocal root) rootty, rootty, idxs, a.ety));
          op (OLocal d) e.ety
        | None -> merr e.epos "unsupported address-of target")
     | ESeqGetK (b, i) ->
       (match b.e with
        | EVarK _ ->
          let ob = lexpr l b and oi = lexpr l i in
          let d = fresh l in
          emit l (MElemAddr (d, ob, oi, a.ety));
          op (OLocal d) e.ety
        | _ -> merr e.epos "element address-of target must be a variable")
     | _ -> merr e.epos "unsupported address-of target")
  | EDerefK p ->
    (* 解引用读：p 为指针值，load 目标类型（聚合类型已在 typeck 拒绝） *)
    let pv = lexpr l p in
    let d = fresh l in
    emit l (MLoadK (d, pv, e.ety));
    op (OLocal d) e.ety
  | EIndirectCallK (f, args) ->
    (* 函数指针间接调用：实参标量语义借传（不做 move 分析） *)
    let of_ = lexpr l f in
    let oargs = List.map (lexpr l) args in
    let d = if e.ety = TVoid then None else Some (fresh l) in
    emit l (MIndirectCall (d, of_, oargs, e.ety));
    (match d with
     | Some d' -> op (OLocal d') e.ety
     | None -> op (OInt 0L) TVoid)
  | EFunPtrK f ->
    (* 函数名引用：dst 寄存器持有函数符号（llvmgen 落为 @名） *)
    let d = fresh l in
    emit l (MFunAddr (d, f));
    op (OLocal d) e.ety
  | EEmptySeqK ->
    (* 数组/列表字段缺省分配：新分配 seq（定长/空列表），登记为语句临时 *)
    let d = fresh l in
    let elem =
      match e.ety with TList t | TArray (t, _) -> t | _ -> assert false
    in
    emit l (MEmptySeq (d, e.ety));
    add_temp l d (FSeq (elem = TString));
    op (OLocal d) e.ety
  | EFailK (code, msg) ->
    (* fail(code, msg)：构造错误值临时槽（value 字段不初始化） *)
    let oc = lexpr l code and om = lexpr l msg in
    let d = fresh l in
    emit l (MErrNew (d, e.ety, oc, om));
    op (OLocal d) e.ety
  | EPanicK (code, msg) ->
    (* panic：调用运行时后不返回；后继代码落入死块（死代码消除删除） *)
    let oc = Option.map (lexpr l) code in
    let om = lexpr l msg in
    emit l (MPanic (oc, om));
    set_term l TUnreachable;
    l.cur <- new_block l;
    op (OInt 0L) TVoid
  | EUnwrapK (a, b) ->
    (* a ?? b：短路——a 成功取 value，失败才求值 b；结果写元素类型临时槽 *)
    let va = lexpr l a in
    let rslot = fresh l in
    emit l (MAlloca (rslot, e.ety));
    let okr = fresh l in
    emit l (MErrIsOk (okr, va, a.ety));
    let bok = new_block l and berr = new_block l and bend = new_block l in
    set_term l (TCondBr (op (OLocal okr) TBool, bok.bid, berr.bid));
    l.cur <- bok;
    let dv = fresh l in
    emit l (MErrValue (dv, va, a.ety));
    emit l (MCopy (rslot, op (OLocal dv) e.ety, e.ety));
    set_term l (TBr bend.bid);
    l.cur <- berr;
    let vb = lexpr l b in
    emit l (MCopy (rslot, vb, e.ety));
    set_term l (TBr bend.bid);
    l.cur <- bend;
    op (OLocal rslot) e.ety
  | EPropagateK a ->
    (* a?：失败即从函数传播返回错误（先 RAII 释放全部局部资源，
       再把错误值拷入返回槽）；成功取 value 继续 *)
    let va = lexpr l a in
    let okr = fresh l in
    emit l (MErrIsOk (okr, va, a.ety));
    let bfail = new_block l and bok = new_block l in
    set_term l (TCondBr (op (OLocal okr) TBool, bok.bid, bfail.bid));
    l.cur <- bfail;
    emit_frees_from l 0;
    emit l (MErrFillOut (va, a.ety));
    set_term l (TRet None);
    l.cur <- bok;
    let dv = fresh l in
    emit l (MErrValue (dv, va, a.ety));
    op (OLocal dv) e.ety
  | EErrOkK v ->
    (* T 值自动包装为 TErr T（赋值/传参/返回处的 coerce） *)
    let ov = lexpr l v in
    let d = fresh l in
    emit l (MErrOk (d, e.ety, ov));
    op (OLocal d) e.ety
  | EFindK (s, c, k) ->
    (* find(s, c, k)：运行时查找，产 TErr i64（sret） *)
    let os = lexpr l s and oc = lexpr l c and ok = lexpr l k in
    let d = fresh l in
    emit l (MCall (Some d, "zfy_err_find", [ os; oc; ok ], e.ety));
    op (OLocal d) e.ety

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
    (* 标量声明：变量永远有值，必有初值；非 unred frac 存入后约分。
       初值是本语句的 seq 临时（如 split 结果）时直接 move 所有权免克隆 *)
    declare_owned l name ty;
    let v = lexpr l init in
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
                         v, is_list, false)))
      inits
  | SSeqCopyK (_, name, elem, len, src, is_list) ->
    (* 数组/列表整体初值：目标槽位无需预分配（初值直接覆盖，
       旧值释放语义不变）；若初值是本语句的 seq 临时（如切片结果）
       则直接 move 所有权，免去克隆 *)
    let tgt = if is_list then TList elem else TArray (elem, Int64.to_int len) in
    declare_owned l name tgt;
    let v = lexpr l src in
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
     | _ -> merr lhs.epos "unsupported assignment target")
  | SAugIndexK (name, elem, idx, bop, v, grow) ->
    (* a[i] op= v：下标只求值一次（load + op + store 同一槽位�?*)
    let oi = lexpr l idx in
    let old = fresh l in
    emit l (MSeqGet (old, op (OLocal name) (TList elem), oi, elem, l.unchecked));
    let ov = lexpr l v in
    let r = fresh l in
    emit l (MBinop (r, bop, op (OLocal old) elem, ov));
    emit l (MSeqSet (name, elem, oi, op (OLocal r) elem, grow, l.unchecked))
  | SAugVarK (name, ty, bop, v, nn) ->
    (* x op= v：load + op + store 同一槽位 *)
    let ov = lexpr l v in
    let r = fresh l in
    emit l (MBinop (r, bop, op (OLocal name) ty, ov));
    emit l (MCopy (name, op (OLocal r) ty, ty));
    if nn then emit l (MNorm (name, ty))
  | SSeqSetK (name, elem, idx, v, grow) ->
    (* 元素写入：元素类型决定写入宽度；grow 允许列表扩长 *)
    emit l (MSeqSet (name, elem, lexpr l idx, lexpr l v, grow, l.unchecked))
  | SRemoveK (name, elem, idx, is_list) ->
    (* remove(数组/列表, i)：数组槽位填零值；列表删除并左移，长度-1 *)
    emit l (MSeqRemove (name, elem, lexpr l idx, is_list))
  | SAugSliceK (name, elem, a, b, st, bop, v) ->
    (* a[x,y:st] op= v：运行时逐元素原地运算 *)
    emit l (MAugSlice (name, elem, lexpr l a, lexpr l b, lexpr l st, bop,
                       lexpr l v))
  | SFieldSetK (root, idxs, rootty, v) ->
    (* 字段写入：GEP 直达字段，深拷贝新值 + 释放旧值（llvmgen 按字段类型分派） *)
    emit l (MFieldStore (op (OLocal root) rootty, rootty, idxs, lexpr l v))
  | SAugFieldK (root, idxs, rootty, bop, v) ->
    (* 字段增广：load 字段 + op + 写回（字段只求值一次；字段类型 = 右值类型） *)
    let fty = v.ety in
    let old = fresh l in
    emit l (MFieldGet (old, op (OLocal root) rootty, rootty, idxs, fty));
    let ov = lexpr l v in
    let r = fresh l in
    emit l (MBinop (r, bop, op (OLocal old) fty, ov));
    emit l (MFieldStore (op (OLocal root) rootty, rootty, idxs,
                         op (OLocal r) fty))
  | SDerefSetK (p, v) ->
    (* 指针解引用写入 p* = v：地址先求值，store 值（仅标量/指针目标） *)
    let pv = lexpr l p in
    let vv = lexpr l v in
    emit l (MStoreK (pv, v.ety, vv))
  | SAugDerefK (p, bop, v) ->
    (* 指针解引用复合赋值 p* op= v：load 旧值 + op + store（p 只求值一次） *)
    let pv = lexpr l p in
    let old = fresh l in
    emit l (MLoadK (old, pv, v.ety));
    let ov = lexpr l v in
    let r = fresh l in
    emit l (MBinop (r, bop, op (OLocal old) v.ety, ov));
    emit l (MStoreK (pv, v.ety, op (OLocal r) v.ety))
  | SUnsafeK b ->
    (* unsafe 块：门禁在 typeck 已检查；块内关闭下标越界检查（@unchecked） *)
    let saved = l.unchecked in
    l.unchecked <- true;
    lblock l b;
    l.unchecked <- saved
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
    l.cur <- bbody;
    lblock l body;
    emit_frees_from l body_depth;
    set_term l (TBr bcond.bid);
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
    l.cur <- bbody;
    lblock l body;
    emit_frees_from l body_depth;
    set_term l (TBr bupd.bid);
    l.cur <- bupd;
    List.iter (lstmt l) updates;
    set_term l (TBr bcond.bid);
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
     | _ -> merr x.epos "reduce target must be a frac-typed local variable")
  | SBreakK ->
    (match l.loops with
     | (bk, _, body_depth) :: _ ->
       (* 跳出前释放循环体内层作用域的全部资源 *)
       emit_frees_from l body_depth;
       set_term l (TBr bk);
       l.cur <- new_block l            (* 后续死代码放入孤立块 *)
     | [] -> merr s.spos "break outside a loop")
  | SContinueK ->
    (match l.loops with
     | (_, ck, body_depth) :: _ ->
       emit_frees_from l body_depth;
       set_term l (TBr ck);
       l.cur <- new_block l
     | [] -> merr s.spos "continue outside a loop")
  | SUnwrapBlockK (is_decl, slot, elem, a, errslot, blk) ->
    (* a ?? 缩进块：a 成功 → value 写入目标槽；失败 → code/msg 拷入 err 槽，
       执行块（块内可用 err，块末表达式已由 typeck 改写为对目标槽的赋值），
       两路在结尾汇合 *)
    if is_decl then begin
      declare_owned l slot elem
    end;
    let va = lexpr l a in
    let okr = fresh l in
    emit l (MErrIsOk (okr, va, a.ety));
    let bok = new_block l and berr = new_block l and bend = new_block l in
    set_term l (TCondBr (op (OLocal okr) TBool, bok.bid, berr.bid));
    (* 成功路径：取 value 写入目标槽 *)
    l.cur <- bok;
    let dv = fresh l in
    emit l (MErrValue (dv, va, a.ety));
    emit l (MCopy (slot, op (OLocal dv) elem, elem));
    set_term l (TBr bend.bid);
    (* 失败路径：填 err 槽后执行块（独立 RAII 作用域） *)
    l.cur <- berr;
    emit l (MErrFillErr (errslot, va, a.ety));
    l.scopes <- ref [] :: l.scopes;
    let outer = List.length (List.tl l.scopes) in
    lblock l blk;
    emit_frees_from l outer;
    set_term l (TBr bend.bid);
    l.scopes <- List.tl l.scopes;
    l.cur <- bend

(* ---------- 函数降码 ---------- *)

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
      | SUnwrapBlockK (is_decl, slot, elem, _, errslot, blk) ->
        (* 解包块：目标槽（声明时）与 err 槽（Err struct）都需要入口 alloca；
           err 槽不登记 RAII（msg 有意泄漏，且槽可复用） *)
        if is_decl && slot.[0] <> '@' then acc := (slot, elem) :: !acc;
        acc := (errslot, TStruct "Err") :: !acc;
        collect_lets acc blk
      | SWhileK (_, b) -> collect_lets acc b
      | SUnsafeK b -> collect_lets acc b
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
      loops = []; scopes = []; stmt_temps = []; unchecked = false }
  in
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
  | MErrNew (_, _, c, m) -> operand_names c @ operand_names m
  | MErrOk (_, _, v) -> operand_names v
  | MErrIsOk (_, slot, _) -> operand_names slot
  | MErrValue (_, slot, _) -> operand_names slot
  | MErrFillErr (_, v, _) -> operand_names v
  | MErrFillOut (v, _) -> operand_names v
  | MPanic (c, m) ->
    (match c with Some o -> operand_names o | None -> []) @ operand_names m
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
  | MSeqSet (_, _, idx, v, _, _) -> operand_names idx @ operand_names v
  | MFreeVar _ -> []
  | MFreeTemp _ -> []
  | MFreeSeqTemp _ -> []
  | MSeqGet (_, base, idx, _, _) -> operand_names base @ operand_names idx
  | MSeqLen (_, base) -> operand_names base
  | MSeqSlice (_, src, a, b, st, _) ->
    operand_names src @ operand_names a @ operand_names b @ operand_names st
  | MStructNew (_, _, fs) -> List.concat_map (fun (_, o) -> operand_names o) fs
  | MFieldGet (_, root, _, _, _) -> operand_names root
  | MFieldStore (root, _, _, v) -> operand_names root @ operand_names v
  | MEmptySeq _ -> []
  | MFreeStructTemp _ -> []
  | MAddrOf (_, slot) -> [ slot ]
  | MLoadK (_, a, _) -> operand_names a
  | MStoreK (a, _, v) -> operand_names a @ operand_names v
  | MFieldAddr (_, root, _, _, _) -> operand_names root
  | MElemAddr (_, base, idx, _) -> operand_names base @ operand_names idx
  | MIndirectCall (_, f, args, _) ->
    operand_names f @ List.concat_map operand_names args
  | MFunAddr _ -> []

let pure_dst (i : instr) : string option =
  match i with
  | MBinop (d, _, _, _) | MUnop (d, _, _) | MCast (d, _, _) ->
    if String.length d > 0 && d.[0] = '%' then Some d else None
  (* 指针取地址/读/字段地址/元素地址/函数地址均为纯求值（间接调用有副作用除外）；
     错误值判定/取值同理（只读槽） *)
  | MAddrOf (d, _) | MLoadK (d, _, _) | MFieldAddr (d, _, _, _, _)
  | MElemAddr (d, _, _, _) | MFunAddr (d, _)
  | MErrIsOk (d, _, _) | MErrValue (d, _, _) ->
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
  { mfns; mstructs = h.hstructs }

