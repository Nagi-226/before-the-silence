# -*- coding: utf-8 -*-
"""A批8 · 补给/敌人跨楼层重平衡生成器(map0)。

用户实机反馈(三条):
1. 二三层补给太少(探针: 一层密度 5.26 个/百格 vs 二三层 0.32, 差 16 倍)
2. 外星孢子(id0)/人类寄生体宿主(id1) 往二三层摆一些(一层 1.46 只/百格 vs
   二层 0.08 / 三层 0.30, 差 18 倍——扩面 26 倍后敌人没跟上)
3. 一层补给过多, 匀往二三层

附带修正 A批7 平衡失误: h(生命上限升级, 消耗10金币 +20 上限, 无次数上限)
在二三层各撒了 11/10 个 → 全吃血上限 100→620。本批每层截断保留 3 个。

口径:
- 运行时坐标: MAPS split 后 rows[0] 空行跳过, y=行索引(与 A批7 生成器一致)
- 一层抑制走 pickupOverrides.suppress(数组格式) / enemyOverrides.suppress
- 二三层新增走 layers[].pickups(直给 symbol, 不经 H→e 平衡计数) /
  enemyOverrides.place(带 floor 抬升)
- 幂等: 新增条目打 "batch": 8 标记, 重跑先剔除本批产物再重算基线

运行: python godot/tools/gen_rebalance.py [--seed N]
输出: build/ab8_pickup_suppress.json, build/ab8_layer_pickups.json,
      build/ab8_enemy_overrides.json
"""
import io
import json
import os
import random
import re
import sys
from collections import Counter, deque

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_DATA = os.path.join(ROOT, "godot", "scripts", "levels", "LevelData.gd")
LEVEL_EXT = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
WEAPONS = os.path.join(ROOT, "godot", "assets", "config", "weapons.json")
OUT_DIR = os.path.join(ROOT, "build")

TOWER = (1, 17, 33, 14)          # x0,y0,w,h A批7 保留的旧塔楼区块(契约区, 不落新实体)
SPAWN = (4, 35)                  # 符号图 P 出生点
COURTYARD = (167, 26, 25, 13)    # 庭院 rect(通关区, 不动)
GOAL_FLAG = (179, 32)            # goals.flags 配置旗(庭院)
DATA_FLAG = (115, 48)            # 符号图 F(已被 suppressDataFlag 抑制, 保守避让)
STAIR_CELLS = [(31, 24), (32, 24), (31, 25), (32, 25),   # 楼梯1 footprint(1F/2F)
               (31, 21), (32, 21), (31, 22), (32, 22)]   # 楼梯2 footprint(2F/3F)
LANDINGS = {2: [(31, 23), (32, 23)], 3: [(31, 20), (32, 20)]}
TOWER_HOLES = {2: [(31, 24), (32, 24), (31, 25), (32, 25)],
               3: [(31, 21), (32, 21), (31, 22), (32, 22)]}
TOWER_DOORS = {2: [(4, 30), (5, 30), (22, 30), (23, 30), (33, 22), (33, 23)],
               3: [(20, 30), (21, 30), (30, 30), (31, 30), (33, 25), (33, 26)]}
WALK_1F = 7284                   # 一层室内可走面积(探针实测, 密度分母)

# ── 配额(设计定稿) ──────────────────────────────────────────────
SUP_PICKUPS = {"H": 48, "C": 89, "A": 52}   # 一层补给抑制格数
SUP_ENEMIES = {0: 8, 1: 32}                 # 一层敌人抑制格数(id0/id1)
NEW_PICKUPS = {                             # 二三层新增补给(按符号)
    2: [("C", 35), ("A", 28), ("H", 14), ("e", 9)],
    3: [("C", 38), ("A", 28), ("H", 16), ("e", 9), ("s", 3)],
}
NEW_ENEMIES = {                             # 二三层新增敌人(id, 只数)
    2: [(0, 14), (1, 24)],
    3: [(0, 16), (1, 19)],
}
H_KEEP = 3                                  # 每层 h 保留数(A批7 过量修正)
TOWER_GUARD = 5                             # 塔楼契约区外扩禁落敌带(格)
PICK_MIN_DIST = 4                           # 补给组内最小切比雪夫距离
ENEMY_MIN_DIST = {0: 5, 1: 4}               # 敌人组内最小距离(id0 远程, 间隔略大)
BUCKET = 14                                 # 一层抑制抽样分桶边长(空间均匀)


