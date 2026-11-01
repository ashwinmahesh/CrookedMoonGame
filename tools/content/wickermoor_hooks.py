#!/usr/bin/env python3
"""ONE-SHOT (R11 hooks): wires Wickermoor to the engine's act-1 hooks: a catchable goat in the wolf fight, faction standing, the stable's mounts and the
jail. Idempotent JSON edits plus appended dialogue nodes; run once from the repo root."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]


def edit(rel, fn):
    p = ROOT / rel
    d = json.loads(p.read_text())
    fn(d)
    p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")


def append(rel, text, marker):
    p = ROOT / rel
    t = p.read_text()
    if marker not in t:
        p.write_text(t.rstrip("\n") + "\n\n" + text.strip("\n") + "\n")


def goat(town):   # the freed goat runs loose through the fight and can be caught; the wolves start nearer so it matters
    encs = town["encounters"]
    if any(e.get("id") == "wm_first_sacrifice" and e.get("when") for e in encs):
        return
    base = next(e for e in encs if e["id"] == "wm_first_sacrifice")
    var = json.loads(json.dumps(base))
    var["when"] = "flag.goat_fate == freed or flag.goat_fate == freed_eaten"
    for m in var["monsters"]:
        m["cell"] = [m["cell"][0] - 7, m["cell"][1]]
    var["monsters"].append({"monster": "goat", "cell": [33, 27], "name": "The baby goat", "side": "neutral", "catch": {"flag": "goat_caught"}})
    encs.insert(encs.index(base), var)


edit("data/locations/wickermoor_village.json", goat)


def flags(d):
    if not any(f["id"] == "goat_caught" for f in d["flags"]):
        d["flags"].append({"id": "goat_caught", "type": "bool", "summary": "A hero caught the loose goat in the wolf fight.", "read_later": True})


edit("data/flags/wickermoor.json", flags)


def mounts(d):
    d.setdefault("services", [])
    if not any(s["id"] == "mounts" for s in d["services"]):
        d["services"].append({"id": "mounts", "price": 10, "days": 3})


edit("data/npcs/marianna_grey.json", mounts)
p = ROOT / "narrative/wickermoor/marianna_grey.dialogue"
t = p.read_text()
if "services" not in t:
    p.write_text(t.replace("marianna_grey [neutral]: Tell me what beast or tack you have need of.\n", "marianna_grey [neutral]: Tell me what beast or tack you have need of.\nservices\n", 1))

# standing: the Old Ways mind a spoiled rite and approve of leaving it be
p = ROOT / "narrative/wickermoor/arrival.dialogue"
t = p.read_text()
if "standing old_ways" not in t:
    t = t.replace("set old_ways_offended\n", "set old_ways_offended\nstanding old_ways -2\n")
    t = t.replace('set goat_fate = "eaten"\nset wm_first_sacrifice_done\n', 'set goat_fate = "eaten"\nstanding old_ways +1\nset wm_first_sacrifice_done\n')
    p.write_text(t)


def station(d):
    d["spawns"].setdefault("cells", [9, 3])
    for e in d["exits"]:
        if e["id"] == "door":
            e["when"] = "not jailed"
    if not any(n.get("when") == "jailed" for n in d["npcs"]):
        d["npcs"].insert(0, {"npc": "doris_squire", "cell": [9, 8], "dialogue": "watch/wickermoor:jail_talk", "when": "jailed"})


edit("data/locations/wickermoor_constable_station.json", station)
p = ROOT / "narrative/watch/wickermoor.dialogue"
t = p.read_text()
if "~ surrender" not in t:
    t = t.replace("* Refuse -> refuse\n", "* Refuse -> refuse\n* Go quietly with the watch -> surrender\n", 1)
    p.write_text(t)
append("narrative/watch/wickermoor.dialogue", '''
~ surrender
doris_squire [neutral]: Sensible. Hand over your gear. You will have a bed, a bucket and a day to think.
Narrator: The cell door is only a barred frame, but there is nowhere in Wickermoor to take what they have kept.
set crime_wickermoor = 0
jail wickermoor_constable_station:cells until days_since.jailed >= 1

~ jail_talk
doris_squire [neutral]: You have had your day. The offence is written off.
* Ask for our gear and go -> jail_out
* Ask what the village thinks of us -> jail_village

~ jail_village
doris_squire [neutral]: It thinks you are strangers. It thinks that of everyone.
-> jail_talk

~ jail_out
doris_squire [neutral]: Out. Mind the doors.
jail release
-> END''', "~ surrender")
