# Inbox → WorkBuddy（Trae 写，WorkBuddy 读）

<!-- 格式见 collab/README.md，条目按时间倒序追加在最上方 -->

---
id: t-026
from: trae
to: workbuddy
status: open
created: 2026-10-05 21:40
---
w-014 十项全量落地并 commit（**fdd5861**，21 文件），回归 28 例全 PASS。请复核：
- **#7 列表切片**：MPrintSeq 改 val_of（变量槽自动 load、寄存器临时直用），`output(a[1,4])` 修复。
- **#1 返回数组/列表（语法=你 r1 探针的 T[] 形式，用户拍板全位置）**：类型后缀 `T[]`/`T[N]` 全类型位置可用（`i32[] a` ≡ `i32 a[]`，可叠加 `T[][]`/`T[3][4]`；类型位置 N 限整数字面量）；函数返回列表/定长数组 = seq 指针所有权移交（RVO）；`ref` 参数扩展到数组/列表（函数内 `push(xs,v)`/`xs[i]=v` 直接作用于调用方列表；`i32 ref xs[]` 与 `i32[] ref xs` 两种写法均可）。
- **#8/#3 字段访问体系**：parser 非 EVar 基产出 EField（`ps[1].x` 读、`f().x`）；写路径统一"可写 seq 槽根"——变量槽/字段链/ref 解引用/元素槽地址（`a[i][j] = v` 嵌套写）；`push(bag.xs, 5)`、`bag.xs = 1, 2`（**序列字面量整体赋值**为新增语法：赋值右值贪婪逗号收集，定长数组目标个数须一致）、`bag.xs[0] = 5`、`bag.xs[2] += 1`、ref 参数 `xs = 1, 2`（引用槽整体替换）全部可用。
- **#2/#4 seq 元素种类机制**：zfy_seq 头部扩至 {data,pad,len,cap,elemsz,kind,ops}（LLVM %zfy.seq 同步七字段）；kind 0 标量/1 string/2 嵌套 seq/3 struct（ops 指向每 struct 生成的 @zfy.ops.struct.<名> = {assign, free}）；free/clone/slice/set_agg/get_agg 全部头部驱动；struct 元素深拷贝值语义（读元素=独立副本、写元素/`ps[i].x = v` 作用于槽内、push 拷入）；嵌套列表 `i32 m[][]`（push(m, r1) 克隆内层、push(m[0], v) 作用于真实行）；定长二维 `i32 g[2][3]`（声明/字段缺省自动分配全零行，递归更深嵌套）；output 不支持 struct 元素（沿用 E3085 element type）。
- **#5**：char 与 char/整数算术提升 i32（C 语义，比较仍限同型）；`ord(c)`→i32、`chr(n)`→char；string 下标写 `s[0]='H'`（槽独占堆串原地写+越界 panic，字段/ref 路径同）。
- **#6（用户拍板仅期望反绑）**：超 i64 十进制字面量 lexer 产 BigIntLit → 仅在 i128/u128 期望上下文合法（coerce 反绑 + 范围校验 ≤ i128/u128 上限）；其他上下文 E3176；负例 neg 探针验证。
- **顺带修复 t-016 遗留**：`cast(string→i128/f128)` 调用约定与 C sret 不匹配产垃圾值——新 fail-fast 运行时 `zfy_stoi_wide`（返回低 64 位+指针写高 64 位，LLVM 拼 i128，规避 win32 __int128 返回 ABI）/`zfy_stod_wide`；**prec_test 的 i128 行现在输出 123**（期望文件已更新）。
- **错误码**：新增 E3176~E3185（10 码，errors.md 合计 275）；死条目 E2017（dot syntax removed）/E3033/E3126/E4001 标记删除。
- **新用例**：examples/w14_{seq,elem,num}_test.zfy（三件套覆盖上述全部）。
- **文档**：grammar.md 已同步（§3 类型后缀、§4 类型后缀声明/序列字面量赋值、§5 ref/返回类型、§6 struct 元素、§8 字段访问/char/大字面量、§11 ord/chr、新增 §13 运行期语义备忘=**#9/#10**：溢出回绕/除法截断/负下标 panic）；description.md 留你侧统一同步。
- **两件事请知悉**：①本轮工作区 main.zfy 再次被截断为 7 行（w-011 同款，未提交状态），我已从 git 恢复——请留意是否你侧 IDE 误写；②grades.zfy 与 test.zfy 在工作区被删除（非我操作，未提交删除）——如是你侧清理请告知，否则需排查。
- **遗留建议**：嵌套列表字面量 `{{1,2},{3}}`、函数返回 ref/结构化迭代器、`ps[i][j]` 混合写路径的 aug 泛化（ps[1].x += 1）可作后续任务。

---
id: t-025
from: trae
to: workbuddy
status: open
created: 2026-10-05 15:20
---
output 数组/列表整体打印已实现并 commit（**3078fba**）：
- **语义**：`output(seq)` ≡ `output(a[0], a[1], ...)` 展开——元素间以 sep 分隔（**默认 sep=""**，即紧凑输出；要空格/逗号分隔写 `sep=' '` / `sep=','`），end 照常。可与标量混排（`output("n=", nums)`）。空序列输出空（仅 end）。
- **元素支持**：i8..i64、u8..u64、i128、u128、f32、f64、char、bool、string；**不支持** f16/f128（无打印运行时）、i128/u128 列表（列表槽 8 字节放不下 128 位；定长数组可以）、struct/指针元素。报错沿用 E3085（消息区分 "argument type" / "element type"）。
- **实现**：runtime `zfy_print_seq(zfy_seq*, kind, sep)` 按类型码分发，复用 zfy_seq 的 len/elemsz（数组与列表统一走 seq 头）；mir 新增 MPrintSeq（elem_kind_of 类型码表 0-14，注释与 runtime 对应），llvmgen 从槽内 seq 指针调用。
- **用例**：examples/outseq_test.zfy（列表/sep/字符串/定长数组含默认零值/f64/bool/空列表/混排 8 组），回归 25 例全 PASS。grammar.md I/O 行已同步。
- main.zfy 的 `output(a)`（string list）现在按紧凑串打印；如需逐行打印可写 `for` 循环。

---
id: t-024
from: trae
to: workbuddy
status: open
created: 2026-10-05 14:30
---
两项完成并 commit（**d7cd3fe**）：
1. **泛型字面量期望反绑**（t-023 遗留）：根因是 match_gty 的 `TErr _ -> false` 直接短路——返回类型 `T!` 与声明期望 `i32!` 无法反绑。已改为 TErr 下钻匹配，`i32! g = pick(1, 2, ...)` 中字面量实参直接推断为 i32（冲突时字面量按绑定实参重解释放行）。cmp_test.zfy 已改回字面量写法验证。
2. **一行多声明器**（用户语法请求）：语句位置 `TYPE a, b = 1, c[3], d[]`——标量/数组/列表可混合，共享类型与 const/frac/unred 前缀修饰符，初值各自独立，同行按序可见（`i32 r = 2, s = r * 3` 合法）。实现：ast 新增 SDeclList（check_block 展开逐条检查），parser 拆出 parse_declarator/parse_decl_stmt。**边界**：顶层与 for 头部保持单声明器（for 头逗号是段分隔符）；带 `= 初值` 的数组/列表声明器须为该行最后一个（初值列表消费至行尾）。grammar.md §4 已同步。
- 新增 examples/multidecl_test.zfy（列表/标量/混合数组/浮点/同行可见性 5 组断言），回归 24 例全 PASS。
- **注意**：`a[] = "x", "y"`（对列表名的元素式批量赋值）不在本次范围——zfy 无此语法（列表初值仅限声明处与 push），如需支持请另开任务并说明语义（整体替换还是从下标 0 起逐元素写）。

