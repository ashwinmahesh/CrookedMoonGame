#!/usr/bin/env python3
"""Dresses the Founder's Round, Wickermoor Village's square: the Founder's statue raised on a low mound ringed by lanterns
and benches (the square's focal point, seen from the moor road down the high street), the Oak of Many Faces on its own
knoll of roots at the far end, a market corner of stalls, crates and sacks, a well corner, the inn's barrels, and lanterns at
the street's two mouths. Run from the repo root (again after any change to the square); it replaces what it wrote before:
    python3 tools/content/wickermoor_square.py

Every piece is decor and claims no square (props never block), stands clear of every person's spot, spawn and exit, and the
mounds only raise the ground 5 ft (a gentle slope), so no walk, spawn or story trigger moves."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOC = ROOT / "data" / "locations" / "wickermoor_village.json"
PREFIX = "wm_sq_"

# (id, cell, model, label, extra)
PIECES = [
    # The statue's ring: lanterns at four corners, benches facing it from the square.
    ("lamp_nw", (45, 29), "lantern_post", "A lantern on an iron post, guttering", {}),
    ("lamp_ne", (51, 29), "lantern_post", "A lantern on an iron post, guttering", {}),
    ("lamp_sw", (45, 33), "lantern_post", "A lantern on an iron post, guttering", {}),
    ("lamp_se", (51, 33), "lantern_post", "A lantern on an iron post, guttering", {}),
    ("bench_w", (46, 35), "stone_bench", "A stone bench worn smooth", {"facing": "north"}),
    ("bench_e", (51, 35), "stone_bench", "A stone bench worn smooth", {"facing": "north"}),
    ("offering", (47, 33), "offering_pile", "Dried flowers and wicker charms at the statue's feet", {}),
    # The market corner, north-east.
    ("stall_a", (55, 29), "market_stall", "A market stall under a patched awning", {"facing": "south"}),
    ("stall_b", (59, 30), "market_stall", "A market stall, its shutters half down", {"facing": "west"}),
    ("crates", (60, 28), "crate_stack", "Crates stacked head high", {}),
    ("sacks", (57, 28), "sack_pile", "Sacks of meal", {}),
    ("barrel_m", (60, 32), "barrel", "A rain barrel", {}),
    ("hay_m", (54, 31), "hay_bale", "A bale of hay", {}),
    ("stocks", (54, 33), "stocks", "The village stocks, empty for now", {"facing": "west"}),
    # The well corner, north-west.
    ("trough", (38, 33), "trough", "A horse trough, skinned with leaves", {}),
    ("bucket", (37, 30), "bucket_brush", "A bucket left by the well", {}),
    ("woodpile", (39, 28), "woodpile", "Split wood stacked against the cold", {}),
    # The inn's side, west.
    ("barrel_a", (38, 43), "barrel", "An ale barrel", {}),
    ("barrel_b", (38, 47), "barrel", "An ale barrel", {}),
    ("crate_i", (39, 48), "crate", "A crate of empties", {}),
    ("handcart", (40, 46), "handcart", "A handcart, tipped on its legs", {}),
    # By the oak, south.
    ("hay_o", (42, 50), "hay_bale", "A bale of hay", {}),
    ("lamp_o", (53, 49), "lantern_stand", "A lantern hung on a crook", {}),
    ("wicker", (55, 47), "wicker_sun", "A wicker sun on a pole, the village's old charm", {}),
    ("ribbons", (41, 44), "ribbon_tree", "A sapling tied all over with ribbons", {}),
    # The high street's mouths.
    ("lamp_n1", (46, 26), "lantern_post", "A lantern on an iron post", {}),
    ("lamp_n2", (51, 26), "lantern_post", "A lantern on an iron post", {}),
    ("lamp_s1", (45, 52), "lantern_post", "A lantern on an iron post", {}),
    ("lamp_s2", (51, 52), "lantern_post", "A lantern on an iron post", {}),
    # Lamps down the high street, so the walk in from the moor and out to the footbridge is lit.
    ("lamp_st1", (45, 6), "lantern_post", "A lantern on an iron post", {}),
    ("lamp_st2", (51, 11), "lantern_post", "A lantern on an iron post", {}),
    ("lamp_st3", (50, 16), "lantern_post", "A lantern on an iron post", {}),
    ("lamp_st4", (51, 22), "lantern_post", "A lantern on an iron post", {}),
    ("lamp_st5", (46, 59), "lantern_post", "A lantern on an iron post", {}),
    ("lamp_st6", (46, 70), "lantern_post", "A lantern on an iron post", {}),
]

# The lamps that shed light (lights `visual`: painted only, so no fight's light changes), a pool on the square and every
# few houses down the street.
LIT = ["lamp_nw", "lamp_se", "lamp_n1", "lamp_s2", "lamp_o", "lamp_st1", "lamp_st2", "lamp_st3", "lamp_st4", "lamp_st5", "lamp_st6"]
# The Founder's statue, drawn bigger than life so it reads across the square (its square and data stay as they were).
STATUE = ("wm_statue", 1.5)
# Mounds: (middle, radius) raised 5 ft over the Round's ground.
MOUNDS = [((48, 31), 2.3), ((48, 47), 2.1)]


def main():
    loc = json.loads(LOC.read_text())
    rows = loc["map"]["rows"]
    loc["props"] = [p for p in loc["props"] if not str(p["id"]).startswith(PREFIX)]
    taken = {}
    for p in loc["props"] + loc.get("containers", []):
        taken[tuple(p["cell"])] = p["id"]
    for n in loc.get("npcs", []):
        taken[tuple(n["cell"])] = n["npc"]
    for e in loc.get("exits", []):
        taken[tuple(e["cell"])] = e["id"]
    for k, v in loc.get("spawns", {}).items():
        taken[tuple(v)] = k
    for enc in loc.get("encounters", []):
        for m in enc.get("monsters", []):
            if "cell" in m:
                taken[tuple(m["cell"])] = enc["id"]
    for pid, cell, model, label, extra in PIECES:
        if cell in taken:
            raise SystemExit("%s%s at %s would stand on %s" % (PREFIX, pid, cell, taken[cell]))
        if rows[cell[1]][cell[0]] != ".":
            raise SystemExit("%s%s at %s is not open ground" % (PREFIX, pid, cell))
        prop = {"id": PREFIX + pid, "cell": list(cell), "kind": "decor", "label": label, "model": model}
        prop.update(extra)
        loc["props"].append(prop)
        taken[cell] = PREFIX + pid
    lamp_cells = [list(cell) for pid, cell, *_ in PIECES if pid in LIT]
    every_lamp = [list(cell) for pid, cell, model, *_ in PIECES if "lantern" in model]
    loc["lights"] = [li for li in loc.get("lights", []) if li["cell"] not in every_lamp]
    for cell in lamp_cells:
        loc["lights"].append({"cell": cell, "kind": "lamp", "bright_ft": 10, "dim_ft": 30, "visual": True})
    for p in loc["props"]:
        if p["id"] == STATUE[0]:
            p["scale"] = STATUE[1]
    elev = [list(r) for r in loc["map"]["elevation"]]
    base = "3"
    for (mx, my), r in MOUNDS:
        for y in range(my - 3, my + 4):
            for x in range(mx - 3, mx + 4):
                if ((x - mx) ** 2 + (y - my) ** 2) ** 0.5 <= r and rows[y][x] in ".=" and elev[y][x] in (base, "4"):
                    elev[y][x] = "4"
    loc["map"]["elevation"] = ["".join(r) for r in elev]
    LOC.write_text(json.dumps(loc, indent=2, ensure_ascii=False) + "\n")
    print("wickermoor square: %d pieces, %d mounds" % (len(PIECES), len(MOUNDS)))


if __name__ == "__main__":
    main()
