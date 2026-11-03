#!/usr/bin/env python3
"""Decks laid over a place (the full 3D grid build, lane B1, 2026-11-02): a hay loft, a gallery, a bridge, a scaffold, a
car roof. Each deck is a `map.floors` entry with kind "deck" (the engine's Decks and FloorCutaway): its own columns past the
map's, open air (void) everywhere but its squares, which stand over the building's squares below them.

A place's table entry lists its decks by height (squares in the building's own coordinates, as rectangles), the links that
reach them (`stairs` with a kind: ladder, ramp or stair) and any edits to the squares below (a stall partition lowered under
a loft). New columns go to the right of the map, so no walkable square, spawn or exit the place already has moves. Running it
again rebuilds the place's decks from the table: the deck floors it laid before (and their columns) are taken off first.

    python3 tools/content/add_decks.py wickermoor_stable          # writes data/locations/wickermoor_stable.json
    python3 tools/content/add_decks.py wickermoor_stable --check  # prints the new map, writes nothing
    python3 tools/content/add_decks.py --all
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOC = ROOT / "data" / "locations"

# place -> {decks: [{height_ft, rects: [[x1, z1, x2, z2], ...] or rows, kind?, rail_ft? (3), posts?, surface?, id?}],
#           links: [{from: [x, z] or [x, z, floor index], to: [x, z, deck index], kind}],
#           edits: [[x, z, char], ...] on the ground floor's own squares}
PLACES = {
    # The footbridge over the Silverbell (the Narrator's "runs dark and quiet under a footbridge"): the three squares where the
    # path crossed the channel between the two pools are river now, and a plank bridge carries the path over them, level with
    # the north bank and ramped down to the south one. The way out south and the arrival from it stand where they did.
    "wickermoor_village": {
        "edits": [[29, 46, "w"], [30, 46, "w"], [31, 46, "w"]],
        "elevation_edits": [[29, 46, "0"], [30, 46, "0"], [31, 46, "0"]],
        "decks": [{"height_ft": 5, "rects": [[29, 46, 31, 46]], "outdoors": True}],
        "links": [{"from": [x, 45], "to": [x, 46, 0], "kind": "ramp"} for x in (29, 30, 31)]
                 + [{"from": [x, 47], "to": [x, 46, 0], "kind": "ramp"} for x in (29, 30, 31)],
    },
    # The river road's bridge over the mill stream: where the road crossed between the stream's bends is water now, under a
    # humped plank bridge a step over the banks, ramped up from each.
    "dawns_gate": {
        "edits": [[x, z, "w"] for z in (28, 29) for x in (50, 51, 52)],
        "decks": [{"height_ft": 20, "rects": [[50, 28, 52, 29]], "outdoors": True}],
        "links": [{"from": [49, z], "to": [50, z, 0], "kind": "ramp"} for z in (28, 29)]
                 + [{"from": [53, z], "to": [52, z, 0], "kind": "ramp"} for z in (28, 29)],
    },
    # A gallery over the front room's north shelves, reached by the rolling ladder beside them (bookstore_ladder).
    "wickermoor_bookstore": {
        "decks": [{"height_ft": 10, "rects": [[1, 1, 12, 2]]}],
        "links": [{"from": [10, 3], "to": [10, 2, 0], "kind": "ladder"}],
    },
    # A walkway of perches round the inside of the round stone room, up a ladder on its west side.
    "wickermoor_dovecote": {
        "decks": [{"height_ft": 10, "rects": [[3, 2, 8, 2], [3, 9, 8, 9], [2, 3, 2, 8], [9, 3, 9, 8]]}],
        "links": [{"from": [3, 7], "to": [2, 7, 0], "kind": "ladder"}],
    },
    # The stone floor over the mill's east room, where the millstones turn, up a steep ladder from beside the gears.
    "fw_windmill": {
        "decks": [{"kind": "storey", "height_ft": 30, "id": "fw_windmill_stones", "rows":
            [" " * 18 + "################"] + [" " * 18 + "#..............#"] * 12 + [" " * 18 + "################"]}],
        "links": [{"from": [30, 2, 1], "to": [30, 1, 0], "kind": "ladder"}],
    },
    # The hay loft over the three stalls, its landing over the tack rail where the ladder stands (stable_hay). The stall
    # partitions under it are low boards now, so the loft isn't run through by walls.
    "wickermoor_stable": {
        "decks": [{"height_ft": 10, "rects": [[1, 1, 20, 7], [15, 8, 20, 10]]}],
        "links": [{"from": [17, 11], "to": [17, 10, 0], "kind": "ladder"}],
        "edits": [[7, z, "="] for z in range(1, 9) if z != 4] + [[14, z, "="] for z in range(1, 9) if z != 4],
    },
    # Act III. The Silent Church (R21): the old chapel's choir loft over the back of the nave, ten feet up behind a balustrade, its
    # stair up the west wall; the doorway and the arrival under it stay clear (the loft stops a row short of the door wall).
    "fd_silent_church": {
        "decks": [{"height_ft": 10, "rects": [[1, 15, 12, 17]], "id": "fd_silent_church_loft"}],
        "links": [{"from": [1, 14], "to": [1, 15, 0], "kind": "stair"}],
    },
    # The Crooked Bookshelf (R22): the shelf above, ten feet over the party's shelf along the books' spines, with no rail at its
    # open edge; the party climbs to it up the stack of books.
    "nm_bookshelf": {
        "decks": [{"height_ft": 10, "rects": [[1, 1, 24, 3]], "rail_ft": 0, "id": "nm_bookshelf_upper"}],
        "links": [{"from": [8, 4], "to": [8, 3, 0], "kind": "ladder"}],
    },
}


# The Ghostlight Express's cars (Ashwin, 2026-11-02 22:41Z: "Sure let's do it"; ours, not the book's): each car's whole roof is a
# storey 15 ft up and open to the sky, up a ladder from a free square of its aisle; it is out of sight while the party is in the car.
CAR_LADDERS = {"g1_passenger": (18, 2), "g2_sleeper": (16, 2), "g3_lounge": (18, 2), "g4_dining": (2, 4), "g5_mail": (18, 2),
               "g6_baggage": (18, 2), "g7_circus": (16, 2)}
for _car, (_x, _z) in CAR_LADDERS.items():
    PLACES["ghostlight_" + _car] = {
        "decks": [{"kind": "storey", "height_ft": 15, "outdoors": True, "id": "ghostlight_%s_roof" % _car, "rows": ["." * 20] * 7}],
        "links": [{"from": [_x, _z], "to": [_x, _z - 1, 0], "kind": "ladder"}],
    }


def strip_decks(loc):
    """Takes off the deck floors (and their columns) a run laid before; returns the map as it was without them."""
    m = loc["map"]
    floors = m.get("floors", [])
    decks = [f for f in floors if "kind" in f]   # (every floor this tool lays says its kind; merged storeys don't)
    if not decks:
        return
    cut = min(f["x0"] for f in decks) - 1   # the void column before the first deck
    m["rows"] = [r[:cut] for r in m["rows"]]
    if "elevation" in m:
        m["elevation"] = [r[:cut] for r in m["elevation"]]
    m["floors"] = [f for f in floors if "kind" not in f]
    m["stairs"] = [s for s in m.get("stairs", []) if s["from"][0] < cut and s["to"][0] < cut]
    if len(m["floors"]) <= 1 and all(f.get("x0", 0) == 0 for f in m["floors"]) and not m["stairs"]:
        m.pop("floors", None)
        m.pop("stairs", None)


def add_decks(loc_id, spec):
    path = LOC / f"{loc_id}.json"
    loc = json.loads(path.read_text())
    strip_decks(loc)
    m = loc["map"]
    rows = [list(r) for r in m["rows"]]
    for x, z, ch in spec.get("edits", []):
        rows[z][x] = ch
    if "elevation_edits" in spec:
        elev = [list(r) for r in m["elevation"]]
        for x, z, ch in spec["elevation_edits"]:
            elev[z][x] = ch
        m["elevation"] = ["".join(r) for r in elev]
    width = max(len(r) for r in rows)
    rows = [r + [" "] * (width - len(r)) for r in rows]
    depth = len(rows)
    floors = m.get("floors") or [{"x0": 0, "width": width, "height_ft": 0}]
    ground = floors[0]
    deck_floors = []
    x0 = width + 1
    for d in spec["decks"]:
        if "rows" in d:   # a storey drawn out whole (its walls and floor), in the building's own coordinates
            w = max(len(r) for r in d["rows"])
            cols = [list(r.ljust(w)) for r in d["rows"]] + [[" "] * w for _ in range(depth - len(d["rows"]))]
        else:
            w = max(r[2] for r in d["rects"]) + 1
            cols = [[" "] * w for _ in range(depth)]
            for x1, z1, x2, z2 in d["rects"]:
                for z in range(z1, z2 + 1):
                    for x in range(x1, x2 + 1):
                        cols[z][x] = "."
        for z in range(depth):
            rows[z] += [" "] + cols[z] if len(rows[z]) < x0 else cols[z]
        entry = {"x0": x0, "width": w, "height_ft": d["height_ft"], "kind": d.get("kind", "deck")}
        if entry["kind"] == "deck":
            entry["rail_ft"] = d.get("rail_ft", 3)   # a 3 ft rail round a deck's open edges: drawn, and Half Cover over it
        for k in ("id", "posts", "surface", "outdoors", "theme", "mood", "bed", "steps"):
            if k in d:
                entry[k] = d[k]
        deck_floors.append(entry)
        x0 += w + 1
    m["rows"] = ["".join(r) for r in rows]
    if "elevation" in m:
        m["elevation"] = [e + "." * (len(m["rows"][z]) - len(e)) for z, e in enumerate(m["elevation"])]
    # Floors lowest first (the engine picks the highest floor at or under a point); the ground floor stays first.
    m["floors"] = [floors[0]] + sorted(floors[1:] + deck_floors, key=lambda f: f["height_ft"])
    stairs = m.get("stairs", [])
    for link in spec.get("links", []):
        fr = link["from"]
        src = floors[fr[2]] if len(fr) > 2 else ground
        to = link["to"]
        dst = deck_floors[to[2]]
        s = {"from": [src["x0"] + fr[0], fr[1]], "to": [dst["x0"] + to[0], to[1]], "kind": link["kind"]}
        stairs.append(s)
    m["stairs"] = stairs
    return loc


def main(argv):
    check = "--check" in argv
    ids = list(PLACES) if "--all" in argv else [a for a in argv if not a.startswith("--")]
    for loc_id in ids:
        loc = add_decks(loc_id, PLACES[loc_id])
        if check:
            print(loc_id)
            print("\n".join(loc["map"]["rows"]))
            print(json.dumps({k: v for k, v in loc["map"].items() if k in ("floors", "stairs")}, indent=1))
        else:
            (LOC / f"{loc_id}.json").write_text(json.dumps(loc, indent=2, ensure_ascii=False) + "\n")
            print("wrote", loc_id)


if __name__ == "__main__":
    main(sys.argv[1:])
