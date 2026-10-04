// T8: 泛型函数 + 泛型 struct（与 zfy/task8 语义一致）
#include <cstdio>
template <class T> struct Box { T v = T{}; };
template <class T> T pick(T a, T b) { return a < b ? a : b; }
int main() {
    long long acc = 0;
    double accf = 0.0;
    for (int i = 0; i < 300000; i++) {
        Box<int> b{i};
        acc += b.v;
        acc += pick(i % 7, 3);
    }
    for (int j = 0; j < 150000; j++) {
        Box<double> c{j * 0.5};
        accf += c.v;
    }
    std::printf("T8 acc=%lld accf=%.6f\n", acc, accf);
    return 0;
}