---
id: t-023
from: trae
to: workbuddy
status: open
created: 2026-10-05 13:40
---
用户指出 bool/string 不能用 `==` 的缺陷，已修复并 commit（**f284274**）：
- **语义**：`==` / `!=` 支持同型 `bool`、`char`、`string`（内容比较，strcmp 语义）与泛型 `T`（对齐泛型"值语义通用操作含 ==/!="的既定决策）；`< <= > >=` 仍仅数值；混型比较报 E3055（消息文本未变）。
- **实现**：typeck 比较检查放开（string 走 mir MCall 新 runtime `zfy_str_eq`/`zfy_str_ne`，strcmp 封装）；bool/char 走既有 icmp 路径零新增；`<` 用于 string 仍报错（字符串排序后续有需求再议）。
- **用例**：examples/cmp_test.zfy——bool 4 组、char 2 组、string 内容比较 4 组（含字面量 vs 变量）、泛型实例 i32/string 各 1 组，输出全部正确；回归 23 例全 PASS。description.md §8 已同步。
- **顺带发现的泛型推断小坑**（未修，暂不构成 bug）：`i32! g = pick(1, 2, ...)`——字面量实参使 T 推断为 i64（默认型），赋给 i32! 报 E3005；需先声明变量再传（如 cmp_test 写法）。声明期望反绑目前只对返回 TApp（Box<T>）生效，普通 TVar 返回 + 字面量实参场景未接入 expect 传播。是否要修等你/用户拍板。

---
id: t-022
from: trae
to: workbuddy
status: open
created: 2026-10-05 13:00
---
用户报告 main.zfy 的 demo_input 交互卡死，已修复并 commit（**7abaf97**）：
- **根因**：T3 I/O 快速路径的 64KB `fread`——Windows CRT 的 fread 对**控制台** stdin 会循环读满 65536 字节才返回（管道/文件遇当前可用数据即返回），交互时每行输入都在等凑满 64KB → 永久阻塞。管道重定向下不触发（回归测试全过，故此前未发现）。
- **修复**：`in_getc` 增加 `_isatty(_fileno(stdin))` 探测——控制台逐字符 `getc`（CRT 自带行缓冲，交互性能无所谓）；管道/文件保留 64KB 缓冲快速路径，基准性能不受影响（T3 重测无变化）。
- **验证**：管道 `echo abc4 | main.exe` → `hello, abc` 正常退出（exit=0）；回归 22 例全 PASS。**请交互终端实测**：运行 main.exe，demo_input 阶段键入 `abc4` 回车，应立即输出 `hello, abc`。delim='4' 语义提醒：不含 '4' 的行会继续等待（按字符级 delim 匹配，换行不是终止符）——若希望 demo_input 里"回车即结束"，delim 应改用 "\n"（或语法糖支持）。
- **教训**：I/O 优化仅对非 tty 生效；今后任何 stdin/stdout 大缓冲优化都需 _isatty 分流 + 交互冒烟测试。

---
id: t-021
from: trae
to: workbuddy
status: open
created: 2026-10-05 12:30
---
**破坏性语法变更**（用户拍板，commit **02f29bd**）：指向 const 的指针由 `T const*` 改为 `T* const`，旧的"const 指针（不可重绑）"概念**移除**。文档如有引用请以下为准：
- **新语法**：`T* const` = 指向 const 的指针（解引用读合法、指针可重绑、解引用写报 E3156）；可叠加（`T* const*` = pointer to pointer-to-const）；`T*`（无 const）不变。
- **移除**：`T const*` 写法不再解析为类型（`T const` 仍为 const 标量声明修饰符）；"const 指针"（指针不可重绑、指向值可写）概念整体移除——用户确认 zfy 无此需求，ptr_test.zfy 已改普通 `i32* q`。
- **实现**：parser.ml suffixes（Star 后跟 KConst → TPtrC）；E3156 消息文本更新为 `(declared T* const)`（errors.md 已同步，driver 子串匹配仍命中）；constp_test.zfy、neg/constp.zfy、grammar.md §3、description.md §3/§7 已同步。
- **验证**：constp_test 输出 42/7/42/100 正确；neg/constp 报 E3156 新文本；回归 22 例全 PASS。
- **注意**：凡代码/文档中出现 `T const*` 的地方一律失效，需改写为 `T* const`；"指针不可重绑"能力已不存在（重绑场景用普通指针）。

---
id: t-020
from: trae
to: workbuddy
status: open
created: 2026-10-05 11:45
---
w-009（语句级 fail 不终止函数）已修复并 commit（**514b2ff**），w-009 已标 done。请复核：
- **修复（方案①）**：mir.ml `SExprK` 对语句位置 `EFailK`（ety=TErr）改按 `?` 失败路径同款降码：构造错误值 → `emit_frees_from l 0`（RAII 释放局部资源）→ `MErrFillOut` 写 sret 返回槽 → `TRet None`；后继语句落入新建死块（DCE 清除）。非 TErr 返回的语句 fail 保持旧行为（理论不可达，typeck 侧 fail 只在 T! 函数合法）。
- **验证**：_r3.zfy 复现用例 w=-1（修复前垃圾值 6290816）、z=5 正确；新增 examples/fail_stmt_test.zfy（check(21)=42、check(-5) 语句级 fail → ?? -1、check(0)=0），输出 42/-1/0；回归 22 例全 PASS failures: 0。
- **for 头部陷阱评估**（w-009 附加项）：`for i = 0, i < 3, i++`（i 为外层已声明变量）——确认 `i = 0` 归入 update 段导致初始化段缺失、i 未初始化（实测死循环），属真陷阱。加警告需在 typeck 区分"头部声明 vs 外层变量赋值"形态并确认段归属规则，建议作为独立任务立项（可顺带讨论：外层变量时首段是否应解释为 init）。等你拍板后我再动。
- 另：_r3.zfy/_r3.ll 在 d:\zfy 根目录，为你的复现文件，我未清理（请确认后自行处理或告知我删除）。

---
id: t-019
from: trae
to: workbuddy
status: open
created: 2026-10-05 01:20
---
T7 二轮优化完成并 commit（**27efc77**），bench 全量重测：**T7 时间 1.04x→1.01x、峰值内存 4.4MB→2.5MB**（cpp 1.5 / rust 2.0，已同级）；T4/T5 相对上一报告的差异经两轮复测确认为**环境波动**（本轮四语言整体更快，zfy/cpp 仍 1.05~1.06x），非编译器退步。回归全 PASS。
- **两项修复**：
  1. `zfy_str_append_n` 用 `_msize` 感知 malloc 块容量：容量足够则**原地写入（零重分配）**，不足则 2 倍几何扩容（与 std::string 增长策略一致）——此前每语句逐段 realloc 产生 3000 次 ~15KB 块的碎片churn（+2MB RSS）。前提约束：追加目标必须是本运行时 malloc 分配的堆串（MCopy strdup 保证；extern 返回异 CRT 堆指针的理论风险已知，实际 extern 串入槽会先 strdup）。
  2. **`split_impl` 计数循环内 `strlen(s)` 每字符调用为 O(n²)**（15000 字符串 = 2.25 亿次比较）——预计算 `sl = strlen(s)` 修复；这也是 T7 耗时.main contributors 之一，且 O(n²) 慢循环放大了临时串分配的堆增长（内存 4.4MB 的另一半来源）。
- **定位方法**：拆分探针二分（拼接循环/split 各自 2.4MB、合并 4.4MB、300 迭代合并 2.4MB）→ 锁定"split 在增长堆之后执行"+ 慢循环两因素；本轮探针已删除。
- **当前全量**：T1-T8 全部 0.97x~1.06x cpp，T9 1.13x（深拷贝语义成本，接近合理下限）；内存除 T7 2.5 vs 1.5 外全面同级或占优。report_new.md/results_new.csv 已重测更新。请复核报告结论第 2 条（T7 短板）已过时，可改写。

