#!/usr/bin/env python3
"""ONE-SHOT (R24, The Crooked Tree). Writes the Wytchwood and its hovel, the clearing of the Crooked Tree, Kehlenn's barrow and the inn's master
suite (`ct_*`), their people, the quests (the main one, its five scene-quests and the side quests), flags, items, the Born King's stat block, the
Horned King's dark gifts, the travel place and the hooks in Wickermoor (Doris, Jean and Siv, the confessing villagers). The conversations are
narrative/crooked_tree/*.dialogue (drafted by Gemini, edited by hand). Other lanes edit these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_crooked_tree.py"""
import copy
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import crooked_tree_maps as M  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CT = "crooked_tree/"
R_WOOD, R_TREE = "the_wytchwood", "crooked_tree"


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


def talk(pid, cell, label, ref, model=None, when=None, **kw):
    """A prop that opens a conversation when clicked."""
    d = prop(pid, cell, label, model=model, dialogue=CT + ref, **kw)
    if when:
        d["when"] = when
    return d


def auto(pid, cell, label, ref, call_when, radius=12, model=None, **kw):
    """A decor square that starts a conversation by itself as the party comes near."""
    return prop(pid, cell, label, kind="decor", model=model, call=CT + ref, approach=radius, call_when=call_when, **kw)


def npc(nid, cell, dialogue=None, **kw):
    d = {"npc": nid, "cell": list(cell)}
    if dialogue:
        d["dialogue"] = CT + dialogue
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


def place(lid, name, rows, spawn, summary, text, region, theme, light, outdoors, areas=None, rest="no", rest_text=None):
    w, h = len(rows[0]), len(rows)
    return {"id": lid, "name": name, "region": region, "summary": summary, "text": text,
            "map": {"rows": rows, "theme": theme, "light": light, "outdoors": outdoors},
            "areas": areas or [area("all", name, (1, 1), (w - 2, h - 2))],
            "spawns": {"default": list(spawn)}, "exits": [], "props": [], "npcs": [], "encounters": [],
            "rest": rest, "rest_text": rest_text or "Not here."}


