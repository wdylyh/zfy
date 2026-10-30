# zfy 语言规范（v3.32.0，2026-10-30）

> 本规范只描述当前语法。旧语法一律删除、不再保留历史版本描述。
> 适用编译器：`compiler/_build/zfyc.exe` 当前构建。

## 0. 30 秒上手

```
fn main()
    let string name = "zfy"
    let i32 n = 42
    output("hello, ", name, " ", n, "\n")
```

- 块用**缩进**（不是花括号），语句结尾**没有分号**。
- 声明以 `let` 开头，函数以 `fn` 开头。
- 编译运行：`zfyc build 程序.zfy` 生成 `程序.exe`。

## 1. 词法规则

- **缩进**：块 = 相对缩进增加；块结束 = 缩进回落。
  - 缩进宽度按**字符数**计：1 个空格 = 1，1 个 Tab = **1**。
  - **禁止 Tab 与空格混用**（同一块内混用报 `inconsistent indentation`）。
    建议统一用 4 空格。
  - 括号 `(...)` / `[...]` 内的换行被忽略（可自由折行）。
  - **行尾自动续行**：行尾是二元运算符（`+ - * / % ** == != < <=
    > >= & | ~ << >> xor`）、复合赋值（`+= -= *= /= %=`）、`,`、`.`、`::`、
    `and`/`or`/`not` 时，下一行自动并入当前表达式——无需括号，续行行缩进
    任意（不参与块判定）。注意 `??` 与 `?` 行尾**不**续行（行尾 `??` 是
    解包块语法、`expr?` 是传播，均为合法完结）。
  - `use a::b::{...}` 分组花括号内同样可折行，组内允许尾逗号。
- **注释**：
  - `// 行注释`（到行尾；**行注释内可以写中文**）。
  - `/* 块注释 */`，**可嵌套** `/* a /* b */ c */`；块注释内同样可写中文。
  - 注意：不是 `(* ... *)`（Pascal 风格写法不是注释，会报错）。
- **标识符**：`[A-Za-z_][A-Za-z0-9_]*`，区分大小写。
- **数字**：`123`、`0x1A`、`0b1010`、`1.5`、`1e-3`。
  超出 i64 的十进制字面量只能用于 i128/u128 上下文。
- **循环小数字面量**：`(前缀,循环节,)` —— 两个逗号包住循环节，前缀可为空：
  `(0.,1,)` = 0.111… = 1/9、`(0.3,4,)` = 0.3444…、`(0.,45,)` = 0.454545…、
  `(45.34,78,)` = 45.347878…。词法期即折算为分数 num/den，
  **与 `(n/d)` 分数字面量同语义**（见 §5）：frac 上下文按分数构造、
  浮点上下文按实数除法、整数上下文向零截断
  （恰好是"不四舍五入"截取）。总位数限 18 位，超长报错。
- **字符串**：双引号。转义：`\n \t \r \0 \a \b \f \v \\ \" \'`。
  串内禁止裸换行（要换行就写 `\n`）。
- **字符**：单引号**单个**字符，同一转义集（`'\n'`、`','`）。
- **运算符**：`== != <= >= += -= *= /= %= ++ -- => -> ??` 与单字符
  `( ) [ ] { } , ; : = + - * & / % < > . ? ! ^`。
  - 解引用是 `p^`（不是 `p*`）。
  - 错误传播是 `e?`。
- **分号**：语句位置非法（写了报错）；仅空语句占位可用。

## 2. 关键字（57 个）

```
if else while for return true false pub mod use break continue
const frac unred reduce and or not xor output input cast array list
remove import as sep end delim fail panic err struct packed move copy
union export section internal
borrow ref null unsafe extern type enum match interface ui shared let fn in asm
```

- `array`/`list`：保留用于报错提示，**不能当标识符**。
- `sep`/`end`/`delim`：output/input 的命名参数名。
- `err`：`??` 块内的错误值绑定名。
- `xor`：二元异或运算符。**`^` 不是异或**——它只作后缀解引用。
- `asm`：内联汇编语句（v3.31，见 §15.1；须写在 `unsafe` 块内）。
- `in`：asm 命名实参 `in=` 的关键字写法（§15.1），因此**不能当标识符**。
- `union`：union 声明（§7.1）；`export`/`section`/`internal`：函数符号属性
  前缀（§7.3，可叠加在 `fn`/`pub fn` 前）。

## 3. 类型系统

- **整数**：`i8 i16 i32 i64 i128`（有符号）、`u8 u16 u32 u64 u128`（无符号）。
- **浮点**：`f16 f32 f64 f128`。
- **其他标量**：`bool char string void`。
- **分数**：`frac` —— `let i32 frac f = (1/4)`。宽度即底层整型宽度
  （`i32 frac`、`f64 frac` 等；`frac` 单写 = `i32 frac`）。
- **错误值**：`T!`（如 `i32!`）—— 可能失败的操作类型（见 §11）；
  可作数组/列表元素（`let i32! xs[]`），128 位整数同样可包装（`let i128! n`）。
- **指针**：`T*`；指向 const 的指针 `T* const`。解引用 `p^`。
  指针算术与 `p[i]` 必须在 `unsafe` 块内。
- **数组/列表**（类型后缀与名字后缀两种写法等价）：
  - `T[N]` ≡ `T name[N]`：定长数组（N 为编译期常量：字面量、const 整数
    变量及其常量折叠表达式——`**`、abs、位运算均可折叠）。
  - `T[]` ≡ `T name[]`：动态列表。
  - 可叠加：`T[3][4]` 定长二维、`T[][]` 列表的列表。
- **函数类型**：`T(参数类型列表)`，如 `i32(i32)`。
  只允许出现在 `type` 别名、函数参数位、struct 字段位。
- **泛型实例化**：`Box<i32>`（泛型 struct，见 §7）；类型实参支持 `T!`
  （如 `Box<i32!>`，§25）。
- **模块路径类型**：`m::Point`。
- **type 别名**：`type I32Fn = i32(i32)`（顶层项）。
- **文件句柄**：`File`（move-only，见 §14）。

**宽度转换规则**：整数→整数同符号宽化自动、窄化/跨符号必须显式 `cast`；
浮点↔整数必须显式 `cast`；char 参与算术自动提升为 i32。

## 4. let 声明

```
标量：let [TYPE] [frac] [const] [unred] 名字 [= 初值]
数组：let TYPE [frac] [const] [unred] 名字[长度] [= 值1, 值2, ...]
列表：let TYPE [frac] [const] [unred] 名字[]      [= 值1, 值2, ...]
```

**修饰符固定顺序：类型 → frac → const → unred**。写错顺序报错并提示。
`let const Outer o`（const 抢在类型前）同样报错——类型必须紧跟 let。

- **类型与初值二选一或都写，不能都没有**：
  - 都写：`let i32 n = 5`
  - 只有类型：零值初始化（`0 / 0.0 / false / '\0' / "" / 分数 0/1`）
    —— `let string s`（空串）、`let i32[2][3] m`（全零二维）合法。
  - 只有初值：由初值推断——整数字面量→`i32`、浮点字面量→`f64`、
    `(n/d)` 分数字面量→`i32 frac`、string/char/bool 按字面量；
    **其他表达式报 E3000**（如 `let x = (1/4) + (1/4)` ✗，写 `let i32 x = ...`）。
- **`let frac f = (1/4)` 合法**（frac 视同给出类型），但初值必须是可直接推断的
  字面量；复合表达式请显式写宽度：`let i32 frac f = ...`。
- `const` 必须带初值；const 深不可变（struct 字段/数组元素也不可写）。
- `unred` 必须有 `frac` 修饰或 `(n/d)` 分数字面量初值（unred = 不自动约分）。
- `ref` 只能用于函数参数（§6）。
- **一行多声明器**：`let i32 a, b = 1`（a 零值 b=1）、
  `let string a[], b[]`、`let i32 arr1[3], arr2[2] = 7, 8`。
  带 `= 初值` 的数组/列表声明器须为该行最后一个。顶层与 for 头部单声明器。
- 顶层 `let` = 全局变量（非 const 也可赋值）；`let i32 frac const g = (3/4)`
  这类顶层 const frac 合法。

## 5. ⚠️ 分数字面量 (n/d) 与 frac 运算（重要规则，v3.29 语义反转）

**`(n/d)`（括号包住的两个整数字面量除式）才是分数字面量**；不带括号的
`n/d` 在任何上下文都是**普通除法**（整数除法语义）。

**frac 目标（frac 变量声明/赋值/复合赋值、frac 函数 return、frac 参数实参、
frac 序列元素）的初值/右值如果是四则表达式（`+ - * /` 与一元负号），整棵
表达式按分数计算**——表达式内的 `(n/d)` 按分数精确构造（不执行除法）、
普通整数字面量按 `n/1` 参与、**裸 `n/d` 按分数除法执行**（`1/4` =
`1/1 ÷ 4/1` = `1/4`，嵌在 frac 算术树内结果天然正确）、浮点字面量按其
二进制精确值转分数（如 `0.5 → 1/2`），结果约分后存入：

```
let i32 frac a = (1/4)         # ✓ a = 1/4（分数字面量，精确构造）
let i32 frac b = (1/4) + (1/4) # ✓ b = 1/2
let i32 frac c = 1/4 + (1/4)   # ✓ c = 1/2（裸 1/4 是分数除法 1/1÷4/1）
let i32 frac d = (1/4) + 0.5   # ✓ d = 3/4（0.5 精确转 1/2）
c = c + c                      # 1/2 + 1/2 = 1/1
let i32 frac e = (1/3)
e += (1/6)                     # ✓ e = 1/2
```

**裸 `n/d` 直接落在 frac 目标顶层报错**（如 `let i32 frac a = 1/4` ✗），
错误提示改写为 `(n/d)`；嵌在更大 frac 算术树内不报错（如上 `1/4 + (1/4)`）。

**无 frac 修饰的目标**：`(n/d)` 的语义由期望类型决定——

- 整数期望：截断整除（`let i32 x = (7/2)` = 3，`let i64 r = (1/4)` = 0）
- 浮点期望：实数除（`let f64 x = (1/4)` = 0.25）
- 无期望推断：`i32 frac`（`let f = (1/4)` → f = 1/4；`output((1/4))` 打印 `1/4`）

`let f64 x = 1/4 + 1/4` 按浮点除法算（纯字面量树整树浮点，= 0.5），
`let i32 x = 7/2` 仍是整数除法（= 3）——裸 `n/d` 处处是除法语义。
`(n/d)` 配 `unred` 保留原分子分母（`let i32 frac unred u = (6/48)` →
u = 6/48）；默认存储自动约分为 1/8。
frac 变量间的 `+ - * /` 是分数运算；非 unred 存储位自动约分。
`return (1/4)`（frac 函数）、`f = 5`（f 为 frac 变量）等"整数面值落 frac
位"自动提升为分数（`5 → 5/1`）——均合法。
循环小数字面量 `(前缀,循节,)` 与 `(n/d)` 同语义（§1）。

## 6. 函数

```
fn [TYPE|void] [frac] [unred] 名字(参数列表) 缩进块
fn <T, U> [TYPE|void] [frac] [unred] 名字(参数列表) 缩进块    # 泛型
fn main() 缩进块                                             # 入口特例
```

- **main 特例**：必须写 `fn main()`（括号必须有）；不给返回类型（隐含 i32）、
  不给参数；`return` 可省（隐式返回 0），裸 `return` ≡ `return 0`
  （任意嵌套深度的 if/循环/块内同样生效）；
  `return n` 的 n 成为进程退出码（0-255）。
- 非 main 函数**返回类型必写**（void 或类型）。返回类型不支持 const/unred。
- **参数一律 let 形式**：
  ```
  (ref)? let [TYPE] [frac] [const] [unred] 名字
  ```
  - 类型可省须有 frac：`fn f(let frac y)` ≡ `fn f(let i32 frac y)`。
  - 数组/列表参数：`let i32 xs[3]` / `let i32 xs[]` /
    类型后缀 `let i32[] xs` 等价。
  - 函数类型参数：`let i32(i32) g`。
  - **ref 参数**：`ref let i32 n`（ref 在 let 前）。标量/string/数组/列表均可
    ref；列表 ref 使 `push(xs, v)`、`xs[i] = v` 直接作用于调用方列表。
    **ref 不支持 frac**。
- 实参传入时非 unred frac 参数自动约分（对参数副本，调用方不变）。
- 返回 `T[]`/`T[N]`（序列）= 所有权移交免克隆。

## 7. struct

```
struct [packed] 名字<T, U>? 缩进块
    字段：TYPE 名字 [= 默认值]
    字段：TYPE 名字[N]        # 数组字段，不可有默认值
    字段：TYPE 名字[]         # 列表字段，不可有默认值
    字段可为指针（自引用）/函数类型/嵌套数组/另一个 struct
    方法：fn 返回类型? 方法名(参数) 缩进块
```

- 实例化：`Point(1, 2)` 位置 / `Point(x=1)` 命名（**struct 构造支持命名实参**，
  未给字段用默认值再退零值） / `Point p`（裸声明全默认）。
- 泛型：`struct Box<T>  T v` → `let Box<i32> b = Box(v=9)`；
  约束见 §28：`struct Pct<T: num>`。
- struct 作数组/列表元素：值语义深拷贝；`ps[i].x = v` 直接改元素；
  const 深不可变同样生效。
- `sizeof(T)` / `alignof(T)` 编译期内建。

**方法**：struct 块内用 `fn` 声明，隐式首参 `self` = 接收者的
引用（方法可改调用方状态）：

```
struct Counter
    i32 n = 0
    fn void bump()
        self.n += 1
    fn i32 get()
        return self.n
```

- 调用：`c.bump()` / `c.get()` / `c.add(6)`——接收者自动按 `ref` 传，
  等价于自由函数 `Counter__bump(ref c)`。
- **元素接收者**：`arr[i].m(...)` / `self.list[i].m(...)` 合法——
  接收者取元素地址（写方法原地改元素）；配合元素字段复合赋值
  `self.arr[i].field++`（取址后按解引用复合赋值）。
- 方法体内字段用 `self.字段`；调兄弟方法写 `self.其他方法(...)`。
- **const 接收者调方法报错**（方法可能改状态）；方法不支持命名实参；
  方法名不能是关键字（`float`/`int` 等不行，换 `uniform` 这类名字）。
- 方法调用与字段访问不冲突：`rng.s0` 是字段，`rng.next_u64()` 是方法。
- 跨文件 use 导入 struct 后方法照常可用（`mod util; use util::Helper`
  → `h.next_u64()`）。
