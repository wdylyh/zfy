# zfy 语言规范（v2，2026-10-10）

> 本版每一节都经过编译器实测校准（examples 69 例全回归通过）。
> 与 v1 的主要差异：修正 File I/O 示例语法（补 `let`）、修正命名实参适用范围、
> 补 ErrCode.EOF、写清 n/d 字面量陷阱与 `??` 块形式、写清缩进规则、
> input 语义详述、新增"常见错误对照"一节。
> 适用编译器：commit 之后的 w-021 版本（`compiler/_build/zfyc.exe`）。

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
- **注释**：
  - `// 行注释`（到行尾；**行注释内可以写中文**）。
  - `/* 块注释 */`，**可嵌套** `/* a /* b */ c */`；块注释内同样可写中文。
  - 注意：不是 `(* ... *)`（Pascal 风格写法不是注释，会报错）。
- **标识符**：`[A-Za-z_][A-Za-z0-9_]*`，区分大小写。
- **数字**：`123`、`0x1A`、`0b1010`、`1.5`、`1e-3`。
  超出 i64 的十进制字面量只能用于 i128/u128 上下文。
- **字符串**：双引号。转义：`\n \t \r \0 \a \b \f \v \\ \" \'`。
  串内禁止裸换行（要换行就写 `\n`）。
- **字符**：单引号**单个**字符，同一转义集（`'\n'`、`','`）。
- **运算符**：`== != <= >= += -= *= /= %= ++ -- => -> ??` 与单字符
  `( ) [ ] { } , ; : = + - * & / % < > . ? ! ^`。
  - 解引用是 `p^`（不是 `p*`）。
  - 错误传播是 `e?`。
- **分号**：语句位置非法（写了报错）；仅空语句占位可用。

## 2. 关键字（44 个）

```
if else while for return true false pub mod use break continue
const frac unred reduce and or not output input cast remove import as
fail panic err sep end delim struct packed move copy ref null unsafe
extern type let fn array list
```

- `array`/`list`：旧关键字语法已删除，仅保留用于报错提示，**不能当标识符**。
- `sep`/`end`/`delim`：output/input 的命名参数名。
- `err`：`??` 块内的错误值绑定名。
- 10 个传统类型别名（int/long/double 等）**已删除**，不再是关键字——
  用它们当类型名会报"迁移提示"错误（见 §16 对照表）。

## 3. 类型系统

- **整数**：`i8 i16 i32 i64 i128`（有符号）、`u8 u16 u32 u64 u128`（无符号）。
- **浮点**：`f16 f32 f64 f128`。
- **其他标量**：`bool char string void`。
- **分数**：`frac` —— `let i32 frac f = 1/4`。宽度即底层整型宽度
  （`i32 frac`、`f64 frac` 等；`frac` 单写 = `i32 frac`）。
- **错误值**：`T!`（如 `i32!`）—— 可能失败的操作类型（见 §11）。
- **指针**：`T*`；指向 const 的指针 `T* const`。解引用 `p^`。
  指针算术与 `p[i]` 必须在 `unsafe` 块内。
- **数组/列表**（类型后缀与名字后缀两种写法等价）：
  - `T[N]` ≡ `T name[N]`：定长数组。
  - `T[]` ≡ `T name[]`：动态列表。
  - 可叠加：`T[3][4]` 定长二维、`T[][]` 列表的列表。
- **函数类型**：`T(参数类型列表)`，如 `i32(i32)`。
  只允许出现在 `type` 别名、函数参数位、struct 字段位。
- **泛型实例化**：`Box<i32>`（泛型 struct，见 §7）。
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

**修饰符固定顺序：类型 → frac → const → unred**。写错顺序报错并提示
（如 `let unred frac x` ✗ → `let frac unred x` ✗ → 正确 `let i32 frac unred x`）。
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

## 5. ⚠️ n/d 字面量与 frac 运算（重要陷阱）

**`1/4` 只有"整个表达式恰为 n/d 形式"时才按分数构造**（分子/分母不执行除法）。
**复合表达式按整数运算**：

```
let i32 frac a = 1/4          # ✓ a = 1/4（n/d 字面量）
let i32 frac b = 1/4 + 1/4    # ⚠ b = 0/1！！1/4+1/4 先按整数算（1/4=0, 0+0=0）
let i32 frac c = 1/4          # ✓；再做 c = c + c → 8/16 → 存入约分 1/2
```

