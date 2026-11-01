# zfy 语言功能差距分析（对照主流语言）

> **状态更新（2026-10-23，v3.13.0）**：**P1 主体清空**——
> #6 for-in 遍历（v3.6 + v3.10 带下标）、#7 容器算法（v3.6 + v3.10
> min/max/sum/count/index_of）、#10 接口/多态（v3.13：interface 隐式实现 +
> vtable 分派 + 接口值列表，§27）、#12 标准库最小版（v3.12：os_args/
> os_env/assert_eq，§26）全部完成；#4/#5 match/enum 追强（v3.11 穷尽性
> 检查 + match 初始化表达式）。match v2 部分余项：return/嵌套表达式位置、
> 守卫。并发 v2（线程池/有界 channel）仍为候选。
>
> **P1 剩余仅 #11（架构级工程，需专项轮决策）**：
> - **#9 泛型约束**：**v3.15 已完成主体**——<T: num|cmp> 约束 + 实例化
>   实参校验 + dry check 早暴露坏体 + 泛型 struct 方法实例化（§28）。
>   评估结论：per-instantiation body check 其实早已存在（实例化时
>   check_one_fn 用具体类型重查），原分析"体只检查一次"过时。
>   余项：泛型体 let T 声明（体级 subst）、interface × 泛型方法。
> - **#11 独立编译/增量构建**：**v3.15 已落 v1（构建级缓存，§28.3）**——
>   .zfydeps 依赖清单 + hash 比对，未变跳过编译链接（ZFY_FORCE=1 强制）。
>   剩余（架构级）：driver 文本内联合并 + 单 LLVM module 是
>   根基约束；per-module 增量需 per-file module + 链接编排 + 跨文件 typeck 边界
>   （导入文件类型/函数一致性检查）。建议路径：先做 per-module 缓存
>   （.zfy hash → 跳过 parse/typeck 的模块级缓存），再做真独立编译。
>   二者工作量均为 1-2 个专项轮，需与 P2 清单（错误恢复/数值安全）竞争排期。
>
> **状态更新（2026-10-23，v3.10.0）**：P1 继续收窄——
> #6 for-in 遍历（v3.6 落地 + v3.10 带下标 `for x in xs, i`）、
> #7 容器算法（v3.6 sort/reverse/join/filter/any/all/sort_by/fold/contains +
> v3.10 min/max/sum/count/index_of）全部完成；#9 泛型放宽第一步
> （v3.10：T[]/T[N]/T* 可作类型实参，§25）。P1 剩余：#9 泛型约束系统、
> #10 接口/多态、#11 独立编译、#12 标准库。下文分析保留作历史依据。
>
> **状态更新（2026-10-18，v3.8.0）**：P0 三项全部完成——
> #1 容器 map/set（v3.6.0 容器轮）、#3 闭包/lambda（v3.7.0 函数式轮）、
> #2 并发（v3.8.0 并发轮：spawn/join/atomic/mutex/chan<T>/sleep，见
> grammar.md §21）。P1 亦推进：#4/#5 switch-match/枚举与和类型
> （v3.9.0，grammar §22/§23）、#8 字符串设施（format/substr/startswith/
> endswith/contains/to_str，§24）。下文分析保留作历史依据，P0/P1 条目以各轮 changelog
> 与 grammar.md 现行版为准。
>
> 2026-10-18 · 原始基线：v3.5.1（commit cdfde19）
> 对照对象：C / C++ / Rust / Go / Java / Python / JavaScript / C#
> 依据：grammar.md v3.4.0 全文 + examples/demos/bench 实测 + collab 历史轮记录
> 定位：zfy 是"AOT 编译、值语义、无 GC、Windows 优先"的 LLVM 后端语言。
> 本文档只列**功能短板**，不否认已有优势（性能已达 cpp 1.0~1.1x、
> i128/u128 全宽、frac 精确分数、ZEM 错误值、GUI 全栈、错误报告 DX 领先）。
> 优先级：**P0**=做真实软件绕不开；**P1**=显著影响表达力/工程化；**P2**=锦上添花。

## 总览（按影响排序）

