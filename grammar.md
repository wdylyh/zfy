# zfy 语言规范（v3.15.0，2026-10-23）

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
  `(45.34,78,)` = 45.347878…。词法期即折算为分数 num/den；
  frac 上下文按分数构造（见 §5）、浮点上下文按实数除法、整数上下文向零截断
  （恰好是"不四舍五入"截取）。总位数限 18 位，超长报错。
- **字符串**：双引号。转义：`\n \t \r \0 \a \b \f \v \\ \" \'`。
  串内禁止裸换行（要换行就写 `\n`）。
- **字符**：单引号**单个**字符，同一转义集（`'\n'`、`','`）。
- **运算符**：`== != <= >= += -= *= /= %= ++ -- => -> ??` 与单字符
  `( ) [ ] { } , ; : = + - * & / % < > . ? ! ^`。
  - 解引用是 `p^`（不是 `p*`）。
  - 错误传播是 `e?`。
- **分号**：语句位置非法（写了报错）；仅空语句占位可用。

## 2. 关键字（45 个）

```
if else while for return true false pub mod use break continue
const frac unred reduce and or not output input cast remove import as
fail panic err sep end delim struct packed move copy ref null unsafe
extern type let fn array list xor
```

- `array`/`list`：保留用于报错提示，**不能当标识符**。
- `sep`/`end`/`delim`：output/input 的命名参数名。
- `err`：`??` 块内的错误值绑定名。
- `xor`：二元异或运算符。**`^` 不是异或**——它只作后缀解引用。

## 3. 类型系统

- **整数**：`i8 i16 i32 i64 i128`（有符号）、`u8 u16 u32 u64 u128`（无符号）。
- **浮点**：`f16 f32 f64 f128`。
- **其他标量**：`bool char string void`。
- **分数**：`frac` —— `let i32 frac f = 1/4`。宽度即底层整型宽度
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
    `n/d` 形式→`i32 frac`、string/char/bool 按字面量；
    **其他表达式报 E3000**（如 `let x = 1/4 + 1/4` ✗，写 `let i32 x = ...`）。
- **`let frac f = 1/4` 合法**（frac 视同给出类型），但初值必须是可直接推断的
  字面量；复合表达式请显式写宽度：`let i32 frac f = ...`。
- `const` 必须带初值；const 深不可变（struct 字段/数组元素也不可写）。
- `unred` 必须有 `frac` 修饰或 `n/d` 形态初值（unred = 不自动约分）。
- `ref` 只能用于函数参数（§6）。
- **一行多声明器**：`let i32 a, b = 1`（a 零值 b=1）、
  `let string a[], b[]`、`let i32 arr1[3], arr2[2] = 7, 8`。
  带 `= 初值` 的数组/列表声明器须为该行最后一个。顶层与 for 头部单声明器。
- 顶层 `let` = 全局变量（非 const 也可赋值）；`let i32 frac const g = 3/4`
  这类顶层 const frac 合法。

## 5. ⚠️ n/d 字面量与 frac 运算（重要规则）

**frac 目标（frac 变量声明/赋值/复合赋值、frac 函数 return、frac 参数实参、
frac 序列元素）的初值/右值如果是四则表达式（`+ - * /` 与一元负号），整棵
表达式按分数计算**——表达式内的 `n/d` 按分数构造、普通整数字面量按 `n/1`
参与、浮点字面量按其二进制精确值转分数（如 `0.5 → 1/2`），结果约分后存入：

```
let i32 frac a = 1/4          # ✓ a = 1/4
let i32 frac b = 1/4 + 1/4    # ✓ b = 1/2（整棵表达式按分数算）
let i32 frac c = 1/4 + 0.5    # ✓ c = 3/4（0.5 精确转 1/2）
c = c + c                     # 1/2 + 1/2 = 1/1
let i32 frac d = 1/3
d += 1/6                      # ✓ d = 1/2
```

