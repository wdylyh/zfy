import ctypes, time
u32 = ctypes.windll.user32
hwnd = u32.FindWindowW(None, "zfy 视频管理器")
assert hwnd, "no window"
# 预写剪贴板
u32.OpenClipboard(0); u32.EmptyClipboard()
k32 = ctypes.windll.kernel32
data = "hello clip!"
h = k32.GlobalAlloc(0x2002, (len(data) + 1) * 2)   # GMEM_MOVEABLE|GMEM_ZEROINIT
p = k32.GlobalLock(h)
ctypes.memmove(p, ctypes.create_unicode_buffer(data), (len(data) + 1) * 2)
k32.GlobalUnlock(h)
u32.SetClipboardData(13, h)
u32.CloseClipboard()
print("clip set:", data)
# 只注入 Ctrl+V
u32.keybd_event(0x12, 0, 0, 0); time.sleep(0.05)
u32.SetForegroundWindow(hwnd); time.sleep(0.2)
u32.keybd_event(0x12, 0, 2, 0); time.sleep(0.1)
u32.keybd_event(0x11, 0, 0, 0); time.sleep(0.05)
u32.keybd_event(0x56, 0, 0, 0); time.sleep(0.05)
u32.keybd_event(0x56, 0, 2, 0); time.sleep(0.05)
u32.keybd_event(0x11, 0, 2, 0); time.sleep(0.4)
print("done: ctrlV only")
