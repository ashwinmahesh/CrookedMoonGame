#!/usr/bin/env python3
"""ONE-SHOT (R18, Hartsblight Forest). Writes the forest's eleven maps (their rows came from tools/content/hartsblight_sketch.py + `make sketch`),
the longhouse inside, its people, quests, flags, items, cutscenes, encounters, Gorthos's second phase, the travel place and road, and Wickermoor's
hooks (Sister Rain at the pavilion, the Mayor's Sporefall offer, the after-beats). Other lanes edit these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_hartsblight.py"""
import json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G
from hartsblight_layout import MAPS
from heirlooms_kept import kept

ROOT = Path(__file__).resolve().parents[2]
REGION = "hartsblight_forest"
HB = "hartsblight/"


def write(rel, obj):
    if kept(rel):
        return
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


class Place:
    """A location being finished: snaps every placed thing to a free open square so a prop never lands in a tree."""

    def __init__(self, mid):
        self.id = mid
        self.loc = read(f"data/locations/{mid}.json")
        self.rows = self.loc["map"]["rows"]
        self.used: set = set()
        self.loc.update({"id": mid, "region": REGION, "props": [], "npcs": [], "exits": [], "encounters": [], "areas": [], "lights": [], "traps": []})
        m = MAPS.get(mid)
        if m:
            self.loc["spawns"] = {k: list(v) for k, v in m["spawns"].items()}
            for v in m["spawns"].values():
                self.used.add(tuple(v))

    def ok(self, c):
        x, y = c
        return 0 <= y < len(self.rows) and 0 <= x < len(self.rows[y]) and self.rows[y][x] == "." and (x, y) not in self.used

    def snap(self, cell):
        x, y = cell
        if self.ok((x, y)):
            return (x, y)
        for r in range(1, 14):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) == r and self.ok((x + dx, y + dy)):
                        return (x + dx, y + dy)
        raise SystemExit(f"{self.id}: no free square near {cell}")

    def prop(self, pid, cell, label=None, kind="examine", model=None, snap=True, **kw):
        c = self.snap(cell) if snap else tuple(cell)
        self.used.add(c)
        d = {"id": pid, "cell": list(c), "kind": kind}
        if label:
            d["label"] = label
        if model:
            d["model"] = model
        d.update(kw)
        self.loc["props"].append(d)
        return c

    def npc(self, nid, cell, dialogue=None, **kw):
        c = self.snap(cell)
        self.used.add(c)
        d = {"npc": nid, "cell": list(c)}
        if dialogue:
            d["dialogue"] = HB + dialogue
        d.update(kw)
        self.loc["npcs"].append(d)
        return c

    def area(self, aid, name, a, b, **kw):
        self.loc["areas"].append({"id": aid, "name": name, "cells": [list(a), list(b)], **kw})

    def exit(self, eid, cell, to, spawn, label, **kw):
        self.loc["exits"].append({"id": eid, "cell": list(cell), "to": to, "spawn": spawn, "label": label, **kw})

    def standard_exits(self, **when):
        for eid, (cell, to, spawn, label) in MAPS[self.id]["exits"].items():
            self.exit(eid, cell, to, spawn, label, **({"when": when[eid]} if eid in when else {}))

    def spots(self, center, n, spread=1, ring=False):
        """n distinct free squares near center, nearest first (reserved as they are handed out)."""
        out = []
        cx, cy = center
        cand = []
        for dy in range(-12, 13):
            for dx in range(-12, 13):
                c = (cx + dx, cy + dy)
                if self.ok(c):
                    cand.append((abs(dx) * spread + abs(dy) * spread + (dx * dx + dy * dy) * 0.01, c))
        cand.sort()
        for _, c in cand[:n]:
            out.append(c)
            self.used.add(c)
        if len(out) < n:
            raise SystemExit(f"{self.id}: not enough room for {n} near {center}")
        return out

    def mon(self, mid, cell, name=None, **kw):
        d = {"monster": mid, "cell": list(cell)}
        if name:
            d["name"] = name
        d.update(kw)
        return d

    def fight(self, eid, monsters, **kw):
        d = {"id": eid, "trigger": "dialogue", "monsters": monsters}
        d.update(kw)
        self.loc["encounters"].append(d)

    def save(self, text, rest="risky", light="dim", theme="forest"):
        self.loc["text"] = text
        self.loc["map"]["theme"] = theme
        self.loc["map"]["light"] = light
        self.loc["map"]["outdoors"] = theme != "caves"
        self.loc["rest"] = rest
        self.loc["rest_text"] = "The spores drift down on your bedrolls like a slow, soft snow, and the trees are listening."
        write(f"data/locations/{self.id}.json", self.loc)


def _stand(a, b, c):
    """All three places of a stand seen, or (the dryad's shortcut) any two of them."""
    va, vb, vc = (f"visited:{x}" for x in (a, b, c))
    return f"({va} and {vb} and {vc}) or (flag.hb_dryad_shortcut and (({va} and {vb}) or ({va} and {vc}) or ({vb} and {vc})))"


STAND1 = _stand("hb_pine_barrens", "hb_infested_outcrop", "hb_noxious_hollow")
STAND2 = _stand("hb_oozing_ravine", "hb_stinking_quagmire", "hb_fungal_grove")


def night_fights(p, camp):
    """The Dead of Night's three fights, at a camp spot (the `combat` line plays the current place's encounter)."""
    x, y = camp
    drums = [p.mon("rotweaver", c, "Rotweaver", facing="west") for c in p.spots((x + 6, y), 4, 2)]
    p.fight("hb_drums", drums, flag="hb_drums_done")
    p.fight("hb_mammoth", [p.mon("mammoth", p.spots((x + 7, y + 2), 1)[0], "A blighted mammoth", facing="west")], flag="hb_mammoth_done")
    if not any(e["id"] == "hb_owlbears" for e in p.loc["encounters"]):
        p.fight("hb_owlbears", [p.mon("owlbear", c, "A rotting owlbear", facing="west") for c in p.spots((x + 8, y - 2), 2, 2)], flag="hb_owlbears_done")


def trek(prop_id, flag, node, place, near):
    """The arrival scene of a stand: a decor prop at the spawn that plays the trek leg once."""
    place.prop(prop_id, near, "The way in, and the smell of it", kind="decor", call=HB + "trek:" + node, approach=8, call_when=f"not flag.{flag}")


NAMES = {
    "hb_patient_commune": ("The Patient Lady Commune", "A dead commune at the forest's edge, dusted green-white, with eighteen still bodies and a drumming at the tree line."),
    "hb_altar_of_rot": ("The Altar of Rot", "A towering effigy woven from branches with a hollow woman's face, and a stag's carcass laid on a stack of stones."),
    "hb_pine_barrens": ("The Pine Barrens", "Thin, peeling pines over a black-green carpet of needles with rusted traps hidden in it."),
    "hb_infested_outcrop": ("The Infested Outcrop", "A rock outcrop in a ring of soft, upturned soil, with a dead botanists' camp on top."),
    "hb_noxious_hollow": ("The Noxious Hollow", "A mossy hollow round one broad beech, white-green with mould, and a dead trapper at its foot."),
    "hb_druid_commune": ("The Druids' Commune", "An open common ringed by giant rotting trees burrowed out as homes, with a drum circle at its heart."),
    "hb_oozing_ravine": ("The Oozing Ravine", "A winding ravine with fungal jelly underfoot and a net of strands overhead hung with sap-bulbs."),
    "hb_stinking_quagmire": ("The Stinking Quagmire", "A sunken marsh of slick green pools, and one perfectly clear pool among them."),
    "hb_fungal_grove": ("The Fungal Grove", "Ten-foot fungal stalks and hanging tendrils under a soft green glow, tended by a blighted tree-man."),
    "hb_wellspring": ("The Withering River and the Befouled Wellspring", "A sallow river across the south and, beyond it, a ring of leaning standing stones round a churning green pool."),
    "hb_den": ("The Den of the Blighted One", "A slick, throat-like tunnel opening on a cavern of bone, root and bile-yellow fungal nests."),
}
GLOW = {"kind": "candle", "bright_ft": 20, "dim_ft": 40, "color": "bile"}


