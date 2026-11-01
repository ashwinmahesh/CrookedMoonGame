"""The Maidenmist Cemetery's maps (R19), painted in code with maidenmist_land.Land. Each builder returns a location dict (not yet written);
build_maidenmist.py adds the people, rites, fights and hazards that need dialogue and writes everything. Sizes follow the digest's
'ours' column. Exits are named for where they lead; every site has its way back to the sepulcher hub."""
import random
from maidenmist_land import Land

MM = "maidenmist/"
REGION = "maidenmist_cemetery"


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
        d["dialogue"] = MM + dialogue
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


def spread(land, center, n, spacing=2, min_r=3, max_r=16, avoid=()):
    """n open squares round `center`, at least `spacing` apart and `min_r` from the centre, nearest first (a fight's starting spots)."""
    cx, cy = center
    cells = sorted(land.open_cells((max(0, cx - max_r), max(0, cy - max_r), min(land.w - 1, cx + max_r), min(land.h - 1, cy + max_r))),
                   key=lambda c: (c[0] - cx) ** 2 + (c[1] - cy) ** 2)
    out = []
    for c in cells:
        if (c[0] - cx) ** 2 + (c[1] - cy) ** 2 < min_r * min_r or c in avoid:
            continue
        if all(max(abs(c[0] - o[0]), abs(c[1] - o[1])) >= spacing for o in out):
            out.append(c)
        if len(out) == n:
            return out
    raise RuntimeError(f"no room for {n} foes round {center}")


def dress(land, loc, region, spec, n, tag, gap=2):
    """Scatter n ordinary props over `region`: spec is [(model, label, ground)] where ground '=' lays low cover under it, '#' a block."""
    rng = land.rng
    x0, y0, x1, y1 = region
    placed, tries = 0, 0
    while placed < n and tries < n * 60:
        tries += 1
        x, y = rng.randint(x0, x1), rng.randint(y0, y1)
        if (x, y) in land.reserved or land.c[y][x] != ".":
            continue
        if any(abs(x - p["cell"][0]) <= gap and abs(y - p["cell"][1]) <= gap for p in loc["props"]):
            continue
        model, label, ground = spec[rng.randrange(len(spec))]
        if ground:
            land.c[y][x] = ground
        loc["props"].append(prop(f"{tag}_{placed}", (x, y), label, kind="decor", model=model))
        placed += 1


HEADSTONES = [("gravestone", "A weathered headstone", "="), ("gravestone", "A leaning marker, the name worn away", "="),
              ("gravestone", "A headstone with a rhyme nobody finished", "="), ("grave_mound", "A sunken grave", "="), ("cairn", "A cairn of grave-stones", "="),
              ("bones", "A scatter of old bones", None), ("dead_tree_a", "A dead tree, bent toward the sepulcher", "#"), ("dead_tree_b", "A dead tree hung with fog", "#")]


def base_loc(lid, name, land, outdoors, theme, light, summary, text, rest="risky", rest_text=None):
    d = {"id": lid, "name": name, "region": REGION, "summary": summary, "text": text,
         "map": {"rows": land.rows(), "theme": theme, "light": light, "outdoors": outdoors},
         "areas": [], "spawns": {}, "exits": [], "props": [], "npcs": [], "encounters": [], "rest": rest}
    if outdoors:
        d["map"]["elevation"] = land.elevation()
    if rest_text:
        d["rest_text"] = rest_text
    return d


def check_reach(land, spawn, targets, lid):
    seen = land.reachable(spawn)
    for t in targets:
        if tuple(t) not in seen:
            raise RuntimeError(f"{lid}: {t} not reachable from {spawn}")


# ---- the gate and the Corpse Road ---------------------------------------------------------------------------------------------------
def gate():
    w, h = 40, 30
    L = Land(w, h, 1901)
    L.hill(20, 8, 16, 3).smooth()
    L.border("#")
    L.hline(0, w - 1, 12, "#")                                 # the iron picket fence on its stone base
    L.clear((19, 12), (20, 12))                                # the gate, hanging bent outward
    L.rect(18, 12, 21, 12, ".")
    L.rect(19, 0, 20, 29, ".")                                 # the cobbled road
    L.rect(19, 0, 20, 0, "."); L.rect(19, 29, 20, 29, ".")
    L.blob(8, 21, 7, 5, "~", only=".")
    L.blob(31, 22, 6, 5, "~", only=".")
    L.hold((19, 29), (20, 29), (19, 0), (20, 0), (19, 12), (20, 12), (19, 14), (22, 14), (17, 14), r=1)
    L.scatter((2, 14, 17, 27), "=", 14); L.scatter((22, 14, 37, 27), "=", 14)
    L.scatter((2, 2, 16, 10), "=", 12); L.scatter((23, 2, 37, 10), "=", 12)
    loc = base_loc("mm_gate", "The Maidenmist Gate", L, True, "wilderness", "dim",
                   "A bent iron gate between two hooded reapers, and a fence that runs off into fog.",
                   "A fifteen-foot iron picket fence on a stone footing runs into the mist both ways. The gate hangs bent outward between two hooded iron reapers, and a broken chain lies in the mud. Beyond it, cobbles climb into grey.")
    loc["areas"] = [area("approach", "The approach", (1, 13), (38, 28)), area("gate_line", "The gate", (14, 10), (25, 14)), area("beyond", "Beyond the fence", (1, 1), (38, 11))]
    loc["spawns"] = {"default": [19, 27], "from_road": [19, 27], "from_corpse": [19, 2]}
    loc["exits"] = [exit_("road_back", (19, 29), "travel", "default", "The road back to Wickermoor"),
                    exit_("corpse_road", (19, 0), "mm_corpse_road", "from_gate", "The Corpse Road, north into the fog")]
    loc["props"] = [
        prop("mm_reaper_west", (17, 12), "A hooded iron reaper", kind="decor", model="statue_knight", scale=1.6, tint="#1c1c24"),
        prop("mm_reaper_east", (22, 12), "A hooded iron reaper", kind="decor", model="statue_knight", scale=1.6, tint="#1c1c24"),
        prop("mm_gate_bent", (19, 11), "The bent gate", kind="decor", model="gate_iron", facing="north"),
        prop("mm_gate_chain", (22, 16), "A snapped iron chain in the mud", model="rope_coils", call=MM + "road:gate_chain", approach=4, call_when="not flag.mm_chain_seen"),
        prop("mm_gate_first", (19, 24), "The fog, thickening", kind="decor", call=MM + "road:gate_arrive", approach=6, call_when="not flag.mm_gate_seen"),
        prop("mm_gate_lamp", (17, 25), "A lamp the fog has drowned", kind="decor", model="lantern_post"),
        prop("mm_gate_lamp2", (22, 25), "A lamp the fog has drowned", kind="decor", model="lantern_post"),
    ]
    for i, (x, y) in enumerate([(x, 12) for x in range(1, 38, 3) if not 16 <= x <= 23]):
        loc["props"].append(prop(f"mm_pickets_{i}", (x, y), "Iron pickets, cold to the touch", kind="decor", model="fence"))
    dress(L, loc, (1, 14, 38, 27), HEADSTONES, 10, "mm_gate_stone")
    dress(L, loc, (1, 1, 38, 10), HEADSTONES, 10, "mm_gate_in")
    loc["map"]["rows"] = L.rows()
    check_reach(L, (19, 27), [(19, 0), (19, 12), (22, 17)], "mm_gate")
    return loc


def corpse_road():
    w, h = 40, 30
    L = Land(w, h, 1902)
    L.hill(20, 15, 18, 2).smooth()
    L.border("#")
    L.rect(0, 13, 39, 17, ".")                                   # the 20-ft hearse road, west to east
    L.rect(0, 14, 0, 16, ".")
    L.blob(10, 6, 9, 4, "~", only="."); L.blob(30, 24, 9, 4, "~", only=".")
    L.hold((0, 15), (39, 15), (7, 15), (20, 15), (32, 15), r=2)
    for x0, x1 in ((2, 12), (14, 25), (27, 37)):
        L.scatter((x0, 2, x1, 11), "=", 11); L.scatter((x0, 19, x1, 27), "=", 11)
    loc = base_loc("mm_corpse_road", "The Corpse Road", L, True, "road", "dim",
                   "Three miles of cobbled hearse road between dense grave markers, in mist at its thickest.",
                   "The road runs straight and wide enough for a hearse, and every yard of its edge is a grave. The mist sits on it like a lid.")
    loc["areas"] = [area("mile_1", "The first mile", (1, 12), (12, 18)), area("mile_2", "The second mile", (14, 12), (25, 18)), area("mile_3", "The third mile", (27, 12), (38, 18))]
    loc["spawns"] = {"default": [2, 15], "from_gate": [2, 15], "from_sepulcher": [37, 15]}
    loc["exits"] = [exit_("gate_back", (0, 15), "mm_gate", "from_corpse", "Back toward the gate"),
                    exit_("to_sepulcher", (39, 15), "mm_sepulcher", "from_road", "On to the sepulcher")]
    loc["props"] = [
        prop("mm_mile_one", (6, 15), "The first mile: the fog leans on you", kind="decor", call=MM + "road:mile1", approach=3, call_when="not flag.mm_mile1_done"),
        prop("mm_mile_three", (30, 15), "The third mile: the cold deepens", kind="decor", call=MM + "road:mile3", approach=3, call_when="not flag.mm_mile3_done"),
        prop("mm_milestone_a", (10, 14), "A mile marker, worn smooth", kind="decor", model="milestone"),
        prop("mm_milestone_b", (24, 14), "A mile marker, worn smooth", kind="decor", model="milestone"),
        prop("mm_hearse_wreck", (17, 17), "A hearse wheel, long since broken", kind="decor", model="cart_broken"),
    ]
    dress(L, loc, (1, 2, 38, 11), HEADSTONES, 22, "mm_road_n")
    dress(L, loc, (1, 19, 38, 28), HEADSTONES, 22, "mm_road_s")
    spots = spread(L, (20, 15), 12, spacing=3, min_r=5, max_r=17)
    loc["foe_spots"] = [list(c) for c in spots]
    cells = spread(L, (20, 15), 6, spacing=2, min_r=4, max_r=10)
    loc["encounters"] = [{"id": "mm_mile2", "trigger": "enter_area:mile_2", "flag": "mm_mile2_done",
        "monsters": [monster(m, c, "A shrouded, boiling out of the mist", facing="west") for m, c in zip(
            ["shrouded_devourer", "shrouded_devourer", "shrouded_reaper", "shrouded_reaper", "shrouded_whisperer", "shrouded_whisperer"], cells)]}]
    check_reach(L, (2, 15), [(39, 15), (0, 15)], "mm_corpse_road")
    return loc


