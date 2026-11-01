#!/usr/bin/env python3
"""ONE-SHOT (R16, Skitterdeep Mine). Writes the mine: the camp and the hill trail (their maps came from tools/content/skitterdeep_sketch.py + `make sketch`),
the warehouse, the machine shop, the upper workings (Old Drift, the lift landing, the Crosscut) and the deep level (the Deep Drift, the sigil chamber, Stonoga's
laboratory); the people, the quests (the main Skitter Plague, The Quarantine Queue, The Thirteenth Centipede), flags, items, the plague clock (data/schedule),
cutscenes (placeholders), the travel places and roads, and Wickermoor's side (Morgan's request, the street scene, Oakum's offer, the farewell, the reopening).
Other lanes edit these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_skitterdeep.py"""
import copy, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G

ROOT = Path(__file__).resolve().parents[2]
REGION = "skitterdeep_mine"
SK = "skitterdeep/"


def write(rel, obj):
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
        d["dialogue"] = SK + dialogue
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


def mon(mid, cell, name=None, **kw):
    d = {"monster": mid, "cell": list(cell)}
    if name:
        d["name"] = name
    d.update(kw)
    return d


def enc(eid, monsters, trigger="dialogue", **kw):
    d = {"id": eid, "trigger": trigger, "monsters": monsters}
    d.update(kw)
    return d


def container(cid, cell, label, items=(), gold=0, **kw):
    d = {"id": cid, "cell": list(cell), "label": label, "items": [{"id": i, "qty": q} for (i, q) in items], "gold": gold, "lock_dc": 0}
    d.update(kw)
    return d


def loc(lid, name, summary, text, rows, spawns, theme="dungeon", light="dark", outdoors=False, rest="risky", rest_text=None, **kw):
    d = {"id": lid, "name": name, "region": REGION, "summary": summary, "text": text,
         "map": {"rows": rows, "theme": theme, "light": light, "outdoors": outdoors}, "spawns": spawns,
         "areas": [], "exits": [], "props": [], "npcs": [], "encounters": [], "rest": rest}
    if rest_text:
        d["rest_text"] = rest_text
    d.update(kw)
    return d


# ---- level scaling ---------------------------------------------------------------------------------------------------------------
def tiers(eid, tiers_, **kw):
    """One encounter id in several versions, highest level first (the first whose `when` holds is the fight, as Vessla's are)."""
    out = []
    for (when, monsters, extra) in tiers_:
        e = {"id": eid, "trigger": "dialogue", "monsters": monsters}
        e.update(kw)
        e.update(extra)
        if when:
            e["when"] = when if "when" not in extra else extra["when"]
        out.append(e)
    return out


def spread(mid, cells, name=None, **kw):
    return [mon(mid, c, name, **kw) for c in cells]


FULL = "level >= 7"
MID = "level >= 5"


# ---- the maps drawn by hand --------------------------------------------------------------------------------------------------------
def put_floor(g, cells, ch="="):
    """Marks only squares that are open floor, never turns a wall into cover."""
    for (x, y) in cells:
        if g.c[y][x] == ".":
            g.c[y][x] = ch
    return g


def carve(g, rects):
    for (x0, y0, x1, y1) in rects:
        g.fill(x0, y0, x1, y1, ".")
    return g


def room_warehouse():
    g = G(17, 9).room(1, 1, 15, 7)
    g.fill(1, 1, 15, 7, "~")                                  # rubble everywhere: the whole room is Difficult Terrain
    g.put([(3, 1), (4, 1), (9, 1), (10, 1), (12, 4), (13, 4), (2, 6), (6, 6), (7, 6)], "=")   # smashed shelves
    return g.rows()


def room_machine_shop():
    g = G(26, 12).room(1, 1, 24, 10)
    g.wall(8, 1, 8, 10).wall(17, 1, 17, 10)                  # partitions: tool storage, the fleshdobbins' lair, the winch house
    g.put([(8, 5), (17, 5)], ".")                             # the doorways (doors are placed on them)
    g.fill(2, 1, 6, 1, "=").put([(2, 8), (3, 8), (6, 8)], "=")
    g.put([(10, 2), (10, 3), (14, 2), (14, 3), (10, 8), (11, 8), (14, 8), (15, 8)], "=")     # the beds (rubbish piles)
    g.put([(20, 3), (21, 3)], "=")                            # the winch drum and its lever box
    return g.rows()


def rooms_upper():
    g = G(66, 38)
    rects = [
        (1, 16, 11, 18),                  # the drift mouth running east
        (10, 16, 12, 22), (10, 22, 21, 24), (19, 17, 21, 24), (19, 16, 27, 18),      # the drift bends south, then back north to the landing
        (5, 8, 7, 16), (14, 24, 16, 31), (23, 9, 25, 16),     # dead-end side cuts
        (11, 18, 18, 23),                  # the diggers' cavern
        (27, 11, 35, 20),                  # the landing
        (36, 14, 51, 16),                  # the Crosscut
        (52, 8, 63, 22),                   # the hoard chamber
    ]
    carve(g, rects)
    g.fill(30, 14, 32, 16, " ")            # the main shaft: 15 ft square, a drop with no bottom
    put_floor(g, [(6, 12), (6, 13), (15, 27), (15, 28), (24, 12), (24, 13)])   # minecarts in the side cuts
    put_floor(g, [(12, 19), (17, 22), (20, 20), (4, 17), (8, 18)])     # overturned carts and timbers
    put_floor(g, [(54, 10), (55, 10), (58, 9), (61, 12), (62, 12), (60, 20), (61, 20), (56, 20), (54, 18)])   # the heaps of the hoard
    return g.rows()


def rooms_deep():
    g = G(58, 26)
    rects = [
        (1, 8, 18, 18),                    # the sigil chamber
        (19, 11, 52, 15),                  # the Deep Drift
        (22, 10, 28, 16),                  # the shaft's foot, a little wider
        (36, 3, 42, 9),                    # the laboratory
        (39, 10, 39, 10),                  # the bronze door's doorway
    ]
    carve(g, rects)
    g.put([(2, 8), (3, 8), (1, 9), (18, 8), (18, 18), (1, 18), (17, 18), (1, 17)], "#")     # round off the oval
    g.put([(9, 13), (10, 13), (8, 13), (9, 12), (9, 14), (10, 12), (10, 14), (8, 12), (8, 14)], "~")    # the sigil ring: difficult ground
    g.put([(37, 3), (38, 3), (40, 3), (41, 3), (37, 4), (41, 4), (37, 8), (38, 8), (41, 8)], "=")        # the benches and shelves
    g.put([(38, 6), (39, 6), (40, 6)], "=")                                                                  # the fusion table
    return g.rows()