# ---- the Wytchwood ---------------------------------------------------------------------------------------------------------------------
def wytchwood():
    rows = M.wytchwood()
    g = M.GLADES
    s = place("ct_wytchwood", "The Wytchwood", rows, (22, 106),
              "A dense old forest of blue-black pines leaning at wrong angles, one trail winding north through seven glades, a black creek across it.",
              "The trees lean the wrong way and the moon comes down through them in thin silver shafts. The needles under you are soft and silent, and the "
              "sound of your own voice dies a few strides away. Hundreds of small things click in the branches. Somewhere ahead, something is breathing.",
              R_WOOD, "forest", "dim", True,
              areas=[area("w1_edge", "The edge of the wood", (15, 99), (29, 110)),
                     area("w2_creek", "The black creek", (3, 84), (40, 100)),
                     area("w3_thicket", "The beast's thicket", (14, 62), (34, 82)),
                     area("w4_hovel", "The hovel glade", (11, 46), (29, 66)),
                     area("w5_grove", "The maidenwood grove", (10, 28), (34, 52)),
                     area("w6_goat", "The goat's path", (14, 16), (30, 32)),
                     area("w7_heart", "The treeline of the heart", (16, 2), (28, 16)),
                     area("side_a", "A side glade", (2, 62), (10, 70)),
                     area("side_b", "A side glade", (34, 46), (42, 54)),
                     area("side_c", "A side glade", (2, 26), (10, 34))],
              rest="risky",
              rest_text="You can sleep, if you like. The wood will give your sleep back to you as three dice of psychic hurt, and lay your belongings out in strange patterns.")
    s["map"]["ceiling_ft"] = 60
    P = s["props"]
    P += [auto("ct_w_enter", (22, 106), "The edge of the wood", "wood:edge_start", "not flag.ct_wood_entered"),
          # ---- the trail legs and the clues ----
          talk("ct_track_1", (22, 102), "The trail, under the pines", "wood:track_1", model="signpost_broken", when="flag.ct_wood_entered and not flag.ct_leg_1_done"),
          talk("ct_clue_1", (19, 96), "Something small and bright in the needles", "wood:clue_1", model="relics", when="not flag.ct_clue_1"),
          talk("ct_creek_log", (14, 91), "A fallen log across the black water", "wood:creek", model="fallen_beam"),
          talk("ct_creek_stones", (22, 91), "A line of wet stones", "wood:creek", model="rocks"),
          talk("ct_creek_ford", (31, 91), "A wading ford", "wood:creek", model="reeds"),
          auto("ct_hare_spot", (22, 83), "A black hare with antlers, unblinking", "beasts:hare_start", "flag.ct_creek_crossed and not flag.ct_hare_done", radius=6, model="crow"),
          talk("ct_track_2", (22, 80), "The trail, on the north bank", "wood:track_2", model="signpost_broken", when="flag.ct_creek_crossed and not flag.ct_leg_2_done"),
          talk("ct_clue_2", (28, 84), "A cracked hooded lantern in the roots", "wood:clue_2", model="lantern_stand", when="flag.ct_creek_crossed and not flag.ct_clue_2"),
          talk("ct_goat_mark_1", (22, 78), "A bit of shaggy black hair on a branch", "goat:visit_1", model="relics", when="flag.ct_creek_crossed and not flag.ct_goat1_done"),
          auto("ct_beast_spot", (23, 73), "The underbrush, moving", "beasts:illusion_start", "flag.ct_hare_done and not flag.ct_illusion_met", radius=7, model="vines"),
          talk("ct_track_3", (22, 66), "The trail, past the thicket", "wood:track_3", model="signpost_broken", when="flag.ct_beast_done and not flag.ct_leg_3_done"),
          talk("ct_clue_3", (27, 69), "A silver hip flask in the moss", "wood:clue_3", model="satchel", when="flag.ct_beast_done and not flag.ct_clue_3"),
          talk("ct_hovel_door", (20, 56), "A slanted hovel hung with idols of sticks and bone", "hovel:door", model="cottage", when="not flag.ct_hovel_done"),
          talk("ct_idols", (15, 58), "Idols of sticks and bone, clicking", "hovel:idols", model="stake_bundle"),
          talk("ct_idols_b", (25, 59), "More idols, hung low", "hovel:idols", model="stake_bundle"),
          talk("ct_clue_4", (24, 62), "A torn scrap of pinstriped cloth on a thorn", "wood:clue_4", model="rags", when="flag.ct_hovel_done and not flag.ct_clue_4"),
          talk("ct_track_4", (20, 49), "The trail, north of the hovel", "wood:track_4", model="signpost_broken", when="flag.ct_hovel_done and not flag.ct_leg_4_done"),
          talk("ct_goat_mark_2", (24, 52), "A black hoofprint in the needles", "goat:visit_2", model="claw_marks", when="flag.ct_hovel_done and not flag.ct_goat2_done"),
          auto("ct_grove_in", (22, 46), "The ring of trees", "grove:grove_start", "flag.ct_goat2_done and not flag.ct_grove_started", radius=6, model="tree_marked"),
          talk("ct_grove_centre", (22, 40), "The middle of the ring", "grove:centre", model="offering_circle", when="flag.ct_grove_started and not flag.ct_grove_done"),
          auto("ct_goat_spot", (22, 26), "The clouds have eaten the moon", "goat:offer_start", "flag.ct_grove_done and not flag.ct_offer_made", radius=6, model="stag_head"),
          talk("ct_clue_5", (21, 22), "A goat-headed cane, laid across the path", "wood:clue_5", model="sword_leaning", when="flag.ct_offer_made and not flag.ct_clue_5"),
          auto("ct_heart_gate", (22, 6), "Where the trees part on the heart of the wood", "wood:heart_start", "flag.ct_offer_made and not flag.ct_heart_reached", radius=6, model="gate"),
          # ---- ordinary trees, stones and bones, so the glades read as a wood ----
          ]
    deco = [("dead_tree_a", "A blue-black pine, leaning"), ("pine_b", "A pine, leaning the wrong way"), ("dead_tree_b", "A bent trunk"), ("pine_c", "A pine, hung with moss")]
    spots = [(18, 104), (27, 103), (16, 98), (28, 96), (17, 86), (28, 86), (19, 71), (28, 75), (21, 59), (16, 63), (27, 56), (15, 41), (30, 38),
             (18, 34), (25, 44), (20, 26), (27, 18), (17, 12), (26, 10), (8, 66), (38, 50), (7, 30)]
    for i, c in enumerate(spots):
        mdl, lab = deco[i % len(deco)]
        P.append(prop(f"ct_w_tree_{i}", c, lab, kind="decor", model=mdl))
    for i, c in enumerate([(24, 100), (20, 76), (26, 64), (18, 36), (24, 14), (31, 104), (13, 90)]):
        P.append(prop(f"ct_w_bones_{i}", c, "A scatter of small bones", kind="decor", model="bone_scatter"))
    for i, c in enumerate([(21, 108), (25, 82), (19, 52), (28, 28), (22, 18), (23, 8)]):
        P.append(prop(f"ct_w_leaves_{i}", c, "Needles and old leaves", kind="decor", model="leaves"))
    for i, c in enumerate([(30, 88), (16, 94), (19, 94), (26, 96)]):
        P.append(prop(f"ct_w_reeds_{i}", c, "Reeds at the black water's edge", kind="decor", model="reeds"))
    # the idols are hung in the hovel glade, clicking
    for i, c in enumerate([(13, 55), (14, 60), (26, 55), (27, 61), (17, 65), (23, 65)]):
        P.append(prop(f"ct_w_idol_{i}", c, "A hanging idol of sticks and bone", kind="decor", model="stake_bundle"))
    # the grove: the false Rowans at the ring's trees
    for i, c in enumerate([(14, 40), (30, 40), (17, 34), (27, 34), (17, 46), (27, 46)]):
        P.append(prop(f"ct_w_ringtree_{i}", c, "A tree with a white face in its bark", kind="decor", model="tree_marked"))
    # the heart: the way on
    P.append(prop("ct_w_heart_standing", (22, 8), "The trees leaning in to listen", kind="decor", model="standing_stones"))
    s["npcs"] = [npc("ct_false_rowan", (14, 41), "grove:rowan", when="flag.ct_grove_started and not flag.ct_grove_done", facing="east"),
                 npc("ct_false_rowan", (30, 41), "grove:rowan", when="flag.ct_grove_started and not flag.ct_grove_done", facing="west"),
                 npc("ct_false_rowan", (18, 35), "grove:rowan", when="flag.ct_grove_started and not flag.ct_grove_done", facing="south"),
                 npc("ct_false_rowan", (27, 35), "grove:rowan", when="flag.ct_grove_started and not flag.ct_grove_done", facing="south"),
                 npc("ct_false_rowan", (18, 46), "grove:rowan", when="flag.ct_grove_started and not flag.ct_grove_done", facing="north"),
                 npc("ct_false_rowan", (26, 46), "grove:rowan", when="flag.ct_grove_started and not flag.ct_grove_done", facing="north"),
                 npc("ct_illusion", (23, 74), "beasts:illusion", when="flag.ct_illusion_met and not flag.ct_beast_done", facing="south"),
                 npc("ct_hk_goat", (22, 22), "goat:offer", when="flag.ct_offer_started and not flag.ct_offer_made", facing="south")]
    s["exits"] = [exit_("to_moors", (22, 109), "travel", "default", "Back to the moors"),
                  exit_("to_heart", (22, 2), "ct_crooked_tree", "default", "North, to the heart of the wood", when="flag.ct_offer_made")]
    s["encounters"] = [
        {"id": "ct_hare", "trigger": "dialogue", "flag": "ct_hare_done", "monsters": [monster("crooked_hare", (22, 82), "The crooked hare", facing="south")]},
        {"id": "ct_beast", "trigger": "dialogue", "flag": "ct_beast_done", "when": "flag.ct_beast_seen_through", "surprise": "",
         "quest": {"id": "the_crooked_tree", "stage": "tracking_phillip"},
         "monsters": [monster("hypnovulfen", (24, 69), "The hypnovulfen", boss=True, facing="south")]},
        {"id": "ct_beast", "trigger": "dialogue", "flag": "ct_beast_done", "when": "not flag.ct_beast_seen_through", "surprise": "enemies",
         "quest": {"id": "the_crooked_tree", "stage": "tracking_phillip"},
         "monsters": [monster("hypnovulfen", (24, 69), "The hypnovulfen", boss=True, facing="south")]},
        {"id": "ct_maidenwood", "trigger": "dialogue", "flag": "ct_maidenwood_done", "monsters": [monster("maidenwood", (22, 34), "The maidenwood", facing="south")]},
        # the Hungry Woods, one per leg, none repeated (the book draws a d6 without repeats, at most one per leg)
        {"id": "ct_hw_1", "trigger": "dialogue", "flag": "ct_hw_1_done", "monsters": [monster("ketgrinn", (20, 99), "A ketgrinn", facing="south"), monster("ketgrinn", (24, 99), "A ketgrinn", facing="south")]},
        {"id": "ct_hw_2", "trigger": "dialogue", "flag": "ct_hw_2_done", "monsters": [monster("gobblegeist", (22, 76), "A gobblegeist", facing="south")]},
        {"id": "ct_hw_3", "trigger": "dialogue", "flag": "ct_hw_3_done", "monsters": [monster("wellwyrm", (22, 61), "A wellwyrm", facing="south")]},
        {"id": "ct_hw_4", "trigger": "dialogue", "flag": "ct_hw_4_done", "monsters": [monster("dream_eater", (22, 44), "A dream eater", facing="south")]},
        {"id": "ct_hw_swept", "trigger": "dialogue", "flag": "ct_hw_swept_done", "monsters": [monster("boneflayer", (18, 95), "A boneflayer", facing="north"),
                                                                                                monster("boneflayer", (22, 95), "A boneflayer", facing="north"),
                                                                                                monster("boneflayer", (26, 95), "A boneflayer", facing="north")]},
        # an early visitor's chase scene: the hypnovulfen's eyes, not a CR 15 fight at low level
    ]
    s["lights"] = [{"cell": [22, 106], "kind": "lamp", "bright_ft": 0, "dim_ft": 30, "color": "moon"}]
    # a prop or a person never stands in a trunk: clear its square (and lay a way to it) wherever the scattering put one
    grid = [list(r) for r in s["map"]["rows"]]
    for c in [p["cell"] for p in P if p.get("kind") != "decor" or p["id"].startswith(("ct_w_enter", "ct_hare", "ct_beast", "ct_grove", "ct_goat", "ct_heart"))] + [n["cell"] for n in s["npcs"]]:
        if grid[c[1]][c[0]] == "#":
            grid[c[1]][c[0]] = "."
    s["map"]["rows"] = ["".join(r) for r in grid]
    write("data/locations/ct_wytchwood.json", s)


