extends TestCase
## R26, Moonfall (optional, levels 13 to 20): the Vagrant's offer after the ritual, the nights clock (13 nights, a day won back for every Old Fear, the
## three-night rewind, the count at the Witching Hour), the level cap raised only once Moonfall starts, all eight Old Fears (the hook-giver and the clue-giver,
## two ways to find each, its weakness, the fight scaled to the party's level, the aftermath), Kehlenn's last offer (refused or accepted), the ride out, the
## moon's impact at zero, and the four side quests (Last Night in Wickermoor, The Vagrant's Ride Out, What the Moon Keeps, The Last Verse). Each scenario plays
## the places' own data the way test_r22_paths does: a person is only talked to while their entry's `when` holds, a fight a conversation starts is won as the
## place records it, and dice are high (every check lands) or low (none does) as the test says. Every failable quest has a failure path here.

const GAME := preload("res://world/game_root.gd")

const FEARS: Array[Dictionary] = [
	{"key": "headsman", "n": 1, "file": "headsman", "outpost": "mf_covered_bridge", "lair": "mf_covered_bridge", "level": 13, "quest": "mf_headsman", "prev": "", "a1": "Read the town's old records", "b1": "Slip in among the mob unseen", "w1": "Search the riverbank mud for the skull", "a_plain": "Walk the farms asking, however long it takes", "item": "mf_headsman_skull", "weak": "mf_headsman_weak", "reward": "axe_of_the_galloping_headsman", "dc": 17, "hook_npc": "mf_osric_farmer", "clue_npc": "mf_mob_captain"},
	{"key": "worm", "n": 2, "file": "worm", "outpost": "mf_moonsong_rift", "lair": "mf_moonsong_rift", "level": 14, "quest": "mf_worm", "prev": "old_fear_headsman", "a1": "Decipher the black obelisks", "b1": "Pretend to join the Worm's order", "w1": "Work out the constellations from the obelisks", "a_plain": "Copy every carving and puzzle at them for hours", "item": "mf_star_chart", "weak": "mf_worm_weak", "reward": "eye_of_the_white_worm", "dc": 17, "hook_npc": "mf_pell_fisher", "clue_npc": "mf_lake_cultist"},
	{"key": "tall_man", "n": 3, "file": "tall_man", "outpost": "mf_tall_man_palace", "lair": "mf_tall_man_palace", "level": 15, "quest": "mf_tall_man", "prev": "old_fear_worm", "a1": "Hear the crone's tale and test it against the lore", "b1": "Stalk the woods and lure him with fear", "w1": "Learn the steps of the lost court dance", "a_plain": "Sit by her fire all night and let her talk it out", "item": "mf_court_notes", "weak": "mf_tall_man_weak", "reward": "hook_of_the_tall_man", "dc": 18, "hook_npc": "mf_bram_logger", "clue_npc": "mf_hesper_crone"},
	{"key": "titan", "n": 4, "file": "titan", "outpost": "mf_howlers_peaks", "lair": "mf_howlers_peaks", "level": 16, "quest": "mf_titan", "prev": "old_fear_tall_man", "a1": "Read the old rune stones on the slope", "b1": "Track the Titan along the ridges", "w1": "Transcribe the maker's glyph from the stones", "a_plain": "Copy every rune on the slope by hand", "item": "mf_glyph_stone", "weak": "mf_titan_weak", "reward": "runestone_of_the_wild_titan", "dc": 18, "hook_npc": "mf_jory_miner", "clue_npc": "mf_grizzle_hunter"},
	{"key": "barrow", "n": 5, "file": "barrow", "outpost": "mf_barrow_catacombs", "lair": "mf_barrow_catacombs", "level": 17, "quest": "mf_barrow", "prev": "old_fear_titan", "a1": "Exhume the oldest graves for the way in", "b1": "Persuade the ghost he is free to go", "w1": "Copy the king's runes onto a blade", "a_plain": "Dig every grave on the hill until the stair is found", "item": "mf_inscribed_blade", "weak": "mf_barrow_weak", "reward": "crown_of_the_barrow_king", "dc": 19, "hook_npc": "solomon_roderick", "clue_npc": "mf_aldous_ghost"},
	{"key": "leviathan", "n": 6, "file": "leviathan", "outpost": "mf_jinxed_bayou", "lair": "mf_jinxed_bayou", "level": 18, "quest": "mf_leviathan", "prev": "old_fear_barrow", "a1": "Bait the Leviathan with the sacred serpent", "b1": "Intimidate him into telling where it was made", "w1": "Persuade him to bless an idol for you", "a_plain": "Drag bait through the swamp and see what follows", "item": "mf_blessed_idol", "weak": "mf_leviathan_weak", "reward": "tooth_of_the_jinxed_leviathan", "dc": 19, "hook_npc": "mf_nadine_bayou", "clue_npc": "mf_jack_follower"},
	{"key": "dusk", "n": 7, "file": "dusk", "outpost": "mf_webwoods", "lair": "mf_dusk_mother_hut", "level": 19, "quest": "mf_dusk", "prev": "old_fear_leviathan", "a1": "Piece together the children's rhymes", "b1": "Follow the spiders through the Webwoods", "w1": "Read the toys for the children's memories", "a_plain": "Gather every rhyme the children ever sang, however long it takes", "item": "mf_children_toys", "weak": "mf_dusk_weak", "reward": "bell_of_the_dusk_mother", "dc": 20, "hook_npc": "mf_ysolde_teen", "clue_npc": "mf_pennywhistle_nurse"},
	{"key": "behemoth", "n": 8, "file": "behemoth", "outpost": "mf_rowans_volcano", "lair": "mf_rowans_volcano", "level": 20, "quest": "mf_behemoth", "prev": "old_fear_dusk", "a1": "Learn the truth of Rowan's wickedness", "b1": "Find Rowan's sister's descendant in the camp", "w1": "Persuade Rowan to go willingly into the lava", "a_plain": "Gather every tale of Rowan, however long it takes", "item": "mf_rowan_locket", "weak": "mf_behemoth_weak", "reward": "hide_of_the_brimstone_behemoth", "dc": 20, "hook_npc": "mf_ash_cultist", "clue_npc": "mf_rowan_spirit"}
]


## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll 1: no check lands.
class LowDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(1)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var st: StoryState
var dice: DiceRoller = HighDice.new()
var fights: Array[String] = []


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", st.location)


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


func _entry(list_key: String, id_key: String, id: String) -> Dictionary:
	for e: Variant in _loc().get(list_key, []):
		if str((e as Dictionary).get(id_key, "")) == id:
			return e as Dictionary
	return {}


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out). Returns what the
## conversation ended in; a combat it ends in is won as the place records it and a move is made.
func _play(ref: String, picks: Array[String] = []) -> Dictionary:
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	for i in 900:
		match str(b["kind"]):
			"end":
				break
			"options":
				var opts := b["options"] as Array
				var pick := opts.size() - 1
				if not left.is_empty():
					var want := str(left.pop_front())
					pick = -1
					for j in opts.size():
						if bool((opts[j] as Dictionary)["enabled"]) and str((opts[j] as Dictionary)["text"]).contains(want):
							pick = j
							break
					if pick < 0:
						fail("%s: no option '%s' among %s" % [ref, want, opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]) + ("" if bool((o as Dictionary)["enabled"]) else " (off)"))])
						return {}
				b = r.choose(pick)
			"guidance":
				b = r.answer_guidance(-1)
			"pick_member":
				b = r.pick_member(0)
			_:
				b = r.next()
	assert_eq(str(b["kind"]), "end", "%s ends" % ref)
	assert_true(left.is_empty(), "%s: picks left over %s" % [ref, left])
	var combat := str(b.get("combat", ""))
	if combat != "":
		_win(combat)
	var move := b.get("move", {}) as Dictionary
	if not move.is_empty():
		_arrive(str(move["location"]))
	return b


## The encounter `id` of this place won, as LocationFights._end_encounter records a victory (spec_for's pick).
func _win(id: String) -> void:
	var spec := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == id:
			spec = e as Dictionary
	assert_true(not spec.is_empty(), "%s has the fight %s" % [st.location, id])
	if spec.is_empty():
		return
	fights.append(id)
	(st.loc_state(st.location)["encounters"] as Dictionary)[id] = true
	if spec.has("flag"):
		st.set_flag(str(spec["flag"]))
	if spec.has("quest"):
		st.set_quest_stage(str((spec["quest"] as Dictionary)["id"]), str((spec["quest"] as Dictionary)["stage"]))


func _arrive(id: String) -> void:
	st.location = id
	assert_true(not _loc().is_empty(), "%s is a place" % id)


func _flag(id: String) -> bool:
	return bool(st.get_flag(id))


func _n(id: String) -> int:
	return int(st.get_flag(id, 0))


## A party of the stated level. The pregens' build plans stop at 13 (the main story's cap), and levelling a hero by hand needs the player's choices
## (an Ability Score Improvement, spells), so a hero past 13 gets stand-in level entries: enough for the story's `level >= n` conditions, which count them.
func _party(level: int) -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, mini(level, 13))
		ch.finish_long_rest()
		var levels := ch.build["levels"] as Array
		while ch.character_level() < level:
			levels.append((levels.back() as Dictionary).duplicate(true))
		st.party.append(ch)


