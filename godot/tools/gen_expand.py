# -*- coding: utf-8 -*-
"""A批7 · 二三层迷宫扩面生成器(map0)。

目标(用户拍板):
- 二三层可走面积 ≥ 一层室内全部可走面积(7284)的 70% = 5098 格
- 旧塔楼区块 (x1..33, y17..30) 原样保留(全部几何契约不动), 周界开门洞连通新区
- 迷宫式布局(房间格+门洞+立柱), BFS 自楼梯落点全连通
- 输出 level_ext.json 的 floor2/floor3 新 layers 块 + enemyOverrides(一层
  id2 精英 40→10, 30 只重布二三层, 主力三层)

口径:
- 运行时坐标: MAPS split 后 rows[0] 空行跳过, y=行索引(与生成器一致)
- 新层 rect = (0,0,168,62): 覆盖符号图全部内容行 y1..61 + 周界; y62..69
  为全墙岩体填充不加板(南天花板带兜底)。庭院在 x167..191 config 外扩区,
  rect 只到 x167(其正上方), 夜空/绿旗/外立面零影响。
- 周界环(x=0/x=167/y=0/y=61)全 X → 天花板四带宽 0, 一层室内顶板=最高层
  整块 7.8m("Ceiling" 节点名不变, P2a 断言兼容)。

运行: python godot/tools/gen_expand.py [--seed2 N] [--seed3 N]
输出: build/ab7_f2.json, build/ab7_f3.json, build/ab7_enemy_overrides.json
"""
import io
import json
import os
import random
import re
import sys
from collections import deque

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_DATA = os.path.join(ROOT, "godot", "scripts", "levels", "LevelData.gd")
LEVEL_EXT = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
OUT_DIR = os.path.join(ROOT, "build")
WALLS = set("XMSG")

RECT_X, RECT_Y, RECT_W, RECT_H = 0, 0, 168, 62
TOWER = (1, 17, 33, 14)  # x0,y0,w,h 旧塔楼区块(绝对格)
WALK_TARGET = 5098       # 7284 * 70%

# 楼梯落点(契约, 必须可走): F2=(31,23)(32,23) 楼梯1顶; F3=(31,20)(32,20) 楼梯2顶
LANDINGS = {2: [(31, 23), (32, 23)], 3: [(31, 20), (32, 20)]}
# 旧塔楼 slabHoles 原样保留
TOWER_HOLES = {2: [(31, 24), (32, 24), (31, 25), (32, 25)],
               3: [(31, 21), (32, 21), (31, 22), (32, 22)]}
# 塔楼周界门洞(开在旧 grid 周界墙上, 2格宽; 生成时验证原为墙且内侧可走)
# 选址依据旧 grid 实内容: F2 row13 可走段 x2-8/x10-15/x17-27/x29-32,
# col32 可走 y18-27; F3 row12 可走 x15-16/x19-26/x30-32, col32 可走 y18-29
TOWER_DOORS = {
    2: [(4, 30), (5, 30), (22, 30), (23, 30), (33, 22), (33, 23)],
    3: [(20, 30), (21, 30), (30, 30), (31, 30), (33, 25), (33, 26)],
}
# 一层 id2 精英 40 只: 保留 10(全图散布), 抑制 30 → 重布二三层(主力三层)
ID2_KEEP = [(44, 2), (148, 9), (50, 12), (73, 16), (30, 18),
            (96, 22), (15, 26), (154, 31), (120, 41), (115, 50)]


def extract_map0_rows():
    src = io.open(LEVEL_DATA, encoding="utf-8").read()
    m = re.search(r"const MAPS := \[\s*\"\"\"(.*?)\"\"\"", src, re.S)
    if not m:
        raise SystemExit("MAPS map0 提取失败")
    return [r.rstrip("\r") for r in m.group(1).split("\n")]


def load_old_tower_grids():
    """取塔楼区块 grid: 旧版(14行×33字)直接用; 已扩面版(62行全境)裁剪
    TOWER 子块——保幂等可重跑。"""
    ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"))
    tx, ty, tw, th = TOWER
    out = {}
    for layer in ext.get("layers", []):
        if layer.get("map") == 0 and layer.get("floor") in (2, 3):
            grid = layer["grid"]
            if len(grid) == th:
                out[layer["floor"]] = grid
            else:
                out[layer["floor"]] = [row[tx:tx + tw]
                                       for row in grid[ty:ty + th]]
    assert 2 in out and 3 in out, "旧塔楼 grid 缺失"
    return out


