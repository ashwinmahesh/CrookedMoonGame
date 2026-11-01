#!/usr/bin/env python3
"""R26 Moonfall: the map shapes for the hub (mf_round), the eight Old Fears' regions and the last hill. Each function returns a dict:
rows, areas, spawns, key cells (K), theme, light, outdoors. Imported by build_moonfall.py (ONE-SHOT; do not re-run over edits)."""
import random

DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


class M:
    def __init__(self, w, h, fill="."):
        self.w, self.h = w, h
        self.c = [[fill] * w for _ in range(h)]
        self.border()

    def border(self, ch="#"):
        for x in range(self.w):
            self.c[0][x] = self.c[self.h - 1][x] = ch
        for y in range(self.h):
            self.c[y][0] = self.c[y][self.w - 1] = ch
        return self

    def fill(self, x0, y0, x1, y1, ch):
        for y in range(max(0, y0), min(self.h - 1, y1) + 1):
            for x in range(max(0, x0), min(self.w - 1, x1) + 1):
                self.c[y][x] = ch
        return self

    def put(self, cells, ch):
        for (x, y) in cells:
            if 0 <= x < self.w and 0 <= y < self.h:
                self.c[y][x] = ch
        return self

    def blob(self, cx, cy, rx, ry, ch, rng=None, hole=0.0):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if 1 <= x < self.w - 1 and 1 <= y < self.h - 1 and ((x - cx) / max(rx, 1)) ** 2 + ((y - cy) / max(ry, 1)) ** 2 <= 1.0:
                    if rng is None or rng.random() >= hole:
                        self.c[y][x] = ch
        return self

    def scatter(self, rng, n, ch, x0, y0, x1, y1, only="."):
        done = 0
        tries = 0
        while done < n and tries < n * 40:
            tries += 1
            x, y = rng.randint(x0, x1), rng.randint(y0, y1)
            if self.c[y][x] == only:
                self.c[y][x] = ch
                done += 1
        return self

    def rows(self):
        return ["".join(r) for r in self.c]

    def at(self, x, y):
        return self.c[y][x]


def walkable(ch):
    return ch in ".~_1234=" and ch != "="  # '=' low obstacles are not stood on for placements


def floor_cells(rows, x0, y0, x1, y1):
    out = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rows[y][x] in ".~_1234":
                out.append((x, y))
    return out


def reachable(rows, start):
    seen = {start}
    stack = [start]
    while stack:
        x, y = stack.pop()
        for dx, dy in DIRS:
            nx, ny = x + dx, y + dy
            if 0 <= ny < len(rows) and 0 <= nx < len(rows[0]) and (nx, ny) not in seen and rows[ny][nx] in ".~_1234":
                seen.add((nx, ny))
                stack.append((nx, ny))
    return seen


def ring(m, cx, cy, rx, ry, ch, gap=None):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            edge = abs(x - cx) == rx or abs(y - cy) == ry
            if edge and 1 <= x < m.w - 1 and 1 <= y < m.h - 1:
                m.c[y][x] = ch
    if gap:
        m.put(gap, ".")


# ---- the hub: the Founder's Round under the falling moon ----------------------------------------------------------------------------
def round_hub():
    m = M(36, 26)
    rng = random.Random(260)
    m.fill(2, 2, 33, 23, ".")
    m.blob(18, 12, 4, 3, "_")                       # the Round's dais where the statue stood
    m.fill(2, 2, 6, 5, "=")                         # tents and cots along the north-west
    m.fill(28, 2, 33, 4, "=")                       # the long table
    m.put([(10, 3), (11, 3), (12, 3), (24, 3), (25, 3)], "#")
    m.fill(2, 19, 7, 23, "=")                       # stacked crates by the platform
    m.fill(2, 20, 7, 22, ".")
    m.put([(30, 19), (31, 19), (32, 19), (30, 20), (30, 21)], "=")
    m.scatter(rng, 14, "#", 3, 3, 32, 22)
    K = {"dais": (18, 12), "vagrant": (14, 15), "platform": (4, 21), "ledger": (22, 14), "map_table": (21, 17), "bonfire": (17, 18), "board": (10, 8),
         "gaunt": (27, 8), "tamsin": (8, 10), "quill": (26, 15), "solomon": (13, 6), "marianna": (29, 12), "west": (3, 12), "south": (18, 23)}
    for k in ("vagrant", "ledger", "map_table", "bonfire", "board", "gaunt", "tamsin", "quill", "solomon", "marianna", "platform"):
        x, y = K[k]
        m.put([(x, y)], ".")
    m.put([(1, 12), (1, 13)], ".")
    areas = [("round", "The Founder's Round", (2, 2), (33, 23)), ("platform", "The Ghostlight platform", (2, 19), (7, 23))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 12), "from_village": (4, 12), "from_travel": (18, 21)}, theme="village", light="dim", outdoors=True,
                exit_cell=(2, 12), exit2_cell=(18, 22))


