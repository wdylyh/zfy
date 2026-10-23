#include <stdio.h>
#include <stdint.h>
typedef struct zfy_seq zfy_seq;
zfy_seq *zfy_seq_new(long long count, long long cap, long long elemsz);
void zfy_seq_set_str();
zfy_seq *zfy_sort_i32(zfy_seq *src);
zfy_seq *zfy_sort_chk_i32(zfy_seq *src, int32_t desc);
struct zfy_seq { void *data; void *_pad; long long len; long long cap; long long elemsz; int kind; void *ops; };
int main() {
    zfy_seq *s = zfy_seq_new(4, 4, 4);
    int vals[4] = {5,2,9,1};
    for (int i = 0; i < 4; i++) ((int*)s->data)[i] = vals[i];
    zfy_seq *r = zfy_sort_i32(s);
    printf("sort_i32:"); for (int i = 0; i < r->len; i++) printf(" %d", ((int*)r->data)[i]); printf("\n");
    zfy_seq *r2 = zfy_sort_chk_i32(s, 0);
    printf("chk desc=0:"); for (int i = 0; i < r2->len; i++) printf(" %d", ((int*)r2->data)[i]); printf("\n");
    return 0;
}
