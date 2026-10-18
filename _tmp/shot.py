import ctypes, ctypes.wintypes as wt
u32 = ctypes.windll.user32; g32 = ctypes.windll.gdi32
try:
    u32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
except Exception:
    pass
PW_RENDERFULLCONTENT = 2
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd, "window not found"
r = wt.RECT(); u32.GetClientRect(hwnd, ctypes.byref(r))
w, h = r.right, r.bottom
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

# GetDIBits 输出 BGRA；PNG RGBA 需要 R/B 交换
data = bytearray(buf.raw)
data[0::4], data[2::4] = buf.raw[2::4], buf.raw[0::4]

# 写 PNG（用最小 zlib 封装）
import zlib, struct
def png(path, w, h, data):
    raw = b"".join(b"\x00" + bytes(data[y*w*4:(y+1)*w*4]) for y in range(h))
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c))
    hdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", hdr)
        + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
png(r"d:\zfy\_tmp\win.png", w, h, data)
print("size:", w, h)
