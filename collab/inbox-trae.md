# Inbox → Trae（WorkBuddy 写，Trae 读）

<!-- 格式见 collab/README.md，条目按时间倒序追加在最上方 -->
---
id: w-036
from: workbuddy
to: trae
status: open
created: 2026-10-16 21:40
---
用户实测计算器反馈三个问题（按钮重合/窗口固定大小/高分屏糊），全部定位为 **L0 runtime 真实 bug** 并修复（v3.3.9）。定位手段值得复用：PrintWindow(PW_RENDERFULLCONTENT) 截窗 + Python 像素连通域聚类，测出"所有 fill_rect 的 x 起点翻倍"才锁定根因。
- **fill_rect 双重偏移**：`row = fb + y*W + x0` 后循环 `for x = x0..x1` → 像素落 2*x0 起。改 `for x = 0..(x1-x0)`。IR 层完全正确（先查了 .ll 排除编译器），纯 C 侧错误。
- **颜色**：DIB 32bpp 小端 DWORD 本身就是 0xRRGGBB，原代码做了多余 R/B 交换（红画成蓝）；draw_text 的 COLORREF(0x00BBGGRR) 却该交换没交换（文本色反）。两处各自纠正。
- **DPI**：gui_open 先 SetProcessDpiAwarenessContext(PER_MONITOR_V2)（动态查找，退回 SetProcessDPIAware），w/h 按 ×dpi/96 缩放为物理像素，字体 -16*dpi/96；新增 `zfy_gui_dpi()` + gui_dpi()；widgets 内部尺寸全部经 SC()=dpi*100/96 换算。**gui_open 的 w/h 语义变更：现在是逻辑尺寸**（gui_smoke 断言已同步改）。
- **resize（M4 部分）**：WS_THICKFRAME + WM_SIZE 重建 DIB + EV_SIZE(=8) 事件；业务层每帧比对 gui_w()/gui_h() 自行重排。calculator.zfy 已是响应式布局范例。
- 回归 0 失败（gui_smoke 断言更新后全绿）。注意：gui_w()/gui_h() 现在返回物理像素，所有 GUI 相关既有代码如依赖"逻辑=物理"需自查。

---
id: w-037
from: workbuddy
to: trae
status: open
created: 2026-10-17 06:20
---
GUI M3 交付（v3.3.10）：**TextArea 多行编辑 + Checkbox + 剪贴板 + demos/notepad.zfy 记事本**。
- **runtime**：扩展 WM_KEYDOWN（方向键/Delete/Home/End，KEY_EXT=0x10000000 前缀合成）+ 剪贴板 CF_UNICODETEXT↔UTF-8（zfy_gui_clip_set/get，gui.zfy 包装 gui_clip_set/gui_clip_get）。
- **widgets**：新增 TextArea（光标 cx/cy、回车拆行/退格合行、vis_rows 滚动、UTF-8 码点对齐 align_fwd/align_back、Ctrl+V）与 Checkbox（clicks 计数）；Ctrl+V 的插入逻辑抽为 `TextArea.insert_at_cursor(string)` 公开方法（业务可复用）。
- **demo**：notepad.zfy——编辑/新建/复制/粘贴/插入时间/字数状态栏，响应式布局（每帧比对 gui_w/gui_h 重排）。编译 0 错，截图验收 OK。
- **重要编译器修复（真实 bug，影响所有 zfy 用户）**：`SWhile`/`SFor` 的**条件表达式**在 ldepth=0 下检查，绕过了"循环体内不自动 move"门禁——while 条件里调用带字符串实参的函数，实参被"最后使用即 move"清槽（store null），下一轮迭代 load null 段错误。最小复现：`while i < n and f(s)`（f 收 string）。修复：typeck 中条件与 for-update 子句检查时同样提升 ldepth。**如果你们的代码里有 while 条件带字符串参数调用的写法，旧编译器可能一直靠侥幸没触发**，升级后行为更安全。
- 回归 0 失败（新增 examples/textarea_test.zfy 20+ 断言，gui_smoke 补剪贴板往返断言）。

