/* zfy 运行时：frac 分数类型 + output/input + 数组/列表 + 字符串方法
 *
 * 有值保证（方案 B）：变量永远有值，运行时不维护 present 位、不做无值传播。
 *  - print：直接输出值
 *  - input：EOF 或解析失败直接报运行时错误退出（fail-fast）
 *    delim 为空串（dlen=0）表示"换行和空格"字符集模式：' ' 或 '\n' 任一命中即切分
 *  - 数组/列表未初始化槽位为全零位模式（数值 0、bool false、char '\0'、string NULL）
 *  - zfy_free_str：free(NULL) 安全（string 槽可能是零值）
 *
 * frac.<suf> 是 { 分子, 分母 } 结构体。运算规则：
 *  - 加减：分母同分，分子加减；乘除：分子分母相乘（除法先检查除零）
 *  - 字面量/初值/输入的分数不自动约分
 *  - 运算结果（add/sub/mul/div）自动约分到最简（gcd，防溢出）；约分语句 reduce 保留
 *  - 中间结果用更宽类型计算，溢出时报运行时错误
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include <setjmp.h>

/* ---------- 异常机制（try/catch/throw）：自实现寄存器级 setjmp/longjmp ----------
 * 不使用 CRT 的 setjmp/longjmp：x64 Windows 的 msvcrt longjmp 走 RtlUnwindEx
 * SEH 展开，而编译器生成的函数无 unwind 信息，展开会崩溃（0xC0000409）。
 * 这里直接保存/恢复 callee-saved 寄存器 + 栈指针 + 控制字 + xmm6-15，
 * 纯寄存器恢复、不展开栈帧——RAII 清理由编译器生成的 catch 路径负责。
 *
 * zfy_try_setup：安装异常帧并保存上下文（returns_twice，LLVM 侧按调用约定处理）
 * zfy_throw：有 handler 则记录消息并跳回 try 点；无 handler 则报错退出
 * zfy_try_msg：catch 路径取走消息（并弹帧）；zfy_try_leave：try 正常完成后弹帧 */
typedef struct zfy_handler {
    unsigned long long env[10];  /* rbx rbp rsi rdi r12 r13 r14 r15 rsp rip */
    unsigned int mxcsr, fpucsr;
    unsigned long long xmm[10][2]; /* xmm6..xmm15 */
    char *msg;
    struct zfy_handler *prev;
} zfy_handler;

static zfy_handler *zfy_handler_top = NULL;

__attribute__((returns_twice)) int zfy_try_setup(zfy_handler *h) {
    h->msg = NULL;
    h->prev = zfy_handler_top;
    zfy_handler_top = h;
    int ret;
    __asm__ volatile
        ("movq %%rbx,   0(%1)\n\t"
         "movq %%rbp,   8(%1)\n\t"
         "movq %%rsi,  16(%1)\n\t"
         "movq %%rdi,  24(%1)\n\t"
         "movq %%r12,  32(%1)\n\t"
         "movq %%r13,  40(%1)\n\t"
         "movq %%r14,  48(%1)\n\t"
         "movq %%r15,  56(%1)\n\t"
         "movq %%rsp,  64(%1)\n\t"
         "leaq  1f(%%rip), %%rax\n\t"
         "movq %%rax,  72(%1)\n\t"
         "stmxcsr 80(%1)\n\t"
         "fnstcw  84(%1)\n\t"
         "movdqu %%xmm6,  88(%1)\n\t"
         "movdqu %%xmm7, 104(%1)\n\t"
         "movdqu %%xmm8, 120(%1)\n\t"
         "movdqu %%xmm9, 136(%1)\n\t"
         "movdqu %%xmm10, 152(%1)\n\t"
         "movdqu %%xmm11, 168(%1)\n\t"
         "movdqu %%xmm12, 184(%1)\n\t"
         "movdqu %%xmm13, 200(%1)\n\t"
         "movdqu %%xmm14, 216(%1)\n\t"
         "movdqu %%xmm15, 232(%1)\n\t"
         "xorl %%eax, %%eax\n"
         "1:\n"
        : "=a"(ret)
        : "S"(h->env)   /* 固定 rsi：避免与输出 rax 冲突；块内只读，安全 */
        : "memory");
    if (getenv("ZFY_DBG")) fprintf(stderr, "[dbg] try_setup ret=%d msg=%s h=%p\n", ret, h->msg ? h->msg : "(null)", (void*)h);
    return ret;
}

/* 恢复上下文：h 为异常帧（Windows x64：arg1=rcx，arg2=edx）。仅裸跳转，无栈展开 */
__attribute__((naked, noreturn)) void zfy_longjmp(zfy_handler *h, int val) {
    __asm__ volatile
        ("movq   0(%rcx), %rbx\n\t"
         "movq   8(%rcx), %rbp\n\t"
         "movq  16(%rcx), %rsi\n\t"
         "movq  24(%rcx), %rdi\n\t"
         "movq  32(%rcx), %r12\n\t"
         "movq  40(%rcx), %r13\n\t"
         "movq  48(%rcx), %r14\n\t"
         "movq  56(%rcx), %r15\n\t"
         "movq  64(%rcx), %rsp\n\t"
         "ldmxcsr 80(%rcx)\n\t"
         "fldcw  84(%rcx)\n\t"
         "movdqu  88(%rcx), %xmm6\n\t"
         "movdqu 104(%rcx), %xmm7\n\t"
         "movdqu 120(%rcx), %xmm8\n\t"
         "movdqu 136(%rcx), %xmm9\n\t"
         "movdqu 152(%rcx), %xmm10\n\t"
         "movdqu 168(%rcx), %xmm11\n\t"
         "movdqu 184(%rcx), %xmm12\n\t"
         "movdqu 200(%rcx), %xmm13\n\t"
         "movdqu 216(%rcx), %xmm14\n\t"
         "movdqu 232(%rcx), %xmm15\n\t"
         "movl %edx, %eax\n\t"
         "jmp *72(%rcx)");
}

void zfy_try_leave(void) {
    zfy_handler_top = zfy_handler_top->prev;
}

char *zfy_try_msg(void) {
    zfy_handler *h = zfy_handler_top;
    char *m = h->msg;
    zfy_handler_top = h->prev;
    if (getenv("ZFY_DBG")) fprintf(stderr, "[dbg] try_msg m=%s\n", m ? m : "(null)");
    return m; /* malloc 串，catch 绑定槽负责释放 */
}

void zfy_throw(char *msg) {
    zfy_handler *h = zfy_handler_top;
    if (!h) {
        fprintf(stderr, "runtime error: %s\n", msg);
        exit(1);
    }
    size_t n = strlen(msg) + 1;
    char *m = (char *)malloc(n);
    if (m) memcpy(m, msg, n); /* 分配失败则消息为 NULL，catch 侧容忍 */
    h->msg = m;
    zfy_longjmp(h, 1);
}

static void zfy_die(const char *msg) {
    zfy_throw((char *)msg);
}

/* 程序加载时调大 stdout 缓冲（默认 4KB）：大量逐行输出时减少系统调用。
 * 进程退出时 C 运行时自动 flush，无需手动处理 */
