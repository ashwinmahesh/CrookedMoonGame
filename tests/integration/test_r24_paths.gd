extends TestCase
## R24, the Crooked Tree: Doris's hook and the mourners, the master suite (four ways in, the will, the parchment), the Wytchwood trail (tracking with the second-failure rule, the
## creek, the hare, the lure and the hypnovulfen, the hovel's hex and fire, the grove), the Horned King's visits and his offer (hero by hero, two confirmations), the barrow (Kehlenn's side
## is an ending, not a failure), the Born King's `final_battle`, the ritual at the goat skull (every offering, the six-refusal limit, the Last Act), Phillip's plea, Adela's ember, and the
## side quests (Alda's Will, the Mayor's Neck, Chaos Reigns, Lost and Found, the Herald). Each scenario plays the places' own data the way test_r13_paths and test_r22_paths do:
## dice are high (every check lands) or low (none does) as the test says, and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")


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


## The first d20 is a 1, every roll after is the highest face (one refusal at the skull, then the offerings land).
class OneMissDice extends DiceRoller:
	var missed := false

	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			if sides == 20 and not missed:
				missed = true
				out.append(1)
			else:
				out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var st: StoryState
var dice: DiceRoller = HighDice.new()
var fights: Array[String] = []
var last_beat := {}


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", st.location)


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


func _entry(list_key: String, id_key: String, id: String) -> Dictionary:
	for e: Variant in _loc().get(list_key, []):
		if str((e as Dictionary).get(id_key, "")) == id:
			return e as Dictionary
	return {}


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out, which is the "leave" in every menu here).
func _play(ref: String, picks: Array[String] = []) -> Dictionary:
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	for i in 1500:
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
	last_beat = b
	return b


## The encounter `id` of this place won, as LocationFights._end_encounter records a victory (spec_for's pick).
func _win(id: String) -> void:
	var spec := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == id and (spec.is_empty() or not _holds(StoryConditions.encounter_when(spec))):
			spec = e as Dictionary
	assert_true(not spec.is_empty(), "%s has the fight %s" % [st.location, id])
	if spec.is_empty():
		return
	fights.append(id)
	(st.loc_state(st.location)["encounters"] as Dictionary)[id] = true
	if spec.has("flag"):
		st.set_flag(str(spec["flag"]))
	if spec.has("withdraw"):
		st.set_flag(str((spec["withdraw"] as Dictionary)["flag"]))
	if spec.has("quest"):
		st.set_quest_stage(str((spec["quest"] as Dictionary)["id"]), str((spec["quest"] as Dictionary)["stage"]))


func _arrive(id: String) -> void:
	st.location = id
	assert_true(not _loc().is_empty(), "%s is a place" % id)


func _flag(id: String) -> bool:
	return bool(st.get_flag(id))


func _n(id: String) -> int:
	return int(st.get_flag(id, 0))


func _s(id: String) -> String:
	return str(st.get_flag(id, ""))


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 13)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	dice = HighDice.new()
	st.location = "wickermoor_village"
	last_beat = {}


func after_each() -> void:
	GameState.reset()


# ---- the hook and the mourners ------------------------------------------------------------------------------------------------------

func test_doris_brings_the_hook_only_after_the_wicker_man_burns() -> void:
	var hook := _entry("npcs", "dialogue", "crooked_tree/hook:doris_start")
	assert_true(not hook.is_empty(), "the village has Doris's petition")
	assert_false(_holds(hook["when"]), "no petition while the Wicker Man stands (a missing flag is false)")
	st.set_flag("wicker_man_burned")
	assert_true(_holds(hook["when"]), "the petition once the Wicker Man has burned")
	st.set_flag("ct_hook_given")
	assert_false(_holds(hook["when"]), "told once")


func test_doris_gives_the_hook_and_starts_the_clock() -> void:
	_play("crooked_tree/hook:doris_start", ["find him"])
	assert_true(_flag("ct_hook_given") and _flag("ct_clock"))
	assert_eq(st.quest_stage("the_crooked_tree"), "the_last_hope")
	assert_false(_flag("act2_done"), "the chapter does not touch act2_done")


func test_jean_and_siv_tell_where_phillip_went_and_where_the_key_hangs() -> void:
	st.location = "wickermoor_green_queen_inn"
	_play("crooked_tree/hook:jean_start", ["Ask about Phillip", "Ask about the suite key"])
	assert_true(_flag("ct_inn_told") and _flag("ct_has_key"))
	assert_eq(st.quest_stage("the_crooked_tree"), "the_master_suite")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_play("crooked_tree/hook:siv_start", ["Is there a key"])
	assert_true(_flag("ct_has_key"))


# ---- the master suite ----------------------------------------------------------------------------------------------------------------

