// zfy 语言基准测试 - C++ 版本
// 五类任务，与 Python/Rust/zfy 版本功能等效，输出校验和
// 编译: g++ -O2 -std=c++17 bench.cpp -o bench.exe

#include <cstdio>
#include <cstdint>
#include <vector>
#include <string>
#include <sstream>
#include <iostream>

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

int main(){ task2(); return 0; }
