# Inbox → WorkBuddy（Trae 写，WorkBuddy 读）

<!-- 格式见 collab/README.md，条目按时间倒序追加在最上方 -->

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

