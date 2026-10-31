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
  | TClo of ty list * ty * pos        (* fn(T...) -> R：闭包类型（v3.7 函数式轮）。
                                         与函数指针 TFun（type 别名处 T(params) 无
                                         fn 前缀）并存；闭包值 = {code, env} 二元组 *)
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
  | EFracLit of int64 * int64 * pos
    (* (n/d) 分数字面量（v3.29 语义反转）：括号包住的两个整数字面量除式
       （或循环小数字面量折算结果）。语义由期望上下文决定——
       frac 期望 → 精确分数构造（EFracNewK，不除法）；整数期望 → 常量
       截断整除；浮点期望 → 实数除；无期望推断 → i32 frac。
       不带括号的 1/4 永远是普通除法（EBin Div），落 frac 目标编译期报错 *)
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
  | ECopyOf of expr * pos                  (* copy x：显式深拷贝标记（struct 赋值必须） *)
  | EMoveOf of expr * pos                  (* move x：显式所有权转移标记（源变量此后不可用） *)
  | EBorrow of expr * pos                  (* borrow e：只读借用——取 e 的地址（T* const），
                                              借用期内源不可被 move *)
  | ERemove of expr * expr * pos
    (* remove(数组/列表, 下标)：表达式（v3 2026-10-11）——返回被删元素
       （深拷贝副本），数组槽位填零、列表删除并左移；裸语句报错 *)
  | ELambda of lambda * pos
    (* lambda（v3.7 函数式轮）：fn [caps] (params) => expr（简写，返回类型
       由表达式推断）或 fn [caps] (params) -> T { block }（块形式，显式返回
       类型）；捕获列表可省 = 体内自由变量默认值捕获，列表内 &x = 引用捕获 *)

(* lambda 参数：类型可省（从期望闭包类型反推；无期望时报错要求显式） *)
and lparam = { lpname : string; lpty : ty option; lppos : pos }

and lambda =
  { lparams : lparam list;
    lcaps : (bool * string * pos) list;   (* (是否引用捕获, 变量名, pos) *)
    lbody : lambda_body }

and lambda_body =
  | LExpr of expr                       (* => expr 简写 *)
  | LBlock of block * ty option         (* -> T { block }；T 已由 parser 消费 *)

and stmt =
  | SDecl of bool * bool * bool * bool * string * ty option * expr option * pos
    (* 标量声明（new.md 2026-10-10）：let (类型)? (frac)? (const)? (unred)? 名 (= 初值)?;
       类型可省（由初值推断：整数字面量→i32、浮点→f64、n/d 字面量除式→i32 frac、
       string/char/bool 按字面量；其他表达式取自身类型）；类型与初值二选一或都写，
       不能都无（frac 修饰视同给出类型 i32 frac）；有类型无初值=零值；
       const 必须带初值；is_frac 时初值 a/b 解释为分数字面量。
       v3.26 并发安全（P0-3）：is_shared = `let shared ...` 声明——仅顶层合法，
       语义 = 跨线程共享变量，锁外裸读写报错（须经 lock 块或 atomic 内建访问） *)
  | SSeqDecl of bool * bool * bool * bool * string * ty * expr option * bool * expr list * pos
    (* 数组/列表声明（let 形式）：(is_const, is_frac, is_unred, is_shared, 名, 元素类型,
       长度表达式(列表为 None, 可用 const 变量), 是否列表, 初始元素)；
       未给出的槽位填零值；frac 数组/列表元素存入后自动约分（unred 数组不约分） *)
  | SLock of expr * block * pos
    (* lock 块（v3.26 P0-3）：lock m { }——m 为 mutex 句柄变量。块入口 zfy_mutex_lock、
       正常/提前跳转路径 zfy_mutex_unlock（mir 侧锁栈回卷）。块内对 shared 全局的
       裸读写合法（typeck 按锁持有集合放行）；锁外裸读写报错 *)
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
  | SForIn of string * string option * expr * block * pos
    (* for-in 遍历（v3.6）：for x in xs { }——xs 支持 列表/数组（元素）、
       string（char）、map（键）。循环变量类型由序列类型推断；
       typeck 降码为索引/迭代器循环（SBlockK 透明块承载）。
       v3.10 带下标：for x in xs, i { }——i 绑定 i64 索引（每轮递增） *)
  | SOutput of expr list * expr option * expr option * pos
    (* output(参数..., sep=?, end=?)；sep/end 为表达式（char/string 或可转 string） *)
  | SInput of in_target list * expr option * pos
    (* input(目标..., delim=?)；delim 为 char/string 表达式，None 默认"换行和空格"字符集 *)
  | SReduce of expr * expr * expr * pos        (* reduce(x, 次数, 起始除数) *)
  | SBreak of pos
  | SContinue of pos
  | SUnsafe of block * pos
    (* unsafe 块：允许指针算术（p+n / p-n / p2-p1）；其余语义与普通块一致 *)
  | SAsm of string * (string * pos) list * (string * pos) list * string option * pos
    (* 内联汇编（语句）：asm("模板", out=变量, in=变量, clobber="寄存器,...")。
       模板 $0..$n 依次对应 out（先）再 in（后）；out= 可重复、顺序任意，
       调用后按槽写回。必须在 unsafe 块内（typeck 门禁）。 *)
  | SFn of string * lparam list * ty option * bool * block * pos
    (* 嵌套函数定义（v3.7 函数式轮）：块内 fn 返回类型? 名(参数) { }——
       按命名 lambda 处理：定义处创建闭包（隐式值捕获所在函数局部变量），
       名字绑定为局部闭包值变量。仅语句位置（顶层 fn 走 IFn）；参数用
       lparam 形状（param 定义在 stmt 之后，无法前向引用） *)
  | SMatch of expr * marm list * pos
    (* match 分发（v3.9）：match scrut 缩进块，每 arm `模式 => 语句或块`。
       模式：_ 通配 / 字面量（== 比较）/ 枚举变体（变体路径 + (绑定名...)）；
       降码为 tag/相等比较 if 链（typeck 内展开，hir/mir 无新构造）。
       v3.11：穷尽性检查——enum 类型的 scrutinee 须覆盖全部变体或含 `_` *)
  | SBlock of stmt list * pos
    (* 透明块（v3.11）：仅作 parser 脱糖容器（let x = match ... 的合成语句
       序列），typecheck 平铺进当前块，不引入新作用域 *)

