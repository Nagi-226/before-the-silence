#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_stairs.py — 楼梯踏步贴图程序化生成(64×64 BMP, 32px/m 与墙贴图同密度)
踏步单元贴图: 上 40% 踏面(浅暖灰+噪点+防滑条) / 下 60% 立面(深暖灰+底部阴影)。
每级台阶一贴图(侧立面完整显示踏面+立面, 顶面显示为横条纹理=防滑条观感)。
种子固定, 可复现。先例: gen_gate.py / gen_roads.py。"""
import random
from PIL import Image

W = H = 64
random.seed(20260830)

img = Image.new("RGB", (W, H))

def shade(base, n):
    return tuple(max(0, min(255, int(c + n))) for c in base)

TREAD = (138, 126, 110)   # 踏面 浅暖灰(与土丘 tint 同族)
RISER = (86, 78, 66)      # 立面 深暖灰

tread_h = 25  # 上 25px 踏面, 下 39px 立面

for y in range(H):
    for x in range(W):
        n = random.randint(-6, 6)
        if y < tread_h:
            c = shade(TREAD, n)
            # 防滑条: 踏面顶缘 2px 亮条
            if y < 2:
                c = shade(TREAD, 26)
            # 踏面前缘 3px 略亮(磨损感)
            elif y > tread_h - 4:
                c = shade(TREAD, 10)
        else:
            c = shade(RISER, n)
            # 立面底部 6px 阴影渐深
            if y > H - 8:
                c = shade(RISER, -(y - (H - 8)) * 3)
        img.putpixel((x, y), c)

img.save("Stair Steps.bmp")
print("Stair Steps.bmp 64x64 saved")