def light(cell, bright=20, dim=40, color="bile"):
    return {"cell": list(cell), "kind": "candle", "bright_ft": bright, "dim_ft": dim, "color": color}


def forest_dressing(p, n_trees, n_bones, n_misc, box):
    """Many ordinary props: dead trees, pines, bone scatter, fungus, leaves. Deterministic scatter over open squares."""
    import random
    r = random.Random(sum(map(ord, p.id)))
    x0, y0, x1, y1 = box
    models = [("dead_tree_a", "A dead tree, furred with fungus"), ("dead_tree_b", "A split trunk bursting with shelf fungus"),
              ("pine_a", "A peeling pine"), ("pine_b", "A black-streaked pine"), ("pine_c", "A thin pine")]
    for i in range(n_trees):
        m, lab = r.choice(models)
        c = (r.randint(x0, x1), r.randint(y0, y1))
        try:
            p.prop(f"{p.id}_tree_{i}", c, lab, kind="decor", model=m)
        except SystemExit:
            pass
    for i in range(n_bones):
        c = (r.randint(x0, x1), r.randint(y0, y1))
        p.prop(f"{p.id}_bones_{i}", c, "Green-stained bones", kind="decor", model="bone_scatter")
    misc = [("leaves", "Drifts of grey leaves"), ("vines", "Pale vines"), ("rocks", "Mossy stones"), ("cobwebs", "Cobwebs hung with spores"), ("puddle", "A puddle that is not water")]
    for i in range(n_misc):
        m, lab = r.choice(misc)
        c = (r.randint(x0, x1), r.randint(y0, y1))
        p.prop(f"{p.id}_misc_{i}", c, lab, kind="decor", model=m)


# ---- maps -------------------------------------------------------------------------------------------------------------------------
def build_commune():
    p = Place("hb_patient_commune")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("commune_yard", "The commune", (3, 8), (40, 54))
    p.area("tree_line", "The tree line", (3, 7), (40, 10))
    p.area("gardens", "The gardens", (5, 35), (14, 44))
    p.standard_exits(tree_line="flag.hb_circle_done or flag.hb_circle_fled")
    p.exit("longhouse_door", (22, 30), "hb_commune_longhouse", "default", "The longhouse")
    p.loc["spawns"]["from_longhouse"] = [22, 31]; p.used.add((22, 31))
    p.prop("hb_commune_arrival", (22, 49), "The commune under the spores", kind="decor", call=HB + "commune:arrival", approach=9, call_when="not flag.hb_commune_seen")
    p.prop("hb_circle_watch", (22, 14), "The Circle of the Hartsblight", kind="decor", model="rune_circle", dialogue=HB + "commune:circle_glimpse",
           call_when="not flag.hb_circle_done and not flag.hb_circle_fled", approach=12, call=HB + "commune:circle_glimpse")
    p.prop("hb_commune_bodies", (20, 22), "Eighteen bodies, soft and green", model="bone_scatter", dialogue=HB + "commune:bodies")
    p.prop("hb_commune_bodies_b", (25, 21), "A family under one blanket of spores", kind="decor", model="bloodstain")
    p.prop("hb_pen_dead", (8, 50), "The pen, silent", kind="decor", model="hay_bale")
    p.prop("hb_pen_dead_b", (10, 49), "A dead ox in the pen", kind="decor", model="bone_scatter")
    p.prop("hb_garden_bed", (10, 40), "A bed of sunflowers in the grey", model="garden_bed", dialogue=HB + "garden:bed_find", when="not flag.hb_garden_burned")
    for i, c in enumerate([(7, 37), (12, 37), (7, 42), (12, 42)]):
        p.prop(f"hb_garden_dead_{i}", c, "A dead bed of greens", kind="decor", model="garden_bed")
    p.prop("hb_commune_well", (26, 40), "The commune well, ringed in white", model="well_stone")
    p.prop("hb_commune_cart", (30, 46), "A handcart left mid-load", kind="decor", model="handcart")
    p.prop("hb_commune_woodpile", (14, 20), "A woodpile gone soft", kind="decor", model="woodpile")
    p.prop("hb_commune_bench", (24, 36), "A bench with a cup left on it", kind="decor", model="bench")
    p.prop("hb_commune_lantern", (22, 34), "A lantern post, burned out", kind="decor", model="lantern_post")
    p.prop("hb_commune_rake", (6, 45), "A rake against the fence", kind="decor", model="rope_coils")
    for i, c in enumerate([(16, 36), (18, 38), (28, 36), (30, 34), (34, 42), (36, 46)]):
        p.prop(f"hb_commune_orchard_{i}", c, "An apple tree gone to white fungus", kind="decor", model="dead_tree_a")
    p.npc("brother_spore", (30, 44), "spore:spore_start", facing="west", when="not flag.gorthos_slain")
    p.prop("hb_goat", (17, 50), "A goat, unbothered", model="horse", kind="examine", dialogue=HB + "spore:goat")
    p.prop("hb_seed_note", (21, 32), "Footprints to the longhouse", kind="decor")
    forest_dressing(p, 20, 6, 10, (3, 8, 40, 53))
    # the keepers and their line at the tree line
    mons = [p.mon("keeper_of_the_blight", (14, 9), "Keeper of the Blight", facing="south"), p.mon("keeper_of_the_blight", (30, 9), "Keeper of the Blight", facing="south")]
    for i, x in enumerate([16, 18, 20, 24, 26, 28]):
        mons.append(p.mon("rotweaver", p.snap((x, 11)), "Rotweaver", facing="south"))
    for m in mons:
        p.used.add(tuple(m["cell"]))
    p.fight("hb_circle", mons, flag="hb_circle_done", quest={"id": "q_hartsblight", "stage": "circle"}, surprise="",
            round_events=[{"id": "circle_cloud", "name": "The spore cloud", "summary": "The cloud over the commune presses down on everyone in it.", "kind": "save", "affects": "party",
                           "save": {"ability": "con", "dc": 15}, "half": True, "damage": {"dice": "1d6", "type": "necrotic"}, "at": 20, "every": 1}])
    p.loc["lights"] = [light((22, 20), 30, 60, "bile")]
    p.save(NAMES[p.id][1] + " The Crooked Moon hangs over the trees, and the spores fall through its light like snow.", rest="risky")


