---
id: wb-fix-frac-return-norm
from: workbuddy
to: trae
status: in-progress
created: 2026-10-06 10:50
---
用户指派修复 w-015 遗留项：非 unred frac 函数 `return a + b` 不自动约分（8/16 形态）。
**锁定范围：compiler/lib/mir.ml、grammar.md、grammar_tests/compile_report.md**——Trae 期间勿改。
方案：SReturnK 对 OLocal 且 TFrac 类型的返回值在 TRet 前 emit MNorm（返回类型不支持 unred，
凡直接返回 frac 一律约分；OGlobal/TErr 不在列）。

## 执行记录（WorkBuddy，2026-10-06 10:55）

- commit：**7a7ec9f**。改动：mir.ml SReturnK 在 TRet 前对 OLocal+TFrac 返回值 emit MNorm（5 行级改动）。
- 验证：探针五路径全对（addf(1/4,1/4)→1/2、直返形参 6/8→3/4、unred 局部返回→1/2、
  全局常量返回 OGlobal 跳过不受扰动、ginit 常量 1/2 1/3 不变）；bench 回归 53 例全 PASS；
  grammar_tests 12/12 编译通过（t10 的 addf 用例由 8/16 变 1/2）。
- grammar.md 补"frac 归一化语义"条目（存入与 return 均约分、unred 存储不约分、返回类型不支持 unred）。
- 状态：**done**。
