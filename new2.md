好，既然你选 B（方法语法）、引擎要最好、语句要全套——那我把整个设计**收敛成一份可直接落地的 zfy 随机数模块方案**。

---

## 一、先定语法：struct 方法

zfy 现在的 struct 只有字段和构造（`Point(x=1)`）。要加方法，最小扩展是：

**定义侧**——在 struct 块内用 `fn` 声明方法，第一个参数隐式是 `ref let Self`：

```
struct Random
    u64 s0
    u64 s1
    u64 s2
    u64 s3

    fn u64 next_u64()
        ...

    fn i64 int(let i64 lo, let i64 hi)
        ...
```

**调用侧**——`rng.next_u64()`，等价于 `rand_next_u64(rng)`，`rng` 自动按 `ref` 传（因为方法需要改状态）。

**关键决策点：方法内 `self` 是 `ref` 还是 `copy`？**

zfy 默认深拷贝，那 `rng.next_u64()` 如果按值传，改的是副本——错。所以规则应该是：

- **方法默认 `ref let Self`**（可改调用方），除非方法体不修改任何字段。
- 提供修饰：`fn const ...` 表示只读方法（按值/按 const ref 传），`fn move ...` 表示消耗 self（对 File 那种 move-only 类型有用）。
- 但为了简单，**第一版就统一：方法第一参数 = `ref let Self`**。`Random` 反正都要改状态，`SecureRandom` 也一样。只读方法（如 `len()`）性能损失可忽略。

**方法调用与字段访问不冲突**：`rng.s0` 是字段，`rng.next_u64()` 是方法，`rng.s0()` 如果 s0 是字段就是字段——用后缀是否带 `()` 区分。

**方法不支持命名实参**（跟用户函数一致，§9 已定）。分布函数里需要命名参数的地方（概率 p、count k）就按位置传。

---

## 二、引擎：要最好的效果

你要"效果最好"——分两类：

### 非加密：xoshiro256\*\*

- 状态 4×u64 = 32 字节，全平台一致。
- 周期 2^256−1，通过 BigCrush 全套。
- 速度接近内存带宽，LLVM 能把它优化成几条寄存器运算。
- 种子扩展用 **SplitMix64**（这是标准做法，避免相近种子相关）。

```
struct Random
    u64 s0
    u64 s1
    u64 s2
    u64 s3
```

`next_u64()` 的核心（LLVM 友好）：

```
result = rotl(s1 * 5, 7) * 9
t = s1 << 17
s2 ^= s0
s3 ^= s1
s1 ^= s2
s0 ^= s3
s2 ^= t
s3 = rotl(s3, 45)
return result
```

`rotl(x, k) = (x << k) | (x >> (64 - k))` —— zfy 有 `<<` `>>` 吗？规范 §1 运算符表里**没有移位运算符**！这是必须补的语法。

**要补的运算符**：`<<` `>>` `&` `|` `^` `~`（位运算）。规范里只有 `&`（取地址）和 `^`（解引用后缀）。位运算整套都没有。随机数模块绕不开，**建议一起做了**：

```
<< >>        移位，左结合，优先级在 + - 之下、* / 之上（跟 C 一致）
& | ^        位与/或/异或，优先级低于比较
~            按位取反，一元
```

注意 `^` 有歧义：`p^` 是后缀解引用，`a ^ b` 是异或。用**位置**区分：后缀紧贴标识符无空格、二元两侧有操作数。词法上可行，但要在 parser 里小心。

### 加密：ChaCha20

- 状态 16×u32，key 256 位 + nonce + counter。
- 每 64 字节块产生一次 keystream，性能远超 AES-CTR（无硬件依赖时）。
- 从 OS 熵源播种：Linux `getrandom(2)`、Windows `BCryptGenRandom`、macOS `getentropy`。你 LLVM 后端可以直接 call 这些。

```
struct SecureRandom
    u32 state[16]
```

`next_u64()` 从 ChaCha20 keystream 取，块用尽自动递增 counter 重新生成。

### 为什么不用别的

- **PCG**：好，但 xoshiro256\*\* 更快且状态同样小。
- **Mersenne Twister**：状态 2.5KB，太大，初始化慢，已过时。
- **rand()/LCG**：质量差，淘汰。
- **AES-CTR**：有 AES-NI 时快，无硬件时慢且实现复杂。ChaCha20 更可移植。

