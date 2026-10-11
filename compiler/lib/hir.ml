(* HIR：带类型/符号信息的高层 IR *)
open Tokens

type zty =
  | TInt of int                     (* 8/16/32/64/128 *)
  | TUint of int
  | TFloat of int                   (* 16/32/64/128 *)
  | TBool
  | TChar
  | TString
  | TVoid
  | TFrac of zty                    (* 分数类型（frac 修饰任意数值类型） *)
  | TArray of zty * int             (* 定长数组：元素类型, 长度 *)
  | TList of zty                    (* 列表：元素类型（容量动态增长） *)
  | TStruct of string               (* struct：名字在 hstructs 中查定义 *)
  | TPtr of zty                     (* 指针：指向 T（T* const 不可变约束由 typeck 检查） *)
  | TErr of zty                     (* T!：可失败值（元素为标量/string/指针） *)
  | TFile                           (* 文件句柄（move-only）：槽为句柄对象指针
                                       {FILE* fp; int closed}，open 分配，close/RAII 释放 *)
  | TFunSig of zty list * zty       (* 函数签名：(参数类型, 返回类型)——仅经 type 别名 *)
  | TVar of int                     (* 类型推断变量 *)

(* struct 定义（typeck 收集后随 HIR/MIR 传递，llvmgen 生成布局与深拷贝辅助） *)
type sdef = { sname : string; spacked : bool; sfields : (string * zty) list }

type binop =
  BAdd | BSub | BMul | BDiv | BMod | BEq | BNe | BLt | BGt | BLe | BGe | BAnd | BOr
| BBitAnd | BBitOr | BBitXor | BShl | BShr | BPow (* ** 幂（v3.3） *)
type unop = UNeg | UNot | UBitNot

type texpr =
  { e : texpr_kind; ety : zty; epos : pos }

