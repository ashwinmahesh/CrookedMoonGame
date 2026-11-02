#!/usr/bin/env python3
"""ONE-SHOT (R20, The Roving Rookery). Writes the chapter as data: the walking dovecote (two floors), four roost maps, the quests (the main one and
five Wickermoor-hysteria side quests), people, items, flags, cutscene definitions and the travel places and roads, and EDITS the Wickermoor
hub additively so it changes shape while the charm holds (mob patrols, locked doors, shuttered shops, a jail beat, the Powder Keg's victims).
The hub edits are idempotent: every entry this script adds is recognisable (dialogue under `rookery/`, ids starting `rk_`) and is replaced, never
duplicated, so it may be re-run after other lanes touch the same files. Dialogue is drafted in rookery_dialogue.py (specs) + rookery_fill.py
(Gemini), not here.
    python3 tools/content/build_rookery.py"""
import json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G
from heirlooms_kept import kept

ROOT = Path(__file__).resolve().parents[2]
RK = "rookery/"
REGION = "wickermoor"

# ---- the conditions the whole chapter shares --------------------------------------------------------------------------------------
HYST = "flag.hysteria_began and not flag.golub_dead"          # the charm is on: the village is hostile until Golub dies
NOHYST = "(not flag.hysteria_began or flag.golub_dead)"
HOOK = "flag.gorthos_slain and flag.raum_slain and flag.renathyr_slain and flag.lethica_slain and flag.grinning_sinner_slain"
KEG1 = "flag.hysteria_began and days_since.hysteria_began >= 7"
KEG2 = "flag.hysteria_began and days_since.hysteria_began >= 14"


def write(rel, obj):
    if kept(rel):   # (a floor of a place merged into one with its floors: merge_floors.py)
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
        d["dialogue"] = RK + dialogue
    d.update(kw)
    return d


def area(aid, name, a, b, **kw):
    d = {"id": aid, "name": name, "cells": [list(a), list(b)]}
    d.update(kw)
    return d


def exit_(eid, cell, to, spawn, label, **kw):
    d = {"id": eid, "cell": list(cell), "to": to, "label": label}
    if spawn:
        d["spawn"] = spawn
    d.update(kw)
    return d


def monster(mid, cell, name=None, **kw):
    d = {"monster": mid, "cell": list(cell)}
    if name:
        d["name"] = name
    d.update(kw)
    return d


def container(cid, cell, label, items=(), gold=0, **kw):
    d = {"id": cid, "cell": list(cell), "label": label, "items": [{"id": i, "qty": q} for i, q in items], "gold": gold}
    d.update(kw)
    return d


