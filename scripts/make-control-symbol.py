#!/usr/bin/env python3
"""Draws lensir.viewfinder.svg, the custom SF Symbol on the Control Center
control: Lensir's four corner brackets and lens dot.

    python3 scripts/make-control-symbol.py

It's an SF Symbols template (v4.0) with three masters, Ultralight, Regular
and Black, at the small scale; iOS interpolates every other weight and scale
from them. The brackets keep the launch mark's proportions (corner 18, arm
32, dot 11 on a 111 side), and each master is the same outline with a
different stroke, so they interpolate cleanly. The glyph sits on the cap
height like SF's own viewfinder.
"""

from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / \
    "LensirWidget/Assets.xcassets/lensir.viewfinder.symbolset/lensir.viewfinder.svg"

CAP = 70.459          # cap height at 100 pt, from Apple's template
SIDE = 76.0           # the glyph's outer edge, a little past the cap height
CORNER, ARM, DOT = 18 / 111, 32 / 111, 11 / 111
MARGIN = 4.0          # side bearing each side

# (master, x of its left margin in the template, stroke, dot radius)
MASTERS = [
    ("Ultralight-S", 508.0, 2.2, SIDE * DOT * 0.85),
    ("Regular-S", 1396.0, 7.0, SIDE * DOT),
    ("Black-S", 2877.0, 12.0, SIDE * DOT * 1.3),
]
BASELINE_S = 696


def n(v: float) -> str:
    return f"{round(v, 4):g}"


def glyph(stroke: float, dot: float) -> str:
    """The outline, in glyph space: origin on the left margin and baseline,
    y down (so above the baseline is negative)."""
    h = stroke / 2
    left = MARGIN + h                       # the brackets' centre line
    top = -(CAP / 2 + SIDE / 2) + h
    side = SIDE - stroke
    r = SIDE * CORNER
    arm = SIDE * ARM
    cx, cy = left + side / 2, top + side / 2

    def bracket(sx: int, sy: int) -> str:
        # Top-left bracket drawn around (0, 0) = the square's corner, then
        # mirrored into place. A mirror flips the arcs' direction.
        def p(x: float, y: float) -> str:
            px = cx + sx * (x - side / 2)
            py = cy + sy * (y - side / 2)
            return f"{n(px)} {n(py)}"
        cw, ccw = ("1", "0") if sx * sy > 0 else ("0", "1")
        return (
            f"M{p(-h, arm)}"
            f"L{p(-h, r)}"
            f"A{n(r + h)} {n(r + h)} 0 0 {cw} {p(r, -h)}"
            f"L{p(arm, -h)}"
            f"A{n(h)} {n(h)} 0 0 {cw} {p(arm, h)}"
            f"L{p(r, h)}"
            f"A{n(r - h)} {n(r - h)} 0 0 {ccw} {p(h, r)}"
            f"L{p(h, arm)}"
            f"A{n(h)} {n(h)} 0 0 {cw} {p(-h, arm)}Z"
        )

    brackets = "".join(bracket(sx, sy) for sx, sy in [(1, 1), (-1, 1), (-1, -1), (1, -1)])
    lens = (f"M{n(cx - dot)} {n(cy)}"
            f"A{n(dot)} {n(dot)} 0 1 1 {n(cx + dot)} {n(cy)}"
            f"A{n(dot)} {n(dot)} 0 1 1 {n(cx - dot)} {n(cy)}Z")
    return brackets + lens


def line(id_: str, y: float) -> str:
    return (f'  <line id="{id_}" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" '
            f'x1="263" x2="3036" y1="{n(y)}" y2="{n(y)}"/>\n')


def margins(name: str, x: float) -> str:
    width = SIDE + 2 * MARGIN
    out = ""
    for side, at in (("left", x), ("right", x + width)):
        out += (f'  <line id="{side}-margin-{name}" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" '
                f'x1="{n(at)}" x2="{n(at)}" y1="600.785" y2="720.121"/>\n')
    return out


svg = ['<?xml version="1.0" encoding="UTF-8"?>\n',
       '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n',
       '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">\n',
       ' <g id="Notes">\n',
       '  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>\n',
       '  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;" transform="matrix(1 0 0 1 3036 1933)">Template v.4.0</text>\n',
       '  <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;" transform="matrix(1 0 0 1 3036 1969)">lensir.viewfinder</text>\n',
       ' </g>\n',
       ' <g id="Guides">\n']
for scale, baseline in (("S", 696), ("M", 1126), ("L", 1556)):
    svg.append(line(f"Baseline-{scale}", baseline))
    svg.append(line(f"Capline-{scale}", baseline - CAP))
for name, x, _, _ in MASTERS:
    svg.append(margins(name, x))
svg.append(' </g>\n <g id="Symbols">\n')
for name, x, stroke, dot in MASTERS:
    svg.append(f'  <g id="{name}" transform="matrix(1 0 0 1 {n(x)} {BASELINE_S})">\n')
    svg.append(f'   <path d="{glyph(stroke, dot)}"/>\n')
    svg.append('  </g>\n')
svg.append(' </g>\n</svg>\n')

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("".join(svg))
(OUT.parent / "Contents.json").write_text(
    '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  },\n'
    '  "symbols" : [\n    {\n      "filename" : "lensir.viewfinder.svg",\n      "idiom" : "universal"\n    }\n  ]\n}\n')
print(f"wrote {OUT}")
