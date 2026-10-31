#!/usr/bin/env python3
"""ONE-SHOT (world-quests1, batch 1 of the Act 1 side-quest plan, vault Build/Side Quest Plan - Act 1.md): Wickermoor's The Grey Mare Gets
Out, Misdelivered and Bread and Circuses, and Ambrose Quill the bad poet. Writes quests, flags, items, the new NPC, and the placements in the
town and its rooms (idempotent); the dialogue is narrative/wickermoor/{mare,misdelivered,feast,quill}.dialogue. Run from the repo root."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
WM = "wickermoor/"


def write(rel, obj):
    (ROOT / rel).write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


def st(sid, journal, hint=None, objectives=None, ends=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    return d


QUESTS = [
    {"id": "the_grey_mare", "name": "The Grey Mare Gets Out", "kind": "side", "region": "wickermoor", "giver": "marianna_grey",
     "summary": "Clover, the stablemistress's grey mare, bolted onto the moor road at the tolling of the bell.",
     "stages": [st("asked", "Marianna Grey's grey mare Clover bolted onto the moor when the clocktower tolled, and the wolves are about.", "Look for hoofprints on the moor road in the north of the village.", ["Find Clover"]),
                st("found", "Clover is in a thicket by the north wall, shaking.", "Go to the thicket on the moor road.", ["Catch Clover"]),
                st("caught", "We have Clover on a halter.", "Take her back to Marianna Grey.", ["Return Clover"]),
                st("done", "Clover is home. Marianna hires out a horse free for three days.", ends="success"),
                st("lost", "We told Marianna we could not find Clover. The third stall stays empty.", ends="failure")]},
    {"id": "misdelivered", "name": "Misdelivered", "kind": "side", "region": "wickermoor", "giver": "geneva_fairchild",
     "summary": "Geneva's unsigned love letters to Deputy Butterman went to the wrong doors.",
     "stages": [st("asked", "Geneva Fairchild's letters to Howie Butterman went astray: one to Doris Squire, one to Mori Shade, one eaten by the goat.", "Get Geneva's letters back from the constable's desk, the undertaker and the goat, then see Geneva.", ["Doris's letter", "Mori's letter", "The goat's letter"]),
                st("done", "Geneva has her letters, or what is left of them, and Howie has been told something.", ends="success")]},
    {"id": "bread_and_circuses", "name": "Bread and Circuses", "kind": "side", "region": "wickermoor", "giver": "holly_aster",
     "summary": "Holly Aster and Siv Harga each mean to serve the mayor's table at the Founders' feast.",
     "stages": [st("asked", "Holly the baker and Siv the butcher each want the mayor's table at the Founders' feast, and each thinks the other cheats.", "Visit Siv at the butcher's, then take your verdict to Mayor Somerton.", ["Hear both sides", "Take the verdict to the mayor"]),
                st("done", "The Founders' feast is over. An ode was read.", ends="success")]},
]
FLAGS = [("mare_asked", "bool"), ("mare_found", "bool"), ("mare_caught", "bool"), ("mare_returned", "bool"), ("mare_lost", "bool"),
         ("misdelivered_asked", "bool"), ("letter_doris", "bool"), ("letter_mori", "bool"), ("letter_goat", "bool"), ("misdelivered_outcome", "string"),
         ("feast_asked", "bool"), ("feast_done", "bool"), ("feast_winner", "string"), ("feast_sabotaged", "bool"), ("siv_tasted", "bool"), ("siv_roll_carried", "bool"),
         ("quill_verses", "int")]
ITEMS = [("geneva_letter_a", "Geneva's letter (Doris's)", "A letter in a round hand, unsigned, sealed with a daisy."),
         ("geneva_letter_b", "Geneva's letter (Mori's)", "A letter in a round hand, a little foxed from a drawer."),
         ("geneva_letter_c", "Geneva's letter (what the goat left)", "A damp third of a love letter, mostly vowels.")]


def entry(npc, cell, dialogue, when):
    return {"npc": npc, "cell": list(cell), "dialogue": dialogue, "when": when}


def prepend(loc_npcs, npc, new):
    i = next((j for j, n in enumerate(loc_npcs) if n["npc"] == npc), 0)
    loc_npcs[i:i] = new


def main():
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)
    write("data/flags/wm_side_quests1.json", {"flags": [{"id": i, "type": t, "summary": "Side quests batch 1 (wickermoor_side_quests1.py).", "read_later": True} for (i, t) in FLAGS]})
    for iid, name, summary in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": "quest", "weight_lb": 0, "cost_gp": 0, "summary": summary})
    write("data/npcs/ambrose_quill.json", {"id": "ambrose_quill", "name": "Ambrose Quill", "title": "A poet", "attitude": "friendly", "sprite": "villager", "region": "wickermoor",
          "summary": "A grand and hopeless poet who reads one more verse every time you pass his table.", "tags": ["faction_none", "voice_hollow"]})
    # the town
    town = read("data/locations/wickermoor_village.json")
    prepend(town["npcs"], "marianna_grey", [
        entry("marianna_grey", (23, 37), WM + "mare:return", "flag.mare_caught and not flag.mare_returned"),
        entry("marianna_grey", (23, 37), WM + "mare:start", "flag.wm_welcomed and not flag.mare_asked and not flag.mare_lost"),
        entry("marianna_grey", (23, 37), WM + "mare:progress", "flag.mare_asked and not flag.mare_caught and not flag.mare_lost")])
    ids = {p["id"] for p in town["props"]}
    if "wm_mare_tracks" not in ids:
        town["props"] += [
            {"id": "wm_mare_tracks", "cell": [20, 3], "kind": "examine", "label": "Hoofprints in the mud", "model": "rocks", "dialogue": WM + "mare:tracks", "when": "flag.mare_asked and not flag.mare_found and not flag.mare_lost"},
            {"id": "wm_mare", "cell": [36, 2], "kind": "examine", "label": "A grey mare in a thicket", "model": "horse", "dialogue": WM + "mare:mare_there", "when": "flag.mare_found and not flag.mare_caught"},
            {"id": "wm_goat", "cell": [31, 26], "kind": "examine", "label": "The village goat", "model": "horse", "scale": 0.5, "dialogue": WM + "misdelivered:goat", "when": "flag.misdelivered_asked and not flag.letter_goat"}]
    town["spawns"].setdefault("from_stable_yard", [23, 37])
    write("data/locations/wickermoor_village.json", town)

    def room(key):
        return read(f"data/locations/{key}.json")
    po = room("wickermoor_post_office")
    prepend(po["npcs"], "geneva_fairchild", [
        entry("geneva_fairchild", (4, 9), WM + "misdelivered:deliver", "flag.letter_doris and flag.letter_mori and flag.letter_goat and not flag.misdelivered_outcome"),
        entry("geneva_fairchild", (4, 9), WM + "misdelivered:start", "flag.wm_welcomed and not flag.misdelivered_asked")])
    write("data/locations/wickermoor_post_office.json", po)
    cs = room("wickermoor_constable_station")
    if not any(p["id"] == "constable_station_desk" for p in cs["props"]):
        cs["props"].append({"id": "constable_station_desk", "cell": [6, 12], "kind": "examine", "label": "Doris Squire's desk", "model": "table_round", "dialogue": WM + "misdelivered:doris_desk", "when": "flag.misdelivered_asked and not flag.letter_doris"})
    write("data/locations/wickermoor_constable_station.json", cs)
    fh = room("wickermoor_funeral_home")
    prepend(fh["npcs"], "mori_shade", [entry("mori_shade", (9, 6), WM + "misdelivered:mori_ask", "flag.misdelivered_asked and not flag.letter_mori")])
    write("data/locations/wickermoor_funeral_home.json", fh)
    bk = room("wickermoor_shop_bakery")
    prepend(bk["npcs"], "holly_aster", [entry("holly_aster", (6, 5), WM + "feast:holly_start", "flag.wm_welcomed and not flag.feast_asked")])
    write("data/locations/wickermoor_shop_bakery.json", bk)
    bt = room("wickermoor_shop_butcher")
    prepend(bt["npcs"], "siv_harga", [entry("siv_harga", (6, 5), WM + "feast:siv_visit", "flag.feast_asked and not flag.siv_roll_carried")])
    write("data/locations/wickermoor_shop_butcher.json", bt)
    mh = room("wickermoor_mayors_house")
    prepend(mh["npcs"], "wendel_somerton", [entry("wendel_somerton", (4, 15), WM + "feast:mayor_judges", "flag.feast_asked and not flag.feast_done")])
    write("data/locations/wickermoor_mayors_house.json", mh)
    inn = room("wickermoor_green_queen_inn")
    if not any(n["npc"] == "ambrose_quill" for n in inn["npcs"]):
        inn["npcs"].append(entry("ambrose_quill", (16, 14), WM + "quill:start", "flag.wm_welcomed"))
    write("data/locations/wickermoor_green_queen_inn.json", inn)


if __name__ == "__main__":
    main()
