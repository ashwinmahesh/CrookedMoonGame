#!/usr/bin/env python3
"""ONE-SHOT (R22, The Crooked Nightmare). Writes the dream-house: the estate crooked again and in ruins (copies of the R12 estate), the eight dream
scenes N1 to N8 (`nm_*`), their people, quests, flags, items, the dream variants of two monsters, the travel places and Old Rusty's hook in
Wickermoor, and the cutscene lists. The conversations are narrative/nightmare/*.dialogue (drafted by Gemini, edited by hand). Other lanes edit
these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_nightmare.py"""
import copy, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G

ROOT = Path(__file__).resolve().parents[2]
REGION = "crooked_nightmare"
NM = "nightmare/"


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
        d["dialogue"] = NM + dialogue
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


def scene(sid, name, rows, spawn, summary, text, theme="manor", light="dim", outdoors=False, areas=None, rest_text=None):
    w, h = len(rows[0]), len(rows)
    return {"id": sid, "name": name, "region": REGION, "summary": summary, "text": text,
            "map": {"rows": rows, "theme": theme, "light": light, "outdoors": outdoors},
            "areas": areas or [area("scene", name, (1, 1), (w - 2, h - 2))],
            "spawns": {"default": list(spawn)}, "exits": [], "props": [], "npcs": [], "encounters": [], "rest": "no",
            "rest_text": rest_text or "You cannot sleep inside a dream, and the dream will not let you stop. A short breath, then."}


def pad(rows):
    w = max(len(r) for r in rows)
    return [r.ljust(w) for r in rows]


# ---- the estate, crooked again and in ruins ----------------------------------------------------------------------------------------
def estate_variants():
    base = read("data/locations/druskenvald_estate.json")
    keep = lambda p: not any(s in p["id"] for s in ("lamp", "bunting", "candles", "flowers"))
    # crooked again
    c = copy.deepcopy(base)
    c.update({"id": "nm_estate", "name": "The Druskenvald Estate, crooked again", "region": REGION,
              "summary": "The cleansed manor bent crooked again: walls weeping purple slime, red lights flaring in the windows and going dark, screams from inside.",
              "text": "The hill road climbs to the iron gate, and the house waits beyond it, every line of it bent. Purple slime runs down the clapboard, a window flashes red, then black. On the porch a small girl and a red dog are quarrelling over the door.",
              "rest_text": "Not here. The house is listening, and the porch is heaving like a chest."})
    c["props"] = [p for p in c["props"] if keep(p)]
    for p in c["props"]:
        p.pop("when", None)
    c["props"] += [prop(f"nm_slime_{i}", cell, "Purple slime", kind="decor", model="puddle") for i, cell in enumerate([(12, 12), (16, 13), (24, 12), (28, 13)])]
    c["props"] += [prop(f"nm_bush_{i}", cell, "A writhing bush", kind="decor", model="vines") for i, cell in enumerate([(10, 14), (18, 14), (26, 14)])]
    c["exits"] = [exit_("porch_steps", (20, 11), "nm_pit", "default", "Up the heaving porch steps into the house", when="flag.nm_estate_met"),
                  exit_("to_village", (33, 35), "travel", "default", "Down the hill road to the village")]
    c["npcs"] = [npc("dani_jenkin", (20, 14), "estate:dani_start", when="not flag.nm_estate_met", approach=12, facing="north"),
                 npc("dani_jenkin", (20, 14), "estate:dani_again", when="flag.nm_estate_met", facing="north"),
                 npc("shuck", (21, 14), "estate:shuck", facing="north")]
    c["doors"] = [d for d in c.get("doors", [])]
    c["spawns"] = {"default": [20, 20], "from_village": [33, 33]}
    c["encounters"] = []
    write("data/locations/nm_estate.json", c)
    # in ruins
    r = copy.deepcopy(base)
    r.update({"id": "nm_estate_ruins", "name": "The Druskenvald Estate, in ruins", "region": REGION,
              "summary": "A heap of wood, plaster and dust under a clear sky, where the Crooked House stood; spirits swirling round it like wasps round a broken hive.",
              "text": "The manor is gone. Where it stood lies a heap of broken timber and plaster, and over it, under a clean starry sky, the freed spirits turn and turn. A small girl stands calm in the middle of it.",
              "rest_text": "The ruin is quiet now, and the air is clean. A short breath, then, or a long one."})
    rows = [list(x) for x in r["map"]["rows"]]
    for y in range(2, 12):
        for x in range(6, 30):
            if rows[y][x] == "#":
                rows[y][x] = "~" if (x + y) % 3 else "="
    r["map"]["rows"] = ["".join(x) for x in rows]
    r["rest"] = "safe"
    r["props"] = [p for p in r["props"] if keep(p) and p["id"] not in ("estate_front_door",)]
    for p in r["props"]:
        p.pop("when", None)
    r["props"] += [
        prop("nm_ruin_timbers", (14, 8), "Broken timbers", kind="decor", model="fallen_beam"),
        prop("nm_ruin_boards", (22, 7), "A heap of plaster and boards", kind="decor", model="broken_boards"),
        prop("nm_ruin_chimney", (26, 6), "A chimney, standing alone", kind="decor", model="fireplace"),
        prop("nm_ruin_cauldron", (18, 9), "A big iron pot in the rubble", kind="search", search_dc=5, item="cauldron_of_the_vermintoll_coven",
             when="flag.abomination_dead and treasure_at:crooked_house_ruins"),
    ]
    r["exits"] = [exit_("to_village", (33, 35), "travel", "default", "Down the hill road to the village")]
    r["npcs"] = [npc("dani_jenkin", (20, 15), "ending:ruins_start", when="flag.crooked_house_destroyed and not flag.nm_ruins_met", approach=12),
                 npc("dani_jenkin", (20, 15), "ending:menu", when="flag.nm_ruins_met and not flag.nm_chapter_done"),
                 npc("shuck", (21, 15), "ending:sally", when="not flag.sally_released"),
                 npc("shuck", (21, 15), None, when="flag.sally_released"),
                 npc("walter_jenkin", (19, 16), "ending:walter", when="flag.walter_saved"),
                 npc("gilly_jenkin", (21, 16), "ending:menu", when="flag.gilly_saved")]
    r["spawns"] = {"default": [20, 16], "from_village": [33, 33]}
    r["encounters"] = []
    write("data/locations/nm_estate_ruins.json", r)


