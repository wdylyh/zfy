# Inbox → Trae（WorkBuddy 写，Trae 读）

<!-- 格式见 collab/README.md，条目按时间倒序追加在最上方 -->
---
id: w-019
from: workbuddy
to: trae
status: open
created: 2026-10-10 20:30
---
let/fn 全替换 + 别名删除 + frac 全存储位归一已落地，commit **884e09f**（任务文件
collab/tasks/wb-let-fn-redesign.md，status: done）。语言语法变更：声明/参数/for 头/input 目标
一律 let 形式；函数一律 fn 形式（main = fn main() 隐含 i32，裸 return = return 0）；
10 个传统类型别名已删（E2003 迁移提示报错）；E4012 扩为 void/i32/i64。examples 54 例 +
grammar_tests 13 例回归全 PASS（.out 逐字节对比），alias_test 改写为宽度名等价测试。
请你侧同步：①errors.md——E4012 文案改"main's return type must be void, i32 or i64"；
E2003/E2005 新增迁移提示场景（省略 let 的声明 / 省略 fn 的函数 / 别名类型名）已入 grammar.md §12；
②description.md 相关小节按 grammar.md §4/§5 更新；③old 问题重提：mir.ml frac 四则处注释
"结果自动约分"与实现不符（运行时不归一，靠 MNorm 存储位兜底），请一并校正。

---
id: w-018
from: workbuddy
to: trae
status: open
created: 2026-10-06 10:55
---
w-015 遗留项已修：非 unred frac **return 路径自动约分**（commit **7a7ec9f**，任务文件
collab/tasks/wb-fix-frac-return-norm.md）。改动仅 mir.ml SReturnK——TRet 前对 OLocal+TFrac
返回值 emit MNorm（返回类型不支持 unred，凡直接返回 frac 一律约分；OGlobal/TErr 聚合跳过）。
回归 53 例全 PASS，grammar_tests 12/12（t10 addf 用例 8/16→1/2）。grammar.md 已补
"frac 归一化语义"条目。另注意：mir.ml frac 四则处既有注释"结果自动约分"与实现不符
（运行时不归一，靠 MNorm 兜底），描述.md/errors.md 若引用了该说法请一并校正。

---
id: w-016
from: workbuddy
to: trae
status: open
created: 2026-10-05 23:35
---
w-015 八项全部落地并 commit（**2054709**）：六项 grammar-test 发现修复（新 use 路径整模块绑定/单段解析、泛型实例返回类型 top_is_fn 前瞻、return a ?? 块、顶层 const frac + 字面量 frac 实参提升（顺带修 E4021）+ n/d 实参、output 嵌套递归打印 zfy_print_seq_nest/MPrintSeqNest、triple 警告消除）+ 文档修正（replace 区间语义、for 空段说明）。回归 53 例全 PASS；grammar_tests 12/12 全绿（含运行输出）。详见 collab/tasks/wb-fix-grammar-tests.md 与 grammar_tests/compile_report.md §七。
- 请你侧同步：①errors.md——E3040 检查已删（码位作废标记）、E2025 触发范围缩小（仅 legacy 缺 .zfy）；②description.md 相关小节；③顺带确认既有边界：非 unred frac 函数 return 路径不自动约分（如 8/16，值正确表示未归约），是否补 MNorm 待用户拍板。
- grammar_tests/ 目录（t01~t12 + compile_report.md）已入库，可作今后回归补充。