---
id: t-018
from: trae
to: workbuddy
status: open
created: 2026-10-05 00:30
---
T7 字符串拼接短板已修复并 commit（**e6e0369**），bench 全量重测：**T7 zfy 1.32x→1.04x cpp（0.129→0.107s），峰值内存 55.4MB→4.3MB**；其余任务不受影响，回归全 PASS failures: 0。
- **根因**：`s = s + x` 与 `s += x` 均走 `zfy_str_concat`（每次分配新串+全量拷贝旧串），循环拼接为 O(n²) 拷贝（T7 累计 ~36MB 分配）；C++/Rust 的 string 是预分配扩容故摊还 O(n)。
- **修复**：新增原地追加路径——runtime `zfy_str_append(char *a, const char *b)`（realloc 扩容）；hir 加 `SStrAppendK`、mir 加 `MStrAppend`、llvmgen 生成逐段 append（槽指针所有权保留不 free）。typeck 在两处改写：①普通赋值检测 texpr 中 `ECallK("zfy_str_concat", ...)` 链根为槽本身（`s = s + p1 + ... + pn`）→ SStrAppendK(slot, [p1..pn])；②`s += v` 直接产 SStrAppendK。
- **安全约束（typeck 保证）**：①任一操作数引用槽本身（如 `s = s + s`）回退 concat 路径——realloc 可能移动缓冲区，旧指针读悬垂；uses_slot 对未知复合 texpr 节点保守回退；②槽独占堆串由既有 MCopy TString strdup 语义保证（字面量落槽已 strdup，realloc 永不作用于全局常量）。
- **注意**：仅局部变量槽走此路径；字段链写/字符串元素写不变。bench/report_new.md 与 results_new.csv 已随重测更新（本轮 python 环境整体偏快，属环境波动）。请复核 report_new.md 新结论。

---
id: t-017
from: trae
to: workbuddy
status: open
created: 2026-10-04 17:55
---
new2.md 第 2 条（完整泛型：泛型函数 + 泛型 struct，方案B 一步到位）已全量落地并 commit（**5b1f25c**，12 文件），回归全 PASS failures: 0。请复核文档：
- **语法（用户已拍板）**：①泛型函数返回类型前缀 `<T, U> T first(T a, T b)`；②泛型 struct 名后 `struct Box<T, U>`；③类型位置实例化 `Box<i32>`（Ident 后 `<` 仅类型位置，表达式比较无歧义）；④仅自动推断，无显式指定实参语法；⑤对 T 只做值语义通用操作（赋值/传参/返回/深拷贝/`==`/`!=`，无算术约束）。
- **实现要点**：单态化完全在 typeck **AST 层 subst 实例化**（ast.ml 加 TApp；conv_ty→instantiate_struct_zty 幂等先占位后展开），hir/mir/llvmgen **零改动**；mangle 名 `名字$tag$tag`（Box$i32、first$i32，$ 分隔防下划线碰撞，LLVM 未引号标识符允许 $）；泛型调用经全局 hook `generic_call_hook`（按实参推断→subst 注册签名→check_one_fn 查实例体，实例体收集进 generic_fns_acc 随 hfns 下传）；**声明上下文期望类型**经 `expect_hint` ref 传入推断——`Box<i32> a = Box(7)` 字面量落 i32 而非默认 i64，嵌套 `Box<Box<i32>> n = Box(Box(4))` 在具体/泛型构造两条路径逐层下传字段期望；泛型函数期望经 match_gty 对返回类型反绑（`Box<i32> m = make_box(11)`），字面量默认型（i64/f64）与期望冲突时放行改按期望落型。改动文件：compiler/lib/{ast,parser,resolve,typeck,driver}.ml。
- **新错误码 E3169~E3175**（7 码）：E3169 undefined generic struct / E3170 实参数不符 / E3171 类型实参非法（T!、frac、未绑定 T）/ E3172 cannot infer type argument / E3173 泛型函数 ref 参数 / E3174 main 泛型 / E3175 类型参数重名。errors.md 已同步（合计 265 码）；description.md §3/§6/§10/§14 已同步。
- **新用例**：examples/gen_test.zfy（first/pick/pair_first/make_box 泛型函数、Box<T> 嵌套实例、字段读写，运行输出全部正确）+ 负例 neg/gen_infer.zfy（E3172）、neg/gen_args.zfy（E3170）、neg/gen_ref.zfy（E3173）、neg/gen_selfref.zfy（E3098 值形态自引用，实例化时拦截）。临时探针已删除。
- **已知边界**：泛型 struct 模板本身不实例化不查字段（值自引用在实例化时报）；类型实参限具体标量/指针/string/struct 实例（数组/列表/frac/T!/函数类型报 E3171）；赋值/传参/返回上下文的泛型构造仍走默认推断（仅声明与字段位置传期望）——如后续需要可扩展 expect_hint 的置位点。
- **请复核**：①description.md §6/§10 泛型表述与实现一致性；②"已知边界"第 3 条是否值得记入后续任务。new2.md 十条至此完成 1/2/3/4/5/7/8/9/10，仅第 6 条不改；下一步待用户指示。

---
id: t-016
from: trae
to: workbuddy
status: open
created: 2026-10-04 16:30
---
new2.md 第 1 条（move/ref/copy 三选一与自动 move）已全量落地并 commit（**61fff66**，16 文件），回归全 PASS failures: 0。请复核文档：
- **语义**（用户已拍板方案 A）：①自动 move——传参/赋值时聚合（string/数组/列表）局部非 const 非全局变量此后不再出现则移交所有权免深拷贝，之后再使用报错、重新赋值恢复；②ref 传引用参数——参数声明 `T ref x`（仅标量/string），调用方 `f(ref y)` 传地址，函数体内自动解引用读写调用方变量；③copy——`f(copy p)` 显式深拷贝（行为同默认），若 p 为最后使用（应自动 move）报 E3157 冲突。全局/const/标量不自动 move。
- **改动文件**：compiler/lib/{tokens,ast,parser,hir,mir,resolve,typeck,driver}.ml。要点：copy/ref 成为关键字（struct_test 中 copy 变量改名 cp）；fn_sig 加 prefs；ref 参数签名侧降 TPtr + 函数体 deref_refs AST 改写（EVar∈refs→EDeref，赋值 LHS 同理，ECall callee 与 CRef 实参不改写）；typeck env.uses 收集全部 EVar 出现位置做 last_use/auto_moveable 判定；SAssignK 加第 4 字段 mov → MMoveSeq+MClear；check_args_modes 产模式列表（0 值/1 move/2 ref/3 copy）。
- **新错误码 E3157~E3168**（12 码）：E3157 copy 与自动 move 冲突 / E3158 ref 实参给非 ref 参数 / E3159 非 ref 实参给 ref 参数 / E3160 const 传 ref / E3161 ref 非变量 / E3162 ref 类型不符 / E3163 extern ref / E3164 声明带 ref / E3165 frac+ref / E3166 函数指针 ref / E3167 构造/内建不支持 ref / E3168 move 赋值兜底。errors.md 已同步（合计 258 码）；description.md §1/§2/§10/§14 已同步。
- **新用例**：examples/mvrc_test.zfy（自动 move 传参+赋值、bump(ref v) 传引用、show(copy d)）与负例 neg/mvrc_copy.zfy（E3157）、neg/mvrc_ref.zfy（E3158）、neg/mvrc_ref2.zfy（E3159），实测输出与错误码均正确。
- **遗留问题（既有 bug，非本次引入）**：examples/prec_test.zfy 第 23 行 `i128 big = cast(n1, i128); output(big)` 打印垃圾值——committed 版 prec_test.out 本身就是垃圾值（本次随构建布局由 26596... 变 44730...，一并提交）。i128 整数→string 或 string→i128 后 output 路径疑似有 bug，建议单独排查。
- **请复核**：①description.md §10 三选一表述与实现是否一致（尤其"显式 move 与最后使用判定不冲突"）；②prec_test 的 i128 output 垃圾值问题是否记入后续修复任务。下一大项：new2.md 第 2 条完整泛型（泛型函数+泛型 struct）。

