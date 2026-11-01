#!/usr/bin/env python3
"""ONE-SHOT (R17, Memory's Rest). Writes the five places (the shore, the Isle of Mourn on top of its sketch, the ground and upper floors, the Grotto of Tears),
their people, quests, flags (collected from the dialogue and the places), items, the two Fabled Heirlooms, the mutated patient, the Widow's phase, the
cutscene stand-ins, the travel place and road, and Wickermoor's three hooks. Other lanes edit these files afterwards: DO NOT re-run it over them.
    /usr/bin/python3 tools/content/build_memorys_rest.py"""
import json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import memorys_rest_maps as M
from heirlooms_kept import kept

ROOT = Path(__file__).resolve().parents[2]
REGION = "memorys_rest"
MR = "memorys_rest/"


def write(rel, obj):
    if kept(rel):
        return
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


def prop(pid, cell, label=None, kind="examine", model=None, dlg=None, **kw):
    d = {"id": pid, "cell": list(cell), "kind": kind}
    if label:
        d["label"] = label
    if model:
        d["model"] = model
    if dlg:
        d["dialogue"] = MR + dlg
    d.update(kw)
    return d


def npc(nid, cell, dlg=None, **kw):
    d = {"npc": nid, "cell": list(cell)}
    if dlg:
        d["dialogue"] = MR + dlg
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


def door(did, cell, label, locked=False, dc=0, key="", **kw):
    d = {"id": did, "cell": list(cell), "label": label}
    if locked:
        d.update({"locked": True, "lock_dc": dc, "key": key})
    d.update(kw)
    return d


def base(lid, name, summary, text, rows, theme, light, outdoors=False):
    return {"id": lid, "name": name, "region": REGION, "summary": summary, "text": text,
            "map": {"rows": rows, "theme": theme, "light": light, "outdoors": outdoors},
            "areas": [], "spawns": {}, "exits": [], "props": [], "npcs": [], "encounters": [], "rest": "risky"}


def punch(rows, cells):
    rows = [list(r) for r in rows]
    for (x, y) in cells:
        rows[y][x] = "."
    return ["".join(r) for r in rows]


# ---- the shore ---------------------------------------------------------------------------------------------------------------------
def build_shore():
    loc = base("mr_shore", "The Moonsong Shore", "Where the marsh trail gives out on a rocky shore, with a rowboat on a stake.",
               "The last hour of the trail is briars and sucking mud. Then the reeds open on a stony shore, grey water, and far out a low island with violet in its windows.",
               punch(M.shore().rows(), [(0, 18)]), "forest", "dim", True)
    loc["areas"] = [area("mr_landing", "The stony landing", (6, 9), (11, 13)), area("mr_shore_hut", "The fisher's hut", (19, 15), (23, 18)),
                    area("mr_marsh_edge", "The marsh edge", (0, 12), (29, 23))]
    loc["spawns"] = {"default": [2, 18], "from_road": [2, 18], "from_isle": [9, 11]}
    loc["exits"] = [exit_("road_back", (0, 18), "travel", "default", "The marsh road back to Wickermoor")]
    loc["props"] = [
        prop("mr_trail_end", (3, 18), "Where the trail breaks out of the marsh", "decor", call=MR + "shore:arrive", approach=8, call_when="not flag.mr_arrived_shore"),
        prop("mr_rowboat", (9, 10), "A rowboat on a stake", model="cart_broken", dlg="shore:boat"),
        prop("mr_hut_carving", (21, 16), "A driftwood carving of a long-jawed thing", model="statue_head", dlg="shore:hut"),
        prop("mr_shore_reeds", (14, 10), "Reeds", "decor", model="reeds"), prop("mr_shore_reeds2", (22, 11), "Reeds", "decor", model="reeds"),
        prop("mr_shore_boulder", (13, 21), "A black boulder", "decor", model="boulder"),
        prop("mr_shore_rack", (19, 17), "A net rack and drying fish", "decor", model="drying_herbs"),
        prop("mr_shore_bed", (23, 16), "A fisher's bunk", "decor", model="bed_small"),
        prop("mr_shore_dead_tree", (6, 20), "A bleached dead tree", "decor", model="dead_tree_a"),
    ]
    loc["rest"] = "risky"
    loc["rest_text"] = "Rain bouts and mosquitoes; the water never quite settles."
    write("data/locations/mr_shore.json", loc)


# ---- the isle ----------------------------------------------------------------------------------------------------------------------
def build_isle():
    loc = read("data/locations/mr_isle.json")
    loc.update({"name": "The Isle of Mourn", "region": REGION,
                "summary": "A neglected garden island with a brick sanatorium across its north, violet in every window.",
                "text": "A weathered dock, four rowboats knocking, black irises in the shallows, and a dry fountain with a barn owl in it. Above the iron doors, serif letters: Memory's Rest."})
    loc["areas"] = [area("mr_dock", "The weathered dock", (15, 37), (25, 43)), area("mr_forecourt", "The forecourt", (8, 15), (31, 34)),
                    area("mr_front", "The brick front", (8, 4), (31, 14))]
    loc["spawns"] = {"default": [20, 40], "from_boat": [20, 40], "from_doors": [19, 16], "from_ground": [19, 16]}
    loc["exits"] = [exit_("front_doors", (19, 14), "mr_ground", "from_isle", "The iron doors of Memory's Rest"),
                    exit_("front_doors_b", (20, 14), "mr_ground", "from_isle", "The iron doors of Memory's Rest"),
                    exit_("boat_back", (20, 42), "mr_shore", "from_isle", "Row back to the shore", when="flag.mr_crossed")]
    loc["props"] = [
        prop("mr_isle_arrival", (20, 38), "The dock, and the isle beyond it", "decor", call=MR + "shore:isle_arrive", approach=10, call_when="not flag.mr_arrived_isle"),
        prop("mr_owl_fountain", (20, 24), "The dry fountain and its barn owl", model="statue_head", dlg="shore:fountain"),
        prop("mr_boat_a", (17, 42), "A rowboat knocking at the dock", "decor", model="cart_broken"), prop("mr_boat_b", (23, 42), "A rowboat knocking at the dock", "decor", model="cart_broken"),
        prop("mr_isle_iris_a", (12, 34), "Black irises", "decor", model="garden_bed"), prop("mr_isle_iris_b", (28, 34), "Black irises", "decor", model="garden_bed"),
        prop("mr_isle_bench", (13, 24), "A rotted bench", "decor", model="bench"), prop("mr_isle_bench_b", (27, 24), "A rotted bench", "decor", model="bench"),
        prop("mr_isle_lamp", (16, 16), "A lantern post, violet inside", "decor", model="lantern_post"), prop("mr_isle_lamp_b", (24, 16), "A lantern post, violet inside", "decor", model="lantern_post"),
        prop("mr_isle_willow", (8, 25), "An overgrown willow", "decor", model="dead_tree_b"), prop("mr_isle_willow_b", (32, 26), "An overgrown willow", "decor", model="dead_tree_b"),
        prop("mr_farewell_dock", (20, 39), "The dock and the rowboats", "decor", dlg="ending:farewell", call=MR + "ending:farewell", approach=5, call_when="flag.lethica_slain and not flag.mr_farewell_done"),
        prop("mr_isle_name", (21, 16), "The name cut in serif letters above the doors", model="signpost"),
    ]
    loc["rest"] = "no"
    loc["rest_text"] = "Camp feels wrong here: dreams come out of the mist as grey and faded as old paper."
    write("data/locations/mr_isle.json", loc)