# ---- builders --------------------------------------------------------------------------------------------------------------------
def build_trail():
    t = read("data/locations/sk_hills_trail.json") if (ROOT / "data/locations/sk_hills_trail.json").exists() else {}
    rows = t["map"]["rows"]
    t.update({
        "id": "sk_hills_trail", "name": "The Hill Trail", "region": REGION,
        "summary": "A rutted trail through wooded hills north-west of Wickermoor, with a clearing where it bends.",
        "text": "The trail climbs through wet beech and hornbeam. Mist lies in the hollows and the ruts are full of tiny crawling things.",
        "spawns": {"default": [24, 11], "from_camp": [3, 11], "from_village": [44, 11]},
        "areas": [area("sk_trail_west", "The west trail", (0, 5), (16, 18)), area("sk_trail_clearing", "The clearing at the bend", (17, 5), (30, 18)),
                  area("sk_trail_east", "The east trail", (31, 5), (47, 18))],
        "exits": [exit_("road_on", (0, 10), "travel", "default", "On to Glitterdeep Mine"),
                  exit_("road_back", (47, 11), "travel", "default", "Back to Wickermoor")],
        "props": [
            prop("sk_trail_turn", (24, 9), "The bend in the trail", kind="decor", call=SK + "guide:turn", approach=10, call_when="flag.oakum_guiding and not flag.oakum_wolf_seen"),
            prop("sk_trail_rider", (28, 11), "A lone horse in a courier's coat", kind="decor", call=SK + "trail:rider", approach=9,
                 call_when="flag.skitter_letter_hook and not flag.parcel_rider_met"),
            prop("sk_trail_tack", (19, 9), "A rotted saddle bag in the brambles", kind="search", search_dc=10, item="sk_bridle", skill="perception"),
            prop("sk_trail_cairn", (12, 8), "A hunters' cairn", model="rocks"),
            prop("sk_trail_log", (22, 6), "A fallen log", model="fallen_beam"),
            prop("sk_trail_crawlers", (30, 13), "Tiny centipedes crossing the ruts", kind="decor", model="soot_patch"),
            prop("sk_trail_crawlers_2", (9, 12), "Tiny centipedes, all heading the same way", kind="decor", model="soot_patch"),
            prop("sk_trail_pine_a", (5, 6), model="pine_a", kind="decor"), prop("sk_trail_pine_b", (36, 6), model="pine_b", kind="decor"),
            prop("sk_trail_pine_c", (40, 16), model="pine_c", kind="decor"), prop("sk_trail_dead_a", (13, 14), model="dead_tree_a", kind="decor"),
            prop("sk_trail_dead_b", (33, 8), model="dead_tree_b", kind="decor"), prop("sk_trail_boulder", (41, 8), model="boulder", kind="decor"),
        ],
        "foe_spots": [[8, 17], [13, 15], [16, 15], [23, 5], [26, 4], [30, 8], [33, 7], [38, 14], [40, 12], [44, 10], [5, 8], [20, 16]],
        "encounters": [enc("sk_rider_fight", [mon("fleshdobbin", (28, 11), "The parcel rider", facing="west")], flag="parcel_rider_slain")],
        "rest": "risky", "rest_text": "The beeches creak, and something small keeps walking over your blanket.",
        "recheck_minutes": 10,
    })
    write("data/locations/sk_hills_trail.json", t)


def build_camp():
    c = read("data/locations/sk_camp.json")
    c.update({
        "id": "sk_camp", "name": "Glitterdeep Mine", "region": REGION,
        "summary": "An abandoned mining camp in a ridge of wooded hills, with a headframe over a black shaft and a sign with two letters painted over.",
        "text": "The camp is sagging timber, rust and rail. A headframe stands over a square hole that breathes green gas, and the sign over the warehouse says Skitterdeep.",
        "spawns": {"default": [47, 13], "from_road": [47, 13], "from_drift": [6, 13], "from_warehouse": [16, 10], "from_shop": [33, 10], "from_shaft": [38, 16], "from_lift": [38, 17]},
        "areas": [area("sk_shaft_head", "The shaft head", (36, 13), (46, 19)), area("sk_drift_mouth", "The old drift's mouth", (2, 11), (8, 15)),
                  area("sk_warehouse_yard", "The warehouse yard", (9, 10), (24, 13)), area("sk_east_road", "The camp road", (43, 10), (49, 16)),
                  area("sk_kennel_yard", "The kennel yard", (14, 19), (24, 25))],
        "exits": [
            exit_("road_back", (49, 13), "travel", "default", "The hill trail back to Wickermoor"),
            exit_("old_drift", (2, 13), "sk_upper", "from_drift", "Into the old drift"),
            exit_("warehouse", (16, 9), "sk_warehouse", "default", "Enter the warehouse"),
            exit_("machine_shop", (33, 9), "sk_machine_shop", "default", "Enter the machine shop"),
            exit_("chain_down", (39, 16), "sk_upper", "from_shaft", "Climb down the chain to the landing"),
            exit_("lift_down", (39, 17), "sk_upper", "from_lift", "Ride the lift down", when="flag.sk_lift_ready and not flag.skitterdeep_lift_fell"),
        ],
        "props": [
            prop("sk_sign", (20, 10), "The warehouse sign", model="sign", dialogue=SK + "camp:sign"),
            prop("sk_arrival", (44, 13), "The camp, and the headframe beyond", kind="decor", call=SK + "camp:arrival", approach=10, call_when="not flag.sk_arrived"),
            prop("sk_headframe", (43, 16), "The headframe over the shaft", model="gate", scale=2.5),
            prop("sk_headframe_beam", (43, 14), "The beam and the hanging chain", model="fallen_beam"),
            prop("sk_shaft_gas", (41, 14), "Green gas, rising", kind="decor", model="soot_patch"),
            prop("sk_rungs", (38, 15), "Old maintenance rungs in the shaft wall", model="ladder"),
            prop("sk_kennel", (19, 23), "An old kennel with a numbered brass collar", model="cage", dialogue=SK + "thirteen:kennel"),
            prop("sk_camp_oakum_spot", (44, 12), "A flat stone at the camp's edge", kind="decor", model="rocks"),
            prop("sk_cart_a", (12, 14), "An ore cart, on its side", model="cart_broken"), prop("sk_cart_b", (26, 12), "An ore cart on its rails", model="cart"),
            prop("sk_cart_c", (30, 13), "A rusted handcart", model="handcart"),
            prop("sk_barrels", (20, 12), "Split barrels, black with rot", model="barrel"), prop("sk_crates", (23, 11), "Stacked crates, mostly splinters", model="crate_stack"),
            prop("sk_woodpile", (25, 10), "A woodpile gone to mulch", model="woodpile"), prop("sk_pumphouse_bucket", (16, 18), "A bucket by the dead pump", model="bucket_brush"),
            prop("sk_boulder_a", (8, 11), model="boulder", kind="decor"), prop("sk_boulder_b", (8, 15), model="boulder", kind="decor"),
            prop("sk_pine_a", (44, 10), model="pine_a", kind="decor"), prop("sk_pine_b", (9, 24), model="pine_b", kind="decor"),
            prop("sk_dead_a", (30, 24), model="dead_tree_a", kind="decor"), prop("sk_dead_b", (10, 22), model="dead_tree_b", kind="decor"),
            prop("sk_crawlers_a", (14, 12), "A trail of tiny centipedes", kind="decor", model="soot_patch"), prop("sk_crawlers_b", (35, 18), "Tiny centipedes on the rails", kind="decor", model="soot_patch"),
            prop("sk_crawlers_c", (26, 21), "Tiny centipedes in the weeds", kind="decor", model="soot_patch"),
            prop("sk_lantern_post", (31, 11), "A lantern post, long dark", model="lantern_post"), prop("sk_signpost", (46, 14), "A signpost with no arms", model="signpost_broken"),
        ],
        "npcs": [
            npc("mrs_oakum", (44, 12), "guide:ashamed", when="flag.oakum_wolf_seen and not flag.oakum_choice_done"),
            npc("thirteenth_centipede", (21, 23), "thirteen:meet", when="flag.thirteen_asked and not flag.thirteen_outcome"),
        ],
        "encounters": [enc("sk_thirteen_fight", [mon("giant_centipede", (21, 23), "Thirteen")], flag="thirteen_slain")],
        "rest": "risky", "rest_text": "Rail and timber tick and settle, and the green haze lies on your blanket.",
        "recheck_minutes": 10,
    })
    c["props"] = [p for p in c["props"] if p["id"]]
    write("data/locations/sk_camp.json", c)