def stage(sid, journal, hint=None, objectives=None, ends=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    return d


# ---- people -----------------------------------------------------------------------------------------------------------------------
PEOPLE = [   # id, name, title, summary, attitude, monster
    ("golub_graygullet", "Golub Graygullet", "The Pigeon Hag", "The eldest of the Vermintoll Coven: vain, sneering, and seventy years a postmaster in other women's skins.", "hostile", "pigeon_hag"),
    ("wynn_carter", "Wynn Carter", "The new postmaster", "A broad young inn hand who took the post office keys because nobody else would, and sorts letters with enormous care.", "friendly", None),
    ("rk_mob_a", "A torch-bearing mob", "Charmed villagers", "A knot of neighbours with torches and one thought, glassy-eyed under the charm.", "hostile", "tough"),
    ("rk_mob_b", "A cudgel-bearing mob", "Charmed villagers", "Neighbours with cudgels, walking the lane in step.", "hostile", "tough"),
    ("rk_mob_c", "A pitchfork mob", "Charmed villagers", "Farmers with pitchforks, all chanting the same name.", "hostile", "tough"),
    ("rk_mob_round", "The mob at the Round", "Charmed villagers", "A crowd round the Oak of Many Faces, waiting for a trial.", "hostile", "tough"),
    ("rk_posse_a", "A deputy of the posse", "Charmed villager", "A neighbour in a constable's armband, lilac-glinting and furious.", "hostile", "tough"),
    ("rk_posse_b", "A deputy of the posse", "Charmed villager", "A neighbour in a constable's armband, lilac-glinting and furious.", "hostile", "tough"),
]


def build_people():
    for (nid, name, title, summary, att, mon) in PEOPLE:
        d = {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": REGION, "tags": ["voice_hollow"]}
        if mon:
            d["monster"] = mon
        write(f"data/npcs/{nid}.json", d)


# ---- quests -----------------------------------------------------------------------------------------------------------------------
def build_quests():
    write("data/quests/roving_rookery.json", {
        "id": "roving_rookery", "name": "The Roving Rookery", "kind": "main", "region": REGION, "giver": "geneva_fairchild",
        "summary": "With the Fallen gone, the postmaster makes her move: a murder pinned on the party, a village gone mad, and a dovecote that walks.",
        "stages": [
            stage("plea", "Geneva Fairchild came running with a white face: Theodora is dead in the post office, and the constable will blame the first stranger she sees.", "Go with Geneva to the post office and look at the body.", ["Go to the post office"]),
            stage("exposed", "Theodora was never a woman at all: the party named the postmaster, and she left her skin behind and her dovecote walked off over the roofs. Whatever she planned, it will not wait.", "Watch the post, and watch the road. The valley will turn on you the moment the last of the Fallen is gone.", ["Wait for her move"]),
            stage("crime_scene", "In the post office lie Theodora Mayville's skin and boneless remains. Geneva hangs back by the door, very quiet.", "Look at the body, and look hard at Geneva.", ["Examine the body", "Question Geneva"]),
            stage("posse", "'Geneva' shrieked murder, burst into feathers and left an empty skin on the boards. Out the north window the dovecote stood up on pigeon legs and walked away. Now a posse is at the door with a forged letter.", "Deal with the posse at the post office door: talk, run, give up, or fight.", ["Face the posse"]),
            stage("jailed", "We woke in the constable's cells, our gear locked away. The trial is at the next Witching Hour, and the mob is already chanting under the window.", "Get out of the cell before the Witching Hour: there are six ways, and most need no roll.", ["Escape the cell before the trial"]),
            stage("hysteria", "Wickermoor is hostile to its bones. Doors are barred, shops shuttered, mobs walk the lanes, and every roof is grey with pigeons. The charm will not lift until Golub is dead.", "Find where the dovecote has settled. Look at the sky from the estate road, ask Hilda, or question Albert.", ["Find the dovecote"]),
            stage("hunt", "Golub's dovecote moves between four roosts, three nights from town, and it takes wing when Albert spots us. Every night it stays, the village tears itself further apart.", "Reach a roost without Albert seeing: watch the pigeons' flight, read the tracks, or walk the circuit.", ["Reach the dovecote"]),
            stage("dovecote", "We are inside the walking dovecote. Parcels and pigeons below; Golub's roost above.", "Climb to the roost floor and end Golub.", ["Defeat Golub Graygullet"]),
            stage("done", "Golub Graygullet is dead and the dovecote has settled for good. The charm broke like a held breath, and Wickermoor woke up dazed and ashamed.", ends="success"),
        ]})
    side = [
        ("quiet_door", "The Quiet Door", "marianna_grey", "Marianna Grey is hiding a neighbour in the stable loft, and the mob is two streets away.",
         [stage("asked", "Marianna Grey whispered that she is hiding Mrs. Oakum in the stable loft. The mob has her name, and Marianna needs her out of the village.", "Get Mrs. Oakum from the stable to the Druskenvald Estate without the mob seeing: the lane, the Round's edge, the moor road.", ["Take Mrs. Oakum to the estate"]),
          stage("delivered", "Mrs. Oakum is safe behind the estate's crooked walls, and Marianna can breathe again.", ends="success"),
          stage("moot", "The charm broke before the escort could be finished. Mrs. Oakum walked home in daylight, and Marianna still has the pitchfork she lent her.", ends="success"),
          stage("taken", "The mob got Mrs. Oakum. They have her in the constable's cells now, and Marianna will not look at us.", ends="failure")]),
        ("doris_poetry", "Doris Writes Poetry", "ambrose_quill", "A sheet of the constable's secret verse has fallen into the poet's hands, and Ambrose Quill has opinions.",
         [stage("asked", "Ambrose Quill, reciting to a mob that has stopped to listen, says someone in the village writes better verse than he does, and he means to find out who.", "Find the verse: the constable's desk is in her station, and the station is shut.", ["Find the anonymous poems"]),
          stage("poem_found", "In a drawer of Doris Squire's desk lie twenty neat poems about the moor, a lost sister, and the Patient Lady. They are good.", "When the charm lifts, bring Ambrose Quill to Doris.", ["Bring Ambrose Quill to Doris"]),
          stage("met", "Ambrose Quill read Doris her own best poem aloud, and the constable said four words, which for her is a speech.", ends="success"),
          stage("burned", "The poems burned in the station's stove before anyone could say what they were.", ends="failure")]),
        ("jury_of_pigeons", "A Jury of Pigeons", "tamsin_ledger", "Tamsin Ledger will not allow a mob to try anyone without a quorum, a docket and sworn witnesses, and the only witnesses are pigeons.",
         [stage("asked", "Tamsin Ledger is auditing the mob from a crate and has found it out of order: no quorum, no docket, no sworn witnesses. She needs a jury, and every free party member has just been drafted.", "Help Tamsin hold the hearing: a docket from Wendel, a quorum, and an oath from the pigeons.", ["Get the docket", "Seat a quorum", "Swear the pigeons"]),
          stage("sitting", "The hearing is in session on the Founder's Round. The mob sits in rows, bewildered, while Tamsin reads out the charges against a pigeon.", "See the hearing through.", ["Finish the hearing"]),
          stage("done", "The mob adjourned for the night, charm and all, because Tamsin refused to let anyone leave before the minutes were read.", ends="success"),
          stage("moot", "The charm broke before the hearing could sit. Tamsin filed the minutes of the hearing that did not happen, and the pigeons were discharged without a stain.", ends="success"),
          stage("abandoned", "Tamsin was left holding a docket and a gavel, and the mob ran her hearing right over.", ends="failure")]),
        ("forms_for_the_end", "Forms for the End of the World", "wendel_somerton", "Mayor Somerton insists the village's last forms be stamped in triplicate before the world may end.",
         [stage("asked", "Mayor Somerton has set up a desk in the Founder's Round and wants three forms stamped before the hysteria may officially proceed: 14-B, 22, and a Writ of Passage.", "Get the three stamps: the clock-chamber stamp, the schoolhouse seal, and the constable's. Forge one if you must.", ["Collect the three stamps"]),
          stage("stamped", "The forms are in order, or look it. Wendel will issue the Writ of Passage.", "Take the forms back to the mayor.", ["Deliver the forms"]),
          stage("done", "Wendel issued a Writ of Passage that no mob can ignore without filling in a form first.", ends="success"),
          stage("moot", "The charm broke before the last stamp was found. Wendel filed the three forms anyway, and the world, strictly, did not end.", ends="success"),
          stage("forged", "A forged stamp, a sharp-eyed deputy, and a short stay in the cells for the party.", ends="failure")]),
        ("powder_keg_ledger", "The Powder Keg Ledger", "weston_murdoch", "Weston Murdoch keeps a ledger of who the hysteria will take, and he wants to cross names off before the seventh dawn.",
         [stage("asked", "Weston Murdoch showed us his ledger: on the seventh dawn of the charm a neighbour dies and a house burns, and the toll doubles every week after. He has names for the first two weeks.", "Protect who you can: hide Jeremiah Stover at the estate, and wet the schoolhouse roof before the seventh dawn.", ["Save Jeremiah Stover", "Save the schoolhouse"]),
          stage("done", "The ledger has a name crossed out. The village still burned, but not as much.", ends="success"),
          stage("moot", "The charm broke before the seventh dawn, and the ledger was never needed. Weston closed it, and wept a little.", ends="success"),
          stage("burned", "The seventh dawn came, and the ledger's first names were not crossed out.", ends="failure")]),
    ]
    for qid, name, giver, summary, stages in side:
        write(f"data/quests/{qid}.json", {"id": qid, "name": name, "kind": "side", "region": REGION, "giver": giver, "summary": summary, "stages": stages})


# ---- items ------------------------------------------------------------------------------------------------------------------------
ITEMS = [
    ("rk_letter_theodora", "A letter for Theodora Mayville", "quest", "A letter addressed in your own hand to the postmaster, ready for a bird to deliver."),
    ("rk_forged_letter", "The forged letter of accusation", "quest", "Doris's letter naming the party as the postmaster's killers. The ink smells faintly of pigeon."),
    ("rk_improvised_picks", "Improvised lockpicks", "tool", "Two bent nails and a hairpin, scraped out of the cell floor."),
    ("rk_cell_key", "A cell key", "quest", "A heavy iron key, dropped through the cell window by something with wings."),
    ("rk_writ_of_passage", "A Writ of Passage", "quest", "A form in triplicate, stamped in three colours, which no mob can ignore without first filling in a form."),
    ("rk_doris_poems", "Doris Squire's poems", "quest", "Twenty neat sheets in a square hand: the moor, a lost sister, and the Patient Lady."),
    ("rk_button_ledger", "Pip's button receipt", "quest", "A scrap marked 'good for one safe passage' in a child's careful hand."),
    ("rk_docket", "Tamsin's docket", "quest", "A ruled sheet headed ORDER OF PROCEEDINGS, with every line blank."),
    ("rk_stamp_clock", "The clock-chamber stamp", "quest", "A rubber stamp reading TIME OF THE ESSENCE."),
    ("rk_stamp_school", "The schoolhouse seal", "quest", "A brass seal showing an open book and a rather stern owl."),
    ("golubs_diary", "Golub's diary", "quest", "Seventy years of a hag's neat, vain hand: where everyone in the hollow lives and works, and what they would pay to hide."),
    ("toy_riverboat", "The Toy Riverboat", "wondrous", "A toy boat that shrinks its owner and a dozen friends to sail any water, twelve hours a day, with a haunting curse on leaving it (its powers wait on the engine's heirloom rules)."),
    ("midnight_tears", "A dose of Midnight Tears", "tool", "A single dose of a poison that kills slowly, taken from Golub's roost."),
    ("golub_crystal_ball", "A crystal ball", "treasure", "A ball of flawless crystal, worth a thousand gold and no more than a Scrying focus."),
    ("golub_birdcage", "A gold birdcage", "treasure", "A tall gold birdcage with a cooing, empty perch, worth five hundred gold."),
    ("skitterdeep_nuggets", "A chest of Skitterdeep nuggets", "treasure", "A small chest of raw gold nuggets from the mine, worth a thousand gold."),
]


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary})


