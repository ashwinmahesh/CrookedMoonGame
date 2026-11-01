"""The places of R14 (The Crimson Monastery): Dawn's Gate and its inn, the pass, the monastery's grounds and floors, the bell tower, the
Holy Vein, the Bloody Sanctum and the cathedral under the blood moon. Helpers shared with build_monastery.py. Dialogue refs are `monastery/<file>:<node>`."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G

M = "monastery/"


def prop(pid, cell, label=None, kind="examine", model=None, **kw):
    d = {"id": pid, "cell": list(cell), "kind": kind}
    if label:
        d["label"] = label
    if model:
        d["model"] = model
    d.update(kw)
    return d


def talk(pid, cell, label, ref, model=None, when=None, approach=None, kind="examine", **kw):
    """A prop that starts a conversation. `approach` makes it speak when the leader comes near (call/call_when)."""
    d = prop(pid, cell, label, kind=kind, model=model)
    if approach:
        d["call"] = M + ref
        d["approach"] = approach
        if when:
            d["call_when"] = when
    else:
        d["dialogue"] = M + ref
        if when:
            d["when"] = when
    d.update(kw)
    return d


def npc(nid, cell, ref=None, **kw):
    d = {"npc": nid, "cell": list(cell)}
    if ref:
        d["dialogue"] = M + ref
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


def base(lid, name, region, rows, theme, light="dim", outdoors=False, summary="", text="", rest="risky", rest_text=None):
    loc = {"id": lid, "name": name, "region": region, "summary": summary or name, "text": text or summary or name,
           "map": {"rows": rows, "theme": theme, "light": light, "outdoors": outdoors},
           "areas": [], "spawns": {"default": [1, 1]}, "exits": [], "props": [], "npcs": [], "encounters": [], "rest": rest}
    if rest_text:
        loc["rest_text"] = rest_text
    return loc


def lights(loc, cells, kind="torch", bright=20, dim=40, color=None):
    for c in cells:
        d = {"cell": list(c), "kind": kind, "bright_ft": bright, "dim_ft": dim}
        if color:
            d["color"] = color
        loc.setdefault("lights", []).append(d)


def dress(loc, pid, pairs, model, label):
    """Scatter plain props of one model over a list of cells (many ordinary props)."""
    for i, c in enumerate(pairs):
        loc["props"].append(prop(f"{pid}_{i + 1}", c, label, kind="decor", model=model))


def door(did, cell, **kw):
    d = {"id": did, "cell": list(cell)}
    d.update(kw)
    return d


def reachable(rows, start):
    """Squares walkable from `start` (4-neighbour flood over '.', '_' and '~' squares), so people are never put in a pocket."""
    seen, todo = {tuple(start)}, [tuple(start)]
    while todo:
        x, y = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= ny < len(rows) and 0 <= nx < len(rows[ny]) and (nx, ny) not in seen and rows[ny][nx] in ".~_1234":
                seen.add((nx, ny))
                todo.append((nx, ny))
    return seen


def fix_open(rows, cell, ok=None):
    """Nearest open '.' to a cell (that can be walked to, when `ok` is the reachable set) for placing people on sketched ground."""
    x0, y0 = cell
    for r in range(0, 12):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                x, y = x0 + dx, y0 + dy
                if 0 <= y < len(rows) and 0 <= x < len(rows[y]) and rows[y][x] == "." and (ok is None or (x, y) in ok):
                    return [x, y]
    return list(cell)


# ---- the inn -------------------------------------------------------------------------------------------------------------------------
def briar():
    g = G(30, 20).room(1, 1, 28, 18)
    g.wall(1, 8, 12, 8).fill(7, 8, 7, 8, ".")                      # the kitchen's wall, a doorway
    g.fill(2, 2, 11, 2, "=").fill(2, 5, 4, 5, "=")                 # kitchen counters
    g.wall(20, 1, 20, 7).fill(20, 4, 20, 4, ".")                    # a store room
    g.fill(14, 6, 26, 6, "=")                                       # the bar
    g.put([(14, 11), (15, 11), (19, 11), (20, 11), (24, 11), (25, 11), (14, 14), (15, 14), (19, 14), (20, 14), (24, 14), (25, 14)], "=")   # tables
    g.put([(2, 12), (2, 13), (2, 14)], "=")
    g.wall(26, 15, 28, 16).fill(27, 15, 27, 15, ".")                # the stair's wall
    g.fill(14, 19, 14, 19, ".")
    rows = g.rows()
    loc = base("dg_briar", "The Briar Public House", "dawns_gate", rows, "tavern", summary="Kristoff Gruber's inn: a low taproom of black beams, a kitchen, a cellar stair and rooms above.",
               text="A low room of black beams and hunters' coats on pegs. The bar is scarred, the fire is good and nobody sings.", rest="safe", rest_text="Kristoff's beds are clean and the bar is barred at night.")
    loc["areas"] = [area("taproom", "The taproom", (1, 9), (28, 18)), area("kitchen", "The kitchen", (1, 1), (11, 7)), area("bar", "The bar", (13, 1), (28, 7)),
                    area("stairs", "The stair", (26, 14), (28, 18))]
    loc["spawns"] = {"default": [14, 17], "from_town": [14, 17], "from_cellar": [6, 6], "from_upstairs": [27, 14]}
    loc["exits"] = [exit_("door", (14, 19), "dawns_gate", "from_briar", "Out to the square"),
                    exit_("cellar_stair", (6, 7), "dg_briar_cellar", "from_stair", "Down to the cellar"),
                    exit_("stairs_up", (27, 15), "dg_briar_upper", "from_stairs", "Up to the rooms")]
    loc["props"] = [
        talk("dg_briar_noticeboard", (24, 2), "A board of Hunt notices", "kristoff:board", model="notice_board"),
        prop("dg_briar_hearth", (24, 9), "The taproom fire", kind="decor", model="fireplace"),
        prop("dg_briar_barrels", (3, 14), "Barrels of black beer", kind="decor", model="barrel"),
        prop("dg_briar_pegs", (2, 17), "Hunters' coats on pegs", kind="decor", model="cloak_pegs"),
        prop("dg_briar_roses", (10, 16), "A golden rose nailed over the door", kind="decor", model="crest"),
        prop("dg_briar_pot", (5, 3), "A pot of something that was a goat", kind="decor", model="cookpot"),
        prop("dg_briar_larder", (9, 4), "Hanging meat and strings of onions", kind="decor", model="drying_herbs"),
    ]
    dress(loc, "dg_briar_stool", [(16, 7), (18, 7), (22, 7), (25, 7)], "chair", "A bar stool")
    dress(loc, "dg_briar_table", [(14, 12), (19, 12), (24, 12), (14, 15), (19, 15), (24, 15)], "table_chairs", "A taproom table")
    loc["npcs"] = [npc("kristoff_gruber", (16, 5), "kristoff:start")]
    lights(loc, [(24, 8), (5, 3), (16, 16)], kind="candle", bright=15, dim=30)
    return loc


def briar_upper():
    g = G(24, 12).room(1, 1, 22, 10)
    g.wall(1, 5, 22, 5)
    for x in (4, 10, 16):
        g.fill(x, 5, x, 5, ".")
    for x in (7, 13, 19):
        g.wall(x, 1, x, 4)
    g.put([(2, 2), (3, 2), (8, 2), (9, 2), (14, 2), (15, 2), (20, 2), (21, 2)], "=")
    loc = base("dg_briar_upper", "The Briar, Upstairs", "dawns_gate", g.rows(), "tavern", summary="Four small rooms over the taproom.", text="Four narrow rooms under the eaves, each with a bed, a hook and a window on the red-lit hill.", rest="safe", rest_text="The beds are clean.")
    loc["areas"] = [area("rooms", "The rooms", (1, 1), (22, 10))]
    loc["spawns"] = {"default": [2, 8], "from_stairs": [2, 8]}
    loc["exits"] = [exit_("stairs_down", (1, 10), "dg_briar", "from_upstairs", "Down to the taproom")]
    g2 = loc["map"]["rows"]
    loc["map"]["rows"][11] = g2[11][:1] + "." + g2[11][2:]
    loc["exits"][0]["cell"] = [1, 11]
    loc["props"] = [prop("dg_briar_window", (22, 7), "A window on the hill", kind="decor", model="window_tall"),
                    prop("dg_briar_chest", (21, 9), "A traveller's chest", kind="decor", model="trunk")]
    loc["npcs"] = [npc("gareth_creed", (10, 3), "gareth:after", when="flag.gareth_fate == \"rescued\" and not flag.gareth_home")]
    return loc


def briar_cellar():
    g = G(20, 14).room(1, 1, 18, 12)
    g.put([(3, 3), (4, 3), (15, 3), (16, 3), (3, 9), (4, 9), (15, 9), (16, 9)], "=")
    loc = base("dg_briar_cellar", "The Briar's Cellar", "dawns_gate", g.rows(), "tavern", light="dim", summary="A cool cellar of casks, and a false wall behind them.", text="Casks, cold stone, and behind the third rack a wall that is newer than the rest.", rest="risky")
    loc["areas"] = [area("cellar", "The cellar", (1, 1), (18, 12))]
    loc["spawns"] = {"default": [9, 11], "from_stair": [9, 11]}
    loc["exits"] = [exit_("stair_up", (9, 13), "dg_briar", "from_cellar", "Up to the taproom")]
    loc["props"] = [
        talk("dg_cellar_wall", (9, 3), "A newer wall behind the casks", "cellar:refugees", model="wall_low", when="flag.cellar_asked and not flag.cellar_outcome"),
        prop("dg_cellar_casks", (6, 5), "Casks of black beer", kind="decor", model="cask_rack"),
        prop("dg_cellar_crates", (14, 5), "Stacked crates", kind="decor", model="crate_stack"),
        prop("dg_cellar_sacks", (16, 10), "Sacks of barley", kind="decor", model="sack_pile"),
    ]
    loc["npcs"] = [npc("dg_refugee_ilse", (8, 2), "cellar:ilse", when="flag.cellar_outcome == \"kept\""),
                   npc("dg_refugee_otto", (11, 2), "cellar:otto", when="flag.cellar_outcome == \"kept\"")]
    return loc


# ---- the village and the pass --------------------------------------------------------------------------------------------------------
def town(loc):
    """Dawn's Gate over its sketched ground (data/locations/dawns_gate.json already carries the map and elevation)."""
    rows = loc["map"]["rows"]
    ok = reachable(rows, (57, 28))
    loc.update({
        "name": "Dawn's Gate", "region": "dawns_gate",
        "summary": "A dour mining village in the Howlers' foothills, below a monastery whose red windows are never dark.",
        "text": "Slate roofs, soot, and a copper glow of lamps. Red banners with a golden rose are nailed on every door, and above the village, on its peak, a bell tower stands black against the stars.",
        "areas": [area("dg_square", "The square", (28, 20), (46, 29)), area("dg_briar_front", "Before the Briar", (31, 36), (40, 38)), area("dg_mine", "The mine hill", (1, 19), (16, 36)),
                  area("dg_smelter", "The smelter", (6, 22), (15, 30)), area("dg_hill", "The hill path", (14, 0), (24, 13)), area("dg_lodge", "The Hunt's lodge", (34, 13), (43, 20)),
                  area("dg_east", "The river road", (47, 26), (59, 31)), area("dg_stream", "The mill stream", (44, 8), (56, 49))],
        "spawns": {"default": [57, 28], "from_road": [57, 28], "from_pass": fix_open(rows, (20, 2), ok), "from_briar": fix_open(rows, (35, 37), ok)},
    })
    loc["exits"] = [exit_("briar", (35, 36), "dg_briar", "from_town", "Enter the Briar Public House"),
                    exit_("road_east", (59, 28), "travel", "default", "The river road back to Wickermoor"),
                    exit_("hill_path", (20, 0), "mon_pass", "from_gate", "Up the hill path to the monastery")]
    xy = lambda c: fix_open(rows, c, ok)
    loc["props"] = [
        talk("dg_arrival", xy((55, 28)), "The river road, and the village ahead", "arrival:dg_arrive", kind="decor", approach=10, when="not flag.dg_arrived"),
        talk("dg_bell_post", xy((34, 25)), "The village bell post", "arrival:bells", model="lantern_post"),
        talk("dg_hill_sign", xy((21, 8)), "The hill path sign", "arrival:hill_sign", model="signpost"),
        talk("dg_notice", xy((40, 31)), "The Hunt's notice", "villagers:notice", model="notice_board"),
        prop("dg_well", xy((37, 27)), "The village well", kind="decor", model="well_stone"),
        prop("dg_adit", xy((8, 21)), "A mine adit, timbered and shut", kind="decor", model="gate_iron"),
        prop("dg_smelter_stack", xy((9, 24)), "The smelter, smoking", kind="decor", model="oven_brick"),
        prop("dg_slag", xy((14, 29)), "A heap of slag", kind="decor", model="rubble"),
        prop("dg_ore_cart", xy((5, 28)), "An ore cart", kind="decor", model="handcart"),
        prop("dg_banner_a", xy((29, 28)), "A red banner with a golden rose", kind="decor", model="festival_cloth"),
        prop("dg_banner_b", xy((46, 22)), "A red banner with a golden rose", kind="decor", model="festival_cloth"),
        prop("dg_banner_c", xy((24, 29)), "A red banner with a golden rose", kind="decor", model="festival_cloth"),
        prop("dg_stakes", xy((38, 22)), "A bundle of stakes the Hunt left", kind="decor", model="stake_bundle"),
        prop("dg_horse_trough", xy((43, 27)), "The Hunt's horse trough", kind="decor", model="trough"),
        prop("dg_lodge_horses", xy((38, 20)), "Tethered warhorses", kind="decor", model="stall_horse"),
        prop("dg_woodpile", xy((21, 27)), "A woodpile", kind="decor", model="woodpile"),
        prop("dg_slate_stack", xy((26, 38)), "A stack of roofing slate", kind="decor", model="slate_stack"),
        talk("dg_pass_view", xy((20, 3)), "The monastery on its peak", "arrival:pass_view", kind="decor", approach=6, when="not flag.mon_skyline_seen"),
        talk("dg_farewell_prop", xy((36, 26)), "The square, quiet at last", "aftermath:farewell", kind="decor", approach=8, when="flag.crimson_aftermath and not flag.crimson_farewell"),
        talk("dg_hunt_gather", xy((37, 24)), "The Hunt, saddling in the square", "villagers:hunt_ambush", kind="decor", approach=7, when="flag.hunt_known and not flag.sanguine_hunt_ambushed and not flag.hunt_gone"),
    ]
    for i, c in enumerate([(30, 21), (33, 29), (42, 30), (26, 22), (45, 24), (27, 31), (41, 21), (19, 30), (30, 36)]):
        loc["props"].append(prop(f"dg_lamp_{i + 1}", xy(c), "A copper lamp", kind="decor", model="lantern_post"))
    for i, c in enumerate([(13, 10), (18, 14), (10, 15), (26, 6), (6, 38), (12, 43), (40, 46), (50, 20)]):
        loc["props"].append(prop(f"dg_tree_{i + 1}", xy(c), "A dead tree", kind="decor", model="dead_tree_a" if i % 2 else "dead_tree_b"))
    loc["npcs"] = [
        npc("dg_toma_flint", xy((12, 27)), "villagers:toma"),
        npc("dg_halka_wren", xy((27, 24)), "villagers:halka"),
        npc("dagny_voll", xy((40, 22)), "hounds:dagny_start"),
        npc("ser_maric_dunmore", xy((42, 25)), "maric:start"),
        npc("pilgrim_quill", xy((36, 27)), "poet:quill_start"),
        npc("brother_quiet", xy((24, 32)), "quiet:quiet_start"),
        npc("orrin_tolle", xy((33, 26)), "bell:orrin_start"),
        npc("dg_wren_child", xy((31, 27)), "villagers:wren"),
    ]
    loc["npcs"] = [n for n in loc["npcs"] if n]
    loc["encounters"] = []
    for lv, knights in (("level <= 5", 1), ("level >= 6", 2)):
        for loose in (False, True):
            n = knights - (1 if loose and knights > 1 else 0)
            ms = [monster("hunt_knight", xy((38, 24)), "The Hunt's captain", facing="west")] + [monster("hunt_knight", xy((36 + 4 * i, 26)), "A Hunt knight", facing="west") for i in range(n)] + [
                monster("bat_hound", xy((37, 22)), "A leashed bat hound", facing="west")]
            if knights > 1:
                ms.append(monster("bat_hound", xy((41, 22)), "A leashed bat hound", facing="west"))
            loc["encounters"].append({"id": "dg_hunt", "trigger": "dialogue", "flag": "sanguine_hunt_ambushed", "when": f"{lv} and " + ("flag.maric_loosened" if loose else "not flag.maric_loosened"),
                                      "quest": {"id": "sanguine_hunt", "stage": "ambushed"}, "monsters": ms})
    loc["rest"] = "risky"
    loc["rest_text"] = "The bell calls the hours, and the village kneels to every one."
    loc["recheck_minutes"] = 30
    return loc


