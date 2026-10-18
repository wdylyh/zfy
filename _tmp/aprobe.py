import ctypes, time
u32 = ctypes.windll.user32
WM_CHAR, WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0102, 0x0200, 0x0201, 0x0202
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd, "no window"
DPI = 1.5
def P(v): return int(v / DPI)
def ch(cp):
    u32.PostMessageW(hwnd, WM_CHAR, cp, 0); time.sleep(0.02)
def mouse(msg, x, y):
    u32.PostMessageW(hwnd, msg, msg == WM_LBUTTONDOWN and 1 or 0, (P(y) << 16) | P(x)); time.sleep(0.02)
def ctrl(vk):
    # Alt 空按解除 SetForegroundWindow 限制，再把目标窗口切到前台
    u32.keybd_event(0x12, 0, 0, 0); time.sleep(0.05)
    u32.SetForegroundWindow(hwnd); time.sleep(0.2)
    u32.keybd_event(0x12, 0, 2, 0); time.sleep(0.1)
    print("fg:", u32.GetForegroundWindow() == hwnd)
    u32.keybd_event(0x11, 0, 0, 0); time.sleep(0.05)
    u32.keybd_event(vk, 0, 0, 0); time.sleep(0.05)
    u32.keybd_event(vk, 0, 2, 0); time.sleep(0.05)
    u32.keybd_event(0x11, 0, 2, 0); time.sleep(0.1)
mouse(WM_LBUTTONDOWN, 700, 30); mouse(WM_LBUTTONUP, 700, 30); time.sleep(0.2)
for c in "abc":
    ch(ord(c))
time.sleep(0.2)
ctrl(0x41)   # 仅 Ctrl+A
time.sleep(0.4)
print("done: ctrlA only")
