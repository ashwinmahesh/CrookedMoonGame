#!/usr/bin/env python3
"""Morgan's Paranormal Potions (R11): twelve brews of the Hollow in our own words, written as items and listed in Morgan's shop (the engine
gates a magic line by the party's level and its rarity). Haint Hooch is R10's item. The effects are told in the text; the ones the game can
run are the ones its items already run (a drink is a consumable); the rest read as flavour until a lane builds them."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
POTIONS = [
    ("lilypad_tonic", "Lilypad Tonic", "common", 25, "A green, cloudy tonic that lets you stand on water for a minute, bobbing like a pad on a pond."),
    ("jinxed_rum", "Jinxed Rum", "uncommon", 100, "Dark rum with a salty finish: the drinker is lucky for an hour and unlucky for the hour after."),
    ("silence_of_the_drowned", "Silence of the Drowned", "uncommon", 100, "A bottle of pond-water that cannot be heard to slosh. Drunk, it silences every footstep and word for ten minutes."),
    ("elixir_of_fogwalking", "Elixir of Fogwalking", "rare", 400, "A silver-grey liquid. Drunk, you step through fog and mist as through an open door, and are hard to find in it for an hour."),
    ("harvest_brew", "Harvest Brew", "rare", 400, "A thick, sweet brew of grain and honey that feeds a person for a day and heals them a little at every meal after."),
    ("nightwatcher_potion", "Nightwatcher Potion", "rare", 400, "An amber draught that keeps the drinker awake and clear-eyed through a night, and lets them see in the dark."),
    ("sight_of_sin", "Sight of Sin", "rare", 400, "A bitter violet eyewash. For a minute the drinker sees what each person nearby is most ashamed of."),
    ("tincture_of_mourning", "Tincture of Mourning", "rare", 400, "A black tincture drunk by the grieving. It dulls sorrow and fear for a day and calls up the dead's last words."),
    ("wytchwood_sap", "Wytchwood Sap", "rare", 400, "Resin from a wytch-tree, sticky and warm. Smeared on a blade it bites deep into the fey and the undead for a time."),
    ("nectar_of_the_green_man", "Nectar of the Green Man", "very_rare", 4000, "Gold-green nectar from the oldest oak in the Hollow. For a day the drinker's skin takes on bark and their wounds close like cut wood."),
    ("draught_of_the_red_hunger", "Draught of the Red Hunger", "legendary", 20000, "A red draught that thirsts back. For a day the drinker's blows heal them and their hunger cannot be fed."),
]
for pid, name, rar, cost, text in POTIONS:
    d = {"id": pid, "name": name, "source": {"book": "CrookedMoon"}, "category": "potion", "weight_lb": 0.5, "cost_gp": cost,
         "magic": {"rarity": rar, "attunement": False}, "summary": text}
    (ROOT / "data/items" / f"{pid}.json").write_text(json.dumps(d, indent=2) + "\n")
npc = ROOT / "data/npcs/morgan.json"
m = json.loads(npc.read_text())
m["shop"]["magic"] = [p[0] for p in POTIONS] + ["haint_hooch"]
npc.write_text(json.dumps(m, indent=2) + "\n")
print("ok", len(POTIONS))