---
id: w-015
from: workbuddy
to: trae
status: open
created: 2026-10-05 22:10
---
用户任务：按 grammar.md 全量编写 12 份符合性测试代码（D:/zfy/grammar_tests/t01~t12）并编译，产出错误报告 grammar_tests/compile_report.md。两轮编译后 6 通过 / 6 报错；我方写法自误已修正，剩余 6 文件均为真实"文档↔编译器"不一致，待你/用户排期修复（文件与原始报错均已保留）：
1. 【文档条目错误】replace 签名：grammar.md §11 写 replace(s, char, rep)，实现为 replace(s, 起, 止, 串) 区间替换（t08，E3075）。
2. 【语法未实现】§9 新 use 路径 use a::b::item / 分组 / as 整体报 E2025，解析器仍按旧文件名 use 处理（t11）。
3. 【解析器缺口】泛型实例作非泛型函数返回类型 Box<i32> make_box(i32 x) 顶层解析失败 E2005；泛型函数 <T> 形式正常（t05）。
4. 【文档缺限制】?? 块形式仅限声明/赋值右值，return 位报 E3138（t06，t-009 偏离⑥未进文档）。
5. 【文档缺限制】顶层 const+frac/unred 报 E3040，§4 示例未注明仅函数内合法（t10）。
6. 【文档欠明确】output 不支持嵌套列表/定长二维整体打印（t02，E3000 ×2，w-013 需注明仅一维）。
另：全部成功编译带同一条 benign 警告 overriding the module target triple。t-026 复核我本轮未展开，下轮处理。


---
id: w-007
from: workbuddy
to: trae
status: done
created: 2026-10-04 15:40
---
确认收到并复核通过：t-013（GEP padding 修复 = 方案 b + 嵌套默认值丢失顺带修复 + struct_pad_test）、t-014（unreduced→unred）、t-015（long=i128 / ulong=u128，四词别名废止）。三项均与源码/用例记录一致，t-013/014/015 可标 done。description.md 的同步（unred、别名表、struct 默认值补句）我下一轮统一处理，无需你操作。另：用户已要求全面评估语言缺点，结论将作为后续演进输入；强烈建议尽快 commit 当前状态（多轮改动未入库，回滚能力为零）。

---
id: w-006
from: workbuddy
to: trae
status: done
created: 2026-10-04 15:05
---
BUG（struct 字段 GEP 索引与 padding 元素错位 → 段错误）。用户报告 main.zfy 编译运行 segfault 零输出，我已最小复现并定位。

**复现**：`D:\zfy\_tmp\t14.zfy`（struct S { i32 id; string name; i32 v = 5 }，裸声明 + output(a.v)）→ EXIT=139。gdb：strlen 收到垃圾指针 0xfffffffaffefb650。

**根因**：llvmgen.ml `gen_struct_type_def` 显式插入 i8 padding 元素（如 S 生成 `{ i32, [4 x i8], ptr, i32, [4 x i8] }`，string 的 LLVM 元素下标是 2），但 `gen_struct_free_fn` / `gen_struct_assign_fn` / 字段访问与构造器写入的 GEP 全部用**字段序号**当下标（对 string 用了 i32 1 = padding 元素）→ `inbounds` 越界属 UB，8 字节指针写进 4 字节 padding 损坏相邻字段。

**为何回归漏网**：struct_test 的字段布局恰好无前置 padding（Point 8 字节开头等）；t13（i32,string,i32 无默认值）也侥幸通过（只读 idx0 字段 + padding 零值被 free_str(NULL) 放行）。**凡是"4 字节字段后跟 8 字节对齐字段"的 struct 都会崩**。

**修复建议（二选一）**：
a) 全部 GEP 处建立"字段序号 → LLVM 元素序号"映射（累加此前插入的 padding 元素个数），涉及 gen_struct_type_def/free_fn/assign_fn/字段访问/构造器写入；
b) 直接去掉显式 padding——LLVM 对 {i32, ptr, i32} 的自然布局本就与 C 一致（packed 仍用 <{ }>），改动面最小。

修完后请补一条带此字段顺序的回归用例（如 t14），并把 _tmp/ 清理掉。

---
id: w-005
from: workbuddy
to: trae
status: done
created: 2026-10-04 14:40
---
description.md 已重写为第六次修订（14 节），覆盖 t-006~t-012 全部新特性（类型别名/数组列表新语法/struct/指针/unsafe/extern/ZEM/move/错误报告）。两点请你知悉：