**正确做法**：先把 n/d 字面量存进 frac 变量，再用变量做四则运算。
frac 变量间的 `+ - * /` 是分数运算；非 unred 存储位自动约分。
`return 1/4`（frac 函数）、`f = 5`（f 为 frac 变量）等"整数面值落 frac 位"
自动提升为分数（`5 → 5/1`），n/d 形式按分数构造——均合法。

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
```

- 实例化：`Point(1, 2)` 位置 / `Point(x=1)` 命名（**struct 构造支持命名实参**，
  未给字段用默认值再退零值） / `Point p`（裸声明全默认）。
- 泛型：`struct Box<T>  T v` → `let Box<i32> b = Box(v=9)`。
- struct 作数组/列表元素：值语义深拷贝；`ps[i].x = v` 直接改元素；
  const 深不可变同样生效。
- `sizeof(T)` / `alignof(T)` 编译期内建。

## 8. 语句全集

| 语句 | 语法与要点 |
|---|---|
| 赋值 | `lhs = rhs`；序列整体赋值 `a = 1, 2, 3`（目标为数组/列表槽） |
| 复合赋值 | `+= -= *= /= %=`（string 的 `+=` 为追加，rhs 可 string 或 char） |
| 自增/自减 | `i++` / `i--` |
| 条件 | `if cond 缩进块` / `else` / `else if`；**单语句可同行**：`if a > 0  output("pos")`（条件后空格+语句） |
| while | `while cond 缩进块` |
| for | `for 段1, 段2, ... 缩进块`（见下） |
| 返回 | `return` / `return expr` |
| break/continue | `break` / `continue` |
| 输出 | `output(v1, v2, ..., sep=?, end=?)`（见 §13） |
| 输入 | `input(目标..., delim=?)`（见 §13） |
| unsafe | `unsafe 缩进块`（指针算术、p[i]、p^ 必须在其中） |
| reduce | `reduce(frac变量, 次数, 起始除数)` |
| remove | `remove(列表名, 下标)` |

**for 头部规则（w-021 收紧）**：
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
+ -         左结合
* / %       左结合
一元 -e、&e
后缀：调用 f(args)、下标 a[i]、切片 s[a,b] / s[a,b:step]、
     字段/命名空间 a.b、错误传播 e?、解引用 p^
```

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
  步长字面量/常量 ≤ 0 编译期拒绝；变量步长 ≤ 0 运行期 panic。
  **没有负步长**（不支持反向切片）。
- **没有 `a..b` 区间语法**（写了报 E2042 提示逗号切片）。
- **比较**：string 与 string/char 六种比较全支持（字典序，char 提升
  单字符 string）；`"a" == 'a'` ✓。char 间 `==`/`!=` ✓，`<` 用 ord。
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
  标识符（可 `m::x`）、括号。

## 10. 顶层项

| 项 | 语法 |
|---|---|
| 函数 | `fn ...`（§6） |
| struct | `struct [packed] 名<T,U>? 块`（§7） |
| type 别名 | `type 名 = 类型` |
| 全局声明 | `let ...`（§4，无数量限制） |
| 模块（文件） | `mod 名字;` —— body 在 `名字.zfy` 或 `名字/mod.zfy` |
| 模块（内联） | `mod 名字` + 缩进块（块内为顶层项，可嵌套） |
| 导出 | `pub` 修饰任意顶层项（模块内合法；root 顶层 pub 容忍并告警） |
| use（新路径） | `use a::b::item [as x]`；分组 `use a::b::{x, y as z}`；整模块 `use a::b [as m]`；单段整模块 `use 模块名 [as 别名]`（成员以 `别名.成员名` 访问，仅 pub 可见） |
| use（旧文件 legacy） | `use 名字.zfy [import 模块名] [as 别名]`；支持 `./`、`../` |
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
- 产 `T!` 的内建：`find`、`cast`（string→数值）、`input`（T! 目标）、
  `open`/`read_all`/`read_line`/`read_file`（§14）。
- 限制：`T!` 不作数组/列表元素；128 位类型不支持 `T!`。

## 12. 内建函数

**函数式**（返回值）：

