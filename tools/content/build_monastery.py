#!/usr/bin/env python3
"""ONE-SHOT (R14, The Crimson Monastery). Writes Dawn's Gate (the town sits on tools/content/monastery_sketch.py's ground: run that and `make sketch`
for dawns_gate and mon_pass first), the Briar Public House, the pass, the monastery's rooms, its people, quests, items, monsters, travel place, cutscenes and
Wickermoor's hooks. Flags are collected from the dialogue and the maps. Other lanes edit these files afterwards: DO NOT re-run it over them.
    python3 tools/content/build_monastery.py"""
import copy, json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import monastery_maps as mm

ROOT = Path(__file__).resolve().parents[2]
M = "monastery/"


def write(rel, obj):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


def read(rel):
    return json.loads((ROOT / rel).read_text())


# ---- locations ---------------------------------------------------------------------------------------------------------------------
def build_locations():
    gate = mm.town(read("data/locations/dawns_gate.json"))
    write("data/locations/dawns_gate.json", gate)
    write("data/locations/mon_pass.json", mm.pass_(read("data/locations/mon_pass.json")))
    for f in (mm.briar, mm.briar_upper, mm.briar_cellar, mm.stables, mm.ground, mm.upper, mm.bell_tower, mm.belfry, mm.holy_vein, mm.sanctum, mm.cathedral_moon):
        loc = f()
        write(f"data/locations/{loc['id']}.json", loc)


# ---- people ------------------------------------------------------------------------------------------------------------------------
CF = "faction_crimson_faith"
PEOPLE = [   # id, name, title, summary, attitude, region, tags
    ("kristoff_gruber", "Kristoff Gruber", "Owner of the Briar Public House", "A gruff innkeeper with a sour crust and soft kindnesses, who keeps his people safe by keeping his mouth shut.", "friendly", "dawns_gate", ["faction_none", "voice_backwoods"]),
    ("gareth_creed", "Gareth Creed", "A Brightsinger pilgrim", "A tall, dark-haired, short-bearded, grey-eyed pilgrim, frightened and stubborn.", "friendly", "dawns_gate", ["faction_brightsingers", "voice_hollow"]),
    ("melina", "Melina", "Gareth's companion", "A Brightsinger pilgrim who fled to Wickermoor and waits there for news of her friend.", "friendly", "wickermoor", ["faction_brightsingers", "voice_hollow"]),
    ("axel_farley", "Axel Farley", "A lapsed faithful, in chains", "A hoarse man who saw the sanctum and shakes when it comes up.", "friendly", "crimson_monastery", ["faction_none", "voice_backwoods"]),
    ("father_renathyr", "Father Marius Renathyr", "The Crimson Abbot", "A warm, measured preacher with a knight's formality, who mutters to his sword.", "friendly", "crimson_monastery", [CF, "voice_druskenvald"]),
    ("viraxys", "Viraxys", "The Crimson Rose", "A voice in the windows: sultry, amused, never loud.", "hostile", "crimson_monastery", ["faction_none", "voice_druskenvald"]),
    ("sigmund_jaeger", "Houndmaster Sigmund Jaeger", "Prior of the hounds", "A plain-spoken huntsman, cultishly friendly while the party shows interest.", "friendly", "crimson_monastery", [CF, "voice_backwoods"]),
    ("friar_olaf", "Friar Olaf of the Silver Bells", "Prior and preacher", "An unctuous prior whose sermons are mostly about himself.", "friendly", "crimson_monastery", [CF, "voice_newcomer"]),
    ("leona_cromwell", "Inquisitor Leona Cromwell", "Prioress of the Sanguine Hunt", "Clipped, contemptuous, suspicious of strong people who resist the faith.", "indifferent", "crimson_monastery", [CF, "voice_newcomer"]),
    ("landers_knight", "Landers", "A Hunt knight", "A knight celebrating the night's catch, unarmoured.", "friendly", "crimson_monastery", [CF, "voice_backwoods"]),
    ("marla_knight", "Marla", "A Hunt knight", "A knight celebrating the night's catch, unarmoured.", "friendly", "crimson_monastery", [CF, "voice_hollow"]),
    ("fremont_knight", "Fremont", "A Hunt knight", "A knight celebrating the night's catch, unarmoured.", "friendly", "crimson_monastery", [CF, "voice_backwoods"]),
    ("stable_hand_cm", "A stable hand", "Hand at the Hunt's stables", "A nervous young hand who sees more than he says.", "friendly", "crimson_monastery", [CF, "voice_hollow"]),
    ("gate_veteran_cm", "A gate veteran", "Warrior at the monastery gate", "A grey veteran of the walls who greets visitors like a shepherd counting sheep.", "friendly", "crimson_monastery", [CF, "voice_backwoods"]),
    ("faithful_novice", "A novice of the Rose", "A faithful of the monastery", "A friendly novice who recites the teachings a little too fast.", "friendly", "crimson_monastery", [CF, "voice_hollow"]),
    ("faithful_cook", "Sister Edda", "The monastery's cook", "A broad woman who renders fat for candles and does not look at the larder door.", "friendly", "crimson_monastery", [CF, "voice_hollow"]),
    ("faithful_scribe", "Brother Cael", "A scribe in the scriptorium", "A thin scribe copying the same verse for the ninth hour.", "friendly", "crimson_monastery", [CF, "voice_newcomer"]),
    ("dg_toma_flint", "Toma Flint", "A miner of Dawn's Gate", "A silver miner who talks to the ore more than to people.", "indifferent", "dawns_gate", ["faction_none", "voice_backwoods"]),
    ("dg_halka_wren", "Halka Wren", "A widow of Dawn's Gate", "A widow whose son rode with the Hunt and did not come back the same.", "indifferent", "dawns_gate", ["faction_none", "voice_hollow"]),
    ("dagny_voll", "Dagny Voll", "A bat-hound trainer", "A leathery trainer who speaks to dogs in their own language and gets their answers.", "friendly", "dawns_gate", [CF, "voice_backwoods"]),
    ("ser_maric_dunmore", "Ser Maric Dunmore", "A Hunt knight", "An overconfident knight who is terrified of horses and explains that it is a tactical position.", "friendly", "dawns_gate", [CF, "voice_newcomer"]),
    ("pilgrim_quill", "Pilgrim Quill", "A pilgrim and poet", "A second bad poet in the family, cousin to Ambrose Quill, and exactly as certain of his genius.", "friendly", "dawns_gate", ["faction_none", "voice_newcomer"]),
    ("brother_quiet", "Brother Quiet", "A friar under a vow of silence", "A monk with a slate and a chalk who must tell someone something and cannot find the one he must tell.", "friendly", "dawns_gate", ["faction_none", "voice_hollow"]),
    ("orrin_tolle", "Orrin Tolle", "The village bellman", "An old bellman who rings the hand-bell at the Twilight and Evening hours and remembers who cast the silver one.", "friendly", "dawns_gate", ["faction_none", "voice_backwoods"]),
    ("dg_wren_child", "Wren", "A child of Dawn's Gate", "A small girl who kneels at the bells and counts them.", "friendly", "dawns_gate", ["faction_none", "voice_hollow"]),
    ("dg_refugee_ilse", "Ilse Marrow", "A refugee from the Hunt", "A tinker's wife hiding in a cellar with her brother.", "friendly", "dawns_gate", ["faction_none", "voice_backwoods"]),
    ("dg_refugee_otto", "Otto Marrow", "A refugee from the Hunt", "Ilse's brother, who says very little and keeps a knife in his boot.", "friendly", "dawns_gate", ["faction_none", "voice_backwoods"]),
]


