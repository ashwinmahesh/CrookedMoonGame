#!/usr/bin/env python3
"""ONE-SHOT (world-quests2, batch 2 of the Act 1 side-quest plan, vault Build/Side Quest Plan - Act 1.md): Wickermoor's A Fair Price, Weight on
the Bell and The Schoolmaster's Field Trip, and the humorous locals Tamsin Ledger, Sergeant Gaunt and Pip Oakum. Writes quests, flags, NPCs and
placements (idempotent); the dialogue is narrative/wickermoor/{fair_price,bell,fieldtrip,folk}.dialogue. Run from the repo root."""
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
    {"id": "a_fair_price", "name": "A Fair Price", "kind": "side", "region": "wickermoor", "giver": "baltus_tolliver",
     "summary": "Baltus Tolliver and Eleanor Heyling are undercutting each other's paper and ink, and each says the other cheats.",
     "stages": [st("asked", "Baltus Tolliver says Eleanor Heyling sells paper below cost; Eleanor says his scale is rigged.", "Look at Eleanor's ledger at the bookshop, or ask Tamsin Ledger at the Mayor's House to audit it.", ["Learn the truth", "Settle it"]),
                st("done", "The price war is settled, one way or another.", ends="success")]},
    {"id": "weight_on_the_bell", "name": "Weight on the Bell", "kind": "side", "region": "wickermoor", "giver": "solomon_roderick",
     "summary": "The clocktower's new bell must be carried from the south footbridge to the Round by dusk.",
     "stages": [st("asked", "Solomon Roderick needs the new clocktower bell carried by cart from the footbridge to the Round by dusk.", "Go to the cart at the south footbridge.", ["Carry the bell to the Round"]),
                st("done", "The bell hangs in the clocktower.", ends="success"),
                st("lost", "We left the bell on its cart, and Solomon sent a labourer to fetch it.", ends="failure")]},
    {"id": "field_trip", "name": "The Schoolmaster's Field Trip", "kind": "side", "region": "wickermoor", "giver": "finneas_trout",
     "summary": "Finneas Trout wants five things the pupils can hold, and one thing told gently.",
     "stages": [st("asked", "Finneas Trout wants a button from Pip Oakum, a fact from Old Rusty, a thread of the bell-rope, a chalk mark from the church, and one thing he will tell us about at the end.", "Gather the things in the village, then see Finneas at the schoolhouse.", ["Four things gathered", "Report to Finneas"]),
                st("done", "The pupils had their lesson.", ends="success")]},
]
FLAGS = [("price_asked", "bool"), ("price_ledger_seen", "bool"), ("price_outcome", "string"),
         ("bell_asked", "bool"), ("bell_done", "bool"), ("bell_abandoned", "bool"), ("bell_cracked", "bool"), ("bell_late", "bool"), ("bell_route", "string"), ("bell_pip", "string"), ("gaunt_hired", "bool"),
         ("field_trip_asked", "bool"), ("field_items", "int"), ("field_pip", "bool"), ("field_rusty", "bool"), ("field_rope", "bool"), ("field_chalk", "bool"), ("field_outcome", "string")]
PEOPLE = [("tamsin_ledger", "Tamsin Ledger", "Apprentice auditor", "indifferent", "A brisk, deadpan clerk from the county seat who treats everything strange as a clerical error.", "newcomers"),
          ("sgt_gaunt", "Sergeant Gaunt", "Retired sergeant", "friendly", "An overconfident coward who has never lost a battle he was present for the end of.", "none"),
          ("pip_oakum", "Pip Oakum", "A small boy", "friendly", "A boy who collects buttons and trades them like gold; every grown-up in the village owes him one.", "none")]


def entry(npc, cell, dialogue, when):
    return {"npc": npc, "cell": list(cell), "dialogue": dialogue, "when": when}


def prepend(loc_npcs, npc, new):
    i = next((j for j, n in enumerate(loc_npcs) if n["npc"] == npc), 0)
    loc_npcs[i:i] = new


