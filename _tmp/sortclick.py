import ctypes, time
u32 = ctypes.windll.user32
WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0201, 0x0202
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd, "window not found"
# 排序按钮中心物理 (672,678) -> DPI x1.5 -> 发 (448,452)
def click(x, y):
    lp = (y << 16) | x
    u32.PostMessageW(hwnd, WM_LBUTTONDOWN, 1, lp)
    time.sleep(0.03)
    u32.PostMessageW(hwnd, WM_LBUTTONUP, 0, lp)
    time.sleep(0.03)
click(448, 452)
print("done")
