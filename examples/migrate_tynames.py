# -*- coding: utf-8 -*-
# 一次性迁移脚本：旧多词类型 -> 新单词类型；array/list 关键字语法 -> T a[N] / T a[]
import re, io, os, glob

MULTI = [
    ("short short uint", "u8"), ("short short", "i8"),
    ("short int uint", "u16"), ("short int", "i16"),
    ("long long uint", "u128"), ("long long", "i128"),
    ("long int uint", "u64"), ("long int", "i64"),
    ("long double", "f128"),
    ("int uint", "u32"),
]

def convert(text):
    # 多词类型（词边界）
    for old, new in MULTI:
        text = re.sub(r'\b' + old.replace(' ', r'\s+') + r'\b', new, text)
    # 单词类型
    text = re.sub(r'\bdouble\b', 'f64', text)
    text = re.sub(r'\bfloat\b', 'f32', text)
    text = re.sub(r'\bhalf\b', 'f16', text)
    text = re.sub(r'\bint\b', 'i32', text)
    # 数组：<ty> array (const )?<name>[N] -> <ty> <name>[N]（const 保留在名字前）
    text = re.sub(r'\b(i8|i16|i32|i64|i128|u8|u16|u32|u64|u128|f16|f32|f64|f128|char|string|bool)\s+array\s+(const\s+)?(\w+)',
                  r'\1 \2\3', text)
    # 列表：<ty> list (const )?<name> -> <ty> <name>[]
    text = re.sub(r'\b(i8|i16|i32|i64|i128|u8|u16|u32|u64|u128|f16|f32|f64|f128|char|string|bool)\s+list\s+(const\s+)?(\w+)',
                  r'\1 \2\3[]', text)
    return text

paths = []
for pat in [r'd:\zfy\examples\**\*.zfy', r'd:\zfy\bench\**\*.zfy', r'd:\zfy\test.zfy']:
    paths += glob.glob(pat, recursive=True)
paths = [p for p in paths if '_neg' not in p]
for p in sorted(set(paths)):
    with io.open(p, 'r', encoding='utf-8') as f:
        src = f.read()
    out = convert(src)
    if out != src:
        with io.open(p, 'w', encoding='utf-8', newline='') as f:
            f.write(out)
        print('converted', p)
print('done')
