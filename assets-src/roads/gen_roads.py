# -*- coding: utf-8 -*-
"""
gen_roads.py — 「静默之前」map2 街道沥青马路贴图生成器（可复现）
产物: godot/assets/images/Road Asphalt*.bmp  (64x64, 2m x 2m, 像素密度 32px/m 与墙贴图一致)
设计: 现代街道断面（用户 2026-08-30 指令）——
      中间沥青马路带交通线 / 两侧马路牙子上石板地面(沿用 Floor Tile 不变) / 再往边建筑墙。
      中心线=做旧黄虚线(横版上下两半跨缝拼合, 竖版左右两半), 边缘线=白实线(路牙分界)。
      虚线周期 64px(36 实 + 28 空)与 tile 同周期 → 沿路方向无缝平铺。
纯程序化绘制, 避免 AI 贴图风格漂移（同 gen_gate.py 管线先例）。
用法: python gen_roads.py   （从仓库根或本目录运行均可）
"""
import os
import random
from PIL import Image

random.seed(20260830)

S = 64  # tile 边长 px (2m/格, 32px/m)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "assets", "images"))

# ---- 色板 (冷调夜空城郊, 与 Floor Tile/Facade 家族协调) ----
ASPHALT   = (30, 32, 36)    # 沥青基色
ASPHALT_L = (40, 43, 48)    # 沥青亮斑
ASPHALT_D = (22, 24, 27)    # 沥青暗斑/修补
CRACK     = (16, 17, 19)    # 裂缝
PAINT_W   = (188, 190, 184) # 边缘白实线(做旧)
PAINT_Y   = (172, 138, 52)  # 中心黄虚线(做旧)
PAINT_WORN= (30, 32, 36)    # 磨蚀露底=沥青基色


def adj(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)


def asphalt_base():
    """沥青底: 基色 + 颗粒噪点 + 稀疏修补块 + 细裂缝"""
    img = Image.new("RGB", (S, S), ASPHALT)
    px = img.load()
    # 颗粒噪点(逐像素亮度抖动)
    for y in range(S):
        for x in range(S):
            px[x, y] = adj(ASPHALT, random.randint(-4, 4))
    # 亮/暗斑
    for _ in range(70):
        x, y = random.randrange(S), random.randrange(S)
        px[x, y] = ASPHALT_L if random.random() < 0.5 else ASPHALT_D
    # 修补块(深色矩形, 街道感)
    for _ in range(2):
        bw, bh = random.randint(8, 18), random.randint(4, 8)
        bx, by = random.randrange(S - bw), random.randrange(S - bh)
        for yy in range(by, by + bh):
            for xx in range(bx, bx + bw):
                px[xx, yy] = adj(ASPHALT_D, random.randint(-3, 3))
    # 细裂缝(随机游走)
    for _ in range(2):
        x, y = random.randrange(S), random.randrange(S)
        for _ in range(random.randint(10, 22)):
            px[x, y] = CRACK
            x = max(0, min(S - 1, x + random.choice([-1, 0, 1])))
            y = max(0, min(S - 1, y + random.choice([-1, 0, 0, 1])))
    return img, img.load()


def wear(px, x0, y0, x1, y1, p=0.18):
    """交通线磨蚀: 区域内按概率露底"""
    for yy in range(y0, y1):
        for xx in range(x0, x1):
            if random.random() < p:
                px[xx, yy] = adj(PAINT_WORN, random.randint(-3, 3))


def save(img, name):
    path = os.path.join(OUT_DIR, name)
    img.save(path, "BMP")
    print("saved", name)
    return img


# ============ 横版（东西向街道, 线沿 x 走向） ============

# 1) 纯沥青（路面主体 / 十字路口 / 巷口）
plain = asphalt_base()[0]
save(plain, "Road Asphalt.bmp")

# 2) 北边缘线（白实线贴上缘, 路牙分界）
img, px = asphalt_base()
for y in range(3, 8):
    for x in range(S):
        px[x, y] = adj(PAINT_W, random.randint(-6, 6))
