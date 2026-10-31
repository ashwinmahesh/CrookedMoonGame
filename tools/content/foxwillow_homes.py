#!/usr/bin/env python3
"""ONE-SHOT (interiors): the houses of Foxwillow that had no inside: the Langtree farmhouse, William Lodge's farmhouse, the Sawyer house, a tenant
cottage, a burnt cottage and the smokehouse. Writes their rooms and adds their doors to the town (idempotent). Run from the repo root."""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from wickermoor_interiors import G

ROOT = Path(__file__).resolve().parents[2]


def prop(pid, cell, label, model, text):
    return {"id": pid, "cell": list(cell), "kind": "examine", "label": label, "model": model, "text": text}


HOMES = {   # key: (label, town door, outside square, w, h, furnish, props)
    "fw_langtree_farmhouse": ("The Langtree Farmhouse", (53, 11), (53, 12), 22, 14, lambda g: g.fill(2, 2, 8, 2, "=").put([(12, 6), (13, 6), (14, 6), (12, 7), (13, 7), (14, 7)], "="),
        [("table", (13, 6), "The long table", "table_round", "Seven chairs, six places laid. The seventh chair has a cloth over it, and a man's pipe on the cloth."),
         ("hearth", (3, 1), "The farmhouse hearth", "hearth", "A fire banked low under a pot of porridge, kept warm by someone who expects company."),
         ("portrait", (16, 2), "A family portrait", "papers", "Martha, Isaac, Adelaide as a girl, and a scarecrow drawn in at the edge in a child's wax crayon.")]),
    "fw_lodge_farmhouse": ("William Lodge's Farmhouse", (36, 44), (36, 45), 16, 12, lambda g: g.fill(2, 2, 5, 2, "=").put([(9, 6), (10, 6)], "="),
        [("table", (9, 6), "A bare table", "table_round", "A plate, a cup, a hat on a peg. William lives alone and it shows."),
         ("ledger", (3, 8), "A rent ledger", "ledger", "Rent owed to the Langtrees in a careful hand, and beside it a note: 'told the preacher about the coin'."),
         ("bed", (12, 3), "A narrow bed", "bed", "A bed with the blanket turned back, as if someone had been called away in the middle of the night.")]),
    "fw_sawyer_house": ("The Sawyer House", (7, 19), (7, 20), 14, 12, lambda g: g.fill(2, 2, 4, 2, "=").put([(8, 6), (9, 6)], "="),
        [("twin_beds", (10, 3), "Two small beds", "bed", "Two beds, one with a scarecrow's straw hat on the pillow, one with a boy's boots beside it."),
         ("hearth", (3, 1), "The hearth", "hearth", "A sooty hearth with a half-burnt letter in the grate."),
         ("shelf", (3, 8), "A shelf of toys", "shelves", "A tin soldier, a wooden crow, and a rag doll with a pumpkin face drawn on it in charcoal.")]),
    "fw_tenant_cottage": ("A Tenant Cottage", (8, 33), (8, 34), 12, 10, lambda g: g.fill(2, 2, 4, 2, "=").put([(7, 5), (8, 5)], "="),
        [("bed", (8, 5), "A bed", "bed", "The straw tick is slashed open and the straw is gone."),
         ("pot", (3, 1), "A cooking pot", "hearth", "A pot of something that was soup, with a corn husk floating in it."),
         ("door", (6, 8), "A message in chalk", "papers", "'We are going to the corn. Tell Martha we are sorry.' Nobody has erased it.")]),
    "fw_burnt_cottage": ("A Burnt Cottage", (42, 45), (42, 46), 14, 12, lambda g: g.fill(2, 2, 6, 2, "=").put([(9, 6), (10, 6)], "="),
        [("ash", (5, 5), "Ash and charred beams", "rocks", "The roof is open to the sky and the floor is black. Something was burned here before the fire started."),
         ("scarecrow", (10, 3), "A scarecrow, half-burnt", "scarecrow", "A straw figure in a farmer's coat, burned from the knees down. It breathes."),
         ("locket", (3, 8), "A blackened box", "case", "A music box that plays three notes of a song and then stops.")]),
    "fw_smokehouse": ("The Smokehouse", (50, 43), (50, 44), 12, 10, lambda g: g.fill(2, 2, 9, 2, "=").put([(5, 5), (6, 5)], "="),
        [("hooks", (3, 3), "Hanging hams", "rope", "Hams on their hooks, all gone to grey fur in a single night."),
         ("brazier", (6, 6), "A smouldering brazier", "hearth", "A small fire kept low for the smoking, burning by itself though no one has fed it."),
         ("crow", (9, 2), "A crow on a rafter", "crow", "A crow watches you from the rafters, its eyes the colour of weak tea.")]),
}


def main():
    town_p = ROOT / "data/locations/foxwillow.json"
    town = json.loads(town_p.read_text())
    for key, (label, door, outside, w, h, furnish, props) in HOMES.items():
        g = G(w, h).room(1, 1, w - 2, h - 2)
        furnish(g)
        dx = w // 2
        g.fill(dx, h - 1, dx, h - 1, ".")
        loc = {"id": key, "name": label, "region": "foxwillow", "summary": f"{label}, in Foxwillow.", "text": f"The inside of {label}.",
               "map": {"rows": g.rows(), "theme": "manor", "light": "dim", "outdoors": False},
               "areas": [{"id": "room", "name": label, "cells": [[1, 1], [w - 2, h - 2]]}], "spawns": {"default": [dx, h - 2]},
               "exits": [{"id": "door", "cell": [dx, h - 1], "to": "foxwillow", "spawn": "from_" + key, "label": "Out to the town"}],
               "props": [prop(f"{key}_{s}", c, l, m, t) for (s, c, l, m, t) in props], "npcs": [], "rest": "risky",
               "lights": [{"cell": [3, 3], "kind": "candle", "bright_ft": 15, "dim_ft": 30, "color": "candle"}]}
        (ROOT / f"data/locations/{key}.json").write_text(json.dumps(loc, indent=2, ensure_ascii=False) + "\n")
        town["spawns"]["from_" + key] = list(outside)
        if not any(e["id"] == key for e in town["exits"]):
            town["exits"].append({"id": key, "cell": list(door), "to": key, "spawn": "default", "label": "Enter " + label})
    town_p.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