- **泛型 struct 方法**见 §28.2。

### 7.1 union（v3.32）

```
union Value
    i32 i
    f32 f
    u8 b
```

- 所有字段**共享偏移 0**；无绑定标签（读哪个字段由程序员负责，安全语义
  与 C union 一致：写入一个字段后读另一个字段得到"位型重解释"）。
- `sizeof(U)` = 最大字段大小（按最大对齐向上取整，至少 1 字节）；
  `alignof(U)` = 最大字段对齐。
- 字段类型限**标量或指针**（整数/浮点/bool/char/string/指针/函数指针）；
  嵌套 struct/数组/列表/frac/T! 字段报错（需要时用指针字段 + 显式转换）。
- 构造：位置形式 `Value(5)` = 初始化第一字段；命名形式 `Value(i=5)`。
  **一次只能初始化一个字段**（多个非零字段报错）；未初始化字段保持零。
- 值语义：赋值/传参/`copy` 一律整体 memcpy（副本独立，不做深拷贝——
  union 内不存 string 之外的所有权资源；string 字段请自行管理）。
- 只能声明字段，不能有方法。

### 7.2 位域（v3.32；布局与 C（MSVC x64）一致）

```
struct Flags
    u8 lo: 3
    u8 mid: 4
    i8 sgn: 4

struct packed P
    u8 a: 3
    u32 b: 5
```

- 语法 `TYPE 名字: N`：普通 struct 与 `struct packed` 内都允许（union 内
  报错）；`TYPE` 必须是整数类型，`N` 为编译期整数字面量且
  `1 ≤ N ≤ 位宽`。
- **存储单元分配（Microsoft C 位域规则）**：按字段声明序逐字段处理，
  维护"当前存储单元"（起点偏移、单元宽 = 声明类型宽度、已用位数）：
  - 位域紧邻塞入当前单元：声明类型与当前单元相同、且剩余位放得下 `N`
    位时共享单元；否则换新单元（新起点 = 当前偏移按单元对齐后取整）。
  - 声明类型宽度不同（如 `u8` 位域后接 `u32` 位域）即换新单元。
  - 普通字段**结束**当前位域单元，按自身对齐另起位置（可与位域交错，
    例如 `u8 a:3; i32 b; u8 c:5` 中 b 对齐到 4、c 另起单元）。
  - 对齐：非 packed 时新单元按声明类型自然对齐（结构对齐 = 各单元/普通
    字段对齐的最大值）；packed 时单元按 **1 字节**对齐（等价
    `#pragma pack(1)`，结构对齐 = 1），单元内部宽度不变。
  - 零宽位域（C 的 `u8 : 0` 强制换下一单元）**本语法不支持**：字段必须
    有名字、宽度 ≥ 1。
- 读写一律生成**显式掩码代码**（读：无符号按 `& (2^N-1)`、有符号先左移
  再算术右移做符号扩展；写：read-modify-write 清位后置入低 N 位）。
  普通代码即可使用，**不必包 `unsafe`**（与 C 位域不同，没有指针访问）。
- 取位域地址（`&f.lo`）报错；位域字段不能有默认值，也不能用于
  `sizeof` 字段偏移。
- `sizeof`/`alignof` 返回与 C 一致的值。实测对照（clang 18.1.8
  `-mms-bitfields`，packed 用 `#pragma pack(1)`）：
  `{u8 a:3}` = 1/1；`{u8 a:5, u8 b:4}` = 2/1；`{u16 a:4, u32 b:5, u8 c:3}`
  = 12/4；`{u8 a:3, i32 b, u8 c:5}` = 12/4；`{u32 a:20, u32 b:12}` = 4/4；
  `{u32 a:32, u8 b:1}` = 8/4；packed `{u8 a:3, u32 b:5, u16 c:4}` = 7/1、
  `{u8 a:3, u32 b, u8 c:5}` = 6/1。内存映像（字段/未用位/填充字节全零）
  与 C 逐字节一致。

### 7.3 符号属性（export / section / internal，v3.32）

```
export "zfy_exported_add" fn i32 add_impl(let i32 a, let i32 b)
internal fn i32 hidden_double(let i32 x)
section "zfy_init" fn i32 in_init(let i32 x)
```

- `export "sym"`：给函数额外导出符号名为 `sym`（同 C 的
  `__attribute__((alias))`）——zfy 内部调用仍用原函数名，链接方按 `sym`
  引用（相当于 `#[no_mangle]` + 指定导出名）。
- `section "seg"`：函数落在指定链接段（等价 GCC `__attribute__((section))`）。
- `internal`：符号不导出（`internal` 链接性，仅供本模块使用）。
- 三者可叠加、顺序任意，**只能作用于顶层函数**（struct 字段/方法报错）。
- `export`/`section` 须跟字符串字面量，否则报错。

## 8. 语句全集

| 语句 | 语法与要点 |
|---|---|
| 赋值 | `lhs = rhs`；序列整体赋值 `a = 1, 2, 3`（目标为数组/列表槽） |
| 复合赋值 | `+= -= *= /= %=`（string 的 `+=` 为追加，rhs 可 string 或 char） |
| 自增/自减 | `i++` / `i--` |
| 条件 | `if cond 缩进块` / `else` / `else if`；**单语句可同行**：`if a > 0  output("pos")`（条件后空格+语句） |
| while | `while cond 缩进块` |
| for | `for 段1, 段2, ... 缩进块`（见下）；for-in 见 §19.3 |
| 返回 | `return` / `return expr` |
| break/continue | `break` / `continue` |
| 输出 | `output(v1, v2, ..., sep=?, end=?)`（见 §13） |
| 输入 | `input(目标..., delim=?)`（见 §13） |
| unsafe | `unsafe 缩进块`（指针算术、p[i]、p^ 必须在其中） |
| asm | `asm("模板", out=变量, in=变量, clobber="r1,r2,memory")`（内联汇编，**须在 unsafe 内**，见 §15.1） |
| volatile | `volatile_load(p)` / `volatile_store(p, v)` 内建调用（§15.2） |
| reduce | `reduce(frac变量, 次数, 起始除数)` |
| `remove` | `remove(名, 下标)`：**表达式**，返回被删元素副本（见 §12） |
| match | `match scrut 缩进块`（见 §23） |

**for 头部规则**：
```
for let i32 i = 0, i < 10, i++   # 初始化, 条件, 更新 —— 三段
for k < 3, k++                   # 条件, 更新（k 在头部前声明）
for let i32 i = 0, i++           # 初始化, 更新（条件省略=恒真，配 break 用）
```
- 段按形状分类：`let` 声明→初始化；赋值/复合赋值/`++`/`--`→更新；
  布尔表达式→条件（多项自动 and 连接）；孤立变量名→初始化（执行一次）。
- **更新段不可省**——缺失报编译错误（否则条件永不变化死循环）。
  无更新就把更新写进块内或改用 while。
- for 头部声明的变量在循环所在的整个块可见（循环结束后可复用）。

## 9. 表达式与运算符（优先级低 → 高）

```
??          a ?? 默认值（值形式）；见下"块形式"
or / and    短路逻辑
not         一元；比较高于 not：not x == 1 即 not (x == 1)
== !=       不结合
< > <= >=   不结合
<< >>       左结合（移位，C 语义；有符号右移=算术移位）
+ -         左结合
* / %       左结合
**          幂：右结合 x**2**3 == x**(2**3)；高于乘除；
            数学优先级——一元负号在底数左侧绑定更松：-x**2 == -(x**2)；
            整数底数负指数 = 0；整数溢出回绕；128 位整数支持
一元 -e、&e、~e（按位取反，仅整数/char）、|e| 绝对值
            （脱糖为内建 abs(e)，整数同宽/浮点同宽；字面量树按
            外层期望落型）；内层表达式解析到 & 层
            为止——按位或作被绝对值须加括号 |(a | b)|，嵌套 ||x|| 合法）
== != 之后的位运算链（左结合，与 C 一致地低于比较）：
&           位与（x & 1 == 1 会解析成 x & (1 == 1)，必须写 (x & 1) == 1）
xor         位异或（关键字；^ 是解引用后缀不是异或）
|           位或
后缀：调用 f(args)、下标 a[i]、切片 s[a,b] / s[a,b:step]、
     字段/命名空间 a.b、错误传播 e?、解引用 p^
```

- **移位/位运算仅整数（char 提升 i32）**；`x << k` / `x >> k` 的 k 会被
  coerce 到左操作数类型（变量移位量建议直接用同宽类型，避免窄化报错）。
- **移位量越界 = 运行期 panic**（默认检查模式）：`k < 0` 或 `k >= 位宽`
  抛 panic"shift overflow"（**已被 `try()` 捕获**）；不再有 LLVM poison/
  未定义行为。`--wrap-overflow` 模式下恢复旧语义（按硬件行为移位）。

- **`??` 值形式**：`let i32 v = 可能失败 ?? 默认值`。
- **`??` 块形式**：`??` 后**直接换行 + 缩进块**（不是 `?? +`！）：
  ```
  let i32 v = ev ??
      output("failed: ", err.code, " ", err.msg, "\n")
      -1
  ```
  块内 `err.code`（i32）、`err.msg`（string）可用；块末值为结果。
  合法位置：声明初值 / 赋值右值 / `return ev ?? ...块`。
- **切片**：`s[a, b]` 闭区间（两端含）；步长用**冒号** `s[a, b:step]`。
  `s[a, b, step]`（逗号步长）**不存在**，写了报错提示。
  步长为 0 编译期拒绝（字面量）或运行期 panic（变量）。
  **负步长 = 反向切片**：`s[4, 0:-1]` 从下标 4 倒着取到 0（含），
  `arr[4, 0:-2]` 反向隔一取一。负步长要求起始下标 a ≥ 当前长度不越界、
  b ≥ 0 且 a ≥ b，否则运行期 panic"切片区间越界"。
- **没有 `a..b` 区间语法**（写了报 E2042 提示逗号切片）。
- **比较**：string 与 string/char 六种比较全支持（字典序，char 提升
  单字符 string）；`"a" == 'a'` ✓。char 间**六种比较全支持**
  （按码点序比较）。
- **拼接 `+`**：string + string；char 侧自动提升单字符 string
  （`s + 'c'` / `'c' + s` 均可）。`s += v` 的 v 同样支持 char。
- **实参修饰**（用户函数调用）：
  - `f(move x)` 所有权移交（string/数组/列表；此后源变量不可用）；
  - `f(copy x)` 显式深拷贝；`f(ref y)` 传引用。
  - ⚠️ **用户函数不支持命名实参** `f(x=1)`（E3068）——命名实参只存在于
    **内建函数**（`find(..., count=k)`、`output(..., sep=/end=)`、
    `input(..., delim=)`）与 **struct 构造**（`Point(x=1)`）。
- **字面量实参**：期望 frac 的位置 `(n/d)` 字面量按分数构造
  （`addf((1/4), (1/4))` = 1/2）；裸 `n/d` 落 frac 实参报错（§5）；
  期望 string 的位置 char 自动提升。
- 主表达式：字面量、`true`/`false`/`null`、`err`（?? 块内）、
  `fail(code, msg)`、`panic(...)`、`cast(e, T)`（**目标类型在后**）、
  lambda（§20）、match 初始化（§23.3）、标识符（可 `m::x`）、括号。

## 10. 顶层项

| 项 | 语法 |
|---|---|
| 函数 | `fn ...`（§6） |
| struct | `struct [packed] 名<T,U>? 块`（§7） |
| interface | `interface 名 块`（§27） |
| enum | `enum 名 块`（§22） |
| type 别名 | `type 名 = 类型` |
| 全局声明 | `let ...`（§4，无数量限制） |
| 模块（文件） | `mod 名字;` —— body 在 `名字.zfy` 或 `名字/mod.zfy` |
| 模块（内联） | `mod 名字` + 缩进块（块内为顶层项，可嵌套） |
| 导出 | `pub` 修饰任意顶层项（模块内合法；root 顶层 pub 容忍并告警） |
| use | `use a::b::item [as x]`；分组 `use a::b::{x, y as z}`（花括号内可折行、允许尾逗号）；整模块 `use a::b [as m]`；单段整模块 `use 模块名 [as 别名]`（成员以 `别名.成员名` 访问，仅 pub 可见）；分组/路径 use 的**首段无本地 mod 声明时自动按 `mod 首段;` 处理**（查本目录与父链 stdlib——显式 mod 优先，无需重复声明） |
| extern | `extern "C"`（或 `"stdcall"` / `"fastcall"` / `"vectorcall"` / `"thiscall"`）+ 缩进块；**每行：`返回类型 [frac] 名(参数)`——返回类型是旧式直接写类型（不加 let），参数是 let 形式**：<br>`i64 strlen(let string s)` ✓、`let i64 strlen(...)` ✗。<br>**变参**：形参表尾写 `...`——`i32 printf(let string fmt, ...)`；调用点可传任意多标量/string/指针实参（i8/i16/i32/bool/char 默认提升 i32，f16/f32 提升 double），struct/列表/数组/frac/`T!` 按值传报错。<br>**序列返回**：允许 `T[]` / `T*` 返回（unsafe 语义：C 侧缓冲区直接交给 zfy，生命周期归调用方/需自行释放）。<br>非法 ABI 名编译期报错（E2031）。 |

内联模块示例：

```
mod mathx
    pub fn i64 sq(let i64 v)
        return v * v
    pub let i64 seed = 7

fn main()
    output(mathx.sq(6), "|", mathx.seed, "\n")
```

## 11. ZEM 错误值

- 类型 `T!`；面值自动包装为成功值。
- `fail(code, msg)` 构造错误值；code 为 `ErrCode.*` 或 ≥100 的字面量。
- `e ?? 默认` / `??` 块（§9）；`e?` 传播——函数返回类型必须显式 `T!`。
- **ErrCode 全表**：`OK=0 DIV_ZERO=1 OOB=2 NOT_FOUND=3 IO=4 CAST=5 INPUT=6
  EOF=7 CUSTOM=100`。
- `panic(msg)` / `panic(code, msg)`；`panic_handler(f)` 注册处理函数
  （f 签名 `fn void f(let i32 code, let string msg)`；panic 后进程仍 exit 101）。
- 除零（frac）、下标越界、input EOF、cast 失败等运行期错误走 panic 通道
  （exit 101），不可被 `?`/`??` 捕获；**整数除零是硬件异常**（也不可捕获）。
