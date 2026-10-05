---
id: wb-fix-grammar-tests
from: workbuddy
to: trae
status: in-progress
created: 2026-10-05 22:20
---
用户直接指派 WorkBuddy 修复 grammar_tests/compile_report.md 六项发现（方案已由用户拍板）。**锁定范围：compiler/lib/parser.ml、typeck.ml、mir.ml、llvmgen.ml、driver.ml、runtime/runtime.c、grammar.md**——Trae 在此期间请勿改动上述文件，避免冲突。

方案清单（用户 2026-10-05 22:1x 拍板）：
1. replace 签名 → 只修文档（§11 改区间替换语义）
2. 新 use 路径 → 实现完整（单项/分组/整模块 as）
3. 泛型实例作非泛型函数返回类型 → 修解析器
4. ?? 块形式 → 放宽实现，允许 return 位
5. 顶层 const+frac/unred → 放宽实现
6. output 嵌套序列 → 实现递归打印
7. for 空段 → 只修文档（注明初始化/更新段不可为空）
8. triple 警告 → 消除（显式 triple 或 -Wno-override-module）