func before_each() -> void:
	_party(13)
	fights.clear()
	dice = HighDice.new()
	st.location = "wickermoor_village"


func after_each() -> void:
	GameState.reset()


## Moonfall begun, the first n Old Fears already dead (each as the aftermath leaves the counters).
func _hunt(slain: int) -> void:
	st.set_flag("kehlenn_bound")
	st.set_flag("moonfall_started")
	st.set_flag("moonfall_begun")
	st.set_flag("moonfall_clock", st.total_minutes())
	st.set_flag("moonfall_credit", slain)
	st.set_flag("moonfall_nights_left", 13 + slain)
	st.set_flag("old_fears_slain", slain)
	for i in slain:
		st.set_flag("old_fear_" + str((FEARS[i] as Dictionary)["key"]))
	st.set_quest_stage("moonfall", "hunt")


# ---- the hook, the clock and the level cap ----------------------------------------------------------------------------------------

func test_the_vagrant_offers_moonfall_only_once_the_moon_has_bound_kehlenn() -> void:
	var offer := {}
	for n: Variant in _loc()["npcs"]:
		if str((n as Dictionary).get("dialogue", "")) == "moonfall/vagrant:offer":
			offer = n as Dictionary
	assert_true(not offer.is_empty(), "the village has the Vagrant's offer")
	assert_false(_holds(offer["when"]), "no offer until the ritual has bound her (a missing flag is false)")
	st.set_flag("kehlenn_bound")
	assert_true(_holds(offer["when"]), "the offer once Kehlenn is bound")
	st.set_flag("moonfall_started")
	assert_false(_holds(offer["when"]), "the offer is taken once")


func test_not_yet_leaves_the_offer_open() -> void:
	st.set_flag("kehlenn_bound")
	_play("moonfall/vagrant:offer", ["Not yet"])
	assert_false(_flag("moonfall_started"))
	assert_eq(st.quest_stage("moonfall"), "shriek", "the shriek is in the journal")


func test_accepting_starts_the_clock_and_lifts_the_level_cap_from_13_to_20() -> void:
	assert_eq(st.level_cap(), 13, "the main story ends at 13")
	st.set_flag("kehlenn_bound")
	_play("moonfall/vagrant:offer", ["take up the hunt"])
	assert_true(_flag("moonfall_started") and _flag("moonfall_begun"))
	assert_eq(_n("moonfall_nights_left"), 13)
	assert_eq(_n("moonfall_credit"), 0)
	assert_eq(st.quest_stage("moonfall"), "hunt")
	assert_eq(st.level_cap(), 20, "the cap rises to 20 once Moonfall starts, and not before")
	assert_eq(st.location, "mf_round", "the Vagrant takes the party to the Round")
	assert_eq(st.days_since("moonfall_clock"), 0)


func test_the_journal_shows_the_nights_left_and_the_fears_slain() -> void:
	_hunt(0)
	var found := false
	for q: Variant in QuestLog.journal(st):
		if str((q as Dictionary)["id"]) == "moonfall":
			var txt := " ".join((q as Dictionary)["objectives"] as Array)
			found = txt.contains("Nights left: 13") and txt.contains("Old Fears slain: 0 of 8")
	assert_true(found, "the journal's objectives read Nights left: 13 and Old Fears slain: 0 of 8")


func test_the_nights_clock_counts_down_at_the_witching_hour() -> void:
	_hunt(0)
	Schedule.use([])
	Schedule.catch_up(st, "mf_round")
	for night in 5:
		st.advance_minutes(24 * 60)
		Schedule.catch_up(st, "mf_round")
	assert_eq(st.days_since("moonfall_clock"), 5)
	assert_eq(_n("moonfall_nights_left"), 8, "13 nights, five gone")


func test_a_long_wait_counts_every_night_once() -> void:
	_hunt(0)
	Schedule.use([])
	Schedule.catch_up(st, "mf_round")
	st.advance_minutes(4 * 24 * 60)
	Schedule.catch_up(st, "mf_round")
	assert_eq(_n("moonfall_nights_left"), 9, "four days gone in one wait: 13 - 4")


func test_each_kill_wins_a_night_back_and_the_clock_follows_it() -> void:
	_hunt(0)
	Schedule.use([])
	Schedule.catch_up(st, "mf_round")
	st.advance_minutes(2 * 24 * 60)
	Schedule.catch_up(st, "mf_round")
	assert_eq(_n("moonfall_nights_left"), 11)
	st.set_flag("moonfall_credit", 1)
	st.set_flag("moonfall_nights_left", 12)
	st.advance_minutes(24 * 60)
	Schedule.catch_up(st, "mf_round")
	assert_eq(_n("moonfall_nights_left"), 11, "one night more with a kill behind: 13 + 1 - 3")


