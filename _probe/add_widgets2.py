# -*- coding: utf-8 -*-
import io
p = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p, encoding="utf-8").read()

block = '''

// ===== 字符串辅助（TextArea 用；按 UTF-8 字节索引，闭区间切片） =====

// 前 i 字节（i<=0 得空串）
fn string prefix(let string s, let i32 i)
    if i <= 0
        return ""
    return s[0, i - 1]

// 从第 i 字节到串尾（i>=len 得空串）
fn string suffix(let string s, let i32 i)
    let i32 n = length(s)
    if i >= n
        return ""
    return s[i, n - 1]

// s[i] 是否 UTF-8 continuation 字节（0x80..0xBF）
fn bool is_cont(let string s, let i32 i)
    if i < 0 or i >= length(s)
        return false
    let i32 b = ord(s[i])
    return b >= 0x80 and b < 0xC0

// 从位置 i 向前对齐到码点起点
fn i32 align_back(let string s, let i32 i)
    let i32 p = i
    while p > 0 and is_cont(s, p)
        p--
    return p

// 从位置 i 向后对齐到下一码点起点
fn i32 align_fwd(let string s, let i32 i)
    let i32 n = length(s)
    let i32 q = i
    while q < n and is_cont(s, q)
        q++
    return q

// ===== Checkbox：复选框 =====
pub struct Checkbox
    i32 x
    i32 y
    string text
    bool checked = false      // 业务读写
    bool hot = false
    bool pressed = false
    i32 clicks = 0
    bool dirty = true

    fn i32 box_size()
        return 16 * SC() / 100

    fn bool hit(let i32 mx, let i32 my)
        let i32 bs = self.box_size()
        let i32 tw = gui_text_w(self.text)
        let i32 wfull = bs + 6 * SC() / 100 + tw
        let i32 hfull = bs
        if bs < LH()
            hfull = LH()
        return mx >= self.x and mx < self.x + wfull and my >= self.y and my < self.y + hfull

    fn void draw()
        let i32 u = SC()
        let i32 bs = self.box_size()
        let u32 fill = C_PANEL
        if self.pressed
            fill = C_DOWN
        else
            if self.hot
                fill = C_HOT
        gui_fill_rect(self.x, self.y, bs, bs, fill)
        gui_rect(self.x, self.y, bs, bs, C_BORDER)
        if self.checked
            gui_draw_text(self.x + 2 * u / 100, self.y - 2 * u / 100, "\\u2713", C_OK)
        let i32 ty = self.y + (bs - LH()) / 2
        gui_draw_text(self.x + bs + 6 * u / 100, ty, self.text, C_TEXT)
        self.dirty = false

// ===== TextArea：多行文本编辑 =====
// 光标（字节列 cx / 行 cy）、Enter 拆行、Backspace 合行、方向键/Home/End/
// Delete、滚轮滚动、Ctrl+V 粘贴（剪贴板 \\n 拆行插入）。超宽行按像素截断。
pub struct TextArea
    i32 x
    i32 y
    i32 w
    i32 h
    string[] lines
    i32 cx = 0            // 光标字节列
    i32 cy = 0            // 光标行
    i32 top = 0           // 首可见行
    bool focus = false
    bool dirty = true

    fn i32 vis_rows()
        let i32 vr = (self.h - 8 * SC() / 100) / LH()
        if vr < 1
            vr = 1
        return vr

    fn void scroll(let i32 d)
        let i32 vr = self.vis_rows()
        let i32 n = length(self.lines)
        let i32 nt = self.top + d
        if nt < 0
            nt = 0
        if n > vr
            if nt > n - vr
                nt = n - vr
        else
            nt = 0
        if nt != self.top
            self.top = nt
            self.dirty = true

    fn void clamp_scroll()
        let i32 vr = self.vis_rows()
        if self.cy < self.top
            self.top = self.cy
        if self.cy >= self.top + vr
            self.top = self.cy - vr + 1
        if self.top < 0
            self.top = 0
        self.dirty = true

    fn void set_text(let string s)
        self.lines = split(s, "\\n")
        let i32 i = 0
        while i < length(self.lines)
            self.lines[i] = trim(self.lines[i], "\\r")
            i++
        self.cx = 0
        self.cy = 0
        self.top = 0
        self.dirty = true

    fn string text()
        let string s2 = ""
        let i32 i = 0
        while i < length(self.lines)
            if i > 0
                s2 = s2 + "\\n"
            s2 = s2 + self.lines[i]
            i++
        return s2

    fn bool hit(let i32 mx, let i32 my)
        return mx >= self.x and mx < self.x + self.w and my >= self.y and my < self.y + self.h

    fn void set_focus(let bool f)
        if self.focus != f
            self.focus = f
            self.dirty = true

    // 鼠标点击定位光标
    fn void place_cursor(let i32 mx, let i32 my)
        let i32 pad = 4 * SC() / 100
        let i32 row = (my - self.y - pad) / LH()
        if row < 0
            row = 0
        self.cy = self.top + row
        let i32 nl = length(self.lines)
        if self.cy >= nl
            self.cy = nl - 1
        let string ln = self.lines[self.cy]
        let i32 target = mx - self.x - pad
        let i32 i = 0
        let i32 best = 0
        while i < length(ln)
            if gui_text_w(prefix(ln, i)) > target
                break
            best = i
            i = align_fwd(ln, i)
            if i == best
                i++
        self.cx = best
        self.clamp_scroll()

    // 替换第 cy 行并重建数组的通用入口都不需要——直接改 self.lines[cy]
    fn bool handle_key(let i64 k)
        let i32 nl = length(self.lines)
        let string ln = self.lines[self.cy]
        let i32 n = length(ln)
        if k == 8
            // Backspace：删光标前一码点；行首则与上一行合并
            if self.cx > 0
                let i32 s2 = align_back(ln, self.cx - 1)
                self.lines[self.cy] = prefix(ln, s2) + suffix(ln, self.cx)
                self.cx = s2
            else
                if self.cy > 0
                    let i32 pn = length(self.lines[self.cy - 1])
                    self.lines[self.cy - 1] = self.lines[self.cy - 1] + ln
                    let string[] out = self.lines[0, 0]
                    let i32 i = 0
                    while i < nl
                        if i != self.cy
                            out = push(out, self.lines[i])
                        i++
                    self.lines = out[1, length(out) - 1]
                    self.cy--
                    self.cx = pn
            self.clamp_scroll()
            return true
        if k == KEY_EXT + 0x2E
            // Delete：删光标处码点；行尾则吞并下一行
            if self.cx < n
                let i32 e2 = align_fwd(ln, self.cx + 1)
                self.lines[self.cy] = prefix(ln, self.cx) + suffix(ln, e2)
            else
                if self.cy < nl - 1
                    self.lines[self.cy] = ln + self.lines[self.cy + 1]
                    let string[] out = self.lines[0, 0]
                    let i32 i = 0
                    while i < nl
                        if i != self.cy + 1
                            out = push(out, self.lines[i])
                        i++
                    self.lines = out[1, length(out) - 1]
            self.clamp_scroll()
            return true
        if k == KEY_EXT + 0x25
            // Left
            if self.cx > 0
                self.cx = align_back(ln, self.cx - 1)
            else
                if self.cy > 0
                    self.cy--
                    self.cx = length(self.lines[self.cy])
            self.clamp_scroll()
            return true
        if k == KEY_EXT + 0x27
            // Right
            if self.cx < n
                self.cx = align_fwd(ln, self.cx + 1)
            else
                if self.cy < nl - 1
                    self.cy++
                    self.cx = 0
            self.clamp_scroll()
            return true
        if k == KEY_EXT + 0x26
            // Up
            if self.cy > 0
                self.cy--
                if self.cx > length(self.lines[self.cy])
                    self.cx = length(self.lines[self.cy])
                self.clamp_scroll()
            return true
        if k == KEY_EXT + 0x28
            // Down
            if self.cy < nl - 1
                self.cy++
                if self.cx > length(self.lines[self.cy])
                    self.cx = length(self.lines[self.cy])
                self.clamp_scroll()
            return true
        if k == KEY_EXT + 0x24
            self.cx = 0
            self.dirty = true
            return true
        if k == KEY_EXT + 0x23
            self.cx = n
            self.dirty = true
            return true
        if k == KEY_CTRL + 86 or k == 22
            // Ctrl+V 粘贴（86='V'；22=0x16 为 WM_CHAR 控制码兜底）
            let string clip = gui_clip_get()
            if clip != ""
                let string[] segs = split(clip, "\\n")
                let i32 ns = length(segs)
                let i32 i = 0
                while i < ns
                    segs[i] = trim(segs[i], "\\r")
                    i++
                segs[0] = prefix(ln, self.cx) + segs[0]
                segs[ns - 1] = segs[ns - 1] + suffix(ln, self.cx)
                // lines[0..cy-1] + segs + lines[cy+1..]（占位首元素后裁掉）
                let string[] out = self.lines[0, 0]
                i = 0
                while i < self.cy
                    out = push(out, self.lines[i])
                    i++
                i = 0
                while i < ns
                    out = push(out, segs[i])
                    i++
                i = self.cy + 1
                while i < nl
                    out = push(out, self.lines[i])
                    i++
                self.lines = out[1, length(out) - 1]
                self.cy = self.cy + ns - 1
                self.cx = length(segs[ns - 1]) - length(suffix(ln, self.cx))
            self.clamp_scroll()
            return true
        if k == 13 or k == 10
            // Enter：光标处拆行
            let string head = prefix(ln, self.cx)
            let string tail = suffix(ln, self.cx)
            let string[] out = self.lines[0, 0]
            let i32 i = 0
            while i < self.cy
                out = push(out, self.lines[i])
                i++
            out = push(out, head)
            out = push(out, tail)
            i = self.cy + 1
            while i < nl
                out = push(out, self.lines[i])
                i++
            self.lines = out[1, length(out) - 1]
            self.cy++
            self.cx = 0
            self.clamp_scroll()
            return true
        if k >= 32 and k < KEY_EXT
            // 可打印（含中文，WM_CHAR UTF-16 码元）：光标处插入
            self.lines[self.cy] = prefix(ln, self.cx) + cast(k, char) + suffix(ln, self.cx)
            self.cx = self.cx + length(cast(k, char))
            self.clamp_scroll()
            return true
        return false

    fn void draw()
        let i32 u = SC()
        let i32 pad = 4 * u / 100
        gui_fill_rect(self.x, self.y, self.w, self.h, C_PANEL)
        if self.focus
            gui_rect(self.x, self.y, self.w, self.h, C_ACCENT)
        else
            gui_rect(self.x, self.y, self.w, self.h, C_BORDER)
        let i32 vr = self.vis_rows()
        let i32 nl = length(self.lines)
        let i32 last = self.top + vr
        if last > nl
            last = nl
        let i32 avail = self.w - 2 * pad
        let i32 i = self.top
        while i < last
            let i32 ry = self.y + pad + (i - self.top) * LH()
            let string ln = self.lines[i]
            // 超宽行按像素截断（对齐码点）
            let i32 cnt = length(ln)
            while cnt > 0 and gui_text_w(prefix(ln, cnt)) > avail
                cnt = align_back(ln, cnt - 1)
            if cnt > 0
                gui_draw_text(self.x + pad, ry, prefix(ln, cnt), C_TEXT)
            i++
        // 光标
        if self.focus
            if self.cy >= self.top and self.cy < last
                let string ln2 = self.lines[self.cy]
                let i32 cxx = gui_text_w(prefix(ln2, self.cx))
                gui_fill_rect(self.x + pad + cxx, self.y + pad + (self.cy - self.top) * LH(), 2 * u / 100, LH(), C_TEXT)
        self.dirty = false
'''

s = s.rstrip() + "\n" + block
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("TextArea + Checkbox appended")
