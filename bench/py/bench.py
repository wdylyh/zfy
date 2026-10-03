# zfy 语言基准测试 - Python 版本
# 五类任务，与 C++/Rust/zfy 版本功能等效，输出校验和

import sys


def task1_datastruct():
    # 构建 0..199999，筛选偶数，求和 + 计数
    n = 200000
    src = list(range(n))
    evens = [x for x in src if x % 2 == 0]
    s = sum(evens)
    print(f"T1 sum={s} count={len(evens)}")


def task2_algo():
    # 筛法：100000 以内素数个数
    limit = 100000
    is_comp = [False] * (limit + 1)
    cnt = 0
    for i in range(2, limit + 1):
        if not is_comp[i]:
            cnt += 1
            for j in range(i * i, limit + 1, i):
                is_comp[j] = True
    # LCG 伪随机 + 插入排序
    state = 42
    arr = []
    for _ in range(2000):
        state = (state * 1103515245 + 12345) % 2147483647
        arr.append(state)
    for i in range(1, len(arr)):
        key = arr[i]
        j = i - 1
        while j >= 0 and arr[j] > key:
            arr[j + 1] = arr[j]
            j -= 1
        arr[j + 1] = key
    print(f"T2 primes={cnt} first={arr[0]} last={arr[-1]}")


def task3_io():
    # 读 n 个整数，逐个 *2，输出
    data = sys.stdin.read().split()
    n = int(data[0])
    out = []
    s = 0
    for k in range(1, n + 1):
        v = int(data[k]) * 2
        s += v
        out.append(str(v))
    sys.stdout.write("\n".join(out) + "\n")
    print(f"T3 sum={s}")


def task4_memory():
    # 5 万元素列表，200 轮深拷贝 + 切片 + 写
    n = 50000
    base = list(range(n))
    rounds = 200
    acc = 0
    for r in range(rounds):
        cp = list(base)          # 深拷贝
        sl = cp[0:n:2]           # 步长切片
        sl[r % len(sl)] += r
        acc = (acc + sl[r % len(sl)]) % 2147483647
    print(f"T4 acc={acc} len={len(base)}")


def task5_compute():
    # 256x256 矩阵乘 + LCG 哈希循环
    n = 256
    a = [[(i * n + j) % 97 * 0.5 for j in range(n)] for i in range(n)]
    b = [[(i + j) % 89 * 0.25 for j in range(n)] for i in range(n)]
    c = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for k in range(n):
            aik = a[i][k]
            for j in range(n):
                c[i][j] += aik * b[k][j]
    tr = 0.0
    for i in range(n):
        tr += c[i][i]
    state = 7
    for _ in range(5000000):
        state = (state * 6364136223846793005 + 1442695040888963407) % 9223372036854775807
    print(f"T5 trace={tr:.6f} hash={state}")


if __name__ == "__main__":
    task1_datastruct()
    task2_algo()
    task3_io()
    task4_memory()
    task5_compute()