# ---- the dream scenes -------------------------------------------------------------------------------------------------------------
def disc(w, h, cx, cy, rad):
    out = []
    for y in range(h):
        out.append("".join("." if (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad else " " for x in range(w)))
    return out


def door_prop(pid, cell, label, ref, when=None, model="door", **kw):
    d = prop(pid, cell, label, model=model, dialogue=NM + ref, **kw)
    if when:
        d["when"] = when
    return d


def n1():
    rows = disc(19, 19, 9, 9, 8)
    s = scene("nm_pit", "The Falling House", rows, (9, 14), "A whirl of walls, floors and furniture falling down an endless earthen shaft.",
              "The foyer looked perfect for a breath. Now there is no floor: a disc of tumbling timber, a wet earthen shaft that oozes something like rotten blood, the attic floorboards far above through the wreckage, and no up or down in all of it.",
              theme="manor", light="dark")
    s["areas"] = [area("disc", "The falling disc", (1, 1), (17, 17))]
    P = s["props"]
    P += [prop("nm_pit_fall", (9, 14), "The perfect foyer, for a moment", kind="decor", call=NM + "n1:fall_start", approach=12, call_when="not flag.nm_pit_started"),
          prop("nm_pit_after", (9, 9), "The noose, running out", kind="decor", call=NM + "n1:after", approach=12, call_when="flag.nm_pit_won and not flag.crooked_man_fell"),
          prop("nm_pit_tub", (5, 7), "A clawfoot bathtub, falling", kind="decor", model="bathtub"),
          prop("nm_pit_tree", (13, 6), "A bergamot tree, uprooted", kind="decor", model="pine_b"),
          prop("nm_pit_portrait", (4, 11), "The family portrait, face out", kind="decor", model="family_portrait"),
          prop("nm_pit_moose", (14, 11), "A moose head, glass-eyed", kind="decor", model="stag_head"),
          prop("nm_pit_clock", (11, 13), "A grandfather clock, tolling", kind="decor", model="clock_tall"),
          prop("nm_pit_chandelier", (9, 4), "The chandelier, still lit", kind="decor", model="skull_chandelier"),
          prop("nm_pit_chair", (6, 13), "A chair, turning slowly", kind="decor", model="chair"),
          prop("nm_pit_beams", (12, 4), "A tumbling beam", kind="decor", model="fallen_beam"),
          prop("nm_pit_books", (6, 4), "Books, falling in a flock", kind="decor", model="floor_books")]
    debris = {"id": "crooked_debris", "name": "Crooked Debris", "summary": "The house keeps falling with you, and bits of it hit.", "kind": "save", "affects": "party",
              "at": 20, "every": 1, "pick": "random", "say": "A piece of the house comes tumbling out of the dark.",
              "table": [
                  {"id": "debris_tub", "name": "A clawfoot bathtub", "summary": "A clawfoot bathtub tumbles down on a hero.", "kind": "save", "affects": "party", "save": {"ability": "dex", "dc": 18}, "damage": {"dice": "6d6", "type": "bludgeoning"}, "area": {"around": [9, 9], "radius": 20}},
                  {"id": "debris_tree", "name": "The bergamot tree", "summary": "A bergamot tree wraps a hero in its roots.", "kind": "save", "affects": "party", "save": {"ability": "dex", "dc": 18}, "damage": {"dice": "2d10", "type": "bludgeoning"}, "condition": "restrained", "until": "target_turn_end", "area": {"around": [9, 9], "radius": 20}},
                  {"id": "debris_portrait", "name": "The family portrait", "summary": "The portrait sucks a hero in; they are gone until their next turn is over.", "kind": "save", "affects": "party", "save": {"ability": "dex", "dc": 18}, "condition": "stunned", "until": "target_turn_end", "area": {"around": [9, 9], "radius": 20}},
                  {"id": "debris_moose", "name": "The moose head", "summary": "A moose head gores a hero.", "kind": "save", "affects": "party", "save": {"ability": "dex", "dc": 18}, "damage": {"dice": "6d6", "type": "piercing"}, "area": {"around": [9, 9], "radius": 20}},
                  {"id": "debris_clock", "name": "The grandfather clock", "summary": "The clock tolls over a hero's head.", "kind": "save", "affects": "party", "save": {"ability": "dex", "dc": 18}, "damage": {"dice": "2d10", "type": "thunder"}, "condition": "deafened", "until": "minute", "area": {"around": [9, 9], "radius": 20}},
                  {"id": "debris_chandelier", "name": "The chandelier", "summary": "The chandelier drops on a hero, alight.", "kind": "save", "affects": "party", "save": {"ability": "dex", "dc": 18}, "damage": {"dice": "2d10", "type": "fire"}, "area": {"around": [9, 9], "radius": 20}}]}
    s["encounters"] = [{"id": "nm_crooked_man", "trigger": "dialogue", "flag": "nm_pit_won",
                        "withdraw": {"who": "crooked_man", "at_hp_below": 40, "flag": "nm_pit_won", "say": "My noose, my noose! Oh, you spoil a show!", "speaker": "crooked_man"},
                        "monsters": [monster("crooked_man", (9, 5), "The Crooked Man", boss=True, facing="south")],
                        "round_events": [debris]}]
    s["lights"] = [{"cell": [9, 4], "kind": "lamp", "bright_ft": 15, "dim_ft": 30, "color": "candle"}]
    write("data/locations/nm_pit.json", s)


def n2():
    g = G(30, 22)
    g.fill(1, 1, 28, 20, ".")
    for (x0, y0, x1, y1) in [(1, 1, 28, 2), (1, 19, 28, 20), (1, 1, 2, 20), (27, 1, 28, 20)]:
        g.fill(x0, y0, x1, y1, "#")
    g.put([(4, 4), (5, 4), (9, 3), (22, 4), (24, 5), (25, 4), (4, 17), (5, 17), (8, 18), (23, 17), (25, 16), (14, 3), (15, 3)], "#")
    g.put([(12, 12), (13, 12)], "~")
    rows = g.rows()
    s = scene("nm_dark_wood", "The Dark Wood", rows, (4, 15), "An autumn wood under a full moon, handprints on the trees, a clearing with a small girl in it.",
              "An autumn wood of beech, ash and hickory, blue and grey in a full moon with no face on it. White handprints, small and bright, mark the trunks every few strides, and ahead the trees open on a clearing.",
              theme="forest", light="dim", outdoors=True)
    s["areas"] = [area("wood", "The wood", (1, 1), (28, 20)), area("clearing", "The moonlit clearing", (16, 6), (25, 14), light="dim")]
    P = s["props"]
    hand = [(5, 14), (7, 12), (9, 10), (11, 11), (13, 9), (15, 8)]
    P += [prop("nm_wood_arrive", (4, 15), "The handprint trail begins", kind="decor", call=NM + "n2:wood_start", approach=12, call_when="not flag.n2_started")]
    P += [prop(f"nm_handprint_{i}", c, "A tree with a white handprint", kind="decor", model="tree_marked") for i, c in enumerate(hand)]
    P += [prop(f"nm_wood_pine_{i}", c, "A beech in the dark", kind="decor", model=m) for i, (c, m) in enumerate(
        [((6, 6), "pine_a"), ((10, 7), "pine_b"), ((3, 10), "pine_c"), ((19, 3), "pine_a"), ((24, 10), "pine_b"), ((21, 17), "pine_c"), ((14, 17), "pine_a"), ((8, 15), "pine_b")])]
    P += [prop("nm_wood_leaves_a", (12, 14), "Leaf litter", kind="decor", model="leaves"), prop("nm_wood_leaves_b", (18, 13), "Leaf litter", kind="decor", model="leaves"),
          prop("nm_wood_frederick", (21, 10), "Frederick, a one-eyed stuffed turkey-dinosaur", model="doll", dialogue=NM + "n2:frederick_toy",
               when="flag.nm_frederick_done and not flag.frederick_resolved"),
          prop("nm_wood_door", (23, 14), "A crooked door in the leaves, covered in handprints", model="door", dialogue=NM + "n2:door"),
          prop("nm_wood_stump", (20, 9), "A stump with a bite out of it", kind="decor", model="stone_bench")]
    s["npcs"] = [npc("nm_adela_child", (20, 11), "n2:child_start", when="not flag.nm_wood_done", facing="west"),
                 npc("nm_sleeper_wood", (8, 9), "dani_lantern:wood", when="flag.danis_lantern_asked and not flag.lantern_wood_done", facing="east")]
    s["encounters"] = [{"id": "nm_frederick", "trigger": "dialogue", "flag": "nm_frederick_done", "monsters": [monster("gobblegeist", (21, 10), "Frederick, grown", boss=False, facing="west")]}]
    write("data/locations/nm_dark_wood.json", s)


def n3():
    g = G(20, 15).room(1, 1, 18, 13)
    g.fill(2, 2, 17, 2, "=")        # the hearth wall, bricks
    g.put([(3, 11), (4, 11), (15, 11), (16, 11)], "=")
    rows = g.rows()
    s = scene("nm_oven", "The Oven", rows, (9, 12), "A room-sized brick oven, blazing: a roast on one spit, a captive on the other.",
              "The kitchen oven of the Crooked House, grown to the size of a room: firebrick, iron spits, and a heat that presses on the eyes. A turkey-reptile roasts on one spit, and a woman hangs chained on the other.",
              theme="manor", light="bright")
    s["areas"] = [area("oven", "The oven", (1, 1), (18, 13), light="bright")]
    P = s["props"]
    P += [prop("nm_oven_arrive", (9, 12), "The heat of the oven", kind="decor", call=NM + "n3:oven_start", approach=12, call_when="not flag.n3_started"),
          prop("nm_oven_fire", (9, 2), "The fire, behind the bricks", kind="decor", model="fireplace"),
          prop("nm_oven_spit", (6, 5), "An iron spit as long as a barn", kind="decor", model="rope"),
          prop("nm_oven_roast", (13, 5), "A turkey-reptile on a spit, roasting", model="stewpot", dialogue=NM + "n3:rescue", scale=2.0),
          prop("nm_oven_chain_a", (5, 7), "A locked chain", kind="decor", model="wall_chains"),
          prop("nm_oven_chain_b", (4, 6), "A locked chain", kind="decor", model="wall_chains"),
          prop("nm_oven_chain_c", (6, 6), "A locked chain", kind="decor", model="wall_chains"),
          prop("nm_oven_crank", (9, 4), "A crank the size of a wheel", kind="decor", model="rope_coils"),
          prop("nm_oven_pots", (16, 9), "A rack of pots", kind="decor", model="pot_rack"),
          prop("nm_oven_door", (17, 7), "A crooked door, in the flames", model="door", dialogue=NM + "n3:door")]
    s["npcs"] = [npc("gilly_jenkin", (5, 6), "n3:rescue", when="not flag.nm_oven_done", facing="east"),
                 npc("nm_stonoga", (10, 4), "n3:rescue", when="not flag.stonoga_struck", facing="south")]
    s["lights"] = [{"cell": [9, 3], "kind": "fire", "bright_ft": 30, "dim_ft": 60, "color": "fire"}]
    write("data/locations/nm_oven.json", s)


def n4():
    g = G(30, 26)
    g.fill(1, 1, 28, 24, ".")
    g.fill(0, 0, 29, 0, "#").fill(0, 25, 29, 25, "#").fill(0, 0, 0, 25, "#").fill(29, 0, 29, 25, "#")
    for y in range(7, 20):                 # the crater: scorched, difficult
        for x in range(8, 22):
            if (x - 14.5) ** 2 / 36 + (y - 13) ** 2 / 36 <= 1:
                g.c[y][x] = "~"
    rows = g.rows()
    s = scene("nm_crater", "The Smoking Crater", rows, (14, 22), "A crater under a clean half-moon, a prismatic meteorite in it, a city's lights across the bay.",
              "A cool summer night and a clean half-moon. Across a little bay stand the lights of a great modern city. In front of you the earth is scorched in rays round a smoking crater, and in it a seven-foot stone pulses in every colour there is, and some there are not.",
              theme="village", light="dim", outdoors=True)
    s["areas"] = [area("rim", "The crater's rim", (1, 1), (28, 24)), area("crater", "The crater", (8, 7), (21, 19))]
    P = s["props"]
    P += [prop("nm_crater_arrive", (14, 22), "The crater's rim", kind="decor", call=NM + "n4:crater_start", approach=12, call_when="not flag.n4_started"),
          prop("nm_crater_meteor", (14, 13), "The meteorite, pulsing", model="boulder", scale=2.4, tint="#b36bff", dialogue=NM + "n4:hub", when="not flag.nm_invader_done"),
          prop("nm_crater_dead", (14, 13), "The meteorite, dark and split", model="boulder", scale=2.4, tint="#4a3a66", dialogue=NM + "n4:hub", when="flag.nm_invader_done"),
          prop("nm_crater_after", (14, 15), "The crater, after", kind="decor", call=NM + "n4:after_fight", approach=12, call_when="flag.nm_invader_done and not flag.nm_crater_done"),
          prop("nm_crater_door", (14, 11), "A crooked door in the dead star", model="door", dialogue=NM + "n4:door", when="flag.nm_invader_done"),
          prop("nm_crater_city", (14, 2), "The lights of a great city, across the bay", kind="decor", model="lantern_bracket"),
          prop("nm_crater_scorch_a", (6, 9), "Scorched earth", kind="decor", model="scorch"),
          prop("nm_crater_scorch_b", (23, 17), "Scorched earth", kind="decor", model="scorch"),
          prop("nm_crater_rock_a", (4, 18), "A stone", kind="decor", model="rocks"),
          prop("nm_crater_rock_b", (25, 6), "A stone", kind="decor", model="rocks"),
          prop("nm_crater_bench", (22, 22), "A bench from another world", kind="decor", model="bench")]
    s["npcs"] = [npc("nm_adela_teen", (13, 10), "n4:hub", when="not flag.nm_crater_done", facing="east"),
                 npc("nm_sleeper_crater", (5, 21), "dani_lantern:crater", when="flag.danis_lantern_asked and not flag.lantern_crater_done", facing="east")]
    s["encounters"] = [{"id": "nm_invader", "trigger": "dialogue", "flag": "nm_invader_done", "monsters": [monster("invader_out_of_space", (14, 12), "The thing in the star", boss=False, facing="south")]}]
    write("data/locations/nm_crater.json", s)


def n5():
    rows = ["#" * 26] + ["#" + "." * 24 + "#" for _ in range(5)] + ["#" * 26]
    rows = [r for r in rows]
    # the open edge to the south: void instead of the last wall row
    rows[6] = " " * 26
    rows = pad(rows)
    s = scene("nm_bookshelf", "The Shelf", rows, (3, 4), "The party, shrunk, on a shelf in the library: book spines for walls, a decanter the size of a tower, a cat's face at the open edge.",
              "You are the size of a thimble, on a shelf in the library, and every book is a wall. A decanter stands over you tall as a tower with a man in it up to his waist in rising liquor. Beyond the plank's open edge a cat's face the size of a barn is grinning.",
              theme="manor", light="dim")
    s["areas"] = [area("shelf", "The shelf", (1, 1), (24, 5))]
    P = s["props"]
    P += [prop("nm_shelf_arrive", (3, 4), "The shelf", kind="decor", call=NM + "n5:shelf_start", approach=12, call_when="not flag.n5_started"),
          prop("nm_shelf_decanter", (19, 3), "A decanter the size of a tower", model="jars", scale=7.0, span=[3, 3], dialogue=NM + "n5:hub", when="not flag.nm_shelf_done"),
          prop("nm_shelf_bookcase_a", (4, 1), "A wall of book spines", kind="decor", model="bookcase", scale=3.0),
          prop("nm_shelf_bookcase_b", (10, 1), "A wall of book spines", kind="decor", model="bookcase", scale=3.0),
          prop("nm_shelf_stack", (8, 3), "A book, lying on its back like a hill", kind="decor", model="book_stack", scale=3.0),
          prop("nm_shelf_dust", (13, 3), "Dust, like snow", kind="decor", model="cobwebs"),
          prop("nm_shelf_voices", (14, 4), "Glass thimbles, humming", model="sill_cups", dialogue=NM + "voices:menu", call=NM + "voices:start", approach=8, call_when="flag.nm_voices_dropped and not flag.nm_voices_listened",
               when="flag.nm_voices_dropped and (quest.voices_not_their_own == asked or quest.voices_not_their_own == listening)"),
          prop("nm_shelf_door", (12, 5), "A crooked door in the cat's grin", model="door", dialogue=NM + "n5:door", when="flag.nm_shelf_done")]
    s["npcs"] = [npc("walter_jenkin", (18, 5), "n5:hub", when="not flag.nm_shelf_done", facing="north"),
                 npc("nm_golub", (21, 2), "n5:hub", when="not flag.golub_struck", facing="south"),
                 npc("nm_wisp", (12, 5), "n5:hub", when="not flag.nm_wisp_done", facing="north")]
    s["encounters"] = [{"id": "nm_wisp", "trigger": "dialogue", "flag": "nm_wisp_done", "monsters": [monster("wisp_nightmare", (13, 5), "Wisp, grinning", boss=True, facing="north")]}]
    write("data/locations/nm_bookshelf.json", s)


def n6():
    g = G(26, 34)
    g.fill(1, 1, 24, 32, ".")
    g.fill(0, 0, 25, 0, "#").fill(0, 33, 25, 33, "#").fill(0, 0, 0, 33, "#").fill(25, 0, 25, 33, "#")
    g.fill(8, 2, 17, 4, "_")                  # the dais
    g.fill(3, 19, 11, 19, "=").fill(14, 19, 22, 19, "=")   # the long tables
    g.fill(3, 25, 11, 25, "=").fill(14, 25, 22, 25, "=")
    rows = g.rows()
    s = scene("nm_wedding", "The Wedding Feast", rows, (12, 30), "A moonless meadow wedding: long tables, a ring of masked dancers, a dais with a bride and a goat.",
              "A moonless spring night, and a meadow in flower. Lanterns hang on poles. Two long tables groan with food, a ring of guests in animal masks turns in a dance, and on a raised dais a bride in a crown of roses stands beside a black goat with a bell.",
              theme="village", light="dim", outdoors=True)
    s["areas"] = [area("meadow", "The meadow", (1, 1), (24, 32)), area("dais", "The dais", (8, 2), (17, 4)), area("ring", "The dance ring", (7, 9), (18, 16))]
    P = s["props"]
    P += [prop("nm_feast_arrive", (12, 30), "The wedding, from the lane", kind="decor", call=NM + "n6:feast_start", approach=12, call_when="not flag.n6_started"),
          prop("nm_feast_ring", (12, 12), "The dance ring", model="offering_circle", dialogue=NM + "n6:hub"),
          prop("nm_feast_table_a", (7, 19), "A long table of food", model="table_meal", dialogue=NM + "n6:feast", span=[4, 1]),
          prop("nm_feast_table_b", (16, 25), "The gory feast table", model="table_meal", dialogue=NM + "n6:door", span=[4, 1]),
          prop("nm_feast_dais", (12, 3), "The dais", kind="decor", model="dais"),
          prop("nm_feast_crown", (6, 5), "Flower crowns on a pole", kind="decor", model="garden_bed"),
          prop("nm_feast_after", (12, 7), "The dais, afterwards", kind="decor", call=NM + "n6:bride_burns", approach=12, call_when="flag.nm_drakkenhob_done and not flag.nm_wedding_done"),
          prop("nm_feast_lantern_a", (3, 10), "A wedding lantern", kind="decor", model="lantern_post"),
          prop("nm_feast_lantern_b", (21, 10), "A wedding lantern", kind="decor", model="lantern_post"),
          prop("nm_feast_lantern_c", (3, 28), "A wedding lantern", kind="decor", model="lantern_post"),
          prop("nm_feast_lantern_d", (21, 28), "A wedding lantern", kind="decor", model="lantern_post")]
    P += [prop(f"nm_feast_guest_{i}", c, "A guest in an animal mask, still as a post", kind="decor", model="scarecrow_stitched") for i, c in enumerate(
        [(8, 10), (9, 9), (11, 8), (14, 8), (16, 9), (17, 11), (17, 14), (15, 16), (11, 16), (9, 15), (7, 13), (7, 11)])]
    s["npcs"] = [npc("nm_adela_bride", (12, 3), "n6:bride", when="not flag.nm_wedding_done", facing="south"),
                 npc("tamsin_ledger", (4, 28), "forms:start", when="not flag.forms_refused", facing="east"),
                 npc("nm_sleeper_feast", (20, 22), "dani_lantern:feast", when="flag.danis_lantern_asked and not flag.lantern_feast_done", facing="west")]
    wolf_free = [monster("drakkenhob", (12, 6), "The Drakkenhob", boss=False, facing="south")]
    s["encounters"] = [
        {"id": "nm_drakkenhob", "trigger": "dialogue", "when": "flag.n6_goat_calmed", "flag": "nm_drakkenhob_done", "monsters": copy.deepcopy(wolf_free),
         "round_events": [_song()]},
        {"id": "nm_drakkenhob", "trigger": "dialogue", "flag": "nm_drakkenhob_done", "surprise": "party", "monsters": copy.deepcopy(wolf_free), "round_events": [_song()]}]
    write("data/locations/nm_wedding.json", s)


def _song():
    t = [("drum", "A drum", {"dice": "2d12", "type": "thunder"}, None), ("hurdy", "A hurdy-gurdy", None, "restrained"), ("flute", "A flute", None, "incapacitated"),
         ("fiddle", "A fiddle", None, "frightened"), ("jaw", "A jaw harp", None, "poisoned"), ("bells", "Bells", None, "deafened")]
    table = []
    for (tid, name, dmg, cond) in t:
        e = {"id": f"song_{tid}", "name": name, "summary": f"{name} in the Wedding Song picks on one hero.", "kind": "save", "affects": "party", "save": {"ability": "cha", "dc": 15}}
        if dmg:
            e["damage"] = dmg
        if cond:
            e["condition"] = cond
            e["until"] = "target_turn_end"
        table.append(e)
    return {"id": "wedding_song", "name": "The Wedding Song", "summary": "The masked guests strike up a song, and it finds one hero.", "kind": "save", "affects": "party",
            "at": 20, "every": 1, "pick": "random", "say": "The guests strike up a wedding song, and it has teeth.", "table": table}


def n7():
    g = G(22, 24).room(1, 1, 20, 22)
    g.fill(2, 2, 19, 2, "#")
    g.put([(4, 6), (5, 6), (16, 6), (17, 6), (4, 15), (5, 15), (16, 15), (17, 15)], "~")
    g.fill(7, 17, 14, 17, "~")
    rows = g.rows()
    s = scene("nm_throne", "The Root Throne", rows, (11, 21), "A freezing, crooked stone basement caked in ice, a throne of roots at its heart.",
              "A basement older than the house: freezing, crooked, caked in ice and blue light. Wailing souls swirl in a blizzard that has no wind in it. At the heart of it a throne of black roots holds a man in a crown of brambles, a torch in one hand and an apple in the other.",
              theme="manor", light="dim")
    s["areas"] = [area("basement", "The basement", (1, 1), (20, 22))]
    P = s["props"]
    P += [prop("nm_throne_arrive", (11, 21), "The cold", kind="decor", call=NM + "n7:throne_start", approach=12, call_when="not flag.n7_started"),
          prop("nm_throne_seat", (11, 6), "A throne of roots", model="chair", scale=2.4, tint="#2b2118", dialogue=NM + "n7:hub", when="not flag.nm_throne_done"),
          prop("nm_throne_door", (11, 3), "A crooked door in the icy roots", model="door", dialogue=NM + "n7:door", when="flag.nm_throne_done")]
    P += [prop(f"nm_throne_root_{i}", c, "A black root", kind="decor", model="vines") for i, c in enumerate([(9, 5), (13, 5), (8, 8), (14, 8), (10, 9), (12, 9)])]
    P += [prop("nm_throne_ice_a", (4, 10), "A drift of ice", kind="decor", model="rubble"), prop("nm_throne_ice_b", (18, 12), "A drift of ice", kind="decor", model="rubble"),
          prop("nm_throne_bones", (6, 19), "Old bones in the rime", kind="decor", model="bone_scatter"), prop("nm_throne_chains", (17, 19), "Rusted chains", kind="decor", model="wall_chains"),
          prop("nm_throne_altar", (11, 14), "A crooked altar stone, iced over", kind="decor", model="altar")]
    s["npcs"] = [npc("phillip_druskenvald", (11, 6), "n7:hub", when="not flag.nm_throne_done", facing="south"),
                 npc("nm_vessla", (7, 9), "n7:hub", when="not flag.vessla_vision_struck and not flag.nm_throne_done", facing="east")]
    s["lights"] = [{"cell": [11, 8], "kind": "window", "bright_ft": 20, "dim_ft": 40, "color": "moonlight"}]
    write("data/locations/nm_throne.json", s)


def n8():
    g = G(24, 28).room(1, 1, 22, 26)
    g.put([(3, 3), (4, 3), (19, 3), (20, 3), (3, 23), (4, 23), (19, 23), (20, 23)], "=")
    rows = g.rows()
    s = scene("nm_attic", "Toil and Trouble", rows, (12, 25), "The attic swollen with old rituals, its walls one seething layer of vermin, a clawed cauldron over a fire.",
              "The attic of the Crooked House, swollen and fouled by every ritual it has ever seen. Its walls are a single seething layer of weasels, centipedes and pigeons. On a floor scrawled with sigils a huge clawed cauldron boils over a fire, and then it takes a step.",
              theme="manor", light="dim")
    s["areas"] = [area("attic", "The attic", (1, 1), (22, 26))]
    P = s["props"]
    P += [prop("nm_attic_arrive", (12, 25), "The attic, from the stair", kind="decor", call=NM + "n8:attic_start", approach=12, call_when="not flag.n8_started"),
          prop("nm_attic_cauldron", (12, 8), "A clawed cauldron, boiling", model="cauldron", scale=3.0, dialogue=NM + "n8:hub", when="not flag.nm_toil_won"),
          prop("nm_attic_sigil", (12, 14), "A seven-pointed star in the floor", model="floor_glyphs", scale=2.0, dialogue=NM + "n8:hub", when="not flag.nm_toil_won"),
          prop("nm_attic_after", (12, 18), "The attic, afterwards", kind="decor", call=NM + "n8:after", approach=12, call_when="flag.nm_toil_won and not flag.abomination_dead"),
          prop("nm_attic_bones", (6, 12), "Bones, gnawed", kind="decor", model="bone_scatter"), prop("nm_attic_trunk", (18, 12), "A wrecked trunk", kind="decor", model="footlocker"),
          prop("nm_attic_webs_a", (2, 6), "Cobwebs and feathers", kind="decor", model="cobwebs"), prop("nm_attic_webs_b", (21, 6), "Cobwebs and feathers", kind="decor", model="cobwebs"),
          prop("nm_attic_glyphs_a", (7, 20), "Scrawled sigils", kind="decor", model="rune_circle"), prop("nm_attic_glyphs_b", (17, 20), "Scrawled sigils", kind="decor", model="rune_circle"),
          prop("nm_attic_crib", (4, 17), "A swollen crib", kind="decor", model="crib"), prop("nm_attic_chair", (20, 17), "A wrecked rocking chair", kind="decor", model="rocking_chair"),
          prop("nm_attic_hatch", (12, 1), "The roof hatch, shut", kind="decor", model="roof_hatch")]
    s["npcs"] = [npc("nm_stonoga", (8, 6), "n8:hub", when="not flag.n8_hags_gone", facing="south"),
                 npc("nm_golub", (12, 5), "n8:hub", when="not flag.n8_hags_gone", facing="south"),
                 npc("nm_vessla", (16, 6), "n8:hub", when="not flag.n8_hags_gone", facing="south")]
    vermin = [monster("vermin_infestation", (6, 12), "A vermin infestation", facing="east"), monster("vermin_infestation", (18, 12), "A vermin infestation", facing="west"),
              monster("vermin_infestation", (12, 16), "A vermin infestation", facing="north")]
    bites = {"id": "endless_bites", "name": "Endless Bites", "summary": "The vermin frenzy over every surface: bites for all who stand on them.", "kind": "save", "affects": "party",
             "from_round": 3, "at": 20, "every": 1, "save": {"ability": "dex", "dc": 12}, "damage": {"dice": "2d8", "type": "piercing"}, "condition": "poisoned", "until": "target_turn_end",
             "say": "The walls shiver loose and the vermin pour over every surface at once."}
    s["encounters"] = [{"id": "vermintoll_abomination", "trigger": "dialogue", "flag": "nm_toil_won", "lair": True, "quest": {"id": "crooked_nightmare", "stage": "dreaming_no_more"},
                        "monsters": [monster("vermintoll_abomination_dream", (12, 9), "The Vermintoll Abomination", boss=True, facing="south")] + vermin,
                        "round_events": [bites]}]
    s["lights"] = [{"cell": [12, 9], "kind": "fire", "bright_ft": 30, "dim_ft": 60, "color": "fire"}]
    write("data/locations/nm_attic.json", s)


# ---- people -----------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude, tags
    ("nm_stonoga", "Stonoga Blackstinger", "A vision of the centipede hag", "A dream-sister in a mock chef's outfit who boasts of readying a body for the oven. Vanishes when struck.", "hostile", ["voice_druskenvald"]),
    ("nm_golub", "Golub Graygullet", "A vision of the pigeon hag", "A dream-sister dressed as a schoolteacher who mocks readying a mind. Vanishes when struck.", "hostile", ["voice_druskenvald"]),
    ("nm_vessla", "Vessla Browntooth", "A vision of the weasel hag", "A dream-sister dressed as a mock angel with a flaming sword, hissing of readying a soul. Vanishes when struck.", "hostile", ["voice_druskenvald"]),
    ("nm_wisp", "Wisp", "A cat of many stolen voices", "The cat Wisp as the nightmare makes her: colossal, grinning, speaking in voices she has stolen.", "hostile", ["voice_druskenvald"]),
    ("nm_adela_child", "Little Adela", "A child in a white dress", "Adela as a small girl in a dark wood, holding a one-eyed doll called Frederick. A mole on her right cheek.", "friendly", ["child", "voice_druskenvald"]),
    ("nm_adela_teen", "Teenage Adela", "A girl at a crater", "Adela at fifteen, rapt and charmed, walking down toward a pulsing stone. A mole on her right cheek.", "indifferent", ["voice_druskenvald"]),
    ("nm_adela_bride", "Bride Adela", "A bride in a crown of roses", "Adela as a bride at a moonless wedding, giddy and manic. A mole on her right cheek.", "friendly", ["voice_druskenvald"]),
    ("nm_frederick", "Frederick", "A stuffed turkey-dinosaur", "Little Adela's doll, one-eyed and always hungry. Becomes a Gobblegeist in the dark.", "friendly", []),
    ("nm_sleeper_wood", "A lost sleeper in the wood", "A small boy", "A boy who fell asleep in the wood and cannot find his way out of the dream.", "friendly", ["child", "voice_hollow"]),
    ("nm_sleeper_crater", "A lost sleeper at the crater", "A girl in a nightgown", "A girl who watches the stars and is not afraid, and has forgotten how to wake.", "friendly", ["child", "voice_hollow"]),
    ("nm_sleeper_feast", "A lost sleeper at the feast", "A very small guest", "A very small person in a flower crown who does not know why everyone is wearing masks.", "friendly", ["child", "voice_hollow"]),
]


