/* D2D 管线探针 v2：验证 D2D+DWrite+WIC+DXGI 交换链、加法混合、CPU 回读合成 */
#define CINTERFACE
#define COBJMACROS
#include <windows.h>
#include <d2d1_1.h>
#include <d2d1effects.h>
#include <d3d11.h>
#include <dxgi1_3.h>
#include <dwrite.h>
#include <wincodec.h>
#include <stdio.h>
#include <string.h>

/* ---- 方法调用宏（d2d1 vtbl 有继承嵌套，逐层写死） ---- */
#define RT(c)          ((ID2D1RenderTarget *)(c))
#define RT_V(c, fn, ...) (RT(c)->lpVtbl->fn(RT(c), ##__VA_ARGS__))
#define DC_V(c, fn, ...) ((c)->lpVtbl->fn(c, ##__VA_ARGS__))
#define F1_V(f, fn, ...) ((f)->lpVtbl->fn((ID2D1Factory *)(f), ##__VA_ARGS__))
#define GEO_V(g, fn, ...) ((g)->lpVtbl->Base.fn(g, ##__VA_ARGS__))
#define PG_V(g, fn, ...) ((g)->lpVtbl->fn(g, ##__VA_ARGS__))
#define SINK_V(s, fn, ...) ((s)->lpVtbl->Base.fn(s, ##__VA_ARGS__))
#define SINK_C(s) ((s)->lpVtbl->Close(s))
#define SB_V(b, fn, ...) ((b)->lpVtbl->fn((ID2D1SolidColorBrush *)(b), ##__VA_ARGS__))
#define BR_V(b, fn, ...) ((b)->lpVtbl->Base.fn((ID2D1Brush *)(b), ##__VA_ARGS__))
#define BM_V(b, fn, ...) ((b)->lpVtbl->Base.fn((ID2D1Bitmap *)(b), ##__VA_ARGS__))
#define BM1_V(b, fn, ...) ((b)->lpVtbl->fn((ID2D1Bitmap1 *)(b), ##__VA_ARGS__))
#define REL(o) do { if (o) ((IUnknown *)(void *)(o))->lpVtbl->Release((IUnknown *)(void *)(o)); } while (0)

static const GUID LocalIID_IDWriteFactory = { 0xb859ee5a,0xd838,0x4b5b,{0xa2,0xe8,0x1a,0xdc,0x7d,0x93,0xdb,0x48} };
static ID2D1Factory1 *fct;
static IDWriteFactory *dw;
static IWICImagingFactory *wic;
static ID2D1Device *dev;
static ID3D11Device *d3d;
static IDXGIFactory2 *dxgi;

static LRESULT CALLBACK proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (m == WM_DESTROY) PostQuitMessage(0);
    return DefWindowProcW(h, m, w, l);
}

