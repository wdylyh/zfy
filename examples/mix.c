#include <stdio.h>
#include <setjmp.h>
typedef struct zfy_handler { jmp_buf env; char *msg; struct zfy_handler *prev; } zfy_handler;
__attribute__((returns_twice)) int zfy_try_setup(zfy_handler *h);
void zfy_throw(char *m);
void thrower(void);
int main(void) {
    zfy_handler h;
    int r = zfy_try_setup(&h);
    if (r) { printf("caught: %s\n", h.msg); return 0; }
    printf("before\n"); fflush(stdout);
    thrower();
    return 1;
}
