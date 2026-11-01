#!/usr/bin/env python3
"""ONE-SHOT (world-quests4, batch 4 of the Act 1 side-quest plan, vault Build/Side Quest Plan - Act 1.md): Foxwillow after Raum: Two Curses (mystery),
The Scarecrows' Choir (puzzle), Rosemary's Crow (friendship), and Agatha Pell, Old Tom Crowley and Malachai Voss. Dialogue:
narrative/foxwillow/{two_curses,choir,rosemary,folk_foxwillow}.dialogue. Idempotent; run from the repo root."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
FW = "foxwillow/"


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
    {"id": "two_curses", "name": "Two Curses", "kind": "side", "region": "foxwillow", "giver": "jonah_sawyer",
     "summary": "Raum is dead, but Foxwillow's herds still sour: the butcher's old spite-hex is a second curse.",
     "stages": [st("asked", "Jonah Sawyer says the milk and the herds are still turning, though Raum is dead. He points at the butcher's chalk circle.", "Look at the chalk circle in the butcher's back room, and talk to Malachai Voss.", ["Undo or lift the hex"]),
                st("done", "The second curse is lifted, one way or another.", ends="success")]},
    {"id": "scarecrows_choir", "name": "The Scarecrows' Choir", "kind": "side", "region": "foxwillow", "giver": "librarian_agnes_fennel",
     "summary": "Twenty child scarecrows hum the chalk song in the schoolhouse, still asleep inside their straw.",
     "stages": [st("asked", "Agnes Fennel says the children will wake only if their song is sung in the true order.", "Ask Agnes for the order if you need it, then sing the song to the children in the schoolhouse.", ["Sing the song in order"]),
                st("done", "The children woke.", ends="success")]},
    {"id": "rosemarys_crow", "name": "Rosemary's Crow", "kind": "side", "region": "foxwillow", "giver": "rosemary_langtree",
     "summary": "A small amber-eyed crow will not leave Rosemary Langtree, and the town wants it gone.",
     "stages": [st("asked", "Rosemary Langtree has a crow called Beak that will not leave her. The town wants it gone.", "Ask Old Tom Crowley in the lanes what kind of crow it is, then see Rosemary.", ["Ask Old Tom", "Decide Beak's fate"]),
                st("done", "Beak has a place now, or has gone.", ends="success")]},
]
FLAGS = [("curses_asked", "bool"), ("curses_outcome", "string"), ("curses_blessed", "bool"), ("choir_asked", "bool"), ("choir_woken", "bool"),
         ("crow_asked", "bool"), ("crow_tom_heard", "bool"), ("crow_outcome", "string")]
PEOPLE = [("malachai_voss", "Malachai Voss", "The butcher", "indifferent", "A sour butcher who has held one grudge against the Langtrees for forty years.", "none"),
          ("agatha_pell", "Agatha Pell", "Pie seller", "friendly", "A pie seller who kept selling pies all through the fire.", "none"),
          ("old_tom_crowley", "Old Tom Crowley", "A crow whisperer", "friendly", "A farmhand who argues with crows as if they owed him rent.", "none")]


def entry(npc, cell, dialogue, when):
    return {"npc": npc, "cell": list(cell), "dialogue": dialogue, "when": when}


def prepend(loc_npcs, npc, new):
    i = next((j for j, n in enumerate(loc_npcs) if n["npc"] == npc), 0)
    loc_npcs[i:i] = new


def open_near(rows, cell):
    x0, y0 = cell
    for r in range(0, 6):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                x, y = x0 + dx, y0 + dy
                if 0 <= y < len(rows) and 0 <= x < len(rows[y]) and rows[y][x] == ".":
                    return [x, y]
    return list(cell)


def main():
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)
    write("data/flags/fw_side_quests4.json", {"flags": [{"id": i, "type": t, "summary": "Side quests batch 4 (foxwillow_side_quests4.py).", "read_later": True} for (i, t) in FLAGS]})
    for nid, name, title, att, summary, fac in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "attitude": att, "sprite": "villager", "region": "foxwillow", "summary": summary, "tags": [f"faction_{fac}", "voice_hollow"]})
    town = read("data/locations/foxwillow.json")
    rows = town["map"]["rows"]
    if not any(n["npc"] == "agatha_pell" for n in town["npcs"]):
        tom = open_near(rows, (22, 30))
        town["npcs"] += [entry("agatha_pell", (35, 26), FW + "folk_foxwillow:agatha_start", "flag.fw_arrived"),
                         entry("old_tom_crowley", tom, FW + "rosemary:old_tom", "flag.crow_asked and not flag.crow_tom_heard"),
                         entry("old_tom_crowley", tom, FW + "folk_foxwillow:tom_start", "flag.fw_arrived"),
                         entry("rosemary_langtree", (54, 12), FW + "rosemary:decide", "flag.crow_tom_heard and not flag.crow_outcome"),
                         entry("rosemary_langtree", (54, 12), FW + "rosemary:start", "flag.raum_slain and not flag.crow_asked")]
    prepend(town["npcs"], "jonah_sawyer", [entry("jonah_sawyer", (31, 31), FW + "two_curses:start", "flag.raum_slain and not flag.curses_asked")])
    write("data/locations/foxwillow.json", town)

    def room(key):
        return read(f"data/locations/{key}.json")
    bt = room("fw_butcher")
    if not any(n["npc"] == "malachai_voss" for n in bt["npcs"]):
        bt["npcs"].append(entry("malachai_voss", (11, 4), FW + "two_curses:malachai", "flag.curses_asked"))
        bt["props"].append({"id": "fw_butcher_hex", "cell": [6, 8], "kind": "examine", "label": "The red chalk circle", "model": "rags", "dialogue": FW + "two_curses:circle", "when": "flag.curses_asked and not flag.curses_outcome"})
    write("data/locations/fw_butcher.json", bt)
    sc = room("fw_schoolhouse")
    if not any(p["id"] == "fw_schoolhouse_choir" for p in sc["props"]):
        sc["props"].append({"id": "fw_schoolhouse_choir", "cell": [8, 5], "kind": "examine", "label": "The humming children", "model": "scarecrow", "dialogue": FW + "choir:teach", "when": "flag.choir_asked and not flag.choir_woken"})
    write("data/locations/fw_schoolhouse.json", sc)
    lb = room("fw_library")
    prepend(lb["npcs"], "librarian_agnes_fennel", [entry("librarian_agnes_fennel", (9, 10), FW + "choir:start", "flag.raum_slain and not flag.choir_asked")])
    write("data/locations/fw_library.json", lb)


if __name__ == "__main__":
    main()