# ---- the hub ------------------------------------------------------------------------------------------------------------------------
SITES = {   # exit label, hub exit cell, the site's own id, its spawn name in the hub
    "gardens": ("mm_cremation_gardens", (10, 0), "Y5 north-west: the Cremation Gardens"),
    "crypts": ("mm_highborn_crypts", (38, 0), "Y4 north-east: the Highborn Crypts"),
    "potters": ("mm_potters_field", (49, 22), "Y6 east: the Potter's Field"),
    "mounds": ("mm_burial_mounds", (49, 38), "Y8 south-east: the Burial Mounds"),
    "kings": ("mm_kings_rest", (25, 49), "Y10 south: King's Rest"),
    "stones": ("mm_shadestone_sanctuary", (10, 49), "Y9 south-west: the Shadestone Stones"),
    "lanes": ("mm_mausoleum_lanes", (0, 18), "Y7 west: the Mausoleum Lanes"),
}
SCONCES = [("crimson", (19, 25)), ("violet", (21, 25)), ("amber", (23, 25)), ("magenta", (27, 25)), ("emerald", (29, 25)), ("azure", (31, 25))]
FLAMES = {"crimson": "", "violet": "violet", "amber": "", "magenta": "violet", "emerald": "bile", "azure": "frost"}


def sepulcher():
    w, h = 50, 50
    L = Land(w, h, 1903)
    L.hill(25, 21, 24, 6).smooth()
    L.border("#")
    for key, (_lid, (x, y), _lab) in SITES.items():
        L.put(x, y, ".")
    L.put(0, 34, ".")
    L.rect(17, 12, 33, 22, "#")                                   # the great sepulcher's base
    L.rect(24, 22, 26, 22, ".")                                   # the double doors
    L.blob(10, 40, 8, 5, "~", only="."); L.blob(40, 10, 8, 5, "~", only="."); L.blob(38, 30, 6, 6, "~", only=".")
    L.hold((25, 23), (25, 25), (24, 26), (26, 26), (10, 1), (38, 1), (48, 22), (48, 38), (25, 48), (10, 48), (1, 18), (1, 34), r=2)
    for cx, cy in [(10, 1), (38, 1), (48, 22), (48, 38), (25, 48), (10, 48), (1, 18), (1, 34)]:
        L.hold((cx, cy), r=2)
    for sc in SCONCES:
        L.hold(sc[1], r=1)
    for x0, y0, x1, y1 in ((2, 2, 15, 15), (35, 2, 47, 12), (36, 16, 47, 30), (2, 20, 14, 31), (36, 32, 47, 46), (2, 36, 20, 47), (22, 36, 34, 47), (14, 27, 36, 34)):
        L.scatter((x0, y0, x1, y1), "=", 10)
    loc = base_loc("mm_sepulcher", "The Great Sepulcher", L, True, "wilderness", "dim",
                   "A cracked, moss-grown tomb on a hilltop, with seven paved paths and two lanterns burning at its doors.",
                   "The sepulcher squats on its hill like a dropped crown. Six iron sconces stand above its great doors, five of them dark and one burning azure, and the fog parts around the glow of two lanterns held to the seam.",
                   rest="risky")
    loc["areas"] = [area("doors", "The great doors", (18, 23), (32, 28)), area("ring", "The ringing road", (1, 1), (48, 48)), area("hill_top", "The hilltop", (14, 10), (36, 30))]
    loc["spawns"] = {"default": [3, 34], "from_road": [3, 34], "from_below": [25, 24]}
    for key, (lid, (x, y), lab) in SITES.items():
        inward = (x if x not in (0, w - 1) else (1 if x == 0 else w - 2), y if y not in (0, h - 1) else (1 if y == 0 else h - 2))
        loc["spawns"]["from_" + key] = list(inward)
    loc["exits"] = [exit_("corpse_road", (0, 34), "mm_corpse_road", "from_sepulcher", "Back down the Corpse Road")]
    for key, (lid, (x, y), lab) in SITES.items():
        loc["exits"].append(exit_("path_" + key, (x, y), lid, "from_hub", f"The paved path: {lab}"))
    loc["exits"].append(exit_("doors_in", (25, 22), "mm_balefire_chamber", "from_doors", "Through the great doors", when="flag.sepulcher_open",
                              locked_text="The doors hold shut, six sconces above them, only one of them lit."))
    loc["props"] = [
        prop("mm_sepulcher_face", (25, 21), "The great double doors, sealed", kind="decor", model="great_doors", scale=1.4, facing="south"),
        prop("mm_lantern_yorgrim", (23, 26), "The gravedigger's lantern", kind="decor", model="lantern_stand"),
        prop("mm_lantern_isolde", (27, 26), "The hound's hooded lantern", kind="decor", model="lantern_stand"),
        prop("mm_hub_fog", (25, 30), "The sepulcher's hill, and the seven paths", kind="decor", call=MM + "yorgrim:arrive", approach=7,
             call_when="not flag.yorgrim_met"),
    ]
    for color, cell in SCONCES:
        if color == "azure":
            loc["props"].append(prop("mm_sconce_azure", cell, "An azure sconce, burning", kind="decor", model="brazier", flame="frost"))
        else:
            loc["props"].append(prop(f"mm_sconce_{color}_dark", cell, f"A dark sconce ({color.capitalize()})", kind="decor", model="brazier_cold", when=f"not flag.beacon_{color}"))
            loc["props"].append(prop(f"mm_sconce_{color}_lit", cell, f"A {color} sconce, burning", kind="decor", model="brazier", flame=FLAMES[color], when=f"flag.beacon_{color}"))
    for i, (x, y) in enumerate([(14, 20), (14, 28), (36, 20), (36, 28), (20, 9), (30, 9)]):
        loc["props"].append(prop(f"mm_hub_statue_{i}", (x, y), "A weeping stone figure", kind="decor", model="statue_saint"))
    dress(L, loc, (2, 2, 47, 47), HEADSTONES, 38, "mm_hub_stone")
    loc["npcs"] = [
        npc("yorgrim", (24, 26), "yorgrim:meet", when="not flag.yorgrim_met"),
        npc("isolde", (26, 26), "isolde:door", when="not flag.isolde_faded and not flag.sepulcher_open"),
        npc("yorgrim", (24, 26), "yorgrim:at_the_doors", when="flag.yorgrim_met and not flag.sepulcher_open and not flag.yorgrim_with_party"),
        npc("yorgrim", (24, 26), "yorgrim:doors_open", when="flag.sepulcher_open and not flag.yorgrim_descends"),
    ]
    loc["encounters"] = [{"id": "mm_lurkers", "trigger": "flag:mm_isolde_lurkers", "flag": "mm_lurkers_done", "when": "flag.isolde_faded and not flag.sepulcher_open",
                          "monsters": [monster(m, c, "A shrouded that slipped the door", facing="south") for m, c in zip(
                              ["shrouded_devourer", "shrouded_reaper", "shrouded_whisperer"], [(22, 31), (25, 33), (28, 31)])]}]
    for pt in [(25, 23), (25, 27), (3, 34), (10, 1), (38, 1), (48, 22), (48, 38), (25, 48), (10, 48), (1, 18)]:
        L.clear(pt)
    loc["map"]["rows"] = L.rows()
    check_reach(L, (3, 34), [(10, 0), (38, 0), (49, 22), (49, 38), (25, 49), (10, 49), (0, 18), (25, 22), (24, 26)], "mm_sepulcher")
    return loc


