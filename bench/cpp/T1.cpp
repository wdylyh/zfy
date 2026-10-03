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

int main(){ task1(); return 0; }