---
id: w-035
from: workbuddy
to: trae
status: open
created: 2026-10-16 20:40
---
GUI M2 交付一个展示应用：**demos/calculator.zfy**（commit **1f06052**，源码入库；exe/ll 在 .gitignore 不入库）。用户点名的"拿 GUI 库真做个软件"展示物。
- **实现**：4x4 按键网格（7 8 9 ÷ / 4 5 6 × / 1 2 3 − / C 0 = +）+ 双 Label 显示屏（上行累积运算式、下行当前值），标准四则左累积状态机，i64 整数运算，除 0 显示"错误：除以 0"并复位。全部构建在 widgets.zfy 现有组件上（App/Button/Label + damage 跟踪），零编译器改动。
- **验证**：编译 0 错；冒烟 2 秒窗口存活不闪退（GUI 交互无法自动化，请你如果方便也可手动点几下）。
- **顺带**：stdlib/gui.zfy 工作区出现过一次未提交的文件头注释被整段删除（25 行，疑似 IDE/中断误伤），已 git checkout 恢复，无代码影响——与 t-026 提到的 main.zfy 截断同类现象，继续留意。
- 已知小坑备忘：`err` 是 ZEM 关键字，局部变量取名 `let bool err` 报 E2006——计算器里已改名 `bad`。是否要把"变量名与关键字冲突"的报错文案加个提示，待议。

---
id: w-031
from: workbuddy
to: trae
status: open
created: 2026-10-11 14:20
---
错误报告 DX 轮（用户指令：抑制级联噪声 + did you mean 建议）。回归 61 例 0 失败（探针验证，无新 examples 用例——回归框架只跑成功程序，错误输出质量靠 _probe/e1~e7 覆盖）。
- **级联抑制（poison 类型）**：hir.zty 加 `TError` 哨兵。语句级 recover（check_block）失败后把该语句声明的变量以 TError 入作用域；此后凡引用毒变量的表达式全部静默——coerce 入口、EBin 整体（比较产 TBool、其余产 TError）、EUn/EIndex/to_i64、check_builtin 的 str_of/char_or_str/length、SOutput 参数、ECallK 类型随实参。效果：`let i32 z = zzz + 1` 失败后，`if z > 0`、`z = z+1`、`helper(z)`、`arr[0] = z`、`output(z)` 全部不再报错（此前 z 的每个引用点都报 undefined/类型错）。
- **did you mean**：typeck 加 Damerau-Levenshtein 编辑距离 + `edit_close`（≤3 字符容 1 错、其余容 2 错，无相近候选不硬凑）+ `with_suggestion`。15 处 undefined variable、3 处 undefined function（含 generic_call_hook 默认值，移到 with_suggestion 之后修 unbound）追加 `(did you mean 'x'?)`；字段报错内联用 edit_close（候选=struct 字段表）。候选来源=作用域链+全局/泛型函数+struct+type 别名+**内建表**（lenth→length 提示靠这个）。实测：`m.mesage`→message、`lenth`→length、`y`→x。
- **错误数上限**：driver report_err 超 30 条截断 + `zfy: ... and N more errors (suppressed)`。**教训：OCaml dangling else**——`if c1 then if c2 then A else B` 的 else 绑内层，导致 i<30 全静默而 i>30 反而打印错误块（e5 探针 40 错只显示后 9 条才暴露）；嵌套 if 必须显式 begin/end。
- llvmgen size_of/ll_ty 加 TError 防御分支（exhaustive 警告驱动，编译器帮找全豁免点——这招好使）。
- TError 不会流到 MIR/LLVM：毒声明只存在于 env 作用域（recover 返回 None 不产 tstmt）；毒引用语句产出的 tstmt 结构正常，且 collected 非空必有错不进 codegen。

---
id: w-030
from: workbuddy
to: trae
status: open
created: 2026-10-11 13:55
---
v3.3.4 语义扩展轮（用户四项指令），回归 61 例（新增 sem334_test）0 失败。
- **下标/长度类内建返回 i32**：`length`（strlen 包 ECastK trunc；MSeqLen
  load i64 + trunc i32）、`find`（TErr (TInt 64) → TErr (TInt 32)，两处
  构造点；%err.i32 与 %err.i64 同为 24 字节 {i32,ptr,i64}，runtime 容器
  与 MErrValue 窄整数读取路径零改动）、`utf8_len`（ECastK 包装）。**连带
  修复**：mir push 路径把 MSeqLen 结果谎报 TInt 64（length 改 i32 后
  zfy_seq_set_w 的 i64 下标参数类型炸 9 例回归）——新增 llvmgen idx64
  helper，gen_seq_set/MSeqGet×3/remove/inline_elem_addr 六处下标统一
  提升提升 i64（sext/zext 按 oty），push 标注如实改 TInt 32
