#include <setjmp.h>
typedef struct zfy_handler { jmp_buf env; char *msg; struct zfy_handler *prev; } zfy_handler;
static zfy_handler *top = NULL;
__attribute__((returns_twice)) int zfy_try_setup(zfy_handler *h) {
    h->msg = NULL; h->prev = top; top = h;
    return _setjmp(h->env, NULL);
}
void zfy_throw(char *m) { top->msg = m; _longjmp(top->env, 1); }
