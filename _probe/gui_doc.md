
## 18. GUI 窗口与组件（v3.3.7+，stdlib/gui.zfy + stdlib/widgets.zfy）

> 分层：**L0** runtime.c C 渲染核心（DIB 帧缓冲 + 事件环形队列 + GDI
> 雅黑中文文本 + BitBlt 单次提交）→ **L1** `stdlib/gui.zfy`（纯 extern
> 薄绑定）→ **L2** `stdlib/widgets.zfy`（9 组件 + App 容器，damage
> 脏区跟踪，只重绘变化的组件）→ **L3** 应用（examples/demos）。
> 仅 Windows（Win32 + GDI）；非 Windows 平台 GUI 桩全部返回失败/空。

### 18.0 30 秒上手（App 容器，推荐路径）

```
mod gui;
mod widgets;
use widgets::{App, Label, Button, SC, C_BG}
use gui::{gui_w, gui_h, gui_frame_sleep}

fn main()
    let App app = App()
    if app.open(280, 340, "zfy 计算器") != 0      // 0=成功（逻辑尺寸）
        return 1
    let Button b = Button(x=0, y=0, w=10, h=10, text="点我")
    app.add_button(b)
    let i32 prev = 0
    let i32 last_w = 0
    while app.alive()
        // 响应式布局：窗口可拖拽缩放（v3.3.9+），每帧比对尺寸重排
        if gui_w() != last_w
            ...重算组件位置...
        app.step()                                // 泵事件+更新+按需重绘
        if b.clicks != prev                       // 按钮被点（读计数器差值）
            prev = b.clicks
            ...业务...
        gui_frame_sleep(tick_ms())                // 限帧（App 已修 CPU 空转）
    app.close()
```

要点：**组件交互结果全部通过字段回读**（Button.clicks / Slider.value /
ListBox.sel / Menu.sel+clicks / Checkbox.checked），不用回调——业务每帧
对比差值。响应式布局参考 `demos/calculator.zfy`。

### 18.1 L1：gui.zfy 窗口与绘制 API

事件与常量：

| 项 | 说明 |
|---|---|
| `Event` struct | `typ/x/y/key` 全 i64；`e.is(EV_MOVE)` 便捷判断 |
| `EV_MOVE/LDOWN/LUP/RDOWN/RUP/KEY/WHEEL/SIZE` | 1..8；KEY 的 key=键值，WHEEL 的 key=滚动增量，SIZE 的 x,y=新物理宽高 |
| `KEY_EXT` | `0x10000000 | VK`：LEFT 0x25 RIGHT 0x27 UP 0x26 DOWN 0x28 DEL 0x2E HOME 0x24 END 0x23 |
| `KEY_CTRL` | `0x20000000 | 'C'/'V'/'A'/'X'` |

窗口生命周期与多窗口（v3.4.0）：

```
gui_open(w, h, title) -> i32      // w/h 逻辑尺寸（96dpi 基准），0=成功
gui_close()                       // 关当前窗口
gui_alive() -> bool               // 当前窗口存活
gui_alive_any() -> bool           // 任一窗口存活（多窗口主循环条件）
gui_self() -> i32                 // 当前窗口句柄 1..8
gui_select(id)                    // 切换"当前窗口"；绘制/事件作用于它
                                  // gui_open 后新窗口自动成为当前窗口
gui_title(t) / gui_set_icon(path) // 标题 / 窗口图标（.ico 文件路径）
gui_w()/gui_h() -> i32            // 当前窗口客户区，物理像素
gui_dpi() -> i32                  // 96=100% 缩放；逻辑转物理 = v*dpi/96
```

绘制（作用于当前窗口的帧缓冲，`gui_present()` 后才上屏）：

```
gui_fill_rect(x, y, w, h, 0xRRGGBB)   // 实心矩形（自动裁剪）
gui_rect(x, y, w, h, 0xRRGGBB)        // 1px 边框
gui_draw_text(x, y, s, 0xRRGGBB)      // 雅黑 16 逻辑px，UTF-8 中英文
gui_text_w(s) -> i32                  // 文本像素宽（当前窗口字体度量）
gui_present()                         // 帧缓冲 → 屏幕（BitBlt 单次提交）
```

事件轮询与帧率：

```
gui_poll(ref e) -> bool               // 泵 Win32 消息队列 + 取一事件
gui_frame_sleep(start_ms)             // 配对 tick_ms()，限 ~60fps 且不空转
```

剪贴板（CF_UNICODETEXT ↔ UTF-8）：

```
gui_clip_set(s)                       // 写入（替换现有内容）
gui_clip_get() -> string              // 读取；失败/无文本返回 ""
```

### 18.2 L2：widgets.zfy 组件库

颜色常量（可整体覆盖自绘主题）：`C_BG C_PANEL C_BORDER C_TEXT
C_ACCENT C_HOT C_DOWN C_OK`。缩放辅助：`SC() -> i32` = dpi/96 百分比
（144dpi 时 150），所有组件内部尺寸已经过它缩放；业务自绘几何建议
同样乘 `SC()/100`。

所有组件共有：`x/y` 坐标（物理像素）、`dirty` 标志（改动后置 true，
App 只重绘脏组件——文本/状态变化后**必须置 dirty = true**）。