def main():
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)
    write("data/flags/wm_side_quests2.json", {"flags": [{"id": i, "type": t, "summary": "Side quests batch 2 (wickermoor_side_quests2.py).", "read_later": True} for (i, t) in FLAGS]})
    for nid, name, title, att, summary, fac in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "attitude": att, "sprite": "villager", "region": "wickermoor", "summary": summary, "tags": [f"faction_{fac}", "voice_hollow"]})
    town = read("data/locations/wickermoor_village.json")
    if not any(n["npc"] == "sgt_gaunt" for n in town["npcs"]):
        town["npcs"] += [entry("sgt_gaunt", (26, 37), WM + "folk:gaunt_start", "flag.wm_welcomed"),
                         entry("pip_oakum", (24, 20), WM + "fieldtrip:pip_button", "flag.field_trip_asked and not flag.field_pip"),
                         entry("pip_oakum", (24, 20), WM + "folk:pip_start", "flag.wm_welcomed")]
    prepend(town["npcs"], "old_rusty", [entry("old_rusty", (28, 24), WM + "fieldtrip:rusty_fact", "flag.field_trip_asked and not flag.field_rusty")])
    ids = {p["id"] for p in town["props"]}
    if "wm_bell_cart" not in ids:
        town["props"] += [
            {"id": "wm_bell_cart", "cell": [30, 44], "kind": "examine", "label": "The bell on its cart", "model": "cart", "dialogue": WM + "bell:cart", "when": "flag.bell_asked and not flag.bell_done and not flag.bell_abandoned"},
            {"id": "wm_bell_rope", "cell": [44, 26], "kind": "examine", "label": "The clocktower's bell-rope", "model": "rope", "dialogue": WM + "fieldtrip:rope", "when": "flag.field_trip_asked and not flag.field_rope"}]
    write("data/locations/wickermoor_village.json", town)

    def room(key):
        return read(f"data/locations/{key}.json")
    tp = room("wickermoor_trading_post")
    prepend(tp["npcs"], "baltus_tolliver", [
        entry("baltus_tolliver", (10, 10), WM + "fair_price:broker", "flag.price_ledger_seen and not flag.price_outcome"),
        entry("baltus_tolliver", (10, 10), WM + "fair_price:baltus_start", "flag.wm_welcomed and not flag.price_asked")])
    write("data/locations/wickermoor_trading_post.json", tp)
    bs = room("wickermoor_bookstore")
    prepend(bs["npcs"], "eleanor_heyling", [entry("eleanor_heyling", (6, 5), WM + "fair_price:eleanor_visit", "flag.price_asked and not flag.price_ledger_seen")])
    write("data/locations/wickermoor_bookstore.json", bs)
    mh = room("wickermoor_mayors_house")
    if not any(n["npc"] == "tamsin_ledger" for n in mh["npcs"]):
        mh["npcs"] += [entry("tamsin_ledger", (18, 9), WM + "fair_price:tamsin_audit", "flag.price_asked and not flag.price_ledger_seen"),
                       entry("tamsin_ledger", (18, 9), WM + "folk:tamsin_start", "flag.wm_welcomed")]
    write("data/locations/wickermoor_mayors_house.json", mh)
    ms = room("wickermoor_shop_masonry")
    prepend(ms["npcs"], "solomon_roderick", [entry("solomon_roderick", (6, 5), WM + "bell:start", "flag.wm_welcomed and not flag.bell_asked")])
    write("data/locations/wickermoor_shop_masonry.json", ms)
    sc = room("wickermoor_schoolhouse")
    prepend(sc["npcs"], "finneas_trout", [
        entry("finneas_trout", (7, 2), WM + "fieldtrip:report", "flag.field_items >= 4 and not flag.field_outcome"),
        entry("finneas_trout", (7, 2), WM + "fieldtrip:start", "flag.wm_welcomed and not flag.field_trip_asked")])
    write("data/locations/wickermoor_schoolhouse.json", sc)
    ch = room("wickermoor_church")
    if not any(p["id"] == "church_hare_mark" for p in ch["props"]):
        ch["props"].append({"id": "church_hare_mark", "cell": [5, 6], "kind": "examine", "label": "A chalk hare on the wall", "model": "papers", "dialogue": WM + "fieldtrip:chalk", "when": "flag.field_trip_asked and not flag.field_chalk"})
    write("data/locations/wickermoor_church.json", ch)


if __name__ == "__main__":
    main()
