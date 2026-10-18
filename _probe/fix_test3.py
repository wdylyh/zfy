# -*- coding: utf-8 -*-
import io
# 1) widgets.zfy: is_cont 用有符号区间（0x80..0xBF = -128..-65）
p1 = r"D:\zfy\stdlib\widgets.zfy"
s = io.open(p1, encoding="utf-8").read()
old = """// s[i] 是否 UTF-8 continuation 字节（0x80..0xBF）
fn bool is_cont(let string s, let i32 i)
    if i < 0 or i >= length(s)
        return false
    let i32 b = ord(s[i])
    return b >= 0x80 and b < 0xC0"""
new = """// s[i] 是否 UTF-8 continuation 字节（0x80..0xBF；ord 返回有符号字节值，即 -128..-65）
fn bool is_cont(let string s, let i32 i)
    if i < 0 or i >= length(s)
        return false
    let i32 b = ord(s[i])
    return b <= -65"""
assert s.count(old) == 1
s = s.replace(old, new)
io.open(p1, "w", encoding="utf-8", newline="\n").write(s)

# 2) 测试修正
p2 = r"D:\zfy\examples\textarea_test.zfy"
t = io.open(p2, encoding="utf-8").read()
def rep(old, new):
    global t
    assert t.count(old) == 1, old
    t = t.replace(old, new)
# append two：先 End 到行尾
rep("""    t.set_text("he")
    r = t.handle_key(108)                                   // 'l'
    r = t.handle_key(108)
    chk(t.lines[0] == "hell", "append two")""",
    """    t.set_text("he")
    r = t.handle_key(KEY_EXT + 0x23)                        // End 到行尾
    r = t.handle_key(108)                                   // 'l'
    r = t.handle_key(108)
    chk(t.lines[0] == "hell", "append two")""")
# backspace deletes：cx=2 删的是 'b' -> "acd"
rep('chk(t.lines[0] == "abd", "backspace deletes")',
    'chk(t.lines[0] == "acd", "backspace deletes")')
# up/down：cx=0 保持 0（列钳制只在超宽时触发）
rep("""    t.handle_key(KEY_EXT + 0x26)                            // Up：cx clamp 到上行宽
    chk(t.cy == 0 and t.cx == 2, "up keeps column clamped")
    t.handle_key(KEY_EXT + 0x28)                            // Down
    chk(t.cy == 1 and t.cx == 2, "down keeps column clamped")""",
    """    t.handle_key(KEY_EXT + 0x26)                            // Up：cx<=上行宽则保持
    chk(t.cy == 0 and t.cx == 0, "up keeps column")
    r = t.handle_key(KEY_EXT + 0x24)                        // Home
    chk(t.cx == 0, "home after up")
    t.cx = 4
    t.handle_key(KEY_EXT + 0x28)                            // Down：cx>下行宽则钳到行尾
    chk(t.cy == 1 and t.cx == 4, "down clamps to line end")""")
io.open(p2, "w", encoding="utf-8", newline="\n").write(t)
print("ok")