def pass_(loc):
    rows = loc["map"]["rows"]
    ok = reachable(rows, (15, 58))
    xy = lambda c: fix_open(rows, c, ok)
    loc.update({
        "name": "The Howlers Pass", "region": "dawns_gate",
        "summary": "A winding climb through slate-grey mountains and a copse of dead trees, with the monastery's red windows lighting the way.",
        "text": "The path climbs in long bends of loose slate. Dead trees lean over it. Above, bats stream out of a black tower and the red windows throw a lit road to the gates.",
        "areas": [area("pass_foot", "The foot of the climb", (10, 48), (22, 59)), area("pass_camp", "The camp ground", (3, 23), (13, 29)), area("pass_apron", "Before the gate", (7, 0), (26, 6)),
                  area("pass_bend", "The long bends", (8, 30), (22, 47))],
        "spawns": {"default": xy((15, 57)), "from_gate": xy((15, 57)), "from_monastery": xy((20, 2))},
    })
    loc["exits"] = [exit_("down_to_village", xy((15, 59)) if rows[59][15] != "#" else (15, 59), "dawns_gate", "from_pass", "Down to Dawn's Gate"),
                    exit_("up_to_gate", (20, 0), "mon_ground", "from_pass", "Through the monastery gate", when="flag.crimson_gate_open")]
    loc["exits"][0]["cell"] = [15, 59]
    loc["props"] = [
        talk("mon_pass_gate", xy((20, 3)), "The monastery gate, and its watch", "arrival:gate_watch", kind="decor", approach=5, when="not flag.crimson_gate_open"),
        talk("mon_pass_view", xy((14, 52)), "The monastery on its peak", "arrival:pass_view", kind="decor", approach=5, when="not flag.mon_skyline_seen"),
        prop("mon_pass_bats", xy((12, 20)), "Bats streaming from the belfry", kind="decor", model="bat_perch"),
        prop("mon_pass_cairn", xy((12, 40)), "A pilgrims' cairn", kind="decor", model="cairn"),
        prop("mon_pass_camp", xy((8, 26)), "A cold fire ring", kind="decor", model="campfire"),
        prop("mon_pass_sign", xy((14, 56)), "A signpost: THE CRIMSON ROSE RECEIVES ALL", kind="decor", model="signpost"),
    ]
    for i, c in enumerate([(7, 24), (11, 28), (16, 36), (18, 44), (12, 33), (21, 8), (11, 5), (19, 50), (13, 15)]):
        loc["props"].append(prop(f"mon_pass_tree_{i + 1}", xy(c), "A dead tree", kind="decor", model="dead_tree_b" if i % 2 else "dead_tree_a"))
    for i, c in enumerate([(14, 30), (10, 38), (17, 41), (9, 12), (19, 18)]):
        loc["props"].append(prop(f"mon_pass_rocks_{i + 1}", xy(c), "Loose slate", kind="decor", model="boulder_a" if i % 2 else "boulder_b"))
    loc["npcs"] = []
    loc["encounters"] = [
        {"id": "mon_alpengrendel", "trigger": "enter_area:pass_camp", "when": "level <= 6 and not flag.mon_alpengrendel_done", "waiting": True, "flag": "mon_alpengrendel_done",
         "monsters": [monster("alpengrendel", xy((6, 25)), "A pale shape at the camp ground", facing="east")]},
        {"id": "mon_alpengrendel", "trigger": "enter_area:pass_camp", "when": "level >= 7 and not flag.mon_alpengrendel_done", "waiting": True, "flag": "mon_alpengrendel_done",
         "monsters": [monster("alpengrendel", xy((6, 25)), "A pale shape at the camp ground", facing="east"), monster("bat_hound", xy((9, 27)), "A bat hound that follows it", facing="east"),
                      monster("bat_hound", xy((8, 23)), "A bat hound that follows it", facing="east")]},
    ]
    loc["encounters"].append({"id": "mon_gate_fight", "trigger": "dialogue", "flag": "mon_gate_fight_done", "monsters": [
        monster("warrior_veteran", xy((19, 3)), "A gate veteran", facing="south"), monster("warrior_veteran", xy((22, 3)), "A gate veteran", facing="south"),
        monster("cultist_fanatic", xy((17, 5)), "A cultist fanatic", facing="east"), monster("cultist_fanatic", xy((23, 5)), "A cultist fanatic", facing="west"), monster("cultist_fanatic", xy((20, 5)), "A cultist fanatic", facing="south")]})
    loc["rest"] = "risky"
    loc["rest_text"] = "Cold wind, loose slate, and bats overhead."
    return loc


