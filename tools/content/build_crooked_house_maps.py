#!/usr/bin/env /usr/bin/python3
"""ONE-SHOT (R12, the maps worker): writes the four floors of the Crooked House and dresses the Druskenvald estate. NEVER RERUN
after a hand edit: the five location files are hand-edited from here on (the wiring step adds encounters, npcs and calls).

The four floors are drawn here from the book's four plans (looked at for layout only): rooms as rectangles and discs on a wall-filled
canvas, a gap or a door between every room and its hall, props as a shell with the ids the package contract names (R12 package, section 3).
The estate's land comes from the sketch tool (make sketch; the pictures are painted by `paint`), and `dress` lays the manor, its
porch, the gate and the dress of the grounds over those rows. Usage from the repo root (all with /usr/bin/python3, which has PIL):
    /usr/bin/python3 tools/content/build_crooked_house_maps.py floors            # first, second, third, attic
    /usr/bin/python3 tools/content/build_crooked_house_maps.py paint docs/plans/crooked_house
    make sketch HEIGHT=docs/plans/crooked_house/height.png LAYOUT=docs/plans/crooked_house/layout.png SIZE=40x36 TOP=35 LOC=data/locations/druskenvald_estate.json
    /usr/bin/python3 tools/content/build_crooked_house_maps.py dress             # props, doors, exits, areas over the sketched rows
    /usr/bin/python3 tools/content/build_crooked_house_maps.py preview captures/r12   # a picture of every map's rows and cells
"""
import json
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGION = "crooked_house"
CH = REGION + "/"
FLOOR = ".~1234_"          # what the data checks call open floor (spawns, doors, traps, people stand on it)
WALK = FLOOR + "="         # what is walked (low cover is stepped over)

REST_TEXT = ("The house won't let you sleep. The walls tick and breathe round you, and something small keeps scratching behind "
             "the plaster. A short breath, then.")


# ---- the canvas ------------------------------------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["#"] * w for _ in range(h)]

    def put(self, x, z, ch):
        self.g[z][x] = ch

    def get(self, x, z):
        return self.g[z][x] if 0 <= z < self.h and 0 <= x < self.w else " "

    def rect(self, x0, z0, x1, z1, ch="."):
        for z in range(z0, z1 + 1):
            for x in range(x0, x1 + 1):
                self.g[z][x] = ch

    def disc(self, cx, cz, r, ch="."):
        """Every square whose middle lies within r of (cx, cz) (a round room: the turrets)."""
        for z in range(self.h):
            for x in range(self.w):
                if (x + 0.5 - cx) ** 2 + (z + 0.5 - cz) ** 2 <= r * r:
                    self.g[z][x] = ch

    def finish(self):
        """Walls that touch no floor become void: the house stands in the dark, not in a block of stone."""
        out = []
        for z in range(self.h):
            row = ""
            for x in range(self.w):
                ch = self.g[z][x]
                if ch == "#":
                    near = False
                    for dz in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            if self.get(x + dx, z + dz) in WALK:
                                near = True
                    ch = "#" if near else " "
                row += ch
            out.append(row)
        return out


class Place:
    """One location file's worth of data, with checks on every cell it is given."""

    def __init__(self, pid, name, canvas, **meta):
        self.id, self.name, self.cv = pid, name, canvas
        self.meta = meta
        self.props, self.doors, self.exits, self.areas, self.lights, self.traps, self.containers = [], [], [], [], [], [], []
        self.spawns = {}
        self.used = {}      # cell -> what stands there (props and containers never share a square)

    # props -----------------------------------------------------------------------------------------------------------
    def prop(self, pid, x, z, kind="decor", label="", model="", low=False, span=None, **kw):
        assert self.cv.get(x, z) in WALK, f"{self.id}: prop {pid} at {x},{z} is not on floor ({self.cv.get(x, z)!r})"
        cells = [(x + i, z + j) for i in range((span or [1, 1])[0]) for j in range((span or [1, 1])[1])]
        for c in cells:
            assert self.cv.get(*c) in WALK, f"{self.id}: prop {pid} covers {c}, which is not floor"
            assert c not in self.used, f"{self.id}: prop {pid} shares {c} with {self.used[c]}"
            self.used[c] = pid
            if low:
                self.cv.put(c[0], c[1], "=")
        d = {"id": pid, "cell": [x, z], "kind": kind}
        if label:
            d["label"] = label
        if model:
            d["model"] = model
        if span:
            d["span"] = list(span)
        d.update(kw)
        self.props.append(d)

    def container(self, cid, x, z, label, model, **kw):
        assert self.cv.get(x, z) in WALK or self.cv.get(x, z) == "#", f"{self.id}: container {cid} at {x},{z}"
        assert (x, z) not in self.used, f"{self.id}: container {cid} shares {x},{z} with {self.used.get((x, z))}"
        self.used[(x, z)] = cid
        d = {"id": cid, "cell": [x, z], "label": label, "model": model}
        d.update(kw)
        self.containers.append(d)

    def door(self, did, x, z, label="", **kw):
        assert self.cv.get(x, z) in FLOOR, f"{self.id}: door {did} at {x},{z} must stand on open floor ({self.cv.get(x, z)!r})"
        d = {"id": did, "cell": [x, z]}
        if label:
            d["label"] = label
        d.update(kw)
        self.doors.append(d)

    def exit(self, eid, x, z, to, spawn, label, **kw):
        d = {"id": eid, "cell": [x, z], "to": to, "spawn": spawn, "label": label}
        d.update(kw)
        self.exits.append(d)

    def area(self, aid, name, x0, z0, x1, z1, light=None, **kw):
        d = {"id": aid, "name": name, "cells": [[x0, z0], [x1, z1]]}
        if light:
            d["light"] = light
        d.update(kw)
        self.areas.append(d)

    def light(self, x, z, kind="candle", bright=10, dim=20, color="candle", **kw):
        d = {"cell": [x, z], "kind": kind, "bright_ft": bright, "dim_ft": dim}
        if color:
            d["color"] = color
        d.update(kw)
        self.lights.append(d)

    def trap(self, tid, cells, **kw):
        for c in cells:
            assert self.cv.get(*c) in FLOOR, f"{self.id}: trap {tid} at {c}"
        d = {"id": tid, "cells": [list(c) for c in cells]}
        d.update(kw)
        self.traps.append(d)

    def spawn(self, name, x, z):
        assert self.cv.get(x, z) in FLOOR, f"{self.id}: spawn {name} at {x},{z} ({self.cv.get(x, z)!r})"
        self.spawns[name] = [x, z]

    # the file --------------------------------------------------------------------------------------------------------
    def data(self, rows, summary, text, light="dim", ceiling=None, extra_map=None):
        m = {"rows": rows}
        if ceiling:
            m["ceiling_ft"] = ceiling
        m.update(extra_map or {})
        m["theme"] = "manor"
        m["light"] = light
        m["outdoors"] = False
        d = {"id": self.id, "name": self.name, "region": REGION, "summary": summary, "text": text, "map": m,
             "areas": self.areas, "spawns": self.spawns, "exits": self.exits}
        if self.doors:
            d["doors"] = self.doors
        d["props"] = self.props
        if self.containers:
            d["containers"] = self.containers
        d["lights"] = self.lights
        if self.traps:
            d["traps"] = self.traps
        d["rest"] = "no"
        d["rest_text"] = REST_TEXT
        return d


def models():
    """Every model name a prop may use: the catalog's, the 3D models', the sprite props'."""
    names = set()
    cat = json.load(open(ROOT / "art/sprites/props/catalog.json"))
    names |= set(cat["models"])
    for rel in ("addons/dnd_core/art/models/manifest.json", "art/models/manifest.json"):
        p = ROOT / rel
        if p.exists():
            names |= set(json.load(open(p)).get("models", {}))
    for rel in ("addons/dnd_core/art/sprites/props/manifest.json", "art/sprites/props/manifest.json"):
        p = ROOT / rel
        if p.exists():
            names |= set(json.load(open(p)).get("props", {}))
    return names


MODELS = None


def check_models(pl):
    global MODELS
    if MODELS is None:
        MODELS = models()
    bad = [f"{p['id']}={p.get('model')}" for p in pl.props + pl.containers if p.get("model") and p["model"] not in MODELS]
    assert not bad, f"{pl.id}: unknown models {bad}"


def write(rel, obj):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def cond_pilgrim(name):
    return f"not flag.incitement_{name}"