# ---- the ground floor --------------------------------------------------------------------------------------------------------------
def build_ground():
    rows = punch(M.ground().rows(), [(18, 35), (19, 35)])
    loc = base("mr_ground", "Memory's Rest, ground floor", "The mask of legitimacy: floral chairs, chamomile, violet tubes, porcelain masks.",
               "A polished desk, a veiled portrait, a hum from every tube. The Behavioral Ward lies west and the Convalescent Ward east, with the Airing Grounds open to the rain between.",
               rows, "manor", "bright")
    loc["map"]["light"] = "bright"
    A = loc["areas"]
    A += [area("mr_l1", "Reception", (14, 27), (23, 34)), area("mr_l2", "Visitation Room", (20, 1), (26, 6)), area("mr_l3", "Moon Porch", (28, 1), (37, 9)),
          area("mr_l4", "Matron's Office", (11, 1), (18, 6)), area("mr_l5a", "Nurse's Station (Behavioral)", (1, 17), (9, 19)),
          area("mr_l5b", "Nurse's Station (Convalescent)", (28, 11), (37, 13)), area("mr_l6a", "Elevator (Behavioral)", (1, 21), (9, 22)),
          area("mr_l6b", "Elevator (Convalescent)", (28, 15), (37, 17)), area("mr_l8", "Pharmacy", (1, 24), (9, 26)),
          area("mr_l9", "Common Room", (1, 28), (9, 34)), area("mr_l10", "The Airing Grounds", (14, 11), (23, 20), light="dim"),
          area("mr_l12", "Examination Room", (1, 11), (9, 15)), area("mr_l13", "Operating Theater", (1, 1), (9, 9)),
          area("mr_ring_w", "West corridor", (11, 8), (12, 34)), area("mr_ring_e", "East corridor", (25, 8), (26, 34)),
          area("mr_ring_n", "North corridor", (11, 8), (26, 9)), area("mr_lobby", "The lobby", (11, 22), (26, 25)),
          area("mr_landing", "Convalescent landing", (28, 19), (37, 19)), area("mr_aisle", "Recovery aisle", (32, 20), (33, 34)),
          area("mr_l11a", "Recovery Room A", (28, 20), (30, 21)), area("mr_l11b", "Recovery Room B", (28, 23), (30, 24)),
          area("mr_l11c", "Recovery Room C", (28, 26), (30, 27)), area("mr_l11d_x", "Recovery Room D", (28, 29), (30, 30)),
          area("mr_l11e", "Recovery Room E", (35, 20), (37, 21)), area("mr_l11d", "Recovery Room F (cool)", (35, 23), (37, 24)),
          area("mr_l11g", "Recovery Room G", (35, 26), (37, 27)), area("mr_l7c", "Washroom", (35, 29), (37, 30)),
          area("mr_l7a", "Storage", (28, 32), (30, 33)), area("mr_l7b", "Laundry", (35, 32), (37, 33))]
    loc["spawns"] = {"default": [18, 33], "from_isle": [18, 33], "from_elevator_a": [5, 21], "from_elevator_b": [33, 16], "from_hatch": [36, 24]}
    loc["exits"] = [exit_("front_door", (18, 35), "mr_isle", "from_doors", "Out to the forecourt"), exit_("front_door_b", (19, 35), "mr_isle", "from_doors", "Out to the forecourt")]
    D = loc["doors"] = []
    D += [door("mr_d_pharmacy", (10, 25), "The Pharmacy door", True, 15, "mr_ward_key"), door("mr_d_station_a", (10, 18), "Nurse's Station door", True, 15, "mr_ward_key"),
          door("mr_d_station_b", (27, 12), "Nurse's Station door", True, 15, "mr_ward_key"), door("mr_d_elev_a", (10, 22), "The Behavioral elevator lobby"),
          door("mr_d_elev_b", (27, 16), "The Convalescent elevator lobby"), door("mr_d_office", (15, 7), "The Matron's door"),
          door("mr_d_visit", (23, 7), "The Visitation Room door", locked_text="The orderlies lock it behind a visit.", unlocked_when="flag.mr_signed_in"),
          door("mr_d_theater", (10, 8), "The Operating Theater doors"), door("mr_d_exam", (10, 13), "The Examination Room door"),
          door("mr_d_common", (10, 31), "The Common Room door"), door("mr_d_porch", (27, 8), "The Moon Porch doors"),
          door("mr_d_recovery", (27, 19), "The Convalescent landing"), door("mr_d_yard_w", (13, 16), "Glass doors to the Airing Grounds"),
          door("mr_d_yard_e", (24, 16), "Glass doors to the Airing Grounds"), door("mr_d_reception", (18, 26), "To Reception", leaf="none")]
    for i, y in enumerate((20, 23, 26, 29, 32)):
        D += [door(f"mr_d_cell_w{i}", (31, y), "A recovery room door"), door(f"mr_d_cell_e{i}", (34, y), "A recovery room door")]
    P = loc["props"] = []
    P += [prop("mr_l1_portrait", (20, 28), "A full-length portrait of a veiled elf woman", model="painting"),
          prop("mr_l1_bell", (17, 28), "The call bell", model="candle_cluster"),
          prop("mr_l1_plaque", (15, 28), "The Code of Conduct", model="notice_board", dlg="reception:plaque"),
          prop("mr_l1_plants", (22, 28), "A fern in a porcelain pot", "decor", model="garden_bed"),
          prop("mr_l2_window", (24, 1), "A barred window onto the courtyard", "decor", model="window_tall"),
          prop("mr_l2_tea", (23, 4), "A tray of chamomile", "decor", model="table_round"),
          prop("mr_l3_note", (31, 4), "A stack of picture books", "search", search_dc=15, dialogue=MR + "cousin:porch_note", when="not flag.mr_antidote_known"),
          prop("mr_l3_glass", (37, 4), "Floor-to-ceiling glass onto the lake", "decor", model="window_tall"),
          prop("mr_l3_chimes", (30, 8), "Wind chimes over a reading nook", "decor", model="lamp"),
          prop("mr_l3_candles", (34, 8), "Aromatherapy candles", "decor", model="candle_cluster"),
          prop("mr_l4_clock", (17, 1), "A loud longcase clock", model="clock_tall"),
          prop("mr_l4_candle", (14, 4), "A violet-flamed candle", "decor", model="candelabra"),
          prop("mr_l4_shelves", (11, 2), "Shelves of records and texts", "decor", model="bookshelf"),
          prop("mr_l5a_station", (7, 18), "The nurse's desk and a hidden switch", model="desk", dlg="rooms1:l5_station"),
          prop("mr_l5b_station", (35, 12), "The nurse's desk and a hidden switch", model="desk", dlg="rooms1:l5_station"),
          prop("mr_l6a_keypad", (5, 21), "Brass doors and a ten-key pad", model="gate_iron", dlg="rooms1:l6_elevator_a"),
          prop("mr_l6b_keypad", (33, 16), "Brass doors and a ten-key pad", model="gate_iron", dlg="rooms1:l6_elevator_b"),
          prop("mr_l8_counter", (5, 26), "The pharmacy counter, mortar and scale", model="shelves", dlg="rooms1:l8_pharmacy"),
          prop("mr_l8_window", (9, 25), "A barred dispensary window", "decor", model="window"),
          prop("mr_l9_chanter", (2, 33), "A patient chanting numbers to the wall", model="chair", dlg="rooms1:l9_chanter"),
          prop("mr_l9_queue", (6, 26 + 1), "A queue at the pharmacy window", "decor", model="bench"),
          prop("mr_l10_bench", (17, 15), "A bench between the hedges", "decor", model="bench"),
          prop("mr_l10_bench_b", (20, 17), "A bench between the hedges", "decor", model="stone_bench"),
          prop("mr_l10_flowers", (18, 14), "Flower beds gone to seed", "decor", model="garden_bed"),
          prop("mr_l10_hugo", (16, 11), "A window above, and a bellow", "decor", dialogue=MR + "hugo:bark", call=MR + "hugo:bark", approach=4, call_when="not flag.mr_hugo_barked"),
          prop("mr_l11_logs", (30, 21), "A bin of patient logs by the door", model="case", dlg="rooms1:l11_logs"),
          prop("mr_l11d_bed", (36, 24), "A narrow bed in a cooler room", model="bed", dlg="rooms1:l11d_bed"),
          prop("mr_l12_table", (5, 14), "The metal table under one lamp", "decor", model="table_round"),
          prop("mr_l12_cabinets", (7, 13), "The glass cabinets", "decor", model="cupboard"),
          prop("mr_l13_pit", (5, 5), "The bright pit of the operating theater", model="table_round", dlg="rooms1:l13_theatre", when="not flag.mr_theatre_done"),
          prop("mr_l13_seats", (3, 2), "Raked seats for twenty-four", "decor", model="chairs"),
          prop("mr_l7a_shelves", (29, 32), "Shelves of linens and uniforms", model="shelves", dlg="extras:l7_storage"),
          prop("mr_l7b_vats", (36, 32), "Laundry vats", "decor", model="barrel"),
          prop("mr_l7c_wash", (36, 29), "A row of washstands", "decor", model="washstand"),
          prop("mr_ring_w_plants", (11, 15), "A potted fern", "decor", model="garden_bed"),
          prop("mr_ring_lamp", (12, 24), "A violet tube humming in its glass", "decor", model="lamp"),
          prop("mr_ring_lamp_b", (25, 24), "A violet tube humming in its glass", "decor", model="lamp"),
          prop("mr_lockdown_panel_w", (11, 20), "A Lockdown panel with a ward-key slot", "decor", model="case"),
          prop("mr_lockdown_panel_e", (26, 30), "A Lockdown panel with a ward-key slot", "decor", model="case")]
    N = loc["npcs"] = []
    N += [npc("mr_orderly_a", (18, 31), "reception:desk", facing="south"), npc("mr_orderly_b", (19, 31), "reception:desk", facing="south"),
          npc("lethica_nightborne", (14, 4), "lethica:office", when="not flag.lethica_slain", facing="south"),
          npc("catherine_winthrop", (23, 4), "cousin:visit", when="not flag.amos_cousin_met"),
          npc("catherine_winthrop", (32, 6), "cousin:visit", when="flag.amos_cousin_met"),
          npc("sarah_godlee", (6, 31), "godlee:common_room"),
          npc("mr_rocking_patient", (37, 6), "cousin:porch_rocking"), npc("doctor_belkin", (7, 12), "belkin:exam", when="not flag.lethica_slain and not flag.mr_lockdown"),
          npc("samuel_blake", (33, 2), "patients:samuel"), npc("thomas_adams", (33, 5), "patients:thomas_a"), npc("emily_hale", (32, 8), "patients:emily_h"),
          npc("wendy_holden", (35, 9), "patients:wendy"), npc("agnes_thorpe", (36, 2), "patients:agnes"),
          npc("victor_lane", (2, 30), "patients:victor"), npc("james_pelham", (6, 28), "patients:james"), npc("geoffrey_barnes", (5, 33), "patients:geoffrey"),
          npc("thomas_redding", (14, 12), "patients:thomas_r"), npc("emily_voss", (20, 16), "patients:emily_v"), npc("harold_stiles", (17, 16), "patients:harold"),
          npc("mr_escapee", (23, 19), "patients:escapee", when="not flag.mr_escapee_seen", approach=5)]
    loc["containers"] = [
        {"id": "mr_c_storage", "cell": [29, 33], "label": "A linen chest", "model": "case", "items": [{"id": "healers_kit", "qty": 1}], "gold": 0, "lock_dc": 0},
        {"id": "mr_c_exam", "cell": [2, 14], "label": "A glass cabinet of instruments", "model": "cupboard", "items": [{"id": "mr_restorative", "qty": 2}], "gold": 0, "lock_dc": 14}]
    loc["encounters"] = [
        {"id": "mr_theatre", "trigger": "dialogue", "flag": "mr_theatre_done", "monsters": [
            monster("mutated_patient", (5, 6), "The patient on the table", facing="south"), monster("wormhost_surgeon", (3, 5), "A watching surgeon", facing="east", art="zombie"),
            monster("wormhost_surgeon", (7, 5), "A watching surgeon", facing="west", art="zombie")]},
        {"id": "mr_patrol_ground", "trigger": "dialogue", "flag": "mr_patrol_done", "monsters": [
            monster("mutant_nurse_cerebral_graft", (17, 30), "A masked orderly", facing="north"), monster("mutant_nurse_tentacle_lash", (20, 30), "A masked orderly", facing="north")]}]
    loc["encounters"][1]["monsters"] += []
    loc["rest"] = "no"
    loc["rest_text"] = "Nobody rests in Memory's Rest unless the Matron says so: the orderlies bring the chamomile."
    loc["lights"] = [{"cell": [15, 4], "kind": "candle", "bright_ft": 20, "dim_ft": 40, "color": "violet", "visual": True}, {"cell": [18, 24], "kind": "candle", "bright_ft": 20, "dim_ft": 40, "visual": True}]
    for k in list(loc["lights"]):
        k.pop("color", None)
    write("data/locations/mr_ground.json", loc)


