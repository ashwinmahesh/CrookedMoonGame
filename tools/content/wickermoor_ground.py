#!/usr/bin/env python3
"""Paints Wickermoor Village's ground (map `ground` and `grounds`, ArenaBoard._plan_ground): grass between the houses (the
place's own floor, catalog `floors`), a cobbled Founder's Round with the high street running through it from the moor road
to the footbridge, and worn dirt lanes from the street to every door and way out. Run from the repo root after any change
to the village's rows, exits or spawns:
    python3 tools/content/wickermoor_ground.py

The lanes follow the shortest walk (eight ways, kept off walls), smoothed and widened with a little noise, so no edge
runs along the grid. Nothing here moves a square, a spawn or an exit."""
import heapq
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOC = ROOT / "data" / "locations" / "wickermoor_village.json"
GROUNDS = {"c": "real/cobblestone", "d": "real/path"}
WALKABLE = ".=1234_"
# The Founder's Round: an oval of cobbles round its middle, its edge broken by noise.
ROUND = (48.5, 38.5, 12.5, 11.5)
# The high street: the moor road in the north, through the Round, down to the footbridge (cobbled).
STREET = [(48, 1), (48, 13), (49, 26), (48, 38), (48, 52), (47, 62), (48, 74)]
STREET_WIDTH = 3.2
LANE_WIDTH = 1.9
# Where the lanes start from: squares on the street or the Round.
HUB = [(48, 8), (48, 20), (48, 38), (47, 58), (48, 70)]


def noise(x, y, scale=3.0, seed=11):
    """Smooth value noise in -1..1 (cosmetic only)."""
    def h(i, j):
        n = (i * 374761393 + j * 668265263 + seed * 2147483647) & 0xFFFFFFFF
        n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFF) / 32767.5 - 1.0
    fx, fy = x / scale, y / scale
    i, j = math.floor(fx), math.floor(fy)
    tx, ty = fx - i, fy - j
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = h(i, j) + (h(i + 1, j) - h(i, j)) * tx
    b = h(i, j + 1) + (h(i + 1, j + 1) - h(i, j + 1)) * tx
    return a + (b - a) * ty


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = 0.0 if dx == dy == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def line_dist(px, py, pts):
    return min(seg_dist(px, py, *pts[i], *pts[i + 1]) for i in range(len(pts) - 1))


def chaikin(pts, times=3):
    for _ in range(times):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out += [(a[0] * .75 + b[0] * .25, a[1] * .75 + b[1] * .25), (a[0] * .25 + b[0] * .75, a[1] * .25 + b[1] * .75)]
        out.append(pts[-1])
        pts = out
    return pts


def walk(rows, start, goals):
    """Shortest eight-way walk from `start` to the nearest of `goals`, dearer beside walls (lanes keep off the houses)."""
    w, d = len(rows[0]), len(rows)
    def ok(x, y):
        return 0 <= x < w and 0 <= y < d and rows[y][x] in WALKABLE
    def hug(x, y):
        return sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1) if 0 <= x + dx < w and 0 <= y + dy < d and rows[y + dy][x + dx] == "#")
    goals = set(goals)
    best = {start: 0.0}
    prev = {}
    todo = [(0.0, start)]
    while todo:
        cost, c = heapq.heappop(todo)
        if c in goals:
            path = [c]
            while c in prev:
                c = prev[c]
                path.append(c)
            return path[::-1]
        if cost > best.get(c, math.inf):
            continue
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (c[0] + dx, c[1] + dy)
                if (dx or dy) and ok(*n) and (not dx or not dy or (ok(c[0] + dx, c[1]) and ok(c[0], c[1] + dy))):
                    step = (1.414 if dx and dy else 1.0) + 0.6 * hug(*n)
                    if cost + step < best.get(n, math.inf):
                        best[n] = cost + step
                        prev[n] = c
                        heapq.heappush(todo, (cost + step, n))
    return []


def main():
    loc = json.loads(LOC.read_text())
    m = loc["map"]
    rows = m["rows"]
    w = m["floors"][0]["width"] if m.get("floors") else len(rows[0])
    d = len(rows)
    paint = [["." for _ in range(w)] for _ in range(d)]

    def open_square(x, y):
        return rows[y][x] in WALKABLE

    # Worn lanes first, so the street and the Round are cobbled over where they meet.
    street_cells = set()
    for y in range(d):
        for x in range(w):
            if open_square(x, y) and line_dist(x + .5, y + .5, STREET) < STREET_WIDTH:
                street_cells.add((x, y))
    hubs = [h for h in HUB if open_square(*h)]
    ends = [tuple(e["cell"]) for e in loc["exits"]]
    for key in loc["spawns"]:
        if key.startswith("from_"):
            ends.append(tuple(loc["spawns"][key]))
    lanes = []
    for end in ends:
        x, y = end
        if not (0 <= x < w and 0 <= y < d):
            continue
        if not open_square(x, y):   # a door in a wall: start from the open square before it
            near = [(x + dx, y + dy) for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)) if 0 <= x + dx < w and 0 <= y + dy < d and open_square(x + dx, y + dy)]
            if not near:
                continue
            end = near[0]
        if end in street_cells:
            continue
        path = walk(rows, end, street_cells or hubs)
        if len(path) > 1:
            lanes.append(chaikin([(px + .5, py + .5) for px, py in path]))
    for y in range(d):
        for x in range(w):
            if not open_square(x, y):
                continue
            px, py = x + .5, y + .5
            if any(line_dist(px, py, lane) < LANE_WIDTH / 2 + 0.45 * noise(px, py, 2.5, 3) for lane in lanes):
                paint[y][x] = "d"
    # The high street and the Round, cobbled.
    cx, cy, rx, ry = ROUND
    for y in range(d):
        for x in range(w):
            if not open_square(x, y):
                continue
            px, py = x + .5, y + .5
            r = math.hypot((px - cx) / rx, (py - cy) / ry)
            if r < 1.0 + 0.12 * noise(px, py, 3.0, 7):
                paint[y][x] = "c"
            elif line_dist(px, py, STREET) < STREET_WIDTH / 2 + 0.55 * noise(px, py, 2.5, 5):
                paint[y][x] = "c"
    m["ground"] = ["".join(r).rstrip(".") for r in paint]
    while m["ground"] and m["ground"][-1] == "":
        m["ground"].pop()
    m["grounds"] = GROUNDS
    LOC.write_text(json.dumps(loc, indent=2, ensure_ascii=False) + "\n")
    counts = {k: sum(r.count(k) for r in m["ground"]) for k in GROUNDS}
    print("wickermoor ground:", counts, "lanes:", len(lanes))
    for r in m["ground"]:
        print(r)


if __name__ == "__main__":
    main()
