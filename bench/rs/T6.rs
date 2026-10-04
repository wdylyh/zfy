// T6: 指针链表 + struct（与 zfy/task6 语义一致；迭代式 drop 防栈溢出）
struct Node { v: i64, next: Option<Box<Node>> }
fn main() {
    let mut head: Option<Box<Node>> = None;
    for i in 0..100000i64 {
        head = Some(Box::new(Node { v: i, next: head.take() }));
    }
    let mut s: i64 = 0;
    let mut cur = head.as_deref();
    while let Some(n) = cur {
        s += n.v;
        cur = n.next.as_deref();
    }
    println!("T6 sum={}", s);
    while let Some(mut n) = head.take() {
        head = n.next.take();
    }
}