def build_people():
    for (nid, name, title, summary, att, region, tags) in PEOPLE:
        write(f"data/npcs/{nid}.json", {"id": nid, "name": name, "title": title, "summary": summary, "attitude": att, "sprite": "villager", "region": region, "tags": tags})


# ---- quests ------------------------------------------------------------------------------------------------------------------------
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
    {"id": "crimson_monastery", "name": "The Crimson Monastery", "kind": "main", "region": "dawns_gate", "giver": "weston_murdoch",
     "summary": "Two Brightsinger pilgrims went to Silverbell Monastery to see its bell and did not come back. A devil calling herself the Crimson Rose rules the place.",
     "stages": [
         st("heard", "Weston Murdoch says his pilgrims Gareth Creed and Melina went to see Silverbell Monastery's bell above Dawn's Gate. A stable hand took Gareth aside to tell him a secret, and Gareth never came back. Melina fled to Wickermoor.", "Take the river road west to Dawn's Gate and look for Gareth.", ["Reach Dawn's Gate"]),
         st("dawns_gate", "Dawn's Gate is afraid. Red banners with a golden rose are nailed on every door, and the whole village kneels to the bells.", "Learn what the village will say, and climb the hill to the monastery.", ["Talk to the village", "Climb the pass"]),
         st("night_of_flames", "The first night at the monastery is a Night of Flames: six captives at six stakes, Olaf with a torch, and Gareth Creed among them.", "Save Gareth Creed, or watch.", ["Reach the pyre", "Save Gareth"]),
         st("inside", "The faithful have taken us for converts. Every infraction is counted, and they watch us the whole time.", "Find the way to the sanctum under the altar. Do not trespass and do not be caught freeing anyone.", ["Learn the way down"]),
         st("the_way_down", "The sanctum is under the altar of the Sanguine Cathedral, and the altar opens for a chalice of blood.", "Fill the chalice and open the altar.", ["Open the altar"]),
         st("holy_vein", "The altar slid forward and a shaft opened under it. Below, a tunnel full of blood leads to a stone door.", "Pass the blood elemental and the door.", ["Pass the blood elemental", "Open the sanctum door"]),
         st("bloody_tears", "In the Bloody Sanctum Father Renathyr, the Crimson Abbot, waits at the altar of a goddess who is a devil.", "End Renathyr, or end him by his own memory.", ["Defeat the Crimson Abbot"]),
         st("aftermath", "Renathyr is dead. The windows became a devil's face and Viraxys made her offer. The faithful stand in the courtyard and wait to be told what they are.", "Decide what the cult becomes.", ["Decide the cult's fate"]),
         st("return", "Dawn's Gate is quiet and the moon is white again. Wickermoor waits for news of Gareth.", "Return to Wickermoor and Weston Murdoch.", ["Return to Wickermoor"]),
         st("done", "Wickermoor heard the news, and Phillip Druskenvald sent a card.", ends="success"),
     ]},
    {"id": "free_the_captives", "name": "Free the Captives", "kind": "side", "region": "crimson_monastery", "giver": "axel_farley",
     "summary": "Four captives are shackled in the Dead Larder, each with Exhaustion, waiting for the next pyre.",
     "stages": [
         st("asked", "Axel Farley and three others hang shackled in the freezing larder. Taking a captive out of the grounds without leave counts against us if the faithful see.", "Free them without being seen, or lead them out the gate.", ["Free the captives", "Lead them out"]),
         st("freed", "Axel and the others are free and on the road to Dawn's Gate.", ends="success"),
         st("seen", "We led the captives out in plain sight, and the faithful noticed.", ends="failure"),
     ]},
    {"id": "sanguine_hunt", "name": "The Sanguine Hunt", "kind": "side", "region": "dawns_gate", "giver": "dg_halka_wren",
     "summary": "The Hunt rides down to Dawn's Gate at Twilight after a Night of Flames to bring in anyone the cult calls impure.",
     "stages": [
         st("known", "Halka Wren says the Hunt rides down into the square at the Twilight bell the night after a Night of Flames. Everyone in the village is on the party's side.", "Meet the riders in the square.", ["Ambush the Hunt"]),
         st("ambushed", "The Hunt is broken in the square, and the village cheers in whispers.", ends="success"),
         st("rode_out", "The Hunt rode down and bought a villager's life, and no one stopped it.", ends="failure"),
     ]},
    {"id": "the_priors", "name": "The Three Priors", "kind": "side", "region": "crimson_monastery", "giver": "father_renathyr",
     "summary": "Houndmaster Jaeger, Friar Olaf and Inquisitor Cromwell run the cult for Renathyr. When he falls, whoever lives takes the faith.",
     "stages": [
         st("known", "Three priors serve the Abbot: a houndmaster, a friar and an inquisitor. Each rises again in the shape of a Night Creature when struck down.", "Meet each prior, and decide who lives.", ["Meet or end the priors"]),
         st("settled", "The priors are settled, one way or another.", ends="success"),
     ]},
    {"id": "silver_bells_name", "name": "The Silver Bell's Name", "kind": "side", "region": "dawns_gate", "giver": "orrin_tolle",
     "summary": "The great silver bell bears Olaf's name, but Orrin remembers who cast it, and Olaf is afraid of it.",
     "stages": [
         st("asked", "Orrin Tolle says the silver bell was cast in Dawn's Gate by miners and bore another name before it hung in the belfry. Olaf had it recut.", "Read the bell's inscription in the belfry, and ask Olaf.", ["Read the inscription", "Learn why Olaf fears it"]),
         st("restored", "The bell's true name is known in the village again.", ends="success"),
         st("left", "We let the name lie, and Orrin rang the old hand-bell alone.", ends="failure"),
     ]},
    {"id": "kristoffs_cellar", "name": "Kristoff's Cellar", "kind": "side", "region": "dawns_gate", "giver": "kristoff_gruber",
     "summary": "Kristoff hides refugees from the Hunt in his cellar behind a false wall.",
     "stages": [
         st("asked", "Kristoff Gruber hides two refugees in his cellar and wants to know whether we can be trusted with them.", "Look at the false wall in the cellar.", ["Decide the refugees' fate"]),
         st("kept", "The refugees are still hidden, and Kristoff trusts us.", ends="success"),
         st("betrayed", "We handed the refugees to the Hunt for a purse.", ends="failure"),
     ]},
    {"id": "pilgrims_bad_poetry", "name": "A Pilgrim's Bad Poetry", "kind": "side", "region": "dawns_gate", "giver": "pilgrim_quill",
     "summary": "Pilgrim Quill has an ode to the Crimson Abbot, and means to recite it at the next Night of Flames.",
     "stages": [
         st("asked", "Pilgrim Quill has composed an ode to Father Renathyr and wants a rhyme for monastery.", "Help Quill with the ode before the next Night of Flames.", ["Fix the ode"]),
         st("done", "Quill's ode is as good as it will get.", ends="success"),
         st("burned", "Quill read his ode as it was, and the monastery did not clap.", ends="failure"),
     ]},
    {"id": "friar_quiet", "name": "Friar Quiet", "kind": "side", "region": "dawns_gate", "giver": "brother_quiet",
     "summary": "A friar under a vow of silence must tell the right person one thing, and does not know who or where.",
     "stages": [
         st("asked", "Brother Quiet wrote on his slate that he must tell a Brightsinger woman something about Gareth Creed.", "Find Melina in Wickermoor.", ["Carry Quiet's message to Melina"]),
         st("done", "Melina knew the message and thanked Quiet's chalk.", ends="success"),
         st("lost", "We gave Quiet's message up, and the chalk was left in the dust.", ends="failure"),
     ]},
    {"id": "axels_debts", "name": "Axel's Debts", "kind": "side", "region": "dawns_gate", "giver": "axel_farley",
     "summary": "Axel Farley owes three people in Dawn's Gate a small kindness each.",
     "stages": [
         st("asked", "Axel owes Toma Flint a hat, Dagny Voll a leash and Halka Wren a letter.", "Deliver the three small kindnesses.", ["Toma's hat", "Dagny's leash", "Halka's letter"]),
         st("done", "Axel's debts are paid.", ends="success"),
         st("forgotten", "We let Axel's debts lie, and three people in Dawn's Gate remembered.", ends="failure"),
     ]},
]