# ---- the stables and kennels ---------------------------------------------------------------------------------------------------------
def stables():
    g = G(34, 24).room(1, 1, 32, 22)
    g.wall(1, 1, 14, 9).room(2, 2, 13, 8)                          # the stable block
    g.put([(3, 3), (3, 4), (3, 6), (3, 7), (6, 3), (6, 4), (6, 6), (6, 7), (9, 3), (9, 4), (9, 6), (9, 7)], "=")       # stalls
    g.fill(8, 9, 8, 9, ".")                                         # the stable door
    g.wall(18, 1, 32, 8).room(19, 2, 31, 7)                        # the armory shed
    g.fill(24, 8, 24, 8, ".")
    g.put([(20, 3), (21, 3), (22, 3), (28, 3), (29, 3), (30, 3)], "=")
    for (x, y) in [(6, 14), (12, 16), (20, 14), (26, 17), (10, 20), (22, 20), (30, 12)]:
        g.put([(x, y), (x + 1, y)], "=")                           # kennel boxes built into dead trees
    loc = base("mon_stables", "The Hunt's Stables and Kennels", "crimson_monastery", g.rows(), "forest", light="dim", outdoors=True,
               summary="Outside the east wall: the Hunt's warhorses, an armory shed, and bat hounds in boxes built into dead trees.", text="Warm stink of horse and iron, and in the dead trees beyond, eyes that open when you pass.", rest="risky")
    loc["areas"] = [area("stable_block", "The stables", (2, 2), (13, 8)), area("armory", "The armory", (19, 2), (31, 7)), area("kennels", "The kennels", (4, 11), (31, 22)), area("yard", "The yard", (1, 10), (32, 22))]
    loc["spawns"] = {"default": [1, 15], "from_grounds": [2, 15]}
    loc["exits"] = [exit_("to_grounds", (0, 15), "mon_ground", "from_stables", "Back inside the walls")]
    loc["map"]["rows"][15] = "." + loc["map"]["rows"][15][1:]
    loc["props"] = [
        prop("mon_st_hay", (4, 5), "Hay", kind="decor", model="hay_bale"),
        prop("mon_st_tack", (11, 3), "Saddles on a rack", kind="decor", model="tack"),
        prop("mon_st_trough", (14, 12), "A water trough", kind="decor", model="trough"),
        talk("mon_st_armory", (22, 5), "The Hunt's armory", "stables:armory", model="weapon_rack"),
        talk("mon_st_kennel_treats", (26, 16), "A crate of bloody treats", "stables:treats", model="crate"),
        prop("mon_st_shield", (30, 4), "A shield hung in a place of honour", kind="decor", model="shrine_small", when="flag.armory_shield"),
        prop("mon_st_horse_a", (4, 4), "A warhorse of the Hunt", kind="decor", model="stall_horse"),
        prop("mon_st_horse_b", (7, 6), "A warhorse of the Hunt", kind="decor", model="stall_horse"),
        prop("mon_st_horse_c", (10, 4), "A riding horse", kind="decor", model="horse"),
        prop("mon_st_wagon", (16, 18), "A prisoners' wagon", kind="decor", model="wagon"),
        prop("mon_st_woodpile", (28, 10), "A woodpile", kind="decor", model="woodpile"),
        prop("mon_st_bones", (18, 21), "Gnawed bones", kind="decor", model="bone_scatter"),
        prop("mon_st_tree_a", (8, 12), "A dead tree, boxed", kind="decor", model="dead_tree_a"),
        prop("mon_st_tree_b", (24, 13), "A dead tree, boxed", kind="decor", model="dead_tree_b"),
    ]
    loc["npcs"] = [npc("landers_knight", (12, 14), "stables:landers"), npc("marla_knight", (14, 15), "stables:marla"), npc("fremont_knight", (12, 17), "stables:fremont"),
                   npc("stable_hand_cm", (8, 10), "stables:hand")]
    loc["encounters"] = [
        {"id": "mon_stable_knights", "trigger": "dialogue", "flag": "mon_stable_knights_done", "monsters": [
            monster("hunt_knight_bare", (12, 14), "Landers", facing="west"), monster("hunt_knight_bare", (14, 15), "Marla", facing="west"), monster("hunt_knight_bare", (12, 17), "Fremont", facing="west")]},
        {"id": "mon_kennels", "trigger": "enter_area:kennels", "when": "not flag.mon_kennels_done and not flag.dagny_hounds_calmed", "waiting": True, "flag": "mon_kennels_done", "monsters": [
            monster("bat_hound", (5, 14), "A bat hound in its box", facing="south"), monster("bat_hound", (13, 17), "A bat hound in its box", facing="south"), monster("bat_hound", (21, 15), "A bat hound in its box", facing="west"),
            monster("bat_hound", (27, 18), "A bat hound in its box", facing="west")]},
    ]
    return loc


