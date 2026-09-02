# -*- coding: utf-8 -*-
"""提交消息辅助 · 提取工作区里 A批7 的事实条目(与 A批8 交织, 需分离)。

只读: level_ext.json 的 A批7 _comment 全文 + 条目结构摘要, LevelGenerator.gd /
SmokeTest.gd / MiniMap.gd 中含 A批7 标记的行。用于撰写准确的提交消息。
运行: python godot/tools/probe_ab7_facts.py
"""
import io
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MARK = "A批7"


def scan_gd(path, tag):
    full = os.path.join(ROOT, path)
    if not os.path.exists(full):
        return
    lines = io.open(full, encoding="utf-8").read().split("\n")
    print("\n=== %s 中含 %s 的行(%d 处) ===" % (path, tag, sum(
        1 for l in lines if tag in l)))
    for i, l in enumerate(lines, 1):
        if tag in l:
            print("  %4d: %s" % (i, l.strip()[:200]))


def main():
    ext = json.load(io.open(os.path.join(
        ROOT, "godot", "assets", "config", "level_ext.json"), encoding="utf-8"))
    print("=== level_ext.json 中含 %s 的条目 ===" % MARK)
    for key, arr in ext.items():
        if not isinstance(arr, list):
            if isinstance(arr, dict) and MARK in json.dumps(arr, ensure_ascii=False):
                print("  [%s] dict 含标记" % key)
            continue
        for idx, e in enumerate(arr):
            if not isinstance(e, dict):
                continue
            blob = json.dumps(e, ensure_ascii=False)
            if MARK not in blob:
                continue
            print("\n  --- %s[%d] ---" % (key, idx))
            for k, v in e.items():
                if k == "_comment":
                    print("    _comment: %s" % str(v)[:1500])
                elif isinstance(v, list):
                    print("    %-14s list(%d) %s"
                          % (k, len(v), json.dumps(v[:2], ensure_ascii=False)[:200]))
                else:
                    print("    %-14s %s" % (k, json.dumps(v, ensure_ascii=False)[:200]))

    for p in ("godot/scripts/levels/LevelGenerator.gd",
              "godot/scripts/ui/MiniMap.gd",
              "godot/scripts/tests/SmokeTest.gd",
              "godot/scripts/main/Main.gd",
              "godot/scripts/core/WorldConst.gd"):
        scan_gd(p, MARK)

    print("\n=== 层区面积相关(layers rect/grid 规模) ===")
    for ld in ext.get("layers", []):
        if ld.get("map") != 0:
            continue
        g = ld.get("grid", [])
        rect = ld.get("rect", {})
        walk = sum(1 for r in g for ch in r if ch == ".")
        print("  floor%s rect=%s baseHeight=%s grid=%dx%d 可走'.'=%d"
              % (ld.get("floor"), json.dumps(rect), ld.get("baseHeight"),
                 len(g), max((len(r) for r in g), default=0), walk))
        print("      keys: %s" % list(ld.keys()))
        print("      enemies=%d pickups=%d slabHoles=%d"
              % (len(ld.get("enemies", [])), len(ld.get("pickups", [])),
                 len(ld.get("slabHoles", []))))


if __name__ == "__main__":
    main()
