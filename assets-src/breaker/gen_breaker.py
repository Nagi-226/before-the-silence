# -*- coding: utf-8 -*-
"""
gen_breaker.py — 「静默之前」配电箱墙贴生成器（可复现，A批6 合闸机制）
产物: godot/assets/images/Breaker Off.bmp / Breaker On.bmp  (64x64, 2m x 2m 墙面贴花,
      与墙贴图同像素密度 32px/m)
设计: 挂墙式配电箱(冷灰钢, 对齐 Gate/Facade 家族) + 箱门缝/铰链/警示条 + 状态灯;
      Off=红色状态灯+闸刀朝下(断电), On=绿色状态灯+闸刀朝上(已合闸)。
纯程序化绘制, 避免 AI 贴图风格漂移。
"""
import random
from PIL import Image

random.seed(20260830)

W, H = 64, 64
ROOT = r"E:\Github Project\Nagi_Games\before-the-silence"

# ---- 色板 (与 Gate Cargo / Facade Panel 同族冷灰 + 锈色) ----
WALL     = None              # 背景透明(贴花叠加在墙面上)? 否——整面不透明, 用混凝土底色
CONCRETE = (58, 60, 62)      # 墙面混凝土底(与 Wall Concrete 接近)
CON_LO   = (46, 48, 50)
BOX      = (70, 78, 82)      # 箱体钢灰
BOX_HI   = (96, 106, 110)    # 箱体顶光
BOX_LO   = (48, 54, 58)      # 箱体底影
SEAM     = (26, 30, 33)      # 门缝/内衬
LEVER    = (150, 154, 156)   # 闸刀金属
HAZ_Y    = (156, 120, 46)    # 警示黄(做旧)
HAZ_D    = (38, 36, 29)
LAMP_OFF = (196, 46, 32)     # 红灯(断电)
LAMP_ON  = (60, 200, 80)     # 绿灯(已合闸)
RUST     = [(108, 76, 42), (130, 88, 46), (92, 62, 36)]


def adj(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)


def build(powered: bool) -> Image:
    img = Image.new("RGB", (W, H), CONCRETE)
    px = img.load()

    # 墙面底: 微噪点混凝土
    for _ in range(300):
        x, y = random.randrange(W), random.randrange(H)
        px[x, y] = adj(CONCRETE, random.randint(-8, 6))

    # 箱体区: 居中 40x48, 上缘留 6px
    bx0, by0, bx1, by1 = 12, 6, 51, 53
    for y in range(by0, by1 + 1):
        for x in range(bx0, bx1 + 1):
            j = random.randint(-3, 3)
            px[x, y] = adj(BOX, j)
    # 箱体边缘高光/阴影
    for x in range(bx0, bx1 + 1):
        px[x, by0] = BOX_HI
        px[x, by1] = BOX_LO
    for y in range(by0, by1 + 1):
        px[bx0, y] = BOX_HI
        px[bx1, y] = BOX_LO

    # 箱门内凹面(留 3px 边)
    dx0, dy0, dx1, dy1 = bx0 + 3, by0 + 3, bx1 - 3, by1 - 3
    for y in range(dy0, dy1 + 1):
        for x in range(dx0, dx1 + 1):
            px[x, y] = adj(BOX, -12 + random.randint(-3, 3))
    # 门缝
    for x in range(dx0, dx1 + 1):
        px[x, dy0] = SEAM
        px[x, dy1] = SEAM
    for y in range(dy0, dy1 + 1):
        px[dx0, y] = SEAM
        px[dx1, y] = SEAM
    # 铰链(左侧上下两粒)
    for hy in (dy0 + 4, dy1 - 6):
        for dy in range(3):
            px[dx0 + 1, hy + dy] = BOX_HI
            px[dx0 + 2, hy + dy] = SEAM

    # 警示条(门内上部, 斜纹黄黑)
    for yy in range(dy0 + 2, dy0 + 6):
        for xx in range(dx0 + 4, dx1 - 4):
            px[xx, yy] = HAZ_Y if ((xx + yy) // 4) % 2 == 0 else HAZ_D

    # 闸刀槽(门内中部竖槽) + 闸刀柄: Off=朝下, On=朝上
    slot_x0, slot_x1 = (dx0 + dx1) // 2 - 2, (dx0 + dx1) // 2 + 2
    slot_y0, slot_y1 = dy0 + 10, dy1 - 8
    for yy in range(slot_y0, slot_y1 + 1):
        for xx in range(slot_x0, slot_x1 + 1):
            px[xx, yy] = SEAM
    lever_y = slot_y0 + 2 if powered else slot_y1 - 6
    for dy in range(5):
        for dx in range(-1, 2):
            px[slot_x0 + 2 + dx, lever_y + dy] = LEVER if dy in (0, 4) else adj(LEVER, -30)
    # 闸刀旁的通/断刻度点
    px[slot_x1 + 2, slot_y0 + 1] = LAMP_ON if powered else adj(LAMP_ON, -110)
    px[slot_x1 + 2, slot_y1 - 2] = adj(LAMP_OFF, -60) if powered else LAMP_OFF

    # 状态灯(门内右上, 2x2 + 光晕)
    lamp = LAMP_ON if powered else LAMP_OFF
    lx, ly = dx1 - 6, dy0 + 9
    for dy in range(2):
        for dx in range(2):
            px[lx + dx, ly + dy] = lamp
    for dx, dy in [(-1, 0), (2, 0), (0, -1), (1, -1), (-1, 1), (2, 1), (0, 2), (1, 2)]:
        px[lx + dx, ly + dy] = adj(lamp, -120)

    # 箱底进线管
    for yy in range(by1 + 1, min(H, by1 + 7)):
        for xx in range(bx0 + 14, bx0 + 19):
            px[xx, yy] = BOX_LO

    # 锈迹(箱体边缘富集)
    for _ in range(46):
        edge = random.random()
        if edge < 0.5:
            xx = random.choice([bx0, bx1]) + random.randint(-1, 1)
            yy = random.randint(by0, by1)
        else:
            xx = random.randint(bx0, bx1)
            yy = random.choice([by0, by1]) + random.randint(-1, 1)
        if 0 <= xx < W and 0 <= yy < H:
            c = random.choice(RUST)
            px[xx, yy] = c
            if random.random() < 0.4 and yy + 1 < H:
                px[xx, yy + 1] = adj(c, -20)
    return img


for powered, name in [(False, "Breaker Off"), (True, "Breaker On")]:
    im = build(powered)
    im.save(r"%s\godot\assets\images\%s.bmp" % (ROOT, name), "BMP")
    im.resize((256, 256), Image.NEAREST).save(r"%s\assets-src\breaker\preview_%s.png" % (ROOT, name.replace(" ", "_").lower()))
    print("saved", name)
