# -*- coding: utf-8 -*-
"""A批8 · 把 gen_rebalance.py 产物合入 level_ext.json(幂等)。

三处改动:
1. layers floor2/3 pickups: 剔除 batch=8 旧产物 → h 截断保留 H_KEEP → 追加新补给
2. pickupOverrides: 剔除 _comment 含 "A批8" 的旧条目 → 追加一层补给抑制(数组 suppress)
3. enemyOverrides: 同上剔除 → 追加一层 id0/id1 抑制 + 二三层布防(A批7 条目原样保留)

h 截断修正 A批7 平衡失误: h = 生命上限升级(消耗10金币 +20 上限, 无次数上限),
A批7 在二三层各撒 11/10 个 → 全吃血上限 100→620。每层截断保留 3 个。

运行: python godot/tools/patch_rebalance.py
"""
import io
import json
import os
from collections import Counter, OrderedDict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_EXT = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
OUT_DIR = os.path.join(ROOT, "build")

BATCH = 8
H_KEEP = 3
MARK = "A批8"
# 权威期望(gen_rebalance.py 报告, 断言用): 层 → 符号 → 只数
# 二层不给 s(霰弹补给): T 在三层, 二层只有冲锋枪 W——给 s 无意义且会抢走
# SmokeTest _teleport_to_symbol("s") 的首个命中位(原为三层宝库 (5,28))
EXPECT = {
    2: {"C": 36, "W": 1, "A": 38, "e": 13, "h": 3, "H": 14},
    3: {"T": 1, "U": 1, "s": 5, "h": 3, "e": 13, "A": 38, "C": 38, "H": 16},
}
LAYER_NOTE = (" | A批8补给重平衡: h 由 %d 截断至 %d(生命上限升级无次数上限, A批7 过量"
              "会导致血上限 100→620), 另撒 C/A/H/e/s 共 %d 个(一层匀来, 密度 "
              "%.2f 个/百格), 落点分桶均匀且全在 BFS 可达集, batch=8 标记供幂等重跑。")


def is_batch(entry):
    return MARK in str(entry.get("_comment", ""))


def main():
    ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"),
                    object_pairs_hook=OrderedDict)
    sup = json.load(io.open(os.path.join(OUT_DIR, "ab8_pickup_suppress.json"),
                            encoding="utf-8"), object_pairs_hook=OrderedDict)
    ov = json.load(io.open(os.path.join(OUT_DIR, "ab8_enemy_overrides.json"),
                           encoding="utf-8"), object_pairs_hook=OrderedDict)
    lay = json.load(io.open(os.path.join(OUT_DIR, "ab8_layer_pickups.json"),
                            encoding="utf-8"), object_pairs_hook=OrderedDict)
    assert is_batch(sup) and is_batch(ov), "产物缺少 A批8 标识, 幂等剔除会失效"

    # ── 1. layers: 剔旧 → h 截断 → 追加 ─────────────────────────
    hit = {2: False, 3: False}
    for layer in ext.get("layers", []):
        if layer.get("map") != 0 or layer.get("floor") not in (2, 3):
            continue
        f = layer["floor"]
        hit[f] = True
        ps = [p for p in layer.get("pickups", []) if p.get("batch") != BATCH]
        hs = sorted([p for p in ps if p.get("symbol") == "h"],
                    key=lambda p: (p["y"], p["x"]))
        keep_ids = {id(p) for p in hs[:H_KEEP]}
        ps = [p for p in ps if p.get("symbol") != "h" or id(p) in keep_ids]
        add = lay[str(f)]
        layer["pickups"] = ps + add
        got = Counter(p["symbol"] for p in layer["pickups"])
        assert dict(got) == EXPECT[f], "F%d 补给明细不符: %s vs %s" % (
            f, dict(got), EXPECT[f])
        cells = [(p["x"], p["y"]) for p in layer["pickups"]]
        assert len(cells) == len(set(cells)), "F%d pickups 有重复坐标" % f
        note = LAYER_NOTE % (len(hs), H_KEEP, len(add),
                             len(layer["pickups"]) / 8378.0 * 100 if f == 2
                             else len(layer["pickups"]) / 8398.0 * 100)
        if MARK not in str(layer.get("_comment", "")):
            layer["_comment"] = str(layer.get("_comment", "")) + note
    assert hit[2] and hit[3], "layers floor2/3 未命中: %s" % hit

    # ── 2. pickupOverrides: 剔旧 → 追加(A批5 单格条目保留) ────────
    po = [e for e in ext.get("pickupOverrides", []) if not is_batch(e)]
    po.append(sup)
    ext["pickupOverrides"] = po

    # ── 3. enemyOverrides: 剔旧 → 追加(A批7 条目保留) ─────────────
    eo = [e for e in ext.get("enemyOverrides", []) if not is_batch(e)]
    eo.append(ov)
    ext["enemyOverrides"] = eo

    # 抑制格不得与 place 格重叠(自我抵消无意义)
    sup_cells = {(d["x"], d["y"]) for d in sup["suppress"]}
    assert len(sup_cells) == len(sup["suppress"]), "补给抑制有重复格"
    esup = {(d["x"], d["y"]) for d in ov["suppress"]}
    assert len(esup) == len(ov["suppress"]), "敌人抑制有重复格"
    epl = {(d["x"], d["y"]) for d in ov["place"]}
    assert len(epl) == len(ov["place"]), "敌人布防有重复格"
    assert not (sup_cells & esup), "补给抑制与敌人抑制格重叠"
    assert not (epl & esup), "布防格与抑制格重叠"

    txt = json.dumps(ext, ensure_ascii=False, indent=2)
    io.open(LEVEL_EXT, "w", encoding="utf-8", newline="\r\n").write(txt + "\r\n")

    print("level_ext.json 已合入 A批8:")
    print("  pickupOverrides: %d 条(一层补给抑制 %d 格: H×48 C×89 A×52)"
          % (len(po), len(sup["suppress"])))
    print("  enemyOverrides : %d 条(一层抑制 %d 格 id0×8/id1×32, 布防 %d 只: "
          "2F %d + 3F %d)" % (len(eo), len(ov["suppress"]), len(ov["place"]),
                              sum(1 for d in ov["place"] if d["floor"] == 2),
                              sum(1 for d in ov["place"] if d["floor"] == 3)))
    for f in (2, 3):
        layer = [l for l in ext["layers"]
                 if l.get("map") == 0 and l.get("floor") == f][0]
        print("  layers F%d pickups: %d 个 %s"
              % (f, len(layer["pickups"]),
                 dict(Counter(p["symbol"] for p in layer["pickups"]))))


if __name__ == "__main__":
    main()