int main(void) {
    SetProcessDPIAware();
    HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    printf("CoInitializeEx=0x%08lx\n", (unsigned long)hr);
    hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &IID_ID2D1Factory1, NULL, (void **)&fct);
    printf("d2d factory=0x%08lx\n", (unsigned long)hr);
    hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, &LocalIID_IDWriteFactory, (IUnknown **)&dw);
    printf("dwrite=0x%08lx\n", (unsigned long)hr);
    hr = CoCreateInstance(&CLSID_WICImagingFactory, NULL, CLSCTX_INPROC_SERVER, &IID_IWICImagingFactory, (void **)&wic);
    printf("wic=0x%08lx\n", (unsigned long)hr);
    D3D_FEATURE_LEVEL fl = 0;
    static const D3D_FEATURE_LEVEL lv[] = { D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1 };
    hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, D3D11_CREATE_DEVICE_BGRA_SUPPORT, lv, 3, D3D11_SDK_VERSION, &d3d, &fl, NULL);
    printf("d3d hardware=0x%08lx\n", (unsigned long)hr);
    if (FAILED(hr)) hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_WARP, NULL, D3D11_CREATE_DEVICE_BGRA_SUPPORT, lv, 3, D3D11_SDK_VERSION, &d3d, &fl, NULL);
    printf("d3d final=0x%08lx level=0x%x\n", (unsigned long)hr, (unsigned)fl);
    IDXGIDevice *dxdev = NULL;
    ID3D11Device_QueryInterface(d3d, &IID_IDXGIDevice, (void **)&dxdev);
    hr = fct->lpVtbl->CreateDevice(fct, dxdev, &dev);
    printf("d2d device=0x%08lx\n", (unsigned long)hr);
    IDXGIAdapter *ad = NULL;
    IDXGIDevice_GetAdapter(dxdev, &ad);
    IDXGIAdapter_GetParent(ad, &IID_IDXGIFactory2, (void **)&dxgi);

    WNDCLASSW wc; memset(&wc, 0, sizeof wc);
    wc.lpfnWndProc = proc; wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW); wc.lpszClassName = L"ProbeD2D";
    RegisterClassW(&wc);
    HWND hwnd = CreateWindowW(L"ProbeD2D", L"probe", WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 400, 300, NULL, NULL, GetModuleHandleW(NULL), NULL);
    ShowWindow(hwnd, SW_SHOW);

    DXGI_SWAP_CHAIN_DESC1 d; memset(&d, 0, sizeof d);
    d.Width = 400; d.Height = 300; d.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    d.SampleDesc.Count = 1; d.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    d.BufferCount = 2; d.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL; d.AlphaMode = DXGI_ALPHA_MODE_IGNORE;
    IDXGISwapChain1 *swap = NULL;
    hr = IDXGIFactory2_CreateSwapChainForHwnd(dxgi, (IUnknown *)d3d, hwnd, &d, NULL, NULL, &swap);
    printf("swapchain=0x%08lx\n", (unsigned long)hr);
    ID2D1DeviceContext *ctx = NULL;
    hr = dev->lpVtbl->CreateDeviceContext(dev, D2D1_DEVICE_CONTEXT_OPTIONS_NONE, &ctx);
    printf("ctx=0x%08lx\n", (unsigned long)hr);
    IDXGISurface *surf = NULL;
    IDXGISwapChain1_GetBuffer(swap, 0, &IID_IDXGISurface, (void **)&surf);
    D2D1_BITMAP_PROPERTIES1 bp; memset(&bp, 0, sizeof bp);
    bp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    bp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    bp.dpiX = 96; bp.dpiY = 96;
    bp.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
    ID2D1Bitmap1 *target = NULL;
    hr = DC_V(ctx, CreateBitmapFromDxgiSurface, surf, &bp, &target);
    printf("target=0x%08lx\n", (unsigned long)hr);
    DC_V(ctx, SetTarget, (ID2D1Image *)target);
    RT_V(ctx, SetDpi, 96, 96);
    RT_V(ctx, SetAntialiasMode, D2D1_ANTIALIAS_MODE_PER_PRIMITIVE);
    RT_V(ctx, SetTextAntialiasMode, D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);

    D2D1_COLOR_F c = { 0.12f, 0.12f, 0.16f, 1.0f };
    ID2D1SolidColorBrush *br = NULL;
    hr = RT_V(ctx, CreateSolidColorBrush, &c, NULL, &br);
    printf("brush=0x%08lx\n", (unsigned long)hr);
    D2D1_COLOR_F c2 = { 0.3f, 0.76f, 1.0f, 1.0f };
    ID2D1SolidColorBrush *br2 = NULL;
    RT_V(ctx, CreateSolidColorBrush, &c2, NULL, &br2);

    IDWriteTextFormat *tf = NULL;
    hr = IDWriteFactory_CreateTextFormat(dw, L"Microsoft YaHei UI", NULL, DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, 16, L"zh-cn", &tf);
    printf("textformat=0x%08lx\n", (unsigned long)hr);
    IDWriteTextLayout *lay = NULL;
    hr = IDWriteFactory_CreateTextLayout(dw, L"你好 zfy D2D", 12, tf, 1000, 1000, &lay);
    printf("layout=0x%08lx\n", (unsigned long)hr);
    DWRITE_TEXT_METRICS tm;
    hr = IDWriteTextLayout_GetMetrics(lay, &tm);
    printf("metrics=0x%08lx w=%.1f h=%.1f\n", (unsigned long)hr, (double)tm.width, (double)tm.height);
    IDWriteTextLayout_SetWordWrapping(lay, DWRITE_WORD_WRAPPING_NO_WRAP);

    RT_V(ctx, Clear, NULL);
    D2D1_RECT_F r0 = { 0, 0, 400, 300 };
    RT_V(ctx, FillRectangle, &r0, (ID2D1Brush *)br);
    D2D1_ELLIPSE el = { { 100, 100 }, 50, 50 };
    RT_V(ctx, FillEllipse, &el, (ID2D1Brush *)br2);
    D2D1_POINT_2F po = { 20, 20 };
    RT_V(ctx, DrawTextLayout, po, lay, (ID2D1Brush *)br2, D2D1_DRAW_TEXT_OPTIONS_NONE);

    /* 加法混合 */
    DC_V(ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_ADD);
    D2D1_ELLIPSE el2 = { { 160, 100 }, 50, 50 };
    RT_V(ctx, FillEllipse, &el2, (ID2D1Brush *)br2);
    DC_V(ctx, SetPrimitiveBlend, D2D1_PRIMITIVE_BLEND_SOURCE_OVER);

    /* 内存位图 */
    unsigned char px[16 * 16 * 4];
    for (int i = 0; i < 16 * 16; i++) { px[i*4+0]=0; px[i*4+1]=128; px[i*4+2]=255; px[i*4+3]=255; }
    D2D1_BITMAP_PROPERTIES1 pp = bp;
    pp.bitmapOptions = D2D1_BITMAP_OPTIONS_NONE;
    ID2D1Bitmap1 *ib = NULL;
    D2D1_SIZE_U sz = { 16, 16 };
    hr = DC_V(ctx, CreateBitmap, sz, px, 64, &pp, &ib);
    printf("mem bitmap=0x%08lx\n", (unsigned long)hr);
    if (SUCCEEDED(hr)) { D2D1_RECT_F ir = { 300, 200, 340, 240 }; RT_V(ctx, DrawBitmap, (ID2D1Bitmap *)ib, &ir, 1.0f, D2D1_BITMAP_INTERPOLATION_MODE_LINEAR, NULL); }

    /* CPU 回读合成探针：源位图 + 目的回读 + Map */
    D2D1_BITMAP_PROPERTIES1 tp = bp;
    tp.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET;
    ID2D1Bitmap1 *tmpT = NULL, *readS = NULL, *readD = NULL;
    D2D1_SIZE_U qs = { 64, 64 };
    hr = DC_V(ctx, CreateBitmap, qs, NULL, 0, &tp, &tmpT);
    printf("tmp target=0x%08lx\n", (unsigned long)hr);
    D2D1_BITMAP_PROPERTIES1 cp = bp;
    cp.bitmapOptions = D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
    hr = DC_V(ctx, CreateBitmap, qs, NULL, 0, &cp, &readS);
    printf("cpu read S=0x%08lx\n", (unsigned long)hr);
    hr = DC_V(ctx, CreateBitmap, qs, NULL, 0, &cp, &readD);
    printf("cpu read D=0x%08lx\n", (unsigned long)hr);
    if (SUCCEEDED(hr)) {
        DC_V(ctx, SetTarget, (ID2D1Image *)tmpT);
        RT_V(ctx, Clear, NULL);
        D2D1_RECT_F rr = { 0, 0, 64, 64 };
        RT_V(ctx, FillRectangle, &rr, (ID2D1Brush *)br2);
        DC_V(ctx, SetTarget, (ID2D1Image *)NULL);
        RT_V(ctx, Flush, NULL, NULL);
        D2D1_POINT_2U dp = { 0, 0 };
        D2D1_RECT_U sr = { 0, 0, 64, 64 };
        hr = BM_V(readS, CopyFromBitmap, &dp, tmpT, &sr);
        printf("copy S<-T =0x%08lx\n", (unsigned long)hr);
        D2D1_MAPPED_RECT mr;
        hr = BM1_V(readS, Map, D2D1_MAP_OPTIONS_READ, &mr);
        printf("map S =0x%08lx pitch=%lu px0=%02x%02x%02x%02x\n", (unsigned long)hr, (unsigned long)(SUCCEEDED(hr) ? mr.pitch : 0), 0, 0, 0, 0);
        if (SUCCEEDED(hr)) { printf("  sample=%08x\n", *(unsigned int *)mr.bits); BM1_V(readS, Unmap); }
        DC_V(ctx, SetTarget, (ID2D1Image *)NULL);
        hr = BM_V(readD, CopyFromBitmap, &dp, target, &sr);
        printf("copy D<-target =0x%08lx\n", (unsigned long)hr);
        DC_V(ctx, SetTarget, (ID2D1Image *)target);
    }

    RT_V(ctx, Flush, NULL, NULL);
    hr = IDXGISwapChain1_Present(swap, 1, 0);
    printf("Present=0x%08lx\n", (unsigned long)hr);
    for (int i = 0; i < 10; i++) { MSG m; while (PeekMessageW(&m, NULL, 0, 0, PM_REMOVE)) { TranslateMessage(&m); DispatchMessageW(&m); } Sleep(50); }
    printf("PROBE OK\n");
    return 0;
}