# ---- the first floor: porch, foyer, parlor, gallery, music room, dining room, kitchen, conservatory -----------------------
def first_floor():
    W, H = 34, 41
    c = Canvas(W, H)
    c.rect(6, 2, 18, 12)                       # H8 conservatory
    for x, z in [(6, 2), (7, 2), (6, 3)]:      # its north-west corner is rounded off
        c.put(x, z, "#")
    c.rect(20, 5, 32, 12)                      # H7 kitchen (its south-west corner is the hall's north end)
    c.rect(20, 13, 21, 33)                     # the long hall, two squares wide, as the plan draws it
    c.rect(4, 14, 18, 21)                      # H3 parlor
    c.rect(23, 14, 32, 21)                     # H6 dining room
    c.rect(23, 23, 32, 30)                     # H5 music room
    c.rect(10, 23, 18, 33)                     # H2 foyer (ceiling 20 ft)
    c.disc(5.0, 28.5, 4.3)                     # H4 gallery, the turret's round base
    c.rect(4, 22, 5, 23)                       # the parlor's south-west corner opens into the gallery
    c.rect(1, 35, 32, 38, "_")                 # H1 porch (a raised deck, south side)
    c.rect(1, 39, 32, 39, ".")                 # the yard's first step: the trap squares
    pl = Place("crooked_house_first", "The Crooked House, First Floor", c)

    # doors and gaps (a door's square is floor in a wall line)
    c.put(19, 12, "."); c.put(19, 18, "."); c.put(22, 17, "."); c.put(22, 26, ".")
    c.put(19, 29, "."); c.put(19, 30, "."); c.put(9, 28, "."); c.put(14, 34, ".")
    pl.door("h8_door", 19, 12, "The conservatory doors")
    pl.door("h3_door", 19, 18, "The parlor door")
    pl.door("h6_door", 22, 17, "The dining room door")
    pl.door("h5_door", 22, 26, "The music room door")
    pl.door("h2_hall_door_north", 19, 29, "The foyer's inner door")
    pl.door("h2_hall_door_south", 19, 30, "The foyer's inner door")
    pl.door("h4_door", 9, 28, "The gallery door")
    pl.door("front_door", 14, 34, "The front door")

    # H1 porch -------------------------------------------------------------------------------------------------------
    pl.prop("h1_porch_edge", 16, 38, "decor", "The porch's edge, where the storm waits", "puddle")
    pl.prop("h1_d01", 27, 36, "decor", "A rocking chair", "rocking_chair", facing="southwest")
    pl.prop("h1_d02", 12, 35, "decor", "", "umbrella_stand")
    pl.prop("h1_d03", 3, 36, "decor", "", "lantern_post")
    pl.prop("h1_d04", 30, 36, "decor", "", "lantern_post")
    pl.prop("h1_d05", 6, 37, "decor", "", "leaves")
    pl.prop("h1_d06", 22, 38, "decor", "", "leaves")
    pl.prop("h1_d07", 9, 38, "decor", "", "puddle")
    pl.prop("h1_d08", 24, 36, "decor", "", "broken_boards")
    pl.prop("h1_d09", 2, 35, "decor", "", "cobwebs")
    pl.prop("h1_d10", 30, 38, "decor", "", "crow")
    pl.prop("h1_d11", 31, 36, "decor", "", "barrel")
    pl.prop("h1_d12", 6, 35, "decor", "", "bench")
    pl.prop("h1_d13", 19, 36, "decor", "", "puddle")
    pl.prop("h1_d14", 26, 38, "decor", "", "bloodstain")
    pl.trap("h1_no_escape", [(x, 39) for x in range(1, 33) if x != 20], label="The storm at the porch's edge", detect_dc=5,
            damage="1d6", damage_type="lightning", when="flag.crooked_house_turned and not flag.vessla_slain",
            text="Lightning cracks down on the step and throws you back onto the boards.")
    pl.trap("h1_no_escape_thunder", [(x, 39) for x in range(1, 33) if x != 20], label="The thunder at the porch's edge", detect_dc=5,
            damage="1d6", damage_type="thunder", when="flag.crooked_house_turned and not flag.vessla_slain",
            text="The thunder lands like a fist.")

    # H2 foyer -------------------------------------------------------------------------------------------------------
    pl.prop("h2_portrait_lockwood", 11, 23, "examine", "The Lockwood family portrait", "family_portrait",
            dialogue=CH + "portraits:lockwood",
            text="A stern family stands in oils, the father's face made of the same long shadows as the man on the porch.")
    pl.prop("h2_portrait_druskenvald", 13, 23, "examine", "The Druskenvalds' portrait", "portrait_couple",
            dialogue=CH + "portraits:druskenvald",
            text="A stern woman in a wicker choker, and beside her a man weeping under a crown that is not there.")
    pl.prop("h2_portrait_party", 15, 23, "examine", "A portrait of your own party", "portrait_jester",
            dialogue=CH + "portraits:party",
            text="Your party stands in paint, every smile too wide and every mouth empty of teeth.")
    pl.prop("h2_chandelier", 14, 28, "decor", "A tilted chandelier", "skull_chandelier")
    pl.prop("h2_stair", 17, 23, "examine", "The curved stair", "stairs_up",
            text="The stair bends round the wall in a long, lazy curve, its rail leaning like a drunk.")
    pl.prop("h2_d01", 13, 30, "decor", "A compass rose inlaid in the floor", "floor_glyphs")
    pl.prop("h2_d02", 11, 25, "decor", "", "candelabra")
    pl.prop("h2_d03", 18, 25, "decor", "", "candelabra")
    pl.prop("h2_d04", 18, 27, "decor", "", "painting")
    pl.prop("h2_d05", 11, 32, "decor", "", "sheeted_furniture")
    pl.prop("h2_d06", 12, 31, "decor", "", "fallen_frames")
    pl.prop("h2_d07", 17, 33, "decor", "", "umbrella_stand")
    pl.prop("h2_d08", 18, 32, "decor", "", "painting_row")
    pl.prop("h2_d09", 10, 24, "decor", "", "cobwebs")
    pl.exit("stairs_up", 17, 22, "crooked_house_second", "from_below", "Stairs up to the second floor")

    # H3 parlor ------------------------------------------------------------------------------------------------------
    pl.prop("h3_spirit_board", 10, 16, "examine", "The round table and Adela's spirit board", "table_round", low=True, span=[3, 3],
            dialogue=CH + "seance:start",
            text="A round table with a spirit board inlaid in its top and a heart-shaped planchette marked with two initials.")
    for name, (x, z), face in [("w", (9, 17), "east"), ("e", (13, 17), "west"), ("n", (11, 15), "south"), ("s", (11, 19), "north"),
                               ("nw", (9, 15), "southeast"), ("ne", (13, 15), "southwest"), ("sw", (9, 19), "northeast"),
                               ("se", (13, 19), "northwest")]:
        pl.prop("h3_chair_" + name, x, z, "decor", "", "chair", facing=face)
    pl.prop("h3_crystal_ball", 17, 15, "examine", "A crystal ball on a shelf", "glass_ring",
            call=CH + "incitements:pilgrimage_enter", approach=4,
            call_when="not flag.incitement_pilgrimage and not flag.pending_pilgrimage_incitement",
            text="A crystal ball, clouded from within, sits on a shelf that has been dusted by someone, recently.")
    pl.prop("h3_fireplace", 14, 14, "examine", "A cobwebbed fireplace", "fireplace",
            text="The hearth is a nest of cobweb, and the ash in it is much too fine for wood.")
    pl.prop("h3_d01", 6, 19, "decor", "", "settee")
    pl.prop("h3_d02", 7, 16, "decor", "", "armchair")
    pl.prop("h3_d03", 16, 19, "decor", "", "armchair")
    pl.prop("h3_d04", 6, 14, "decor", "", "book_shelf")
    pl.prop("h3_d05", 9, 14, "decor", "", "painting")
    pl.prop("h3_d06", 17, 17, "decor", "", "candelabra")
    pl.prop("h3_d07", 17, 21, "decor", "", "sheeted_furniture")
    pl.prop("h3_d08", 4, 14, "decor", "", "cobwebs")
    pl.prop("h3_d09", 11, 14, "decor", "", "painting")
    pl.prop("h3_d10", 8, 21, "decor", "", "floor_books")

    # H4 gallery -----------------------------------------------------------------------------------------------------
    pl.prop("h4_peacock", 2, 29, "examine", "A marble peacock in its alcove", "bird_case", scale=1.6, tint="#e8e4dc",
            text="An albino peacock carved in marble, huge, its tail fanned and one eye a polished red stone.")
    pl.prop("h4_bust", 3, 25, "examine", "A dour bust", "statue_head",
            text="The bust glares from its plinth with the look of a man who has never once enjoyed himself.")
    pl.prop("h4_paintings", 5, 24, "examine", "Keziah's landscapes", "painting_row",
            dialogue=CH + "keziah:paintings",
            text="Rolling country in a thin, careful hand. The longer you look, the more of it is eyes, and fur, and teeth.")
    pl.prop("h4_d01", 7, 25, "decor", "", "statue_head")
    pl.prop("h4_d02", 2, 31, "decor", "", "statue_head")
    pl.prop("h4_d03", 6, 31, "decor", "", "candelabra")
    pl.prop("h4_d04", 5, 30, "decor", "", "statue_head")
    pl.prop("h4_d05", 7, 28, "decor", "", "cobwebs")
    pl.prop("h4_d06", 3, 27, "decor", "", "bench")

    # H5 music room --------------------------------------------------------------------------------------------------
    pl.prop("h5_harpsichord", 31, 24, "examine", "A harpsichord gaping like a coffin", "harpsichord", facing="southwest",
            dialogue=CH + "patrini_lament:harpsichord",
            text="The harpsichord's lid is thrown back like a coffin's, and its strings hum faintly though nothing touches them.")
    pl.prop("h5_mirror", 26, 23, "examine", "A cracked oval mirror", "mirror",
            call=CH + "incitements:duality_enter", approach=4, call_when="not flag.incitement_duality",
            text="An oval mirror, cracked across, shows the room with something dancing in it that is not there when you turn.")
    pl.prop("h5_d01", 24, 24, "decor", "", "harp")
    pl.prop("h5_d02", 30, 29, "decor", "", "lute")
    pl.prop("h5_d03", 28, 23, "decor", "", "music_box")
    pl.prop("h5_d04", 24, 28, "decor", "", "settee")
    pl.prop("h5_d05", 31, 27, "decor", "", "armchair")
    pl.prop("h5_d06", 30, 23, "decor", "", "instrument_tray")
    pl.prop("h5_d07", 27, 26, "decor", "", "soot_patch")
    pl.prop("h5_d08", 28, 27, "decor", "", "scorch")
    pl.prop("h5_d09", 26, 29, "decor", "", "soot_patch")
    pl.prop("h5_d10", 29, 25, "decor", "", "scattered_notes")

    # H6 dining room -------------------------------------------------------------------------------------------------
    pl.prop("h6_table", 26, 15, "examine", "A table laid for a perfect feast", "table_meal", low=True, span=[3, 4],
            text="Roast, fruit, steaming bread and wine: a hot feast, spotless, in a room where every other thing wears dust.")
    pl.prop("h6_table_end", 26, 19, "decor", "", "table_meal", low=True, span=[3, 2])
    pl.prop("h6_table_loot", 25, 21, "search", "Something glints among the plates", "", search_dc=10, skill="perception",
            text="Under the edge of a plate, something small and bright.")
    for i, z in enumerate((16, 18, 20)):
        pl.prop(f"h6_chair_w{i}", 25, z, "decor", "", "chair", facing="east")
        pl.prop(f"h6_chair_e{i}", 29, z, "decor", "", "chair", facing="west")
    pl.prop("h6_chair_n", 27, 14, "decor", "", "chair", facing="south")
    pl.prop("h6_chair_s", 27, 21, "decor", "", "chair", facing="north")
    pl.prop("h6_d01", 32, 16, "decor", "", "sideboard")
    pl.prop("h6_d02", 32, 19, "decor", "", "sideboard")
    pl.prop("h6_d03", 23, 15, "decor", "", "candelabra")
    pl.prop("h6_d04", 30, 14, "decor", "", "painting")
    pl.prop("h6_d05", 24, 14, "decor", "", "cobwebs")
    pl.prop("h6_d06", 32, 14, "decor", "", "cobwebs")
    pl.prop("h6_d07", 23, 21, "decor", "", "candelabra")

    # H7 kitchen -----------------------------------------------------------------------------------------------------
    pl.container("h7_oven_contents", 30, 10, "The padlocked brick oven", "oven_brick", locked=True, lock_dc=15)
    pl.trap("h7_oven_trap", [(29, 10)], label="The screaming oven", detect_dc=12, disarm_dc=15,
            save={"ability": "con", "dc": 13}, damage="1d6", damage_type="fire",
            text="The padlock is hot, and the screams behind it get louder as you reach.")
    pl.trap("h7_oven_trap_acid", [(29, 10)], label="The screaming oven's seep", detect_dc=12, disarm_dc=15,
            save={"ability": "con", "dc": 13}, damage="1d6", damage_type="acid",
            text="Something wet and sour seeps from the oven's seams.")
    pl.prop("h7_shelf", 24, 6, "examine", "A fallen metal shelf", "shelves",
            text="A tall metal shelf lies where it fell, its pots and tins strewn across the flags.")
    pl.prop("h7_d01", 28, 5, "decor", "", "stove")
    pl.prop("h7_d02", 22, 5, "decor", "", "pot_rack")
    pl.prop("h7_d03", 31, 5, "decor", "", "jars")
    pl.prop("h7_d04", 26, 8, "decor", "", "cookpot")
    pl.prop("h7_d05", 32, 7, "decor", "", "barrel")
    pl.prop("h7_d06", 21, 8, "decor", "", "sack_pile")
    pl.prop("h7_d07", 32, 11, "decor", "", "crate_stack")
    pl.prop("h7_d08", 23, 11, "decor", "", "bucket_brush")
    pl.prop("h7_d09", 25, 5, "decor", "", "drying_herbs")
    pl.prop("h7_d10", 27, 10, "decor", "", "bloodstain")
    pl.prop("h7_d11", 22, 9, "decor", "", "broken_boards")
    pl.prop("h7_d12", 30, 8, "decor", "", "stewpot")

    # H8 conservatory ------------------------------------------------------------------------------------------------
    pl.prop("h8_bergamot", 10, 6, "examine", "A living bergamot tree", "pine_b", scale=0.9,
            call=CH + "incitements:rejuvenation_enter", approach=4,
            call_when="not flag.incitement_rejuvenation and not flag.pending_rejuvenation_incitement",
            text="One tree among the dead vines is green and heavy with fruit, as if it were fed by the rest.")
    pl.prop("h8_cup", 12, 9, "examine", "A porcelain cup", "sill_cups",
            text="A small porcelain cup sits on the flagstones, polished, with nothing in it and no dust on it at all.")
    pl.prop("h8_d01", 15, 6, "decor", "", "garden_bed")
    pl.prop("h8_d02", 8, 5, "decor", "", "garden_bed")
    pl.prop("h8_d03", 16, 3, "decor", "", "stone_bench")
    pl.prop("h8_d04", 8, 9, "decor", "", "stone_bench")
    pl.prop("h8_d05", 7, 4, "decor", "", "vines")
    pl.prop("h8_d06", 17, 4, "decor", "", "vines")
    pl.prop("h8_d07", 16, 10, "decor", "", "dead_tree_a")
    pl.prop("h8_d08", 13, 4, "decor", "", "leaves")
    pl.prop("h8_d09", 9, 11, "decor", "", "leaves")
    pl.prop("h8_d10", 17, 8, "decor", "", "cobwebs")
    pl.prop("h8_d11", 7, 7, "decor", "", "vines")

    # the long hall ---------------------------------------------------------------------------------------------------
    pl.prop("h_d01", 21, 16, "decor", "", "lantern_bracket")
    pl.prop("h_d02", 21, 24, "decor", "", "lantern_bracket")
    pl.prop("h_d03", 21, 30, "decor", "", "lantern_bracket")
    pl.prop("h_d04", 21, 20, "decor", "", "fallen_frames")
    pl.prop("h_d05", 20, 27, "decor", "", "cobwebs")
    pl.prop("h_d06", 21, 32, "decor", "", "cobwebs")

    # spawns, areas, lights --------------------------------------------------------------------------------------------
    pl.spawn("from_porch", 14, 36)
    pl.spawn("default", 14, 36)
    pl.spawn("from_above", 16, 24)
    pl.exit("to_estate", 20, 39, "druskenvald_estate", "default", "Down the porch steps to the grounds",
            when="not flag.crooked_house_turned or flag.vessla_slain",
            locked_text="The storm hammers the steps. A foot off the boards is a foot into the lightning, and the house will not let you leave.")
    pl.area("h5_floor", "The dance floor", 24, 23, 32, 30, "dim")
    pl.area("h1_porch", "Porch", 1, 35, 32, 39, "dim")
    pl.area("h2_foyer", "Foyer", 10, 23, 18, 33, "dim")
    pl.area("h3_parlor", "Parlor", 4, 14, 18, 21, "dim")
    pl.area("h4_gallery", "Gallery", 1, 24, 8, 32, "dim")
    pl.area("h5_music_room", "Music Room", 23, 23, 32, 30, "dim")
    pl.area("h6_dining_room", "Dining Room", 23, 14, 32, 21, "bright")
    pl.area("h7_kitchen", "Kitchen", 20, 5, 32, 12, "dim")
    pl.area("h8_conservatory", "Conservatory", 6, 2, 18, 12, "dim")
    pl.area("h_hall", "The long hall", 20, 13, 21, 33, "dark")
    pl.light(3, 36, "lamp", 10, 20)
    pl.light(30, 36, "lamp", 10, 20)
    pl.light(14, 29, "candle", 15, 30)
    pl.light(12, 17, "candle", 10, 20)
    pl.light(14, 16, "fire", 10, 25, "ember")
    pl.light(27, 17, "candle", 25, 40)
    pl.light(26, 27, "magic", 10, 25, "moonlight")
    pl.light(29, 11, "fire", 10, 25, "ember")
    pl.light(12, 7, "window", 20, 40, "moonlight")
    pl.light(16, 4, "window", 15, 30, "moonlight")
    pl.light(5, 28, "candle", 10, 20)
    check_models(pl)
    rows = c.finish()
    return pl, rows


