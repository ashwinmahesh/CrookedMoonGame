#!/usr/bin/env python3
"""ONE-SHOT (R19, Maidenmist Cemetery). Writes the cemetery's fifteen maps (tools/content/maidenmist_maps.py), its people, quests, items,
the Chained Reaper's Harrowing variant, cutscene definitions, the travel place, and Wickermoor's side of the chapter (the raid, Mori's request,
the epilogue). Dialogue is drafted by Gemini (maidenmist_dialogue.py + maidenmist_fill.py); the flag registry is scanned from what the data
and the dialogue use (`flags` step). Other lanes edit these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_maidenmist.py            # everything but the flags
    python3 tools/content/build_maidenmist.py flags      # data/flags/maidenmist.json, after the dialogue is written"""
import copy, json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import maidenmist_maps as M
from maidenmist_land import Land

ROOT = Path(__file__).resolve().parents[2]
REGION = M.REGION
MM = M.MM
prop, npc, area, exit_, monster = M.prop, M.npc, M.area, M.exit_, M.monster

# The chapter opens when the last of the other five Fallen is dead (Gorthos is Farryn, chapter 18). Each flag is read tolerantly: the
# lanes that build those chapters set them (names are the vault's); a test sets them directly.
HOOK = "flag.gorthos_slain and flag.raum_slain and flag.renathyr_slain and flag.lethica_slain and flag.briggsy_slain"


def write(rel, obj):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


def land_from(loc):
    rows = loc["map"]["rows"]
    L = Land(len(rows[0]), len(rows), 0)
    L.c = [list(r) for r in rows]
    return L


def find_prop(loc, pid):
    return next(p for p in loc["props"] if p["id"] == pid)


# ---- the maps and what the chapter adds to them -------------------------------------------------------------------------------------
def build_locations():
    locs = {}
    for b in M.BUILDERS:
        d = b()
        locs[d["id"]] = d
    for d in M.gravestone_pair():
        locs[d["id"]] = d

    gate = locs["mm_gate"]
    gate["props"].append(prop("mm_grammar_stone", (16, 22), "A headstone in a prissy hand", model="gravestone", call=MM + "folk:grammar_stone", approach=2))

    gardens = locs["mm_cremation_gardens"]
    for k, (x, y) in zip("abc", [(4, 12), (20, 12), (12, 20)]):
        gardens["props"].append(prop(f"mm_epitaph_{k}", (x, y), "A brick plaque with an epitaph the dead wrote for themselves", model="bronze_plaque",
                                     call=MM + f"folk:epitaph_plaque_{k}", approach=2, call_when="quest.epitaph_competition == asked"))
    gardens["npcs"].append(npc("tobias_dibbs", (13, 15), "folk:epitaph_judge", when="quest.epitaph_competition == asked and (flag.mm_epitaph_a_read or flag.mm_epitaph_b_read or flag.mm_epitaph_c_read)"))
    gardens["props"].append(prop("mm_walk_violet_prop", (11, 14), "Something under the brazier's foot", kind="decor", call=MM + "epilogue:walk_violet", approach=2,
                                 call_when="flag.mm_isolde_walk_started and not flag.mm_walk_violet"))

    potters = locs["mm_potters_field"]
    potters["props"].append(prop("mm_names_graves", (20, 14), "Three plain posts, each with a small token at its foot", model="stump", call=MM + "folk:names_graves", approach=2,
                                 call_when="quest.names_on_stones == asked"))

    crypts = locs["mm_highborn_crypts"]
    crypts["props"].append(prop("mm_walk_crimson_prop", (13, 14), "Something in the ash of the brazier", kind="decor", call=MM + "epilogue:walk_crimson", approach=2,
                                call_when="flag.mm_isolde_walk_started and not flag.mm_walk_crimson"))
    mounds = locs["mm_burial_mounds"]
    mounds["props"].append(prop("mm_walk_emerald_prop", (14, 15), "Something under the tree roots", kind="decor", call=MM + "epilogue:walk_emerald", approach=2,
                                call_when="flag.mm_isolde_walk_started and not flag.mm_walk_emerald"))
    sanct = locs["mm_shadestone_sanctuary"]
    sanct["props"] = [p for p in sanct["props"] if p["id"] != "mm_isolde_rest"] + [
        prop("mm_isolde_rest", (12, 18), "A place by the stones where the hound lies", kind="decor", call=MM + "epilogue:walk_end", approach=3,
             call_when="flag.mm_isolde_walk_sites >= 3 and not flag.mm_isolde_walk_done")]

    # the hub: Isolde's sixteen hours, the lurkers' fight, her farewell and walk
    hub = locs["mm_sepulcher"]
    hub["recheck_minutes"] = 30
    hub["npcs"] = [
        npc("isolde", (26, 26), "isolde:fades", approach=10, when="flag.yorgrim_with_party and minutes_since.isolde_alone_since >= 960 and not flag.isolde_faded and not flag.sepulcher_open"),
        npc("yorgrim", (24, 26), "yorgrim:meet", when="not flag.yorgrim_met"),
        npc("isolde", (26, 26), "isolde:door", when="not flag.isolde_faded and not flag.sepulcher_open"),
        npc("isolde", (26, 26), "isolde:farewell", when="flag.shroud_tear_sealed and flag.isolde_alive and not flag.isolde_faded and not flag.mm_isolde_farewelled"),
        npc("isolde", (26, 26), "epilogue:walk_ask", when="flag.mm_isolde_farewelled and flag.isolde_alive and not flag.isolde_faded and not flag.mm_isolde_walk_started and not flag.mm_isolde_walk_gone"),
        npc("isolde", (26, 26), "isolde:door", when="flag.shroud_tear_sealed and flag.isolde_alive and not flag.isolde_faded"),
        npc("yorgrim", (24, 26), "yorgrim:at_the_doors", when="flag.yorgrim_met and not flag.yorgrim_with_party and not flag.sepulcher_open and not flag.yorgrim_fallen"),
        npc("yorgrim", (24, 26), "yorgrim:doors_open", when="flag.sepulcher_open and not flag.yorgrim_descends and not flag.yorgrim_fallen"),
    ]

    # the Balefire Chamber's fight: ten shrouded minus the beacons' work (mm_chamber_n is set by descent:chamber)
    ch = locs["mm_balefire_chamber"]
    Lc = land_from(ch)
    kinds = ["shrouded_devourer", "shrouded_reaper", "shrouded_whisperer"]
    ch["encounters"] = []
    for n in range(1, 11):
        cells = M.spread(Lc, (10, 12), n, spacing=2, min_r=3, max_r=10, avoid={(10, 21)})
        ch["encounters"].append({"id": "mm_chamber", "trigger": "dialogue", "when": f"flag.mm_chamber_n == {n}", "flag": "mm_chamber_done",
                                 "monsters": [monster(kinds[i % 3], c, facing="south") for i, c in enumerate(cells)]})

    # the necrolisk, and a sicker one if the party mixed the herbs
    dp = locs["mm_necropolis_depths"]
    base = dp["encounters"][0]
    sick = copy.deepcopy(base)
    sick["id"] = "mm_necrolisk_sick"
    sick["monsters"][0]["hp"] = 118
    sick["monsters"][0]["name"] = "The necrolisk, heaving"
    dp["encounters"].append(sick)

    # the Harrowing runs on the tuned boss block below
    tomb = locs["mm_tomb"]
    tomb["props"].append(prop("mm_harrow_start", (10, 20), "The tomb floor, and the tear above the highest platform", kind="decor", call=MM + "descent:harrowing", approach=4,
                              call_when="flag.mm_tomb_door_open and not flag.mm_harrowing_begun"))
    tomb["encounters"][0]["monsters"][0]["monster"] = "chained_reaper_harrowing"

    for lid, d in locs.items():
        write(f"data/locations/{lid}.json", d)
    return locs


