"""The Maidenmist Cemetery's conversations (R19): the logic is written here, the spoken text is drafted by Gemini through the ai-bridge
(docs/plans/gemini_r19/). A skeleton line holds `<<key|brief>>` where a drafted line goes; maidenmist_fill.py sends the briefs and writes
narrative/maidenmist/<file>.dialogue with the drafts in place. Node names are referenced by the maps and the tests: do not rename them."""
import re

FILES: dict[str, str] = {}

# ------------------------------------------------------------------------------------------------------------------------------------
# The rites: five beacons, one template. Each Fallen's themes are the digest's suggested skills with the tool checks stood in for by
# the nearest skill (no Persuasion/Performance/Insight/Deception/Intimidation: a failed one is spent for good, and a rite repeats).
RITES = {
    "crimson": dict(fallen="Sir Marius Renathyr", short="Marius", site="Y4, the Highborn Crypts", kindling="mm_dried_rose", flag="mm_crimson", mem=("mem_marius_feats", "mem_marius_oath", "mem_marius_love"), heirloom=None,
        themes=[("feats", "his feats on the road", ("Athletics", "Acrobatics"), "Tell of the rides and the fights"),
                ("oath", "his king, his oath and his god of the morning", ("History", "Religion"), "Speak the oath he kept"),
                ("love", "the woman who could calm him", ("Investigation", "Perception"), "Speak of the one who calmed him")],
        facts=["a knight of a god of the morning, sworn to King Viktor Denathria, whom he loved like a brother", "a destroyer of evil who rode a horse called Dawn", "a man whose wrath only one person ever calmed, a priestess named Lethica"]),
    "violet": dict(fallen="Lethica Nightborne", short="Lethica", site="Y5, the Cremation Gardens", kindling="mm_owl_feather", flag="mm_violet", mem=("mem_lethica_healing", "mem_lethica_love", "mem_lethica_hymns"), heirloom=None,
        themes=[("healing", "her healing", ("Medicine", "Nature"), "Speak of the cures she made"),
                ("love", "her love for Marius", ("Investigation", "History"), "Write the letter she never sent"),
                ("hymns", "the Nightmother's hymns", ("Religion", "Arcana"), "Sing the Nightmother's hymn")],
        facts=["a priestess of the Nightmother, goddess of night, healing and motherhood, whose symbol is a barn owl", "a healer to whom pilgrims came for cures, who hid behind a mask until she loved", "the one person who could quiet Marius's anger, and who loved him back"]),
    "amber": dict(fallen="Ol' Jericho Sticks", short="Jericho", site="Y6, the Potter's Field", kindling="mm_straw_bundle", flag="mm_amber", mem=("mem_jericho_songs", "mem_jericho_tales", "mem_jericho_craft"), heirloom="item:jericho_banjo",
        themes=[("songs", "his folksy songs", ("Sleight of Hand", "History"), "Play one of his songs"),
                ("tales", "his tall tales", ("Investigation", "History"), "Tell one of his tall tales"),
                ("craft", "his handiwork and his farming", ("Survival", "Nature"), "Speak of the work of his hands")],
        facts=["a kindly scarecrow tunesmith with a banjo, who told stories from town to town", "a man the children loved, who listened as hard as he sang", "a handyman and field-hand who mended whatever he was given"]),
    "magenta": dict(fallen="Captain Briggsy Kratch", short="Briggsy", site="Y7, the Mausoleum Lanes", kindling="mm_rum_bottle", flag="mm_magenta", mem=("mem_briggsy_exploits", "mem_briggsy_ruses", "mem_briggsy_luck"), heirloom=None,
        themes=[("exploits", "his exploits at sea", ("History", "Survival"), "Tell of his voyages"),
                ("ruses", "his footwork and his ruses", ("Acrobatics", "Sleight of Hand"), "Speak of his ruses and his swordwork"),
                ("luck", "his luck, and the sorcery that bent it", ("Arcana", "Investigation"), "Speak of his luck at the tables")],
        facts=["a feared pirate with a heart of gold, who never once abandoned a loyal crew", "a swordsman and a schemer, quick on his feet and quicker with a lie", "a man lucky at every game until he learned to bend fate with sorcery"]),
    "emerald": dict(fallen="Farryn of the Greenwood", short="Farryn", site="Y8, the Burial Mounds", kindling="mm_oak_branch", flag="mm_emerald", mem=("mem_farryn_circle", "mem_farryn_forest_love", "mem_farryn_gwenna"), heirloom=None,
        themes=[("circle", "her circle and the Old Ways", ("Nature", "Religion"), "Speak of her circle and the Green Queen"),
                ("beasts", "her love of beasts and growing things", ("Animal Handling", "Medicine"), "Speak of the creatures she tended"),
                ("gwenna", "her love for Gwenna", ("Survival", "Investigation"), "Carve something for Gwenna")],
        facts=["a satyr of an antlered druid circle, which served the Green Queen", "at home with beasts, birds and the Fey, and gentle with all of them", "a woman who loved Gwenna, a hopeful human of the Patient Lady, more than the wild itself"]),
}
COLORS = list(RITES)
LEVEL_NAME = {"crimson": "Crimson", "violet": "Violet", "amber": "Amber", "magenta": "Magenta", "emerald": "Emerald"}


def rite_file() -> str:
    out = ["# Drafted by Gemini (R19 rites), edited. The five Final Rites of Maidenmist; logic by hand.\n"]
    for c in COLORS:
        r = RITES[c]
        f = r["flag"]
        site = r["site"]
        short = r["short"]
        cname = LEVEL_NAME[c]
        out.append(f"""
~ {c}_start
if flag.{f}_guardians_dead
-> {c}_honor
endif
Narrator: <<{c}_scene|The party stands at the cold brazier at {site}, Yorgrim's lantern holding the fog back. One or two sentences, concrete senses.>>
yorgrim [weary]: <<{c}_facts|Yorgrim, dour, stoic, short flat sentences, tells the party three facts about {r['fallen']}: {r['facts'][0]}; {r['facts'][1]}; {r['facts'][2]}. Three or four short sentences in all.>>
* [if item:{r['kindling']}] Place the kindling in the brazier -> {c}_kindle
* I have no kindling yet -> {c}_nokindle
* Tell us again what you know of {short} -> {c}_start
* We will be back -> END

~ {c}_nokindle
yorgrim [neutral]: <<{c}_nokindle|Yorgrim says the kindling is hidden somewhere near; his memory is failing; try again, nothing is lost. Two short sentences.>>
-> END

~ {c}_kindle
take {r['kindling']}
set {f}_kindled
Narrator: <<{c}_flame|The kindling catches in the brazier and the {c} fire climbs; the fog thickens and the site's guardians rise to be offered to the flame. Two sentences.>>
yorgrim [angry]: <<{c}_hold|Yorgrim tells the party to keep inside the lantern light and kill what comes; they must die in the fire's sight. Two short sentences.>>
combat {f}_rite

~ {c}_honor
if not flag.{f}_began
set {f}_began
set {f}_round = 0
set {f}_succ = 0
set {f}_bright = 0
endif
-> {c}_rite

~ {c}_rite
if flag.{f}_succ >= 6
-> {c}_done
endif
if flag.mm_yorgrim_spent and flag.{f}_succ >= 4
-> {c}_done
endif
if flag.{f}_round >= 10
-> {c}_dies
endif
Narrator: <<{c}_rite_prompt|The rite is under way; the flame hangs on the party's remembered words of {r['fallen']}; each theme to speak to. One sentence.>>
* {r['themes'][0][3]} -> {c}_a
* {r['themes'][1][3]} -> {c}_b
* {r['themes'][2][3]} -> {c}_c
* Step back from the flame for now -> END
""")
        for i, (tid, tdesc, skills, label) in enumerate(r["themes"]):
            letter = "abc"[i]
            mem = r["mem"][i]
            oks = skills
            out.append(f"""
~ {c}_{letter}
if flag.{mem}
advantage checks next: you remember {short}
endif
Narrator: <<{c}_{letter}_intro|The party turns the rite toward {tdesc}; what each hero reaches for. One or two sentences.>>
* [{skills[0]} DC 15] {label}, the way you have heard it -> {c}_{letter}_ok | {c}_{letter}_miss
* [{skills[1]} DC 15] {label}, another way -> {c}_{letter}_ok | {c}_{letter}_miss
* [Charisma DC 18] Offer a memory of your own -> {c}_{letter}_ok | {c}_{letter}_miss
* Choose another theme -> {c}_rite

~ {c}_{letter}_ok
set {f}_succ += 1
set {f}_round += 1
if flag.{mem}
set {f}_bright += 1
endif
Narrator: <<{c}_{letter}_okline|The flame leaps up as the words land true, speaking of {tdesc}. One or two sentences.>>
-> {c}_rite

~ {c}_{letter}_miss
set {f}_round += 1
damage 1d6 psychic party
Narrator: <<{c}_{letter}_missline|The words fall flat, and the shrouded spirits mock {r['fallen']} in the flame with a mocking, cruel shape of {tdesc}; everyone who hears it flinches. Two sentences.>>
-> {c}_rite
""")
        out.append(f"""
~ {c}_dies
Narrator: <<{c}_dies|The minute runs out and the flame gutters dark; Yorgrim offers a sliver of his soul to hold the ember. Two sentences.>>
set mm_soul_fragments += 1
set mm_rite_fails += 1
disadvantage checks 1h: a piece of your soul is in the fire
set {f}_round = 0
set {f}_succ = 0
set {f}_bright = 0
if flag.mm_rite_fails >= 2
set mm_yorgrim_spent
yorgrim [weary]: <<{c}_spent|Yorgrim says he will spend more of himself so the next attempt needs fewer words; he grows fainter. Two sentences, tired.>>
else
yorgrim [neutral]: <<{c}_again|Yorgrim says the flame can be tried again, and the fault is nobody's. One sentence.>>
endif
-> END

~ {c}_done
set beacon_{c} = 1
if flag.{f}_bright >= 3
set beacon_{c} = 2
endif
if flag.{f}_bright >= 6
set beacon_{c} = 3
endif
set mm_beacons_lit += 1
set {f}_done
cutscene mm_beacon_lit
Narrator: <<{c}_done|The {cname} beacon roars up and the mist rolls back from {site}; far off a sconce catches above the sepulcher doors. Two sentences.>>
yorgrim [smile]: <<{c}_thanks|Yorgrim, quietly moved, honours {r['fallen']} as who he was before he fell. Two short sentences.>>
if flag.mm_beacons_lit >= 5
set sepulcher_open
quest maidenmist_dead_rise sepulcher
yorgrim [weary]: <<{c}_all_lit|All five are burning with his azure; Yorgrim says the sepulcher doors will open; it is time to go back. Two short sentences.>>
endif
-> END
""")
    return "\n".join(out)


