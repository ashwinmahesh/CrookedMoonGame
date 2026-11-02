#!/usr/bin/env python3
"""ONE-SHOT (R15, The Drowned Crossroads). Writes the swamp trail (three nights), Murkwater Bend, the Bayou King's fort, the Marshwinder shack and
its approach, the lagoon, the riverboat Dead Man's Hand (promenade, hall, lower deck, captain's quarters) and the jinxcraft casino, their
people, quests (the main Withered Arm plus the Batch 3 side quests), flags, items, monsters, travel and cutscenes. Dialogue files are
narrative/drowned_crossroads/*.dialogue (drafted by Gemini through the ai-bridge, specs in tools/content/crossroads_specs.py).
Other lanes edit these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_crossroads.py"""
import copy, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import crossroads_maps as M
from heirlooms_kept import kept

ROOT = Path(__file__).resolve().parents[2]
REGION = "drowned_crossroads"
DC = "drowned_crossroads/"


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
        d["dialogue"] = DC + dialogue
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


def spots(rows, n, x0, x1, y0, y1, seed, avoid=(), gap=2):
    """n open '.' squares in the box, each at least `gap` from the others and from the squares in `avoid`."""
    import random
    r = random.Random(seed)
    cand = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if rows[y][x] == "."]
    r.shuffle(cand)
    out = []
    for c in cand:
        if all(max(abs(c[0] - o[0]), abs(c[1] - o[1])) >= gap for o in list(out) + list(avoid)):
            out.append(c)
        if len(out) == n:
            return out
    raise SystemExit(f"no {n} spots in the box ({x0},{y0})-({x1},{y1}); got {len(out)}")


def level_variants(base, drop=None, add=None):
    """The same fight three ways: a gentler one for heroes of level 5 or less, the book's for 6, a harder one for 7 or more.
    `base` is an encounter dict; drop/add are lists of monster entries removed from / added to it."""
    low, mid, high = copy.deepcopy(base), copy.deepcopy(base), copy.deepcopy(base)
    low["when"] = _and(base.get("when"), "level <= 5")
    mid["when"] = _and(base.get("when"), "level == 6")
    high["when"] = _and(base.get("when"), "level >= 7")
    if drop:
        low["monsters"] = [m for i, m in enumerate(low["monsters"]) if i not in drop]
    if add:
        high["monsters"] = high["monsters"] + add
    return [low, mid, high]


def _and(a, b):
    return f"({a}) and {b}" if a else b


LABEL = {}
ERRORS = []
SPAWN_CHECK = []   # (location id, spawn name) pairs checked by BFS


def room_loc(key, name, rows, light="dim", outdoors=False, theme="manor", rest="risky", summary="", text=""):
    return {"id": key, "name": name, "region": REGION, "summary": summary or f"{name}, in the Drowned Crossroads.", "text": text or f"The inside of {name}.",
            "map": {"rows": rows, "theme": theme, "light": light, "outdoors": outdoors}, "areas": [], "spawns": {}, "exits": [], "props": [], "npcs": [],
            "encounters": [], "rest": rest}


def finish(loc, start):
    """Writes a location after checking that every exit, NPC, monster and spawn can be reached on foot from `start`."""
    rows = loc["map"]["rows"]
    pts = [(f"spawn {k}", tuple(v)) for k, v in loc["spawns"].items()]
    pts += [(f"exit {e['id']}", tuple(e["cell"])) for e in loc["exits"]]
    pts += [(f"npc {n['npc']}", tuple(n["cell"])) for n in loc["npcs"]]
    for e in loc["encounters"]:
        pts += [(f"foe {e['id']}:{m['monster']}", tuple(m["cell"])) for m in e["monsters"]]
    bad = M.check(loc["id"], rows, start, pts)
    if bad:
        print("\n".join(bad))
        ERRORS.extend(bad)
    write(f"data/locations/{loc['id']}.json", loc)


# =============================================================================================================================
# the trail, three nights
# =============================================================================================================================
def build_trails():
    names = {1: "The Dry Hummock", 2: "The Deep Crossing", 3: "The Old Battlefield"}
    texts = {1: "A raised island of cypress roots in black water: dry enough for a fire, if you do not mind what watches from the reeds.",
             2: "A channel too deep to wade, spanned by one fallen log. The water between the cypress knees is very still.",
             3: "A green fog lies on the hummock where armed men and the dead met. Nothing here moves except what the fog moves."}
    out = {}
    for n in (1, 2, 3):
        key = f"dc_trail{n}"
        rows = M.LOCATIONS[key]()
        loc = room_loc(key, names[n], rows, light="dim", outdoors=True, theme="forest", text=texts[n], summary=texts[n].split(":")[0])
        loc["spawns"] = {"default": [3, 12], "from_west": [3, 12], "from_east": [36, 12]}
        prev = "travel" if n == 1 else f"dc_trail{n - 1}"
        nxt = f"dc_trail{n + 1}" if n < 3 else "dc_murkwater"
        loc["exits"] = [exit_("west", (0, 12), prev, "default" if n == 1 else "from_east", "The way back" if n > 1 else "The road back to Wickermoor"),
                        exit_("east", (39, 12), nxt, "from_west" if n < 3 else "from_trail", "On along the trail" if n < 3 else "Toward Murkwater Bend")]
        loc["areas"] = [area("trail", names[n], (1, 1), (38, 22))]
        loc["rest"] = "risky"
        loc["rest_text"] = "Something in the water is awake all night."
        loc["props"] = [prop(f"dc_t{n}_cypress{i}", c, "A bald cypress", kind="decor", model="dead_tree_a" if i % 2 else "dead_tree_b")
                        for i, c in enumerate([(8, 8), (11, 15), (30, 6), (33, 17), (14, 4), (26, 19)])]
        loc["props"] += [prop(f"dc_t{n}_reeds{i}", c, "Reeds", kind="decor", model="reeds") for i, c in enumerate([(9, 11), (24, 13), (31, 14)])]
        out[n] = loc
    # night 1: the Withered Hand, then a Bayou Beast; a dry camp
    t = out[1]
    t["props"] += [
        prop("dc_t1_fire", (19, 12), "The camp fire on the hummock", model="rocks"),
        prop("dc_t1_hand", (15, 11), "A withered hand at the edge of the light", kind="decor", call=DC + "trek:hand_comes", approach=7, call_when="not flag.dc_hand_seen"),
        prop("dc_t1_remains", (24, 10), "Splintered wood and a hexed mask", kind="examine", dialogue=DC + "trek:beast_remains", when="flag.dc_beast_done and not flag.dc_beast_lore"),
    ]
    t["encounters"] = level_variants({"id": "dc_beast_camp", "trigger": "dialogue", "flag": "dc_beast_done", "quest": {"id": "withered_arm", "stage": "trek"},
                                      "monsters": [monster("bayou_beast", (25, 10), "The Bayou Beast", facing="west")]})
    # night 2: the crossing, crocodiles
    t = out[2]
    t["props"] += [
        prop("dc_t2_log", (19, 11), "The fallen log", kind="decor", model="broken_boards"),
        prop("dc_t2_crossing", (13, 12), "The channel, black and still", kind="decor", call=DC + "trek:crossing", approach=4, call_when="not flag.dc_croc_started"),
        prop("dc_t2_hide", (24, 14), "A crocodile's glyph-scarred hide", kind="examine", dialogue=DC + "trek:croc_arcana", when="flag.dc_croc_done and not flag.dc_croc_lore"),
    ]
    croc = {"id": "dc_croc_crossing", "trigger": "dialogue", "flag": "dc_croc_done",
            "monsters": [monster("giant_crocodile", (15, 7), "A glyph-scarred crocodile", facing="east"), monster("giant_crocodile", (24, 17), "A glyph-scarred crocodile", facing="west"),
                         monster("crocodile", (15, 15), facing="east"), monster("crocodile", (24, 8), facing="west"), monster("crocodile", (15, 20), facing="east"),
                         monster("crocodile", (24, 20), facing="west")]}
    plain = level_variants(croc, drop=[5, 4, 3, 2], add=[monster("crocodile", (15, 3), facing="east")])
    # low-level party: one giant and two crocodiles; high: a seventh
    plain[0]["monsters"] = [croc["monsters"][0], croc["monsters"][2], croc["monsters"][3]]
    ambushed = copy.deepcopy(plain)
    for e in ambushed:
        e["when"] = _and("flag.dc_croc_ambush", e["when"])
        e["surprise"] = "party"
    for e in plain:
        e["when"] = _and("not flag.dc_croc_ambush", e["when"])
    t["encounters"] = ambushed + plain
    # night 3: the ghoul ambush in green fog
    t = out[3]
    rows = t["map"]["rows"]
    t["spawns"]["default"] = [3, 12]
    ghoul_cells = spots(rows, 9, 14, 30, 5, 19, seed=3, avoid=[(3, 12), (4, 12)], gap=2)
    ghouls = [monster("ghoul", c, facing="west") for c in ghoul_cells[:8]] + [monster("ferryman", ghoul_cells[8], "The Ferryman", facing="west")]
    t["props"] += [
        prop("dc_t3_bones", (17, 10), "Bones and torn purple cloth", kind="decor", model="bone_scatter"),
        prop("dc_t3_cart", (22, 15), "A smashed strongbox cart", kind="decor", model="cart"),
        prop("dc_t3_banners", (25, 12), "A purple-and-black banner in the mud", kind="examine", dialogue=DC + "trek:battlefield_clue", when="not flag.dc_clue_banner"),
        prop("dc_t3_fog", (12, 12), "The green fog", kind="decor", call=DC + "trek:battlefield", approach=4, call_when="not flag.dc_ghoul_started"),
    ]
    t["encounters"] = level_variants({"id": "dc_ghoul_ambush", "trigger": "dialogue", "flag": "dc_ghoul_done", "monsters": ghouls}, drop=[0, 1], add=[monster("ghoul", ghoul_cells[0], facing="west")])
    for n in (1, 2, 3):
        finish(out[n], (3, 12))
    return out