func test_the_clock_stops_at_zero_and_the_impact_ends_the_hunt() -> void:
	_hunt(0)
	Schedule.use([])
	Schedule.catch_up(st, "mf_round")
	for night in 16:
		st.advance_minutes(24 * 60)
		Schedule.catch_up(st, "mf_round")
	assert_eq(_n("moonfall_nights_left"), 0, "it never goes below zero")
	st.location = "mf_round"
	var imp := {}
	for p: Variant in _loc()["props"]:
		if str((p as Dictionary).get("call", "")) == "moonfall/moon:impact":
			imp = p as Dictionary
	assert_true(not imp.is_empty(), "the Round has the moon's impact")
	assert_true(_holds(imp["call_when"]), "the impact plays when the nights are gone")
	var b := _play("moonfall/moon:impact")
	assert_true(bool(b.get("end_game")), "the moon hitting ends the game (the `moonfall` ending reads moonfall_nights_left <= 0)")
	assert_eq(st.quest_stage("moonfall"), "lost")
	assert_true(_holds("flag.moonfall_started and flag.moonfall_nights_left <= 0"), "the ending's own condition holds")


func test_the_impact_waits_while_there_is_time_and_never_for_a_party_that_fled() -> void:
	_hunt(0)
	st.location = "mf_round"
	var imp := {}
	for p: Variant in _loc()["props"]:
		if str((p as Dictionary).get("call", "")) == "moonfall/moon:impact":
			imp = p as Dictionary
	assert_false(_holds(imp["call_when"]))
	st.set_flag("moonfall_nights_left", 0)
	st.set_flag("moonfall_fled")
	assert_false(_holds(imp["call_when"]), "the last train out is its own ending")


func test_the_rewind_adds_three_nights_once_for_a_village_that_was_saved() -> void:
	_hunt(0)
	_arrive("mf_round")
	_play("moonfall/vagrant:hub_start", ["turning time back"])
	assert_eq(_n("moonfall_nights_left"), 16)
	assert_eq(_n("moonfall_credit"), 3)
	assert_true(_flag("moonfall_rewound"))
	assert_true(not _entry_has_option("moonfall/vagrant:hub_menu", "turning time back"), "it is offered once")


func _entry_has_option(ref: String, text: String) -> bool:
	var r := DialogueRunner.new(st, dice)
	r.start(ref)
	var b := r.next()
	for i in 20:
		if str(b["kind"]) == "options":
			for o: Variant in b["options"]:
				if bool((o as Dictionary)["enabled"]) and str((o as Dictionary)["text"]).contains(text):
					return true
			return false
		if str(b["kind"]) == "end":
			return false
		b = r.next()
	return false


func test_the_rewind_has_a_second_way_when_too_many_were_lost_at_the_vigil() -> void:
	_hunt(0)
	st.set_flag("vigil_deaths", 15)
	_arrive("mf_round")
	_play("moonfall/vagrant:hub_start", ["turning time back"])
	assert_eq(_n("moonfall_nights_left"), 13, "too many lost: the tune needs more voices")
	assert_false(_flag("moonfall_rewound"))
	st.give_item("jericho_banjo", 1)
	_play("moonfall/vagrant:hub_start", ["turning time back"])
	assert_eq(_n("moonfall_nights_left"), 16, "Jericho's banjo makes up the difference")
	assert_true(_flag("moonfall_rewound"))


# ---- the Old Fears -----------------------------------------------------------------------------------------------------------------

func test_the_regions_open_in_the_books_order() -> void:
	var travel := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	var by_id := {}
	for p: Variant in travel["places"]:
		by_id[str((p as Dictionary)["id"])] = p
	_hunt(0)
	assert_true(_holds((by_id["mf_covered_bridge"] as Dictionary)["when"]), "the Headsman's farmland first")
	assert_false(_holds((by_id["mf_moonsong_rift"] as Dictionary)["when"]), "the lake waits for the Headsman")
	st.set_flag("old_fear_headsman")
	assert_true(_holds((by_id["mf_moonsong_rift"] as Dictionary)["when"]))
	assert_false(_holds((by_id["mf_tall_man_palace"] as Dictionary)["when"]))
	for f: Dictionary in FEARS:
		st.set_flag("old_fear_" + str(f["key"]))
	for id: String in ["mf_covered_bridge", "mf_moonsong_rift", "mf_tall_man_palace", "mf_howlers_peaks", "mf_barrow_catacombs", "mf_jinxed_bayou", "mf_webwoods", "mf_rowans_volcano"]:
		assert_true(_holds((by_id[id] as Dictionary)["when"]), "%s is open once the hunt is through" % id)
	var hours := 0
	for r: Variant in travel["roads"]:
		if str((r as Dictionary)["id"]).begins_with("mf_to_"):
			hours += int((r as Dictionary)["hours"])
	assert_true(hours <= 12 * 24, "the whole chain of regions is under twelve days' travel, so thirteen nights is a real but fair plan (%d hours)" % hours)


