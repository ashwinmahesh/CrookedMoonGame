#!/usr/bin/env python3
"""R26 Moonfall: the eight Old Fears and the shared constants (ids, levels, skills, flags). Used by build_moonfall.py and moonfall_dialogue.py.
The book's numbers (CR, HP, DCs) are the digest's; every word of story is ours."""

REGION = "moonfall"
NS = "moonfall/"
START_NIGHTS = 13

# One entry per Old Fear, in the book's fixed order (the level curve). `level` is the party level the fight expects: the light variant
# (fewer minions) plays below it. DCs rise 17 to 20. Two routes to find it (a, b), a secret weakness, a reward.
FEARS = [
    dict(n=1, key="headsman", file="headsman", short="Galloping Headsman", name="The Galloping Headsman", monster="galloping_headsman", cr=18, hp=220, level=13,
         map="mf_covered_bridge", region="Foxwillow's farmland and the covered bridge", dc=17,
         hook_npc="mf_osric_farmer", clue_npc="mf_mob_captain",
         route_a=[("History", 17), ("Investigation", 17)], route_b=[("Stealth", 17), ("Deception", 17)],
         weak_skills=[("Investigation", 17), ("Athletics", 17)], weak_item="mf_headsman_skull", weak_flag="mf_headsman_weak",
         afflict=("Athletics", 17, "2d8", "bludgeoning", "the sinkholes of the accused"),
         reward="axe_of_the_galloping_headsman", reward_name="Axe of the Galloping Headsman", next_region="Moonsong Lake",
         minions=[("warrior_veteran", 5), ("warhorse_skeleton", 2)], light_minions=[("warrior_veteran", 3)],
         patrol=[("warrior_veteran", 4)], patrol_name="a lynch mob",
         fall_cut="mf_headsman_falls", reveal_cut="mf_headsman_reveals"),
    dict(n=2, key="worm", file="worm", short="White Worm", name="The White Worm", monster="white_worm", cr=19, hp=330, level=14,
         map="mf_moonsong_rift", region="Moonsong Lake and its fishing villages", dc=17,
         hook_npc="mf_pell_fisher", clue_npc="mf_lake_cultist",
         route_a=[("Arcana", 17), ("Investigation", 17)], route_b=[("Deception", 17), ("Persuasion", 17)],
         weak_skills=[("Arcana", 17), ("Nature", 17)], weak_item="mf_star_chart", weak_flag="mf_worm_weak",
         afflict=("Wisdom", 17, "2d10", "psychic", "the lake water that takes memories"),
         reward="eye_of_the_white_worm", reward_name="Eye of the White Worm", next_region="Hartsblight Forest",
         minions=[("wormhost_surgeon", 3), ("chuul", 2)], light_minions=[("wormhost_surgeon", 2), ("chuul", 1)],
         patrol=[("wormhost_surgeon", 3)], patrol_name="Wormhost surgeons",
         fall_cut="mf_worm_falls", reveal_cut="mf_worm_reveals"),
    dict(n=3, key="tall_man", file="tall_man", short="Tall Man", name="The Tall Man", monster="tall_man", cr=20, hp=322, level=15,
         map="mf_tall_man_palace", region="the healed Hartsblight Forest and a logging settlement", dc=18,
         hook_npc="mf_bram_logger", clue_npc="mf_hesper_crone",
         route_a=[("Arcana", 18), ("Persuasion", 18)], route_b=[("Survival", 18), ("Intimidation", 18)],
         weak_skills=[("Performance", 20), ("History", 18)], weak_item="mf_court_notes", weak_flag="mf_tall_man_weak",
         afflict=("Wisdom", 18, "2d10", "psychic", "the hour's wandering dread"),
         reward="hook_of_the_tall_man", reward_name="Hook of the Tall Man", next_region="the Howlers",
         minions=[("lurker_in_the_dark", 4), ("woodwarped", 2)], light_minions=[("lurker_in_the_dark", 3)],
         patrol=[("woodwarped", 3), ("lurker_in_the_dark", 1)], patrol_name="woodwarped wanderers",
         fall_cut="mf_tall_man_falls", reveal_cut="mf_tall_man_reveals"),
    dict(n=4, key="titan", file="titan", short="Wild Titan", name="The Wild Titan", monster="wild_titan", cr=21, hp=350, level=16,
         map="mf_howlers_peaks", region="the Howlers mountains and the mining hamlets", dc=18,
         hook_npc="mf_jory_miner", clue_npc="mf_grizzle_hunter",
         route_a=[("History", 18), ("Nature", 18)], route_b=[("Survival", 18), ("Animal Handling", 18)],
         weak_skills=[("History", 18), ("Athletics", 18)], weak_item="mf_glyph_stone", weak_flag="mf_titan_weak",
         afflict=("Dexterity", 18, "4d8", "bludgeoning", "the falling rock"),
         reward="runestone_of_the_wild_titan", reward_name="Runestone of the Wild Titan", next_region="Maidenmist Cemetery",
         minions=[("alpengrendel", 2), ("ettin", 2)], light_minions=[("alpengrendel", 1), ("ettin", 1)],
         patrol=[("owlbear", 3), ("mammoth", 1)], patrol_name="maddened beasts",
         fall_cut="mf_titan_falls", reveal_cut="mf_titan_reveals"),
    dict(n=5, key="barrow", file="barrow", short="Barrow King", name="The Barrow King", monster="barrow_king", cr=22, hp=414, level=17,
         map="mf_barrow_catacombs", region="Maidenmist Cemetery and a Wickermoor grave", dc=19,
         hook_npc="solomon_roderick", clue_npc="mf_aldous_ghost",
         route_a=[("Arcana", 19), ("History", 19)], route_b=[("Persuasion", 19), ("Religion", 19)],
         weak_skills=[("Investigation", 19), ("Sleight of Hand", 19)], weak_item="mf_inscribed_blade", weak_flag="mf_barrow_weak",
         afflict=("Constitution", 19, "3d10", "necrotic", "the hour's creeping weariness"),
         reward="crown_of_the_barrow_king", reward_name="Crown of the Barrow King", next_region="the Drowned Crossroads",
         minions=[("hunt_knight", 4), ("minotaur_skeleton", 2), ("boneflayer", 1)], light_minions=[("hunt_knight", 3), ("minotaur_skeleton", 1)],
         patrol=[("ogre_zombie", 3), ("boneflayer", 1)], patrol_name="risen dead",
         fall_cut="mf_barrow_falls", reveal_cut="mf_barrow_reveals"),
    dict(n=6, key="leviathan", file="leviathan", short="Jinxed Leviathan", name="The Jinxed Leviathan", monster="jinxed_leviathan", cr=23, hp=437, level=18,
         map="mf_jinxed_bayou", region="the Drowned Crossroads and Murkwater Bend", dc=19,
         hook_npc="mf_nadine_bayou", clue_npc="mf_jack_follower",
         route_a=[("Animal Handling", 19), ("Survival", 19)], route_b=[("Intimidation", 19), ("Persuasion", 19)],
         weak_skills=[("Religion", 19), ("Persuasion", 19)], weak_item="mf_blessed_idol", weak_flag="mf_leviathan_weak",
         afflict=("Wisdom", 19, "3d10", "psychic", "the confusing swamplights"),
         reward="tooth_of_the_jinxed_leviathan", reward_name="Tooth of the Jinxed Leviathan", next_region="the Webwoods",
         minions=[("bayou_beast", 3), ("giant_crocodile", 2), ("hydra", 1)], light_minions=[("bayou_beast", 2), ("giant_crocodile", 1)],
         patrol=[("bayou_beast", 3), ("giant_crocodile", 1)], patrol_name="bayou beasts",
         fall_cut="mf_leviathan_falls", reveal_cut="mf_leviathan_reveals"),
    dict(n=7, key="dusk", file="dusk", short="Dusk Mother", name="The Dusk Mother", monster="dusk_mother", cr=24, hp=315, level=19,
         map="mf_dusk_mother_hut", region="the Webwoods and a farm homestead", dc=20,
         hook_npc="mf_ysolde_teen", clue_npc="mf_pennywhistle_nurse",
         route_a=[("Arcana", 20), ("History", 20)], route_b=[("Animal Handling", 20), ("Survival", 20)],
         weak_skills=[("Insight", 20), ("Investigation", 20)], weak_item="mf_children_toys", weak_flag="mf_dusk_weak",
         afflict=("Dexterity", 20, "4d10", "poison", "the webs of the Webwoods"),
         reward="bell_of_the_dusk_mother", reward_name="Bell of the Dusk Mother", next_region="Rowan's Rise",
         minions=[("weeping_widow", 2), ("skitterswarm", 3), ("necrolisk", 1)], light_minions=[("weeping_widow", 1), ("skitterswarm", 3)],
         patrol=[("skitterswarm", 4), ("weeping_widow", 1)], patrol_name="web-spinners",
         fall_cut="mf_dusk_falls", reveal_cut="mf_dusk_reveals"),
    dict(n=8, key="behemoth", file="behemoth", short="Brimstone Behemoth", name="The Brimstone Behemoth", monster="brimstone_behemoth", cr=25, hp=468, level=20,
         map="mf_rowans_volcano", region="Rowan's Rise, now a volcano, and the moors as a hellscape", dc=20,
         hook_npc="mf_ash_cultist", clue_npc="mf_rowan_spirit",
         route_a=[("Persuasion", 20), ("Intimidation", 20)], route_b=[("Arcana", 20), ("History", 20)],
         weak_skills=[("Persuasion", 20), ("Insight", 20)], weak_item="mf_rowan_locket", weak_flag="mf_behemoth_weak",
         afflict=("Dexterity", 20, "4d10", "fire", "the burning boulders and the meteors"),
         reward="hide_of_the_brimstone_behemoth", reward_name="Hide of the Brimstone Behemoth", next_region="the heroes themselves",
         minions=[("hell_hound", 4), ("incubus", 1), ("wyvern", 1)], light_minions=[("hell_hound", 3), ("wyvern", 1)],
         patrol=[("hell_hound", 3), ("wyvern", 1)], patrol_name="hellhounds",
         fall_cut="mf_behemoth_falls", reveal_cut="mf_behemoth_reveals"),
]
BY_KEY = {f["key"]: f for f in FEARS}


def fq(f):
    return "mf_" + f["key"]


def fl(f, what):
    """The flag `mf_<key>_<what>`."""
    return f"mf_{f['key']}_{what}"


def fear_flag(f):
    return "old_fear_" + f["key"]
