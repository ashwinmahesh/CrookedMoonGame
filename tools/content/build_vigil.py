#!/usr/bin/env python3
"""ONE-SHOT (R23, Wicker's Vigil). Writes the night before the finale: Wickermoor's square on the eve (barricades, volunteers, the Silent Church shelter),
the moors approach (A0 edge, A1 heath, A2 quagmire, A3 hardpan and the foot of the Rise), Rowan's Rise (B1 the stone circle, B2 the summit), their people,
quests (main `wickers_vigil` and five side quests), the level-scaled fights, the Wicker Man variant with its phases, the travel places and the hooks.
The conversations are narrative/vigil/*.dialogue (drafted by Gemini where they talk, written by hand where they count). Other lanes edit these files
afterwards: DO NOT re-run it over them.
    python3 tools/content/build_vigil.py"""
import copy, json, random, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G

ROOT = Path(__file__).resolve().parents[2]
REGION = "wickers_vigil"
VG = "vigil/"


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
        d["dialogue"] = VG + dialogue
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


def place(lid, name, rows, spawns, summary, text, theme="wilderness", light="dim", outdoors=True, areas=None, rest="no", rest_text=None):
    w, h = len(rows[0]), len(rows)
    return {"id": lid, "name": name, "region": REGION, "summary": summary, "text": text,
            "map": {"rows": rows, "theme": theme, "light": light, "outdoors": outdoors},
            "areas": areas or [area("all", name, (1, 1), (w - 2, h - 2))],
            "spawns": spawns, "exits": [], "props": [], "npcs": [], "encounters": [], "rest": rest,
            "rest_text": rest_text or "Not tonight. The fire on the hill is in sight and the burning has begun; a few breaths, and then you must go on."}


def frame(g, w, h):
    g.fill(0, 0, w - 1, 0, "#").fill(0, h - 1, w - 1, h - 1, "#").fill(0, 0, 0, h - 1, "#").fill(w - 1, 0, w - 1, h - 1, "#")


def scatter(g, rng, n, ch, x0, y0, x1, y1, keep=()):
    """n single squares of `ch` at random inside the box, never on a kept cell."""
    for _ in range(n):
        x, y = rng.randint(x0, x1), rng.randint(y0, y1)
        if (x, y) not in keep and g.c[y][x] == ".":
            g.c[y][x] = ch


def blob(g, rng, cx, cy, rx, ry, ch="~", only="."):
    for y in range(max(1, cy - ry), min(g.h - 1, cy + ry + 1)):
        for x in range(max(1, cx - rx), min(g.w - 1, cx + rx + 1)):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 + rng.uniform(-0.25, 0.2) and g.c[y][x] in only:
                g.c[y][x] = ch


# ---- B. the village on the eve ------------------------------------------------------------------------------------------------
def square():
    w, h = 42, 34
    g = G(w, h)
    g.fill(1, 1, w - 2, h - 2, ".")
    frame(g, w, h)
    # the houses along the north and south rims, the church on the east side
    for (x0, y0, x1, y1) in [(2, 2, 9, 7), (12, 2, 18, 6), (24, 2, 30, 6), (2, 26, 9, 31), (13, 27, 19, 31), (22, 27, 28, 31), (32, 24, 39, 31)]:
        g.fill(x0, y0, x1, y1, "#")
    g.fill(33, 2, 39, 9, "#")                                   # the Silent Church, outside walls
    g.fill(34, 3, 38, 8, "_")
    g.fill(34, 3, 38, 8, "#")
    g.put([(36, 9)], ".")                                       # its door
    g.fill(20, 2, 22, 5, ".")                                   # the moor road, between the houses
    g.put([(14, 28), (15, 28), (24, 28)], ".")
    # the barricades: carts and planks across the moor road mouth and the south lane, with a gap
    g.fill(19, 8, 23, 8, "=").put([(21, 8)], ".")
    g.fill(14, 24, 28, 24, "=").put([(20, 24), (21, 24)], ".")
    # the inn yard table, the well, stalls
    g.fill(8, 14, 14, 14, "=")
    g.put([(21, 16), (26, 12), (27, 12), (10, 20), (11, 20), (30, 20), (31, 20)], "=")
    rows = g.rows()
    s = place("wv_square", "Wickermoor, the night before", rows, {"default": [21, 22], "from_moors": [21, 10], "from_shelter": [36, 11], "from_travel": [21, 22]},
              "The Founder's Round on the eve of the burning: carts across the moor road, a long table under lanterns, a bonfire on the hill, a goat on the notice board.",
              "The bonfire on the hill north of the village is visible from every window, and the village has gone out to meet it: carts and planks barring the moor road, volunteers lining up in a queue that bends round the well, a long table under lanterns, and across the way the stone door of the Silent Church standing open. The goat is on the notice board.",
              theme="village", light="dim", rest="no",
              areas=[area("sq_round", "The Round", (10, 10), (32, 22)), area("sq_barricade", "The barricade", (14, 8), (28, 9)), area("sq_inn_yard", "The inn yard", (4, 12), (16, 18)),
                     area("sq_church", "The church steps", (33, 9), (39, 14))])
    s["exits"] = [exit_("to_moors", (21, 3), "wv_moor_edge", "from_village", "North up the moor road to the burning", when="flag.wv_started and not flag.wicker_man_burned"),
                  exit_("to_shelter", (36, 9), "wv_shelter", "from_square", "Into the Silent Church"),
                  exit_("south_lane", (21, 32), "travel", "default", "South, out of the village")]
    P = s["props"]
    P += [prop("wv_sq_arrive", (21, 22), "The Round, on the eve", kind="decor", call=VG + "square:arrive", approach=12, call_when="not flag.wv_square_seen"),
          prop("wv_sq_barricade", (21, 8), "A barricade of carts and planks", model="cart_broken", dialogue=VG + "square:barricade", span=[1, 1]),
          prop("wv_sq_barricade_a", (19, 8), "A hay cart on its side", kind="decor", model="cart"),
          prop("wv_sq_barricade_b", (23, 8), "A stack of planks", kind="decor", model="woodpile"),
          prop("wv_sq_board", (30, 14), "The notice board, and the goat on it", model="notice_board", dialogue=VG + "goat:board", when="not flag.goat_resolved"),
          prop("wv_sq_board_after", (30, 14), "The notice board, empty of goat", kind="decor", model="notice_board", when="flag.goat_resolved"),
          prop("wv_sq_dinner", (11, 14), "The long table under the lanterns", model="table_meal", dialogue=VG + "dinner:table", span=[4, 1]),
          prop("wv_sq_post", (27, 17), "The post cart, loaded with letters", model="handcart", dialogue=VG + "letters:cart", when="flag.wv_letters_asked and not flag.letters_done"),
          prop("wv_sq_well", (21, 16), "The village well", kind="decor", model="well_stone"),
          prop("wv_sq_sick", (31, 12), "A wagon of the sick, under blankets", model="cart", dialogue=VG + "sleep:sick"),
          prop("wv_sq_children", (13, 20), "The children, huddled under the inn's awning", model="bench", dialogue=VG + "sleep:children"),
          prop("wv_sq_old", (27, 20), "The old folk, on chairs, refusing to move", model="chairs", dialogue=VG + "sleep:old"),
          prop("wv_sq_queue", (23, 13), "The volunteers' queue and a trestle desk", model="desk", dialogue=VG + "volunteers:desk", when="flag.wv_vol_asked and not flag.vol_resolved"),
          prop("wv_sq_hill", (21, 2), "The bonfire on the hill", kind="decor", call=VG + "square:bonfire", approach=3, call_when="not flag.wv_bonfire_watched"),
          prop("wv_sq_lantern_a", (9, 12), "Lanterns on the inn's yard posts", kind="decor", model="lantern_post"),
          prop("wv_sq_lantern_b", (16, 12), "Lanterns on the inn's yard posts", kind="decor", model="lantern_post"),
          prop("wv_sq_barrels", (4, 16), "Barrels of lamp oil, rolled out", kind="decor", model="barrel"),
          prop("wv_sq_buckets", (16, 10), "Buckets of water along the wall", kind="decor", model="bucket_brush"),
          prop("wv_sq_hay", (12, 22), "Hay bales for the cattle", kind="decor", model="hay_bale"),
          prop("wv_sq_fence", (24, 24), "A fence, dragged across", kind="decor", model="fence"),
          prop("wv_sq_fallback", (21, 12), "The gap in the line, and the road to the barricade", dialogue=VG + "square:fall_back_gate", when="flag.vigil_fled and not flag.wicker_man_destroyed", kind="examine")]
    s["npcs"] = [npc("tamsin_ledger", (23, 13), "volunteers:start", when="not flag.wv_vol_asked", facing="west"),
                 npc("tamsin_ledger", (23, 13), "volunteers:progress", when="flag.wv_vol_asked and not flag.vol_resolved", facing="west"),
                 npc("tamsin_ledger", (23, 13), "volunteers:after", when="flag.vol_resolved", facing="west"),
                 npc("sgt_gaunt", (25, 11), "volunteers:gaunt", when="flag.wv_vol_asked and not flag.vol_gaunt", facing="south"),
                 npc("sgt_gaunt", (25, 11), "folk:gaunt", when="not flag.wv_vol_asked or flag.vol_gaunt", facing="south"),
                 npc("ambrose_quill", (16, 15), "folk:quill", facing="east"),
                 npc("pip_oakum", (14, 21), "folk:pip", facing="north"),
                 npc("barnaby_pennywhistle", (29, 18), "folk:barnaby", facing="west"),
                 npc("geneva_fairchild", (26, 17), "letters:start", when="not flag.wv_letters_asked", facing="east"),
                 npc("geneva_fairchild", (26, 17), "letters:progress", when="flag.wv_letters_asked and not flag.letters_done", facing="east"),
                 npc("geneva_fairchild", (26, 17), "letters:after", when="flag.letters_done", facing="east"),
                 npc("marianna_grey", (10, 17), "dinner:host", when="not flag.dinner_resolved", facing="east"),
                 npc("marianna_grey", (10, 17), "dinner:after", when="flag.dinner_resolved", facing="east"),
                 npc("morgan", (30, 13), "sleep:morgan", when="flag.wv_sleep_asked and not flag.sleep_resolved", facing="west"),
                 npc("dani_jenkin", (20, 20), "square:dani", when="flag.wv_started", facing="north")]
    s["encounters"] = [  # the retreat: the Wicker Man walks into the square at full power (filled by build_fights)
    ]
    s["lights"] = [{"cell": [11, 13], "kind": "lamp", "bright_ft": 20, "dim_ft": 40, "color": "candle"}, {"cell": [21, 2], "kind": "fire", "bright_ft": 40, "dim_ft": 80, "color": "fire"}]
    write("data/locations/wv_square.json", s)


