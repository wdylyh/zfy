import ctypes, time
u32 = ctypes.windll.user32
WM_CHAR, WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0102, 0x0200, 0x0201, 0x0202
hwnd = u32.FindWindowW(None, "selprobe")
assert hwnd, "no selprobe window"
DPI = 1.5
def P(v): return int(v / DPI)
def mouse(msg, x, y):
    u32.PostMessageW(hwnd, msg, msg == WM_LBUTTONDOWN and 1 or 0, (P(y) << 16) | P(x)); time.sleep(0.03)
def ch(cp):
    u32.PostMessageW(hwnd, WM_CHAR, cp, 0); time.sleep(0.03)
def force_fg(hwnd):
    # 强制前台：重试 + SwitchToThisWindow 兜底
    for i in range(10):
        u32.keybd_event(0x12, 0, 0, 0); time.sleep(0.03)
        u32.SetForegroundWindow(hwnd); time.sleep(0.1)
        u32.keybd_event(0x12, 0, 2, 0); time.sleep(0.05)
        if u32.GetForegroundWindow() == hwnd:
            print("fg ok (alt):", True)
            return
    ctypes.windll.user32.SwitchToThisWindow(hwnd, True); time.sleep(0.2)
    print("fg ok (switch):", u32.GetForegroundWindow() == hwnd)
def shift_home():
    # 真键注入：Shift down -> Home down/up -> Shift up（须真前台）
    force_fg(hwnd)
    u32.keybd_event(0x10, 0, 0, 0); time.sleep(0.05)
    u32.keybd_event(0x24, 0, 0, 0); time.sleep(0.05)
    u32.keybd_event(0x24, 0, 2, 0); time.sleep(0.05)
    u32.keybd_event(0x10, 0, 2, 0); time.sleep(0.1)
mouse(WM_LBUTTONDOWN, 200, 42); mouse(WM_LBUTTONUP, 200, 42); time.sleep(0.2)
for c in "hello":
    ch(ord(c))
time.sleep(0.2)
force_fg(hwnd)
u32.keybd_event(0x5A, 0, 0, 0); time.sleep(0.05)   # 'Z' keybd_event 链路测试
u32.keybd_event(0x5A, 0, 2, 0); time.sleep(0.1)
shift_home()
time.sleep(0.4)
print("done: hello + keybd Z + shift+home")
