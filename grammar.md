# zfy 语法全表（直接从编译器源码提纯）

> 依据：compiler/lib/{tokens,lexer,parser}.ml 全文 + typeck.ml 内建/错误码表（2026-10-05，commit 27efc77）。非转录旧文档，逐条对应解析器产生式。

## 1. 词法规则

- 缩进系语言：块用缩进（INDENT/DEDENT），括号内换行被忽略；`;` 仅允许出现在 for 头部。
- 注释：`// 行注释`；`/* 块注释（可嵌套）*/`。
- 标识符：`[A-Za-z_][A-Za-z0-9_]*`。
- 数字：`123`、`0x1A`、`0b1010`、`1.5`、`1e-3`。
- 字符串：双引号，转义 `\n \t \r \0 \a \b \f \v \\ \" \'`；串内禁止裸换行。
- 字符：单引号单字符，同样转义集。
- 运算符：`== != <= >= += -= *= /= %= ++ -- => -> ??` 与单字符 `( ) [ ] { } , ; : = + - * & / % < > . ? ! ^`。

## 2. 关键字（34 个）

`if else while for return true false pub mod use break continue const frac unred reduce and or not output input cast array list remove import as sep end delim fail panic err struct packed move copy ref null unsafe extern type short long ushort ulong int uint half float double quad`
（`array`/`list` 仅保留用于报错提示：旧语法已删除；`sep`/`end`/`delim`/`err` 是命名参数/块内变量标记）

## 3. 类型

- **宽度名**：`bool char string void i8 i16 i32 i64 i128 u8 u16 u32 u64 u128 f16 f32 f64 f128`。
- **传统别名**（归一化到宽度名）：`short=i8 short int=i16 int=i32 long=i128 ushort=u8 ushort int=u16 uint=u32 ulong=u128 half=f16 float=f32 double=f64 quad=f128`。类型词重复/别名与宽度名混写报错（`int int`、`i32 int`）。
- **后缀**（可叠加）：`T*` 指针；`T* const` 指向 const 的指针；`T!` 错误值类型（ZEM）；`T[]` 动态数组/列表、`T[N]` 定长数组（类型后缀形式，w-014 #1——可叠加 `T[][]` 列表的列表、`T[3][4]` 定长二维；类型位置 N 须整数字面量）。
- **函数类型**：`T(参数类型列表)` —— 仅在 `type` 别名、函数参数位、struct 字段位允许。
- **泛型实例化**：`Box<i32>`、`Box<Box<i32>>`（仅类型位置；表达式比较不受影响）。
- **模块路径类型**：`m::Point`。
- type 别名：`type 名 = 类型`（可含指针/函数类型）。

## 4. 声明语句

```
标量：TYPE (const|frac|unred)* 名字 [= 初值]        # 初值可省略（填零值）；const 必须带初值
数组：TYPE 名字[长度] (= 值1, 值2, ...)?             # 长度为表达式；未给出的槽位填零值
列表：TYPE 名字[] (= 值1, 值2, ...)?                # 中括号必须为空，长度由初值决定
```
- 修饰符可任意顺序、位于类型后名字前：`long const frac r = 1/2`。
- `frac` 不可修饰数组/列表；`ref` 仅函数参数合法。
- 顶层声明 = 全局变量（非 const 也可赋值）。
- **一行多声明器**（w-012）：语句位置可用逗号声明多个，共享类型与前缀修饰符，初值各自独立（`i32 a, b = 1`、`string a[], b[]`、`i32 arr1[3], arr2[2] = 7, 8`）；同行后续声明器/语句可见前面的名字。顶层与 for 头部保持单声明器（for 头逗号是段分隔符）。带 `= 初值` 的数组/列表声明器须为该行最后一个（初值列表消费至行尾）。
- **类型后缀声明**（w-014 #1）：`i32[] a` ≡ `i32 a[]`、`i32[3] b` ≡ `i32 b[3]`；两种写法可叠加（`i32[3][4] m` 定长二维、`i32[][] n` 列表的列表）。嵌套（组数 > 1）声明不支持 `= 初值`（空声明 + push 构建；定长二维自动分配全零行）。
- **序列字面量整体赋值**（w-014 #3）：`a = 1, 2, 3` / `bag.xs = 1, 2`——目标须为数组/列表槽（变量、字段链、ref 参数）；定长数组目标要求字面量个数与长度一致。

## 5. 函数

```
TYPE (frac)? 名字(参数列表) 缩进块          # 顶层函数；无 fn 关键字
<T, U> TYPE (frac)? 名字(参数列表) 缩进块    # 泛型函数
```
- 参数四种形状：
  - 标量 `TYPE (frac)? (ref)? 名字`（`ref` 仅标量/string）
  - 数组 `TYPE 名字[长度]`（长度为字面量或之前的参数名）
  - 列表 `TYPE 名字[]`
  - 函数类型参数 `TYPE(参数类型) 名字`
