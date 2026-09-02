# -*- coding: utf-8 -*-
"""A批8 勘察: 需避让的关键位置(出生点/终点旗/楼梯/霰弹补给/组件)."""
import io
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_DATA = os.path.join(ROOT, "godot", "scripts", "levels", "LevelData.gd")
LEVEL_EXT = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
WEAPONS = os.path.join(ROOT, "godot", "assets", "config", "weapons.json")

ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"))
w = json.load(io.open(WEAPONS, encoding="utf-8"))

print("--- goals ---")
print(json.dumps(ext.get("goals", []), ensure_ascii=False)[:800])
print("\n--- stairs ---")
print(json.dumps(ext.get("stairs", []), ensure_ascii=False)[:900])
print("\n--- courtyard rect ---")
print(json.dumps(ext.get("courtyard", {}).get("rect", {}), ensure_ascii=False))
print("\n--- shellSpawns map0 ---")
print([s for s in w.get("shellSpawns", []) if s.get("map") == 0])
print("--- pickupSpawns map0 ---")
print([s for s in w.get("pickupSpawns", []) if s.get("map") == 0])
print("--- upgradeComponents map0 ---")
print([s for s in w.get("upgradeComponents", {}).get("spawns", [])
       if s.get("map") == 0])
print("\n--- pickupOverrides place ---")
for e in ext.get("pickupOverrides", []):
    if e.get("map") == 0:
        print(e.get("place"))
print("\n--- layers enemies(塔楼原有) ---")
for ld in ext.get("layers", []):
    if ld.get("map") == 0:
        print(" floor", ld["floor"], ld.get("enemies", []))

src = io.open(LEVEL_DATA, encoding="utf-8").read()
rows = [r.rstrip("\r") for r in
        re.search(r"const MAPS := \[\s*\"\"\"(.*?)\"\"\"", src, re.S).group(1).split("\n")]
print("\n--- MAPS P/F 符号位 ---")
for y in range(1, len(rows)):
    for x, ch in enumerate(rows[y]):
        if ch in "PF":
            print("  %s @ (%d,%d)" % (ch, x, y))