# The Azure Rites: Yorgrim's own, in the tomb after the Reaper falls (six successes, three themes).
def azure_file() -> str:
    themes = [("a", "his care for the dead and his rites", ("Arcana", "History"), "Speak of his care for the dead"),
              ("b", "his duty to the Shadestone Clan", ("History", "Religion"), "Speak the names on his stone"),
              ("c", "his bond with his friends and with Isolde", ("Nature", "Investigation"), "Speak of his friends and his hound")]
    out = []
    for letter, desc, skills, label in themes:
        out.append(f"""
~ azure_{letter}
Narrator: <<azure_{letter}_intro|The party turns the last rite toward {desc}. One sentence.>>
* [{skills[0]} DC 15] {label} -> azure_{letter}_ok | azure_{letter}_miss
* [{skills[1]} DC 15] {label}, from what you learned of him -> azure_{letter}_ok | azure_{letter}_miss
* [Charisma DC 18] Offer a memory of your own -> azure_{letter}_ok | azure_{letter}_miss
* Choose another theme -> azure_rite

~ azure_{letter}_ok
set mm_azure_succ += 1
Narrator: <<azure_{letter}_okline|The lantern flares as the words land true, about {desc}. Two sentences.>>
-> azure_rite

~ azure_{letter}_miss
set mm_azure_miss += 1
damage 1d6 psychic party
Narrator: <<azure_{letter}_missline|The words fall short, the Shroud whispers a mocking echo of {desc}, and the tear shudders. Two sentences.>>
if flag.mm_azure_miss >= 3
if not flag.mm_wave_done
combat mm_tear_wave
endif
endif
-> azure_rite
""")
    return "\n".join(out)


FILES["rites"] = rite_file()

# ------------------------------------------------------------------------------------------------------------------------------------
FILES["road"] = """# Drafted by Gemini (R19 road), edited. The gate, the Corpse Road and King's Rest.

~ gate_arrive
set mm_gate_seen
cutscene mm_broken_gate
Narrator: <<gate_arrive|The party reaches the Maidenmist gate: the iron fence running into fog, the bent gate between two hooded reapers, the cold. Two sentences.>>
interject name:rook_coldwake: <<gate_rook|Rook Coldwake, clipped and deadpan with municipal vocabulary, remarks on the state of this fence as a piece of civic infrastructure. One line.>>
-> END

~ gate_chain
set mm_chain_seen
Narrator: <<gate_chain|A fifty-foot iron chain lies snapped in the mud by the gate; the links are bent outward. One or two sentences.>>
* [Investigation DC 13] Study how the chain broke -> chain_clever | chain_plain
* Take the chain, it is iron and the shrouded fear iron -> chain_take
* Leave it -> END

~ chain_clever
Narrator: <<chain_clever|The links were burst from inside; whatever broke the gate was already within. One or two sentences.>>
set mm_gate_burst_known
-> chain_take

~ chain_plain
Narrator: <<chain_plain|The chain is old and cold and tells the party nothing more. One sentence.>>
-> chain_take

~ chain_take
give mm_iron_chain
Narrator: <<chain_take|The party coils fifty feet of cold iron over a shoulder; the chain is heavy and it feels right. One sentence.>>
-> END

~ mile1
set mm_mile1_done
Narrator: <<mile1|In the first mile the fog leans on the party and every grave marker seems to look back; a wail sets in behind the eyes. Two sentences.>>
check Wisdom DC 15 -> mile1_ok | mile1_fail

~ mile1_ok
damage 1d6 psychic party
Narrator: <<mile1_ok|The party grits its teeth through the wail and comes through with only a headache. One sentence.>>
-> END

~ mile1_fail
damage 2d6 psychic party
damage 2d6 necrotic party
Narrator: <<mile1_fail|The wailing and the cold get through, and every hero staggers with it. One or two sentences.>>
-> END

~ mile3
set mm_mile3_done
Narrator: <<mile3|The third mile is the coldest; breath hangs in the air and does not come back out. One or two sentences.>>
check Constitution DC 15 -> mile3_ok | mile3_fail

~ mile3_ok
Narrator: <<mile3_ok|The party pushes through the freezing fog and reaches the hilltop with strength to spare. One sentence.>>
-> END

~ mile3_fail
disadvantage checks 2h: the long cold walk
Narrator: <<mile3_fail|The cold settles into the bones and will not leave for a good while. One sentence.>>
-> END

~ kings_rest
set mm_kings_rest_seen
Narrator: <<kings_rest|Before the rune-covered doors, wights and shrouded fight on in the fog without end, under a giant armoured king with his sword raised. One or two sentences.>>
if flag.yorgrim_with_party
yorgrim [afraid]: <<kings_yorgrim|Yorgrim, flatly, warns them off; the doors kill; something sleeps inside that must not be woken. Two short sentences.>>
endif
Narrator: <<kings_doors|The great doors do not budge; and the party is quite sure it would be a mistake if they did. One sentence.>>
-> END
"""

