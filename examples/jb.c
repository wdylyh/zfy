#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>
typedef struct zfy_handler { jmp_buf env; char *msg; struct zfy_handler *prev; } zfy_handler;
static zfy_handler *top = NULL;
__attribute__((returns_twice)) int zfy_try_setup(zfy_handler *h) {
    h->msg = NULL; h->prev = top; top = h;
    return setjmp(h->env);
}
void zfy_throw(char *m) { top->msg = m; longjmp(top->env, 1); }
int main(void) {
    zfy_handler h;
    int r = zfy_try_setup(&h);
    if (r) { printf("caught: %s\n", h.msg); return 0; }
    printf("before throw\n");
    zfy_throw("boom");
    return 1;
}