- **char 六种比较**：`< <= > >=` 新增（==/!= 已有），按码点序（i8 signed
  icmp，落 gen_binop signed fallback arm）；typeck is_cmp ok 判定加
  rl=rr=TChar 分支
- **string + char 拼接**：`s + 'c'` / `'c' + s`——BAdd TString 分支
  char 侧 to_string_of 提升（zfy_tostr_char 临时串有语句末释放，无泄漏）
- **cast(char→string) 与 main 隐含 i32 实测已就位**（cast 走既有
  num→string 路径；main 的 parser 强制/typeck 裸 return→0/退出码 return n
  全部工作）——用户报的两项是文档/认知滞后，grammar.md 本就写着 main
  隐含 i32；此轮无代码改动
- 测试：examples/sem334_test.zfy（末尾 `return bad` 验证 main 退出码）；
  grammar.md v3.3.4（内建表 length/find/utf8_len 返回 i32、char 六种
  比较、拼接、版本头）
- 注意：`??` 优先级低于 `!=`——`find(s,c) ?? -1 != -1` 解析成
  `find(s,c) ?? (-1 != -1)` 报 E3005，须写 `(find(s,c) ?? -1) != -1`
  （既有语义非本轮改动，备忘）
---
id: w-029
from: workbuddy
to: trae
status: open
created: 2026-10-11 13:35
---
v3.3.3：**`**` 幂运算支持 128 位整数**（用户指令），探针 12 项 + pow128_test 全过。
- **runtime**：`zfy_pow_u128/i128(out[2], blo, bhi, elo, ehi)`——参数与结果全走
  64 位对（规避 win32 __int128 参数/返回 ABI，同 zfy_stoi_wide 策略）；内部
  unsigned __int128 平方乘（回绕无 UB）；指数支持完整 128 位（迭代数=位长≤128，
  `2 ** 2^64` 正确得 0）；有符号负指数=0、0^0=1 与 64 位语义一致
- **typeck**：删除 BPow 的两处 128 位拒绝（前置守卫 + 同型 arm）；跨宽度改用
  **免检 ECastK 隐式宽化**（与通用算术对齐）——顺带修了 `u64 ** i32` 此前误报
  E3155 narrowing 的问题（`*` 能过而 `**` 报错的不一致）
- **llvmgen**：BPow 加 i128 分支（trunc/lshr 拆 64 位对 + alloca [2 x i64] +
  调用 + 拼回 i128）；prelude 加两个 declare
- **注意**：BPow 有三处定型路径（浮点 arm / 跨宽度 arm / 同型 arm），128 位
  拒绝当时写了**两处**（前置 + 同型）——排查时报错源不止一处的教训再+1
- 测试：examples/pow128_test.zfy（锚点 3^39、5^23 对照手写循环乘、2^128=0
  回绕、2^(2^64) 大指数、0^0=1、负底数/负指数、跨符号 u64**i32、右结合、
  字面量树）；grammar.md v3.3.3（§9 优先级表 + §17 限制区 + 版本头）
- 回归 60 例（结果见下一条确认）；无新错误码（E3000 兜底消息已随功能删除）
---
id: w-028
from: workbuddy
to: trae
status: open
created: 2026-10-11 13:20
---
v3.3.2 第二批：**new.md bug 报告（自动 move 循环误判）+ 附带发现已修**，回归 59 例 0 失败。
用户本轮指令"继续修bug"实指 new.md 里的报告（main.zfy 已被用户改写为 t14 大数开方
复现程序；new.md 改写为报告）。请复核：
1. **主修：自动 move 循环误判（报告根因，采纳方案 C）**：env 加 `mutable ldepth`
   （循环嵌套深度，SWhile/SFor 体检查时 ±1），auto_moveable 加门禁
   `env.ldepth = 0`——循环体内（任意深度）的实参/赋值一律不自动 move、走克隆。
   理由：last_use 按静态源码位置判"之后"，循环内使用点每轮迭代都执行，move 后
   下一轮读 null；报告的方案 B（忽略循环内后向使用）单独不足以拦住本例——
   r 的内层循环使用点本身没有更晚的静态使用，照旧被判 last。方案 C 是 B 的
   超集且语义可靠（循环外顶层"最后使用"仍自动 move，move_test 的循环内克隆
   语义本就如此，t-010 语义不变）。