# ------------------------------------------------------------------------------------------------------------------------------------
FILES["yorgrim"] = """# Drafted by Gemini (R19 yorgrim), edited. Yorgrim the Gravedigger, ally and then the sixth Fallen.

~ arrive
quest maidenmist_dead_rise gravedigger
cutscene mm_gravedigger_door
Narrator: <<arrive|At the sepulcher's doors an orc ghost hunches under a chained gravestone, a black hound beside him, both holding lanterns to the seam. One or two sentences.>>
-> meet

~ meet
set yorgrim_met
yorgrim [weary]: <<meet_hello|Yorgrim, deep slow orc bass, short flat sentences, long pauses: he greets the strangers, says the dead have been restless, and asks who they are. Two short sentences.>>
-> meet_menu

~ meet_menu
* Who are you? -> q_who
* What is this place? -> q_place
* Are you dead? -> q_dead
* The hound? -> q_dog
* What is the Shroud? -> q_shroud
* What are those things in the mist? -> q_shrouded
* The monsters we killed. Your friends? -> q_friends
* You honour villains? -> q_honour
* What do we do about it? -> briefing

~ q_who
yorgrim [neutral]: <<q_who|Yorgrim says his name, that this is his cemetery, and that he serves the dead. Two short sentences.>>
-> meet_menu

~ q_place
yorgrim [neutral]: <<q_place|Yorgrim says the hollow's dead have lain here for centuries, before him and after. Two short sentences.>>
-> meet_menu

~ q_dead
yorgrim [weary]: <<q_dead|Yorgrim says his life ended but his duty did not, and will not until he atones. Two short sentences.>>
-> meet_menu

~ q_dog
Narrator: <<q_dog|The black hound with white eyes presses against Yorgrim's leg, a hooded lantern in her mouth with a spark in it. One sentence.>>
yorgrim [smile]: <<q_dog_line|Yorgrim says she is Isolde, a grim, his only companion. One short sentence.>>
-> meet_menu

~ q_shroud
yorgrim [afraid]: <<q_shroud|Yorgrim says the Shroud is death itself, an element that should not be here, not even in an afterlife. Two short sentences.>>
-> meet_menu

~ q_shrouded
yorgrim [angry]: <<q_shrouded|Yorgrim says shrouded are souls eaten and hollowed by the Shroud, abominations; do not let them touch you. Two short sentences.>>
-> meet_menu

~ q_friends
yorgrim [sad]: <<q_friends|Yorgrim says those the party killed were his friends, good hearts once, who fell to their burdens as anyone might. Two short sentences.>>
-> meet_menu

~ q_honour
yorgrim [neutral]: <<q_honour|Yorgrim says nobody will mourn the Crimson Abbot or the Grinning Sinner; he honours who those souls were while there was light in them, the only way. Two short sentences.>>
-> meet_menu

~ briefing
Narrator: <<briefing_scene|Yorgrim lifts his lantern; the fog backs off; the mist leaks from the seam in the doors and burns in the azure light. One sentence.>>
yorgrim [weary]: <<briefing_1|Yorgrim explains: the tear is growing; the beacons went out one by one; only his azure one still burns, tied to his soul. Three short sentences.>>
yorgrim [neutral]: <<briefing_2|Yorgrim explains: the rites of the Fallen can relight the other five; corrupted monsters guard the braziers; he will go with them and shield them with his light. Three short sentences.>>
yorgrim [neutral]: <<briefing_3|Yorgrim explains: Isolde stays at the door and can last only sixteen hours; when all six burn, the doors will open. Two short sentences.>>
* We will relight them -> accept
* [if background:acolyte] We know a little of death rites -> accept_acolyte
* Let us think -> END

~ accept_acolyte
yorgrim [smile]: <<accept_acolyte|Yorgrim, gruffly pleased, says that will help. One short sentence.>>
-> accept

~ accept
set yorgrim_with_party
set isolde_alone_since = now
quest maidenmist_dead_rise beacons
join yorgrim
yorgrim [neutral]: <<accept|Yorgrim says stay in the light of his lantern and he will keep the mist off; the nearest site is any of the seven paths. Two short sentences.>>
-> END

~ at_the_doors
yorgrim [neutral]: <<at_doors|Yorgrim waits at the doors, lantern held to the seam, and asks if they are ready to go on with the beacons. Two short sentences.>>
* Come with us -> rejoin
* Not yet -> END

~ rejoin
set yorgrim_with_party
join yorgrim
-> END

~ site_crypts
set mm_site_crypts_told
yorgrim [weary]: <<site_crypts|Yorgrim, vaguer now, says this is where Marius's beacon burned, a knight who rode a horse called Dawn. One or two short sentences.>>
-> END

~ site_gardens
set mm_site_gardens_told
yorgrim [sad]: <<site_gardens|Yorgrim says here Lethica kept her beacon, and that she hid a kind face behind a mask. One or two short sentences.>>
-> END

~ site_potters
set mm_site_potters_told
yorgrim [neutral]: <<site_potters|Yorgrim says Jericho's beacon, among nameless graves, fitting for a man the children loved. One or two short sentences.>>
-> END

~ site_lanes
set mm_site_lanes_told
yorgrim [neutral]: <<site_lanes|Yorgrim says Briggsy's fire here, a pirate with a heart of gold, and he will not say how many rum bottles are buried. One or two short sentences.>>
-> END

~ site_mounds
set mm_site_mounds_told
yorgrim [sad]: <<site_mounds|Yorgrim says Farryn's beacon, a satyr who loved a human, and that the trees here still remember her. One or two short sentences.>>
-> END

~ clan_stones
cutscene mm_penitent_pilgrim
Narrator: <<clan_scene|The standing stones are cut with Orc names, hundreds of them, root to crown. One sentence.>>
yorgrim [weary]: <<clan_1|Yorgrim, slowly, says these are the names of the Shadestone Clan, his clan, which he led in a ritual that was a trick; their souls were annihilated. Three short sentences.>>
yorgrim [sad]: <<clan_2|Yorgrim says the stone chained to his back carries the same names; he drags it to atone. Two short sentences.>>
set yorgrim_told_story
set mm_clan_names_learned
-> END

~ doors_open
yorgrim [weary]: <<doors_open|Yorgrim, fainter, lantern small, says all six burn and the doors open; he talks less now and will not turn back. Three short sentences.>>
if flag.isolde_alive and not flag.isolde_faded
Narrator: <<doors_isolde|Yorgrim tells Isolde to stay and guard the door, and she lies down with a low whine, watching him go. One or two sentences.>>
endif
* Go in -> doors_go
* Wait a moment -> END

~ doors_go
set yorgrim_descends
quest maidenmist_dead_rise sepulcher
-> END
"""

# ------------------------------------------------------------------------------------------------------------------------------------
FILES["isolde"] = """# Drafted by Gemini (R19 isolde), edited. Isolde the grim speaks in Narrator lines only.

~ door
set isolde_met
set isolde_alive
Narrator: <<isolde_door|A black hound with bright white eyes holds a hooded lantern in her mouth and stands against the seam of the great doors, hackles up. One or two sentences.>>
* Offer her a hand -> door_hand
* [Animal Handling DC 12] Calm her -> door_calm | door_hand
* Leave her to her work -> END

~ door_hand
Narrator: <<isolde_hand|The hound sniffs the offered hand and licks it once, then goes back to guarding the seam. One sentence.>>
-> END

~ door_calm
Narrator: <<isolde_calm|The hound's hackles ease; she watches the party the way a guard watches a friend. One sentence.>>
-> END

~ fades
set isolde_faded
set isolde_alive = 0
cutscene mm_isolde_fades
Narrator: <<isolde_fades|Isolde, alone at the doors too long, flickers; her lantern gutters out, and she is gone; mist pours from the seam. Two sentences.>>
set mm_isolde_lurkers
-> END

~ farewell
set mm_isolde_farewelled
cutscene mm_isolde_farewell
Narrator: <<isolde_farewell|Isolde lies by the doors under six burning sconces, then rises and turns toward the Shadestone stones as if to say follow. Two sentences.>>
-> END
"""