# =============================================================================================================================
# Murkwater Bend
# =============================================================================================================================
def build_murkwater():
    rows = M.LOCATIONS["dc_murkwater"]()
    loc = room_loc("dc_murkwater", "Murkwater Bend", rows, light="dim", outdoors=True, theme="village", rest="risky",
                   summary="A stilt town of lamplit shacks and rope bridges over black water, and a purple-and-black flag over a wooden fort.",
                   text="Murkwater Bend stands on stilts among bald cypress: shacks, boathouses and trader's stalls joined by swaying walkways, lanterns hung in moss, and at its heart a fort flying purple and black.")
    loc["rest_text"] = "The walkways creak all night, and the water talks to itself under them."
    loc["spawns"] = {"default": [28, 41], "from_trail": [28, 41], "from_fort": [28, 16], "from_north": [28, 2], "from_dock": [49, 33]}
    loc["areas"] = [
        area("dc_gate", "The south gate", (24, 36), (32, 43)), area("dc_boathouses", "The boathouses", (4, 20), (15, 36)),
        area("dc_pits", "The fight pits", (40, 19), (53, 29)), area("dc_traders", "Traders' Row", (26, 33), (48, 38)),
        area("dc_church", "The Mud Church", (5, 5), (13, 16)), area("dc_mooring", "The Ferryman's mooring", (48, 31), (53, 36)),
        area("dc_cookshack", "Mama Pelletier's cookshack", (41, 40), (47, 42)), area("dc_fort_apron", "The fort apron", (27, 15), (29, 18)),
        area("dc_north_gate", "The north gate", (24, 0), (32, 4)), area("dc_walks", "The walkways", (1, 1), (54, 42)),
    ]
    loc["exits"] = [
        exit_("south_gate", (28, 43), "dc_trail3", "from_east", "Back down the trail"),
        exit_("fort_gate", (28, 14), "dc_fort", "from_gate", "The Bayou King's fort"),
        exit_("north_gate", (28, 0), "dc_shack_approach", "from_town", "The Marshwinder Road, north", when="flag.screams_done"),
        exit_("north_gate_early", (27, 0), "dc_shack_approach", "from_town", "The Marshwinder Road, north", when="not flag.screams_done and flag.vander_met and flag.dc_fort_rested"),
    ]
    loc["npcs"] = [
        npc("lyla_webb", (28, 39), "town:lyla_gate", when="not flag.lyla_met", approach=7),
        npc("lyla_webb", (31, 35), "town:lyla_talk", when="flag.lyla_met and not flag.grinning_sinner_slain"),
        npc("lyla_webb", (31, 35), "town:lyla_after", when="flag.grinning_sinner_slain"),
        npc("luckless_lou", (47, 24), "side_king:lou_start", when="flag.vander_met and not flag.king_asked"),
        npc("luckless_lou", (47, 24), "side_king:lou_progress", when="flag.king_asked and not flag.king_outcome"),
        npc("luckless_lou", (47, 24), "side_king:lou_after", when="flag.king_outcome"),
        npc("mama_pelletier", (44, 41), "folk:mama"), npc("tibby_marsh", (30, 29), "folk:tibby"),
        npc("ferryman_chauffeur", (50, 33), "side_coins:ferryman_start", when="flag.lyla_met and not flag.coins_asked"),
        npc("ferryman_chauffeur", (50, 33), "side_coins:ferryman_progress", when="flag.coins_asked and not flag.coins_outcome"),
        npc("odell_tarrant", (12, 22), "side_ledger:odell", when="flag.vander_met"),
        npc("maude_ledoux", (45, 21), "side_ledger:maude", when="flag.vander_met"),
        npc("bo_gaspard", (36, 36), "folk:bo", when="flag.vander_met"),
        npc("cora_beaudry", (21, 27), "side_print:cora_start", when="flag.shack_met and not flag.print_asked"),
        npc("cora_beaudry", (21, 27), "side_print:cora_progress", when="flag.print_asked and not flag.print_outcome"),
        npc("odalys_thibault", (9, 13), "side_wedding:thibault_start", when="flag.vander_met and not flag.wedding_asked"),
        npc("odalys_thibault", (9, 13), "side_wedding:thibault_progress", when="flag.wedding_asked and not flag.wedding_outcome"),
        npc("marguerite_salt", (7, 13), "side_wedding:bride", when="flag.wedding_asked and not flag.wedding_outcome"),
        npc("ignatius_fontaine", (12, 13), "side_wedding:groom", when="flag.wedding_asked and not flag.wedding_outcome"),
        npc("vander_boone", (28, 20), "vander:vander_after", when="flag.grinning_sinner_slain and not flag.vander_settled"),
    ]
    loc["props"] = [
        prop("dc_reveal", (28, 38), "Murkwater Bend, lamplit on its stilts", kind="decor", call=DC + "town:reveal", approach=9, call_when="not flag.dc_town_seen"),
        prop("dc_flag", (28, 17), "The purple-and-black flag over the fort", kind="decor", model="lantern_bracket"),
        prop("dc_lyla_stall", (30, 36), "Lyla Webb's stall: charms, jewellery and loose change", model="table_round"),
        prop("dc_pit_ring", (46, 24), "The sunk ring of the fight pits", kind="decor", model="fence"),
        prop("dc_pit_board", (42, 21), "The pit board, chalked with odds", model="notice_board", dialogue=DC + "folk:pit_board"),
        prop("dc_boathouse_ledger", (13, 22), "A boathouse tally board", model="ledger", dialogue=DC + "side_ledger:tally_board", when="flag.ledger_asked"),
        prop("dc_church_door", (9, 12), "The Mud Church's plank door", kind="decor", model="door"),
        prop("dc_church_bell", (11, 13), "A cracked ship's bell", model="lantern_post", dialogue=DC + "side_wedding:bell", when="flag.wedding_asked"),
        prop("dc_church_plate", (6, 14), "The Mud Church's collection plate", model="bench", dialogue=DC + "side_coins:thibault_coin", when="flag.coins_asked and not flag.coin_church"),
        prop("dc_ferry_boat", (51, 35), "A coffin boat, tied at the mooring", kind="decor", model="rocks"),
        prop("dc_trader_barrels", (33, 36), "Barrels of pickled things", kind="decor", model="barrel"),
        prop("dc_trader_nets", (41, 36), "Hanging nets and crab traps", kind="decor", model="rope"),
        prop("dc_small_print_board", (35, 31), "A scrawled tally of who bought what, and what came of it", model="notice_board", dialogue=DC + "side_print:board", when="flag.print_asked"),
        prop("dc_gumbo_pot", (43, 41), "A black pot that is never the same twice", kind="decor", model="jars"),
        prop("dc_pit_stakes", (48, 22), "The bookie's coin box", model="case", dialogue=DC + "side_coins:pit_coin", when="flag.coins_asked and not flag.coin_pits"),
    ]
    for i, c in enumerate([(26, 18), (30, 18), (14, 20), (38, 24), (22, 30), (34, 30), (28, 8), (28, 33), (40, 36), (6, 17)]):
        loc["props"].append(prop(f"dc_lantern{i}", c, "A moss-hung lantern", kind="decor", model="lantern_post"))
    for i, c in enumerate([(16, 17), (20, 18), (36, 17), (42, 29), (24, 38), (47, 38), (16, 30), (38, 30)]):
        loc["props"].append(prop(f"dc_crate{i}", c, "Crates and coiled rope", kind="decor", model="case" if i % 2 else "rope_coils"))
    loc["lights"] = [{"cell": [28, 30], "kind": "lamp", "bright_ft": 20, "dim_ft": 40}, {"cell": [28, 16], "kind": "lamp", "bright_ft": 20, "dim_ft": 40},
                     {"cell": [46, 28], "kind": "lamp", "bright_ft": 20, "dim_ft": 40}, {"cell": [10, 28], "kind": "lamp", "bright_ft": 20, "dim_ft": 40}]
    finish(loc, (28, 41))
    return loc


