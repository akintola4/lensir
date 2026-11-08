#!/usr/bin/env python3
"""Draws LaunchMark.svg and LaunchMark-light.svg, the launch screen's mark
in dark and light: four corner brackets and a
lens dot, at the exact size the splash starts from.

    python3 scripts/make-launch-mark.py

The numbers are SplashLogic.Mark's (side 111, stroke 5, corner radius 18,
arm 32, dot radius 11), and SplashLogicTests checks the SVG against them,
so change both together. The brackets are the outline of the scanner's
BracketsShape stroked 5 pt with round caps: an arc at each corner with a
straight arm off both ends.
"""

from pathlib import Path

SIDE, STROKE, RADIUS, ARM, DOT = 111, 5, 18, 32, 11
IMAGE = SIDE + STROKE
o = STROKE / 2                 # the square's centre line starts half a stroke in
lo, hi = o, o + SIDE


def n(v: float) -> str:
    return f"{v:g}"


h = STROKE / 2
c = IMAGE / 2


def rotate(x: float, y: float, quarter: int) -> tuple[float, float]:
    """Rotates (x, y) about the centre by quarter turns, clockwise on screen."""
    for _ in range(quarter):
        x, y = c - (y - c), x
    return x, y


def bracket(quarter: int) -> str:
    """The top-left bracket as a filled outline (outer arc, round cap, inner
    arc, round cap), turned to each corner. Fills, not a stroke: the launch
    screen's renderer drops stroked paths."""
    # (command, points...) with arcs as (radius, sweep, end point)
    steps = [
        ("M", (lo - h, lo + ARM)),
        ("L", (lo - h, lo + RADIUS)),
        ("A", RADIUS + h, 1, (lo + RADIUS, lo - h)),
        ("L", (lo + ARM, lo - h)),
        ("A", h, 1, (lo + ARM, lo + h)),
        ("L", (lo + RADIUS, lo + h)),
        ("A", RADIUS - h, 0, (lo + h, lo + RADIUS)),
        ("L", (lo + h, lo + ARM)),
        ("A", h, 1, (lo - h, lo + ARM)),
    ]
    out = []
    for step in steps:
        if step[0] == "A":
            _, r, sweep, (x, y) = step
            x, y = rotate(x, y, quarter)
            out.append(f"A{n(r)} {n(r)} 0 0 {sweep} {n(x)} {n(y)}")
        else:
            x, y = rotate(*step[1], quarter)
            out.append(f"{step[0]}{n(x)} {n(y)}")
    return "".join(out) + "Z"


def svg(ink: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{n(IMAGE)}" height="{n(IMAGE)}" viewBox="0 0 {n(IMAGE)} {n(IMAGE)}">
  <path d="{''.join(bracket(q) for q in range(4))}" fill="{ink}"/>
  <circle cx="{n(c)}" cy="{n(c)}" r="{DOT}" fill="{ink}"/>
</svg>
'''


# White on the black launch screen in dark mode, black on white in light.
folder = Path(__file__).resolve().parent.parent / "Lensir/Assets.xcassets/LaunchMark.imageset"
for name, ink in (("LaunchMark.svg", "#FFFFFF"), ("LaunchMark-light.svg", "#000000")):
    (folder / name).write_text(svg(ink))
    print(f"wrote {folder / name}")