# ---- the upper floor ---------------------------------------------------------------------------------------------------------------
def build_upper():
    rows = punch(M.upper().rows(), [])
    loc = base("mr_upper", "Memory's Rest, second floor", "Grey, stained, metal and glass: the Processing Wing west, the Experimental Wing east.",
               "Upstairs there are no chairs and no chimes. The violet tubes buzz over tile and steel, and every door has a lock.", rows, "dungeon", "dim")
    A = loc["areas"]
    A += [area("mr_l14", "Orderlies' Apartments", (1, 1), (9, 9)), area("mr_l15", "Restraining Room", (1, 11), (9, 15)), area("mr_l16", "Sedation Hall", (1, 17), (9, 22)),
          area("mr_l17", "Godlee's Quarters", (1, 24), (9, 28)), area("mr_l18", "Crematorium", (1, 30), (9, 34)),
          area("mr_l19", "Lethica's Quarters", (11, 1), (18, 6)), area("mr_l20", "Engineering Room", (20, 1), (26, 6)),
          area("mr_l26", "Experiment Lab", (28, 1), (37, 9)), area("mr_l21", "Hugo's Quarters", (28, 11), (37, 13)), area("mr_l22", "Monster Containment", (28, 15), (37, 21)),
          area("mr_l23", "Belkin's Office", (28, 23), (37, 27)), area("mr_l24", "Surgeons' Rooms", (28, 29), (32, 34)), area("mr_l25", "Observation Chambers", (34, 29), (37, 34)),
          area("mr_l27", "Laboratory", (14, 27), (23, 34), light="bright"), area("mr_u_ring_w", "West corridor", (11, 8), (12, 34)),
          area("mr_u_ring_e", "East corridor", (25, 8), (26, 34)), area("mr_u_ring_n", "North corridor", (11, 8), (26, 9)), area("mr_u_ring_s", "South corridor", (11, 22), (26, 25))]
    loc["spawns"] = {"default": [11, 24], "from_elevator": [11, 24], "from_lab": [18, 30]}
    loc["exits"] = [exit_("elev_a_down", (11, 25), "mr_ground", "from_elevator_a", "The Behavioral elevator, down", when="not flag.mr_lockdown"),
                    exit_("elev_b_down", (26, 18), "mr_ground", "from_elevator_b", "The Convalescent elevator, down", when="not flag.mr_lockdown")]
    D = loc["doors"] = [door("mr_u_d_lab_w", (13, 30), "A smooth wall with a mural of an owl", when="flag.mr_lab_open", locked_text="A smooth wall with a mural of a barn owl in a weeping willow."),
                        door("mr_u_d_lab_e", (24, 30), "A smooth wall with a mural of an owl", when="flag.mr_lab_open", locked_text="A smooth wall with a mural of a barn owl in a weeping willow."),
                        door("mr_u_d_l14", (10, 8), "Orderlies' Apartments", True, 15, "mr_ward_key"), door("mr_u_d_l15", (10, 13), "The Restraining Room", True, 15, "mr_ward_key"),
                        door("mr_u_d_l16", (10, 20), "The Sedation Hall"), door("mr_u_d_l17", (10, 26), "Godlee's Quarters", True, 15, "mr_ward_key"),
                        door("mr_u_d_l18", (10, 32), "The Crematorium"), door("mr_u_d_l19", (15, 7), "Lethica's Quarters", True, 15, "mr_ward_key"),
                        door("mr_u_d_l20", (23, 7), "The Engineering Room", True, 15, "mr_ward_key"), door("mr_u_d_l26", (27, 8), "The Experiment Lab", True, 15, "mr_ward_key"),
                        door("mr_u_d_l21", (27, 12), "Hugo's den"), door("mr_u_d_l22", (27, 18), "Monster Containment", True, 15, "mr_ward_key"),
                        door("mr_u_d_l23", (27, 25), "Belkin's office"), door("mr_u_d_l24", (27, 31), "The Surgeons' Rooms"),
                        door("mr_u_d_chamber", (30, 19), "The containment door", True, 20, "")]
    P = loc["props"] = []
    P += [prop("mr_l14_cots", (5, 5), "Five narrow cots and a mirror each", model="bed_small", dlg="rooms2a:l14_apartments"),
          prop("mr_l14_mirror", (3, 4), "A full-length mirror", "decor", model="mirror"),
          prop("mr_l15_chair", (4, 12), "A bolted chair, straps torn from their sockets", "decor", model="chair"),
          prop("mr_l15_log", (8, 12), "Godlee's log, pinned by a calliper", model="papers", dlg="extras:l15_log"),
          prop("mr_l16_beds", (5, 19), "Twelve curtained beds", model="bed", dlg="rooms2a:l16_hall"),
          prop("mr_l17_register", (7, 26), "The master patient register", model="ledger", dlg="rooms2a:l17_register"),
          prop("mr_l17_irises", (8, 27), "A vase of black irises", "decor", model="sill_cups"),
          prop("mr_l18_ash", (5, 32), "The furnace ash glints purple", model="soot_patch", dlg="rooms2a:l18_ash"),
          prop("mr_l18_lockers", (3, 33), "Twelve morgue lockers", "decor", model="case"),
          prop("mr_l19_diagrams", (12, 3), "Revision after revision of a diagram", model="papers", dlg="rooms2b:l19_diagrams"),
          prop("mr_l19_shrine", (17, 5), "A small shrine of mementos", model="portrait_couple", dlg="rooms2b:l19_shrine"),
          prop("mr_l19_study", (14, 1), "Shelves of alchemy texts", "decor", model="bookshelf"),
          prop("mr_l20_unit", (23, 4), "The central cylinder, levers and gauges", model="stove", dlg="rooms2b:l20_unit"),
          prop("mr_l20_pipes", (21, 5), "Violet-glass conduits", "decor", model="rope_coils"),
          prop("mr_l21_file", (35, 12), "A woven mat, bowls, and a high shelf of vials", model="rug_runner", dlg="rooms2b:l21_file"),
          prop("mr_l22_chamber", (29, 18), "A reinforced glass chamber, fogged with breath", model="cage", dlg="rooms2b:l22_chamber"),
          prop("mr_l22_jars", (29, 20), "Jars of floating brains", "decor", model="jars"),
          prop("mr_l23_journal", (32, 25), "The Anatomist's Journal", model="book", dlg="rooms2c:l23_journal"),
          prop("mr_l23_jars", (36, 24), "Specimen jars", "decor", model="jars"),
          prop("mr_l24_pods", (30, 31), "Six slimy metal pods", model="crate_stack", dlg="rooms2c:l24_pods"),
          prop("mr_l25_glass", (35, 30), "A glass-walled chamber", model="cage", dlg="rooms2c:l25_glass"),
          prop("mr_l26_jar", (33, 5), "A glowing jar of alien tissue", "decor", model="jars"),
          prop("mr_l27_eye_w", (12, 30), "A mural: a barn owl in a weeping willow", model="painting", dlg="rooms2c:l27_eye"),
          prop("mr_l27_eye_e", (25, 30), "A mural: a barn owl in a weeping willow", model="painting", dlg="rooms2c:l27_eye"),
          prop("mr_l27_lab", (19, 29), "Bubbling glass, flasks and brass tubing", model="stewpot", dlg="rooms2c:l27_lab"),
          prop("mr_l27_bench", (22, 32), "A workbench among the flasks", model="table_round", dlg="workbench:bench"),
          prop("mr_l27_lift", (18, 34), "The lift platform of beams and slats", "decor", model="roof_hatch"),
          prop("mr_u_panel", (11, 12), "A Lockdown panel with a ward-key slot", "decor", model="case")]
    N = loc["npcs"] = [npc("mr_restrained_patient", (3, 12), "rooms2a:l15_patient", facing="east", when="not flag.l15_patient_fate"),
                       npc("sarah_godlee", (5, 26), "godlee:quarters"),
                       npc("doctor_belkin", (33, 4), "belkin:lab_offer", when="not flag.lethica_slain and not flag.belkin_offer", approach=3),
                       npc("mr_glass_patient", (36, 33), "rooms2c:l25_glass", when="not flag.l25_patient_fate")]
    loc["containers"] = [{"id": "mr_c_lab_cabinet", "cell": [36, 5], "label": "A sealed cabinet of the lab's stock", "model": "cupboard", "gold": 0, "lock_dc": 15,
                          "items": [{"id": "philter_of_love", "qty": 1}, {"id": "potion_of_healing_greater", "qty": 4}, {"id": "mr_lethic_serum", "qty": 1}]},
                         {"id": "mr_c_godlee_stash", "cell": [3, 27], "label": "A stash under Godlee's bed", "model": "footlocker", "gold": 250, "lock_dc": 14,
                          "items": [{"id": "bead_of_force", "qty": 1}, {"id": "wand_of_magic_missiles", "qty": 1}, {"id": "ring_of_water_walking", "qty": 1}]}]
    loc["encounters"] = [
        {"id": "mr_patrol_up", "trigger": "dialogue", "flag": "mr_patrol_up_done", "monsters": [
            monster("mutant_nurse_cerebral_graft", (4, 5), "A masked orderly", facing="south"), monster("mutant_nurse_tentacle_lash", (6, 5), "A masked orderly", facing="south")]},
        {"id": "mr_mouthers", "trigger": "dialogue", "flag": "mr_mouthers_done", "monsters": [monster("gibbering_mouther", (22, 5), "A mouther of violet ooze", facing="south")],
         "round_events": [{"id": "mr_more_mouthers", "name": "More memory", "summary": "Another gibbering mouther pours out of the cylinder.", "kind": "summon", "affects": "enemies",
                           "monster": "gibbering_mouther", "count": 1, "side": "enemies", "cells": [[21, 5], [25, 5]], "at": 20, "every": 1, "times": 2}]},
        {"id": "mr_otyugh", "trigger": "dialogue", "flag": "mr_otyugh_done", "monsters": [monster("otyugh", (33, 19), "The abomination in the glass", facing="west")]},
        {"id": "mr_swarm", "trigger": "dialogue", "flag": "mr_swarm_done", "monsters": [monster("swarm_of_venomous_snakes", (31, 26), "A worm swarm", facing="west"),
                                                                                       monster("swarm_of_venomous_snakes", (30, 32), "A worm swarm", facing="east")]},
        {"id": "mr_surgeons", "trigger": "dialogue", "flag": "mr_surgeons_done", "monsters": [monster("wormhost_surgeon", (29, 31), "A waking surgeon", facing="east", art="zombie"),
                                                                                        monster("wormhost_surgeon", (31, 33), "A waking surgeon", facing="east", art="zombie"),
                                                                                        monster("wormhost_surgeon", (29, 33), "A waking surgeon", facing="east", art="zombie")]},
        {"id": "mr_amalgam", "trigger": "dialogue", "flag": "mr_amalgam_done", "monsters": [monster("chimera", (32, 6), "The amalgam", facing="west", art="zombie"),
                                                                                       monster("wormhost_surgeon", (35, 6), "Doctor Belkin", facing="west", art="zombie")]}]
    loc["rest"] = "no"
    loc["rest_text"] = "Not up here."
    write("data/locations/mr_upper.json", loc)