# ---- Wickermoor's side --------------------------------------------------------------------------------------------------------------
def prepend_npc(loc, npc_id, dialogue, when, approach=None, cell=None):
    path = ROOT / f"data/locations/{loc}.json"
    d = json.loads(path.read_text())
    d["npcs"] = [n for n in d["npcs"] if str(n.get("dialogue", "")) != MM + dialogue]
    base = next((n for n in d["npcs"] if n["npc"] == npc_id), None)
    c = cell or (base["cell"] if base else None)
    if c is None:
        raise SystemExit(f"{loc} has no {npc_id} to copy a square from; give a cell")
    e = {"npc": npc_id, "cell": list(c), "dialogue": MM + dialogue, "when": when}
    if approach:
        e["approach"] = approach
    i = d["npcs"].index(base) if base else 0
    d["npcs"].insert(i, e)
    path.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")


def open_near(rows, cell):
    x0, y0 = cell
    for r in range(0, 8):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                x, y = x0 + dx, y0 + dy
                if 0 <= y < len(rows) and 0 <= x < len(rows[y]) and rows[y][x] == ".":
                    return [x, y]
    return list(cell)


def build_village():
    path = ROOT / "data/locations/wickermoor_village.json"
    v = json.loads(path.read_text())
    rows = v["map"]["rows"]
    mine = {MM + n for n in ("raid:alarm", "raid:aftermath", "folk:hester", "epilogue:adela", "epilogue:weston", "epilogue:doris_after")}
    v["npcs"] = [n for n in v["npcs"] if n.get("dialogue") not in mine]
    doris = open_near(rows, (29, 27))
    first = 0
    new = [
        {"npc": "doris_squire", "cell": doris, "dialogue": MM + "raid:alarm", "approach": 9,
         "when": f"{HOOK} and not flag.mm_raid_started and (not flag.mm_raid_delay or minutes_since.mm_raid_delay >= 600)"},
        {"npc": "doris_squire", "cell": doris, "dialogue": MM + "raid:aftermath", "when": "flag.mm_raid_started and not flag.mm_raid_done"},
        {"npc": "hester_bolton", "cell": open_near(rows, (32, 28)), "dialogue": MM + "folk:hester", "when": "flag.mm_raid_done and not flag.mm_hester_paid"},
        {"npc": "adela_druskenvald", "cell": open_near(rows, (31, 24)), "dialogue": MM + "epilogue:adela", "when": "flag.shroud_tear_sealed and not flag.mm_epilogue_adela"},
        {"npc": "weston_murdoch", "cell": open_near(rows, (27, 25)), "dialogue": MM + "epilogue:weston", "when": "flag.shroud_tear_sealed and not flag.mm_epilogue_weston"},
        {"npc": "doris_squire", "cell": doris, "dialogue": MM + "epilogue:doris_after", "when": "flag.shroud_tear_sealed and not flag.mm_epilogue_doris"},
    ]
    v["npcs"][first:first] = new
    v["props"] = [p for p in v["props"] if p["id"] != "mm_postoffice_pigeons"]
    v["props"].append(prop("mm_postoffice_pigeons", [34, 9], "A hundred pigeons on the post office roof", kind="decor", call=MM + "epilogue:golub_tease", approach=6,
                           call_when="flag.shroud_tear_sealed and not flag.mm_epilogue_golub"))
    # the raid itself: eight ghasts in the streets round the Round (twelve once the militia has lost two nights)
    Lv = land_from(v)
    base_cells = M.spread(Lv, (30, 26), 12, spacing=2, min_r=4, max_r=12)
    v["encounters"] = [e for e in v["encounters"] if e.get("id") != "mm_raid"]
    for tag, n, cond in (("small", 8, "flag.mm_nights_delayed < 2"), ("big", 12, "flag.mm_nights_delayed >= 2")):
        mons = []
        for i in range(n):
            mons.append(monster("ghast", base_cells[i], "Gregor Bolton, hunched and shrieking" if (i == 0) else None, facing="south"))
        v["encounters"].append({"id": "mm_raid", "trigger": "dialogue", "when": cond, "flag": "mm_raid_fought", "monsters": mons})
    path.write_text(json.dumps(v, indent=2, ensure_ascii=False) + "\n")

    # the funeral home: Mori asks, returns, hubs; Tobias lives here
    fh = ROOT / "data/locations/wickermoor_funeral_home.json"
    f = json.loads(fh.read_text())
    mine = {MM + n for n in ("mori:request", "mori:return", "mori:hub", "folk:dibbs")}
    f["npcs"] = [n for n in f["npcs"] if n.get("dialogue") not in mine]
    mori = next(n for n in f["npcs"] if n["npc"] == "mori_shade")
    i = f["npcs"].index(mori)
    f["npcs"][i:i] = [
        {"npc": "mori_shade", "cell": mori["cell"], "dialogue": MM + "mori:return", "when": "flag.shroud_tear_sealed and not flag.mm_mori_return_told"},
        {"npc": "mori_shade", "cell": mori["cell"], "dialogue": MM + "mori:request", "when": "flag.mm_raid_done and not flag.mm_asked"},
        {"npc": "mori_shade", "cell": mori["cell"], "dialogue": MM + "mori:hub", "when": "flag.mm_asked and not flag.shroud_tear_sealed"},
        {"npc": "tobias_dibbs", "cell": open_near(f["map"]["rows"], (12, 9)), "dialogue": MM + "folk:dibbs", "when": "flag.mm_raid_done"},
    ]
    fh.write_text(json.dumps(f, indent=2, ensure_ascii=False) + "\n")

    # the three names: Holly, Old Rusty and Thomasin are told in their own places
    for loc, who, node, when in (("wickermoor_shop_bakery", "holly_aster", "folk:names_tell_holly", "quest.names_on_stones == asked and flag.mm_names_a and not flag.mm_names_told_a"),
                                 ("wickermoor_village", "old_rusty", "folk:names_tell_rusty", "quest.names_on_stones == asked and flag.mm_names_b and not flag.mm_names_told_b"),
                                 ("wickermoor_shop_tailor", "thomasin_ardor", "folk:names_tell_thomasin", "quest.names_on_stones == asked and flag.mm_names_c and not flag.mm_names_told_c")):
        p = ROOT / f"data/locations/{loc}.json"
        d = json.loads(p.read_text())
        d["npcs"] = [n for n in d["npcs"] if n.get("dialogue") != MM + node]
        base = next((n for n in d["npcs"] if n["npc"] == who), None)
        if base is None:
            raise SystemExit(f"{loc} has no {who}")
        d["npcs"].insert(d["npcs"].index(base), {"npc": who, "cell": base["cell"], "dialogue": MM + node, "when": when})
        p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")


