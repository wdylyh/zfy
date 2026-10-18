# -*- coding: utf-8 -*-
# runtime 容器回调改为按值分派（v3.7 闭包轮）
import io
p = 'compiler/runtime/runtime.c'
src = io.open(p, encoding='utf-8').read()

old_start = src.index('/* \u8c13\u8bcd/\u6bd4\u8f83\u5668\u7edf\u4e00\u7ea6\u5b9a')
old_end = src.index('#define DEF_REDUCE')
new = r'''/* 谓词/比较器统一约定（v3.7，元素按值传入）：
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

'''
src = src[:old_start] + new + src[old_end:]
io.open(p, 'w', encoding='utf-8', newline='\n').write(src)
print('done')
