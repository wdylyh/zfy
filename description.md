# zfy 语言语法说明（description.md）

> 本文与当前编译器实现逐条对齐（2026-10-03 第四次修订，依据 compiler/lib/ 源码与 examples/ 全量用例核对）。共 11 节。保留但未开放的关键字见 §2 与 §9。

## 1. 概述

zfy 是一门编译到 LLVM IR 的静态类型语言，编译器为 OCaml 实现（`zfyc`）。语法特征：

- **缩进块**：代码块用缩进（INDENT/DEDENT）划分，不用 `{}`；语句按行分隔，语句末尾不允许分号（分号仅允许出现在 for 头部）。
- **无 `fn` 关键字**：函数声明直接以返回类型开头，如 `void main()`。
- **声明初值可省略**：标量/数组/列表声明均可写 `= 初值`，也可省略（省略时填类型零值：整数 0、浮点 0.0、bool false、char '\0'、string ""、frac 0/1；列表为空列表）；`const` 必须带初值。
- **顶层可声明变量**：函数定义、use 之外，顶层允许任意标量/数组/列表声明（带或不带初值均可，`const` 除外仍须带初值）。顶层非 const 变量为全局变量（零值初始化，程序启动时先执行全部顶层初始化语句，再进入 main）；顶层 `const` 为编译期常量，使用处内联。
- 注释为 `//` 到行尾。

## 2. 词法

- 注释：`// ...`（行注释）。
- 字面量：整数（`42`）、浮点（`3.99`）、字符串（`"..."`）、字符（`'a'`）、布尔（`true` / `false`）。
- 转义字符（char 与 string 统一）：`\n` `\t` `\\` `\'` `\"`。
- 生效关键字：

  ```
  if else while for return true false break continue
  const frac unreduced reduce and or not output input
  cast array list remove use import as sep end delim
  short long int uint half float double
  ```

- `pub` 与 `mod` 为**保留关键字**：词法层可识别，但当前解析器不接受任何含它们的语法，源码中出现即报错。

## 3. 类型系统

- 标量类型：`bool` `char` `string` `void`（void 仅作返回类型）。
- 数值类型为**多词关键字序列**，解析后规范化为内部宽度名：
  - 整数：`short short` / `short int` / `int` / `long int` / `long long`，后跟 `uint` 后缀表示无符号：`short short uint` / `short int uint` / `int uint` / `long int uint` / `long long uint`（内部 i8..i128 / u8..u128）。
  - 浮点：`half` / `float` / `double` / `long double`（内部 f16..f128），不支持 `uint` 修饰。
- 已删除的旧语法：指针 `*T`、切片/数组类型 `[]T` / `[T;N]`、`int.` / `float.` 等前缀类型——出现即报错。
- 数组/列表在声明处用 `array` / `list` 关键字标注（见第 5 节），不是类型后缀。

## 4. 变量声明

标量声明形式（`const` / `frac` / `unreduced` 修饰符位于类型后、名字前，可任意顺序组合）：

```
<类型> [const] [frac] [unreduced] 名字 [= 初值]
```

- 初值可省略（省略时填类型零值：整数 0、浮点 0.0、bool false、char '\0'、string ""、frac 0/1）。
- `const` **必须带初值**（编译期常量无初值无意义），且不可再赋值；顶层 `const` 为编译期常量，使用处内联，不生成运行时槽。
- `frac` / `unreduced` / `reduce`：见第 10 节。
- 示例：`long int m = 42`、`int x`（x 为 0）、`int const frac pi2 = 22/7`。

## 5. 数组与列表

- 数组：`<元素类型> array 名字[长度] = 元素, 元素, ...`（长度可为 const 变量表达式；初值为逗号分隔，可整体省略，未给出的槽位填零值）。
  示例：`int array n[4] = 1,2`（n[2]、n[3] 为 0）；`int array arr[10]`（全部为 0）。
- 列表：`<元素类型> list 名字 = 元素, 元素, ...`（声明处不写长度；初值可省略，省略时为空列表，之后可用 push 追加）。
  示例：`int list a = 1,2,3`；`int list lst` + `push(lst, x)`。
- `const` 也可位于 `array` / `list` 关键字之后、名字之前（如 `int array const carr[3]`）。
- 下标访问 `a[i]`，下标从 0 起，带边界检查（越界触发运行期 zfy_bounds_fail）。
- `push(列表, 值)`：追加到末尾并自动扩长，无返回值；支持 int / double / string 等元素类型。
- `remove(数组或列表名, 下标)`：按下标删除。
- `length(x)`：string / 数组 / 列表通用，返回 i64。
- 列表整体赋值/传参为**深拷贝**；切片等临时序列赋给变量时所有权转移，免克隆。

## 6. 表达式与运算符

