# zfy 编译器 Bug 报告

## 一句话

**`typeck.ml` 的自动 move 判定（`last_use` / `pos_after`）无法处理循环体内的变量使用，把循环体内反复使用的列表变量误判为「最后使用」，生成 `store ptr null` 清槽，导致下一轮迭代读到 null 列表，空指针解引用崩溃。**

## 现象

- **编译**：`zfyc build` 成功，无错误无警告。
- **运行**：程序在 `main` 入口前就崩，**连第一行 `output` 都不打**（因为崩在 `@main` 之前调用的 `@zfy.globals` 或 `@main` 早期）。
- **stderr**：无 panic、无任何消息，静默退出。
- **IR 层面**：`main.ll` 正常生成，`@big_sqrt` 里能看到 `store ptr null, ptr %v.r20` 的 move 清槽。

## 复现条件

变量满足全部：

1. 是**列表**（`i32[]`）局部变量。
2. **声明在循环体内**（外层 `while` 里）。
3. **同一次外层迭代里**，在内层 `while` 循环体中**反复使用**（如 `big_mul_add(r20, d, d*d)`）。
4. 作为**用户函数实参**传递（`big_mul_add`），触发自动 move 判定。

## 最小复现（推演）

```
fn i32[] f(let i32[] a)
    let i32[] out
    out = push(out, length(a))
    return out

fn main()
    let i32 i = 0
    while i < 2
        let i32[] r
        r = push(r, i)
        let i32 j = 0
        while j < 2
            let i32[] t = f(r)     # ← r 在循环体内反复使用，被误 move
            j++
        i++
```

第二层循环第二轮时 `r` 已是 null。

## 根因（源码定位）

`typeck.ml`：

```ocaml
and pos_after (a : pos) (b : pos) =
  a.file = b.file && (a.line > b.line || (a.line = b.line && a.col > b.col))

and last_use env n (p : pos) =
  not (List.exists (fun (m, q) -> m = n && pos_after q p) env.uses)
```

`env.uses` 是**整个函数体所有 `EVar` 出现位置的静态列表**，`last_use` 判「变量 n 在位置 p 之后是否还有出现」。

**缺陷**：用**源码位置**判「之后」。循环体里同一行 `big_mul_add(r20, d, d*d)` 的 `r20` 出现位置**每次运行时迭代都相同**。判定时：

- 当前位置 `p` = 内层循环里 `r20` 的位置。
- `env.uses` 里 `r20` 的其他出现（同一行、下一轮迭代）**位置相同**，`pos_after q p` 要求**严格晚于**，**不成立**。
- 所以 `last_use` 返回 **true** → `auto_moveable` 返回 true → 标记 move → 生成 `store ptr null`。

**一句话**：源码位置是静态的，循环迭代是动态的；`pos_after` 无法表达「同一位置的多次运行时复用」。

## 影响面

任何**「循环体内声明的列表变量 + 嵌套循环里反复作为函数实参」**的程序都会中招。包括：

- 大数运算（本案例）。
- 矩阵/多维数组处理。
- 任何在双层循环里反复传入同一列表的算法。

**且无编译期警告**——静默生成错误的 move，只在运行时崩。

## 附带发现（次要 bug）

1. **`zfy_seq_free` 调用参数不一致**：`main.ll` 里同时出现 `call void @zfy_seq_free(ptr %r)`（单参）和 `call void @zfy_seq_free(ptr %r, i8 0)`（双参），而声明是 `declare void @zfy_seq_free(ptr)`。**LLVM IR 非法**，但 `clang -O2` 链接时把双参当单参用（多传的参数被忽略），**能链接但语义可疑**。来源可能是 `llvmgen.ml` 里 `TArray _ | TList _` 的释放路径有一处多传了 `is_str` 标志。

2. **`@big_sqrt` 入口 alloca 数达 25 个**（19 个变量 + 5 个 i128 临时 + 1 个 i1 临时），未做合并——**不是 bug，但栈帧偏大**。

## 修复建议

**方案 A（最小改动）**：`last_use` 加循环感知——**循环体内声明的变量，在循环体内一律不自动 move**。需要 `env` 记录「当前循环体作用域深度」，`auto_moveable` 检查声明位置是否在循环内。

**方案 B（保守）**：**循环体内的 `EVar` 出现一律不参与「最后使用」判定**——即 `uses_of_expr` 收集位置时标记「是否在循环内」，`last_use` 忽略循环内的后向使用。

**方案 C（最稳）**：**列表/string 的自动 move 只在「函数体顶层语句」（非循环内）启用**，循环体内一律走 clone。

**推荐 B**——改动局部，语义清晰，不影响函数顶层（`t13` 那种「只调一次」的场景仍能正确 move 免拷贝）。

## 用户侧绕法（bug 修复前）

1. **变量移到循环外**：`r20` 声明提到外层 `while` 之前——但 `r20` 本身在内层循环被反复用，仍会中招。
2. **struct 包装**：`struct Big  i32[] d`，参数类型 `Big`——struct 传参走 `ptr_of`（借传槽地址），**不走列表自动 move**。
3. **`ref` 参数**：函数接收 `ref let i32[] a`——`CRef` 实参**不走自动 move**（`check_ref_arg` 直接取地址）。
4. **hack**：调用点后加一次使用（如 `r20 = push(r20, 0)`）——不可靠，破坏算法。

**方案 2 最彻底**，但要重写整个大数层。**方案 3 改动小**——把 `big_mul_add` 等函数的列表参数改成 `ref`。

## 证据链

| 步骤 | 测试 | 结果 |
|---|---|---|
| 1 | `big_cmp` 单独 | ✅ 正常 |
| 2 | `+ big_sub` | ✅ 正常 |
| 3 | `+ big_sqrt` 到 `L4`（`r20` 只调一次） | ✅ 正常 |
| 4 | `+ big_sqrt` 加内层循环（`r20` 反复用） | ❌ 连 `A` 都不打 |
| 5 | 去掉打点（`t17`） | ❌ 同样崩 |
| 6 | 单独测「循环内列表声明」`t6` | ✅ 正常 |
| 7 | 单独测「嵌套 while」`t7` | ✅ 正常 |
| 8 | 单独测「循环内 `let` 列表 = 函数调用」`t11` | ✅ 正常 |
| 9 | 单独测「bool 循环条件 + 循环内列表 + 赋值」`t9` | ✅ 正常 |
| 10 | IR 定位 | `b17` 里 `store ptr null, ptr %v.r20` |

**单项全过、组合必崩**——正是「循环体内反复使用 + 函数实参 move 判定」这个组合触发的。

## 结论

**这是 `typeck.ml` 自动 move 判定的循环语义缺陷，不是用户代码错误。** 当前 zfy 语言**无法可靠地表达「双层循环里反复传入同一列表变量」的算法**——除非用 struct 包装或 `ref` 参数绕开。建议优先修 `last_use` 的循环感知。