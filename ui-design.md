# zfy UI 整改设计稿（依据 new2.md）

> 设计思想（new2.md）：先定义一个元素 → 给这个元素输入 → 再让这个元素输出。
> 每个元素带有多个**标签**：坐标、颜色、形状、大小、功能……
> 目标：简单高效地写界面代码。

## 0. 现状问题（为什么要整改）

当前 widgets.zfy 是 **9 个独立 struct**（Label/Button/InputBox/Slider/
ProgressBar/ListBox/Menu/Checkbox/TextArea），每个各有自己的字段名与
`add_xxx` 注册方法：

```
let Button b = Button(x=0, y=0, w=10, h=10, text="点我")
app.add_button(b)
if b.clicks != prev ...
```

问题：
- 组件之间字段不统一（同是"位置"，各 struct 都是 x/y/w/h 但要记 9 套构造签名）；
- 输入（事件）与输出（状态）散落在不同字段（clicks/checked/sel/value…）；
- 新增一种组件要改 stdlib 多处（add_xxx、draw 分派、hit-test 分派）。

## 1. 目标模型：Element = 标签袋

**一个元素类型 + 统一标签方法**。任何可视元素都是 `UI`，用标签声明
"它是什么、在哪、多大、什么颜色、什么功能"；输入走标签、输出走标签。

### 1.1 语法示例（stdlib 层，推荐第一版）

```
mod gui
mod widgets
use widgets::{App, UI, C_BG, C_ACCENT}

fn main()
    let App app = App()
    if app.open(280, 340, "zfy 计数器") != 0
        return 1

    // 定义元素：先 kind（功能），再逐个打标签
    let UI btn = UI("button")
    btn.pos(20, 20)            // 坐标
    btn.size(120, 44)          // 大小
    btn.text("点我 +1")        // 内容
    btn.color(C_ACCENT)        // 颜色
    btn.radius(8)              // 形状（圆角；0=直角）
    app.add(btn)               // 统一注册，不再 add_button/add_label

    let UI num = UI("label")
    num.pos(20, 80)
    num.size(120, 30)
    num.text("0")
    num.color(C_TEXT)
    app.add(num)

    // 输入→输出：每帧读元素输出标签（沿用"无回调、读差值"模型）
    let i32 prev = 0
    while app.alive()
        app.step()
        if btn.clicks != prev      // 输出标签：点了没有
            prev = btn.clicks
            num.text("计数 " + str(prev))   // 输入标签：改内容即改界面
        gui_frame_sleep(tick_ms())
    app.close()
```

### 1.2 统一标签表

| 类别 | 标签（输入） | 说明 |
|---|---|---|
| 功能 | `UI(kind)` | "button" / "label" / "input" / "slider" / "progress" / "list" / "check" / "menu" / "textarea" |
| 坐标 | `pos(x, y)` | 逻辑像素 |
| 大小 | `size(w, h)` | 逻辑像素 |
| 形状 | `radius(r)` | 圆角半径；后续可扩 `shape("circle")` |
| 颜色 | `color(rgb)` / `text_color(rgb)` | 面/文本 |
| 内容 | `text(s)` / `value(f)` / `items(list)` | 文本、滑杆值、列表项 |
| 状态 | `visible(bool)` / `enable(bool)` | 显隐与禁用 |

**输出标签（只读回读）**：

| 输出 | kind | 含义 |
|---|---|---|
| `clicks` | button / check / menu | 点击计数（差值=新点击） |
| `checked` | check | 勾选态 |
| `sel` | list / menu | 选中下标 |
| `value` | slider / progress | 当前值（f64） |
| `changed` | input / textarea / slider | 内容是否变化（差值读） |
| `text_out` | input / textarea | 用户输入的文本（输出标签） |

**不变式（保持现架构优点）**：
- 仍然**无回调**：输入是"改标签"，输出是"读标签"，每帧差值比对；
- kind 决定绘制与 hit-test，App 内部按 kind 分派——9 个组件的绘制函数
  原样复用，只是包装进 Element；
- damage 脏区跟踪不变：只有被改过标签的元素重绘。

### 1.3 实现要点（stdlib 层）

- `UI` struct 内部持有：kind 字符串、坐标/大小/颜色/内容标签、以及一个
  按需分配的**载荷**（各 kind 的私有状态：InputBox 缓冲、Slider 值…）。
  zfy 无 union，用"每 kind 一个可选字段"或"内部 new 各旧 struct 并转发"
  均可；**推荐转发方案**：UI 内部 `let i32 which` + 9 个可选旧 struct
  字段，标签方法按 which 转发——旧绘制/事件代码零改动。
- `app.add(UI)` 一个入口；内部按 which 走原 add_xxx 路径。
- 旧 9 struct 与 add_xxx **保留一个过渡版**，标记"deprecated"，下版删除。
- 工作量：widgets.zfy 重构 + demos 迁移 1~2 个 + grammar §18 改写。
  **不动编译器**，一轮完成。

## 2. 编译器级 `ui` 语句（二期，可选）

stdlib 方案落地稳定后，可把"元素+标签"提升为语言语句，缩进块即标签：

```
ui Button b
    x 20, y 20, w 120, h 44
    text "点我 +1"
    color C_ACCENT
    on_click ->
        count = count + 1        // 直接写业务（脱糖为帧差值检查）
```

- `ui <类型> <名>` + 缩进标签块：每行 `标签 表达式(, 表达式)*`；
- `on_xxx ->` 行把闭包体登记为"该事件的帧检查动作"，App.step 后依序
  执行（实现上仍是差值模型，不引入 C 回调）；
- 编译器改动：parser（新语句）+ typeck（标签名核对/类型检查）+
  脱糖（展开为 stdlib 等价代码）。2~3 轮，**建议在 stdlib 方案验证
  标签集合稳定后再做**，避免语法过早固化。

## 3. 分期与验收

| 期 | 内容 | 验收 | 状态 |
|---|---|---|---|
| 一期 | stdlib 统一元素 UI（§1），语法不变 | 新写 ui_demo ≤ 50 行；ui_test 全过；回归全绿 | **已完成（v3.17）** |
| 二期 | 编译器 `ui` 语句（§2），脱糖到一期 | 同一 demo 用 ui 语句重写，行为一致；旧代码不受影响 | 未开工 |

**一期落地记录**：`UI(kind)` + 标签方法（pos/size/text/color/text_color/
radius/value/rows/checked/add_item）；`app.add(UI)` 统一注册；输出标签
`app.uis[k]`（clicks/checked/sel/value/text_out/changed）每帧 step 自动
刷新；后置输入标签 app.set_text/set_pos/set_size/set_color/set_text_color/
set_value/set_checked/add_item。visible/enable 标签缓行（值语义保留模式下
需穿透 9 组分派循环，二期随 `ui` 语句一并做）。Button 新增 color/tcolor/
radius 字段。examples/ui_test.zfy 全过；demos/ui_demo.zfy 为写法演示。
