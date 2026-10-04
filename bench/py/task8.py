# T8: 泛型函数 + 泛型 struct 的动态语言对应（与 zfy/task8 语义一致）
class Box:
    __slots__ = ("v",)
    def __init__(self, v):
        self.v = v

def pick(a, b):
    return a if a < b else b

def main():
    acc = 0
    accf = 0.0
    for i in range(300000):
        b = Box(i)
        acc += b.v
        acc += pick(i % 7, 3)
    for j in range(150000):
        c = Box(j * 0.5)
        accf += c.v
    print(f"T8 acc={acc} accf={accf:.6f}")

main()