def build_quests():
    for q in QUESTS:
        write(f"data/quests/{q['id']}.json", q)


# ---- items -------------------------------------------------------------------------------------------------------------------------
ITEMS = [
    ("skeleton_key", "A skeleton key", "quest", "A prior's key, good for the cells, the larder, the priors' chambers and the Bell Tower Gate."),
    ("bloody_treats", "Bloody treats", "quest", "A sack of bloody scraps that makes bat hounds fight over it. Throw it up to 30 feet."),
    ("jaegers_workbook", "Jaeger's workbook", "quest", "Notes on blood magic for bat hounds, enchanting weapons and moving vitality between people, and when Renathyr keeps his Witching Hour."),
    ("olafs_missal", "Olaf's missal", "quest", "Olaf's prayer book: the chalice ritual, and where the priors were anointed."),
    ("rosen_testament", "The Rosen Testament", "quest", "A heavy reference on the faith and on vampires. Worth 250 gp to a collector."),
    ("renathyr_journal", "Renathyr's journal", "quest", "His story as he lived it, until the page where he knew he was tricked. Proof for the reveal."),
    ("lethica_painting", "Painting of Lethica Nightborne", "quest", "An elven woman in oils. A Wickermoor collector would pay 500 gp. Renathyr's wife, and a memento."),
    ("dried_roses", "Dried roses of the sanctum", "quest", "They crumble at a touch (Immune to Poisoned for a day), and they are kindling for the Crimson Beacon rites."),
    ("jewel_box_cromwell", "Cromwell's jewel box", "treasure", "300 gp of diamonds and 200 gp of rubies, taken from Cromwell's victims."),
    ("calligraphers_set", "A set of calligrapher's tools", "treasure", "Fifty gold pieces of pens, inks and a ruler."),
    ("melinas_songbird", "Melina's wooden songbird", "quest", "A small wooden songbird Melina carved. Gareth will know it."),
    ("salt_pouch", "A pouch of salt", "quest", "Wipe it on a weapon as a Bonus Action and the weapon bites a Night Creature."),
    ("dagnys_whistle", "Dagny's whistle", "quest", "A bone whistle that tells bat hounds that the person blowing it is the pack."),
    ("quill_ode", "Quill's ode", "quest", "A bad ode to Father Renathyr. It has been improved or it has not."),
    ("toma_hat", "Toma's second-best hat", "quest", "A knitted hat Axel never returned."),
    ("dagny_leash", "Dagny's long leash", "quest", "A braided leash Axel borrowed."),
    ("halka_letter", "A letter for Halka", "quest", "Axel never delivered it."),
    ("quiet_slate", "Brother Quiet's slate", "quest", "A chalk slate with a short message, wiped and rewritten."),
]


