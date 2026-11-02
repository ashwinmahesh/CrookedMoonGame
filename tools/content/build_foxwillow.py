#!/usr/bin/env python3
"""ONE-SHOT (R13, Fields of the Crow). Writes Foxwillow: the town (its map came from tools/content/foxwillow_sketch.py + `make sketch`), its six small
rooms, the windmill and its cellar, the corn maze (three junctions, three dead ends, the Circle of Secrets), its people, quests, flags, items,
the new monsters and Raum's phases, and the travel place. Other lanes edit these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_foxwillow.py"""
import copy, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G
from heirlooms_kept import kept

ROOT = Path(__file__).resolve().parents[2]
REGION = "foxwillow"
FW = "foxwillow/"


def write(rel, obj):
    if kept(rel):
        return
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


def prop(pid, cell, label=None, kind="examine", model=None, **kw):
    d = {"id": pid, "cell": list(cell), "kind": kind}
    if label:
        d["label"] = label
    if model:
        d["model"] = model
    d.update(kw)
    return d


def npc(nid, cell, dialogue=None, **kw):
    d = {"npc": nid, "cell": list(cell)}
    if dialogue:
        d["dialogue"] = FW + dialogue
    d.update(kw)
    return d


def area(aid, name, a, b, **kw):
    d = {"id": aid, "name": name, "cells": [list(a), list(b)]}
    d.update(kw)
    return d


def exit_(eid, cell, to, spawn, label, **kw):
    d = {"id": eid, "cell": list(cell), "to": to, "spawn": spawn, "label": label}
    d.update(kw)
    return d


def monster(mid, cell, name=None, **kw):
    d = {"monster": mid, "cell": list(cell)}
    if name:
        d["name"] = name
    d.update(kw)
    return d


# ---- the town ---------------------------------------------------------------------------------------------------------------------
DOORS = {   # room key: (door cell on the building's wall, the open square outside)
    "fw_schoolhouse": ((24, 18), (24, 19)), "fw_lantern": ((34, 18), (34, 19)), "fw_store": ((41, 20), (40, 20)),
    "fw_butcher": ((45, 29), (45, 28)), "fw_library": ((18, 25), (19, 25)), "fw_hall": ((28, 33), (28, 32)),
    "fw_windmill": ((11, 44), (11, 45)),
}
LABEL = {"fw_schoolhouse": "The Schoolhouse", "fw_lantern": "The Hooded Lantern", "fw_store": "The General Store", "fw_butcher": "The Butcher's",
         "fw_library": "The Library", "fw_hall": "The Town Hall", "fw_windmill": "The Windmill", "fw_windmill_cellar": "The Windmill's Cellar",
         "fw_maze_j1": "The First Clearing", "fw_maze_j2": "The Second Clearing", "fw_maze_j3": "The Third Clearing",
         "fw_maze_dead1": "A Dead End of Black Stalks", "fw_maze_dead2": "A Dead End of Black Stalks", "fw_maze_dead3": "A Dead End of Black Stalks",
         "fw_circle": "The Circle of Secrets"}


