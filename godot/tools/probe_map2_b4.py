# -*- coding: utf-8 -*-
"""B批4 探针: map2 事实全量导出 + 道具点缀候选格

用途: 为 B批4 的 T1 道具点缀(props)选落位格, 并核对 T5 环境差异化与文案终稿
所需的街区事实(建筑/马路/地形/敌人/拾取/信标/出生点)。

口径与 LevelGenerator._apply_ext_map 一致:
  wall = 围界环(borderWall) + 建筑周界环(buildings) - 门洞(door)
  groundZones = 纯视觉覆层(不进 wall_cells), 按 rect 标记路面材质
  terrain(platform/ramp) = 玩法几何(独立 StaticBody3D), 按 rect 标记高差区

只读, 不改任何文件。
"""
import io
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CFG = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
OUT = os.path.join(ROOT, "build", "probe_map2_b4_out.txt")


def load():
    with io.open(CFG, encoding="utf-8") as f:
        return json.load(f)


def map_cfg(cfg, m=2):
    for e in cfg.get("maps", []):
        if int(e.get("map", -1)) == m:
            return e
    return {}


def build_walls(c):
    w = int(c.get("width", 0))
    h = int(c.get("height", 0))
    walls = {}
    sym = (c.get("borderWall", {}) or {}).get("symbol", "S")
    for y in range(h):
        for x in range(w):
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                walls[(x, y)] = sym
    doors = set()
    for b in c.get("buildings", []):
        bx, by = int(b.get("x", 0)), int(b.get("y", 0))
        bw = max(2, int(b.get("w", 2)))
        bh = max(2, int(b.get("h", 2)))
        bsym = b.get("symbol", "X")
        d = b.get("door", {}) or {}
        side, pos, dw = str(d.get("side", "")), int(d.get("pos", -1)), max(0, int(d.get("w", 0)))
        for yy in range(by, by + bh):
            for xx in range(bx, bx + bw):
                if not (xx == bx or xx == bx + bw - 1 or yy == by or yy == by + bh - 1):
                    continue
                on_door = False
                if dw > 0 and side:
                    if side == "S":
                        on_door = yy == by + bh - 1 and bx + pos <= xx < bx + pos + dw
                    elif side == "N":
                        on_door = yy == by and bx + pos <= xx < bx + pos + dw
                    elif side == "W":
                        on_door = xx == bx and by + pos <= yy < by + pos + dw
                    elif side == "E":
                        on_door = xx == bx + bw - 1 and by + pos <= yy < by + pos + dw
                if on_door:
                    doors.add((xx, yy))
                    continue
                walls[(xx, yy)] = bsym
    return walls, doors


def rect_cells(r):
    x, y = int(r.get("x", 0)), int(r.get("y", 0))
    w, h = max(1, int(r.get("w", 1))), max(1, int(r.get("h", 1)))
    return [(xx, yy) for yy in range(y, y + h) for xx in range(x, x + w)]


