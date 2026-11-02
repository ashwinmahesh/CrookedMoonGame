#!/usr/bin/env python3
"""ONE-SHOT (Act 2 batch 1, vault Build/Side Quest Plan - Act 2.md): Wickermoor during the Skitter Plague (it reaches the village once one Act II
chapter is done: flag.act2_done >= 1). Quarantine Notices, Soup for the Sick, Oakum's Curse, Walder Pye's Letter, The Quack, and Barnaby
Pennywhistle and Granny Orla Pike. Dialogue: narrative/wickermoor/{quarantine,soup,oakum,letter,quack,folk_plague}.dialogue.
Idempotent; run from the repo root."""
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parent))
from heirlooms_kept import kept

ROOT = Path(__file__).resolve().parents[2]
WM = "wickermoor/"
PLAGUE = "flag.act2_done >= 1"


def write(rel, obj):
    if kept(rel):   # (a floor of a building merged into one place: tools/content/merge_floors.py)
        return
    (ROOT / rel).write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    if kept(rel):
        raise SystemExit("%s is a floor of a building merged into one place (tools/content/merge_floors.py): this one-shot already ran" % rel)
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
    {"id": "quarantine_notices", "name": "Quarantine Notices", "kind": "side", "region": "wickermoor", "giver": "wendel_somerton",
     "summary": "The mayor must file the plague notices in triplicate with three seals before the inn may be closed.",
     "stages": [st("asked", "Mayor Somerton wants three seals on the quarantine notices: his own, Tamsin Ledger's and the post office's.", "Get Tamsin Ledger's countersign in the Mayor's House and the postmaster's stamp, then see the mayor.", ["Tamsin's seal", "The post office's seal", "File the notices"]),
                st("done", "The notices are filed, in triplicate.", ends="success")]},
    {"id": "soup_for_the_sick", "name": "Soup for the Sick", "kind": "side", "region": "wickermoor", "giver": "holly_aster",
     "summary": "The sick need broth, Holly has bread and Siv has bones, and the bake-off still stings.",
     "stages": [st("asked", "Holly Aster needs Siv Harga's bones for the sick-room broth, and they are not speaking.", "Talk to Siv at the butcher's, sort out the shared stove in the Round, then see Holly.", ["Siv's bones", "The stove", "Serve the broth"]),
                st("done", "The sick were fed.", ends="success")]},
    {"id": "oakums_curse", "name": "Oakum's Curse", "kind": "side", "region": "wickermoor", "giver": "mrs_oakum",
     "summary": "The butcher's assistant leaves town each Evening and is back at Twilight, and asks no one to follow.",
     "stages": [st("asked", "Mrs. Oakum asked us not to follow her when she leaves the village each Evening.", "Learn where she goes, or let it lie, and talk to her at the butcher's.", ["Decide what to do about her secret"]),
                st("done", "We decided what to do about Mrs. Oakum's secret.", ends="success")]},
    {"id": "walders_letter", "name": "Walder Pye's Letter", "kind": "side", "region": "wickermoor", "giver": "mori_shade",
     "summary": "A dead traveler's letter must leave Wickermoor without passing through the post.",
     "stages": [st("asked", "Mori Shade holds a dead traveler's letter and asked that it not go by the post.", "Get it past the post office counter to Hilda Brom on the moor road side of the Round.", ["Carry the letter out"]),
                st("done", "Hilda took the letter on the moor road.", ends="success"),
                st("lost", "The post office kept the letter.", ends="failure")]},
    {"id": "the_quack", "name": "The Quack", "kind": "side", "region": "wickermoor", "giver": "morgan",
     "summary": "A pedlar sells a plague cure in the Round, and Morgan wants to know what is in it.",
     "stages": [st("asked", "Morgan wants to know what is in Barnaby Pennywhistle's plague cure.", "Talk to Barnaby in the Round; buy a bottle or press him.", ["Learn what is in the cure", "Decide what to do about Barnaby"]),
                st("done", "We settled Barnaby Pennywhistle's cure.", ends="success")]},
]
FLAGS = [("quarantine_asked", "bool"), ("seal_tamsin", "bool"), ("seal_post", "bool"), ("quarantine_forged", "bool"), ("quarantine_done", "bool"),
         ("soup_asked", "bool"), ("soup_siv", "bool"), ("soup_stove", "bool"), ("soup_done", "bool"),
         ("oakum_asked", "bool"), ("oakum_known", "bool"), ("oakum_outcome", "string"),
         ("letter_asked", "bool"), ("letter_outcome", "string"),
         ("quack_asked", "bool"), ("quack_bottle", "bool"), ("quack_known", "bool"), ("quack_outcome", "string"), ("orla_sang", "bool")]
PEOPLE = [("barnaby_pennywhistle", "Barnaby Pennywhistle", "A pedlar", "friendly", "A travelling quack who sells a plague cure with a different guarantee for every customer.", "none"),
          ("granny_orla_pike", "Granny Orla Pike", "An old woman", "indifferent", "A fierce old woman who sings the sick to sleep and judges everyone's singing.", "old_ways")]


def entry(npc, cell, dialogue, when):
    return {"npc": npc, "cell": list(cell), "dialogue": dialogue, "when": when}


def prop(pid, cell, label, model, dialogue, when):
    return {"id": pid, "cell": list(cell), "kind": "examine", "label": label, "model": model, "dialogue": dialogue, "when": when}


def prepend(loc_npcs, npc, new):
    i = next((j for j, n in enumerate(loc_npcs) if n["npc"] == npc), 0)
    loc_npcs[i:i] = new


