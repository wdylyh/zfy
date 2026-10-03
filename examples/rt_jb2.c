#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct zfy_handler {
    unsigned long long env[10];
    unsigned int mxcsr, fpucsr;
    unsigned long long xmm[10][2];
    char *msg;
    struct zfy_handler *prev;
} zfy_handler;

static zfy_handler *top = NULL;

__attribute__((noinline, returns_twice)) int zfy_try_setup(zfy_handler *h) {
    h->msg = NULL; h->prev = top; top = h;
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
        : "=a"(ret) : "S"(h->env) : "memory");
    return ret;
}

__attribute__((noinline, naked, noreturn)) void zfy_longjmp(zfy_handler *h, int val) {
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

__attribute__((noinline)) void do_throw(char *m) {
    top->msg = m;
    zfy_longjmp(top, 1);
}

int main(void) {
    zfy_handler h;
    int r = zfy_try_setup(&h);
    if (r) { printf("caught: %s\n", h.msg); return 0; }
    printf("before\n");
    fflush(stdout);
    do_throw("boom");
    printf("BAD: returned from do_throw\n");
    return 1;
}