# ------------------------------------------------------------------------------------------------------------------------------------
FILES["sites"] = """# Drafted by Gemini (R19 sites), edited. Hazards and kindling searches of the five beacon sites.

~ crypt_study
Narrator: <<crypt_study|A crypt wall is worked with suns and roses; the family's crest. One sentence.>>
* [History DC 15] Study the carvings -> crypt_study_ok | crypt_study_plain
* [Religion DC 15] Read the god of the morning in the stone -> crypt_study_ok | crypt_study_plain
* Leave it -> END

~ crypt_study_ok
set mm_crypt_hint
Narrator: <<crypt_study_ok|The suns and roses are Marius's family's, and they mark the crypt on the east of the courtyard. One or two sentences.>>
-> END

~ crypt_study_plain
Narrator: <<crypt_study_plain|The carvings are fine work and tell the party nothing certain. One sentence.>>
-> END

~ crypt_wrong_a
Narrator: <<crypt_door|The crypt door is sealed with a basin at its foot; a blood tithe will open it. One sentence.>>
* Pay the tithe, a little blood -> crypt_open_wrong_a
* Leave it -> END

~ crypt_open_wrong_a
damage 1d12 necrotic
check Dexterity DC 17 -> crypt_bats_ok | crypt_bats_fail

~ crypt_wrong_c
Narrator: <<crypt_door2|The crypt door is sealed with a basin at its foot; a blood tithe will open it. One sentence.>>
* Pay the tithe, a little blood -> crypt_open_wrong_c
* Leave it -> END

~ crypt_open_wrong_c
damage 1d12 necrotic
check Dexterity DC 17 -> crypt_bats_ok | crypt_bats_fail

~ crypt_bats_ok
Narrator: <<crypt_bats_ok|Bats burst out of the opened crypt and the party ducks them; the chamber beyond is empty and wrong. One or two sentences.>>
-> crypt_empty

~ crypt_bats_fail
damage 4d4 piercing
Narrator: <<crypt_bats_fail|Bats burst out of the crypt in a screaming cloud and bite. One sentence.>>
-> crypt_empty

~ crypt_empty
if flag.mm_crimson_fails < 2
set mm_crimson_fails += 1
endif
yorgrim [neutral]: <<crypt_empty|Yorgrim says this is not the one, and something in the courtyard has stirred at the noise. Two short sentences.>>
-> END

~ crypt_right
Narrator: <<crypt_door3|The crypt door is sealed with a basin at its foot; the suns and roses over it are the ones from the wall. One sentence.>>
if flag.mm_crypt_hint
Narrator: <<crypt_right_hint|This is the crypt the carvings pointed to. One short sentence.>>
endif
* Pay the tithe, a little blood -> crypt_open_right
* Leave it -> END

~ crypt_open_right
damage 1d12 necrotic
check Dexterity DC 17 -> crypt_right_ok | crypt_right_fail

~ crypt_right_ok
Narrator: <<crypt_right_ok|Bats burst out; the party ducks them and the stair down is open. One sentence.>>
move mm_crypt_below:from_stair

~ crypt_right_fail
damage 4d4 piercing
Narrator: <<crypt_right_fail|Bats burst out in a screaming cloud and bite as the stair opens. One sentence.>>
move mm_crypt_below:from_stair

~ rose_take
give mm_dried_rose
set mm_rose_taken
Narrator: <<rose_take|On a sarcophagus lid lies a dried red rose, light as paper, and the party takes it. One sentence.>>
-> END

~ fountain
Narrator: <<fountain|A wishing fountain burbles in the rain, coins gleaming in the basin. One sentence.>>
* Toss in a gold piece for luck -> fountain_toss
* Take the coins -> fountain_take
* [Arcana DC 18] Work out what the fountain does -> fountain_study | fountain_plain
* Leave it -> END

~ fountain_study
Narrator: <<fountain_study|A coin given blesses; a coin taken curses. Both last a few hours. One or two sentences.>>
set mm_fountain_known
-> fountain

~ fountain_plain
Narrator: <<fountain_plain|The water keeps its secret. One short sentence.>>
-> fountain

~ fountain_toss
gold -1
bless party 2h
Narrator: <<fountain_toss|The coin sinks, and warmth settles on each shoulder. One sentence.>>
-> END

~ fountain_take
check Wisdom DC 18 -> fountain_take_ok | fountain_take_cursed

~ fountain_take_ok
gold +300
Narrator: <<fountain_take_ok|The party fills a pocket with wishes and nothing happens. One sentence.>>
-> END

~ fountain_take_cursed
gold +300
disadvantage checks 2h: the fountain's curse
Narrator: <<fountain_take_cursed|Cold coin, and a cold feeling in the stomach; the fountain remembers. One sentence.>>
-> END

~ urn_study
Narrator: <<urn_study|Rows of clay urns line the walk; some of them hum a thin, terrible note. One sentence.>>
* [Nature DC 15] Listen to which hum and which do not -> urn_study_ok | urn_study_plain
* [Religion DC 15] Judge them by their carving -> urn_study_ok | urn_study_plain
* Leave it -> END

~ urn_study_ok
set mm_urn_hint
Narrator: <<urn_study_ok|The humming urns are mourning urns, and they wail if they are opened; one stands silent, with owls on its side. One or two sentences.>>
-> END

~ urn_study_plain
Narrator: <<urn_study_plain|The humming is unsettling and the party cannot say why. One sentence.>>
-> END

~ urn_wrong_a
Narrator: <<urn_wrong|The urn hums a mourning note that rises as a hand nears the lid. One sentence.>>
if flag.mm_urn_hint
Narrator: <<urn_warn|This is a mourning urn: opening it will wail. One short sentence.>>
endif
* Open it anyway -> urn_wail
* Leave it -> END

~ urn_wrong_c
Narrator: <<urn_wrong2|The urn hums a mourning note that rises as a hand nears the lid. One sentence.>>
* Open it anyway -> urn_wail
* Leave it -> END

~ urn_wail
check Wisdom DC 13 -> urn_wail_ok | urn_wail_fail

~ urn_wail_ok
Narrator: <<urn_wail_ok|The urn wails, and the party hears it as a wave and lets it pass. One sentence.>>
-> urn_empty

~ urn_wail_fail
damage 4d6 psychic party
Narrator: <<urn_wail_fail|The wail goes through everyone like a hand through water, and every hero staggers. One sentence.>>
-> urn_empty

~ urn_empty
if flag.mm_violet_fails < 2
set mm_violet_fails += 1
endif
yorgrim [neutral]: <<urn_empty|Yorgrim says not that one; the loud ones hold only ash. Two short sentences.>>
-> END

~ urn_right
Narrator: <<urn_right|The urn with owls on its side is silent; it does not wail. One sentence.>>
* Open it -> urn_right_open
* Leave it -> END

~ urn_right_open
give mm_owl_feather
set mm_owl_taken
Narrator: <<urn_right_open|Inside the silent urn lies a single barn owl feather, white as a new moon. One sentence.>>
-> END

~ lavender
give mm_lavender
Narrator: <<lavender|A bed of lavender gone wild; the party picks a bunch. One sentence.>>
-> END

~ lilies
give mm_lilies
Narrator: <<lilies|White lilies bloom in the rain; the party picks a few. One sentence.>>
-> END

~ amber_find
Narrator: <<amber_find|Amber lights bob in the fog, leading nowhere the party can follow; the brazier is somewhere among them. One sentence.>>
* [Perception DC 18] Read where the lights gather -> amber_found | amber_lost
* [Survival DC 18] Read the ground between the posts -> amber_found | amber_lost
* Ask Yorgrim to find it -> amber_yorgrim
* Leave it -> END

~ amber_found
set mm_amber_found
Narrator: <<amber_found|The lights circle one hollow, and the brazier of orange coals is in it. One sentence.>>
-> END

~ amber_lost
time +60
check Dexterity DC 17 -> amber_pit_ok | amber_pit_fail

~ amber_pit_ok
set mm_amber_found
Narrator: <<amber_pit_ok|An hour is lost in the fog, and the edge of a mass grave catches no one; Yorgrim's lantern then finds the brazier. Two sentences.>>
-> END

~ amber_pit_fail
set mm_amber_found
damage 2d6 necrotic party
Narrator: <<amber_pit_fail|The ground gives way into a mass grave and skeletal hands pull, until the party tears free; then Yorgrim's lantern finds the brazier. Two sentences.>>
-> END

~ amber_yorgrim
set mm_amber_found
Narrator: <<amber_yorgrim|Yorgrim raises his lantern and the amber lights scatter, showing the brazier. One sentence.>>
-> END

~ mass_grave
Narrator: <<mass_grave|The edge of a mass grave yawns, and skeletal hands stir at the bottom of it. One sentence.>>
-> END

~ grave_study
Narrator: <<grave_study|Crows flock on one post in the field. One short sentence.>>
* [Animal Handling DC 17] Watch where the crows gather -> grave_study_ok | grave_study_plain
* [Perception DC 17] Look for the post they will not leave -> grave_study_ok | grave_study_plain
* Leave it -> END

~ grave_study_ok
set mm_grave_hint
Narrator: <<grave_study_ok|The crows ring one shallow grave to the east; it holds the straw. One or two sentences.>>
-> END

~ grave_study_plain
Narrator: <<grave_study_plain|The crows are no help at all. One sentence.>>
-> END

~ grave_wrong_a
Narrator: <<grave_dig|The party starts to dig the shallow grave; carrion birds explode out of the ground. One sentence.>>
check Constitution DC 15 -> grave_birds_ok | grave_birds_fail

~ grave_wrong_c
Narrator: <<grave_dig2|The party starts to dig the shallow grave; carrion birds explode out of the ground. One sentence.>>
check Constitution DC 15 -> grave_birds_ok | grave_birds_fail

~ grave_birds_ok
Narrator: <<grave_birds_ok|The birds scatter and the grave under them holds nothing but a bone or two. One sentence.>>
-> grave_empty

~ grave_birds_fail
damage 1d8 poison party
Narrator: <<grave_birds_fail|The birds' wings are thick with grave-dust and the party coughs for a while. One sentence.>>
-> grave_empty

~ grave_empty
if flag.mm_amber_fails < 2
set mm_amber_fails += 1
endif
yorgrim [neutral]: <<grave_empty|Yorgrim says this one holds no straw, and a pale shape stirs in the fog. Two short sentences.>>
-> END

~ grave_right
Narrator: <<grave_right|The crows gather thickest on this grave. One short sentence.>>
* Dig -> grave_right_dig
* Leave it -> END

~ grave_right_dig
give mm_straw_bundle
set mm_straw_taken
Narrator: <<grave_right_dig|A dry bundle of straw lies in the shallow grave, tied with a bit of blue yarn. One sentence.>>
-> END

~ muck
set mm_magenta_muck_done
Narrator: <<muck|Acrid muck seeps up between the tiles of the lane and stings the nose. One sentence.>>
check Strength DC 17 -> muck_ok | muck_fail

~ muck_ok
Narrator: <<muck_ok|The party picks a dry way over the slick tiles. One sentence.>>
-> END

~ muck_fail
damage 1d10 acid
Narrator: <<muck_fail|A boot goes through the tile and into acid mud; the leg burns until it is dragged out. One sentence.>>
-> END

~ vault_study
Narrator: <<vault_study|The vault doors are carved with ships and spirals, hex glyphs at their corners. One sentence.>>
* [Arcana DC 17] Read the glyphs -> vault_study_ok | vault_study_plain
* [History DC 17] Read the ships -> vault_study_ok | vault_study_plain
* Leave it -> END

~ vault_study_ok
set mm_vault_hint
Narrator: <<vault_study_ok|One vault is carved with a ship and a sorcerer's spiral together, to the south-east; that is Briggsy's. One or two sentences.>>
-> END

~ vault_study_plain
Narrator: <<vault_study_plain|The carvings tell no clear story. One short sentence.>>
-> END

~ vault_wrong_a
Narrator: <<vault_door|A hexed vault door, a glyph glowing faintly at its corner. One sentence.>>
* [Athletics DC 20] Force it -> vault_open_wrong | vault_hexed
* Open it anyway and take the hex -> vault_hexed
* Leave it -> END

~ vault_wrong_c
Narrator: <<vault_door2|A hexed vault door, a glyph glowing faintly at its corner. One sentence.>>
* [Athletics DC 20] Force it -> vault_open_wrong | vault_hexed
* Open it anyway and take the hex -> vault_hexed
* Leave it -> END

~ vault_hexed
damage 2d10 force
disadvantage checks 1h: the vault's hex
-> vault_open_wrong

~ vault_open_wrong
Narrator: <<vault_open_wrong|The vault stands open and the bones inside are not Briggsy's. One sentence.>>
if flag.mm_magenta_fails < 2
set mm_magenta_fails += 1
endif
yorgrim [neutral]: <<vault_empty|Yorgrim says not that one, and a heavy shape moves above the lanes. Two short sentences.>>
-> END

~ vault_right
Narrator: <<vault_right|A hexed vault door with a ship and a spiral carved side by side. One sentence.>>
* [Athletics DC 20] Force it -> vault_right_open | vault_right_hex
* Open it anyway and take the hex -> vault_right_hex
* Leave it -> END

~ vault_right_hex
damage 2d10 force
disadvantage checks 1h: the vault's hex
-> vault_right_open

~ vault_right_open
give mm_rum_bottle
set mm_rum_taken
Narrator: <<vault_right_open|Inside, on a bone-dry shelf, a bottle of rum, still corked. One sentence.>>
-> END

~ moth_vault
give mm_moth_wing
set mm_moth_taken
Narrator: <<moth_vault|In a small vault, a dried moth's wing the size of a hand lies in a glass case, its pattern a promise of sleep. One sentence.>>
-> END

~ emerald_find
Narrator: <<emerald_find|The mounds shift in the mist and every path loops back; the green brazier is somewhere among them. One sentence.>>
* [Survival DC 18] Find the way through the mounds -> emerald_found | emerald_lost
* [Nature DC 18] Read where the trees lean -> emerald_found | emerald_lost
* Ask Yorgrim to find it -> emerald_yorgrim
* Leave it -> END

~ emerald_found
set mm_emerald_found
Narrator: <<emerald_found|The trees all lean toward one mound, and green coals glow atop it. One sentence.>>
-> END

~ emerald_lost
time +60
set mm_emerald_ring_ready
Narrator: <<emerald_lost|An hour is lost in the shifting wood, and the party ends inside a ring of bright toadstools. One sentence.>>
-> toadstool_ring

~ toadstool_ring
set mm_ring_done
check Constitution DC 17 -> ring_ok | ring_fail

~ ring_ok
set mm_emerald_found
Narrator: <<ring_ok|The spores sting the eyes, and then Yorgrim's lantern shows the brazier. One sentence.>>
-> END

~ ring_fail
set mm_emerald_found
damage 2d8 poison party
Narrator: <<ring_fail|The toadstool spores burn the lungs; then Yorgrim's lantern shows the brazier. One sentence.>>
-> END

~ emerald_yorgrim
set mm_emerald_found
Narrator: <<emerald_yorgrim|Yorgrim raises his lantern and the mist peels back from the green brazier. One sentence.>>
-> END

~ apple_tree
Narrator: <<apple_tree|Bright apples hang from hand-shaped branches. One short sentence.>>
* [Nature DC 15] Study the apples -> apple_study_ok | apple_study_plain
* Pick one -> apple_pick
* Eat one -> apple_eat
* Leave it -> END

~ apple_study_ok
Narrator: <<apple_study_ok|The apples are magical, for good or ill; one in twenty can do real harm; the tree lashes out at a thief. Two sentences.>>
-> apple_tree

~ apple_study_plain
Narrator: <<apple_study_plain|The apples gleam and tell nothing. One short sentence.>>
-> apple_tree

~ apple_pick
check Dexterity DC 15 -> apple_pick_ok | apple_pick_lash

~ apple_pick_ok
give forbidden_apple
Narrator: <<apple_pick_ok|A hand-shaped branch swings; the party picks an apple and ducks. One sentence.>>
-> END

~ apple_pick_lash
damage 1d12 bludgeoning
give forbidden_apple
Narrator: <<apple_pick_lash|The tree lashes out as the apple is taken and knocks the picker flat. One sentence.>>
-> END

~ apple_eat
check Constitution DC 10 -> apple_good | apple_bad

~ apple_good
heal 4d4+4 party
Narrator: <<apple_good|The apple is sweet and the body warms through. One sentence.>>
-> END

~ apple_bad
damage 4d6 poison
Narrator: <<apple_bad|The apple is bitter and the stomach turns over. One sentence.>>
-> END

~ mound_study
Narrator: <<mound_study|A twisted tree with a woman's face carved in its trunk, antlers worn into the bark. One sentence.>>
* [Perception DC 17] Follow the tree's gaze -> mound_study_ok | mound_study_plain
* [Survival DC 17] Follow the roots -> mound_study_ok | mound_study_plain
* Leave it -> END

~ mound_study_ok
set mm_mound_hint
Narrator: <<mound_study_ok|The face looks east, at the mound the oak branch hangs over. One sentence.>>
-> END

~ mound_study_plain
Narrator: <<mound_study_plain|The carved face tells nothing. One short sentence.>>
-> END

~ mound_wrong_a
Narrator: <<mound_dig|The barrow mouth is packed with earth; the party digs for a minute and finds only a ring of stones. One sentence.>>
-> mound_empty

~ mound_wrong_c
Narrator: <<mound_dig2|The barrow mouth is packed with earth; the party digs for a minute and finds only a ring of stones. One sentence.>>
-> mound_empty

~ mound_empty
if flag.mm_emerald_fails < 2
set mm_emerald_fails += 1
endif
yorgrim [neutral]: <<mound_empty|Yorgrim says not that one, and the roots stir below. Two short sentences.>>
-> END

~ mound_right
Narrator: <<mound_right|An oak branch grows crooked over this barrow mouth. One sentence.>>
* Dig -> mound_right_dig
* Leave it -> END

~ mound_right_dig
give mm_oak_branch
set mm_oak_taken
Narrator: <<mound_right_dig|Under the packed earth lies a dry oak branch, laid like an offering. One sentence.>>
-> END

~ nightshade
give mm_nightshade
set mm_nightshade_taken
Narrator: <<nightshade|Nightshade, purple and glossy; the party gathers a sprig with care. One sentence.>>
-> END

~ carve_tree
set mm_greenwood_carved
Narrator: <<carve_tree|A hero carves the word Greenwood into the thick bark; the tree shivers. One sentence.>>
-> END

~ clan_study
Narrator: <<clan_study|The stones are cut in a script the party almost knows. One sentence.>>
* [History DC 13] Make out the names -> clan_study_ok | clan_study_plain
* [Investigation DC 13] Compare the stone to the one on Yorgrim's back -> clan_study_ok | clan_study_plain
* Leave it -> END

~ clan_study_ok
set mm_clan_names_learned
Narrator: <<clan_study_ok|The names are Orc names, one clan, and they match the ones on the gravestone Yorgrim drags. One or two sentences.>>
-> END

~ clan_study_plain
Narrator: <<clan_study_plain|The names will not come clear. One short sentence.>>
-> END

~ lantern_statue
Narrator: <<lantern_statue|A hooded figure carries a lantern in one stone hand; at its base a name has begun to etch itself. One or two sentences.>>
-> END
"""