**无 frac 修饰的目标不受影响**：`let f64 x = 1/4 + 1/4` 仍是先整数除法
再浮点相加（= 0.0），`let i32 x = 7/2` 仍是整数除法（= 3）。
需要"分子分母不除"的字面量对直接存入 frac 变量即可（`let i32 frac u = 6/48`
→ u = 6/48，配 `unred` 不约分、默认存储自动约分为 1/8）。
frac 变量间的 `+ - * /` 是分数运算；非 unred 存储位自动约分。
`return 1/4`（frac 函数）、`f = 5`（f 为 frac 变量）等"整数面值落 frac 位"
自动提升为分数（`5 → 5/1`）——均合法。

## 6. 函数

```
fn [TYPE|void] [frac] [unred] 名字(参数列表) 缩进块
fn <T, U> [TYPE|void] [frac] [unred] 名字(参数列表) 缩进块    # 泛型
fn main() 缩进块                                             # 入口特例
```

- **main 特例**：必须写 `fn main()`（括号必须有）；不给返回类型（隐含 i32）、
  不给参数；`return` 可省（隐式返回 0），裸 `return` ≡ `return 0`；
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
- 跨文件 use 导入 struct 后方法照常可用（`mod random; use random::Random`
  → `rng.next_u64()`）。
- **泛型 struct 方法**见 §28.2。

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
- 移位量 ≥ 位宽 = 未定义（LLVM poison），自行保证 0 ≤ k < 位宽。

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
- **字面量实参**：期望 frac 的位置 n/d 字面量按分数构造（`addf(1/4, 1/4)`
  = 1/2）；期望 string 的位置 char 自动提升。
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
| extern | `extern "C"` + 缩进块；**每行：`返回类型 [frac] 名(参数)`——返回类型是旧式直接写类型（不加 let），参数是 let 形式**：<br>`i64 strlen(let string s)` ✓、`let i64 strlen(...)` ✗ |

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

### 12.1 随机数标准库（stdlib/random.zfy）

`stdlib/` 目录下的文件模块可被任意源文件引用（resolve 沿父目录链查
`<祖先>/stdlib/名.zfy`）。用法：

```
mod random;
use random::{Random, seed_from_u64, seed_from_entropy, SecureRandom, secure_new}

fn main()
    let Random rng = seed_from_u64(42)     # 可复现
    let i64 n = rng.int_range(1, 100)      # [1, 100) 无偏
    let f64 x = rng.uniform()              # [0, 1) 53 位精度
    let SecureRandom sr = secure_new()     # OS 熵源 + ChaCha20
    let string tok = sr.token(32)          # base64url 字符集 token
```

**Random（非加密，xoshiro256\*\*，周期 2^256-1）**：

| API | 说明 |
|---|---|
| `next_u64()` / `next_u32()` | 引擎原语 |
| `uniform()` / `uniform32()` | [0,1)，f64 取高 53 位 / f32 取高 24 位（不会取到 1.0） |
| `boolean()` / `boolean_p(p)` | p=0.5 / 伯努利 P(true)=p |
| `int_range(lo,hi)` / `int_range_incl(lo,hi)` | i64 半开 [lo,hi) / 闭 [lo,hi] |
| `uint_range(lo,hi)` / `uint_range_incl(lo,hi)` | u64 同上 |
| `normal(mean,stddev)` / `exponential(lambda)` / `geometric(p)` | Box-Muller 正态 / 指数 / 几何（试验次数口径 ≥1） |
| `shuffle(ref xs)` / `shuffle_u64(ref xs)` | Fisher-Yates 洗牌（i32/u64 列表，原地） |
| `choice(xs)` / `sample(xs,k)` | 均匀选一（空表 panic）/ 无放回抽 k（k>n 截断） |
| `fill_bytes(ref buf)` / `hex_string(n)` / `ascii_char()` | 随机字节 / 小写 hex 串 / 可见 ASCII 字符 |