func _meet_fear(f: Dictionary) -> void:
	_party(int(f["level"]))
	dice = HighDice.new()
	_hunt(int(f["n"]) - 1)


func _find_and_arm(f: Dictionary, weakness: bool) -> void:
	var file := "moonfall/" + str(f["file"])
	_arrive(str(f["outpost"]))
	_play(file + ":arrive")
	_play(file + ":hook", ["Ask how to find it", str(f["a1"])])
	assert_true(_flag("mf_%s_found" % f["key"]), "found the lair")
	assert_eq(st.quest_stage(str(f["quest"])), "trail")
	if weakness:
		_play(file + ":clue", ["Ask what could hurt it", str(f["w1"])])
		assert_true(_flag(str(f["weak"])), "the weakness is prepared")
		assert_true(st.party_has_item(str(f["item"])))
		assert_eq(st.quest_stage(str(f["quest"])), "ready")


func test_every_fear_is_met_found_fought_and_leaves_its_aftermath() -> void:
	for f: Dictionary in FEARS:
		_meet_fear(f)
		var file := "moonfall/" + str(f["file"])
		_arrive(str(f["outpost"]))
		var hook := {}
		for n: Variant in _loc()["npcs"]:
			if str((n as Dictionary).get("dialogue", "")) == file + ":hook":
				hook = n as Dictionary
		assert_true(not hook.is_empty(), "%s: the hook-giver is in %s" % [f["key"], f["outpost"]])
		assert_true(_holds(hook["when"]), "%s: the hook-giver is there once the previous Fear is dead" % f["key"])
		_find_and_arm(f, false)
		_arrive(str(f["lair"]))
		var lair := _entry("props", "id", str(f["key"]) + "_lair")
		assert_true(not lair.is_empty() and _holds(lair["when"]), "%s: the lair opens once found" % f["key"])
		var b := _play(file + ":lair", ["Go in and face it"])
		assert_eq(str(b["combat"]), "mf_%s_full" % f["key"], "%s: a party of the expected level meets the full court" % f["key"])
		assert_true(_flag("old_fear_" + str(f["key"])), "%s: slain" % f["key"])
		var slain := _n("old_fears_slain")
		var nights := _n("moonfall_nights_left")
		var credit := _n("moonfall_credit")
		_play(file + ":aftermath")
		assert_eq(_n("old_fears_slain"), slain + 1, "%s: one more Old Fear slain" % f["key"])
		assert_eq(_n("moonfall_nights_left"), nights + 1, "%s: the moon pauses a day" % f["key"])
		assert_eq(_n("moonfall_credit"), credit + 1)
		assert_eq(st.quest_stage(str(f["quest"])), "slain")
		assert_true(st.party_has_item(str(f["reward"])), "%s: the heirloom" % f["key"])
		if int(f["n"]) < 8:
			assert_eq(st.quest_stage("moonfall"), "hunt")
		else:
			assert_eq(st.quest_stage("moonfall"), "one_last_choice")
			assert_eq(st.location, "mf_last_hill", "the last Fear's aftermath climbs to the hill")


func test_a_party_below_the_expected_level_meets_a_lighter_court() -> void:
	for f: Dictionary in FEARS:
		if int(f["level"]) <= 13:
			continue
		_party(13)
		dice = HighDice.new()
		_hunt(int(f["n"]) - 1)
		_find_and_arm(f, false)
		_arrive(str(f["lair"]))
		var b := _play("moonfall/" + str(f["file"]) + ":lair", ["Go in and face it"])
		assert_eq(str(b["combat"]), "mf_%s_light" % f["key"], "%s: level 13 meets the light variant" % f["key"])


