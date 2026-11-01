#!/usr/bin/env /usr/bin/python3
"""ONE-SHOT. Paints R16's two outdoor places as land, 20 px a square: sk_camp (Glitterdeep's mining camp, 50 x 28: the west ridge with the old drift's mouth,
the warehouse, the machine shop, the shaft head with its headframe, scree and rails, the road out east) and sk_hills_trail (the hill road, 48 x 24, a wooded
cut with a clearing where the road bends). Then:
    /usr/bin/python3 tools/content/skitterdeep_sketch.py docs/plans/skitterdeep
    make sketch HEIGHT=docs/plans/skitterdeep/camp_height.png LAYOUT=docs/plans/skitterdeep/camp_layout.png SIZE=50x28 TOP=40 LOC=data/locations/sk_camp.json
    make sketch HEIGHT=docs/plans/skitterdeep/trail_height.png LAYOUT=docs/plans/skitterdeep/trail_layout.png SIZE=48x24 TOP=30 LOC=data/locations/sk_hills_trail.json"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
S = 20
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plans/skitterdeep"); OUT.mkdir(parents=True, exist_ok=True)
WATER, WOODS, ROCK, WALL, BRAMBLE, FENCE, OPEN, VOID = "#0000ff", "#006400", "#808080", "#ff0000", "#8b4513", "#ffff00", "#e8e8e8", "#000000"


def blob(d, cx, cy, rx, ry, fill, wob=0.2, n=26, seed=None):
    r = random.Random(seed); pts = []
    for i in range(n):
        a = 2 * math.pi * i / n; k = 1 + r.uniform(-wob, wob)
        pts.append(((cx + math.cos(a) * rx * k) * S, (cy + math.sin(a) * ry * k) * S))
    d.polygon(pts, fill=fill)


def rect(d, x0, y0, x1, y1, fill):
    d.rectangle((x0 * S, y0 * S, (x1 + 1) * S - 1, (y1 + 1) * S - 1), fill=fill)


def camp():
    W, H = 50, 28
    random.seed(1616)
    lay = Image.new("RGB", (W * S, H * S), OPEN); hei = Image.new("L", (W * S, H * S), 70)
    L, Hd = ImageDraw.Draw(lay), ImageDraw.Draw(hei)
    # the ground: the west ridge is high, the camp a flat shelf, the hills rise again in the east and north
    for x in range(W * S):
        Hd.line((x, 0, x, H * S), fill=int(70 + 150 * max(0, 1 - x / (11 * S)) + 25 * math.sin(x / 180)))
    blob(Hd, 44, 3, 8, 5, 170, 0.2); blob(Hd, 5, 13, 4, 4, 120, 0.1)
    hei = hei.filter(ImageFilter.GaussianBlur(S * 1.1))
    # the west ridge: rock, with a notch for the old drift's mouth at y 12..14
    rect(L, 0, 0, 5, 27, ROCK)
    rect(L, 2, 12, 5, 14, OPEN)
    rect(L, 6, 0, 7, 10, ROCK); rect(L, 6, 16, 7, 27, ROCK)
    for (cx, cy, rx, ry) in [(25, 0.5, 26, 1.8), (25, 27, 26, 2), (46, 3, 4, 3), (47, 24, 4, 3.5), (48, 8, 3, 3), (14, 26, 5, 2)]:
        blob(L, cx, cy, rx, ry, WOODS, 0.3, seed=int(cx * 7 + cy))
    rect(L, 46, 12, 49, 15, OPEN)                      # the road out east
    # the warehouse (the old store, 15 x 7), the machine shop (13 x 7), and a ruined pump house
    rect(L, 9, 3, 23, 9, WALL); rect(L, 27, 3, 39, 9, WALL); rect(L, 14, 19, 18, 22, WALL)
    # scree: in front of the warehouse, round the shaft head, along the rails
    for (cx, cy, rx, ry) in [(16, 12, 5, 1.6), (34, 17, 6.5, 3.2), (24, 15, 3, 1.4), (11, 15, 1.8, 1.2), (30, 22, 4, 1.4), (42, 22, 2.4, 1.4)]:
        blob(L, cx, cy, rx, ry, BRAMBLE, 0.3, seed=int(cx * 3 + cy))
    # the shaft head: a three by three drop with no bottom (the headframe stands on its east edge)
    rect(L, 40, 15, 42, 17, VOID)
    # ore-cart cover along the rail from the drift to the shaft, a collapsed fence round the camp
    for (x0, y0, x1, y1) in [(9, 13, 9, 13), (12, 14, 12, 14), (22, 14, 22, 14), (26, 12, 26, 12), (30, 13, 30, 13), (33, 20, 34, 20), (44, 19, 45, 19), (20, 24, 22, 24)]:
        rect(L, x0, y0, x1, y1, FENCE)
    lay.save(OUT / "camp_layout.png"); hei.save(OUT / "camp_height.png")


def trail():
    W, H = 48, 24
    random.seed(1617)
    lay = Image.new("RGB", (W * S, H * S), OPEN); hei = Image.new("L", (W * S, H * S), 60)
    L, Hd = ImageDraw.Draw(lay), ImageDraw.Draw(hei)
    for y in range(H * S):
        Hd.line((0, y, W * S, y), fill=int(60 + 40 * math.sin(y / 120)))
    blob(Hd, 10, 5, 8, 4, 190, 0.2); blob(Hd, 38, 19, 9, 4, 170, 0.2)
    hei = hei.filter(ImageFilter.GaussianBlur(S * 1.3))
    # wooded hills north and south of the road; the road wanders (open) from x 0 to x 47 near y 11..12, with a clearing at x 20..28
    road = lambda x: 11 + 2.0 * math.sin(x / 6.5)
    for x in range(W):
        yc = road(x)
        rect(L, x, 0, x, int(yc - 6.5), WOODS); rect(L, x, int(yc + 7.5), x, H - 1, WOODS)
    for (cx, cy, rx, ry) in [(10, 4, 4, 2), (38, 20, 4, 1.6), (5, 19, 3, 2)]:
        blob(L, cx, cy, rx, ry, WOODS, 0.3, seed=int(cx + cy))
    # rocks and brambles beside the road, a fallen log and cairn for cover
    for (cx, cy) in [(7, 8), (15, 15), (32, 8), (40, 14), (44, 9), (3, 15)]:
        blob(L, cx, cy, 1.4, 1.0, ROCK, 0.3, seed=cx * cy)
    for (cx, cy) in [(12, 9), (19, 14), (30, 14), (36, 9), (28, 7)]:
        blob(L, cx, cy, 1.2, 0.8, BRAMBLE, 0.3, seed=cx + cy)
    for (x0, y0, x1, y1) in [(17, 8, 18, 8), (26, 15, 27, 15), (22, 6, 23, 6), (22, 17, 23, 17)]:
        rect(L, x0, y0, x1, y1, FENCE)
    # keep the ends of the road open
    rect(L, 0, 8, 2, 13, OPEN); rect(L, 45, 9, 47, 14, OPEN)
    lay.save(OUT / "trail_layout.png"); hei.save(OUT / "trail_height.png")


if __name__ == "__main__":
    camp(); trail(); print("wrote", OUT)
