# zfy 错误穷举与修复指南

> 依据 `d:\zfy\errors.md`（2026-10-04 定稿，含 v3.1~v3.3.6 各轮补录）改写。错误码与文案均出自编译器实际输出（compiler/lib/*，与 driver.ml `code_of` 映射表一一对应），英文文案保留原文，`%s/%d/%Ld` 为运行时填充。
>
> **码位规则**：`E` + 体系位 + 3 位序号（不足 3 位前补零）。体系位：1 词法 / 2 语法 / 3 类型语义 / 4 代码生成（MIR+LLVM）/ 5 驱动配置。例：E300-84 → E3084。
>
> **多错误恢复**：词法单错即停；语法按语句/顶层项恢复；类型语义按语句/函数/顶层项恢复（详见附录 B）。标注 **[内部兜底]** 的为代码生成阶段一致性检查，正常程序不会触发（前端已拦截），列出仅为穷举完整。

---

## 〇、报错输出格式

### 报错行格式

```
zfy:error[序号][E码] in 行号 of 文件 because (文案)
```

- **序号**为本次编译的全局递增编号 `[1][2][3]…`，按「文件 / 行 / 列」排序；同一位置的多个诊断各自占行、E 码并行保留。
- 报错行后跟 **5 行源码上下文**，以及一条等长 `^` 列对齐指示线，指向出错列。
- 错误超过 **30 条**时折叠截断，尾部打印一行：

  ```
  zfy: ... and N more errors (suppressed)
  ```

### 修复建议后缀（did you mean）

- 大多数类型语义报错带修复指导后缀 `(did you mean 'x'?)`。
- 编辑距离规则（Damerau-Levenshtein）：候选 ≤3 字符容 1 错、其余容 2 错；无相近候选时**不硬凑**、不加后缀。
- 候选来源：作用域链 + 全局/泛型函数 + struct + type 别名 + 内建表（如 `lenth` → `length`）；struct 字段报错在报错行内联给出字段表内的相近候选（如 `m.mesage` → `message`）。
- exit 码：编译错误 1（E5006 CLI 用法为 exit 2）。

---

## 〇′、自动修复

编译器内置自动修复（v3.5.1 起支持交互式选择）。报错含修复项时，错误块**顶部**先打一行预告：

```
zfy: auto-fixable: error(s) [序号] [序号] ... will be repaired automatically
```

### ① 修复动作（两类，均可写回源文件）

- **整数字面量窄化但值在目标范围内**：把字面量包成 `cast(字面量, 目标类型)`（对应 E3155 场景）。
- **char → 整数槽**：按 ord 码点把 char 包成 `cast(c, 目标类型)`（对应 E3005 场景）。
- **undefined variable / undefined function**：存在**唯一最近候选**（最小编辑距离且并列唯一；两个以上并列则只提示不修）时自动改名。
- **undefined type 的传统别名迁移**：`int→i32`、`short→i16`、`long→i128`、`signed→i32`、`unsigned→u32`、`ulong→u128`、`float→f32`、`double→f64`、`byte→i8`。

### ② 修复模式（按 stdin 是否为终端自动分流；`ZFY_FIX=ask`/`all` 可强制）

- **非交互（脚本/管道，默认 `ZFY_FIX=all`）**：自动修复全部——内存补丁重跑 ≤4 轮，**源文件不动**，照常产出 exe 并附清单：

```
zfy: note: auto-fixed N error(s):
[序号][E码] in 行 of 文件 because (文案…auto-fixed…)
```

- **交互（终端，默认 `ZFY_FIX=ask`）**：照常报告全部错误（顶部罗列可修序号）**且不退出**，提示输入要修复的序号：

```
zfy: enter error number(s) to auto-fix (space/comma separated; Enter = all, q = none):
```

  序号**空格与逗号分隔均支持**（可混用，如 `1, 3` 或 `1 3`）；直接回车=全部，`q`/`n`/`no`=不修；非法序号忽略并提示；选中不可修序号提示后跳过。选中项**直接写回源文件**（改名与 cast 插入都改文件）后自动重编译。

### ③ 大决定（是否产出 exe）

- **选中修复且全部错误可自动修复** → 照常产出 exe，并附 `zfy: note: auto-fixed N error(s):` 清单。
- **选中部分修复** → 选中项写回源文件后重编译，不可修错误照常报告（重编译仍失败则不产出 exe）。
- **选择不修（`q`）** → 报告全部错误，不产出 exe。

各错误码条目的「自动修复」列即按上述范围标注。

---

## 1. 词法错误（E1xxx，Lexer，单错即停）

**代表性代码示例**：

```zfy
fn main()
    let string s = "abc         // ← E1001 unterminated string literal（缺右引号）
    let char c = 'ab            // ← E1008 character literal must end with '
    let i32 a = 0x              // ← E1009 numeric literal has no digits
    let i64 n = 99999999999999999999
                                // ← E1013 integer literal overflows i64
```

### 1x1 字符串/字符字面量

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E1001 | `let string s = "abc` → `unterminated string literal` | 字符串缺右引号，扫到行尾/文件尾仍未闭合 | 补上右引号 `"` | 否 |
| E1002 | `output("a\` → `dangling escape character` | 反斜杠后直接是字符串结尾（字符字面量同） | 删掉多余 `\`，或补全转义序列（如 `\n`） | 否 |
| E1003 | `output("a\qb")` → `unknown escape sequence \q` | `\q` 不是合法转义（字符字面量同） | 改用合法转义（`\n \t \\ \" \'` 等）或去掉 `\` | 否 |
| E1004 | 字符串内直接回车换行 → `raw newline in string literal` | 字符串字面量内不允许裸换行 | 换行处改写 `\n`，或拆成多段拼接 | 否 |
| E1005 | `let char c = 'a` → `unterminated character literal` | 字符字面量缺右引号 | 补上右引号 `'` | 否 |
| E1008 | `let char c = 'ab`（缺 `'` 结尾）→ `character literal must end with '` | 多字符后未闭合 | 单字符补右引号；多字符内容改用 string | 否 |

### 1x2 数字字面量

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E1009 | `let i32 a = 0x`（0x 后无数位）→ `numeric literal has no digits` | 前缀后没有数位 | 补齐十六/二进制数位 | 否 |
| E1010 | `let f64 a = 1.` → `invalid float literal` | 浮点格式非法（小数点后无数位等） | 写成 `1.0` 或科学计数法 `1e0` | 否 |
| E1011 | `let i64 a = 0xFFFFFFFFFFFFFFFF` → `hex literal overflows i64` | 十六进制字面量超 i64 | 缩小数值；确需 128 位请在 i128/u128 上下文书写 | 否 |
| E1012 | `let i64 a = 0b111...1`（超 64 位）→ `binary literal overflows i64` | 二进制字面量超 64 位 | 缩短位串或改 i128/u128 上下文 | 否 |
| E1013 | `let i64 a = 99999999999999999999` → `integer literal overflows i64` | 十进制整数字面量超 i64 | 缩小数值；超 i64 的大整数需 i128/u128 上下文（另见 E3176） | 否 |

### 1x3 注释 / 缩进 / 字符

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E1014 | `/* 未闭合` → `unterminated block comment` | 块注释缺 `*/` | 补上 `*/` | 否 |
| E1015 | 同一语句内缩进比上一行多且不成块（Dedent 时不匹配栈顶）→ `inconsistent indentation: expected %d, got %d` | 缩进不匹配任何块层级 | 按报错的 expected 列对齐缩进层级 | 否 |
| E1016 | 源码出现 `#`、`` ` ``、`$` 等无 token 含义字符 → `illegal character '%c' (0x%02X)` | 字符无词法含义 | 删除该字符或改为合法写法 | 否 |

> 跳号：E1006/E1007（占位：字符字面量场景的悬空转义/未知转义）并入 E1002/E1003——两场景文案相同。

---

## 2. 语法错误（E2xxx，Parser，语句/顶层级恢复 [多错误恢复]）

**代表性代码示例**：

```zfy
fn main()
    let i32 a = 1
    a =                     // ← E2001 expected an expression, got %s（右侧缺表达式）
    const k                 // ← E2012 const requires an initializer
    output(1, sep=',', 2)   // ← E2038 named output parameters (sep/end) must come last
    a[1..3]                 // ← E2042 invalid syntax 'a..b'（切片应写 s[a,b:step]）
```