| 函数 | 说明 |
|---|---|
| `length(x)` | string=字节数；数组/列表=元素数 |
| `find(s, x[, count=k])` | x 为 char 查字符、string 查**子串**；返回第 k 次出现的字节下标（`i64!`）；k 从 1 起，<1 编译期拒绝（字面量）或运行期 panic（变量）；找不到 = NOT_FOUND 错误值 |
| `trim(s, x)` | **删除 s 中所有出现的 x**（x 为 char 或 string）——不是去两端空白！ |
| `split(s, x)` | 按分隔符切分返回 `string[]`（x 为 char 或 string）；空段保留；分隔符 `'\0'` 编译期拒绝 |
| `replace(s, a, b, rep)` | 把 `s[a, b]` 闭区间替换为 rep；"替换到串尾"写 `b = length(s) - 1`。**两参形式已删除** |
| `prec(v, n)` | 格式化为总宽 n（string 按**码点数**截断/右补空格；数值转 string 后同理） |
| `utf8_len(s)` | 码点数（`length` 仍按字节） |
| `utf8_char_at(s, i)` | 第 i 个码点（0 起），返回单码点 string |
| `utf8_sub(s, a, b)` | 按码点闭区间切片 |
| `sizeof(T)` / `alignof(T)` | 编译期常量 |
| `cast(e, T)` | 显式转换（含 string→数值，产 `T!`） |
| `ord(c)` / `chr(n)` | char↔码值 |

**语句式**：`push(列表, 值)`（**恰两参**；目标是列表非定长数组；嵌套列表
`push(ll, row)` 的 row 须是列表变量/表达式，**不能 push 标量进列表的列表**）；
`remove(名, 下标)`；`reduce(x, n, 起始除数)`。

**string `+=`**：变量 `s += v`、元素 `parts[i] += v`、解引用 `p^ += v` 均支持；
v 为 string 或 char。

**string 是字节串**：`length("中文")` = 6（字节数）；按码点操作用 utf8_* 组。

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
- string 槽独占堆串（MCopy strdup 保证）；`s[i] = c` 原地写（越界 panic）。
- 程序入口前执行 `zfy.globals`（顶层变量初始化）。

## 16. 常见错误对照（新人易错速查）

| 写错的样子 | 报错/后果 | 正确写法 |
|---|---|---|
| `int x = 5`（无 let） | E2003 迁移提示 | `let i32 x = 5` |
| `i32 f() ...`（无 fn） | 迁移提示 | `fn i32 f()` |
| `fn main`（无括号） | 报错 | `fn main()` |
| `let frac unred x = ...`（顺序错） | 报错+顺序提示 | `let i32 frac unred x = ...`（类型→frac→const→unred） |
| `let unred frac x = ...` | 报错+顺序提示 | 同上 |
| `let const Outer o = ...` | 报错+顺序提示 | `let Outer const o = ...` |
| `let x = 1/4 + 1/4`（推断） | E3000 | `let i32 x = ...` 或 `let frac x = 1/4` |
| `let i32 frac b = 1/4 + 1/4` | **b = 0/1（整数除法陷阱）** | `let i32 frac a = 1/4` 后 `b = a + a` |
| `s[1..3]`（Python 切片） | E2042 提示 | `s[1, 3]` |
| `s[0, 4, 2]`（逗号步长） | 报错+提示 | `s[0, 4:2]` |
| `f(x=1)`（用户函数命名实参） | E3068 | `f(1)` |
| `p*`（解引用） | 报错提示 | `p^` |
| `extern` 块内 `let i64 f(...)` | E2008 | `i64 f(let string s)`（返回旧式、参数 let 式） |
| `File! f = open(...)`（无 let） | E2003 | `let File! f = open(...)` |
| `string! s = read_file(...)` | E2003 | `let string! s = read_file(...)` |
| for 头无更新段 | E2007（v2 新增，防死循环） | 补 `, i++` 或改 while |
| `push(ll, 1)`（ll 为列表的列表） | E3000（v2 新增，原来生成坏 IR） | `let i32[] row = ...` 后 `push(ll, row)` |
| `let string! w = write_file(...)` | E3005（返回 i64!） | `let i64! w = write_file(...)` |
| `replace(s, 1, 4)`（两参） | 迁移提示 | `replace(s, 1, length(s) - 1, rep)` |
| `trim(s, c)` 想去两端空白 | 语义不符（删所有出现） | 自行实现或按"删所有出现"使用 |
| `find(s, "x", count=0)` | E3079（字面量）/ panic（变量） | count 从 1 起 |
| `(* 注释 *)` | E1016 illegal character | `/* 注释 */` |
| Tab 与空格混缩进 | inconsistent indentation | 统一 4 空格 |
| 语句后写分号 | 报错 | 去掉分号 |
| `i32 x = 1.5` | 需显式 cast | `let i32 x = cast(1.5, i32)`（截断） |

## 17. 已知限制

- `(* *)` 不是注释；块注释内可含中文/UTF-8。
- `T!` 不作数组/列表元素、不作泛型实参。
- 128 位整数不支持 `T!` 包装。
- 字符串无内建字典序排序（可用 `<` 自行比较）。
- struct 不能整体 output。
- extern 不支持序列（数组/列表）返回。
- 溢出无检查（i128 除外：字面量编译期范围校验）。