def build_items():
    for (iid, name, cat, summary) in ITEMS:
        write(f"data/items/{iid}.json", {"id": iid, "name": name, "source": {"book": "CrookedMoon"}, "category": cat, "weight_lb": 1, "cost_gp": 0, "summary": summary})
    scythe = read("data/magic_items/scythe_of_the_harvest_terror.json")
    sword = copy.deepcopy(scythe)
    sword.update({"id": "sword_of_the_crimson_abbot", "name": "Sword of the Crimson Abbot", "icon": "longsword", "weight_lb": 3,
                  "summary": "A Fabled Heirloom longsword that grows with its bearer (+1, +2 at level 7, +3 at 13): 1d6 extra Necrotic. From level 7, Vampiric Charm once a dusk. It was Duchess, and it has no mind of its own.",
                  "weapon": {"kind": "martial_melee", "damage": "1d8", "damage_type": "slashing", "properties": ["versatile"], "versatile": "1d10", "mastery": "sap"}})
    sword["weapon_rules"] = {"extra": [{"dice": "1d6", "type": "necrotic"}]}
    sword["powers"] = [{"id": "charm", "name": "Vampiric Charm", "spell": "charm_person", "min_level": 7, "uses": {"count": 1, "per": "dusk"}}]
    write("data/magic_items/sword_of_the_crimson_abbot.json", sword)
    shield = copy.deepcopy(scythe)
    shield.update({"id": "shield_of_marius_renathyr", "name": "Shield of Marius Renathyr", "category": "shield", "icon": "shield", "weight_lb": 6,
                   "armor": {"kind": "shield", "base_ac": 2, "stealth_disadvantage": False, "don_minutes": 0, "doff_minutes": 0},
                   "summary": "A Fabled Heirloom shield of a golden knight (+1, +2 at level 7, +3 at 13 to Armor Class). Valorous Guard: its bearer's Reaction adds to an adjacent ally's AC against a hit (the power waits on the engine's heirloom rules)."})
    for k in ("weapon", "weapon_rules", "powers"):
        shield.pop(k, None)
    shield["modifiers"] = [{"stat": "ac", "value": "tier", "when": {"item": "@self"}}]
    write("data/magic_items/shield_of_marius_renathyr.json", shield)


