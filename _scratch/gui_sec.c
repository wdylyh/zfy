/* ==================== GUI 核心层（v3.3.7 design_gui.md L0） ====================
 * 渲染引擎（完全替换 GDI DIB → Direct2D + DirectWrite + WIC）：
 *  - 每窗口一套 ID2D1DeviceContext + DXGI 交换链（Flip 模型，双缓冲），
 *    后端 D3D11 设备（硬件优先，失败自动退回 WARP 软件光栅，远程会话可用）
 *  - 抗锯齿：几何 PER_PRIMITIVE，文本 GRAYSCALE（中文/英文均平滑，无 GDI 调色板抖动）
 *  - 颜色约定：zfy 侧统一 0xAARRGGBB；仅给 0xRRGGBB（高字节为 0 且 RGB 非 0）时
 *    alpha 缺省为 0xFF（向后兼容旧组件配色）
 *  - 全局乘性透明度：gui_set_alpha(a) 把后续所有绘制的 alpha 再乘 a/255
 *  - 混合模式：0=SourceOver（D2D 默认）1=Additive（D2D 原生加法混合）
 *    2=Multiply 3=Screen 4=Xor 走"源位图 + 目标回读 + CPU 逐像素合成 + 上传"路径
 *    （Xor 按 abs(dst-src) 逐通道实现，等同差异混合）
 *  - DPI 语义不变：open 的 w/h 为逻辑尺寸，按 dpi/96 放大为物理像素；渲染目标
 *    SetDpi(96) 使 1 DIP = 1 物理像素，字体 px 逻辑 → 物理 = px * dpi / 96，
 *    故 widgets 的 SC() 缩放逻辑无需修改
 *  - 事件：环形队列（WndProc 生产、poll 消费），轮询模型 O(1)
 *  - 单线程模型：poll() 顺带泵消息，用户每帧至少 poll 一次；每帧画完 present() 一次
 *  - 缓存策略：
 *      · IDWriteTextFormat：全局 64 槽 LRU，键 = (字体族, 物理字号, 字重, 斜体)
 *      · 纯色画刷：每窗口 64 槽 LRU，键 = 有效 ARGB（已乘全局 alpha）
 *      · 位图：全局 64 槽句柄表（句柄 = 槽位 + 1，0 表示非法）
 *      · 混合合成的临时位图/缓冲区：每窗口单例，按需增长
 *  - 可调窗口：WM_SIZE 时 ResizeBuffers + 重建目标位图并推 EV_SIZE 事件 */
#if defined(_WIN32) && !defined(ZFY_FREESTANDING)
#include <wchar.h>                     /* wcslen（GUI 文本转换） */
#include <d2d1_1.h>
#include <d3d11.h>
#include <dxgi1_3.h>
#include <dwrite.h>
#include <wincodec.h>

/* mingw 的 IDWriteFactory IID 未进导入库，本地定义一份 */
static const GUID gui_iid_dwrite = { 0xb859ee5a, 0xd838, 0x4b5b,
                                     { 0xa2, 0xe8, 0x1a, 0xdc, 0x7d, 0x93, 0xdb, 0x48 } };

typedef struct { int64_t t, x, y, k; } gui_ev;
#define GUI_EVQ 256

/* 事件类型常量（与 stdlib/gui.zfy 保持一致） */
#define GUI_EV_MOVE  1
#define GUI_EV_LDOWN 2
#define GUI_EV_LUP   3
#define GUI_EV_RDOWN 4
#define GUI_EV_RUP   5
#define GUI_EV_KEY   6
#define GUI_EV_WHEEL 7
#define GUI_EV_SIZE  8

/* EV_KEY 的 k 值分区（避免与 WM_CHAR 码元 <0x110000 冲突）：
 *   GUI_KEY_EXT  | VK   —— 方向键/Delete/Home/End 等（WM_KEYDOWN）
 *   GUI_KEY_SHIFT| EXT|VK —— Shift+导航（扩选用）
 *   GUI_KEY_CTRL | 'C'  —— Ctrl 组合键（VK 大写字母） */
#define GUI_KEY_EXT  0x10000000
#define GUI_KEY_CTRL 0x20000000
#define GUI_KEY_SHIFT 0x40000000

/* 多窗口（v3.4）：窗口状态集中管理，WndProc 经 GWLP_USERDATA 找回窗口。
 * 绘制类 API 作用于"当前窗口" g_cur（gui_select 切换）；gui_open 保持
 * 返回 0=成功 的兼容语义，句柄经 zfy_gui_self() 取。 */
#define GUI_MAXWIN 8
#define GUI_TF_SLOTS 64
#define GUI_BR_SLOTS 64
#define GUI_IMG_SLOTS 64
#define GUI_XF_STACK 16
#define GUI_CLIP_STACK 16

/* ---------- D2D 调用宏（mingw 的 d2d1 vtbl 有继承嵌套，路径逐层写死） ---------- */
#define RT(c)            ((ID2D1RenderTarget *)(c))
#define RT_V(c, fn, ...) (RT(c)->lpVtbl->fn(RT(c), ##__VA_ARGS__))
#define DC_V(c, fn, ...) ((c)->lpVtbl->fn(c, ##__VA_ARGS__))
#define FACT(f, fn, ...) ((f)->lpVtbl->Base.fn((ID2D1Factory *)(f), ##__VA_ARGS__))
#define FACT1(f, fn, ...) ((f)->lpVtbl->fn((ID2D1Factory1 *)(f), ##__VA_ARGS__))
#define GEO(g, fn, ...)  ((g)->lpVtbl->Base.fn((ID2D1Geometry *)(g), ##__VA_ARGS__))
#define PG(g, fn, ...)   ((g)->lpVtbl->fn((ID2D1PathGeometry *)(g), ##__VA_ARGS__))
#define SINK(s, fn, ...) ((s)->lpVtbl->Base.fn((ID2D1SimplifiedGeometrySink *)(s), ##__VA_ARGS__))
#define SINK_CLOSE(s)    ((s)->lpVtbl->Close((ID2D1GeometrySink *)(s)))
#define SB_SETCOLOR(b, c) ((b)->lpVtbl->SetColor((ID2D1SolidColorBrush *)(b), c))
#define BR_SETOPACITY(b, o) ((b)->lpVtbl->Base.SetOpacity((ID2D1Brush *)(b), o))
#define BM_V(b, fn, ...) ((b)->lpVtbl->Base.fn((ID2D1Bitmap *)(b), ##__VA_ARGS__))
#define BM1_V(b, fn, ...) ((b)->lpVtbl->fn((ID2D1Bitmap1 *)(b), ##__VA_ARGS__))
#define REL(o) do { if (o) { ((IUnknown *)(void *)(o))->lpVtbl->Release((IUnknown *)(void *)(o)); } } while (0)

typedef struct {
    uint32_t argb;
    ID2D1SolidColorBrush *br;
    unsigned stamp;
    int used;
} gui_br_slot;

typedef struct {
    ID2D1Bitmap1 *bmp;
    int w, h;
    int used;
} gui_img;

typedef struct {
    char family[64];
    float size;
    int weight, italic;
    IDWriteTextFormat *fmt;
    unsigned stamp;
    int used;
} gui_tf_slot;

typedef struct {
    int used;
    HWND hwnd;
    /* D2D/DXGI 渲染资源 */
    IDXGISwapChain1 *swap;
    ID2D1DeviceContext *ctx;
    ID2D1Bitmap1 *target;
    int w, h, dpi;
    /* 当前默认文本样式（DirectWrite） */
    char tf_family[64];
    int tf_px, tf_weight, tf_italic;
    /* 透明度 / 混合模式 */
    int alpha;                            /* 全局乘性 alpha 0..255 */
    int blend;                            /* 0..4（见 GUI_BLEND_*） */
    /* 纯色画刷缓存（每窗口） */
    gui_br_slot br[GUI_BR_SLOTS];
    unsigned br_tick;
    /* 混合模式合成用临时资源 */
    ID2D1Bitmap1 *scr_src;                /* 源：图元画在透明底上 */
    ID2D1Bitmap1 *scr_dst;                /* 目的快照（CPU 可读） */
    ID2D1Bitmap1 *scr_up;                 /* 合成结果上传位图 */
    unsigned char *scr_buf;               /* CPU 合成缓冲区 */
    int scr_w, scr_h;
    /* 变换 / 裁剪栈 */
    D2D1_MATRIX_3X2_F xf[GUI_XF_STACK];
    int xf_n;
    int clip_n;
    volatile int alive, should_close;
    gui_ev q[GUI_EVQ];
    volatile long qh, qt;
} gui_win;
static gui_win g_wins[GUI_MAXWIN];
static gui_win *g_cur = NULL;

/* 全局单例（COM 与设备级对象） */
static ID2D1Factory1 *g_d2d_fct = NULL;
static IDWriteFactory *g_dw = NULL;
static IWICImagingFactory *g_wic = NULL;
static ID2D1Device *g_d2d_dev = NULL;
static ID3D11Device *g_d3d = NULL;
static IDXGIFactory2 *g_dxgi = NULL;
static ID2D1StrokeStyle *g_stroke_flat = NULL;
static int g_com_ready = 0;
static gui_tf_slot g_tf[GUI_TF_SLOTS];
static unsigned g_tf_tick = 0;
static gui_img g_imgs[GUI_IMG_SLOTS];

/* 混合模式取值（与 stdlib/gui.zfy 的 BLEND_* 一致） */
#define GUI_BLEND_SRCOVER  0
#define GUI_BLEND_ADD      1
#define GUI_BLEND_MULTIPLY 2
#define GUI_BLEND_SCREEN   3
#define GUI_BLEND_XOR      4

static void gui_push_ev(gui_win *w, int64_t t, int64_t x, int64_t y, int64_t k) {
    /* MOVE 合并：队列尾已有未消费的 MOVE 时直接覆盖坐标（只保留最新位置）。
       鼠标快速移动会产生事件洪流——旧实现队列满后"丢弃新事件"会把夹在
       MOVE 洪流中的 DOWN/UP/KEY 一并丢掉（表现为点击无效、组件"点了没
       反应、点几下才显示"，w-052）。合并 MOVE 后 DOWN/UP 永不被挤掉。 */
    if (t == GUI_EV_MOVE && w->qt != w->qh) {
        long prv = (w->qt + GUI_EVQ - 1) % GUI_EVQ;
        if (w->q[prv].t == GUI_EV_MOVE) {
            w->q[prv].x = x;
            w->q[prv].y = y;
            return;
        }
    }
    long nxt = (w->qt + 1) % GUI_EVQ;
    if (nxt == w->qh) {
        /* 队列满：新事件若非 MOVE，挤掉队头 MOVE 腾位（保 DOWN/UP/KEY）；
           新事件本身是 MOVE 则直接丢弃 */
        if (t == GUI_EV_MOVE) return;
        if (w->q[w->qh].t == GUI_EV_MOVE) {
            w->qh = (w->qh + 1) % GUI_EVQ;
            nxt = (w->qt + 1) % GUI_EVQ;
        } else return;
    }
    w->q[w->qt].t = t; w->q[w->qt].x = x;
    w->q[w->qt].y = y; w->q[w->qt].k = k;
    w->qt = nxt;
}

