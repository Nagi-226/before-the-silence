# -*- coding: utf-8 -*-
"""
gen_gate_open.py — 「静默之前」货运大门·开启态贴图生成器（可复现, A批6 合闸机制）
产物: godot/assets/images/Gate Cargo Open.bmp  (128x64, 4m x 2.6m, 32px/m)
设计: 与 gen_gate.py 同门框/导轨/色板; 卷帘升起(顶部帘箱+底部残余帘板),
      门洞漆黑(室内未通电/夜色), 底部一线微光(庭院地灯渗入), 状态灯转绿。
"""
import random
from PIL import Image

random.seed(20260830)

W, H = 128, 64
ROOT = r"E:\Github Project\Nagi_Games\before-the-silence"

FRAME    = (36, 44, 48)
FRAME_HI = (62, 74, 79)
BASE     = (76, 90, 96)
HI       = (104, 118, 122)
LO       = (54, 66, 71)
SEAM     = (28, 35, 39)
VOID     = (6, 7, 9)         # 门洞漆黑
VOID_LO  = (14, 17, 20)      # 洞底微光带
GLOW     = (30, 36, 40)      # 底部微光
RUST     = [(108, 76, 42), (130, 88, 46), (92, 62, 36)]
GREEN    = (60, 200, 80)     # 已通电状态灯


def adj(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)


img = Image.new("RGB", (W, H), FRAME)
px = img.load()

TOP, BOT = 3, 59
RAIL = 4
SLAT_H = 7
# 卷帘升起: 帘板只剩顶部帘箱(2 板) + 最底 1 板悬垂, 中间为门洞
SHUTTER_BOTTOM = TOP + SLAT_H * 2   # 帘箱下缘
DRIP_TOP = BOT - SLAT_H             # 悬垂残余帘板上缘

seam_rows = []

def slat_row(y0, h):
    j = random.randint(-5, 5)
    for i in range(h):
        yy = y0 + i
        if i == 0:
            c = adj(HI, j)
        elif i == h - 1:
            c = SEAM
            seam_rows.append(yy)
        elif i == h - 2:
            c = adj(LO, j)
        else:
            c = adj(BASE, j)
        for x in range(RAIL, W - RAIL):
            px[x, yy] = c

# ---- 1) 升起的帘板(顶部帘箱) ----
slat_row(TOP, SLAT_H)
slat_row(TOP + SLAT_H, SLAT_H)
# 帘箱下缘加厚(卷起的帘体)
for yy in range(SHUTTER_BOTTOM, SHUTTER_BOTTOM + 2):
    for x in range(RAIL, W - RAIL):
        px[x, yy] = adj(LO, -10)
# ---- 2) 悬垂残余帘板(帘未完全收进箱) ----
slat_row(DRIP_TOP, SLAT_H)

# ---- 3) 门洞: 漆黑 + 底部微光 ----
for yy in range(SHUTTER_BOTTOM + 2, DRIP_TOP):
    for x in range(RAIL, W - RAIL):
        px[x, yy] = VOID
# 洞内偶发极暗噪点(夜色纵深)
for _ in range(60):
    x = random.randint(RAIL + 2, W - RAIL - 3)
    y = random.randint(SHUTTER_BOTTOM + 4, DRIP_TOP - 4)
    px[x, y] = adj(VOID, random.randint(2, 7))
# 底部微光带(庭院方向地灯渗入)
for yy in range(DRIP_TOP - 3, DRIP_TOP):
    for x in range(RAIL, W - RAIL):
        px[x, yy] = VOID_LO if yy < DRIP_TOP - 1 else GLOW

# ---- 4) 两侧导轨 + 顶楣(与关门版一致) ----
for yy in range(H):
    for x in range(RAIL):
        px[x, yy] = FRAME
    for x in range(W - RAIL, W):
        px[x, yy] = FRAME
    if yy < TOP:
        for x in range(W):
            px[x, yy] = FRAME
for yy in range(TOP, BOT):
    px[RAIL - 1, yy] = adj(FRAME_HI, -12)
    px[W - RAIL, yy] = adj(FRAME_HI, -12)
for rx in range(1, W - 1, 10):
    px[rx, 1] = FRAME_HI
for ry in range(6, H - 6, 9):
    px[1, ry] = FRAME_HI
    px[W - 2, ry] = FRAME_HI
for x in range(W):
    px[x, TOP - 1] = FRAME_HI
# 导轨底端(门洞两侧)
for yy in range(BOT, H):
    for x in range(RAIL):
        px[x, yy] = adj(FRAME, -8)
        px[W - 1 - x, yy] = adj(FRAME, -8)
# 帘底之下: 门洞地面延伸(漆黑), 最底一线微光(庭院地灯自帘底缝渗入)
for yy in range(BOT, H):
    for x in range(RAIL, W - RAIL):
        px[x, yy] = GLOW if yy >= H - 2 else VOID

# ---- 5) 锈迹与划痕(收敛于帘板/导轨) ----
for _ in range(70):
    if random.random() < 0.6 and seam_rows:
        yy = random.choice(seam_rows) + random.randint(-1, 1)
        xx = random.randint(RAIL, W - RAIL - 1)
    else:
        xx = random.choice([random.randint(0, RAIL - 2), random.randint(W - RAIL + 1, W - 2)])
        yy = random.randint(TOP, H - 4)
    if 0 <= yy < H and 0 <= xx < W:
        c = random.choice(RUST)
        px[xx, yy] = c
        if random.random() < 0.4 and yy + 1 < H:
            px[xx, yy + 1] = adj(c, -20)
for _ in range(4):
    yy = random.choice(seam_rows) if seam_rows else TOP + 2
    x0 = random.randint(RAIL + 2, W - RAIL - 12)
    for xx in range(x0, min(x0 + random.randint(4, 10), W - RAIL)):
        px[xx, yy] = adj(HI, 8)

# ---- 6) 状态灯(已通电绿, 顶楣右侧) ----
for dy in range(2):
    for dx in range(2):
        px[W - 12 + dx, 1 + dy] = GREEN

img.save(r"%s\godot\assets\images\Gate Cargo Open.bmp" % ROOT, "BMP")
img.resize((512, 256), Image.NEAREST).save(r"%s\assets-src\gate\preview_gate_open.png" % ROOT)
print("saved Gate Cargo Open.bmp")
