// zfy 语言基准测试 - C++ 版本
// 五类任务，与 Python/Rust/zfy 版本功能等效，输出校验和
// 编译: g++ -O2 -std=c++17 bench.cpp -o bench.exe

#include <cstdio>
#include <cstdint>
#include <vector>
#include <string>
#include <sstream>
#include <iostream>

// ---------- T1 数据结构 ----------
static void task1() {
    const int n = 200000;
    std::vector<int> src;
    src.reserve(n);
    for (int i = 0; i < n; i++) src.push_back(i);   // 构建序列
    std::vector<int> evens;                          // 筛选偶数
    evens.reserve(n / 2);
    for (int x : src) if (x % 2 == 0) evens.push_back(x);
    long long s = 0;
    for (int x : evens) s += x;
    std::printf("T1 sum=%lld count=%zu\n", s, evens.size());
}

// ---------- T2 算法：筛法 + 插入排序 ----------
static void task2() {
    const int limit = 100000;
    std::vector<char> is_comp(limit + 1, 0);
    long long cnt = 0;
    for (int i = 2; i <= limit; i++) {
        if (!is_comp[i]) {
            cnt++;
            for (long long j = (long long)i * i; j <= limit; j += i)
                is_comp[j] = 1;
        }
    }
    // LCG 伪随机 + 插入排序
    std::vector<long long> arr;
    arr.reserve(2000);
    long long state = 42;
    for (int k = 0; k < 2000; k++) {
        state = (state * 1103515245LL + 12345LL) % 2147483647LL;
        arr.push_back(state);
    }
    for (size_t i = 1; i < arr.size(); i++) {
        long long key = arr[i];
        long long j = (long long)i - 1;
        while (j >= 0 && arr[j] > key) { arr[j + 1] = arr[j]; j--; }
        arr[j + 1] = key;
    }
    std::printf("T2 primes=%lld first=%lld last=%lld\n", cnt, arr.front(), arr.back());
}

// ---------- T3 I/O：读 n 个整数，逐个 *2 输出 ----------
static void task3() {
    int n;
    std::scanf("%d", &n);
    long long s = 0;
    std::ostringstream out;
    for (int k = 0; k < n; k++) {
        long long v;
        std::scanf("%lld", &v);
        v *= 2;
        s += v;
        out << v << '\n';
    }
    std::cout << out.str();
    std::printf("T3 sum=%lld\n", s);
}

// ---------- T4 内存密集：深拷贝 + 步长切片 + 写 ----------
static void task4() {
    const int n = 50000, rounds = 200;
    std::vector<int> base(n);
    for (int i = 0; i < n; i++) base[i] = i;
    long long acc = 0;
    for (int r = 0; r < rounds; r++) {
        std::vector<int> cp(base);            // 深拷贝
        std::vector<int> sl;                   // 步长 2 切片
        sl.reserve((n + 1) / 2);
        for (int i = 0; i < n; i += 2) sl.push_back(cp[i]);
        int idx = r % (int)sl.size();
        sl[idx] += r;
        acc = (acc + sl[idx]) % 2147483647LL;
    }
    std::printf("T4 acc=%lld len=%zu\n", acc, base.size());
}

// ---------- T5 计算密集：矩阵乘 + LCG 哈希 ----------
static void task5() {
    const int n = 256;
    std::vector<std::vector<double>> a(n, std::vector<double>(n)),
        b(n, std::vector<double>(n)), c(n, std::vector<double>(n, 0.0));
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            a[i][j] = (i * n + j) % 97 * 0.5;
            b[i][j] = (i + j) % 89 * 0.25;
        }
    for (int i = 0; i < n; i++)
        for (int k = 0; k < n; k++) {
            double aik = a[i][k];
            for (int j = 0; j < n; j++) c[i][j] += aik * b[k][j];
        }
    double tr = 0.0;
    for (int i = 0; i < n; i++) tr += c[i][i];
    unsigned long long state = 7;
    for (int k = 0; k < 5000000; k++)
        state = (unsigned long long)(((__uint128_t)state * 6364136223846793005ULL +
                                      1442695040888963407ULL) % 9223372036854775807ULL);
    std::printf("T5 trace=%.6f hash=%llu\n", tr, state);
}

int main() {
    task1();
    task2();
    task3();
    task4();
    task5();
    return 0;
}