# ---- people -------------------------------------------------------------------------------------------------------------------------
PEOPLE = [
    ("yorgrim", "Yorgrim", "The Gravedigger", "A deep-voiced orc ghost with a gravestone of names chained to his back and a balefire lantern in his fist; he follows the dead's ways and is cracking under the whispers.", "friendly",
     {"guest": True, "guest_fights": False, "tags": ["faction_none"]}),
    ("isolde", "Isolde", "A grim", "A black spectral hound with bright white eyes and a hooded lantern in her mouth, holding the sepulcher's door.", "friendly", {"tags": ["faction_none"]}),
    ("tobias_dibbs", "Tobias Dibbs", "Gravedigger's apprentice", "A cheerful, relentlessly practical lad who has been Mori Shade's apprentice for a year and has no feelings about it he can't use.", "friendly", {"tags": ["faction_none", "voice_hollow"]}),
    ("hester_bolton", "Hester Bolton", "A widow of sorts", "A proud Wickermoor wife whose husband Gregor is now a ghast, and who is annoyed that he still owes the landlord.", "indifferent", {"tags": ["faction_old_ways", "voice_hollow"]}),
]


def build_people():
    for (nid, name, title, summary, att, extra) in PEOPLE:
        d = {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION}
        d.update(extra)
        write(f"data/npcs/{nid}.json", d)


