// zfy 语言基准测试 - Rust 版本
// 五类任务，与 Python/C++/zfy 版本功能等效，输出校验和
// 展示所有权系统（clone 深拷贝、借用切片）与类型安全
// 编译: rustc -O bench.rs -o bench.exe

use std::io::{self, Read, Write};

// ---------- T2 算法：筛法 + 插入排序 ----------
fn task2() {
    let limit: usize = 100000;
    let mut is_comp = vec![false; limit + 1];
    let mut cnt: i64 = 0;
    for i in 2..=limit {
        if !is_comp[i] {
            cnt += 1;
            let mut j = i * i;
            while j <= limit {
                is_comp[j] = true;
                j += i;
            }
        }
    }
    // LCG 伪随机 + 插入排序
    let mut arr: Vec<i64> = Vec::with_capacity(2000);
    let mut state: i64 = 42;
    for _ in 0..2000 {
        state = (state * 1103515245 + 12345) % 2147483647;
        arr.push(state);
    }
    for i in 1..arr.len() {
        let key = arr[i];
        let mut j = i as i64 - 1;
        while j >= 0 && arr[j as usize] > key {
            arr[(j + 1) as usize] = arr[j as usize];
            j -= 1;
        }
        arr[(j + 1) as usize] = key;
    }
    println!("T2 primes={} first={} last={}", cnt, arr[0], arr[arr.len() - 1]);
}

fn main() { task2(); }
