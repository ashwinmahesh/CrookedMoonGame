#!/usr/bin/env python3
"""ONE-SHOT (R15). Appends the Sinner's wares menus to narrative/drowned_crossroads/shack.dialogue: thirteen Dark Bargains (the engine's dark_gift pick
shows each bargain's boon and price before anyone accepts), twelve potions and three curios, one to a hero (`sinner_deals`, up to four). A hand-written
file: Gemini drafted the rest of shack.dialogue. Run once from the repo root."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
F = ROOT / "narrative/drowned_crossroads/shack.dialogue"
GIFTS = ["bestial_awakening", "call_of_the_lonely", "collector_of_stories", "crooked_fortune", "cult_of_personality", "hand_of_death", "might_of_the_old",
         "self_serving_sacrifice", "shrouded_spirit", "skin_of_coffin_nails", "stilled_hungers", "unquenchable_fury", "wings_of_whispers"]
POTIONS = ["lilypad_tonic", "jinxed_rum", "silence_of_the_drowned", "elixir_of_fogwalking", "harvest_brew", "nightwatcher_potion", "sight_of_sin",
           "tincture_of_mourning", "wytchwood_sap", "nectar_of_the_green_man", "draught_of_the_red_hunger", "haint_hooch"]
CURIOS = ["the_bag", "green_ribbon", "amber_birdcage"]


def item(i):
    return json.loads((ROOT / f"data/items/{i}.json").read_text())


def gift(g):
    return json.loads((ROOT / f"data/dark_gifts/{g}.json").read_text())


def blind(cond):
    return f"if {cond} and not flag.small_print_read\nset deal_taken_blind\nendif\n"


out = ["", "# The wares (hand-written; see tools/content/crossroads_shop.py)", "",
       "~ wares",
       "mister_crossroads [smile]: Every bargain here costs a handshake and every trinket three copper, friend. One to a customer, and I am a stickler.",
       "if flag.small_print_read",
       "Narrator: Cora Beaudry's three tales sit in your head like a lamp: you can read the small print on every tag.",
       "endif",
       "* [if flag.sinner_deals < 4] A dark bargain, for a handshake -> bargains",
       "* [if flag.sinner_deals < 4] A potion, tagged 3 CP -> potions",
       "* [if flag.sinner_deals < 4] A curio or an idol, tagged 3 CP -> curios",
       "* [if flag.sinner_deals >= 1] That is all of us -> done_trading",
       "* Back to our talk -> parley_menu", ""]
out += ["~ bargains", "mister_crossroads [sly]: A handshake is a small thing. It is binding once sealed, but small. Choose with your eyes open: each one shows its price."]
for g in GIFTS:
    out.append(f"* [if not flag.deal_{g}] {gift(g)['name']} -> take_{g}")
out += ["* Look at something else -> wares", ""]
for g in GIFTS:
    d = gift(g)
    out += [f"~ take_{g}", f"Narrator: A paper tag on a string reads 3 CP, and under it, in small print: {d['summary']}", "mister_crossroads [smile]: A handshake, then. Who is it to be?",
            f"dark_gift {g}",
            blind(f"gift:{g} and not flag.deal_{g}").rstrip("\n"),
            f"if gift:{g} and not flag.deal_{g}", f"set deal_{g}", "set sinner_deals += 1",
            "Narrator: His hand is warm and dry, and something in your chest signs.", "endif", "-> wares", ""]
out += ["~ potions", "mister_crossroads [smile]: From the bottles that glow, friend. Three copper a bottle, and I never overcharge."]
for w in POTIONS:
    out.append(f"* [if not flag.ware_{w}] {item(w)['name']} -> take_{w}")
out += ["* Look at something else -> wares", ""]
for w in POTIONS + CURIOS:
    it = item(w)
    kind = "curse" if w in CURIOS else "small print"
    cost = it.get("magic", {}).get("curse") or "the tag says only what the bottle does; the rest is between you and the bottle."
    out += [f"~ take_{w}", f"Narrator: A paper tag reads 3 CP. {it.get('summary', '')}", f"Narrator: The {kind}: {cost}",
            "mister_crossroads [smile]: Wrapped, and on the house, practically.", f"give {w}",
            blind(f"not flag.ware_{w}").rstrip("\n"),
            f"set ware_{w}", "set sinner_deals += 1", "-> wares", ""]
out += ["~ curios", "mister_crossroads [sly]: Curios, idols, a bag. Some of them are old friends of mine."]
for w in CURIOS:
    out.append(f"* [if not flag.ware_{w}] {item(w)['name']} -> take_{w}")
out += ["* Look at something else -> wares", ""]
txt = F.read_text() if F.exists() else ""
if "~ wares" not in txt:
    F.write_text(txt.rstrip("\n") + "\n" + "\n".join(out) + "\n")
    print("appended")