# ---- the grotto --------------------------------------------------------------------------------------------------------------------
def build_grotto():
    rows = M.grotto().rows()
    loc = base("mr_grotto", "The Grotto of Tears", "Folded grey walls like a brain, glowing pools, and the White Worm on its chains.",
               "A cavern like the inside of a skull. Purple and teal water bubbles; vats of verdigris copper hiss along the walls; and over a round stone platform, a pale thing as long as a barn hangs in chains.",
               rows, "cave", "bright")
    loc["areas"] = [area("mr_g_tunnel", "The south tunnel", (14, 38), (18, 42)), area("mr_g_lift", "The lift landing", (1, 21), (3, 23)),
                    area("mr_g_platform", "The platform of glyphs", (10, 12), (22, 20)), area("mr_g_bridge", "The stone bridge", (15, 5), (17, 11)),
                    area("mr_g_vats", "The fermentation vats", (10, 30), (22, 31)), area("mr_g_tanks", "The mutation tanks", (5, 15), (27, 17))]
    loc["spawns"] = {"default": [16, 22], "from_hatch": [16, 40], "from_lift": [2, 22], "from_wile": [16, 23]}
    loc["exits"] = [exit_("hatch_up", (16, 42), "mr_ground", "from_hatch", "The stair up to the hatch room"),
                    exit_("lift_up", (1, 22), "mr_upper", "from_lab", "The Plunge Platform, up (five minutes)")]
    loc["props"] = [
        prop("mr_g_arrival", (16, 25), "The grotto opens out", "decor", call=MR + "grotto:arrival", approach=12, call_when="not flag.mr_grotto_seen"),
        prop("mr_g_worm", (16, 15), "The White Worm, on its chains", "decor", model="gate_pillar"),
        prop("mr_g_drip", (14, 17), "Ichor dripping onto the glyph ring", "decor", model="blood_pool"),
        prop("mr_g_vat_a", (11, 30), "A verdigris copper vat", "decor", model="barrel"), prop("mr_g_vat_b", (21, 30), "A verdigris copper vat", "decor", model="barrel"),
        prop("mr_g_tank_a", (5, 16), "A tank of distilled serum, a shape inside", "decor", model="jars"), prop("mr_g_tank_b", (26, 16), "A tank of distilled serum, a shape inside", "decor", model="jars"),
        prop("mr_g_carvings", (30, 40), "Eel-people carvings down a side passage", "decor", model="floor_glyphs"),
        prop("mr_g_widow_end", (16, 21), "Lethica's veil, on the glyph ring", "decor", call=MR + "grotto:lethica_dies", approach=10, call_when="flag.mr_widow_done and not flag.lethica_slain")]
    loc["npcs"] = [npc("doctor_belkin", (13, 29), "belkin:after_belkin", when="flag.lethica_slain and not flag.belkin_fate"), npc("hugo", (16, 18), "hugo:peace", when="flag.mr_widow_done and not flag.hugo_fate", facing="north"),
                   npc("lethica_nightborne", (16, 20), "grotto:widow_arrives", when="flag.mr_grotto_seen and not flag.mr_widow_done", approach=6)]
    objects = [{"id": f"mr_vat_{i}", "kind": "vessel", "cell": [x, y], "name": "A pressurised vat", "model": "barrel", "ac": 13, "hp": 10, "immune": ["poison", "psychic"]}
               for i, (x, y) in enumerate([(11, 30), (21, 30), (6, 33), (26, 33)])]
    widow = [monster("weeping_widow", (16, 14), "Matron Lethica, the Weeping Widow", boss=True, facing="south"), monster("serum_brute", (16, 15), "Hugo, the Serum Brute", boss=False, facing="south")]
    loc["encounters"] = [
        {"id": "mr_widow", "trigger": "dialogue", "flag": "mr_widow_done", "when": "level >= 8", "lair": True, "objects": objects,
         "monsters": widow + [monster("mutant_nurse_cerebral_graft", (12, 16), "A masked orderly", facing="east"), monster("mutant_nurse_tentacle_lash", (20, 16), "A masked orderly", facing="west")]},
        {"id": "mr_widow", "trigger": "dialogue", "flag": "mr_widow_done", "lair": True, "objects": objects, "monsters": widow},
        {"id": "mr_hugo_after", "trigger": "dialogue", "flag": "mr_hugo_after_done", "monsters": [monster("serum_brute", (16, 19), "Hugo", boss=False, facing="south")]}]
    loc["rest"] = "no"
    loc["rest_text"] = "The worm's dreams press at the edge of sleep."
    write("data/locations/mr_grotto.json", loc)