# ---- monsters ----------------------------------------------------------------------------------------------------------------------
def human_block(src, mid, name, hp, dice, ac, cr, xp, sword_bonus, sword_dmg, sword_avg, art, summary, ai="brute"):
    m = copy.deepcopy(src)
    m.update({"id": mid, "name": name, "hp": {"average": hp, "dice": dice}, "ac": ac, "cr": cr, "xp": xp, "art": art, "ai_profile": ai, "summary": summary})
    m["actions"] = [{"id": "blade", "name": "Blade", "kind": "melee", "attack": {"bonus": sword_bonus, "reach": 5}, "damage": [{"average": sword_avg, "dice": sword_dmg, "type": "slashing"}],
                     "summary": f"+{sword_bonus}, reach 5 ft, {sword_dmg} Slashing."},
                    {"id": "human_multiattack", "name": "Multiattack", "kind": "multiattack", "multiattack": [{"action": "blade", "count": 2}], "summary": "Two Blade attacks."}]
    m["bonus_actions"] = []
    m.pop("spellcasting", None)
    return m


def prior(src, nc, mid, name, hp, dice, ac, cr, xp, art, summary, boss=False):
    m = human_block(src, mid, name, hp, dice, ac, cr, xp, 5, "1d8+3", 7, art, summary)
    m["phases"] = [{"id": "true_form", "name": "Night Creature", "when": {"at_zero": True}, "hp": 75, "ac": 15,
                    "summary": "The man falls, and rises at full strength in the shape of a Night Creature, Large and clawed.", "art": "night_creature",
                    "actions_remove": ["blade", "human_multiattack"], "actions_add": copy.deepcopy(nc["actions"]), "traits_add": copy.deepcopy(nc["traits"]), "end_conditions": True,
                    "flag": "prior_second_form_seen"}]
    return m


