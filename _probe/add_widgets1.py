# -*- coding: utf-8 -*-
import io
p = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, ("NOT UNIQUE/FOUND", old[:80], s.count(old))
    s = s.replace(old, new)

# 0) use 组加新常量
rep("use gui::{gui_open, gui_alive, gui_close, gui_w, gui_h, gui_dpi, gui_fill_rect, gui_rect, gui_draw_text, gui_text_w, gui_present, gui_poll, gui_frame_sleep, Event, EV_MOVE, EV_LDOWN, EV_LUP, EV_KEY, EV_WHEEL}",
    "use gui::{gui_open, gui_alive, gui_close, gui_w, gui_h, gui_dpi, gui_fill_rect, gui_rect, gui_draw_text, gui_text_w, gui_present, gui_poll, gui_frame_sleep, Event, EV_MOVE, EV_LDOWN, EV_LUP, EV_KEY, EV_WHEEL, KEY_EXT, KEY_CTRL, gui_clip_get}")

# 1) InputBox：扩展键（>=KEY_EXT）不当可打印字符
rep("""        if k >= 32
            // 可打印（WM_CHAR 已做 Shift 映射）；中文/全角按 UTF-16 码元追加
            self.text = self.text + cast(k, char)
            self.dirty = true
            return true
        return false""",
    """        if k >= 32 and k < KEY_EXT
            // 可打印（WM_CHAR 已做 Shift 映射）；中文/全角按 UTF-16 码元追加
            self.text = self.text + cast(k, char)
            self.dirty = true
            return true
        return false""")

# 2) App 字段
rep("""    ListBox[] lists
    i32 mx = -1""",
    """    ListBox[] lists
    TextArea[] texts
    Checkbox[] checks
    i32 mx = -1""")

# 3) add 方法（挂在 add_list 后）
rep("""    fn void add_list(let ListBox lb)
        self.lists = push(self.lists, lb)
""",
    """    fn void add_list(let ListBox lb)
        self.lists = push(self.lists, lb)

    fn void add_text(let TextArea t)
        self.texts = push(self.texts, t)

    fn void add_checkbox(let Checkbox c)
        self.checks = push(self.checks, c)
""")

# 4) invalidate_all 补两组
rep("""        i = 0
        while i < length(self.lists)
            self.lists[i].dirty = true
            i++
""",
    """        i = 0
        while i < length(self.lists)
            self.lists[i].dirty = true
            i++
        i = 0
        while i < length(self.texts)
            self.texts[i].dirty = true
            i++
        i = 0
        while i < length(self.checks)
            self.checks[i].dirty = true
            i++
""")

# 5) step 的 wheel 分支补 textarea 滚动
rep("""            if e.typ == EV_WHEEL
                let i32 i = 0
                while i < length(self.lists)
                    self.lists[i].scroll(cast(e.key, i32))
                    if self.lists[i].dirty
                        self.any_dirty = true
                    i++
""",
    """            if e.typ == EV_WHEEL
                let i32 i = 0
                while i < length(self.lists)
                    self.lists[i].scroll(cast(e.key, i32))
                    if self.lists[i].dirty
                        self.any_dirty = true
                    i++
                i = 0
                while i < length(self.texts)
                    self.texts[i].scroll(cast(e.key, i32))
                    if self.texts[i].dirty
                        self.any_dirty = true
                    i++
""")

# 6) on_click：聚焦互斥（inputs 与 texts），checkbox 状态机
rep("""        // 输入框聚焦
        let i32 i = 0
        while i < length(self.inputs)
            if press
                self.inputs[i].set_focus(self.inputs[i].hit(self.mx, self.my))
            if self.inputs[i].dirty
                self.any_dirty = true
            i++
""",
    """        // 输入框聚焦：press 时先全部失焦（inputs 与 texts 互斥），再按命中恢复
        let i32 i = 0
        if press
            i = 0
            while i < length(self.inputs)
                self.inputs[i].set_focus(false)
                i++
            i = 0
            while i < length(self.texts)
                self.texts[i].set_focus(false)
                i++
        i = 0
        while i < length(self.inputs)
            if press
                self.inputs[i].set_focus(self.inputs[i].hit(self.mx, self.my))
            if self.inputs[i].dirty
                self.any_dirty = true
            i++
        i = 0
        while i < length(self.texts)
            if press
                self.texts[i].set_focus(self.texts[i].hit(self.mx, self.my))
                if self.texts[i].focus
                    self.texts[i].place_cursor(self.mx, self.my)
            if self.texts[i].dirty
                self.any_dirty = true
            i++
        // 复选框
        i = 0
        while i < length(self.checks)
            let bool inside = self.checks[i].hit(self.mx, self.my)
            if press and inside
                self.checks[i].pressed = true
                self.checks[i].dirty = true
            if release and self.checks[i].pressed
                self.checks[i].pressed = false
                self.checks[i].checked = not self.checks[i].checked
                self.checks[i].clicks++
                self.checks[i].dirty = true
            if self.checks[i].dirty
                self.any_dirty = true
            i++
""")

# 7) on_hover 补 checkbox
rep("""    fn void on_hover()
        let i32 i = 0
        while i < length(self.buttons)
            let bool h = self.buttons[i].hit(self.mx, self.my) and not self.ldown
            if h != self.buttons[i].hot
                self.buttons[i].hot = h
                self.buttons[i].dirty = true
            i++
""",
    """    fn void on_hover()
        let i32 i = 0
        while i < length(self.buttons)
            let bool h = self.buttons[i].hit(self.mx, self.my) and not self.ldown
            if h != self.buttons[i].hot
                self.buttons[i].hot = h
                self.buttons[i].dirty = true
            i++
        i = 0
        while i < length(self.checks)
            let bool hc = self.checks[i].hit(self.mx, self.my) and not self.ldown
            if hc != self.checks[i].hot
                self.checks[i].hot = hc
                self.checks[i].dirty = true
            i++
""")

# 8) on_key 路由 textarea
rep("""    fn void on_key(let i64 k)
        let i32 i = 0
        while i < length(self.inputs)
            if self.inputs[i].focus
                if self.inputs[i].handle_key(k)
                    self.any_dirty = true
            i++
""",
    """    fn void on_key(let i64 k)
        let i32 i = 0
        while i < length(self.inputs)
            if self.inputs[i].focus
                if self.inputs[i].handle_key(k)
                    self.any_dirty = true
            i++
        i = 0
        while i < length(self.texts)
            if self.texts[i].focus
                if self.texts[i].handle_key(k)
                    self.any_dirty = true
            i++
""")

# 9) flush_dirty 补两组
rep("""        i = 0
        while i < length(self.lists)
            if self.lists[i].dirty
                self.lists[i].draw()
                self.any_dirty = true
            i++
""",
    """        i = 0
        while i < length(self.lists)
            if self.lists[i].dirty
                self.lists[i].draw()
                self.any_dirty = true
            i++
        i = 0
        while i < length(self.texts)
            if self.texts[i].dirty
                self.texts[i].draw()
                self.any_dirty = true
            i++
        i = 0
        while i < length(self.checks)
            if self.checks[i].dirty
                self.checks[i].draw()
                self.any_dirty = true
            i++
""")

io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("App integration OK")