def build_town():
    town = read("data/locations/foxwillow.json")
    town.update({
        "name": "Foxwillow", "region": REGION,
        "summary": "A farming town in flames, with a stone flock of magpies in its square and a windmill on a bluff.",
        "text": "Foxwillow burns. Scarecrows with pumpkin heads brawl in Magpie Square, the windmill on its bluff is a wheel of fire, and past the east fields a wall of corn stands taller than any corn should.",
        "areas": [
            area("fw_square", "Magpie Square", (28, 22), (40, 28)),
            area("fw_school_yard", "The schoolyard", (21, 12), (28, 21)),
            area("fw_north", "The north lanes", (20, 0), (50, 11)),
            area("fw_farm", "The Langtree farm", (48, 4), (59, 14)),
            area("fw_butcher_pens", "The butcher's pens", (41, 28), (49, 37)),
            area("fw_mill_bluff", "The mill bluff", (1, 36), (16, 54)),
            area("fw_creek", "Foxwillow Creek", (17, 30), (30, 55)),
            area("fw_east_fields", "The east fields", (50, 15), (62, 55)),
            area("fw_corn_wall", "The corn wall", (58, 22), (63, 33)),
        ],
        "spawns": {"default": [3, 21], "from_road": [3, 21], "from_corn": [60, 28],
                   **{"from_" + k: list(v[1]) for k, v in DOORS.items()}},
        "exits": [exit_(k[3:], v[0], k, "default", "Enter " + LABEL[k]) for k, v in DOORS.items()] + [
            exit_("road_west", (0, 21), "travel", "default", "The road back to Wickermoor"),
            exit_("into_the_corn", (63, 28), "fw_maze_j1", "default", "Into the corn", when="flag.maze_open"),
        ],
        "props": [
            prop("fw_pump", (25, 26), "The town pump", model="well_stone"),
            prop("fw_magpies", (34, 25), "The stone flock of magpies", kind="decor", model="statue_headless"),
            prop("fw_notice_board", (33, 29), "The notice board", model="notice_board"),
            prop("fw_cart", (39, 27), "William's cart", model="cart"),
            prop("fw_scarecrow_a", (30, 26), "Two scarecrows, swinging", model="scarecrow", dialogue=FW + "extras:brawl_a"),
            prop("fw_scarecrow_b", (38, 23), "A scarecrow with a pitchfork", model="scarecrow", dialogue=FW + "extras:brawl_b"),
            prop("fw_scarecrow_c", (22, 24), "A pumpkin head at the pump", model="scarecrow", dialogue=FW + "extras:brawl_c"),
            prop("fw_field_scarecrow", (54, 24), "A field scarecrow in a bonnet", model="scarecrow", kind="decor"),
            prop("fw_hay", (52, 21), "A burning hay stook", kind="decor", burning="not flag.raum_slain"),
            prop("fw_gate_eyes", (60, 28), "The corn wall", model="gate", call=FW + "gate:start", approach=10,
                 call_when="flag.fw_investigated and not flag.maze_open"),
            prop("fw_burning_arrival", (6, 21), "The ridge road, and the town below", kind="decor",
                 call=FW + "arrival:start", approach=12, call_when="not flag.fw_arrived"),
            prop("fw_homecoming", (58, 28), "The corn wall, ordinary again", kind="decor", call=FW + "raum:coming_home", approach=12, call_when="flag.jericho_at_rest and not flag.fw_home"),
            prop("fw_mill_yard", (11, 45), "The mill yard gate", kind="decor", call=FW + "arrival:martha_plea", approach=10,
                 call_when="flag.fw_arrived and not flag.fw_mill_asked"),
        ],
        "npcs": [
            npc("william_lodge", (5, 22), "townsfolk:william_secret", when="flag.foxwillow_asked and flag.fw_arrived and not flag.secret_william"),
            npc("martha_langtree", (12, 45), "arrival:martha_plea", when="not flag.fw_mill_asked"),
            npc("martha_langtree", (30, 31), "townsfolk:martha_after", when="flag.fw_mill_asked"),
            npc("jonah_sawyer", (31, 31), "windmill:jonah_rescued", when="flag.jonah_saved and not flag.maze_open"),
        ],
        "encounters": [],
        "rest": "risky", "rest_text": "Embers drift across the square, and the scarecrows never quite stop.",
    })
    # three small brawls, each started only when a hero steps in (the extras conversation says `combat`)
    for tag, cells in (("a", [(29, 25), (31, 27), (30, 28)]), ("b", [(37, 22), (39, 24), (38, 25)]), ("c", [(21, 23), (23, 25)])):
        town["encounters"].append({"id": f"fw_brawl_{tag}", "trigger": "dialogue", "flag": f"fw_brawl_{tag}_done",
            "monsters": [monster("pumpkin_head", c, "A brawling scarecrow", facing="west") for c in cells]})
    write("data/locations/foxwillow.json", town)
    return town


# ---- rooms ------------------------------------------------------------------------------------------------------------------------
def small(w, h, door_x):
    g = G(w, h).room(1, 1, w - 2, h - 2)
    return g, (door_x, h - 1), (door_x, h - 2)


def room_defs():
    out = {}
    g, door, spawn = small(16, 12, 8)
    g.fill(2, 2, 13, 2, "=").put([(3, 5), (4, 5), (6, 5), (7, 5), (9, 5), (10, 5), (12, 5), (13, 5), (3, 8), (4, 8), (6, 8), (7, 8), (9, 8), (10, 8), (12, 8), (13, 8)], "=")
    out["fw_schoolhouse"] = dict(rows=g.rows(), door=door, spawn=spawn, dress=[
        ("chalk", (8, 1), "The chalkboard", "papers", "townsfolk:school_chalk"), ("desk_row", (5, 5), "Twenty small desks, twenty small scarecrows", "table_round", None)])
    g, door, spawn = small(18, 12, 9)
    g.fill(2, 2, 15, 2, "=").put([(3, 6), (4, 6), (8, 6), (9, 6), (13, 6), (14, 6)], "=")
    out["fw_lantern"] = dict(rows=g.rows(), door=door, spawn=spawn, dress=[
        ("counter", (9, 4), "The counter, and a loose board", "table_round", "townsfolk:lantern_cache"), ("hearth", (2, 1), "The cold hearth", "hearth", None)])
    g, door, spawn = small(16, 12, 8)
    g.fill(2, 2, 13, 2, "=").put([(3, 6), (4, 6), (11, 6), (12, 6)], "=")
    out["fw_store"] = dict(rows=g.rows(), door=door, spawn=spawn, dress=[
        ("rubble", (13, 3), "Burning rubble and a banjo's neck", "rocks", "townsfolk:store_banjo"), ("shelves", (3, 1), "Shelves of staples", "shelves", None)])
    g, door, spawn = small(16, 12, 8)
    g.fill(2, 2, 13, 2, "=").put([(3, 6), (4, 6), (11, 6), (12, 6)], "=")
    out["fw_butcher"] = dict(rows=g.rows(), door=door, spawn=spawn, dress=[
        ("circle", (8, 8), "A hex circle drawn in red chalk", "rags", "townsfolk:butcher_circle"), ("block", (4, 4), "The chopping block", "table_round", None)])
    g, door, spawn = small(18, 14, 9)
    g.fill(2, 2, 15, 2, "=").fill(2, 5, 6, 5, "=").fill(11, 5, 15, 5, "=").fill(2, 8, 6, 8, "=").fill(11, 8, 15, 8, "=")
    out["fw_library"] = dict(rows=g.rows(), door=door, spawn=spawn, dress=[("stacks", (4, 2), "Tall stacks of books", "bookcase", None)],
                             npcs=[("librarian_agnes_fennel", (9, 10), "townsfolk:librarian", {})])
    g, door, spawn = small(20, 14, 10)
    g.fill(2, 2, 17, 2, "=").put([(4, 6), (5, 6), (14, 6), (15, 6)], "=")
    out["fw_hall"] = dict(rows=g.rows(), door=door, spawn=spawn, dress=[
        ("notices", (10, 1), "The town hall's notice board", "notice_board", "townsfolk:hall_notice"), ("chairs", (6, 8), "Council chairs", "chairs", None)])
    return out


