import ctypes, time
u32 = ctypes.windll.user32
WM_CHAR = 0x0102
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd, "window not found"
def ch(cp, d=0.02):
    u32.PostMessageW(hwnd, WM_CHAR, cp, 0)
    time.sleep(d)
def click(x, y):
    lp = (y << 16) | x
    u32.PostMessageW(hwnd, 0x0201, 1, lp)
    time.sleep(0.02)
    u32.PostMessageW(hwnd, 0x0202, 0, lp)
    time.sleep(0.05)
click(466, 200)     # 点击详情 TextArea 中央（物理 (700,300)），光标定位中间
time.sleep(0.3)
ch(0x4E2D); ch(0x6587); ch(ord('a'))   # 中文a
time.sleep(0.4)
print("done")
