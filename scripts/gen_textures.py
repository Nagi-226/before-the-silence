"""生成程序化 BMP 纹理，替代缺失的纹理文件。
   Run: python scripts/gen_textures.py
"""
import struct, os

IMAGES = os.path.join(os.path.dirname(__file__), "..", "assets", "images")

def write_bmp(path, width, height, pixels):
    """pixels: list of (r,g,b) tuples, row-major (top-left first)"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    row_size = (width * 3 + 3) & ~3
    file_size = 54 + row_size * height
    with open(path, 'wb') as f:
        f.write(b'BM')
        f.write(struct.pack('<I', file_size))
        f.write(b'\x00\x00\x00\x00')
        f.write(struct.pack('<I', 54))
        f.write(struct.pack('<I', 40))
        f.write(struct.pack('<I', width))
        f.write(struct.pack('<I', height))
        f.write(struct.pack('<H', 1))
        f.write(struct.pack('<H', 24))
        f.write(b'\x00' * 24)
        for y in range(height - 1, -1, -1):
            row = bytearray()
            for x in range(width):
                c = pixels[y * width + x]
                row.append(c[2])  # B
                row.append(c[1])  # G
                row.append(c[0])  # R
            row.extend(b'\x00' * (row_size - width * 3))
            f.write(row)

def brick_pat(x, y):
    """生成砖墙纹理"""
    row = y // 8
    offset = (row & 1) * 4
    bx = ((x + offset) % 16) // 4
    by = (y % 16) // 4
    if 1 <= bx <= 2 and by in (0, 3):
        return (75, 35, 35)
    if bx in (0, 3) or by in (0, 3):
        return (90, 50, 40)
    return (110, 65, 45)

def metal_pat(x, y):
    """金属板纹理"""
    v = 120 + ((x // 8 + y // 8) & 1) * 15
    if x % 16 == 0 or y % 16 == 0:
        v -= 20
    if x % 4 == 0 or y % 4 == 0:
        v += 5
    return (v, v, v + 10)

def stone_pat(x, y):
    """石墙纹理"""
    v = 80
    if (x * 7 + y * 13) % 23 < 3:
        v = 70
    elif (x * 3 + y * 17) % 19 < 2:
        v = 90
    if x % 16 < 2 or y % 16 < 2:
        v = 65
    return (v, v, v)

def grate_pat(x, y):
    """铁栅栏纹理（透明为黑色）"""
    bar_x =  (x % 12) < 2
    bar_y = (y % 12) < 2
    if bar_x or bar_y:
        return (140, 150, 160)
    return (20, 25, 35)

def floor_pat(x, y):
    """地板砖纹理"""
    v = 70
    if (x // 16 + y // 16) & 1:
        v = 55
    if x % 16 == 0 or y % 16 == 0:
        v = 45
    return (v, v - 5, v - 15)

def ceiling_pat(x, y):
    """天花板纹理"""
    v = 50 + ((x // 8 + y // 8) & 1) * 8
    return (v - 5, v, v + 10)

def cloud_pat(x, y):
    """云纹理"""
    r = 0
    g = 0
    b = 0
    for dx, dy, w in [(0, 3, 80), (30, 8, 60), (60, 5, 70), (120, 12, 50), (160, 7, 65)]:
        cx = x - dx
        cy = y - dy
        dist2 = cx * cx + cy * cy * 4
        d = w * w - dist2
        if d > 0:
            a = min(d / (w * w) * 0.6, 0.6)
            r = int(r + 200 * a)
            g = int(g + 220 * a)
            b = int(b + 255 * a)
    return (min(r, 255), min(g, 255), min(b, 255))

def weapon_pat(x, y):
    """武器模型纹理"""
    if y < 5:
        return (40, 35, 30)
    if x < 4 or x >= 28:
        return (60, 55, 50)
    if 10 <= x <= 20 and 20 <= y <= 40:
        return (50, 40, 30)
    return (45, 40, 35)

def gen_tex(filename, width, height, func):
    """生成纹理 BMP"""
    pixels = [func(x, y) for y in range(height) for x in range(width)]
    path = os.path.join(IMAGES, filename)
    write_bmp(path, width, height, pixels)
    print(f"  {path} ({width}x{height})")

print("Generating procedural textures...")
gen_tex("Wall Brick.bmp", 64, 64, brick_pat)
gen_tex("Wall Metal.bmp", 64, 64, metal_pat)
gen_tex("Wall Stone.bmp", 64, 64, stone_pat)
gen_tex("Wall Grate.bmp", 64, 64, grate_pat)
gen_tex("Floor Tile.bmp", 64, 64, floor_pat)
gen_tex("Ceiling.bmp", 64, 64, ceiling_pat)
gen_tex("Cloud.bmp", 200, 32, cloud_pat)
gen_tex("Weapon.bmp", 32, 60, weapon_pat)
print("Done!")
