(* MIR：基本块 + 三地址码；含常量折叠与死代码消除 *)
open Tokens
open Hir

exception MirError of pos * string

let merr p fmt = Printf.ksprintf (fun s -> raise (MirError (p, s))) fmt

(* 任务一：整数溢出检查开关（与 Llvmgen.set_wrap_overflow 同步）。
   检查模式（默认）：常量折叠出溢出 → 编译期错误（消息含
   "constant overflow"）；--wrap-overflow：保持旧的静默回绕折叠。 *)
let wrap_overflow = ref false
let set_wrap_overflow b = wrap_overflow := b

(* 任务二：顶层函数符号属性（driver 在类型检查前从 AST 登记）：
   export "name" → 导出别名；section "seg" → 链接段；internal → 不导出 *)
let fn_export : (string, string) Hashtbl.t = Hashtbl.create 8
let fn_section : (string, string) Hashtbl.t = Hashtbl.create 8
let fn_internal : (string, unit) Hashtbl.t = Hashtbl.create 8

(* 有符号整数类型 w 位的取值范围（w ≤ 64；w = 64 用 Int64 极值） *)
let int_range_of (w : int) : int64 * int64 =
  if w >= 64 then (Int64.min_int, Int64.max_int)
  else (Int64.neg (Int64.shift_left 1L (w - 1)),
        Int64.sub (Int64.shift_left 1L (w - 1)) 1L)

(* 无符号整数类型 w 位的最大值（w ≤ 64；w = 64 为全 1 位型 -1L） *)
let uint_max_of (w : int) : int64 =
  if w >= 64 then -1L else Int64.sub (Int64.shift_left 1L w) 1L

let const_overflow p what =
  merr p "constant overflow in integer %s" what

(* 任务一：常量整数运算的编译期溢出判定（仅检查模式生效） *)
let check_const_binop (p : pos) (bop : binop) (x : int64) (y : int64)
    (t : zty) : unit =
  if !wrap_overflow then ()
  else
    match t with
    | TInt w ->
      let (mn, mx) = int_range_of w in
      (match bop with
       | BAdd ->
         let r = Int64.add x y in
         if w < 64 then begin
           if r < mn || r > mx then const_overflow p "addition"
         end else if (x > 0L && y > 0L && r < 0L) || (x < 0L && y < 0L && r >= 0L) then
           const_overflow p "addition"
       | BSub ->
         let r = Int64.sub x y in
         if w < 64 then begin
           if r < mn || r > mx then const_overflow p "subtraction"
         end else if (x >= 0L && y < 0L && r < 0L) || (x < 0L && y >= 0L && r >= 0L) then
           const_overflow p "subtraction"
       | BMul ->
         if w < 64 then begin
           let r = Int64.mul x y in
           if r < mn || r > mx then const_overflow p "multiplication"
         end else if x <> 0L && y <> 0L then begin
           let r = Int64.mul x y in
           if (x = -1L && y = Int64.min_int) || (y = -1L && x = Int64.min_int)
              || Int64.div r x <> y then
             const_overflow p "multiplication"
         end
       | BDiv | BMod ->
         if w = 64 && x = Int64.min_int && y = -1L then
           const_overflow p "division"
       | _ -> ())
    | TUint w ->
      let mx = uint_max_of w in
      (match bop with
       | BAdd ->
         if Int64.unsigned_compare x (Int64.sub mx y) > 0 then
           const_overflow p "addition"
       | BSub ->
         if Int64.unsigned_compare x y < 0 then const_overflow p "subtraction"
       | BMul ->
         if y <> 0L && Int64.unsigned_compare x (Int64.unsigned_div mx y) > 0 then
           const_overflow p "multiplication"
       | _ -> ())
    | _ -> ()

let check_const_uneg (p : pos) (x : int64) (t : zty) : unit =
  if !wrap_overflow then ()
  else
    match t with
    | TInt w -> let (mn, _) = int_range_of w in if x = mn then const_overflow p "negation"
    | _ -> ()

