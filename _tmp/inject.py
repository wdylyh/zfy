import ctypes, time, subprocess, sys
u32 = ctypes.windll.user32
WM_CHAR = 0x0102
p = subprocess.Popen([r"d:\zfy\_tmp\guitype.exe"], cwd=r"d:\zfy\_tmp")
hwnd = 0
for _ in range(100):
    time.sleep(0.02)
    hwnd = u32.FindWindowW(None, "guitype")
    if hwnd:
        break
assert hwnd, "window not found"
time.sleep(0.15)
for cp in (0x4E2D, ord('A')):          # '中' 'A'
    u32.PostMessageW(hwnd, WM_CHAR, cp, 0)
p.wait(timeout=5)
data = open(r"d:\zfy\_tmp\guitype_out.txt", "rb").read()
print("bytes:", data.hex(), "expect: e4b8ad41")
print("OK" if data == b"\xe4\xb8\xadA" else "FAIL")