/* ---------- 引擎初始化（首次开窗时懒创建；失败返回 0） ---------- */
static int gui_engine_init(void) {
    if (g_d2d_fct) return 1;
    /* COM 初始化：D2D/DWrite/WIC 均走 COM。已是 MTA 时不致命（RPC_E_CHANGED_MODE） */
    if (SUCCEEDED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE)))
        g_com_ready = 1;

    D2D1_FACTORY_OPTIONS fopt;
    memset(&fopt, 0, sizeof(fopt));
    if (FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &IID_ID2D1Factory1,
                                &fopt, (void **)&g_d2d_fct)))
        return 0;
    if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &gui_iid_dwrite,
                                   (IUnknown **)&g_dw)))
        return 0;
    if (FAILED(CoCreateInstance(&CLSID_WICImagingFactory, NULL, CLSCTX_INPROC_SERVER,
                                &IID_IWICImagingFactory, (void **)&g_wic)))
        return 0;

    /* D3D11 设备：硬件优先，失败退 WARP（远程桌面/无 GPU 环境仍可渲染） */
    D3D_FEATURE_LEVEL lv[] = { D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0,
                               D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0 };
    D3D_FEATURE_LEVEL got = 0;
    HRESULT hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL,
                                   D3D11_CREATE_DEVICE_BGRA_SUPPORT, lv, 4,
                                   D3D11_SDK_VERSION, &g_d3d, &got, NULL);
    if (FAILED(hr) || !g_d3d)
        hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_WARP, NULL,
                               D3D11_CREATE_DEVICE_BGRA_SUPPORT, lv, 4,
                               D3D11_SDK_VERSION, &g_d3d, &got, NULL);
    if (FAILED(hr) || !g_d3d) return 0;

    IDXGIDevice *dxdev = NULL;
    if (FAILED(ID3D11Device_QueryInterface(g_d3d, &IID_IDXGIDevice, (void **)&dxdev))) return 0;
    hr = FACT1(g_d2d_fct, CreateDevice, dxdev, &g_d2d_dev);
    IDXGIAdapter *ad = NULL;
    if (SUCCEEDED(hr)) IDXGIDevice_GetAdapter(dxdev, &ad);
    if (ad) {
        IDXGIAdapter_GetParent(ad, &IID_IDXGIFactory2, (void **)&g_dxgi);
        REL(ad);
    }
    REL(dxdev);
    if (!g_d2d_dev || !g_dxgi) return 0;

    /* 统一描边样式：平头、斜接，抗锯齿由 target 决定 */
    D2D1_STROKE_STYLE_PROPERTIES sp;
    memset(&sp, 0, sizeof(sp));
    sp.startCap = D2D1_CAP_STYLE_FLAT;
    sp.endCap = D2D1_CAP_STYLE_FLAT;
    sp.dashCap = D2D1_CAP_STYLE_FLAT;
    sp.lineJoin = D2D1_LINE_JOIN_MITER;
    sp.miterLimit = 10.0f;
    FACT(g_d2d_fct, CreateStrokeStyle, &sp, NULL, 0, &g_stroke_flat);
    return 1;
}

/* ---------- 文本格式缓存（64 槽 LRU，键 = 族/物理字号/字重/斜体） ---------- */
static IDWriteTextFormat *gui_text_format(gui_win *w, const char *family,
                                          int px, int weight, int italic) {
    if (!g_dw || !w) return NULL;
    const char *fam = (family && family[0]) ? family : "Microsoft YaHei UI";
    if (px <= 0) px = 16;
    float size = (float)((px * w->dpi + 95) / 96);   /* 逻辑 px → 物理 px */
    if (size < 1.0f) size = 1.0f;

    gui_tf_slot *victim = &g_tf[0];
    for (int i = 0; i < GUI_TF_SLOTS; i++) {
        gui_tf_slot *s = &g_tf[i];
        if (s->used) {
            if (s->size == size && s->weight == weight && s->italic == italic
                && strncmp(s->family, fam, sizeof(s->family) - 1) == 0) {
                s->stamp = ++g_tf_tick;
                return s->fmt;
            }
            if (s->stamp < victim->stamp || !victim->used) victim = s;
        } else if (!victim->used) {
            victim = s;
        }
    }
    /* 淘汰最久未用槽（固定 64 槽，不做动态增长） */
    REL(victim->fmt);
    memset(victim, 0, sizeof(*victim));

    wchar_t wfam[64];
    int n = MultiByteToWideChar(CP_UTF8, 0, fam, -1, wfam, 64);
    if (n <= 0) { wcscpy(wfam, L"Microsoft YaHei UI"); }
    IDWriteTextFormat *fmt = NULL;
    if (FAILED(IDWriteFactory_CreateTextFormat(g_dw, wfam, NULL,
            (DWRITE_FONT_WEIGHT)weight, italic ? DWRITE_FONT_STYLE_ITALIC : DWRITE_FONT_STYLE_NORMAL,
            DWRITE_FONT_STRETCH_NORMAL, size, L"zh-cn", &fmt)))
        return NULL;
    strncpy(victim->family, fam, sizeof(victim->family) - 1);
    victim->family[sizeof(victim->family) - 1] = 0;
    victim->size = size;
    victim->weight = weight;
    victim->italic = italic ? 1 : 0;
    victim->fmt = fmt;
    victim->stamp = ++g_tf_tick;
    victim->used = 1;
    return fmt;
}

/* ---------- 颜色：0xAARRGGBB → 乘全局 alpha → D2D1_COLOR_F ---------- */
static uint32_t gui_argb_eff(gui_win *w, uint32_t c) {
    uint32_t a = (c >> 24) & 0xFFu;
    if (a == 0 && (c & 0x00FFFFFFu) != 0) a = 0xFFu;   /* 兼容旧 0xRRGGBB */
    a = a * (uint32_t)(w->alpha < 0 ? 0 : (w->alpha > 255 ? 255 : w->alpha)) / 255u;
    return (a << 24) | (c & 0x00FFFFFFu);
}

static D2D1_COLOR_F gui_color(uint32_t argb) {
    D2D1_COLOR_F c;
    c.a = (float)((argb >> 24) & 0xFFu) / 255.0f;
    c.r = (float)((argb >> 16) & 0xFFu) / 255.0f;
    c.g = (float)((argb >> 8) & 0xFFu) / 255.0f;
    c.b = (float)(argb & 0xFFu) / 255.0f;
    return c;
}

/* ---------- 纯色画刷缓存（每窗口 64 槽 LRU） ---------- */
static void gui_br_flush(gui_win *w) {
    for (int i = 0; i < GUI_BR_SLOTS; i++) {
        REL(w->br[i].br);
        w->br[i].br = NULL;
        w->br[i].used = 0;
    }
}

static ID2D1SolidColorBrush *gui_brush(gui_win *w, uint32_t argb) {
    if (!w || !w->ctx) return NULL;
    uint32_t eff = gui_argb_eff(w, argb);
    gui_br_slot *victim = &w->br[0];
    for (int i = 0; i < GUI_BR_SLOTS; i++) {
        gui_br_slot *s = &w->br[i];
        if (s->used) {
            if (s->argb == eff) {
                s->stamp = ++w->br_tick;
                return s->br;
            }
            if (!victim->used || s->stamp < victim->stamp) victim = s;
        } else if (!victim->used) {
            victim = s;
        }
    }
    REL(victim->br);
    memset(victim, 0, sizeof(*victim));
    D2D1_COLOR_F col = gui_color(eff);
    ID2D1SolidColorBrush *br = NULL;
    if (FAILED(RT_V(w->ctx, CreateSolidColorBrush, &col, NULL, &br))) return NULL;
    victim->argb = eff;
    victim->br = br;
    victim->stamp = ++w->br_tick;
    victim->used = 1;
    return br;
}

/* ---------- 混合模式：几何绘制统一入口 ---------- */
static void gui_draw_geo_brush(gui_win *w, ID2D1Geometry *geo, ID2D1Brush *br, float sw);

/* CPU 合成（模式 2/3/4）：把几何画到透明源位图，回读目标区，逐像素混合后上传绘制 */
static int gui_scr_ensure(gui_win *w, int bw, int bh) {
    if (bw < 1 || bh < 1) return 0;
    if (w->scr_w >= bw && w->scr_h >= bh && w->scr_src && w->scr_dst && w->scr_up && w->scr_buf)
        return 1;
    int nw = bw > 1 ? ((bw + 31) / 32) * 32 : 32;
    int nh = bh > 1 ? ((bh + 31) / 32) * 32 : 32;
    if (w->scr_w >= nw && w->scr_h >= nh) return 1;   /* 已有更大缓存，直接复用 */

    REL(w->scr_src); REL(w->scr_dst); REL(w->scr_up); w->scr_src = w->scr_dst = w->scr_up = NULL;
    free(w->scr_buf); w->scr_buf = NULL;
    w->scr_w = w->scr_h = 0;

    D2D1_BITMAP_PROPERTIES1 tp;
    memset(&tp, 0, sizeof(tp));
    tp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    tp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    tp.dpiX = 96; tp.dpiY = 96;
    tp.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET;
    D2D1_SIZE_U sz;
    sz.width = (UINT32)nw; sz.height = (UINT32)nh;
    if (FAILED(DC_V(w->ctx, CreateBitmap, sz, NULL, 0, &tp, &w->scr_src))) return 0;

    D2D1_BITMAP_PROPERTIES1 cp;
    memset(&cp, 0, sizeof(cp));
    cp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    cp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    cp.dpiX = 96; cp.dpiY = 96;
    cp.bitmapOptions = D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
    if (FAILED(DC_V(w->ctx, CreateBitmap, sz, NULL, 0, &cp, &w->scr_dst))) {
        REL(w->scr_src); w->scr_src = NULL;
        return 0;
    }

    D2D1_BITMAP_PROPERTIES1 up;
    memset(&up, 0, sizeof(up));
    up.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    up.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    up.dpiX = 96; up.dpiY = 96;
    up.bitmapOptions = D2D1_BITMAP_OPTIONS_NONE;
    if (FAILED(DC_V(w->ctx, CreateBitmap, sz, NULL, 0, &up, &w->scr_up))) {
        REL(w->scr_src); REL(w->scr_dst);
        w->scr_src = w->scr_dst = NULL;
        return 0;
    }
    w->scr_buf = (unsigned char *)malloc((size_t)nw * (size_t)nh * 4);
    if (!w->scr_buf) {
        REL(w->scr_src); REL(w->scr_dst); REL(w->scr_up);
        w->scr_src = w->scr_dst = w->scr_up = NULL;
        return 0;
    }
    w->scr_w = nw; w->scr_h = nh;
    return 1;
}