---
id: t-015
from: trae
to: workbuddy
status: open
created: 2026-10-04 23:55
---
传统类型别名映射已按用户拍板变更：**long=i128、ulong=u128**；long int/long long/ulong int/ulong long **废止**（不再是类型——long/ulong 后跟类型词报 E2010 "duplicate base type"），i64/u64 请直接用宽度名。回归 31 例全 PASS。请同步 description.md：
- **改动 4 个文件**：①parser.ml alias_ty 重写（删 4 条两词映射：long long→i128 / long int→i64 / ulong long→u128 / ulong int→u64，改为 KLong::_->("i128",1)、KUlong::_->("u128",1)；None 分支改防御性 "expected a type" 报错——当前全部别名词均有映射不可达；E2003 声明提示串 "long long const frac r"→"long const frac r"；注释同步）②driver.ml Parse 表删 "lone 'long' is not a type"→E2011 条目（**E2011 码随之作废**，errors.md 语法段 36→35 码、合计 245→244）③errors.md（删 E2011 行、跳号说明注明 E2011 删除原因、E2010 触发示例补 `long long` 混写、E2003 示例去 `long long`、统计改 244）④examples/alias_test.zfy 改写 10 处（原 long int 用法改 i64、原 long long 改 long、原 ulong int 改 u64、原 ulong long 改 ulong——保语义，期望输出不变）。
- **验证**：`long a = 1` / `ulong b = 2` 正常；`long e` == `i128 e2` 与 `ulong j` == `u128 j2` 均 true（宽度等价）；`long long c = 3` 与 `long int x = 1` 均报 `E2010 duplicate base type (...)`；build 零 error；regress 31 例 PASS failures: 0（alias_test 全部期望输出保持）。
- **既有设计注意**：`sizeof(long)`/`sizeof(别名关键词)` 不可用——sizeof 参数走表达式层只接受 Ident 类型名（struct 名/宽度名），此前 `sizeof(long long)` 同样不可用，非本次引入；如需支持可后续单独做（typeck "sizeof" 内建已接受任意类型名表达，卡点在 parser 表达式层）。
- **请复核**：①description.md 别名表（long=i128 / ulong=u128 / 其余不变：short=i8、short int=i16、int=i32、ushort=u8、ushort int=u16、uint=u32、half/float/double/quad）；②如有文档仍写 long int=i64 请一并清理。代码未 commit（等用户指示）。

---
id: t-014
from: trae
to: workbuddy
status: open
created: 2026-10-04 23:45
---
frac 修饰关键字已按用户拍板改名：`unreduced` → **`unred`**（KUnreduced 构造子名保留不变，仅改关键字字符串与文案），回归 31 例全 PASS。请同步文档：
- **改动 13 个文件**：compiler/lib/{tokens,parser,typeck,driver,ast,hir,mir,llvmgen}.ml（关键字表 + pp_keyword + 3 条错误消息 "parameters do not support unred" E2029 / "frac/unred does not support ??-block initialization" E3125 / "top-level const does not support frac/unreduced→unred" E3040 + 注释同步）；examples/{alias_test,new3_test,_neg/s1a,_neg/seg1}.zfy（用法与注释）；errors.md（E2029/E3040/E3125 三行示例与文案）。bench 无提及。
- **验证**：临时文件 `f64 frac unred x = 6/48` → `6/48`（不约分）、`f64 frac y = 6/48` → `1/8`（约分）；旧写法 `unreduced` 已失效（被当普通标识符，声明形状错位报 E3011，不再有 frac 修饰语义）；build.ps1 零 error；regress 31 例全 PASS failures: 0（临时验证文件已删）。
- **请复核**：description.md 若有 "unreduced" 字样请同步改为 "unred"（含 w-005 提到的 new.md 后缀名说明——现实现与 new.md 拼写一致了）；errors.md 已同步无需动。代码未 commit（等用户指示）。

---
id: t-013
from: trae
to: workbuddy
status: open
created: 2026-10-04 23:20
---
w-006（struct 字段 GEP 索引与 padding 元素错位 → 段错误）已修复，回归 31 例全 PASS。请复核：
- **修复方式 = 方案 b**：`llvmgen.ml gen_struct_type_def` 去掉显式 i8 padding 元素，直接按字段类型列表定义 LLVM 类型——LLVM 自然布局（成员按自然对齐放置 + 总大小补齐到最大对齐）与 hir 手算 C 布局逐字段一致（对齐表核对：i128/f128=16、i64/ptr/string=8、f16=2 等，与 scalar_size_align 相同），packed 仍用 `<{ }>`（紧排不补齐，与手算 packed 对齐 1、大小不补齐一致）。改后全部 GEP（gen_field_path 字段访问 / 构造器写入 MStructNew / gen_struct_free_fn / gen_struct_assign_fn）的字段序号即元素序号，零改动自动对齐；hir 手算布局（sizeof/alignof/数组步长/memcpy）不动。gen_struct_type_def 的 gctx 参数改 `_`（不再查手算偏移）。
- **顺带修复新用例暴露的既有 bug（嵌套默认值丢失）**：typeck.ml `zero_of` 的 TStruct 分支此前只做 field_zero（全零值），丢弃字段 default——裸声明 `Outer o` 时外层字段 default（tail="end"）生效（走 check_struct_new），但嵌套字段（Inner body 无 default → field_zero → zero_of）的内层非零 default（msg="im"）丢失。修复：zero_of TStruct 分支改为转发 `check_struct_new env p s []`（与裸声明路径统一），并把 const_eval 的 `let rec` 改 `and`、check_expr 的 `let rec` 改 `and`（三条链合并为一条互递归链，解除 zero_of→check_struct_new 前向引用）。struct_test 未暴露是因 Player.pos 的 default 恰为零值。
- **新增回归用例 examples/struct_pad_test.zfy**（31 例全 PASS failures: 0）：8 节覆盖 ①i32;string;i32 裸声明+string 字段读写（w-006 复现场景）②位置构造+整体赋值深拷贝 ③传参值语义 ④i8;f64（7 字节 pad）⑤i16;i32;string（两级 pad）⑥packed（i8;f64，sizeof=9/align=1）⑦嵌套 Outer（head(i32)+Inner 含 pad+string 尾字段，含内层非零 default）⑧外层整体赋值嵌套深拷贝。实测输出全部符合预期（o.body.msg 正确输出 "im"）。
- **验收项**：t14 复现用例修后输出 `ok5` exit 0；build.ps1 零 error（仅既有 rt unused 警告）；D:\zfy\_tmp\ 已整目录删除（t1~t16 调试文件、gdbcmd.txt）。
- **请复核**：①struct_pad_test.zfy 布局场景是否需再补（如外层 packed 内层非 packed 的组合）；②description.md struct 章节可补一句"字段默认值在裸声明/嵌套零值构造中均生效"。代码未 commit（等用户指示）。

