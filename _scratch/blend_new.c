static void gui_blend_composite(gui_win *w, ID2D1Geometry *geo, ID2D1Brush *br,
                                float sw, int bx, int by, int bw, int bh) {
    if (!gui_scr_ensure(w, bw, bh)) return;
    D2D1_MATRIX_3X2_F m;
    RT_V(w->ctx, GetTransform, &m);

    /* 1) 源：透明底上按"当前变换 + 平移(-bx,-by)"画图元，结果贴在位图左上角 */
    D2D1_MATRIX_3X2_F lm = m;
    lm._31 -= (float)bx;
    lm._32 -= (float)by;
    DC_V(w->ctx, SetTarget, (ID2D1Image *)w->scr_src);
    RT_V(w->ctx, Clear, NULL);
    RT_V(w->ctx, SetTransform, &lm);
    if (sw > 0.0f) RT_V(w->ctx, DrawGeometry, geo, br, sw, g_stroke_flat);
    else           RT_V(w->ctx, FillGeometry, geo, br, NULL);
    RT_V(w->ctx, Flush, NULL, NULL);
    DC_V(w->ctx, SetTarget, NULL);

    /* 2) 源区快照 → CPU 缓冲（scr_src 不再作目标后才允许回读） */
    D2D1_POINT_2U dp;
    dp.x = 0; dp.y = 0;
    D2D1_RECT_U sr;
    sr.left = 0; sr.top = 0;
    sr.right = (UINT32)bw; sr.bottom = (UINT32)bh;
    D2D1_MAPPED_RECT ms;
    memset(&ms, 0, sizeof(ms));
    int src_ok = 0;
    if (SUCCEEDED(BM_V(w->scr_dst, CopyFromBitmap, &dp, (ID2D1Bitmap *)w->scr_src, &sr))
        && SUCCEEDED(BM1_V(w->scr_dst, Map, D2D1_MAP_OPTIONS_READ, &ms))) {
        for (int y = 0; y < bh; y++) {
            const unsigned char *srow = (const unsigned char *)ms.bits + (size_t)y * ms.pitch;
            memcpy(w->scr_buf + (size_t)y * (size_t)(bw * 4), srow, (size_t)bw * 4);
        }
        BM1_V(w->scr_dst, Unmap);
        src_ok = 1;
    }

    /* 3) 目标区快照 → CPU 逐像素合成 → 写回 scr_buf → 上传 */
    if (src_ok && w->target) {
        D2D1_BITMAP_PROPERTIES1 cp;
        memset(&cp, 0, sizeof(cp));
        cp.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
        cp.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
        cp.dpiX = 96; cp.dpiY = 96;
        cp.bitmapOptions = D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW;
        D2D1_SIZE_U dsz;
        dsz.width = (UINT32)bw; dsz.height = (UINT32)bh;
        ID2D1Bitmap1 *dstSnap = NULL;
        if (SUCCEEDED(DC_V(w->ctx, CreateBitmap, dsz, NULL, 0, &cp, &dstSnap)) && dstSnap) {
            D2D1_RECT_U tr;
            tr.left = (UINT32)bx; tr.top = (UINT32)by;
            tr.right = (UINT32)(bx + bw); tr.bottom = (UINT32)(by + bh);
            D2D1_MAPPED_RECT md;
            memset(&md, 0, sizeof(md));
            if (SUCCEEDED(BM_V(dstSnap, CopyFromBitmap, &dp, (ID2D1Bitmap *)w->target, &tr))
                && SUCCEEDED(BM1_V(dstSnap, Map, D2D1_MAP_OPTIONS_READ, &md))) {
                int mode = w->blend;
                for (int y = 0; y < bh; y++) {
                    const unsigned char *srow = w->scr_buf + (size_t)y * (size_t)(bw * 4);
                    const unsigned char *drow = (const unsigned char *)md.bits + (size_t)y * md.pitch;
                    for (int x = 0; x < bw; x++) {
                        /* 预乘存储：通道 = 颜色 × alpha */
                        float as = (float)srow[x * 4 + 3] / 255.0f;
                        float ab = (float)drow[x * 4 + 3] / 255.0f;
                        if (as <= 0.0f) continue;
                        float ao = as + ab * (1.0f - as);
                        for (int ch = 0; ch < 3; ch++) {
                            float sp = (float)srow[x * 4 + ch] / 255.0f;   /* 源，预乘 */
                            float dpc = (float)drow[x * 4 + ch] / 255.0f;  /* 目标，预乘 */
                            float cs = sp / as;                            /* 源，去预乘 */
                            float cb = ab > 0.0f ? dpc / ab : 0.0f;        /* 目标，去预乘 */
                            float b;
                            if (mode == GUI_BLEND_MULTIPLY)      b = cs * cb;
                            else if (mode == GUI_BLEND_SCREEN)   b = 1.0f - (1.0f - cs) * (1.0f - cb);
                            else {                              /* XOR：按差值合成 */
                                b = cs > cb ? cs - cb : cb - cs;
                            }
                            /* 预乘通用式：co = sp*(1-ab) + as*ab*b + dpc*(1-as) */
                            float co = sp * (1.0f - ab) + as * ab * b + dpc * (1.0f - as);
                            if (co < 0.0f) co = 0.0f;
                            if (co > 1.0f) co = 1.0f;
                            srow[x * 4 + ch] = (unsigned char)(co * 255.0f + 0.5f);
                        }
                        srow[x * 4 + 3] = (unsigned char)(ao * 255.0f + 0.5f);
                    }
                }
                BM1_V(dstSnap, Unmap);
            }
            REL(dstSnap);
        }
    }

    /* 4) 上传结果并画回目标区（此处用设备坐标，绕开当前变换） */
    D2D1_RECT_U ur;
    ur.left = 0; ur.top = 0;
    ur.right = (UINT32)bw; ur.bottom = (UINT32)bh;
    if (src_ok && SUCCEEDED(BM_V(w->scr_up, CopyFromMemory, &ur, w->scr_buf, (UINT32)(bw * 4))) && w->target) {
        D2D1_MATRIX_3X2_F id;
        memset(&id, 0, sizeof(id));
        id._11 = 1.0f; id._22 = 1.0f;
        RT_V(w->ctx, SetTransform, &id);
        DC_V(w->ctx, SetTarget, (ID2D1Image *)w->target);
        D2D1_RECT_F dest;
        dest.left = (float)bx; dest.top = (float)by;
        dest.right = (float)(bx + bw); dest.bottom = (float)(by + bh);
        RT_V(w->ctx, DrawBitmap, (ID2D1Bitmap *)w->scr_up, &dest, 1.0f,
              D2D1_BITMAP_INTERPOLATION_MODE_NEAREST_NEIGHBOR, NULL);
    } else if (w->target) {
        DC_V(w->ctx, SetTarget, (ID2D1Image *)w->target);
    }
    RT_V(w->ctx, SetTransform, &m);
}
