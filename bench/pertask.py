# Per-task breakdown: split each language's bench into task-isolated programs,
# run each 3 times, report per-task mean.
import subprocess, re, os, time, statistics, tempfile

BENCH = r"d:\zfy\bench"
INPUT = open(os.path.join(BENCH, "input.txt"), "rb").read()
RUNS = 3
OUT = {}

# ---- zfy: split bench.zfy at "void taskN()" ----
zsrc = open(os.path.join(BENCH, r"zfy\bench.zfy"), encoding="utf-8").read()
parts = re.split(r"(?=void task\d\(\))", zsrc)
tasks_zfy = {}
for p in parts:
    m = re.match(r"void (task\d)\(\)", p)
    if m:
        tasks_zfy[m.group(1)] = p.split("void main()")[0].rstrip()
for name, body in tasks_zfy.items():
    with open(os.path.join(BENCH, r"zfy", f"{name}.zfy"), "w", encoding="utf-8") as f:
        f.write(body + "\n\nvoid main()\n    " + name + "()\n")
OUT["zfy"] = ([os.path.join(BENCH, r"zfy", f"task{n}.zfy") for n in "12345"],
              lambda src: subprocess.run([r"d:\zfy\compiler\_build\zfyc.exe", "build", src],
                                         capture_output=True) and
              os.path.join(BENCH, "zfy", os.path.basename(src)[:-4] + ".exe"))

# ---- C++: split bench.cpp at "// ---------- T" ----
csrc = open(os.path.join(BENCH, r"cpp\bench.cpp"), encoding="utf-8").read()
head, rest = csrc.split("// ---------- T1", 1)
rest = "// ---------- T1" + rest
chunks = re.split(r"(?=// ---------- T\d)", rest)
cpp_tasks = {}
for ch in chunks:
    m = re.match(r"// ---------- (T\d)", ch)
    if m:
        cpp_tasks[m.group(1)] = ch.split("int main()")[0]
def build_cpp(src):
    exe = src[:-4] + ".exe"
    subprocess.run(["g++", "-O2", "-std=c++17", src, "-o", exe], capture_output=True)
    return exe
for name, body in cpp_tasks.items():
    src = os.path.join(BENCH, "cpp", f"{name}.cpp")
    with open(src, "w", encoding="utf-8") as f:
        f.write(head + body + "int main(){ task" + name[1] + "(); return 0; }\n")
OUT["cpp"] = ([os.path.join(BENCH, "cpp", f"{n}.cpp") for n in list(cpp_tasks)], build_cpp)

# ---- Rust: split bench.rs at "// ---------- T" ----
rsrc = open(os.path.join(BENCH, r"rs\bench.rs"), encoding="utf-8").read()
rhead, rrest = rsrc.split("// ---------- T1", 1)
rrest = "// ---------- T1" + rrest
rchunks = re.split(r"(?=// ---------- T\d)", rrest)
rs_tasks = {}
for ch in rchunks:
    m = re.match(r"// ---------- (T\d)", ch)
    if m:
        rs_tasks[m.group(1)] = ch.split("fn main()")[0]
def build_rs(src):
    exe = src[:-3] + ".exe"
    r = subprocess.run(["rustc", "-O", src, "-o", exe], capture_output=True)
    if r.returncode: print(r.stderr.decode()[:400])
    return exe
for name, body in rs_tasks.items():
    src = os.path.join(BENCH, "rs", f"{name}.rs")
    with open(src, "w", encoding="utf-8") as f:
        f.write(rhead + body + f"fn main() {{ task{name[1]}(); }}\n")
OUT["rust"] = ([os.path.join(BENCH, "rs", f"{n}.rs") for n in list(rs_tasks)], build_rs)

# ---- Python ----
PYFN = {"1": "task1_datastruct", "2": "task2_algo", "3": "task3_io",
        "4": "task4_memory", "5": "task5_compute"}
for n in "12345":
    src = os.path.join(BENCH, "py", f"task{n}.py")
    with open(src, "w", encoding="utf-8") as f:
        f.write(f"import sys, os\nsys.path.insert(0, r'{BENCH}\\py')\n"
                f"from bench import {PYFN[n]}\n{PYFN[n]}()\n")
OUT["python"] = ([os.path.join(BENCH, "py", f"task{n}.py") for n in "12345"],
                 lambda src: "python")  # placeholder build (interpreted)

results = {}
import re as _re
for impl, (srcs, build) in OUT.items():
    for src in srcs:
        exe = build(src)
        tid = _re.search(r"(?:task|T)(\d)", os.path.basename(src)).group(1)
        name = impl + "/T" + tid
        times = []
        for _ in range(RUNS):
            t0 = time.perf_counter()
            p = subprocess.run([exe] if impl != "python" else ["python", src],
                               input=INPUT if tid == "3" else b"",
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            times.append(time.perf_counter() - t0)
        results[name] = (statistics.mean(times), min(times))
        print(f"{name:16} mean={statistics.mean(times):.3f}s min={min(times):.3f}s", flush=True)

print("\n== per-task ratio vs best ==")
for t in "12345":
    vals = {impl: results[f"{impl}/T{t}"][0] for impl in OUT if f"{impl}/T{t}" in results}
    best = min(vals.values())
    line = " ".join(f"{k}:{v/best:.2f}x({v:.3f}s)" for k, v in sorted(vals.items(), key=lambda kv: kv[1]))
    print(f"T{t}: {line}")