2. **验证**：用户 main.zfy（t14 big_sqrt）修复前崩在第一个 output 之前
   （`store ptr null, ptr %v.r20`），修后完整跑通输出 `D r=495249`；
   报告最小复现（嵌套 while + f(r) 反复传参）过；新增
   examples/loopmove_test.zfy（嵌套 while/单层循环/循环内赋值 move 同根因/
   循环外顶层仍 move，~12 断言）。
3. **附带发现 #1（zfy_seq_free 参数不一致）已修**：runtime 签名是单参
   `void zfy_seq_free(zfy_seq*)`，llvmgen 5 处调用多发 `i8` kind 标志
   （zfy_seq_clone 同病 4 处，共 9 处）——LLVM 对 call/declare 元数不匹配
   本应 verifier 拒绝，clang -O2 不跑 verifier 才侥幸过。已全部去掉多余
   `i8` 参数与无用 kind 绑定；main.ll 现为 49 处单参 free + 19 处单参 clone，
   与 declare 一致。**请留意你侧如有生成/校验 IR 的工具，旧 .ll 里可能仍有
   双参形态。**
4. **附带发现 #2（alloca 25 个未合并）**：未动，记为备忘（性能非正确性）。
5. **文档**：grammar.md v3.3.2 头部变更记录 + §15 所有权条目补"自动 move
   循环限制"。errors.md 无新码。
6. **工作区提示**：main.zfy（t14 内容）与 new.md（报告）随本轮 commit 入库
   （用户文件，内容未动）；根目录多了未跟踪的 `zfyc` 二进制与 `新建文件夹/`，
   非我创建，请用户处置。


---
id: w-027
from: workbuddy
to: trae
status: open
created: 2026-10-11 13:05
---
v3.3.2 修复轮（用户指令"继续修bug"，探针驱动挖出 4 个 bug），全部修复并回归 58 例 0 失败。请复核：
1. **abs/`|e|` 延迟定型（主修）**：`let i32 a = |3|`、`|2-5|` 落 i32 报 E3155 窄化、
   `let f32 c = |2.5|` 报 E3005——abs 的 lit_default 把纯字面量实参树提前定型成
   i64/f64，期望无法传播（上轮 pow_abs_test 的 abs 断言全在 i64 上下文，未暴露）。
   修法与 BPow 字面量树同机制：typeck check_call abs 分支对 ety=TVar 实参不再
   lit_default，改把**实参自身的 TVar 直接作 sig 参数/返回**——调用结果与实参树
   共享同一 TVar，由外层 coerce 统一求解（声明/赋值/实参/return/下标/T! 包装/
   嵌套 `||3|-5|` 全部实测正确）；无约束时 fix 阶段按默认型收口。
2. **fix_texpr ECallK 浮点对齐（修①引出）**：`output(|2.5|)` 产 `print_i64(double)`
   非法 IR——未约束 abs 调用落默认 i64 而实参叶子特判翻 f64。ECallK 分支加对齐：
   `abs` 单实参且 ety 落默认 TInt 64 而实参为浮点 → 调用型随实参。
3. **条件位 bool 守卫（既有 bug，与①无关）**：`if 2**0` 报 E4025 内部错误——
   懒定型算术树（BPow 既有路径）被 unify 静默绑成 TBool，codegen 无分发。修法：
   coerce 加守卫（TVar 算术/调用树 → TBool/TChar 目标报 E3000 正规错误）+
   `not` 分支同守卫 + SIf/SWhile/SFor/and/or 五处条件位从直连 `unify TBool`
   改走 `coerce p tc TBool`（具体型不匹配走正规 E3055）。
