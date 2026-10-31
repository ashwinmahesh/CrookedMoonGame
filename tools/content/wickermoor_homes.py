#!/usr/bin/env python3
"""ONE-SHOT (interiors): Wickermoor Village's buildings that had no inside: the stable, two cottages south of it, the hut north-east of the Round and
Gaston's studio. Writes their rooms, adds their doors to the town (idempotent), and furnishes them. Run from the repo root."""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G

ROOT = Path(__file__).resolve().parents[2]


def write(rel, obj):
    p = ROOT / rel
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def prop(pid, cell, label, model, text):
    return {"id": pid, "cell": list(cell), "kind": "examine", "label": label, "model": model, "text": text}


# key: (label, town door cell, outside square, width, height, furniture cells '=', props)
HOMES = {
    "wickermoor_stable": ("Marianna's Stable", (23, 38), (23, 37), 22, 14,
        lambda g: g.wall(7, 1, 7, 8).fill(7, 4, 7, 4, ".").wall(14, 1, 14, 8).fill(14, 4, 14, 4, ".").fill(2, 10, 6, 10, "=").fill(15, 10, 19, 10, "="),
        [("stall_one", (3, 3), "The first stall", "cupboard", "A grey mare shifts her weight and looks at you with one patient eye."),
         ("stall_two", (10, 3), "The second stall", "cupboard", "A mule, shaggy and calm, chewing nothing."),
         ("stall_three", (17, 3), "The third stall", "cupboard", "The stall is empty, swept clean, with a halter on the nail as if its owner will be back."),
         ("tack", (3, 11), "Tack and harness", "rope", "Saddles on pegs, each oiled and each stamped with a small hare."),
         ("hay", (17, 11), "The hay loft ladder", "ladder", "A ladder to the loft, the hay above it sweet and a little too fresh.")]),
    "wickermoor_cottage_south_a": ("A Cottage on the South Lane", (30, 42), (30, 43), 14, 12,
        lambda g: g.fill(2, 2, 6, 2, "=").put([(9, 6), (10, 6), (9, 7)], "="),
        [("hearth", (3, 1), "A cold hearth", "hearth", "The ash is a week old and a kettle has been left to rust on its hook."),
         ("table", (9, 6), "A table laid for three", "table_round", "Three bowls set out and never eaten from, a spoon in each."),
         ("bed", (11, 3), "A narrow bed", "bed", "A bed made with soldier's corners, a child's wooden hare tucked under the pillow.")]),
    "wickermoor_cottage_south_b": ("A Cottage on the South Lane", (36, 42), (36, 43), 14, 12,
        lambda g: g.fill(2, 2, 5, 2, "=").put([(8, 6), (9, 6)], "="),
        [("hearth", (3, 1), "A warm hearth", "hearth", "Embers glow under a pot of turnip stew that somebody stirred a moment ago."),
         ("loom", (10, 3), "A loom", "case", "A half-woven cloth in green and plum, the shuttle still threaded."),
         ("shelf", (3, 8), "A shelf of jars", "shelves", "Jars of pickles, each labelled with the date and, oddly, a mood.")]),
    "wickermoor_hut": ("A Herder's Hut", (51, 8), (51, 9), 12, 10,
        lambda g: g.fill(2, 2, 4, 2, "=").put([(8, 5), (9, 5)], "="),
        [("pallet", (9, 5), "A straw pallet", "bed", "A pallet by the wall, warm from a body that has just left it."),
         ("crook", (3, 3), "Shepherd's crooks", "rope", "Three crooks on pegs and a fourth peg bare."),
         ("pot", (2, 1), "A pot on a tripod", "hearth", "Oat porridge, burnt on the bottom, the spoon left standing in it.")]),
    "wickermoor_studio": ("Gaston's Studio", (15, 18), (16, 18), 16, 12,
        lambda g: g.fill(2, 2, 5, 2, "=").put([(10, 6), (11, 6), (12, 6)], "="),
        [("easel", (6, 5), "The painter's easel", "table_round", "A canvas half-finished, a field of waving grass under a night sky, and in the corner a tiny hare."),
         ("canvases", (13, 2), "Stacked canvases", "papers", "Finished canvases turned face to the wall, each signed with a smudge of red thumb."),
         ("palette", (4, 8), "A paint-crusted palette", "case", "Pigment gone hard, and a jar of brushes in water the colour of old wine.")]),
}


def main():
    town_p = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(town_p.read_text())
    for key, (label, door, outside, w, h, furnish, props) in HOMES.items():
        g = G(w, h).room(1, 1, w - 2, h - 2)
        furnish(g)
        dx = w // 2
        g.fill(dx, h - 1, dx, h - 1, ".")
        rows = g.rows()
        loc = {"id": key, "name": label, "region": "wickermoor", "summary": f"{label}, in Wickermoor Village.", "text": f"The inside of {label}: close, creaking and lived-in.",
               "map": {"rows": rows, "theme": "manor", "light": "dim", "outdoors": False},
               "areas": [{"id": "room", "name": label, "cells": [[1, 1], [w - 2, h - 2]]}], "spawns": {"default": [dx, h - 2]},
               "exits": [{"id": "door", "cell": [dx, h - 1], "to": "wickermoor_village", "spawn": "from_" + key[len("wickermoor_"):], "label": "Out to the village"}],
               "props": [prop(f"{key[len('wickermoor_'):]}_{s}", c, l, m, t) for (s, c, l, m, t) in props], "npcs": [], "rest": "risky",
               "lights": [{"cell": [3, 3], "kind": "candle", "bright_ft": 15, "dim_ft": 30, "color": "candle"}]}
        write(f"data/locations/{key}.json", loc)
        sp = "from_" + key[len("wickermoor_"):]
        town["spawns"][sp] = list(outside)
        if not any(e["id"] == key[len("wickermoor_"):] for e in town["exits"]):
            town["exits"].append({"id": key[len("wickermoor_"):], "cell": list(door), "to": key, "spawn": "default", "label": "Enter " + label})
    town_p.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
