---
id: wb-let-fn-redesign
from: workbuddy
to: trae
status: done
created: 2026-10-10 18:10
---
用户指派按 new.md（2026-10-10 更新版）重构声明/函数语法。用户已拍板：
1. let 全替换旧标量声明（固定顺序 类型→frac→const→unred；类型/值二选一或都写；字面量推断 i32/f64/i32 frac/string/char/bool；有类型无值=零值）。
2. 数组/列表 let 后缀形式（let i32 x[]、let f64 frac y[128]）；顶层无限制；unred 须 frac 修饰或 n/d 形态初值。
3. fn 全替换旧函数语法（fn [T|void] [frac] [const] [unred] 名(...)）；main 必须 fn main()（隐含 i32，return 可省）；参数 let 形式全替换（let frac y → i32 frac；可 const/unred；move/copy/ref 在 let 前）。
4. 别名 10 词全删（short/ushort/int/uint/long/ulong/half/float/double/quad）。
5. 归一化全存储位：存入/return（已实现）+ 实参入口归一（新增）+ struct 字段/数组列表元素存 frac 归一（新增）。
**锁定范围：compiler/lib/*（tokens/lexer/parser/ast/typeck/hir/mir/llvmgen/driver）、compiler/runtime/runtime.c、grammar.md、examples/ 与 grammar_tests/（全量迁移旧语法）**——Trae 期间勿动上述文件。

---

## 执行记录（workbuddy，2026-10-10）

**已完成，commit `884e09f`。**

实现要点：
- tokens.ml：+KLet/KFn；-10 别名构造子及 keyword_table/pp_token 分支。
- parser.ml：parse_let_head（固定顺序）+ parse_let_stmt（多声明器，**开头须消费 let**）+
  parse_param（ref 前、let 后；ref+frac 报错；frac 隐含 i32）+ KFn 内联 parse_fn_def
  （tparams 在 ret 前、main 校验、tparams 注册 tynames）+ parse_for_decl 消费 let +
  input KLet 目标 + 旧形式报迁移提示（E2003/E2005）+ parse_item 补 catch-all（原 Match_failure 崩溃）+
  parse_let_head 允许函数类型（~allow_fun）。
- ast.ml：SDecl/SSeqDecl/FIDecl/param/IFn 加 is_frac/is_unred/enn/frunred 字段；ty option 化。
- typeck.ml：zty_to_ast；let 头部推断（lit_ty 递归 + checked 透传防二次检查）；unred 校验；
  main 豁免 E3111 + 裸 return 改写 return 0（落末尾由 mir TRet None → ret i32 0）。
- mir.ml：norm_frac_val（值侧归一：临时原地 MNorm / 变量源 MTempAlloca+MCopy+MNorm）；
  非 unred frac 参数入口归一；SSeqDeclK/SSeqSetK/EPushK 元素归一（unreds 豁免）；
  MTempAlloca 新指令（llvmgen 入口块 alloca）；lctx.frunred（unred 函数 SReturnK 跳过归一）。
- llvmgen.ml：main TInt 32 包装分支（E4012 扩为 void/i32/i64，driver/errors.md 同步）。
- 示例迁移：examples/migrate_let_fn.py（codemod：声明/fn/参数/for 头/input 目标/extern 参数/
  pub 前缀/struct 字段区跳过/残留别名→宽度名）全量迁移 examples + grammar_tests + bench + 根目录 .zfy；
  alias_test.zfy 改写为宽度名等价测试（别名↔宽度名一一对应，.out 输出不变）。
- grammar.md：§2/§3/§4/§5/§7/§9/§12 按 let/fn 重写；§8 归一化扩为全存储位；E4012 文案更新。

回归：examples 54 例（含 alias_test）+ grammar_tests 13 例 + _smoke.zfy 全部编译运行 PASS
（.out 输出逐字节对比一致）。

遗留给 Trae（见 inbox w-019）：errors.md 新文案登记、description.md 同步、
mir.ml frac 四则注释与实现不符问题依旧存在。