def build_longhouse():
    g = G(24, 14).room(1, 1, 22, 12)
    g.fill(2, 2, 7, 2, "=").put([(14, 5), (15, 5), (14, 6), (15, 6)], "=")
    rows = g.rows()
    loc = {"id": "hb_commune_longhouse", "name": "The Commune Longhouse", "region": REGION, "summary": "The longhouse of woven branches and clay, where the commune's last elder lies.",
           "text": "A long dim room of woven branches and clay, pallets in rows, and the smell of sweet damp.",
           "map": {"rows": rows, "theme": "tavern", "light": "dim", "outdoors": False},
           "areas": [{"id": "hall", "name": "The longhouse", "cells": [[1, 1], [22, 12]]}],
           "spawns": {"default": [12, 11]}, "exits": [{"id": "door", "cell": [12, 13], "to": "hb_patient_commune", "spawn": "from_longhouse", "label": "Out to the commune"}],
           "props": [], "npcs": [], "rest": "safe", "lights": [{"cell": [3, 3], "kind": "candle", "bright_ft": 15, "dim_ft": 30, "color": "candle"}]}
    pl = Place.__new__(Place)
    pl.id = "hb_commune_longhouse"; pl.loc = loc; pl.rows = rows; pl.used = {(12, 11)}
    pl.prop("hb_lh_pallets", (5, 8), "Rows of empty pallets", kind="decor", model="bed")
    pl.prop("hb_lh_pallets_b", (18, 8), "Pallets, most of them occupied", kind="decor", model="bed_small")
    pl.prop("hb_lh_hearth", (11, 2), "A hearth gone cold", kind="decor", model="hearth")
    pl.prop("hb_lh_sketch", (4, 4), "A charcoal sketch pinned over the lintel", model="painting", dialogue=HB + "harvest:elder_sketch", when="not item:gwenna_sketch")
    pl.prop("hb_lh_jars", (20, 3), "Jars of seed, most of them black", kind="decor", model="jars")
    pl.prop("hb_lh_keepsakes", (9, 10), "Keepsakes of the dead", kind="decor", model="rags")
    pl.npc("elder_brisa_thorne", (16, 8), "harvest:elder_progress", when="flag.hb_harvest_asked and not flag.hb_harvest_lost and not flag.hb_harvest_done")
    pl.npc("elder_brisa_thorne", (16, 8), "harvest:elder_start")
    write("data/locations/hb_commune_longhouse.json", loc)


def build_altar():
    p = Place("hb_altar_of_rot")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("altar_glade", "The altar glade", (2, 2), (27, 27))
    p.standard_exits(to_druids=STAND1)
    trek("hb_altar_leg", "hb_leg_altar", "leg_altar", p, (15, 25))
    p.prop("hb_effigy", (15, 9), "The effigy, a woman's face under fungus", model="scarecrow", scale=4.0, dialogue=HB + "forest1:effigy")
    p.prop("hb_altar", (15, 14), "A stack of stones and a stag carcass", model="altar", dialogue=HB + "forest1:altar_look")
    p.prop("hb_stag", (16, 14), "The stag's head, turned to listen", kind="decor", model="stag_head")
    p.prop("hb_effigy_small", (9, 22), "A small effigy of sticks, facing away", kind="decor", model="scarecrow")
    p.prop("hb_effigy_small_b", (21, 21), "Another small effigy of sticks, facing away", kind="decor", model="scarecrow")
    p.prop("hb_camp_spot", (6, 25), "A hollow among the roots fit for a camp", model="rune_circle", dialogue=HB + "night:camp")
    forest_dressing(p, 24, 5, 10, (3, 3, 26, 26))
    night_fights(p, (6, 25))
    p.loc["lights"] = [light((15, 14), 25, 50, "bile")]
    p.save(NAMES[p.id][1] + " Spores drift through a moonlight that never quite reaches the ground.")


def build_pines():
    p = Place("hb_pine_barrens")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("pine_east", "The edge of the barrens", (20, 2), (34, 27))
    p.area("pine_deep", "The deep pines", (2, 2), (18, 27))
    p.standard_exits()
    trek("hb_pines_leg", "hb_leg_pines", "leg_pines", p, (31, 15))
    p.prop("hb_leash", (6, 8), "A leash tied to a pine, its collar gone", model="rope", dialogue=HB + "forest1:leash")
    p.prop("hb_seed_iron_site", (17, 20), "Blighted roots round an old trap's iron", model="vines", dialogue=HB + "harvest:seed_iron")
    p.prop("hb_trap_dead", (24, 20), "A trap stamped with a trapper's name", model="claw_marks", dialogue=HB + "forest1:trap_dead")
    p.prop("hb_bear_skull", (12, 22), "A bear skull grown with yellow fungus", kind="decor", model="bone_scatter")
    p.prop("hb_rib_bones", (15, 12), "Green-stained ribs", kind="decor", model="bone_scatter")
    p.prop("hb_lh_trinkets", (28, 8), "Old coins and a buckle in the needles", kind="search", model="satchel", search_dc=12, skill="investigation")
    p.prop("hb_camp_spot_p", (30, 24), "A dry hollow among the pines", model="rune_circle", dialogue=HB + "night:camp")
    for i, (cx, cy) in enumerate([(26, 9), (22, 14), (28, 17), (24, 23), (20, 11), (30, 12)]):
        c = p.snap((cx, cy))
        p.loc["traps"].append({"id": f"hb_trap_{i}", "cells": [list(c)], "detect_dc": 17, "disarm_dc": 15, "save": {"ability": "dex", "dc": 15}, "damage": "1d8", "damage_type": "piercing", "flag": "hb_trap_found"})
        p.used.add(c)
    forest_dressing(p, 30, 8, 8, (3, 3, 34, 26))
    night_fights(p, (30, 24))
    hounds = [p.mon("death_dog", c, "A one-headed hound", facing="east") for c in p.spots((9, 15), 8, 2)]
    p.loc["encounters"].append({"id": "hb_hounds", "trigger": "enter_area:pine_deep", "flag": "hb_hounds_done", "monsters": hounds, "when": "not flag.hb_hounds_done"})
    p.save(NAMES[p.id][1] + " Everything grows in straight, thin lines, and nothing moves among them.")


def build_outcrop():
    p = Place("hb_infested_outcrop")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("outcrop_top", "The camp on the rock", (13, 13), (27, 23), light="bright")
    p.area("outcrop_edge", "The way out", (8, 32), (31, 38))
    p.standard_exits()
    trek("hb_outcrop_leg", "hb_leg_outcrop", "leg_outcrop", p, (20, 35))
    p.prop("hb_camp", (20, 18), "The botanists' camp, safe in the smoke", model="cookpot", dialogue=HB + "forest1:camp")
    for i, c in enumerate([(16, 15), (24, 15), (16, 21), (24, 21)]):
        p.prop(f"hb_tent_{i}", c, "A tent, sagging", kind="decor", model="sheeted_furniture")
    for i, c in enumerate([(18, 15), (22, 15), (18, 22), (22, 22)]):
        p.prop(f"hb_botanist_{i}", c, "A bloated body on a log", kind="decor", model="bloodstain")
    p.prop("hb_smoke_bottle", (20, 20), "The Eversmoking Bottle, still hissing", kind="decor", model="jars")
    p.prop("hb_cold_fire", (19, 17), "A cold fire pit", kind="decor", model="soot_patch")
    p.prop("hb_burrow_a", (10, 30), "A burrow hole at the smoke's edge", kind="decor", model="rocks")
    p.prop("hb_burrow_b", (30, 28), "An acid-scored trench", kind="decor", model="scorch")
    p.prop("hb_burrow_c", (8, 22), "An upturned mound of soil", kind="decor", model="rocks")
    forest_dressing(p, 18, 6, 8, (3, 3, 36, 36))
    beetles = [p.mon("ankheg", c, "A carrion beetle", facing="north") for c in p.spots((20, 29), 8, 2)]
    p.fight("hb_beetles", beetles, flag="hb_beetles_done")
    leave = [dict(m) for m in beetles]
    p.loc["encounters"].append({"id": "hb_beetles_leave", "trigger": "enter_area:outcrop_edge", "flag": "hb_beetles_done", "monsters": leave,
                                "when": "flag.hb_camp_seen and not flag.hb_beetles_done"})
    p.loc["lights"] = [light((20, 18), 40, 80, "candle")]
    p.save(NAMES[p.id][1] + " Flies and beetles buzz everywhere except inside the smoke.")


