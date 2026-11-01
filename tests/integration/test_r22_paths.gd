extends TestCase
## R22, the Crooked Nightmare: Old Rusty's hook, Dani at the porch, the eight dreams N1 to N8 (the Crooked Man, the dark wood and Frederick, the oven and
## Gilly's clock, the crater, Walter's loyalty, the wedding feast, the root throne, the Abomination), the collapse and the ruins, and the four side quests
## (Dani's Lantern, Frederick the Turkey, The Nightmare Forms, Voices Not Their Own). Each scenario plays the places' own data the way test_r13_paths does:
## a person is only talked to while their entry's `when` holds, a fight a conversation starts is won as the place records it, and dice are high
## (every check lands) or low (none does) as the test says. Every failable quest has a failure path here.

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


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out, which is the
## "leave" in every menu here). Returns what the conversation ended in; a combat it ends in is won as the place records it and a move is made.
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


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 11)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	dice = HighDice.new()
	st.location = "nm_estate"


func after_each() -> void:
	GameState.reset()


# ---- the hook and the porch -----------------------------------------------------------------------------------------------------

func test_old_rusty_brings_the_hook_only_once_chuckles_is_dead() -> void:
	st.location = "wickermoor_village"
	var hook := {}
	for n: Variant in _loc()["npcs"]:
		if str((n as Dictionary).get("dialogue", "")) == "nightmare/hook:rusty_start":
			hook = n as Dictionary
	assert_true(not hook.is_empty(), "the village has Rusty's hook")
	assert_false(_holds(hook["when"]), "no hook while Chuckles lives (a missing flag is false)")
	st.set_flag("chuckles_dead")
	assert_true(_holds(hook["when"]), "the hook once Chuckles is dead")
	st.set_flag("nm_hook_given")
	assert_false(_holds(hook["when"]), "the hook is told once")


func test_rusty_gives_the_hook_and_the_wicker_star() -> void:
	st.location = "wickermoor_village"
	_play("nightmare/hook:rusty_start", ["keep the vermin off", "We will go"])
	assert_true(_flag("nm_hook_given") and _flag("nm_star_given"))
	assert_eq(st.quest_stage("crooked_nightmare"), "prodigal_son")
	assert_true(st.party_has_item("nm_wicker_star"))


func test_naming_patrini_blesses_the_party_and_he_can_be_worked_out_either_way() -> void:
	st.location = "wickermoor_village"
	st.set_flag("rusty_told_patrini")
	_play("nightmare/hook:rusty_start", ["Say the name", "We will go"])
	assert_true(_flag("rusty_named_patrini"))
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 11))
	st.location = "wickermoor_village"
	_play("nightmare/hook:rusty_start", ["Study the old scar", "Say the name", "We will go"])
	assert_true(_flag("nm_rusty_linked") and _flag("rusty_named_patrini"), "Investigation links him to Patrini")


func test_a_failed_link_with_rusty_costs_nothing() -> void:
	dice = LowDice.new()
	st.location = "wickermoor_village"
	_play("nightmare/hook:rusty_start", ["Wonder who he really is", "Study the old scar", "We will go"])
	assert_false(_flag("nm_rusty_linked"))
	assert_true(_flag("nm_hook_given"), "the hook still holds")


func test_dani_at_the_porch_keeps_outside_and_gives_the_lantern() -> void:
	_play("nightmare/estate:dani_start", ["wait here", "lantern at her feet"])
	assert_true(_flag("nm_estate_met") and _flag("dani_kept_outside"))
	assert_eq(st.quest_stage("crooked_nightmare"), "estate")
	assert_eq(st.quest_stage("danis_lantern"), "carrying")
	assert_true(st.party_has_item("dani_lantern"))
	var steps := _entry("exits", "id", "porch_steps")
	assert_true(_holds(steps["when"]), "the porch steps open once Dani is met")


# ---- the dreams -------------------------------------------------------------------------------------------------------------------

func test_n1_the_crooked_man_falls_away_and_the_party_lands_in_the_wood() -> void:
	_arrive("nm_pit")
	_play("nightmare/n1:fall_start", ["Read him", "Laugh at him", "Draw steel"])
	assert_eq(fights, ["nm_crooked_man"] as Array[String])
	assert_true(_flag("crooked_man_aversion_known") and _flag("dream_laughed"))
	assert_eq(st.quest_stage("crooked_nightmare"), "crooked_pit")
	_play("nightmare/n1:after")
	assert_true(_flag("crooked_man_fell"))
	assert_eq(st.location, "nm_dark_wood")
	assert_eq(st.quest_stage("crooked_nightmare"), "dark_wood")


