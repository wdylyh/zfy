# -*- coding: utf-8 -*-
import io
p = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, (old, s.count(old))
    s = s.replace(old, new)

# Label.draw
rep("gui_fill_rect(self.x - 2, self.y - 2, tw + 4, LH, C_BG)",
    "gui_fill_rect(self.x - 2, self.y - 2, tw + 4, LH(), C_BG)")
# Button.draw 文本垂直居中
rep("gui_draw_text(self.x + (self.w - tw) / 2, self.y + (self.h - LH) / 2 + 2, self.text, C_TEXT)",
    "gui_draw_text(self.x + (self.w - tw) / 2, self.y + (self.h - LH()) / 2 + 2 * SC() / 100, self.text, C_TEXT)")
# InputBox.hit
rep("return mx >= self.x and mx < self.x + self.w and my >= self.y and my < self.y + LH + 8",
    "return mx >= self.x and mx < self.x + self.w and my >= self.y and my < self.y + LH() + 8 * SC() / 100")
# InputBox.draw
rep("""    fn void draw()
        gui_fill_rect(self.x, self.y, self.w, LH + 8, C_PANEL)
        if self.focus
            gui_rect(self.x, self.y, self.w, LH + 8, C_ACCENT)
        else
            gui_rect(self.x, self.y, self.w, LH + 8, C_BORDER)
        gui_draw_text(self.x + 6, self.y + 5, self.text, C_TEXT)
        if self.focus
            let i32 tw = gui_text_w(self.text)
            gui_fill_rect(self.x + 8 + tw, self.y + 5, 2, LH - 4, C_TEXT)
        self.dirty = false""",
    """    fn void draw()
        let i32 hh = LH() + 8 * SC() / 100
        gui_fill_rect(self.x, self.y, self.w, hh, C_PANEL)
        if self.focus
            gui_rect(self.x, self.y, self.w, hh, C_ACCENT)
        else
            gui_rect(self.x, self.y, self.w, hh, C_BORDER)
        gui_draw_text(self.x + 6 * SC() / 100, self.y + 5 * SC() / 100, self.text, C_TEXT)
        if self.focus
            let i32 tw = gui_text_w(self.text)
            gui_fill_rect(self.x + 8 * SC() / 100 + tw, self.y + 5 * SC() / 100, 2 * SC() / 100, LH() - 4 * SC() / 100, C_TEXT)
        self.dirty = false""")
# Slider.draw
rep("""    fn void draw()
        gui_fill_rect(self.x, self.y + 8, self.w, 4, C_PANEL)
        gui_rect(self.x, self.y + 8, self.w, 4, C_BORDER)
        let i32 fx = self.x + (self.w - 2) * self.value / 100
        if fx > self.x
            gui_fill_rect(self.x, self.y + 8, fx - self.x, 4, C_ACCENT)
        if self.dragging
            gui_fill_rect(fx - 5, self.y, 10, 20, C_HOT)
        else
            gui_fill_rect(fx - 5, self.y, 10, 20, C_ACCENT)
        self.dirty = false""",
    """    fn void draw()
        let i32 u = SC()
        gui_fill_rect(self.x, self.y + 8 * u / 100, self.w, 4 * u / 100, C_PANEL)
        gui_rect(self.x, self.y + 8 * u / 100, self.w, 4 * u / 100, C_BORDER)
        let i32 fx = self.x + (self.w - 2 * u / 100) * self.value / 100
        if fx > self.x
            gui_fill_rect(self.x, self.y + 8 * u / 100, fx - self.x, 4 * u / 100, C_ACCENT)
        if self.dragging
            gui_fill_rect(fx - 5 * u / 100, self.y, 10 * u / 100, 20 * u / 100, C_HOT)
        else
            gui_fill_rect(fx - 5 * u / 100, self.y, 10 * u / 100, 20 * u / 100, C_ACCENT)
        self.dirty = false""")
# Slider.hit_wide
rep("return mx >= self.x and mx < self.x + self.w and my >= self.y - 6 and my < self.y + 26",
    "return mx >= self.x and mx < self.x + self.w and my >= self.y - 6 * SC() / 100 and my < self.y + 26 * SC() / 100")
# ProgressBar.draw
rep("""        gui_fill_rect(self.x, self.y, self.w, 18, C_PANEL)
        gui_rect(self.x, self.y, self.w, 18, C_BORDER)
        let i32 fw = (self.w - 4) * self.value / 100
        if fw > 0
            gui_fill_rect(self.x + 2, self.y + 2, fw, 14, self.color)""",
    """        let i32 u = SC()
        gui_fill_rect(self.x, self.y, self.w, 18 * u / 100, C_PANEL)
        gui_rect(self.x, self.y, self.w, 18 * u / 100, C_BORDER)
        let i32 fw = (self.w - 4 * u / 100) * self.value / 100
        if fw > 0
            gui_fill_rect(self.x + 2 * u / 100, self.y + 2 * u / 100, fw, 14 * u / 100, self.color)""")
# ListBox.draw
rep("""    fn void draw()
        let i32 hgt = self.rows * LH + 8
        gui_fill_rect(self.x, self.y, self.w, hgt, C_PANEL)
        gui_rect(self.x, self.y, self.w, hgt, C_BORDER)
        let i32 n = length(self.items)
        let i32 last = self.top + self.rows
        if last > n
            last = n
        let i32 i = self.top
        while i < last
            let i32 row = i - self.top
            let i32 ry = self.y + 4 + row * LH""",
    """    fn void draw()
        let i32 hgt = self.rows * LH() + 8 * SC() / 100
        gui_fill_rect(self.x, self.y, self.w, hgt, C_PANEL)
        gui_rect(self.x, self.y, self.w, hgt, C_BORDER)
        let i32 n = length(self.items)
        let i32 last = self.top + self.rows
        if last > n
            last = n
        let i32 i = self.top
        while i < last
            let i32 row = i - self.top
            let i32 ry = self.y + 4 * SC() / 100 + row * LH()""")
rep("""            if i == self.sel
                gui_fill_rect(self.x + 2, ry - 1, self.w - 4, LH, C_ACCENT)
                gui_draw_text(self.x + 8, ry, self.items[i], 0xFFFFFF)
            else
                gui_draw_text(self.x + 8, ry, self.items[i], C_TEXT)""",
    """            if i == self.sel
                gui_fill_rect(self.x + 2 * SC() / 100, ry - 1, self.w - 4 * SC() / 100, LH(), C_ACCENT)
                gui_draw_text(self.x + 8 * SC() / 100, ry, self.items[i], 0xFFFFFF)
            else
                gui_draw_text(self.x + 8 * SC() / 100, ry, self.items[i], C_TEXT)""")
# App list 点击命中
rep("""            if press and self.mx >= self.lists[i].x and self.mx < self.lists[i].x + self.lists[i].w
                let i32 rows = length(self.lists[i].items)
                let i32 hgt = self.lists[i].rows * LH + 8
                if self.my >= self.lists[i].y and self.my < self.lists[i].y + hgt
                    let i32 row = (self.my - self.lists[i].y - 4) / LH""",
    """            if press and self.mx >= self.lists[i].x and self.mx < self.lists[i].x + self.lists[i].w
                let i32 rows = length(self.lists[i].items)
                let i32 hgt = self.lists[i].rows * LH() + 8 * SC() / 100
                if self.my >= self.lists[i].y and self.my < self.lists[i].y + hgt
                    let i32 row = (self.my - self.lists[i].y - 4 * SC() / 100) / LH()""")
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("widgets.zfy OK")