# ---- 1. The Galloping Headsman: farm yard, cornfield, the covered bridge, the execution ground -------------------------------------------
def covered_bridge():
    m = M(46, 30)
    rng = random.Random(261)
    m.fill(2, 2, 43, 27, ".")
    m.fill(24, 1, 29, 28, "w")                       # the river
    m.fill(22, 12, 31, 17, ".")                      # the bridge approach and deck
    m.fill(24, 12, 29, 12, "#").fill(24, 17, 29, 17, "#")   # the covered bridge's side walls
    m.fill(24, 13, 29, 16, ".")
    m.fill(2, 3, 12, 25, ".")                        # the farm yard
    m.fill(3, 4, 11, 4, "=").fill(3, 24, 11, 24, "=").fill(11, 5, 11, 10, "=").fill(11, 19, 11, 23, "=")  # its fence
    m.fill(14, 3, 21, 26, "~")                       # the strangling corn
    m.fill(14, 13, 22, 16, ".")                      # the track through the corn
    m.fill(31, 12, 43, 17, ".")
    m.blob(38, 14, 5, 4, "_")                        # the execution ground: a low dais
    m.fill(33, 5, 34, 7, "~").fill(40, 21, 42, 23, "~").fill(35, 22, 37, 24, "~")   # sinkholes
    m.scatter(rng, 18, "#", 31, 3, 43, 26)
    m.scatter(rng, 10, "=", 14, 3, 21, 26, only="~")
    for (x, y) in [(2, 14), (2, 15), (3, 14), (3, 15)]:
        m.c[y][x] = "."
    K = {"farmer": (6, 14), "mob": (18, 8), "gate": (11, 14), "bridge_in": (23, 14), "bridge_mid": (27, 14), "dais": (38, 14), "lair": (37, 14), "skull": (34, 20),
         "affliction": (7, 12), "board": (8, 10), "exit": (2, 14), "archive": (7, 19), "keepsake": (40, 20)}
    for k in ("farmer", "gate", "board", "archive", "skull", "keepsake", "mob", "affliction"):
        x, y = K[k]
        m.put([(x, y)], ".")
    areas = [("farm", "The farm", (2, 3), (12, 25)), ("corn", "The corn", (14, 3), (22, 26)), ("bridge", "The covered bridge", (23, 12), (30, 17)),
             ("ground", "The execution ground", (31, 8), (43, 20))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 14), "from_travel": (4, 14)}, theme="wilderness", light="dim", outdoors=True, exit_cell=(2, 14))


# ---- 2. The White Worm: a fishing village, the jetty, an air pocket on the lake bed ------------------------------------------------------
def moonsong_rift():
    m = M(44, 30)
    rng = random.Random(262)
    m.fill(2, 2, 41, 27, "w")                        # the lake
    m.fill(2, 2, 17, 27, ".")                        # the shore and the village
    m.blob(14, 14, 6, 10, "~")                       # the mud flats
    m.fill(18, 13, 30, 15, "_")                      # the jetty
    m.fill(31, 8, 41, 21, ".")                       # the lake bed, an air pocket round the rift
    m.blob(38, 14, 3, 3, "~")
    m.fill(31, 13, 31, 15, "_")
    m.put([(31, 12), (31, 16), (32, 8), (32, 21)], "#")
    m.fill(4, 4, 8, 7, "=").fill(4, 20, 8, 23, "=").fill(10, 4, 12, 5, "=")     # huts
    m.scatter(rng, 14, "#", 33, 8, 40, 21)
    m.scatter(rng, 12, "~", 2, 3, 16, 26)
    for (x, y) in [(2, 14), (3, 14), (2, 15), (3, 15)]:
        m.c[y][x] = "."
    K = {"fisher": (6, 14), "cultist": (12, 10), "obelisk": (10, 18), "jetty_end": (29, 14), "lair": (37, 14), "rift": (38, 14), "affliction": (7, 16),
         "board": (8, 12), "exit": (2, 14), "stars": (35, 10), "keepsake": (9, 22)}
    for k in ("fisher", "cultist", "obelisk", "board", "affliction", "stars", "keepsake", "lair"):
        x, y = K[k]
        m.put([(x, y)], ".")
    areas = [("shore", "The fishing village", (2, 3), (17, 26)), ("jetty", "The long jetty", (18, 13), (30, 15)), ("bed", "The lake bed", (31, 8), (41, 21))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 14), "from_travel": (4, 14)}, theme="riverside", light="dim", outdoors=True, exit_cell=(2, 14))