# ------------------------------------------------------------------------------------------------------------------------------------
FILES["descent"] = """# Drafted by Gemini (R19 descent), edited. The sepulcher below: the balefire chamber, the undercroft, the depths, the Stygian Descent, the Harrowing and the Azure Rites.

~ chamber
set mm_chamber_started
set mm_chamber_n = 10
if flag.beacon_crimson == 3
set mm_chamber_n -= 2
elif flag.beacon_crimson == 2
set mm_chamber_n -= 1
endif
if flag.beacon_violet == 3
set mm_chamber_n -= 2
elif flag.beacon_violet == 2
set mm_chamber_n -= 1
endif
if flag.beacon_amber == 3
set mm_chamber_n -= 2
elif flag.beacon_amber == 2
set mm_chamber_n -= 1
endif
if flag.beacon_magenta == 3
set mm_chamber_n -= 2
elif flag.beacon_magenta == 2
set mm_chamber_n -= 1
endif
if flag.beacon_emerald == 3
set mm_chamber_n -= 2
elif flag.beacon_emerald == 2
set mm_chamber_n -= 1
endif
cutscene mm_six_beacons
Narrator: <<chamber_scene|Inside the sepulcher, sconces of every colour burn down a long hall; the far end is collapsed, and grey mist wells through the rubble. Two sentences.>>
if flag.mm_chamber_n == 0
set mm_chamber_done
Narrator: <<chamber_empty|The beacon fires burn every shrouded away before they can rise; the hall is clean and silent. Two sentences.>>
yorgrim [smile]: <<chamber_good|Yorgrim, quietly, says the friends' flames did their work. One short sentence.>>
-> END
endif
Narrator: <<chamber_spill|Shrouded spill up out of the mist at the far end and the coloured flames burn some of them to nothing as they come. Two sentences.>>
combat mm_chamber

~ rubble
Narrator: <<rubble|The collapsed passage is a wall of rubble and mist; clearing it will take time and hard work. One sentence.>>
* [Athletics DC 15] Clear it together -> rubble_ok | rubble_slow
* Take the hour and do it by hand -> rubble_slow

~ rubble_ok
set mm_rubble_cleared
quest maidenmist_dead_rise undercroft
time +10
Narrator: <<rubble_ok|Ten minutes of hauling stone and the passage opens onto a stair going down. One sentence.>>
-> END

~ rubble_slow
set mm_rubble_cleared
quest maidenmist_dead_rise undercroft
time +60
Narrator: <<rubble_slow|An hour of sweat, but the passage opens onto a stair going down. One sentence.>>
-> END

~ maze_hint
set mm_maze_hint_done
Narrator: <<maze_intro|Passages fork in every direction, lined with grinning skulls; the floor trembles under a step here and there. Two sentences.>>
* [Investigation DC 15] Read the way from the skulls and the draughts -> maze_hint_ok | maze_hint_plain
* [Intelligence DC 15] Work it out like a map -> maze_hint_ok | maze_hint_plain
* Wander and hope -> END

~ maze_hint_ok
Narrator: <<maze_hint_ok|Faint candlelight winks in the eye-sockets of certain skulls, trailing off in one direction. One sentence.>>
-> END

~ maze_hint_plain
Narrator: <<maze_hint_plain|The skulls grin and tell nothing. One sentence.>>
-> END

~ crack
Narrator: <<crack|The floor is cracked and trembles under the party. One short sentence.>>
check Dexterity DC 13 -> crack_ok | crack_fall

~ crack_ok
Narrator: <<crack_ok|A breach opens beside the party and they leap clear; a long way down, something shifts. One sentence.>>
-> END

~ crack_fall
damage 3d6 bludgeoning party
Narrator: <<crack_fall|The floor gives way and the party falls sixty feet into darkness. One sentence.>>
move mm_necropolis_depths:from_fall

~ depths_arrive
set mm_depths_seen
Narrator: <<depths_arrive|A huge cavern widened by claws, slimed corpses in the burrows, and a heavy breathing somewhere above. Two sentences.>>
* [if item:mm_lavender and item:mm_lilies and item:mm_nightshade] Mix the herbs into a tincture to throw -> herb_mix
* Hold still and listen -> necrolisk_start

~ wall
set mm_wall_broken
Narrator: <<wall|A cracked wall leaks grey mist; the party spots it and breaks through, and the stair's landing is on the other side. Two sentences.>>
-> END

~ slime
give necrolisk_slime
set mm_slime_taken
set mm_slimes += 1
if flag.mm_slimes >= 4
set mm_slime_all
endif
Narrator: <<slime|A minute's careful work harvests a blob of necrolisk slime into a jar; it clings and eats at the glass. One or two sentences.>>
-> END

~ herb_mix
take mm_lavender
take mm_lilies
take mm_nightshade
set mm_herb_ready
Narrator: <<herb_mix|The party mixes the lavender, lilies and nightshade into a stinking tincture that would make anything gag. One sentence.>>
-> necrolisk_start

~ necrolisk_start
set mm_necrolisk_started
Narrator: <<necrolisk_ambush|The great dragon-thing drops from a high burrow with a hiss. Two sentences.>>
if flag.mm_herb_ready
Narrator: <<necrolisk_herbs|The party flings the stinking tincture and the beast heaves up half its last meal. One sentence.>>
combat mm_necrolisk_sick
endif
combat mm_necrolisk

~ stygian
set mm_stygian_seen
cutscene mm_stygian_descent
Narrator: <<stygian|The Stygian Descent: a spiral stair carved with thousands of wailing faces, sconces burning the sick blue-green of the Shroud. Two sentences.>>
if flag.yorgrim_with_party
yorgrim [afraid]: <<stygian_yorgrim|Yorgrim, thinly, says his light is dimmed here; the voices blame him in Common and in Orc. Two short sentences.>>
endif
check Wisdom DC 15 -> stygian_ok | stygian_fail

~ stygian_ok
Narrator: <<stygian_ok|The party covers its ears and lets the wailing slide. One sentence.>>
-> END

~ stygian_fail
disadvantage checks 2h: the voices on the stair
Narrator: <<stygian_fail|The voices get in and will not be shaken for hours. One sentence.>>
-> END

~ tomb_door
Narrator: <<tomb_door|The doors are carved with a hooded woman holding a lantern. Only Yorgrim can open them. One sentence.>>
yorgrim [weary]: <<tomb_door_yorgrim|Yorgrim, very faint, asks if they are ready. One short sentence.>>
* We are ready -> tomb_open
* Give us a moment -> END

~ tomb_open
set mm_tomb_door_open
quest maidenmist_dead_rise harrowing
Narrator: <<tomb_open|The doors swing in, and the cold of the Shroud rolls out over the floor. One sentence.>>
-> END

~ harrowing
set mm_harrowing_begun
cutscene mm_harrowing
Narrator: <<harrow_a|The tear churns above the hanging platform; Yorgrim, translucent, raises his lantern into it. Two sentences.>>
yorgrim [afraid]: <<harrow_b|Yorgrim, voice breaking, says the voices are saying his name. One short sentence.>>
Narrator: <<harrow_c|The lantern dims, a shrieking tendril wraps him, and a colossal hooded reaper stands in his place, scythe of blue-green fire, a gravestone on its back. Two sentences.>>
set yorgrim_fallen
leave yorgrim
set yorgrim_with_party = 0
combat mm_harrowing

~ harrow_hold
Narrator: <<harrow_hold|Yorgrim stands in the dark under the tear, his lantern raised. One short sentence.>>
-> END

~ azure_rites
if not flag.mm_azure_began
set mm_azure_began
set mm_azure_succ = 0
set mm_azure_miss = 0
Narrator: <<azure_scene|Where the Reaper fell there is only a big ornate lantern on the floor and Yorgrim's faint voice asking the party to perform his own rites. Two sentences.>>
yorgrim [weary]: <<azure_ask|Yorgrim's voice from the lantern asks that they perform his rites and seal the tear. Two short sentences.>>
endif
-> azure_rite

~ azure_rite
if flag.mm_azure_succ >= 6
-> sealed
endif
Narrator: <<azure_prompt|The tear shudders overhead, and the flame in the lantern waits for words. One sentence.>>
* Speak of his care for the dead -> azure_a
* Speak the names on his stone -> azure_b
* Speak of his friends and his hound -> azure_c
* [Arcana DC 13] Work out who is left to honour -> azure_hint | azure_hint_plain

~ azure_hint
Narrator: <<azure_hint|Of the six Fallen, he is the last to honour. One sentence.>>
-> azure_rite

~ azure_hint_plain
Narrator: <<azure_hint_plain|The answer is there, just out of reach. One sentence.>>
-> azure_rite

~ sealed
set shroud_tear_sealed
set fallen_yorgrim_dead
quest maidenmist_dead_rise done
cutscene mm_tear_sealed
Narrator: <<sealed|The lantern blazes white-blue until the world washes out; when it fades the ceiling is whole, the tomb is calm azure light, and every shrouded is gone. Two sentences.>>
yorgrim [smile]: <<sealed_thanks|Yorgrim's last faint thanks from the lantern, then silence. One short sentence.>>
xp milestone
-> END
"""

