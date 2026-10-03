// zfy 语言基准测试 - Rust 版本
// 五类任务，与 Python/C++/zfy 版本功能等效，输出校验和
// 展示所有权系统（clone 深拷贝、借用切片）与类型安全
// 编译: rustc -O bench.rs -o bench.exe

use std::io::{self, Read, Write};

// ---------- T5 计算密集：矩阵乘 + LCG 哈希（单线程，与其他语言校验和一致） ----------
fn lcg(start: u64, steps: u64) -> u64 {
    let mut state = start as u128;
    for _ in 0..steps {
        state = (state * 6364136223846793005u128 + 1442695040888963407u128)
            % 9223372036854775807u128;
    }
    state as u64
}

fn task5() {
    let n: usize = 256;
    let mut a = vec![vec![0.0f64; n]; n];
    let mut b = vec![vec![0.0f64; n]; n];
    let mut c = vec![vec![0.0f64; n]; n];
    for i in 0..n {
        for j in 0..n {
            a[i][j] = ((i * n + j) % 97) as f64 * 0.5;
            b[i][j] = ((i + j) % 89) as f64 * 0.25;
        }
    }
    for i in 0..n {
        for k in 0..n {
            let aik = a[i][k];
            let (brow, crow) = (&b[k], &mut c[i]); // 借用检查保证安全
            for j in 0..n {
                crow[j] += aik * brow[j];
            }
        }
    }
    let tr: f64 = (0..n).map(|i| c[i][i]).sum();
    let hash = lcg(7, 5000000);
    println!("T5 trace={:.6} hash={}", tr, hash);
}

fn main() { task5(); }
