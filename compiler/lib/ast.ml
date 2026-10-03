(* zfy 抽象语法树（Parser 产物，未做语义分析） *)
open Tokens

(* 类型一律为裸名字：i8..i128 / u8..u128 / f16..f128 / bool / char / string / void
   （int. / float. / double. / frac. 前缀与 &T *T []T [T;N] 已删除） *)
type ty = TNamed of string * pos

type binop = Add | Sub | Mul | Div | Mod | Eq | Ne | Lt | Gt | Le | Ge | And | Or
type unop = Neg | Not

(* input 的目标：声明新变量（<类型> 名）或使用已有变量（名） *)
type in_target =
  | InNew of string * ty * pos
  | InUse of string * pos

type expr =
  | EInt of int64 * pos
  | EFloat of float * pos
  | EStr of string * pos
  | EChar of char * pos
  | EBool of bool * pos
  | EVar of string * pos
  | EBin of binop * expr * expr * pos
  | EUn of unop * expr * pos
  | ECall of expr * call_arg list * pos    (* callee 为函数名 *)
  | EIndex of expr * expr * pos            (* arr[i] / s[i] *)
  | ESlice of expr * expr * expr * expr option * pos
    (* s[a,b] / s[a,b:step]（两端含，step 可省略；步长用冒号） *)
  | ECast of expr * ty * pos               (* cast(e, T) *)
  | EBlock of block * pos                  (* 块表达式，值为最后一个表达式 *)

and stmt =
  | SDecl of bool * bool * bool * string * ty * expr option * pos
    (* 标量声明：(is_const, is_frac, is_unreduced, 名, 类型, 初值(可省略, 省略时填零值))；
       const/frac/unreduced 在类型后名字前；const 必须带初值；
       is_frac 时初值 a/b 解释为分数字面量 *)
  | SSeqDecl of bool * string * ty * expr option * bool * expr list * pos
    (* 数组/列表声明：(is_const, 名, 元素类型, 长度表达式(列表为 None, 可用 const
       变量), 是否列表, 初始元素)；未给出的槽位填零值 *)
  | SAssign of expr * expr * pos
  | SAug of binop * expr * expr * pos      (* 复合赋值：lhs op= rhs（左值地址只求值一次） *)
  | SInc of expr * pos                     (* x++（仅后缀） *)
  | SDec of expr * pos                     (* x--（仅后缀） *)
  | SExpr of expr
  | SReturn of expr option * pos
  | SIf of expr * block * block option * pos
  | SWhile of expr * block * pos
  | SFor of for_init list * expr * for_update list * block * pos
  | SOutput of expr list * expr option * expr option * pos
    (* output(参数..., sep=?, end=?)；sep/end 为表达式（char/string 或可转 string） *)
  | SInput of in_target list * expr option * pos
    (* input(目标..., delim=?)；delim 为 char/string 表达式，None 默认"换行和空格"字符集 *)
  | SReduce of expr * expr * expr * pos        (* reduce(x, 次数, 起始除数) *)
  | SRemove of expr * expr * pos               (* remove(数组/列表名, 下标) *)
  | SBreak of pos
  | SContinue of pos
  | SThrow of expr * pos
    (* throw 表达式：表达式为 char/string（运行时统一为 string 消息） *)
  | STry of block * (string option * block) * pos
    (* try 块 + catch (名字)? 块：异常消息为 string，catch 名字可省略 *)

(* for 头部初始化项：新声明（类型 [const] [frac] [unreduced] 名 = 值）
   或占位表达式（孤立变量名，如 for i, i<5, i++ 的 i，执行一次，无效果） *)
and for_init =
  | FIDecl of bool * string * ty * expr option * pos  (* (is_const, 名, 类型, 初值(可省略)) *)
  | FIExpr of expr * pos

(* for 头部更新项：x = e / x op= e / x++ / x-- *)
and for_update =
  | FUAssign of expr * expr * pos
  | FUOp of binop * expr * expr * pos          (* 复合赋值：lhs op= rhs *)
  | FUInc of expr * pos                        (* x++（仅后缀） *)
  | FUDec of expr * pos                        (* x--（仅后缀） *)

and block = stmt list

(* 调用实参：位置参数在前，命名参数在后（如 find 的 count=、output 的 sep=） *)
and call_arg =
  | CPos of expr
  | CNamed of string * expr

(* 参数种类：标量 / 定长数组（长度为表达式：字面量或之前参数名）/ 列表 *)
type pseq_kind =
  | PScalar
  | PArray of expr
  | PList

type param = { pname : string; pty : ty; pfrac : bool; pseq : pseq_kind; ppos : pos }

type item =
  | IUse of { path : string; import : string option; alias : string option;
              pos : pos }
    (* use 文件名.zfy [import 模块名] [as 别名]：别名绑定给文件（命名空间） *)
  | IFn of { name : string; params : param list; ret : ty option; rfrac : bool;
             body : block; pos : pos }
    (* rfrac：返回类型带 frac 修饰（返回 TFrac） *)
  | IMod of string * item list * pos
  | IDecl of stmt * pos
    (* 顶层声明：仅允许 const 标量（编译期常量，使用处内联，不生成运行时槽） *)

type program = item list
