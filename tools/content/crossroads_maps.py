#!/usr/bin/env python3
"""R15 (The Drowned Crossroads): the map painter and the fourteen locations' rows. Imported by build_crossroads.py (ONE-SHOT).
Map characters: . floor, # wall or tree, = low cover, ~ shallows or mud (Difficult Terrain), w deep water, _ low dais / dock boards."""
import random
from collections import deque


class C:
    def __init__(self, w, h, fill="#"):
        self.w, self.h = w, h
        self.c = [[fill] * w for _ in range(h)]

    def rect(self, x0, y0, x1, y1, ch="."):
        for y in range(max(0, y0), min(self.h - 1, y1) + 1):
            for x in range(max(0, x0), min(self.w - 1, x1) + 1):
                self.c[y][x] = ch
        return self

    def put(self, cells, ch):
        for (x, y) in cells:
            if 0 <= x < self.w and 0 <= y < self.h:
                self.c[y][x] = ch
        return self

    def blob(self, cx, cy, rx, ry, ch, wob=0.25, seed=0):
        r = random.Random(seed)
        for y in range(self.h):
            for x in range(self.w):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                if dx * dx + dy * dy <= 1 + r.uniform(-wob, wob):
                    self.c[y][x] = ch
        return self

    def scatter(self, ch, n, seed, only="~", keep=()):
        r = random.Random(seed)
        tries = 0
        while n > 0 and tries < 4000:
            tries += 1
            x, y = r.randrange(1, self.w - 1), r.randrange(1, self.h - 1)
            if self.c[y][x] in only and (x, y) not in keep:
                self.c[y][x] = ch
                n -= 1
        return self

    def border(self, ch="#"):
        for x in range(self.w):
            self.c[0][x] = self.c[self.h - 1][x] = ch
        for y in range(self.h):
            self.c[y][0] = self.c[y][self.w - 1] = ch
        return self

    def rows(self):
        return ["".join(r) for r in self.c]


WALK = set(".~_1234=")   # '=' is cover, walkable in play but never a start square


def reach(rows, start):
    h, w = len(rows), len(rows[0])
    seen, q = {start}, deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and rows[ny][nx] in ".~_1234":
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


# ---- the swamp trail, three nights ----------------------------------------------------------------------------------------------
def trail(n):
    c = C(40, 24, "~")
    c.border("#")
    for i, (cx, cy, rx, ry) in enumerate([(5, 12, 4, 4), (12, 8, 3, 3), (13, 17, 3, 3), (28, 8, 3, 3), (28, 17, 3, 3), (35, 12, 4, 4)]):
        c.blob(cx, cy, rx, ry, ".", seed=n * 10 + i)
    c.blob(7, 5, 3, 2, "w", seed=n + 50).blob(33, 20, 4, 2, "w", seed=n + 60).blob(22, 3, 4, 1.5, "w", seed=n + 70)
    c.rect(1, 11, 5, 13, ".").rect(34, 11, 38, 13, ".")
    if n == 1:      # a dry camp hummock
        c.blob(20, 12, 8, 5, ".", wob=0.15, seed=11)
        c.rect(6, 11, 14, 12, ".").rect(27, 11, 34, 12, ".")
        c.scatter("#", 34, 101, only="~")
        c.put([(17, 9), (23, 15), (16, 15), (24, 9)], "=")
    elif n == 2:    # the deep channel and the fallen-log bridge
        c.rect(16, 1, 23, 22, "w")
        c.rect(15, 1, 15, 22, "~").rect(24, 1, 24, 22, "~")
        c.rect(15, 11, 24, 12, ".")                   # the log bridge
        c.rect(6, 11, 14, 12, ".").rect(25, 11, 33, 12, ".")
        c.scatter("#", 30, 202, only="~", keep={(x, y) for x in range(14, 26) for y in range(9, 15)})
        c.put([(13, 10), (26, 14), (11, 14)], "=")
    else:           # the old battlefield in green fog
        c.blob(20, 12, 13, 8, ".", wob=0.2, seed=31)
        c.rect(6, 11, 12, 12, ".").rect(28, 11, 34, 12, ".")
        c.scatter("#", 22, 303, only="~")
        c.put([(14, 8), (16, 15), (21, 9), (24, 14), (27, 10), (18, 12), (12, 13), (30, 15)], "=")
    for x in (0, 39):
        c.c[12][x] = "."
    return c.rows()


