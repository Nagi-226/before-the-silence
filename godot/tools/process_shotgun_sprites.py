"""Build the runtime shotgun sprites from their archived high-resolution sources."""

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT.parent / "assets-src" / "shotgun"

# source, output relative to godot/, target height, palette colors
JOBS = [
    ("viewmodel7_raw.png", "assets/images/WeaponShotgun.png", 144, 24),
    ("pickup_raw.png", "assets/sprites/Weapon Shotgun Pickup.png", 48, 48),
    ("shells_raw.png", "assets/sprites/Shells 12g.png", 40, 48),
]

BLACK_TOLERANCE = 28


def remove_black_bg(image: Image.Image) -> Image.Image:
    """Flood-fill an opaque black backdrop without deleting enclosed dark details."""
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    visited = bytearray(width * height)
    queue = deque()

    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if visited[index]:
            continue
        visited[index] = 1
        red, green, blue, alpha = pixels[x, y]
        if alpha > 0 and max(red, green, blue) > BLACK_TOLERANCE:
            continue
        pixels[x, y] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height and not visited[ny * width + nx]:
                queue.append((nx, ny))
    return image


def crop_content(image: Image.Image, pad: int = 4, alpha_threshold: int = 1) -> Image.Image:
    mask = image.getchannel("A").point(
        lambda value: 255 if value >= alpha_threshold else 0
    )
    bbox = mask.getbbox()
    if not bbox:
        return image
    width, height = image.size
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(width, bbox[2] + pad)
    bottom = min(height, bbox[3] + pad)
    return image.crop((left, top, right, bottom))


def resize_to_height(image: Image.Image, target_height: int) -> Image.Image:
    width, height = image.size
    target_width = max(1, round(width * target_height / height))
    return image.resize((target_width, target_height), Image.Resampling.LANCZOS)


def posterize(image: Image.Image, colors: int) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = image.convert("RGB").quantize(colors=colors, dither=Image.Dither.NONE)
    output = rgb.convert("RGBA")
    output.putalpha(alpha)
    return output


def main() -> None:
    for source_name, output_relative, target_height, colors in JOBS:
        image = Image.open(SRC / source_name).convert("RGBA")
        is_viewmodel = "viewmodel" in source_name
        if not is_viewmodel:
            image = remove_black_bg(image)
        image = crop_content(
            image,
            pad=2 if is_viewmodel else 4,
            alpha_threshold=128 if is_viewmodel else 1,
        )

        if is_viewmodel:
            # The HUD scales this sprite with nearest-neighbor filtering. Keep the
            # source clusters hard and preserve side padding so neither arm is
            # clipped against the texture boundary during weapon animations.
            image = image.resize((96, target_height), Image.Resampling.NEAREST)
            alpha = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
            image.putalpha(alpha)
            padded = Image.new("RGBA", (108, target_height), (0, 0, 0, 0))
            padded.paste(image, (6, 0), image)
            image = padded
        else:
            image = resize_to_height(image, target_height)

        image = posterize(image, colors)
        output = ROOT / output_relative
        output.parent.mkdir(parents=True, exist_ok=True)
        image.save(output)
        print(f"OK {source_name} -> {output_relative} {image.size}")


if __name__ == "__main__":
    main()
