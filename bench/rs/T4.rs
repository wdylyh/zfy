// zfy 语言基准测试 - Rust 版本
// 五类任务，与 Python/C++/zfy 版本功能等效，输出校验和
// 展示所有权系统（clone 深拷贝、借用切片）与类型安全
// 编译: rustc -O bench.rs -o bench.exe

use std::io::{self, Read, Write};

// ---------- T4 内存密集：clone（深拷贝）+ 步长切片 + 写 ----------
fn task4() {
    let n: usize = 50000;
    let rounds: usize = 200;
    let base: Vec<i64> = (0..n as i64).collect();
    let mut acc: i64 = 0;
    for r in 0..rounds {
        let cp: Vec<i64> = base.clone();            // 所有权深拷贝
        let mut sl: Vec<i64> = cp.iter().step_by(2).cloned().collect();
        let idx = r % sl.len();
        sl[idx] += r as i64;
        acc = (acc + sl[idx]) % 2147483647;
    }
    println!("T4 acc={} len={}", acc, base.len());
}

fn main() { task4(); }
