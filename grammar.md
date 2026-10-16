# zfy 语言规范（v3.3.6，2026-10-16）

> 本版每一节都经过编译器实测校准（examples 全回归通过）。
> 与 v3.3.4 的主要差异（v3.3.5 错误报告轮 + v3.3.6 时间内建轮）：
> **错误报告 DX（v3.3.5）**——poison 类型抑制级联（一处出错不再拖出一串
> 附属假错）、undefined variable/function 与 struct 字段报错附
> did-you-mean 修改建议、报错超 30 条折叠；**时间内建（v3.3.6）**——
> `now() -> i64`（Unix 时间戳秒）、`tick_ms() -> i64`（单调时钟，进程起
> 点为 0，测代码段耗时）、`sleep_ms(i64)`（毫秒阻塞，TVoid 可裸语句）、
> `localtime(i64) -> datetime`（拆解本地时间，datetime 为内建 struct：
> year/month/day/hour/minute/second/weekday/yday 全 i32，weekday
> 0=周日）、`mktime(y,mo,d,h,mi,s) -> i64`（反向构造，各分量 i64 允许
> 越界由 mktime 归一化——日期算术基础：`mktime(2026,10,16,0,0,0) +
> 86400*30` 即 30 天后）。运行时 zfy_time_now/tick/sleep/local/mktime，
> datetime 布局 8×i32 与 runtime.c zfy_datetime 一致；
> `now`/`tick_ms`/`sleep_ms`/`localtime`/`mktime`/`datetime` 为保留名。
> 与 v3.3.3 的主要差异（v3.3.4 语义扩展轮）：**下标/长度类内建返回 i32**——
> `length`/`find`（`i32!`）/`utf8_len` 此前返回 i64，落 i32 槽需显式 cast；
> **char 六种比较全支持**（`<` `<=` `>` `>=` 按码点序，此前需绕道 ord）；
> **string + char 拼接**（`s + 'c'` / `'c' + s`，char 提升单字符 string，
> cast(char→string) 已有）。
> 与 v3.3.2 的主要差异（v3.3.3）：**128 位整数幂**——`**` 支持
> i128/u128（含跨宽度提升 `u64 ** i32`、u128 指数全宽 `2^(2^64)`），
> 运行时 zfy_pow_u128/i128 64 位对接口（参数/结果全 64 位，规避
> win32 __int128 ABI）；溢出回绕、负指数得 0、0^0=1 与 64 位一致；
> 跨宽度隐式宽化与通用算术对齐（此前 `u64 ** i32` 误报 narrowing）。
> 与 v3.3.1 的主要差异（v3.3.2 修复轮）：**自动 move 循环误判修复**——
> 循环体内反复作为实参/赋值源的列表/string 变量此前被误判"最后使用"
> 而清槽（`store null`），下一轮迭代空指针崩溃（双层循环传同一列表的
> 算法全中招）；现循环体内一律克隆，循环外顶层仍自动 move；
> **`|e|`/abs 延迟定型**——
> 纯字面量实参树按外层期望落型（`let i32 a = |3|`、`let f32 c = |2.5|`、
> `f(|6|)`、`return |7|` 均合法；此前一律定 i64/f64 报 E3155/E3005）；
> **条件位强制 bool**——`if 2**0`、`not (2**0)` 报正规类型错误
> （此前静默绑定致 E4025 内部错误）；**const_eval 折叠 `**` 与 abs**——
> 可作数组长度（`let i32 const n = 2**4; let i32 a[n]`）；
> **编译期非有限浮点字面量按位型发射**（`1e400` → inf 位型，
> 此前产非法 "inf.0"）。
> 与 v3.3 的主要差异（v3.3.1 修复轮）：**浮点/整数混算全面修正**——
> 纯字面量混合树整树按浮点（`2.5 + 1` = 3.5，f32 上下文则 f32）；
> 浮点字面量与整数变量混算/落整数槽报 E3190（此前产坏 IR）；
> **f32 常量按最近位型发射**（`let f32 a = 0.1` 此前必产坏 IR）；
> **修复科学计数法字面量解析**（`1e40` 此前被错读为 1.4、`1e-45`
> 被拆成 `1.0-45`）。
> 与 v3.2 的主要差异：**`**` 幂运算符**（右结合，数学优先级：
> `-x**2 == -(x**2)`，`x**2**3 == x**(2**3)`；整数走运行时快速幂
> （≤64 位 zfy_pow_ll/ull、128 位 zfy_pow_u128/i128 64 位对接口），
> 浮点走 libm pow/powf）、**`|e|` 绝对值运算符**（脱糖为内建 `abs(e)`）。
> 与 v3.1 的主要差异：**位运算全套**（`<< >> & | ~` 运算符 + `xor` 关键字异或，
> `^` 仍只作解引用后缀）、**struct 方法**（隐式 `ref self` 首参）、
> **数学内建**（sqrt/log/exp/sin/cos/tan/pow/floor/ceil/abs）、
> **ref struct 参数**、**随机数标准库**（stdlib/random.zfy：xoshiro256** 与
> ChaCha20，含 OS 熵源播种）。
> 与 v3 的主要差异：**push/remove 表达式化**（push 返回列表、remove 返回被删元素）、
> **裸语句丢弃值报错**（E3189；fail/panic 与 ?? 块例外）、
> **cast(x, frac) 支持**、**裸 cast 语句（重绑定特例）删除**、
> bool→整数 cast 修为 zext（true=1）。
> 与 v2 的主要差异：**frac 上下文整棵表达式按分数计算**（消除 1/4+1/4=0 陷阱）、
> 新增**循环小数字面量** `(前缀,循环节,)`、切片支持**负步长反向**、
> **T! 解除数组/列表元素与 128 位限制**、cast(string→i128/u128) 改产错误值。
> 适用编译器：本版对应 `compiler/_build/zfyc.exe` 当前构建。

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

