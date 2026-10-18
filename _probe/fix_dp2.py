import io
p = r"D:\zfy\_probe\dp.zfy"
s = io.open(p, encoding="utf-8").read()
old = """        frames++
    gui_close()
"""
new = """        frames++
    output("loop end: alive=", gui_alive(), " frames=", frames)
    gui_close()
"""
assert s.count(old) == 1
s = s.replace(old, new)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
