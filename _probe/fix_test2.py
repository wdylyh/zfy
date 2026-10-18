# -*- coding: utf-8 -*-
import io
# 1) widgets.zfy: length(char) -> length("" + char)
p1 = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p1, encoding="utf-8").read()
old = "self.cx = self.cx + length(cast(k, char))"
assert s.count(old) == 1
s = s.replace(old, "self.cx = self.cx + length(\"\" + cast(k, char))")
io.open(p1, "w", encoding="utf-8", newline="\n").write(s)

# 2) textarea_test.zfy: 接住 handle_key 返回值
p2 = r"D:\zfy\examples\textarea_test.zfy"
t = io.open(p2, encoding="utf-8").read()
lines = t.split("\n")
out = []
declared = False
for ln in lines:
    st = ln.strip()
    if st.startswith("t.handle_key("):
        if not declared:
            out.append("    let bool r = false")
            declared = True
        out.append(ln.replace("t.handle_key(", "r = t.handle_key("))
    else:
        out.append(ln)
t2 = "\n".join(out)
# chk(t.handle_key(88) == true, ...) 这类已直接用在表达式里，无需改
io.open(p2, "w", encoding="utf-8", newline="\n").write(t2)
print("ok")