- **panic 带位置**：未注册 handler 时 panic 输出末尾追加
  `  at 源文件:行号`（指向触发语句所在行，含 runtime 内部触发的越界等）；
  注册 panic_handler 后由用户函数全权接管，不再打印位置。
- 产 `T!` 的内建：`find`、`cast`（string→数值，含 i128/u128）、
  `input`（T! 目标）、`open`/`read_all`/`read_line`/`read_file`（§14）、
  `os_env`（§26）、`chan_recv`（§21.4）。
- **T! 作数组/列表元素**：`let i32! xs[] = 1, fail(3, "m")` 合法；
  元素按聚合存储（i32!/i64!/f64! 24 字节、i128!/u128! 32 字节），
  读取 `xs[i]` 得 `T!`、用 `??` 解包；push/切片/整体拷贝均支持。
  **T! 复合赋值**：`xs[i] op= v` / `e op= v`（T! 变量）合法——错误值保持
  错误不变，成功值取值参与运算后重新包装写回；T! string 元素仅支持 `+=`。
  **T! 整体 output**：`output(e)` 合法——成功打印元素值，失败打印
  `err#<code>`；T! 作列表叶元素打印不支持（先 `??` 解包）。
- **T! 作 struct 字段**：合法（`struct Box<T>` 实例化为 `Box<i32!>` 后
  字段即 i32! 聚合）；字段读写/整体赋值按 24/32 字节聚合语义。
- **128 位整数支持 `T!` 包装**：`let i128! n`、`cast(s, i128)` 失败
  产错误值，`input` 到 `i128!`/`u128!` 目标同样产错误值。

## 12. 内建函数

**函数式**（返回值）：

| 函数 | 说明 |
|---|---|
| `length(x)` | string=字节数；数组/列表=元素数。**返回 i32**（落 i64 槽自动宽化） |
| `find(s, x[, count=k])` | x 为 char 查字符、string 查**子串**；返回第 k 次出现的字节下标（**`i32!`**）；k 从 1 起，<1 编译期拒绝（字面量）或运行期 panic（变量）；找不到 = NOT_FOUND 错误值 |
| `trim(s, x)` | **删除 s 中所有出现的 x**（x 为 char 或 string）——不是去两端空白！ |
| `split(s, x)` | 按分隔符切分返回 `string[]`（x 为 char 或 string）；空段保留；分隔符 `'\0'` 编译期拒绝 |
| `replace(s, a, b, rep)` | 把 `s[a, b]` 闭区间替换为 rep；"替换到串尾"写 `b = length(s) - 1` |
| `prec(v, n)` | 格式化为总宽 n（string 按**码点数**截断/右补空格；数值转 string 后同理） |
| `utf8_len(s)` | 码点数（`length` 仍按字节）。**返回 i32** |
| `utf8_char_at(s, i)` | 第 i 个码点（0 起），返回单码点 string |
| `utf8_sub(s, a, b)` | 按码点闭区间切片 |
| `sizeof(T)` / `alignof(T)` | 编译期常量 |
| `cast(e, T)` | 显式转换（含 string→数值；失败产 `T!` 错误值，i128/u128 目标同样产错误值）。`cast(e, frac)` 支持——int/bool/char → n/1；float **字面量**按二进制精确转分数（0.5→1/2）；非字面量 float 拒绝 |
| `ord(c)` / `chr(n)` | char↔码值 |
| `sqrt(x)` | 平方根（实参 coerce 到 f64，返回 f64；下同） |
| `log(x)` / `exp(x)` | 自然对数 / e^x |
| `sin(x)` / `cos(x)` / `tan(x)` | 三角函数（弧度） |
| `pow(b, e)` | b^e（两参均 f64）。亦可写 **`b**e` 幂运算符**：整数走运行时快速幂（≤64 位；负指数=0；溢出回绕），任一侧为浮点/含浮点字面量则整树按浮点（f32 双侧走 powf）；**右结合** |
| `floor(x)` / `ceil(x)` | 向下/向上取整（返回 f64） |
| `abs(x)` | **重载**：整数→同宽整数（含 i128/u128，内联生成）；浮点→同宽浮点（f32 走 fabsf）。字面量实参树**延迟定型**：按外层期望落型（`let i32 a = |3|`、`let f32 c = |2.5|`、实参/返回上下文同理；无约束时整数 i64 / 浮点 f64）；`|e|` 运算符即本内建的语法糖 |
| `now()` | 当前 Unix 时间戳（秒，**i64**） |
| `tick_ms()` | 单调时钟毫秒数（**i64**，进程起点为 0；QPC/CLOCK_MONOTONIC，不受系统改时间影响，测代码段耗时：`let i64 el = tick_ms() - t0`） |
| `sleep_ms(ms)` | 阻塞 ms 毫秒（TVoid，可作裸语句；负值按 0） |
| `localtime(ts) -> datetime` | 时间戳拆解为本地时间。**datetime 为内建 struct**（8 字段全 i32）：`year month day hour minute second weekday yday`；weekday 0=周日..6=周六；yday 年内第几天 0 起 |
| `mktime(y,mo,d,h,mi,s)` | 反向构造时间戳（本地时区，**i64**）。各分量 i64 **允许越界**（32 日、13 月、-5 小时），由 mktime 归一化；日期算术直接在时间戳上加减秒即可。失败（越界到不可表示）返回 -1 |
| `os_args()` | 命令行参数 `list<string>`（§26） |
| `os_env(s)` | 环境变量读取，产 `string!`（§26） |
| `assert_eq(a, b)` | 断言相等，不等 panic 带值（§26） |
| `startswith(s, p)` / `endswith(s, p)` | 前缀/后缀判定 -> bool（§24） |
| `contains(s, x)` | string 子串包含 -> bool（与容器键包含共用名，按实参类型分流） |
| `substr(s, start, len)` | 字节区间 [start, start+len) 深拷贝；负 start 前移、越界截断（§24） |
| `to_str(v)` | 标量/bool/char/frac 显式转串（§24） |
| `format(fmt, args)` | 把 `list<string>` 元素逐个替换 `{}` 占位；占位多于实参 = 剩余 `{}` 原样保留（§24） |

**数学内建说明**：直接落到 libm 符号（`@sqrt` `@log` `@fabs` 等）；
`abs` 与 C 的 32 位 `abs` 无关，i128/u128 正确。

**低层内建指引**：原子操作与内存序见 §21.2；`volatile` 内存访问见 §15.2；
内联汇编 `asm` 见 §15.1。

**表达式化的序列操作**：
- `push(列表, 值)`（**恰两参**；目标是列表非定长数组；嵌套列表
  `push(ll, row)` 的 row 须是列表变量/表达式，**不能 push 标量进列表的列表**）
  ——**返回列表本身**：惯用 `xs = push(xs, v)` / `bag.xs = push(bag.xs, v)`
  （同槽赋值零拷贝）。
- `remove(名, 下标)`——**返回被删元素的深拷贝副本**（数组=槽位填零长度不变、
  列表=删除并左移长度-1）：`let i32 v = remove(xs, 0)`；不需要返回值时
  赋给丢弃变量（`let i32 dropped = remove(xs, 0)`）。
- `reduce(x, n, 起始除数)` 保持语句形式。
- **裸语句丢弃值一律报错**（E3189）：push/remove/find/length/cast 等产值内建
  与用户函数的返回值不能裸写成一句（`push(xs, 1)` ✗ → `xs = push(xs, 1)` ✓）。
  例外：`fail(...)`/`panic(...)`（非局部退出）；`??` 解包块内不受限
  （块末兜底值表达式即块值）。

**string `+=`**：变量 `s += v`、元素 `parts[i] += v`、解引用 `p^ += v` 均支持；
v 为 string 或 char。

**string 是字节串**：`length("中文")` = 6（字节数）；按码点操作用 utf8_* 组。

### 12.1 内建随机：rand 系（v3.28，替代 stdlib/random）

随机为编译器内建（xoshiro256\*\* 引擎 + SplitMix64 播种，Lemire 无偏采样）。
`rand` / `rand.seed` / `rand.choice` / `rand.sample` / `rand.shuffle` 为保留
调用名。未 `rand.seed` 直接使用 → 自动以种子 0 播种（可复现）。

```
rand.seed(42)                  # 语句：设种子（整数）
rand(A, B)                     # 表达式：闭区间 [A, B] 内均匀取一
rand(S)                        # 表达式：串 S 内随机一个码点（返回 string）
rand.choice(N, num=K)          # 从 N 选 K 个（可重复），返回列表
rand.sample(N, num=K)          # 从 N 无放回抽 K 个（K>n 运行期 panic）
rand.shuffle(xs)               # 列表/数组变量：原地打乱（void）
rand.shuffle(v1, v2, ...)      # 多个同型值：返回打乱后的新列表
```

**rand(A, B) 类型规则**：A、B 必须同类型（整数可宽化统一；128 位整数不
支持）：

| A/B 类型 | 语义 |
|---|---|
| 整数（i/u 8..64） | 闭区间 [A, B]，含两端 |
| f32 / f64 | 浮点闭区间（混合字面量按 f64） |
| char | 按 ascii 码区间随机，返回 char |
| bool | 忽略 A、B 值，P(true) = 0.5 |
| frac（i8..i64/u8..u64 元素） | 区间内随机分数，自动约分 |
| string | 只有单参形态 `rand(S)`：随机一码点（返回 string，char 装不下多字节） |

**choice / sample / shuffle 规则**：
- `N` 可以是单个列表/数组，或多个同型标量值（多值自动打包临时列表）。
- 多值形态元素类型必须一致：数值实参统一宽化（混入浮点 → f64，全整数
  字面量 → i64）；非数值（string/bool/char/frac）要求完全一致，混型编译错。
- `num=K` 命名参数必填；K ≤ 0 字面量编译期拒绝（非字面量运行期 panic）。
- `sample` 无放回：K 大于元素个数 → 运行期 panic（索引池部分洗牌，源不动）。
- `choice` 可重复；源列表/数组不被修改。
- `shuffle` 单列表/数组变量（含数组）：data 原地重排；多值形态返回新列表。

```zfy
rand.seed(7)
let i64 n = rand(2, 5)             # 2..5
let f64 x = rand(1.5, 2.5)
let char c = rand('a', 'e')
let bool b = rand(false, true)
let i32 frac f = rand((1/2), (3/2))  # (n/d) 分数字面量 → frac 区间随机
let string ch = rand("AB中文")      # "A" / "B" / "中" / "文" 之一
let i32[] xs = 1, 2, 3
let i32[] cs = rand.choice(xs, num=4)
let i32[] sp = rand.sample(xs, num=2)
rand.shuffle(xs)                    # xs 原地打乱
let i64[] sh = rand.shuffle(4, 5, 6)
```

### 12.2 内建计时：timer 系 + time.sleep（v3.28，替代旧时间语义）

计时器为固定 4096 槽表（序号可不连续），单调钟（QPC）计时：

```
timer.add(x)        # 语句：登记第 x 号计时线程（0..4095，重登记即重置）
timer.remove(x)     # 语句：删除第 x 号线程（不存在 → panic）
timer(x, n, start)  # 语句：第 n 号线程从起始数 x（f64，秒）开始计时
timer(n, stop)      # 语句：冻结第 n 号线程当前值（未在计时则无事发生）
time.sleep(x)       # 语句：休眠 x 秒（f64，整数宽化）
timer.now(n)        # 表达式：第 n 号线程当前秒数（f64；线程不存在 → panic）
timer.now()         # 表达式：当前 Unix 时间戳（秒，i64）
```

`timer.now(n)` 返回 `base + 自 start 起的增量`；`stop` 后为冻结值；
再次 `start(x)` 将计数值重置为 x。

```zfy
timer.add(18)
timer(0.2, 18, start)    # 从 0.2 秒起计
time.sleep(0.15)
timer(18, stop)
let f64 e = timer.now(18)
let i64 ts = timer.now()   # Unix 秒
```

> 旧内建 `tick_ms / localtime / mktime / sleep_ms` 仍保留（见 §12 内建
> 函数表），但推荐用 timer 系。
## 13. output 与 input（行为详述）

**output**：
- `output(v1, v2, ..., sep=?, end=?)`；命名参数必须最后；`sep` 默认 `""`、
  `end` 默认 `"\n"`。
- 可打印：所有标量（整数各宽度/浮点/bool/char）、string、frac（打印 `n/d`）、
  数组/列表（整体按元素打印，元素间 sep）。
- 嵌套序列每层包 `[` `]`：`i32[2][3]` → `[[05][00][00]]`（整数定宽补零对齐）；
  叶元素须为可打印标量/string（**struct 叶不支持**）。
- 整数默认按十进制；i64 直接打印无问题。

**input**：
- `input(目标..., delim=?)`；delim 必须最后。
- 目标两种：**新声明** `input(let i32 n)`——类型必须显式（不可 `let n`）；
  **已有变量** `input(n)`。
- 读取规则：
  - **不给 delim**（字符集模式）：读一段，遇**空格或换行**结束（该字符消费掉）。
  - **给 delim**：读一段，遇到完整 delim 串结束（delim 消费掉）。
  - **多目标共用同一个 delim**：`input(a, b, delim=',')` 依次读
    `"a段,b段"`；最后一段读到 delim 或 EOF（EOF 时自动剥离行尾换行）。
  - 一个 input 读不满一行时，剩余部分留给下一个 input
    （`input(a, delim=',')` 读 "tom,x" 得 a="tom"，随后 `input(b)` 得 b="x"）。
  - EOF 且无输入 → panic（`input: EOF`）；T! 目标（`let i64! n`）则产
    INPUT 错误值不 panic。
- 整数目标按类型宽度解析（i32 目标写 4 字节，越界范围报错）。

## 14. File I/O

**所有声明必须用 let 形式**：

```
fn main()
    let i64! wn = write_file("a.txt", "line1\nline2\n")   # 覆盖写，返回字节数
    let File! fo = open("a.txt", "r")                     # mode 字面量限 "r" "w" "a"
    let File f = fo ?? panic("cannot open")
    let string! all = read_all(f)                         # 全文
    let string! l1 = read_line(f)                         # 一行（不含换行）；EOF 产 ErrCode.EOF
    close(f)                                              # 幂等
    let bool e = exists("a.txt")
    let string! rf = read_file("a.txt")                   # 一步式读
    output(all ?? "?", "|", l1 ?? "eof", "|", e, "|", rf ?? "?", "\n")
```