# ---- quests -------------------------------------------------------------------------------------------------------------------------
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
    write("data/quests/maidenmist_dead_rise.json", {
        "id": "maidenmist_dead_rise", "name": "The Dead Rise", "kind": "main", "region": "maidenmist_cemetery", "giver": "mori_shade",
        "summary": "Wickermoor's dead are walking out of Maidenmist Cemetery. Its gravedigger has gone silent, the beacons have gone dark, and the tear into the Shroud is growing.",
        "stages": [
            stage("dusk_of_the_dead", "Late in the Dusk Hour the bells rang and ghasts shrieked through Wickermoor. We fought them off beside Doris Squire's militia.", "Find out where the dead came from: ask Mori Shade at the funeral home.", ["Survive the raid", "Speak with Mori Shade"]),
            stage("corpse_road", "Mori Shade asked us to go to Maidenmist: the gates are chained, the fog thick, no beacon fires, no lantern. She sent us with grave salt.", "Take the road south-east to the cemetery gate and follow the Corpse Road up to the sepulcher.", ["Reach the cemetery gate", "Walk the Corpse Road"]),
            stage("gravedigger", "At the sepulcher's doors an orc ghost named Yorgrim and a black hound hold lanterns to the seam, burning back the mist.", "Speak with Yorgrim at the great doors.", ["Meet Yorgrim and Isolde"]),
            stage("beacons", "Yorgrim asked us to relight the five dark beacons with the final rites of the Fallen. The sepulcher doors will open when all six burn. Isolde can hold the door for sixteen hours.", "Take one of the seven paths to a beacon site, find its kindling, and perform the rite at the brazier. The Shadestone Stones are safe to rest.", ["Relight the Crimson beacon", "Relight the Violet beacon", "Relight the Amber beacon", "Relight the Magenta beacon", "Relight the Emerald beacon"]),
            stage("sepulcher", "All six beacons burn and the sepulcher's doors have opened onto a hall of coloured fire.", "Go through the great doors, and clear the collapsed passage at the far end of the Balefire Chamber.", ["Enter the Balefire Chamber"]),
            stage("undercroft", "The passage is clear, and below it lies the undercroft: a catacomb maze above a drake's cave.", "Find the way through the catacombs to the Stygian Descent. A fall leads to the necropolis depths, and the depths have a way on.", ["Cross the undercroft", "Reach the Stygian Descent"]),
            stage("harrowing", "Down a stair of screaming faces, Yorgrim opened the tomb's door and asked whether we were ready.", "Go into the Tomb of the Shrouded with Yorgrim.", ["Enter the tomb"]),
            stage("azure_rites", "Yorgrim broke under the tear and became the Chained Reaper. We destroyed him, and his voice asked us to perform his own rites.", "Honour Yorgrim at the lantern on the tomb floor: six words that land true will seal the tear.", ["Perform the Azure Rites"]),
            stage("done", "The tear is sealed. The depths' balefire is azure again, and the dead of Maidenmist lie quiet.", ends="success"),
        ]})
    write("data/quests/names_on_stones.json", {
        "id": "names_on_stones", "name": "Names on Stones", "kind": "side", "region": "maidenmist_cemetery", "giver": "mori_shade",
        "summary": "Three unmarked graves lie in the Potter's Field. Mori Shade wants each one matched to the villager who lost them.",
        "stages": [
            stage("asked", "Mori Shade has three unmarked graves in the Potter's Field and a ledger of grieving villagers. She wants each grave given a name.", "Study the three tokens at the posts in the Potter's Field, then tell the right villager. Mori can place them from her ledger if you cannot.", ["Study the three graves", "Tell the villagers", "Tell Mori"]),
            stage("done", "All three graves have names, and three villagers know where their dead are.", ends="success"),
            stage("lost", "The three posts stay blank. The field goes on forgetting.", ends="failure"),
        ], "closes": [{"stage": "lost", "from": ["asked"], "when": "flag.shroud_tear_sealed", "warn": "Mori's ledger will close with the tear.", "warn_when": "flag.chained_reaper_destroyed"}]})
    write("data/quests/isolde_walk.json", {
        "id": "isolde_walk", "name": "Isolde's Walk", "kind": "side", "region": "maidenmist_cemetery", "giver": "isolde",
        "summary": "With the tear sealed, the grim Isolde wants to walk the beacon sites at dusk and show what her master hid.",
        "stages": [
            stage("asked", "Isolde stands in the sepulcher's doorway, turning between the paths and back. She wants to walk the beacons.", "Follow Isolde to the Crimson, Violet and Emerald beacons, then to the Shadestone Stones.", ["Walk with Isolde", "Visit three beacons", "Reach the Shadestone Stones"]),
            stage("done", "At the Shadestone Stones Isolde found Yorgrim's last letter to Mori.", ends="success"),
            stage("gone_quiet", "Isolde stopped waiting. By morning her lantern had gone dark by the door.", ends="failure"),
        ]})
    write("data/quests/epitaph_competition.json", {
        "id": "epitaph_competition", "name": "The Epitaph Competition", "kind": "side", "region": "maidenmist_cemetery", "giver": "tobias_dibbs",
        "summary": "Mori Shade's apprentice has collected the dead's own epitaphs, which are too honest, and needs a winner.",
        "stages": [
            stage("asked", "Tobias Dibbs wants a verdict on the epitaphs the dead wrote for themselves, on the plaques in the Cremation Gardens.", "Read the plaques in the Cremation Gardens, then give Tobias your verdict by the fountain.", ["Read the plaques", "Choose a winner"]),
            stage("done", "A winner has been chosen, and the dead approve, or at least rustle.", ends="success"),
            stage("lost", "We called the contest off, and the plaques scraped their own words away overnight.", ends="failure"),
        ]})
    write("data/quests/doris_militia.json", {
        "id": "doris_militia", "name": "Doris's Militia", "kind": "side", "region": "wickermoor", "giver": "doris_squire",
        "summary": "Constable Doris Squire has four posts to hold against the ghasts and four volunteers. Assign the right person to each.",
        "stages": [
            stage("asked", "Doris has four posts (bell tower, south bridge, forge, funeral lane) and four volunteers: Howie Butterman, Hilda Brom, Jean Myriel and Siv Harga.", "Assign each volunteer to the post that suits them, then see the raid through.", ["Hold the bell tower", "Hold the south bridge", "Hold the forge", "Hold the funeral lane"]),
            stage("done", "The posts are manned, and Doris has said her piece.", ends="success"),
            stage("lost", "We left it to Doris, and the village noticed.", ends="failure"),
        ], "closes": [{"stage": "lost", "from": ["asked"], "when": "flag.mm_raid_started"}]})


