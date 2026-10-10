# zfy 语法全表（直接从编译器源码提纯）

> 依据：compiler/lib/{tokens,lexer,parser}.ml 全文 + typeck.ml 内建/错误码表（2026-10-05，commit 27efc77；2026-10-10 按 new.md 更新 let/fn 声明与函数形式、删除类型别名、扩展 frac 全存储位归一）。非转录旧文档，逐条对应解析器产生式。

## 1. 词法规则

- 缩进系语言：块用缩进（INDENT/DEDENT），括号内换行被忽略
- 注释：`// 行注释`；`/* 块注释（可嵌套）*/`。
- 标识符：`[A-Za-z_][A-Za-z0-9_]*`。
- 数字：`123`、`0x1A`、`0b1010`、`1.5`、`1e-3`。
- 字符串：双引号，转义 `\n \t \r \0 \a \b \f \v \\ \" \'`；串内禁止裸换行。
- 字符：单引号单字符，同样转义集。
- 运算符：`== != <= >= += -= *= /= %= ++ -- => -> ??` 与单字符 `( ) [ ] { } , ; : = + - * & / % < > . ? ! ^`。

## 2. 关键字（44 个）

`if else while for return true false pub mod use break continue const frac unred reduce and or not output input cast array list remove import as fail panic err sep end delim struct packed move copy ref null unsafe extern type let fn`
（`array`/`list` 仅保留用于报错提示：旧数组/列表关键字语法已删除；`extern`/`type`/`import` 服务于 extern 块/type 别名/旧 use；`sep`/`end`/`delim`/`err` 是命名参数/块内变量标记；`let` 声明、`fn` 函数定义）

## 3. 类型

- **宽度名**：`bool char string void i8 i16 i32 i64 i128 u8 u16 u32 u64 u128 f16 f32 f64 f128`。
  传统多词别名（short/long/int/double/quad 等 10 词）已全部删除（new.md 2026-10-10）：作为类型名使用报 E2003 迁移提示，改用对应宽度名（short=i8、short int=i16、int=i32、long=i128、ushort=u8、ushort int=u16、uint=u32、ulong=u128、half=f16、float=f32、double=f64、quad=f128）。类型词重复报错（`i32 i32`）。
- **后缀**（可叠加）：`T*` 指针；`T* const` 指向 const 的指针；`T!` 错误值类型（ZEM）；`T[]` 动态数组/列表、`T[N]` 定长数组（类型后缀形式，w-014 #1——可叠加 `T[][]` 列表的列表、`T[3][4]` 定长二维；类型位置 N 须整数字面量）。
- **函数类型**：`T(参数类型列表)` —— 仅在 `type` 别名、函数参数位、struct 字段位允许。
- **泛型实例化**：`Box<i32>`、`Box<Box<i32>>`（仅类型位置；表达式比较不受影响）。
- **模块路径类型**：`m::Point`。
- type 别名：`type 名 = 类型`（可含指针/函数类型）。

## 4. 声明语句（let 形式，new.md 2026-10-10）

