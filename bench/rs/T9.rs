// T9: 聚合传参（move 路径 + clone 深拷贝路径，与 zfy/task9 语义一致）
fn build(n: i64) -> Vec<i64> {
    (0..n).collect()
}
fn sum_consume(a: Vec<i64>) -> i64 {
    a.iter().sum()
}
fn main() {
    let xs = build(1000000);
    let s1 = sum_consume(xs); // move，免克隆
    println!("T9 s1={}", s1);
    let ys = build(1000000);
    let mut s2: i64 = 0;
    for _r in 0..30 {
        s2 += sum_consume(ys.clone()); // 深拷贝
    }
    println!("T9 s2={} keep={}", s2, ys.len());
}