# =============================================================================================================================
# the fort
# =============================================================================================================================
def build_fort():
    rows = M.LOCATIONS["dc_fort"]()
    loc = room_loc("dc_fort", "The Bayou King's Fort", rows, light="dim", theme="manor", rest="safe",
                   summary="A palisade fort crowded with refugees, with a cramped throne hall of mismatched plush furniture.",
                   text="Inside the palisade a yard full of refugees, bandits in tribute and enforcers in purple and black. Beyond it a cramped throne hall of mismatched plush furniture and a cushioned chair by a window.")
    loc["rest_text"] = "The fort is full, but the guest room has beds, and it holds until the dead come."
    loc["spawns"] = {"default": [17, 23], "from_gate": [17, 23], "from_run": [17, 23]}
    loc["areas"] = [area("dc_yard", "The yard", (1, 13), (32, 24)), area("dc_throne_hall", "The throne hall", (13, 1), (32, 11)), area("dc_guest_room", "The guest room", (1, 1), (11, 11))]
    loc["exits"] = [exit_("gate", (17, 25), "dc_murkwater", "from_fort", "Out through the gate")]
    loc["npcs"] = [
        npc("vander_boone", (22, 5), "vander:throne", when="not flag.vander_met"),
        npc("vander_boone", (22, 5), "vander:throne_again", when="flag.vander_met and not flag.screams_done"),
        npc("vander_boone", (22, 5), "vander:fort_after", when="flag.dc_screams_done"),
        npc("lyla_webb", (20, 7), "town:lyla_fort", when="flag.vander_met and not flag.screams_done"),
        npc("fort_refugee", (6, 17), "folk:refugee", when="not flag.screams_done"), npc("fort_refugee", (26, 17), "folk:refugee", when="not flag.screams_done"),
        npc("fort_enforcer", (14, 14), "folk:enforcer", when="not flag.screams_done"),
    ]
    loc["props"] = [
        prop("dc_dice_table", (29, 9), "A card table, a leather cup and five dice", model="table_round", dialogue=DC + "vander:dice_start", when="flag.vander_met and not flag.vander_dice"),
        prop("dc_dice_table_after", (29, 9), "The card table, cups put away", model="table_round", dialogue=DC + "side_king:table_watch", when="flag.vander_dice"),
        prop("dc_window_chair", (30, 5), "The cushioned chair by the window", model="armchair"),
        prop("dc_guest_bed", (3, 3), "A bed in the guest room", model="bed", dialogue=DC + "vander:dinner_rest", when="flag.vander_dinner and not flag.dc_fort_rested"),
        prop("dc_fort_sleep", (8, 3), "A bed that has seen worse nights", model="bed"),
        prop("dc_wall_alarm", (17, 22), "The dead, at the palisade", kind="decor", call=DC + "vander:screams", approach=5, call_when="flag.dc_fort_rested and not flag.screams_done"),
        prop("dc_plush", (14, 6), "A plush sofa from three different houses", kind="decor", model="settee"),
        prop("dc_throne_rug", (20, 9), "A rug that was a banner once", kind="decor", model="rug_runner"),
        prop("dc_bedrolls", (25, 15), "Bedrolls and a child's wooden boat", kind="decor", model="rags"),
    ]
    waves = [(5, "dc_wave_one"), (10, "dc_wave_two")]
    ev = [{"id": wid, "name": "More of the dead", "summary": "More dead hands come over the palisade.", "kind": "summon", "affects": "enemies", "monster": "ghast", "count": 2, "side": "enemies",
           "cells": [[3, 14], [30, 14]], "at": 20, "from_round": r, "every": 99, "times": 1, "say": "More of the dead come over the wall."} for (r, wid) in waves]
    base = {"id": "dc_screams", "trigger": "dialogue", "flag": "dc_screams_done", "quest": {"id": "withered_arm", "stage": "the_shack"},
            "monsters": [monster("ghast", (7, 17), facing="east"), monster("ghast", (12, 21), facing="east"), monster("ghast", (21, 21), facing="west"), monster("ghast", (28, 19), facing="west"),
                         monster("ferryman", (17, 18), "The Ferryman at the gate", facing="south")], "round_events": ev}
    loc["encounters"] = level_variants(base, drop=[1], add=[monster("ghast", (3, 22), facing="east")])
    loc["lights"] = [{"cell": [17, 6], "kind": "candle", "bright_ft": 15, "dim_ft": 30, "color": "candle"}, {"cell": [8, 18], "kind": "lamp", "bright_ft": 20, "dim_ft": 40}]
    finish(loc, (17, 23))
    return loc


# =============================================================================================================================
# the shack, its approach, the lagoon
# =============================================================================================================================
def build_shack():
    rows = M.LOCATIONS["dc_shack_approach"]()
    loc = room_loc("dc_shack_approach", "The Marshwinder Approach", rows, light="dim", outdoors=True, theme="forest",
                   summary="Paired glowing bottles float as buoys along a path of plank boards to a lit shack on stilts.",
                   text="Mournful strings drift across the water. Pairs of glowing bottles bob on black water, marking a path of boards to a lit shack on stilts. Off the path, the water is four feet of cold mud.")
    loc["spawns"] = {"default": [14, 28], "from_town": [14, 28], "from_shack": [14, 3], "from_lagoon": [14, 2]}
    loc["areas"] = [area("dc_causeway", "The bottle path", (10, 4), (19, 28)), area("dc_beast_bay", "The shallows to the west", (2, 8), (9, 20)), area("dc_porch", "The shack's porch", (11, 1), (17, 3))]
    loc["exits"] = [exit_("south", (14, 29), "dc_murkwater", "from_north", "Back toward Murkwater Bend"),
                    exit_("ladder", (14, 2), "dc_shack", "from_ladder", "Up the ladder to the shack"),
                    exit_("north", (14, 0), "dc_lagoon", "from_shack", "The Marshwinder Road, north", when="flag.crossroads_passage or flag.crossroads_refused")]
    loc["props"] = [
        prop("dc_rocker", (13, 3), "A rocking chair, and a steel guitar rocking on its seat", model="rocking_chair", dialogue=DC + "shack:guitar"),
        prop("dc_buoy_call", (14, 22), "Bottles glowing in pairs", kind="decor", call=DC + "shack:arrive", approach=6, call_when="not flag.shack_met"),
        prop("dc_bay_bottle", (6, 14), "A single bottle, glowing alone", model="jars", dialogue=DC + "shack:bay_bottle", when="not flag.dc_bay_done"),
    ]
    for i, c in enumerate([(14, 26), (15, 24), (17, 21), (13, 19), (12, 16), (14, 14), (16, 11), (14, 8), (15, 6)]):
        loc["props"].append(prop(f"dc_buoy{i}", c, "A pair of glowing bottles", kind="decor", model="jars"))
    bay = {"id": "dc_beast_bay", "trigger": "enter_area:dc_beast_bay", "flag": "dc_bay_done", "monsters": [monster("bayou_beast", (4, 12), "The Bayou Beast", facing="east")]}
    loc["encounters"] = level_variants(bay)
    loc["lights"] = [{"cell": [14, 6], "kind": "lamp", "bright_ft": 20, "dim_ft": 40, "color": "bile"}]
    finish(loc, (14, 28))
    # the shack
    rows = M.LOCATIONS["dc_shack"]()
    sh = room_loc("dc_shack", "The Marshwinder Shack", rows, light="dim", theme="tavern", rest="no",
                  summary="A one-room shack of trinkets under neon sigils, every tag marked 3 CP.",
                  text="Warm firelight from outside proves false. The room is cluttered with trinkets and bottles glowing neon green and magenta under sigils; carved idols and woven dolls crowd the shelves, each with a paper tag reading 3 CP. A spiral stair rises into darkness.")
    sh["rest_text"] = "Not here."
    sh["spawns"] = {"default": [5, 7], "from_ladder": [5, 7]}
    sh["areas"] = [area("dc_shack_room", "The shack", (1, 1), (9, 7))]
    sh["exits"] = [exit_("ladder", (5, 8), "dc_shack_approach", "from_shack", "Down the ladder")]
    sh["npcs"] = [npc("mister_crossroads", (5, 4), "shack:parley", when="flag.shack_met and not flag.crossroads_passage and not flag.crossroads_refused and not flag.sinner_gone")]
    sh["props"] = [
        prop("dc_shack_idols", (3, 2), "Idols and dolls, each tagged 3 CP", model="doll", dialogue=DC + "shack:steal_one", when="flag.crossroads_refused and not flag.crossroads_passage"),
        prop("dc_shack_stair", (5, 1), "A spiral stair into darkness", kind="decor", model="rope"),
        prop("dc_shack_bottles", (8, 2), "Bottles glowing magenta", kind="decor", model="jars"), prop("dc_shack_tags", (2, 6), "A tag: 3 CP", kind="decor", model="papers"),
        prop("dc_shack_doll", (7, 6), "A woven doll with your size of hands", kind="decor", model="doll"),
    ]
    stalk = {"id": "dc_shack_stalkers", "trigger": "dialogue", "flag": "dc_stalkers_done", "monsters": [monster("bayou_beast", (5, 3), "The Bayou Beast", facing="south")] + [
        monster("stirge", c, "A jinxed mosquito", facing="south") for c in [(2, 3), (8, 3), (4, 5), (6, 5), (2, 5), (8, 5)]]}
    sh["encounters"] = level_variants(stalk, drop=[6, 5], add=[monster("stirge", (3, 4), "A jinxed mosquito", facing="south")])
    sh["lights"] = [{"cell": [5, 3], "kind": "lamp", "bright_ft": 15, "dim_ft": 30, "color": "bile"}]
    finish(sh, (5, 7))
    # the lagoon
    rows = M.LOCATIONS["dc_lagoon"]()
    lg = room_loc("dc_lagoon", "Dead Man's Lagoon", rows, light="dim", outdoors=True, theme="forest", rest="risky",
                  summary="A mangrove-ringed lake with a neon riverboat at its heart.",
                  text="A mangrove-ringed lake. At its centre a riverboat is moored, funnels coughing magenta, a gangplank down to a mud island. Heroes without a token see only a wreck, split in two, with part of an old name in faded paint.")
    lg["rest_text"] = "The reeds hiss all night."
    lg["spawns"] = {"default": [2, 15], "from_shack": [2, 15], "from_boat": [26, 16]}
    lg["areas"] = [area("dc_landing", "The landing", (1, 13), (6, 17)), area("dc_island", "The mud island", (22, 11), (29, 19))]
    lg["exits"] = [exit_("road_south", (0, 14), "dc_shack_approach", "from_lagoon", "The Marshwinder Road, south"),
                   exit_("gangplank", (26, 15), "dc_boat_promenade", "from_gangplank", "Up the gangplank", when="flag.dc_boarded")]
    lg["npcs"] = [npc("ferryman_chauffeur", (5, 15), "lagoon:dock", when="flag.crossroads_passage and not flag.dc_boarded"),
                  npc("ferryman_chauffeur", (5, 15), "lagoon:wreck_ferryman", when="not flag.crossroads_passage and flag.lagoon_seen")]
    lg["props"] = [
        prop("dc_lagoon_view", (4, 14), "The lagoon, and what is moored in it", kind="decor", call=DC + "lagoon:view", approach=8, call_when="not flag.lagoon_seen"),
        prop("dc_wreck", (24, 13), "A wreck, split in two, with faded letters", model="broken_boards", when="not flag.crossroads_passage", dialogue=DC + "lagoon:wreck"),
        prop("dc_riverboat", (24, 13), "The riverboat Dead Man's Hand, funnels coughing magenta", kind="decor", model="lantern_bracket", when="flag.crossroads_passage"),
        prop("dc_cutlass", (9, 15), "Something steel glowing under the water", kind="search", search_dc=13, item="cutlass_of_briggsy_kratch", when="treasure_at:murkwater_swamp_water"),
    ]
    finish(lg, (2, 15))
    return loc, sh, lg