- `array`/`list`：旧关键字语法已删除，仅保留用于报错提示，**不能当标识符**。
- `sep`/`end`/`delim`：output/input 的命名参数名。
- `err`：`??` 块内的错误值绑定名。
- `xor`：二元异或运算符（v3.2）。**`^` 不是异或**——它只作后缀解引用。
- 10 个传统类型别名（int/long/double 等）**已删除**，不再是关键字——
  用它们当类型名会报"迁移提示"错误（见 §16 对照表）。

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
    变量及其常量折叠表达式——v3.3.2 起 `**`、abs、位运算均可折叠）。
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

## 5. ⚠️ n/d 字面量与 frac 运算（重要规则）

**frac 目标（frac 变量声明/赋值/复合赋值、frac 函数 return、frac 参数实参、
frac 序列元素）的初值/右值如果是四则表达式（`+ - * /` 与一元负号），整棵
表达式按分数计算**——表达式内的 `n/d` 按分数构造、普通整数字面量按 `n/1`
参与、浮点字面量按其二进制精确值转分数（如 `0.5 → 1/2`），结果约分后存入：

```
let i32 frac a = 1/4          # ✓ a = 1/4
let i32 frac b = 1/4 + 1/4    # ✓ b = 1/2（v3 起整棵表达式按分数算）
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
    方法（v3.2）：fn 返回类型? 方法名(参数) 缩进块
```

- 实例化：`Point(1, 2)` 位置 / `Point(x=1)` 命名（**struct 构造支持命名实参**，
  未给字段用默认值再退零值） / `Point p`（裸声明全默认）。
- 泛型：`struct Box<T>  T v` → `let Box<i32> b = Box(v=9)`。
- struct 作数组/列表元素：值语义深拷贝；`ps[i].x = v` 直接改元素；
  const 深不可变同样生效。
- `sizeof(T)` / `alignof(T)` 编译期内建。

**方法（v3.2）**：struct 块内用 `fn` 声明，隐式首参 `self` = 接收者的
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
- 方法体内字段用 `self.字段`；调兄弟方法写 `self.其他方法(...)`。
- **const 接收者调方法报错**（方法可能改状态）；方法不支持命名实参；
  方法名不能是关键字（`float`/`int` 等不行，换 `uniform` 这类名字）。