def main():
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)
    write("data/flags/wm_act2_batch1.json", {"flags": [{"id": i, "type": t, "summary": "Act 2 batch 1 (wickermoor_act2_batch1.py).", "read_later": True} for (i, t) in FLAGS]})
    write("data/items/walder_letter.json", {"id": "walder_letter", "name": "Walder Pye's letter", "source": {"book": "CrookedMoon"}, "category": "quest", "weight_lb": 0, "cost_gp": 0, "summary": "A creased letter addressed to a family a long way away."})
    for nid, name, title, att, summary, fac in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "attitude": att, "sprite": "villager", "region": "wickermoor", "summary": summary, "tags": [f"faction_{fac}", "voice_hollow"]})

    def room(key):
        return read(f"data/locations/{key}.json")

    def save(key, loc):
        write(f"data/locations/{key}.json", loc)
    town = read("data/locations/wickermoor_village.json")
    if not any(n["npc"] == "barnaby_pennywhistle" for n in town["npcs"]):
        town["npcs"] += [entry("barnaby_pennywhistle", (33, 34), WM + "quack:pitch", "flag.act2_done >= 1")]
    prepend(town["npcs"], "hilda_brom", [entry("hilda_brom", (48, 28), WM + "letter:hilda", "flag.letter_asked and not flag.letter_outcome")])
    if not any(p["id"] == "wm_shared_stove" for p in town["props"]):
        town["props"].append(prop("wm_shared_stove", (26, 20), "The shared stove", "hearth", WM + "soup:stove", "flag.soup_asked and not flag.soup_stove"))
    save("wickermoor_village", town)
    mh = room("wickermoor_mayors_house")
    prepend(mh["npcs"], "wendel_somerton", [
        entry("wendel_somerton", (4, 15), WM + "quarantine:file", "flag.seal_tamsin and flag.seal_post and not flag.quarantine_done"),
        entry("wendel_somerton", (4, 15), WM + "quarantine:start", f"{PLAGUE} and not flag.quarantine_asked")])
    prepend(mh["npcs"], "tamsin_ledger", [entry("tamsin_ledger", (18, 9), WM + "quarantine:tamsin_seal", "flag.quarantine_asked and not flag.seal_tamsin")])
    save("wickermoor_mayors_house", mh)
    po = room("wickermoor_post_office")
    if not any(p["id"] == "post_office_counter" for p in po["props"]):
        po["props"].append(prop("post_office_counter", (8, 3), "The post counter", "table_round", WM + "quarantine:post_seal", "flag.quarantine_asked and not flag.seal_post"))
        po["props"].append(prop("post_office_outbox", (10, 3), "The outgoing tray", "papers", WM + "letter:counter", "flag.letter_asked and not flag.letter_outcome"))
    save("wickermoor_post_office", po)
    bk = room("wickermoor_shop_bakery")
    prepend(bk["npcs"], "holly_aster", [
        entry("holly_aster", (6, 5), WM + "soup:serve", "flag.soup_siv and flag.soup_stove and not flag.soup_done"),
        entry("holly_aster", (6, 5), WM + "soup:holly_start", f"{PLAGUE} and not flag.soup_asked")])
    save("wickermoor_shop_bakery", bk)
    bt = room("wickermoor_shop_butcher")
    prepend(bt["npcs"], "siv_harga", [entry("siv_harga", (6, 5), WM + "soup:siv_talk", "flag.soup_asked and not flag.soup_siv")])
    prepend(bt["npcs"], "mrs_oakum", [
        entry("mrs_oakum", (9, 5), WM + "oakum:choose", "flag.oakum_known and not flag.oakum_outcome"),
        entry("mrs_oakum", (9, 5), WM + "oakum:start", f"{PLAGUE} and not flag.oakum_asked")])
    save("wickermoor_shop_butcher", bt)
    fh = room("wickermoor_funeral_home")
    if not any(p["id"] == "funeral_home_effects" for p in fh["props"]):
        fh["props"].append(prop("funeral_home_effects", (10, 3), "A shelf of a dead traveler's effects", "shelves", WM + "letter:effects", f"{PLAGUE} and not flag.letter_asked"))
    save("wickermoor_funeral_home", fh)
    ap = room("wickermoor_apothecary")
    if not any(p["id"] == "apothecary_note" for p in ap["props"]):
        ap["props"].append(prop("apothecary_note", (6, 3), "A note pinned to the counter", "papers", WM + "quack:morgan_ask", f"{PLAGUE} and not flag.quack_asked"))
    save("wickermoor_apothecary", ap)
    inn = room("wickermoor_green_queen_inn")
    if not any(n["npc"] == "granny_orla_pike" for n in inn["npcs"]):
        inn["npcs"].append(entry("granny_orla_pike", (4, 15), WM + "folk_plague:orla_start", PLAGUE))
    save("wickermoor_green_queen_inn", inn)
    # the verdict and settle talks with Barnaby follow the pitch: he is in the Round, so they are options of a second entry
    town = read("data/locations/wickermoor_village.json")
    if not any(n.get("dialogue") == WM + "quack:settle" for n in town["npcs"]):
        prepend(town["npcs"], "barnaby_pennywhistle", [
            entry("barnaby_pennywhistle", (33, 34), WM + "quack:settle", "flag.quack_known and not flag.quack_outcome"),
            entry("barnaby_pennywhistle", (33, 34), WM + "quack:verdict", "flag.quack_asked and not flag.quack_known")])
    save("wickermoor_village", town)


if __name__ == "__main__":
    main()