4. **编译期非有限浮点字面量（既有 bug）**：`let f64 z = 1e400` 产 `inf.0` 非法 LLVM
   （%.17g 对 inf/nan 的输出）。float_const 默认分支加 `Float.is_finite` 检查，
   非有限按 double 位型 hex 发（`0x%016LX`）。f128/f16 的 inf 本就正确（fp80/half
   位型转换内部处理），`-inf`、下溢 0、-0.0 实测均对。
5. **const_eval 扩展（既有缺口）**：只折叠 `+ - * / %`——`let i32 const n = 2**4`
   作数组长度报 E3129。补 BPow（负指数=0、平方乘、Int64 回绕=runtime 语义）、
   abs（无符号恒等/有符号取反，与 llvmgen 一致）、位运算（& | xor ~ << >>
   移位量 0..63 界内、BShr 有符号 ashr/无符号 lshr 对齐）。
6. **新用例**：examples/lazyabs_test.zfy（约 20 断言：延迟定型各上下文/嵌套/T!
   包装/const 折叠数组长度/inf/-0.0 经 1/nz=-inf 判定）。回归 58 例 0 失败。
   另补提交上轮遗漏的 float_mix_test.out/.err 产物。
7. **文档**：grammar.md 升 v3.3.2（头部变更记录、abs 重载行、`|e|` 行、
   §3 定长数组 N 说明、§17 条件位 bool 强制）；errors.md 无新码（E3000/E3055
   复用，E4025 不再可达于 bool 场景）。
8. **行为变化提示**：①`if 2**0`/`not (2**0)`/`2**0 and x` 从 E4025 变 E3000；
   ②`let char c = 2**0` 类（算术树落 char）从静默绑定+内部崩溃变 E3000；
   ③abs 字面量树不再有"默认 i64/f64"概念——按期望落型，无期望才落默认。
9. 顺带确认的既有行为（非 bug，未动）：数字后缀不支持（`2u8`/`2.5f` 被
   拆成 `2`+`u8` 两个 token，报错链较绕——若要改善诊断质量可另立任务：
   scan_number 遇数字后紧跟字母/下划线报词法错）；`j * 1e2`（整数变量×
   浮点字面量）按 v3.3.1 拍板报 E3190（Rust 风格需显式 cast），维持。


---
id: w-026
from: workbuddy
to: trae
status: open
created: 2026-10-11 12:20
---
v3.3.1 浮点/整数混算修复轮（用户指令"修"= 修 v3.3 记录的两个既有缺陷，过程中又挖出
第三个既有 bug），全部修复并回归。请复核：
1. **混合 int/float 字面量树坏 IR（缺陷①，已修）**：根因 fix_texpr 对未约束浮点字面量
   逐叶翻 f64 而兄弟节点/父节点留在默认 i64。三层修复：
   - typeck 新增 `floaty_texpr`（子树含 EFloatK 判别）；coerce 拦截"浮点字面量子树
     → 整数/char 槽"（`let i64 x = 2.5`、`x += 2.5`、浮点实参落 i64 形参 → E3190）；
   - check_binop 通用路径：浮点字面量 × 具体整数/char 混算 → E3190（`2.0 * x`、
     `2.5 < q`；此前 unify 静默把浮点字面量绑成 i64 再翻型爆炸）；
   - fix_texpr 树级传播：子节点混浮点/整型 → 整型侧必为字面量子树，重打浮点；
     节点落默认整数型 → 提升同宽浮点。纯字面量混合树合法（`2.5 + 1` = 3.5；
     f32 上下文整树 f32，`let f32 g = 1.5 * 2` 不受影响）。
2. **f32 常量发射（缺陷②，已修）**：llvmgen float_const 加 TFloat 32 分支——
   53 位尾数低 29 位清零且正规域 → 十进制原样；否则 double→f32 就近取整
   （round-to-nearest-even，含次正规/进位/溢出 inf）后发 double hex 位型
   （clang 同款 `0x%016LX`）。`let f32 a = 0.1` / `a < 2.249` 此前必产坏 IR，
   现位型正确（0.1f = 0x3FB99999A0000000）。
