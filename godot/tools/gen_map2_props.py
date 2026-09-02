# -*- coding: utf-8 -*-
"""B批4·T1: map2 城区街道道具点缀——落位校验 + props 配置片段生成

设计意图(与规划 §4.2 T1 / §4.3 呼应):
  路灯 Streetlamp  主街两侧人行道等距(北 row40 / 南 row45, 错开半间距)——街道骨架
  枯树 Deadtree    北侧街区与南侧巷区开阔地——城郊凌晨剪影
  木箱 Crate       三座可进入建筑门外两侧 + 室内——转运链叙事呼应(不堵门洞)
  瓦砾 Rubble      街区空地与巷区散布——废墟破败感

校验口径与 LevelGenerator._apply_ext_map 一致(同 probe_map2_b4.py):
  wall      = 围界环 + 建筑周界环 - 门洞
  asphalt   = groundZones 中 Road/Asphalt 覆层格(道具压车道会被车流感排斥)
  terrain   = platform/ramp 高差区(道具落在坡面上会悬空或穿模)
  sealed    = 无 door 的封闭装饰体块室内(放进去玩家看不见也进不去)
  occupied  = 敌人/拾取/出生点/信标旗所在格(避免视觉重叠)

props 为纯布景: Sprite3D billboard, 不建碰撞、不登记 wall_cells → 玩法零侵入。

用法:
  python gen_map2_props.py           # 只校验 + 写 build/map2_props_snippet.json
  python gen_map2_props.py --apply   # 校验通过后并入 level_ext.json(幂等, 重跑不叠加)

落盘口径与 merge_level_ext.py 一致: json.dumps(ensure_ascii=False, indent=2) + CRLF。
"""
import io
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CFG = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
OUT = os.path.join(ROOT, "build", "map2_props_snippet.json")

SP_LAMP = "res://assets/sprites/Prop Streetlamp.png"
SP_TREE = "res://assets/sprites/Prop Deadtree.png"
SP_CRATE = "res://assets/sprites/Prop Crate.png"
SP_RUBBLE = "res://assets/sprites/Prop Rubble.png"