| # | 差距 | 优先级 | 一句话影响 |
|---|---|---|---|
| 1 | 无哈希表/字典/集合 | P0 | 键值查找只能线性扫列表，效率与表达力双输 |
| 2 | 无并发（线程/协程/async） | P0 | 多核与 IO 并行完全用不上 |
| 3 | 无闭包/lambda/高阶函数 | P0 | 回调、排序比较器、事件处理器只能手写 struct |
| 4 | 无 switch/match 模式匹配 | P1 | 多分支全靠 if 链，状态机代码冗长 |
| 5 | 无枚举 enum 与和类型 | P1 | 常量组手写、状态合法性编译器不查 |
| 6 | 容器遍历无 for-in/迭代器 | P1 | `for let i32 i = 0, i < length(xs), i++` 样板每处重写 |
| 7 | 无内建排序/查找/反转等容器算法 | P1 | videolib 排序靠手写插入排序；无 sort/reverse/join |
| 8 | 字符串设施薄弱 | P1 | 无 format/插值/startswith/join/正则；length 是字节数 |
| 11 | 独立编译 | P1 v1 ✅ | 构建级缓存已落地；per-module 增量/真独立编译待专项轮 |
| 9 | 泛型受限 | P1 ✅（v3.15） | 约束/方法已落地；余项：体级 let T、显式实例化语法 |
| 10 | 无接口/继承/多态 | P1 | 组件库无法抽象"可绘制物"，只能 each-type-if |
| 11 | 无独立编译/增量构建/包管理 | P1 | 全部源文件文本合并每次全量重编；依赖靠复制文件 |
| 12 | 标准库薄 | P1 | 无网络/进程/环境变量/JSON/序列化 |
| 13 | 运行期错误不可恢复 | P2 | 越界/除零 panic 直接死，无 try-catch 全链回溯 |
| 14 | 整数溢出/移位未定义行为 | P2 | 无 checked arithmetic 与 debug 溢出检查 |
| 15 | 其他语法缺口 | P2 | 三元运算符、嵌套函数、标签 break、字符串顶层 const 等 |

---

## 1. 数据结构：容器生态是最大短板（P0）

**现状**：只有定长数组 `T[N]` 与动态列表 `T[]`（seq 头 + 线性内存）。
查找靠 `find()`（线性）；去重靠手写双循环；键值映射不存在——
videolib 的"按 id 找视频"、widgets 的命中测试全是 O(n) 扫描。

**主流做法**：
- Python `dict`/`set`、Java `HashMap`/`HashSet`、C++ `std::unordered_map`、
  Go `map`、Rust `HashMap`/`BTreeMap`、JS 对象/Map——全是语言级或标准库级一等公民。

**缺失能力清单**：
- 哈希表 `map<K,V>`（插入/查找/删除 O(1)）——string/struct 键需要可哈希约定
- 有序映射 `sorted_map<K,V>`（范围查询；frac 作键时尤其有用）
- 集合 `set<T>`
- 双端队列/栈/优先队列（堆）
- 容器字面量空列表 `[]` 仍不可写（t-041 再次确认），类型推导也没有

**建议方向**：runtime 加 robin-hood/open-addressing 哈希表，语言层
`let map<string, i32> m` 声明 + `m["k"] = v` / `m["k"]`（缺失产 `V!`）。
键类型先限 string/整数/char（值可哈希），struct 键后续加 derive。
这是**投入产出比最高的一项**：GUI、游戏、脚本工具全部受益。

## 2. 并发：单线程语言（P0）

**现状**：无线程、无协程、无 async/await、无原子类型、无互斥锁。
GUI 靠消息泵轮询模拟（gui_frame_sleep），IO 全阻塞。

**主流做法**：C++ `std::thread`/atomic、Rust `std::thread`+async、
Go goroutine+channel、Java 虚拟线程、Python asyncio、JS 事件循环+worker。

**最小可用路径**（不必一步到位）：
1. runtime 层 `thread_spawn(fn_ptr, arg)`、`mutex_lock/unlock`、
   `atomic_add`（Win32/POSIX 双路径，与 zfy_time_* 同套路）——函数指针
   +单参数指针的 C 风格线程，unsafe 块门槛，可先出
