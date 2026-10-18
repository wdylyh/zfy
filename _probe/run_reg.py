# -*- coding: utf-8 -*-
# v3.6 容器轮回归：examples/*.zfy（有 .out 基线的）编译+运行+比对
import subprocess, sys, os, glob, filecmp

ZFYC = r"compiler\_build\zfyc.exe"
os.chdir(r"D:\zfy")
tests = sorted(glob.glob("examples/*.zfy"))
npass = nfail = nskip = 0
fails = []
for z in tests:
    base = z[:-4]
    out_ref = base + ".out"
    err_ref = base + ".err"
    exe = base + ".exe"
    if not (os.path.exists(out_ref) or os.path.exists(err_ref)):
        nskip += 1
        continue
    # 编译
    p = subprocess.run([ZFYC, "build", z], capture_output=True, text=True,
                       timeout=60, cwd=r"D:\zfy")
    if p.returncode != 0:
        # 编译失败：若有 .err 基线，比对错误输出
        if os.path.exists(err_ref):
            got = p.stdout
            ref = open(err_ref, encoding="utf-8", errors="replace").read()
            # 宽松比对：只看是否有错误行数一致（错误信息含路径，难全等）
            gl = [l for l in got.splitlines() if "zfy:error" in l]
            rl = [l for l in ref.splitlines() if "zfy:error" in l]
            if len(gl) == len(rl) and len(gl) > 0:
                npass += 1
            else:
                nfail += 1
                fails.append((z, "compile-err count %d vs %d" % (len(gl), len(rl))))
        else:
            nfail += 1
            fails.append((z, "compile failed: " + p.stdout[:200]))
        continue
    if not os.path.exists(exe):
        nfail += 1; fails.append((z, "no exe produced")); continue
    try:
        r = subprocess.run([exe], capture_output=True, text=True, timeout=10,
                           cwd=os.path.dirname(exe) or ".")
    except subprocess.TimeoutExpired:
        nfail += 1; fails.append((z, "TIMEOUT (可能 GUI 挂起)")); continue
    got = r.stdout
    if os.path.exists(out_ref):
        ref = open(out_ref, encoding="utf-8", errors="replace").read()
        if got.strip() == ref.strip() and r.returncode == 0:
            npass += 1
        else:
            nfail += 1
            fails.append((z, "rc=%d out-diff" % r.returncode))
print("PASS=%d FAIL=%d SKIP=%d" % (npass, nfail, nskip))
for z, why in fails:
    print("FAIL", z, why)