def first_data():
    pl, rows = first_floor()
    return pl.data(rows,
                   "The ground floor of the Lockwood manor, bent out of true: a storm-lashed porch, a tall foyer with a curving stair, a parlor with a spirit board, a round gallery, a music room, a dining room laid for a feast, a wrecked kitchen and a glass conservatory.",
                   "Rain drums on the porch. Inside, the floors lean, the doors sit in their frames at slight wrong angles, and every wall holds something that looks back.")


# ---- the second floor: sitting room (turret), children's room, bathroom, master bedroom, balcony -------------------------
def second_floor():
    W, H = 34, 36
    c = Canvas(W, H)
    c.rect(6, 5, 18, 10)                       # H10 children's room
    c.rect(20, 5, 30, 10)                      # H11 bathroom
    c.rect(6, 12, 30, 21)                      # H12 master bedroom and the west hall
    c.rect(11, 13, 15, 14, "#")                # the stair up to the third floor, a block with its foot on the room's side
    c.rect(9, 17, 9, 21, "#")                  # the bedroom's wall against the west hall (open at its north end)
    c.disc(5.5, 27.0, 4.9)                     # H9 sitting room, the turret
    c.rect(10, 23, 18, 25)                     # the landing at the head of the foyer stair
    c.rect(10, 26, 18, 26, "=")                # the cracked rail over the foyer
    c.rect(10, 27, 10, 33, "=")
    c.rect(11, 27, 18, 33, " ")                # the foyer below: nothing to stand on
    c.rect(20, 23, 30, 28)                     # the balcony
    c.rect(20, 29, 30, 29, "=")                # its rail
    c.rect(20, 30, 30, 30, ".")                # and the ledge beyond it
    pl = Place("crooked_house_second", "The Crooked House, Second Floor", c)
    c.put(12, 11, "."); c.put(25, 11, "."); c.put(24, 22, ".")
    pl.door("h10_door", 12, 11, "The children's room door")
    pl.door("h11_door", 25, 11, "The bathroom door")
    pl.door("h12_balcony_doors", 24, 22, "The balcony doors", locked=True, lock_dc=15,
            locked_text="The balcony doors are locked, and the storm leans on them from the other side.")

    # H9 sitting room --------------------------------------------------------------------------------------------------
    pl.prop("h9_clock", 8, 23, "examine", "A grandfather clock, still ticking", "clock_tall",
            text="A grandfather clock stands in the turret's curve, ticking in a house where nothing else keeps time.")
    pl.prop("h9_rail", 12, 26, "examine", "A cracked rail over the foyer", "bridge_parapet", span=[4, 1],
            text="The rail is cracked through in three places. Below it, the foyer's chandelier hangs at a tilt, looking up.")
    pl.prop("h9_d01", 5, 27, "decor", "", "table_round")
    pl.prop("h9_d02", 3, 26, "decor", "", "armchair")
    pl.prop("h9_d03", 7, 26, "decor", "", "armchair")
    pl.prop("h9_d04", 3, 29, "decor", "", "armchair")
    pl.prop("h9_d05", 7, 29, "decor", "", "armchair")
    pl.prop("h9_d06", 11, 24, "decor", "", "candelabra")
    pl.prop("h9_d07", 4, 24, "decor", "", "cobwebs")
    pl.prop("h9_d08", 2, 28, "decor", "", "settee")
    pl.prop("h9_d09", 16, 24, "decor", "", "fallen_frames")

    # H10 children's room --------------------------------------------------------------------------------------------
    pl.prop("h10_bed_left", 9, 5, "search", "A small bed", "bed_small", search_dc=10, skill="perception",
            text="A child's bed, made, the blanket drawn up over a shape that is only pillows.")
    pl.prop("h10_bed_right", 13, 5, "search", "A second small bed", "bed_small", search_dc=10, skill="perception",
            text="A second small bed, its blanket slightly turned back, as if someone has just got out.")
    pl.prop("h10_window", 11, 5, "search", "A dark window", "window_tall", search_dc=10, skill="perception",
            text="The window shows nothing but black glass, and a faint breath on it from the inside.")
    pl.prop("h10_chest", 16, 5, "search", "A big toy chest", "toy_chest", search_dc=10, skill="perception",
            text="A toy chest big enough for a child to curl up in, its lid not quite shut.")
    pl.prop("h10_armoire", 18, 8, "search", "A child's armoire", "wardrobe", search_dc=10, skill="perception",
            text="A little armoire, its door ajar on a row of tiny coats.")
    pl.prop("h10_closet", 7, 8, "search", "A closet, ajar", "cupboard", search_dc=15, skill="investigation",
            text="A closet door stands open a hand's width on the dark inside.")
    pl.prop("h10_doll", 17, 9, "examine", "A wooden doll", "doll", dialogue=CH + "sally_doll:start", when="flag.memento_doll",
            text="A small wooden doll sits where it fell, its painted face turned toward you.")
    pl.prop("h10_d01", 8, 9, "decor", "", "dollhouse")
    pl.prop("h10_d02", 13, 8, "decor", "", "rocking_horse")
    pl.prop("h10_d03", 15, 5, "decor", "", "toy_shelf")
    pl.prop("h10_d04", 10, 5, "decor", "", "drawings")
    pl.prop("h10_d05", 12, 8, "decor", "", "floor_books")
    pl.prop("h10_d06", 9, 8, "decor", "", "scattered_notes")
    pl.prop("h10_d07", 6, 5, "decor", "", "cobwebs")
    pl.prop("h10_d08", 15, 9, "decor", "", "doll")

    # H11 bathroom ---------------------------------------------------------------------------------------------------
    pl.prop("h11_tub", 29, 5, "examine", "A claw-foot tub, stained red", "bathtub", span=[2, 3],
            text="The tub is full to the brim of something warm and red, and it is very still.")
    pl.container("h11_duck", 22, 5, "A yellow duck on the sink", "doll_yellow")
    pl.prop("h11_d01", 21, 5, "decor", "", "washstand")
    pl.prop("h11_d02", 24, 5, "decor", "", "dressing_table")
    pl.prop("h11_d03", 26, 5, "decor", "", "mirror")
    pl.prop("h11_d04", 27, 8, "decor", "", "bloodstain")
    pl.prop("h11_d05", 24, 8, "decor", "", "puddle")
    pl.prop("h11_d06", 28, 8, "decor", "", "blood_pool")
    pl.prop("h11_d07", 21, 9, "decor", "", "cobwebs")
    pl.prop("h11_d08", 22, 8, "decor", "", "bucket_brush")

    # H12 master bedroom and hall ---------------------------------------------------------------------------------------
    pl.prop("h12_bed", 27, 16, "examine", "A torn canopy bed, something writhing under the covers", "bed_canopy", low=True, span=[3, 4],
            text="The canopy is in rags, and under the bedclothes something large turns over, slowly, and settles again.")
    pl.prop("h12_journal", 17, 20, "book", "Phillip's black journal", "book", codex="phillip_journal",
            text="A black leather journal with a monogram stamped in gilt, and a small lock holding it shut.")
    pl.prop("h12_scratchings", 22, 12, "examine", "Scratchings in the plaster", "claw_marks",
            call=CH + "incitements:kindred_enter", approach=4, call_when="not flag.incitement_kindred",
            text="Fine scratches cover the wall, thousands of them, as if something has been trying to dig its way out for years.")
    pl.prop("h12_d01", 15, 20, "decor", "", "desk", span=[2, 1])
    pl.prop("h12_d02", 16, 12, "decor", "", "wardrobe")
    pl.prop("h12_d03", 20, 12, "decor", "", "dressing_table")
    pl.prop("h12_d04", 7, 15, "decor", "", "rug_runner")
    pl.prop("h12_d05", 7, 18, "decor", "", "rug_runner")
    pl.prop("h12_d06", 30, 13, "decor", "", "settee")
    pl.prop("h12_d07", 26, 20, "decor", "", "bloodstain")
    pl.prop("h12_d08", 11, 15, "decor", "", "bridge_parapet")
    pl.prop("h12_d09", 15, 15, "decor", "", "bridge_parapet")
    pl.prop("h12_d10", 20, 16, "decor", "", "fallen_frames")
    pl.prop("h12_d11", 8, 12, "decor", "", "cobwebs")
    pl.prop("h12_d12", 30, 20, "decor", "", "footlocker")
    pl.prop("h12_d13", 18, 14, "decor", "", "sheeted_furniture")

    # the balcony ------------------------------------------------------------------------------------------------------
    pl.prop("bal_d01", 21, 24, "decor", "", "garden_bed")
    pl.prop("bal_d02", 29, 24, "decor", "", "garden_bed")
    pl.prop("bal_d03", 25, 26, "decor", "", "puddle")
    pl.prop("bal_d04", 22, 27, "decor", "", "leaves")
    pl.prop("bal_d05", 28, 27, "decor", "", "broken_boards")
    pl.prop("bal_d06", 24, 24, "decor", "", "rocking_chair", facing="south")
    pl.trap("h12_balcony_edge", [(x, 30) for x in range(20, 31)], label="The storm beyond the balcony rail", detect_dc=5,
            damage="1d6", damage_type="lightning", when="flag.crooked_house_turned and not flag.vessla_slain",
            text="Lightning splits the air over the ledge and throws you back against the rail.")
    pl.trap("h12_balcony_edge_thunder", [(x, 30) for x in range(20, 31)], label="The thunder beyond the balcony rail", detect_dc=5,
            damage="1d6", damage_type="thunder", when="flag.crooked_house_turned and not flag.vessla_slain",
            text="The thunder lands like a fist.")

    pl.spawn("from_below", 16, 24)
    pl.spawn("default", 16, 24)
    pl.spawn("from_above", 13, 15)
    pl.exit("stairs_down", 17, 22, "crooked_house_first", "from_above", "Stairs down to the foyer")
    pl.exit("stairs_up", 13, 14, "crooked_house_third", "from_below", "Stairs up to the third floor")
    pl.area("h9_sitting_room", "Sitting Room", 1, 22, 9, 31, "dim")
    pl.area("h9_landing", "Landing", 10, 23, 18, 25, "dim")
    pl.area("h10_childrens_room", "Children's Room", 6, 5, 18, 10, "dim")
    pl.area("h11_bathroom", "Bathroom", 20, 5, 30, 10, "dim")
    pl.area("h12_master_bedroom", "Master Bedroom", 9, 12, 30, 21, "dim")
    pl.area("h12_west_hall", "The west hall", 6, 12, 8, 21, "dark")
    pl.area("h12_balcony", "Balcony", 20, 23, 30, 28, "dim")
    pl.area("balcony_edge", "The balcony's edge", 20, 29, 30, 30, "dim")
    pl.light(5, 27, "candle", 10, 25)
    pl.light(13, 24, "candle", 10, 20)
    pl.light(12, 7, "candle", 8, 20)
    pl.light(29, 8, "candle", 10, 20)
    pl.light(28, 18, "candle", 10, 25)
    pl.light(17, 19, "lamp", 10, 20)
    pl.light(25, 26, "window", 15, 30, "moonlight")
    pl.light(7, 14, "candle", 8, 16)
    check_models(pl)
    rows = c.finish()
    return pl, rows


