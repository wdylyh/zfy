# 设计稿：zfy 文件 I/O（定稿待实施）

> 状态：设计已由用户拍板（2026-10-05），**尚未派发**。实施时转 w-0xx 给 Trae。
> 前置依赖：无（第一阶段刻意绕开 w-014 #1"函数返回列表"）。

## 一、类型语义：File 是 move-only 句柄

1. **move-only**：赋值/传参/返回只能 `move`，禁止深拷贝与隐式共享。
   `File g = move f`；`f(handle g)` / `return move f`。
   move 后原变量失效。
2. **失效统一运行期标记兜底**：move 后的原变量、close 后的句柄，任何操作
   （read/write/close 均含）→ 运行期 panic（复用 panic 通道，exit 101）。
   编译期可查的"同块内 move/ close 后复用"报编译错误（复用 E3013
   "has been moved" 机制）；编译期查不到的（跨分支/跨函数）一律运行期 panic。
   ——双保险：编译期尽量报，运行期绝不允许静默使用。
3. **作用域自动 close（RAII）**：函数退出时经 `emit_frees_from` 对仍有效的
   File 自动 close；**幂等**，已 close 的跳过。
4. **close 语义**：显式 `close(f)` 可选；**close 失败 → panic**
   （close 的错误无法被 `?` 接住——想要错误处理就不要依赖自动 close，
   但 close 本身不产 T!，失败即 panic，规则简单一致）。

## 二、第一阶段限制

- **File 不得作为 struct 字段**，只允许局部变量与参数。
  （struct 字段 + move-only + 值语义深拷贝三方冲突，等 move-only
  类型系统成熟再放开；编译期直接报错，给专门错误码。）
- File 不参与泛型（`Box<File>` 禁止，同理）。
- File 不支持数组/列表元素（同上，编译期报错）。

## 三、API（第一阶段）

```
File! f = open(path, mode)     // mode: "r" "w" "a"（P2 加 b 后缀）
string! s = read_all(f)        // 整读；IO 错误产 err（ErrCode.IO）
string! line = read_line(f)    // 单行（不含换行符）；EOF 产 err（ErrCode.EOF，新码）
write(f, s)                    // 原样写（不产 T!；写失败 panic？见"待定"）
writeln(f, s)                  // 写 + '\n'
close(f)                       // 幂等；失败 panic
bool e = exists(path)
```

一步式便捷版（open + 操作 + 自动 close）：
```
string! s = read_file(path)
write_file(path, s)!           // 覆盖写；? 传播
```

注意：`read_file` / `write_file` 的错误可被 `?`/`??` 正常处理；
`open` 产 T!，典型用法 `File! f = open("a.txt", "r")` 配 `?` 传播。

## 四、第二阶段（与"函数返回列表"同步落地）

```
string[]! read_lines(f)        // 依赖 w-014 #1
for string line in file        // for-in 语法糖（依赖 for-in 设计，另立任务）
```

## 五、明确不做 / 边界

- 文件按**字节透传（假定 UTF-8），不做编码转换**——Windows 控制台 GBK
  乱码属预期行为，写入文档。
- 不做：目录遍历、seek/随机访问、编码转换、符号链接。
- `remove_file` / `rename_file`（避免与内建 `remove(列表,下标)` 撞名）放
  第一阶段可选件，Trae 评估工作量后可挪 P2。

## 六、待定项（实施前需确认）

1. `write`/`writeln` 失败语义：写失败（磁盘满/权限）是 panic 还是产 T!？
   倾向：第一阶段 panic（与 close 一致），第二阶段如需精细化再改 T!。
2. 错误码分配：ErrCode.IO 已存在；EOF 需新码；"File 不得作 struct 字段"
   需新码。按 errors.md 现有分段规则分配。
3. mode 字符串是否接受非法值：建议编译期只查字面量合法集（"r"/"w"/"a"），
   非字面量运行期校验。

## 七、改动面清单（供排期参考）

- lexer/tokens：无新关键字（`File` 作内建类型名，与 string 同级处理）
- typeck：内建类型 File、内建函数表 6~8 项、move-only 约束检查、
  struct 字段/泛型/容器元素禁用检查
- mir/llvmgen：File 局部变量槽（handle + closed 标记双字段）、
  emit_frees_from 挂自动 close
- runtime：zfy_file_open/read_all/read_line/write/writeln/close（stdio 包装）
- errors.md / grammar.md / description.md 同步；examples 增 3~4 个用例
- 回归：现有 25 例不受影响（纯新增）
