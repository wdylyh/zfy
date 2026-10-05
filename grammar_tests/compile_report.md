# zfy 语法全表符合性测试——编译错误报告

- 测试日期：2026-10-05
- 编译器：`D:\zfy\compiler\_build\zfyc.exe build <file>`（commit 27efc77 基线，含 t-026 fdd5861 回归）
- 依据文档：`D:\zfy\grammar.md`（2026-10-05 版）
- 测试代码：本目录 `t01_types.zfy` ~ `t12_misc.zfy`，共 12 份

## 一、结果总览

| 文件 | 结果 | 问题定性 |
|---|---|---|
| t01_types.zfy | ✅ 编译通过 | — |
| t02_seq.zfy | ❌ 2 错 | 文档欠明确：output 不支持嵌套序列 |
| t03_func.zfy | ✅ 编译通过 | — |
| t04_struct.zfy | ✅ 编译通过 | — |
| t05_generic.zfy | ❌ 1 错 + 连锁 | 解析器缺口：泛型实例作非泛型函数返回类型 |
| t06_zem.zfy | ❌ 2 错 | 文档缺限制说明：?? 块形式位置受限 |
| t07_ptr.zfy | ✅ 编译通过 | — |
| t08_str.zfy | ❌ 3 错 | **文档条目错误：replace 签名与实现不符** |
| t09_ctrl.zfy | ✅ 编译通过 | — |
| t10_frac.zfy | ❌ 2 错 | 文档缺限制说明：顶层 const 不支持 frac |
| t11_mod.zfy | ❌ 3 错 | **新 use 路径语法未实现** |
| t12_misc.zfy | ✅ 编译通过 | — |

6 通过 / 6 报错。以下按文件列出报错原文与依据条目，供逐条修复。

## 二、真实"文档 ↔ 编译器"不一致（建议优先处理）

### 1. t08_str.zfy —— replace 内建签名：文档写的与实现完全是两套

- 代码依据 §11：`replace(s, char, rep)` 全替换 / `replace(s, char, char, rep)` 次数限定：
  ```zfy
  string r1 = replace("aaa", 'a', 'b')
  string r2 = replace("aaa", 'a', 'b', 2)
  ```
- 实际报错：
  ```
  zfy:error[E3075] in 12 of t08_str.zfy because (an integer type is required, got char)
  zfy:error[E3075] in 13 of t08_str.zfy because (an integer type is required, got char)
  ```
- 比对既有示例（fn_call_test.zfy:48、str_test.zfy:21、raii_stress_test.zfy:29），实现的真实签名是
  **`replace(s, 起, 止, "串")` 区间整数替换**，与文档 `replace(s, char, rep)` 完全不符。
- 结论：grammar.md §11 replace 条目过时/错误，需改写为区间替换语义（或实现端补 char 替换重载）。
- 连锁：`r1`/`r2` 未声明导致 line 31 E3011（undefined variable: r1），随上文修复消除。

### 2. t11_mod.zfy —— grammar.md §9"新 use 路径"语法未实现

- 代码依据 §9：`use a::b::item [as x]`、分组 `use a::b::{x, y as z}`、整模块 `use a::b [as m]`：
  ```zfy
  use math::sq
  use math::{one, inner as mi}
  use util as ut
  ```
- 实际报错：
  ```
  zfy:error[E2025] in 19 of t11_mod.zfy because (use file name must end with .zfy)
  ```
- 解析器仍按旧文件名 use（`use 名字.zfy`）语法处理 `::` 路径，新路径语法整体不可用。
- 连锁：`sq`、`mi.add`、`ut.tag`、`ut.hl` 等导入名全部未定义（E3101/E3011 ×2），随上文修复消除。
- 结论：要么实现新 use 路径，要么 grammar.md §9 改回仅 legacy 文件 use 并标注新语法未落地。

### 3. t05_generic.zfy —— 泛型实例 `Box<i32>` 作非泛型函数返回类型，顶层解析失败

- 代码依据 §3"泛型实例化 `Box<i32>`（仅类型位置）" + §9 函数返回类型为任意合法类型：
  ```zfy
  Box<i32> make_box(i32 x)
      return Box(x)
  ```
- 实际报错（line 11，其后全部为连锁）：
  ```
  zfy:error[E2005] in 11 of t05_generic.zfy because (expected a top-level item (function/use/declaration), got ()
  ```
