#!/usr/bin/env /usr/bin/python3
"""ONE-SHOT (R17). Paints the Isle of Mourn as land: 40 x 45 squares at 20 px a square. The two-storey brick front across the north (the sanatorium's
forecourt side), a weathered dock jutting south into the lake with four rowboats, the dry owl fountain on the gravel forecourt, overgrown willows and
hedges, reeds and shallows round the rim.
    /usr/bin/python3 tools/content/memorys_rest_sketch.py docs/plans/mr_isle
    make sketch LAYOUT=docs/plans/mr_isle/layout.png HEIGHT=docs/plans/mr_isle/height.png SIZE=40x45 TOP=10 LOC=data/locations/mr_isle.json"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
S, W, H = 20, 40, 45
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plans/mr_isle"); OUT.mkdir(parents=True, exist_ok=True)
random.seed(1717)
WATER, WOODS, WALL, BRAMBLE, FENCE, OPEN = "#0000ff", "#006400", "#ff0000", "#8b4513", "#ffff00", "#e8e8e8"
lay = Image.new("RGB", (W * S, H * S), WATER); hei = Image.new("L", (W * S, H * S), 0)
L, Hd = ImageDraw.Draw(lay), ImageDraw.Draw(hei)

def blob(d, cx, cy, rx, ry, fill, wob=0.12, n=40, seed=None):
    r = random.Random(seed); pts = []
    for i in range(n):
        a = 2 * math.pi * i / n; k = 1 + r.uniform(-wob, wob)
        pts.append(((cx + math.cos(a) * rx * k) * S, (cy + math.sin(a) * ry * k) * S))
    d.polygon(pts, fill=fill)
def rect(x0, y0, x1, y1, fill): L.rectangle((x0 * S, y0 * S, (x1 + 1) * S - 1, (y1 + 1) * S - 1), fill=fill)

blob(L, 20, 22, 18, 20, OPEN, 0.1, seed=3)                     # the isle
blob(Hd, 20, 22, 17, 19, 90, 0.1, seed=3)
hei = hei.filter(ImageFilter.GaussianBlur(S * 1.5))
# the dock: a weathered jetty south into the water
rect(19, 38, 21, 43, OPEN)
rect(16, 41, 24, 41, OPEN)
# the brick front: a long block across the north, the iron doors at its south face
rect(8, 4, 31, 14, WALL)
# rim: reeds and willows (woods) all round the shore except the dock and the forecourt gravel
for (cx, cy, rx, ry) in [(4, 14, 3, 4), (4, 30, 3, 5), (36, 14, 3, 4), (36, 30, 3, 5), (11, 38, 5, 2), (29, 38, 5, 2), (6, 22, 2, 3), (34, 22, 2, 3), (20, 2, 8, 1.5), (7, 8, 3, 3), (33, 8, 3, 3)]:
    blob(L, cx, cy, rx, ry, WOODS, 0.25, seed=int(cx * 7 + cy))
# overgrown hedges along the forecourt
for (x0, y0, x1, y1) in [(9, 19, 15, 19), (25, 19, 31, 19), (9, 31, 14, 31), (26, 31, 31, 31)]:
    rect(x0, y0, x1, y1, BRAMBLE)
for (cx, cy) in [(12, 25), (28, 25), (13, 35), (27, 35), (16, 17), (24, 17)]:
    blob(L, cx, cy, 1.5, 1.2, BRAMBLE, 0.3, seed=cx + cy)
lay.save(OUT / "layout.png"); hei.save(OUT / "height.png")
print("wrote", OUT)