static void gui_blend_composite(gui_win *w, ID2D1Geometry *geo, ID2D1Brush *br,
                                float sw, int bx, int by, int bw, int bh) {
    if (!gui_scr_ensure(w, bw, bh)) return;
    /* 1) 源：透明底上画图元（偏移到临时位图局部坐标） */
    DC_V(w->ctx, SetTarget, (ID2D1Image *)w->scr_src);
    RT_V(w->ctx, Clear, NULL);
    D2D1_MATRIX_3X2_F tr = { 1.0f, 0.0f, 0.0f, 1.0f, (float)-bx, (float)-by };
    RT_V(w->ctx, SetTransform, &tr);
    if (sw > 0.0f) RT_V(w->ctx, DrawGeometry, geo, br, sw, g_stroke_flat);
    else          RT_V(w->ctx, FillGeometry, geo, br);
    D2D1_MATRIX_3X2_F id = { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f };
    RT_V(w->ctx, SetTransform, &id);
    RT_V(w->ctx, Flush, NULL, NULL);

    /* 2) 目标区快照（源位图不再是当前目标后才可回读） */
    DC_V(w->ctx, SetTarget, (ID2D1Image *)NULL);
    D2D1_POINT_2U dp;
    dp.x = 0; dp.y = 0;
    D2D1_RECT_U sr;
    sr.left = (UINT32)bx; sr.top = (UINT32)by;
    sr.right = (UINT32)(bx + bw); sr.bottom = (UINT32)(by + bh);
    HRESULT hr = BM_V(w->scr_src, CopyFromBitmap, &dp, (ID2D1Bitmap *)w->scr_src, &sr);
    (void)hr;
    D2D1_MAPPED_RECT ms, md;
    memset(&ms, 0, sizeof(ms));
    memset(&md, 0, sizeof(md));
    if (SUCCEEDED(BM1_V(w->scr_src, Map, D2D1_MAP_OPTIONS_READ, &ms))) {
        /* 源位图不可 Map（GPU 位图），先转存到 CPU 可读位图 */
        BM1_V(w->scr_src, Unmap);
    }
    memset(&ms, 0, sizeof(ms));
    hr = BM_V(w->scr_dst, CopyFromBitmap, &dp, (ID2D1Bitmap *)w->scr_src, &sr);
    DC_V(w->ctx, SetTarget, (ID2D1Image *)NULL);
    if (SUCCEEDED(BM1_V(w->scr_dst, Map, D2D1_MAP_OPTIONS_READ, &md))) {
        for (int y = 0; y < bh; y++) {
            const unsigned char *srow = (const unsigned char *)md.bits + (size_t)y * md.pitch;
            unsigned char *orow = w->scr_buf + (size_t)y * (size_t)(bw * 4);
            memcpy(orow, srow, (size_t)bw * 4);
        }
        BM1_V(w->scr_dst, Unmap);
    }
    /* 3) 目的像素快照：直接用同一 CPU 可读位图再取一次目标内容 */
    ID2D1Bitmap1 *dstSnap = NULL;
    D2D1_BITMAP_PROPERTIES1 cp;
    memset(&cp, 0, sizeof(cp));
    cp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    cp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    cp.dpiX = 96; cp.dpiY = 96;
    cp.bitmapOptions = D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
    D2D1_SIZE_U dsz;
    dsz.width = (UINT32)bw; dsz.height = (UINT32)bh;
    if (SUCCEEDED(DC_V(w->ctx, CreateBitmap, dsz, NULL, 0, &cp, &dstSnap))) {
        D2D1_MAPPED_RECT mdst;
        memset(&mdst, 0, sizeof(mdst));
        if (SUCCEEDED(BM_V(dstSnap, CopyFromBitmap, &dp, (ID2D1Bitmap *)w->target, &sr))
            && SUCCEEDED(BM1_V(dstSnap, Map, D2D1_MAP_OPTIONS_READ, &mdst))) {
            for (int y = 0; y < bh; y++) {
                const unsigned char *drow = (const unsigned char *)mdst.bits + (size_t)y * mdst.pitch;
                unsigned char *orow = w->scr_buf + (size_t)y * (size_t)(bw * 4);
                const unsigned char *srow = orow;
                unsigned char *res = (unsigned char *)malloc((size_t)bw * 4);
                if (!res) break;
                for (int x = 0; x < bw; x++) {
                    float ab = (float)drow[x * 4 + 3] / 255.0f;
                    float as = (float)srow[x * 4 + 3] / 255.0f;
                    float ao = as + ab * (1.0f - as);
                    for (int ch = 0; ch < 3; ch++) {
                        float sc = (float)srow[x * 4 + ch] / 255.0f;   /* 预乘源 */
                        float dc = (float)drow[x * 4 + ch] / 255.0f;   /* 预乘目标 */
                        float bo;
                        if (w->blend == GUI_BLEND_MULTIPLY)      bo = dc * (ab > 0.0f ? sc / ab : 0.0f);
                        else if (w->blend == GUI_BLEND_SCREEN)   bo = dc / ab + (ab > 0.0f ? sc / ab : 0.0f)
                                                                      - dc * (ab > 0.0f ? sc / ab : 0.0f) / ab;
                        else                                    bo = (dc / (ab > 0.0001f ? ab : 1.0f)) -
                                                                     (dc / (ab > 0.0001f ? ab : 1.0f) - sc / (as > 0.0001f ? as : 1.0f));
                        /* 标准复合：Co = sp*(1-ab) + as*ab*B + dp*(1-as) */
                        float co = sc * (1.0f - ab) + as * ab * bo + dc * (1.0f - as);
                        if (co < 0.0f) co = 0.0f;
                        if (co > 1.0f) co = 1.0f;
                        res[x * 4 + ch] = (unsigned char)(co * 255.0f + 0.5f);
                    }
                    res[x * 4 + 3] = (unsigned char)(ao * 255.0f + 0.5f);
                }
                memcpy(orow, res, (size_t)bw * 4);
                free(res);
            }
            BM1_V(dstSnap, Unmap);
            /* 4) 上传并画回目标区 */
            D2D1_RECT_U ur;
            ur.left = 0; ur.top = 0;
            ur.right = (UINT32)bw; ur.bottom = (UINT32)bh;
            if (SUCCEEDED(BM_V(w->scr_up, CopyFromMemory, &ur, w->scr_buf, (UINT32)(bw * 4))) && w->target) {
                DC_V(w->ctx, SetTarget, (ID2D1Image *)w->target);
                D2D1_RECT_F dest;
                dest.left = (float)bx; dest.top = (float)by;
                dest.right = (float)(bx + bw); dest.bottom = (float)(by + bh);
                RT_V(w->ctx, DrawBitmap, (ID2D1Bitmap *)w->scr_up, &dest, 1.0f,
                      D2D1_BITMAP_INTERPOLATION_MODE_NEAREST_NEIGHBOR, NULL);
            }
        }
        REL(dstSnap);
    }
    DC_V(w->ctx, SetTarget, (ID2D1Image *)w->target);
}

static void gui_draw_geo_brush(gui_win *w, ID2D1Geometry *geo, ID2D1Brush *br, float sw) {
    if (!w || !w->ctx || !geo || !br) return;
    if (w->blend == GUI_BLEND_SRCOVER) {
        if (sw > 0.0f) RT_V(w->ctx, DrawGeometry, geo, br, sw, g_stroke_flat);
        else           RT_V(w->ctx, FillGeometry, geo, br);
        return;
    }
    if (w->blend == GUI_BLEND_ADD) {
        DC_V(w->ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_ADD);
        if (sw > 0.0f) RT_V(w->ctx, DrawGeometry, geo, br, sw, g_stroke_flat);
        else           RT_V(w->ctx, FillGeometry, geo, br);
        DC_V(w->ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_SOURCE_OVER);
        return;
    }
    /* 2=Multiply 3=Screen 4=Xor：包围盒内 CPU 合成 */
    D2D1_RECT_F bb;
    if (FAILED(GEO(geo, GetBounds, NULL, &bb))) return;
    float pad = (sw > 0.0f ? sw : 0.0f) + 2.0f;
    int bx = (int)(bb.left - pad), by = (int)(bb.top - pad);
    int bx2 = (int)(bb.right + pad + 0.5f), by2 = (int)(bb.bottom + pad + 0.5f);
    if (bx < 0) bx = 0;
    if (by < 0) by = 0;
    if (bx2 > w->w) bx2 = w->w;
    if (by2 > w->h) by2 = w->h;
    int bw = bx2 - bx, bh = by2 - by;
    if (bw <= 0 || bh <= 0) return;
    DC_V(w->ctx, SetTarget, (ID2D1Image *)w->target);
    gui_blend_composite(w, geo, br, sw, bx, by, bw, bh);
}
static void gui_draw_geo(gui_win *w, ID2D1Geometry *geo, uint32_t argb, float sw) {
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    gui_draw_geo_brush(w, geo, (ID2D1Brush *)br, sw);
}

static gui_win *gui_win_of(HWND hw) {
    return (gui_win *)(INT_PTR)GetWindowLongPtrW(hw, GWLP_USERDATA);
}

/* ---------- 渲染目标（交换链 + 目标位图） ---------- */
static int gui_rt_bind_target(gui_win *w) {
    if (!w->ctx || !w->swap) return 0;
    if (w->target) {
        w->ctx->lpVtbl->SetTarget(w->ctx, NULL);
        REL(w->target);
        w->target = NULL;
    }
    IDXGISurface *surf = NULL;
    if (FAILED(IDXGISwapChain1_GetBuffer(w->swap, 0, &IID_IDXGISurface, (void **)&surf))) return 0;
    D2D1_BITMAP_PROPERTIES1 bp;
    memset(&bp, 0, sizeof(bp));
    bp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    bp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    bp.dpiX = 96; bp.dpiY = 96;
    bp.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
    HRESULT hr = DC_V(w->ctx, CreateBitmapFromDxgiSurface, surf, &bp, &w->target);
    REL(surf);
    if (FAILED(hr) || !w->target) return 0;
    w->ctx->lpVtbl->SetTarget(w->ctx, (ID2D1Image *)w->target);
    return 1;
}

static void gui_rt_release(gui_win *w) {
    gui_br_flush(w);
    REL(w->scr_src); REL(w->scr_dst); REL(w->scr_up);
    w->scr_src = w->scr_dst = w->scr_up = NULL;
    free(w->scr_buf);
    w->scr_buf = NULL;
    w->scr_w = w->scr_h = 0;
    if (w->ctx && w->target) w->ctx->lpVtbl->SetTarget(w->ctx, NULL);
    REL(w->target); w->target = NULL;
    REL(w->ctx); w->ctx = NULL;
    REL(w->swap); w->swap = NULL;
}