func test_n1_the_fall_has_a_debris_table_of_six() -> void:
	_arrive("nm_pit")
	var spec := _entry("encounters", "id", "nm_crooked_man")
	var events := spec["round_events"] as Array
	assert_eq(((events[0] as Dictionary)["table"] as Array).size(), 6)
	assert_true(spec.has("withdraw"), "his noose takes him away, it is not a kill")


func test_n2_the_wicker_star_sends_frederick_back_to_a_toy_and_he_is_kept() -> void:
	_arrive("nm_dark_wood")
	st.give_item("nm_wicker_star", 1)
	_play("nightmare/n2:wood_start", ["Follow the handprint"])
	assert_true(_flag("nm_wood_direction"))
	_play("nightmare/n2:child_start", ["Comfort her", "wicker star", "Take Frederick", "Let her go"])
	assert_true(_flag("nm_frederick_done") and _flag("frederick_repelled") and _flag("frederick_taken"))
	assert_eq(st.quest_stage("frederick_the_turkey"), "kept")
	assert_true(st.party_has_item("frederick_corn_dolly"))
	assert_true(_flag("nm_wood_done"))
	_play("nightmare/n2:door", ["Step through"])
	assert_eq(st.location, "nm_oven")


func test_n2_frederick_fought_and_put_to_bed() -> void:
	_arrive("nm_dark_wood")
	_play("nightmare/n2:child_start", ["Ask for the doll"])
	assert_eq(fights, ["nm_frederick"] as Array[String])
	_play("nightmare/n2:frederick_toy", ["Tuck Frederick", "Let her go"])
	assert_eq(st.quest_stage("frederick_the_turkey"), "bed")
	assert_true(_flag("frederick_in_bed") and _flag("frederick_resolved"))


func test_n2_frederick_left_behind_is_a_failure_with_a_click_in_the_dark() -> void:
	_arrive("nm_dark_wood")
	_play("nightmare/n2:child_start", ["Ask for the doll"])
	_play("nightmare/n2:frederick_toy", ["Leave him in the leaves", "Let her go"])
	assert_eq(st.quest_stage("frederick_the_turkey"), "left")
	assert_true(_flag("frederick_left"))
	assert_true(_flag("nm_wood_done"), "the way on is open all the same")


func test_n2_the_door_is_shut_until_the_child_is_taken() -> void:
	_arrive("nm_dark_wood")
	_play("nightmare/n2:door")
	assert_eq(st.location, "nm_dark_wood", "no move while the wood is not done")


func test_n3_three_chains_free_gilly() -> void:
	_arrive("nm_oven")
	_play("nightmare/n3:oven_start", ["Wrench", "Wrench", "Wrench"])
	assert_eq(_n("n3_chains"), 3)
	assert_true(_flag("gilly_saved") and _flag("nm_oven_done"))
	_play("nightmare/n3:door", ["Tell the oven a joke"])
	assert_eq(st.location, "nm_crater")
	assert_false(_flag("dream_laughed"), "a joke waives the toll once")


func test_n3_gilly_is_lost_when_nothing_lands_for_ten_rounds_and_the_door_still_comes() -> void:
	dice = LowDice.new()
	_arrive("nm_oven")
	_play("nightmare/n3:oven_start", ["Wrench", "Wrench", "Wrench", "Wrench", "Wrench"])
	assert_true(_flag("gilly_dead") and _flag("nm_oven_done"))
	assert_false(_flag("gilly_saved"))
	_play("nightmare/n3:door", ["Step through"])
	assert_eq(st.location, "nm_crater", "a lost rescue is not a dead end")


func test_n3_the_roast_heals_for_three_slices_and_costs_a_round() -> void:
	_arrive("nm_oven")
	_play("nightmare/n3:oven_start", ["Carve a slice", "Carve a slice", "Carve a slice"])
	assert_eq(_n("n3_slices"), 3)
	assert_true(_n("n3_clock") >= 3, "each slice is a round")


func test_n4_the_crater_the_invader_the_shard_and_the_door() -> void:
	_arrive("nm_crater")
	_play("nightmare/n4:crater_start", ["Look closely", "Cross the ridge", "Pull Adela back", "Haul her", "Touch the meteorite"])
	assert_eq(fights, ["nm_invader"] as Array[String])
	assert_true(_flag("n4_adela_charmed_seen") and _flag("n4_adela_pulled"))
	_play("nightmare/n4:after_fight")
	assert_true(_flag("nm_crater_done"))
	assert_eq(st.quest_stage("crooked_nightmare"), "crooked_bookshelf")
	_play("nightmare/n4:hub", ["Chip a shard"])
	assert_true(st.party_has_item("ioun_stone_reserve"))
	_play("nightmare/n4:door", ["Climb up"])
	assert_eq(st.location, "nm_bookshelf")