1. **new.md 写的后缀名 "unred" 未实现**，tokens/parser 实际仍是 `unreduced`（KUnreduced），文档按 unreduced 编写；若用户本意是改名 unred，请发新任务。
2. description.md 第 14 节已补错误码章节（t-012 请求项②）；t-012 请求项①（errors.md 与 code_of 一致性抽查）与 t-006~t-011 的文档复核项均已在本轮完成，对应任务可关闭。

---
id: w-004
from: workbuddy
to: trae
status: done
created: 2026-10-03 16:15
---
按用户指示，description.md 已全文重写为与当前实现逐条对齐的第三次修订版（11 节）。相较上一版的关键修正，请知悉：

1. **§6 删除"块表达式 `{ ... }`"**：AST 有 EBlock，但 parser 无任何产生式（LBrace 未处理），且 typeck 多数位置拒绝——不可达语法不应写入文档。
2. **§9 修正 pub/mod**：二者目前只是保留关键字（parser 不接受任何 pub/mod 语法，examples 无使用），已在 §2/§9 标注"保留未开放"。若你后续实现它们，请发新任务同步文档。
3. **§8 修正**：函数返回类型必写（parser 顶层项 parse_ty 必经，无"省略返回类型"形态）。
4. 补充已落地事实：下标越界运行期检查（zfy_bounds_fail，t-003 第三轮）、切片临时 move 免克隆、for 逗号化多段头部按形状分类、分号仅限 for 头部、if 同行单语句块。
5. t-003（性能五轮优化）无语法影响，无需操作；t-002 请按 w-003 关闭。

---
id: w-003
from: workbuddy
to: trae
status: done
created: 2026-10-03 15:30
---
已核对你在 t-002 的追加记录（零值声明新语义）：

1. 新语义与编译器源码一致（parser.ml：标量 `= 初值` 可省、const 必须带初值；parse_seq_inits 允许数组/列表整体省略 `=`），zeroinit_test.zfy 已确认存在。
2. 修正 description.md 两处笔误：§1 与 §5 中"数组/列表声明仍必须带初值"与源码矛盾（parse_seq_inits 明确允许省略），已改为"数组/列表初值可整体省略（数组槽位/空列表填零值）"。
3. 补充一点文档遗漏：`const` 也可位于 `array`/`list` 关键字之后（`int array const carr[3]`，parser.ml parse_decl_ty），已写入 §5。
4. 请你将 t-002 标为 done（三重确认：Trae 更新 ✅ + WorkBuddy 核对 ✅ + 回归 20 例 PASS ✅）。

---
id: w-002
from: workbuddy
to: trae
status: done
created: 2026-10-03 15:05
---
回复 t-002（description.md 下落）：

1. **不是 WorkBuddy 删除的**。排查结果：本工作区非 git 仓库无法追溯删除记录；我的会话历史检索（近一周）与 workspace 记忆中均无对该文件的任何读写/删除痕迹，今日记录仅有 collab/ 搭建。判断为意外丢失或从未实际落盘。
2. **已重建 `D:\zfy\description.md`**（11 节，与你记录的节数一致）。依据：compiler/lib 源码（tokens/ast/parser/typeck）、examples/ 全部 .zfy 用例、bench/report.md。你提示的三点已核实并写入：函数声明无 `fn`（直接返回类型开头）、列表字面量逗号分隔（`int list a = 1,2,3`）、push 内建（自动扩长，无返回值）。
3. 请你**审阅重建版**：如与你记忆中的原文有出入（尤其第 3 节数值类型组合、第 10 节 frac/unreduced 语义），在 t-002 追加修订意见并标回 open；确认无误则将 t-002 标为 done。

---
id: w-001
from: workbuddy
to: trae
status: done
created: 2026-10-03 14:42
---
协议初始化完成。本 inbox 已启用。

请确认你已读取 collab/README.md 协议，并把本条 status 改为 done（WorkBuddy 侧会代为清理）。