def hovel():
    rows = M.hovel()
    s = place("ct_hovel", "The Wytchwood hovel", rows, (4, 9),
              "A twenty-foot hovel of rotting boards with a bed, a bent table, a broken chair and six chipped painted scenes running round its walls.",
              "Dust lies thick on everything. Six chipped painted scenes run round the walls at the height of a small woman's eye, and the door has swung shut behind you "
              "with a sound like a latch being lowered.", R_WOOD, "manor", "dark", False,
              rest_text="Not in here. The painted walls watch.")
    s["map"]["ceiling_ft"] = 15
    s["areas"] = [area("hovel", "The hovel", (1, 1), (8, 10))]
    P = s["props"]
    P += [auto("ct_hovel_arrive", (4, 9), "The hovel, from the door", "hovel:arrive", "not flag.ct_hovel_entered"),
          talk("ct_hovel_paintings", (4, 1), "Six chipped painted scenes", "hovel:paintings", model="painting"),
          talk("ct_hovel_bed", (2, 3), "The rotting bed", "hovel:bed", model="bed"),
          talk("ct_hovel_door_in", (4, 10), "The door, locked itself", "hovel:escape", model="door", when="flag.ct_hovel_fire"),
          prop("ct_hovel_table", (7, 4), "A bent table", kind="decor", model="table_round"),
          prop("ct_hovel_chair", (6, 6), "A broken chair", kind="decor", model="chair"),
          prop("ct_hovel_dust", (3, 6), "Thick dust, undisturbed", kind="decor", model="cobwebs"),
          prop("ct_hovel_window_a", (1, 5), "A slatted window, sealed", kind="decor", model="window"),
          prop("ct_hovel_window_b", (8, 7), "A slatted window, sealed", kind="decor", model="window")]
    s["exits"] = [exit_("out", (4, 10), "ct_wytchwood", "from_hovel", "Out of the hovel", when="not flag.ct_hovel_fire or flag.ct_hovel_escaped")]
    s["spawns"]["to_glade"] = [4, 9]
    s["encounters"] = []
    write("data/locations/ct_hovel.json", s)
    # the wood gets a spawn back at the hovel door
    w = read("data/locations/ct_wytchwood.json")
    w["spawns"]["from_hovel"] = [20, 57]
    w["spawns"]["from_clearing"] = [22, 4]
    w["spawns"]["north_bank"] = [22, 86]
    write("data/locations/ct_wytchwood.json", w)


def clearing():
    rows = M.crooked_tree()
    s = place("ct_crooked_tree", "The Crooked Tree", rows, (16, 29),
              "A flat glade of short green-grey grass in bright moonlight, a steep mound at its heart with a barren, impossibly twisted oak on it, and a goat skull at its foot.",
              "The moon has never looked closer. It is huge and it is grinning. At the middle of the glade a mound heaves up, and on it stands the Crooked Tree: a bare, "
              "twisted oak forty feet to its first limb, its branches knotting themselves as you watch. A great goat skull lies at its base with a carved crescent tied between "
              "its horns, and under the trunk a narrow mouth glows the warm colour of a campfire. Embers rise from the grass toward the moon.",
              R_TREE, "forest", "bright", True,
              areas=[area("glade", "The glade", (2, 2), (29, 29)), area("mound", "The mound", (12, 12), (20, 20)), area("south", "Where the trail comes in", (13, 26), (19, 30))],
              rest_text="The trees have writhed into a wall that nothing will damage, and the moon is leering. No.")
    s["map"]["ceiling_ft"] = 400
    P = s["props"]
    P += [auto("ct_clearing_arrive", (16, 29), "The glade, from the trail", "king:arrive", "not flag.ct_clearing_entered", radius=12),
          talk("ct_barrow_mouth", (16, 17), "The barrow mouth, glowing", "barrow:mouth", model="barrow", when="not flag.ct_phillip_taken"),
          talk("ct_skull", (16, 18), "The goat skull, with a carved moon between its horns", "ritual:skull", model="stag_head", when="flag.horned_king_destroyed and not flag.ct_ritual_done"),
          talk("ct_tree", (16, 16), "The Crooked Tree", "king:tree", model="dead_tree_a", scale=3.0, when="not flag.ct_tree_burned"),
          talk("ct_tree_burnt", (16, 16), "The Crooked Tree, burning", "king:tree_burnt", model="brazier", scale=3.0, when="flag.ct_tree_burned"),
          prop("ct_sigil_a", (8, 16), "A sigil line in the grass, glowing", kind="decor", model="floor_glyphs"),
          prop("ct_sigil_b", (24, 16), "A sigil line in the grass, glowing", kind="decor", model="floor_glyphs"),
          prop("ct_sigil_c", (16, 6), "A sigil line in the grass, glowing", kind="decor", model="floor_glyphs"),
          prop("ct_sigil_d", (16, 26), "A sigil line in the grass, glowing", kind="decor", model="floor_glyphs"),
          prop("ct_roots_a", (8, 8), "Roots over stones", kind="decor", model="stump"),
          prop("ct_roots_b", (23, 9), "Roots over stones", kind="decor", model="stump"),
          prop("ct_roots_c", (9, 23), "Roots over stones", kind="decor", model="stump"),
          prop("ct_roots_d", (24, 22), "Roots over stones", kind="decor", model="stump"),
          prop("ct_moon_vista", (16, 2), "The Crooked Moon, huge and grinning", kind="decor", model="statue_head")]
    s["npcs"] = [npc("ct_herald", (16, 24), "herald:start", when="flag.ct_phillip_taken and not flag.ct_herald_done and not flag.horned_king_destroyed", facing="south"),
                 npc("ct_herald", (16, 24), "herald:again", when="flag.ct_herald_done and not flag.horned_king_destroyed", facing="south"),
                 npc("ct_adela_spirit", (15, 19), "ember:start", when="flag.kehlenn_bound and not flag.ct_ember_done", facing="south"),
                 npc("ct_phillip_spirit", (17, 19), "plea:start", when="flag.ct_skull_spoke and not flag.ct_plea_done", facing="south")]
    s["exits"] = [exit_("to_barrow", (16, 17), "ct_barrow", "default", "Down into the barrow", when="not flag.ct_phillip_taken"),
                  exit_("to_wood", (16, 30), "ct_wytchwood", "from_clearing", "Back down the trail", when="flag.ct_tree_burned")]
    s["encounters"] = [{"id": "ct_born_king", "trigger": "dialogue", "final_battle": "crooked_tree", "lair": True,
                        "flag": "horned_king_destroyed", "quest": {"id": "the_crooked_tree", "stage": "end_of_the_crooked_queen"},
                        "monsters": [monster("horned_king_born", (15, 11), "The Born King", boss=True, facing="south")]}]
    s["lights"] = [{"cell": [16, 14], "kind": "fire", "bright_ft": 20, "dim_ft": 60, "color": "fire"}]
    s["spawns"]["from_barrow"] = [16, 22]
    write("data/locations/ct_crooked_tree.json", s)