def second_data():
    pl, rows = second_floor()
    return pl.data(rows,
                   "The upper floor: a round sitting room in the turret, a children's room with two small beds, a red-stained bathroom, a master bedroom with a writhing bed, and a locked balcony over the porch.",
                   "The upper hall slopes toward the turret. Doors stand ajar on rooms that were kept for children, a bath, and a bed that will not stay still.",
                   ceiling=10)


# ---- the third floor: nursery, library, trophy room ---------------------------------------------------------------------
def third_floor():
    W, H = 34, 33
    c = Canvas(W, H)
    c.rect(6, 4, 16, 9)                        # H13 nursery
    c.rect(6, 11, 14, 18)                      # the stair hall
    c.rect(9, 12, 11, 13, "#")                 # the stair down, with its foot in the hall
    c.rect(15, 16, 28, 18)                     # the hall along the trophy room's south wall
    c.rect(18, 3, 28, 14)                      # H15 trophy room
    c.rect(8, 20, 27, 27)                      # H14 library
    c.rect(13, 28, 23, 29)                     # the library's bay
    pl = Place("crooked_house_third", "The Crooked House, Third Floor", c)
    c.put(11, 10, "."); c.put(23, 15, "."); c.put(12, 19, ".")
    pl.door("h13_door", 11, 10, "The nursery door")
    pl.door("h15_door", 23, 15, "The trophy room door")
    pl.door("h14_door", 12, 19, "The library door")

    pl.prop("h13_crib", 10, 5, "examine", "A mahogany crib riddled with tiny holes", "crib", low=True,
            text="The crib's rails are pitted with hundreds of little round holes, and inside it something small and blue is crying.")
    pl.prop("h13_d01", 14, 5, "decor", "A cradle, riddled the same way", "crib_shroud")
    pl.prop("h13_d02", 7, 8, "decor", "", "rocking_horse")
    pl.prop("h13_d03", 15, 8, "decor", "", "rocking_chair", facing="west")
    pl.prop("h13_d04", 7, 5, "decor", "", "toy_chest")
    pl.prop("h13_d05", 13, 7, "decor", "", "dollhouse")
    pl.prop("h13_d06", 9, 8, "decor", "", "floor_books")
    pl.prop("h13_d07", 8, 6, "decor", "", "doll")
    pl.prop("h13_d08", 12, 5, "decor", "", "mobile")
    pl.prop("h13_d09", 15, 6, "decor", "", "cobwebs")
    pl.prop("h13_d10", 6, 9, "decor", "", "drawings")
    pl.prop("h_d01", 7, 12, "decor", "", "painting")
    pl.prop("h_d02", 13, 12, "decor", "", "lantern_bracket")
    pl.prop("h_d03", 12, 15, "decor", "", "bridge_parapet")
    pl.prop("h_d04", 20, 16, "decor", "", "cobwebs")
    pl.prop("h_d05", 27, 17, "decor", "", "lantern_bracket")

    pl.prop("h14_cart", 11, 24, "examine", "A cobwebbed liquor cart", "handcart",
            text="A drinks cart furred with cobweb, its bottles gone brown and a few of them, oddly, unbroken.")
    pl.container("h14_cart_stock", 11, 25, "The cart's lower shelf", "bottle_rack", items=[{"id": "potion_of_healing", "qty": 4}])
    pl.prop("h14_tome", 15, 24, "examine", "A tome left on a lectern", "lectern",
            call=CH + "incitements:malediction_enter", approach=4, call_when="not flag.incitement_malediction",
            text="A heavy book lies open on a lectern, and the words on its page seem to be the ones you would say next.")
    pl.prop("h14_desk", 21, 23, "examine", "A desk under a stack of books", "desk", low=True, span=[3, 2],
            text="A wide desk stacked with books, and the dust on it is rubbed away in a round warm patch where something curled.")
    for i, x in enumerate([9, 10, 13, 14, 15, 17, 18, 19, 20, 21, 22, 24, 25, 26]):
        pl.prop(f"h14_shelf_{i}", x, 20, "decor", "", "bookshelf")
    pl.prop("h14_d01", 27, 22, "decor", "", "bookshelf")
    pl.prop("h14_d02", 27, 25, "decor", "", "bookshelf")
    pl.prop("h14_d03", 14, 26, "decor", "", "armchair")
    pl.prop("h14_d04", 25, 26, "decor", "", "armchair")
    pl.prop("h14_d05", 10, 22, "decor", "", "floor_books")
    pl.prop("h14_d06", 12, 22, "decor", "", "scattered_notes")
    pl.prop("h14_d07", 17, 26, "decor", "", "sheeted_furniture")
    pl.prop("h14_d08", 17, 28, "decor", "", "book_stack")
    pl.prop("h14_d09", 20, 28, "decor", "", "candelabra")
    pl.prop("h14_d10", 9, 26, "decor", "", "cobwebs")
    pl.prop("h14_d11", 26, 23, "decor", "", "tiger_rug")

    pl.prop("h15_trapdoor", 22, 5, "examine", "The ceiling above the hearth", "roof_hatch",
            text="Above you the ceiling plaster is stained in an almost-square, and the stain is a little too neat.")
    pl.prop("h15_bear", 26, 12, "examine", "A large brown bear, stuffed", "stuffed_wolf", low=True, scale=2.2,
            text="A huge bear, mounted on its hind legs, fangs bared, and its stuffing has a way of shifting when you look away.")
    pl.prop("h15_trophy_crow", 19, 4, "examine", "A stuffed crow on a perch", "crow", scale=1.5,
            call=CH + "incitements:slaughter_enter", approach=4,
            call_when="not flag.incitement_slaughter and not flag.pending_slaughter_incitement",
            text="A stuffed crow sits on a perch with its glass eyes fixed on the doorway, and one wing half open.")
    pl.prop("h15_d01", 26, 3, "decor", "", "fireplace")
    pl.prop("h15_d02", 20, 3, "decor", "", "stag_head")
    pl.prop("h15_d03", 19, 7, "decor", "", "bat_perch")
    pl.prop("h15_d04", 27, 7, "decor", "", "stuffed_wolf")
    pl.prop("h15_d05", 20, 10, "decor", "", "trophy_wolf")
    pl.prop("h15_d06", 23, 9, "decor", "", "rug_wolf")
    pl.prop("h15_d07", 21, 12, "decor", "", "armchair")
    pl.prop("h15_d08", 24, 12, "decor", "", "crow_barrel")
    pl.prop("h15_d09", 28, 5, "decor", "", "stag_head")
    pl.prop("h15_d10", 18, 13, "decor", "", "cobwebs")
    pl.prop("h15_d11", 25, 6, "decor", "", "bat_perch")

    pl.spawn("from_below", 10, 14)
    pl.spawn("default", 10, 14)
    pl.spawn("from_attic", 23, 7)
    pl.exit("stairs_down", 10, 13, "crooked_house_second", "from_above", "Stairs down to the second floor")
    pl.exit("up_to_attic", 23, 5, "crooked_house_attic", "from_ladder", "Hatch up to the attic",
            when="flag.trapdoor_known",
            locked_text="There is nothing up there to reach. The ceiling is only plaster.")
    pl.area("h13_nursery", "Nursery", 6, 4, 16, 9, "dim")
    pl.area("h13_stair_hall", "The stair hall", 6, 11, 14, 18, "dark")
    pl.area("h13_long_hall", "The upper hall", 15, 16, 28, 18, "dark")
    pl.area("h14_library", "Library", 8, 20, 27, 29, "dim")
    pl.area("h15_trophy_room", "Trophy Room", 18, 3, 28, 14, "dim")
    pl.light(11, 7, "candle", 8, 20)
    pl.light(23, 9, "candle", 10, 25)
    pl.light(26, 4, "fire", 10, 25, "ember")
    pl.light(20, 24, "lamp", 10, 25)
    pl.light(12, 14, "candle", 8, 16)
    pl.light(27, 8, "window", 15, 30, "moonlight")
    pl.light(27, 23, "window", 15, 30, "moonlight")
    check_models(pl)
    rows = c.finish()
    return pl, rows