- `write(f, s)` / `writeln(f, s)`：写（失败 panic；实参自动转 string）。
- `File` 是 move-only 句柄：不可作 struct 字段/数组列表元素/泛型实参；
  `File g = f` = 所有权转移（源失效）；用户函数的 File 参数只能
  `f(move g)` 传；**作用域退出自动 close（RAII）**；已 close 句柄上操作
  → panic "use of closed file"。
- `File! fo = open(...)` 失败产 `ErrCode.IO` 错误值；
  `?? panic(...)` 解包合法（panic 任意 T! 均可）。

## 15. 运行期语义备忘

- 下标/切片越界（含负下标）→ panic（exit 101），无 Python 式负索引。
- **整数溢出默认检查（v3.32）**：`+ - *`、一元 `-`、`**`（整数底数）、
  移位量越界/负移位、整除/取余的除零、`INT_MIN / -1`、`|e|` 对 MIN 一律
  **运行期 panic**（可被 `try()` 捕获，`panic_msg()` 取消息；panic
  "integer add overflow" 等）。复合赋值 `+= -= *=`、`++`/`--`、for 更新段
  走同一路径；u8..u128 同样检查（无符号按无符号溢出位）。**浮点不受影响**
  （IEEE 语义不变）。
- 编译开关 `zfyc build --wrap-overflow`（别名 `-Wno-overflow-check`）：
  切回旧的**静默回绕**语义（`+ - *` `**` 移位不检查、溢出按位宽回绕）。
- **显式溢出内建**（永不 panic，任何模式下行为一致）：

  | 内建 | 语义 | 返回类型 |
  |---|---|---|
  | `wrapping_add(a, b)` / `wrapping_sub` / `wrapping_mul` | 回绕 | 与实参**同宽同类型** |
  | `wrapping_neg(a)` | 取负回绕 | 同上 |
  | `saturating_add` / `saturating_sub` / `saturating_mul` | 饱和到类型边界 | 同上 |
  | `checked_add` / `checked_sub` / `checked_mul` | 溢出返回错误值 | `T!`（成功 code=0，溢出 `ErrCode.OVERFLOW`=12） |

  实参须同为整数类型（宽度/符号不一致报错）；未定型字面量实参按默认型
  （`i64`）或外层期望定型——**观察 i32 回绕/饱和请传 i32 变量**。
  `checked_*` 的溢出走 `??` 兜底，不 panic：
  `let i32! c = checked_add(2147483647, 1) ?? -1`。
- **常量折叠溢出**：检查模式下编译期报错（`constant overflow in integer
  addition/subtraction/multiplication/division/negation`）；`--wrap-overflow`
  下按回绕折叠。
- `/` `%` 向零截断（`-7 / 2 = -3`）；**整数除零 = panic**（不再硬件异常，
  亦被 try 捕获）；frac 除零走 panic。
- 所有权：返回数组/列表/string = 指针移交（RVO）。
  **struct 赋值/初始化取消隐式深拷贝**（new.md）：RHS 为既有值的变量/
  字段/元素链时必须写 `copy(x)`（显式深拷贝）或 `move x`（所有权转移，
  源变量此后使用报 E3013，重新赋值解除）；构造调用 `P(...)`、函数返回值、
  枚举变体等产新值形式不需标记。数组/列表/string 聚合赋值/传参默认
  深拷贝，`move`/自动 move（源变量此后不再出现时）免拷贝。
- **借用 `borrow e`**（`borrow(x)` 同形）：对可定位表达式（变量/字段/
  元素）取借用，产指针值 `T*`，解引用 `p^` 读。借用不转移所有权——
  源变量照常可用（`f(ref src)` 传参、读值均合法）。所有权联动：
  借用期内 `move` 源报 E3000；`move` 后再 `borrow` 同样报错。
  **只读性强制**：借用结果必须落入 `T* const` 槽——`let T* p = borrow(x)`
  （显式非 const 指针类型）编译期报错；类型省略时（`let p = borrow(x)`）
  自动按 const 槽处理。const 槽解引用写报 E3156。
  **借用存活（NLL-lite）**：借用结果绑定到指针变量（`let T* const p =
  borrow(x)` / `p = borrow(x)`）时，借用随该变量的作用域结束失效——
  块/分支/循环体结束后源变量恢复可写可 move；表达式/实参位置的临时
  借用（`(borrow(x))^`、作实参直接传递）随所在语句结束失效。
  **整体借用**：`borrow(列表)` 配合 `T[]* const` 槽类型（如
  `let i32[]* const p = borrow(xs)`），经 `p^[i]` 只读索引、`p^` 整体
  传参（`length(p^)` 等）；列表/数组元素与解引用借用视为整体借用。
  **字段粒度借用**：`borrow(b.a)` 只锁 `b.a` 路径——借用期内写 `b.a`
  （赋值/序列字面量/元素写，路径重叠即前缀关系，含嵌套路径：借
  `s.ix.x` 时写 `s.ix`/`s` 报错，写兄弟 `s.ix.y`/`s.other` 放行）
  报 E3000；`move b`（整体）在任何字段借用期内报 E3000。
  **逃逸禁止**：`return borrow(x)` 报错（借用指向函数栈内数据，返回即
  悬垂）；借用不得借全局变量。
  **自动 move 循环限制**：循环体内（while/for 任意嵌套深度）的
  实参/赋值一律不自动 move、走克隆——源码位置判不出"下一轮迭代还会用"
  （`while` 里 `f(r)` 反复传同一列表是安全且常见的，误 move 会致
  第二轮空指针崩溃）；循环外顶层"最后使用"仍自动 move 免拷贝。
  被借用变量同样不参与自动 move。
- string 槽独占堆串（MCopy strdup 保证）；`s[i] = c` 原地写（越界 panic）。
- 程序入口前执行 `zfy.globals`（顶层变量初始化）。

### 15.1 内联汇编 asm（unsafe，v3.31）

```zfy
unsafe
    asm("cpuid", out=eax, out=ebx, out=ecx, out=edx, in=leaf, clobber="memory")
    asm("mfence", clobber="memory")
    asm("syscall", in=nr, in=a1, out=ret, clobber="rcx,r11,memory")
```

- 语法 `asm("模板"[, 命名实参 ...])`；命名实参为 `out=变量`、`in=变量`、
  `clobber="寄存器名列表"`——**可重复、顺序任意**，`in` 按关键字识别。
- 占位符 `$0 $1 ...` **依次对应 out（按书写顺序，先）再 in（按书写顺序，
  后）**；约束由编译器自动生成：out = `=r`、in = `r`，clobber 逐项追加为
  `~{名}`（如 `clobber="rcx,r11,memory"` → `~{rcx},~{r11},~{memory}`）。
- 生成 `call void asm sideeffect "模板", "约束"(实参...)`——**始终带
  `sideeffect`**（不被优化器删除/提升/复制）。asm 是**语句**，不产生表达式值。
- out 变量在 asm 执行后写回槽位（可多个；类型限 ≤64 位整数/bool/char/指针）。
  模板对内存有读写时须声明 `clobber="memory"`。
- **必须在 `unsafe` 块内**，否则报 `inline asm requires unsafe`。
- 模板语法错误、无效寄存器名由汇编器/clang 报编译错误（不会产出坏 exe）。

### 15.2 volatile 内存访问（内存映射 I/O）

```zfy
let i64 mm = 0
volatile_store(&mm, 11)
let i64 v = volatile_load(&mm)
```

- `volatile_load(p)` / `volatile_store(p, v)` 生成 LLVM `load volatile` /
  `store volatile`：该次访问**不可被优化器删除、合并或重排**（内存映射
  I/O 的典型用途）。指针元素类型限 i8/i16/i32/i64/u8..u64。
- 语言**不提供 `volatile` 声明修饰符**（不做"变量级全访问 volatile"）：
  需要单次强制访问处用这两个内建；需要顺序/原子性语义用 §21.2 原子内建
  或 `atomic_fence`。
- 实参 `&var` 取址；与原子内建一样豁免 `shared` 锁外访问检查（§21.6）。

## 16. 错误报告格式与自动修复

**报错格式**：每条错误带全局递增序号 `[N]`（按文件→行→列排序编号，
一次编译内连续），后跟错误码、行号、文件名与原因，并附出错行上下文
（上下各 2 行共 5 行 + `^` 指示列）。超过 30 条折叠，保留汇总行。

```
zfy:error[2][E3011] in 5 of main.zfy because (undefined variable: cont (did you mean 'count'? auto-fixed))
let i32 n = cont
             ^
```

undefined variable/function 报错附 did-you-mean 建议（最小编辑距离，
≤3 字符容 1 错、其余容 2；候选并列时只提示不修）。

**自动修复**：四类"唯一语义"错误（修复方式唯一、无歧义）由编译器
自动修复，报错照常输出（文案含 `auto-fixed`），且报告顶部先罗列将
被自动修复的序号：

| 类别 | 触发示例 | 自动修复动作 | 修复后 |
|---|---|---|---|
| undefined variable 唯一候选 | `let i32 n = cont`（作用域内有 `count`） | 改名 `cont` → `count` | `let i32 n = count` |
| undefined function 唯一候选 | `shwo(x)`（有 `show`） | 改名 `shwo` → `show` | `show(x)` |
| 范围内整数字面量窄化 | `let i8 x = 100`（值在 i8 范围） | 插 cast | `let i8 x = cast(100, i8)` |
| char→整数槽 | `let i32 c = 'A'` | 按码点插 cast | `let i32 c = cast('A', i32)` |

**产出规则（交互式修复）**：

- **非交互场景**（stdin 非终端，如脚本/管道；可用 `ZFY_FIX=all` 强制）
  → 自动修复全部（内存补丁重跑 ≤4 轮，**源文件不动**），照常产出
  可执行文件，stderr 打印修复明细
  `zfy: note: auto-fixed N error(s):`（每条带序号/错误码/行号/文案）。
- **交互场景**（终端运行，或 `ZFY_FIX=ask` 强制）→ 照常报告全部错误
  （顶部罗列可自动修复的序号）**且不退出**，提示
  `zfy: enter error number(s) to auto-fix (space/comma separated; Enter = all, q = none):`
  ——输入要修复的**序号**（空格与逗号分隔均支持，可混用，如
  `1, 3` 或 `1 3`；直接回车=全部，`q`=不修），选中项**直接写回源
  文件**（改名与 cast 插入都改文件）后自动重编译；不可修错误照常
  留存，全部可修则产出 exe 并打印修复明细。
- `ZFY_FIX=ask`/`all` 环境变量可强制指定模式（脚本/测试用）。

**整数字面量落窄槽**：超界字面量不再静默回绕，报 E3155 要求显式 cast——

```
let i32 x = 7000000000   // E3155：字面量超 i32 范围，须 cast(…, i32) 或改 i64
let u8 y = -1            // E3155：负值不在 u8 范围
```

例外：u64/u128 上下文的 hex 字面量（如 `0xC2B2AE3D27D4EB4F`）按位型
语义接受，不查符号位。

## 17. 已知限制

- `(* *)` 不是注释；块注释内可含中文/UTF-8。
- 字符串无内建字典序排序（可用 `<` 自行比较）。
- struct 不能整体 output。
- extern 允许 `T[]` / `T*` 返回（unsafe 语义，§10）；变参只收标量/string/指针。
- 整数溢出**默认检查**（`+ - *`、一元负号、`**`、`abs` 溢出即 panic，可被
  `try()` 捕获）；`--wrap-overflow` 切回静默回绕（§15）。
- `x & 1 == 1` 按优先级解析为 `x & (1 == 1)`，位运算与比较混用建议加括号。
- 分数字面量写 `(n/d)`（§5）；裸 `n/d` 是整数除法，落 frac 目标报错。
  浮点缩放常量请写成科学计数法（如 `1.1102230246251565e-16`）而非
  `1.0/9007199254740992.0`。
- 跨文件 use 的 struct/类型别名作声明类型：解析器按"Ident 后跟 Ident"
  形状识别，`let Pt p` / `let Pair<int,string> pr` 均可。
- **`**` 整数幂**：≤64 位走 zfy_pow_ll/ull；
  i128/u128 走 zfy_pow_u128/i128（64 位对接口，指数支持完整 128 位，
  如 `2 ** 2^64`）；跨宽度提升与通用算术一致（`u64 ** i32` 隐式宽化）；
  整数负指数 = 0；**整数溢出默认 panic**（检查模式，§15；`--wrap-overflow`
  下按回绕语义）。
- **浮点与整数不能隐式混算**：含浮点字面量的表达式与
  整数变量混算报 E3190（如 `2.0 * x`，x 为 i64）——请显式
  `cast(x, f64)`；纯字面量混合树（`2.5 + 1`）整树按浮点算（f32 上下文
  则 f32）；浮点字面量落整数槽（`let i64 x = 2.5`、`x += 2.5`）同样
  E3190。
- **科学计数法字面量**：`1e40` / `1e-45` 裸指数形式正确解析；f32 常量按
  最近位型发射（0.1/2.249 等非精确值走 hex 位型，与 clang 一致）。
- **条件位必须是 bool**：if/while/for/and/or/not 的操作数须为 bool——
  算术树（`if 2**0`、`not (2**0)`、`x and 1`）报 E3000 正规类型错误。
- **T! 作列表叶元素整体打印不支持**（顶层 `output(e)` 支持，§11）。

## 18. GUI 窗口与组件（stdlib/gui.zfy + stdlib/widgets.zfy）

> 分层：**L0** runtime.c C 渲染核心（DIB 帧缓冲 + 事件环形队列 + GDI
> 雅黑中文文本 + BitBlt 单次提交）→ **L1** `stdlib/gui.zfy`（纯 extern
> 薄绑定）→ **L2** `stdlib/widgets.zfy`（统一元素 UI + 9 组件 + App 容器，
> damage 脏区跟踪，只重绘变化的组件）→ **L3** 应用（examples/demos）。
> 仅 Windows（Win32 + GDI）；非 Windows 平台 GUI 桩全部返回失败/空。

### 18.0 ui 语句（元素+标签，最简写法）

`ui <kind> <名> [in <app>]` + 缩进标签块——编译期脱糖为统一元素代码，
注册自动查重（循环内安全），on_xxx 为每帧边沿触发：

```
ui button btn
    x 20, y 50, w 130, h 36     // 坐标/大小（等价 pos/size 标签）
    text "点我 +1"
    color C_ACCENT
    on_click ->
        app.set_text(app.find_ui("title"),
                     "点击 " + cast(app.uis[app.find_ui("btn")].clicks, string))
```

