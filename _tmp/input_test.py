import ctypes, time, sys
u32 = ctypes.windll.user32
WM_CHAR = 0x0102
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd, "window not found"
def ch(cp):
    u32.PostMessageW(hwnd, WM_CHAR, cp, 0)
    time.sleep(0.02)
def click(x, y):
    lp = (y << 16) | x
    u32.PostMessageW(hwnd, 0x0201, 1, lp)
    time.sleep(0.02)
    u32.PostMessageW(hwnd, 0x0202, 0, lp)
    time.sleep(0.05)
click(200, 63)        # 聚焦搜索框（物理约 (300,95)）
time.sleep(0.3)
for cp in (0x4E2D, ord('A'), ord('B')):   # 中 A B
    ch(cp)
time.sleep(0.3)
print("typed, see shot1")
