"""生成通用武器升级组件拾取物精灵（48x41，透明底 + 光晕）。

风格对齐 Weapon SMG Pickup.png：中央深色像素剪影 + 柔和彩色光晕。
一级组件: 青色光晕，单竖条标记；二级组件: 橙色光晕，双竖条标记。
输出: godot/assets/sprites/Upgrade Component 1.png / Upgrade Component 2.png
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

W, H = 48, 41
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sprites"

# (文件名, 光晕色, 主体描边色, 标记竖条数)
LEVELS = [
    ("Upgrade Component 1.png", (64, 220, 220), (120, 240, 240), 1),
    ("Upgrade Component 2.png", (255, 150, 40), (255, 190, 90), 2),
]


def make_sprite(path: Path, halo: tuple, edge: tuple, marks: int) -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # 光晕层: 椭圆径向渐变近似（多层递减 alpha）
    halo_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo_layer)
    cx, cy = W / 2, H / 2
    for i in range(10, 0, -1):
        rx, ry = 2.0 * i, 1.7 * i
        alpha = int(14 + (10 - i) * 6)
        hd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=halo + (alpha,))
    halo_layer = halo_layer.filter(ImageFilter.GaussianBlur(1.2))
    img.alpha_composite(halo_layer)

    d = ImageDraw.Draw(img)

    # 组件主体: 深色芯片模块 24x16，居中
    x0, y0, x1, y1 = 12, 12, 36, 28
    d.rectangle([x0, y0, x1, y1], fill=(18, 20, 26, 255), outline=edge + (255,))
    # 内部电路线
    d.line([x0 + 3, y0 + 4, x1 - 3, y0 + 4], fill=edge + (160,))
    d.line([x0 + 3, y1 - 4, x1 - 3, y1 - 4], fill=edge + (160,))
    # 四角引脚
    for px, py in [(x0 - 2, y0 + 2), (x1 + 1, y0 + 2), (x0 - 2, y1 - 3), (x1 + 1, y1 - 3)]:
        d.rectangle([px, py, px + 1, py + 1], fill=edge + (255,))
    # 中央核心块
    d.rectangle([cx - 4, cy - 3, cx + 3, cy + 2], fill=(30, 34, 44, 255), outline=edge + (200,))
    # 等级标记: 竖条 I / II
    for m in range(marks):
        mx = int(cx) - (marks - 1) + m * 3 - 1
        d.line([mx, cy - 2, mx, cy + 1], fill=(255, 255, 255, 255))

    img.save(path)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, halo, edge, marks in LEVELS:
        out = OUT_DIR / name
        make_sprite(out, halo, edge, marks)
        print("written:", out)


if __name__ == "__main__":
    main()
