# P0 缺陷总体规划（v2 · 一次到位版，待评审）

> 用户拍板：每项选**效果最好、最完善**的方案，不分阶段、不铺垫场，一次搞定。工作量不作为约束（仅供排期参考）。
> P0-2 跨平台按此前决定搁置（仅 API 命名保持中性，不做移植）。
> 调研依据见 v1：mir.ml 既有 RAII 栈（FStr/FSeq/FStruct + emit_frees_from_skip）、File 句柄范式、extern "C" 地基、panic handler/try 现状。

---

## P0-1 内存生命周期（一次到位）

**最终方案：完整所有权系统 —— RAII 主干 + 闭包逃逸分析 + iface move-only + 进程退出兜底清理。**

四件套同时落地，缺一不可（否则复评的"长期运行稳定泄漏"结论不消）：

### 1a. 句柄 RAII（mutex / chan / thread / File 统一）
- runtime 追加 `mutex_free` / `chan_free`（含对端阻塞 recv 的处理：free 前未 close 则 die；close 后释放节点与结构）/ thread env+句柄释放。
- mir.ml 释放分类新增 **FHandle**：句柄声明作用域退出自动 free（复用 emit_frees_from / emit_frees_from_skip，提前 return、break、panic 跳转路径全覆盖）。
- move 语义与 File 同构：typeck 同块复用拦截 + 运行时 moved 兜底。

### 1b. 接口 iface$X 完整所有权
- iface 值改 **move-only**：typeck 加同块复用检查（与 File 完全同构），句柄浅拷贝语义废止。
- 作用域退出发 `zfy_iface_release(data, ty)`：按 data 类型分发释放（string/seq/struct 嵌套深释放，复用既有 FStr/FSeq/FStruct 释放函数；iface 嵌套 iface 递归）。
- 存入全局/struct 字段的 iface：全局不释放（进程级，见 1d 兜底）；struct 字段随 struct 释放链级联。
- **不做 RC**：循环引用无解 + 与值语义基调冲突 + 给每次赋值插 retain/release 的开销不值得。move-only 是与语言现有所有权模型（File、闭包捕获移交）一致的最完备方案。

### 1c. 闭包环境逃逸分析（完整版，非简化白名单）
- typeck 对每个闭包做去向分析，env 三类结局全部覆盖：
  1. **直接调用**：调用后释放（FClo 类别，作用域栈出栈时发 free）；
  2. **spawn 移交**：env 所有权移交线程，线程体结束时线程侧释放（spawn 强制 move，typeck 拦截移交后使用）；
  3. **存续捕获**（赋变量/入 struct/返回/再捕获）：宿主作用域退出释放；嵌套捕获级联（内层 env 由外层释放函数调用）；**存全局不释放，走 1d 兜底**。
- mir.ml 新增 **FClo** 释放类别 + llvmgen 在闭包结构中保留 env 释放函数指针（结构体自描述析构，供级联）。

### 1d. 进程退出兜底（终结"借进程退出"的讽刺）
- runtime 维护 **全局资源注册表**（mutex/chan/iface/全局闭包 env 登记句柄；`atexit` 统一 release）。
- 目标承诺：任何路径（正常退出 / panic 退出 / handler 自定义退出）堆块要么 RAII 释放要么注册表释放，**文档可承诺零泄漏**（ZEM 错误 msg 的"有意最小泄漏"同步取消——msg 改由 try 捕获路径与注册表释放）。
- 附带：Debug 构建下注册表可输出未释放清单（泄漏报告，DX 加分项）。

**验证**：新增 examples/leak_test.zfy（长循环构造/释放闭包、iface、chan、mutex，进程内存 RSS 对拍基线）；regress 全绿。

---

## P0-3 并发安全边界（一次到位）

**最终方案：spawn 捕获白名单 + @sync 受保护变量标注，两件套同轮落地。**

1. **spawn 捕获规则（typeck 编译期强制）**：
   - 放行：整数/浮点/bool 标量（按值拷贝）、string（**按值移交**，sender 槽置空，复用 move 机制）、chan/mutex/thread 句柄（共享载体，本就为此设计）、标注 `@sync` 的全局变量。
   - 拒绝：seq/struct/enum/iface/闭包嵌套捕获（报错提示：经 chan 传值 / @global+mutex）。
2. **`@sync` 变量标注**：全局变量可标注 `@sync`，语义 = 必须在持有对应 mutex 时访问（`mutex.lock` 块形式建立"保护作用域"），作用域外裸读写 typeck 报错；原子内建（atomic_load/store/add/inc）豁免。这是 Send/Sync 在 zfy 无 trait 系统前提下的最强等价物，且编译期零运行时开销。
3. panic 时 mutex 的释放：P0-4 的 try 帧栈与 RAII 补释放覆盖 lock 块（panic 解锁，防死锁）。

