#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""B批5 · map2 密集街区装饰建筑(cityBlocks)布局生成器。

确定性(无随机)填充: 把主街两侧可建区按"临街界面 + 中层 + 高层塔"三条带切分,
每条带内沿 x 扫描最大可建连续段, 拆成 8~14 格宽、2~3 格巷道分隔的实心窗格体块,
按带赋层数(临街 4~6 / 中层 6~8 / 高层 8~10, 地标塔 12)。

红线: 严格避开所有 reserved 单元——围界、主街(人行道+沥青)、次街/南巷、
三栋可进入建筑及其门前通道、东北信标土丘及其坡道接引、南侧废墟坡地。
生成的体块互不重叠(分带 y 区间不相交), 也不压任何 reserved 格。

输出: build/city_blocks.json (cityBlocks 数组片段, 直接粘进 level_ext.json)。
"""
import json
import os

W, H = 140, 84  # map2 格尺寸 (x:0-139, y:0-83)

reserved = set()


def reserve_rect(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H:
                reserved.add((x, y))


# 围界
for x in range(W):
    reserved.add((x, 0))
    reserved.add((x, H - 1))
for y in range(H):
    reserved.add((0, y))
    reserved.add((W - 1, y))

# 主街(人行道 y40/y45 + 沥青 y41-44) 全宽保持通行
reserve_rect(1, 40, 138, 45)
# 次街 A/B (北侧竖街, 连通主街)
reserve_rect(59, 1, 60, 45)
reserve_rect(101, 1, 102, 45)
# 南巷 C/D (南侧竖巷, 连通主街)
reserve_rect(29, 40, 30, 82)
reserve_rect(71, 40, 72, 82)

# 三栋可进入建筑(实心占位, 禁叠) + 各自门前通道(通往主街)
reserve_rect(8, 6, 24, 24)      # 转运站
reserve_rect(15, 25, 18, 40)    # 转运站门前通道 (门 x16-17 @ y24)
reserve_rect(68, 8, 78, 18)     # 便利店
reserve_rect(72, 19, 75, 40)    # 便利店门前通道 (门 x73-74 @ y18)
reserve_rect(110, 10, 126, 30)  # 派出所
reserve_rect(117, 31, 120, 40)  # 派出所门前通道 (门 x118-119 @ y30)

# 东北信标土丘(平台+坡道)及其接引通道 —— 保持登顶动线与地标可视
reserve_rect(127, 3, 138, 19)   # 土丘本体
reserve_rect(127, 20, 138, 40)  # 土丘南侧接引(自主街上坡)

# 南侧废墟坡地(掩体地形 + 坡道)
reserve_rect(31, 55, 38, 60)

# 分带: (y0, y1, 层数下限, 层数上限)。带间留 y 缝隙 → 体块成排、内部有暗巷
BANDS = [
    (31, 39, 4, 6),   # 北·临街界面(南缘 y39 贴主街人行道 y40)
    (21, 29, 6, 8),   # 北·中层(y30 缝)
    (6, 19, 8, 10),   # 北·高层塔(y20 缝)
    (46, 54, 4, 6),   # 南·临街界面(北缘 y46 贴主街人行道 y45)
    (56, 64, 6, 8),   # 南·中层
    (66, 82, 8, 10),  # 南·高层塔
]

MIN_W, MAX_W = 8, 14   # 体块宽格数范围
ALLEY = 3              # 体块间巷道宽(街角小道辅助)
LANDMARK_X = 46        # 地标塔目标 x 中心(北侧 x25-58 大空档)
LANDMARK_STORIES = 12

blocks = []
bi = 0
landmark_placed = False


def emit(x0, y0, x1, y1, lo, hi):
    """在可建段 [x0,x1] × [y0,y1] 内切分体块(确定性层数, 永不越段)。"""
    global bi, landmark_placed
    if x1 - x0 + 1 < 4:
        return
    x = x0
    while x <= x1:
        remain = x1 - x + 1
        if remain < 4:
            break
        bw = min(MAX_W, remain)
        # 若本块之后会剩下 <4 的碎尾段(不成块也不成巷), 并入本块
        tail = remain - bw - ALLEY
        if 0 < tail < 4:
            bw = remain
        bx1 = x + bw - 1
        stories = lo + ((bi + x) % (hi - lo + 1))
        name = "Block_%d" % bi
        if (not landmark_placed and hi >= 8
                and abs((x + bx1) // 2 - LANDMARK_X) <= 4 and stories >= hi - 1):
            stories = LANDMARK_STORIES
            name = "LandmarkTower"
            landmark_placed = True
        blocks.append({
            "name": name, "map": 2,
            "x": x, "y": y0, "w": bw, "h": y1 - y0 + 1,
            "stories": stories,
        })
        bi += 1
        x = bx1 + 1 + ALLEY


for (y0, y1, lo, hi) in BANDS:
    x = 1
    while x <= 138:
        # 找最大可建连续段
        if (x, y0) in reserved or any((x, yy) in reserved for yy in range(y0, y1 + 1)):
            x += 1
            continue
        x_start = x
        while x <= 138 and not any((x, yy) in reserved for yy in range(y0, y1 + 1)):
            x += 1
        emit(x_start, y0, x - 1, y1, lo, hi)

# 校验: 体块互不重叠 且 不压 reserved
cells = {}
overlap = False
for b in blocks:
    for yy in range(b["y"], b["y"] + b["h"]):
        for xx in range(b["x"], b["x"] + b["w"]):
            if (xx, yy) in reserved:
                print("!! 体块 %s 压 reserved (%d,%d)" % (b["name"], xx, yy))
                overlap = True
            if (xx, yy) in cells:
                print("!! 体块重叠 (%d,%d): %s / %s" % (xx, yy, cells[(xx, yy)], b["name"]))
                overlap = True
            cells[(xx, yy)] = b["name"]

total_wall = len(cells)
print("cityBlocks 体块数: %d" % len(blocks))
print("新增墙格(体块 footprint 合计): %d" % total_wall)
print("校验: %s" % ("有冲突!" if overlap else "无冲突(reserved/重叠均通过)"))
hi_stories = [b["stories"] for b in blocks]
print("层数范围: %d~%d, 地标塔: %s" % (
    min(hi_stories), max(hi_stories),
    [b["name"] for b in blocks if b["stories"] == LANDMARK_STORIES]))

out_dir = os.path.join(os.path.dirname(__file__), "..", "build")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "city_blocks.json")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(blocks, f, ensure_ascii=False, indent=2)
print("写出: %s" % os.path.abspath(out_path))

# 粘贴就绪片段(一行一块, 4 空格缩进): 直接插入 level_ext.json 的 cityBlocks 数组
snip = ",\n".join(
    '    { "name": "%s", "map": 2, "x": %d, "y": %d, "w": %d, "h": %d, "stories": %d }'
    % (b["name"], b["x"], b["y"], b["w"], b["h"], b["stories"])
    for b in blocks)
snip_path = os.path.join(out_dir, "city_blocks_snippet.txt")
with open(snip_path, "w", encoding="utf-8") as f:
    f.write(snip)
print("片段: %s (%d 行)" % (os.path.abspath(snip_path), len(blocks)))