# (sprite, scale, x, y, 备注)
CANDIDATES = [
    # --- 路灯: 主街北人行道 row40, 间隔 22 格(44m) ---
    (SP_LAMP, 0.95, 10, 40, "主街北人行道"),
    (SP_LAMP, 0.95, 32, 40, "主街北人行道"),
    (SP_LAMP, 0.95, 54, 40, "主街北人行道"),
    (SP_LAMP, 0.95, 76, 40, "主街北人行道"),
    (SP_LAMP, 0.95, 98, 40, "主街北人行道"),
    (SP_LAMP, 0.95, 120, 40, "主街北人行道·土丘西侧"),
    # --- 路灯: 主街南人行道 row45, 与北侧错开半间距 ---
    (SP_LAMP, 0.95, 21, 45, "主街南人行道"),
    (SP_LAMP, 0.95, 43, 45, "主街南人行道"),
    (SP_LAMP, 0.95, 65, 45, "主街南人行道"),
    (SP_LAMP, 0.95, 87, 45, "主街南人行道"),
    (SP_LAMP, 0.95, 109, 45, "主街南人行道"),
    (SP_LAMP, 0.95, 131, 45, "主街南人行道·东南端"),
    # --- 枯树: 北侧街区开阔地 ---
    (SP_TREE, 1.05, 52, 12, "转运站与次街A之间"),
    (SP_TREE, 1.05, 42, 18, "转运站东侧空地"),
    (SP_TREE, 1.05, 86, 20, "便利店与次街B之间"),
    (SP_TREE, 1.05, 104, 26, "次街B东·派出所西"),
    # --- 枯树: 南侧巷区 ---
    (SP_TREE, 1.05, 6, 66, "装饰D1西侧"),
    (SP_TREE, 1.05, 36, 76, "南巷C东·废墟坡地南"),
    (SP_TREE, 1.05, 90, 78, "装饰D3南侧"),
    (SP_TREE, 1.05, 120, 60, "东南巷区"),
    # --- 木箱: 三座可进入建筑门外两侧(不堵门洞) ---
    (SP_CRATE, 0.55, 15, 26, "转运站门外西"),
    (SP_CRATE, 0.55, 18, 26, "转运站门外东"),
    (SP_CRATE, 0.55, 72, 20, "便利店门外西"),
    (SP_CRATE, 0.55, 75, 20, "便利店门外东"),
    (SP_CRATE, 0.55, 117, 32, "派出所门外西"),
    (SP_CRATE, 0.55, 120, 32, "派出所门外东"),
    # --- 木箱: 主街西段(出生点方向, 暗示转运链起点) ---
    (SP_CRATE, 0.55, 8, 46, "主街西段南缘"),
    (SP_CRATE, 0.55, 26, 46, "主街西段南缘"),
    # --- 木箱: 建筑室内(货运残留) ---
    (SP_CRATE, 0.55, 11, 13, "转运站室内西北"),
    (SP_CRATE, 0.55, 19, 12, "转运站室内东北"),
    (SP_CRATE, 0.55, 21, 20, "转运站室内东南"),
    (SP_CRATE, 0.55, 71, 15, "便利店室内西南"),
    (SP_CRATE, 0.55, 114, 17, "派出所室内西"),
    (SP_CRATE, 0.55, 121, 23, "派出所室内东南"),
    # --- 瓦砾: 北侧街区空地 ---
    (SP_RUBBLE, 0.5, 30, 30, "转运站东南空地"),
    (SP_RUBBLE, 0.5, 48, 28, "北侧街区中段"),
    (SP_RUBBLE, 0.5, 66, 30, "次街A东"),
    (SP_RUBBLE, 0.5, 88, 28, "便利店南空地"),
    (SP_RUBBLE, 0.5, 108, 36, "派出所西南"),
    (SP_RUBBLE, 0.5, 122, 36, "派出所南·土丘西"),
    # --- 瓦砾: 南侧巷区 ---
    (SP_RUBBLE, 0.5, 16, 48, "装饰D1北侧"),
    (SP_RUBBLE, 0.5, 48, 50, "装饰D2北侧"),
    (SP_RUBBLE, 0.5, 64, 60, "D2与南巷D之间"),
    (SP_RUBBLE, 0.5, 78, 52, "南巷D东"),
    (SP_RUBBLE, 0.5, 106, 48, "装饰D3东北"),
    (SP_RUBBLE, 0.5, 112, 70, "东南巷区"),
    (SP_RUBBLE, 0.5, 126, 52, "东南巷区"),
    (SP_RUBBLE, 0.5, 134, 66, "东南角"),
]


def load():
    with io.open(CFG, encoding="utf-8") as f:
        return json.load(f)


def map_cfg(cfg, m=2):
    for e in cfg.get("maps", []):
        if int(e.get("map", -1)) == m:
            return e
    return {}


def rect_cells(r):
    x, y = int(r.get("x", 0)), int(r.get("y", 0))
    w, h = max(1, int(r.get("w", 1))), max(1, int(r.get("h", 1)))
    return [(xx, yy) for yy in range(y, y + h) for xx in range(x, x + w)]


