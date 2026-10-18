import zlib, struct
data = open(r"d:\zfy\_tmp\win.png", "rb").read()
# 解析 PNG IDAT（zfy 截图为无滤波 zlib，shot.py 每行前加 0 filter byte）
i = data.find(b"IDAT"); end = data.find(b"IEND")
raw = zlib.decompress(data[i+4:end-8])  # type(4) 之后是数据；尾部去掉 CRC(4)+IEND长度(4)
w = struct.unpack(">I", data[data.find(b"IHDR")+8:data.find(b"IHDR")+12])[0]
h = struct.unpack(">I", data[data.find(b"IHDR")+8+4:data.find(b"IHDR")+12+4])[0]
# win.png 为 RGBA（shot.py 已交换 R/B），C_ACCENTD 0x0C3B5E → 字节 0C 3B 5E
tgt = bytes([0x0C, 0x3B, 0x5E])
hits = []
y = 0
while y < h:
    row = raw[y*(w*4+1)+1 : (y+1)*(w*4+1)]
    if tgt in row:
        hits.append(y)
    y += 1
print("rows with accent-hl:", len(hits), "y range:", (hits[0], hits[-1]) if hits else None)