def shelter():
    g = G(22, 20)
    g.fill(1, 1, 20, 18, ".")
    frame(g, 22, 20)
    g.fill(8, 1, 13, 2, "_")
    for y in (6, 9, 12):
        g.fill(3, y, 7, y, "=").fill(14, y, 18, y, "=")
    g.put([(11, 19)], ".")
    rows = g.rows()
    s = place("wv_shelter", "The Silent Church", rows, {"default": [11, 17], "from_square": [11, 17]},
              "The half-rebuilt Brightsinger chapel, where no hymn carries: the one roof the cult's song cannot reach.",
              "The vigil's song stops at the door as if cut with a knife. Pews have been dragged into rows for the sick, the children are asleep on the altar steps in a heap of coats, and the stone knight stands in the nave with his sneer, listening for the fire.",
              theme="church", light="dim", outdoors=False, rest="safe",
              rest_text="The song cannot reach you here. You may rest, but the fire on the hill is not resting.",
              areas=[area("church", "The Silent Church", (1, 1), (20, 18))])
    s["exits"] = [exit_("door", (11, 19), "wv_square", "from_shelter", "Out into the Round")]
    P = s["props"]
    P += [prop("wv_sh_altar", (10, 2), "The altar, half rebuilt", kind="decor", model="dais"),
          prop("wv_sh_tarps", (2, 3), "Tarps where the windows will go", kind="decor", model="rags"),
          prop("wv_sh_timber", (19, 3), "New timber, still sweet with resin", kind="decor", model="crate_stack"),
          prop("wv_sh_cots", (4, 15), "Cots in the aisle", kind="decor", model="bed_small"),
          prop("wv_sh_cots2", (16, 15), "Cots in the aisle", kind="decor", model="bed_small"),
          prop("wv_sh_coats", (10, 4), "A heap of coats and sleeping children", kind="decor", model="sack_pile"),
          prop("wv_sh_candles", (5, 3), "Candles in jam jars", kind="decor", model="candle_cluster"),
          prop("wv_sh_arrive", (11, 17), "The door shuts out the song", kind="decor", call=VG + "shelter:arrive", approach=12, call_when="not flag.wv_shelter_seen")]
    s["npcs"] = [npc("man_in_marble", (11, 8), "shelter:marble", facing="south"),
                 npc("weston_murdoch", (13, 3), "shelter:weston", facing="south", when="flag.wv_started")]
    write("data/locations/wv_shelter.json", s)


# ---- A. the moors ---------------------------------------------------------------------------------------------------------------
def moor_edge():
    w, h = 36, 22
    rng = random.Random(2301)
    g = G(w, h)
    g.fill(1, 1, w - 2, h - 2, ".")
    frame(g, w, h)
    blob(g, rng, 8, 6, 5, 3)
    blob(g, rng, 26, 15, 6, 3)
    scatter(g, rng, 14, "#", 3, 2, 32, 19, keep={(3, 18), (33, 10), (4, 18)})
    g.fill(1, 17, 5, 20, ".")
    rows = g.rows()
    s = place("wv_moor_edge", "The moor's edge", rows, {"default": [3, 18], "from_village": [3, 18], "from_heath": [33, 10]},
              "Heath and mud under a violent storm; bodies in the muck, townsfolk scattering both ways, and a bonfire on a hill that every eye keeps finding.",
              "Rain comes sideways across the heather and the sky flashes white over a bonfire on the highest hill north of the village. Townsfolk run past you in both directions. Someone lies in the mud and is not going to get up.",
              light="dark", areas=[area("edge", "The moor's edge", (1, 1), (w - 2, h - 2))])
    s["exits"] = [exit_("to_village", (2, 19), "wv_square", "from_moors", "Back to the village", when="flag.wv_started and not flag.wicker_man_burned"),
                  exit_("to_travel", (2, 18), "travel", "default", "Back down the moor road"),
                  exit_("to_heath", (34, 10), "wv_heath", "from_edge", "On across the heath")]
    P = s["props"]
    P += [prop("wv_edge_sky", (4, 17), "The sky over the moor", kind="decor", call=VG + "moor:sky", approach=12, call_when="not flag.wv_sky_seen"),
          prop("wv_edge_body_a", (12, 12), "A body in the mud", kind="decor", model="bones"),
          prop("wv_edge_body_b", (20, 5), "A body in the mud", kind="decor", model="bones"),
          prop("wv_edge_cart", (9, 15), "An overturned handcart", kind="decor", model="cart_broken"),
          prop("wv_edge_tracks", (15, 10), "Drag marks in the peat", model="claw_marks", dialogue=VG + "moor:tracks"),
          prop("wv_edge_mask", (22, 9), "A dropped antlered-hare mask", model="stag_head", dialogue=VG + "moor:mask"),
          prop("wv_edge_lantern", (7, 19), "A lantern left burning on a post", kind="decor", model="lantern_post"),
          prop("wv_edge_cairn", (28, 4), "A rain-slick cairn", kind="decor", model="cairn"),
          prop("wv_edge_dead_tree", (31, 17), "A dead tree against the lightning", kind="decor", model="dead_tree_a"),
          prop("wv_edge_leave", (33, 10), "The path onto the heath", kind="decor", call=VG + "moor:leave_edge", approach=1, call_when="not flag.wv_edge_left")]
    s["npcs"] = [npc("marianna_grey", (14, 16), "moor:eyewitness", when="not flag.wv_eyewitness_done", facing="east")]
    s["lights"] = [{"cell": [7, 19], "kind": "lamp", "bright_ft": 15, "dim_ft": 30, "color": "candle"}]
    write("data/locations/wv_moor_edge.json", s)