| 组件 | 关键字段（业务读） | 交互 |
|---|---|---|
| `Label` | text、color、bg_w | 静态文本；bg_w=清屏宽度防残影 |
| `Button` | **clicks**（累计点击数） | 悬停/按下高亮 |
| `InputBox` | text、focus | 单行输入，点击获焦，键盘输入 |
| `Slider` | **value**（0..100） | 拖拽滑块 |
| `ProgressBar` | value | 只展示，set_value 驱动 |
| `ListBox` | **sel**（-1 未选）、top | 点击选中行，滚轮滚动 |
| `TextArea` | lines、**cx/cy**、top、focus | 见 18.3 |
| `Checkbox` | **checked**、clicks | 勾选切换 |
| `Menu` | **sel**（最后选中条目索引）、**clicks**、open | 见 18.4 |

App 容器：

```
app.open(w, h, title) -> i32          // 同 gui_open（0=成功）
app.alive() -> bool                   // gui_alive 且未请求退出
app.close()                           // 退出循环
app.add_label / add_button / add_input / add_slider / add_bar /
app.add_list / add_text / add_checkbox / add_menu(...)
                                      // 挂组件（值拷贝进容器）
app.step()                            // 一帧：泵事件→命中测试→更新→脏区重绘
app.mx / app.my                       // 本帧鼠标客户区坐标（自绘命中用）
app.ldown                             // 左键按住（拖拽逻辑用）
app.invalidate_all()                  // 全组件置脏（主题切换等）
```

### 18.3 TextArea（多行编辑）

```
let TextArea ta = TextArea(x=8, y=40, w=100, h=80)
ta.set_text("第一行\n第二行")          // 按回车拆行初始化
ta.text() -> string                    // 合行取回全文（\n 连接）
ta.insert_at_cursor(s)                 // 光标处插入（Ctrl+V 内部走它）
ta.handle_key(k) -> bool               // 手动喂键（App.add_text 已自动）
```

内置编辑能力：点击/方向键/Home/End 移动光标、回车拆行、退格删字
（行首回退合行）、Delete、滚轮上下滚动。**UTF-8 码点对齐**：cx 是
字节列，退格/Delete 自动按前导字节回退整个多字节字符，中文不会被
切坏。判断按键来源：`k >= KEY_EXT` 为扩展键（k-KEY_EXT=VK），
`k >= KEY_CTRL` 为 Ctrl 组合键。

### 18.4 MenuBar（菜单栏）

```
let Menu mf = Menu(title="文件", items="新建", "退出")
let Menu me = Menu(title="编辑", items="复制", "粘贴", "插入时间")
app.add_menu(mf)                       // 挂多个 Menu 即成菜单栏
...
let i32 handled = me.clicks            // 每帧对比差值
app.step()
if me.clicks != handled
    output("选中条目 idx=", me.sel)    // 0 基；"退出"=1
```

交互语义：点击标题开/合下拉（同排其它菜单自动收起）；点击条目时
`sel` 写入条目索引、`clicks++`，随后下拉自动收起；点击菜单栏以外
区域也收起。条目高亮随悬停变化。菜单栏高度 `app.menu_bar_h()`，
业务组件 y 应从其下方起排。

### 18.5 裸 L0 轮询写法（不用 App，适合嵌入自定义框架）

```
use gui::{...}
fn main()
    if gui_open(480, 300, "raw") != 0
        return 1
    let Event e = Event()
    while gui_alive()                  // 多窗口用 gui_alive_any()
        while gui_poll(ref e)
            if e.is(EV_LDOWN)          // 事件驱动分支...
                ...
            if e.is(EV_KEY) and e.key >= KEY_EXT
                ...
            if e.is(EV_SIZE)           // 窗口缩放 → 全量重绘
                ...
        gui_fill_rect(16, 16, 64, 32, 0x2F7FD6)
        gui_draw_text(20, 20, "你好 zfy", 0xFFFFFF)
        gui_present()
        gui_frame_sleep(tick_ms())
    gui_close()
```

### 18.6 GUI 易错点

- **组件交互不用回调**：全部读字段差值（clicks/value/sel/checked），
  忘记对比差值 = 每帧重复触发。
- **改了必置 dirty**：`lbl.text = "x"` 后不置 `lbl.dirty = true` 不重绘。
- **gui_w/gui_h 是物理像素**：与逻辑坐标混算前乘 `SC()/100` 或除以
  `gui_dpi()/96`；断言宽高请用物理值（150% 屏上 480 逻辑 = 720 物理）。
- **交互/死循环 GUI 程序不得放 examples/**（回归会挂死），放 demos/。
- **`err` 是关键字**（ZEM 错误模型），GUI 业务局部变量改名（如 bad）。
- **值语义深拷贝**：`app.add_button(b)` 后再改局部 `b` 无效——需要
  改容器内组件时读 `app.buttons[i]`（元素字段复合赋值
  `app.buttons[i].x = 5`、`app.buttons[i].clicks++` 均支持，v3.3.8）。
- 字符串实参在 **while 条件里传函数**：旧编译器（< v3.3.10）段错误
  （自动 move 循环误判），现版本安全；文档存档供排查旧二进制。