# ---- items --------------------------------------------------------------------------------------------------------------------------
ITEMS = [
    ("mm_dried_rose", "Dried red rose", "quest", "A dried red rose, light as paper: the Crimson Beacon's kindling."),
    ("mm_owl_feather", "Barn owl feather", "quest", "A white barn owl feather: the Violet Beacon's kindling."),
    ("mm_straw_bundle", "Bundle of straw", "quest", "A dry bundle of straw tied with blue yarn: the Amber Beacon's kindling."),
    ("mm_rum_bottle", "Bottle of rum", "quest", "A corked bottle of rum: the Magenta Beacon's kindling."),
    ("mm_oak_branch", "Oak branch", "quest", "A dry oak branch laid like an offering: the Emerald Beacon's kindling."),
    ("mm_iron_chain", "Fifty feet of iron chain", "gear", "The gate's snapped chain, cold iron that shrouded will not cross."),
    ("grave_salt", "Grave salt", "gear", "A pouch of salt from Mori Shade's store; wipe a weapon with it and night creatures feel it."),
    ("mm_moth_wing", "A moth's wing", "gear", "A dried moth's wing, the size of a hand: a warding against a dream eater's hypnotic wings."),
    ("mm_lavender", "Lavender", "gear", "A bunch of lavender from the Cremation Gardens."),
    ("mm_lilies", "White lilies", "gear", "White lilies from the Cremation Gardens."),
    ("mm_nightshade", "Nightshade", "gear", "A sprig of nightshade from the Burial Mounds."),
    ("forbidden_apple", "Forbidden apple", "consumable", "A bright apple from a face-tree: magical, and not always kind."),
    ("necrolisk_slime", "Necrolisk slime", "consumable", "A jar of slime that traps a shrouded and eats into it; throw it."),
    ("yorgrims_letter", "Yorgrim's letter to Mori", "quest", "A packet in oilcloth: the gravedigger's last letter to the undertaker who learned his faith."),
]


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        d = {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary}
        if iid == "necrolisk_slime":
            d["stackable"] = True
            d["effects"] = [{"effect": "damage", "params": {"dice": "1d10", "damage_type": "force", "save": "dex", "dc": "15", "range": 30, "target": "creature"}}]
        write(f"data/items/{iid}.json", d)
    write("data/magic_items/shovel_of_yorgrim.json", {
        "id": "shovel_of_yorgrim", "name": "Shovel of Yorgrim", "source": {"book": "CrookedMoon", "note": "Fabled Heirloom from Maidenmist Cemetery; the book's numbers, our words."},
        "category": "weapon", "weight_lb": 10, "cost_gp": 0, "magic": {"rarity": "rare", "attunement": True}, "theme": "armaments", "icon": "club",
        "modifiers": [{"stat": "attack", "value": "tier", "when": {"item": "@self"}}, {"stat": "damage", "value": "tier", "when": {"item": "@self"}}],
        "powers": [{"id": "rest_the_dead", "name": "Gentle Repose", "spell": "gentle_repose", "min_level": 7, "uses": {"count": 1, "per": "dusk"}},
                   {"id": "ask_the_dead", "name": "Speak with Dead", "spell": "speak_with_dead", "min_level": 7, "uses": {"count": 1, "per": "dusk"}}],
        "summary": "A gravedigger's shovel as heavy as a greatclub (+1, +2 at level 7, +3 at 13): from level 7, Gentle Repose and Speak with Dead once a dusk each. (Its learn-an-undead's-defences, aura and Psychopomp wait on the engine's heirloom rules.)",
        "weapon": {"kind": "martial_melee", "damage": "1d12", "damage_type": "bludgeoning", "properties": ["heavy", "two_handed"], "mastery": "topple"}})
    write("data/magic_items/lantern_of_the_chained_reaper.json", {
        "id": "lantern_of_the_chained_reaper", "name": "Lantern of the Chained Reaper", "source": {"book": "CrookedMoon", "note": "Fabled Heirloom from Maidenmist Cemetery; the book's numbers, our words."},
        "category": "wondrous", "weight_lb": 2, "cost_gp": 0, "magic": {"rarity": "rare", "attunement": True}, "theme": "implements", "icon": "lantern",
        "modifiers": [{"stat": "check", "skill": "investigation", "value": "tier"}, {"stat": "check", "skill": "perception", "value": "tier"}],
        "powers": [{"id": "detect", "name": "Detect Magic", "spell": "detect_magic", "min_level": 7, "uses": {"count": 1, "per": "dusk"}},
                   {"id": "ray", "name": "Scorching Ray", "spell": "scorching_ray", "min_level": 10, "uses": {"count": 3, "per": "dusk"}},
                   {"id": "circle", "name": "Magic Circle", "spell": "magic_circle", "min_level": 10, "uses": {"count": 1, "per": "dusk"}}],
        "light": {"bright": 30, "dim": 30, "when": "held"},
        "summary": "A hooded lantern with a blue-green, fuel-free flame (30 ft bright, 30 dim): a growing bonus to Investigation and Perception; from level 7 Detect Magic, from 10 Scorching Ray (three a dusk) and Magic Circle. (Seeing the ethereal and its summoned ghost wait on the engine.)"})


