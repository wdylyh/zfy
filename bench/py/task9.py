# T9: 聚合传参（Python 无 move 语义：传引用；拷贝路径用 list(xs)，与 zfy/task9 对应）
def build(n):
    return list(range(n))

def sum_consume(a):
    s = 0
    for x in a:
        s += x
    return s

def main():
    xs = build(1000000)
    s1 = sum_consume(xs)  # Python 天然传引用（无拷贝）
    print(f"T9 s1={s1}")
    ys = build(1000000)
    s2 = 0
    for _r in range(30):
        s2 += sum_consume(list(ys))  # 显式深拷贝
    print(f"T9 s2={s2} keep={len(ys)}")

main()