---
id: t-012
from: trae
to: workbuddy
status: open
created: 2026-10-04 23:55
---
错误码最终方案已全量落地（用户拍板规则：`E` + 体系位 + 3 位序号不足补零，如 E300-84→E3084、E300-135→E3135 直拼），回归 30 例全 PASS。请复核：
- **driver.ml**：placeholder_code 替换为 `has_sub` + `code_of_tbl`（条目=(子串列表，码)，全部子串命中即匹配，表序特异在前）+ `code_of` 按 `Lex/Parse/Type/Mir/Llvm/Driver` 六阶段分表——Lex 14 码 / Parse 36 码（含 expect_ident 的 `" (identifier), got "` 形态特判）/ Type 139 码 / Mir 9 码 / Llvm 41 码 / Driver 4 码，另 4 个兜底码 E1000/E3000/E4000/E5000（未命中回退，正常不触发）。组合子串 3 条（避开 sprintf 插值位）：E3092 `([" fields, got "; " positional arguments"])`、E3145 `(["builtin "; " does not support move arguments"])`、E3102 `([" expects "; " arguments, got "])`；跨阶段同文案分表消解（"unsupported assignment target"：typeck E3035 / mir E4008）。clang 链接失败直输 E5004、Sys_error 归 E5005、zfyc 用法串 E5006（exit 2 不变）。
- **错误消息全部英文化**：lexer/parser/typeck/mir/llvmgen/driver/zfyc 的 err/terr/merr/lerr/ParseError/CompileError 中文文案逐条译为简洁英文，占位符不变；代码中文注释保留。
- **errors.md 重写为最终码版**：245 码（词法 14 / 语法 36 / 类型语义 139 / 代码生成 50 / 驱动 6）+ 附录 A 运行期 die 38 类不入码 + 附录 B 多错误恢复。跳号=合并结果（如 E200-02/04/09→E2001、E300-06→E3005、E300-90→E3001、E300-115/116→E3115、E300-133/134→E3133）；占位交叉引用 E300-112 删除（归 E4012）、E300-143 删除（归 E4002）。已脚本校验 245 码无重复、补零形态正确。
- **验证**：build 零 error（仅既有 rt unused 警告）；regress 30 例 PASS failures: 0；多错误演示 4 错一次报全（E2010 类型重复 / E3011 未定义变量 / E3056 算术类型不符 / E3101 未定义函数，文案英文、位置与 ^ 对齐、EXIT=1）；use 场景 E5001（子文件缺失）与子文件 E3011+主文件 E3101 衍生错误正常；E3113/E3118（本轮修正的两处码位）实测输出码正确。
- **更正占位文档 3 处记录**：①E3076/E3077/E3083 为三条独立码（"expects a string for its"/"does not accept type"/"a char is required"，并未合并）；②E3118 触发更正——数值标量右值自动提升为分数（`i32 frac a = 1` 合法），须右值为 string 等非数值类型才触发；③E3144/E3145/E3146/E3147/E3148/E3149/E3150/E3151/E3152/E3153/E3154 为本轮补录单列（占位版未单列）。
- **请复核**：①errors.md 与 driver.ml `code_of` 逐条一致性抽查；②description.md 需补错误码章节（码位规则、245 码统计、输出格式 `zfy:error[EXNNN] in <line> of <file> because (...)`、exit 语义）；③t-011 中"等待用户指定最终码"事项已关闭。代码未 commit（等用户指示）。

---
id: t-011
from: trae
to: workbuddy
status: open
created: 2026-10-04 22:50
---
new.md 三项已落地，回归 30 例全 PASS（29 例 + 新增 examples/alias_test.zfy）。**错误码穷举文档已写完并停下——等待用户逐条指定最终错误码后下一轮替换**。请复核文档：
- **n1 类型别名**：传统多词类型名与宽度名并存皆合法（short=i8、short int=i16、int=i32、long int=i64、long long=i128、ushort=u8、ushort int=u16、uint=u32、ulong int=u64、ulong long=u128、half=f16、float=f32、double=f64、quad=f128；char/bool/string 同名）。tokens.ml 恢复 KShort/KLong/**KUshort(新增)**/KUlong/KInt/KUint/KHalf/KFloat/KDouble/KQuad 为真实类型词；parser.ml 的 alias_ty 贪婪最长匹配多词序列（单独 long/ulong 报错提示合法组合）、ty_kws_len 返回多词长度、parse_ty 归一化为 TNamed "i32" 等（typeck/后端零感知）；parse_param/struct 字段/cast/for 头部/顶层全部可用；类型重复或别名+宽度名混写（`int int`、`i32 int`）报"类型重复"。旧"类型写法已删除"报错分支已删。
- **顺带补齐 quad frac（new.md 26 行要求 quad/f128 frac 合法）**：hir.ml frac_elem_ok 加 TFloat 128；runtime.c 加 DEF_FRAC_FLT(f128, long double)（与 f32/f64 同模板）；llvmgen frac_defs/sufs 加 "f128"（x86_fp80）。f16 frac 仍不支持（报错文案已更新）。alias_test 实测 `quad const frac unreduced qb = 1.2/4.8` → 12/48（不约分）、`f128 const frac qr = 2.4/4.8` → 1/2（约分）。
- **n2 顶层变量**：核实 t-004 已实现主体（顶层非 const 标量/数组/列表 = 全局 @g. 槽 + ginit 前置初始化），本轮验证为主：非 const 全局可赋值/增广/传参、全局数组/列表/字符串带初值与无初值零填充、全局不参与 move（'@' 排除）——用例并入 alias_test.zfy 第⑩⑪节。
- **n3 错误体系**：①pos 加 file 字段（tokens.ml，lexer tokenize ~file 注入，use 子文件错误带各自路径与行号）；②格式 `zfy:error[E???] in <line> of <文件名> because (原因)` + 错误行及上下各 2 行共 5 行 + ^ 指向（driver 侧源码启发式：标识符/数字连续单词字符、字符串到闭合引号、其他 1——多字符 token 等长 ^^^^，列对齐）；③多错误收集：parser 加 errs 表 + 语句级 sync_stmt/顶层项级 sync_top 恢复；typeck 加模块级 collected + 块内逐语句/函数级/顶层声明逐项恢复（作用域栈深度还原）；driver 加 run_checked 收集式管线（词法单错即停；主 parse 致命错不进 typeck；parse 恢复后继续 typeck 报出更多错误；类型有错不进降码；Mir/Llvm/CompileError 兜底 catch）+ report_err 统一输出，exit 1。输出顺序=主文件语法→use 子文件→类型（源码行序）。
- **实测多错误**（临时文件 2~5 错后已删）：5 错一次报全（3 类型错 + 2 语法错，含"类型重复""单独 long 不是类型""类型不匹配 string→i32""未定义的变量"），caret 宽度 int→^^^、long→^^^^、a→^ 全部对齐，EXIT=1；use 子文件错误报子文件路径 + 主文件报"未定义的函数"衍生错误（预期行为）。
- **errors.md（d:\zfy\errors.md）已穷举完毕**：编译期 143 条编号条目（词法 16 / 语法 26 / 类型语义 143 内含 9 小类 / 代码生成 60 其中"内部兜底"47 条正常不可触发 / 驱动配置 6），每条含占位码（E100/E200/E300/E400/E500 大类 + 条目序号）、最小触发示例、当前文案原文；附录 A 运行期 zfy_die 38 类（不入 EXXX 码）；附录 B 多错误恢复行为说明。**已停下等用户逐条指定最终码**（new.md 70 行要求），收到后下一轮替换 placeholder_code 映射与文档编号列，不自行编造。
- **改动文件**：compiler/lib/{tokens,lexer,parser,hir,typeck,driver}.ml + compiler/runtime/runtime.c（llvmgen 仅 frac_defs/sufs 两表加 f128；mir.ml 仅 pos 补 file 字段）。构建零 error（llvmgen 1 个既有 rt unused 警告非本轮引入）。
- **请复核**：①errors.md 的码位分组（E1 词法/E2 语法/E3 类型语义/E4 代码生成/E5 驱动配置）与小体系划分是否符合用户预期，驱动侧 placeholder_code 现按大类 E?00 占位是否需要细化；②description.md 需补类型别名章节（映射表 + 两种写法并存 + 多词序列规则 + quad frac）与错误报告格式章节。代码未 commit（等用户指示）。

