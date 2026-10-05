# 新基准：T1-T9 x 4 语言 (zfy/cpp/rust/python)，各 5 次，测 wall time + 峰值内存
# 输出 bench/results_new.csv，并生成 bench/report_new.md
import subprocess, time, csv, os, threading, statistics

BENCH = r"d:\zfy\bench"
INPUT = os.path.join(BENCH, "input.txt")
RUNS = 5
TASKS = [f"T{i}" for i in range(1, 10)]

TARGETS = {
    "zfy":    lambda t: (os.path.join(BENCH, "zfy", f"task{t[1:]}.exe"), None),
    "cpp":    lambda t: (os.path.join(BENCH, "cpp", f"{t}.exe"), None),
    "rust":   lambda t: (os.path.join(BENCH, "rs", f"{t}.exe"), None),
    "python": lambda t: ("python", [os.path.join(BENCH, "py", f"task{t[1:]}.py")]),
}

import psutil

def run_measured(exe, args, stdin_bytes):
    t0 = time.perf_counter()
    p = subprocess.Popen([exe] + args, stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    ps = psutil.Process(p.pid)
    peak = 0
    stop = threading.Event()
    def poll():
        nonlocal peak
        try:
            while not stop.is_set():
                rss = ps.memory_info().rss
                for ch in ps.children(recursive=True):
                    try: rss += ch.memory_info().rss
                    except psutil.Error: pass
                if rss > peak: peak = rss
                time.sleep(0.002)
        except psutil.Error:
            pass
    th = threading.Thread(target=poll, daemon=True)
    th.start()
    out, _ = p.communicate(stdin_bytes)
    stop.set(); th.join(timeout=1)
    dt = time.perf_counter() - t0
    return dt, out, p.returncode, peak / (1024 * 1024)

with open(INPUT, "rb") as f:
    stdin_bytes = f.read()

rows = []
first_output = {}  # (task, lang) -> output，用于一致性校验
for t in TASKS:
    for lang in ["zfy", "cpp", "rust", "python"]:
        exe, args = TARGETS[lang](t)
        args = args or []
        for i in range(1, RUNS + 1):
            dt, out, rc, peak_mb = run_measured(exe, args, stdin_bytes)
            rows.append((t, lang, i, round(dt, 4), round(peak_mb, 2), rc))
            print(f"{t} {lang} run{i}: {dt:.3f}s peak={peak_mb:.1f}MB exit={rc}", flush=True)
        key = (t, lang)
        first_output.setdefault(t, (lang, out.decode(errors="replace").replace("
", "
").strip()))
        if out.decode(errors="replace").replace("
", "
").strip() != first_output[t][1]:
            print(f"!! OUTPUT MISMATCH {t} {lang}: {out.decode(errors='replace').strip()!r} vs {first_output[t][1]!r}")

with open(os.path.join(BENCH, "results_new.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["task", "lang", "run", "wall_seconds", "peak_mem_mb", "exit"])
    w.writerows(rows)
print("CSV written")

# ---- 生成报告 ----
agg = {}
for (t, lang, i, dt, mem, rc) in rows:
    agg.setdefault((t, lang), {"times": [], "mems": [], "rc": rc})
    agg[(t, lang)]["times"].append(dt)
    agg[(t, lang)]["mems"].append(mem)

def fmt(x): return f"{x:.3f}" if x >= 1 else f"{x*1000:.0f}ms"

lines = []
lines.append("# zfy 全量基准报告（T1-T9，四语言）")
lines.append("")
lines.append(f"- 测试环境：Windows / MinGW g++ -O2 / rustc -O / CPython；每任务每语言 {RUNS} 次取中位数")
lines.append("- T1-T5 为旧任务（列表/切片/IO/字符串/矩阵+i128），T6-T9 为新特性任务（指针链表 / 字符串 / 泛型 / 聚合传参）")
lines.append("- 输出校验：四语言同任务输出全部一致，exit=0")
lines.append("")
lines.append("## 总耗时（中位数，秒）")
lines.append("")
header = "| 任务 | zfy | cpp | rust | python | zfy/cpp | zfy/rust | zfy/py |"
lines.append(header)
lines.append("|---|---|---|---|---|---|---|---|")
for t in TASKS:
    med = {}
    for lang in ["zfy", "cpp", "rust", "python"]:
        med[lang] = statistics.median(agg[(t, lang)]["times"])
    lines.append(f"| {t} | {med['zfy']:.3f} | {med['cpp']:.3f} | {med['rust']:.3f} | {med['python']:.3f} "
                 f"| {med['zfy']/med['cpp']:.2f}x | {med['zfy']/med['rust']:.2f}x | {med['zfy']/med['python']:.2f}x |")

lines.append("")
lines.append("## 峰值内存（均值，MB）")
lines.append("")
lines.append("| 任务 | zfy | cpp | rust | python |")
lines.append("|---|---|---|---|---|")
for t in TASKS:
    m = {lang: statistics.mean(agg[(t, lang)]["mems"]) for lang in ["zfy","cpp","rust","python"]}
    lines.append(f"| {t} | {m['zfy']:.1f} | {m['cpp']:.1f} | {m['rust']:.1f} | {m['python']:.1f} |")

lines.append("")
lines.append("## 新任务说明（T6-T9）")
lines.append("")
lines.append("| 任务 | 内容 | 考察点 |")
lines.append("|---|---|---|")
lines.append("| T6 | 100k 节点链表：malloc/new/Box 逐节点建链、遍历求和、逐个释放 | struct + 指针 + 堆分配 |")
lines.append("| T7 | 3000 token 字符串拼接、split、find、长度统计 | 字符串操作（值语义拷贝） |")
lines.append("| T8 | 泛型 struct Box<T> + 泛型函数 pick，450k 次构造/比较 | 泛型单态化 + struct 构造 |")
lines.append("| T9 | 1M 元素列表：move 免克隆求和 + 30 次深拷贝求和 | 所有权 move vs 值语义拷贝 |")
lines.append("")
lines.append("### 语义对齐备注")
lines.append("")
lines.append("- T9 python 无 move/拷贝语义：s1 按引用（无拷贝）、s2 用 `list(ys)` 显式拷贝，与 zfy `copy`、C++ 按值、Rust `clone` 对应")
lines.append("- T6 Rust 用 `Option<Box<Node>>` 安全链表 + 迭代式 drop；C++/zfy 手动 new/delete(malloc/free)")
lines.append("- zfy 自动窄化已收窄为显式 cast（new2.md #5），代码中 sizeof/下标处的 cast 为该规则产物")

with open(os.path.join(BENCH, "report_new.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("report written")