type operand = { o : op_kind; oty : zty }
and op_kind =
  | OInt of int64
  | OBig of string              (* i128/u128 大字面量（w-014 #6）：十进制数字串 *)
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
  | MStrAppend of string * operand list          (* string 原地追加（T7 优化）：槽 realloc 扩容逐个并入，旧指针所有权保留（不 free） *)
  | MMoveSeq of string * operand * zty           (* 所有权转移：释放目标旧值后直接接管临时（免克隆）；string/数组/列表=指针接管，struct=槽 memcpy *)
  | MClear of string * zty                       (* move 后清空变量槽（store null，防 RAII 双释放） *)
  | MBinop of string * binop * operand * operand
  | MUnop of string * unop * operand
  | MCast of string * operand * zty
  | MCall of string option * string * operand list * zty
  | MTry of operand               (* try(f)：zfy_try(code, env) -> i1 前置 i32 *)
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
  | MSetLoc of string * int
    (* panic 行号追踪（v3.5 DX）：每条语句入口写全局 @zfy_cur_line/@zfy_cur_file，
       zfy_panic（含 runtime 内部越界/除零等）打印 "  at file:line" *)
  | MAlloca of string * zty                      (* 变量槽（入口块统一分配�?*)
  | MFracNew of string * zty * operand * operand (* 分数字面量：… frac 类型, 分子, 分母 *)
  | MFracCast of string * operand * zty
    (* cast(frac, T) 转出（v3.23）：(目标寄存器, frac 操作数, 目标类型)。
       i64/u64 = n/d 截断整除（sdiv/udiv）；f64/f32 = n/d 实数除。
       frac 槽按 %frac.SUF {n, d} 布局直接 GEP 读字段，无需运行时调用 *)
  | MBoxAlloc of string * zty
    (* t-049/C：& 捕获堆箱槽的 rc 堆箱分配（槽名, 载荷类型=声明类型）。
       必须在声明点发射：循环体内声明逐轮分配，与作用域退出 MFreeVar 的
       rc release 逐次配平（MAlloca 在入口块仅执行一次，无法逐轮分配） *)
  | MNorm of string * zty                        (* frac 槽约分：调用 zfy_frac_norm_<suf> *)
  | MTempAlloca of string * zty                  (* 归一用临时聚合槽（llvmgen 入口块 alloca） *)
  | MSeqRemove of string * operand * operand * zty * bool
    (* remove 表达式（v3）：(目标寄存器, seq 操作数, 下标, 元素类型, 是否列表)。
       返回被删元素副本；数组=槽位填零、列表=删除并左移 *)
  | MAugSlice of string * zty * operand * operand * operand * binop * operand
    (* a[x,y:st] op= v：槽, 元素类型, 起点, 终点, 步长, 运算, 右值（逐元素原地） *)
  | MReduce of string * zty * operand * operand  (* reduce(root, frac 类型, 次数, 起始除数) *)
  | MPrintStr of string                          (* output：输出字符串字面�?*)
  | MPrintVal of operand                         (* output：按类型输出一个�?*)
  | MPrintSeq of operand * int * operand         (* output(数组/列表)（w-013）：(序列槽, 元素类型码, sep) *)
  | MPrintSeqNest of operand * int * int * operand (* output(嵌套序列)（w-015 #6）：(序列槽, 剩余层数, 叶元素类型码, sep) *)
  | MInput of string * zty * operand             (* input：delim 是 string 值（空串 = 默认换行和空白字符集） *)
  | MFreeVar of string * zty                     (* RAII：作用域退出释放变量持有的资源 *)
  | MFreeClo of string * string                  (* RAII（P0-1c）：释放闭包槽持有的 env 块
                                                    （槽名, clenv 布局名——级联释放捕获副本后 free 块） *)
  | MFreeTemp of string                          (* 语句末释放临时堆�?*)
  | MFreeSeqTemp of string * bool                (* 语句末释放临�?seq（bool=元素是否 string�?*)
  | MFreeVal of operand * zty
    (* 释放寄存器持有的堆值（w-014 #3 引用槽整体赋值用）：
       string 释放堆串；数组/列表释放 seq（bool 元素标志按类型推导） *)
  | MSeqAlloc of string * zty * int64 * bool
    (* 数组/列表分配：槽, 元素类型, 长度(列表�?0→编译器自选初始容�?, 是否列表 *)
  | MSeqSet of string * zty * operand * operand * bool * bool
    (* arr[i]=v：槽, 元素类型(决定写入宽度), 下标, 值, 可扩长 *)
  | MSeqSetAt of operand * zty * operand * operand * bool * bool
    (* arr[i]=v 槽地址版（w-014 #3）：槽地址(持有 seq 指针的槽), 元素类型,
       下标, 值, 可扩长, unchecked——字段链/ref 解引用/元素槽写目标 *)
  | MLoadSeq of string * operand
    (* 从槽地址 load seq 指针：目标, 槽地址操作数（MSeqSetAt/MSeqLenAt 前置） *)
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
  | MElemAddr of string * operand * operand * zty * bool
    (* 元素地址：dst = getelementptr（base ptr, 下标, 元素类型）；
       bool = 是否做边界检查（&x 显式取地址为 false，写目标定位为 true） *)
  | MSeqLit of string * zty * operand list
    (* 序列字面量（w-014 #3）：目标槽（alloca 持 seq 指针）, 元素类型, 元素值——
       分配 len=cap=元素个数的 seq 并逐元素写入 *)
  | MIndirectCall of string option * operand * operand list * zty
    (* 函数指针间接调用：dst, 被调指针值, 实参（标量语义借传）, 返回类型 *)
  | MClNew of string * string * string * operand list * zty
    (* 闭包构造（v3.7）：dst(h 句柄), closure$sig, clenv$N 布局类型,
       堆块内容 [code; caps...], 签名返回类型——分配 [8+caps] 堆块并
       逐字段写入（string/seq 捕获深拷贝），dst = 堆块地址 *)
  | MClCall of string option * operand * operand list * zty
    (* 闭包调用（v3.7）：dst, 闭包句柄 operand（槽）, 实参, 返回类型——
       h = 槽字段 0；code = 堆块头部；call code(h, args) *)
  | MFunAddr of string * string
    (* 函数入口地址：dst 寄存器持有 LLVM 符号文本（@名），作函数指针值 *)
  | MAsm of string * (string * zty) list * operand list * string list
    (* 内联汇编（v3.31，语句）：(模板, out（槽名, 类型）列表, in 值列表, clobber
       寄存器名列表)。llvmgen 发 call <ret> asm sideeffect；模板 $0.. 依次对应
       out（先）再 in（后）；out 结果按槽写回（boxed 槽经 ptr_of 取箱地址） *)
  | MAtomicLoad of string * operand * zty * int
    (* 原子读：目标寄存器, 指针, 元素类型, 内存序（0..4） *)
  | MAtomicStore of operand * operand * zty * int
    (* 原子写：指针, 值, 元素类型, 内存序 *)
  | MAtomicRMW of string * string * operand * operand * zty * int
    (* 原子读改写：目标寄存器, 运算(add/sub/and/or/xor/xchg), 指针, 值, 类型, 序 *)
  | MAtomicCAS of string * operand * operand * operand * zty * int * int
    (* 比较交换：目标(bool), 指针, 期望值, 新值, 类型, 成功序, 失败序 *)
  | MFence of int
    (* 内存屏障（内存序 0..4；0=Relaxed 无操作） *)
  | MVolatileLoad of string * operand * zty
    (* volatile 读（内存映射 I/O）：目标寄存器, 指针, 元素类型 *)
  | MVolatileStore of operand * operand * zty
    (* volatile 写（内存映射 I/O）：指针, 值, 元素类型 *)

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
  | FClo of string                (* 闭包句柄槽：env 块释放（clenv 布局名，P0-1c） *)

(* ---------- 降码上下�?---------- *)

type lctx = {
  blocks : (int, block) Hashtbl.t;
  mutable nb : int;
  mutable nt : int;
  mutable cur : block;
  mutable loops : (int * int * int * int) list;  (* (break 目标, continue 目标, 循环体作用域深度, 循环入口锁栈深度) *)
  mutable scopes : (string * zty) list ref list;  (* RAII 作用域栈：每层收集需释放变量 *)
  mutable stmt_temps : (string * free_kind) list;  (* 当前语句拥有的临时：(名, 释放类别) *)
  mutable unchecked : bool;  (* unsafe 块内：下标读写关闭越界检查（new2.md #3/@unchecked） *)
  mutable frunred : bool;    (* 当前函数返回类型带 unred：return 不做 frac 归一（new.md） *)
  mutable locks : operand list;  (* v3.26 P0-3：lock 块栈——return/break/continue
                                    穿越时按栈逆序补 zfy_mutex_unlock（配对回卷） *)
  mutable clo_envs : (string * string) list;  (* P0-1c：闭包变量槽 -> clenv 布局名
                                                （EClNewK 临时移入变量时登记，MFreeVar 级联释放用） *)
  unreds : (string, bool) Hashtbl.t;  (* unred frac 数组/列表槽名集合：元素存入不归一 *)
  boxed : (string, string) Hashtbl.t;  (* t-049/C：& 捕获堆箱槽（槽名 -> zbox 布局名）。
                                          这些槽存的是 rc 堆箱指针，llvmgen 在作用域退出
                                          发 zfy_rc_release——mir 侧据此强制登记 RAII，
                                          否则标量槽不满足 owned_ty 而漏发 MFreeVar（泄漏） *)
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

(* sort 内建（new.md 第3条）：元素类型 → 运行时排序后缀 tag；
   元素类型 → 混合键类别（0=有符号整数 1=无符号 2=浮点 3=string 4=bool 5=char）。
   mir 阶段 TVar 已由 typeck 收尾求解落地，这里按字面类型分派 *)
let resolve (t : zty) : zty = t

let sort_tag (t : zty) =
  match resolve t with
  | TInt w -> "i" ^ string_of_int w
  | TUint w -> "u" ^ string_of_int w
  | TFloat w -> "f" ^ string_of_int w
  | TString -> "str"
  | _ -> assert false

let seq_key_kind (t : zty) =
  let e = (match t with TArray (e, _) | TList e -> e | _ -> t) in
  match resolve e with
  | TInt _ -> 0 | TUint _ -> 1 | TFloat _ -> 2
  | TString -> 3 | TBool -> 4 | TChar -> 5
  | _ -> assert false

(* 需 RAII 释放的变量类型：string（堆串）、数组/列表（seq 资源）、struct（内含堆资源）。
   全局变量槽（'@' 前缀）不属于函数作用域，永不释放。
   v3.27 P0-1：句柄（mutex$/chan$/thread$）、接口（iface$X）、闭包
   （closure$*）也是 owned——声明作用域退出自动释放（free_kind/llvmgen 分派） *)
let is_handle_sname (s : string) =
  s = "mutex$" || s = "thread$"
  || (String.length s > 5 && String.sub s 0 5 = "chan$")
let is_clo_sname (s : string) =
  String.length s > 8 && String.sub s 0 8 = "closure$"
let is_move_only_sname (s : string) =
  (* 接口 iface$X 不在此列（本轮）：接口值可深拷贝（vtable clone），
     按普通 struct 走 assign/free 级联 *)
  is_handle_sname s || is_clo_sname s

let owned_ty (name : string) (t : zty) =
  match t with
  | TString | TArray _ | TList _ | TStruct _ | TFile -> name.[0] <> '@'
  | _ -> false

(* move-only 类型（P0-1a/b/c）：句柄/接口/闭包——变量间转移 = 所有权
   转移（源槽清空），值语义拷贝废止 *)
let move_only_ty (t : zty) =
  match t with
  | TFile -> true
  | TStruct s -> is_move_only_sname s
  | _ -> false

(* 在当前作用域登记需 RAII 释放的变量（后声明先释放）。
   t-049/C：& 捕获堆箱槽（boxed 表内）强制登记——无论槽类型是否 owned_ty，
   作用域退出都要对箱做 rc release（llvmgen 的 MFreeVar boxed 分支接管） *)
let declare_owned l name ty =
  if owned_ty name ty || Hashtbl.mem l.boxed name then
    match l.scopes with
    | top :: _ -> top := (name, ty) :: !top
    | [] -> ()

(* frac 存储归一（new.md 2026-10-10）：存入非 unred frac 位置的值先约分。
   临时槽（%）原地归一；变量/全局源先拷贝到临时再归一（源不变，
   如 unred 变量赋给非 unred 目标：目标得最简形态、源保持 4/8）。
   全局常量（ginit 已归一）与寄存器值不动 *)
let norm_frac_val l (v : operand) (ty : zty) : operand =
  match ty with
  | TFrac _ ->
    (match v.o with
     | OLocal n when n.[0] = '%' ->
       emit l (MNorm (n, ty)); v
     | OLocal _ ->
       (* 变量/全局槽源：拷贝到临时后归一（源不变） *)
       let t = fresh l in
       emit l (MTempAlloca (t, ty));
       emit l (MCopy (t, v, ty));
       emit l (MNorm (t, ty));
       op (OLocal t) ty
     | _ -> v)
  | _ -> v

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
    | FClo _, TStruct s -> is_clo_sname s
    | _ -> false
  in
  match v.o, ty with
  | OLocal d, (TString | TArray _ | TList _ | TStruct _) ->
    let rec go acc = function
      | [] -> false
      | (n, kind) :: rest when n = d && kind_matches kind ->
        l.stmt_temps <- List.rev_append acc rest;
        (match kind with
         | FClo clenv -> l.clo_envs <- (name, clenv) :: l.clo_envs
         | _ -> ());
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
        | FStruct t -> emit l (MFreeStructTemp (n, t))
        | FClo clenv -> emit l (MFreeClo (n, clenv)))
      ts

(* RAII：从作用域栈顶释放到深度 depth（不含），内层作用域先释放�?   层内后声明先释放；skip 中的变量名不释放（如�?return 转移的返回值） *)
let emit_frees_from_skip l depth skip =
  let rec go = function
    | [] -> ()
    | top :: rest when List.length rest >= depth ->
      List.iter
        (fun (n, t) ->
          if not (List.mem n skip) then
            match t with
            | TStruct s when is_clo_sname s ->
              (match List.assoc_opt n l.clo_envs with
               | Some clenv -> emit l (MFreeClo (n, clenv))
               | None -> emit l (MFreeVar (n, t)))
            | _ -> emit l (MFreeVar (n, t)))
        !top;
      go rest
    | _ -> ()
  in
  go l.scopes

let emit_frees_from l depth = emit_frees_from_skip l depth []

(* v3.26 P0-3：锁栈回卷——把锁栈回卷到 depth（对 depth 之上的锁按入栈
   逆序发 zfy_mutex_unlock）。return 全回卷（depth=0）；break/continue 只
   回卷到循环入口深度（外层 lock 块仍持有，不得误放） *)
let emit_unlocks_to l depth =
  let rec go n = function
    | mo :: rest when n > depth ->
      emit l (MCall (None, "zfy_mutex_unlock", [ mo ], TVoid));
      go (n - 1) rest
    | _ -> ()
  in
  let len = List.length l.locks in
  go len l.locks;
  l.locks <- List.filteri (fun i _ -> i < depth) l.locks

let emit_unlocks l = emit_unlocks_to l 0

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

(* output 序列元素类型码（对应 runtime zfy_print_seq，w-013）：
   0 i8 1 i16 2 i32 3 i64 4 u8 5 u16 6 u32 7 u64 8 i128 9 u128
   10 f32 11 f64 12 char 13 bool 14 string *)
(* 序列嵌套层数：i32[] → 1，i32[][] → 2，i32[2][3] → 2 *)
let rec seq_depth (z : zty) : int =
  match z with
  | TArray (_, _) | TList _ -> 1 + seq_depth (seq_elem z)
  | _ -> 0

(* 剥到最内层元素类型 *)
and seq_elem (z : zty) : zty =
  match z with
  | TArray (e, _) | TList e -> e
  | _ -> z

(* 最内层叶元素的打印类型码（嵌套序列用；typeck 已校验叶可打印） *)
let rec leaf_kind_of (z : zty) : int =
  match z with
  | TArray (_, _) | TList _ -> leaf_kind_of (seq_elem z)
  | TInt 8 -> 0 | TInt 16 -> 1 | TInt 32 -> 2 | TInt 64 -> 3
  | TUint 8 -> 4 | TUint 16 -> 5 | TUint 32 -> 6 | TUint 64 -> 7
  | TInt 128 -> 8 | TUint 128 -> 9
  | TFloat 32 -> 10 | TFloat 64 -> 11
  | TChar -> 12 | TBool -> 13 | TString -> 14
  | TVar _ -> 3
  | _ -> assert false

let elem_kind_of (z : zty) : int =
  match z with
  | TArray (e, _) | TList e ->
    (match e with
     | TInt 8 -> 0 | TInt 16 -> 1 | TInt 32 -> 2 | TInt 64 -> 3
     | TUint 8 -> 4 | TUint 16 -> 5 | TUint 32 -> 6 | TUint 64 -> 7
     | TInt 128 -> 8 | TUint 128 -> 9
     | TFloat 32 -> 10 | TFloat 64 -> 11
     | TChar -> 12 | TBool -> 13 | TString -> 14
     | TVar _ -> 3
     | _ -> assert false)   (* typeck 已校验元素类型 *)
  | _ -> assert false

(* 赋值目标 / push 槽根的槽键：(根槽名, 字段序号链)。解引用/元素槽等
   复杂根返回 None（不参与同槽判定）。用于 xs = push(xs, v) 零拷贝特判 *)
let seq_root_key_opt (e : texpr) : (string * int list) option =
  let rec go acc x =
    match x.e with
    | EFieldK (b, i) -> go (i :: acc) b
    | EVarK n -> Some (n, acc)
    | _ -> None
  in
  go [] e

let same_seq_root (a : texpr) (b : texpr) : bool =
  match seq_root_key_opt a, seq_root_key_opt b with
  | Some ka, Some kb -> ka = kb
  | _ -> false

(* 字段链根展平（t-049/B）：EFieldK 链 → (根操作数, 前置序号链, 根类型)。
   EVarK → 变量槽；EDerefK (EVarK n)（TPtr）→ 指针槽（MFieldGet/Store
   按 TPtr 根自动解引用）；EFieldK（捕获字段形态 deref($env).p）→ 递归
   展平，序号并入前置链——GEP 一次直达最终字段。供 SFieldSetK /
   SAugFieldK 的捕获根分派使用（lexpr EFieldK 读路径另有自己的
   flatten + lexpr base fallback，语义不同不共用） *)
let flatten_field_root (l : lctx) (root : texpr) : operand * int list * zty =
  let rec go acc b =
    match b.e with
    | EFieldK (b', i) -> go (i :: acc) b'
    | EVarK n -> (op (OLocal n) b.ety, acc, b.ety)
    | EDerefK ({ e = EVarK n; ety = TPtr t; _ }) ->
      (op (OLocal n) (TPtr t), acc, TPtr t)
    | _ -> merr b.epos "unsupported field chain root"
  in
  go [] root

(* 原子/volatile 内建名解析（v3.31）：typeck 产出规范名
   zfy_atomic_{load,store,add,sub,and,or,xor,exchange,cas}_<宽>,
   zfy_atomic_fence、zfy_volatile_{load,store}_<宽>。
   atomic_inc 不在此列（继续走 runtime 调用）。返回 (运算, 位宽)；
   volatile 运算名带 "v" 前缀（vload/vstore） *)
let atomic_core_name (name : string) : (string * int) option =
  if name = "zfy_atomic_fence" then Some ("fence", 0)
  else
    let pfx =
      if String.length name > 11 && String.sub name 0 11 = "zfy_atomic_" then
        Some (11, "")
      else if String.length name > 13 && String.sub name 0 13 = "zfy_volatile_" then
        Some (13, "v")
      else None
    in
    match pfx with
    | None -> None
    | Some (pl, vp) ->
      (match String.rindex_opt name '_' with
       | Some i when i > pl ->
         let op = String.sub name pl (i - pl) in
         let ws = String.sub name (i + 1) (String.length name - i - 1) in
         (match op, int_of_string_opt ws with
          | ("load" | "store" | "add" | "sub" | "and" | "or" | "xor"
            | "exchange" | "cas"), Some w -> Some (vp ^ op, w)
          | _ -> None)
       | _ -> None)

let rec lexpr l (e : texpr) : operand =
  match e.e with
  | EIntK n ->
    (match e.ety with
     | TFloat _ -> op (OFloat (Int64.to_float n)) e.ety
     | _ -> op (OInt n) e.ety)
  | EBigK digits -> op (OBig digits) e.ety
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
     | TBool when a.ety = TString
                  && List.mem b [ BEq; BNe; BLt; BGt; BLe; BGe ] ->
       (* string 比较（w-020）：==/!= 内容比较；< <= > >= 走 strcmp 三态
          与 0 比（逐字符 ASCII，比到第一个不同即断） *)
       let d = fresh l in
       if b = BEq || b = BNe then
         emit l (MCall (Some d, (if b = BEq then "zfy_str_eq" else "zfy_str_ne"),
                        [ oa; ob ], TBool))
       else begin
         let c = fresh l in
         emit l (MCall (Some c, "zfy_str_cmp", [ oa; ob ], TInt 32));
         emit l (MBinop (d, b, op (OLocal c) (TInt 32), { o = OInt 0L; oty = TInt 32 }))
       end;
       op (OLocal d) TBool
     | _ ->
       let d = fresh l in
       (* 任务一：常量折叠前的溢出检查（只用左操作数类型：算术结果类型
          与左操作数一致；比较结果为 bool 不检查） *)
       (match oa.o, ob.o with
        | OInt x, OInt y -> check_const_binop e.epos b x y a.ety
        | _ -> ());
       emit l (MBinop (d, b, oa, ob));
       op (OLocal d) e.ety)
  | EUnK (u, a) ->
    let oa = lexpr l a in
    (match u, oa.o with
     | UNeg, OInt x -> check_const_uneg e.epos x a.ety
     | _ -> ());
    let d = fresh l in
    emit l (MUnop (d, u, oa));
    op (OLocal d) e.ety
  | ECastK (a, t) when (match a.ety with TFrac _ -> true | _ -> false) ->
    (* cast(frac, T)（v3.23）：frac 转出（i64/u64 截断整除、f64/f32 实数除，
       typeck 已限定目标与元素宽度）；frac 槽按 {n, d} 布局读字段 *)
    let oa = lexpr l a in
    let d = fresh l in
    emit l (MFracCast (d, oa, e.ety));
    op (OLocal d) e.ety
  | ECastK (a, t) when a.ety = TString ->
    (* string → 数值 cast：错误值路径（e.ety 为 TErr）以 sret 写 TErr 聚合，
       失败产 CAST 错误值；128 位整数目标用 32 字节 zfy_err_wide 容器
       （new.md 2026-10-11，用户拍板改为产错误值）；f128 保持 fail-fast
       （zfy_stod_wide，无 T! 包装）。窄整数走 zfy_stoi_err（24 字节容器） *)
    let oa = lexpr l a in
    (match e.ety with
     | TErr _ ->
       let fn =
         match t with
         | TInt 128 | TUint 128 -> "zfy_stoi_wide_err"
         | TFloat _ -> "zfy_stod_err"
         | _ -> "zfy_stoi_err"
       in
       let d = fresh l in
       emit l (MCall (Some d, fn, [ oa ], e.ety));
       op (OLocal d) e.ety
     | _ ->
       (* fail-fast 宽通道（f128 / 非 TErr 上下文的 128 位目标） *)
       let fn = match t with TFloat 128 -> "zfy_stod_wide" | _ -> "zfy_stoi_wide" in
       let d = fresh l in
       emit l (MCall (Some d, fn, [ oa ], t));
       op (OLocal d) e.ety)
  | ECastK (a, t) ->
    let oa = lexpr l a in
    let d = fresh l in
    emit l (MCast (d, oa, t));
    op (OLocal d) e.ety
  | ECallK ("zfy_try", [ cb ], _) ->
    (* try(f)：特判降码。f 是零参闭包，lexpr 产出闭包句柄 struct 槽
       { ptr h }——字段 0 = 堆块地址 h；h 处首 8 字节 = 代码指针 code。
       调 zfy_try(code, h) 返回 i32（0=正常完成，非 0=panic 捕获），
       与 0 比较转 bool *)
    let oh = lexpr l cb in
    (match oh.oty with
     | TStruct cs ->
       let hp = fresh l in
       emit l (MFieldAddr (hp, oh, TStruct cs, [ 0 ], TPtr (TUint 8)));
       let h = fresh l in
       emit l (MLoadK (h, op (OLocal hp) (TPtr (TPtr (TUint 8))), TPtr (TUint 8)));
       let code = fresh l in
       emit l (MLoadK (code, op (OLocal h) (TPtr (TPtr (TUint 8))), TPtr (TUint 8)));
       let d = fresh l in
       emit l
         (MCall
            ( Some d,
              "zfy_try",
              [ op (OLocal code) (TPtr (TUint 8));
                op (OLocal h) (TPtr (TUint 8)) ],
              TInt 32 ));
       let b = fresh l in
       emit l (MBinop (b, BNe, op (OLocal d) (TInt 32), op (OInt 0L) (TInt 32)));
       op (OLocal b) e.ety
     | t -> merr e.epos "zfy_try: expected closure handle, got %s" (Hir.pp_zty t))
  | ECallK ("zfy_panic_msg", _, _) ->
    (* panic_msg()：直接调运行时取最近一次 panic 消息（无捕获时空串） *)
    let d = fresh l in
    emit l (MCall (Some d, "zfy_panic_msg", [], TString));
    op (OLocal d) e.ety
  | ECallK (f, args, _moves) when atomic_core_name f <> None ->
    (* 原子/volatile 内建（v3.31）：直发 LLVM 原子/volatile 指令（不经 runtime）。
       实参序已由 typeck 规整（内存序位置为 i32 常量 0..4） *)
    let (aop, _w) =
      match atomic_core_name f with Some x -> x | None -> assert false
    in
    let oargs = List.map (lexpr l) args in
    (* 元素类型按需取：fence 没有指针实参（唯一实参是内存序 i32） *)
    let elem_ty () =
      match oargs with
      | p :: _ ->
        (match p.oty with
         | TPtr et -> et
         | t ->
           merr e.epos "atomic builtin expects a pointer argument, got %s"
             (Hir.pp_zty t))
      | [] -> merr e.epos "atomic builtin expects a pointer argument"
    in
    let ord (o : operand) : int =
      match o.o with
      | OInt n -> Int64.to_int n
      | _ -> merr e.epos "atomic ordering must be a constant (Ordering.*)"
    in
    (match aop, oargs with
     | "load", [ p; o ] ->
       let d = fresh l in
       emit l (MAtomicLoad (d, p, elem_ty (), ord o));
       op (OLocal d) e.ety
     | "store", [ p; v; o ] ->
       emit l (MAtomicStore (p, v, elem_ty (), ord o));
       op (OInt 0L) TVoid
     | ("add" | "sub" | "and" | "or" | "xor" | "exchange"), [ p; v; o ] ->
       let d = fresh l in
       let opn = if aop = "exchange" then "xchg" else aop in
       emit l (MAtomicRMW (d, opn, p, v, elem_ty (), ord o));
       op (OLocal d) e.ety
     | "cas", [ p; ex; nw; os; of_ ] ->
       let d = fresh l in
       emit l (MAtomicCAS (d, p, ex, nw, elem_ty (), ord os, ord of_));
       op (OLocal d) e.ety
     | "fence", [ o ] ->
       (* 内存屏障：唯一实参是内存序，没有指针 *)
       emit l (MFence (ord o));
       op (OInt 0L) TVoid
     | "vload", [ p ] ->
       let d = fresh l in
       emit l (MVolatileLoad (d, p, elem_ty ()));
       op (OLocal d) e.ety
     | "vstore", [ p; v ] ->
       emit l (MVolatileStore (p, v, elem_ty ()));
       op (OInt 0L) TVoid
     | _ -> merr e.epos "malformed atomic/volatile builtin call %s" f)
  | ECallK (f, args, moves) ->
    (* spawn 特判（P0-1c 类别 2）：env 所有权移交线程（线程体结束线程侧
       释放）。实参为语句临时闭包时从 stmt_temps 摘除（宿主不再释放）；
       为变量槽时调用后清槽（typeck 已标记 moved） *)
    if f = "zfy_thread_spawn" then begin
      match args with
      | [ cb ] ->
        let oc = lexpr l cb in
        let need_clear =
          match oc.o with
          | OLocal n when n.[0] = '%' ->
            let rec go acc = function
              | [] -> false
              | (m, FClo _) :: rest when m = n ->
                l.stmt_temps <- List.rev_append acc rest; true
              | x :: rest -> go (x :: acc) rest
            in
            go [] l.stmt_temps
          | OLocal n when n.[0] <> '@' -> true
          | _ -> false
        in
        let d = fresh l in
        (* ret 类型 = e.ety（thread$）：dst 槽是 thread 句柄槽；
           用 oc.oty（closure）会让 thread$ 变量槽 alloca 成闭包槽，
           RAII 按 thread$ 释放时 free 错地址 → AV *)
        emit l (MCall (Some d, "zfy_thread_spawn", [ oc ], e.ety));
        (* 清槽在调用之后：spawn 需读闭包 env 指针移交线程 *)
        (match oc.o with
         | OLocal n when n.[0] <> '@' && n.[0] <> '%' -> emit l (MClear (n, oc.oty))
         | _ -> ());
        ignore need_clear;
        op (OLocal d) e.ety
      | _ -> merr e.epos "spawn expects exactly one argument"
    end
    else
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
            (* 显式 move：typeck 已保证局部 owned 变量（string/数组/列表/
               File/句柄/接口/闭包，P0-1 扩展） *)
            (match o.o, o.oty with
             | OLocal n, (TString | TArray _ | TList _ | TFile) when n.[0] <> '@' ->
               (true, Some (n, o.oty))
             | OLocal n, TStruct s when is_move_only_sname s && n.[0] <> '@' ->
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
       | TList TString -> add_temp l d' (FSeq true)  (* read_lines 等运行时返回列表 *)
       | TList _ -> add_temp l d' (FSeq false)       (* v3.6 容器内建返回的标量列表 *)
        | _ -> ())
     | _ -> ());
    (match d with
     | Some d' -> op (OLocal d') e.ety
     | None -> op (OInt 0L) TVoid)
  | ESeqGetK (b, i) ->
    (* arr[i]：结果写入元素类型临时（越界运行时报错）。
       聚合元素（struct/嵌套 seq，w-014 #2/#4）为深拷贝副本：
       登记语句临时（语句末释放，整体赋值时 move 接管） *)
    let ob = lexpr l b and oi = lexpr l i in
    let elem = e.ety in
    let d = fresh l in
    emit l (MSeqGet (d, ob, oi, elem, l.unchecked));
    (match elem with
     | TStruct _ -> add_temp l d (FStruct elem)
     | TList _ | TArray _ -> add_temp l d (FSeq false)
     | _ -> ());
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
  | ESeqLitK (elem, elems) ->
    (* 序列字面量（w-014 #3）：分配 len=cap=N 的 seq 逐元素写入；
       结果登记为语句临时（整体赋值时 move 接管，免克隆） *)
    let d = fresh l in
    let vals = List.map (lexpr l) elems in
    emit l (MSeqLit (d, elem, vals));
    add_temp l d (FSeq (match elem with TString -> true | _ -> false));
    op (OLocal d) (TList elem)
  | EPushK (base, v) ->
    (* push(列表, 值)：下标 = 当前长度，写入时自动扩长。
       槽根分派（w-014 #3）：变量槽直写；字段链/ref 解引用/元素槽经槽地址。
       返回列表本身（v3 2026-10-11 表达式化）：变量槽直接以槽值为结果，
       其余槽根 load seq 头（指向 base 的堆，赋值目标异槽时由 MCopy 深拷贝） *)
    let elem = (match base.ety with
                | TList t -> t
                | TPtr (TList t) -> t
                | _ -> assert false) in
    (match base.e with
     | EVarK name ->
       let dl = fresh l in
       emit l (MSeqLen (dl, op (OLocal name) base.ety));
       let ov = lexpr l v in
       (* frac 列表 push：值归一（unred 列表豁免） *)
       let ov =
         match elem, base.e with
         | TFrac _, EVarK name when Hashtbl.find_opt l.unreds name = Some true -> ov
         | TFrac _, _ -> norm_frac_val l ov elem
         | _ -> ov
       in
       (* v3.3.4：MSeqLen 结果为 i32（length 改 i32），如实标注；
          llvmgen gen_seq_set 内统一下标提升 i64 *)
       emit l (MSeqSet (name, elem, op (OLocal dl) (TInt 32), ov, true, l.unchecked));
       op (OLocal name) base.ety
     | _ ->
       let addr = seq_slot_addr l base elem in
       let sp = fresh l in
       emit l (MLoadSeq (sp, addr));
       let dl = fresh l in
       emit l (MSeqLen (dl, op (OLocal sp) (TList elem)));
       let ov = lexpr l v in
       let ov = (match elem with TFrac _ -> norm_frac_val l ov elem | _ -> ov) in
       emit l (MSeqSetAt (addr, elem, op (OLocal dl) (TInt 32), ov, true, l.unchecked));
       op (OLocal sp) (TList elem))
  | ERemoveK (base, idx, is_list) ->
    (* remove(数组/列表, i)：表达式（v3 2026-10-11），返回被删元素的
       深拷贝副本（runtime elem_init 出独立值；数组=槽位填零、
       列表=删除并左移）。结果登记语句临时（string 元素语句末释放） *)
    let elem = (match base.ety with
                | TArray (t, _) | TList t | TPtr (TArray (t, _)) | TPtr (TList t) -> t
                | _ -> assert false) in
    let oi = lexpr l idx in
    let d = fresh l in
    (match base.e with
     | EVarK name ->
       emit l (MSeqRemove (d, op (OLocal name) base.ety, oi, elem, is_list))
     | _ ->
       let addr = seq_slot_addr l base elem in
       let sp = fresh l in
       emit l (MLoadSeq (sp, addr));
       emit l (MSeqRemove (d, op (OLocal sp) (TList elem), oi, elem, is_list)));
    (match elem with
     | TStruct _ -> add_temp l d (FStruct elem)
     | TString -> add_temp l d FStr
     | TList _ | TArray _ -> add_temp l d (FSeq false)
     | _ -> ());
    op (OLocal d) elem
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
       嵌套 struct 字段深拷贝到临时槽（值语义）。
       展平到 EVarK 失败时（w-014 #8：ps[1].x / f().x 等），先求基
       表达式（struct 结果为深拷贝临时槽/借用根），再从根 GEP 取字段 *)
    let rec flatten acc b =
      match b.e with
      | EFieldK (b', i) -> flatten (i :: acc) b'
      | EVarK n -> Some (n, acc, b.ety)
      (* deref(p).f（v3.7 闭包捕获）：p 槽持有指针，root 标 TPtr 由
         llvmgen MFieldGet load 后 GEP（自动解引用字段访问） *)
      | EDerefK ({ e = EVarK n; ety = TPtr t; _ }) -> Some (n, acc, TPtr t)
      | _ -> None
    in
    let (root, idxs, rootty) =
      match flatten [ idx ] base with
      | Some (n, idxs, rootty) -> (op (OLocal n) rootty, idxs, rootty)
      | None ->
        let rb = lexpr l base in
        (rb, [ idx ], base.ety)
    in
    let d = fresh l in
    emit l (MFieldGet (d, root, rootty, idxs, e.ety));
    (match e.ety with
     | TStruct _ -> add_temp l d (FStruct e.ety)  (* 深拷贝副本：语句末释放 *)
     | _ -> ());
    op (OLocal d) e.ety
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
       (* v3.3.8 泛化：字段链/元素嵌套地址（&a.b[i].c 等）——递归生成
          基地址（变量槽/字段 GEP/元素 MElemAddr），再逐级 MFieldAddr。
          非变量根的地址是寄存器值，MFieldAddr 侧统一以 TPtr rootty
          走 val_of（寄存器直取，不 load）；变量槽根保持原语义 *)
       let rec addr_of (x : texpr) : operand =
         match x.e with
         | EVarK n -> op (OLocal n) x.ety
         | EFieldK (b, i) ->
           let (pb, rootty) =
             match b.e with
             | EVarK _ -> (addr_of b, b.ety)
             | _ ->
               let pb = addr_of b in
               (pb, (match b.ety with
                     | TStruct s -> TPtr (TStruct s)
                     | t -> t))
           in
           let d = fresh l in
           emit l (MFieldAddr (d, pb, rootty, [ i ], x.ety));
           (* 结果标 x.ety（槽语义）：MElemAddr/MLoadK 对寄存器根直取
              SSA（不再 load），对 TList 根再取 data 字段——与变量槽
              「值=seq 指针」的既有约定一致 *)
           op (OLocal d) x.ety
         | ESeqGetK (b, i) ->
           (* 基语义须与「变量槽」一致：val_of(基) = seq 指针。
              EVarK 槽由 MElemAddr 自行 load；字段链等寄存器地址
              （reg = seq 槽地址）需先 load 出 seq 指针再传 *)
           let ob =
             match b.e with
             | EVarK _ -> addr_of b
             | _ ->
               let pa = addr_of b in
               let d = fresh l in
               emit l (MLoadK (d, pa, b.ety));
               op (OLocal d) b.ety
           in
           let oi = lexpr l i in
           let d = fresh l in
           emit l (MElemAddr (d, ob, oi, x.ety, false));
           op (OLocal d) x.ety
         | EDerefK p -> lexpr l p
         | _ -> merr x.epos "unsupported address-of target"
       in
       (* EFieldK 内部按字段类型标注（MElemAddr/MLoadK 语义需要），但
          EAddrOfK 的结果是指针值——重新标为外层 TPtr *)
       let o = addr_of a in
       { o with oty = e.ety }
     | ESeqGetK (b, i) ->
       (* 元素地址：基为变量槽/字段链/解引用等任意"seq 指针值"形态
          （w-014 #8 泛化；显式取地址，无越界检查） *)
       let ob = lexpr l b and oi = lexpr l i in
       let d = fresh l in
       emit l (MElemAddr (d, ob, oi, a.ety, false));
       op (OLocal d) e.ety
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
  | EClNewK (mangle, clenv, items) ->
    (* 闭包构造（v3.7）：分配堆块写入 code+捕获，句柄值 = 堆块地址。
       登记为 FClo 语句临时（P0-1c：语句末未移交则级联释放 env） *)
    let oitems = List.map (lexpr l) items in
    let d = fresh l in
    emit l (MClNew (d, mangle, clenv, oitems, e.ety));
    add_temp l d (FClo clenv);
    op (OLocal d) e.ety
  | EClCallK (cb, args) ->
    (* 闭包调用（v3.7）：call code(env=堆块, args)。
       string/seq/struct 形参按 zfy 约定由被调方接管（末尾 free）——
       调用点先深拷贝落临时槽再传（实参本身若是语句临时则 move 接管） *)
    let oc = lexpr l cb in
    let oargs =
      List.map
        (fun (a : texpr) ->
          match a.ety with
          | TString | TList _ | TArray _ | TStruct _ | TErr _ ->
            let tmp = fresh l in
            emit l (MAlloca (tmp, a.ety));
            let va = lexpr l a in
            if not (move_owned_temp l tmp va a.ety) then
              emit l (MCopy (tmp, va, a.ety));
            op (OLocal tmp) a.ety
          | _ -> lexpr l a)
        args
    in
    let d = if e.ety = TVoid then None else Some (fresh l) in
    emit l (MClCall (d, oc, oargs, e.ety));
    (match d with
     | Some d' -> op (OLocal d') e.ety
     | None -> op (OInt 0L) TVoid)
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
    (* panic：调用运行时后不返回；后继代码落入死块（死代码消除删除）。
       P0-4c：panic 路径 RAII 回卷——先释放本函数局部资源、回卷锁栈，
       再调 zfy_panic（try 帧栈恢复后不留悬垂句柄/死锁） *)
    let oc = Option.map (lexpr l) code in
    let om = lexpr l msg in
    finish_stmt_temps l;
    emit_frees_from l 0;
    emit_unlocks l;
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
    (* find(s, x, k)：运行时查找，产 TErr i64（sret）。
       x 为 char 查字符、string 查子串（w-020 补子串形态） *)
    let os = lexpr l s and oc = lexpr l c and ok = lexpr l k in
    let d = fresh l in
    let fn = (match oc.oty with TChar -> "zfy_err_find" | _ -> "zfy_err_find_str") in
    emit l (MCall (Some d, fn, [ os; oc; ok ], e.ety));
    op (OLocal d) e.ety
  | ESortSeqK (src, elem, desc) ->
    (* sort(seq, max|min)（new.md 第3条）：克隆源列表后原地排序
       （长度 <2 运行期 die，克隆在运行时完成——mir 的 MCopy 临时会被
       拷贝传播消除，不能用作防原地排序的副本）；desc=true 从大到小。
       结果恒为新列表，源序列不变（值语义） *)
    let osrc = lexpr l src in
    let d = fresh l in
    emit l (MCall (Some d, "zfy_sort_chk_" ^ sort_tag elem,
                   [ osrc;
                     op (OInt (if desc then 1L else 0L)) (TInt 32) ],
                   TList elem));
    add_temp l d (FSeq (elem = TString));
    op (OLocal d) e.ety
  | ESortMixK (args, elem, desc) ->
    (* sort(e1..en, max|min) 混合展平：新列表逐实参追加（标量经键转换：
       string/char 按 ascii 码、bool 按 0/1；序列运行时逐元素转换），
       再整体排序。elem 限 TInt 64 / TFloat 64 *)
    let dkind = (match elem with TFloat 64 -> 1 | _ -> 0) in
    let acc = fresh l in
    emit l (MEmptySeq (acc, TList elem));
    List.iter
      (fun (a : texpr) ->
        match resolve a.ety with
        | TList _ | TArray _ ->
          let os = lexpr l a in
          let sk = seq_key_kind (resolve a.ety) in
          emit l (MCall (None, "zfy_seq_extend_num",
                         [ op (OLocal acc) (TList elem); os;
                           op (OInt (Int64.of_int sk)) (TInt 32);
                           op (OInt (Int64.of_int dkind)) (TInt 32) ],
                         TVoid))
        | t ->
          let ov = lexpr l a in
          let (push_fn, keyop) =
            match t, elem with
            | TString, _ ->
              let d = fresh l in
              emit l (MCall (Some d, "zfy_str_code", [ ov ], TInt 64));
              ("zfy_sort_push_i", op (OLocal d) (TInt 64))
            | TFloat _, _ ->
              (* 统一转 f64 键（f32 扩展） *)
              let c = fresh l in
              emit l (MCast (c, ov, TFloat 64));
              ("zfy_sort_push_d", op (OLocal c) (TFloat 64))
            | _, TFloat 64 ->
              (* 整数/bool/char 键转 f64（u64 位型大值有精度损失，接受） *)
              let c = fresh l in
              emit l (MCast (c, ov, TFloat 64));
              ("zfy_sort_push_d", op (OLocal c) (TFloat 64))
            | _ ->
              (* 整数/bool/char → i64 键（gen_cast：zext/sext/bitcast） *)
              let c = fresh l in
              emit l (MCast (c, ov, TInt 64));
              ("zfy_sort_push_i", op (OLocal c) (TInt 64))
          in
          emit l (MCall (None, push_fn, [ op (OLocal acc) (TList elem); keyop ], TVoid)))
      args;
    let d = fresh l in
    emit l (MCall (Some d, "zfy_sort_chk_" ^ sort_tag elem,
                   [ op (OLocal acc) (TList elem);
                     op (OInt (if desc then 1L else 0L)) (TInt 32) ],
                   TList elem));
    (* sort_chk 内部克隆：展平用临时列表就地释放 *)
    emit l (MCall (None, "zfy_seq_free", [ op (OLocal acc) (TList elem) ], TVoid));
    add_temp l d (FSeq false);
    op (OLocal d) e.ety

(* 可写 seq 槽地址（w-014 #3）：非变量槽根（字段链/解引用/元素槽）
   统一产出一个"持有 seq 指针的槽地址"寄存器操作数。
   EVarK 不走此函数（MSeqSet 直写槽名的快速路径） *)
and seq_slot_addr l (root : texpr) (elem : zty) : operand =
  match root.e with
  | EFieldK _ ->
    let rec flatten acc b =
      match b.e with
      | EFieldK (b', i) -> flatten (i :: acc) b'
      | EVarK n -> Some (n, acc, b.ety)
      (* deref(env).f（t-049 捕获下标写/push）：根槽持有指针，rootty 标
         TPtr 由 llvmgen MFieldAddr load 后 GEP（自动解引用字段定位） *)
      | EDerefK ({ e = EVarK n; ety = TPtr t; _ }) -> Some (n, acc, TPtr t)
      | _ -> None
    in
    (match flatten [] root with
     | Some (n, idxs, rootty) ->
       let d = fresh l in
       emit l (MFieldAddr (d, op (OLocal n) rootty, rootty, idxs, TList elem));
       op (OLocal d) (TList elem)
     | None -> merr root.epos "unsupported field slot target")
  | EDerefK p -> lexpr l p
  | EAddrOfK { e = ESeqGetK (b, i); _ } ->
    (* 元素槽地址（嵌套 seq 写）：带边界检查定位外层元素槽。
       定位的元素类型 = 基的元素类型（行/子列表，宽度 8），非最内层元素 *)
    let et = (match b.ety with
              | TList t | TArray (t, _) -> t
              | _ -> merr root.epos "element slot base is not a seq") in
    let d = fresh l in
    emit l (MElemAddr (d, lexpr l b, lexpr l i, et, true));
    op (OLocal d) et
  | _ -> merr root.epos "unsupported seq slot target"

(* ---------- 语句降码 ---------- *)

let rec lblock l (stmts : tblock) : unit =
  List.iter (lstmt l) stmts

and lstmt l (s : tstmt) : unit =
  emit l (MSetLoc (s.spos.file, s.spos.line));
  l.stmt_temps <- [];
  lstmt_inner l s;
  finish_stmt_temps l

and lstmt_inner l (s : tstmt) : unit =
  match s.s with
  | SDeclK (_, name, ty, init, nn) ->
    (* 标量声明：变量永远有值，必有初值；非 unred frac 存入后约分。
       初值是本语句的 seq/struct/闭包临时（如 split 结果、构造调用）时
       直接 move 所有权免克隆。File/句柄/接口/闭包（move-only，P0-1）：
       初值为局部变量槽时为所有权转移（清空源槽，运行期失效兜底） *)
    declare_owned l name ty;
    (* t-049/C：& 捕获堆箱槽在声明点分配 rc 堆箱（逐轮配平释放，见 MBoxAlloc 注释） *)
    if Hashtbl.mem l.boxed name then emit l (MBoxAlloc (name, ty));
    let v = lexpr l init in
    let moved =
      match ty, v.o with
      | (TFile | TStruct _), OLocal src when src.[0] <> '%' && src.[0] <> '@'
        && move_only_ty ty ->
        (* 所有权转移：位拷贝接管（rc 引用计数不动）+ 清空源槽——
           用 MCopy（assign retain）会 +1 而源槽 MClear 裸 null 不减，泄漏 *)
        emit l (MMoveSeq (name, v, ty));
        emit l (MClear (src, ty));
        true
      | _ ->
        (match ty with
         | TString | TArray _ | TList _ | TStruct _ ->
           move_owned_temp l name v ty
         | _ -> false)
    in
    if not moved then begin
      emit l (MCopy (name, v, ty));
      if nn then emit l (MNorm (name, ty))
    end
  | SSeqDeclK (_, name, elem, len, is_list, inits, enn) ->
    (* 数组/列表：先分配（未初始化槽位为全零位模式），再逐个写入初始元素。
       frac 元素（enn）：初值与后续存入均自动约分；unred 数组不归一 *)
    let ty = if is_list then TList elem else TArray (elem, Int64.to_int len) in
    declare_owned l name ty;
    (* t-049/C：& 捕获堆箱槽在声明点分配 rc 堆箱（逐轮配平释放） *)
    if Hashtbl.mem l.boxed name then emit l (MBoxAlloc (name, ty));
    (match elem with
     | TFrac _ when not enn -> Hashtbl.replace l.unreds name true
     | _ -> ());
    emit l (MSeqAlloc (name, elem, len, is_list));
    List.iteri
      (fun i t ->
        let v = lexpr l t in
        let v = if enn then norm_frac_val l v elem else v in
        emit l (MSeqSet (name, elem, op (OInt (Int64.of_int i)) (TInt 64),
                         v, is_list, false)))
      inits
  | SSeqCopyK (_, name, elem, len, src, is_list) ->
    (* 数组/列表整体初值：目标槽位无需预分配（初值直接覆盖，
       旧值释放语义不变）；若初值是本语句的 seq 临时（如切片结果）
       则直接 move 所有权，免去克隆 *)
    let tgt = if is_list then TList elem else TArray (elem, Int64.to_int len) in
    declare_owned l name tgt;
    (* t-049/C：& 捕获堆箱槽在声明点分配 rc 堆箱（逐轮配平释放） *)
    if Hashtbl.mem l.boxed name then emit l (MBoxAlloc (name, tgt));
    let v = lexpr l src in
    if not (move_owned_temp l name v tgt) then
      emit l (MCopy (name, v, tgt))
  | SStrAppendK (name, parts) ->
    (* string 原地追加（T7 优化）：各操作数求值为临时后逐个并入槽串。
       槽指针所有权保留（不 free），realloc 可能移动缓冲区——typeck
       保证操作数不引用槽本身 *)
    let ops = List.map (lexpr l) parts in
    emit l (MStrAppend (name, ops))
  | SAssignK (lhs, rhs, nn, mov) ->
    (* v3 2026-10-11：xs = push(xs, v) / bag.xs = push(bag.xs, v)——赋值
       目标与 push 槽根同槽时原地追加即可，零拷贝（push 本就原地写槽根）；
       异槽走通用路径（MCopy/MFieldStore 深拷贝，语义正确） *)
    (match rhs.e with
     | EPushK (base, _) when same_seq_root lhs base ->
       ignore (lexpr l rhs)
     | _ ->
    let v = lexpr l rhs in
    (match lhs.e with
     | EVarK name ->
       if mov then begin
         (* move 赋值（new2.md #1：自动 move/显式 move）：源为变量槽时
            所有权直接转移（释放目标旧值 + 接管指针），随后清空源槽防双释放 *)
         (match lhs.ety, v.o with
          | ((TString | TArray _ | TList _ | TFile | TStruct _) as ty), OLocal src ->
            emit l (MMoveSeq (name, v, ty));
            emit l (MClear (src, ty))
          | _ -> merr lhs.epos "move assignment requires an aggregate variable source")
       end
       else if move_only_ty lhs.ety then begin
         (* move-only 类型（File/句柄/接口/闭包，P0-1）：变量到变量赋值 =
            所有权转移（typeck 已标记源变量 moved）；目标旧句柄自动释放 *)
         (match v.o with
          | OLocal src when src.[0] <> '%' && src.[0] <> '@' ->
            emit l (MMoveSeq (name, v, lhs.ety));
            emit l (MClear (src, lhs.ety))
          | _ ->
            if not (move_owned_temp l name v lhs.ety) then
              emit l (MCopy (name, v, lhs.ety)))
       end
       else begin
         (* 聚合整体赋值：值为本语句临时（切片/split/调用结果等）时 move 免克隆 *)
         let moved =
           match lhs.ety with
           | TString | TArray _ | TList _ | TStruct _ ->
             move_owned_temp l name v lhs.ety
           | _ -> false
         in
         if not moved then begin
           emit l (MCopy (name, v, lhs.ety));
           if nn then emit l (MNorm (name, lhs.ety))
         end
       end
     | EFieldK _ ->
       (* 字段链整体赋值（bag.xs = ...，w-14 #3）：GEP 定位字段 +
          深拷贝写入（值语义，旧字段资源由 MFieldStore 释放）。
          字面量临时不 move（深拷贝进字段，临时语句末释放） *)
       let rec flatten acc b =
         match b.e with
         | EFieldK (b', i) -> flatten (i :: acc) b'
         | EVarK n -> Some (n, acc, b.ety)
         (* deref(env).f（t-049 捕获赋值）：根槽 = "$env" 指针槽，
            rootty 标 TPtr 由 MFieldStore 自动解引用定位字段 *)
         | EDerefK ({ e = EVarK n; ety = TPtr t; _ }) -> Some (n, acc, TPtr t)
         | _ -> None
       in
       (match flatten [] lhs with
        | Some (rootn, idxs, rootty) ->
          emit l (MFieldStore (op (OLocal rootn) rootty, rootty, idxs, v));
          (* 非 unred frac 捕获字段赋值后自动约分（t-049/B）：MNorm 限变量
             槽，这里 GEP 字段地址后直接调用 zfy_frac_norm_<suf> *)
          (match lhs.ety with
           | TFrac e when nn ->
             let ap = fresh l in
             emit l (MFieldAddr (ap, op (OLocal rootn) rootty, rootty, idxs,
                                 lhs.ety));
             emit l (MCall (None, "zfy_frac_norm_" ^ Hir.suffix_of e,
                           [ op (OLocal ap) (TPtr lhs.ety) ], TVoid))
           | _ -> ())
        | None -> merr lhs.epos "unsupported field assignment target")
     | _ -> merr lhs.epos "unsupported assignment target"))
  | SAugIndexK (root, (TErr _ as elem), idx, bop, v, grow) ->
    (* T! 元素复合赋值（new.md 第1条）：下标只求值一次。语义——
       错误元素保持错误原样写回；成功元素取值参与运算后重新包装写回。
       string 元素 += 走 zfy_str_concat（同非 T! 路径） *)
    let inner = (match elem with TErr t -> t | _ -> assert false) in
    let oi = lexpr l idx in
    let (seqop, addr) =
      match root.e with
      | EVarK name -> (op (OLocal name) (TList elem), None)
      | _ ->
        let a = seq_slot_addr l root elem in
        let sp = fresh l in
        emit l (MLoadSeq (sp, a));
        (op (OLocal sp) (TList elem), Some a)
    in
    let old = fresh l in
    emit l (MSeqGet (old, seqop, oi, elem, l.unchecked));
    let ov = lexpr l v in
    let okr = fresh l in
    emit l (MErrIsOk (okr, op (OLocal old) elem, elem));
    let writeback vv =
      match addr with
      | None ->
        (match root.e with
         | EVarK name ->
           emit l (MSeqSet (name, elem, oi, vv, grow, l.unchecked))
         | _ -> assert false)
      | Some a ->
        emit l (MSeqSetAt (a, elem, oi, vv, grow, l.unchecked))
    in
    let bok = new_block l and berr = new_block l and bend = new_block l in
    set_term l (TCondBr (op (OLocal okr) TBool, bok.bid, berr.bid));
    (* 成功路径：取值 → 运算 → 包装 → 写回 *)
    l.cur <- bok;
    let dv = fresh l in
    emit l (MErrValue (dv, op (OLocal old) elem, elem));
    let r = fresh l in
    if inner = TString then begin
      if bop <> BAdd then merr root.epos "string elements only support +=";
      emit l (MCall (Some r, "zfy_str_concat",
                     [ op (OLocal dv) inner; ov ], inner))
    end else
      emit l (MBinop (r, bop, op (OLocal dv) inner, ov));
    let na = fresh l in
    emit l (MErrOk (na, elem, op (OLocal r) inner));
    writeback (op (OLocal na) elem);
    set_term l (TBr bend.bid);
    (* 错误路径：保持错误，原样写回 *)
    l.cur <- berr;
    writeback (op (OLocal old) elem);
    set_term l (TBr bend.bid);
    l.cur <- bend
  | SAugIndexK (root, elem, idx, bop, v, grow) ->
    (* a[i] op= v：下标只求值一次（load + op + store 同一槽位）。
       槽根分派（w-014 #3）：变量槽直写；其余经槽地址 *)
    let oi = lexpr l idx in
    let (seqop, addr) =
      match root.e with
      | EVarK name -> (op (OLocal name) (TList elem), None)
      | _ ->
        let a = seq_slot_addr l root elem in
        let sp = fresh l in
        emit l (MLoadSeq (sp, a));
        (op (OLocal sp) (TList elem), Some a)
    in
    let old = fresh l in
    emit l (MSeqGet (old, seqop, oi, elem, l.unchecked));
    let ov = lexpr l v in
    let r = fresh l in
    if elem = TString && bop = BAdd then
      (* string 元素 +=（w-020）：old 是槽内堆串指针本身（zfy_seq_get
         位拷贝语义，不 strdup）——必须 concat 产新串写回（写回路径释放
         旧串），不可用 zfy_str_append 原地 realloc（会使槽内指针悬空） *)
      emit l (MCall (Some r, "zfy_str_concat", [ op (OLocal old) elem; ov ], TString))
    else
      emit l (MBinop (r, bop, op (OLocal old) elem, ov));
    (match addr with
     | None ->
       (match root.e with
        | EVarK name ->
          emit l (MSeqSet (name, elem, oi, op (OLocal r) elem, grow, l.unchecked))
        | _ -> assert false)
     | Some a ->
       emit l (MSeqSetAt (a, elem, oi, op (OLocal r) elem, grow, l.unchecked)))
  | SAugVarK (name, (TErr _ as ty), bop, v, _) ->
    (* T! 变量复合赋值（new.md 第1条）：成功取值运算后包装写回；
       错误值保持不变（不消耗错误） *)
    let inner = (match ty with TErr t -> t | _ -> assert false) in
    let ov = lexpr l v in
    let okr = fresh l in
    emit l (MErrIsOk (okr, op (OLocal name) ty, ty));
    let bok = new_block l and bend = new_block l in
    set_term l (TCondBr (op (OLocal okr) TBool, bok.bid, bend.bid));
    l.cur <- bok;
    let dv = fresh l in
    emit l (MErrValue (dv, op (OLocal name) ty, ty));
    let r = fresh l in
    if inner = TString then begin
      if bop <> BAdd then merr s.spos "string values only support +=";
      emit l (MCall (Some r, "zfy_str_concat",
                     [ op (OLocal dv) inner; ov ], inner))
    end else
      emit l (MBinop (r, bop, op (OLocal dv) inner, ov));
    let na = fresh l in
    emit l (MErrOk (na, ty, op (OLocal r) inner));
    emit l (MCopy (name, op (OLocal na) ty, ty));
    set_term l (TBr bend.bid);
    l.cur <- bend
  | SAugVarK (name, ty, bop, v, nn) ->
    (* x op= v：load + op + store 同一槽位；frac 槽走运行时分数四则
       （sret，聚合不可直接 MBinop） *)
    let ov = lexpr l v in
    (match ty with
     | TFrac elem ->
       let d = fresh l in
       emit l (MCall (Some d, frac_rt_name bop elem,
                      [ op (OLocal name) ty; ov ], ty));
       emit l (MCopy (name, op (OLocal d) ty, ty));
       if nn then emit l (MNorm (name, ty))
     | _ ->
       let r = fresh l in
       emit l (MBinop (r, bop, op (OLocal name) ty, ov));
       emit l (MCopy (name, op (OLocal r) ty, ty));
       if nn then emit l (MNorm (name, ty)))
  | SSeqSetK (root, elem, idx, v, grow) ->
    (* 元素写入：元素类型决定写入宽度；grow 允许列表扩长。
       槽根分派（w-014 #3）：变量槽直写；字段链/ref 解引用/元素槽经槽地址。
       frac 元素存入自动约分（unred 数组豁免，new.md 2026-10-10） *)
    let v = lexpr l v in
    let v =
      match elem, root.e with
      | TFrac _, EVarK name when Hashtbl.find_opt l.unreds name = Some true -> v
      | TFrac _, _ -> norm_frac_val l v elem
      | _ -> v
    in
    (match root.e with
     | EVarK name ->
       emit l (MSeqSet (name, elem, lexpr l idx, v, grow, l.unchecked))
     | _ ->
       let addr = seq_slot_addr l root elem in
       emit l (MSeqSetAt (addr, elem, lexpr l idx, v, grow, l.unchecked)))
  | SStrSetK (root, idx, v) ->
    (* string 下标写（w-014 #5）：槽内堆串原地写（槽独占由 MCopy strdup
       保证），越界运行时报错。变量槽 load 串指针；字段/ref 路径
       load 出串指针后同写 *)
    let sp =
      match root.e with
      | EVarK n -> op (OLocal n) root.ety
      | EFieldK _ | EDerefK _ -> lexpr l root
      | _ -> merr root.epos "unsupported string index-assignment target"
    in
    let oi = lexpr l idx and ov = lexpr l v in
    emit l (MCall (None, "zfy_str_set", [ sp; oi; ov ], TVoid))
  | SAugSliceK (name, elem, a, b, st, bop, v) ->
    (* a[x,y:st] op= v：运行时逐元素原地运算 *)
    emit l (MAugSlice (name, elem, lexpr l a, lexpr l b, lexpr l st, bop,
                       lexpr l v))
  | SFieldSetK (root, idxs, rootty, v) ->
    (* 字段写入：根地址（变量槽/元素槽地址/解引用/捕获字段链）定位一次 +
       GEP 链，深拷贝新值 + 释放旧值（llvmgen 按字段类型分派）。
       v3 2026-10-11：bag.items = push(bag.items, x) 同槽特判——push 本就
       原地写该字段，跳过整体深拷贝（MFieldStore 先释放旧值会让 push
       写入的 seq 变悬垂） *)
    let same_field_root =
      match v.e with
      | EPushK (base, _) ->
        (match seq_root_key_opt base, seq_root_key_opt root with
         | Some (n, il), Some (n', []) -> n = n' && il = idxs
         | _ -> false)
      | _ -> false
    in
    if same_field_root then
      ignore (lexpr l v)
    else
      begin match root.e with
      | EFieldK _ ->
        (* 捕获字段链根（t-049/B）：根 = env 块字段（deref($env).p），
           展平出根指针与前置序号链，并入 idxs 一次 GEP 直达最终字段
           （值捕获副本 = env 块内独立存储，字段写只改副本，外层不变） *)
        let (rr, pre, rrootty) = flatten_field_root l root in
        emit l (MFieldStore (rr, rrootty, pre @ idxs, lexpr l v))
      | _ ->
        let rp =
          match root.e with
          | EVarK n -> op (OLocal n) root.ety
          | EAddrOfK { e = ESeqGetK (b, i); _ } ->
            let d = fresh l in
            let ety = (match root.ety with TPtr t -> t | _ -> assert false) in
            emit l (MElemAddr (d, lexpr l b, lexpr l i, ety, true));
            op (OLocal d) ety
          | EDerefK p -> lexpr l p
          | _ -> merr root.epos "unsupported field-set root"
        in
        emit l (MFieldStore (rp, root.ety, idxs, lexpr l v))
      end
  | SAugFieldK (root, idxs, rootty, bop, v) ->
    (* 字段增广：load 字段 + op + 写回（字段只求值一次；字段类型 = 右值类型）。
       根 = 变量槽（EVarK，lslot 名）或捕获字段链（EFieldK，t-049/B——
       展平出 env 根指针与前置序号链，读写链均穿透 env 解引用） *)
    let fty = v.ety in
    let (rp, base_ty, pre) =
      match root.e with
      | EVarK n -> (op (OLocal n) rootty, rootty, [])
      | EFieldK _ ->
        let (rr, pre, rrootty) = flatten_field_root l root in
        (rr, rrootty, pre)
      | EDerefK p ->
        let pv = lexpr l p in
        (pv, (match p.ety with TPtr t -> t | _ -> p.ety), [])
      | _ -> merr (match root with { epos = ep; _ } -> ep)
               "unsupported augmented-field root"
    in
    let old = fresh l in
    emit l (MFieldGet (old, rp, base_ty, pre @ idxs, fty));
    let ov = lexpr l v in
    let r = fresh l in
    emit l (MBinop (r, bop, op (OLocal old) fty, ov));
    emit l (MFieldStore (rp, base_ty, pre @ idxs, op (OLocal r) fty))
  | SDerefSetK (p, v) ->
    (* 指针解引用写入 p* = v：地址先求值。
       标量/指针目标：直接 store 值。
       聚合目标（string/数组/列表，ref 参数整体赋值，w-014 #3）：
       新值落入临时槽（右值为本语句临时则 move 接管）→ 释放旧值 →
       store 新指针（引用槽整体替换） *)
    let pv = lexpr l p in
    (match v.ety with
     | TString | TList _ | TArray _ ->
       let tmp = fresh l in
       emit l (MAlloca (tmp, v.ety));
       let vv = lexpr l v in
       if not (move_owned_temp l tmp vv v.ety) then
         emit l (MCopy (tmp, vv, v.ety));
       let old = fresh l in
       emit l (MLoadK (old, pv, v.ety));
       emit l (MFreeVal (op (OLocal old) v.ety, v.ety));
       emit l (MStoreK (pv, v.ety, op (OLocal tmp) v.ety))
     | _ ->
       let vv = lexpr l v in
       emit l (MStoreK (pv, v.ety, vv)))
  | SAugDerefK (p, bop, v) ->
    (* 指针解引用复合赋值 p* op= v：load 旧值 + op + store（p 只求值一次） *)
    let pv = lexpr l p in
    let old = fresh l in
    emit l (MLoadK (old, pv, v.ety));
    let ov = lexpr l v in
    let r = fresh l in
    emit l (MBinop (r, bop, op (OLocal old) v.ety, ov));
    emit l (MStoreK (pv, v.ety, op (OLocal r) v.ety))
  | SAsmK (tmpl, outs, ins, clob) ->
    (* 内联汇编（v3.31）：in 实参求值后发 MAsm；out 按槽写回由 llvmgen 完成 *)
    let oins = List.map (fun (x, _) -> lexpr l x) ins in
    emit l (MAsm (tmpl, outs, oins, clob))
  | SUnsafeK b ->
    (* unsafe 块：门禁在 typeck 已检查；块内关闭下标越界检查（@unchecked） *)
    let saved = l.unchecked in
    l.unchecked <- true;
    lblock l b;
    l.unchecked <- saved
  | SBlockK b ->
    (* 透明块（v3.6 for-in 降码承载）：平铺，无独立作用域 *)
    lblock l b
  | SLockK (m, blk) ->
    (* lock 块（v3.26 P0-3）：入口加锁 + 块体 + 正常路径解锁。
       提前跳转（return/break/continue）由各自降码点的 emit_unlocks 回卷；
       panic 直接终止进程（OS 回收锁），try 恢复路径待 P0-4 帧栈回卷 *)
    let mo = lexpr l m in
    emit l (MCall (None, "zfy_mutex_lock", [ mo ], TVoid));
    l.locks <- mo :: l.locks;
    lblock l blk;
    if l.cur.term = None then begin
      emit l (MCall (None, "zfy_mutex_unlock", [ mo ], TVoid));
      l.locks <- List.tl l.locks
    end
    (* term 已设（块内 return/break/continue）：锁由跳转点回卷，栈保持 *)
  | SExprK e ->
    (* 语句级 fail(code, msg)（w-009）：构造错误值后按 ? 失败路径终止
       函数（RAII 释放局部资源 + 错误值 memcpy 到 sret 返回槽 + ret
       void），后继语句为死块。原实现把错误值当普通表达式丢弃后继续
       执行（return 10/b 除零/垃圾值）；fail 返回 TErr 说明函数本身
       返回 T!，MErrFillOut 合法 *)
    (match e.e with
     | EFailK _ ->
       (match e.ety with
        | TErr _ ->
          let va = lexpr l e in
          emit_frees_from l 0;
          emit l (MErrFillOut (va, e.ety));
          set_term l (TRet None);
          l.cur <- new_block l
        | _ -> ignore (lexpr l e))
     | _ -> ignore (lexpr l e))
  | SReturnK e ->
    (* 先求返回值，再释放全部局部资源（RAII）；
       若返回值本身就�?owned 局部变量，跳过其释放（所有权随返回转移）�?       本语句的临时串所有权同样随返回转移，不再释放 *)
    let v = Option.map (lexpr l) e in
    (* 字段链/嵌套表达式读出的 owned 值（% 临时寄存器）不拥有资源所有权——
       返回前深拷贝到独立临时槽（string strdup / seq clone），随后局部
       RAII 释放不影响返回值（v3.35 修复：return x.a 返回悬垂指针，
       mk 作用域 free x 后调用方持有已释放堆串 → 堆损坏）。变量槽返回
       （OLocal 非 % 前缀）保持既有所有权转移语义不动 *)
    let v = Option.map
        (fun (vo : operand) ->
          match vo.o, vo.oty with
          | OLocal n, (TString | TArray _ | TList _) when n.[0] = '%' ->
            let tmp = fresh l in
            emit l (MTempAlloca (tmp, vo.oty));
            emit l (MCopy (tmp, vo, vo.oty));
            { vo with o = OLocal tmp }
          | _ -> vo)
        v
    in
    (* 非 unred frac 返回前原地约分（w-017）：四则运算的运行时结果不经归一，
       声明/赋值存槽路径有 MNorm 兜底，return 路径此前缺失（产出 8/16 形态）。
       返回类型不支持 unred 修饰，凡直接返回 frac 一律约分；
       全局常量（OGlobal）与 TErr 聚合不在其列 *)
    (match v with
     | Some ({ o = OLocal n; oty = TFrac _; _ } as vo) when not l.frunred ->
       emit l (MNorm (n, vo.oty))
     | _ -> ());
    l.stmt_temps <- [];
    let skip =
      match v with
      | Some { o = OLocal n; _ } -> [ n ]
      | _ -> []
    in
    emit_frees_from_skip l 0 skip;
    emit_unlocks l;
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
    let locks_depth = List.length l.locks in
    l.loops <- (bend.bid, bcond.bid, body_depth, locks_depth) :: l.loops;
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
    let locks_depth = List.length l.locks in
    (* 循环上下文：break -> bend；continue -> bupd（continue/break 前
       需先释放 body 层，bupd/bend 都在 body 作用域之外） *)
    l.loops <- (bend.bid, bupd.bid, body_depth, locks_depth) :: l.loops;
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
    (* 逐参数输出：sep 只出现在相邻参数之间，最后输出 end。
       数组/列表参数整体按元素打印（w-013），元素间同样以 sep 分隔
       （与 output(a[0], a[1], ...) 展开语义一致） *)
    let sep_op = lexpr l sep in
    List.iteri
      (fun i a ->
        if i > 0 then emit l (MPrintVal sep_op);
        let oa = lexpr l a in
        (match a.ety with
         | TArray _ | TList _ ->
           (match seq_depth a.ety with
            | 1 -> emit l (MPrintSeq (oa, elem_kind_of a.ety, sep_op))
            | d -> emit l (MPrintSeqNest (oa, d, leaf_kind_of a.ety, sep_op)))
         | _ -> emit l (MPrintVal oa)))
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
     | (bk, _, body_depth, locks_depth) :: _ ->
       (* 跳出前释放循环体内层作用域的全部资源；穿越的 lock 块逆序解锁
          （只回卷到循环入口深度——外层 lock 块仍持有，不得误放） *)
       emit_frees_from l body_depth;
       emit_unlocks_to l locks_depth;
       set_term l (TBr bk);
       l.cur <- new_block l            (* 后续死代码放入孤立块 *)
     | [] -> merr s.spos "break outside a loop")
  | SContinueK ->
    (match l.loops with
     | (_, ck, body_depth, locks_depth) :: _ ->
       emit_frees_from l body_depth;
       emit_unlocks_to l locks_depth;
       set_term l (TBr ck);
       l.cur <- new_block l
     | [] -> merr s.spos "continue outside a loop")
  | SUnwrapBlockK (is_decl, is_ret, slot, elem, a, errslot, blk) ->
    (* a ?? 缩进块：a 成功 → value 写入目标槽；失败 → code/msg 拷入 err 槽，
       执行块（块内可用 err，块末表达式已由 typeck 改写为对目标槽的赋值），
       两路在结尾汇合。
       return 形式（is_ret）：成功路径直接返回 a 的成功聚合（TErr 值，
       与 SReturnK 同款 RAII 处理）；失败路径执行块——块末已由 typeck
       改写为 SReturnK，两路均在块内离开，bend 为死块 *)
    if is_decl then begin
      declare_owned l slot elem
    end;
    let va = lexpr l a in
    if is_ret then begin
      let okr = fresh l in
      emit l (MErrIsOk (okr, va, a.ety));
      let bok = new_block l and berr = new_block l and bend = new_block l in
      set_term l (TCondBr (op (OLocal okr) TBool, bok.bid, berr.bid));
      (* 成功路径：返回成功聚合（所有权随返回转移，跳过其释放） *)
      l.cur <- bok;
      l.stmt_temps <- [];
      let skip = (match va.o with OLocal n -> [ n ] | _ -> []) in
      emit_frees_from_skip l 0 skip;
      set_term l (TRet (Some va));
      (* 失败路径：填 err 槽后执行块（块末为 SReturnK） *)
      l.cur <- berr;
      emit l (MErrFillErr (errslot, va, a.ety));
      l.scopes <- ref [] :: l.scopes;
      let outer = List.length (List.tl l.scopes) in
      lblock l blk;
      emit_frees_from l outer;
      set_term l (TBr bend.bid);
      l.scopes <- List.tl l.scopes;
      l.cur <- bend
    end
    else begin
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
    end

(* ---------- 函数降码 ---------- *)

let rec collect_lets acc (stmts : tblock) =
  List.iter
    (fun (s : tstmt) ->
      match s.s with
      | SDeclK (_, n, t, _, _) ->
        if n.[0] <> '@' then acc := (n, t) :: !acc
      | SSeqDeclK (_, n, elem, len, is_list, _, _) ->
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
      | SUnwrapBlockK (is_decl, _, slot, elem, _, errslot, blk) ->
        (* 解包块：目标槽（声明时）与 err 槽（Err struct）都需要入口 alloca；
           err 槽不登记 RAII（msg 有意泄漏，且槽可复用）。
           return 形式成功路径不写槽，目标槽无需 alloca *)
        if is_decl && slot.[0] <> '@' then acc := (slot, elem) :: !acc;
        acc := (errslot, TStruct "Err") :: !acc;
        collect_lets acc blk
      | SWhileK (_, b) -> collect_lets acc b
      | SBlockK b -> collect_lets acc b
      | SUnsafeK b -> collect_lets acc b
      | SLockK (_, b) -> collect_lets acc b
      | SForK (inits, _, _, b) ->
        List.iter
          (fun (s : tstmt) ->
            match s.s with
            | SDeclK (_, n, t, _, _) ->
              if n.[0] <> '@' then acc := (n, t) :: !acc
            | SSeqDeclK (_, n, elem, len, is_list, _, _) ->
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
      loops = []; scopes = []; stmt_temps = []; unchecked = false;
      frunred = f.frunred; locks = []; clo_envs = []; unreds = Hashtbl.create 8;
      (* t-049/C：& 捕获堆箱槽表（槽名 -> zbox 布局名），按函数名从 typeck
         读取（与 llvmgen 同源——mname 即 f.fname）；declare_owned 据此把
         堆箱槽强制纳入 RAII，作用域退出配平 rc release *)
      boxed = (match Hashtbl.find_opt Typeck.boxed_fns f.fname with
               | Some t -> t | None -> Hashtbl.create 0) }
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
     在入口 clone（一律拷贝语义，gen_fn 落槽），参数槽登记为 owned 以便函数退出时释放。
     P0-1：句柄/接口/闭包参数 = 借用（调用方持有并释放；被调方只读使用，
     不登记 owned——否则被调方退出会释放调用方的资源） *)
  l.scopes <- ref [] :: l.scopes;
  List.iter
    (fun (_, n, t, u) ->
      if not (move_only_ty t) then declare_owned l n t;
      (* 非 unred frac 参数入口归一（new.md：传参也要自动约分）。
         参数在 llvmgen 入口已值拷贝（memcpy 语义），此处原地归一
         只影响本函数的参数副本，调用方源槽不变 *)
      (match t with
       | TFrac _ when not u -> emit l (MNorm (n, t))
       | _ -> ()))
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
    mparams = List.map (fun (_, n, t, _) -> (n, t)) f.fparams;
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
  | MStrAppend (name, ops) ->
    (* 槽名计为 use：名字后续仍被读时本语句不可删（同时是 def） *)
    name :: List.concat_map operand_names ops
  | MMoveSeq (_, v, _) -> operand_names v
  | MClear _ -> []
  | MFreeClo _ -> []   (* 槽释放：def 而非 use（槽随后清空） *)
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
    (match c with
     | Some c -> operand_names c @ operand_names m
     | None -> operand_names m)
  | MSetLoc _ -> []
  | MAlloca _ -> []
  | MBoxAlloc _ -> []
  | MFracNew (_, _, a, b) -> operand_names a @ operand_names b
  | MFracCast (_, a, _) -> operand_names a
  | MNorm _ -> []
  | MTempAlloca _ -> []
  | MSeqRemove (_, s, idx, _, _) -> operand_names s @ operand_names idx
  | MAugSlice (_, _, a, b, st, _, v) ->
    operand_names a @ operand_names b @ operand_names st @ operand_names v
  | MReduce (r, _, a, b) -> r :: operand_names a @ operand_names b
  | MPrintStr _ -> []
  | MPrintVal o -> operand_names o
  | MPrintSeq (o, _, sep) -> operand_names o @ operand_names sep
  | MPrintSeqNest (o, _, _, sep) -> operand_names o @ operand_names sep
  | MInput (_, _, d) -> operand_names d
  | MSeqAlloc _ -> []
  | MSeqSet (name, _, idx, v, _, _) ->
    (* name 亦为 use：字段链下数组写经 MFieldAddr 临时
       指针 %tN 作为 seq 来源，须保持其纯指令不被死代码消除 *)
    name :: operand_names idx @ operand_names v
  | MSeqSetAt (slot, _, idx, v, _, _) ->
    operand_names slot @ operand_names idx @ operand_names v
  | MLoadSeq (_, a) -> operand_names a
  | MSeqLit (_, _, vs) -> List.concat_map operand_names vs
  | MFreeVal (o, _) -> operand_names o
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
  | MElemAddr (_, base, idx, _, _) -> operand_names base @ operand_names idx
  | MIndirectCall (_, f, args, _) ->
    operand_names f @ List.concat_map operand_names args
  | MClNew (_, _, _, items, _) ->
    List.concat_map operand_names items
  | MClCall (_, cb, args, _) ->
    operand_names cb @ List.concat_map operand_names args
  | MFunAddr _ -> []
  | MAsm (_, _, ins, _) -> List.concat_map operand_names ins
  | MAtomicLoad (_, p, _, _) -> operand_names p
  | MAtomicStore (p, v, _, _) -> operand_names p @ operand_names v
  | MAtomicRMW (_, _, p, v, _, _) -> operand_names p @ operand_names v
  | MAtomicCAS (_, p, ex, nw, _, _, _) ->
    operand_names p @ operand_names ex @ operand_names nw
  | MFence _ -> []
  | MVolatileLoad (_, p, _) -> operand_names p
  | MVolatileStore (p, v, _) -> operand_names p @ operand_names v

let pure_dst (i : instr) : string option =
  match i with
  | MBinop (d, _, _, _) | MUnop (d, _, _) | MCast (d, _, _) ->
    if String.length d > 0 && d.[0] = '%' then Some d else None
  (* 指针取地址/读/字段地址/元素地址/函数地址均为纯求值（间接调用有副作用除外）；
     错误值判定/取值同理（只读槽） *)
  | MAddrOf (d, _) | MLoadK (d, _, _) | MFieldAddr (d, _, _, _, _)
  | MElemAddr (d, _, _, _, _) | MFunAddr (d, _)
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
    { fname = "zfy.globals"; fparams = []; fret = TVoid; frunred = false;
      fbody = h.ginit }
  in
  let mfns =
    List.map (fun (f : tfn) -> cleanup_fn (fold_fn (lower_fn h f))) (gfn :: h.hfns)
  in
  { mfns; mstructs = h.hstructs }

