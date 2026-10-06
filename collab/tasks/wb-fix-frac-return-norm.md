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
