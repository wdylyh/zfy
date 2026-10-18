import io
p = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p, encoding="utf-8").read()

def rep(old, new):
    global s
    assert s.count(old) == 1, ("NOT FOUND or DUP: " + old[:60])
    s = s.replace(old, new)

# 1) App struct 加菜单字段
rep("""    TextArea[] texts
    Checkbox[] checks
    i32 mx = -1""",
    """    TextArea[] texts
    Checkbox[] checks
    Menu[] menus
    bool menu_dirty = false
    i32 mx = -1""")

# 2) add_checkbox 后加 add_menu / close_menus
rep("""    fn void add_checkbox(let Checkbox c)
        self.checks = push(self.checks, c)""",
    """    fn void add_checkbox(let Checkbox c)
        self.checks = push(self.checks, c)

    fn void add_menu(let Menu m)
        self.menus = push(self.menus, m)
        self.menu_dirty = true

    // 关闭全部下拉（点击空白/打开新菜单/选中项后调用）
    fn void close_menus()
        let i32 i = 0
        while i < length(self.menus)
            if self.menus[i].open
                self.menus[i].open = false
                self.menus[i].dirty = true
            i++
        if self.menu_dirty == false
            self.menu_dirty = true

    // 菜单栏高度（物理 px）
    fn i32 menu_bar_h()
        return LH() + 6 * SC() / 100""")

# 3) invalidate_all 补 menu_dirty
rep("""        i = 0
        while i < length(self.checks)
            self.checks[i].dirty = true
            i++

    // 一帧：泵事件 → 更新 → 脏区重绘 → 按需 present""",
    """        i = 0
        while i < length(self.checks)
            self.checks[i].dirty = true
            i++
        self.menu_dirty = true

    // 一帧：泵事件 → 更新 → 脏区重绘 → 按需 present""")

# 4) step 里 EV_MOVE 时若下拉打开则强制重绘（悬停高亮跟随）
rep("""            if e.typ == EV_MOVE
                self.mx = cast(e.x, i32)
                self.my = cast(e.y, i32)
                self.on_hover()""",
    """            if e.typ == EV_MOVE
                self.mx = cast(e.x, i32)
                self.my = cast(e.y, i32)
                self.on_hover()
                let i32 mi = 0
                while mi < length(self.menus)
                    if self.menus[mi].open
                        self.menu_dirty = true
                    mi++""")

# 5) on_click 开头插菜单栏处理（优先级最高）
rep("""    fn void on_click()
        let bool press = self.ldown and not self.ldown_prev
        let bool release = not self.ldown and self.ldown_prev""",
    """    fn void on_click()
        let bool press = self.ldown and not self.ldown_prev
        let bool release = not self.ldown and self.ldown_prev
        // ---- 菜单栏（优先于一切组件） ----
        if press and length(self.menus) > 0
            let i32 mbh = self.menu_bar_h()
            let bool in_bar = self.my < mbh
            let bool handled = false
            let i32 mi = 0
            // 下拉打开时：条目命中 > 其他标题 > 空白关闭
            mi = 0
            while mi < length(self.menus)
                if self.menus[mi].open
                    let i32 it = self.menu_item_at(mi, self.mx, self.my)
                    if it >= 0
                        self.menus[mi].sel = it
                        self.menus[mi].clicks++
                        self.menus[mi].open = false
                        self.menus[mi].dirty = true
                        self.menu_dirty = true
                        handled = true
                mi++
            if not handled and in_bar
                mi = 0
                while mi < length(self.menus)
                    if self.mx >= self.menus[mi].x
                        and self.mx < self.menus[mi].x + self.menus[mi].tw
                        let bool was = self.menus[mi].open
                        self.close_menus()
                        self.menus[mi].open = not was
                        self.menus[mi].dirty = true
                        self.menu_dirty = true
                        handled = true
                    mi++
            if not handled
                self.close_menus()
            self.ldown_prev = self.ldown
            return""")

