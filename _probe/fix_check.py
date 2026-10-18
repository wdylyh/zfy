# -*- coding: utf-8 -*-
import io
p = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p, encoding="utf-8").read()
needle = chr(92) + "u2713"          # backslash + u2713
assert needle in s, "needle missing"
s = s.replace(needle, chr(0x2713))
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