### 2x1 期望类（token 缺失/多余）

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E2001 | `a = `（赋值右侧缺表达式）、`output(1`（缺右括号）、`f(1,`（参数表缺项）、`let i32 a = b[`（下标缺表达式）→ `expected an expression, got %s` | 期望表达式处拿到别的 token | 补上缺失的表达式或右括号 `)` / `]` | 否 |
| E2003 | `int`（单独类型词作语句）→ `declaration syntax: TYPE (const)? (frac)? NAME [= init] (e.g. %s x = 1 / …)` | 声明不符合形状（含省略 let 的声明、别名类型名等迁移提示场景） | 按 `let 类型 名字 = 初值` 形状改写 | 否 |
| E2005 | `struct P`（缺缩进字段块）；顶层出现孤立 `else` 等 → `expected a top-level item (function/use/declaration), got %s` | 顶层位置出现非顶层项 | 补全 struct 缩进字段块 / 删除孤立 else 等 | 否 |
| E2006 | `let int 1x = 2`（名字非标识符）→ `expected %s (identifier), got %s` | 名字位置不是标识符（注意 `err` 等是关键字） | 换一个合法标识符（避开关键字） | 否 |
| E2007 | `if a then`（期望关键字处给错 token）→ `expected %s (%s), got %s` | 关键字缺失或写错 | 按提示补/改关键字 | 否 |
| E2008 | `cast(1, 2)`（cast 第二参须类型）→ `expected a type, got %s` | cast 第二参不是类型 | 写类型名：`cast(x, i32)` | 否 |

### 2x2 声明形状

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E2010 | `let int int d = 1` 或 `let i32 int x`；`long long`（long 与 long 混写）→ `duplicate base type: a declaration has exactly one base type (alias and width names cannot be mixed)` | 一个声明只允许一个基本类型（别名与宽度名不可混写） | 只保留一个类型词（建议统一宽度名） | 否 |
| E2012 | `const k`（const 无初值）→ `const requires an initializer` | const 缺初值 | 补 `= 初值` | 否 |
| E2013 | `let int frac a[] = 1/2`（列表带 frac）→ `lists do not support the frac modifier` | 列表不支持 frac 修饰 | 去掉 frac | 否 |
| E2014 | `let int frac a[3] = 1`（数组带 frac）→ `arrays do not support the frac modifier` | 数组不支持 frac 修饰 | 去掉 frac | 否 |
| E2015 | `fn i32 frac f(let int frac a[3])`（参数带 frac 的数组）→ `array/list parameters do not support the frac modifier` | 数组/列表参数不支持 frac | 参数去掉 frac | 否 |

### 2x3 已删除/受限语法

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E2017 | `t.item`（保留码：点访问已开放为 struct 字段语法 `ps[1].x`，仅命名空间形态仍用 dotted 名） | 现版本不再报 dot syntax removed；字段访问经 EField 节点 | —（现版本正常程序不触发） | 否 |
| E2018 | `array int a` / `list f64 b` → `'array'/'list' keywords removed: arrays are written T a[N], lists T a[]` | array/list 关键字已删除 | 数组写 `i32 a[4]`，列表写 `i32 a[]` | 否 |
| E2019 | `* p = 1`（星号在声明开头）→ `'*' must follow a type to form a pointer (syntax T*, e.g. i32* p)` | 星号不能起头声明 | 写 `let i32* p = …`（T* 形式） | 否 |
| E2020 | `[i32; 4] x`（旧切片类型写法）→ `'[]T' / '[T;N]' (slice/array type) syntax removed` | 旧切片/数组类型写法已删 | 数组写 `i32 x[4]` | 否 |
| E2021 | `panic()`（无消息参数）→ `panic requires a message argument: panic(msg) or panic(code, msg)` | panic 至少要消息 | `panic("msg")` 或 `panic(code, "msg")` | 否 |

### 2x4 output / struct / use / extern

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E2022 | `output(1, sep=',' , sep='|')` → `duplicate sep parameter in output` | sep 命名参数重复 | 只保留一个 sep | 否 |
| E2023 | `output(1, end='\n', end='')` → `duplicate end parameter in output` | end 命名参数重复 | 只保留一个 end | 否 |
| E2024 | struct 字段写 `x = 1`（缺类型）→ `struct field syntax: TYPE NAME [= default]` | 字段缺类型 | 补类型：`i32 x = 1` | 否 |
| E2025 | `use myfile`（缺 .zfy）→ `use file name must end with .zfy` | use 文件名缺后缀 | 改 `use myfile.zfy` | 否 |
| E2031 | `extern "Sys" f()`（链接名非 "C"）→ `extern supports only "C", got "%s"` / `expected "C" after extern` | extern 链接名只支持 "C" | 写 `extern "C" f()` | 否 |

### 2x5 括号/逗号/语句形状（本轮补录）

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E2027 | 语句中出现孤立分号（非 for 头部）→ `semicolon is only allowed in for headers` | 分号只允许出现在 for 头部 | 删除分号（for 头部各段用 `,` 分隔） | 否 |
| E2028 | `i32 const f(let i32 x)`（参数用 const）→ `parameters do not support const` | 参数不支持 const | 参数去掉 const | 否 |
| E2029 | 参数用 unred 修饰 → `parameters do not support unred` | 参数不支持 unred | 去掉 unred | 否 |
| E2030 | struct 字段 `i32 a[3] = …`（数组/列表字段带默认值）→ `array/list struct fields cannot have default values` | 数组/列表字段不能有默认值 | 去掉 `= …` 默认值 | 否 |
| E2032 | `fn i32 f(let int a let int b`（参数类型表未闭合）→ `expected ',' or ')' to end the parameter type list` | 参数表缺逗号/未闭合 | 补 `,` 或 `)` | 否 |
| E2033 | `a[1 2]`（下标/切片列表未闭合）→ `expected ',' or ']'` | 下标/切片列表缺逗号/未闭合 | 补 `,` 或 `]`（切片两端逗号分隔、含头含尾） | 否 |
| E2034 | `f(1; 2)`（实参间用分号）→ `';' is not allowed between call arguments; use ','` | 实参间误用分号 | 改用 `,` | 否 |
| E2035 | `f(1 2)`（调用实参表未闭合）→ `expected ',' or ')' to end the argument list` | 实参表缺逗号/未闭合 | 补 `,` 或 `)` | 否 |
| E2036 | `panic(1 2)`（panic 实参表未闭合）→ `expected ',' or ')' to end the panic arguments` | panic 实参表未闭合 | 补 `,` 或 `)` | 否 |
| E2037 | 块未关闭直到 EOF → `unexpected end of input (unclosed block)` | 缩进块未闭合 | 检查缩进层级，补全块内容或回退缩进 | 否 |
| E2038 | `output(1, sep=',', 2)`（命名参数不居末）→ `named output parameters (sep/end) must come last` | 命名参数必须在末尾 | 把 sep/end 挪到实参表末尾 | 否 |
| E2039 | `output(1 2)`（output 实参表未闭合）→ `expected ',' or ')' to end the output argument list` | output 实参表未闭合 | 补 `,` 或 `)` | 否 |
| E2040 | `input(x, delim=',', y)`（delim 不居末）→ `input's delim parameter must come last` | delim 必须居末 | delim 挪到目标表末尾 | 否 |
| E2041 | `input(x 2)`（input 目标表未闭合）→ `expected ',' or ')' to end the input target list` | input 目标表未闭合 | 补 `,` 或 `)` | 否 |
| E2042 | `s[1..3]`（Python/C 风格 `..` 切片写法）→ `invalid syntax 'a..b': slice syntax is s[a,b:step] (comma-separated, both ends inclusive)` | 切片语法应为逗号分隔 | 写 `s[1,3]`（两端含头含尾；带步长写 `s[1,3:step]`） | 否 |

> 跳号：E2002/E2004/E2009（占位）并入 E2001（同文案"期望表达式"）；E2011 删除（别名映射变更：long=i128 / ulong=u128 为独立类型，long int / long long / ulong int / ulong long 废止——long 后跟类型词报 E2010）；E2016 并入 E2003（声明语法提示）；E2026 并入 E2005（顶层项期望）。

---

## 3. 类型/语义错误（E3xxx，Typeck，语句/函数/顶层项级恢复 [多错误恢复]）

**代表性代码示例**：

```zfy
struct Point
    i32 x
    i32 y

fn i32 add(let i32 a, let i32 b)
    return a + b

fn main()
    let Point p = Point(1, 2)
    let i32 b = "str"       // ← E3005 type mismatch: expected i32, got string
    let i64 n = 2.5         // ← E3190 浮点字面量落整数槽须显式 cast
    output(p.z)             // ← E3087 struct Point has no field z（无相近字段不硬凑）
    let i32 w = zz + 1      // ← E3011 undefined variable: zz（唯一候选时自动改名）
```

### 3x1 类型解析

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3001 | `let foo x = 1`（foo 非类型）；`type T = T2`（T2 未定义）；`f(T3 x)`（参数类型未定义）；`P(1)`（P 未定义）→ `undefined type: %s` | 引用了未定义的类型名（含已删除的传统别名） | 定义该类型或改用存在的类型；传统别名改宽度名 | 是——传统别名迁移（int→i32、short→i16、long→i128、signed→i32、unsigned→u32、ulong→u128、float→f32、double→f64、byte→i8，改名级） |
| E3004 | 类型推断出现循环约束 → `circular type inference constraint` | 推断依赖成环 | 给变量显式标注类型，打破循环 | 否 |