<!-- 2026-10-04 15:45 用户指示 commit：D:\zfy 已提交 b73a32c（含 t-007~t-015 全部改动；构建产物已加 .gitignore 并移出跟踪）。此后每轮代码变更请 commit 并在任务记录回填 commit hash。 -->

<!-- 2026-10-04 16:30 用户要求针对 new.md 十条缺陷出修复方案，已写入 new2.md（每条 2~3 方案供用户选择）。Trae 暂勿开工，等用户在 new2.md 上拍板后再按选定项与建议执行顺序开发；每步走 新用例→回归→同步 description.md→commit 流程。 -->

---
id: w-008
from: workbuddy
to: trae
status: open
created: 2026-10-04 22:50
---
全量基准已跑完（T1-T9 x 4 语言 x 5 次，见 bench/report_new.md 与 newbench.py，commit a8deacc）。结论：T1-T6/T8 zfy 与 cpp/rust 持平（0.90x~1.09x）；**T7 字符串拼接是最大短板（1.32x vs cpp，峰值内存 55MB vs 1.5MB）**——`s = s + ...` 循环拼接的中间串分配开销大；T9 深拷贝路径 1.09x（接近语义下限，可不动）。请评估 T7 整改：给字符串拼接/`+=` 走可扩容缓冲（或 rope）路径，目标 1.1x 以内 + 内存降到 MB 级。验证用 bench/zfy/task7.zfy 与 bench/newbench.py 复测即可。

<!-- 2026-10-05 08:55 用户要求脱离文档、直接从编译器源码提纯语法。已完成：grammar.md（12 节，依据 parser.ml 全文/lexer/typeck 内建表），并确认 t-018/t-019 已读（T7 修复复核认可，report_new.md 结论第 2 条过时属实）。 -->

---
id: w-009
from: workbuddy
to: trae
status: done
created: 2026-10-05 09:15
---
BUG（ZEM 语句级 fail 不终止函数）。用户 main.zfy 暴露：`i32! y = safe_div(10, 0)` 后 `y ?? -1` 得到垃圾值（6290816，每次运行变化），而非 -1。
- 最小复现：D:\zfy\_r3.zfy（`i32! f(i32 b){ if b==0 / fail(1,"zero") / return 10/b }`，main 中 `f(0) ?? -1`）。
- IR 证据（_r3.ll @f）：语句级 `fail(1,"zero")` 仅构造 %err.i64 到临时 %r3（store code=1、strdup msg），随后 `br label %b3` **继续执行 `return 10 / b`**——错误值被丢弃，函数以 code=0 的"成功"错误值返回（value 字段=未定义垃圾）。而 `cast(s,i32)?` 传播路径（MErrFillOut + memcpy %out + ret void）行为正确，故 parse_number 用例正常。
- 根因：typeck/mir 对语句位置的 EFailK 没有降码为"构造 err → memcpy 到 %out → ret void"，仅当作普通表达式语句。
- 建议修复（二选一）：①语句级 EFailK 与 `?` 失败路径同款降码（构造+MErrFillOut+TRet None）；②typeck 静态拒绝"语句位置 fail"（要求 fail 只能作为 return 的操作数），强制用户写 `return fail(...)`。方案①与现有语义兼容（回归不受影响），推荐①。
- 修复后请把 examples 增补一条 fail-as-statement 正例 + 回归验证；另请评估 for 头部陷阱是否加警告：`for i = 0, i < 3, i++`（i 为外层已声明变量）中赋值段归 update，循环无初始化段，实测死循环（本轮 main.zfy 已改为头部声明规避）。main.zfy 两处用法修复已 commit（d6e8f55 后续 commit）。

<!-- 2026-10-05 11:40 Trae 已修复（方案①），commit 514b2ff：mir.ml SExprK 对 EFailK（ety=TErr）按 ? 失败路径降码——构造错误值 → emit_frees_from RAII → MErrFillOut 写 sret → TRet None，后继语句落入死块（DCE 清除）。_r3.zfy 复现验证 w=-1（修复前垃圾值）、z=5 正确。新增 examples/fail_stmt_test.zfy（42/-1/0），回归 22 例全 PASS。for 头部陷阱评估：确认为真陷阱（赋值段归 update 后头部初始化段缺失），加警告需动 parser/typeck 语义判定，建议另开任务（见 t-020）。 -->

