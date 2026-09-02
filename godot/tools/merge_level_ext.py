# -*- coding: utf-8 -*-
"""双线合并 · level_ext.json 三路语义合并(A=master 室内多层线 / B=dev2 城区街道线)。

文本级 merge 失败(两侧 JSON 排版密度差异过大 → 整文件成单一冲突块), 改走段级语义合并。
口径依据 probe_merge_ext.py 的勘察结论:

  段名              判定                取值
  --------------    ----------------    ------------------------------
  wallDecals        仅 A 改             A
  maps              仅 B 改             B(map2 buildings/groundZones)
  terrain           双侧都改            A 的 map0 条目 + B 的 map2 条目
  stairs/partitions/pickupOverrides/
  enemyOverrides/layers                 仅 A 有 → A
  其余(_comment/courtyard/facade/props/
  campaign/goals/miniMapFollow/followView) 双侧未改 → A(==B)

排版沿用 A 侧惯例: json.dumps(ensure_ascii=False, indent=2) + CRLF + 末尾换行
(patch_level_ext.py / patch_rebalance.py 同口径, 保证后续脚本可直接读写)。

运行: python godot/tools/merge_level_ext.py [--check]
      --check 只诊断不落盘
"""
import io
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
REL = "godot/assets/config/level_ext.json"
DST = os.path.join(ROOT, REL.replace("/", os.sep))
REFS = {"O": "ab76dde", "A": "master", "B": "dev2"}

# 仅 B 改 → 整段取 B
TAKE_B = ("maps",)
# 双侧都改 → 按 map 归属深合并(A 保留 map!=2, B 提供 map==2)
DEEP_BY_MAP = ("terrain",)


def git_show(ref):
    r = subprocess.run(["git", "show", "%s:%s" % (ref, REL)],
                       capture_output=True, cwd=ROOT)
    if r.returncode != 0:
        raise SystemExit("git show 失败 %s: %s"
                         % (ref, r.stderr.decode("utf-8", "replace")))
    return json.loads(r.stdout.decode("utf-8"))


def dump(v):
    return json.dumps(v, sort_keys=True, ensure_ascii=False)


def main():
    check_only = "--check" in sys.argv
    v = {k: git_show(r) for k, r in REFS.items()}
    O, A, B = v["O"], v["A"], v["B"]

    print("=== 段级差异复核 ===")
    for key in A:
        if key not in O:
            print("  %-18s 仅 A 新增 → 取 A" % key)
            continue
        a_same, b_same = dump(O[key]) == dump(A[key]), dump(O.get(key)) == dump(B.get(key))
        if a_same and b_same:
            print("  %-18s 双侧未改 → 取 A" % key)
        elif a_same:
            print("  %-18s 仅 B 改 → 取 B%s" % (key, "" if key in TAKE_B else "  !! 未登记"))
        elif b_same:
            print("  %-18s 仅 A 改 → 取 A" % key)
        else:
            print("  %-18s 双侧都改 → 深合并%s" % (key, "" if key in DEEP_BY_MAP else "  !! 未登记"))
    for key in B:
        if key not in A:
            print("  %-18s 仅 B 有 → 需补入  !!" % key)

    # 以 A 为骨架(保留 A 的段序与 A线全部成果)
    out = {}
    for key in A:
        out[key] = A[key]

    for key in TAKE_B:
        assert key in B, "B 侧缺 %s" % key
        out[key] = B[key]

    for key in DEEP_BY_MAP:
        a_items = [it for it in A.get(key, []) if it.get("map") != 2]
        b_items = [it for it in B.get(key, []) if it.get("map") == 2]
        # A 侧 map0 条目若与 O 不同, 说明 A 改过 → 以 A 为准(B 的 map0 条目丢弃)
        b_map0 = [it for it in B.get(key, []) if it.get("map") != 2]
        o_map0 = [it for it in O.get(key, []) if it.get("map") != 2]
        if dump(b_map0) != dump(o_map0):
            print("  !! %s: B 侧也改了 map0 条目, 与 A 冲突, 需人工判定" % key)
            print("     O map0: %s" % dump(o_map0)[:200])
            print("     A map0: %s" % dump(a_items)[:200])
            print("     B map0: %s" % dump(b_map0)[:200])
        out[key] = a_items + b_items
        print("  %s 深合并: A 侧 %d 条(map!=2) + B 侧 %d 条(map2) = %d 条"
              % (key, len(a_items), len(b_items), len(out[key])))

    # 仅 B 有的段(理论上无)补入
    for key in B:
        if key not in out:
            out[key] = B[key]
            print("  补入仅 B 有的段: %s" % key)

    print("\n=== 合并结果校验 ===")
    ok = True
    for key in ("stairs", "partitions", "pickupOverrides", "enemyOverrides", "layers"):
        n = len(out.get(key, []))
        print("  A线段 %-18s %d 条 %s" % (key, n, "OK" if n else "!! 丢失"))
        ok = ok and n > 0
    m2 = [m for m in out["maps"] if m.get("map") == 2]
    print("  maps[2] 存在=%s buildings=%d groundZones=%d enemies=%d pickups=%d"
          % (bool(m2), len(m2[0].get("buildings", [])) if m2 else -1,
             len(m2[0].get("groundZones", [])) if m2 else -1,
             len(m2[0].get("enemies", [])) if m2 else -1,
             len(m2[0].get("pickups", [])) if m2 else -1))
    ok = ok and bool(m2) and len(m2[0].get("buildings", [])) > 0
    terr2 = [t for t in out["terrain"] if t.get("map") == 2]
    print("  terrain map2 条目 %d 条 %s" % (len(terr2), "OK" if terr2 else "!! 丢失"))
    ok = ok and len(terr2) > 0
    lay = out.get("layers", [])
    for ld in lay:
        print("  layers floor%s pickups=%d enemies=%d"
              % (ld.get("floor"), len(ld.get("pickups", [])), len(ld.get("enemies", []))))
    print("  pickupOverrides: %s" % [
        {"map": e.get("map"),
         "suppress": (len(e["suppress"]) if isinstance(e.get("suppress"), list) else 1)
         if e.get("suppress") else 0}
        for e in out.get("pickupOverrides", [])])
    print("  enemyOverrides: %s" % [
        {"map": e.get("map"), "suppress": len(e.get("suppress", [])),
         "place": len(e.get("place", []))} for e in out.get("enemyOverrides", [])])

    if not ok:
        raise SystemExit("!! 校验未通过, 拒绝落盘")
    if check_only:
        print("\n[--check] 未落盘")
        return

    text = json.dumps(out, ensure_ascii=False, indent=2) + "\r\n"
    with io.open(DST, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(text)
    print("\n已落盘 %s (%d 字符, %d 行)" % (REL, len(text), text.count("\n") + 1))
    # 回读自证
    back = json.load(io.open(DST, encoding="utf-8"))
    print("回读一致=%s 段数=%d" % (dump(back) == dump(out), len(back)))


if __name__ == "__main__":
    main()