# ---- cutscenes (placeholder pictures; the real ones are queued) -------------------------------------------------------------------
PICTURES = {
    "rk_master_stroke": "Inside a cluttered post office, a sobbing young woman's shadow on the floor shows a beaked head and a puffed-up throat",
    "rk_master_stroke_2": "A young woman folding in on herself in a burst of grey feathers, an empty skin settling on the floorboards",
    "rk_master_stroke_3": "Through a window, a round dovecote rocking, rising on two huge scaly pigeon legs and hopping away over the roofs toward the moors",
    "rk_village_turns": "The village green full of torches, an oak with carved faces lit from below, a constable holding up a letter",
    "rk_village_turns_2": "Rows of pigeons along every roof ridge, all their heads turning together toward the viewer",
    "rk_rookery_horizon": "A moor at dusk with a tiny dovecote striding along the skyline on pigeon legs",
    "rk_rookery_horizon_2": "A muddy three-toed footprint the size of a cart, filling with rain",
    "rk_home_to_roost": "A dovecote's legs folding under it and its wings pulling back into the thatch as it thumps down for good",
    "rk_home_to_roost_2": "A dead pigeon-man in the straw of a dovecote floor, one human ear turned up to the rafters",
    "rk_home_to_roost_3": "A village street at morning with townsfolk standing blinking in the daylight, someone hanging the first strand of festival bunting",
}


def build_cutscenes():
    write("tools/content/rookery_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": PICTURES})
    for cid, desc in PICTURES.items():
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": cid.replace("rk_", "").replace("_", " ").capitalize(), "summary": desc, "images": [{"image": cid, "when": ""}]})


# ---- the walking dovecote ---------------------------------------------------------------------------------------------------------
ROOSTS = [   # key, n, name, pos on the travel map, theme, summary
    ("prairie", 0, "Rolling Prairie", (0.84, 0.52), "forest", "Gold-grey grass under a big sky, with the dark shape of the dovecote squatting in it."),
    ("swamp", 1, "Murky Swamp", (0.88, 0.90), "forest", "Green-black water, dead trees and reeds, and a dovecote standing in the shallows."),
    ("foothills", 2, "Barren Foothills", (0.40, 0.12), "forest", "Bare rock and scree under the Howlers, with the dovecote high on a rise."),
    ("lakeshore", 3, "Stormy Lakeshore", (0.06, 0.44), "forest", "A rainy shingle beach on Moonsong Lake's north shore, and the dovecote on the stones."),
]