def build_hollow():
    p = Place("hb_noxious_hollow")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("hollow_floor", "The hollow", (4, 4), (26, 26))
    p.area("owlbear_ridge", "The ridge of dead trees", (20, 2), (27, 8))
    p.standard_exits()
    trek("hb_hollow_leg", "hb_leg_hollow", "leg_hollow", p, (4, 15))
    p.prop("hb_halden", (15, 17), "A half-eaten corpse against the beech", model="bone_scatter", dialogue=HB + "forest1:corpse", when="not flag.hb_halden_torso_seen")
    p.prop("hb_beech_carving", (13, 16), "A skeletal stag carved into the bark", model="tree_marked", dialogue=HB + "forest1:shrine")
    p.prop("hb_owlbear_den", (24, 5), "A den under dead trees, scratched and wet", model="claw_marks", dialogue=HB + "halden:den_prop", when="flag.hb_owlbears_traced and not flag.hb_owlbears_understood")
    p.prop("hb_halden_cairn", (17, 19), "Halden's cairn", model="grave", dialogue=HB + "halden:buried", when="flag.hb_halden_torso_seen and not flag.hb_halden_buried")
    p.prop("hb_halden_torso", (15, 11), "Halden's torso, high in the beech", model="bone_scatter", dialogue=HB + "gorthos:parley2", when="flag.hb_halden_torso_seen")
    p.prop("hb_halden_pack", (14, 18), "A trapper's pack, torn open", kind="decor", model="satchel")
    p.prop("hb_halden_journal_prop", (16, 18), "The trapper's journal", kind="examine", model="book", dialogue=HB + "halden:journal_find", when="not flag.hb_halden_journal")
    p.prop("hb_journal_read", (14, 20), "The journal, open", kind="examine", model="book", dialogue=HB + "halden:journal_read", when="flag.hb_halden_journal")
    p.prop("hb_camp_spot_h", (8, 8), "A hollow in the moss fit for a camp", model="rune_circle", dialogue=HB + "night:camp")
    forest_dressing(p, 16, 6, 8, (3, 3, 26, 26))
    owl = [p.mon("owlbear", c, "A rotting owlbear", facing="west") for c in p.spots((23, 6), 2, 2)]
    p.fight("hb_owlbears", owl, flag="hb_owlbears_done")
    night_fights(p, (8, 8))
    p.loc["lights"] = [light((15, 15), 25, 50, "bile")]
    p.save(NAMES[p.id][1] + " The beech's white-green branches hold the dark close.")


def build_druids():
    p = Place("hb_druid_commune")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("f5_common", "The common", (8, 8), (31, 31), light="dim")
    p.area("dwellings", "The burrowed dwellings", (3, 6), (36, 33))
    p.standard_exits(to_ravine="visited:hb_druid_commune", to_wellspring=STAND2)
    trek("hb_druids_leg", "hb_leg_druids", "leg_druids", p, (4, 35))
    p.prop("hb_f5_common", (20, 26), "The open common, the drum circle at its heart", kind="decor", model="offering_circle", call=HB + "forest2:common", approach=8, call_when="not flag.hb_f5_seen")
    p.prop("hb_dwelling_a", (6, 12), "A dwelling burrowed into a rotting trunk", model="cobwebs", dialogue=HB + "forest2:dwelling")
    p.prop("hb_dwelling_b", (33, 11), "A dwelling, mouldy bedding at its door", model="cobwebs", dialogue=HB + "forest2:dwelling")
    p.prop("hb_dwelling_c", (8, 31), "A dwelling, its prayer rings broken", kind="decor", model="cobwebs")
    p.prop("hb_drum_circle", (20, 20), "The drum circle", kind="decor", model="rune_circle")
    p.prop("hb_antler_idols", (13, 22), "Antler idols on a stone", kind="decor", model="stag_head")
    p.prop("hb_bone_pipes", (27, 22), "Gourd-and-bone instruments", kind="decor", model="lute")
    p.prop("hb_camp_spot_d", (4, 30), "A hollow at the edge of the common", model="rune_circle", dialogue=HB + "night:camp")
    forest_dressing(p, 14, 6, 10, (3, 3, 36, 36))
    night_fights(p, (4, 30))
    mons = [p.mon("keeper_of_the_blight", p.snap((20, 19)), "Keeper of the Blight", facing="south")]
    p.used.add(tuple(mons[0]["cell"]))
    import math
    for i in range(12):
        a = 2 * math.pi * i / 12
        c = p.snap((20 + round(4.5 * math.cos(a)), 20 + round(4.5 * math.sin(a))))
        p.used.add(c)
        mons.append(p.mon("rotweaver", c, "Rotweaver", facing="north"))
    p.loc["encounters"].append({"id": "hb_f5", "trigger": "enter_area:f5_common", "flag": "hb_f5_done", "waiting": True, "monsters": mons,
                                "when": "not flag.hb_garb_taken and not flag.hb_f5_done"})
    p.loc["lights"] = [light((20, 20), 40, 80, "bile")]
    p.save(NAMES[p.id][1] + " Spore clouds thicken the air until the far trees are only a rumour.")


def build_ravine():
    p = Place("hb_oozing_ravine")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("ravine_floor", "The ravine floor", (4, 1), (11, 32))
    p.standard_exits()
    trek("hb_ravine_leg", "hb_leg_ravine", "leg_ravine", p, (8, 29))
    p.prop("hb_ravine_net", (8, 16), "The net of fungal strands overhead", kind="decor", model="vines", dialogue=HB + "forest2:ravine")
    for i, c in enumerate([(6, 8), (10, 12), (6, 20), (9, 24), (7, 4)]):
        p.prop(f"hb_sap_bulb_{i}", c, "A sap-bulb as big as a calf", kind="decor", model="jars")
    p.prop("hb_jelly_residue", (8, 6), "Residue of jelly, with something in it", kind="search", model="puddle", search_dc=10, item="chunk_of_oozing_fungus", when="flag.hb_jellies_done")
    forest_dressing(p, 4, 3, 5, (4, 2, 11, 30))
    jellies = [p.mon("ochre_jelly", c, "An ochre jelly", facing="south") for c in p.spots((8, 12), 6, 2)]
    p.fight("hb_jellies", jellies, flag="hb_jellies_done")
    p.save(NAMES[p.id][1] + " Sap-bulbs hang over you like ripe fruit.")