### 3x2 类型不匹配/转换/初始化

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3005 | `let i32 b = "str"`；`f(g())`（实参类型不符）→ `type mismatch: expected %s, got %s (numeric conversion requires an explicit cast)` | 期望与实际类型不符；数值转换须显式 cast | 改用匹配类型；数值跨型写 `cast(x, T)`；char 落整数槽可自动插入 cast | 是——char → 整数槽时按 ord 码点插入 cast（语义级） |
| E3007 | `output(some_int as string)`（无 cast 转 string）→ `type %s cannot convert to string` | 该类型不能直接转 string | 用 `cast(x, string)` 显式转换 | 否 |
| E3008 | `cast(p, i32)`（指针转整数等非法转换）→ `unsupported cast: %s -> %s` | 该转换方向不支持 | 改用合法转换路径（如经 string 解析）或重构类型 | 否 |
| E3009 | `let i32* p`（无初值的不可省略类型）→ `type %s cannot omit an initializer` | 该类型声明必须带初值 | 补初值（指针可 `= null`） | 否 |
| E3010 | `let i32 x = f()!`（T! 直接当 T 用）→ `fallible value used directly as a plain value (unwrap with ?? or propagate with ?): got %s, expected %s` | 可失败值未解包 | `f() ?? 默认值/缩进块` 解包，或 `f()?` 向上传播 | 否 |

### 3x3 变量/常量/赋值

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3011 | `output(a)`（a 未声明）；`a = 1`；`1.field = 2`（左值未定义）；move 后再使用之外的未定义引用 → `undefined variable: %s` | 引用了未声明的名字（含拼写错） | 先声明再使用，或改正名字 | 是——存在唯一最近候选（最小编辑距离且并列唯一）时自动改名（改名级，最多 4 轮） |
| E3013 | move 后再使用：`let string s2 = move s` 后 `output(s)` → `variable %s has been moved and cannot be used (reassign to revive it)` | 值已被 move | 重新赋值复活；或利用循环内自动克隆语义 | 否 |
| E3014 | `const k = 1` 后 `k = 2` → `cannot assign to constant %s (declared const)` | const 不可赋值 | 改用 let 声明，或去掉该赋值 | 否 |
| E3015 | `const arr[3] = 1,2,3` 后 `arr[0] = 9` → `cannot modify elements of constant %s` | const 深不可变 | 数组改用 let 声明 | 否 |
| E3016 | move 后写入：`move f(arr)` 后 `arr[0] = 1` → `array %s has been moved and cannot be written` | 数组已被 move | 重新赋值或调整 move 时机 | 否 |
| E3017 | `s[0] = 'x'`（string 下标写）→ `strings do not support index assignment (use replace for ranges)` | string 不支持下标写 | 用 replace 做区间替换 | 否 |
| E3018 | `s[0,2] += "a"` → `string slices do not support augmented assignment` | string 切片不支持复合赋值 | 写 `s = s[0,2] + "a"` 或整体 `s += "a"` | 否 |
| E3019 | `fr[0,2] += 1`（frac 切片）→ `frac slices do not support augmented assignment` | frac 切片不支持复合赋值 | 逐元素运算或整体重算赋回 | 否 |
| E3020 | `h[0,2] += 1.0`（half/quad 切片）→ `f16/f128 slices do not support augmented assignment` | f16/f128 切片不支持复合赋值 | 逐元素处理 | 否 |
| E3021 | `p += 1`（unsafe 内指针复合赋值）→ `pointers do not support augmented assignment/inc/dec (arithmetic only as p = p + n inside unsafe)` | 指针不支持复合赋值/自增自减 | unsafe 内写 `p = p + n` | 否 |
| E3022 | `a[1,2] += 1`（a 非 seq）→ `augmented assignment target does not support indexing: %s` | 该类型不支持下标复合赋值 | 确认目标是数组/列表/string | 否 |
| E3023 | `a[0,2] += 1`（a 非 seq，切片形式）→ `augmented assignment target does not support slicing: %s` | 该类型不支持切片复合赋值 | 确认目标是 string/array/list | 否 |
| E3024 | `*p += 1`（非数值/指针）→ `dereferenced augmented assignment supports only numeric/pointer types, got %s` | 解引用复合赋值仅限数值/指针 | 检查 p 的指向类型 | 否 |
| E3025 | `*x = 1`（x 非指针，复合/自增自减）→ `augmented/inc/dec target must be a pointer dereference, got %s` | 目标须为指针解引用 | 改为普通变量赋值，或使用正确指针 | 否 |
| E3026 | `1 = 2` → `augmented/inc/dec target must be a variable or array/list element` | 复合赋值目标须变量/元素 | 改用变量作为目标 | 否 |
| E3027 | const struct 后 `pl.name = "x"` → `cannot assign to field of constant %s (const is deeply immutable)` | const 深不可变 | struct 改用 let 声明 | 否 |
| E3028 | struct 复合赋值非标量字段 `pl.pos += 1` → `struct field augmented assignment supports only numeric scalar fields, got %s` | 字段复合赋值仅限数值标量 | 整体读出、修改后写回 | 否 |
| E3029 | `1.field = 2`（类型不支持字段赋值）→ `type %s does not support field assignment %s` | 该类型无字段写语义 | 目标须为 struct 变量/元素槽 | 否 |
| E3031 | `*p = "s"`（写非标量）→ `dereference assignment supports only scalar/pointer types (for now), got %s` | 解引用写仅限标量/指针 | 检查指向类型或改写法 | 否 |
| E3032 | `a[0] = p`（写 struct 等聚合）→ `type %s does not support index assignment` | 元素类型不支持整体下标写 | 逐字段写，或改为受支持的元素类型 | 否 |
| E3033 | （已删除：下标写目标泛化为槽根——变量/字段链/ref/元素槽，w-014 #3） | 码位作废 | — | 否 |
| E3034 | `*x = 1`（x 非指针，普通赋值）→ `assignment target must be a pointer dereference, got %s` | 赋值目标须为指针解引用 | x 须为指针类型 | 否 |
| E3035 | 无法解析的赋值目标；`p^ -= v`（string 解引用仅支持 +=，w-020）→ `unsupported assignment target`；`dereferenced string only supports += (concatenation)` | 赋值目标形态无法解析 | string 解引用改用 `+=`；其余按目标形态改写 | 否 |
| E3036 | `move 5` 或 `move f()` → `cannot move constant %s` | 常量不可 move | move 仅用于变量 | 否 |
| E3037 | `move g`（全局变量）→ `cannot move global variable %s` | 全局变量不可 move | 改为局部变量传参 | 否 |
| E3038 | `let string s2 = move s` 两次 → `variable %s has already been moved` | 重复 move | 第二处改用重新赋值后的值或克隆 | 否 |
| E3039 | `move i`（i 是 int）→ `move supports only string/array/list arguments, %s has type %s` | move 仅支持 string/array/list | 标量直接赋值即可（值语义） | 否 |
| E3040 | 顶层 `const frac r = 1/2` → `top-level const does not support frac/unred` | 顶层 const 不支持 frac/unred | frac 常量移入函数内（仅函数内合法） | 否 |
| E3041 | 顶层 `const k = 1` 两次 → `duplicate top-level constant: %s` | 顶层常量重名 | 改名或删除重复定义 | 否 |
| E3042 | 顶层 `const d = 1.5` → `top-level const currently supports only integer types, got %s` | 顶层 const 仅整数类型 | 浮点常量移入函数内，或改为整数 | 否 |
| E3043 | 顶层 `let int g = 1` 两次；顶层变量与函数同名后再声明 → `duplicate top-level variable: %s` | 顶层变量重名/与函数同名 | 改名或删除重复定义 | 否 |