def third_data():
    pl, rows = third_floor()
    return pl.data(rows,
                   "The top floor: a nursery with a holed crib, a library of sagging shelves, and a trophy room of stuffed things in the wrong poses, with a stain on the ceiling that is a little too square.",
                   "Wind finds its way into the top floor through places the walls swear are sealed. Books lie open on every flat thing, and the animals on the walls have all turned to watch the door.",
                   ceiling=10)


# ---- the attic: the secret landing and the cauldron room ----------------------------------------------------------------
def attic():
    W, H = 19, 23
    c = Canvas(W, H)
    c.rect(4, 3, 12, 6)                        # H16 secret landing
    c.rect(4, 8, 14, 19)                       # H17 cauldron room
    pl = Place("crooked_house_attic", "The Crooked House, Attic", c)
    c.put(8, 7, ".")
    pl.door("h16_ward", 8, 7, "The warded door", leaf="none", when="flag.mementos_placed >= 6",
            locked_text="A curtain of red light holds the little door shut, and six empty circles in the runes wait to be filled.")

    pl.prop("h16_sockets", 9, 6, "examine", "Six empty circles in the runes", "offering_circle",
            dialogue=CH + "sockets:place",
            text="Six circles are cut into the pulsing runes, each the size of a hand, each empty.")
    pl.prop("h16_runes", 6, 5, "examine", "Blood-red runes", "rune_circle",
            text="Runes cover the floor, walls and ceiling, throbbing like a slow pulse.")
    pl.prop("h16_d01", 11, 4, "decor", "", "floor_glyphs")
    pl.prop("h16_d02", 6, 3, "decor", "", "cobwebs")
    pl.prop("h16_d03", 12, 6, "decor", "", "candle_cluster")
    pl.prop("h16_d04", 8, 4, "decor", "", "bone_scatter")

    pl.prop("h17_cauldron", 9, 13, "examine", "A great cauldron of glowing red ichor", "cauldron", scale=1.4,
            text="A cauldron as wide as a cart, bubbling with something red that gives off heat and the smell of old pennies.")
    pl.prop("h17_phillip", 7, 15, "decor", "Phillip, bound", "rope_coils")
    pl.prop("h17_adela", 11, 15, "decor", "Adela, bound", "rope_coils")
    pl.prop("h17_scratchings", 14, 12, "examine", "Scratchings in the beam", "claw_marks",
            text="Scratches cover the old beam, and among them, cut deep and slowly, are names.")
    pl.prop("h17_window", 9, 19, "decor", "The round window", "window_lit")
    pl.prop("h17_d01", 4, 10, "decor", "", "bench")
    pl.prop("h17_d02", 4, 12, "decor", "", "bench")
    pl.prop("h17_d03", 14, 14, "decor", "", "bench")
    pl.prop("h17_d04", 9, 9, "decor", "", "reading_table")
    pl.prop("h17_d05", 5, 9, "decor", "", "cobwebs")
    pl.prop("h17_d06", 5, 17, "decor", "", "wall_chains")
    for i, (x, z) in enumerate([(6, 10), (8, 11), (12, 10), (13, 11), (6, 12), (7, 17), (12, 17), (10, 18), (5, 15), (13, 16),
                                (11, 12), (8, 17), (10, 10), (13, 18), (6, 18)]):
        pl.prop(f"h17_teeth_{i:02d}", x, z, "decor", "", "bone_scatter")

    pl.spawn("from_ladder", 5, 5)
    pl.spawn("default", 5, 5)
    pl.exit("ladder_down", 4, 3, "crooked_house_third", "from_attic", "Hatch down to the trophy room")
    pl.area("h16_secret_landing", "Secret Landing", 4, 3, 12, 6, "dim")
    pl.area("h17_cauldron_room", "Cauldron Room", 4, 8, 14, 19, "dim")
    pl.area("h17_cauldron_area", "Round the cauldron", 6, 11, 12, 15, "dim")
    pl.light(8, 5, "magic", 15, 30, "blood")
    pl.light(9, 13, "magic", 25, 45, "blood")
    pl.light(5, 9, "candle", 8, 16)
    pl.light(13, 9, "candle", 8, 16)
    pl.light(9, 18, "window", 12, 25, "blood_deep")
    check_models(pl)
    rows = c.finish()
    return pl, rows


