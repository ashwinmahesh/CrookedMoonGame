#!/usr/bin/env /usr/bin/python3
"""ONE-SHOT (R18). Paints Hartsblight Forest's eleven outdoor and cave maps as land (layout + height pictures at 20 px a square) into
docs/plans/hartsblight/<map>/ and prints the `make sketch` line for each (tools/content/hartsblight_sketch.sh runs them):
    make sketch HEIGHT=docs/plans/hartsblight/<map>/height.png LAYOUT=docs/plans/hartsblight/<map>/layout.png SIZE=WxH TOP=n LOC=data/locations/<map>.json
    /usr/bin/python3 tools/content/hartsblight_sketch.py docs/plans/hartsblight"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, str(Path(__file__).parent))
from hartsblight_layout import MAPS
S = 20
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/plans/hartsblight")
WATER, WOODS, ROCK, WALL, BRAMBLE, FENCE, OPEN = "#0000ff", "#006400", "#808080", "#ff0000", "#8b4513", "#ffff00", "#e8e8e8"


class Canvas:
    def __init__(self, mid, base_h=70):
        m = MAPS[mid]; self.mid, self.m, self.w, self.h = mid, m, m["w"], m["h"]
        self.lay = Image.new("RGB", (self.w * S, self.h * S), OPEN); self.hei = Image.new("L", (self.w * S, self.h * S), base_h)
        self.L, self.H = ImageDraw.Draw(self.lay), ImageDraw.Draw(self.hei)
        self.r = random.Random(sum(map(ord, mid)))
        if mid not in ("hb_oozing_ravine", "hb_den", "hb_infested_outcrop", "hb_noxious_hollow"):      # a gentle swell, so open ground is never dead flat
            ph = self.r.uniform(0, 6)
            for y in range(self.h * S):
                self.H.line((0, y, self.w * S, y), fill=int(base_h + 50 * math.sin(y / (S * 6.0) + ph)))

    def blob(self, cx, cy, rx, ry, fill, wob=0.25, n=22, height=None):
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n; k = 1 + self.r.uniform(-wob, wob)
            pts.append(((cx + math.cos(a) * rx * k) * S, (cy + math.sin(a) * ry * k) * S))
        if fill: self.L.polygon(pts, fill=fill)
        if height is not None: self.H.polygon(pts, fill=height)

    def rect(self, x0, y0, x1, y1, fill=WALL):
        self.L.rectangle((x0 * S, y0 * S, (x1 + 1) * S - 1, (y1 + 1) * S - 1), fill=fill)

    def hrect(self, x0, y0, x1, y1, v):
        self.H.rectangle((x0 * S, y0 * S, (x1 + 1) * S - 1, (y1 + 1) * S - 1), fill=v)

    def fence(self, x0, y0, x1, y1, gap=()):
        for (x, y) in [(x, y0) for x in range(x0, x1 + 1)] + [(x, y1) for x in range(x0, x1 + 1)] + [(x0, y) for y in range(y0, y1 + 1)] + [(x1, y) for y in range(y0, y1 + 1)]:
            if (x, y) not in gap: self.rect(x, y, x, y, FENCE)

    def border(self, thick=2, fill=WOODS):
        for t in range(thick):
            for x in range(self.w): self.rect(x, t, x, t, fill); self.rect(x, self.h - 1 - t, x, self.h - 1 - t, fill)
            for y in range(self.h): self.rect(t, y, t, y, fill); self.rect(self.w - 1 - t, y, self.w - 1 - t, y, fill)

    def scatter(self, n, fill, rx=(0.8, 1.6), keep=(), box=None):
        x0, y0, x1, y1 = box or (2, 2, self.w - 3, self.h - 3)
        for _ in range(n):
            cx, cy = self.r.uniform(x0, x1), self.r.uniform(y0, y1)
            if any(abs(cx - kx) < kr and abs(cy - ky) < kr for (kx, ky, kr) in keep): continue
            r = self.r.uniform(*rx); self.blob(cx, cy, r, r * self.r.uniform(0.8, 1.2), fill)

    def clear(self, cell, rad=2):
        x, y = cell
        self.rect(max(0, x - rad), max(0, y - rad), min(self.w - 1, x + rad), min(self.h - 1, y + rad), OPEN)

    def finish(self):
        for cell in list(self.m["spawns"].values()) + [e[0] for e in self.m["exits"].values()]:
            self.clear(cell, 2)
        d = OUT / self.mid; d.mkdir(parents=True, exist_ok=True)
        self.lay.save(d / "layout.png"); self.hei.filter(ImageFilter.GaussianBlur(S * 0.9)).save(d / "height.png")
        print(f"make sketch HEIGHT=docs/plans/hartsblight/{self.mid}/height.png LAYOUT=docs/plans/hartsblight/{self.mid}/layout.png SIZE={self.w}x{self.h} TOP={self.m['top']} LOC=data/locations/{self.mid}.json")


def keepers(m):
    return [(c[0], c[1], 3) for c in list(m["spawns"].values()) + [e[0] for e in m["exits"].values()]]


def commune():
    c = Canvas("hb_patient_commune")
    c.border(2)
    for y in range(0, 7):                                           # the tree line, a gap in the middle
        for x in range(c.w):
            if not (19 <= x <= 25): c.rect(x, y, x, y, WOODS)
    c.rect(16, 24, 28, 30); c.rect(8, 14, 12, 18); c.rect(32, 14, 36, 18); c.rect(6, 24, 10, 28); c.rect(34, 26, 38, 30)   # longhouse, huts
    c.fence(5, 35, 14, 44, gap=[(10, 35)]); c.fence(4, 47, 13, 53, gap=[(8, 47)])       # gardens, pen
    for row in range(5):                                            # orchard rows
        for col in range(5):
            c.blob(32 + col * 2.2, 36 + row * 3.2, 0.7, 0.7, WOODS, 0.1)
    c.scatter(18, WOODS, keep=keepers(c.m) + [(22, 20, 6)], box=(3, 8, 40, 52)); c.scatter(8, BRAMBLE, (1, 2), keep=keepers(c.m), box=(3, 8, 40, 52))
    c.finish()


def altar():
    c = Canvas("hb_altar_of_rot")
    c.border(2)
    c.rect(13, 13, 17, 15, ROCK)                                    # the stacked-stone altar
    c.blob(14, 9, 2.2, 2.6, WOODS, 0.1)                             # the effigy
    c.scatter(22, WOODS, (1, 2.2), keep=keepers(c.m) + [(15, 14, 5), (14, 9, 4)]); c.scatter(10, BRAMBLE, (1, 2), keep=keepers(c.m))
    c.finish()


def pines():
    c = Canvas("hb_pine_barrens")
    c.border(2)
    c.scatter(34, WOODS, (0.7, 1.3), keep=keepers(c.m)); c.scatter(20, BRAMBLE, (1.5, 2.5), keep=keepers(c.m))
    c.finish()


def outcrop():
    c = Canvas("hb_infested_outcrop", base_h=40)
    c.border(2)
    c.blob(20, 18, 12, 11, BRAMBLE, 0.25)                           # the soft upturned ring
    c.blob(20, 18, 8.5, 7.5, ROCK, 0.1, height=230)                 # the outcrop, ten feet up in the engine's steps
    c.blob(20, 18, 6.2, 5.2, OPEN, 0.05, height=230)                # its flat top where the camp stands
    c.rect(19, 19, 21, 27, OPEN)                                    # the way up
    c.scatter(14, WOODS, (1, 2), keep=keepers(c.m) + [(20, 18, 14)])
    c.finish()


def hollow():
    c = Canvas("hb_noxious_hollow", base_h=120)
    c.border(2); c.blob(15, 15, 9, 9, None, height=20)
    c.blob(15, 14, 1.8, 1.8, WOODS, 0.1)                            # the great beech
    c.scatter(18, WOODS, (1, 2), keep=keepers(c.m) + [(15, 15, 5)]); c.scatter(8, BRAMBLE, (1, 2), keep=keepers(c.m))
    c.finish()


def druids():
    c = Canvas("hb_druid_commune")
    c.border(2)
    for i in range(10):                                             # the ring of giant rotting trees
        a = 2 * math.pi * i / 10 + 0.2
        c.blob(20 + 14 * math.cos(a), 20 + 13 * math.sin(a), 2.4, 2.4, WOODS, 0.12)
    for (x0, y0, x1, y1) in [(4, 8, 7, 11), (31, 6, 35, 9), (6, 27, 9, 30), (30, 29, 34, 32)]: c.rect(x0, y0, x1, y1)   # burrowed dwellings
    c.scatter(10, BRAMBLE, (1, 2), keep=keepers(c.m) + [(20, 20, 6)])
    c.finish()


def ravine():
    c = Canvas("hb_oozing_ravine", base_h=240)
    c.hrect(4, 0, 11, 33, 20)                                       # the floor, low
    for y in range(c.h):
        c.rect(0, y, 3, y, ROCK); c.rect(12, y, 15, y, ROCK)        # the rims (rock walls, high)
    c.scatter(10, BRAMBLE, (0.8, 1.4), box=(5, 3, 10, 28), keep=keepers(c.m))
    c.finish()


def quagmire():
    c = Canvas("hb_stinking_quagmire", base_h=60)
    c.border(2)
    for (x, y, rx, ry) in [(10, 8, 4, 3), (28, 9, 5, 3), (9, 27, 4, 3), (30, 26, 5, 4), (18, 30, 3, 2)]: c.blob(x, y, rx, ry, WATER, 0.3)
    c.blob(20, 18, 5.5, 4.5, WATER, 0.1)                            # the clear pool
    c.scatter(14, BRAMBLE, (1.5, 2.6), keep=keepers(c.m) + [(20, 18, 8)]); c.scatter(10, WOODS, (0.8, 1.4), keep=keepers(c.m) + [(20, 18, 8)])
    c.finish()


def grove():
    c = Canvas("hb_fungal_grove", base_h=60)
    c.border(2)
    c.scatter(26, WOODS, (0.5, 1.0), keep=keepers(c.m) + [(14, 18, 5)]); c.scatter(8, BRAMBLE, (1, 2), keep=keepers(c.m))
    c.blob(14, 18, 2.6, 2.6, WOODS, 0.1)                            # the gloomwood's place
    c.finish()


def wellspring():
    c = Canvas("hb_wellspring", base_h=80)
    c.border(2)
    c.rect(2, 26, 27, 33, BRAMBLE)                                  # the river, waded (Difficult)
    c.blob(15, 12, 4.4, 4.4, WATER, 0.08)                           # the pool
    for i in range(11):                                             # the standing stones
        a = 2 * math.pi * i / 11
        c.blob(15 + 8.5 * math.cos(a), 12 + 8.2 * math.sin(a), 0.9, 1.2, ROCK, 0.1)
    c.scatter(14, WOODS, (1, 2), keep=keepers(c.m) + [(15, 12, 11)], box=(2, 2, 27, 24)); c.scatter(6, BRAMBLE, (1, 2), keep=keepers(c.m) + [(15, 12, 11)])
    c.finish()


def den():
    c = Canvas("hb_den", base_h=70)
    c.rect(0, 0, c.w - 1, c.h - 1, ROCK)
    c.rect(4, 3, 25, 27, OPEN); c.rect(11, 28, 18, 39, OPEN)        # the cavern and the tunnel stub
    for (x, y, rx, ry) in [(8, 8, 1.5, 1.2), (22, 9, 1.4, 1.5), (7, 20, 1.2, 1.3), (23, 21, 1.5, 1.2)]: c.blob(x, y, rx, ry, ROCK, 0.2)   # pillars
    c.scatter(10, BRAMBLE, (1, 2), keep=keepers(c.m) + [(15, 10, 5)], box=(5, 4, 24, 26))
    c.finish()


if __name__ == "__main__":
    for f in (commune, altar, pines, outcrop, hollow, druids, ravine, quagmire, grove, wellspring, den): f()
