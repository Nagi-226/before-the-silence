# -*- coding: utf-8 -*-
"""A批8 · 一层补给/敌人存量统计(匀往二三层的决策输入)。

口径与运行时一致: MAPS split 后 rows[0] 空行跳过, y=行索引;
H 符号按"每第4个转 e"平衡规则折算实际生成物。
输出: 各补给符号总数 + 已抑制数 + 净存量, 三型敌人总数 + 已抑制 + 净存量。
"""
import io
import json
import os
import re
from collections import Counter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_DATA = os.path.join(ROOT, "godot", "scripts", "levels", "LevelData.gd")
LEVEL_EXT = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")


def extract_map0_rows():
    src = io.open(LEVEL_DATA, encoding="utf-8").read()
    m = re.search(r"const MAPS := \[\s*\"\"\"(.*?)\"\"\"", src, re.S)
    if not m:
        raise SystemExit("MAPS map0 提取失败")
    return [r.rstrip("\r") for r in m.group(1).split("\n")]


def main():
    rows = extract_map0_rows()
    ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"))

    p_sup = set()
    for e in ext.get("pickupOverrides", []):
        if e.get("map") != 0:
            continue
        s = e.get("suppress", {})
        if isinstance(s, dict) and s:
            p_sup.add((s.get("x"), s.get("y")))
        elif isinstance(s, list):
            for it in s:
                p_sup.add((it.get("x"), it.get("y")))
    e_sup = set()
    e_place = Counter()
    for e in ext.get("enemyOverrides", []):
        if e.get("map") != 0:
            continue
        for it in e.get("suppress", []):
            e_sup.add((it.get("x"), it.get("y")))
        for it in e.get("place", []):
            e_place[(it.get("id"), it.get("floor", 1))] += 1

    raw = Counter()
    cells = {}
    health_seen = 0
    for y in range(1, len(rows)):
        for x, ch in enumerate(rows[y]):
            if ch in "HCAhaw012":
                raw[ch] += 1
                cells.setdefault(ch, []).append((x, y))
            if ch == "H":
                health_seen += 1

    print("=== 符号图原始存量(map0) ===")
    for ch in "HCAhaw012":
        print("  %s: %d" % (ch, raw[ch]))
    print("  H 按每4个转e折算: H=%d e_from_H=%d"
          % (health_seen - health_seen // 4, health_seen // 4))

    print("\n=== 补给: 已抑制 %d 格 ===" % len(p_sup))
    sup_by = Counter()
    for (x, y) in sorted(p_sup):
        if 0 <= y < len(rows) and x < len(rows[y]):
            sup_by[rows[y][x]] += 1
    print("  按符号:", dict(sup_by))

    # 净存量(实际生成物口径)
    net = Counter()
    hs = 0
    for y in range(1, len(rows)):
        for x, ch in enumerate(rows[y]):
            if (x, y) in p_sup and ch in "HCAhaw":
                continue
            if ch == "H":
                hs += 1
                net["e" if hs % 4 == 0 else "H"] += 1
            elif ch in "aw":
                net["e"] += 1
            elif ch in "CAh":
                net[ch] += 1
    print("\n=== 一层补给净存量(实际生成物) ===")
    for k in ("H", "e", "C", "A", "h"):
        print("  %s: %d" % (k, net[k]))
    print("  合计: %d" % sum(net.values()))

    # 层补给(layers[].pickups)
    print("\n=== 二三层 layers.pickups 存量 ===")
    for ld in ext.get("layers", []):
        if ld.get("map") != 0:
            continue
        c = Counter(p.get("symbol") for p in ld.get("pickups", []))
        print("  floor%d: 合计 %d %s" % (ld["floor"], sum(c.values()), dict(c)))

    print("\n=== 敌人: 已抑制 %d 格, 重布 %s ==="
          % (len(e_sup), dict(e_place)))
    enem = Counter()
    for y in range(1, len(rows)):
        for x, ch in enumerate(rows[y]):
            if ch in "012" and (x, y) not in e_sup:
                enem[ch] += 1
    print("  一层净存量: id0=%d id1=%d id2=%d 合计=%d"
          % (enem["0"], enem["1"], enem["2"], sum(enem.values())))
    print("  一层可走格 7284 → 敌人密度 %.2f 只/百格"
          % (sum(enem.values()) / 7284 * 100))
    for ld in ext.get("layers", []):
        if ld.get("map") != 0:
            continue
        f = ld["floor"]
        n = sum(v for (i, fl), v in e_place.items() if fl == f)
        n += len(ld.get("enemies", []))
        walk = sum(1 for row in ld["grid"] for c2 in row if c2 == " ") \
            - len(ld.get("slabHoles", []))
        print("  floor%d: 敌人 %d 只, 可走 %d 格 → 密度 %.2f 只/百格"
              % (f, n, walk, n / walk * 100))


if __name__ == "__main__":
    main()