# =============================================================================================================================
# the riverboat
# =============================================================================================================================
def build_boat():
    out = {}
    rows = M.LOCATIONS["dc_boat_promenade"]()
    p = room_loc("dc_boat_promenade", "The Dead Man's Hand: Promenade", rows, light="bright", theme="tavern", rest="no",
                 summary="The top decks of a ghostly riverboat casino, crowded with glassy-eyed revellers.",
                 text="Neon soulfire, green and magenta. The deck circles the ship, crowded with well-dressed revellers whose eyes will not quite meet yours, and holds the balcony over the hall. Catchy jazz comes from everywhere.")
    p["rest_text"] = "The jazz does not let anyone rest."
    p["spawns"] = {"default": [3, 9], "from_gangplank": [3, 9], "from_hall_up": [22, 12], "from_captain": [42, 3]}
    p["areas"] = [area("dc_gangplank", "Dead Man's Gangplank", (1, 7), (6, 12)), area("dc_top_deck", "The top deck", (2, 1), (44, 4)), area("dc_balcony", "The balcony", (7, 6), (44, 14))]
    p["exits"] = [exit_("gangplank", (0, 8), "dc_lagoon", "from_boat", "Down the gangplank"),
                  exit_("to_hall", (22, 13), "dc_boat_hall", "from_balcony", "Stairs down to the Gambling Hall"),
                  exit_("to_captain", (43, 2), "dc_boat_captain", "from_stairs", "Stairs up to the Captain's Quarters")]
    p["npcs"] = [npc("bellhop_zombie", (8, 8), "lagoon:bellhops", when="not flag.dc_bellhops_ok and not flag.dc_bellhops_done"),
                 npc("elias_greaves", (30, 9), "boat:elias_mute", when="flag.dc_boarded and not flag.elias_freed and not flag.elias_met"),
                 npc("elias_greaves", (30, 9), "boat:elias_again", when="flag.elias_met and not flag.elias_freed"),
                 npc("boat_reveler", (14, 3), "boat:reveler"), npc("boat_reveler", (35, 11), "boat:reveler")]
    p["props"] = [prop("dc_flag_skull", (6, 3), "A black flag with a crocodile skull", kind="decor", model="lantern_bracket"),
                  prop("dc_paddle", (44, 8), "A paddle wheel that never turns", kind="decor", model="gate")]
    p["lights"] = [{"cell": [22, 8], "kind": "lamp", "bright_ft": 30, "dim_ft": 60, "color": "bile"}]
    out["promenade"] = p
    p["encounters"] = level_variants({"id": "dc_bellhops", "trigger": "dialogue", "flag": "dc_bellhops_done",
                                      "monsters": [monster("ogre_zombie", (10, 8), "A bellhop", facing="west"), monster("ogre_zombie", (10, 10), "A bellhop", facing="west")]}, drop=[1])
    finish(p, (3, 9))
    rows = M.LOCATIONS["dc_boat_hall"]()
    h = room_loc("dc_boat_hall", "The Dead Man's Hand: Gambling Hall", rows, light="bright", theme="tavern", rest="no",
                 summary="Card, dice and roulette tables, a five-skeleton jazz band, and chandeliers over cursed gamblers.",
                 text="Card, dice and roulette tables, racing figurines of enchanted horses, a long bar, and on a stand a five-skeleton jazz band. Undead dealers and barmen, ghoul waiters and ogre bellhops. Tall windows in mirrored walls.")
    h["rest_text"] = "No."
    h["spawns"] = {"default": [21, 21], "from_balcony": [21, 21], "from_below": [21, 21], "from_casino": [21, 14]}
    h["areas"] = [area("dc_gambling_hall", "The Gambling Hall", (1, 1), (40, 22)), area("dc_band", "The jazz band's stand", (2, 2), (12, 5)), area("dc_bar", "The bar", (16, 2), (38, 3))]
    h["exits"] = [exit_("stairs_up", (20, 0), "dc_boat_promenade", "from_hall_up", "Up to the promenade"),
                  exit_("stairs_down", (21, 23), "dc_boat_lower", "from_hall", "Down to the lower deck")]
    h["npcs"] = [npc("boat_dealer", (9, 8), "boat:dealer"), npc("boat_gambler", (18, 12), "boat:gambler", when="not flag.dc_hall_brawl_done"),
                 npc("boat_gambler", (27, 13), "boat:gambler", when="not flag.dc_hall_brawl_done"),
                 npc("elias_greaves", (21, 18), "boat:elias_again", when="flag.dc_hall_help and not flag.elias_freed")]
    h["props"] = [
        prop("dc_hall_table_dice", (17, 10), "A dice table", model="table_round", dialogue=DC + "boat:wager"),
        prop("dc_hall_table_cards", (26, 16), "A half-moon card table", model="table_round", dialogue=DC + "boat:wager"),
        prop("dc_hall_roulette", (35, 10), "A roulette table", model="table_round", dialogue=DC + "boat:wager"),
        prop("dc_hall_window", (39, 12), "The tall mirrored windows", model="window", dialogue=DC + "boat:window"),
        prop("dc_hall_deck", (8, 18), "A table with a hexed deck of cards", model="table_round", dialogue=DC + "boat:hexed_deck"),
        prop("dc_hall_bar", (28, 3), "The bar, and a barman with copper on his eyes", model="shelves", dialogue=DC + "boat:barman"),
        prop("dc_hall_band", (6, 3), "Five skeletons, a trumpet, a trombone, a piano, a clarinet and drums", kind="decor", model="bone_scatter"),
        prop("dc_hall_horses", (32, 20), "Enchanted horse figurines, racing", model="rocking_horse", dialogue=DC + "boat:wager"),
    ]
    h["encounters"] = level_variants({"id": "dc_hall_brawl", "trigger": "dialogue", "flag": "dc_hall_brawl_done", "monsters": (
        [monster("ghoul", c, "A ghoul waiter", facing="south") for c in [(10, 12), (14, 18), (24, 7), (28, 19), (33, 14), (37, 18)]] +
        [monster("ogre_zombie", c, "A bellhop", facing="south") for c in [(6, 15), (36, 8)]])}, drop=[0, 1, 6], add=[monster("ghoul", (30, 8), "A ghoul waiter", facing="south")])
    h["lights"] = [{"cell": [10, 10], "kind": "lamp", "bright_ft": 30, "dim_ft": 60, "color": "bile"}, {"cell": [30, 10], "kind": "lamp", "bright_ft": 30, "dim_ft": 60, "color": "bile"}]
    out["hall"] = h
    finish(h, (21, 21))
    # the lower deck
    rows = M.LOCATIONS["dc_boat_lower"]()
    lo = room_loc("dc_boat_lower", "The Dead Man's Hand: Lower Deck", rows, light="dim", theme="tavern", rest="no",
                  summary="The boiler room, the coin vault, the galley and the quarters.",
                  text="Corridors of bare plank under bright pipes. The galley smells of superb food; the boiler room at the stern glows magenta.")
    lo["rest_text"] = "No."
    lo["spawns"] = {"default": [4, 9], "from_hall": [4, 9]}
    lo["areas"] = [area("dc_corridor", "The corridor", (1, 9), (50, 10)), area("dc_boiler", "B4: Boiler Room", (41, 1), (50, 7)), area("dc_vault", "B5: Coin Vault", (31, 1), (39, 7)),
                   area("dc_galley", "B6: Galley", (13, 12), (29, 18)), area("dc_quarters", "B7: Crew and Guest Quarters", (1, 12), (11, 18)), area("dc_stores", "Storerooms", (1, 1), (29, 7))]
    lo["exits"] = [exit_("stairs_up", (0, 9), "dc_boat_hall", "from_below", "Up to the Gambling Hall")]
    lo["doors"] = [{"id": "dc_boiler_door", "cell": [44, 8], "locked": False, "lock_dc": 0, "key": "", "secret_dc": 0},
                   {"id": "dc_vault_door", "cell": [34, 8], "locked": True, "lock_dc": 15, "key": "coin_keepers_key", "secret_dc": 0, "locked_text": "A soggy hold behind an iron door."}]
    lo["containers"] = [
        {"id": "dc_vault_cage", "cell": [37, 4], "label": "The iron cage and its coin sacks", "items": [], "gold": 710, "lock_dc": 20, "flag": "coin_vault_looted"},
        {"id": "dc_keeper_desk", "cell": [47, 9], "label": "A drawer of keys", "items": [{"id": "coin_keepers_key", "qty": 1}], "gold": 0, "lock_dc": 0}]
    lo["npcs"] = [npc("soulfire_engineer", (47, 5), "boat:engineer", when="not flag.dc_boiler_done"),
                  npc("coin_keeper", (35, 6), "boat:keeper", when="not flag.dc_keeper_done"),
                  npc("elias_greaves", (8, 9), "boat:elias_again", when="flag.dc_boiler_lead and not flag.elias_freed")]
    lo["props"] = [
        prop("dc_boiler", (46, 4), "A coffin-shaped boiler glowing magenta, stamped Stranger Ferryworks", model="case", dialogue=DC + "boat:boiler_open", when="flag.dc_boiler_done and not flag.elias_freed"),
        prop("dc_boiler_cold", (46, 4), "The boiler, gone cold", kind="decor", model="case", when="flag.elias_freed"),
        prop("dc_boiler_stamp", (45, 3), "Stranger Ferryworks, stamped into the iron", dialogue=DC + "boat:ferryworks", when="not flag.dc_boiler_done"),
        prop("dc_galley_drinks", (17, 15), "Superb food and strong drinks", model="table_meal", dialogue=DC + "boat:galley"),
        prop("dc_galley_chefs", (22, 16), "Dead chefs, working", kind="decor", model="table_round"),
        prop("dc_quarters_bunks", (5, 15), "Crew bunks and guest cots", kind="decor", model="bed"),
        prop("dc_hand_trail", (8, 10), "A withered hand, tugging toward the stern", kind="decor", model="rags", when="flag.withered_hand_taken and not flag.dc_boiler_done"),
    ]
    boiler = {"id": "dc_boiler_fight", "trigger": "dialogue", "flag": "dc_boiler_done", "quest": {"id": "withered_arm", "stage": "elias"},
              "monsters": [monster("soulfire_engineer", (47, 4), "The Soulfire Engineer", facing="west"), monster("specter", (43, 2), facing="south"), monster("specter", (45, 6), facing="south"),
                           monster("specter", (49, 2), facing="west"), monster("specter", (49, 6), facing="west"), monster("specter", (42, 6), facing="east"),
                           monster("soulfire_stoker", (44, 4), "The Soulfire Stoker", facing="west")],
              "round_events": [{"id": "blasting_furnace", "name": "The Blasting Furnace", "summary": "The furnace vents: everyone but the spirits takes fire.", "kind": "save", "affects": "party",
                                "save": {"ability": "dex", "dc": 13}, "half": True, "damage": {"dice": "2d6", "type": "fire"}, "at": 20, "every": 1, "area": {"cells": [[41, 1], [50, 7]]},
                                "say": "The furnace roars, and the room is fire."}]}
    keep = {"id": "dc_vault_fight", "trigger": "dialogue", "flag": "dc_keeper_done", "monsters": [monster("wight", (35, 6), "The Coin Keeper", facing="west")] + [
        monster("ghast", c, "A swamp-covered ghast", facing="south") for c in [(32, 3), (38, 3), (32, 6), (38, 6)]] + [
        monster("ghoul", c, facing="south") for c in [(33, 2), (36, 2), (39, 2), (31, 4), (39, 4), (31, 7), (35, 7), (39, 7)]]}
    lo["encounters"] = (level_variants(boiler, drop=[5], add=[monster("specter", (48, 4), facing="west")]) +
                        level_variants(keep, drop=[1, 2, 5, 6, 9, 10], add=[monster("ghoul", (34, 1), facing="south")]))
    out["lower"] = lo
    finish(lo, (4, 9))
    # the captain's quarters
    rows = M.LOCATIONS["dc_boat_captain"]()
    cap = room_loc("dc_boat_captain", "The Dead Man's Hand: Captain's Quarters", rows, light="bright", theme="manor", rest="no",
                   summary="A nautical museum of a captain's cabin, and a desk etched with jinxcraft.",
                   text="A black flag with a crocodile skull, tattered flags of other crews, a ship in a bottle, a huge sigil-etched blunderbuss on the wall, and a desk etched with jinxcraft.")
    cap["rest_text"] = "No."
    cap["spawns"] = {"default": [11, 12], "from_stairs": [11, 12]}
    cap["areas"] = [area("dc_cabin", "The Captain's Quarters", (1, 1), (22, 12))]
    cap["exits"] = [exit_("door", (11, 13), "dc_boat_promenade", "from_captain", "Down to the promenade")]
    cap["npcs"] = [npc("mister_crossroads", (11, 5), "sinner:invite", when="flag.dc_boarded and not flag.dc_sinner_done and not flag.sinner_roll_started"),
                   npc("mister_crossroads", (11, 5), "sinner:invite_again", when="flag.sinner_roll_started and not flag.sinner_dice and not flag.dc_sinner_done")]
    cap["props"] = [
        prop("dc_cap_blunderbuss", (21, 3), "A huge sigil-etched blunderbuss on the wall", kind="decor", model="stag_head"),
        prop("dc_cap_bottle", (6, 4), "A ship in a bottle", model="jars", dialogue=DC + "sinner:ship_bottle"),
        prop("dc_cap_desk", (11, 3), "A desk etched with jinxcraft", model="table_round", dialogue=DC + "sinner:desk"),
    ]
    out["captain"] = cap
    finish(cap, (11, 12))
    return out