def build_dovecote():
    # R1, the parcel store
    g = G(20, 14).room(1, 1, 18, 12)
    g.fill(2, 2, 5, 4, "~").fill(13, 7, 17, 10, "~").fill(2, 10, 6, 10, "=").put([(15, 2), (16, 2), (17, 2)], "=")
    r1 = {"id": "rk_dovecote_r1", "name": "The Dovecote: the Parcel Store", "region": REGION, "summary": "The ground floor of the walking dovecote: crates and letters and a constant cooing.",
          "text": "The inside of a round dovecote: straw, seed, feathers, crates piled in drifts of letters, and a ladder going up to the roost.",
          "map": {"rows": g.rows(), "theme": "manor", "light": "dim", "outdoors": False},
          "areas": [area("r1_floor", "The parcel store", (1, 1), (18, 12))],
          "spawns": {"default": [10, 11], "from_r2": [10, 2]},
          "exits": [exit_("ladder_up", (10, 0), "rk_dovecote_r2", "from_r1", "Up the ladder to the roost floor")] + [
              exit_(f"door_{k}", (10, 13), f"rk_roost_{k}", "from_dovecote", "Out through the door", when=f"flag.dovecote_roost == {n}") for (k, n, *_r) in ROOSTS],
          "doors": [], "props": [
              prop("rk_r1_nest", (3, 11), "Albert's nest of stolen ribbon", model="hay_bale", text="A nest woven from ribbon, hair and tickets, with a very small mirror in it."),
              prop("rk_r1_seed", (16, 4), "Sacks of seed", model="sack_pile"),
              prop("rk_r1_letters", (8, 6), "Drifts of undelivered letters", model="letters", text="Letters by the hundred, many opened and re-sealed, a good few addressed to the dead."),
              prop("rk_r1_cord", (12, 11), "Coils of leather cord", model="rope_coils"),
              prop("rk_r1_window", (5, 6), "A round window, with the moor moving past", kind="decor", model="window"),
          ],
          "containers": [
              container("pkg1", (8, 2), "Package 1", [("gold_pocket_watch", 1)], 0),
              container("pkg2", (10, 2), "Package 2", [], 12),
              container("pkg3", (12, 2), "Package 3", [("mirror", 1)], 0),
              container("pkg4", (8, 4), "Package 4", [], 240),
              container("pkg5", (10, 4), "Package 5", [("alchemists_supplies", 1), ("herbalism_kit", 1), ("healers_kit", 1), ("potion_of_healing", 2)], 0),
              container("pkg6", (12, 4), "Package 6", [], 0),
              container("pkg7", (14, 4), "Package 7", [], 0),
              container("pkg8", (16, 6), "Package 8", [("toy_riverboat", 1)], 0),
          ],
          "encounters": [
              {"id": "rk_parcels", "trigger": "enter_area:r1_floor", "when": "not flag.albert_dead and not flag.rk_parcels_done", "flag": "rk_parcels_done", "text": "The crates stir; wings and a wet little voice from the rafters.",
               "monsters": [monster("vermin_familiar_pigeon", (4, 6), "Peeping Albert", facing="east"), monster("squabswarm", (16, 3), "A squabswarm", facing="west"),
                            monster("squabswarm", (4, 11), "A squabswarm", facing="east"), monster("squabswarm", (16, 11), "A squabswarm", facing="west")]},
              {"id": "rk_parcels", "trigger": "enter_area:r1_floor", "when": "flag.albert_dead and not flag.rk_parcels_done", "flag": "rk_parcels_done", "text": "The crates stir; wings in the rafters.",
               "monsters": [monster("squabswarm", (4, 6), "A squabswarm", facing="east"), monster("squabswarm", (16, 3), "A squabswarm", facing="west"), monster("squabswarm", (16, 11), "A squabswarm", facing="west")]},
              {"id": "rk_parcel_spiders", "trigger": "open:pkg7", "flag": "rk_spiders_done", "text": "The straw in the box heaves, and then it is all legs.",
               "monsters": [monster("skitterswarm", (13, 3), "A swarm of spiders"), monster("skitterswarm", (15, 5), "A swarm of spiders"), monster("skitterswarm", (11, 5), "A swarm of spiders")]},
          ],
          "npcs": [], "rest": "no", "rest_text": "The building lurches too often for a long rest.",
          "lights": [{"cell": [4, 5], "kind": "candle", "bright_ft": 10, "dim_ft": 25, "color": "candle"}, {"cell": [15, 12], "kind": "candle", "bright_ft": 10, "dim_ft": 25, "color": "candle"}]}
    write("data/locations/rk_dovecote_r1.json", r1)

    # R2, Golub's roost floor, with the rafter platform stood on at ten feet
    g = G(24, 18).room(1, 1, 22, 16)
    g.fill(2, 2, 6, 2, "=").fill(17, 2, 21, 2, "=").fill(2, 3, 2, 14, "=").fill(21, 3, 21, 14, "=")
    r2 = {"id": "rk_dovecote_r2", "name": "The Dovecote: Golub's Roost", "region": REGION, "summary": "The roost floor of the walking dovecote: cubbies to the rafters, a swivel ladder, and a platform where a hag keeps her vanity.",
          "text": "A tall round chamber walled with roost cubbies up to a walkway under the thatch, stuffed with stolen letters. A platform of straw and cloth hangs at the north end, with four tall windows.",
          "map": {"rows": g.rows(), "theme": "manor", "light": "dim", "outdoors": False},
          "areas": [area("r2_floor", "The roost floor", (3, 3), (20, 15)), area("r2_rafters", "The rafter roost", (8, 2), (15, 4))],
          "spawns": {"default": [11, 15], "from_r1": [11, 15]},
          "exits": [exit_("ladder_down", (11, 17), "rk_dovecote_r1", "from_r2", "Down the ladder to the parcel store")],
          "props": [
              prop("rk_rafter_platform_w", (8, 2), "The rafter roost, ten feet up", kind="decor", model="dais", span=[4, 3], stand_ft=10),
              prop("rk_rafter_platform_e", (12, 2), "The rafter roost, ten feet up", kind="decor", model="dais", span=[4, 3], stand_ft=10),
              prop("rk_swivel_ladder", (6, 14), "The swivel ladder, on its track", model="ladder", text="A ladder on a ring-track round the cubbies. It swings wherever the one who rides it pushes."),
              prop("rk_cubbies", (6, 7), "Cubbies stuffed with letters and sins", model="shelves", dialogue=RK + "dovecote:cubbies", when="flag.rk_golub_done and not flag.golub_secrets_read"),
              prop("rk_cubbies_empty", (6, 7), "Cubbies, emptied", model="shelves", kind="decor", when="flag.golub_secrets_read"),
              prop("rk_r2_cages", (18, 7), "Rodent cages", model="cage", text="Cages of rats and a few big, bored mice. All of them look as if they have been listening."),
              prop("rk_r2_window_a", (4, 9), "A tall window, the moor sliding past", kind="decor", model="window_tall"),
              prop("rk_r2_window_b", (19, 9), "A tall window, the moor sliding past", kind="decor", model="window_tall"),
              prop("rk_r2_window_c", (4, 13), "A tall window, the moor sliding past", kind="decor", model="window_tall"),
              prop("rk_r2_window_d", (19, 13), "A tall window, the moor sliding past", kind="decor", model="window_tall"),
              prop("rk_diary", (13, 3), "Golub's diary, open on a perch", kind="search", search_dc=5, item="golubs_diary", when="flag.rk_golub_done"),
              prop("rk_crystal_ball", (10, 3), "A crystal ball on the platform", kind="search", search_dc=5, item="golub_crystal_ball", when="flag.rk_golub_done"),
              prop("rk_midnight_tears", (14, 3), "A stoppered vial among the feathers", kind="search", search_dc=12, item="midnight_tears", when="flag.rk_golub_done"),
              prop("rk_golub_farewell", (11, 12), "The roost, settled and still", kind="decor", call=RK + "dovecote:home_to_roost", approach=10, call_when="flag.rk_golub_done and not flag.golub_dead"),
          ],
          "containers": [container("rk_golub_cage", (4, 5), "A gold birdcage", [("golub_birdcage", 1)], 0), container("rk_golub_chest", (19, 5), "A chest of nuggets", [("skitterdeep_nuggets", 1)], 0)],
          "encounters": [],
          "npcs": [npc("golub_graygullet", (11, 3), "dovecote:golub", approach=9, when="not flag.rk_golub_done")],
          "rest": "no", "rest_text": "The building lurches too often for a long rest.",
          "lights": [{"cell": [4, 4], "kind": "candle", "bright_ft": 10, "dim_ft": 25, "color": "candle"}, {"cell": [19, 4], "kind": "candle", "bright_ft": 10, "dim_ft": 25, "color": "candle"}]}
    boss_mons = lambda alive: ([monster("pigeon_hag", (11, 3), "Golub Graygullet", boss=True, facing="south", steps_down={"npc": "golub_graygullet"})] +
                               [monster("squabswarm", (5, 10), "A squabswarm", facing="east"), monster("squabswarm", (18, 10), "A squabswarm", facing="west"), monster("squabswarm", (11, 12), "A squabswarm", facing="north")] +
                               ([monster("vermin_familiar_pigeon", (16, 6), "Peeping Albert", facing="west")] if alive else []))
    lurch = {"id": "rk_lurch", "name": "Violent lurch", "summary": "The dovecote heaves on its pigeon legs; anyone not holding on goes over.", "kind": "save", "affects": "party",
             "save": {"ability": "dex", "dc": 15}, "condition": "prone", "at": 20, "every": 1, "area": {"cells": [[1, 1], [22, 16]]}, "say": "The whole roost lurches, and the floor tilts under your boots."}
    for alive in (True, False):
        r2["encounters"].append({"id": "rk_golub", "trigger": "dialogue", "when": ("not flag.albert_dead" if alive else "flag.albert_dead"), "flag": "rk_golub_done",
                                 "quest": {"id": "roving_rookery", "stage": "dovecote"}, "monsters": boss_mons(alive), "round_events": [lurch]})
    write("data/locations/rk_dovecote_r2.json", r2)


