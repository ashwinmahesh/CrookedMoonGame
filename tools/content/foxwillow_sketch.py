#!/usr/bin/env /usr/bin/python3
"""ONE-SHOT. Paints Foxwillow (R13) as land: 64 x 56 squares at 20 px a square. Magpie Square in the middle with its stone flock, the pump west of it,
the windmill on a bluff above a creek ravine in the south-west, the school, the Hooded Lantern, the store, the butcher, the library and the town hall
round the square, the farmhouse courtyard north-east, fields and pens between, and the tall corn wall along the east edge with one gateway.
    /usr/bin/python3 tools/content/foxwillow_sketch.py docs/plans/foxwillow
    make sketch HEIGHT=docs/plans/foxwillow/height.png LAYOUT=docs/plans/foxwillow/layout.png SIZE=64x56 TOP=40 LOC=data/locations/foxwillow.json"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
S, W, H = 20, 64, 56
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plans/foxwillow"); OUT.mkdir(parents=True, exist_ok=True)
random.seed(1313)
WATER, WOODS, ROCK, WALL, BRAMBLE, FENCE, OPEN = "#0000ff", "#006400", "#808080", "#ff0000", "#8b4513", "#ffff00", "#e8e8e8"
lay = Image.new("RGB", (W * S, H * S), OPEN); hei = Image.new("L", (W * S, H * S), 80)
L, Hd = ImageDraw.Draw(lay), ImageDraw.Draw(hei)

def blob(d, cx, cy, rx, ry, fill, wob=0.2, n=26, seed=None):
    r = random.Random(seed); pts = []
    for i in range(n):
        a = 2 * math.pi * i / n; k = 1 + r.uniform(-wob, wob)
        pts.append(((cx + math.cos(a) * rx * k) * S, (cy + math.sin(a) * ry * k) * S))
    d.polygon(pts, fill=fill)
def block(x0, y0, x1, y1): L.rectangle((x0 * S, y0 * S, (x1 + 1) * S - 1, (y1 + 1) * S - 1), fill=WALL)
def fence(x0, y0, x1, y1, gap=()):
    for (x, y) in [(x, y0) for x in range(x0, x1 + 1)] + [(x, y1) for x in range(x0, x1 + 1)] + [(x0, y) for y in range(y0, y1 + 1)] + [(x1, y) for y in range(y0, y1 + 1)]:
        if (x, y) not in gap: L.rectangle((x * S, y * S, (x + 1) * S - 1, (y + 1) * S - 1), fill=FENCE)

# height: gentle, the windmill bluff in the south-west (high), the creek ravine cut beside it, the farm a little raised
for y in range(H * S): Hd.line((0, y, W * S, y), fill=int(70 + 25 * math.sin(y / 260)))
blob(Hd, 11, 43, 8, 7, 250, 0.1)
blob(Hd, 54, 10, 8, 6, 130, 0.15)
blob(Hd, 22, 47, 3, 12, 20, 0.15)       # the ravine
hei = hei.filter(ImageFilter.GaussianBlur(S * 1.2))
# the corn wall: a thick wandering band of woods along the east edge, one gateway at y 27..29
for y in range(H):
    x0 = 58 + int(2 * math.sin(y / 3.1)) + (1 if y % 5 == 0 else 0)
    if 26 <= y <= 30: continue
    L.rectangle((x0 * S, y * S, W * S, (y + 1) * S), fill=WOODS)
for (cx, cy, rx, ry) in [(1, 10, 2.2, 9), (2, 30, 2.5, 8), (1, 50, 3, 6), (30, 54, 12, 2), (58, 52, 6, 3), (30, 1, 14, 1.8), (4, 3, 5, 3)]:
    blob(L, cx, cy, rx, ry, WOODS, 0.25, seed=int(cx * 5 + cy))
# the creek ravine: water running down the south-west, bending east at the bottom
for y in range(30, 56):
    xc = 21 + 2 * math.sin(y / 3.5) + max(0, y - 46) * 1.2
    L.rectangle((int((xc - 1.2) * S), y * S, int((xc + 1.4) * S), (y + 1) * S), fill=WATER)
# a footbridge: open ground across the creek at y 36..37
L.rectangle((17 * S, 36 * S, 27 * S, 38 * S - 1), fill=OPEN)
B = {"windmill": (9, 40, 13, 44), "school": (22, 13, 27, 18), "lantern": (30, 12, 38, 18), "store": (41, 17, 47, 22), "butcher": (42, 29, 48, 34),
     "library": (13, 23, 18, 28), "hall": (24, 33, 32, 39), "farmhouse": (50, 5, 57, 11)}
for (x0, y0, x1, y1) in B.values(): block(x0, y0, x1, y1)
for (x0, y0, x1, y1) in [(34, 40, 38, 44), (40, 40, 45, 45), (6, 28, 10, 33), (48, 38, 52, 43), (5, 14, 9, 19)]: block(x0, y0, x1, y1)   # homes
fence(21, 12, 28, 21, gap=[(24, 21)])                    # schoolyard
fence(41, 28, 49, 37, gap=[(45, 28)])                    # the butcher's pens
fence(48, 4, 59, 14, gap=[(53, 14)])                     # farmhouse courtyard
fence(8, 39, 14, 46, gap=[(11, 46)])                     # the mill yard
for (cx, cy) in [(36, 30), (44, 12), (12, 20), (30, 45)]: blob(L, cx, cy, 1.2, 1.0, BRAMBLE, 0.3, seed=cx + cy)
for (cx, cy, r) in [(18, 8, 1.6), (52, 24, 1.8), (33, 49, 1.4), (6, 36, 1.4), (46, 48, 1.7)]: blob(L, cx, cy, r, r * 1.2, WOODS, 0.3, seed=cx * 3 + cy)
# hay stooks (low cover) scattered in the fields
for (cx, cy) in [(50, 20), (52, 21), (53, 25), (49, 45), (54, 46), (8, 8), (20, 5), (56, 33)]: blob(L, cx, cy, 0.9, 0.7, FENCE, 0.2, seed=cx + cy)
lay.save(OUT / "layout.png"); hei.save(OUT / "height.png")
prev = lay.copy(); D = ImageDraw.Draw(prev)
for k, (x0, y0, x1, y1) in B.items(): D.text((x0 * S + 4, y0 * S + 4), k, fill="white")
D.ellipse(((30 - 6) * S, (26 - 6) * S, (30 + 6) * S, (26 + 6) * S), outline="black", width=3); D.text((27 * S, 25 * S), "Magpie Square", fill="black")
prev.save(OUT / "preview_labelled.png"); print("wrote", OUT)
