#!/usr/bin/env python3
"""R17, Memory's Rest: the grids. Ground floor and upper floor share one footprint (39 x 36): two wings joined by a central block, a ring corridor round the
open-air Airing Grounds, Reception on the south. The Grotto of Tears is a cave (33 x 44). The shore is a small outdoor rim (30 x 24).
    python3 tools/content/memorys_rest_maps.py        prints every grid"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G

W, H = 39, 36


def box(g, x0, y0, x1, y1, doors=()):
    """Walls on the rectangle's border (x0..x1, y0..y1), floor inside; `doors` are border cells opened to floor."""
    g.wall(x0, y0, x1, y1).room(x0 + 1, y0 + 1, x1 - 1, y1 - 1)
    for (x, y) in doors:
        g.fill(x, y, x, y, ".")
    return g


def ground():
    g = G(W, H).room(1, 1, W - 2, H - 2)
    # the wings' walls and the courtyard's wall
    g.wall(10, 1, 10, H - 2).wall(27, 1, 27, H - 2)               # wing walls
    g.wall(11, 7, 26, 7)                                           # the north block's floor line
    box(g, 13, 10, 24, 21)                                         # the Airing Grounds' wall
    g.fill(14, 11, 23, 20, ".")
    g.wall(13, 26, 24, 26)                                         # Reception's north wall
    g.wall(13, 27, 13, H - 2).wall(24, 27, 24, H - 2)             # Reception's side walls
    # doors out of the courtyard (glass doors), Reception, the north block
    for (x, y) in [(13, 16), (24, 16), (18, 10), (19, 10), (18, 21), (19, 21), (18, 26), (19, 26), (15, 7), (23, 7)]:
        g.fill(x, y, x, y, ".")
    g.wall(19, 1, 19, 6)                                           # Matron's Office | kitchen
    # west wing, north to south: theater, exam, station a, elevator a, pharmacy, common room
    for y in (10, 16, 20, 23, 27):
        g.wall(1, y, 9, y)
    for (x, y) in [(10, 8), (10, 13), (10, 18), (10, 22), (10, 25), (10, 31)]:
        g.fill(x, y, x, y, ".")
    # east wing: Moon Porch, station b, elevator b, then the landing and the recovery cells
    for y in (10, 14, 18):
        g.wall(28, y, 37, y)
    for (x, y) in [(27, 8), (27, 12), (27, 16), (27, 19)]:
        g.fill(x, y, x, y, ".")
    g.wall(28, 18, 37, 18)
    g.fill(28, 19, 37, 19, ".")                                    # the landing
    for y in (22, 25, 28, 31, 34):
        g.wall(28, y, 30, y).wall(35, y, 37, y)
    g.wall(31, 20, 31, 34).wall(34, 20, 34, 34)
    for y in (20, 23, 26, 29, 32):                                # cell doors on both aisle walls (the middle row of each cell pair)
        g.fill(31, y, 31, y, ".").fill(34, y, 34, y, ".")
    # fixtures drawn as low obstacles
    # theater: raked seats round a pit
    for y in (2, 3, 4):
        g.fill(2, y, 3, y, "=").fill(7, y, 8, y, "=")
    g.fill(2, 7, 8, 7, "=")
    # exam room: the table and cabinets
    g.fill(4, 13, 6, 13, "=").fill(2, 11, 2, 15, "=")
    # station a: the desk and cabinet
    g.fill(2, 17, 5, 17, "=")
    # pharmacy counters
    g.fill(2, 25, 8, 25, "=")
    # common room: tables and the queue's rail
    g.put([(3, 29), (4, 29), (7, 29), (8, 29), (3, 32), (4, 32), (7, 32), (8, 32)], "=")
    # courtyard hedges (the gravel loop) and benches
    g.fill(16, 13, 21, 13, "=").fill(16, 18, 21, 18, "=").fill(15, 14, 15, 17, "=").fill(22, 14, 22, 17, "=").put([(15, 16), (22, 16)], ".")   # a gap in the gravel loop at each glass door
    # reception desk, chairs
    g.fill(16, 29, 21, 29, "=").put([(15, 32), (16, 32), (21, 32), (22, 32)], "=")
    # north block: matron's desk, shelves; kitchen counters
    g.fill(13, 2, 16, 2, "=").put([(21, 3), (22, 3), (24, 3), (25, 3), (21, 5), (22, 5), (24, 5), (25, 5)], "=")   # the Visitation Room's chairs, in pairs
    # moon porch cots
    for y in (3, 5, 7):
        g.fill(29, y, 31, y, "=").fill(34, y, 36, y, "=")
    # recovery cells: a bed in each
    for y in (20, 23, 26, 29, 32):
        g.put([(29, y), (36, y)], "=")
    # station b, elevator b lobbies
    g.fill(29, 11, 32, 11, "=")
    # opening the cell rows' second row of walls: each cell is two rows high (y, y+1), with the door on the first
    return g