static int gui_rt_create(gui_win *w) {
    DXGI_SWAP_CHAIN_DESC1 sd;
    memset(&sd, 0, sizeof(sd));
    sd.Width = (UINT32)(w->w > 0 ? w->w : 1);
    sd.Height = (UINT32)(w->h > 0 ? w->h : 1);
    sd.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    sd.SampleDesc.Count = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.BufferCount = 2;
    sd.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    sd.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
    sd.Scaling = DXGI_SCALING_NONE;
    if (FAILED(IDXGIFactory2_CreateSwapChainForHwnd(g_dxgi, (IUnknown *)g_d3d, w->hwnd,
                                                   &sd, NULL, NULL, &w->swap)))
        return 0;
    IDXGIFactory2_MakeWindowAssociation(g_dxgi, w->hwnd, DXGI_MWA_NO_ALT_ENTER);
    if (FAILED(g_d2d_dev->lpVtbl->CreateDeviceContext(g_d2d_dev,
                                                      D2D1_DEVICE_CONTEXT_OPTIONS_NONE, &w->ctx)))
        return 0;
    RT_V(w->ctx, SetDpi, 96.0f, 96.0f);
    RT_V(w->ctx, SetAntialiasMode, D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
    RT_V(w->ctx, SetTextAntialiasMode, D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);
    if (!gui_rt_bind_target(w)) return 0;
    return 1;
}

static void gui_rt_resize(gui_win *w, int nw, int nh) {
    if (!w->swap || !w->ctx) { w->w = nw; w->h = nh; return; }
    if (w->target) {
        w->ctx->lpVtbl->SetTarget(w->ctx, NULL);
        REL(w->target);
        w->target = NULL;
    }
    if (FAILED(IDXGISwapChain1_ResizeBuffers(w->swap, 0, (UINT32)nw, (UINT32)nh,
                                             DXGI_FORMAT_UNKNOWN, 0))) {
        w->w = nw; w->h = nh;
        return;
    }
    w->w = nw; w->h = nh;
    gui_rt_bind_target(w);
    /* 临时合成位图尺寸随目标变化，下一次混合绘制会自动重建 */
}

static LRESULT CALLBACK gui_wndproc(HWND hw, UINT msg, WPARAM wp, LPARAM lp) {
    gui_win *w = gui_win_of(hw);
    if (!w) return DefWindowProcW(hw, msg, wp, lp);   /* 创建期消息 */
    switch (msg) {
    case WM_SIZE:
        /* 最小化不重建；尺寸变化时重建交换链缓冲并通知业务层重布局 */
        if (w->alive && wp != SIZE_MINIMIZED) {
            int nw = LOWORD(lp), nh = HIWORD(lp);
            if (nw > 0 && nh > 0 && (nw != w->w || nh != w->h)) {
                gui_rt_resize(w, nw, nh);
                gui_push_ev(w, GUI_EV_SIZE, nw, nh, 0);
            }
        }
        return 0;
    case WM_PAINT: {
        /* 交换链内容自持（Flip 模型），这里只校验更新区防刷屏重绘 */
        PAINTSTRUCT ps;
        BeginPaint(hw, &ps);
        EndPaint(hw, &ps);
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;                          /* 防闪烁：擦背景交给 present */
    case WM_MOUSEMOVE:
        gui_push_ev(w, GUI_EV_MOVE, (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0);
        return 0;
    case WM_LBUTTONDOWN: gui_push_ev(w, GUI_EV_LDOWN, (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0); return 0;
    case WM_LBUTTONUP:   gui_push_ev(w, GUI_EV_LUP,   (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0); return 0;
    case WM_RBUTTONDOWN: gui_push_ev(w, GUI_EV_RDOWN, (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0); return 0;
    case WM_RBUTTONUP:   gui_push_ev(w, GUI_EV_RUP,   (int16_t)(lp & 0xFFFF), (int16_t)(lp >> 16), 0); return 0;
    case WM_MOUSEWHEEL:
        gui_push_ev(w, GUI_EV_WHEEL, 0, 0, (int16_t)(wp >> 16));
        return 0;
    case WM_KEYDOWN: {
        int vk = (int)wp;
        /* Ctrl+C/V/A/X：WM_CHAR 只会送出控制码，这里统一成显式组合键事件 */
        if ((vk == 'C' || vk == 'V' || vk == 'A' || vk == 'X')
            && (GetKeyState(VK_CONTROL) < 0)) {
            gui_push_ev(w, GUI_EV_KEY, 0, 0, GUI_KEY_CTRL | vk);
            return 0;
        }
        /* 导航/编辑键不走 WM_CHAR，显式推送；Shift 按下时带 SHIFT 位（扩选） */
        if (vk == VK_LEFT || vk == VK_RIGHT || vk == VK_UP || vk == VK_DOWN
            || vk == VK_DELETE || vk == VK_HOME || vk == VK_END) {
            int64_t mod = GUI_KEY_EXT;
            if (GetKeyState(VK_SHIFT) < 0) mod |= GUI_KEY_SHIFT;
            gui_push_ev(w, GUI_EV_KEY, 0, 0, mod | vk);
        }
        return 0;
    }
    case WM_CHAR: {
        /* UTF-8 编码策略：WM_CHAR 送来的是 UTF-16 码元（中文一键一个码元，
           >0x7F 的值经 widgets 的 cast(k, char) 会截断成乱码字节）。这里把
           码元（含代理对）转成 UTF-8 字节序列，逐字节作为连续 KEY 事件入队
           ——业务层逐字节追加即拼出正确 UTF-8 串，与 string 内部表示一致 */
        static unsigned int pend_sur = 0;   /* 高代理暂存（键盘焦点唯一，进程级即可） */
        unsigned int cp = (unsigned int)wp;
        if (cp >= 0xD800 && cp <= 0xDBFF) { pend_sur = cp; return 0; }
        if (cp >= 0xDC00 && cp <= 0xDFFF && pend_sur) {
            cp = 0x10000u + ((pend_sur - 0xD800) << 10) + (cp - 0xDC00);
            pend_sur = 0;
        }
        unsigned char u8[4];
        int n;
        if (cp < 0x80)      { u8[0] = (unsigned char)cp; n = 1; }
        else if (cp < 0x800)  { u8[0] = 0xC0 | (cp >> 6); u8[1] = 0x80 | (cp & 0x3F); n = 2; }
        else if (cp < 0x10000){ u8[0] = 0xE0 | (cp >> 12); u8[1] = 0x80 | ((cp >> 6) & 0x3F); u8[2] = 0x80 | (cp & 0x3F); n = 3; }
        else { u8[0] = 0xF0 | (cp >> 18); u8[1] = 0x80 | ((cp >> 12) & 0x3F); u8[2] = 0x80 | ((cp >> 6) & 0x3F); u8[3] = 0x80 | (cp & 0x3F); n = 4; }
        for (int i = 0; i < n; i++)
            gui_push_ev(w, GUI_EV_KEY, 0, 0, (int64_t)u8[i]);
        return 0;
    }
    case WM_CLOSE:
        w->should_close = 1;
        DestroyWindow(hw);
        return 0;
    case WM_DESTROY:
        w->alive = 0;
        w->used = 0;
        w->hwnd = NULL;
        gui_rt_release(w);
        return 0;
    }
    return DefWindowProcW(hw, msg, wp, lp);
}

static wchar_t *gui_utf8_to_wide(const char *s) {
    int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
    if (n <= 0) n = 1;
    wchar_t *w = (wchar_t *)malloc((size_t)n * sizeof(wchar_t));
    MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n);
    return w;
}

int32_t zfy_gui_open(int32_t w, int32_t h, char *title_utf8) {
    gui_win *wslot = NULL;
    for (int i = 0; i < GUI_MAXWIN; i++)
        if (!g_wins[i].used) { wslot = &g_wins[i]; break; }
    if (!wslot) return -5;                 /* 窗口数达上限 */
    if (w <= 0 || h <= 0) return -2;
    /* 渲染引擎不可用：返回负数失败（绝不静默退回 GDI） */
    if (!gui_engine_init()) return -6;
    static int class_registered = 0;
    if (!class_registered) {
        WNDCLASSW wc;
        memset(&wc, 0, sizeof(wc));
        wc.lpfnWndProc = gui_wndproc;
        wc.hInstance = GetModuleHandleW(NULL);
        wc.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
        wc.hbrBackground = NULL;
        wc.lpszClassName = L"ZfyGuiWindow";
        if (!RegisterClassW(&wc)) return -3;
        class_registered = 1;
    }
    /* DPI 感知（进程级一次性）：Per-Monitor V2 优先，旧系统退回 SetProcessDPIAware。
       之后 w/h 是物理像素，DWM 不再拉伸——文字与像素逐一对齐，不糊 */
    typedef BOOL (WINAPI *SPDACfn)(void *);
    SPDACfn spdac = (SPDACfn)(void *)GetProcAddress(GetModuleHandleW(L"user32.dll"),
                                                    "SetProcessDpiAwarenessContext");
    if (spdac) spdac((void *)(INT_PTR)-4);       /* PER_MONITOR_AWARE_V2 */
    else SetProcessDPIAware();
    int dpi = 96;
    {
        HDC sdc = GetDC(NULL);
        dpi = GetDeviceCaps(sdc, LOGPIXELSX);
        ReleaseDC(NULL, sdc);
    }
    if (dpi <= 0) dpi = 96;
    w = w * dpi / 96;                      /* 逻辑尺寸 → 物理尺寸 */
    h = h * dpi / 96;
    wchar_t *wt = gui_utf8_to_wide(title_utf8 ? title_utf8 : "zfy");
    /* 可调尺寸窗口：客户区初始为 w x h */
    DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX
                | WS_MAXIMIZEBOX | WS_THICKFRAME;
    RECT rc = { 0, 0, w, h };
    AdjustWindowRect(&rc, style, 0);
    HWND hwnd = CreateWindowW(L"ZfyGuiWindow", wt,
                              style,
                              CW_USEDEFAULT, CW_USEDEFAULT,
                              rc.right - rc.left, rc.bottom - rc.top,
                              NULL, NULL, GetModuleHandleW(NULL), NULL);
    free(wt);
    if (!hwnd) return -4;
    memset(wslot, 0, sizeof(*wslot));
    wslot->hwnd = hwnd;
    wslot->w = w;
    wslot->h = h;
    wslot->dpi = dpi;
    wslot->alpha = 255;
    wslot->blend = GUI_BLEND_SRCOVER;
    wcscpy(wslot->tf_family, "Microsoft YaHei UI");
    wslot->tf_px = 16;
    wslot->tf_weight = 400;
    wslot->tf_italic = 0;
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)wslot);
    if (!gui_rt_create(wslot)) {
        DestroyWindow(hwnd);
        memset(wslot, 0, sizeof(*wslot));
        return -6;                          /* D2D 交换链创建失败 */
    }
    wslot->should_close = 0;
    wslot->alive = 1;
    wslot->used = 1;
    g_cur = wslot;
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    return 0;
}

/* 泵消息（非阻塞）+ 从当前窗口队列取一事件；返回 1=取到，0=无 */
int32_t zfy_gui_poll(int64_t *t, int64_t *x, int64_t *y, int64_t *k) {
    if (!g_cur) return 0;
    MSG msg;
    while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT) {
            for (int i = 0; i < GUI_MAXWIN; i++) g_wins[i].alive = 0;
            break;
        }
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
    if (!g_cur || g_cur->qh == g_cur->qt) return 0;
    *t = g_cur->q[g_cur->qh].t; *x = g_cur->q[g_cur->qh].x;
    *y = g_cur->q[g_cur->qh].y; *k = g_cur->q[g_cur->qh].k;
    g_cur->qh = (g_cur->qh + 1) % GUI_EVQ;
    return 1;
}

int32_t zfy_gui_alive(void)        { return g_cur ? g_cur->alive : 0; }
int32_t zfy_gui_should_close(void) { return g_cur ? g_cur->should_close : 1; }
int32_t zfy_gui_alive_any(void) {
    for (int i = 0; i < GUI_MAXWIN; i++)
        if (g_wins[i].used && g_wins[i].alive) return 1;
    return 0;
}
int32_t zfy_gui_self(void) {
    for (int i = 0; i < GUI_MAXWIN; i++)
        if (g_cur == &g_wins[i]) return i + 1;
    return 0;
}
void zfy_gui_select(int64_t id) {
    if (id >= 1 && id <= GUI_MAXWIN && g_wins[id - 1].used)
        g_cur = &g_wins[id - 1];
}
int32_t zfy_gui_w(void)            { return g_cur ? g_cur->w : 0; }
int32_t zfy_gui_h(void)            { return g_cur ? g_cur->h : 0; }
int32_t zfy_gui_dpi(void)          { return g_cur ? g_cur->dpi : 96; }

/* ---- 剪贴板（CF_UNICODETEXT，UTF-8 进出） ----
 * clip_get 返回写入 buf 的字节数（不含 \0）；-1=打开失败/无文本；-2=缓冲不足。
 * 失败时 buf 保持原样。调用频率低，无额外分配。 */
int32_t zfy_gui_clip_get(char *buf, int32_t cap) {
    if (!buf || cap <= 0) return -1;
    if (!OpenClipboard(NULL)) return -1;
    HANDLE h = GetClipboardData(CF_UNICODETEXT);
    if (!h) { CloseClipboard(); return -1; }
    wchar_t *w = (wchar_t *)GlobalLock(h);
    if (!w) { CloseClipboard(); return -1; }
    int need = WideCharToMultiByte(CP_UTF8, 0, w, -1, NULL, 0, NULL, NULL);
    if (need <= 0 || need > cap) {
        GlobalUnlock(h);
        CloseClipboard();
        return -2;
    }
    WideCharToMultiByte(CP_UTF8, 0, w, -1, buf, need, NULL, NULL);
    GlobalUnlock(h);
    CloseClipboard();
    return need - 1;                       /* 不含 \0 */
}

/* clip_set：把 UTF-8 文本放入剪贴板（替换现有内容；\n 由调用方自行决定格式） */
void zfy_gui_clip_set(char *utf8) {
    if (!utf8) utf8 = "";
    int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    if (wlen <= 0) return;
    HGLOBAL h = GlobalAlloc(GMEM_MOVEABLE, (size_t)wlen * sizeof(wchar_t));
    if (!h) return;
    wchar_t *w = (wchar_t *)GlobalLock(h);
    if (!w) { GlobalFree(h); return; }
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, w, wlen);
    GlobalUnlock(h);
    if (!OpenClipboard(NULL)) { GlobalFree(h); return; }
    EmptyClipboard();
    if (SetClipboardData(CF_UNICODETEXT, h) == NULL) GlobalFree(h);
    CloseClipboard();
}

void zfy_gui_close(void) {
    if (g_cur && g_cur->hwnd) {
        HWND hw = g_cur->hwnd;
        g_cur->hwnd = NULL;
        g_cur->alive = 0;
        g_cur->used = 0;
        DestroyWindow(hw);                 /* WM_DESTROY 里释放 D2D 资源 */
    }
}

void zfy_gui_title(char *title_utf8) {
    if (!g_cur || !g_cur->hwnd) return;
    wchar_t *wt = gui_utf8_to_wide(title_utf8 ? title_utf8 : "");
    SetWindowTextW(g_cur->hwnd, wt);
    free(wt);
}

/* 窗口图标（当前窗口）：path 为 .ico/.png 等系统可加载文件；失败静默 */
void zfy_gui_set_icon(char *path_utf8) {
    if (!g_cur || !g_cur->hwnd || !path_utf8) return;
    wchar_t *wp = gui_utf8_to_wide(path_utf8);
    HICON big = (HICON)LoadImageW(NULL, wp, IMAGE_ICON, 0, 0,
                                  LR_LOADFROMFILE | LR_DEFAULTSIZE);
    HICON small = (HICON)LoadImageW(NULL, wp, IMAGE_ICON,
                                    GetSystemMetrics(SM_CXSMICON),
                                    GetSystemMetrics(SM_CYSMICON), LR_LOADFROMFILE);
    free(wp);
    if (big)   SendMessageW(g_cur->hwnd, WM_SETICON, ICON_BIG, (LPARAM)big);
    if (small) SendMessageW(g_cur->hwnd, WM_SETICON, ICON_SMALL, (LPARAM)small);
}

/* 提交整帧：Flush + Present（每帧绘制完成后调用一次） */
void zfy_gui_present(void) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || !w->swap) return;
    RT_V(w->ctx, Flush, NULL, NULL);
    IDXGISwapChain1_Present(w->swap, 1, 0);
}