def room_loc(key, spec, outdoors=False, theme="manor"):
    rows = spec["rows"]
    w, h = len(rows[0]), len(rows)
    name = LABEL[key]
    return {"id": key, "name": name, "region": REGION, "summary": f"{name}, in Foxwillow.", "text": f"The inside of {name}.",
            "map": {"rows": rows, "theme": theme, "light": "dim", "outdoors": outdoors},
            "areas": [area("room", name, (1, 1), (w - 2, h - 2))], "spawns": {"default": list(spec["spawn"])},
            "exits": [], "props": [], "npcs": [], "rest": "risky"}


def build_rooms():
    rooms = {}
    for key, spec in room_defs().items():
        loc = room_loc(key, spec)
        loc["exits"].append(exit_("door", spec["door"], "foxwillow", "from_" + key, "Out to the town"))
        for (suffix, cell, label, model, dlg) in spec["dress"]:
            kw = {"dialogue": FW + dlg} if dlg else {}
            loc["props"].append(prop(f"{key}_{suffix}", cell, label, model=model, **kw))
        for (nid, cell, dlg, extra) in spec.get("npcs", []):
            loc["npcs"].append(npc(nid, cell, dlg, **extra))
        if key == "fw_library":
            loc["encounters"] = [{"id": "fw_librarian", "trigger": "dialogue", "flag": "fw_librarian_done",
                                  "monsters": [monster("pumpkin_head", (9, 9), "Agnes Fennel, in the straw", facing="south")]}]
        loc["lights"] = [{"cell": [3, 3], "kind": "candle", "bright_ft": 15, "dim_ft": 30, "color": "candle"}]
        rooms[key] = loc
    # the windmill: the ground floor on the left, the burning fourth floor and its beam on the right, one fight with a ticking clock
    g = G(30, 14).room(1, 1, 28, 12)
    g.wall(14, 1, 14, 12).fill(14, 6, 14, 7, ".")
    g.fill(2, 2, 6, 2, "=").put([(20, 4), (21, 4), (22, 4), (23, 4), (24, 4)], "=")   # the beam
    mill = room_loc("fw_windmill", dict(rows=g.rows(), spawn=(8, 11)), theme="tavern")
    mill["exits"] = [exit_("door", (8, 13), "foxwillow", "from_fw_windmill", "Out to the mill yard"),
                     exit_("cellar_stair", (3, 11), "fw_windmill_cellar", "from_stair", "Down to the cellar", when="flag.fw_mill_done")]
    mill["rows_note"] = None
    del mill["rows_note"]
    mill["map"]["rows"][13] = mill["map"]["rows"][13][:8] + "." + mill["map"]["rows"][13][9:]   # the door square in the south wall
    mill["props"] = [
        prop("fw_mill_beam", (22, 4), "The beam, and Jonah", kind="decor", call=FW + "windmill:jonah_rescued", approach=12, call_when="flag.fw_mill_done and not flag.jonah_saved and not flag.jonah_dead"),
        prop("fw_mill_cog", (16, 8), "The great cog", kind="decor", model="case"),
        prop("fw_mill_start", (8, 8), "The stair to the upper floor", kind="decor", call=FW + "extras:mill_start", approach=6, call_when="not flag.fw_mill_done and not flag.jonah_dead"),
    ]
    mill["npcs"] = [npc("liza_sawyer", (21, 5), "windmill:liza_plea", when="not flag.fw_mill_done")]
    mill["encounters"] = [{
        "id": "fw_mill", "trigger": "dialogue", "flag": "fw_mill_done", "quest": {"id": "the_burning_mill", "stage": "rescued"},
        "monsters": [monster("pumpkin_head", (21, 6), "Liza Sawyer, in the straw", art="scarecrow", facing="west"),
                     monster("pumpkin_head", (24, 8), "A burning scarecrow", facing="west")],
        "round_events": [
            {"id": "mill_fire", "name": "The mill burns", "summary": "Fire rolls down the stair and licks across the floorboards.", "kind": "save", "affects": "all",
             "save": {"ability": "dex", "dc": 12}, "half": True, "damage": {"dice": "1d6", "type": "fire"}, "at": 20, "every": 1,
             "area": {"cells": [[1, 1], [28, 12]]}, "say": "The mill groans, and the fire reaches for the stair."},
            {"id": "mill_falls", "name": "The mill falls", "summary": "On round nine the tower folds into itself.", "kind": "save", "affects": "all", "from_round": 9,
             "save": {"ability": "dex", "dc": 16}, "damage": {"dice": "4d10", "type": "bludgeoning"}, "at": 19, "every": 1,
             "area": {"cells": [[1, 1], [28, 12]]}, "say": "The sails tear loose and the tower comes down."}]}]
    rooms["fw_windmill"] = mill
    # the cellar: Isaac's chest, and the Hanged Man's banjo
    g = G(18, 14).room(1, 1, 16, 12)
    g.put([(3, 3), (4, 3), (12, 3), (13, 3)], "=")
    cel = room_loc("fw_windmill_cellar", dict(rows=g.rows(), spawn=(8, 11)))
    cel["exits"] = [exit_("stair_up", (8, 13), "fw_windmill", "from_cellar_stair", "Up to the mill")]
    cel["props"] = [
        prop("fw_isaac_chest", (14, 8), "A cellar chest, shut", model="case", call=FW + "extras:cellar_chest", approach=6, call_when="flag.isaac_found and not flag.fw_cellar_done"),
        prop("fw_banjo_hidden", (3, 9), "Something under the foundation stone", kind="search", search_dc=12, item="jericho_banjo",
             when="treasure_at:foxwillow_windmill_basement"),
    ]
    cel["encounters"] = [{"id": "fw_cellar", "trigger": "dialogue", "flag": "fw_cellar_done", "monsters": [
        monster("corvodaemon_split", (8, 6), "A crow knotted into a shape"), monster("corvodaemon_split", (10, 7), "A crow knotted into a shape"),
        monster("pumpkin_head", (6, 8), "The man in the straw", facing="east")]}]
    rooms["fw_windmill_cellar"] = cel
    rooms["fw_windmill"]["spawns"]["from_cellar_stair"] = [4, 11]
    cel["spawns"]["from_stair"] = [8, 11]
    # the corn maze
    def clearing(key, theme_note):
        g = G(24, 18).room(1, 1, 22, 16)
        g.put([(5, 5), (18, 5), (5, 12), (18, 12), (11, 9), (12, 9)], "#")   # stalks that pushed in
        loc = room_loc(key, dict(rows=g.rows(), spawn=(11, 15)), outdoors=True, theme="forest")
        loc["map"]["light"] = "dim"
        return loc
    for n in (1, 2, 3):
        j = clearing(f"fw_maze_j{n}", "")
        j["spawns"] = {"default": [11, 15], "from_back": [11, 15], "from_dead": [11, 14]}
        back = "foxwillow" if n == 1 else f"fw_maze_j{n - 1}"
        j["exits"] = [exit_("way_back", (11, 17), back, "from_corn" if n == 1 else "from_onward", "Back the way you came"),
                      exit_("mouth_left", (0, 8), "module_maze_left", "default", "The left mouth"),
                      exit_("mouth_centre", (11, 0), "module_maze_centre", "default", "The centre mouth"),
                      exit_("mouth_right", (23, 8), "module_maze_right", "default", "The right mouth")]
        j["props"] = [prop(f"fw_j{n}_call", (11, 8), "The crows' calls", kind="decor", call=FW + f"maze:junction{n}", approach=6, call_when=f"not flag.fw_j{n}_seen")]
        j["encounters"] = [{"id": f"fw_maze_j{n}_fight", "trigger": "dialogue", "flag": f"fw_maze_j{n}_done", "monsters": (
            [monster("corvodaemon_split", (8, 6), "A crow knotted into a shape"), monster("corvodaemon_split", (14, 6), "A crow knotted into a shape")] if n < 3 else
            [monster("corvodaemon_split", (8, 6)), monster("corvodaemon_split", (14, 6)), monster("pumpkin_head", (11, 5), "A scarecrow from the town", facing="south")])}]
        rooms[f"fw_maze_j{n}"] = j
        d = clearing(f"fw_maze_dead{n}", "")
        d["spawns"] = {"default": [11, 14]}
        d["exits"] = [exit_("way_back", (11, 17), f"fw_maze_j{n}", "from_dead", "Back to the clearing")]
        d["props"] = [prop(f"fw_dead{n}_end", (11, 8), "A dead end of black stalks", kind="decor", call=FW + f"maze:dead_end{n}", approach=5, call_when=f"not flag.fw_dead{n}_seen")]
        d["encounters"] = [{"id": f"fw_maze_dead{n}_fight", "trigger": "dialogue", "flag": f"fw_maze_dead{n}_done",
                            "monsters": [monster("crowstorm", (11, 7), "A storm of crows")] if n == 3 else [monster("pumpkin_head", (11, 7), "A scarecrow from the town", facing="south")]}]
        rooms[f"fw_maze_dead{n}"] = d
    # junction arrivals: the right junction's `default` is also where its predecessor's mouth leads
    rooms["fw_maze_j1"]["spawns"]["from_onward"] = [11, 15]
    for n in (2, 3):
        rooms[f"fw_maze_j{n}"]["spawns"]["from_onward"] = [11, 15]
    # Adelaide waits at the third junction's mouth: a fight in her own right, started from the maze conversation
    rooms["fw_maze_j2"]["npcs"] = [npc("adelaide_langtree", (11, 4), "maze:adelaide", when="not flag.adelaide_freed")]
    rooms["fw_maze_j2"]["encounters"].append({"id": "fw_maze_adelaide", "trigger": "dialogue", "flag": "fw_adelaide_fought",
        "monsters": [monster("corvodaemon_adelaide", (11, 6), "Adelaide Langtree", facing="south")]})
    rooms["fw_maze_j3"]["npcs"] = [npc("lost_soul", (6, 10), "maze:lost_soul", when="not flag.fw_lost_soul_saved")]
    # the Circle of Secrets: Raum's arena
    g = G(32, 22).room(1, 1, 30, 20)
    g.put([(8, 6), (23, 6), (8, 15), (23, 15)], "#")
    circ = room_loc("fw_circle", dict(rows=g.rows(), spawn=(15, 19)), outdoors=True, theme="forest")
    circ["exits"] = [exit_("way_back", (15, 21), "fw_maze_j3", "from_onward", "Back into the maze", when="not flag.fw_raum_started")]
    circ["props"] = [
        prop("fw_raum_birdcage", (15, 8), "Virgil, in the crop circle", model="scarecrow", call=FW + "raum:prefight", approach=8, call_when="not flag.fw_raum_done"),
        prop("fw_farewell", (15, 8), "A faint scarecrow ghost with a banjo", kind="decor", call=FW + "raum:jericho_farewell", approach=8, call_when="flag.fw_raum_done and not flag.jericho_at_rest"),
        prop("fw_scythe", (16, 10), "A scythe of black wood and bone", kind="search", search_dc=5, item="scythe_of_the_harvest_terror", when="flag.fw_raum_done and treasure_at:raum_arena"),
    ]
    circ["exits"].append(exit_("way_home", (15, 0), "foxwillow", "from_corn", "Out of the corn, home", when="flag.jericho_at_rest"))
    circ["encounters"] = [{
        "id": "fw_raum", "trigger": "dialogue", "flag": "fw_raum_done", "lair": True, "final_battle": None,
        "monsters": [monster("harvest_terror", (15, 7), "Raum, the Harvest Terror", boss=True, facing="south"),
                     monster("corvodaemon_split", (10, 9), "A murder of crows"), monster("corvodaemon_split", (20, 9), "A murder of crows"),
                     monster("corvodaemon_split", (15, 12), "A murder of crows")],
        "round_events": [{"id": "amber_crows", "name": "Amber crows", "summary": "Another amber-eyed crow lands in the circle.", "kind": "summon", "affects": "enemies",
                          "monster": "amber_crow", "count": 1, "side": "enemies", "cells": [[12, 11], [18, 11]], "at": 20, "every": 3, "times": 3}]}]
    del circ["encounters"][0]["final_battle"]
    rooms["fw_circle"] = circ
    for key, loc in rooms.items():
        write(f"data/locations/{key}.json", loc)
    return rooms