def build_quagmire():
    p = Place("hb_stinking_quagmire")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("marsh", "The marsh", (3, 3), (36, 32))
    p.standard_exits()
    trek("hb_quagmire_leg", "hb_leg_quagmire", "leg_quagmire", p, (4, 18))
    p.prop("hb_clear_pool", (20, 22), "The clear pool, impossibly clean", kind="examine", model="puddle", dialogue=HB + "forest2:pool", when="not flag.hb_pool_fouled or not flag.hb_mounds_done")
    p.prop("hb_pool_drained", (20, 22), "The drained pool bed", kind="decor", model="bone_scatter", dialogue=HB + "forest2:pool_drained", when="flag.hb_pool_fouled and flag.hb_mounds_done")
    p.prop("hb_pool_ring", (21, 22), "A ring of bone in the pool bed", kind="search", model="jars", search_dc=8, item="ring_of_resistance_necrotic", when="flag.hb_pool_fouled and flag.hb_mounds_done")
    p.prop("hb_seed_fire_site", (11, 12), "A reed bed under white-green mould", model="reeds", dialogue=HB + "harvest:seed_fire")
    for i, c in enumerate([(14, 24), (28, 14), (30, 30), (12, 30), (24, 6)]):
        p.prop(f"hb_mud_{i}", c, "A deep mud pit", kind="decor", model="puddle")
    forest_dressing(p, 10, 6, 8, (3, 3, 36, 32))
    mounds = [p.mon("shambling_mound", c, "A shambling mound of black rot", facing="west") for c in p.spots((18, 20), 3, 2)]
    p.fight("hb_mounds", mounds, flag="hb_mounds_done")
    p.save(NAMES[p.id][1] + " Every step here is a negotiation with the ground.")


def build_grove():
    p = Place("hb_fungal_grove")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("grove", "The grove", (3, 3), (32, 32), light="bright")
    p.standard_exits()
    trek("hb_grove_leg", "hb_leg_grove", "leg_grove", p, (31, 17))
    p.prop("hb_gloomwood", (14, 18), "The gloomwood, covered in corpse flowers", kind="examine", model="tree_marked", scale=3.0, dialogue=HB + "forest2:gloom_start",
           when="not flag.hb_gloomwood_done and not flag.hb_grove_done")
    p.prop("hb_corpse_flower", (9, 27), "A wilted corpse flower with a pod", model="vines", dialogue=HB + "forest2:flower", when="not flag.hb_pod_taken")
    for i, c in enumerate([(8, 8), (20, 8), (26, 12), (10, 14), (22, 24), (28, 26), (6, 22)]):
        p.prop(f"hb_stalk_{i}", c, "A ten-foot fungal stalk", kind="decor", model="vines")
    p.prop("hb_grove_parley", (13, 20), "The gloomwood's trunk", kind="decor", model="tree_marked", call=HB + "gorthos:parley3", approach=4,
           call_when="(flag.hb_gloomwood_done or flag.hb_grove_done) and not flag.hb_parley3")
    forest_dressing(p, 6, 4, 8, (3, 3, 32, 32))
    p.npc("hb_dryad", (24, 10), "dryad:dryad_review_start", facing="west", when="flag.hb_night_dryad or flag.hb_dryad_friendly")
    p.npc("hb_dryad", (24, 10), "dryad:dryad_arrive", facing="west", when="not flag.hb_dryad_hostile")
    p.fight("hb_gloomwood", [p.mon("gloomwood", (14, 20), "The gloomwood", facing="east")], flag="hb_gloomwood_done")
    p.loc["lights"] = [light((14, 18), 40, 80, "bile"), light((22, 22), 30, 60, "bile")]
    p.save(NAMES[p.id][1] + " The whole grove glows a soft, patient green.", light="bright")


def build_wellspring():
    p = Place("hb_wellspring")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("river", "The Withering River", (2, 26), (27, 33))
    p.area("wellspring_clearing", "The clearing of stones", (4, 3), (25, 23), light="bright")
    p.standard_exits(to_den="flag.hb_festerhulk_done")
    trek("hb_wellspring_leg", "hb_leg_wellspring", "leg_wellspring", p, (15, 36))
    p.prop("hb_river_toll", (15, 35), "The Withering River", kind="decor", model="reeds", call=HB + "wellspring:river", approach=6, call_when="not flag.hb_river_paid")
    p.prop("hb_pool", (15, 18), "The churning pool", model="puddle", dialogue=HB + "wellspring:stones", when="not flag.hb_festerhulk_done")
    p.prop("hb_pool_after", (15, 18), "The pool, still and spent", kind="decor", model="puddle", call=HB + "wellspring:pool_memory", approach=6, call_when="flag.hb_festerhulk_done and not flag.hb_pool_memory_seen")
    p.prop("hb_staff", (13, 17), "A crooked staff among the stones", kind="search", model="rope", search_dc=8, item="staff_of_farryn", when="flag.hb_festerhulk_done and treasure_at:befouled_wellspring")
    p.prop("hb_seed_song_site", (8, 30), "Black reeds by the water, listening", model="reeds", dialogue=HB + "harvest:seed_song")
    p.prop("hb_camp_spot_w", (22, 36), "A bank above the water", model="rune_circle", dialogue=HB + "night:camp")
    for i, c in enumerate([(9, 6), (22, 6), (7, 14), (23, 15), (12, 22), (20, 21)]):
        p.prop(f"hb_pustule_{i}", c, "A glowing pustule", kind="decor", model="candle_cluster")
    p.prop("hb_gwenna_trail", (15, 5), "A slime trail leading north", kind="decor", model="bloodstain", when="flag.hb_festerhulk_done")
    forest_dressing(p, 10, 4, 6, (3, 3, 26, 24))
    night_fights(p, (22, 36))
    p.fight("hb_festerhulk", [p.mon("festerhulk", (15, 19), "Gwenna's remains, risen", facing="north", boss=True)], flag="hb_festerhulk_done", lair=True)
    p.loc["lights"] = [light((15, 12), 60, 120, "bile"), light((8, 8), 30, 60, "bile"), light((22, 8), 30, 60, "bile")]
    p.save(NAMES[p.id][1] + " The ceiling is a living wall of fungus, sixty feet up.", light="bright")


