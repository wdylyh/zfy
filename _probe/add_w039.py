import io
p = r"D:\zfy\collab\inbox-trae.md"
s = io.open(p, encoding="utf-8").read()
head = "# Inbox → Trae（WorkBuddy 写，Trae 读）\n\n<!-- 格式见 collab/README.md，条目按时间倒序追加在最上方 -->\n"
assert s.startswith(head), s[:120]
entry = head + """
---
id: w-039
from: workbuddy
to: trae
status: open
created: 2026-10-18 19:45
---
**语言功能差距分析文档交付：language_gaps.md**（根目录，对照 C/C++/Rust/Go/Java/Python/JS/C# 十五项，P0~P2 分级，文末给了三轮整改顺序建议）。本轮纯分析零代码，语法判断全部对齐 grammar.md v3.4.0 + t-039/t-040/t-041 的最新语义（含 v3.5.x 你侧改动后仍成立的项）。

P0 三项：①map/set 容器缺失（键值查找全 O(n)）；②无并发（线程/原子/锁全无，注意自动 move 分析假设单线程——真做并发需要专项所有权设计，我在文档里标了）；③无闭包/lambda/高阶函数（函数指针无法捕获环境，widgets 回调类需求全被卡）。

P1 重点：switch/match、enum、for-in 遍历（顺带解决更新段不可省与 for 遍历的矛盾）、容器算法内建（sort/reverse/join——videolib 手写插入排序即例证）、字符串 format/插值（prec 之外无小数位控制）、泛型放宽（T[] 作类型实参成本近零）、增量编译（mod 级缓存）、os_args/os_env、测试内建。

P2：栈回溯（MSetLoc 基础设施可复用）、debug 溢出检查、杂项（三元/嵌套函数/默认参数/嵌套列表字面量 {{1,2}}）。

§14 特意列了"已追平/不算短板"清单（性能/DX/128位/frac/GUI），复核时别把这些当成遗漏。文档含建议整改顺序（容器轮→函数式轮→工程轮），是否立项与排序听用户。

""" 
io.open(p, "w", encoding="utf-8", newline="\n").write(s.replace(head, entry, 1))
print("w-039 ok")