# ---- the people -------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude
    ("william_lodge", "William Lodge", "A tenant farmer", "A decent man in his forties, scared and stubborn, who has ridden for Wickermoor's help.", "friendly"),
    ("martha_langtree", "Martha Langtree", "The Langtree matriarch", "A proud, sharp widow in her sixties, grieving more than she lets show.", "indifferent"),
    ("jonah_sawyer", "Jonah Sawyer", "A farmhand", "A hot-headed young man in his twenties, ashamed of something he has done.", "indifferent"),
    ("adelaide_langtree", "Adelaide Langtree", "Martha's daughter", "Lost in the corn maze; cold, drawn and spoken for by something else.", "indifferent"),
    ("isaac_langtree", "Isaac Langtree", "Martha's late husband", "A dead man whose secret lies in a cellar chest.", "friendly"),
    ("liza_sawyer", "Liza Sawyer", "Jonah's sister", "A pumpkin-headed scarecrow with half her own mind.", "friendly"),
    ("rosemary_langtree", "Rosemary Langtree", "Martha's granddaughter", "A girl who watches the corn from the porch.", "friendly"),
    ("jericho_sticks", "Ol' Jericho Sticks", "The scarecrow musician", "A gentle old banjo man, eaten by something with a crow's face.", "friendly"),
    ("librarian_agnes_fennel", "Agnes Fennel", "The librarian", "The town librarian, prim and precise, now a scarecrow.", "indifferent"),
    ("lost_soul", "A lost soul", "A frightened villager", "A man in the corn who cannot stop saying one word.", "friendly"),
]