def heath():
    w, h = 40, 24
    rng = random.Random(2302)
    g = G(w, h)
    g.fill(1, 1, w - 2, h - 2, ".")
    frame(g, w, h)
    scatter(g, rng, 24, "#", 3, 2, 36, 21, keep={(3, 10), (4, 10), (36, 12), (35, 12)})
    for (x, y) in [(12, 8), (13, 8), (24, 15), (25, 15), (25, 16)]:
        g.c[y][x] = "="
    rows = g.rows()
    s = place("wv_heath", "The heath", rows, {"default": [3, 10], "from_edge": [3, 10], "from_quagmire": [37, 12]},
              "Open heather and stony rises in a storm, with room above for flyers; boneflayers stooping out of the smoke.",
              "Open heather, stony rises and scattered boulders under a roaring sky. The smoke of the bonfire comes down the hill in sheets, and in it, wide as a barn door, something large is turning.",
              light="dark", areas=[area("heath", "The heath", (1, 1), (w - 2, h - 2))])
    s["exits"] = [exit_("to_edge", (2, 10), "wv_moor_edge", "from_heath", "Back to the moor's edge"),
                  exit_("to_quagmire", (37, 12), "wv_quagmire", "from_heath", "On to the quagmire", when="flag.wv_h1_done or flag.wv_h1_skipped or flag.wv_h1_walked")]
    P = s["props"]
    P += [prop("wv_heath_arrive", (3, 10), "The heath, from the edge", kind="decor", call=VG + "moor:heath_start", approach=12, call_when="not flag.wv_h1_started"),
          prop("wv_heath_gong", (13, 9), "A rusted ploughman's gong on a post", model="lantern_stand", dialogue=VG + "moor:gong", when="not flag.wv_h1_done"),
          prop("wv_heath_net", (25, 13), "A drover's net and poles in the heather", model="rope_coils", dialogue=VG + "moor:net", when="not flag.wv_h1_done"),
          prop("wv_heath_after", (20, 11), "The heath, after", kind="decor", call=VG + "moor:heath_after", approach=12, call_when="flag.wv_h1_done and not flag.wv_h1_tallied"),
          prop("wv_heath_body", (30, 5), "A body in the heather", kind="decor", model="bones"),
          prop("wv_heath_feathers", (9, 14), "Black feathers the length of an arm", kind="decor", model="leaves"),
          prop("wv_heath_cairn", (33, 18), "A cairn", kind="decor", model="cairn"),
          prop("wv_heath_walk", (36, 12), "The far side of the heath", kind="decor", call=VG + "moor:heath_walk", approach=1, call_when="not flag.wv_h1_done and not flag.wv_h1_skipped and not flag.wv_h1_walked")]
    s["npcs"] = [npc("wv_fleeing_villager", (35, 8), "moor:potions", when="flag.wv_h1_tallied and flag.wv_h1_lost <= 1 and not flag.wv_potions_given", facing="west")]
    write("data/locations/wv_heath.json", s)


def quagmire():
    w, h = 40, 24
    rng = random.Random(2303)
    g = G(w, h)
    g.fill(1, 1, w - 2, h - 2, "~")
    frame(g, w, h)
    g.fill(1, 9, 5, 14, ".").fill(34, 9, 38, 14, ".")        # the dry ends
    for (cx, cy, rx, ry) in [(14, 6, 3, 2), (22, 16, 3, 2), (28, 8, 2, 2), (10, 17, 2, 2), (18, 11, 2, 1)]:
        blob(g, rng, cx, cy, rx, ry, ".", only="~")
    scatter(g, rng, 10, "#", 6, 2, 33, 21, keep={(3, 12)})
    rows = g.rows()
    s = place("wv_quagmire", "The quagmire", rows, {"default": [3, 12], "from_heath": [3, 12], "from_hardpan": [37, 12]},
              "Waterlogged bog, all Difficult Terrain, the rain stopped; six villagers stuck at the waist and something moving under the mud.",
              "The rain has stopped. The bog lies black and still, and in it stand six villagers sunk to the waist, not speaking. The surface of the mud moves in a line toward one of them.",
              light="dim", areas=[area("bog", "The quagmire", (1, 1), (w - 2, h - 2))])
    s["exits"] = [exit_("to_heath", (2, 12), "wv_heath", "from_quagmire", "Back to the heath"),
                  exit_("to_hardpan", (37, 12), "wv_hardpan", "from_quagmire", "On to firmer ground", when="flag.wv_h2_done or flag.wv_h2_skipped or flag.wv_h2_walked")]
    P = s["props"]
    P += [prop("wv_quag_arrive", (3, 12), "The quagmire, from the heath", kind="decor", call=VG + "moor:quag_start", approach=12, call_when="not flag.wv_h2_started"),
          prop("wv_quag_horn", (6, 10), "A drover's horn hanging on a post", model="lantern_bracket", dialogue=VG + "moor:horn", when="not flag.wv_h2_done"),
          prop("wv_quag_pole", (5, 14), "Long poles and a coil of rope", model="rope_coils", dialogue=VG + "moor:poles", when="not flag.wv_h2_done"),
          prop("wv_quag_after", (35, 12), "The quagmire, after", kind="decor", call=VG + "moor:quag_after", approach=10, call_when="flag.wv_h2_done and not flag.wv_h2_tallied"),
          prop("wv_quag_reeds", (30, 20), "Reeds", kind="decor", model="reeds"), prop("wv_quag_reeds2", (12, 3), "Reeds", kind="decor", model="reeds"),
          prop("wv_quag_walk", (36, 12), "The far shore of the bog", kind="decor", call=VG + "moor:quag_walk", approach=1, call_when="not flag.wv_h2_done and not flag.wv_h2_skipped and not flag.wv_h2_walked")]
    s["npcs"] = [npc("sister_lumen", (36, 10), "moor:lumen", when="flag.wv_h2_tallied and flag.wv_h2_lost <= 2 and not flag.wv_lumen_done", facing="west")]
    write("data/locations/wv_quagmire.json", s)


def hardpan():
    w, h = 40, 28
    rng = random.Random(2304)
    g = G(w, h)
    g.fill(1, 1, w - 2, h - 2, ".")
    frame(g, w, h)
    scatter(g, rng, 18, "#", 3, 6, 36, 25, keep={(3, 19), (36, 19)})
    for (x, y) in [(14, 18), (15, 18), (26, 14), (27, 14)]:
        g.c[y][x] = "="
    g.fill(17, 1, 22, 6, ".")          # the path up the hill
    rows = g.rows()
    s = place("wv_hardpan", "The hardpan", rows, {"default": [3, 19], "from_quagmire": [3, 19], "from_stones": [19, 4]},
              "Firmer ground, rusted sickles and pitchforks dropped by Foxwillow farmhands, and the path up the Rise.",
              "Firmer ground at last, packed hard as a threshing floor. Rusted sickles and pitchforks lie where their owners dropped them, and four figures are sitting very still in the middle of the field. The path to the hill runs north from here, and the revel's song comes down it.",
              light="dim", areas=[area("pan", "The hardpan", (1, 7), (w - 2, h - 2)), area("foot", "The foot of the Rise", (1, 1), (w - 2, 6))])
    s["exits"] = [exit_("to_quagmire", (2, 19), "wv_quagmire", "from_hardpan", "Back to the bog"),
                  exit_("to_stones", (19, 2), "wv_stones", "from_hardpan", "Up the path to the stones", when="flag.wv_h3_done or flag.wv_h3_skipped or flag.wv_h3_walked")]
    P = s["props"]
    P += [prop("wv_pan_arrive", (3, 19), "The hardpan, from the bog", kind="decor", call=VG + "moor:pan_start", approach=12, call_when="not flag.wv_h3_started"),
          prop("wv_pan_axes", (9, 21), "Axes and billhooks stacked against a fence", model="woodpile", dialogue=VG + "moor:axes", when="not flag.wv_h3_done"),
          prop("wv_pan_after", (20, 19), "The hardpan, after", kind="decor", call=VG + "moor:pan_after", approach=12, call_when="flag.wv_h3_done and not flag.wv_h3_tallied"),
          prop("wv_pan_sickles", (24, 22), "Rusted sickles in the dirt", kind="decor", model="stake_bundle"),
          prop("wv_pan_forks", (30, 9), "Pitchforks dropped in a line", kind="decor", model="fence"),
          prop("wv_pan_foot", (19, 6), "The foot of the Rise", kind="decor", call=VG + "moor:foot", approach=3, call_when="not flag.wv_foot_seen"),
          prop("wv_pan_song", (19, 3), "The song coming down the hill", kind="decor", model="stone_faces"),
          prop("wv_pan_lantern", (21, 5), "A hurricane lantern on the path", kind="decor", model="lantern_post"),
          prop("wv_pan_fallback", (19, 4), "The way back down", dialogue=VG + "moor:fall_back_foot", when="not flag.vigil_fled"),
          prop("wv_pan_walk", (19, 7), "The path north", kind="decor", call=VG + "moor:pan_walk", approach=1, call_when="not flag.wv_h3_done and not flag.wv_h3_skipped and not flag.wv_h3_walked")]
    write("data/locations/wv_hardpan.json", s)


