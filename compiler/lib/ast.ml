(* zfy 抽象语法树（Parser 产物，未做语义分析） *)
open Tokens

(* 类型与表达式互递归定义（w-014 #1：TSeqN 的定长带表达式长度）：
   类型：裸名字（i8..f128 / bool / char / string / void / struct 名 / type 别名），
   加指针 T*（T* const 为不可变指针）与函数类型（仅 type 别名处允许） *)
type ty =
  | TNamed of string * pos
  | TPtr of ty * pos                  (* T*：指向 T 的指针 *)
  | TPtrC of ty * pos                 (* T* const：指向 const T 的指针（解引用写报错） *)
  | TErr of ty * pos                  (* T!：可失败值（错误模型 ZEM） *)
  | TFun of ty * ty list * pos        (* 返回类型, 参数类型列表（仅 type 别名） *)
  | TApp of string * ty list * pos    (* 泛型实例化：Box<i32, T*>（名字 + 类型实参） *)
  | TSeq of ty * pos                  (* T[]：动态数组/列表（类型后缀形式，w-014 #1） *)
  | TSeqN of ty * expr * pos          (* T[N]：定长数组（类型后缀形式；N 须整数字面量，
                                         声明/参数处仍可用完整表达式长度） *)

and binop =
  | Add | Sub | Mul | Div | Mod | Eq | Ne | Lt | Gt | Le | Ge | And | Or
  | BitAnd (* & 二元位与（一元 Amp 是取地址，位置区分） *)
  | BitOr  (* | 位或 *)
  | Xor    (* xor 关键字：二元异或（^ 仍为解引用后缀） *)
  | Shl    (* << *)
  | Shr    (* >> *)
  | Pow    (* ** 幂，右结合（v3.3）：x**2**3 == x**(2**3) *)

and unop = Neg | Not | BitNot (* ~ 按位取反 *)

(* input 的目标：声明新变量（<类型> 名）或使用已有变量（名） *)
and in_target =
  | InNew of string * ty * pos
  | InUse of string * pos

and expr =
  | EInt of int64 * pos
  | EBigInt of string * pos       (* 超出 i64 的十进制大字面量（w-014 #6）：
                                     仅在 i128/u128 期望上下文合法 *)
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
  | EStructNew of string * call_arg list * pos
    (* struct 构造：Point(1.0, 2.0) / Point(x=1.0) / Point()；位置参数在前命名在后 *)
  | EField of expr * string * pos          (* p.x：点号字段访问（链式） *)
  | EBlock of block * pos                  (* 块表达式，值为最后一个表达式 *)
  | EAddrOf of expr * pos                  (* &x：取地址（变量/字段/元素/解引用） *)
  | EDeref of expr * pos                   (* p*：后缀解引用 *)
  | ENull of pos                           (* null：空指针字面量 *)
  | EFail of expr * expr * pos             (* fail(code, msg)：构造 T! 错误值 *)
  | EPanic of expr option * expr * pos     (* panic(msg) / panic(code, msg)：不可恢复终止 *)
  | EUnwrap of expr * expr * pos           (* a ?? b：解包；b 为 EBlock 时为解包块形式 *)
  | EPropagate of expr * pos               (* a?：错误传播（函数返回类型须 T!） *)
  | ERemove of expr * expr * pos
    (* remove(数组/列表, 下标)：表达式（v3 2026-10-11）——返回被删元素
       （深拷贝副本），数组槽位填零、列表删除并左移；裸语句报错 *)

and stmt =
  | SDecl of bool * bool * bool * string * ty option * expr option * pos
    (* 标量声明（new.md 2026-10-10）：let (类型)? (frac)? (const)? (unred)? 名 (= 初值)?;
       类型可省（由初值推断：整数字面量→i32、浮点→f64、n/d 字面量除式→i32 frac、
       string/char/bool 按字面量；其他表达式取自身类型）；类型与初值二选一或都写，
       不能都无（frac 修饰视同给出类型 i32 frac）；有类型无初值=零值；
       const 必须带初值；is_frac 时初值 a/b 解释为分数字面量 *)
  | SSeqDecl of bool * bool * bool * string * ty * expr option * bool * expr list * pos
    (* 数组/列表声明（let 形式）：(is_const, is_frac, is_unred, 名, 元素类型,
       长度表达式(列表为 None, 可用 const 变量), 是否列表, 初始元素)；
       未给出的槽位填零值；frac 数组/列表元素存入后自动约分（unred 数组不约分） *)
  | SDeclList of stmt list
    (* 一行多声明器（w-012）：T a, b = 1, c[3], d[]——各声明器共享类型与前缀
       修饰符（const/frac/unred），初值各自独立；仅语句位置（顶层与 for
       头部保持单声明器，避免与 for 头逗号段冲突） *)
  | SAssign of expr * expr * pos
  | SAssignList of expr * expr list * pos
    (* 序列字面量整体赋值（w-014 #3）：a = 1, 2, 3 / bag.xs = 1, 2——
       目标须为数组/列表槽（变量/字段链/ref 解引用），元素逐个检查 *)
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
  | SBreak of pos
  | SContinue of pos
  | SUnsafe of block * pos
    (* unsafe 块：允许指针算术（p+n / p-n / p2-p1）；其余语义与普通块一致 *)

(* for 头部初始化项：let 声明（let (类型)? (frac)? (const)? (unred)? 名 = 值，
   类型可省时由初值推断）或占位表达式（孤立变量名，如 for i, i<5, i++ 的 i，
   执行一次，无效果） *)
and for_init =
  | FIDecl of bool * bool * bool * string * ty option * expr option * pos
    (* (is_const, is_frac, is_unred, 名, 类型(可省), 初值(可省略)) *)
  | FIExpr of expr * pos

(* for 头部更新项：x = e / x op= e / x++ / x-- *)
and for_update =
  | FUAssign of expr * expr * pos
  | FUOp of binop * expr * expr * pos          (* 复合赋值：lhs op= rhs *)
  | FUInc of expr * pos                        (* x++（仅后缀） *)
  | FUDec of expr * pos                        (* x--（仅后缀） *)

and block = stmt list

(* 调用实参：位置参数在前，命名参数在后（如 find 的 count=、output 的 sep=）；
   CMove 为显式 move 实参（f(move p)：所有权移交，p 之后不可再用）；
   CCopy 为显式深拷贝实参（f(copy p)：与默认值语义相同，显式声明意图，
   与自动 move 判定互斥）；CRef 为传引用实参（f(ref y)：y 须为可定位变量，
   对应参数须声明为 ref——函数内经指针读写调用方变量） *)
and call_arg =
  | CPos of expr
  | CNamed of string * expr
  | CMove of expr
  | CCopy of expr
  | CRef of expr

(* 参数种类：标量 / 定长数组（长度为表达式：字面量或之前参数名）/ 列表 *)
type pseq_kind =
  | PScalar
  | PArray of expr
  | PList

type param = { pname : string; pty : ty; pfrac : bool; pseq : pseq_kind;
               pconst : bool; punred : bool; pref : bool; ppos : pos }
  (* let 形式参数（new.md 2026-10-10）：let (类型)? (frac)? (const)? (unred)? 名；
     类型可省但须有 frac（隐含 i32 frac），否则报错（参数无初值可推断）；
     pref：ref 参数——`ref let i32 x`，调用方 f(ref y) 传地址，
     函数体内自动解引用读写（仅标量/string，extern/函数指针不支持）；
     pconst：函数体内不可赋值；punred：入口不做 frac 归一 *)

(* extern "C" 块内的单个 C 函数声明 *)
type extern_fn =
  { ename : string; eparams : param list; eret : ty; erfrac : bool; epos : pos }

(* struct 字段：类型 名字 [= 默认值]；类型可为标量/T[N]/T[]/其他 struct *)
type sfield =
  { fname : string; fty : ty; fseq : pseq_kind; fdefault : expr option; fpos : pos }

(* struct 方法（v3.2 随机数模块）：struct 块内 fn 定义；
   脱糖为顶层 IFn <S>__<m>，隐式首参 self = ref let <S>（可变接收者） *)
type smethod =
  { mname : string; mparams : param list; mret : ty option; mrfrac : bool;
    mbody : block; mpos : pos }

type item =
  | IUse of { path : string; import : string option; alias : string option;
              pos : pos }
    (* use 文件名.zfy [import 模块名] [as 别名]：别名绑定给文件（命名空间，
       legacy——新代码用 IUseP 的 a::b::item 路径语法） *)
  | IUseP of { binds : (string * string list * pos) list; pos : pos }
    (* use 路径语法（模块系统）：名字绑定，不搬运 AST。
       use a::b::item;      binds=[("item", ["a";"b";"item"])]
       use a::b::item as x; binds=[("x", ["a";"b";"item"])]
       use a::b::{x, y as z}; binds=[("x", [...;"x"]); ("z", [...;"y"])]
       use a::b as m;       binds=[("m", ["a";"b"])]（绑定模块） *)
  | IFn of { name : string; params : param list; ret : ty option; rfrac : bool;
             runred : bool; body : block; pos : pos; tparams : string list }
    (* fn 前缀函数（new.md 2026-10-10）：fn (类型)? (frac)? (const)? (unred)? 名(参数)；
       ret=None 仅限 main（隐含 i32，return 可省）；runred：返回类型带 unred
       （返回值不做 frac 归一）；tparams：泛型类型参数（fn <T, U> ...），空 = 普通 *)
  | IStruct of { name : string; packed : bool; fields : sfield list; pos : pos;
                 tparams : string list; methods : smethod list }
    (* tparams：泛型类型参数（struct Box<T, U>），空 = 普通 struct *)
  | IMod of string * item list * pos
    (* 内联模块 mod name（缩进块体，可嵌套）；resolve 展开为扁平名 *)
  | IModFile of string * pos
    (* 文件模块 mod name;：body 在 name.zfy 或 name/mod.zfy（相对父模块
       文件目录），由 resolve 加载展开；空 item list 语义由此区分 *)
  | IExtern of { funcs : extern_fn list; pos : pos }
    (* extern "C" 块：多个 C 函数声明（签名直通 LLVM，调用不门禁） *)
  | ITypeAlias of { name : string; ty : ty; pos : pos }
    (* type 别名：type 名 = 类型（可含函数类型） *)
  | IDecl of stmt * pos
    (* 顶层声明：仅允许 const 标量（编译期常量，使用处内联，不生成运行时槽） *)
  | IPub of item * pos
    (* pub 修饰：仅模块内顶层合法（root 顶层 pub 被 resolve 忽略） *)

type program = item list