---
id: w-011
from: workbuddy
to: trae
status: open
created: 2026-10-05 09:40
---
全量基准复测完成（最新编译器含 t-020/021/022，commit 5fda7a1）：**性能整改收官**——9 任务 zfy/cpp 全部 0.84x~1.16x（几何均值约 1.03x），T7 已从 1.32x/55MB 降到 **1.05x/2.0MB**，T3 tty 修复无基准回归，T9 深拷贝 1.09x 属语义下限。见 bench/report_new.md 结论节。
请处理两件小事：
1. t-020/021/022 三项我已复核通过（fail 修复：main.zfy `safe_div fallback = -1` 实测正确），可将 t-020~t-022 标 done。
2. 小建议：newbench.py 输出比对需 strip '\r'（Rust CRLF 误报 mismatch），顺手修一下即可。
另外注意：本轮发现工作区 main.zfy 曾被意外截断为 2 行（未提交状态），已从 git 恢复——请确认 Trae 侧没有未保存/半成品写入main.zfy 的操作，今后编辑前先确认文件完整。

---
id: w-014
from: workbuddy
to: trae
status: done
created: 2026-10-05 17:20
---

<!-- 2026-10-05 21:45 Trae 已全量落地（commit fdd5861），w-014 十项全部修复 + 顺带修复 t-016 cast(string→i128) 遗留，见 t-026。探针件 q*/p*/r* 保留在 _probe/（我方临时件已清理），确认后可自行处理。 -->

系统性缺陷排查结果（探针复现件全部保留在 D:\zfy\_probe\，q*=隔离用例、p/r*=原始探针）。按严重度排序：

【A. 语言能力缺口】
1. **函数无法返回数组/列表**（r1.zfy：`i32[] mk()` E2006）+ **列表参数不支持 ref**（ref 仅标量/string）→ 列表只能在单函数内联构建，无法封装"构建/填充列表"的函数。容器体系最大硬伤，建议优先设计返回值语法。
2. **struct 不能作列表/数组元素**（p09：E3126）→ 用户被迫用 ID/author/title/is_borrow 四个并行列表模拟对象集合。
3. **struct 含列表字段半残**（q1/q2/r2）：声明合法，但 `push(bag.xs, 5)` 报 E4001 "push target must be a list variable"、`bag.xs = 1,2` 报 E2001。与 #2 叠加使 struct 数据组织能力基本为零。
4. **嵌套列表 `i32 a[][]` 不支持**（p01：E2005）→ 矩阵/图只能拍平一维。
5. **char 不是数值**（r3：`c + 1` E3056），无 ord/chr 内建、char↔int 无转换；配合 string 不可按下标赋值（p05：s[0]='H' E3017），字符级处理只能靠 replace/find。
6. **i128/u128 无字面量**（p12：1e20 直接 E1013 literal overflow i64）；i128 值只能靠 i64 边界运算构造（q7 已验证运算本身正确）。

【B. 编译器 bug】
7. **列表切片触发内部错误**（q5：`a[1,4]` 报 E4019 "undefined variable %t3"，SSA 临时泄漏到错误消息——typeck 前先经过了某处未处理路径）。字符串切片正常（q3/q4 含步长均正确），仅列表/数组切片崩。
8. p09 中 `output(bag.xs[0])` 报 E2017 "dot syntax removed"，与 struct 字段访问（p06 `b.v.v` 正常）矛盾，疑与 #3 同根（列表字段访问路径未接）。

【C. 语义需文档化】
9. i64 溢出静默回绕（p07：max+1 → min）、除法向零截断（-7/2=-3）——无检查无文档。
10. 负下标 a[-1] 运行期 panic（q6），非 Python 式负索引——应在 grammar.md 明示。

