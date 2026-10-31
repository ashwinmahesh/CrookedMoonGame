#!/usr/bin/env python3
"""ONE-SHOT (world-quests3, batch 3 of the Act 1 side-quest plan, vault Build/Side Quest Plan - Act 1.md): Wickermoor's What Mori Keeps (a moral
dilemma whose last stage WAITS until the Crooked House is done), Hair of the Dog (a mystery across two cellars) and Brother Elias the hermit.
Dialogue: narrative/wickermoor/{mori,hair,elias}.dialogue. Idempotent; run from the repo root."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
WM = "wickermoor/"


def write(rel, obj):
    (ROOT / rel).write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


def st(sid, journal, hint=None, objectives=None, ends=None, waits=None):
    d = {"id": sid, "journal": journal}
    if objectives:
        d["objectives"] = objectives
    if hint:
        d["hint"] = hint
    if ends:
        d["ends"] = ends
    if waits:
        d["waits"] = waits
    return d


QUESTS = [
    {"id": "what_mori_keeps", "name": "What Mori Keeps", "kind": "side", "region": "wickermoor", "giver": "mori_shade",
     "summary": "Mori Shade stencils coffin plates for living villagers, at someone's monthly request.",
     "stages": [st("asked", "Mori Shade showed us a drawer of coffin plates stencilled with the names of people who are still alive.", "Decide what to do with the list, at the funeral home.", ["Decide what to do with the list"]),
                st("decided", "We chose what to do with Mori's list. The next month's note has not come yet.", "See Mori again once the Crooked House is behind us.", ["See Mori again"],
                   waits={"until": "flag.vessla_slain", "text": "Mori's next note comes after the Crooked House is behind us."}),
                st("done", "The next note came, and it named someone we know.", ends="success")]},
    {"id": "hair_of_the_dog", "name": "Hair of the Dog", "kind": "side", "region": "wickermoor", "giver": "randall_graham",
     "summary": "Customers' hair keeps turning up in the wrong cellars, and Randall Graham cannot explain it.",
     "stages": [st("asked", "Randall Graham's customers' hair keeps turning up in the funeral home's basement, and he cannot say why.", "Look at the jars in the barber's cellar and the funeral home's basement, then see Randall.", ["The barber's cellar", "The funeral home's basement"]),
                st("done", "We found out why the hair travels, and what Randall does about it.", ends="success")]},
]
FLAGS = [("mori_list_seen", "bool"), ("mori_outcome", "string"), ("mori_later", "bool"), ("hair_asked", "bool"), ("hair_clue_a", "bool"), ("hair_clue_b", "bool"), ("hair_outcome", "string")]
PEOPLE = [("brother_elias", "Brother Elias", "A hermit", "indifferent", "A cranky hermit who refuses every faith and argues with his crow.", "none"),
          ("crow", "The crow", "Brother Elias's crow", "indifferent", "A crow on a post that says only Caw, and is plainly smarter than Elias.", "none")]


def entry(npc, cell, dialogue, when):
    return {"npc": npc, "cell": list(cell), "dialogue": dialogue, "when": when}


def prepend(loc_npcs, npc, new):
    i = next((j for j, n in enumerate(loc_npcs) if n["npc"] == npc), 0)
    loc_npcs[i:i] = new


def main():
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)
    write("data/flags/wm_side_quests3.json", {"flags": [{"id": i, "type": t, "summary": "Side quests batch 3 (wickermoor_side_quests3.py).", "read_later": True} for (i, t) in FLAGS]})
    for nid, name, title, att, summary, fac in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "attitude": att, "sprite": "villager", "region": "wickermoor", "summary": summary, "tags": [f"faction_{fac}", "voice_hollow"]})
    town = read("data/locations/wickermoor_village.json")
    if not any(n["npc"] == "brother_elias" for n in town["npcs"]):
        town["npcs"].append(entry("brother_elias", (38, 3), WM + "elias:start", "flag.wm_welcomed"))
    write("data/locations/wickermoor_village.json", town)

    def room(key):
        return read(f"data/locations/{key}.json")
    fh = room("wickermoor_funeral_home")
    prepend(fh["npcs"], "mori_shade", [
        entry("mori_shade", (9, 6), WM + "mori:later", "flag.mori_outcome and flag.vessla_slain and not flag.mori_later"),
        entry("mori_shade", (9, 6), WM + "mori:start", "flag.wm_welcomed and not flag.mori_list_seen")])
    write("data/locations/wickermoor_funeral_home.json", fh)
    bs = room("wickermoor_barber_shop")
    prepend(bs["npcs"], "randall_graham", [
        entry("randall_graham", (6, 5), WM + "hair:confront", "flag.hair_clue_a and flag.hair_clue_b and not flag.hair_outcome"),
        entry("randall_graham", (6, 5), WM + "hair:start", "flag.wm_welcomed and not flag.hair_asked")])
    write("data/locations/wickermoor_barber_shop.json", bs)
    bc = room("wickermoor_barber_cellar")
    if not any(p["id"] == "barber_cellar_labels" for p in bc["props"]):
        bc["props"].append({"id": "barber_cellar_labels", "cell": [6, 7], "kind": "examine", "label": "Jars labelled by customer", "model": "shelves", "dialogue": WM + "hair:clue_barber", "when": "flag.hair_asked and not flag.hair_clue_a"})
    write("data/locations/wickermoor_barber_cellar.json", bc)
    fb = room("wickermoor_funeral_basement")
    if not any(p["id"] == "funeral_basement_jar" for p in fb["props"]):
        fb["props"].append({"id": "funeral_basement_jar", "cell": [8, 8], "kind": "examine", "label": "A stoppered jar of hair", "model": "case", "dialogue": WM + "hair:clue_funeral", "when": "flag.hair_asked and not flag.hair_clue_b"})
    write("data/locations/wickermoor_funeral_basement.json", fb)


if __name__ == "__main__":
    main()
