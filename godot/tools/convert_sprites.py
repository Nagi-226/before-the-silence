# 旧版精灵 BMP 使用黑色背景作为透明色键 → 转为带 alpha 的 PNG
# 用法: py -3 tools/convert_sprites.py
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "images"
OUT = ROOT / "assets" / "sprites"
OUT.mkdir(exist_ok=True)

SPRITES = [
    "Alien Small", "Alien Medium", "Alien Large",
    "Coin", "Heart", "Battery", "Flag", "Crosshair",
    "Upgrade Ammo 10", "Upgrade Heart 10", "Upgrade Weapon Speed 10",
    "Orb Green", "Orb Purple",
]

for name in SPRITES:
    src = SRC / f"{name}.bmp"
    if not src.exists():
        print(f"skip (missing): {name}")
        continue
    img = Image.open(src).convert("RGBA")
    px = img.load()
    keyed = 0
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if r == 0 and g == 0 and b == 0:
                px[x, y] = (0, 0, 0, 0)
                keyed += 1
    dst = OUT / f"{name}.png"
    img.save(dst)
    print(f"ok: {name}.png ({img.width}x{img.height}, keyed {keyed}px)")
print("done")