func test_the_suite_door_opens_four_ways_and_a_failed_try_locks_nothing() -> void:
	st.location = "wickermoor_green_queen_inn_upper"
	_play("crooked_tree/suite:door", ["Pick the lock"])
	assert_true(_flag("ct_suite_open"), "a high pick opens it")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	dice = LowDice.new()
	_play("crooked_tree/suite:door", ["Pick the lock", "Force the door", "Search the landing", "Ask Jean"])
	assert_false(_flag("ct_suite_open"), "every roll missed and the door is still shut")
	st.set_flag("ct_has_key")
	_play("crooked_tree/suite:door", ["spare key"])
	assert_true(_flag("ct_suite_open"), "the spare key is the way that needs no roll")
	assert_true(_holds(_entry("exits", "id", "ct_suite_exit").get("when", "")), "the exit into the suite is open")


func test_forcing_the_door_and_finding_the_key_are_the_other_ways_in() -> void:
	st.location = "wickermoor_green_queen_inn_upper"
	_play("crooked_tree/suite:door", ["Force the door"])
	assert_true(_flag("ct_suite_open"))
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_play("crooked_tree/suite:door", ["Search the landing"])
	assert_true(_flag("ct_has_key") and _flag("ct_suite_open"))


func test_the_suite_gives_its_things_once_and_the_strongbox_gives_the_will() -> void:
	_arrive("ct_master_suite")
	_play("crooked_tree/suite:arrive")
	assert_true(_flag("ct_suite_seen"))
	_play("crooked_tree/suite:jewels")
	_play("crooked_tree/suite:jewels")
	dice = LowDice.new()
	_play("crooked_tree/suite:box", ["Pick it", "Break it open"])
	assert_false(_flag("ct_box_open"), "two misses leave the box shut")
	dice = HighDice.new()
	var gold := st.gold
	_play("crooked_tree/suite:box", ["Pick it"])
	assert_true(_flag("ct_box_open") and st.party_has_item("alda_will"))
	assert_eq(st.gold, gold + 242)
	assert_eq(st.quest_stage("alda_will"), "have")


func test_the_parchment_opens_the_wood_and_the_road() -> void:
	_arrive("ct_master_suite")
	var t := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	var place := {}
	for p: Variant in t["places"]:
		if str((p as Dictionary)["id"]) == "ct_wytchwood":
			place = p as Dictionary
	assert_false(_holds(place["when"]), "the wood is not on the map before the parchment is read")
	_play("crooked_tree/suite:parchment")
	_play("crooked_tree/suite:parchment")
	assert_true(_flag("wytchwood_open") and st.party_has_item("crooked_tree_parchment"))
	assert_eq(st.quest_stage("the_crooked_tree"), "into_the_wytchwood")
	assert_true(_holds(place["when"]), "the wood and its road appear")


func test_the_lovers_card_finds_adelas_planchette_in_the_ash() -> void:
	_arrive("ct_master_suite")
	st.set_flag("tarot_hero_2", "the_lovers")
	_play("crooked_tree/suite:circle", ["Look for what Adela wore"])
	assert_true(st.party_has_item("adelas_planchette") and _flag("ct_planchette_taken"))


# ---- the side quests in the village ---------------------------------------------------------------------------------------------------

func test_alda_will_delivered_or_burned() -> void:
	st.give_item("alda_will", 1)
	st.set_quest_stage("alda_will", "have")
	_play("crooked_tree/will:marianna", ["Give her the will"])
	assert_true(_flag("alda_will_delivered"))
	assert_eq(st.quest_stage("alda_will"), "delivered")
	assert_false(st.party_has_item("alda_will"))
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	st.give_item("alda_will", 1)
	st.set_quest_stage("alda_will", "have")
	_play("crooked_tree/will:marianna", ["Burn the will"])
	assert_eq(st.quest_stage("alda_will"), "burned")
	assert_false(_flag("alda_will_delivered"))


func test_the_mayor_is_talked_down_scared_off_or_taken_into_custody() -> void:
	_play("crooked_tree/mayor:mob_start", ["Talk the crowd down"])
	assert_eq(st.quest_stage("save_the_mayor"), "saved")
	assert_eq(_s("ct_mayor_fate"), "saved")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	dice = LowDice.new()
	_play("crooked_tree/mayor:mob_start", ["Talk the crowd down", "Take Wendel into our custody"])
	assert_flag_state("saved")


func assert_flag_state(expect: String) -> void:
	assert_eq(_s("ct_mayor_fate"), expect, "the mayor's fate is %s" % expect)