**验证**：examples/sync_test.zfy（违规捕获逐一报错对拍、@sync 裸访问报错、lock 块 panic 后解锁不死锁）。

---

## P0-4 panic 策略（一次到位）

1. **退出码可配置**：编译器 flag `--panic-exit <n>`（默认 101）+ runtime 全局 `zfy_panic_exit`；所有退出路径（含 handler 返回后）统一走该码。
2. **try 嵌套帧栈**：zfy_try 改链表帧栈（jmp_buf + 前驱指针，压栈/弹栈），panic 弹最近帧，任意嵌套深度正确回卷。
3. **panic 路径 RAII 回卷**：编译器在 try 包装函数的 panic 出口补 emit_frees（复用 emit_frees_from_skip）；lock 块/mutex 作用域同理 panic 解锁。P0-1 的全部新类别（FHandle/FClo/FIface）自动获得 panic 路径覆盖。
4. **panic 行为档位**：`panic = exit | abort` 可选（--panic-mode flag；abort 供调试器断点场景）。handler 注册与 try 恢复保持不变。

---

## P0-5 FFI/ABI 一等公民（一次到位）

1. **C 调 zfy：完整头文件生成** `--emit-c-header`：
   - 顶层 fn → `zfy_...` 原型；**POD struct（纯标量/定长数组字段）同时生成 C struct 定义**（含对齐注释），可跨边界传值/传指针；
   - 含 string/seq/句柄/iface 参数的函数标注"仅句柄语义可跨边界"（string = char* UTF-8 所有权约定：跨边界一律克隆）并在头文件注释中写明；
   - 产出带 `#ifdef __cplusplus extern "C"` 包裹。
2. **链接声明语法**：`lib "user32" { extern fn i32 fnA(i32) }`——typeck 注册 extern_fns，编译器收集 link 指令传 clang；gui.zfy 现状迁移。
3. **ABI 承诺文档**（grammar.md 新章）：标量宽度/对齐表、调用约定（x64 Microsoft C）、返回值 ABI（含 i128/f128 sret 特判现状说明）、错误值容器布局（24/32 字节）、符号命名规则。
4. **导出标注**：`@export("name")` 可改导出符号名（默认 zfy_ 前缀），供 C 侧调用约定对齐。

---

## P0-6 包管理/可复现构建（一次到位，v1+v2 合并）

1. **项目清单 zfy.toml**：`[pkg] name/version/edition/compiler-min`、`[build] entry/lib`、`[link] libs`、`[deps]`（path 依赖 + git 依赖）。
2. **`zfyc build`**：读清单 → 从 entry 按 mod/use 闭包收集源（复用 resolve.ml 遍历）→ 依赖图构建（含 path/git 依赖各自 entry）→ 统一编译链接；单文件直编模式保留。
3. **可复现性**：
   - 产物嵌入编译器版本（`@zfy_compiler_ver` 符号）+ 源文件哈希清单（产物注释区）；
   - `zfy.lock`：依赖（git 依赖的 commit hash、path 依赖哈希）锁定，重复构建 bit-for-bit；
   - stdlib 版本随编译器（edition 号，衔接 P1-10 稳定性承诺：edition 声明保证行为不漂移）。
4. **依赖缓存**：git 依赖 clone 到本地缓存目录（~/.zfy/cache），锁 commit，幂等拉取。

---

## 实施顺序（一次到位，但仍有内部依赖序）

| 轮 | 内容 | 说明 |
|---|---|---|
| R1 | P0-3 全部（白名单 + @sync） | 先定捕获规则，P0-1 闭包释放规则依赖它 |
| R2 | P0-1 全部四件套（1a~1d）+ P0-4 全部 | panic 帧栈/RAII 回卷与释放类别同批实现最省，二者天然交织 |
| R3 | P0-5 全部 | 头文件生成需要 P0-1 的句柄语义定型后标注"可跨边界" |
| R4 | P0-6 全部 | link libs 语法与 P0-5 的 lib 声明共用基建 |

每轮回归 0 失败（69 例基线）+ 各自专项验证程序；P0-1 落地后 grammar.md 补"borrow 管栈值防拷贝、堆生命周期由所有权/RAII 管"口径，回应复评指出的误导风险。

## 附：复评清单其他项口径

- P1-7 借用：本轮不动（只读借用已自洽）；P0-1 落地后一并写清两层语义。
- P1-8 泛型/trait：WorkBuddy 侧 w-046 已落地约束泛型（`<T: num|cmp>`）+ 泛型 struct 方法，复评清单疑基于旧版本，下版复评前同步进度。
- P1-11 自动修复默认开启：列入 P2 待议。