构造：`seed_from_i64` / `seed_from_u64` / `seed_from_string`（FNV-1a）/ 
`seed_from_entropy()`（OS 熵源）。播种一律 SplitMix64 扩展（相近种子不相关）。

**SecureRandom（加密，ChaCha20 纯 zfy 实现）**：

| API | 说明 |
|---|---|
| `next_u64()` / `next_u32()` / `boolean()` / `boolean_p(p)` / `uniform()` | 同 Random 语义 |
| `int_range` / `int_range_incl` / `uint_range` / `uint_range_incl` / `uint_below` | 同 Random 语义 |
| `fill_bytes(ref buf)` | 随机字节 |
| `token(n)` / `hex_token(n)` | base64url 字符集（A-Z a-z 0-9 - _，每字符 6 位熵，无偏）/ 小写 hex |
| `reseed()` | 重新从 OS 熵源播种 |

构造：`secure_new()`（OS 熵源：Windows SystemFunction036 / POSIX getentropy）/
`secure_from_string(s)`（可复现，仅测试用）。状态布局：sigma 常数 + 256 位 key
+ counter + 96 位 nonce，块用尽自动递增 counter。

**设计要点**：区间采样用 Lemire 无偏乘法（u128 高 64 位 + 阈值拒绝），
杜绝 `x % n` 模偏差；`Random`/`SecureRandom` 类型隔离（加密强度显式选择）。

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
- i64 及以下整数溢出**静默回绕**；`/` `%` 向零截断（`-7 / 2 = -3`）。
- 整数除零 = 硬件异常；frac 除零走 panic。
- 所有权：返回数组/列表/string = 指针移交（RVO）；聚合赋值/传参默认深拷贝，
  `move`/自动 move（源变量此后不再出现时）免拷贝。
  **自动 move 循环限制**：循环体内（while/for 任意嵌套深度）的
  实参/赋值一律不自动 move、走克隆——源码位置判不出"下一轮迭代还会用"
  （`while` 里 `f(r)` 反复传同一列表是安全且常见的，误 move 会致
  第二轮空指针崩溃）；循环外顶层"最后使用"仍自动 move 免拷贝。
- string 槽独占堆串（MCopy strdup 保证）；`s[i] = c` 原地写（越界 panic）。
- 程序入口前执行 `zfy.globals`（顶层变量初始化）。

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
- extern 不支持序列（数组/列表）返回。
- 溢出无检查（i128 除外：字面量编译期范围校验）。
- 移位量 ≥ 位宽未定义（LLVM poison）；`x & 1 == 1` 按优先级解析为
  `x & (1 == 1)`，位运算与比较混用建议加括号。
- `n/d` 字面量除式按分数字面量语义处理（§5），浮点缩放常量请写成
  科学计数法（如 `1.1102230246251565e-16`）而非 `1.0/9007199254740992.0`。
- 跨文件 use 的 struct/类型别名作声明类型：解析器按"Ident 后跟 Ident"
  形状识别，`let Pt p` / `let Random rng` 均可。
- **`**` 整数幂**：≤64 位走 zfy_pow_ll/ull；
  i128/u128 走 zfy_pow_u128/i128（64 位对接口，指数支持完整 128 位，
  如 `2 ** 2^64`）；跨宽度提升与通用算术一致（`u64 ** i32` 隐式宽化）；
  整数负指数 = 0；整数溢出回绕无检查。
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
> 薄绑定）→ **L2** `stdlib/widgets.zfy`（9 组件 + App 容器，damage
> 脏区跟踪，只重绘变化的组件）→ **L3** 应用（examples/demos）。
> 仅 Windows（Win32 + GDI）；非 Windows 平台 GUI 桩全部返回失败/空。

### 18.0 30 秒上手（App 容器，推荐路径）