func test_the_mayor_is_jailed_when_the_crowd_has_him_and_hanged_if_the_party_dawdles() -> void:
	_play("crooked_tree/mayor:mob_start", ["Let the crowd have him"])
	assert_eq(st.quest_stage("save_the_mayor"), "jailed")
	assert_flag_state("jailed")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_play("crooked_tree/hook:doris_start", ["find him"])
	st.advance_minutes(4 * 24 * 60 + 5)
	_play("crooked_tree/mayor:mob_start")
	assert_eq(st.quest_stage("save_the_mayor"), "lynched")
	assert_flag_state("lynched")


func test_the_ledger_is_a_third_way_to_calm_the_mob() -> void:
	st.give_item("ledger_of_debts", 1)
	dice = LowDice.new()
	_play("crooked_tree/mayor:mob_start", ["Face them down", "Hand over Alda's ledger"])
	assert_eq(st.quest_stage("save_the_mayor"), "saved")
	assert_false(st.party_has_item("ledger_of_debts"))


func test_chaos_reigns_confessors_come_by_the_day_and_the_third_closes_the_quest() -> void:
	st.set_flag("wicker_man_burned")
	_play("crooked_tree/hook:doris_start", ["find him"])
	var a := _entry("npcs", "dialogue", "crooked_tree/chaos:confess_a")
	var c := _entry("npcs", "dialogue", "crooked_tree/chaos:confess_c")
	assert_false(_holds(a["when"]), "no confessions on the first day")
	st.advance_minutes(24 * 60 + 1)
	assert_true(_holds(a["when"]))
	assert_false(_holds(c["when"]))
	st.advance_minutes(2 * 24 * 60)
	assert_true(_holds(c["when"]))
	_play("crooked_tree/chaos:confess_a", ["forgive"])
	_play("crooked_tree/chaos:confess_b", ["forgiven"])
	_play("crooked_tree/chaos:confess_c", ["forgive"])
	assert_eq(_n("ct_confessions"), 3)
	assert_eq(st.quest_stage("chaos_reigns"), "heard")


func test_a_long_delay_sets_the_bedlam_nights_on_entering_the_wood() -> void:
	_play("crooked_tree/hook:doris_start", ["find him"])
	st.advance_minutes(3 * 24 * 60 + 5)
	st.set_flag("wytchwood_open")
	for i in 4:
		st.set_flag("tarot_hero_%d" % (i + 1), "the_fool")
	_arrive("ct_wytchwood")
	_play("crooked_tree/wood:edge_start")
	assert_eq(_n("horned_bedlam_nights"), 3)
	assert_eq(_n("party_size"), 4)
	assert_true(_flag("ct_wood_entered"))


# ---- the Wytchwood trail -------------------------------------------------------------------------------------------------------------

func test_entering_early_turns_you_back() -> void:
	_arrive("ct_wytchwood")
	_play("crooked_tree/wood:edge_start")
	assert_false(_flag("ct_wood_entered"), "the glamoured wood lets nobody in before Phillip answers")


func test_tracking_a_leg_a_miss_costs_a_fight_and_a_second_miss_finds_the_trail_anyway() -> void:
	st.set_flag("wytchwood_open")
	_arrive("ct_wytchwood")
	dice = LowDice.new()
	_play("crooked_tree/wood:track_1", ["Read the ground"])
	assert_eq(fights, ["ct_hw_1"] as Array[String])
	assert_false(_flag("ct_leg_1_done"))
	_play("crooked_tree/wood:track_1", ["Read the ground"])
	assert_true(_flag("ct_leg_1_done"), "the second failure finds the trail anyway")
	assert_eq(fights.size(), 1, "no second fight")
	dice = HighDice.new()
	_play("crooked_tree/wood:track_2", ["Read the ground"])
	assert_true(_flag("ct_leg_2_done"))


func test_each_clue_is_found_by_one_of_two_skills_and_the_cane_is_automatic() -> void:
	_arrive("ct_wytchwood")
	_play("crooked_tree/wood:clue_1", ["Search the needles"])
	assert_true(_flag("ct_clue_1") and st.party_has_item("clue_pocket_watch"))
	dice = LowDice.new()
	_play("crooked_tree/wood:clue_2", ["Search", "Look more carefully"])
	assert_false(_flag("ct_clue_2"), "a missed clue is only a missed clue")
	st.set_flag("tarot_hero_3", "the_devil")
	_play("crooked_tree/wood:clue_5")
	assert_true(_flag("ct_clue_5") and st.party_has_item("clue_cane") and st.party_has_item("phillips_cane"))