### 3x4 运算符

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3045 | `1 + "a"`（两侧异型）；`s += "a"`（s 为 int）→ `string concatenation requires both sides to be string, got %s and %s`（单参形态 `got %s`） | 字符串拼接两侧须均为 string | 两侧 `cast(x, string)`，或修正操作数 | 否 |
| E3047 | unsafe 外 `p + 1`、`p - 1`、`p - q` → `pointer arithmetic is only allowed inside an unsafe block` | 指针算术仅限 unsafe | 把运算放进 unsafe 块 | 否 |
| E3048 | unsafe 内 `p1 + p2` → `cannot add two pointers` | 两指针相加非法 | 指针 + 整数偏移 | 否 |
| E3049 | unsafe 内 `1.5 + p`（整数不能与指针相加）→ `cannot add an integer to a pointer` | 浮点不能与指针相加 | 偏移量改为整数 | 否 |
| E3052 | unsafe 内 `1 - p` → `cannot subtract a pointer from an integer` | 整数减指针非法 | 改为 `p - n` 或同型指针差 `p - q` | 否 |
| E3053 | `p < 1` → `pointer comparison requires both sides to be pointers or null, got %s and %s` | 指针比较两侧须指针或 null | 与 null 或同型指针比较 | 否 |
| E3054 | `p * 2` → `unsupported pointer operation: %s (only + - inside unsafe and == !=)` | 指针仅支持 unsafe 内 + - 与 == != | 改用合法操作 | 否 |
| E3055 | `"a" < 1` → `comparison requires numeric types, got %s and %s` | 比较须数值类型（string/char 另有路径） | cast 成同型再比较 | 否 |
| E3056 | `true + 1` → `arithmetic requires numeric types, got %s and %s` | 算术须数值类型 | bool 不参与算术；char 无数值运算，需要时先 cast | 否 |
| E3057 | `-true` → `unary minus requires a numeric type, got %s` | 一元负号须数值类型 | 修正操作数类型 | 否 |

### 3x5 内建操作（output/input/length/find/prec/sizeof/push/函数指针）

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3058 | `panic_handler(1)` → `panic_handler expects a function name argument: panic_handler(fn)` | panic_handler 须函数名 | 传函数名 | 否 |
| E3059 | `panic_handler(fn)`（fn 签名不符）→ `panic_handler signature must be (i32, string) -> void, got (%s) -> %s` | 处理函数签名不符 | 按 `(i32, string) -> void` 定义 | 否 |
| E3061 | `push(a, 1)`（a 是数组）→ `push target must be a list, got %s` | push 目标须列表 | 改用列表（数组定长不可 push） | 否 |
| E3062 | `push(1)` → `push takes two arguments: push(list, value)` | push 须两参 | 补目标列表与值 | 否 |
| E3063 | `sizeof(1)` → `sizeof/alignof does not support type %s` | sizeof/alignof 须类型名 | 传类型：`sizeof(i32)` | 否 |
| E3064 | `sizeof(3+1)` → `%s expects a type name argument, e.g. %s(Point)` | 实参须类型名 | 传类型名而非表达式 | 否 |
| E3065 | `fp(1, 2)`（fp 期望 1 参）→ `function pointer expects %d arguments, got %d` | 函数指针调用实参数不符 | 按签名传参 | 否 |
| E3066 | `fp(move s)` → `function pointer calls do not support move arguments` | 函数指针调用不支持 move | 去掉 move | 否 |
| E3067 | `fp(x=1)` → `function pointer calls do not support named argument %s=` | 函数指针不支持命名实参 | 用位置实参 | 否 |
| E3068 | `f(x=1)`（普通函数命名实参）→ `function calls do not support named argument %s=` | 普通函数不支持命名实参（output/input 除外） | 用位置实参 | 否 |
| E3069 | `(a + b)(1)` → `unsupported callee expression` | 被调须为函数/函数指针 | 用函数名或函数指针变量 | 否 |
| E3070 | `1[0]` → `type %s does not support index access` | 类型不支持下标 | 目标须 string/array/list | 否 |
| E3071 | `1[0,1]` → `slicing is only for string/array/list, got %s` | 切片仅限 string/array/list | 修正目标类型 | 否 |
| E3072 | `&f()`（取临时地址）→ `'&' can only take the address of a variable/field/element` | 取址须可定位目标 | 对变量/字段/元素取址 | 否 |
| E3073 | `&f()`（f 返回 void）→ `cannot take the address of a void value` | void 无地址 | 对有值表达式取址 | 否 |
| E3074 | `*1` → `dereference requires a pointer type, got %s` | 解引用须指针 | 操作数改为指针 | 否 |
| E3075 | `a[1.5]` → `an integer type is required, got %s` | 下标须整数 | 下标改为整数（浮点先 `cast(x, i32)`） | 否 |
| E3076 | `replace(1, 0, "x")`（目标参数须 string）→ `%s expects a string for its %s parameter, got %s` | 参数须 string | 传 string | 否 |
| E3077 | `trim(1, 'a')`（参数类型不符）；`s += 5`/元素 `+=` 非 string/char（w-020 文案统一）→ `%s does not accept type %s for its %s parameter`；`string concatenation requires string or char, got %s`；`string element concatenation requires string or char, got %s` | 内建参数类型不符/拼接类型不符 | 按文案传正确类型（string/char） | 否 |
| E3078 | `length(1)` → `length expects string/array/list, got %s` | length 目标类型受限 | 传 string/array/list | 否 |
| E3079 | `find("a", 'a', count=0)` → `find's count must be > 0, got %Ld` | count 须正数 | count ≥ 1 | 否 |
| E3080 | `prec(true, 2)` → `prec does not support type %s` | prec 不支持该类型 | 用数值/string/char | 否 |
| E3081 | `prec("a", 1.5)` → `prec's length parameter must be integer/char/float, got %s` | 长度参数类型不符 | 长度用整数/char/浮点 | 否 |
| E3082 | `split(s, sep='a', x=1)` → `malformed argument list for builtin %s (positional arguments must precede named ones)` | 位置实参须在命名实参之前 | 调整实参顺序 | 否 |
| E3083 | `replace(1, 'x')`（旧字符参数须 char）；`trim(s, 65)` 等第二参非 char/string（w-020 文案统一）；`find(..., count=0)` → `a char is required (%s), got %s`；`%s's %s must be char or string, got %s`；`find's count must be > 0, got %s`；`replace requires (s, a, b, rep)`（两参形式已删除，w-020） | char/string 参数类型不符；replace 两参形式已删 | 按签名传参；replace 用 `(s, 起, 止, rep)` 四参区间形式 | 否 |
| E3084 | `input(struct_target)` → `input target must be string/integer/float/bool/char, got %s` | input 目标类型受限 | 目标改为标量/string 变量（按目标宽度写槽） | 否 |
| E3085 | `output(Point(1,2))`（struct 直接输出）→ `output does not support argument type: %s` | output 不支持 struct 直出 | 逐字段 output | 否 |
| E3086 | `input(x, delim=1)`；`split(s, ' ')`（w-020 编译期拒绝）→ `input's delim must be char or string, got %s`；`split does not accept ' ' as the delimiter (a C string can never contain NUL)` | delim 类型不符/分隔符为 NUL | delim 用 char/string；split 分隔符改非 `'\0'` 字符 | 否 |

### 3x6 struct

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3087 | `p.z`（无字段 z）→ `struct %s has no field %s` | 字段不存在（字段表内联 did-you-mean） | 改用存在的字段名 | 否 |
| E3088 | `1.x` → `type %s has no field %s (dot access is only for structs)` | 点访问仅限 struct | 目标改为 struct | 否 |
| E3089 | `p.x`（p 非 struct）→ `type %s does not support field access %s` | 非 struct 不支持字段访问 | 修正目标类型 | 否 |
| E3091 | `P(move s)` → `struct constructor does not support move arguments` | 构造不支持 move | 直接传值（构造即拷贝） | 否 |
| E3092 | `P(1,2,3)`（只有 2 字段）→ `struct %s has %d fields, got %d positional arguments` | 位置实参数不符 | 按字段数传参 | 否 |
| E3093 | `P(x=1, x=2)` → `field %s initialized twice` | 字段重复初始化 | 每字段只初始化一次 | 否 |
| E3094 | 顶层 `struct Point` 两次 → `duplicate struct definition: %s` | struct 重复定义 | 删除/改名 | 否 |
| E3095 | `struct length`（内建名）→ `struct name %s conflicts with a builtin, rename it` | 与内建名冲突 | 换名 | 否 |
| E3096 | `struct f`（f 已是函数）→ `%s is already a function and cannot also be a struct name` | 与函数重名 | 换名 | 否 |
| E3097 | 字段 `i32 a[n]`（n 非字面量）；切片步长 `s[0,4:0]`（w-020 编译期拒绝）→ `struct field array length must be a compile-time literal`；`slice step must not be 0, got %Ld` | 字段数组长度须编译期字面量；切片步长不得为 0 | 长度写字面量；步长改非 0 | 否 |
| E3098 | `struct S` 内含 `S s` → `struct %s field type cannot be itself (infinite size)` | 自引用无限大小 | 改为指针字段或去掉 | 否 |
| E3099 | `struct S` 内含 `i32! x` → `T! cannot be a struct field (error values are aggregates and cannot be loaded as a field)` | T! 不能作字段 | 用 `??` 解包后存元素类型 T | 否 |
| E3100 | `struct S` 两个 `i32 x` → `struct %s has duplicate field %s` | 字段重名 | 改名/去重 | 否 |

