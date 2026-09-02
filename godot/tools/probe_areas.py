# -*- coding: utf-8 -*-
"""探针: map0 一楼室内可走总面积 / 敌人构成(id 0/1/2 坐标) / 二三层可走面积对比。

口径:
- LevelData.MAPS 三引号串 split 后 rows[0] 为空行(已知坑), 运行时 y = 行索引,
  本探针直接输出运行时坐标 (x=列索引, y=行索引)。
- 墙符号 = X/M/S/G(与 LevelGenerator.build 同口径), 其余字符(含空格)均为一层可走格。
- 庭院为 level_ext.json 运行时外扩(config), 不在 MAPS 内 → 本探针天然只统计室内。
- 二/三层可走 = layers grid 中非 X 格(层 rect 内), 与生成器层地板口径一致。

运行: python godot/tools/probe_areas.py
"""
import io
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_DATA = os.path.join(ROOT, "godot", "scripts", "levels", "LevelData.gd")
LEVEL_EXT = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
WALLS = set("XMSG")


def extract_map0_rows():
    src = io.open(LEVEL_DATA, encoding="utf-8").read()
    m = re.search(r"const MAPS := \[\s*\"\"\"(.*?)\"\"\"", src, re.S)
    if not m:
        raise SystemExit("MAPS map0 提取失败")
    return [r.rstrip("\r") for r in m.group(1).split("\n")]


def main():
    rows = extract_map0_rows()
    assert rows[0] == "", "rows[0] 应为空行(口径漂移?)"
    total = 0
    walk = 0
    enemies = {"0": [], "1": [], "2": []}
    for y in range(1, len(rows)):  # 跳过空行 rows[0], y=运行时行索引
        row = rows[y]
        for x, ch in enumerate(row):
            total += 1
            if ch not in WALLS:
                walk += 1
            if ch in enemies:
                enemies[ch].append((x, y))
    print("map0 尺寸(运行时): %d x %d 行" % (max(len(r) for r in rows), len(rows)))
    print("一层室内总格数: %d, 墙格: %d, 可走格: %d" % (total, total - walk, walk))
    print("敌人构成: id0(孢子囊)=%d, id1(宿主)=%d, id2(巨型突变体/精英)=%d"
          % (len(enemies["0"]), len(enemies["1"]), len(enemies["2"])))
    print("id2 运行时坐标: %s" % enemies["2"])
    print("id1 运行时坐标: %s" % enemies["1"])

    ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"))
    for layer in ext.get("layers", []):
        if layer.get("map") != 0:
            continue
        grid = layer["grid"]
        rect = layer["rect"]
        fwalk = sum(1 for r in grid for ch in r if ch != "X")
        print("floor%d rect=%s 可走=%d (一层室内可走的 %.1f%%)"
              % (layer["floor"], rect, fwalk, 100.0 * fwalk / walk))
        need = int(walk * 0.7)
        print("floor%d 达 70%% 需可走 %d 格, 缺口 %d 格"
              % (layer["floor"], need, max(0, need - fwalk)))


if __name__ == "__main__":
    main()