def build_den():
    p = Place("hb_den")
    p.loc.update({"name": NAMES[p.id][0], "summary": NAMES[p.id][1]})
    p.area("tunnel", "The tunnel", (11, 28), (18, 38))
    p.area("lair", "The den", (4, 3), (25, 27))
    p.standard_exits(to_wellspring="not flag.hb_gorthos_started or flag.hb_gorthos_done")
    trek("hb_den_leg", "hb_leg_den", "leg_den", p, (15, 35))
    p.prop("hb_den_torso", (15, 6), "The gaunt top half of a satyr, hanging from the wall", kind="examine", model="stag_head", scale=2.0, dialogue=HB + "gorthos:den_arrive",
           when="not flag.hb_gorthos_started")
    p.prop("hb_den_arrive", (15, 30), "The tunnel mouth", kind="decor", call=HB + "gorthos:den_arrive", approach=4, call_when="not flag.hb_gorthos_started")
    p.prop("hb_den_farewell", (15, 12), "The dissolving colossus", kind="decor", call=HB + "gorthos:den_farewell", approach=12, call_when="flag.hb_gorthos_done and not flag.gorthos_slain")
    p.prop("hb_idol", (15, 5), "A carved idol hanging in the den", kind="search", model="stag_head", search_dc=8, item="idol_of_the_beast_of_blight", when="flag.gorthos_slain and treasure_at:gorthos_den")
    p.prop("hb_charms", (7, 12), "Charms of bone, flesh and fur", kind="decor", model="bone_scatter")
    p.prop("hb_charms_b", (23, 12), "Idols hung with hair", kind="decor", model="stag_head")
    p.prop("hb_root_veins", (6, 22), "Blighted root veins", kind="decor", model="vines")
    p.prop("hb_fungal_nest_a", (10, 20), "A pus-oozing fungal nest", kind="decor", model="candle_cluster")
    p.prop("hb_fungal_nest_b", (20, 18), "A pus-oozing fungal nest", kind="decor", model="candle_cluster")
    p.prop("hb_fungal_nest_c", (14, 24), "Swollen rotten moss", kind="decor", model="leaves")
    p.prop("hb_den_bones", (17, 14), "Bones of a very large animal", kind="decor", model="bone_scatter")
    mons = [p.mon("beast_of_blight", (14, 6), "Gorthos, the Beast of Blight", boss=True, facing="south")]
    for c in p.spots((15, 22), 3, 2):
        mons.append(p.mon("rotweaver", c, "Rotweaver", facing="north"))
    p.loc["encounters"] = [{
        "id": "hb_gorthos", "trigger": "dialogue", "flag": "hb_gorthos_done", "lair": True, "monsters": mons,
        "round_events": [{"id": "hartsblight_influence", "name": "Hartsblight Influence", "summary": "On count 20 the den's rot takes a different shape each round.", "kind": "save", "affects": "party",
                          "at": 20, "every": 1, "pick": "random", "table": [
            {"id": "blighted_spores", "name": "Blighted Spores", "kind": "save", "affects": "party", "save": {"ability": "con", "dc": 15}, "damage": {"dice": "1d6", "type": "necrotic"}, "half": True,
             "condition": "poisoned", "until": "target_turn_end", "say": "hb_influence_spores"},
            {"id": "sticky_tendrils", "name": "Sticky Tendrils", "kind": "save", "affects": "party", "save": {"ability": "str", "dc": 15}, "condition": "restrained", "until": "target_turn_end", "say": "hb_influence_tendrils"},
            {"id": "weaving_rot", "name": "Weaving Rot", "kind": "summon", "affects": "enemies", "monster": "rotweaver", "count": 1, "side": "enemies", "cells": [[10, 24], [20, 24]], "say": "hb_influence_weaving"}]}]}]
    p.loc["lights"] = [light((15, 10), 40, 80, "bile"), light((8, 20), 25, 50, "bile")]
    p.save(NAMES[p.id][1] + " Everything is wet, and everything glows a little.", rest="no", theme="caves", light="dim")


# ---- people, quests, items, flags --------------------------------------------------------------------------------------------------
PEOPLE = [
    ("gorthos", "Gorthos, the Beast of Blight", "Once Farryn of the Greenwood", "A young satyr druid who ate a dead stag-god and became the rot she wanted to cure the world of.", "indifferent", "monster"),
    ("keeper_of_the_blight", "Keeper of the Blight", "A druid of rot", "A stag-bodied fey druid, flat and calm, who serves the Emerald Rebirth.", "hostile", "monster"),
    ("gwenna", "Gwenna", "A Patient Lady faithful", "Farryn's dead love, seen only in visions: laughing, dancing, idealistic.", "friendly", None),
    ("halden_wreath", "Halden Wreath", "A dead trapper", "A Wickermoor trapper who chased the Tall Man into the forest and never came out.", "indifferent", None),
    ("elder_brisa_thorne", "Elder Brisa Thorne", "Last elder of the commune", "A dying Patient Lady elder, seventy, bitter and plain, who knew more than she told.", "friendly", None),
    ("brother_spore", "Brother Spore", "A forager", "A Patient Lady forager who tastes everything and narrates it like a sommelier.", "friendly", None),
    ("hb_dryad", "The Dryad", "A corrupted tree-spirit", "A nameless, bad-tempered critic in half-rotted leaves.", "indifferent", None),
    ("gloomwood", "The Gloomwood", "A blighted tree-man", "A huge gnarled tree-man covered in corpse flowers, guarding the fungal stalks.", "hostile", "monster"),
    ("commune_goat", "Biscuit", "The commune goat", "A goat that survived everything and is not bothered.", "friendly", None),
]