def build_sets(cfg, c):
    w, h = int(c["width"]), int(c["height"])
    walls = set()
    sym = (c.get("borderWall", {}) or {}).get("symbol", "S")
    for y in range(h):
        for x in range(w):
            if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                walls.add((x, y))
    doors, inner, sealed = set(), {}, set()
    for i, b in enumerate(c.get("buildings", [])):
        bx, by = int(b["x"]), int(b["y"])
        bw, bh = int(b["w"]), int(b["h"])
        d = b.get("door", {}) or {}
        side, pos = str(d.get("side", "")), int(d.get("pos", -1))
        dw = max(0, int(d.get("w", 0)))
        for yy in range(by, by + bh):
            for xx in range(bx, bx + bw):
                on_ring = (xx == bx or xx == bx + bw - 1
                           or yy == by or yy == by + bh - 1)
                if not on_ring:
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
                else:
                    walls.add((xx, yy))
        for yy in range(by + 1, by + bh - 1):
            for xx in range(bx + 1, bx + bw - 1):
                inner[(xx, yy)] = i
                if dw <= 0:
                    sealed.add((xx, yy))
    asphalt = set()
    for z in c.get("groundZones", []):
        tex = os.path.basename(str(z.get("texture", "")))
        if "Asphalt" in tex or "Road" in tex:
            asphalt |= set(rect_cells(z.get("rect", {}) or {}))
    terrain = set()
    for t in cfg.get("terrain", []):
        if int(t.get("map", -1)) != 2:
            continue
        kind = "platform" if "platform" in t else ("ramp" if "ramp" in t else "")
        if kind:
            terrain |= set(rect_cells(t[kind] or {}))
    entities = set()
    for e in c.get("enemies", []):
        entities.add((int(e["x"]), int(e["y"])))
    for p in c.get("pickups", []):
        entities.add((int(p["x"]), int(p["y"])))
    for key in ("spawn", "flag"):
        s = c.get(key, {}) or {}
        if s:
            entities.add((int(s.get("x", -1)), int(s.get("y", -1))))
    return {
        "w": w, "h": h, "walls": walls, "doors": doors, "inner": inner,
        "sealed": sealed, "asphalt": asphalt, "terrain": terrain,
        "entities": entities,
    }


def check(k, S):
    """返回冲突原因串; 合法返回空串"""
    x, y = k
    if not (0 <= x < S["w"] and 0 <= y < S["h"]):
        return "越界"
    if k in S["walls"]:
        return "墙格"
    if k in S["doors"]:
        return "门洞(堵门)"
    if k in S["terrain"]:
        return "地形高差区(坡面/台面会穿模)"
    if k in S["asphalt"]:
        return "沥青车道覆层"
    if k in S["sealed"]:
        return "封闭装饰体块室内(不可见)"
    if k in S["entities"]:
        return "敌人/拾取/出生/信标占用"
    return ""


def _is_map2_entry(p):
    """map2 归属判定: 带 map==2 的道具条目, 以及本工具写的 map2 区块注释条。
    后者不带 map 字段, 不纳入剔除会在重跑时重复累积(破幂等)。"""
    if int(p.get("map", -1)) == 2:
        return True
    c = str(p.get("_comment", ""))
    return "B批4" in c and "map2" in c


def apply_to_cfg(snippet):
    """并入 level_ext.json 的 props 段。幂等: 先剔除已有 map2 条目(含注释条)再追加,
    重跑不会叠加。段序不变(键已存在时 dict 赋值不挪位)。"""
    with io.open(CFG, encoding="utf-8", newline="") as f:
        cfg = json.load(f)
    before_keys = list(cfg.keys())
    props = cfg.get("props", [])
    kept = [p for p in props if not _is_map2_entry(p)]
    map0_before = sum(1 for p in kept if int(p.get("map", -1)) == 0)
    cfg["props"] = kept + snippet
    out = json.dumps(cfg, ensure_ascii=False, indent=2).replace("\n", "\r\n") + "\r\n"
    with io.open(CFG, "w", encoding="utf-8", newline="") as f:
        f.write(out)
    # 回读校验(期望值同样排除注释条, 否则恒差 1)
    with io.open(CFG, encoding="utf-8") as f:
        back = json.load(f)
    bp = back.get("props", [])
    m2 = sum(1 for p in bp if int(p.get("map", -1)) == 2)
    m2_expect = sum(1 for p in snippet if int(p.get("map", -1)) == 2)
    m0 = sum(1 for p in bp if int(p.get("map", -1)) == 0)
    marks = sum(out.count(m) for m in ("<<<<<<<", ">>>>>>>", "======="))
    print("")
    print("--- --apply 落盘校验 ---")
    print("  字符 %d / 行 %d / 段 %d (段序未变: %s)"
          % (len(out), out.count("\r\n"), len(back),
             "是" if list(back.keys()) == before_keys else "!! 否"))
    print("  props 总数 %d (map0 %d 未变=%s / map2 %d 期望 %d=%s)"
          % (len(bp), m0, m0 == map0_before, m2, m2_expect, m2 == m2_expect))
    print("  冲突标记残留 %d" % marks)
    print("  environments 段在场: %s" % ("environments" in back))
    ok = (list(back.keys()) == before_keys and m0 == map0_before
          and m2 == m2_expect and marks == 0)
    print("  => %s" % ("OK" if ok else "!! 校验未通过, 请回滚"))
    return ok


