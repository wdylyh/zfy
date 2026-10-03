// zfy 语言基准测试 - C++ 版本
// 五类任务，与 Python/Rust/zfy 版本功能等效，输出校验和
// 编译: g++ -O2 -std=c++17 bench.cpp -o bench.exe

#include <cstdio>
#include <cstdint>
#include <vector>
#include <string>
#include <sstream>
#include <iostream>

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

int main(){ task3(); return 0; }