### 3x7 函数/调用/extern

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3101 | `f(1)`（f 未定义）；`panic_handler(g)`（g 未定义）→ `undefined function: %s` | 函数未定义（含拼写错） | 定义该函数或改正名字 | 是——存在唯一最近候选（最小编辑距离且并列唯一）时自动改名（改名级，最多 4 轮） |
| E3102 | `f(1, 2)`（f 期望 1 参）→ `function %s expects %d arguments, got %d` | 实参数不符 | 按签名传参 | 否 |
| E3103 | `type T = ...` 与已有类型/函数冲突 → `type alias %s conflicts with an existing type/function` | 别名与既有名冲突 | 换名 | 否 |
| E3104 | `fn i32 length()` → `function name %s conflicts with a builtin, rename it` | 与内建重名 | 换名 | 否 |
| E3105 | `fn i32 f()` 两次 → `duplicate function definition: %s` | 函数重复定义 | 删除/改名 | 否 |
| E3106 | extern "C" 与 zfy 函数同名 → `duplicate function definition: %s (extern conflicts with an existing function)` | extern 与既有函数重名 | 换名 | 否 |
| E3107 | `extern "C" length()` → `extern function name %s conflicts with a builtin` | extern 名与内建冲突 | 换名 | 否 |
| E3108 | `extern "C" f(let i32 a[3])` → `extern parameters do not support arrays/lists` | extern 参数不支持数组/列表 | 用指针参数或改签名 | 否 |
| E3109 | `extern "C" f(let i32! x)` → `extern parameters do not support T!` | extern 参数不支持 T! | 去掉 T!（错误模型仅 zfy 函数） | 否 |
| E3110 | `extern "C" fn i32! g()` → `extern functions do not support a T! return type (the error model is for zfy functions only)` | extern 返回不支持 T! | 返回普通类型或改 zfy 函数 | 否 |
| E3111 | `fn i32 f()` 内无 return → `function %s declares return type %s but may not return a value` | 非 void 函数可能不返回值 | 补 return（main 裸 return = return 0） | 否 |

### 3x8 frac

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3113 | `let half frac x = 1/2`（f16 frac）→ `frac does not support element type %s (supported: i8..i128 / u8..u128 / f32 / f64 / f128)` | frac 元素类型不支持 | 改用受支持的元素类型 | 否 |
| E3114 | `let i32 frac a = 1/2` 与 `let i64 frac b` 运算；`let i32 frac a = i64_frac_变量`（初始化元素类型不符，无占位形态）→ `mismatched frac element types: %s vs %s` / `mismatched frac element types` | frac 元素类型不匹配 | 统一元素类型（cast） | 否 |
| E3115 | `fr + 1`（frac 与标量）；`1 + fr` → `%s cannot be mixed with %s in this operation` | frac 与标量混算 | 两侧统一为 frac 或标量 | 否 |
| E3117 | `fr % 2` → `frac does not support modulo` | frac 不支持取模 | 用除法/乘法组合表达 | 否 |
| E3118 | `let i32 frac a = "x"`（右值既非分数也非数值标量；int/uint/float 标量自动提升为分数，不触发）→ `cannot initialize %s as frac` | frac 初值形态非法 | 用 n/d 字面量、数值标量或 `(前缀,循环节,)` 循环小数 | 否 |
| E3119 | `frac arr[]` → `frac arrays/lists are not yet supported` | frac 序列暂不支持 | 用 frac 标量逐个处理 | 否 |
| E3120 | `fn i32 frac f(let i32 frac a)`（参数元素类型不符时）→ `frac parameter does not support element type %s` | frac 参数元素类型不符 | 统一元素类型 | 否 |
| E3121 | `half frac f()`（返回类型不符）→ `frac return type does not support element type %s` | frac 返回元素类型不符 | 改受支持元素类型 | 否 |
| E3122 | `const fr` 后 `reduce(fr, 2, 2)` → `cannot reduce constant %s` | const 不可 reduce | 用 let 声明 frac 变量 | 否 |
| E3123 | `reduce(x, 2, 2)`（x 非 frac）→ `reduce requires a frac-typed variable, got %s` | reduce 目标须 frac 变量 | 传 frac 变量 | 否 |
| E3124 | `reduce(1, 2, 2)` → `reduce's first argument must be a frac-typed local variable` | 首参须 frac 局部变量 | 传 frac 局部变量 | 否 |
| E3125 | `let i32 frac x = f() ?? 缩进块` → `frac/unred does not support ??-block initialization` | frac/unred 不支持 ?? 块初始化 | 先解包再初始化，或改用普通类型 | 否 |

### 3x9 数组/列表声明

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3126 | （已删除：struct 作数组/列表元素已支持，w-014 #2——运行时按 seq 头部 kind/ops 深拷贝） | 码位作废 | —（现为合法写法） | 否 |
| E3127 | `i32! xs[]`（已删除，v3 2026-10-11：T! 允许作数组/列表元素）→ 原文案 `T! cannot be an array/list element (error values are aggregates and cannot be loaded by index)` | 码位作废 | —（现为合法写法） | 否 |
| E3128 | `let i32 a["n"]` → `array length must be an integer, got %s` | 数组长度须整数 | 长度用整数字面量或 const | 否 |
| E3129 | `let i32 a[x]`（x 非 const）→ `array length must be a compile-time constant (a literal or const integer variable)` | 长度须编译期常量 | 用字面量或 const 整数变量 | 否 |
| E3130 | `let i32 a[3]`（列表写法带了长度）→ `lists take no length` | 列表不写长度 | 去掉长度：`let i32 a[]` | 否 |
| E3131 | `let i32 a[]`（数组写法缺长度）→ `arrays require a length` | 数组须长度 | 补长度：`let i32 a[N]` | 否 |
| E3132 | `let i32 a[2] = 1,2,3` → `%d initial values exceed array length %Ld` | 初值个数超长 | 减初值或扩长度 | 否 |
| E3133 | `f(n, b[m])`（m 非前参）；`f(b[x])`（x 为表达式）→ `array parameter length must be a literal or a previously declared parameter`（带 `: %s` 与不带两形态） | 数组参数长度须字面量或前参 | 长度用字面量或前面声明的参数 | 否 |

### 3xA 错误值 T! / ? / ?? / err

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3135 | `ErrCode.Nope` → `undefined error code: ErrCode.%s` | 错误码未定义 | 用已定义的 ErrCode 成员 | 否 |
| E3136 | `1 ?? 2`（左侧非 T!）→ `left side of ?? must be a fallible value (T!), got %s` | ?? 左侧须 T! | 左侧改为 T! 表达式 | 否 |
| E3137 | `let i32 x = a ?? 缩进块`（类型不符时）→ `??-block declaration type must be the element type T (without '!')` | ?? 块声明类型须为元素 T（无 !） | 声明类型去掉 `!`，写元素类型 | 否 |
| E3138 | `a ?? 缩进块`（独立语句）→ `??-block form (a ?? indented block) is only allowed as the RHS of a declaration or assignment` | ?? 块仅限声明/赋值右值 | 改为 `let T x = a ?? 块` 或 `x = a ?? 块` | 否 |
| E3139 | `x = a ?? 缩进块`（目标非变量）→ `??-block assignment target must be a variable (for now)` | ?? 块赋值目标暂须变量 | 目标改为变量 | 否 |
| E3140 | `a?`（a 非 T!）→ `? left side must be a fallible value (T!), got %s` | ? 左侧须 T! | 左侧改为 T! 表达式 | 否 |
| E3141 | `a?`（在 void 函数内）→ `? propagation requires the enclosing function to return T! (current: void)` | ? 传播要求函数返回 T! | 函数改返回 T! 或改用 ?? 解包 | 否 |
| E3142 | `a?`（返回类型不匹配）→ `? propagation requires the enclosing function to return %s! (current: %s)` | ? 传播元素类型须一致 | 统一 T! 元素类型 | 否 |