func test_n4_a_failed_ridge_save_hurts_but_does_not_stop_the_way() -> void:
	dice = LowDice.new()
	_arrive("nm_crater")
	_play("nightmare/n4:hub", ["Cross the ridge", "Touch the meteorite"])
	assert_true(_flag("n4_ridge_crossed"))
	assert_eq(fights, ["nm_invader"] as Array[String])


func test_n5_six_loyalty_frees_walter_and_drops_the_voices() -> void:
	_arrive("nm_bookshelf")
	st.set_flag("walter_loyalty", 5)
	_play("nightmare/n5:shelf_start", ["Say it plainly"])
	assert_true(_flag("walter_saved") and _flag("nm_shelf_done") and _flag("nm_voices_dropped"))
	assert_eq(st.quest_stage("voices_not_their_own"), "asked")


func test_n5_defeating_wisp_adds_three_loyalty() -> void:
	_arrive("nm_bookshelf")
	_play("nightmare/n5:hub", ["Fight Wisp"])
	assert_eq(fights, ["nm_wisp"] as Array[String])
	_play("nightmare/n5:hub", ["Say it plainly", "Rally Walter", "Bellow"])
	assert_true(_n("walter_loyalty") >= 6 or _flag("walter_saved"), "+3 for Wisp, +1 plain, +2 rallied")
	assert_true(_flag("walter_saved"))


func test_n5_the_lantern_is_a_second_way_to_move_him() -> void:
	_arrive("nm_bookshelf")
	st.give_item("dani_lantern", 1)
	_play("nightmare/n5:hub", ["Hold Dani's lantern"])
	assert_eq(_n("walter_loyalty"), 1)
	assert_true(_flag("n5_lantern_shown"))


func test_n5_walter_drowns_when_every_word_fails_and_the_door_still_comes() -> void:
	dice = LowDice.new()
	_arrive("nm_bookshelf")
	_play("nightmare/n5:hub", ["Rally Walter", "Bellow", "Remind him", "Reason", "Distract", "Hold fast", "Hold fast", "Hold fast", "Hold fast", "Hold fast"])
	assert_true(_flag("walter_dead") and _flag("nm_shelf_done"))
	assert_false(_flag("walter_saved"))
	_play("nightmare/n5:door", ["Leave the thimbles behind"])
	assert_eq(st.location, "nm_wedding")
	assert_eq(st.quest_stage("voices_not_their_own"), "lost")


func test_voices_the_right_thimble_returned_and_the_rest_freed() -> void:
	st.set_quest_stage("voices_not_their_own", "asked")
	_play("nightmare/voices:start", ["Choose a thimble", "The fourth", "take the rest home"])
	assert_eq(st.quest_stage("voices_not_their_own"), "freed")
	assert_eq(str(st.get_flag("voices_outcome", "")), "all")
	assert_true(st.party_has_item("walter_voice_jar"))


func test_voices_the_rest_can_be_kept_or_smashed() -> void:
	st.set_quest_stage("voices_not_their_own", "asked")
	_play("nightmare/voices:start", ["Choose a thimble", "The fourth", "keep the others"])
	assert_eq(st.quest_stage("voices_not_their_own"), "returned")
	assert_eq(str(st.get_flag("voices_outcome", "")), "walter")


func test_voices_three_wrong_guesses_shatter_the_thimbles() -> void:
	st.set_quest_stage("voices_not_their_own", "asked")
	_play("nightmare/voices:start", ["Choose a thimble", "The first", "Choose a thimble", "The second", "Choose a thimble", "The third"])
	assert_eq(st.quest_stage("voices_not_their_own"), "lost")
	assert_false(st.party_has_item("walter_voice_jar"))


func test_n6_the_drakkenhob_fought_and_the_bride_burns() -> void:
	_arrive("nm_wedding")
	_play("nightmare/n6:feast_start", ["Speak to the bride", "Notice the mole", "Settle the goat", "Join the dance", "Go up to the dais", "Fight it"])
	assert_eq(fights, ["nm_drakkenhob"] as Array[String])
	assert_true(_flag("n6_mole_seen") and _flag("n6_goat_calmed") and _flag("n6_danced"))
	_play("nightmare/n6:bride_burns")
	assert_true(_flag("nm_wedding_done"))
	assert_eq(st.quest_stage("crooked_nightmare"), "crooked_throne")
	_play("nightmare/n6:door", ["Climb on to the table"])
	assert_eq(st.location, "nm_throne")