static char out_buf[1 << 16];
__attribute__((constructor)) static void zfy_io_init(void) {
    setvbuf(stdout, out_buf, _IOFBF, sizeof out_buf);
}

/* ---------- 串辅助（深拷贝语义 + 安全释放） ---------- */

/* 释放堆串：free(NULL) 安全（零值槽位） */
void zfy_free_str(char *s) {
    if (s) free(s);
}

/* 复制 C 字符串为堆串（NULL 透传） */
char *zfy_strdup(const char *s) {
    if (!s) return NULL;
    size_t n = strlen(s) + 1;
    char *r = (char *)malloc(n);
    if (!r) zfy_die("内存分配失败");
    memcpy(r, s, n);
    return r;
}

/* ---------- f64 -> int64 化整：乘 10^n 直到整数值 ---------- */

static int64_t zfy_frac_to_int(double x, const char *what) {
    double scale = 1.0;
    for (int k = 0; k <= 17; k++) {
        double s = x * scale;
        double r = round(s);
        if (fabs(s - r) <= 1e-9 * (fabs(s) > 1.0 ? fabs(s) : 1.0)) {
            if (r > 9.2233720368547748e18 || r < -9.2233720368547748e18)
                zfy_die("frac: 小数化整后溢出 i64");
            return (int64_t)r;
        }
        scale *= 10.0;
    }
    (void)what;
    zfy_die("frac: 分子/分母无法化整（十进制精度超限）");
    return 0;
}

/* ---------- 128 位整数转串 / 打印 ---------- */

static char *zfy_u128_to_str(unsigned __int128 v) {
    char tmp[64];
    int len = 0;
    if (v == 0) tmp[len++] = '0';
    while (v > 0) {
        tmp[len++] = (char)('0' + (int)(v % 10));
        v /= 10;
    }
    char *buf = (char *)malloc((size_t)len + 1);
    if (!buf) zfy_die("内存分配失败");
    for (int i = 0; i < len; i++) buf[i] = tmp[len - 1 - i];
    buf[len] = '\0';
    return buf;
}

void zfy_print_i128(__int128 v) {
    if (v < 0) {
        putchar('-');
        /* 防止 -INT128_MIN 取负回绕：按无符号处理负号 */
        unsigned __int128 u = (unsigned __int128)(-(v + 1)) + 1;
        char *s = zfy_u128_to_str(u);
        fputs(s, stdout);
        free(s);
    } else {
        char *s = zfy_u128_to_str((unsigned __int128)v);
        fputs(s, stdout);
        free(s);
    }
}

void zfy_print_u128(unsigned __int128 v) {
    char *s = zfy_u128_to_str(v);
    fputs(s, stdout);
    free(s);
}

/* ---------- tostr 家族：值 -> malloc 堆串（供 string 强转） ---------- */

char *zfy_tostr_char(char c) {
    char *buf = (char *)malloc(2);
    if (!buf) zfy_die("内存分配失败");
    buf[0] = c;
    buf[1] = '\0';
    return buf;
}

char *zfy_tostr_bool(int b) {
    return zfy_strdup(b ? "true" : "false");
}

char *zfy_tostr_i64(long long v) {
    char tmp[32];
    snprintf(tmp, sizeof tmp, "%lld", v);
    return zfy_strdup(tmp);
}

char *zfy_tostr_u64(unsigned long long v) {
    char tmp[32];
    snprintf(tmp, sizeof tmp, "%llu", v);
    return zfy_strdup(tmp);
}

char *zfy_tostr_i128(__int128 v) {
    if (v < 0) {
        unsigned __int128 u = (unsigned __int128)(-(v + 1)) + 1;
        char *body = zfy_u128_to_str(u);
        size_t n = strlen(body);
        char *buf = (char *)malloc(n + 2);
        if (!buf) zfy_die("内存分配失败");
        buf[0] = '-';
        memcpy(buf + 1, body, n + 1);
        free(body);
        return buf;
    }
    return zfy_u128_to_str((unsigned __int128)v);
}

char *zfy_tostr_u128(unsigned __int128 v) {
    return zfy_u128_to_str(v);
}

char *zfy_tostr_f64(double v) {
    char tmp[64];
    snprintf(tmp, sizeof tmp, "%f", v);
    return zfy_strdup(tmp);
}

/* ---------- prec：输出长度控制 ---------- */

/* 按总字符数 n 截断 / 右补空格；n<=0 得空串。返回 malloc 串（调用者释放） */
char *zfy_prec_str(const char *s, long long n) {
    if (n < 0) n = 0;
    size_t len = strlen(s);
    size_t nn = (size_t)n;
    char *buf = (char *)malloc(nn + 1);
    if (!buf) zfy_die("内存分配失败");
    if (nn <= len) {
        memcpy(buf, s, nn);
    } else {
        memcpy(buf, s, len);
        memset(buf + len, ' ', nn - len);
    }
    buf[nn] = '\0';
    return buf;
}

/* 数字字符 -> 数值（'6' -> 6）；非数字字符报运行时错误 */
long long zfy_char_digit(char c) {
    if (c < '0' || c > '9')
        zfy_die("prec 长度参数：char 必须是数字字符 '0'-'9'");
    return c - '0';
}

/* ---------- string -> 数值（运行时解析，C++ stoi/stod 语义：取前缀数字） ---------- */

long long zfy_stoi(const char *s) {
    char *end;
    long long v = strtoll(s, &end, 10);
    if (end == s)
        zfy_die("cast：无法把 string 解析为整数");
    return v;
}

double zfy_stod(const char *s) {
    char *end;
    double v = strtod(s, &end);
    if (end == s)
        zfy_die("cast：无法把 string 解析为浮点数");
    return v;
}

/* ---------- 浮点位模式辅助（half / quad 读写槽位） ---------- */

/* double -> IEEE half（binary16）位模式 */
static uint16_t zfy_dbl_to_half_bits(double f) {
    uint64_t b;
    memcpy(&b, &f, 8);
    unsigned sign = (unsigned)(b >> 63);
    unsigned exp = (unsigned)((b >> 52) & 0x7FF);
    uint64_t mant = b & 0xFFFFFFFFFFFFFULL;
    if (exp == 0 && mant == 0) return (uint16_t)(sign << 15);
    if (exp == 0x7FF) return (uint16_t)((sign << 15) | 0x7C00);
    long e = (long)exp - 1023 + 15;
    if (e >= 31) return (uint16_t)((sign << 15) | 0x7C00);       /* 溢出 -> inf */
    if (e > 0)
        return (uint16_t)((sign << 15) | ((unsigned)e << 10) |
                          (unsigned)(mant >> 42));
    /* 半精度非规格化 */
    uint64_t m10 = (mant | 0x10000000000000ULL) >> (42 + (1 - e));
    return (uint16_t)((sign << 15) | (m10 & 0x3FF));
}

/* double -> IEEE quad（binary128）位模式：已废弃（f128 改用 x86_fp80/long double） */

/* ---------- 整数版本宏 ---------- */