# ---- the monastery: ground floor ----------------------------------------------------------------------------------------------------
def ground():
    g = G(64, 42).room(1, 1, 62, 40)
    g.wall(1, 30, 62, 30).fill(31, 30, 33, 30, ".")                # the building's south wall and its gate hall opening
    g.fill(32, 41, 32, 41, ".")                                     # the gate in the south wall
    g.fill(63, 36, 63, 36, ".")                                     # the east gate to the stables
    # Jaeger's cabin (M3)
    g.wall(2, 32, 12, 40).room(3, 33, 11, 39).fill(12, 36, 12, 36, ".")
    g.fill(4, 34, 6, 34, "=").put([(9, 38), (10, 38), (10, 37)], "=")
    # the cloister: halls (18..45 x 11..29), the courtyard wall (20..43 x 13..27) with arches and windows, the courtyard (21..42 x 14..26)
    g.wall(17, 11, 17, 29)
    g.wall(46, 11, 46, 29)
    g.wall(20, 13, 43, 27).room(21, 14, 42, 26)
    for x in (32, 33):
        g.fill(x, 13, x, 13, ".").fill(x, 27, x, 27, ".")
    for y in (19, 20):
        g.fill(20, y, 20, y, ".").fill(43, y, 43, y, ".")
    for x in (24, 26, 28, 36, 38, 40):
        g.put([(x, 13), (x, 27)], "=")
    for y in (15, 17, 22, 24):
        g.put([(20, y), (43, y)], "=")
    # the courtyard of the rose: statues, the pyre ring
    g.put([(23, 15), (40, 15), (23, 25), (40, 25), (27, 20), (36, 20)], "=")
    # the cathedral (M12)
    g.wall(22, 1, 42, 10).room(23, 2, 41, 9).fill(32, 10, 32, 10, ".")
    g.fill(29, 2, 35, 3, "_")                                       # the altar dais
    for y in (5, 7):
        g.put([(x, y) for x in (24, 25, 26, 27, 28, 36, 37, 38, 39, 40)], "=")      # pews
    g.wall(17, 1, 21, 3).wall(17, 7, 21, 10).fill(17, 4, 21, 6, ".")   # passage from the refectory
    g.wall(43, 1, 46, 10).fill(44, 4, 45, 10, ".").fill(1, 25, 16, 29, "#")
    # the west wing: refectory (M5a) and cells (M6)
    g.wall(1, 10, 16, 10)
    g.fill(3, 3, 14, 3, "=").fill(3, 6, 14, 6, "=")                 # refectory tables
    g.room(2, 17, 16, 18)                                          # the cell corridor
    g.fill(17, 17, 17, 18, ".")
    g.wall(1, 11, 16, 11).wall(1, 16, 16, 16).wall(1, 19, 16, 19).wall(1, 24, 16, 24)
    for x0 in (2, 6, 10, 14):
        g.fill(x0, 12, x0 + 2, 15, ".").fill(x0, 20, x0 + 2, 23, ".")
        g.fill(x0 + 1, 16, x0 + 1, 16, ".").fill(x0 + 1, 19, x0 + 1, 19, ".")
        g.put([(x0, 13), (x0 + 2, 22)], "=")
    for x in (5, 9, 13):
        g.wall(x, 12, x, 15).wall(x, 20, x, 23)
    # the east wing: kitchen (M10), larder (M11), corridor, prayer nooks (M5b)
    g.wall(47, 1, 62, 10).room(48, 2, 61, 9).fill(44, 5, 47, 5, ".")
    g.fill(49, 3, 52, 3, "=").fill(56, 5, 59, 5, "=").put([(60, 8), (60, 7)], "=")
    g.fill(55, 10, 55, 10, ".")
    g.wall(47, 10, 62, 19).room(48, 11, 61, 18).fill(55, 10, 55, 10, ".")
    g.put([(50, 12), (53, 12), (58, 12), (61, 12), (50, 16), (58, 16)], "=")
    g.room(47, 20, 61, 21).fill(46, 21, 46, 21, ".")
    g.wall(47, 22, 62, 22).fill(50, 22, 50, 22, ".").fill(58, 22, 58, 22, ".")
    g.wall(47, 23, 62, 29)
    g.fill(48, 23, 53, 29, ".").fill(56, 23, 61, 29, ".")
    g.wall(54, 23, 55, 29)
    # the south yard dressing
    g.put([(8, 31), (20, 33), (21, 33), (44, 33), (45, 33), (52, 34), (53, 34), (54, 34)], "=")
    rows = g.rows()
    # the hall ring is reached through the south opening (31..33,30) -> hall rows 28..29; make sure the ring is open
    loc = base("mon_ground", "The Crimson Monastery", "crimson_monastery", rows, "manor", light="bright",
               summary="A walled octagon on the peak: grounds, the Courtyard of the Rose, cloister halls, cells, a kitchen, a freezing larder and a domed cathedral.",
               text="Spiked black walls, red glass in every window and a smell of iron and sulfur. Statues weep blood in the courtyard and the whole place is lit the colour of a wound.", rest="no",
               rest_text="No one rests under the Rose's eye.")
    loc["areas"] = [
        area("grounds", "The monastery grounds", (1, 31), (62, 40)),
        area("cabin", "Jaeger's cabin", (3, 33), (11, 39), private="sigmund_jaeger", open="flag.crimson_in and standing.crimson_faith >= 5"),
        area("courtyard", "The Courtyard of the Rose", (21, 14), (42, 26)),
        area("halls", "The monastery halls", (18, 11), (45, 29)),
        area("cathedral", "The Sanguine Cathedral", (23, 2), (41, 9)),
        area("refectory", "The refectory", (2, 2), (15, 9)),
        area("cells", "The monastic cells", (2, 12), (16, 23)),
        area("kitchen", "The kitchen", (48, 2), (61, 9), private="sigmund_jaeger", open="flag.crimson_in and standing.crimson_faith >= 5"),
        area("larder", "The Dead Larder", (48, 11), (61, 18)),
        area("nooks", "The prayer nooks", (48, 23), (61, 29)),
    ]
    loc["spawns"] = {"default": [32, 39], "from_pass": [32, 39], "from_stables": [62, 36], "from_upstairs_a": [19, 12], "from_upstairs_b": [44, 28], "from_tower": [41, 5],
                     "from_sanctum": [32, 4], "larder": [54, 15], "from_vein": [32, 4]}
    loc["exits"] = [
        exit_("gate", (32, 41), "mon_pass", "from_monastery", "Out of the monastery gate", when="not jailed"),
        exit_("stables_gate", (63, 36), "mon_stables", "from_grounds", "The east gate to the stables", when="not jailed"),
        exit_("stairs_up_a", (19, 12), "mon_upper", "from_down_a", "Up the spiral stair", when="not jailed"),
        exit_("stairs_up_b", (44, 28), "mon_upper", "from_down_b", "Up the spiral stair", when="not jailed"),
        exit_("bell_tower_gate", (42, 5), "mon_bell_tower", "from_cathedral", "Through the Bell Tower Gate", when="flag.bell_gate_open and not jailed"),
        exit_("altar_shaft", (32, 3), "mon_holy_vein", "from_altar", "Down the shaft beneath the altar", when="flag.altar_open and not jailed"),
    ]
    loc["doors"] = [door("larder_door", (55, 10), locked=True, lock_dc=15, key="skeleton_key", locked_text="The larder door is barred from outside."),
                    door("cabin_door", (12, 36), locked=False)]
    loc["props"] = [
        talk("mon_pyre", (31, 20), "The pyre of six stakes", "flames:pyre_start", model="stake_bundle", approach=9, when="flag.dg_arrived and not flag.night_of_flames_done"),
        talk("mon_pyre_after", (31, 20), "The pyre, burnt down", "flames:pyre_cold", kind="decor", model="ash_heap", when="flag.night_of_flames_done"),
        talk("mon_aftermath", (32, 8), "The faithful, gathering", "aftermath:courtyard", kind="decor", approach=6, when="flag.hellfire_done and not flag.crimson_aftermath"),
        talk("mon_larder_wake", (54, 14), "The Dead Larder", "captives:larder_wake", kind="decor", approach=4, when="jailed and not flag.larder_woke"),
        talk("mon_shackles", (53, 15), "Shackles on the larder wall", "captives:shackles", model="wall_chains", when="flag.larder_woke and not flag.larder_out"),
        talk("mon_larder_axel_group", (57, 15), "Four shackled captives", "captives:group", model="skeleton_shackles", when="flag.crimson_in and not flag.crimson_captives_freed"),
        talk("mon_altar", (32, 4), "The altar, heaped with roses", "clues:altar", model="altar_church"),
        talk("mon_pulpit", (35, 5), "The stone pulpit", "clues:pulpit", model="lectern", kind="decor"),
        talk("mon_bell_gate", (41, 5), "The Bell Tower Gate", "clues:bell_gate", model="door_barred", when="not flag.bell_gate_open"),
        talk("mon_cabin_bench", (5, 34), "A butcher's worktable", "clues:workbook", model="workbench"),
        talk("mon_cell_row", (9, 17), "A row of bare cells", "faithful:cells", kind="decor", model="straw_pallet"),
        talk("mon_prayer_nook_a", (50, 25), "A prayer nook over the valley", "arrival:nook_view", model="window_tall"),
        talk("mon_halls_parishioners", (30, 12), "Murmuring prayers in the hall", "faithful:parishioners", kind="decor", approach=5, when="flag.crimson_in and not flag.halls_met"),
        talk("mon_halls_noise", (18, 22), "Hall doors with spikes on this side", "faithful:spiked_doors", kind="decor", model="door_carved"),
        prop("mon_banner_a", (23, 12), "A red-and-gold banner", kind="decor", model="festival_cloth"),
        prop("mon_banner_b", (40, 12), "A red-and-gold banner", kind="decor", model="festival_cloth"),
        prop("mon_banner_c", (23, 28), "A red-and-gold banner", kind="decor", model="festival_cloth"),
        prop("mon_banner_d", (40, 28), "A red-and-gold banner", kind="decor", model="festival_cloth"),
        prop("mon_candles_altar", (30, 3), "Candles heaped about the altar", kind="decor", model="candle_cluster"),
        prop("mon_candles_altar_b", (34, 3), "Candles heaped about the altar", kind="decor", model="candle_cluster"),
        prop("mon_corpse_platform", (32, 2), "A corpse on a platform, bleeding into a golden bowl", kind="decor", model="bier"),
        prop("mon_font", (25, 8), "A font of blood", kind="decor", model="stone_font"),
        prop("mon_kitchen_stove", (50, 4), "A stove with a vat of rendering fat", kind="decor", model="stove"),
        prop("mon_kitchen_pots", (57, 4), "Hounds' meat in tubs", kind="decor", model="tub_wooden"),
        prop("mon_larder_hook", (52, 13), "A corpse on a hook, in an inch of blood", kind="decor", model="carcass"),
        prop("mon_larder_hook_b", (59, 14), "An alpengrendel's carcass on a hook", kind="decor", model="carcass"),
        prop("mon_refectory_lectern", (8, 8), "A reader's lectern", kind="decor", model="lectern"),
        prop("mon_cabin_hides", (10, 35), "Hides and cleavers", kind="decor", model="tool_rack"),
        prop("mon_gate_brazier_a", (30, 38), "A brazier by the gate", kind="decor", model="brazier"),
        prop("mon_gate_brazier_b", (34, 38), "A brazier by the gate", kind="decor", model="brazier"),
        prop("mon_yard_cart", (50, 36), "A cart of firewood", kind="decor", model="cart_broken"),
        prop("mon_yard_wellhead", (22, 36), "A wellhead", kind="decor", model="well_stone"),
    ]
    for i, c in enumerate([(23, 4), (23, 8), (41, 8), (27, 15), (36, 15), (27, 25), (36, 25), (22, 20), (42, 20)]):
        loc["props"].append(prop(f"mon_statue_{i + 1}", c, "A weeping statue", kind="decor", model=["statue_saint", "statue_mother_night", "statue_knight"][i % 3]))
    stakes = [(29, 18), (29, 22), (31, 17), (31, 23), (33, 18), (33, 22)]
    for i, c in enumerate(stakes):
        loc["props"].append(prop(f"mon_stake_{i + 1}", c, "A stake", kind="decor", model="stake_bundle", when="not flag.night_of_flames_done"))
    for i, c in enumerate([(24, 28), (26, 28), (36, 29), (38, 29)]):
        loc["props"].append(prop(f"mon_hall_lamp_{i + 1}", c, "A red-glass lantern", kind="decor", model="lantern_bracket"))
    for i, c in enumerate([(3, 21), (7, 21), (11, 21), (15, 21), (3, 13), (7, 13), (11, 13), (15, 13)]):
        loc["props"].append(prop(f"mon_cell_{i + 1}", c, "A cell: a bed, a table, a rose carved in the floor", kind="decor", model="bed_small"))
    dress(loc, "mon_pew_n", [(25, 6), (27, 6), (37, 6), (39, 6)], "pew", "A pew")
    dress(loc, "mon_refectory_table", [(5, 4), (9, 4), (12, 4), (5, 7), (9, 7), (12, 7)], "table_set", "A refectory table")
    dress(loc, "mon_yard_barrel", [(4, 31), (15, 31), (58, 31), (58, 38), (45, 38)], "barrel", "A barrel")
    loc["npcs"] = [
        npc("gate_veteran_cm", (31, 37), "arrival:gate_guards", facing="south"),
        npc("faithful_novice", (26, 22), "faithful:novice", when="flag.crimson_in", facing="east"),
        npc("faithful_cook", (52, 6), "faithful:cook", when="flag.crimson_in"),
        npc("friar_olaf", (31, 6), "priors:olaf_start", when="flag.night_of_flames_done and not flag.mon_olaf_done and not flag.olaf_in_room"),
        npc("sigmund_jaeger", (8, 36), "priors:jaeger_start", when="flag.night_of_flames_done and not flag.mon_jaeger_done"),
        npc("leona_cromwell", (33, 29), "priors:cromwell_start", when="flag.night_of_flames_done and not flag.mon_cromwell_done and not flag.cromwell_in_room"),
        npc("father_renathyr", (32, 4), "renathyr:cathedral", when="flag.crimson_in and flag.renathyr_invited_cathedral and not flag.cathedral_audience_done"),
        npc("axel_farley", (57, 16), "captives:axel_start", when="flag.crimson_in and not flag.crimson_captives_freed and not flag.axel_freed"),
        npc("gareth_creed", (33, 18), "flames:urge_start", when="flag.night_of_flames_active and not flag.night_of_flames_done"),
    ]
    loc["encounters"] = [
        {"id": "mon_pyre_fight", "trigger": "dialogue", "flag": "mon_pyre_fight_done", "monsters": [
            monster("warrior_veteran", (28, 20), "A veteran of the pyre", facing="east"), monster("warrior_veteran", (38, 22), "A veteran of the pyre", facing="west"),
            monster("cultist_fanatic", (31, 16), "A cultist fanatic", facing="south"), monster("cultist_fanatic", (34, 24), "A cultist fanatic", facing="north"), monster("cultist_fanatic", (26, 20), "A cultist fanatic", facing="east")]},
        {"id": "mon_jaeger", "trigger": "dialogue", "flag": "mon_jaeger_done", "monsters": [
            monster("prior_jaeger", (8, 36), "Houndmaster Jaeger", facing="east"), monster("bat_hound", (6, 35), "A kennel hound", facing="east"), monster("bat_hound", (9, 36), "A kennel hound", facing="west")]},
        {"id": "mon_halls_clergy", "trigger": "dialogue", "flag": "mon_halls_clergy_done", "monsters": [
            monster("crimson_clergy", (30, 12), "Crimson clergy", facing="south"), monster("crimson_clergy", (34, 12), "Crimson clergy", facing="south"), monster("crimson_clergy", (32, 11), "Crimson clergy", facing="south")]},
        {"id": "mon_halls_hunt", "trigger": "dialogue", "flag": "mon_halls_hunt_done", "monsters": [
            monster("hunt_knight", (30, 28), "A Hunt knight", facing="north"), monster("bat_hound", (28, 28), "A bat hound", facing="north"), monster("bat_hound", (35, 28), "A bat hound", facing="north")]},
        {"id": "mon_halls_priests", "trigger": "dialogue", "flag": "mon_olaf_done", "monsters": [
            monster("prior_olaf", (31, 12), "Friar Olaf", facing="south"), monster("cultist_fanatic", (28, 12), "A cultist fanatic", facing="south"), monster("cultist_fanatic", (35, 12), "A cultist fanatic", facing="south")]},
    ]
    lights(loc, [(30, 3), (34, 3), (25, 20), (38, 20), (32, 36), (20, 12), (44, 12), (54, 15), (8, 36)], kind="torch", bright=25, dim=50, color="ember")
    return loc