- **kind**：label/button/input/slider/progress/list/check/menu/textarea
  （input/list 为关键字，直接写）。
- **标签**：`x/y/w/h expr`（可同行逗号分隔）、`pos a, b`、`size a, b`、
  `text/color/text_color/radius/value/rows/checked expr`、
  `items e1, e2, ...`、`on_xxx ->` 缩进块。
- **事件**：`on_click`（点击）、`on_input`（文本变化）、`on_change`
  （值/文本/选中变化，单帧边沿）、`on_value`（滑杆/进度值变化）、
  `on_select`（列表/菜单选中）。同一 ui 语句可写多个 on_xxx。
- **语义**：语句须置于帧循环内（`app.step()` 之后）；首轮注册一次
  （按元素名查重），此后每帧只做边沿检查；边沿状态存于
  `app.uis[k]` 内部字段（p_clicks 等），无需业务管理。
- `in <app>`：App 变量名非 `app` 时显式指定。
- 元素变量（如 `btn`）仅在注册帧生效；运行期读写一律走
  `app.uis[app.find_ui("名")]` 或 `app.set_xxx(app.find_ui("名"), ...)`。

### 18.0a 统一元素 UI（标签袋 API）

**一个元素类型 + 标签袋**：先定义元素（`UI(kind)`），给它打标签
（坐标/颜色/形状/大小/内容），再注册；输入=改标签，输出=读标签。

```
mod gui;
mod widgets;
use widgets::{App, UI, C_ACCENT}
use gui::{gui_frame_sleep}

fn main()
    let App app = App()
    if app.open(300, 200, "demo") != 0
        return 1
    // 定义元素 → 打标签 → 注册（返回元素下标 k）
    let UI btn = UI("button")
    btn.pos(20, 20)            // 坐标
    btn.size(120, 44)          // 大小
    btn.text("点我 +1")        // 内容
    btn.color(C_ACCENT)        // 面色
    btn.radius(8)              // 形状（圆角）
    let i32 kb = app.add(btn)
    let UI num = UI("label")
    num.pos(20, 80)
    num.text("计数 0")
    let i32 kn = app.add(num)
    let i32 prev = 0
    while app.alive()
        app.step()                       // 输出标签每帧自动刷新
        if app.uis[kb].clicks != prev    // 输出：读标签（差值）
            prev = app.uis[kb].clicks
            app.set_text(kn, "计数 " + str(prev))   // 输入：改标签即改界面
        gui_frame_sleep(app.t0)
    app.close()
```

**kind**：`"label" "button" "input" "slider" "progress" "list" "check"
"menu" "textarea"`。

**属性标签（加入前，元素方法）**：`pos(x,y)` `size(w,h)` `text(s)`
`color(rgb)`（面色/填充，0=主题默认）`text_color(rgb)` `radius(r)`
（button 圆角）`value(v)`（slider/progress 初值 0..100）`rows(n)`
（list 可见行数）`checked(b)`（check 初值）`add_item(s)`（list/menu 条目）
`visible(b)`（可见性，默认 true——flush 跳过绘制；带标签的元素每帧重申，
运行期 `app.set_visible` 改不带标签的元素）`enable(b)`（可用性，默认
true——事件忽略；同上每帧重申语义）`placeholder(s)`（input 专属：
text 为空时框内显示的灰色提示——不是文本内容、不可选中、不进 text_out）。

**属性标签（加入后，按元素下标）**：`app.set_text(k, s)` `set_pos(k, x, y)`
`set_size(k, w, h)` `set_color(k, c)` `set_text_color(k, c)`
`set_value(k, v)` `set_checked(k, b)` `set_visible(k, b)` `set_enable(k, b)`
`set_placeholder(k, s)`（input）`app.add_item(k, s)`。

**输出标签（`app.uis[k]` 只读，`app.step()` 后刷新）**：

| 输出 | kind | 含义 |
|---|---|---|
| `clicks` | button/check/menu | 点击计数（差值=新点击）；list=双击计数 |
| `checked` | check | 勾选态 |
| `sel` | list/menu | 选中下标（-1 未选） |
| `value` | slider/progress | 当前值 0..100 |
| `text_out` | input/textarea | 当前文本；list=选中项文本 |
| `changed` | input/textarea/slider/progress/list | 本帧值/文本/选中是否变化 |

要点：仍然**无回调**（差值模型）、damage 脏区跟踪不变；UI 内部按 kind
转发到各组件实现。响应式布局参考 `demos/ui_demo.zfy`。

### 18.0b 组件 API（旧式，直接构造组件）

需要细粒度控制（如 bg_w 防残影、TextArea 光标操作）时可直接构造组件：

```
let App app = App()
if app.open(280, 340, "zfy 计算器") != 0      // 0=成功（逻辑尺寸）
    return 1
let Button b = Button(x=0, y=0, w=10, h=10, text="点我")
app.add_button(b)                             // 返回组件下标
let i32 prev = 0
let i32 last_w = 0
while app.alive()
    // 响应式布局：窗口可拖拽缩放，每帧比对尺寸重排
    if gui_w() != last_w
        ...重算组件位置...
    app.step()                                // 泵事件+更新+按需重绘
    if app.buttons[0].clicks != prev          // 按钮被点（读计数器差值）
        prev = app.buttons[0].clicks
        ...业务...
    gui_frame_sleep(tick_ms())                // 限帧（App 已修 CPU 空转）
app.close()
```

要点：add 进去的是**副本**（值语义），此后业务读写一律走
`app.buttons[idx].字段`。Button 支持自定义 `color`（面色，0=主题）/`tcolor`
（文本色）/`radius`（圆角，默认 6）。响应式布局参考 `demos/calculator.zfy`。

### 18.1 L1：gui.zfy 窗口与绘制 API

事件与常量：

| 项 | 说明 |
|---|---|
| `Event` struct | `typ/x/y/key` 全 i64；`e.is(EV_MOVE)` 便捷判断 |
| `EV_MOVE/LDOWN/LUP/RDOWN/RUP/KEY/WHEEL/SIZE` | 1..8；KEY 的 key=键值，WHEEL 的 key=滚动增量，SIZE 的 x,y=新物理宽高 |
| `KEY_EXT` | `0x10000000 | VK`：LEFT 0x25 RIGHT 0x27 UP 0x26 DOWN 0x28 DEL 0x2E HOME 0x24 END 0x23 |
| `KEY_CTRL` | `0x20000000 | 'C'/'V'/'A'/'X'` |

窗口生命周期与多窗口：

```
gui_open(w, h, title) -> i32      // w/h 逻辑尺寸（96dpi 基准），0=成功
gui_close()                       // 关当前窗口
gui_alive() -> bool               // 当前窗口存活
gui_alive_any() -> bool           // 任一窗口存活（多窗口主循环条件）
gui_self() -> i32                 // 当前窗口句柄 1..8
gui_select(id)                    // 切换"当前窗口"；绘制/事件作用于它
                                  // gui_open 后新窗口自动成为当前窗口
gui_title(t) / gui_set_icon(path) // 标题 / 窗口图标（.ico 文件路径）
gui_w()/gui_h() -> i32            // 当前窗口客户区，物理像素
gui_dpi() -> i32                  // 96=100% 缩放；逻辑转物理 = v*dpi/96
```

绘制（作用于当前窗口的帧缓冲，`gui_present()` 后才上屏）：

```
gui_fill_rect(x, y, w, h, 0xRRGGBB)   // 实心矩形（自动裁剪）
gui_rect(x, y, w, h, 0xRRGGBB)        // 1px 边框
gui_draw_text(x, y, s, 0xRRGGBB)      // 雅黑 16 逻辑px，UTF-8 中英文
gui_text_w(s) -> i32                  // 文本像素宽（当前窗口字体度量）
gui_present()                         // 帧缓冲 → 屏幕（BitBlt 单次提交）
```

事件轮询与帧率：

```
gui_poll(ref e) -> bool               // 泵 Win32 消息队列 + 取一事件
gui_frame_sleep(start_ms)             // 配对 tick_ms()，限 ~60fps 且不空转
```

剪贴板（CF_UNICODETEXT ↔ UTF-8）：

```
gui_clip_set(s)                       // 写入（替换现有内容）
gui_clip_get() -> string              // 读取；失败/无文本返回 ""
```

### 18.2 L2：widgets.zfy 组件库

颜色常量（可整体覆盖自绘主题）：`C_BG C_PANEL C_BORDER C_TEXT
C_ACCENT C_HOT C_DOWN C_OK`。缩放辅助：`SC() -> i32` = dpi/96 百分比
（144dpi 时 150），所有组件内部尺寸已经过它缩放；业务自绘几何建议
同样乘 `SC()/100`。

所有组件共有：`x/y` 坐标（物理像素）、`dirty` 标志（改动后置 true，
App 只重绘脏组件——文本/状态变化后**必须置 dirty = true**）。

| 组件 | 关键字段（业务读） | 交互 |
|---|---|---|
| `Label` | text、color、bg_w | 静态文本；bg_w=清屏宽度防残影 |
| `Button` | **clicks**（累计点击数） | 悬停/按下高亮 |
| `InputBox` | text、focus | 单行输入，点击获焦，键盘输入；**鼠标拖选**（按下定位光标并开始拖选，移动扩选，松开结束），有选区时输入/退格/Delete 先删选区 |
| `Slider` | **value**（0..100） | 拖拽滑块 |
| `ProgressBar` | value | 只展示，set_value 驱动 |
| `ListBox` | **sel**（-1 未选）、top | 点击选中行，滚轮滚动 |
| `TextArea` | lines、**cx/cy**、top、focus | 见 18.3 |
| `Checkbox` | **checked**、clicks | 勾选切换 |
| `Menu` | **sel**（最后选中条目索引）、**clicks**、open | 见 18.4 |

App 容器：

```
app.open(w, h, title) -> i32          // 同 gui_open（0=成功）
app.alive() -> bool                   // gui_alive 且未请求退出
app.close()                           // 退出循环
app.add_label / add_button / add_input / add_slider / add_bar /
app.add_list / add_text / add_checkbox / add_menu(...)
                                      // 挂组件（值拷贝进容器）
app.step()                            // 一帧：泵事件→命中测试→更新→脏区重绘
app.mx / app.my                       // 本帧鼠标客户区坐标（自绘命中用）
app.ldown                             // 左键按住（拖拽逻辑用）
app.invalidate_all()                  // 全组件置脏（主题切换等）
```

### 18.3 TextArea（多行编辑）

```
let TextArea ta = TextArea(x=8, y=40, w=100, h=80)
ta.set_text("第一行\n第二行")          // 按回车拆行初始化
ta.text() -> string                    // 合行取回全文（\n 连接）
ta.insert_at_cursor(s)                 // 光标处插入（Ctrl+V 内部走它）
ta.handle_key(k) -> bool               // 手动喂键（App.add_text 已自动）
```

内置编辑能力：**鼠标拖选**（按下定位光标并记录锚点，按住移动扩选，
松开结束；高亮跟随；拖选跨行按行主序规范化）+ 点击/方向键/Home/End
移动光标（移动即收起选区）、回车拆行、退格删字
（行首回退合行）、Delete、滚轮上下滚动。
**选区联动**：有选区时输入字符 / 回车 / Ctrl+V / 退格 / Delete 均先删除
选区再作用于光标处（输入即替换选区）。选中状态可读：`ta.has_sel() ->
bool`，`ta.del_selection() -> bool`（删选区，光标落选区起点，业务可手动
调用）；锚点字段 `sax/say`，拖选进行中 `dragging`。**UTF-8 码点对齐**：cx 是
字节列，退格/Delete 自动按前导字节回退整个多字节字符，中文不会被
切坏。判断按键来源：`k >= KEY_EXT` 为扩展键（k-KEY_EXT=VK），
`k >= KEY_CTRL` 为 Ctrl 组合键。

### 18.4 MenuBar（菜单栏）

```
let Menu mf = Menu(title="文件", items="新建", "退出")
let Menu me = Menu(title="编辑", items="复制", "粘贴", "插入时间")
app.add_menu(mf)                       // 挂多个 Menu 即成菜单栏
...
let i32 handled = me.clicks            // 每帧对比差值
app.step()
if me.clicks != handled
    output("选中条目 idx=", me.sel)    // 0 基；"退出"=1
```

交互语义：点击标题开/合下拉（同排其它菜单自动收起）；点击条目时
`sel` 写入条目索引、`clicks++`，随后下拉自动收起；点击菜单栏以外
区域也收起。条目高亮随悬停变化。菜单栏高度 `app.menu_bar_h()`，
业务组件 y 应从其下方起排。

### 18.5 裸 L0 轮询写法（不用 App，适合嵌入自定义框架）

```
use gui::{...}
fn main()
    if gui_open(480, 300, "raw") != 0
        return 1
    let Event e = Event()
    while gui_alive()                  // 多窗口用 gui_alive_any()
        while gui_poll(ref e)
            if e.is(EV_LDOWN)          // 事件驱动分支...
                ...
            if e.is(EV_KEY) and e.key >= KEY_EXT
                ...
            if e.is(EV_SIZE)           // 窗口缩放 → 全量重绘
                ...
        gui_fill_rect(16, 16, 64, 32, 0x2F7FD6)
        gui_draw_text(20, 20, "你好 zfy", 0xFFFFFF)
        gui_present()
        gui_frame_sleep(tick_ms())
    gui_close()
```

### 18.6 GUI 易错点

- **组件交互不用回调**：全部读字段差值（clicks/value/sel/checked），
  忘记对比差值 = 每帧重复触发。
- **改了必置 dirty**：`lbl.text = "x"` 后不置 `lbl.dirty = true` 不重绘。
- **gui_w/gui_h 是物理像素**：与逻辑坐标混算前乘 `SC()/100` 或除以
  `gui_dpi()/96`；断言宽高请用物理值（150% 屏上 480 逻辑 = 720 物理）。
