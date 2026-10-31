#!/usr/bin/env python3
"""ONE-SHOT (batch 5 of the Act 1 side-quest plan, vault Build/Side Quest Plan - Act 1.md): the Ghostlight Express's The Conductor's Punch, A Seat
for the Lord and Lady, the conductor's understudy and Mrs. Calloway. Dialogue: narrative/ghostlight_express/{punch,seating,folk_train}.dialogue.
Idempotent; run from the repo root."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
GL = "ghostlight_express/"


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
    {"id": "conductors_punch", "name": "The Conductor's Punch", "kind": "side", "region": "ghostlight_express", "giver": "conductor_understudy",
     "summary": "The real conductor's ticket punch is missing, and a smaller frog in a smaller hat wants it found.",
     "stages": [st("asked", "The conductor's understudy says the real punch is missing. Ticket stubs with a star-shaped hole turn up in the sleeper and the mail car.", "Look for stubs in the sleeper and mail cars, and a chest in the circus car.", ["Find the punch"]),
                st("found", "We have the conductor's punch.", "Take it back to the understudy in the passenger car.", ["Return the punch"]),
                st("done", "The punch has a home again.", ends="success")]},
    {"id": "a_seat_for_the_lord", "name": "A Seat for the Lord and Lady", "kind": "side", "region": "ghostlight_express", "giver": "phillip_druskenvald",
     "summary": "Three ghost passengers will only sit in the lounge by rank, and Lord Phillip fears a scene.",
     "stages": [st("asked", "Phillip wants the songstress, the daydreamer and the harlequin seated in the lounge without a slight.", "Use the banquette in the lounge car; Lady Adela may know the order.", ["Seat the three ghosts"]),
                st("done", "The lounge is seated, quietly or not.", ends="success")]},
]
FLAGS = [("punch_asked", "bool"), ("punch_clue", "int"), ("punch_found", "bool"), ("punch_outcome", "string"), ("seating_asked", "bool"), ("seating_outcome", "string")]
PEOPLE = [("conductor_understudy", "The Understudy", "The conductor's understudy", "friendly", "A second, smaller frog in a smaller hat who insists he is the real conductor.", "none"),
          ("mrs_calloway", "Mrs. Calloway", "A widow-ghost", "friendly", "A dining-car ghost who sets a place every night for a husband a century late.", "none")]


def entry(npc, cell, dialogue, when):
    return {"npc": npc, "cell": list(cell), "dialogue": dialogue, "when": when}


def prop(pid, cell, label, model, dialogue, when):
    return {"id": pid, "cell": list(cell), "kind": "examine", "label": label, "model": model, "dialogue": dialogue, "when": when}


def main():
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)
    write("data/flags/gl_side_quests5.json", {"flags": [{"id": i, "type": t, "summary": "Side quests batch 5 (ghostlight_side_quests5.py).", "read_later": True} for (i, t) in FLAGS]})
    write("data/items/conductors_punch.json", {"id": "conductors_punch", "name": "The conductor's ticket punch", "source": {"book": "CrookedMoon"}, "category": "quest", "weight_lb": 0, "cost_gp": 0, "summary": "A brass ticket punch that leaves a star-shaped hole."})
    for nid, name, title, att, summary, fac in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "attitude": att, "sprite": "villager", "region": "ghostlight_express", "summary": summary, "tags": [f"faction_{fac}", "voice_hollow"]})

    def room(key):
        return read(f"data/locations/{key}.json")
    g1 = room("ghostlight_g1_passenger")
    if not any(n["npc"] == "conductor_understudy" for n in g1["npcs"]):
        g1["npcs"] += [entry("conductor_understudy", (14, 5), GL + "punch:return", "flag.punch_found and not flag.punch_outcome"),
                       entry("conductor_understudy", (14, 5), GL + "punch:start", "flag.gl_aboard_welcomed and not flag.punch_asked and not flag.gl_crashed")]
    write("data/locations/ghostlight_g1_passenger.json", g1)
    for key, pid, cell, label, model, dlg, when in (
            ("ghostlight_g2_sleeper", "g2_punched_stub", (14, 4), "A punched ticket stub", "papers", "punch:stub", "flag.punch_asked and not flag.punch_found and not flag.stub_sleeper"),
            ("ghostlight_g5_mail", "g5_punched_stub", (2, 4), "A punched ticket stub", "papers", "punch:stub_mail", "flag.punch_asked and not flag.punch_found and not flag.stub_mail"),
            ("ghostlight_g7_circus", "g7_punch_chest", (13, 5), "The marionette chest's lid", "case", "punch:chest", "flag.punch_asked and not flag.punch_found"),
            ("ghostlight_g3_lounge", "g3_banquette", (6, 4), "The lounge banquette", "chairs", "seating:seat", "flag.seating_asked and not flag.seating_outcome")):
        loc = room(key)
        if not any(p["id"] == pid for p in loc["props"]):
            loc["props"].append(prop(pid, cell, label, model, GL + dlg, when))
        write(f"data/locations/{key}.json", loc)
    g3 = room("ghostlight_g3_lounge")
    if not any(n.get("dialogue") == GL + "seating:start" for n in g3["npcs"]):
        i = next(j for j, n in enumerate(g3["npcs"]) if n["npc"] == "phillip_druskenvald")
        g3["npcs"].insert(i, entry("phillip_druskenvald", (10, 3), GL + "seating:start", "flag.gl_lounge_met and not flag.seating_asked and not flag.gl_crashed"))
    write("data/locations/ghostlight_g3_lounge.json", g3)
    g4 = room("ghostlight_g4_dining")
    if not any(n["npc"] == "mrs_calloway" for n in g4["npcs"]):
        g4["npcs"].append(entry("mrs_calloway", (15, 4), GL + "folk_train:calloway_start", "not flag.gl_crashed"))
    write("data/locations/ghostlight_g4_dining.json", g4)
    flags = read("data/flags/gl_side_quests5.json")
    for i in ("stub_sleeper", "stub_mail"):
        if not any(f["id"] == i for f in flags["flags"]):
            flags["flags"].append({"id": i, "type": "bool", "summary": "A punched stub was found (batch 5).", "read_later": True})
    write("data/flags/gl_side_quests5.json", flags)


if __name__ == "__main__":
    main()
