#!/usr/bin/env python3
"""Spaces out Wickermoor Village (Ashwin, 2026-11-03: "Why is wickermoor village so cramped? Space it out a lot more").

A one-time rewrite of data/locations/wickermoor_village.json. The land (ground, water, height) is stretched by SCALE; every
house keeps its own size and shape and is carried to its stretched place, so the gaps between houses grow and nothing is
squeezed. Fences and one-square yard walls are redrawn along their stretched line. Doors, the squares in front of them and
anything standing beside a house move with the house; everything else moves with the land. The bridge deck (the second
floor) is stretched the same way and its ramps are laid again. Runs only on the old 96 x 50 map.

    python3 tools/content/space_out_wickermoor.py [--scale 1.6]
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "data/locations/wickermoor_village.json"
OLD_W, OLD_H, DECK_X0, DECK_W = 60, 50, 61, 35
OPEN = ".~1234_="


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", type=float, default=1.6)
    ap.add_argument("--src", default=str(PATH))
    ap.add_argument("--out", default=str(PATH))
    a = ap.parse_args()
    s = a.scale
    loc = json.loads(Path(a.src).read_text())
    m = loc["map"]
    rows: list[str] = m["rows"]
    if len(rows) != OLD_H or len(rows[0]) != 96:
        print("the village is not the old 96 x 50 map: already spaced out?", file=sys.stderr)
        return 1
    elev: list[str] = m["elevation"]
    W, H = OLD_W, OLD_H
    NW, NH = round(W * s), round(H * s)
    ND = math.ceil(DECK_W * s)
    grid = [list(r[:W]) for r in rows]
    deck = [list(r[DECK_X0:DECK_X0 + DECK_W]) for r in rows]

    # --- houses: squares of wall in some 2 x 2 of wall (TownBuilder's rule), grouped 4-connected ---
    wall = {(x, y) for y in range(H) for x in range(W) if grid[y][x] == "#"}
    block = set()
    for (x, y) in wall:
        for ox, oy in ((0, 0), (-1, 0), (0, -1), (-1, -1)):
            if all((x + ox + i, y + oy + j) in wall for i in (0, 1) for j in (0, 1)):
                block.add((x, y))
                break
    group: dict[tuple[int, int], int] = {}
    groups: list[list[tuple[int, int]]] = []
    for c in sorted(block):
        if c in group:
            continue
        gi = len(groups)
        groups.append([])
        q = deque([c])
        group[c] = gi
        while q:
            p = q.popleft()
            groups[gi].append(p)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (p[0] + dx, p[1] + dy)
                if n in block and n not in group:
                    group[n] = gi
                    q.append(n)
    offsets: list[tuple[int, int]] = []
    for cells in groups:
        x0 = min(c[0] for c in cells); x1 = max(c[0] for c in cells)
        y0 = min(c[1] for c in cells); y1 = max(c[1] for c in cells)
        w, h = x1 - x0 + 1, y1 - y0 + 1
        dx = round(s * (x0 + w / 2) - w / 2) - x0
        dy = round(s * (y0 + h / 2) - h / 2) - y0
        # A house running off the map's edge stays against the edge.
        if x0 == 0:
            dx = 0
        elif x1 == W - 1:
            dx = NW - 1 - x1
        if y0 == 0:
            dy = 0
        elif y1 == H - 1:
            dy = NH - 1 - y1
        offsets.append((dx, dy))
    lines = {c for c in wall if c not in block}
    fences = {(x, y) for y in range(H) for x in range(W) if grid[y][x] == "="}

    # --- the land under everything, walls and fences filled in from the nearest open ground ---
    ground = [row[:] for row in grid]
    q = deque((x, y) for y in range(H) for x in range(W) if ground[y][x] not in "#=")
    seen = set(q)
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if 0 <= n[0] < W and 0 <= n[1] < H and n not in seen:
                ground[n[1]][n[0]] = ground[y][x]
                seen.add(n)
                q.append(n)

    def src(i: int, n: int) -> int:
        return min(n - 1, int((i + 0.5) / s))

    def height(x: float, y: float, rows_e: list[str], x0: int, w: int) -> int:
        # Bilinear over the old heights, so a slope stays a slope.
        fx = min(max((x + 0.5) / s - 0.5, 0), w - 1); fy = min(max((y + 0.5) / s - 0.5, 0), H - 1)
        ix, iy = int(fx), int(fy); tx, ty = fx - ix, fy - iy
        def e(xx: int, yy: int) -> float:
            ch = rows_e[min(yy, H - 1)][x0 + min(xx, w - 1)]
            return float(ch) if ch.isdigit() else -1.0
        vals = [e(ix, iy), e(ix + 1, iy), e(ix, iy + 1), e(ix + 1, iy + 1)]
        if min(vals) < 0:
            return -1
        v = (vals[0] * (1 - tx) + vals[1] * tx) * (1 - ty) + (vals[2] * (1 - tx) + vals[3] * tx) * ty
        return int(round(v))

    new = [[ground[src(y, H)][src(x, W)] for x in range(NW)] for y in range(NH)]
    new_e = [[str(height(x, y, elev, 0, W)) for x in range(NW)] for y in range(NH)]

    def put_line(cells: set[tuple[int, int]], ch: str) -> None:
        def at(c: tuple[int, int]) -> tuple[int, int]:
            return (min(NW - 1, round(s * c[0])) if c[0] < W - 1 else NW - 1, min(NH - 1, round(s * c[1])) if c[1] < H - 1 else NH - 1)
        for c in cells:
            a = at(c)
            new[a[1]][a[0]] = ch
            for dx, dy in ((1, 0), (0, 1)):
                n = (c[0] + dx, c[1] + dy)
                if n in cells:
                    b = at(n)
                    x, y = a
                    while (x, y) != b:   # four-connected, so the line still closes
                        if x != b[0]:
                            x += 1 if b[0] > x else -1
                        else:
                            y += 1 if b[1] > y else -1
                        new[y][x] = ch

    put_line(fences, "=")
    put_line(lines, "#")
    for gi, cells in enumerate(groups):
        dx, dy = offsets[gi]
        for (x, y) in cells:
            new[y + dy][x + dx] = "#"

    # --- points: beside a house they ride with it, elsewhere with the land ---
    def near_group(p: tuple[int, int]) -> int:
        best, bd = -1, 99
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                g = group.get((p[0] + dx, p[1] + dy), -1)
                if g >= 0 and abs(dx) + abs(dy) < bd:
                    best, bd = g, abs(dx) + abs(dy)
        return best

    def scale_pt(p: list[int]) -> list[int]:
        x = 0 if p[0] == 0 else NW - 1 if p[0] == W - 1 else min(NW - 2, round(s * (p[0] + 0.5) - 0.5))
        y = 0 if p[1] == 0 else NH - 1 if p[1] == H - 1 else min(NH - 2, round(s * (p[1] + 0.5) - 0.5))
        return [x, y]

    def pm(p: list[int], stand: bool = True) -> list[int]:
        if p[0] >= W:
            return p
        g = near_group((p[0], p[1]))
        out = [p[0] + offsets[g][0], p[1] + offsets[g][1]] if g >= 0 else scale_pt(p)
        if stand and grid[p[1]][p[0]] in OPEN and new[out[1]][out[0]] not in OPEN:
            out = nearest_open(out)
        return out

    def nearest_open(p: list[int]) -> list[int]:
        for r in range(1, 6):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    x, y = p[0] + dx, p[1] + dy
                    if 0 <= x < NW and 0 <= y < NH and new[y][x] in OPEN and new[y][x] != "=":
                        return [x, y]
        return p

    for e in loc["exits"]:
        e["cell"] = pm(e["cell"], stand=False)
    loc["spawns"] = {k: (pm(v) if isinstance(v[0], int) else [pm(c) for c in v]) for k, v in loc["spawns"].items()}
    for n in loc["npcs"]:
        n["cell"] = pm(n["cell"])
        if "path" in n:
            n["path"] = [pm(c) for c in n["path"]]
        if "approach" in n:
            n["approach"] = min(12, round(n["approach"] * s))   # the schema caps it at 12
    for p in loc["props"]:
        p["cell"] = pm(p["cell"], stand=False)
        if "approach" in p:
            p["approach"] = min(12, round(p["approach"] * s))
    for enc in loc["encounters"]:
        taken: set[tuple[int, int]] = set()
        for mon in enc["monsters"]:
            c = pm(mon["cell"])
            while tuple(c) in taken or new[c[1]][c[0]] not in OPEN or new[c[1]][c[0]] == "=":
                c = [c[0] + 1, c[1]] if new[c[1]][min(NW - 1, c[0] + 1)] in OPEN else nearest_open([c[0], c[1] + 1])
            taken.add(tuple(c))
            mon["cell"] = c
    for ar in loc.get("areas", []):
        (x0, y0), (x1, y1) = ar["cells"]
        ar["cells"] = [[round(s * x0), round(s * y0)], [min(NW - 1, round(s * (x1 + 1)) - 1), min(NH - 1, round(s * (y1 + 1)) - 1)]]

    # --- the bridge deck, stretched, and its ramps laid again ---
    nd = [[deck[src(y, H)][src(x, DECK_W)] for x in range(ND)] for y in range(NH)]
    nd_e = [["." for x in range(ND)] for y in range(NH)]
    stairs = []
    old_cols = sorted({st["from"][0] for st in m["stairs"]})
    deck_row = m["stairs"][0]["to"][1]
    for x in range(NW):
        if src(x, W) not in old_cols:
            continue
        rows_on_deck = [y for y in range(NH) if src(y, H) == deck_row and nd[y][x] != " "]
        if not rows_on_deck:
            continue
        top, bot = min(rows_on_deck), max(rows_on_deck)
        for gy, dy in ((top - 1, top), (bot + 1, bot)):
            if 0 <= gy < NH and new[gy][x] in OPEN:
                stairs.append({"from": [x, gy], "to": [NW + 1 + x, dy], "kind": "ramp"})
    m["stairs"] = stairs
    m["floors"][0]["width"] = NW
    m["floors"][1]["x0"] = NW + 1
    m["floors"][1]["width"] = ND
    m["rows"] = ["".join(new[y]) + " " + "".join(nd[y]) for y in range(NH)]
    m["elevation"] = ["".join(new_e[y]) + "." + "".join(nd_e[y]) for y in range(NH)]
    Path(a.out).write_text(json.dumps(loc, indent=2, ensure_ascii=False) + "\n")
    print(f"{W}x{H} -> {NW}x{NH} (+ deck {ND}), {len(groups)} houses, {len(stairs)} ramps")
    return 0


if __name__ == "__main__":
    sys.exit(main())
