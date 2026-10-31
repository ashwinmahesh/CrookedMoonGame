"""R11b/c: the village's subplots (Gory Gus, the Play, a Bad Seed, the Lottery), the Oak event and their orchard, as data. build_wickermoor.py
calls apply(town, rooms) and write_all(); the conversations are narrative/wickermoor/{gus,play,bad_seed,lottery,oak}.dialogue."""
import json, random
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
WM = "wickermoor/"

NPCS = [
    ("lottery_stranger", "The Stranger with the Ledger", "Runs the lottery", "A pleasant, tidy stranger in a grey coat with a ledger and a hat of folded slips, who runs a lottery in the Round.", "indifferent"),
    ("george_hickock", "George Hickock", "Leader of Hickock and Company", "A florid actor-manager who speaks as if every sentence were a line.", "friendly"),
    ("lilian_vale", "Lilian Vale", "Leading lady", "A brittle, proud leading lady quick to anger.", "indifferent"),
    ("barnaby_quill", "Barnaby Quill", "Actor, dead", "The company's villain, found dead in his dressing room.", "indifferent"),
    ("olwen_pike", "Olwen Pike", "Prop mistress", "A quiet, practical prop mistress with a needle always in her hand.", "friendly"),
    ("marta_dunn", "Marta Dunn", "A widow in black", "A lean grey-haired woman in widow's black, calm and kind-voiced.", "friendly"),
    ("cecil_marl", "Cecil Marl", "Orchard owner", "A plump, jovial orchard owner whose joviality has curdled.", "friendly"),
]

QUESTS = [
    {"id": "gory_gus", "name": "The Return of Gory Gus", "kind": "side", "region": "wickermoor", "giver": "doris_squire",
     "summary": "A villager is found beheaded before the oak, just as Gus Strong was a year ago.",
     "stages": [
         {"id": "body", "journal": "Ned Cooper, a woodcutter, was found beheaded before the Oak of Many Faces, the way Gus Strong was a year ago. The constable looks at us.", "hint": "Speak with Doris Squire at the oak.", "objectives": ["See the body"]},
         {"id": "clues", "journal": "Someone is copying Gus Strong's work. There is an axe, a woman's hair and a small mark on the dead man's palm to follow up.", "hint": "Ask Mori Shade at the funeral home, and the carpenter at her workshop.", "objectives": ["Find who made the cut"]},
         {"id": "marta", "journal": "The axe was sold to a widow in black, and Mori's hair and the brand lead the same way: Marta Dunn, Gus's apprentice.", "hint": "Find Marta Dunn in the churchyard.", "objectives": ["Face the killer"]},
         {"id": "solved", "journal": "Marta Dunn is stopped. Doris Squire says the village will sleep a little easier.", "ends": "success"}]},
    {"id": "the_play", "name": "The Play's the Deadly Thing", "kind": "side", "region": "wickermoor", "giver": "george_hickock",
     "summary": "A travelling company plays in the inn's little theatre, and its villain dies before the curtain.",
     "stages": [
         {"id": "arrival", "journal": "Hickock and Company have come to the Green Queen Inn to play The Prince in Gold. George Hickock wants us in the audience.", "hint": "See the company at the inn.", "objectives": ["Attend the play"]},
         {"id": "body", "journal": "Barnaby Quill, the company's villain, was found dead in his dressing room behind the stage, a cup beside him.", "hint": "Question the company at the inn.", "objectives": ["Find out who killed Barnaby"]},
         {"id": "suspects", "journal": "Everyone in the company has a reason. The prop cup and a torn letter may tell us more.", "hint": "Examine the cup and the dead man's pockets, then speak to Lilian and Olwen.", "objectives": ["Find the cup and the letter"]},
         {"id": "accused", "journal": "Olwen Pike admitted it: Barnaby had ruined her old friend Mara. Hickock begs us to let the show go on.", "hint": "Speak to George Hickock.", "objectives": ["Decide about the show"]},
         {"id": "solved", "journal": "The company has dealt with the dead man in its own way, and the Green Queen has seen its play.", "ends": "success"}]},
    {"id": "bad_seed", "name": "A Bad Seed", "kind": "side", "region": "wickermoor", "giver": "morgan",
     "summary": "The harvest picnic left the village sick, and the apples lead to an orchard.",
     "stages": [
         {"id": "sick", "journal": "Half the village has fallen sick after the picnic. Morgan thinks it is the apples.", "hint": "Speak with Morgan at the apothecary.", "objectives": ["Learn where the apples came from"]},
         {"id": "orchard", "journal": "The apples came from Marl's orchard, east of the village. Cecil Marl has been selling something worse than fruit.", "hint": "Take the path east from the village's north road to the orchard.", "objectives": ["Go to Marl's orchard"]},
         {"id": "cured", "journal": "Cecil Marl and what he bargained with are gone, the orchard has withered to ash and the sickness is lifting.", "ends": "success"}]},
    {"id": "souls_of_the_oak", "name": "The Souls of the Oak", "kind": "side", "region": "wickermoor", "giver": "old_rusty",
     "summary": "The faces in the oak are the souls of those beheaded before it, and they want to be let go.",
     "stages": [
         {"id": "whispers", "journal": "In the Witching Hour the carved faces of the oak opened their eyes and spoke to us. They are the souls of the beheaded.", "hint": "Return to the oak at the Witching Hour when the party is stronger.", "objectives": ["Learn what the faces want"]},
         {"id": "woken", "journal": "The oak woke to defend its souls and we have had to fight it.", "hint": "Finish the fight.", "objectives": ["Defeat the oak"]},
         {"id": "freed", "journal": "The faces left the bark one by one. The oak is only a tree.", "ends": "success"}]},
]