2. 语言层 channel（列表+锁封装成 stdlib）——性能不重要，语义先通
3. async/await 需要 MIR 着色/状态机降码，工作量大，**不建议近期做**

**风险**：zfy 的自动 move/深拷贝所有权分析目前假设单线程；
跨线程共享需要 `unsafe` 或新的 `shared` 标注，否则数据竞争无防护
（连 Rust 的编译期防线都没有，至少要文档化"共享即可怕"）。

## 3. 函数式能力：无闭包、无高阶函数（P0）

**现状**：函数只能经 `type Callback = i32(i32)` 别名+函数指针传递；
**捕获环境变量不可能**（函数指针无上下文）。列表无 map/filter/reduce/
any/all——统计"列表里所有及格成绩的平均分"要手写循环。

**主流做法**：C++ lambda（可捕获）、Rust `Fn`/`iterator adapters`、
JS/Python/Java/Go（Java 8+ lambda、Go func 字面量）全部内建。

**缺失能力清单**：
- lambda 表达式 `fn(x) => x * 2`（匿名函数）
- 环境捕获（值捕获即可，引用捕获涉及所有权需谨慎）
- 容器高阶内建：`map(xs, f)` / `filter(xs, f)` / `reduce(xs, f, init)` /
  `any(xs, f)` / `all(xs, f)` / `sort_by(xs, cmp)`
- 函数类型的表达限制：`i32(i32)` 直接作参数类型不可写（必须 type 别名），
  多个回调参数时别名爆炸

**建议方向**：lambda 降码为"编译器生成的匿名 struct（捕获字段）+
匿名函数"，类型 `fn(T)->R` 一等化。这是泛型之后的第二个表达力天花板。

## 4. 控制流：无 switch/match（P1）

**现状**：多分支靠 if/else if 链；计算器 16 键分发、ZEM err.code
分派、菜单条目分派全是 if 链。无三元运算符（`c ? a : b`），
`let x = cond 值1 else 值2` 也没有——只能先声明再 if 赋值。

**主流做法**：C switch、Rust match（模式绑定+穷尽性检查）、
Go switch（无穿透）、Python 3.10 match、JS switch/三链。

**缺失能力清单**：
- `switch v` / `case 值:` 语句与表达式形式（整数/char/string 值分发）
- 值域 case（`case 0..9:`）与多值 case（`case 1, 2, 3:`）
- 表达式位置的条件选择（三元/`if 表达式`）
- 标签 break/continue（跳出多层循环）

## 5. 类型系统：无枚举、无和类型、泛型受限（P1）

**现状**：
- 常量组手写 `pub let i32 const EV_MOVE = 1`——无 enum，编译器不查
  穷尽性、不查非法值、变量可以塞任意 i32
- struct 无继承/接口/trait——widgets 的 9 个组件无法统一抽象，
  App 内部只能按类型分槽（labels/buttons/...9 个平行容器）
- 泛型（t-017）：无约束（对 T 只能做值语义通用操作）、**数组/列表/
  frac/T!/函数类型不能作类型实参**（E3171）、无显式实例化语法、
  泛型函数不支持 ref 参数（E3173）——`fn f<T>(xs T[])` 写不了
- 无 tagged union/variant（C++ std::variant、Rust enum）

**主流做法**：Rust enum+match 穷尽检查、Java/C# enum+接口、
C++ 概念约束模板、Go 泛型约束。

**建议方向**（按序）：
1. `enum Status { Ok, Err, Pending }`——底层 i32，switch 穷尽性检查
2. 泛型放宽：允许 `T[]` 作类型实参（最常见需求，seq 指针本来就是
  单指针，单态化成本为零）
3. 接口最小版：`interface Drawable { fn void draw() }` + struct 声明
  实现 + `Drawable` 类型的列表（虚表或 enum-tag 分派）

## 6. 容器遍历与迭代协议（P1）

**现状**：遍历列表必须写全三段 for（且**更新段不可省**的规则
使 `for x in xs` 式遍历无处安放）；无 while-let、无迭代器。
字符串按字节遍历，码点遍历要自己管 UTF-8 对齐（TextArea 里
align_fwd/next_cp 的教训——t-043 整轮修的就是这个语义踩坑）。