# ---- the Chained Reaper, tuned for the Harrowing -------------------------------------------------------------------------------------------
def build_monsters():
    base = read("data/monsters/chained_reaper.json")
    m = copy.deepcopy(base)
    m["id"] = "chained_reaper_harrowing"
    m["name"] = "Yorgrim, the Chained Reaper"
    m["summary"] = base["summary"] + " The Harrowing's tune: Cold Iron at first, Cold Fire once Bloodied."
    m["phases"] = [{
        "id": "cold_fire", "name": "Cold Fire", "when": {"bloodied": True}, "legendary_resistance": "refill", "legendary_refill": True,
        "summary": "Azure Defiance: flickers of Yorgrim's azure light pass through him and the mist lashes out. Then his voice joins the chorus, the corrupted beacons burn stronger, and the fallen's effigies glow in their beacon colours.",
        "say": "mm_azure_defiance", "cutscene": "mm_azure_defiance", "flag": "mm_reaper_phase2",
        "traits_add": [
            {"id": "corrupted_beacons", "name": "Corrupted Beacons", "summary": "The eight braziers burn at DC 15, and ending a turn within 5 ft of one forces the save too."},
            {"id": "fallen_effigies", "name": "Fallen Effigies", "summary": "Five coffins on the platforms hold effigies of the Fallen; a Utilize action within 5 ft of a brazier puts one in, cleansing it and wounding the Reaper (engine hook)."},
            {"id": "devouring_balefire", "name": "Devouring Balefire", "summary": "A creature starting its turn within 10 ft of the Reaper makes a DC 15 Constitution save or takes 1d6 necrotic."}]}]
    write("data/monsters/chained_reaper_harrowing.json", m)


