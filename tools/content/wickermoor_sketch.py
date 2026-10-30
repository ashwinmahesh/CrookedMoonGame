#!/usr/bin/env /usr/bin/python3
"""Paints Wickermoor Village as land (R11): a height picture and a layout drawing for the engine's sketch tool (make sketch).
The village is 60 x 50 squares (5 ft each); the drawing is 20 px a square so edges can wander. Buildings are solid blocks (the
rooms are their own maps, entered at a door square); everything else is the land: the Silverbell along the south edge, the
Round in the middle, the estate's hill in the north-west, the dovecote's mound in the north, woods closing in on three sides.
    /usr/bin/python3 tools/content/wickermoor_sketch.py docs/plans/wickermoor
Then: make sketch HEIGHT=docs/plans/wickermoor/height.png LAYOUT=docs/plans/wickermoor/layout.png SIZE=60x50 TOP=40 LOC=data/locations/wickermoor_village.json"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

S = 20                 # pixels a square
W, H = 60, 50
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plans/wickermoor")
OUT.mkdir(parents=True, exist_ok=True)
random.seed(1031)

WATER, WOODS, ROCK, WALL, BRAMBLE, FENCE, VOID, OPEN = "#0000ff", "#006400", "#808080", "#ff0000", "#8b4513", "#ffff00", "#000000", "#e8e8e8"

lay = Image.new("RGB", (W * S, H * S), OPEN)
hei = Image.new("L", (W * S, H * S), 70)
L = ImageDraw.Draw(lay)
Hd = ImageDraw.Draw(hei)


def sq(x, y):          # a square's centre in pixels
    return (x * S + S // 2, y * S + S // 2)


def blob(draw, cx, cy, rx, ry, fill, wobble=0.18, n=28, seed=None):
    r = random.Random(seed)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + r.uniform(-wobble, wobble)
        pts.append(((cx + math.cos(a) * rx * k) * S, (cy + math.sin(a) * ry * k) * S))
    draw.polygon(pts, fill=fill)


def block(x0, y0, x1, y1, door=None):
    """A building: a solid block of squares x0..x1, y0..y1 (inclusive)."""
    L.rectangle((x0 * S, y0 * S, (x1 + 1) * S - 1, (y1 + 1) * S - 1), fill=WALL)


def fence(x0, y0, x1, y1, gap=None):
    """A wattle fence round a rectangle, one square thick, with a gap square (x, y) left open."""
    pts = [(x, y0) for x in range(x0, x1 + 1)] + [(x, y1) for x in range(x0, x1 + 1)] + [(x0, y) for y in range(y0, y1 + 1)] + [(x1, y) for y in range(y0, y1 + 1)]
    for (x, y) in pts:
        if gap and (x, y) in gap:
            continue
        L.rectangle((x * S, y * S, (x + 1) * S - 1, (y + 1) * S - 1), fill=FENCE)


def road(points, width, draw=None):
    pass   # roads are open ground: nothing is drawn; they are where nothing else is


def hill(cx, cy, r, level):
    blob(Hd, cx, cy, r, r * 0.85, level, wobble=0.1)


# ---- height: the land ----------------------------------------------------------------------------------------------
# a gentle rise to the north moor, the Silverbell lying lowest in the south, the estate hill north-west, the dovecote mound north
for y in range(H * S):
    for x in range(0, W * S, S):
        t = 1 - y / (H * S)                      # 0 south .. 1 north
        base = int(40 + 60 * t)
        Hd.rectangle((x, y, x + S, y), fill=base)
hill(8, 7, 11, 255)          # the estate's hill, the highest ground
hill(44, 4, 5, 205)          # the dovecote's mound
blob(Hd, 30, 24, 9, 8, 85, wobble=0.08)   # the Round is a shallow trodden bowl
blob(Hd, 30, 49, 40, 3, 0, wobble=0.08)   # the river's bed
hei = hei.filter(ImageFilter.GaussianBlur(S * 1.1))

# ---- layout ----------------------------------------------------------------------------------------------------------
# woods close in on the west, east, and the south bank; the moor in the north stays open
for (cx, cy, rx, ry) in [(1, 20, 2.2, 9), (1, 40, 2.4, 8), (58, 14, 2.4, 9), (58, 30, 2.2, 7), (57, 44, 3, 5), (4, 46, 5, 4), (20, 48, 5, 2.2), (40, 48.6, 5, 2), (0, 4, 3, 5)]:
    blob(L, cx, cy, rx, ry, WOODS, wobble=0.25, seed=int(cx * 7 + cy))
# stands of trees inside
for (cx, cy, r) in [(14, 20, 1.8), (41, 46, 1.6), (26, 40, 1.6), (52, 7, 1.8), (24, 6, 1.6), (14, 31, 1.6)]:
    blob(L, cx, cy, r, r * 1.2, WOODS, wobble=0.3, seed=int(cx * 3 + cy))
# the Silverbell: wandering along the south edge, east to west, a footbridge gap left in the south road at x 30
for x in range(0, W * S):
    t = x / S
    yc = 47.6 + math.sin(t / 5.5) * 0.9 + math.sin(t / 2.3) * 0.25
    L.rectangle((x, int((yc - 1.3) * S), x + 1, int((yc + 1.7) * S)), fill=WATER)
# the bridge: open ground across the river
L.rectangle((29 * S, 45 * S, 32 * S - 1, 50 * S - 1), fill=OPEN)

# buildings (x0, y0, x1, y1), inclusive: the book's map 11.2 redrawn with room to walk between them
B = {
    "inn":        (16, 27, 25, 33),   # V1 Green Queen Inn, south-west of the Round
    "trading":    (16, 21, 21, 26),   # V5 joined to the inn's north end
    "stables":    (20, 38, 26, 41),   # V2 behind the inn
    "mayor":      (38, 27, 47, 34),   # V4 Mayor's home and office, south-east of the Round (the clocktower rises from it)
    "barber":     (20, 11, 25, 16),   # V7
    "tailor":     (27, 9, 30, 16),    # V18 narrow and tall
    "bakery":     (32, 11, 37, 16),   # V14
    "constable":  (40, 10, 48, 16),   # V3
    "post":       (31, 3, 37, 7),     # V20
    "dovecote":   (42, 3, 45, 6),     # V21 a round tower on its mound
    "pavilion":   (17, 10, 18, 11),   # V28 a gazebo
    "church":     (5, 25, 10, 29),    # V19 roofless walls, new framing
    "school":     (4, 14, 9, 18),     # V8
    "books":      (12, 16, 15, 22),   # V23 narrow and tall
    "smithy":     (2, 34, 5, 38),     # V16
    "apothecary": (8, 34, 12, 38),    # V6
    "wickery":    (14, 35, 18, 40),   # V17 beside the butcher
    "harga":      (8, 41, 12, 45),    # V15
    "masonry":    (51, 18, 57, 23),   # V12
    "carpentry":  (51, 25, 57, 30),   # V13
    "funeral":    (44, 39, 49, 44),   # V22 south-east, toward the bridge to Maidenmist
    "pyethymer":  (53, 42, 57, 45),   # V26 at the end of the lane of houses
    "estate":     (5, 3, 12, 8),      # V24 the manor on its hill
}
for k, (x0, y0, x1, y1) in B.items():
    block(x0, y0, x1, y1)
# houses (V27): south of the Round, and along the east lane
for (x0, y0, x1, y1) in [(28, 38, 32, 42), (34, 38, 38, 42), (51, 33, 52, 36), (56, 33, 57, 36), (51, 38, 52, 40), (56, 38, 57, 40)]:
    block(x0, y0, x1, y1)
# fences: constable's yard, the schoolyard, the stable paddock, the church yard, the estate's wall, the butcher's pens, Pyethymer
fence(39, 9, 49, 18, gap=[(44, 18)])
fence(3, 13, 10, 20, gap=[(7, 20)])
fence(19, 36, 28, 43, gap=[(23, 36)])
fence(3, 23, 12, 31, gap=[(8, 31)])
fence(3, 1, 14, 10, gap=[(13, 10), (14, 10)])
fence(7, 46, 14, 46, gap=[(10, 46)])
fence(52, 41, 58, 46, gap=[(55, 41)])
# stone heaps in the mason's yard, log piles and stumps at the carpenter's, brambles at the lanes' ends
for (cx, cy) in [(50, 21), (50, 24), (58, 24)]:
    blob(L, cx, cy, 0.9, 0.9, ROCK, wobble=0.3, seed=cx + cy)
for (cx, cy) in [(49, 30), (58, 32), (49, 36)]:
    blob(L, cx, cy, 1, 0.8, FENCE, wobble=0.2, seed=cx + cy)
for (cx, cy) in [(54, 47), (2, 11), (26, 3), (38, 1), (49, 46)]:
    blob(L, cx, cy, 1.3, 1, BRAMBLE, wobble=0.35, seed=cx + cy)
# the moor road's ditch, in broken lengths
for i in range(16):
    x = 17 + i * 2
    L.rectangle((x * S, 1 * S, (x + 1) * S - 1, 2 * S - 1), fill=BRAMBLE)

# a labelled preview for the eye
prev = lay.copy()
D = ImageDraw.Draw(prev)
for k, (x0, y0, x1, y1) in B.items():
    D.text((x0 * S + 4, y0 * S + 4), k, fill="white")
D.ellipse(((30 - 7) * S, (24 - 7) * S, (30 + 7) * S, (24 + 7) * S), outline="black", width=3)
D.text((26 * S, 23 * S), "The Round", fill="black")
D.text((29 * S, 18 * S), "statue", fill="black")
D.text((29 * S, 29 * S), "oak", fill="black")
prev.save(OUT / "preview_labelled.png")
lay.save(OUT / "layout.png")
hei.save(OUT / "height.png")
print("wrote", OUT)
