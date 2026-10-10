# -*- coding: utf-8 -*-
# 一次性迁移脚本：旧声明/函数语法 -> let/fn 形式（new.md 2026-10-10）
#   声明:  TYPE (frac|const|unred)* NAME...      -> let TYPE (frac const unred 顺序) NAME...
#   函数:  (<T,..>)? RET (mods)* NAME(params)    -> fn [<T,..> ]RET (frac const unred) NAME(...)
#          main 特例: void/i64/i32 main()        -> fn main()
#   参数:  TYPE (frac|const|unred|ref)* NAME     -> (ref)? let TYPE (frac const unred) NAME
#   extern 块: 只改参数（保持旧式返回）
#   struct 字段区: 跳过不改
import re, io, os, glob

PRIMS = ['void','i8','i16','i32','i64','i128','u8','u16','u32','u64','u128',
         'f16','f32','f64','f128','char','string','bool']
DECL_MODS = ['frac', 'const', 'unred']
MOD_RE = r'(?:frac|const|unred|ref)'
DMOD_RE = r'(?:frac|const|unred)'

# 语句首关键字（防止把 use/return/output... 误当类型）
KW_GUARD = (r'(?!use\b|as\b|mod\b|type\b|extern\b|struct\b|packed\b|return\b|'
            r'if\b|else\b|while\b|for\b|break\b|continue\b|unsafe\b|reduce\b|'
            r'remove\b|input\b|output\b|panic\b|fail\b|cast\b|true\b|'
            r'false\b|null\b|move\b|copy\b|ref\b|and\b|or\b|not\b|sep\b|end\b|'
            r'delim\b|frac\b|const\b|unred\b|array\b|list\b|let\b|fn\b)')

PUB_RE = re.compile(r'^(pub\s+)(.*)$')

# 残留旧别名 -> 宽度名（先多词后单词，\b 词边界）
ALIAS_MULTI = [
    (r'short\s+short\s+uint', 'u8'), (r'short\s+short', 'i8'),
    (r'short\s+int\s+uint', 'u16'), (r'short\s+int', 'i16'),
    (r'ushort\s+int', 'u16'),
    (r'long\s+long\s+uint', 'u128'), (r'long\s+long', 'i128'),
    (r'long\s+double', 'f128'), (r'long\s+int\s+uint', 'u64'),
    (r'long\s+int', 'i64'), (r'int\s+uint', 'u32'),
]
ALIAS_SINGLE = [
    (r'double', 'f64'), (r'float', 'f32'), (r'half', 'f16'),
    (r'quad', 'f128'), (r'uint', 'u32'), (r'ushort', 'u8'),
    (r'ulong', 'u128'), (r'long', 'i128'), (r'short', 'i8'), (r'int', 'i32'),
]

def alias_sub(text):
    for old, new in ALIAS_MULTI:
        text = re.sub(r'\b' + old + r'\b', new, text)
    for old, new in ALIAS_SINGLE:
        text = re.sub(r'\b' + old + r'\b', new, text)
    return text

def indent_of(line):
    s = line.expandtabs(4)
    return len(s) - len(s.lstrip(' '))

def collect_known(lines):
    known = set(PRIMS)
    for ln in lines:
        m = re.match(r'^\s*struct\s+(?:packed\s+)?([A-Za-z_]\w*)', ln)
        if m: known.add(m.group(1))
        m = re.match(r'^\s*type\s+([A-Za-z_]\w*)\s*=', ln)
        if m: known.add(m.group(1))
        m = re.match(r'^\s*<([A-Za-z0-9_,\s\*]+)>', ln)
        if m:
            for t in re.findall(r'[A-Za-z_]\w*', m.group(1)):
                known.add(t)
    return known

def ty_pattern(known):
    names = '|'.join(sorted(map(re.escape, known), key=len, reverse=True))
    return ('(?:' + names + r'|[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*)'
            r'(?:(?:\[\d*\]|\*|!|<[A-Za-z0-9_,\s\*\[\]<>]*>)*)'
            r'(?:\((?:[^()]|\([^()]*\))*\))?')

def split_top(s):
    """按顶层逗号分割（尊重 () [] <> 深度）"""
    parts, depth, cur = [], 0, ''
    for ch in s:
        if ch in '([<': depth += 1
        elif ch in ')]>': depth -= 1
        if ch == ',' and depth == 0:
            parts.append(cur); cur = ''
        else:
            cur += ch
    if cur.strip(): parts.append(cur)
    return parts