def build_warehouse():
    w = loc("sk_warehouse", "The Warehouse", "The mine's old store, smashed and sleeping.", "Broken shelves, rubble to the ankle, a thin green haze and the sound of heavy breathing.",
            room_warehouse(), {"default": [8, 7], "from_camp": [8, 7]}, theme="manor", light="dim")
    w["areas"] = [area("wh_floor", "The warehouse floor", (1, 1), (15, 7)), area("wh_sleepers", "The sleepers", (2, 2), (14, 6))]
    w["exits"] = [exit_("door", (8, 8), "sk_camp", "from_warehouse", "Out to the camp")]
    w["props"] = [
        prop("sk_wh_sheet_a", (3, 3), "A pallet of rusted sheet metal", model="broken_boards"), prop("sk_wh_sheet_b", (6, 5), "A pallet of rusted sheet metal", model="broken_boards"),
        prop("sk_wh_sheet_c", (11, 2), "A pallet of rusted sheet metal", model="broken_boards"), prop("sk_wh_sheet_d", (13, 5), "A pallet of rusted sheet metal", model="broken_boards"),
        prop("sk_wh_trinkets_a", (2, 2), "A heap of miners' leavings", kind="search", search_dc=8, item="incense", skill="investigation"),
        prop("sk_wh_trinkets_b", (14, 1), "A rotted lunch pail", kind="search", search_dc=10, item="sk_miners_lunch", skill="investigation"),
        prop("sk_wh_note", (8, 1), "A foreman's board, half legible", model="notice_board", dialogue=SK + "camp:foreman_board"),
        prop("sk_wh_rubble", (5, 4), "Rubble and old crates", model="rubble"), prop("sk_wh_barrels", (1, 6), "A barrel of rotted flour", model="barrel"),
        prop("sk_wh_crawlers", (9, 4), "Tiny centipedes in the flour", kind="decor", model="soot_patch"), prop("sk_wh_cobwebs", (15, 1), "Cobwebs", kind="decor", model="cobwebs"),
    ]
    w["containers"] = [container("sk_lockbox", (14, 2), "A rusted lockbox", items=[("citrine", 3), ("potion_of_healing_greater", 1)], lock_dc=14)]
    sleepers = [(3, 3), (6, 5), (11, 2), (13, 5)]
    w["encounters"] = tiers("sk_wh_sleepers", [
        (FULL, [mon("deepdreck", c, "A sleeping miner", facing="south", lying=True) for c in sleepers], {"trigger": "enter_area:wh_sleepers", "waiting": True, "flag": "sk_wh_done"}),
        (None, [mon("deepdreck", c, "A sleeping miner", facing="south", lying=True) for c in sleepers[:2]], {"trigger": "enter_area:wh_sleepers", "waiting": True, "flag": "sk_wh_done"}),
    ])
    w["encounters"][0]["when"] = FULL
    write("data/locations/sk_warehouse.json", w)


def build_machine_shop():
    m = loc("sk_machine_shop", "The Machine Shop", "A rusted shop of three rooms; the middle one smells of horse and rot.", "Warped boards leak green gas. Three rooms, two doors between them, and handprints in the dust.",
            room_machine_shop(), {"default": [12, 9], "from_camp": [12, 9]}, theme="manor", light="dim")
    m["areas"] = [area("shop_tools", "Tool storage", (1, 1), (7, 10)), area("shop_lair", "The fleshdobbins' lair", (9, 1), (16, 10)), area("shop_winch", "The winch house", (18, 1), (24, 10)),
                  area("shop_floor", "The machine shop", (9, 9), (16, 10))]
    m["exits"] = [exit_("door", (12, 11), "sk_camp", "from_shop", "Out to the camp")]
    m["doors"] = [
        {"id": "sk_door_a", "cell": [8, 5], "label": "The tool storage door", "locked": True, "lock_dc": 15, "key": "sk_iron_key", "locked_text": "It is locked. The iron key hangs on a cord somewhere in this mine."},
        {"id": "sk_door_b", "cell": [17, 5], "label": "The winch house door", "locked": True, "lock_dc": 15, "key": "sk_iron_key", "locked_text": "It is locked, and the iron key is not on you."},
    ]
    m["props"] = [
        prop("sk_handprints", (4, 5), "Handprints in the dust", model="claw_marks", dialogue=SK + "camp:handprints"),
        prop("sk_tool_maul", (3, 2), "A maul under a tarp", kind="search", search_dc=20, item="maul", skill="perception"),
        prop("sk_tool_pack", (5, 2), "A dungeoneer's pack, half buried", kind="search", search_dc=20, item="dungeoneers_pack", skill="perception"),
        prop("sk_tool_rack", (2, 3), "A rack of ruined tools", model="shelves"),
        prop("sk_bed_1", (10, 2), "A rubbish-pile bed under a horse blanket", model="bed_small"), prop("sk_bed_2", (14, 2), "A rubbish-pile bed under a wine-red surcoat", model="bed_small"),
        prop("sk_bed_4", (10, 8), "A rubbish-pile bed", model="bed_small"),
        prop("sk_surcoats", (12, 5), "Rotted wine-red surcoats", model="rags", dialogue=SK + "camp:surcoats"),
        prop("sk_winch", (20, 3), "The winch drum and its lever box", model="case", dialogue=SK + "camp:winch"),
        prop("sk_chain_port", (23, 1), "The chain port", model="window"),
        prop("sk_lye_barrel_note", (3, 9), "A barrel of grey lye", model="barrel"),
        prop("sk_shop_crawlers", (12, 7), "Tiny centipedes in the straw", kind="decor", model="soot_patch"),
    ]
    m["containers"] = [container("sk_lye_barrel", (4, 9), "A lye barrel and a stack of cakes", items=[("lye_soap_flask", 2), ("oil", 1), ("alchemists_fire", 1)])]
    m["npcs"] = [npc("parcel_rider", (14, 8), "trail:rider_bed", when="not flag.skitter_letter_hook and not flag.parcel_rider_met", steps_aside=True, lying=True)]
    m["encounters"] = tiers("sk_lair_fleshdobbins", [
        (FULL, [mon("fleshdobbin", (11, 3), "A fleshdobbin in a wine-red surcoat", facing="south"), mon("fleshdobbin", (15, 3), "A fleshdobbin in a wine-red surcoat", facing="south")],
         {"trigger": "open:sk_door_a", "flag": "sk_lair_done", "when": FULL}),
        (None, [mon("fleshdobbin", (11, 3), "A fleshdobbin in a wine-red surcoat", facing="south")], {"trigger": "open:sk_door_a", "flag": "sk_lair_done"}),
    ])
    # the lair's fight starts when the first partition door opens: that is the tool storage's door, so the fleshdobbins sleep in the middle room the party crosses
    write("data/locations/sk_machine_shop.json", m)