def build_casino():
    rows = M.LOCATIONS["dc_casino"]()
    cs = room_loc("dc_casino", "The Jinxcraft Casino", rows, light="bright", theme="manor", rest="no",
                  summary="The Gambling Hall stretched into a demiplane: 2 ft of glowing bayou water, a balcony all round, and a coffin on four legs for a dice table.",
                  text="The hall stretches. Tall windows rise through walls etched with skeletal serpents, grown over with swamp vines. 2 ft of glowing green water covers the floor. At the centre, a coffin stands on four legs, with dice on its lid.")
    cs["rest_text"] = "No."
    cs["spawns"] = {"default": [8, 23], "from_hall": [8, 23]}
    cs["areas"] = [area("dc_casino_floor", "The floor", (3, 3), (14, 24)), area("dc_balcony_ring", "The balcony", (1, 1), (16, 24))]
    cs["exits"] = [exit_("back_to_hall", (8, 25), "dc_boat_hall", "from_casino", "Back into the real hall", when="flag.grinning_sinner_slain")]
    cs["npcs"] = []
    cs["props"] = [
        prop("dc_jack_coffin", (8, 12), "Snake Eye Jack's coffin, on four legs", model="case", kind="examine", dialogue=DC + "sinner:coffin", when="not flag.grinning_sinner_slain"),
        prop("dc_jack_coffin_shut", (8, 12), "The coffin, lid shut, a crocodile skull cut in it", kind="decor", model="case", when="flag.grinning_sinner_slain"),
        prop("dc_after_call", (8, 20), "The still hall, and the body at the table", kind="decor", call=DC + "sinner:after", approach=9, call_when="flag.dc_sinner_done and not flag.sinner_after_seen"),
        prop("dc_blunderbuss", (7, 13), "The Sinner's blunderbuss in his dead hands", kind="search", search_dc=5, item="blunderbuss_of_the_grinning_sinner", when="flag.dc_sinner_done and treasure_at:dead_mans_hand_casino"),
    ]
    boss = {"id": "dc_sinner", "trigger": "enter_area:dc_casino_floor", "flag": "dc_sinner_done", "lair": True, "quest": {"id": "withered_arm", "stage": "return"},
            "monsters": [monster("grinning_sinner_boss", (8, 7), "Mister Crossroads, the Grinning Sinner", boss=True, facing="south")],
            "round_events": [{"id": "jacks_ferrymen", "name": "Snake Eye Jack's Ferrymen", "summary": "Three Ferrymen rise at Jack's call, 10 Hit Points each.", "kind": "summon", "affects": "enemies",
                              "monster": "ferryman_husk", "count": 3, "side": "enemies", "cells": [[5, 8], [8, 9], [12, 8]], "at": 20, "from_round": 2, "every": 99, "times": 1,
                              "say": "Jack's Influence: three Ferrymen climb out of the water."}]}
    low = copy.deepcopy(boss); mid = copy.deepcopy(boss); high = copy.deepcopy(boss)
    low["when"], mid["when"], high["when"] = "level <= 5", "level == 6", "level >= 7"
    low["monsters"][0]["hp"] = 118
    high["monsters"].append(monster("ferryman_husk", (4, 10), "A Ferryman of Jack's", facing="east"))
    high["monsters"].append(monster("ferryman_husk", (12, 10), "A Ferryman of Jack's", facing="west"))
    cs["encounters"] = [low, mid, high]
    cs["lights"] = [{"cell": [8, 12], "kind": "lamp", "bright_ft": 30, "dim_ft": 60, "color": "bile"}]
    finish(cs, (8, 23))
    return cs