def attic_data():
    pl, rows = attic()
    return pl.data(rows,
                   "The hidden attic: a cramped landing cut with blood-red runes and six empty circles, a little warded door, and beyond it a long room whose floor is carpeted with teeth and whose cauldron bubbles red.",
                   "The attic is a box of beams and red light. The runes pulse on every surface, and the air smells of hot copper and wet fur.",
                   ceiling=10)


FLOORS = [("crooked_house_first", first_data), ("crooked_house_second", second_data), ("crooked_house_third", third_data),
          ("crooked_house_attic", attic_data)]


def cmd_floors():
    for pid, fn in FLOORS:
        write(f"data/locations/{pid}.json", fn())
        print("wrote", pid)



# ---- the estate: the land (paint), then the manor, porch, gate and dress laid over what make sketch derived -----------------
EW, EH = 40, 36        # the estate is 40 x 36 squares; the pictures are 20 px a square so edges can wander
S = 20

# the buildings, as inclusive square rectangles (x0, z0, x1, z1): the manor with its turret wing (one L-shaped block), two barns
MANOR = [(11, 5, 28, 11), (8, 8, 10, 11), (12, 2, 16, 4), (23, 3, 28, 4)]   # the main house, the turret wing, the conservatory, the kitchen wing
BARN_N = (31, 4, 37, 8)
BARN_E = (31, 14, 35, 17)
# the road from the village gate at the south-east corner up to the manor's porch steps (squares; trees and props keep off it)
ROAD = [(33, 35), (31, 33), (27, 31), (23, 29.5), (21, 28), (21, 26), (21, 22), (20, 18), (20, 14)]
YARD_PATH = [(24, 20), (28, 16), (29, 13.5), (32, 12.5)]
GARDEN_PATH = [(18, 14), (13, 14.5), (9, 15)]
GATE = (20, 27)         # the gate's two squares are (20, 27) and (21, 27)


def noisy_blob(cx, cz, rx, rz, seed, wobble=0.22, n=44):
    r = random.Random(seed)
    ph = [r.uniform(0, 6.28) for _ in range(4)]
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + wobble * (0.55 * math.sin(2 * a + ph[0]) + 0.3 * math.sin(3 * a + ph[1]) + 0.25 * math.sin(5 * a + ph[2]))
        pts.append(((cx + math.cos(a) * rx * k) * S, (cz + math.sin(a) * rz * k) * S))
    return pts


def height_at(x, z):
    """The land in digits (1 = 5 ft): a hill with the manor on its shoulder, easing down south to the road's end."""
    d = math.hypot((x - 20) / 1.0, (z - 8) / 0.8)
    h = max(0.7, 6.2 - 0.27 * max(0.0, d - 10.5))
    h += 1.1 * math.exp(-((x - 5.0) ** 2 + (z - 31.0) ** 2) / 14.0) + 0.8 * math.exp(-((x - 36.0) ** 2 + (z - 24.0) ** 2) / 10.0)
    h -= 0.6 * math.exp(-((x - 34.0) ** 2 + (z - 34.0) ** 2) / 26.0)
    # the farmyard's bench to the north-east, held level for the barns
    d2 = math.hypot((x - 34) / 1.0, (z - 11) / 1.3)
    h = max(h, 5.0 - 0.45 * max(0.0, d2 - 6.5))
    # the kitchen gardens step down the western slope in three terraces
    if x < 10 and 3 <= z <= 16:
        h = min(h, 5.6 if z < 8 else 5.0 if z < 12 else 4.4)
    # the pond's hollow
    r = math.hypot((x - 10.5) / 5.5, (z - 25.5) / 3.9)
    h -= 2.6 * math.exp(-(r * r) * 0.9)
    # the dead tree's old mound, and the lane's long gentle rise to the gate
    h += 0.5 * math.exp(-((x - 4.5) ** 2 + (z - 3.5) ** 2) / 8.0)
    return max(0.0, min(7.0, h))


