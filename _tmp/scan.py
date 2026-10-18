import ctypes, ctypes.wintypes as wt
u32 = ctypes.windll.user32; g32 = ctypes.windll.gdi32
try:
    u32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
except Exception:
    pass
PW_RENDERFULLCONTENT = 2
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd
r = wt.RECT(); u32.GetClientRect(hwnd, ctypes.byref(r))
w, h = r.right, r.bottom
print("client:", w, h)
hdc = u32.GetDC(hwnd)
mem = g32.CreateCompatibleDC(hdc)
bmp = g32.CreateCompatibleBitmap(hdc, w, h)
g32.SelectObject(mem, bmp)
u32.PrintWindow(hwnd, mem, PW_RENDERFULLCONTENT)
class BMIH(ctypes.Structure):
    _fields_ = [("biSize", ctypes.c_uint32), ("biWidth", ctypes.c_int32),
        ("biHeight", ctypes.c_int32), ("biPlanes", ctypes.c_uint16),
        ("biBitCount", ctypes.c_uint16), ("biCompression", ctypes.c_uint32),
        ("biSizeImage", ctypes.c_uint32), ("biXPelsPerMeter", ctypes.c_int32),
        ("biYPelsPerMeter", ctypes.c_int32), ("biClrUsed", ctypes.c_uint32),
        ("biClrImportant", ctypes.c_uint32)]
bi = BMIH(ctypes.sizeof(BMIH), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
buf = ctypes.create_string_buffer(w * h * 4)
g32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bi), 0)
px = buf.raw
def pixel(x, y):
    i = (y * w + x) * 4
    b, g, rr = px[i], px[i+1], px[i+2]
    return (rr, g, b)
# 扫描按钮区竖列 x=300 与录入框竖列 x=800，找出非背景色段
BG = (0x24, 0x24, 0x2C)  # C_BG 0x1E1E24 近似
def scan_col(x, y0, y1, label):
    runs = []
    prev = False
    for y in range(y0, min(y1, h)):
        c = pixel(x, y)
        isbg = abs(c[0]-0x1E) < 6 and abs(c[1]-0x1E) < 6 and abs(c[2]-0x24) < 6
        if not isbg and not prev:
            start = y; prev = True
        elif isbg and prev:
            runs.append((start, y-1)); prev = False
    if prev: runs.append((start, min(y1,h)-1))
    print(label, "x=%d:" % x, runs)
scan_col(300, 600, h, "buttons")
scan_col(800, 450, h, "entry")
scan_col(60, 60, h, "list")