def build_monsters():
    fan = read("data/monsters/cultist_fanatic.json")
    nc = read("data/monsters/night_creature.json")
    write("data/monsters/hunt_knight.json", human_block(fan, "hunt_knight", "Hunt Knight", 52, "8d8+16", 18, 3, 700, 5, "1d8+3", 7, "knight", "A knight of the Sanguine Hunt in plate: two swings of a longsword."))
    write("data/monsters/hunt_knight_bare.json", human_block(fan, "hunt_knight_bare", "Hunt Knight (unarmoured)", 52, "8d8+16", 10, 3, 700, 5, "1d8+3", 7, "knight", "A Hunt knight at a celebration, without armour: AC 10."))
    write("data/monsters/warrior_veteran.json", human_block(fan, "warrior_veteran", "Warrior Veteran", 58, "9d8+18", 17, 3, 700, 5, "1d8+3", 7, "warrior_veteran", "A grey wall-warden of the monastery with a longsword."))
    write("data/monsters/prior_jaeger.json", prior(fan, nc, "prior_jaeger", "Houndmaster Jaeger", 65, "10d8+20", 15, 2, 450, "bandit_captain", "A houndmaster in leathers. Struck down, he rises as a Night Creature at full strength."))
    write("data/monsters/prior_olaf.json", prior(fan, nc, "prior_olaf", "Friar Olaf", 38, "7d8+7", 13, 2, 450, "priest", "A friar who preaches and smiles. Struck down, he rises as a Night Creature at full strength."))
    write("data/monsters/prior_cromwell.json", prior(fan, nc, "prior_cromwell", "Inquisitor Cromwell", 52, "8d8+16", 18, 3, 700, "knight", "A clipped inquisitor in plate. Struck down, she rises as a Night Creature at full strength."))
    bats = read("data/monsters/squabswarm.json")
    bats.update({"id": "swarm_of_bats", "name": "Swarm of Bats", "type": "beast", "art": "swarm_of_bats", "hp": {"average": 11, "dice": "5d8"}, "ac": 12,
                 "summary": "A swarm of bats dropped from the belfry rafters."})
    bats["actions"] = [{"id": "bite", "name": "Bite", "kind": "melee", "attack": {"bonus": 4, "reach": 5}, "damage": [{"average": 5, "dice": "2d4", "type": "piercing"}], "summary": "+4, 2d4 Piercing."}]
    write("data/monsters/swarm_of_bats.json", bats)
    eff = read("data/monsters/crimson_clergy.json")
    eff.update({"id": "blood_effigy", "name": "Blood Effigy", "art": "blood_effigy", "hp": {"average": 10, "dice": "3d6"}, "cr": 0.5, "xp": 100, "minion_of": "crimson_abbot_boss",
                "minions": {"when_it_falls": "vanish", "narration": "The effigy slumps into a puddle."},
                "summary": "A clergy shape of blood, rising beside the Abbot under the red moon. Ten Hit Points."})
    write("data/monsters/blood_effigy.json", eff)
    be = read("data/monsters/mud_mephit.json")
    be.update({"id": "blood_elemental", "name": "Blood Elemental", "size": "large", "type": "elemental", "ac": 14, "hp": {"average": 114, "dice": "12d10+48"}, "cr": 5, "xp": 1800, "art": "blood_elemental",
               "summary": "A water elemental made of the sanctum's blood: two slams of Necrotic. Holy water destroys it at once."})
    be["actions"] = [{"id": "slam", "name": "Slam", "kind": "melee", "attack": {"bonus": 7, "reach": 5}, "damage": [{"average": 13, "dice": "2d8+4", "type": "necrotic"}], "summary": "+7, 2d8+4 Necrotic."},
                     {"id": "blood_multiattack", "name": "Multiattack", "kind": "multiattack", "multiattack": [{"action": "slam", "count": 2}], "summary": "Two Slams."}]
    be["traits"] = [{"id": "holy_water", "name": "Holy Water Destroys It", "action": "passive", "summary": "A flask of holy water thrown at it destroys it at once.",
                     "text": "A flask of holy water thrown at the elemental destroys it. (The engine does not do this yet: see the package doc.)", "implemented": "text"}]
    be["bonus_actions"] = []
    be.pop("spellcasting", None)
    write("data/monsters/blood_elemental.json", be)
    ab = read("data/monsters/crimson_abbot.json")
    ab.update({"id": "crimson_abbot_boss", "name": "The Crimson Abbot",
               "summary": "A fallen crusader turned vampire, in two phases: half-transformed at the altar, then a bat-like horror under the blood moon with effigies of blood beside him."})
    ab["phases"] = [{"id": "beneath_a_blood_moon", "name": "Beneath a Blood Moon", "when": {"bloodied": True}, "legendary_refill": True, "end_conditions": True, "lair": True,
                     "summary": "Viraxys laughs and a blood geyser throws everyone up into the cathedral: Renathyr's true form, three blood effigies, and Viraxys's lair actions.",
                     "summon": {"monster": "blood_effigy", "count": 3}, "cutscene": "mon_moon", "flag": "renathyr_phase2", "art": "vampire"}]
    ab["lair_actions"] = [
        {"id": "blood_torrent", "name": "Blood Torrent", "kind": "save", "save": {"ability": "dex", "dc": 15, "success": "none"}, "targets": {"range": 30, "count": 3},
         "on_fail": [{"do": "condition", "condition": "prone"}],
         "summary": "Up to three creatures within 30 ft: a DC 15 Dex save or knocked prone by a torrent of blood.",
         "text": "On Viraxys's count the blood in the room surges: up to three creatures within 30 feet of the pool make a DC 15 Dexterity saving throw or are thrown down."},
        {"id": "endless_minions", "name": "Endless Minions", "kind": "summon", "summon": {"monster": "blood_effigy", "count": 1, "max": 3}, "summary": "If fewer than three effigies stand, another rises.",
         "text": "Viraxys wills another effigy up out of the blood, so long as fewer than three stand."},
        {"id": "viraxys_laughs", "name": "Viraxys Laughs", "kind": "text", "summary": "A sultry, amused voice from the windows mocks the party.", "text": "She never raises her voice."}]
    write("data/monsters/crimson_abbot_boss.json", ab)