**主流做法**：C++ range-for、Rust `for x in xs`（Iterator trait）、
Go range、Python for-in、Java 增强 for。

**建议**：`for x in xs` / `for x in xs, i`（带下标）脱糖为下标循环；
字符串遍历按**码点**产出 char/string。这一条与 #7 排序一起，
能把 zfy 的"样板循环浓度"降到主流水平。

## 7. 容器算法内建缺失（P1）

**现状**：排序不存在（videolib t-042 手写插入排序）；无 reverse/
join/index_of（有 find）/count/contains（find?? >= 0 绕）；min/max
（手写）；zip/chunk。random 库反而有 shuffle/choice/sample——
不对称说明只是没排期。

**主流做法**：Python 内建+itertools、C++ `<algorithm>`、
Rust slice 方法、JS Array.prototype.*。

**建议**：一轮加齐 `sort(ref xs)`（int/float/string 各型快排）、
`sort_by(ref xs, cmp)`（依赖 #3 闭包，可后置）、`reverse(ref xs)`、
`join(xs, sep)`、`contains(xs, v)`、`min/max(xs)`、`sum(xs)`。
全是 runtime+stdlib 级工作，无编译器改动（sort_by 除外）。

## 8. 字符串与文本处理（P1）

**现状**：string 是**字节串**（length=字节数），格式化只有
`prec(v, n)`（宽度对齐）——没有 printf/格式说明符，浮点小数位数
无法控制（`output(3.14159)` 全量打印）；无字符串插值
（`"x=${v}"`）、无 `format(...)`、无 join/reverse/startswith/
endswith/pad/upper/lower/is_digit；**无正则**；trim 语义特殊
（删除所有出现字符，不是去两端空白）。顶层 const 仅整数（E3042），
string 常量只能内联（t-041 ③）。

**主流做法**：Python f-string、Rust format!、C# 插值、
JS 模板串；各语言 regex 标配（Go 内建）。

**建议方向**：
1. `str_format(fmt, args...)`——`{}`/`{:.2f}` 占位，runtime 一处实现
2. 字符串方法式调用 `s.join(xs)`/`s.startswith(p)`（脱糖内建即可）
3. regex 引 PCRE2 或自写受限引擎（P2，依赖外部库需考虑链接策略）
4. 顶层 string const（现在只有整数能 const）

## 9. 工程化：构建系统与包管理（P1）

**现状**：
- **全量重编**：mod/use 是文本内联合并（driver.ml 递归展开），
  改一行重编所有文件；videolib 四文件已能感受到等待
- **无包管理**：stdlib 靠父链目录查找；第三方库=复制 .zfy 文件进项目
- 可见性只有 pub/私有两级；无 `#[deprecated]`/实验标注类元信息
- 无条件编译（按 OS/特性开关代码）不存在——runtime.c 有双路径，
  zfy 层没有

**主流做法**：C++20 modules/预编译头、Rust cargo（增量编译+依赖
+特性开关全套）、Go module 缓存、Java Maven/Gradle。

**建议路径**：
1. **增量编译**：mod 文件级缓存（.zfy → .lli 中间产物 + 时间戳/哈希
   失效判断）——单文件未变则跳过 codegen。这是编译器当前架构下
   可做的，收益立竿见影
2. 包管理最小版：`deps.txt` + `zfy fetch`（git clone 到缓存目录）
   + use 路径解析扩展——可以先只做"约定目录+版本目录名"
3. 条件编译：`#if os == "windows"` 词法层跳过即可

## 10. 标准库覆盖面（P1）

**现状**：string 基础操作、随机数（质量不错）、时间、File I/O
（§14，move-only 句柄）、GUI、网络（v3.37：TCP/UDP）。**没有**：
HTTP 客户端（需在 socket 之上自建）、进程管理（spawn/pipes）、
环境变量/命令行参数内建、JSON/CSV/序列化、压缩、数据库、
单元测试框架（回归靠 PowerShell 对拍 out 文件）。

**建议优先序**（对齐"真的能做软件"目标）：
1. **命令行参数**：`os_args() -> string[]`——目前连 argc/argv 都拿不到
2. **进程与环境**：`os_env(name)`、`process_run(cmd, args)` 
3. **JSON 编解码**（无反射则用"字符串→逐节点遍历"的 DOM 式 API）
4. **单元测试内建**：`assert_eq(v, want)` + `zfyc test` 收集
   `*_test.zfy` 运行汇总——把回归从 PowerShell 搬进语言