# ---- B. Rowan's Rise ---------------------------------------------------------------------------------------------------------
STONES = [(18, 8), (23, 10), (26, 14), (24, 19), (18, 21), (12, 19), (10, 14), (13, 10), (18, 5)]   # nine standing stones round a ring about 12 squares across
CAPTIVE_SPOTS = [(13, 10), (23, 10), (26, 14), (24, 19), (12, 19), (10, 14)]                        # six of them have a chain melded in
CAPTIVES = ["doris_squire", "siv_harga", "marianna_grey", "beatrice_wells", "jean_myriel", "finneas_trout"]   # the order the ring takes them (open: Connection NPCs by party)
CULTISTS = ["alda_farnum", "howie_butterman", "gaston_doray", "randall_graham", "baltus_tolliver", "holly_aster"]


def stones():
    w, h = 36, 30
    rng = random.Random(2305)
    g = G(w, h)
    g.fill(1, 1, w - 2, h - 2, ".")
    frame(g, w, h)
    scatter(g, rng, 22, "#", 2, 2, 33, 27, keep=set(STONES) | {(18, 27), (18, 26)} | {(x, y) for x in range(8, 29) for y in range(3, 24)})
    g.fill(17, 14, 19, 16, "=")            # the bonfire
    for (x, y) in STONES:
        g.c[y][x] = "="
    rows = g.rows()
    s = place("wv_stones", "The stone circle", rows, {"default": [18, 27], "from_hardpan": [18, 27], "from_summit": [18, 4]},
              "Nine standing stones round a bonfire, chains melded into six of them, masked dancers capering in the firelight.",
              "Nine standing stones stand in a ring with a bonfire at the heart of it, runes burning orange along their edges. Chains run out of the rock to six figures kneeling at its foot. Round them, dozens of dancers in animal masks sway to a hymn that has no words you can hold on to, and in the middle of the song, one of them turns and waves.",
              light="dim", areas=[area("below", "The slope", (1, 22), (34, 28)), area("ring", "The stone circle", (7, 3), (29, 23), light="bright"), area("beyond", "Beyond the ring", (1, 1), (34, 3))])
    s["exits"] = [exit_("to_hardpan", (18, 28), "wv_hardpan", "from_stones", "Back down the hill"),
                  exit_("to_summit", (18, 3), "wv_summit", "from_stones", "Up to the summit", when="flag.wv_ring_down and flag.wv_cult_done")]
    P = s["props"]
    P += [prop("wv_st_arrive", (18, 26), "The hymn, loud now", kind="decor", call=VG + "stones:arrive", approach=12, call_when="not flag.wv_stones_seen"),
          prop("wv_st_skip", (18, 24), "The slope below the stones", kind="decor", call=VG + "stones:slope", approach=2, call_when="flag.wv_stones_seen and not flag.wv_ring_started and not flag.wv_ring_down")]
    for i, (x, y) in enumerate(STONES, 1):
        P += [prop(f"wv_stone_{i}", (x, y), f"Standing stone {i}, runes burning", model="standing_stones", dialogue=VG + f"stones:stone_{i}", when=f"flag.wv_ring_started and not flag.wv_stone_{i}_down and not flag.wv_ring_down"),
              prop(f"wv_stone_{i}_calm", (x, y), f"Standing stone {i}, runes burning (the dancers' song holds the fire back)", model="standing_stones", dialogue=VG + "stones:calm", when="not flag.wv_ring_started"),
              prop(f"wv_stone_{i}_dark", (x, y), f"Standing stone {i}, dark", kind="decor", model="standing_stones", tint="#3a3a40", when=f"flag.wv_stone_{i}_down or flag.wv_ring_down")]
    P += [prop("wv_st_bonfire", (18, 15), "The bonfire", kind="decor", model="brazier", scale=2.4, when="not flag.wv_ring_down"),
          prop("wv_st_bonfire_low", (18, 15), "The bonfire, burning low", kind="decor", model="brazier_cold", scale=1.6, when="flag.wv_ring_down"),
          prop("wv_st_gem", (27, 6), "A rune-marked shard of a stone", model="rocks", kind="search", search_dc=8, item="elemental_gem_yellow_diamond", when="flag.wv_ring_down and flag.wv_captives_lost <= 2"),
          prop("wv_st_welcome", (18, 20), "The dancers, turning to greet you", kind="decor", call=VG + "stones:welcome", approach=6, call_when="flag.wv_stones_seen and not flag.wv_welcome_done and not flag.wv_ring_started"),
          prop("wv_st_after", (18, 19), "The ring, fallen", kind="decor", call=VG + "stones:ring_fall_scene", approach=8, call_when="flag.wv_ring_down and not flag.wv_cult_started"),
          prop("wv_st_aftermath", (18, 12), "The circle, after", kind="decor", call=VG + "stones:aftermath", approach=8, call_when="flag.wv_cult_done and not flag.wv_aftermath_done"),
          prop("wv_st_effigy", (18, 2), "The Wicker Man, against the moon", kind="decor", call=VG + "stones:effigy", approach=8, call_when="flag.wv_aftermath_done and not flag.wv_effigy_seen"),
          prop("wv_st_fallback", (18, 22), "The way back down the hill", dialogue=VG + "stones:fall_back", when="not flag.vigil_fled and not flag.wv_aftermath_done")]
    # the dancers stand as a crowd until the ring falls
    dancers = [(16, 13), (20, 13), (15, 15), (21, 15), (16, 17), (20, 17), (14, 12), (22, 12), (14, 18), (22, 18), (18, 12), (18, 18)]
    P += [prop(f"wv_dancer_{i}", c, "A masked dancer, swaying", kind="decor", model="scarecrow_stitched", when="not flag.wv_cult_started") for i, c in enumerate(dancers)]
    # the captives, chained to six of the stones
    s["npcs"] = []
    for i, (spot, cap) in enumerate(zip(CAPTIVE_SPOTS, CAPTIVES), 1):
        s["npcs"].append(npc(cap, (spot[0], spot[1] + 1), "stones:captive", when=f"flag.wv_stones_seen and not flag.vigil_burned_{cap} and not flag.vigil_saved_{cap}", facing="north"))
        s["npcs"].append(npc(cap, (spot[0], spot[1] + 1), "stones:captive_freed", when=f"flag.vigil_saved_{cap} and not flag.wv_{cap}_thanked", facing="north"))
    s["npcs"] += [npc("holly_aster", (17, 20), "stones:holly", when="flag.wv_welcome_done and attitude.holly_aster == friendly and not flag.cultist_holly_turned and not flag.wv_ring_down and not flag.wv_holly_declined", facing="north")]
    s["lights"] = [{"cell": [18, 15], "kind": "fire", "bright_ft": 60, "dim_ft": 120, "color": "fire"}]
    s["encounters"] = [{"id": "wv_cult", "trigger": "dialogue", "flag": "wv_cult_done", "quest": {"id": "wickers_vigil", "stage": "shadow_of_the_wicker_man"},
                        "monsters": [monster("cultist", c, "A masked dancer", facing="south") for c in [(15, 13), (21, 13), (14, 16), (22, 16), (16, 18), (20, 18), (18, 11), (13, 14)]]
                        + [monster("cultist_fanatic", c, n, facing="south") for c, n in [((17, 17), "Gaston Doray, masked"), ((19, 17), "Randall Graham, masked"), ((18, 20), "Baltus Tolliver, masked")]]
                        + [monster("spy", (23, 14), "Howie Butterman, unmasked", facing="west")],
                        "loot": {"gold": 120, "items": [{"id": "potion_of_healing_greater", "qty": 1}]}}]
    write("data/locations/wv_stones.json", s)