- 参数不支持 const/unred；数组/列表参数不支持 frac。
- **ref 参数**（w-014 #1 扩展）：标量/string/数组/列表均可 `ref`（列表 ref 使函数内 `push(xs, v)` / `xs[i] = v` 直接作用于调用方列表；类型后缀形式 `i32 ref xs[]` 或 `i32[] ref xs`）。
- **返回类型**（w-014 #1）：可为 `T[]`（列表/动态数组，返回即所有权移交免克隆）与 `T[N]`（定长数组，同为 seq 指针移交）；extern 不支持序列返回。
- 返回类型必写；`rfrac` 允许 `TYPE frac f(...)` 形式返回分数。

## 6. struct

```
struct [packed] 名字<T, U>? 缩进块
    字段：TYPE 名字 [= 默认值]
    字段：TYPE 名字[长度]        # 数组字段，不可有默认值
    字段：TYPE 名字[]            # 列表字段，不可有默认值
    字段可为指针类型（允许 Node* 指针形态自引用）；可为函数类型；
    可为嵌套数组（i32 m[3][4]，自动分配全零行）
```
- 实例化：`Point(1, 2)` 位置构造 / `Point(x=1, y=2)` 命名构造 / `Point(x...)` 补全 / 裸声明 `Point p`（全默认）。
- `sizeof(T)` / `alignof(T)`：编译期内建。
- packed：紧排不补齐。
- **struct 作数组/列表元素**（w-014 #2）：值语义深拷贝——push 拷入、读元素得独立副本、元素字段写 `ps[i].x = v` 直接作用于元素；const 深不可变对元素写同样生效。output 不支持 struct 元素。

## 7. 语句全集

| 语句 | 语法 |
|---|---|
| 赋值 | `lhs = rhs`；序列字面量整体赋值 `a = 1, 2, 3`（目标为数组/列表槽，w-014 #3） |
| 复合赋值 | `lhs += -= *= /= %= rhs` |
| 自增/自减 | `lhs++` / `lhs--` |
| 表达式语句 | `expr` |
| 条件 | `if cond 块` / `else` / `else if`（可链） |
| while | `while cond 块` |
| for | `for 项, 项, ... 块`（逗号化多段头部，按形状分类：声明→初始化、布尔表达式→条件（多项 and 连接，可无）、赋值/复合赋值/自增自减→更新；孤立变量名进初始化段；头部声明不支持数组/列表） |
| 返回 | `return` / `return expr`（expr 可为列表/数组——所有权移交） |
| break/continue | `break` / `continue` |
| 输出 | `output(参数..., sep=?, end=?)`（命名参数必须最后；sep 默认 ""，end 默认 "\n"）；参数可为数组/列表（整体按元素打印，元素间以 sep 分隔，w-013） |
| 输入 | `input(目标..., delim=?)`（目标为 `TYPE 名` 新声明或已有 `名`） |
| unsafe 块 | `unsafe 块`（指针算术、p[i] 必须） |
| reduce | `reduce(x, 次数, 起始除数)`（手动约分 frac） |
| remove | `remove(数组或列表名, 下标)` |

- 分号在语句位置非法；空块允许；单语句块可同行（`if cond  stmt`）。
- **块表达式**仅存在于 `??` 块形式，无独立的 `{ }` 块语句。

## 8. 表达式（优先级低→高）

```
??        a ?? b（值形式）；a ?? + 缩进块（块形式，块内 err.code / err.msg 可用）
or / and  逻辑（短路）
not       一元（比较高于 not：not y==1 == not(y==1)）
== !=     不结合
< > <= >= 不结合
+ -       左结合
* / %     左结合
一元负号 -e；取地址 &e
后缀：调用 f(args)；下标 a[i]；切片 s[a, b] / s[a, b:step]（两端含）；
     命名空间 a.b（仅 use 导入名）；错误传播 e?；解引用 p^
```
- **解引用是 `p^`**；旧 `p*` 写法已删除（解析器遇到收尾上下文中的 `p*` 报错提示改用 `p^`）。
- **点号字段访问**（w-014 #8）：`a.b` / `a.b.c`（dotted 名编码）；任意后缀表达式可接字段——`ps[1].x`（struct 元素字段）、`f().x`、`bag.xs[0]`（列表字段下标）、`bag.s[0] = 'H'`（string 字段下标写）。
- **char 数值化**（w-014 #5）：算术运算中 char 与 char/整数混合自动提升为 i32（C 语义，`c + 1` 结果 i32）；`==`/`!=` 同型 char 直接比较；比较 `c < 'B'` 不支持（用 ord）。
- **大整数字面量**（w-014 #6）：超出 i64 的十进制字面量仅在 i128/u128 期望上下文合法（`i128 a = 1267650...0`，范围按 i128/u128 上限校验）；其他上下文报 E3176；无后缀语法。
- **序列下标语义**：负下标运行期 panic（`数组/列表下标越界`，非 Python 式负索引）；越界同 panic。string 下标读/写越界同 panic。
- **整数语义**（w-014 #9）：i64 及以下整数溢出静默回绕（`max + 1 → min`）；`/` 与 `%` 向零截断（`-7 / 2 = -3`）；整数除零为硬件异常不可捕获。
- 实参修饰：`f(move p)` 所有权移交 / `f(copy p)` 显式深拷贝 / `f(ref y)` 传引用 / `f(name=v)` 命名实参；位置在前命名在后。
- 主表达式：整/浮/串/字面量、`true` `false` `null` `err`、`fail(code, msg)`、`panic(msg)` / `panic(code, msg)`、`cast(expr, 目标类型)`、标识符（可 `m::x` 路径）、括号表达式。
- 模块路径：`Ident (:: Ident)+` 在表达式、类型、调用处均合法。

