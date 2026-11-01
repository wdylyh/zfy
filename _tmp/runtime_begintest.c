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
#ifndef ZFY_FREESTANDING
#include <malloc.h>                  /* 宿主堆扩展（裸机无此头） */
#endif
#include <time.h>                    /* 时间内建（v3.3.6）：time/mktime/localtime */

/* ---------- 裸机内存层（§31 --freestanding）----------
   裸机无宿主堆：本文件所有 malloc/free/realloc/calloc 经宏重定向到
   zfy_malloc/zfy_free（弱符号，用户可提供自己的实现覆盖）。
   默认实现是 16MB 静态缓冲的 bump 分配器：不回收（free 空操作），
   每块带 16 字节头记录长度，故 realloc 可“新分配 + 拷贝”。
   注意：整段仅在 ZFY_FREESTANDING 下生效，宿主构建行为一字不变。 */
#ifdef ZFY_FREESTANDING
#define ZFY_FS_POOL_SIZE (16u * 1024u * 1024u)
static unsigned char zfy_fs_pool[ZFY_FS_POOL_SIZE] __attribute__((aligned(16)));
static size_t zfy_fs_off = 0;
typedef struct { size_t size; } zfy_fs_hdr;

__attribute__((weak)) void *zfy_malloc(size_t n) {
    /* 头部 16 字节 + 数据按 16 字节对齐 */
    size_t need = sizeof(zfy_fs_hdr) + ((n + 15u) & ~(size_t)15);
    if (zfy_fs_off + need > sizeof(zfy_fs_pool)) return NULL;
    zfy_fs_hdr *h = (zfy_fs_hdr *)(void *)(zfy_fs_pool + zfy_fs_off);
    h->size = n;
    zfy_fs_off += need;
    return (void *)(h + 1);
}

__attribute__((weak)) void zfy_free(void *p) { (void)p; /* bump：不回收 */ }

__attribute__((weak)) void *zfy_realloc(void *p, size_t n) {
    if (!p) return zfy_malloc(n);
    zfy_fs_hdr *h = ((zfy_fs_hdr *)p) - 1;
    void *q = zfy_malloc(n);
    if (q) memcpy(q, p, h->size < n ? h->size : n);
    return q;
}

__attribute__((weak)) void *zfy_calloc(size_t cnt, size_t sz) {
    size_t n = cnt * sz;
    void *q = zfy_malloc(n);
    if (q) memset(q, 0, n);
    return q;
}

#define malloc(n) zfy_malloc(n)
#define free(p) zfy_free(p)
#define realloc(p, n) zfy_realloc(p, n)
#define calloc(n, s) zfy_calloc(n, s)
#endif /* ZFY_FREESTANDING */
#ifdef _WIN32
#include <io.h>                      /* _isatty（交互控制台探测） */
#ifndef ZFY_FREESTANDING
/* COM 的 C 语言接口形态：d2d1/dwrite/wincodec/dxgi 头文件需要这两个宏
   才会产出可直接调用的 vtbl 结构与 ID2D1Factory_CreateXxx 之类的宏。
   必须在任何系统头（windows.h 及其传递包含）之前定义。 */
#define CINTERFACE
#define COBJMACROS
#include <windows.h>                 /* OS 熵源（SystemFunction036 动态加载） */
#endif
#else
#include <unistd.h>                  /* isatty / getentropy */
#endif
#include <errno.h>

/* ---------- 致命错误（除零/越界/内存不足等）：统一走 panic 通道 ----------
   与 panic 语句共用 zfy_panic：有注册 handler 先回调（code=0），否则打印
   后 exit(101)。new2.md #3：panic 通道可注册 handler、默认 abort、不可
   被 ?/?? 捕获。 */

void zfy_panic(int32_t code, char *msg); /* 前向声明（定义在 ZEM 段后） */

/* ---- 前向声明：seq 基础设施（定义在 seq 段，read_lines 提前使用） ---- */
typedef struct zfy_seq zfy_seq;
typedef struct zfy_ops zfy_ops;
zfy_seq *zfy_seq_new_k(long long count, long long cap, long long elemsz,
                       int kind, zfy_ops *ops);
void zfy_seq_set_str(zfy_seq *s, long long idx, const char *str,
                     unsigned char grow);

static void zfy_die(const char *msg) {
    zfy_panic(0, (char *)msg);
}

/* ---------- ZEM 错误模型运行时 ----------
 * 错误值 zfy_err = { int32_t code; char* msg; value 容器 }，LLVM 侧布局
 * %err.<T> = { i32, ptr, i64/double/ptr }，二者偏移一致（24 字节）。
 * 约定：code=0 表示成功（value 有效，msg=NULL）；code≠0 时 value 未定义。
 * msg 一律走受跟踪分配器（zfy_msg_strdup），进程退出时统一释放（零泄漏）。
 * 自定义错误码 ≥ 100 由源码直接写字面量；0-99 为标准码：
 * OK=0 DIV_ZERO=1 OOB=2 NOT_FOUND=3 IO=4 CAST=5 INPUT=6 EOF=7 */
enum {
    ZFY_EOK = 0, ZFY_EDIV_ZERO = 1, ZFY_EOOB = 2, ZFY_ENOT_FOUND = 3,
    ZFY_EIO = 4, ZFY_ECAST = 5, ZFY_EINPUT = 6, ZFY_EEOF = 7
};

typedef struct zfy_err {
    int32_t code;
    char *msg;
    union {
        long long i;
        double d;
        void *p;
    } value;
} zfy_err;

/* panic 用户处理器（panic_handler(f) 注册；签名 (i32, string) -> void） */
static void (*zfy_panic_handler)(int32_t, char *) = NULL;

/* panic 位置追踪（v3.5 DX）：编译器在每条语句入口写当前 file/line，
   zfy_panic 打印 "  at file:line"（runtime 内部越界/除零等同样带位置） */
int zfy_cur_line = 0;
const char *zfy_cur_file = NULL;

void zfy_set_panic_handler(void (*h)(int32_t, char *)) {
    zfy_panic_handler = h;
}

char *zfy_strdup(const char *s); /* 前向声明（zfy_strdup 定义在后） */
char *zfy_msg_strdup(const char *s); /* 前向声明：受跟踪的错误消息串（退出时统一释放） */

/* panic：不可恢复。有 handler 先调用（用户可自定义输出），随后退出进程。
   handler 是 zfy 函数，string 参数按所有权约定接管——克隆走受跟踪分配器，
   退出时统一释放（P0-1d 零泄漏口径）。 */
/* ---- panic 恢复（v3.27 P0-4：链表帧栈 + 行为档位）----
 * try(f) 内建：帧栈（jmp_buf + 前驱指针）支持任意嵌套深度——panic 弹
 * 最近帧 longjmp 回对应 zfy_try（返回 0=发生 panic / 1=正常完成）。
 * 无帧时走 handler 或打印 + 退出。
 * 退出行为可配置（P0-4a/d）：
 *   - zfy_panic_exit：退出码（默认 101，编译器 --panic-exit <n> 设置）；
 *   - zfy_panic_abort：非 0 时 abort()（调试器断点场景，--panic-mode abort）。
 * 编译器生成侧在 MPanic 调用前补 RAII 释放（emit_frees + unlock 回卷），
 * 覆盖 panic 语句所在函数的局部资源与锁。 */
#ifndef ZFY_FREESTANDING
#include <setjmp.h>
typedef struct zfy_try_frame {
    struct zfy_try_frame *prev;
    jmp_buf jb;
} zfy_try_frame;
static zfy_try_frame *zfy_try_top = NULL;
static char zfy_panic_msg_buf[512];

int zfy_panic_exit = 101;        /* panic 退出码（--panic-exit 可改） */
int zfy_panic_abort = 0;         /* 1 = abort()（--panic-mode abort） */
void zfy_set_panic_exit(int code) { zfy_panic_exit = code; }
void zfy_set_panic_abort(int on) { zfy_panic_abort = on; }

int zfy_try(void (*fn)(void *), void *env) {
    zfy_try_frame fr;
    fr.prev = zfy_try_top;
    if (setjmp(fr.jb) == 0) {
        zfy_try_top = &fr;
        fn(env);
        zfy_try_top = fr.prev;   /* 正常完成：弹栈 */
        return 1;
    }
    /* longjmp 回来时 zfy_panic 已弹栈（zfy_try_top = fr.prev） */
    return 0;
}

const char *zfy_panic_msg(void) {
    return zfy_panic_msg_buf;
}

void zfy_panic(int32_t code, char *msg) {
    fflush(stdout);
    if (zfy_try_top) {
        snprintf(zfy_panic_msg_buf, sizeof(zfy_panic_msg_buf), "%s",
                 msg ? msg : "");
        zfy_try_frame *fr = zfy_try_top;
        zfy_try_top = fr->prev;  /* 弹栈后再跳（嵌套外层帧继续可捕） */
        longjmp(fr->jb, 1);
    }
    if (zfy_panic_handler) {
        zfy_panic_handler(code, zfy_msg_strdup(msg ? msg : ""));
    } else if (code == 0) {
        fprintf(stderr, "panic: %s\n", msg ? msg : "");
    } else {
        fprintf(stderr, "panic: %s (code %d)\n", msg ? msg : "", code);
    }
    if (zfy_cur_line > 0 && !zfy_panic_handler) {
        fprintf(stderr, "  at %s:%d\n", zfy_cur_file ? zfy_cur_file : "?", zfy_cur_line);
    }
    if (zfy_panic_abort) abort();
    exit(zfy_panic_exit);
}

#else /* ZFY_FREESTANDING：裸机 panic 骨架 */
/* 无 setjmp/longjmp、无 exit/abort、无 stderr。
   panic 直接调用用户 panic_handler(code=0, msg)；handler 约定不返回
   （loop 或 asm("hlt")）。若用户 handler 意外返回，在此挂起（不引入 OS 退出）。 */
void zfy_set_panic_exit(int code) { (void)code; }
void zfy_set_panic_abort(int on) { (void)on; }
const char *zfy_panic_msg(void) { return ""; }

void zfy_panic(int32_t code, char *msg) {
    if (zfy_panic_handler) zfy_panic_handler(code, msg ? msg : "");
    for (;;) { /* 用户 handler 应已停止执行；返回则死循环挂起 */ }
}
#endif /* ZFY_FREESTANDING */


/* 错误值快捷填充 */
static void err_set(zfy_err *out, int32_t code, const char *msg) {
    out->code = code;
    out->msg = zfy_msg_strdup(msg);
    out->value.i = 0;
}

static void err_ok_i(zfy_err *out, long long v) {
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value.i = v;
}

/* string -> 整数（错误值版：解析失败产 CAST 错误，取前缀数字，C++ stoi 语义） */
void zfy_stoi_err(zfy_err *out, const char *s) {
    char *end;
    long long v = strtoll(s, &end, 10);
    if (end == s) {
        err_set(out, ZFY_ECAST, "cast：无法把 string 解析为整数");
    } else {
        err_ok_i(out, v);
    }
}

/* 128 位整数错误值容器（new.md 2026-10-11）：32 字节，与 LLVM
 * %err.i128 = { i32, ptr, i128 } 布局一致（x64：4+4pad+8+16） */
typedef struct zfy_err_wide {
    int32_t code;
    char *msg;
    __int128 value;
} zfy_err_wide;

static void err_wide_set(zfy_err_wide *out, int32_t code, const char *msg) {
    out->code = code;
    out->msg = zfy_msg_strdup(msg);
    out->value = 0;
}

/* string -> 128 位整数（错误值版）：解析失败/越界产 CAST 错误（不终止）。
 * u128 目标复用本函数（负号按位模式回绕，与 fail-fast 通道一致） */
void zfy_stoi_wide_err(zfy_err_wide *out, const char *s) {
    unsigned __int128 v = 0;
    const char *p = s;
    while (*p == ' ' || *p == '\t') p++;
    int neg = 0;
    if (*p == '+' || *p == '-') { neg = (*p == '-'); p++; }
    if (*p < '0' || *p > '9') {
        err_wide_set(out, ZFY_ECAST, "cast：无法把 string 解析为整数");
        return;
    }
    for (; *p >= '0' && *p <= '9'; p++) {
        unsigned d = (unsigned)(*p - '0');
        if (v > ((~(unsigned __int128)0) - d) / 10) {
            err_wide_set(out, ZFY_ECAST, "cast：整数超出 128 位范围");
            return;
        }
        v = v * 10 + d;
    }
    while (*p == ' ' || *p == '\t') p++;
    if (*p != '\0') {
        err_wide_set(out, ZFY_ECAST, "cast：无法把 string 解析为整数（尾随字符）");
        return;
    }
    if (neg) {
        if (v > (unsigned __int128)1 << 127) {
            err_wide_set(out, ZFY_ECAST, "cast：整数超出 128 位范围");
            return;
        }
        v = (unsigned __int128)0 - v;
    }
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value = (__int128)v;
}

/* string -> 浮点（错误值版） */
void zfy_stod_err(zfy_err *out, const char *s) {
    char *end;
    double v = strtod(s, &end);
    if (end == s) {
        err_set(out, ZFY_ECAST, "cast：无法把 string 解析为浮点数");
    } else {
        out->code = ZFY_EOK;
        out->msg = NULL;
        out->value.d = v;
    }
}

/* string -> 128 位整数（fail-fast：解析失败/溢出直接终止；w-014 顺带修
 * t-016 遗留——128 位目标无 8 字节错误值容器，走独立转换通道）。
 * 返回低 64 位，*hi 写高 64 位（LLVM 侧拼装 i128，规避 win32 __int128
 * 返回值 ABI 的 sret 隐藏指针约定） */
long long zfy_stoi_wide(long long *hi, const char *s) {
    unsigned __int128 v = 0;
    const char *p = s;
    while (*p == ' ' || *p == '\t') p++;
    int neg = 0;
    if (*p == '+' || *p == '-') { neg = (*p == '-'); p++; }
    if (*p < '0' || *p > '9') zfy_die("cast：无法把 string 解析为整数");
    for (; *p >= '0' && *p <= '9'; p++) {
        unsigned d = (unsigned)(*p - '0');
        if (v > ((~(unsigned __int128)0) - d) / 10)
            zfy_die("cast：整数超出 128 位范围");
        v = v * 10 + d;
    }
    while (*p == ' ' || *p == '\t') p++;
    if (*p != '\0') zfy_die("cast：无法把 string 解析为整数（尾随字符）");
    if (neg) {
        if (v > (unsigned __int128)1 << 127)
            zfy_die("cast：整数超出 128 位范围");
        v = (unsigned __int128)0 - v;
    }
    *hi = (long long)(unsigned long long)(v >> 64);
    return (long long)(unsigned long long)v;
}

/* string -> f128（fail-fast；x86_fp80 经 x87 st0 返回，与 LLVM 调用约定一致） */
long double zfy_stod_wide(const char *s) {
    char *end;
    long double v = strtold(s, &end);
    if (end == s) zfy_die("cast：无法把 string 解析为浮点数");
    return v;
}

/* find(s, c, k)：第 k 次出现的下标；未找到产 NOT_FOUND 错误 */
void zfy_err_find(zfy_err *out, const char *s, char c, long long k) {
    if (k < 1) zfy_die("find: count 必须 > 0");   /* w-020：与编译期检查统一为 panic */
    for (long long i = 0, seen = 0; s[i]; i++) {
        if (s[i] == c) {
            seen++;
            if (seen == k) {
                err_ok_i(out, i);
                return;
            }
        }
    }
    err_set(out, ZFY_ENOT_FOUND, "find: 未找到字符");
}

/* 子串版 find：找第 k 次出现（k 从 1 起）；不存在返回 -1；k < 1 panic（w-020） */
long long zfy_str_find_str(const char *s, const char *sub, long long k) {
    if (k < 1) zfy_die("find: count 必须 > 0");
    size_t sl = strlen(sub);
    if (sl == 0) zfy_die("find: 子串分隔不能为空串");
    for (long long i = 0, seen = 0; s[i]; i++) {
        if (strncmp(s + i, sub, sl) == 0) {
            seen++;
            if (seen == k) return i;
        }
    }
    return -1;
}

/* 子串版 find（错误值版，sret）：产 TErr i64 */
void zfy_err_find_str(zfy_err *out, const char *s, const char *sub, long long k) {
    long long r = zfy_str_find_str(s, sub, k);
    if (r < 0)
        err_set(out, ZFY_ENOT_FOUND, "find: 未找到子串");
    else
        err_ok_i(out, r);
}

/* freestanding（--freestanding）：文件 I/O 依赖 OS，整段裁剪。 */
#ifndef ZFY_FREESTANDING

/* ---------- 文件 I/O（design_fileio.md） ----------
 * File = move-only 句柄：变量槽值是堆上句柄对象指针 { FILE* fp; int closed }。
 * - open 分配句柄；close 显式关闭（幂等）；autoclose 供作用域退出 RAII 调用。
 * - 失效（move 后源槽 = NULL）或已关闭句柄上的任何操作 → panic（编译期
 *   同块复用已由 typeck 拦截，此处为跨块/跨函数兜底）。
 * - read 产错误值（IO=4 / EOF=7）；write/close 失败 panic（不产 T!）。
 * - 文件按字节透传（假定 UTF-8），不做编码转换。 */

typedef struct {
    FILE *fp;
    int closed;
} zfy_file_t;

static void zfy_file_check(zfy_file_t *h) {
    if (!h) zfy_die("use of moved file handle");
    if (h->closed) zfy_die("use of closed file");
}

void zfy_file_open_err(zfy_err *out, const char *path, const char *mode) {
    FILE *fp = fopen(path, mode);
    if (!fp) {
        err_set(out, ZFY_EIO, "open: 无法打开文件");
        return;
    }
    zfy_file_t *h = (zfy_file_t *)malloc(sizeof(zfy_file_t));
    if (!h) zfy_die("内存分配失败");
    h->fp = fp;
    h->closed = 0;
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value.p = h;
}

/* 读整个文件内容为堆串（调用方持有，zfy 侧 RAII 释放）。
   读到末尾为 EOF 时若已读到数据按成功处理（空文件 = 空串） */
static char *zfy_file_slurp(FILE *fp, size_t *out_len) {
    size_t cap = 4096, len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) zfy_die("内存分配失败");
    for (;;) {
        if (len + 4096 + 1 > cap) {
            cap *= 2;
            char *nb = (char *)realloc(buf, cap);
            if (!nb) zfy_die("内存分配失败");
            buf = nb;
        }
        size_t n = fread(buf + len, 1, 4096, fp);
        len += n;
        if (n < 4096) {
            if (ferror(fp)) {
                free(buf);
                return NULL;
            }
            break;
        }
    }
    buf[len] = '\0';
    *out_len = len;
    return buf;
}

void zfy_file_read_all_err(zfy_err *out, zfy_file_t *h) {
    zfy_file_check(h);
    size_t len = 0;
    char *s = zfy_file_slurp(h->fp, &len);
    if (!s) {
        err_set(out, ZFY_EIO, "read_all: 读取失败");
        return;
    }
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value.p = s;
}

/* 读一行（不含行尾换行符）；文件结束且无数据 → EOF 错误 */
void zfy_file_read_line_err(zfy_err *out, zfy_file_t *h) {
    zfy_file_check(h);
    size_t cap = 128, len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) zfy_die("内存分配失败");
    int c;
    while ((c = fgetc(h->fp)) != EOF) {
        if (c == '\n') break;
        if (len + 2 > cap) {
            cap *= 2;
            char *nb = (char *)realloc(buf, cap);
            if (!nb) zfy_die("内存分配失败");
            buf = nb;
        }
        buf[len++] = (char)c;
    }
    if (c == EOF && len == 0) {
        free(buf);
        err_set(out, ZFY_EEOF, "read_line: 文件结束");
        return;
    }
    if (ferror(h->fp)) {
        free(buf);
        err_set(out, ZFY_EIO, "read_line: 读取失败");
        return;
    }
    buf[len] = '\0';
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value.p = buf;
}

/* write / writeln（nl=1 追加换行）：失败 panic（不产 T!，design_fileio.md） */
void zfy_file_write(zfy_file_t *h, const char *s, int nl) {
    zfy_file_check(h);
    size_t n = strlen(s);
    if (n > 0 && fwrite(s, 1, n, h->fp) != n)
        zfy_die("write: 写入失败");
    if (nl && fputc('\n', h->fp) == EOF)
        zfy_die("write: 写入失败");
}

/* 显式 close：幂等（已关闭直接返回）；fclose 失败 panic */
void zfy_file_close(zfy_file_t *h) {
    if (!h) zfy_die("use of moved file handle");
    if (h->closed) return;
    if (fclose(h->fp) != 0) zfy_die("close: 关闭失败");
    h->closed = 1;
}

/* 作用域退出 RAII 自动 close：null（已 move）或已关闭跳过；失败 panic。
 * close 失败仍置 closed，防双关（进程即将终止，无碍） */
void zfy_file_autoclose(zfy_file_t *h) {
    if (!h || h->closed) return;
    if (fclose(h->fp) != 0) zfy_die("close: 关闭失败");
    h->closed = 1;
}

int zfy_file_exists(const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) return 0;
    fclose(fp);
    return 1;
}

/* 一步式整读：open("r") + 读全部 + close */
void zfy_file_read_file_err(zfy_err *out, const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) {
        err_set(out, ZFY_EIO, "read_file: 无法打开文件");
        return;
    }
    size_t len = 0;
    char *s = zfy_file_slurp(fp, &len);
    if (fclose(fp) != 0 || !s) {
        free(s);
        err_set(out, ZFY_EIO, "read_file: 读取失败");
        return;
    }
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value.p = s;
}

/* read_lines：读全部行（去行尾 \r\n/\n），EOF 正常结束返回列表；
   IO 错误 panic（与 write/close 一致）。元素为 string（kind=1） */
zfy_seq *zfy_file_read_lines(zfy_file_t *h) {
    zfy_file_check(h);
    zfy_seq *out = zfy_seq_new_k(0, 8, 8, 1, NULL);
    size_t cap = 128;
    char *buf = (char *)malloc(cap);
    if (!buf) zfy_die("内存分配失败");
    long long idx = 0;
    for (;;) {
        int c;
        size_t len = 0;
        int hit_eof = 0;
        while ((c = fgetc(h->fp)) != EOF) {
            if (c == '\n') break;
            if (len + 2 > cap) {
                cap *= 2;
                char *nb = (char *)realloc(buf, cap);
                if (!nb) zfy_die("内存分配失败");
                buf = nb;
            }
            buf[len++] = (char)c;
        }
        if (c == EOF && len == 0) {
            hit_eof = 1;
        } else {
            while (len > 0 && (buf[len - 1] == '\r' || buf[len - 1] == '\n'))
                len--;
            buf[len] = '\0';
            zfy_seq_set_str(out, idx++, buf, 1);
        }
        if (hit_eof) break;
    }
    free(buf);
    if (ferror(h->fp))
        zfy_die("read_lines: 读取失败");
    return out;
}
void zfy_file_write_file_err(zfy_err *out, const char *path, const char *s) {
    FILE *fp = fopen(path, "w");
    if (!fp) {
        err_set(out, ZFY_EIO, "write_file: 无法打开文件");
        return;
    }
    size_t len = strlen(s);
    if (len > 0 && fwrite(s, 1, len, fp) != len) {
        fclose(fp);
        err_set(out, ZFY_EIO, "write_file: 写入失败");
        return;
    }
    if (fclose(fp) != 0) {
        err_set(out, ZFY_EIO, "write_file: 关闭失败");
        return;
    }
    err_ok_i(out, (long long)len);
}

/* 程序加载时调大 stdout 缓冲（默认 4KB）：大量逐行输出时减少系统调用。
 * 进程退出时 C 运行时自动 flush，无需手动处理 */
static char out_buf[1 << 16];
__attribute__((constructor)) static void zfy_io_init(void) {
    setvbuf(stdout, out_buf, _IOFBF, sizeof out_buf);
}

#endif /* !ZFY_FREESTANDING：文件 I/O 段结束 */

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

/* ---- 受跟踪的错误消息串（P0-1d：取消"有意最小泄漏"口径）----
 * 错误值 msg / panic handler 消息 / panic_msg 缓冲来源等纯诊断字符串
 * 无法静态判定生命周期（TErr 值可任意传递/存容器），统一走本分配器
 * 登记，atexit 统一释放。进程生命周期内任何路径（正常退出 / panic
 * 退出 / handler 自定义退出——atexit 在 exit 时仍会执行）都回收。 */
typedef struct zfy_msg_node {
    struct zfy_msg_node *next;
    char *s;
} zfy_msg_node;
static zfy_msg_node *zfy_msg_list = NULL;
static void zfy_msg_atexit(void); /* 前向声明 */

char *zfy_msg_strdup(const char *s) {
#ifndef ZFY_FREESTANDING
    static int hooked = 0;
    if (!hooked) {
        hooked = 1;
        atexit(zfy_msg_atexit);
    }
#endif
    char *r = zfy_strdup(s);
    if (r) {
        zfy_msg_node *n = (zfy_msg_node *)malloc(sizeof(zfy_msg_node));
        if (n) {
            n->s = r;
            n->next = zfy_msg_list;
            zfy_msg_list = n;
        }
    }
    return r;
}

static void zfy_msg_atexit(void) {
    zfy_msg_node *n = zfy_msg_list;
    while (n) {
        zfy_msg_node *nx = n->next;
        free(n->s);
        free(n);
        n = nx;
    }
    zfy_msg_list = NULL;
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

/* 9d ABI 自检：extern "C" i128 参数（按值声明，MinGW 下后端自动按引用传递）
   与 i128 返回值（sret）的双向验证 */
int64_t abi_i128_lo(__int128 v) {
    return (int64_t)(v & (((__int128)1 << 64) - 1));
}

__int128 abi_i128_scale(__int128 v, int64_t k) {
    return v * (__int128)k;
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

/* 按总码点数 n 截断 / 右补空格；n<=0 得空串。返回 malloc 串（调用者释放）。
   w-020：UTF-8 感知——宽度按码点数计，截断对齐码点边界，
   不再产生截半码点的非法 UTF-8 序列；非 UTF-8 字节按 1 码点容错 */
char *zfy_prec_str(const char *s, long long n) {
    if (n < 0) n = 0;
    size_t len = strlen(s);
    /* 数前 n 个完整码点的字节宽度 */
    const unsigned char *p = (const unsigned char *)s;
    size_t cut = len;               /* 默认 = 全串（码点数 <= n 时） */
    long long cnt = 0;
    for (size_t i = 0; i < len; i++) {
        if ((p[i] & 0xC0) != 0x80) {   /* 码点起点 */
            if (cnt == n) { cut = i; break; }
            cnt++;
        }
    }
    size_t nn = (size_t)n;
    size_t cp = (size_t)cnt;        /* 全串码点数（截断时 = n） */
    char *buf;
    if (nn <= cp) {
        /* 截断到 n 个码点（cut 已对齐边界；nn==cp 时 cut==len） */
        buf = (char *)malloc(cut + 1);
        if (!buf) zfy_die("内存分配失败");
        memcpy(buf, s, cut);
        buf[cut] = '\0';
    } else {
        /* 右补空格到 n 个码点宽 */
        buf = (char *)malloc(len + (size_t)(nn - cp) + 1);
        if (!buf) zfy_die("内存分配失败");
        memcpy(buf, s, len);
        memset(buf + len, ' ', (size_t)(nn - cp));
        buf[len + (nn - cp)] = '\0';
    }
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
DEF_FRAC_FLT(f128, long double)

/* ---------- output / input 运行时支持 ----------
   freestanding：无控制台（output/input 在编译期已被 typeck 拒绝），整段裁剪。 */
#ifndef ZFY_FREESTANDING

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

/* 输出 T! 错误值（new.md 第1条：T! 可整体 output）：
 * 成功打印元素值，失败打印 err#<code>。
 * kind：0=i64 1=u64 2=f64 3=bool 4=char 5=string 6=i128 7=u128 */
void zfy_print_err(int32_t kind, void *errp) {
    zfy_err *e = (zfy_err *)errp;
    if (e->code != 0) {
        printf("err#%d", e->code);
        return;
    }
    switch (kind) {
    case 0: zfy_print_i64(e->value.i); break;
    case 1: zfy_print_u64((unsigned long long)e->value.i); break;
    case 2: zfy_print_f64(e->value.d); break;
    case 3: zfy_print_bool(e->value.i != 0); break;
    case 4: zfy_print_char((char)e->value.i); break;
    case 5: zfy_print_str(e->value.p ? (const char *)e->value.p : ""); break;
    case 6: {
        zfy_err_wide *w = (zfy_err_wide *)errp;
        zfy_print_i128(w->value);
        break;
    }
    default: {
        zfy_err_wide *w = (zfy_err_wide *)errp;
        zfy_print_u128((unsigned __int128)w->value);
        break;
    }
    }
}

/* ---------- input 运行时支持 ---------- */

/* stdin 快速缓冲读取：整块 fread 进自管缓冲，替代逐字符 getchar()
 * （每次 getchar 都走 stdio 锁与调度，1 万整数输入约 6 万次调用）。
 * 当前语言单线程，无并发读 stdio 的场景 */
static char in_buf[1 << 16];
static size_t in_len = 0, in_pos = 0;
static int in_eof = 0;

/* 交互控制台标记：-1 未探测。控制台 stdin 不能用大块 fread——
   Windows CRT 的 fread 会循环读满请求字节数才返回（管道/文件遇到
   当前可用数据即返回），交互时表现为永远等 64KB（w-010） */
static int in_tty = -1;

static int in_getc(void) {
    if (in_tty < 0) {
#ifdef _WIN32
        in_tty = _isatty(_fileno(stdin));
#else
        in_tty = isatty(fileno(stdin));
#endif
    }
    if (in_tty)
        return getc(stdin);          /* 控制台：逐字符（CRT 已按行缓冲） */
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
    if (dlen != 0 && !*saw_delim) {
        /* EOF 结束且未遇到 delim（多目标最后一段/单目标到 EOF）：
           剥离行尾换行符，避免把 '\n' 读进字符串值（w-021） */
        while (len > 0 && (buf[len - 1] == '\n' || buf[len - 1] == '\r'))
            len--;
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

/* 整数目标（≤64 位）：EOF 或解析失败报运行时错误。
   i32/i16/i8 单独版本：i64 版按 8 字节写会溢出小宽度 alloca 槽，
   覆盖相邻变量（w-021）。各宽度解析后按范围校验 */
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

static void input_int_wide(void *val, const char *delim,
                           long long lo, unsigned long long hi,
                           int width, const char *what) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    long long v;
    if (no_input) {
        free(seg);
        zfy_die("input: EOF（无输入可读）");
    }
    if (!try_i64(seg, &v) || v < lo || (unsigned long long)v > hi) {
        free(seg);
        zfy_die(what);
    }
    switch (width) {
    case 1: *(signed char *)val = (signed char)v; break;
    case 2: *(short *)val = (short)v; break;
    default: *(int *)val = (int)v; break;
    }
    free(seg);
}

void zfy_input_i32(void *val, const char *delim) {
    input_int_wide(val, delim, -2147483648LL, 2147483647LL, 4,
                   "input: 无法把输入解析为整数");
}

void zfy_input_i16(void *val, const char *delim) {
    input_int_wide(val, delim, -32768LL, 32767LL, 2,
                   "input: 无法把输入解析为整数");
}

void zfy_input_i8(void *val, const char *delim) {
    input_int_wide(val, delim, -128LL, 127LL, 1,
                   "input: 无法把输入解析为整数");
}

void zfy_input_u32(void *val, const char *delim) {
    input_int_wide(val, delim, 0, 4294967295LL, 4,
                   "input: 无法把输入解析为整数");
}

void zfy_input_u16(void *val, const char *delim) {
    input_int_wide(val, delim, 0, 65535LL, 2,
                   "input: 无法把输入解析为整数");
}

void zfy_input_u8(void *val, const char *delim) {
    input_int_wide(val, delim, 0, 255LL, 1,
                   "input: 无法把输入解析为整数");
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

/* ---------- ZEM：T! 目标 input（失败写错误值而非退出） ----------
 * EOF 或解析失败 → code=INPUT、msg=原因、value 保持 0；成功 → code=0 */

void zfy_input_err_i64(zfy_err *out, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    long long v;
    if (no_input) {
        free(seg);
        err_set(out, ZFY_EINPUT, "input: EOF（无输入可读）");
        return;
    }
    if (!try_i64(seg, &v)) {
        free(seg);
        err_set(out, ZFY_EINPUT, "input: 无法把输入解析为整数");
        return;
    }
    free(seg);
    err_ok_i(out, v);
}

/* i128/u128 T! 目标（new.md 2026-10-11）：32 字节宽错误值容器 */
void zfy_input_err_i128(zfy_err_wide *out, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    if (no_input) {
        free(seg);
        err_wide_set(out, ZFY_EINPUT, "input: EOF（无输入可读）");
        return;
    }
    unsigned __int128 v = 0;
    const char *p = seg;
    while (*p == ' ' || *p == '\t') p++;
    int neg = 0;
    if (*p == '+' || *p == '-') { neg = (*p == '-'); p++; }
    int ok = (*p >= '0' && *p <= '9');
    for (; ok && *p >= '0' && *p <= '9'; p++) {
        unsigned d = (unsigned)(*p - '0');
        if (v > ((~(unsigned __int128)0) - d) / 10) { ok = 0; break; }
        v = v * 10 + d;
    }
    if (ok) {
        while (*p == ' ' || *p == '\t') p++;
        if (*p != '\0') ok = 0;
    }
    if (!ok) {
        free(seg);
        err_wide_set(out, ZFY_EINPUT, "input: 无法把输入解析为整数");
        return;
    }
    free(seg);
    if (neg) {
        if (v > (unsigned __int128)1 << 127) {
            err_wide_set(out, ZFY_EINPUT, "input: 整数超出 128 位范围");
            return;
        }
        v = (unsigned __int128)0 - v;
    }
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value = (__int128)v;
}

void zfy_input_err_f64(zfy_err *out, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    double v;
    if (no_input) {
        free(seg);
        err_set(out, ZFY_EINPUT, "input: EOF（无输入可读）");
        return;
    }
    if (!try_f64(seg, &v)) {
        free(seg);
        err_set(out, ZFY_EINPUT, "input: 无法把输入解析为小数");
        return;
    }
    free(seg);
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value.d = v;
}

void zfy_input_err_str(zfy_err *out, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    if (no_input) {
        free(seg);
        err_set(out, ZFY_EINPUT, "input: EOF（无输入可读）");
        return;
    }
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value.p = seg;               /* 缓冲区所有权移交错误值（?? 解包后归变量） */
}

void zfy_input_err_bool(zfy_err *out, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    if (no_input) {
        free(seg);
        err_set(out, ZFY_EINPUT, "input: EOF（无输入可读）");
        return;
    }
    if (strcmp(seg, "true") == 0) {
        free(seg);
        err_ok_i(out, 1);
        return;
    }
    if (strcmp(seg, "false") == 0) {
        free(seg);
        err_ok_i(out, 0);
        return;
    }
    long long v;
    if (!try_i64(seg, &v)) {
        free(seg);
        err_set(out, ZFY_EINPUT, "input: 无法把输入解析为布尔值");
        return;
    }
    free(seg);
    err_ok_i(out, v != 0);
}

void zfy_input_err_char(zfy_err *out, const char *delim) {
    int no_input = 0;
    char *seg = input_segment(delim, (long long)strlen(delim), &no_input);
    if (no_input || seg[0] == '\0') {
        free(seg);
        err_set(out, ZFY_EINPUT, "input: EOF（无输入可读）");
        return;
    }
    char c = seg[0];
    free(seg);
    err_ok_i(out, (long long)c);
}

#endif /* !ZFY_FREESTANDING：output/input 段结束 */

/* ---------- 数组/列表运行时支持（按元素宽度存储） ---------- */

/* 前置声明：元素级操作按头部 kind 递归释放/复制嵌套 seq（w-014 #2/#4） */
typedef struct zfy_ops zfy_ops;
typedef struct zfy_seq zfy_seq;
zfy_seq *zfy_seq_new(long long count, long long cap, long long elemsz);
zfy_seq *zfy_seq_new_k(long long count, long long cap, long long elemsz,
                       int kind, zfy_ops *ops);
zfy_seq *zfy_seq_clone(const zfy_seq *src);
void zfy_seq_free(zfy_seq *s);

/* 定长数组与列表统一表示（与 LLVM 的 %zfy.seq = { ptr, ptr, i64, i64, i64, i32, ptr }
 * 前五字段布局一致，len 在偏移 16；第二字段为占位（历史 present 位图，现已废弃），
 * cap/elemsz/kind/ops 供运行时元素操作使用（w-014 #2/#4）：
 *  - data：元素按 elemsz 字节连续存储，未初始化槽位为全零位模式
 *  - len：当前元素个数（定长数组不变，列表可扩长）
 *  - cap：容量（列表扩长用）
 *  - elemsz：元素字节数
 *  - kind：元素种类 0=标量 1=string 2=嵌套 seq（列表的列表/二维数组）
 *          3=struct（ops 指向深拷贝/释放函数对）
 *  - ops：kind=3 时的 struct 元素操作（copy/dtor），其余 NULL */
typedef struct zfy_ops {
    void (*copy)(void *dst, const void *src);  /* 深拷贝 src → dst（dst 须为已定位槽） */
    void (*dtor)(void *elem);                  /* 释放元素内含堆资源 */
} zfy_ops;

struct zfy_seq {
    void *data;
    void *_pad;
    long long len;
    long long cap;
    long long elemsz;
    int kind;
    zfy_ops *ops;
};

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
    s->kind = 0;
    s->ops = NULL;
    if (!s->data) zfy_die("数组: 内存分配失败");
    memset(s->data, 0, (size_t)cap * (size_t)elemsz);
    return s;
}

/* 带元素种类的分配（w-014 #2/#4）：kind/ops 随头部传递，后续
   free/clone/slice/set/get 全部按头部驱动，无需逐调用点传标志 */
zfy_seq *zfy_seq_new_k(long long count, long long cap, long long elemsz,
                       int kind, zfy_ops *ops) {
    zfy_seq *s = zfy_seq_new(count, cap, elemsz);
    s->kind = kind;
    s->ops = ops;
    return s;
}

/* ---- 元素级操作（按头部 kind/ops 分派） ---- */

/* 释放单个元素内含的堆资源（槽位本身归 seq 数据缓冲所有） */
static void elem_dtor(void *elem, int kind, zfy_ops *ops) {
    switch (kind) {
    case 1: zfy_free_str(*(char **)elem); break;
    case 2: zfy_seq_free(*(zfy_seq **)elem); break;
    case 3: if (ops) ops->dtor(elem); break;
    default: break;
    }
}

/* 把 src 元素深拷贝进"新分配全零"槽（无旧资源，读/clone 路径） */
static void elem_init(void *dst, const void *src, int kind, zfy_ops *ops,
                      long long esz) {
    switch (kind) {
    case 1: *(char **)dst = zfy_strdup(*(char *const *)src); break;
    case 2: *(zfy_seq **)dst = zfy_seq_clone(*(zfy_seq *const *)src); break;
    case 3: if (ops) ops->copy(dst, src); else memcpy(dst, src, (size_t)esz); break;
    default: memcpy(dst, src, (size_t)esz); break;
    }
}

/* 把 src 元素深拷贝进"已有元素"槽（覆盖写路径）。
 * 顺序敏感：先把新值深拷贝到临时缓冲，再释放旧值——src 可能就是 dst
 * 本身（push 原地修改后返回同一头部 / 自赋值），先释放会悬垂 */
static void elem_assign(void *dst, const void *src, int kind, zfy_ops *ops,
                        long long esz) {
    if (kind == 0) {
        memcpy(dst, src, (size_t)esz);
        return;
    }
    unsigned char tmpbuf[64];
    void *buf = esz <= (long long)sizeof(tmpbuf) ? tmpbuf
                                                 : malloc((size_t)esz);
    if (!buf) zfy_die("elem_assign: 内存分配失败");
    memset(buf, 0, (size_t)esz);
    elem_init(buf, src, kind, ops, esz);
    elem_dtor(dst, kind, ops);
    memcpy(dst, buf, (size_t)esz);
    if (buf != tmpbuf) free(buf);
}

#ifndef ZFY_FREESTANDING
/* output(数组/列表)（w-013）：按元素类型码打印序列，元素间以 sep 分隔。
   类型码：0 i8 1 i16 2 i32 3 i64 4 u8 5 u16 6 u32 7 u64 8 i128 9 u128
   10 f32 11 f64 12 char 13 bool 14 string（与 mir elem_kind 对应） */
void zfy_print_seq(zfy_seq *s, int kind, const char *sep) {
    if (!s || !s->data) return;
    const char *base = (const char *)s->data;
    long long esz = s->elemsz;
    for (long long i = 0; i < s->len; i++) {
        if (i && sep) zfy_print_str(sep);
        const void *p = base + i * esz;
        switch (kind) {
        case 0: zfy_print_i64(*(int8_t *)p); break;
        case 1: zfy_print_i64(*(int16_t *)p); break;
        case 2: zfy_print_i64(*(int32_t *)p); break;
        case 3: zfy_print_i64(*(int64_t *)p); break;
        case 4: zfy_print_u64((unsigned long long)*(uint8_t *)p); break;
        case 5: zfy_print_u64((unsigned long long)*(uint16_t *)p); break;
        case 6: zfy_print_u64((unsigned long long)*(uint32_t *)p); break;
        case 7: zfy_print_u64(*(uint64_t *)p); break;
        case 8: zfy_print_i128(*(__int128 *)p); break;
        case 9: zfy_print_u128(*(unsigned __int128 *)p); break;
        case 10: zfy_print_f64((double)*(float *)p); break;
        case 11: zfy_print_f64(*(double *)p); break;
        case 12: zfy_print_char(*(char *)p); break;
        case 13: zfy_print_bool((int)*(uint8_t *)p); break;
        case 14: {
            char *v = *(char **)p;
            zfy_print_str(v ? v : "(null)");
            break;
        }
        default: break;
        }
    }
}

/* 嵌套序列递归打印（w-015 #6）：每个元素槽内是内层 zfy_seq 指针，
   逐层输出 [ ... ]，元素间以 sep 分隔；depth 为剩余层数（2D 传 1），
   叶元素类型码 leafkind 由编译器静态传入（运行时头部 kind 无宽度信息） */
static void zfy_print_seq_nest_rec(zfy_seq *s, int depth, int leafkind, const char *sep) {
    /* depth = 剩余指针层数：>1 时元素槽内是内层 zfy_seq*，逐层递归；
       <=1 时当前序列的元素即叶值，整体交给 zfy_print_seq */
    if (depth <= 1) {
        zfy_print_char('[');
        if (s && s->data) zfy_print_seq(s, leafkind, sep);
        zfy_print_char(']');
        return;
    }
    if (!s || !s->data) {
        zfy_print_char('[');
        zfy_print_char(']');
        return;
    }
    const char *base = (const char *)s->data;
    long long esz = s->elemsz;
    zfy_print_char('[');
    for (long long i = 0; i < s->len; i++) {
        if (i && sep) zfy_print_str(sep);
        zfy_seq *inner = *(zfy_seq **)(base + i * esz);
        zfy_print_seq_nest_rec(inner, depth - 1, leafkind, sep);
    }
    zfy_print_char(']');
}

void zfy_print_seq_nest(zfy_seq *s, int depth, int leafkind, const char *sep) {
    zfy_print_seq_nest_rec(s, depth, leafkind, sep);
}
#endif /* !ZFY_FREESTANDING：output(序列) 打印段结束（output 语句不可用） */

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

/* 释放 seq：按头部 kind/ops 逐元素释放内含堆资源（w-014 #2/#4）；
   零值槽 free(NULL)/空 struct 释放均安全 */
void zfy_seq_free(zfy_seq *s) {
    if (!s) return;
    for (long long i = 0; i < s->len; i++)
        elem_dtor(seq_at(s, i), s->kind, s->ops);
    free(s->data);
    free(s);
}

/* 深拷贝 seq（数组/列表整体赋值/元素读出）：按头部 kind/ops 逐元素复制 */
zfy_seq *zfy_seq_clone(const zfy_seq *src) {
    if (!src) return NULL;
    zfy_seq *s = (zfy_seq *)malloc(sizeof(zfy_seq));
    if (!s) zfy_die("数组赋值: 内存分配失败");
    s->len = src->len;
    s->cap = src->len > 0 ? src->len : 1;
    s->elemsz = src->elemsz;
    s->kind = src->kind;
    s->ops = src->ops;
    s->_pad = NULL;
    s->data = malloc((size_t)s->cap * (size_t)s->elemsz);
    if (!s->data) zfy_die("数组赋值: 内存分配失败");
    memset(s->data, 0, (size_t)s->cap * (size_t)s->elemsz);
    for (long long i = 0; i < s->len; i++)
        elem_init(seq_at(s, i), seq_at(src, i), s->kind, s->ops, s->elemsz);
    return s;
}

/* ---------- 哈希表 map<K,V> / set<T>（v3.6 容器轮） ----------
 * 语言侧 map$<ktag>$<vtag> / set$<ktag> 是内建泛型 struct（单 ptr 字段 h），
 * 槽指针即本节函数的 m** 参数（h 懒分配）。键两类：i（整数/char 按 i64 位
 * 模式）、s（string）。值统一 8 字节：整数/bool/char/ptr 按 i64 位模式存
 * （窄整数读回由 LLVM 截断），f32 存 float 位模式（零扩展）、f64 存 double
 * 位模式、string 存 strdup 堆指针。链式哈希 + FNV-1a/splitmix64。 */

typedef struct zfy_ment {
    struct zfy_ment *next;
    unsigned long long hash;
    long long k_i;          /* ktag=i：键位模式 */
    char *k_s;              /* ktag=s：键串（表所有） */
    unsigned long long val; /* 值 8 字节位模式 */
} zfy_ment;

typedef struct zfy_map {
    zfy_ment **buckets;
    long long nbuckets;
    long long size;
    int kstr;               /* 1 = string 键 */
    int kbig;               /* 1 = 128 位二进制键（k_s 指向 16 字节缓冲，表拥有） */
    int vstr;               /* 1 = string 值（首 put 时确定，释放/克隆用） */
} zfy_map;

static unsigned long long zfy_mix64(unsigned long long x) {
    x ^= x >> 30; x *= 0xbf58476d1ce4e5b9ULL;
    x ^= x >> 27; x *= 0x94d049bb133111ebULL;
    x ^= x >> 31; return x;
}

static unsigned long long zfy_hash_key(const zfy_map *m, long long ki, const char *ks) {
    if (m->kbig) {
        /* 128 位键：低/高两个字分别 mix 后合并 */
        unsigned long long lo, hi;
        memcpy(&lo, ks, 8); memcpy(&hi, ks + 8, 8);
        return zfy_mix64(lo) ^ (zfy_mix64(hi) * 0x9e3779b97f4a7c15ULL);
    }
    if (!m->kstr) return zfy_mix64((unsigned long long)ki);
    unsigned long long h = 1469598103934665603ULL;
    for (const unsigned char *p = (const unsigned char *)ks; *p; p++) {
        h ^= *p; h *= 1099511628211ULL;
    }
    return h;
}

static int zfy_key_eq(const zfy_map *m, const zfy_ment *e, long long ki, const char *ks) {
    if (m->kbig) return memcmp(e->k_s, ks, 16) == 0;
    if (m->kstr) return strcmp(e->k_s, ks) == 0;
    return e->k_i == ki;
}

static zfy_map *zfy_map_alloc(int kstr) {
    zfy_map *m = (zfy_map *)malloc(sizeof(zfy_map));
    if (!m) zfy_die("map: 内存分配失败");
    m->buckets = NULL; m->nbuckets = 0; m->size = 0;
    m->kstr = kstr; m->kbig = 0; m->vstr = 0;
    return m;
}

static void zfy_map_put_raw(zfy_map **mp, long long ki, const char *ks,
                            unsigned long long v, int vstr) {
    zfy_map *m = *mp;
    if (!m) { m = zfy_map_alloc(ks != NULL); *mp = m; }
    if (vstr) m->vstr = 1;
    if (m->nbuckets == 0 || m->size * 4 >= m->nbuckets * 3) {
        long long nn = m->nbuckets ? m->nbuckets * 2 : 16;
        zfy_ment **nb = (zfy_ment **)calloc((size_t)nn, sizeof(zfy_ment *));
        if (!nb) zfy_die("map: 内存分配失败");
        for (long long b = 0; b < m->nbuckets; b++) {
            zfy_ment *e = m->buckets[b];
            while (e) {
                zfy_ment *nx = e->next;
                unsigned long long idx = e->hash & (unsigned long long)(nn - 1);
                e->next = nb[idx]; nb[idx] = e;
                e = nx;
            }
        }
        free(m->buckets); m->buckets = nb; m->nbuckets = nn;
    }
    const char *ks2 = (m->kstr || m->kbig) ? ks : NULL;
    unsigned long long h = zfy_hash_key(m, ki, ks2);
    unsigned long long idx = h & (unsigned long long)(m->nbuckets - 1);
    for (zfy_ment *e = m->buckets[idx]; e; e = e->next) {
        if (e->hash == h && zfy_key_eq(m, e, ki, ks2)) {
            /* 值为 string：旧值释放（覆盖语义） */
            if (m->vstr) free((void *)(unsigned long long)e->val);
            e->val = v;
            return;
        }
    }
    zfy_ment *e = (zfy_ment *)malloc(sizeof(zfy_ment));
    if (!e) zfy_die("map: 内存分配失败");
    e->next = m->buckets[idx];
    e->hash = h;
    e->k_i = ki;
    if (m->kbig) {
        e->k_s = (char *)malloc(16);
        if (!e->k_s) zfy_die("map: 内存分配失败");
        memcpy(e->k_s, ks, 16);
    } else {
        e->k_s = m->kstr ? zfy_strdup(ks) : NULL;
    }
    e->val = v;
    m->buckets[idx] = e;
    m->size++;
}

/* 整数键 put（值按 i64 位模式：整数/bool/char/ptr） */
void zfy_map_put_i_i64(zfy_map **mp, long long k, long long v) {
    zfy_map_put_raw(mp, k, NULL, (unsigned long long)v, 0);
}
/* 浮点值 put：按位模式存 */
void zfy_map_put_i_f32(zfy_map **mp, long long k, float v) {
    union { float f; unsigned long long u; } c;
    c.u = 0; c.f = v;
    zfy_map_put_raw(mp, k, NULL, c.u, 0);
}
void zfy_map_put_i_f64(zfy_map **mp, long long k, double v) {
    union { double d; unsigned long long u; } c;
    c.d = v;
    zfy_map_put_raw(mp, k, NULL, c.u, 0);
}
/* string 值 put：strdup 拷入（值语义），旧值释放 */
void zfy_map_put_i_str(zfy_map **mp, long long k, char *v) {
    zfy_map_put_raw(mp, k, NULL, (unsigned long long)(size_t)zfy_strdup(v), 1);
}
/* string 键四件套 */
void zfy_map_put_s_i64(zfy_map **mp, const char *k, long long v) {
    zfy_map_put_raw(mp, 0, k, (unsigned long long)v, 0);
}
void zfy_map_put_s_f32(zfy_map **mp, const char *k, float v) {
    union { float f; unsigned long long u; } c;
    c.u = 0; c.f = v;
    zfy_map_put_raw(mp, 0, k, c.u, 0);
}
void zfy_map_put_s_f64(zfy_map **mp, const char *k, double v) {
    union { double d; unsigned long long u; } c;
    c.d = v;
    zfy_map_put_raw(mp, 0, k, c.u, 0);
}
void zfy_map_put_s_str(zfy_map **mp, const char *k, char *v) {
    zfy_map_put_raw(mp, 0, k, (unsigned long long)(size_t)zfy_strdup(v), 1);
}

/* ---- RAII 零槽探测（v3.35）：全零槽跳过用户 drop ---- */

int zfy_slot_is_zero(void *p, long long n) {
    const char *q = (const char *)p;
    for (long long i = 0; i < n; i++) if (q[i]) return 0;
    return 1;
}

/* ---- 128 位键通道（v3.34）：16 字节二进制键，k_s 复用为缓冲指针 ---- */

/* 键打包：lo/hi 两个 i64 -> 堆上 16 字节缓冲（调用后所有权归 map 表） */
char *zfy_map_key128(long long lo, long long hi) {
    char *buf = (char *)malloc(16);
    if (!buf) zfy_die("map: 内存分配失败");
    memcpy(buf, &lo, 8); memcpy(buf + 8, &hi, 8);
    return buf;
}

static void zfy_map_put_k_raw(zfy_map **mp, const char *kb,
                              unsigned long long v, int vstr) {
    zfy_map *m = *mp;
    if (!m) { m = zfy_map_alloc(0); m->kbig = 1; *mp = m; }
    if (!m->kbig) zfy_die("map: 键类型不匹配（128 位键通道）");
    zfy_map_put_raw(mp, 0, kb, v, vstr);
}
void zfy_map_put_k_i64(zfy_map **mp, char *k, long long v) {
    zfy_map_put_k_raw(mp, k, (unsigned long long)v, 0);
}
void zfy_map_put_k_f32(zfy_map **mp, char *k, float v) {
    union { float f; unsigned long long u; } c;
    c.u = 0; c.f = v;
    zfy_map_put_k_raw(mp, k, c.u, 0);
}
void zfy_map_put_k_f64(zfy_map **mp, char *k, double v) {
    union { double d; unsigned long long u; } c;
    c.d = v;
    zfy_map_put_k_raw(mp, k, c.u, 0);
}
void zfy_map_put_k_str(zfy_map **mp, char *k, char *v) {
    zfy_map_put_k_raw(mp, k, (unsigned long long)(size_t)zfy_strdup(v), 1);
}

/* 读：按值种类写入 err.value（与 LLVM MErrValue 约定一致：
 * 整数 → sext i64、浮点 → double、string → strdup 所有权副本）；
 * 缺失产 NOT_FOUND 错误。空表/未分配直接报缺失（nbuckets=0 时掩码无意义） */
static zfy_ment *zfy_map_find_raw(zfy_map **mp, long long ki, const char *ks) {
    zfy_map *m = *mp;
    if (!m || m->size == 0) return NULL;
    const char *ks2 = (m->kstr || m->kbig) ? ks : NULL;
    unsigned long long h = zfy_hash_key(m, ki, ks2);
    unsigned long long idx = h & (unsigned long long)(m->nbuckets - 1);
    for (zfy_ment *e = m->buckets[idx]; e; e = e->next)
        if (e->hash == h && zfy_key_eq(m, e, ki, ks2)) return e;
    return NULL;
}

static void get_ok_i(zfy_err *out, unsigned long long v) {
    out->code = ZFY_EOK; out->msg = NULL; out->value.i = (long long)v;
}
static void get_ok_f32(zfy_err *out, unsigned long long v) {
    union { unsigned u; float f; } c;
    c.u = (unsigned)v;
    out->code = ZFY_EOK; out->msg = NULL; out->value.d = (double)c.f;
}
static void get_ok_f64(zfy_err *out, unsigned long long v) {
    union { unsigned long long u; double d; } c;
    c.u = v;
    out->code = ZFY_EOK; out->msg = NULL; out->value.d = c.d;
}
static void get_ok_str(zfy_err *out, unsigned long long v) {
    out->code = ZFY_EOK; out->msg = NULL;
    out->value.p = zfy_strdup((const char *)(size_t)v);
}

#define MAP_MISS(out) err_set(out, ZFY_ENOT_FOUND, "map: 键不存在")

void zfy_map_get_err_i_i64(zfy_err *out, zfy_map **mp, long long k) {
    zfy_ment *e = zfy_map_find_raw(mp, k, NULL);
    if (e) get_ok_i(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_i_f32(zfy_err *out, zfy_map **mp, long long k) {
    zfy_ment *e = zfy_map_find_raw(mp, k, NULL);
    if (e) get_ok_f32(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_i_f64(zfy_err *out, zfy_map **mp, long long k) {
    zfy_ment *e = zfy_map_find_raw(mp, k, NULL);
    if (e) get_ok_f64(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_i_str(zfy_err *out, zfy_map **mp, long long k) {
    zfy_ment *e = zfy_map_find_raw(mp, k, NULL);
    if (e) get_ok_str(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_s_i64(zfy_err *out, zfy_map **mp, const char *k) {
    zfy_ment *e = zfy_map_find_raw(mp, 0, k);
    if (e) get_ok_i(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_s_f32(zfy_err *out, zfy_map **mp, const char *k) {
    zfy_ment *e = zfy_map_find_raw(mp, 0, k);
    if (e) get_ok_f32(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_s_f64(zfy_err *out, zfy_map **mp, const char *k) {
    zfy_ment *e = zfy_map_find_raw(mp, 0, k);
    if (e) get_ok_f64(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_s_str(zfy_err *out, zfy_map **mp, const char *k) {
    zfy_ment *e = zfy_map_find_raw(mp, 0, k);
    if (e) get_ok_str(out, e->val); else MAP_MISS(out);
}

void zfy_map_get_err_k_i64(zfy_err *out, zfy_map **mp, char *k) {
    zfy_ment *e = zfy_map_find_raw(mp, 0, k);
    if (e) get_ok_i(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_k_f32(zfy_err *out, zfy_map **mp, char *k) {
    zfy_ment *e = zfy_map_find_raw(mp, 0, k);
    if (e) get_ok_f32(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_k_f64(zfy_err *out, zfy_map **mp, char *k) {
    zfy_ment *e = zfy_map_find_raw(mp, 0, k);
    if (e) get_ok_f64(out, e->val); else MAP_MISS(out);
}
void zfy_map_get_err_k_str(zfy_err *out, zfy_map **mp, char *k) {
    zfy_ment *e = zfy_map_find_raw(mp, 0, k);
    if (e) get_ok_str(out, e->val); else MAP_MISS(out);
}

int zfy_map_has_k(zfy_map **mp, char *k) {
    return zfy_map_find_raw(mp, 0, k) != NULL;
}
int zfy_map_del_k(zfy_map **mp, char *k) {
    zfy_map *m = *mp;
    if (!m || m->size == 0) return 0;
    const char *ks2 = (m->kstr || m->kbig) ? k : NULL;
    unsigned long long h = zfy_hash_key(m, 0, ks2);
    unsigned long long idx = h & (unsigned long long)(m->nbuckets - 1);
    for (zfy_ment **pp = &m->buckets[idx]; *pp; pp = &(*pp)->next) {
        zfy_ment *e = *pp;
        if (e->hash == h && zfy_key_eq(m, e, 0, ks2)) {
            *pp = e->next;
            if (m->vstr) free((void *)(unsigned long long)e->val);
            if (e->k_s) free(e->k_s);
            free(e);
            m->size--;
            return 1;
        }
    }
    return 0;
}


/* has / del / len / clear / clone / free */
static int zfy_map_has_raw(zfy_map **mp, long long ki, const char *ks) {
    zfy_map *m = *mp;
    if (!m) return 0;
    const char *ks2 = (m->kstr || m->kbig) ? ks : NULL;
    unsigned long long h = zfy_hash_key(m, ki, ks2);
    unsigned long long idx = h & (unsigned long long)(m->nbuckets - 1);
    for (zfy_ment *e = m->buckets[idx]; e; e = e->next)
        if (e->hash == h && zfy_key_eq(m, e, ki, ks2)) return 1;
    return 0;
}
int zfy_map_has_i(zfy_map **mp, long long k) { return zfy_map_has_raw(mp, k, NULL); }
int zfy_map_has_s(zfy_map **mp, const char *k) { return zfy_map_has_raw(mp, 0, k); }

static int zfy_map_del_raw(zfy_map **mp, long long ki, const char *ks) {
    zfy_map *m = *mp;
    if (!m) return 0;
    const char *ks2 = (m->kstr || m->kbig) ? ks : NULL;
    unsigned long long h = zfy_hash_key(m, ki, ks2);
    unsigned long long idx = h & (unsigned long long)(m->nbuckets - 1);
    for (zfy_ment **pp = &m->buckets[idx]; *pp; pp = &(*pp)->next) {
        zfy_ment *e = *pp;
        if (e->hash == h && zfy_key_eq(m, e, ki, ks2)) {
            *pp = e->next;
            if (m->vstr) free((void *)(unsigned long long)e->val);
            if (e->k_s) free(e->k_s);
            free(e);
            m->size--;
            return 1;
        }
    }
    return 0;
}
int zfy_map_del_i(zfy_map **mp, long long k) { return zfy_map_del_raw(mp, k, NULL); }
int zfy_map_del_s(zfy_map **mp, const char *k) { return zfy_map_del_raw(mp, 0, k); }

long long zfy_map_len(zfy_map **mp) { return *mp ? (*mp)->size : 0; }
int zfy_map_has_any(zfy_map **mp) { return *mp != NULL; }

void zfy_map_clear(zfy_map **mp) {
    zfy_map *m = *mp;
    if (!m) return;
    for (long long b = 0; b < m->nbuckets; b++) {
        zfy_ment *e = m->buckets[b];
        while (e) {
            zfy_ment *nx = e->next;
            if (m->vstr) free((void *)(unsigned long long)e->val);
            if (e->k_s) free(e->k_s);
            free(e);
            e = nx;
        }
    }
    free(m->buckets);
    m->buckets = NULL; m->nbuckets = 0; m->size = 0;
}

/* 深拷贝（整体赋值值语义）：值/键串全 strdup */
static zfy_map *zfy_map_clone_raw(zfy_map *src) {
    if (!src) return NULL;
    zfy_map *m = zfy_map_alloc(src->kstr);
    m->kbig = src->kbig;
    m->vstr = src->vstr;
    for (long long b = 0; b < src->nbuckets; b++) {
        for (zfy_ment *e = src->buckets[b]; e; e = e->next)
            zfy_map_put_raw(&m, e->k_i, e->k_s, e->val, m->vstr);
    }
    return m;
}
void zfy_map_assign(zfy_map **dst, zfy_map **src) {
    zfy_map *old = *dst;
    *dst = zfy_map_clone_raw(*src);
    /* 旧表释放（src 可能就是 dst 自身——克隆后释放原表安全） */
    if (old) {
        for (long long b = 0; b < old->nbuckets; b++) {
            zfy_ment *e = old->buckets[b];
            while (e) {
                zfy_ment *nx = e->next;
                if (old->vstr) free((void *)(unsigned long long)e->val);
                if (e->k_s) free(e->k_s);
                free(e);
                e = nx;
            }
        }
        free(old->buckets);
        free(old);
    }
}

void zfy_map_free(zfy_map **mp) {
    zfy_map *m = *mp;
    if (!m) return;
    for (long long b = 0; b < m->nbuckets; b++) {
        zfy_ment *e = m->buckets[b];
        while (e) {
            zfy_ment *nx = e->next;
            if (m->vstr) free((void *)(unsigned long long)e->val);
            if (e->k_s) free(e->k_s);
            free(e);
            e = nx;
        }
    }
    free(m->buckets);
    free(m);
    *mp = NULL;
}

/* 迭代器（for-in map 产键）：{ map, bucket, entry } 三字句柄 */
typedef struct {
    zfy_map *m;
    long long b;
    zfy_ment *e;
} zfy_miter;

void *zfy_map_iter(zfy_map **mp) {
    zfy_map *m = *mp;
    if (!m) return NULL;
    zfy_miter *it = (zfy_miter *)malloc(sizeof(zfy_miter));
    if (!it) zfy_die("map: 内存分配失败");
    it->m = m; it->b = 0; it->e = NULL;
    return it;
}

int zfy_map_next(void *itv, void *kout) {
    zfy_miter *it = (zfy_miter *)itv;
    if (!it) return 0;
    if (!it->e) {
        while (it->b < it->m->nbuckets && !it->m->buckets[it->b]) it->b++;
        if (it->b >= it->m->nbuckets) { free(it); return 0; }
        it->e = it->m->buckets[it->b];
    }
    zfy_ment *e = it->e;
    it->e = e->next;
    if (it->m->kstr)
        *(char **)kout = e->k_s;
    else
        *(long long *)kout = e->k_i;
    return 1;
}

/* keys(m)：键列表（string 键逐个 strdup，kind=1 深拷贝语义安全） */
zfy_seq *zfy_map_keys(zfy_map **mp) {
    zfy_map *m = *mp;
    long long n = m ? m->size : 0;
    zfy_seq *s = zfy_seq_new_k(n, n > 0 ? n : 1, 8, m && m->kstr ? 1 : 0, NULL);
    long long i = 0;
    if (m) {
        for (long long b = 0; b < m->nbuckets; b++) {
            for (zfy_ment *e = m->buckets[b]; e; e = e->next) {
                void *slot = (char *)s->data + i * 8;
                if (m->kstr) {
                    char *cp = zfy_strdup(e->k_s);
                    memcpy(slot, &cp, 8);
                } else {
                    memcpy(slot, &e->k_i, 8);
                }
                i++;
            }
        }
    }
    return s;
}

/* values(m)：值列表（vstr 时逐个 strdup；velemsz 4=f32 位模式 / 8=其余）。
 * 元素 kind 0（标量位模式）；string 值 kind=1 深拷贝语义 */
zfy_seq *zfy_map_values(zfy_map **mp, int vstr, int velemsz) {
    zfy_map *m = *mp;
    long long n = m ? m->size : 0;
    zfy_seq *s = zfy_seq_new_k(n, n > 0 ? n : 1, velemsz, vstr ? 1 : 0, NULL);
    long long i = 0;
    if (m) {
        for (long long b = 0; b < m->nbuckets; b++) {
            for (zfy_ment *e = m->buckets[b]; e; e = e->next) {
                void *slot = (char *)s->data + i * velemsz;
                if (vstr) {
                    char *cp = zfy_strdup((const char *)(unsigned long long)e->val);
                    memcpy(slot, &cp, velemsz);
                } else {
                    memcpy(slot, &e->val, velemsz);
                }
                i++;
            }
        }
    }
    return s;
}

/* ---------- 容器算法内建（v3.6）：sort/reverse/join/contains ----------
 * 全部返回新列表（值语义：原列表不动）。元素限 ≤64 位标量/string，
 * 排序比较按元素种类分派（宏生成）；谓词/比较器为 C thunk（llvmgen 生成）。 */

#define DEF_SORT(TAG, CMP_EXPR, DECL, ELEM_T)                              \
static int zfy_cmp_##TAG(const void *a, const void *b) {                   \
    DECL x = *(const ELEM_T *)a;                                           \
    DECL y = *(const ELEM_T *)b;                                           \
    return (CMP_EXPR);                                                     \
}                                                                          \
zfy_seq *zfy_sort_##TAG(zfy_seq *src) {                                    \
    if (!src) return zfy_seq_new_k(0, 1, 8, 0, NULL);                      \
    zfy_seq *s = zfy_seq_clone(src);                                       \
    if (s->len > 1)                                                        \
        qsort(s->data, (size_t)s->len, (size_t)s->elemsz, zfy_cmp_##TAG);  \
    return s;                                                              \
}

#define STRCMP(a, b) strcmp((a), (b))
DEF_SORT(i8, (x < y) ? -1 : (x > y), signed char, signed char)
DEF_SORT(i16, (x < y) ? -1 : (x > y), short, short)
DEF_SORT(i32, (x < y) ? -1 : (x > y), int, int)
DEF_SORT(i64, (x < y) ? -1 : (x > y), long long, long long)
DEF_SORT(u8, (x < y) ? -1 : (x > y), unsigned char, unsigned char)
DEF_SORT(u16, (x < y) ? -1 : (x > y), unsigned short, unsigned short)
DEF_SORT(u32, (x < y) ? -1 : (x > y), unsigned int, unsigned int)
DEF_SORT(u64, (x < y) ? -1 : (x > y), unsigned long long, unsigned long long)
DEF_SORT(f32, (x < y) ? -1 : (x > y), float, float)
DEF_SORT(f64, (x < y) ? -1 : (x > y), double, double)
DEF_SORT(str, STRCMP(x, y), char *, char *)

zfy_seq *zfy_reverse(zfy_seq *src) {
    if (!src) return zfy_seq_new_k(0, 1, 8, 0, NULL);
    zfy_seq *s = zfy_seq_clone(src);
    for (long long i = 0, j = s->len - 1; i < j; i++, j--) {
        char tmp[16];
        void *a = (char *)s->data + i * s->elemsz;
        void *b = (char *)s->data + j * s->elemsz;
        memcpy(tmp, a, (size_t)s->elemsz);
        memcpy(a, b, (size_t)s->elemsz);
        memcpy(b, tmp, (size_t)s->elemsz);
    }
    return s;
}

/* ---------- sort 内建（new.md 第3条）----------
 * sort(内容..., max|min)：min 从小到大、max 从大到小。
 * zfy_sort_chk_<TAG>：长度 <2 直接 die（编译期只挡 const 定长数组，
 * 非 const 容器的单元素检查在运行期）；升序排序后按 desc 原地倒置。
 * 调用方约定：传入的是调用方私有副本（列表 MCopy / 混合路径新建 acc），
 * 原地排序不影响源序列（值语义） */
#define DEF_SORT_CHK(TAG)                                                  \
zfy_seq *zfy_sort_chk_##TAG(zfy_seq *src, int32_t desc) {                  \
    if (!src || src->len < 2) zfy_die("sort: 至少需要 2 个元素");           \
    zfy_seq *s = zfy_sort_##TAG(src);   /* 内部已克隆，返回新表 */           \
    if (desc) {                                                            \
        for (long long i = 0, j = s->len - 1; i < j; i++, j--) {           \
            char tmp[16];                                                  \
            void *a = (char *)s->data + i * s->elemsz;                     \
            void *b = (char *)s->data + j * s->elemsz;                     \
            memcpy(tmp, a, (size_t)s->elemsz);                             \
            memcpy(a, b, (size_t)s->elemsz);                               \
            memcpy(b, tmp, (size_t)s->elemsz);                             \
        }                                                                  \
    }                                                                      \
    return s; }
DEF_SORT_CHK(i8)
DEF_SORT_CHK(i16)
DEF_SORT_CHK(i32)
DEF_SORT_CHK(i64)
DEF_SORT_CHK(u8)
DEF_SORT_CHK(u16)
DEF_SORT_CHK(u32)
DEF_SORT_CHK(u64)
DEF_SORT_CHK(f32)
DEF_SORT_CHK(f64)
DEF_SORT_CHK(str)

/* 混合排序的键提取：sk = 源元素类别
 *   0=有符号整数 1=无符号整数 2=浮点 3=string(取首字节码) 4=bool 5=char
 * string/char 按 ascii 码比、bool 等价 0/1（new.md 第3条） */
static long long seq_key_i(zfy_seq *s, long long i, int sk) {
    char *base = (char *)s->data + i * s->elemsz;
    switch (sk) {
    case 1:
        switch (s->elemsz) {
        case 1: return *(unsigned char *)base;
        case 2: return *(unsigned short *)base;
        case 4: return *(unsigned int *)base;
        default: return (long long)*(unsigned long long *)base;
        }
    case 2:
        return (long long)(s->elemsz == 4 ? (double)*(float *)base
                                          : *(double *)base);
    case 3: {
        char *st = *(char **)base;
        return st ? (long long)(unsigned char)st[0] : 0;
    }
    default: /* 0 / 4 / 5：按有符号读（bool/char 存储宽度即 elemsz） */
        switch (s->elemsz) {
        case 1: return *(signed char *)base;
        case 2: return *(short *)base;
        case 4: return *(int *)base;
        default: return *(long long *)base;
        }
    }
}

static double seq_key_d(zfy_seq *s, long long i, int sk) {
    char *base = (char *)s->data + i * s->elemsz;
    if (sk == 2)
        return s->elemsz == 4 ? (double)*(float *)base : *(double *)base;
    if (sk == 3) {
        char *st = *(char **)base;
        return st ? (double)(unsigned char)st[0] : 0.0;
    }
    return (double)seq_key_i(s, i, sk);
}

/* dst 末尾追加一个 8 字节元素（len==cap 时倍增扩容） */
static void seq_push8(zfy_seq *s, const void *v) {
    if (s->len >= s->cap) {
        s->cap = s->cap < 8 ? 8 : s->cap * 2;
        s->data = realloc(s->data, (size_t)(s->cap * s->elemsz));
        if (!s->data) zfy_die("sort: 内存分配失败");
    }
    memcpy((char *)s->data + s->len * s->elemsz, v, (size_t)s->elemsz);
    s->len++;
}

/* zfy_seq_extend_num(dst, src, sk, dk)：把 src 的元素逐个转成数值键
 * 追加到 dst（dk=0 → i64，dk=1 → f64）。混合排序的序列展平用 */
void zfy_seq_extend_num(zfy_seq *dst, zfy_seq *src, int32_t sk, int32_t dk) {
    if (!src) return;
    for (long long i = 0; i < src->len; i++) {
        if (dk == 0) {
            long long v = (sk == 2) ? (long long)seq_key_d(src, i, sk)
                                    : seq_key_i(src, i, sk);
            seq_push8(dst, &v);
        } else {
            double v = seq_key_d(src, i, sk);
            seq_push8(dst, &v);
        }
    }
}

/* string -> 排序键：首字节 ascii 码（空串 = 0） */
long long zfy_str_code(const char *s) {
    return (s && s[0]) ? (long long)(unsigned char)s[0] : 0;
}

/* 混合排序的标量追加（键 = i64 或 f64，元素宽 8 字节） */
void zfy_sort_push_i(zfy_seq *dst, long long v) { seq_push8(dst, &v); }
void zfy_sort_push_d(zfy_seq *dst, double v) { seq_push8(dst, &v); }

/* join(xs, sep)：string 列表拼接（元素 strdup 后释放），sep 可空串 */
char *zfy_join(zfy_seq *src, const char *sep) {
    if (!src) zfy_die("join: 源为空");
    size_t sl = strlen(sep), total = 1;
    for (long long i = 0; i < src->len; i++) {
        char *e = *(char **)((char *)src->data + i * 8);
        if (!e) zfy_die("join: 元素为空");
        total += strlen(e) + (i > 0 ? sl : 0);
    }
    char *out = (char *)malloc(total);
    if (!out) zfy_die("join: 内存分配失败");
    char *p = out;
    for (long long i = 0; i < src->len; i++) {
        if (i > 0) { memcpy(p, sep, sl); p += sl; }
        char *e = *(char **)((char *)src->data + i * 8);
        size_t el = strlen(e);
        memcpy(p, e, el); p += el;
    }
    *p = '\0';
    return out;
}

#define DEF_CONTAINS(TAG, EQ_EXPR, ELEM_T)                                 \
int zfy_contains_##TAG(zfy_seq *s, ELEM_T v) {                             \
    if (!s) return 0;                                                      \
    for (long long i = 0; i < s->len; i++) {                               \
        ELEM_T x = *(ELEM_T *)((char *)s->data + i * s->elemsz);           \
        if (EQ_EXPR) return 1;                                             \
    }                                                                      \
    return 0;                                                              \
}

DEF_CONTAINS(i8, x == v, signed char)
DEF_CONTAINS(i16, x == v, short)
DEF_CONTAINS(i32, x == v, int)
DEF_CONTAINS(i64, x == v, long long)
DEF_CONTAINS(u8, x == v, unsigned char)
DEF_CONTAINS(u16, x == v, unsigned short)
DEF_CONTAINS(u32, x == v, unsigned int)
DEF_CONTAINS(u64, x == v, unsigned long long)
DEF_CONTAINS(f32, x == v, float)
DEF_CONTAINS(f64, x == v, double)
DEF_CONTAINS(str, STRCMP(x, v) == 0, char *)

/* ---------- 容器算法内建（v3.10）：min/max/sum/count/index_of ----------
 * min/max：空列表 die（运行期错误）；返回元素值（str 返回指针，
 *   调用方按 TList 元素所有权约定深拷贝/接管）。
 * sum：仅数值列表，同型返回（回绕与既有算术语义一致）。
 * count：相等元素计数（str 用 strcmp）；index_of：首个相等下标（未找到 -1）。 */

#define DEF_MINMAX(TAG, DECL, ELEM_T)                                      \
static ELEM_T zfy_mm_##TAG(zfy_seq *s, int want_max) {                     \
    if (!s || s->len == 0)                                                 \
        zfy_die("min/max of empty list");                                  \
    ELEM_T best = *(ELEM_T *)(char *)s->data;                              \
    for (long long i = 1; i < s->len; i++) {                               \
        ELEM_T x = *(ELEM_T *)((char *)s->data + i * s->elemsz);           \
        if (want_max ? (x > best) : (x < best)) best = x;                  \
    }                                                                      \
    return best;                                                           \
}                                                                          \
ELEM_T zfy_min_##TAG(zfy_seq *s) { return zfy_mm_##TAG(s, 0); }            \
ELEM_T zfy_max_##TAG(zfy_seq *s) { return zfy_mm_##TAG(s, 1); }

DEF_MINMAX(i8, signed char, signed char)
DEF_MINMAX(i16, short, short)
DEF_MINMAX(i32, int, int)
DEF_MINMAX(i64, long long, long long)
DEF_MINMAX(u8, unsigned char, unsigned char)
DEF_MINMAX(u16, unsigned short, unsigned short)
DEF_MINMAX(u32, unsigned int, unsigned int)
DEF_MINMAX(u64, unsigned long long, unsigned long long)
DEF_MINMAX(f32, float, float)
DEF_MINMAX(f64, double, double)

char *zfy_min_str(zfy_seq *s) {
    if (!s || s->len == 0) zfy_die("min of empty list");
    char *best = *(char **)(char *)s->data;
    for (long long i = 1; i < s->len; i++) {
        char *x = *(char **)((char *)s->data + i * s->elemsz);
        if (strcmp(x, best) < 0) best = x;
    }
    /* 所有权约定：返回独立堆串（元素指针不得移交，槽 free 会双重释放） */
    return zfy_strdup(best);
}
char *zfy_max_str(zfy_seq *s) {
    if (!s || s->len == 0) zfy_die("max of empty list");
    char *best = *(char **)(char *)s->data;
    for (long long i = 1; i < s->len; i++) {
        char *x = *(char **)((char *)s->data + i * s->elemsz);
        if (strcmp(x, best) > 0) best = x;
    }
    return zfy_strdup(best);
}

#define DEF_SUM(TAG, ELEM_T)                                               \
ELEM_T zfy_sum_##TAG(zfy_seq *s) {                                         \
    if (!s) return (ELEM_T)0;                                              \
    ELEM_T acc = (ELEM_T)0;                                                \
    for (long long i = 0; i < s->len; i++)                                 \
        acc = (ELEM_T)(acc + *(ELEM_T *)((char *)s->data + i * s->elemsz));\
    return acc;                                                            \
}

DEF_SUM(i8, signed char)
DEF_SUM(i16, short)
DEF_SUM(i32, int)
DEF_SUM(i64, long long)
DEF_SUM(u8, unsigned char)
DEF_SUM(u16, unsigned short)
DEF_SUM(u32, unsigned int)
DEF_SUM(u64, unsigned long long)
DEF_SUM(f32, float)
DEF_SUM(f64, double)

#define DEF_COUNT(TAG, EQ_EXPR, ELEM_T)                                    \
long long zfy_count_##TAG(zfy_seq *s, ELEM_T v) {                          \
    if (!s) return 0;                                                      \
    long long n = 0;                                                       \
    for (long long i = 0; i < s->len; i++) {                               \
        ELEM_T x = *(ELEM_T *)((char *)s->data + i * s->elemsz);           \
        if (EQ_EXPR) n++;                                                  \
    }                                                                      \
    return n;                                                              \
}                                                                          \
long long zfy_index_of_##TAG(zfy_seq *s, ELEM_T v) {                       \
    if (!s) return -1;                                                     \
    for (long long i = 0; i < s->len; i++) {                               \
        ELEM_T x = *(ELEM_T *)((char *)s->data + i * s->elemsz);           \
        if (EQ_EXPR) return i;                                             \
    }                                                                      \
    return -1;                                                             \
}

DEF_COUNT(i8, x == v, signed char)
DEF_COUNT(i16, x == v, short)
DEF_COUNT(i32, x == v, int)
DEF_COUNT(i64, x == v, long long)
DEF_COUNT(u8, x == v, unsigned char)
DEF_COUNT(u16, x == v, unsigned short)
DEF_COUNT(u32, x == v, unsigned int)
DEF_COUNT(u64, x == v, unsigned long long)
DEF_COUNT(f32, x == v, float)
DEF_COUNT(f64, x == v, double)
DEF_COUNT(str, STRCMP(x, v) == 0, char *)

/* ---------- 标准库最小版（v3.12）：os_args / os_env / assert_eq ---------- */

#ifndef ZFY_FREESTANDING
/* os_args() -> list<string>：Windows CRT argv 规则解析 GetCommandLineA
 * （空格分隔，"..." 段内空格保留，"..." 内 "" 转义引号，反斜杠按 CRT 规则） */
zfy_seq *zfy_os_args(void) {
    char *cmd = GetCommandLineA();
    if (!cmd) cmd = "";
    /* 先数 argv 数量：CommandLineToArgvW 语义的轻量实现 */
    long long n = 0;
    for (const char *p = cmd; *p; ) {
        while (*p == ' ' || *p == '\t') p++;
        if (!*p) break;
        n++;
        int in_q = 0, bs = 0;
        for (; *p; p++) {
            if (*p == '\\') { bs++; continue; }
            if (*p == '"') {
                if (bs % 2 == 0) in_q = !in_q;
                bs = 0;
                continue;
            }
            bs = 0;
            if (!in_q && (*p == ' ' || *p == '\t')) break;
        }
    }
    zfy_seq *s = zfy_seq_new_k(n, n > 0 ? n : 1, 8, 1, NULL);
    long long i = 0;
    for (const char *p = cmd; *p && i < n; ) {
        while (*p == ' ' || *p == '\t') p++;
        if (!*p) break;
        /* 逐字符写出（处理转义）到动态缓冲 */
        size_t cap = 32, len = 0;
        char *buf = (char *)malloc(cap);
        if (!buf) zfy_die("os_args: out of memory");
        int in_q = 0, bs = 0;
        for (; *p; p++) {
            if (*p == '\\') { bs++; buf[len++] = *p; if (len + 2 > cap) { cap *= 2; buf = (char *)realloc(buf, cap); if (!buf) zfy_die("os_args: out of memory"); } continue; }
            if (*p == '"') {
                if (bs % 2 == 0) { in_q = !in_q; }
                /* 成对反斜杠后跟引号：CRT 规则减半反斜杠并可能吃引号 */
                long long drop = bs / 2;
                len -= drop;
                if (bs % 2 == 1) { buf[len++] = '"'; }
                else if (in_q) { buf[len++] = '"'; }
                bs = 0;
                if (len + 2 > cap) { cap *= 2; buf = (char *)realloc(buf, cap); if (!buf) zfy_die("os_args: out of memory"); }
                continue;
            }
            bs = 0;
            if (!in_q && (*p == ' ' || *p == '\t')) break;
            buf[len++] = *p;
            if (len + 2 > cap) { cap *= 2; buf = (char *)realloc(buf, cap); if (!buf) zfy_die("os_args: out of memory"); }
        }
        buf[len] = '\0';
        char *cp = buf;
        memcpy((char *)s->data + i * 8, &cp, 8);
        i++;
    }
    return s;
}

/* os_env(name) -> T! string：环境变量读取，未设置 = NOT_FOUND 错误值。
 * sret 写 zfy_err（同 input_err_str 布局） */
void zfy_os_env_err(zfy_err *out, const char *name) {
    char tmp[1024];
    DWORD n = GetEnvironmentVariableA(name, tmp, (DWORD)sizeof(tmp));
    if (n == 0 || n >= sizeof(tmp)) {
        err_set(out, ZFY_ENOT_FOUND, "os_env: 环境变量未设置");
        return;
    }
    out->code = ZFY_EOK;
    out->msg = NULL;
    out->value.p = zfy_strdup(tmp);
}
#endif /* !ZFY_FREESTANDING：os_args/os_env 段结束（assert_eq 纯计算，保留） */

/* assert_eq(a, b)（v3.12 测试内建）：不等 panic（打印两侧值）。 */
#define DEF_ASSERT(TAG, FMT, ELEM_T, FREAD)                                \
void zfy_assert_eq_##TAG(ELEM_T a, ELEM_T b) {                             \
    if (!(a == b)) {                                                       \
        char buf[128];                                                     \
        snprintf(buf, sizeof(buf), "assert_eq failed: " FMT " != " FMT,    \
                 (FREAD)a, (FREAD)b);                                      \
        zfy_die(buf);                                                      \
    }                                                                      \
}
DEF_ASSERT(i64, "%lld", long long, long long)
DEF_ASSERT(u64, "%llu", unsigned long long, unsigned long long)
DEF_ASSERT(f32, "%g", float, double)
DEF_ASSERT(f64, "%g", double, double)

void zfy_assert_eq_str(const char *a, const char *b) {
    if (!a || !b || strcmp(a, b) != 0) {
        char buf[512];
        snprintf(buf, sizeof(buf), "assert_eq failed: \"%s\" != \"%s\"",
                 a ? a : "(null)", b ? b : "(null)");
        zfy_die(buf);
    }
}

/* ---------- 闭包与容器高阶算法（v3.7） ----------
 * 闭包值 = 句柄 h（堆块地址）；堆块头部 code 指针，其后捕获字段。
 * 调用约定：code(env, args...)——env = 堆块地址（lambda 首参 $env）。
 * 容器内建收"闭包句柄 struct 槽地址"（{ ptr h }），解两层：
 *   h = *(void**)clo; code = *(void**)h; code(h, ...)。
 * 裸函数名在 typeck 包装为空捕获 wrapper 闭包（env 无关）。

/* ---- 句柄引用计数（v3.27 P0-1a）----
 * chan 对象 / mutex CS / 闭包 env / iface 装箱统一带 8 字节原子 rc 头。
 * 背景：assign 是浅拷共享（同一堆对象多槽引用），单主 free 会双释放/
 * 悬垂（thread_test 双闭包捕 chan、iface 进数组后 d1/d2/shapes 共享）。
 * 约定：new = rc(1)；LLVM 侧 assign 浅拷后调 zfy_rc_retain；
 * 释放侧一律 zfy_rc_release(p, dtor)——rc 归零才执行 dtor + free。
 * spawn 移交 = 宿主槽 rc 份额移交线程（spawn 后宿主槽裸置空不再释放） */
#if defined(_WIN32) && !defined(ZFY_FREESTANDING)
static long long *zfy_rc_of(void *p) { return ((long long *)p) - 1; }
static long long zfy_rc_alloced = 0, zfy_rc_freed = 0;   /* 泄漏统计（ZFY_LEAK_DEBUG） */
static void zfy_rc_report(void);
void *zfy_rc_alloc(size_t payload) {
#ifndef ZFY_FREESTANDING
    static int rep_hooked = 0;
    if (!rep_hooked) { rep_hooked = 1; atexit(zfy_rc_report); }
#endif
    long long *raw = (long long *)malloc(payload + 8);
    if (!raw) zfy_die("rc: 内存分配失败");
    *raw = 1;
    zfy_rc_alloced++;
    return (void *)(raw + 1);
}
void zfy_rc_retain(void *p) {
    if (p) InterlockedIncrement64(zfy_rc_of(p));
}
void zfy_rc_release(void *p, void (*dtor)(void *)) {
    if (!p) return;
    if (InterlockedDecrement64(zfy_rc_of(p)) == 0) {
        zfy_rc_freed++;
        if (dtor) dtor(p);
        free(zfy_rc_of(p));
    }
}
#else
static long long *zfy_rc_of(void *p) { return ((long long *)p) - 1; }
static long long zfy_rc_alloced = 0, zfy_rc_freed = 0;
static void zfy_rc_report(void);
void *zfy_rc_alloc(size_t payload) {
#ifndef ZFY_FREESTANDING
    static int rep_hooked = 0;
    if (!rep_hooked) { rep_hooked = 1; atexit(zfy_rc_report); }
#endif
    long long *raw = (long long *)malloc(payload + 8);
    if (!raw) zfy_die("rc: 内存分配失败");
    *raw = 1;
    zfy_rc_alloced++;
    return (void *)(raw + 1);
}
void zfy_rc_retain(void *p) { if (p) (*zfy_rc_of(p))++; }
void zfy_rc_release(void *p, void (*dtor)(void *)) {
    if (!p) return;
    if (--*zfy_rc_of(p) == 0) {
        zfy_rc_freed++;
        if (dtor) dtor(p);
        free(zfy_rc_of(p));
    }
}
#endif
#ifndef ZFY_FREESTANDING
/* 泄漏报告（P0-1a 验证）：ZFY_LEAK_DEBUG=1 时 atexit 打印 rc 对象
 * 分配/回收差值（>0 = 泄漏的闭包 env/chan/mutex/iface 装箱数） */
static void zfy_rc_report(void) {
    if (getenv("ZFY_LEAK_DEBUG") != NULL && zfy_rc_alloced != zfy_rc_freed)
        fprintf(stderr, "[zfy-leak] rc 对象泄漏: %lld (alloc %lld / freed %lld)\n",
                zfy_rc_alloced - zfy_rc_freed, zfy_rc_alloced, zfy_rc_freed);
}
#endif /* !ZFY_FREESTANDING：泄漏报告依赖 atexit/getenv/stderr */

/* env 堆块分配（v3.27 P0-1 引用计数；t-049/C 改自描述 dtor）：
 * 头 16 字节 = { dtor, rc }（dtor 在 rc 前 8 字节，rc 仍保持"载荷指针
 * 前 8 字节"约定），返回 payload 指针（字段偏移不受影响）。
 * dtor 由 LLVM 侧构造后经 zfy_env_set_dtor 写入（@zfy.clofree$<clenv>，
 * 级联释放捕获副本）；释放统一走 zfy_env_free——rc 归零时从块内取 dtor
 * 执行 + free 整块。此前释放侧由句柄方传 clenv 布局析构器，同签名多
 * lambda 布局不同时会错配（值捕获字段被当箱指针 rc_release → 崩溃）。
 * 注意：iface 装箱 / zbox 堆箱仍是 8 字节 rc 头（zfy_rc_alloc 分配 +
 * zfy_rc_release 释放，dtor 由调用方按类型传），不走本组接口 */
void *zfy_env_new(long long n) {
    size_t payload = (size_t)(n > 0 ? n : 1);
    long long *raw = (long long *)malloc(payload + 16);
    if (!raw) zfy_die("rc: 内存分配失败");
    raw[0] = 0;   /* dtor 槽（构造后由 zfy_env_set_dtor 写入） */
    raw[1] = 1;   /* rc = 1（new 约定） */
    zfy_rc_alloced++;
    return (void *)(raw + 2);
}

/* 写入 env 块自描述析构器（载荷指针, dtor） */
void zfy_env_set_dtor(void *p, void (*d)(void *)) {
    if (p) ((void (**)(void *))p)[-2] = d;
}

/* env 块释放（t-049/C）：rc 归零才执行块内 dtor（级联释放捕获副本）+
 * free 整块（malloc 起点在 dtor 槽）。null 安全（move 后槽/零值槽） */
void zfy_env_free(void *p) {
    if (!p) return;
    long long *rcp = ((long long *)p) - 1;        /* rc 槽 */
    void (**dp)(void *) = (void (**)(void *))rcp - 1;  /* dtor 槽 = 块起点 */
#if defined(_WIN32) && !defined(ZFY_FREESTANDING)
    if (InterlockedDecrement64(rcp) == 0) {
#else
    if (--*rcp == 0) {
#endif
        zfy_rc_freed++;
        if (*dp) (*dp)(p);
        free(dp);
    }
}

/* 从闭包槽解出调用入口 */
static void *clo_code(void *clo) {
    void *h = *(void **)clo;
    if (!h) zfy_die("closure is null");
    return *(void **)h;
}

/* 谓词/比较器统一约定（v3.7，元素按值传入）：
 *   元素调用类别 ck：0=整型/bool/char/指针（槽内按宽度读、零扩展到 8 字节），
 *   1=f32，2=f64，3=string（槽内指针直传）。与 llvmgen 注入的常量编码一致。
 *   谓词返回 i1（LLVM 约定 AL 低 1 位有效）→ C 侧按 int 读后 &1。
 *   filter/any/all：i32 (*pred)(void *env, <elem by value>)
 *   sort_by：       i32 (*cmp)(void *env, <a>, <b>)
 *   fold：          T (*f)(void *env, T acc, T elem)（按值种类宏生成） */
static long long load_int_elem(void *e, int esz) {
    switch (esz) {
    case 1: return (long long)(unsigned char)*(unsigned char *)e;
    case 2: return (long long)(unsigned short)*(unsigned short *)e;
    case 4: return (long long)(unsigned int)*(unsigned int *)e;
    default: return *(long long *)e;
    }
}
static int pred_call(void *code, void *env, void *e, int esz, int ck) {
    switch (ck) {
    case 1: return ((int (*)(void *, float))code)(env, *(float *)e) & 1;
    case 2: return ((int (*)(void *, double))code)(env, *(double *)e) & 1;
    case 3: return ((int (*)(void *, void *))code)(env, *(void **)e) & 1;
    default: return ((int (*)(void *, long long))code)(env, load_int_elem(e, esz)) & 1;
    }
}
zfy_seq *zfy_filter(zfy_seq *src, void *pred_clo, int ck) {
    if (!src) zfy_die("filter: source is null");
    void *code = clo_code(pred_clo);
    void *cenv = *(void **)pred_clo;
    zfy_seq *s = zfy_seq_new_k(0, src->len > 0 ? src->len : 1, src->elemsz,
                               src->kind, src->ops);
    for (long long i = 0; i < src->len; i++) {
        void *e = (char *)src->data + i * src->elemsz;
        if (pred_call(code, cenv, e, src->elemsz, ck)) {
            void *slot = (char *)s->data + s->len * s->elemsz;
            elem_init(slot, e, s->kind, s->ops, s->elemsz);
            s->len++;
        }
    }
    return s;
}

int zfy_any(zfy_seq *s, void *pred_clo, int ck) {
    if (!s) return 0;
    void *code = clo_code(pred_clo);
    void *cenv = *(void **)pred_clo;
    for (long long i = 0; i < s->len; i++)
        if (pred_call(code, cenv, (char *)s->data + i * s->elemsz,
                      s->elemsz, ck)) return 1;
    return 0;
}

int zfy_all(zfy_seq *s, void *pred_clo, int ck) {
    if (!s) return 0;
    void *code = clo_code(pred_clo);
    void *cenv = *(void **)pred_clo;
    for (long long i = 0; i < s->len; i++)
        if (!pred_call(code, cenv, (char *)s->data + i * s->elemsz,
                       s->elemsz, ck)) return 0;
    return 1;
}

/* sort_by：qsort 的比较器签名 (a, b) 不带上下文——经线程局部 env 中转
 * （zfy v1 无并发，安全）；元素按 ck 分发为值传给比较闭包；
 * 返回 clone 排序后的新表（值语义） */
static void *zfy_sb_env;
static void *zfy_sb_code;
static int zfy_sb_ck;
static int zfy_sb_esz;
static int zfy_sb_trampoline(const void *a, const void *b) {
    switch (zfy_sb_ck) {
    case 1: return ((int (*)(void *, float, float))zfy_sb_code)(
        zfy_sb_env, *(float *)a, *(float *)b);
    case 2: return ((int (*)(void *, double, double))zfy_sb_code)(
        zfy_sb_env, *(double *)a, *(double *)b);
    case 3: return ((int (*)(void *, void *, void *))zfy_sb_code)(
        zfy_sb_env, *(void **)a, *(void **)b);
    default: return ((int (*)(void *, long long, long long))zfy_sb_code)(
        zfy_sb_env, load_int_elem((void *)a, zfy_sb_esz),
        load_int_elem((void *)b, zfy_sb_esz));
    }
}
zfy_seq *zfy_sort_by(zfy_seq *src, void *cmp_clo, int ck) {
    if (!src) return zfy_seq_new_k(0, 1, 8, 0, NULL);
    zfy_seq *s = zfy_seq_clone(src);
    if (s->len > 1) {
        zfy_sb_code = clo_code(cmp_clo);
        zfy_sb_env = *(void **)cmp_clo;
        zfy_sb_ck = ck;
        zfy_sb_esz = s->elemsz;
        qsort(s->data, (size_t)s->len, (size_t)s->elemsz, zfy_sb_trampoline);
    }
    return s;
}

/* map(xs, f) -> list<B>（v3.7）：逐元素应用闭包，结果按 B 的种类写入新表。
 * sck/rck：源/结果元素的调用类别（按值传参、按返回类别取值——i/f32/f64/
 * string 分别经 rax/xmm0/返回指针寄存器约定拆位）；
 * string 返回堆串（所有权移交新表）。 */
zfy_seq *zfy_map_seq(zfy_seq *src, void *f_clo, int bkind, int belosz,
                     int sck, int rck) {
    if (!src) zfy_die("map: source is null");
    void *code = clo_code(f_clo);
    void *cenv = *(void **)f_clo;
    zfy_seq *s = zfy_seq_new_k(0, src->len > 0 ? src->len : 1, belosz,
                               bkind, NULL);
    for (long long i = 0; i < src->len; i++) {
        void *e = (char *)src->data + i * src->elemsz;
        long long r = 0;
        switch (sck) {
        case 1: {   /* f32 arg */
            if (rck == 2) { double d = ((double (*)(void *, float))code)(cenv, *(float *)e); memcpy(&r, &d, 8); }
            else if (rck == 1) { float f = ((float (*)(void *, float))code)(cenv, *(float *)e); memcpy(&r, &f, 4); }
            else if (rck == 3) { r = (long long)(intptr_t)((void *(*)(void *, float))code)(cenv, *(float *)e); }
            else r = ((long long (*)(void *, float))code)(cenv, *(float *)e);
            break; }
        case 2: {   /* f64 arg */
            if (rck == 2) { double d = ((double (*)(void *, double))code)(cenv, *(double *)e); memcpy(&r, &d, 8); }
            else if (rck == 1) { float f = ((float (*)(void *, double))code)(cenv, *(double *)e); memcpy(&r, &f, 4); }
            else if (rck == 3) { r = (long long)(intptr_t)((void *(*)(void *, double))code)(cenv, *(double *)e); }
            else r = ((long long (*)(void *, double))code)(cenv, *(double *)e);
            break; }
        case 3: {   /* string arg (heap ptr, f takes ownership) */
            if (rck == 2) { double d = ((double (*)(void *, void *))code)(cenv, *(void **)e); memcpy(&r, &d, 8); }
            else if (rck == 1) { float f = ((float (*)(void *, void *))code)(cenv, *(void **)e); memcpy(&r, &f, 4); }
            else if (rck == 3) { r = (long long)(intptr_t)((void *(*)(void *, void *))code)(cenv, *(void **)e); }
            else r = ((long long (*)(void *, void *))code)(cenv, *(void **)e);
            break; }
        default: {  /* int/bool/char/ptr arg (load by width, zero-extend) */
            long long v = load_int_elem(e, src->elemsz);
            if (rck == 2) { double d = ((double (*)(void *, long long))code)(cenv, v); memcpy(&r, &d, 8); }
            else if (rck == 1) { float f = ((float (*)(void *, long long))code)(cenv, v); memcpy(&r, &f, 4); }
            else if (rck == 3) { r = (long long)(intptr_t)((void *(*)(void *, long long))code)(cenv, v); }
            else r = ((long long (*)(void *, long long))code)(cenv, v);
            break; }
        }
        void *slot = (char *)s->data + s->len * s->elemsz;
        if (bkind == 1) {
            char *str = (char *)(uintptr_t)r;
            *(char **)slot = zfy_strdup(str);
            free(str);
        } else {
            memcpy(slot, &r, belosz);
        }
        s->len++;
    }
    return s;
}

#define DEF_REDUCE(TAG, ELEM_T)                                            \
ELEM_T zfy_fold_##TAG(zfy_seq *s, void *f_clo, ELEM_T init) {               \
    if (!s) return init;                                                   \
    ELEM_T (*f)(void *, ELEM_T, ELEM_T) =                                   \
        (ELEM_T (*)(void *, ELEM_T, ELEM_T))clo_code(f_clo);               \
    void *cenv = *(void **)f_clo;                                          \
    ELEM_T acc = init;                                                     \
    for (long long i = 0; i < s->len; i++)                                 \
        acc = f(cenv, acc, *(ELEM_T *)((char *)s->data + i * s->elemsz));  \
    return acc;                                                            \
}

DEF_REDUCE(i8, signed char)
DEF_REDUCE(i16, short)
DEF_REDUCE(i32, int)
DEF_REDUCE(i64, long long)
DEF_REDUCE(u8, unsigned char)
DEF_REDUCE(u16, unsigned short)
DEF_REDUCE(u32, unsigned int)
DEF_REDUCE(u64, unsigned long long)
DEF_REDUCE(f32, float)
DEF_REDUCE(f64, double)
/* string 归并：f 接管两个参数所有权（zfy 传参约定），结果串归调用方 */
char *zfy_fold_str(zfy_seq *s, void *f_clo, char *init) {
    if (!s) return init;
    char *(*f)(void *, char *, char *) =
        (char *(*)(void *, char *, char *))clo_code(f_clo);
    void *cenv = *(void **)f_clo;
    char *acc = init;
    for (long long i = 0; i < s->len; i++) {
        char *x = *(char **)((char *)s->data + i * s->elemsz);
        acc = f(cenv, acc, zfy_strdup(x));
    }
    return acc;
}

/* remove(数组, idx, out)：把 idx 槽位填零值（长度不变）；被删元素
 * 深拷贝副本写入 out（v3 2026-10-11 表达式化，out 可为 NULL 仅删除）。
 * 元素内含堆资源先深拷贝再释放；越界报错 */
void zfy_seq_zero(zfy_seq *s, long long idx, void *out) {
    if (!s) zfy_die("remove: 源为空");
    if (idx < 0 || idx >= s->len) zfy_die("remove: 数组下标越界");
    void *slot = seq_at(s, idx);
    if (out) elem_init(out, slot, s->kind, s->ops, s->elemsz);
    elem_dtor(slot, s->kind, s->ops);
    memset(slot, 0, (size_t)s->elemsz);
}

/* remove(列表, idx, out)：被删元素深拷贝副本写入 out，后续元素左移，
 * 长度 -1（v3 2026-10-11 表达式化，out 可为 NULL 仅删除）。越界报错 */
void zfy_seq_remove(zfy_seq *s, long long idx, void *out) {
    if (!s) zfy_die("remove: 源为空");
    if (idx < 0 || idx >= s->len) zfy_die("remove: 列表下标越界");
    void *slot = seq_at(s, idx);
    if (out) elem_init(out, slot, s->kind, s->ops, s->elemsz);
    elem_dtor(slot, s->kind, s->ops);
    memmove(slot, (char *)slot + s->elemsz,
            (size_t)(s->len - idx - 1) * (size_t)s->elemsz);
    s->len--;
    memset((char *)s->data + s->len * s->elemsz, 0, (size_t)s->elemsz);
}

/* 聚合元素写入（w-014 #2/#4）：src 为指向元素值的指针（struct 槽 /
   持 seq 指针的槽），按头部 kind/ops 深拷贝进槽位（先释放旧元素）。
   标量 kind 也走此路径时按位拷贝（与 zfy_seq_set_w 等价）。 */
void zfy_seq_set_agg(zfy_seq *s, long long idx, const void *src,
                     unsigned char grow) {
    seq_check(s, idx, grow);
    elem_assign(seq_at(s, idx), src, s->kind, s->ops, s->elemsz);
}

/* 聚合元素读出（w-014 #2/#4）：dst 为已分配的全零槽（struct 临时 /
   持 seq 指针的槽），按头部 kind/ops 深拷贝出独立副本（值语义） */
void zfy_seq_get_agg(const zfy_seq *s, long long idx, void *dst) {
    if (idx < 0 || idx >= s->len) zfy_die("数组/列表下标越界");
    elem_init(dst, seq_at(s, idx), s->kind, s->ops, s->elemsz);
}

/* 切片复合赋值 a[a..b:step] op= v：对区间内每个元素原地做 op（逐元素读-算-写）。
 * op: 0=+ 1=- 2=* 3=/ 4=%；val 为 i128 位模式缓冲指针（低 width 字节有效）；
 * 整数中间运算用 __int128，截断回 width 后不一致则报溢出；除零报错 */
void zfy_seq_aug_range(zfy_seq *s, long long a, long long b, long long step,
                       int op, const void *val, int width, int sgn,
                       int is_float) {
    if (!s) zfy_die("复合赋值: 源为空");
    if (step == 0) zfy_die("切片步长不能为 0");
    if (step > 0) {
        /* 空区间合法（a > b 产出空序列；a == len 为空起点）——
           ListBox.clear 等"清空容器"惯用法 xs[0, -1] 依赖此语义 */
        if (a < 0 || a > s->len || (a < s->len && a <= b && b >= s->len))
            zfy_die("切片区间越界");
    } else {
        /* 反向区间（new.md 2026-10-11）：a 递减到 b（闭区间），要求 a >= b */
        if (a >= s->len || b < 0 || a < b) zfy_die("切片区间越界");
    }
    for (long long i = a; i < s->len && (step > 0 ? i <= b : i >= b); i += step) {
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

/* 切片 base[a..b]（两端含，步长 step）：越界报错退出；返回新 seq。
 * 元素按头部 kind/ops 逐个深拷贝，保证切片独占堆资源（w-014 #2/#4）。
 * step<0 反向切片（new.md 2026-10-11）：从 a 递减收集到 b（闭区间），
 * 要求 a >= b；a < b 时区间非法报错。step=0 报错 */
zfy_seq *zfy_seq_slice(const zfy_seq *s, long long a, long long b,
                       long long step) {
    if (!s) zfy_die("切片: 源为空");
    if (step == 0) zfy_die("切片步长不能为 0");
    if (step > 0) {
        /* 空区间合法（a > b 产出空序列；a == len 为空起点）——清空惯用法 xs[0,-1] */
        if (a < 0 || a > s->len || (a < s->len && a <= b && b >= s->len))
            zfy_die("切片区间越界");
    } else {
        if (a >= s->len || b < 0 || a < b) zfy_die("切片区间越界");
    }
    long long n = (a > b || a >= s->len) ? 0 : (step > 0 ? (b - a) / step : (a - b) / (-step)) + 1;
    zfy_seq *r = zfy_seq_new_k(n, n, s->elemsz, s->kind, s->ops);
    long long j = 0;
    for (long long i = a; i < s->len && (step > 0 ? i <= b : i >= b); i += step, j++)
        elem_init(seq_at(r, j), seq_at(s, i), s->kind, s->ops, s->elemsz);
    return r;
}

/* ---------- 字符串方法运行时支持 ---------- */

/* s[i]：读单个字符（越界报错） */
char zfy_str_char(const char *s, long long idx) {
    long long n = (long long)strlen(s);
    if (idx < 0 || idx >= n) zfy_die("字符串下标越界");
    return s[idx];
}

/* s[i] = c：string 下标写字符（w-014 #5）。s 须为槽独占堆串
 * （MCopy strdup 保证），原地写安全；越界报错 */
void zfy_str_set(char *s, long long idx, char c) {
    if (!s) zfy_die("字符串下标写: 源为空");
    long long n = (long long)strlen(s);
    if (idx < 0 || idx >= n) zfy_die("字符串下标越界");
    s[idx] = c;
}

/* s[a..b]（两端含），按步长 step 收集字符，返回 malloc 新串。
 * step<0 反向切片（new.md 2026-10-11）：从 a 递减收集到 b（闭区间），
 * 要求 a >= b；a < b 时区间非法报错。step=0 报错 */
char *zfy_str_slice(const char *s, long long a, long long b, long long step) {
    long long n = (long long)strlen(s);
    if (step == 0) zfy_die("字符串切片步长不能为 0");
    if (step > 0) {
        /* 空区间合法（a > b 产出空串；a == n 为空起点） */
        if (a < 0 || a > n || (a < n && a <= b && b >= n))
            zfy_die("字符串切片区间越界");
    } else {
        if (a >= n || b < 0 || a < b) zfy_die("字符串切片区间越界");
    }
    long long cnt = (a > b || a >= n) ? 0 : (step > 0 ? (b - a) / step : (a - b) / (-step)) + 1;
    char *buf = (char *)malloc((size_t)cnt + 1);
    if (!buf) zfy_die("字符串切片: 内存分配失败");
    long long len = 0;
    for (long long i = a; i < n && (step > 0 ? i <= b : i >= b); i += step)
        buf[len++] = s[i];
    buf[len] = '\0';
    return buf;
}

/* ---------- UTF-8 感知 API（w-020，用户拍板扩展集） ----------
 * string 底层仍是字节串（length/下标/切片不变）；本组函数按码点视图操作。
 * 非法 UTF-8 字节：len/遍历按 1 字节计 1 码点（容错不 panic）。 */

/* 码点数（区别于 length 的字节数） */
long long zfy_utf8_len(const char *s) {
    long long n = 0;
    for (const unsigned char *p = (const unsigned char *)s; *p; p++)
        if ((*p & 0xC0) != 0x80) n++;   /* 非续字节 = 新码点起点 */
    return n;
}

/* 定位第 i 个码点（0 起）的字节区间 [start, end)，越界 panic。
   内部公共实现：返回码点总数（完整计数），区间经 out_start/out_end 带出 */
static long long utf8_locate(const char *s, long long i,
                             long long *out_start, long long *out_end) {
    const unsigned char *p = (const unsigned char *)s;
    long long cnt = 0, start = -1, end = -1;
    long long pos = 0, total = 0;
    while (p[pos]) {
        if ((p[pos] & 0xC0) != 0x80) {
            if (cnt == i) start = pos;
            else if (cnt == i + 1) end = pos;
            cnt++;
        }
        pos++;
    }
    total = cnt;
    if (start < 0) zfy_die("utf8 下标越界");
    if (end < 0) end = pos;   /* i 是最后一个码点 */
    *out_start = start;
    *out_end = end;
    return total;
}

/* 第 i 个码点（0 起）返回 malloc 单码点串（可能多字节；越界 panic） */
char *zfy_utf8_char_at(const char *s, long long i) {
    if (i < 0) zfy_die("utf8 下标越界");
    long long st, en;
    utf8_locate(s, i, &st, &en);
    char *buf = (char *)malloc((size_t)(en - st) + 1);
    if (!buf) zfy_die("utf8_char_at: 内存分配失败");
    memcpy(buf, s + st, (size_t)(en - st));
    buf[en - st] = '\0';
    return buf;
}

/* 按码点闭区间 [a, b] 切片（两端含，越界/非法 panic），返回 malloc 新串 */
char *zfy_utf8_sub(const char *s, long long a, long long b) {
    if (a < 0 || a > b) zfy_die("utf8 切片区间越界");
    long long st2, en2;
    long long total = utf8_locate(s, a, &st2, &en2);   /* 顺带校验 a < total */
    (void)en2;
    if (b >= total) zfy_die("utf8 切片区间越界");
    long long st, en;
    utf8_locate(s, b, &st, &en);
    char *buf = (char *)malloc((size_t)(en - st2) + 1);
    if (!buf) zfy_die("utf8_sub: 内存分配失败");
    memcpy(buf, s + st2, (size_t)(en - st2));
    buf[en - st2] = '\0';
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

/* w-020：两参 replace（replace_from）已按用户拍板删除——
   "替换到串尾"用四参 replace(s, a, n-1, rep) 的闭区间即可表达 */

/* 拼接两个字符串，返回 malloc 新串 */
/* string 内容比较（== / !=，w-011）：strcmp 封装，返回 0/1 */
long long zfy_str_eq(const char *a, const char *b) {
    return strcmp(a, b) == 0;
}

long long zfy_str_ne(const char *a, const char *b) {
    return strcmp(a, b) != 0;
}

/* string 字典序比较（w-020）：返回 strcmp 三态（<0 / 0 / >0），
   逐字符按 ASCII 比到第一个不同字符即断（用户拍板语义） */
int zfy_str_cmp(const char *a, const char *b) {
    return strcmp(a, b);
}

char *zfy_str_concat(const char *a, const char *b) {
    size_t la = strlen(a), lb = strlen(b);
    char *buf = (char *)malloc(la + lb + 1);
    if (!buf) zfy_die("字符串拼接: 内存分配失败");
    memcpy(buf, a, la);
    memcpy(buf + la, b, lb);
    buf[la + lb] = '\0';
    return buf;
}

/* 原地追加（T7 优化）：b 并入 a 的缓冲区（realloc 扩容），返回新指针。
   a 必须是槽独占的 malloc 堆串（MCopy 对字面量 strdup 保证），
   调用方不得再使用旧 a（realloc 可能移动缓冲区） */
char *zfy_str_append(char *a, const char *b) {
    size_t la = strlen(a), lb = strlen(b);
    char *p = (char *)realloc(a, la + lb + 1);
    if (!p) zfy_die("字符串追加: 内存分配失败");
    memcpy(p + la, b, lb);
    p[la + lb] = '\0';
    return p;
}

/* 批量原地追加（T7 优化）：n 个片段并入 a 的缓冲区。
   用 _msize 感知堆块容量：容量足够则原地写入（零重分配），
   不足则按 2 倍几何扩容（与 C++ std::string 增长策略一致），
   避免逐次 realloc 的拷贝与堆碎片。a 必须是本运行时 malloc/realloc
   分配的堆串（槽独占，MCopy strdup 保证），调用方不得再使用旧 a */
char *zfy_str_append_n(char *a, const char **parts, long long n) {
    size_t la = strlen(a), total = la + 1;
    for (long long i = 0; i < n; i++)
        total += strlen(parts[i]);
    size_t cap = _msize(a);
    char *p;
    if (total <= cap) {
        p = a;                       /* 容量足够：原地写，零重分配 */
    } else {
        size_t nc = cap * 2;
        if (nc < total) nc = total;
        p = (char *)realloc(a, nc);
        if (!p) zfy_die("字符串追加: 内存分配失败");
    }
    char *q = p + la;
    for (long long i = 0; i < n; i++) {
        size_t lb = strlen(parts[i]);
        memcpy(q, parts[i], lb);
        q += lb;
    }
    *q = '\0';
    return p;
}

/* 按分隔符切分为 string 列表：返回 zfy_seq（元素宽度 8=指针），
 * 各段为 malloc 堆串、len = 段数（连续分隔符产生空段）。
 * 内部公共实现：c>=0 按单字符，否则按 delim 整串 */
static zfy_seq *split_impl(const char *s, char c, const char *delim) {
    size_t dl = (c >= 0) ? 1 : strlen(delim);
    if (dl == 0) {
        /* 空分隔符：不切分，返回单段 [s] */
        zfy_seq *seq = zfy_seq_new_k(1, 1, 8, 1, NULL);
        char *seg = zfy_strdup(s);
        memcpy(seq_at(seq, 0), &seg, sizeof(seg));
        return seq;
    }
    long long cnt = 1;
    size_t sl = strlen(s);   /* 预计算长度：原实现循环内 strlen 是 O(n²) */
    for (const char *p = s; *p; p++)
        if ((c >= 0 && *p == c) ||
            (c < 0 && (size_t)(p - s) + dl <= sl &&
             memcmp(p, delim, dl) == 0))
            cnt++;
    zfy_seq *seq = zfy_seq_new_k(cnt, cnt, 8, 1, NULL);
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

/* ---------- OS 熵源（v3.2 随机数模块：Random.seed_from_entropy /
   SecureRandom 播种） ----------
   Windows: 动态加载 advapi32!SystemFunction036（RtlGenRandom），免附加
   链接库（kernel32 的 GetModuleHandle/GetProcAddress 恒可用）；
   POSIX: getentropy()。
   熵源不可用属不可恢复错误，fail-fast die。 */

#ifndef ZFY_FREESTANDING
/* ---- 控制台 UTF-8 统一（编码策略：进程内所有 string 均为 UTF-8 字节） ----
 * Windows 控制台默认代码页（如 936/GBK）会导致 UTF-8 中文经 printf/fwrite
 * 输出乱码、input() 键入字节为 GBK。进程加载时强制代码页 65001：
 * 输出侧 UTF-8 字节直通、输入侧 ReadConsoleA 产 UTF-8 字节，与 string 内部
 * 表示一致。GUI 侧本就 CP_UTF8 转换，不受影响。 */
#ifdef _WIN32
static void zfy_console_utf8_init(void) __attribute__((constructor));
static void zfy_console_utf8_init(void) {
    if (GetConsoleWindow() != NULL) {
        SetConsoleOutputCP(65001);
        SetConsoleCP(65001);
    }
}
#endif

void zfy_os_random_u64(unsigned long long *out) {
#ifdef _WIN32
    typedef unsigned char (WINAPI *rng_fn)(void *, unsigned long);
    HMODULE h = GetModuleHandleA("Advapi32.dll");
    rng_fn pfn = NULL;
    if (!h) h = LoadLibraryA("Advapi32.dll");
    if (h) pfn = (rng_fn)(void *)GetProcAddress(h, "SystemFunction036");
    if (!pfn) zfy_die("os_random: SystemFunction036 unavailable");
    if (!pfn(out, 8)) zfy_die("os_random: SystemFunction036 failed");
#else
    if (getentropy(out, 8) != 0) zfy_die("os_random: getentropy failed");
#endif
}
#endif /* !ZFY_FREESTANDING：OS 熵源 / 控制台代码页段结束 */

/* ---------- 整数溢出 panic（任务一：默认检查）----------
   LLVM 侧用 llvm.*.with.overflow 内建/前置比较判定溢出，命中时调用本函数。
   走 zfy_die → zfy_panic 路径（打印位置、可被 try() 捕获）。 */
void zfy_overflow_panic(const char *op, long long a, long long b) {
    char buf[256];
    snprintf(buf, sizeof buf, "%s (left=%lld, right=%lld)", op, a, b);
    zfy_die(buf);
}

/* ---------- ** 幂运算（v3.3）：整数快速幂 ----------
   平方乘法；有符号版负指数得 0（整数幂无意义取截断语义）；
   内部按无符号回绕乘法（与 LLVM mul 一致，避免 C 有符号溢出 UB） */
long long zfy_pow_ll(long long b, long long e) {
    if (e < 0) return 0;
    unsigned long long ub = (unsigned long long)b;
    unsigned long long r = 1;
    while (e > 0) {
        if (e & 1) r *= ub;
        ub *= ub;
        e >>= 1;
    }
    return (long long)r;
}

unsigned long long zfy_pow_ull(unsigned long long b, unsigned long long e) {
    unsigned long long r = 1;
    while (e > 0) {
        if (e & 1) r *= b;
        b *= b;
        e >>= 1;
    }
    return r;
}

/* 带溢出标志的 64 位幂（任务一检查模式）：结果保持回绕语义（与旧版一致），
   溢出时置 ov=1；调用方（LLVM guard）决定 panic。 */
long long zfy_pow_ll_ov(long long b, long long e, unsigned char *ov);
unsigned long long zfy_pow_ull_ov(unsigned long long b, unsigned long long e,
                                  unsigned char *ov);

long long zfy_pow_ll_ov(long long b, long long e, unsigned char *ov) {
    if (e < 0) { *ov = 0; return 0; }
    /* 有符号幂：按绝对值计算，再按结果符号判定是否超出有符号范围。
       不能直接把负底数当无符号位型（(-3)^2 会因 (2^64-3)^2 无符号溢出误报） */
    unsigned long long m = (unsigned long long)b;
    int neg = b < 0 && (e & 1);
    if (b < 0) m = 0ULL - m;
    unsigned long long lim = neg ? (1ULL << 63) : ((1ULL << 63) - 1);
    unsigned long long r = 1;
    unsigned long long ee = (unsigned long long)e;
    *ov = 0;
    while (ee > 0) {
        if (ee & 1) {
            unsigned long long t;
            if (__builtin_mul_overflow(r, m, &t)) *ov = 1;
            else if (t > lim) *ov = 1;
            r = t;
        }
        ee >>= 1;
        if (ee > 0) {
            unsigned long long t;
            if (__builtin_mul_overflow(m, m, &t)) *ov = 1;
            m = t;
        }
    }
    return neg ? (long long)(0ULL - r) : (long long)r;
}

unsigned long long zfy_pow_ull_ov(unsigned long long b, unsigned long long e,
                                  unsigned char *ov) {
    unsigned long long r = 1;
    *ov = 0;
    while (e > 0) {
        if (e & 1) {
            unsigned long long t;
            if (__builtin_mul_overflow(r, b, &t)) *ov = 1;
            r = t;
        }
        e >>= 1;
        if (e > 0) {
            unsigned long long t;
            if (__builtin_mul_overflow(b, b, &t)) *ov = 1;
            b = t;
        }
    }
    return r;
}

/* ---------- ** 幂运算 128 位扩展（v3.3.3） ----------
   参数与结果全部走 64 位对（out[0]=低 64 位 / out[1]=高 64 位），
   规避 win32 __int128 参数/返回 ABI 的 byval/sret 约定（同
   zfy_stoi_wide 策略）；内部按无符号回绕乘法（与 LLVM mul 一致）；
   指数支持完整 128 位（平方乘迭代次数 = 指数位长 ≤ 128）；
   有符号版负指数得 0（与 zfy_pow_ll 语义一致）。 */
void zfy_pow_u128(unsigned long long out[2],
                  unsigned long long blo, unsigned long long bhi,
                  unsigned long long elo, unsigned long long ehi) {
    unsigned __int128 b = ((unsigned __int128)bhi << 64) | blo;
    unsigned __int128 e = ((unsigned __int128)ehi << 64) | elo;
    unsigned __int128 r = 1;
    while (e > 0) {
        if (e & 1) r *= b;
        b *= b;
        e >>= 1;
    }
    out[0] = (unsigned long long)r;
    out[1] = (unsigned long long)(r >> 64);
}

void zfy_pow_i128(long long out[2],
                  long long blo, long long bhi,
                  long long elo, long long ehi) {
    if (ehi < 0) { out[0] = 0; out[1] = 0; return; } /* 负指数 → 0 */
    unsigned __int128 b = ((unsigned __int128)(unsigned long long)bhi << 64)
                        | (unsigned long long)blo;
    unsigned __int128 e = ((unsigned __int128)(unsigned long long)ehi << 64)
                        | (unsigned long long)elo;
    unsigned __int128 r = 1;
    while (e > 0) {
        if (e & 1) r *= b;
        b *= b;
        e >>= 1;
    }
    out[0] = (unsigned long long)r;
    out[1] = (unsigned long long)(r >> 64);
}

/* 带溢出标志的 128 位幂（任务一检查模式）：结果保持回绕语义，
   任一乘法溢出时置 ov=1（调用方 LLVM guard 决定 panic） */
void zfy_pow_u128_ov(unsigned long long out[2],
                     unsigned long long blo, unsigned long long bhi,
                     unsigned long long elo, unsigned long long ehi,
                     unsigned char *ov) {
    unsigned __int128 b = ((unsigned __int128)bhi << 64) | blo;
    unsigned __int128 e = ((unsigned __int128)ehi << 64) | elo;
    unsigned __int128 r = 1;
    *ov = 0;
    while (e > 0) {
        if (e & 1) {
            unsigned __int128 t;
            if (__builtin_mul_overflow(r, b, &t)) *ov = 1;
            r = t;
        }
        e >>= 1;
        if (e > 0) {
            unsigned __int128 t;
            if (__builtin_mul_overflow(b, b, &t)) *ov = 1;
            b = t;
        }
    }
    out[0] = (unsigned long long)r;
    out[1] = (unsigned long long)(r >> 64);
}

void zfy_pow_i128_ov(long long out[2],
                     long long blo, long long bhi,
                     long long elo, long long ehi,
                     unsigned char *ov) {
    if (ehi < 0) { out[0] = 0; out[1] = 0; *ov = 0; return; } /* 负指数 → 0 */
    /* 有符号 128 位幂：同 64 位版，按绝对值 + 符号位判定（避免负底数平方
       被无符号溢出规则误报） */
    unsigned __int128 e = ((unsigned __int128)(unsigned long long)ehi << 64)
                          | (unsigned long long)elo;
    unsigned __int128 m = ((unsigned __int128)(unsigned long long)bhi << 64)
                          | (unsigned long long)blo;
    int neg = bhi < 0 && (e & 1);
    if (bhi < 0) m = (unsigned __int128)0 - m;
    unsigned __int128 lim = neg ? ((unsigned __int128)1 << 127)
                                : (((unsigned __int128)1 << 127) - 1);
    unsigned __int128 r = 1;
    *ov = 0;
    while (e > 0) {
        if (e & 1) {
            unsigned __int128 t;
            if (__builtin_mul_overflow(r, m, &t)) *ov = 1;
            else if (t > lim) *ov = 1;
            r = t;
        }
        e >>= 1;
        if (e > 0) {
            unsigned __int128 t;
            if (__builtin_mul_overflow(m, m, &t)) *ov = 1;
            m = t;
        }
    }
    if (neg) r = (unsigned __int128)0 - r;
    out[0] = (unsigned long long)r;
    out[1] = (unsigned long long)(r >> 64);
}

/* ---------- 时间内建（v3.3.6）：时间戳 / 单调计时 / sleep / 日历拆解与构造 ----------
 * datetime 布局与 LLVM %struct.datetime 一致：8 个 int32_t（32 字节），
 * zfy_time_local 以 sret 首参写入（调用方分配槽位）。
 * weekday: 0=周日..6=周六（tm_wday 语义）；yday: 年内第几天，0 起（tm_yday）。 */
#ifndef ZFY_FREESTANDING
typedef struct {
    int32_t year, month, day, hour, minute, second, weekday, yday;
} zfy_datetime;

int64_t zfy_time_now(void) {
    return (int64_t)time(NULL);
}

int64_t zfy_time_tick(void) {
#ifdef _WIN32
    static LARGE_INTEGER freq = { { 0 } };
    static LARGE_INTEGER start;
    static int inited = 0;
    if (!inited) {
        QueryPerformanceFrequency(&freq);
        QueryPerformanceCounter(&start);
        inited = 1;
    }
    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);
    /* 先乘后除，ms 精度足够且避免溢出（freq 约 1e7，span 上限 ~2.9 万年） */
    return (int64_t)((now.QuadPart - start.QuadPart) * 1000 / freq.QuadPart);
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
#endif
}

void zfy_time_sleep(int64_t ms) {
    if (ms < 0) ms = 0;
#ifdef _WIN32
    Sleep((DWORD)ms);
#else
    struct timespec req;
    req.tv_sec = (time_t)(ms / 1000);
    req.tv_nsec = (long)((ms % 1000) * 1000000L);
    while (nanosleep(&req, &req) == -1 && errno == EINTR) { /* 重试剩余部分 */ }
#endif
}

void zfy_time_local(zfy_datetime *out, int64_t ts) {
    time_t t = (time_t)ts;
    struct tm tmv;
#ifdef _WIN32
    if (localtime_s(&tmv, &t) != 0) { memset(&tmv, 0, sizeof(tmv)); }
#else
    if (localtime_r(&t, &tmv) == NULL) { memset(&tmv, 0, sizeof(tmv)); }
#endif
    out->year   = (int32_t)(tmv.tm_year + 1900);
    out->month  = (int32_t)(tmv.tm_mon + 1);
    out->day    = (int32_t)tmv.tm_mday;
    out->hour   = (int32_t)tmv.tm_hour;
    out->minute = (int32_t)tmv.tm_min;
    out->second = (int32_t)tmv.tm_sec;
    out->weekday = (int32_t)tmv.tm_wday;
    out->yday   = (int32_t)tmv.tm_yday;
}

int64_t zfy_time_mktime(int64_t y, int64_t mo, int64_t d,
                        int64_t h, int64_t mi, int64_t s) {
    /* 各分量允许越界（32 日、13 月等），由 mktime 归一化——日期算术的基础 */
    struct tm tmv;
    memset(&tmv, 0, sizeof(tmv));
    tmv.tm_year = (int)(y - 1900);
    tmv.tm_mon  = (int)(mo - 1);
    tmv.tm_mday = (int)d;
    tmv.tm_hour = (int)h;
    tmv.tm_min  = (int)mi;
    tmv.tm_sec  = (int)s;
    tmv.tm_isdst = -1;   /* 交由系统判定夏令时 */
    time_t t = mktime(&tmv);
    return (t == (time_t)-1) ? -1 : (int64_t)t;
}
#endif /* !ZFY_FREESTANDING：时间内建段结束（依赖 time/localtime/mktime/sleep） */

/* ---------- 内建随机 + 计时器（v3.28 new.md 第1、2条）----------
 * rand 系：xoshiro256** 引擎 + SplitMix64 播种（全局单序列；未 seed 先用
 * 自动种子 0）。choice/sample/shuffle 泛型走 zfy_seq（elemsz 逐元素拷贝，
 * string 列表按 kind strdup 保证元素所有权独立）。timer 系：固定 4096 槽
 * 表（序号可不连续）+ QPC 单调计时；base 累计已冻结秒数，running 时叠加
 * 自 stamp 起的增量。 */

static uint64_t g_rng_s[4];
static int g_rng_seeded = 0;

static uint64_t rng_splitmix64(uint64_t *x) {
    uint64_t z = (*x += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

void zfy_rand_seed(int64_t seed) {
    uint64_t x = (uint64_t)seed;
    for (int i = 0; i < 4; i++) g_rng_s[i] = rng_splitmix64(&x);
    g_rng_seeded = 1;
}

static uint64_t rng_next(void) {
    if (!g_rng_seeded) zfy_rand_seed(0);
    /* xoshiro256**：result = rotl(s[1] * 5, 7) * 9 */
    uint64_t r5 = g_rng_s[1] * 5ULL;
    uint64_t result = ((r5 << 7) | (r5 >> 59)) * 9ULL;
    uint64_t t = g_rng_s[1] << 17;
    g_rng_s[2] ^= g_rng_s[0];
    g_rng_s[3] ^= g_rng_s[1];
    g_rng_s[1] ^= g_rng_s[2];
    g_rng_s[0] ^= g_rng_s[3];
    g_rng_s[2] ^= t;
    g_rng_s[3] = (g_rng_s[3] << 45) | (g_rng_s[3] >> 19);
    return result;
}

/* Lemire 无偏 [0, n) */
static uint64_t rng_below(uint64_t n) {
    uint64_t x = rng_next();
    __uint128_t m = (__uint128_t)x * n;
    uint64_t l = (uint64_t)m;
    if (l < n) {
        uint64_t t = (uint64_t)(0 - n) % n;
        while (l < t) {
            x = rng_next();
            m = (__uint128_t)x * n;
            l = (uint64_t)m;
        }
    }
    return (uint64_t)(m >> 64);
}

/* 128 位宽度的无偏 [0, span)（frac 宽区间用） */
static uint64_t rng_below128(unsigned __int128 span) {
    unsigned __int128 wrap = ((unsigned __int128)0 - span) % span;
    unsigned __int128 r;
    do {
        r = ((unsigned __int128)rng_next() << 64) | rng_next();
    } while (r < wrap);
    return (uint64_t)(r % span);
}

int64_t zfy_rand_i64(int64_t a, int64_t b) {
    if (a > b) { int64_t t = a; a = b; b = t; }
    if (a == INT64_MIN && b == INT64_MAX) return (int64_t)rng_next();
    uint64_t span = (uint64_t)(b - a);
    return a + (int64_t)rng_below(span + 1);
}

uint64_t zfy_rand_u64(uint64_t a, uint64_t b) {
    if (a > b) { uint64_t t = a; a = b; b = t; }
    uint64_t span = b - a;
    if (span == UINT64_MAX) return rng_next();
    return a + rng_below(span + 1);
}

#define DEF_RANDI(SUF, T)                                                  \
T zfy_rand_##SUF(T a, T b) {                                               \
    if (a > b) { T t = a; a = b; b = t; }                                  \
    return (T)zfy_rand_i64((int64_t)a, (int64_t)b); }

DEF_RANDI(i8, int8_t)
DEF_RANDI(i16, int16_t)
DEF_RANDI(i32, int32_t)
DEF_RANDI(u8, uint8_t)
DEF_RANDI(u16, uint16_t)
DEF_RANDI(u32, uint32_t)

double zfy_rand_f64(double a, double b) {
    if (a > b) { double t = a; a = b; b = t; }
    return a + (b - a) * (double)(rng_next() >> 11) * 0x1.0p-53;
}

float zfy_rand_f32(float a, float b) {
    if (a > b) { float t = a; a = b; b = t; }
    return (float)((double)a + ((double)b - (double)a)
                   * (double)(rng_next() >> 11) * 0x1.0p-53);
}

_Bool zfy_rand_bool(void) { return rng_below(2) != 0; }

int8_t zfy_rand_char(int64_t a, int64_t b) {
    return (int8_t)zfy_rand_i64(a, b);
}

/* rand(A)：字符串 A 内随机一个 UTF-8 码点，返回单码点堆串 */
char *zfy_rand_char_in(const char *s) {
    if (!s || !s[0]) zfy_die("rand: 空字符串没有可随机字符");
    long long n = 0;
    for (const unsigned char *p = (const unsigned char *)s; *p; p++)
        if ((*p & 0xC0) != 0x80) n++;
    if (n == 0) zfy_die("rand: 空字符串没有可随机字符");
    long long idx = (long long)rng_below((uint64_t)n);
    const unsigned char *p = (const unsigned char *)s;
    for (long long k = 0; k < idx; k++) {
        p++;
        while ((*p & 0xC0) == 0x80) p++;
    }
    int len = 1;
    while (p[len] && (p[len] & 0xC0) == 0x80) len++;
    char *out = (char *)malloc((size_t)len + 1);
    if (!out) zfy_die("内存分配失败");
    memcpy(out, p, (size_t)len);
    out[len] = '\0';
    return out;
}

/* 元素拷贝（string 列表 strdup 保证所有权独立） */
static void seq_copy_elem(zfy_seq *dst, long long di, zfy_seq *src, long long si) {
    const char *e = (const char *)src->data + si * src->elemsz;
    char *d = (char *)dst->data + di * dst->elemsz;
    if (src->kind == 1)
        *(char **)d = zfy_strdup(*(const char **)e);
    else
        memcpy(d, e, (size_t)src->elemsz);
}

zfy_seq *zfy_choice_seq(zfy_seq *src, int64_t k) {
    if (!src) zfy_die("choice: 源为空");
    if (k <= 0) zfy_die("choice: num 必须大于 0");
    if (src->len == 0) zfy_die("choice: 空列表");
    zfy_seq *out = zfy_seq_new_k(k, k, src->elemsz, src->kind, NULL);
    for (int64_t i = 0; i < k; i++)
        seq_copy_elem(out, i, src, (long long)rng_below((uint64_t)src->len));
    return out;
}

zfy_seq *zfy_sample_seq(zfy_seq *src, int64_t k) {
    if (!src) zfy_die("sample: 源为空");
    if (k <= 0) zfy_die("sample: num 必须大于 0");
    if (k > src->len) zfy_die("sample: num 大于元素个数（无放回抽样）");
    /* 索引池部分洗牌：不动源列表 */
    int64_t *pool = (int64_t *)malloc(sizeof(int64_t) * (size_t)src->len);
    if (!pool) zfy_die("内存分配失败");
    for (int64_t i = 0; i < src->len; i++) pool[i] = i;
    zfy_seq *out = zfy_seq_new_k(k, k, src->elemsz, src->kind, NULL);
    for (int64_t i = 0; i < k; i++) {
        int64_t j = i + (int64_t)rng_below((uint64_t)(src->len - i));
        int64_t t = pool[i]; pool[i] = pool[j]; pool[j] = t;
        seq_copy_elem(out, i, src, pool[i]);
    }
    free(pool);
    return out;
}

/* Fisher-Yates 原地洗牌；返回 src 本身（多值形态回传临时列表） */
zfy_seq *zfy_shuffle_seq(zfy_seq *s) {
    if (!s) zfy_die("shuffle: 源为空");
    for (int64_t i = s->len - 1; i > 0; i--) {
        int64_t j = (int64_t)rng_below((uint64_t)(i + 1));
        char *a = (char *)s->data + i * s->elemsz;
        char *b = (char *)s->data + j * s->elemsz;
        for (int by = 0; by < s->elemsz; by++) {
            char t = a[by]; a[by] = b[by]; b[by] = t;
        }
    }
    return s;
}

/* frac 区间随机：k ∈ [A.num*B.den, B.num*B.den? ] 统一格点 —— 先符号归一
 * （分母转正、必要时交换 A/B），k 在 [A.num*B.den, B.num*A.den? ] 由
 * an*bd 起、跨度 bn*ad - an*bd 内均匀取，结果 k/(ad*bd) 后约分 */
static unsigned __int128 gcd128_u(unsigned __int128 x, unsigned __int128 y) {
    while (y) { unsigned __int128 t = x % y; x = y; y = t; }
    return x;
}

#define DEF_RANDFRAC(SUF, T)                                                   \
void zfy_rand_frac_##SUF(zfy_frac_##SUF *out, const zfy_frac_##SUF *a,         \
                         const zfy_frac_##SUF *b) {                            \
    __int128 an = (__int128)a->n, ad = (__int128)a->d;                         \
    __int128 bn = (__int128)b->n, bd = (__int128)b->d;                         \
    if (ad == 0 || bd == 0) zfy_die("rand: 分母为零");                          \
    if (ad < 0) { ad = -ad; an = -an; }                                        \
    if (bd < 0) { bd = -bd; bn = -bn; }                                        \
    if (an * bd > bn * ad) {                                                   \
        __int128 tn = an, tdd = ad; an = bn; ad = bd; bn = tn; bd = tdd;       \
    }                                                                          \
    unsigned __int128 span = (unsigned __int128)(bn * ad - an * bd);           \
    if (span == 0) { out->n = a->n; out->d = a->d; return; }                   \
    __int128 kk = an * bd + (__int128)rng_below128(span);                      \
    unsigned __int128 dd = (unsigned __int128)(ad * bd);                       \
    unsigned __int128 uk = kk < 0 ? (unsigned __int128)(-kk) : (unsigned __int128)kk; \
    unsigned __int128 g = gcd128_u(uk, dd);                                    \
    __int128 rn = kk / (__int128)g;                                            \
    __int128 rd = (__int128)(dd / g);                                          \
    if (rn != (T)rn || rd != (T)rd) zfy_die("rand: frac 结果溢出 " #SUF);       \
    out->n = (T)rn; out->d = (T)rd; }

DEF_RANDFRAC(i8, int8_t)
DEF_RANDFRAC(i16, int16_t)
DEF_RANDFRAC(i32, int32_t)
DEF_RANDFRAC(i64, int64_t)
DEF_RANDFRAC(u8, uint8_t)
DEF_RANDFRAC(u16, uint16_t)
DEF_RANDFRAC(u32, uint32_t)
DEF_RANDFRAC(u64, uint64_t)

/* ---------- 计时器（timer 系，new.md 第2条） ---------- */

#ifndef ZFY_FREESTANDING
#define ZFY_TIMER_SLOTS 4096
static struct {
    int active;      /* 槽已登记 */
    int running;     /* 正在计时 */
    double base;     /* 已冻结的累计秒数（含 start 起始值） */
    int64_t stamp_q; /* 最近 start 时的 QPC/单调钟读数 */
} g_timers[ZFY_TIMER_SLOTS];

static int64_t qpc_val(void) {
#ifdef _WIN32
    LARGE_INTEGER c;
    QueryPerformanceCounter(&c);
    return c.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000000LL + ts.tv_nsec;
#endif
}

static double qpc_seconds_since(int64_t stamp) {
#ifdef _WIN32
    static double qpf = 0.0;
    if (qpf == 0.0) {
        LARGE_INTEGER f;
        QueryPerformanceFrequency(&f);
        qpf = (double)f.QuadPart;
    }
    return (double)(qpc_val() - stamp) / qpf;
#else
    return (double)(qpc_val() - stamp) / 1e9;
#endif
}

static void timer_check(int64_t x) {
    if (x < 0 || x >= ZFY_TIMER_SLOTS || !g_timers[x].active)
        zfy_die("timer: 该序号的计时线程不存在（0..4095，须先 timer.add）");
}

void zfy_timer_add(int64_t x) {
    if (x < 0 || x >= ZFY_TIMER_SLOTS)
        zfy_die("timer.add: 序号越界（0..4095）");
    g_timers[x].active = 1;
    g_timers[x].running = 0;
    g_timers[x].base = 0.0;
    g_timers[x].stamp_q = 0;
}

void zfy_timer_remove(int64_t x) {
    timer_check(x);
    g_timers[x].active = 0;
}

void zfy_timer_start(int64_t n, double x) {
    timer_check(n);
    g_timers[n].base = x;
    g_timers[n].stamp_q = qpc_val();
    g_timers[n].running = 1;
}

void zfy_timer_stop(int64_t n) {
    timer_check(n);
    if (g_timers[n].running) {
        g_timers[n].base += qpc_seconds_since(g_timers[n].stamp_q);
        g_timers[n].running = 0;
    }
}

double zfy_timer_now(int64_t n) {
    timer_check(n);
    return g_timers[n].base
           + (g_timers[n].running ? qpc_seconds_since(g_timers[n].stamp_q) : 0.0);
}

void zfy_time_sleep_f(double sec) {
    if (sec < 0) sec = 0;
#ifdef _WIN32
    Sleep((DWORD)(sec * 1000.0));
#else
    struct timespec req;
    req.tv_sec = (time_t)sec;
    req.tv_nsec = (long)((sec - (double)req.tv_sec) * 1e9);
    while (nanosleep(&req, &req) == -1 && errno == EINTR) { /* 重试剩余部分 */ }
#endif
}
#endif /* !ZFY_FREESTANDING：计时器段结束（依赖 QPC/单调钟/sleep） */

/* ==================== GUI 核心层（v3.3.7 design_gui.md L0） ====================
 * 渲染引擎（完全替换 GDI DIB → Direct2D + DirectWrite + WIC）：
 *  - 每窗口一套 ID2D1DeviceContext + DXGI 交换链（Flip 模型，双缓冲），
 *    后端 D3D11 设备（硬件优先，失败自动退回 WARP 软件光栅，远程会话可用）
 *  - 抗锯齿：几何 PER_PRIMITIVE，文本 GRAYSCALE（中文/英文均平滑，无 GDI 调色板抖动）
 *  - 颜色约定：zfy 侧统一 0xAARRGGBB；仅给 0xRRGGBB（高字节为 0 且 RGB 非 0）时
 *    alpha 缺省为 0xFF（向后兼容旧组件配色）
 *  - 全局乘性透明度：gui_set_alpha(a) 把后续所有绘制的 alpha 再乘 a/255
 *  - 混合模式：0=SourceOver（D2D 默认）1=Additive（D2D 原生加法混合）
 *    2=Multiply 3=Screen 4=Xor 走"源位图 + 目标回读 + CPU 逐像素合成 + 上传"路径
 *    （Xor 按 abs(dst-src) 逐通道实现，等同差异混合）
 *  - DPI 语义不变：open 的 w/h 为逻辑尺寸，按 dpi/96 放大为物理像素；渲染目标
 *    SetDpi(96) 使 1 DIP = 1 物理像素，字体 px 逻辑 → 物理 = px * dpi / 96，
 *    故 widgets 的 SC() 缩放逻辑无需修改
 *  - 事件：环形队列（WndProc 生产、poll 消费），轮询模型 O(1)
 *  - 单线程模型：poll() 顺带泵消息，用户每帧至少 poll 一次；每帧画完 present() 一次
 *  - 缓存策略：
 *      · IDWriteTextFormat：全局 64 槽 LRU，键 = (字体族, 物理字号, 字重, 斜体)
 *      · 纯色画刷：每窗口 64 槽 LRU，键 = 有效 ARGB（已乘全局 alpha）
 *      · 位图：全局 64 槽句柄表（句柄 = 槽位 + 1，0 表示非法）
 *      · 混合合成的临时位图/缓冲区：每窗口单例，按需增长
 *  - 可调窗口：WM_SIZE 时 ResizeBuffers + 重建目标位图并推 EV_SIZE 事件 */
#if defined(_WIN32) && !defined(ZFY_FREESTANDING)
#include <wchar.h>                     /* wcslen（GUI 文本转换） */
#include <d2d1_1.h>
#include <d3d11.h>
#include <dxgi1_3.h>
#include <dwrite.h>
#include <wincodec.h>
/* UI Automation Provider：仅用头文件里的接口 vtable/常量，运行期动态加载
   UIAutomationCore.dll 的函数（避免链接期依赖）。oleauto 提供 VARIANT/
   BSTR/SAFEARRAY（SysAllocString/SafeArrayCreate 走 oleaut32）。 */
#include <uiautomation.h>
#include <oleauto.h>

/* mingw 的 IDWriteFactory IID 未进导入库，本地定义一份 */
static const GUID gui_iid_dwrite = { 0xb859ee5a, 0xd838, 0x4b5b,
                                     { 0xa2, 0xe8, 0x1a, 0xdc, 0x7d, 0x93, 0xdb, 0x48 } };

typedef struct { int64_t t, x, y, k; } gui_ev;
#define GUI_EVQ 256

/* 事件类型常量（与 stdlib/gui.zfy 保持一致） */
#define GUI_EV_MOVE  1
#define GUI_EV_LDOWN 2
#define GUI_EV_LUP   3
#define GUI_EV_RDOWN 4
#define GUI_EV_RUP   5
#define GUI_EV_KEY   6
#define GUI_EV_WHEEL 7
#define GUI_EV_SIZE  8

/* EV_KEY 的 k 值分区（避免与 WM_CHAR 码元 <0x110000 冲突）：
 *   GUI_KEY_EXT  | VK   —— 方向键/Delete/Home/End 等（WM_KEYDOWN）
 *   GUI_KEY_SHIFT| EXT|VK —— Shift+导航（扩选用）
 *   GUI_KEY_CTRL | 'C'  —— Ctrl 组合键（VK 大写字母） */
#define GUI_KEY_EXT  0x10000000
#define GUI_KEY_CTRL 0x20000000
#define GUI_KEY_SHIFT 0x40000000

/* 多窗口（v3.4）：窗口状态集中管理，WndProc 经 GWLP_USERDATA 找回窗口。
 * 绘制类 API 作用于"当前窗口" g_cur（gui_select 切换）；gui_open 保持
 * 返回 0=成功 的兼容语义，句柄经 zfy_gui_self() 取。 */
#define GUI_MAXWIN 8
#define GUI_TF_SLOTS 64
#define GUI_BR_SLOTS 64
#define GUI_IMG_SLOTS 64
#define GUI_XF_STACK 16
#define GUI_CLIP_STACK 16

/* ---------- D2D 调用宏（mingw 的 d2d1 vtbl 有继承嵌套，路径逐层写死） ---------- */
#define RT(c)            ((ID2D1RenderTarget *)(c))
#define RT_V(c, fn, ...) (RT(c)->lpVtbl->fn(RT(c), ##__VA_ARGS__))
#define DC_V(c, fn, ...) ((c)->lpVtbl->fn(c, ##__VA_ARGS__))
#define FACT(f, fn, ...) ((f)->lpVtbl->Base.fn((ID2D1Factory *)(f), ##__VA_ARGS__))
#define FACT1(f, fn, ...) ((f)->lpVtbl->fn((ID2D1Factory1 *)(f), ##__VA_ARGS__))
#define GEO(g, fn, ...)  (((ID2D1Geometry *)(g))->lpVtbl->fn((ID2D1Geometry *)(g), ##__VA_ARGS__))
#define PG(g, fn, ...)   ((g)->lpVtbl->fn((ID2D1PathGeometry *)(g), ##__VA_ARGS__))
#define SINK(s, fn, ...) ((s)->lpVtbl->Base.fn((ID2D1SimplifiedGeometrySink *)(s), ##__VA_ARGS__))
#define SINK2(s, fn, ...) ((s)->lpVtbl->fn((ID2D1GeometrySink *)(s), ##__VA_ARGS__))
#define SINK_CLOSE(s)    ((s)->lpVtbl->Base.Close((ID2D1SimplifiedGeometrySink *)(s)))
#define SB_SETCOLOR(b, c) ((b)->lpVtbl->SetColor((ID2D1SolidColorBrush *)(b), c))
#define BR_SETOPACITY(b, o) ((b)->lpVtbl->Base.SetOpacity((ID2D1Brush *)(b), o))
#define BM_V(b, fn, ...) ((b)->lpVtbl->Base.fn((ID2D1Bitmap *)(b), ##__VA_ARGS__))
#define BM1_V(b, fn, ...) ((b)->lpVtbl->fn((ID2D1Bitmap1 *)(b), ##__VA_ARGS__))
#define REL(o) do { if (o) { ((IUnknown *)(void *)(o))->lpVtbl->Release((IUnknown *)(void *)(o)); } } while (0)

typedef struct {
    uint32_t argb;
    ID2D1SolidColorBrush *br;
    unsigned stamp;
    int used;
} gui_br_slot;

typedef struct {
    ID2D1Bitmap1 *bmp;
    int w, h;
    int used;
} gui_img;

typedef struct {
    char family[64];
    float size;
    int weight, italic;
    int rtl;                       /* 创建时的阅读方向（缓存键的一部分） */
    IDWriteTextFormat *fmt;
    unsigned stamp;
    int used;
} gui_tf_slot;

typedef struct {
    int used;
    HWND hwnd;
    /* D2D/DXGI 渲染资源 */
    IDXGISwapChain1 *swap;
    ID2D1DeviceContext *ctx;
    ID2D1Bitmap1 *target;
    int w, h, dpi;
    /* 当前默认文本样式（DirectWrite） */
    char tf_family[64];
    int tf_px, tf_weight, tf_italic;
    /* 透明度 / 混合模式 */
    int alpha;                            /* 全局乘性 alpha 0..255 */
    int blend;                            /* 0..4（见 GUI_BLEND_*） */
    int rtl;                              /* 0=LTR 1=RTL（DirectWrite 阅读方向） */
    /* 纯色画刷缓存（每窗口） */
    gui_br_slot br[GUI_BR_SLOTS];
    unsigned br_tick;
    /* 混合模式合成用临时资源 */
    ID2D1Bitmap1 *scr_src;                /* 源：图元画在透明底上 */
    ID2D1Bitmap1 *scr_dst;                /* 目的快照（CPU 可读） */
    ID2D1Bitmap1 *scr_up;                 /* 合成结果上传位图 */
    unsigned char *scr_buf;               /* CPU 合成缓冲区 */
    int scr_w, scr_h;
    /* 变换 / 裁剪栈 */
    D2D1_MATRIX_3X2_F xf[GUI_XF_STACK];
    int xf_n;
    int clip_n;
    volatile int alive, should_close;
    gui_ev q[GUI_EVQ];
    volatile long qh, qt;
} gui_win;
static gui_win g_wins[GUI_MAXWIN];
static gui_win *g_cur = NULL;

/* 全局单例（COM 与设备级对象） */
static ID2D1Factory1 *g_d2d_fct = NULL;
static IDWriteFactory *g_dw = NULL;
static IWICImagingFactory *g_wic = NULL;
static ID2D1Device *g_d2d_dev = NULL;
static ID3D11Device *g_d3d = NULL;
static IDXGIFactory2 *g_dxgi = NULL;
static ID2D1StrokeStyle *g_stroke_flat = NULL;
static int g_com_ready = 0;
static gui_tf_slot g_tf[GUI_TF_SLOTS];
static unsigned g_tf_tick = 0;
static gui_img g_imgs[GUI_IMG_SLOTS];

/* 混合模式取值（与 stdlib/gui.zfy 的 BLEND_* 一致） */
#define GUI_BLEND_SRCOVER  0
#define GUI_BLEND_ADD      1
#define GUI_BLEND_MULTIPLY 2
#define GUI_BLEND_SCREEN   3
#define GUI_BLEND_XOR      4

static void gui_push_ev(gui_win *w, int64_t t, int64_t x, int64_t y, int64_t k) {
    /* MOVE 合并：队列尾已有未消费的 MOVE 时直接覆盖坐标（只保留最新位置）。
       鼠标快速移动会产生事件洪流——旧实现队列满后"丢弃新事件"会把夹在
       MOVE 洪流中的 DOWN/UP/KEY 一并丢掉（表现为点击无效、组件"点了没
       反应、点几下才显示"，w-052）。合并 MOVE 后 DOWN/UP 永不被挤掉。 */
    if (t == GUI_EV_MOVE && w->qt != w->qh) {
        long prv = (w->qt + GUI_EVQ - 1) % GUI_EVQ;
        if (w->q[prv].t == GUI_EV_MOVE) {
            w->q[prv].x = x;
            w->q[prv].y = y;
            return;
        }
    }
    long nxt = (w->qt + 1) % GUI_EVQ;
    if (nxt == w->qh) {
        /* 队列满：新事件若非 MOVE，挤掉队头 MOVE 腾位（保 DOWN/UP/KEY）；
           新事件本身是 MOVE 则直接丢弃 */
        if (t == GUI_EV_MOVE) return;
        if (w->q[w->qh].t == GUI_EV_MOVE) {
            w->qh = (w->qh + 1) % GUI_EVQ;
            nxt = (w->qt + 1) % GUI_EVQ;
        } else return;
    }
    w->q[w->qt].t = t; w->q[w->qt].x = x;
    w->q[w->qt].y = y; w->q[w->qt].k = k;
    w->qt = nxt;
}

/* ==================================================================
 * UI Automation Provider（无障碍，v3.33）
 *
 * 结构：zfy 侧每帧提交一棵"无障碍节点表"（begin → push_node* → end），
 * C 侧据此实现 COM 形态的 UIA Provider，供 Narrator / Inspect.exe 等
 * UIA 客户端读取与操作。
 *
 * 线程模型：
 *   - 节点表由 CRITICAL_SECTION 保护；UIA 客户端在 RPC 线程上回调 Provider
 *     方法，因此所有读取都先加锁拷贝再使用；
 *   - UIA 动作（Invoke / SetValue / SetFocus）绝不直接改绘制状态：先写入
 *     每窗口"待投递"槽，再 PostMessage 回窗口线程（WM_APP+401..403），
 *     wndproc 把动作翻译成既有事件队列里的 EV_A11Y_*，zfy 在 gui_poll
 *     里取到后走既有组件路径——不在 UIA 线程碰任何 UI 状态；
 *   - 事件仅在 UiaClientsAreListening() 为真时发送（无人监听时零开销）。
 *
 * 链接：UIAutomationCore 的导出与 IID 都走 LoadLibrary/GetProcAddress 与
 * 本地标准常量（不依赖导入库，缺库时自动退化为"无障碍静默禁用"）。
 * ================================================================== */

#define A11Y_MAX_NODES 256
#define A11Y_NAME_MAX  128
#define A11Y_ROLE_MAX  24
#define A11Y_VAL_MAX   256

/* 事件类型（与 stdlib/gui.zfy 的 EV_A11Y_* 一致） */
#define GUI_EV_A11Y_INVOKE 9      /* x = 节点下标（上一帧），y = 组件 id */
#define GUI_EV_A11Y_VALUE  10     /* x = 节点下标，key = 数值（edit 文本走 take_value）*/
#define GUI_EV_A11Y_FOCUS  11     /* x = 节点下标（UIA SetFocus 请求） */

/* UIA 线程 → UI 线程的投递消息（lParam 复用为数值/标志） */
#define GUI_WM_A11Y_INVOKE (WM_APP + 401)
#define GUI_WM_A11Y_VALUE  (WM_APP + 402)
#define GUI_WM_A11Y_FOCUS  (WM_APP + 403)

/* 节点状态位（与 zfy 侧 A11Y_* 的映射在 a11y_states_to_c） */
#define A11Y_ST_DISABLED 1
#define A11Y_ST_FOCUSED  2
#define A11Y_ST_CHECKED  4
#define A11Y_ST_EXPANDED 8
#define A11Y_ST_SELECTED 16
#define A11Y_ST_READONLY 32
#define A11Y_ST_PASSWORD 64

/* Pattern 支持位（按 role 决定 GetPatternProvider 返回值） */
#define A11Y_P_INVOKE    0x01
#define A11Y_P_TOGGLE    0x02
#define A11Y_P_RANGE     0x04
#define A11Y_P_SELECTION 0x08
#define A11Y_P_SELITEM   0x10
#define A11Y_P_VALUE     0x20
#define A11Y_P_EXPAND    0x40
#define A11Y_P_TEXT      0x80

typedef struct {
    int used;
    char name[A11Y_NAME_MAX];      /* UTF-8（由 zfy 提供） */
    char role[A11Y_ROLE_MAX];      /* UTF-8：button/checkbox/... */
    char value[A11Y_VAL_MAX];      /* UTF-8 */
    int states;                    /* A11Y_ST_* 位集 */
    int x, y, w, h;                /* 客户区物理像素（提交时换算成屏幕坐标） */
    int parent;                    /* 父节点下标；-1 = 窗口根元素 */
    int id;                        /* zfy 侧组件 id（回投解析用） */
} a11y_node;

typedef struct {
    a11y_node stage[A11Y_MAX_NODES];   /* 正在构建的帧 */
    int stage_n;
    a11y_node cur[A11Y_MAX_NODES];     /* 已提交的帧（UIA 客户端读这个） */
    int cur_n;
    int stage_focus;                   /* 本帧焦点节点 */
    int focus;                         /* 已提交焦点 */
    int focus_last;                    /* 已发送焦点事件的节点 */
    int pend_idx;                      /* 待投递动作的节点下标 */
    int pend_num;                      /* 待投递数值（RangeValue.SetValue） */
    char pend_str[A11Y_VAL_MAX];       /* 待投递文本（IValueProvider.SetValue） */
    int deliv_idx;                     /* 已投递到 UI 线程的文本节点下标 */
    char deliv_str[A11Y_VAL_MAX];
    int deliv_ok;
} a11y_tab;

static a11y_tab g_a11y[GUI_MAXWIN];
static INIT_ONCE g_a11y_once = INIT_ONCE_STATIC_INIT;
static CRITICAL_SECTION g_a11y_cs;

static BOOL CALLBACK a11y_once_cb(PINIT_ONCE o, PVOID p, PVOID *c) {
    (void)o; (void)p; (void)c;
    InitializeCriticalSection(&g_a11y_cs);
    return TRUE;
}
static void a11y_lock(void) {
    InitOnceExecuteOnce(&g_a11y_once, a11y_once_cb, NULL, NULL);
    EnterCriticalSection(&g_a11y_cs);
}
static void a11y_unlock(void) { LeaveCriticalSection(&g_a11y_cs); }

/* ---------- UIAutomationCore 动态加载（缺库 = 无障碍静默禁用） ---------- */
static int g_uia_state = 0;        /* 0=未尝试 1=可用 -1=不可用 */
static HMODULE g_uia_dll = NULL;
static LRESULT (WINAPI *g_uia_raw_provider)(HWND, WPARAM, LPARAM, IRawElementProviderSimple *);
static HRESULT (WINAPI *g_uia_host_from_hwnd)(HWND, IRawElementProviderSimple **);
static WINBOOL (WINAPI *g_uia_listening)(void);
static HRESULT (WINAPI *g_uia_raise_event)(IRawElementProviderSimple *, EVENTID);
static HRESULT (WINAPI *g_uia_raise_prop)(IRawElementProviderSimple *, PROPERTYID, VARIANT, VARIANT);
static HRESULT (WINAPI *g_uia_raise_struct)(IRawElementProviderSimple *, enum StructureChangeType,
                                            int *, int);

static void a11y_uia_load(void) {
    if (g_uia_state != 0) return;
    g_uia_dll = LoadLibraryW(L"UIAutomationCore.dll");
    if (!g_uia_dll) { g_uia_state = -1; return; }
    g_uia_raw_provider = (LRESULT (WINAPI *)(HWND, WPARAM, LPARAM, IRawElementProviderSimple *))
        (void *)GetProcAddress(g_uia_dll, "UiaReturnRawElementProvider");
    g_uia_host_from_hwnd = (HRESULT (WINAPI *)(HWND, IRawElementProviderSimple **))
        (void *)GetProcAddress(g_uia_dll, "UiaHostProviderFromHwnd");
    g_uia_listening = (WINBOOL (WINAPI *)(void))
        (void *)GetProcAddress(g_uia_dll, "UiaClientsAreListening");
    g_uia_raise_event = (HRESULT (WINAPI *)(IRawElementProviderSimple *, EVENTID))
        (void *)GetProcAddress(g_uia_dll, "UiaRaiseAutomationEvent");
    g_uia_raise_prop = (HRESULT (WINAPI *)(IRawElementProviderSimple *, PROPERTYID, VARIANT, VARIANT))
        (void *)GetProcAddress(g_uia_dll, "UiaRaiseAutomationPropertyChangedEvent");
    g_uia_raise_struct = (HRESULT (WINAPI *)(IRawElementProviderSimple *, enum StructureChangeType, int *, int))
        (void *)GetProcAddress(g_uia_dll, "UiaRaiseStructureChangedEvent");
    g_uia_state = (g_uia_raw_provider && g_uia_host_from_hwnd && g_uia_listening
                   && g_uia_raise_event && g_uia_raise_prop && g_uia_raise_struct) ? 1 : -1;
}

static int a11y_listening(void) {
    a11y_uia_load();
    if (g_uia_state != 1) return 0;
    return g_uia_listening() ? 1 : 0;
}

/* ---------- 接口 IID（本地常量，不依赖导入库） ---------- */
static const GUID a11y_iid_unknown = { 0x00000000, 0x0000, 0x0000,
                                      { 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 } };
static const GUID a11y_iid_simple = { 0xd6dd68d1, 0x86fd, 0x4332,
                                      { 0x86, 0x66, 0x9a, 0xbe, 0xde, 0xa2, 0xd2, 0x4c } };
static const GUID a11y_iid_frag = { 0xf7063da8, 0x8359, 0x439c,
                                    { 0x92, 0x97, 0xbb, 0xc5, 0x29, 0x9a, 0x7d, 0x87 } };
static const GUID a11y_iid_root = { 0x620ce2a5, 0xab8f, 0x40a9,
                                    { 0x86, 0xcb, 0xde, 0x3c, 0x75, 0x59, 0x9b, 0x58 } };
static const GUID a11y_iid_invoke = { 0x54fcb24b, 0xe18e, 0x47a2,
                                      { 0xb4, 0xd3, 0xec, 0xcb, 0xe7, 0x75, 0x99, 0xa2 } };
static const GUID a11y_iid_toggle = { 0x56d00bd0, 0xc4f4, 0x433c,
                                      { 0xa8, 0x36, 0x1a, 0x52, 0xa5, 0x7e, 0x08, 0x92 } };
static const GUID a11y_iid_range = { 0x36dc7aef, 0x33e6, 0x4691,
                                     { 0xaf, 0xe1, 0x2b, 0xe7, 0x27, 0x4b, 0x3d, 0x33 } };
static const GUID a11y_iid_sel = { 0xfb8b03af, 0x3bdf, 0x48d4,
                                   { 0xbd, 0x36, 0x1a, 0x65, 0x79, 0x3b, 0xe1, 0x68 } };
static const GUID a11y_iid_selitem = { 0x2acad808, 0xb2d4, 0x452d,
                                       { 0xa4, 0x07, 0x91, 0xff, 0x1a, 0xd1, 0x67, 0xb2 } };
static const GUID a11y_iid_value = { 0xc7935180, 0x6fb3, 0x4201,
                                     { 0xb1, 0x74, 0x7d, 0xf7, 0x3a, 0xdb, 0xf6, 0x4a } };
static const GUID a11y_iid_expand = { 0xd847d3a5, 0xcab0, 0x4a98,
                                      { 0x8c, 0x32, 0xec, 0xb4, 0x5c, 0x59, 0xad, 0x24 } };
static const GUID a11y_iid_text = { 0x3589c92c, 0x63f3, 0x4367,
                                    { 0x99, 0xbb, 0xad, 0xa6, 0x53, 0xb7, 0x7c, 0xf2 } };
static const GUID a11y_iid_textrange = { 0x5347ad7b, 0xc355, 0x46f8,
                                         { 0xaf, 0xf5, 0x90, 0x90, 0x33, 0x58, 0x2f, 0x63 } };

/* ---------- 元素对象（静态池：下标即节点下标，永不复用释放） ---------- */
typedef struct { const void *lpVtbl; void *e; } a11y_face;

typedef struct a11y_elem {
    a11y_face simple, frag, root, invoke, toggle, range, sel, selitem, val, expand, text;
    int win;
    int node;              /* -1 = 窗口根元素 */
    LONG refs;
    int ready;
} a11y_elem;

typedef struct a11y_trange {
    a11y_face face;
    a11y_elem *owner;      /* 所属文本元素（win/node 复用 owner） */
    int start, end;        /* 文本字节区间 */
    int ready;
} a11y_trange;

static a11y_elem g_a11y_elems[GUI_MAXWIN][A11Y_MAX_NODES + 1];
static a11y_trange g_a11y_ranges[GUI_MAXWIN][A11Y_MAX_NODES + 1];

/* vtable 前置声明（定义在方法实现之后） */
static const IRawElementProviderSimpleVtbl a11y_vt_simple;
static const IRawElementProviderFragmentVtbl a11y_vt_frag;
static const IRawElementProviderFragmentRootVtbl a11y_vt_root;
static const IInvokeProviderVtbl a11y_vt_invoke;
static const IToggleProviderVtbl a11y_vt_toggle;
static const IRangeValueProviderVtbl a11y_vt_range;
static const ISelectionProviderVtbl a11y_vt_sel;
static const ISelectionItemProviderVtbl a11y_vt_selitem;
static const IValueProviderVtbl a11y_vt_val;
static const IExpandCollapseProviderVtbl a11y_vt_expand;
static const ITextProviderVtbl a11y_vt_text;
static const ITextRangeProviderVtbl a11y_vt_textrange;

/* ---------- 节点表辅助 ---------- */

static wchar_t *gui_utf8_to_wide(const char *s);   /* 定义在 wndproc 之后 */

/* win 参数：1..GUI_MAXWIN（与 zfy 的 gui_self() 一致）；0/-1 = 当前窗口 */
static int a11y_win_idx(int64_t win) {
    int i = -1;
    if (win >= 1 && win <= GUI_MAXWIN && g_wins[win - 1].used) i = (int)(win - 1);
    else if (win >= 0 && win < GUI_MAXWIN && g_wins[win].used) i = (int)win;
    else if (g_cur) {
        for (int k = 0; k < GUI_MAXWIN; k++)
            if (g_cur == &g_wins[k]) { i = k; break; }
    }
    return i;
}

/* 锁内拷贝节点（UIA 线程读）；返回 1=存在 */
static int a11y_node_copy(int win, int node, a11y_node *out) {
    int ok = 0;
    if (win < 0 || win >= GUI_MAXWIN || node < 0) return 0;
    a11y_lock();
    if (node < g_a11y[win].cur_n && g_a11y[win].cur[node].used) {
        *out = g_a11y[win].cur[node];
        ok = 1;
    }
    a11y_unlock();
    return ok;
}

/* 节点包围盒（屏幕物理坐标；客户端坐标 + 窗口原点） */
static void a11y_screen_rect(int win, const a11y_node *nd, struct UiaRect *r) {
    double left = nd->x, top = nd->y;
    HWND hw = (win >= 0 && win < GUI_MAXWIN) ? g_wins[win].hwnd : NULL;
    if (hw) {
        POINT p;
        p.x = nd->x; p.y = nd->y;
        if (ClientToScreen(hw, &p)) { left = p.x; top = p.y; }
    }
    r->left = left;
    r->top = top;
    r->width = nd->w > 0 ? nd->w : 0;
    r->height = nd->h > 0 ? nd->h : 0;
}

/* role → UIA ControlType */
static int a11y_control_type(const char *role) {
    if (!strcmp(role, "button"))   return UIA_ButtonControlTypeId;
    if (!strcmp(role, "checkbox")) return UIA_CheckBoxControlTypeId;
    if (!strcmp(role, "radio"))    return UIA_RadioButtonControlTypeId;
    if (!strcmp(role, "slider"))   return UIA_SliderControlTypeId;
    if (!strcmp(role, "edit"))     return UIA_EditControlTypeId;
    if (!strcmp(role, "list"))     return UIA_ListControlTypeId;
    if (!strcmp(role, "table"))    return UIA_TableControlTypeId;
    if (!strcmp(role, "tab"))      return UIA_TabControlTypeId;
    if (!strcmp(role, "group"))    return UIA_GroupControlTypeId;
    if (!strcmp(role, "image"))    return UIA_ImageControlTypeId;
    if (!strcmp(role, "text"))     return UIA_TextControlTypeId;
    if (!strcmp(role, "progress")) return UIA_ProgressBarControlTypeId;
    if (!strcmp(role, "window"))   return UIA_WindowControlTypeId;
    return UIA_PaneControlTypeId;
}

/* role → 支持的 Pattern 位集 */
static int a11y_patterns(const char *role) {
    if (!strcmp(role, "button"))   return A11Y_P_INVOKE;
    if (!strcmp(role, "checkbox")) return A11Y_P_INVOKE | A11Y_P_TOGGLE;
    if (!strcmp(role, "radio"))    return A11Y_P_SELITEM | A11Y_P_TOGGLE;
    if (!strcmp(role, "slider"))   return A11Y_P_RANGE;
    if (!strcmp(role, "progress")) return A11Y_P_RANGE;
    if (!strcmp(role, "edit"))     return A11Y_P_VALUE | A11Y_P_TEXT;
    if (!strcmp(role, "list"))     return A11Y_P_SELECTION;
    if (!strcmp(role, "table"))    return A11Y_P_SELECTION;
    if (!strcmp(role, "tab"))      return A11Y_P_SELECTION;
    if (!strcmp(role, "tree"))     return A11Y_P_EXPAND;
    return 0;
}

/* pattern id → Pattern 位 */
static int a11y_pattern_bit(PATTERNID id) {
    switch (id) {
    case UIA_InvokePatternId:        return A11Y_P_INVOKE;
    case UIA_TogglePatternId:        return A11Y_P_TOGGLE;
    case UIA_RangeValuePatternId:    return A11Y_P_RANGE;
    case UIA_SelectionPatternId:     return A11Y_P_SELECTION;
    case UIA_SelectionItemPatternId: return A11Y_P_SELITEM;
    case UIA_ValuePatternId:         return A11Y_P_VALUE;
    case UIA_ExpandCollapsePatternId:return A11Y_P_EXPAND;
    case UIA_TextPatternId:          return A11Y_P_TEXT;
    default: return 0;
    }
}

/* 元素取用（懒初始化 face 表；窗口槽位由调用方保证有效） */
static a11y_elem *a11y_elem_get(int win, int node) {
    a11y_elem *e;
    if (win < 0 || win >= GUI_MAXWIN) return NULL;
    if (node < 0) node = -1;
    if (node >= A11Y_MAX_NODES) return NULL;
    e = &g_a11y_elems[win][node + 1];
    if (!e->ready) {
        e->win = win;
        e->node = node;
        e->refs = 1;
        e->simple.lpVtbl = (const void *)&a11y_vt_simple;
        e->simple.e = e;
        e->frag.lpVtbl = (const void *)&a11y_vt_frag;
        e->frag.e = e;
        e->root.lpVtbl = (const void *)&a11y_vt_root;
        e->root.e = e;
        e->invoke.lpVtbl = (const void *)&a11y_vt_invoke;
        e->invoke.e = e;
        e->toggle.lpVtbl = (const void *)&a11y_vt_toggle;
        e->toggle.e = e;
        e->range.lpVtbl = (const void *)&a11y_vt_range;
        e->range.e = e;
        e->sel.lpVtbl = (const void *)&a11y_vt_sel;
        e->sel.e = e;
        e->selitem.lpVtbl = (const void *)&a11y_vt_selitem;
        e->selitem.e = e;
        e->val.lpVtbl = (const void *)&a11y_vt_val;
        e->val.e = e;
        e->expand.lpVtbl = (const void *)&a11y_vt_expand;
        e->expand.e = e;
        e->text.lpVtbl = (const void *)&a11y_vt_text;
        e->text.e = e;
        e->ready = 1;
    }
    return e;
}

static a11y_elem *a11y_elem_of(const void *iface) {
    if (!iface) return NULL;
    return (a11y_elem *)((const a11y_face *)iface)->e;
}

/* 有效 role：根元素固定 window；节点读已提交表；节点不存在时当 pane */
static void a11y_role_of(int win, int node, char *out, int cap) {
    a11y_node nd;
    out[0] = 0;
    if (node < 0) { strncpy(out, "window", (size_t)cap - 1); return; }
    if (a11y_node_copy(win, node, &nd)) {
        strncpy(out, nd.role, (size_t)cap - 1);
        out[cap - 1] = 0;
    } else {
        strncpy(out, "group", (size_t)cap - 1);
    }
}

/* UTF-8 → BSTR（UIA 字符串属性） */
static BSTR a11y_bstr(const char *s) {
    if (!s) s = "";
    wchar_t *w = gui_utf8_to_wide(s);   /* 定义在 GUI 段较早处 */
    BSTR b = SysAllocString(w ? w : L"");
    free(w);
    return b;
}

/* 节点下标 → BSTR（AutomationId） */
static BSTR a11y_bstr_idx(int idx) {
    char buf[24];
    snprintf(buf, sizeof(buf), "zfy-%d", idx);
    return a11y_bstr(buf);
}

/* UIA 线程投递动作到窗口线程（只写"待投递"槽 + PostMessage，不碰 UI） */
static void a11y_post(int win, int node, int kind, int num) {
    HWND hw;
    if (win < 0 || win >= GUI_MAXWIN || node < 0) return;
    hw = g_wins[win].hwnd;
    if (!hw) return;
    if (kind == 2 || kind == 4) {
        a11y_lock();
        g_a11y[win].pend_idx = node;
        g_a11y[win].pend_num = num;
        a11y_unlock();
    }
    switch (kind) {
    case 1: PostMessageW(hw, GUI_WM_A11Y_INVOKE, (WPARAM)node, 0); break;
    /* 数值 +1 入队：EV_A11Y_VALUE 的 key>0 表示数值（key-1），key==0 表示文本走
       take_value 取串——这样滑块设 0 与"设文本"能区分开 */
    case 2: PostMessageW(hw, GUI_WM_A11Y_VALUE, (WPARAM)node, (LPARAM)(num + 1)); break;
    case 3: PostMessageW(hw, GUI_WM_A11Y_FOCUS, (WPARAM)node, 0); break;
    case 4: PostMessageW(hw, GUI_WM_A11Y_VALUE, (WPARAM)node, 0); break;
    default: break;
    }
}

/* IValueProvider.SetValue 的文本：先落待投递串再 Post */
static void a11y_post_value_str(int win, int node, const char *s) {
    if (win < 0 || win >= GUI_MAXWIN || node < 0) return;
    a11y_lock();
    g_a11y[win].pend_idx = node;
    g_a11y[win].pend_str[0] = 0;
    if (s) {
        int n = (int)strlen(s);
        if (n > A11Y_VAL_MAX - 1) n = A11Y_VAL_MAX - 1;
        memcpy(g_a11y[win].pend_str, s, (size_t)n);
        g_a11y[win].pend_str[n] = 0;
    }
    a11y_unlock();
    a11y_post(win, node, 4, 0);
}

/* ---------- IUnknown 三个方法（每个接口一份，签名必须与 SDK vtable 一致） ---------- */
static HRESULT a11y_qi(a11y_elem *e, REFIID riid, void **out);
static ULONG a11y_addref(a11y_elem *e);
static ULONG a11y_release(a11y_elem *e);

#define A11Y_UNKNOWN(IFC, PFX) \
static HRESULT WINAPI PFX##_QueryInterface(IFC *t, REFIID riid, void **o) \
{ return a11y_qi(a11y_elem_of((void *)t), riid, o); } \
static ULONG WINAPI PFX##_AddRef(IFC *t) { return a11y_addref(a11y_elem_of((void *)t)); } \
static ULONG WINAPI PFX##_Release(IFC *t) { return a11y_release(a11y_elem_of((void *)t)); }

A11Y_UNKNOWN(IRawElementProviderSimple, a11y_simple)
A11Y_UNKNOWN(IRawElementProviderFragment, a11y_frag)
A11Y_UNKNOWN(IRawElementProviderFragmentRoot, a11y_root)
A11Y_UNKNOWN(IInvokeProvider, a11y_invoke)
A11Y_UNKNOWN(IToggleProvider, a11y_toggle)
A11Y_UNKNOWN(IRangeValueProvider, a11y_range)
A11Y_UNKNOWN(ISelectionProvider, a11y_sel)
A11Y_UNKNOWN(ISelectionItemProvider, a11y_selitem)
A11Y_UNKNOWN(IValueProvider, a11y_val)
A11Y_UNKNOWN(IExpandCollapseProvider, a11y_expand)
A11Y_UNKNOWN(ITextProvider, a11y_text)
/* 文本区间对象：IUnknown 三方法单独实现（持有 owner 元素的引用） */

/* 引用计数：静态池对象不释放，归零仅表示"客户端不再引用" */
static ULONG a11y_addref(a11y_elem *e) {
    if (!e) return 0;
    return (ULONG)InterlockedIncrement(&e->refs);
}
static ULONG a11y_release(a11y_elem *e) {
    if (!e) return 0;
    LONG n = InterlockedDecrement(&e->refs);
    if (n < 0) { InterlockedExchange(&e->refs, 0); n = 0; }
    return (ULONG)n;
}

/* QueryInterface：按 IID 返回对应的 face（未支持返回 E_NOINTERFACE） */
static HRESULT a11y_qi(a11y_elem *e, REFIID riid, void **out) {
    char role[A11Y_ROLE_MAX];
    int pats;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e || !riid) return E_POINTER;
    if (IsEqualGUID(riid, &a11y_iid_unknown) || IsEqualGUID(riid, &a11y_iid_simple)) {
        *out = (void *)&e->simple;
        return S_OK;
    }
    if (IsEqualGUID(riid, &a11y_iid_frag)) {
        *out = (void *)&e->frag;
        return S_OK;
    }
    if (e->node < 0) {
        if (IsEqualGUID(riid, &a11y_iid_root)) { *out = (void *)&e->root; return S_OK; }
        return E_NOINTERFACE;
    }
    a11y_role_of(e->win, e->node, role, (int)sizeof(role));
    pats = a11y_patterns(role);
    if ((pats & A11Y_P_INVOKE)    && IsEqualGUID(riid, &a11y_iid_invoke))   { *out = (void *)&e->invoke; return S_OK; }
    if ((pats & A11Y_P_TOGGLE)    && IsEqualGUID(riid, &a11y_iid_toggle))   { *out = (void *)&e->toggle; return S_OK; }
    if ((pats & A11Y_P_RANGE)     && IsEqualGUID(riid, &a11y_iid_range))    { *out = (void *)&e->range; return S_OK; }
    if ((pats & A11Y_P_SELECTION) && IsEqualGUID(riid, &a11y_iid_sel))      { *out = (void *)&e->sel; return S_OK; }
    if ((pats & A11Y_P_SELITEM)   && IsEqualGUID(riid, &a11y_iid_selitem))  { *out = (void *)&e->selitem; return S_OK; }
    if ((pats & A11Y_P_VALUE)     && IsEqualGUID(riid, &a11y_iid_value))    { *out = (void *)&e->val; return S_OK; }
    if ((pats & A11Y_P_EXPAND)    && IsEqualGUID(riid, &a11y_iid_expand))   { *out = (void *)&e->expand; return S_OK; }
    if ((pats & A11Y_P_TEXT)      && IsEqualGUID(riid, &a11y_iid_text))     { *out = (void *)&e->text; return S_OK; }
    return E_NOINTERFACE;
}

/* ---------- IRawElementProviderSimple ---------- */
static HRESULT WINAPI a11y_simple_get_ProviderOptions(IRawElementProviderSimple *t, enum ProviderOptions *o) {
    (void)t;
    if (!o) return E_POINTER;
    /* 服务端 Provider + 跨线程（节点表加锁，动作经消息回窗口线程） */
    *o = (enum ProviderOptions)(ProviderOptions_ServerSideProvider | ProviderOptions_UseComThreading);
    return S_OK;
}

static HRESULT WINAPI a11y_simple_GetPatternProvider(IRawElementProviderSimple *t, PATTERNID id, IUnknown **o) {
    a11y_elem *e = a11y_elem_of(t);
    char role[A11Y_ROLE_MAX];
    int pats;
    if (!o) return E_POINTER;
    *o = NULL;
    if (!e || e->node < 0) return S_OK;
    a11y_role_of(e->win, e->node, role, (int)sizeof(role));
    pats = a11y_patterns(role);
    if (pats & a11y_pattern_bit(id)) {
        void *face = NULL;
        if ((pats & A11Y_P_INVOKE) && id == UIA_InvokePatternId) face = &e->invoke;
        else if ((pats & A11Y_P_TOGGLE) && id == UIA_TogglePatternId) face = &e->toggle;
        else if ((pats & A11Y_P_RANGE) && id == UIA_RangeValuePatternId) face = &e->range;
        else if ((pats & A11Y_P_SELECTION) && id == UIA_SelectionPatternId) face = &e->sel;
        else if ((pats & A11Y_P_SELITEM) && id == UIA_SelectionItemPatternId) face = &e->selitem;
        else if ((pats & A11Y_P_VALUE) && id == UIA_ValuePatternId) face = &e->val;
        else if ((pats & A11Y_P_EXPAND) && id == UIA_ExpandCollapsePatternId) face = &e->expand;
        else if ((pats & A11Y_P_TEXT) && id == UIA_TextPatternId) face = &e->text;
        if (face) {
            a11y_addref(e);
            *o = (IUnknown *)face;
        }
    }
    return S_OK;
}

/* 取节点（根元素合成一条 node=-1 的虚拟记录） */
static int a11y_get_node(int win, int node, a11y_node *nd) {
    if (node < 0) {
        HWND hw = (win >= 0 && win < GUI_MAXWIN) ? g_wins[win].hwnd : NULL;
        RECT rc = { 0, 0, 0, 0 };
        memset(nd, 0, sizeof(*nd));
        nd->used = 1;
        nd->parent = -1;
        strncpy(nd->role, "window", sizeof(nd->role) - 1);
        strncpy(nd->name, "zfy", sizeof(nd->name) - 1);
        if (hw) {
            wchar_t wt[160];
            GetClientRect(hw, &rc);
            nd->w = rc.right - rc.left;
            nd->h = rc.bottom - rc.top;
            if (GetWindowTextW(hw, wt, 160) > 0) {
                char *u8 = (char *)malloc(640);
                if (u8) {
                    if (WideCharToMultiByte(CP_UTF8, 0, wt, -1, u8, 640, NULL, NULL) > 0)
                        strncpy(nd->name, u8, sizeof(nd->name) - 1);
                    free(u8);
                }
            }
        }
        return 1;
    }
    return a11y_node_copy(win, node, nd);
}

static void a11y_rect_array(VARIANT *v, const struct UiaRect *r) {
    SAFEARRAY *sa = SafeArrayCreateVector(VT_R8, 0, 4);
    double *pd = NULL;
    if (!sa) return;
    if (SUCCEEDED(SafeArrayAccessData(sa, (void **)&pd))) {
        pd[0] = r->left; pd[1] = r->top;
        pd[2] = r->width; pd[3] = r->height;
        SafeArrayUnaccessData(sa);
    }
    VariantInit(v);
    v->vt = VT_R8 | VT_ARRAY;
    v->parray = sa;
}

/* 可键盘聚焦的角色集合 */
static int a11y_focusable(const char *role) {
    return !strcmp(role, "button") || !strcmp(role, "checkbox") || !strcmp(role, "radio")
        || !strcmp(role, "slider") || !strcmp(role, "edit") || !strcmp(role, "list")
        || !strcmp(role, "table") || !strcmp(role, "tab") || !strcmp(role, "tree");
}

static HRESULT WINAPI a11y_simple_GetPropertyValue(IRawElementProviderSimple *t, PROPERTYID id, VARIANT *v) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    char role[A11Y_ROLE_MAX];
    if (!v) return E_POINTER;
    VariantInit(v);
    if (!e || !a11y_get_node(e->win, e->node, &nd)) return S_OK;
    if (e->node < 0) strncpy(role, "window", sizeof(role) - 1);
    else { strncpy(role, nd.role, sizeof(role) - 1); role[sizeof(role) - 1] = 0; }
    switch (id) {
    case UIA_NamePropertyId:
        v->vt = VT_BSTR; v->bstrVal = a11y_bstr(nd.name); break;
    case UIA_AutomationIdPropertyId:
        v->vt = VT_BSTR; v->bstrVal = a11y_bstr_idx(e->node); break;
    case UIA_ControlTypePropertyId:
        v->vt = VT_I4; v->lVal = a11y_control_type(role); break;
    case UIA_BoundingRectanglePropertyId: {
        struct UiaRect r;
        a11y_screen_rect(e->win, &nd, &r);
        a11y_rect_array(v, &r);
        break;
    }
    case UIA_IsEnabledPropertyId:
        v->vt = VT_BOOL; v->boolVal = (nd.states & A11Y_ST_DISABLED) ? VARIANT_FALSE : VARIANT_TRUE; break;
    case UIA_HasKeyboardFocusPropertyId:
        v->vt = VT_BOOL; v->boolVal = (nd.states & A11Y_ST_FOCUSED) ? VARIANT_TRUE : VARIANT_FALSE; break;
    case UIA_IsKeyboardFocusablePropertyId:
        v->vt = VT_BOOL; v->boolVal = a11y_focusable(role) ? VARIANT_TRUE : VARIANT_FALSE; break;
    case UIA_IsOffscreenPropertyId:
        v->vt = VT_BOOL; v->boolVal = VARIANT_FALSE; break;
    case UIA_HelpTextPropertyId:
        v->vt = VT_BSTR; v->bstrVal = a11y_bstr(nd.value); break;
    case UIA_ItemStatusPropertyId:
        v->vt = VT_BSTR; v->bstrVal = a11y_bstr(nd.value); break;
    case UIA_IsPasswordPropertyId:
        v->vt = VT_BOOL; v->boolVal = (nd.states & A11Y_ST_PASSWORD) ? VARIANT_TRUE : VARIANT_FALSE; break;
    case UIA_ToggleToggleStatePropertyId:
        v->vt = VT_I4;
        v->lVal = (nd.states & A11Y_ST_CHECKED) ? ToggleState_On : ToggleState_Off;
        break;
    case UIA_SelectionItemIsSelectedPropertyId:
        v->vt = VT_BOOL;
        v->boolVal = (nd.states & (A11Y_ST_SELECTED | A11Y_ST_CHECKED)) ? VARIANT_TRUE : VARIANT_FALSE;
        break;
    case UIA_ValueValuePropertyId:
        v->vt = VT_BSTR; v->bstrVal = a11y_bstr(nd.value); break;
    case UIA_ValueIsReadOnlyPropertyId:
        v->vt = VT_BOOL; v->boolVal = (nd.states & A11Y_ST_READONLY) ? VARIANT_TRUE : VARIANT_FALSE; break;
    case UIA_RangeValueValuePropertyId:
        v->vt = VT_R8; v->dblVal = (double)atof(nd.value); break;
    case UIA_RangeValueMinimumPropertyId:
        v->vt = VT_R8; v->dblVal = 0.0; break;
    case UIA_RangeValueMaximumPropertyId:
        v->vt = VT_R8; v->dblVal = 100.0; break;
    case UIA_RangeValueSmallChangePropertyId:
        v->vt = VT_R8; v->dblVal = 1.0; break;
    case UIA_RangeValueLargeChangePropertyId:
        v->vt = VT_R8; v->dblVal = 10.0; break;
    case UIA_RangeValueIsReadOnlyPropertyId:
        v->vt = VT_BOOL;
        v->boolVal = ((nd.states & A11Y_ST_READONLY) || !strcmp(role, "progress"))
                     ? VARIANT_TRUE : VARIANT_FALSE;
        break;
    case UIA_ExpandCollapseExpandCollapseStatePropertyId:
        v->vt = VT_I4;
        v->lVal = (nd.states & A11Y_ST_EXPANDED) ? ExpandCollapseState_Expanded
                                                 : ExpandCollapseState_Collapsed;
        break;
    default:
        break;
    }
    return S_OK;
}

static HRESULT WINAPI a11y_simple_get_HostRawElementProvider(IRawElementProviderSimple *t, IRawElementProviderSimple **o) {
    a11y_elem *e = a11y_elem_of(t);
    if (!o) return E_POINTER;
    *o = NULL;
    /* 仅窗口根元素挂宿主（UIA 用 HWND 的默认 Provider 承担客户端区外部分） */
    if (e && e->node < 0 && e->win >= 0 && e->win < GUI_MAXWIN && g_wins[e->win].hwnd
        && g_uia_state == 1)
        return g_uia_host_from_hwnd(g_wins[e->win].hwnd, o);
    return S_OK;
}

/* ---------- IRawElementProviderFragment / FragmentRoot ---------- */
static HRESULT a11y_ret_frag(int win, int node, IRawElementProviderFragment **out) {
    a11y_elem *e = a11y_elem_get(win, node);
    if (!e) return S_OK;
    a11y_addref(e);
    *out = (IRawElementProviderFragment *)&e->frag;
    return S_OK;
}

/* 同父相邻兄弟（dir>0 找下一个，dir<0 找上一个）；-1=没有 */
static int a11y_sibling(int win, int node, int dir) {
    a11y_node nd;
    int res = -1, i, n;
    if (!a11y_node_copy(win, node, &nd)) return -1;
    a11y_lock();
    n = g_a11y[win].cur_n;
    if (dir > 0) {
        for (i = node + 1; i < n; i++)
            if (g_a11y[win].cur[i].used && g_a11y[win].cur[i].parent == nd.parent) { res = i; break; }
    } else {
        for (i = node - 1; i >= 0; i--)
            if (g_a11y[win].cur[i].used && g_a11y[win].cur[i].parent == nd.parent) { res = i; break; }
    }
    a11y_unlock();
    return res;
}

/* 子节点：parent=-1 时为根元素的孩子；last=1 取最后一个 */
static int a11y_child(int win, int parent, int last) {
    int res = -1, i, n;
    a11y_lock();
    n = g_a11y[win].cur_n;
    if (last) {
        for (i = n - 1; i >= 0; i--)
            if (g_a11y[win].cur[i].used && g_a11y[win].cur[i].parent == parent) { res = i; break; }
    } else {
        for (i = 0; i < n; i++)
            if (g_a11y[win].cur[i].used && g_a11y[win].cur[i].parent == parent) { res = i; break; }
    }
    a11y_unlock();
    return res;
}

static HRESULT WINAPI a11y_frag_Navigate(IRawElementProviderFragment *t, enum NavigateDirection dir,
                                         IRawElementProviderFragment **out) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    int win, node, r;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e) return E_POINTER;
    win = e->win; node = e->node;
    switch (dir) {
    case NavigateDirection_Parent:
        if (node < 0) return S_OK;
        if (!a11y_node_copy(win, node, &nd)) return S_OK;
        r = (nd.parent >= 0) ? nd.parent : -1;
        return a11y_ret_frag(win, r, out);
    case NavigateDirection_NextSibling:
        if (node < 0) return S_OK;
        r = a11y_sibling(win, node, 1);
        if (r >= 0) return a11y_ret_frag(win, r, out);
        return S_OK;
    case NavigateDirection_PreviousSibling:
        if (node < 0) return S_OK;
        r = a11y_sibling(win, node, -1);
        if (r >= 0) return a11y_ret_frag(win, r, out);
        return S_OK;
    case NavigateDirection_FirstChild:
        r = (node < 0) ? a11y_child(win, -1, 0) : a11y_child(win, node, 0);
        if (r >= 0) return a11y_ret_frag(win, r, out);
        return S_OK;
    case NavigateDirection_LastChild:
        r = (node < 0) ? a11y_child(win, -1, 1) : a11y_child(win, node, 1);
        if (r >= 0) return a11y_ret_frag(win, r, out);
        return S_OK;
    default:
        return S_OK;
    }
}

static HRESULT WINAPI a11y_frag_GetRuntimeId(IRawElementProviderFragment *t, SAFEARRAY **out) {
    a11y_elem *e = a11y_elem_of(t);
    SAFEARRAY *sa;
    int *pi = NULL;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e) return E_POINTER;
    sa = SafeArrayCreateVector(VT_I4, 0, 2);
    if (!sa) return E_OUTOFMEMORY;
    if (SUCCEEDED(SafeArrayAccessData(sa, (void **)&pi))) {
        pi[0] = UiaAppendRuntimeId;
        pi[1] = e->node + 1;
        SafeArrayUnaccessData(sa);
    }
    *out = sa;
    return S_OK;
}

static HRESULT WINAPI a11y_frag_get_BoundingRectangle(IRawElementProviderFragment *t, struct UiaRect *r) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!r) return E_POINTER;
    memset(r, 0, sizeof(*r));
    if (!e || !a11y_get_node(e->win, e->node, &nd)) return S_OK;
    a11y_screen_rect(e->win, &nd, r);
    return S_OK;
}

static HRESULT WINAPI a11y_frag_GetEmbeddedFragmentRoots(IRawElementProviderFragment *t, SAFEARRAY **out) {
    (void)t;
    if (!out) return E_POINTER;
    *out = NULL;                       /* 无嵌套 fragment root */
    return S_OK;
}

static HRESULT WINAPI a11y_frag_SetFocus(IRawElementProviderFragment *t) {
    a11y_elem *e = a11y_elem_of(t);
    if (!e || e->node < 0) return S_OK;
    a11y_post(e->win, e->node, 3, 0);
    return S_OK;
}

static HRESULT WINAPI a11y_frag_get_FragmentRoot(IRawElementProviderFragment *t, IRawElementProviderFragmentRoot **out) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_elem *root;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e) return E_POINTER;
    root = a11y_elem_get(e->win, -1);
    if (!root) return S_OK;
    a11y_addref(root);
    *out = (IRawElementProviderFragmentRoot *)&root->root;
    return S_OK;
}

static HRESULT WINAPI a11y_root_ElementProviderFromPoint(IRawElementProviderFragmentRoot *t, double x, double y,
                                                         IRawElementProviderFragment **out) {
    a11y_elem *e = a11y_elem_of(t);
    int win, i, hit = -1;
    POINT p;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e) return E_POINTER;
    win = e->win;
    p.x = (LONG)x; p.y = (LONG)y;
    if (win >= 0 && win < GUI_MAXWIN && g_wins[win].hwnd)
        ScreenToClient(g_wins[win].hwnd, &p);
    a11y_lock();
    for (i = g_a11y[win].cur_n - 1; i >= 0; i--) {
        a11y_node *n = &g_a11y[win].cur[i];
        if (!n->used) continue;
        if (p.x >= n->x && p.x < n->x + n->w && p.y >= n->y && p.y < n->y + n->h) { hit = i; break; }
    }
    a11y_unlock();
    return a11y_ret_frag(win, hit, out);
}

static HRESULT WINAPI a11y_root_GetFocus(IRawElementProviderFragmentRoot *t, IRawElementProviderFragment **out) {
    a11y_elem *e = a11y_elem_of(t);
    int win, foc = -1;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e) return E_POINTER;
    win = e->win;
    a11y_lock();
    foc = g_a11y[win].focus;
    a11y_unlock();
    if (foc < 0 || foc >= A11Y_MAX_NODES) return a11y_ret_frag(win, -1, out);
    return a11y_ret_frag(win, foc, out);
}

/* ---------- Pattern：Invoke / Toggle / RangeValue ---------- */
static HRESULT WINAPI a11y_invoke_Invoke(IInvokeProvider *t) {
    a11y_elem *e = a11y_elem_of(t);
    if (!e || e->node < 0) return S_OK;
    a11y_post(e->win, e->node, 1, 0);
    return S_OK;
}

static HRESULT WINAPI a11y_toggle_Toggle(IToggleProvider *t) {
    a11y_elem *e = a11y_elem_of(t);
    if (!e || e->node < 0) return S_OK;
    a11y_post(e->win, e->node, 1, 0);      /* 与 Invoke 同一回投通道（zfy 侧翻转） */
    return S_OK;
}

static HRESULT WINAPI a11y_toggle_get_ToggleState(IToggleProvider *t, enum ToggleState *st) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!st) return E_POINTER;
    *st = ToggleState_Off;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    *st = (nd.states & A11Y_ST_CHECKED) ? ToggleState_On : ToggleState_Off;
    return S_OK;
}

static HRESULT WINAPI a11y_range_SetValue(IRangeValueProvider *t, double val) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    int v;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    if ((nd.states & A11Y_ST_READONLY) || !strcmp(nd.role, "progress")) return S_OK;
    v = (int)val;
    if (v < 0) v = 0;
    if (v > 100) v = 100;
    a11y_post(e->win, e->node, 2, v);
    return S_OK;
}

static HRESULT WINAPI a11y_range_get_Value(IRangeValueProvider *t, double *v) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!v) return E_POINTER;
    *v = 0.0;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    *v = atof(nd.value);
    return S_OK;
}

static HRESULT WINAPI a11y_range_get_IsReadOnly(IRangeValueProvider *t, WINBOOL *b) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!b) return E_POINTER;
    *b = 0;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    *b = ((nd.states & A11Y_ST_READONLY) || !strcmp(nd.role, "progress")) ? 1 : 0;
    return S_OK;
}

static HRESULT WINAPI a11y_range_get_Maximum(IRangeValueProvider *t, double *v) {
    (void)t;
    if (!v) return E_POINTER;
    *v = 100.0;
    return S_OK;
}

static HRESULT WINAPI a11y_range_get_Minimum(IRangeValueProvider *t, double *v) {
    (void)t;
    if (!v) return E_POINTER;
    *v = 0.0;
    return S_OK;
}

static HRESULT WINAPI a11y_range_get_LargeChange(IRangeValueProvider *t, double *v) {
    (void)t;
    if (!v) return E_POINTER;
    *v = 10.0;
    return S_OK;
}

static HRESULT WINAPI a11y_range_get_SmallChange(IRangeValueProvider *t, double *v) {
    (void)t;
    if (!v) return E_POINTER;
    *v = 1.0;
    return S_OK;
}

/* ---------- Pattern：Selection / SelectionItem / Value / ExpandCollapse ---------- */
static void a11y_empty_array(SAFEARRAY **out, VARTYPE vt) {
    SAFEARRAYBOUND b;
    b.lLbound = 0;
    b.cElements = 0;
    *out = SafeArrayCreate(vt, 1, &b);
}

static HRESULT WINAPI a11y_sel_GetSelection(ISelectionProvider *t, SAFEARRAY **out) {
    (void)t;
    if (!out) return E_POINTER;
    *out = NULL;
    /* 列表/表格的选中项尚未作为独立节点发布，故返回空集（仍合法） */
    a11y_empty_array(out, VT_UNKNOWN);
    return S_OK;
}

static HRESULT WINAPI a11y_sel_get_CanSelectMultiple(ISelectionProvider *t, WINBOOL *b) {
    (void)t;
    if (!b) return E_POINTER;
    *b = 0;
    return S_OK;
}

static HRESULT WINAPI a11y_sel_get_IsSelectionRequired(ISelectionProvider *t, WINBOOL *b) {
    (void)t;
    if (!b) return E_POINTER;
    *b = 0;
    return S_OK;
}

static HRESULT WINAPI a11y_selitem_Select(ISelectionItemProvider *t) {
    a11y_elem *e = a11y_elem_of(t);
    if (!e || e->node < 0) return S_OK;
    a11y_post(e->win, e->node, 1, 0);
    return S_OK;
}

static HRESULT WINAPI a11y_selitem_AddToSelection(ISelectionItemProvider *t) {
    return a11y_selitem_Select(t);
}

static HRESULT WINAPI a11y_selitem_RemoveFromSelection(ISelectionItemProvider *t) {
    (void)t;
    return S_OK;                     /* 单选语义：不支持反选 */
}

static HRESULT WINAPI a11y_selitem_get_IsSelected(ISelectionItemProvider *t, WINBOOL *b) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!b) return E_POINTER;
    *b = 0;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    *b = (nd.states & (A11Y_ST_SELECTED | A11Y_ST_CHECKED)) ? 1 : 0;
    return S_OK;
}

static HRESULT WINAPI a11y_selitem_get_SelectionContainer(ISelectionItemProvider *t, IRawElementProviderSimple **out) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    a11y_elem *c;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    c = a11y_elem_get(e->win, nd.parent >= 0 ? nd.parent : -1);
    if (!c) return S_OK;
    a11y_addref(c);
    *out = (IRawElementProviderSimple *)&c->simple;
    return S_OK;
}

static HRESULT WINAPI a11y_val_SetValue(IValueProvider *t, LPCWSTR val) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    if (nd.states & A11Y_ST_READONLY) return S_OK;
    if (!val) val = L"";
    {
        int n = WideCharToMultiByte(CP_UTF8, 0, val, -1, NULL, 0, NULL, NULL);
        if (n > 0) {
            char *u8 = (char *)malloc((size_t)n);
            if (u8) {
                WideCharToMultiByte(CP_UTF8, 0, val, -1, u8, n, NULL, NULL);
                a11y_post_value_str(e->win, e->node, u8);
                free(u8);
            }
        }
    }
    return S_OK;
}

static HRESULT WINAPI a11y_val_get_Value(IValueProvider *t, BSTR *out) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    *out = a11y_bstr(nd.value);
    return S_OK;
}

static HRESULT WINAPI a11y_val_get_IsReadOnly(IValueProvider *t, WINBOOL *b) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!b) return E_POINTER;
    *b = 0;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    *b = (nd.states & A11Y_ST_READONLY) ? 1 : 0;
    return S_OK;
}

static HRESULT WINAPI a11y_expand_Expand(IExpandCollapseProvider *t) {
    a11y_elem *e = a11y_elem_of(t);
    if (!e || e->node < 0) return S_OK;
    a11y_post(e->win, e->node, 1, 0);      /* zfy 侧按折叠/展开切换语义处理 */
    return S_OK;
}

static HRESULT WINAPI a11y_expand_Collapse(IExpandCollapseProvider *t) {
    return a11y_expand_Expand(t);
}

static HRESULT WINAPI a11y_expand_get_ExpandCollapseState(IExpandCollapseProvider *t, enum ExpandCollapseState *st) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_node nd;
    if (!st) return E_POINTER;
    *st = ExpandCollapseState_Collapsed;
    if (!e || !a11y_node_copy(e->win, e->node, &nd)) return S_OK;
    *st = (nd.states & A11Y_ST_EXPANDED) ? ExpandCollapseState_Expanded : ExpandCollapseState_Collapsed;
    return S_OK;
}

/* ---------- ITextProvider（edit）：文档区间 + 选中区间（简化实现） ---------- */
static a11y_trange *a11y_trange_get(int win, int node);
static HRESULT WINAPI a11y_text_get_DocumentRange(ITextProvider *t, ITextRangeProvider **out);

static HRESULT WINAPI a11y_text_GetSelection(ITextProvider *t, SAFEARRAY **out) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_trange *r;
    SAFEARRAY *sa;
    IUnknown **pp = NULL;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e) return E_POINTER;
    r = a11y_trange_get(e->win, e->node);
    if (!r) return S_OK;
    sa = SafeArrayCreateVector(VT_UNKNOWN, 0, 1);
    if (!sa) return E_OUTOFMEMORY;
    if (SUCCEEDED(SafeArrayAccessData(sa, (void **)&pp))) {
        a11y_addref(r->owner);
        pp[0] = (IUnknown *)&r->face;
        SafeArrayUnaccessData(sa);
    }
    *out = sa;
    return S_OK;
}

static HRESULT WINAPI a11y_text_GetVisibleRanges(ITextProvider *t, SAFEARRAY **out) {
    return a11y_text_GetSelection(t, out);
}

static HRESULT WINAPI a11y_text_RangeFromChild(ITextProvider *t, IRawElementProviderSimple *child, ITextRangeProvider **out) {
    (void)t; (void)child;
    if (!out) return E_POINTER;
    *out = NULL;
    return E_NOTIMPL;
}

static HRESULT WINAPI a11y_text_RangeFromPoint(ITextProvider *t, struct UiaPoint pt, ITextRangeProvider **out) {
    (void)pt;
    return a11y_text_get_DocumentRange(t, out);
}

static HRESULT WINAPI a11y_text_get_DocumentRange(ITextProvider *t, ITextRangeProvider **out) {
    a11y_elem *e = a11y_elem_of(t);
    a11y_trange *r;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!e) return E_POINTER;
    r = a11y_trange_get(e->win, e->node);
    if (!r) return S_OK;
    a11y_addref(r->owner);
    *out = (ITextRangeProvider *)&r->face;
    return S_OK;
}

static HRESULT WINAPI a11y_text_get_SupportedTextSelection(ITextProvider *t, enum SupportedTextSelection *s) {
    (void)t;
    if (!s) return E_POINTER;
    *s = SupportedTextSelection_Single;
    return S_OK;
}

static a11y_trange *a11y_trange_get(int win, int node) {
    a11y_trange *r;
    if (win < 0 || win >= GUI_MAXWIN || node < 0 || node >= A11Y_MAX_NODES) return NULL;
    r = &g_a11y_ranges[win][node + 1];
    if (!r->ready) {
        a11y_elem *e = a11y_elem_get(win, node);
        if (!e) return NULL;
        r->face.lpVtbl = (const void *)&a11y_vt_textrange;
        r->face.e = e;
        r->owner = e;
        r->start = 0;
        r->end = -1;                   /* -1 = 覆盖全文 */
        r->ready = 1;
    }
    return r;
}

static a11y_trange *a11y_trange_of(const void *iface) { return (a11y_trange *)iface; }

static HRESULT WINAPI a11y_trange_QueryInterface(ITextRangeProvider *t, REFIID riid, void **o) {
    if (!o) return E_POINTER;
    *o = NULL;
    if (!t || !riid) return E_POINTER;
    if (IsEqualGUID(riid, &a11y_iid_unknown) || IsEqualGUID(riid, &a11y_iid_textrange)) {
        *o = (void *)t;
        return S_OK;
    }
    return E_NOINTERFACE;
}
static ULONG WINAPI a11y_trange_AddRef(ITextRangeProvider *t) {
    a11y_trange *r = a11y_trange_of(t);
    return r ? a11y_addref(r->owner) : 0;
}
static ULONG WINAPI a11y_trange_Release(ITextRangeProvider *t) {
    a11y_trange *r = a11y_trange_of(t);
    return r ? a11y_release(r->owner) : 0;
}

static HRESULT WINAPI a11y_trange_Clone(ITextRangeProvider *t, ITextRangeProvider **out) {
    a11y_trange *r = a11y_trange_of(t);
    if (!out) return E_POINTER;
    *out = NULL;
    if (!r || !r->owner) return E_POINTER;
    a11y_addref(r->owner);
    *out = (ITextRangeProvider *)&r->face;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_Compare(ITextRangeProvider *t, ITextRangeProvider *range, WINBOOL *b) {
    a11y_trange *r = a11y_trange_of(t);
    a11y_trange *o = a11y_trange_of(range);
    if (!b) return E_POINTER;
    *b = (r && o && r->owner == o->owner) ? 1 : 0;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_CompareEndpoints(ITextRangeProvider *t, enum TextPatternRangeEndpoint ep,
                                                   ITextRangeProvider *range, enum TextPatternRangeEndpoint tep,
                                                   int *v) {
    (void)t; (void)ep; (void)range; (void)tep;
    if (!v) return E_POINTER;
    *v = 0;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_ExpandToEnclosingUnit(ITextRangeProvider *t, enum TextUnit unit) {
    (void)t; (void)unit;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_FindAttribute(ITextRangeProvider *t, TEXTATTRIBUTEID id, VARIANT val,
                                                WINBOOL backward, ITextRangeProvider **out) {
    (void)t; (void)id; (void)val; (void)backward;
    if (!out) return E_POINTER;
    *out = NULL;
    return E_NOTIMPL;
}

static HRESULT WINAPI a11y_trange_FindText(ITextRangeProvider *t, BSTR text, WINBOOL backward,
                                           WINBOOL ignore_case, ITextRangeProvider **out) {
    (void)t; (void)text; (void)backward; (void)ignore_case;
    if (!out) return E_POINTER;
    *out = NULL;
    return E_NOTIMPL;
}

static HRESULT WINAPI a11y_trange_GetAttributeValue(ITextRangeProvider *t, TEXTATTRIBUTEID id, VARIANT *v) {
    (void)t; (void)id;
    if (!v) return E_POINTER;
    VariantInit(v);
    return S_OK;
}

static HRESULT WINAPI a11y_trange_GetBoundingRectangles(ITextRangeProvider *t, SAFEARRAY **out) {
    a11y_trange *r = a11y_trange_of(t);
    struct UiaRect rc;
    a11y_node nd;
    SAFEARRAY *sa;
    double *pd = NULL;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!r || !a11y_get_node(r->owner->win, r->owner->node, &nd)) return S_OK;
    a11y_screen_rect(r->owner->win, &nd, &rc);
    sa = SafeArrayCreateVector(VT_R8, 0, 4);
    if (!sa) return E_OUTOFMEMORY;
    if (SUCCEEDED(SafeArrayAccessData(sa, (void **)&pd))) {
        pd[0] = rc.left; pd[1] = rc.top; pd[2] = rc.width; pd[3] = rc.height;
        SafeArrayUnaccessData(sa);
    }
    *out = sa;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_GetEnclosingElement(ITextRangeProvider *t, IRawElementProviderSimple **out) {
    a11y_trange *r = a11y_trange_of(t);
    if (!out) return E_POINTER;
    *out = NULL;
    if (!r || !r->owner) return E_POINTER;
    a11y_addref(r->owner);
    *out = (IRawElementProviderSimple *)&r->owner->simple;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_GetText(ITextRangeProvider *t, int max_len, BSTR *out) {
    a11y_trange *r = a11y_trange_of(t);
    a11y_node nd;
    char buf[A11Y_VAL_MAX];
    int n;
    if (!out) return E_POINTER;
    *out = NULL;
    if (!r || !a11y_node_copy(r->owner->win, r->owner->node, &nd)) return S_OK;
    strncpy(buf, nd.value, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = 0;
    n = (int)strlen(buf);
    if (max_len > 0 && n > max_len) buf[max_len] = 0;    /* 简化：按字节截断 */
    *out = a11y_bstr(buf);
    return S_OK;
}

static HRESULT WINAPI a11y_trange_Move(ITextRangeProvider *t, enum TextUnit unit, int count, int *v) {
    (void)t; (void)unit; (void)count;
    if (!v) return E_POINTER;
    *v = 0;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_MoveEndpointByUnit(ITextRangeProvider *t, enum TextPatternRangeEndpoint ep,
                                                     enum TextUnit unit, int count, int *v) {
    (void)t; (void)ep; (void)unit; (void)count;
    if (!v) return E_POINTER;
    *v = 0;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_MoveEndpointByRange(ITextRangeProvider *t, enum TextPatternRangeEndpoint ep,
                                                      ITextRangeProvider *range, enum TextPatternRangeEndpoint tep) {
    (void)t; (void)ep; (void)range; (void)tep;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_Select(ITextRangeProvider *t) { (void)t; return S_OK; }
static HRESULT WINAPI a11y_trange_AddToSelection(ITextRangeProvider *t) { (void)t; return S_OK; }
static HRESULT WINAPI a11y_trange_RemoveFromSelection(ITextRangeProvider *t) { (void)t; return S_OK; }

static HRESULT WINAPI a11y_trange_ScrollIntoView(ITextRangeProvider *t, WINBOOL align_top) {
    (void)t; (void)align_top;
    return S_OK;
}

static HRESULT WINAPI a11y_trange_GetChildren(ITextRangeProvider *t, SAFEARRAY **out) {
    (void)t;
    if (!out) return E_POINTER;
    *out = NULL;
    a11y_empty_array(out, VT_UNKNOWN);
    return S_OK;
}

/* ---------- vtable 实例（指定初始化器：字段顺序与 SDK 头完全一致） ---------- */
static const IRawElementProviderSimpleVtbl a11y_vt_simple = {
    .QueryInterface = a11y_simple_QueryInterface,
    .AddRef = a11y_simple_AddRef,
    .Release = a11y_simple_Release,
    .get_ProviderOptions = a11y_simple_get_ProviderOptions,
    .GetPatternProvider = a11y_simple_GetPatternProvider,
    .GetPropertyValue = a11y_simple_GetPropertyValue,
    .get_HostRawElementProvider = a11y_simple_get_HostRawElementProvider
};

static const IRawElementProviderFragmentVtbl a11y_vt_frag = {
    .QueryInterface = a11y_frag_QueryInterface,
    .AddRef = a11y_frag_AddRef,
    .Release = a11y_frag_Release,
    .Navigate = a11y_frag_Navigate,
    .GetRuntimeId = a11y_frag_GetRuntimeId,
    .get_BoundingRectangle = a11y_frag_get_BoundingRectangle,
    .GetEmbeddedFragmentRoots = a11y_frag_GetEmbeddedFragmentRoots,
    .SetFocus = a11y_frag_SetFocus,
    .get_FragmentRoot = a11y_frag_get_FragmentRoot
};

static const IRawElementProviderFragmentRootVtbl a11y_vt_root = {
    .QueryInterface = a11y_root_QueryInterface,
    .AddRef = a11y_root_AddRef,
    .Release = a11y_root_Release,
    .ElementProviderFromPoint = a11y_root_ElementProviderFromPoint,
    .GetFocus = a11y_root_GetFocus
};

static const IInvokeProviderVtbl a11y_vt_invoke = {
    .QueryInterface = a11y_invoke_QueryInterface,
    .AddRef = a11y_invoke_AddRef,
    .Release = a11y_invoke_Release,
    .Invoke = a11y_invoke_Invoke
};

static const IToggleProviderVtbl a11y_vt_toggle = {
    .QueryInterface = a11y_toggle_QueryInterface,
    .AddRef = a11y_toggle_AddRef,
    .Release = a11y_toggle_Release,
    .Toggle = a11y_toggle_Toggle,
    .get_ToggleState = a11y_toggle_get_ToggleState
};

static const IRangeValueProviderVtbl a11y_vt_range = {
    .QueryInterface = a11y_range_QueryInterface,
    .AddRef = a11y_range_AddRef,
    .Release = a11y_range_Release,
    .SetValue = a11y_range_SetValue,
    .get_Value = a11y_range_get_Value,
    .get_IsReadOnly = a11y_range_get_IsReadOnly,
    .get_Maximum = a11y_range_get_Maximum,
    .get_Minimum = a11y_range_get_Minimum,
    .get_LargeChange = a11y_range_get_LargeChange,
    .get_SmallChange = a11y_range_get_SmallChange
};

static const ISelectionProviderVtbl a11y_vt_sel = {
    .QueryInterface = a11y_sel_QueryInterface,
    .AddRef = a11y_sel_AddRef,
    .Release = a11y_sel_Release,
    .GetSelection = a11y_sel_GetSelection,
    .get_CanSelectMultiple = a11y_sel_get_CanSelectMultiple,
    .get_IsSelectionRequired = a11y_sel_get_IsSelectionRequired
};

static const ISelectionItemProviderVtbl a11y_vt_selitem = {
    .QueryInterface = a11y_selitem_QueryInterface,
    .AddRef = a11y_selitem_AddRef,
    .Release = a11y_selitem_Release,
    .Select = a11y_selitem_Select,
    .AddToSelection = a11y_selitem_AddToSelection,
    .RemoveFromSelection = a11y_selitem_RemoveFromSelection,
    .get_IsSelected = a11y_selitem_get_IsSelected,
    .get_SelectionContainer = a11y_selitem_get_SelectionContainer
};

static const IValueProviderVtbl a11y_vt_val = {
    .QueryInterface = a11y_val_QueryInterface,
    .AddRef = a11y_val_AddRef,
    .Release = a11y_val_Release,
    .SetValue = a11y_val_SetValue,
    .get_Value = a11y_val_get_Value,
    .get_IsReadOnly = a11y_val_get_IsReadOnly
};

static const IExpandCollapseProviderVtbl a11y_vt_expand = {
    .QueryInterface = a11y_expand_QueryInterface,
    .AddRef = a11y_expand_AddRef,
    .Release = a11y_expand_Release,
    .Expand = a11y_expand_Expand,
    .Collapse = a11y_expand_Collapse,
    .get_ExpandCollapseState = a11y_expand_get_ExpandCollapseState
};

static const ITextProviderVtbl a11y_vt_text = {
    .QueryInterface = a11y_text_QueryInterface,
    .AddRef = a11y_text_AddRef,
    .Release = a11y_text_Release,
    .GetSelection = a11y_text_GetSelection,
    .GetVisibleRanges = a11y_text_GetVisibleRanges,
    .RangeFromChild = a11y_text_RangeFromChild,
    .RangeFromPoint = a11y_text_RangeFromPoint,
    .get_DocumentRange = a11y_text_get_DocumentRange,
    .get_SupportedTextSelection = a11y_text_get_SupportedTextSelection
};

static const ITextRangeProviderVtbl a11y_vt_textrange = {
    .QueryInterface = a11y_trange_QueryInterface,
    .AddRef = a11y_trange_AddRef,
    .Release = a11y_trange_Release,
    .Clone = a11y_trange_Clone,
    .Compare = a11y_trange_Compare,
    .CompareEndpoints = a11y_trange_CompareEndpoints,
    .ExpandToEnclosingUnit = a11y_trange_ExpandToEnclosingUnit,
    .FindAttribute = a11y_trange_FindAttribute,
    .FindText = a11y_trange_FindText,
    .GetAttributeValue = a11y_trange_GetAttributeValue,
    .GetBoundingRectangles = a11y_trange_GetBoundingRectangles,
    .GetEnclosingElement = a11y_trange_GetEnclosingElement,
    .GetText = a11y_trange_GetText,
    .Move = a11y_trange_Move,
    .MoveEndpointByUnit = a11y_trange_MoveEndpointByUnit,
    .MoveEndpointByRange = a11y_trange_MoveEndpointByRange,
    .Select = a11y_trange_Select,
    .AddToSelection = a11y_trange_AddToSelection,
    .RemoveFromSelection = a11y_trange_RemoveFromSelection,
    .ScrollIntoView = a11y_trange_ScrollIntoView,
    .GetChildren = a11y_trange_GetChildren
};

/* ================= 公开 API：zfy 侧每帧提交节点表 ================= */

/* 最近一次 begin 的窗口槽位（end / hit / take_value 作用于该窗口） */
static int g_a11y_stage_win = -1;

/* 上一帧快照（end 里做属性 diff；只在 UI 线程使用，故放静态区） */
static a11y_node g_a11y_prev[A11Y_MAX_NODES];

/* 开始本帧：清空"正在构建"的节点表。win 为 gui_self()（1..8）。 */
void zfy_a11y_begin(int64_t win) {
    int wi = a11y_win_idx(win);
    if (wi < 0) return;
    g_a11y_stage_win = wi;
    a11y_lock();
    memset(g_a11y[wi].stage, 0, sizeof(a11y_node) * A11Y_MAX_NODES);
    g_a11y[wi].stage_n = 0;
    g_a11y[wi].stage_focus = -1;
    a11y_unlock();
}

/* 追加/覆盖一个节点。idx 由调用方从 0 递增；坐标是客户区物理像素；
   parent 为父节点下标（-1 = 直接挂在窗口根元素下）。 */
void zfy_a11y_push_node(int64_t win, int64_t idx, char *name, char *role, char *value,
                        int32_t states, int32_t x, int32_t y, int32_t w, int32_t h,
                        int32_t parent) {
    int wi = a11y_win_idx(win);
    a11y_node *t;
    if (wi < 0 || idx < 0 || idx >= A11Y_MAX_NODES) return;
    a11y_lock();
    t = &g_a11y[wi].stage[idx];
    memset(t, 0, sizeof(*t));
    t->used = 1;
    t->id = (int)idx;                       /* 回投时 zfy 侧按 idx → 组件 id 映射 */
    t->states = states;
    t->x = x; t->y = y;
    t->w = w; t->h = h;
    t->parent = (parent >= 0 && parent < A11Y_MAX_NODES) ? parent : -1;
    strncpy(t->name,  name  ? name  : "", A11Y_NAME_MAX - 1);
    strncpy(t->role,  role  ? role  : "", A11Y_ROLE_MAX - 1);
    strncpy(t->value, value ? value : "", A11Y_VAL_MAX - 1);
    if ((int)idx + 1 > g_a11y[wi].stage_n) g_a11y[wi].stage_n = (int)idx + 1;
    a11y_unlock();
}

/* 本帧焦点节点（-1 = 无焦点）；end 时与上一帧比较并发焦点事件 */
void zfy_a11y_set_focus(int64_t idx) {
    int wi = g_a11y_stage_win;
    if (wi < 0) return;
    a11y_lock();
    g_a11y[wi].stage_focus = (idx >= 0 && idx < A11Y_MAX_NODES) ? (int)idx : -1;
    a11y_unlock();
}

/* 发一个 BSTR 属性变化事件（old/new 均为 UTF-8） */
static void a11y_emit_str_prop(a11y_elem *el, PROPERTYID pid, const char *old_s, const char *new_s) {
    VARIANT o, n;
    if (!el || !g_uia_raise_prop) return;
    VariantInit(&o); VariantInit(&n);
    o.vt = VT_BSTR; o.bstrVal = a11y_bstr(old_s);
    n.vt = VT_BSTR; n.bstrVal = a11y_bstr(new_s);
    g_uia_raise_prop((IRawElementProviderSimple *)&el->simple, pid, o, n);
    SysFreeString(o.bstrVal);
    SysFreeString(n.bstrVal);
}

/* 结束本帧：提交节点表 + （仅在有人监听时）发结构/属性/焦点事件 */
void zfy_a11y_end(void) {
    int wi = g_a11y_stage_win;
    int prev_n, focus_old, focus_new, n;
    if (wi < 0 || wi >= GUI_MAXWIN) return;
    a11y_lock();
    prev_n = g_a11y[wi].cur_n;
    focus_old = g_a11y[wi].focus;
    memcpy(g_a11y_prev, g_a11y[wi].cur, sizeof(a11y_node) * A11Y_MAX_NODES);
    memcpy(g_a11y[wi].cur, g_a11y[wi].stage, sizeof(a11y_node) * A11Y_MAX_NODES);
    g_a11y[wi].cur_n = g_a11y[wi].stage_n;
    focus_new = g_a11y[wi].stage_focus;
    g_a11y[wi].focus = focus_new;
    n = g_a11y[wi].cur_n;
    a11y_unlock();

    if (!a11y_listening()) return;

    /* 结构变化：节点数量变了，通知客户端重取子树 */
    if (prev_n != n) {
        a11y_elem *root = a11y_elem_get(wi, -1);
        if (root) g_uia_raise_struct((IRawElementProviderSimple *)&root->simple,
                                     StructureChangeType_ChildrenInvalidated, NULL, 0);
    }

    /* 属性变化：名称 / 值 / 启用态 / 勾选态 */
    for (int i = 0; i < n; i++) {
        a11y_node *c = &g_a11y[wi].cur[i];
        a11y_node *o = (i < prev_n) ? &g_a11y_prev[i] : NULL;
        a11y_elem *el;
        if (!c->used) continue;
        el = a11y_elem_get(wi, i);
        if (!el) continue;
        if (o && o->used) {
            if (strcmp(o->name, c->name))
                a11y_emit_str_prop(el, UIA_NamePropertyId, o->name, c->name);
            if (strcmp(o->value, c->value))
                a11y_emit_str_prop(el, UIA_ValueValuePropertyId, o->value, c->value);
            if ((o->states ^ c->states) & A11Y_ST_DISABLED) {
                VARIANT ov, nv;
                VariantInit(&ov); VariantInit(&nv);
                ov.vt = VT_BOOL; ov.boolVal = (o->states & A11Y_ST_DISABLED) ? VARIANT_FALSE : VARIANT_TRUE;
                nv.vt = VT_BOOL; nv.boolVal = (c->states & A11Y_ST_DISABLED) ? VARIANT_FALSE : VARIANT_TRUE;
                g_uia_raise_prop((IRawElementProviderSimple *)&el->simple, UIA_IsEnabledPropertyId, ov, nv);
            }
            if ((o->states ^ c->states) & A11Y_ST_CHECKED) {
                VARIANT ov, nv;
                VariantInit(&ov); VariantInit(&nv);
                ov.vt = VT_I4; ov.lVal = (o->states & A11Y_ST_CHECKED)
                                          ? ToggleState_On : ToggleState_Off;
                nv.vt = VT_I4; nv.lVal = (c->states & A11Y_ST_CHECKED)
                                          ? ToggleState_On : ToggleState_Off;
                g_uia_raise_prop((IRawElementProviderSimple *)&el->simple, UIA_ToggleToggleStatePropertyId, ov, nv);
            }
        }
    }

    /* 焦点变化事件（读屏软件据此跟随朗读） */
    if (focus_new >= 0 && focus_new != focus_old) {
        a11y_elem *el = a11y_elem_get(wi, focus_new);
        if (el) g_uia_raise_event((IRawElementProviderSimple *)&el->simple, UIA_AutomationFocusChangedEventId);
    }
}

/* 命中测试：客户区坐标 → 已提交节点下标（后入者优先=最上层），-1=未命中 */
int64_t zfy_a11y_hit(int32_t x, int32_t y) {
    int wi = a11y_win_idx(0);
    int hit = -1;
    if (wi < 0) return -1;
    a11y_lock();
    for (int i = g_a11y[wi].cur_n - 1; i >= 0; i--) {
        a11y_node *nd = &g_a11y[wi].cur[i];
        if (!nd->used) continue;
        if (x >= nd->x && x < nd->x + nd->w && y >= nd->y && y < nd->y + nd->h) {
            hit = i;
            break;
        }
    }
    a11y_unlock();
    return hit;
}

/* 取走 UIA 文本设值（zfy 侧在 EV_A11Y_VALUE 且 key==0 时调用）
   返回字节数（不含 \0）；0=无待取值；-2=缓冲不足（调用方扩容重试） */
int32_t zfy_gui_a11y_take_value(int64_t idx, char *buf, int32_t cap) {
    int wi = -1, n;
    if (idx < 0 || idx >= A11Y_MAX_NODES) return 0;
    a11y_lock();
    if (g_a11y_stage_win >= 0 && g_a11y[g_a11y_stage_win].deliv_ok
        && g_a11y[g_a11y_stage_win].deliv_idx == (int)idx)
        wi = g_a11y_stage_win;
    else {
        for (int k = 0; k < GUI_MAXWIN; k++)
            if (g_a11y[k].deliv_ok && g_a11y[k].deliv_idx == (int)idx) { wi = k; break; }
    }
    if (wi < 0) { a11y_unlock(); return 0; }
    n = (int)strlen(g_a11y[wi].deliv_str);
    if (!buf || cap <= n) { a11y_unlock(); return -2; }
    memcpy(buf, g_a11y[wi].deliv_str, (size_t)n + 1);
    g_a11y[wi].deliv_ok = 0;
    a11y_unlock();
    return n;
}

/* 窗口线程：把 UIA 投递消息翻译成既有事件队列里的 EV_A11Y_* */
static void a11y_deliver(gui_win *w, UINT msg, WPARAM wp, LPARAM lp) {
    int wi = (int)(w - g_wins);
    int node = (int)wp;
    if (wi < 0 || wi >= GUI_MAXWIN) return;
    switch (msg) {
    case GUI_WM_A11Y_INVOKE:
        gui_push_ev(w, GUI_EV_A11Y_INVOKE, node, 0, 0);
        break;
    case GUI_WM_A11Y_VALUE:
        if (lp == 0) {
            /* 文本设值：待投递串搬到"已投递"槽，等 zfy 调 take_value 取走 */
            a11y_lock();
            g_a11y[wi].deliv_idx = node;
            strncpy(g_a11y[wi].deliv_str, g_a11y[wi].pend_str, A11Y_VAL_MAX - 1);
            g_a11y[wi].deliv_str[A11Y_VAL_MAX - 1] = 0;
            g_a11y[wi].deliv_ok = 1;
            a11y_unlock();
            gui_push_ev(w, GUI_EV_A11Y_VALUE, node, 0, 0);
        } else {
            /* 数值：LPARAM = 值 + 1（避免与"文本"路径的 0 混淆） */
            gui_push_ev(w, GUI_EV_A11Y_VALUE, node, 0, (int64_t)(lp - 1));
        }
        break;
    case GUI_WM_A11Y_FOCUS:
        gui_push_ev(w, GUI_EV_A11Y_FOCUS, node, 0, 0);
        break;
    default:
        break;
    }
}

/* ---------- 引擎初始化（首次开窗时懒创建；失败返回 0） ---------- */
static int gui_engine_init(void) {
    if (g_d2d_fct) return 1;
    /* COM 初始化：D2D/DWrite/WIC 均走 COM。已是 MTA 时不致命（RPC_E_CHANGED_MODE） */
    if (SUCCEEDED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE)))
        g_com_ready = 1;

    D2D1_FACTORY_OPTIONS fopt;
    memset(&fopt, 0, sizeof(fopt));
    if (FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &IID_ID2D1Factory1,
                                &fopt, (void **)&g_d2d_fct)))
        return 0;
    if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &gui_iid_dwrite,
                                   (IUnknown **)&g_dw)))
        return 0;
    if (FAILED(CoCreateInstance(&CLSID_WICImagingFactory, NULL, CLSCTX_INPROC_SERVER,
                                &IID_IWICImagingFactory, (void **)&g_wic)))
        return 0;

    /* D3D11 设备：硬件优先，失败退 WARP（远程桌面/无 GPU 环境仍可渲染） */
    D3D_FEATURE_LEVEL lv[] = { D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0,
                               D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0 };
    D3D_FEATURE_LEVEL got = 0;
    HRESULT hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL,
                                   D3D11_CREATE_DEVICE_BGRA_SUPPORT, lv, 4,
                                   D3D11_SDK_VERSION, &g_d3d, &got, NULL);
    if (FAILED(hr) || !g_d3d)
        hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_WARP, NULL,
                               D3D11_CREATE_DEVICE_BGRA_SUPPORT, lv, 4,
                               D3D11_SDK_VERSION, &g_d3d, &got, NULL);
    if (FAILED(hr) || !g_d3d) return 0;

    IDXGIDevice *dxdev = NULL;
    if (FAILED(ID3D11Device_QueryInterface(g_d3d, &IID_IDXGIDevice, (void **)&dxdev))) return 0;
    hr = FACT1(g_d2d_fct, CreateDevice, dxdev, &g_d2d_dev);
    IDXGIAdapter *ad = NULL;
    if (SUCCEEDED(hr)) IDXGIDevice_GetAdapter(dxdev, &ad);
    if (ad) {
        IDXGIAdapter_GetParent(ad, &IID_IDXGIFactory2, (void **)&g_dxgi);
        REL(ad);
    }
    REL(dxdev);
    if (!g_d2d_dev || !g_dxgi) return 0;

    /* 统一描边样式：平头、斜接，抗锯齿由 target 决定 */
    D2D1_STROKE_STYLE_PROPERTIES sp;
    memset(&sp, 0, sizeof(sp));
    sp.startCap = D2D1_CAP_STYLE_FLAT;
    sp.endCap = D2D1_CAP_STYLE_FLAT;
    sp.dashCap = D2D1_CAP_STYLE_FLAT;
    sp.lineJoin = D2D1_LINE_JOIN_MITER;
    sp.miterLimit = 10.0f;
    FACT(g_d2d_fct, CreateStrokeStyle, &sp, NULL, 0, &g_stroke_flat);
    return 1;
}

/* ---------- 文本格式缓存（64 槽 LRU，键 = 族/物理字号/字重/斜体/方向） ---------- */
static IDWriteTextFormat *gui_text_format(gui_win *w, const char *family,
                                          int px, int weight, int italic) {
    if (!g_dw || !w) return NULL;
    int rtl = w->rtl ? 1 : 0;
    const char *fam = (family && family[0]) ? family : "Microsoft YaHei UI";
    if (px <= 0) px = 16;
    float size = (float)((px * w->dpi + 95) / 96);   /* 逻辑 px → 物理 px */
    if (size < 1.0f) size = 1.0f;

    gui_tf_slot *victim = &g_tf[0];
    for (int i = 0; i < GUI_TF_SLOTS; i++) {
        gui_tf_slot *s = &g_tf[i];
        if (s->used) {
            if (s->size == size && s->weight == weight && s->italic == italic
                && s->rtl == rtl
                && strncmp(s->family, fam, sizeof(s->family) - 1) == 0) {
                s->stamp = ++g_tf_tick;
                return s->fmt;
            }
            if (s->stamp < victim->stamp || !victim->used) victim = s;
        } else if (!victim->used) {
            victim = s;
        }
    }
    /* 淘汰最久未用槽（固定 64 槽，不做动态增长） */
    REL(victim->fmt);
    memset(victim, 0, sizeof(*victim));

    wchar_t wfam[64];
    int n = MultiByteToWideChar(CP_UTF8, 0, fam, -1, wfam, 64);
    if (n <= 0) { wcscpy(wfam, L"Microsoft YaHei UI"); }
    IDWriteTextFormat *fmt = NULL;
    if (FAILED(IDWriteFactory_CreateTextFormat(g_dw, wfam, NULL,
            (DWRITE_FONT_WEIGHT)weight, italic ? DWRITE_FONT_STYLE_ITALIC : DWRITE_FONT_STYLE_NORMAL,
            DWRITE_FONT_STRETCH_NORMAL, size, L"zh-cn", &fmt)))
        return NULL;
    /* RTL：DirectWrite 阅读方向右到左（bidi 重排；布局镜像由 zfy 侧计算） */
    IDWriteTextFormat_SetReadingDirection(fmt, rtl ? DWRITE_READING_DIRECTION_RIGHT_TO_LEFT
                                                   : DWRITE_READING_DIRECTION_LEFT_TO_RIGHT);
    strncpy(victim->family, fam, sizeof(victim->family) - 1);
    victim->family[sizeof(victim->family) - 1] = 0;
    victim->size = size;
    victim->weight = weight;
    victim->italic = italic ? 1 : 0;
    victim->rtl = rtl;
    victim->fmt = fmt;
    victim->stamp = ++g_tf_tick;
    victim->used = 1;
    return fmt;
}

/* ---------- 颜色：0xAARRGGBB → 乘全局 alpha → D2D1_COLOR_F ---------- */
static uint32_t gui_argb_eff(gui_win *w, uint32_t c) {
    uint32_t a = (c >> 24) & 0xFFu;
    if (a == 0 && (c & 0x00FFFFFFu) != 0) a = 0xFFu;   /* 兼容旧 0xRRGGBB */
    a = a * (uint32_t)(w->alpha < 0 ? 0 : (w->alpha > 255 ? 255 : w->alpha)) / 255u;
    return (a << 24) | (c & 0x00FFFFFFu);
}

static D2D1_COLOR_F gui_color(uint32_t argb) {
    D2D1_COLOR_F c;
    c.a = (float)((argb >> 24) & 0xFFu) / 255.0f;
    c.r = (float)((argb >> 16) & 0xFFu) / 255.0f;
    c.g = (float)((argb >> 8) & 0xFFu) / 255.0f;
    c.b = (float)(argb & 0xFFu) / 255.0f;
    return c;
}

/* ---------- 纯色画刷缓存（每窗口 64 槽 LRU） ---------- */
static void gui_br_flush(gui_win *w) {
    for (int i = 0; i < GUI_BR_SLOTS; i++) {
        REL(w->br[i].br);
        w->br[i].br = NULL;
        w->br[i].used = 0;
    }
}

static ID2D1SolidColorBrush *gui_brush(gui_win *w, uint32_t argb) {
    if (!w || !w->ctx) return NULL;
    uint32_t eff = gui_argb_eff(w, argb);
    gui_br_slot *victim = &w->br[0];
    for (int i = 0; i < GUI_BR_SLOTS; i++) {
        gui_br_slot *s = &w->br[i];
        if (s->used) {
            if (s->argb == eff) {
                s->stamp = ++w->br_tick;
                return s->br;
            }
            if (!victim->used || s->stamp < victim->stamp) victim = s;
        } else if (!victim->used) {
            victim = s;
        }
    }
    REL(victim->br);
    memset(victim, 0, sizeof(*victim));
    D2D1_COLOR_F col = gui_color(eff);
    ID2D1SolidColorBrush *br = NULL;
    if (FAILED(RT_V(w->ctx, CreateSolidColorBrush, &col, NULL, &br))) return NULL;
    victim->argb = eff;
    victim->br = br;
    victim->stamp = ++w->br_tick;
    victim->used = 1;
    return br;
}

/* ---------- 混合模式：几何绘制统一入口 ---------- */
static void gui_draw_geo_brush(gui_win *w, ID2D1Geometry *geo, ID2D1Brush *br, float sw);

/* CPU 合成（模式 2/3/4）：把几何画到透明源位图，回读目标区，逐像素混合后上传绘制 */
static int gui_scr_ensure(gui_win *w, int bw, int bh) {
    if (bw < 1 || bh < 1) return 0;
    if (w->scr_w >= bw && w->scr_h >= bh && w->scr_src && w->scr_dst && w->scr_up && w->scr_buf)
        return 1;
    int nw = bw > 1 ? ((bw + 31) / 32) * 32 : 32;
    int nh = bh > 1 ? ((bh + 31) / 32) * 32 : 32;
    if (w->scr_w >= nw && w->scr_h >= nh) return 1;   /* 已有更大缓存，直接复用 */

    REL(w->scr_src); REL(w->scr_dst); REL(w->scr_up); w->scr_src = w->scr_dst = w->scr_up = NULL;
    free(w->scr_buf); w->scr_buf = NULL;
    w->scr_w = w->scr_h = 0;

    D2D1_BITMAP_PROPERTIES1 tp;
    memset(&tp, 0, sizeof(tp));
    tp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    tp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    tp.dpiX = 96; tp.dpiY = 96;
    tp.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET;
    D2D1_SIZE_U sz;
    sz.width = (UINT32)nw; sz.height = (UINT32)nh;
    if (FAILED(DC_V(w->ctx, CreateBitmap, sz, NULL, 0, &tp, &w->scr_src))) return 0;

    D2D1_BITMAP_PROPERTIES1 cp;
    memset(&cp, 0, sizeof(cp));
    cp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    cp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    cp.dpiX = 96; cp.dpiY = 96;
    cp.bitmapOptions = D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
    if (FAILED(DC_V(w->ctx, CreateBitmap, sz, NULL, 0, &cp, &w->scr_dst))) {
        REL(w->scr_src); w->scr_src = NULL;
        return 0;
    }

    D2D1_BITMAP_PROPERTIES1 up;
    memset(&up, 0, sizeof(up));
    up.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    up.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    up.dpiX = 96; up.dpiY = 96;
    up.bitmapOptions = D2D1_BITMAP_OPTIONS_NONE;
    if (FAILED(DC_V(w->ctx, CreateBitmap, sz, NULL, 0, &up, &w->scr_up))) {
        REL(w->scr_src); REL(w->scr_dst);
        w->scr_src = w->scr_dst = NULL;
        return 0;
    }
    w->scr_buf = (unsigned char *)malloc((size_t)nw * (size_t)nh * 4);
    if (!w->scr_buf) {
        REL(w->scr_src); REL(w->scr_dst); REL(w->scr_up);
        w->scr_src = w->scr_dst = w->scr_up = NULL;
        return 0;
    }
    w->scr_w = nw; w->scr_h = nh;
    return 1;
}

static void gui_blend_composite(gui_win *w, ID2D1Geometry *geo, ID2D1Brush *br,
                                float sw, int bx, int by, int bw, int bh) {
    if (!gui_scr_ensure(w, bw, bh)) return;
    D2D1_MATRIX_3X2_F m;
    RT_V(w->ctx, GetTransform, &m);

    /* 1) 源：透明底上按"当前变换 + 平移(-bx,-by)"画图元，结果贴在位图左上角 */
    D2D1_MATRIX_3X2_F lm = m;
    lm._31 -= (float)bx;
    lm._32 -= (float)by;
    DC_V(w->ctx, SetTarget, (ID2D1Image *)w->scr_src);
    RT_V(w->ctx, Clear, NULL);
    RT_V(w->ctx, SetTransform, &lm);
    if (sw > 0.0f) RT_V(w->ctx, DrawGeometry, geo, br, sw, g_stroke_flat);
    else           RT_V(w->ctx, FillGeometry, geo, br, NULL);
    RT_V(w->ctx, Flush, NULL, NULL);
    DC_V(w->ctx, SetTarget, NULL);

    /* 2) 源区快照 → CPU 缓冲（scr_src 不再作目标后才允许回读） */
    D2D1_POINT_2U dp;
    dp.x = 0; dp.y = 0;
    D2D1_RECT_U sr;
    sr.left = 0; sr.top = 0;
    sr.right = (UINT32)bw; sr.bottom = (UINT32)bh;
    D2D1_MAPPED_RECT ms;
    memset(&ms, 0, sizeof(ms));
    int src_ok = 0;
    if (SUCCEEDED(BM_V(w->scr_dst, CopyFromBitmap, &dp, (ID2D1Bitmap *)w->scr_src, &sr))
        && SUCCEEDED(BM1_V(w->scr_dst, Map, D2D1_MAP_OPTIONS_READ, &ms))) {
        for (int y = 0; y < bh; y++) {
            const unsigned char *srow = (const unsigned char *)ms.bits + (size_t)y * ms.pitch;
            memcpy(w->scr_buf + (size_t)y * (size_t)(bw * 4), srow, (size_t)bw * 4);
        }
        BM1_V(w->scr_dst, Unmap);
        src_ok = 1;
    }

    /* 3) 目标区快照 → CPU 逐像素合成 → 写回 scr_buf → 上传 */
    if (src_ok && w->target) {
        D2D1_BITMAP_PROPERTIES1 cp;
        memset(&cp, 0, sizeof(cp));
        cp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
        cp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
        cp.dpiX = 96; cp.dpiY = 96;
        cp.bitmapOptions = D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
        D2D1_SIZE_U dsz;
        dsz.width = (UINT32)bw; dsz.height = (UINT32)bh;
        ID2D1Bitmap1 *dstSnap = NULL;
        if (SUCCEEDED(DC_V(w->ctx, CreateBitmap, dsz, NULL, 0, &cp, &dstSnap)) && dstSnap) {
            D2D1_RECT_U tr;
            tr.left = (UINT32)bx; tr.top = (UINT32)by;
            tr.right = (UINT32)(bx + bw); tr.bottom = (UINT32)(by + bh);
            D2D1_MAPPED_RECT md;
            memset(&md, 0, sizeof(md));
            if (SUCCEEDED(BM_V(dstSnap, CopyFromBitmap, &dp, (ID2D1Bitmap *)w->target, &tr))
                && SUCCEEDED(BM1_V(dstSnap, Map, D2D1_MAP_OPTIONS_READ, &md))) {
                int mode = w->blend;
                for (int y = 0; y < bh; y++) {
                    unsigned char *srow = w->scr_buf + (size_t)y * (size_t)(bw * 4);
                    const unsigned char *drow = (const unsigned char *)md.bits + (size_t)y * md.pitch;
                    for (int x = 0; x < bw; x++) {
                        /* 预乘存储：通道 = 颜色 × alpha */
                        float as = (float)srow[x * 4 + 3] / 255.0f;
                        float ab = (float)drow[x * 4 + 3] / 255.0f;
                        if (as <= 0.0f) continue;
                        float ao = as + ab * (1.0f - as);
                        for (int ch = 0; ch < 3; ch++) {
                            float sp = (float)srow[x * 4 + ch] / 255.0f;   /* 源，预乘 */
                            float dpc = (float)drow[x * 4 + ch] / 255.0f;  /* 目标，预乘 */
                            float cs = sp / as;                            /* 源，去预乘 */
                            float cb = ab > 0.0f ? dpc / ab : 0.0f;        /* 目标，去预乘 */
                            float b;
                            if (mode == GUI_BLEND_MULTIPLY)      b = cs * cb;
                            else if (mode == GUI_BLEND_SCREEN)   b = 1.0f - (1.0f - cs) * (1.0f - cb);
                            else {                              /* XOR：按差值合成 */
                                b = cs > cb ? cs - cb : cb - cs;
                            }
                            /* 预乘通用式：co = sp*(1-ab) + as*ab*b + dpc*(1-as) */
                            float co = sp * (1.0f - ab) + as * ab * b + dpc * (1.0f - as);
                            if (co < 0.0f) co = 0.0f;
                            if (co > 1.0f) co = 1.0f;
                            srow[x * 4 + ch] = (unsigned char)(co * 255.0f + 0.5f);
                        }
                        srow[x * 4 + 3] = (unsigned char)(ao * 255.0f + 0.5f);
                    }
                }
                BM1_V(dstSnap, Unmap);
            }
            REL(dstSnap);
        }
    }

    /* 4) 上传结果并画回目标区（此处用设备坐标，绕开当前变换） */
    D2D1_RECT_U ur;
    ur.left = 0; ur.top = 0;
    ur.right = (UINT32)bw; ur.bottom = (UINT32)bh;
    if (src_ok && SUCCEEDED(BM_V(w->scr_up, CopyFromMemory, &ur, w->scr_buf, (UINT32)(bw * 4))) && w->target) {
        D2D1_MATRIX_3X2_F id;
        memset(&id, 0, sizeof(id));
        id._11 = 1.0f; id._22 = 1.0f;
        RT_V(w->ctx, SetTransform, &id);
        DC_V(w->ctx, SetTarget, (ID2D1Image *)w->target);
        D2D1_RECT_F dest;
        dest.left = (float)bx; dest.top = (float)by;
        dest.right = (float)(bx + bw); dest.bottom = (float)(by + bh);
        RT_V(w->ctx, DrawBitmap, (ID2D1Bitmap *)w->scr_up, &dest, 1.0f,
              D2D1_BITMAP_INTERPOLATION_MODE_NEAREST_NEIGHBOR, NULL);
    } else if (w->target) {
        DC_V(w->ctx, SetTarget, (ID2D1Image *)w->target);
    }
    RT_V(w->ctx, SetTransform, &m);
}
static void gui_draw_geo_brush(gui_win *w, ID2D1Geometry *geo, ID2D1Brush *br, float sw) {
    if (!w || !w->ctx || !geo || !br) return;
    if (w->blend == GUI_BLEND_SRCOVER) {
        if (sw > 0.0f) RT_V(w->ctx, DrawGeometry, geo, br, sw, g_stroke_flat);
        else           RT_V(w->ctx, FillGeometry, geo, br, NULL);
        return;
    }
    if (w->blend == GUI_BLEND_ADD) {
        DC_V(w->ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_ADD);
        if (sw > 0.0f) RT_V(w->ctx, DrawGeometry, geo, br, sw, g_stroke_flat);
        else           RT_V(w->ctx, FillGeometry, geo, br, NULL);
        DC_V(w->ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_SOURCE_OVER);
        return;
    }
    /* 2=Multiply 3=Screen 4=Xor：包围盒内 CPU 合成 */
    D2D1_RECT_F bb;
    if (FAILED(GEO(geo, GetBounds, NULL, &bb))) return;
    float pad = (sw > 0.0f ? sw : 0.0f) + 2.0f;
    int bx = (int)(bb.left - pad), by = (int)(bb.top - pad);
    int bx2 = (int)(bb.right + pad + 0.5f), by2 = (int)(bb.bottom + pad + 0.5f);
    if (bx < 0) bx = 0;
    if (by < 0) by = 0;
    if (bx2 > w->w) bx2 = w->w;
    if (by2 > w->h) by2 = w->h;
    int bw = bx2 - bx, bh = by2 - by;
    if (bw <= 0 || bh <= 0) return;
    DC_V(w->ctx, SetTarget, (ID2D1Image *)w->target);
    gui_blend_composite(w, geo, br, sw, bx, by, bw, bh);
}
static void gui_draw_geo(gui_win *w, ID2D1Geometry *geo, uint32_t argb, float sw) {
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    gui_draw_geo_brush(w, geo, (ID2D1Brush *)br, sw);
}

static gui_win *gui_win_of(HWND hw) {
    return (gui_win *)(INT_PTR)GetWindowLongPtrW(hw, GWLP_USERDATA);
}

/* ---------- 渲染目标（交换链 + 目标位图） ---------- */
static int gui_rt_bind_target(gui_win *w) {
    if (!w->ctx || !w->swap) return 0;
    if (w->target) {
        w->ctx->lpVtbl->SetTarget(w->ctx, NULL);
        REL(w->target);
        w->target = NULL;
    }
    IDXGISurface *surf = NULL;
    if (FAILED(IDXGISwapChain1_GetBuffer(w->swap, 0, &IID_IDXGISurface, (void **)&surf))) return 0;
    D2D1_BITMAP_PROPERTIES1 bp;
    memset(&bp, 0, sizeof(bp));
    bp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    bp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    bp.dpiX = 96; bp.dpiY = 96;
    bp.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
    HRESULT hr = DC_V(w->ctx, CreateBitmapFromDxgiSurface, surf, &bp, &w->target);
    REL(surf);
    if (FAILED(hr) || !w->target) return 0;
    w->ctx->lpVtbl->SetTarget(w->ctx, (ID2D1Image *)w->target);
    return 1;
}

static void gui_rt_release(gui_win *w) {
    gui_br_flush(w);
    REL(w->scr_src); REL(w->scr_dst); REL(w->scr_up);
    w->scr_src = w->scr_dst = w->scr_up = NULL;
    free(w->scr_buf);
    w->scr_buf = NULL;
    w->scr_w = w->scr_h = 0;
    if (w->ctx && w->target) w->ctx->lpVtbl->SetTarget(w->ctx, NULL);
    REL(w->target); w->target = NULL;
    REL(w->ctx); w->ctx = NULL;
    REL(w->swap); w->swap = NULL;
}

static int gui_rt_create(gui_win *w) {
    DXGI_SWAP_CHAIN_DESC1 sd;
    memset(&sd, 0, sizeof(sd));
    sd.Width = (UINT32)(w->w > 0 ? w->w : 1);
    sd.Height = (UINT32)(w->h > 0 ? w->h : 1);
    sd.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    sd.SampleDesc.Count = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.BufferCount = 2;
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    sd.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
    sd.Scaling = DXGI_SCALING_NONE;
    if (FAILED(IDXGIFactory2_CreateSwapChainForHwnd(g_dxgi, (IUnknown *)g_d3d, w->hwnd,
                                                   &sd, NULL, NULL, &w->swap)))
        return 0;
    IDXGIFactory2_MakeWindowAssociation(g_dxgi, w->hwnd, DXGI_MWA_NO_ALT_ENTER);
    if (FAILED(g_d2d_dev->lpVtbl->CreateDeviceContext(g_d2d_dev,
                                                      D2D1_DEVICE_CONTEXT_OPTIONS_NONE, &w->ctx)))
        return 0;
    RT_V(w->ctx, SetDpi, 96.0f, 96.0f);
    RT_V(w->ctx, SetAntialiasMode, D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
    RT_V(w->ctx, SetTextAntialiasMode, D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);
    if (!gui_rt_bind_target(w)) return 0;
    return 1;
}

static void gui_rt_resize(gui_win *w, int nw, int nh) {
    if (!w->swap || !w->ctx) { w->w = nw; w->h = nh; return; }
    if (w->target) {
        w->ctx->lpVtbl->SetTarget(w->ctx, NULL);
        REL(w->target);
        w->target = NULL;
    }
    if (FAILED(IDXGISwapChain1_ResizeBuffers(w->swap, 0, (UINT32)nw, (UINT32)nh,
                                             DXGI_FORMAT_UNKNOWN, 0))) {
        w->w = nw; w->h = nh;
        return;
    }
    w->w = nw; w->h = nh;
    gui_rt_bind_target(w);
    /* 临时合成位图尺寸随目标变化，下一次混合绘制会自动重建 */
}

static LRESULT CALLBACK gui_wndproc(HWND hw, UINT msg, WPARAM wp, LPARAM lp) {
    gui_win *w = gui_win_of(hw);
    if (!w) return DefWindowProcW(hw, msg, wp, lp);   /* 创建期消息 */
    switch (msg) {
    case WM_GETOBJECT:
        /* UIA 客户端请求本窗口的根元素：lParam == UiaRootObjectId（-25）。
           仅当 UIAutomationCore 可用且确实有客户端监听时才返回 Provider，
           其余情况交回默认处理（返回 0 表示"没有对象"）。 */
        if (lp == (LPARAM)UiaRootObjectId) {
            a11y_elem *root;
            if (!a11y_listening()) return 0;
            root = a11y_elem_get((int)(w - g_wins), -1);
            if (!root || !g_uia_raw_provider) return 0;
            return g_uia_raw_provider(hw, wp, lp, (IRawElementProviderSimple *)&root->simple);
        }
        break;
    case WM_SIZE:
        /* 最小化不重建；尺寸变化时重建交换链缓冲并通知业务层重布局 */
        if (w->alive && wp != SIZE_MINIMIZED) {
            int nw = LOWORD(lp), nh = HIWORD(lp);
            if (nw > 0 && nh > 0 && (nw != w->w || nh != w->h)) {
                gui_rt_resize(w, nw, nh);
                gui_push_ev(w, GUI_EV_SIZE, nw, nh, 0);
            }
        }
        return 0;
    case WM_PAINT: {
        /* 交换链内容自持（Flip 模型），这里只校验更新区防刷屏重绘 */
        PAINTSTRUCT ps;
        BeginPaint(hw, &ps);
        EndPaint(hw, &ps);
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;                          /* 防闪烁：擦背景交给 present */
    case WM_MOUSEMOVE:
        gui_push_ev(w, GUI_EV_MOVE, (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0);
        return 0;
    case WM_LBUTTONDOWN: gui_push_ev(w, GUI_EV_LDOWN, (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0); return 0;
    case WM_LBUTTONUP:   gui_push_ev(w, GUI_EV_LUP,   (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0); return 0;
    case WM_RBUTTONDOWN: gui_push_ev(w, GUI_EV_RDOWN, (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0); return 0;
    case WM_RBUTTONUP:   gui_push_ev(w, GUI_EV_RUP,   (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0); return 0;
    case WM_MOUSEWHEEL:
        gui_push_ev(w, GUI_EV_WHEEL, 0, 0, (int16_t)(wp >> 16));
        return 0;
    case WM_KEYDOWN: {
        int vk = (int)wp;
        /* Ctrl+C/V/A/X：WM_CHAR 只会送出控制码，这里统一成显式组合键事件 */
        if ((vk == 'C' || vk == 'V' || vk == 'A' || vk == 'X')
            && (GetKeyState(VK_CONTROL) < 0)) {
            gui_push_ev(w, GUI_EV_KEY, 0, 0, GUI_KEY_CTRL | vk);
            return 0;
        }
        /* 导航/编辑键不走 WM_CHAR，显式推送；Shift 按下时带 SHIFT 位（扩选） */
        if (vk == VK_LEFT || vk == VK_RIGHT || vk == VK_UP || vk == VK_DOWN
            || vk == VK_DELETE || vk == VK_HOME || vk == VK_END) {
            int64_t mod = GUI_KEY_EXT;
            if (GetKeyState(VK_SHIFT) < 0) mod |= GUI_KEY_SHIFT;
            gui_push_ev(w, GUI_EV_KEY, 0, 0, mod | vk);
        }
        return 0;
    }
    case WM_CHAR: {
        /* UTF-8 编码策略：WM_CHAR 送来的是 UTF-16 码元（中文一键一个码元，
           >0x7F 的值经 widgets 的 cast(k, char) 会截断成乱码字节）。这里把
           码元（含代理对）转成 UTF-8 字节序列，逐字节作为连续 KEY 事件入队
           ——业务层逐字节追加即拼出正确 UTF-8 串，与 string 内部表示一致 */
        static unsigned int pend_sur = 0;   /* 高代理暂存（键盘焦点唯一，进程级即可） */
        unsigned int cp = (unsigned int)wp;
        if (cp >= 0xD800 && cp <= 0xDBFF) { pend_sur = cp; return 0; }
        if (cp >= 0xDC00 && cp <= 0xDFFF && pend_sur) {
            cp = 0x10000u + ((pend_sur - 0xD800) << 10) + (cp - 0xDC00);
            pend_sur = 0;
        }
        unsigned char u8[4];
        int n;
        if (cp < 0x80)      { u8[0] = (unsigned char)cp; n = 1; }
        else if (cp < 0x800)  { u8[0] = 0xC0 | (cp >> 6); u8[1] = 0x80 | (cp & 0x3F); n = 2; }
        else if (cp < 0x10000){ u8[0] = 0xE0 | (cp >> 12); u8[1] = 0x80 | ((cp >> 6) & 0x3F); u8[2] = 0x80 | (cp & 0x3F); n = 3; }
        else { u8[0] = 0xF0 | (cp >> 18); u8[1] = 0x80 | ((cp >> 12) & 0x3F); u8[2] = 0x80 | ((cp >> 6) & 0x3F); u8[3] = 0x80 | (cp & 0x3F); n = 4; }
        for (int i = 0; i < n; i++)
            gui_push_ev(w, GUI_EV_KEY, 0, 0, (int64_t)u8[i]);
        return 0;
    }
    case WM_CLOSE:
        w->should_close = 1;
        DestroyWindow(hw);
        return 0;
    case WM_DESTROY:
        w->alive = 0;
        w->used = 0;
        w->hwnd = NULL;
        gui_rt_release(w);
        return 0;
    /* UIA 动作回投：UIA 线程只 PostMessage，这里在 UI 线程翻译成 EV_A11Y_* */
    case GUI_WM_A11Y_INVOKE:
    case GUI_WM_A11Y_VALUE:
    case GUI_WM_A11Y_FOCUS:
        a11y_deliver(w, msg, wp, lp);
        return 0;
    }
    return DefWindowProcW(hw, msg, wp, lp);
}

static wchar_t *gui_utf8_to_wide(const char *s) {
    int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
    if (n <= 0) n = 1;
    wchar_t *w = (wchar_t *)malloc((size_t)n * sizeof(wchar_t));
    MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n);
    return w;
}

int32_t zfy_gui_open(int32_t w, int32_t h, char *title_utf8) {
    gui_win *wslot = NULL;
    for (int i = 0; i < GUI_MAXWIN; i++)
        if (!g_wins[i].used) { wslot = &g_wins[i]; break; }
    if (!wslot) return -5;                 /* 窗口数达上限 */
    if (w <= 0 || h <= 0) return -2;
    /* 渲染引擎不可用：返回负数失败（绝不静默退回 GDI） */
    if (!gui_engine_init()) return -6;
    static int class_registered = 0;
    if (!class_registered) {
        WNDCLASSW wc;
        memset(&wc, 0, sizeof(wc));
        wc.lpfnWndProc = gui_wndproc;
        wc.hInstance = GetModuleHandleW(NULL);
        wc.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
        wc.hbrBackground = NULL;
        wc.lpszClassName = L"ZfyGuiWindow";
        if (!RegisterClassW(&wc)) return -3;
        class_registered = 1;
    }
    /* DPI 感知（进程级一次性）：Per-Monitor V2 优先，旧系统退回 SetProcessDPIAware。
       之后 w/h 是物理像素，DWM 不再拉伸——文字与像素逐一对齐，不糊 */
    typedef BOOL (WINAPI *SPDACfn)(void *);
    SPDACfn spdac = (SPDACfn)(void *)GetProcAddress(GetModuleHandleW(L"user32.dll"),
                                                    "SetProcessDpiAwarenessContext");
    if (spdac) spdac((void *)(INT_PTR)-4);       /* PER_MONITOR_AWARE_V2 */
    else SetProcessDPIAware();
    int dpi = 96;
    {
        HDC sdc = GetDC(NULL);
        dpi = GetDeviceCaps(sdc, LOGPIXELSX);
        ReleaseDC(NULL, sdc);
    }
    if (dpi <= 0) dpi = 96;
    w = w * dpi / 96;                      /* 逻辑尺寸 → 物理尺寸 */
    h = h * dpi / 96;
    wchar_t *wt = gui_utf8_to_wide(title_utf8 ? title_utf8 : "zfy");
    /* 可调尺寸窗口：客户区初始为 w x h */
    DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX
                | WS_MAXIMIZEBOX | WS_THICKFRAME;
    RECT rc = { 0, 0, w, h };
    AdjustWindowRect(&rc, style, 0);
    HWND hwnd = CreateWindowW(L"ZfyGuiWindow", wt,
                              style,
                              CW_USEDEFAULT, CW_USEDEFAULT,
                              rc.right - rc.left, rc.bottom - rc.top,
                              NULL, NULL, GetModuleHandleW(NULL), NULL);
    free(wt);
    if (!hwnd) return -4;
    memset(wslot, 0, sizeof(*wslot));
    wslot->hwnd = hwnd;
    wslot->w = w;
    wslot->h = h;
    wslot->dpi = dpi;
    wslot->alpha = 255;
    wslot->blend = GUI_BLEND_SRCOVER;
    strncpy(wslot->tf_family, "Microsoft YaHei UI", sizeof(wslot->tf_family) - 1);
    wslot->tf_family[sizeof(wslot->tf_family) - 1] = 0;
    wslot->tf_px = 16;
    wslot->tf_weight = 400;
    wslot->tf_italic = 0;
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)wslot);
    if (!gui_rt_create(wslot)) {
        DestroyWindow(hwnd);
        memset(wslot, 0, sizeof(*wslot));
        return -6;                          /* D2D 交换链创建失败 */
    }
    wslot->should_close = 0;
    wslot->alive = 1;
    wslot->used = 1;
    g_cur = wslot;
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    return 0;
}

/* 泵消息（非阻塞）+ 从当前窗口队列取一事件；返回 1=取到，0=无 */
int32_t zfy_gui_poll(int64_t *t, int64_t *x, int64_t *y, int64_t *k) {
    if (!g_cur) return 0;
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT) {
            for (int i = 0; i < GUI_MAXWIN; i++) g_wins[i].alive = 0;
            break;
        }
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    if (!g_cur || g_cur->qh == g_cur->qt) return 0;
    *t = g_cur->q[g_cur->qh].t; *x = g_cur->q[g_cur->qh].x;
    *y = g_cur->q[g_cur->qh].y; *k = g_cur->q[g_cur->qh].k;
    g_cur->qh = (g_cur->qh + 1) % GUI_EVQ;
    return 1;
}

int32_t zfy_gui_alive(void)        { return g_cur ? g_cur->alive : 0; }
int32_t zfy_gui_should_close(void) { return g_cur ? g_cur->should_close : 1; }
int32_t zfy_gui_alive_any(void) {
    for (int i = 0; i < GUI_MAXWIN; i++)
        if (g_wins[i].used && g_wins[i].alive) return 1;
    return 0;
}
int32_t zfy_gui_self(void) {
    for (int i = 0; i < GUI_MAXWIN; i++)
        if (g_cur == &g_wins[i]) return i + 1;
    return 0;
}
void zfy_gui_select(int64_t id) {
    if (id >= 1 && id <= GUI_MAXWIN && g_wins[id - 1].used)
        g_cur = &g_wins[id - 1];
}
int32_t zfy_gui_w(void)            { return g_cur ? g_cur->w : 0; }
int32_t zfy_gui_h(void)            { return g_cur ? g_cur->h : 0; }
int32_t zfy_gui_dpi(void)          { return g_cur ? g_cur->dpi : 96; }

/* ---- 剪贴板（CF_UNICODETEXT，UTF-8 进出） ----
 * clip_get 返回写入 buf 的字节数（不含 \0）；-1=打开失败/无文本；-2=缓冲不足。
 * 失败时 buf 保持原样。调用频率低，无额外分配。 */
int32_t zfy_gui_clip_get(char *buf, int32_t cap) {
    if (!buf || cap <= 0) return -1;
    if (!OpenClipboard(NULL)) return -1;
    HANDLE h = GetClipboardData(CF_UNICODETEXT);
    if (!h) { CloseClipboard(); return -1; }
    wchar_t *w = (wchar_t *)GlobalLock(h);
    if (!w) { CloseClipboard(); return -1; }
    int need = WideCharToMultiByte(CP_UTF8, 0, w, -1, NULL, 0, NULL, NULL);
    if (need <= 0 || need > cap) {
        GlobalUnlock(h);
        CloseClipboard();
        return -2;
    }
    WideCharToMultiByte(CP_UTF8, 0, w, -1, buf, need, NULL, NULL);
    GlobalUnlock(h);
    CloseClipboard();
    return need - 1;                       /* 不含 \0 */
}

/* clip_set：把 UTF-8 文本放入剪贴板（替换现有内容；\n 由调用方自行决定格式） */
void zfy_gui_clip_set(char *utf8) {
    if (!utf8) utf8 = "";
    int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    if (wlen <= 0) return;
    HGLOBAL h = GlobalAlloc(GMEM_MOVEABLE, (size_t)wlen * sizeof(wchar_t));
    if (!h) return;
    wchar_t *w = (wchar_t *)GlobalLock(h);
    if (!w) { GlobalFree(h); return; }
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, w, wlen);
    GlobalUnlock(h);
    if (!OpenClipboard(NULL)) { GlobalFree(h); return; }
    EmptyClipboard();
    if (SetClipboardData(CF_UNICODETEXT, h) == NULL) GlobalFree(h);
    CloseClipboard();
}

void zfy_gui_close(void) {
    if (g_cur && g_cur->hwnd) {
        HWND hw = g_cur->hwnd;
        g_cur->hwnd = NULL;
        g_cur->alive = 0;
        g_cur->used = 0;
        DestroyWindow(hw);                 /* WM_DESTROY 里释放 D2D 资源 */
    }
}

void zfy_gui_title(char *title_utf8) {
    if (!g_cur || !g_cur->hwnd) return;
    wchar_t *wt = gui_utf8_to_wide(title_utf8 ? title_utf8 : "");
    SetWindowTextW(g_cur->hwnd, wt);
    free(wt);
}

/* 窗口图标（当前窗口）：path 为 .ico/.png 等系统可加载文件；失败静默 */
void zfy_gui_set_icon(char *path_utf8) {
    if (!g_cur || !g_cur->hwnd || !path_utf8) return;
    wchar_t *wp = gui_utf8_to_wide(path_utf8);
    HICON big = (HICON)LoadImageW(NULL, wp, IMAGE_ICON, 0, 0,
                                  LR_LOADFROMFILE | LR_DEFAULTSIZE);
    HICON small = (HICON)LoadImageW(NULL, wp, IMAGE_ICON,
                                    GetSystemMetrics(SM_CXSMICON),
                                    GetSystemMetrics(SM_CYSMICON), LR_LOADFROMFILE);
    free(wp);
    if (big)   SendMessageW(g_cur->hwnd, WM_SETICON, ICON_BIG, (LPARAM)big);
    if (small) SendMessageW(g_cur->hwnd, WM_SETICON, ICON_SMALL, (LPARAM)small);
}

/* 提交整帧：Flush + Present（每帧绘制完成后调用一次） */
static int g_dbg_drawing[GUI_MAXWIN];
void zfy_gui_present(void) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || !w->swap) return;
    int idx = (int)(w - g_wins);
    if (idx >= 0 && idx < GUI_MAXWIN && g_dbg_drawing[idx]) {
        RT_V(w->ctx, EndDraw, NULL, NULL);
        g_dbg_drawing[idx] = 0;
    }
    RT_V(w->ctx, Flush, NULL, NULL);
    IDXGISwapChain1_Present(w->swap, 1, 0);
    RT_V(w->ctx, BeginDraw);
    if (idx >= 0 && idx < GUI_MAXWIN) g_dbg_drawing[idx] = 1;
}

/* ---------- 图元 ---------- */

/* 矩形几何（混合模式路径用） */
static ID2D1RectangleGeometry *gui_rect_geo(int32_t x, int32_t y, int32_t w, int32_t h) {
    D2D1_RECT_F r;
    r.left = (float)x; r.top = (float)y;
    r.right = (float)(x + w); r.bottom = (float)(y + h);
    ID2D1RectangleGeometry *g = NULL;
    if (FAILED(FACT(g_d2d_fct, CreateRectangleGeometry, &r, &g))) return NULL;
    return g;
}

void zfy_gui_fill_rect(int32_t rx, int32_t ry, int32_t rw, int32_t rh, uint32_t argb) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (rw <= 0 || rh <= 0) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    D2D1_RECT_F r;
    r.left = (float)rx; r.top = (float)ry;
    r.right = (float)(rx + rw); r.bottom = (float)(ry + rh);
    if (w->blend == GUI_BLEND_SRCOVER) {
        RT_V(w->ctx, FillRectangle, &r, (ID2D1Brush *)br);
    } else if (w->blend == GUI_BLEND_ADD) {
        DC_V(w->ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_ADD);
        RT_V(w->ctx, FillRectangle, &r, (ID2D1Brush *)br);
        DC_V(w->ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_SOURCE_OVER);
    } else {
        ID2D1RectangleGeometry *g = gui_rect_geo(rx, ry, rw, rh);
        if (g) { gui_draw_geo_brush(w, (ID2D1Geometry *)g, (ID2D1Brush *)br, 0.0f); REL(g); }
    }
}

/* 描边矩形（真描边，替代旧 4 次填充模拟；width<=0 视为 1） */
void zfy_gui_stroke_rect(int32_t x, int32_t y, int32_t rw, int32_t rh,
                         uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (rw <= 0 || rh <= 0) return;
    float sw = (float)(width > 0 ? width : 1);
    float half = sw / 2.0f;
    D2D1_RECT_F r;
    r.left = (float)x + half; r.top = (float)y + half;
    r.right = (float)(x + rw) - half; r.bottom = (float)(y + rh) - half;
    if (r.right <= r.left || r.bottom <= r.top) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    RT_V(w->ctx, DrawRectangle, &r, (ID2D1Brush *)br, sw, g_stroke_flat);
}

/* 圆角矩形：fill=0 跳过填充，border=0 跳过描边（1px）；r 为逻辑半径 */
void zfy_gui_round_rect(int32_t x, int32_t y, int32_t rw, int32_t rh, int32_t r,
                        uint32_t fill, uint32_t border) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (rw <= 0 || rh <= 0) return;
    if (r * 2 > rw) r = rw / 2;
    if (r * 2 > rh) r = rh / 2;
    if (r < 0) r = 0;
    D2D1_ROUNDED_RECT rr;
    rr.rect.left = (float)x; rr.rect.top = (float)y;
    rr.rect.right = (float)(x + rw); rr.rect.bottom = (float)(y + rh);
    rr.radiusX = (float)r; rr.radiusY = (float)r;
    if (fill) {
        ID2D1SolidColorBrush *br = gui_brush(w, fill);
        if (br) {
            if (w->blend == GUI_BLEND_SRCOVER) {
                RT_V(w->ctx, FillRoundedRectangle, &rr, (ID2D1Brush *)br);
            } else {
                /* 圆角几何走统一混合路径 */
                ID2D1RoundedRectangleGeometry *g = NULL;
                if (SUCCEEDED(FACT(g_d2d_fct, CreateRoundedRectangleGeometry, &rr, &g)) && g) {
                    gui_draw_geo_brush(w, (ID2D1Geometry *)g, (ID2D1Brush *)br, 0.0f);
                    REL(g);
                }
            }
        }
    }
    if (border) {
        ID2D1SolidColorBrush *br = gui_brush(w, border);
        if (br) RT_V(w->ctx, DrawRoundedRectangle, &rr, (ID2D1Brush *)br, 1.0f, g_stroke_flat);
    }
}

/* 线段：width<=0 视为 1 */
void zfy_gui_line(int32_t x0, int32_t y0, int32_t x1, int32_t y1,
                  uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    float sw = (float)(width > 0 ? width : 1);
    if (w->blend == GUI_BLEND_SRCOVER) {
        D2D1_POINT_2F a, b;
        a.x = (float)x0; a.y = (float)y0; b.x = (float)x1; b.y = (float)y1;
        RT_V(w->ctx, DrawLine, a, b, (ID2D1Brush *)br, sw, g_stroke_flat);
        return;
    }
    ID2D1PathGeometry *pg = NULL;
    ID2D1GeometrySink *sink = NULL;
    if (FAILED(FACT(g_d2d_fct, CreatePathGeometry, &pg))) return;
    if (FAILED(PG(pg, Open, &sink))) { REL(pg); return; }
    SINK(sink, BeginFigure, (D2D1_POINT_2F){ (float)x0, (float)y0 }, D2D1_FIGURE_BEGIN_HOLLOW);
    SINK2(sink, AddLine, (D2D1_POINT_2F){ (float)x1, (float)y1 });
    SINK(sink, EndFigure, D2D1_FIGURE_END_OPEN);
    SINK_CLOSE(sink);
    REL(sink);
    gui_draw_geo_brush(w, (ID2D1Geometry *)pg, (ID2D1Brush *)br, sw);
    REL(pg);
}

/* 渐变矩形：c1→c2 线性插值，vertical 非 0 为纵向（D2D 线性渐变画刷） */
void zfy_gui_fill_grad(int32_t rx, int32_t ry, int32_t rw, int32_t rh,
                       uint32_t c1, uint32_t c2, int32_t vertical) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (rw <= 0 || rh <= 0) return;
    uint32_t e1 = gui_argb_eff(w, c1), e2 = gui_argb_eff(w, c2);
    D2D1_GRADIENT_STOP stops[2];
    stops[0].position = 0.0f;  stops[0].color = gui_color(e1);
    stops[1].position = 1.0f;  stops[1].color = gui_color(e2);
    ID2D1GradientStopCollection *coll = NULL;
    if (FAILED(RT_V(w->ctx, CreateGradientStopCollection, stops, 2,
                    D2D1_GAMMA_2_2, D2D1_EXTEND_MODE_CLAMP, &coll)))
        return;
    D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES gp;
    if (vertical) {
        gp.startPoint.x = (float)rx; gp.startPoint.y = (float)ry;
        gp.endPoint.x = (float)rx;   gp.endPoint.y = (float)(ry + rh);
    } else {
        gp.startPoint.x = (float)rx; gp.startPoint.y = (float)ry;
        gp.endPoint.x = (float)(rx + rw); gp.endPoint.y = (float)ry;
    }
    ID2D1LinearGradientBrush *br = NULL;
    if (FAILED(RT_V(w->ctx, CreateLinearGradientBrush, &gp, NULL, coll, &br))) {
        REL(coll);
        return;
    }
    D2D1_RECT_F r;
    r.left = (float)rx; r.top = (float)ry;
    r.right = (float)(rx + rw); r.bottom = (float)(ry + rh);
    if (w->blend == GUI_BLEND_SRCOVER) {
        RT_V(w->ctx, FillRectangle, &r, (ID2D1Brush *)br);
    } else {
        ID2D1RectangleGeometry *g = gui_rect_geo(rx, ry, rw, rh);
        if (g) { gui_draw_geo_brush(w, (ID2D1Geometry *)g, (ID2D1Brush *)br, 0.0f); REL(g); }
    }
    REL(br);
    REL(coll);
}

/* 圆：填充 / 描边 */
void zfy_gui_fill_circle(int32_t cx, int32_t cy, int32_t r, uint32_t argb) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || r <= 0) return;
    D2D1_ELLIPSE e;
    e.point.x = (float)cx; e.point.y = (float)cy;
    e.radiusX = (float)r; e.radiusY = (float)r;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    if (w->blend == GUI_BLEND_SRCOVER) {
        RT_V(w->ctx, FillEllipse, &e, (ID2D1Brush *)br);
        return;
    }
    ID2D1EllipseGeometry *g = NULL;
    if (SUCCEEDED(FACT(g_d2d_fct, CreateEllipseGeometry, &e, &g)) && g) {
        gui_draw_geo_brush(w, (ID2D1Geometry *)g, (ID2D1Brush *)br, 0.0f);
        REL(g);
    }
}

void zfy_gui_stroke_circle(int32_t cx, int32_t cy, int32_t r, uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || r <= 0) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    D2D1_ELLIPSE e;
    float sw = (float)(width > 0 ? width : 1);
    e.point.x = (float)cx; e.point.y = (float)cy;
    e.radiusX = (float)r - sw / 2.0f;
    e.radiusY = (float)r - sw / 2.0f;
    if (e.radiusX < 0.5f || e.radiusY < 0.5f) return;
    RT_V(w->ctx, DrawEllipse, &e, (ID2D1Brush *)br, sw, g_stroke_flat);
}

/* 圆弧：角度制，0°=+x 轴，正角度顺时针（屏幕 y 向下）；a0→a1 */
void zfy_gui_arc(int32_t cx, int32_t cy, int32_t r, double a0, double a1,
                 uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || r <= 0) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    double th0 = a0 * 3.14159265358979323846 / 180.0;  /* 角度 → 弧度（rad0/rad1 与 dlgs.h 宏冲突，避开） */
    double th1 = a1 * 3.14159265358979323846 / 180.0;
    double span = a1 - a0;
    while (span >= 360.0) span -= 360.0;
    while (span <= -360.0) span += 360.0;
    if (span == 0.0) return;
    ID2D1PathGeometry *pg = NULL;
    ID2D1GeometrySink *sink = NULL;
    if (FAILED(FACT(g_d2d_fct, CreatePathGeometry, &pg))) return;
    if (FAILED(PG(pg, Open, &sink))) { REL(pg); return; }
    D2D1_POINT_2F start;
    start.x = (float)(cx + r * cos(th0));
    start.y = (float)(cy + r * sin(th0));
    SINK(sink, BeginFigure, start, D2D1_FIGURE_BEGIN_HOLLOW);
    D2D1_ARC_SEGMENT seg;
    seg.point.x = (float)(cx + r * cos(th1));
    seg.point.y = (float)(cy + r * sin(th1));
    seg.size.width = (float)r; seg.size.height = (float)r;
    seg.rotationAngle = 0.0f;
    seg.sweepDirection = span > 0.0 ? D2D1_SWEEP_DIRECTION_CLOCKWISE
                                    : D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE;
    seg.arcSize = (span > 180.0 || span < -180.0) ? D2D1_ARC_SIZE_LARGE : D2D1_ARC_SIZE_SMALL;
    SINK2(sink, AddArc, &seg);
    SINK(sink, EndFigure, D2D1_FIGURE_END_OPEN);
    SINK_CLOSE(sink);
    REL(sink);
    float sw = (float)(width > 0 ? width : 1);
    RT_V(w->ctx, DrawGeometry, (ID2D1Geometry *)pg, (ID2D1Brush *)br, sw, g_stroke_flat);
    REL(pg);
}

/* 多边形：pts 为 x,y 交错整数数组（物理像素），n 为点数 */
static ID2D1PathGeometry *gui_poly_geo(int32_t *pts, int32_t n, int closed) {
    if (!pts || n < 2) return NULL;
    ID2D1PathGeometry *pg = NULL;
    ID2D1GeometrySink *sink = NULL;
    if (FAILED(FACT(g_d2d_fct, CreatePathGeometry, &pg))) return NULL;
    if (FAILED(PG(pg, Open, &sink))) { REL(pg); return NULL; }
    SINK(sink, BeginFigure, (D2D1_POINT_2F){ (float)pts[0], (float)pts[1] },
         closed ? D2D1_FIGURE_BEGIN_FILLED : D2D1_FIGURE_BEGIN_HOLLOW);
    for (int i = 1; i < n; i++)
        SINK2(sink, AddLine, (D2D1_POINT_2F){ (float)pts[i * 2], (float)pts[i * 2 + 1] });
    SINK(sink, EndFigure, closed ? D2D1_FIGURE_END_CLOSED : D2D1_FIGURE_END_OPEN);
    SINK_CLOSE(sink);
    REL(sink);
    return pg;
}

void zfy_gui_fill_poly(int32_t *pts, int32_t n, uint32_t argb) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    ID2D1PathGeometry *pg = gui_poly_geo(pts, n, 1);
    if (!pg) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (br) gui_draw_geo_brush(w, (ID2D1Geometry *)pg, (ID2D1Brush *)br, 0.0f);
    REL(pg);
}

void zfy_gui_stroke_poly(int32_t *pts, int32_t n, uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    ID2D1PathGeometry *pg = gui_poly_geo(pts, n, 0);
    if (!pg) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (br) gui_draw_geo_brush(w, (ID2D1Geometry *)pg, (ID2D1Brush *)br,
                               (float)(width > 0 ? width : 1));
    REL(pg);
}

/* 二次贝塞尔（一个控制点） */
void zfy_gui_bezier(int32_t x0, int32_t y0, int32_t cx, int32_t cy,
                    int32_t x1, int32_t y1, uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    ID2D1PathGeometry *pg = NULL;
    ID2D1GeometrySink *sink = NULL;
    if (FAILED(FACT(g_d2d_fct, CreatePathGeometry, &pg))) return;
    if (FAILED(PG(pg, Open, &sink))) { REL(pg); return; }
    SINK(sink, BeginFigure, (D2D1_POINT_2F){ (float)x0, (float)y0 }, D2D1_FIGURE_BEGIN_HOLLOW);
    D2D1_BEZIER_SEGMENT seg;
    seg.point1.x = (float)cx; seg.point1.y = (float)cy;
    seg.point2.x = (float)cx; seg.point2.y = (float)cy;
    seg.point3.x = (float)x1; seg.point3.y = (float)y1;
    SINK2(sink, AddBezier, &seg);
    SINK(sink, EndFigure, D2D1_FIGURE_END_OPEN);
    SINK_CLOSE(sink);
    REL(sink);
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (br) gui_draw_geo_brush(w, (ID2D1Geometry *)pg, (ID2D1Brush *)br,
                               (float)(width > 0 ? width : 1));
    REL(pg);
}

/* ---------- 文本 ---------- */

static IDWriteTextLayout *gui_make_layout(gui_win *w, const wchar_t *txt, int len,
                                          IDWriteTextFormat *fmt) {
    IDWriteTextLayout *lay = NULL;
    if (!fmt) return NULL;
    if (FAILED(IDWriteFactory_CreateTextLayout(g_dw, txt, (UINT32)len, fmt,
                                               100000.0f, 100000.0f, &lay)))
        return NULL;
    IDWriteTextLayout_SetWordWrapping(lay, DWRITE_WORD_WRAPPING_NO_WRAP);
    (void)w;
    return lay;
}

/* 设置当前默认文本样式：family 空串 = 微软雅黑；weight 400/700 等；italic 非 0 斜体 */
void zfy_gui_font_ex(char *family_utf8, int32_t px, int32_t weight, int32_t italic) {
    gui_win *w = g_cur;
    if (!w) return;
    if (px <= 0) px = 16;
    if (weight < 100) weight = 400;
    if (weight > 950) weight = 700;
    if (family_utf8 && family_utf8[0]) {
        strncpy(w->tf_family, family_utf8, sizeof(w->tf_family) - 1);
        w->tf_family[sizeof(w->tf_family) - 1] = 0;
    } else {
        strncpy(w->tf_family, "Microsoft YaHei UI", sizeof(w->tf_family) - 1);
        w->tf_family[sizeof(w->tf_family) - 1] = 0;
    }
    w->tf_px = px;
    w->tf_weight = weight;
    w->tf_italic = italic ? 1 : 0;
}

/* 兼容旧形态：px 逻辑像素，bold 非 0 → 700 */
void zfy_gui_font(int32_t px, int32_t bold) {
    zfy_gui_font_ex(NULL, px, bold ? 700 : 400, 0);
}

void zfy_gui_draw_text(int32_t tx, int32_t ty, char *utf8, uint32_t argb) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (fmt && br) {
        IDWriteTextLayout *lay = gui_make_layout(w, wt, (int)wcslen(wt), fmt);
        if (lay) {
            D2D1_POINT_2F po;
            po.x = (float)tx; po.y = (float)ty;
            RT_V(w->ctx, DrawTextLayout, po, lay, (ID2D1Brush *)br, D2D1_DRAW_TEXT_OPTIONS_NONE);
            REL(lay);
        }
    }
    free(wt);
}

/* UTF-8 字节偏移 → UTF-16 码元下标（富文本 run 换算用） */
static int gui_u8_to_u16(const char *s, int off) {
    int i = 0, n = 0;
    while (i < off && s[i]) {
        unsigned char c = (unsigned char)s[i];
        int step;
        if (c < 0x80) step = 1;
        else if ((c & 0xE0) == 0xC0) step = 2;
        else if ((c & 0xF0) == 0xE0) step = 3;
        else if ((c & 0xF8) == 0xF0) step = 4;
        else step = 1;
        i += step;
        n++;
    }
    return n;
}

/* 富文本：runs 每段 6 个 i64 = {起始字节偏移, 字节长度, 0xAARRGGBB,
   字重(0=用当前默认), 斜体(0/1), 字号偏移(逻辑 px，可负)}；未覆盖部分白色 */
void zfy_gui_draw_text_rich(int32_t tx, int32_t ty, char *utf8,
                            int64_t *runs, int32_t runs_len) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    int wlen = (int)wcslen(wt);
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    if (!fmt || wlen <= 0) { free(wt); return; }
    IDWriteTextLayout *lay = gui_make_layout(w, wt, wlen, fmt);
    if (!lay) { free(wt); return; }
    for (int i = 0; i < runs_len; i++) {
        int64_t *r = runs + i * 6;
        int start = gui_u8_to_u16(utf8 ? utf8 : "", (int)r[0]);
        int len = gui_u8_to_u16(utf8 ? utf8 : "", (int)(r[0] + r[1])) - start;
        if (start < 0) start = 0;
        if (start >= wlen || len <= 0) continue;
        if (start + len > wlen) len = wlen - start;
        DWRITE_TEXT_RANGE range;
        range.startPosition = (UINT32)start;
        range.length = (UINT32)len;
        if (r[3] >= 100 && r[3] <= 950)
            IDWriteTextLayout_SetFontWeight(lay, (DWRITE_FONT_WEIGHT)r[3], range);
        if (r[4])
            IDWriteTextLayout_SetFontStyle(lay, DWRITE_FONT_STYLE_ITALIC, range);
        if (r[5] != 0) {
            float base = (float)(w->tf_px * w->dpi / 96);
            float sz = base + (float)(r[5] * w->dpi / 96);
            if (sz < 1.0f) sz = 1.0f;
            IDWriteTextLayout_SetFontSize(lay, sz, range);
        }
        ID2D1SolidColorBrush *br = gui_brush(w, (uint32_t)r[2]);
        if (br) IDWriteTextLayout_SetDrawingEffect(lay, (IUnknown *)br, range);
    }
    ID2D1SolidColorBrush *fallback = gui_brush(w, 0xFFFFFFFF);
    if (fallback) {
        D2D1_POINT_2F po;
        po.x = (float)tx; po.y = (float)ty;
        RT_V(w->ctx, DrawTextLayout, po, lay, (ID2D1Brush *)fallback, D2D1_DRAW_TEXT_OPTIONS_NONE);
    }
    REL(lay);
    free(wt);
}

/* 文本像素宽度（DirectWrite 度量，物理像素；无窗口时 0） */
int32_t zfy_gui_text_w(char *utf8) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return 0;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    IDWriteTextLayout *lay = fmt ? gui_make_layout(w, wt, (int)wcslen(wt), fmt) : NULL;
    int32_t v = 0;
    if (lay) {
        DWRITE_TEXT_METRICS tm;
        if (SUCCEEDED(IDWriteTextLayout_GetMetrics(lay, &tm)))
            v = (int32_t)(tm.widthIncludingTrailingWhitespace + 0.999f);
        REL(lay);
    }
    free(wt);
    return v;
}

/* 文本像素高度（行高，物理像素） */
int32_t zfy_gui_text_h(char *utf8) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return 0;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    IDWriteTextLayout *lay = fmt ? gui_make_layout(w, wt, (int)wcslen(wt), fmt) : NULL;
    int32_t v = 0;
    if (lay) {
        DWRITE_TEXT_METRICS tm;
        if (SUCCEEDED(IDWriteTextLayout_GetMetrics(lay, &tm)))
            v = (int32_t)(tm.height + 0.999f);
        REL(lay);
    }
    free(wt);
    return v;
}

/* 文本度量四元组：宽/高/基线以上/基线以下（物理像素） */
void zfy_gui_text_metrics(char *utf8, int32_t *pw, int32_t *ph, int32_t *pa, int32_t *pd) {
    if (pw) *pw = 0;
    if (ph) *ph = 0;
    if (pa) *pa = 0;
    if (pd) *pd = 0;
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    IDWriteTextLayout *lay = fmt ? gui_make_layout(w, wt, (int)wcslen(wt), fmt) : NULL;
    if (lay) {
        DWRITE_TEXT_METRICS tm;
        DWRITE_LINE_METRICS lm[4];
        UINT32 got = 0;
        if (SUCCEEDED(IDWriteTextLayout_GetMetrics(lay, &tm)) && pw) {
            *pw = (int32_t)(tm.widthIncludingTrailingWhitespace + 0.999f);
            if (ph) *ph = (int32_t)(tm.height + 0.999f);
        }
        if (SUCCEEDED(IDWriteTextLayout_GetLineMetrics(lay, lm, 4, &got)) && got > 0) {
            /* 行度量只给行高与基线位置：基线以上 = baseline，以下 = height - baseline */
            if (pa) *pa = (int32_t)(lm[0].baseline + 0.999f);
            if (pd) *pd = (int32_t)((lm[0].height - lm[0].baseline) + 0.999f);
        }
        REL(lay);
    }
    free(wt);
}

/* ---------- 透明度 / 混合模式 ---------- */
void zfy_gui_set_alpha(int32_t alpha) {
    if (!g_cur) return;
    if (alpha < 0) alpha = 0;
    if (alpha > 255) alpha = 255;
    g_cur->alpha = alpha;
    gui_br_flush(g_cur);               /* 画刷键含有效 alpha，需整体失效 */
}
void zfy_gui_reset_alpha(void) {
    if (!g_cur) return;
    g_cur->alpha = 255;
    gui_br_flush(g_cur);
}
void zfy_gui_set_blend(int32_t mode) {
    if (!g_cur) return;
    if (mode < 0 || mode > 4) mode = 0;
    g_cur->blend = mode;
}

/* 阅读方向（RTL 国际化文本）：1=右到左，0=左到右。切换后下次取文本格式
   会命中另一缓存键（rtl 是 key 的一部分），DirectWrite 重新按新方向排版。 */
void zfy_gui_set_rtl(int32_t on) {
    if (!g_cur) return;
    g_cur->rtl = on ? 1 : 0;
}

/* ---------- 裁剪 / 变换 ---------- */
void zfy_gui_push_clip(int32_t x, int32_t y, int32_t cw, int32_t ch) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (w->clip_n >= GUI_CLIP_STACK - 1) return;
    D2D1_RECT_F r;
    r.left = (float)x; r.top = (float)y;
    r.right = (float)(x + cw); r.bottom = (float)(y + ch);
    if (r.right < r.left) { float t = r.left; r.left = r.right; r.right = t; }
    if (r.bottom < r.top) { float t = r.top; r.top = r.bottom; r.bottom = t; }
    RT_V(w->ctx, PushAxisAlignedClip, &r, D2D1_ANTIALIAS_MODE_ALIASED);
    w->clip_n++;
}
void zfy_gui_pop_clip(void) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || w->clip_n <= 0) return;
    RT_V(w->ctx, PopAxisAlignedClip);
    w->clip_n--;
}
void zfy_gui_push_translate(int32_t dx, int32_t dy) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || w->xf_n >= GUI_XF_STACK - 1) return;
    /* 读回当前变换，压栈后左乘平移 */
    D2D1_MATRIX_3X2_F cur;
    RT_V(w->ctx, GetTransform, &cur);
    w->xf[w->xf_n] = cur;
    w->xf_n++;
    cur._31 += (float)dx;
    cur._32 += (float)dy;
    RT_V(w->ctx, SetTransform, &cur);
}
void zfy_gui_pop_transform(void) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || w->xf_n <= 0) return;
    w->xf_n--;
    RT_V(w->ctx, SetTransform, &w->xf[w->xf_n]);
}

/* ---------- 位图（WIC 加载 / 内存构建） ---------- */
static int64_t gui_img_alloc(ID2D1Bitmap1 *bmp, int w, int h) {
    for (int i = 0; i < GUI_IMG_SLOTS; i++) {
        if (!g_imgs[i].used) {
            g_imgs[i].bmp = bmp;
            g_imgs[i].w = w;
            g_imgs[i].h = h;
            g_imgs[i].used = 1;
            return (int64_t)(i + 1);
        }
    }
    return 0;
}
static gui_img *gui_img_of(int64_t h) {
    if (h < 1 || h > GUI_IMG_SLOTS) return NULL;
    gui_img *g = &g_imgs[h - 1];
    return g->used ? g : NULL;
}

/* 加载 PNG/JPG/BMP/GIF（首帧）→ 32bppPBGRA 位图；返回句柄 >0，失败 0 */
int64_t zfy_gui_image_load(char *path_utf8) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || !g_wic || !path_utf8) return 0;
    wchar_t *wp = gui_utf8_to_wide(path_utf8);
    IWICBitmapDecoder *dec = NULL;
    IWICBitmapFrameDecode *fr = NULL;
    IWICFormatConverter *conv = NULL;
    ID2D1Bitmap1 *bmp = NULL;
    HRESULT hr = IWICImagingFactory_CreateDecoderFromFilename(g_wic, wp, NULL, GENERIC_READ,
                                                              WICDecodeMetadataCacheOnDemand, &dec);
    if (SUCCEEDED(hr) && dec) hr = IWICBitmapDecoder_GetFrame(dec, 0, &fr);
    if (SUCCEEDED(hr) && fr && g_wic) {
        hr = IWICImagingFactory_CreateFormatConverter(g_wic, &conv);
        if (SUCCEEDED(hr) && conv)
            hr = IWICFormatConverter_Initialize(conv, (IWICBitmapSource *)fr,
                                                &GUID_WICPixelFormat32bppPBGRA,
                                                WICBitmapDitherTypeNone, NULL, 0.0,
                                                WICBitmapPaletteTypeCustom);
    }
    if (SUCCEEDED(hr) && conv)
        hr = DC_V(w->ctx, CreateBitmapFromWicBitmap, (IWICBitmapSource *)conv, NULL, &bmp);
    int iw = 0, ih = 0;
    if (bmp) {
        D2D1_SIZE_U ps = BM_V(bmp, GetPixelSize);
        iw = (int)ps.width; ih = (int)ps.height;
    }
    REL(conv);
    REL(fr);
    REL(dec);
    free(wp);
    if (!bmp) return 0;
    int64_t h = gui_img_alloc(bmp, iw, ih);
    if (h == 0) REL(bmp);
    return h;
}

int32_t zfy_gui_image_w(int64_t h) {
    gui_img *g = gui_img_of(h);
    return g ? g->w : 0;
}
int32_t zfy_gui_image_h(int64_t h) {
    gui_img *g = gui_img_of(h);
    return g ? g->h : 0;
}

void zfy_gui_image_free(int64_t h) {
    gui_img *g = gui_img_of(h);
    if (!g) return;
    REL(g->bmp);
    memset(g, 0, sizeof(*g));
}

/* 缩放绘制：alpha 0..255 叠加在全局 alpha 之上 */
void zfy_gui_draw_image(int64_t h, int32_t x, int32_t y, int32_t dw, int32_t dh, int32_t alpha) {
    gui_win *w = g_cur;
    gui_img *g = gui_img_of(h);
    if (!w || !w->ctx || !g) return;
    if (dw <= 0 || dh <= 0) return;
    if (alpha < 0) alpha = 0;
    if (alpha > 255) alpha = 255;
    float op = (float)alpha / 255.0f * (float)w->alpha / 255.0f;
    D2D1_RECT_F dest;
    dest.left = (float)x; dest.top = (float)y;
    dest.right = (float)(x + dw); dest.bottom = (float)(y + dh);
    RT_V(w->ctx, DrawBitmap, (ID2D1Bitmap *)g->bmp, &dest, op,
          D2D1_BITMAP_INTERPOLATION_MODE_LINEAR, NULL);
}

/* 子区域绘制（精灵表/九宫格） */
void zfy_gui_draw_image_sub(int64_t h, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
                            int32_t dx, int32_t dy, int32_t dw, int32_t dh, int32_t alpha) {
    gui_win *w = g_cur;
    gui_img *g = gui_img_of(h);
    if (!w || !w->ctx || !g) return;
    if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return;
    if (alpha < 0) alpha = 0;
    if (alpha > 255) alpha = 255;
    float op = (float)alpha / 255.0f * (float)w->alpha / 255.0f;
    D2D1_RECT_F dest;
    dest.left = (float)dx; dest.top = (float)dy;
    dest.right = (float)(dx + dw); dest.bottom = (float)(dy + dh);
    D2D1_RECT_F src;
    src.left = (float)sx; src.top = (float)sy;
    src.right = (float)(sx + sw); src.bottom = (float)(sy + sh);
    RT_V(w->ctx, DrawBitmap, (ID2D1Bitmap *)g->bmp, &dest, op,
          D2D1_BITMAP_INTERPOLATION_MODE_LINEAR, &src);
}

/* 从内存 RGBA 缓冲（非预乘，4 字节/像素）构建位图 */
int64_t zfy_gui_image_from_rgba(void *px, int32_t wpx, int32_t hpx, int32_t stride) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || !px || wpx <= 0 || hpx <= 0) return 0;
    if (stride <= 0) stride = wpx * 4;
    unsigned char *bg = (unsigned char *)malloc((size_t)wpx * (size_t)hpx * 4);
    if (!bg) return 0;
    const unsigned char *src = (const unsigned char *)px;
    for (int y = 0; y < hpx; y++) {
        const unsigned char *s = src + (size_t)y * (size_t)stride;
        unsigned char *d = bg + (size_t)y * (size_t)wpx * 4;
        for (int x = 0; x < wpx; x++) {
            unsigned char a = s[x * 4 + 3];
            /* RGBA(非预乘) → BGRA(预乘)：alpha 乘入各通道 */
            unsigned int pr = (unsigned int)s[x * 4 + 0] * a / 255u;
            unsigned int pg = (unsigned int)s[x * 4 + 1] * a / 255u;
            unsigned int pb = (unsigned int)s[x * 4 + 2] * a / 255u;
            d[x * 4 + 0] = (unsigned char)pb;
            d[x * 4 + 1] = (unsigned char)pg;
            d[x * 4 + 2] = (unsigned char)pr;
            d[x * 4 + 3] = a;
        }
    }
    D2D1_BITMAP_PROPERTIES1 bp;
    memset(&bp, 0, sizeof(bp));
    bp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    bp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    bp.dpiX = 96; bp.dpiY = 96;
    bp.bitmapOptions = D2D1_BITMAP_OPTIONS_NONE;
    D2D1_SIZE_U sz;
    sz.width = (UINT32)wpx; sz.height = (UINT32)hpx;
    ID2D1Bitmap1 *bmp = NULL;
    HRESULT hr = DC_V(w->ctx, CreateBitmap, sz, bg, (UINT32)(wpx * 4), &bp, &bmp);
    free(bg);
    if (FAILED(hr) || !bmp) return 0;
    int64_t h = gui_img_alloc(bmp, wpx, hpx);
    if (h == 0) REL(bmp);
    return h;
}

#else
/* 非 Windows：桩实现（返回失败，UI 程序可优雅降级为 TUI） */
int32_t zfy_gui_open(int32_t w, int32_t h, char *t) { (void)w; (void)h; (void)t; return -1; }
/* 无障碍（UIA）在非 Windows 上不可用：全部桩化，zfy 侧可无差别调用 */
void zfy_a11y_begin(int64_t win) { (void)win; }
void zfy_a11y_push_node(int64_t win, int64_t idx, char *name, char *role, char *value,
                        int32_t states, int32_t x, int32_t y, int32_t w, int32_t h,
                        int32_t parent) {
    (void)win; (void)idx; (void)name; (void)role; (void)value; (void)states;
    (void)x; (void)y; (void)w; (void)h; (void)parent;
}
void zfy_a11y_end(void) {}
void zfy_a11y_set_focus(int64_t idx) { (void)idx; }
int64_t zfy_a11y_hit(int32_t x, int32_t y) { (void)x; (void)y; return -1; }
int32_t zfy_gui_a11y_take_value(int64_t idx, char *buf, int32_t cap) {
    (void)idx; (void)buf; (void)cap; return 0;
}
int32_t zfy_gui_poll(int64_t *t, int64_t *x, int64_t *y, int64_t *k) { (void)t; (void)x; (void)y; (void)k; return 0; }
int32_t zfy_gui_alive(void) { return 0; }
int32_t zfy_gui_should_close(void) { return 1; }
int32_t zfy_gui_w(void) { return 0; }
int32_t zfy_gui_h(void) { return 0; }
int32_t zfy_gui_dpi(void) { return 96; }
int32_t zfy_gui_clip_get(char *buf, int32_t cap) { (void)buf; (void)cap; return -1; }
void zfy_gui_clip_set(char *utf8) { (void)utf8; }
void zfy_gui_close(void) {}
void zfy_gui_title(char *s) { (void)s; }
void zfy_gui_font(int32_t a, int32_t b) { (void)a; (void)b; }
void zfy_gui_font_ex(char *f, int32_t p, int32_t w, int32_t i) { (void)f; (void)p; (void)w; (void)i; }
void zfy_gui_round_rect(int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, uint32_t f, uint32_t g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
void zfy_gui_line(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e, int32_t w) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)w; }
void zfy_gui_fill_grad(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e, uint32_t f, int32_t g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
int32_t zfy_gui_alive_any(void) { return 0; }
int32_t zfy_gui_self(void) { return 0; }
void zfy_gui_select(int64_t id) { (void)id; }
void zfy_gui_set_icon(char *s) { (void)s; }
void zfy_gui_present(void) {}
void zfy_gui_fill_rect(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e) { (void)a; (void)b; (void)c; (void)d; (void)e; }
void zfy_gui_stroke_rect(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e, int32_t w) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)w; }
void zfy_gui_draw_text(int32_t a, int32_t b, char *s, uint32_t c) { (void)a; (void)b; (void)s; (void)c; }
void zfy_gui_draw_text_rich(int32_t a, int32_t b, char *s, int64_t *r, int32_t n) { (void)a; (void)b; (void)s; (void)r; (void)n; }
int32_t zfy_gui_text_w(char *s) { (void)s; return 0; }
int32_t zfy_gui_text_h(char *s) { (void)s; return 0; }
void zfy_gui_text_metrics(char *s, int32_t *w, int32_t *h, int32_t *a, int32_t *d) { (void)s; (void)h; (void)a; (void)d; if (w) *w = 0; }
void zfy_gui_fill_circle(int32_t cx, int32_t cy, int32_t r, uint32_t c) { (void)cx; (void)cy; (void)r; (void)c; }
void zfy_gui_stroke_circle(int32_t cx, int32_t cy, int32_t r, uint32_t c, int32_t w) { (void)cx; (void)cy; (void)r; (void)c; (void)w; }
void zfy_gui_arc(int32_t cx, int32_t cy, int32_t r, double a0, double a1, uint32_t c, int32_t w) { (void)cx; (void)cy; (void)r; (void)a0; (void)a1; (void)c; (void)w; }
void zfy_gui_fill_poly(int32_t *p, int32_t n, uint32_t c) { (void)p; (void)n; (void)c; }
void zfy_gui_stroke_poly(int32_t *p, int32_t n, uint32_t c, int32_t w) { (void)p; (void)n; (void)c; (void)w; }
void zfy_gui_bezier(int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, uint32_t g, int32_t h) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; }
void zfy_gui_set_alpha(int32_t a) { (void)a; }
void zfy_gui_reset_alpha(void) {}
void zfy_gui_set_blend(int32_t m) { (void)m; }
void zfy_gui_set_rtl(int32_t on) { (void)on; }
void zfy_gui_push_clip(int32_t a, int32_t b, int32_t c, int32_t d) { (void)a; (void)b; (void)c; (void)d; }
void zfy_gui_pop_clip(void) {}
void zfy_gui_push_translate(int32_t a, int32_t b) { (void)a; (void)b; }
void zfy_gui_pop_transform(void) {}
int64_t zfy_gui_image_load(char *p) { (void)p; return 0; }
int32_t zfy_gui_image_w(int64_t h) { (void)h; return 0; }
int32_t zfy_gui_image_h(int64_t h) { (void)h; return 0; }
void zfy_gui_draw_image(int64_t h, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e) { (void)h; (void)a; (void)b; (void)c; (void)d; (void)e; }
void zfy_gui_draw_image_sub(int64_t h, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, int32_t g, int32_t i, int32_t j) { (void)h; (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)i; (void)j; }
void zfy_gui_image_free(int64_t h) { (void)h; }
int64_t zfy_gui_image_from_rgba(void *p, int32_t w, int32_t h, int32_t s) { (void)p; (void)w; (void)h; (void)s; return 0; }
#endif

/* ==================================================================
 * 并发（v3.8.0）：线程 / 互斥锁 / 原子操作 / channel
 * 约定：
 *   - 线程/互斥/channel 句柄 = 单 ptr 字段 struct（{ptr h}），
 *     操作函数收槽地址（void**）解一层取 h（与 map 同款）；
 *   - spawn 收闭包句柄（解一层 = env 块地址，首字段 = code），
 *     线程体调 code(env) 后释放 env 堆块（v3.27 P0-1c：env 所有权
 *     随 spawn 移交线程，线程侧释放；编译器保证 spawn 后宿主不再使用）；
 *   - 原子操作直接作用于变量地址（&g 取址），限 32/64 位整型；
 *   - channel 为无界队列（send 不阻塞），recv 阻塞直至有值或
 *     关闭且排空（后者产 NOT_FOUND 错误值，与 map 缺键同款）；
 *   - 句柄 RAII（v3.27 P0-1a）：作用域退出由编译器发 zfy_mutex_free /
 *     zfy_chan_free（chan free 前未 close 则终止）；全局句柄登记到
 *     资源注册表（zfy_global_reg），atexit 统一释放（P0-1d）；
 *   - join 后句柄置 null（重复 join 报错）；map/列表等容器
 *     非线程安全，跨线程共享须用 mutex 外部保护。
 * ================================================================== */
#if defined(_WIN32) && !defined(ZFY_FREESTANDING)
#include <process.h>

/* ---- 线程 ---- */
typedef struct {
    void *env;
    void (*dtor)(void *);                /* env 析构器（zfy_env_free：块内 dtor + rc + free） */
} zfy_thr_pack;

static unsigned __stdcall zfy_thr_proc_d(void *p) {
    zfy_thr_pack *pk = (zfy_thr_pack *)p;
    void *env = pk->env;
    void (*dtor)(void *) = pk->dtor;
    free(pk);
    void *code = *(void **)env;
    ((void (*)(void *))code)(env);
    if (dtor) dtor(env);                 /* P0-1c：dtor（zfy_env_free）自带块内 dtor 分派 */
    else zfy_env_free(env);              /* 无 dtor：env 自描述析构（rc 归零语义） */
    return 0;
}

static unsigned __stdcall zfy_thr_proc(void *p) {
    void *env = p;                       /* env 块：首字段 = code */
    void *code = *(void **)env;
    ((void (*)(void *))code)(env);
    zfy_env_free(env);                   /* P0-1c：env 所有权随 spawn 移交，线程侧释放 */
    return 0;
}
void zfy_thread_spawn(void **out, void *clo_slot) {
    void *env = *(void **)clo_slot;      /* 闭包句柄解一层 = env 块 */
    uintptr_t th = _beginthreadex(NULL, 0, zfy_thr_proc, env, 0, NULL);
    if (th == 0) zfy_die("spawn: 线程创建失败");
    *out = (void *)th;
}
/* 带析构器版（P0-1c）：dtor 在线程体结束后调用（级联释放捕获的
 * string/seq 副本再 free env 块，零泄漏）；dtor 为 NULL 时仅 free */
void zfy_thread_spawn_d(void **out, void *clo_slot, void (*dtor)(void *)) {
    void *env = *(void **)clo_slot;
    zfy_thr_pack *pk = (zfy_thr_pack *)malloc(sizeof(zfy_thr_pack));
    if (!pk) zfy_die("spawn: 分配失败");
    pk->env = env;
    pk->dtor = dtor;
    uintptr_t th = _beginthreadex(NULL, 0, zfy_thr_proc_d, pk, 0, NULL);
    if (th == 0) zfy_die("spawn: 线程创建失败");
    *out = (void *)th;
}
/* 幂等 join（v3.31）：句柄已空（已 join/已 detach/已 free）时直接返回，
 * 第二次 join 为已完成的空操作 */
void zfy_thread_join(void **slot) {
    void *h = *slot;
    if (!h) return;
    WaitForSingleObject((HANDLE)h, INFINITE);
    CloseHandle((HANDLE)h);
    *slot = NULL;
}
/* 分离（v3.31）：detach(t) 只放弃句柄所有权、不等待线程结束；
 * 线程体继续独立执行，结束后由 _endthreadex 回收线程资源 */
void zfy_thread_detach(void **slot) {
    void *h = *slot;
    if (!h) return;
    CloseHandle((HANDLE)h);
    *slot = NULL;
}
/* 句柄 RAII（P0-1a）：作用域退出未 join 的线程句柄——句柄本身不持堆
 * 资源（env 已移交线程自释放），只 CloseHandle 防句柄泄漏 */
void zfy_thread_free(void **slot) {
    void *h = *slot;
    if (h) {
        CloseHandle((HANDLE)h);
        *slot = NULL;
    }
}

/* ---- 互斥锁（CRITICAL_SECTION） ---- */
void zfy_mutex_new(void **out) {
    CRITICAL_SECTION *cs = (CRITICAL_SECTION *)zfy_rc_alloc(sizeof(CRITICAL_SECTION));
    InitializeCriticalSection(cs);
    *out = cs;
}
void zfy_mutex_lock(void **slot) {
    void *h = *slot;
    if (!h) zfy_die("lock: 互斥锁未初始化（先 mutex_new）");
    EnterCriticalSection((CRITICAL_SECTION *)h);
}
void zfy_mutex_unlock(void **slot) {
    void *h = *slot;
    if (!h) zfy_die("unlock: 互斥锁未初始化（先 mutex_new）");
    LeaveCriticalSection((CRITICAL_SECTION *)h);
}
/* rc 归零 dtor：销毁 CS（引用计数 P0-1a——assign 浅拷共享同一 CS） */
static void zfy_mutex_dtor(void *h) {
    DeleteCriticalSection((CRITICAL_SECTION *)h);
}
/* 句柄 RAII（P0-1a）：作用域退出释放互斥锁（持锁释放 = 死锁隐患，
 * 编译器保证 lock 块先行回卷；防御性再查一次）。引用计数释放 */
void zfy_mutex_free(void **slot) {
    void *h = *slot;
    *slot = NULL;
    zfy_rc_release(h, zfy_mutex_dtor);
}

/* ---- 原子操作（作用于变量地址；返回旧值语义与
 * Interlocked 家族一致：add 返回加前旧值） ---- */
int32_t zfy_atomic_load_32(void *p) {
    return InterlockedCompareExchange((volatile long *)p, 0, 0);
}
void zfy_atomic_store_32(void *p, int32_t v) {
    InterlockedExchange((volatile long *)p, (long)v);
}
int32_t zfy_atomic_add_32(void *p, int32_t v) {
    return (int32_t)InterlockedExchangeAdd((volatile long *)p, (long)v);
}
int64_t zfy_atomic_load_64(void *p) {
    return InterlockedCompareExchange64((volatile long long *)p, 0, 0);
}
void zfy_atomic_store_64(void *p, int64_t v) {
    InterlockedExchange64((volatile long long *)p, v);
}
int64_t zfy_atomic_add_64(void *p, int64_t v) {
    return InterlockedExchangeAdd64((volatile long long *)p, v);
}

/* 原子自增（void 返回：语句级可用，免值丢弃检查） */
void zfy_atomic_inc_32(void *p) {
    InterlockedExchangeAdd((volatile long *)p, 1);
}
void zfy_atomic_inc_64(void *p) {
    InterlockedExchangeAdd64((volatile long long *)p, 1);
}

/* ---- 睡眠 ---- */
void zfy_sleep_ms(long long ms) { Sleep((DWORD)ms); }

/* ---- channel：无界队列（链表）+ CS/CONDVAR ---- */
typedef struct zfy_chan_node {
    struct zfy_chan_node *next;
    long long i;                         /* 标量值 / f32/f64 位模式 */
    void *p;                             /* string 堆串（接管所有权） */
} zfy_chan_node;
typedef struct {
    CRITICAL_SECTION cs;
    CONDITION_VARIABLE cv;
    zfy_chan_node *head, *tail;
    long long len;
    int closed;
} zfy_chan;

void zfy_chan_new(void **out) {
    zfy_chan *c = (zfy_chan *)zfy_rc_alloc(sizeof(zfy_chan));
    InitializeCriticalSection(&c->cs);
    InitializeConditionVariable(&c->cv);
    c->head = c->tail = NULL;
    c->len = 0;
    c->closed = 0;
    *out = c;
}
static void chan_push(zfy_chan *c, long long i, void *p) {
    zfy_chan_node *n = (zfy_chan_node *)malloc(sizeof(zfy_chan_node));
    if (!n) zfy_die("chan_send: 分配失败");
    n->next = NULL;
    n->i = i;
    n->p = p;
    EnterCriticalSection(&c->cs);
    if (c->closed) {
        LeaveCriticalSection(&c->cs);
        free(n);
        if (p) free(p);
        zfy_die("chan_send: channel 已关闭");
    }
    if (c->tail) c->tail->next = n; else c->head = n;
    c->tail = n;
    c->len++;
    LeaveCriticalSection(&c->cs);
    WakeConditionVariable(&c->cv);
}
void zfy_chan_send_i64(void **slot, long long v) { chan_push((zfy_chan *)*slot, v, NULL); }
void zfy_chan_send_f32(void **slot, float v) {
    long long b = 0; memcpy(&b, &v, 4);
    chan_push((zfy_chan *)*slot, b, NULL);
}
void zfy_chan_send_f64(void **slot, double v) {
    long long b = 0; memcpy(&b, &v, 8);
    chan_push((zfy_chan *)*slot, b, NULL);
}
void zfy_chan_send_str(void **slot, char *v) {
    chan_push((zfy_chan *)*slot, 0, zfy_strdup(v));   /* 深拷贝，队列接管 */
}

/* 阻塞接收：取出写 *out_i/*out_p（string 转移所有权给调用方）；
 * 返回 1 = 成功，0 = 已关闭且排空（编译器侧据此产 NOT_FOUND） */
static int chan_pop(zfy_chan *c, long long *out_i, void **out_p) {
    EnterCriticalSection(&c->cs);
    while (!c->head && !c->closed)
        SleepConditionVariableCS(&c->cv, &c->cs, INFINITE);
    if (!c->head) {                       /* closed 且排空 */
        LeaveCriticalSection(&c->cs);
        return 0;
    }
    zfy_chan_node *n = c->head;
    c->head = n->next;
    if (!c->head) c->tail = NULL;
    c->len--;
    LeaveCriticalSection(&c->cs);
    *out_i = n->i;
    *out_p = n->p;
    free(n);
    return 1;
}
int zfy_chan_recv_raw(void **slot, long long *out_i, void **out_p) {
    return chan_pop((zfy_chan *)*slot, out_i, out_p);
}

/* 错误值形态 recv（与 map get_err 同款：out = zfy_err* 首参）：
 * 编译器按 vtag 选择具体实例，失败产 NOT_FOUND */
/* recv_err_*：成功时直接把队列节点值写入 out（string 转移所有权，
 * 不经 get_ok_str 二次 strdup 免泄漏）；失败 = NOT_FOUND（closed 且排空） */
void zfy_chan_recv_err_i64(zfy_err *out, void **slot) {
    long long i; void *p;
    if (chan_pop((zfy_chan *)*slot, &i, &p)) err_ok_i(out, (unsigned long long)i);
    else MAP_MISS(out);
}
void zfy_chan_recv_err_f32(zfy_err *out, void **slot) {
    long long i; void *p;
    if (chan_pop((zfy_chan *)*slot, &i, &p)) get_ok_f32(out, (unsigned long long)i);
    else MAP_MISS(out);
}
void zfy_chan_recv_err_f64(zfy_err *out, void **slot) {
    long long i; void *p;
    if (chan_pop((zfy_chan *)*slot, &i, &p)) get_ok_f64(out, (unsigned long long)i);
    else MAP_MISS(out);
}
void zfy_chan_recv_err_str(zfy_err *out, void **slot) {
    long long i; void *p;
    if (chan_pop((zfy_chan *)*slot, &i, &p)) {
        out->code = ZFY_EOK; out->msg = NULL;
        out->value.p = p;             /* 所有权移交（send 时 strdup 过） */
    } else MAP_MISS(out);
}

void zfy_chan_close(void **slot) {
    zfy_chan *c = (zfy_chan *)*slot;
    if (!c) zfy_die("chan_close: channel 未初始化");
    EnterCriticalSection(&c->cs);
    c->closed = 1;
    LeaveCriticalSection(&c->cs);
    WakeAllConditionVariable(&c->cv);
}
long long zfy_chan_len(void **slot) {
    zfy_chan *c = (zfy_chan *)*slot;
    if (!c) zfy_die("chan_len: channel 未初始化");
    EnterCriticalSection(&c->cs);
    long long n = c->len;
    LeaveCriticalSection(&c->cs);
    return n;
}

/* rc 归零 dtor：隐式 close（唤醒对端 recv 使其返回 miss）后丢弃残留
 * 消息节点（收端已无法再取）。不强制显式 close：作用域退出自动回收是
 * P0-1a 的目标语义，未 close 的残留消息属程序放弃的数据，静默清理
 * （string 元素 free 防泄漏） */
static void zfy_chan_dtor(void *v) {
    zfy_chan *c = (zfy_chan *)v;
    EnterCriticalSection(&c->cs);
    c->closed = 1;
    WakeAllConditionVariable(&c->cv);
    zfy_chan_node *n = c->head;
    while (n) {
        zfy_chan_node *nx = n->next;
        if (n->p) free(n->p);
        free(n);
        n = nx;
    }
    c->head = c->tail = NULL;
    LeaveCriticalSection(&c->cs);
    DeleteCriticalSection(&c->cs);
}
/* 句柄 RAII（P0-1a）：引用计数释放——assign 浅拷共享同一 chan（跨
 * 闭包捕获/传参），最后一个持有者归零时才真正回收 */
void zfy_chan_free(void **slot) {
    void *c = *slot;
    *slot = NULL;
    zfy_rc_release(c, zfy_chan_dtor);
}

/* ---- 全局资源注册表（P0-1d）----
 * 全局句柄/闭包 env 等进程级资源在 main 前后由编译器生成的初始化代码
 * 登记（zfy_global_reg），atexit 统一释放——任何退出路径（正常 / panic
 * / handler 自定义退出）都回收，文档可承诺零泄漏。
 * 环境变量 ZFY_LEAK_DEBUG=1 时打印回收清单（Debug 泄漏报告）。 */
typedef struct zfy_gres {
    void **slot;                 /* 资源槽地址（全局变量槽） */
    void (*release)(void **);    /* 释放函数（收槽地址，幂等） */
    const char *name;            /* 诊断用资源名 */
    struct zfy_gres *next;
} zfy_gres;
static zfy_gres *zfy_gres_list = NULL;
static void zfy_gres_atexit(void); /* 前向声明 */

void zfy_global_reg(void **slot, void (*release)(void **), const char *name) {
    static int hooked = 0;
    if (!hooked) {
        hooked = 1;
        atexit(zfy_gres_atexit);
    }
    zfy_gres *g = (zfy_gres *)malloc(sizeof(zfy_gres));
    if (!g) return;                      /* 登记失败降级为不兜底（不致命） */
    g->slot = slot;
    g->release = release;
    g->name = name;
    g->next = zfy_gres_list;
    zfy_gres_list = g;
}

static void zfy_gres_atexit(void) {
    int report = getenv("ZFY_LEAK_DEBUG") != NULL;
    for (zfy_gres *g = zfy_gres_list; g; g = g->next) {
        if (*g->slot) {
            if (report) fprintf(stderr, "[zfy-leak] 回收全局资源 %s\n", g->name);
            g->release(g->slot);
        }
    }
}

#else
/* 非 Windows：桦实现（调用即终止，zfy v1 并发仅支持 Windows） */
void zfy_thread_spawn(void **o, void *c) { (void)o; (void)c; zfy_die("spawn: 仅支持 Windows"); }
void zfy_thread_spawn_d(void **o, void *c, void (*d)(void *)) { (void)o; (void)c; (void)d; zfy_die("spawn: 仅支持 Windows"); }
void zfy_thread_join(void **s) { (void)s; zfy_die("join: 仅支持 Windows"); }
void zfy_thread_detach(void **s) { (void)s; }
void zfy_thread_free(void **s) { (void)s; }
void zfy_mutex_new(void **o) { (void)o; zfy_die("mutex: 仅支持 Windows"); }
void zfy_mutex_lock(void **s) { (void)s; }
void zfy_mutex_unlock(void **s) { (void)s; }
void zfy_mutex_free(void **s) { (void)s; }
#if defined(ZFY_FREESTANDING)
/* 裸机：原子操作走 clang __atomic 内建（无需 OS 互斥原语；atomic 内建在
   freestanding 下仍可用，保持与 Windows Interlocked 相同的旧值语义） */
int32_t zfy_atomic_load_32(void *p) { return __atomic_load_n((int32_t *)p, __ATOMIC_SEQ_CST); }
void zfy_atomic_store_32(void *p, int32_t v) { __atomic_store_n((int32_t *)p, v, __ATOMIC_SEQ_CST); }
int32_t zfy_atomic_add_32(void *p, int32_t v) { return __atomic_fetch_add((int32_t *)p, v, __ATOMIC_SEQ_CST); }
int64_t zfy_atomic_load_64(void *p) { return __atomic_load_n((int64_t *)p, __ATOMIC_SEQ_CST); }
void zfy_atomic_store_64(void *p, int64_t v) { __atomic_store_n((int64_t *)p, v, __ATOMIC_SEQ_CST); }
int64_t zfy_atomic_add_64(void *p, int64_t v) { return __atomic_fetch_add((int64_t *)p, v, __ATOMIC_SEQ_CST); }
void zfy_atomic_inc_32(void *p) { (void)__atomic_fetch_add((int32_t *)p, 1, __ATOMIC_SEQ_CST); }
void zfy_atomic_inc_64(void *p) { (void)__atomic_fetch_add((int64_t *)p, 1, __ATOMIC_SEQ_CST); }
#else
int32_t zfy_atomic_load_32(void *p) { (void)p; return 0; }
void zfy_atomic_store_32(void *p, int32_t v) { (void)p; (void)v; }
int32_t zfy_atomic_add_32(void *p, int32_t v) { (void)p; (void)v; return 0; }
int64_t zfy_atomic_load_64(void *p) { (void)p; return 0; }
void zfy_atomic_store_64(void *p, int64_t v) { (void)p; (void)v; }
int64_t zfy_atomic_add_64(void *p, int64_t v) { (void)p; (void)v; return 0; }
#endif
void zfy_sleep_ms(long long ms) { (void)ms; }
void zfy_chan_new(void **o) { (void)o; zfy_die("chan: 仅支持 Windows"); }
void zfy_chan_send_i64(void **s, long long v) { (void)s; (void)v; }
void zfy_chan_send_f32(void **s, float v) { (void)s; (void)v; }
void zfy_chan_send_f64(void **s, double v) { (void)s; (void)v; }
void zfy_chan_send_str(void **s, char *v) { (void)s; (void)v; }
int zfy_chan_recv_raw(void **s, long long *oi, void **op) { (void)s; (void)oi; (void)op; return 0; }
void zfy_chan_recv_err_i64(zfy_err *o, void **s) { (void)o; (void)s; MAP_MISS(o); }
void zfy_chan_recv_err_f32(zfy_err *o, void **s) { (void)o; (void)s; MAP_MISS(o); }
void zfy_chan_recv_err_f64(zfy_err *o, void **s) { (void)o; (void)s; MAP_MISS(o); }
void zfy_chan_recv_err_str(zfy_err *o, void **s) { (void)o; (void)s; MAP_MISS(o); }
void zfy_chan_close(void **s) { (void)s; }
long long zfy_chan_len(void **s) { (void)s; return 0; }
void zfy_chan_free(void **s) { (void)s; }
void zfy_global_reg(void **slot, void (*release)(void **), const char *name) {
    (void)slot; (void)release; (void)name;
}
#endif

/* ---------- 字符串设施补齐（v3.9.2）---------- */

/* startswith / endswith / contains：均返回 0/1 */
int zfy_str_startswith(const char *s, const char *p) {
    size_t n = strlen(p);
    return strncmp(s, p, n) == 0;
}

int zfy_str_endswith(const char *s, const char *p) {
    size_t ls = strlen(s), lp = strlen(p);
    if (lp > ls) return 0;
    return strcmp(s + (ls - lp), p) == 0;
}

int zfy_str_contains(const char *s, const char *sub) {
    return strstr(s, sub) != NULL;
}

/* substr(s, start, len)：字节区间深拷贝（start/len 越界截断到串边界） */
char *zfy_str_sub(const char *s, long long start, long long len) {
    long long ls = (long long)strlen(s);
    if (start < 0) { len += start; start = 0; }
    if (start > ls) start = ls;
    if (len < 0) len = 0;
    if (start + len > ls) len = ls - start;
    char *out = (char *)malloc((size_t)len + 1);
    if (!out) zfy_die("内存分配失败");
    memcpy(out, s + start, (size_t)len);
    out[len] = '\0';
    return out;
}

/* format(fmt, args)：把 string 列表 args 逐个替换 fmt 中的 "{}" 占位。
 * 占位多于实参 = 剩余 "{}" 原样保留；实参多于占位 = 忽略余项。 */
char *zfy_str_format(const char *fmt, zfy_seq *args) {
    size_t cap = strlen(fmt) + 16;
    if (args) cap += (size_t)args->len * 8;
    char *out = (char *)malloc(cap);
    if (!out) zfy_die("内存分配失败");
    size_t o = 0;
    long long ai = 0;
    for (const char *p = fmt; *p; p++) {
        if (p[0] == '{' && p[1] == '}' && args && ai < args->len) {
            const char *v = *(char **)((char *)args->data + ai * args->elemsz);
            size_t vl = strlen(v);
            if (o + vl + 1 > cap) { cap = (o + vl + 1) * 2; out = (char *)realloc(out, cap); }
            memcpy(out + o, v, vl); o += vl;
            ai++; p++;
        } else {
            if (o + 2 > cap) { cap = cap * 2; out = (char *)realloc(out, cap); }
            out[o++] = *p;
        }
    }
    out[o] = '\0';
    return out;
}