FLAGS = [("wm_lottery_open", "bool", "The Stranger has set up his lottery in the Round."), ("wm_lottery_done", "bool", "The party has dealt with the lottery."), ("wm_lottery_broken", "bool", "The party tore up the Stranger's ledger."),
         ("gus_body_found", "bool", "Ned Cooper's body is at the oak."), ("gus_accused", "bool", "Doris suspects the party."), ("gus_clue_axe", "bool", "The axe came from the carpenter's."),
         ("gus_clue_hair", "bool", "Mori found a woman's grey hair."), ("gus_clue_hare", "bool", "Mori found the crossed-axes brand."), ("gus_marta_down", "bool", "Marta Dunn is defeated."), ("gus_solved", "bool", "The Gus case is closed."),
         ("play_arrived", "bool", "The company has come to the inn."), ("play_victim_dead", "bool", "Barnaby Quill is dead."), ("play_clue_cup", "bool", "The prop cup."), ("play_clue_note", "bool", "The torn letter."),
         ("play_accused_olwen", "bool", "Olwen has confessed."), ("play_done", "bool", "The play is over."),
         ("picnic_sick", "bool", "The picnic sickness is on the village."), ("seed_fought", "bool", "Cecil Marl's orchard fight is won."), ("seed_done", "bool", "The orchard's curse is lifted."),
         ("wm_oak_ready", "bool", "It is the Witching Hour: the oak may wake."), ("wm_oak_woken", "bool", "The oak woke."), ("wm_oak_won", "bool", "The oak is beaten."), ("wm_oak_freed", "bool", "The souls are freed.")]

EVENTS = [("wm_lottery_open", 20, 3, "wm_lottery_open", "A stranger in a grey coat sets a trestle in the Round and starts calling the village to try its luck."),
          ("gus_body_found", 6, 4, "gus_body_found", "A cry goes up from the Round, and a crowd gathers about the oak."),
          ("play_arrived", 11, 6, "play_arrived", "A cart of painted flats and trunks rolls into the village and stops outside the Green Queen."),
          ("play_victim_dead", 23, 7, "play_victim_dead", "A woman's scream comes from behind the inn's stage, and the fiddler stops mid-bar."),
          ("picnic_sick", 11, 9, "picnic_sick", "Half the village has taken to its bed after the harvest picnic, and the apothecary's lamp burns all night.")]


def orchard_rows():
    w, h = 36, 24
    g = [["."] * w for _ in range(h)]
    r = random.Random(77)
    for x in range(w):
        for y in (0, 1, h - 1, h - 2):
            g[y][x] = "#"
    for y in range(h):
        for x in (0, 1, w - 1, w - 2):
            g[y][x] = "#"
    g[11][0] = "."
    g[11][1] = "."
    for _ in range(22):                     # apple trees in loose groups
        cx, cy = r.randint(3, w - 4), r.randint(3, h - 4)
        for dx, dy in [(0, 0), (1, 0), (0, 1)] if r.random() < 0.5 else [(0, 0)]:
            if 22 <= cx + dx <= 31 and 4 <= cy + dy <= 11:
                continue
            if (cx + dx, cy + dy) not in [(3, 11), (4, 11)]:
                g[cy + dy][cx + dx] = "#"
    for y in range(3, 9):                  # the farmhouse
        for x in range(24, 31):
            g[y][x] = "#"
    for y in range(9, 14):                 # its yard, kept clear
        for x in range(20, 32):
            if g[y][x] == "#":
                g[y][x] = "."
    for y in range(9, 14):
        for x in range(2, 6):
            g[y][x] = "."
    for cx, cy in [(8, 17), (14, 5), (17, 19)]:
        g[cy][cx] = "~"
    return ["".join(r) for r in g]