def build_people():
    for (nid, name, title, summary, att) in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION,
                                         **({"monster": "pumpkin_head"} if nid == "liza_sawyer" else {})})
    # Raum is a monster; the foxwillow regional NPC file is for the dialogues' speaker only
    write("data/npcs/raum.json", {"id": "raum", "name": "Raum", "title": "The Harvest Terror", "summary": "A crow-headed wicker demon who wears the scarecrow he swallowed.",
                                  "attitude": "hostile", "sprite": "villager", "region": REGION})


# ---- quests -----------------------------------------------------------------------------------------------------------------------
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
    write("data/quests/fields_of_the_crow.json", {
        "id": "fields_of_the_crow", "name": "Fields of the Crow", "kind": "main", "region": REGION, "giver": "jeremiah_stover",
        "summary": "A tenant farmer begs for help: the crops have died, the scarecrows walk, and a demon is eating Foxwillow's secrets.",
        "stages": [
            stage("asked", "In the Round, Jeremiah Stover and a thin tenant farmer called William Lodge asked us to ride to Foxwillow and find what is wrong with the corn.", "Ride out to Foxwillow with William.", ["Reach Foxwillow"]),
            stage("burning", "Foxwillow is on fire. Scarecrows with pumpkin heads brawl in the square, and the windmill is a wheel of flame.", "Find who is trapped in the windmill, and ask the town what happened.", ["Speak with Martha Langtree", "Help in the burning mill"]),
            stage("investigating", "The town is not the cause; the corn is. William says no one who went into the east fields came back. Villagers are hiding in scarecrows' skins, and a body burned or smashed means a person dead for good.", "Learn what the town hides: its secrets are the toll to enter the corn.", ["Find the librarian's song", "Find the town's tender secrets", "Reach the corn wall"]),
            stage("gate", "At the corn wall two amber eyes opened, and a croak set the toll: a secret, freely given.", "Pay the toll, and go in.", ["Pay the toll", "Reach the Circle of Secrets"]),
            stage("raum", "In the Circle of Secrets Raum fell. The ghost of Jericho Sticks bowed out under a white moon.", "Bring the people home and return to the town.", ["Return to Foxwillow"]),
            stage("done", "Foxwillow was freed. The scarecrows slept and Jeremiah paid us in Wickermoor.", ends="success"),
        ]})
    write("data/quests/the_burning_mill.json", {
        "id": "the_burning_mill", "name": "The Burning Mill", "kind": "side", "region": REGION, "giver": "martha_langtree",
        "summary": "Jonah Sawyer is trapped on a beam at the top of the burning windmill with his sister Liza, who is now a scarecrow.",
        "stages": [
            stage("burning", "Martha begged us to save Jonah from the windmill before it falls.", "Climb the mill and get Jonah down before it collapses.", ["Reach Jonah on the beam"]),
            stage("rescued", "We got Jonah out. He was ashamed to say what he and Martha had quarrelled over.", ends="success"),
            stage("lost", "The mill fell with Jonah on the beam.", ends="failure"),
        ]})