func test_the_creek_crosses_three_ways_and_a_swept_hero_rejoins_after_the_fight() -> void:
	_arrive("ct_wytchwood")
	_play("crooked_tree/wood:creek", ["Walk the fallen log"])
	assert_true(_flag("ct_creek_crossed"))
	assert_eq(st.quest_stage("the_crooked_tree"), "tracking_phillip")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_arrive("ct_wytchwood")
	dice = LowDice.new()
	_play("crooked_tree/wood:creek", ["Walk the fallen log"])
	assert_eq(fights, ["ct_hw_swept"] as Array[String])
	assert_false(_flag("ct_creek_crossed"))
	_play("crooked_tree/wood:creek")
	assert_true(_flag("ct_creek_crossed"), "the swept hero always rejoins after the fight")


func test_the_hare_is_slipped_or_fought() -> void:
	_arrive("ct_wytchwood")
	_play("crooked_tree/beasts:hare_start", ["Slip round it"])
	assert_true(_flag("ct_hare_done") and fights.is_empty())
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_arrive("ct_wytchwood")
	_play("crooked_tree/beasts:hare_start", ["Approach it"])
	assert_eq(fights, ["ct_hare"] as Array[String])


func test_the_lure_seen_through_or_not_the_beast_is_fought_and_the_surprise_differs() -> void:
	_arrive("ct_wytchwood")
	_play("crooked_tree/beasts:illusion", ["Look closer"])
	assert_true(_flag("ct_beast_seen_through"))
	assert_eq(fights, ["ct_beast"] as Array[String])
	var seen := {}
	for e: Variant in _loc()["encounters"]:
		if str((e as Dictionary)["id"]) == "ct_beast" and str((e as Dictionary)["when"]).begins_with("flag."):
			seen = e as Dictionary
	assert_eq(str(seen["surprise"]), "", "no ambush when the lure was seen through")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_arrive("ct_wytchwood")
	_play("crooked_tree/beasts:illusion", ["Go to help"])
	assert_false(_flag("ct_beast_seen_through"))
	var ambush := {}
	for e: Variant in _loc()["encounters"]:
		if str((e as Dictionary)["id"]) == "ct_beast" and str((e as Dictionary)["when"]).begins_with("not "):
			ambush = e as Dictionary
	assert_eq(str(ambush["surprise"]), "enemies", "an unseen lure means the beast has the surprise")


func test_the_hovel_hex_the_painted_walls_the_fire_and_three_ways_out() -> void:
	_arrive("ct_wytchwood")
	dice = LowDice.new()
	_play("crooked_tree/hovel:idols", ["Take one down"])
	assert_true(_flag("ct_idols_hex"))
	dice = HighDice.new()
	_play("crooked_tree/hovel:door", ["Go in"])
	_arrive("ct_hovel")
	_play("crooked_tree/hovel:arrive")
	_play("crooked_tree/hovel:bed", ["Search under the bed"])
	assert_true(st.party_has_item("painters_supplies"))
	_play("crooked_tree/hovel:paintings", ["Read the paintings"])
	assert_true(_flag("ct_hovel_fire"), "the last painting is a fire")
	dice = LowDice.new()
	var hp0 := 0
	for ch in st.party:
		hp0 += ch.hp
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start("crooked_tree/hovel:escape"))
	var b := r.next()
	for tries in 4:
		while str(b["kind"]) != "options":
			b = r.next()
		b = r.choose(tries)
	while str(b["kind"]) != "options":
		b = r.next()
	assert_false(_flag("ct_hovel_escaped"), "four failed attempts burn but never lock the way")
	var hp1 := 0
	for ch in st.party:
		hp1 += ch.hp
	assert_true(hp1 < hp0, "each failed try costs fire damage")
	dice = HighDice.new()
	_play("crooked_tree/hovel:escape", ["Smash through a slatted window"])
	assert_true(_flag("ct_hovel_escaped") and _flag("ct_hovel_done"))
	assert_eq(st.location, "ct_wytchwood")


func test_the_grove_rowans_the_centre_and_the_maidenwood() -> void:
	_arrive("ct_wytchwood")
	_play("crooked_tree/grove:grove_start")
	assert_true(_flag("ct_grove_started"))
	_play("crooked_tree/grove:rowan", ["Step closer"])
	assert_eq(fights, ["ct_maidenwood"] as Array[String])
	_play("crooked_tree/grove:centre")
	assert_true(_flag("ct_grove_done"), "with the maidenwood down the centre is clear")
	assert_eq(st.quest_stage("the_crooked_tree"), "tracking_phillip")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_arrive("ct_wytchwood")
	_play("crooked_tree/grove:centre", ["Cross the centre"])
	assert_true(_flag("ct_grove_done"), "a high save carries them across")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	fights.clear()
	_arrive("ct_wytchwood")
	dice = LowDice.new()
	_play("crooked_tree/grove:centre", ["Cross the centre"])
	assert_eq(fights, ["ct_maidenwood"] as Array[String], "a charmed hero is pulled to the maidenwood")
	_play("crooked_tree/grove:centre")
	assert_true(_flag("ct_grove_done"), "and with the maidenwood down the way is clear")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_arrive("ct_wytchwood")
	_play("crooked_tree/grove:centre", ["Go round the edge"])
	assert_true(_flag("ct_grove_done"), "going round the edge needs no roll")