def open_near(rows, want, taken=()):
    x0, y0 = want
    for d in range(0, 8):
        for dx in range(-d, d + 1):
            for dy in range(-d, d + 1):
                x, y = x0 + dx, y0 + dy
                if 0 <= y < len(rows) and 0 <= x < len(rows[0]) and rows[y][x] == "." and (x, y) not in taken:
                    return [x, y]
    return list(want)


def apply(town, rooms, npc, prop):
    rows = town["map"]["rows"]
    taken = set()

    def cell(want):
        c = open_near(rows, want, taken)
        taken.add(tuple(c))
        return c
    # first the Round: the lottery, the body, Doris at the scene, and the oak's call
    town["npcs"] = [
        npc("lottery_stranger", cell((26, 25)), "lottery:start", when="flag.wm_lottery_open and not flag.wm_lottery_done"),
        npc("doris_squire", cell((28, 33)), "gus:solved", when="flag.gus_marta_down and not flag.gus_solved"),
        npc("doris_squire", cell((28, 33)), "gus:doris_scene", when="flag.gus_body_found and not flag.gus_marta_down and not flag.gus_solved"),
        npc("marta_dunn", [9, 30], "gus:marta", when="flag.gus_clue_hair and flag.gus_clue_axe and not flag.gus_marta_down"),
    ] + town["npcs"]
    town["props"] += [
        prop("wm_gus_body", cell((29, 33)), "A body before the oak", model="grave", when="flag.gus_body_found and not flag.gus_solved", dialogue=WM + "gus:body"),
        prop("wm_oak_roots_call", cell((27, 30)), "The oak's bark, faces turning", kind="decor", model="tree_marked", call=WM + "oak:freed", approach=8,
             call_when="flag.wm_oak_won and not flag.wm_oak_freed"),
    ]
    for pr in town["props"]:
        if pr["id"] == "wm_oak":
            pr.update(call=WM + "oak:start", approach=8, call_when="flag.wm_oak_ready and flag.old_ways_offended and not flag.wm_oak_woken and not flag.wm_oak_won")
    town["exits"].append({"id": "orchard_path", "cell": [58, 4], "to": "wickermoor_orchard", "spawn": "from_village", "label": "The path to Marl's orchard", "when": "flag.picnic_sick and not flag.seed_done"})
    town["spawns"]["from_orchard"] = [57, 4]
    town["encounters"] += [
        {"id": "watch_arrest", "trigger": "dialogue", "text": "The watch closes in, spears levelled.",
         "monsters": [{"monster": "scout", "cell": open_near(rows, (20, 20)), "name": "Watchman 1"}, {"monster": "scout", "cell": open_near(rows, (22, 21)), "name": "Watchman 2"}]},
        {"id": "wm_oak_wakes", "trigger": "dialogue", "flag": "wm_oak_won", "quest": {"id": "souls_of_the_oak", "stage": "woken"},
         "monsters": [{"monster": "treant", "cell": open_near(rows, (30, 31)), "name": "The Oak of Many Faces", "boss": True}]},
        {"id": "wm_gus_marta", "trigger": "dialogue", "flag": "gus_marta_down", "quest": {"id": "gory_gus", "stage": "marta"},
         "monsters": [{"monster": "spy", "cell": [9, 30], "name": "Marta Dunn", "steps_down": {"npc": "marta_dunn"}}, {"monster": "bandit", "cell": [4, 25], "name": "Marta's hireling"}, {"monster": "bandit", "cell": [11, 24], "name": "Marta's hireling"}]},
    ]
    # the carpenter's axe rack and the funeral home's register carry Beatrice's and Mori's parts of the case
    car = rooms["wickermoor_shop_carpentry"][1]
    car["props"].append(prop("carpentry_axe_rack", [4, 3], "A rack of axes", model="rope", when="flag.gus_body_found and not flag.gus_solved", dialogue=WM + "gus:beatrice"))
    fun = rooms["wickermoor_funeral_home"][1]
    fun["props"].append(prop("funeral_home_register", [13, 2], "The undertaker's register", model="book", when="flag.gus_body_found and not flag.gus_solved", dialogue=WM + "gus:mori"))
    # the inn: the company
    inn = rooms["wickermoor_green_queen_inn"][1]
    inn["npcs"] = [
        npc("george_hickock", [22, 5], "play:suspects", when="flag.play_victim_dead and not flag.play_done"),
        npc("george_hickock", [22, 5], "play:hickock_pitch", when="flag.play_arrived and not flag.play_victim_dead and not flag.play_done"),
        npc("lilian_vale", [25, 5], "play:lilian", when="flag.play_victim_dead and not flag.play_done"),
        npc("olwen_pike", [20, 6], "play:olwen", when="flag.play_victim_dead and not flag.play_done"),
    ] + inn["npcs"]
    inn["props"].append(prop("green_queen_inn_dressing_room", [27, 3], "The dressing room behind the stage", model="case", when="flag.play_victim_dead and not flag.play_done", dialogue=WM + "play:body"))
    inn["encounters"] = inn.get("encounters", [])
    mor = rooms["wickermoor_apothecary"][1]
    mor["npcs"] = [npc("morgan", [4, 8], "bad_seed:morgan_apples", when="flag.picnic_sick and not flag.seed_done")] + mor["npcs"]
    # the orchard
    rows_o = orchard_rows()
    orch = {"id": "wickermoor_orchard", "name": "Marl's Orchard", "region": "wickermoor", "summary": "An apple orchard east of the village, and a farmhouse with its shutters closed.",
            "text": "Apple trees stand in loose groups round a farmhouse, their fruit too red and too many, and nothing in the whole orchard is humming.",
            "map": {"rows": rows_o, "theme": "forest", "light": "dim", "outdoors": True},
            "areas": [{"id": "orchard_yard", "name": "The orchard yard", "cells": [[20, 9], [31, 13]]}, {"id": "orchard_trees", "name": "The apple trees", "cells": [[2, 2], [33, 21]]}],
            "spawns": {"default": [3, 11], "from_village": [3, 11]},
            "exits": [{"id": "to_village", "cell": [0, 11], "to": "wickermoor_village", "spawn": "from_orchard", "label": "Back to Wickermoor"}],
            "props": [prop("orchard_apple_tree", [21, 12], "A heavy apple tree", model="tree_marked", call=WM + "bad_seed:cured", approach=6, call_when="flag.seed_fought and not flag.seed_done"),
                      prop("orchard_farmhouse", [27, 9], "Marl's farmhouse"), prop("orchard_cart", [19, 10], "A cart of red apples", model="cart")],
            "npcs": [npc("cecil_marl", [25, 11], "bad_seed:cecil", when="not flag.seed_fought")],
            "encounters": [{"id": "wm_bad_seed", "trigger": "dialogue", "flag": "seed_fought", "quest": {"id": "bad_seed", "stage": "orchard"},
                            "monsters": [{"monster": "cultist_fanatic", "cell": [26, 11], "name": "Cecil Marl"}, {"monster": "quasit", "cell": [24, 13], "name": "A quasit"}, {"monster": "quasit", "cell": [29, 12], "name": "A quasit"}]}],
            "lights": [{"cell": [25, 12], "kind": "lamp", "bright_ft": 15, "dim_ft": 30, "color": "candle"}],
            "rest": "risky", "rest_text": "No one sleeps well among the apples."}
    rooms["wickermoor_orchard"] = ({}, orch)


def write_all(write):
    for (nid, name, title, summary, att) in NPCS:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": "wickermoor"})
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)
    ev = [{"id": fid if fid.startswith("wm_") else f"wm_{fid}", "summary": text, "hour": hour, "first_day": day, "once": True, "location": "wickermoor_village", "set": {fid: True}, "narration": text} for (fid, hour, day, fid2, text) in
          [(e[0], e[1], e[2], e[3], e[4]) for e in EVENTS]]
    ev.append({"id": "wm_oak_hour", "summary": "At the Witching Hour the oak may wake.", "hour": 3, "location": "wickermoor_village", "set": {"wm_oak_ready": True}})
    p = ROOT / "data/schedule/wickermoor.json"
    d = json.loads(p.read_text())
    mine = {e["id"] for e in ev}
    d["events"] = [e for e in d["events"] if e["id"] not in mine] + ev
    write("data/schedule/wickermoor.json", d)