# ---- Murkwater Bend: a stilt town ---------------------------------------------------------------------------------------------
def murkwater():
    W, H = 56, 44
    c = C(W, H, "w")
    c.rect(0, 0, W - 1, 1, "~").rect(0, H - 3, W - 1, H - 1, "~").rect(0, 0, 1, H - 1, "~").rect(W - 2, 0, W - 1, H - 1, "~")
    # the main walk, south gate to north gate, and the ring that goes round the fort
    c.rect(27, 0, 29, 43, ".")
    c.rect(14, 3, 39, 4, ".").rect(14, 3, 15, 39, ".").rect(38, 3, 39, 39, ".")
    for (y0, y1) in ((17, 18), (29, 30), (38, 39)):
        c.rect(4, y0, 52, y1, ".")
    # the fort: a palisade block, gate on its south face at (28, 14)
    c.rect(20, 6, 36, 14, "#").rect(27, 15, 29, 16, ".")
    # the mud church (north-west): porch boards and a plank down to the walk
    c.rect(5, 5, 12, 11, "#").rect(5, 12, 13, 14, "_").rect(9, 15, 10, 16, ".")
    # boathouses and their docks (west)
    c.rect(4, 20, 10, 26, "#").rect(11, 20, 13, 26, "_").rect(4, 31, 10, 36, "#").rect(11, 31, 13, 36, "_")
    # fight pits (east): a sunk ring of mud inside a platform
    c.rect(41, 20, 52, 28, ".").rect(44, 22, 49, 26, "~").put([(44, 22), (49, 22), (44, 26), (49, 26)], "=")
    # stilt houses between the walks, each with a plank apron on the walk side
    c.rect(18, 20, 24, 25, "#").rect(18, 26, 24, 28, ".").rect(31, 20, 36, 25, "#").rect(31, 26, 36, 28, ".")
    c.rect(18, 31, 24, 36, "#").rect(18, 37, 24, 37, ".")
    # traders' row (south platform) with stalls as low cover; Mama Pelletier's cookshack boards; the Ferryman's mooring (east)
    c.rect(26, 33, 48, 37, ".")
    for x0 in (30, 35, 40, 45):
        c.rect(x0, 34, x0 + 2, 34, "=")
    c.rect(41, 40, 47, 42, "_")
    c.rect(48, 31, 53, 36, "_")
    c.scatter("#", 14, 77, only="~")
    c.put([(28, 14)], "#")
    return c.rows()


def shack_approach():
    W, H = 30, 30
    c = C(W, H, "~")
    c.border("#")
    c.rect(1, 1, W - 2, 3, "w").rect(1, 26, W - 2, 28, "~")
    # deep water either side of the bottle path, a winding lane of stepping boards
    c.rect(2, 4, 27, 25, "w")
    path = [(14, 29), (14, 28), (14, 27), (14, 26), (14, 25), (14, 24), (14, 23), (15, 23), (16, 23), (17, 23), (17, 22), (17, 21), (17, 20), (17, 19), (16, 19), (15, 19), (14, 19),
            (13, 19), (12, 19), (12, 18), (12, 17), (12, 16), (12, 15), (12, 14), (13, 14), (14, 14), (15, 14), (16, 14), (16, 13), (16, 12), (16, 11), (16, 10), (15, 10), (14, 10), (14, 9),
            (14, 8), (14, 7), (14, 6), (14, 5), (14, 4)]
    for (x, y) in path:
        c.rect(x, y, x, y, "_")
        if (x + 1, y) not in path and c.c[y][x + 1] == "w" and x + 1 < 27:
            pass
    # widen the boards to two squares so a party fits
    for (x, y) in list(path):
        for (dx, dy) in ((1, 0), (0, 1)):
            nx, ny = x + dx, y + dy
            if ny < H and nx < W and c.c[ny][nx] == "w" and 3 < ny < 26:
                c.c[ny][nx] = "_"
    # the pocket bay on the west: shallow water the beast sleeps under, with a ford off the path
    c.rect(2, 8, 9, 20, "~").rect(10, 14, 11, 15, "~")
    # the shack's porch at the top and the lagoon road at the foot
    c.rect(11, 1, 17, 3, "_")
    c.c[0][14] = "."
    c.c[29][14] = "."
    return c.rows()


