# 基准测量脚本：四种语言实现各运行 10 次
# 记录：运行总耗时、峰值内存(psutil RSS 轮询)、退出码 -> bench/results.csv
import subprocess, time, csv, os, threading

BENCH = r"d:\zfy\bench"
INPUT = os.path.join(BENCH, "input.txt")
RUNS = 10

TARGETS = [
    ("zfy",    os.path.join(BENCH, r"zfy\bench.exe"), []),
    ("cpp",    os.path.join(BENCH, r"cpp\bench.exe"), []),
    ("rust",   os.path.join(BENCH, r"rs\bench.exe"), []),
    ("python", "python", [os.path.join(BENCH, r"py\bench.py")]),
]

import psutil

def run_once(name, i, exe, args):
    t0 = time.perf_counter()
    p = subprocess.Popen([exe] + args, stdin=subprocess.PIPE,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
    p.stdin.write(input_bytes)
    p.stdin.close()
    p.wait()
    stop.set()
    th.join(timeout=1)
    dt = time.perf_counter() - t0
    peak_mb = round(peak / (1024*1024), 2)
    rows.append((name, i, round(dt, 3), peak_mb, p.returncode))
    print(f"{name} run {i}: {dt:.3f}s peak={peak_mb}MB exit={p.returncode}", flush=True)

with open(INPUT, "rb") as f:
    input_bytes = f.read()

rows = []
for name, exe, args in TARGETS:
    for i in range(1, RUNS + 1):
        run_once(name, i, exe, args)

with open(os.path.join(BENCH, "results.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["impl", "run", "wall_seconds", "peak_mem_mb", "exit"])
    w.writerows(rows)
print("DONE")
