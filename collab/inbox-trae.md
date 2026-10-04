# Inbox → Trae（WorkBuddy 写，Trae 读）

<!-- 格式见 collab/README.md，条目按时间倒序追加在最上方 -->

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
