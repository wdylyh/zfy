import io
f = r'D:\zfy\stdlib\widgets.zfy'
s = io.open(f, encoding='utf-8').read()

s = s.replace('gui_rect(self.x, self.y, self.w, LH + 8, self.focus ? C_ACCENT : C_BORDER)',
'''if self.focus
            gui_rect(self.x, self.y, self.w, LH + 8, C_ACCENT)
        else
            gui_rect(self.x, self.y, self.w, LH + 8, C_BORDER)''')

s = s.replace('gui_fill_rect(fx - 5, self.y, 10, 20, self.dragging ? C_HOT : C_ACCENT)',
'''if self.dragging
            gui_fill_rect(fx - 5, self.y, 10, 20, C_HOT)
        else
            gui_fill_rect(fx - 5, self.y, 10, 20, C_ACCENT)''')

s = s.replace('gui_rect(self.x, self.y, self.w, hgt, self.sel >= 0 ? C_BORDER : C_BORDER)',
'gui_rect(self.x, self.y, self.w, hgt, C_BORDER)')

s = s.replace('gui_draw_text(self.x + 8, ry, self.items[i], i == self.sel ? 0xFFFFFF : C_TEXT)',
'''if i == self.sel
                gui_draw_text(self.x + 8, ry, self.items[i], 0xFFFFFF)
            else
                gui_draw_text(self.x + 8, ry, self.items[i], C_TEXT)''')

s = s.replace('''        let i32 si = 0
        while si < length(self.sliders)
            ref let Slider s = self.sliders[si]
            if s.dragging and self.ldown
                s.set_value((self.mx - s.x) * 100 / (s.w - 2))
            if s.dirty
                self.any_dirty = true
            si++''',
'''        let i32 si = 0
        while si < length(self.sliders)
            if self.sliders[si].dragging and self.ldown
                self.sliders[si].set_value((self.mx - self.sliders[si].x) * 100 / (self.sliders[si].w - 2))
            if self.sliders[si].dirty
                self.any_dirty = true
            si++''')

s = s.replace('''            ref let Button b = self.buttons[i]
            let bool h = b.hit(self.mx, self.my) and not self.ldown
            if h != b.hot
                b.hot = h
                b.dirty = true
            i++''',
'''            let bool h = self.buttons[i].hit(self.mx, self.my) and not self.ldown
            if h != self.buttons[i].hot
                self.buttons[i].hot = h
                self.buttons[i].dirty = true
            i++''')

s = s.replace('''            ref let InputBox ib = self.inputs[i]
            if press
                ib.set_focus(ib.hit(self.mx, self.my))
            if ib.dirty
                self.any_dirty = true
            i++''',
'''            if press
                self.inputs[i].set_focus(self.inputs[i].hit(self.mx, self.my))
            if self.inputs[i].dirty
                self.any_dirty = true
            i++''')

s = s.replace('''            ref let Button b = self.buttons[i]
            let bool inside = b.hit(self.mx, self.my)
            if press and inside
                b.pressed = true
                b.dirty = true
            if release and b.pressed
                b.pressed = false
                b.dirty = true
                if inside
                    b.clicks++
            if b.dirty
                self.any_dirty = true
            i++''',
'''            let bool inside = self.buttons[i].hit(self.mx, self.my)
            if press and inside
                self.buttons[i].pressed = true
                self.buttons[i].dirty = true
            if release and self.buttons[i].pressed
                self.buttons[i].pressed = false
                self.buttons[i].dirty = true
                if inside
                    self.buttons[i].clicks++
            if self.buttons[i].dirty
                self.any_dirty = true
            i++''')

s = s.replace('''            ref let Slider s = self.sliders[i]
            if press and inside_slider(s)
                s.dragging = true
                s.set_value((self.mx - s.x) * 100 / (s.w - 2))
            if release
                s.dragging = false
            if s.dirty
                self.any_dirty = true
            i++''',
'''            if press and self.sliders[i].hit_wide(self.mx, self.my)
                self.sliders[i].dragging = true
                self.sliders[i].set_value((self.mx - self.sliders[i].x) * 100 / (self.sliders[i].w - 2))
            if release
                self.sliders[i].dragging = false
            if self.sliders[i].dirty
                self.any_dirty = true
            i++''')

s = s.replace('''            ref let ListBox lb = self.lists[i]
            if press and self.mx >= lb.x and self.mx < lb.x + lb.w
                let i32 rows = length(lb.items)
                let i32 hgt = lb.rows * LH + 8
                if self.my >= lb.y and self.my < lb.y + hgt
                    let i32 row = (self.my - lb.y - 4) / LH
                    let i32 idx = lb.top + row
                    if row >= 0 and idx < rows
                        lb.sel = idx
                        lb.dirty = true
            if lb.dirty
                self.any_dirty = true
            i++''',
'''            if press and self.mx >= self.lists[i].x and self.mx < self.lists[i].x + self.lists[i].w
                let i32 rows = length(self.lists[i].items)
                let i32 hgt = self.lists[i].rows * LH + 8
                if self.my >= self.lists[i].y and self.my < self.lists[i].y + hgt
                    let i32 row = (self.my - self.lists[i].y - 4) / LH
                    let i32 idx = self.lists[i].top + row
                    if row >= 0 and idx < rows
                        self.lists[i].sel = idx
                        self.lists[i].dirty = true
            if self.lists[i].dirty
                self.any_dirty = true
            i++''')

s = s.replace('''            ref let InputBox ib = self.inputs[i]
            if ib.focus
                if ib.handle_key(k)
                    self.any_dirty = true
            i++''',
'''            if self.inputs[i].focus
                if self.inputs[i].handle_key(k)
                    self.any_dirty = true
            i++''')

s = s.replace('''
// 滑块命中（含上下 6px 容差）
fn bool inside_slider(ref let Slider s)
    return self_mx() >= s.x and self_mx() < s.x + s.w and self_my() >= s.y - 6 and self_my() < s.y + 26
''', '')

s = s.replace('''        if vv != self.value
            self.value = vv
            self.dirty = true

    pub fn void draw()
        // 轨道''',
'''        if vv != self.value
            self.value = vv
            self.dirty = true

    pub fn bool hit_wide(let i32 mx, let i32 my)
        return mx >= self.x and mx < self.x + self.w and my >= self.y - 6 and my < self.y + 26

    pub fn void draw()
        // 轨道''')

assert '? C_' not in s and 'ref let' not in s and 'inside_slider' not in s and 's_dragging_fill' not in s
io.open(f, 'w', encoding='utf-8', newline='\n').write(s)
print('ok')
