# zfy 基准测试实现问题记录（第 4 组测试过程中发现）

日期：2026-10-03
背景：用 zfy 实现与 Python/C++/Rust 功能等效的 5 类基准任务时记录的所有语言限制、设计问题与编译器 bug。

## 一、实现过程中发现的编译器 Bug（已修复）

### BUG-1 列表扩长容量爆炸（runtime.c seq_grow）【严重】
- 现象：`src[length(src)] = i` 循环追加约 30 次后 realloc 申请 4GB 失败 exit(1)。
- 根因：`seq_grow` 无条件 `ncap = cap * 2`，每次追加（idx==len）都翻倍容量，
  n 次追加后 cap = 8 * 2^n。既有示例最多追加几十次故未暴露。
- 修复：need <= cap 时只填零新槽位不扩容；扩容时 memset 从 len 起（而非旧 cap 起）。
- 状态：已修复，20 万次追加验证通过。

### BUG-2 循环体内 alloca 耗尽栈（llvmgen.ml）【严重】
- 现象：20 万次列表追加栈溢出（0xC00000FD）；5 万次侥幸通过。
- 根因：临时 i128 槽 / 变量槽的 `alloca` 内联在当前基本块（循环体内），
  每次迭代新增栈帧不回收，栈占用随迭代次数线性增长。
- 修复：新增 `emitf_entry`，所有 alloca 沉入函数入口块（ebuf，生成后拼接）。
- 状态：已修复，20 万次追加验证通过。

### BUG-3 runtime 函数 ABI 声明错配（llvmgen.ml declare）【隐蔽】
- 现象：切片复合赋值 `sa[1,3] += 10` 输出全零；最小复现直接报"浮点不支持取模"。
- 根因：`zfy_seq_aug_range` 的 C 签名是 `int op/int sgn/int is_float`，
  IR 却声明 `i8`——x64 ABI 整数参数槽 32 位，高位垃圾导致 op/is_float 错乱。
  此前恰好未暴露。同类问题：`zfy_tostr_bool(int)`、`zfy_input_f64(..., int mode)`。
- 修复：declare 与调用点统一改为 i32。
- 状态：已修复，全部示例回归通过。

### BUG-4 C++ 基准自身笔误（bench.cpp）
- u128 先截断再取模导致校验和不一致，已修正（非语言问题）。

## 二、语言设计限制（第二轮：LIM-1~5 全部已解决）

### LIM-1 顶层 const ✅ 已支持
- 顶层 `int const 名 = 表达式`（仅整数；使用处内联编译期值，可作数组长度）。
- 实现位置：typeck.ml check_program（全局作用域 + const_vals 内联）。

### LIM-2 列表整体拷贝初值 ✅ 已支持
- `int list cp = base` 按整体深拷贝处理（与数组对齐）。
- 实现位置：typeck check_seq_decl + hir SSeqCopyK(is_list) + mir 降码 memcpy。
- 验证：examples/listcopy_test.zfy（改副本不影响源）。

### LIM-3 and/or 短路 ✅ 已支持
- and/or 短路求值：rhs 仅在需要时求值（mir.ml lexpr EBinK 分支块）。
- 验证：examples/shortcircuit_test.zfy。

### LIM-4/5 混合宽度自动宽化 ✅ 已支持
- i32/i64（含 u/i）比较与算术按 widen_target 自动宽化（typeck.ml），字面量随上下文。
- 验证：examples/widen_test.zfy。

### LIM-6 push 内建 ✅ 已支持（第二轮新增）
- `push(列表, 值)`：追加到末尾，下标=当前长度，写入时自动扩长（复用 MSeqSet grow）。
- 支持 int/double/string（string 深拷贝）元素；无返回值。
- 实现位置：hir EPushK + typeck ECall "push" 分支 + mir 降码。
- 验证：examples/push_test.zfy。

## 三、其它观察

- T5 哈希需要 i128：zfy 的 `long long` + 大字面量常量可用，表现尚可。
- 输出 1 万行文本（T3）无明显异常，但 output 逐行 flush 的性能未单独测。
- 切片返回同类型深拷贝的设计使得 T4 写法自然，但深拷贝语义（赋值/传参/返回
  一律拷贝）在内存密集任务上的成本会在基准数据中体现。
- 并发能力：zfy 目前无线程/并发设施，Rust/C++ 可用线程，本次基准为公平
  全部单线程；并发列为语言路线图候选。