def build_people():
    for (nid, name, title, summary, att, mon) in PEOPLE:
        d = {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION}
        if nid == "gorthos":
            d["monster"] = "beast_of_blight"
        if nid == "keeper_of_the_blight":
            d["monster"] = "keeper_of_the_blight"
        if nid == "gloomwood":
            d["monster"] = "gloomwood"
        if nid in ("brother_spore", "elder_brisa_thorne"):
            d["tags"] = ["faction_patient_lady"]
        write(f"data/npcs/{nid}.json", d)


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
    write("data/quests/q_hartsblight.json", {
        "id": "q_hartsblight", "name": "The Hartsblight", "kind": "main", "region": REGION, "giver": "sister_rain",
        "summary": "A fungal rot pours out of a forest north-west of Wickermoor, and a satyr who answers to Gorthos is its heart.",
        "stages": [
            stage("hook", "A rot called the Hartsblight is coming out of the forest beyond Moonsong Lake. Sister Rain, or the Mayor's panic, sent us after it.", "Follow the spore trail north-west to the Patient Lady commune.", ["Reach the commune"]),
            stage("commune", "The commune is dead, eighteen bodies rotted too fast, and a ring of druids drums at the tree line.", "Deal with the druids at the tree line, or slip past them into the forest.", ["Stop the Circle of the Hartsblight"]),
            stage("circle", "The Circle's drums have gone quiet, or we left them to their work. The forest waits.", "Enter the forest by the altar of rot.", ["Cross the outer stand"]),
            stage("blighted_wood", "We have walked into the Blighted Wood. The rot gets into us a little with every league.", "Visit the pine barrens, the outcrop and the hollow before going deeper.", ["Visit all three places of the outer stand"]),
            stage("festering_wilds", "The middle wood is thick with spore clouds and a commune of druids in the trees.", "Pass the druids' commune and see the ravine, the quagmire and the grove.", ["Cross the middle stand"]),
            stage("rotten_heart", "The Rotten Heart: a sallow river, a ring of standing stones, and a pool with a dead woman in it.", "Cross the river and reach the wellspring.", ["Destroy what is left of Gwenna"]),
            stage("den", "A slime trail leads to a cave under a ridge, and a voice that has been talking to us all the way.", "Follow the slime trail north to the den.", ["Face Gorthos"]),
            stage("gorthos_destroyed", "Gorthos died a second time with Gwenna's name in her mouth, and the rot went out of us.", "Return to Sister Rain in Wickermoor.", ["Tell Sister Rain"]),
            stage("reported", "We told Sister Rain what we found. The Patient Lady's missionaries will go to the forest's edge.", ends="success"),
        ]})
    write("data/quests/hb_commune_harvest.json", {
        "id": "hb_commune_harvest", "name": "The Commune's Last Harvest", "kind": "side", "region": REGION, "giver": "elder_brisa_thorne",
        "summary": "The commune's last elder wants seed gathered from three stands of blight so the commune is not just a grave.",
        "stages": [
            stage("asked", "Elder Brisa Thorne gave us a clay seed jar. Iron for the pines, fire for the mould, song for the river.", "Gather the three seeds: iron at the pine barrens, fire at the quagmire, song at the river.", ["Iron seed", "Fire seed", "Song seed"]),
            stage("done", "We brought the seed bank back, and the elder planted the first seed in the longhouse floor.", ends="success"),
            stage("lost", "We told the elder it could not be done. She nodded, and the jar went cold.", ends="failure"),
        ]})
    write("data/quests/hb_halden_hunt.json", {
        "id": "hb_halden_hunt", "name": "Halden's Last Hunt", "kind": "side", "region": REGION, "giver": "halden_wreath",
        "summary": "A dead trapper's journal says the forest answers in his own voice. Find out what is using it.",
        "stages": [
            stage("asked", "We took Halden Wreath's journal off his corpse. He chased the Tall Man here, and the last page says the forest talks back.", "Read the journal and follow the trail it describes.", ["Read the journal"]),
            stage("traced", "The trail leads to a ridge of dead trees east of the hollow, where the screams come from.", "Find the owlbears' den on the ridge.", ["Find the source of the screams"]),
            stage("done", "Two rotting owlbears were copying Halden's last scream. We learned what they were and what they copied.", ends="success"),
        ]})
    write("data/quests/hb_gwennas_garden.json", {
        "id": "hb_gwennas_garden", "name": "Gwenna's Garden", "kind": "side", "region": REGION, "giver": "sister_rain",
        "summary": "A bed of sunflowers Gwenna planted still blooms in the commune's blight. Decide what becomes of it.",
        "stages": [
            stage("found", "In the dead commune a bed of sunflowers still blooms where Gwenna planted it.", "Tend it, move it or burn it.", ["Decide the garden's fate"]),
            stage("done", "We kept Gwenna's garden alive.", ends="success"),
            stage("lost", "We burned Gwenna's garden to keep the blight from it, and it burned.", ends="failure"),
        ]})
    write("data/quests/hb_dryad_review.json", {
        "id": "hb_dryad_review", "name": "The Dryad's Review", "kind": "side", "region": REGION, "giver": "hb_dryad",
        "summary": "A nameless dryad judges everything the party shows it. Its reviews grow warmer the more honest the party is.",
        "stages": [
            stage("asked", "A corrupted dryad asked to be shown things worth reviewing. It is hard to please.", "Show it a few things: a weapon, a ration, the seed jar, the sketch.", ["Show it three things"]),
            stage("done", "The dryad gave its verdict on us.", ends="success"),
        ]})


INTS = {"hb_blight", "hb_refused", "hb_pool_uses", "hb_reviews", "hb_dryad_warmth", "act2_done", "hb_garden_outcome"}
STRINGS = {"hb_garden_outcome"}


def build_flags():
    # every flag the new files read or set, gathered from them, so none is registered by hand and forgotten
    found: dict = {}
    pat_set = re.compile(r"^\s*set\s+([a-z0-9_]+)", re.M)
    pat_flag = re.compile(r"flag\.([a-z0-9_]+)")
    pat_days = re.compile(r"(?:days|minutes)_since\.([a-z0-9_]+)")
    pat_enc = re.compile(r'"flag": "([a-z0-9_]+)"')
    texts = []
    for f in (ROOT / "narrative/hartsblight").glob("*.dialogue"):
        texts.append(f.read_text())
    for mid in list(MAPS) + ["hb_commune_longhouse"]:
        texts.append((ROOT / f"data/locations/{mid}.json").read_text())
    for t in texts:
        for m in pat_set.findall(t) + pat_flag.findall(t) + pat_days.findall(t) + pat_enc.findall(t):
            found[m] = True
    reg_other = set()
    for f in (ROOT / "data/flags").glob("*.json"):
        if f.name != "hartsblight.json":
            reg_other |= {x["id"] for x in json.loads(f.read_text())["flags"]}
    flags = []
    for fid in sorted(found):
        if fid in reg_other:
            continue
        t = "string" if fid in STRINGS else ("int" if fid in INTS else "bool")
        flags.append({"id": fid, "type": t, "summary": f"Hartsblight Forest (R18): {fid.replace('_', ' ')}.", "read_later": True})
    write("data/flags/hartsblight.json", {"flags": flags})


ITEMS = [
    ("devilbone_button", "Devilbone Button", "wondrous", "A button of pale bone, faintly warm. It steadies your saving throws, and a devil may notice (its powers wait on the engine's heirloom rules)."),
    ("chunk_of_oozing_fungus", "Chunk of Oozing Fungus", "wondrous", "A wet lump of fungus: thrown, it bursts into a poisonous spore cloud (its powers wait on the engine's item rules)."),
    ("druid_rot_garb", "Druid garb", "wondrous", "Hide-and-bark clothes from a druid's dwelling. Worn, a hero passes as one of the rot's own and has Advantage on Charisma checks with the gloomwood."),
    ("gwenna_sketch", "Charcoal sketch of Gwenna", "quest", "A charcoal sketch of a laughing young woman, kept in the commune's longhouse. Seen by the Beast of Blight, it burns."),
    ("seed_jar", "The elder's seed jar", "quest", "A clay jar for the commune's seed bank."),
    ("devils_glove_pod", "Devil's Glove pod", "wondrous", "A dormant pod from a corpse flower. In a day it hatches into a Tiny plant familiar bonded to whoever carries it (its powers wait on the familiar rules)."),
    ("halden_journal", "Halden Wreath's journal", "quest", "A trapper's journal ending on a page that says the forest talks back in his voice."),
    ("tainted_goodberries", "Tainted goodberries", "treasure", "Plump berries that smell of good things. They are not."),
    ("staff_of_farryn", "Staff of Farryn of the Greenwood", "wondrous", "A Fabled Heirloom focus for a druid of the Greenwood: necrotic resistance and healing at a cost (its powers wait on the engine's heirloom rules)."),
    ("idol_of_the_beast_of_blight", "Idol of the Beast of Blight", "wondrous", "A Fabled Heirloom idol carved in a dead stag's bone: spores, a bite in your bark (its powers wait on the engine's heirloom rules)."),
]


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary})


# ---- Gorthos's second phase ---------------------------------------------------------------------------------------------------------
def build_monsters():
    m = read("data/monsters/beast_of_blight.json")
    if not any(ph["id"] == "dead_and_gone" for ph in m.get("phases", [])):
        m["phases"].append({"id": "dead_and_gone", "name": "Dead and Gone", "when": {"bloodied": True},
                            "summary": "Phase two: a storm of spores wraps her, and the first time she falls she surges once more.",
                            "text": "Storm of Spores: a 10-ft emanation round her, 1d10 necrotic and a DC 15 Con save or rot for anyone not hers who starts a turn there. Harvested Decay: the first time she drops to 0 Hit Points, a 120-ft surge (DC 15 Con or rot), every rotweaver dies, and she regains 1d12 Hit Points per rotweaver killed this way.",
                            "say": "hb_gorthos_phase2", "flag": "hb_gorthos_phase2"})
    write("data/monsters/beast_of_blight.json", m)