# The Azure Rites' themes follow the shared template (appended to the descent file).
FILES["descent"] += azure_file()

# ------------------------------------------------------------------------------------------------------------------------------------
FILES["raid"] = """# Drafted by Gemini (R19 raid), edited. Dusk of the Dead, Doris Squire's militia, and Mori Shade's request.

~ alarm
if not flag.mm_raid_seen
set mm_raid_seen
cutscene mm_dusk_of_the_dead
Narrator: <<raid_open|The clock-tower bells ring late in the Dusk Hour; ghasts shriek down Wickermoor's streets, eating whom they catch. Two sentences.>>
endif
doris_squire [angry]: <<raid_doris|Doris Squire, a flat northern burr, fewest words possible: the dead are walking, her militia is stretched, will the strangers help. Two short sentences.>>
-> alarm_menu

~ alarm_menu
* Fight beside the militia -> go_fight
* [if not flag.mm_militia_done] Organise the militia first -> militia_start
* [if flag.mm_nights_delayed < 4] Let the militia hold the lanes tonight -> delay
* [if not flag.mm_inspected] [Medicine DC 10] Look at what the ghasts were -> inspect | inspect_fail
* Not yet -> END

~ inspect
set mm_inspected
doris_squire [neutral]: <<inspect|Doris reports that the dead were buried anything from weeks to centuries ago, and the freshest is Gregor Bolton, who fell off the Mayor's roof. Two short sentences.>>
-> alarm_menu

~ inspect_fail
set mm_inspected
Narrator: <<inspect_fail|The bodies are too far gone to read, and the stench is not helping. One sentence.>>
-> alarm_menu

~ delay
set mm_nights_delayed += 1
set mm_raid_delay = now
set mm_volunteers_lost += 2
doris_squire [weary]: <<delay|Doris says the militia will hold, at a cost; she will not forget who stood aside. Two short sentences.>>
time +600
-> END

~ go_fight
set mm_raid_started
quest maidenmist_dead_rise dusk_of_the_dead
doris_squire [angry]: <<go_fight|Doris orders the militia aside to make room for the strangers; to the square. One short sentence.>>
combat mm_raid

~ aftermath
set mm_raid_done
if flag.mm_nights_delayed >= 1
doris_squire [sad]: <<after_cost|Doris counts the volunteers who did not come back from the nights they waited. Two short sentences.>>
else
doris_squire [smile]: <<after_clean|Doris, dry, says the village lost nobody tonight and she will say it only once. Two short sentences.>>
endif
doris_squire [neutral]: <<after_gregor|Doris notes that the freshest of the dead was Gregor Bolton, who fell off the Mayor's roof, and that Mori Shade will want to hear it. Two short sentences.>>
-> END

~ militia_start
quest doris_militia asked
doris_squire [neutral]: <<militia_start|Doris has four posts and four volunteers, and not enough time: the bell tower, the south bridge, the forge and the funeral lane. Three short sentences.>>
-> post_bell

~ post_bell
Narrator: <<post_bell|The bell tower needs someone who can send signals across the rooftops. One sentence.>>
* Howie Butterman, the quick deputy -> post_bell_right
* Hilda Brom, the huntress -> post_bell_wrong
* Jean Myriel, the smith -> post_bell_wrong
* Siv Harga, the butcher -> post_bell_wrong
* [ends:doris_militia] Leave it to Doris -> militia_quit

~ post_bell_right
set mm_posts_held += 1
Narrator: <<post_bell_right|Howie runs the bells like a conductor and every street hears the warning in time. One sentence.>>
-> post_bridge

~ post_bell_wrong
Narrator: <<post_bell_wrong|The bell rings out of time and the warning arrives late. One sentence.>>
-> post_bridge

~ post_bridge
Narrator: <<post_bridge|The south bridge needs someone with a steady eye and a long bow. One sentence.>>
* Howie Butterman, the quick deputy -> post_bridge_wrong
* Hilda Brom, the huntress -> post_bridge_right
* Jean Myriel, the smith -> post_bridge_wrong
* Siv Harga, the butcher -> post_bridge_wrong

~ post_bridge_right
set mm_posts_held += 1
Narrator: <<post_bridge_right|Hilda picks off what crosses the bridge one by one and nothing gets by. One sentence.>>
-> post_forge

~ post_bridge_wrong
Narrator: <<post_bridge_wrong|The bridge holds, barely, and not for long. One sentence.>>
-> post_forge

~ post_forge
Narrator: <<post_forge|The forge needs someone who can silver blades fast. One sentence.>>
* Howie Butterman, the quick deputy -> post_forge_wrong
* Hilda Brom, the huntress -> post_forge_wrong
* Jean Myriel, the smith -> post_forge_right
* Siv Harga, the butcher -> post_forge_wrong

~ post_forge_right
set mm_posts_held += 1
Narrator: <<post_forge_right|Jean silvers a rack of blades before the first shriek has died, and the militia has teeth. One sentence.>>
-> post_lane

~ post_forge_wrong
Narrator: <<post_forge_wrong|The forge is hot and slow and the blades arrive too late. One sentence.>>
-> post_lane

~ post_lane
Narrator: <<post_lane|The funeral lane needs someone who is not afraid of the dead. One sentence.>>
* Howie Butterman, the quick deputy -> post_lane_wrong
* Hilda Brom, the huntress -> post_lane_wrong
* Jean Myriel, the smith -> post_lane_wrong
* Siv Harga, the butcher -> post_lane_right

~ post_lane_right
set mm_posts_held += 1
Narrator: <<post_lane_right|Siv steps over the corpses as if they were Tuesday, and the lane stands. One sentence.>>
-> militia_done

~ post_lane_wrong
Narrator: <<post_lane_wrong|The lane breaks and the militia falls back to the square. One sentence.>>
-> militia_done

~ militia_done
set mm_militia_done
doris_squire [neutral]: <<militia_done|Doris surveys the four posts and gives her verdict in as few words as possible. Two short sentences.>>
if flag.mm_posts_held >= 3
quest doris_militia done
standing old_ways +1
else
quest doris_militia done
endif
-> END

~ militia_quit
set mm_militia_done
quest doris_militia lost
doris_squire [weary]: <<militia_quit|Doris says she will do it herself, and the village will notice who did not help. Two short sentences.>>
-> END
"""