def barrow():
    rows = M.barrow()
    s = place("ct_barrow", "Kehlenn's barrow", rows, (6, 11),
              "A low earthen hollow of packed dirt and knotted roots, a huge mossy skeleton against the far wall, a man kneeling in the middle.",
              "Packed earth and roots, and a ceiling you could touch. Against the far wall a skeleton the size of a cart lies wrapped in roots, glowing the colours of a campfire, "
              "and images of slain fey flicker in the light. Phillip Druskenvald kneels in the middle of the floor with the roots crushing him down. Trophies hang in the roots along the walls.",
              R_TREE, "cave", "dim", False,
              rest_text="No one regains Hit Points here, and every hour costs a level of Exhaustion. You would not rest if you could.")
    s["areas"] = [area("barrow", "The barrow", (1, 1), (10, 12))]
    P = s["props"]
    P += [auto("ct_barrow_arrive", (6, 11), "The barrow, from the mouth", "barrow:arrive", "not flag.ct_barrow_entered"),
          talk("ct_kehlenn_bones", (5, 2), "Kehlenn's skeleton, wrapped in roots", "barrow:kehlenn", model="skeleton_shackles", scale=2.0, when="not flag.ct_phillip_taken"),
          talk("ct_trophies_a", (2, 4), "Trophies in the roots", "barrow:trophies", model="relics", when="not flag.ct_trophies_taken"),
          talk("ct_trophies_b", (9, 5), "Trophies in the roots", "barrow:trophies", model="relics", when="not flag.ct_trophies_taken"),
          talk("ct_trophies_c", (2, 9), "A bird's nest of human hair, a jar of teeth", "barrow:trophies", model="jars", when="not flag.ct_trophies_taken"),
          prop("ct_barrow_roots_a", (1, 6), "Roots, thick as a man", kind="decor", model="vines"),
          prop("ct_barrow_roots_b", (10, 6), "Roots, thick as a man", kind="decor", model="vines"),
          prop("ct_barrow_fey_a", (3, 1), "A slain fey's face in the glow", kind="decor", model="stone_faces"),
          prop("ct_barrow_fey_b", (8, 1), "A slain fey's face in the glow", kind="decor", model="stone_faces")]
    s["npcs"] = [npc("phillip_druskenvald", (6, 7), "barrow:phillip", when="not flag.ct_phillip_taken", facing="south")]
    s["exits"] = [exit_("out", (6, 12), "ct_crooked_tree", "from_barrow", "Out of the barrow", when="flag.ct_phillip_taken or flag.ct_barrow_leaving")]
    s["lights"] = [{"cell": [5, 2], "kind": "fire", "bright_ft": 15, "dim_ft": 30, "color": "fire"}]
    s["encounters"] = []
    write("data/locations/ct_barrow.json", s)


def master_suite():
    rows = M.master_suite()
    s = place("ct_master_suite", "The Green Queen Inn, master suite", rows, (12, 12),
              "The inn's master suite with the furniture shoved to the walls, a runic circle cut in the floor and ringed with burned-out candles, Adela's charred bones inside it.",
              "The furniture has been shoved to the walls and a runic circle cut into the boards, ringed with candle stubs burned to nothing. The smell of burned flesh is thick and "
              "close. Inside the circle, a small heap of charred bones.", "wickermoor", "manor", "dim", False, rest="safe",
              rest_text="You will not sleep in here.")
    s["areas"] = [area("suite", "The master suite", (1, 1), (22, 13))]
    P = s["props"]
    P += [auto("ct_suite_arrive", (12, 12), "The suite, from the door", "suite:arrive", "not flag.ct_suite_seen"),
          talk("ct_suite_circle", (11, 7), "A runic circle cut into the floor", "suite:circle", model="rune_circle", scale=2.0),
          prop("ct_suite_bones", (11, 7), "Charred bones, inside the circle", kind="decor", model="bone_scatter"),
          talk("ct_suite_desk", (19, 3), "A desk with a calligrapher's tray", "suite:desk", model="desk"),
          talk("ct_suite_jewels", (4, 3), "A jewellery box on the dresser", "suite:jewels", model="case"),
          talk("ct_suite_box", (3, 2), "A locked strongbox", "suite:box", model="chest_iron", when="not flag.ct_box_open"),
          talk("ct_suite_grimoire", (9, 7), "An open grimoire by the circle", "suite:grimoire", model="lectern"),
          talk("ct_suite_parchment", (13, 8), "A tear-stained parchment", "suite:parchment", model="letter"),
          prop("ct_suite_candles_a", (9, 5), "A burned-out candle", kind="decor", model="candle_cluster"),
          prop("ct_suite_candles_b", (13, 5), "A burned-out candle", kind="decor", model="candle_cluster"),
          prop("ct_suite_candles_c", (9, 9), "A burned-out candle", kind="decor", model="candle_cluster"),
          prop("ct_suite_candles_d", (13, 9), "A burned-out candle", kind="decor", model="candle_cluster"),
          prop("ct_suite_bed", (3, 11), "A bed shoved against the wall", kind="decor", model="bed"),
          prop("ct_suite_settee", (21, 11), "A settee, shoved aside", kind="decor", model="settee"),
          prop("ct_suite_window", (12, 1), "A window onto the dark", kind="decor", model="window")]
    s["exits"] = [exit_("out", (12, 14), "wickermoor_green_queen_inn_upper", "from_suite", "Out to the landing")]
    write("data/locations/ct_master_suite.json", s)