# ---- travel and hooks --------------------------------------------------------------------------------------------------------------
def build_travel():
    path = ROOT / "data/travel/wickermoor_hollow.json"
    t = json.loads(path.read_text())
    t["places"] = [x for x in t["places"] if x["id"] != "dawns_gate"] + [
        {"id": "dawns_gate", "name": "Dawn's Gate", "location": "dawns_gate", "spawn": "from_road", "pos": [0.12, 0.56], "region": "dawns_gate",
         "when": "flag.vessla_slain or visited:dawns_gate", "summary": "A dour mining village in the Howlers' foothills, below the Crimson Monastery."}]
    t["roads"] = [x for x in t["roads"] if x["id"] != "wickermoor_to_dawns_gate"] + [
        {"id": "wickermoor_to_dawns_gate", "from": "wickermoor_village", "to": "dawns_gate", "hours": 14, "name": "The Silverbell river road",
         "when": "flag.vessla_slain or visited:dawns_gate"}]
    path.write_text(json.dumps(t, indent=2, ensure_ascii=False) + "\n")


def build_village_hooks():
    """Wickermoor's side: Weston's hook and return, Melina who waits, the pilgrims' messages. Idempotent edits of the village's NPC entries."""
    path = ROOT / "data/locations/wickermoor_village.json"
    town = json.loads(path.read_text())
    town["npcs"] = [n for n in town["npcs"] if not str(n.get("dialogue", "")).startswith(M)]
    plain = next(n for n in town["npcs"] if n["npc"] == "weston_murdoch" and n.get("dialogue") == "wickermoor/weston_murdoch:start")
    i = town["npcs"].index(plain)
    town["npcs"][i:i] = [
        mm.npc("weston_murdoch", plain["cell"], "hook:weston_return", when="flag.crimson_farewell and not flag.mon_returned"),
        mm.npc("weston_murdoch", plain["cell"], "hook:weston_pilgrim", when="flag.vessla_slain and not flag.gareth_asked")]
    town["npcs"] += [
        mm.npc("melina", [4, 32], "hook:melina_reunion", when="flag.crimson_farewell and not flag.mon_returned"),
        mm.npc("melina", [4, 32], "quiet:melina_message", when="flag.quiet_asked and not flag.quiet_done and flag.gareth_asked"),
        mm.npc("melina", [4, 32], "hook:melina_wait", when="flag.gareth_asked and not flag.crimson_farewell")]
    path.write_text(json.dumps(town, indent=2, ensure_ascii=False) + "\n")