def summit():
    w, h = 38, 34
    g = G(w, h)
    g.fill(1, 1, w - 2, h - 2, ".")
    frame(g, w, h)
    # the spiral of small stones at the crown and ten bonfires round the edge
    for (x, y) in [(18, 11), (20, 12), (21, 14), (20, 16), (18, 17), (16, 16), (15, 14), (16, 12)]:
        g.c[y][x] = "="
    fires = [(5, 5), (18, 3), (32, 5), (34, 14), (32, 24), (18, 29), (5, 24), (3, 14), (11, 8), (26, 8)]
    for (x, y) in fires:
        g.c[y][x] = "="
    rows = g.rows()
    s = place("wv_summit", "The summit of Rowan's Rise", rows, {"default": [18, 31], "from_stones": [18, 31]},
              "A spiral of small stones on scorched red earth, ten bonfires round the edge, and the Wicker Man at the heart of it.",
              "A spiral of small stones is laid on the crown of the hill, with satellite rings and stone-lined rays running out of it, and ten bonfires round the edge on scorched rust-red earth. At the spiral's centre stands a thing of woven willow bound with wire and iron, sixty feet of it, its chest and limbs hollow cages, and in the cages people are praying.",
              light="bright", rest="no", areas=[area("crown", "The crown", (1, 1), (w - 2, h - 2))])
    s["exits"] = [exit_("to_stones", (18, 32), "wv_stones", "from_summit", "Back down to the stones", when="flag.vigil_fled or flag.wicker_man_destroyed")]
    P = s["props"]
    P += [prop("wv_su_arrive", (18, 30), "The summit", kind="decor", call=VG + "summit:arrive", approach=12, call_when="not flag.wv_summit_seen"),
          prop("wv_su_effigy", (18, 8), "The Wicker Man, unlit", model="scarecrow", scale=6.0, dialogue=VG + "summit:effigy", when="not flag.wv_wicker_lit and not flag.wicker_man_destroyed"),
          prop("wv_su_cage", (18, 10), "The chest cage: Adela's small face behind the weave", kind="decor", model="cage", scale=2.0, when="not flag.wicker_man_destroyed"),
          prop("wv_su_ash", (18, 9), "A smoking heap of ash", model="soot_patch", scale=2.5, kind="decor", when="flag.wicker_man_destroyed"),
          prop("wv_su_end", (18, 12), "The ash, where the Crooked Man crawled", kind="decor", call=VG + "summit:crooked_end", approach=12, call_when="flag.wicker_man_destroyed and not flag.wv_crooked_end_seen"),
          prop("wv_su_ash_phillip", (18, 13), "Phillip, kneeling in the ash", kind="decor", call=VG + "summit:phillip_ash", approach=6, call_when="flag.wv_crooked_end_seen and not flag.wv_phillip_seen"),
          prop("wv_su_locket", (22, 10), "A silver locket in the heather: an antlered hare", model="scattered_notes", kind="search", search_dc=10, item="rowans_locket", when="flag.wv_summit_seen"),
          prop("wv_su_rowan", (18, 14), "The spiral's centre stone, carved with a woman's name", model="stone_faces", dialogue=VG + "summit:rowan"),
          prop("wv_su_fallback", (18, 26), "The way back down", dialogue=VG + "summit:fall_back", when="not flag.vigil_fled and not flag.wv_wicker_lit and not flag.wicker_man_destroyed"),
          prop("wv_su_home", (18, 28), "The path home", dialogue=VG + "summit:home", when="flag.wv_phillip_seen")]
    P += [prop(f"wv_su_fire_{i}", c, "A bonfire", kind="decor", model="brazier", scale=1.6) for i, c in enumerate([(5, 5), (18, 3), (32, 5), (34, 14), (32, 24), (18, 29), (5, 24), (3, 14), (11, 8), (26, 8)])]
    s["npcs"] = [npc("phillip_druskenvald", (18, 13), "summit:phillip_ash", when="flag.wv_crooked_end_seen and not flag.wv_phillip_seen", facing="south")]
    s["lights"] = [{"cell": [18, 8], "kind": "fire", "bright_ft": 60, "dim_ft": 120, "color": "fire"}]
    s["encounters"] = []     # filled by build_fights
    write("data/locations/wv_summit.json", s)


# ---- people -------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude, tags
    ("wv_fleeing_villager", "A fleeing villager", "A farmer, soaked through", "A farmer who ran from the heath with a sack of whatever he could carry. Grateful and out of breath.", "friendly", ["voice_hollow"]),
    ("sister_lumen", "Sister Lumen", "A wandering Brightsinger priestess", "A warm, hymn-voiced priestess who walks the moor at night singing the dying home, and the living out of it.", "friendly", ["faction_brightsingers", "voice_hollow"]),
]


def build_people():
    for (nid, name, title, summary, att, tags) in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION, **({"tags": tags} if tags else {})})
    # the goat needs a person of its own so the notice board can speak for it
    write("data/npcs/the_notice_goat.json", {"id": "the_notice_goat", "name": "The Goat", "title": "A goat on a notice board", "summary": "A village goat of fixed opinions who has taken up a position on the notice board and will not be moved by reason, rope or poetry.", "attitude": "indifferent", "sprite": "villager", "region": REGION})