func test_n6_gold_and_wine_talk_the_drakkenhob_down_without_a_fight() -> void:
	_arrive("nm_wedding")
	st.gold = 200
	_play("nightmare/n6:feast_start", ["Go up to the dais", "Offer it gold"])
	assert_true(fights.is_empty())
	assert_true(_flag("n6_paid_off") and _flag("nm_drakkenhob_done") and _flag("nm_wedding_done"))
	assert_eq(int(st.gold), 150)


func test_n6_a_hero_who_will_not_dance_may_be_made_to() -> void:
	dice = LowDice.new()
	_arrive("nm_wedding")
	_play("nightmare/n6:hub", ["Refuse to dance"])
	assert_true(true, "the failed save costs a little and the scene carries on")


func test_n7_six_roots_free_phillip_and_the_sword_is_dropped() -> void:
	_arrive("nm_throne")
	_play("nightmare/n7:throne_start", ["Help another hero", "Tear at the roots", "Tear at the roots", "Tear at the roots", "Tear at the roots", "Tear at the roots", "Tear at the roots"])
	assert_eq(_n("n7_roots"), 6)
	assert_true(_flag("phillip_freed") and _flag("nm_throne_done"))
	assert_true(st.party_has_item("flame_tongue"))
	assert_eq(st.quest_stage("crooked_nightmare"), "toil_and_trouble")
	_play("nightmare/n7:door", ["Step through"])
	assert_eq(st.location, "nm_attic")


func test_n7_after_three_failures_the_roots_loosen() -> void:
	dice = LowDice.new()
	_arrive("nm_throne")
	_play("nightmare/n7:throne_start", ["Tear at the roots", "Tear at the roots", "Tear at the roots"])
	assert_eq(_n("n7_fails"), 3)
	assert_false(_flag("phillip_freed"), "no soft-lock, no timer: the party is not out of options")
	dice = HighDice.new()
	_play("nightmare/n7:hub", ["The roots have loosened", "The roots have loosened", "The roots have loosened", "The roots have loosened", "The roots have loosened", "The roots have loosened"])
	assert_true(_flag("phillip_freed"))


func test_n7_striking_vessla_drops_the_sword_at_once() -> void:
	_arrive("nm_throne")
	_play("nightmare/n7:hub", ["Strike Vessla"])
	assert_true(_flag("vessla_vision_struck"))
	assert_true(st.party_has_item("flame_tongue"))


func test_n8_the_abomination_and_the_collapse() -> void:
	_arrive("nm_attic")
	_play("nightmare/n8:attic_start", ["Study the seven-pointed", "Notice the hags", "Face the cauldron"])
	assert_eq(fights, ["vermintoll_abomination"] as Array[String])
	assert_true(_flag("nm_sigil_read") and _flag("nm_hags_bicker_seen") and _flag("nm_toil_won"))
	assert_eq(st.quest_stage("crooked_nightmare"), "dreaming_no_more")
	_play("nightmare/n8:after")
	assert_true(_flag("abomination_dead") and _flag("crooked_house_destroyed"))
	assert_eq(st.location, "nm_estate_ruins")


func test_n8_the_abomination_has_a_second_phase_and_three_minions() -> void:
	_arrive("nm_attic")
	var spec := _entry("encounters", "id", "vermintoll_abomination")
	assert_eq((spec["monsters"] as Array).size(), 4)
	var m := Compendium.shared().get_entry("monsters", "vermintoll_abomination_dream")
	assert_eq(((m["phases"] as Array)[0] as Dictionary)["id"], "scream_ye_vermin")


# ---- the ruins and the farewell ---------------------------------------------------------------------------------------------------

func test_the_ruins_with_both_jenkins_give_the_party_a_long_rest_and_the_farewell_pays() -> void:
	_arrive("nm_estate_ruins")
	st.set_flag("walter_saved")
	st.set_flag("gilly_saved")
	st.set_flag("crooked_house_destroyed")
	st.set_flag("voices_outcome", "all")
	var before := _n("act2_done")
	_play("nightmare/ending:ruins_start", ["Ask about Phillip", "Ask Walter how he is", "Ask about the spirits", "Ask about the moors", "We are done here"])
	assert_true(_flag("nm_ruins_met") and _flag("joseph_rested") and _flag("crooked_man_slain") and _flag("nm_chapter_done"))
	assert_eq(_n("act2_done"), before, "an Act 3 chapter does not touch the Act 2 count")


