#!/usr/bin/env python3
"""Writes Wickermoor Village (R11): the town (its map came from the sketch tool: docs/plans/wickermoor, make sketch), its rooms, its people,
the arrival quest and the flags. Run from the repo root after `make sketch ... LOC=data/locations/wickermoor_village.json`:
    python3 tools/content/build_wickermoor.py"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import ROOMS
from wickermoor_people import ADULTS, CHILDREN, EXTRAS

ROOT = Path(__file__).resolve().parents[2]
REGION = "wickermoor"
WM = "wickermoor/"


def write(rel, obj):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def prop(pid, cell, label=None, kind="examine", model=None, **kw):
    d = {"id": pid, "cell": list(cell), "kind": kind}
    if label:
        d["label"] = label
    if model:
        d["model"] = model
    d.update(kw)
    return d


def npc(npc_id, cell, dialogue=None, **kw):
    d = {"npc": npc_id, "cell": list(cell)}
    if dialogue:
        d["dialogue"] = WM + dialogue
    d.update(kw)
    return d


def area(aid, name, a, b, **kw):
    d = {"id": aid, "name": name, "cells": [list(a), list(b)]}
    d.update(kw)
    return d


def open_spread(rows, candidates, n):
    """The first n candidate squares that are open ground with open ground all round them and at least two squares apart."""
    out = []
    for (x, y) in candidates:
        ok = all(0 <= y + dy < len(rows) and 0 <= x + dx < len(rows[0]) and rows[y + dy][x + dx] in ".1234" for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        if ok and all(max(abs(x - a), abs(y - b)) >= 2 for (a, b) in out):
            out.append((x, y))
        if len(out) == n:
            break
    return out


# ---- the town: where each building's door is (a wall square) and the open square in front of it ---------------------------------
DOORS = {   # key: (door cell, outside spawn)
    "wickermoor_green_queen_inn": ((25, 30), (26, 30)), "wickermoor_trading_post": ((21, 23), (22, 23)),
    "wickermoor_mayors_house": ((38, 30), (37, 30)), "wickermoor_barber_shop": ((22, 16), (22, 17)),
    "wickermoor_constable_station": ((44, 16), (44, 17)), "wickermoor_post_office": ((34, 7), (34, 8)),
    "wickermoor_dovecote": ((43, 6), (43, 7)), "wickermoor_schoolhouse": ((6, 18), (6, 19)),
    "wickermoor_bookstore": ((13, 22), (13, 23)), "wickermoor_apothecary": ((10, 34), (10, 33)),
    "wickermoor_funeral_home": ((46, 39), (46, 38)),
    # the craft shops, one shell dressed seven ways
    "wickermoor_shop_bakery": ((34, 16), (34, 17)), "wickermoor_shop_tailor": ((28, 16), (28, 17)),
    "wickermoor_shop_smithy": ((5, 36), (6, 36)), "wickermoor_shop_wickery": ((16, 35), (16, 34)),
    "wickermoor_shop_butcher": ((10, 41), (10, 40)), "wickermoor_shop_masonry": ((51, 22), (50, 22)),
    "wickermoor_shop_carpentry": ((51, 27), (50, 27)),
}
LABEL = {
    "wickermoor_green_queen_inn": "The Green Queen Inn", "wickermoor_trading_post": "Tolliver's Trading Post", "wickermoor_mayors_house": "The Mayor's House",
    "wickermoor_barber_shop": "Graham's Barber Shop", "wickermoor_constable_station": "The Constable's Station", "wickermoor_post_office": "The Post Office",
    "wickermoor_dovecote": "The Dovecote", "wickermoor_schoolhouse": "The Schoolhouse", "wickermoor_bookstore": "The Antique Bookstore",
    "wickermoor_apothecary": "The Apothecary", "wickermoor_funeral_home": "Shade Funeral Home",
    "wickermoor_shop_bakery": "Bread by Holly", "wickermoor_shop_tailor": "A Stitch in Time", "wickermoor_shop_smithy": "The Smithy",
    "wickermoor_shop_wickery": "The Wickery", "wickermoor_shop_butcher": "Harga's Meats", "wickermoor_shop_masonry": "Roderick Masonry",
    "wickermoor_shop_carpentry": "The Carpentry Workshop",
}
# who stands inside each (npc, cell, dialogue file)
INSIDE = {
    "wickermoor_green_queen_inn": [("alda_farnum", (15, 9), "alda_farnum:start")],
    "wickermoor_mayors_house": [("wendel_somerton", (4, 15), "wendel_somerton:start"), ("myrtle_somerton", (20, 4), "myrtle_somerton:start"), ("rose_somerton", (6, 6), "children:rose")],
    "wickermoor_constable_station": [("doris_squire", (5, 11), "doris_squire:start"), ("howie_butterman", (15, 11), "howie_butterman:start")],
    "wickermoor_trading_post": [("baltus_tolliver", (10, 10), "baltus_tolliver:start"), ("wilma_wainwright", (4, 4), "wilma_wainwright:start"),
                                ("ronald_wainwright", (17, 4), "ronald_wainwright:start"), ("victoria_wainwright", (7, 6), "children:victoria"),
                                ("eddie_wainwright", (8, 6), "children:eddie"), ("zachariah_wainwright", (9, 6), "children:zachariah")],
    "wickermoor_apothecary": [("morgan", (4, 8), "morgan:start")],
    "wickermoor_barber_shop": [("randall_graham", (6, 5), "randall_graham:start")],
    "wickermoor_schoolhouse": [("finneas_trout", (7, 2), "finneas_trout:start")],
    "wickermoor_post_office": [("theodora_mayville", (7, 3), "theodora_mayville:start"), ("geneva_fairchild", (4, 9), "geneva_fairchild:start"),
                               ("peeping_albert", (13, 2), "peeping_albert:start")],
    "wickermoor_funeral_home": [("mori_shade", (9, 6), "mori_shade:start")],
    "wickermoor_bookstore": [("eleanor_heyling", (6, 5), "eleanor_heyling:start"), ("margery_heyling", (9, 5), "children:margery"),
                             ("algernon_heyling", (10, 5), "children:algernon"), ("sheridan_heyling", (4, 5), "children:sheridan")],
    "wickermoor_shop_bakery": [("holly_aster", (6, 5), "holly_aster:start"), ("violet_aster", (9, 8), "children:violet"), ("lavender_aster", (10, 8), "children:lavender")],
    "wickermoor_shop_tailor": [("thomasin_ardor", (6, 5), "thomasin_ardor:start")],
    "wickermoor_shop_smithy": [("jean_myriel", (6, 5), "jean_myriel:start")],
    "wickermoor_shop_wickery": [("oswick_frey", (6, 5), "oswick_frey:start")],
    "wickermoor_shop_butcher": [("siv_harga", (6, 5), "siv_harga:start"), ("mrs_oakum", (9, 5), "mrs_oakum:start"), ("ulf_harga", (3, 8), "children:ulf")],
    "wickermoor_shop_masonry": [("solomon_roderick", (6, 5), "solomon_roderick:start"), ("sofia_roderick", (9, 8), "children:sofia")],
    "wickermoor_shop_carpentry": [("beatrice_wells", (6, 5), "beatrice_wells:start"), ("branden_wells", (9, 5), "branden_wells:start"),
                                  ("robin_wells", (3, 8), "children:robin"), ("lark_wells", (4, 8), "children:lark"), ("jay_wells", (10, 8), "children:jay"),
                                  ("wren_wells", (11, 8), "children:wren")],
}


# Opening hours by the Hollow's named hours (Twilight 07, Dusk 11, Nightfall 15, Evening 19, Midnight 23, Witching 03): the bakery
# Twilight to the start of Nightfall, the mayor's office Twilight through Nightfall, most shops shut from the Evening Hour (the book's
# tables). Mrs. Oakum leaves every Evening Hour. Whoever is not listed keeps their place all night: the inn, the constable, the funeral home.
HOURS = {"holly_aster": [7, 15], "violet_aster": [7, 15], "lavender_aster": [7, 15], "finneas_trout": [7, 15],
         "wendel_somerton": [7, 19], "myrtle_somerton": [7, 19], "rose_somerton": [7, 19], "mrs_oakum": [7, 19]}
for _n in ("baltus_tolliver", "jean_myriel", "oswick_frey", "thomasin_ardor", "siv_harga", "ulf_harga", "solomon_roderick", "sofia_roderick", "beatrice_wells",
           "branden_wells", "eleanor_heyling", "randall_graham"):
    HOURS[_n] = [7, 19]


def room_location(key, spec):
    rows = spec["rows"]
    w, h = len(rows[0]), len(rows)
    loc = {"id": key, "name": LABEL.get(key, spec["name"]), "region": REGION, "summary": f"{LABEL.get(key, spec['name'])}, a room of Wickermoor Village.",
           "text": f"The inside of {LABEL.get(key, spec['name'])}: candle-lit, close and creaking.",
           "map": {"rows": rows, "theme": "tavern" if "inn" in key else "manor", "light": "dim", "outdoors": False},
           "areas": [{"id": "room", "name": LABEL.get(key, spec["name"]), "cells": [[1, 1], [w - 2, h - 2]]}],
           "spawns": {"default": list(spec["spawn"])}, "exits": [], "props": [], "npcs": [], "rest": "risky"}
    if "inn" in key:
        loc["rest"] = "safe"
    return loc


def add_exit(loc, eid, cell, to, spawn, label, **kw):
    e = {"id": eid, "cell": list(cell), "to": to, "spawn": spawn, "label": label}
    e.update(kw)
    loc["exits"].append(e)


def near_open(rows, cell):
    x, y = cell
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)):
        nx, ny = x + dx, y + dy
        if 0 <= ny < len(rows) and 0 <= nx < len(rows[ny]) and rows[ny][nx] in ".~":
            return [nx, ny]
    return [x, y]


def build_rooms(town_rows):
    rooms = {}
    for key, fn in ROOMS.items():
        spec = fn()
        rooms[key] = (spec, room_location(key, spec))
    # the seven craft shops from one shell
    for key in [k for k in DOORS if k.startswith("wickermoor_shop_")]:
        spec = ROOMS["wickermoor_bookstore"]() if False else __import__("wickermoor_interiors").small_shop()
        spec["name"] = LABEL[key]
        rooms[key] = (spec, room_location(key, spec))
    for key, (spec, loc) in rooms.items():
        # the way out onto the town
        if key in DOORS:
            _, outside = DOORS[key]
            add_exit(loc, "door", spec["door"], "wickermoor_village", "from_" + key[len("wickermoor_"):], "Out to the village")
        for (eid, cell, to, sp, label) in spec.get("extra_exits", []):
            if eid in ("dovecote_stair", "cellar"):
                continue
            add_exit(loc, eid, cell, to, sp, label)
        if "exits_to" in spec:
            eid, cell, to, sp = spec["exits_to"]
            add_exit(loc, eid, cell, to, sp, "Stairs down")
        if "door_to" in spec:
            to, sp, label = spec["door_to"]
            add_exit(loc, "door", spec["door"], to, sp, label)
    # named spawns: a back door's arrival square is the open square beside the exit that returns
    for key, (spec, loc) in rooms.items():
        for e in loc["exits"]:
            dest = rooms.get(e["to"])
            if dest:
                back = [x for x in dest[1]["exits"] if x["to"] == key]
                dest[1]["spawns"].setdefault(e["spawn"], near_open(dest[1]["map"]["rows"], back[0]["cell"]) if back else dest[1]["spawns"]["default"])
    return rooms


# a few things to look at in each room: (id suffix, cell, label, model); the cells are squares the room leaves open or the furniture's own
DRESS = {
    "wickermoor_green_queen_inn": [("bar", (16, 10), "The bar", "bar"), ("hearth", (3, 10), "The taproom hearth", "hearth"), ("stage", (23, 3), "The little stage", "dais"),
                                   ("kitchen", (4, 3), "The kitchen counters", "cupboard"), ("rumour_board", (12, 19), "A board of rumours", "notice_board")],
    "wickermoor_green_queen_inn_upper": [("ledger", (22, 9), "A ledger of favours", "ledger"), ("window", (28, 1), "A window onto the Round", "window")],
    "wickermoor_mayors_house": [("forms", (5, 14), "Forms in baskets and boxes", "papers"), ("desk", (22, 15), "The mayor's desk", "table_round"), ("portrait", (3, 3), "A portrait of the founder, face turned to the wall", "book")],
    "wickermoor_clock_chamber": [("works", (5, 5), "The clock's works", "case")],
    "wickermoor_constable_station": [("board", (3, 3), "The notice board", "notice_board"), ("stove", (17, 3), "The stove and kettle", "hearth"), ("cell_a", (3, 6), "A barred cell", "barred_door"), ("cell_b", (9, 6), "A barred cell", "barred_door"), ("cell_c", (15, 6), "A barred cell", "barred_door")],
    "wickermoor_trading_post": [("shelves", (4, 3), "Shelves of staples", "shelves"), ("oddities", (14, 3), "A cabinet of oddities", "case"), ("counter", (10, 11), "The counter", "table_round")],
    "wickermoor_apothecary": [("alembic", (11, 3), "A bubbling alembic", "case"), ("jars", (3, 2), "Jars and drying bundles", "shelves"), ("table", (3, 9), "A cleared workbench", "table_round")],
    "wickermoor_barber_shop": [("chair_one", (3, 3), "The first barber's chair", "chair"), ("chair_two", (8, 3), "The second barber's chair", "chair"), ("still", (11, 2), "A still, gurgling", "case"), ("broom", (2, 7), "A broom, carefully leaned", "rope")],
    "wickermoor_schoolhouse": [("map", (7, 1), "A hand-lettered map of the Hollow", "papers"), ("desks", (4, 3), "Small desks", "table_round")],
    "wickermoor_post_office": [("pigeonholes", (4, 4), "Pigeonholes and parcels", "shelves"), ("rafters", (12, 1), "The rafters", "crow")],
    "wickermoor_dovecote": [("coops", (3, 3), "Stacked coops", "cage"), ("perches", (8, 3), "Perches thick with feathers", "crow")],
    "wickermoor_funeral_home": [("coffins", (4, 2), "A row of coffins", "case"), ("lectern", (12, 2), "A lectern", "book")],
    "wickermoor_bookstore": [("stacks", (3, 2), "Narrow aisles of books", "bookcase"), ("ladder", (10, 4), "A rolling ladder", "bookcase"), ("writing", (4, 9), "A table of pens and paper", "table_round")],
}



# what each room's thing says when it is looked at (our words; a prop with no Narrator line shows this)
TEXT = {
    "green_queen_inn_bar": "The bar is a single plank of black oak, its edge worn pale where a hundred years of elbows have rested.",
    "green_queen_inn_hearth": "A fire of split oak burns low in the taproom hearth, and the stone above it is blackened to the beams.",
    "green_queen_inn_stage": "A little stage of scrubbed planks, its curtain drawn back on a painted forest that has been touched up often.",
    "green_queen_inn_kitchen": "Copper pots, a block of salt and a ham on a hook: the kitchen counters are always one order behind.",
    "green_queen_inn_rumour_board": "Scraps of paper pinned to the board, each with a rumour scrawled on it in a different hand.",
    "green_queen_inn_upper_ledger": "A ledger bound in green cloth, columns of names and favours owed, and beside many of them a small inked hare.",
    "green_queen_inn_upper_window": "From the window you see the whole Round, the oak a dark knot in its middle.",
    "mayors_house_forms": "Forms in baskets, forms in boxes, forms in neat rubber-banded stacks, and not one of them blank.",
    "mayors_house_desk": "The mayor's desk holds a blotter, an oak-leaf seal and an inkwell shaped like a small acorn.",
    "mayors_house_portrait": "A portrait of the founder hangs with its face turned to the wall, as though someone had been told off.",
    "clock_chamber_works": "Brass wheels and a great slow pendulum; the whole room breathes with it and nothing here is in a hurry.",
    "constable_station_board": "Wanted notices gone yellow at the corners and a hand-drawn map of the village with several houses crossed out.",
    "constable_station_stove": "A kettle simmers on a stove that smells of peat, and a tin mug waits beside it.",
    "constable_station_cell_a": "An empty cell: a plank bed, a bucket, and the word SORRY scratched into the wall a great many times.",
    "constable_station_cell_b": "A cell with a folded blanket on its bed and a bowl of cold porridge that nobody has collected.",
    "constable_station_cell_c": "A cell with iron bars worn bright where hands have held them, and a window too high to look out of.",
    "trading_post_shelves": "Shelves of staples with their prices chalked on tags, and a ledger of what the post has been asked to find.",
    "trading_post_oddities": "A glass cabinet of oddities from far valleys: a bird's skull in amber, a key with no lock, a coin with two heads.",
    "trading_post_counter": "The counter is spotless. Not a ring, not a crumb, and not a fingerprint on the brass scale.",
    "apothecary_alembic": "An alembic bubbles over a small flame, dripping something the colour of weak tea into a flask.",
    "apothecary_jars": "Jars of dried herbs with hand-written labels, and bundles of drying flowers hung head-down from the beams.",
    "apothecary_table": "A cleared workbench with a mortar and pestle, scrubbed so clean it looks unused.",
    "barber_shop_chair_one": "A leather chair, cracked at the arms and warm as if someone had only just stood up.",
    "barber_shop_chair_two": "A second leather chair, and on its wooden arm a tiny antlered hare, knifed neatly into the grain.",
    "barber_shop_still": "A copper still gurgles in the corner; the air round it smells sharp and sweet, like an apple that has been struck.",
    "barber_shop_broom": "A broom leaned against the wall with great care, its bristles clipped short and clean, while the floor is swept to the last hair.",
    "schoolhouse_map": "A hand-lettered map of the Hollow, marked in pencil with a great many question marks.",
    "schoolhouse_desks": "Small desks, their lids carved with initials and one with a very good drawing of a pig.",
    "post_office_pigeonholes": "Pigeonholes crammed with parcels and letters, some of which have been opened and sealed again.",
    "post_office_rafters": "Up among the rafters a pigeon watches you with an eye that is a little too thoughtful.",
    "dovecote_coops": "Stacked coops of wicker and wire, some of them occupied, all of them quiet.",
    "dovecote_perches": "Perches thick with feathers and droppings, and a faint warm smell of grain.",
    "funeral_home_coffins": "A row of coffins, their lids polished to a mirror shine, each fitted for someone not yet dead.",
    "funeral_home_lectern": "A lectern with a book of the departed, open to a page that lists tonight's date and no name.",
    "bookstore_stacks": "Narrow aisles of old paper; the books lean on one another like tired neighbours.",
    "bookstore_ladder": "A rolling ladder, worn smooth by a reader who climbs it more often than she eats.",
    "bookstore_writing": "A table of pens, ink and thick paper, laid out as if for a letter the writer has not yet decided to send.",
}


def dress(key, loc):
    for (suffix, cell, label, model) in DRESS.get(key, []):
        pid = f"{key[len('wickermoor_'):]}_{suffix}"
        extra = {"dialogue": WM + "rumours:r01"} if suffix == "rumour_board" else {}
        if pid in TEXT:
            extra["text"] = TEXT[pid]
        loc["props"].append(prop(pid, cell, label, model=model, **extra))
    w = len(loc["map"]["rows"][0])
    h = len(loc["map"]["rows"])
    loc["lights"] = [{"cell": [max(2, w // 4), max(2, h // 3)], "kind": "candle", "bright_ft": 15, "dim_ft": 30, "color": "candle"},
                     {"cell": [min(w - 3, 3 * w // 4), max(2, h // 3)], "kind": "candle", "bright_ft": 15, "dim_ft": 30, "color": "candle"}]


# ---- the town ---------------------------------------------------------------------------------------------------------------------
def build_town():
    p = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(p.read_text())
    rows = town["map"]["rows"]
    town["areas"] = [
        area("wm_round", "The Founder's Round", (23, 17), (37, 31)),
        area("wm_north", "The north row", (19, 8), (49, 17)),
        area("wm_moor_road", "The moor road", (16, 0), (50, 7)),
        area("wm_estate_hill", "The estate's hill", (1, 1), (15, 11)),
        area("wm_west", "The west quarter", (2, 12), (15, 33)),
        area("wm_southwest", "The south-west lanes", (2, 34), (27, 45)),
        area("wm_east", "The east side", (48, 17), (58, 32)),
        area("wm_south", "The south side", (28, 35), (50, 46)),
        area("wm_river", "The Silverbell's bank", (0, 45), (59, 49)),
    ]
    town["spawns"] = {"default": [6, 21], "from_wreck": [6, 21], "from_moor": [30, 2], "from_bridge": [30, 45], "from_estate": [14, 11]}
    town["exits"] = []
    for key, (door, outside) in DOORS.items():
        town["spawns"]["from_" + key[len("wickermoor_"):]] = list(outside)
        add_exit(town, key[len("wickermoor_"):], door, key, "door", "Enter " + LABEL[key])
        if key == "wickermoor_green_queen_inn":   # reaching the inn is what the parting asks for
            town["exits"][-1]["sets_quest"] = {"id": "wickermoor_arrival", "stage": "free_roam", "from": ["parting"]}
    town["spawns"]["from_inn_yard"] = [24, 34]
    town["exits"] = [e for e in town["exits"]]
    for e in town["exits"]:
        e["spawn"] = "default"
    town["exits"] += [
        {"id": "road_to_estate", "cell": [14, 10], "to": "travel", "label": "Up the hill to the estate", "when": "flag.wm_welcomed",
         "sets_quest": {"id": "wickermoor_arrival", "stage": "dinner", "from": ["parting", "free_roam"]}},
        {"id": "moor_road", "cell": [30, 1], "to": "travel", "label": "The moor road"},
        {"id": "south_bridge", "cell": [30, 47], "to": "travel", "label": "The footbridge south"},
    ]
    town["props"] = [
        prop("wm_statue", (30, 19), "The Founder's statue", model="statue_headless"),
        prop("wm_oak", (30, 29), "The Oak of Many Faces", model="tree_marked", span=[2, 2]),
        prop("wm_oak_roots", (28, 31), "The oak's roots", kind="decor"),
        prop("wm_clocktower", (45, 28), "The clocktower", span=[2, 2]),
        prop("wm_pavilion", (17, 10), "The pavilion", model="gate"),
        prop("wm_inn_sign", (24, 26), "The Green Queen's sign", model="sign"),
        prop("wm_notice_board", (36, 25), "The notice board", model="notice_board"),
        prop("wm_well", (22, 19), "The well", model="well_stone"),
        prop("wm_bonfire", (55, 14), "A bone bonfire, banked", kind="decor"),
        prop("wm_hare_effigy", (12, 14), "A wicker hare", model="scarecrow"),
        prop("wm_turnip_1", (27, 17), "A carved turnip over a door", kind="decor"),
        prop("wm_turnip_2", (33, 17), "A carved turnip over a door", kind="decor"),
        prop("wm_stable_horse", (22, 42), "The stable's horses", model="horse"),
        prop("wm_cart", (36, 21), "A farm cart", model="cart"),
        prop("wm_graves", (46, 37), "Plots of the dead", model="grave"),
        prop("wm_pyethymer_gate", (55, 41), "The chained gate", model="gate"),
        prop("wm_sacrifice_doll", (30, 27), "A bound shape on a stake", kind="decor", when="not flag.wm_first_sacrifice_done"),
        prop("wm_church_ruin", (7, 27), "The abandoned church"),
        prop("wm_man_in_marble", (8, 24), "A scowling marble knight", model="statue_headless"),
    ]
    town["npcs"] = [
        npc("old_rusty", (28, 24), "old_rusty:start", path=[[28, 24], [32, 23], [31, 26]], pause=4),
        npc("sister_rain", (33, 23), "sister_rain:start", facing="west"),
        npc("jeremiah_stover", (37, 22), "jeremiah_stover:start"),
        npc("gaston_doray", (19, 15), "gaston_doray:start"),
        npc("hilda_brom", (48, 28), "hilda_brom:start"),
        npc("weston_murdoch", (7, 30), "weston_murdoch:start"), npc("joan_murdoch", (4, 27), "joan_murdoch:start"),
        npc("peter_murdoch", (11, 26), "children:peter"), npc("charlotte_murdoch", (11, 28), "children:charlotte"),
        npc("marianna_grey", (23, 37), "marianna_grey:start"), npc("dani_jenkin", (15, 12), "children:dani"),
        npc("mayor_arrival", (36, 28), None) if False else None,
    ]
    town["npcs"] = [n for n in town["npcs"] if n]
    for pr in town["props"]:      # the scenes start from things that are really there: the well as the party comes in, the notice board once the Round is quiet
        if pr["id"] == "wm_well":
            pr.update(call=WM + "arrival:start", approach=12, call_when="not flag.wm_first_sacrifice_done and not flag.wm_welcomed")
        if pr["id"] == "wm_notice_board":
            pr.update(call=WM + "mayor_welcome:start", approach=12, call_when="flag.wm_first_sacrifice_done and not flag.wm_welcomed")
    town["rest"] = "risky"
    town["rest_text"] = "The village sleeps with one eye open."
    wolf_cells = open_spread(rows, [(49, 24), (46, 20), (47, 25), (44, 23), (49, 19), (45, 27), (50, 22), (43, 21), (48, 26), (51, 25), (46, 23), (44, 19), (41, 24), (42, 27), (47, 18), (43, 25), (40, 21), (45, 21), (49, 21), (47, 22)], 7)
    town["encounters"] = [
        {"id": "wm_first_sacrifice", "trigger": "dialogue", "flag": "wm_first_sacrifice_done", "quest": {"id": "wickermoor_arrival", "stage": "welcome"},
         "monsters": [{"monster": "wolf", "cell": list(c), "name": "A hungry wolf", "facing": "west"} for c in wolf_cells[1:]] +
                    [{"monster": "dire_wolf", "cell": list(wolf_cells[0]), "name": "The pack leader", "facing": "west"}]},
    ]
    write("data/locations/wickermoor_village.json", town)
    return town


SHOPS = {   # npc: what the shop sells (engine item ids); markup 1.0 unless said
    "baltus_tolliver": ["backpack", "rope", "torch", "ration", "tinderbox", "hooded_lantern", "oil", "waterskin", "bedroll", "crowbar", "hunting_trap", "shovel", "dagger", "handaxe", "spear", "light_crossbow", "crossbow_bolt", "shortbow", "arrow", "shield", "leather_armor", "explorers_pack"],
    "morgan": ["potion_of_healing", "antitoxin", "healers_kit", "herbalism_kit", "vial", "holy_water"],
    "jean_myriel": ["dagger", "handaxe", "mace", "spear", "shortsword", "light_hammer", "sickle", "chain_shirt", "shield", "iron_spike", "caltrops"],
    "oswick_frey": ["candle", "lamp", "torch", "hooded_lantern", "oil", "tinderbox"],
    "siv_harga": ["ration"],
    "holly_aster": ["ration", "goodberry"],
    "thomasin_ardor": ["travelers_clothes", "fine_clothes", "costume", "robe", "blanket"],
    "eleanor_heyling": ["book", "paper", "parchment", "ink", "ink_pen", "map", "map_or_scroll_case", "spellbook", "magnifying_glass"],
    "hilda_brom": ["ration", "hunting_trap", "net", "shortbow", "arrow", "leather_armor", "hide_armor"],
    "beatrice_wells": ["ladder", "pole", "chest", "barrel", "bucket", "carpenters_tools", "club", "quarterstaff"],
}
SERVICES = {
    "alda_farnum": [{"id": "room_modest", "price": 1}, {"id": "room_wealthy", "price": 2}],
    "randall_graham": [{"id": "cure_wounds", "price": 10}],
    "weston_murdoch": [{"id": "cure_wounds", "price": 0}],
}


def build_people():
    for (nid, name, title, faction, where, summary, voice) in ADULTS:
        d = {"id": nid, "name": name, "title": title, "summary": summary, "attitude": "friendly", "sprite": "villager", "region": REGION,
             "tags": [f"faction_{faction}", f"voice_{voice}"]}
        if nid in SHOPS:
            d["shop"] = {"sells": [{"id": i} for i in SHOPS[nid]], "markup": 1.0, "sell_rate": 0.5}
        if nid == "morgan":   # the Paranormal Potions (tools/content/build_potions.py)
            d["shop"]["magic"] = ["lilypad_tonic", "jinxed_rum", "silence_of_the_drowned", "elixir_of_fogwalking", "harvest_brew", "nightwatcher_potion",
                                  "sight_of_sin", "tincture_of_mourning", "wytchwood_sap", "nectar_of_the_green_man", "draught_of_the_red_hunger", "haint_hooch"]
        if nid in SERVICES:
            d["services"] = SERVICES[nid]
        write(f"data/npcs/{nid}.json", d)
    for (nid, name, who) in CHILDREN:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": who[0].upper() + who[1:], "summary": f"{name}, {who}.", "attitude": "friendly", "sprite": "villager",
                                          "region": REGION, "tags": ["child", "voice_hollow"]})
    for (nid, name, title, summary) in EXTRAS:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": "indifferent", "sprite": "villager", "region": REGION})


def stage(sid, journal, hint=None, objectives=None, ends=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    return d


def build_quests():
    write("data/quests/wickermoor_arrival.json", {
        "id": "wickermoor_arrival", "name": "Wickermoor Village", "kind": "main", "region": REGION, "giver": "wendel_somerton",
        "summary": "Walk the Druskenvalds into Wickermoor, and see what the village does with strangers.",
        "stages": [
            stage("first_sacrifice", "We walked the Lord and Lady to Wickermoor Village through woods and moor. The streets were empty, the clocktower was tolling, and a bound shape was staked beside an oak of carved faces. Wolves were coming.",
                  "Stand in the Founder's Round and see what is staked beside the oak.", ["Reach the Round"]),
            stage("welcome", "The wolves are dealt with, one way or another. The mayor has come out to greet Lord Phillip, and is full of apologies for the interruption.",
                  "Hear the mayor out in the Round.", ["Speak with Mayor Somerton"]),
            stage("parting", "Phillip has tired of the evening. He gave us gold for the inn and a promise of dinner at the estate tomorrow night.", "Find the Green Queen Inn and take a room.", ["Reach the Green Queen Inn"]),
            stage("free_roam", "Wickermoor is ours to walk. The estate on its hill is waiting for dinner whenever we choose to climb to it.",
                  "Meet the villagers; when you are ready, take the road up to the estate.", ["Meet the people of Wickermoor", "Dine at the Druskenvald estate"]),
            stage("dinner", "We climbed the hill to the Druskenvald estate.", ends="success"),
        ]})


FLAGS = [
    ("wm_first_sacrifice_done", "bool", "The first sacrifice in the Round has played out (the wolves are dealt with or the goat is gone)."),
    ("wm_welcomed", "bool", "The mayor has welcomed Lord Phillip and the party; the way up to the estate opens."),
    ("goat_fate", "string", "What became of the goat in the doll: `eaten`, `freed`, `caught` or `freed_eaten`."),
    ("old_ways_offended", "bool", "The party spoiled the Old Ways' rite (read by village attitude, the mob in chapter 20, and the cultists at Rowan's Rise)."),
    ("mayor_admitted_troubles", "bool", "The mayor owned up to more disappearances, sickness and deaths than usual."),
    ("phillip_uneasy_noticed", "bool", "The party noticed Phillip was uneasy, not just tired."),
    ("wm_doll_inspected", "bool", "The party took its one close look at the staked doll."),
]


def build_flags():
    met = [{"id": f"{n[0]}_met", "type": "bool", "summary": f"The party has spoken with {n[1]}.", "read_later": True} for n in ADULTS] + [{"id": f"{e[0]}_met", "type": "bool", "summary": f"The party has met {e[1]}.", "read_later": True} for e in EXTRAS]
    write("data/flags/wickermoor.json", {"flags": met + [{"id": i, "type": t, "summary": s, **({"read_later": True} if i in ("old_ways_offended", "phillip_uneasy_noticed", "goat_fate") else {})} for (i, t, s) in FLAGS]})


if __name__ == "__main__":
    town = build_town()
    rooms = build_rooms(town["map"]["rows"])
    for key, (spec, loc) in rooms.items():
        for (nid, cell, dlg) in INSIDE.get(key, []):
            loc["npcs"].append(npc(nid, cell, dlg, **({"hours": HOURS[nid]} if nid in HOURS else {})))
        dress(key, loc)
        write(f"data/locations/{key}.json", loc)
    build_people()
    build_quests()
    build_flags()
    print("ok", len(rooms), "rooms")