# ---- the hooks in Wickermoor ----------------------------------------------------------------------------------------------------------------
def build_village_hooks():
    path = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(path.read_text())
    mine = (CT + "hook:", CT + "chaos:", CT + "mayor:", CT + "will:")
    town["npcs"] = [n for n in town["npcs"] if not str(n.get("dialogue", "")).startswith(mine)]
    doris = next(n for n in town["npcs"] if n["npc"] == "doris_squire")
    c = doris["cell"]
    rows = town["map"]["rows"]
    taken = {tuple(n["cell"]) for n in town["npcs"]} | {tuple(p["cell"]) for p in town["props"]}
    spots = [(x, y) for r in range(1, 8) for y in range(c[1] - r, c[1] + r + 1) for x in range(c[0] - r, c[0] + r + 1)
             if 0 <= y < len(rows) and 0 <= x < len(rows[0]) and rows[y][x] == "." and (x, y) not in taken and max(abs(x - c[0]), abs(y - c[1])) == r]
    spots = [s for i, s in enumerate(spots) if s not in spots[:i]][1:]
    after_vigil = "flag.wicker_man_burned"
    town["npcs"][0:0] = [
        {"npc": "doris_squire", "cell": c, "dialogue": CT + "hook:doris_start", "when": f"{after_vigil} and not flag.ct_hook_given", "approach": 10, "facing": "south"},
        {"npc": "doris_squire", "cell": c, "dialogue": CT + "hook:doris_again", "when": f"flag.ct_hook_given and not flag.ct_barrow_entered", "facing": "south"},
        {"npc": "ct_confessor_a", "cell": list(spots[0]), "dialogue": CT + "chaos:confess_a", "when": f"{after_vigil} and days_since.ct_clock >= 1 and not flag.ct_confessed_a", "facing": "west"},
        {"npc": "ct_confessor_b", "cell": list(spots[2]), "dialogue": CT + "chaos:confess_b", "when": f"{after_vigil} and days_since.ct_clock >= 2 and not flag.ct_confessed_b", "facing": "west"},
        {"npc": "ct_confessor_c", "cell": list(spots[4]), "dialogue": CT + "chaos:confess_c", "when": f"{after_vigil} and days_since.ct_clock >= 3 and not flag.ct_confessed_c", "facing": "east"},
        {"npc": "ct_mob_leader", "cell": list(spots[6]), "dialogue": CT + "mayor:mob_start", "when": f"{after_vigil} and not flag.ct_mayor_settled and flag.ct_hook_given", "approach": 8, "facing": "east"},
    ]
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")
    # Marianna's will delivery uses her stable entry: she is already in the village (alda_will)
    town = json.loads(path.read_text())
    town["npcs"] = [n for n in town["npcs"] if not str(n.get("dialogue", "")).startswith(CT + "will:")]
    town["npcs"].insert(0, {"npc": "marianna_grey", "cell": next(n for n in town["npcs"] if n["npc"] == "marianna_grey")["cell"], "dialogue": CT + "will:marianna",
                            "when": "item:alda_will and not flag.alda_will_delivered", "facing": "south"})
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")
    inn = ROOT / "data/locations/wickermoor_green_queen_inn.json"
    d = json.loads(inn.read_text())
    d["npcs"] = [n for n in d["npcs"] if not str(n.get("dialogue", "")).startswith(CT)]
    d["npcs"][0:0] = [
        {"npc": "jean_myriel", "cell": [14, 11], "dialogue": CT + "hook:jean_start", "when": "flag.wicker_man_burned and not flag.ct_barrow_entered", "facing": "south"},
        {"npc": "siv_harga", "cell": [16, 11], "dialogue": CT + "hook:siv_start", "when": "flag.wicker_man_burned and not flag.ct_barrow_entered", "facing": "south"}]
    inn.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
    up = ROOT / "data/locations/wickermoor_green_queen_inn_upper.json"
    d = json.loads(up.read_text())
    d["props"] = [p for p in d["props"] if not p["id"].startswith("ct_")]
    d["props"].append(talk("ct_suite_door", (16, 10), "The master suite door, shut tight", "suite:door", model="door_house", when="flag.ct_hook_given and not flag.ct_suite_open"))
    d["exits"] = [e for e in d["exits"] if not e["id"].startswith("ct_")]
    d["exits"].append(exit_("ct_suite_exit", (15, 10), "ct_master_suite", "default", "Into the master suite", when="flag.ct_suite_open"))
    d["spawns"]["from_suite"] = [14, 10]
    up.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")


def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if x["id"] != "ct_wytchwood"] + [
        {"id": "ct_wytchwood", "name": "The Wytchwood", "location": "ct_wytchwood", "spawn": "default", "pos": [0.5, 0.1], "region": R_WOOD,
         "when": "flag.wytchwood_open or visited:ct_wytchwood", "summary": "A dense old forest north of the moors, where every path bends back to the edge until it wants you."}]
    t["roads"] = [x for x in t["roads"] if x["id"] != "wickermoor_to_wytchwood"] + [
        {"id": "wickermoor_to_wytchwood", "from": "wickermoor_village", "to": "ct_wytchwood", "hours": 14, "name": "The moor road north", "when": "flag.wytchwood_open or visited:ct_wytchwood"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


# ---- people -----------------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude, sprite, tags, region
    ("kehlenn", "Kehlenn, the Crooked Queen", "Archfey goddess of the realm", "The Green Queen who made this land, wronged and bitter. Her voice comes from the roots: raspy, crackling, each word a cracking branch. She is honest, and cannot be talked out of her goal.", "indifferent", "villager", ["voice_druskenvald"], R_TREE),
    ("ct_hk_goat", "The Horned King", "A black goat with three red eyes", "Her consort, a god of sin woven from Phillip's soul: a huge black goat, always half seen between the trees, low, rumbling and seductive. He answers questions with questions.", "indifferent", "villager", ["voice_druskenvald"], R_WOOD),
    ("ct_false_rowan", "A white-gowned young woman", "A maidenwood's lure", "A young woman in a white gown, digging at a tree's roots with her bare hands. She says she has lost her locket. There is one at every tree.", "hostile", "villager", ["voice_druskenvald"], R_WOOD),
    ("ct_illusion", "A familiar face in the thicket", "A hypnovulfen's lure", "Someone the party knows and trusts, begging for help from the underbrush. It is not them.", "friendly", "villager", [], R_WOOD),
    ("ct_herald", "The Born King's herald", "A bright-eyed twig of a creature", "A herald of sticks and moss who has been sent to read the terms of the combat, and has the order of the pages wrong.", "indifferent", "villager", ["voice_hollow"], R_TREE),
    ("ct_phillip_spirit", "Phillip, in the skull", "A mild voice from a goat skull", "Phillip Druskenvald speaking through the goat skull in his own voice, mild and clear at last.", "friendly", "phillip_druskenvald", ["voice_druskenvald"], R_TREE),
    ("ct_adela_spirit", "Adela, a specter", "A woman in blue-green light with an ember in her hands", "Adela Druskenvald's specter, kind and calm, carrying a single ember.", "friendly", "adela_druskenvald", ["voice_druskenvald"], R_TREE),
    ("ct_confessor_a", "Wilf Baxter", "A baker's apprentice, ashamed, confessing", "A village boy who stole bread from the dead and cannot say why. He heard something in the dark whisper that he deserved it.", "friendly", "villager", ["voice_hollow", "child"], "wickermoor"),
    ("ct_confessor_b", "Nell Harrow", "A farmhand, shaking, confessing", "A woman who struck her brother over a debt and watched him fall. She heard a low voice tell her it was only fair.", "friendly", "villager", ["voice_hollow"], "wickermoor"),
    ("ct_confessor_c", "Maud Tilling", "A widow, whispering, confessing", "A neighbour who has been selling the sick their own medicine at three times the price, and heard a three-eyed thing approve.", "friendly", "villager", ["voice_hollow"], "wickermoor"),
    ("ct_mob_leader", "The mob's loudest voice", "A mill hand with a rope", "A big-voiced mill hand at the head of a crowd with a rope and a grievance, who wants someone to hang for what the cult did.", "hostile", "villager", ["voice_hollow"], "wickermoor"),
]


def build_people():
    for (nid, name, title, summary, att, sprite, tags, region) in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": sprite, "region": region,
                                         **({"tags": tags} if tags else {})})