---

## 三、完整 API：一整套语句/函数

### 3.1 Random struct 方法

```
struct Random
    u64 s0
    u64 s1
    u64 s2
    u64 s3

    # ===== 引擎原语 =====
    fn u64 next_u64()
    fn u32 next_u32()
    fn void fill_bytes(ref let u8 buf[])

    # ===== 均匀分布 =====
    fn f64 float()                    # [0, 1)，53 位精度
    fn f32 float32()                  # [0, 1)，24 位精度
    fn bool boolean()                 # p = 0.5
    fn bool boolean_p(let f64 p)      # 伯努利，p ∈ [0,1]

    # ===== 整数区间（命名强制语义）=====
    fn i64 int(let i64 lo, let i64 hi)        # [lo, hi) 半开
    fn i64 int_incl(let i64 lo, let i64 hi)   # [lo, hi] 闭
    fn u64 uint(let u64 lo, let u64 hi)       # [lo, hi)
    fn u64 uint_incl(let u64 lo, let u64 hi)  # [lo, hi]

    # ===== 分布 =====
    fn f64 normal(let f64 mean, let f64 stddev)   # 正态，Box-Muller
    fn f64 exponential(let f64 lambda)            # 指数
    fn i64 geometric(let f64 p)                   # 几何

    # ===== 序列 =====
    fn void shuffle(ref let i32 xs[])
    fn void shuffle_u64(ref let u64 xs[])
    fn void shuffle_string(ref let string xs[])
    fn i32 choice(let i32 xs[])                   # 均匀选一个
    fn i32[] sample(let i32 xs[], let i32 k)      # 无放回抽 k 个
    fn i32[] sample_weighted(let i32 xs[], let f64 weights[])

    # ===== 字符串 =====
    fn string string_bytes(let i32 n)             # n 个随机字节
    fn char ascii_char()                          # 可见 ASCII
    fn string hex_string(let i32 n)               # n 个 hex 字符
```

### 3.2 SecureRandom struct

```
struct SecureRandom
    u32 state[16]

    fn u64 next_u64()
    fn void fill_bytes(ref let u8 buf[])
    fn bool boolean()
    fn i64 int(let i64 lo, let i64 hi)
    fn string token(let i32 nbytes)          # URL-safe base64
    fn string hex_token(let i32 nhex)
    fn void reseed()                         # 重新从 OS 熵源
```

### 3.3 构造函数（自由函数，因为构造前无 self）

```
fn Random seed_from_i64(let i64 seed) -> Random
fn Random seed_from_u64(let u64 seed) -> Random
fn Random seed_from_string(let string s) -> Random
fn Random seed_from_entropy() -> Random        # 非加密，但用 OS 熵播种
fn SecureRandom secure_new() -> SecureRandom
fn SecureRandom secure_from_string(let string s) -> SecureRandom
```

**为什么不放 struct 里当静态方法**？zfy 现在没有静态方法语法，加自由函数成本最低。以后有了再说。

### 3.4 全局便捷实例（可选）

如果你想给用户一个"开箱即用"的：

```
mod random
    ...
    let Random global = seed_from_entropy()

# 用户
random.global.int(1, 10)
```

**但全局可变状态在并发下是灾难**。zfy 现在有没有协程/线程？规范里没提。如果暂时单线程，可以放一个全局 `Random`；如果有并发，必须 thread-local。**建议第一版不给全局**，强迫用户自己拿 `Random` 实例——这符合你设计里"显式优于隐式"的调性。

---

## 四、关键实现细节（避免踩坑）

### 4.1 整数区间：拒绝采样，杜绝模偏差

`next_u64() % n` 有模偏差。用 Lemire 方法（无除法、无偏）：

```
range = hi - lo                 # u64
m = next_u64() * range          # u128 乘法，取低 64 位和高 64 位
low = cast(m, u64)              # 低 64 位
if low < range
    threshold = (0 - range) % range
    while low < threshold
        m = next_u64() * range
        low = cast(m, u64)
return cast(lo + (m >> 64), i64)
```

zfy 有 u128（§3），正好用。`m >> 64` 取高 64 位——**这就是为什么必须有移位运算符**。

### 4.2 float：53 位精度

```
fn f64 Random.float()
    let u64 x = next_u64()
    return cast(x >> 11, f64) * (1.0 / 9007199254740992.0)   # 2^-53
```

