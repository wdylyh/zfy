// zfy 语言基准测试 - C++ 版本
// 五类任务，与 Python/Rust/zfy 版本功能等效，输出校验和
// 编译: g++ -O2 -std=c++17 bench.cpp -o bench.exe

#include <cstdio>
#include <cstdint>
#include <vector>
#include <string>
#include <sstream>
#include <iostream>

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

int main(){ task5(); return 0; }