def conv_param(s, known):
    if s.strip().startswith('let '):
        return s   # 已是新语法，避免二次前缀
    tp = ty_pattern(known)
    m = re.match(r'^(\s*)(?:(ref)\s+)?(' + tp + r')((?:\s+' + MOD_RE + r')*)\s+([A-Za-z_]\w*)(.*)$', s)
    if not m:
        return s
    (_ws, ref0, ty, mods, name, tail) = m.groups()
    mtoks = set(re.findall(MOD_RE, mods))
    if ref0: mtoks.add('ref')
    out = ('ref let ' if 'ref' in mtoks else 'let ') + ty
    for md in DECL_MODS:
        if md in mtoks: out += ' ' + md
    out += ' ' + name + tail
    return out

def conv_params(s, known):
    return ', '.join(conv_param(p, known) for p in split_top(s))

def conv_params_till_close(rest, known):
    """rest 以参数列表开始；找配对 ')'，参数转换，其余原样"""
    depth = 1
    for i, ch in enumerate(rest):
        if ch == '(': depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return conv_params(rest[:i], known) + rest[i:]
    return conv_params(rest, known)

def conv_for_header(stripped, known):
    """for 头部：声明段 TYPE mods* NAME = init -> let TYPE mods* NAME = init"""
    tp = ty_pattern(known)
    parts = split_top(stripped)
    out = []
    for seg in parts:
        s2 = seg.strip()
        lead_ws = seg[:len(seg) - len(seg.lstrip())]
        if s2.startswith('let ') or s2.startswith('let('):
            out.append(seg); continue
        m = re.match(r'^(' + tp + r')((?:\s+' + DMOD_RE + r')*)(\s+)([A-Za-z_]\w*)(\s*=)(.*)$',
                     s2, re.S)
        if m:
            ty, mods, sp, name, eq, rest = m.groups()
            mtoks = re.findall(DMOD_RE, mods)
            modstr = ''.join(' ' + md for md in DECL_MODS if md in mtoks)
            out.append(lead_ws + 'let ' + ty + modstr + sp + name + eq + rest)
        else:
            out.append(seg)
    return ', '.join(out)

def conv_input_args(stripped, known):
    """input(...)：目标段 TYPE mods* NAME -> let TYPE mods* NAME（delim= 等命名段不动）"""
    tp = ty_pattern(known)
    lparen = stripped.index('(')
    head = stripped[:lparen + 1]
    # 找配对右括号
    depth, close = 1, len(stripped)
    for i in range(lparen + 1, len(stripped)):
        if stripped[i] == '(': depth += 1
        elif stripped[i] == ')':
            depth -= 1
            if depth == 0:
                close = i; break
    inner, tail = stripped[lparen + 1:close], stripped[close:]
    parts = split_top(inner)
    out = []
    for seg in parts:
        s2 = seg.strip()
        lead_ws = seg[:len(seg) - len(seg.lstrip())]
        first_tok = s2.split()[0] if s2 else ''
        if s2.startswith('let ') or '=' in first_tok:
            out.append(seg); continue
        m = re.match(r'^(' + tp + r')((?:\s+' + DMOD_RE + r')*)(\s+)([A-Za-z_]\w*)\s*$', s2)
        if m:
            ty, mods, sp, name = m.groups()
            mtoks = re.findall(DMOD_RE, mods)
            modstr = ''.join(' ' + md for md in DECL_MODS if md in mtoks)
            out.append(lead_ws + 'let ' + ty + modstr + sp + name)
        else:
            out.append(seg)
    return head + ', '.join(out) + tail