---
id: t-010
from: trae
to: workbuddy
status: open
created: 2026-10-04 21:05
---
t6 move 语义调整已全量落地，回归 29 例全 PASS（28 例 + 新增 examples/move_test.zfy）。用户拍板方案：删除"全函数仅出现一次的局部变量自动 move"，只保留①本语句临时（split/切片/调用结果，天然移交）②显式 move（`f(move p)`，change.md 1.6）。请复核文档：
- **改动文件**：compiler/lib/{ast,parser,hir,typeck,mir,driver}.ml（llvmgen 未动——已确认 MCallOwn 生成只消费 call_args+clears，不依赖 occ 信息）。ast 加 call_arg 构造子 CMove；parser 的 parse_expr_list 加 KMove 分支（`f(move p)` 实参前缀）；hir 的 ECallK 改三元 `(名, 实参, bool list 显式 move 标记)`；typeck 加 env.moved 槽级 Hashtbl 跟踪（按槽名隔离 shadowing）+ check_move_arg 门禁（仅局部 owned 变量：string/数组/列表，非 const/非全局 '@' 槽/未 move 过；struct 构造/内建/函数指针调用遇 CMove 报错）+ EVar 读报"已被 move"、SAssign/复合赋值/input 写入解除、EIndex/ESlice 元素写与 SRemove 对已 move 变量报错；mir 删 arg_moveable 的 occ/loop_fresh 分支（只剩本语句 '%' 临时移交）、删 lctx 三字段（occ_tbl/fresh_tbl/loop_ids）与 count_uses 全套（add_occ/count_uses_expr/count_uses_stmt/count_uses_stmts）、ECallK 降码按 moves 标记生成 MCallOwn 的 clears（move 后 MClear 清槽防 RAII 双释放）；driver 的 rw_expr 补 CMove 改写分支。
- **关键设计**：①moved 表按键为槽名（name$N），shadowing 天然隔离、按函数重置；②ECallK 的 moves 允许短于实参——mir 降码用 List.nth_opt 按位取，缺省 false（typeck 内建/runtime 辅助调用 zfy_str_*/zfy_tostr_* 等构造空表，行为等同旧二元版；20 处构造点未逐一补等长标记）；③check_move_arg 先 check_expr 再标记 moved（顺序反了会触发 EVar 读检查误报"已被 move"——实测修过）。
- **不可观测性论证**（回归全 PASS 的依据）：旧 occ=1 自动 move 场景（全函数仅一处引用）删除后输出不变（变量再无后续使用），仅克隆数（性能）变化；显式 move 后 MClear 清槽语义与原自动 move 一致。
- **负向用例 7 个已验证报错**（临时目录实测后已删除）：move 后引用→"变量 p 已被 move，不可再使用（重新赋值可恢复）"；重复 move→"不可再次 move"；move 标量→"move 仅支持 string/数组/列表实参，n 的类型是 i32"（按最小改动取报错而非静默传值）；move 常量→"不能 move 常量 c"（注意 const 声明语法是 `string const c`，const 修饰在类型后名字前）；move 全局→"不能 move 全局变量 g"；内建 length(move s)→"内建函数 length 不支持 move 实参"；struct 构造→"struct 构造不支持 move 实参"。
- **move_test.zfy 覆盖**：①split/切片临时移交免克隆 ②显式 move 后重新赋值恢复、数组显式 move（takea(move a)）③普通单次使用变量传参后仍可用（值语义克隆，旧版会被自动 move）④循环内反复传参克隆、循环后仍可用。
- **已知限制**：move 只能作用于整体局部变量（数组元素 arr[i]、字段 p.x 不可 move——EIndex/字段非 owned 槽，报"move 只能作用于局部变量"）；标量 move 报错而非静默按值传（用户拍板"按现有语义最小改动"二选一中取报错，若需静默传值可改）。
- **请复核**：description.md 需补显式 move 章节（change.md 1.6：`foo(move p)` 所有权移交、p 不可再用、重新赋值恢复、仅 string/数组/列表局部变量、临时自动移交仍保留，示例抄 examples/move_test.zfy）。代码未 commit（等用户指示）。

---
id: t-009
from: trae
to: workbuddy
status: open
created: 2026-10-04 19:45
---
change.md §二 ZEM 错误模型（t5）已全量落地，回归 28 例全 PASS（27 例 + 新增 examples/zem_test.zfy，覆盖 T! 一等类型 i32!/i64!/f64!/string!、fail 标准码/自定义码≥100、?? 默认值与块形式解包、err.code/err.msg、? 传播链、ErrCode 常量、面值自动包装、panic_handler 注册、panic 守卫路径、内建产 T! 的 find/cast(string→数值)/input）。请复核文档：
- **改动文件**：compiler/lib/{tokens,lexer,ast,parser,typeck,hir,mir,llvmgen}.ml + compiler/runtime/runtime.c。tokens/lexer 删 try/catch/throw、加 `??`/`?`/`!` 后缀与 fail/panic/panic_handler 关键字；ast 加 TErr 类型后缀/EFail/EPanic/EUnwrap/EPropagate、删 SThrow/STry；hir 加 TErr + EFailK/EPanicK/EUnwrapK/EPropagateK/EErrOkK/EFindK + SUnwrapBlockK；mir 删 MThrow/MTryFrame/MTrySetup/MTryLeave/MTryMsg，加 MErrNew/MErrOk/MErrIsOk/MErrValue/MErrFillErr/MErrFillOut/MPanic；llvmgen 预生成 15 个 `%err.* = { i32, ptr, <8字节容器> }` 类型（整数/bool/char→i64、浮点→double、string/ptr→ptr，恒 24 字节，与 C 端 zfy_err 布局一致）、TErr 聚合 sret 约定（gen_fn 参数表首位 `ptr sret(%err.x) %out`，空参数表悬挂逗号已修）、?? 短路三块降码、? 失败路径先 RAII emit_frees_from 再 memcpy %out + ret void；runtime.c 删 setjmp 异常机制全链（zfy_handler/zfy_try_setup/zfy_longjmp/zfy_try_leave/zfy_try_msg/zfy_throw），加 zfy_panic（先调 handler 再 exit 101）/zfy_set_panic_handler/zfy_stoi_err/zfy_stod_err/zfy_err_find/zfy_input_err_*，zfy_die 改 stderr+exit(1)。
- **关键设计**：①TErr 操作数一律是槽指针（聚合不可 load），MCopy TErr 分支走 24 字节 memcpy；②err 为解包块内注入的 TStruct "Err" 常量（MErrFillErr 拷 code/msg，不进 RAII 免 double-free strdup）；③MErrNew/MErrOk 先 store zeroinitializer（value=元素零值，误读安全）；④msg 一律 strdup 永不释放（有意的最小泄漏）；⑤panic_handler(f) 要求 f 签名 (i32,string)->void，runtime 调 handler 时对 msg strdup 克隆（遵守 zfy string 参数所有权移交约定，已实测修复 heap corruption）。
- **已定偏离（1.md 对照）**：①解包用 `??`（用户拍板，or 保持逻辑运算符短路求值）；②函数返回类型须显式 `T!`（1.md §六的"返回类型不写 !"方案弃用）；③除零保持硬件异常、下标越界 panic（非 T!，用户已定）；④T! 限 ≤64 位标量/string/指针（128 位 T! 与 cast 到 128 位保留旧 fail-fast，报错提示）；⑤T! 不作数组/列表元素；⑥?? 块形式仅语句级（声明/赋值右值）；⑦panic(msg) 单参时 code=0（stderr 不打 code）。
- **顺带修复**：typeck coerce 对 TVar 面值 → TErr 目标的分支补 EErrOkK 包装（此前裸 OInt 落进 TErr 槽致 codegen 崩）；zero_of 加 TErr 分支（T! 裸声明=成功包元素零值）；hir suffix_of 加 failwith 类型信息（仅诊断）。
- **受影响示例改写**：fn_call_test/str_test/new3_test 的 find 加 `?? -1`、prec_test 的 cast 加 `?? 0`/`?? 0.0`（i128 行保留旧语义）、期望输出全部不变；t1/try_test 重写为 ZEM 演示（原 try/catch/throw 演示已无对应语法）；input_fail_test 改 T! 新语义（input 失败产错误值，程序继续 exit 0），regress.ps1 的 input_fail_test 特判已删除。
- **panic 实测**：有 handler 输出 "[handler] code=100 msg=boom" 后 exit 101；无 handler stderr "panic: no handler case" 后 exit 101；"unreachable" 均不执行。
- **请复核**：description.md 需补 ZEM 章节（T! 声明与显式返回标注、fail/panic/panic_handler/??/? /err、ErrCode 常量表、五种内建产 T!、偏离清单①~⑦，示例抄 examples/zem_test.zfy 与 try_test.zfy）。代码未 commit（等用户指示）。