# ---- 3. The Tall Man: the healed Hartsblight, then a ruined fey palace --------------------------------------------------------------------
def tall_man_palace():
    m = M(46, 32)
    rng = random.Random(263)
    m.fill(2, 2, 43, 29, ".")
    m.scatter(rng, 90, "#", 2, 2, 22, 29)             # the thick wood
    m.fill(3, 14, 21, 17, ".")                         # the logging road
    m.fill(2, 12, 9, 19, ".")                          # the logging camp
    m.blob(12, 22, 3, 3, "~")                          # the old Wellspring, boggy
    m.fill(23, 8, 43, 24, ".")                         # the palace court
    ring(m, 36, 16, 8, 6, "#", gap=[(28, 16), (36, 10), (36, 22)])    # its wall, broken in three places
    m.put([(31, 12), (31, 20), (41, 12), (41, 20), (36, 13), (36, 19)], "=")    # fallen pillars
    m.fill(34, 15, 38, 17, "_")                        # the throne of the lost court
    m.scatter(rng, 22, "#", 23, 3, 43, 7)
    m.scatter(rng, 22, "#", 23, 25, 43, 29)
    for (x, y) in [(2, 15), (3, 15), (2, 14), (3, 14)]:
        m.c[y][x] = "."
    K = {"logger": (5, 15), "crone": (8, 18), "wellspring": (12, 22), "palace_gate": (28, 16), "dais": (36, 16), "lair": (35, 16), "affliction": (6, 13), "board": (7, 13),
         "exit": (2, 15), "steps": (30, 16), "keepsake": (14, 17), "gorthos_stump": (16, 16)}
    for k in ("logger", "crone", "board", "affliction", "keepsake", "gorthos_stump", "steps", "lair"):
        x, y = K[k]
        m.put([(x, y)], ".")
    areas = [("camp", "The loggers' camp", (2, 12), (9, 19)), ("wood", "The healed wood", (2, 2), (22, 29)), ("court", "The ruined court", (23, 8), (43, 24))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 15), "from_travel": (4, 15)}, theme="forest", light="dark", outdoors=True, exit_cell=(2, 15))


# ---- 4. The Wild Titan: mining hamlet, rune-stone slopes, the summit -------------------------------------------------------------------
def howlers_peaks():
    m = M(46, 32)
    rng = random.Random(264)
    m.fill(2, 2, 43, 29, ".")
    m.fill(2, 2, 43, 29, ".")
    m.fill(14, 2, 43, 29, "1")                          # the first terrace
    m.fill(24, 4, 43, 27, "2")
    m.fill(33, 7, 43, 24, "3")
    m.fill(2, 12, 13, 19, ".")                           # the hamlet
    m.fill(14, 14, 23, 17, "1")                          # the switchback path, a gentle slope
    m.fill(24, 14, 32, 17, "2")
    m.fill(33, 14, 36, 17, "3")
    m.scatter(rng, 60, "#", 2, 2, 43, 29, only="1")
    m.scatter(rng, 30, "#", 2, 2, 13, 29)
    m.scatter(rng, 40, "#", 24, 2, 43, 29, only="2")
    m.fill(14, 14, 23, 17, "1").fill(24, 14, 32, 17, "2").fill(33, 14, 36, 17, "3")
    m.fill(37, 11, 42, 20, "3")                          # the summit plateau
    m.put([(4, 14), (5, 14), (6, 14)], ".")
    for (x, y) in [(2, 15), (3, 15), (2, 14), (3, 14)]:
        m.c[y][x] = "."
    K = {"miner": (5, 15), "hunter": (9, 13), "stones": (20, 15), "glyph_stone": (28, 16), "lair": (40, 15), "affliction": (6, 17), "board": (8, 17),
         "exit": (2, 15), "keepsake": (11, 18), "dais": (40, 15)}
    for k in ("miner", "hunter", "stones", "glyph_stone", "board", "affliction", "keepsake", "lair"):
        x, y = K[k]
        m.put([(x, y)], m.at(x, y) if m.at(x, y) in ".123" else ".")
    areas = [("hamlet", "The mining hamlet", (2, 12), (13, 19)), ("slopes", "The rune-stone slopes", (14, 3), (32, 28)), ("summit", "The summit", (33, 7), (43, 24))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 15), "from_travel": (4, 15)}, theme="wilderness", light="dim", outdoors=True, exit_cell=(2, 15))