# ---- the upper floor -----------------------------------------------------------------------------------------------------------------
def upper():
    g = G(52, 40).room(2, 2, 49, 37)
    g.fill(12, 2, 39, 27, " ")                                     # the courtyard and the cathedral roof are a drop
    # west wing: scriptorium (M7) above, the upper cells below
    g.wall(2, 14, 11, 14).fill(7, 14, 7, 14, ".")
    g.put([(3, 4), (4, 4), (5, 4), (8, 4), (9, 4), (10, 4), (3, 8), (4, 8), (5, 8), (8, 8), (9, 8), (10, 8), (3, 11), (4, 11), (8, 11), (9, 11)], "=")
    g.wall(6, 16, 6, 20).wall(6, 22, 6, 26).wall(2, 21, 11, 21).fill(3, 21, 3, 21, ".").fill(7, 21, 7, 21, ".")
    # east wing: Olaf's chambers (M8), the east hall, Cromwell's chambers (M9)
    g.wall(40, 2, 40, 11).wall(40, 12, 48, 12).fill(44, 12, 44, 12, ".")
    g.wall(40, 20, 48, 20).wall(40, 21, 40, 27).wall(48, 21, 48, 27).wall(40, 28, 48, 28).fill(44, 28, 44, 28, ".")
    g.put([(42, 4), (43, 4), (47, 4), (47, 5), (42, 8), (46, 9)], "=")
    g.put([(42, 23), (43, 23), (47, 23), (47, 24), (45, 26), (46, 26)], "=")
    g.put([(14, 31), (15, 31), (24, 31), (25, 31), (34, 31), (35, 31), (14, 34), (15, 34), (34, 34), (35, 34)], "=")
    rows = g.rows()
    loc = base("mon_upper", "The Crimson Monastery, Upper Floor", "crimson_monastery", rows, "manor", light="bright",
               summary="A second ring of halls over the courtyard: the scriptorium, cells, and the priors' locked chambers.", text="Red light through red glass. The scriptorium smells of ink and wax, and below the balustrade the courtyard waits.", rest="no")
    loc["areas"] = [area("scriptorium", "The scriptorium", (3, 3), (10, 13)), area("upper_cells", "The upper cells", (3, 15), (10, 27)), area("olaf_rooms", "Olaf's chambers", (41, 3), (48, 11), private="friar_olaf", open="flag.olaf_in_room"),
                    area("cromwell_rooms", "Cromwell's chambers", (41, 21), (47, 27), private="leona_cromwell", open="flag.cromwell_in_room"), area("upper_halls", "The upper halls", (3, 29), (48, 36)),
                    area("east_hall", "The east hall", (41, 13), (49, 19))]
    loc["spawns"] = {"default": [5, 35], "from_down_a": [5, 35], "from_down_b": [47, 35]}
    loc["exits"] = [exit_("down_a", (4, 37), "mon_ground", "from_upstairs_a", "Down the spiral stair"), exit_("down_b", (47, 37), "mon_ground", "from_upstairs_b", "Down the spiral stair")]
    loc["doors"] = [door("olaf_door", (44, 12), locked=True, lock_dc=15, key="skeleton_key", flag="olaf_in_room", locked_text="Olaf's door is locked."),
                    door("cromwell_door", (44, 28), locked=True, lock_dc=15, key="skeleton_key", flag="cromwell_in_room", locked_text="Cromwell's door is locked.")]
    loc["props"] = [
        talk("mon_scriptorium", (6, 6), "Lecterns of scripture", "clues:scriptorium", model="lectern"),
        talk("mon_olaf_missal", (46, 6), "Olaf's missal, on a stand", "clues:missal", model="book_stack", when="flag.olaf_in_room"),
        talk("mon_olaf_bell", (43, 8), "A drawing of the silver bell", "bell:olaf_drawing", model="drawings", when="flag.olaf_in_room"),
        talk("mon_cromwell_chest", (46, 24), "A locked trophy chest", "clues:trophy_chest", model="chest_iron", when="flag.cromwell_in_room"),
        talk("mon_upper_view", (20, 29), "A balustrade over the courtyard", "faithful:upper_view", kind="decor", model="wall_low"),
        prop("mon_upper_candles", (8, 5), "Beeswax candles, rendered from fat", kind="decor", model="candle_cluster"),
        prop("mon_upper_trophies", (45, 22), "Hunting trophies", kind="decor", model="trophy_wolf"),
        prop("mon_upper_stained", (46, 3), "A stained-glass window over the battlements", kind="decor", model="window_stained"),
        prop("mon_upper_books", (4, 12), "Blank books and paper", kind="decor", model="book_stack"),
        prop("mon_upper_tools", (9, 12), "Calligrapher's tools", kind="decor", model="instrument_tray"),
    ]
    dress(loc, "mon_upper_cell", [(4, 18), (8, 18), (4, 24), (8, 24)], "bed_small", "A bare cell")
    loc["npcs"] = [npc("friar_olaf", (46, 8), "priors:olaf_room", when="flag.olaf_in_room and not flag.mon_olaf_done"), npc("leona_cromwell", (45, 25), "priors:cromwell_room", when="flag.cromwell_in_room and not flag.mon_cromwell_done"),
                   npc("faithful_scribe", (7, 9), "faithful:scribe", when="flag.crimson_in")]
    loc["encounters"] = [
        {"id": "mon_olaf_room", "trigger": "dialogue", "flag": "mon_olaf_done", "monsters": [monster("prior_olaf", (46, 8), "Friar Olaf", facing="west")]},
        {"id": "mon_cromwell_room", "trigger": "dialogue", "flag": "mon_cromwell_done", "monsters": [monster("prior_cromwell", (45, 25), "Inquisitor Cromwell", facing="west")]},
    ]
    lights(loc, [(6, 6), (46, 6), (45, 24), (24, 33), (8, 33)], kind="torch", bright=25, dim=50, color="ember")
    return loc