def build_roosts():
    for (key, n, name, pos, theme, summary) in ROOSTS:
        w, h = 34, 24
        g = G(w, h).room(0, 0, w - 1, h - 1)
        if key == "swamp":
            for (x0, y0, x1, y1) in ((2, 3, 8, 8), (24, 14, 31, 20), (4, 15, 10, 20)):
                g.fill(x0, y0, x1, y1, "w")
            g.fill(12, 12, 22, 14, "~")
        elif key == "lakeshore":
            g.fill(0, 17, w - 1, h - 1, "w").fill(0, 16, w - 1, 16, "~")
        elif key == "foothills":
            g.fill(6, 4, 9, 6, "#").fill(26, 12, 29, 15, "#").fill(4, 18, 7, 20, "#")
        else:
            g.fill(12, 16, 16, 18, "~")
        rows = g.rows()
        loc = {"id": f"rk_roost_{key}", "name": name, "region": REGION, "summary": summary, "text": summary,
               "map": {"rows": rows, "theme": theme, "light": "dim", "outdoors": True},
               "areas": [area("roost", name, (1, 1), (w - 2, h - 2))],
               "spawns": {"default": [2, 12], "from_dovecote": [17, 11]},
               "exits": [exit_("road_back", (0, 12), "travel", None, "The road back to Wickermoor"),
                         exit_("dovecote_door", (17, 10), "rk_dovecote_r1", "default", "Into the dovecote", when=f"flag.dovecote_roost == {n}")],
               "props": [
                   prop(f"rk_dovecote_ext_{key}", (15, 5), "The dovecote, squatting on its pigeon legs", model="cottage", span=[4, 4], when=f"flag.dovecote_roost == {n}", dialogue=RK + "hunt:dovecote_here"),
                   prop(f"rk_footprints_{key}", (17, 8), "Footprints the size of carts", model="rocks", kind="examine", when=f"flag.dovecote_roost != {n} and flag.hysteria_began", dialogue=RK + "hunt:tracks"),
                   prop(f"rk_ring_{key}", (17, 8), "A ring of flattened ground", kind="decor", model="rocks", when=f"flag.dovecote_roost != {n} and not flag.hysteria_began"),
                   prop(f"rk_arrive_{key}", (6, 12), "The roost, and the sky above it", kind="decor", call=RK + "hunt:arrive", approach=10, call_when=f"flag.dovecote_roost == {n} and flag.hysteria_began and not flag.golub_dead and not flag.rk_seen_{key}"),
               ],
               "npcs": [],
               "encounters": [{"id": f"rk_minions_{key}", "trigger": "enter_area:roost", "when": f"flag.dovecote_roost == {n} and not flag.golub_dead and not flag.rk_minions_{key}_done", "flag": f"rk_minions_{key}_done",
                               "text": "Golub's charmed minions rise to meet you, a lilac glint in every eye.", "monsters": MINIONS[key]}],
               "rest": "risky", "rest_text": "The grass hisses and a pigeon watches from a stone."}
        if key == "foothills":
            elev = []
            for y in range(h):
                row = ""
                for x in range(w):
                    d = ((x - 17) ** 2 + (y - 9) ** 2) ** 0.5
                    v = max(0, int(round(3 - d / 5)))
                    row += str(v) if v > 0 else "."
                elev.append(row)
            loc["map"]["elevation"] = elev
        write(f"data/locations/rk_roost_{key}.json", loc)


MINIONS = {
    "prairie": [monster("ettin", (24, 6), "A charmed ettin", facing="west"), monster("ettin", (26, 14), "A charmed ettin", facing="west"),
                monster("dire_wolf", (10, 4), "A charmed wolf", facing="south"), monster("dire_wolf", (12, 20), "A charmed wolf", facing="north"), monster("dire_wolf", (28, 20), "A charmed wolf", facing="north")],
    "swamp": [monster("troll", (24, 8), "A charmed troll", facing="west"), monster("troll", (11, 20), "A charmed troll", facing="north"), monster("giant_crocodile", (28, 12), "A charmed crocodile", facing="west")],
    "foothills": [monster("wyvern", (25, 4), "A charmed wyvern", facing="west"), monster("wyvern", (7, 16), "A charmed wyvern", facing="east"),
                  monster("giant_vulture", (28, 20), "A charmed vulture", facing="north"), monster("giant_vulture", (12, 3), "A charmed vulture", facing="south")],
    "lakeshore": [monster("oni", (26, 6), "A charmed oni", facing="west"), monster("oni", (8, 8), "A charmed oni", facing="east"), monster("chuul", (20, 14), "A charmed chuul", facing="north")],
}


# ---- Wickermoor, additively -------------------------------------------------------------------------------------------------------
LOCK_TEXT = "Barred from within. A shutter twitches, and a chalked word on the door says what the village thinks of you."
OPEN_IN_HYSTERIA = {"road_to_estate", "moor_road", "south_bridge", "orchard_path", "stable", "hut", "cottage_south_a", "cottage_south_b"}
SHUN = ["old_rusty", "sister_rain", "gaston_doray", "joan_murdoch", "peter_murdoch", "charlotte_murdoch", "dani_jenkin", "brother_elias", "barnaby_pennywhistle", "joan_murdoch"]


def _mine_npc(n):
    return str(n.get("dialogue", "")).startswith(RK)


def _strip_mine(loc):
    loc["npcs"] = [n for n in loc.get("npcs", []) if not _mine_npc(n)]
    loc["props"] = [p for p in loc.get("props", []) if not str(p.get("id", "")).startswith("rk_")]
    loc["encounters"] = [e for e in loc.get("encounters", []) if not str(e.get("id", "")).startswith("rk_")]
    loc["exits"] = [e for e in loc.get("exits", []) if not str(e.get("id", "")).startswith("rk_")]


def _front(loc, entries):
    loc["npcs"][0:0] = entries


