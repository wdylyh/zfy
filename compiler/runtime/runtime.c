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
#include <malloc.h>
#include <time.h>                    /* 时间内建（v3.3.6）：time/mktime/localtime */
#ifdef _WIN32
#include <io.h>                      /* _isatty（交互控制台探测） */
#include <windows.h>                 /* OS 熵源（SystemFunction036 动态加载） */
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
    static int hooked = 0;
    if (!hooked) {
        hooked = 1;
        atexit(zfy_msg_atexit);
    }
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
    int vstr;               /* 1 = string 值（首 put 时确定，释放/克隆用） */
} zfy_map;

static unsigned long long zfy_mix64(unsigned long long x) {
    x ^= x >> 30; x *= 0xbf58476d1ce4e5b9ULL;
    x ^= x >> 27; x *= 0x94d049bb133111ebULL;
    x ^= x >> 31; return x;
}

static unsigned long long zfy_hash_key(const zfy_map *m, long long ki, const char *ks) {
    if (!m->kstr) return zfy_mix64((unsigned long long)ki);
    unsigned long long h = 1469598103934665603ULL;
    for (const unsigned char *p = (const unsigned char *)ks; *p; p++) {
        h ^= *p; h *= 1099511628211ULL;
    }
    return h;
}

static int zfy_key_eq(const zfy_map *m, const zfy_ment *e, long long ki, const char *ks) {
    if (m->kstr) return strcmp(e->k_s, ks) == 0;
    return e->k_i == ki;
}