# ---- the Horned King -----------------------------------------------------------------------------------------------------------------

func test_the_two_visits_record_a_theme_and_attacking_him_is_futile() -> void:
	_arrive("ct_wytchwood")
	_play("crooked_tree/goat:visit_1", ["carry grief"])
	assert_eq(_s("hk_theme_1"), "pain")
	assert_true(_flag("ct_goat1_done"))
	assert_eq(st.quest_stage("the_horned_kings_offer"), "tempted")
	dice = LowDice.new()
	_play("crooked_tree/goat:visit_2", ["Attack the shadow"])
	assert_true(_flag("ct_goat2_done"), "a failed fright still ends the visit")


func test_the_final_offer_all_refuse() -> void:
	_arrive("ct_wytchwood")
	st.set_flag("party_size", 4)
	_play("crooked_tree/goat:offer_start", ["Hear him out", "I refuse", "I refuse", "I refuse", "I refuse"])
	assert_true(_flag("ct_offer_made"))
	assert_eq(_n("horned_bargains"), 0)
	assert_false(_flag("ct_all_bargained"))
	assert_eq(st.quest_stage("the_horned_kings_offer"), "refused")
	assert_eq(st.quest_stage("the_crooked_tree"), "live_deliciously")


func test_the_final_offer_one_accepts_with_two_confirmations_a_wish_and_a_gift() -> void:
	_arrive("ct_wytchwood")
	st.set_flag("party_size", 4)
	var picks: Array[String] = ["Hear him out", "I accept", "Yes, I want it", "Yes, I accept", "gift of luck", "Might", "I refuse", "I refuse", "I refuse"]
	_play("crooked_tree/goat:offer_start", picks)
	assert_eq(_n("horned_bargains"), 1)
	assert_true(_flag("ct_offer_made"))
	assert_eq(st.quest_stage("the_horned_kings_offer"), "bargained")
	assert_false(_flag("ct_all_bargained"))
	var gifted := 0
	for ch in st.party:
		if "horned_gift_might" in ch.dark_gifts():
			gifted += 1
	assert_eq(gifted, 1, "one hero carries the Horned King's gift")


func test_a_refusal_at_the_second_confirmation_is_still_a_refusal() -> void:
	_arrive("ct_wytchwood")
	st.set_flag("party_size", 1)
	_play("crooked_tree/goat:offer_start", ["Hear him out", "I accept", "Yes, I want it", "No, I refuse"])
	assert_eq(_n("horned_bargains"), 0)
	assert_true(_flag("ct_offer_made"))


func test_when_every_hero_accepts_the_party_may_kneel() -> void:
	_arrive("ct_wytchwood")
	st.set_flag("party_size", 4)
	var picks: Array[String] = ["Hear him out"]
	for i in 4:
		picks.append_array(["I accept", "Yes, I want it", "Yes, I accept", "Rest and healing", "Grace"] as Array[String])
	_play("crooked_tree/goat:offer_start", picks)
	assert_eq(_n("horned_bargains"), 4)
	assert_true(_flag("ct_all_bargained"))
	_arrive("ct_crooked_tree")
	_play("crooked_tree/king:emerge", ["Kneel", "Yes, we kneel", "Yes. We kneel."])
	assert_true(bool(last_beat.get("end_game", false)), "kneeling ends the game")
	assert_eq(st.quest_stage("the_horned_kings_offer"), "kneeled")
	assert_true(fights.is_empty(), "no fight when they kneel")


# ---- the barrow ----------------------------------------------------------------------------------------------------------------------

func test_kehlenns_story_may_be_heard_argued_with_or_refused_and_none_is_a_failure() -> void:
	_arrive("ct_barrow")
	_play("crooked_tree/barrow:arrive")
	assert_eq(st.quest_stage("the_barrows_side"), "heard")
	_play("crooked_tree/barrow:kehlenn", ["Ask for her story", "Argue with her", "We refuse you", "Try to free Phillip", "Study Phillip"])
	assert_true(_flag("ct_kehlenn_story"))
	assert_eq(st.quest_stage("the_barrows_side"), "refused")
	assert_false(_flag("kehlenn_sided"))


