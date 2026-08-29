# -*- coding: utf-8 -*-
"""
gen_gate.py — 「静默之前」仓库货运大门贴图生成器（可复现）
产物: godot/assets/images/Gate Cargo.bmp  (128x64, 4m x 2.6m, 与墙贴图同像素密度 32px/m)
设计: 卷帘式货运大门(蓝灰钢, 对齐 Facade Panel 家族) + 底部警示条 + 锈迹;
      帘底未完全闭合, 留一条暗缝 —— 「提灯」由此潜入的叙事入口。
纯程序化绘制, 像素密度/色板与现有 64x64 墙贴图一致, 避免 AI 贴图风格漂移。
"""
import random
from PIL import Image

random.seed(20260829)

W, H = 128, 64
OUT_BMP = r"E:\Github Project\Nagi_Games\signal-lost\godot\assets\images\Gate Cargo.bmp"
OUT_PNG = r"C:\Users\FJL03\.qoderworkcn\workspace\msk0v4pu83273vku\gate_preview.png"

# ---- 色板 (与 Facade Panel / Wall Concrete 同族冷灰 + 锈色) ----
FRAME    = (36, 44, 48)     # 门框深钢
FRAME_HI = (62, 74, 79)     # 框高光/铆钉
BASE     = (76, 90, 96)     # 帘板蓝灰
HI       = (104, 118, 122)  # 帘板顶光
LO       = (54, 66, 71)     # 帘板底影
SEAM     = (28, 35, 39)     # 板缝
GAP      = (8, 9, 10)       # 帘底暗缝(门外微光)
GAP_EDGE = (20, 22, 24)     # 暗缝上缘
RUST     = [(108, 76, 42), (130, 88, 46), (92, 62, 36)]
HAZ_Y    = (156, 120, 46)   # 警示条(做旧黄)
HAZ_D    = (38, 36, 29)
ORANGE   = (216, 138, 44)   # EDAA 橙(状态灯)


def adj(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)


img = Image.new("RGB", (W, H), FRAME)
px = img.load()

TOP, BOT = 3, 59   # 帘板区 [TOP, BOT); BOT 之下为地面暗缝
RAIL = 4           # 两侧导轨宽
SLAT_H = 7

# ---- 1) 卷帘板条 (每板: 顶光/主体/底影/板缝, 逐板亮度抖动防呆板) ----
seam_rows = []
si, y = 0, TOP
while y < BOT:
    h = min(SLAT_H, BOT - y)
    j = random.randint(-5, 5)
    for i in range(h):
        yy = y + i
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
    y += h
    si += 1

# ---- 2) 底帘警示条 (斜纹做旧黄/黑) ----
hz0 = BOT - SLAT_H
for yy in range(hz0 + 1, BOT - 1):
    for x in range(RAIL, W - RAIL):
        px[x, yy] = HAZ_Y if ((x + yy) // 5) % 2 == 0 else HAZ_D

# ---- 3) 两侧导轨 + 顶楣 ----
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
# 铆钉
for rx in range(1, W - 1, 10):
    px[rx, 1] = FRAME_HI
for ry in range(6, H - 6, 9):
    px[1, ry] = FRAME_HI
    px[W - 2, ry] = FRAME_HI
# 顶楣下缘高光
for x in range(W):
    px[x, TOP - 1] = FRAME_HI

# ---- 4) 帘底暗缝 (门未关严, 渗透入口) ----
for yy in range(BOT, H):
    for x in range(RAIL, W - RAIL):
        px[x, yy] = GAP_EDGE if yy == BOT else GAP
# 缝内偶有微光斑点(外面庭院方向透入)
for _ in range(10):
    gx = random.randint(RAIL + 4, W - RAIL - 5)
    px[gx, random.randint(BOT + 1, H - 2)] = (26, 30, 34)

# ---- 5) 锈迹 (沿板缝/导轨/底部富集) + 划痕 ----
for _ in range(110):
    if random.random() < 0.6 and seam_rows:
        yy = random.choice(seam_rows) + random.randint(-1, 1)
    else:
        yy = random.randint(TOP, BOT - 1)
    yy = max(TOP, min(BOT - 1, yy))
    xx = random.randint(RAIL, W - RAIL - 1)
    c = random.choice(RUST)
    px[xx, yy] = c
    if random.random() < 0.5:
        px[min(W - RAIL - 1, xx + 1), yy] = adj(c, -14)
    if random.random() < 0.25 and yy + 1 < BOT:
        px[xx, yy + 1] = adj(c, -20)  # 锈垂流
# 导轨锈蚀
for _ in range(24):
    xx = random.choice([random.randint(0, RAIL - 2), random.randint(W - RAIL + 1, W - 2)])
    yy = random.randint(TOP, H - 4)
    px[xx, yy] = random.choice(RUST)
# 划痕
for _ in range(6):
    yy = random.randint(TOP + 1, BOT - 2)
    if yy in seam_rows:
        continue
    x0 = random.randint(RAIL + 2, W - RAIL - 12)
    ln = random.randint(4, 10)
    for xx in range(x0, min(x0 + ln, W - RAIL)):
        px[xx, yy] = adj(HI, 8)

# ---- 6) 状态灯 (EDAA 橙, 顶楣右侧) ----
for dy in range(2):
    for dx in range(2):
        px[W - 12 + dx, 1 + dy] = ORANGE

img.save(OUT_PNG)
img.save(OUT_BMP, "BMP")
print("saved", OUT_BMP)
print("saved", OUT_PNG)