/* ---------- 图元 ---------- */

/* 矩形几何（混合模式路径用） */
static ID2D1RectangleGeometry *gui_rect_geo(int32_t x, int32_t y, int32_t w, int32_t h) {
    D2D1_RECT_F r;
    r.left = (float)x; r.top = (float)y;
    r.right = (float)(x + w); r.bottom = (float)(y + h);
    ID2D1RectangleGeometry *g = NULL;
    if (FAILED(FACT(g_d2d_fct, CreateRectangleGeometry, &r, &g))) return NULL;
    return g;
}

void zfy_gui_fill_rect(int32_t rx, int32_t ry, int32_t rw, int32_t rh, uint32_t argb) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (rw <= 0 || rh <= 0) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    D2D1_RECT_F r;
    r.left = (float)rx; r.top = (float)ry;
    r.right = (float)(rx + rw); r.bottom = (float)(ry + rh);
    if (w->blend == GUI_BLEND_SRCOVER) {
        RT_V(w->ctx, FillRectangle, &r, (ID2D1Brush *)br);
    } else if (w->blend == GUI_BLEND_ADD) {
        DC_V(w->ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_ADD);
        RT_V(w->ctx, FillRectangle, &r, (ID2D1Brush *)br);
        DC_V(w->ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_SOURCE_OVER);
    } else {
        ID2D1RectangleGeometry *g = gui_rect_geo(rx, ry, rw, rh);
        if (g) { gui_draw_geo_brush(w, (ID2D1Geometry *)g, (ID2D1Brush *)br, 0.0f); REL(g); }
    }
}

/* 描边矩形（真描边，替代旧 4 次填充模拟；width<=0 视为 1） */
void zfy_gui_stroke_rect(int32_t x, int32_t y, int32_t w, int32_t h,
                         uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (w <= 0 || h <= 0) return;
    float sw = (float)(width > 0 ? width : 1);
    float half = sw / 2.0f;
    D2D1_RECT_F r;
    r.left = (float)x + half; r.top = (float)y + half;
    r.right = (float)(x + w) - half; r.bottom = (float)(y + h) - half;
    if (r.right <= r.left || r.bottom <= r.top) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    RT_V(w->ctx, DrawRectangle, &r, (ID2D1Brush *)br, sw, g_stroke_flat);
}

/* 圆角矩形：fill=0 跳过填充，border=0 跳过描边（1px）；r 为逻辑半径 */
void zfy_gui_round_rect(int32_t x, int32_t y, int32_t w, int32_t h, int32_t r,
                        uint32_t fill, uint32_t border) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (w <= 0 || h <= 0) return;
    if (r * 2 > w) r = w / 2;
    if (r * 2 > h) r = h / 2;
    if (r < 0) r = 0;
    D2D1_ROUNDED_RECT rr;
    rr.rect.left = (float)x; rr.rect.top = (float)y;
    rr.rect.right = (float)(x + w); rr.rect.bottom = (float)(y + h);
    rr.radiusX = (float)r; rr.radiusY = (float)r;
    if (fill) {
        ID2D1SolidColorBrush *br = gui_brush(w, fill);
        if (br) {
            if (w->blend == GUI_BLEND_SRCOVER) {
                RT_V(w->ctx, FillRoundedRectangle, &rr, (ID2D1Brush *)br);
            } else {
                /* 圆角几何走统一混合路径 */
                ID2D1RoundedRectangleGeometry *g = NULL;
                if (SUCCEEDED(FACT(g_d2d_fct, CreateRoundedRectangleGeometry, &rr, &g)) && g) {
                    gui_draw_geo_brush(w, (ID2D1Geometry *)g, (ID2D1Brush *)br, 0.0f);
                    REL(g);
                }
            }
        }
    }
    if (border) {
        ID2D1SolidColorBrush *br = gui_brush(w, border);
        if (br) RT_V(w->ctx, DrawRoundedRectangle, &rr, (ID2D1Brush *)br, 1.0f, g_stroke_flat);
    }
}

/* 线段：width<=0 视为 1 */
void zfy_gui_line(int32_t x0, int32_t y0, int32_t x1, int32_t y1,
                  uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    float sw = (float)(width > 0 ? width : 1);
    if (w->blend == GUI_BLEND_SRCOVER) {
        D2D1_POINT_2F a, b;
        a.x = (float)x0; a.y = (float)y0; b.x = (float)x1; b.y = (float)y1;
        RT_V(w->ctx, DrawLine, a, b, (ID2D1Brush *)br, sw, g_stroke_flat);
        return;
    }
    ID2D1PathGeometry *pg = NULL;
    ID2D1GeometrySink *sink = NULL;
    if (FAILED(FACT(g_d2d_fct, CreatePathGeometry, &pg))) return;
    if (FAILED(PG(pg, Open, &sink))) { REL(pg); return; }
    SINK(sink, BeginFigure, (D2D1_POINT_2F){ (float)x0, (float)y0 }, D2D1_FIGURE_BEGIN_HOLLOW);
    SINK(sink, AddLine, &(D2D1_POINT_2F){ (float)x1, (float)y1 });
    SINK(sink, EndFigure, D2D1_FIGURE_END_OPEN);
    SINK_CLOSE(sink);
    REL(sink);
    gui_draw_geo_brush(w, (ID2D1Geometry *)pg, (ID2D1Brush *)br, sw);
    REL(pg);
}