# ---- the bell tower and the belfry ----------------------------------------------------------------------------------------------------
def bell_tower():
    g = G(28, 14).room(1, 1, 26, 12)
    g.wall(10, 1, 10, 12).fill(10, 9, 10, 10, ".")                  # the stair hall on the left, the landing on the right
    g.put([(3, 3), (4, 3), (3, 4), (4, 4)], "=")                    # the spiral's well
    g.put([(14, 4), (15, 4), (20, 4), (22, 4), (16, 9), (21, 9)], "=")
    loc = base("mon_bell_tower", "The Bell Tower", "crimson_monastery", g.rows(), "manor", light="dim", summary="Two floors of spiral stair, then a landing where bat hounds sleep, and a ladder to a trapdoor.", text="Cold stone, a spiral stair, and the stink of wet dog and bat.", rest="no")
    loc["areas"] = [area("tower_stair", "The spiral stair", (1, 1), (9, 12)), area("landing", "The landing", (11, 1), (26, 12))]
    loc["spawns"] = {"default": [5, 11], "from_cathedral": [5, 11], "from_belfry": [22, 3]}
    loc["exits"] = [exit_("tower_door", (5, 13), "mon_ground", "from_tower", "Back to the cathedral"), exit_("ladder_up", (22, 1), "mon_belfry", "from_ladder", "Up the ladder to the trapdoor")]
    loc["map"]["rows"][13] = loc["map"]["rows"][13][:5] + "." + loc["map"]["rows"][13][6:]
    loc["props"] = [
        prop("mon_bt_ladder", (22, 2), "A twenty-foot ladder to a trapdoor", kind="decor", model="roof_hatch"),
        prop("mon_bt_beds", (17, 10), "Straw beds fouled by dogs", kind="decor", model="straw_pallet"),
        prop("mon_bt_window", (26, 6), "A slit window over the valley", kind="decor", model="window_tall"),
        prop("mon_bt_bones", (14, 11), "Gnawed bones", kind="decor", model="bone_scatter"),
    ]
    loc["encounters"] = [{"id": "mon_landing", "trigger": "enter_area:landing", "when": "not flag.mon_landing_done and not flag.dagny_hounds_calmed", "waiting": True, "flag": "mon_landing_done", "monsters": [
        monster("bat_hound", (14, 8), "A sleeping bat hound", facing="east"), monster("bat_hound", (17, 6), "A sleeping bat hound", facing="east"), monster("bat_hound", (19, 10), "A sleeping bat hound", facing="north"),
        monster("bat_hound", (23, 7), "A sleeping bat hound", facing="west"), monster("bat_hound", (24, 11), "A sleeping bat hound", facing="north")]}]
    lights(loc, [(5, 6), (20, 8)], kind="torch", bright=15, dim=30, color="ember")
    return loc