# =============================================================================================================================
# people
# =============================================================================================================================
PEOPLE = [   # id, name, title, summary, attitude, extras
    ("mister_crossroads", "Mister Crossroads", "The Grinning Sinner", "A lizardfolk gentleman in a good coat with a slow laugh, who calls himself a humble sinner and keeps your soul in a ledger.", "friendly", {"monster": "grinning_sinner"}),
    ("elias_greaves", "Elias Greaves", "A gambler's ghoul", "A gaunt waiter in an ill-fitting suit, eye pits and peeling skin, mute, one arm a stump. His soul burns in the boiler.", "friendly", {}),
    ("vander_boone", "Vander Boone", "The Bayou King", "A big, bald man in a purple top hat who crowned himself king and means to protect his town. Canny, with a gambler's swagger.", "indifferent", {}),
    ("lyla_webb", "Lyla Webb", "The King's advisor", "A brisk young woman in a purple coat hung with charms, who fences goods and prays quietly to Snake Eye Jack.", "friendly", {}),
    ("soulfire_engineer", "The Soulfire Engineer", "A boiler spirit", "A grey wraith in an engineer's cap who tends the furnace and would rather you left first.", "indifferent", {}),
    ("coin_keeper", "The Coin Keeper", "Vault guard", "A wight in a clerk's sleeve-garters, guarding a soggy hold.", "hostile", {}),
    ("ferryman_chauffeur", "The Ferryman", "A coffin-boat chauffeur", "A silent boatman with copper coins on his eyes and brow, waiting to be paid.", "indifferent", {}),
    ("bellhop_zombie", "A bellhop", "An ogre zombie in a pillbox hat", "A very large dead man in a very small hat, holding a very small bag.", "indifferent", {}),
    ("boat_dealer", "The dealer", "An undead dealer", "A pale dealer with copper on his eyes, shuffling without looking.", "indifferent", {}),
    ("boat_gambler", "A glassy-eyed gambler", "A cursed patron", "A living gambler in evening dress, smiling too long.", "friendly", {}),
    ("boat_reveler", "A reveler", "A cursed patron", "A well-dressed guest who is having a wonderful time and cannot say why.", "friendly", {}),
    ("luckless_lou", "Luckless Lou", "A gambler with a system", "A cheerful man who has lost every hand he ever played and insists it is a system.", "friendly", {}),
    ("mama_pelletier", "Mama Pelletier", "Cook", "A broad, unhurried cook whose gumbo is never the same twice.", "friendly", {"shop": {"sells": [{"id": "ration", "qty": -1}], "markup": 1.0, "sell_rate": 0.0}}),
    ("tibby_marsh", "Tibby Marsh", "A bayou child", "A quick child who carries messages along the walkways for pennies.", "friendly", {}),
    ("odell_tarrant", "Odell Tarrant", "Boathouse clerk", "A neat, nervous clerk with new boots.", "indifferent", {}),
    ("maude_ledoux", "Maude Ledoux", "Pit boss", "A scarred woman who ran Vander's fights and runs them still, honestly, at a loss.", "indifferent", {}),
    ("bo_gaspard", "Bo Gaspard", "Fish seller", "A trader of smoked eel who counts coins twice and prices by the mood.", "indifferent", {}),
    ("cora_beaudry", "Cora Beaudry", "A widow", "A tidy woman in mended black whose husband took a trinket from a shack on the road.", "friendly", {}),
    ("odalys_thibault", "Reverend Odalys Thibault", "Minister of the Mud Church", "A long-suffering minister of a church that floods weekly, who has stopped expecting the groom.", "friendly", {}),
    ("marguerite_salt", "Marguerite Salt", "A bride", "A bride in a hurry, sensible about everything but her cousin.", "friendly", {}),
    ("ignatius_fontaine", "Ignatius Fontaine", "A groom", "A groom with cold feet and a warm heart, sitting on the church step in his good boots.", "friendly", {}),
    ("fort_refugee", "A refugee", "A townsperson in the fort", "A Murkwater local sleeping in the fort's yard, with a bundle and a bad feeling.", "friendly", {}),
    ("fort_enforcer", "An enforcer", "A man in a purple-and-black suit", "One of the King's six enforcers, very serious about his suit.", "indifferent", {}),
]


def build_people():
    for (nid, name, title, summary, att, extra) in PEOPLE:
        d = {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION}
        d.update(extra)
        write(f"data/npcs/{nid}.json", d)


# =============================================================================================================================
# quests
# =============================================================================================================================
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
    write("data/quests/withered_arm.json", {
        "id": "withered_arm", "name": "The Withered Arm", "kind": "main", "region": REGION, "giver": "adela_druskenvald",
        "summary": "Lady Adela's left arm is withering since she traded her wedding ring in the Drowned Crossroads. Find the deal-maker, and a cure.",
        "stages": [
            stage("asked", "In the Witching Hour Adela showed us her arm, grey and nearly skeletal to the elbow, and begged us to find the one who took her ring.", "Take the road to the Drowned Crossroads.", ["Cross the swamp"]),
            stage("trek", "Three nights of swamp. The first brought a withered hand to the fire, then a Bayou Beast out of the reeds.", "Follow the trail to Murkwater Bend.", ["Reach Murkwater Bend"]),
            stage("murkwater", "Murkwater Bend stands on stilts, and Lyla Webb met us at the gate and took us to the Bayou King.", "Hear Vander Boone out, and rest in the fort.", ["Meet the Bayou King"]),
            stage("fort_falls", "The dead came over the fort wall in the night.", "Get out, or hold the yard, and then go north on the Marshwinder Road.", ["Survive the night"]),
            stage("the_shack", "Six hours up the Marshwinder Road a shack on stilts sits in black water, and a steel guitar plays on its porch.", "Meet the one who lives there.", ["Meet Mister Crossroads", "Take a deal, or a trinket"]),
            stage("aboard", "Every one of us took something from the Grinning Sinner, and it bought us passage to his riverboat, the Dead Man's Hand.", "Cross Dead Man's Lagoon and go aboard.", ["Board the Dead Man's Hand"]),
            stage("elias", "A mute waiter named Elias Greaves wants to be freed; the boiler on the lower deck burns his soul.", "Open the boiler on the lower deck.", ["Free Elias", "Optional: the Withered Hand leads the way"]),
            stage("roll_the_bones", "The Grinning Sinner has a challenge: a game of Liar's Dice for his ship and our souls.", "Meet him in the Captain's Quarters.", ["Play, or refuse"]),
            stage("bayou_boogie", "The dice are done, and Mister Crossroads means to kill us anyway.", "Defeat the Grinning Sinner.", ["Defeat the Grinning Sinner"]),
            stage("return", "The Grinning Sinner is gone, dragged into Jack's coffin. The riverboat is quiet, and the way back lies open.", "Go home to Wickermoor and tell Adela.", ["Return to Adela"]),
            stage("done", "Adela's arm is whole again.", ends="success")]})
    write("data/quests/a_hand_with_the_king.json", {
        "id": "a_hand_with_the_king", "name": "A Hand with the King", "kind": "side", "region": REGION, "giver": "luckless_lou",
        "summary": "Luckless Lou swears the Bayou King's table is rigged. Prove it, or lose the last of his money trying.",
        "stages": [
            stage("asked", "Lou says Vander and Lyla signal under the table. He wants the proof, and the pot.", "Watch the table, or the two of them, and come back to Lou.", ["Find how they cheat"]),
            stage("proof", "We know how it is done: a cough, a boot, a pair of fingers.", "Take it to Vander or to Lyla, or tell Lou.", ["Decide what to do with it"]),
            stage("done", "The matter is settled, one way or another.", ends="success"),
            stage("lost", "We were caught at the table, and Lou lost his last coin.", ends="failure")]})
    write("data/quests/lylas_ledger.json", {
        "id": "lylas_ledger", "name": "Lyla's Ledger", "kind": "side", "region": REGION, "giver": "lyla_webb",
        "summary": "Coin is going missing between the pits, the boathouses and the market, and Lyla wants the skimmer without telling Vander.",
        "stages": [
            stage("asked", "Someone is skimming Murkwater's coin. Lyla wants three tallies checked: the boathouses, the pits, Traders' Row.", "Check the boathouse board, ask the pit boss, and look at Traders' Row.", ["Check three tallies"]),
            stage("done", "The skimmer is named, and the town knows it.", ends="success"),
            stage("lost", "We named the wrong person, and the pits closed over it.", ends="failure")]})
    write("data/quests/the_ferrymans_coins.json", {
        "id": "the_ferrymans_coins", "name": "The Ferryman's Coins", "kind": "side", "region": REGION, "giver": "ferryman_chauffeur",
        "summary": "The coffin-boat Ferryman will give safe passage to anyone who pays him, but only in copper, and only one coin from each district.",
        "stages": [
            stage("asked", "The Ferryman wants four copper coins, one from the pits, the boathouses, Traders' Row and the Mud Church.", "Gather a coin from each district.", ["Four coppers"]),
            stage("paid", "He has his four coppers, and his curse is lifted from us.", ends="success"),
            stage("lost", "We offered gold, and the Ferryman stepped into the water.", ends="failure")]})
    write("data/quests/the_sinners_small_print.json", {
        "id": "the_sinners_small_print", "name": "The Sinner's Small Print", "kind": "side", "region": REGION, "giver": "cora_beaudry",
        "summary": "Cora Beaudry wants the cost of the Sinner's wares written down where the town can read it.",
        "stages": [
            stage("asked", "Cora's husband took a trinket from the shack. She wants the true price of each ware written on the town board.", "Collect three cautionary tales from the town.", ["Gather three tales"]),
            stage("read", "We have three tales and the small print.", "Take them to Cora, or keep them.", ["Decide what to do with the tales"]),
            stage("done", "The town board reads the small print.", ends="success"),
            stage("lost", "We took a deal before Cora knew the price, and she has left town.", ends="failure")]})
    write("data/quests/a_wedding_at_the_mud_church.json", {
        "id": "a_wedding_at_the_mud_church", "name": "A Wedding at the Mud Church", "kind": "side", "region": REGION, "giver": "odalys_thibault",
        "summary": "Marguerite Salt and Ignatius Fontaine are to marry at the Mud Church tonight, and nothing is ready.",
        "stages": [
            stage("asked", "The Reverend needs three things: the ring Lou pawned, music, and a supper.", "Find the ring, music and supper.", ["Ring, music, supper"]),
            stage("done", "They were married, more or less.", ends="success"),
            stage("lost", "We gave up, and the wedding was called off.", ends="failure")]})