FILES["mori"] = """# Drafted by Gemini (R19 mori), edited. Mori Shade asks the party to go to Maidenmist.

~ request
set mm_mori_met_again
Narrator: <<mori_scene|Mori Shade stands in the funeral home in her black, white hair loose, a ledger open on the counter. One sentence.>>
mori_shade [sad]: <<mori_request|Mori Shade, grave and stately: the freshest of the ghasts was Gregor Bolton, whom she took to the cemetery just before the party came. She has not heard from Yorgrim or seen Isolde since. Three sentences.>>
mori_shade [weary]: <<mori_request2|Mori: a week ago she found the gates chained, the fog thick, no beacon fires, no lantern. She asks the party to go. Two sentences.>>
* We will go -> accept
* [if gold >= 0] What is at Maidenmist? -> about
* Who is Yorgrim? -> about_yorgrim
* Not yet -> END

~ about
mori_shade [neutral]: <<mori_about|Mori says Maidenmist is a prison over a tear in the mist of death, and that Yorgrim is its sexton. Two sentences.>>
-> request

~ about_yorgrim
mori_shade [smile]: <<mori_yorgrim|Mori says Yorgrim is an old orc ghost who taught her her faith; he drags a stone on his back. Two sentences.>>
-> request

~ accept
set mm_asked
set mm_pyre_lit
quest maidenmist_dead_rise corpse_road
give grave_salt
mori_shade [neutral]: <<mori_accept|Mori gives the party grave salt for their blades and says to hold iron against the mist; she will burn the dead outside town. Three short sentences.>>
-> END

~ hub
mori_shade [neutral]: <<mori_hub|Mori looks up from her ledger and asks how the cemetery goes. One short sentence.>>
* [if not flag.mm_salt_extra] Could we have more grave salt? -> salt
* [if not flag.mm_names_asked] Is there anything else you need done? -> maidenmist/folk:names_start
* [if quest.names_on_stones == asked] About the three unmarked graves -> maidenmist/folk:names_done
* [ends:names_on_stones] [if quest.names_on_stones == asked] Leave the graves unnamed -> maidenmist/folk:names_drop
* That is all -> END

~ salt
if not flag.mm_salt_extra
set mm_salt_extra
give grave_salt
endif
mori_shade [neutral]: <<mori_salt|Mori hands over another pouch of grave salt, says it is all she can spare. Two short sentences.>>
-> END

~ return
set mm_mori_return_told
mori_shade [sad]: <<mori_return|Mori, stately, grieves Yorgrim in her stoic way, and says the cemetery needs a caretaker; maybe herself. Three sentences.>>
if flag.isolde_alive and not flag.isolde_faded
mori_shade [smile]: <<mori_isolde|Mori says Isolde has been her messenger before and will wait for the next sexton. Two sentences.>>
endif
set mm_mori_caretaker
-> END
"""

FILES["folk"] = """# Drafted by Gemini (R19 folk), edited. Tobias Dibbs, Hester Bolton, the grammar headstone, the Epitaph Competition and Names on Stones.

~ dibbs
Narrator: <<dibbs_scene|In the funeral home a cheerful lad in an apron sharpens a spade as if for a picnic. One sentence.>>
tobias_dibbs [smile]: <<dibbs_hello|Tobias Dibbs, Mori's apprentice, relentlessly cheerful and practical: he is delighted to meet people with a good use for a spade. Two sentences.>>
* What do you do here? -> dibbs_job
* [if not flag.mm_epitaph_asked] Is there anything we can help with? -> dibbs_contest
* Goodbye -> END

~ dibbs_job
tobias_dibbs [neutral]: <<dibbs_job|Tobias explains with horrifying practicality what a gravedigger's apprentice does all day. Two sentences.>>
-> dibbs

~ dibbs_contest
set mm_epitaph_asked
quest epitaph_competition asked
tobias_dibbs [smile]: <<dibbs_contest|Tobias has collected the dead's own epitaphs; they are too honest; he needs someone to judge a winner, over in the Cremation Gardens. Three short sentences.>>
-> END

~ epitaph_plaque_a
set mm_epitaph_a_read
Narrator: <<epitaph_a|A brick plaque reads an epitaph the dead wrote for themselves; it is blunt and funny. One sentence.>>
-> END

~ epitaph_plaque_b
set mm_epitaph_b_read
Narrator: <<epitaph_b|A plaque with an epitaph that complains about the neighbours. One sentence.>>
-> END

~ epitaph_plaque_c
set mm_epitaph_c_read
Narrator: <<epitaph_c|A plaque with an epitaph that is a very honest confession. One sentence.>>
-> END

~ epitaph_judge
Narrator: <<epitaph_judge|Tobias waits by the fountain with a ribbon and a pencil, ready for a verdict. One sentence.>>
* The one that complained about the neighbours -> epitaph_win_b
* The blunt one -> epitaph_win_a
* The honest confession -> epitaph_win_c
* [if flag.mm_epitaph_a_read or flag.mm_epitaph_b_read or flag.mm_epitaph_c_read] A tie, honestly -> epitaph_tie
* [ends:epitaph_competition] They are all too honest. Call it off -> epitaph_off

~ epitaph_win_a
quest epitaph_competition done
set mm_epitaph_winner = 1
gold +25
tobias_dibbs [smile]: <<epitaph_win_a|Tobias delighted: the blunt one wins; he pins the ribbon and the dead rustle approval. Two short sentences.>>
-> END

~ epitaph_win_b
quest epitaph_competition done
set mm_epitaph_winner = 2
gold +25
tobias_dibbs [smile]: <<epitaph_win_b|Tobias delighted: the neighbour one wins; the neighbours, he notes, will be furious. Two short sentences.>>
-> END

~ epitaph_win_c
quest epitaph_competition done
set mm_epitaph_winner = 3
gold +25
tobias_dibbs [smile]: <<epitaph_win_c|Tobias delighted: the confession wins; he promises to have it carved before anyone can reconsider. Two short sentences.>>
-> END

~ epitaph_tie
quest epitaph_competition done
set mm_epitaph_winner = 4
tobias_dibbs [neutral]: <<epitaph_tie|Tobias accepts a tie with the air of a man writing three more plaques. Two short sentences.>>
-> END

~ epitaph_off
quest epitaph_competition lost
tobias_dibbs [sad]: <<epitaph_off|Tobias folds his ribbon and says the dead will take it personally; by morning the plaques have scraped their own words off. Two short sentences.>>
-> END

~ hester
Narrator: <<hester_scene|Hester Bolton stands in the square with her arms folded and her chin up. One sentence.>>
hester_bolton [angry]: <<hester_1|Hester Bolton, annoyed: her husband Gregor is now a ghast, and he still owes the landlord rent. Two sentences.>>
* We are sorry for your loss -> hester_loss
* [if gold >= 5] Pay the rent for her -> hester_rent
* Where is Gregor now? -> hester_where
* Goodbye -> END

~ hester_loss
hester_bolton [weary]: <<hester_loss|Hester says her loss is the rent; the husband she can forgive. Two short sentences.>>
-> hester

~ hester_rent
gold -5
hester_bolton [smile]: <<hester_rent|Hester takes the coins with the dignity of a woman collecting a debt and tells Gregor will hear of it. Two short sentences.>>
set mm_hester_paid
-> END

~ hester_where
hester_bolton [neutral]: <<hester_where|Hester says Gregor is wherever the ghasts are, and the Mayor's roof is to blame. Two short sentences.>>
-> hester

~ grammar_stone
Narrator: <<grammar_stone|At the gate stands a headstone in a prissy hand: HERE LYES A PEDANT, WHO CORRECTS YOU. One or two sentences.>>
* Read the epitaph aloud -> grammar_read
* Misspell something on purpose -> grammar_correct
* Leave -> END

~ grammar_read
Narrator: <<grammar_read|The headstone clears its throat and corrects the party's pronunciation. One sentence.>>
-> END

~ grammar_correct
Narrator: <<grammar_correct|The headstone sighs through its entire carved face and fixes the spelling in the air. One sentence.>>
-> END

~ names_start
set mm_names_asked
quest names_on_stones asked
mori_shade [neutral]: <<names_start|Mori has three unmarked graves in the Potter's Field and a ledger of villagers who lost someone; match the names, give each grave its stone. Three short sentences.>>
-> END

~ names_graves
Narrator: <<names_graves|Three plain posts stand in a row, each with a small token left at its foot. One sentence.>>
* [Investigation DC 12] Study the first token -> names_a | names_a_plain
* [Medicine DC 12] Study the second token -> names_b | names_b_plain
* [History DC 12] Study the third token -> names_c | names_c_plain
* Ask Mori to place them by the ledger -> names_mori
* Leave it -> END

~ names_a
set mm_names_a
Narrator: <<names_a|The first token is a corner of a baker's apron; a grave of Holly Aster's mother. One sentence.>>
-> names_graves

~ names_a_plain
Narrator: <<names_a_plain|The first token is a scrap of cloth and could be anyone's. One sentence.>>
-> names_graves

~ names_b
set mm_names_b
Narrator: <<names_b|The second token is a child's wooden toy; a grave of a Lockwood child Old Rusty remembers. One sentence.>>
-> names_graves

~ names_b_plain
Narrator: <<names_b_plain|The second token is a toy, worn smooth; it says nothing of whose. One sentence.>>
-> names_graves

~ names_c
set mm_names_c
Narrator: <<names_c|The third token is a thimble stamped with a tailor's mark; a grave of someone Thomasin Ardor lost. One sentence.>>
-> names_graves

~ names_c_plain
Narrator: <<names_c_plain|The third token is a thimble with no mark you can read. One sentence.>>
-> names_graves

~ names_mori
mori_shade [neutral]: <<names_mori|Mori reads the ledger and matches all three tokens to names, and says each should hear of it in person. Two short sentences.>>
set mm_names_a
set mm_names_b
set mm_names_c
-> names_graves

~ names_tell_holly
if flag.mm_names_a
set mm_names_told_a
Narrator: <<names_holly|Holly Aster sets down her tray and says her mother's name aloud for the first time in years. One sentence.>>
endif
-> END

~ names_tell_rusty
if flag.mm_names_b
set mm_names_told_b
Narrator: <<names_rusty|Old Rusty stops sweeping and says a child's name that nobody has said on the hill since. One sentence.>>
endif
-> END

~ names_tell_thomasin
if flag.mm_names_c
set mm_names_told_c
Narrator: <<names_thomasin|Thomasin Ardor holds the thimble in both hands and does not say anything for a long time. One sentence.>>
endif
-> END

~ names_done
if flag.mm_names_told_a and flag.mm_names_told_b and flag.mm_names_told_c
quest names_on_stones done
mori_shade [smile]: <<names_done|Mori says the three graves have names and the field will remember. Two short sentences.>>
else
mori_shade [neutral]: <<names_wait|Mori says some of the three still wait to be told. One short sentence.>>
endif
-> END

~ names_drop
quest names_on_stones lost
mori_shade [sad]: <<names_drop|Mori says the posts will stay blank, and the field will keep forgetting. Two short sentences.>>
-> END
"""

