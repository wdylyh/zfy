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
  | TVar of int                     (* 类型推断变量 *)

type binop = BAdd | BSub | BMul | BDiv | BMod | BEq | BNe | BLt | BGt | BLe | BGe | BAnd | BOr
type unop = UNeg | UNot

type texpr =
  { e : texpr_kind; ety : zty; epos : pos }

and texpr_kind =
  | EIntK of int64
  | EFloatK of float
  | EStrK of string
  | ECharK of char
  | EBoolK of bool
  | EVarK of string                 (* 槽位名（shadowing 时与源码名不同） *)
  | EBinK of binop * texpr * texpr
  | EUnK of unop * texpr
  | ECallK of string * texpr list   (* 函数名 + 实参 *)
  | ECastK of texpr * zty
  | EFracNewK of texpr * texpr      (* 分数字面量：分子 / 分母 *)
  | ESeqGetK of texpr * texpr       (* arr[i]：结果为元素类型（越界运行时报错） *)
  | ESeqLenK of texpr               (* length(x)：数组/列表长度（string 走 strlen 调用） *)
  | ESeqSliceK of texpr * texpr * texpr * texpr
    (* base[a,b:step]：数组/列表切片，返回同元素类型的动态序列（TList 元素） *)
  | ESplitK of texpr * texpr        (* split(s, x)：结果为 string 列表（新 seq，临时） *)
  | EPushK of texpr * texpr         (* push(list, v)：追加到列表末尾（自动扩长），结果 void *)

and tstmt =
  { s : tstmt_kind; spos : pos }

and tstmt_kind =
  | SDeclK of bool * string * zty * texpr * bool
    (* 标量声明：(is_const, 槽位名, 类型, 值, 需自动约分)——变量永远有值，必有初值；
       需约分 = frac 且非 unreduced（存入后调用 zfy_frac_norm 约分） *)
  | SSeqDeclK of bool * string * zty * int64 * bool * texpr list
    (* 数组/列表声明：(is_const, 槽位名, 元素类型, 长度(列表为编译期求得的初始
       槽位数，可为 0), 是否列表, 初始元素) *)
  | SSeqCopyK of bool * string * zty * int64 * texpr * bool
    (* (is_const, 槽, 元素类型, 长度(列表忽略), 源, 是否列表) *)
    (* 数组整体初值：T array b[N] = 源（源为数组/列表，深拷贝） *)
  | SAssignK of texpr * texpr * bool             (* 标量赋值：(目标, 值, 需自动约分) *)
  | SAugIndexK of string * zty * texpr * binop * texpr * bool
    (* 复合赋值作用于数组/列表元素：a[i] op= v
       (槽名, 元素类型, 下标(只求值一次), 运算, 右值, 可扩长) *)
  | SAugVarK of string * zty * binop * texpr * bool
    (* 复合赋值作用于标量变量：x op= v（槽名, 类型, 运算, 右值, 需自动约分） *)
  | SAugSliceK of string * zty * texpr * texpr * texpr * binop * texpr
    (* 复合赋值作用于切片区间：a[x,y:st] op= v（槽名, 元素类型, 起点, 终点, 步长,
       运算, 右值）——原地作用于原数组的每个元素 *)
  | SSeqSetK of string * zty * texpr * texpr * bool
    (* arr[i] = v：(槽名, 元素类型, 下标, 值, 是否列表可扩长) *)
  | SExprK of texpr
  | SReturnK of texpr option
  | SIfK of texpr * tblock * tblock
  | SWhileK of texpr * tblock
  | SForK of tstmt list * texpr * tstmt list * tblock
    (* (初始化语句, 条件表达式, 更新语句, 循环体) *)
  | SOutputK of texpr list * texpr * texpr      (* (参数, sep, end)——sep/end 已转 string *)
  | SInputK of tin_target list * texpr option   (* (目标列表, delim 表达式；None 默认字符集) *)
  | SReduceK of texpr * texpr * texpr           (* reduce(x, 次数, 起始除数) *)
  | SRemoveK of string * zty * texpr * bool     (* remove(x, i)：(槽名, 元素类型, 下标, 是否列表) *)
  | SThrowK of texpr                            (* throw 表达式（已统一为 string 消息） *)
  | STryK of tblock * string option * tblock    (* try 块, catch 绑定名(可省), catch 块 *)
  | SBreakK
  | SContinueK

and tblock = tstmt list

(* input 目标：tnew=true 表示声明新变量，否则为给已有变量赋值 *)
and tin_target = { tname : string; tnew : bool; tty : zty }

type tfn = {
  fname : string;
  fparams : (bool * string * zty) list;   (* (is_mut, 槽位名, 类型) *)
  fret : zty;
  fbody : tblock;
}

type hir = { hfns : tfn list; hglobals : (string * zty) list; ginit : tblock }
  (* hglobals：全局变量槽（槽名以 @ 开头，LLVM 全局变量）；ginit：全局初始化语句 *)

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
     | _ -> None)

(* frac 支持的元素类型（f16/f128 分数暂不支持） *)
let frac_elem_ok = function
  | TInt _ | TUint _ | TFloat 32 | TFloat 64 -> true
  | _ -> false

let rec pp_zty = function
  | TInt n -> Printf.sprintf "i%d" n
  | TUint n -> Printf.sprintf "u%d" n
  | TFloat n -> Printf.sprintf "f%d" n
  | TBool -> "bool" | TChar -> "char" | TString -> "string" | TVoid -> "void"
  | TFrac t -> Printf.sprintf "%s frac" (pp_zty t)
  | TArray (t, n) -> Printf.sprintf "%s[%d]" (pp_zty t) n
  | TList t -> Printf.sprintf "%s list" (pp_zty t)
  | TVar n -> Printf.sprintf "?T%d" n

(* 类型后缀（frac 与 LLVM 类型命名共用） *)
and suffix_of = function
  | TInt n -> Printf.sprintf "i%d" n
  | TUint n -> Printf.sprintf "u%d" n
  | TFloat n -> Printf.sprintf "f%d" n
  | _ -> failwith "非法的 frac 元素类型"

let pp_binop = function
  | BAdd -> "+" | BSub -> "-" | BMul -> "*" | BDiv -> "/" | BMod -> "%"
  | BEq -> "==" | BNe -> "!=" | BLt -> "<" | BGt -> ">" | BLe -> "<=" | BGe -> ">="
  | BAnd -> "&&" | BOr -> "||"

let pp_unop = function UNeg -> "-" | UNot -> "!"
