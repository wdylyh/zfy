# zfy 错误码穷举文档（最终码版）

> 定稿于 2026-10-04。依据编译器代码（compiler/lib/*）逐调用点穷举，错误码与 driver.ml `code_of` 映射表一一对应；所有错误消息为英文（编译器实际输出原文，`%s/%d/%Ld` 为运行时填充）。
>
> **码位规则**（用户指定）：`E` + 体系位 + 3 位序号（不足 3 位前补零）。体系位：1 词法 / 2 语法 / 3 类型语义 / 4 代码生成（MIR+LLVM）/ 5 驱动配置。例：E500-01 → E5001、E300-84 → E3084（84 补零为 084）、E300-135 → E3135（三位序号直接拼）。
>
> **输出格式**：`zfy:error[EXNNN] in <行> of <文件> because (<文案>)` + 5 行源码上下文 + 等长 `^` 列对齐；exit 码 1（E5006 CLI 用法为 exit 2）。
>
> **跳号说明**：号段不连续是条目合并的结果（同一错误多处触发 / 同文案合并同码），各节末尾列出。已删除两条占位交叉引用：E300-112（main 返回类型检查实际由 LLVM 阶段报，归 E4012）、E300-143（TErr 元素非法由 E4002 承担）。
>
> 统计：词法 14 码 / 语法 35 码 / 类型语义 139 码 / 代码生成 50 码 / 驱动配置 6 码，**合计 244 码**；另有 4 个兜底码（E1000 / E3000 / E4000 / E5000，错误消息未命中映射表时回退，正常不触发）。运行期 die（不入 EXXX 码体系，附录 A）38 类。

格式说明：
- 「触发」列给最小触发示例（`…` 表示任意合法代码）；「文案」列为编译器当前输出原文。
- 标注 **[多错误恢复]** 的阶段支持错误收集后继续（词法单错即停；语法按语句/顶层项恢复；类型按语句/函数/顶层项恢复）。
- 标注 **[内部兜底]** 的为代码生成阶段一致性检查，正常程序不会触发（前端已拦截），列出仅为穷举完整。

---

## 1. 词法错误（E1xxx，Lexer，单错即停）

### 1x1 字符串/字符字面量

| 码 | 触发示例 | 文案 |
|---|---|---|
| E1001 | `string s = "abc`（缺右引号） | unterminated string literal |
| E1002 | `output("a\`（反斜杠后接字符串结尾；字符字面量同） | dangling escape character |
| E1003 | `output("a\qb")`（\q 不存在；字符字面量同） | unknown escape sequence \q |
| E1004 | 字符串内直接回车换行 | raw newline in string literal |
| E1005 | `char c = 'a`（缺右引号） | unterminated character literal |
| E1008 | `char c = 'ab`（缺 `'` 结尾） | character literal must end with ' |

### 1x2 数字字面量

| 码 | 触发示例 | 文案 |
|---|---|---|
| E1009 | `i32 a = 0x`（0x 后无数位） | numeric literal has no digits |
| E1010 | `f64 a = 1.`（浮点格式非法） | invalid float literal |
| E1011 | `i64 a = 0xFFFFFFFFFFFFFFFF`（超 i64） | hex literal overflows i64 |
| E1012 | `i64 a = 0b111...1`（超 64 位） | binary literal overflows i64 |
| E1013 | `i64 a = 99999999999999999999` | integer literal overflows i64 |

### 1x3 注释 / 缩进 / 字符

| 码 | 触发示例 | 文案 |
|---|---|---|
| E1014 | `/* 未闭合` | unterminated block comment |
| E1015 | 同一语句内缩进比上一行多且不成块（Dedent 时不匹配栈顶） | inconsistent indentation: expected %d, got %d |
| E1016 | 源码出现 `#`、`` ` ``、`$` 等无 token 含义字符 | illegal character '%c' (0x%02X) |

> 跳号：E1006/E1007（占位：字符字面量场景的悬空转义/未知转义）并入 E1002/E1003——两场景文案相同。

---

## 2. 语法错误（E2xxx，Parser，语句/顶层级恢复 [多错误恢复]）

### 2x1 期望类（token 缺失/多余）

| 码 | 触发示例 | 文案 |
|---|---|---|
| E2001 | `a = `（赋值右侧缺表达式）、`output(1`（缺右括号）、`f(1,`（参数表缺项）、`i32 a = b[`（下标缺表达式） | expected an expression, got %s |
| E2003 | `int`（单独类型词作语句） | declaration syntax: TYPE (const)? (frac)? NAME [= init] (e.g. %s x = 1 / …) |
| E2005 | `struct P`（缺缩进字段块）；顶层出现孤立 `else` 等 | expected a top-level item (function/use/declaration), got %s |
| E2006 | `int 1x = 2`（名字非标识符） | expected %s (identifier), got %s |
| E2007 | `if a then`（期望关键字处给错 token） | expected %s (%s), got %s |
| E2008 | `cast(1, 2)`（cast 第二参须类型） | expected a type, got %s |

### 2x2 声明形状

| 码 | 触发示例 | 文案 |
|---|---|---|
| E2010 | `int int d = 1` 或 `i32 int x`；`long long`（long 与 long 混写） | duplicate base type: a declaration has exactly one base type (alias and width names cannot be mixed) |
| E2012 | `const k`（const 无初值） | const requires an initializer |
| E2013 | `int frac a[] = 1/2`（列表带 frac） | lists do not support the frac modifier |
| E2014 | `int frac a[3] = 1`（数组带 frac） | arrays do not support the frac modifier |
| E2015 | `i32 frac f(int frac a[3])`（参数带 frac 的数组） | array/list parameters do not support the frac modifier |

### 2x3 已删除/受限语法

| 码 | 触发示例 | 文案 |
|---|---|---|
| E2017 | `a.b = 1`（非 use 命名空间的点访问） | dot syntax removed: '.' is only for use-namespace access (e.g. t.item) |
| E2018 | `array int a` / `list f64 b` | 'array'/'list' keywords removed: arrays are written T a[N], lists T a[] |
| E2019 | `* p = 1`（星号在声明开头） | '*' must follow a type to form a pointer (syntax T*, e.g. i32* p) |
| E2020 | `[i32; 4] x`（旧切片类型写法） | '[]T' / '[T;N]' (slice/array type) syntax removed |
| E2021 | `panic()`（无消息参数） | panic requires a message argument: panic(msg) or panic(code, msg) |

### 2x4 output / struct / use / extern

| 码 | 触发示例 | 文案 |
|---|---|---|
| E2022 | `output(1, sep=',' , sep='|')` | duplicate sep parameter in output |
| E2023 | `output(1, end='\n', end='')` | duplicate end parameter in output |
| E2024 | struct 字段写 `x = 1`（缺类型） | struct field syntax: TYPE NAME [= default] |
| E2025 | `use myfile`（缺 .zfy） | use file name must end with .zfy |
| E2031 | `extern "Sys" f()`（链接名非 "C"） | extern supports only "C", got "%s" / expected "C" after extern |

### 2x5 括号/逗号/语句形状（本轮补录）

| 码 | 触发示例 | 文案 |
|---|---|---|
| E2027 | 语句中出现孤立分号（非 for 头部） | semicolon is only allowed in for headers |
| E2028 | `i32 const f(i32 x)`（参数用 const） | parameters do not support const |
| E2029 | 参数用 unred 修饰 | parameters do not support unred |
| E2030 | struct 字段 `i32 a[3] = …`（数组/列表字段带默认值） | array/list struct fields cannot have default values |
| E2032 | `i32 f(int a int b`（参数类型表未闭合） | expected ',' or ')' to end the parameter type list |
| E2033 | `a[1 2]`（下标/切片列表未闭合） | expected ',' or ']' |
| E2034 | `f(1; 2)`（实参间用分号） | ';' is not allowed between call arguments; use ',' |
| E2035 | `f(1 2)`（调用实参表未闭合） | expected ',' or ')' to end the argument list |
| E2036 | `panic(1 2)`（panic 实参表未闭合） | expected ',' or ')' to end the panic arguments |
| E2037 | 块未关闭直到 EOF | unexpected end of input (unclosed block) |
| E2038 | `output(1, sep=',', 2)`（命名参数不居末） | named output parameters (sep/end) must come last |
| E2039 | `output(1 2)`（output 实参表未闭合） | expected ',' or ')' to end the output argument list |
| E2040 | `input(x, delim=',', y)`（delim 不居末） | input's delim parameter must come last |
| E2041 | `input(x 2)`（input 目标表未闭合） | expected ',' or ')' to end the input target list |

> 跳号：E2002/E2004/E2009（占位）并入 E2001（同文案"期望表达式"）、E2011 删除（别名映射变更：long=i128 / ulong=u128 为独立类型，long int/long long/ulong int/ulong long 废止——long 后跟类型词报 E2010）、E2016 并入 E2003（声明语法提示）、E2026 并入 E2005（顶层项期望）。

---

## 3. 类型/语义错误（E3xxx，Typeck，语句/函数/顶层项级恢复 [多错误恢复]）

### 3x1 类型解析

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3001 | `foo x = 1`（foo 非类型）；`type T = T2`（T2 未定义）；`f(T3 x)`（参数类型未定义）；`P(1)`（P 未定义） | undefined type: %s |
| E3004 | 类型推断出现循环约束 | circular type inference constraint |

### 3x2 类型不匹配/转换/初始化

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3005 | `i32 b = "str"`；`f(g())`（实参类型不符） | type mismatch: expected %s, got %s (numeric conversion requires an explicit cast) |
| E3007 | `output(some_int as string)`（无 cast 转 string） | type %s cannot convert to string |
| E3008 | `cast(p, i32)`（指针转整数等非法转换） | unsupported cast: %s -> %s |
| E3009 | `i32* p`（无初值的不可省略类型） | type %s cannot omit an initializer |
| E3010 | `i32 x = f()!`（T! 直接当 T 用） | fallible value used directly as a plain value (unwrap with ?? or propagate with ?): got %s, expected %s |

### 3x3 变量/常量/赋值

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3011 | `output(a)`（a 未声明）；`a = 1`；`1.field = 2`（左值未定义）；move 后再使用之外的未定义引用 | undefined variable: %s |
| E3013 | move 后再使用：`string s2 = move s` 后 `output(s)` | variable %s has been moved and cannot be used (reassign to revive it) |
| E3014 | `const k = 1` 后 `k = 2` | cannot assign to constant %s (declared const) |
| E3015 | `const arr[3] = 1,2,3` 后 `arr[0] = 9` | cannot modify elements of constant %s |
| E3016 | move 后写入：`move f(arr)` 后 `arr[0] = 1` | array %s has been moved and cannot be written |
| E3017 | `s[0] = 'x'`（string 下标写） | strings do not support index assignment (use replace for ranges) |
| E3018 | `s[0,2] += "a"` | string slices do not support augmented assignment |
| E3019 | `fr[0,2] += 1`（frac 切片） | frac slices do not support augmented assignment |
| E3020 | `h[0,2] += 1.0`（half/quad 切片） | f16/f128 slices do not support augmented assignment |
| E3021 | `p += 1`（unsafe 内指针复合赋值） | pointers do not support augmented assignment/inc/dec (arithmetic only as p = p + n inside unsafe) |
| E3022 | `a[1,2] += 1`（a 非 seq） | augmented assignment target does not support indexing: %s |
| E3023 | `a[0,2] += 1`（a 非 seq，切片形式） | augmented assignment target does not support slicing: %s |
| E3024 | `*p += 1`（非数值/指针） | dereferenced augmented assignment supports only numeric/pointer types, got %s |
| E3025 | `*x = 1`（x 非指针，复合/自增自减） | augmented/inc/dec target must be a pointer dereference, got %s |
| E3026 | `1 = 2` | augmented/inc/dec target must be a variable or array/list element |
| E3027 | const struct 后 `pl.name = "x"` | cannot assign to field of constant %s (const is deeply immutable) |
| E3028 | struct 复合赋值非标量字段 `pl.pos += 1` | struct field augmented assignment supports only numeric scalar fields, got %s |
| E3029 | `1.field = 2`（类型不支持字段赋值） | type %s does not support field assignment %s |
| E3031 | `*p = "s"`（写非标量） | dereference assignment supports only scalar/pointer types (for now), got %s |
| E3032 | `a[0] = p`（写 struct 等聚合） | type %s does not support index assignment |
| E3033 | `f(1)[0] = 2`（调用结果下标写） | index-assignment target must be an array/list variable, e.g. n[3] = value |
| E3034 | `*x = 1`（x 非指针，普通赋值） | assignment target must be a pointer dereference, got %s |
| E3035 | 无法解析的赋值目标 | unsupported assignment target |
| E3036 | `move 5` 或 `move f()` | cannot move constant %s |
| E3037 | `move g`（全局变量） | cannot move global variable %s |
| E3038 | `string s2 = move s` 两次 | variable %s has already been moved |
| E3039 | `move i`（i 是 int） | move supports only string/array/list arguments, %s has type %s |
| E3040 | 顶层 `const frac r = 1/2` | top-level const does not support frac/unred |
| E3041 | 顶层 `const k = 1` 两次 | duplicate top-level constant: %s |
| E3042 | 顶层 `const d = 1.5` | top-level const currently supports only integer types, got %s |
| E3043 | 顶层 `int g = 1` 两次；顶层变量与函数同名后再声明 | duplicate top-level variable: %s |

### 3x4 运算符

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3045 | `1 + "a"`（两侧异型）；`s += "a"`（s 为 int） | string concatenation requires both sides to be string, got %s and %s（单参形态 got %s） |
| E3047 | unsafe 外 `p + 1`、`p - 1`、`p - q` | pointer arithmetic is only allowed inside an unsafe block |
| E3048 | unsafe 内 `p1 + p2` | cannot add two pointers |
| E3049 | unsafe 内 `1.5 + p`（整数不能与指针相加） | cannot add an integer to a pointer |
| E3052 | unsafe 内 `1 - p` | cannot subtract a pointer from an integer |
| E3053 | `p < 1` | pointer comparison requires both sides to be pointers or null, got %s and %s |
| E3054 | `p * 2` | unsupported pointer operation: %s (only + - inside unsafe and == !=) |
| E3055 | `"a" < 1` | comparison requires numeric types, got %s and %s |
| E3056 | `true + 1` | arithmetic requires numeric types, got %s and %s |
| E3057 | `-true` | unary minus requires a numeric type, got %s |

### 3x5 内建操作（output/input/length/find/prec/sizeof/push/函数指针）

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3058 | `panic_handler(1)` | panic_handler expects a function name argument: panic_handler(fn) |
| E3059 | `panic_handler(fn)`（fn 签名不符） | panic_handler signature must be (i32, string) -> void, got (%s) -> %s |
| E3061 | `push(a, 1)`（a 是数组） | push target must be a list, got %s |
| E3062 | `push(1)` | push takes two arguments: push(list, value) |
| E3063 | `sizeof(1)` | sizeof/alignof does not support type %s |
| E3064 | `sizeof(3+1)` | %s expects a type name argument, e.g. %s(Point) |
| E3065 | `fp(1, 2)`（fp 期望 1 参） | function pointer expects %d arguments, got %d |
| E3066 | `fp(move s)` | function pointer calls do not support move arguments |
| E3067 | `fp(x=1)` | function pointer calls do not support named argument %s= |
| E3068 | `f(x=1)`（普通函数命名实参） | function calls do not support named argument %s= |
| E3069 | `(a + b)(1)` | unsupported callee expression |
| E3070 | `1[0]` | type %s does not support index access |
| E3071 | `1[0,1]` | slicing is only for string/array/list, got %s |
| E3072 | `&f()`（取临时地址） | '&' can only take the address of a variable/field/element |
| E3073 | `&f()`（f 返回 void） | cannot take the address of a void value |
| E3074 | `*1` | dereference requires a pointer type, got %s |
| E3075 | `a[1.5]` | an integer type is required, got %s |
| E3076 | `replace(1, 0, "x")`（目标参数须 string） | %s expects a string for its %s parameter, got %s |
| E3077 | `trim(1, 'a')`（参数类型不符） | %s does not accept type %s for its %s parameter |
| E3078 | `length(1)` | length expects string/array/list, got %s |
| E3079 | `find("a", 'a', count=0)` | find's count must be > 0, got %Ld |
| E3080 | `prec(true, 2)` | prec does not support type %s |
| E3081 | `prec("a", 1.5)` | prec's length parameter must be integer/char/float, got %s |
| E3082 | `split(s, sep='a', x=1)` | malformed argument list for builtin %s (positional arguments must precede named ones) |
| E3083 | `replace(1, 'x')`（旧字符参数须 char） | a char is required (%s), got %s |
| E3084 | `input(struct_target)` | input target must be string/integer/float/bool/char, got %s |
| E3085 | `output(Point(1,2))`（struct 直接输出） | output does not support argument type: %s |
| E3086 | `input(x, delim=1)` | input's delim must be char or string, got %s |

### 3x6 struct

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3087 | `p.z`（无字段 z） | struct %s has no field %s |
| E3088 | `1.x` | type %s has no field %s (dot access is only for structs) |
| E3089 | `p.x`（p 非 struct） | type %s does not support field access %s |
| E3091 | `P(move s)` | struct constructor does not support move arguments |
| E3092 | `P(1,2,3)`（只有 2 字段） | struct %s has %d fields, got %d positional arguments |
| E3093 | `P(x=1, x=2)` | field %s initialized twice |
| E3094 | 顶层 `struct Point` 两次 | duplicate struct definition: %s |
| E3095 | `struct length`（内建名） | struct name %s conflicts with a builtin, rename it |
| E3096 | `struct f`（f 已是函数） | %s is already a function and cannot also be a struct name |
| E3097 | 字段 `i32 a[n]`（n 非字面量） | struct field array length must be a compile-time literal |
| E3098 | `struct S` 内含 `S s` | struct %s field type cannot be itself (infinite size) |
| E3099 | `struct S` 内含 `i32! x` | T! cannot be a struct field (error values are aggregates and cannot be loaded as a field) |
| E3100 | `struct S` 两个 `i32 x` | struct %s has duplicate field %s |

### 3x7 函数/调用/extern

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3101 | `f(1)`（f 未定义）；`panic_handler(g)`（g 未定义） | undefined function: %s |
| E3102 | `f(1, 2)`（f 期望 1 参） | function %s expects %d arguments, got %d |
| E3103 | `type T = ...` 与已有类型/函数冲突 | type alias %s conflicts with an existing type/function |
| E3104 | `i32 length()` | function name %s conflicts with a builtin, rename it |
| E3105 | `i32 f()` 两次 | duplicate function definition: %s |
| E3106 | extern "C" 与 zfy 函数同名 | duplicate function definition: %s (extern conflicts with an existing function) |
| E3107 | `extern "C" length()` | extern function name %s conflicts with a builtin |
| E3108 | `extern "C" f(i32 a[3])` | extern parameters do not support arrays/lists |
| E3109 | `extern "C" f(i32! x)` | extern parameters do not support T! |
| E3110 | `extern "C" i32! g()` | extern functions do not support a T! return type (the error model is for zfy functions only) |
| E3111 | `i32 f()` 内无 return | function %s declares return type %s but may not return a value |

> 占位 E300-112（`int main()` 返回类型受限）已删除：该检查实际由 LLVM 阶段报，归 **E4012**。

### 3x8 frac

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3113 | `half frac x = 1/2`（f16 frac） | frac does not support element type %s (supported: i8..i128 / u8..u128 / f32 / f64 / f128) |
| E3114 | `i32 frac a = 1/2` 与 `i64 frac b` 运算；`i32 frac a = i64_frac_变量`（初始化元素类型不符，无占位形态） | mismatched frac element types: %s vs %s / mismatched frac element types |
| E3115 | `fr + 1`（frac 与标量）；`1 + fr` | %s cannot be mixed with %s in this operation |
| E3117 | `fr % 2` | frac does not support modulo |
| E3118 | `i32 frac a = "x"`（右值既非分数也非数值标量；int/uint/float 标量自动提升为分数，不触发） | cannot initialize %s as frac |
| E3119 | `frac arr[]` | frac arrays/lists are not yet supported |
| E3120 | `i32 frac f(i32 frac a)`（参数元素类型不符时） | frac parameter does not support element type %s |
| E3121 | `half frac f()`（返回类型不符） | frac return type does not support element type %s |
| E3122 | `const fr` 后 `reduce(fr, 2, 2)` | cannot reduce constant %s |
| E3123 | `reduce(x, 2, 2)`（x 非 frac） | reduce requires a frac-typed variable, got %s |
| E3124 | `reduce(1, 2, 2)` | reduce's first argument must be a frac-typed local variable |
| E3125 | `i32 frac x = f() ?? 缩进块` | frac/unred does not support ??-block initialization |

### 3x9 数组/列表声明

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3126 | `Point ps[3]` | struct is not yet supported as an array/list element |
| E3127 | `i32! xs[]` | T! cannot be an array/list element (error values are aggregates and cannot be loaded by index) |
| E3128 | `i32 a["n"]` | array length must be an integer, got %s |
| E3129 | `i32 a[x]`（x 非 const） | array length must be a compile-time constant (a literal or const integer variable) |
| E3130 | `i32 a[3]`（列表写法带了长度） | lists take no length |
| E3131 | `i32 a[]`（数组写法缺长度） | arrays require a length |
| E3132 | `i32 a[2] = 1,2,3` | %d initial values exceed array length %Ld |
| E3133 | `f(n, b[m])`（m 非前参）；`f(b[x])`（x 为表达式） | array parameter length must be a literal or a previously declared parameter（带 `: %s` 与不带两形态） |

### 3xA 错误值 T! / ? / ?? / err

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3135 | `ErrCode.Nope` | undefined error code: ErrCode.%s |
| E3136 | `1 ?? 2`（左侧非 T!） | left side of ?? must be a fallible value (T!), got %s |
| E3137 | `i32 x = a ?? 缩进块`（类型不符时） | ??-block declaration type must be the element type T (without '!') |
| E3138 | `a ?? 缩进块`（独立语句） | ??-block form (a ?? indented block) is only allowed as the RHS of a declaration or assignment |
| E3139 | `x = a ?? 缩进块`（目标非变量） | ??-block assignment target must be a variable (for now) |
| E3140 | `a?`（a 非 T!） | ? left side must be a fallible value (T!), got %s |
| E3141 | `a?`（在 void 函数内） | ? propagation requires the enclosing function to return T! (current: void) |
| E3142 | `a?`（返回类型不匹配） | ? propagation requires the enclosing function to return %s! (current: %s) |

### 3xB 补录（本轮重写时补充单列）

| 码 | 触发示例 | 文案 |
|---|---|---|
| E3144 | `i32[2]` 形状与 `i32[3]` 形状参与运算 | array lengths differ: %d vs %d |
| E3145 | `push(move s, …)` 等内建带 move 实参 | builtin %s does not support move arguments |
| E3146 | `bool b = "x"` | bool can only be initialized with true/false, 0/1, or a boolean expression |
| E3147 | `remove(1, 0)`（目标非数组/列表） | remove only works on arrays/lists, got %s / remove's first argument must be an array/list variable |
| E3148 | 程序无 `main()` | missing main() |
| E3149 | 块表达式出现在不支持的位置 | block expressions are not supported here |
| E3150 | move 的对象不是简单局部变量 | move can only apply to a local variable |
| E3151 | `const s = ""` 后 `input(s)` | cannot input into constant %s |
| E3152 | move 后 remove：`move f(arr)` 后 `remove(arr, 0)` | array %s has been moved and cannot be removed from |
| E3153 | `const arr` 后 `remove(arr, 0)` | cannot remove from constant %s |
| E3154 | struct A 内含 B、B 内含 A（循环嵌套） | struct %s has circular nesting (infinite size) |
| E3155 | 窄化转换未加显式 cast（new2.md #5：宽化自动，窄化显式） | narrowing conversion from %s to %s requires an explicit cast |

> 跳号（类型段）：E3002/E3003 并入 E3001、E3006 并入 E3005、E3012 并入 E3011、E3030 并入 E3011、E3044 并入 E3043、E3046 并入 E3045、E3050/E3051 并入 E3047、E3060 并入 E3101、E3090 并入 E3001、E3112 删除（归 E4012）、E3116 并入 E3115、E3134 并入 E3133、E3143 删除（TErr 元素非法归 E4002）。

---

## 4. 代码生成错误（E4xxx，Mir/Mir.ml 与 LLVM/Llvmgen.ml）

### 4x1 语义兜底（Mir 降码期，可由用户代码触发 [内部兜底]）

| 码 | 触发示例 | 文案 |
|---|---|---|
| E4001 | `push(1, 2)`（漏过前端的极端形状） | push target must be a list variable |
| E4002 | `f()!`（TErr 元素为 f128 等 128 位类型） | error value element type does not support 128-bit width (T! is limited to <=64-bit scalars/string/pointers) |
| E4003 | TErr 元素为聚合 | invalid error value element type (scalar/string/pointer only)（无括号短形态同码） |
| E4004 | — | unsupported frac operation |
| E4005 | `1.x = 2`（字段目标） | unsupported field-access target |
| E4006 | `&1` | unsupported address-of target |
| E4007 | `&a[i]`（a 非 seq） | element address-of target must be a variable |
| E4008 | `x = y`（槽写入目标） | unsupported assignment target |
| E4009 | `reduce(1,2,2)` | reduce target must be a frac-typed local variable |
| E4010 | `break`（循环外） | break outside a loop |
| E4011 | `continue`（循环外） | continue outside a loop |
| E4012 | `int main()`（返回类型受限，占位 E300-112 并入此处） | main's return type must be void or i64, got %s |

### 4x2 内部一致性兜底（Llvmgen，正常不可触发——前端已拦截）

| 码 | 触发场景 | 文案 |
|---|---|---|
| E4013 | 非法浮点宽度 | unsupported float width f%d |
| E4014 | TVar 未求解 | unresolved type variable |
| E4015 | 类型大小未知 / struct 未登记 | undefined struct %s / cannot determine type size |
| E4016 | seq 元素非法 | unsupported array/list element type |
| E4017 | 指针常量非 null | pointer constant must be null |
| E4018 | 聚合值当标量 | aggregate value %s must be used as a pointer |
| E4019 | 局部变量未登记 | undefined local variable %s / undefined variable %s |
| E4020 | 元素类型非法 | type cannot be stored as an array/list element |
| E4021 | 期望聚合 | expected aggregate local: %s (oty=%s) |
| E4022 | 聚合算术 | aggregate type does not support arithmetic |
| E4023 | 指针运算超限 | unsupported pointer operation |
| E4024 | 浮点取模 | float type does not support modulo |
| E4025 | 布尔运算超限 | bool type does not support this operation |
| E4026 | 聚合一元 | aggregate type does not support unary operations |
| E4027 | 转 string 超限 | type cannot convert to string |
| E4028 | 聚合 cast | aggregate type does not support cast |
| E4029 | 转换超限 | unsupported conversion %s -> %s |
| E4030 | output 类型超限 | output does not support this argument type |
| E4031 | input 目标超限 | input does not support this target type / input does not support this error-value element type |
| E4032 | prec 长度参数 | invalid prec length parameter type |
| E4033 | 聚合返回未接收 | aggregate return value must be captured / aggregate return value must be captured into a variable |
| E4034 | 非 void 返回未使用 | non-void return value must be used |
| E4035 | 字段访问目标 | field access target is not a struct / invalid root type for field access |
| E4036 | 字段序号 | struct %s has no field index %d |
| E4037 | 槽位类型不一致 | slot type %s does not match value type %s |
| E4038 | move 槽类型 | invalid move target slot type %s |
| E4039 | fail code | fail's code must be i32 |
| E4040 | MErrOk/MErrValue 类型 | MErrOk type error: %s / MErrValue type error |
| E4041 | panic code | panic's code must be i32 |
| E4042 | MNorm/reduce 类型 | norm type error / reduce type error |
| E4043 | 切片复合赋值 | unsupported augmented-assignment operation on slices / unsupported element type for slice augmented assignment |
| E4044 | 未定义的临时 | undefined temp %s |
| E4045 | MEmptySeq 类型 | MEmptySeq type is not an array/list |
| E4046 | 取地址目标 | address-of target is undefined: %s |
| E4047 | 解引用写类型 | dereference-assignment type mismatch %s vs %s |
| E4048 | 取字段/元素地址根类型 | invalid root type for field address / invalid root type for element address |
| E4049 | 释放临时类型 | freed temp type is not a struct |
| E4050 | 返回默认值 | type cannot be a return default value |

> 注：E4015 的 "undefined struct %s" 在类型大小计算与字段访问两处触发（同码）；E4036 行原占位含 "未定义的 struct P" 形态，现该形态归 E4015；无括号短文案 "invalid error value element type" 因映射表序在前落 E4003。E4001~E4050 连续无跳号；E4000 为本段兜底码（正常不触发）。

---

## 5. 驱动与配置错误（E5xxx，Driver）

| 码 | 触发示例 | 文案 |
|---|---|---|
| E5001 | `use lib/util.zfy`（文件不存在） | use: file not found: %s |
| E5002 | 两个文件导出同名函数被同一主文件 use | import conflict: %s already exists |
| E5003 | mod 内再嵌 mod | nested modules are not allowed |
| E5004 | clang 退出码非 0 | link failed (clang exit code %d)（直输 `zfy:error[E5004] in 0 of <主文件> because (…)`） |
| E5005 | 读源文件失败（权限/IO） | cannot read source file: %s |
| E5006 | CLI 参数错误 | usage: zfyc <tokens\|ast\|hir\|mir\|llvm\|build> <file.zfy>（输出 `in 0 of (cli)`，exit 2） |

> E5001~E5006 连续无跳号；E5000 为本段兜底码（正常不触发）。

---

## 附录 A. 运行期终止（zfy_die / zfy_panic，不入 EXXX 码体系）

程序运行时错误没有源码位置，由 runtime.c 的 `zfy_die`（或 `panic` 的 `zfy_panic`）打印并终止进程，不使用 `zfy:error[EXXX]` 格式。如需纳入码体系请另行约定。主要类别：

- 内存：内存分配失败 / input: 内存分配失败 / 数组: 内存分配失败 / 列表扩长: 内存分配失败 / 数组赋值: 内存分配失败
- frac：frac 除以零 / frac 加法溢出 / frac 减法溢出 / frac 乘法溢出 / frac 除法溢出 / frac 运算溢出 <后缀> / frac: 小数化整后溢出 i64 / frac: 分子/分母无法化整（十进制精度超限）
- 下标/切片：数组/列表下标不能为负 / 数组下标越界 / 数组/列表下标越界 / remove: 数组下标越界 / remove: 列表下标越界 / 切片区间越界 / 切片步长必须 >= 1 / 数组/列表长度非法
- cast：cast：无法把 string 解析为整数 / cast：无法把 string 解析为浮点数 / prec 长度参数：char 必须是数字字符 '0'-'9'
- input：input: EOF（无输入可读）/ input: 无法把输入解析为整数 / 解析为小数 / 解析为布尔值
- 运算：除以零（浮点/整数除）/ 取模除零 / 浮点不支持取模

## 附录 B. 多错误恢复行为说明（当前实现）

1. 词法错误：单错即停（token 流不可靠）。
2. 语法错误：主文件语句级恢复（跳到下一条语句）与顶层项级恢复（跳到下一个顶层项）；use 子文件错误记录后跳过该文件；恢复后继续类型检查（可能产生"未定义"衍生错误）。
3. 类型错误：块内逐语句恢复、函数级恢复（跳过整函数）、顶层声明逐项恢复；全部收集。
4. 阶段间提前终止：主文件 parse 致命错误（AST 不完整）不进类型检查；use 展开 CompileError 不继续；类型有错不进 MIR/LLVM。
5. MIR/LLVM 阶段：单错即停（内部兜底，正常不触发）。
6. 输出顺序：按 主文件语法 → use 子文件 → 类型 源码顺序；编译错误 exit 1（E5006 CLI 用法 exit 2）。
