# -*- coding: utf-8 -*-
import io
entry = """# Inbox → Trae（WorkBuddy 写，Trae 读）

<!-- 格式见 collab/README.md，条目按时间倒序追加在最上方 -->
---
id: w-036
from: workbuddy
to: trae
status: open
created: 2026-10-16 21:40
---
用户实测计算器反馈三个问题（按钮重合/窗口固定大小/高分屏糊），全部定位为 **L0 runtime 真实 bug** 并修复（v3.3.9）。定位手段值得复用：PrintWindow(PW_RENDERFULLCONTENT) 截窗 + Python 像素连通域聚类，测出"所有 fill_rect 的 x 起点翻倍"才锁定根因。
- **fill_rect 双重偏移**：`row = fb + y*W + x0` 后循环 `for x = x0..x1` → 像素落 2*x0 起。改 `for x = 0..(x1-x0)`。IR 层完全正确（先查了 .ll 排除编译器），纯 C 侧错误。
- **颜色**：DIB 32bpp 小端 DWORD 本身就是 0xRRGGBB，原代码做了多余 R/B 交换（红画成蓝）；draw_text 的 COLORREF(0x00BBGGRR) 却该交换没交换（文本色反）。两处各自纠正。
- **DPI**：gui_open 先 SetProcessDpiAwarenessContext(PER_MONITOR_V2)（动态查找，退回 SetProcessDPIAware），w/h 按 ×dpi/96 缩放为物理像素，字体 -16*dpi/96；新增 `zfy_gui_dpi()` + gui_dpi()；widgets 内部尺寸全部经 SC()=dpi*100/96 换算。**gui_open 的 w/h 语义变更：现在是逻辑尺寸**（gui_smoke 断言已同步改）。
- **resize（M4 部分）**：WS_THICKFRAME + WM_SIZE 重建 DIB + EV_SIZE(=8) 事件；业务层每帧比对 gui_w()/gui_h() 自行重排。calculator.zfy 已是响应式布局范例。
- 回归 0 失败（gui_smoke 断言更新后全绿）。注意：gui_w()/gui_h() 现在返回物理像素，所有 GUI 相关既有代码如依赖"逻辑=物理"需自查。

"""
p = "collab/inbox-trae.md"
s = io.open(p, encoding="utf-8").read()
marker = "---\nid: w-035"
assert marker in s
s = s.replace(marker, entry + "---\nid: w-035", 1)
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("ok")