#define DEF_FRAC_INT(SUF, T, WT, WTC)                                     \
    typedef struct { T n; T d; } zfy_frac_##SUF;                          \
    static void zfy_frac_store_##SUF(zfy_frac_##SUF *o, WT n, WT d) {     \
        if ((T)n != n || (T)d != d)                                       \
            zfy_die("frac 运算溢出 " #SUF);                               \
        o->n = (T)n; o->d = (T)d; }                                       \
    void zfy_frac_add_##SUF(zfy_frac_##SUF *o, const zfy_frac_##SUF *a,   \
                            const zfy_frac_##SUF *b) {                    \
        WT an=a->n, ad=a->d, bn=b->n, bd=b->d, n, d;                      \
        WT n1, n2, dd;                                                    \
        if (__builtin_mul_overflow(an, bd, &n1) ||                        \
            __builtin_mul_overflow(bn, ad, &n2) ||                        \
            __builtin_mul_overflow(ad, bd, &dd) ||                        \
            __builtin_add_overflow(n1, n2, &n))                           \
            zfy_die("frac 加法溢出");                                     \
        zfy_frac_store_##SUF(o, n, dd); }                                 \
    void zfy_frac_sub_##SUF(zfy_frac_##SUF *o, const zfy_frac_##SUF *a,   \
                            const zfy_frac_##SUF *b) {                    \
        WT an=a->n, ad=a->d, bn=b->n, bd=b->d, n, d;                      \
        WT n1, n2, dd;                                                    \
        if (__builtin_mul_overflow(an, bd, &n1) ||                        \
            __builtin_mul_overflow(bn, ad, &n2) ||                        \
            __builtin_mul_overflow(ad, bd, &dd) ||                        \
            __builtin_sub_overflow(n1, n2, &n))                           \
            zfy_die("frac 减法溢出");                                     \
        zfy_frac_store_##SUF(o, n, dd); }                                 \
    void zfy_frac_mul_##SUF(zfy_frac_##SUF *o, const zfy_frac_##SUF *a,   \
                            const zfy_frac_##SUF *b) {                    \
        WT an=a->n, ad=a->d, bn=b->n, bd=b->d, n, d;                      \
        if (__builtin_mul_overflow(an, bn, &n) ||                         \
            __builtin_mul_overflow(ad, bd, &d))                           \
            zfy_die("frac 乘法溢出");                                     \
        zfy_frac_store_##SUF(o, n, d); }                                  \
    void zfy_frac_div_##SUF(zfy_frac_##SUF *o, const zfy_frac_##SUF *a,   \
                            const zfy_frac_##SUF *b) {                    \
        WT an=a->n, ad=a->d, bn=b->n, bd=b->d, n, d;                      \
        if (bn == 0) zfy_die("frac 除以零");                              \
        if (__builtin_mul_overflow(an, bd, &n) ||                         \
            __builtin_mul_overflow(ad, bn, &d))                           \
            zfy_die("frac 除法溢出");                                     \
        zfy_frac_store_##SUF(o, n, d); }                                  \
    _Bool zfy_frac_eq_##SUF(const zfy_frac_##SUF *a,                      \
                            const zfy_frac_##SUF *b) {                    \
        WTC l = (WTC)a->n * b->d, r = (WTC)b->n * a->d; return l == r; }  \
    _Bool zfy_frac_ne_##SUF(const zfy_frac_##SUF *a,                      \
                            const zfy_frac_##SUF *b) {                    \
        WTC l = (WTC)a->n * b->d, r = (WTC)b->n * a->d; return l != r; }  \
    _Bool zfy_frac_lt_##SUF(const zfy_frac_##SUF *a,                      \
                            const zfy_frac_##SUF *b) {                    \
        WTC l = (WTC)a->n * b->d, r = (WTC)b->n * a->d; return l < r; }   \
    _Bool zfy_frac_gt_##SUF(const zfy_frac_##SUF *a,                      \
                            const zfy_frac_##SUF *b) {                    \
        WTC l = (WTC)a->n * b->d, r = (WTC)b->n * a->d; return l > r; }   \
    _Bool zfy_frac_le_##SUF(const zfy_frac_##SUF *a,                      \
                            const zfy_frac_##SUF *b) {                    \
        WTC l = (WTC)a->n * b->d, r = (WTC)b->n * a->d; return l <= r; }  \
    _Bool zfy_frac_ge_##SUF(const zfy_frac_##SUF *a,                      \
                            const zfy_frac_##SUF *b) {                    \
        WTC l = (WTC)a->n * b->d, r = (WTC)b->n * a->d; return l >= r; }  \
    void zfy_frac_reduce_##SUF(zfy_frac_##SUF *x, int64_t cnt,            \
                               int64_t start) {                           \
        WT n = x->n, d = x->d;                                            \
        if (start < 2) start = 2;                                         \
        WT div = (WT)start;                                               \
        WT an = (n < 0 ? -n : n), ad = (d < 0 ? -d : d);                  \
        WT lim = an < ad ? an : ad;                                       \
        for (int64_t done = 0; done < cnt;) {                             \
            if (div > lim) break;                                         \
            if (div > 1 && n % div == 0 && d % div == 0) {                \
                n /= div; d /= div; done++;                               \
                an = (n < 0 ? -n : n); ad = (d < 0 ? -d : d);             \
                lim = an < ad ? an : ad;                                  \
            }                                                             \
            div++;                                                        \
        }                                                                 \
        x->n = (T)n; x->d = (T)d; }                                       \
    void zfy_frac_norm_##SUF(zfy_frac_##SUF *x) {                         \
        WT n = x->n, d = x->d;                                            \
        WT g = (n < 0 ? -n : n), t2 = (d < 0 ? -d : d);                   \
        while (t2) { WT tt = g % t2; g = t2; t2 = tt; }                   \
        if (g > 1 && d != 0) { n /= g; d /= g; }                          \
        x->n = (T)n; x->d = (T)d; }                                       \
    void zfy_frac_print_##SUF(const zfy_frac_##SUF *x) {                  \
        zfy_print_i128((__int128)x->n); putchar('/');                     \
        zfy_print_i128((__int128)x->d); }                                 \
    char *zfy_frac_str_##SUF(const zfy_frac_##SUF *x) {                   \
        char *sn = zfy_tostr_i128((__int128)x->n);                        \
        char *sd = zfy_tostr_i128((__int128)x->d);                        \
        size_t ln = strlen(sn), ld = strlen(sd);                          \
        char *buf = (char *)malloc(ln + 1 + ld + 1);                      \
        if (!buf) zfy_die("内存分配失败");                                 \
        memcpy(buf, sn, ln); buf[ln] = '/';                               \
        memcpy(buf + ln + 1, sd, ld + 1);                                 \
        free(sn); free(sd);                                               \
        return buf; }

/* (T)n != n 的窄化检查：宽值超出 T 范围时 (T) 回绕则不等 */

DEF_FRAC_INT(i8,  int8_t,  int64_t, __int128)
DEF_FRAC_INT(i16, int16_t, int64_t, __int128)
DEF_FRAC_INT(i32, int32_t, int64_t, __int128)
DEF_FRAC_INT(i64, int64_t, __int128, __int128)
DEF_FRAC_INT(i128, __int128, __int128, __int128)
DEF_FRAC_INT(u8,  uint8_t,  int64_t, __int128)
DEF_FRAC_INT(u16, uint16_t, int64_t, __int128)
DEF_FRAC_INT(u32, uint32_t, int64_t, __int128)
DEF_FRAC_INT(u64, uint64_t, unsigned __int128, unsigned __int128)
DEF_FRAC_INT(u128, unsigned __int128, unsigned __int128, unsigned __int128)