def cmd_paint(out):
    from PIL import Image, ImageDraw, ImageFilter
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    WATER, WOODS, ROCK, WALL, BRAMBLE, FENCE, VOID, OPEN = "#0000ff", "#006400", "#808080", "#ff0000", "#8b4513", "#ffff00", "#000000", "#e8e8e8"
    lay = Image.new("RGB", (EW * S, EH * S), OPEN)
    L = ImageDraw.Draw(lay)
    hei = Image.new("L", (EW * S, EH * S))
    hp = hei.load()
    for py in range(EH * S):
        z = py / S
        for px in range(EW * S):
            hp[px, py] = int(255 * height_at(px / S, z) / 7.0 + 0.5)
    hei = hei.filter(ImageFilter.GaussianBlur(S * 0.9))
    hei.save(out / "height.png")

    def sqr(x0, z0, x1, z1, fill):
        L.rectangle((x0 * S, z0 * S, (x1 + 1) * S - 1, (z1 + 1) * S - 1), fill=fill)

    # the border of woods, thinning to open at the road's end
    sqr(0, 0, EW - 1, 0, WOODS)
    sqr(0, EH - 1, EW - 1, EH - 1, WOODS)
    sqr(0, 0, 0, EH - 1, WOODS)
    sqr(EW - 1, 0, EW - 1, EH - 1, WOODS)
    sqr(32, EH - 2, 35, EH - 1, OPEN)                 # the road leaves the map here
    # the pond: one wandering body of water, with a tail where it spills toward the south-west
    L.polygon(noisy_blob(10.5, 25.6, 5.0, 3.3, 11), fill=WATER)
    L.polygon(noisy_blob(14.6, 27.2, 1.6, 1.2, 12, 0.3, 24), fill=WATER)
    L.polygon(noisy_blob(5.2, 22.4, 1.8, 1.3, 13, 0.3, 24), fill=WATER)
    # the buildings: one L-shaped block for the manor, two barns
    for r in MANOR:
        sqr(*r, WALL)
    sqr(*BARN_N, WALL)
    sqr(*BARN_E, WALL)

    def fence_h(x0, x1, z, gap=()):
        for x in range(x0, x1 + 1):
            if x not in gap:
                sqr(x, z, x, z, FENCE)

    def fence_v(x, z0, z1, gap=()):
        for z in range(z0, z1 + 1):
            if z not in gap:
                sqr(x, z, x, z, FENCE)

    fence_h(17, 38, 27, gap=(20, 21))                  # the fence along the hill below the manor, the gate's gap left in it
    fence_v(29, 3, 19, gap=(13, 14))                   # the farmyard's fence, a gap for the cart track
    fence_h(29, 38, 19, gap=(33, 34))
    fence_h(2, 9, 16, gap=(5, 6))                      # the kitchen gardens
    fence_v(8, 4, 7)
    # brambles in clumps along the outside of the fences and in the corners
    for (cx, cz, rx, rz) in [(14, 29.4, 1.6, 1.0), (26, 29, 1.4, 1.0), (31, 25.4, 1.6, 1.1), (4, 19.5, 1.5, 1.2), (2.4, 24.6, 1.1, 1.5),
                             (36.5, 23, 1.5, 1.2), (37.2, 12, 1.0, 1.6), (25, 2.2, 1.5, 0.9), (22.5, 17.6, 1.1, 0.8),
                             (36, 31, 1.6, 1.0), (8.5, 32, 1.8, 1.2)]:
        L.polygon(noisy_blob(cx, cz, rx, rz, int(cx * 5 + cz)), fill=BRAMBLE)
    lay.save(out / "layout.png")
    # a labelled picture for the eye
    prev = lay.copy()
    D = ImageDraw.Draw(prev)
    for name, (x0, z0, x1, z1) in {"manor": MANOR[0], "turret": MANOR[1], "barn N": BARN_N, "barn E": BARN_E}.items():
        D.text((x0 * S + 4, z0 * S + 4), name, fill="white")
    for a, b in zip(ROAD, ROAD[1:]):
        D.line((a[0] * S + 10, a[1] * S + 10, b[0] * S + 10, b[1] * S + 10), fill=(120, 80, 20), width=6)
    prev.save(out / "preview_labelled.png")
    print("painted", out)


def corridor(points, c, radius):
    """Squares within `radius` of the polyline `points` (kept clear of trees and bulky props)."""
    near = set()
    for (x0, z0), (x1, z1) in zip(points, points[1:]):
        steps = int(max(abs(x1 - x0), abs(z1 - z0)) * 2) + 1
        for i in range(steps + 1):
            x = x0 + (x1 - x0) * i / steps
            z = z0 + (z1 - z0) * i / steps
            for dz in range(-int(radius) - 1, int(radius) + 2):
                for dx in range(-int(radius) - 1, int(radius) + 2):
                    cx, cz = int(x) + dx, int(z) + dz
                    if (cx + 0.5 - x) ** 2 + (cz + 0.5 - z) ** 2 <= radius * radius:
                        near.add((cx, cz))
    return near


WELCOME = "not flag.crooked_house_turned or flag.druskenvald_manor_restored"
RUINED = "flag.crooked_house_turned and not flag.druskenvald_manor_restored"