func test_the_weakness_changes_the_fight() -> void:
	for f: Dictionary in FEARS:
		_meet_fear(f)
		_find_and_arm(f, true)
		_arrive(str(f["lair"]))
		var b := _play("moonfall/" + str(f["file"]) + ":lair", ["Go in and face it"])
		assert_eq(str(b["combat"]), "mf_%s_weak" % f["key"], "%s: the weakened fight" % f["key"])
		var full := _entry("encounters", "id", "mf_%s_full" % f["key"])
		var weak := _entry("encounters", "id", "mf_%s_weak" % f["key"])
		var hp_full := 0
		var hp_weak := 0
		for m: Variant in (full["monsters"] as Array):
			if bool((m as Dictionary).get("boss", false)):
				hp_full = int((m as Dictionary).get("hp", 0))
		for m: Variant in (weak["monsters"] as Array):
			if bool((m as Dictionary).get("boss", false)):
				hp_weak = int((m as Dictionary).get("hp", 0))
		assert_true(hp_weak > 0 and (hp_full == 0 or hp_weak < hp_full), "%s: the weakness costs it Hit Points" % f["key"])


func test_a_failed_check_costs_hours_and_never_the_way() -> void:
	for f: Dictionary in FEARS:
		_meet_fear(f)
		dice = LowDice.new()
		var file := "moonfall/" + str(f["file"])
		_arrive(str(f["outpost"]))
		var before := st.total_minutes()
		_play(file + ":hook", ["Ask how to find it", str(f["a1"])])
		assert_true(_flag("mf_%s_found" % f["key"]), "%s: a failed roll still finds the lair the long way" % f["key"])
		assert_true(st.total_minutes() - before >= 300, "%s: the long way costs hours" % f["key"])
		_play(file + ":clue", ["Ask what could hurt it", str(f["w1"])])
		assert_true(_flag(str(f["weak"])), "%s: the weakness comes the long way too" % f["key"])


func test_the_second_route_finds_every_lair_too() -> void:
	for f: Dictionary in FEARS:
		_meet_fear(f)
		_arrive(str(f["outpost"]))
		_play("moonfall/" + str(f["file"]) + ":clue", ["Ask how to find it", str(f["b1"])])
		assert_true(_flag("mf_%s_found" % f["key"]), "%s: route two finds the lair (a roll that misses takes the long way)" % f["key"])
		assert_eq(st.quest_stage(str(f["quest"])), "trail")


func test_the_land_afflicts_and_a_good_roll_resists_it_for_good() -> void:
	var f: Dictionary = FEARS[0]
	_meet_fear(f)
	dice = LowDice.new()
	_arrive(str(f["outpost"]))
	_play("moonfall/" + str(f["file"]) + ":arrive")
	var hurt := false
	for ch in st.party:
		if ch.hp < ch.max_hp():
			hurt = true
	assert_true(hurt, "the sinkholes bruise the party on a failed roll, never below 1 Hit Point")
	assert_false(_flag("mf_headsman_resisted"))
	dice = HighDice.new()
	_play("moonfall/" + str(f["file"]) + ":region")
	assert_true(_flag("mf_headsman_resisted"), "a good roll is immune afterwards")
	assert_true(_entry("props", "id", "headsman_region")["when"] != "", "the hazard prop goes quiet once resisted")


func test_each_lair_has_three_scaled_fights_and_the_region_a_patrol() -> void:
	for f: Dictionary in FEARS:
		_arrive(str(f["lair"]))
		var ids := {}
		for e: Variant in _loc()["encounters"]:
			ids[str((e as Dictionary)["id"])] = e
		for v: String in ["full", "light", "weak"]:
			assert_true(ids.has("mf_%s_%s" % [f["key"], v]), "%s has the %s fight" % [f["key"], v])
		var full := ids["mf_%s_full" % f["key"]] as Dictionary
		var light := ids["mf_%s_light" % f["key"]] as Dictionary
		assert_true((full["monsters"] as Array).size() > (light["monsters"] as Array).size(), "%s: the light fight brings fewer minions" % f["key"])
		assert_true(bool(full["lair"]), "%s fights in its lair" % f["key"])
		_arrive(str(f["outpost"]))
		var found_patrol := false
		for e: Variant in _loc()["encounters"]:
			if str((e as Dictionary)["id"]) == "mf_%s_patrol" % f["key"]:
				found_patrol = true
		assert_true(found_patrol, "%s has a regional patrol" % f["key"])


func test_barrow_king_hook_is_a_wickermoor_villager_the_player_knows() -> void:
	_meet_fear(FEARS[4])
	_arrive("mf_barrow_catacombs")
	var hook := {}
	for n: Variant in _loc()["npcs"]:
		if str((n as Dictionary).get("dialogue", "")) == "moonfall/barrow:hook":
			hook = n as Dictionary
	assert_eq(str(hook["npc"]), "solomon_roderick")


