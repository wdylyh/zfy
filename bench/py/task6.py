# T6: 指针链表 + struct（与 zfy/task6 语义一致）
class Node:
    __slots__ = ("v", "next")
    def __init__(self, v, nxt):
        self.v = v
        self.next = nxt

def main():
    head = None
    for i in range(100000):
        head = Node(i, head)
    s = 0
    cur = head
    while cur is not None:
        s += cur.v
        cur = cur.next
    print(f"T6 sum={s}")
    while head is not None:
        head = head.next

main()