# ---- flags ------------------------------------------------------------------------------------------------------------------------
FLAGS = [
    ("foxwillow_asked", "bool", "The party has agreed to ride to Foxwillow."), ("fw_arrived", "bool", "The party has come over the ridge and seen Foxwillow burning."),
    ("fw_mill_asked", "bool", "Martha has asked the party to save Jonah."), ("fw_investigated", "bool", "The party has learned what the town hides and may try the corn."),
    ("body_rule_told", "bool", "William has told the party that a villager inside a scarecrow dies for good if its body is burned or smashed."),
    ("jonah_saved", "bool", "Jonah got out of the windmill."), ("jonah_dead", "bool", "The mill fell with Jonah in it."), ("liza_asked", "bool", "Liza begged not to be burned."),
    ("secret_martha", "bool", "The party knows Martha's secret."), ("secret_jonah", "bool", "The party knows Jonah's secret."), ("secret_isaac", "bool", "The party knows Isaac's secret."),
    ("secret_william", "bool", "The party knows William's secret."), ("secret_adelaide", "bool", "The party knows Adelaide's secret."),
    ("song_seen", "bool", "The party has seen the chalk song at the school."), ("song_known", "bool", "The party has Virgil's Birdcage (the Unraveling Song in the Raum fight)."),
    ("tender_banjo", "bool", "A hero carries Jericho's banjo into the corn."), ("tender_certificate", "bool", "A hero carries Jericho's certificate into the corn."),
    ("tender_song", "bool", "A hero carries the song sheet into the corn."), ("isaac_found", "bool", "The party found Isaac's cache and note."),
    ("butchers_hex_known", "bool", "The party knows the butcher cast an unrelated hex on the crops."),
    ("maze_open", "bool", "The toll is paid and the corn has parted."), ("paid_own_secret", "bool", "A hero paid their own secret at the gate."),
    ("told_raum_martha", "bool", "Raum was told Martha's secret."), ("told_raum_jonah", "bool", "Raum was told Jonah's secret."),
    ("told_raum_isaac", "bool", "Raum was told Isaac's secret."), ("told_raum_william", "bool", "Raum was told William's secret."),
    ("secrets_paid", "int", "How many secrets the party paid Raum at the gate."), ("adelaide_freed", "bool", "Adelaide was talked free of Raum's hold."),
    ("lost_souls_saved", "int", "Lost souls calmed in the maze."), ("fw_lost_soul_saved", "bool", "The lost soul in the third clearing was saved."),
    ("raum_song_sung", "bool", "The party sang Virgil's Birdcage at Raum."), ("raum_slain", "bool", "Raum is dead."), ("jericho_at_rest", "bool", "Jericho's ghost bowed out."),
    ("foxwillow_paid", "bool", "Jeremiah paid the party for Foxwillow."), ("phillip_matched_reward", "bool", "Phillip matched Jeremiah's reward."),
    ("sister_rain_invited", "bool", "Sister Rain is told the party freed Foxwillow."), ("sister_rain_recruited", "bool", "Sister Rain has come to Wickermoor recruiting."),
    ("adela_painting_bats", "bool", "Adela has painted the bats over the red moon."), ("adela_paintings_seen", "bool", "The party saw Adela's two paintings."),
    ("act2_done", "int", "Act II chapters finished (shared by the Crooked House and the Fields of the Crow)."),
    ("fw_brawl_a_done", "bool", "The first brawl is over."), ("fw_brawl_b_done", "bool", "The second brawl is over."), ("fw_brawl_c_done", "bool", "The third brawl is over."),
    ("fw_mill_done", "bool", "The mill fight is over."), ("fw_cellar_done", "bool", "The cellar fight is over."), ("fw_raum_done", "bool", "Raum's fight is over."),
    ("fw_raum_started", "bool", "Raum's fight has started."), ("fw_adelaide_fought", "bool", "Adelaide was fought."),
    ("fw_j1_seen", "bool", "The first junction's calls were heard."), ("fw_j2_seen", "bool", "The second junction's calls were heard."), ("fw_j3_seen", "bool", "The third junction's calls were heard."),
    ("fw_dead1_seen", "bool", "The first dead end was seen."), ("fw_dead2_seen", "bool", "The second dead end was seen."), ("fw_dead3_seen", "bool", "The third dead end was seen."),
    ("fw_maze_j1_done", "bool", "The first clearing's fight is over."), ("fw_maze_j2_done", "bool", "The second clearing's fight is over."), ("fw_maze_j3_done", "bool", "The third clearing's fight is over."),
    ("fw_maze_dead1_done", "bool", "The first dead end's fight is over."), ("fw_maze_dead2_done", "bool", "The second dead end's fight is over."), ("fw_maze_dead3_done", "bool", "The third dead end's fight is over."),
    ("fw_librarian_done", "bool", "The librarian's fight is over."), ("fw_home", "bool", "The party is home from the corn."),
]