func test_rowans_sisters_descendant_gives_advantage_on_persuading_her() -> void:
	_meet_fear(FEARS[7])
	_arrive("mf_rowans_volcano")
	_play("moonfall/behemoth:descendant", ["Tell her about Rowan"])
	assert_true(_flag("mf_behemoth_descendant"))
	_play("moonfall/behemoth:clue", ["Ask how to find it", str((FEARS[7] as Dictionary)["b1"])])
	assert_true(_flag("mf_behemoth_found"))
	_play("moonfall/behemoth:clue", ["Ask what could hurt it", str((FEARS[7] as Dictionary)["w1"])])
	assert_true(_flag("mf_behemoth_weak"), "Rowan goes willingly into the lava")


# ---- Kehlenn's last offer and the ride out ----------------------------------------------------------------------------------------

func _on_the_hill() -> void:
	_hunt(8)
	st.set_flag("moonfall_nights_left", 9)
	st.set_quest_stage("moonfall", "one_last_choice")
	_arrive("mf_last_hill")


func test_refusing_the_offer_returns_the_moon_and_sets_the_ending_flags() -> void:
	_on_the_hill()
	var prop := _entry("props", "id", "mf_hill_offer")
	assert_true(_holds(prop["call_when"]), "Kehlenn speaks once all eight are dead")
	var b := _play("moonfall/moon:last_offer", ["Refuse her", "Refuse her, and let the moon go back"])
	assert_true(bool(b.get("end_game")))
	assert_eq(str(st.get_flag("moonfall_offer")), "refused")
	assert_eq(st.quest_stage("moonfall"), "refused")
	assert_true(_holds("flag.moonfall_started and flag.old_fears_slain == 8 and flag.moonfall_offer == refused"), "the `moon_unbent` ending's condition")


func test_accepting_the_offer_destroys_every_other_soul_and_sets_the_flag() -> void:
	_on_the_hill()
	var b := _play("moonfall/moon:last_offer", ["Accept her offer", "Accept: the moon falls"])
	assert_true(bool(b.get("end_game")))
	assert_eq(str(st.get_flag("moonfall_offer")), "accepted")
	assert_eq(st.quest_stage("moonfall"), "accepted")
	assert_true(_holds("flag.moonfall_offer == accepted"), "the `green_sea` ending's condition")


func test_the_offer_can_be_thought_over_and_heard_out_first() -> void:
	_on_the_hill()
	var r := DialogueRunner.new(st, dice)
	r.start("moonfall/moon:last_menu")
	var b := r.next()
	for want: String in ["Hear her out", "Ask the Vagrant", "Refuse her", "Think again", "Accept her offer", "Think again"]:
		assert_eq(str(b["kind"]), "options")
		var pick := -1
		for j in (b["options"] as Array).size():
			if str(((b["options"] as Array)[j] as Dictionary)["text"]).contains(want):
				pick = j
				break
		assert_true(pick >= 0, "option %s" % want)
		b = r.choose(pick)
		while str(b["kind"]) not in ["options", "end"]:
			b = r.next()
	assert_eq(str(st.get_flag("moonfall_offer", "")), "", "nothing is decided until it is confirmed")


func test_the_ride_out_is_one_train_and_its_own_ending() -> void:
	_hunt(3)
	_arrive("mf_round")
	var b := _play("moonfall/vagrant:hub_start", ["train out", "Take the ride out now", "Yes, take us out"])
	assert_true(bool(b.get("end_game")))
	assert_true(_flag("moonfall_fled"))
	assert_eq(st.quest_stage("moonfall"), "fled")
	assert_eq(st.quest_stage("mf_ride_out"), "taken")
	assert_true(_holds("flag.moonfall_fled"), "the `last_train_out` ending's condition")
	assert_false(_holds("flag.moonfall_started and flag.old_fears_slain == 8 and flag.moonfall_offer == refused"))


func test_staying_to_fight_fails_the_ride_but_the_train_can_still_be_taken_later() -> void:
	_hunt(2)
	_arrive("mf_round")
	_play("moonfall/vagrant:hub_start", ["train out", "We stay and fight"])
	assert_eq(st.quest_stage("mf_ride_out"), "declined", "the seat stays empty")
	assert_false(_flag("moonfall_fled"))
	var b := _play("moonfall/vagrant:hub_start", ["train out", "Take the ride out now", "Yes, take us out"])
	assert_true(bool(b.get("end_game")), "the train is still there")
	assert_eq(st.quest_stage("mf_ride_out"), "taken", "a comeback from the failure")


# ---- the side quests ---------------------------------------------------------------------------------------------------------------