- 方法调用与字段访问不冲突：`rng.s0` 是字段，`rng.next_u64()` 是方法。
- 跨文件 use 导入 struct 后方法照常可用（`mod random; use random::Random`
  → `rng.next_u64()`）。

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
| `remove` | `remove(名, 下标)`（v3.1：**表达式**，返回被删元素副本，见 §12） |

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
<< >>       左结合（v3.2：移位，C 语义；有符号右移=算术移位）
+ -         左结合
* / %       左结合
**          幂（v3.3）：右结合 x**2**3 == x**(2**3)；高于乘除；
            数学优先级——一元负号在底数左侧绑定更松：-x**2 == -(x**2)；
            整数底数负指数 = 0；整数溢出回绕；128 位整数支持
            （v3.3.3：zfy_pow_u128/i128，指数支持完整 128 位）
一元 -e、&e、~e（v3.2：按位取反，仅整数/char）、|e| 绝对值（v3.3，
            脱糖为内建 abs(e)，整数同宽/浮点同宽（v3.3.2：字面量树按
            外层期望落型）；内层表达式解析到 & 层
            为止——按位或作被绝对值须加括号 |(a | b)|，嵌套 ||x|| 合法）
== != 之后的位运算链（v3.2，左结合，注意与 C 一致地低于比较）：
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
  **负步长 = 反向切片**（v3 起）：`s[4, 0:-1]` 从下标 4 倒着取到 0（含），
  `arr[4, 0:-2]` 反向隔一取一。负步长要求起始下标 a ≥ 当前长度不越界、
  b ≥ 0 且 a ≥ b，否则运行期 panic"切片区间越界"。
- **没有 `a..b` 区间语法**（写了报 E2042 提示逗号切片）。
- **比较**：string 与 string/char 六种比较全支持（字典序，char 提升
  单字符 string）；`"a" == 'a'` ✓。char 间**六种比较全支持**
  （v3.3.4：按码点序比较，`<` `<=` `>` `>=` 不再需要绕道 ord）。
- **拼接 `+`**：string + string；char 侧自动提升单字符 string
  （v3.3.4：`s + 'c'` / `'c' + s` 均可）。`s += v` 的 v 同样支持 char。
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
- 产 `T!` 的内建：`find`、`cast`（string→数值，含 i128/u128）、
  `input`（T! 目标）、`open`/`read_all`/`read_line`/`read_file`（§14）。
- **T! 作数组/列表元素**（v3 起）：`let i32! xs[] = 1, fail(3, "m")` 合法；
  元素按聚合存储（i32!/i64!/f64! 24 字节、i128!/u128! 32 字节），
  读取 `xs[i]` 得 `T!`、用 `??` 解包；push/切片/整体拷贝均支持。
  **T! 元素不支持复合赋值**（`xs[0] += 1` 报错——先 `??` 解包再重新赋值）；
  **output 不支持 T! 元素**（错误值不可打印，先解包）。
- **128 位整数支持 `T!` 包装**（v3 起）：`let i128! n`、`cast(s, i128)` 失败
  产错误值（不再 fail-fast），`input` 到 `i128!`/`u128!` 目标同样产错误值。

## 12. 内建函数

**函数式**（返回值）：