def build_people():
    for (nid, name, title, summary, att, tags) in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION,
                                         **({"tags": tags} if tags else {})})


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
    write("data/quests/crooked_nightmare.json", {
        "id": "crooked_nightmare", "name": "The Crooked Nightmare", "kind": "main", "region": REGION, "giver": "old_rusty",
        "summary": "The Crooked House is dreaming again, and Lady Adela's nightmares have swallowed her husband and the Jenkins. Eight dreams lie between the porch and the attic.",
        "stages": [
            stage("prodigal_son", "Old Rusty found us in the Round, steady for once: the house on the hill is dreaming, and the vermin are back.", "Go up the hill road to the Druskenvald estate.", ["Reach the estate"]),
            stage("estate", "The house is crooked again. Dani Jenkin waits at the porch with her dog; her parents and the Druskenvalds are inside.", "Talk to Dani, then go in by the porch steps.", ["Go into the house"]),
            stage("crooked_pit", "We stepped into the foyer and the house came apart around us.", "Survive the fall.", ["Beat the Crooked Man"]),
            stage("dark_wood", "We landed in an autumn wood where a little girl held a doll, and white handprints marked the trees.", "Find the child and the crooked door.", ["Find little Adela", "Find the door"]),
            stage("crooked_oven", "Behind the door, an oven the size of a room, with Gilly Jenkin on a spit.", "Free Gilly before the fire takes her.", ["Free Gilly"]),
            stage("smoking_crater", "Behind the flames, a smoking crater under a half-moon, and a girl walking down into it.", "Deal with the star in the crater.", ["Reach the meteorite's door"]),
            stage("crooked_bookshelf", "We were shrunk on a library shelf; Walter Jenkin was drowning in a decanter.", "Free Walter before the liquor rises over him.", ["Free Walter"]),
            stage("wedding_feast", "A moonless wedding in a meadow, with a bride, a goat and a thing in the crowd.", "Get through the feast to the gory table.", ["Reach the feast table's door"]),
            stage("crooked_throne", "A frozen basement and a throne of roots holding Lord Phillip.", "Free Phillip from the roots.", ["Free Phillip"]),
            stage("toil_and_trouble", "The attic, and a cauldron that walked.", "End the Vermintoll Abomination.", ["Defeat the Vermintoll Abomination"]),
            stage("dreaming_no_more", "The house fell in on itself and its spirits went free. Adela is in the Crooked Man's hands, out on the moors.", ends="success"),
        ]})
    write("data/quests/danis_lantern.json", {
        "id": "danis_lantern", "name": "Dani's Lantern", "kind": "side", "region": REGION, "giver": "dani_jenkin",
        "summary": "Dani gave us a lantern of blue mist to carry through the nightmare, and asked us to bring it back lit.",
        "stages": [
            stage("asked", "Dani offered us a small lantern of blue mist to keep the lost company.", "Take Dani's lantern from her at the estate porch."),
            stage("carrying", "We carry Dani's lantern. In the dreams there are small lost sleepers who might follow its light.", "Light the way for lost sleepers in the wood, the crater and the feast, then give the lantern back to Dani.", ["Light the way for a lost sleeper (0 of 3)"]),
            stage("done", "We brought the lantern back lit. Dani smiled, and a little of the mist went with us.", ends="success"),
            stage("dimmed", "The lantern went dim. Dani took it back and said it was all right.", ends="failure"),
        ]})
    write("data/quests/frederick_the_turkey.json", {
        "id": "frederick_the_turkey", "name": "Frederick the Turkey", "kind": "side", "region": REGION, "giver": "nm_adela_child",
        "summary": "Little Adela's doll Frederick turns into a Gobblegeist in the dark. He wants only to gobble, and to be someone's.",
        "stages": [
            stage("found", "Little Adela's one-eyed doll turned out to be a monster that gobbles.", "Settle the doll in the wood."),
            stage("kept", "We carry Frederick now, the way you carry a small and furious pet.", ends="success"),
            stage("bed", "We tucked Frederick back into little Adela's arms, and she fell asleep standing up.", ends="success"),
            stage("left", "We left Frederick in the leaves. Somewhere in the dark a beak clicked.", ends="failure"),
        ]})
    write("data/quests/the_nightmare_forms.json", {
        "id": "the_nightmare_forms", "name": "The Nightmare Forms", "kind": "side", "region": REGION, "giver": "tamsin_ledger",
        "summary": "Tamsin Ledger's dream self has set up a desk at the wedding and will file the party's complaints, if they are in the proper form.",
        "stages": [
            stage("asked", "Tamsin Ledger, in a dream, offered to file our complaints on the proper forms.", "File at least two complaints with Tamsin at the wedding."),
            stage("filing", "Some of our complaints are filed.", "File one more complaint, then submit the forms to Tamsin for a stamp."),
            stage("filed", "Tamsin stamped our forms. The stamp smelled of wedding cake.", ends="success"),
            stage("refused", "Tamsin refused our forms: perjury in a dream is still perjury.", ends="failure"),
        ]})
    write("data/quests/voices_not_their_own.json", {
        "id": "voices_not_their_own", "name": "Voices Not Their Own", "kind": "side", "region": REGION, "giver": "nm_wisp",
        "summary": "Wisp kept stolen voices in glass thimbles. One of them is Walter Jenkin's own, and the others are not ours to keep.",
        "stages": [
            stage("asked", "Wisp's voices lie in glass thimbles on the shelf.", "Listen to the thimbles on the shelf."),
            stage("listening", "We are listening to the thimbles to find which one is Walter's.", "Find Walter's voice among the thimbles and decide what to do with the rest."),
            stage("returned", "We gave Walter his voice back and kept the others.", ends="success"),
            stage("freed", "We gave Walter his voice and let the others go home.", ends="success"),
            stage("lost", "We broke the thimbles by guessing, and the voices scattered.", ends="failure"),
        ]})