5. ~~网络（WinSock 封装 TCP 先行）~~——**v3.37 已完成**：TCP/UDP +
   超时/非阻塞/poll，缓存 `stdlib/net.zfy`；HTTP/HTTPS 客户端待做

## 11. 运行期错误恢复（P2）

**现状**：ZEM 只覆盖**可预期**失败（T! 类型：find/cast/input/文件）。
越界/切片/除零/空指针 panic 直接 exit(101)，panic_handler 只能
收尸不能恢复；panic 位置已带 file:line（t-039），但**无调用栈回溯**。

**主流做法**：Java/Python 异常全栈回溯、Rust panic=unwind 可 catch、
Go recover。zfy 走的是 C/Rust(-panic=abort) 路线，方向不算错，
但缺：栈回溯（MSetLoc 已有语句位置，沿调用链展开打印是可行增量）、
`assert` 内建。

## 12. 数值安全（P2）

**现状**：整数溢出回绕无检查（i128 字面量除外）、移位量 ≥ 位宽
是 LLVM poison、无 checked/ saturating 算术变体内建。

**主流做法**：Rust debug 模式溢出即 panic + checked_/wrapping_/saturating_
三套、Python 任意精度整数、C# checked 块。

**建议**：debug 构建加溢出检查开关（llvmgen nsw/nuw 标志已可挂），
成本最低收益明确；checked_add 等作为 `T!` 内建与 ZEM 天然契合。

## 13. 杂项语法缺口（P2，逐条列出）

| 缺口 | 现状与出处 |
|---|---|
| 嵌套函数/局部函数 | 不支持；小工具函数被迫提到顶层污染命名空间 |
| 默认参数/命名实参（普通函数） | 仅 output/input 内建支持命名参数；用户函数无 |
| 可变参数（用户函数） | 无（output 是编译器特判） |
| 运算符重载 | 无（struct 只能用 ==/!= 值比较；frac 运算是内建特判） |
| 方法链上的自引用 struct 方法返回 self | struct 方法有，但无 `&self`/`mut self` 区分，全深拷贝语义下链式 API 成本高 |
| 嵌套列表字面量 | `{{1,2},{3}}` 不支持（t-026 遗留清单），只能逐行 push |
| goto | 无（争议项，多数现代语言也弃用，列出仅为完备） |
| 属性/注解系统 | 无（元信息如 deprecated/serializable 无法表达） |
| 交互式 REPL | 无（编译型语言可选做 zfyc repl 脚本包装） |
| 跨平台 | 仅 Windows（runtime.c GUI/时间/路径双路径已铺垫，POSIX 分支未验证）；文档/工具链默认 Win32 |

## 14. 已追平或不构成短板的项（避免误判）

- **性能**：bench T1-T9 已达 cpp 0.97~1.13x（t-019），不是短板
- **错误报告 DX**：全局序号、did-you-mean、交互式自动修复（t-040）
  已**超过**多数主流编译器的开箱体验
- **128 位整数 / frac 精确分数 / 幂运算符**：多数主流语言没有
- **GUI**：自研全栈组件库 + 多窗口 + 剪贴板 + 菜单栏，小语言罕见
- **指针安全模型**：T*/unsafe 门槛与 C 相当，未承诺 Rust 级保证，
  按定位不算差距
- **panic 定位 / 语句级回溯基础设施**：MSetLoc 已铺好（t-039）

## 15. 建议的整改顺序（三轮）

1. **容器轮**（P0 集中）：map/set 容器 + sort/reverse/join/contains
   算法 + for-in 遍历 + 顶层 string const —— 一次把"数据结构焦虑"清掉
2. **函数式轮**：lambda（值捕获）+ fn 类型一等化 + map/filter/reduce
   + switch 表达式（顺带 enum 最小版）
3. **工程轮**：增量编译 + os_args/os_env/process + assert 测试内建
   + 泛型放宽（T[] 实参）

并发放最后单独决策（所有权模型冲突大，需要专项设计）。