`x >> 11` 取高 53 位，乘 2^−53 得 [0, 1)。**不要**用 `next_u64() / 2^64`——那个下取整会丢精度且可能取到 1.0。

### 4.3 f32：24 位精度

```
let u32 x = next_u32()
return cast(x >> 8, f32) * (1.0 / 16777216.0)   # 2^-24
```

### 4.4 正态分布：Box-Muller（或 Ziggurat）

Box-Muller 简单可靠，两行：

```
fn f64 Random.normal(let f64 mean, let f64 stddev)
    let f64 u1 = float()
    let f64 u2 = float()
    while u1 == 0.0
        u1 = float()
    let f64 r = sqrt(-2.0 * log(u1))
    let f64 theta = 2.0 * 3.141592653589793 * u2
    return mean + stddev * r * cos(theta)
```

`sqrt` `log` `cos` 需要数学内建——**zfy 现在没有数学函数**。要补：`sqrt` `log` `exp` `sin` `cos` `pow` `abs` `floor` `ceil`。这些 LLVM 直接映射到 `llvm.sqrt.f64` 等 intrinsic，或 libm call。工作量小，一起做了。

**性能更好**是 Ziggurat 算法，但实现复杂。第一版 Box-Muller 够用，标注"后续可换 Ziggurat"。

### 4.5 shuffle：Fisher-Yates

```
fn void Random.shuffle(ref let i32 xs[])
    let i64 n = cast(length(xs), i64)
    let i64 i = n - 1
    while i > 0
        let i64 j = int_incl(0, i)
        let i32 tmp = xs[i]
        xs[i] = xs[j]
        xs[j] = tmp
        i--
```

**不要用 `sort(by random)`**——那是有偏的且 O(n log n)。

### 4.6 种子扩展：SplitMix64

`seed_from_i64(42)` 不能直接把 42 塞进 s0 其他置零——相近种子会相关。用 SplitMix64 扩展：

```
fn Random seed_from_u64(let u64 seed)
    let u64 z = seed
    # 四次 SplitMix64，各产一个状态字
    z += 0x9E3779B97F4A7C15
    let u64 a = splitmix_final(z)
    z += 0x9E3779B97F4A7C15
    let u64 b = splitmix_final(z)
    z += 0x9E3779B97F4A7C15
    let u64 c = splitmix_final(z)
    z += 0x9E3779B97F4A7C15
    let u64 d = splitmix_final(z)
    let Random r = Random(s0=a, s1=b, s2=c, s3=d)
    # 防止全零状态（xoshiro 全零会死锁）
    if a == 0 and b == 0 and c == 0 and d == 0
        return seed_from_u64(0xDEADBEEF)
    return r

fn u64 splitmix_final(let u64 z)
    let u64 z1 = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
    let u64 z2 = (z1 ^ (z1 >> 27)) * 0x94D049BB133111EB
    return z2 ^ (z2 >> 31)
```

### 4.7 ChaCha20 播种

```
fn SecureRandom secure_new()
    let SecureRandom r = SecureRandom()   # 零初始化
    # 从 OS 熵源填 48 字节（key 32 + nonce 12 + 初始 counter 可随机）
    let u8 buf[48]
    os_random_bytes(ref buf)
    # 塞进 state[4..15]
    ...
    return r
```

`os_random_bytes` 是 extern：

```
extern "C"
    i32 getrandom(u8* buf, u64 len, u32 flags)    # Linux
    i32 BCryptGenRandom(u8* buf, u32 len, u32 flags)  # Windows
```

你可以在编译器里做平台分发，或用条件编译。

---

## 五、zfy 语言侧要补的东西（汇总）

做随机数模块会逼出这些语言特性：

| 需求 | 现状 | 动作 |
|---|---|---|
| 移位 `<< >>` | 无 | 加运算符，优先级同 C |
| 位运算 `& \| ^ ~` | 只有 `&` 取地址、`^` 后缀解引用 | 加二元位运算 + 一元 `~`，parser 处理 `^` 歧义 |
| struct 方法 | 无 | 加 `fn` in struct，默认 `ref let Self` |
| 数学内建 `sqrt/log/exp/sin/cos/pow` | 无 | 加，映射 LLVM intrinsic / libm |
| u128 运算（乘法高位） | 有类型 | 确认 `u64 * u64 → u128` 的乘法语义、`>> 64` 可用 |
| ref struct 参数 | §6 说标量/string/数组/列表可 ref | **确认/补 struct 可 ref** |
| 全局初始化调用 OS 熵源 | §15 说入口前执行 globals | 确认 globals 初始化能调 extern |
| `cast(i64, u64)` 跨符号 | §3 要求显式 cast | 确认可用 |

