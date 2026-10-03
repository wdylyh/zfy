// zfy 语言基准测试 - Rust 版本
// 五类任务，与 Python/C++/zfy 版本功能等效，输出校验和
// 展示所有权系统（clone 深拷贝、借用切片）与类型安全
// 编译: rustc -O bench.rs -o bench.exe

use std::io::{self, Read, Write};

// ---------- T1 数据结构 ----------
fn task1() {
    let n: i64 = 200000;
    let src: Vec<i64> = (0..n).collect();          // 构建序列
    let evens: Vec<i64> = src.iter().cloned().filter(|x| x % 2 == 0).collect();
    let s: i64 = evens.iter().sum();
    println!("T1 sum={} count={}", s, evens.len());
}

fn main() { task1(); }