# ---- people ------------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude
    ("amos_dority", "Amos Dority", "A farmer from the village outskirts", "A worried, stubborn farmer who wants his cousin back as she was.", "friendly"),
    ("catherine_winthrop", "Catherine Winthrop", "Patient and Amos's cousin", "A woman in her forties who clings to a left arm she feels should be gone; calm, polite and blank.", "friendly"),
    ("lethica_nightborne", "Matron Lethica", "The Matron of Memory's Rest", "A white-haired elf in black lace and a mourning veil, who never sits and never stops weeping black tears; she means to end suffering for everyone.", "indifferent"),
    ("hugo", "Hugo", "The First Experiment", "A huge cursed giant with three eyes sewn shut, devoted to the Matron; few words, speaks of himself by name.", "indifferent"),
    ("sarah_godlee", "Nurse Sarah Godlee", "Head orderly", "A hawk-eyed ward sister with a painted porcelain eyepatch and a tight smile; she loves Lethica and wants her to forget Marius.", "indifferent"),
    ("doctor_belkin", "Doctor Belkin", "Surgeon", "A gaunt, courtly surgeon whose cap covers an open skull of larvae.", "indifferent"),
    ("mr_orderly_a", "The orderly at the desk", "Reception", "A staff member in a blank porcelain mask, soft-voiced and in step with the other.", "indifferent"),
    ("mr_orderly_b", "The orderly by the door", "Reception", "A staff member in a blank porcelain mask, soft-voiced and in step with the other.", "indifferent"),
    ("mr_rocking_patient", "A wild-eyed patient", "In a rocking chair", "A patient who knows your name and says it with three strange phrases.", "friendly"),
    ("mr_restrained_patient", "A restrained patient", "Restraining Room", "A patient in a bolted chair, veins faintly violet, halfway through a second dose.", "friendly"),
    ("mr_glass_patient", "A patient behind glass", "Observation Chambers", "A patient with an open brain, seething with worms, who will not be themselves much longer.", "friendly"),
    ("mr_escapee", "A patient with a plan", "Airing Grounds", "A patient who crushed their pills to powder and means to leave.", "friendly"),
    ("mr_theatre_patient", "The patient on the table", "Operating Theater", "An unconscious patient with violet veins.", "friendly"),
    ("mr_surgeon", "A wormhost surgeon", "Surgeon", "A masked surgeon whose speech is low gurgling.", "hostile"),
    ("samuel_blake", "Samuel Blake", "Patient", "A patient who stares into every mirror as if looking for someone.", "friendly"),
    ("thomas_adams", "Thomas Adams", "Patient", "A patient who watches reflections like his twin; his surname is Adams, his twin's is Blake.", "friendly"),
    ("victor_lane", "Victor Lane", "Patient", "A patient who feels tendrils moving under his skin.", "friendly"),
    ("emily_hale", "Emily Hale", "Patient", "A patient who draws spirals on everything.", "friendly"),
    ("wendy_holden", "Wendy Holden", "Patient", "A patient who whispers apologies to people who are not there.", "friendly"),
    ("agnes_thorpe", "Agnes Thorpe", "Patient", "A patient who dreams of hanging in a bright cave.", "friendly"),
    ("james_pelham", "James Pelham", "Patient", "A patient who writes a name, Kehlenn, again and again.", "friendly"),
    ("geoffrey_barnes", "Geoffrey Barnes", "Patient", "A patient who stops mid-movement and carries on minutes later.", "friendly"),
    ("thomas_redding", "Thomas Redding", "Patient", "A patient who insists he is awake, even asleep.", "friendly"),
    ("emily_voss", "Emily Voss", "Patient", "A patient who talks to her shadow, and finds it rude.", "friendly"),
    ("harold_stiles", "Harold Stiles", "Patient", "A patient who listens to the violet lights.", "friendly"),
]