## 9. 顶层项

| 项 | 语法 |
|---|---|
| 函数 | `TYPE (frac)? 名字(参数) 块` / 泛型 `<T, U> TYPE ...` |
| struct | `struct [packed] 名<T,U>? 块` |
| type 别名 | `type 名 = 类型` |
| 顶层声明 | 标量/数组/列表（含 const/frac/unred） |
| 模块（文件） | `mod 名字;` —— body 在 `名字.zfy` 或 `名字/mod.zfy` |
| 模块（内联） | `mod 名字` + 缩进块（块内为顶层项，可嵌套） |
| 导出 | `pub` 修饰任意顶层项（仅模块内合法；root 顶层 pub 容忍并告警） |
| use（新路径） | `use a::b::item [as x]`；分组 `use a::b::{x, y as z}`；整模块 `use a::b [as m]` |
| use（旧文件，legacy） | `use 名字.zfy [import 模块名] [as 别名]`；支持 `./`、`../` 前缀 |
| extern | `extern "C"` + 缩进块（每行一个 C 函数声明：`TYPE (frac)? 名(参数)`） |

## 10. ZEM 错误值

- 类型 `T!`（如 `i32!`）；面值自动包装为成功值。
- `fail(code, msg)` 构造错误值；code 为 `ErrCode.*` 或 ≥100 字面量。
- `?? 默认值` 值形式 / `??` 块形式（`err.code`: i32、`err.msg`: string）。
- `e?` 传播——函数返回类型必须显式 `T!`。
- `ErrCode.*`：`OK=0 DIV_ZERO=1 OOB=2 NOT_FOUND=3 IO=4 CAST=5 INPUT=6 CUSTOM=100`。
- `panic(msg)` / `panic(code, msg)`；`panic_handler(f)` 注册处理函数（签名 `(i32, string) -> void`）。
- 除零、下标越界、frac 溢出、input EOF、cast 失败等运行期错误统一走 panic 通道（exit 101），不可被 `?`/`??` 捕获。
- 产 `T!` 的内建：`find`、`cast`（string→数值）、`input`。
- 限制：`T!` 不作数组/列表元素；128 位类型不支持 `T!`。

## 11. 内建函数

**函数式**：`length(x)`；`find(s, char[, count=k])` 产 T!；`trim(s, x)`；`split(s, x)` 返回 `string[]`；`replace(s, char, rep)` 全替换 / `replace(s, char, char, rep)` 次数限定；`prec(v, n)` 精度；`sizeof(T)`；`alignof(T)`；`cast(e, T)`；`ord(c)`（char→i32 码值）；`chr(n)`（码值→char）——w-014 #5。
**语句式**：`push(列表, 值)`（目标可为变量/字段链 `bag.xs`/ref 参数/嵌套元素槽 `m[0]`，w-014 #3）；`remove(名, 下标)`；`reduce(x, n, 起始除数)`。
**I/O**：`output(..., sep, end)`；`input(..., delim)`。
**泛型**：仅值语义通用操作（赋值/传参/返回/深拷贝/`==`/`!=`），对 T 无算术约束（实例化后按具体类型检查）。

## 12. 词法/解析层已删除或禁用的旧语法（报错保留提示）

- `array`/`list` 关键字声明形式（现为 `T a[N]` / `T a[]`）。
- `p*` 解引用（现为 `p^`）。
- `[]T` / `[T;N]` 类型。
- ~~`.` 字段访问~~（已恢复：w-014 #8 起点号为 struct 字段访问；use 命名空间仍走 dotted 名编码）。
- `long long` / `long int` / `ulong long` / `ulong int` 多词别名（报 E2010 duplicate base type）。
- string 下标赋值（旧报错"s[0]='H' 不支持"→ 现已支持原地写，w-014 #5）。

## 13. 运行期语义备忘（w-014 #9/#10）

- **下标越界 / 负下标**：数组、列表、string 的读写下标 < 0 或 ≥ 长度 → panic（stderr `panic: 数组/列表下标越界` / `字符串下标越界`，exit 101）。无 Python 式负索引。
- **整数溢出**：i64 及以下定宽整数运算溢出**静默回绕**（二补码），无检查无警告。
- **除法截断**：`/` 向零截断（`-7 / 2 = -3`、`7 / -2 = -3`）；`%` 符号随被除数。
- **整数除零**：硬件异常（不可捕获、非 panic 通道）；frac 除零走 panic 通道。
- **所有权**：返回数组/列表 = seq 指针移交（与 string 返回一致，RVO）；函数内返回局部列表免克隆。