# ---- the gravestone shortcuts --------------------------------------------------------------------------------------------------------
HORDES = [   # (encounter id, name, [(monster, count)])
    ("mm_horde_wights", "Wights and warhorse skeletons", [("wight", 4), ("warhorse_skeleton", 4)]),
    ("mm_horde_spawn", "A vampire spawn and its specters", [("vampire_spawn", 1), ("specter", 6)]),
    ("mm_horde_minotaurs", "Minotaur skeletons", [("minotaur_skeleton", 6)]),
    ("mm_horde_ghasts", "Ghasts and ghouls", [("ghast", 2), ("ghoul", 4)]),
    ("mm_horde_wraith", "A wraith and will-o'-wisps", [("wraith", 1), ("will_o_wisp", 3)]),
    ("mm_horde_mummies", "Mummies and shadows", [("mummy", 3), ("shadow", 3)]),
    ("mm_horde_ogres", "Ogre zombies and zombies", [("ogre_zombie", 3), ("zombie", 8)]),
    ("mm_horde_ghost", "A ghost and a crowd of skeletons", [("ghost", 1), ("skeleton", 12)]),
]


def gravestones(key, seed, west, east, hordes, labels):
    """An endless-gravestone shortcut: 56 x 30 hills of markers, four fight spots along the winding way between two sites."""
    w, h = 56, 30
    L = Land(w, h, seed)
    L.hill(14, 14, 16, 3).hill(42, 15, 16, 3).smooth()
    L.border("#")
    L.rect(0, 13, w - 1, 17, ".")                                  # the way through, wide
    L.blob(14, 8, 8, 4, "~", only="."); L.blob(40, 22, 9, 4, "~", only=".")
    L.hold((0, 15), (w - 1, 15), (2, 15), (w - 3, 15), r=2)
    for x0 in range(2, w - 8, 9):
        L.scatter((x0, 2, x0 + 8, 11), "=", 8); L.scatter((x0, 19, x0 + 8, 27), "=", 8)
    loc = base_loc(f"mm_gravestones_{key}", f"The Endless Gravestones ({key.upper()})", L, True, "road", "dim",
                   "Rolling hills of grave markers a few feet apart, a shortcut that always brings a fight.",
                   "The markers crowd so close the path is a suggestion. Something is always walking between them.")
    xs = [(9, 17), (18, 26), (29, 37), (40, 48)]
    loc["areas"] = [area(f"zone_{i + 1}", f"Gravestones, stretch {i + 1}", (xa, 11), (xb, 19)) for i, (xa, xb) in enumerate(xs)]
    loc["spawns"] = {"default": [2, 15], f"from_{west}": [2, 15], f"from_{east}": [w - 3, 15]}
    loc["exits"] = [exit_(f"to_{west}", (0, 15), SITE_BY_KEY[west], "from_" + key, f"Back to {labels[0]}"),
                    exit_(f"to_{east}", (w - 1, 15), SITE_BY_KEY[east], "from_" + key, f"On to {labels[1]}")]
    loc["props"] = [prop(f"mm_gs_{key}_note", (4, 14), "A marker with your own name begun on it", kind="decor", model="gravestone")]
    dress(L, loc, (1, 2, w - 2, 11), HEADSTONES, 26, f"mm_gs{key}_n")
    dress(L, loc, (1, 19, w - 2, 28), HEADSTONES, 26, f"mm_gs{key}_s")
    spots = spread(L, (28, 15), 12, spacing=3, min_r=6, max_r=26)
    loc["foe_spots"] = [list(c) for c in spots]
    for i, ((eid, ename, group), (xa, xb)) in enumerate(zip(hordes, xs)):
        n = sum(c for _m, c in group)
        centre = ((xa + xb) // 2, 15)
        cells = spread(L, centre, n, spacing=2, min_r=3, max_r=12)
        mons, k = [], 0
        for m, c in group:
            for _ in range(c):
                mons.append(monster(m, cells[k], facing="west"))
                k += 1
        loc["encounters"].append({"id": eid, "trigger": f"enter_area:zone_{i + 1}", "flag": eid + "_done", "monsters": mons})
    check_reach(L, (2, 15), [(w - 1, 15)], f"mm_gravestones_{key}")
    return loc


SITE_BY_KEY = {k: v[0] for k, v in SITES.items()}
SITE_BY_KEY.update({"gardens": "mm_cremation_gardens", "crypts": "mm_highborn_crypts", "potters": "mm_potters_field", "mounds": "mm_burial_mounds"})


# ---- the five beacon sites ---------------------------------------------------------------------------------------------------------------
def rite_exits(loc, key, hub_cell_edge, short=None):
    """The site's way back to the hub (at hub_cell_edge, on the map edge) and, if given, its gravestone shortcut."""
    loc["spawns"]["from_hub"] = list(hub_cell_edge[1])
    loc["exits"].append(exit_("hub_path", hub_cell_edge[0], "mm_sepulcher", "from_" + key, "The paved path back to the sepulcher"))
    if short:
        sk, scell, slabel = short
        loc["exits"].append(exit_("short_" + sk, scell, f"mm_gravestones_{sk}", "from_" + key, slabel))


def highborn_crypts():
    w, h = 24, 28
    L = Land(w, h, 1904)
    L.hill(12, 14, 12, 2).smooth()
    L.border("#")
    L.put(12, 27, "."); L.put(23, 13, ".")
    for (x0, y0, x1, y1) in ((2, 3, 7, 8), (16, 3, 21, 8), (2, 18, 7, 23), (16, 18, 21, 23)):
        L.rect(x0, y0, x1, y1, "#")                              # crypts of polished dark stone
    L.rect(10, 3, 13, 6, "#")                                    # the great crypt wall
    L.blob(12, 14, 3, 3, ".")                                    # the brazier circle
    L.hold((12, 26), (22, 13), (12, 14), (12, 9), (5, 9), (18, 9), (5, 17), r=1)
    for x, y in ((5, 9), (18, 9), (5, 17), (18, 17), (12, 9)):
        L.put(x, y, ".")
    L.scatter((1, 10, 22, 26), "=", 12)
    loc = base_loc("mm_highborn_crypts", "The Highborn Crypts", L, True, "wilderness", "dim",
                   "Crypts of polished dark stone round small iron-fenced courtyards, with a brazier of dull red coals at the heart.",
                   "Family names stand over the crypt doors in letters as sharp as the gargoyles' teeth. Bats turn in the grey above, and a brazier of dull red coals waits at the centre.")
    loc["areas"] = [area("courtyard", "The brazier courtyard", (9, 11), (15, 17)), area("fronts", "The crypt fronts", (1, 9), (22, 10)), area("path", "The path in", (8, 18), (16, 26))]
    loc["spawns"] = {"default": [12, 25]}
    rite_exits(loc, "crypts", ((12, 27), (12, 25)), ("a", (23, 13), "Across the Endless Gravestones to the Cremation Gardens"))
    loc["spawns"]["from_a"] = [21, 13]
    loc["props"] = [
        prop("mm_brazier_crimson", (12, 14), "The brazier of dull red coals", kind="decor", model="brazier_cold", call=MM + "rites:crimson_start", approach=3, call_when="not flag.beacon_crimson"),
        prop("mm_brazier_crimson_lit", (12, 14), "The Crimson Beacon, burning", kind="decor", model="brazier", when="flag.beacon_crimson"),
        prop("mm_crimson_stone", (12, 10), "A crypt wall with suns and roses worked into it", model="relief", call=MM + "sites:crypt_study", approach=3),
        prop("mm_crypt_a", (5, 9), "A crypt door, a basin at its foot", model="door_double", call=MM + "sites:crypt_wrong_a"),
        prop("mm_crypt_b", (18, 9), "A crypt door, a basin at its foot", model="door_double", call=MM + "sites:crypt_right"),
        prop("mm_crypt_c", (5, 17), "A crypt door, a basin at its foot", model="door_double", call=MM + "sites:crypt_wrong_c"),
        prop("mm_crypt_d", (18, 17), "A crypt door with a rusted lock", model="door_double", kind="decor"),
        prop("mm_yorgrim_site_crypts", (13, 22), "The lantern's edge", kind="decor", call=MM + "yorgrim:site_crypts", approach=4, call_when="flag.yorgrim_with_party and not flag.mm_site_crypts_told"),
    ]
    for i, (x, y) in enumerate([(3, 10), (20, 10), (3, 24), (20, 24)]):
        loc["props"].append(prop(f"mm_gargoyle_{i}", (x, y), "A leering gargoyle", kind="decor", model="gargoyle"))
    dress(L, loc, (1, 11, 22, 26), HEADSTONES, 12, "mm_crypts_stone")
    loc["encounters"] = rite_fights("crimson", [("night_creature", 5)], ("ghoul", 1), (12, 14), L)
    loc["map"]["rows"] = L.rows()
    check_reach(L, (12, 25), [(12, 27), (23, 13), (12, 13), (5, 9), (18, 9), (5, 17)], "mm_highborn_crypts")
    return loc


def rite_fights(color, base, extra, centre, L, extra_n=1, reinf_name=None):
    """The guardians of a rite, in three versions: 0, 1 or 2+ failed searches (each adds `extra` x extra_n, up to two failures)."""
    cells = spread(L, centre, sum(c for _m, c in base) + 2 * extra_n * extra[1], spacing=2, min_r=3, max_r=12)
    out = []
    for fails in (0, 1, 2):
        mons, k = [], 0
        for m, c in base:
            for _ in range(c):
                mons.append(monster(m, cells[k], facing="south"))
                k += 1
        for _ in range(fails * extra_n * extra[1]):
            mons.append(monster(extra[0], cells[k], reinf_name or "Roused by the failed search", facing="south"))
            k += 1
        cond = {0: f"not flag.mm_{color}_fails", 1: f"flag.mm_{color}_fails == 1", 2: f"flag.mm_{color}_fails >= 2"}[fails]
        out.append({"id": f"mm_{color}_rite", "trigger": "dialogue", "when": cond, "flag": f"mm_{color}_guardians_dead", "monsters": mons,
                    "round_events": rite_effect(color)})
    return out


def rite_effect(color):
    ev = {
        "crimson": {"id": "gargoyle_fear", "name": "Grotesque Gargoyles", "summary": "The gargoyles leer, and fear takes whoever sees them.", "kind": "save", "affects": "party",
                    "save": {"ability": "wis", "dc": 15}, "condition": "frightened", "until": "target_turn_end", "at": 20, "every": 1,
                    "say": "The gargoyles seem to lean in, and every shadow has teeth."},
        "violet": {"id": "death_knell", "name": "Death Knell", "summary": "A bell tolls from nowhere and the living feel it in their bones.", "kind": "save", "affects": "party",
                   "save": {"ability": "wis", "dc": 15}, "half": True, "damage": {"dice": "2d12", "type": "necrotic"}, "at": 20, "every": 1,
                   "say": "A bell tolls once, low and wet, from no tower in sight."},
        "amber": {"id": "dancing_lanterns", "name": "Dancing Lanterns", "summary": "Amber lights bob in the fog and call to whoever follows them.", "kind": "save", "affects": "party",
                  "save": {"ability": "wis", "dc": 15}, "condition": "charmed", "until": "target_turn_end", "at": 20, "every": 1,
                  "say": "Amber lanterns bob in the fog, and the fog wants you to follow."},
        "magenta": {"id": "jinxed_flame", "name": "Jinxed Flame", "summary": "The pink flame throws a jinx on whoever stands in its light.", "kind": "save", "affects": "party",
                    "save": {"ability": "cha", "dc": 15}, "condition": "frightened", "until": "target_turn_end", "at": 20, "every": 1,
                    "say": "The pink flame spits, and somebody's luck runs out."},
        "emerald": {"id": "corpse_roots", "name": "Corpse Roots", "summary": "Roots rise from the burial mounds and tie up whoever stands near.", "kind": "save", "affects": "party",
                    "save": {"ability": "str", "dc": 15}, "condition": "restrained", "until": "target_turn_end", "at": 20, "every": 1,
                    "say": "Roots with bone in them break the earth and reach."},
    }[color]
    return [ev]


def cremation_gardens():
    w, h = 24, 28
    L = Land(w, h, 1905)
    L.hill(12, 14, 12, 1).smooth()
    L.border("#")
    L.put(12, 27, "."); L.put(1, 14, ".")
    L.blob(12, 14, 3, 3, ".")
    for (cx, cy) in ((6, 7), (18, 7), (6, 21), (18, 21)):
        L.rect(cx - 1, cy - 1, cx + 1, cy + 1, ".")
    L.hold((12, 26), (2, 14), (12, 14), (6, 7), (18, 7), (6, 21), (18, 21), (12, 6), r=1)
    L.scatter((1, 2, 22, 26), "=", 14)
    loc = base_loc("mm_cremation_gardens", "The Cremation Gardens", L, True, "wilderness", "dim",
                   "Brick-paved memorial walks lined with clay urns, a fountain at every circle, purple and white flowers in the rain.",
                   "Rain falls steadily on the urns and a bell tolls somewhere beyond the hedges. Fountains burble at the walk's circles, and a brazier of purple coals waits beside the middle one.")
    loc["map"]["light"] = "dim"
    loc["areas"] = [area("brazier_circle", "The brazier circle", (9, 11), (15, 17)), area("urn_walks", "The urn walks", (1, 2), (22, 10)), area("path", "The path in", (8, 18), (16, 26))]
    loc["spawns"] = {"default": [12, 25]}
    rite_exits(loc, "gardens", ((12, 27), (12, 25)), ("a", (0, 14), "Across the Endless Gravestones to the Highborn Crypts"))
    loc["spawns"]["from_a"] = [1, 14]
    loc["props"] = [
        prop("mm_brazier_violet", (12, 14), "A brazier of purple coals by the fountain", kind="decor", model="brazier_cold", call=MM + "rites:violet_start", approach=3, call_when="not flag.beacon_violet"),
        prop("mm_brazier_violet_lit", (12, 14), "The Violet Beacon, burning", kind="decor", model="brazier", flame="violet", when="flag.beacon_violet"),
        prop("mm_fountain_a", (6, 7), "A wishing fountain", model="stone_font", call=MM + "sites:fountain", approach=2),
        prop("mm_fountain_b", (18, 7), "A wishing fountain", model="stone_font", call=MM + "sites:fountain", approach=2),
        prop("mm_urn_study", (12, 6), "A row of mourning urns", model="relics", call=MM + "sites:urn_study", approach=3),
        prop("mm_urn_a", (6, 21), "A tall clay urn, humming", model="relics", call=MM + "sites:urn_wrong_a"),
        prop("mm_urn_b", (18, 21), "A tall clay urn, silent", model="relics", call=MM + "sites:urn_right"),
        prop("mm_urn_c", (18, 7), "A tall clay urn, humming", model="relics", kind="decor"),
        prop("mm_urn_d", (6, 24), "A tall clay urn, humming", model="relics", call=MM + "sites:urn_wrong_c"),
        prop("mm_lavender_bed", (3, 3), "A bed of lavender", model="garden_bed", call=MM + "sites:lavender", approach=2),
        prop("mm_lilies_bed", (20, 3), "A bed of white lilies", model="garden_bed", call=MM + "sites:lilies", approach=2),
        prop("mm_yorgrim_site_gardens", (13, 22), "The lantern's edge", kind="decor", call=MM + "yorgrim:site_gardens", approach=4, call_when="flag.yorgrim_with_party and not flag.mm_site_gardens_told"),
    ]
    dress(L, loc, (1, 9, 22, 26), [("relics", "A memorial urn, ash-grey", "="), ("garden_bed", "A bed of flowers gone to seed", None), ("gravestone", "A memorial plaque in the brick", "=")], 14, "mm_gardens_urn")
    loc["encounters"] = rite_fights("violet", [("phantom_hearse", 1)], ("specter", 1), (12, 14), L, reinf_name="A specter roused by the failed search")
    loc["map"]["rows"] = L.rows()
    check_reach(L, (12, 25), [(12, 27), (1, 14), (12, 15), (6, 8), (18, 22)], "mm_cremation_gardens")
    return loc


def potters_field():
    w, h = 30, 34
    L = Land(w, h, 1906)
    L.hill(8, 10, 12, 3).hill(22, 24, 12, 3).smooth()
    L.border("#")
    L.put(0, 17, "."); L.put(29, 27, ".")
    L.blob(15, 17, 4, 4, ".")
    L.hold((1, 17), (28, 27), (15, 17), (6, 6), (24, 9), (6, 27), (14, 28), r=1)
    L.scatter((1, 1, 28, 32), "=", 40)
    L.blob(22, 6, 3, 2, "~", only=".")
    loc = base_loc("mm_potters_field", "The Potter's Field", L, True, "wilderness", "dim",
                   "Rolling hills of plain wooden posts over nameless graves, amber lights drifting through the fog.",
                   "Plain posts, no names, a thousand shallow graves, and carrion birds waiting on every second one. Amber lanterns bob in the mist, going nowhere you can follow.")
    loc["areas"] = [area("brazier_hollow", "The brazier hollow", (11, 13), (19, 21)), area("graves", "The shallow graves", (1, 1), (28, 12)), area("mass_grave", "The mass grave pit", (20, 4), (25, 8)), area("path", "The way in", (1, 15), (10, 19))]
    loc["spawns"] = {"default": [2, 17]}
    rite_exits(loc, "potters", ((0, 17), (2, 17)), ("b", (29, 27), "Across the Endless Gravestones to the Burial Mounds"))
    loc["spawns"]["from_b"] = [28, 27]
    loc["props"] = [
        prop("mm_fog_amber", (4, 17), "Amber lights, drifting in the fog", kind="decor", call=MM + "sites:amber_find", approach=4, call_when="not flag.mm_amber_found"),
        prop("mm_brazier_amber", (15, 17), "A brazier of orange coals among the graves", kind="decor", model="brazier_cold", call=MM + "rites:amber_start", approach=3, call_when="flag.mm_amber_found and not flag.beacon_amber"),
        prop("mm_brazier_amber_lit", (15, 17), "The Amber Beacon, burning", kind="decor", model="brazier", when="flag.beacon_amber"),
        prop("mm_pit_edge", (22, 6), "The edge of a mass grave", kind="decor", model="grave_open", call=MM + "sites:mass_grave", approach=2),
        prop("mm_grave_study", (8, 8), "A post the crows will not leave alone", model="crow", call=MM + "sites:grave_study", approach=3),
        prop("mm_grave_a", (6, 6), "A shallow grave under a plain post", model="grave_mound", call=MM + "sites:grave_wrong_a"),
        prop("mm_grave_b", (24, 9), "A shallow grave under a plain post", model="grave_mound", call=MM + "sites:grave_right"),
        prop("mm_grave_c", (6, 27), "A shallow grave under a plain post", model="grave_mound", call=MM + "sites:grave_wrong_c"),
        prop("mm_shovel_stand", (14, 28), "A rusted shovel, leaning on a post", kind="decor", model="tool_rack"),
        prop("mm_yorgrim_site_potters", (3, 19), "The lantern's edge", kind="decor", call=MM + "yorgrim:site_potters", approach=4, call_when="flag.yorgrim_with_party and not flag.mm_site_potters_told"),
    ]
    for i in range(7):
        loc["props"].append(prop(f"mm_crowpost_{i}", (3 + i * 4, 3 + (i % 3) * 8 + 2), "A crow on a post", kind="decor", model="crow"))
    dress(L, loc, (1, 1, 28, 32), [("grave_mound", "A shallow grave", "="), ("stump", "A plain wooden post", "="), ("bones", "Bones, picked clean", None)], 26, "mm_potters_post")
    loc["encounters"] = rite_fights("amber", [("kackle", 2)], ("specter", 1), (15, 17), L, reinf_name="A specter roused by the failed search")
    loc["map"]["rows"] = L.rows()
    check_reach(L, (2, 17), [(0, 17), (29, 27), (15, 18), (4, 17)], "mm_potters_field")
    return loc


def mausoleum_lanes():
    w, h = 24, 34
    L = Land(w, h, 1907)
    L.hill(12, 17, 14, 1).smooth()
    L.border("#")
    L.put(23, 17, "."); L.put(12, 33, ".")
    for lane_x in (3, 8, 15, 20):                                # long lanes of small ivy-grown vaults
        L.rect(lane_x - 1, 2, lane_x + 1, 12, "#")
        L.rect(lane_x - 1, 22, lane_x + 1, 31, "#")
    L.rect(1, 13, 22, 21, ".")
    L.blob(12, 17, 5, 3, "~")                                    # acrid muck on the tiles
    L.blob(4, 27, 2, 2, "~", only="."); L.blob(19, 4, 2, 2, "~", only=".")
    L.rect(11, 19, 13, 21, ".")
    L.hold((23, 17), (12, 33), (12, 17), (3, 13), (8, 13), (15, 13), (20, 13), (3, 21), (8, 21), (15, 21), (20, 21), r=1)
    loc = base_loc("mm_mausoleum_lanes", "The Mausoleum Lanes", L, True, "riverside", "dim",
                   "A boggy city of small ivy-grown vaults, murky water in the tile cracks, a brazier of pink coals at the end of a sunken lane.",
                   "A fen has crept into the dead city. Water seeps between the tiles, moss hangs from gnarled trees, and every vault door is carved with a ship, a sea or a spiral.")
    loc["areas"] = [area("sunken_lane", "The sunken lane", (8, 14), (16, 21)), area("vault_rows", "The vault rows", (1, 2), (22, 12)), area("south_rows", "The southern vaults", (1, 22), (22, 31)), area("muck", "The acrid muck", (9, 14), (15, 20))]
    loc["spawns"] = {"default": [22, 17], "from_hub": [22, 17]}
    loc["exits"] = [exit_("hub_path", (23, 17), "mm_sepulcher", "from_lanes", "The paved path back to the sepulcher")]
    L.rect(11, 22, 13, 31, ".")
    loc["props"] = [
        prop("mm_brazier_magenta", (12, 17), "A brazier of pink coals beside a mossy tree", kind="decor", model="brazier_cold", call=MM + "rites:magenta_start", approach=3, call_when="not flag.beacon_magenta"),
        prop("mm_brazier_magenta_lit", (12, 17), "The Magenta Beacon, burning", kind="decor", model="brazier", flame="violet", when="flag.beacon_magenta"),
        prop("mm_muck_edge", (12, 15), "Acrid muck on the tiles", kind="decor", call=MM + "sites:muck", approach=2, call_when="not flag.mm_magenta_muck_done"),
        prop("mm_vault_study", (8, 13), "Vault doors carved with ships and spirals", model="relief", call=MM + "sites:vault_study", approach=3),
        prop("mm_vault_a", (3, 13), "A vault door with a hex glyph", model="door_double", call=MM + "sites:vault_wrong_a"),
        prop("mm_vault_b", (15, 21), "A vault door with a hex glyph", model="door_double", call=MM + "sites:vault_right"),
        prop("mm_vault_c", (20, 13), "A vault door with a hex glyph", model="door_double", call=MM + "sites:vault_wrong_c"),
        prop("mm_moth_vault", (8, 21), "A small vault, its door ajar", model="door_double", call=MM + "sites:moth_vault", approach=2, call_when="not flag.mm_moth_taken"),
        prop("mm_yorgrim_site_lanes", (12, 28), "The lantern's edge", kind="decor", call=MM + "yorgrim:site_lanes", approach=4, call_when="flag.yorgrim_with_party and not flag.mm_site_lanes_told"),
    ]
    for i, (x, y) in enumerate([(2, 14), (10, 14), (22, 14), (2, 20), (22, 20), (10, 30), (14, 30)]):
        loc["props"].append(prop(f"mm_lane_tree_{i}", (x, y), "A gnarled tree hung with moss", kind="decor", model="dead_tree_a"))
        L.put(x, y, "#")
    dress(L, loc, (1, 2, 22, 31), [("barrel", "A sunken vault slab", "="), ("vines", "Ivy over a vault door", None), ("bones", "A scatter of old bones", None)], 10, "mm_lanes_dress")
    loc["encounters"] = rite_fights("magenta", [("dream_eater", 1)], ("mud_mephit", 2), (12, 17), L, extra_n=1, reinf_name="A mud mephit roused by the failed search")
    for i in (0, 1, 2):
        pass
    loc["map"]["rows"] = L.rows()
    check_reach(L, (22, 17), [(12, 18), (3, 13), (15, 21), (20, 13), (8, 21), (12, 28)], "mm_mausoleum_lanes")
    return loc


def burial_mounds():
    w, h = 30, 30
    L = Land(w, h, 1908)
    L.hill(6, 8, 7, 4).hill(24, 10, 7, 4).hill(8, 23, 7, 3).hill(15, 15, 6, 5).smooth()
    L.border("#")
    L.put(0, 26, "."); L.put(29, 15, ".")
    L.blob(15, 15, 4, 4, ".")
    L.hold((1, 26), (28, 15), (15, 15), (6, 8), (24, 10), (8, 23), r=1)
    L.scatter((1, 1, 28, 28), "#", 30, gap=2)                    # twisted trees with faces
    for (x, y) in ((15, 15), (6, 8), (24, 10), (8, 23), (1, 26), (28, 15)):
        L.clear((x, y))
    L.blob(21, 22, 2, 2, "~", only=".")
    loc = base_loc("mm_burial_mounds", "The Burial Mounds", L, True, "forest", "dim",
                   "Tall round mounds packed close, a grove of twisted trees with faces in their trunks, a brazier of green coals on a mound.",
                   "Barrows rise on every side, grassed over and silent. The trees between them have faces, and bright apples hang from branches shaped like hands.")
    loc["areas"] = [area("brazier_mound", "The brazier mound", (11, 11), (19, 19)), area("mounds", "The mounds", (1, 1), (28, 10)), area("grove", "The face-tree grove", (1, 20), (28, 28)), area("toadstools", "The toadstool ring", (19, 20), (24, 25))]
    loc["spawns"] = {"default": [2, 26]}
    rite_exits(loc, "mounds", ((0, 26), (2, 26)), ("b", (29, 15), "Across the Endless Gravestones to the Potter's Field"))
    loc["spawns"]["from_b"] = [28, 15]
    loc["props"] = [
        prop("mm_fog_green", (4, 25), "Mist hiding the way through the mounds", kind="decor", call=MM + "sites:emerald_find", approach=4, call_when="not flag.mm_emerald_found"),
        prop("mm_brazier_emerald", (15, 15), "A brazier of green coals atop a mound", kind="decor", model="brazier_cold", call=MM + "rites:emerald_start", approach=3, call_when="flag.mm_emerald_found and not flag.beacon_emerald"),
        prop("mm_brazier_emerald_lit", (15, 15), "The Emerald Beacon, burning", kind="decor", model="brazier_green", flame="bile", when="flag.beacon_emerald"),
        prop("mm_apple_tree", (21, 20), "A face-tree with bright apples on hand-shaped branches", model="tree_marked", call=MM + "sites:apple_tree", approach=2),
        prop("mm_toad_ring", (21, 23), "A ring of colourful toadstools", kind="decor", model="vines", call=MM + "sites:toadstool_ring", approach=2, call_when="flag.mm_emerald_ring_ready and not flag.mm_ring_done"),
        prop("mm_mound_study", (4, 6), "The tree with the Green Queen's face", model="tree_marked", call=MM + "sites:mound_study", approach=3),
        prop("mm_mound_a", (6, 8), "A barrow mouth packed with earth", model="barrow", call=MM + "sites:mound_wrong_a"),
        prop("mm_mound_b", (24, 10), "A barrow mouth packed with earth", model="barrow", call=MM + "sites:mound_right"),
        prop("mm_mound_c", (8, 23), "A barrow mouth packed with earth", model="barrow", call=MM + "sites:mound_wrong_c"),
        prop("mm_nightshade", (27, 25), "Nightshade, in flower", model="garden_bed", call=MM + "sites:nightshade", approach=2, call_when="not flag.mm_nightshade_taken"),
        prop("mm_carve_tree", (13, 21), "A tree grown thick round a name", kind="decor", model="tree_marked", call=MM + "sites:carve_tree", approach=2, call_when="flag.mem_farryn_greenwood and not flag.mm_greenwood_carved"),
        prop("mm_yorgrim_site_mounds", (3, 24), "The lantern's edge", kind="decor", call=MM + "yorgrim:site_mounds", approach=4, call_when="flag.yorgrim_with_party and not flag.mm_site_mounds_told"),
    ]
    dress(L, loc, (1, 1, 28, 28), [("grave_mound", "A grassed-over mound", "="), ("boulder_a", "A moss-covered stone", "="), ("bramble_a", "Brambles", "~")], 14, "mm_mounds_dress")
    loc["encounters"] = rite_fights("emerald", [("gloomwood", 1)], ("violet_fungus", 2), (15, 15), L, reinf_name="A violet fungus roused by the failed search")
    loc["map"]["rows"] = L.rows()
    check_reach(L, (2, 26), [(0, 26), (29, 15), (15, 16), (6, 9), (24, 11), (8, 24)], "mm_burial_mounds")
    return loc


# ---- the crypt below, the sanctuary, King's Rest ----------------------------------------------------------------------------------------
def crypt_below():
    w, h = 14, 14
    L = Land(w, h, 1909, base="#")
    L.rect(1, 1, 12, 12, ".")
    for x in (3, 4, 9, 10):
        L.put(x, 4, "="); L.put(x, 8, "=")
    L.put(6, 13, ".")
    loc = base_loc("mm_crypt_below", "A Highborn Crypt, below", L, False, "dungeon", "dark",
                   "A stair down to a low chamber of stone sarcophagi, bats roosting on the ceiling.", "Cold air, sarcophagi in rows, and the sound of wings settling.")
    loc["areas"] = [area("chamber", "The sarcophagus chamber", (1, 1), (12, 12))]
    loc["spawns"] = {"default": [6, 11], "from_stair": [6, 11]}
    loc["exits"] = [exit_("stair_up", (6, 13), "mm_highborn_crypts", "from_hub", "Up the stair, to the courtyard")]
    loc["exits"][0]["spawn"] = "from_crypt"
    loc["props"] = [
        prop("mm_rose_sarcophagus", (6, 3), "A sarcophagus with a dried red rose on its lid", model="coffin", call=MM + "sites:rose_take", approach=3, call_when="not flag.mm_rose_taken"),
        prop("mm_sarcophagus_a", (3, 4), "A stone sarcophagus", kind="decor", model="coffin"),
        prop("mm_sarcophagus_b", (10, 4), "A stone sarcophagus", kind="decor", model="coffin"),
        prop("mm_sarcophagus_c", (3, 8), "A stone sarcophagus", kind="decor", model="coffin"),
        prop("mm_sarcophagus_d", (10, 8), "A stone sarcophagus", kind="decor", model="coffin"),
        prop("mm_bats_roost", (6, 1), "Roosting bats", kind="decor", model="bat_perch"),
    ]
    loc["rest"] = "risky"
    return loc


def sanctuary():
    w, h = 30, 30
    L = Land(w, h, 1910)
    L.hill(15, 14, 14, 2).smooth()
    L.border("#")
    L.put(0, 15, ".");
    L.rect(11, 9, 18, 16, "1")                                   # the stepped ziggurat, three rises
    L.rect(12, 10, 17, 15, "2")
    L.rect(13, 11, 16, 14, "3")
    L.hold((1, 15), (14, 17), (15, 17), (14, 18), r=2)
    L.scatter((1, 1, 28, 8), "=", 6); L.scatter((1, 19, 28, 28), "=", 8)
    loc = base_loc("mm_shadestone_sanctuary", "The Shadestone Sanctuary", L, True, "wilderness", "dim",
                   "Tall carved standing stones covered in Orc names before a small stepped ziggurat, an azure beacon on its crown.",
                   "The air here is still and clean. Names are cut into the standing stones from root to crown, and an azure fire burns on top of the little ziggurat as if it had never gone out.",
                   rest="safe", rest_text="Azure light and a stillness the rest of the cemetery has lost.")
    loc["areas"] = [area("stones", "The standing stones", (1, 1), (28, 8)), area("ziggurat", "The ziggurat", (11, 9), (18, 16)), area("chamber_of_rest", "The chamber of rest", (13, 11), (16, 14))]
    loc["spawns"] = {"default": [3, 15], "from_hub": [2, 15]}
    loc["exits"] = [exit_("hub_path", (0, 15), "mm_sepulcher", "from_stones", "The paved path back to the sepulcher")]
    loc["props"] = [
        prop("mm_beacon_azure", (15, 12), "The azure beacon", kind="decor", model="brazier", flame="frost"),
        prop("mm_clan_stones", (14, 20), "The standing stones, cut with Orc names", model="standing_stones", call=MM + "yorgrim:clan_stones", approach=4, call_when="not flag.yorgrim_told_story"),
        prop("mm_clan_study", (6, 12), "A stone with names in a script you almost know", model="names_wall", call=MM + "sites:clan_study", approach=2),
        prop("mm_shovel_slab", (14, 13), "A slab with a shovel laid across it", kind="search", search_dc=5, item="shovel_of_yorgrim", when="treasure_at:shadestone_chamber_of_rest"),
        prop("mm_statue_lantern", (21, 21), "A statue of a hooded figure holding a lantern", model="statue_mother_night", call=MM + "sites:lantern_statue", approach=2),
        prop("mm_isolde_rest", (12, 18), "A place by the stones where the hound lies", kind="decor", call=MM + "isolde:rest_here", approach=3, call_when="flag.isolde_alive and flag.mm_isolde_walk_started and not flag.mm_isolde_walk_done"),
    ]
    for i in range(10):
        loc["props"].append(prop(f"mm_slab_{i}", (13 + (i % 4), 11 + (i // 4)) if False else (12 + i % 6 if i < 6 else 25, 3 + i), "A stone slab", kind="decor", model="bier"))
    for i, (x, y) in enumerate([(5, 4), (10, 4), (20, 4), (25, 4), (5, 24), (10, 24), (20, 24), (25, 24)]):
        loc["props"].append(prop(f"mm_names_stone_{i}", (x, y), "A standing stone cut with names", kind="decor", model="standing_stones"))
        L.put(x, y, "#")
    loc["map"]["rows"] = L.rows()
    # the slab props placed in the grid above may land on stone squares: put them on open squares
    check_reach(L, (3, 15), [(0, 15), (14, 12), (14, 20)], "mm_shadestone_sanctuary")
    return loc


def kings_rest():
    w, h = 30, 30
    L = Land(w, h, 1911)
    L.hill(15, 6, 14, 3).smooth()
    L.border("#")
    L.put(15, 29, ".")
    L.rect(7, 2, 22, 3, "#")                                     # the barrow's face
    L.rect(13, 3, 16, 3, ".")
    L.scatter((1, 8, 28, 26), "=", 22)
    L.hold((15, 28), (15, 24), (15, 4), r=2)
    loc = base_loc("mm_kings_rest", "King's Rest", L, True, "wilderness", "dim",
                   "An enormous palatial barrow, a giant armoured king raising a sword through the fog, huge rune-covered doors.",
                   "Past a field of wrecked iron the barrow rises, and on its roof a king of stone lifts a sword into the fog. Wights and shrouded fight at its doors, endlessly, and none of them look over.")
    loc["areas"] = [area("approach", "The approach", (1, 17), (28, 28)), area("doors", "The rune doors", (10, 2), (20, 7))]
    loc["spawns"] = {"default": [15, 27], "from_hub": [15, 27]}
    loc["exits"] = [exit_("hub_path", (15, 29), "mm_sepulcher", "from_kings", "The paved path back to the sepulcher")]
    loc["props"] = [
        prop("mm_king_statue", (15, 1), "A giant armoured king, sword raised", kind="decor", model="colossus", scale=2.4),
        prop("mm_king_doors", (15, 4), "Huge doors, rune-covered stone", model="great_doors", scale=1.8, call=MM + "road:kings_rest", approach=6, facing="south"),
    ]
    for i in range(6):
        loc["props"].append(prop(f"mm_war_{i}", (6 + i * 3, 11 + (i % 2) * 2), "Wights and shrouded, locked in a war that does not end", kind="decor", model="skeleton_shackles"))
    for i, (x, y) in enumerate([(4, 20), (25, 20), (8, 24), (22, 24)]):
        loc["props"].append(prop(f"mm_wreck_{i}", (x, y), "Broken iron and older bones", kind="decor", model="bones"))
    loc["map"]["rows"] = L.rows()
    check_reach(L, (15, 27), [(15, 29), (15, 6)], "mm_kings_rest")
    return loc


# ---- inside: the balefire chamber, the undercroft maze, the depths, the tomb ------------------------------------------------------------
def balefire_chamber():
    w, h = 20, 24
    L = Land(w, h, 1912, base="#")
    L.rect(2, 2, 17, 21, ".")
    L.rect(2, 2, 17, 4, "~")                                    # rubble and mist at the far end
    L.rect(9, 1, 10, 1, "."); L.put(9, 0, "#")
    L.put(10, 23, ".")
    loc = base_loc("mm_balefire_chamber", "The Balefire Chamber", L, False, "dungeon", "dim",
                   "The sepulcher's entry hall: a sixty-foot ceiling, sconces of coloured fire, a collapsed passage at the far end.",
                   "Six sconces down each wall burn in the colours of the beacons outside. At the far end the passage has fallen in, and grey mist wells through the rubble.")
    loc["areas"] = [area("hall", "The entry hall", (2, 5), (17, 21)), area("rubble", "The collapsed passage", (2, 2), (17, 4))]
    loc["spawns"] = {"default": [10, 21], "from_doors": [10, 21], "from_undercroft": [9, 2]}
    loc["exits"] = [exit_("doors_out", (10, 23), "mm_sepulcher", "from_below", "Out through the great doors"),
                    exit_("passage_on", (9, 1), "mm_undercroft", "from_chamber", "Through the cleared passage, down to the undercroft", when="flag.mm_rubble_cleared",
                          locked_text="Rubble fills the passage to the ceiling.")]
    loc["exits"][0]["spawn"] = "from_below"
    loc["props"] = [
        prop("mm_rubble", (10, 4), "The fallen passage, rubble to the ceiling", model="rubble", call=MM + "descent:rubble", approach=3, call_when="flag.mm_chamber_done and not flag.mm_rubble_cleared"),
        prop("mm_chamber_start", (10, 18), "The hall, and the mist at its end", kind="decor", call=MM + "descent:chamber", approach=8, call_when="not flag.mm_chamber_started"),
    ]
    colors = ["crimson", "violet", "amber", "magenta", "emerald", "azure"]
    for side, x in (("w", 2), ("e", 17)):
        for j, y in enumerate((7, 11, 15, 19)):
            c = colors[(j + (0 if side == "w" else 2)) % 6]
            loc["props"].append(prop(f"mm_chamber_sconce_{side}{j}", (x, y), f"A sconce of {c} fire", kind="decor", model="brazier", flame=FLAMES.get(c, "")))
    for i, (x, y) in enumerate([(5, 10), (14, 10), (5, 16), (14, 16)]):
        loc["props"].append(prop(f"mm_chamber_col_{i}", (x, y), "A cracked pillar", kind="decor", model="gate_pillar"))
        L.put(x, y, "=")
    L.hold((10, 23), (10, 21), (9, 1), (10, 18), (10, 5), r=1)
    for y in (22, 23):
        L.put(10, y, ".")
    loc["map"]["rows"] = L.rows()
    check_reach(L, (10, 21), [(10, 23), (9, 5)], "mm_balefire_chamber")
    return loc


def undercroft():
    cell, gw, gh = 3, 13, 13
    w = h = cell * gw + 1
    L = Land(w, h, 1913, base="#")
    rng = random.Random(1913)
    seen = {(0, 0)}
    stack = [(0, 0)]
    links = set()
    while stack:
        cx, cy = stack[-1]
        nb = [(cx + dx, cy + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= cx + dx < gw and 0 <= cy + dy < gh and (cx + dx, cy + dy) not in seen]
        if not nb:
            stack.pop()
            continue
        n = rng.choice(nb)
        seen.add(n)
        links.add(((cx, cy), n)); links.add((n, (cx, cy)))
        stack.append(n)

    def room(cxy):
        x0, y0 = cxy[0] * cell + 1, cxy[1] * cell + 1
        L.rect(x0, y0, x0 + 1, y0 + 1, ".")
        return x0, y0
    for cy in range(gh):
        for cx in range(gw):
            x0, y0 = room((cx, cy))
            if ((cx, cy), (cx + 1, cy)) in links:
                L.rect(x0 + 2, y0, x0 + 2, y0 + 1, ".")
            if ((cx, cy), (cx, cy + 1)) in links:
                L.rect(x0, y0 + 2, x0 + 1, y0 + 2, ".")
    # entrance bottom-left, stair down top-right
    ent = (1, (gh - 1) * cell + 1)
    ext = ((gw - 1) * cell + 1, 1)
    L.put(ent[0], ent[1] + 2, ".")                                # a doorway south of the first cell
    L.rect((gw - 1) * cell + 1, 0, (gw - 1) * cell + 2, 0, ".")
    # the true path
    from collections import deque
    prev, q = {(0, gh - 1): None}, deque([(0, gh - 1)])
    while q:
        cur = q.popleft()
        for (a, b) in links:
            if a == cur and b not in prev:
                prev[b] = cur
                q.append(b)
    path, cur = [], (gw - 1, 0)
    while cur is not None:
        path.append(cur)
        cur = prev[cur]
    path.reverse()
    on_path = set(path)
    # dead ends (cells with one link) off the path, for the cracked floors
    deg = {}
    for (a, _b) in links:
        deg[a] = deg.get(a, 0) + 1
    dead = [c for c, d in deg.items() if d == 1 and c not in on_path]
    rng.shuffle(dead)
    cracks = dead[:6]
    loc = base_loc("mm_undercroft", "The Undercroft Catacombs", L, False, "dungeon", "dark",
                   "A maze of earthen passages lined with rows of skulls, mist pooled on the floor, and floors that tremble.",
                   "Skulls look out of the walls in neat rows. The passages fork and fork again, and here and there the floor sounds hollow.")
    loc["areas"] = [area("maze", "The catacomb maze", (1, 1), (w - 2, h - 3))]
    loc["spawns"] = {"default": [ent[0], ent[1] + 1], "from_chamber": [ent[0], ent[1] + 1], "from_depths": [ent[0] + 3, ent[1]]}
    loc["exits"] = [exit_("back_up", (ent[0], ent[1] + 2), "mm_balefire_chamber", "from_undercroft", "Back up to the balefire chamber"),
                    exit_("stygian_stair", (ext[0], 0), "mm_tomb", "from_stair", "The stair down, carved with faces")]
    loc["exits"][0]["spawn"] = "from_undercroft"
    loc["props"] = [prop("mm_maze_hint", (ent[0] + 1, ent[1] + 1), "A dozen passages, and a feeling about the right one", kind="decor", call=MM + "descent:maze_hint", approach=3, call_when="not flag.mm_maze_hint_done")]
    for i, (cx, cy) in enumerate(cracks):
        x0, y0 = room((cx, cy))
        loc["props"].append(prop(f"mm_crack_{i}", (x0, y0), "A cracked, trembling floor", kind="decor", model="rubble", call=MM + "descent:crack", approach=1))
    for i, c in enumerate(path[1:-1:2]):
        x0, y0 = c[0] * cell + 1, c[1] * cell + 1
        loc["props"].append(prop(f"mm_trail_{i}", (x0 + 1, y0 + 1), "A skull lit from within, as if pointing", kind="decor", model="candle_cluster", when="flag.mm_maze_hint_done"))
    skulls = 0
    for (cx, cy) in [(c[0], c[1]) for c in path][::3]:
        x0, y0 = cx * cell + 1, cy * cell + 1
        loc["props"].append(prop(f"mm_skullwall_{skulls}", (x0, y0), "A wall of grinning skulls", kind="decor", model="bone_scatter"))
        skulls += 1
    loc["map"]["rows"] = L.rows()
    check_reach(L, (ent[0], ent[1] + 1), [(ext[0], 0), (ent[0], ent[1] + 2)] + [tuple(p["cell"]) for p in loc["props"] if p["id"].startswith("mm_crack")], "mm_undercroft")
    return loc


def necropolis_depths():
    w = h = 36
    L = Land(w, h, 1914, base="#")
    L.blob(18, 18, 15, 14, ".", wob=0.18)
    L.blob(8, 8, 5, 4, ".", wob=0.3); L.blob(28, 28, 5, 4, ".", wob=0.3); L.blob(30, 8, 4, 4, ".", wob=0.3)
    L.hold((18, 30), (18, 18), (6, 18), (30, 18), r=1)
    L.scatter((4, 4, 31, 31), "~", 40, gap=0)                    # rough rock formations, Difficult for Large and smaller
    for x, y in ((18, 30), (18, 18), (6, 18), (30, 18), (18, 22), (10, 12), (26, 12)):
        L.clear((x, y))
    L.rect(17, 31, 19, 33, "."); L.put(18, 34, ".")
    loc = base_loc("mm_necropolis_depths", "The Necropolis Depths", L, False, "dungeon", "dark",
                   "A huge cavern widened by claws, tunnels lined with slimed corpses, pockets of glowing Shroud-ooze.",
                   "The cave smells of wet stone and old meat. Something has dug here for a very long time, and it left its slime on everything.")
    loc["areas"] = [area("cavern", "The great cavern", (3, 3), (32, 32)), area("lair", "The necrolisk's lair", (12, 10), (24, 22))]
    loc["spawns"] = {"default": [18, 29], "from_fall": [18, 24], "from_below": [18, 32]}
    loc["exits"] = [exit_("burrow_up", (18, 34), "mm_undercroft", "from_depths", "A collapsed burrow, climbing back to the catacombs"),
                    exit_("to_descent", (30, 18), "mm_tomb", "from_below", "Through the broken wall, to the Stygian Descent", when="flag.mm_wall_broken",
                          locked_text="The wall is cracked, but whole.")]
    loc["props"] = [
        prop("mm_depths_crack", (29, 18), "A cracked wall leaking grey mist", model="rubble", call=MM + "descent:wall", approach=3, call_when="not flag.mm_wall_broken"),
        prop("mm_depths_first", (18, 27), "A broken cavern, and the smell of something large", kind="decor", call=MM + "descent:depths_arrive", approach=6, call_when="not flag.mm_depths_seen"),
    ]
    for i, (x, y) in enumerate([(10, 12), (26, 12), (12, 26), (26, 26)]):
        loc["props"].append(prop(f"mm_slime_{i}", (x, y), "A slime blob, trapping something dead", model="soul_bags", call=MM + "descent:slime", approach=2, call_when="not flag.mm_slime_all"))
    for i, (x, y) in enumerate([(6, 18), (20, 8), (8, 28), (28, 24)]):
        loc["props"].append(prop(f"mm_depths_bones_{i}", (x, y), "A slimed corpse in a burrow wall", kind="decor", model="bones"))
    cells = spread(L, (18, 16), 1, spacing=1, min_r=0, max_r=3)
    loc["encounters"] = [{"id": "mm_necrolisk", "trigger": "dialogue", "flag": "necrolisk_slain",
                          "monsters": [monster("necrolisk", (18, 14), "The necrolisk", facing="south", boss=True)]}]
    loc["map"]["rows"] = L.rows()
    check_reach(L, (18, 29), [(30, 18), (18, 34), (10, 12), (26, 12), (12, 26), (26, 26), (18, 18)], "mm_necropolis_depths")
    return loc


def tomb():
    w, h = 22, 32
    L = Land(w, h, 1915, base="#")
    L.rect(2, 1, 19, 22, ".")
    for y, (xa, xb) in {1: (5, 16), 2: (4, 17), 21: (4, 17), 22: (5, 16)}.items():
        L.rect(2, y, 19, y, "#"); L.rect(xa, y, xb, y, ".")
    L.rect(9, 23, 12, 30, ".")                                 # the long hallway of wailing faces
    L.rect(10, 31, 11, 31, ".")
    L.rect(9, 22, 12, 22, ".")
    # the first, three-pronged platform (10 ft): crossbar and three prongs; stair steps (5 ft) in front of its bar
    L.rect(6, 12, 15, 13, "2")
    for xa, xb in ((6, 7), (10, 11), (14, 15)):
        L.rect(xa, 8, xb, 11, "2")
    L.rect(7, 14, 14, 14, "1")
    # the second (20 ft), reached from the first by a step up at each prong
    L.rect(6, 5, 15, 6, "4")
    for xa, xb in ((6, 7), (10, 11), (14, 15)):
        L.rect(xa, 2, xb, 4, "4")
    for xa, xb in ((6, 7), (10, 11), (14, 15)):
        L.rect(xa, 7, xb, 7, "3")
    loc = base_loc("mm_tomb", "The Tomb of the Shrouded", L, False, "dungeon", "bright",
                   "A cavern of balefire turned Shroud-coloured: three-pronged platforms hung on giant chains under a tear in the ceiling.",
                   "Down a stair carved with a thousand screaming faces and along a hall of wailing, a hooded woman holding a lantern watches the door. Beyond it, a cavern. The air above its highest platform is torn open.")
    loc["areas"] = [area("hallway", "The hall of faces", (9, 23), (12, 30)), area("floor", "The tomb floor", (2, 15), (19, 22)), area("first", "The first platform", (6, 8), (15, 13)), area("second", "The hanging platform", (6, 2), (15, 6))]
    loc["spawns"] = {"default": [10, 30], "from_stair": [10, 30], "from_below": [10, 30], "from_tomb": [10, 19]}
    loc["exits"] = [exit_("stair_up", (10, 31), "mm_undercroft", "from_tomb", "Back up the Stygian Descent", when="not flag.mm_harrowing_begun")]
    loc["exits"][0]["spawn"] = "from_tomb"
    loc["props"] = [
        prop("mm_statue_lantern_woman", (19, 18), "A hooded woman carved in stone, holding a lantern", kind="decor", model="statue_mother_night"),
        prop("mm_descent_enter", (10, 29), "The hall of wailing faces", kind="decor", call=MM + "descent:stygian", approach=4, call_when="not flag.mm_stygian_seen"),
        prop("mm_tomb_door", (10, 24), "A door carved with a hooded woman and a lantern", model="door_carved", call=MM + "descent:tomb_door", approach=2, call_when="not flag.mm_harrowing_begun"),
        prop("mm_tear", (10, 2), "A twenty-foot tear in the air, gyrating mist", kind="decor", model="glass_ring", scale=3.0),
        prop("mm_grand_lantern", (10, 18), "A big ornate lantern left on the floor, its flame faint", model="lantern_stand", call=MM + "descent:azure_rites", approach=2, call_when="flag.chained_reaper_destroyed and not flag.shroud_tear_sealed"),
        prop("mm_lantern_item", (11, 18), "A lantern in a pool of light", kind="search", search_dc=5, item="lantern_of_the_chained_reaper", when="flag.shroud_tear_sealed and treasure_at:tomb_of_the_shrouded"),
    ]
    braz = [(3, 17), (18, 17), (3, 11), (18, 11), (4, 5), (17, 5), (7, 20), (14, 20)]
    for i, (x, y) in enumerate(braz):
        loc["props"].append(prop(f"mm_balefire_{i}", (x, y), "A brazier of corrupted balefire", kind="decor", model="brazier", flame="bile"))
        L.put(x, y, "=")
    coffins = [(6, 8), (11, 8), (15, 8), (6, 2), (11, 2), (15, 2)]
    for i, (x, y) in enumerate(coffins):
        loc["props"].append(prop(f"mm_effigy_{i}", (x, y), "A stone coffin, glowing faintly" if i < 5 else "A stone coffin, empty", kind="decor", model="coffin"))
    for i, (x, y) in enumerate([(3, 4), (18, 4), (3, 20), (18, 20)]):
        loc["props"].append(prop(f"mm_chain_{i}", (x, y), "A giant chain, vanishing upward", kind="decor", model="wall_chains"))
    for i, y in enumerate((24, 27, 30)):
        loc["props"].append(prop(f"mm_faces_{i}", (9, y), "A wall of carved, wailing faces", kind="decor", model="stone_faces"))
    loc["npcs"] = [npc("yorgrim", (10, 19), "descent:harrow_hold", when="flag.mm_harrowing_begun and not flag.chained_reaper_destroyed")]
    shr = [(5, 18), (15, 17), (10, 16)]
    loc["encounters"] = [
        {"id": "mm_harrowing", "trigger": "dialogue", "flag": "chained_reaper_destroyed", "lair": True, "quest": {"id": "maidenmist_dead_rise", "stage": "azure_rites"},
         "monsters": [monster("chained_reaper", (10, 10), "Yorgrim, the Chained Reaper", boss=True, facing="south", steps_down={"npc": "yorgrim"}),
                      monster("shrouded_devourer", shr[0], facing="east"), monster("shrouded_reaper", shr[1], facing="west"), monster("shrouded_whisperer", shr[2], facing="north")],
         "round_events": [
             {"id": "shroud_influence", "name": "Shroud Influence", "summary": "The tear acts on its own count, and never the same way twice.", "kind": "save", "affects": "party", "pick": "random", "at": 20, "every": 1,
              "table": [
                  {"id": "abominable_spirits", "name": "Abominable Spirits", "summary": "Three shrouded tear out of the mist.", "kind": "summon", "monster": "shrouded_reaper", "count": 3, "side": "enemies", "cells": [[4, 18], [16, 18], [10, 20]], "say": "Three shrouded tear out of the mist."},
                  {"id": "oppressive_gloom", "name": "Oppressive Gloom", "summary": "The tomb dims to a blur of grey.", "kind": "text", "say": "The tomb dims until your own hands are shapes."},
                  {"id": "tide_of_death", "name": "Tide of Death", "summary": "A wave of cold shoves the living back.", "kind": "save", "affects": "party", "save": {"ability": "str", "dc": 15}, "damage": {"dice": "1d6", "type": "necrotic"}, "say": "A wave of cold shoves at your chest."}]}]},
        {"id": "mm_tear_wave", "trigger": "dialogue", "flag": "mm_wave_done",
         "monsters": [monster("shrouded_devourer", (4, 17), facing="east"), monster("shrouded_reaper", (16, 17), facing="west"), monster("shrouded_whisperer", (10, 15), facing="south")]},
    ]
    loc["map"]["rows"] = L.rows()
    check_reach(L, (10, 30), [(10, 24), (10, 19), (19, 18) if False else (18, 18)], "mm_tomb")
    return loc


BUILDERS = [gate, corpse_road, sepulcher, highborn_crypts, cremation_gardens, potters_field, mausoleum_lanes, burial_mounds, crypt_below, sanctuary, kings_rest,
            balefire_chamber, undercroft, necropolis_depths, tomb]


def gravestone_pair():
    a = gravestones("a", 1916, "gardens", "crypts", HORDES[:4], ("the Cremation Gardens", "the Highborn Crypts"))
    b = gravestones("b", 1917, "potters", "mounds", HORDES[4:], ("the Potter's Field", "the Burial Mounds"))
    return [a, b]