/* ---------- 浮点版本（分子分母先化整为 i64 计算，写回浮点） ---------- */

#define DEF_FRAC_FLT(SUF, T)                                                  \
    typedef struct { T n; T d; } zfy_frac_##SUF;                              \
    static void zfy_frac_storef_##SUF(zfy_frac_##SUF *o, int64_t n,           \
                                      int64_t d) {                            \
        o->n = (T)n; o->d = (T)d; }                                           \
    void zfy_frac_add_##SUF(zfy_frac_##SUF *o, const zfy_frac_##SUF *a,       \
                            const zfy_frac_##SUF *b) {                        \
        int64_t an=zfy_frac_to_int(a->n,"n"), ad=zfy_frac_to_int(a->d,"d");   \
        int64_t bn=zfy_frac_to_int(b->n,"n"), bd=zfy_frac_to_int(b->d,"d");   \
        __int128 n1=(__int128)an*bd, n2=(__int128)bn*ad;                      \
        __int128 dd=(__int128)ad*bd, n=n1+n2;                                 \
        if (n > (__int128)INT64_MAX || n < -(__int128)INT64_MAX ||            \
            dd > (__int128)INT64_MAX || dd < -(__int128)INT64_MAX)            \
            zfy_die("frac 加法溢出");                                         \
        int64_t nn=(int64_t)n, dn=(int64_t)dd;                                \
        zfy_frac_storef_##SUF(o, nn, dn); }                                   \
    void zfy_frac_sub_##SUF(zfy_frac_##SUF *o, const zfy_frac_##SUF *a,       \
                            const zfy_frac_##SUF *b) {                        \
        int64_t an=zfy_frac_to_int(a->n,"n"), ad=zfy_frac_to_int(a->d,"d");   \
        int64_t bn=zfy_frac_to_int(b->n,"n"), bd=zfy_frac_to_int(b->d,"d");   \
        __int128 n1=(__int128)an*bd, n2=(__int128)bn*ad;                      \
        __int128 dd=(__int128)ad*bd, n=n1-n2;                                 \
        if (n > (__int128)INT64_MAX || n < -(__int128)INT64_MAX ||            \
            dd > (__int128)INT64_MAX || dd < -(__int128)INT64_MAX)            \
            zfy_die("frac 减法溢出");                                         \
        int64_t nn=(int64_t)n, dn=(int64_t)dd;                                \
        zfy_frac_storef_##SUF(o, nn, dn); }                                   \
    void zfy_frac_mul_##SUF(zfy_frac_##SUF *o, const zfy_frac_##SUF *a,       \
                            const zfy_frac_##SUF *b) {                        \
        int64_t an=zfy_frac_to_int(a->n,"n"), ad=zfy_frac_to_int(a->d,"d");   \
        int64_t bn=zfy_frac_to_int(b->n,"n"), bd=zfy_frac_to_int(b->d,"d");   \
        __int128 n=(__int128)an*bn, d=(__int128)ad*bd;                        \
        if (n > (__int128)INT64_MAX || n < -(__int128)INT64_MAX ||            \
            d > (__int128)INT64_MAX || d < -(__int128)INT64_MAX)              \
            zfy_die("frac 乘法溢出");                                         \
        int64_t nn=(int64_t)n, dn=(int64_t)d;                                 \
        zfy_frac_storef_##SUF(o, nn, dn); }                                   \
    void zfy_frac_div_##SUF(zfy_frac_##SUF *o, const zfy_frac_##SUF *a,       \
                            const zfy_frac_##SUF *b) {                        \
        int64_t an=zfy_frac_to_int(a->n,"n"), ad=zfy_frac_to_int(a->d,"d");   \
        int64_t bn=zfy_frac_to_int(b->n,"n"), bd=zfy_frac_to_int(b->d,"d");   \
        if (bn == 0) zfy_die("frac 除以零");                                  \
        __int128 n=(__int128)an*bd, d=(__int128)ad*bn;                        \
        if (n > (__int128)INT64_MAX || n < -(__int128)INT64_MAX ||            \
            d > (__int128)INT64_MAX || d < -(__int128)INT64_MAX)              \
            zfy_die("frac 除法溢出");                                         \
        int64_t nn=(int64_t)n, dn=(int64_t)d;                                 \
        zfy_frac_storef_##SUF(o, nn, dn); }                                   \
    _Bool zfy_frac_eq_##SUF(const zfy_frac_##SUF *a,                          \
                            const zfy_frac_##SUF *b) {                        \
        return a->n * b->d == b->n * a->d; }                                  \
    _Bool zfy_frac_ne_##SUF(const zfy_frac_##SUF *a,                          \
                            const zfy_frac_##SUF *b) {                        \
        return a->n * b->d != b->n * a->d; }                                  \
    _Bool zfy_frac_lt_##SUF(const zfy_frac_##SUF *a,                          \
                            const zfy_frac_##SUF *b) {                        \
        return a->n * b->d < b->n * a->d; }                                   \
    _Bool zfy_frac_gt_##SUF(const zfy_frac_##SUF *a,                          \
                            const zfy_frac_##SUF *b) {                        \
        return a->n * b->d > b->n * a->d; }                                   \
    _Bool zfy_frac_le_##SUF(const zfy_frac_##SUF *a,                          \
                            const zfy_frac_##SUF *b) {                        \
        return a->n * b->d <= b->n * a->d; }                                  \
    _Bool zfy_frac_ge_##SUF(const zfy_frac_##SUF *a,                          \
                            const zfy_frac_##SUF *b) {                        \
        return a->n * b->d >= b->n * a->d; }                                  \
    void zfy_frac_reduce_##SUF(zfy_frac_##SUF *x, int64_t cnt,                \
                               int64_t start) {                               \
        int64_t n = zfy_frac_to_int(x->n, "n");                               \
        int64_t d = zfy_frac_to_int(x->d, "d");                               \
        if (start < 2) start = 2;                                             \
        int64_t div = start;                                                  \
        int64_t lim = llabs(n) < llabs(d) ? llabs(n) : llabs(d);              \
        for (int64_t done = 0; done < cnt;) {                                 \
            if (div > lim) break;                                             \
            if (div > 1 && n % div == 0 && d % div == 0) {                \
                n /= div; d /= div; done++;                                   \
                lim = llabs(n) < llabs(d) ? llabs(n) : llabs(d);          \
            }                                                                 \
            div++;                                                        \
        }                                                                     \
        x->n = (T)n; x->d = (T)d; }                                           \
    void zfy_frac_norm_##SUF(zfy_frac_##SUF *x) {                             \
        int64_t n = zfy_frac_to_int(x->n, "n");                               \
        int64_t d = zfy_frac_to_int(x->d, "d");                               \
        int64_t g1=(n<0?-n:n), g2=(d<0?-d:d);                                 \
        while (g2) { int64_t t=g1%g2; g1=g2; g2=t; }                          \
        if (g1 > 1 && d != 0) { n/=g1; d/=g1; }                               \
        x->n = (T)n; x->d = (T)d; }                                           \
    void zfy_frac_print_##SUF(const zfy_frac_##SUF *x) {                      \
        printf("%lld/%lld", (long long)zfy_frac_to_int(x->n, "n"),            \
               (long long)zfy_frac_to_int(x->d, "d")); }                      \
    char *zfy_frac_str_##SUF(const zfy_frac_##SUF *x) {                       \
        char tmp[160];                                                        \
        snprintf(tmp, sizeof tmp, "%lld/%lld",                                \
                 (long long)zfy_frac_to_int(x->n, "n"),                       \
                 (long long)zfy_frac_to_int(x->d, "d"));                      \
        return zfy_strdup(tmp); }