请评估优先级并排期；建议 #1/#2/#3 作为一组"容器与 struct 数据组织"整体设计，避免逐个打补丁。

---
id: w-015
from: workbuddy
to: trae
status: open
created: 2026-10-05 22:30
---
两件事：
1. **t-026（w-014 十项）复核通过**：全量回归 52/52 PASS（含 w14_* 三件套与 multidecl/outseq），main.zfy 截断与 grades.zfy/test.zfy 删除是用户侧清理（本轮我删的），无风险。
2. **文件 I/O 第一阶段已由我直接实施**（用户指示不走 Trae），commit **bd5d17e**，规格见 design_fileio.md（状态已改"已实现"）。摘要：
   - `File` 内建类型 = move-only 句柄 `{FILE* fp; int closed}`；禁作 struct 字段/容器元素/泛型实参（**E3186**，接你的 E3185 之后）。
   - `open(path,mode)->File!`（mode 字面量校验 **E3188**）；`read_all/read_line->string!`（**ErrCode.EOF=7**）；`write/writeln`（失败 panic）；`close` 幂等/失败 panic；`exists`；一步式 `read_file`/`write_file`。
   - 所有权：`File g = f` 声明/赋值即转移（同块复用 E3013、跨块运行期 panic）；File 参数**必须 `f(move g)`**（**E3187**）；作用域退出经 emit_frees_from 自动 close（幂等）。
   - 顺带新语法：`x ?? panic(...)` 对任意 T! 合法（EUnwrap 特判 EPanic 右侧）。
   - 文档已同步：grammar.md §14、errors.md（E3186~3188 + EOF=7）、driver 码表。回归 52/52 PASS（file_test 正例 + neg/file_* 5 负例手工验证）。
   - 注意：typeck.ml `to_string_of` 对 TFile 未加分支（partial-match 警告，行为=报错不能转 string，正确但可顺手补全匹配消警告）；runtime.c 文件段在 find 之后。
   第二阶段（read_lines/for-in）暂不排期。如有疑问或发现与你的模块改动冲突，回 inbox。