func test_last_night_in_wickermoor_three_goodbyes() -> void:
	_hunt(0)
	_arrive("mf_round")
	_play("moonfall/last_night:gaunt_start", ["sit with the village"])
	assert_eq(st.quest_stage("mf_last_night"), "asked")
	assert_true(_flag("mf_gaunt_said"))
	_play("moonfall/last_night:tamsin_start", ["Sit with her", "Stamp her form"])
	assert_eq(st.quest_stage("mf_last_night"), "asked")
	_play("moonfall/last_night:marianna_start", ["Stay with her", "Help with the mane"])
	assert_eq(_n("mf_goodbyes"), 3)
	assert_eq(st.quest_stage("mf_last_night"), "done")


func test_last_night_can_be_skipped_and_it_costs_a_cold_look() -> void:
	_hunt(0)
	_arrive("mf_round")
	_play("moonfall/last_night:gaunt_start", ["no time for this"])
	assert_eq(st.quest_stage("mf_last_night"), "skipped")
	assert_eq(_n("mf_goodbyes"), 0)


func test_what_the_moon_keeps_returned_kept_or_left() -> void:
	for ending: String in ["returned", "kept", "left"]:
		_party(13)
		_hunt(0)
		_arrive("mf_round")
		_play("moonfall/keeps:start", ["Ask where"])
		assert_eq(st.quest_stage("mf_what_moon_keeps"), "asked")
		if ending == "left":
			_play("moonfall/keeps:menu", ["leave them to the moon"])
			assert_eq(st.quest_stage("mf_what_moon_keeps"), "left")
			continue
		for i in range(1, 5):
			st.give_item("mf_keepsake_%d" % i, 1)
		_play("moonfall/keeps:menu", ["Show him", "Let him carry them" if ending == "returned" else "Keep them close"])
		assert_eq(_n("mf_keepsakes"), 4)
		assert_eq(st.quest_stage("mf_what_moon_keeps"), ending)
		assert_false(st.party_has_item("mf_keepsake_1"), "the keepsakes are handed over")


func test_the_keepsakes_are_found_in_four_places() -> void:
	var places := {"mf_round": "mf_keepsake_1", "mf_covered_bridge": "mf_keepsake_2", "mf_barrow_catacombs": "mf_keepsake_3", "mf_rowans_volcano": "mf_keepsake_4"}
	for loc: String in places:
		_arrive(loc)
		var p := _entry("props", "id", str(places[loc]))
		assert_true(not p.is_empty() and str(p.get("item", "")) == str(places[loc]), "%s holds %s" % [loc, places[loc]])


func test_the_last_verse_each_way_and_the_banjo() -> void:
	_hunt(0)
	_arrive("mf_round")
	_play("moonfall/verse:start", ["stirring"])
	assert_eq(st.quest_stage("mf_last_verse"), "delivered")
	assert_eq(str(st.get_flag("mf_verse_style")), "stirring")
	GameState.reset()
	_party(13)
	_hunt(0)
	_arrive("mf_round")
	st.give_item("jericho_banjo", 1)
	_play("moonfall/verse:start", ["Play a chord", "honest"])
	assert_true(_flag("mf_verse_banjo"))
	assert_eq(st.quest_stage("mf_last_verse"), "delivered")


func test_telling_quill_to_stop_fails_the_verse() -> void:
	_hunt(0)
	_arrive("mf_round")
	_play("moonfall/verse:start", ["Tell him to stop"])
	assert_eq(st.quest_stage("mf_last_verse"), "silenced")


func test_the_moons_nights_ledger_tells_the_hour() -> void:
	_hunt(0)
	_arrive("mf_round")
	var b := _play("moonfall/moon:ledger", ["Study the sky"])
	assert_eq(str(b["kind"]), "end")


func test_the_quests_close_when_the_nights_run_out() -> void:
	_hunt(2)
	st.set_quest_stage("mf_tall_man", "asked")
	st.set_quest_stage("mf_headsman", "slain")
	st.set_flag("moonfall_nights_left", 0)
	QuestClosures.sweep(st)
	assert_eq(st.quest_stage("moonfall"), "lost")
	assert_eq(st.quest_stage("mf_tall_man"), "lost", "an open hunt fails with the moon")
	assert_eq(st.quest_stage("mf_headsman"), "slain", "a won hunt stays won")


func test_the_ride_out_is_not_a_lost_moon() -> void:
	_hunt(2)
	st.set_flag("moonfall_fled")
	st.set_flag("moonfall_nights_left", 0)
	QuestClosures.sweep(st)
	assert_eq(st.quest_stage("moonfall"), "hunt", "the nights running out after a ride out do not close the hunt")


func test_moonfall_starts_nothing_without_the_vagrant() -> void:
	assert_eq(st.quest_stage("moonfall"), "")
	assert_eq(st.level_cap(), 13)
	st.set_flag("moonfall_begun")
	assert_eq(st.level_cap(), 20)