# =============================================================================================================================
# flags
# =============================================================================================================================
FLAGS = [
    ("crossroads_asked", "bool", "The party agreed to help Adela."), ("adela_secret_kept", "bool", "The party swore to keep Adela's trip from Phillip."), ("adela_hex_seen", "bool", "Adela's withered arm, worse, after the first chapter."),
    ("dc_hand_seen", "bool", "The Withered Hand came to the fire."), ("withered_hand_taken", "bool", "A hero took the Withered Hand."), ("dc_beast_done", "bool", "Night 1's Bayou Beast is over."), ("dc_beast_lore", "bool", "The mask was read."),
    ("dc_croc_started", "bool", "The deep crossing began."), ("dc_croc_ambush", "bool", "The party missed the crocodiles."), ("dc_croc_done", "bool", "Night 2's crocodiles are over."), ("dc_croc_lore", "bool", "The hide's glyphs were read."),
    ("dc_ghoul_started", "bool", "Night 3's fog began."), ("dc_ghoul_done", "bool", "Night 3's ghouls are over."), ("dc_clue_banner", "bool", "The party knows the dead brigands were the King's crew."),
    ("dc_town_seen", "bool", "The party saw Murkwater Bend from the south gate."), ("lyla_met", "bool", "Lyla met the party at the gate."), ("lyla_jack_known", "bool", "The party learned Lyla serves Snake Eye Jack."), ("vander_met", "bool", "The party met the Bayou King."),
    ("vander_dinner", "bool", "Dinner with Vander."), ("dc_fort_rested", "bool", "The party slept at the fort."), ("vander_dice", "string", "Liar's Dice with Vander: won or lost."), ("vander_pay", "int", "Gold each Vander has promised."),
    ("vander_lied_to", "bool", "The party lied to Vander about their pay."), ("vander_settled", "bool", "Vander paid up."), ("dice_score", "int", "Rounds won in the game being played."),
    ("screams_done", "bool", "The fort's night is over (fled or fought)."), ("screams_fled", "bool", "The party ran north."), ("dc_screams_done", "bool", "The fort fight is over."),
    ("shack_met", "bool", "The party reached the shack."), ("dc_bay_done", "bool", "The bay Bayou Beast is over."), ("dc_stalkers_done", "bool", "The shack's Swamp Stalkers are over."),
    ("sinner_deals", "int", "Deals and wares taken at the shack (one a hero)."), ("crossroads_passage", "bool", "The party holds tokens and may board."), ("crossroads_refused", "bool", "The party refused the Sinner's wares."),
    ("sinner_gone", "bool", "Mister Crossroads left the shack."), ("lagoon_seen", "bool", "The party saw the lagoon."), ("dc_boarded", "bool", "The coffin boat took the party aboard."), ("dc_bellhops_ok", "bool", "The bellhops let the party pass."),
    ("dc_bellhops_done", "bool", "The bellhop fight is over."), ("elias_met", "bool", "The party met Elias."), ("dc_boiler_lead", "bool", "Elias is leading the party to the boiler."), ("dc_boiler_done", "bool", "The boiler room fight is over."),
    ("elias_freed", "bool", "Elias's soul is back in his body."), ("dc_ring_taken", "bool", "The party has Adela's wedding ring."), ("adela_ring", "string", "Adela's ring: returned or kept."),
    ("dc_hall_help", "bool", "Elias helped in the hall."), ("dc_hall_brawl_done", "bool", "The hall brawl is over."), ("dc_keeper_done", "bool", "The vault fight is over."), ("coin_vault_looted", "bool", "The cage was looted."),
    ("sinner_roll_started", "bool", "The Sinner made his challenge."), ("sinner_dice", "string", "Liar's Dice with the Sinner: won or lost."), ("jack_boon", "bool", "Snake Eye Jack's boon is the party's."),
    ("dc_sinner_done", "bool", "The boss fight is over."), ("grinning_sinner_slain", "bool", "The Grinning Sinner is dead."), ("sinner_after_seen", "bool", "The party saw the Sinner go."),
    ("adela_cured", "bool", "Adela is healed."), ("crossroads_done", "bool", "The Drowned Crossroads is finished."), ("high_roller_cursed", "int", "A hero finished a game of chance aboard."), ("dc_window_seen", "bool", "The mirrored windows were studied."),
    # side quests
    ("king_asked", "bool", "Lou asked for proof against Vander."), ("king_proof", "bool", "The party knows how Vander and Lyla signal."), ("king_outcome", "string", "A Hand with the King: exposed, rematch or kept."),
    ("ledger_asked", "bool", "Lyla asked for the skimmer."), ("ledger_boathouse", "bool", "The boathouse tally was read."), ("ledger_pits", "bool", "The pit boss's tally was read."), ("ledger_traders", "bool", "Traders' Row was checked."),
    ("ledger_outcome", "string", "Lyla's Ledger: right, wrong or quiet."), ("pits_closed", "bool", "The pits closed over a wrong accusation."),
    ("coins_asked", "bool", "The Ferryman asked for four coppers."), ("ferry_coins", "int", "Copper coins gathered."), ("coin_pits", "bool", "The pits' copper."), ("coin_boathouses", "bool", "The boathouses' copper."),
    ("coin_traders", "bool", "Traders' Row copper."), ("coin_church", "bool", "The church's copper."), ("coins_outcome", "string", "The Ferryman's Coins: paid or insulted."), ("ferryman_paid", "bool", "The Ferryman was paid in copper."),
    ("print_asked", "bool", "Cora asked for the small print."), ("print_tales", "int", "Cautionary tales gathered."), ("print_lou", "bool", "Lou's tale."), ("print_odell", "bool", "Odell's tale."), ("print_mama", "bool", "Mama's tale."),
    ("small_print_read", "bool", "The party knows the true price of the wares."), ("print_outcome", "string", "Small print: posted or kept."), ("deal_taken_blind", "bool", "A deal was taken before the small print was read."),
    ("wedding_asked", "bool", "The Reverend asked for a wedding."), ("wedding_ring", "bool", "The ring is found."), ("wedding_music", "bool", "Music is found."), ("wedding_supper", "bool", "Supper is found."), ("wedding_score", "int", "How many things are ready."),
    ("wedding_outcome", "string", "The wedding: held or called off."), ("lou_ring_known", "bool", "Lou pawned the ring."), ("gumbo_tasted", "bool", "Mama's gumbo was tasted."),
    ("bo_met", "bool", "The party met Bo Gaspard."), ("lou_system", "int", "Lou's system, explained."), ("tibby_hired", "bool", "Tibby was paid for a message."),
]
DEAL_FLAGS = ["bestial_awakening", "call_of_the_lonely", "collector_of_stories", "crooked_fortune", "cult_of_personality", "hand_of_death", "might_of_the_old", "self_serving_sacrifice",
              "shrouded_spirit", "skin_of_coffin_nails", "stilled_hungers", "unquenchable_fury", "wings_of_whispers"]
WARES = ["lilypad_tonic", "jinxed_rum", "silence_of_the_drowned", "elixir_of_fogwalking", "harvest_brew", "nightwatcher_potion", "sight_of_sin", "tincture_of_mourning", "wytchwood_sap",
         "nectar_of_the_green_man", "draught_of_the_red_hunger", "haint_hooch", "the_bag", "green_ribbon", "amber_birdcage"]


def build_flags():
    fl = [{"id": i, "type": t, "summary": s, "read_later": True} for (i, t, s) in FLAGS]
    fl += [{"id": "deal_" + g, "type": "bool", "summary": f"The party took the {g.replace('_', ' ')} bargain.", "read_later": True} for g in DEAL_FLAGS]
    fl += [{"id": "ware_" + w, "type": "bool", "summary": f"The party took {w.replace('_', ' ')} from the shack.", "read_later": True} for w in WARES]
    write("data/flags/crossroads.json", {"flags": fl})