# ---- quests ---------------------------------------------------------------------------------------------------------------------
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
    write("data/quests/wickers_vigil.json", {
        "id": "wickers_vigil", "name": "Wicker's Vigil", "kind": "main", "region": REGION, "giver": "tamsin_ledger",
        "summary": "The cult has raised a wicker effigy on the highest hill north of Wickermoor and needs thirteen souls to burn in it. Adela is the last piece; the night is one long road across the moor to Rowan's Rise.",
        "stages": [
            stage("follow_the_spirits", "The Crooked House is down, and every freed spirit in it is streaming north over the moor toward a bonfire on the hill.", "Go north up the moor road, out of the village.", ["Reach the moor's edge"]),
            stage("crooked_chaos", "The storm at the moor's edge has a face in it, and the face is grinning at us.", "Talk to whoever is left at the edge, then cross the heath.", ["Leave the moor's edge"]),
            stage("death_from_above", "Boneflayers have come out of the smoke over the heath, and they are taking villagers.", "Fight on the heath, or walk on.", ["Beat the boneflayers"]),
            stage("death_from_below", "In the quagmire six villagers stand sunk to the waist and the mud is moving.", "Pull the villagers out of the bog.", ["Settle the villagers", "Deal with the wellwyrms"]),
            stage("death_from_within", "On the hardpan, four of the Foxwillow folk sat down and put out shoots.", "Deal with the woodwarped.", ["End the woodwarped"]),
            stage("ring_of_fire", "The cult's stone circle: nine stones, six captives, a ring of fire waiting for a signal.", "Bring down four of the nine stones, then the cult.", ["Bring the ring down", "Deal with the cult"]),
            stage("shadow_of_the_wicker_man", "The ring is down. Above it the Wicker Man stands with Adela in its chest.", "Climb to the summit.", ["Destroy the Wicker Man"]),
            stage("fallen_back", "We fell back to Wickermoor. The effigy will come for the village at full power.", "Make your stand in the Round.", ["Destroy the Wicker Man in the village"]),
            stage("the_ash", "The Wicker Man is down, a column of sparks. In the ash something crooked crawled, and fell still.", "Look in the ash.", ["Find what the fire left"]),
            stage("ashes_to_ashes", "The Wicker Man is ash, and Adela with it. Phillip knelt in the ash and left to bury her. The Crooked Man is gone too.", ends="success"),
            stage("ash_over_the_hollow", "We did not stand. The Wicker Man walked down from Rowan's Rise and burned Wickermoor to the ground.", ends="failure"),
        ]})
    write("data/quests/vigil_volunteers.json", {
        "id": "vigil_volunteers", "name": "Volunteers", "kind": "side", "region": REGION, "giver": "tamsin_ledger",
        "summary": "Tamsin Ledger is enrolling the village militia in triplicate, and needs three signatures to make it lawful. Sergeant Gaunt has volunteered for the rear.",
        "stages": [
            stage("asked", "Tamsin Ledger set up a trestle desk in the Round to enrol the militia. It must be signed in triplicate by three named volunteers.", "Collect signatures from Sergeant Gaunt, Ambrose Quill and Barnaby Pennywhistle, then take them to Tamsin.", ["Signatures collected (0 of 3)"]),
            stage("filed", "Tamsin stamped the militia roll, three copies. The village has a lawful militia, and it is mostly Barnaby.", ends="success"),
            stage("refused", "Tamsin tore up the forms: an unsigned militia cannot lawfully hold a barricade. The barricade will be held by whoever is standing there.", ends="failure"),
        ]})
    write("data/quests/the_last_dinner.json", {
        "id": "the_last_dinner", "name": "The Last Dinner", "kind": "side", "region": REGION, "giver": "marianna_grey",
        "summary": "Marianna Grey is laying the Green Queen's last supper in the inn yard, and each guest has a last request.",
        "stages": [
            stage("asked", "Marianna is feeding the village in the inn yard while the inn's cellar lasts. Every guest at the long table has a last request.", "Fulfil three guests' last requests.", ["Requests granted (0 of 3)"]),
            stage("served", "The long table ate in peace. Everyone who asked got something, and Marianna wept into the gravy.", ends="success"),
            stage("cold", "The supper went cold. The table was empty by the time the song started.", ends="failure"),
        ]})
    write("data/quests/a_place_to_sleep.json", {
        "id": "a_place_to_sleep", "name": "A Place to Sleep", "kind": "side", "region": REGION, "giver": "morgan",
        "summary": "The sick, the children and the old folk must be moved to the Silent Church, where the cult's hymns cannot reach.",
        "stages": [
            stage("asked", "Morgan wants the sick and the children moved to the Silent Church, where the song cannot reach them, and the old folk with them if they can be talked round.", "Move the sick, the children and the old folk to the Silent Church.", ["Groups sheltered (0 of 3)"]),
            stage("sheltered", "The sick, the children and the old folk sleep under one roof, and the Man in Marble watches the door.", ends="success"),
            stage("scattered", "Not everyone made it into the church before the song started. The ones who stayed outside will meet the Wicker Man in the Round.", ends="failure"),
        ]})
    write("data/quests/letters_home.json", {
        "id": "letters_home", "name": "Letters Home", "kind": "side", "region": REGION, "giver": "geneva_fairchild",
        "summary": "Geneva Fairchild has a bag of the villagers' last letters and no one to carry them. One of them is Walder Pye's.",
        "stages": [
            stage("asked", "Geneva's post cart is full of last letters, and the post will not run tomorrow. She asked us to put them into the right hands tonight.", "Deliver Geneva's letters to their readers in the Round.", ["Letters delivered (0 of 3)"]),
            stage("delivered", "Every letter reached its reader before midnight. Geneva sat down on the cart and cried with relief.", ends="success"),
            stage("unsent", "The letters went unread. They pile up on the notice board, and the wind turns them over.", ends="failure"),
        ]})
    write("data/quests/the_goats_stand.json", {
        "id": "the_goats_stand", "name": "The Goat's Stand", "kind": "side", "region": REGION, "giver": "tamsin_ledger",
        "summary": "The village goat has taken a position on the notice board and refuses to leave it, and a notice has gone up that says the board is the evacuation point.",
        "stages": [
            stage("asked", "The goat is on the notice board, and the board is the evacuation point.", "Get the goat off the board, or the board away from the goat."),
            stage("moved", "The goat is off the board. It has not forgiven anyone.", ends="success"),
            stage("stands", "We left the goat on the board. It will meet whatever comes with the same expression.", ends="failure"),
        ]})


# ---- items ------------------------------------------------------------------------------------------------------------------------
ITEMS = [
    ("rowans_locket", "Rowan's locket", "quest", "A tarnished silver locket with a picture of an antlered hare, found in the heather on Rowan's Rise. The legend says she climbed to sit on the moon."),
    ("wv_barnaby_repellent", "Barnaby's Wicker Man Repellent", "quest", "A stoppered bottle of something brown. The label says it repels wicker, men, and Wicker Men, and Barnaby has underlined the third one."),
    ("wv_pip_button", "Pip's courage button", "quest", "A brass button the size of a thumbnail that Pip swears was worn by a hero in the last war. It is, in fact, warm."),
    ("wv_last_letters", "Geneva's last letters", "quest", "A satchel of sealed letters in a dozen hands, each addressed to someone within a hundred yards."),
    ("wv_signed_roll", "The militia roll", "quest", "Tamsin Ledger's militia roll, in triplicate, with a gap for a signature."),
    ("wv_feast_bread", "A heel of the last loaf", "quest", "The end of the last loaf from the inn's ovens, still warm."),
    ("wv_horn", "A drover's horn", "quest", "A long horn on a cord, blown to call cattle across a bog. Wellwyrms do not care for it."),
    ("wv_gong_striker", "A gong striker", "quest", "A padded mallet from a ploughman's gong. Boneflayers do not care for the noise."),
]


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary})