| 函数 | 说明 |
|---|---|
| `length(x)` | string=字节数；数组/列表=元素数。**返回 i32**（v3.3.4，此前 i64；落 i64 槽自动宽化） |
| `find(s, x[, count=k])` | x 为 char 查字符、string 查**子串**；返回第 k 次出现的字节下标（**`i32!`**，v3.3.4 此前 `i64!`）；k 从 1 起，<1 编译期拒绝（字面量）或运行期 panic（变量）；找不到 = NOT_FOUND 错误值 |
| `trim(s, x)` | **删除 s 中所有出现的 x**（x 为 char 或 string）——不是去两端空白！ |
| `split(s, x)` | 按分隔符切分返回 `string[]`（x 为 char 或 string）；空段保留；分隔符 `'\0'` 编译期拒绝 |
| `replace(s, a, b, rep)` | 把 `s[a, b]` 闭区间替换为 rep；"替换到串尾"写 `b = length(s) - 1`。**两参形式已删除** |
| `prec(v, n)` | 格式化为总宽 n（string 按**码点数**截断/右补空格；数值转 string 后同理） |
| `utf8_len(s)` | 码点数（`length` 仍按字节）。**返回 i32**（v3.3.4） |
| `utf8_char_at(s, i)` | 第 i 个码点（0 起），返回单码点 string |
| `utf8_sub(s, a, b)` | 按码点闭区间切片 |
| `sizeof(T)` / `alignof(T)` | 编译期常量 |
| `cast(e, T)` | 显式转换（含 string→数值；失败产 `T!` 错误值，i128/u128 目标同样产错误值）。v3.1：`cast(e, frac)` 支持——int/bool/char → n/1；float **字面量**按二进制精确转分数（0.5→1/2）；非字面量 float 拒绝。**裸 cast 语句（重绑定）已删除** |
| `ord(c)` / `chr(n)` | char↔码值 |
| `sqrt(x)` | 平方根（v3.2；实参 coerce 到 f64，返回 f64；下同） |
| `log(x)` / `exp(x)` | 自然对数 / e^x |
| `sin(x)` / `cos(x)` / `tan(x)` | 三角函数（弧度） |
| `pow(b, e)` | b^e（两参均 f64）。亦可写 **`b**e` 幂运算符**（v3.3）：整数走运行时快速幂（≤64 位；负指数=0；溢出回绕），任一侧为浮点/含浮点字面量则整树按浮点（f32 双侧走 powf）；**右结合** |
| `floor(x)` / `ceil(x)` | 向下/向上取整（返回 f64） |
| `abs(x)` | **重载**：整数→同宽整数（含 i128/u128，内联生成）；浮点→同宽浮点（f32 走 fabsf）。字面量实参树**延迟定型**（v3.3.2）：按外层期望落型（`let i32 a = |3|`、`let f32 c = |2.5|`、实参/返回上下文同理；无约束时整数 i64 / 浮点 f64）；`|e|` 运算符即本内建的语法糖 |
| `now()` | 当前 Unix 时间戳（秒，**i64**，v3.3.6） |
| `tick_ms()` | 单调时钟毫秒数（**i64**，进程起点为 0；QPC/CLOCK_MONOTONIC，不受系统改时间影响，测代码段耗时：`let i64 el = tick_ms() - t0`） |
| `sleep_ms(ms)` | 阻塞 ms 毫秒（TVoid，可作裸语句；负值按 0） |
| `localtime(ts) -> datetime` | 时间戳拆解为本地时间。**datetime 为内建 struct**（8 字段全 i32）：`year month day hour minute second weekday yday`；weekday 0=周日..6=周六；yday 年内第几天 0 起 |
| `mktime(y,mo,d,h,mi,s)` | 反向构造时间戳（本地时区，**i64**）。各分量 i64 **允许越界**（32 日、13 月、-5 小时），由 mktime 归一化；日期算术直接在时间戳上加减秒即可。失败（越界到不可表示）返回 -1 |

**数学内建说明（v3.2）**：直接落到 libm 符号（`@sqrt` `@log` `@fabs` 等）；
`abs` 与 C 的 32 位 `abs` 无关，i128/u128 正确。

**表达式化的序列操作（v3.1 2026-10-11）**：
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

