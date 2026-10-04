# T7: 字符串处理（与 zfy/task7 语义一致）
def main():
    s = ""
    for i in range(3000):
        s += "w" + str(i % 10) + "ab "
    toks = s.split(" ")
    cnt = 0
    total = 0
    for t in toks:
        total += len(t)
        if t.find("a") >= 0:
            cnt += 1
    print(f"T7 total={total} cnt={cnt} slen={len(s)}")

main()