# ---- items ------------------------------------------------------------------------------------------------------------------------
ITEMS = [
    ("nm_wicker_star", "A wicker seven-pointed star", "quest", "A woven star from Old Rusty's broom cupboard, old Old Ways work. Gobbling things will not come near it."),
    ("frederick_corn_dolly", "Frederick, the turkey doll", "quest", "A one-eyed stuffed turkey-dinosaur that chews faintly in the pack. A Corn Dolly familiar, and an unwilling one."),
    ("dani_lantern", "Dani's lantern", "quest", "A small lantern of blue mist that keeps the lost company. Dani wants it back lit."),
    ("walter_voice_jar", "Walter's voice, in a thimble", "quest", "A glass thimble warm as a hand, holding a gentle man's voice."),
    ("nm_stamped_complaint", "A stamped complaint", "quest", "Tamsin Ledger's stamp on a Form 22-N, smelling of wedding cake."),
]


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary})
    write("data/magic_items/cauldron_of_the_vermintoll_coven.json", {
        "id": "cauldron_of_the_vermintoll_coven", "name": "Cauldron of the Vermintoll Coven",
        "source": {"book": "CrookedMoon", "note": "Fabled Heirloom from the Crooked Nightmare; the book's numbers, our words. Its Tiny-to-Medium size change, Cookpot, Vermincall and Fortifying Gorge wait on the engine's heirloom rules."},
        "category": "wondrous", "weight_lb": 10, "cost_gp": 0, "magic": {"rarity": "very_rare", "attunement": True}, "theme": "implements", "icon": "bottle",
        "modifiers": [{"stat": "save", "ability": "all", "value": 1}],
        "summary": "A big iron pot the coven cooked in: a spellcasting focus that adds +1 to all saving throws (its heirloom powers wait on the engine)."})