DEF_FRAC_FLT(f32, float)
DEF_FRAC_FLT(f64, double)

/* ---------- output 运行时支持 ---------- */

/* 输出 C 字符串（不追加换行，不解释格式符） */
void zfy_print_str(const char *s) {
    fputs(s, stdout);
}

/* 输出有/无符号整数 */
void zfy_print_i64(long long v) {
    printf("%lld", v);
}
void zfy_print_u64(unsigned long long v) {
    printf("%llu", v);
}

/* 输出小数 */
void zfy_print_f64(double v) {
    printf("%f", v);
}

/* 输出单个字符 */
void zfy_print_char(char c) {
    putchar(c);
}

/* 输出布尔值 */
void zfy_print_bool(int b) {
    fputs(b ? "true" : "false", stdout);
}

/* ---------- input 运行时支持 ---------- */

/* stdin 快速缓冲读取：整块 fread 进自管缓冲，替代逐字符 getchar()
 * （每次 getchar 都走 stdio 锁与调度，1 万整数输入约 6 万次调用）。
 * 当前语言单线程，无并发读 stdio 的场景 */
static char in_buf[1 << 16];
static size_t in_len = 0, in_pos = 0;
static int in_eof = 0;

static int in_getc(void) {
    if (in_pos >= in_len) {
        if (in_eof) return EOF;
        in_len = fread(in_buf, 1, sizeof in_buf, stdin);
        in_pos = 0;
        if (in_len == 0) { in_eof = 1; return EOF; }
    }
    return (unsigned char)in_buf[in_pos++];
}

/* 读入一段输入：读到 delim 整串或 EOF 为止（delim 本身不包含在结果内）。
 * dlen=0（delim 空串）为字符集模式：' ' 或 '\n' 任一命中即切分（该字符消费掉）。
 * 多字符 delim 用朴素滑动窗口整串匹配。
 * 返回 malloc 的缓冲区；saw_delim=1 表示以 delim 结束，0 表示以 EOF 结束。
 * 每个命中 delim 的位置切换下一段（连续 delim 产生空段） */
static char *read_segment(const char *delim, long long dlen, int *saw_delim) {
    size_t cap = 64, len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) zfy_die("input: 内存分配失败");
    *saw_delim = 0;
    for (;;) {
        int c = in_getc();
        if (c == EOF) break;
        if (dlen == 0) {
            /* 字符集模式：空格或换行任一命中即切分 */
            if (c == ' ' || c == '\n') {
                *saw_delim = 1;
                break;
            }
            if (len + 2 > cap) {
                cap *= 2;
                char *nb = (char *)realloc(buf, cap);
                if (!nb) zfy_die("input: 内存分配失败");
                buf = nb;
            }
            buf[len++] = (char)c;
        } else {
            if (len + 2 > cap) {
                cap *= 2;
                char *nb = (char *)realloc(buf, cap);
                if (!nb) zfy_die("input: 内存分配失败");
                buf = nb;
            }
            buf[len++] = (char)c;
            /* 检查缓冲区末尾是否恰好构成完整 delim */
            if ((long long)len >= dlen &&
                memcmp(buf + len - dlen, delim, (size_t)dlen) == 0) {
                len -= (size_t)dlen;
                *saw_delim = 1;
                break;
            }
        }
    }
    buf[len] = '\0';
    return buf;
}

/* 解析辅助：失败返回 0（由调用方决定报错） */
static int try_i64(const char *s, long long *out) {
    char *end;
    errno = 0;
    long long v = strtoll(s, &end, 10);
    while (*end == ' ' || *end == '\t' || *end == '\r' || *end == '\n') end++;
    if (end == s || *end != '\0' || errno == ERANGE) return 0;
    *out = v;
    return 1;
}