def main():
    cfg = load()
    c = map_cfg(cfg)
    if not c:
        sys.exit("!! level_ext.maps 无 map=2 配置")
    S = build_sets(cfg, c)

    ok, bad = [], []
    seen = {}
    for sprite, scale, x, y, note in CANDIDATES:
        k = (x, y)
        if k in seen:
            bad.append((sprite, scale, x, y, note, "与候选 #%d 重复" % seen[k]))
            continue
        seen[k] = len(seen)
        why = check(k, S)
        if why:
            bad.append((sprite, scale, x, y, note, why))
        else:
            ok.append((sprite, scale, x, y, note))

    lines = []
    ap = lines.append
    ap("=" * 74)
    ap("map2 道具点缀落位校验 (B批4·T1)")
    ap("=" * 74)
    ap("候选 %d 项 → 合法 %d / 冲突 %d" % (len(CANDIDATES), len(ok), len(bad)))
    by_sprite = {}
    for sprite, scale, x, y, note in ok:
        by_sprite.setdefault(os.path.basename(sprite), []).append((x, y))
    for name in sorted(by_sprite):
        ap("  %-24s %2d 个" % (name, len(by_sprite[name])))
    ap("")
    if bad:
        ap("--- 冲突项(需调整落位) ---")
        for sprite, scale, x, y, note, why in bad:
            ap("  !! (%d,%d) %-16s %s → %s"
               % (x, y, os.path.basename(sprite).replace("Prop ", "")
                  .replace(".png", ""), note, why))
        ap("")
    ap("--- 合法落位明细 ---")
    for sprite, scale, x, y, note in ok:
        ap("  (%3d,%3d) %-10s scale=%.2f  %s"
           % (x, y, os.path.basename(sprite).replace("Prop ", "").replace(".png", ""),
              scale, note))

    snippet = [{"_comment": "B批4·T1 map2 城区街道点缀: 主街路灯序列(北 row40/南 row45 "
                             "错开半间距)+枯树剪影+三座可进入建筑门侧与室内木箱(转运链呼应)"
                             "+街区/巷区瓦砾。纯布景: Sprite3D billboard, 不建碰撞、"
                             "不登记 wall_cells → 玩法/寻路/小地图零侵入。"
                             "落位经 gen_map2_props.py 校验(非墙/门洞/地形/车道/封闭室内/实体占用)。"}]
    for sprite, scale, x, y, note in ok:
        snippet.append({"map": 2, "sprite": sprite, "x": x, "y": y, "scale": scale})
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(snippet, f, ensure_ascii=False, indent=2)
        f.write("\n")
    ap("")
    ap("已写出 %s (%d 条目, 含 1 条 _comment)" % (OUT, len(snippet)))

    text = "\n".join(lines) + "\n"
    print(text)
    if bad:
        print("!! 有 %d 项冲突, 片段已剔除这些项" % len(bad))
    if "--apply" in sys.argv:
        if bad:
            sys.exit("!! 存在 %d 项落位冲突, 拒绝 --apply" % len(bad))
        if not apply_to_cfg(snippet):
            sys.exit("!! 落盘校验未通过")


if __name__ == "__main__":
    main()
