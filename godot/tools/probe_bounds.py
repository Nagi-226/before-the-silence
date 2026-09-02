# -*- coding: utf-8 -*-
"""探针2: map0 符号图内容 bbox / 行长分布 / 宏观降采样图(设计扩面 rect 用)。"""
import io
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_DATA = os.path.join(ROOT, "godot", "scripts", "levels", "LevelData.gd")
WALLS = set("XMSG")


def extract_map0_rows():
    src = io.open(LEVEL_DATA, encoding="utf-8").read()
    m = re.search(r"const MAPS := \[\s*\"\"\"(.*?)\"\"\"", src, re.S)
    return [r.rstrip("\r") for r in m.group(1).split("\n")]


def main():
    rows = extract_map0_rows()
    lens = sorted(set(len(r) for r in rows))
    print("行数: %d, 行长集合: %s" % (len(rows), lens))
    # 非空内容 bbox(非空格字符)
    minx, maxx, miny, maxy = 10**9, -1, 10**9, -1
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch.strip():
                minx, maxx = min(minx, x), max(maxx, x)
                miny, maxy = min(miny, y), max(maxy, y)
    print("非空内容 bbox: x[%d..%d] y[%d..%d]" % (minx, maxx, miny, maxy))
    # 每行内容 x 范围(抽样打印前/中/后)
    for y in [1, 2, 10, 30, 50, maxy]:
        r = rows[y] if y < len(rows) else ""
        xs = [x for x, ch in enumerate(r) if ch.strip()]
        if xs:
            print("row%02d 内容 x[%d..%d] 长%d" % (y, xs[0], xs[-1], len(r)))
    # 宏观降采样: 每 4x2 格一块, 墙占比>50% 记 '#', 全空记 '.', 否则 '+'
    print("--- 降采样图 (4x2/块, #=墙多 .=空 +=混合) ---")
    for by in range(0, maxy + 1, 2):
        line = []
        for bx in range(0, maxx + 1, 4):
            w = t = 0
            for yy in range(by, min(by + 2, len(rows))):
                for xx in range(bx, min(bx + 4, len(rows[yy]))):
                    ch = rows[yy][xx]
                    if ch.strip():
                        t += 1
                        if ch in WALLS:
                            w += 1
            line.append("#" if t and w * 2 >= t else ("+" if t else "."))
        print("%02d|%s" % (by, "".join(line)))


if __name__ == "__main__":
    main()