### 3xB 补录（errors.md 重写时补充单列）

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3144 | `i32[2]` 形状与 `i32[3]` 形状参与运算 → `array lengths differ: %d vs %d` | 定长数组长度不同不可运算 | 统一长度或逐元素处理 | 否 |
| E3145 | `push(move s, …)` 等内建带 move 实参 → `builtin %s does not support move arguments` | 内建不支持 move 实参 | 去掉 move | 否 |
| E3146 | `let bool b = "x"` → `bool can only be initialized with true/false, 0/1, or a boolean expression` | bool 初值受限 | 用 true/false、0/1 或布尔表达式 | 否 |
| E3147 | `remove(1, 0)`（目标非数组/列表）→ `remove only works on arrays/lists, got %s` / `remove's first argument must be an array/list variable` | remove 目标须数组/列表 | 传数组/列表变量 | 否 |
| E3148 | 程序无 `main()` → `missing main()` | 缺入口函数 | 定义 `fn main()` | 否 |
| E3149 | 块表达式出现在不支持的位置 → `block expressions are not supported here` | 块表达式位置受限 | 改写为普通语句/表达式 | 否 |
| E3150 | move 的对象不是简单局部变量 → `move can only apply to a local variable` | move 仅限局部变量 | 先赋给局部变量再 move | 否 |
| E3151 | `const s = ""` 后 `input(s)` → `cannot input into constant %s` | input 目标不可 const | 用 let 变量 | 否 |
| E3152 | move 后 remove：`move f(arr)` 后 `remove(arr, 0)` → `array %s has been moved and cannot be removed from` | 数组已 move | 调整 move 时机 | 否 |
| E3153 | `const arr` 后 `remove(arr, 0)` → `cannot remove from constant %s` | const 不可 remove | 用 let 数组/列表 | 否 |
| E3154 | struct A 内含 B、B 内含 A（循环嵌套）→ `struct %s has circular nesting (infinite size)` | 循环嵌套无限大小 | 打破循环（改指针字段） | 否 |
| E3155 | 窄化转换未加显式 cast（宽化自动，窄化显式）→ `narrowing conversion from %s to %s requires an explicit cast` | 窄化须显式 cast | 写 `cast(x, T)`；整数字面量在目标范围内时自动插入 cast | 是——整数字面量值在目标范围内时插入 cast（语义级） |
| E3156 | 通过指向 const 的指针（T* const）解引用写 → `cannot write through pointer-to-const %s (declared T* const)` | const 指针不可写 | 去掉 const 或改用非 const 指针 | 否 |
| E3157 | `f(copy b)` 且 b 为最后使用（与自动 move 冲突）→ `explicit copy conflicts with automatic move: %s is not used after this point, the value is moved automatically (remove 'copy')` | 显式 copy 与自动 move 冲突 | 去掉 copy | 否 |
| E3158 | `f(ref v)` 但参数未声明 ref → `argument %d of %s is passed by ref, but the parameter is not declared ref` | 实参 ref 而形参未声明 | 形参加 ref，或实参去掉 ref | 否 |
| E3159 | 参数为 ref 但实参未加 ref → `parameter %d of %s is ref, pass the argument with ref (f(ref x))` | 形参 ref 而实参未加 | 实参加 ref | 否 |
| E3160 | `f(ref c)`（c 为 const）→ `cannot pass constant %s by ref` | const 不可 ref 传 | 用 let 变量 | 否 |
| E3161 | `f(ref (a+b))`（ref 实参非变量）→ `ref can only apply to a variable (pass-by-reference needs an addressable variable)` | ref 须可寻址变量 | 传变量 | 否 |
| E3162 | `i32[3] ref a` / `struct S ref s` / `i32 frac ref x`（ref 参数类型不符）→ `ref parameters support scalar/string types only` | ref 参数仅限标量/string | 数组/列表/frac/struct 参数去掉 ref | 否 |
| E3163 | extern "C" 参数带 ref → `extern parameters do not support ref` | extern 参数不支持 ref | 去掉 ref | 否 |
| E3164 | 变量声明带 ref（`let i32 ref x = 1`）→ `ref is only allowed on function parameters` | ref 仅限参数 | 声明去掉 ref | 否 |
| E3165 | `i32 frac ref x`（参数同时带 frac 与 ref）→ `ref parameters do not support the frac modifier` | ref 参数不支持 frac | 去掉其一 | 否 |
| E3166 | 函数指针调用带 ref 实参 → `function pointer calls do not support ref arguments` | 函数指针不支持 ref 实参 | 去掉 ref | 否 |
| E3167 | struct 构造/内建函数带 ref 实参 → `%s does not support ref arguments`（struct 构造为固定文案） | 构造/内建不支持 ref | 去掉 ref | 否 |
| E3168 | move 赋值源非聚合变量槽（内部错误兜底）→ `move assignment requires an aggregate variable source` | move 赋值源须聚合变量槽 | 源改为聚合局部变量 | 否 |
| E3169 | `let Box<i32> x`（未定义的泛型 struct）→ `undefined generic struct: %s` | 泛型 struct 未定义 | 先定义 `<T> struct Box ...` | 否 |
| E3170 | `let Box<i32, f64> b = Box(1)`（泛型实参数不符）→ `generic struct %s expects %d type arguments, got %d` | 泛型实参数不符 | 按定义给足类型实参 | 否 |
| E3171 | `Box<T!> x` / `Box<frac<i32>> x` / `Box<T> x`（T 未绑定）（实参类型非法）→ `T! cannot be a type argument` / `frac cannot be a type argument` / `a generic type argument must be a concrete type` / `this type cannot be used as a generic type argument` | 类型实参非法 | 用具体类型作类型实参 | 否 |
| E3172 | `zero()`（泛型函数/构造的类型实参无法推断）→ `cannot infer type argument for %s (in call to %s)` / `cannot infer type argument for %s (constructor of %s)` / `cannot infer type argument for field %s of %s (got %s)` / `cannot infer type argument for parameter %s of %s (got %s)` | 类型实参无法推断 | 显式给出类型实参，或让声明/实参提供期望类型 | 否 |
| E3173 | `<T> void f(T ref x)`（泛型函数带 ref 参数）→ `generic functions do not support ref parameters` | 泛型函数不支持 ref 参数 | 去掉 ref | 否 |
| E3174 | `<T> void main()` → `main cannot be a generic function` | main 不可泛型 | 去掉类型参数 | 否 |
| E3175 | `<T, T> void f(T x)`（类型参数重名）→ `duplicate type parameter in %s` | 类型参数重名 | 改名区分 | 否 |
| E3176 | `let i64 a = 1267650600228229401496703205376`（大字面量非 i128/u128 上下文）→ `large integer literal %s requires an i128/u128 context, got %s` | 大字面量需 i128/u128 上下文 | 声明为 i128/u128 | 否 |
| E3177 | `let u128 b = 340282366920938463463374607431768211456`（超出 u128）→ `integer literal %s overflows i128` / `integer literal %s overflows u128` | 字面量超 i128/u128 | 缩小数值 | 否 |
| E3178 | `1 = 2, 3`（序列字面量赋值目标非法）→ `sequence literal assignment requires an array/list target, got %s` / `sequence literal assignment target must be a list variable, field, or ref parameter` / `sequence literal assignment through ref requires a list parameter, got %s` / `sequence literal assignment requires an array/list field, got %s` | 序列字面量赋值目标受限 | 目标改为数组/列表变量、字段或 ref 参数 | 否 |
| E3179 | `let i32 a[2]` 下 `a = 1, 2, 3`（字面量长度不符）→ `array literal has %d elements but target length is %d` / `array literal has %d elements but field length is %d` | 字面量元素数与目标长度不符 | 对齐元素个数与目标长度 | 否 |
| E3180 | `s[0] = "x"`（string 下标写非 char）→ `string index assignment requires a char, got %s` | string 下标写须 char | 写单字符字面量：`s[0] = 'x'` | 否 |
| E3181 | `fn i32[x] mk()`（类型位置数组长度非字面量）→ `type-position array length must be an integer literal (T[N])` | 类型位置数组长度须字面量 | 长度写字面量 | 否 |
| E3182 | `let i32 a[2][3] = 1, 2`（嵌套声明带初值）→ `nested array/list declarations do not support initializers yet` | 嵌套声明暂不支持初值 | 去掉初值，逐行填充 | 否 |
| E3183 | `f().x = 1`（字段写目标非 struct 元素槽）→ `field assignment target must be a struct array/list element (ps[i].x = v)` | 字段写目标须 struct 元素槽 | 通过元素槽写字段：`ps[i].x = v` | 否 |
| E3184 | `extern "C" { i32[] f() }`（extern 返回序列）→ `extern functions do not support array/list return types (zfy seq is not a C type)` | extern 返回不支持序列 | 返回指针或标量 | 否 |
| E3185 | `for i32 a[] = ...`（for 头部声明数组/列表）→ `for header declarations do not support arrays/lists` | for 头部声明不支持数组/列表 | 循环外声明，for 头部只声明标量 | 否 |
| E3186 | `struct S` 含 `File f` 字段 / `File f[]` / `Box<File>` → `File cannot be a struct field (move-only handle)` / `File cannot be an array/list element` / `File cannot be a type argument` | File 是 move-only 句柄，禁作字段/元素/类型实参 | File 变量保持局部；多处用时以 move 参数传递 | 否 |
| E3187 | `usef(f)`（File 参数未用 move 传）→ `File parameters are move-only: pass with %s(move x)` | File 参数须 move 传 | 写 `usef(move f)` | 否 |
| E3188 | `open("a.txt", "rw+")` → `invalid open mode "%s" (expected "r", "w" or "a")` | 打开模式非法 | 用 "r" / "w" / "a" | 否 |