# ---- cutscenes, travel, flags ----------------------------------------------------------------------------------------------------------
PICTURES = {
    "mm_dusk_of_the_dead": ["The clock tower of a village with its bell swinging, street lamps going out one by one in the dusk",
                            "Hunched figures in grave rags crouched over a body in a doorway, a moon like a crone's face above"],
    "mm_broken_gate": ["A tall iron fence of prison-bar pickets running off into fog, a gate hanging bent outward between two hooded iron reapers",
                       "Thousands of grave markers climbing hills into blue-green mist, as far as the eye goes"],
    "mm_gravedigger_door": ["The great moss-grown sepulcher with huge double doors, an orc ghost hunched under a chained headstone and a black hound with white eyes both holding lanterns to the seam",
                            "Mist tendrils writhing out of a crack in stone doors and burning away in azure lantern light, six iron sconces above, five of them dark"],
    "mm_beacon_lit": ["A brazier roaring up in coloured flame with kindling burning in it, mist rolling back across a graveyard",
                      "Far away, a sconce above great stone doors catching fire in the same colour, seen through fog"],
    "mm_isolde_fades": ["A black hound with white eyes alone at stone doors, her lantern guttering",
                        "A door seam with grey mist pouring out, a lantern lying on the steps"],
    "mm_penitent_pilgrim": ["A young orc seer leading a ritual in a stone circle, his clan gathered around him at night",
                            "The same stone circle empty, ash and light streaming up into the sky, a lone figure dragging a huge stone of names down a long road"],
    "mm_six_beacons": ["The sepulcher doors framed by six coloured flames, crimson violet amber magenta emerald azure",
                       "An orc ghost seen from behind before the doors, fainter and more hollow, his lantern smaller"],
    "mm_stygian_descent": ["A spiral stair whose walls are thousands of carved screaming faces, sconces burning sick blue-green",
                           "Stone doors carved with a hooded woman holding a lantern, at the end of a hall of wailing faces"],
    "mm_harrowing": ["A twenty-foot tear of churning mist above a hanging platform, an orc ghost translucent below it raising his lantern",
                     "A colossal hooded reaper with a scythe of blue-green fire and a gravestone on its back, skeletal eyes, chains falling from the dark"],
    "mm_azure_defiance": ["Flickers of azure light inside a colossal chained reaper, the mist lashing out",
                          "Five stone coffins glowing in five colours on raised platforms, in a cavern of blue-green fire"],
    "mm_tear_sealed": ["A lantern blazing white-blue until the frame washes out, a ring of mist collapsing into it",
                       "A calm cavern in azure light, the ceiling whole, no tear, an empty lantern on the floor"],
    "mm_isolde_farewell": ["A black hound at the sepulcher steps with a lantern in her mouth, looking toward the south-west",
                           "The same hound sitting alone by the doors under six burning sconces"],
}


def build_cutscenes():
    pics = {}
    for cid, (a, b) in PICTURES.items():
        pics[cid], pics[cid + "_2"] = a, b
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("mm_", "").replace("_", " ").capitalize(), "summary": a,
                                             "images": [{"image": cid, "when": ""}, {"image": cid + "_2", "when": ""}]})
    write("tools/content/maidenmist_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": pics})


