#!/usr/bin/env python3
"""Lays the hand-placed magic finds of data/treasure/world_finds.json into their places in data/locations (Ashwin, 2026-11-02:
more magic items to find in Acts I and II, each usable in a fight). An entry with `container` adds its items to that container
already in the place; any other entry is a container of its own, put the first time on a free corner of plain floor ('.' or a low dais, '_')
that the party can walk to from the place's default spawn, the one furthest from it, clear of every door, exit, spawn,
prop, container, light and person and the squares round them. The cell chosen is written back into world_finds.json, so
later runs (after a chapter's build script rewrote its places) put it in the same spot. A container stands on a floor
square without filling it, so no walkable square is lost. Safe to run again; `--check` says whether the places are current.

    python3 tools/content/place_world_finds.py [--check]"""
import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FINDS = ROOT / "data" / "treasure" / "world_finds.json"
WALKABLE = set(".~_1234")
FACES = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def cells_of(loc):
    taken = set()
    for key in ("props", "containers", "npcs", "lights", "doors", "exits", "traps"):
        for t in loc.get(key, []) or []:
            c = t.get("cell")
            if isinstance(c, list) and len(c) >= 2:
                taken.add((int(c[0]), int(c[1])))
    for c in (loc.get("spawns") or {}).values():
        if isinstance(c, list) and len(c) >= 2 and isinstance(c[0], int):
            taken.add((c[0], c[1]))
    return taken


def at(rows, x, z):
    if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
        return " "
    return rows[z][x]


def pick_cell(loc):
    rows = loc["map"]["rows"]
    start = tuple((loc.get("spawns") or {}).get("default", [0, 0]))
    dist = {start: 0}
    q = deque([start])
    while q:
        x, z = q.popleft()
        for dx, dz in FACES:
            n = (x + dx, z + dz)
            if n not in dist and at(rows, *n) in WALKABLE:
                dist[n] = dist[(x, z)] + 1
                q.append(n)
    near = set()
    for (x, z) in cells_of(loc):
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                near.add((x + dx, z + dz))
    best = None
    for (x, z), d in dist.items():
        if at(rows, x, z) not in "._" or (x, z) in near or d < 3:
            continue
        walls = sum(1 for dx, dz in FACES if at(rows, x + dx, z + dz) == "#")
        if walls == 0:
            continue
        key = (min(walls, 2), d, -z, -x)   # a corner first, then the furthest walk
        if best is None or key > best[0]:
            best = (key, [x, z])
    if best is None:
        raise SystemExit("%s: no free floor beside a wall for a find" % loc["id"])
    return best[1]


def main():
    check = "--check" in sys.argv
    cfg = json.loads(FINDS.read_text())
    stale = []
    cfg_changed = False
    by_loc = {}
    for f in cfg["finds"]:
        by_loc.setdefault(f["loc"], []).append(f)
    for loc_id, finds in by_loc.items():
        path = ROOT / "data" / "locations" / f"{loc_id}.json"
        before = path.read_text()
        loc = json.loads(before)
        conts = loc.setdefault("containers", [])
        for f in finds:
            items = [{"id": i, "qty": 1} for i in f["items"]]
            if "container" in f:
                c = next(c for c in conts if c["id"] == f["container"])
                have = {str(i["id"]) for i in c.get("items", [])}
                c.setdefault("items", []).extend(i for i in items if i["id"] not in have)
                continue
            c = next((c for c in conts if c["id"] == f["id"]), None)
            if c is None:
                if "cell" not in f:
                    f["cell"] = pick_cell(loc)
                    cfg_changed = True
                c = {"id": f["id"]}
                conts.append(c)
            elif "cell" not in f:
                f["cell"] = c["cell"]   # placed before its cell was written back
                cfg_changed = True
            c.update({"cell": f["cell"], "label": f["label"], "model": f["model"], "gold": 0, "lock_dc": int(f.get("lock_dc", 0)), "items": items})
        after = json.dumps(loc, indent=2, ensure_ascii=False) + "\n"
        if after != before:
            stale.append(loc_id)
            if not check:
                path.write_text(after)
    if cfg_changed and not check:
        FINDS.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
    print("%d finds in %d places%s" % (len(cfg["finds"]), len(by_loc), (": stale " + ", ".join(stale)) if check and stale else ""))
    if check and (stale or cfg_changed):
        sys.exit(1)


if __name__ == "__main__":
    main()