def ground_rows():
    return ground().rows()


def upper():
    g = G(W, H).room(1, 1, W - 2, H - 2)
    g.wall(10, 1, 10, H - 2).wall(27, 1, 27, H - 2)
    g.wall(11, 7, 26, 7)
    g.wall(13, 10, 24, 21)                                         # the courtyard's footprint: a block with long windows
    g.wall(13, 26, 24, 26).wall(13, 27, 13, H - 2).wall(24, 27, 24, H - 2)
    g.wall(19, 1, 19, 6)
    for (x, y) in [(15, 7), (23, 7)]:
        g.fill(x, y, x, y, ".")
    # west wing (Processing): L14 apartments, L15 restraint, L16 sedation hall, L17 Godlee, L18 crematorium
    for y in (10, 16, 23, 29):
        g.wall(1, y, 9, y)
    for (x, y) in [(10, 8), (10, 13), (10, 20), (10, 26), (10, 32)]:
        g.fill(x, y, x, y, ".")
    for x in (2, 4, 6, 8):                                         # five alcoves in the apartments: a narrow cot each
        g.wall(x, 1, x, 3)
    g.put([(1, 2), (3, 2), (5, 2), (7, 2), (9, 2)], "=")
    g.put([(3, 13), (4, 13), (5, 13)], "=")                        # the bolted chair and its tray
    for x in (2, 4, 6, 8):
        for y in (18, 20, 22):
            g.fill(x, y, x, y, "=")                                # twelve curtained beds
    g.fill(2, 25, 8, 25, "=").put([(3, 27), (4, 27)], "=")         # Godlee's desk and bed
    g.fill(2, 31, 4, 31, "=").fill(6, 31, 8, 31, "=").fill(2, 33, 8, 33, "=")   # cremators and lockers
    # north block: L19 quarters (study + bedroom), L20 engineering
    g.wall(11, 4, 18, 4).fill(14, 4, 15, 4, ".")                   # study above, bedroom below the line
    g.fill(12, 2, 17, 2, "=").put([(12, 6), (13, 6)], "=")
    g.fill(21, 2, 25, 3, "=")                                      # the central cylinder
    # east wing (Experimental): L26 lab, L21 Hugo's den, L22 containment, L23 Belkin, L24 surgeons + L25 chambers
    for y in (10, 14, 22, 28):
        g.wall(28, y, 37, y)
    for (x, y) in [(27, 8), (27, 12), (27, 18), (27, 25), (27, 31)]:
        g.fill(x, y, x, y, ".")
    g.fill(29, 3, 36, 3, "=").fill(29, 7, 33, 7, "=")               # lab benches
    g.fill(29, 12, 32, 12, "=")                                     # Hugo's mat
    box(g, 30, 17, 37, 21, doors=[(30, 19)])                        # the glass chamber, its door a wall panel
    g.fill(30, 24, 34, 24, "=")                                     # Belkin's steel desk
    g.wall(33, 29, 33, 34).fill(33, 31, 33, 31, ".")                 # surgeons | chambers
    g.wall(34, 32, 37, 32).fill(33, 30, 33, 30, ".").fill(33, 33, 33, 33, ".")
    g.put([(29, 30), (31, 30), (29, 32), (31, 32), (29, 34), (31, 34)], "=")   # the six metal pods
    # the Laboratory (L27) over Reception: smooth walls, one door in each side wall
    g.fill(13, 30, 13, 30, ".").fill(24, 30, 24, 30, ".")
    g.fill(15, 28, 22, 28, "=").fill(15, 33, 22, 33, "=").put([(17, 31), (18, 31), (20, 31), (21, 31)], "=")
    return g