3. **科学计数法字面量解析 bug（新发现，已修）**：lexer scan_number 浮点分支无条件
   `add '.'; advance` 把裸指数的 `e` 当小数点吞掉——`1e40` 被错读为 `1.40`=1.4、
   `1e-45` 被拆成 `1.0-45`=-44（f64 也错，既有 bug 与本轮改动无关）。修为
   小数点/指数两形态分支。另修 float_const：`1e+40` 无小数点被 clang 拒 →
   指数形插 `.0`（`1.0e+40`）。
4. **错误码**：新增 E3190（2 条消息），errors.md 合计 278 码。
5. **新用例**：examples/float_mix_test.zfy（约 20 断言：混合树/上下文绑定/f32
   位型/科学计数法/inf/次正规）。回归 57 例 0 失败。
6. **语义提示**：E3190 是行为变化——此前 `2.0 * x`（x:i64）等错误代码能"编译"
   （坏 IR 链接失败），现在 typeck 干净报错；`let i64 x = 2.5` 从 E4037 变 E3190
   （更明确）。grammar.md v3.3.1 §17 已同步。
7. 顺带确认：`not`/`and`/`or` 优先级为 or > and > not > 比较（or 最松），
   `not A or B` == `not (A or B)`——grammar.md §9 若未明示建议补一句。

---
id: w-025
from: workbuddy
to: trae
status: open
created: 2026-10-11 11:25
---
v3.3 运算符落地，commit **7d38edd**（编译器 + grammar.md v3.3 + examples/pow_abs_test.zfy，
回归 56 例 0 失败）。请复核与同步 description.md：
1. **`**` 幂运算符**：右结合 `x**2**3 == x**(2**3)`；数学优先级（高于乘除；
   `-x**2 == -(x**2)`）。整数 ≤64 位走 runtime 快速幂 `zfy_pow_ll/ull`（负指数=0、
   溢出回绕）；任一侧浮点/含浮点字面量 → 整树按浮点（f32 双侧走 powf）；
   128 位整数报 E3000。`pow(b,e)` 内建与 `**` 共存（prelude declare 去重）。
2. **`|e|` 绝对值**：脱糖为内建 `abs(e)`（整数同宽内联、浮点 fabs/fabsf）；
   内层表达式解析到 `&` 层为止——按位或作被绝对值须写 `|(a | b)|`；嵌套 `||x||` 合法。
3. **顺带发现两处既有缺陷**（已记 grammar.md §17，未修）：①通用算术的混合
   int/float 字面量树（`2.0 * 3`）经 fix_texpr 独立定型产坏 IR——`**` 已修，
   其余运算符建议同样加"floaty 树统一"判定；②f32 与字面量直接比较
   （`fb < 2.249`）浮点常量按 %.17g 输出 double 位数，产非法 IR。
4. abs 的字面量定型 lit_default 已扩展为递归识别字面量表达式树
   （EUnK/EBinK，含浮点字面量取 f64），`|3-9|`/`|-2.5-1.5|` 均正确。

---
id: w-024
from: workbuddy
to: trae
status: open
created: 2026-10-11 10:45
---
new2.md 随机数模块全量落地（用户拍板：一次全做；异或用 `xor` 关键字）。主体改动已被用户
以 commit **3455a58** 入库（含我侧全部编译器改动），探针清理 + errors.md 补录为 **e970355**。
回归 55 例全 PASS（含新增 examples/random_test.zfy，两处参考实现锚点对拍）。请复核文档与同步：
1. **语言特性（v3.2）**：①位运算 `<< >> & | ~` 运算符 + `xor` 关键字（`^` 仍只作解引用后缀），
   优先级 C 风格：`<<>>` 在 + - 之下、比较之上，`&`/`xor`/`|` 低于比较（`x & 1 == 1`
   解析为 `x & (1==1)`，grammar.md §9 已注明）；移位量 ≥ 位宽未定义。②struct 方法：
   隐式首参 self = ref 接收者，`c.bump()` 脱糖 `<S>__bump(ref c)`；const 接收者调方法报错；
   方法名不能是关键字。③数学内建 sqrt/log/exp/sin/cos/tan/pow/floor/ceil（直落 libm）+
   **abs 重载**（整数→同宽含 i128/u128 内联 sub+select；浮点→同宽 @fabs/@fabsf）。
   ④ref struct 参数放行（E3162 对 TStruct 解除）。
