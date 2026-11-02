#!/usr/bin/env python3
"""Decks laid into a place as layers of their own (the full 3D grid build, lane B2, 2026-11-02): a balcony round a hall, a walkway
under a roof, a stone bridge over pools, platforms hung on chains. Each deck is a `map.floors` entry of kind "deck" whose columns
are open air (void) except the deck itself, laid beside the place's other floors, its squares over the floor it stands above; its
`stairs` (a stair, a ladder or a ramp) join it to that floor (the engine's CombatGrid.apply_floors).

Two ways to lay one:
- `add`: the deck is new, over squares that stay as they are under it (a balcony over the ring of the hall floor, a walkway over
  the roost floor). Nothing on the floor below moves.
- `lift`: the deck was drawn as raised ground (height digits, a flat-topped block that gave the grid away); its squares go up to the
  deck at the same height, with what stood on them (props, people, foes, the areas named in `areas`), and the ground under it is
  open floor (`under`).

A place is read as it stood at the commit named in `from` (never the working tree: this tool writes over it), or for a place merged
from its floors, from merge_floors.py's merge of it; so a run is the same however often it is made. Run it after merge_floors.py:
a merge writes its place without its decks.

    python3 tools/content/layer_decks.py dc_casino            # writes data/locations/dc_casino.json
    python3 tools/content/layer_decks.py dc_casino --check    # prints the map, writes nothing
    python3 tools/content/layer_decks.py --all
"""
import copy
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import merge_floors

ROOT = Path(__file__).resolve().parents[2]
LOC = ROOT / "data" / "locations"
FROM = "b46abefc"   # main before the layered places of Act II
DIGITS = "1234"


def rect(x0, z0, x1, z1):
    return {(x, z) for x in range(x0, x1 + 1) for z in range(z0, z1 + 1)}


def ring(x0, z0, x1, z1, w):
    """The squares of a band `w` wide just inside the rectangle (x0, z0)-(x1, z1)."""
    return {(x, z) for (x, z) in rect(x0, z0, x1, z1) if x < x0 + w or x > x1 - w or z < z0 + w or z > z1 - w}


# place id -> its decks. `on`: the floor the deck stands over (a floor id of the place; the place itself when it has one floor).
# `cells`: the deck's squares in that floor's own squares (as its own map had them). `height_ft`: how far over that floor the deck
# stands. `rail_ft`: the height of the railing or parapet along its open edges (none on the tomb's platforms, hung bare on
# their chains). `stairs`: (square on the floor below, square on the deck, kind), both in that floor's own squares.
DECKS = {
    # The Jinxcraft Casino: the balcony that runs all round the drowned hall, ten feet over the dais ring under it, with a stair up
    # at each south corner. The hall's floor stays as it was under it.
    "dc_casino": [{
        "id": "dc_casino_balcony", "on": "dc_casino", "mode": "add", "height_ft": 10, "rail_ft": 3,
        "cells": ring(1, 1, 16, 24, 2),
        "stairs": [((3, 22), (2, 22), "stair"), ((14, 22), (15, 22), "stair")],
    }],
    # Golub's roost floor in the walking dovecote: the walkway under the thatch along the tops of the roost cubbies, and the swivel
    # ladder up to it from beside its track.
    "rk_dovecote_r1": [{
        "id": "rk_dovecote_walkway", "on": "rk_dovecote_r2", "mode": "add", "height_ft": 10, "rail_ft": 3,
        "cells": ring(1, 1, 22, 16, 2),
        "stairs": [((6, 15), (6, 16), "ladder")],
    }],
    # The Grotto of Tears: the stone bridge from the north tunnel to the platform of glyphs arches over the glowing pools, which
    # now run on under it; a ramp up from the tunnel's mouth and down onto the platform.
    "mr_grotto": [{
        "id": "mr_grotto_bridge", "on": "mr_grotto", "mode": "add", "height_ft": 5, "rail_ft": 3,
        "cells": rect(15, 5, 17, 11), "under": "~",
        "stairs": [((16, 4), (16, 5), "ramp"), ((16, 12), (16, 11), "ramp")],
    }],
    # The Tomb of the Shrouded: its three-pronged platforms hang on the giant chains, the first ten feet over the tomb floor and the
    # highest twenty, with the tomb floor running on under both. The steps at the first platform's foot climb onto it, and the
    # last step at its back up to the hanging platform.
    "mm_tomb": [{
        "id": "mm_tomb_first_platform", "on": "mm_tomb", "mode": "lift", "height_ft": 10,
        "cells": {c for c in rect(6, 7, 15, 13)}, "areas": ["first"],
        "stairs": [((x, 14), (x, 13), "stair") for x in (8, 11, 13)],
    }, {
        "id": "mm_tomb_hanging_platform", "on": "mm_tomb", "mode": "lift", "height_ft": 20,
        "cells": {c for c in rect(6, 2, 15, 6)}, "areas": ["second"],
        "stairs": [],
        # (joined to the first platform: its 15 ft step at the back, row 7, climbs to the hanging platform's row 6)
        "deck_stairs": [("mm_tomb_first_platform", (x, 7), (x, 6), "stair") for x in (6, 10, 14)],
    }],
}
# place id -> exit id -> what the exit now says: ways out that lead into a place merged from its floors (merge_floors.py).
EXITS = {
    "dc_casino": {"back_to_hall": {"to": "dc_boat_promenade", "spawn": "hall_from_casino"}},   # (the hall is a floor of the boat)
    "mr_grotto": {"lift_up": {"to": "mr_ground", "spawn": "upper_from_lab"}},   # (the second floor is a floor of Memory's Rest)
}
LISTS = ["props", "npcs", "containers", "lights", "traps"]