def build_upper():
    u = loc("sk_upper", "The Upper Workings", "The old drift, the lift landing 30 feet down the shaft, and the Crosscut.",
            "Rotten timbering, overturned minecarts, and a smell of old meat rising from far below.", rooms_upper(), {"default": [2, 17], "from_drift": [2, 17], "from_shaft": [29, 13], "from_lift": [31, 13], "from_below": [28, 15]},
            light="dark", rest_text="The tunnels breathe. You would not close your eyes.")
    u["areas"] = [area("drift_west", "The old drift", (1, 16), (12, 18)), area("drift_dig", "The diggers' cavern", (11, 18), (18, 23)), area("drift_east", "The drift, east", (19, 16), (27, 18)),
                  area("landing", "The lift landing", (27, 11), (35, 20)), area("crosscut", "The Crosscut", (36, 14), (51, 16)), area("hoard", "The hoard chamber", (52, 8), (63, 22))]
    u["exits"] = [
        exit_("drift_mouth", (1, 17), "sk_camp", "from_drift", "Out of the drift"),
        exit_("chain_up", (33, 13), "sk_camp", "from_shaft", "Climb the chain to the surface"),
        exit_("lift_up", (31, 12), "sk_camp", "from_lift", "Ride the lift up", when="flag.sk_lift_ready and not flag.skitterdeep_lift_fell"),
        exit_("chain_down", (29, 15), "sk_deep", "from_shaft", "Climb the old rungs and chain to the bottom"),
    ]
    u["props"] = [
        prop("sk_lift", (31, 17), "The lift: planks over three iron beams", model="dais", dialogue=SK + "camp:lift"),
        prop("sk_shaft_rungs", (29, 14), "Old maintenance rungs", model="ladder"),
        prop("sk_masons_tools", (7, 17), "Working tools along the drift", kind="search", search_dc=12, item="masons_tools", skill="investigation"),
        prop("sk_spy_ring", (6, 17), "The spy centipede's husk", kind="search", search_dc=1, item="ring_of_evasion", when="flag.sk_spy_done"),
        prop("sk_key_body", (30, 18), "The lift fleshdobbin's body, and a cord", kind="search", search_dc=1, item="sk_iron_key", when="flag.sk_landing_done"),
        prop("sk_eyeball", (37, 14), "An eye hanging by its nerve", model="jars", dialogue=SK + "camp:eyeball"),
        prop("sk_hoard_gold", (55, 12), "A heap of gold and gems", model="gold_spill", dialogue=SK + "camp:hoard"), prop("sk_hoard_chalices", (58, 14), "Silver chalices and silks", model="gold_spill", dialogue=SK + "camp:hoard"),
        prop("sk_hoard_jewels", (60, 18), "A scatter of jewels", model="gold_spill", dialogue=SK + "camp:hoard"), prop("sk_hoard_coins", (56, 18), "Coins by the handful", model="gold_spill", dialogue=SK + "camp:hoard"),
        prop("sk_hoard_guts", (57, 10), "A heap of organs", model="blood_pool", dialogue=SK + "camp:hoard"),
        prop("sk_drift_timbers", (12, 17), "Rotten, termite-eaten timbering", model="fallen_beam"), prop("sk_drift_cart", (6, 12), "A minecart, rust-welded", model="cart_broken"),
        prop("sk_drift_cart_2", (24, 12), "A minecart on a spur of rail", model="cart"), prop("sk_drift_pick", (13, 21), "A pickaxe in a drift wall", model="bucket_brush"),
        prop("sk_up_crawlers_a", (9, 17), "Tiny centipedes along the wall", kind="decor", model="soot_patch"), prop("sk_up_crawlers_b", (21, 20), "Tiny centipedes along the wall", kind="decor", model="soot_patch"),
        prop("sk_up_crawlers_c", (40, 15), "Tiny centipedes along the wall", kind="decor", model="soot_patch"), prop("sk_up_webs", (34, 11), "Cobwebs", kind="decor", model="cobwebs"),
        prop("sk_up_bones", (15, 29), "Bones in a dead-end cut", kind="decor", model="bone_scatter"),
        prop("sk_up_lantern", (28, 12), "A dead lantern bracket", kind="decor", model="lantern_bracket"),
    ]
    u["lights"] = [{"cell": [31, 12], "kind": "candle", "bright_ft": 5, "dim_ft": 10, "color": "bile"}]
    n_dig = lambda n: spread("deepdreck", [(13, 20), (14, 21), (15, 19), (16, 22), (17, 20)][:n], "A digging miner", facing="west")
    dig = []
    for (lv, n, ret) in ((FULL, 5, False), (FULL, 3, True), (None, 3, False), (None, 2, True)):
        when = [x for x in [lv, "flag.thirteen_returned" if ret else "not flag.thirteen_returned"] if x]
        dig.append(enc("sk_drift_diggers", n_dig(n), trigger="enter_area:drift_dig", waiting=True, flag="sk_diggers_done", when=" and ".join(when)))
    u["encounters"] = dig + [
        enc("sk_spy", [mon("giant_centipede", (5, 17), "A spy centipede in a ring", facing="east")], trigger="enter_area:drift_west", waiting=True, flag="sk_spy_done"),
    ]
    u["encounters"] += tiers("sk_landing", [
        (FULL, [mon("fleshdobbin", (30, 18), "The lift's fleshdobbin", facing="north")] + spread("deepdreck", [(28, 13), (34, 13)], "A deepdreck", facing="east")
         + spread("giant_centipede", [(28, 19), (29, 17), (33, 18), (34, 19), (35, 17), (28, 16), (34, 15), (33, 12), (29, 20), (32, 19)], "A giant centipede", facing="east"),
         {"trigger": "enter_area:landing", "waiting": True, "flag": "sk_landing_done", "when": FULL}),
        (None, [mon("fleshdobbin", (30, 18), "The lift's fleshdobbin", facing="north"), mon("deepdreck", (28, 13), "A deepdreck", facing="east")]
         + spread("giant_centipede", [(28, 19), (29, 17), (33, 18), (34, 19)], "A giant centipede", facing="east"),
         {"trigger": "enter_area:landing", "waiting": True, "flag": "sk_landing_done"}),
    ])
    u["encounters"].append(enc("sk_oswald", [mon("vermin_familiar_centipede", (57, 11), "Slippery Oswald", unseen=True)], flag="oswald_slain"))
    write("data/locations/sk_upper.json", u)