- **交互/死循环 GUI 程序不得放 examples/**（回归会挂死），放 demos/。
- **`err` 是关键字**（ZEM 错误模型），GUI 业务局部变量改名（如 bad）。
- **值语义深拷贝**：`app.add_button(b)` 后再改局部 `b` 无效——需要
  改容器内组件时读 `app.buttons[i]`（元素字段复合赋值
  `app.buttons[i].x = 5`、`app.buttons[i].clicks++` 均支持）。

## 19. 内建容器 map / set 与 for-in

### 19.1 map<K, V>

```zfy
let map<string, i32> ages        // 裸声明即空表（h 槽惰性分配）
ages["alice"] = 30               // 写入（覆盖语义）
let i32 a = ages["alice"] ?? -1  // 读产 i32!：缺失 = NOT_FOUND，须 ?? 解包
output(map_len(ages))            // 元素数
output(map_has(ages, "bob"))     // 是否有键 -> bool
output(map_del(ages, "bob"))     // 删除（返回是否存在）
output(keys(ages))               // 键列表 list<K>（新分配）
output(values(ages))             // 值列表 list<V>（新分配）
```

- **键类型**：string 或整数（i8~i64/u8~u64）。整数键统一按 i64 位模式存储。
- **值类型**：≤64 位标量（整数/浮点）或 string。string 值深拷贝（值语义）。
- 整体赋值/传参为**值语义深拷贝**（`m2 = m1` 后互不影响）；
  作用域退出自动释放。键插入顺序不保证（哈希桶序）。
- `m[k]` 只能作用于**局部变量**（字段链 `bag.m[k]` 暂不支持）。
- `m[k] op= v` 不支持（读侧是 T!，请 `m[k] = (m[k] ?? 0) + 1`）。

### 19.2 set<T>

```zfy
let set<i32> seen
set_add(seen, 1)                 // 插入（重复无效果）
output(contains(seen, 1))        // 成员判定 -> bool（set_has 同义）
output(set_len(seen))
set_del(seen, 1)                 // 删除
for x in seen { ... }            // 遍历产元素
```

元素类型同 map 键（string/整数）。内部即 map<T, i32>（值恒 1），
`set_add`/`contains`/`set_del`/`keys` 对 set 同样适用。

### 19.3 for-in 遍历

```zfy
for x in xs { ... }              // 列表/数组（数组须为变量）：x 为元素类型
for x in xs, i { ... }           // 同上 + i 绑定 i64 索引
for c in "ab" { ... }            // string：c 为 char
for c in "ab", i { ... }         // 同上 + i 为 i64 字节索引
for k in m { ... }               // map：k 为键类型
for k in m, i { ... }            // 同上 + i 为遍历序号（非键序）
for x in s { ... }               // set：x 为元素类型
```

- 循环变量类型自动推断、每轮为元素的**独立深拷贝**（循环体内修改不影响
  原序列）；序列表达式只求值一次（拷入临时槽）。与三段式 `for` 并存。
- 循环变量作用域同 `for` 头变量：循环结束后仍可见（值为最后一轮元素）。
- **下标变量**：逗号后的名字绑定 `i64` 索引，从 0 起每轮 +1；
  同样在循环结束后可见（值为最后索引）。与外层同名变量构成 shadowing。

### 19.4 列表算法内建（全部返回新列表，原列表不动）

| 内建 | 形态 | 说明 |
|---|---|---|
| `sort(xs)` | `list<T> -> list<T>` | 升序；T 限整数/浮点/string |
| `reverse(xs)` | `list<T> -> list<T>` | 倒序（元素深拷贝） |
| `join(xs, sep)` | `(list<string>, string) -> string` | 拼接 |
| `contains(xs, v)` | `(list<T>, T) -> bool` | 成员判定 |
| `filter(xs, pred)` | `(list<T>, fn(T)->bool) -> list<T>` | 按谓词筛选 |
| `any(xs, pred)` / `all(xs, pred)` | `-> bool` | 存在/全部满足 |
| `sort_by(xs, cmp)` | `(list<T>, fn(T,T)->i32) -> list<T>` | 自定义比较器排序 |
| `fold(xs, f, init)` | `(list<T>, fn(T,T)->T, T) -> T` | 左归并 |
| `map(xs, f)` | `(list<T>, fn(T)->B) -> list<B>` | 逐元素映射（§20.5） |
| `min(xs)` / `max(xs)` | `list<T> -> T` | 最值；**空列表运行期 die**；T 限整数/浮点/string（string 返回为独立堆串） |
| `sum(xs)` | `list<T> -> T` | 求和；空列表 = 0；T 限整数/浮点 |
| `count(xs, v)` | `(list<T>, T) -> i64` | 相等元素计数（string 用 strcmp） |
| `index_of(xs, v)` | `(list<T>, T) -> i64` | 首个相等下标，未找到 = -1 |

- 谓词/比较器/归并函数**传 lambda 或裸函数名**（自动包装为闭包）；`fold`
  不叫 `reduce`（`reduce` 是 frac 缩减关键字）。
- 结果为表达式临时时语句末自动释放；赋给变量即接管所有权。
- 定长数组不能直接作为这些内建的实参（先赋给列表变量）。

### 19.5 sort 内建表达式

```
sort(内容..., 顺序)      # 顺序 = max（从大到小）| min（从小到大），裸名
sort(a, min)             # a 为数组/列表：返回排序后的新列表，a 不变
sort(1, 6, 3, max)       # 多个标量：返回 list<i64>（6,3,1）
sort(x, y, 2, -56, 555, max)   # 序列与标量混合：展平后排序
```

- **是表达式**，可赋值/传参/立即 output。
- 内容可为数组、列表或多个标量（逗号隔开），可混合宽度与类型。
- 混合比较规则：string/char 按 ascii 码、bool 等价 0/1；
  任一浮点参与 → 结果 `list<f64>`，否则 `list<i64>`。
- 单容器实参：元素限整数/浮点/string，结果保持元素类型（string 按字典序）；
  bool/char 容器按 0/1 与 ascii 码排，结果 `list<i64>`。
- **检查**：单标量内容编译报错；const 定长数组元素 ≤1 编译报错；
  非 const 容器/列表元素合计 <2 运行期 panic。
- 结果恒为新列表（值语义，源序列不变）。

### 19.6 已知限制

- 键/值不支持 struct、frac、i128/u128、f16/f128、bool、char 值。
- map/set 无字面量语法；构造靠裸声明 + 逐条写入。
- `m[k]` 读在语句位置直接丢弃会报"丢弃 T! 值"（须 `??`）。
- filter/any/all/sort_by/fold 的函数实参不能是函数指针变量（须 lambda/函数名）。

## 20. 闭包与 lambda

### 20.1 lambda 表达式

```
fn(i32 x) => x * 2              // 简写：返回类型由体表达式推断
fn [&counter](i32 d) => counter + d   // 显式引用捕获
fn(i32 a, i32 b) -> i32         // 块形式：换行 + 缩进块，体内 return
    return a + b
fn() => 42                      // 无参
let fn(i32) -> i32 dbl = fn(x) => x * 2   // 参数按声明闭包类型推断
map(xs, fn(v) => v * 2)         // 参数按列表元素类型推断
```

- 参数类型**可省**（v3.30）：上下文能给出期望闭包类型 `fn(T...) -> R`
  时，省略类型的参数按位置落型（参数个数须与期望一致；个数不符或
  无期望 → 编译期报错 `cannot infer lambda parameter type`）。
  期望位置：`let fn(...) -> R f = ...` 声明初值、函数实参（含容器内建
  map/filter/any/all/sort_by/fold 与 spawn/try 的闭包实参）、赋值右值、
  `return`（函数返回类型为闭包时）、struct 字段默认值。
  无期望（lambda 位于普通表达式位置）时仍须显式类型；显式类型优先于
  期望。
- `=>` 简写体为单个表达式；`-> T` 块形式体内用 `return`，缺 `return`
  报错（void 除外）。
- lambda 是表达式，可赋值、传参、立即调用：
  `output((fn(i32 x) => x + 1)(41))`。

### 20.2 闭包类型与变量

```
let fn(i32) -> i32 dbl = fn(i32 x) => x * 2
let fn(string) -> string mk = fn(string who) => greet + who
```

- 闭包类型写法 `fn(T...) -> R`；闭包值是轻量句柄（拷贝廉价，指向
  共享的捕获环境堆块）。
- 闭包可再作为捕获/参数/返回值传递。可捕获的值类型见 20.3。

### 20.3 捕获语义

- **默认值捕获**：体内引用的外层局部变量自动按值捕获（声明点快照，
  **深拷贝**进环境块）：标量/string/bool/char/指针/闭包句柄，以及
  **动态列表 `T[]`、定长数组 `T[N]`、struct、frac、`T!`**（v3.30）。
  列表捕获 = 深拷贝新列表；struct 捕获 = 整个值语义 struct 内联进环境块
  （含其列表字段深拷贝）；frac 按元素宽度内联分子/分母。
- **显式引用捕获** `fn [&x, y](...) => ...`：`&x` 引用捕获（读写穿透
  到外层变量），`y` 值捕获。
- **引用捕获的目标自动堆箱化**（v3.30）：本函数内被任一 lambda `&`
  捕获的变量，其存储改为 rc 堆箱（引用计数）；lambda 环境块持有箱的
  一份份额。因此闭包**逃逸出作用域后调用仍然安全**——`&x` 读写穿透到
  箱，箱随最后一个闭包释放而销毁（无悬垂、无泄漏）。
- 全局（`@` 名）与 const 不经捕获、直接可见。
- 捕获环境按引用计数回收（v3.27 P0-1a：最后一个持有者释放时归还 env
  堆块，闭包被覆盖/离开作用域即配平）；环境块的释放由块内自描述 dtor
  完成（v3.30：每个 env 块头记录自身 clenv 布局的字段级联释放函数，
  修复同签名多 lambda 混捕时 dtor 错配导致的堆越界）。
- 值捕获是**副本**：lambda 内对该变量的赋值只改环境块内的副本，
  外层变量不变（要跨闭包共享可变状态请用 `&x` 引用捕获，或全局变量）。

### 20.4 嵌套命名函数

```
fn main()
    let i32 scale = 3
    fn i32 scaled(i32 v)
        return v * scale
    output(scaled(7))    // 21
```

- 函数体内 `fn Ret 名(参数)` 声明嵌套函数；自动捕获外层局部变量
  （值语义），声明即成为可调用值。

### 20.5 容器内建与 lambda

- `filter/any/all/sort_by/fold` 的谓词/比较器/归并函数直接传 lambda
  或**裸函数名**（自动包装为闭包）：
  ```
  let i32[] big = filter(xs, fn(i32 v) => v > 2)
  let i32[] desc = sort_by(xs, fn(i32 a, i32 b) => b - a)
  let i32[] ev = filter(xs, is_even)      // 裸函数名
  ```
- `map(xs, f) -> list<B>`：逐元素映射，B 由 f 返回类型决定
  （限标量/string/bool/char）。
- 元素按值传入回调；string 元素传堆串指针，回调接管其所有权。

### 20.6 已知限制

- lambda 参数可省（§20.1）：有期望闭包类型的位置按位置推断，无期望时
  必须显式；块形式必须显式 `-> T`；嵌套函数参数限标量。
- 值捕获的容器/struct 在 lambda 体内可读、可整体赋值；**不能作为
  `push` 等需要 `ref` 的目标**（容器的 ref 语义指外层变量槽，捕获副本
  无独立槽）——需要就地修改请用 `&x` 引用捕获。
- 捕获 struct 后不可在 lambda 体内调用其方法（`self` 需可写接收者，
  捕获副本不支持取方法接收者地址）；需要时用 `&x` 引用捕获。
- spawn 场景捕获白名单更严（§21.1）：数组/列表/普通 struct 编译期拒绝。

## 21. 并发

> 线程收闭包（env 堆块引用计数回收，线程持有期间计数不归零，天然适配线程）；
> 共享数据 v3.26 起走 `shared` 全局 + lock 块（§21.3/§21.6）或原子内建；
> 容器（map/set/列表）非线程安全，跨线程共享须外部 mutex 保护。

### 21.1 线程：spawn / join / detach

```zfy
let t = spawn(fn() => output("hi"))   // 收 lambda
let t2 = spawn(worker)                // 收裸函数名（自动包 wrapper）
join(t)                               // 阻塞等待；成功后句柄置空
join(t)                               // 幂等：对已完成的句柄立即返回（空操作）
detach(t2)                            // 放弃句柄所有权，不等待线程结束
```

- 线程体签名须 `fn() -> void`；spawn 返回线程句柄（`let t =` 推断）。
- **join 幂等**（v3.31）：join 完成后句柄置空；对已 join/已 detach 的句柄
  再次 join 是**空操作**（立即返回，不报错、不崩溃）。
- **detach(t)**（v3.31）：关闭句柄、放弃所有权，立即返回、不等待线程；
  线程继续独立运行到线程体结束。detach 后句柄为空操作（再次 join 亦空操作）。
- 句柄仍为 move-only（OS HANDLE 不可拷贝，§30），连接语义靠 join/detach。
- spawn 的闭包环境所有权移交线程：线程体结束时由线程侧释放
  （`zfy_env_free`，级联捕获副本）；变量实参在 spawn 后清槽（不可再用）。
- **spawn 捕获白名单（v3.26 P0-3；v3.31 起放行 `&x` 引用捕获）**：spawn
  实参闭包捕获的类型限标量/string/bool/char、闭包句柄、thread/mutex/chan
  句柄，以及 **`&x` 引用捕获（捕获字段是原子的 rc 堆箱指针）**；捕获数组/
  列表/普通 struct/frac、借用/原始指针编译期报错（提示用全局 `shared` 变量
  或 chan 传值）。**非 spawn 场景**的闭包捕获按 §20.3 白名单放行
  （v3.30 起含列表/数组/struct/frac，值捕获深拷贝进环境块）。
- **跨线程 `&x` = 共享可变状态**：`&x` 引用捕获的目标由编译器堆箱化，箱的
  生命周期由**原子引用计数**维护——跨线程不会悬垂/双释放（安全）；但箱内
  数据的并发读写是共享可变状态，**须自行用 mutex（§21.3a）或原子内建
  （§21.2）同步**。未同步的并发读写 = 数据竞争（结果不确定），**不是
  内存安全缺陷（非 UB）**。

### 21.2 原子操作与内存序（v3.31）

```zfy
atomic_inc(&counter)                                      // 旧形态：自增（void，语句级）
atomic_store(&counter, 5)                                 // 旧形态：原子写（默认 SeqCst）
let old = atomic_add(&counter, 10)                        // 旧形态：fetch_add -> 旧值
output(atomic_load(&counter))                             // 旧形态：原子读（默认 SeqCst）

atomic_store(&counter, 5, Ordering.Release)               // 指定内存序
output(atomic_load(&counter, Ordering.Acquire))
let old2 = atomic_add(&counter, 1, Ordering.AcqRel)       // fetch-add -> 加前旧值
let old3 = atomic_exchange(&counter, 9, Ordering.AcqRel)  // 交换 -> 旧值
let ok = atomic_compare_exchange(&counter, 9, 21, Ordering.AcqRel, Ordering.Acquire)
atomic_fence(Ordering.SeqCst)                             // 内存屏障（语句级）
```

| 内建 | 语义 | 返回值 |
|---|---|---|
| `atomic_load(p[, ord])` | 原子读 | 值 |
| `atomic_store(p, v[, ord])` | 原子写 | void（语句级） |
| `atomic_add(p, v[, ord])` | fetch-add（返回运算前旧值） | 旧值 |
| `atomic_sub(p, v[, ord])` | fetch-sub | 旧值 |
| `atomic_and(p, v[, ord])` | fetch-and | 旧值 |
| `atomic_or(p, v[, ord])` | fetch-or | 旧值 |
| `atomic_xor(p, v[, ord])` | fetch-xor | 旧值 |
| `atomic_exchange(p, v[, ord])` | 原子交换 | 旧值 |
| `atomic_compare_exchange(p, expect, new[, 成功序, 失败序])` | CAS：`*p == expect` 时写 new | bool（成功 true） |
| `atomic_inc(p)` | 原子自增（旧形态） | void（语句级） |
| `atomic_fence([ord])` | 内存屏障 | void（语句级） |
| `volatile_load(p)` / `volatile_store(p, v)` | 非原子强制访问（见 §15.2） | 值 / void |

- **元素类型**：i8/i16/i32/i64 与 u8/u16/u32/u64（按位模式操作，8/16/32/64 位）。
- **内存序 `Ordering`**（预置枚举值，无新关键字）：`Ordering.Relaxed`、
  `Ordering.Acquire`、`Ordering.Release`、`Ordering.AcqRel`、
  `Ordering.SeqCst`——编译期识别为常量，运行期不占开销。
  **省略内存序实参 = `Ordering.SeqCst`**（旧形态因此保持完全兼容）。
- CAS 的失败序不能是 `Release`/`AcqRel`（硬件/LLVM 限制），编译器自动
  降为 Relaxed（monotonic）。
- **生成方式**：编译器直接发 LLVM 原子指令（`load atomic` / `store atomic` /
  `atomicrmw` / `cmpxchg` / `fence`），不经运行时库——无 libatomic 依赖。
  `atomic_inc` 仍走 runtime（Interlocked 家族）。
- 实参 `&var` 取址；atomic/volatile 内建实参豁免 shared 锁外访问检查
  （§21.6）——原子操作本身即同步原语。

### 21.3 互斥锁

```zfy
let m = mutex_new()                   // 声明即构造（句柄捕获安全）
lock(m)                               // 函数式（须手动配对 unlock）
// ... 临界区 ...
unlock(m)
```

### 21.3a lock 块（v3.26，推荐）

```zfy
lock m                                // 块形式：入口自动加锁、块尾自动解锁
  counter = counter + 1               // 缩进块体（无花括号）
  if done
    return                            // return 穿越自动回卷解锁
// 此处锁已释放
```

- `lock <mutex 变量>` + 缩进块；与 `lock(` 表达式调用区分（`lock m` 后
  必须跟缩进块）。mutex 句柄类型用户侧不可名状，块目标须是 mutex 变量
  （可为闭包捕获传入）。
- **自动解锁回卷**：正常块尾、块内 `return` 全回卷解锁；块内 `break`/
  `continue`（穿越循环）只回卷到循环入口时的锁深度——循环外层的 lock
  块仍持有锁，不误放。
- 可嵌套（连续 lock 不同锁按序持有）。
- 持有任意 lock 块内即可访问 `shared` 全局（§21.6）。

### 21.4 channel：chan<T> 无界阻塞通道

```zfy
let chan<i32> ch                      // 声明即构造
chan_send(ch, 42)                     // 无界队列，不阻塞；closed 后发送报错
let v = chan_recv(ch) ?? -1           // 阻塞接收；产 T!（closed 且排空 =
chan_close(ch)                        //   NOT_FOUND），须 ?? 解包
output(chan_len(ch))                  // 当前排队数
```

- 元素类型限 ≤64 位标量/string（同 map 值）；string 深拷贝、所有权随
  队列转移。
- 句柄（thread/mutex/chan）可被闭包值捕获——声明即构造保证捕获副本
  与原句柄指向同一对象。
- **仅支持 Windows**（非 Windows 平台调用即终止）。

### 21.5 其他

- `sleep(ms)`：休眠指定毫秒。
- 已知限制：thread 句柄 move-only（join/detach 成功后置空，再次 join 为空操作）；
  mutex/chan 按引用计数回收（最后一个引用
  释放时归还内核资源与控制块，close 后归零即释放）；
  output 多线程交错不保证。
- **跨线程 `&x`（引用捕获）**（v3.31）：编译期放行的**安全共享**——捕获
  目标是原子 rc 堆箱，生命周期跨线程正确（不悬垂、不双释放）。箱内数据
  的并发读写是**共享可变状态**：须自行用 mutex（§21.3a）或原子内建
  （§21.2）同步；**未同步 = 数据竞争**（结果不确定），但**不是 UB/
  内存安全缺陷**——"引用捕获跨线程逃逸 = UB"的旧真空已消除。

### 21.6 shared 全局（v3.26 P0-3）

```zfy
let shared i64 counter = 0            // 仅顶层 let；函数内声明报错

fn main()
  let m = mutex_new()
  lock m
    counter = counter + 1             // lock 块内访问：放行
  atomic_inc(&counter)                // 原子内建：豁免
```

- 语义：`shared` 标注的全局变量**裸读写（不在任何 lock 块内、非 atomic
  内建实参）编译期报错**——把"忘记加锁"从运行期数据竞争提前为编译错误。
  上例若在 lock 块外写 `counter = ...` 即报错。
- 检查与具体锁无关：持有**任意** lock 块即视为受保护（锁与全局变量的
  关联靠约定，语言不校验锁-变量配对）。
- `shared` 仅允许出现在顶层 let；函数内/块内声明编译期拒绝。
- 参考用例：examples/sync_test.zfy（正例）+ sync_err_*.zfy（三类负例，
  回归带 .expect 基线）。

## 22. 枚举与和类型

### 22.1 定义

```
enum Color                     // 简单枚举：全部零载荷变体
    Red
    Green
    Blue

enum Shape                     // 和类型：变体可带载荷（类型列表）
    Empty
    Circle(f64)
    Rect(f64, f64)
    Named(string)
```

- 变体载荷类型任意（标量/string/指针/列表）；**任意变体都可带列表载荷**，
  多个变体可各带不同元素类型的列表（`Ints(i32[])`、`Strs(string[])`），
  同一变体也可带多个列表载荷（`Pair(i32[], string[])`）。
- 实现：统一编译为 struct `enum$<名>` { i32 tag; f0..fn }——载荷按
  **类型分槽**（同类型变体载荷共享槽，`Rect(f64,f64)` 占两个 f64 槽；
  每个列表元素类型各占独立槽：`i32[]` 与 `string[]` 是两个槽），
  因此不同变体载荷类型可以不同；未给出的载荷槽填空值（列表槽为空列表）。
  值语义 assign/深拷贝按 struct 走：列表字段随 struct 克隆/释放，
  match 解构的绑定为载荷字段的深拷贝。

### 22.2 构造

```
let Color c = Color.Green      // 零载荷变体裸名（也可写 Color.Green()）
let Shape s = Shape.Circle(2.0)
let Shape s2 = Shape.Rect(3.0, 4.0)
```

- 构造 = tag + 载荷全字段 struct 构造，类型不符编译期报错。

### 22.3 判别与解构

变体判别/载荷提取统一走 match（§23）；载荷字段名不直接暴露
（tag 字段可用 `x.tag` 读取，返回 i32 序号）。

## 23. match 分发

### 23.1 语法

```
match scrut                    // 换行缩进块，每 arm 一行
    模式 => 语句                // 单语句体
    模式 =>                     // 或换行缩进块体（多语句）
        语句...
```

### 23.2 模式

- `_`：通配（匹配一切，常作兜底）。
- 字面量/表达式：`1`、`"str"`、`'c'`、`true`、`-1`——按 `==` 比较
  （scrutinee 为标量/string/bool/char 时用）。
- 枚举变体：`Shape.Circle(r)`（载荷绑定名列表）、`Shape.Empty`（零载荷）、
  裸变体名 `Circle(r)`（scrutinee 类型已知时）。
- 绑定 = 对应载荷字段的深拷贝声明（值语义）。

### 23.3 语义

- 降码 = scrutinee 求值一次入临时槽 + tag/相等比较 if 链；首个命中
  arm 执行，其后 arm 跳过。
- **穷尽性检查（强制）**：scrutinee 为 enum 类型时，arm 须覆盖
  全部变体或含 `_` 兜底，否则编译期报错（`match is not exhaustive`）。
  字面量模式不计入覆盖（对 enum 无意义）；非 enum scrutinee 无此要求。
- **表达式位置的 match（v3.30）**：
  - `return match ...`：脱糖为语句位置 match——arm 体为单表达式时自动
    改写为 `return 表达式`（arm 体为缩进块时，块内须显式 `return`）；
    穷尽性检查与语句位置一致。
  - `let T x = match ...`：每个 arm 体为单表达式或缩进块（块末表达式
    作为 arm 值），脱糖为 `x` 零值声明 + 各 arm 对 `x` 赋值的透明块；
    限标量/struct/string/列表（可零初始化），const 不支持。
  - `let x = match ...`（省略类型）：按各 arm 体末表达式的类型求
    **公共类型**，再走上面的脱糖。规则：
    - 全整数：取首个 concrete 整型，字面量则默认 `i32`；
    - 有 float 混入：统一 `f64`（整数字面量按 `f64` 落型）；
    - string/bool/char：须全部同型；
    - struct/序列：须同型；不同 struct/序列或数值与非数值混用报
      `cannot infer match result type`（附两类型，提示显式标注类型）；
    - arm 体为缩进块时按块末表达式类型；无值 arm（如 `return`/`panic`）
      同样报上述错误。推断先做一次试检查（不产生副作用），正式检查
      仍按脱糖做一次。
  - 其他嵌套表达式位置（如函数实参 `f(match ...)`）不支持——match 的
    arm 块依赖缩进，无法在任意实参位置展开，请先赋值给局部变量再传。
- match 内 return/break/continue 正常传播。

## 24. 字符串设施

| 内建 | 签名 | 说明 |
|---|---|---|
| startswith | (string, string) -> bool | 前缀判定 |
| endswith | (string, string) -> bool | 后缀判定 |
| contains | (string, string) -> bool | 子串包含（与容器键包含共用名，按实参类型分流） |
| substr | (string, i64, i64) -> string | 字节区间 [start, start+len) 深拷贝；负 start 前移、越界截断 |
| to_str | (标量/bool/char/frac) -> string | 显式转串（整数字面量默认 i64；float 格式同 output） |
| format | (string, list<string>) -> string | 把列表元素逐个替换 `{}` 占位；占位多于实参 = 剩余 `{}` 原样保留 |

- 既有设施：length/find/trim/split/replace/utf8_*（§12）；
  列表 join(list<string>, sep)（§19.4）。

## 25. 泛型类型实参

- 泛型实例化 `Box<i32>` 的类型实参支持：标量/string/struct/指针/`T!`/
  **接口类型**（`Box<Drawable>`、`Holder<Drawable>`），以及
  **列表 `T[]`、定长数组 `T[N]`**：`Box<i32[]>`、`Pair<i32[], string>`、
  `Box<i32[3]>`、`Box<i32!>` 均合法（T! 实例字段为聚合，§11）。
- 实现层面单 ptr/值形态，单态化零成本；mangle 名扩展
  `Box$list$i32$...`（list$）/ `Box$arr$i32$3`（arr$…$长度）/
  `Box$err$i32`（err$，T! 实参）/ `Box$iface$Drawable`（接口实参）前缀，
  `$` 分隔保证与源码标识符无碰撞。
- **不可作类型实参**：frac、File、函数类型；容器 map/set 的键值实参仍限
  ≤64 位标量/string（§19.6）。
- 泛型 struct 的 `T` 字段可省略默认值：实例化时按实参类型取零值
  （`struct Box2<T>\n T v` 的 `Box2<i32>` 实例 `v = 0`、`Box2<string>`
  实例 `v = ""`，嵌套实例逐层取零）。
- 泛型函数对 `T`（绑定为列表）可做值语义操作与容器内建调用
  （`length(xs)`/`sum(xs)` 等按实例元素类型检查）；泛型体内支持
  `let T` 局部变量声明（实例化时按实参替换，fn 体与方法体均支持）。

## 26. 标准库内建：os_args / os_env / assert_eq

| 内建 | 签名 | 说明 |
|---|---|---|
| os_args | () -> list<string> | 命令行参数（argv[0] = 程序路径）；Windows CRT 引号/转义规则 |
| os_env | (string) -> string! | 环境变量读取；未设置 = NOT_FOUND（T!，`??` 解包或 match） |
| assert_eq | (标量, 标量) / (string, string) -> void | 断言相等；不等 panic 打印两侧值（`assert_eq failed: a != b`），exit 101 |

- assert_eq 的整数/bool/char 统一按 i64 位模式比较（u64/u128 走无符号
  位模式）；f32/f64 数值比较；string 按 strcmp。两侧须同类别。
- 典型用法：`let string home = os_env("HOME") ?? "fallback"`；
  测试断言 `assert_eq(actual, expected)`（失败即 panic，带 file:line）。

## 27. interface 接口与多态

```zfy
interface Drawable
    fn f64 area()
    fn string name()

struct Circle
    f64 r = 0.0
    fn f64 area()
        return 3.14159 * self.r * self.r
    fn string name()
        return "circle"

fn main()
    let Drawable d = Drawable(Circle(2.0))
    output(d.area())          // 多态分派：按构造时的动态类型
    let Drawable[] shapes
    shapes = push(shapes, d)  // 接口值可入列表（16 字节值语义）
    return
```

- **隐式实现**：struct 拥有与接口方法同名、同签名（除 self）的方法即满足，
  无显式 impl 声明；构造 `IfaceName(structValue)` 时逐一核对方法集与签名，
  缺失/不匹配编译期报错。
- **表示**：接口类型 = 句柄 struct `iface$<名>` { ptr data; ptr vt }（16 字节）。
  构造 = struct 值堆拷贝（data 堆块带引用计数，最后一个引用释放时归还，
  与闭包 env 同策略）
  + vtable 指针绑定；方法调用 = `vt[slot](data, args...)` 间接分派。
  vtable 布局 = `[方法…, clone, release]`。
- **值语义与接收者**：接口值拷贝（声明初始化、赋值、传参、入列表/数组、
  返回、struct 字段）按底层动态类型的 vtable `clone` 槽深拷贝 data 堆块
  （新分配 + 新 rc 份额），各副本独立——改一侧不影响另一侧。方法调用
  接收者可为任意接口值表达式：位置接收者（变量/字段/元素）按地址分派，
  方法内修改写回原处；临时值（构造结果、函数返回值）按副本分派。
- **接口作泛型实参**：`Box<Drawable>`、`Holder<Drawable>[]` 等合法
  （泛型实例字段/元素按接口值深拷贝语义管理）。
- **限制**：接口方法实参限位置实参（`copy`/`ref`/命名实参不支持）；
  接口声明本身不带类型参数（`interface Name` 仅支持 `: 父接口` 继承）。
  方法返回支持标量/string/指针与聚合（列表/数组，按值语义深拷贝转移）。
- self 约定与 struct 方法一致（隐式首参 = 接收者引用，方法体内 `self.x`）。

### 27.1 接口继承

```zfy
interface Animal
    fn string name()

interface Pet: Animal
    fn string owner()
```

- `interface A: B` 声明继承：A 的方法集 = B 的全部方法 + 自身方法
  （父方法在前，vtable 槽序与声明序一致）。
- struct 实现 A 时必须同时实现 B 的全部方法；子接口重定义父方法（同名
  同签名出现两次）编译期报错。
- 多层继承扁平化展开；`Pet(implValue)` 构造出的接口值可当 `Animal` 用
  （赋给 Animal 变量/实参，前缀槽方法分派不变）。

### 27.2 接口默认方法体

```zfy
interface Greeter
    fn string greet()
    fn void hello()
        output(self.greet())   // 默认实现：未实现时 struct 直接继承

struct Robot
    fn string greet()
        return "beep"
```

- 接口方法签名行后跟缩进块即为**默认方法体**；struct 未实现该方法时
  自动按默认体合成（`struct.m$=default` 隐藏方法），实现了则用自身的。
- 默认体内可调用同接口其他方法（含只有默认体的方法、被 struct 覆盖的
  方法——动态分派按 struct 实际实现）。
- 合成方法签名与接口声明一致；self 类型为实现 struct。

## 28. 泛型约束与泛型 struct 方法

### 28.1 约束语法

```zfy
fn <T: num> T gadd(let T a, let T b)
    return a + b

fn <T: cmp> i32 cmin(let T a, let T b) ...
struct Pct<T: num>
    T v = 0
    ...
```

- 约束三档：**num** = 算术+比较（整数/浮点）；**cmp** = 比较（数值/string/
  char/bool）；**any**（默认）= 无约束（仅值语义通用操作）。
- **实例化实参校验**：调用点/构造点/显式类型实参处核对——违反报
  `type argument string does not satisfy constraint 'num' of gadd`
  （E3000，位置在调用处而非实例体内）。
- **dry check（早暴露坏体）**：从未实例化、且类型参数全带 num/cmp 约束的
  泛型函数，编译尾部用代表类型（num→i64/f64、cmp→i64/string 双代表）
  实例检查一次——未定义变量等语义错误不再静默逃逸；任一代表通过即放行
  （抑制误报）。无约束泛型不做 dry check（无法选代表）。

### 28.2 泛型 struct 方法

```zfy
struct Pct<T: num>
    T v = 0
    fn T twice()
        return self.v + self.v
    fn f64 as_f()
        return cast(self.v, f64)

let Pct<i32> p = Pct(5)
p.twice()   // 10——方法随实例化实例化，self 类型 = Pct<i32>
```

- 方法在 struct **实例化时**逐个实例化（`<S>__<m>$<实参tags>` 全局函数），
  self 类型 = 实例（ref 传参）；方法表按 (实例名, 方法名) 分派。
- 逐实例检查：i32 实例里 `self.v * 100.0` 报 E3190（混型）——与泛型函数
  同一"按实例重查"语义，约束保证实参在允许集合内。
- 方法体内支持 `let T` 局部变量（随实例替换）；泛型 struct 实例的方法
  参与 interface 隐式实现（`let Wrap<i32> w = Wrap(9)` 后 `Show(w)` 按
  实例方法集核对，接口构造时给出具体实例值）。
- 字面量构造 `Pct(7)` 按上下文落型：声明初值（`let Pct<i32> p = Pct(7)`）、
  赋值、函数实参、`push` 元素、struct 字段的目标类型为具体实例时，省略的
  类型实参由该期望填充；无上下文期望时字面量实参仍按默认 i64/f64 推断，
  需显式注解或 cast 固定。
- 值位置不支持 `Wrap<i32>(9)` 这类显式类型实参写法（`<...>` 只在类型
  位置合法）；需要固定实例时用类型注解声明后使用（如上一行写法）。

### 28.3 增量构建缓存

- `zfyc build` 成功后写 `<输出名>.zfydeps` 依赖清单：主文件 + 全部 mod/use
  加载的模块文件（含 stdlib）+ runtime.c + zfyc 自身的内容 hash。
- 下次 build：清单存在、全部 hash 未变且 exe 存在 → 跳过编译链接，
  打印 `zfy: up to date: <exe> (ZFY_FORCE=1 to rebuild)`。
- `ZFY_FORCE=1` 强制全量重建；任一依赖（源文件/runtime/编译器本体）变化
  即自动全量重编。注意这是**构建级缓存**（非 per-module 独立编译）——
  模块级增量仍在 #11 路线图上（per-module 缓存 → 真独立编译）。

## 29. panic 策略可配置：try / panic_msg / 退出档位

```zfy
fn void risky()
    let i32[] a
    a = push(a, 1)
    output(a[5])          // 越界 → panic（默认 die 路径）

fn main()
    let bool ok = try(risky)      // 正常完成 = true，panic 被捕获 = false
    if !ok
        let string msg = panic_msg()   // 被捕获的 panic 消息
        output("caught: ", msg)
    return
```

- `try(f)`：f 为**零参 lambda** 或**零参具名函数名**（函数名自动包装为
  wrapper 闭包，与 spawn/容器谓词同机制）。返回 bool：f 正常完成 = true；
  f 内部发生 panic（含数组越界、除零、cast 失败等全部运行期 die 路径）=
  捕获并返回 false。带参闭包编译期报错。
- `panic_msg()`：返回最近一次被 try 捕获的 panic 消息；无捕获上下文时为
  空串。消息在下次 try 调用时重置。
- 捕获实现 = runtime setjmp/longjmp（**链表帧栈，v3.27 起支持任意嵌套
  深度**：内层 try 先捕获，未处理 panic 向外层传播）；被捕获的 panic 不走
  panic_handler、不 exit 101，控制流回到对应 try 调用点。
- 未被 try 包裹的 panic 行为完全不变（panic_handler 或打印位置 + 退出）。
- **退出档位（v3.27，zfyc 编译选项）**：
  - `--panic-exit <n>`：panic 退出码改为 n（默认 101）；
  - `--panic-mode abort`：panic 改为 abort()（调试器断点场景；默认 exit）。
  两档只影响未捕获 panic 的进程终止方式，try 捕获路径不受影响。
- try 捕获后 f 中已分配的堆资源：句柄类（chan/mutex/闭包 env/iface 装箱）
  走引用计数（§30），栈回退丢弃的 rc 份额由其余持有者或全局注册表回收；
  string/seq 局部资源 v1 不保证即时释放（与进程退出同语义）。

## 30. 资源管理与引用计数（v3.27）

- **move-only 类型**：`File`、`mutex$`、`thread$`、`chan$<T>`、`iface$X`、
  `closure$<sig>`——赋值/传参 = 所有权转移（源槽失效），move 后使用报
  运行期错误；此类类型**不能作 struct 字段**（编译期拒绝）。
- **作用域退出自动释放（RAII）**：句柄变量离开作用域自动释放
  （mutex DestroyCS / thread CloseHandle / chan 隐式 close + 清残留消息 /
  iface 走 vtable release / 闭包 env 级联释放捕获副本）。显式 close/join
  后句柄置空，重复释放安全。
- **引用计数**：chan 对象、mutex CS、闭包 env 块、iface 装箱堆块带原子
  rc 头——浅拷共享（闭包捕获 chan、iface 进数组/赋值、闭包赋值）自动
  retain，最后一个持有者释放时才真正回收（杜绝共享双释放/悬垂）。
  thread 句柄除外（OS HANDLE 不可计数，语义为 move-only；join 幂等、
  detach 放弃所有权但线程继续运行，v3.31 §21.1）。
- **spawn 移交**：spawn 实参闭包的 env 所有权移交线程——线程体结束线程侧
  释放（含捕获副本级联）；宿主槽置空不再释放。
- **全局资源兜底**：全局句柄/容器登记进程级注册表，任何退出路径
  （正常/panic/handler 自定义退出）atexit 统一回收——零泄漏承诺。
  `ZFY_LEAK_DEBUG=1` 运行时 stderr 打印回收清单与 rc 差值报告
  （`[zfy-leak] rc 对象泄漏: N`，N=0 为平衡）。

## 31. 裸机模式（freestanding，v3.31）

`--freestanding` 生成不依赖操作系统 / CRT 的裸机产物：入口由用户提供、
panic 走用户钩子、OS 依赖的内建在**编译期**拒绝、运行时只链接纯计算
核心层。普通模式（不带该开关）行为完全不变。

### 31.1 编译开关

```
zfyc build 程序.zfy --freestanding [--no-link] [--target <triple>] [--link-script <path>]
```

- `--freestanding`：进入裸机模式。可与 `--wrap-overflow`、`--panic-mode`
  等既有开关任意组合（开关解析在 CLI，先于编译管线生效）。
- `--no-link`：只产出 `.ll`（及用户自行转出的 `.o`），不做最终链接。
  宿主（Windows）通常无法链接裸机 ELF 目标，交叉场景用它交接给
  `clang`/`ld` 与链接脚本。
- `--target <triple>`：LLVM 目标三元组（如 `x86_64-unknown-elf`、
  `riscv32-unknown-elf`）；缺省沿用宿主三元组。
- `--link-script <path>`（等价写法 `--linker-script`）：传给链接器
  `-Wl,-T,<path>`。仅 ELF 目标可用；Windows/MSVC 目标报错。
  `--no-link` 时只记录不传给链接器。

### 31.2 入口点：`fn _start()`

- 裸机入口是用户写的 `fn _start()`：**无返回值、无参数**
  （`void` 返回可省略返回类型）。生成 `define void @_start()`，
  不再生成 `main`。
- 函数体先由编译器合成的入口包装调用 `zfy.globals` 完成全局变量
  初始化，再注册 panic 钩子，最后调用户 `_start` 本体。
- 同时存在 `fn main()` 是允许的（自行链接 CRT 时可用），但入口仍取
  `_start`。缺少 `_start` 且缺少 `main` 时报
  `freestanding requires fn _start()`。
- 普通模式（无 `--freestanding`）仍必须提供 `fn main()`。

### 31.3 panic_handler：必需钩子

裸机必须提供：

```
fn panic_handler(let string msg)
    return
```

- 签名固定为 `(string) -> void`，无返回类型（`void`）。缺失或签名不符
  在**编译期**报 `freestanding requires a panic handler`。
- 运行时把所有 panic 路径（panic 内建、整数溢出检查、除零、断言失败、
  frac 错误、越界）统一改调用户 handler；handler 返回后进入死循环
  （`for(;;)`），保证不返回宿主。
- 代码生成会生成稳定的适配器 `define void @zfy.fs.panic_adapter`
  （把 runtime 的 `(i32, string)` 回调适配到用户 `(string)` handler）
  并在入口处 `zfy_set_panic_handler` 注册。

### 31.4 不可用能力（编译期拒绝）

裸机没有 OS 层，以下能力在类型检查阶段直接报错（位置指向使用处），
消息统一为 `<名称> is not available in freestanding mode`：

| 类别 | 名称 |
| --- | --- |
| 文件 I/O | `File` 类型、`open`/`read_all`/`read_line`/`read_lines`/`write`/`writeln`/`close`/`exists`/`read_file`/`write_file` |
| 控制台 I/O | `output` 语句、`input` 语句 |
| 并发 | `spawn`/`join`/`detach`、`mutex_new`/`lock`/`unlock`、`chan_send`/`chan_recv`/`chan_close`/`chan_len` |
| 时间 | `now`/`tick_ms`/`sleep`/`sleep_ms`/`localtime`/`mktime`、`timer`/`timer.add`/`timer.remove`/`timer.now`/`time.sleep` |
| 环境 | `os_args`/`os_env`、`try`（依赖 setjmp/longjmp） |
| GUI | `ui` 关键字及全部窗口/组件内建（依赖 Win32/GDI） |

保留可用：纯计算、字符串/数组/列表/map/set、struct、frac、整数溢出
检查、`assert_eq`、`rand`（纯算法）、原子/volatile 内建。

### 31.5 运行时裁剪与内存

`--freestanding` 链接时 runtime.c 以 `-DZFY_FREESTANDING` 编译：
去掉 `windows.h` / 线程 / 文件 / GUI / QPC 计时 / output / input /
时间 / 环境变量等 OS 段，只保留内存、panic 适配器、字符串与容器
rc/free、frac 运算、溢出检查、断言、rand、math 基础。

裸机内存优先弱符号：

```
void *zfy_malloc(size_t n);   /* __attribute__((weak)) */
void  zfy_free(void *p);      /* __attribute__((weak)) */
```

用户可实现同名强符号覆盖；未提供时默认使用 16MB 静态缓冲的 bump
分配器（`zfy_free` 空操作，`zfy_realloc` 新分配 + 拷贝）。本文件内
`malloc/free/realloc/calloc` 经宏重定向到该层。

### 31.6 全局初始化顺序

`_start` 入口 → `zfy.globals`（顶层变量初始化，按声明顺序）→
注册 panic 钩子 → 用户 `_start` 本体。裸机下不做资源登记表 /
atexit 兜底回收（无进程退出路径）。

### 31.7 示例

```
fn panic_handler(let string msg)
    return

let i64 total = 0

fn _start()
    let i64 i = 1
    while i <= 100
        total = total + i
        i = i + 1
    assert_eq(total, cast(5050, i64))
```

编译：`zfyc build demo.zfy --freestanding --no-link` → 产出 `demo.ll`。
