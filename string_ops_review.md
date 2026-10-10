# zfy 字符串操作审查报告

> 审查范围：`length / find / trim / split / replace / prec` 内建 + `s[i]` 读写 + 切片 `s[a,b:step]` + `+`/`+=` 拼接 + `==`/`!=` 比较 + input(string)。
> 审查方式：通读 typeck.ml（check_builtin）/ mir.ml（EFindK/ESplitK/SStrSetK）/ runtime.c（zfy_str_*）+ 17 个行为实验全部实测。
> 日期：2026-10-10。所有结论均以实测输出为准。

---

## 一、结论摘要

- **1 个 P0 编译器 bug**：string 数组/列表元素的 `+=` 生成非法 LLVM IR，直接编译失败。
- **2 个功能缺口**：字符串无字典序比较（`< >`）；find 不支持子串查找。
- **3 处双路径行为不一致**：find 的 count 校验、ref string 的 `+=`、replace 两参/四参的边界。
- **1 个用户可见的乱码问题**：prec 按字节截断 UTF-8 中文产生非法序列。
- **其余核心路径（推断/拷贝/所有权/const 保护/越界 panic）实测健康**，详见 §6。

---

## 二、P0：string 数组/列表元素 `+=` 编译失败（bug）

### 修复方向（供拍板）
添加功能，支持对于字符串/字符的+=符号。

---

## 三、功能缺口（需要决定是否补）

### 1. 字符串没有字典序比较

补这个功能

### 2. find 不支持子串

补string

### 3. `"a" == 'a'`（string vs char）也不比

字符==中，按照ascii来比。字符串中，把里面每个字符来比，且一旦比到不同的字符直接不比了，返回不等于。
---

## 四、语义 / 一致性问题（每条独立拍板）

### 1. trim 的语义是"删除所有出现"，不是"去两端"

不改

### 2. find 的 count 校验：编译期与运行期行为不一致

这个解决方案我不知道，你提问工具问
### 3. replace 两参形式存在但文档没写，且与四参的边界不对称

删两参形式
### 4. 字节语义与 UTF-8：prec 截断产生非法字节序列

增加 UTF-8 感知 API

### 5. 负/零步长只到运行期才炸

字面量步长完全可以编译期拒绝（与 find count=0 的编译期检查同款）

### 6. ref string 参数不支持 `+=`（与 deref 整体赋值不一致）

deref 增广路径对 string 走"load → zfy_str_append → store 回引用槽"。

---

## 五、诊断 / DX 问题（小）

| # | 现象 | 现状 | 建议 |
|---|---|---|---|
| 1 | `s[1..3]`（`..` 写法） | `E2006: expected namespace member or field name (identifier), got .`——`1..3` 被解析成 `1` 后接 Dot 字段访问，报错完全不知所云 | Dot 分支检测基为整数字面量时提示"切片语法是 s[a,b:step]，不是 s[a..b]" |
| 2 | `s.find('l')` 方法调用 | `E3089: type string does not support field access find` | 追加提示"字符串内建是函数式：find(s, c)" |
| 3 | `trim(s, 65)`（int 实参） | `E3007: type ?T1 cannot convert to string`——显示未绑定类型变量 | char_or_str 的兜底分支报错文案改成"trim's argument 2 must be char or string, got i32"（find 的 E3083 文案就是对的，风格统一） |
| 4 | `split(s, '\0')` | c=0 ≥ 0 → 永不匹配 → 返回 `[s]`，无任何说明 | 文档写明，或编译期拒绝 '\0' 分隔符 |
可以的，都按你的建议
---

## 六、实测通过、无需担心的部分

| 能力 | 实测 |
|---|---|
| 字面量推断/零值/const 保护 | `let string const cs` 下标写 E3000 拒绝、`cs += x` E3014 拒绝 ✓ |
| 拷贝语义 | `t2 = s2` 后改 s2，t2 不受影响（MCopy strdup）✓ |
| 字面量槽可写 | `let s = "abc"; s[0]='X'` 安全（声明即 strdup，不写静态区）✓；全局 `let string g = "abc"` 同样安全 ✓ |
| `s[i]` 读写 | 越界/负下标 panic rc=101 ✓；struct 字段路径 `p.name[0]='T'` ✓ |
| 切片 | `s[1,3]`→"ell"、`s[0,4:2]`→"hlo"、两端含 ✓（语法是逗号 `s[a,b:step]`，grammar.md §117 已记） |
| `+` 与 `+=` | `"hello" + " world"` 新串 ✓；局部 `s += "b"` realloc 原地扩容（T7 优化）✓；`s += 5` 数字自动转串 ✓ |
| `==`/`!=` | strcmp 语义 ✓；字面量常量折叠 ✓ |
| find/count | 找第 k 次、找不到 NOT_FOUND、`??` 解包 ✓ |
| split | 单字符/多字符 delim、连续分隔符产生空段（`"a,,b"`→3 段）、空串→1 段 ✓；结果临时语句末释放/整体赋值 move 接管 ✓；`let p = split(...)[0]` 元素取出安全 ✓ |
| trim | char/子串/空子串（原样返回）✓ |
| replace | 四参闭区间、两参到尾、源串不被修改 ✓ |
| prec | ASCII 补空格/截断 ✓ |
| input | `let string name` + `input(name)` ✓；read_lines/遍历 ✓ |
| 内存 | 全轮次实验（17 个程序）无崩溃/乱码（除 prec 中文）/泄漏迹象；回归 67/67 仍 PASS |

---

## 七、代码级隐患（当前 Windows 构建无影响，记录备查）

1. **`zfy_str_append_n` 使用 `_msize`**（runtime.c）——MSVC CRT 专用。移植 Linux 需换 `malloc_usable_size`，macOS 需 `malloc_size`。是跨平台阻塞点。
2. `zfy_str_char/zfy_str_set` 的 idx 用 `long long` 与 `strlen` 的 `size_t` 混算——串 >2GB 理论上有符号问题（现实无虞）。
3. `zfy_str_trim_str` 的输出缓冲 `malloc(n+1)` 是最坏情况正确分配（无 bug，注明防误改）。
4. split_impl 已做 O(n) 预计数（旧 O(n²) 已修，注释保留）。

---

## 八、建议处理优先级（供拍板，非指令）

1. **必修**：§二 P0（元素 `+=` 非法 IR）——正确性问题，一句话复现。
2. **建议修**：§四.2（find count 双路径统一）、§四.3（replace 两参入文档）、§五.1-3（报错文案，成本低收益高）。
3. **要拍板的语义决策**：§三.1 字典序比较、§三.2 find 子串、§四.1 trim 改名、§四.4 UTF-8 策略、§四.6 ref string `+=`。
4. **顺手**：§四.5 步长编译期检查、§五.4 '\0' 分隔符。