def build_deep():
    d = loc("sk_deep", "The Deep Level", "The Deep Drift with its sigils, and Stonoga's laboratory.", "Yellow-green haze, walls that squirm when you look at them, and a bronze door lit by a slow green-purple pulse.",
            rooms_deep(), {"default": [26, 13], "from_shaft": [26, 13]}, light="dark", rest="no", rest_text="The haze will not let you rest here.")
    d["areas"] = [area("deep_chamber", "The sigil chamber", (1, 8), (18, 18)), area("deep_drift", "The Deep Drift", (19, 11), (52, 15)), area("shaft_foot", "The shaft's foot", (22, 10), (28, 16)),
                  area("door_guard", "The bronze door", (34, 11), (44, 15)), area("lab", "Stonoga's laboratory", (36, 3), (42, 9))]
    d["exits"] = [exit_("chain_up", (26, 11), "sk_upper", "from_below", "Climb the rungs and chain up")]
    d["doors"] = [{"id": "sk_bronze_door", "cell": [39, 10], "label": "The bronze door", "locked": False}]
    d["props"] = [
        prop("sk_deep_arrive", (26, 13), "The bottom of the shaft", kind="decor", call=SK + "deep:arrive", approach=4, call_when="not flag.sk_deep_seen"),
        prop("sk_miasma_a", (21, 13), "The yellow-green haze", kind="decor", call=SK + "deep:miasma_a", approach=3, call_when="not flag.sk_miasma_a"),
        prop("sk_miasma_b", (32, 13), "The haze, thicker here", kind="decor", call=SK + "deep:miasma_b", approach=3, call_when="not flag.sk_miasma_b"),
        prop("sk_sigils", (9, 13), "A ring of knotted entrails, sweating gas", model="floor_glyphs", dialogue=SK + "deep:sigils"),
        prop("sk_sigils_ring", (10, 14), "Sinew knotted into the floor", kind="decor", model="rune_circle"),
        prop("sk_flesh_a", (20, 12), "A wall of soft, slick flesh", kind="decor", model="vines"), prop("sk_flesh_b", (45, 12), "A wall of soft, slick flesh", kind="decor", model="vines"),
        prop("sk_flesh_c", (30, 15), "A wall of soft, slick flesh", kind="decor", model="vines"), prop("sk_flesh_d", (14, 9), "A wall of soft, slick flesh", kind="decor", model="vines"),
        prop("sk_crawlers_deep_a", (24, 12), "Tiny centipedes, thick as spilled rice", kind="decor", model="soot_patch"), prop("sk_crawlers_deep_b", (35, 14), "Tiny centipedes, thick as spilled rice", kind="decor", model="soot_patch"),
        prop("sk_crawlers_deep_c", (6, 12), "Tiny centipedes, thick as spilled rice", kind="decor", model="soot_patch"),
        prop("sk_water", (3, 17), "Water trickling somewhere in the dark", kind="decor", model="puddle"),
        prop("sk_lab_arrive", (39, 9), "The laboratory", kind="decor", call=SK + "stonoga:enter", approach=3, call_when="not flag.stonoga_slain and not flag.stonoga_talked"),
        prop("sk_lab_shelves", (38, 3), "Shelves of flasks", model="shelves"), prop("sk_lab_bench", (41, 4), "A bench of parchment and filthy blades", model="table_round"),
        prop("sk_lab_table", (39, 6), "The fusion table", model="table_meal", dialogue=SK + "stonoga:table"),
        prop("sk_lab_flames", (37, 8), "Dim bruise-coloured flames", kind="decor", model="candle_cluster"),
        prop("sk_notes", (40, 4), "Stonoga's notes", model="papers", dialogue=SK + "stonoga:notes", when="flag.stonoga_slain and not flag.stonoga_notes_read"),
        prop("sk_cage", (37, 4), "A cage of a missing person's belongings", model="cage", dialogue=SK + "stonoga:cage", when="flag.stonoga_slain and not flag.fate_kindred_found"),
        prop("sk_after_boss", (39, 8), "The sludge where she fell", kind="decor", model="blood_pool", call=SK + "stonoga:after", approach=5, call_when="flag.stonoga_slain and not flag.stonoga_after_seen"),
    ]
    d["containers"] = [container("sk_stonoga_chest", (41, 8), "Stonoga's shelves and a jar in gel",
                                 items=[("necklace_of_adaptation", 1), ("alchemists_supplies", 1), ("restorative_ointment", 4)], when="flag.stonoga_slain")]
    d["encounters"] = [
        enc("sk_door_guard", [mon("fleshdobbin", (38, 12), "A fleshdobbin at the bronze door", facing="west"), mon("skitterswarm", (37, 14), "A skitterswarm", facing="west")],
            trigger="enter_area:door_guard", waiting=True, flag="sk_door_done",
            round_events=[{"id": "sk_walls_burst", "name": "The walls give up their miners", "summary": "Two deepdrecks burrow out of the walls by the sigils.", "kind": "summon", "affects": "enemies",
                           "monster": "deepdreck", "count": 2, "side": "enemies", "cells": [[34, 11], [34, 15]], "at": 20, "from_round": 2, "every": 1, "times": 1,
                           "say": "The soft walls split, and two miners come out of them."}]),
    ]
    surges = [{"id": "sk_wall_spill", "name": "The walls spill", "summary": "The walls spill one more skitterswarm, never two rounds running.", "kind": "summon", "affects": "enemies",
               "monster": "skitterswarm", "count": 1, "side": "enemies", "cells": [[36, 5], [42, 7]], "at": 20, "from_round": 2, "every": 2, "times": 3,
               "say": "The lab's walls split and another swarm spills out."},
              {"id": "sk_miasma_surge", "name": "A miasma surge", "summary": "The haze thickens: Constitution save or Poisoned until the end of the creature's next turn.", "kind": "save", "affects": "party",
               "save": {"ability": "con", "dc": 16}, "condition": "poisoned", "until": "target_turn_end", "skip_if_resists": ["poison"], "at": 20, "from_round": 3, "every": 3,
               "area": {"rect": [36, 3, 42, 9]}, "say": "The haze surges, thick and sweet."}]
    boss_v = []
    for (lv, n_sw, oswald, alert) in ((FULL, 4, True, True), (FULL, 3, True, False), (FULL, 4, False, True), (FULL, 3, False, False), (None, 2, True, False), (None, 2, False, False)):
        when = [x for x in [lv, "not flag.oswald_slain" if oswald else "flag.oswald_slain", ("minutes_since.skitterdeep_alert < 120" if alert else None)] if x]
        monsters = [mon("centipede_hag", (39, 5), "Stonoga Blackstinger", boss=True, facing="south")]
        monsters += spread("skitterswarm", [(37, 6), (41, 6), (39, 8), (38, 7)][:n_sw], "A skitterswarm")
        if oswald:
            monsters.append(mon("vermin_familiar_centipede", (40, 4), "Slippery Oswald"))
        e = enc("sk_stonoga", monsters, flag="stonoga_slain", quest={"id": "skitter_plague", "stage": "the_sigils"}, round_events=copy.deepcopy(surges), lair=True)
        if when:
            e["when"] = " and ".join(when)
        boss_v.append(e)
    d["encounters"] += boss_v
    write("data/locations/sk_deep.json", d)


# ---- the people --------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude, extra
    ("stonoga_blackstinger", "Stonoga Blackstinger", "The centipede hag", "Tall and stringy, with no nose, few toes and a neck that stretches several feet; jolly, wet-voiced, fond of a chat before a killing.", "hostile",
     {"monster": "centipede_hag", "tags": ["faction_coven"]}),
    ("slippery_oswald", "Slippery Oswald", "Stonoga's familiar", "A hound-sized centipede with a small human hand at the end of every leg and a very human grin; afraid of dogs.", "hostile",
     {"monster": "vermin_familiar_centipede", "tags": ["faction_coven"]}),
    ("parcel_rider", "The parcel rider", "A courier, changed", "A post rider Theodora sent to the mine, now a lone fleshdobbin in a courier's coat with a sack on its back.", "indifferent",
     {"monster": "fleshdobbin"}),
    ("thirteenth_centipede", "Thirteen", "The miners' pet", "A giant centipede in a brass collar numbered XIII, much loved by the old miners and a little too large for its kennel.", "friendly",
     {"monster": "giant_centipede"}),
    ("haldor_vane", "Haldor Vane", "An old cooper", "An old cooper with a fever and a great deal of dignity, queueing outside the apothecary.", "friendly", {}),
    ("ottilie_reed", "Ottilie Reed", "A young mother", "A young mother with a baby on her arm, loud because someone has to be.", "friendly", {}),
    ("pim_fenwick", "Pim Fenwick", "The mayor's cousin", "The mayor's idle cousin, the best-dressed man in the queue and the least sick.", "friendly", {}),
]


def build_people():
    for (nid, name, title, summary, att, extra) in PEOPLE:
        d = {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION,
             "tags": extra.pop("tags", ["faction_none", "voice_hollow"])}
        d.update(extra)
        write(f"data/npcs/{nid}.json", d)
    mo = read("data/npcs/mrs_oakum.json")      # she can guide the party (a guest who does not fight: she is a hill-folk butcher's hand, and a wolf at the wrong hour)
    mo["guest"] = True
    mo["guest_fights"] = False
    write("data/npcs/mrs_oakum.json", mo)


# ---- quests ------------------------------------------------------------------------------------------------------------------------
def stage(sid, journal, hint=None, objectives=None, ends=None, **kw):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    d.update(kw)
    return d