def build_people():
    for (nid, name, title, summary, att) in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION})


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
    write("data/quests/all_is_well.json", {
        "id": "all_is_well", "name": "All Is Well", "kind": "main", "region": REGION, "giver": "amos_dority",
        "summary": "A cousin went west to a hospital for an old injury and wrote that all is well, in a stranger's hand.",
        "stages": [
            stage("the_letter", "A letter says all is well at Memory's Rest. The hand is neat and strange, and the pamphlet shows a hospital on a lake.", "Get ready for a long road west; Wickermoor's people can tell you more.", ["Take the pamphlet"]),
            stage("to_moonsong", "Three nights west by a boggy road, then an hour of marsh to a shore.", "Take the road west from Wickermoor.", ["Reach the Moonsong shore"]),
            stage("the_crossing", "A rowboat on a stake, three miles of grey water, and a low island with violet in its windows.", "Row to the isle. Keep clear of the weeds or bring something the lake fears.", ["Cross to the Isle of Mourn"]),
            stage("sign_in", "The iron doors of Memory's Rest. The orderlies want to know why we have come.", "Sign in at Reception: as visitors, as patients, or to see the Matron.", ["Sign in at Reception"]),
            stage("find_the_cousin", "We are in. Catherine is somewhere in the wards.", "See Catherine in the Visitation Room, or search the Moon Porch.", ["Meet Catherine", "Search the Moon Porch"]),
            stage("the_truth", "The Matron's medicines take memory. The pale grub under the building feeds on it.", "Learn what the serum is: the diagrams upstairs, Godlee's log, the Sedation Hall, Belkin's journal.", ["Learn what the serum is"]),
            stage("the_way_down", "A cavern under the sanatorium holds the source.", "Reach the Grotto: the Laboratory, or the hatch in a recovery room.", ["Reach the Grotto of Tears"]),
            stage("the_weeping_widow", "In the Grotto of Tears the Matron waits with her giant.", "Face the Weeping Widow.", ["End the Matron's work"]),
            stage("unforgettable", "The Matron is dead and the worm is gone into the lake. The patients must be rowed home.", "Use the antidote doses, then row home from the dock.", ["Decide who is saved", "Row home"]),
            stage("back_in_wickermoor", "Amos and his cousin, in the village at last. Families paid for the patients saved.", ends="success")]})
    write("data/quests/amos_cousin.json", {
        "id": "amos_cousin", "name": "Amos's Cousin", "kind": "side", "region": REGION, "giver": "amos_dority",
        "summary": "Amos Dority wants his cousin Catherine Winthrop back as she was.",
        "stages": [
            stage("asked", "Amos Dority's cousin Catherine went west for a chronic arm injury and has not come home.", "Find Catherine in Memory's Rest.", ["Find Catherine"]),
            stage("found", "Catherine is content, blank and polite. She does not know Amos.", "Bring her home, with or without a cure.", ["Decide what happens to Catherine"]),
            stage("home_cured", "Catherine is home and herself, with her pain and her farm, a little changed.", ends="success"),
            stage("home_hollow", "Catherine is home, calm, and blank. Amos takes her arm and does not mind.", ends="success"),
            stage("left", "Catherine stayed behind on the island. Amos got a letter in a neat strange hand.", ends="failure")]})
    write("data/quests/patients_register.json", {
        "id": "patients_register", "name": "The Patients' Register", "kind": "side", "region": REGION, "giver": "sarah_godlee",
        "summary": "Twelve names in Godlee's register. Name each of them, and learn what each one cannot forget.",
        "stages": [
            stage("started", "Godlee's register lists twelve long-term patients. Each of them is someone's loss.", "Speak to every named patient.", ["Name all twelve"]),
            stage("done", "All twelve are named: Catherine, Samuel, Thomas, Victor, Emily, Wendy, Agnes, James, Geoffrey, Thomas, Emily and Harold.", ends="success")]})
    write("data/quests/godlees_mementos.json", {
        "id": "godlees_mementos", "name": "Godlee's Mementos", "kind": "side", "region": REGION, "giver": "sarah_godlee",
        "summary": "Godlee wants the Matron's mementos of her husband destroyed. They are also the best weapon against the Matron.",
        "stages": [
            stage("asked", "Godlee will help us if we destroy Lethica's mementos upstairs.", "Decide: destroy them for her help, keep them and lie, or refuse.", ["Choose"]),
            stage("destroyed", "We burned the mementos. The orderlies look away.", ends="success"),
            stage("kept", "We kept them and lied. They will matter below.", ends="success"),
            stage("refused", "We refused. Godlee's help is gone, and she is watching us.", ends="failure"),
            stage("caught", "Godlee heard the lie. The staff are hostile.", ends="failure")]})
    write("data/quests/the_lethic_antidote.json", {
        "id": "the_lethic_antidote", "name": "The Solution", "kind": "side", "region": REGION, "giver": "morgan",
        "summary": "Only an antidote restores memories the serum took. It wants three things: ash, brain extract and ichor.",
        "stages": [
            stage("learned", "A patient's note says there must be an antidote. The diagrams upstairs name three ingredients.", "Gather Mnemonic Residue (the furnace), Noetic Extract (the jars), Unrefined Ichor (the lab or the grotto).", ["Gather the three ingredients", "Brew a dose at a workbench"]),
            stage("brewed", "We brewed at least one dose of the antidote.", ends="success"),
            stage("lost", "We left with no antidote, and the worm gone with its ichor.", ends="failure")]})