# ---- cutscenes ---------------------------------------------------------------------------------------------------------------------
SETS = {
    "mon_monastery": ["The monastery on its peak from the pass: spiked walls and a bell tower black against the sky, red light spilling down the mountain",
                      "Thousands of bats pouring from a belfry over a mining village's copper lights"],
    "mon_flames": ["A high shot from a tower: six stakes in a ring of torches and red robes in a courtyard at night",
                   "A friar's torch touching a pyre, sparks rising past red stained-glass windows",
                   "Flames and one tall silhouette, a crowd's bowed heads, a faint sulfur haze"],
    "mon_knights_tale": ["A golden knight with a red lion banner saving a priestess on a night road",
                         "A knight dying among bandits while a rose-red shadow leans over him",
                         "A vampire in half plate turning away from a sleeping wife"],
    "mon_way_down": ["A golden chalice filled and glowing red, a stone altar sliding forward in a candlelit cathedral",
                     "Looking down a shaft into black liquid"],
    "mon_phase1": ["A tall abbot's image shimmering as he grows, red light on a vaulted stone chamber",
                   "Great wings unfolding against a chandelier"],
    "mon_moon": ["A blood geyser erupting through a stone chamber floor",
                 "A cathedral from below: statues weeping blood and a bat-like monster against a red moon in the dome"],
    "mon_hellfire": ["A sword spinning into a stone altar",
                     "Candles flaring to hellfire in a cathedral",
                     "Stained glass remade as a leering devil's face over a blood-wet nave"],
    "mon_refusal": ["Hellfire snuffed to smoke over an altar", "Red stained-glass windows shattering outward over a dark valley"],
    "mon_acceptance": ["A hand with no face closing on a sword's hilt", "A bat and red mist streaming out through a shattered dome"],
    "mon_reveal": ["A bat-like corpse held up on cathedral steps before a crowd in red robes", "Red robes thrown down in a courtyard"],
    "mon_moon_white": ["A red moon draining back to a pale white crescent over the snowy Howlers", "Silver light on the slate roofs of a quiet mining village"],
}


def build_cutscenes():
    pics = {}
    for cid, descs in SETS.items():
        for n, d in enumerate(descs, 1):
            pid = cid if n == 1 else f"{cid}_{n}"
            pics[pid] = d
            write(f"data/cutscenes/{pid}.json", {"id": pid, "title": pid.replace("mon_", "").replace("_", " ").capitalize(), "summary": d, "images": [{"image": pid, "when": ""}]})
    write("tools/content/monastery_cutscenes.json", {"style": read("tools/content/ghostlight_cutscenes.json")["style"], "pictures": pics})


# ---- flags, collected from the dialogue and the maps ---------------------------------------------------------------------------------
def build_flags():
    text = ""
    for f in (ROOT / "narrative/monastery").glob("*.dialogue"):
        text += f.read_text() + "\n"
    for lid in ["dawns_gate", "mon_pass", "dg_briar", "dg_briar_upper", "dg_briar_cellar", "mon_stables", "mon_ground", "mon_upper", "mon_bell_tower", "mon_belfry", "mon_holy_vein", "mon_sanctum", "mon_cathedral_moon"]:
        text += (ROOT / f"data/locations/{lid}.json").read_text() + "\n"
    text += (ROOT / "data/travel/wickermoor_hollow.json").read_text()
    wv = (ROOT / "data/locations/wickermoor_village.json").read_text()
    text += "\n".join(l for l in wv.splitlines() if "crimson" in l or "gareth" in l or "quiet" in l or "mon_" in l)
    names, ints, strs = set(), set(), set()
    for m in re.finditer(r"flag\.([a-z0-9_]+)(\s*(?:==|!=|>=|<=|>|<)\s*(\"?)[a-z0-9_]*\"?)?", text):
        names.add(m.group(1))
        if m.group(3) == '"' or m.group(3) == '\\"':
            strs.add(m.group(1))
    for m in re.finditer(r"^set ([a-z0-9_]+)( \+= -?\d+| -= \d+| = \"[^\"]*\"| = \d+| = now)?\s*$", text, re.M):
        names.add(m.group(1))
        if m.group(2):
            if "+=" in m.group(2) or "-=" in m.group(2) or re.search(r"= \d+$", m.group(2)):
                ints.add(m.group(1))
            elif '"' in m.group(2):
                strs.add(m.group(1))
    for m in re.finditer(r'"(?:flag|quest_flag)": "([a-z0-9_]+)"', text):
        names.add(m.group(1))
    for m in re.finditer(r'"flag": "([a-z0-9_]+)"', text):
        names.add(m.group(1))
    # fights set `<fight>_done`-style flags via their entries; the maps above list them
    skip = {"act2_done", "vessla_slain", "wm_welcomed", "foxwillow_asked", "gl_last_stop"}   # owned by other lanes' flag files
    flags = []
    for n in sorted(names - skip):
        if n.startswith("standing_"):
            continue
        t = "int" if n in ints and n not in strs else "string" if n in strs else "bool"
        flags.append({"id": n, "type": t, "summary": "R14 The Crimson Monastery (build_monastery.py).", "read_later": True})
    write("data/flags/monastery.json", {"flags": flags})
    return len(flags)


if __name__ == "__main__":
    stage = sys.argv[1] if len(sys.argv) > 1 else "all"
    if stage in ("all", "data"):
        build_locations()
        build_people()
        build_quests()
        build_items()
        build_monsters()
        build_travel()
        build_cutscenes()
    if stage in ("all", "hooks"):
        build_village_hooks()
    if stage in ("all", "flags"):
        print("flags", build_flags())
    print("ok")