func test_siding_with_kehlenn_takes_two_confirmations_and_is_an_ending_not_a_failure() -> void:
	_arrive("ct_barrow")
	var b := _play("crooked_tree/barrow:kehlenn", ["Ask for her story", "take your side", "Yes, we will help her", "No. Not that", "We are done here"])
	assert_false(bool(b.get("end_game", false)) and _flag("kehlenn_sided"), "backing out at the second confirmation changes nothing")
	assert_false(_flag("kehlenn_sided"))
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_arrive("ct_barrow")
	b = _play("crooked_tree/barrow:kehlenn", ["Ask for her story", "take your side", "Yes, we will help her", "Yes. We kneel"])
	assert_true(bool(b.get("end_game", false)))
	assert_true(_flag("kehlenn_sided"))
	assert_eq(st.quest_stage("the_barrows_side"), "sided")
	assert_true(_flag("ct_kehlenn_story"))


func test_the_side_option_is_off_until_her_story_is_heard() -> void:
	_arrive("ct_barrow")
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start("crooked_tree/barrow:kehlenn"))
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	for o: Variant in b["options"]:
		if str((o as Dictionary)["text"]).contains("take your side"):
			assert_false(bool((o as Dictionary)["enabled"]), "siding is not offered before the story is heard")


func test_leaving_the_barrow_turns_phillip_into_the_born_king() -> void:
	_arrive("ct_barrow")
	_play("crooked_tree/barrow:kehlenn", ["We are done here"])
	assert_true(_flag("ct_phillip_taken"))
	assert_eq(st.quest_stage("the_crooked_tree"), "born_king")
	assert_eq(st.location, "ct_crooked_tree")


func test_the_trophies_are_taken_back_or_left_and_the_trophy_cases_are_one_conversation() -> void:
	_arrive("ct_barrow")
	_play("crooked_tree/barrow:trophies", ["Take back what was ours"])
	assert_true(_flag("ct_trophies_taken"))
	assert_true(st.party_has_item("rowans_sister_portrait") and st.party_has_item("hypnovulfen_figure"))
	assert_eq(st.quest_stage("lost_and_found"), "taken")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_arrive("ct_barrow")
	_play("crooked_tree/barrow:trophies", ["Leave it all"])
	assert_eq(st.quest_stage("lost_and_found"), "left")


# ---- the Born King -------------------------------------------------------------------------------------------------------------------

func test_the_herald_reads_the_terms_in_order_or_the_wrong_way_round_and_the_fight_follows() -> void:
	_arrive("ct_crooked_tree")
	st.set_flag("ct_phillip_taken")
	_play("crooked_tree/herald:start", ["put the pages in order", "Just read"])
	assert_eq(st.quest_stage("heralds_terms"), "sorted")
	assert_eq(fights, ["ct_born_king"] as Array[String], "the herald's last word leads straight into the fight")
	assert_eq(_s("crooked_cause"), "wipe", "a wipe from here is the Crooked Defeat")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	fights.clear()
	_arrive("ct_crooked_tree")
	st.set_flag("ct_phillip_taken")
	_play("crooked_tree/herald:start", ["Hear the rest"])
	assert_eq(st.quest_stage("heralds_terms"), "garbled")
	assert_eq(fights, ["ct_born_king"] as Array[String])


func test_the_born_king_is_a_final_battle_with_kehlenns_influence_and_a_second_phase() -> void:
	_arrive("ct_crooked_tree")
	var spec := _entry("encounters", "id", "ct_born_king")
	assert_eq(str(spec["final_battle"]), "crooked_tree")
	assert_true(Endings.is_final_battle(spec), "a wipe here asks for an ending")
	assert_true(bool(spec.get("lair", false)))
	var m := Compendium.shared().get_entry("monsters", "horned_king_born")
	assert_eq((m["lair_actions"] as Array).size(), 3, "effigies, grasping roots, moonlight dirge")
	assert_eq(str(((m["phases"] as Array)[0] as Dictionary)["id"]), "wrath_of_the_crooked_queen")
	assert_eq((((m["phases"] as Array)[0] as Dictionary)["lair_actions"] as Array).size(), 4, "the Wrath joins them when he is Bloodied")


# ---- the ritual ---------------------------------------------------------------------------------------------------------------------

func _after_the_king() -> void:
	_arrive("ct_crooked_tree")
	st.set_flag("horned_king_destroyed")
	st.set_flag("party_size", 4)
	st.set_flag("crooked_cause", "wipe")


func test_the_skull_speaks_and_the_wipe_cause_is_cleared() -> void:
	_after_the_king()
	_play("crooked_tree/ritual:skull", ["Ask Phillip what he needs"])
	assert_true(_flag("ct_skull_spoke"))
	assert_eq(_s("crooked_cause"), "")
	assert_eq(st.quest_stage("what_each_hero_offers"), "asked")
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start("crooked_tree/ritual:menu"))
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	for o: Variant in b["options"]:
		if str((o as Dictionary)["text"]).contains("Begin the ritual"):
			assert_false(bool((o as Dictionary)["enabled"]), "the ritual waits for Phillip's plea")