def _git_json(rel, rev):
    return json.loads(subprocess.run(["git", "show", "%s:%s" % (rev, rel)], cwd=ROOT, check=True, capture_output=True,
                                     text=True).stdout)


def source(pid):
    """The place as it stands before its decks."""
    if pid in merge_floors.BUILDINGS:
        return merge_floors.merge(pid)[0]
    return _git_json("data/locations/%s.json" % pid, FROM)


def _floor_entry(loc, fid):
    """(x0, dz, height_ft) of floor `fid`'s own squares in the place's map: where its own (0, 0) lies, and its height."""
    m = loc["map"]
    for f in m.get("floors", []):
        if f["id"] == fid:
            off = f.get("offset", [f["x0"], 0])
            return off[0], off[1], int(f["height_ft"]), f
    raise KeyError(fid)


def _in(cells, v):
    return isinstance(v, list) and len(v) == 2 and all(isinstance(x, int) for x in v) and (v[0], v[1]) in cells


def _shift_on(o, cells, dx):
    """Every square of `o` (a prop, a person, a fight) that lies on `cells` moved `dx` columns (onto the deck)."""
    if isinstance(o, dict):
        out = {}
        for k, v in o.items():
            if k == "cell" and _in(cells, v):
                out[k] = [v[0] + dx, v[1]]
            elif k == "cells" and isinstance(v, list) and v and all(_in(cells, c) for c in v):
                out[k] = [[c[0] + dx, c[1]] for c in v]
            else:
                out[k] = _shift_on(v, cells, dx)
        return out
    if isinstance(o, list):
        return [_shift_on(x, cells, dx) for x in o]
    return o


def lay(pid):
    loc = copy.deepcopy(source(pid))
    for e in loc.get("exits", []):
        e.update(EXITS.get(pid, {}).get(e["id"], {}))
    m = loc["map"]
    rows = [list(r) for r in m["rows"]]
    width = max(len(r) for r in rows)
    for r in rows:
        r.extend(" " * (width - len(r)))
    if not m.get("floors"):
        m["floors"] = [{"x0": 0, "width": width, "height_ft": 0, "id": pid}]
    stairs = m.setdefault("stairs", [])
    placed = {}   # deck id -> (its x0 minus its floor's, the squares' z offset)
    for d in DECKS[pid]:
        ox, oz, base_ft, below = _floor_entry(loc, d["on"])
        fx0, fw = below["x0"], below["width"]
        x0 = width + 1
        for r in rows:
            r.extend(" " * (fw + 1))
        width = x0 + fw
        shift = x0 - fx0   # a square of the floor below to the same square of the deck
        cells = {(ox + x, oz + z) for x, z in d["cells"]}   # (in the place's map)
        if d["mode"] == "lift":
            cells = {c for c in cells if rows[c[1]][c[0]] in DIGITS}   # (only the raised squares go up: the gaps stay floor)
        steps = d["height_ft"] // 5
        for (x, z) in sorted(cells):
            ch = rows[z][x]
            if d["mode"] == "lift":
                if ch in DIGITS:
                    left = int(ch) - steps
                    rows[z][x + shift] = str(left) if left > 0 else "."
                else:
                    rows[z][x + shift] = ch
                rows[z][x] = d.get("under", ".")
            else:
                rows[z][x + shift] = "."
                if "under" in d:
                    rows[z][x] = d["under"]
        if d["mode"] == "lift":
            for k in LISTS:
                if k in loc:
                    loc[k] = [_shift_on(e, cells, shift) for e in loc[k]]
            for e in loc.get("encounters", []):
                for key in ("monsters", "foes", "allies"):
                    if key in e:
                        e[key] = [_shift_on(f, cells, shift) for f in e[key]]
            for a in loc.get("areas", []):
                if a["id"] in d.get("areas", []):
                    for key in ("rect", "cells"):
                        if key in a:
                            a[key] = [[c[0] + shift, c[1]] for c in a[key]]
        entry = {"x0": x0, "width": fw, "height_ft": base_ft + d["height_ft"], "id": d["id"], "kind": "deck"}
        if "rail_ft" in d:
            entry["rail_ft"] = d["rail_ft"]   # (a balustrade or parapet along its open edge: Half Cover over it)
        m["floors"].append(entry)
        placed[d["id"]] = (shift, ox, oz)
        for a, b, kind in d["stairs"]:
            st = {"from": [ox + a[0], oz + a[1]], "to": [ox + b[0] + shift, oz + b[1]]}
            st["kind"] = kind   # (always named: a deck's stair has no exits to be drawn from)
            stairs.append(st)
        for other, a, b, kind in d.get("deck_stairs", []):
            s0, _, _ = placed[other]
            st = {"from": [ox + a[0] + s0, oz + a[1]], "to": [ox + b[0] + shift, oz + b[1]]}
            st["kind"] = kind   # (always named: a deck's stair has no exits to be drawn from)
            stairs.append(st)
    m["rows"] = ["".join(r) for r in rows]
    if m.get("elevation"):
        m["elevation"] = [e + "0" * (width - len(e)) if len(e) < width else e for e in m["elevation"]]
    return loc


def write(pid):
    loc = lay(pid)
    (LOC / (pid + ".json")).write_text(json.dumps(loc, indent=2, ensure_ascii=False) + "\n")
    print("wrote data/locations/%s.json" % pid)


def main():
    if "--all" in sys.argv:
        for pid in DECKS:
            write(pid)
        return
    pid = sys.argv[1]
    if "--check" in sys.argv:
        loc = lay(pid)
        print(loc["map"]["floors"])
        print(loc["map"]["stairs"])
        for z, r in enumerate(loc["map"]["rows"]):
            print("%2d %s" % (z, r))
        return
    write(pid)


if __name__ == "__main__":
    main()