def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if x["id"] != "maidenmist_gate"] + [
        {"id": "maidenmist_gate", "name": "Maidenmist Cemetery", "location": "mm_gate", "spawn": "from_road", "pos": [0.66, 0.72], "region": "maidenmist_cemetery",
         "when": "flag.mm_asked or visited:mm_gate", "summary": "A fogbound cemetery behind a bent iron gate, south-east of Wickermoor."}]
    t["roads"] = [x for x in t["roads"] if x["id"] != "wickermoor_to_maidenmist"] + [
        {"id": "wickermoor_to_maidenmist", "from": "wickermoor_village", "to": "maidenmist_gate", "hours": 5, "name": "The cemetery road", "when": "flag.mm_asked or visited:mm_gate"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


FLAG_NOTES = {
    "gorthos_slain": "Gorthos (Farryn, chapter 18) is dead; set by the Hartsblight lane. Read here to open the chapter.",
    "renathyr_slain": "Sir Marius Renathyr (chapter 14) is dead. Read tolerantly: set by that chapter's lane.",
    "lethica_slain": "Lethica Nightborne (chapter 17) is dead. Read tolerantly: set by that chapter's lane.",
    "briggsy_slain": "Captain Briggsy Kratch (chapter 15) is dead. Read tolerantly: set by that chapter's lane.",
    "beacon_crimson": "0 unlit, 1 glowing, 2 blazing, 3 roaring (the Crimson Beacon).", "beacon_violet": "0 unlit, 1 glowing, 2 blazing, 3 roaring (the Violet Beacon).",
    "beacon_amber": "0 unlit, 1 glowing, 2 blazing, 3 roaring (the Amber Beacon).", "beacon_magenta": "0 unlit, 1 glowing, 2 blazing, 3 roaring (the Magenta Beacon).",
    "beacon_emerald": "0 unlit, 1 glowing, 2 blazing, 3 roaring (the Emerald Beacon).",
    "sepulcher_open": "All five dark beacons are lit: the sepulcher doors open.", "shroud_tear_sealed": "The tear into the Shroud is sealed (the Azure Rites are done).",
    "chained_reaper_destroyed": "The Chained Reaper is destroyed; chapter 20's hook (Golub moves) reads this.", "fallen_yorgrim_dead": "Yorgrim, the sixth Fallen, is gone for good.",
    "necrolisk_slain": "The necrolisk of the necropolis depths is dead.", "yorgrim_fallen": "Yorgrim broke under the tear.",
    "isolde_faded": "Isolde was left alone past sixteen hours and faded.", "isolde_alone_since": "The game minute Isolde was left to hold the door (a clock: set = now).",
    "mm_nights_delayed": "Nights the party ignored the raid in Wickermoor (the militia pays; capped at four).", "mm_raid_delay": "The game minute the party last let the militia hold (a clock).",
    "mm_chamber_n": "Shrouded left in the Balefire Chamber after the beacons' work (10 minus 2 per roaring and 1 per blazing).",
    "mm_soul_fragments": "Soul fragments offered to restart a rite.", "mm_rite_fails": "Rites whose flame died; a second one makes Yorgrim spend more of himself.",
    "mem_marius_feats": "The party learned of Marius's feats (chapter 14). Read by the Crimson rite for Advantage.", "mem_marius_oath": "The party learned of Marius's oath and king (chapter 14).",
    "mem_marius_love": "The party learned of the woman who calmed Marius (chapter 14).", "mem_lethica_healing": "The party learned of Lethica's healing (chapter 17).",
    "mem_lethica_love": "The party learned of Lethica's love for Marius (chapter 17).", "mem_lethica_hymns": "The party learned of the Nightmother's hymns (chapter 17).",
    "mem_jericho_songs": "The party learned Jericho's songs (chapter 13).", "mem_jericho_tales": "The party learned Jericho's tall tales (chapter 13).", "mem_jericho_craft": "The party learned of Jericho's handiwork (chapter 13).",
    "mem_briggsy_exploits": "The party learned of Briggsy's exploits (chapter 15).", "mem_briggsy_ruses": "The party learned of Briggsy's footwork and ruses (chapter 15).", "mem_briggsy_luck": "The party learned of Briggsy's luck and sorcery (chapter 15).",
    "mem_farryn_circle": "The party learned of Farryn's circle and the Old Ways (chapter 18).", "mem_farryn_forest_love": "The party learned of Farryn's love of beasts and growing things (chapter 18).",
    "mem_farryn_gwenna": "The party learned of Farryn's love for Gwenna (chapter 18).", "mem_farryn_greenwood": "The party learned that 'Greenwood' carved in the gloomwood hurts it (chapter 18).",
}


FOREIGN = {"gorthos_slain", "renathyr_slain", "lethica_slain", "briggsy_slain"} | {m for t in ("marius_feats", "marius_oath", "marius_love", "lethica_healing", "lethica_love", "lethica_hymns", "jericho_songs", "jericho_tales",
           "jericho_craft", "briggsy_exploits", "briggsy_ruses", "briggsy_luck", "farryn_circle", "farryn_forest_love", "farryn_gwenna", "farryn_greenwood") for m in ("mem_" + t,)}


def build_flags():
    registered = set()
    for f in (ROOT / "data/flags").glob("*.json"):
        if f.name == "maidenmist.json":
            continue
        registered |= {x["id"] for x in json.loads(f.read_text())["flags"]}
    texts = []
    for f in (ROOT / "narrative/maidenmist").glob("*.dialogue"):
        texts.append(f.read_text())
    for f in (ROOT / "data").rglob("*.json"):
        if f.parent.name in ("locations", "quests", "travel", "monsters") and f.name.startswith(("mm_", "wickermoor", "maidenmist", "chained")):
            texts.append(f.read_text())
    blob = "\n".join(texts)
    names = set(re.findall(r"\bflag\.([a-z][a-z0-9_]*)", blob)) | set(re.findall(r"^\s*set\s+([a-z][a-z0-9_]*)", blob, flags=re.M))
    names |= set(re.findall(r'"flag":\s*"([a-z][a-z0-9_]*)"', blob)) | set(re.findall(r"\b(?:minutes_since|days_since)\.([a-z][a-z0-9_]*)", blob))
    ints = set(re.findall(r"flag\.([a-z][a-z0-9_]*)\s*(?:==|!=|>=|<=|>|<)", blob)) | set(re.findall(r"^\s*set\s+([a-z][a-z0-9_]*)\s*(?:\+=|-=|=\s*(?:\d+|now)\b)", blob, flags=re.M))
    ints |= set(re.findall(r"\b(?:minutes_since|days_since)\.([a-z][a-z0-9_]*)", blob))
    mine = sorted(n for n in names if n not in registered and not n.startswith(("mm_epilogue_x",)))
    out = []
    for n in mine:
        note = FLAG_NOTES.get(n)
        if note is None:
            note = "Maidenmist Cemetery (R19) story state."
        e = {"id": n, "type": "int" if (n in ints or n.startswith("beacon_")) else "bool", "summary": note, "read_later": True}
        if n in FOREIGN:
            e["set_by"] = "engine"
            e["summary"] = note + " (Registered here as set_by engine so R19 can read it before the owning chapter exists: that chapter's lane registers and sets it for real and removes this entry.)"
        out.append(e)
    write("data/flags/maidenmist.json", {"flags": out})
    print("flags:", len(out))


if __name__ == "__main__":
    if sys.argv[1:] == ["flags"]:
        build_flags()
    else:
        build_locations()
        build_people()
        build_quests()
        build_items()
        build_monsters()
        build_travel()
        build_cutscenes()
        build_village()
        print("ok")