# ---- travel, cutscenes -----------------------------------------------------------------------------------------------------------------
def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if x["id"] != "hartsblight_forest"] + [
        {"id": "hartsblight_forest", "name": "The Hartsblight", "location": "hb_patient_commune", "spawn": "from_road", "pos": [0.13, 0.14], "region": "hartsblight_forest",
         "when": "flag.hb_asked or visited:hb_patient_commune", "summary": "A dead commune at the edge of a rotting forest, north-west of Moonsong Lake."}]
    t["roads"] = [x for x in t["roads"] if x["id"] != "wickermoor_to_hartsblight"] + [
        {"id": "wickermoor_to_hartsblight", "from": "wickermoor_village", "to": "hartsblight_forest", "hours": 32, "name": "The spore trail", "when": "flag.hb_asked or visited:hb_patient_commune"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


PICTURES = {
    "hb_sporefall": "Wickermoor's timber rooftops at night under what looks like snow, green-white flakes drifting through lamplight",
    "hb_sporefall_2": "A palm held up catching green-white flakes, beyond it a field of crops gone dark with rot and a villager's hunched back",
    "hb_circle": "Six gaunt antlered satyrs in a line at a tree line with drums and horns raised, two stag-bodied keepers lifting withered staves",
    "hb_circle_2": "A corpse in a dead commune bursting into a whirlwind of green spores under a crooked moon",
    "hb_keepers_end": "A world of trees, beasts and houses collapsing into rot",
    "hb_keepers_end_2": "Black nothing, then a flash of emerald and a pristine green wilderness",
    "hb_wood_vision": "A healthy ancient forest with a young woman dancing between the trees, laughing",
    "hb_wood_vision_2": "The same trees now black and shedding spores, the vision snapping",
    "hb_wilds_vision": "A rotting stag colossus seen from where someone kneels to eat it, only hands and flesh in view",
    "hb_wilds_vision_2": "A young woman lying dead beside the stag, then emerald light and her standing healthy in a green glade, smiling",
    "hb_heart_vision": "A gnarled oak with a hateful woman's face rotting into soil",
    "hb_heart_vision_2": "A sprout, a flash, and a radiant green elf-featured woman wreathed in emerald leaves",
    "hb_halden_torso": "A dead trapper's corpse shuddering against a carved beech tree in a mossy hollow",
    "hb_halden_torso_2": "Mould blooming over a torso as it is hauled up a trunk, its jaw hanging",
    "hb_gwenna_rises": "A churning green pool spilling ooze between leaning standing stones",
    "hb_gwenna_rises_2": "A mass of flesh and fungus standing in a humanlike shape, sheets of rot sliding off it",
    "hb_pool_memory": "A crystal pool in a ring of clean standing stones, a corpse held in someone's arms",
    "hb_pool_memory_2": "The body lowered into the water and the pool turning foul and erupting with spores",
    "hb_beast_revealed": "The gaunt top half of a satyr with long black hair hanging from a fungal cave wall",
    "hb_beast_revealed_2": "The wall tearing open as a colossal stag body of bone, blighted wood and fungus steps forward on cloven hooves",
    "hb_gorthos_dies": "A colossus of bone and fungus collapsing, its body running from green to brown to yellow sludge",
    "hb_gorthos_dies_2": "Motes drifting out of a cave mouth into the dark sky, toward another province",
    "hb_backstory": "Two young women walking hand in hand by the edge of a dark wood",
    "hb_backstory_2": "A satyr carrying a corpse into a hidden fungus-choked cave toward a dead stag the size of a barn",
    "hb_missionaries": "Patient Lady missionaries with sunflower lanterns setting off for the edge of a rotting forest",
    "hb_missionaries_2": "An Old Ways stag feast in a village square, antlers on poles, a goat watching with great calm",
}


def build_cutscenes():
    write("tools/content/hartsblight_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": PICTURES})
    for cid, desc in PICTURES.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("hb_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


# ---- Wickermoor's hooks ------------------------------------------------------------------------------------------------------------------
def build_village_hooks():
    path = ROOT / "data/locations/wickermoor_village.json"
    v = json.loads(path.read_text())
    v["npcs"] = [n for n in v["npcs"] if not str(n.get("dialogue", "")).startswith(HB)]
    pav = Place.__new__(Place); pav.rows = v["map"]["rows"]; pav.id = "wickermoor_village"
    pav.used = {tuple(n["cell"]) for n in v["npcs"]}
    pavilion = pav.snap((18, 11))
    rain = next(n for n in v["npcs"] if n["npc"] == "sister_rain")
    spore = pav.snap((19, 12))
    entries = [
        {"npc": "sister_rain", "cell": list(pavilion), "dialogue": HB + "hook:rain_start", "when": "flag.act2_done >= 5 and not flag.hb_asked and not flag.hb_refused", "facing": "east"},
        {"npc": "sister_rain", "cell": list(pavilion), "dialogue": HB + "hook:rain_again", "when": "flag.act2_done >= 5 and flag.hb_refused and not flag.hb_asked", "facing": "east"},
        {"npc": "sister_rain", "cell": rain["cell"], "dialogue": HB + "village_after:rain_report", "when": "flag.gorthos_slain and not flag.hb_rain_done"},
        {"npc": "sister_rain", "cell": rain["cell"], "dialogue": HB + "village_after:rain_garden", "when": "flag.hb_rain_done and flag.hb_garden_found and not flag.hb_garden_told"},
        {"npc": "sister_rain", "cell": rain["cell"], "dialogue": HB + "village_after:rain_sick", "when": "flag.hb_cloud_reached_village and not flag.gorthos_slain and flag.hb_asked"},
        {"npc": "brother_spore", "cell": list(spore), "dialogue": HB + "village_after:spore_after", "when": "flag.hb_rain_done", "facing": "west"},
    ]
    i = v["npcs"].index(rain)
    v["npcs"][i:i] = entries
    path.write_text(json.dumps(v, indent=2, ensure_ascii=False) + "\n")
    mp = ROOT / "data/locations/wickermoor_mayors_house.json"
    m = json.loads(mp.read_text())
    m["npcs"] = [n for n in m["npcs"] if not str(n.get("dialogue", "")).startswith(HB)]
    w = next(n for n in m["npcs"] if n["npc"] == "wendel_somerton")
    j = m["npcs"].index(w)
    m["npcs"][j:j] = [
        {"npc": "wendel_somerton", "cell": w["cell"], "dialogue": HB + "village_after:wendel_pay", "when": "flag.gorthos_slain and flag.hb_sporefall and not flag.hb_wendel_paid"},
        {"npc": "wendel_somerton", "cell": w["cell"], "dialogue": HB + "hook:wendel_offer", "when": "flag.hb_refused and not flag.hb_asked and days_since.hb_refused >= 1"},
    ]
    mp.write_text(json.dumps(m, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    for f in (build_commune, build_longhouse, build_altar, build_pines, build_outcrop, build_hollow, build_druids, build_ravine, build_quagmire, build_grove, build_wellspring, build_den):
        f()
    build_people()
    build_quests()
    build_items()
    build_monsters()
    build_travel()
    build_cutscenes()
    build_village_hooks()
    build_flags()
    print("ok")