- 解析器把 `Box<i32> make_box` 当成了"声明语句"，遇到 `(` 失败；同文件 `<T> T first(...)`、
  `<T> T pick(...)` 泛型函数本身解析正常（gen_test.zfy 中 `<T> Box<T> make_box(T x)` 泛型形式也可编译）。
- 结论：顶层项解析只对泛型函数前缀 `<T>` 后的返回类型接受 TApp，非泛型函数的 TApp 返回类型
  （及连锁的 E3101 undefined function: make_box / first / pick、E3148 missing main）无法解析。
  建议解析器在顶层函数判定处支持 `Ident<...>` 形态返回类型。

## 三、文档未写明的限制（实现行为合理，文档需补充说明）

### 4. t02_seq.zfy —— output 不支持嵌套序列整体打印

- 代码依据 §7 w-013"参数可为数组/列表（整体按元素打印）"：
  ```zfy
  i32[][] m          // 嵌套列表
  i32 g[2][3]        // 定长二维
  output(m)          // E3000: output does not support element type: i32 list
  output(g)          // E3000: output does not support element type: i32[3]
  ```
- 一维定长数组 `output(b)`（i32[3]）正常，与 outseq_test 一致；仅嵌套/二维序列被拒。
- 结论：w-013 需注明"仅一维序列；嵌套列表/定长二维不支持整体打印"。

### 5. t06_zem.zfy —— ?? 块形式仅限声明/赋值右值，return 后不可用

- 代码依据 §8/§10（§8 将块形式列为表达式）：
  ```zfy
  return safe_div(a, b) ??
      ErrCode.CUSTOM
  ```
- 实际报错：
  ```
  zfy:error[E3138] in 15 of t06_zem.zfy because (??-block form (a ?? indented block) is only allowed as the RHS of a declaration or assignment)
  ```
- 连锁：E3111（code_msg 声明 i32! 但可能无返回值）。
- 注：声明右值位置的 `i32 r = safe_div(6, 0) ?? <缩进块>` 编译正常；t-009 偏离清单⑥
  （"?? 块形式仅语句级：声明/赋值右值"）有此决策但 grammar.md 未收录。
- 结论：grammar.md §8/§10 需补"?? 块形式仅允许作为声明/赋值右值"的限制（或放宽实现支持 return 位）。

### 6. t10_frac.zfy —— 顶层 const 不支持 frac/unred

- 代码依据 §4 修饰符示例 `long const frac r = 1/2`（未区分声明位置）：
  ```zfy
  long const frac third = 1/3    // 顶层
  ```
- 实际报错：
  ```
  zfy:error[E3040] in 3 of t10_frac.zfy because (top-level const does not support frac/unred)
  ```
- 函数内 `i32 const frac pi2 = 22/7`（frac_test.zfy:32）合法；仅顶层被拒。
- 连锁：E3011（undefined variable: third）。
- 结论：grammar.md §4 需注明"const + frac/unred 仅函数内声明合法，顶层报 E3040"。

## 四、通过文件与验证要点

- **t01_types.zfy**：宽度名/别名、type 别名、类型后缀 `i32[]`/`i32[3]`/`i32[][]`/`i32[2][3]`、
  一行多声明器、const/frac/unred（函数内）、泛型实例化声明位置——全部按 §3/§4 通过。
- **t03_func.zfy**：ref 标量/string/列表（两种后缀写法 `i32 ref xs[]` 与 `i32[] ref xs`）、
  返回 `i32[]`/`i32[3]`、函数类型参数（type 别名）——§5 全通过。
- **t04_struct.zfy**：位置/命名/补全/裸声明构造、嵌套 struct、packed、sizeof/alignof、
  struct 作列表元素（深拷贝值语义、`ps[0].x` 写）——§6 全通过。
- **t07_ptr.zfy**：`&`/`p^`/`T* const`/null/unsafe 指针算术与 p[i]/函数指针——§3/§7/§8 全通过。
- **t09_ctrl.zfy**：if 链、单语句同行块、while+break/continue、四段 for、output sep/end、
  input 声明目标 + delim、not/and/or 优先级——§7/§8 全通过。
- **t12_misc.zfy**：not 低于比较、复合赋值、自增自减、?? 值形式、e?（T! 函数内）、cast、
  panic 单/双参、sizeof/alignof——全通过。
- 所有成功编译均有同一条 benign 警告（非本次引入）：
  `warning: overriding the module target triple with x86_64-w64-windows-gnu`。

