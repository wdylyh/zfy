import io
p = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p, encoding="utf-8").read()

# 1) 把 Ctrl+V 的插入逻辑抽为 insert_at_cursor 方法，handle_key 调用它
old = '''        if k == KEY_CTRL + 86 or k == 22
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
            return true'''
new = '''        if k == KEY_CTRL + 86 or k == 22
            // Ctrl+V 粘贴（86='V'；22=0x16 为 WM_CHAR 控制码兜底）
            self.insert_at_cursor(gui_clip_get())
            return true'''
assert s.count(old) == 1
s = s.replace(old, new)

# 2) 在 handle_key 前插入 insert_at_cursor 方法
anchor = "    fn bool handle_key(let i64 k)\n        let i32 nl = length(self.lines)"
method = '''    // 光标处插入多行文本（\\n 拆行；空串无操作），供 Ctrl+V 与业务侧复用
    fn void insert_at_cursor(let string clip)
        let i32 nl = length(self.lines)
        let string ln = self.lines[self.cy]
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

'''
assert s.count(anchor) == 1
s = s.replace(anchor, method + anchor)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