def build_flags():
    write("data/flags/foxwillow.json", {"flags": [{"id": i, "type": t, "summary": s, "read_later": True} for (i, t, s) in FLAGS]})


# ---- items ------------------------------------------------------------------------------------------------------------------------
ITEMS = [
    ("jericho_banjo_gift", "Jericho's six-string banjo", "quest", "Ol' Jericho Sticks's banjo, dug out of the burning store. A mundane instrument, and a tender thing."),
    ("virgils_birdcage_sheet", "\"Virgil's Birdcage\" sheet", "quest", "The librarian's transcription of Jericho's favourite song, in her neat hand."),
    ("jericho_certificate", "Jericho's certificate", "quest", "A signed, unclaimed certificate of citizenship for Jericho Sticks."),
    ("isaacs_note", "Isaac's note", "quest", "A note in a dead man's fist: an invitation to the cellar, from Adelaide."),
    ("marthas_locket", "Martha's brass locket", "wondrous", "A brass locket Isaac made for Adelaide as a child. It turns a hand aside from the one who wears it (a Cloak of Protection in the book)."),
    ("williams_letter", "William's letter", "quest", "A letter in William Lodge's hand for Jeremiah, thanking the village."),
    ("cache_coin", "A black feather coin", "treasure", "A coin that crumbles at a touch and whispers when it does."),
    ("jericho_banjo", "The Banjo of Ol' Jericho Sticks", "wondrous", "A Fabled Heirloom focus: the banjo charms a fiend or humanoid, even through a demon's immunity (its powers wait on the engine's heirloom rules)."),
    ("scythe_of_the_harvest_terror", "Scythe of the Harvest Terror", "wondrous", "A Fabled Heirloom halberd that bites the frightened (its powers wait on the engine's heirloom rules)."),
    ("amber_birdcage", "The Amber Birdcage", "wondrous", "Raum's chest cage; replaces your torso while attuned (cursed; its powers wait on the engine's curio rules)."),
]


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary})


# ---- monsters ---------------------------------------------------------------------------------------------------------------------
def build_monsters():
    base = read("data/monsters/corvodaemon.json")
    for mid, name, hp in (("corvodaemon_split", "Corvodaemon (split from Raum)", 20), ("corvodaemon_adelaide", "Adelaide, Raum's puppet", 60)):
        m = copy.deepcopy(base)
        m.update({"id": mid, "name": name, "hp": {"average": hp, "dice": f"{max(1, hp // 5)}d8"}})
        m["summary"] = ("A scrap of Raum, shaped like a corvodaemon: weak, fast, and gone when the demon falls." if mid.endswith("split")
                        else "Adelaide Langtree, dominated: she moves in Raum's rhythm and her eyes are full of amber.")
        if mid.endswith("split"):
            m["minion_of"] = "harvest_terror"
            m["minions"] = {"when_it_falls": "vanish", "narration": "The crow comes apart into black feathers."}
        write(f"data/monsters/{mid}.json", m)
    pump = read("data/monsters/pumpkin_head.json")
    for mid, name, summary in (("amber_crow", "Amber crow", "A Tiny fiend with amber eyes; Raum eats it for temporary Hit Points."),
                               ("lost_soul", "Lost soul", "A frightened villager's soul, adrift in the corn.")):
        m = copy.deepcopy(pump)
        m.update({"id": mid, "name": name, "size": "tiny", "ac": 14 if mid == "amber_crow" else 10, "hp": {"average": 5, "dice": "1d4+2"}, "cr": 0, "xp": 0,
                  "summary": summary, "ai_profile": "skirmisher" if mid == "amber_crow" else "cowardly", "traits": [],
                  "actions": [{"id": "peck", "name": "Peck", "kind": "melee", "attack": {"bonus": 2, "reach": 5},
                               "damage": [{"average": 1, "dice": "1", "type": "piercing"}], "summary": "+2, reach 5 ft, 1 Piercing."}]})
        m.pop("multiattack", None)
        write(f"data/monsters/{mid}.json", m)
    raum = read("data/monsters/harvest_terror.json")
    for t in raum.get("traits", []):
        if t["id"] == "unraveling_song":
            t["summary"] = t["summary"]
            t["text"] = t["text"].replace('"Coal-Eyed Birds"', '"Virgil\'s Birdcage"')
    raum["phases"] = [{"id": "demon_of_secrets", "name": "Demon of Secrets", "when": {"bloodied": True}, "legendary_resistance": "refill",
                       "summary": "The murder bursts: Raum's Legendary Resistance returns and his Devour Secrets hungers.", "say": "fw_raum_phase2", "flag": "fw_raum_phase2"}]
    raum["minions"] = {"when_it_falls": "vanish", "narration": "The murder of crows scatters into black feathers and amber motes."}
    write("data/monsters/harvest_terror.json", raum)


