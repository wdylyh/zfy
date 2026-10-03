// zfy 语言基准测试 - Rust 版本
// 五类任务，与 Python/C++/zfy 版本功能等效，输出校验和
// 展示所有权系统（clone 深拷贝、借用切片）与类型安全
// 编译: rustc -O bench.rs -o bench.exe

use std::io::{self, Read, Write};

// ---------- T3 I/O：读 n 个整数，逐个 *2 输出 ----------
fn task3() {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();
    let mut it = input.split_whitespace();
    let n: usize = it.next().unwrap().parse().unwrap();
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());
    let mut s: i64 = 0;
    for _ in 0..n {
        let v: i64 = it.next().unwrap().parse().unwrap();
        let v = v * 2;
        s += v;
        writeln!(out, "{}", v).unwrap();
    }
    println!("T3 sum={}", s);
}

fn main() { task3(); }