def belfry():
    g = G(18, 18).room(1, 1, 16, 16)
    g.put([(3, 3), (14, 3), (3, 14), (14, 14)], "#")               # the four pillars
    loc = base("mon_belfry", "The Watchful Belfry", "crimson_monastery", g.rows(), "manor", light="dim", outdoors=True,
               summary="A wooden platform under a dome on four pillars: Olaf's great silver bell, braziers in red and orange, and hundreds of bats in the rafters.", text="Wind, bats, and the whole valley laid out below: Moonsong Lake's mist, and the lights of Wickermoor.", rest="no")
    loc["areas"] = [area("platform", "The platform", (1, 1), (16, 16))]
    loc["spawns"] = {"default": [8, 15], "from_ladder": [8, 15]}
    loc["exits"] = [exit_("trapdoor", (8, 17), "mon_bell_tower", "from_belfry", "Down the ladder")]
    loc["map"]["rows"][17] = loc["map"]["rows"][17][:8] + "." + loc["map"]["rows"][17][9:]
    loc["props"] = [
        talk("mon_bell", (8, 8), "Olaf's great silver bell", "bell:inscription", model="bell_tower"),
        talk("mon_belfry_vista", (14, 8), "The view over Moonsong Lake", "bell:vista", kind="decor", model="window_tall", approach=4, when="not flag.belfry_vista_seen"),
        talk("mon_belfry_renathyr", (8, 5), "A figure at the rail, watching the mist", "renathyr:belfry_talk", kind="decor", approach=5, when="(flag.cathedral_audience_done and not flag.belfry_talk_done and hour >= 3 and hour <= 6)"),
        prop("mon_brazier_a", (5, 5), "A brazier of red fire", kind="decor", model="brazier"),
        prop("mon_brazier_b", (12, 5), "A brazier of orange fire", kind="decor", model="brazier"),
        prop("mon_brazier_c", (5, 12), "A brazier of red fire", kind="decor", model="brazier"),
        prop("mon_brazier_d", (12, 12), "A brazier of orange fire", kind="decor", model="brazier"),
        prop("mon_rafters", (8, 2), "Rafters thick with sleeping bats", kind="decor", model="perch"),
    ]
    loc["npcs"] = [npc("father_renathyr", (8, 5), "renathyr:belfry_talk", when="(flag.cathedral_audience_done and not flag.belfry_talk_done and hour >= 3 and hour <= 6)")]
    loc["encounters"] = [{"id": "mon_belfry_fight", "trigger": "dialogue", "flag": "mon_belfry_done", "withdraw": {"who": "crimson_abbot_boss", "after_rounds": 2, "flag": "abbot_recalled"}, "monsters": [
        monster("crimson_abbot_boss", (8, 6), "Father Renathyr", facing="south", boss=True), monster("swarm_of_bats", (4, 10), "Bats from the rafters", facing="east"),
        monster("swarm_of_bats", (12, 10), "Bats from the rafters", facing="west"), monster("swarm_of_bats", (8, 12), "Bats from the rafters", facing="north")]}]
    lights(loc, [(5, 5), (12, 5), (5, 12), (12, 12)], kind="fire", bright=20, dim=40, color="ember")
    return loc