2. **编译器顺带修复 3 处**：①resolve_name 对 extern "C" 名不再做模块扁平化（此前模块内
   调 extern 报 undefined，IExtern 侧本就不改名，两处失配）；②文件模块 use 导入 struct/
   type 名作声明类型不可用——parse_let_head/fn 返回类型/方法返回类型/input 目标四处判定
   增加"Ident 后跟 Ident ⇒ 视为类型"形状规则（跨文件类型名解析器不可知）；③resolve 模块
   文件查找加 stdlib 回退（沿父目录链查 `<祖先>/stdlib/名.zfy`，最多 6 级），E5008 文案
   已更新。
3. **stdlib/random.zfy**（459 行，全部纯 zfy）：Random = xoshiro256** + SplitMix64 播种 +
   Lemire 无偏区间（u128 高 64 位 + 阈值拒绝）+ Fisher-Yates；SecureRandom = ChaCha20
   （quarter round 经 ref 定长数组参数原地改写）+ OS 熵源（runtime.c 新增
   zfy_os_random_u64：Windows 动态加载 SystemFunction036 / POSIX getentropy，免附加链接库）。
   设计稿方法名 float()/int()/uint() 与类型关键字冲突，更名 uniform()/int_range()/uint_range()。
   xoshiro 与 ChaCha20 均与 Python 参考实现逐位对拍通过（random_test.zfy 内含锚点）。
4. **请同步**：①grammar.md 已升 v3.2（§2 xor、§7 方法、§9 位运算、§12 数学内建 + §12.1
   随机数库、§16/§17 对照与限制）——description.md 若有运算符/内建清单请对齐；②errors.md
   E5007/E5008 已补录（277 码）；③runtime.c 尾部新增 zfy_os_random_u64 与 windows.h include，
   合并时注意冲突。
5. **已知边界**：字面量 `n/d` 除式按分数字面量语义，浮点缩放常量需写科学计数法
   （1.0/16777216.0 会走 frac 路径产生坏 LLVM 常量——random.zfy 内已用 2^-n 科学计数法绕开，
   该交互是否算 bug 待用户裁决）；`abs(大整数字面量)` 需显式 i128 上下文。

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
<!-- w-028 复验（2026-10-13:00）：用户重提 new.md 报告，已确认 e05ed62 修复在位且生效——main.zfy 完整跑通 D r=495249、loopmove_test/s8 最小复现全过、回归 59 例 0 失败。无需 Trae 动作。 -->

<!-- 2026-10-11 14:20 轮次确认：本轮为用户程序编写练习（program.zfy 数字直方图），未改编译器；两处报错（main 带返回类型、数组字面量方括号语法）均为我方笔误，非编译器 bug。另外发现根目录 zfyc 是 0 字节空文件（易误导调用），建议后续清理。 -->

<!-- 2026-10-11 14:38 轮次确认：本轮用户程序练习（grade_report.zfy 成绩统计分析器），编译通过、边界用例验证正确，未改编译器；三处报错（空列表字面量 [] 不支持、main 裸 return 类型不符、output 是变参每调用末尾自动换行）均属语法认知问题已自行修正，非编译器 bug。 -->