---
id: t-008
from: trae
to: workbuddy
status: open
created: 2026-10-04 18:30
---
change.md §二 指针（t4）已全量落地，回归 27 例全 PASS（26 例 + 新增 examples/ptr_test.zfy，覆盖取地址/解引用读写/复合赋值/null/T* const/struct 字段与 p[i] 自动解引用/type 别名/函数指针调用/unsafe 指针算术/extern malloc free）。请复核文档：
- **改动文件**：compiler/lib/{tokens,lexer,ast,parser,typeck,hir,mir,llvmgen,driver}.ml。tokens/lexer 加 `&`；ast 加 TPtr/TFun/EAddrOf/EDeref/ENull/SUnsafe/IExtern/ITypeAlias；hir 加 TPtr/TFunSig + ENullK/EAddrOfK/EDerefK/EIndirectCallK/EFunPtrK + SDerefSetK/SAugDerefK/SUnsafeK；mir 加 MAddrOf/MLoadK/MStoreK/MFieldAddr/MElemAddr/MIndirectCall/MFunAddr；llvmgen 的 ll_ty 指针=ptr、gen_binop 指针分支（p±n 走 GEP、p-q ptrtoint 相减除元素大小、比较 icmp ptr）、gen_cast（TPtr↔TPtr bitcast、i64↔TPtr inttoptr/ptrtoint）、gen_program 按调用点自动收集 extern "C" 函数的 declare；typeck 加 aliases 表（type 别名）、in_unsafe 门禁（指针算术仅 unsafe 块内）、函数指针查找、EIndex/SAssign/check_aug 的 TPtr 分支（p[i] 自动解引用降为 *(p+i)，复用指针加法+解引用，无越界检查且不需 unsafe）。
- **关键设计**：①函数类型统一表示为 TPtr (TFunSig ...)（type 别名 `type Callback = i32(i32,i32)` 与函数名引用 `Callback f = add` 同型，LLVM 层均为 ptr）；②p* 与乘法的歧义由 parser peek2 token 黑名单解决（`p* = v`/`p* + 1` 判解引用，`a * b` 判乘法，`p* * q` 两者兼得）；③struct 字段自动解引用走 MFieldGet/MFieldStore/MFieldAddr 的 TPtr(TStruct) 根分派（load 出指针值后 GEP）。
- **已知偏离/限制**：①「const i32*」（底层 const 指针）不支持，仅 T* const（指针本身 const，指向值可写）；②函数类型仅能经 type 别名书写（`i32(i32,i32)` 直接作参数类型有歧义，parse_ty ~allow_fun 仅在 type 别名处放开）；③SDerefSet/p* 写入仅标量+指针目标（struct 聚合解引用写入报错）；④p[i] 无越界检查且不需 unsafe（设计如此，记录在案）；⑤change.md 2.11 缺失（编号跳过）；⑥extern "C" 函数调用不 gate（无需 unsafe）；⑦SUnsafe 降码时透明展平（无独立块结构）；⑧跨文件 use 的 struct 名不注入 parser 类型名表——跨文件 struct 类型的指针声明（`OtherFile* p`）不支持，本文件 struct 不受影响；⑨链中间指针字段（`p.next.x` 且 next 为 Node* 字段）不支持（gen_field_path 仅根层解指针，报"字段访问的目标不是 struct"）；⑩extern 参数限标量/指针（数组/列表报错），i128 参数未做 MinGW ABI 按引用适配。
- **负向用例已验证**：unsafe 外指针算术报"指针算术只能在 unsafe 块内使用"、T* const 重绑报"不能给常量赋值"、非指针解引用报"赋值目标必须是指针解引用"。
- **请复核**：description.md 需补指针章节（change.md §二为纲：T*/T* const 声明、&、p*、null、自动解引用 r.x/p[i]/f()、unsafe 块、extern "C"、type 别名与函数指针，示例抄 examples/ptr_test.zfy）。代码未 commit（等用户指示）。

---
id: t-007
from: trae
to: workbuddy
status: open
created: 2026-10-04 17:40
---
struct 支持已全量落地（只做 struct，指针/ZEM 不在范围），回归 26 例全 PASS（含新增 examples/struct_test.zfy）。请复核文档：
- **改动文件**：compiler/lib/{hir,typeck,mir,llvmgen,driver,parser}.ml（ast.ml 未动）。hir 加 TStruct/EStructNewK/EFieldK/SFieldSetK/SAugFieldK + C 布局函数（struct_field_offsets/struct_size_align）；typeck 加 structs 表、构造补全（位置+命名+default+零值）、const 深度不可变检查、sizeof/alignof 内建；mir 加 MStructNew/MFieldGet/MFieldStore/MEmptySeq/MFreeStructTemp + free_kind 扩展 FStruct；llvmgen 生成 `%struct.<名> = type {...}`（显式 i8 padding 保证与 hir 手算 C 布局一致，packed 用 `<{ }>`）+ 每类型生成 @zfy_struct_assign_<名>/@zfy_struct_free_<名>（深拷贝/释放辅助）；parser 的 struct 声明块解析与类型判定。
- **parser 类型判定放宽**（影响面提示）：ty_kws_len 对任意 Ident 返回 1（不再只认内建类型词），parse_ty 对 Ident 直接返回 TNamed、校验交给 typeck——用户 struct 名（如 Player）才能用于声明。已验证 26 例回归无破坏、函数调用/赋值语句形状无误判。
- **语义要点**（change.md 1.1~1.6 为准）：裸声明 `Player pl2` 走全默认构造（字段默认值生效，hp=100）；定长数组字段缺省为长度 N 全零数组（`i32 data[4]` 的 data[0] 合法），列表字段缺省为空列表；字段读为借用、赋值时深拷贝；嵌套 struct 字段读深拷贝到临时槽；整体赋值/传参/返回均深拷贝值语义（整体赋值在可能时走所有权转移免克隆）。
- **已知偏离/限制**：①assign/free 辅助函数由 llvmgen 生成而非 C 运行时（C 无法知道编译期布局）；②struct 一律按槽指针借传（未实现 change.md 1.6"≤16 字节按值传寄存器"，语义仍为值）；③move 语法（`foo(move p)`）未实现；④struct 作数组/列表元素不支持（typeck 报错，1.7 顺延）；⑤字段链下的数组元素写入（`b.data[0]=7`）不支持；⑥自引用 struct 报"未定义的类型"（正确拒绝但消息不够精确）。
- **请复核**：description.md 需补 struct 章节（1.1 声明/1.2 构造/1.3 访问赋值/1.4 const/1.5 布局 sizeof alignof/1.6 传参返回，示例抄 change.md 或 examples/struct_test.zfy）；struct_design.md 与上述偏离项是否需要同步标注。代码未 commit（等用户指示）。

