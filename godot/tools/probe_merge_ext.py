# -*- coding: utf-8 -*-
"""双线合并勘察 · level_ext.json 三路(O=merge-base / A=master / B=dev2)段结构对比。

只读: 用 `git show <ref>:<path>` 取三个版本, 逐顶层段打印类型/规模/map 归属,
并判定每段属于「仅 A 改」「仅 B 改」「双侧改」→ 为语义合并定口径。
运行: python godot/tools/probe_merge_ext.py
"""
import json
import os
import subprocess
from collections import Counter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PATH = "godot/assets/config/level_ext.json"
REFS = {"O": "ab76dde", "A": "master", "B": "dev2"}


def git_show(ref):
    r = subprocess.run(["git", "show", "%s:%s" % (ref, PATH)],
                       capture_output=True, cwd=ROOT)
    if r.returncode != 0:
        raise SystemExit("git show 失败 %s: %s" % (ref, r.stderr.decode("utf-8", "replace")))
    return json.loads(r.stdout.decode("utf-8"))


def brief(v):
    """段的规模摘要(不打印内容)。"""
    if isinstance(v, dict):
        return "dict(%d 键: %s)" % (len(v), ", ".join(list(v.keys())[:8]))
    if isinstance(v, list):
        maps = Counter()
        for it in v:
            if isinstance(it, dict) and "map" in it:
                maps[it["map"]] += 1
        extra = ""
        if maps:
            extra = " | map 归属 " + str(dict(sorted(maps.items())))
        return "list(%d 项)%s" % (len(v), extra)
    return "%s = %s" % (type(v).__name__, json.dumps(v, ensure_ascii=False)[:80])


def main():
    vers = {k: git_show(r) for k, r in REFS.items()}
    keys = []
    for k in ("O", "A", "B"):
        for key in vers[k]:
            if key not in keys:
                keys.append(key)

    print("=== 顶层段清单(O/A/B 三版本) ===")
    print("%-22s %-6s %-6s %-6s  判定" % ("段名", "O", "A", "B"))
    for key in keys:
        in_o, in_a, in_b = key in vers["O"], key in vers["A"], key in vers["B"]
        same_a = in_o and in_a and json.dumps(vers["O"][key], sort_keys=True, ensure_ascii=False) == \
            json.dumps(vers["A"][key], sort_keys=True, ensure_ascii=False)
        same_b = in_o and in_b and json.dumps(vers["O"][key], sort_keys=True, ensure_ascii=False) == \
            json.dumps(vers["B"][key], sort_keys=True, ensure_ascii=False)
        if not in_o:
            verdict = "新增(A/B 两侧都新加?)" if (in_a and in_b) else ("仅 A 新增" if in_a else "仅 B 新增")
        elif same_a and same_b:
            verdict = "双侧未改"
        elif same_a:
            verdict = "仅 B 改 → 取 B"
        elif same_b:
            verdict = "仅 A 改 → 取 A"
        else:
            verdict = "!! 双侧都改 → 需深合并"
        print("%-22s %-6s %-6s %-6s  %s"
              % (key, "有" if in_o else "-", "有" if in_a else "-", "有" if in_b else "-", verdict))

    for tag in ("O", "A", "B"):
        print("\n=== %s(%s) 各段规模 ===" % (tag, REFS[tag]))
        for key in vers[tag]:
            print("  %-20s %s" % (key, brief(vers[tag][key])))

    # maps 段逐条对比(最关键的深合并对象)
    print("\n=== maps 段逐条(按 map 索引) ===")
    for tag in ("O", "A", "B"):
        ms = vers[tag].get("maps", [])
        print("  %s: %s" % (tag, [
            {"map": m.get("map"), "keys": sorted(m.keys()),
             "w": m.get("width"), "h": m.get("height")} for m in ms]))


if __name__ == "__main__":
    main()