<!-- 2026-10-11 14:42 轮次确认：本轮用户程序练习（mortgage.zfy 等额本息房贷计算器），首次编译即通过；标准用例（100万/4.9%/30年 → 月供 5307.27、总利息 910616.19）与逐年计划、0 利率边界全对。仅一处显示瑕疵（两位小数补零）自行用 output end="" 命名参数修复，非编译器 bug。 -->
---
id: w-032
from: workbuddy
to: trae
status: open
created: 2026-10-16 19:25
---
时间内建已落地（commit 1db2d01，v3.3.6），回归 62/62 全 PASS：
- 新内建：`now() -> i64`（Unix 秒）、`tick_ms() -> i64`（单调钟 QPC/CLOCK_MONOTONIC，进程起点 0）、`sleep_ms(i64)`（TVoid 裸语句合法）、`localtime(i64) -> datetime`、`mktime(y,mo,d,h,mi,s) -> i64`（分量 i64 允许越界归一化，日期算术基础）
- **内建 datetime struct**：8 字段全 i32（year/month/day/hour/minute/second/weekday/yday），weekday 0=周日；由编译器在 genv 初始化处预注册，用户不得定义同名 struct/fn（已入 builtin_names 保留表）
- 实现要点：localtime 走 sret（MCallOwn 聚合返回既有路径，C 侧 `void zfy_time_local(zfy_datetime*, i64)` 与 clang ABI 天然对齐）；时间符号全部 zfy_ 前缀豁免 declare 自动收集，由 prelude 统一声明；typeck 侧 ECallK 构造处加 time_rt_name 用户名→运行时符号映射
- 保留名新增：now/tick_ms/sleep_ms/localtime/mktime/datetime
- examples/time_test.zfy 为行为参考（含越界归一化、单调性、sleep 实测断言）
---
id: w-033
from: workbuddy
to: trae
status: open
created: 2026-10-16 19:50
---
GUI 框架 L0/L1 已落地（commit 9b6d738，design_gui.md 为架构总纲），回归 62/62：
- 分层：L0 渲染核心（runtime.c，~330 行 C）→ L1 绑定（stdlib/gui.zfy，纯 extern）→ L2 组件（下一轮，纯 zfy）→ L3 应用框架
- L0 速度设计：CreateDIBSection 32bpp 帧缓冲直写像素、fill_rect 按行块填充、事件环形队列 O(1) 轮询、present 单次 BitBlt、WM_ERASEBKGND 吞掉防闪烁；GDI 同 DC 出中文文本（雅黑 16px ClearType）+ text_w 布局测量
- **零编译器改动**（唯一例外：driver 链接追加 -lgdi32 -luser32，Windows 分支）
- API：gui_open/close/title/w/h/alive/should_close/poll/present/fill_rect/rect/draw_text/text_w/frame_sleep + Event struct + EV_* 常量；事件 MOVE/LDOWN/LUP/RDOWN/RUP/KEY/WHEEL
- 交互演示在 demos/gui_demo.zfy（不进回归扫描）；examples/gui_smoke.zfy 自动断言可入回归
- 已知 Phase 2 待办：resize/DIB 重建、damage 跟踪（组件层）、键盘扫描码、剪贴板
---
id: w-034
from: workbuddy
to: trae
status: open
created: 2026-10-16 20:40
---
GUI 框架 M2 已落地（commit 13259f7，v3.3.8），回归 66/66 全 PASS：
- stdlib/widgets.zfy（L2，纯 zfy）：Label/Button/InputBox/Slider/ProgressBar/ListBox + App 容器。damage 跟踪：组件带 dirty 标志，只重绘脏组件，本帧无重绘则不 present（空闲零拷贝）；App.step() 一帧完成泵事件→分发→脏区重绘→按需提交；业务侧读组件状态（clicks/text/value/sel）驱动 UI
- **编译器三项改动**（本轮真实 bug 修复）：
  1. resolve.ml：mod 文件内方法的参数/返回类型漏做名字扁平化（只重写了 body）→ mod 内方法带 struct 参数报 E3001 undefined type（单文件/自由函数均正常，故此前未暴露）
  2. typeck.ml：ECall callee 为 EField 时支持元素方法调用 arr[i].m(...)——接收者按元素地址传（CRef 泛化到可定位字段/元素表达式）；check_aug 支持 self.a[i].f++ 等元素字段复合赋值（取址→SAugDerefK）
  3. mir.ml：EAddrOfK 泛化为递归地址生成（字段链/元素/解引用任意嵌套）；注意字段链地址的寄存器语义与变量槽差一次 load（seq 指针），MElemAddr 基址已对齐槽语义
- examples/widgets_test.zfy 可入回归（合成事件断言状态机 + 渲染冒烟）；demos/widgets_demo.zfy 交互演示（按钮计数/输入回显/滑块联动进度条/列表选中/添加项）——可直接运行体验
- 语法备忘：struct 内方法不可加 pub；use 组绑定不可跨行；struct 值语义——add 进 App 后须读 app.buttons[i] 而非局部变量
- 下一步 M3：L3 应用框架（焦点链/回调）+ 记事本/计算器两个真实小软件
