# 霰弹枪素材处理: 去黑底 → 裁剪 → 缩放到项目尺寸 → 限色retro化
# 用法: python godot/tools/process_shotgun_sprites.py
from collections import deque
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]          # .../signal-lost/godot
SRC = ROOT.parent / "assets-src" / "shotgun"

# (源文件, 输出相对 godot/, 目标高度, 限色数)
JOBS = [
    # viewmodel3: 粗块像素风（以手枪/冲锋枪为参考图生成，胸前手持指向正前方）。
    # 关键经验：写实高清源压 120px 必然虚化——AI 写实纹理在 240x135 呈现层下全部糊掉，
    # 持枪素材必须生成为大色块硬边像素风（2026-08-09 三轮迭代结论）
    ("viewmodel3_raw.png", "assets/images/WeaponShotgun.png", 120, 32),
    ("pickup_raw.png", "assets/sprites/Weapon Shotgun Pickup.png", 48, 48),
    ("shells_raw.png", "assets/sprites/Shells 12g.png", 40, 48),
]

TOL = 28  # 黑底判定阈值（边缘洪泛）


def remove_black_bg(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    visited = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if visited[i]:
            continue
        visited[i] = 1
        r, g, b, a = px[x, y]
        if a > 0 and max(r, g, b) > TOL:
            continue  # 非黑底，洪泛停止
        px[x, y] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx]:
                q.append((nx, ny))
    return im


def crop_content(im: Image.Image, pad: int = 4) -> Image.Image:
    bbox = im.getchannel("A").getbbox()
    if not bbox:
        return im
    w, h = im.size
    l = max(0, bbox[0] - pad)
    t = max(0, bbox[1] - pad)
    r = min(w, bbox[2] + pad)
    b = min(h, bbox[3] + pad)
    return im.crop((l, t, r, b))


def resize_to_height(im: Image.Image, target_h: int) -> Image.Image:
    w, h = im.size
    target_w = max(1, round(w * target_h / h))
    return im.resize((target_w, target_h), Image.LANCZOS)


def posterize(im: Image.Image, colors: int) -> Image.Image:
    alpha = im.getchannel("A")
    rgb = im.convert("RGB").quantize(colors=colors, dither=Image.Dither.NONE)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def main() -> None:
    for src_name, out_rel, target_h, colors in JOBS:
        im = Image.open(SRC / src_name)
        if src_name == "viewmodel2_raw.png":
            # 一次性修补：涂掉左下角 "AI生成" 水印（位于纯黑底区域）
            im = im.convert("RGBA")
            px = im.load()
            for yy in range(1380, im.size[1]):
                for xx in range(0, 220):
                    px[xx, yy] = (0, 0, 0, 255)
        if src_name == "viewmodel3_raw.png":
            # 一次性修补：裁掉底部含 "AI生成" 水印条
            im = im.convert("RGBA").crop((0, 0, im.size[0], 1450))
        im = remove_black_bg(im)
        im = crop_content(im, pad=2 if "viewmodel" in src_name else 4)
        if "viewmodel" in src_name:
            # 像素风管线：直接缩到 60x120 + alpha 硬边，限色在主流程完成
            im = im.resize((60, target_h), Image.LANCZOS)
            a = im.getchannel("A").point(lambda v: 255 if v >= 140 else 0)
            im.putalpha(a)
        else:
            im = resize_to_height(im, target_h)
        im = posterize(im, colors)
        out = ROOT / out_rel
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out)
        print(f"OK {src_name} -> {out_rel} {im.size}")


if __name__ == "__main__":
    main()