def lagoon():
    W, H = 36, 30
    c = C(W, H, "w")
    c.border("#")
    c.rect(1, 1, W - 2, 3, "#")                         # mangrove wall north
    c.scatter("#", 30, 9, only="w", keep={(x, y) for x in range(8, 30) for y in range(6, 26)})
    c.rect(1, 14, 6, 16, "~").rect(1, 13, 3, 17, ".")   # the landing the shack road comes down to
    c.blob(25, 15, 4, 4, ".", seed=4).rect(22, 14, 27, 16, "_")   # the mud island the gangplank lands on
    c.rect(6, 14, 17, 15, "~")                          # a causeway of shallows (the Ferryman's pole-way)
    c.rect(18, 14, 22, 15, "~")
    c.rect(1, 14, 1, 15, ".")
    c.c[14][0] = "."
    return c.rows()


# ---- buildings, drawn on the same G pattern as the Foxwillow rooms --------------------------------------------------------------
class G(C):
    def __init__(self, w, h):
        super().__init__(w, h, "#")

    def room(self, x0, y0, x1, y1):
        return self.rect(x0, y0, x1, y1, ".")

    def wall(self, x0, y0, x1, y1):
        return self.rect(x0, y0, x1, y1, "#")


def fort():
    g = G(34, 26).room(1, 1, 32, 24)
    g.wall(1, 12, 32, 12)                                         # the throne hall above, the yard below
    g.rect(16, 12, 18, 12, ".")                                  # a wide doorway
    g.wall(12, 1, 12, 11).rect(12, 8, 12, 9, ".")                 # the sleeping room's wall, a door
    g.rect(15, 2, 29, 4, "_")                                     # the short dais
    g.put([(14, 6), (15, 6), (16, 6), (22, 6), (23, 6), (24, 6), (29, 6), (30, 6), (14, 9), (15, 9), (28, 9), (29, 9)], "=")    # plush furniture, a card table
    g.put([(3, 3), (4, 3), (3, 6), (4, 6), (3, 9), (4, 9), (8, 3), (9, 3), (8, 9), (9, 9)], "=")         # beds
    g.put([(4, 15), (5, 15), (8, 15), (9, 15), (24, 15), (25, 15), (28, 15), (29, 15), (4, 20), (5, 20), (26, 20), (27, 20), (10, 22), (11, 22), (22, 22), (23, 22)], "=")   # refugee bedrolls, crates
    g.c[25][17] = "."
    return g.rows()


def shack():
    g = G(11, 9).room(1, 1, 9, 7)
    g.put([(2, 2), (3, 2), (7, 2), (8, 2), (2, 6), (3, 6), (7, 6), (8, 6)], "=")      # shelves of trinkets
    g.put([(5, 1)], "=")                                            # the spiral stair's foot
    g.c[8][5] = "."
    return g.rows()


def promenade():
    g = G(46, 16).room(1, 1, 44, 14)
    g.wall(1, 5, 44, 5).rect(8, 5, 12, 5, ".").rect(30, 5, 36, 5, ".")      # the balcony hall above the hall's roof
    g.rect(2, 1, 44, 4, ".")
    g.put([(14, 2), (15, 2), (22, 2), (23, 2), (24, 2), (32, 2), (33, 2), (40, 2), (41, 2), (14, 11), (15, 11), (26, 11), (27, 11), (36, 11), (37, 11)], "=")
    g.rect(2, 7, 6, 12, "_")                                        # the foot of the gangplank
    g.c[8][0] = "."
    return g.rows()


def hall():
    g = G(42, 24).room(1, 1, 40, 22)
    g.rect(2, 2, 12, 5, "_")                                       # the skeleton jazz band's stand
    g.rect(16, 2, 38, 2, "=")                                       # the bar
    for (x, y) in ((8, 9), (8, 14), (8, 19), (17, 10), (17, 16), (26, 10), (26, 16), (35, 10), (35, 16), (22, 20), (32, 20)):
        g.put([(x, y), (x + 1, y), (x + 2, y)], "=")                # gaming tables
    g.put([(30, 5), (31, 5), (32, 5), (33, 5)], "=")
    g.c[23][21] = "."
    g.c[0][20] = "."
    return g.rows()