# ---- the Holy Vein, the Bloody Sanctum, the cathedral under the moon ----------------------------------------------------------------------
def holy_vein():
    g = G(38, 14).room(1, 5, 36, 8)
    g.fill(2, 5, 34, 8, "~")                                       # three feet of blood: Difficult Terrain
    g.fill(1, 5, 1, 8, ".")                                         # the foot of the shaft
    g.put([(14, 5), (22, 8), (27, 6)], "#")
    loc = base("mon_holy_vein", "The Holy Vein", "crimson_monastery", g.rows(), "cave", light="dark", summary="A rough tunnel, six feet high and three feet deep in blood, ending at a stone door.", text="The ceiling presses on your head and the blood is warm. Somewhere ahead, something wet moves.", rest="no")
    loc["areas"] = [area("shaft_foot", "The foot of the shaft", (1, 5), (3, 8)), area("vein", "The Holy Vein", (4, 5), (34, 8)), area("sealed_door", "The sealed door", (33, 5), (36, 8))]
    loc["spawns"] = {"default": [2, 6], "from_altar": [2, 6], "from_sanctum": [34, 6]}
    loc["exits"] = [exit_("shaft_up", (1, 4), "mon_ground", "from_vein", "Back up the shaft"), exit_("to_sanctum", (37, 6), "mon_sanctum", "from_vein", "Through the stone door", when="flag.sanctum_door_open")]
    loc["map"]["rows"][4] = loc["map"]["rows"][4][:1] + "." + loc["map"]["rows"][4][2:]
    loc["props"] = [
        talk("mon_vein_door", (36, 6), "A stone door under Arcane Lock", "clues:sanctum_door", model="portcullis", when="not flag.sanctum_door_open"),
        talk("mon_vein_warning", (4, 6), "Blood, three feet deep", "clues:vein_warning", kind="decor", model="puddle", approach=4, when="not flag.vein_warned"),
        prop("mon_vein_bones", (18, 7), "Bones in the blood", kind="decor", model="bones"),
        prop("mon_vein_roots", (26, 5), "Roots like veins in the ceiling", kind="decor", model="vines"),
    ]
    loc["encounters"] = [{"id": "mon_blood_elemental", "trigger": "enter_area:sealed_door", "when": "not flag.mon_elemental_done", "waiting": True, "flag": "mon_elemental_done", "monsters": [
        monster("blood_elemental", (33, 6), "A blood elemental", facing="west")]}]
    lights(loc, [(2, 6)], kind="torch", bright=10, dim=20, color="ember")
    return loc


def sanctum():
    g = G(26, 18).room(2, 2, 23, 15)
    g.fill(2, 2, 23, 15, "~")                                      # the blood channel
    g.fill(6, 5, 19, 12, ".")                                       # the stone island
    g.fill(10, 7, 15, 10, "_")                                      # the altar's dais
    g.put([(2, 2), (3, 2), (22, 2), (23, 2), (2, 15), (3, 15), (22, 15), (23, 15)], "#")
    g.fill(0, 8, 1, 9, ".")
    rows_ = None
    loc = base("mon_sanctum", "The Bloody Sanctum", "crimson_monastery", g.rows(), "cave", light="dim", summary="A vaulted chamber with a stone island and a round altar ringed by a moat of blood.", text="A chandelier lights polished stone. The altar is etched with a rose and drowned in dried roses, and beside it lies a painting of an elf-woman.", rest="no")
    loc["areas"] = [area("moat", "The blood channel", (2, 2), (23, 15)), area("island", "The stone island", (6, 5), (19, 12)), area("altar_dais", "The altar", (10, 7), (15, 10))]
    loc["spawns"] = {"default": [1, 8], "from_vein": [1, 8]}
    loc["exits"] = [exit_("back_to_vein", (0, 9), "mon_holy_vein", "from_sanctum", "Back into the Holy Vein", when="not flag.renathyr_fight_started")]
    loc["props"] = [
        talk("mon_sanctum_prefight", (12, 6), "Father Renathyr at the altar", "sanctum:prefight", kind="decor", approach=10, when="not flag.renathyr_fight_started and not flag.renathyr_slain"),
        talk("mon_sanctum_journal", (13, 8), "A journal on the altar", "clues:journal", model="book_stack", when="not flag.renathyr_journal"),
        talk("mon_sanctum_painting", (11, 8), "A painting of an elven woman", "clues:painting", model="portrait_tatyana", when="not flag.lethica_painting"),
        talk("mon_sanctum_roses", (12, 9), "Dried roses, heaped", "clues:roses", model="offering_pile", when="not flag.dried_roses"),
        talk("mon_sanctum_geyser", (12, 11), "The blood in the channel, stirring", "sanctum:geyser", kind="decor", approach=12, when="flag.renathyr_fallen_first and not flag.hellfire_seen"),
        prop("mon_sanctum_chandelier", (12, 4), "A chandelier of candles", kind="decor", model="skull_chandelier"),
    ]
    loc["encounters"] = []
    for (lv, hp, effs) in (("level <= 5", 85, 0), ("level >= 6 and level <= 7", 110, 0), ("level >= 8", 140, 2)):
        loc["encounters"].append({"id": "mon_abbot", "trigger": "dialogue", "flag": "renathyr_fallen_first", "when": lv,
                                  "monsters": [
            monster("crimson_abbot_boss", (12, 7), "Father Marius Renathyr", boss=True, facing="south", hp=hp)] + [
            monster("blood_effigy", c, "A blood effigy", facing="south") for c in [(8, 9), (17, 9)][:effs]]})
    lights(loc, [(12, 4), (7, 6), (18, 6)], kind="candle", bright=25, dim=50, color="ember")
    return loc


def cathedral_moon():
    g = G(20, 24).room(1, 1, 18, 22)
    g.fill(1, 1, 18, 22, "~")
    g.fill(2, 3, 8, 20, ".")
    g.fill(15, 9, 18, 14, "_")                                      # the altar, east
    g.put([(5, 3), (5, 7), (5, 11), (5, 15), (5, 19), (11, 5), (11, 17)], "=")
    loc = base("mon_cathedral_moon", "The Cathedral Under a Blood Moon", "crimson_monastery", g.rows(), "manor", light="dim", outdoors=True,
               summary="The cathedral on its side, altar east, blood on the floor and a red moon in the dome.", text="Stained glass in red and violet, statues weeping, and through the dome a moon the colour of a wound.", rest="no")
    loc["areas"] = [area("nave", "The cathedral", (1, 1), (18, 22)), area("altar_east", "The altar", (15, 9), (18, 14))]
    loc["spawns"] = {"default": [3, 12], "from_sanctum": [3, 12]}
    loc["exits"] = [exit_("down_the_shaft", (0, 12), "mon_ground", "from_sanctum", "Down the nave to the cathedral", when="flag.hellfire_done")]
    loc["map"]["rows"][12] = "." + loc["map"]["rows"][12][1:]
    loc["props"] = [
        talk("mon_hellfire", (14, 11), "The sword in the altar, and the windows", "sanctum:hellfire", kind="decor", approach=12, when="flag.renathyr_slain and not flag.hellfire_done"),
        talk("mon_altar_sword", (16, 11), "A sword buried in the altar", "sanctum:sword_altar", model="sword_leaning", when="flag.hellfire_done and flag.viraxys_offer == \"refused\" and not flag.sword_taken"),
        prop("mon_moon_windows", (10, 2), "Red and violet windows", kind="decor", model="window_stained"),
        prop("mon_moon_statue_a", (6, 6), "A weeping statue", kind="decor", model="statue_saint"),
        prop("mon_moon_statue_b", (6, 16), "A weeping statue", kind="decor", model="statue_saint"),
    ]
    loc["encounters"] = []
    lights(loc, [(16, 10), (16, 13)], kind="candle", bright=25, dim=50, color="ember")
    return loc