and texpr_kind =
  | EIntK of int64
  | EBigK of string               (* i128/u128 大字面量（w-014 #6）：十进制数字串 *)
  | EFloatK of float
  | EStrK of string
  | ECharK of char
  | EBoolK of bool
  | EVarK of string                 (* 槽位名（shadowing 时与源码名不同） *)
  | EBinK of binop * texpr * texpr
  | EUnK of unop * texpr
  | ECallK of string * texpr list * bool list
  (* 函数名 + 实参 + 显式 move 标记（与实参等长；true = f(move x) 所有权移交） *)
  | ECastK of texpr * zty
  | EFracNewK of texpr * texpr      (* 分数字面量：分子 / 分母 *)
  | ESeqGetK of texpr * texpr       (* arr[i]：结果为元素类型（越界运行时报错） *)
  | ESeqLenK of texpr               (* length(x)：数组/列表长度（string 走 strlen 调用） *)
  | ESeqSliceK of texpr * texpr * texpr * texpr
    (* base[a,b:step]：数组/列表切片，返回同元素类型的动态序列（TList 元素） *)
  | ESplitK of texpr * texpr        (* split(s, x)：结果为 string 列表（新 seq，临时） *)
  | ESeqLitK of zty * texpr list    (* 序列字面量（整体赋值右值，w-014 #3）：新分配 seq + 逐元素写入 *)
  | EPushK of texpr * texpr         (* push(list, v)：追加到列表末尾（自动扩长），
                                       返回列表本身（v3 2026-10-11 表达式化）。
                                       base 为可写 seq 槽根：变量槽/字段链/解引用（ref 参数） *)
  | ERemoveK of texpr * texpr * bool
    (* remove(数组/列表, i)：(槽根, 下标, 是否列表)，返回被删元素（深拷贝副本，
       v3 2026-10-11 表达式化）；数组=槽位填零（长度不变）、列表=删除并左移 *)
  | EStructNewK of string * texpr list
    (* struct 构造：名, 字段值（按声明序，typeck 已补全 default/零值） *)
  | EFieldK of texpr * int          (* 字段读取：base, 字段序号（ety = 字段类型） *)
  | EEmptySeqK                      (* 空数组/列表（struct 字段缺省值：新分配空 seq） *)
  | ENullK                          (* null：空指针（ety = 具体指针类型，推断后落地） *)
  | EAddrOfK of texpr               (* &x：取地址（ety = TPtr x.ety；x 为变量/字段/元素） *)
  | EDerefK of texpr                (* p*：解引用（p.ety = TPtr 目标；ety = 目标类型） *)
  | EIndirectCallK of texpr * texpr list
    (* 函数指针调用 f(args)：被调指针表达式 + 实参（f.ety = TPtr TFunSig） *)
  | EFunPtrK of string
    (* 函数名作为值（取函数入口地址）：ety = TPtr (TFunSig ...) *)
  | EFailK of texpr * texpr         (* fail(code, msg)：ety = TErr 元素类型（TVar 由上下文求解） *)
  | EPanicK of texpr option * texpr (* panic(code?, msg)：不可恢复终止（ety = TVoid） *)
  | EUnwrapK of texpr * texpr       (* a ?? b：a 为 TErr t，b 为 t，结果 t（短路） *)
  | EPropagateK of texpr            (* a?：a 为 TErr t；失败则从函数传播返回（ety = t） *)
  | EErrOkK of texpr                (* 成功包装：T 值包成 TErr T（赋值/传参/返回自动包装） *)
  | EFindK of texpr * texpr * texpr (* find(s, c, k)：ety = TErr (TInt 64)；找不到 = NOT_FOUND *)

and tstmt =
  { s : tstmt_kind; spos : pos }

and tstmt_kind =
  | SDeclK of bool * string * zty * texpr * bool
    (* 标量声明：(is_const, 槽位名, 类型, 值, 需自动约分)——变量永远有值，必有初值；
       需约分 = frac 且非 unred（存入后调用 zfy_frac_norm 约分） *)
  | SSeqDeclK of bool * string * zty * int64 * bool * texpr list * bool
    (* 数组/列表声明：(is_const, 槽位名, 元素类型, 长度(列表为编译期求得的初始
       槽位数，可为 0), 是否列表, 初始元素, 元素需归一 enn——frac 且非 unred，
       初值元素与后续元素存入均自动约分) *)
  | SSeqCopyK of bool * string * zty * int64 * texpr * bool
    (* (is_const, 槽, 元素类型, 长度(列表忽略), 源, 是否列表) *)
    (* 数组整体初值：T array b[N] = 源（源为数组/列表，深拷贝） *)
  | SAssignK of texpr * texpr * bool * bool
    (* 标量赋值：(目标, 值, 需自动约分, move)——move=true 时值为同一变量槽
       （EVarK src），所有权转移免克隆（自动 move/显式 move 赋值，new2.md #1） *)
  | SStrAppendK of string * texpr list
    (* string 原地追加（T7 优化）：槽名 + 追加操作数（各为 string 值）。
       语义同 s = s + p1 + p2 + ...，但走 realloc 扩容（O(追加量) 而非
       O(总长) 拷贝）；槽须独占堆串（MCopy strdup 保证），且各操作数
       不得引用槽本身（typeck 侧保证，否则 realloc 后悬垂读） *)
  | SAugIndexK of texpr * zty * texpr * binop * texpr * bool
    (* 复合赋值作用于数组/列表元素：a[i] op= v
       (槽根, 元素类型, 下标(只求值一次), 运算, 右值, 可扩长)——槽根为
       变量槽 EVarK / 字段链 EFieldK / 解引用 EDerefK（w-014 #3） *)
  | SAugVarK of string * zty * binop * texpr * bool
    (* 复合赋值作用于标量变量：x op= v（槽名, 类型, 运算, 右值, 需自动约分） *)
  | SAugSliceK of string * zty * texpr * texpr * texpr * binop * texpr
    (* 复合赋值作用于切片区间：a[x,y:st] op= v（槽名, 元素类型, 起点, 终点, 步长,
       运算, 右值）——原地作用于原数组的每个元素 *)
  | SSeqSetK of texpr * zty * texpr * texpr * bool
    (* arr[i] = v：(槽根, 元素类型, 下标, 值, 是否列表可扩长)。槽根为可写
       seq 槽：变量槽 EVarK / 字段链 EFieldK / 解引用 EDerefK（ref 参数）/
       元素槽地址 EAddrOfK (ESeqGetK _)（嵌套写 a[i][j]，w-014 #3/#4） *)
  | SStrSetK of texpr * texpr * texpr
    (* s[i] = c：string 下标写字符（w-014 #5）——(槽根, 下标, char 值)。
       槽内堆串原地写（槽独占由 MCopy strdup 保证），越界运行时报错；
       字段/ref 路径 load 出串指针后同写 *)
  | SExprK of texpr
  | SReturnK of texpr option
  | SIfK of texpr * tblock * tblock
  | SWhileK of texpr * tblock
  | SForK of tstmt list * texpr * tstmt list * tblock
    (* (初始化语句, 条件表达式, 更新语句, 循环体) *)
  | SOutputK of texpr list * texpr * texpr      (* (参数, sep, end)——sep/end 已转 string *)
  | SInputK of tin_target list * texpr option   (* (目标列表, delim 表达式；None 默认字符集) *)
  | SReduceK of texpr * texpr * texpr           (* reduce(x, 次数, 起始除数) *)
  | SUnwrapBlockK of bool * bool * string * zty * texpr * string * tblock
    (* 解包块：a ?? 缩进块。(是否声明新变量, 是否 return 形式, 目标槽, 元素类型,
       a 表达式, err 槽名（TStruct "Err"）, 块)。块末值表达式已由 typeck 改写为
       对目标槽的赋值（return 形式改写为 SReturnK）；块也可 return/break/
       continue/panic 提前离开。return 形式：成功路径直接返回 a 的成功聚合，
       目标槽不使用（is_decl=false、slot=""） *)
  | SBreakK
  | SContinueK
  | SFieldSetK of texpr * int list * zty * texpr
    (* struct 字段链写入：(根地址, 字段序号链, 根 struct 类型, 值)——
       根地址为 TStruct/TPtr(TStruct) 形态：变量槽 EVarK / 元素槽地址
       EAddrOfK (ESeqGetK _)（ps[1].x = v，w-014 #8）/ 解引用 EDerefK；
       根只定位一次，链逐级 GEP；聚合字段写入为深拷贝（值语义） *)
  | SAugFieldK of string * int list * zty * binop * texpr
    (* struct 字段链复合赋值：(根槽名, 链, 根类型, 运算, 右值)——
       仅数值标量字段（load + op + store 同一字段） *)
  | SDerefSetK of texpr * texpr
    (* 指针解引用写入：p* = v（p 表达式, 值——目标类型 = v.ety，仅标量/指针；
       聚合（string/数组/列表）目标为引用槽整体赋值：释放旧值 + 接管新值（w-014 #3） *)
  | SAugDerefK of texpr * binop * texpr
    (* 指针解引用复合赋值：p* op= v（p 表达式, 运算, 右值）；p*++ 亦归此 *)
  | SUnsafeK of tblock
    (* unsafe 块：仅标记作用域（typeck 时放开指针算术门禁），降码时透明展开 *)

and tblock = tstmt list

(* input 目标：tnew=true 表示声明新变量，否则为给已有变量赋值 *)
and tin_target = { tname : string; tnew : bool; tty : zty }

type tfn = {
  fname : string;
  fparams : (bool * string * zty * bool) list;   (* (is_mut, 槽位名, 类型, 参数 unred) *)
  fret : zty;
  frunred : bool;                         (* 返回类型带 unred：返回值不做 frac 归一 *)
  fbody : tblock;
}

type hir = { hfns : tfn list; hglobals : (string * zty) list; ginit : tblock;
             hstructs : sdef list }
  (* hglobals：全局变量槽（槽名以 @ 开头，LLVM 全局变量）；ginit：全局初始化语句；
     hstructs：本程序全部 struct 定义（llvmgen 生成类型/布局/深拷贝辅助） *)

(* ---------- 类型名表 ---------- *)

let int_suffixes = [
  ("i8", TInt 8); ("i16", TInt 16); ("i32", TInt 32); ("i64", TInt 64);
  ("i128", TInt 128);
  ("u8", TUint 8); ("u16", TUint 16); ("u32", TUint 32); ("u64", TUint 64);
  ("u128", TUint 128);
  ("f16", TFloat 16); ("f32", TFloat 32); ("f64", TFloat 64); ("f128", TFloat 128);
]

let prim_type name =
  match List.assoc_opt name int_suffixes with
  | Some t -> Some t
  | None ->
    (match name with
     | "bool" -> Some TBool
     | "char" -> Some TChar
     | "string" -> Some TString
     | "void" -> Some TVoid
     | "File" -> Some TFile
     | _ -> None)

(* frac 支持的元素类型（f16 分数暂不支持；f128=long double 与整数/f32/f64 同模板） *)
let frac_elem_ok = function
  | TInt _ | TUint _ | TFloat 32 | TFloat 64 | TFloat 128 -> true
  | _ -> false

let rec pp_zty = function
  | TInt n -> Printf.sprintf "i%d" n
  | TUint n -> Printf.sprintf "u%d" n
  | TFloat n -> Printf.sprintf "f%d" n
  | TBool -> "bool" | TChar -> "char" | TString -> "string" | TVoid -> "void"
  | TFrac t -> Printf.sprintf "%s frac" (pp_zty t)
  | TArray (t, n) -> Printf.sprintf "%s[%d]" (pp_zty t) n
  | TList t -> Printf.sprintf "%s list" (pp_zty t)
  | TStruct s -> s
  | TPtr t -> Printf.sprintf "%s*" (pp_zty t)
  | TErr t -> Printf.sprintf "%s!" (pp_zty t)
  | TFile -> "File"
  | TFunSig (ptys, ret) ->
    Printf.sprintf "%s(%s)" (pp_zty ret)
      (String.concat "," (List.map pp_zty ptys))
  | TVar n -> Printf.sprintf "?T%d" n

(* 类型后缀（frac 与 LLVM 类型命名共用） *)
and suffix_of = function
  | TInt n -> Printf.sprintf "i%d" n
  | TUint n -> Printf.sprintf "u%d" n
  | TFloat n -> Printf.sprintf "f%d" n
  | t -> failwith ("非法的 frac 元素类型: " ^ pp_zty t)

let pp_binop = function
  | BAdd -> "+" | BSub -> "-" | BMul -> "*" | BDiv -> "/" | BMod -> "%"
  | BEq -> "==" | BNe -> "!=" | BLt -> "<" | BGt -> ">" | BLe -> "<=" | BGe -> ">="
  | BAnd -> "&&" | BOr -> "||"
  | BBitAnd -> "&" | BBitOr -> "|" | BBitXor -> "xor"
  | BShl -> "<<" | BShr -> ">>" | BPow -> "**"

let pp_unop = function UNeg -> "-" | UNot -> "!" | UBitNot -> "~"

(* ---------- x86-64 C 布局（sizeof/alignof 与 struct 字段偏移） ---------- *)

let align_up n a = if a <= 1 then n else (n + a - 1) / a * a

(* 标量（含 string/数组/列表槽=ptr）的 (大小, 对齐)；
   TStruct/TVoid/TVar 返回 (-1, 1)（由调用方按 struct 表递归） *)
let rec scalar_size_align (t : zty) : int * int =
  match t with
  | TInt n | TUint n -> if n <= 64 then (n / 8, n / 8) else (16, 16)
  | TFloat 16 -> (2, 2)
  | TFloat 32 -> (4, 4)
  | TFloat 64 -> (8, 8)
  | TFloat 128 -> (16, 16)         (* x86_fp80（long double） *)
  | TBool | TChar -> (1, 1)
  | TString | TArray _ | TList _ | TFile -> (8, 8)
  | TPtr _ | TFunSig _ -> (8, 8)
  | TFrac e -> let (s, a) = scalar_size_align e in (2 * s, a)
  | _ -> (-1, 1)

(* 类型 (大小, 对齐)：struct 递归查表 *)
let rec ty_size_align (structs : sdef list) (t : zty) : int * int =
  match t with
  | TStruct s ->
    (match List.find_opt (fun sd -> sd.sname = s) structs with
     | Some sd -> struct_size_align structs sd
     | None -> (-1, 1))
  | _ -> scalar_size_align t

(* struct (大小, 对齐)：
   - 非 packed：C 布局（字段偏移按各自对齐取整，总大小对齐到最大字段对齐）
   - packed：字段紧凑排列（无填充），整体对齐 1 *)
and struct_size_align (structs : sdef list) (sd : sdef) : int * int =
  if sd.spacked then begin
    let size =
      List.fold_left
        (fun acc (_, ft) ->
          let (s, _) = ty_size_align structs ft in
          if s < 0 then acc else acc + s)
        0 sd.sfields
    in
    (size, 1)
  end
  else begin
    let off = ref 0 and mal = ref 1 in
    List.iter
      (fun (_, ft) ->
        let (s, a) = ty_size_align structs ft in
        if s >= 0 then begin
          mal := max !mal a;
          off := align_up !off a + s
        end)
      sd.sfields;
    (align_up !off !mal, !mal)
  end

(* struct 各字段偏移（声明序；packed 无填充）与 (总大小, 总对齐) *)
let struct_field_offsets (structs : sdef list) (sd : sdef)
    : int list * int * int =
  let (tsize, talign) = struct_size_align structs sd in
  if sd.spacked then begin
    let rec go off = function
      | [] -> ([], off)
      | (_, ft) :: rest ->
        let (s, _) = ty_size_align structs ft in
        let (offs, endoff) = go (if s < 0 then off else off + s) rest in
        (off :: offs, endoff)
    in
    let (offs, _) = go 0 sd.sfields in
    (offs, tsize, talign)
  end
  else begin
    let rec go off = function
      | [] -> ([], off)
      | (_, ft) :: rest ->
        let (s, a) = ty_size_align structs ft in
        if s < 0 then go off rest
        else begin
          let o = align_up off a in
          let (offs, endoff) = go (o + s) rest in
          (o :: offs, endoff)
        end
    in
    let (offs, _) = go 0 sd.sfields in
    (offs, tsize, talign)
  end
