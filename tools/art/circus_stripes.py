#!/usr/bin/env python3
"""Paints the Circus Car's floor boards in faded circus stripes (Ashwin, 2026-11-03: circus flooring, red and cream): Poly Haven's
White Planks Clean (CC0, art/sourced/polyhaven_white_planks_clean, kept untouched) with every board tinted, one crimson then two
vellum, in the palette's colours (art/palette/palette.json), the wood's grain, knots and grooves kept. The tile holds 21 boards,
so one red to two cream repeats seven times across it and the stripes tile without a seam. Writes
art/textures/props/circus_stripes_diff.jpg; the source's own normal and roughness maps go with it.
  /usr/bin/python3 tools/art/circus_stripes.py     (needs PIL)
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "art/sourced/polyhaven_white_planks_clean/white_planks_clean_diff_2k.jpg")
OUT = os.path.join(ROOT, "art/textures/props/circus_stripes_diff.jpg")
# The boards: the first groove's middle and the pitch from one board to the next (pixels in the 2048 px tile, measured).
FIRST = 3.0
PITCH = 2048.0 / 21.0
PATTERN = ["crimson", "vellum", "vellum"]
# How much of the paint shows over the bare wood (worn, faded: some grain shows through).
PAINT = 0.72


def colour(name):
    pal = json.load(open(os.path.join(ROOT, "art/palette/palette.json")))
    pal = pal.get("colors", pal.get("colours", pal))
    h = pal[name].lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def main():
    src = Image.open(SOURCE).convert("RGB")
    w, h = src.size
    paints = [colour(n) for n in PATTERN]
    px = src.load()
    out = Image.new("RGB", (w, h))
    po = out.load()
    for x in range(w):
        board = int(((x - FIRST) % w) // PITCH)
        c = paints[board % len(paints)]
        for y in range(h):
            r, g, b = px[x, y]
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            shade = min(1.0, lum * 1.15)   # the wood's light and dark under the paint: grain, knots, grooves
            po[x, y] = tuple(int(255 * ((1 - PAINT) * (v / 255.0) + PAINT * c[i] * shade)) for i, v in enumerate((r, g, b)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT, quality=90)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
