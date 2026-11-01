"""R24 The Crooked Tree: the maps. The Wytchwood (one winding trail with seven glades and a creek), the hovel inside, the clearing of the Crooked Tree
and Kehlenn's barrow, plus the inn's master suite. Rows only (the legend is the combat one: . floor, # wall or tree, = low obstacle, ~ difficult,
w deep water, _ dais); the props, people and fights are put on by build_crooked_tree.py."""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G  # noqa: E402

W_W, W_H = 44, 112

# Glade centres, south to north: (name, cx, cy, radius)
GLADES = {
    "edge": (22, 105, 7),
    "south_bank": (22, 97, 8),
    "north_bank": (22, 85, 8),
    "thicket": (24, 72, 9),
    "hovel": (20, 57, 9),
    "grove": (22, 40, 12),
    "goat": (22, 24, 8),
    "heart": (22, 10, 6),
}
SIDE_GLADES = {"side_a": (6, 66, 4), "side_b": (38, 50, 4), "side_c": (6, 30, 4)}   # the Hungry Woods boards


def _disc(rows, cx, cy, r, ch="."):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if 1 <= x < W_W - 1 and 1 <= y < W_H - 1 and (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r // 2:
                rows[y][x] = ch


def _trail(rows, a, b, width=5, seed=0):
    """A wiggling trail from glade centre a to b (x, y), north-south."""
    (x0, y0), (x1, y1) = a, b
    steps = abs(y1 - y0)
    for i in range(steps + 1):
        t = i / max(steps, 1)
        y = int(y0 + (y1 - y0) * t)
        x = int(round(x0 + (x1 - x0) * t + 3 * math.sin(t * math.pi * 2 + seed)))
        for dx in range(-(width // 2), width // 2 + 1):
            if 1 <= x + dx < W_W - 1 and 1 <= y < W_H - 1:
                rows[y][x + dx] = "."


def wytchwood():
    """The wood: dense trees (#) everywhere but the trail and its glades. Returns (rows, cells) where cells names the key squares."""
    rng = random.Random(24)
    rows = [["#"] * W_W for _ in range(W_H)]
    names = list(GLADES)
    for n in names:
        cx, cy, r = GLADES[n]
        _disc(rows, cx, cy, r)
    for i in range(len(names) - 1):
        a, b = GLADES[names[i]], GLADES[names[i + 1]]
        _trail(rows, (a[0], a[1]), (b[0], b[1]), 5, seed=i)
    for n, (cx, cy, r) in SIDE_GLADES.items():
        _disc(rows, cx, cy, r)
    # side glades hang off the trail by a short path
    for (sx, sy, tx) in [(10, 66, 18), (34, 50, 26), (10, 30, 17)]:
        for x in range(min(sx, tx), max(sx, tx) + 1):
            for dy in (-1, 0, 1):
                rows[sy + dy][x] = "."
    # the creek: a band of black water 8 squares deep (40 ft) across the whole wood, with three ways over
    c0, c1 = 89, 93
    for y in range(c0, c1 + 1):
        for x in range(1, W_W - 1):
            rows[y][x] = "w"
    for y in range(c0, c1 + 1):
        rows[y][14] = "."           # the fallen log (a plank of trunk, two squares wide)
        rows[y][15] = "."
        for x in (30, 31, 32):
            rows[y][x] = "~"         # the ford: wading, Difficult Terrain
    for i, y in enumerate(range(c0, c1 + 1)):          # the line of stones, zig-zag
        rows[y][22 + (i % 2)] = "."
        rows[y][21 + (i % 2)] = "." if i % 2 else rows[y][21 + (i % 2)]
    for y in range(c0 - 3, c0):
        for x in range(12, 34):
            rows[y][x] = "."
    for y in range(c1 + 1, c1 + 4):
        for x in range(12, 34):
            rows[y][x] = "."
    # the thicket: underbrush the hypnovulfen waits in
    _disc(rows, 24, 72, 4, "~")
    # the hovel glade: nothing walks through the hovel's footprint
    for y in range(52, 56):
        for x in range(17, 24):
            rows[y][x] = "#"
    # the grove: an even ring of trunks round the centre, open at the south and the north
    cx, cy = 22, 40
    for k in range(0, 360, 30):
        x = int(round(cx + 8 * math.cos(math.radians(k))))
        y = int(round(cy + 8 * math.sin(math.radians(k))))
        if (x, y) not in {(22, 48), (22, 32)} and abs(x - cx) > 1:
            rows[y][x] = "#"
    # the goat's path: a few trunks to circle between
    for (x, y) in [(18, 22), (26, 21), (20, 27), (25, 26)]:
        rows[y][x] = "#"
    # scatter: standing trunks in the open glades so they are not bare lawns
    for n, (cx, cy, r) in list(GLADES.items()) + list(SIDE_GLADES.items()):
        if n in ("heart", "goat"):
            continue
        for _ in range(r):
            x, y = cx + rng.randint(-r, r), cy + rng.randint(-r, r)
            if 1 <= x < W_W - 1 and 1 <= y < W_H - 1 and rows[y][x] == "." and not (c0 - 3 <= y <= c1 + 3) and abs(x - cx) + abs(y - cy) > 3 \
                    and not (n == "grove" and (x, y) in {(22, 40)}):
                rows[y][x] = "#"
    # the way out: the south edge (to the moors) and the north (to the clearing)
    for y in (1, 2, 3, 4):
        for x in range(20, 25):
            rows[y][x] = "."
    for y in (W_H - 2, W_H - 3):
        for x in range(20, 25):
            rows[y][x] = "."
    return ["".join(r) for r in rows]


def hovel():
    """Inside the hovel: 20 x 30 ft in the book, drawn here 8 x 10 so a party fits. One door, sealed windows."""
    g = G(10, 12).room(1, 1, 8, 10)
    g.put([(2, 2), (3, 2), (7, 4), (7, 5)], "=")       # the rotting bed, the bent table
    return g.rows()


def crooked_tree():
    """The clearing: 130 ft across (about 30 x 30 squares), a mound at the centre with the Crooked Tree and the goat skull."""
    n = 32
    g = G(n, n)
    cx = cy = 16
    for y in range(n):
        for x in range(n):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 <= 14 ** 2:
                g.c[y][x] = "."
            if d2 > 14 ** 2:
                g.c[y][x] = "#"                          # the treeline, a wall of writhing trunks once inside
    for y in range(n):
        for x in range(n):
            if (x - cx) ** 2 + (y - cy) ** 2 <= 3 ** 2:
                g.c[y][x] = "1"                           # the mound, a steep rise at the centre
    g.put([(cx, cy), (cx - 1, cy), (cx + 1, cy)], "=")  # the trunk of the Crooked Tree and its root flare
    g.put([(8, 8), (23, 9), (9, 23), (24, 22), (12, 4), (20, 27)], "=")   # root spreads
    # the way in, in the south
    for y in range(28, 31):
        for x in range(14, 19):
            g.c[y][x] = "."
    return g.rows()


def barrow():
    """Kehlenn's barrow: about 6 x 8 squares in the book, drawn 12 x 14 so a party fits; ceiling low, roots everywhere."""
    g = G(12, 14).room(1, 1, 10, 12)
    g.put([(1, 1), (2, 1), (9, 1), (10, 1), (1, 12), (10, 12), (1, 6), (10, 6)], "~")
    g.fill(4, 1, 7, 2, "=")                              # the huge mossy skeleton against the far wall
    g.put([(3, 11), (8, 11)], "=")
    return g.rows()


def master_suite():
    """The Green Queen Inn's master suite: furniture shoved to the walls, a runic circle in the middle."""
    g = G(24, 15).room(1, 1, 22, 13)
    g.fill(2, 2, 5, 2, "=")                              # the dresser
    g.fill(18, 2, 21, 3, "=")                            # the desk
    g.fill(2, 11, 6, 12, "=")                            # the bed, pushed up against the wall
    g.put([(21, 11), (21, 12), (20, 12)], "=")           # a settee, shoved
    g.put([(12, 14)], ".")                               # the door in the south wall
    return g.rows()
