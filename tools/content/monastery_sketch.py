#!/usr/bin/env /usr/bin/python3
"""ONE-SHOT. Paints Dawn's Gate (R14: a mining village in the Howlers' foothills, 60 x 50) and the monastery pass (30 x 60) as land.
    /usr/bin/python3 tools/content/monastery_sketch.py docs/plans/dawns_gate
then `make sketch HEIGHT=docs/plans/dawns_gate/gate_height.png LAYOUT=docs/plans/dawns_gate/gate_layout.png SIZE=60x50 TOP=45 LOC=data/locations/dawns_gate.json`
and the same for the pass (SIZE=30x60 TOP=90)."""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
S = 20
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plans/dawns_gate"); OUT.mkdir(parents=True, exist_ok=True)
random.seed(1414)
WATER, WOODS, ROCK, WALL, BRAMBLE, FENCE, OPEN = "#0000ff", "#006400", "#808080", "#ff0000", "#8b4513", "#ffff00", "#e8e8e8"


def canvas(w, h, base):
    lay = Image.new("RGB", (w * S, h * S), OPEN); hei = Image.new("L", (w * S, h * S), base)
    return lay, hei, ImageDraw.Draw(lay), ImageDraw.Draw(hei)


def blob(d, cx, cy, rx, ry, fill, wob=0.2, n=26, seed=None):
    r = random.Random(seed); pts = []
    for i in range(n):
        a = 2 * math.pi * i / n; k = 1 + r.uniform(-wob, wob)
        pts.append(((cx + math.cos(a) * rx * k) * S, (cy + math.sin(a) * ry * k) * S))
    d.polygon(pts, fill=fill)


def block(L, x0, y0, x1, y1, col=WALL): L.rectangle((x0 * S, y0 * S, (x1 + 1) * S - 1, (y1 + 1) * S - 1), fill=col)


def fence(L, x0, y0, x1, y1, gap=()):
    for (x, y) in [(x, y0) for x in range(x0, x1 + 1)] + [(x, y1) for x in range(x0, x1 + 1)] + [(x0, y) for y in range(y0, y1 + 1)] + [(x1, y) for y in range(y0, y1 + 1)]:
        if (x, y) not in gap: block(L, x, y, x, y, FENCE)


# ---- Dawn's Gate: 60 x 50; the land climbs to the north-west where the monastery pass leaves the village --------------------------------
W, H = 60, 50
lay, hei, L, Hd = canvas(W, H, 70)
for y in range(H * S): Hd.line((0, y, W * S, y), fill=int(150 - y * 0.12 * 1.0))   # higher in the north
blob(Hd, 10, 6, 14, 9, 235, 0.15)       # the shoulder the pass climbs
blob(Hd, 4, 24, 5, 6, 150, 0.2)         # the mine hill
hei = hei.filter(ImageFilter.GaussianBlur(S * 1.5)); Hd = ImageDraw.Draw(hei)
# slate cliffs and woods round the edge; the pass path is an open corridor at x 18..22 in the north
for (cx, cy, rx, ry) in [(30, 1, 16, 2.4), (52, 4, 8, 5), (58, 14, 3, 8), (2, 40, 4, 10), (30, 49, 22, 1.8), (57, 46, 4, 5), (8, 1, 6, 2)]:
    blob(L, cx, cy, rx, ry, WOODS, 0.25, seed=int(cx * 5 + cy))
for (cx, cy) in [(4, 14), (6, 17), (14, 3), (26, 3), (28, 5)]: blob(L, cx, cy, 2, 1.6, ROCK, 0.3, seed=cx + cy)
B = {"briar": (31, 30, 40, 36), "square_well": (28, 26, 29, 27)}
block(L, *B["briar"])                     # the Briar Public House
for (x0, y0, x1, y1) in [(20, 22, 24, 26), (22, 31, 26, 35), (42, 22, 47, 26), (44, 31, 49, 36), (14, 33, 18, 38), (38, 40, 44, 44), (24, 40, 30, 44),
                         (46, 12, 51, 17), (36, 14, 41, 19), (28, 12, 33, 17)]:
    block(L, x0, y0, x1, y1)              # homes, the hunters' lodge, the chandler
# the smelter and mine adits in the west (rock fronts with an open mouth)
block(L, 8, 22, 13, 27); block(L, 3, 30, 7, 35, ROCK); block(L, 3, 19, 6, 22, ROCK)
fence(L, 6, 28, 15, 30, gap=[(10, 28)])
fence(L, 33, 20, 46, 28 - 1, gap=[(40, 19 + 1)])      # nothing: kept off the square
L.rectangle((33 * S, 20 * S, 47 * S, 29 * S), fill=OPEN)
fence(L, 20, 40, 32, 46, gap=[(26, 40)]) if False else None
# the stream through the village, with a footbridge at y 28..29
for y in range(8, 50):
    xc = 50 + 2.5 * math.sin(y / 4.0) - max(0, y - 40) * 0.9
    block(L, int(xc - 1), y, int(xc), y, WATER)
L.rectangle((43 * S, 28 * S, 56 * S, 30 * S - 1), fill=OPEN)
# brambles and a few dead trees' copses
for (cx, cy) in [(12, 40), (34, 22), (54, 30), (17, 12)]: blob(L, cx, cy, 1.3, 1.1, BRAMBLE, 0.3, seed=cx + cy)
for (cx, cy, r) in [(10, 45, 1.8), (40, 8, 1.6), (50, 40, 1.6)]: blob(L, cx, cy, r, r, WOODS, 0.3, seed=cx * 3 + cy)
# the open hill path: clear the woods and cliffs on a corridor to the north-west
for y in range(0, 14):
    xc = 20 + 2 * math.sin(y / 2.4)
    L.rectangle((int((xc - 1.6) * S), y * S, int((xc + 1.8) * S), (y + 1) * S), fill=OPEN)
lay.save(OUT / "gate_layout.png"); hei.save(OUT / "gate_height.png")

# ---- the pass: 30 x 60, a zig-zag climb from the south (Dawn's Gate) to the north (the monastery gate) ------------------------------------
W, H = 30, 60
lay, hei, L, Hd = canvas(W, H, 60)
for y in range(H * S): Hd.line((0, y, W * S, y), fill=int(235 - y * (190 / (H * S))))
hei = hei.filter(ImageFilter.GaussianBlur(S * 1.0))
# rock and slate: heavy on both flanks, a winding open path between
L.rectangle((0, 0, W * S, H * S), fill=ROCK)
pts = []
for y in range(H - 1, -1, -1):
    xc = 15 + 7 * math.sin((H - y) / 7.0)
    wid = 3.2 + 0.6 * math.sin(y / 3.0)
    pts.append((xc, y, wid))
    L.rectangle((int((xc - wid) * S), y * S, int((xc + wid) * S), (y + 1) * S), fill=OPEN)
# a camp clearing at about y 30, and a copse of dead trees (woods) beside it, a bluff before the gate
blob(L, pts[H - 31][0] + 0.0, 30, 6, 4.2, OPEN, 0.1, seed=1)
for (cx, cy, rx, ry) in [(5, 33, 3.5, 4), (24, 27, 3, 3.5), (6, 12, 3, 3), (25, 46, 3, 4)]: blob(L, cx, cy, rx, ry, WOODS, 0.3, seed=cx + cy)
blob(L, 15, 4, 8, 3.2, OPEN, 0.1, seed=3)       # the apron before the monastery gate
lay.save(OUT / "pass_layout.png"); hei.save(OUT / "pass_height.png")
print("wrote", OUT)
