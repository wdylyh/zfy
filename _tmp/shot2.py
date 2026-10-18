import ctypes, sys
u32 = ctypes.windll.user32
gdi = ctypes.windll.gdi32
title = sys.argv[1] if len(sys.argv) > 1 else "zfy 视频管理器"
hwnd = u32.FindWindowW(None, title)
assert hwnd, "not found"
u32.SetForegroundWindow(hwnd)
import time; time.sleep(0.3)
hdc = u32.GetWindowDC(hwnd)
# PrintWindow DPI-aware
ctypes.windll.shcore.SetProcessDpiAwareness(2)
hdc = u32.GetWindowDC(hwnd)
PW_RENDERFULLCONTENT = 2
r = ctypes.wintypes.RECT() if hasattr(ctypes, "wintypes") else None
u32.GetWindowRect(hwnd, ctypes.byref(r))
w, h = r.right - r.left, r.bottom - r.top
hmem = gdi.CreateCompatibleDC(hdc)
hbmp = gdi.CreateCompatibleBitmap(hdc, w, h)
gdi.SelectObject(hmem, hbmp)
u32.PrintWindow(hwnd, hmem, PW_RENDERFULLCONTENT)
class BMIH(ctypes.Structure):
    _fields_ = [("biSize", ctypes.c_uint32), ("biWidth", ctypes.c_int32), ("biHeight", ctypes.c_int32),
                ("biPlanes", ctypes.c_uint16), ("biBitCount", ctypes.c_uint16), ("biCompression", ctypes.c_uint32),
                ("biSizeImage", ctypes.c_uint32), ("biXPelsPerMeter", ctypes.c_int32), ("biYPelsPerMeter", ctypes.c_int32),
                ("biClrUsed", ctypes.c_uint32), ("biClrImportant", ctypes.c_uint32)]
bmi = BMIH(ctypes.sizeof(BMIH), w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
buf = ctypes.create_string_buffer(w * h * 4)
gdi.GetDIBits(hmem, hbmp, 0, h, buf, ctypes.byref(bmi), 0)
# 采样 (30,30) 与 (30,65) (30,90) (30,118) 像素
for py in (30, 65, 90, 118):
    off = (py * w + 30) * 4
    b, g, rr = buf[off], buf[off+1], buf[off+2]
    print(f"y={py}: R={rr&0xff} G={g&0xff} B={b&0xff}")