### 3xC v3.1 后补码（errors.md 以附录 A2 形式补录，2026-10-11）

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E3189 | 裸语句 `cast(pi, i32)`、`push(xs, 1)` 单独成句 → `statement discards a value of type T (cast/find/push/remove and user functions return values; assign it to a variable: x = f(...))` | 产值内建与用户函数返回值不能单独成句丢弃 | 赋给变量：`x = f(...)`；不需要值时赋丢弃变量。例外：fail/panic（非局部退出）、?? 解包块内表达式（块末兜底值即块值） | 否 |
| E3190 | `let i64 x = 2.5`（浮点字面量落整数/char 槽）、`x += 2.5`、`2.0 * x`（与具体整数操作数混算）→ `floating-point literal cannot be used as i64 (explicit cast required)` / `floating-point and integer operands cannot be mixed without an explicit cast, got f64 and i64` | 浮点字面量与整数混用（v3.3.1；此前产坏 IR） | 写 `cast(2.5, i64)` 显式转换；纯字面量混合树（`2.5 + 1`）合法，整树按浮点 | 否 |

> 跳号（类型段）：E3002/E3003 并入 E3001、E3006 并入 E3005、E3012 并入 E3011、E3030 并入 E3011、E3044 并入 E3043、E3046 并入 E3045、E3050/E3051 并入 E3047、E3060 并入 E3101、E3090 并入 E3001、E3112 删除（归 E4012）、E3116 并入 E3115、E3134 并入 E3133、E3143 删除（TErr 元素非法归 E4002）。
>
> 同批变更备忘（2026-10-11 v3.1）：裸 cast 语句重绑定特例删除（原 `cast(a, T)` 单独成句把 a 重绑定为 T 槽，现按 E3189 报错）；push 返回列表、remove 返回被删元素副本；cast(e, frac) 支持（int/bool/char→n/1，float 字面量二进制精确转分数）；bool→整数 cast 由 sext 改 zext（true=1）。

---

## 4. 代码生成错误（E4xxx，Mir/Mir.ml 与 LLVM/Llvmgen.ml）

**代表性代码示例**：

```zfy
fn main()
    while true
        output(1)
    break                    // ← E4010 break outside a loop（continue 同为 E4011）
```

```zfy
fn i64 main()                // ← E4012 main's return type must be void, i32 or i64, got i64
    return 0
```

### 4x1 语义兜底（Mir 降码期，可由用户代码触发 [内部兜底]）

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E4001 | （已删除：push 目标泛化为槽根——变量/字段链/ref/元素槽，w-014 #3） | 码位作废（号段保留连续） | — | 否 |
| E4002 | `f()!`（TErr 元素为 f128 等 128 位类型）→ `error value element type does not support 128-bit width (T! is limited to <=64-bit scalars/string/pointers)`（仅剩 f128 窄/宽 TErr 路径触发，i128/u128 已支持，v3 2026-10-11） | T! 元素超宽限制 | T! 元素改 ≤64 位标量/string/指针 | 否 |
| E4003 | TErr 元素为聚合 → `invalid error value element type (scalar/string/pointer only)`（无括号短形态同码） | 错误值元素仅限标量/string/指针 | 改元素类型 | 否 |
| E4004 | — → `unsupported frac operation` | frac 运算超限 | 检查 frac 操作是否受支持 | 否 |
| E4005 | `1.x = 2`（字段目标）→ `unsupported field-access target` | 字段访问目标非法 | 目标改为 struct 槽 | 否 |
| E4006 | `&1` → `unsupported address-of target` | 取址目标非法 | 对变量/字段/元素取址 | 否 |
| E4007 | `&a[i]`（a 非 seq）→ `element address-of target must be a variable` | 元素取址目标须变量 | 修正目标形态 | 否 |
| E4008 | `x = y`（槽写入目标）→ `unsupported assignment target` | 槽写入目标非法 | 检查赋值目标形态 | 否 |
| E4009 | `reduce(1,2,2)` → `reduce target must be a frac-typed local variable` | reduce 目标须 frac 局部变量 | 传 frac 局部变量 | 否 |
| E4010 | `break`（循环外）→ `break outside a loop` | break 在循环外 | 移入循环体或删除 | 否 |
| E4011 | `continue`（循环外）→ `continue outside a loop` | continue 在循环外 | 移入循环体或删除 | 否 |
| E4012 | `int main()`（main 显式返回类型受限；省略返回类型时隐含 i32，占位 E300-112 并入此处）→ `main's return type must be void, i32 or i64, got %s` | main 显式返回类型仅允许 void/i32/i64 | 写 `fn main()`（隐含 i32）或显式 void/i32/i64 | 否 |

### 4x2 内部一致性兜底（Llvmgen，正常不可触发——前端已拦截）

> 以下 38 码为代码生成阶段一致性检查：前端拦截正常时不可达；若出现，属编译器内部 bug，请最小化复现代码并上报。

| 错误码 | 触发场景 | 文案 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|---|
| E4013 | 非法浮点宽度 | `unsupported float width f%d` | 浮点宽度不在 f16/f32/f64/f128 之列 | 上报编译器 bug | 否 |
| E4014 | TVar 未求解 | `unresolved type variable` | 类型变量漏到代码生成 | 上报编译器 bug | 否 |
| E4015 | 类型大小未知 / struct 未登记 | `undefined struct %s` / `cannot determine type size` | struct 未在生成期登记（"undefined struct %s" 在类型大小计算与字段访问两处触发，同码） | 上报编译器 bug | 否 |
| E4016 | seq 元素非法 | `unsupported array/list element type` | 序列元素类型不受支持 | 上报编译器 bug | 否 |
| E4017 | 指针常量非 null | `pointer constant must be null` | 指针常量只允许 null | 上报编译器 bug | 否 |
| E4018 | 聚合值当标量 | `aggregate value %s must be used as a pointer` | 聚合值被当标量使用 | 上报编译器 bug | 否 |
| E4019 | 局部变量未登记 | `undefined local variable %s` / `undefined variable %s` | 局部变量槽未登记 | 上报编译器 bug | 否 |
| E4020 | 元素类型非法 | `type cannot be stored as an array/list element` | 元素类型不能入槽 | 上报编译器 bug | 否 |
| E4021 | 期望聚合 | `expected aggregate local: %s (oty=%s)` | 期望聚合槽实际不是 | 上报编译器 bug | 否 |
| E4022 | 聚合算术 | `aggregate type does not support arithmetic` | 聚合不支持算术 | 上报编译器 bug | 否 |
| E4023 | 指针运算超限 | `unsupported pointer operation` | 指针操作超出生成期支持 | 上报编译器 bug | 否 |
| E4024 | 浮点取模 | `float type does not support modulo` | 浮点不支持取模 | 上报编译器 bug | 否 |
| E4025 | 布尔运算超限 | `bool type does not support this operation` | bool 运算超限（条件位场景已由 E3000/E3055 前端拦截） | 上报编译器 bug | 否 |
| E4026 | 聚合一元 | `aggregate type does not support unary operations` | 聚合不支持一元运算 | 上报编译器 bug | 否 |
| E4027 | 转 string 超限 | `type cannot convert to string` | 转 string 超出生成期支持 | 上报编译器 bug | 否 |
| E4028 | 聚合 cast | `aggregate type does not support cast` | 聚合不支持 cast | 上报编译器 bug | 否 |
| E4029 | 转换超限 | `unsupported conversion %s -> %s` | 转换超出生成期支持 | 上报编译器 bug | 否 |
| E4030 | output 类型超限 | `output does not support this argument type` | output 实参类型超限 | 上报编译器 bug | 否 |
| E4031 | input 目标超限 | `input does not support this target type` / `input does not support this error-value element type` | input 目标类型超限 | 上报编译器 bug | 否 |
| E4032 | prec 长度参数 | `invalid prec length parameter type` | prec 长度参数类型非法 | 上报编译器 bug | 否 |
| E4033 | 聚合返回未接收 | `aggregate return value must be captured` / `aggregate return value must be captured into a variable` | 聚合返回值未接收 | 上报编译器 bug | 否 |
| E4034 | 非 void 返回未使用 | `non-void return value must be used` | 非 void 返回值被丢弃 | 上报编译器 bug | 否 |
| E4035 | 字段访问目标 | `field access target is not a struct` / `invalid root type for field access` | 字段访问根类型非法 | 上报编译器 bug | 否 |
| E4036 | 字段序号 | `struct %s has no field index %d` | 字段序号越界（原"未定义的 struct P"形态归 E4015） | 上报编译器 bug | 否 |
| E4037 | 槽位类型不一致 | `slot type %s does not match value type %s` | 槽类型与值类型不符 | 上报编译器 bug | 否 |
| E4038 | move 槽类型 | `invalid move target slot type %s` | move 目标槽类型非法 | 上报编译器 bug | 否 |
| E4039 | fail code | `fail's code must be i32` | fail 的 code 非 i32 | 上报编译器 bug | 否 |
| E4040 | MErrOk/MErrValue 类型 | `MErrOk type error: %s` / `MErrValue type error` | 错误值节点类型不符 | 上报编译器 bug | 否 |
| E4041 | panic code | `panic's code must be i32` | panic 的 code 非 i32 | 上报编译器 bug | 否 |
| E4042 | MNorm/reduce 类型 | `norm type error` / `reduce type error` | 归一/reduce 节点类型不符 | 上报编译器 bug | 否 |
| E4043 | 切片复合赋值 | `unsupported augmented-assignment operation on slices` / `unsupported element type for slice augmented assignment` | 切片复合赋值操作/元素类型非法 | 上报编译器 bug | 否 |
| E4044 | 未定义的临时 | `undefined temp %s` | SSA 临时未登记 | 上报编译器 bug | 否 |
| E4045 | MEmptySeq 类型 | `MEmptySeq type is not an array/list` | 空序列节点类型非法 | 上报编译器 bug | 否 |
| E4046 | 取地址目标 | `address-of target is undefined: %s` | 取址目标未定义 | 上报编译器 bug | 否 |
| E4047 | 解引用写类型 | `dereference-assignment type mismatch %s vs %s` | 解引用写两侧类型不符 | 上报编译器 bug | 否 |
| E4048 | 取字段/元素地址根类型 | `invalid root type for field address` / `invalid root type for element address` | 取地址根类型非法 | 上报编译器 bug | 否 |
| E4049 | 释放临时类型 | `freed temp type is not a struct` | 释放的临时非 struct | 上报编译器 bug | 否 |
| E4050 | 返回默认值 | `type cannot be a return default value` | 类型不能生成返回默认值 | 上报编译器 bug | 否 |