def main():
    cfg = load()
    c = map_cfg(cfg)
    if not c:
        sys.exit("!! level_ext.maps 无 map=2 配置")
    W, H = int(c["width"]), int(c["height"])
    walls, doors = build_walls(c)

    zones = {}          # cell -> 贴图名(后写覆盖先写, 与生成器序号递增同序)
    zone_list = []
    for z in c.get("groundZones", []):
        r = z.get("rect", {}) or {}
        tex = os.path.basename(str(z.get("texture", "")))
        zone_list.append((r, tex))
        for cell in rect_cells(r):
            zones[cell] = tex

    terrain = {}        # cell -> (kind, height, base)
    terr_list = []
    for t in cfg.get("terrain", []):
        if int(t.get("map", -1)) != 2:
            continue
        # terrain 条目为 {"map":2, "platform"|"ramp": {x,y,w,h,height,...}};
        # 纯 _comment 条目(无 kind 键)跳过
        kind = "platform" if "platform" in t else ("ramp" if "ramp" in t else "")
        if not kind:
            continue
        body = t[kind] or {}
        tt = dict(body)
        tt["kind"] = kind
        terr_list.append(tt)
        for cell in rect_cells(body):
            terrain[cell] = (kind, float(body.get("height", 0.0)),
                             float(body.get("base", 0.0)))

    enemies = [(int(e.get("x")), int(e.get("y")), int(e.get("id", 0)),
                float(e.get("y_m", 0.0))) for e in c.get("enemies", [])]
    pickups = [(int(p.get("x")), int(p.get("y")), str(p.get("symbol", "")),
                float(p.get("y_m", 0.0))) for p in c.get("pickups", [])]
    sp = c.get("spawn", {}) or {}
    fl = c.get("flag", {}) or {}

    occupied = set(walls) | set(doors) | set(terrain)
    occupied |= {(e[0], e[1]) for e in enemies} | {(p[0], p[1]) for p in pickups}
    occupied |= {(int(sp.get("x", -1)), int(sp.get("y", -1))),
                 (int(fl.get("x", -1)), int(fl.get("y", -1)))}

    lines = []
    ap = lines.append
    ap("=" * 78)
    ap("map2 事实导出 (B批4 探针)")
    ap("=" * 78)
    ap("尺寸 %dx%d (outdoor=%s)  墙格 %d  门洞格 %d" %
       (W, H, c.get("outdoor"), len(walls), len(doors)))
    ap("出生点 (%s,%s)  信标旗 (%s,%s) y_m=%s" %
       (sp.get("x"), sp.get("y"), fl.get("x"), fl.get("y"), fl.get("y_m", 0)))
    ap("")
    ap("--- buildings (%d) ---" % len(c.get("buildings", [])))
    for i, b in enumerate(c.get("buildings", [])):
        d = b.get("door", {}) or {}
        ap("  B%d %-10s x=%-4s y=%-4s w=%-3s h=%-3s symbol=%s door(side=%s pos=%s w=%s) "
           "室内格=%d" % (i, str(b.get("name", ""))[:10], b.get("x"), b.get("y"),
                          b.get("w"), b.get("h"), b.get("symbol", "X"),
                          d.get("side", "-"), d.get("pos", "-"), d.get("w", 0),
                          (int(b.get("w", 2)) - 2) * (int(b.get("h", 2)) - 2)))
    ap("")
    ap("--- groundZones (%d) ---" % len(zone_list))
    for r, tex in zone_list:
        ap("  rect(x=%s y=%s w=%s h=%s) %s" % (r.get("x"), r.get("y"), r.get("w"),
                                              r.get("h"), tex))
    ap("")
    ap("--- terrain map2 (%d) ---" % len(terr_list))
    for t in terr_list:
        ap("  %-8s rect(x=%s y=%s w=%s h=%s) height=%s base=%s dir=%s tint=%s" %
           (t.get("kind"), t.get("x"), t.get("y"), t.get("w"), t.get("h"),
            t.get("height"), t.get("base", "-"), t.get("dir", "-"), t.get("tint", "-")))
    ap("")
    ap("--- enemies (%d) / pickups (%d) ---" % (len(enemies), len(pickups)))
    ap("  enemies: " + " ".join("(%d,%d id%d y%.1f)" % e for e in enemies))
    ap("  pickups: " + " ".join("(%d,%d %s y%.1f)" % p for p in pickups))
    ap("")

    # 道具候选格: 非墙/非门洞/非地形/无实体占用, 且不在沥青马路覆层上。
    # 封闭装饰体块(无 door)室内排除——道具放进去玩家看不见也进不去。
    asphalt = set()
    for cell, tex in zones.items():
        if "Asphalt" in tex or "Road" in tex or "asphalt" in tex:
            asphalt.add(cell)
    inner = {}          # cell -> 建筑序号
    sealed = set()      # 封闭装饰体块室内格
    for i, b in enumerate(c.get("buildings", [])):
        bx, by = int(b["x"]), int(b["y"])
        bw, bh = int(b["w"]), int(b["h"])
        has_door = int((b.get("door", {}) or {}).get("w", 0)) > 0
        for yy in range(by + 1, by + bh - 1):
            for xx in range(bx + 1, bx + bw - 1):
                inner[(xx, yy)] = i
                if not has_door:
                    sealed.add((xx, yy))
    cand_in = []        # 可进入建筑室内
    cand_open = []      # 室外开阔地(含人行道)
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            k = (x, y)
            if k in occupied or k in asphalt or k in sealed:
                continue
            if k in inner:
                cand_in.append(k)
            else:
                cand_open.append(k)
    # 分带统计(便于按设计意图选区)
    bands = [
        ("主街北人行道 y=39-40", lambda k: 39 <= k[1] <= 40),
        ("主街南人行道 y=45-46", lambda k: 45 <= k[1] <= 46),
        ("北侧街区空地 y=25-38", lambda k: 25 <= k[1] <= 38),
        ("北侧建筑前庭 y=1-24", lambda k: k[1] <= 24),
        ("南侧巷区 y=47-82", lambda k: k[1] >= 47),
    ]
    ap("--- 道具候选格(排除墙/门洞/地形/实体/沥青车道/封闭装饰体块室内) ---")
    ap("  可进入建筑室内 %d 格 / 室外开阔地 %d 格" % (len(cand_in), len(cand_open)))
    for name, pred in bands:
        n = sum(1 for k in cand_open if pred(k))
        ap("    %-26s %d 格" % (name, n))
    ap("  覆层贴图种类: %s" % sorted(set(zones.values())))
    ap("")

    # ASCII 全景: 每 2 格取样压到 70x42, 便于肉眼选区
    ap("--- ASCII 全景(1:1, %dx%d) ---" % (W, H))
    ap("图例: #墙 =沥青 ^地形 1-6可进入建筑室内 x封闭装饰体块 d门洞 E敌 P拾取 S出生 F旗 ' '=开阔地")
    bidx = {}
    for i, b in enumerate(c.get("buildings", [])):
        bx, by = int(b["x"]), int(b["y"])
        has_door = int((b.get("door", {}) or {}).get("w", 0)) > 0
        ch = str(i + 1) if has_door else "x"
        for yy in range(by, by + int(b["h"])):
            for xx in range(bx, bx + int(b["w"])):
                bidx[(xx, yy)] = ch
    emap = {(e[0], e[1]): "E" for e in enemies}
    pmap = {(p[0], p[1]): "P" for p in pickups}
    hdr = "    " + "".join(str((x // 10) % 10) if x % 10 == 0 else " " for x in range(W))
    ap(hdr)
    ap("    " + "".join(str(x % 10) for x in range(W)))
    for y in range(H):
        row = []
        for x in range(W):
            k = (x, y)
            if k == (int(sp.get("x", -1)), int(sp.get("y", -1))):
                row.append("S")
            elif k == (int(fl.get("x", -1)), int(fl.get("y", -1))):
                row.append("F")
            elif k in emap:
                row.append(emap[k])
            elif k in pmap:
                row.append(pmap[k])
            elif k in walls:
                row.append("#")
            elif k in doors:
                row.append("d")
            elif k in terrain:
                row.append("^")
            elif k in inner:
                row.append(bidx.get(k, "1"))
            elif k in asphalt:
                row.append("=")
            elif k in zones:
                row.append(",")
            else:
                row.append(" ")
        ap("%3d|%s|" % (y, "".join(row)))
    ap("")
    ap("--- 可进入建筑室内候选格(按建筑分组) ---")
    for i, b in enumerate(c.get("buildings", [])):
        if int((b.get("door", {}) or {}).get("w", 0)) <= 0:
            continue
        cells = [k for k in cand_in if inner.get(k) == i]
        ap("  B%d %s (%d 格): %s" % (i, b.get("name", ""), len(cells),
                                    " ".join("(%d,%d)" % t for t in sorted(cells))))
    ap("")
    ap("--- 室外开阔地候选格(按带分组) ---")
    for name, pred in bands:
        cells = [k for k in cand_open if pred(k)]
        ap("  [%s] %d 格" % (name, len(cells)))
        ap("    " + " ".join("(%d,%d)" % t for t in sorted(cells)))
        ap("")

    text = "\n".join(lines) + "\n"
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("已写出 %s (%d 行)" % (OUT, len(lines)))
    for ln in lines[:60]:
        print(ln)


if __name__ == "__main__":
    main()