def lower():
    g = G(52, 20).room(1, 1, 50, 18)
    g.wall(1, 8, 50, 8)                                              # the long corridor runs y 9-10; compartments above and below
    g.wall(1, 11, 50, 11)
    g.rect(1, 9, 50, 10, ".")
    for x in (7, 15, 24, 34, 44):
        g.rect(x, 8, x, 8, ".").rect(x, 11, x, 11, ".")             # doors off the corridor
    g.wall(12, 1, 12, 7).wall(21, 1, 21, 7).wall(30, 1, 30, 7).wall(40, 1, 40, 7)
    g.wall(12, 12, 12, 18).wall(30, 12, 30, 18).wall(40, 12, 40, 18)
    g.rect(41, 1, 50, 7, ".")
    g.put([(43, 3), (44, 3), (45, 3), (46, 3), (43, 5), (44, 5), (45, 5), (46, 5)], "=")      # the boiler's coffin shape and its pipes
    g.put([(3, 13), (4, 13), (6, 13), (7, 13), (9, 13), (10, 13), (3, 16), (4, 16), (6, 16), (7, 16), (9, 16), (10, 16)], "=")   # bunks
    g.put([(14, 14), (15, 14), (16, 14), (18, 14), (19, 14), (20, 14), (22, 14), (23, 14), (24, 14)], "=")   # galley counters
    g.put([(33, 3), (34, 3), (35, 3), (36, 3), (33, 5), (34, 5), (35, 5), (36, 5)], "=")    # coin sacks in the vault
    g.c[9][0] = "."
    g.c[10][51] = "#"
    return g.rows()


def captain():
    g = G(24, 14).room(1, 1, 22, 12)
    g.put([(3, 2), (4, 2), (5, 2), (18, 2), (19, 2), (20, 2)], "=")     # the nautical museum's cases
    g.put([(10, 3), (11, 3), (12, 3), (13, 3)], "=")                   # the desk
    g.c[13][11] = "."
    return g.rows()


def casino():
    g = G(18, 26).room(1, 1, 16, 24)
    g.rect(1, 1, 16, 2, "_")                                          # the balcony all round, 20 ft up (drawn as raised floor)
    g.rect(1, 1, 2, 24, "_").rect(15, 1, 16, 24, "_")
    g.rect(1, 23, 16, 24, "_")
    g.rect(4, 4, 13, 21, "~")                                         # 2 ft of glowing bayou water
    g.put([(5, 7), (6, 7), (11, 7), (12, 7), (5, 18), (6, 18), (11, 18), (12, 18)], "=")                # round gaming tables
    g.put([(8, 12), (9, 12), (8, 13), (9, 13)], "=")                  # Jack's coffin on four legs, the dice table
    g.c[25][8] = "."
    return g.rows()


LOCATIONS = {"dc_trail1": lambda: trail(1), "dc_trail2": lambda: trail(2), "dc_trail3": lambda: trail(3), "dc_murkwater": murkwater, "dc_fort": fort,
             "dc_shack_approach": shack_approach, "dc_shack": shack, "dc_lagoon": lagoon, "dc_boat_promenade": promenade, "dc_boat_hall": hall,
             "dc_boat_lower": lower, "dc_boat_captain": captain, "dc_casino": casino}


def check(key, rows, starts, points):
    """Every point (exit, npc, monster, spawn) must stand on open floor reachable from the first spawn."""
    bad = []
    seen = reach(rows, tuple(starts))
    for label, (x, y) in points:
        if not (0 <= y < len(rows) and 0 <= x < len(rows[0])):
            bad.append(f"{key}: {label} {(x, y)} off the map")
        elif (x, y) not in seen and not (label.startswith("exit") and rows[y][x] in "#w"):
            bad.append(f"{key}: {label} {(x, y)} ({rows[y][x]}) is not reachable from {tuple(starts)}")
    return bad
