import ctypes, time
u32 = ctypes.windll.user32
WM_CHAR, WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0102, 0x0200, 0x0201, 0x0202
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd, "no window"
DPI = 1.5
def P(v): return int(v / DPI)
def mouse(msg, x, y):
    u32.PostMessageW(hwnd, msg, msg == WM_LBUTTONDOWN and 1 or 0, (P(y) << 16) | P(x)); time.sleep(0.02)
def ch(cp):
    u32.PostMessageW(hwnd, WM_CHAR, cp, 0); time.sleep(0.02)
def force_fg():
    for i in range(10):
        u32.keybd_event(0x12, 0, 0, 0); time.sleep(0.03)
        u32.SetForegroundWindow(hwnd); time.sleep(0.1)
        u32.keybd_event(0x12, 0, 2, 0); time.sleep(0.05)
        if u32.GetForegroundWindow() == hwnd:
            return
    u32.SwitchToThisWindow(hwnd, True); time.sleep(0.2)
mouse(WM_LBUTTONDOWN, 700, 30); mouse(WM_LBUTTONUP, 700, 30); time.sleep(0.2)
for c in "hello":
    ch(ord(c))
time.sleep(0.2)
# Shift+Home 真键（须真前台：keybd_event 依赖系统键盘焦点）
force_fg()
u32.keybd_event(0x10, 0, 0, 0); time.sleep(0.05)
u32.keybd_event(0x24, 0, 0, 0); time.sleep(0.05)
u32.keybd_event(0x24, 0, 2, 0); time.sleep(0.05)
u32.keybd_event(0x10, 0, 2, 0); time.sleep(0.4)
print("done: hello + shift+home on videolib")
