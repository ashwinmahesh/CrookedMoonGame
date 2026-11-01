#!/usr/bin/env python3
"""ONE-SHOT (R25 Epilogue and the Last Ride, and the endings of the whole game; vault Packages/R25 - Epilogue and the Last Ride.md): the endings
(data/endings), the quests, flags, the Ghostlight ticket, the old station (ep_fog) and the Last Ride car (ep_car), the post-finale fair and closing
talks in Wickermoor Village, the graves, and the cutscene lists. Dialogue: narrative/endings/*.dialogue and narrative/epilogue/*.dialogue (drafted
by Gemini, tools/content/epilogue_dialogue_specs.py). Idempotent; run from the repo root."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import epilogue_slides as sl  # noqa: E402

EP = "epilogue/"


def write(rel, obj):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


def stage(sid, journal, hint=None, objectives=None, ends=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    return d


# ------------------------------------------------------------------------------------------------------------------ endings
ENDINGS = [
    # (id, title, summary, priority, when, tone, slides, epilogue_from)
    ("empty_car", "An Empty Car", "The tree burned and the Queen is bound, but nobody was left to board the train.", 30,
     "flag.kehlenn_bound and party_alive == 0", "night", sl.EMPTY, "under_the_crooked_moon"),
    ("embers_of_the_fallen", "Embers of the Fallen", "The Queen is bound, and the fallen burn on beside Adela's ember.", 25,
     "flag.kehlenn_bound and flag.last_act_count >= 1", "night", sl.EMBERS, "under_the_crooked_moon"),
    ("under_the_crooked_moon", "Underneath the Crooked Moon", "The Crooked Tree burned, the moon scowls, and the train comes out of the fog.", 20,
     "flag.kehlenn_bound", "dawn", sl.SEALED, ""),
    ("queens_consort", "Kneel to the Crooked Queen", "You took Kehlenn's side, and the valley is hers to remake.", 15,
     "flag.kehlenn_sided", "blood", sl.CRUEL, "crooked_rebirth"),
    ("ash_over_the_hollow", "Ash over the Hollow", "The Wicker Man walked down from the moors, and the valley is ash.", 14,
     "flag.wicker_man_triumphant and not flag.kehlenn_bound", "blood", sl.ASH, "crooked_rebirth"),
    ("live_deliciously", "Live Deliciously", "Every hero took the goat's offer, and every wish came true, bent.", 12,
     "not flag.kehlenn_bound and flag.horned_bargains >= party_size and party_size > 0", "blood", sl.BARGAIN, "crooked_rebirth"),
    ("crooked_rebirth", "All Will Be Crooked", "The ritual was lost and the realm reborn crooked.", 10,
     "not flag.kehlenn_bound", "blood", sl.CROOKED, ""),
    ("moon_unbent", "The Moon Unbent", "The Old Fears are slain, the offer refused, and the moon climbs back into the sky.", 60,
     'flag.moonfall_started and flag.old_fears_slain == 8 and flag.moonfall_offer == "refused"', "dawn", sl.MOON_OWN, "under_the_crooked_moon"),
    ("green_sea", "A Green Sea", "The moon fell on everyone but you, and you made a world of what was left.", 55,
     'flag.moonfall_started and flag.moonfall_offer == "accepted"', "dawn", sl.GREEN_SEA, ""),
    ("last_train_out", "The Last Train Out", "The Vagrant offered one ride out on the last night, and you took it.", 52,
     "flag.moonfall_started and flag.moonfall_fled", "night", sl.LAST_TRAIN, "moonfall"),
    ("moonfall", "Moonfall", "The nights ran out. Impact, and nothing after it.", 50,
     "flag.moonfall_started and flag.moonfall_nights_left <= 0", "night", sl.MOONFALL, ""),
]


def build_endings():
    for eid, title, summary, prio, when, tone, slides, frm in ENDINGS:
        d = {"id": eid, "title": title, "summary": summary, "priority": prio, "when": when,
             "narration": f"endings/{eid}:start", "tone": tone, "music": "ending"}
        if frm:
            d["epilogue_from"] = frm
        d["epilogue"] = slides
        write(f"data/endings/{eid}.json", d)


# ------------------------------------------------------------------------------------------------------------------ quests
QUESTS = [
    {"id": "ep_the_last_ride", "name": "The Last Ride", "kind": "main", "region": "wickermoor", "giver": "old_rusty",
     "summary": "The tree has burned. Mend what you like in Wickermoor, then go down to the old station when the fog is thick enough.",
     "stages": [
         stage("loose_ends", "The Crooked Tree burned and the valley is changed. Wickermoor is quiet and busy at once: closing talks to have, graves to see, a fair on the Round.",
               "Walk the village and talk to anyone who mattered. The old station is south of the bridge, whenever we are ready.", ["Say what needs saying", "Go down to the old station when ready"]),
         stage("the_last_ride", "The Ghostlight Express came out of the fog for us. The Vagrant holds the door and the ticket reads Destination: Unknown.",
               "Choose where the train takes us, or step down for one more goodbye.", ["Choose a destination"]),
         stage("done", "We rode.", ends="success")]},
    {"id": "ep_empty_seats", "name": "Empty Seats", "kind": "side", "region": "wickermoor", "giver": "old_rusty",
     "summary": "The village dug graves for the heroes who gave their lives. Say a word over them, or do not.",
     "stages": [
         stage("graves", "The village has marked graves for the heroes we lost. Nothing is required of us here.",
               "The graves are at the edge of the village, near the Round.", ["Visit the graves"]),
         stage("done", "A word was said, or a flower left, and the seats on the train stay aired.", ends="success")]},
    {"id": "ep_fair_on_the_round", "name": "The Fair on the Round", "kind": "side", "region": "wickermoor", "giver": "ambrose_quill",
     "summary": "Wickermoor holds a fair on the Round because nobody can think what else to do. The poet will read, the goat has views on the permit, and the auditor has a clipboard.",
     "stages": [
         stage("open", "The fair is on. Ambrose Quill is about to read, Biscuit is eyeing the permit on the notice board, and Tamsin Ledger is auditing.",
               "Hear Quill's verse, keep the permit from the goat if you can, and meet Tamsin's audit.", ["Keep the fair legal", "Meet the audit"]),
         stage("done", "The audit is over, and the fair went on regardless.", ends="success")]},
]

# flags this chapter sets (and reads): name, type, summary, read_later
OWN_FLAGS = [
    ("ep_started", "bool", "Old Rusty told the party the village is theirs to mend before the train comes.", False),
    ("ep_vagrant_met", "bool", "The Vagrant has come out of the fog at the old station.", False),
    ("ep_boarded", "bool", "The party has boarded the Ghostlight Express for the Last Ride.", False),
    ("ep_last_ride_asked", "bool", "The Vagrant has asked where the party would like to go.", False),
    ("last_ride_destination", "string", "`home`, `province` or `beyond`: where the Last Ride went (read by the endings).", False),
    ("ep_fallen_graves_seen", "bool", "The party has seen the graves marked for the fallen heroes.", True),
    ("ep_goodbyes_said", "bool", "The party said a word or left a flower at the fallen heroes' graves.", True),
    ("ep_fair_open", "bool", "The Fair on the Round has begun.", False),
    ("ep_fair_verse", "bool", "Quill read his final verse.", True),
    ("ep_fair_permit_safe", "bool", "The fair's permit was kept from the goat.", False),
    ("ep_fair_permit_eaten", "bool", "The goat ate the fair's permit.", False),
    ("ep_fair_outcome", "string", "`passed`, `bluffed`, `fined` or `bribed`: how Tamsin Ledger's audit of the fair ended.", False),
    ("ep_closings", "int", "How many of the villagers' closing talks the party has had.", True),
]
CLOSING_IDS = ["marianna_grey", "siv_harga", "doris_squire", "wendel_somerton", "jean_myriel", "eleanor_heyling", "finneas_trout", "sister_rain",
               "weston_murdoch", "solomon_roderick", "mori_shade", "morgan", "geneva_fairchild", "jeremiah_stover", "hilda_brom", "thomasin_ardor",
               "beatrice_wells", "mrs_oakum"]

# flags the finale chapters (R23, R24, R26) set and this one reads, in the order of the vault digest 0.3; registered `set_by: engine` here only so this
# lane validates alone (the merge replaces each by its real owner's registration and drops this file).
FINALE_READS = [
    ("wicker_man_burned", "bool", "R23: the Wicker Man was burned out (read by the epilogue)."),
    ("wicker_man_triumphant", "bool", "R23: the Wicker Man won and walked on the village (ash_over_the_hollow)."),
    ("vigil_deaths", "int", "R23: innocents lost on the moors and at the stones."),
    ("vigil_fled", "bool", "R23: the heroes left the moors before the Wicker Man fell."),
    ("horned_bedlam_nights", "int", "R24: nights spent before entering the Wytchwood."),
    ("mayor_fate", "string", "R23/R24: cultist_dead, cultist_spared, jailed, lynched or saved."),
    ("alda_will_delivered", "bool", "R24: Alda Farnum's will was found and delivered."),
    ("kehlenn_bound", "bool", "R24: the ritual succeeded and Kehlenn is bound in the moon."),
    ("kehlenn_sided", "bool", "R24: the heroes sided with Kehlenn at the barrow."),
    ("last_act_count", "int", "R24: heroes who gave their lives at the skull."),
    ("crooked_cause", "string", "R24: wipe, ritual_failed or refused."),
    ("horned_bargains", "int", "R24: heroes who accepted the Horned King's bargain."),
    ("moonfall_started", "bool", "R26: the Moonfall expansion began."),
    ("old_fears_slain", "string", "R26: Old Fears slain, of eight (an int there; typed string here only so story_reach lets a count of eight stand for the stand-in)."),
    ("moonfall_offer", "string", "R26: Kehlenn's last offer, accepted or refused."),
    ("moonfall_fled", "bool", "R26: the party took the Vagrant's ride out."),
    ("moonfall_nights_left", "int", "R26: nights before the moon falls."),
    ("moonfall_realm", "string", "R26: the realm the heroes shaped from the green sea (wild, city, farm, home)."),
] + [(f"thread_{t}_catharsis", "string", f"R24: the {t.title()} Thread's Catharsis, taken or declined.") for t, *_ in sl.THREADS]


def build_flags():
    write("data/flags/ep_epilogue.json", {"flags": [
        *({"id": i, "type": t, "summary": s, **({"read_later": True} if rl else {})} for i, t, s, rl in OWN_FLAGS),
        *({"id": f"ep_closing_{n}", "type": "bool", "summary": f"The closing talk with {n.replace('_', ' ')} has been had.", "read_later": False} for n in CLOSING_IDS)]})
    write("data/flags/ep_finale_reads.json", {"flags": [{"id": i, "type": t, "summary": s, "set_by": "engine"} for i, t, s in FINALE_READS]})
    write("data/flags/endings.json", {"flags": [{"id": "campaign_ending", "type": "string", "summary": "The id of the ending reached (story/endings.gd); set by the engine.", "set_by": "engine"}]})


# ------------------------------------------------------------------------------------------------------------------ places
def fog_map():
    w, h = 32, 14
    rows = []
    for y in range(h):
        if y in (0, h - 1):
            rows.append("#" * w)
        else:
            rows.append("#" + "." * (w - 2) + "#")
    return rows


def build_places():
    fog = {
        "id": "ep_fog", "name": "The Old Station", "region": "wickermoor",
        "summary": "A disused halt south of the bridge where the fog lies thickest, and the Ghostlight Express stops once the moon is crooked no longer.",
        "text": "Rails of mist run into the fog under a broken lamp. Somewhere out in the white, one fiddle plays, and a ghostly blue-green headlamp grows slowly larger.",
        "map": {"rows": fog_map(), "theme": "village", "light": "dim", "outdoors": True},
        "areas": [{"id": "ep_platform", "name": "The platform", "cells": [[1, 1], [30, 12]]}],
        "spawns": {"default": [3, 6], "from_car": [22, 8], "from_village": [3, 6]},
        "exits": [{"id": "to_village", "cell": [0, 6], "to": "wickermoor_village", "spawn": "from_fog", "label": "Back up the lane to Wickermoor"}],
        "props": [
            {"id": "ep_fog_signpost", "cell": [5, 4], "kind": "examine", "label": "The halt's signpost", "model": "signpost",
             "text": "The board once named a place. The paint has run, and what is left says only: Destination, and a smudge."},
            {"id": "ep_fog_rails", "cell": [14, 7], "kind": "examine", "label": "Rails of mist", "model": "rocks",
             "text": "The rails are not iron. They hold their shape the way a held breath does."},
            {"id": "ep_fog_lamp", "cell": [8, 2], "kind": "decor", "label": "A broken lamp", "model": "crow"},
            {"id": "ep_fog_bench", "cell": [10, 10], "kind": "examine", "label": "A platform bench", "model": "table_round",
             "text": "Someone has left a sprig of wheat on the bench, as if keeping a place."},
        ],
        "npcs": [
            {"npc": "the_vagrant", "cell": [20, 6], "dialogue": EP + "vagrant:arrive", "when": "not flag.ep_vagrant_met", "approach": 12, "facing": "west"},
            {"npc": "the_vagrant", "cell": [20, 6], "dialogue": EP + "vagrant:again", "when": "flag.ep_vagrant_met", "facing": "west"},
        ],
        "rest": "no", "rest_text": "The fog does not let anyone sleep here. A short breath, then.",
        "lights": [{"cell": [8, 2], "kind": "lamp", "bright_ft": 20, "dim_ft": 40, "color": "candle"}],
    }
    write("data/locations/ep_fog.json", fog)
    g1 = read("data/locations/ghostlight_g1_passenger.json")
    car = {
        "id": "ep_car", "name": "The Last Car", "region": "ghostlight_express",
        "summary": "The Ghostlight Express's passenger car, empty and warm, for the last ride.",
        "text": "Two rows of red leather seats and a lit aisle. No pale passengers this time. Through the window the Hollow slides away under the Crooked Moon.",
        "map": g1["map"],
        "areas": [{"id": "ep_car_rear", "name": "The rear end", "cells": [[1, 1], [8, 5]]}, {"id": "ep_car_front", "name": "The front end", "cells": [[9, 1], [18, 5]]}],
        "spawns": {"default": [3, 3]},
        "exits": [{"id": "ep_car_door", "cell": [0, 3], "to": "ep_fog", "spawn": "from_car", "label": "Step down to the platform"}],
        "props": [
            {"id": "ep_car_seats", "cell": [6, 1], "kind": "examine", "label": "Paired seats", "model": "chairs", "text": "Red leather, worn smooth by passengers who did not mind waiting."},
            {"id": "ep_car_window", "cell": [10, 1], "kind": "examine", "label": "The window", "model": "window", "text": "The Hollow, small and dark under a moon that scowls. Further on, only fog."},
        ],
        "npcs": [
            {"npc": "the_vagrant", "cell": [12, 3], "dialogue": EP + "last_ride:start", "when": "flag.ep_boarded and not flag.ep_last_ride_asked", "approach": 12, "facing": "west"},
            {"npc": "the_vagrant", "cell": [12, 3], "dialogue": EP + "last_ride:destination", "when": "flag.ep_last_ride_asked", "facing": "west"},
        ],
        "rest": "no", "rest_text": "The rocking of the train will not let anyone sleep. A short breath, then.",
        "lights": g1["lights"],
    }
    write("data/locations/ep_car.json", car)


def free_cells(vil, x0, x1, y0, y1):
    rows = vil["map"]["rows"]
    taken = {tuple(n["cell"]) for n in vil["npcs"]} | {tuple(p["cell"]) for p in vil["props"]} | {tuple(e["cell"]) for e in vil["exits"]}
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rows[y][x] in ".=" and (x, y) not in taken and all(rows[y + dy][x + dx] in ".=" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                yield (x, y)


def build_village():
    vil = read("data/locations/wickermoor_village.json")
    vil["npcs"] = [n for n in vil["npcs"] if not str(n.get("dialogue", "")).startswith(EP)]
    vil["props"] = [p for p in vil["props"] if not str(p.get("id", "")).startswith("ep_")]
    vil["exits"] = [e for e in vil["exits"] if e["id"] != "old_station"]
    cells = list(free_cells(vil, 23, 38, 17, 31))
    # spread the cast over the Round: every third free cell
    picks = cells[::2]
    it = iter(picks)
    fair = "flag.kehlenn_bound"

    def put(npc, node, when):
        vil["npcs"].append({"npc": npc, "cell": list(next(it)), "dialogue": EP + node, "when": when})

    put("old_rusty", "hook:start", f"{fair} and not flag.ep_started")
    put("ambrose_quill", "fair:quill_start", f"{fair} and flag.ep_started")
    put("tamsin_ledger", "fair:audit_start", f"{fair} and flag.ep_fair_open and not flag.ep_fair_outcome")
    put("sgt_gaunt", "fair:gaunt_start", f"{fair} and flag.ep_started")
    put("pip_oakum", "fair:pip_start", f"{fair} and flag.ep_started")
    put("barnaby_pennywhistle", "fair:barnaby_start", f"{fair} and flag.ep_started")
    put("commune_goat", "fair:notice_start", f"{fair} and flag.ep_fair_open and not flag.ep_fair_permit_safe and not flag.ep_fair_permit_eaten")
    for n in CLOSING_IDS:
        put(n, f"closing:{n}", f"{fair} and flag.ep_started and not flag.ep_closing_{n}")
    # props: the notice board, the fair's stalls, the graves
    pl = []
    c = next(it)
    pl.append({"id": "ep_notice_board", "cell": list(c), "kind": "examine", "label": "The fair's notice board", "model": "notice_board",
               "dialogue": EP + "fair:notice_start", "when": f"{fair} and flag.ep_fair_open and not flag.ep_fair_permit_safe and not flag.ep_fair_permit_eaten"})
    for i in range(4):
        c = next(it)
        pl.append({"id": f"ep_fair_stall_{i}", "cell": list(c), "kind": "decor", "label": "A fair stall", "model": "table_round", "when": fair})
    for i in range(3):
        c = next(it)
        pl.append({"id": f"ep_fair_bunting_{i}", "cell": list(c), "kind": "decor", "label": "Bunting", "model": "bunting", "when": fair})
    gcells = list(free_cells(vil, 40, 56, 19, 33))
    gc = gcells[len(gcells) // 2]
    pl.append({"id": "ep_graves", "cell": list(gc), "kind": "examine", "label": "The new graves", "model": "grave",
               "dialogue": EP + "graves:start", "when": fair})
    vil["props"] += pl
    vil["exits"].append({"id": "old_station", "cell": [34, 44], "to": "ep_fog", "spawn": "from_village", "label": "Walk down to the old station",
                         "when": "flag.kehlenn_bound and flag.ep_started",
                         "locked_text": "The fog sits thick down the south lane, and nothing in it is waiting yet.",
                         "sets_quest": {"id": "ep_the_last_ride", "stage": "the_last_ride", "from": ["loose_ends"]}})
    vil["spawns"]["from_fog"] = [34, 43]
    write("data/locations/wickermoor_village.json", vil)


# ------------------------------------------------------------------------------------------------------------------ cutscenes and items
PICTURES = {
    "ep_old_train": "Fog and darkness on a disused halt at the Midnight Hour, a single blue-green headlamp growing out of the white, a lone fiddle somewhere in the dark",
    "ep_old_train_2": "A black locomotive screeching to a halt on rails of pale mist, sparks of green light, a moonlit station sign half-eaten by fog",
    "ep_old_train_3": "A train door creaking open in the fog, a mottled-green frogman in a patched coat and a hat with three railroad spikes hopping down to the platform with a sprig of wheat in his mouth",
    "ep_last_ride": "Seen through a train window, the Hollow shrinking in the dark and the Crooked Moon sneering down, its grin now a scowl",
    "ep_last_ride_2": "Only fog rushing past a train window, pale and silver, with a faint blue-green reflection of a lamp on the glass",
}
TITLES = {"ep_old_train": "An old black train", "ep_last_ride": "The last ride"}


def build_cutscenes():
    write("tools/content/epilogue_cutscenes.json", {"style": "Style: vintage Saturday-morning monster cartoon still with a real horror edge, heavy painted gouache background, deep inky blacks, one coloured light source (ghostly blue-green), flat cel-painted characters with clean black outlines, high contrast, unsettling. Wide cinematic frame. No faces of the heroes shown, no text.", "pictures": PICTURES})
    for cid, desc in PICTURES.items():
        base = cid.rsplit("_", 1)[0] if cid.rsplit("_", 1)[-1].isdigit() else cid
        write(f"data/cutscenes/{cid}.json", {"id": cid, "title": TITLES.get(base, base), "summary": desc, "images": [{"image": cid, "when": ""}]})


def build_items():
    write("data/items/ghostlight_ticket_unknown.json", {"id": "ghostlight_ticket_unknown", "name": "Ghostlight Express ticket: Destination Unknown", "source": {"book": "CrookedMoon"},
                                                          "category": "quest", "weight_lb": 0, "cost_gp": 0,
                                                          "summary": "A black rail ticket punched with a star. Where it says Destination, it says Unknown. A keepsake for the finished save."})


def main():
    build_endings()
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)
    build_flags()
    build_items()
    build_places()
    build_village()
    build_cutscenes()


if __name__ == "__main__":
    main()
