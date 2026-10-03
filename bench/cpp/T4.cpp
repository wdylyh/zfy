// zfy 语言基准测试 - C++ 版本
// 五类任务，与 Python/Rust/zfy 版本功能等效，输出校验和
// 编译: g++ -O2 -std=c++17 bench.cpp -o bench.exe

#include <cstdio>
#include <cstdint>
#include <vector>
#include <string>
#include <sstream>
#include <iostream>

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

int main(){ task4(); return 0; }
