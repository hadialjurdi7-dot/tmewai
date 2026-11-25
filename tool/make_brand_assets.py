"""Regenerates the Tmewai brand assets in assets/branding/.

Run only when the mark changes: `python3 tool/make_brand_assets.py`.
The committed PNG/ICO files are the source of truth for builds; this script
needs Pillow (`pip install pillow`) because the repo ships no rasteriser.
"""

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "branding"
)
S = 4  # supersample factor, downscaled at the end for clean edges

NAVY_TOP = (27, 42, 60)   # 1B2A3C
NAVY_BOT = (43, 73, 100)  # 2B4964
MINT_HI = (52, 211, 153)  # 34D399
MINT_LO = (34, 184, 207)  # 22B8CF


def shield_points(cx, cy, w, h):
    """Shield outline: straight shoulders, curved sides meeting at a bottom tip."""
    pts = []
    steps = 240
    for i in range(steps + 1):  # right side, top -> tip
        t = i / steps
        hw = w / 2 if t < 0.42 else (w / 2) * math.sqrt(max(0.0, 1 - ((t - 0.42) / 0.58) ** 2))
        pts.append((cx + hw, cy - h / 2 + t * h))
    for i in range(steps + 1):  # left side, tip -> top
        t = 1 - i / steps
        hw = w / 2 if t < 0.42 else (w / 2) * math.sqrt(max(0.0, 1 - ((t - 0.42) / 0.58) ** 2))
        pts.append((cx - hw, cy - h / 2 + t * h))
    return pts


def gradient(size, top, bottom):
    img = Image.new("RGB", (1, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        d.point((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img.resize((size, size))


def draw_mark(size):
    """Transparent mark: mint gradient shield holding a navy data-node triad.

    The caller passes the size it wants; the supersample factor is applied once
    here so nested callers (the tile) cannot multiply it again.
    """
    return _draw_mark_px(size * S).resize((size, size), Image.LANCZOS)


def _draw_mark_px(px):
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).polygon(shield_points(px / 2, px / 2, px * 0.80, px * 0.90), fill=255)
    canvas.paste(gradient(px, MINT_HI, MINT_LO), (0, 0), mask)

    d = ImageDraw.Draw(canvas)
    nodes = [(px * 0.50, px * 0.34), (px * 0.365, px * 0.60), (px * 0.635, px * 0.60)]
    for a, b in ((0, 1), (0, 2), (1, 2)):
        d.line([nodes[a], nodes[b]], fill=NAVY_TOP + (255,), width=max(2, int(px * 0.022)))
    r = px * 0.052
    for x, y in nodes:
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 255))
        d.ellipse([x - r * 0.55, y - r * 0.55, x + r * 0.55, y + r * 0.55], fill=NAVY_TOP + (255,))

    return canvas


def draw_tile(size):
    """App tile: navy rounded square with the mark centred."""
    px = size * S
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, px - 1, px - 1], radius=px * 0.22, fill=255)
    canvas.paste(gradient(px, NAVY_TOP, NAVY_BOT), (0, 0), mask)
    # Draw the mark at full canvas resolution, then shrink it into place: the
    # downscale is where the edge quality comes from, so it must not be drawn
    # at the smaller size in the first place.
    mark = _draw_mark_px(px).resize((int(px * 0.62), int(px * 0.62)), Image.LANCZOS)
    canvas.paste(mark, ((px - mark.width) // 2, (px - mark.height) // 2), mark)
    return canvas.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    mark = draw_mark(512)
    mark.save(os.path.join(OUT, "tmewai_logo.png"))
    tile = draw_tile(1024)
    tile.save(os.path.join(OUT, "tmewai_app_icon.png"))
    tile.save(
        os.path.join(OUT, "tmewai.ico"),
        sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)],
    )
    # self-check: the mark is transparent outside the shield, the tile is solid
    assert mark.getpixel((2, 2))[3] == 0, "mark corner should be transparent"
    assert tile.getpixel((512, 512))[3] == 255, "tile centre should be opaque"
    print("wrote tmewai_logo.png, tmewai_app_icon.png, tmewai.ico to", OUT)


if __name__ == "__main__":
    main()
