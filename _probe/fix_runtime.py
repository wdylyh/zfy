# -*- coding: utf-8 -*-
# runtime.c 容器算法段改造：回调带 env + 闭包调用约定 + zfy_env_new + zfy_map_seq
import io

P = r"D:\zfy\compiler\runtime\runtime.c"
s = io.open(P, encoding="utf-8").read()

old_start = s.index("/* 谓词/比较器 thunk：llvmgen 为每个 (函数, 元素类型) 生成 C ABI 适配器，")
old_end = s.index("/* remove(数组, idx, out)：把 idx 槽位填零值（长度不变）；被删元素")

new = r'''/* ---------- 闭包与容器高阶算法（v3.7） ----------
 * 闭包值 = 句柄 h（堆块地址）；堆块头部 code 指针，其后捕获字段。
 * 调用约定：code(env, args...)——env = 堆块地址（lambda 首参 $env）。
 * 容器内建收"闭包句柄 struct 槽地址"（{ ptr h }），解两层：
 *   h = *(void**)clo; code = *(void**)h; code(h, ...)。
 * 裸函数名在 typeck 包装为空捕获 wrapper 闭包（env 无关）。

/* env 堆块分配：不回收（闭包/捕获生命周期 = 进程，v1 设计） */
void *zfy_env_new(long long n) {
    void *p = malloc(n > 0 ? (size_t)n : 1);
    if (!p) zfy_die("out of memory (closure env)");
    return p;
}

/* 从闭包槽解出调用入口 */
static void *clo_code(void *clo) {
    void *h = *(void **)clo;
    if (!h) zfy_die("closure is null");
    return *(void **)h;
}

/* 谓词/比较器统一约定（元素按指针传入）：
 *   filter/any/all：i32 (*pred)(void *env, const void *elem)
 *   sort_by：       i32 (*cmp)(void *env, const void *a, const void *b)
 *   fold：          T (*f)(void *env, T acc, T elem)（值传，按值种类宏生成） */
zfy_seq *zfy_filter(zfy_seq *src, void *pred_clo) {
    if (!src) zfy_die("filter: 源为空");
    int (*pred)(void *, const void *) =
        (int (*)(void *, const void *))clo_code(pred_clo);
    void *cenv = *(void **)pred_clo;
    zfy_seq *s = zfy_seq_new_k(0, src->len > 0 ? src->len : 1, src->elemsz,
                               src->kind, src->ops);
    for (long long i = 0; i < src->len; i++) {
        void *e = (char *)src->data + i * src->elemsz;
        if (pred(cenv, e)) {
            void *slot = (char *)s->data + s->len * s->elemsz;
            elem_init(slot, e, s->kind, s->ops, s->elemsz);
            s->len++;
        }
    }
    return s;
}

int zfy_any(zfy_seq *s, void *pred_clo) {
    if (!s) return 0;
    int (*pred)(void *, const void *) =
        (int (*)(void *, const void *))clo_code(pred_clo);
    void *cenv = *(void **)pred_clo;
    for (long long i = 0; i < s->len; i++)
        if (pred(cenv, (char *)s->data + i * s->elemsz)) return 1;
    return 0;
}

int zfy_all(zfy_seq *s, void *pred_clo) {
    if (!s) return 0;
    int (*pred)(void *, const void *) =
        (int (*)(void *, const void *))clo_code(pred_clo);
    void *cenv = *(void **)pred_clo;
    for (long long i = 0; i < s->len; i++)
        if (!pred(cenv, (char *)s->data + i * s->elemsz)) return 0;
    return 1;
}

/* sort_by：qsort 的比较器签名 (a, b) 不带上下文——经线程局部 env 中转
 * （zfy v1 无并发，安全）；返回 clone 排序后的新表（值语义） */
static void *zfy_sb_env;
static int (*zfy_sb_cmp)(void *, const void *, const void *);
static int zfy_sb_trampoline(const void *a, const void *b) {
    return zfy_sb_cmp(zfy_sb_env, a, b);
}
zfy_seq *zfy_sort_by(zfy_seq *src, void *cmp_clo) {
    if (!src) return zfy_seq_new_k(0, 1, 8, 0, NULL);
    zfy_seq *s = zfy_seq_clone(src);
    if (s->len > 1) {
        zfy_sb_cmp = (int (*)(void *, const void *, const void *))clo_code(cmp_clo);
        zfy_sb_env = *(void **)cmp_clo;
        qsort(s->data, (size_t)s->len, (size_t)s->elemsz, zfy_sb_trampoline);
    }
    return s;
}

/* map(xs, f) -> list<B>（v3.7）：逐元素应用闭包，结果按 B 的种类写入新表。
 * 回调值语义：i/f 按 8 字节位模式返回（宽标量统一 i64/double 接口），
 * string 返回堆串（所有权移交新表）；调用点按元素宽度拆位（llvmgen）。 */
zfy_seq *zfy_map_seq(zfy_seq *src, void *f_clo, int bkind, int belosz) {
    if (!src) zfy_die("map: 源为空");
    long long (*f)(void *, void *) =
        (long long (*)(void *, void *))clo_code(f_clo);
    void *cenv = *(void **)f_clo;
    zfy_seq *s = zfy_seq_new_k(0, src->len > 0 ? src->len : 1, belosz,
                               bkind, NULL);
    for (long long i = 0; i < src->len; i++) {
        void *e = (char *)src->data + i * src->elemsz;
        long long r = f(cenv, e);
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

'''

s = s[:old_start] + new + s[old_end:]
io.open(P, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