其中**位运算和 struct 方法**是硬依赖，其他可以绕过但很难看。

---

## 六、模块组织（最终形态）

```
mod random
    # ===== 非加密 =====
    pub struct Random
        u64 s0
        u64 s1
        u64 s2
        u64 s3

        fn u64 next_u64()
        fn u32 next_u32()
        fn void fill_bytes(ref let u8 buf[])
        fn f64 float()
        fn f32 float32()
        fn bool boolean()
        fn bool boolean_p(let f64 p)
        fn i64 int(let i64 lo, let i64 hi)
        fn i64 int_incl(let i64 lo, let i64 hi)
        fn u64 uint(let u64 lo, let u64 hi)
        fn u64 uint_incl(let u64 lo, let u64 hi)
        fn f64 normal(let f64 mean, let f64 stddev)
        fn f64 exponential(let f64 lambda)
        fn i64 geometric(let f64 p)
        fn void shuffle(ref let i32 xs[])
        fn i32 choice(let i32 xs[])
        fn i32[] sample(let i32 xs[], let i32 k)
        fn string hex_string(let i32 n)

    pub fn Random seed_from_i64(let i64 seed)
    pub fn Random seed_from_u64(let u64 seed)
    pub fn Random seed_from_string(let string s)
    pub fn Random seed_from_entropy()

    # ===== 加密 =====
    pub struct SecureRandom
        u32 state[16]

        fn u64 next_u64()
        fn void fill_bytes(ref let u8 buf[])
        fn bool boolean()
        fn i64 int(let i64 lo, let i64 hi)
        fn string token(let i32 nbytes)
        fn string hex_token(let i32 nhex)
        fn void reseed()

    pub fn SecureRandom secure_new()
    pub fn SecureRandom secure_from_string(let string s)
```

用户：

```
use random

fn main()
    let random.Random rng = random.seed_from_i64(42)
    let i64 n = rng.int(1, 100)
    let f64 x = rng.float()
    output("n=", n, " x=", x, "\n")

    let random.SecureRandom srng = random.secure_new()
    let string tok = srng.token(32)
    output("token=", tok, "\n")
```

注意：`rng.int(...)` 里的 `rng` 是 `let Random`（非 const），方法默认 `ref` 所以能改状态。如果用户写 `let Random const rng = ...`，方法调用应该报错（const 不可变，方法改状态违规）——这是**类型系统要处理的一致性检查**。

---

## 七、落地顺序（不管工作量，按依赖排）

1. **语言侧第一批**：位运算 `<< >> & | ^ ~` + parser 消歧 `^`
2. **语言侧第二批**：struct 方法语法（定义 + 调用 + `ref let Self` 默认）
3. **语言侧第三批**：数学内建 `sqrt log exp sin cos pow abs floor ceil`
4. **语言侧第四批**：确认 `ref struct`、`u64*u64→u128`、`extern` 调用 OS 熵源
5. **模块实现**：`Random`（xoshiro256\*\* + SplitMix64 播种 + SplitMix64 拒绝采样）
6. **模块实现**：`SecureRandom`（ChaCha20 + OS 熵源）
7. **分布**：float / int / shuffle / choice / sample / normal / exponential
8. **测试**：可复现性、均匀性卡方、相邻种子不相关、边界、性能基准

---

## 八、一句话总结

**引擎**：xoshiro256\*\*（非加密）+ ChaCha20（加密），SplitMix64 播种和种子扩展。**API**：`Random` / `SecureRandom` 两个 struct，方法语法 `rng.int(lo, hi)` 半开区间命名强制语义，`ref let Self` 默认。**必补语言特性**：移位/位运算、struct 方法、数学内建、`ref struct`。**必守的坑**：拒绝采样防模偏差、种子扩展防相关、float 用高 53 位、shuffle 用 Fisher-Yates、加密非加密类型隔离。

这套下来效果是"最好"级别的：引擎质量顶级、API 无歧义、安全边界靠类型系统强制。