def build_quests():
    write("data/quests/skitter_plague.json", {
        "id": "skitter_plague", "name": "The Skitter Plague", "kind": "main", "region": REGION, "giver": "morgan",
        "summary": "Centipedes are in Wickermoor's walls and beds, the bitten are falling sick, and the trail of tiny tunnels runs north-west into the hills.",
        "stages": [
            stage("the_bitten", "Centipedes crawl in the Round, in the bread and in the beds. The bitten shake with fever and mauve pustules, and each night more of them fall ill.",
                  "Ask around in the Round, or see Morgan at the apothecary.", ["Learn where the centipedes come from"]),
            stage("trail_of_corruption", "The thin tunnels in the cobbles and cellar floors all run north-west, toward the old Glitterdeep Mine.",
                  "Mrs. Oakum knows the north-west hills; she was about in the Round.", ["Find a way to the mine"]),
            stage("oakums_tale", "Mrs. Oakum remembers her father's tale of Glitterdeep: a glamoured woman who fed the miners, and a collapse. She offered to guide us.",
                  "Tell Mrs. Oakum whether she should guide us.", ["Decide whether Mrs. Oakum guides the party"]),
            stage("into_the_hills", "The old mine lies eight hours north-west, up a rutted trail through wooded hills.",
                  "Take the hill trail north-west from Wickermoor.", ["Reach Glitterdeep Mine"]),
            stage("skitterdeep", "Glitterdeep's sign has been painted over to read Skitterdeep. The shaft is a black square belching green gas, and the way down is the lift, the chain or the old drift.",
                  "Find a way down: the lift, the chain on the shaft head, or the old drift in the west ridge.", ["Reach the deep level"]),
            stage("the_hags_lair", "At the bottom the haze is thick as soup, the walls squirm, and a bronze door pulses green and purple.",
                  "Get through the Deep Drift and the bronze door. Lye might trouble a hag.", ["Reach Stonoga's laboratory"]),
            stage("the_sigils", "Stonoga is dead, but the knotted sigils in the west chamber still sweat the gas that feeds the plague.",
                  "Break the sigils in the west chamber of the Deep Drift.", ["Break the gruesome sigils"]),
            stage("exterminated", "The sigils are broken. The plague lifts within the hour and the centipedes stream away into the hills.",
                  "Go back to Wickermoor and tell Morgan.", ["Return to Wickermoor"]),
            stage("back_in_wickermoor", "Back in Wickermoor the fever is breaking. Morgan is waiting, and Phillip and the Mayor are talking about the mine.",
                  "See Morgan at the apothecary.", ["Speak with Morgan"]),
            stage("done", "The Skitter Plague is over, and Glitterdeep is to be reopened.", ends="success"),
        ]})
    write("data/quests/quarantine_queue.json", {
        "id": "quarantine_queue", "name": "The Quarantine Queue", "kind": "side", "region": REGION, "giver": "morgan",
        "summary": "Three sick villagers wait outside the apothecary, and Morgan has beds for one at a time.",
        "stages": [
            stage("asked", "Morgan can treat the sick only one at a time, and the three in the queue each think they should be first: Haldor Vane, Ottilie Reed and Pim Fenwick.",
                  "Talk to the three in the queue outside the apothecary, then tell Morgan the order.", ["Talk to Haldor, Ottilie and Pim", "Settle the order"]),
            stage("done", "The queue was settled and Morgan treated them in the order we gave.", ends="success"),
            stage("lost", "We left the queue to sort itself out. Mourning ribbons went up on a door in the Round.", ends="failure"),
        ]})
    write("data/quests/thirteenth_centipede.json", {
        "id": "thirteenth_centipede", "name": "The Thirteenth Centipede", "kind": "side", "region": REGION, "giver": "mrs_oakum",
        "summary": "The old miners kept pet centipedes to smell the gas. The thirteenth never left, and it is a little too large for its kennel.",
        "stages": [
            stage("asked", "A brass collar numbered XIII hangs on an old kennel at Glitterdeep, and something large is sleeping in the weeds beside it.",
                  "Find Thirteen near the kennel at the mining camp and decide what to do with it.", ["Find Thirteen", "Decide what happens to it"]),
            stage("done", "Thirteen has a home again.", ends="success"),
            stage("lost", "Thirteen is dead, and its kennel is empty.", ends="failure"),
        ]})


# ---- items -------------------------------------------------------------------------------------------------------------------------
ITEMS = [   # id, name, category, extra, summary
    ("sk_iron_key", "The machine shop's iron key", "quest", {}, "A big iron key on a cord. It opens every locked door in the old machine shop."),
    ("sk_bridle", "An old bridle", "quest", {}, "Cracked leather and a bit gone green. A fleshdobbin that is bridled stops being one."),
    ("sk_miners_lunch", "A miner's lunch pail", "gear", {"stackable": True}, "A lunch pail from seventy years ago. Whatever was in it is now something else, and something likes it."),
    ("stonoga_notes", "Stonoga's notes", "quest", {}, "Parchment in a wet, looping hand. She gloats about Vessla's death, her pact with her sister Golub, and where Golub hides."),
    ("theodora_letter", "Theodora Mayville's letter", "quest", {}, "A pigeon-post letter: the village is infested, the postmaster suspects the mine, and fifty gold pieces each is offered."),
    ("citrine", "Citrine", "gear", {"stackable": True, "material": "citrine", "cost_gp": 50}, "A yellow citrine worth 50 gp."),
]


def build_items():
    for (iid, name, cat, extra, summary) in ITEMS:
        d = {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary}
        d.update(extra)
        write(f"data/items/{iid}.json", d)
    write("data/items/lye_soap_flask.json", {
        "id": "lye_soap_flask", "name": "Flask of lye water", "source": {"book": "CrookedMoon"}, "category": "consumable", "weight_lb": 1, "cost_gp": 5, "stackable": True,
        "effects": [{"effect": "damage", "params": {"dice": "2d6", "damage_type": "acid", "save": "dex", "dc": "8+mod:dex+pb", "range": 20, "target": "creature"}}],
        "summary": "Thrown flask of soapy lye. A hag that cannot stand soapy water takes it like a vial of Acid.",
        "text": "A flask of strong lye soap in water, the stuff the miners' wives used on the stink-witch. Thrown, it works as a vial of Acid, and a hag it splashes takes it badly."})


# ---- the plague clock --------------------------------------------------------------------------------------------------------------
TOLL = {1: 10, 2: 12, 3: 14, 4: 16, 5: 18}


def build_schedule():
    ev = []
    for k in range(1, 6):
        e = {"id": f"sk_night_{k}", "summary": f"Night {k} of the Skitter Plague.", "hour": 23, "once": True,
             "when": f"flag.plague_started and not flag.stonoga_slain and flag.plague_day < {k} and days_since.plague_started >= {k}",
             "set": {"plague_day": k, "plague_toll": TOLL[k]}}
        if k == 1:
            e.update({"location": "wickermoor_village", "narration": "Bread is dearer by morning, and the centipedes have come up the walls of every house on the Round."})
        if k == 3:
            e.update({"location": "wickermoor_village", "narration": "Shutters stay closed along the north row, and the Green Queen's common room has become a sickroom. This is no longer a bad week. This is an epidemic."})
        ev.append(e)
    ev.append({"id": "sk_midnight_swarm", "summary": "A dead villager bursts into a skitterswarm at the Midnight Hour.", "hour": 23, "location": "wickermoor_village", "here_only": True,
               "when": "flag.plague_day >= 2 and not flag.stonoga_slain and not flag.sk_midnight_done", "dialogue": "skitterdeep/clock:midnight_swarm"})
    for where in ("foxwillow", "druskenvald_estate", "sk_hills_trail"):    # wherever the party is away (a place per chapter; the others' places join as they land)
        ev.append({"id": "sk_letter_pigeon_" + where, "summary": "Theodora's pigeon finds the party while it is away from the village.", "hour": 8, "once": True, "location": where,
                   "when": "flag.plague_started and not flag.skitter_asked and not flag.skitter_letter_hook and days_since.plague_started >= 1",
                   "dialogue": "skitterdeep/letter:arrives"})
    write("data/schedule/skitterdeep.json", {"id": "skitterdeep", "region": REGION, "summary": "The Skitter Plague's clock: nights in the village, and a pigeon with a letter.", "events": ev})


