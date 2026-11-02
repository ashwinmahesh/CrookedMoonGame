#!/usr/bin/env python3
"""A building's floor places merged into one multi-floor place (Ashwin, 2026-11-02: "we no longer need to separate floors into
different areas ... These can all be a single multi-floor area"; the engine's CombatGrid.apply_floors).

Each floor's map is laid in its own columns of one map, side by side with a column of void between, its squares moved by
where the floor lies in the building (dx, dz) so the floors stand over each other; every square in its data moves with it
(props, doors, lights, traps, people, fights and their foes, areas, spawns). The exits from one floor to another become
the map's `stairs` (the exit's square to the square its spawn puts the party on); the exits out of the building stay. Spawns
of the first floor keep their names, the others' are prefixed with their floor's short name (second_from_below). Each
entry of `map.floors` keeps the floor place's id, so the game marks it visited and says its entering words when the party
first climbs to it.

    python3 tools/content/merge_floors.py crooked_house             # writes data/locations/crooked_house.json
    python3 tools/content/merge_floors.py crooked_house --check     # prints the layout, writes nothing
"""
import copy
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOC = ROOT / "data" / "locations"
STOREY_FT = 15

# merged id -> its name, and its floors from the ground up: (place id, short name, dx, dz) where (dx, dz) is where the floor's
# own map lies in the building, worked out from its stairs so each stair's top meets the square it comes out on.
BUILDINGS = {
    "crooked_house": {
        "name": "The Crooked House",
        "from": "751d2e25",   # the commit whose four floor places this was merged from
        "floors": [
            ("crooked_house_first", "first", 0, 0),
            ("crooked_house_second", "second", 0, 0),
            ("crooked_house_third", "third", 3, 1),
            ("crooked_house_attic", "attic", 21, 1),
        ],
    },
}
# Keys whose value is one square [x, z], and keys whose value is a list of squares.
CELL = {"cell"}
CELLS = {"cells"}
LISTS = ["areas", "doors", "props", "containers", "lights", "traps", "npcs", "encounters"]


def shift(o, dx, dz):
    """Every square in `o` moved by (dx, dz)."""
    if isinstance(o, dict):
        out = {}
        for k, v in o.items():
            if k in CELL and _is_cell(v):
                out[k] = [v[0] + dx, v[1] + dz]
            elif k in CELLS and isinstance(v, list) and all(_is_cell(c) for c in v):
                out[k] = [[c[0] + dx, c[1] + dz] for c in v]
            else:
                out[k] = shift(v, dx, dz)
        return out
    if isinstance(o, list):
        return [shift(x, dx, dz) for x in o]
    return o


def _floor_place(pid, rev):
    """A floor's place file: in data/locations while it is still there, else as git had it at `rev` (the merge removes them)."""
    path = LOC / (pid + ".json")
    if path.exists():
        return json.loads(path.read_text())
    return json.loads(subprocess.run(["git", "show", "%s:data/locations/%s.json" % (rev, pid)], cwd=ROOT, check=True,
                                     capture_output=True, text=True).stdout)


def _is_cell(v):
    return isinstance(v, list) and len(v) == 2 and all(isinstance(x, int) for x in v)