(* match 模式（v3.9） *)
and mpat =
  | PWild                                   (* _：匹配一切 *)
  | PLit of expr                            (* 字面量/表达式模式：按 == 比较 *)
  | PVar of string * string list * pos      (* 枚举变体：变体路径名, 载荷绑定名 *)

and marm = { mpat : mpat; mbody : block; mpos : pos }

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

(* extern "C" 块内的单个 C 函数声明。
   eabi：调用约定（"C"/"stdcall"/"fastcall"/"vectorcall"/"thiscall"）；
   evarargs：参数列表以 ... 结尾（调用点可传任意多个标量/string/指针实参） *)
type extern_fn =
  { ename : string; eparams : param list; eret : ty; erfrac : bool; epos : pos;
    eabi : string; evarargs : bool }

(* struct 字段：类型 名字 [= 默认值]；类型可为标量/T[N]/T[]/其他 struct。
   fbits：位域宽度（`u8 a : 3` 的 3；None = 普通字段）。位域仅限标量整型字段 *)
type sfield =
  { fname : string; fty : ty; fseq : pseq_kind; fdefault : expr option;
    fpos : pos; fbits : int option }

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
             runred : bool; body : block; pos : pos; tparams : string list;
             tcons : string list;
             fexport : string option;  (* export "sym"：导出符号名（no_mangle） *)
             fsection : string option; (* section "seg"：链接段 *)
             finternal : bool }        (* internal：不导出（LLVM internal 链接性） *)
    (* fn 前缀函数（new.md 2026-10-10）：fn (类型)? (frac)? (const)? (unred)? 名(参数)；
       ret=None 仅限 main（隐含 i32，return 可省）；runred：返回类型带 unred
       （返回值不做 frac 归一）；tparams：泛型类型参数（fn <T, U> ...），空 = 普通；
       tcons：与 tparams 等长的约束列表（"num"/"cmp"/"any"，v3.15） *)
  | IStruct of { name : string; packed : bool; fields : sfield list; pos : pos;
                 tparams : string list; tcons : string list;
                 methods : smethod list;
                 is_union : bool }         (* union：全部字段共享偏移 0 *)
    (* tparams：泛型类型参数（struct Box<T, U>），空 = 普通 struct；tcons 同 IFn *)
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
  | IIf of { name : string; methods : (ty option * string * param list * pos) list;
             parent : string option;
             tparams : (string * string) list;
             defaults : (string * param list * ty option * block * pos) list;
             pos : pos }
    (* interface 接口（v3.13）：缩进块内每行一个方法签名 fn ret? 名(参数)——
       struct 方法同名同签名（除 self）即隐式实现。
       继承（v3.20）：interface A: B——A 的方法表 = B 的方法 @ A 自己。
       泛型接口（v3.34）：tparams <> [] 时为模板（方法签名可引用类型参数），
       经 TApp（Store<i32>）/构造点推断实例化，单态化为 iface$<名>$<tags>。
       默认实现（v3.20）：签名后跟缩进块体——struct 未实现该方法时按
       实现者合成（self 指向实现 struct，self.m2 静态分派）。
       接口类型 = struct iface$<名> { ptr data; ptr vt }（vtable 分派） *)
  | IEnum of { name : string; variants : (string * ty list) list; pos : pos }
    (* enum 枚举与和类型（v3.9）：enum 名 { 变体, 变体(载荷类型...), ... }——
       简单枚举 = 全部变体零载荷；统一编译为 struct enum$<名>
       { i32 tag; 载荷字段并集 f0..fn }，变体序号即 tag；
       变体构造 `名.变体(实参)` = struct 构造；判别/解构用 match（§23） *)
  | IPub of item * pos
    (* pub 修饰：仅模块内顶层合法（root 顶层 pub 被 resolve 忽略） *)

type program = item list