# ---- 5. The Barrow King: Maidenmist's graves above, catacombs below, one map ---------------------------------------------------------------
def barrow_catacombs():
    m = M(46, 34)
    rng = random.Random(265)
    m.fill(2, 2, 43, 31, ".")
    m.fill(2, 17, 43, 31, "#")                           # rock under the graves
    m.scatter(rng, 40, "=", 3, 3, 42, 15)                # headstones
    m.fill(2, 8, 12, 12, ".")                            # the gate and the lane
    m.fill(4, 3, 40, 4, ".")
    m.fill(30, 4, 36, 9, "~")                            # the opened graves, loose earth
    m.fill(22, 14, 24, 19, ".")                          # the stair down
    m.fill(10, 20, 42, 30, "#")
    m.fill(12, 22, 40, 28, ".")                          # the catacomb
    m.fill(22, 14, 24, 22, ".")
    for x0 in (16, 22, 28, 34):
        m.fill(x0, 22, x0, 25, "#")                      # the pillars of the nave
    m.fill(12, 22, 12, 28, "=").fill(40, 22, 40, 28, "=")   # niches
    m.fill(30, 23, 38, 27, "_")                          # the throne of skulls dais
    m.fill(13, 29, 21, 29, ".")
    for (x, y) in [(2, 10), (3, 10), (2, 9), (3, 9)]:
        m.c[y][x] = "."
    K = {"ghost": (18, 25), "grave_a": (31, 6), "grave_b": (34, 8), "dig": (31, 5), "stair": (23, 17), "lair": (34, 25), "dais": (34, 25), "affliction": (6, 10), "board": (8, 10),
         "exit": (2, 10), "keepsake": (14, 26), "ghost_room": (14, 24), "forge": (10, 8)}
    for k in ("grave_a", "grave_b", "dig", "board", "affliction", "keepsake", "lair", "ghost", "forge", "stair", "ghost_room"):
        x, y = K[k]
        m.put([(x, y)], ".")
    m.fill(22, 12, 24, 16, ".")
    areas = [("graves", "The opened graves", (2, 3), (43, 16)), ("stair", "The stair down", (22, 14), (24, 19)), ("catacombs", "The royal catacombs", (12, 22), (40, 29))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 10), "from_travel": (4, 10)}, theme="dungeon", light="dark", outdoors=False, exit_cell=(2, 10))


# ---- 6. The Jinxed Leviathan: the bayou, the shacks on stilts, the cursed pool -----------------------------------------------------------
def jinxed_bayou():
    m = M(46, 30)
    rng = random.Random(266)
    m.fill(2, 2, 43, 27, "~")                            # mud and shallows
    m.blob(36, 14, 7, 8, "w")                            # the cursed pool
    m.blob(36, 14, 4, 5, "_")                            # an island in it
    m.fill(30, 14, 34, 15, "_")                          # a causeway of planks
    m.fill(2, 3, 14, 26, ".")                            # the stilt village boards
    m.fill(15, 13, 29, 16, "_")                          # the boardwalk
    m.scatter(rng, 20, "w", 15, 3, 29, 26, only="~")
    m.scatter(rng, 24, "#", 15, 3, 43, 26, only="~")
    m.fill(15, 13, 29, 16, "_").fill(30, 14, 34, 15, "_")
    m.blob(36, 14, 4, 5, "_")
    m.put([(5, 6), (6, 6), (5, 7), (6, 7), (10, 20), (11, 20), (10, 21), (11, 21)], "=")
    for (x, y) in [(2, 14), (3, 14), (2, 15), (3, 15)]:
        m.c[y][x] = "."
    K = {"resident": (6, 14), "follower": (11, 9), "idol": (12, 18), "serpent_nest": (22, 6), "lair": (36, 14), "dais": (36, 14), "affliction": (7, 12), "board": (9, 12),
         "exit": (2, 14), "keepsake": (8, 22), "boardwalk": (20, 14)}
    for k in ("resident", "follower", "idol", "board", "affliction", "keepsake", "serpent_nest", "lair"):
        x, y = K[k]
        m.put([(x, y)], "." if k != "lair" else "_")
    areas = [("village", "The stilt village", (2, 3), (14, 26)), ("boardwalk", "The boardwalk", (15, 13), (34, 16)), ("pool", "The cursed pool", (29, 6), (43, 22))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 14), "from_travel": (4, 14)}, theme="riverside", light="dark", outdoors=True, exit_cell=(2, 14))