/* 渐变矩形：c1→c2 线性插值，vertical 非 0 为纵向（D2D 线性渐变画刷） */
void zfy_gui_fill_grad(int32_t rx, int32_t ry, int32_t rw, int32_t rh,
                       uint32_t c1, uint32_t c2, int32_t vertical) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (rw <= 0 || rh <= 0) return;
    uint32_t e1 = gui_argb_eff(w, c1), e2 = gui_argb_eff(w, c2);
    D2D1_GRADIENT_STOP stops[2];
    stops[0].position = 0.0f;  stops[0].color = gui_color(e1);
    stops[1].position = 1.0f;  stops[1].color = gui_color(e2);
    ID2D1GradientStopCollection *coll = NULL;
    if (FAILED(RT_V(w->ctx, CreateGradientStopCollection, stops, 2,
                    D2D1_GAMMA_2_2, D2D1_EXTEND_MODE_CLAMP, &coll)))
        return;
    D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES gp;
    if (vertical) {
        gp.startPoint.x = (float)rx; gp.startPoint.y = (float)ry;
        gp.endPoint.x = (float)rx;   gp.endPoint.y = (float)(ry + rh);
    } else {
        gp.startPoint.x = (float)rx; gp.startPoint.y = (float)ry;
        gp.endPoint.x = (float)(rx + rw); gp.endPoint.y = (float)ry;
    }
    ID2D1LinearGradientBrush *br = NULL;
    if (FAILED(RT_V(w->ctx, CreateLinearGradientBrush, &gp, NULL, coll, &br))) {
        REL(coll);
        return;
    }
    D2D1_RECT_F r;
    r.left = (float)rx; r.top = (float)ry;
    r.right = (float)(rx + rw); r.bottom = (float)(ry + rh);
    if (w->blend == GUI_BLEND_SRCOVER) {
        RT_V(w->ctx, FillRectangle, &r, (ID2D1Brush *)br);
    } else {
        ID2D1RectangleGeometry *g = gui_rect_geo(rx, ry, rw, rh);
        if (g) { gui_draw_geo_brush(w, (ID2D1Geometry *)g, (ID2D1Brush *)br, 0.0f); REL(g); }
    }
    REL(br);
    REL(coll);
}

/* 圆：填充 / 描边 */
void zfy_gui_fill_circle(int32_t cx, int32_t cy, int32_t r, uint32_t argb) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || r <= 0) return;
    D2D1_ELLIPSE e;
    e.point.x = (float)cx; e.point.y = (float)cy;
    e.radiusX = (float)r; e.radiusY = (float)r;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    if (w->blend == GUI_BLEND_SRCOVER) {
        RT_V(w->ctx, FillEllipse, &e, (ID2D1Brush *)br);
        return;
    }
    ID2D1EllipseGeometry *g = NULL;
    if (SUCCEEDED(FACT(g_d2d_fct, CreateEllipseGeometry, &e, &g)) && g) {
        gui_draw_geo_brush(w, (ID2D1Geometry *)g, (ID2D1Brush *)br, 0.0f);
        REL(g);
    }
}

void zfy_gui_stroke_circle(int32_t cx, int32_t cy, int32_t r, uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || r <= 0) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    D2D1_ELLIPSE e;
    float sw = (float)(width > 0 ? width : 1);
    e.point.x = (float)cx; e.point.y = (float)cy;
    e.radiusX = (float)r - sw / 2.0f;
    e.radiusY = (float)r - sw / 2.0f;
    if (e.radiusX < 0.5f || e.radiusY < 0.5f) return;
    RT_V(w->ctx, DrawEllipse, &e, (ID2D1Brush *)br, sw, g_stroke_flat);
}

/* 圆弧：角度制，0°=+x 轴，正角度顺时针（屏幕 y 向下）；a0→a1 */
void zfy_gui_arc(int32_t cx, int32_t cy, int32_t r, double a0, double a1,
                 uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || r <= 0) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (!br) return;
    double rad0 = a0 * 3.14159265358979323846 / 180.0;
    double rad1 = a1 * 3.14159265358979323846 / 180.0;
    double span = a1 - a0;
    while (span >= 360.0) span -= 360.0;
    while (span <= -360.0) span += 360.0;
    if (span == 0.0) return;
    ID2D1PathGeometry *pg = NULL;
    ID2D1GeometrySink *sink = NULL;
    if (FAILED(FACT(g_d2d_fct, CreatePathGeometry, &pg))) return;
    if (FAILED(PG(pg, Open, &sink))) { REL(pg); return; }
    D2D1_POINT_2F start;
    start.x = (float)(cx + r * cos(rad0));
    start.y = (float)(cy + r * sin(rad0));
    SINK(sink, BeginFigure, start, D2D1_FIGURE_BEGIN_HOLLOW);
    D2D1_ARC_SEGMENT seg;
    seg.point.x = (float)(cx + r * cos(rad1));
    seg.point.y = (float)(cy + r * sin(rad1));
    seg.size.width = (float)r; seg.size.height = (float)r;
    seg.rotationAngle = 0.0f;
    seg.sweepDirection = span > 0.0 ? D2D1_SWEEP_DIRECTION_CLOCKWISE
                                    : D2D1_SWEEP_DIRECTION_COUNTER_CLOCKWISE;
    seg.arcSize = (span > 180.0 || span < -180.0) ? D2D1_ARC_SIZE_LARGE : D2D1_ARC_SIZE_SMALL;
    SINK(sink, AddArc, &seg);
    SINK(sink, EndFigure, D2D1_FIGURE_END_OPEN);
    SINK_CLOSE(sink);
    REL(sink);
    float sw = (float)(width > 0 ? width : 1);
    RT_V(w->ctx, DrawGeometry, (ID2D1Geometry *)pg, (ID2D1Brush *)br, sw, g_stroke_flat);
    REL(pg);
}

/* 多边形：pts 为 x,y 交错整数数组（物理像素），n 为点数 */
static ID2D1PathGeometry *gui_poly_geo(int32_t *pts, int32_t n, int closed) {
    if (!pts || n < 2) return NULL;
    ID2D1PathGeometry *pg = NULL;
    ID2D1GeometrySink *sink = NULL;
    if (FAILED(FACT(g_d2d_fct, CreatePathGeometry, &pg))) return NULL;
    if (FAILED(PG(pg, Open, &sink))) { REL(pg); return NULL; }
    SINK(sink, BeginFigure, (D2D1_POINT_2F){ (float)pts[0], (float)pts[1] },
         closed ? D2D1_FIGURE_BEGIN_FILLED : D2D1_FIGURE_BEGIN_HOLLOW);
    for (int i = 1; i < n; i++)
        SINK(sink, AddLine, &(D2D1_POINT_2F){ (float)pts[i * 2], (float)pts[i * 2 + 1] });
    SINK(sink, EndFigure, closed ? D2D1_FIGURE_END_CLOSED : D2D1_FIGURE_END_OPEN);
    SINK_CLOSE(sink);
    REL(sink);
    return pg;
}

void zfy_gui_fill_poly(int32_t *pts, int32_t n, uint32_t argb) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    ID2D1PathGeometry *pg = gui_poly_geo(pts, n, 1);
    if (!pg) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (br) gui_draw_geo_brush(w, (ID2D1Geometry *)pg, (ID2D1Brush *)br, 0.0f);
    REL(pg);
}

void zfy_gui_stroke_poly(int32_t *pts, int32_t n, uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    ID2D1PathGeometry *pg = gui_poly_geo(pts, n, 0);
    if (!pg) return;
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (br) gui_draw_geo_brush(w, (ID2D1Geometry *)pg, (ID2D1Brush *)br,
                               (float)(width > 0 ? width : 1));
    REL(pg);
}

/* 二次贝塞尔（一个控制点） */
void zfy_gui_bezier(int32_t x0, int32_t y0, int32_t cx, int32_t cy,
                    int32_t x1, int32_t y1, uint32_t argb, int32_t width) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    ID2D1PathGeometry *pg = NULL;
    ID2D1GeometrySink *sink = NULL;
    if (FAILED(FACT(g_d2d_fct, CreatePathGeometry, &pg))) return;
    if (FAILED(PG(pg, Open, &sink))) { REL(pg); return; }
    SINK(sink, BeginFigure, (D2D1_POINT_2F){ (float)x0, (float)y0 }, D2D1_FIGURE_BEGIN_HOLLOW);
    D2D1_BEZIER_SEGMENT seg;
    seg.point1.x = (float)cx; seg.point1.y = (float)cy;
    seg.point2.x = (float)cx; seg.point2.y = (float)cy;
    seg.point3.x = (float)x1; seg.point3.y = (float)y1;
    SINK(sink, AddBezier, &seg);
    SINK(sink, EndFigure, D2D1_FIGURE_END_OPEN);
    SINK_CLOSE(sink);
    REL(sink);
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (br) gui_draw_geo_brush(w, (ID2D1Geometry *)pg, (ID2D1Brush *)br,
                               (float)(width > 0 ? width : 1));
    REL(pg);
}

/* ---------- 文本 ---------- */

static IDWriteTextLayout *gui_make_layout(gui_win *w, const wchar_t *txt, int len,
                                          IDWriteTextFormat *fmt) {
    IDWriteTextLayout *lay = NULL;
    if (!fmt) return NULL;
    if (FAILED(IDWriteFactory_CreateTextLayout(g_dw, txt, (UINT32)len, fmt,
                                               100000.0f, 100000.0f, &lay)))
        return NULL;
    IDWriteTextLayout_SetWordWrapping(lay, DWRITE_WORD_WRAPPING_NO_WRAP);
    (void)w;
    return lay;
}

/* 设置当前默认文本样式：family 空串 = 微软雅黑；weight 400/700 等；italic 非 0 斜体 */
void zfy_gui_font_ex(char *family_utf8, int32_t px, int32_t weight, int32_t italic) {
    gui_win *w = g_cur;
    if (!w) return;
    if (px <= 0) px = 16;
    if (weight < 100) weight = 400;
    if (weight > 950) weight = 700;
    if (family_utf8 && family_utf8[0]) {
        strncpy(w->tf_family, family_utf8, sizeof(w->tf_family) - 1);
        w->tf_family[sizeof(w->tf_family) - 1] = 0;
    } else {
        strncpy(w->tf_family, "Microsoft YaHei UI", sizeof(w->tf_family) - 1);
        w->tf_family[sizeof(w->tf_family) - 1] = 0;
    }
    w->tf_px = px;
    w->tf_weight = weight;
    w->tf_italic = italic ? 1 : 0;
}