def build_village_hooks():
    """Wickermoor's side of R13: Jeremiah's hook and reward, Sister Rain's recruiting. Idempotent edits of the village's NPC entries."""
    path = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(path.read_text())
    mine = {("jeremiah_stover", "hook:jeremiah_start"), ("jeremiah_stover", "village_after:jeremiah_reward"), ("sister_rain", "village_after:rain_recruits")}
    town["npcs"] = [n for n in town["npcs"] if (n["npc"], str(n.get("dialogue", "")).replace(FW, "")) not in mine and n.get("dialogue") not in (FW + "hook:jeremiah_start", FW + "village_after:jeremiah_reward", FW + "village_after:rain_recruits")]
    jer = next(n for n in town["npcs"] if n["npc"] == "jeremiah_stover")
    rain = next(n for n in town["npcs"] if n["npc"] == "sister_rain")
    i = town["npcs"].index(jer)
    town["npcs"][i:i] = [
        npc("jeremiah_stover", jer["cell"], "village_after:jeremiah_reward", when="flag.raum_slain and not flag.foxwillow_paid"),
        npc("jeremiah_stover", jer["cell"], "hook:jeremiah_start", when="flag.wm_welcomed and not flag.foxwillow_asked")]
    j = town["npcs"].index(rain)
    town["npcs"][j:j] = [npc("sister_rain", rain["cell"], "village_after:rain_recruits", when="flag.raum_slain and not flag.sister_rain_recruited")]
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


# ---- travel and cutscenes ---------------------------------------------------------------------------------------------------------
def build_travel():
    """Foxwillow joins the Wickermoor Hollow's travel map (a place belongs to one map)."""
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if x["id"] != "foxwillow"] + [
        {"id": "foxwillow", "name": "Foxwillow", "location": "foxwillow", "spawn": "from_road", "pos": [0.76, 0.32], "region": "foxwillow",
         "when": "flag.foxwillow_asked or visited:foxwillow", "summary": "A farming town in flames, east of Wickermoor."}]
    t["roads"] = [x for x in t["roads"] if x["id"] != "wickermoor_to_foxwillow"] + [
        {"id": "wickermoor_to_foxwillow", "from": "wickermoor_village", "to": "foxwillow", "hours": 18, "name": "The Foxwillow road", "when": "flag.foxwillow_asked or visited:foxwillow"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


PICTURES = {
    "fw_burning": "A farm cart cresting a ridge over dead fields lined with ragged scarecrows, an orange glow of a burning town on the horizon, a low orange moon",
    "fw_burning_2": "A windmill on a bluff turned into a spinning wheel of fire above a town square, figures in hats and bonnets brawling in the firelight below",
    "fw_mill_falls": "Burning windmill sails tearing loose and falling in a shower of sparks, the tower leaning in the night",
    "fw_mill_falls_2": "The windmill tower folding into itself in a column of orange sparks, tiny silhouettes running from it",
    "fw_isaac_chest": "A cellar chest with a carved-open ribcage inside it, black crows bursting out of it in a cloud",
    "fw_isaac_chest_2": "Crows knotting together in a stone cellar into the shape of a crow-headed demon, amber eyes glowing",
    "fw_gate": "A wall of impossibly tall corn at night swaying without wind, an orange moon behind it",
    "fw_gate_2": "Two great orange eyes with four-pointed star pupils opening between the corn stalks",
    "fw_into_the_fields": "Corn stalks parting and rising like redwoods around a lone path, an enormous harvest moon overhead",
    "fw_into_the_fields_2": "An orange harvest moon filling half the sky with cloud tendrils writhing out of it over an endless field",
    "fw_virgil_comes": "A humble straw-hatted scarecrow with a rusty birdcage in its chest, shaking in a crop circle at night",
    "fw_virgil_comes_2": "A demon erupting from a scarecrow: four black wings, a crow skull, a scythe raised to a harvest moon",
    "fw_farewell": "A faint scarecrow ghost with a banjo tipping his hat in a field at dawn",
    "fw_farewell_2": "The harvest moon turning from orange to white as the corn sinks to normal height around a silver ghost",
    "fw_coming_home": "Silver spirits drifting over fields toward a quiet farm town at dawn",
    "fw_coming_home_2": "On a porch a pumpkin head softening into a sleeping person, beside it a burned scarecrow that stays straw",
    "fw_adela_paintings": "A painting of a corn maze under an orange moon propped on an easel in a lamp-lit room",
    "fw_adela_paintings_2": "A painting of bats flying over mountains beneath a blood-red moon, the paint still wet",
}


def build_cutscenes():
    write("tools/content/foxwillow_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": PICTURES})
    for cid, desc in PICTURES.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("fw_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


if __name__ == "__main__":
    build_town()
    build_rooms()
    build_people()
    build_quests()
    build_flags()
    build_items()
    build_monsters()
    build_travel()
    build_cutscenes()
    build_village_hooks()
    print("ok")