# 6) flush_dirty 开头画菜单栏（title 行 + 打开的下拉）
anchor = "    fn void flush_dirty()\n"
menu_draw = """    // 下拉菜单条目命中：返回条目索引（-1 = 未命中）
    fn i32 menu_item_at(let i32 mi, let i32 px, let i32 py)
        let u32 u = SC()
        let i32 mbh = LH() + 6 * u / 100
        let i32 iw = self.menu_item_w(mi)
        let i32 ih = LH() + 4 * u / 100
        let i32 n = length(self.menus[mi].items)
        let i32 i = 0
        while i < n
            let i32 iy = mbh + i * ih
            if px >= self.menus[mi].x and px < self.menus[mi].x + iw
                and py >= iy and py < iy + ih
                return i
            i++
        return -1

    // 下拉面板宽度（最长条目 + 内边距）
    fn i32 menu_item_w(let i32 mi)
        let u32 u = SC()
        let i32 iw = 0
        let i32 i = 0
        while i < length(self.menus[mi].items)
            let i32 twi = gui_text_w(self.menus[mi].items[i])
            if twi > iw
                iw = twi
            i++
        return iw + 24 * u / 100

    // 布局菜单标题横向位置（加菜单/改标题后调用一次即可；draw 也会自愈）
    fn void layout_menus()
        let u32 u = SC()
        let i32 px = 6 * u / 100
        let i32 i = 0
        while i < length(self.menus)
            self.menus[i].x = px
            self.menus[i].tw = gui_text_w(self.menus[i].title) + 16 * u / 100
            px = px + self.menus[i].tw
            self.menus[i].dirty = true
            i++
        self.menu_dirty = true

    fn void draw_menu_bar()
        let u32 u = SC()
        let i32 mbh = LH() + 6 * u / 100
        if length(self.menus) == 0
            return
        let i32 nopen = 0
        let i32 i = 0
        while i < length(self.menus)
            if self.menus[i].open
                nopen++
            i++
        if self.menu_dirty or nopen > 0
            gui_fill_rect(0, 0, gui_w(), mbh, C_PANEL)
            gui_fill_rect(0, mbh - 1, gui_w(), 1, C_BORDER)
            i = 0
            while i < length(self.menus)
                let Menu m = self.menus[i]
                let bool hot = self.my < mbh and self.mx >= m.x and self.mx < m.x + m.tw
                if m.open
                    gui_fill_rect(m.x, 0, m.tw, mbh, C_HOT)
                else
                    if hot
                        gui_fill_rect(m.x, 0, m.tw, mbh, C_PANEL)
                gui_draw_text(m.x + 8 * u / 100, 4 * u / 100, m.title, C_TEXT)
                i++
            // 下拉面板（打开时覆盖在内容之上，最后画）
            i = 0
            while i < length(self.menus)
                if self.menus[i].open
                    let i32 iw = self.menu_item_w(i)
                    let i32 ih = LH() + 4 * u / 100
                    let i32 n = length(self.menus[i].items)
                    gui_fill_rect(self.menus[i].x, mbh, iw, n * ih + 4 * u / 100, C_PANEL)
                    gui_rect(self.menus[i].x, mbh, iw, n * ih + 4 * u / 100, C_BORDER)
                    let i32 j = 0
                    while j < n
                        let i32 iy = mbh + j * ih
                        let bool hov = self.mx >= self.menus[i].x
                            and self.mx < self.menus[i].x + iw
                            and self.my >= iy and self.my < iy + ih
                        if hov
                            gui_fill_rect(self.menus[i].x + 1, iy, iw - 2, ih, C_HOT)
                        gui_draw_text(self.menus[i].x + 12 * u / 100, iy + 2 * u / 100,
                                      self.menus[i].items[j], C_TEXT)
                        j++
                i++
            self.menu_dirty = false

    fn void flush_dirty()
"""
rep(anchor, menu_draw)

# 7) flush_dirty 体内先画菜单栏（找 flush_dirty 原函数体第一条语句）
rep("""    fn void flush_dirty()
        let i32 i = 0""",
    """    fn void flush_dirty()
        self.draw_menu_bar()
        let i32 i = 0""")

io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
