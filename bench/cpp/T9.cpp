// T9: 聚合传参（move 路径 + 按值深拷贝路径，与 zfy/task9 语义一致）
#include <cstdio>
#include <utility>
#include <vector>
static std::vector<long long> build(long long n) {
    std::vector<long long> v;
    v.reserve(n);
    for (long long i = 0; i < n; i++) v.push_back(i);
    return v;
}
static long long sum_consume(std::vector<long long> a) {
    long long s = 0;
    for (long long x : a) s += x;
    return s;
}
int main() {
    auto xs = build(1000000);
    long long s1 = sum_consume(std::move(xs));   // move，免克隆
    std::printf("T9 s1=%lld\n", s1);
    auto ys = build(1000000);
    long long s2 = 0;
    for (int r = 0; r < 30; r++) s2 += sum_consume(ys);  // 按值深拷贝
    std::printf("T9 s2=%lld keep=%zu\n", s2, ys.size());
    return 0;
}
