# -*- coding: utf-8 -*-
"""B线勘察 · dev2 分支 map2(城区街道)实装内容只读探针。

不切分支(dev1 工作区有未提交的 A批7/8 成果), 用 `git show dev2:<path>` 取内容。
输出: map2 配置全貌(grid 符号统计/groundZones/terrain/敌补分布) + narrative
map2 提示 + LevelGenerator/SmokeTest 的 dev2 侧改动摘要。
运行: python godot/tools/probe_map2_dev2.py
"""
import json
import os
import subprocess
from collections import Counter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def git_show(path, ref="dev2"):
    r = subprocess.run(["git", "show", "%s:%s" % (ref, path)],
                       capture_output=True, cwd=ROOT)
    if r.returncode != 0:
        return None
    return r.stdout.decode("utf-8")


def main():
    ext = json.loads(git_show("godot/assets/config/level_ext.json"))
    print("=== dev2 level_ext.json 顶层段 ===")
    print("  " + ", ".join(ext.keys()))

    m = [x for x in ext["maps"] if x["map"] == 2][0]
    print("\n=== dev2 maps[map=2] ===")
    for k, v in m.items():
        if k in ("_comment", "grid"):
            continue
        if isinstance(v, list):
            print("  %-14s list(%d)" % (k, len(v)))
        else:
            print("  %-14s %s" % (k, v))
    print("  _comment: %s" % str(m.get("_comment", ""))[:700])

    grid = m.get("grid", [])
    if grid:
        print("\n  grid: %d 行 x %d 宽" % (len(grid), max(len(r) for r in grid)))
        cnt = Counter(ch for r in grid for ch in r)
        print("  符号统计: %s" % dict(cnt.most_common()))
        print("  前 6 行预览:")
        for r in grid[:6]:
            print("    |%s|" % r)
    else:
        print("\n  grid: 无(几何走 LevelData 回退或纯 borderWall)")

    print("\n=== buildings(6) ===")
    for b in m.get("buildings", []):
        print("  %s" % json.dumps(b, ensure_ascii=False))

    print("\n=== groundZones(%d) ===" % len(m.get("groundZones", [])))
    for z in m.get("groundZones", []):
        r = z.get("rect", {})
        print("  rect(%3s,%3s,%3s,%3s) tex=%s %s"
              % (r.get("x"), r.get("y"), r.get("w"), r.get("h"),
                 str(z.get("texture", "")).split("/")[-1],
                 str(z.get("_comment", ""))[:60]))

    print("\n=== enemies(%d) ===" % len(m.get("enemies", [])))
    for e in m.get("enemies", []):
        print("  %s" % json.dumps(e, ensure_ascii=False)[:220])

    print("\n=== pickups(%d) ===" % len(m.get("pickups", [])))
    for p in m.get("pickups", []):
        print("  %s" % json.dumps(p, ensure_ascii=False)[:220])

    print("\n=== dev2 各段对 map2 的覆盖 ===")
    for key in ("terrain", "groundZones", "wallDecals", "layers", "goals",
                "partitions", "enemyOverrides", "pickupOverrides", "facade",
                "props", "courtyard", "stairs"):
        arr = ext.get(key)
        if arr is None:
            continue
        if isinstance(arr, dict):
            print("  %-18s dict(map=%s) keys=%s"
                  % (key, arr.get("map"), list(arr.keys())[:8]))
            continue
        c = Counter(e.get("map", "?") for e in arr if isinstance(e, dict))
        print("  %-18s %d 条, 按 map: %s" % (key, len(arr), dict(c)))
        if c.get(2):
            for e in arr:
                if isinstance(e, dict) and e.get("map") == 2:
                    print("      map2 → %s"
                          % json.dumps(e, ensure_ascii=False)[:420])

    print("\n=== dev2 narrative.json map2 相关 ===")
    n = json.loads(git_show("godot/assets/config/narrative.json"))
    for i, h in enumerate(n.get("area_hints", [])):
        if h.get("map") == 2:
            print("  hint[%d] (%s,%s) r=%s: %s"
                  % (i, h.get("x"), h.get("y"), h.get("radius"),
                     str(h.get("text"))[:150]))
    print("  briefings[2]: %s" % json.dumps(
        n["briefings"][2], ensure_ascii=False)[:400])

    print("\n=== dev2 weapons.json map 索引(确认 v 落位方式) ===")
    w = json.loads(git_show("godot/assets/config/weapons.json"))
    for key in ("shellSpawns", "pickupSpawns"):
        print("  %-18s %s" % (key, json.dumps(
            w.get(key, []), ensure_ascii=False)[:300]))
    print("  upgradeComponents.spawns %s" % json.dumps(
        w.get("upgradeComponents", {}).get("spawns", []),
        ensure_ascii=False)[:400])


if __name__ == "__main__":
    main()