## 五、测试方自误修正记录（非编译器问题，已改正后复测）

1. t01：`const i32 k` → `i32 const k`（§4 修饰符位于类型后名字前）。
2. t02：`push(m, c)` 实参类型不符（i64[] vs i32[]），改同型。
3. t03：`ref i32 x` → `i32 ref x`（§5 ref 在类型之后）。
4. t06：`?? { ... }` 花括号块 → 缩进块（§7：无花括号块语句，分号非法）。
5. t07：`p[0] = 7` 移入 unsafe 块（§7：p[i] 必须 unsafe）。
6. t08：`find`/`split`/`trim` 分隔实参为 char 而非 string（§11）。
7. t09：`for , cond,` 空初始化段被拒——§7"条件可无"未写明其他段可否为空，视为文档歧义，
   已改标准四段写法（此歧义可顺带澄清）。
8. t10/t11：`half` 为类型关键字，不可作变量名（E2006），改名 `hl`。

## 六、备注

- 本轮只做编译验证，未运行产物；t02 中 `a[0, 4:2]` 切片在当前数据长度下运行时会 panic
  （编译无错，属运行期语义，非本次范围）。
- 每个失败文件保留在首次触发真实问题的最小改动状态，连锁错误未清理，便于对照原始报错。

## 七、修复记录（2026-10-05 晚，WorkBuddy，方案经用户逐项拍板）

| # | 问题 | 决定 | 落地 |
|---|---|---|---|
| 1 | replace 签名 | 只修文档 | grammar.md §11 改为 `replace(s, 起, 止, 串)` 区间替换（两端含）；t08 测试改用真实语义，运行输出正确 |
| 2 | 新 use 路径 | 实现完整 | 单项/分组本已可解析；补齐 ①整模块绑定 `use a::b [as m]` 的命名空间解析（resolve BMod 点分展开 `别名.成员`，pub 可见性沿用）②单段 `use 模块名 [as 别名]` 解析（原误入 legacy 报 E2025）；t11 全绿（3630 / u1/2） |
| 3 | 泛型实例返回类型 | 修解析器 | top_is_fn 前瞻新增类型实参平衡跳过（skip_tyargs_toks/skip_ty_lookahead_toks，`Box<i32> make_box(...)` 可解析；`Box<Box<i32>>` 亦支持）；t05 全绿 |
| 4 | ?? 块位置 | 放宽实现 | SUnwrapBlockK 增加 ret 标志：`return a ?? 块` 成功路径直接返回成功聚合（RAII 同 SReturnK），失败路径执行块、块末值 coerce 包装为返回类型；E3138 保留用于其余非法位置；探针验证 i32!/string! 两路正确 |
| 5 | 顶层 const frac | 放宽实现 | 全局分数常量槽（@g.名 + lconst=true + ginit），不做整数内联；顺带修复既有 bug：数值字面量实参经 TVar 静默重打型落进 frac 聚合槽致 E4021——coerce 增加字面量→frac 提升（mk_frac_from），check_call 支持 frac 期望位置的 `n/d` 字面量实参（与声明初值同语义） |
| 6 | output 嵌套 | 实现递归打印 | 新增 runtime zfy_print_seq_nest（depth=剩余指针层数，逐层 `[...]`，sep 全层生效）+ MIR MPrintSeqNest + typeck 叶元素递归校验（struct 叶/列表 i128 叶仍拒，depth<8）；t02 输出 `[[1234][1020]]`、`[[000][005]]` |
| 7 | for 空段 | 只修文档 | §7 注明初始化/更新段不可为空 |
| 8 | triple 警告 | 消除 | llvmgen 输出显式 `target triple = "x86_64-w64-windows-gnu"` |

- 验证：build 零 error；回归 53 例全 PASS（failures: 0）；grammar_tests 12/12 编译通过且运行输出正确。
- 已知遗留（未在本轮范围，记录备查）：非 unred frac 函数 `return a + b` 不自动约分
  （如 8/16，值正确表示未归约；"存入后约分"仅覆盖声明路径）——是否补 MNorm 待用户拍板。
- E3040（顶层 const+frac）检查已删除，码位在 errors.md 中待标记作废；E2025 触发范围缩小
  （仅 legacy 缺 .zfy 扩展名路径）。errors.md / description.md 侧同步留 Trae 统一处理。