# ---- quests -----------------------------------------------------------------------------------------------------------------------------
def stage(sid, journal, hint=None, objectives=None, ends=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    return d


def quest(qid, name, kind, region, giver, summary, stages, **extra):
    write(f"data/quests/{qid}.json", {"id": qid, "name": name, "kind": kind, "region": region, "giver": giver, "summary": summary, "stages": stages, **extra})


def build_quests():
    quest("the_crooked_tree", "The Crooked Tree", "main", R_TREE, "doris_squire",
          "Phillip Druskenvald has gone north to find his wife's soul, and the Crooked Queen has called him to her barrow under the Crooked Tree. Two nights through the Wytchwood, a goat that tempts, a barrow, a king made of sin and one great sacrifice.",
          [stage("the_last_hope", "Both sides of the village begged us to find Phillip: some to punish him, some to save him. He was seen stumbling into the Green Queen Inn.", "Find out where Phillip went.", ["Learn he is at the inn"]),
           stage("the_master_suite", "Phillip locked himself in the master suite, tried an Old Ways rite with Alda's grimoire, and failed. He is gone.", "Open the suite and read what he left.", ["Read the parchment"]),
           stage("into_the_wytchwood", "A crude crooked tree over a mound, and words saying the Crooked Queen holds Adela's soul in the Wytchwood. Two nights north.", "Walk to the Wytchwood and go in.", ["Reach the creek"]),
           stage("tracking_phillip", "We follow Phillip's trail through the Wytchwood, past the creek, the thicket, the hovel and the grove.", "Keep to his trail.", ["Reach the goat's path"]),
           stage("live_deliciously", "A black goat with three red eyes stepped out of the dark and made each of us an offer.", "Answer the Horned King.", ["Each hero accepts or refuses"]),
           stage("six_horns_his_crown", "The clearing, the Crooked Tree, a barrow glowing like a campfire, and the Crooked Queen inside it.", "Go into the barrow.", ["Phillip is taken"]),
           stage("born_king", "Phillip was dragged up into the tree and unfolded into a thirty-foot goat. He waits outside, patient.", "Come out of the barrow and face the Born King.", ["Destroy the Horned King"]),
           stage("end_of_the_crooked_queen", "Only the goat skull is left, and it speaks with Phillip's voice. It asks each of us for a sacrifice.", "Give the skull what it asks.", ["Resolve the ritual"]),
           stage("flickering_life", "Kehlenn is bound in the moon and the tree is ash. The wood is quiet; the way out is long.", "Leave the Wytchwood.", ["Leave the Wytchwood"]),
           stage("bound", "Kehlenn is bound in the moon, and the Crooked Tree burned.", ends="success"),
           stage("crooked_rebirth", "The Crooked Queen rose, and the Hollow was remade crooked.", ends="failure")])
    quest("the_barrows_side", "The Barrow's Side of the Story", "main", R_TREE, "kehlenn",
          "The Crooked Queen says Phillip stole her realm and forgot her. She tells the whole story if she is asked. She cannot be talked out of her goal, but she can be listened to, argued with or refused. Siding with her is an ending, not a failure.",
          [stage("heard", "Kehlenn is ready to tell us her side.", "Ask her for her story."),
           stage("listened", "We heard the Crooked Queen's whole account.", "Argue with her, refuse her, or take her side."),
           stage("argued", "We argued with her. She does not move.", ends="success"),
           stage("refused", "We refused her.", ends="success"),
           stage("sided", "We took the Crooked Queen's side, and promised to help her.", ends="success")])
    quest("the_horned_kings_offer", "The Horned King's Offer", "main", R_WOOD, "ct_hk_goat",
          "A black goat with three red eyes walks the wood and tempts. His final offer to each hero is their heart's desire, a Dark Bargain with only the features they choose, and a level. He will attack anyway.",
          [stage("tempted", "The Horned King has spoken to us in the dark.", "Keep going north, and keep your wits."), stage("offered", "He made each of us his offer, with the price left unsaid.", "Accept or refuse, hero by hero."),
           stage("refused", "We refused him, each of us.", ends="success"), stage("bargained", "Some of us took his bargain.", ends="success"),
           stage("kneeled", "All of us took his bargain, and we knelt.", ends="success")])
    quest("what_each_hero_offers", "What Each Hero Offers", "main", R_TREE, "ct_phillip_spirit",
          "The goat skull asks each hero for something of great personal value. There is no right answer and no wrong one, only what it costs.",
          [stage("asked", "The skull asked for our sacrifices, one by one.", "Touch the skull and offer something."),
           stage("offering", "The ritual is under way.", "Every hero must offer."),
           stage("bound", "Every offering was accepted. Kehlenn is bound.", ends="success"),
           stage("refused", "The ritual failed.", ends="failure")])
    quest("phillips_plea", "Phillip's Plea", "main", R_TREE, "ct_phillip_spirit",
          "Phillip speaks through the goat skull in his own voice, mild and clear, to ask for the sacrifices. It can fail only by silence.",
          [stage("heard", "Phillip, through the skull, asked for our help.", "Answer him."),
           stage("answered", "We answered him, and he thanked us.", ends="success"),
           stage("silence", "We said nothing, and he went quiet.", ends="failure")])
    quest("adelas_ember", "Adela's Ember", "main", R_TREE, "ct_adela_spirit",
          "Adela's specter carries a single ember to the Crooked Tree's roots and asks for a word. It can fail only by silence.",
          [stage("met", "Adela's specter waits by the skull with an ember in her hands.", "Speak to her."),
           stage("lit", "We stood with her, and she lit the Crooked Tree.", ends="success"),
           stage("unlit", "We stood silent, and she carried the ember to the roots alone.", ends="failure")])
    quest("alda_will", "Alda's Will", "side", "wickermoor", "marianna_grey",
          "Alda Farnum's strongbox in the master suite holds her will, and it leaves the Green Queen Inn and its goods to Marianna Grey. She does not know.",
          [stage("found", "A locked strongbox in the master suite dresser.", "Open the strongbox."),
           stage("have", "We have Alda's will, which leaves the inn to Marianna Grey.", "Take it to Marianna at the stable."),
           stage("delivered", "Marianna Grey now owns the Green Queen Inn.", ends="success"),
           stage("burned", "We burned the will. The inn's debts went with it.", ends="failure")])
    quest("save_the_mayor", "The Mayor's Neck", "side", "wickermoor", "wendel_somerton",
          "Many in the village were cultists, many others are dead, and a mob wants someone to hang. The mayor is the nearest neck.",
          [stage("mob", "A mob with a rope is looking for the mayor.", "Stop them before they jail or hang Wendel."),
           stage("saved", "We got the mayor out of the mob's hands.", ends="success"),
           stage("jailed", "The mob jailed him. He is in his own cell.", ends="failure"),
           stage("lynched", "We were too late. The mob hanged him from the oak.", ends="failure")])
    quest("chaos_reigns", "Chaos Reigns", "side", "wickermoor", "ct_confessor_a",
          "Every night we delay, another villager falls to a vice. Each of them heard a three-eyed beast whispering.",
          [stage("first", "A villager confessed, and said a three-eyed thing whispered to them.", "Hear the others out before the village falls apart."), stage("some", "More villagers have confessed.", "Hear the rest, and then go north."),
           stage("heard", "We heard them all and know what the beast promises.", ends="success"),
           stage("bedlam", "The village has gone to bedlam: shops shut and doors barred.", ends="failure")])
    quest("lost_and_found", "Lost and Found", "side", R_TREE, "kehlenn",
          "The barrow walls hold everything the Crooked Queen has taken: the party's lost things from the whole campaign, and a small portrait of a young woman, Rowan's sister.",
          [stage("seen", "The roots of the barrow hold trophies.", "Take back what is ours, or leave it."), stage("taken", "We took back what was ours.", ends="success"),
           stage("left", "We left it all hanging in the roots.", ends="failure")])
    quest("heralds_terms", "The Herald Reads the Terms", "side", R_TREE, "ct_herald",
          "The Born King's herald is here to read the terms of the combat. He has the pages in the wrong order.",
          [stage("reading", "The herald is reading the terms of the combat. The pages are out of order.", "Help the herald, or ignore him."),
           stage("sorted", "We put the herald's pages in order, and he read the terms properly.", ends="success"),
           stage("garbled", "He read it all the wrong way round and nobody was any the wiser.", ends="failure")],
          closes=[{"stage": "garbled", "from": ["reading"], "when": "flag.horned_king_destroyed", "warn": "The herald will go when the Born King falls."}])


# ---- items, monsters, dark gifts ---------------------------------------------------------------------------------------------------------
ITEMS = [   # id, name, category, cost_gp, summary
    ("alda_will", "Alda Farnum's will", "quest", 0, "A will in a neat, careful hand leaving the Green Queen Inn and everything in it to Marianna Grey."),
    ("grimoire_old_ways", "Grimoire of the Old Ways", "quest", 0, "A battered book of rituals, open at a failed rite, with Phillip's desperate margin notes."),
    ("crooked_tree_parchment", "A tear-stained parchment", "quest", 0, "A crude crooked tree over a mound, and scratched words that say the Crooked Queen holds Adela's soul in the Wytchwood."),
    ("ledger_of_debts", "A ledger of favours and debts", "quest", 0, "Alda's ledger of what the village and its guests owe. It names one or two more secret sinners."),
    ("hare_earrings", "Silver hare earrings", "treasure", 15, "A pair of silver earrings shaped like antlered hares."),
    ("copper_rings", "Silver and copper rings", "treasure", 15, "Three plain rings of silver and copper, 5 gp each."),
    ("painters_supplies", "Painter's Supplies", "tool", 10, "A battered tin of pigments, brushes and a palette, found under the hovel bed."),
    ("clue_pocket_watch", "Phillip's silver pocket watch", "quest", 0, "A silver pocket watch stopped at a quarter to midnight. The initials P.D. are engraved on the case."),
    ("clue_lantern", "A cracked hooded lantern", "quest", 0, "A hooded lantern with a cracked glass, still warm."),
    ("clue_hip_flask", "A silver hip flask marked P.D.", "quest", 0, "An engraved silver hip flask, empty. The engraving reads P.D."),
    ("clue_cloth", "A torn scrap of pinstriped cloth", "quest", 0, "A scrap of fine grey pinstripe, torn off on a thorn."),
    ("clue_cane", "Phillip's goat-headed cane", "quest", 0, "A black cane with a silver goat-skull head, laid across the path."),
    ("rowans_sister_portrait", "A small oval portrait of a young woman", "quest", 0, "A miniature of a girl with a serious mouth. She looks like Rowan. A clue for later."),
    ("wooden_toy_deer", "A smooth wooden toy deer", "quest", 0, "A child's toy deer, worn smooth by a hand."),
    ("jar_of_teeth", "A jar of human teeth", "quest", 0, "A jar of human teeth."),
    ("posy_ring", "A tarnished silver posy ring", "treasure", 10, "A silver posy ring, black with age."),
    ("birds_nest_of_hair", "A bird's nest of human hair", "quest", 0, "A bird's nest woven of human hair."),
    ("moth_wing", "A dream eater's moth wing", "quest", 0, "A moth's wing held in the hand makes the bearer immune to a dream eater's wings."),
]


def build_items():
    for (iid, name, cat, gp, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": gp, "summary": summary})
    write("data/magic_items/adelas_planchette.json", {
        "id": "adelas_planchette", "name": "Planchette of Adela Druskenvald", "source": {"book": "CrookedMoon", "note": "Fabled Heirloom (if The Lovers was drawn). The book's numbers, our words. Its Detect Magic, Locate Object and See Invisibility charges wait on the engine's heirloom rules."},
        "category": "wondrous", "weight_lb": 1, "cost_gp": 0, "magic": {"rarity": "rare", "attunement": True}, "theme": "implements", "icon": "bottle",
        "modifiers": [{"stat": "resistance", "damage_type": "radiant"}],
        "summary": "Adela's necklace, a spellcasting focus: Radiant Resistance (its Int and Wis bonus and charges wait on the engine). Resurrecting Adela always fails."})
    write("data/magic_items/phillips_cane.json", {
        "id": "phillips_cane", "name": "Cane of Phillip Druskenvald", "source": {"book": "CrookedMoon", "note": "Fabled Heirloom (if The Devil was drawn). The book's numbers, our words. Its spell storing and summons wait on the engine."},
        "category": "wondrous", "weight_lb": 3, "cost_gp": 0, "magic": {"rarity": "rare", "attunement": True}, "theme": "implements", "icon": "bottle",
        "modifiers": [{"stat": "spell_attack", "value": 1}, {"stat": "spell_dc", "value": 1}],
        "summary": "A rod and spellcasting focus with a silver goat-skull head: +1 to spell attacks and spell save DCs (its stored spell and summons wait on the engine)."})
    write("data/magic_items/hypnovulfen_figure.json", {
        "id": "hypnovulfen_figure", "name": "Hypnovulfen Figure", "source": {"book": "CrookedMoon", "note": "A cursed curio from the barrow walls; its focus, biting teeth, Confusion and hunger wait on the engine."},
        "category": "wondrous", "weight_lb": 1, "cost_gp": 0, "magic": {"rarity": "uncommon", "attunement": False}, "theme": "implements", "icon": "bottle",
        "summary": "A small carved hypnovulfen with too many teeth. A cursed curio."})


def build_boons():
    base = read("data/dark_gifts/might_of_the_old.json")
    for gid, name, ab, abname in (("binding_boon_might", "Boon of the Binding: Might", "str", "Strength"), ("binding_boon_mind", "Boon of the Binding: Mind", "int", "Intelligence"),
                                  ("binding_boon_grace", "Boon of the Binding: Grace", "cha", "Charisma")):
        g = copy.deepcopy(base)
        g.update({"id": gid, "name": name, "vestige": "Adela's power", "summary": f"{abname} +2 (max 24), given when Kehlenn is bound. No price.",
                  "source": {"book": "CM2024", "note": "chapter 24: +2 to one ability when the ritual binds Kehlenn (the Moonfall variant; level 14 only comes from the Horned King's bargain). Our words."}})
        g["benefit"] = {"modifiers": [{"stat": "ability", "ability": ab, "value": 2, "max": 24}], "text": f"Adela's power rolls through you as the binding takes. Your {abname} score increases by 2, to a maximum of 24."}
        g["cost"] = {"modifiers": [], "text": "None. This one was freely given.", "features": []}
        write(f"data/dark_gifts/{gid}.json", g)


def build_monsters():
    h = read("data/monsters/horned_king.json")
    h.update({"id": "horned_king_born", "name": "The Born King",
              "summary": "Sin made flesh, thirty feet tall: six horns, bat wings, a split lion's tail and a dragon's maw, fighting under the Crooked Queen's influence."})
    h["lair_actions"] = [
        {"id": "crooked_effigies", "name": "Crooked Effigies", "kind": "summon", "summon": {"monster": "crooked_effigy", "count": 3, "max": 3},
         "summary": "Three effigies drop from the branches within 60 ft of the mound.", "text": "Kehlenn's branches drop three Crooked Effigies within 60 feet of the mound. They vanish when she uses this again or when the Horned King falls."},
        {"id": "grasping_roots", "name": "Grasping Roots", "kind": "save", "save": {"ability": "str", "dc": 15, "success": "none"}, "targets": {"range": 120, "count": 3},
         "on_fail": [{"do": "condition", "condition": "grappled"}], "summary": "Up to three creatures in the clearing: DC 15 Strength save or Grappled (escape DC 13) until she uses this again.",
         "text": "Roots erupt and seize up to three creatures in the clearing."},
        {"id": "moonlight_dirge", "name": "Moonlight Dirge", "kind": "save", "save": {"ability": "con", "dc": 15, "success": "half"}, "targets": {"range": 120, "count": 8},
         "damage": [{"average": 10, "dice": "3d6", "type": "radiant"}], "summary": "Every creature in the moonlight but the Horned King: DC 15 Con save, 3d6 radiant and Disadvantage on its next attack, half on a success.",
         "text": "The whole clearing is moonlit, her effigies included."}]
    h["phases"] = [{"id": "wrath_of_the_crooked_queen", "name": "Wrath of the Crooked Queen", "when": {"bloodied": True}, "lair": True, "flag": "ct_born_king_wrath", "say": "ct_born_king_wrath",
                    "summary": "At Bloodied the Crooked Queen's wrath comes down: a start-of-turn Wisdom save for every hero but the effigies, with a penalty of their own choosing.",
                    "lair_actions": h["lair_actions"] + [
                        {"id": "wrath", "name": "Wrath of the Crooked Queen", "kind": "save", "save": {"ability": "wis", "dc": 15, "success": "none"}, "targets": {"range": 120, "count": 6},
                         "damage": [{"average": 10, "dice": "3d6", "type": "psychic"}], "summary": "Heroes: DC 15 Wisdom save or 10 psychic damage and no Reactions until their next turn.",
                         "text": "Her wrath breaks on the clearing. A hero who fails loses Concentration or takes 10 psychic damage, or loses their Reactions."}]}]
    h["source"] = dict(h["source"]); h["source"]["note"] = "The Born King of chapter 24: the Horned King's block with Kehlenn's Influence as lair actions and the Wrath of the Crooked Queen as its second phase. Numbers are the book's; the words are ours."
    write("data/monsters/horned_king_born.json", h)
    base = read("data/dark_gifts/might_of_the_old.json")
    for gid, name, ab, abname in (("horned_gift_might", "The Horned King's Might", "str", "Strength"), ("horned_gift_mind", "The Horned King's Mind", "int", "Intelligence"),
                                  ("horned_gift_grace", "The Horned King's Grace", "cha", "Charisma")):
        g = copy.deepcopy(base)
        g.update({"id": gid, "name": name, "vestige": "the Horned King", "summary": f"{abname} +2 (max 24). The price: half damage to the Horned King and his, and a DC 19 Wisdom save before you may target him or Kehlenn.",
                  "source": {"book": "CM2024", "note": "chapter 24: the Horned King's bargain, with only the benefits the hero chooses; the Price is the cost. Our words."}})
        g["benefit"] = {"modifiers": [{"stat": "ability", "ability": ab, "value": 2, "max": 24}], "text": f"You asked for more, and he gave it. Your {abname} score increases by 2, to a maximum of 24."}
        g["cost"] = {"modifiers": [], "text": "The Price. Only a Wish or Divine Intervention can lift it.",
                     "features": [{"id": "the_price", "name": "The Price", "summary": "Half damage against the Horned King and his minions; a DC 19 Wisdom save to target him, Kehlenn, the tree or their minions, or you lose the action (the engine hook waits).",
                                   "text": "You deal half damage to the Horned King and his minions, and before you attack or cast at him, the Crooked Queen, the Crooked Tree or their minions you make a DC 19 Wisdom saving throw or pick another target or lose the action.", "action": "passive", "implemented": "text"}]}
        write(f"data/dark_gifts/{gid}.json", g)


SETS = {   # cutscene set -> one prompt per scene (placeholders first; real art is queued separately)
    "ct_failed_rite": ["The master suite by candle stubs: a runic circle cut into the floor, charred bones in the middle",
                       "A tear-stained parchment: a crude crooked tree over a mound, scratched words beneath"],
    "ct_between_the_trees": ["A ruby eye between blue-black pine trunks",
                             "A grey horn and a shaggy black flank sliding out of sight between the trees"],
    "ct_live_deliciously": ["Clouds swallowing the moon over a dark wood",
                            "A huge black goat stepping from the thicket, its third eye opening"],
    "ct_six_horns_his_crown": ["A moonlit clearing, an impossibly tall crooked tree on its mound, a goat skull with a wooden moon between its horns",
                               "The Crooked Moon above the tree, enormous and grinning"],
    "ct_druskenvald_kneels": ["Roots crawling over a kneeling man in a pinstriped suit",
                              "His body torn upward through a barrow roof",
                              "Outside, the tree bulging as a winged goat shape unfolds from it"],
    "ct_born_king": ["The beast made flesh: six horns, bat wings, a split lion's tail, a dragon's maw, thirty feet tall",
                     "A fey queen's face forming in the bark of a crooked tree, laughing"],
    "ct_fleeting_victory": ["A beast's head flickering into a thin man's face, mild and astonished",
                            "A burst of gore, and then only a goat skull on the grass",
                            "A face in the bark of the tree, shrieking"],
    "ct_underneath_the_crooked_moon": ["A single ember drifting down on the wind to the roots of a tree",
                                       "The whole tree in flame",
                                       "A huge grinning moon, its grin twisting into a scowl",
                                       "Two blue-green specters embracing, fading"],
    "ct_crooked_defeat": ["A huge horned beast rearing and bellowing at a grinning moon",
                          "A trunk splitting, a beautiful, terrible, crooked queen rising toward the moon",
                          "The land below withering and twisting"],
}


def build_cutscenes():
    pics = {}
    for first, prompts in SETS.items():
        for n, desc in enumerate(prompts, 1):
            cid = first if n == 1 else f"{first}_{n}"
            pics[cid] = desc
    write("tools/content/crooked_tree_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": pics})
    for cid, desc in pics.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("ct_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


if __name__ == "__main__":
    wytchwood()
    hovel()
    clearing()
    barrow()
    master_suite()
    build_people()
    build_quests()
    build_items()
    build_monsters()
    build_boons()
    build_village_hooks()
    build_travel()
    build_cutscenes()
    print("ok")