func test_phillips_plea_is_answered_or_met_with_silence() -> void:
	_after_the_king()
	_play("crooked_tree/plea:start", ["We will do it"])
	assert_eq(st.quest_stage("phillips_plea"), "answered")
	assert_true(_flag("ct_plea_done"))
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_after_the_king()
	_play("crooked_tree/plea:start", ["Say nothing"])
	assert_eq(st.quest_stage("phillips_plea"), "silence")
	assert_true(_flag("ct_plea_done"), "silence ends the scene, it does not block the ritual")


func test_every_offering_accepted_binds_kehlenn_and_everyone_gets_a_boon() -> void:
	_after_the_king()
	st.set_flag("ct_plea_done")
	st.set_flag("horned_bargains", 2)
	var picks: Array[String] = ["Begin the ritual", "Offer a treasure", "Offer two points", "Offer a gift", "Offer my Thread", "boon of Might", "boon of Mind", "boon of Grace", "boon of Might"]
	_play("crooked_tree/ritual:menu", picks)
	assert_true(_flag("kehlenn_bound"))
	assert_eq(_s("sacrifice_1"), "item")
	assert_eq(_s("sacrifice_2"), "ability")
	assert_eq(_s("sacrifice_3"), "feature")
	assert_eq(_s("sacrifice_4"), "thread")
	assert_eq(_n("ritual_points"), 4, "two bargains gave Kehlenn four points to start")
	assert_eq(_n("last_act_count"), 0)
	assert_eq(st.quest_stage("what_each_hero_offers"), "bound")
	assert_eq(st.quest_stage("the_crooked_tree"), "flickering_life")
	var boons := 0
	for ch in st.party:
		for g: String in ["binding_boon_might", "binding_boon_mind", "binding_boon_grace"]:
			if g in ch.dark_gifts():
				boons += 1
	assert_true(boons >= 3, "the boons were given (a hero can take one gift of each kind)")


func test_six_refusals_complete_the_ritual_for_kehlenn() -> void:
	_after_the_king()
	st.set_flag("ct_plea_done")
	dice = LowDice.new()
	var picks: Array[String] = ["Begin the ritual", "Offer a treasure"]
	for i in 5:
		picks.append_array(["Offer something else", "Offer a treasure"] as Array[String])
	var b := _play("crooked_tree/ritual:menu", picks)
	assert_true(bool(b.get("end_game", false)))
	assert_eq(_n("ritual_fails"), 6)
	assert_eq(_s("crooked_cause"), "ritual_failed")
	assert_false(_flag("kehlenn_bound"))
	assert_eq(st.quest_stage("what_each_hero_offers"), "refused")
	assert_eq(st.quest_stage("the_crooked_tree"), "crooked_rebirth")


func test_a_hero_who_will_not_offer_is_the_refused_cause() -> void:
	_after_the_king()
	st.set_flag("ct_plea_done")
	var b := _play("crooked_tree/ritual:menu", ["Begin the ritual", "I will not offer"])
	assert_true(bool(b.get("end_game", false)))
	assert_eq(_s("crooked_cause"), "refused")


func test_the_last_act_is_offered_only_after_a_refusal_and_counts() -> void:
	_after_the_king()
	st.set_flag("ct_plea_done")
	st.set_flag("party_size", 2)
	dice = OneMissDice.new()
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start("crooked_tree/ritual:menu"))
	var b := r.next()
	while str(b["kind"]) != "options":
		b = r.next()
	b = r.choose(0)
	while str(b["kind"]) != "options":
		b = r.next()
	for o: Variant in b["options"]:
		if str((o as Dictionary)["text"]).contains("Last Act"):
			assert_false(bool((o as Dictionary)["enabled"]), "no Last Act before a refusal")
	var picks: Array[String] = ["Begin the ritual", "Offer a treasure", "Give my life", "Yes. I will give my life", "Yes", "Offer two points", "boon", "No one takes"]
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_after_the_king()
	st.set_flag("ct_plea_done")
	st.set_flag("party_size", 2)
	dice = OneMissDice.new()
	_play("crooked_tree/ritual:menu", picks)
	assert_eq(_n("last_act_count"), 1)
	assert_eq(_s("sacrifice_1"), "life")
	assert_eq(_s("sacrifice_2"), "ability")
	assert_true(_flag("kehlenn_bound"), "one life given and one offering accepted binds her")
	assert_eq(st.party.size(), GAME.NEW_GAME_PARTY.size() - 1, "the Last Act takes one hero from the party for good")


