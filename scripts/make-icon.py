#!/usr/bin/env python3
"""Draws Lensir's app icon: four white corner brackets on near-black, with a
small white lens dot in the middle, like the scanner waiting for a code.

    python3 scripts/make-icon.py            # writes Lensir/Assets.xcassets/AppIcon.appiconset/AppIcon.png
    python3 scripts/make-icon.py out.png    # or anywhere else

Drawn at 4x and scaled down, so every edge is antialiased. Needs Pillow.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4
S = SIZE * SCALE

BACKGROUND = "#0B0B0C"  # near-black, the camera with nothing in front of it
WHITE = "#FFFFFF"

# The brackets: a square window, thick strokes with round ends, each corner
# an arc with a straight arm off both sides. Heavy enough to read at 60 px.
WINDOW = 560
STROKE = 68
RADIUS = 96   # of the stroke's centre line
ARM = 156     # from the corner, along each edge
DOT = 64      # radius of the lens dot


def px(value: float) -> int:
    return round(value * SCALE)


def draw(out: Path) -> None:
    image = Image.new("RGB", (S, S), BACKGROUND)
    d = ImageDraw.Draw(image)

    left = top = (SIZE - WINDOW) / 2
    right = bottom = left + WINDOW
    half = STROKE / 2

    # One rounded outline, so arcs and arms join without seams...
    d.rounded_rectangle([px(left - half), px(top - half), px(right + half), px(bottom + half)],
                        radius=px(RADIUS + half), outline=WHITE, width=px(STROKE))
    # ...then cut the middle out of each side, leaving the four corners...
    gap_from, gap_to = left + ARM, right - ARM
    d.rectangle([px(gap_from), px(top - STROKE), px(gap_to), px(top + STROKE)], fill=BACKGROUND)
    d.rectangle([px(gap_from), px(bottom - STROKE), px(gap_to), px(bottom + STROKE)], fill=BACKGROUND)
    d.rectangle([px(left - STROKE), px(gap_from), px(left + STROKE), px(gap_to)], fill=BACKGROUND)
    d.rectangle([px(right - STROKE), px(gap_from), px(right + STROKE), px(gap_to)], fill=BACKGROUND)
    # ...and round the cut ends.
    for x, y in ((gap_from, top), (gap_to, top), (gap_from, bottom), (gap_to, bottom),
                 (left, gap_from), (left, gap_to), (right, gap_from), (right, gap_to)):
        d.ellipse([px(x - half), px(y - half), px(x + half), px(y + half)], fill=WHITE)

    c = SIZE / 2
    d.ellipse([px(c - DOT), px(c - DOT), px(c + DOT), px(c + DOT)], fill=WHITE)

    image.resize((SIZE, SIZE), Image.LANCZOS).save(out)
    print(f"wrote {out}")


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "Lensir/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    draw(target)