```
标量：let (TYPE)? (frac)? (const)? (unred)? 名字 [= 初值]     # 修饰符固定顺序：类型→frac→const→unred
数组：let TYPE (frac)? (const)? (unred)? 名字[长度] (= 值1, 值2, ...)?   # 长度为表达式
列表：let TYPE (frac)? (const)? (unred)? 名字[] (= 值1, 值2, ...)?      # 中括号必须为空
```
- **类型/初值二选一或都写，不能都无**；类型可省时由初值推断：整数字面量→i32、浮点字面量→f64、`n/d` 字面量除式→i32 frac、string/char/bool 按字面量；其他表达式取表达式自身类型。
- **有类型无初值 = 零值初始化**（0/0.0/false/'\0'/""/分数 0/1）；`const` 必须带初值；`let frac 名`（frac 修饰视同给出类型）= `let i32 frac 名`。
- **unred 校验**：`unred` 须有 `frac` 修饰或 `n/d` 形态初值，否则报错。
- 修饰符可省略；`frac` 可修饰数组/列表元素（元素存入自动约分，unred 数组/列表不约分）；`ref` 仅函数参数合法。
- 顶层 let 声明 = 全局变量（非 const 也可赋值），无数量限制。
- **顶层 const + frac/unred 合法**（w-015 #5）：编译为全局分数常量槽（ginit 初始化，const 不可赋值）。
- **一行多声明器**（w-012）：语句位置可用逗号声明多个，共享类型与前缀修饰符，初值各自独立（`let i32 a, b = 1`、`let string a[], b[]`、`let i32 arr1[3], arr2[2] = 7, 8`）；同行后续声明器/语句可见前面的名字。顶层与 for 头部保持单声明器（for 头逗号是段分隔符）。带 `= 初值` 的数组/列表声明器须为该行最后一个（初值列表消费至行尾）。
- **类型后缀声明**（w-014 #1）：`let i32[] a` ≡ `let i32 a[]`、`let i32[3] b` ≡ `let i32 b[3]`；两种写法可叠加（`let i32[3][4] m` 定长二维、`let i32[][] n` 列表的列表）。嵌套（组数 > 1）声明不支持 `= 初值`（空声明 + push 构建；定长二维自动分配全零行）。
- **序列字面量整体赋值**（w-014 #3）：`a = 1, 2, 3` / `bag.xs = 1, 2`——目标须为数组/列表槽（变量、字段链、ref 参数）；定长数组目标要求字面量个数与长度一致。
- 旧省略 let 的声明形式（`i32 x = 1`）已删除：报 E2003 迁移提示。

## 5. 函数（fn 形式，new.md 2026-10-10）

```
fn (TYPE|void)? (frac)? (unred)? 名字(参数列表) 缩进块          # 修饰符固定顺序：返回类型→frac→unred
fn <T, U> (TYPE|void)? (frac)? (unred)? 名字(参数列表) 缩进块    # 泛型函数（tparams 在返回类型前）
fn main() 缩进块                                              # 入口特例
```
- **main 特例**：必须写 `fn main()`（括号必须有）；不给返回类型（隐含 i32）、不给参数、不给 frac/unred；`return` 可写可不写，裸 `return` 等价 `return 0`，落到函数末尾隐式返回 0。
- 非 main 函数返回类型必写（`void` 或类型）；`frac` 可修饰返回类型（`fn i32 frac f(...)`）；返回类型不支持 const/unred 修饰（unred 语义：非 unred 函数 return 归一，见 §8）。
- 参数一律 let 形式：`(ref)? let (TYPE)? (frac)? (const)? (unred)? 名字`——
  - 标量 `let TYPE 名字`（类型可省须有 frac：`let frac y` ≡ `let i32 frac y`；可 const/unred）
  - 数组 `let TYPE 名字[长度]`（长度为字面量或之前的参数名）；列表 `let TYPE 名字[]`；类型后缀形式 `let TYPE[] 名字` 等价
  - 函数类型参数 `let TYPE(参数类型) 名字`
  - `ref` 置于 let 前（`ref let i32 x`）；**ref 参数不支持 frac**；数组/列表参数不支持 const/unred/frac