# ---- items -------------------------------------------------------------------------------------------------------------------------
ITEMS = [
    ("mr_pamphlet", "The sanatorium's pamphlet", "quest", "A glossy pamphlet: a painted hospital on a calm lake and the words Memory's Rest, a place for peace."),
    ("mr_letter", "Catherine's letter", "quest", "A letter in a neat, strange hand that says all is well."),
    ("mr_porch_note", "A patient's note", "quest", "A note hidden in a picture book: one name written over and over, and a plea not to take the medicine, not to be taken upstairs. There must be an antidote."),
    ("mr_code_slip", "A slip with 1756", "quest", "The Behavioral elevator's code, on a nurse's slip."),
    ("mr_ward_key", "A ward key", "quest", "A staff key that opens most restricted doors."),
    ("mr_orderly_garb", "Orderly garb and a porcelain mask", "armor", "A starched uniform and a blank white mask."),
    ("mr_tranquilizer", "A tranquilizer needle", "gear", "An orderly's needle."),
    ("mr_unlabeled_medicine", "An unlabeled medicine", "potion", "A brown bottle: Tonic, Sedative, Hypnotic, Relaxant, Suppressant or Euphoriant. Nobody can tell."),
    ("mr_restorative", "A restorative syringe", "potion", "Belkin's restorative: a quick heal and a light head."),
    ("mr_lethic_serum", "A vial of Lethic Serum", "potion", "A vial of the serum: poison, a day of lost memory, and the key to the Laboratory's owl."),
    ("mr_godlee_diary", "Godlee's diary", "quest", "A diary of devotion to the Matron; it says how to open the Laboratory."),
    ("mr_belkin_journal", "Belkin's journal", "quest", "The Anatomist's Journal: the grotto, the eel-people's language and the hatch incantation."),
    ("mr_hugo_file", "Hugo's file", "quest", "A yellowed file on Hugo's surgeries, his curse and his dependence on it."),
    ("mr_memento_portrait", "The wedding portrait", "quest", "Lethica and Sir Marius on their wedding night. A memento that stops her."),
    ("mr_memento_tabard", "A knight's tabard", "quest", "A blood-stained tabard with a rising-sun device."),
    ("mr_memento_sonnet", "A faded love sonnet", "quest", "A sonnet in a knight's hand."),
    ("mr_stabilizer_stone", "A numbing injector", "potion", "Stoneskin, as a vial and an oversized syringe."),
    ("mr_stabilizer_acid", "An alkaline injector", "potion", "Protection from acid, as a vial and a syringe."),
    ("mr_stabilizer_stim", "An adrenal injector", "potion", "Strength enhanced, as a vial and a syringe."),
]


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat if cat in ("quest",) else "quest", "weight_lb": 0.5, "cost_gp": 0, "summary": summary})
    for (iid, name, summary, mods) in [
        ("mask_of_lethica_nightborne", "Mask of Lethica Nightborne", "A Fabled Heirloom, the High Priestess: a porcelain mask with violet filigree. Bonus to Wisdom and Charisma saves (its darkness powers wait on the engine's heirloom rules).",
         [{"stat": "save", "ability": "wis", "value": 1}, {"stat": "save", "ability": "cha", "value": 1}]),
        ("veil_of_the_weeping_widow", "Veil of the Weeping Widow", "A Fabled Heirloom, Temperance: the veil lifted from her dead face. Bonus to Wisdom saves (its psychic powers wait on the engine's heirloom rules).",
         [{"stat": "save", "ability": "wis", "value": 1}])]:
        write(f"data/magic_items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon", "note": "Fabled Heirloom from Memory's Rest; the book's numbers, our words."},
                                               "category": "wondrous", "weight_lb": 0.5, "cost_gp": 0, "magic": {"rarity": "rare", "attunement": True}, "theme": "relics", "icon": "cloak",
                                               "worn": "head" if iid.startswith("mask") else "neck", "modifiers": mods, "summary": summary})


# ---- monsters ----------------------------------------------------------------------------------------------------------------------
def build_monsters():
    golem = read("addons/dnd_core/data/monsters/flesh_golem.json")
    m = json.loads(json.dumps(golem))
    m.update({"id": "mutated_patient", "name": "Mutated patient", "type": "aberration", "hp": {"average": 50, "dice": "6d8+23"}, "cr": 5, "xp": 1800,
              "summary": "A patient the surgeons cut open: an arm and a foot gone wormlike, 50 Hit Points, slams that burn the mind."})
    for t in ("traits",):
        m[t] = [x for x in m.get(t, []) if "absorb" not in x.get("id", "") and "lightning" not in x.get("id", "")]
    write("data/monsters/mutated_patient.json", m)
    widow = read("data/monsters/weeping_widow.json")
    widow["phases"] = [{"id": "desperate_measures", "name": "Desperate Measures", "when": {"bloodied": True}, "summon": {"monster": "hospital_horror", "count": 3},
                        "say": "mr_widow_phase2", "summary": "Bloodied, she sacrifices her work to live: three hospital horrors burst from their tanks.", "flag": "mr_widow_phase2"}]
    write("data/monsters/weeping_widow.json", widow)


# ---- narrator ----------------------------------------------------------------------------------------------------------------------
NARRATOR = """# R17: Narrator lines for Memory's Rest (region memorys_rest). The Narrator is the Vagrant: second person, present tense, one or two sentences.
# Triggers: enter:<location id or area id>. First draft by Claude; no voice yet.

~ enter:mr_shore
| The marsh lets go of your boots all at once, and there is the water, grey as a pan of dishwater, with a low island out on it.
once
~ enter:mr_isle
| The isle is a neglected garden grown wild round a brick house with violet in every window. Somebody inside is humming.
once
~ enter:mr_ground
| Floral chairs, a bowl of chamomile, a hum in the glass tubes along the walls. The place is trying very hard to be restful.
once
~ enter:mr_upper
| Upstairs is grey tile and steel, and the hum has an edge on it. Nobody has bothered to make this floor kind.
once
~ enter:mr_grotto
| Below the hospital the stone is folded like a brain, and something very large is breathing in its sleep.
once
~ mr_widow_phase2
| Glass bursts outward from the tanks, and what comes out of them has more blades than a sensible person should be given.
"""


def build_narrator():
    (ROOT / "narrative/narrator").mkdir(parents=True, exist_ok=True)
    (ROOT / "narrative/narrator/memorys_rest.dialogue").write_text(NARRATOR)


# ---- flags: collected from the dialogue and the places -----------------------------------------------------------------------------
def build_flags():
    existing = set()
    for f in (ROOT / "data/flags").glob("*.json"):
        if f.name == "memorys_rest.json":
            continue
        existing |= {x["id"] for x in json.loads(f.read_text())["flags"]}
    found: dict = {}
    srcs = [p.read_text() for p in (ROOT / "narrative/memorys_rest").glob("*.dialogue")] + [p.read_text() for p in (ROOT / "data/locations").glob("mr_*.json")]
    srcs += [p.read_text() for p in (ROOT / "data/travel").glob("*.json")]
    srcs += [(ROOT / f"data/locations/{n}.json").read_text() for n in ("wickermoor_village", "wickermoor_apothecary", "wickermoor_mayors_house")]
    for text in srcs:
        for m in re.finditer(r"^[ \t]*set[ \t]+([a-z][a-z0-9_]*)[ \t]*(\+=|-=|=)?[ \t]*(.*)$", text, flags=re.M):
            fid, op, rhs = m.group(1), m.group(2), m.group(3).strip()
            t = "int" if op in ("+=", "-=") or (op == "=" and re.fullmatch(r"\d+|now", rhs)) else ("string" if op == "=" and rhs.startswith('"') else "bool")
            if fid not in found or (found[fid] == "bool" and t != "bool"):
                found[fid] = t
        for m in re.finditer(r"flag\.([a-z][a-z0-9_]*)\s*(?:(>=|<=|==|!=|>|<)\s*(\S+))?", text):
            fid, op, rhs = m.group(1), m.group(2), m.group(3) or ""
            if fid not in found:
                found[fid] = "int" if op in (">=", "<=", ">", "<") or re.fullmatch(r"\d+", rhs) else ("string" if rhs.startswith('"') else "bool")
    for text in srcs:
        for m in re.finditer(r'"(?:flag|until_flag)": "([a-z][a-z0-9_]*)"', text):
            found.setdefault(m.group(1), "bool")
    found.update({k: "int" for k in ("mr_register_named", "mr_conduct_strikes", "mr_truth_clues", "mnemonic_residue", "noetic_extract", "unrefined_ichor", "lethic_antidote_doses",
                                     "mr_patients_saved", "mr_patients_cured", "mr_orderly_cured")})
    flags = [{"id": i, "type": t, "summary": "Memory's Rest: " + i.replace("_", " ") + ".", "read_later": True} for i, t in sorted(found.items()) if i not in existing]
    for f in flags:
        if f["id"] == "renathyr_journal":
            f["summary"] = "The party has read Father Renathyr's journal at the Crimson Monastery (R14 sets it; R17's third hook reads it)."
            f["set_by"] = "engine"
    write("data/flags/memorys_rest.json", {"flags": flags})
    return len(flags)


