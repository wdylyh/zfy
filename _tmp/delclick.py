import ctypes, time
u32 = ctypes.windll.user32
WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0201, 0x0202
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd, "window not found"
# DPI x1.5。选中列表行 (100,142)->发(67,95)；删除按钮中心物理(174,678)->发(116,452)
def click(x, y):
    lp = (y << 16) | x
    u32.PostMessageW(hwnd, WM_LBUTTONDOWN, 1, lp)
    time.sleep(0.03)
    u32.PostMessageW(hwnd, WM_LBUTTONUP, 0, lp)
    time.sleep(0.03)
click(67, 95)      # 选中行
time.sleep(0.2)
click(116, 452)    # 删除 -> 应变"确认?"
print("armed")