/* 兼容旧形态：px 逻辑像素，bold 非 0 → 700 */
void zfy_gui_font(int32_t px, int32_t bold) {
    zfy_gui_font_ex(NULL, px, bold ? 700 : 400, 0);
}

void zfy_gui_draw_text(int32_t tx, int32_t ty, char *utf8, uint32_t argb) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    ID2D1SolidColorBrush *br = gui_brush(w, argb);
    if (fmt && br) {
        IDWriteTextLayout *lay = gui_make_layout(w, wt, (int)wcslen(wt), fmt);
        if (lay) {
            D2D1_POINT_2F po;
            po.x = (float)tx; po.y = (float)ty;
            RT_V(w->ctx, DrawTextLayout, po, lay, (ID2D1Brush *)br, D2D1_DRAW_TEXT_OPTIONS_NONE);
            REL(lay);
        }
    }
    free(wt);
}

/* UTF-8 字节偏移 → UTF-16 码元下标（富文本 run 换算用） */
static int gui_u8_to_u16(const char *s, int off) {
    int i = 0, n = 0;
    while (i < off && s[i]) {
        unsigned char c = (unsigned char)s[i];
        int step;
        if (c < 0x80) step = 1;
        else if ((c & 0xE0) == 0xC0) step = 2;
        else if ((c & 0xF0) == 0xE0) step = 3;
        else if ((c & 0xF8) == 0xF0) step = 4;
        else step = 1;
        i += step;
        n++;
    }
    return n;
}

/* 富文本：runs 每段 6 个 i64 = {起始字节偏移, 字节长度, 0xAARRGGBB,
   字重(0=用当前默认), 斜体(0/1), 字号偏移(逻辑 px，可负)}；未覆盖部分白色 */
void zfy_gui_draw_text_rich(int32_t tx, int32_t ty, char *utf8,
                            int64_t *runs, int32_t runs_len) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    int wlen = (int)wcslen(wt);
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    if (!fmt || wlen <= 0) { free(wt); return; }
    IDWriteTextLayout *lay = gui_make_layout(w, wt, wlen, fmt);
    if (!lay) { free(wt); return; }
    for (int i = 0; i < runs_len; i++) {
        int64_t *r = runs + i * 6;
        int start = gui_u8_to_u16(utf8 ? utf8 : "", (int)r[0]);
        int len = gui_u8_to_u16(utf8 ? utf8 : "", (int)(r[0] + r[1])) - start;
        if (start < 0) start = 0;
        if (start >= wlen || len <= 0) continue;
        if (start + len > wlen) len = wlen - start;
        DWRITE_TEXT_RANGE range;
        range.startPosition = (UINT32)start;
        range.length = (UINT32)len;
        if (r[3] >= 100 && r[3] <= 950)
            IDWriteTextLayout_SetFontWeight(lay, (DWRITE_FONT_WEIGHT)r[3], range);
        if (r[4])
            IDWriteTextLayout_SetFontStyle(lay, DWRITE_FONT_STYLE_ITALIC, range);
        if (r[5] != 0) {
            float base = (float)(w->tf_px * w->dpi / 96);
            float sz = base + (float)(r[5] * w->dpi / 96);
            if (sz < 1.0f) sz = 1.0f;
            IDWriteTextLayout_SetFontSize(lay, sz, range);
        }
        ID2D1SolidColorBrush *br = gui_brush(w, (uint32_t)r[2]);
        if (br) IDWriteTextLayout_SetDrawingEffect(lay, (IUnknown *)br, range);
    }
    ID2D1SolidColorBrush *fallback = gui_brush(w, 0xFFFFFFFF);
    if (fallback) {
        D2D1_POINT_2F po;
        po.x = (float)tx; po.y = (float)ty;
        RT_V(w->ctx, DrawTextLayout, po, lay, (ID2D1Brush *)fallback, D2D1_DRAW_TEXT_OPTIONS_NONE);
    }
    REL(lay);
    free(wt);
}

/* 文本像素宽度（DirectWrite 度量，物理像素；无窗口时 0） */
int32_t zfy_gui_text_w(char *utf8) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return 0;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    IDWriteTextLayout *lay = fmt ? gui_make_layout(w, wt, (int)wcslen(wt), fmt) : NULL;
    int32_t v = 0;
    if (lay) {
        DWRITE_TEXT_METRICS tm;
        if (SUCCEEDED(IDWriteTextLayout_GetMetrics(lay, &tm)))
            v = (int32_t)(tm.widthIncludingTrailingWhitespace + 0.999f);
        REL(lay);
    }
    free(wt);
    return v;
}

/* 文本像素高度（行高，物理像素） */
int32_t zfy_gui_text_h(char *utf8) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return 0;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    IDWriteTextLayout *lay = fmt ? gui_make_layout(w, wt, (int)wcslen(wt), fmt) : NULL;
    int32_t v = 0;
    if (lay) {
        DWRITE_TEXT_METRICS tm;
        if (SUCCEEDED(IDWriteTextLayout_GetMetrics(lay, &tm)))
            v = (int32_t)(tm.height + 0.999f);
        REL(lay);
    }
    free(wt);
    return v;
}

/* 文本度量四元组：宽/高/基线以上/基线以下（物理像素） */
void zfy_gui_text_metrics(char *utf8, int32_t *pw, int32_t *ph, int32_t *pa, int32_t *pd) {
    if (pw) *pw = 0;
    if (ph) *ph = 0;
    if (pa) *pa = 0;
    if (pd) *pd = 0;
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    wchar_t *wt = gui_utf8_to_wide(utf8 ? utf8 : "");
    IDWriteTextFormat *fmt = gui_text_format(w, w->tf_family, w->tf_px, w->tf_weight, w->tf_italic);
    IDWriteTextLayout *lay = fmt ? gui_make_layout(w, wt, (int)wcslen(wt), fmt) : NULL;
    if (lay) {
        DWRITE_TEXT_METRICS tm;
        DWRITE_LINE_METRICS lm[4];
        UINT32 got = 0;
        if (SUCCEEDED(IDWriteTextLayout_GetMetrics(lay, &tm)) && pw) {
            *pw = (int32_t)(tm.widthIncludingTrailingWhitespace + 0.999f);
            if (ph) *ph = (int32_t)(tm.height + 0.999f);
        }
        if (SUCCEEDED(IDWriteTextLayout_GetLineMetrics(lay, lm, 4, &got)) && got > 0) {
            if (pa) *pa = (int32_t)(lm[0].ascent + 0.999f);
            if (pd) *pd = (int32_t)(lm[0].descent + 0.999f);
        }
        REL(lay);
    }
    free(wt);
}

/* ---------- 透明度 / 混合模式 ---------- */
void zfy_gui_set_alpha(int32_t alpha) {
    if (!g_cur) return;
    if (alpha < 0) alpha = 0;
    if (alpha > 255) alpha = 255;
    g_cur->alpha = alpha;
    gui_br_flush(g_cur);               /* 画刷键含有效 alpha，需整体失效 */
}
void zfy_gui_reset_alpha(void) {
    if (!g_cur) return;
    g_cur->alpha = 255;
    gui_br_flush(g_cur);
}
void zfy_gui_set_blend(int32_t mode) {
    if (!g_cur) return;
    if (mode < 0 || mode > 4) mode = 0;
    g_cur->blend = mode;
}

/* ---------- 裁剪 / 变换 ---------- */
void zfy_gui_push_clip(int32_t x, int32_t y, int32_t w, int32_t h) {
    gui_win *w = g_cur;
    if (!w || !w->ctx) return;
    if (w->clip_n >= GUI_CLIP_STACK - 1) return;
    D2D1_RECT_F r;
    r.left = (float)x; r.top = (float)y;
    r.right = (float)(x + w); r.bottom = (float)(y + h);
    if (r.right < r.left) { float t = r.left; r.left = r.right; r.right = t; }
    if (r.bottom < r.top) { float t = r.top; r.top = r.bottom; r.bottom = t; }
    RT_V(w->ctx, PushAxisAlignedClip, &r, D2D1_ANTIALIAS_MODE_ALIASED);
    w->clip_n++;
}
void zfy_gui_pop_clip(void) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || w->clip_n <= 0) return;
    RT_V(w->ctx, PopAxisAlignedClip);
    w->clip_n--;
}
void zfy_gui_push_translate(int32_t dx, int32_t dy) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || w->xf_n >= GUI_XF_STACK - 1) return;
    /* 读回当前变换，压栈后左乘平移 */
    D2D1_MATRIX_3X2_F cur;
    RT_V(w->ctx, GetTransform, &cur);
    w->xf[w->xf_n] = cur;
    w->xf_n++;
    cur._31 += (float)dx;
    cur._32 += (float)dy;
    RT_V(w->ctx, SetTransform, &cur);
}
void zfy_gui_pop_transform(void) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || w->xf_n <= 0) return;
    w->xf_n--;
    RT_V(w->ctx, SetTransform, &w->xf[w->xf_n]);
}

/* ---------- 位图（WIC 加载 / 内存构建） ---------- */
static int64_t gui_img_alloc(ID2D1Bitmap1 *bmp, int w, int h) {
    for (int i = 0; i < GUI_IMG_SLOTS; i++) {
        if (!g_imgs[i].used) {
            g_imgs[i].bmp = bmp;
            g_imgs[i].w = w;
            g_imgs[i].h = h;
            g_imgs[i].used = 1;
            return (int64_t)(i + 1);
        }
    }
    return 0;
}
static gui_img *gui_img_of(int64_t h) {
    if (h < 1 || h > GUI_IMG_SLOTS) return NULL;
    gui_img *g = &g_imgs[h - 1];
    return g->used ? g : NULL;
}

