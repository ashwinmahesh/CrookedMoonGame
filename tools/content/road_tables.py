#!/usr/bin/env /usr/bin/python3
"""Fun pass, lane D: writes the road encounter tables (data/random_encounters/<table>.json) and names each road's table in
data/travel/wickermoor_hollow.json. The book asks for road fights that serve the coming chapter's themes, from its own
bestiary, and never feel random: each road's table holds that land's creatures, kept to the party's level by `when`, and the
meetings (narrative/roads/*.dialogue). A fight's foes stand on the table map's foe spots, taken in turn from a different
spot for each entry so fights come from more than one side. Narration comes from the Gemini draft, edited
(docs/plans/gemini_roads/fight_texts.json, keyed by entry id).
    /usr/bin/python3 tools/content/road_tables.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXTS = json.loads((ROOT / "docs/plans/gemini_roads/fight_texts.json").read_text())


def fight(eid, weight, when, monsters):
    """`monsters`: ids, repeated as many times as they come."""
    return {"id": eid, "weight": weight, "when": when, "monsters": monsters}


def meeting(eid, weight, when, dialogue):
    return {"id": eid, "weight": weight, "when": when, "once": True, "dialogue": dialogue}


# Each road's table: id -> (map, grounds, chance by day, by night, summary, roads, entries). The Hollow is in endless night,
# so `chance_night` is the one that counts; `chance_day` is kept equal for a campaign that ever sees a day.
TABLES = {
    "wreck_road": ("road_moor_bonfire", ["road_moor_bonfire", "road_oakwood", "road_creek_ford"], 0.35,
        "The wreck road from the Ghostlight's oak wood to Wickermoor, over moor and through old oaks: the restless dead from the "
        "wreck, the hag's weasels hunting teeth, crooked hares and magpies; and, now and then, a meeting.",
        ["wreck_to_wickermoor"], [
            fight("haints", 3, "level <= 3", ["wayward_haint", "wayward_haint"]),
            fight("haints_many", 3, "level >= 4", ["wayward_haint", "wayward_haint", "wayward_haint", "corrupted_passenger"]),
            fight("weasels", 3, "not flag.vessla_slain and level <= 2", ["giant_weasel"] * 5),
            fight("weasels_led", 3, "not flag.vessla_slain and level >= 3", ["vermin_familiar_weasel"] + ["giant_weasel"] * 4),
            fight("passengers", 2, "level <= 3", ["corrupted_passenger", "corrupted_passenger"]),
            fight("hares", 2, "", ["crooked_hare", "crooked_hare"]),
            fight("magpies", 2, "level >= 2", ["magpie_of_omens", "swarm_of_ravens", "swarm_of_ravens"]),
            fight("wolves", 2, "", ["wolf", "wolf", "wolf"]),
            meeting("lost_passenger", 2, "not flag.road_passenger_met", "roads/act1:lost_passenger"),
            meeting("bone_bonfire", 2, "not flag.road_bonfire_met", "roads/act1:bone_bonfire"),
            meeting("lost_child", 2, "not flag.road_child_met", "roads/act1:lost_child"),
            meeting("wayside_shrine", 2, "not flag.road_shrine_met", "roads/act1:wayside_shrine"),
        ]),
    "hill_road": ("road_oakwood", ["road_oakwood"], 0.25,
        "The hill road from Wickermoor up to the Druskenvald Estate, under oaks: the hag's weasels, hares and magpies, and the "
        "Brightsingers' lantern walk.",
        ["wickermoor_to_estate"], [
            fight("weasels", 3, "not flag.vessla_slain and level <= 2", ["giant_weasel"] * 4),
            fight("weasels_led", 3, "not flag.vessla_slain and level >= 3", ["vermin_familiar_weasel"] + ["giant_weasel"] * 3),
            fight("hares", 2, "", ["crooked_hare", "crooked_hare"]),
            fight("magpies", 2, "level >= 2", ["magpie_of_omens", "swarm_of_ravens"]),
            meeting("lantern_walk", 3, "not flag.road_lanterns_met", "roads/act1:lantern_walk"),
        ]),
    # Act II (any order, levels 4 to 8): each road keeps to its chapter's land and creatures.
    "foxwillow_road": ("road_cornfield_lane", ["road_cornfield_lane", "road_moor_bonfire", "road_oakwood"], 0.4,
        "The Foxwillow road east through farmland: Raum's crows and the things that walk the fields, scarecrows and corn "
        "effigies; refugees from the burning town.",
        ["wickermoor_to_foxwillow"], [
            fight("crows", 3, "level <= 5", ["quasit_crow", "quasit_crow", "swarm_of_ravens", "swarm_of_ravens"]),
            fight("crowstorm", 3, "level >= 6", ["crowstorm", "quasit_crow", "quasit_crow", "swarm_of_ravens"]),
            fight("scarecrows", 3, "level <= 5", ["scarecrow", "scarecrow", "scarecrow", "corn_dolly"]),
            fight("pumpkin_head", 3, "level >= 6", ["pumpkin_head", "scarecrow", "scarecrow", "scarecrow"]),
            fight("effigies", 2, "level <= 6", ["crooked_effigy", "crooked_effigy", "witchwoven"]),
            fight("effigies_many", 2, "level >= 7", ["crooked_effigy", "crooked_effigy", "crooked_effigy", "witchwoven", "witchwoven"]),
            meeting("foxwillow_refugees", 3, "not flag.road_refugees_met and not flag.raum_slain", "roads/act2:foxwillow_refugees"),
        ]),
    "silverbell_road": ("road_foothill_pass", ["road_foothill_pass", "road_creek_ford"], 0.35,
        "The Silverbell river road up into the Howlers' foothills to Dawn's Gate: death dogs and hell hounds, vultures, and the "
        "Crimson Monastery's patrols on the road below it; a pilgrim walking up to be cleansed.",
        ["wickermoor_to_dawns_gate"], [
            fight("death_dogs", 3, "level <= 5", ["death_dog", "death_dog"]),
            fight("hounds", 3, "level >= 6", ["death_dog", "death_dog", "hell_hound"]),
            fight("vultures", 2, "level <= 5", ["giant_vulture", "giant_vulture"]),
            fight("crimson_patrol", 3, "not flag.renathyr_slain and level <= 5", ["crimson_clergy", "cultist", "cultist", "cultist"]),
            fight("crimson_patrol_strong", 3, "not flag.renathyr_slain and level >= 6", ["crimson_clergy", "crimson_clergy", "cultist_fanatic"]),
            meeting("crimson_pilgrim", 3, "not flag.road_pilgrim_met and not flag.renathyr_slain", "roads/act2:crimson_pilgrim"),
        ]),
    "bayou_road": ("road_bayou_causeway", ["road_bayou_causeway", "road_creek_ford"], 0.4,
        "The road south to the Drowned Crossroads and on through the swamp to Murkwater Bend: crocodiles, mud mephits, "
        "snakes, stirges and the ferryman's drowned husks; a dead gambler who wants a game.",
        ["wickermoor_to_crossroads", "crossroads_to_murkwater"], [
            fight("crocodiles", 3, "level <= 5", ["crocodile", "crocodile", "crocodile"]),
            fight("giant_crocodile", 3, "level >= 6", ["giant_crocodile", "crocodile"]),
            fight("mephits", 2, "level <= 5", ["mud_mephit", "mud_mephit", "mud_mephit", "mud_mephit"]),
            fight("deepdreck", 2, "level >= 6", ["deepdreck", "mud_mephit", "mud_mephit"]),
            fight("snakes", 2, "", ["swarm_of_venomous_snakes", "swarm_of_venomous_snakes"]),
            fight("stirges", 2, "level <= 5", ["stirge"] * 6),
            fight("husks", 2, "", ["ferryman_husk"] * 4 + ["mud_mephit"]),
            meeting("dice_ghost", 3, "not flag.road_dice_met and not flag.grinning_sinner_slain", "roads/act2:dice_ghost"),
        ]),
    "skitter_road": ("road_oakwood", ["road_oakwood", "road_foothill_pass"], 0.35,
        "The hill road and trail north-west to Glitterdeep Mine: centipedes everywhere, swarming out of the plague the coven "
        "is spreading; a sick miner on the road.",
        ["wickermoor_to_sk_trail", "sk_trail_to_camp"], [
            fight("centipedes", 4, "level <= 5", ["giant_centipede"] * 5),
            fight("skitterswarm", 4, "level >= 6", ["skitterswarm", "skitterswarm", "vermin_familiar_centipede"]),
            fight("wolves", 2, "level <= 5", ["wolf", "wolf", "wolf", "wolf"]),
            meeting("sick_miner", 3, "not flag.road_miner_met", "roads/act2:sick_miner"),
        ]),
    "marsh_road": ("road_creek_ford", ["road_creek_ford", "road_bayou_causeway", "road_moor_bonfire"], 0.35,
        "The long marsh road west to Moonsong Lake and Memory's Rest: vultures, marsh lights, and the sanatorium's escaped "
        "and changed patients; one who has forgotten his name.",
        ["wickermoor_to_memorys_rest"], [
            fight("vultures", 3, "level <= 5", ["giant_vulture", "giant_vulture", "giant_vulture"]),
            fight("wisps", 3, "level >= 5", ["will_o_wisp", "will_o_wisp"]),
            fight("horrors", 3, "level <= 6", ["hospital_horror", "hospital_horror"]),
            fight("mutated", 3, "level >= 7", ["mutated_patient", "hospital_horror", "hospital_horror"]),
            meeting("escaped_patient", 3, "not flag.road_patient_met and not flag.lethica_slain", "roads/act2:escaped_patient"),
        ]),
    # Act III (a chain: the forest, the cemetery, then the village's own chapters; levels 8 to 11).
    "spore_trail": ("road_oakwood", ["road_oakwood", "road_moor_bonfire"], 0.4,
        "The spore trail north-west into the Hartsblight: rot and the things it wakes, violet fungus, woodwarped and rotweavers.",
        ["wickermoor_to_hartsblight"], [
            fight("fungus", 3, "level <= 8", ["violet_fungus", "violet_fungus", "violet_fungus", "woodwarped"]),
            fight("woodwarped", 3, "level >= 9", ["woodwarped", "woodwarped", "rotweaver"]),
            fight("rotweavers", 3, "", ["rotweaver", "rotweaver", "rotweaver", "violet_fungus"]),
        ]),
    "cemetery_road": ("road_moor_bonfire", ["road_moor_bonfire", "road_creek_ford"], 0.35,
        "The cemetery road south-east to Maidenmist: the hungry dead out of the fog, ghouls and the Shroud's reapers; a "
        "funeral walking the other way.",
        ["wickermoor_to_maidenmist"], [
            fight("ghouls", 3, "", ["ghast", "ghoul", "ghoul", "ghoul"]),
            fight("shrouded", 3, "", ["shrouded_reaper", "shrouded_whisperer", "shrouded_devourer"]),
            fight("wight", 2, "level >= 9", ["wight", "ghast", "ghast", "ghoul"]),
            meeting("funeral", 3, "not flag.road_funeral_met", "roads/act2:funeral"),
        ]),
    "rookery_road": ("road_moor_bonfire", ["road_moor_bonfire", "road_bayou_causeway", "road_foothill_pass", "road_cornfield_lane"], 0.35,
        "The roads out to the walking dovecote's four roosts: the pigeon hag's flocks and the omen-birds that follow them.",
        ["wickermoor_to_rk_roost_prairie", "wickermoor_to_rk_roost_swamp", "wickermoor_to_rk_roost_foothills", "wickermoor_to_rk_roost_lakeshore"], [
            fight("squabs", 4, "not flag.golub_dead", ["vermin_familiar_pigeon", "vermin_familiar_pigeon", "squabswarm", "squabswarm", "squabswarm"]),
            fight("corvodaemon", 3, "", ["corvodaemon", "corvodaemon", "magpie_of_omens", "magpie_of_omens"]),
                    ]),
}


# The Crooked Man between the acts: rolled on any road's leg that its own table left quiet (`every_road`), each meeting
# once, when the story has come to it (narrative/roads/crooked_man.dialogue; his fireside calls are night events).
CROOKED_MAN = {
    "id": "crooked_man_road", "map": "road_moor_bonfire", "every_road": True, "when": "flag.vessla_slain",
    "chance_day": 0.5, "chance_night": 0.5,
    "summary": "The Crooked Man at the edge of the road between the acts: after the Crooked House, after the first of the Fallen, "
               "and his note when only one candle is left.",
    "entries": [
        meeting("after_house", 1, "flag.vessla_slain and not flag.cm_road_house", "roads/crooked_man:after_house"),
        meeting("first_fallen", 1, "(flag.raum_slain or flag.renathyr_slain or flag.grinning_sinner_slain or flag.lethica_slain) "
                "and not flag.cm_road_fallen", "roads/crooked_man:first_fallen"),
        meeting("note", 1, "flag.fallen_farryn_dead and not flag.fallen_yorgrim_dead and not flag.cm_note_read", "roads/crooked_man:note"),
    ],
}


def cells_for(map_id, n, turn):
    spots = json.loads((ROOT / "data/locations" / f"{map_id}.json").read_text())["foe_spots"]
    return [spots[(turn * 3 + i) % len(spots)] for i in range(n)]


def build():
    travel_path = ROOT / "data/travel/wickermoor_hollow.json"
    travel = json.loads(travel_path.read_text())
    by_road = {r["id"]: r for r in travel["roads"]}
    out_dir = ROOT / "data/random_encounters"; out_dir.mkdir(exist_ok=True)
    for tid, (map_id, grounds, chance, summary, roads, entries) in TABLES.items():
        missing = [e["id"] for e in entries if "monsters" in e and f"{tid}:{e['id']}" not in TEXTS]
        if missing:
            print(f"{tid}: no narration yet for {', '.join(missing)}; left out")
            continue
        rows = []
        for turn, e in enumerate(entries):
            e = dict(e)
            if not e["when"]: del e["when"]
            if "monsters" in e:
                e["monsters"] = [{"monster": m, "cell": c} for m, c in zip(e["monsters"], cells_for(map_id, len(e["monsters"]), turn))]
                e["text"] = TEXTS[f"{tid}:{e['id']}"]
            rows.append(e)
        table = {"id": tid, "map": map_id, "grounds": grounds, "chance_day": chance, "chance_night": chance, "summary": summary, "entries": rows}
        (out_dir / f"{tid}.json").write_text(json.dumps(table, indent=2) + "\n")
        for rid in roads:
            by_road[rid]["table"] = tid
    travel_path.write_text(json.dumps(travel, indent=2, ensure_ascii=False) + "\n")
    (out_dir / "crooked_man_road.json").write_text(json.dumps(CROOKED_MAN, indent=2) + "\n")


if __name__ == "__main__":
    build()