FILES["epilogue"] = """# Drafted by Gemini (R19 epilogue), edited. After the Chained Reaper: Isolde's Walk, Adela, Golub's move, Doris.

~ walk_ask
quest isolde_walk asked
Narrator: <<walk_ask|Isolde stands in the doorway of the sepulcher and tugs the hem of a coat, turning to look at the sites and back. One or two sentences.>>
* Walk with her -> walk_yes
* Not now, old girl -> walk_no

~ walk_yes
set mm_isolde_walk_started
Narrator: <<walk_yes|Isolde sets off down the nearest path, looking back every few steps to see the party follows. One sentence.>>
-> END

~ walk_no
Narrator: <<walk_no|Isolde lowers herself to the step and watches the path with her ears flat. One sentence.>>
* Change your mind -> walk_yes
* [ends:isolde_walk] Leave her -> walk_leave

~ walk_leave
set mm_isolde_walk_gone
quest isolde_walk gone_quiet
Narrator: <<walk_leave|Isolde does not follow. By morning her lantern has gone dark by the door. One sentence.>>
-> END

~ walk_crimson
set mm_walk_crimson
set mm_isolde_walk_sites += 1
Narrator: <<walk_crimson|Isolde noses at the ash of the Crimson brazier and finds a small carved horse, hidden there by Yorgrim. One sentence.>>
-> END

~ walk_violet
set mm_walk_violet
set mm_isolde_walk_sites += 1
Narrator: <<walk_violet|Isolde noses at the foot of the Violet fountain and uncovers a mask of white bone, left there by Yorgrim. One sentence.>>
-> END

~ walk_emerald
set mm_walk_emerald
set mm_isolde_walk_sites += 1
Narrator: <<walk_emerald|Isolde noses under the Emerald tree roots and finds a sprig of dried greenery tied with a thread, left there by Yorgrim. One sentence.>>
-> END

~ walk_end
set mm_isolde_walk_done
quest isolde_walk done
give yorgrims_letter
Narrator: <<walk_end|At the Shadestone stones Isolde noses up a packet wrapped in oilcloth: Yorgrim's letter to Mori. One sentence.>>
-> END

~ adela
set mm_epilogue_adela
adela_druskenvald [smile]: <<adela_1|Lady Adela Druskenvald, transatlantic, thanks the party for the cemetery and says she thought it had been averted for good. Two sentences.>>
adela_druskenvald [sly]: <<adela_2|Adela adds, lightly, that she has seen something in the tower clock; pigeons. One short sentence.>>
-> END

~ golub_tease
set mm_epilogue_golub
Narrator: <<golub_tease|On the roof of the post office a hundred pigeons shift all together, and Theodora Mayville watches the party pass with violet eyes. One or two sentences.>>
-> END

~ weston
set mm_epilogue_weston
weston_murdoch [smile]: <<weston_1|Weston Murdoch, revival-preacher warmth, says the Brightsingers heard the bells and will sing for the dead tonight. Two sentences.>>
-> END

~ doris_after
set mm_epilogue_doris
doris_squire [neutral]: <<doris_after|Doris, in as few words as possible, says the village is quiet and she is grateful. Two short sentences.>>
-> END
"""

ENTER = {
    "mm_gate": "the Maidenmist gate: a fifteen-foot iron fence running into fog both ways, a bent gate between two hooded reapers",
    "mm_corpse_road": "the Corpse Road: a wide cobbled hearse road between grave markers, mist at its densest",
    "mm_sepulcher": "the sepulcher's hill: a cracked moss-grown tomb with huge doors and six iron sconces, seven paved paths, blue-green wisps in grey fog",
    "mm_highborn_crypts": "the Highborn Crypts: polished dark stone crypts, leering gargoyles, bats wheeling, a brazier of dull red coals",
    "mm_crypt_below": "a crypt below: stone sarcophagi, roosting bats, cold air",
    "mm_cremation_gardens": "the Cremation Gardens: brick memorial walks in heavy rain, clay urns, fountains, a bell tolling slow",
    "mm_potters_field": "the Potter's Field: plain wooden posts over nameless graves, carrion birds, amber lanterns drifting in fog",
    "mm_mausoleum_lanes": "the Mausoleum Lanes: a boggy city of ivy-grown vaults, murky water in the cracks, acrid muck",
    "mm_burial_mounds": "the Burial Mounds: tall round mounds, twisted trees with faces in their trunks, bright apples on hand-shaped branches",
    "mm_shadestone_sanctuary": "the Shadestone Sanctuary: standing stones cut with Orc names, an azure beacon on a small ziggurat, a stillness the rest of the cemetery has lost",
    "mm_kings_rest": "King's Rest: a palatial barrow, a giant armoured king raising a sword through fog, a war in the mist at its doors",
    "mm_balefire_chamber": "the Balefire Chamber: a sixty-foot hall of coloured fire sconces, a collapsed passage at the far end leaking grey mist",
    "mm_undercroft": "the Undercroft Catacombs: earthen walls lined with rows of skulls, mist pooled on the floor, trembling floors",
    "mm_necropolis_depths": "the Necropolis Depths: a huge cavern widened by claws, slimed corpses in burrows, glowing ooze",
    "mm_tomb": "the Tomb of the Shrouded: a cavern of blue-green balefire, chained three-pronged platforms, a tear in the air above them",
    "mm_gravestones_a": "the Endless Gravestones: rolling hills of grave markers a few feet apart, something always walking between them",
    "mm_gravestones_b": "the Endless Gravestones: rolling hills of grave markers a few feet apart, something always walking between them",
}
FILES["narrator/maidenmist"] = "# Drafted by Gemini (R19 narrator), edited. Arrival lines for Maidenmist's places.\n\n" + "\n".join(
    f"~ enter:{k}\n| <<enter_{k}|The party arrives at {v}. The Narrator's first impression in one or two sentences, concrete senses.>>\ncooldown 0\n" for k, v in ENTER.items())

PLACEHOLDER = re.compile(r"<<([a-z0-9_]+)\|([^>]*)>>")
