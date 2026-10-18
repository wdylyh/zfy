import io
p = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p, encoding="utf-8").read()

def rep(old, new):
    global s
    assert s.count(old) == 1, ("MISS: " + old[:50])
    s = s.replace(old, new)

rep("""                    if self.mx >= self.menus[mi].x
                        and self.mx < self.menus[mi].x + self.menus[mi].tw
""",
    """                    if self.mx >= self.menus[mi].x and self.mx < self.menus[mi].x + self.menus[mi].tw
""")

rep("""            if px >= self.menus[mi].x and px < self.menus[mi].x + iw
                and py >= iy and py < iy + ih
""",
    """            if px >= self.menus[mi].x and px < self.menus[mi].x + iw and py >= iy and py < iy + ih
""")

rep("""                        let bool hov = self.mx >= self.menus[i].x
                            and self.mx < self.menus[i].x + iw
                            and self.my >= iy and self.my < iy + ih
""",
    """                        let bool hov = self.mx >= self.menus[i].x and self.mx < self.menus[i].x + iw and self.my >= iy and self.my < iy + ih
""")

io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
