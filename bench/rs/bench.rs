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

fn main() {
    task1();
    task2();
    task3();
    task4();
    task5();
}
