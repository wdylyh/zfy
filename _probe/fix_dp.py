import io
p = r"D:\zfy\_probe\dp.zfy"
s = io.open(p, encoding="utf-8").read()
s = s.replace("        pass_frame()\n", "")
s = s.replace('gui_fill_rect(0, 0, gui_w(), gui_h(), 0x202028)\n',
              'gui_fill_rect(0, 0, gui_w(), gui_h(), 0x202028)\n        gui_draw_text(20, 20, "frame", 0xFFFFFF)\n')
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