- **ref 参数**（w-14 #1 扩展）：标量/string/数组/列表均可 `ref`（列表 ref 使函数内 `push(xs, v)` / `xs[i] = v` 直接作用于调用方列表；类型后缀形式 `ref let i32[] xs`）。
- **返回类型**（w-014 #1）：可为 `T[]`（列表/动态数组，返回即所有权移交免克隆）与 `T[N]`（定长数组，同为 seq 指针移交）；extern 不支持序列返回。
- 实参入口归一（new.md）：非 unred frac 参数在进入函数时对参数副本自动约分（值拷贝语义，调用方源槽不变）；unred frac 参数不归一。
- 旧省略 fn 的函数形式（`TYPE 名(...)`）与旧 `<T> ret 名(...)` 泛型形式已删除：报迁移提示错误。

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
| for | `for 项, 项, ... 块`（逗号化多段头部，按形状分类：`let` 声明→初始化（`for let i32 i = 0`，类型可省由初值推断）、布尔表达式→条件（多项 and 连接，可无）、赋值/复合赋值/自增自减→更新；孤立变量名进初始化段；头部声明不支持数组/列表。**初始化段与更新段不可为空**——无初值时在头部前声明、无更新时把更新写进块内或改用 while；条件段可省（其位置留空）） |
| 返回 | `return` / `return expr`（expr 可为列表/数组——所有权移交；main 内裸 `return` 等价 `return 0`） |
| break/continue | `break` / `continue` |
| 输出 | `output(参数..., sep=?, end=?)`（命名参数必须最后；sep 默认 ""，end 默认 "\n"）；参数可为数组/列表（整体按元素打印，元素间以 sep 分隔，w-013）。**嵌套列表/定长二维及以上**递归输出：每层包 `[` `]`，如 `i32[2][3]` → `[[000][005]]`；叶元素须为可打印标量/string（struct 叶不支持，w-015 #6） |
| 输入 | `input(目标..., delim=?)`（目标为 `let TYPE 名` 新声明——类型必须显式——或已有 `名`；delim 必须最后） |
| unsafe 块 | `unsafe 块`（指针算术、p[i] 必须） |
| reduce | `reduce(x, 次数, 起始除数)`（手动约分 frac） |
| remove | `remove(数组或列表名, 下标)` |

- 分号在语句位置非法；空块允许；单语句块可同行（`if cond  stmt`）。
- **块表达式**仅存在于 `??` 块形式，无独立的 `{ }` 块语句。

## 8. 表达式（优先级低→高）