func test_if_everyone_gives_their_life_the_ritual_ends_the_game_itself() -> void:
	_after_the_king()
	st.set_flag("ct_plea_done")
	st.set_flag("party_size", 1)
	st.set_flag("last_act_count", 0)
	dice = OneMissDice.new()
	var b := _play("crooked_tree/ritual:menu", ["Begin the ritual", "Offer a treasure", "Give my life", "Yes. I will give my life", "Yes", "No one takes"])
	assert_true(bool(b.get("end_game", false)), "nobody is left to board: the ritual requests the ending")
	assert_eq(_n("last_act_count"), 1)
	assert_true(_flag("kehlenn_bound"))


func test_the_heirlooms_may_be_offered_by_name() -> void:
	_after_the_king()
	st.set_flag("ct_plea_done")
	st.set_flag("party_size", 1)
	st.give_item("phillips_cane", 1)
	_play("crooked_tree/ritual:menu", ["Begin the ritual", "Offer Phillip's cane", "No one takes"])
	assert_false(st.party_has_item("phillips_cane"), "the cane is really given up")
	assert_eq(_s("sacrifice_1"), "item")


# ---- Adela's ember -------------------------------------------------------------------------------------------------------------------

func test_the_ember_is_stood_beside_or_met_with_silence_and_either_way_the_tree_burns() -> void:
	_after_the_king()
	st.set_flag("kehlenn_bound")
	_play("crooked_tree/ember:start", ["Stand beside her"])
	assert_eq(st.quest_stage("adelas_ember"), "lit")
	assert_true(_flag("ct_tree_burned") and _flag("ct_ember_done"))
	assert_eq(st.quest_stage("the_crooked_tree"), "bound")
	GameState.reset(); st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 13))
	_after_the_king()
	st.set_flag("kehlenn_bound")
	_play("crooked_tree/ember:start", ["Say nothing"])
	assert_eq(st.quest_stage("adelas_ember"), "unlit")
	assert_true(_flag("ct_tree_burned"), "she lights it alone")


func test_the_burnt_tree_can_be_looked_at() -> void:
	_after_the_king()
	st.set_flag("ct_tree_burned")
	_play("crooked_tree/king:tree_burnt")
	assert_true(_holds(_entry("exits", "id", "to_wood")["when"]), "the way back out opens once the tree has burned")


# ---- the places ---------------------------------------------------------------------------------------------------------------------

func _reachable(rows: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var p: Vector2i = q.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var n := p + d
			if n.y < 0 or n.y >= rows.size() or n.x < 0 or n.x >= str(rows[n.y]).length() or seen.has(n):
				continue
			if str(rows[n.y])[n.x] in ".~=_1234":
				seen[n] = true
				q.append(n)
	return seen


func test_every_place_can_be_walked_from_its_spawn_to_its_ways_out_and_its_people() -> void:
	for id: String in ["ct_wytchwood", "ct_hovel", "ct_crooked_tree", "ct_barrow", "ct_master_suite"]:
		st.location = id
		var loc := _loc()
		var spawn: Array = loc["spawns"]["default"]
		var seen := _reachable(loc["map"]["rows"], Vector2i(int(spawn[0]), int(spawn[1])))
		for e: Variant in loc["exits"]:
			var c: Array = (e as Dictionary)["cell"]
			assert_true(seen.has(Vector2i(int(c[0]), int(c[1]))), "%s: exit %s is reachable" % [id, (e as Dictionary)["id"]])
		for n: Variant in loc["npcs"]:
			var c: Array = (n as Dictionary)["cell"]
			assert_true(seen.has(Vector2i(int(c[0]), int(c[1]))), "%s: %s is reachable" % [id, (n as Dictionary)["npc"]])
		for p: Variant in loc["props"]:
			if str((p as Dictionary)["kind"]) != "decor":
				var c: Array = (p as Dictionary)["cell"]
				assert_true(seen.has(Vector2i(int(c[0]), int(c[1]))), "%s: prop %s is reachable" % [id, (p as Dictionary)["id"]])


func test_the_wood_has_seven_glades_and_five_hungry_woods_boards() -> void:
	st.location = "ct_wytchwood"
	var areas := (_loc()["areas"] as Array).map(func(a: Variant) -> String: return str((a as Dictionary)["id"]))
	for a: String in ["w1_edge", "w2_creek", "w3_thicket", "w4_hovel", "w5_grove", "w6_goat", "w7_heart"]:
		assert_true(a in areas, "the wood has %s" % a)
	var boards := 0
	for e: Variant in _loc()["encounters"]:
		if str((e as Dictionary)["id"]).begins_with("ct_hw_"):
			boards += 1
	assert_eq(boards, 5)