# ---- monsters ---------------------------------------------------------------------------------------------------------------------
def build_monsters():
    w = read("data/monsters/wicker_man.json")
    w.update({"id": "wicker_man_vigil", "name": "The Wicker Man, possessed"})
    w["summary"] = ("The effigy of Rowan's Rise with the Crooked Man in its head, as the vigil meets it: heavy burning slams that push, a roaring cone, an aura, and motes of stolen souls "
                    "(its mote count is the vigil's tally of the dead, here as extra Hit Points it mends) that fall to a damage threshold while the Old Ways Chosen live.")
    w["source"] = dict(w["source"], note=w["source"]["note"] + " The vigil variant (R23): phases Dying Embers and Furnace, the Old Ways Influence lair turn, the push the text promises.")
    for a in w["actions"]:
        if a["id"] == "blazing_slam":
            a["on_hit"] = [{"do": "push", "feet": 10, "max_size": "large"}]
            a["summary"] += " A Large or smaller target is pushed up to 10 ft, toward a bonfire if there is one."
    w["traits"].append({"id": "blazing_ardor", "name": "Blazing Ardor", "action": "passive",
                        "summary": "While Old Ways Chosen live it ignores damage below 10 times their number (30 at the start). Kill the Chosen first.",
                        "text": "The Wicker Man ignores any damage from a single source below a threshold of 10 times the number of Old Ways Chosen alive (30 to begin with).",
                        "implemented": "text"})
    w["lair_actions"] = [
        {"id": "hymn_hearten", "name": "The Chosen Sing", "kind": "text", "summary": "Surviving Old Ways Chosen gain 10 temporary Hit Points.", "text": "A hymn rises from the masks and the surviving Chosen are filled with fire."},
        {"id": "hymn_falter", "name": "A Hymn Out of Tune", "kind": "save", "save": {"ability": "wis", "dc": 15, "success": "none"}, "targets": {"range": 120, "count": 4},
         "on_fail": [{"do": "condition", "condition": "frightened"}], "summary": "Up to four heroes: a DC 15 Wisdom save or their aim wavers in the song (modelled as Frightened until the lair's next turn).",
         "text": "The hymn runs a bar out of step and four heads swim: a DC 15 Wisdom save or they falter."},
        {"id": "hymn_burn", "name": "Embers in the Wind", "kind": "save", "save": {"ability": "dex", "dc": 15, "success": "none"}, "targets": {"range": 120, "count": 3},
         "damage": [{"average": 5, "dice": "1d10", "type": "fire"}], "summary": "Up to three heroes: a DC 15 Dex save or 1d10 Fire from the embers on the wind.",
         "text": "Sparks lift off the nearest bonfire and find the nearest living flesh."}]
    w["phases"] = [
        {"id": "dying_embers", "name": "Dying Embers", "when": {"gone": {"monster": "old_ways_chosen", "at_least": 3}, "flag": "wv_chosen_fallen"}, "traits_remove": ["blazing_ardor"],
         "legendary_refill": True, "lair": True, "flag": "wv_embers", "say": "wv_wicker_embers",
         "summary": "The last Chosen falls and its soul pours into the effigy. The threshold is gone, and the Wicker Man lurches to the front, burning hotter."},
        {"id": "furnace", "name": "The Furnace", "when": {"bloodied": True}, "legendary_resistance": "refill", "lair": True, "flag": "wv_furnace", "say": "wv_wicker_furnace",
         "summary": "Bloodied, the weave splits and the fire inside goes white: its Legendary Resistance returns and the lair turns on every hymn."}]
    write("data/monsters/wicker_man_vigil.json", w)


# ---- the fights (level-scaled, with the tally's tier on the boss) ---------------------------------------------------------------
BANDS = [("level <= 11", 0.85, "low"), ("level == 12", 1.0, "mid"), ("level >= 13", 1.12, "high")]
TIERS = [(0, 0, 0), (1, 3, 1), (4, 6, 2), (7, 9, 3), (10, 12, 4), (13, 99, 5)]     # deaths from, to, soul motes


def hp(base, f):
    return int(round(base * f))


def cond(*parts):
    return " and ".join(p for p in parts if p)


def sq(x, y, i=0):
    return [x, y]


def build_fights():
    # -- A1 the heath: boneflayers carry villagers off
    h = read("data/locations/wv_heath.json")
    villagers = [monster("commoner", c, "A fleeing villager", side="neutral", catch={"flag": f"wv_h1_saved_{i}"}, facing="north") for i, c in enumerate([(14, 10), (18, 14), (22, 8), (26, 12), (16, 17)], 1)]
    gong = {"id": "wv_gong", "name": "The gong rings", "summary": "The gong on the post is struck: the boneflayers' hearing goes and their blows go wild.", "kind": "save", "affects": "enemies",
            "save": {"ability": "con", "dc": 14}, "condition": "frightened", "until": "target_turn_end", "area": {"around": [19, 12], "radius": 40}, "at": 20, "every": 2,
            "say": "The gong booms, and the boneflayers flinch from the noise."}
    flyers = lambda n, f: [monster("boneflayer", c, "A boneflayer", facing="south", hp=hp(94, f), boss=False) for c in [(12, 4), (20, 3), (28, 5), (33, 9), (8, 14), (26, 18)][:n]]
    h["encounters"] = []
    for (lv, f, tag) in BANDS:
        n = 5 if tag == "low" else 6
        for gongd in (True, False):
            e = {"id": "wv_boneflayers", "trigger": "dialogue", "when": cond(lv, "flag.wv_gong_ready" if gongd else "not flag.wv_gong_ready"), "flag": "wv_h1_done",
                 "quest": {"id": "wickers_vigil", "stage": "death_from_below"}, "monsters": flyers(n, f) + copy.deepcopy(villagers)}
            if gongd:
                e["round_events"] = [copy.deepcopy(gong)]
            h["encounters"].append(e)
    write("data/locations/wv_heath.json", h)
    # -- A2 the quagmire: wellwyrms and six mired villagers
    q = read("data/locations/wv_quagmire.json")
    mired = [monster("commoner", c, "A mired villager", side="neutral", catch={"flag": f"wv_h2_saved_{i}"}, facing="north") for i, c in enumerate([(10, 8), (14, 14), (18, 7), (22, 18), (26, 11), (30, 15)], 1)]
    horn = {"id": "wv_horn", "name": "The horn sounds", "summary": "The drover's horn is blown across the bog: the wellwyrms recoil from the sound.", "kind": "save", "affects": "enemies",
            "save": {"ability": "wis", "dc": 15}, "condition": "frightened", "until": "target_turn_end", "area": {"around": [20, 12], "radius": 40}, "at": 20, "every": 2,
            "say": "The horn rolls over the bog, and the mud shudders."}
    q["encounters"] = []
    for (lv, f, tag) in BANDS:
        n = 2 if tag == "low" else 3
        for hornd in (True, False):
            e = {"id": "wv_wellwyrms", "trigger": "dialogue", "when": cond(lv, "flag.wv_horn_ready" if hornd else "not flag.wv_horn_ready"), "flag": "wv_h2_done",
                 "quest": {"id": "wickers_vigil", "stage": "death_from_within"},
                 "monsters": [monster("wellwyrm", c, "A wellwyrm", facing="west", hp=hp(153, f), boss=False) for c in [(12, 12), (20, 10), (28, 13)][:n]] + copy.deepcopy(mired)}
            if hornd:
                e["round_events"] = [copy.deepcopy(horn)]
            q["encounters"].append(e)
    write("data/locations/wv_quagmire.json", q)
    # -- A3 the hardpan: four sprout into woodwarped; the villagers' bodies are ruined by fire and crushing blows
    p = read("data/locations/wv_hardpan.json")
    body = {"ruined_by": ["fire", "bludgeoning", "necrotic"], "count": "vigil_deaths", "warn": "A Foxwillow villager is inside. Fire or crushing blows would kill them for good; cuts and radiance would not."}
    ripped = {"id": "wv_torn_out", "name": "Torn out of the heroes", "summary": "Roots tear out of each hero's chest: a DC 17 Con save or 2d10 Necrotic.", "kind": "save", "affects": "party",
              "save": {"ability": "con", "dc": 17}, "damage": {"dice": "2d10", "type": "necrotic"}, "area": {"around": [20, 18], "radius": 40}, "at": 20, "from_round": 1, "times": 1,
              "say": "Something green and cold wrenches out of every hero's chest."}
    born = lambda f: {"id": "wv_hero_born", "name": "Hero-born woodwarped", "summary": "Two woodwarped tear out of the heroes' own backs.", "kind": "summon", "affects": "enemies", "monster": "woodwarped", "count": 2, "side": "enemies",
                      "cells": [[14, 21], [26, 21]], "at": 20, "from_round": 1, "every": 1, "times": 1, "say": "The torn-out roots stand up on their own."}
    p["encounters"] = []
    for (lv, f, tag) in BANDS:
        e = {"id": "wv_woodwarped", "trigger": "dialogue", "when": lv, "flag": "wv_h3_done", "quest": {"id": "wickers_vigil", "stage": "ring_of_fire"},
             "monsters": [monster("woodwarped", c, "A woodwarped farmhand", facing="south", hp=hp(82, f), body=copy.deepcopy(body), boss=False) for c in [(14, 14), (18, 12), (22, 14), (26, 12)]],
             "round_events": [copy.deepcopy(ripped), born(f)]}
        p["encounters"].append(e)
    write("data/locations/wv_hardpan.json", p)
    # -- B1 the cult: trimmed to the dancers who fight (the crowd flees once the ring is down)
    st = read("data/locations/wv_stones.json")
    base = st["encounters"][0]
    dancers = [m for m in base["monsters"] if m["monster"] == "cultist"]
    named = [m for m in base["monsters"] if m["monster"] != "cultist"]
    for m in named:
        if m["name"] in ("Gaston Doray, masked", "Randall Graham, masked"):
            m["name"] = "A masked fanatic"
    st["encounters"] = []
    for (lv, f, tag) in BANDS:
        e = copy.deepcopy(base)
        e["when"] = lv
        n = {"low": 5, "mid": 8, "high": 11}[tag]
        e["monsters"] = copy.deepcopy((dancers + [monster("cultist", c, "A masked dancer", facing="south") for c in [(12, 12), (24, 12), (12, 18)]])[:n]) + copy.deepcopy(named)
        st["encounters"].append(e)
    write("data/locations/wv_stones.json", st)
    # -- B2 the summit: the Wicker Man and the three Chosen, tiered by the tally of the dead
    su = read("data/locations/wv_summit.json")
    chosen = [monster("old_ways_chosen", c, n, facing="south", boss=False) for c, n in [((13, 14), "Alda Farnum, the Hare"), ((23, 14), "Gaston Doray, the Crow"), ((18, 19), "Randall Graham, the Stag")]]
    su["encounters"] = []
    for (lv, f, tag) in BANDS:
        for (lo, hi, motes) in TIERS:
            when = cond(lv, "flag.vigil_deaths >= %d" % lo if lo else "", "flag.vigil_deaths <= %d" % hi if hi < 99 else "", "not flag.vigil_fled")
            ch = copy.deepcopy(chosen)
            for c in ch:
                c["hp"] = hp(88, f)
            e = {"id": "wv_wicker_man", "trigger": "dialogue", "when": when, "flag": "wicker_man_destroyed", "lair": True, "quest": {"id": "wickers_vigil", "stage": "the_ash"},
                 "monsters": [monster("wicker_man_vigil", (18, 9), "The Wicker Man", boss=True, facing="south", hp=hp(155 + 20 * motes, f))] + ch,
                 "objects": [{"id": f"wv_bonfire_{i}", "kind": "brazier" if False else "vessel", "cell": list(c), "name": "A bonfire", "fuel": "fire", "ac": 5, "hp": 999, "size": "medium", "immune": ["fire"]} for i, c in enumerate([(11, 8), (26, 8)])]}
            e.pop("objects")           # bonfires are scenery props; pushing into them is the tactic (open: object hazards)
            su["encounters"].append(e)
    write("data/locations/wv_summit.json", su)
    # -- the retreat: the village square, five motes, no Chosen
    sq_ = read("data/locations/wv_square.json")
    sq_["encounters"] = []
    for (lv, f, tag) in BANDS:
        sq_["encounters"].append({"id": "wv_wicker_square", "trigger": "dialogue", "when": lv, "flag": "wicker_man_destroyed", "lair": True, "quest": {"id": "wickers_vigil", "stage": "the_ash"},
                                  "monsters": [monster("wicker_man_vigil", (21, 12), "The Wicker Man", boss=True, facing="south", hp=hp(155 + 100, f))]})
    write("data/locations/wv_square.json", sq_)