def merge(bid):
    spec = BUILDINGS[bid]
    floors = [(pid, short, dx, dz, _floor_place(pid, spec.get("from", "HEAD"))) for pid, short, dx, dz in spec["floors"]]
    ids = [f[0] for f in floors]
    depth = max(len(f[4]["map"]["rows"]) + f[3] for f in floors)
    blocks = []
    x0 = 0
    for pid, short, dx, dz, loc in floors:
        w = max(len(r) for r in loc["map"]["rows"]) + dx
        blocks.append({"x0": x0, "width": w, "dx": dx, "dz": dz})
        x0 += w + 1
    width = x0 - 1
    rows = [[" "] * width for _ in range(depth)]
    for b, (pid, short, dx, dz, loc) in zip(blocks, floors):
        for z, r in enumerate(loc["map"]["rows"]):
            for x, ch in enumerate(r):
                rows[z + dz][b["x0"] + dx + x] = ch
    first = floors[0][4]
    out = {k: copy.deepcopy(v) for k, v in first.items() if k not in LISTS + ["exits", "spawns", "map"]}
    out["id"] = bid
    out["name"] = spec["name"]
    out["map"] = {k: v for k, v in first["map"].items() if k not in ("rows", "elevation")}
    out["map"]["rows"] = ["".join(r) for r in rows]
    out["map"]["floors"] = [{"x0": b["x0"], "width": b["width"], "height_ft": i * STOREY_FT, "id": f[0],
                             "offset": [b["x0"] + b["dx"], b["dz"]]} for i, (b, f) in enumerate(zip(blocks, floors))]
    spawns = {}
    stairs = []
    exits = []
    seen_ids = {k: set() for k in LISTS}
    for k in LISTS:
        out[k] = []
    for i, (b, (pid, short, dx, dz, loc)) in enumerate(zip(blocks, floors)):
        mx, mz = b["x0"] + dx, dz
        prefix = "" if i == 0 else short + "_"
        for name, cell in loc.get("spawns", {}).items():
            spawns[prefix + name] = [cell[0] + mx, cell[1] + mz]
        for k in LISTS:
            for e in loc.get(k, []):
                e2 = shift(e, mx, mz)
                if "id" in e2 and k != "encounters" and e2["id"] in seen_ids[k]:
                    e2["id"] = "%s_%s" % (e2["id"], short)
                seen_ids[k].add(e2.get("id", ""))
                out[k].append(e2)
    for i, (b, (pid, short, dx, dz, loc)) in enumerate(zip(blocks, floors)):
        mx, mz = b["x0"] + dx, dz
        for e in loc.get("exits", []):
            if e["to"] in ids and ids.index(e["to"]) > i:
                j = ids.index(e["to"])
                # The stair runs between where each floor's way to the other sets the party down: the square on this floor
                # the way back down arrives at, and the square on the next floor this way up arrives at.
                back = next((b for b in floors[j][4].get("exits", []) if b["to"] == pid), {})
                here = loc["spawns"][back.get("spawn", "default")]
                there = floors[j][4]["spawns"][e.get("spawn", "default")]
                tb = blocks[j]
                stair = {"from": [here[0] + mx, here[1] + mz], "to": [there[0] + tb["x0"] + tb["dx"], there[1] + tb["dz"]]}
                for key in ("when", "locked_text"):
                    if key in e or key in back:
                        stair[key] = e.get(key, back.get(key))
                stairs.append(stair)
            if e["to"] in ids:
                # Kept as a way within the place: stepping onto it climbs the stair (the party set down on the other floor).
                j = ids.index(e["to"])
                way = shift(e, mx, mz)
                way["to"] = bid
                way["spawn"] = ("" if j == 0 else floors[j][1] + "_") + e.get("spawn", "default")
                if i > 0 and sum(1 for f in floors for x in f[4].get("exits", []) if x["id"] == e["id"]) > 1:
                    way["id"] = "%s_%s" % (way["id"], short)   # (an id two floors share: stairs_down_second)
                exits.append(way)
                continue
            exits.append(shift(e, mx, mz))
    out["map"]["stairs"] = stairs
    out["exits"] = exits
    out["spawns"] = spawns
    for k in LISTS:
        if not out[k]:
            del out[k]
    return out, blocks


def main():
    bid = sys.argv[1]
    merged, blocks = merge(bid)
    if "--check" in sys.argv:
        print("%d x %d, floors %s" % (len(merged["map"]["rows"][0]), len(merged["map"]["rows"]), blocks))
        print("stairs", merged["map"]["stairs"])
        print("spawns", merged["spawns"])
        for r in merged["map"]["rows"]:
            print(r)
        return
    (LOC / (bid + ".json")).write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n")
    print("wrote data/locations/%s.json" % bid)


if __name__ == "__main__":
    main()
