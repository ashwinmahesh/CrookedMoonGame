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

A building with a cellar keeps the id of its ground floor as the place's id (the exits into it, the flags, quests, music, moods
and vistas that name it keep working), and its floors are listed lowest first, the cellar at 0 ft and the ground floor one storey
over it (so no floor lies under the ground, which the engine's floors do not take). The ground floor's spawns keep their names;
every other floor's is prefixed with its short name (cellar_from_stair). The floors are read as they stood at the commit named
in `from` (never from the working tree: the merged file takes the ground floor's own path).

    python3 tools/content/merge_floors.py crooked_house             # writes data/locations/crooked_house.json
    python3 tools/content/merge_floors.py crooked_house --check     # prints the layout, writes nothing
    python3 tools/content/merge_floors.py fw_windmill --solve       # the (dx, dz) each floor needs so its stairs meet
    python3 tools/content/merge_floors.py --all                     # every building in the table
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
# `ground` is the floor whose id the place keeps and whose spawns keep their names (the first by default). `ways_only`: exits that
# stay a way within the place with no stair joining their squares. `cover`: the ground floor is built over its cellar (the floor
# below it): wall squares are laid where the cellar's squares lie beyond the ground floor's own, so no sunken room shows beside the
# building. `edits`: (floor id, "spawn" or "exit", name, [x, z]): a spawn or an exit moved on its own floor's map, the one
# change the merge makes to a floor's squares.
FROM = "0605fb0e"   # the commit the later buildings were merged from (main before multifloor-buildings)
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
    # The buildings with a cellar or an upper floor (multifloor-buildings, 2026-11-02): the cellar at the bottom, the ground
    # floor one storey over it, and each floor's (dx, dz) from `--solve` so its stairs meet.
    "fw_windmill": {
        "ground": "fw_windmill",
        "cover": True,
        "floors": [("fw_windmill_cellar", "cellar", 0, 0), ("fw_windmill", "ground", 4, 0)],
    },
    "wickermoor_green_queen_inn": {
        "ground": "wickermoor_green_queen_inn",
        "cover": True,
        "floors": [("wickermoor_inn_cellar", "cellar", 0, 0), ("wickermoor_green_queen_inn", "ground", 2, 6),
                   ("wickermoor_green_queen_inn_upper", "upper", 27, 1)],
    },
    "dg_briar": {
        "ground": "dg_briar",
        "cover": True,
        "floors": [("dg_briar_cellar", "cellar", 0, 0), ("dg_briar", "ground", 3, 5), ("dg_briar_upper", "upper", 28, 11)],
    },
    "wickermoor_barber_shop": {
        "ground": "wickermoor_barber_shop",
        "cover": True,
        "floors": [("wickermoor_barber_cellar", "cellar", 6, 0), ("wickermoor_barber_shop", "ground", 0, 5)],
    },
    "wickermoor_funeral_home": {
        "ground": "wickermoor_funeral_home",
        "cover": True,
        "floors": [("wickermoor_funeral_basement", "basement", 9, 0), ("wickermoor_funeral_home", "ground", 0, 9)],
    },
    "wickermoor_trading_post": {
        "ground": "wickermoor_trading_post",
        "cover": True,
        "floors": [("wickermoor_trading_cellar", "cellar", 11, 0), ("wickermoor_trading_post", "ground", 0, 11)],
    },
    # The monastery has two spiral stairs and its upper floor lies where the east one meets exactly (it sits over the west and middle
    # of the ground floor). The west stair's old landings were 23 squares apart, so it is moved to meet: on the ground floor from the
    # top of the corridor down it to the same corridor, ten squares south (19, 22), and on the upper floor its landing and the way
    # back down from the hall's far west end to the hall's north edge over it (22, 29) and (22, 30). Nothing else on either floor
    # moves; only what stood on those squares was the stairs themselves.
    "mon_ground": {
        "ground": "mon_ground",
        "floors": [("mon_ground", "ground", 3, 7), ("mon_upper", "upper", 0, 0)],
        "edits": [("mon_ground", "spawn", "from_upstairs_a", [19, 22]), ("mon_ground", "exit", "stairs_up_a", [19, 22]),
                  ("mon_upper", "spawn", "from_down_a", [22, 29]), ("mon_upper", "exit", "down_a", [22, 30])],
    },
    # The bell tower is a tower of its own (the book gives it its own map, reached through the Bell Tower Gate), two floors.
    "mon_bell_tower": {
        "ground": "mon_bell_tower",
        "floors": [("mon_bell_tower", "ground", 0, 12), ("mon_belfry", "belfry", 14, 0)],
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


def floor_ids():
    """The id of every floor place of every building in the table: each is one place now, so a tool that builds places writes none of
    them (heirlooms_kept.kept)."""
    return {pid for spec in BUILDINGS.values() for pid, *_ in spec["floors"]}


def is_merged_path(rel):
    """Whether `rel` (a path a tool is about to write) is the file of a floor place of a merged building."""
    parts = rel.replace("\\", "/").split("/")
    return len(parts) == 3 and parts[0] == "data" and parts[1] == "locations" and parts[2][:-5] in floor_ids()


def _floor_place(pid, rev):
    """A floor's place file as git had it at `rev`: the merged place takes the ground floor's own path, so the working tree's
    file is never the floor (and the other floors' files are removed by the merge)."""
    return json.loads(subprocess.run(["git", "show", "%s:data/locations/%s.json" % (rev, pid)], cwd=ROOT, check=True,
                                     capture_output=True, text=True).stdout)


def _is_cell(v):
    return isinstance(v, list) and len(v) == 2 and all(isinstance(x, int) for x in v)


def _floors_of(spec):
    rev = spec.get("from", FROM)
    floors = [(pid, short, dx, dz, _floor_place(pid, rev)) for pid, short, dx, dz in spec["floors"]]
    for pid, kind, name, cell in spec.get("edits", []):
        loc = next(f[4] for f in floors if f[0] == pid)
        if kind == "spawn":
            loc["spawns"][name] = list(cell)
        elif kind == "exit":
            next(e for e in loc["exits"] if e["id"] == name)["cell"] = list(cell)
        else:
            raise ValueError(kind)
    return floors


def _json_at(rev, path):
    return json.loads(subprocess.run(["git", "show", "%s:%s" % (rev, path)], cwd=ROOT, check=True, capture_output=True, text=True).stdout)


def floor_settings(spec, floors, base):
    """What each floor other than the ground floor settled for itself before its building was one place, where it differs from the
    ground floor's (the engine's PlaceFloors): its map's theme and outdoors, its rest, and from the game's own files as they were
    at the commit the floors are read from, its atmosphere mood, ambient bed and footsteps. A floor that doesn't differ says
    nothing and takes the place's."""
    rev = spec.get("from", FROM)
    audio = _json_at(rev, "art/audio.json")
    moods = _json_at(rev, "art/atmosphere/moods.json")

    def of(floor):
        pid, loc = floor[0], floor[4]
        m = loc["map"]
        return {"mood": moods.get("places", {}).get(pid), "bed": audio.get("place_beds", {}).get(pid),
                "steps": audio.get("steps", {}).get("places", {}).get(pid), "rest": loc.get("rest"),
                "rest_text": loc.get("rest_text"), "theme": m.get("theme"), "outdoors": bool(m.get("outdoors", False))}
    ground = of(floors[base])
    out = []
    for i, f in enumerate(floors):
        mine = of(f)
        settings = {}
        if i != base:
            for key in ("mood", "bed", "steps", "rest", "theme", "outdoors"):
                if mine[key] is not None and mine[key] != ground[key]:
                    settings[key] = mine[key]
            if settings.get("rest") == "no" and mine["rest_text"] != ground["rest_text"] and mine["rest_text"]:
                settings["rest_text"] = mine["rest_text"]
        out.append(settings)
    return out


def _stair_ends(floors, i, e):
    """Where the way up `e` of floor `i` comes out (on its floor `j`) and where the way back down comes out (on floor `i`):
    the two squares one stair joins, each in its own floor's own squares. With two stairs between a pair of floors the way
    back is the one whose square is nearest where this way comes out."""
    ids = [f[0] for f in floors]
    j = ids.index(e["to"])
    there = floors[j][4]["spawns"][e.get("spawn", "default")]
    backs = [b for b in floors[j][4].get("exits", []) if b["to"] == floors[i][0]]
    back = min(backs, key=lambda b: abs(b["cell"][0] - there[0]) + abs(b["cell"][1] - there[1])) if backs else {}
    here = floors[i][4]["spawns"][back.get("spawn", "default")]
    return j, here, there, back


def solve(bid):
    """Each floor's (dx, dz) from the ground floor's, so every stair's two ends stand over each other; the cost of each stair
    under the offsets found, and the offsets moved so none is negative (the building's own origin)."""
    spec = BUILDINGS[bid]
    floors = _floors_of(spec)
    ids = [f[0] for f in floors]
    base = ids.index(spec["ground"]) if "ground" in spec else 0
    links = []   # (i, j, here, there)
    for i, f in enumerate(floors):
        for e in f[4].get("exits", []):
            if e["to"] in ids and ids.index(e["to"]) > i and e["id"] not in spec.get("ways_only", []):
                j, here, there, _ = _stair_ends(floors, i, e)
                links.append((i, j, here, there))
    off = {base: (0, 0)}
    todo = True
    while todo:
        todo = False
        for i, j, here, there in links:
            # off[j] + there == off[i] + here
            if i in off and j not in off:
                off[j] = (off[i][0] + here[0] - there[0], off[i][1] + here[1] - there[1])
                todo = True
            elif j in off and i not in off:
                off[i] = (off[j][0] + there[0] - here[0], off[j][1] + there[1] - here[1])
                todo = True
    mx = min(o[0] for o in off.values())
    mz = min(o[1] for o in off.values())
    out = {k: (v[0] - mx, v[1] - mz) for k, v in off.items()}
    print("%s: floors from the ground up, normalised so none is negative" % bid)
    for k in sorted(out):
        print("   (%r, %r, %d, %d)" % (floors[k][0], floors[k][1], out[k][0], out[k][1]))
    for i, j, here, there in links:
        a = (out[i][0] + here[0], out[i][1] + here[1])
        b = (out[j][0] + there[0], out[j][1] + there[1])
        print("   stair %s %s -> %s %s: apart by (%d, %d)" % (ids[i], here, ids[j], there, b[0] - a[0], b[1] - a[1]))
    return out


def merge(bid):
    spec = BUILDINGS[bid]
    floors = _floors_of(spec)
    ids = [f[0] for f in floors]
    base = ids.index(spec["ground"]) if "ground" in spec else 0
    depth = max(len(f[4]["map"]["rows"]) + f[3] for f in floors)
    # The squares (in the building's own columns and rows) of the cellar the ground floor is built over, when it is.
    cover = set()
    if spec.get("cover") and base > 0:
        _, _, ldx, ldz, lloc = floors[base - 1]
        for z, r in enumerate(lloc["map"]["rows"]):
            for x, ch in enumerate(r):
                if ch != " ":
                    cover.add((ldx + x, ldz + z))
    blocks = []
    x0 = 0
    for i, (pid, short, dx, dz, loc) in enumerate(floors):
        w = max(len(r) for r in loc["map"]["rows"]) + dx
        if i == base and cover:
            w = max(w, max(bx for bx, _ in cover) + 1)
        blocks.append({"x0": x0, "width": w, "dx": dx, "dz": dz})
        x0 += w + 1
    width = x0 - 1
    rows = [[" "] * width for _ in range(depth)]
    for b, (pid, short, dx, dz, loc) in zip(blocks, floors):
        for z, r in enumerate(loc["map"]["rows"]):
            for x, ch in enumerate(r):
                rows[z + dz][b["x0"] + dx + x] = ch
    for bx, bz in cover:
        # Wall where the cellar's squares lie past the ground floor's own: its walls stand over the whole cellar.
        own_rows = floors[base][4]["map"]["rows"]
        ox, oz = bx - floors[base][2], bz - floors[base][3]
        own = own_rows[oz][ox] if 0 <= oz < len(own_rows) and 0 <= ox < len(own_rows[oz]) else " "
        if own == " ":
            rows[bz][blocks[base]["x0"] + bx] = "#"
    first = floors[base][4]
    out = {k: copy.deepcopy(v) for k, v in first.items() if k not in LISTS + ["exits", "spawns", "map"]}
    out["id"] = bid
    out["name"] = spec.get("name", first["name"])
    out["map"] = {k: v for k, v in first["map"].items() if k not in ("rows", "elevation")}
    out["map"]["rows"] = ["".join(r) for r in rows]
    settings = floor_settings(spec, floors, base)
    out["map"]["floors"] = [{"x0": b["x0"], "width": b["width"], "height_ft": i * STOREY_FT, "id": f[0],
                             "offset": [b["x0"] + b["dx"], b["dz"]], **settings[i]} for i, (b, f) in enumerate(zip(blocks, floors))]
    spawns = {}
    stairs = []
    exits = []
    seen_ids = {k: set() for k in LISTS}
    for k in LISTS:
        out[k] = []
    order = [base] + [i for i in range(len(floors)) if i != base]   # (the ground floor's ids are the ones kept as they are)
    for i in order:
        b = blocks[i]
        pid, short, dx, dz, loc = floors[i]
        mx, mz = b["x0"] + dx, dz
        prefix = "" if i == base else short + "_"
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
            if e["to"] in ids and ids.index(e["to"]) > i and e["id"] not in spec.get("ways_only", []):
                # The stair runs between where each floor's way to the other sets the party down: the square on this floor
                # the way back down arrives at, and the square on the next floor this way up arrives at.
                j, here, there, back = _stair_ends(floors, i, e)
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
                way["spawn"] = ("" if j == base else floors[j][1] + "_") + e.get("spawn", "default")
                if i != base and sum(1 for f in floors for x in f[4].get("exits", []) if x["id"] == e["id"]) > 1:
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


def write(bid):
    merged, blocks = merge(bid)
    (LOC / (bid + ".json")).write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n")
    print("wrote data/locations/%s.json" % bid)
    for pid, *_ in BUILDINGS[bid]["floors"]:
        gone = LOC / (pid + ".json")
        if pid != bid and gone.exists():
            gone.unlink()
            print("removed data/locations/%s.json" % pid)


def main():
    if "--all" in sys.argv:
        for bid in BUILDINGS:
            write(bid)
        return
    bid = sys.argv[1]
    if "--solve" in sys.argv:
        solve(bid)
        return
    merged, blocks = merge(bid)
    if "--check" in sys.argv:
        print("%d x %d, floors %s" % (len(merged["map"]["rows"][0]), len(merged["map"]["rows"]), blocks))
        print("stairs", merged["map"]["stairs"])
        print("spawns", merged["spawns"])
        for r in merged["map"]["rows"]:
            print(r)
        return
    write(bid)


if __name__ == "__main__":
    main()