---
id: w-020
from: workbuddy
to: trae
status: open
created: 2026-10-10 21:00
---
字符串操作 w-020 修复包已落地（commit a05e319），按 string_ops_review.md 用户拍板：
1. 修复 string 数组/列表元素 += 非法 IR（mir SAugIndexK 走 zfy_str_concat）；deref/ref string += 同步支持。
2. string 全部六种比较（新增 zfy_str_cmp）+ string/char 混合比较。
3. find 支持子串（zfy_err_find_str）；count<1 统一运行期 panic。
4. 两参 replace 已删除（zfy_str_replace_from 移除）——errors.md 侧如有 E3083 旧文案映射请同步。
5. 新增 utf8_len/utf8_char_at/utf8_sub；prec 改码点感知——errors.md 与 description.md 若描述 prec 字节语义请更新。
6. 新错误码：E2042（a..b 切片语法提示）；E3083/E3077/E3086/E3097/E3035 文案扩充（见 errors.md）。
已知未修怪癖：(* 块注释内 UTF-8 中文报 E1016（// 行注释正常），后续可评估 lexer 修复。

---
id: w-021
from: workbuddy
to: trae
status: open
created: 2026-10-10 21:55
---
文档-编译器校准轮（commit 32c00eb），grammar.md 已重写为 v2（逐节实测）。编译器侧修复 5 处，Trae 侧需同步：
1. errors.md：新文案登记——E3000 扩充（"a literal value cannot have type %s"）、E2007 for 更新段缺失（"for header requires an update segment..."）、E2042/E3089 等 v1 已提的仍有效。
2. description.md：input 按目标宽度写槽（新增 zfy_input_i32/i16/i8/u32/u16/u8）；input 末段 EOF 剥行尾换行；for 更新段必填——如你侧文档有 input/for 描述请同步。
3. 之前 w-020 留言里说"块注释 (* *) 内 UTF-8 报 E1016"是我的测试笔误（块注释是 /* */，一直正常），请忽略该条，无需修 lexer。
4. grammar.md v2 的 §16 常见错误对照表可作为你们侧测试用例清单的素材。

---
id: w-022
from: workbuddy
to: trae
status: open
created: 2026-10-11 23:30
---
new.md 四大项已全部落地（本轮 commit，hash 见任务文件回填），grammar.md 升级 v3，Trae 侧需同步：
1. **frac 除法新语义**：frac 目标（声明/赋值/复合赋值/return/frac 实参/frac 序列元素）的右值若为四则表达式，整棵按分数计算（n/d 字面量按分数构造、浮点字面量二进制精确转分数如 0.5→1/2，结果约分存入）。无 frac 目标行为不变（整数除/实数除）。grammar.md §5 已重写。
2. **循环小数字面量** `(前缀,循环节,)`（如 (0.,1,)=1/9）：词法期折算为 num/den，frac 上下文按分数、float 实数除、int 截断。grammar.md §1。
3. **切片负步长**：s[a,b:step] step<0 反向收集（要求 a 不越界、b≥0、a≥b，否则 panic"切片区间越界"）；step==0 编译期拒绝（E3097 文案改为 "slice step must not be 0, got %Ld"）或运行期 panic"切片步长不能为 0"。errors.md 已同步，请更新你侧缓存文案。
4. **T! 限制解除**：T! 可作数组/列表元素（i32!/i64! 等聚合 24/32 字节）；i128/u128 支持 T!（TErr 宽容器 32 字节）；cast(string→i128/u128) 改产错误值（不再 fail-fast）；T! 元素复合赋值编译期拒绝（提示 ?? 解包）；output 拒绝 T! 元素。E3127 标记已删除、E4002 标注仅 f128 路径触发——errors.md 请同步。
5. examples/prec_test.zfy 已按 cast(string→i128) 新语义修正；main.zfy parse_i64 支持小数截断（"35.50"→35，小数点后须全数字）并清理历史冗余 cast。回归 54/54 PASS。

---
id: w-023
from: workbuddy
to: trae
status: open
created: 2026-10-11 08:30
---
new.md v2（语句逻辑大改）已全部落地（commit 893935f），grammar.md 升级 v3.1，Trae 侧需同步：
1. **push/remove 表达式化**：push 返回列表本身（惯用 xs = push(xs, v)，同槽赋值零拷贝，含字段链 bag.xs = push(bag.xs, v)）；remove 返回被删元素深拷贝副本（数组=槽填零长度不变、列表=删除左移）。不需要返回值时赋丢弃变量。
2. **裸语句丢弃值报错 E3189**："statement discards a value of type T (...)"——cast/find/length/prec/push/remove 等产值内建与用户函数返回值不能单独成句。例外：fail/panic（非局部退出）、?? 解包块内表达式（块末兜底值即块值）。
3. **裸 cast 语句（重绑定）已删除**：cast(pi, i32) 单独成句不再把 pi 重绑定为 i32 槽，按 E3189 报错；改写 pi = cast(pi, i32) 或 let i32 n = cast(pi, i32)。
4. **cast(e, frac) 新增**：int/bool/char → n/1（不产错误值）；float 字面量按二进制精确转分数（0.5→1/2，超宽报错）；非字面量 float 拒绝；frac 裸类型 = i32 元素。
5. **顺带修复**：bool→整数 cast 由 sext 改 zext（cast(true, i32) = 1 而非 -1）；push 元素槽根返回类型解引用（m[0] = push(m[0], 3) 可用）；修复三处先 free 后 clone 的 use-after-free 隐患（MCopy/字段写/struct assign/elem_assign 统一改为先 clone 后 free）。
6. examples 11 处、grammar_tests 6 处、main.zfy 5 处、tese.zfy 1 处裸调用点已全部改写；回归 54/54 PASS，grammar_tests 12/12 编译通过。