### 12.1 随机数标准库（stdlib/random.zfy，v3.2）

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
注意：设计稿中的 `float()`/`int()`/`uint()` 方法名与类型关键字冲突，
实现更名为 `uniform()`/`int_range()`/`uint_range()`。

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
  **自动 move 循环限制（v3.3.2）**：循环体内（while/for 任意嵌套深度）的
  实参/赋值一律不自动 move、走克隆——源码位置判不出"下一轮迭代还会用"
  （`while` 里 `f(r)` 反复传同一列表是安全且常见的，此前会被误 move 致
  第二轮空指针崩溃）；循环外顶层"最后使用"仍自动 move 免拷贝。
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
| `let f64 x = 1/4 + 1/4` 想得 0.5 | 实数除法陷阱：得 0.0（先整数除） | `let i32 frac f = 1/4 + 1/4`（分数算）或写 `0.25` |
| `let i128 x = cast(s, i128)`（无 ??） | E3010（cast 失败产错误值，v3 起） | `let i128 x = cast(s, i128) ?? 0` |
| `xs[0] += 1`（xs 为 `T!` 元素列表） | 报错（错误值无算术语义） | `let i32 v = xs[0] ?? 0` 后 `xs[0] = v + 1` |
| `output(xs)`（xs 为 `T!` 元素列表） | 报错（错误值不可打印） | 逐元素 `??` 解包后输出 |
| `s[4, 0:-1]` 反向切片 | v3 起合法 | 要求 a 不越界、b ≥ 0、a ≥ b |
| `s[1..3]`（Python 切片） | E2042 提示 | `s[1, 3]` |
| `s[0, 4, 2]`（逗号步长） | 报错+提示 | `s[0, 4:2]` |
| `f(x=1)`（用户函数命名实参） | E3068 | `f(1)` |
| `p*`（解引用） | 报错提示 | `p^` |
| `a ^ b`（当异或用） | E3074（`^` 只作后缀解引用） | `a xor b` |
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
| `push(xs, 1)` 裸语句 | E3189（v3.1 新增） | `xs = push(xs, 1)`（push 返回列表） |
| `remove(xs, 0)` 裸语句 | E3189（v3.1 新增） | `let i32 v = remove(xs, 0)`（返回被删元素） |
| `cast(pi, i32)` 裸语句（旧重绑定） | E3189（v3.1：特例已删除） | `pi = cast(pi, i32)` 或 `let i32 n = cast(pi, i32)` |

## 17. 已知限制

- `(* *)` 不是注释；块注释内可含中文/UTF-8。
- `T!` 不作泛型实参；`T!` 元素不支持复合赋值、不能整体 output（§11）。
- 字符串无内建字典序排序（可用 `<` 自行比较）。
- struct 不能整体 output。
- extern 不支持序列（数组/列表）返回。
- 溢出无检查（i128 除外：字面量编译期范围校验）。
- 移位量 ≥ 位宽未定义（LLVM poison）；`x & 1 == 1` 按优先级解析为
  `x & (1 == 1)`，位运算与比较混用建议加括号。
- `n/d` 字面量除式按分数字面量语义处理（§5），浮点缩放常量请写成
  科学计数法（如 `1.1102230246251565e-16`）而非 `1.0/9007199254740992.0`。
- 跨文件 use 的 struct/类型别名作声明类型：解析器按"Ident 后跟 Ident"
  形状识别（v3.2 起），`let Pt p` / `let Random rng` 均可。
- **`**` 整数幂**（v3.3.3 起 128 位支持）：≤64 位走 zfy_pow_ll/ull；
  i128/u128 走 zfy_pow_u128/i128（64 位对接口，指数支持完整 128 位，
  如 `2 ** 2^64`）；跨宽度提升与通用算术一致（`u64 ** i32` 隐式宽化）；
  整数负指数 = 0；整数溢出回绕无检查。
- **浮点与整数不能隐式混算**（v3.3.1 起强制）：含浮点字面量的表达式与
  整数变量混算报 E3190（如 `2.0 * x`，x 为 i64）——请显式
  `cast(x, f64)`；纯字面量混合树（`2.5 + 1`）整树按浮点算（f32 上下文
  则 f32）；浮点字面量落整数槽（`let i64 x = 2.5`、`x += 2.5`）同样
  E3190。
- **科学计数法字面量**（v3.3.1 修复）：`1e40` / `1e-45` 裸指数形式
  现已正确解析（此前被错读为 `1.40` / `1.0-45`）；f32 常量按最近位型
  发射（0.1/2.249 等非精确值走 hex 位型，与 clang 一致）。
- **条件位必须是 bool**（v3.3.2 起强制）：if/while/for/and/or/not 的
  操作数须为 bool——算术树（`if 2**0`、`not (2**0)`、`x and 1`）报
  E3000 正规类型错误，此前静默绑定成 bool 致 E4025 内部错误。