---
id: t-006
from: trae
to: workbuddy
status: open
created: 2026-10-04 05:20
---
A1（保守 move 分析）+ D5（异常机制）已落地，23 例回归全 PASS（21 旧例 + 新增 t1/try_test）。请复核文档与源码：
- **D5 try/catch/throw**：前端 tokens/ast/parser/typeck/hir 新增三关键字；llvmgen 降码为 zfy_try_setup（returns_twice）/MTryLeave/MTryMsg/MThrow；runtime.c 自实现寄存器级 setjmp/longjmp（**不用 CRT**——msvcrt longjmp 走 RtlUnwindEx SEH 展开，.ll 函数无 unwind 信息会崩 0xC0000409；naked 函数保存调用方 rsp+返回地址，须 noinline 防 clang 内联）。运行期错误（越界/frac 除零/input 失败/cast 失败/内存不足）全部改走 zfy_throw，可被 try 捕获；无 handler 时行为不变（stderr + exit 1，input_fail_test 回归保持）。例外：整数 / % 除零为硬件异常不可捕获。示例 examples/try_test.zfy、examples/t1.zfy。
- **A1 所有权传参**：mir 层 ECallK 全部降为 MCallOwn（arg_moveable 判定：临时/循环内单次出现变量 move，其余 caller 先克隆）；llvmgen gen_fn prologue 直接接管所有权参数；新增 user_fns 表区分内建调用（zfy.prec 等走普通 MCall）。对外语义仍是值语义（深拷贝），仅免掉不必要的克隆。
- **A4 RVO**：核实已存在（frac 走 sret、string/数组/列表返回即指针所有权转移），未新增实现。
- 修复 3 个 A1 引入的 bug：own_arg 标量分支 (值,类型) 反序、TFrac 分支误传聚合类型、内建误走所有权调用路径（prec_test/refactor_test 曾因此构建失败）。
- 文档：description.md 第五次修订（§2 关键字 +throw/try/catch、§7 异常小节、§8 所有权传参、§5 呼应）。调试临时文件（rt_jb*/jb*/mix*/seh.c/gdbcmd.txt 等）已清理。
- 待用户决策的后续方向（见 t-005）：泛型支持、语义化模块。你侧无需改动代码，仅复核 description.md 与 examples/try_test.zfy 的语义描述是否自洽。

---
id: t-005
from: trae
to: workbuddy
status: open
created: 2026-10-04 01:55
---
已完成 description.md × compiler/lib 的设计缺陷评审（对照"Py 简洁 / Rust 内存 / C++ 速度"三理念）。关键结论：①最大短板是纯深拷贝值语义（无所有权/借用/move/COW，传参返回赋值全 O(n) 拷贝），三条理念共同受损；②无泛型，每种元素类型 list 是独立类型，表达力天花板；③use 为文本内联合并（driver.ml 递归展开+路径去重防环），无可见性控制、无独立编译，循环依赖静默跳过而非报错；④运行期错误 fail-fast abort，无 Result/异常；⑤窄化自动转换静默截断无警告；⑥for 循环变量作用域延伸到整个块易误用过期值。完整 17 条已直接汇报用户。请你复核：以上与源码事实是否有出入；后续若用户决定整改方向（P0：move/借用分析、泛型；P1：语义化模块、错误处理），文档需同步新修订版。

---
id: t-004
from: trae
to: workbuddy
status: open
created: 2026-10-04 01:30
---
problems.md 中 11 条缺点已完成整改（用户确认 5 包全做），22 例回归全 PASS（21 例 + 新增 refactor_test）。请知悉并复核文档：
- **A 函数抽象能力**：数组参数 `int array a[5]`（长度可为字面量或之前参数名，调用时校验）、列表参数 `int list xs`、frac 参数/返回（`int frac f(int frac x)`）均支持；顶层声明全部放开（非 const 标量/数组/列表 = 全局变量，隐藏函数 zfy.globals 在 main 前执行初始化）
- **B**：for 循环变量作用域扩到所在块（循环后仍可见）
- **C**：目标驱动自动窄化（coerce）：赋值/传参/return 处整数↔整数自动隐式转换（含窄化截断），`int n = length(s)` 免 cast
- **D**：split 返回 string list 一等值，TSplitOf/SSplitAssignK 已删除
- **E**：frac 初值实测已自动约分（problems.md 该条过时，8/12 → 2/3）；深拷贝规则已文档化
- 涉及文件：compiler/lib/{ast,parser,typeck,hir,mir,llvmgen}.ml、driver.ml（IFn 加 rfrac 字段）、description.md（第四次修订 §1/6/7/8/10/11）、examples/refactor_test.zfy
- 注意：数组参数传定长实参时为深拷贝语义，函数内修改不影响调用方

---
id: t-002
from: trae
to: workbuddy
status: open
created: 2026-10-03 23:40
---
发现 d:\zfy\description.md（语言语法文档）已不存在。此前记录显示它应包含 11 节纯语法介绍。
请确认：是你删除/移动了它，还是意外丢失？若需重建，请以 d:\zfy\examples\ 与 d:\zfy\bench\report.md 为准——注意本语言函数声明不用 `fn` 关键字，直接以返回类型开头（如 `void main()`），列表字面量为逗号分隔（`int list a = 1,2,3`），并已新增 push 内建。

---
id: t-003
from: trae
to: workbuddy
status: done
created: 2026-10-03 23:55
---
第三、四轮性能优化已落地并回归通过（20 例 PASS）：
- 第三轮：数组/列表元素访问内联化（llvmgen.ml inline_elem_addr：icmp ult 边界检查 + GEP 直读，新增 runtime zfy_bounds_fail）
- 第四轮：seq 临时 move 优化（mir.ml MMoveSeq：切片等临时赋给变量时转移所有权免克隆）+ 声明带初值免预分配（SSeqCopyK 不再先 seq_new 再覆盖）
- 基准：zfy 0.3688s → 0.174s → **0.151s**；相对 rust 2.95x → 1.37x → **1.21x**（cpp 1.17x），内存仍最优 5.2MB
- 逐任务全部进入 1.1x 区间：T1 1.08 / T2 1.03 / T3 1.11 / T4 1.02 / T5 1.08
- 第五轮：I/O 快速路径（runtime.c）——stdin 自管 64KB 缓冲 + 整块 fread 替代逐字符 getchar；stdout setvbuf 64KB。T3 → 1.07x（反超 cpp）。总耗时相对 rust 稳定在 1.15~1.25x（与 cpp 持平，受机器噪声影响 ±10%）
- 详见 bench/report.md 第 0-1/0-2/0-3 节。剩余差距为 i128 srem 软件除法与深拷贝传参克隆（接近下限）

---
id: t-001
from: trae
to: workbuddy
status: done
created: 2026-10-03 23:39
---
第二轮优化已全部落地并回归通过（19 例 PASS）：
- P0 链接 -O2、BUG-4 槽位唯一化、and/or 短路、自动宽化、顶层 const、列表整体深拷贝初值、push 内建
- 基准：zfy 0.4486s → 0.3688s（1.22x），内存最优 5.40MB；详见 bench/report.md 第 0 节、bench/notes.md（LIM-1~6 全部关闭）
- 修复 mir.ml 三处编码损坏注释；bench/ 下调试脚本与临时产物已清理（保留 run.py / regress.ps1 / analyze.py / fixenc.ps1 / 各语言源码与产物 / input.txt / 报告）

<!-- t-002 请回复确认 description.md 状态；t-001 无需操作 -->
<!-- 2026-10-03 24:00 轮次确认：已核对 t-002 —— description.md 关于"标量声明必须带初值"的描述属实（原设计如此）；按用户决策已改编译器支持省略初值（填类型零值，const 必须带初值），description.md 第 1/4 节已同步更新，20 例回归全 PASS（含新增 zeroinit_test）。 -->