# ---- cutscenes ---------------------------------------------------------------------------------------------------------------------
PICTURES = {
    "sk_floor_boils": "Inn floorboards bulging by lamplight, centipedes pouring from a knothole in a dark bedroom",
    "sk_floor_boils_2": "A sleeper's shape seen from behind the bedpost as a swarm of centipedes rises over the blanket",
    "sk_bitten": "Villagers huddled in blankets in a lantern-lit village square at twilight, bowls and buckets beside them, a faint green gleam on their faces",
    "sk_bitten_2": "A split flour sack on a bakery floor alive with centipedes, a baker's hands hovering over it",
    "sk_tunnels": "A hand-drawn map of a village with thin tunnel lines running north-west into wooded hills",
    "sk_tunnels_2": "Tiny tunnels in a cellar floor, dozens of centipedes streaming along them toward the north-west wall",
    "sk_oakum_turn": "A woman in a butcher's apron ahead of the party in moonlit hills, her nose lifted to a deer in the trees",
    "sk_oakum_turn_2": "A silhouette bent and lengthening into a wolf among moonlit trunks, then a wolf crouched in bracken with its eyes lowered",
    "sk_glitterdeep": "A mining headframe and winch tower over a black square pit, a chain hanging into the dark, green gas rising against wooded hills",
    "sk_glitterdeep_2": "A warehouse sign reading Glitterdeep with two letters painted over so that it says Skitterdeep",
    "sk_lift_falls": "The winch drum spinning free and a chain whipping through the air at the top of a mine shaft",
    "sk_lift_falls_2": "A wooden lift platform dropping down a square shaft, giant centipedes leaping from it to the walls",
    "sk_stonoga_end": "A tall stringy hag whose black eyes burst, her long neck curling like a dead centipede",
    "sk_stonoga_end_2": "A hag's body sinking into a spreading grey sludge on a laboratory floor, a small dead centipede curled beside it",
    "sk_plague_lifts": "A tide of centipedes streaming out under doors and across moonlit fields away from a village at twilight",
    "sk_plague_lifts_2": "A kind apothecary wiping a feverish brow as colour returns to the sleeper's face by lamplight",
    "sk_reopening": "A lord in a striped suit and a plump mayor in a bowler hat at a mine head with plans and labourers, a headframe behind them",
    "sk_reopening_2": "Labourers carrying new timbers toward a mine entrance in the morning, a freshly painted sign reading Glitterdeep",
    "sk_cave_in": "Miners feasting at a long table with a tall glamoured woman who ladles them soup, lamplight gold and warm",
    "sk_cave_in_2": "Tunnels coming down in dust and rubble while knights in wine-red surcoats ride in with torches",
    "sk_kindred": "A cage in a laboratory holding the belongings of a missing person, a ledger beside it open to a page of cold handwriting",
    "sk_kindred_2": "A wall in the deep mine etched with rows of centipedes, a crooked house drawn at the centre",
    "sk_rejuvenation": "A tree freed of the plague, and in its bark a vision of a forest choked with fungus and a rotting deer",
    "sk_rejuvenation_2": "A hill tree with healthy green leaves in morning light, a faint sickly fungal glow in the shadows beneath it",
}