- 算术：`+ - * / %`；比较：`== != < > <= >=`；逻辑：`and` `or` `not`（`and` / `or` 短路求值）。
- 复合赋值：`+= -= *= /= %=`；自增自减仅后缀：`x++` / `x--`。
- 下标 `a[i]`；切片 `s[a, b]` / `s[a, b:step]`（**两端含**，step 用冒号，可省略）。
- 强制转换：`cast(e, T)`——显式转换语法。**目标驱动自动转换**：赋值、传参、return 时若目标类型宽度明确，整数↔整数（跨宽度/含窄化）自动隐式完成（窄化向零截断，同 C 语义），如 `int n = length(s)`、`long int big = 100; int small = big` 均无需 cast；其余场景（浮点↔整数、无目标的混算等）仍须显式 `cast`。
- 命名实参：位置参数在前，命名参数在后，如 `find(s, 'l', count=k)`、`output(x, sep=',')`。

## 7. 语句与控制流

- 赋值：`x = e`；语句逐行书写，语句末尾不允许分号。
- `if 条件` / `if 条件 ... else ...` / `else if` 链（条件不加括号；块用缩进，`if cond` 同行跟单条语句也合法）。
- `while 条件`。
- `for 项, 项, ...`：**逗号化多段头部**，编译器按形状分类——声明（类型开头）→ 初始化；比较/布尔表达式 → 条件（多项用 `and` 连接，无条件恒真）；赋值/复合赋值/自增自减 → 更新。
  示例：`for i, j, i < 5 and j > 0, i--, j += i`。
  头部声明也可带 `const`/`frac`（同样必须带初值）。
  **循环变量作用域**：for 头部声明的变量作用域延伸到 for 所在的整个块（循环结束后仍可读，值为最后一次迭代后的值）。
- `break` / `continue`；`return`（可带值，也可裸写 `return`）。

## 8. 函数

- **直接以返回类型开头**，无 `fn` 关键字：`<返回类型> [frac] 名字(参数, ...)`，函数体为缩进块。
- 参数形式（逗号分隔）：
  - 标量：`类型 [frac] 名字`（frac 修饰表示分数参数）。
  - 数组：`类型 array 名字[长度]`——长度为整数字面量，或**之前声明的参数名**（长度运行期由该实参决定）；调用时定长实参长度须与字面量一致，长度为参数名的形式接受任意同元素类型数组。
  - 列表：`类型 list 名字`。
  - 不支持 `const` / `unreduced` 修饰。
- 返回值类型必写（无返回值写 `void`）；返回类型带 `frac` 修饰表示返回分数（如 `int frac half_of(int frac x)` 风格：`<宽度> frac 名字(...)`）。
- **所有数组/列表/frac/string 参数与返回均为值语义（深拷贝）**：函数内修改不影响调用方；string 参数/返回自动 strdup，数组/列表参数/返回自动整体克隆，frac 聚合按值传递。
- 函数名即入口，调用为 `名(实参)`；跨文件调用经 use 命名空间（见第 9 节）。
- 字符串返回走 RAII：提前 `return` 转移所有权不重复释放；字面量返回自动 strdup 副本。

## 9. 模块化（use）

- `use 文件名.zfy [import 模块名] [as 别名]`：引入其他 .zfy 文件；路径支持相对形式 `./` 与 `../`（如 `use ../lib/math.zfy as m`）；文件名必须带 `.zfy` 后缀。
- `as 别名` 把别名绑定给文件（命名空间），调用 `别名.函数(...)`。
- 示例（examples/use_test）：`use mathlib.zfy as m` 后调用 `m.add(1, 2)`。
- `pub` / `mod` 为保留关键字，当前语法**未开放**（见 §2）。

## 10. 分数（frac）与 reduce

- `<宽度> frac x = a/b`：分数类型，分子分母可为小数（乘 10^n 化整后按分数规则运算）。
- 初值（含声明、赋值）**自动约分到最简**；运算结果（加减乘除、标量提升）同样自动约分。
- `reduce(x, 次数, 起始除数)`：手动约分。
- `unreduced`：抑制相关约分行为。
- 比较运算按分数值进行；`int frac a = 1/2` 的 `1/2` 是分数字面量，不是整数除法。

## 11. I/O 与字符串内建

- `output(e1, e2, ..., sep=?, end=?)`：依次输出各表达式；`sep` 默认空格，`end` 默认换行，二者为 char/string（或可转 string 的表达式）；命名参数必须放在最后，且各只允许出现一次。
- `input(目标..., delim=?)`：读入到目标；目标可为**新声明**（`int x`）或已有变量（`x`），支持多个目标；`delim` 为 char/string 表达式且必须是最后一个参数，默认"换行和空格"字符集。
- 函数式字符串内建（位置参数在前，命名参数在后）：
  - `length(s)`：字符串/数组/列表长度（i64）。
  - `find(s, c[, count=k])`：找字符第 k（默认 1）次出现，找不到返回 -1；count 必须 > 0。
  - `trim(s, x)`：去除指定字符（x 为 char 或 string）。
  - `split(s, x)`：按分隔符切分（x 为 char 或 string），返回 `string` 列表（一等值：可赋给变量、`length` 计数、下标访问、作为参数传递、遍历）。
  - `replace(s, a, b, rep)`：把下标 a..b（两端含）替换为 rep；`replace(s, a, rep)` 从 a 起替换到串尾。
  - `prec(v, n)`：输出宽度控制（总字符数），返回 string；string 截断/补空格，其他可打印类型先按输出格式转 string。
- `push` / `remove` 见第 5 节。
