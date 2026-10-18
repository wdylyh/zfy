import io

p = r'D:\zfy\compiler\runtime\runtime.c'
src = io.open(p, encoding='utf-8').read()

sec = u'''
/* ==================================================================
 * \u5e76\u53d1\uff08v3.8.0\uff09\uff1a\u7ebf\u7a0b / \u4e92\u65a5\u9501 / \u539f\u5b50\u64cd\u4f5c / channel
 * \u7ea6\u5b9a\uff1a
 *   - \u7ebf\u7a0b/\u4e92\u65a5/channel \u53e5\u67c4 = \u5355 ptr \u5b57\u6bb5 struct\uff08{ptr h}\uff09\uff0c
 *     \u64cd\u4f5c\u51fd\u6570\u6536\u69fd\u5730\u5740\uff08void**\uff09\u89e3\u4e00\u5c42\u53d6 h\uff08\u4e0e map \u540c\u6b3e\uff09\uff1b
 *   - spawn \u6536\u95ed\u5305\u53e5\u67c4\uff08\u89e3\u4e00\u5c42 = env \u5757\u5730\u5740\uff0c\u9996\u5b57\u6bb5 = code\uff09\uff0c
 *     \u7ebf\u7a0b\u4f53\u76f4\u63a5\u8c03 code(env)\uff1benv \u5806\u5757\u751f\u547d\u5468\u671f = \u8fdb\u7a0b\uff0c
 *     \u5929\u7136\u9002\u914d\u7ebf\u7a0b\uff08\u65e0 GC\uff0c\u65e0\u6240\u6709\u6743\u56de\u6536\u95ee\u9898\uff09\uff1b
 *   - \u539f\u5b50\u64cd\u4f5c\u76f4\u63a5\u4f5c\u7528\u4e8e\u53d8\u91cf\u5730\u5740\uff08&g \u53d6\u5740\uff09\uff0c\u9650 32/64 \u4f4d\u6574\u578b\uff1b
 *   - channel \u4e3a\u65e0\u754c\u961f\u5217\uff08send \u4e0d\u963b\u585e\uff09\uff0crecv \u963b\u585e\u76f4\u81f3\u6709\u503c\u6216
 *     \u5173\u95ed\u4e14\u6392\u7a7a\uff08\u540e\u8005\u4ea7 NOT_FOUND \u9519\u8bef\u503c\uff0c\u4e0e map \u7f3a\u952e\u540c\u6b3e\uff09\uff1b
 *   - \u5df2\u77e5\u9650\u5236 v1\uff1ajoin \u540e\u53e5\u67c4\u7f6e null\uff08\u91cd\u590d join \u62a5\u9519\uff09\uff1b
 *     mutex/chan \u4e0d\u56de\u6536\uff08\u751f\u547d\u5468\u671f = \u8fdb\u7a0b\uff09\uff1bmap/\u5217\u8868\u7b49\u5bb9\u5668
 *     \u975e\u7ebf\u7a0b\u5b89\u5168\uff0c\u8de8\u7ebf\u7a0b\u5171\u4eab\u987b\u7528 mutex \u5916\u90e8\u4fdd\u62a4\u3002
 * ================================================================== */
#ifdef _WIN32
#include <process.h>

/* ---- \u7ebf\u7a0b ---- */
static unsigned __stdcall zfy_thr_proc(void *p) {
    void *env = p;                       /* env \u5757\uff1a\u9996\u5b57\u6bb5 = code */
    void *code = *(void **)env;
    ((void (*)(void *))code)(env);
    return 0;
}
void zfy_thread_spawn(void **out, void *clo_slot) {
    void *env = *(void **)clo_slot;      /* \u95ed\u5305\u53e5\u67c4\u89e3\u4e00\u5c42 = env \u5757 */
    uintptr_t th = _beginthreadex(NULL, 0, zfy_thr_proc, env, 0, NULL);
    if (th == 0) zfy_die("spawn: \\u7ebf\\u7a0b\\u521b\\u5efa\\u5931\\u8d25");
    *out = (void *)th;
}
void zfy_thread_join(void **slot) {
    void *h = *slot;
    if (!h) zfy_die("join: \\u7ebf\\u7a0b\\u53e5\\u67c4\\u4e3a\\u7a7a\\uff08\\u91cd\\u590d join\\uff1f\\uff09");
    WaitForSingleObject((HANDLE)h, INFINITE);
    CloseHandle((HANDLE)h);
    *slot = NULL;
}

/* ---- \u4e92\u65a5\u9501\uff08CRITICAL_SECTION\uff09 ---- */
void zfy_mutex_new(void **out) {
    CRITICAL_SECTION *cs = (CRITICAL_SECTION *)malloc(sizeof(CRITICAL_SECTION));
    if (!cs) zfy_die("mutex_new: \\u5206\\u914d\\u5931\\u8d25");
    InitializeCriticalSection(cs);
    *out = cs;
}
void zfy_mutex_lock(void **slot) {
    void *h = *slot;
    if (!h) zfy_die("lock: \\u4e92\\u65a5\\u9501\\u672a\\u521d\\u59cb\\u5316\\uff08\\u5148 mutex_new\\uff09");
    EnterCriticalSection((CRITICAL_SECTION *)h);
}
void zfy_mutex_unlock(void **slot) {
    void *h = *slot;
    if (!h) zfy_die("unlock: \\u4e92\\u65a5\\u9501\\u672a\\u521d\\u59cb\\u5316\\uff08\\u5148 mutex_new\\uff09");
    LeaveCriticalSection((CRITICAL_SECTION *)h);
}

/* ---- \u539f\u5b50\u64cd\u4f5c\uff08\u4f5c\u7528\u4e8e\u53d8\u91cf\u5730\u5740\uff1b\u8fd4\u56de\u65e7\u503c\u8bed\u4e49\u4e0e
 * Interlocked \u5bb6\u65cf\u4e00\u81f4\uff1aadd \u8fd4\u56de\u52a0\u524d\u65e7\u503c\uff09 ---- */
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

/* ---- \u7761\u7720 ---- */
void zfy_sleep_ms(long long ms) { Sleep((DWORD)ms); }

/* ---- channel\uff1a\u65e0\u754c\u961f\u5217\uff08\u94fe\u8868\uff09+ CS/CONDVAR ---- */
typedef struct zfy_chan_node {
    struct zfy_chan_node *next;
    long long i;                         /* \u6807\u91cf\u503c / f32/f64 \u4f4d\u6a21\u5f0f */
    void *p;                             /* string \u5806\u4e32\uff08\u63a5\u7ba1\u6240\u6709\u6743\uff09 */
} zfy_chan_node;
typedef struct {
    CRITICAL_SECTION cs;
    CONDITION_VARIABLE cv;
    zfy_chan_node *head, *tail;
    long long len;
    int closed;
} zfy_chan;

void zfy_chan_new(void **out) {
    zfy_chan *c = (zfy_chan *)malloc(sizeof(zfy_chan));
    if (!c) zfy_die("chan_new: \\u5206\\u914d\\u5931\\u8d25");
    InitializeCriticalSection(&c->cs);
    InitializeConditionVariable(&c->cv);
    c->head = c->tail = NULL;
    c->len = 0;
    c->closed = 0;
    *out = c;
}
static void chan_push(zfy_chan *c, long long i, void *p) {
    zfy_chan_node *n = (zfy_chan_node *)malloc(sizeof(zfy_chan_node));
    if (!n) zfy_die("chan_send: \\u5206\\u914d\\u5931\\u8d25");
    n->next = NULL;
    n->i = i;
    n->p = p;
    EnterCriticalSection(&c->cs);
    if (c->closed) {
        LeaveCriticalSection(&c->cs);
        free(n);
        if (p) free(p);
        zfy_die("chan_send: channel \\u5df2\\u5173\\u95ed");
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
    chan_push((zfy_chan *)*slot, 0, zfy_strdup(v));   /* \u6df1\u62f7\u8d1d\uff0c\u961f\u5217\u63a5\u7ba1 */
}

/* \u963b\u585e\u63a5\u6536\uff1a\u53d6\u51fa\u5199 *out_i/*out_p\uff08string \u8f6c\u79fb\u6240\u6709\u6743\u7ed9\u8c03\u7528\u65b9\uff09\uff1b
 * \u8fd4\u56de 1 = \u6210\u529f\uff0c0 = \u5df2\u5173\u95ed\u4e14\u6392\u7a7a\uff08\u7f16\u8bd1\u5668\u4fa7\u636e\u6b64\u4ea7 NOT_FOUND\uff09 */
static int chan_pop(zfy_chan *c, long long *out_i, void **out_p) {
    EnterCriticalSection(&c->cs);
    while (!c->head && !c->closed)
        SleepConditionVariableCS(&c->cv, &c->cs, INFINITE);
    if (!c->head) {                       /* closed \\u4e14\\u6392\\u7a7a */
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

/* \u9519\u8bef\u503c\u5f62\u6001 recv\uff08\u4e0e map get_err \u540c\u6b3e\uff1aout = zfy_err* \u9996\u53c2\uff09\uff1a
 * \u7f16\u8bd1\u5668\u6309 vtag \u9009\u62e9\u5177\u4f53\u5b9e\u4f8b\uff0c\u5931\u8d25\u4ea7 NOT_FOUND */
void zfy_chan_recv_err_i64(zfy_err *out, void **slot) {
    long long i; void *p;
    if (chan_pop((zfy_chan *)*slot, &i, &p)) get_ok_i(out, i);
    else MAP_MISS(out);
}
void zfy_chan_recv_err_f32(zfy_err *out, void **slot) {
    long long i; void *p;
    if (chan_pop((zfy_chan *)*slot, &i, &p)) get_ok_f32(out, i);
    else MAP_MISS(out);
}
void zfy_chan_recv_err_f64(zfy_err *out, void **slot) {
    long long i; void *p;
    if (chan_pop((zfy_chan *)*slot, &i, &p)) get_ok_f64(out, i);
    else MAP_MISS(out);
}
void zfy_chan_recv_err_str(zfy_err *out, void **slot) {
    long long i; void *p;
    if (chan_pop((zfy_chan *)*slot, &i, &p)) get_ok_str(out, p);
    else MAP_MISS(out);
}

void zfy_chan_close(void **slot) {
    zfy_chan *c = (zfy_chan *)*slot;
    if (!c) zfy_die("chan_close: channel \\u672a\\u521d\\u59cb\\u5316");
    EnterCriticalSection(&c->cs);
    c->closed = 1;
    LeaveCriticalSection(&c->cs);
    WakeAllConditionVariable(&c->cv);
}
long long zfy_chan_len(void **slot) {
    zfy_chan *c = (zfy_chan *)*slot;
    if (!c) zfy_die("chan_len: channel \\u672a\\u521d\\u59cb\\u5316");
    EnterCriticalSection(&c->cs);
    long long n = c->len;
    LeaveCriticalSection(&c->cs);
    return n;
}

#else
/* \u975e Windows\uff1a\u6866\u5b9e\u73b0\uff08\u8c03\u7528\u5373\u7ec8\u6b62\uff0czfy v1 \u5e76\u53d1\u4ec5\u652f\u6301 Windows\uff09 */
void zfy_thread_spawn(void **o, void *c) { (void)o; (void)c; zfy_die("spawn: \\u4ec5\\u652f\\u6301 Windows"); }
void zfy_thread_join(void **s) { (void)s; zfy_die("join: \\u4ec5\\u652f\\u6301 Windows"); }
void zfy_mutex_new(void **o) { (void)o; zfy_die("mutex: \\u4ec5\\u652f\\u6301 Windows"); }
void zfy_mutex_lock(void **s) { (void)s; }
void zfy_mutex_unlock(void **s) { (void)s; }
int32_t zfy_atomic_load_32(void *p) { (void)p; return 0; }
void zfy_atomic_store_32(void *p, int32_t v) { (void)p; (void)v; }
int32_t zfy_atomic_add_32(void *p, int32_t v) { (void)p; (void)v; return 0; }
int64_t zfy_atomic_load_64(void *p) { (void)p; return 0; }
void zfy_atomic_store_64(void *p, int64_t v) { (void)p; (void)v; }
int64_t zfy_atomic_add_64(void *p, int64_t v) { (void)p; (void)v; return 0; }
void zfy_sleep_ms(long long ms) { (void)ms; }
void zfy_chan_new(void **o) { (void)o; zfy_die("chan: \\u4ec5\\u652f\\u6301 Windows"); }
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
#endif
'''

# \u8f6c\u4e49\u4fee\u6b63\uff1a\u4e0a\u9762\u628a \\u 转义写进了 C 字符串（zfy_die 的中文需要直接 UTF-8）——
# C 源码里用 UTF-8 字面量即可，统一把 \uXXXX 形式还原为字符
import re
def deesc(m):
    return chr(int(m.group(1), 16))
sec = re.sub(r'\\u([0-9a-fA-F]{4})', deesc, sec)

src = src.rstrip() + '\n' + sec
io.open(p, 'w', encoding='utf-8', newline='\n').write(src)
print('appended', len(sec), 'chars')
