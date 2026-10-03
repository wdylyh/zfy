# Analyze results.csv: mean, sd, var per impl
import csv, statistics, os

BENCH = os.path.dirname(os.path.abspath(__file__))
rows = list(csv.DictReader(open(os.path.join(BENCH, "results.csv"))))
groups = {}
for r in rows:
    groups.setdefault(r["impl"], []).append((float(r["wall_seconds"]), float(r["peak_mem_mb"])))

print(f"{'impl':8} {'time_mean':>10} {'time_sd':>9} {'time_var':>10} {'mem_mean':>9}  rel")
base = min(statistics.mean(t for t, m in groups[n]) for n in groups)
for name, vals in sorted(groups.items(), key=lambda kv: statistics.mean(v[0] for v in kv[1])):
    times = [t for t, m in vals]
    mems = [m for t, m in vals]
    mean = statistics.mean(times)
    var = statistics.variance(times) if len(times) > 1 else 0.0
    sd = statistics.stdev(times) if len(times) > 1 else 0.0
    print(f"{name:8} {mean:10.4f} {sd:9.4f} {var:10.6f} "
          f"{statistics.mean(mems):9.2f}  {mean/base:.2f}x")