```
mod gui;
mod widgets;
use widgets::{App, Label, Button, SC, C_BG}
use gui::{gui_w, gui_h, gui_frame_sleep}

fn main()
    let App app = App()
    if app.open(280, 340, "zfy 计算器") != 0      // 0=成功（逻辑尺寸）
        return 1
    let Button b = Button(x=0, y=0, w=10, h=10, text="点我")
    app.add_button(b)
    let i32 prev = 0
    let i32 last_w = 0
    while app.alive()
        // 响应式布局：窗口可拖拽缩放，每帧比对尺寸重排
        if gui_w() != last_w
            ...重算组件位置...
        app.step()                                // 泵事件+更新+按需重绘
        if b.clicks != prev                       // 按钮被点（读计数器差值）
            prev = b.clicks
            ...业务...
        gui_frame_sleep(tick_ms())                // 限帧（App 已修 CPU 空转）
    app.close()
```

要点：**组件交互结果全部通过字段回读**（Button.clicks / Slider.value /
ListBox.sel / Menu.sel+clicks / Checkbox.checked），不用回调——业务每帧
对比差值。响应式布局参考 `demos/calculator.zfy`。

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
| `InputBox` | text、focus | 单行输入，点击获焦，键盘输入 |
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

内置编辑能力：点击/方向键/Home/End 移动光标、回车拆行、退格删字
（行首回退合行）、Delete、滚轮上下滚动。**UTF-8 码点对齐**：cx 是
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
```

- 参数**必须显式类型**（暂无上下文推断）。
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
- 闭包可再作为捕获/参数/返回值传递（v1 限标量/string/bool/char/指针/
  闭包句柄类型的捕获）。

### 20.3 捕获语义

- **默认值捕获**：体内引用的外层局部变量自动按值捕获（声明点快照，
  深拷贝；string 也是深拷贝）。
- **显式引用捕获** `fn [&x, y](...) => ...`：`&x` 引用捕获（读写穿透
  到外层变量），`y` 值捕获。
- 全局（`@` 名）与 const 不经捕获、直接可见。
- v1 已知限制：捕获环境不回收（生命周期 = 进程）；引用捕获变量逃逸
  出作用域后调用为未定义行为（无逃逸分析）；seq/struct/frac 不可捕获。

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

- lambda 参数必须显式类型；嵌套函数参数限标量；块形式必须显式 `-> T`。
- 捕获类型限标量/string/bool/char/指针/闭包句柄。
- 引用捕获逃逸、env 堆块回收见 20.3。

## 21. 并发

> 线程收闭包（env 堆块生命周期 = 进程，天然适配线程）；
> 共享数据 v1 约定走全局变量 + 原子内建；容器（map/set/列表）非线程
> 安全，跨线程共享须外部 mutex 保护。

### 21.1 线程：spawn / join

```zfy
let t = spawn(fn() => output("hi"))   // 收 lambda
let t2 = spawn(worker)                // 收裸函数名（自动包 wrapper）
join(t)                               // 阻塞等待；句柄置空，重复 join 报错
```

- 线程体签名须 `fn() -> void`；spawn 返回线程句柄（`let t =` 推断）。
- 闭包捕获照常：值捕获（声明点快照）安全；引用捕获逃逸为 UB（同 §20）。

### 21.2 原子操作（32/64 位整数全局/局部变量）

```zfy
atomic_inc(&counter)                  // 自增（void，语句级）
let old = atomic_add(&counter, 10)    // fetch_add：返回加前旧值
atomic_store(&counter, 5)
output(atomic_load(&counter))
```

- 实参 `&var` 取址；类型限 i32/u32/i64/u64（统一按位模式操作）。

### 21.3 互斥锁

```zfy
let m = mutex_new()                   // 声明即构造（句柄捕获安全）
lock(m)
// ... 临界区 ...
unlock(m)
```

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
- 已知限制：join 后句柄置空；mutex/chan 不回收（生命周期 = 进程）；
  output 多线程交错不保证；无逃逸分析（引用捕获跨线程逃逸 = UB）。

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

- 变体载荷类型任意（标量/string/指针/列表；列表载荷 v1 限 1 个）。
- 实现：统一编译为 struct `enum$<名>` { i32 tag; f0..fn }——载荷按
  **类型分槽**（同类型变体载荷共享槽，`Rect(f64,f64)` 占两个 f64 槽），
  因此不同变体载荷类型可以不同；值语义 assign/深拷贝按 struct 走。

### 22.2 构造

```
let Color c = Color.Green      // 零载荷变体裸名（也可写 Color.Green()）
let Shape s = Shape.Circle(2.0)
let Shape s2 = Shape.Rect(3.0, 4.0)
```

- 构造 = tag + 载荷全字段 struct 构造，类型不符编译期报错。

### 22.3 判别与解构

变体判别/载荷提取统一走 match（§23）；v1 不直接暴露载荷字段名
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
- **match 初始化表达式**：`let T x = match ...`——每个 arm 体
  须为单表达式语句，脱糖为 `x` 零值声明 + 各 arm 对 `x` 赋值的透明块；
  限标量/struct/string 形状（可零初始化），const 不支持。返回/嵌套
  表达式位置的 match 暂不支持（已知限制）。
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

- 泛型实例化 `Box<i32>` 的类型实参支持：标量/string/struct/指针/`T!`，以及
  **列表 `T[]`、定长数组 `T[N]`**：`Box<i32[]>`、`Pair<i32[], string>`、
  `Box<i32[3]>`、`Box<i32!>` 均合法（T! 实例字段为聚合，§11）。
- 实现层面单 ptr/值形态，单态化零成本；mangle 名扩展
  `Box$list$i32$...`（list$）/ `Box$arr$i32$3`（arr$…$长度）/
  `Box$err$i32`（err$，T! 实参）前缀，`$` 分隔保证与源码标识符无碰撞。
- **不可作类型实参**：frac、File、函数类型；容器 map/set 的键值实参仍限
  ≤64 位标量/string（§19.6）。
- 已知限制：泛型 struct 模板的 `T` 字段须带默认值。
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
  构造 = struct 值堆拷贝（生命周期 = 进程，不回收，与闭包 env 同策略）
  + vtable 指针绑定；方法调用 = `vt[slot](data, args...)` 间接分派。
- **限制（v1）**：接口方法实参限位置实参；接口方法调用接收者须为变量；
  接口值浅拷贝（共享 data 堆拷贝）；接口名经别名解析（`let Drawable d`），
  不可再嵌泛型实参。方法返回支持标量/string/指针与聚合（列表/数组，
  按值语义深拷贝转移）。
- self 约定与 struct 方法一致（隐式首参 = 接收者引用，方法体内 `self.x`）。

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
  参与 interface 隐式实现（`Show(Wrap<i32>(...))` 按实例方法集核对）。
- 已知限制（v1）：泛型 struct 方法不参与 interface 的跨实例动态分派
  （接口构造时按具体实例核对）；字面量构造 `Pct(7)` 默认 i64——经
  `let Pct<i32> p = Pct(7)` 或先声明变量再 push 落型。

### 28.3 增量构建缓存

- `zfyc build` 成功后写 `<输出名>.zfydeps` 依赖清单：主文件 + 全部 mod/use
  加载的模块文件（含 stdlib）+ runtime.c + zfyc 自身的内容 hash。
- 下次 build：清单存在、全部 hash 未变且 exe 存在 → 跳过编译链接，
  打印 `zfy: up to date: <exe> (ZFY_FORCE=1 to rebuild)`。
- `ZFY_FORCE=1` 强制全量重建；任一依赖（源文件/runtime/编译器本体）变化
  即自动全量重编。注意这是**构建级缓存**（非 per-module 独立编译）——
  模块级增量仍在 #11 路线图上（per-module 缓存 → 真独立编译）。
