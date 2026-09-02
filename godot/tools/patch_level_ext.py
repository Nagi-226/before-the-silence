# -*- coding: utf-8 -*-
"""A批7 · 将 gen_expand.py 产物合入 level_ext.json。

- floor2/floor3 layers 块整体替换(rect/grid/slabHoles/pickups 新, enemies+宝库
  pickups 生成器已并入), 补 _comment 说明批次口径
- 新增 enemyOverrides 段(插在 pickupOverrides 之后, 保持键序可读)
运行: python godot/tools/patch_level_ext.py
"""
import io
import json
import os
from collections import OrderedDict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVEL_EXT = os.path.join(ROOT, "godot", "assets", "config", "level_ext.json")
OUT_DIR = os.path.join(ROOT, "build")

F2_COMMENT = ("A批7·二层全境扩面(用户拍板: ≥一层室内可走7284的70%): rect 扩至符号图"
              "全部内容行 (0,0,168,62), 可走8378格=115%(gen_expand.py BFS自楼梯落点"
              "(31,23)全连通实证+塔楼契约格逐格验证)。旧塔楼区块(x1..33,y17..30)原样"
              "保留(井道/楼梯1落点/物资/哨戒敌全契约不动), 周界开门洞 (4-5,30)(22-23,30)"
              "(33,22-23) 连通新区。新区=抖动墙线房间迷宫+2格门洞+稀疏立柱。周界环全X"
              " → 天花板带0宽, 一层室内顶板=三层整块7.8(Ceiling 节点名不变)。y62..69"
              "岩体不加板(南带2.6兜底)。拾取 h/C/W 塔楼原样 + 新区 h×10/A×10/e×4。")
F3_COMMENT = ("A批7·三层全境扩面(同二层口径): 可走8398格=115%, BFS自楼梯2落点(31,20)"
              "全连通+契约验证。旧塔楼区块原样保留(宝库 T/U/s×2/巨宿主镇守(9,25)/row20"
              "cols30-32落点段), 周界门洞 (20-21,30)(30-31,30)(33,25-26)。迷宫布局与"
              "二层不同(seed 分离)。一层精英重布主力层: enemyOverrides 24只 id2 落三层"
              "新区(_layer_base_height 抬升板顶)。")


def main():
    ext = json.load(io.open(LEVEL_EXT, encoding="utf-8"),
                    object_pairs_hook=OrderedDict)
    f2 = json.load(io.open(os.path.join(OUT_DIR, "ab7_f2.json"), encoding="utf-8"),
                   object_pairs_hook=OrderedDict)
    f3 = json.load(io.open(os.path.join(OUT_DIR, "ab7_f3.json"), encoding="utf-8"),
                   object_pairs_hook=OrderedDict)
    ov = json.load(io.open(os.path.join(OUT_DIR, "ab7_enemy_overrides.json"),
                           encoding="utf-8"), object_pairs_hook=OrderedDict)
    f2["_comment"] = F2_COMMENT
    f3["_comment"] = F3_COMMENT

    replaced = {2: False, 3: False}
    new_layers = []
    for layer in ext.get("layers", []):
        if layer.get("map") == 0 and layer.get("floor") == 2:
            new_layers.append(f2)
            replaced[2] = True
        elif layer.get("map") == 0 and layer.get("floor") == 3:
            new_layers.append(f3)
            replaced[3] = True
        else:
            new_layers.append(layer)
    assert replaced[2] and replaced[3], "floor2/3 块未命中: %s" % replaced
    ext["layers"] = new_layers

    # enemyOverrides 插到 pickupOverrides 之后(键序可读)
    out = OrderedDict()
    for k, v in ext.items():
        out[k] = v
        if k == "pickupOverrides":
            out["enemyOverrides"] = [ov]
    if "enemyOverrides" not in out:
        out["enemyOverrides"] = [ov]
    else:
        out["enemyOverrides"] = [ov]

    txt = json.dumps(out, ensure_ascii=False, indent=2)
    io.open(LEVEL_EXT, "w", encoding="utf-8", newline="\r\n").write(txt + "\r\n")
    print("level_ext.json 已更新: floor2/3 全境扩面 + enemyOverrides(抑制%d/重布%d)"
          % (len(ov["suppress"]), len(ov["place"])))


if __name__ == "__main__":
    main()