/* 加载 PNG/JPG/BMP/GIF（首帧）→ 32bppPBGRA 位图；返回句柄 >0，失败 0 */
int64_t zfy_gui_image_load(char *path_utf8) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || !g_wic || !path_utf8) return 0;
    wchar_t *wp = gui_utf8_to_wide(path_utf8);
    IWICBitmapDecoder *dec = NULL;
    IWICBitmapFrameDecode *fr = NULL;
    IWICFormatConverter *conv = NULL;
    ID2D1Bitmap1 *bmp = NULL;
    HRESULT hr = IWICImagingFactory_CreateDecoderFromFilename(g_wic, wp, NULL, GENERIC_READ,
                                                              WICDecodeMetadataCacheOnDemand, &dec);
    if (SUCCEEDED(hr) && dec) hr = IWICBitmapDecoder_GetFrame(dec, 0, &fr);
    if (SUCCEEDED(hr) && fr && g_wic) {
        hr = IWICImagingFactory_CreateFormatConverter(g_wic, &conv);
        if (SUCCEEDED(hr) && conv)
            hr = IWICFormatConverter_Initialize(conv, (IWICBitmapSource *)fr,
                                                &GUID_WICPixelFormat32bppPBGRA,
                                                WICBitmapDitherTypeNone, NULL, 0.0,
                                                WICBitmapPaletteTypeCustom);
    }
    if (SUCCEEDED(hr) && conv)
        hr = DC_V(w->ctx, CreateBitmapFromWicBitmap, (IWICBitmapSource *)conv, NULL, &bmp);
    int iw = 0, ih = 0;
    if (bmp) {
        D2D1_SIZE_U ps = BM_V(bmp, GetPixelSize);
        iw = (int)ps.width; ih = (int)ps.height;
    }
    REL(conv);
    REL(fr);
    REL(dec);
    free(wp);
    if (!bmp) return 0;
    int64_t h = gui_img_alloc(bmp, iw, ih);
    if (h == 0) REL(bmp);
    return h;
}

int32_t zfy_gui_image_w(int64_t h) {
    gui_img *g = gui_img_of(h);
    return g ? g->w : 0;
}
int32_t zfy_gui_image_h(int64_t h) {
    gui_img *g = gui_img_of(h);
    return g ? g->h : 0;
}

void zfy_gui_image_free(int64_t h) {
    gui_img *g = gui_img_of(h);
    if (!g) return;
    REL(g->bmp);
    memset(g, 0, sizeof(*g));
}

/* 缩放绘制：alpha 0..255 叠加在全局 alpha 之上 */
void zfy_gui_draw_image(int64_t h, int32_t x, int32_t y, int32_t dw, int32_t dh, int32_t alpha) {
    gui_win *w = g_cur;
    gui_img *g = gui_img_of(h);
    if (!w || !w->ctx || !g) return;
    if (dw <= 0 || dh <= 0) return;
    if (alpha < 0) alpha = 0;
    if (alpha > 255) alpha = 255;
    float op = (float)alpha / 255.0f * (float)w->alpha / 255.0f;
    D2D1_RECT_F dest;
    dest.left = (float)x; dest.top = (float)y;
    dest.right = (float)(x + dw); dest.bottom = (float)(y + dh);
    RT_V(w->ctx, DrawBitmap, (ID2D1Bitmap *)g->bmp, &dest, op,
          D2D1_BITMAP_INTERPOLATION_MODE_LINEAR, NULL);
}

/* 子区域绘制（精灵表/九宫格） */
void zfy_gui_draw_image_sub(int64_t h, int32_t sx, int32_t sy, int32_t sw, int32_t sh,
                            int32_t dx, int32_t dy, int32_t dw, int32_t dh, int32_t alpha) {
    gui_win *w = g_cur;
    gui_img *g = gui_img_of(h);
    if (!w || !w->ctx || !g) return;
    if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) return;
    if (alpha < 0) alpha = 0;
    if (alpha > 255) alpha = 255;
    float op = (float)alpha / 255.0f * (float)w->alpha / 255.0f;
    D2D1_RECT_F dest;
    dest.left = (float)dx; dest.top = (float)dy;
    dest.right = (float)(dx + dw); dest.bottom = (float)(dy + dh);
    D2D1_RECT_F src;
    src.left = (float)sx; src.top = (float)sy;
    src.right = (float)(sx + sw); src.bottom = (float)(sy + sh);
    RT_V(w->ctx, DrawBitmap, (ID2D1Bitmap *)g->bmp, &dest, op,
          D2D1_BITMAP_INTERPOLATION_MODE_LINEAR, &src);
}

/* 从内存 RGBA 缓冲（非预乘，4 字节/像素）构建位图 */
int64_t zfy_gui_image_from_rgba(void *px, int32_t wpx, int32_t hpx, int32_t stride) {
    gui_win *w = g_cur;
    if (!w || !w->ctx || !px || wpx <= 0 || hpx <= 0) return 0;
    if (stride <= 0) stride = wpx * 4;
    unsigned char *bg = (unsigned char *)malloc((size_t)wpx * (size_t)hpx * 4);
    if (!bg) return 0;
    const unsigned char *src = (const unsigned char *)px;
    for (int y = 0; y < hpx; y++) {
        const unsigned char *s = src + (size_t)y * (size_t)stride;
        unsigned char *d = bg + (size_t)y * (size_t)wpx * 4;
        for (int x = 0; x < wpx; x++) {
            unsigned char a = s[x * 4 + 3];
            /* RGBA(非预乘) → BGRA(预乘)：alpha 乘入各通道 */
            unsigned int pr = (unsigned int)s[x * 4 + 0] * a / 255u;
            unsigned int pg = (unsigned int)s[x * 4 + 1] * a / 255u;
            unsigned int pb = (unsigned int)s[x * 4 + 2] * a / 255u;
            d[x * 4 + 0] = (unsigned char)pb;
            d[x * 4 + 1] = (unsigned char)pg;
            d[x * 4 + 2] = (unsigned char)pr;
            d[x * 4 + 3] = a;
        }
    }
    D2D1_BITMAP_PROPERTIES1 bp;
    memset(&bp, 0, sizeof(bp));
    bp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    bp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    bp.dpiX = 96; bp.dpiY = 96;
    bp.bitmapOptions = D2D1_BITMAP_OPTIONS_NONE;
    D2D1_SIZE_U sz;
    sz.width = (UINT32)wpx; sz.height = (UINT32)hpx;
    ID2D1Bitmap1 *bmp = NULL;
    HRESULT hr = DC_V(w->ctx, CreateBitmap, sz, bg, (UINT32)(wpx * 4), &bp, &bmp);
    free(bg);
    if (FAILED(hr) || !bmp) return 0;
    int64_t h = gui_img_alloc(bmp, wpx, hpx);
    if (h == 0) REL(bmp);
    return h;
}

#else
/* 非 Windows：桩实现（返回失败，UI 程序可优雅降级为 TUI） */
int32_t zfy_gui_open(int32_t w, int32_t h, char *t) { (void)w; (void)h; (void)t; return -1; }
int32_t zfy_gui_poll(int64_t *t, int64_t *x, int64_t *y, int64_t *k) { (void)t; (void)x; (void)y; (void)k; return 0; }
int32_t zfy_gui_alive(void) { return 0; }
int32_t zfy_gui_should_close(void) { return 1; }
int32_t zfy_gui_w(void) { return 0; }
int32_t zfy_gui_h(void) { return 0; }
int32_t zfy_gui_dpi(void) { return 96; }
int32_t zfy_gui_clip_get(char *buf, int32_t cap) { (void)buf; (void)cap; return -1; }
void zfy_gui_clip_set(char *utf8) { (void)utf8; }
void zfy_gui_close(void) {}
void zfy_gui_title(char *s) { (void)s; }
void zfy_gui_font(int32_t a, int32_t b) { (void)a; (void)b; }
void zfy_gui_font_ex(char *f, int32_t p, int32_t w, int32_t i) { (void)f; (void)p; (void)w; (void)i; }
void zfy_gui_round_rect(int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, uint32_t f, uint32_t g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
void zfy_gui_line(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e, int32_t w) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)w; }
void zfy_gui_fill_grad(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e, uint32_t f, int32_t g) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; }
int32_t zfy_gui_alive_any(void) { return 0; }
int32_t zfy_gui_self(void) { return 0; }
void zfy_gui_select(int64_t id) { (void)id; }
void zfy_gui_set_icon(char *s) { (void)s; }
void zfy_gui_present(void) {}
void zfy_gui_fill_rect(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e) { (void)a; (void)b; (void)c; (void)d; (void)e; }
void zfy_gui_stroke_rect(int32_t a, int32_t b, int32_t c, int32_t d, uint32_t e, int32_t w) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)w; }
void zfy_gui_draw_text(int32_t a, int32_t b, char *s, uint32_t c) { (void)a; (void)b; (void)s; (void)c; }
void zfy_gui_draw_text_rich(int32_t a, int32_t b, char *s, int64_t *r, int32_t n) { (void)a; (void)b; (void)s; (void)r; (void)n; }
int32_t zfy_gui_text_w(char *s) { (void)s; return 0; }
int32_t zfy_gui_text_h(char *s) { (void)s; return 0; }
void zfy_gui_text_metrics(char *s, int32_t *w, int32_t *h, int32_t *a, int32_t *d) { (void)s; (void)h; (void)a; (void)d; if (w) *w = 0; }
void zfy_gui_fill_circle(int32_t cx, int32_t cy, int32_t r, uint32_t c) { (void)cx; (void)cy; (void)r; (void)c; }
void zfy_gui_stroke_circle(int32_t cx, int32_t cy, int32_t r, uint32_t c, int32_t w) { (void)cx; (void)cy; (void)r; (void)c; (void)w; }
void zfy_gui_arc(int32_t cx, int32_t cy, int32_t r, double a0, double a1, uint32_t c, int32_t w) { (void)cx; (void)cy; (void)r; (void)a0; (void)a1; (void)c; (void)w; }
void zfy_gui_fill_poly(int32_t *p, int32_t n, uint32_t c) { (void)p; (void)n; (void)c; }
void zfy_gui_stroke_poly(int32_t *p, int32_t n, uint32_t c, int32_t w) { (void)p; (void)n; (void)c; (void)w; }
void zfy_gui_bezier(int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, uint32_t g, int32_t h) { (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h; }
void zfy_gui_set_alpha(int32_t a) { (void)a; }
void zfy_gui_reset_alpha(void) {}
void zfy_gui_set_blend(int32_t m) { (void)m; }
void zfy_gui_push_clip(int32_t a, int32_t b, int32_t c, int32_t d) { (void)a; (void)b; (void)c; (void)d; }
void zfy_gui_pop_clip(void) {}
void zfy_gui_push_translate(int32_t a, int32_t b) { (void)a; (void)b; }
void zfy_gui_pop_transform(void) {}
int64_t zfy_gui_image_load(char *p) { (void)p; return 0; }
int32_t zfy_gui_image_w(int64_t h) { (void)h; return 0; }
int32_t zfy_gui_image_h(int64_t h) { (void)h; return 0; }
void zfy_gui_draw_image(int64_t h, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e) { (void)h; (void)a; (void)b; (void)c; (void)d; (void)e; }
void zfy_gui_draw_image_sub(int64_t h, int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, int32_t g, int32_t i, int32_t j) { (void)h; (void)a; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)i; (void)j; }
void zfy_gui_image_free(int64_t h) { (void)h; }
int64_t zfy_gui_image_from_rgba(void *p, int32_t w, int32_t h, int32_t s) { (void)p; (void)w; (void)h; (void)s; return 0; }
#endif