static int try_u128(const char *s, unsigned __int128 *out) {
    while (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n') s++;
    if (*s < '0' || *s > '9') return 0;
    unsigned __int128 v = 0;
    for (; *s >= '0' && *s <= '9'; s++) {
        unsigned __int128 nv = v * 10 + (unsigned)(*s - '0');
        if (nv < v) return 0;            /* 回绕即溢出 */
        v = nv;
    }
    while (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n') s++;
    if (*s != '\0') return 0;
    *out = v;
    return 1;
}

static int try_i128(const char *s, __int128 *out) {
    while (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n') s++;
    int neg = 0;
    if (*s == '-') { neg = 1; s++; }
    else if (*s == '+') s++;
    unsigned __int128 u;
    if (!try_u128(s, &u)) return 0;
    if (neg) {
        if (u > ((unsigned __int128)1 << 127)) return 0;   /* > 2^127 */
        /* 取负按模意义回绕，u == 2^127 时正好得到 INT128_MIN */
        *out = (__int128)(0 - u);
    } else {
        if (u > (((unsigned __int128)-1) >> 1)) return 0;  /* > 2^127-1 */
        *out = (__int128)u;
    }
    return 1;
}

static int try_f64(const char *s, double *out) {
    char *end;
    errno = 0;
    double v = strtod(s, &end);
    while (*end == ' ' || *end == '\t' || *end == '\r' || *end == '\n') end++;
    if (end == s || *end != '\0') return 0;
    *out = v;
    return 1;
}

/* 读段并判定"无输入"：EOF 且没读到任何字符 */
static char *input_segment(const char *delim, long long dlen, int *no_input) {
    int saw = 0;
    /* stdout 为全缓冲（zfy_io_init），读输入前先刷出未换行的提示语 */
    fflush(stdout);
    char *seg = read_segment(delim, dlen, &saw);
    *no_input = (!saw && seg[0] == '\0');
    return seg;
}

/* string 目标：重新赋值时先释放旧串；EOF 无输入报运行时错误 */
void zfy_input_str(void *val, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    if (no_input) {
        free(seg);
        zfy_die("input: EOF（无输入可读）");
    }
    zfy_free_str(*(char **)val);
    *(char **)val = seg;              /* 缓冲区所有权转移给变量 */
}

/* 整数目标（≤64 位）：EOF 或解析失败报运行时错误 */
void zfy_input_i64(void *val, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    long long v;
    if (no_input) {
        free(seg);
        zfy_die("input: EOF（无输入可读）");
    }
    if (!try_i64(seg, &v)) {
        free(seg);
        zfy_die("input: 无法把输入解析为整数");
    }
    *(long long *)val = v;
    free(seg);
}

/* i128 目标 */
void zfy_input_i128(void *val, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    __int128 v;
    if (no_input) {
        free(seg);
        zfy_die("input: EOF（无输入可读）");
    }
    if (!try_i128(seg, &v)) {
        free(seg);
        zfy_die("input: 无法把输入解析为整数");
    }
    *(__int128 *)val = v;
    free(seg);
}

/* u128 目标 */
void zfy_input_u128(void *val, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    unsigned __int128 v;
    if (no_input) {
        free(seg);
        zfy_die("input: EOF（无输入可读）");
    }
    if (!try_u128(seg, &v)) {
        free(seg);
        zfy_die("input: 无法把输入解析为整数");
    }
    *(unsigned __int128 *)val = v;
    free(seg);
}

/* 浮点目标：mode=0 f64（8B）、1 f32（4B）、2 f16（2B）、3 f128（16B，long double 80 位扩展精度） */
void zfy_input_f64(void *val, const char *delim, int mode) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    double v;
    if (no_input) {
        free(seg);
        zfy_die("input: EOF（无输入可读）");
    }
    if (!try_f64(seg, &v)) {
        free(seg);
        zfy_die("input: 无法把输入解析为小数");
    }
    switch (mode) {
    case 1: *(float *)val = (float)v; break;
    case 2: {
        uint16_t h = zfy_dbl_to_half_bits(v);
        memcpy(val, &h, 2);
        break;
    }
    case 3: *(long double *)val = (long double)v; break;   /* f128 = x86_fp80（与 LLVM 侧一致） */
    default: *(double *)val = v; break;
    }
    free(seg);
}

/* 布尔目标：接受 "true"/"false"，其余按整数解析（非零为真） */
void zfy_input_bool(void *val, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    if (no_input) {
        free(seg);
        zfy_die("input: EOF（无输入可读）");
    }
    if (strcmp(seg, "true") == 0) {
        *(char *)val = 1;
    } else if (strcmp(seg, "false") == 0) {
        *(char *)val = 0;
    } else {
        long long v;
        if (!try_i64(seg, &v)) {
            free(seg);
            zfy_die("input: 无法把输入解析为布尔值");
        }
        *(char *)val = (char)(v != 0);
    }
    free(seg);
}

/* 字符目标：取该段首字符 */
void zfy_input_char(void *val, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    if (no_input || seg[0] == '\0') {
        free(seg);
        zfy_die("input: EOF（无输入可读）");
    }
    *(char *)val = seg[0];
    free(seg);
}

/* ---------- 数组/列表运行时支持（按元素宽度存储） ---------- */

/* 定长数组与列表统一表示（与 LLVM 的 %zfy.seq = { ptr, ptr, i64 } 前三字段
 * 布局一致，len 在偏移 16；第二字段为占位（历史 present 位图，现已废弃），
 * cap/elemsz 仅供运行时内部使用）：
 *  - data：元素按 elemsz 字节连续存储，未初始化槽位为全零位模式
 *  - len：当前元素个数（定长数组不变，列表可扩长）
 *  - cap：容量（列表扩长用）
 *  - elemsz：元素字节数 */
typedef struct {
    void *data;
    void *_pad;
    long long len;
    long long cap;
    long long elemsz;
} zfy_seq;

/* 分配一个全零位模式槽位的数组/列表（数值 0、bool false、char '\0'、string NULL） */
zfy_seq *zfy_seq_new(long long count, long long cap, long long elemsz) {
    if (count < 0 || cap < count) zfy_die("数组/列表长度非法");
    if (cap < 1) cap = 1;
    zfy_seq *s = (zfy_seq *)malloc(sizeof(zfy_seq));
    if (!s) zfy_die("数组: 内存分配失败");
    s->len = count;
    s->cap = cap;
    s->elemsz = elemsz;
    s->data = malloc((size_t)cap * (size_t)elemsz);
    s->_pad = NULL;
    if (!s->data) zfy_die("数组: 内存分配失败");
    memset(s->data, 0, (size_t)cap * (size_t)elemsz);
    return s;
}

/* 列表扩长到 need 个元素：容量按需加倍 realloc，新增槽位填零值 */
static void seq_grow(zfy_seq *s, long long need) {
    if (need <= s->cap) {
        /* 容量已够：只把 len 到 need 之间的新槽位填零值 */
        memset((char *)s->data + (size_t)s->len * (size_t)s->elemsz, 0,
               (size_t)(need - s->len) * (size_t)s->elemsz);
        s->len = need;
        return;
    }
    long long ncap = s->cap * 2;
    if (ncap < need) ncap = need;
    void *nd = realloc(s->data, (size_t)ncap * (size_t)s->elemsz);
    if (!nd) zfy_die("列表扩长: 内存分配失败");
    memset((char *)nd + (size_t)s->len * (size_t)s->elemsz, 0,
           (size_t)(need - s->len) * (size_t)s->elemsz);
    s->data = nd;
    s->cap = ncap;
    s->len = need;
}

/* 下标检查：负数或（不可扩长时）越界报错；grow=1 时先扩长 */
static void seq_check(zfy_seq *s, long long idx, unsigned char grow) {
    if (idx < 0) zfy_die("数组/列表下标不能为负");
    if (grow && idx >= s->len) seq_grow(s, idx + 1);
    else if (idx >= s->len) zfy_die("数组下标越界");
}

/* 内联边界检查的失败路径（LLVM 侧 icmp ult 失败时调用；不返回） */
void zfy_bounds_fail(void) {
    zfy_die("数组/列表下标越界");
}

/* 指向第 idx 个元素的指针 */
static void *seq_at(const zfy_seq *s, long long idx) {
    return (char *)s->data + idx * s->elemsz;
}

/* 写入标量元素位模式：bits 为 i128 位模式，取低 width 字节（小端） */
void zfy_seq_set_w(zfy_seq *s, long long idx, unsigned __int128 bits,
                   int width, unsigned char grow) {
    seq_check(s, idx, grow);
    memcpy(seq_at(s, idx), &bits, (size_t)width);
}

/* 写入 string 元素：深拷贝（数组独占堆串）；替换时释放旧串 */
void zfy_seq_set_str(zfy_seq *s, long long idx, const char *str,
                     unsigned char grow) {
    seq_check(s, idx, grow);
    char **slot = (char **)seq_at(s, idx);
    zfy_free_str(*slot);
    *slot = zfy_strdup(str);
}

/* 元素读取：写入 16 字节 i128 位模式缓冲（越界报错）。
 * 窄整数按符号扩展到 128 位；string 走低 64 位（由 LLVM 侧 inttoptr 还原） */
void zfy_seq_get(const zfy_seq *s, long long idx, void *out, int width,
                 unsigned char sgn) {
    if (idx < 0 || idx >= s->len) zfy_die("数组/列表下标越界");
    unsigned __int128 bits = 0;
    memcpy(&bits, seq_at(s, idx), (size_t)width);
    if (sgn && width < 16) {
        unsigned shift = (unsigned)(128 - width * 8);
        bits = (unsigned __int128)(((__int128)bits << shift) >> shift);
    }
    memcpy(out, &bits, 16);
}

/* 释放 seq：free_elems=1 时逐元素释放堆串（string 数组/列表；零值槽 free(NULL) 安全） */
void zfy_seq_free(zfy_seq *s, unsigned char free_elems) {
    if (!s) return;
    if (free_elems)
        for (long long i = 0; i < s->len; i++)
            free(*(char **)seq_at(s, i));
    free(s->data);
    free(s);
}

/* 深拷贝 seq（数组/列表整体赋值）：string 元素一并复制 */
zfy_seq *zfy_seq_clone(const zfy_seq *src, unsigned char is_str) {
    if (!src) return NULL;
    zfy_seq *s = (zfy_seq *)malloc(sizeof(zfy_seq));
    if (!s) zfy_die("数组赋值: 内存分配失败");
    s->len = src->len;
    s->cap = src->len > 0 ? src->len : 1;
    s->elemsz = src->elemsz;
    s->_pad = NULL;
    s->data = malloc((size_t)s->cap * (size_t)s->elemsz);
    if (!s->data) zfy_die("数组赋值: 内存分配失败");
    memcpy(s->data, src->data, (size_t)src->len * (size_t)src->elemsz);
    memset((char *)s->data + (size_t)src->len * (size_t)src->elemsz, 0,
           (size_t)(s->cap - src->len) * (size_t)src->elemsz);
    if (is_str)
        for (long long i = 0; i < s->len; i++) {
            char **slot = (char **)seq_at(s, i);
            *slot = zfy_strdup(*slot);
        }
    return s;
}

/* remove(数组, idx)：把 idx 槽位填零值（长度不变）。
 * string 元素先释放旧堆串（零值槽 free(NULL) 安全）；越界报错 */
void zfy_seq_zero(zfy_seq *s, long long idx, unsigned char free_elems) {
    if (!s) zfy_die("remove: 源为空");
    if (idx < 0 || idx >= s->len) zfy_die("remove: 数组下标越界");
    void *slot = seq_at(s, idx);
    if (free_elems) zfy_free_str(*(char **)slot);
    memset(slot, 0, (size_t)s->elemsz);
}

/* remove(列表, idx)：删除第 idx 个元素，后续元素左移，长度 -1。
 * string 元素（free_elems=1）先释放被删的堆串；越界报错 */
void zfy_seq_remove(zfy_seq *s, long long idx, unsigned char free_elems) {
    if (!s) zfy_die("remove: 源为空");
    if (idx < 0 || idx >= s->len) zfy_die("remove: 列表下标越界");
    void *slot = seq_at(s, idx);
    if (free_elems) zfy_free_str(*(char **)slot);
    memmove(slot, (char *)slot + s->elemsz,
            (size_t)(s->len - idx - 1) * (size_t)s->elemsz);
    s->len--;
    memset((char *)s->data + s->len * s->elemsz, 0, (size_t)s->elemsz);
}

/* 切片复合赋值 a[a..b:step] op= v：对区间内每个元素原地做 op（逐元素读-算-写）。
 * op: 0=+ 1=- 2=* 3=/ 4=%；val 为 i128 位模式缓冲指针（低 width 字节有效）；
 * 整数中间运算用 __int128，截断回 width 后不一致则报溢出；除零报错 */
void zfy_seq_aug_range(zfy_seq *s, long long a, long long b, long long step,
                       int op, const void *val, int width, int sgn,
                       int is_float) {
    if (!s) zfy_die("复合赋值: 源为空");
    if (step < 1) zfy_die("切片步长必须 >= 1");
    if (a < 0 || b >= s->len || a > b) zfy_die("切片区间越界");
    for (long long i = a; i <= b; i += step) {
        void *slot = seq_at(s, i);
        if (is_float) {
            if (width == 4) {
                float f, v;
                memcpy(&f, slot, 4);
                memcpy(&v, val, 4);
                switch (op) {
                case 0: f += v; break;
                case 1: f -= v; break;
                case 2: f *= v; break;
                case 3: if (v == 0.0f) zfy_die("除以零"); f /= v; break;
                default: zfy_die("浮点不支持取模");
                }
                memcpy(slot, &f, 4);
            } else {
                double d, v;
                memcpy(&d, slot, 8);
                memcpy(&v, val, 8);
                switch (op) {
                case 0: d += v; break;
                case 1: d -= v; break;
                case 2: d *= v; break;
                case 3: if (v == 0.0) zfy_die("除以零"); d /= v; break;
                default: zfy_die("浮点不支持取模");
                }
                memcpy(slot, &d, 8);
            }
        } else {
            unsigned __int128 mask =
                width >= 16 ? ~(unsigned __int128)0
                            : (((unsigned __int128)1 << (width * 8)) - 1);
            unsigned __int128 x = 0, vv = 0;
            memcpy(&x, slot, (size_t)width);
            memcpy(&vv, val, (size_t)width);
            if (sgn && width < 16) {
                unsigned sh = (unsigned)(128 - width * 8);
                x = (unsigned __int128)(((__int128)x << sh) >> sh);
                vv = (unsigned __int128)(((__int128)vv << sh) >> sh);
            }
            if (width >= 16) {
                /* i128/u128：运算由硬件回绕，不做溢出检查 */
                __int128 r;
                switch (op) {
                case 0: r = (__int128)x + (__int128)vv; break;
                case 1: r = (__int128)x - (__int128)vv; break;
                case 2: r = (__int128)x * (__int128)vv; break;
                case 3:
                    if (vv == 0) zfy_die("除以零");
                    r = (__int128)x / (__int128)vv;
                    break;
                case 4:
                    if (vv == 0) zfy_die("取模除零");
                    r = (__int128)x % (__int128)vv;
                    break;
                default: r = 0;
                }
                unsigned __int128 tb = (unsigned __int128)r & mask;
                memcpy(slot, &tb, (size_t)width);
            } else {
                __int128 r;
                switch (op) {
                case 0: r = (__int128)x + (__int128)vv; break;
                case 1: r = (__int128)x - (__int128)vv; break;
                case 2: r = (__int128)x * (__int128)vv; break;
                case 3:
                    if (vv == 0) zfy_die("除以零");
                    r = (__int128)x / (__int128)vv;
                    break;
                case 4:
                    if (vv == 0) zfy_die("取模除零");
                    r = (__int128)x % (__int128)vv;
                    break;
                default: r = 0;
                }
                /* 溢出检查：截断回 width 再符号/零扩展，须与原结果一致 */
                unsigned __int128 tb = (unsigned __int128)r & mask;
                __int128 back;
                if (sgn) {
                    unsigned sh = (unsigned)(128 - width * 8);
                    back = (__int128)(tb << sh) >> sh;
                } else {
                    back = (__int128)tb;
                }
                if (back != r) zfy_die("复合赋值溢出");
                memcpy(slot, &tb, (size_t)width);
            }
        }
    }
}

/* 切片 base[a..b]（两端含，步长 step）：越界报错退出；返回新 seq（深拷贝）。
 * string 元素（is_str=1）对每个元素 strdup，保证切片独占堆串 */
zfy_seq *zfy_seq_slice(const zfy_seq *s, long long a, long long b,
                       long long step, unsigned char is_str) {
    if (!s) zfy_die("切片: 源为空");
    if (step < 1) zfy_die("切片步长必须 >= 1");
    if (a < 0 || b >= s->len || a > b) zfy_die("切片区间越界");
    long long n = (b - a) / step + 1;
    zfy_seq *r = zfy_seq_new(n, n, s->elemsz);
    long long j = 0;
    for (long long i = a; i <= b; i += step, j++) {
        if (is_str) {
            char *dup = zfy_strdup(*(char **)seq_at(s, i));
            memcpy(seq_at(r, j), &dup, sizeof(dup));
        } else {
            memcpy(seq_at(r, j), seq_at(s, i), (size_t)s->elemsz);
        }
    }
    return r;
}

/* ---------- 字符串方法运行时支持 ---------- */

/* s[i]：读单个字符（越界报错） */
char zfy_str_char(const char *s, long long idx) {
    long long n = (long long)strlen(s);
    if (idx < 0 || idx >= n) zfy_die("字符串下标越界");
    return s[idx];
}

/* s[a..b]（两端含），按步长 step 收集字符，返回 malloc 新串 */
char *zfy_str_slice(const char *s, long long a, long long b, long long step) {
    long long n = (long long)strlen(s);
    if (step < 1) zfy_die("字符串切片步长必须 >= 1");
    if (a < 0 || b >= n || a > b) zfy_die("字符串切片区间越界");
    char *buf = (char *)malloc((size_t)((b - a) / step) + 2);
    if (!buf) zfy_die("字符串切片: 内存分配失败");
    long long len = 0;
    for (long long i = a; i <= b; i += step) buf[len++] = s[i];
    buf[len] = '\0';
    return buf;
}

/* 找第 k 次出现（k 从 1 起）；不存在返回 -1；k < 1 报运行时错误 */
long long zfy_str_find(const char *s, char c, long long k) {
    if (k < 1) zfy_die("find: count 必须 > 0");
    for (long long i = 0, seen = 0; s[i]; i++) {
        if (s[i] == c) {
            seen++;
            if (seen == k) return i;
        }
    }
    return -1;
}

/* 删除字符串中所有字符 c，返回 malloc 新串 */
char *zfy_str_trim(const char *s, char c) {
    size_t n = strlen(s);
    char *buf = (char *)malloc(n + 1);
    if (!buf) zfy_die("trim: 内存分配失败");
    size_t len = 0;
    for (size_t i = 0; i < n; i++)
        if (s[i] != c) buf[len++] = s[i];
    buf[len] = '\0';
    return buf;
}

/* 删除字符串中所有子串 sub（多字符整串匹配），返回 malloc 新串 */
char *zfy_str_trim_str(const char *s, const char *sub) {
    size_t sl = strlen(sub);
    if (sl == 0) return zfy_strdup(s);
    size_t n = strlen(s);
    char *buf = (char *)malloc(n + 1);
    if (!buf) zfy_die("trim: 内存分配失败");
    size_t len = 0;
    for (size_t i = 0; i < n; ) {
        if (i + sl <= n && memcmp(s + i, sub, sl) == 0) {
            i += sl;                    /* 跳过整个子串 */
        } else {
            buf[len++] = s[i++];
        }
    }
    buf[len] = '\0';
    return buf;
}

/* 把 [a, b]（两端含）区间替换为 rep，返回 malloc 新串 */
char *zfy_str_replace(const char *s, long long a, long long b, const char *rep) {
    long long n = (long long)strlen(s);
    if (a < 0 || b >= n || a > b) zfy_die("replace 区间越界");
    size_t rl = strlen(rep);
    char *buf = (char *)malloc((size_t)a + rl + (size_t)(n - 1 - b) + 1);
    if (!buf) zfy_die("replace: 内存分配失败");
    long long len = 0;
    for (long long i = 0; i < a; i++) buf[len++] = s[i];
    for (size_t i = 0; i < rl; i++) buf[len++] = rep[i];
    for (long long i = b + 1; i < n; i++) buf[len++] = s[i];
    buf[len] = '\0';
    return buf;
}

/* 从下标 a 起替换到串尾为 rep，返回 malloc 新串 */
char *zfy_str_replace_from(const char *s, long long a, const char *rep) {
    long long n = (long long)strlen(s);
    if (a < 0 || a > n) zfy_die("replace 区间越界");
    size_t rl = strlen(rep);
    char *buf = (char *)malloc((size_t)a + rl + 1);
    if (!buf) zfy_die("replace: 内存分配失败");
    long long len = 0;
    for (long long i = 0; i < a; i++) buf[len++] = s[i];
    for (size_t i = 0; i < rl; i++) buf[len++] = rep[i];
    buf[len] = '\0';
    return buf;
}

/* 拼接两个字符串，返回 malloc 新串 */
char *zfy_str_concat(const char *a, const char *b) {
    size_t la = strlen(a), lb = strlen(b);
    char *buf = (char *)malloc(la + lb + 1);
    if (!buf) zfy_die("字符串拼接: 内存分配失败");
    memcpy(buf, a, la);
    memcpy(buf + la, b, lb);
    buf[la + lb] = '\0';
    return buf;
}

/* 按分隔符切分为 string 列表：返回 zfy_seq（元素宽度 8=指针），
 * 各段为 malloc 堆串、len = 段数（连续分隔符产生空段）。
 * 内部公共实现：c>=0 按单字符，否则按 delim 整串 */
static zfy_seq *split_impl(const char *s, char c, const char *delim) {
    size_t dl = (c >= 0) ? 1 : strlen(delim);
    if (dl == 0) {
        /* 空分隔符：不切分，返回单段 [s] */
        zfy_seq *seq = zfy_seq_new(1, 1, 8);
        char *seg = zfy_strdup(s);
        memcpy(seq_at(seq, 0), &seg, sizeof(seg));
        return seq;
    }
    long long cnt = 1;
    for (const char *p = s; *p; p++)
        if ((c >= 0 && *p == c) ||
            (c < 0 && (size_t)(p - s) + dl <= strlen(s) &&
             memcmp(p, delim, dl) == 0))
            cnt++;
    zfy_seq *seq = zfy_seq_new(cnt, cnt, 8);
    const char *start = s;
    long long i = 0;
    const char *p = s;
    for (;;) {
        int hit = 0;
        if (c >= 0) {
            hit = (*p == c);
        } else if (*p != '\0') {
            hit = (memcmp(p, delim, dl) == 0);
        }
        if (hit || *p == '\0') {
            size_t seglen = (size_t)(p - start);
            char *seg = (char *)malloc(seglen + 1);
            if (!seg) zfy_die("split: 内存分配失败");
            memcpy(seg, start, seglen);
            seg[seglen] = '\0';
            memcpy(seq_at(seq, i), &seg, sizeof(seg));
            i++;
            if (*p == '\0') break;
            start = p + dl;
            p = start - 1;              /* for 循环 p++ 后指向下一段开头 */
        }
        p++;
    }
    return seq;
}

/* 按单字符分隔符切分 */
zfy_seq *zfy_str_split(const char *s, char c) {
    return split_impl(s, c, "");
}

/* 按多字符分隔串切分（整串匹配） */
zfy_seq *zfy_str_split_str(const char *s, const char *delim) {
    return split_impl(s, -1, delim);
}