# =============================================================================================================================
# items, monsters, travel, cutscenes
# =============================================================================================================================
def build_items():
    items = [
        ("adelas_wedding_ring", "Adela's wedding ring", "treasure", "The ring Adela traded away. Return it to her, or keep it: it is worth a thousand gold.", 1000),
        ("coin_keepers_key", "The Coin Keeper's key", "quest", "A heavy iron key from the vault wight's drawer.", 0),
        ("sinners_tag", "A tag: 3 CP", "quest", "A paper tag with a price on it, the proof that you bought something from the shack.", 0),
    ]
    for (iid, name, cat, summary, cost) in items:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 0, "cost_gp": cost, "summary": summary})
    write("data/magic_items/withered_hand.json", {
        "id": "withered_hand", "name": "The Withered Hand", "source": {"book": "CrookedMoon", "note": "Cursed curio from the Drowned Crossroads; the book's numbers, our words."},
        "category": "wondrous", "weight_lb": 0, "cost_gp": 0, "magic": {"rarity": "rare", "attunement": True, "cursed": True,
        "curse": "Each Long Rest in which you used it, your Hit Point maximum drops by 1 for good. (Reference only; the game does not roll it yet.)"},
        "theme": "implements", "icon": "ring",
        "summary": "A tattooed, desiccated hand that attunes on touch. +1 to spell attacks and spell save DCs; its Withering Grasp reaches 30 ft on magenta threads. Cursed: each Long Rest after use costs 1 maximum Hit Point for good (reference only)."})
    write("data/magic_items/cutlass_of_briggsy_kratch.json", {
        "id": "cutlass_of_briggsy_kratch", "name": "Cutlass of Briggsy Kratch", "source": {"book": "CrookedMoon", "note": "Fabled Heirloom (Wheel of Fortune)."},
        "category": "weapon", "weight_lb": 3, "cost_gp": 0, "magic": {"rarity": "rare", "attunement": True}, "theme": "armaments", "icon": "scimitar",
        "modifiers": [{"stat": "attack", "value": "tier", "when": {"item": "@self"}}, {"stat": "damage", "value": "tier", "when": {"item": "@self"}}],
        "summary": "A pirate captain's scimitar, +1 (+2 at level 7, +3 at 13). Its Raise the Stakes and Sea Legs powers wait on the engine's heirloom rules.",
        "weapon": {"kind": "martial_melee", "damage": "1d6", "damage_type": "slashing", "properties": ["finesse", "light"], "mastery": "nick"}})
    write("data/magic_items/blunderbuss_of_the_grinning_sinner.json", {
        "id": "blunderbuss_of_the_grinning_sinner", "name": "Blunderbuss of the Grinning Sinner", "source": {"book": "CrookedMoon", "note": "Fabled Heirloom (The Emperor)."},
        "category": "weapon", "weight_lb": 10, "cost_gp": 0, "magic": {"rarity": "rare", "attunement": True}, "theme": "armaments", "icon": "crossbow",
        "modifiers": [{"stat": "attack", "value": "tier", "when": {"item": "@self"}}, {"stat": "damage", "value": "tier", "when": {"item": "@self"}}],
        "summary": "A musket that ignores Loading and makes its own Necrotic ammunition, +1 (+2 at level 7, +3 at 13). Jinxshot and the curse rider wait on the engine's heirloom rules.",
        "weapon": {"kind": "martial_ranged", "damage": "2d8", "damage_type": "necrotic", "properties": ["ammunition", "two_handed", "range"], "range": [30, 90], "mastery": "slow"}})


def build_monsters():
    ferry = read("data/monsters/ferryman.json")
    m = copy.deepcopy(ferry)
    m.update({"id": "ferryman_husk", "name": "Ferryman of Jack's", "hp": {"average": 10, "dice": "2d8+1"}, "cr": 0.5, "xp": 100,
              "summary": "A Ferryman called up by Snake Eye Jack: the stat block of the Ferryman at 10 Hit Points."})
    m.pop("legendary_actions", None)
    write("data/monsters/ferryman_husk.json", m)
    wr = read("addons/dnd_core/data/monsters/wraith.json")
    e = copy.deepcopy(wr)
    e.update({"id": "soulfire_engineer", "name": "Soulfire Engineer", "summary": "A wraith in an engineer's cap who tends the boiler. She asks the party to leave before the furnace vents."})
    write("data/monsters/soulfire_engineer.json", e)
    wt = read("addons/dnd_core/data/monsters/wight.json")
    k = copy.deepcopy(wt)
    k.update({"id": "coin_keeper", "name": "Coin Keeper", "summary": "A wight in sleeve-garters, keeper of the Sinner's coin vault and its key."})
    write("data/monsters/coin_keeper.json", k)
    s = read("data/monsters/grinning_sinner.json")
    s.update({"id": "grinning_sinner_boss", "name": "The Grinning Sinner", "ai_profile": s.get("ai_profile", "boss")})
    s["summary"] = s.get("summary", "") + " (The boss version: Bayou Boogie's two phases.)"
    s["phases"] = [
        {"id": "all_in", "name": "All In", "when": {"round": 1}, "summary": "He raises the blunderbuss, the music turns discordant, and his whole crew withers into husks to feed the gun.", "say": "dc_all_in", "flag": "dc_all_in"},
        {"id": "double_down", "name": "Double Down", "when": {"bloodied": True}, "summary": "He stamps the coffin and demands more of Jack: he and every attack against him have Advantage (a rider the engine adds).",
         "say": "dc_double_down", "flag": "dc_double_down", "legendary_refill": True}]
    write("data/monsters/grinning_sinner_boss.json", s)


def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if x["id"] not in ("dc_trail1", "dc_murkwater")] + [
        {"id": "dc_trail1", "name": "The Marshwinder Trail", "location": "dc_trail1", "spawn": "from_west", "pos": [0.36, 0.9], "region": REGION,
         "when": "flag.crossroads_asked or visited:dc_trail1", "summary": "The start of three nights' trek south, down to the valley's lowest point."},
        {"id": "dc_murkwater", "name": "Murkwater Bend", "location": "dc_murkwater", "spawn": "from_trail", "pos": [0.22, 0.96], "region": REGION,
         "when": "visited:dc_murkwater", "summary": "A stilt town in the bayou, under the Bayou King's flag."}]
    t["roads"] = [x for x in t["roads"] if x["id"] not in ("wickermoor_to_crossroads", "crossroads_to_murkwater")] + [
        {"id": "wickermoor_to_crossroads", "from": "wickermoor_village", "to": "dc_trail1", "hours": 24, "name": "The road to the Drowned Crossroads", "when": "flag.crossroads_asked or visited:dc_trail1"},
        {"id": "crossroads_to_murkwater", "from": "dc_trail1", "to": "dc_murkwater", "hours": 36, "name": "Through the swamp", "when": "visited:dc_murkwater"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


PICTURES = {
    "dc_adela_arm": "A gloved hand peeling off a long woollen glove by candlelight",
    "dc_adela_arm_2": "A grey, near-skeletal forearm with fingers curled in, in a black fur sleeve, in candlelight",
    "dc_hand_comes": "A tattooed, desiccated hand dragging itself over a cypress root toward a campfire in a swamp",
    "dc_hand_comes_2": "The withered hand stopped at the edge of the firelight, fingers spread, magenta threads in the dark",
    "dc_briggsy": "A man rowing out at midnight and dropping a sigil-etched cutlass where two drowned roads cross",
    "dc_briggsy_2": "A many-armed figure of shadow and bone with neon serpent eyes rising over a rowboat on black water",
    "dc_briggsy_3": "Dice on a coffin lid at dawn, the lid closing",
    "dc_murkwater": "Cypress foliage parting on a stilt town of lamplit shacks and rope bridges over black water",
    "dc_murkwater_2": "A fort's purple-and-black flag over a wooden palisade among stilts",
    "dc_screams": "Dead hands coming over a wooden palisade by torchlight",
    "dc_screams_2": "A bloodied sentry falling through a throne-room doorway",
    "dc_shack": "Bottle-buoys glowing in pairs across black water toward a lit shack on stilts",
    "dc_shack_2": "A steel guitar rocking on an empty porch chair",
    "dc_lagoon": "A neon riverboat moored in a mangrove lake, twin funnels coughing magenta flame",
    "dc_lagoon_2": "The same lagoon with the riverboat a broken wreck split in two, faded letters on the hull",
    "dc_lagoon_3": "A coffin boat poled by a chauffeur with copper coins on his eyes and brow",
    "dc_elias_soul": "A withered hand leaping into a dark furnace toward a green mote of light",
    "dc_elias_soul_2": "Neon light returning to the dead eyes of a gaunt waiter",
    "dc_elias_soul_3": "A gaunt waiter in an ill-fitting suit sitting down at last, at rest",
    "dc_roll_bones": "A hall stretching, windows rising, a coffin on four legs carved with a dice-eyed skeleton",
    "dc_roll_bones_2": "A lizardfolk gentleman's grin over a dice table, his crew massed behind him",
    "dc_all_in": "A crew falling to their knees and withering, their light streaming into a huge blunderbuss",
    "dc_all_in_2": "Tall windows bursting as swamp water pours into a casino hall",
    "dc_jack_due": "Skeletal arms and shadow serpents pouring from an opened coffin around a magenta shade",
    "dc_jack_due_2": "The coffin lid slamming shut, a crocodile skull and crossbones cut into it",
    "dc_jack_due_3": "A dark gambling hall, a corpse slumped with a blunderbuss in its hands, eyes wide",
}


def build_cutscenes():
    write("tools/content/crossroads_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": PICTURES})
    for cid, desc in PICTURES.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("dc_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


# =============================================================================================================================
# Wickermoor: Adela's hook and her after-beat
# =============================================================================================================================
def build_village_hooks():
    path = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(path.read_text())
    town["npcs"] = [n for n in town["npcs"] if not str(n.get("dialogue", "")).startswith(DC)]
    rows = town["map"]["rows"]
    cell = None
    for (x, y) in ((30, 30), (31, 30), (30, 31), (29, 30), (32, 29), (33, 30)):
        if rows[y][x] == ".":
            cell = (x, y)
            break
    assert cell, "no open square for Adela"
    town["npcs"] = [
        npc("adela_druskenvald", cell, "village_after:adela_cure", when="flag.grinning_sinner_slain and not flag.adela_cured"),
        npc("adela_druskenvald", cell, "hook:adela_hex", when="flag.crossroads_asked and flag.act2_done >= 1 and not flag.adela_hex_seen and not flag.grinning_sinner_slain"),
        npc("adela_druskenvald", cell, "hook:adela_start", when="flag.vessla_slain and not flag.crossroads_asked"),
    ] + town["npcs"]
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    build_trails()
    build_murkwater()
    build_fort()
    build_shack()
    build_boat()
    build_casino()
    build_people()
    build_quests()
    build_flags()
    build_items()
    build_monsters()
    build_travel()
    build_cutscenes()
    build_village_hooks()
    print("ok" if not ERRORS else f"{len(ERRORS)} placement problems")