# ---- monsters ---------------------------------------------------------------------------------------------------------------------
def build_monsters():
    w = read("data/monsters/sphinx_of_lore.json")
    w.update({"id": "wisp_nightmare", "name": "Wisp, the dream cat", "size": "gargantuan", "type": "fey", "alignment": "chaotic evil",
              "summary": "Wisp as the nightmare makes her: a gargantuan grinning cat whose head and paws reach in from the shelf's edge. Vanishes at 0 Hit Points."})
    w["source"] = {"book": "CM2024", "edition": "2024", "note": "The Crooked Moon (Legends of Avantris), chapter 22: the Sphinx of Lore's block made Chaotic Evil, Gargantuan and Fey. Numbers are the book's; the words are ours."}
    write("data/monsters/wisp_nightmare.json", w)
    a = read("data/monsters/vermintoll_abomination.json")
    a.update({"id": "vermintoll_abomination_dream", "name": "The Vermintoll Abomination"})
    a["phases"] = [{"id": "scream_ye_vermin", "name": "Scream Ye Vermin", "when": {"bloodied": True}, "legendary_refill": True, "lair": True, "flag": "abomination_frenzy",
                    "say": "nm_abom_phase2", "summary": "The vermin go into a frenzy over every surface: biting for all who stand on them."}]
    write("data/monsters/vermintoll_abomination_dream.json", a)