# ---- hooks, travel and cutscenes --------------------------------------------------------------------------------------------------
def build_hooks():
    path = ROOT / "data/locations/nm_estate_ruins.json"
    r = json.loads(path.read_text())
    r["npcs"] = [n for n in r["npcs"] if not str(n.get("dialogue", "")).startswith(VG)]
    r["npcs"][0:0] = [
        {"npc": "dani_jenkin", "cell": [20, 15], "dialogue": VG + "hook:dani_ruins", "when": "flag.crooked_man_slain and not flag.wv_hook_given", "approach": 12},
        {"npc": "dani_jenkin", "cell": [20, 15], "dialogue": VG + "hook:dani_again", "when": "flag.wv_hook_given and not flag.wicker_man_burned"}]
    path.write_text(json.dumps(r, indent=2, ensure_ascii=False) + "\n")
    vp = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(vp.read_text())
    town["npcs"] = [n for n in town["npcs"] if not str(n.get("dialogue", "")).startswith(VG)]
    i = next(k for k, n in enumerate(town["npcs"]) if n["npc"] == "tamsin_ledger")
    town["npcs"][i:i] = [
        {"npc": "tamsin_ledger", "cell": [23, 21], "dialogue": VG + "hook:tamsin_start", "when": "flag.crooked_man_slain and not flag.wv_started and not flag.wicker_man_burned", "approach": 8},
        {"npc": "tamsin_ledger", "cell": [23, 21], "dialogue": VG + "hook:tamsin_again", "when": "flag.wv_started and not flag.wicker_man_burned"}]
    vp.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if not x["id"].startswith("wv_")] + [
        {"id": "wv_square", "name": "Wickermoor, barricaded", "location": "wv_square", "spawn": "from_travel", "pos": [0.5, 0.47], "region": REGION,
         "when": "flag.wv_started and not flag.wicker_man_burned", "summary": "The Founder's Round on the night before the burning: barricades, a long table, the Silent Church open."},
        {"id": "wv_moor_edge", "name": "The moor's edge", "location": "wv_moor_edge", "spawn": "default", "pos": [0.5, 0.33], "region": REGION,
         "when": "flag.crooked_man_slain and not flag.wicker_man_burned", "summary": "Where the moor road ends and the storm begins, with a bonfire on the hill above."}]
    t["roads"] = [x for x in t["roads"] if not x["id"].startswith("wv_")] + [
        {"id": "wv_village_to_square", "from": "wickermoor_village", "to": "wv_square", "hours": 1, "name": "Through the barricade", "when": "flag.wv_started and not flag.wicker_man_burned"},
        {"id": "wv_square_to_edge", "from": "wv_square", "to": "wv_moor_edge", "hours": 1, "name": "Up the moor road", "when": "flag.wv_started and not flag.wicker_man_burned"},
        {"id": "wv_village_to_edge", "from": "wickermoor_village", "to": "wv_moor_edge", "hours": 1, "name": "The moor road", "when": "flag.crooked_man_slain and not flag.wicker_man_burned"},
        {"id": "wv_ruins_to_edge", "from": "nm_estate_ruins", "to": "wv_moor_edge", "hours": 1, "name": "The spirits' road, north over the moor", "when": "flag.crooked_man_slain and not flag.wicker_man_burned"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


SETS = {
    "wv_grinning_storm": ["The moor in driving rain, townsfolk running, a bonfire on a far hill and a ring of freed spirits streaming toward it",
                          "The storm clouds coiling into a grinning face with hollow eyes and lightning in its mouth"],
    "wv_effigy_revealed": ["A colossal wicker man standing against a huge cold moon, its shadow stretched across the moor, bonfires round its feet",
                           "Close on the chest cage of the wicker man: a woman's small calm face behind the weave among villagers, goats, sheep and sheaves"],
    "wv_final_sacrifice": ["Flames climbing the wicker effigy while masked dancers caper in the firelight",
                           "A woman's eye behind the weave and a single tear, flames rising beyond it",
                           "The titan wicker man lurching one step forward, its eyes catching fire"],
    "wv_crooked_mans_end": ["The wicker man collapsing into a column of sparks over the hill",
                            "A shrivelled, charred, crooked specter clawing out of a heap of ash and falling still",
                            "Rain falling on a smoking ash heap under a hill of dying fires"],
    "wv_phillip_in_ash": ["A lord in a torn smouldering coat running up a dark hill in the rain",
                          "The same man kneeling in grey ash, lifting a blackened necklace from charred bones"],
}


def build_cutscenes():
    pics = {}
    for first, prompts in SETS.items():
        for n, desc in enumerate(prompts, 1):
            pics[first if n == 1 else f"{first}_{n}"] = desc
    write("tools/content/vigil_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": pics})
    for cid, desc in pics.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("wv_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


if __name__ == "__main__":
    square(); shelter(); moor_edge(); heath(); quagmire(); hardpan(); stones(); summit()
    build_people(); build_quests(); build_items(); build_monsters()
    build_fights()
    build_hooks(); build_travel(); build_cutscenes()
    print("ok")
