// T8: 泛型函数 + 泛型 struct（与 zfy/task8 语义一致）
struct Box<T> { v: T }
fn pick<T: PartialOrd + Copy>(a: T, b: T) -> T { if a < b { a } else { b } }
fn main() {
    let mut acc: i64 = 0;
    let mut accf: f64 = 0.0;
    for i in 0..300000i32 {
        let b = Box::<i32> { v: i };
        acc += b.v as i64;
        acc += pick(i % 7, 3) as i64;
    }
    for j in 0..150000i32 {
        let c = Box::<f64> { v: j as f64 * 0.5 };
        accf += c.v;
    }
    println!("T8 acc={} accf={:.6}", acc, accf);
}