```
??        a ?? b（值形式）；a ?? + 缩进块（块形式，块内 err.code / err.msg 可用；
          块形式允许位置 = 声明初值 / 赋值右值 / return（w-015 #4：
          return a ?? 块 —— a 成功直接返回成功值，失败执行块并以块末值为返回值））
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
- **字符串比较**（w-020 用户拍板）：string 与 string/char 可做全部六种比较 `== != < <= > >=`；char 侧自动提升为单字符 string（ASCII）；语义为逐字符比较、比到第一个不同字符即断（字典序/strcmp）。
- **大整数字面量**（w-014 #6）：超出 i64 的十进制字面量仅在 i128/u128 期望上下文合法（`i128 a = 1267650...0`，范围按 i128/u128 上限校验）；其他上下文报 E3176；无后缀语法。
- **序列下标语义**：负下标运行期 panic（`数组/列表下标越界`，非 Python 式负索引）；越界同 panic。string 下标读/写越界同 panic。
- **整数语义**（w-014 #9）：i64 及以下整数溢出静默回绕（`max + 1 → min`）；`/` 与 `%` 向零截断（`-7 / 2 = -3`）；整数除零为硬件异常不可捕获。
- 实参修饰：`f(move p)` 所有权移交 / `f(copy p)` 显式深拷贝 / `f(ref y)` 传引用 / `f(name=v)` 命名实参；位置在前命名在后。
- **frac 字面量实参**（w-015 #5 顺带）：期望类型为 frac 的位置（实参/返回/赋值右值），数值字面量自动提升为分数；`n/d` 形式的数值字面量除式按分数构造（分子/分母不执行除法、不自动约分），与声明初值语义一致（如 `addf(1/4, 1/4)` = 1/2，非 unred 存入后约分）。
- **frac 归一化语义**（w-017 扩展，new.md 2026-10-10 全存储位归一）：非 unred frac 值在**所有存储位**自动约分到最简——①存入变量（声明/赋值）、②return 返回、③**实参传入**（进入函数时对参数副本归一，调用方源槽不变）、④**struct 字段存入与数组/列表元素存入**（含 push）。四则运算的运行时结果本身不经归一（如 1/4+1/4 的中间态为 8/16，存入或返回时约分为 1/2）；`unred` 修饰的变量/参数/数组存储不做自动约分（函数返回时仍按返回类型归一——返回类型不支持 unred 修饰；unred 函数 return 不归一）。
- 主表达式：整/浮/串/字面量、`true` `false` `null` `err`、`fail(code, msg)`、`panic(msg)` / `panic(code, msg)`、`cast(expr, 目标类型)`、标识符（可 `m::x` 路径）、括号表达式。
- 模块路径：`Ident (:: Ident)+` 在表达式、类型、调用处均合法。

## 9. 顶层项

| 项 | 语法 |
|---|---|
| 函数 | `fn (TYPE\|void)? (frac)? (unred)? 名(参数) 块` / 泛型 `fn <T, U> ...` |
| struct | `struct [packed] 名<T,U>? 块` |
| type 别名 | `type 名 = 类型` |
| 顶层声明 | `let` 标量/数组/列表（含 const/frac/unred，无限制） |
| 模块（文件） | `mod 名字;` —— body 在 `名字.zfy` 或 `名字/mod.zfy` |
| 模块（内联） | `mod 名字` + 缩进块（块内为顶层项，可嵌套） |
| 导出 | `pub` 修饰任意顶层项（仅模块内合法；root 顶层 pub 容忍并告警） |
| use（新路径） | `use a::b::item [as x]`；分组 `use a::b::{x, y as z}`；整模块 `use a::b [as m]`；单段整模块 `use 模块名 [as 别名]`（w-015 #2：整模块绑定命名空间，成员以 `别名.成员名` 访问，仅 pub 可见） |
| use（旧文件，legacy） | `use 名字.zfy [import 模块名] [as 别名]`；支持 `./`、`../` 前缀 |
| extern | `extern "C"` + 缩进块（每行一个 C 函数声明：`TYPE (frac)? 名(参数)`；参数用 let 形式） |

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

**函数式**：`length(x)`；`find(s, x[, count=k])` 产 T!——x 为 char 查字符、**string 查子串**（w-020），count<1 编译期拒绝（字面量/常量）、运行期 panic；`trim(s, x)`（x 为 char/string，**删除全部出现**，非去两端）；`split(s, x)` 返回 `string[]`（分隔符 '\0' 编译期拒绝——C 串无内嵌 NUL）；`replace(s, 起, 止, 串)` 区间替换（把 `s[起, 止]` 闭区间内内容替换为串，两端含；"替换到串尾"用 `止 = length(s) - 1` 表达——两参形式已删除，w-020）；`prec(v, n)` 精度——string 按**码点数**截断/补齐（对齐码点边界，不产生非法 UTF-8）；`utf8_len(s)` 码点数（length 仍按字节）；`utf8_char_at(s, i)` 第 i 个码点（0 起，返回单码点 string，可能多字节）；`utf8_sub(s, a, b)` 按码点闭区间切片——UTF-8 组为 w-020 扩展集；`sizeof(T)`；`alignof(T)`；`cast(e, T)`；`ord(c)`（char→i32 码值）；`chr(n)`（码值→char）——w-014 #5。
**语句式**：`push(列表, 值)`（目标可为变量/字段链 `bag.xs`/ref 参数/嵌套元素槽 `m[0]`，w-014 #3）；`remove(名, 下标)`；`reduce(x, n, 起始除数)`。
**I/O**：`output(..., sep, end)`；`input(..., delim)`。
**泛型**：仅值语义通用操作（赋值/传参/返回/深拷贝/`==`/`!=`），对 T 无算术约束（实例化后按具体类型检查）。
**字符串 `+=`**（w-020）：变量 `s += v`、数组/列表元素 `parts[i] += v`、ref 参数 `p^ += v` 均支持；v 为 string 或 char（char 提升为单字符 string）；变量路径原地扩容（realloc），元素/解引用路径 concat 产新串写回。
**切片步长**：`s[a,b:step]` / `a[x,y:st]` 的步长字面量/常量 ≤ 0 编译期拒绝；变量步长运行期 panic（w-020）。

## 12. 词法/解析层已删除或禁用的旧语法（报错保留提示）

- `array`/`list` 关键字声明形式（现为 `T a[N]` / `T a[]`）。
- `p*` 解引用（现为 `p^`）。
- `[]T` / `[T;N]` 类型。
- ~~`.` 字段访问~~（已恢复：w-014 #8 起点号为 struct 字段访问；use 命名空间仍走 dotted 名编码）。
- `long long` / `long int` / `ulong long` / `ulong int` 多词别名（报 E2010 duplicate base type）。
- **10 个传统类型别名**（new.md 2026-10-10 删除）：`short long ushort ulong int uint half float double quad` 不再是关键字，作类型名使用报 E2003 迁移提示（对应宽度名见 §3）。
- **省略 let 的旧声明形式** `TYPE (mods)* 名 = 初值`：报 E2003 迁移提示（现为 `let` 形式，§4）。
- **省略 fn 的旧函数形式** `TYPE 名(...)` 与旧泛型 `<T> ret 名(...)`：报迁移提示错误（现为 `fn` 形式，§5）。
- string 下标赋值（旧报错"s[0]='H' 不支持"→ 现已支持原地写，w-014 #5）。

## 13. 运行期语义备忘（w-014 #9/#10）

- **下标越界 / 负下标**：数组、列表、string 的读写下标 < 0 或 ≥ 长度 → panic（stderr `panic: 数组/列表下标越界` / `字符串下标越界`，exit 101）。无 Python 式负索引。
- **整数溢出**：i64 及以下定宽整数运算溢出**静默回绕**（二补码），无检查无警告。
- **除法截断**：`/` 向零截断（`-7 / 2 = -3`、`7 / -2 = -3`）；`%` 符号随被除数。
- **整数除零**：硬件异常（不可捕获、非 panic 通道）；frac 除零走 panic 通道。
- **所有权**：返回数组/列表 = seq 指针移交（与 string 返回一致，RVO）；函数内返回局部列表免克隆。

## 14. 文件 I/O（design_fileio.md 第一阶段）

- **`File` 内建类型**：move-only 句柄（槽 = 堆上 `{FILE* fp; int closed}` 对象指针）。
  不可作 struct 字段、数组/列表元素、泛型实参（E3186）；不可 const 语义复制。
- **打开**：`File! fo = open(path, mode)`——mode 字面量限 `"r"`/`"w"`/`"a"`（E3188），
  变量实参运行期校验；失败产 `ErrCode.IO` 错误值。
- **典型解包**：`File f = fo ?? panic("...")`（`?? panic(...)` 对任意 T! 合法）。
- **读**（借传，不消耗句柄）：
  - `string! s = read_all(f)`（IO 错误产 `ErrCode.IO`）
  - `string! l = read_line(f)`——读一行不含换行符；文件结束产 `ErrCode.EOF`（=7）
- **写**（失败 panic，不产 T!）：`write(f, s)` / `writeln(f, s)`（追加 `\n`）；
  实参自动转 string。
- **关闭**：`close(f)` 幂等；close 失败 panic。
- **一步式**：`string! s = read_file(path)`；`i64! n = write_file(path, s)`（覆盖写，
  成功返回字节数）。
- **查询**：`bool e = exists(path)`。
- **所有权规则**：
  - 声明初始化/赋值 `File g = f` = 所有权转移（源变量失效；同块复用报 E3013，
    跨块运行期 panic "use of moved file handle"）。
  - 用户函数的 File 参数**只能 `f(move g)` 传**（E3187）；被调函数退出时自动 close。
  - **作用域退出自动 close**（RAII）：仍有效的 File 局部变量/参数在函数退出时
    幂等关闭（复用 emit_frees_from）；close 失败 panic。
  - 已 close 句柄上的任何操作 → panic "use of closed file"。
- **运行时约定**：文件按字节透传（Windows 文本模式含 CRLF 转换），不做编码转换；
  第二阶段规划 `read_lines -> string[]`（依赖函数返回列表，已落地）与 for-in 迭代。