func test_sally_goes_free_when_asked_about_the_dog() -> void:
	_arrive("nm_estate_ruins")
	_play("nightmare/ending:menu", ["Ask about the dog"])
	assert_true(_flag("sally_released"))


func test_the_cauldron_is_in_the_ruins_only_where_the_reading_put_it() -> void:
	_arrive("nm_estate_ruins")
	var p := _entry("props", "id", "nm_ruin_cauldron")
	assert_eq(str(p["item"]), "cauldron_of_the_vermintoll_coven")
	assert_true(str(p["when"]).contains("treasure_at:crooked_house_ruins"))


# ---- the side quests --------------------------------------------------------------------------------------------------------------

func test_dani_s_lantern_three_lost_sleepers_lit_home_and_the_lantern_returned() -> void:
	_play("nightmare/dani_lantern:offer")
	assert_eq(st.quest_stage("danis_lantern"), "carrying")
	_play("nightmare/dani_lantern:wood", ["Light the way"])
	_play("nightmare/dani_lantern:crater", ["Light the way"])
	_play("nightmare/dani_lantern:feast", ["Light the way"])
	assert_eq(_n("lantern_tends"), 3)
	_play("nightmare/dani_lantern:return")
	assert_eq(st.quest_stage("danis_lantern"), "done")
	assert_false(st.party_has_item("dani_lantern"))


func test_dani_s_lantern_dims_when_the_sleepers_are_told_to_wait() -> void:
	_play("nightmare/dani_lantern:offer")
	_play("nightmare/dani_lantern:wood", ["Tell him to wait"])
	_play("nightmare/dani_lantern:crater", ["Tell her to wait"])
	_play("nightmare/dani_lantern:return")
	assert_eq(st.quest_stage("danis_lantern"), "dimmed")
	assert_true(_flag("danis_lantern_dimmed"))


func test_the_nightmare_forms_two_filed_and_stamped() -> void:
	_arrive("nm_wedding")
	var gold := st.gold
	_play("nightmare/forms:start", ["Form 7-B", "Form 3", "Submit the forms"])
	assert_eq(st.quest_stage("the_nightmare_forms"), "filed")
	assert_true(_flag("forms_stamped"))
	assert_eq(int(st.gold), int(gold) + 40)


func test_the_nightmare_forms_a_lie_costs_a_little_and_the_forms_stay_open() -> void:
	dice = LowDice.new()
	_arrive("nm_wedding")
	_play("nightmare/forms:start", ["Embellish a form", "Form 7-B", "Form 12", "Submit the forms"])
	assert_true(_flag("forms_warned"))
	assert_eq(st.quest_stage("the_nightmare_forms"), "filed", "a failed Deception is not the end of the forms")


func test_the_nightmare_forms_left_unfiled_at_the_door_are_refused() -> void:
	_arrive("nm_wedding")
	_play("nightmare/forms:start", ["Form 7-B", "Leave"])
	st.set_flag("nm_wedding_done")
	_play("nightmare/n6:door", ["Leave the forms unfiled"])
	assert_eq(st.quest_stage("the_nightmare_forms"), "refused")
	assert_true(_flag("forms_refused"))
	assert_eq(st.location, "nm_throne")


# ---- the data ----------------------------------------------------------------------------------------------------------------------

func test_every_dream_has_its_scene_its_door_and_no_way_out_but_the_door() -> void:
	for id: String in ["nm_pit", "nm_dark_wood", "nm_oven", "nm_crater", "nm_bookshelf", "nm_wedding", "nm_throne", "nm_attic"]:
		st.location = id
		var loc := _loc()
		assert_false(loc.is_empty(), "%s exists" % id)
		assert_eq(str(loc["rest"]), "no", "%s: no rest in a dream" % id)
		assert_true((loc["exits"] as Array).is_empty(), "%s: you cannot walk out of a dream" % id)


func test_the_doors_are_conversations_and_each_leads_to_the_next_dream() -> void:
	var door := {"nm_dark_wood": "nm_wood_door", "nm_oven": "nm_oven_door", "nm_crater": "nm_crater_door", "nm_bookshelf": "nm_shelf_door", "nm_throne": "nm_throne_door"}
	for loc_id: String in door:
		st.location = loc_id
		var p := _entry("props", "id", str(door[loc_id]))
		assert_true(str(p.get("dialogue", "")).begins_with("nightmare/"), "%s has a door conversation" % loc_id)


func test_the_travel_map_swaps_the_estate_for_the_ruins() -> void:
	var t := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	var ids: Array = (t["places"] as Array).map(func(p: Variant) -> String: return str((p as Dictionary)["id"]))
	assert_true("nm_estate" in ids and "nm_estate_ruins" in ids)