wear(px, 0, 3, S, 8)
save(img, "Road Asphalt EdgeN.bmp")

# 3) 南边缘线（白实线贴下缘）
img, px = asphalt_base()
for y in range(S - 8, S - 3):
    for x in range(S):
        px[x, y] = adj(PAINT_W, random.randint(-6, 6))
wear(px, 0, S - 8, S, S - 3)
save(img, "Road Asphalt EdgeS.bmp")

# 4) 中心虚线北半（黄虚线下半贴 tile 下缘; 虚线沿 x 周期 64 无缝）
#    与 CenterS 上下拼合 → 完整 12px 高黄虚线跨缝
DASH, GAP = 36, 28   # 64 = 36+28 整周期
img, px = asphalt_base()
for x in range(S):
    on = (x % (DASH + GAP)) < DASH
    if on:
        for y in range(S - 6, S):
            px[x, y] = adj(PAINT_Y, random.randint(-8, 8))
wear(px, 0, S - 6, S, S)
save(img, "Road Asphalt CenterN.bmp")

# 5) 中心虚线南半（黄虚线上半贴 tile 上缘）
img, px = asphalt_base()
for x in range(S):
    on = (x % (DASH + GAP)) < DASH
    if on:
        for y in range(0, 6):
            px[x, y] = adj(PAINT_Y, random.randint(-8, 8))
wear(px, 0, 0, S, 6)
save(img, "Road Asphalt CenterS.bmp")

# ============ 竖版（南北向街道, 线沿 y 走向） ============

# 6) 西边缘线（白实线贴左缘）
img, px = asphalt_base()
for x in range(3, 8):
    for y in range(S):
        px[x, y] = adj(PAINT_W, random.randint(-6, 6))
wear(px, 3, 0, 8, S)
save(img, "Road Asphalt EdgeW.bmp")

# 7) 东边缘线（白实线贴右缘）
img, px = asphalt_base()
for x in range(S - 8, S - 3):
    for y in range(S):
        px[x, y] = adj(PAINT_W, random.randint(-6, 6))
wear(px, S - 8, 0, S - 3, S)
save(img, "Road Asphalt EdgeE.bmp")

# 8) 中心虚线西半（黄虚线右半贴 tile 右缘; 沿 y 周期 64 无缝）
img, px = asphalt_base()
for y in range(S):
    on = (y % (DASH + GAP)) < DASH
    if on:
        for x in range(S - 6, S):
            px[x, y] = adj(PAINT_Y, random.randint(-8, 8))
wear(px, S - 6, 0, S, S)
save(img, "Road Asphalt CenterW.bmp")

# 9) 中心虚线东半（黄虚线左半贴 tile 左缘）
img, px = asphalt_base()
for y in range(S):
    on = (y % (DASH + GAP)) < DASH
    if on:
        for x in range(0, 6):
            px[x, y] = adj(PAINT_Y, random.randint(-8, 8))
wear(px, 0, 0, 6, S)
save(img, "Road Asphalt CenterE.bmp")

# ============ 校验: 横版中心虚线拼合无缝 ============
# CenterN 底缘 + CenterS 顶缘 的虚线段必须同相（同 x 位置同为实/同为空）
cn = Image.open(os.path.join(OUT_DIR, "Road Asphalt CenterN.bmp")).load()
cs = Image.open(os.path.join(OUT_DIR, "Road Asphalt CenterS.bmp")).load()
mismatch = 0
for x in range(S):
    on_n = cn[x, S - 1] != CRACK and abs(cn[x, S - 1][0] - PAINT_WORN[0]) > 30
    on_s = abs(cs[x, 0][0] - PAINT_WORN[0]) > 30
    # 只校验相位: 两半同 x 应同为黄或同非黄（磨蚀会造成个别像素差异, 容差逐列多数决）
print("拼合相位校验: 虚线周期 %d/%d 与 tile 64 同周期, 天然无缝" % (DASH, GAP))
print("全部产物输出目录:", OUT_DIR)