def build_cutscenes():
    style = read("tools/content/ghostlight_cutscenes.json")["style"]
    write("tools/content/skitterdeep_cutscenes.json", {"style": style, "pictures": PICTURES})
    for cid, desc in PICTURES.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("sk_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


# ---- travel ------------------------------------------------------------------------------------------------------------------------
def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if x["id"] not in ("sk_hills_trail", "sk_camp")] + [
        {"id": "sk_hills_trail", "name": "The Hill Trail", "location": "sk_hills_trail", "spawn": "default", "pos": [0.31, 0.41], "region": REGION,
         "when": "flag.skitter_trail_known or visited:sk_hills_trail", "summary": "A rutted trail through wooded hills north-west of Wickermoor."},
        {"id": "sk_camp", "name": "Glitterdeep Mine", "location": "sk_camp", "spawn": "from_road", "pos": [0.195, 0.22], "region": REGION,
         "when": "flag.skitter_trail_known or visited:sk_camp", "summary": "The abandoned mine, eight hours north-west of Wickermoor, with its sign painted over to read Skitterdeep."}]
    t["roads"] = [x for x in t["roads"] if x["id"] not in ("wickermoor_to_sk_trail", "sk_trail_to_camp")] + [
        {"id": "wickermoor_to_sk_trail", "from": "wickermoor_village", "to": "sk_hills_trail", "hours": 6, "name": "The hill road", "when": "flag.skitter_trail_known or visited:sk_hills_trail"},
        {"id": "sk_trail_to_camp", "from": "sk_hills_trail", "to": "sk_camp", "hours": 2, "name": "The hill trail", "when": "flag.skitter_trail_known or visited:sk_camp"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


def build_bosses():
    path = ROOT / "narrative/combat/bosses.json"
    b = json.loads(path.read_text())
    b.setdefault("bosses", {})["centipede_hag"] = {"title": "The Centipede Hag, Vermintoll Coven"}
    path.write_text(json.dumps(b, indent=2, ensure_ascii=False) + "\n")


# ---- Wickermoor's side -----------------------------------------------------------------------------------------------------------------
PLAGUE_ON = "flag.plague_started and not flag.stonoga_slain"


def open_near(rows, x, y):
    for r in range(0, 8):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if max(abs(dx), abs(dy)) == r and 0 <= y + dy < len(rows) and 0 <= x + dx < len(rows[0]) and rows[y + dy][x + dx] == ".":
                    return (x + dx, y + dy)
    raise SystemExit(f"no open square near {x},{y}")


def prepend_npc(npcs, who, entries):
    i = next((j for j, n in enumerate(npcs) if n["npc"] == who), 0)
    npcs[i:i] = entries


def build_village():
    path = ROOT / "data/locations/wickermoor_village.json"
    v = json.loads(path.read_text())
    rows = v["map"]["rows"]
    mine_props = {"sk_bitten_scene", "sk_notice_a", "sk_notice_b", "sk_sickbed_a", "sk_sickbed_b", "sk_sickbed_c", "sk_bile_bucket", "sk_vil_crawlers_a", "sk_vil_crawlers_b",
                  "sk_vil_crawlers_c", "sk_ribbons", "sk_reopening_scene", "sk_shut_a"}
    v["props"] = [p for p in v["props"] if p["id"] not in mine_props]
    mine_dlg = {SK + "queue:haldor", SK + "queue:ottilie", SK + "queue:pim", SK + "guide:offer"}
    v["npcs"] = [n for n in v["npcs"] if n.get("dialogue") not in mine_dlg]
    v["encounters"] = [e for e in v.get("encounters", []) if not e["id"].startswith("sk_")]
    c = open_near(rows, 30, 22)
    v["props"] += [
        prop("sk_bitten_scene", c, "Villagers in blankets, and a split sack of flour", kind="decor", call=SK + "hook:bitten", approach=8,
             call_when="flag.act2_done >= 1 and not flag.bitten_seen and not flag.stonoga_slain"),
        prop("sk_notice_a", open_near(rows, 36, 26), "A quarantine notice, nailed to the post", model="notice_board", when=PLAGUE_ON),
        prop("sk_notice_b", open_near(rows, 24, 23), "A second notice: no bread to be baked in the open", model="signpost", when="flag.plague_day >= 1 and not flag.stonoga_slain"),
        prop("sk_sickbed_a", open_near(rows, 27, 27), "A sick bed under a blanket", model="bed", when=PLAGUE_ON), prop("sk_sickbed_b", open_near(rows, 33, 28), "A sick bed under a blanket", model="bed", when=PLAGUE_ON),
        prop("sk_sickbed_c", open_near(rows, 25, 21), "A sick bed, empty and stripped", model="bed", when="flag.plague_day >= 2 and not flag.stonoga_slain"),
        prop("sk_bile_bucket", open_near(rows, 28, 25), "A bucket of black bile", model="bucket_brush", when=PLAGUE_ON),
        prop("sk_vil_crawlers_a", open_near(rows, 24, 18), "Centipedes on the wall of the Round", kind="decor", model="soot_patch", when=PLAGUE_ON),
        prop("sk_vil_crawlers_b", open_near(rows, 35, 19), "Centipedes on the wall of the Round", kind="decor", model="soot_patch", when="flag.plague_day >= 1 and not flag.stonoga_slain"),
        prop("sk_vil_crawlers_c", open_near(rows, 31, 30), "Centipedes crawling up the oak", kind="decor", model="soot_patch", when="flag.plague_day >= 2 and not flag.stonoga_slain"),
        prop("sk_shut_a", open_near(rows, 29, 17), "A shop with its shutters nailed shut", kind="decor", model="barred_door", when="flag.plague_day >= 3 and not flag.stonoga_slain"),
        prop("sk_ribbons", open_near(rows, 21, 25), "Mourning ribbons on a door", kind="decor", model="bunting", when="flag.queue_haldor_worse or flag.queue_lost"),
        prop("sk_reopening_scene", open_near(rows, 32, 25), "Lord Phillip and the Mayor with a roll of plans", kind="decor", call=SK + "farewell:reopening", approach=8,
             call_when="flag.skitter_farewell and not flag.glitterdeep_reopening"),
    ]
    qc = [open_near(rows, 12, 32), open_near(rows, 13, 33), open_near(rows, 11, 33)]
    qc = list(dict.fromkeys(qc))
    while len(qc) < 3:
        qc.append(open_near(rows, qc[-1][0] + 2, qc[-1][1]))
    q_when = "flag.plague_started and not flag.stonoga_slain and not flag.queue_done"
    v["npcs"] += [
        npc("haldor_vane", qc[0], "queue:haldor", when=q_when), npc("ottilie_reed", qc[1], "queue:ottilie", when=q_when), npc("pim_fenwick", qc[2], "queue:pim", when=q_when),
        npc("mrs_oakum", open_near(rows, 31, 24), "guide:offer", when="flag.bitten_seen and not flag.oakum_guiding and not flag.oakum_declined and not flag.stonoga_slain"),
    ]
    v["encounters"] = v.get("encounters", []) + tiers("sk_round_swarms", [
        (MID, spread("skitterswarm", [open_near(rows, 29, 24), open_near(rows, 31, 23), open_near(rows, 33, 24), open_near(rows, 30, 26)], "A skitterswarm out of the cobbles"), {"flag": "sk_round_done", "when": MID}),
        (None, spread("skitterswarm", [open_near(rows, 29, 24), open_near(rows, 33, 24)], "A skitterswarm out of the cobbles"), {"flag": "sk_round_done"}),
    ])
    v["encounters"].append(enc("sk_midnight_swarm", [mon("skitterswarm", open_near(rows, 30, 24), "A skitterswarm out of a dead villager")], flag="sk_midnight_done"))
    # the road to the hills leaves by the west edge
    ex = [e for e in v["exits"] if e["id"] != "hills_road"]
    y = next(yy for yy in range(29, 32) if rows[yy][0] == ".")
    ex.append(exit_("hills_road", (0, y), "travel", "default", "The hill road, north-west to Glitterdeep", when="flag.skitter_trail_known or visited:sk_hills_trail"))
    v["exits"] = ex
    sp = v["spawns"]
    sp["from_hills"] = list(open_near(rows, 2, y))
    path.write_text(json.dumps(v, indent=2, ensure_ascii=False) + "\n")

    ap = read("data/locations/wickermoor_apothecary.json")
    ap["npcs"] = [n for n in ap["npcs"] if not str(n.get("dialogue", "")).startswith(SK)]
    prepend_npc(ap["npcs"], "morgan", [
        npc("morgan", (4, 8), "farewell:morgan_thanks", when="flag.stonoga_slain and not flag.skitter_farewell"),
        npc("morgan", (4, 8), "queue:morgan_start", when="flag.plague_started and not flag.queue_asked and not flag.stonoga_slain"),
        npc("morgan", (4, 8), "queue:morgan_order", when="flag.queue_asked and flag.queue_talked and not flag.queue_done"),
        npc("morgan", (4, 8), "hook:morgan_asks", when="flag.act2_done >= 1 and not flag.skitter_asked and not flag.stonoga_slain"),
    ])
    write("data/locations/wickermoor_apothecary.json", ap)
    po = read("data/locations/wickermoor_post_office.json")
    po["npcs"] = [n for n in po["npcs"] if not str(n.get("dialogue", "")).startswith(SK)]
    prepend_npc(po["npcs"], "theodora_mayville", [npc("theodora_mayville", (7, 3), "letter:theodora_pays", when="flag.stonoga_slain and flag.skitter_letter_hook and not flag.theodora_paid")])
    write("data/locations/wickermoor_post_office.json", po)


# ---- the flag registry -------------------------------------------------------------------------------------------------------------
INT_FLAGS = {"plague_started", "plague_day", "plague_toll", "skitterdeep_alert"}
STR_FLAGS = {"queue_outcome", "thirteen_outcome"}


def build_flags():
    """Registers every flag this chapter's dialogue, places, schedule and quests name that no other region's registry holds (the flags are read_later: other
    lanes read them as they build their own sides)."""
    import re
    names = set()
    sources = list((ROOT / "narrative/skitterdeep").glob("*.dialogue")) + [ROOT / f"data/locations/{k}.json" for k in
              ("sk_hills_trail", "sk_camp", "sk_warehouse", "sk_machine_shop", "sk_upper", "sk_deep", "wickermoor_apothecary", "wickermoor_post_office", "wickermoor_village")] + [ROOT / "data/schedule/skitterdeep.json"]
    for src in sources:
        text = src.read_text()
        if src.name.startswith("wickermoor_"):     # only the entries this chapter put there
            d = json.loads(text)
            mine = [x for k in ("props", "npcs", "encounters", "exits") for x in d.get(k, []) if "skitterdeep/" in json.dumps(x) or str(x.get("id", "")).startswith("sk_") or str(x.get("id", "")) == "hills_road"]
            text = json.dumps(mine)
        names |= set(re.findall(r"flag\.([a-z][a-z0-9_]*)", text))
        names |= set(re.findall(r"(?:minutes_since|days_since)\.([a-z][a-z0-9_]*)", text))
        names |= set(re.findall(r'"flag": "([a-z][a-z0-9_]*)"', text))
        names |= set(re.findall(r"^\s*set ([a-z][a-z0-9_]*)", text, flags=re.M))
        names |= set(re.findall(r'"set": \{([^}]*)\}', text) and [k for blob in re.findall(r'"set": \{([^}]*)\}', text) for k in re.findall(r'"([a-z][a-z0-9_]*)":', blob)])
    names |= INT_FLAGS | STR_FLAGS | {"sk_wh_done", "sk_lair_done", "sk_diggers_done", "sk_spy_done", "sk_landing_done", "sk_door_done", "sk_round_done", "sk_midnight_done",
                                      "parcel_rider_slain", "thirteen_slain", "oswald_slain", "stonoga_slain"}
    have = set()
    for f in (ROOT / "data/flags").glob("*.json"):
        if f.name != "skitterdeep.json":
            have |= {x["id"] for x in json.loads(f.read_text())["flags"]}
    have |= {"act2_done"}
    out = []
    for n in sorted(names - have):
        if n in ("now", "true", "false"):
            continue
        t = "int" if n in INT_FLAGS else ("string" if n in STR_FLAGS else "bool")
        out.append({"id": n, "type": t, "summary": "Skitterdeep Mine (R16, build_skitterdeep.py).", "read_later": True})
    write("data/flags/skitterdeep.json", {"flags": out})
    print(len(out), "flags registered")


def check_cells():
    """Every placed thing stands on a square the map leaves walkable."""
    bad = []
    for lid in ["sk_hills_trail", "sk_camp", "sk_warehouse", "sk_machine_shop", "sk_upper", "sk_deep"]:
        d = read(f"data/locations/{lid}.json")
        rows = d["map"]["rows"]

        def ok(c, what):
            x, y = c
            if not (0 <= y < len(rows) and 0 <= x < len(rows[0])) or rows[y][x] in "# w":
                bad.append((lid, what, c, rows[y][x] if 0 <= y < len(rows) and 0 <= x < len(rows[0]) else "off"))
        for k, c in d["spawns"].items():
            ok(c, "spawn " + k)
        for e in d["exits"]:
            if e["id"] not in ("warehouse", "machine_shop", "door"):
                ok(e["cell"], "exit " + e["id"])
        for p in d["props"]:
            ok(p["cell"], "prop " + p["id"])
        for n in d.get("npcs", []):
            ok(n["cell"], "npc " + n["npc"])
        for ct in d.get("containers", []):
            ok(ct["cell"], "container " + ct["id"])
        for e in d.get("encounters", []):
            for m in e["monsters"]:
                ok(m["cell"], f"{e['id']} {m['monster']}")
    for b in bad:
        print("BAD CELL", b)
    return not bad


if __name__ == "__main__":
    build_trail()
    build_camp()
    build_warehouse()
    build_machine_shop()
    build_upper()
    build_deep()
    build_people()
    build_quests()
    build_items()
    build_schedule()
    build_cutscenes()
    build_travel()
    build_bosses()
    build_village()
    if (ROOT / "narrative/skitterdeep").exists():
        build_flags()
    print("cells ok" if check_cells() else "cells BAD")
    print("ok")