# ---- cutscenes ---------------------------------------------------------------------------------------------------------------------
PICTURES = {
    "mr_all_is_well": "A glossy pamphlet showing a painted island hospital on a calm lake, held in a farmer's rough hand",
    "mr_all_is_well_2": "Two letters side by side on a plain table, one in a neat strange hand and one in a rough old scrawl",
    "mr_moonsong": "A marsh trail breaking onto a rocky shore at dusk, a rowboat tied to a stake, a low island on grey water",
    "mr_moonsong_2": "The wide lake with an island in mist and violet light in its windows, a rowboat pulling away from the camera",
    "mr_dredger": "Pale weeds parting under a rowboat over a vast pale shape in the grey water",
    "mr_dredger_2": "A rotten ribcage of a vast maw breaching beside a pair of oars, grey rain",
    "mr_isle": "A weathered dock with four rowboats knocking against it, an island of dark garden behind",
    "mr_isle_2": "A dry stone fountain with a weathered barn owl statue before iron double doors with serif lettering above",
    "mr_theater": "A gloved hand lifting a pulsing violet growth from an open operating table under a bright lamp",
    "mr_theater_2": "A patient convulsing on a table, one arm gone wormlike, masked surgeons watching unmoved from raked seats",
    "mr_lockdown": "Violet light rushing down a hospital corridor like something fleeing, doors slamming shut",
    "mr_lockdown_2": "Violet fog settling over an island and a lake at night, a roof vent screaming violet steam",
    "mr_creation": "A stained sheet sliding off a lumpy mass on a steel table in a dim surgery",
    "mr_creation_2": "A gaunt surgeon with his cap lifted off, an open skull full of pale larvae",
    "mr_worm": "A cavern of folded grey walls lit by glowing purple and teal pools, a stone bridge to a round glyph platform",
    "mr_worm_2": "A gargantuan pale grub hanging in chains, tubes running from it to copper vats, ichor dripping onto the glyph ring",
    "mr_first_incision": "A needle sinking into the neck of a huge stitched giant, a veiled woman holding the syringe",
    "mr_first_incision_2": "A giant swollen to twice his size lifting a veiled woman onto his back, a chain leash in her fist",
    "mr_into_oblivion": "A veiled woman in black lace collapsing in her own violet blood, black tears falling",
    "mr_into_oblivion_2": "Chains ripping from cave stone and a pale grub plunging into glowing water, the surface closing over it",
    "mr_hugo_grief": "A huge stitched giant kneeling over a small veiled body in a glowing cavern",
    "mr_hugo_grief_2": "A lone huge figure walking a grey shore at twilight",
    "mr_widows_past": "A wedding portrait of a white-haired elf priestess and a knight, then the same priestess under an owl idol",
    "mr_widows_past_2": "A ritual circle in a cavern, something pale descending from the dark",
    "mr_home": "A line of rowboats full of gowned patients crossing grey water at dusk",
    "mr_home_2": "A farmer at a farm gate holding his cousin in the morning light",
}


def build_cutscenes():
    write("tools/content/memorys_rest_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": PICTURES})
    for cid, desc in PICTURES.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("mr_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


# ---- travel and Wickermoor's hooks -------------------------------------------------------------------------------------------------
def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if x["id"] != "memorys_rest"] + [
        {"id": "memorys_rest", "name": "The Moonsong Shore", "location": "mr_shore", "spawn": "from_road", "pos": [0.14, 0.52], "region": "memorys_rest",
         "when": "flag.mr_hook_open or visited:mr_shore", "summary": "The last of the marsh trail, and the lake that holds Memory's Rest."}]
    t["roads"] = [x for x in t["roads"] if x["id"] != "wickermoor_to_memorys_rest"] + [
        {"id": "wickermoor_to_memorys_rest", "from": "wickermoor_village", "to": "memorys_rest", "hours": 72, "name": "The marsh road west", "when": "flag.mr_hook_open or visited:mr_shore"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


def build_village_hooks():
    """Wickermoor's side: Amos waits in the Round (after the first Act II chapter, or at once for those who found a pamphlet), Morgan's pamphlet, the mayor's amulet,
    the families' payment through Amos, Morgan's slow cure. Idempotent."""
    path = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(path.read_text())
    mine = {MR + "hook:amos_start", MR + "ending:amos_reward", MR + "hook:morgan_pamphlet", MR + "ending:mayor_amulet", MR + "ending:morgan_slow_cure"}
    town["npcs"] = [n for n in town["npcs"] if n.get("dialogue") not in mine]
    jer = next(n for n in town["npcs"] if n["npc"] == "jeremiah_stover")
    morgan = next((n for n in town["npcs"] if n["npc"] == "morgan"), None)
    mayor = next((n for n in town["npcs"] if n["npc"] == "wendel_somerton"), None)
    if morgan is None or mayor is None:
        print("note: morgan or the mayor stands in another place; hooks for them go in their shop and house (see build_extra_hooks)")
    cell_amos = [jer["cell"][0] + 2, jer["cell"][1] + 1]
    i = town["npcs"].index(jer)
    town["npcs"][i:i] = [
        npc("amos_dority", cell_amos, "ending:amos_reward", when="flag.lethica_slain and flag.mr_farewell_done and not flag.mr_paid"),
        npc("amos_dority", cell_amos, "hook:amos_start", when="flag.vessla_slain and not flag.amos_asked and (flag.act2_done >= 1 or flag.renathyr_journal or flag.mr_hook_open)")]
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


def build_extra_hooks():
    """Morgan's shop and the mayor's house (their interiors hold them)."""
    for loc_id, nid, entries in [
        ("wickermoor_apothecary", "morgan", [("hook:morgan_pamphlet", "flag.vessla_slain and not flag.mr_hook_open"), ("ending:morgan_slow_cure", "flag.lethica_slain and flag.mr_farewell_done and not flag.mr_morgan_cure")]),
        ("wickermoor_mayors_house", "wendel_somerton", [("ending:mayor_amulet", "flag.lethica_slain and flag.mr_cure_found and flag.mr_farewell_done and not flag.mayor_amulet_given")])]:
        path = ROOT / f"data/locations/{loc_id}.json"
        town = json.loads(path.read_text())
        mine = {MR + e[0] for e in entries}
        town["npcs"] = [n for n in town.get("npcs", []) if n.get("dialogue") not in mine]
        who = next((n for n in town["npcs"] if n["npc"] == nid), None)
        if who is None:
            print("no", nid, "in", loc_id)
            continue
        k = town["npcs"].index(who)
        town["npcs"][k:k] = [npc(nid, who["cell"], d, when=w) for (d, w) in entries]
        path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    build_shore()
    build_isle()
    build_ground()
    build_upper()
    build_grotto()
    build_people()
    build_quests()
    build_items()
    build_monsters()
    build_narrator()
    build_cutscenes()
    build_travel()
    build_village_hooks()
    build_extra_hooks()
    print("flags:", build_flags())
    print("ok")
