# 从 src/game/Level.cpp 提取地图数据 → godot/scripts/levels/LevelData.gd
# 用法: py -3 tools/gen_level_data.py
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]          # .../Retro FPS/godot
LEVEL_CPP = ROOT.parent / "src" / "game" / "Level.cpp"
OUT = ROOT / "scripts" / "levels" / "LevelData.gd"
WIDTH, HEIGHT = 168, 68


def extract_map(src: str, var: str) -> str:
    m = re.search(var + r"\s*=\s*\n?(.*?);", src, re.S)
    if not m:
        raise SystemExit(f"cannot find {var}")
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))
    return "".join(parts)


def rows_of(data: str) -> list:
    return [data[y * WIDTH:(y + 1) * WIDTH] for y in range(HEIGHT)]


src = LEVEL_CPP.read_text(encoding="utf-8")
maps = {}
for var in ("kMap0", "kMap1"):
    data = extract_map(src, var)
    if len(data) < WIDTH * HEIGHT:
        print(f"WARN {var}: len={len(data)} < {WIDTH * HEIGHT} (不足部分按空格补齐)")
        data = data + " " * (WIDTH * HEIGHT - len(data))
    maps[var] = rows_of(data)
    print(f"OK {var}: {len(data)} chars")

blocks = []
for var in ("kMap0", "kMap1"):
    lines = "\n".join(maps[var])
    blocks.append(f'"""\n{lines}\n"""')

gd = f'''# 自动生成于 tools/gen_level_data.py — 源自 src/game/Level.cpp，请勿手改
class_name LevelData

const WIDTH := {WIDTH}
const HEIGHT := {HEIGHT}
const NAMES := ["前哨站废墟", "地下研究所"]

const MAPS := [
{blocks[0]},
{blocks[1]},
]
'''
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(gd, encoding="utf-8")
print(f"written: {OUT}")
