# -*- coding: utf-8 -*-
"""B线勘察 · map2(第二关 城区街道)现状探针。

只读: level_ext.json 的 maps[map=2] 全字段 + LevelData.gd 的 MAPS 块数/尺寸常量
+ terrain/props 等段是否覆盖 map2 → 判定 B批1..4 各批落地情况。
运行: python godot/tools/probe_map2.py
"""
import io
import json
import os
import re
from collections import Counter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_EXT = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
LEVEL_DATA = os.path.join(ROOT, "godot", "scripts", "levels", "LevelData.gd")
NARRATIVE = os.path.join(ROOT, "godot", "assets", "config", "narrative.json")
WEAPONS = os.path.join(ROOT, "godot", "assets", "config", "weapons.json")


def main():
    ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"))
    print("=== level_ext.json 顶层段 ===")
    print("  " + ", ".join(ext.keys()))

    m = [x for x in ext.get("maps", []) if x.get("map") == 2]
    if not m:
        raise SystemExit("maps 段无 map=2")
    m = m[0]
    print("\n=== maps[map=2] ===")
    for k, v in m.items():
        if k == "_comment":
            continue
        if isinstance(v, list):
            print("  %-12s list(%d) %s" % (k, len(v), v[:3]))
        else:
            print("  %-12s %s" % (k, v))
    print("  _comment: %s" % str(m.get("_comment", ""))[:600])

    print("\n=== 各段对 map2 的覆盖 ===")
    for key in ("terrain", "wallDecals", "layers", "goals", "partitions",
                "enemyOverrides", "pickupOverrides", "facade", "props",
                "courtyard", "stairs"):
        arr = ext.get(key)
        if arr is None:
            print("  %-18s 段不存在" % key)
            continue
        if isinstance(arr, dict):
            print("  %-18s dict(map=%s)" % (key, arr.get("map")))
            continue
        maps = Counter()
        for e in arr:
            if isinstance(e, dict):
                maps[e.get("map", "?")] += 1
        print("  %-18s %d 条, 按 map: %s" % (key, len(arr), dict(maps)))

    src = io.open(LEVEL_DATA, encoding="utf-8").read()
    blocks = re.findall(r'"""(.*?)"""', src, re.S)
    print("\n=== LevelData.gd ===")
    print("  MAPS 符号图块数: %d" % len(blocks))
    for i, b in enumerate(blocks):
        rows = [r for r in b.split("\n")]
        nz = [r for r in rows if r.strip()]
        print("    MAPS[%d]: 行 %d(非空 %d), 宽 %d, 符号 %s"
              % (i, len(rows), len(nz), max((len(r) for r in nz), default=0),
                 dict(Counter(ch for r in nz for ch in r if ch != " "))))
    print("  尺寸常量: %s" % re.findall(r"const (?:WIDTH|HEIGHT) := \d+", src))

    print("\n=== narrative.json 第二关文案 ===")
    if os.path.exists(NARRATIVE):
        n = json.load(io.open(NARRATIVE, encoding="utf-8"))
        for key in ("briefings", "victory", "area_hints"):
            v = n.get(key)
            if isinstance(v, list):
                print("  %-12s list(%d)" % (key, len(v)))
                for i, it in enumerate(v):
                    txt = it if isinstance(it, str) else json.dumps(
                        it, ensure_ascii=False)
                    print("    [%d] %s" % (i, txt[:110]))
            elif isinstance(v, dict):
                print("  %-12s dict keys %s" % (key, list(v.keys())))
    else:
        print("  narrative.json 不存在")

    print("\n=== weapons.json 中 map 索引使用 ===")
    w = json.load(io.open(WEAPONS, encoding="utf-8"))
    for key in ("shellSpawns", "pickupSpawns"):
        arr = w.get(key, [])
        print("  %-18s %s" % (key, dict(Counter(
            e.get("map") for e in arr if isinstance(e, dict) and "map" in e))))
    uc = w.get("upgradeComponents", {}).get("spawns", [])
    print("  upgradeComponents  %s" % dict(Counter(
        e.get("map") for e in uc if isinstance(e, dict) and "map" in e)))
    print("  (转关后 map_index=2 → 标 map=1 的 spawn 全部不落位)")


if __name__ == "__main__":
    main()
