import ctypes, time
u32 = ctypes.windll.user32
WM_CHAR, WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0102, 0x0200, 0x0201, 0x0202
hwnd = u32.FindWindowW(None, "selprobe")
assert hwnd, "no selprobe window"
# DPI-unaware 进程 PostMessage 鼠标坐标会被系统 ×1.5 虚拟化——目标收到 1.5 倍
# 因此发送前须 //1.5，使目标收到期望的物理坐标
DPI = 1.5
def P(v): return int(v / DPI)
def mouse(msg, x, y):
    u32.PostMessageW(hwnd, msg, msg == WM_LBUTTONDOWN and 1 or 0, (P(y) << 16) | P(x)); time.sleep(0.03)
def ch(cp):
    u32.PostMessageW(hwnd, WM_CHAR, cp, 0); time.sleep(0.03)
for c in "hello":
    ch(ord(c))
time.sleep(0.2)
# 目标物理坐标：拖选 (200,42)->(60,42)
mouse(WM_LBUTTONDOWN, 200, 42)
for x in (170, 140, 100, 60):
    mouse(WM_MOUSEMOVE, x, 42)
mouse(WM_LBUTTONUP, 60, 42)
time.sleep(0.4)
print("done")