> 注：E4001~E4050 连续无跳号；E4000 为本段兜底码（正常不触发）。无括号短文案 `invalid error value element type` 因映射表序在前落 E4003。

---

## 5. 驱动与配置错误（E5xxx，Driver）

**代表性代码示例**：

```zfy
use lib/util.zfy            // ← E5001 use: file not found: lib/util.zfy（文件不存在时）

mod calc
    fn i64 sq(let i64 x)
        return x * x
```

| 错误码 | 触发示例 | 出错原因 | 修复方案 | 自动修复 |
|---|---|---|---|---|
| E5001 | `use lib/util.zfy`（文件不存在）→ `use: file not found: %s` | use 的文件不存在 | 检查路径与文件名（含 .zfy 后缀） | 否 |
| E5002 | 两个文件导出同名函数被同一主文件 use → `import conflict: %s already exists` | 导入名冲突 | 改名，或只 use 其一 | 否 |
| E5003 | mod 内再嵌 mod → `nested modules are not allowed` | 不允许嵌套模块 | 拆平模块结构 | 否 |
| E5004 | clang 退出码非 0 → `link failed (clang exit code %d)`（直输 `zfy:error[E5004] in 0 of <主文件> because (…)`） | 链接失败 | 检查 extern 符号与链接库 | 否 |
| E5005 | 读源文件失败（权限/IO）→ `cannot read source file: %s` | 源文件不可读 | 检查文件权限与路径 | 否 |
| E5006 | CLI 参数错误 → `usage: zfyc <tokens\|ast\|hir\|mir\|llvm\|build> <file.zfy>`（输出 `in 0 of (cli)`，exit 2） | 命令行用法错误 | 按 `zfyc <阶段> <file.zfy>` 传参 | 否 |
| E5007 | use/mod 路径指向私有项 → `'x' is not visible from module m (...)`（v3.2 起含 declare it pub to export 提示） | 目标项未导出 | 给目标项加 pub 声明导出 | 否 |
| E5008 | 文件模块未找到 / use 路径解析失败 → `module file not found: mod x (looked for x.zfy, x/mod.zfy and <parents>/stdlib/x.zfy)`；`unresolved path: 'x' not found (...)` | 模块文件找不到（v3.2 起 stdlib 目录回退：沿父目录链查 `<祖先>/stdlib/名.zfy`，最多 6 级） | 建立 x.zfy 或 x/mod.zfy，或放入 stdlib 搜索路径 | 否 |

> E5001~E5008 连续无跳号（E5007/E5008 为 v3.2 模块系统补录）；E5000 为本段兜底码（正常不触发）。

---

## 6. 兜底码（错误消息未命中映射表时回退，正常不触发）

| 错误码 | 所属段 | 说明 | 自动修复 |
|---|---|---|---|
| E1000 | 词法兜底 | 词法错误消息未命中映射表时回退，正常不触发 | 否 |
| E3000 | 类型语义兜底 | 类型语义错误消息未命中映射表时回退，正常不触发 | 否 |
| E4000 | 代码生成兜底 | 代码生成错误消息未命中映射表时回退，正常不触发 | 否 |
| E5000 | 驱动配置兜底 | 驱动错误消息未命中映射表时回退，正常不触发 | 否 |

---

## 附录 A. 运行期终止（zfy_die / zfy_panic，不入 EXXX 码体系）

程序运行时错误没有源码位置，由 runtime.c 的 `zfy_die`（或 `panic` 的 `zfy_panic`）打印并终止进程，不使用 `zfy:error[EXXX]` 格式。主要类别（38 类）：

- **内存**：`内存分配失败` / `input: 内存分配失败` / `数组: 内存分配失败` / `列表扩长: 内存分配失败` / `数组赋值: 内存分配失败`
  —— malloc/calloc 失败（通常是内存耗尽或请求尺寸异常）。
- **frac**：`frac 除以零` / `frac 加法溢出` / `frac 减法溢出` / `frac 乘法溢出` / `frac 除法溢出` / `frac 运算溢出 <后缀>` / `frac: 小数化整后溢出 i64` / `frac: 分子/分母无法化整（十进制精度超限）`
  —— 分数运算分母为 0，或分子/分母超出存储位宽。
- **下标/切片**：`数组/列表下标不能为负`（负下标不是 Python 式负索引）/ `数组下标越界` / `数组/列表下标越界` / `remove: 数组下标越界` / `remove: 列表下标越界` / `切片区间越界` / `切片步长不能为 0` / `数组/列表长度非法`
  —— 下标越界或切片参数非法；负步长反向切片要求起始不越界、b ≥ 0、a ≥ b，否则报「切片区间越界」。
- **cast**：`cast：无法把 string 解析为整数` / `cast：无法把 string 解析为浮点数` / `prec 长度参数：char 必须是数字字符 '0'-'9'`
  —— 字符串内容与目标类型不符。
- **input**：`input: EOF（无输入可读）` / `input: 无法把输入解析为整数` / `解析为小数` / `解析为布尔值`
  —— 输入流结束，或内容与目标类型不符。
- **运算**：`除以零（浮点/整数除）` / `取模除零` / `浮点不支持取模`
  —— 整数/浮点除零、模零。

如需把运行期终止纳入码体系，请另行约定。

## 附录 B. 多错误恢复行为说明（当前实现）

1. **词法错误**：单错即停（token 流不可靠）。
2. **语法错误**：主文件语句级恢复（跳到下一条语句）与顶层项级恢复（跳到下一个顶层项）；use 子文件错误记录后跳过该文件；恢复后继续类型检查（可能产生"未定义"衍生错误）。
3. **类型错误**：块内逐语句恢复、函数级恢复（跳过整函数）、顶层声明逐项恢复；全部收集。
4. **阶段间提前终止**：主文件 parse 致命错误（AST 不完整）不进类型检查；use 展开 CompileError 不继续；类型有错不进 MIR/LLVM。
5. **MIR/LLVM 阶段**：单错即停（内部兜底，正常不触发）。
6. **输出顺序**：按 主文件语法 → use 子文件 → 类型 源码顺序；编译错误 exit 1（E5006 CLI 用法 exit 2）。

---

## 统计

- 本文档表格行（以 `| E` 开头）合计 **287 行**：错误码表行 **283**（覆盖 errors.md 全部码行，无一省略）+ 兜底码 **4**（E1000 / E3000 / E4000 / E5000）。
- 与 errors.md 头部「**合计 278 码**」的口径对齐：活跃错误码 278 = 283 表行 − 5 个非活跃占位行（E2017 为保留码；E3033、E3126、E3127、E4001 为已删除码，仍列行以便穷举完整）。
- 分段：词法 14（全活跃）/ 语法 36 行（活跃 35）/ 类型语义 175 行（活跃 172，含 v3.1 后补的 E3189/E3190）/ 代码生成 50 行（活跃 49）/ 驱动配置 8（全活跃）。14 + 35 + 172 + 49 + 8 = 278。
- 附录 A 运行期 die 共 38 类，逐条列出（列表形式）。
- 自查命令：`grep -c "^| E" errors_guide.md` → 287（错误码表行 283 + 兜底 4）。



