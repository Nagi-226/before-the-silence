# -*- coding: utf-8 -*-
"""Shotgun viewmodel r2 pipeline (reproducible):
raw(AI, magenta bg) -> key out bg -> remove watermark zone -> crop bbox
-> nearest-scale into 108x144 canvas (bottom-aligned, horizontally centered)
-> godot/assets/images/WeaponShotgun.png
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(ROOT))
SRC = os.path.join(ROOT, "viewmodel_final_raw.png")
DST = os.path.join(REPO, "godot", "assets", "images", "WeaponShotgun.png")
KEY_POS = (8, 8)
SIM = 0.22          # colorkey similarity (normalized RGB distance)
BLEND = 0.10        # colorkey blend band
MAXD = math.sqrt(3.0) * 255.0
CANVAS_W, CANVAS_H = 108, 144


def main():
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    key = img.getpixel(KEY_POS)[:3]
    print("raw=%dx%d key=%s" % (w, h, key))

    # Paint watermark zone (bottom-right) with the key color so it keys out.
    draw = ImageDraw.Draw(img)
    draw.rectangle([int(w * 0.70), int(h * 0.90), w - 1, h - 1], fill=key + (255,))

    lo = SIM * MAXD
    hi = (SIM + BLEND) * MAXD
    px = img.load()
    kr, kg, kb = key
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = math.sqrt((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2)
            if d <= lo:
                px[x, y] = (r, g, b, 0)
            elif d < hi:
                t = (d - lo) / (hi - lo)
                px[x, y] = (r, g, b, int(t * 255))

    box = img.getbbox()
    if box is None:
        raise SystemExit("keying removed everything - check key color")
    crop = img.crop(box)
    cw, ch = crop.size
    print("bbox=%s crop=%dx%d" % (box, cw, ch))

    scale = min(CANVAS_W / cw, CANVAS_H / ch)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    scaled = crop.resize((nw, nh), Image.NEAREST)

    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    ox = (CANVAS_W - nw) // 2
    oy = CANVAS_H - nh  # bottom-aligned: stock sits on the HUD frame bottom
    canvas.paste(scaled, (ox, oy))
    canvas.save(DST)
    print("saved %s (%dx%d, gun %dx%d at +%d+%d)" % (DST, CANVAS_W, CANVAS_H, nw, nh, ox, oy))


if __name__ == "__main__":
    main()