def extract_map0_rows():
    src = io.open(LEVEL_DATA, encoding="utf-8").read()
    m = re.search(r"const MAPS := \[\s*\"\"\"(.*?)\"\"\"", src, re.S)
    if not m:
        raise SystemExit("MAPS map0 提取失败")
    return [r.rstrip("\r") for r in m.group(1).split("\n")]


def in_tower(x, y):
    tx, ty, tw, th = TOWER
    return tx <= x < tx + tw and ty <= y < ty + th


def near(cells, x, y, r):
    """(x,y) 是否落在 cells 中任一点的切比雪夫 r 邻域内。"""
    return any(max(abs(x - cx), abs(y - cy)) <= r for cx, cy in cells)


def cheb(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def protected_1f(ext, weapons):
    """一层抑制格保护集: 出生区/垂直动线/通关区/既有配置实体周边不动。"""
    keep = []
    keep.append((SPAWN, 6, "出生点"))
    keep.append((DATA_FLAG, 3, "符号图旗"))
    keep.append((GOAL_FLAG, 5, "庭院终点旗"))
    tx, ty, tw, th = COURTYARD
    for yy in range(ty, ty + th):
        for xx in range(tx, tx + tw):
            keep.append(((xx, yy), 0, "庭院"))
    for c in STAIR_CELLS:
        keep.append((c, 3, "楼梯"))
    for s in weapons.get("shellSpawns", []):
        if s.get("map") == 0:
            keep.append(((s["x"], s["y"]), 2, "霰弹补给"))
    for s in weapons.get("upgradeComponents", {}).get("spawns", []):
        if s.get("map") == 0:
            keep.append(((s["x"], s["y"]), 2, "升级组件"))
    for e in ext.get("pickupOverrides", []):
        if e.get("map") == 0 and "A批8" not in str(e.get("_comment", "")) \
                and isinstance(e.get("place"), dict):
            p = e["place"]
            keep.append(((p.get("x"), p.get("y")), 2, "pickupOverrides.place"))
    for ld in ext.get("layers", []):
        if ld.get("map") == 0:
            for p in ld.get("pickups", []):
                # 幂等: 本批(batch=8)产物不当保护集, 否则重跑候选逐轮萎缩
                if p.get("batch") == 8:
                    continue
                keep.append(((p["x"], p["y"]), 1, "层拾取"))
            for e2 in ld.get("enemies", []):
                keep.append(((e2["x"], e2["y"]), 1, "层敌人"))
    return keep


def is_protected(keep, x, y):
    if in_tower(x, y):
        return True
    for (c, r, _tag) in keep:
        if c[0] is None:
            continue
        if cheb(c, (x, y)) <= r:
            return True
    return False


def bucketed_sample(rng, cells, count):
    """分桶轮转抽取: 每 BUCKET×BUCKET 桶轮流取一个 → 空间均匀, 不局部抽空。"""
    buckets = {}
    for c in cells:
        buckets.setdefault((c[0] // BUCKET, c[1] // BUCKET), []).append(c)
    keys = sorted(buckets)
    for k in keys:
        rng.shuffle(buckets[k])
    out = []
    while len(out) < count:
        progressed = False
        for k in keys:
            if buckets[k]:
                out.append(buckets[k].pop())
                progressed = True
                if len(out) == count:
                    break
        if not progressed:
            break
    return out


def layer_walkable(ld):
    """层可走格集(grid 空格 − slabHoles), 以及 BFS 自楼梯落点的可达集。"""
    grid = ld["grid"]
    holes = {(h["x"], h["y"]) for h in ld.get("slabHoles", [])}
    walk = {(x, y) for y, row in enumerate(grid) for x, ch in enumerate(row)
            if ch == " " and (x, y) not in holes}
    f = ld["floor"]
    seen = set(LANDINGS[f])
    q = deque(LANDINGS[f])
    while q:
        cx, cy = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (cx + dx, cy + dy)
            if n in seen or n not in walk:
                continue
            seen.add(n)
            q.append(n)
    return walk, seen


def pick_grouped(rng, pool, groups, min_dist_map, blocked, taken):
    """分组落点: 组内两两 ≥min_dist, 组间仅要求不同格(taken 累积)。
    返回 [(coord, tag), ...]; 不足配额时抛断言(便于调参)。"""
    out = []
    for tag, count in groups:
        md = min_dist_map if isinstance(min_dist_map, int) else min_dist_map[tag]
        cand = [c for c in pool if c not in blocked and c not in taken]
        rng.shuffle(cand)
        got = []
        for c in cand:
            if all(cheb(c, o) >= md for o in got):
                got.append(c)
                if len(got) == count:
                    break
        assert len(got) == count, "落点不足 %s: %d/%d (可放 %d)" % (
            tag, len(got), count, len(cand))
        for c in got:
            taken.add(c)
            out.append((c, tag))
    return out


def baseline_pickups(ld):
    """幂等基线: 剔除本批(batch=8)产物 + h 截断保留前 H_KEEP(按 y,x 排序)。"""
    ps = [p for p in ld.get("pickups", []) if p.get("batch") != 8]
    hs = sorted([p for p in ps if p.get("symbol") == "h"],
                key=lambda p: (p["y"], p["x"]))
    drop = {id(p) for p in hs[H_KEEP:]}
    return [p for p in ps if id(p) not in drop], len(hs)


def prior_overrides(ext):
    """既有(非本批) overrides 的抑制格与放置补给 → 权威净存量口径。

    A批5 pickupOverrides: suppress (153,31) + place (150,31) H
    A批7 enemyOverrides: suppress 30 格 id2 + place 30 只 id2(2/3层)
    这些在运行时与本批叠加生效, 模拟必须一并计入。
    """
    sup_pick, sup_enemy, place_pick = set(), set(), []
    for e in ext.get("pickupOverrides", []):
        if e.get("map") != 0 or "A批8" in str(e.get("_comment", "")):
            continue
        s = e.get("suppress", {})
        items = s if isinstance(s, list) else ([s] if s else [])
        for it in items:
            sup_pick.add((it["x"], it["y"]))
        p = e.get("place")
        if isinstance(p, dict):
            place_pick.append((p["x"], p["y"], p["symbol"]))
    for e in ext.get("enemyOverrides", []):
        if e.get("map") != 0 or "A批8" in str(e.get("_comment", "")):
            continue
        for it in e.get("suppress", []):
            sup_enemy.add((it["x"], it["y"]))
    return sup_pick, sup_enemy, place_pick


def main():
    seed = 20260908
    args = sys.argv[1:]
    for i, a in enumerate(args):
        if a == "--seed":
            seed = int(args[i + 1])
    rng = random.Random(seed)
    rows = extract_map0_rows()
    ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"))
    weapons = json.load(io.open(WEAPONS, encoding="utf-8"))
    os.makedirs(OUT_DIR, exist_ok=True)

    # ── 一层: 候选收集 + 保护集过滤 + 分桶抽样 ──────────────────
    keep = protected_1f(ext, weapons)
    prior_pick, prior_enemy, prior_place = prior_overrides(ext)
    cand = {k: [] for k in list(SUP_PICKUPS) + ["0", "1"]}
    for y in range(1, len(rows)):
        for x, ch in enumerate(rows[y]):
            if ch not in cand:
                continue
            if is_protected(keep, x, y) or (x, y) in prior_pick \
                    or (x, y) in prior_enemy:
                continue
            cand[ch].append((x, y))

    print("=== 一层候选(已排除保护集) ===")
    for ch in ("H", "C", "A", "0", "1"):
        quota = SUP_PICKUPS[ch] if ch in SUP_PICKUPS else SUP_ENEMIES[int(ch)]
        print("  %s: 候选 %d, 配额 %d" % (ch, len(cand[ch]), quota))

    sup_picks = []
    for ch, n in SUP_PICKUPS.items():
        assert len(cand[ch]) >= n, "一层 %s 候选 %d < 配额 %d" % (ch, len(cand[ch]), n)
        got = bucketed_sample(rng, cand[ch], n)
        assert len(got) == n, "%s 分桶抽样仅得 %d/%d" % (ch, len(got), n)
        sup_picks += [(c, ch) for c in got]
    sup_enems = []
    for tid, n in SUP_ENEMIES.items():
        ch = str(tid)
        assert len(cand[ch]) >= n, "一层 id%d 候选 %d < 配额 %d" % (tid, len(cand[ch]), n)
        got = bucketed_sample(rng, cand[ch], n)
        assert len(got) == n, "id%d 分桶抽样仅得 %d/%d" % (tid, len(got), n)
        sup_enems += [(c, tid) for c in got]

    # 抑制后一层净存量(H 走"每第4个转e"运行时折算); 既有 A批5/A批7 抑制同计
    sup_cells = {c for c, _ in sup_picks} | {c for c, _ in sup_enems} \
        | prior_pick | prior_enemy
    net = Counter()
    hs = 0
    for y in range(1, len(rows)):
        for x, ch in enumerate(rows[y]):
            if (x, y) in sup_cells:
                continue
            if ch == "H":
                hs += 1
                net["e" if hs % 4 == 0 else "H"] += 1
            elif ch in "aw":
                net["e"] += 1
            elif ch in "CAh":
                net[ch] += 1
    for _px, _py, sym in prior_place:      # A批5 place 不经符号扫描, 不参与折算
        net[sym] += 1
    enem1 = Counter()
    for y in range(1, len(rows)):
        for x, ch in enumerate(rows[y]):
            if ch in "012" and (x, y) not in sup_cells:
                enem1[ch] += 1

    # ── 二三层: 新增补给 + 敌人落点 ─────────────────────────────
    new_pickups = {}
    new_enemies = {}
    base_summary = {}
    for ld in ext.get("layers", []):
        if ld.get("map") != 0:
            continue
        f = ld["floor"]
        base, h_total = baseline_pickups(ld)
        walk, reach = layer_walkable(ld)
        assert walk == reach, "F%d 可走格非全连通(缺口 %d)" % (f, len(walk - reach))
        # 新区可走格: 排除塔楼契约区(宝库/镇守敌不动)
        pool = sorted(c for c in walk if not in_tower(*c))
        blocked = set(LANDINGS[f]) | set(TOWER_DOORS[f]) | set(TOWER_HOLES[f])
        for c in STAIR_CELLS:
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    blocked.add((c[0] + dx, c[1] + dy))
        taken = set()
        for p in base:
            taken.add((p["x"], p["y"]))
        for e in ld.get("enemies", []):
            taken.add((e["x"], e["y"]))
        for eo in ext.get("enemyOverrides", []):
            if eo.get("map") == 0 and "A批8" not in str(eo.get("_comment", "")):
                for p in eo.get("place", []):
                    if p.get("floor") == f:
                        taken.add((p["x"], p["y"]))

        # 补给: 允许贴近门洞(上楼即见补给), 仅避楼梯 footprint
        pk = pick_grouped(rng, pool, NEW_PICKUPS[f], PICK_MIN_DIST,
                          blocked, set(taken))
        # 敌人: 上楼层安全区——楼梯落点 4 格内 / 门洞 3 格内不落敌(防上楼被围)
        eblocked = set(blocked) | set(taken) | {c for c, _ in pk}
        for c in LANDINGS[f]:
            for dy in range(-4, 5):
                for dx in range(-4, 5):
                    eblocked.add((c[0] + dx, c[1] + dy))
        for c in TOWER_DOORS[f]:
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    eblocked.add((c[0] + dx, c[1] + dy))
        # 塔楼宝库周遭禁落新敌: W/T/U/s 与镇守敌均在契约区内, SmokeTest 会传送
        # 到这些位验拾取数值——外扩 5 格(≈13m)防新敌贴脸干扰断言
        tx, ty, tw, th = TOWER
        for yy in range(ty - TOWER_GUARD, ty + th + TOWER_GUARD):
            for xx in range(tx - TOWER_GUARD, tx + tw + TOWER_GUARD):
                eblocked.add((xx, yy))
        en = pick_grouped(rng, pool, NEW_ENEMIES[f], ENEMY_MIN_DIST,
                          eblocked, set())

        new_pickups[f] = [{"x": c[0], "y": c[1], "symbol": s, "batch": 8}
                          for c, s in pk]
        new_enemies[f] = [{"x": c[0], "y": c[1], "id": t, "floor": f, "batch": 8}
                          for c, t in en]
        # 落点必须可走且 BFS 可达
        for d in new_pickups[f] + new_enemies[f]:
            assert (d["x"], d["y"]) in reach, \
                "F%d 落点 (%d,%d) 不可达" % (f, d["x"], d["y"])
        base_summary[f] = {
            "base": Counter(p["symbol"] for p in base),
            "h_before": h_total, "walk": len(walk),
            "enemy_base": len(ld.get("enemies", [])) + sum(
                1 for eo in ext.get("enemyOverrides", [])
                if eo.get("map") == 0 and "A批8" not in str(eo.get("_comment", ""))
                for p in eo.get("place", []) if p.get("floor") == f),
        }

    # ── 报告 ────────────────────────────────────────────────────
    print("\n=== 一层(抑制 %d 补给 + %d 敌人) ===" % (len(sup_picks), len(sup_enems)))
    print("  补给净存量: H=%d e=%d C=%d A=%d h=%d s=4 → 合计 %d (密度 %.2f/百格)"
          % (net["H"], net["e"], net["C"], net["A"], net["h"],
             sum(net.values()) + 4, (sum(net.values()) + 4) / WALK_1F * 100))
    print("  敌人净存量: id0=%d id1=%d id2=%d → 合计 %d (密度 %.2f/百格)"
          % (enem1["0"], enem1["1"], enem1["2"], sum(enem1.values()),
             sum(enem1.values()) / WALK_1F * 100))
    for f in (2, 3):
        bs = base_summary[f]
        add = Counter(p["symbol"] for p in new_pickups[f])
        tot = bs["base"] + add
        ea = Counter(e["id"] for e in new_enemies[f])
        etot = bs["enemy_base"] + sum(ea.values())
        print("\n=== %d层(可走 %d 格) ===" % (f, bs["walk"]))
        print("  h 截断: %d → %d (A批7 过量修正)" % (bs["h_before"], H_KEEP))
        print("  补给: 基线 %s + 新增 %s → 合计 %d (密度 %.2f/百格)"
              % (dict(bs["base"]), dict(add), sum(tot.values()),
                 sum(tot.values()) / bs["walk"] * 100))
        print("       明细 %s" % dict(tot))
        print("  敌人: 基线 %d + 新增 %s → 合计 %d (密度 %.2f/百格)"
              % (bs["enemy_base"], dict(ea), etot, etot / bs["walk"] * 100))

    # ── 输出 ────────────────────────────────────────────────────
    pick_entry = {
        "_comment": ("A批8·一层补给减量匀往二三层(用户实机反馈: 一层密度 5.26 个/百格"
                     " vs 二三层 0.32, 差 16 倍)。suppress 为数组格式(A批8 扩展"
                     " _pickup_suppress_cells 兼容单格字典/数组): H×48 C×89 A×52"
                     " 共 189 格。抽样分桶轮转(14×14)保空间均匀; 保护集=出生点6格/"
                     "塔楼区块/楼梯3格/庭院/终点旗/霰弹点/组件/既有配置实体周边。"
                     "A批5 单格条目 (153,31) 原样保留(机制累加多 entry)。"),
        "map": 0,
        "suppress": [{"x": c[0], "y": c[1]} for c, _ in sup_picks],
    }
    enemy_entry = {
        "_comment": ("A批8·孢子囊(id0)/人类寄生体宿主(id1) 跨楼层布防(用户实机反馈:"
                     " 一层敌人密度 1.46 只/百格 vs 二层 0.08/三层 0.30, 扩面 26 倍"
                     "后敌人没跟上)。suppress: 一层 id0×8(28→20) id1×32(68→36),"
                     " id2 保持 A批7 的 10 只不动。place: 二层 id0×14+id1×24,"
                     " 三层 id0×16+id1×19 共 73 只(含匀来 40 + 净增 33 填充迷宫)。"
                     "落点全在 BFS 可达集; 楼梯落点 4 格/门洞 3 格内不落敌(上楼"
                     "安全区, 防刚上楼被围); 塔楼契约区排除(宝库镇守不动)。"
                     "batch=8 供 patch 脚本幂等剔除。"),
        "map": 0,
        "suppress": [{"x": c[0], "y": c[1]} for c, _ in sup_enems],
        "place": new_enemies[2] + new_enemies[3],
    }
    io.open(os.path.join(OUT_DIR, "ab8_pickup_suppress.json"), "w",
            encoding="utf-8").write(json.dumps(pick_entry, ensure_ascii=False, indent=1))
    io.open(os.path.join(OUT_DIR, "ab8_enemy_overrides.json"), "w",
            encoding="utf-8").write(json.dumps(enemy_entry, ensure_ascii=False, indent=1))
    io.open(os.path.join(OUT_DIR, "ab8_layer_pickups.json"), "w",
            encoding="utf-8").write(json.dumps(
                {str(f): new_pickups[f] for f in (2, 3)},
                ensure_ascii=False, indent=1))
    print("\n写出 build/ab8_pickup_suppress.json (抑制 %d 格)" % len(sup_picks))
    print("写出 build/ab8_enemy_overrides.json (抑制 %d + 布防 %d)"
          % (len(sup_enems), len(enemy_entry["place"])))
    print("写出 build/ab8_layer_pickups.json (2F +%d, 3F +%d)"
          % (len(new_pickups[2]), len(new_pickups[3])))


if __name__ == "__main__":
    main()