def build_village():
    path = ROOT / "data/locations/wickermoor_village.json"
    v = json.loads(path.read_text())
    _strip_mine(v)
    v["recheck_minutes"] = 30
    v["spawns"]["from_post_office_back"] = [38, 8]
    # doors: locked while the charm holds (the estate road, the moor road, the footbridge, the orchard path, the stable and the empty cottages stay open)
    for e in v["exits"]:
        if e["id"] in OPEN_IN_HYSTERIA or e.get("to") == "travel":
            continue
        if NOHYST in e.get("when", ""):
            continue
        e["when"] = NOHYST if not e.get("when") else f"({e['when']}) and {NOHYST}"
        e["locked_text"] = LOCK_TEXT
        if e["id"] == "dovecote":
            e["when"] = "not flag.golub_exposed"
            e["locked_text"] = "The plot is an empty ring of foundation stones, where a dovecote stood until it stood up."
        if e["id"] == "post_office":
            e["locked_text"] = "A CLOSED sign, a constable's seal, and a smell of death behind the door."
    mobs = [("rk_mob_a", [(25, 19), (35, 19), (35, 22), (25, 22)], "a"), ("rk_mob_b", [(27, 33), (37, 33), (37, 35), (27, 35)], "b"), ("rk_mob_c", [(20, 8), (46, 8)], "c")]
    entries = []
    # the hook: Geneva comes running (route A), or accuses the party (route B)
    entries.append(npc("geneva_fairchild", (33, 9), "hook:plea", approach=10, when=f"{HOOK} and not flag.golub_exposed_early and not flag.rk_started"))
    entries.append(npc("geneva_fairchild", (33, 9), "hook:geneva_accuses", approach=10, when=f"{HOOK} and flag.golub_exposed_early and not flag.hysteria_began"))
    # the posse waits outside the post office door
    pw = "flag.rk_posse_out and not flag.rk_posse_done"
    entries += [npc("doris_squire", (31, 8), "posse:start", approach=9, steps_aside=True, when=pw), npc("howie_butterman", (37, 8), "posse:howie", steps_aside=True, when=pw),
                npc("rk_posse_a", (28, 8), "posse:grunt", steps_aside=True, when=pw), npc("rk_posse_b", (40, 8), "posse:grunt", steps_aside=True, when=pw)]
    # the mobs walk their routes; each stands down for a while after it is beaten, calmed, or bought off
    for (nid, route, tag) in mobs:
        w = (f"{HYST} and (not flag.rk_posse_out or flag.rk_posse_done) and (not flag.rk_mob_down or minutes_since.rk_mob_down >= 240)"
             f" and (not flag.rk_mob_calm or minutes_since.rk_mob_calm >= 600)")
        entries.append(npc(nid, route[0], f"folk:mob_{tag}", approach=4, path=[list(c) for c in route], pause=2, steps_aside=True, when=w))
    entries.append(npc("rk_mob_round", (31, 25), "folk:mob_round", approach=3, steps_aside=True, when=f"{HYST} and (not flag.rk_posse_out or flag.rk_posse_done) and (not flag.rk_mob_calm or minutes_since.rk_mob_calm >= 600)"))
    # named villagers with a part to play while the charm holds
    entries += [
        npc("peeping_albert", (36, 9), "folk:albert_town", approach=6, when=f"{HYST} and not flag.albert_dead and not flag.rk_albert_fled"),
        npc("sgt_gaunt", (26, 37), "folk:gaunt", when=HYST),
        npc("pip_oakum", (24, 20), "folk:pip", when=HYST),
        npc("tamsin_ledger", (23, 21), "jury:start", when=f"{HYST} and not flag.rk_jury_asked"),
        npc("tamsin_ledger", (23, 21), "jury:progress", when=f"{HYST} and flag.rk_jury_asked and not flag.rk_jury_done and not flag.rk_jury_abandoned"),
        npc("tamsin_ledger", (23, 21), "jury:after", when=HYST),
        npc("wendel_somerton", (32, 22), "forms:start", when=f"{HYST} and not flag.rk_forms_asked"),
        npc("wendel_somerton", (32, 22), "forms:progress", when=f"{HYST} and flag.rk_forms_asked and not flag.rk_forms_done and not flag.rk_forms_forged"),
        npc("wendel_somerton", (32, 22), "forms:after", when=HYST),
        npc("ambrose_quill", (27, 22), "poetry:start", when=f"{HYST} and not flag.quill_asked"),
        npc("ambrose_quill", (27, 22), "poetry:progress", when=f"{HYST} and flag.quill_asked"),
        npc("marianna_grey", (23, 37), "quiet_door:start", when=f"{HYST} and not flag.rk_quiet_asked"),
        npc("marianna_grey", (23, 37), "quiet_door:progress", when=f"{HYST} and flag.rk_quiet_asked"),
        npc("weston_murdoch", (7, 30), "ledger:start", when=f"{HYST} and not flag.rk_ledger_asked"),
        npc("weston_murdoch", (7, 30), "ledger:progress", when=f"{HYST} and flag.rk_ledger_asked"),
        npc("hilda_brom", (48, 28), "hunt:hilda", when=f"{HYST} and flag.rk_hunt"),
        npc("jeremiah_stover", (37, 22), "folk:jeremiah_body", lying=True, when=f"{KEG1} and not flag.rk_jeremiah_hidden and not flag.golub_dead"),
        npc("jeremiah_stover", (13, 12), "folk:jeremiah_hiding", when=f"{HYST} and flag.rk_jeremiah_hidden"),
        npc("jeremiah_stover", (37, 22), "folk:jeremiah_escort", when=f"{HYST} and flag.rk_ledger_asked and not flag.rk_jeremiah_hidden and not ({KEG1})"),
        npc("geneva_fairchild", (33, 9), "after:geneva_postmaster", when="flag.golub_dead and flag.geneva_alive and not flag.rk_geneva_back"),
        npc("doris_squire", (31, 24), "after:doris_after", when="flag.golub_dead and not flag.rk_doris_after and flag.rk_posse_done"),
        npc("phillip_druskenvald", (34, 24), "after:phillip_repairs", when="flag.golub_dead and not flag.rk_repairs_paid"),
        npc("adela_druskenvald", (35, 24), "after:adela_worry", when="flag.golub_dead and not flag.rk_repairs_paid"),
    ]
    for nid in SHUN:
        base = next((n for n in v["npcs"] if n["npc"] == nid), None)
        if base:
            entries.append(npc(nid, base["cell"], "folk:shun", when=HYST))
    _front(v, entries)
    # props: the village as the charm leaves it
    pigeons = [(26, 16), (31, 16), (38, 16), (17, 19), (22, 17), (44, 7), (13, 22), (28, 30), (37, 39), (24, 34), (47, 18), (10, 36)]
    v["props"] += [
        prop("rk_scaffold", (33, 28), "A scaffold of new planks beside the oak", model="dais", kind="examine", when=HYST, text="New planks, still pale, and a rope coiled where a rope should not need to be."),
        prop("rk_chalk_a", (26, 17), "Chalk on a shutter", model="papers", when=HYST, text="MURDERERS, in a hand that has pressed hard enough to snap the chalk."),
        prop("rk_chalk_b", (33, 17), "Chalk on a door", model="papers", when=HYST, text="A list of names, and four of them are yours."),
        prop("rk_chalk_c", (40, 17), "Chalk on a wall", model="papers", when=HYST, text="A drawing of a pigeon wearing a crown, and under it, in tidy script, THE POST IS WATCHING."),
        prop("rk_goat", (32, 24), "The village goat", model="horse", scale=0.5, when=HYST, dialogue=RK + "folk:goat"),
        prop("rk_sky_watch", (15, 12), "The estate road, and the open sky", kind="examine", model="signpost", when=HYST, dialogue=RK + "hunt:sky"),
        prop("rk_ring_stones", (44, 7), "A ring of foundation stones", kind="decor", model="rocks", when="flag.golub_exposed"),
        prop("rk_wendel_desk", (31, 22), "A trestle table of forms", kind="decor", model="table_round", when=HYST),
        prop("rk_keg_school", (7, 19), "The schoolhouse, burned to its footings", kind="examine", model="scorch", when=f"{KEG1} and not flag.rk_school_saved", text="The schoolhouse is blackened timber and standing chimney. Nobody has cleared the slates."),
        prop("rk_keg_carpentry", (50, 28), "The carpentry workshop, burned", kind="examine", model="scorch", when=KEG2, text="The Wells family's workshop is a shell, and the whole family sings no more."),
    ]
    v["props"] += [prop(f"rk_pigeons_{i}", c, "Pigeons, in rows", kind="decor", model="crow", when=HYST) for i, c in enumerate(pigeons)]
    # fights
    v["encounters"] += [
        {"id": "rk_mob_fight", "trigger": "dialogue", "text": "The mob closes in, torches high.",
         "monsters": [monster("tough", (24, 19), "A charmed neighbour", facing="east"), monster("tough", (36, 19), "A charmed neighbour", facing="west"), monster("tough", (24, 25), "A charmed neighbour", facing="east"),
                      monster("tough", (36, 25), "A charmed neighbour", facing="west"), monster("tough", (30, 22), "A charmed neighbour", facing="south"),
                      monster("warrior_veteran", (23, 22), "A charmed veteran", facing="east"), monster("warrior_veteran", (37, 22), "A charmed veteran", facing="west")]},
        {"id": "rk_squabs", "trigger": "dialogue", "flag": "rk_squabs_down", "text": "A grey wave of wings comes off the roof.",
         "monsters": [monster("squabswarm", (26, 21), "A squabswarm", facing="east"), monster("squabswarm", (35, 21), "A squabswarm", facing="west"),
                      monster("squabswarm", (30, 17), "A squabswarm", facing="south"), monster("squabswarm", (30, 26), "A squabswarm", facing="north")]},
        {"id": "rk_albert_town", "trigger": "dialogue", "flag": "albert_dead", "text": "The pigeon with the man's ears bolts for the roofs.",
         "monsters": [monster("vermin_familiar_pigeon", (37, 9), "Peeping Albert", facing="west")]},
        {"id": "rk_posse", "trigger": "dialogue", "flag": "rk_posse_done", "text": "The posse comes on, shouting for the party's names.",
         "quest": {"id": "roving_rookery", "stage": "hysteria"}, "monsters": [monster("tough", (22, 8), "A charmed deputy", facing="east"), monster("tough", (26, 8), "A charmed deputy", facing="east"), monster("knight", (28, 8), "Doris Squire", facing="east"),
                      monster("tough", (31, 9), "A charmed deputy", facing="east"), monster("tough", (38, 9), "A charmed deputy", facing="west"), monster("spy", (40, 8), "Howie Butterman", facing="west"),
                      monster("tough", (43, 8), "A charmed deputy", facing="west"), monster("tough", (47, 8), "A charmed deputy", facing="west")]},
    ]
    path.write_text(json.dumps(v, indent=2, ensure_ascii=False) + "\n")