def conv_line(ln, known):
    if re.match(r'^\s*//', ln) or not ln.strip():
        return ln
    stripped = ln.lstrip()
    lead = ln[:len(ln) - len(stripped)]
    # pub 前缀：剥出后转换再拼回
    pub = ''
    mp = PUB_RE.match(stripped)
    if mp:
        pub = mp.group(1)
        stripped = mp.group(2)
        lead = ln[:len(ln) - len(mp.group(2)) - len(pub)]
    tp = ty_pattern(known)

    # for 头部：声明段加 let
    mfor = re.match(r'^for\b(.*)$', stripped, re.S)
    if mfor:
        return lead + 'for' + conv_for_header(mfor.group(1), known)
    # input(...)：目标加 let
    if re.match(r'^input\s*\(', stripped):
        return lead + conv_input_args(stripped, known)

    # fn 定义：<T,...>? RET mods* NAME(  —— main 特例
    m = re.match(r'^' + KW_GUARD + r'((?:<[A-Za-z0-9_,\s\*]+>\s*)?)(' + tp +
                 r')((?:\s+' + DMOD_RE + r')*)\s+([A-Za-z_]\w*)(\s*\()(.*)$', stripped)
    if m:
        gens, ret, mods, name, _lp, rest = m.groups()
        mtoks = re.findall(DMOD_RE, mods)
        modstr = ''.join(' ' + md for md in DECL_MODS if md in mtoks)
        if name == 'main':
            return lead + pub + 'fn main(' + conv_params_till_close(rest, known)
        return (lead + pub + 'fn ' + (gens if gens else '') + ret + modstr + ' ' +
                name + '(' + conv_params_till_close(rest, known))

    # 声明：TYPE mods* NAME（后随 [ , = 或行尾）
    m = re.match(r'^' + KW_GUARD + r'(' + tp + r')((?:\s+' + DMOD_RE +
                 r')*)(\s+)([A-Za-z_]\w*)(\s*(?:\[|,|=|$))(.*)$', stripped)
    if m:
        ty, mods, sp, name, look, rest = m.groups()
        mtoks = re.findall(DMOD_RE, mods)
        modstr = ''.join(' ' + md for md in DECL_MODS if md in mtoks)
        return lead + pub + 'let ' + ty + modstr + sp + name + look + rest
    return ln

def convert_text(text):
    # 残留旧别名 -> 宽度名（跳过整行注释）
    lines = []
    for ln in text.split('\n'):
        if ln.lstrip().startswith('//'):
            lines.append(ln)
        else:
            lines.append(alias_sub(ln))
    text = '\n'.join(lines)
    lines = text.split('\n')
    known = collect_known(lines)
    out = []
    region = None      # None | ('struct', indent) | ('extern', indent)
    for ln in lines:
        if region:
            rind = region[1]
            if ln.strip() == '':
                out.append(ln); continue
            if indent_of(ln) > rind:
                if region[0] == 'extern':
                    stripped = ln.lstrip()
                    lead = ln[:len(ln) - len(stripped)]
                    m = re.match(r'^(' + ty_pattern(known) + r')((?:\s+' +
                                 MOD_RE + r')*)\s+([A-Za-z_]\w*)(\s*\()(.*)$', stripped)
                    if m:
                        ret, mods, name, _lp, rest = m.groups()
                        out.append(lead + ret + mods + ' ' + name + '(' +
                                   conv_params_till_close(rest, known))
                    else:
                        out.append(ln)
                else:
                    out.append(ln)   # struct 字段原样
                continue
            else:
                region = None
        st = ln.strip()
        if re.match(r'(?:pub\s+)?struct\b', st):
            out.append(ln)
            region = ('struct', indent_of(ln))
            continue
        if re.match(r'(?:pub\s+)?extern\b', st):
            out.append(ln)
            region = ('extern', indent_of(ln))
            continue
        out.append(conv_line(ln, known))
    return '\n'.join(out)

def main():
    paths = []
    for pat in [r'd:\zfy\examples\**\*.zfy', r'd:\zfy\grammar_tests\*.zfy',
                r'd:\zfy\bench\**\*.zfy', r'd:\zfy\test.zfy', r'd:\zfy\main.zfy',
                r'd:\zfy\tese.zfy', r'd:\zfy\_t1.zfy', r'd:\zfy\_t2.zfy']:
        paths += glob.glob(pat, recursive=True)
    paths = sorted(set(paths))
    paths = [p for p in paths if '_neg' not in p
             and os.path.basename(p) != '_smoke.zfy']
    for p in paths:
        with io.open(p, 'r', encoding='utf-8') as f:
            src = f.read()
        out = convert_text(src)
        if out != src:
            with io.open(p, 'w', encoding='utf-8', newline='') as f:
                f.write(out)
            print('converted', p)
    print('done')

if __name__ == '__main__':
    main()