def grotto():
    w, h = 33, 44
    g = G(w, h)
    # a cave: everything starts as rock, then the folds are carved out
    g.fill(1, 1, w - 2, h - 2, ".")
    # rock folds: irregular intrusions along the walls
    for (x0, y0, x1, y1) in [(1, 1, 6, 6), (26, 1, 31, 5), (1, 14, 3, 20), (29, 12, 31, 22), (1, 30, 5, 36), (27, 30, 31, 38), (8, 40, 12, 42), (20, 40, 25, 42),
                             (9, 1, 12, 3), (21, 1, 24, 3)]:
        g.wall(x0, y0, x1, y1)
    # the north chamber: a narrow stone bridge over a glowing pool to the round platform
    g.fill(8, 5, 24, 11, "~")                                       # pool (bubbling, difficult)
    g.fill(15, 5, 17, 11, ".")                                      # the bridge, three wide
    g.fill(10, 12, 22, 20, "_")                                     # the platform, a low dais
    g.fill(14, 14, 18, 18, "_")
    g.put([(8, 12), (9, 12), (23, 12), (24, 12), (8, 20), (24, 20)], "~")
    # side pools
    g.fill(4, 22, 8, 27, "~").fill(24, 23, 28, 28, "~")
    g.fill(13, 24, 19, 26, "~")
    # the south tunnel and the lift landing (west)
    g.wall(13, 38, 13, 43).wall(19, 38, 19, 43)
    g.fill(1, 21, 3, 23, ".")
    # vats and tanks drawn as low obstacles
    for (x, y) in [(6, 9), (7, 9), (25, 9), (26, 9), (6, 33), (7, 33), (25, 33), (26, 33)]:
        g.put([(x, y)], "=")
    g.fill(10, 30, 12, 31, "=").fill(20, 30, 22, 31, "=")          # fermentation vats
    g.fill(5, 15, 6, 17, "=").fill(26, 15, 27, 17, "=")            # mutation tanks
    return g


def shore():
    w, h = 30, 24
    g = G(w, h)
    g.fill(0, 0, w - 1, h - 1, "w")                                 # the lake, then land
    g.fill(0, 12, w - 1, h - 1, ".")
    g.fill(0, 9, w - 1, 11, "~")                                    # reed and mud rim
    g.fill(8, 9, 10, 11, ".")                                       # a stony landing
    g.put([(9, 7), (9, 8)], "_")                                    # the stake's little jetty
    g.fill(9, 5, 9, 6, "_")
    # the fisher's hut
    g.wall(18, 14, 24, 19).room(19, 15, 23, 18)
    g.fill(21, 19, 21, 19, ".")
    # boulders and willow-shaped rocks
    g.put([(3, 14), (4, 14), (3, 15), (27, 20), (13, 20), (14, 20)], "#")
    return g


def show(rows, name):
    print("==", name, len(rows[0]), "x", len(rows))
    print("    " + "".join(str(i % 10) for i in range(len(rows[0]))))
    for i, r in enumerate(rows):
        print(f"{i:3d} {r}")


if __name__ == "__main__":
    show(ground().rows(), "ground")
    show(upper().rows(), "upper")
    show(grotto().rows(), "grotto")
    show(shore().rows(), "shore")
