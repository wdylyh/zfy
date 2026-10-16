# zfy GUI 框架架构设计（design_gui.md）

> 决策（2026-10-16，用户拍板）：路线 B 扩展版——runtime 内置自绘 GUI，
> 但目标是**能做真软件的框架**，不是玩具窗口。核心原则：
> **速度关键路径全部下沉 C 层（L0），语言侧（L1~L3）只做组合逻辑。**

## 0. 分层

```
L3 应用框架   事件循环骨架、焦点管理、对话框        （纯 zfy，后续轮次）
L2 组件层     Widget 树/布局/damage 跟踪、          （纯 zfy）
              Button/Input/Slider/List/Menu...
L1 绑定层     stdlib/gui.zfy：extern 声明 + Event   （纯 zfy，本轮完成）
              struct + 常量 + 薄包装
L0 渲染核心   runtime.c：Win32 窗口 + DIB 帧缓冲 +  （C，本轮完成）
              事件环形队列 + GDI 文本 + BitBlt 提交
```

无编译器改动：L1 用 `extern "C"` 直接绑定 runtime 符号（runtime 每次编译
自动链接）；driver 链接命令追加 `-lgdi32 -luser32`。

## 1. L0 设计（已实现，v3.3.7）

### 渲染管线
- `CreateDIBSection` 32bpp top-down 位图：像素内存可直接读写（`g_gui_fb`），
  与 GDI 内存 DC 共享——既支持高速块填充又支持高质量文字
- `zfy_gui_fill_rect(x,y,w,h,rgb)`：裁剪后按行填充，热路径无函数调用开销
- `zfy_gui_draw_text(x,y,s,rgb)`：GDI TextOutW（微软雅黑 16px，透明背景，
  ClearType），天然支持中文与抗锯齿；`zfy_gui_text_w` 供布局测量
- `zfy_gui_present()`：单次 BitBlt 提交整帧（离屏绘制 + 一次上屏 = 无闪烁）
- 颜色约定：zfy 侧 `0xRRGGBB`；帧缓冲 dword 按 DIB 内存序 `(B<<16)|(G<<8)|R`

### 事件模型
- WndProc 生产 → 256 槽环形队列 → `zfy_gui_poll` 消费（泵消息 + 取事件 O(1)）
- 轮询式（immediate-mode 友好，无回调线程边界问题）；队列满丢弃新事件
- 事件类型：MOVE/LDOWN/LUP/RDOWN/RUP/KEY/WHEEL（stdlib 常量 EV_* 对应）
- `zfy_gui_should_close()`：WM_CLOSE 置位；`alive()` 由 WM_DESTROY 清零

### 窗口
- 固定客户区（无 thickframe），AdjustWindowRect 精确换算外框
- Phase 2 扩展：resize（重建 DIB + RESIZE 事件）、键盘扫描码事件、
  双缓冲光标、剪贴板

## 2. L2 组件层设计（下一轮）

### Widget 树与布局
```zfy
struct Widget
    i32 x, y, w, h          // 相对父组件坐标（布局后为绝对）
    i32 vis                 // 可见性
    Widget[] children
    // 绘制与事件处理走 fn 指针字段（语言已支持 TFnSig）
```
- 布局：简单盒模型（border/padding/gap），先做绝对布局 + 手动排列，
  Phase 3 加 flex 式自动布局
- **damage 跟踪**：Widget 维护 dirty 位；每帧只重绘脏子树，然后一次
  `gui_present()`——避免全帧重绘，这是"能做软件"的关键性能设计
- 每帧节奏：`poll 事件 → 命中测试 → 分发 → 重绘脏区 → present →
  gui_frame_sleep(t0)`（stdlib 已备帧节拍函数）

### 首批组件
Button（按下态高亮）、Label、Checkbox、InputBox（文本编辑+光标闪烁）、
Slider、ProgressBar、ListBox、MenuBar。参照 gui_demo.zfy 的 Button 写法。

## 3. L3 应用框架（后续）
- `App` 结构 + `on_tick/on_key/on_click` fn 指针回调
- 焦点链（Tab 切换）、模态对话框、菜单栏路由
- 典型程序参考：文本编辑器、计算器

## 4. 已验证（本轮）
- examples/gui_smoke.zfy：90 帧渲染/开关窗生命周期/事件泵/文本测量，自动断言
- examples/gui_demo.zfy：交互演示（按钮计数 + 条纹绘制 + 鼠标/Esc）
- 中文渲染（雅黑）与 `0xRRGGBB` 颜色、`gui_text_w` 布局测量均实测正确

## 5. 里程碑
- [x] M1（v3.3.7）：L0 渲染核心 + L1 绑定 + 冒烟测试
- [x] M2（v3.3.8）：L2 组件层——stdlib/widgets.zfy：Label/Button/InputBox/
  Slider/ProgressBar/ListBox + App 容器（事件分发/damage 脏区/按需 present）；
  examples/widgets_test.zfy 自动断言（状态机+渲染+damage）、demos/widgets_demo.zfy
  交互演示。语言侧配套：元素方法调用 arr[i].m()、元素字段复合赋值（编译器修复
  mod 内方法 struct 参数 E3001 + mir 取址泛化）
- [x] M3（v3.3.10）：TextArea 多行编辑组件（光标/拆合行/滚动/UTF-8 码点对齐/
  Ctrl+V→insert_at_cursor）+ Checkbox + 剪贴板（gui_clip_set/get，CF_UNICODETEXT
  ↔ UTF-8）+ demos/notepad.zfy 记事本（编辑/新建/复制/粘贴/插入时间/字数统计/
  响应式布局）。计算器（v3.3.9）+ 记事本 = 两个真实小软件达成
  - 配套编译器修复：**while 条件表达式绕过循环 move 门禁**——SWhile/SFor 的
    cond（和 for update）在 ldepth=0 下检查，"最后使用即 move"把条件里的
    字符串实参误判为可 move（store null 清槽），下一轮迭代 load null 段错误。
    修复：条件与 update 子句检查时同样提升 ldepth
- [ ] M4：多窗口、图标、MenuBar 组件
  - resize 已完成（v3.3.9）：WS_THICKFRAME 可调窗口 + WM_SIZE 重建 DIB +
    EV_SIZE 事件；业务每帧比对 gui_w()/gui_h() 自行重排（calculator 即范例）
  - 剪贴板已完成（v3.3.10，见 M3）；Checkbox 已完成（v3.3.10）
- [x] M4a（v3.3.9）渲染正确性修复（计算器 demo 实测暴露，PrintWindow+像素聚类定位）：
  - **fill_rect 双重偏移**：row 指针已含 +x0，循环又从 x0 起 → 所有矩形右移自身
    x 倍（按钮重合的根源）；改为 `for x in 0..span`
  - **颜色通道**：DIB 32bpp 小端 DWORD 恰为 0xRRGGBB，删掉多余 R/B 交换；
    draw_text 的 COLORREF(0x00BBGGRR) 反之必须交换——两处此前各错各的
  - **DPI 感知**：Per-Monitor V2（退回 SetProcessDPIAware）；gui_open 的 w/h 为
    逻辑尺寸，内部 ×dpi/96 成物理像素，字体同步缩放；新增 gui_dpi()；
    widgets 组件内部尺寸全部经 SC()（=dpi*100/96）换算——150% 屏不糊不小