# ---- 7a. The Dusk Mother: the Webwoods and a homestead -----------------------------------------------------------------------------------
def webwoods():
    m = M(44, 30)
    rng = random.Random(267)
    m.fill(2, 2, 41, 27, ".")
    m.scatter(rng, 110, "#", 2, 2, 41, 27)
    m.scatter(rng, 70, "~", 2, 2, 41, 27)                # webs
    m.fill(2, 11, 11, 18, ".")                           # the homestead yard
    m.fill(4, 12, 8, 14, "=")                            # the farmhouse (a low block)
    m.fill(12, 14, 33, 15, ".")                          # the spiders' trail
    m.fill(32, 9, 40, 21, ".")                           # the clearing
    m.blob(36, 15, 3, 3, "~")
    for (x, y) in [(2, 15), (3, 15), (2, 16), (3, 16)]:
        m.c[y][x] = "."
    K = {"girl": (6, 16), "nurse": (9, 17), "rhymes": (7, 18), "trail": (20, 14), "hut_door": (37, 15), "affliction": (5, 17), "board": (4, 17), "exit": (2, 15),
         "keepsake": (11, 12), "lair": (37, 15), "toys": (9, 12), "web_shrine": (30, 14)}
    for k in ("girl", "nurse", "rhymes", "board", "affliction", "keepsake", "toys", "hut_door", "web_shrine"):
        x, y = K[k]
        m.put([(x, y)], ".")
    areas = [("homestead", "The homestead", (2, 11), (11, 18)), ("woods", "The Webwoods", (12, 2), (31, 27)), ("clearing", "The clearing", (32, 9), (40, 21))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 15), "from_travel": (4, 15)}, theme="forest", light="dark", outdoors=True, exit_cell=(2, 15))


# ---- 7b. The Dusk Mother's hut: bigger inside than out ---------------------------------------------------------------------------
def dusk_mother_hut():
    m = M(34, 26, fill="#")
    m.fill(1, 1, 32, 24, ".")
    m.fill(1, 10, 32, 10, "#").fill(16, 10, 17, 10, ".")        # a long wall with a doorway to the stage
    m.fill(1, 17, 14, 17, "#").fill(7, 17, 8, 17, ".")           # the nursery
    m.fill(19, 17, 32, 17, "#").fill(25, 17, 26, 17, ".")
    m.fill(3, 3, 8, 5, "=").fill(24, 3, 30, 5, "=")               # cutting tables with shears and bolts
    m.fill(12, 12, 21, 15, "_")                                   # the stage of dolls
    m.put([(3, 19), (4, 19), (3, 20), (5, 22), (6, 22), (27, 19), (28, 19), (29, 22)], "=")   # cots and cradles
    m.put([(16, 4), (17, 4)], "=")
    K = {"door": (16, 23), "lair": (16, 13), "dais": (16, 13), "toys_nook": (4, 21), "nursery": (6, 19), "keepsake": (28, 21), "affliction": (16, 21), "board": (14, 22),
         "exit": (16, 24), "ledger": (27, 7)}
    for k in ("toys_nook", "keepsake", "affliction", "board", "ledger", "lair"):
        x, y = K[k]
        m.put([(x, y)], ".")
    areas = [("hut", "The hut that is bigger inside", (1, 1), (32, 24))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (16, 22), "from_woods": (16, 22)}, theme="manor", light="dark", outdoors=False, exit_cell=(16, 24))


