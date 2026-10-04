// T6: 指针链表 + struct（与 zfy/task6 语义一致）
#include <cstdio>
struct Node { long long v; Node* next; };
int main() {
    Node* head = nullptr;
    for (long long i = 0; i < 100000; i++) {
        Node* p = new Node{i, head};
        head = p;
    }
    long long s = 0;
    for (Node* c = head; c; c = c->next) s += c->v;
    std::printf("T6 sum=%lld\n", s);
    while (head) { Node* nx = head->next; delete head; head = nx; }
    return 0;
}