def build_post_office():
    path = ROOT / "data/locations/wickermoor_post_office.json"
    p = json.loads(path.read_text())
    _strip_mine(p)
    p["spawns"]["from_back"] = [14, 10]
    p["exits"].append(exit_("rk_back_door", (15, 10), "wickermoor_village", "from_post_office_back", "Out the back door"))
    _front(p, [
        npc("theodora_mayville", (7, 3), "post:skin_theodora", lying=True, when="flag.rk_started or flag.golub_exposed"),
        npc("geneva_fairchild", (6, 10), "post:false_geneva", approach=7, when="flag.rk_started and not flag.golub_exposed"),
        npc("geneva_fairchild", (6, 10), "post:skin_geneva", lying=True, when="flag.golub_exposed and not flag.geneva_alive"),
        npc("geneva_fairchild", (7, 5), "after:geneva_postmaster", when="flag.golub_dead and flag.geneva_alive"),
        npc("wynn_carter", (7, 5), "after:wynn", when="flag.golub_dead and not flag.geneva_alive"),
    ])
    p["props"] += [
        prop("rk_post_accuse", (8, 5), "The postmaster's counter", kind="examine", model="table_round", dialogue=RK + "hook:accuse_theodora",
             when="flag.cult_proof_theodora and not flag.rk_started and not flag.golub_exposed"),
        prop("rk_post_letters", (11, 3), "A tray of blank envelopes", kind="examine", model="papers", dialogue=RK + "post:letters", when="not flag.golub_dead"),
        prop("rk_post_window", (12, 1), "The north window, with the dovecote's plot beyond", kind="decor", model="window"),
    ]
    p["recheck_minutes"] = 30
    path.write_text(json.dumps(p, indent=2, ensure_ascii=False) + "\n")