# ---- 8. The Brimstone Behemoth: Rowan's Rise, a volcano -------------------------------------------------------------------------------
def rowans_volcano():
    m = M(46, 32)
    rng = random.Random(268)
    m.fill(2, 2, 43, 29, "~")                            # ash moor
    m.blob(36, 15, 8, 9, "1")
    m.blob(36, 15, 5, 6, "2")
    m.blob(36, 15, 3, 3, "w")                            # the crater's lava
    m.fill(2, 12, 12, 18, ".")                           # the doomsday camp
    m.fill(13, 14, 28, 16, ".")                          # the ash road up
    for x in range(14, 30):
        m.c[15][x] = "."
    for (cx, cy, rx, ry) in [(16, 6, 3, 2), (24, 24, 4, 2), (20, 20, 2, 5), (28, 8, 2, 4)]:
        m.blob(cx, cy, rx, ry, "w")                      # lava rivers
    m.fill(13, 14, 28, 16, ".")
    m.fill(2, 12, 12, 18, ".")
    m.fill(30, 13, 35, 17, "1").fill(31, 14, 34, 16, "2")
    m.scatter(rng, 40, "#", 14, 2, 43, 29, only="~")
    m.fill(13, 14, 28, 16, ".")
    m.fill(36, 9, 37, 11, "2")
    m.fill(30, 15, 33, 15, "2")
    for (x, y) in [(2, 15), (3, 15), (2, 14), (3, 14)]:
        m.c[y][x] = "."
    K = {"rowan": (30, 15), "camp": (6, 15), "cultist": (9, 13), "descendant": (8, 17), "lair": (34, 15), "dais": (34, 15), "lava_edge": (35, 13), "affliction": (6, 13),
         "board": (5, 17), "exit": (2, 15), "keepsake": (11, 17), "prayer": (10, 15)}
    for k in ("rowan", "cultist", "descendant", "board", "affliction", "keepsake", "prayer", "camp"):
        x, y = K[k]
        m.put([(x, y)], ".")
    m.put([(34, 15)], "2")
    areas = [("camp", "The doomsday camp", (2, 12), (12, 18)), ("moor", "The ash moor", (13, 3), (28, 28)), ("rise", "Rowan's Rise", (29, 8), (43, 23))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 15), "from_travel": (4, 15)}, theme="wilderness", light="dark", outdoors=True, exit_cell=(2, 15))


# ---- the last hill, the moon a few hundred feet up -------------------------------------------------------------------------------------
def last_hill():
    m = M(30, 22)
    rng = random.Random(269)
    m.fill(2, 2, 27, 19, ".")
    m.blob(15, 10, 7, 5, "1")
    m.blob(15, 10, 3, 2, "_")
    m.scatter(rng, 14, "=", 3, 3, 26, 18)
    m.scatter(rng, 10, "#", 3, 3, 26, 18)
    K = {"vagrant": (12, 12), "heroes": (15, 12), "moon_spot": (15, 8), "start": (4, 16), "back": (4, 17), "board": (20, 15)}
    for k in ("vagrant", "moon_spot", "board"):
        x, y = K[k]
        m.put([(x, y)], ".")
    m.put([(4, 16), (4, 17), (3, 16), (3, 17), (5, 16), (5, 17)], ".")
    areas = [("hill", "The hill under the moon", (2, 2), (27, 19))]
    return dict(m=m, K=K, areas=areas, spawns={"default": (4, 16), "from_rise": (4, 16)}, theme="wilderness", light="bright", outdoors=True, exit_cell=(3, 17))


MAPS = {"mf_round": round_hub, "mf_covered_bridge": covered_bridge, "mf_moonsong_rift": moonsong_rift, "mf_tall_man_palace": tall_man_palace, "mf_howlers_peaks": howlers_peaks,
        "mf_barrow_catacombs": barrow_catacombs, "mf_jinxed_bayou": jinxed_bayou, "mf_webwoods": webwoods, "mf_dusk_mother_hut": dusk_mother_hut,
        "mf_rowans_volcano": rowans_volcano, "mf_last_hill": last_hill}


def check_all():
    for name, fn in MAPS.items():
        d = fn()
        rows = d["m"].rows()
        sp = d["spawns"]["default"]
        assert rows[sp[1]][sp[0]] in ".~_1234", (name, "spawn", sp, rows[sp[1]][sp[0]])
        seen = reachable(rows, sp)
        for k, (x, y) in d["K"].items():
            ch = rows[y][x]
            if ch not in ".~_1234" and k not in ("hero", "heroes", "back"):
                print("BLOCKED key", name, k, (x, y), ch)
            elif (x, y) not in seen and ch in ".~_1234":
                print("UNREACHABLE key", name, k, (x, y))
        print(name, len(rows[0]), len(rows), len(seen))


if __name__ == "__main__":
    check_all()