def estate_data():
    f = ROOT / "data/locations/druskenvald_estate.json"
    base = json.load(open(f))
    rows = [list(r) for r in base["map"]["rows"]]
    elev = base["map"]["elevation"]
    assert len(rows) == EH and len(rows[0]) == EW, "run make sketch with SIZE=40x36 first"
    cv = Canvas(EW, EH)
    cv.g = rows
    # the porch: a raised deck round the manor's south and west sides (a 2 ft step; no climb)
    for (x0, z0, x1, z1) in [(7, 12, 29, 13), (6, 8, 7, 13), (9, 5, 10, 7)]:
        for z in range(z0, z1 + 1):
            for x in range(x0, x1 + 1):
                if cv.get(x, z) == ".":
                    cv.put(x, z, "_")
    pl = Place("druskenvald_estate", "The Druskenvald Estate", cv)
    keep = corridor(ROAD, cv, 2.2) | corridor(YARD_PATH, cv, 1.6) | corridor(GARDEN_PATH, cv, 1.6)
    for c in [(20, 24), (21, 24), (20, 25), (21, 25), (22, 24), (22, 25), (19, 25), (19, 24)]:
        keep.add(c)          # the Jenkins wait at the gate
    rnd = random.Random(1031)

    def open_cell(x, z, loose=False):
        ch = cv.get(x, z)
        return ch in (".", "_", "~") and (x, z) not in pl.used and (loose or (x, z) not in keep) and 1 <= x < EW - 1 and 1 <= z < EH - 1

    # doors and exits
    pl.exit("porch_steps", 20, 11, "crooked_house_first", "from_porch", "Up the porch steps into the house")
    pl.exit("to_village", 33, 35, "travel", None, "Down the hill road to the village")
    del pl.exits[-1]["spawn"]
    # people's places and spawns
    pl.spawn("default", 20, 15)
    pl.spawn("from_village", 33, 33)

    # --- the buildings' own props: things to look at beside them
    pl.prop("estate_front_door", 20, 12, "examine", "The manor's front door", "door_house",
            text="The front door stands under the porch light, tall and polished and very slightly out of square.")
    pl.prop("estate_gate", 20, 27, "examine", "The open gate", "gate_iron", span=[2, 1],
            text="An iron gate between two stone posts, standing open as if the house had been waiting up for you.")
    pl.prop("estate_pillar_w", 19, 27, "decor", "", "gate_pillar")
    pl.prop("estate_pillar_e", 22, 27, "decor", "", "gate_pillar")
    pl.prop("estate_pond", 15, 25, "examine", "The pond", "reeds", scale=1.3,
            text="Black water under a skin of drifted leaves. Something below it turns over and is still.")
    pl.prop("estate_barn_north", 33, 9, "examine", "The big barn", "hay_bale",
            text="The big barn's doors are chained, and the hay inside has been dry for years, yet it smells freshly cut.")
    pl.prop("estate_barn_east", 33, 18, "examine", "The small barn", "cart_broken",
            text="The small barn sags toward its neighbour. A cart with a broken wheel waits for a horse that is never coming.")
    pl.prop("estate_dead_tree", 5, 4, "examine", "The dead tree", "dead_tree_b", scale=3.2,
            text="A great grey tree, dead to its roots, reaches over the north-west corner of the grounds with its fingers spread.")
    pl.prop("estate_well", 24, 15, "examine", "A well", "well_stone",
            text="A stone well with a bucket on a rotten rope. Down it, a very faint sound of something scratching.")
    pl.prop("estate_sign", 22, 28, "examine", "A signpost at the gate", "signpost", facing="west", when=WELCOME,
            text="A painted board: the Druskenvald Estate, and a smaller line under it: dinner at seven.")
    pl.prop("estate_sign_broken", 23, 28, "examine", "A broken signpost", "signpost_broken", facing="west", when=RUINED,
            text="The signpost leans, split at the middle, the name on it scratched into a long line.")
    pl.prop("estate_steps", 20, 14, "decor", "The porch steps", "stair_riser", facing="north")
    pl.prop("estate_scarecrow", 6, 9, "decor", "A scarecrow", "scarecrow", facing="east", when=WELCOME)
    pl.prop("estate_scarecrow_stitched", 6, 10, "decor", "A scarecrow, stitched", "scarecrow_stitched", facing="east", when=RUINED)
    pl.prop("estate_boat", 5, 24, "decor", "A rowboat drawn up on the bank", "rowboat", facing="east")

    # --- dressed beyond the map: the welcoming manor and the ruined one, from the same rows
    cells_welcome = [(15, 14), (25, 14), (20, 16), (21, 24), (19, 20), (22, 20), (29, 14), (11, 14)]
    for i, (x, z) in enumerate(cells_welcome):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_lamp_{i}", x, z, "decor", "", "lantern_post", when=WELCOME)
    for i, (x, z) in enumerate([(12, 13), (16, 13), (24, 13), (28, 13), (8, 13), (7, 10)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_bunting_{i}", x, z, "decor", "", "bunting", when=WELCOME)
    for i, (x, z) in enumerate([(18, 13), (22, 13), (14, 13)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_candles_{i}", x, z, "decor", "", "candle_cluster", when=WELCOME)
    for i, (x, z) in enumerate([(18, 15), (23, 16), (14, 15), (26, 14)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_flowers_{i}", x, z, "decor", "", "garden_bed", when=WELCOME)
    for i, (x, z) in enumerate([(13, 13), (17, 13), (23, 13), (27, 12), (9, 12), (14, 6)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_rot_boards_{i}", x, z, "decor", "", "broken_boards", when=RUINED)
    for i, (x, z) in enumerate([(12, 12), (25, 12), (10, 9), (7, 12)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_rot_cobweb_{i}", x, z, "decor", "", "cobwebs", when=RUINED)
    for i, (x, z) in enumerate([(16, 12), (26, 13), (18, 8)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_rot_beam_{i}", x, z, "decor", "", "fallen_beam", when=RUINED)
    for i, (x, z) in enumerate([(17, 16), (24, 16), (15, 20), (23, 21), (14, 16), (27, 18)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_rot_tree_{i}", x, z, "decor", "", "dead_tree_a" if i % 2 == 0 else "dead_tree_b", when=RUINED, scale=1.1)
    for i, (x, z) in enumerate([(19, 27 - 1), (23, 26), (18, 22), (24, 22), (28, 20), (9, 17)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_rot_crow_{i}", x, z, "decor", "", "crow", when=RUINED)
    for i, (x, z) in enumerate([(21, 21), (19, 24), (22, 17)]):
        pass

    # --- the ground's own dress, always there: the Lockwoods' plot, the kitchen gardens, the barns' yard, the pond's edge
    for i, (x, z) in enumerate([(3, 6), (4, 7), (3, 9), (5, 8)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_grave_{i}", x, z, "decor", "", "gravestone")
    for i, (x, z) in enumerate([(3, 11), (4, 12), (6, 11), (6, 6), (7, 14), (3, 14), (2, 12)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_garden_{i}", x, z, "decor", "", "garden_bed")
    for i, (x, z) in enumerate([(32, 10), (35, 11), (33, 12), (36, 10), (32, 19)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_yard_{i}", x, z, "decor", "", ["hay_bale", "woodpile", "barrel", "handcart", "hay_bale"][i])
    for i, (x, z) in enumerate([(7, 22), (8, 21), (14, 21), (16, 24), (15, 29), (5, 27)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_reeds_{i}", x, z, "decor", "", "reeds")
    for i, (x, z) in enumerate([(26, 22), (30, 13), (6, 2), (17, 3), (36, 26), (13, 31), (24, 33), (30, 30)]):
        if open_cell(x, z, loose=True):
            pl.prop(f"estate_rock_{i}", x, z, "decor", "", "boulder")
    for i in range(12):
        x, z = rnd.randrange(2, EW - 2), rnd.randrange(2, EH - 2)
        if open_cell(x, z):
            pl.prop(f"estate_leaves_{i}", x, z, "decor", "", rnd.choice(["leaves", "leaves", "puddle"]))

    # --- trees: groves that hug the edges and the fence, never in a row (blue-noise placement, mixed kinds)
    groves = [(5, 5, 6, 4), (36, 26, 5, 6), (3, 31, 6, 4), (12, 2, 6, 2), (25, 2, 6, 2), (38, 18, 2, 3), (30, 31, 3, 3), (16, 33, 5, 2), (1, 16, 2, 4), (28, 24, 3, 2)]
    placed = []
    n = 0
    for (gx, gz, rx, rz) in groves:
        for _ in range(60):
            x = int(rnd.gauss(gx, rx * 0.55))
            z = int(rnd.gauss(gz, rz * 0.55))
            if not open_cell(x, z):
                continue
            if any((x - px) ** 2 + (z - pz) ** 2 < 5 for px, pz in placed):
                continue
            if cv.get(x, z) != ".":
                continue
            placed.append((x, z))
            model = rnd.choice(["pine_a", "pine_b", "pine_c", "dead_tree_a", "pine_a", "pine_b", "dead_tree_b"])
            pl.prop(f"estate_tree_{n:02d}", x, z, "decor", "", model, scale=round(rnd.uniform(0.9, 1.35), 2))
            n += 1
            if sum(1 for q in placed) > 70:
                break

    # lights: the porch light, the gate's lamps (the welcoming dress adds lanterns; the storm adds its own flashes)
    pl.light(20, 12, "lamp", 15, 30)
    pl.light(15, 12, "lamp", 10, 20)
    pl.light(26, 12, "lamp", 10, 20)
    pl.light(21, 27, "lamp", 10, 20)
    pl.light(14, 8, "window", 20, 40, "moonlight")
    pl.light(24, 8, "window", 20, 40, "moonlight")
    # areas
    pl.area("gate", "The gate", 17, 24, 25, 28, "dim")
    pl.area("manor_porch", "The wrap-around porch", 6, 8, 29, 14, "dim")
    pl.area("pond", "The pond", 4, 21, 17, 30, "dim")
    pl.area("kitchen_gardens", "The kitchen gardens", 2, 4, 9, 15, "dim")
    pl.area("farmyard", "The barns' yard", 29, 3, 38, 19, "dim")
    pl.area("hill_road", "The hill road", 21, 28, 36, 35, "dim")
    pl.area("dead_tree_corner", "The dead tree", 2, 2, 9, 6, "dim")
    check_models(pl)
    d = {"id": "druskenvald_estate", "name": "The Druskenvald Estate", "region": REGION,
         "summary": "The hilltop grounds above Wickermoor Village: a gate in a fence, the pond, two barns, the kitchen gardens, a dead tree in the north-west corner, and the three-storey manor behind its wrap-around porch. Welcoming on the first night; ruined once the house turns.",
         "text": "The hill road climbs to an open gate in an iron fence. Beyond it a pond lies black in a hollow, two barns lean together on a bench of level ground, and the house waits on the shoulder of the hill, its porch lit and every window warm. Its roofline is very slightly wrong.",
         "map": {"rows": ["".join(r) for r in rows], "elevation": elev, "theme": "village", "light": "dim", "outdoors": True},
         "areas": pl.areas, "spawns": pl.spawns, "exits": pl.exits, "props": pl.props, "lights": pl.lights,
         "rest": "no", "rest_text": REST_TEXT}
    return d


def estate_command(what, args):
    if what == "paint":
        cmd_paint(args[0] if args else "docs/plans/crooked_house")
    elif what == "dress":
        write("data/locations/druskenvald_estate.json", estate_data())
        print("dressed druskenvald_estate")


def cmd_preview(out_dir):
    """A picture of every map: squares by what they are, then props, doors, exits, spawns and traps over them."""
    from PIL import Image, ImageDraw
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    px = 24
    base = {"#": (50, 40, 36), " ": (0, 0, 0), ".": (190, 180, 150), "=": (150, 120, 80), "_": (160, 110, 60), "~": (110, 130, 80),
            "w": (40, 90, 170)}
    for pid in ("druskenvald_estate", "crooked_house_first", "crooked_house_second", "crooked_house_third", "crooked_house_attic"):
        f = ROOT / f"data/locations/{pid}.json"
        if not f.exists():
            continue
        d = json.load(open(f))
        rows = d["map"]["rows"]
        el = d["map"].get("elevation", [])
        w, h = len(rows[0]), len(rows)
        img = Image.new("RGB", (w * px, h * px), (0, 0, 0))
        dr = ImageDraw.Draw(img)
        for z, row in enumerate(rows):
            for x, ch in enumerate(row):
                col = base.get(ch, (190, 180, 150))
                if el and z < len(el) and x < len(el[z]) and el[z][x] in "0123456789abcdef" and ch in ".~=_":
                    lift = int(el[z][x], 16) / 9.0
                    col = tuple(min(255, int(c + 70 * lift)) for c in col)
                dr.rectangle((x * px, z * px, x * px + px - 2, z * px + px - 2), fill=col)
        for t in d.get("traps", []):
            for c in t["cells"]:
                dr.rectangle((c[0] * px, c[1] * px, c[0] * px + px - 2, c[1] * px + px - 2), outline=(255, 120, 0), width=2)
        for a in d.get("areas", []):
            (x0, z0), (x1, z1) = a["cells"]
            dr.rectangle((x0 * px, z0 * px, x1 * px + px - 2, z1 * px + px - 2), outline=(80, 200, 220))
        for p in d.get("props", []):
            x, z = p["cell"]
            sx, sz = p.get("span", [1, 1])
            col = (40, 80, 255) if not p["id"].split("_")[1:2] or "_d" not in p["id"] else (110, 110, 190)
            dr.rectangle((x * px + 3, z * px + 3, (x + sx) * px - 5, (z + sz) * px - 5), outline=col, width=2)
            if "_d0" not in p["id"] and "_d1" not in p["id"] and "chair" not in p["id"] and "teeth" not in p["id"] and "shelf_" not in p["id"]:
                dr.text((x * px + 2, z * px + 2), p["id"][:9], fill=(255, 255, 255))
        for c in d.get("containers", []):
            x, z = c["cell"]
            dr.ellipse((x * px + 4, z * px + 4, x * px + px - 6, z * px + px - 6), fill=(30, 200, 60))
        for dd in d.get("doors", []):
            x, z = dd["cell"]
            dr.rectangle((x * px + 2, z * px + 2, x * px + px - 4, z * px + px - 4), fill=(220, 40, 40))
        for e in d.get("exits", []):
            x, z = e["cell"]
            dr.rectangle((x * px + 1, z * px + 1, x * px + px - 3, z * px + px - 3), fill=(250, 220, 40))
            dr.text((x * px + 2, z * px + 2), "E", fill=(0, 0, 0))
        for n, c in d.get("spawns", {}).items():
            dr.ellipse((c[0] * px + 6, c[1] * px + 6, c[0] * px + px - 8, c[1] * px + px - 8), fill=(255, 0, 255))
        for l in d.get("lights", []):
            c = l["cell"]
            dr.ellipse((c[0] * px + 8, c[1] * px + 8, c[0] * px + px - 10, c[1] * px + px - 10), fill=(255, 255, 255))
        img.save(Path(out_dir) / f"{pid}.png")
        print("preview", pid, w, "x", h)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "floors"
    if what == "floors":
        cmd_floors()
    elif what == "preview":
        cmd_preview(sys.argv[2] if len(sys.argv) > 2 else "/tmp/r12prev")
    elif what in ("paint", "dress"):
        estate_command(what, sys.argv[2:])
    else:
        raise SystemExit(__doc__)