def build_station():
    path = ROOT / "data/locations/wickermoor_constable_station.json"
    s = json.loads(path.read_text())
    _strip_mine(s)
    s["recheck_minutes"] = 30
    jail = "jailed and flag.hysteria_began and not flag.golub_dead"
    _front(s, [
        npc("doris_squire", (9, 8), "jail:cell", when=f"{jail} and minutes_since.jail_began < 360"),
        npc("doris_squire", (9, 8), "jail:march", when=f"{jail} and minutes_since.jail_began >= 360"),
        npc("doris_squire", (5, 11), "poetry:doris_station", when="flag.golub_dead and flag.quill_poem_found and not flag.rk_poetry_met"),
        npc("mrs_oakum", (3, 3), "quiet_door:prisoner", when="flag.rk_oakum_taken and not flag.golub_dead"),
    ])
    s["props"] += [
        prop("rk_cell_bars", (9, 6), "The cell door, a barred frame", kind="examine", model="barred_door", dialogue=RK + "jail:bars", when=jail),
        prop("rk_cell_floor", (8, 2), "Loose boards in the cell floor", kind="search", search_dc=12, item="rk_improvised_picks", when=jail),
        prop("rk_cell_window", (10, 1), "A barred window under the eaves", kind="examine", model="window", dialogue=RK + "jail:window", when=jail),
        prop("rk_cell_wall", (11, 3), "The cell's back wall", kind="examine", model="rocks", dialogue=RK + "jail:wall", when=jail),
        prop("rk_key_peg", (13, 8), "A ring of keys on a peg", kind="examine", model="lantern_bracket", dialogue=RK + "jail:keys", when=jail),
        prop("rk_doris_poems", (7, 13), "A desk drawer that sticks", kind="examine", model="papers", dialogue=RK + "poetry:drawer", when="(jailed or " + NOHYST + ") and not flag.quill_poem_found"),
    ]
    path.write_text(json.dumps(s, indent=2, ensure_ascii=False) + "\n")


def build_stable():
    path = ROOT / "data/locations/wickermoor_stable.json"
    s = json.loads(path.read_text())
    _strip_mine(s)
    _front(s, [npc("mrs_oakum", (17, 9), "quiet_door:oakum", when=f"{HYST} and flag.rk_quiet_asked and not flag.rk_oakum_gone")])
    path.write_text(json.dumps(s, indent=2, ensure_ascii=False) + "\n")


def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if not x["id"].startswith("rk_roost_")]
    t["roads"] = [x for x in t["roads"] if not x["id"].startswith("wickermoor_to_rk_roost_")]
    for (key, n, name, pos, theme, summary) in ROOSTS:
        t["places"].append({"id": f"rk_roost_{key}", "name": name + " (a roost)", "location": f"rk_roost_{key}", "spawn": "default", "pos": list(pos), "region": REGION,
                            "when": "(flag.rk_hunt and not flag.golub_dead) or visited:rk_roost_" + key, "summary": summary})
        t["roads"].append({"id": f"wickermoor_to_rk_roost_{key}", "from": "wickermoor_village", "to": f"rk_roost_{key}", "hours": 30, "name": f"The road to {name}",
                           "when": "(flag.rk_hunt and not flag.golub_dead) or visited:rk_roost_" + key})
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


# ---- flags: every id the chapter's data and dialogue touch, registered once -----------------------------------------------------------
STRING_FLAGS = {"posse_outcome": "How the posse was dealt with: talked, fled, fought or surrendered.", "jail_escape": "How the party left the cells: picks, bars, spell, poetry, help or the march."}
SUMMARY = {
    "hysteria_began": "The charm took hold: stamped with the game minute. The Powder Keg counts from it.",
    "golub_dead": "Golub Graygullet is dead and the charm is broken.", "golub_exposed": "Theodora's skin has been shed: the postmaster is Golub and the dovecote has left.",
    "golub_exposed_early": "The party named the postmaster before the Fallen were done (route B): Geneva lives.", "geneva_alive": "Geneva Fairchild survived (route B).",
    "dovecote_roost": "Which roost the dovecote is at: 0 prairie, 1 swamp, 2 foothills, 3 lakeshore.", "dovecote_moves": "How many times Albert has made the dovecote move.",
    "albert_dead": "Peeping Albert is dead.", "golub_secrets_read": "The party read Golub's stashed secrets: every villager's faction is plain.",
    "villagers_slain": "Charmed villagers killed in the mob fights.", "gorthos_slain": "Gorthos is dead (set by the Maidenmist chapter).",
    "renathyr_slain": "The Crimson Abbot is dead.", "lethica_slain": "Matron Lethica is dead.", "grinning_sinner_slain": "Briggsy is dead.",
}


HOOK_FLAGS_MISSING = {"gorthos_slain", "renathyr_slain", "lethica_slain", "grinning_sinner_slain"}


def build_flags():
    reg = set()
    for f in (ROOT / "data/flags").glob("*.json"):
        if f.name == "rookery.json":
            continue
        reg |= {x["id"] for x in json.loads(f.read_text())["flags"]}
    text = ""
    for f in list((ROOT / "narrative/rookery").glob("*.dialogue")) + [ROOT / "narrative/narrator/rookery.dialogue"]:
        if f.exists():
            text += f.read_text() + "\n"
    for rel in ("data/locations/wickermoor_village.json", "data/locations/wickermoor_post_office.json", "data/locations/wickermoor_constable_station.json", "data/locations/wickermoor_stable.json",
                "data/locations/rk_dovecote_r1.json", "data/locations/rk_dovecote_r2.json", "data/travel/wickermoor_hollow.json", *(f"data/locations/rk_roost_{k}.json" for (k, *_r) in ROOSTS)):
        text += (ROOT / rel).read_text() + "\n"
    for rel in ("data/quests/roving_rookery.json",):
        pass
    found = set(re.findall(r"\bflag\.([a-z][a-z0-9_]*)", text)) | set(re.findall(r"^\s*set ([a-z][a-z0-9_]*)", text, flags=re.M))
    found |= set(re.findall(r"(?:days|minutes)_since\.([a-z][a-z0-9_]*)", text))
    found |= set(re.findall(r'"flag": "([a-z][a-z0-9_]*)"', text))
    ints = set(re.findall(r"^\s*set ([a-z][a-z0-9_]*) \+=", text, flags=re.M)) | set(re.findall(r"^\s*set ([a-z][a-z0-9_]*) = now", text, flags=re.M)) | {"dovecote_roost", "dovecote_moves", "villagers_slain"}
    out = []
    for fid in sorted(found):
        if fid in reg or fid in ("jailed", "now"):
            continue
        typ = "string" if fid in STRING_FLAGS else ("int" if fid in ints else "bool")
        e = {"id": fid, "type": typ, "summary": STRING_FLAGS.get(fid) or SUMMARY.get(fid) or f"The Roving Rookery: {fid.replace('_', ' ')}.", "read_later": True}
        if fid in HOOK_FLAGS_MISSING:
            e["set_by"] = "engine"   # the chapters that kill these Fallen register and set them; until they land, tests set them directly
        out.append(e)
    write("data/flags/rookery.json", {"flags": out})
    return len(out)


if __name__ == "__main__":
    build_people()
    build_quests()
    build_items()
    build_cutscenes()
    build_dovecote()
    build_roosts()
    build_village()
    build_post_office()
    build_station()
    build_stable()
    build_travel()
    print("flags registered:", build_flags())
    print("ok")