# ---- the village, travel and cutscenes ------------------------------------------------------------------------------------------------
def build_village_hooks():
    """Old Rusty brings the hook once Chuckles is dead (flag.chuckles_dead, set by Fool's Day; missing flags are false)."""
    path = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(path.read_text())
    town["npcs"] = [n for n in town["npcs"] if str(n.get("dialogue", "")) not in (NM + "hook:rusty_start", NM + "hook:rusty_again")]
    rusty = next(n for n in town["npcs"] if n["npc"] == "old_rusty")
    i = town["npcs"].index(rusty)
    town["npcs"][i:i] = [
        {"npc": "old_rusty", "cell": rusty["cell"], "dialogue": NM + "hook:rusty_start", "when": "flag.chuckles_dead and not flag.nm_hook_given and not flag.crooked_house_destroyed",
         "path": rusty["path"], "pause": 4, "approach": 8},
        {"npc": "old_rusty", "cell": rusty["cell"], "dialogue": NM + "hook:rusty_again", "when": "flag.nm_hook_given and not flag.crooked_house_destroyed", "path": rusty["path"], "pause": 4}]
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    on = "(flag.nm_hook_given or flag.chuckles_dead)"
    for p in t["places"]:
        if p["id"] == "druskenvald_estate" and "chuckles_dead" not in p["when"]:
            p["when"] = f"({p['when']}) and not flag.chuckles_dead"
    for r in t["roads"]:
        if r["id"] == "wickermoor_to_estate" and "chuckles_dead" not in r.get("when", ""):
            r["when"] = f"({r['when']}) and not flag.chuckles_dead"
    t["places"] = [x for x in t["places"] if x["id"] not in ("nm_estate", "nm_estate_ruins")] + [
        {"id": "nm_estate", "name": "The Druskenvald Estate (crooked again)", "location": "nm_estate", "spawn": "from_village", "pos": [0.56, 0.42], "region": REGION,
         "when": f"{on} and not flag.crooked_house_destroyed", "summary": "The cleansed manor on the hill, bent crooked again and dreaming."},
        {"id": "nm_estate_ruins", "name": "The Druskenvald Estate (in ruins)", "location": "nm_estate_ruins", "spawn": "from_village", "pos": [0.56, 0.42], "region": REGION,
         "when": "flag.crooked_house_destroyed", "summary": "A heap of wood and plaster where the Crooked House stood."}]
    t["roads"] = [x for x in t["roads"] if x["id"] not in ("wickermoor_to_nm_estate", "wickermoor_to_nm_estate_ruins")] + [
        {"id": "wickermoor_to_nm_estate", "from": "wickermoor_village", "to": "nm_estate", "hours": 1, "name": "The hill road, again", "when": f"{on} and not flag.crooked_house_destroyed"},
        {"id": "wickermoor_to_nm_estate_ruins", "from": "wickermoor_village", "to": "nm_estate_ruins", "hours": 1, "name": "The hill road, to the ruins", "when": "flag.crooked_house_destroyed"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


SETS = {   # cutscene set -> (scene count, one prompt per scene)
    "nm_crooked_again": ["The manor on its hill at night with every line bent again, purple slime running down the clapboard, one window flashing red then black",
                         "A red dog barrelling out of writhing bushes and knocking a small girl down on a heaving porch step"],
    "nm_house_shatters": ["A perfect foyer, chandelier lit, with a body dropping into frame from above on a rope",
                          "The foyer bursting outward into a whirl of walls, furniture, a bathtub and a moose head, all hanging in the dark",
                          "The floor crumbling into a bottomless pit, the attic floorboards far above through tumbling debris"],
    "nm_noose_runs_out": ["A crooked top-hatted silhouette jerked to a halt by his rope as the party drops past below",
                          "His grin shrinking away above in the dark"],
    "nm_three_adelas_a": ["A little girl in a white dress yanked backwards into the trees by nothing, a doll falling in the leaves",
                          "White handprints glowing on the trunks of an autumn wood under a full moon, the clearing empty"],
    "nm_three_adelas_b": ["A teenage girl shooting up from a smoking crater into the sky",
                          "A new twinkling star among the others over a city's lights across a bay"],
    "nm_three_adelas_c": ["A bride in a crown of roses going up in flame on her dais",
                          "Masked wedding guests torn apart in the firelight of a moonless meadow"],
    "nm_pulled_out": ["A swirl of blue mist round a hand reaching out of the dark",
                      "Outside at a porch, a small girl with her eyes closed, a thread of blue light running from her hands into a crooked house"],
    "nm_cauldron_births": ["Thousands of vermin rippling as one over the walls of an attic",
                           "A brew boiling over in a clawed cauldron and slithering up into a three-headed thing of weasel, centipede and pigeon",
                           "The clawed cauldron taking its first step across a floor of sigils"],
    "nm_dreaming_no_more": ["A manor folding in on itself floor by floor in a cloud of dust",
                            "Rubble under a cloudless sky, ghosts swirling round it like wasps round a broken nest, a calm little girl standing in the middle",
                            "A butler's ghost nodding once, then joining the swirl"],
    "nm_sally_goes_free": ["A pale girl's shape lifting out of a red dog",
                           "The dog shaking himself, an ordinary dog now, licking a small girl's hand"],
}


def build_cutscenes():
    pics = {}
    for first, prompts in SETS.items():
        for n, desc in enumerate(prompts, 1):
            cid = first if n == 1 else f"{first}_{n}"
            pics[cid] = desc
    write("tools/content/nightmare_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": pics})
    for cid, desc in pics.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("nm_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


if __name__ == "__main__":
    estate_variants()
    n1(); n2(); n3(); n4(); n5(); n6(); n7(); n8()
    build_people()
    build_quests()
    build_items()
    build_monsters()
    build_village_hooks()
    build_travel()
    build_cutscenes()
    print("ok")
