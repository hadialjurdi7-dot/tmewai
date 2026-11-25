"""Builds the shipped app icon and .ico from the approved logo.

The approved mark is a black rounded square with a white sans-serif «T».
Source of truth: the logo the owner signed off on. This script only crops the
white margin, applies the rounded-corner mask and writes the sizes the Windows
runner and the Flutter bundle need.

Run: python3 tool/make_icon_from_logo.py <source-image>
"""

import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "branding")

# Corner radius as a share of the side, measured off the approved logo.
RADIUS_RATIO = 0.20
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def load_mark(source):
    """The mark alone: white margin cropped away."""
    image = Image.open(source).convert("RGB")
    width, height = image.size
    pixels = image.load()
    xs, ys = [], []
    for y in range(0, height, 2):
        for x in range(0, width, 2):
            r, g, b = pixels[x, y]
            if min(r, g, b) < 128:  # part of the black square
                xs.append(x)
                ys.append(y)
    if not xs:
        raise SystemExit("no dark pixels: not the approved mark?")
    box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    side = max(box[2] - box[0], box[3] - box[1])
    cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
    half = side // 2
    return image.crop((cx - half, cy - half, cx - half + side, cy - half + side))


def rounded(mark, size):
    """The mark at [size]px with transparent corners."""
    scaled = mark.resize((size * 4, size * 4), Image.LANCZOS)
    mask = Image.new("L", scaled.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, scaled.size[0] - 1, scaled.size[1] - 1),
        radius=int(scaled.size[0] * RADIUS_RATIO),
        fill=255,
    )
    scaled = scaled.resize((size, size), Image.LANCZOS)
    mask = mask.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(scaled, (0, 0), mask)
    return out


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    mark = load_mark(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)

    icon = rounded(mark, 1024)
    icon.save(os.path.join(OUT, "tmewai_app_icon.png"))
    rounded(mark, 512).save(os.path.join(OUT, "tmewai_mark_primary_512.png"))
    rounded(mark, 256).save(
        os.path.join(OUT, "tmewai.ico"),
        sizes=[(s, s) for s in ICO_SIZES],
    )
    # The README logo sits on white, so it keeps square transparent corners.
    icon.save(os.path.join(OUT, "tmewai_logo.png"))
    for name in os.listdir(OUT):
        path = os.path.join(OUT, name)
        print(f"{name}: {os.path.getsize(path)} bytes")


if __name__ == "__main__":
    main()