static zfy_map *zfy_map_alloc(int kstr) {
    zfy_map *m = (zfy_map *)malloc(sizeof(zfy_map));
    if (!m) zfy_die("map: 内存分配失败");
    m->buckets = NULL; m->nbuckets = 0; m->size = 0;
    m->kstr = kstr; m->vstr = 0;
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
    const char *ks2 = m->kstr ? ks : NULL;
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
    e->k_s = m->kstr ? zfy_strdup(ks) : NULL;
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

/* 读：按值种类写入 err.value（与 LLVM MErrValue 约定一致：
 * 整数 → sext i64、浮点 → double、string → strdup 所有权副本）；
 * 缺失产 NOT_FOUND 错误。空表/未分配直接报缺失（nbuckets=0 时掩码无意义） */
static zfy_ment *zfy_map_find_raw(zfy_map **mp, long long ki, const char *ks) {
    zfy_map *m = *mp;
    if (!m || m->size == 0) return NULL;
    const char *ks2 = m->kstr ? ks : NULL;
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

/* has / del / len / clear / clone / free */
static int zfy_map_has_raw(zfy_map **mp, long long ki, const char *ks) {
    zfy_map *m = *mp;
    if (!m) return 0;
    const char *ks2 = m->kstr ? ks : NULL;
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
    const char *ks2 = m->kstr ? ks : NULL;
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
#ifdef _WIN32
static long long *zfy_rc_of(void *p) { return ((long long *)p) - 1; }
static long long zfy_rc_alloced = 0, zfy_rc_freed = 0;   /* 泄漏统计（ZFY_LEAK_DEBUG） */
static void zfy_rc_report(void);
void *zfy_rc_alloc(size_t payload) {
    static int rep_hooked = 0;
    if (!rep_hooked) { rep_hooked = 1; atexit(zfy_rc_report); }
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
    static int rep_hooked = 0;
    if (!rep_hooked) { rep_hooked = 1; atexit(zfy_rc_report); }
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
/* 泄漏报告（P0-1a 验证）：ZFY_LEAK_DEBUG=1 时 atexit 打印 rc 对象
 * 分配/回收差值（>0 = 泄漏的闭包 env/chan/mutex/iface 装箱数） */
static void zfy_rc_report(void) {
    if (getenv("ZFY_LEAK_DEBUG") != NULL && zfy_rc_alloced != zfy_rc_freed)
        fprintf(stderr, "[zfy-leak] rc 对象泄漏: %lld (alloc %lld / freed %lld)\n",
                zfy_rc_alloced - zfy_rc_freed, zfy_rc_alloced, zfy_rc_freed);
}

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
#ifdef _WIN32
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

/* ---------- 时间内建（v3.3.6）：时间戳 / 单调计时 / sleep / 日历拆解与构造 ----------
 * datetime 布局与 LLVM %struct.datetime 一致：8 个 int32_t（32 字节），
 * zfy_time_local 以 sret 首参写入（调用方分配槽位）。
 * weekday: 0=周日..6=周六（tm_wday 语义）；yday: 年内第几天，0 起（tm_yday）。 */
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

/* ==================== GUI 核心层（v3.3.7 design_gui.md L0） ====================
 * 架构（速度保障）：
 *  - CreateDIBSection 32bpp 帧缓冲：zfy/C 直接写像素内存，无 GDI 逐像素开销
 *  - fill_rect 按行块填充，draw_text 走 GDI（内存 DC 与 DIB 共享，
 *    支持中文/抗锯齿）；present 单次 BitBlt 提交整帧
 *  - 事件：环形队列（WndProc 生产、poll 消费），轮询模型 O(1)
 *  - 单线程模型：poll() 顺带泵消息，用户每帧至少 poll 一次
 *  - 颜色约定：zfy 侧 0xRRGGBB；帧缓冲 dword = 0x00RRGGBB（DIB 32bpp 内存序
 *    为 B,G,R，小端 DWORD 恰好还原 RRGGBB——不做通道交换）
 *  - DPI 感知：Per-Monitor V2（旧系统退回 SetProcessDPIAware），
 *    open 的 w/h 按 dpi 缩放为物理像素，无 DWM 拉伸模糊；gui_dpi() 供布局缩放
 *  - 可调窗口：WM_SIZE 时重建 DIB 并推 EV_SIZE 事件（x=新宽, y=新高） */
#ifdef _WIN32
#include <wchar.h>                     /* wcslen（GUI 文本转换） */

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
typedef struct {
    int used;
    HWND hwnd;
    HDC win_dc, mem;
    HBITMAP bmp, oldbmp;
    HFONT font, oldfont;
    uint32_t *fb;
    int w, h, dpi;
    volatile int alive, should_close;
    gui_ev q[GUI_EVQ];
    volatile long qh, qt;
} gui_win;
static gui_win g_wins[GUI_MAXWIN];
static gui_win *g_cur = NULL;

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

/* 重建 DIB 帧缓冲（open 首建与 WM_SIZE 缩放共用） */
static void gui_recreate_surface(gui_win *w, int nw, int nh) {
    if (!w->mem) return;
    if (w->bmp) {
        SelectObject(w->mem, w->oldbmp);
        DeleteObject(w->bmp);
        w->bmp = NULL;
    }
    BITMAPINFO bi;
    memset(&bi, 0, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = nw;
    bi.bmiHeader.biHeight = -nh;           /* top-down：原点左上 */
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    w->bmp = CreateDIBSection(w->mem, &bi, DIB_RGB_COLORS, (void **)&w->fb, NULL, 0);
    w->oldbmp = (HBITMAP)SelectObject(w->mem, w->bmp);
    w->w = nw; w->h = nh;
    if (w->fb) memset(w->fb, 0, (size_t)nw * (size_t)nh * 4);
}

static gui_win *gui_win_of(HWND hw) {
    return (gui_win *)(INT_PTR)GetWindowLongPtrW(hw, GWLP_USERDATA);
}

static LRESULT CALLBACK gui_wndproc(HWND hw, UINT msg, WPARAM wp, LPARAM lp) {
    gui_win *w = gui_win_of(hw);
    if (!w) return DefWindowProcW(hw, msg, wp, lp);   /* 创建期消息 */
    switch (msg) {
    case WM_SIZE:
        /* 最小化不重建；尺寸变化时换新 DIB 并通知业务层重布局 */
        if (w->alive && wp != SIZE_MINIMIZED) {
            int nw = LOWORD(lp), nh = HIWORD(lp);
            if (nw > 0 && nh > 0 && (nw != w->w || nh != w->h)) {
                gui_recreate_surface(w, nw, nh);
                gui_push_ev(w, GUI_EV_SIZE, nw, nh, 0);
            }
        }
        return 0;
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC dc = BeginPaint(hw, &ps);
        if (w->mem)
            BitBlt(dc, 0, 0, w->w, w->h, w->mem, 0, 0, SRCCOPY);
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
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)wslot);
    wslot->win_dc = GetDC(hwnd);
    wslot->mem = CreateCompatibleDC(wslot->win_dc);
    gui_recreate_surface(wslot, w, h);     /* DIB + w/h */
    /* 字体：微软雅黑 16 逻辑px × DPI（覆盖中英文）；SetBkMode 在 draw_text 内保持透明 */
    wslot->font = CreateFontW(-16 * dpi / 96, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET,
                              OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                              CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Microsoft YaHei UI");
    wslot->oldfont = (HFONT)SelectObject(wslot->mem, wslot->font);
    SetBkMode(wslot->mem, TRANSPARENT);
    wslot->dpi = dpi;
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
        DestroyWindow(hw);
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

void zfy_gui_present(void) {
    if (g_cur && g_cur->win_dc && g_cur->mem)
        BitBlt(g_cur->win_dc, 0, 0, g_cur->w, g_cur->h, g_cur->mem, 0, 0, SRCCOPY);
}

void zfy_gui_fill_rect(int32_t rx, int32_t ry, int32_t rw, int32_t rh, uint32_t rgb) {
    if (!g_cur || !g_cur->fb) return;
    int gw = g_cur->w, gh = g_cur->h;
    /* 裁剪到客户区 */
    int x0 = rx < 0 ? 0 : rx, y0 = ry < 0 ? 0 : ry;
    int x1 = (rx + rw) > gw ? gw : (rx + rw);
    int y1 = (ry + rh) > gh ? gh : (ry + rh);
    if (x0 >= x1 || y0 >= y1) return;
    /* DIB 32bpp 小端 DWORD 恰为 0x00RRGGBB——直接用，不换通道 */
    uint32_t pix = 0xFF000000u | rgb;
    int span = x1 - x0;
    for (int y = y0; y < y1; y++) {
        uint32_t *row = g_cur->fb + (size_t)y * gw + x0;
        for (int x = 0; x < span; x++) row[x] = pix;
    }
}

void zfy_gui_draw_text(int32_t tx, int32_t ty, char *utf8, uint32_t rgb) {
    if (!g_cur || !g_cur->mem) return;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    /* COLORREF = 0x00BBGGRR：R 在低字节，与 0xRRGGBB 相反，需交换 */
    COLORREF cr = ((rgb >> 16) & 0xFF) | (rgb & 0xFF00) | ((rgb & 0xFF) << 16);
    COLORREF old = SetTextColor(g_cur->mem, cr);
    TextOutW(g_cur->mem, tx, ty, wt, (int)wcslen(wt));
    SetTextColor(g_cur->mem, old);
    free(wt);
}

int32_t zfy_gui_text_w(char *utf8) {
    if (!g_cur || !g_cur->mem) return 0;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    SIZE sz;
    if (!GetTextExtentPoint32W(g_cur->mem, wt, (int)wcslen(wt), &sz)) sz.cx = 0;
    free(wt);
    return (int32_t)sz.cx;
}

/* ---------- UI 打磨原语（v3.4.x：字号/圆角/线条/渐变） ---------- */

static COLORREF gui_rgb(uint32_t rgb) {
    /* 0xRRGGBB -> COLORREF 0x00BBGGRR */
    return ((rgb >> 16) & 0xFF) | (rgb & 0xFF00) | ((rgb & 0xFF) << 16);
}

/* 设置当前字体：px 逻辑像素（内部 ×DPI），bold 非 0 为粗体。
   影响后续 gui_draw_text / gui_text_w；px<=0 恢复默认 16。
   按 (px,bold) 缓存 HFONT——组件每帧 draw 都会设置字体，不缓存则每帧 CreateFont。 */
void zfy_gui_font(int32_t px, int32_t bold) {
    if (!g_cur || !g_cur->mem) return;
    if (px <= 0) px = 16;
    /* 槽位表：每种 (px,bold) 一个 HFONT 常驻，不做单槽淘汰。
       旧实现"单槽缓存 + DeleteObject(仍选入 DC 的旧字体)"在多字号
       来回切换时触发 GDI 未定义行为（实测 <16px 渲染缺失/变黑）。 */
    #define GUI_FONT_SLOTS 16
    static HFONT fonts[GUI_FONT_SLOTS] = {0};
    static int fpx[GUI_FONT_SLOTS];
    static int fbold[GUI_FONT_SLOTS];
    static int slot_n = 0;
    int want = (bold != 0);
    int i;
    for (i = 0; i < GUI_FONT_SLOTS; i++) {
        if (fonts[i] && fpx[i] == px && fbold[i] == want) {
            SelectObject(g_cur->mem, fonts[i]);
            return;
        }
    }
    HFONT f = CreateFontW(-(int)px * g_cur->dpi / 96, 0, 0, 0,
                          bold ? FW_SEMIBOLD : FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET,
                          OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                          CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Microsoft YaHei UI");
    if (!f) return;
    /* 覆盖循环槽；旧字体可能仍被某窗口 DC 持有——不 DeleteObject，
       GDI 句柄数量按字号种类计（个位数），无需回收 */
    int slot = slot_n % GUI_FONT_SLOTS;
    fonts[slot] = f; fpx[slot] = px; fbold[slot] = want;
    slot_n++;
    SelectObject(g_cur->mem, f);
}

/* 圆角矩形：fill=0 跳过填充，border=0 跳过描边（1px） */
void zfy_gui_round_rect(int32_t x, int32_t y, int32_t w, int32_t h, int32_t r,
                        uint32_t fill, uint32_t border) {
    if (!g_cur || !g_cur->mem) return;
    if (w <= 0 || h <= 0) return;
    if (r * 2 > w) r = w / 2;
    if (r * 2 > h) r = h / 2;
    if (r < 1) {
        if (fill) zfy_gui_fill_rect(x, y, w, h, fill);
        if (border) {
            zfy_gui_fill_rect(x, y, w, 1, border);
            zfy_gui_fill_rect(x, y + h - 1, w, 1, border);
            zfy_gui_fill_rect(x, y, 1, h, border);
            zfy_gui_fill_rect(x + w - 1, y, 1, h, border);
        }
        return;
    }
    HRGN rgn = CreateRoundRectRgn(x, y, x + w + 1, y + h + 1, r * 2, r * 2);
    if (!rgn) return;
    if (fill) {
        HBRUSH bf = CreateSolidBrush(gui_rgb(fill));
        FillRgn(g_cur->mem, rgn, bf);
        DeleteObject(bf);
    }
    if (border) {
        HBRUSH bb = CreateSolidBrush(gui_rgb(border));
        FrameRgn(g_cur->mem, rgn, bb, 1, 1);
        DeleteObject(bb);
    }
    DeleteObject(rgn);
}

/* 线段（GDI 硬边，1px） */
void zfy_gui_line(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint32_t rgb) {
    if (!g_cur || !g_cur->mem) return;
    HGDIOBJ oldpen = SelectObject(g_cur->mem, GetStockObject(DC_PEN));
    COLORREF prev = SetDCPenColor(g_cur->mem, gui_rgb(rgb));
    MoveToEx(g_cur->mem, x0, y0, NULL);
    LineTo(g_cur->mem, x1, y1);
    SetDCPenColor(g_cur->mem, prev);
    SelectObject(g_cur->mem, oldpen);
}

/* 渐变矩形：c1->c2 像素线性插值，vertical 非 0 为纵向（DIB 直写，快） */
void zfy_gui_fill_grad(int32_t rx, int32_t ry, int32_t rw, int32_t rh,
                       uint32_t c1, uint32_t c2, int32_t vertical) {
    if (!g_cur || !g_cur->fb) return;
    int gw = g_cur->w, gh = g_cur->h;
    int x0 = rx < 0 ? 0 : rx, y0 = ry < 0 ? 0 : ry;
    int x1 = (rx + rw) > gw ? gw : (rx + rw);
    int y1 = (ry + rh) > gh ? gh : (ry + rh);
    if (x0 >= x1 || y0 >= y1) return;
    int span = x1 - x0;
    int steps = vertical ? (y1 - y0) : (x1 - x0);
    if (steps < 1) steps = 1;
    for (int y = y0; y < y1; y++) {
        uint32_t *row = g_cur->fb + (size_t)y * gw + x0;
        for (int x = x0; x < x1; x++) {
            int t = vertical ? (y - y0) : (x - x0);
            uint32_t r = ((c1 >> 16) & 0xFF) * (steps - 1 - t) / (steps - 1)
                       + ((c2 >> 16) & 0xFF) * t / (steps - 1);
            uint32_t g = ((c1 >> 8) & 0xFF) * (steps - 1 - t) / (steps - 1)
                       + ((c2 >> 8) & 0xFF) * t / (steps - 1);
            uint32_t b = (c1 & 0xFF) * (steps - 1 - t) / (steps - 1)
                       + (c2 & 0xFF) * t / (steps - 1);
            row[x - x0] = 0xFF000000u | (r << 16) | (g << 8) | b;
        }
    }
}

#else
/* 非 Windows：桩实现（返回失败，UI 程序可优雅降级为 TUI） */
int32_t zfy_gui_open(int32_t w, int32_t h, char *t) { (void)w; (void)h; (void)t; return -1; }
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
void zfy_gui_round_rect(int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, uint32_t f, uint32_t g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
void zfy_gui_line(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e) { (void)a; (void)b; (void)c; (void)d; (void)e; }
void zfy_gui_fill_grad(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e, uint32_t f, int32_t g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
int32_t zfy_gui_alive_any(void) { return 0; }
int32_t zfy_gui_self(void) { return 0; }
void zfy_gui_select(int64_t id) { (void)id; }
void zfy_gui_set_icon(char *s) { (void)s; }
void zfy_gui_present(void) {}
void zfy_gui_fill_rect(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e) { (void)a; (void)b; (void)c; (void)d; (void)e; }
void zfy_gui_draw_text(int32_t a, int32_t b, char *s, uint32_t c) { (void)a; (void)b; (void)s; (void)c; }
int32_t zfy_gui_text_w(char *s) { (void)s; return 0; }
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
#ifdef _WIN32
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
void zfy_thread_join(void **slot) {
    void *h = *slot;
    if (!h) zfy_die("join: 线程句柄为空（重复 join？）");
    WaitForSingleObject((HANDLE)h, INFINITE);
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
void zfy_thread_free(void **s) { (void)s; }
void zfy_mutex_new(void **o) { (void)o; zfy_die("mutex: 仅支持 Windows"); }
void zfy_mutex_lock(void **s) { (void)s; }
void zfy_mutex_unlock(void **s) { (void)s; }
void zfy_mutex_free(void **s) { (void)s; }
int32_t zfy_atomic_load_32(void *p) { (void)p; return 0; }
void zfy_atomic_store_32(void *p, int32_t v) { (void)p; (void)v; }
int32_t zfy_atomic_add_32(void *p, int32_t v) { (void)p; (void)v; return 0; }
int64_t zfy_atomic_load_64(void *p) { (void)p; return 0; }
void zfy_atomic_store_64(void *p, int64_t v) { (void)p; (void)v; }
int64_t zfy_atomic_add_64(void *p, int64_t v) { (void)p; (void)v; return 0; }
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