class Grid:
    def __init__(self):
        self.cells = [[" " for _ in range(RECT_W)] for _ in range(RECT_H)]

    def get(self, x, y):
        return self.cells[y][x]

    def set(self, x, y, ch):
        self.cells[y][x] = ch

    def in_tower(self, x, y):
        tx, ty, tw, th = TOWER
        return tx <= x < tx + tw and ty <= y < ty + th

    def paste_tower(self, old_grid):
        tx, ty, tw, th = TOWER
        assert len(old_grid) == th, "旧 grid 行数 %d != %d" % (len(old_grid), th)
        for gy, row in enumerate(old_grid):
            assert len(row) == tw, "旧 grid 行%d 宽 %d != %d" % (gy, len(row), tw)
            for gx, ch in enumerate(row):
                self.set(tx + gx, ty + gy, ch)

    def carve_tower_doors(self, floor_n):
        for (x, y) in TOWER_DOORS[floor_n]:
            # 幂等: 裁剪自已扩面配置时门洞已开(空格), 只验内侧可走
            assert self.get(x, y) in WALLS or self.get(x, y) == " ", \
                "门洞 (%d,%d) 原非墙(F%d)?" % (x, y, floor_n)
            self.set(x, y, " ")
            # 门洞内侧(塔内方向)必须可走, 否则开洞无意义
            tx, ty, tw, th = TOWER
            if y == ty:          inside = (x, y + 1)
            elif y == ty + th - 1: inside = (x, y - 1)
            elif x == tx:        inside = (x + 1, y)
            else:                inside = (x - 1, y)
            assert self.get(*inside) not in WALLS, \
                "门洞 (%d,%d) 内侧 %s 是墙(F%d)" % (x, y, inside, floor_n)

    def perimeter(self):
        for x in range(RECT_W):
            self.set(x, 0, "X")
            self.set(x, RECT_H - 1, "X")
        for y in range(RECT_H):
            self.set(0, y, "X")
            self.set(RECT_W - 1, y, "X")

    def gen_maze(self, rng):
        """新区(非塔楼)迷宫: 抖动墙线切房间 + 每墙段门洞 + 稀疏立柱。"""
        # 竖向墙线 x≈13,27,...,155(±2 抖动), 横向墙线 y≈9,18,...,56(±2)
        vlines, hlines = [], []
        x = 13
        while x < RECT_W - 12:
            vlines.append(x + rng.randint(-2, 2))
            x += 14
        y = 9
        while y < RECT_H - 5:
            hlines.append(y + rng.randint(-2, 2))
            y += 9
        for vx in vlines:
            for y in range(1, RECT_H - 1):
                if not self.in_tower(vx, y) and self.get(vx, y) == " ":
                    self.set(vx, y, "X")
        for hy in hlines:
            for x in range(1, RECT_W - 1):
                if not self.in_tower(x, hy) and self.get(x, hy) == " ":
                    self.set(x, hy, "X")
        # 门洞: 每相邻墙线间墙段开 2格宽门 1-2 个; 候选需门两侧(垂直墙线
        # 方向)至少一侧可走——防墙线贴塔楼时把门开在塔楼周界墙上(契约漂移)
        def seg_door(cells, vertical):
            cand = []
            for c in cells:
                if self.get(*c) != "X":
                    continue
                x, y = c
                if vertical:
                    sides = [(x - 1, y), (x + 1, y)]
                else:
                    sides = [(x, y - 1), (x, y + 1)]
                if any(self.get(sx, sy) == " " and not self.in_tower(sx, sy)
                       for sx, sy in sides):
                    cand.append(c)
            if len(cand) < 3:
                return
            n = rng.randint(1, 2) if len(cand) >= 8 else 1
            for _ in range(n):
                i = rng.randrange(0, len(cand) - 1)
                self.set(*cand[i], " ")
                self.set(*cand[i + 1], " ")
        bounds_v = [1] + vlines + [RECT_W - 1]
        bounds_h = [1] + hlines + [RECT_H - 1]
        for vx in vlines:
            for a, b in zip(bounds_h[:-1], bounds_h[1:]):
                seg_door([(vx, yy) for yy in range(a, b)], True)
        for hy in hlines:
            for a, b in zip(bounds_v[:-1], bounds_v[1:]):
                seg_door([(xx, hy) for xx in range(a, b)], False)
        # 立柱: 房间内稀疏 1x1 柱(掩体/视觉/迷宫感), 3x3 邻域全空才落
        for _ in range(700):
            x, y = rng.randrange(2, RECT_W - 2), rng.randrange(2, RECT_H - 2)
            if self.in_tower(x, y) or self.get(x, y) != " ":
                continue
            if all(self.get(x + dx, y + dy) == " "
                   for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                self.set(x, y, "X")

    def walkable(self):
        return [(x, y) for y in range(RECT_H) for x in range(RECT_W)
                if self.get(x, y) == " "]

    def bfs(self, seeds, holes):
        seen = set(seeds)
        q = deque(seeds)
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n in seen or not (0 <= n[0] < RECT_W and 0 <= n[1] < RECT_H):
                    continue
                if n in holes or self.get(*n) in WALLS:
                    continue
                seen.add(n)
                q.append(n)
        return seen

    def repair(self, seeds, holes, rng, budget=400):
        """BFS 不达全连通时挖墙修复: 从不可达区向可达区方向开洞。"""
        for _ in range(budget):
            walk = set(self.walkable()) - holes
            reach = self.bfs(seeds, holes)
            unreach = walk - reach
            if not unreach:
                return True
            ur = rng.choice(sorted(unreach))
            # 找 ur 邻近(2格内)的可达格, 打通中间墙(绝不碰塔楼区块)
            fixed = False
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    tgt = (ur[0] + dx, ur[1] + dy)
                    if tgt in reach:
                        mx, my = ur[0] + (dx // 2 if abs(dx) > 1 else dx), \
                                 ur[1] + (dy // 2 if abs(dy) > 1 else dy)
                        if self.get(mx, my) == "X" and not self.in_tower(mx, my) \
                                and not self.in_tower(*ur) and not self.in_tower(*tgt):
                            self.set(mx, my, " ")
                            fixed = True
                            break
                if fixed:
                    break
            if not fixed:
                return False
        return False

    def dump_rows(self):
        return ["".join(row) for row in self.cells]


def pick_spots(rng, candidates, count, min_dist, blocked):
    """从候选格挑 count 个, 两两 ≥min_dist 且避开 blocked 集。"""
    out = []
    pool = [c for c in candidates if c not in blocked]
    rng.shuffle(pool)
    for c in pool:
        if all(max(abs(c[0] - o[0]), abs(c[1] - o[1])) >= min_dist for o in out):
            out.append(c)
            if len(out) == count:
                break
    return out


def main():
    seed2 = seed3 = None
    args = sys.argv[1:]
    for i, a in enumerate(args):
        if a == "--seed2":
            seed2 = int(args[i + 1])
        elif a == "--seed3":
            seed3 = int(args[i + 1])
    rng2 = random.Random(seed2 if seed2 is not None else 20260902)
    rng3 = random.Random(seed3 if seed3 is not None else 20260903)
    old = load_old_tower_grids()
    os.makedirs(OUT_DIR, exist_ok=True)

    # id2 抑制清单: 直接从 MAPS 重算(探针同口径), 40 - 保留10 = 抑制30
    rows = extract_map0_rows()
    id2_all = [(x, y) for y in range(1, len(rows))
               for x, ch in enumerate(rows[y]) if ch == "2"]
    suppress = [p for p in id2_all if p not in ID2_KEEP]
    assert len(id2_all) == 40 and len(suppress) == 30, \
        "id2 清单 %d/抑制 %d != 40/30" % (len(id2_all), len(suppress))

    layers_out = {}
    for floor_n, rng in ((2, rng2), (3, rng3)):
        g = Grid()
        g.perimeter()
        g.paste_tower(old[floor_n])
        g.carve_tower_doors(floor_n)
        g.gen_maze(rng)
        holes = set(TOWER_HOLES[floor_n])
        seeds = LANDINGS[floor_n]
        for s in seeds:
            assert g.get(*s) not in WALLS, "楼梯落点 %s 不可走(F%d)" % (s, floor_n)
        if not g.repair(seeds, holes, rng):
            raise SystemExit("F%d 连通修复失败" % floor_n)
        walk = set(g.walkable()) - holes
        reach = g.bfs(seeds, holes)
        assert walk == reach, "F%d BFS 缺口 %d" % (floor_n, len(walk - reach))
        # 契约格验证: 塔楼区块除门洞外与旧 grid 逐格一致
        tx, ty, tw, th = TOWER
        doors = set(TOWER_DOORS[floor_n])
        for gy in range(th):
            for gx in range(tw):
                ax, ay = tx + gx, ty + gy
                if (ax, ay) in doors:
                    continue
                assert g.get(ax, ay) == old[floor_n][gy][gx], \
                    "塔楼契约格 (%d,%d) 漂移(F%d)" % (ax, ay, floor_n)
        n_walk = len(walk)
        pct = 100.0 * n_walk / 7284
        print("F%d: 可走 %d 格 (%.1f%% of 7284, 目标≥%d) 墙 %d 板洞 %d"
              % (floor_n, n_walk, pct, WALK_TARGET,
                 sum(1 for y in range(RECT_H) for x in range(RECT_W)
                     if g.get(x, y) in WALLS), len(holes)))
        assert n_walk >= WALK_TARGET, "F%d 可走 %d < %d" % (floor_n, n_walk, WALK_TARGET)

        # 实体布点: 新区(非塔楼)可走格, 远离落点/门洞/彼此。
        # 补给组合 h×10/A×10/e×4(每层): 8400格大迷宫需足够补给;
        # e 计数动 SmokeTest 断言(37→41+4=45), h/A 不碰既有 H/e/s 口径
        new_area = sorted(walk - {c for c in walk if g.in_tower(*c)})
        blocked = set(seeds) | doors | holes
        pickups = pick_spots(rng, new_area, 24, 8, blocked)
        assert len(pickups) == 24, "F%d 补给落点不足 %d" % (floor_n, len(pickups))
        psym = ["h"] * 10 + ["A"] * 10 + ["e"] * 4
        rng.shuffle(psym)
        layer_pickups = [{"x": c[0], "y": c[1], "symbol": s}
                         for c, s in zip(pickups, psym)]
        layers_out[floor_n] = {
            "grid": g.dump_rows(), "pickups": layer_pickups,
            "new_area": new_area, "blocked": blocked, "rng": rng,
        }

    # id2 重布: 24 → F3, 6 → F2(enemyOverrides.place, 生成器 floor 抬升)
    place = []
    for floor_n, cnt in ((3, 24), (2, 6)):
        st = layers_out[floor_n]
        spots = pick_spots(st["rng"], st["new_area"], cnt, 10,
                           st["blocked"] | {tuple((p["x"], p["y"]))
                                            for p in st["pickups"]})
        assert len(spots) == cnt, "F%d 精英落点不足 %d/%d" % (floor_n, len(spots), cnt)
        for c in spots:
            place.append({"x": c[0], "y": c[1], "id": 2, "floor": floor_n})
    overrides = {
        "_comment": ("A批7·一层精英突变体减量重布(用户拍板): 符号图 id2 40只 抑制30"
                     " 保留10(全图散布); 30只重布二三层(24×3F+6×2F, 层板顶抬升由"
                     " floor 参数驱动 _layer_base_height)。suppress=符号扫描跳过该格"
                     " 敌人; place=按坐标直给落敌。"),
        "map": 0,
        "suppress": [{"x": p[0], "y": p[1]} for p in suppress],
        "place": place,
    }

    # 输出: 层块(不含 _comment, patch 脚本补) + enemyOverrides
    for floor_n in (2, 3):
        st = layers_out[floor_n]
        block = {
            "map": 0, "floor": floor_n,
            "baseHeight": 2.6 if floor_n == 2 else 5.2,
            "rect": {"x": RECT_X, "y": RECT_Y, "w": RECT_W, "h": RECT_H},
            "grid": st["grid"],
            "slabHoles": [{"x": c[0], "y": c[1]} for c in TOWER_HOLES[floor_n]],
            "pickups": st["pickups"],
        }
        # 旧塔楼实体(enemies + 宝库 pickups)原样并入。幂等: 已扩面配置里
        # pickups 含上一轮新区补给, 只保留塔楼区块内的(宝库), 防重跑叠加
        tx, ty, tw, th = TOWER

        def _in_tower(p):
            return tx <= p["x"] < tx + tw and ty <= p["y"] < ty + th

        ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"))
        for layer in ext.get("layers", []):
            if layer.get("map") == 0 and layer.get("floor") == floor_n:
                block["enemies"] = layer.get("enemies", [])
                block["pickups"] = [p for p in layer.get("pickups", [])
                                    if _in_tower(p)] + st["pickups"]
        out = os.path.join(OUT_DIR, "ab7_f%d.json" % floor_n)
        io.open(out, "w", encoding="utf-8").write(
            json.dumps(block, ensure_ascii=False, indent=1))
        print("写出 %s (grid %d行×%d字符)" % (out, len(block["grid"]), RECT_W))
    out = os.path.join(OUT_DIR, "ab7_enemy_overrides.json")
    io.open(out, "w", encoding="utf-8").write(
        json.dumps(overrides, ensure_ascii=False, indent=1))
    print("写出 %s (抑制%d + 重布%d)" % (out, len(suppress), len(place)))


if __name__ == "__main__":
    main()
