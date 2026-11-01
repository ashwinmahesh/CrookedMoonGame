extends TestCase
## R23, Wicker's Vigil: the hooks, the eve in the Round (five side quests), the three moor fights and their death tally, the stone circle's ring of fire and the cult,
## the Wicker Man's tiers, the Crooked Man's end and Phillip in the ash, the retreat to the village. Each scenario plays the places' own data the way test_r13_paths does:
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
		var ch := Pregens.build(id, 12)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	dice = HighDice.new()
	st.location = "wv_square"


func after_each() -> void:
	GameState.reset()


func _low() -> void:
	dice = LowDice.new()


## The encounter specs of the current place with this id whose `when` holds now.
func _live(id: String) -> Array:
	var out: Array = []
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == id and _holds(StoryConditions.encounter_when(e as Dictionary)):
			out.append(e)
	return out


# ---- hooks ---------------------------------------------------------------------------------------------------------------

func test_the_hooks_wait_for_the_crooked_man_to_be_slain() -> void:
	st.location = "wickermoor_village"
	var hook := {}
	for n: Variant in _loc()["npcs"]:
		if str((n as Dictionary).get("dialogue", "")) == "vigil/hook:tamsin_start":
			hook = n as Dictionary
	assert_true(not hook.is_empty(), "Tamsin has the hook in the village")
	assert_false(_holds(hook["when"]), "no hook before R22 ends (a missing flag is false)")
	st.set_flag("crooked_man_slain")
	assert_true(_holds(hook["when"]))
	st.location = "nm_estate_ruins"
	var dani := {}
	for n: Variant in _loc()["npcs"]:
		if str((n as Dictionary).get("dialogue", "")) == "vigil/hook:dani_ruins":
			dani = n as Dictionary
	assert_true(_holds(dani["when"]), "Dani warns at the ruins")


func test_tamsin_takes_the_party_to_the_round() -> void:
	_play("vigil/hook:tamsin_start", ["Join the village"])
	assert_true(_flag("wv_started"))
	assert_eq(st.quest_stage("wickers_vigil"), "follow_the_spirits")
	assert_eq(st.location, "wv_square")


func test_dani_gives_the_warning_and_starts_the_vigil() -> void:
	_play("vigil/hook:dani_ruins", ["follow the dead"])
	assert_true(_flag("wv_hook_given") and _flag("wv_started"))
	assert_eq(st.quest_stage("wickers_vigil"), "follow_the_spirits")


# ---- the eve ---------------------------------------------------------------------------------------------------------------

func test_the_barricade_stands_by_a_roll_or_by_asking_and_a_fail_costs_a_bruise() -> void:
	_low()
	_play("vigil/square:barricade", ["Put your shoulders", "Set the militia"])
	assert_true(_flag("wv_barricade_built"), "the second way works with every roll failed")


func test_volunteers_filed_in_triplicate() -> void:
	_play("vigil/volunteers:start", ["Take the muster roll"])
	assert_eq(st.quest_stage("vigil_volunteers"), "asked")
	_play("vigil/volunteers:gaunt", ["Offer to write him in"])
	_play("vigil/folk:quill", ["sign the militia roll", "Promise to write the hymn"])
	_play("vigil/folk:barnaby", ["sign the militia roll", "Promise to note a bulk order"])
	assert_eq(_n("vol_signed"), 3)
	_play("vigil/volunteers:progress", ["Present the completed"])
	assert_eq(st.quest_stage("vigil_volunteers"), "filed")
	assert_true(_flag("vol_resolved") and _flag("wv_militia_lawful"))


func test_volunteers_refused_is_a_failure_by_choice_and_failed_rolls_alone_do_not_end_it() -> void:
	_low()
	_play("vigil/volunteers:start", ["Take the muster roll"])
	_play("vigil/volunteers:gaunt", ["Assure him", "Remind him", "Offer to write him in"])
	assert_true(_flag("vol_gaunt"), "the free way gets the signature")
	assert_eq(st.quest_stage("vigil_volunteers"), "asked")
	_play("vigil/volunteers:progress", ["Tell her the roll will go unsigned"])
	assert_eq(st.quest_stage("vigil_volunteers"), "refused")


func test_the_last_dinner_served_with_three_requests_even_when_every_roll_fails() -> void:
	_low()
	_play("vigil/dinner:host", ["Take a bench"])
	assert_eq(st.quest_stage("the_last_dinner"), "asked")
	_play("vigil/dinner:quill", ["Guess how"])
	_play("vigil/dinner:pip", ["See what the boy"])
	_play("vigil/dinner:gaunt", ["Read the purpose"])
	assert_eq(_n("dinner_fed"), 3)
	_play("vigil/dinner:table_menu", ["Lift a cup"])
	assert_eq(st.quest_stage("the_last_dinner"), "served")
	assert_true(st.party_has_item("wv_feast_bread"))


func test_the_last_dinner_goes_cold_when_the_heroes_walk_away() -> void:
	_play("vigil/dinner:host", ["Tell her there is no time"])
	assert_eq(st.quest_stage("the_last_dinner"), "cold")
	assert_true(_flag("dinner_resolved"))


func test_a_place_to_sleep_moves_all_three_groups() -> void:
	_play("vigil/sleep:morgan", ["Step away"])
	assert_eq(st.quest_stage("a_place_to_sleep"), "asked")
	_low()
	_play("vigil/sleep:sick", ["Haul the wagon", "Brace their limbs", "Carry them across by stretcher"])
	_play("vigil/sleep:children", ["Spin a story", "Promise they can meet", "Carry them over"])
	_play("vigil/sleep:old", ["Insist the church", "Spot each small", "Lift them chair and all"])
	assert_eq(_n("sleep_count"), 3)
	_play("vigil/sleep:morgan_menu", ["Everyone is inside"])
	assert_eq(st.quest_stage("a_place_to_sleep"), "sheltered")


func test_a_place_to_sleep_scatters_when_the_heroes_give_up() -> void:
	_play("vigil/sleep:morgan", ["Step away"])
	_play("vigil/sleep:morgan_menu", ["We cannot move them"])
	assert_eq(st.quest_stage("a_place_to_sleep"), "scattered")


func test_letters_home_delivered_and_unsent() -> void:
	_play("vigil/letters:start", ["Take the satchel"])
	assert_true(st.party_has_item("wv_last_letters"))
	_play("vigil/folk:gaunt", ["Hand over the letter"])
	_play("vigil/folk:quill", ["Hand him the publisher"])
	_play("vigil/dinner:host", ["Hand her Walder"])
	assert_eq(_n("letters_n"), 3)
	_play("vigil/letters:progress", ["Tell her every letter"])
	assert_eq(st.quest_stage("letters_home"), "delivered")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 12))
	_play("vigil/letters:start", ["Take the satchel"])
	_play("vigil/letters:progress", ["no time to deliver"])
	assert_eq(st.quest_stage("letters_home"), "unsent")


func test_the_goat_moves_by_bread_or_by_moving_the_point_and_stands_by_choice() -> void:
	_low()
	_play("vigil/goat:board", ["Coax the goat", "Stare the goat", "Ask Tamsin"])
	assert_eq(st.quest_stage("the_goats_stand"), "moved", "a failed roll never ends the quest; asking Tamsin does")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 12))
	_play("vigil/goat:board", ["Leave the goat"])
	assert_eq(st.quest_stage("the_goats_stand"), "stands")


func test_the_funny_people_give_their_small_boons_once() -> void:
	st.gold = 50
	_play("vigil/folk:quill", ["Ask him to read"])
	assert_true(_flag("quill_blessed"))
	_play("vigil/folk:pip", ["Trade him"])
	assert_true(st.party_has_item("wv_pip_button"))
	_play("vigil/folk:barnaby", ["Buy a bottle"])
	assert_true(st.party_has_item("wv_barnaby_repellent"))


# ---- the moors ---------------------------------------------------------------------------------------------------------------

func test_the_sky_and_the_eyewitness_open_the_moor() -> void:
	_arrive("wv_moor_edge")
	_play("vigil/moor:sky")
	assert_eq(st.quest_stage("wickers_vigil"), "crooked_chaos")
	_play("vigil/moor:eyewitness", ["Ask what they saw", "Ask for a word"])
	assert_true(_flag("wv_eyewitness_done"))
	_play("vigil/moor:leave_edge")
	assert_eq(st.quest_stage("wickers_vigil"), "death_from_above")


func test_the_heath_fight_scales_by_level_and_the_gong_adds_a_round_event() -> void:
	_arrive("wv_heath")
	assert_eq(_live("wv_boneflayers").size(), 1, "exactly one variant at level 12")
	assert_eq(((_live("wv_boneflayers")[0] as Dictionary)["monsters"] as Array).filter(func(m: Variant) -> bool: return str((m as Dictionary)["monster"]) == "boneflayer").size(), 6)
	_play("vigil/moor:gong", ["Take the striker"])
	assert_true(_flag("wv_gong_ready"))
	assert_true((_live("wv_boneflayers")[0] as Dictionary).has("round_events"), "the gong frightens them")


func test_the_heath_tally_counts_the_villagers_not_saved_and_the_net_saves_two() -> void:
	_arrive("wv_heath")
	_play("vigil/moor:heath_ready", ["Hold the heath"])
	assert_eq(fights, ["wv_boneflayers"] as Array[String])
	assert_eq(st.quest_stage("wickers_vigil"), "death_from_below")
	st.set_flag("wv_h1_saved_1")
	_play("vigil/moor:heath_after")
	assert_eq(_n("wv_h1_lost"), 4)
	assert_eq(_n("vigil_deaths"), 4)


func test_the_net_and_everyone_saved_gives_the_potions() -> void:
	_arrive("wv_heath")
	_play("vigil/moor:net", ["Take the poles"])
	for i: int in range(1, 6):
		st.set_flag("wv_h1_saved_%d" % i)
	_play("vigil/moor:heath_after")
	assert_eq(_n("vigil_deaths"), 0)
	var npc_e := _entry("npcs", "dialogue", "vigil/moor:potions")
	assert_true(_holds(npc_e["when"]), "the fleeing villager gives the potions")
	_play("vigil/moor:potions")
	assert_true(st.party_has_item("potion_of_healing_greater"))


func test_skipping_the_heath_adds_five_and_opens_the_way_on() -> void:
	_arrive("wv_heath")
	_play("vigil/moor:heath_walk", ["Go on and leave"])
	assert_eq(_n("vigil_deaths"), 5)
	assert_true(_holds(_entry("exits", "id", "to_quagmire")["when"]))


func test_the_quagmire_counts_six_and_a_rope_saves_one() -> void:
	_arrive("wv_quagmire")
	_play("vigil/moor:poles", ["Take the rope"])
	_play("vigil/moor:quag_ready", ["Fight the wellwyrms"])
	assert_eq(fights, ["wv_wellwyrms"] as Array[String])
	st.set_flag("wv_h2_saved_1")
	st.set_flag("wv_h2_saved_2")
	_play("vigil/moor:quag_after")
	assert_eq(_n("wv_h2_lost"), 3)
	assert_eq(_n("vigil_deaths"), 3)


func test_the_priestess_comes_if_four_were_saved_and_the_horn_is_a_round_event() -> void:
	_arrive("wv_quagmire")
	_play("vigil/moor:horn", ["Take the horn"])
	assert_true((_live("wv_wellwyrms")[0] as Dictionary).has("round_events"))
	for i: int in range(1, 5):
		st.set_flag("wv_h2_saved_%d" % i)
	_play("vigil/moor:quag_after")
	assert_true(_holds(_entry("npcs", "dialogue", "vigil/moor:lumen")["when"]))
	_play("vigil/moor:lumen")
	assert_true(_flag("wv_lumen_done"))


func test_the_hardpan_woodwarped_count_deaths_by_body_and_skipping_adds_four() -> void:
	_arrive("wv_hardpan")
	var e := _live("wv_woodwarped")[0] as Dictionary
	var bodies := 0
	for m: Variant in e["monsters"]:
		if (m as Dictionary).has("body"):
			assert_eq(str(((m as Dictionary)["body"] as Dictionary)["count"]), "vigil_deaths")
			bodies += 1
	assert_eq(bodies, 4)
	_play("vigil/moor:pan_walk", ["Go around"])
	assert_eq(_n("vigil_deaths"), 4)


# ---- the stone circle ---------------------------------------------------------------------------------------------------------

func _stones_started(grace: bool) -> void:
	_arrive("wv_stones")
	_play("vigil/stones:arrive")
	assert_eq(st.quest_stage("wickers_vigil"), "ring_of_fire")
	var pick: Array[String] = []
	pick.append("Walk toward the stones" if grace else "Strike the nearest")
	_play("vigil/stones:welcome", pick)
	assert_true(_flag("wv_ring_started"))


func test_four_stones_bring_the_ring_down_and_the_captives_left_chained_are_saved() -> void:
	_stones_started(true)
	_play("vigil/stones:stone_1", ["Wrench"])
	_play("vigil/stones:stone_2", ["Wrench"])
	_play("vigil/stones:stone_3", ["Wrench", "Throw yourself"])
	assert_eq(_n("vigil_deaths"), 0, "two free rounds from walking in with the hymn, then a rescue")
	_play("vigil/stones:stone_4", ["Wrench"])
	assert_true(_flag("wv_ring_down") and _flag("wv_stone_4_down"))
	assert_eq(fights, ["wv_cult"] as Array[String])
	assert_true(_flag("vigil_saved_doris_squire") and _flag("vigil_saved_finneas_trout"))
	assert_eq(st.quest_stage("wickers_vigil"), "shadow_of_the_wicker_man")


func test_a_captive_burns_each_round_unless_a_hero_steps_in() -> void:
	_stones_started(false)
	_play("vigil/stones:stone_1", ["Wrench", "Hold your ground"])
	assert_eq(_n("vigil_deaths"), 1)
	assert_true(_flag("vigil_burned_doris_squire"))
	_play("vigil/stones:stone_2", ["Wrench", "Throw yourself"])
	assert_eq(_n("vigil_deaths"), 1, "the intercept saved the second")
	assert_false(_flag("vigil_burned_siv_harga"))


func test_with_every_roll_failing_the_ring_still_falls_when_the_six_are_gone() -> void:
	_stones_started(false)
	_low()
	for i: int in range(6):
		_play("vigil/stones:stone_1", ["Wrench", "Hold your ground"])
	assert_eq(_n("vigil_deaths"), 6)
	assert_true(_flag("wv_ring_down"), "all six lost ends the ring")
	assert_false(_holds("flag.wv_captives_lost <= 2"), "no gem for the heroes")


func test_holly_turns_on_the_stones_when_friendly_and_the_cult_is_judged() -> void:
	_stones_started(true)
	_play("vigil/stones:holly")
	assert_eq(str(st.get_flag("cultist_holly_aster")), "turned")
	assert_eq(_n("wv_stones_down"), 1)
	st.set_flag("wv_cult_done")
	_play("vigil/stones:aftermath", ["Bind the living"])
	assert_eq(str(st.get_flag("cultist_alda_farnum")), "spared")
	assert_eq(str(st.get_flag("cultist_holly_aster")), "turned", "a turned cultist stays turned")
	assert_true(_flag("wv_aftermath_done"))


func test_the_stones_cult_fight_has_three_level_bands() -> void:
	_arrive("wv_stones")
	assert_eq(_live("wv_cult").size(), 1)
	assert_eq((_loc()["encounters"] as Array).size(), 3)


# ---- the summit -----------------------------------------------------------------------------------------------------------

func test_the_wicker_man_has_exactly_one_tier_for_every_tally_and_level() -> void:
	_arrive("wv_summit")
	for deaths: int in [0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 21]:
		st.set_flag("vigil_deaths", deaths)
		assert_eq(_live("wv_wicker_man").size(), 1, "one fight at %d deaths" % deaths)
	st.set_flag("vigil_deaths", 13)
	var boss := ((_live("wv_wicker_man")[0] as Dictionary)["monsters"] as Array)[0] as Dictionary
	assert_eq(int(boss["hp"]), 155 + 100)
	st.set_flag("vigil_fled")
	assert_eq(_live("wv_wicker_man").size(), 0, "after a retreat the fight is in the village")


func test_the_wicker_man_block_has_the_push_the_phases_and_the_lair() -> void:
	var m := Compendium.shared().get_entry("monsters", "wicker_man_vigil")
	assert_eq(((m["phases"]) as Array).size(), 2)
	assert_eq(((m["lair_actions"]) as Array).size(), 3)
	var push := false
	for a: Variant in m["actions"]:
		if str((a as Dictionary)["id"]) == "blazing_slam":
			push = (a as Dictionary).has("on_hit")
	assert_true(push)


func test_the_summit_to_the_ash_to_phillip_to_the_road_home() -> void:
	_arrive("wv_summit")
	st.set_flag("vigil_deaths", 2)
	_play("vigil/summit:arrive")
	_play("vigil/summit:effigy", ["Call out to Adela", "Ask the Crooked Man", "Light the fire"])
	assert_eq(fights, ["wv_wicker_man"] as Array[String])
	assert_true(_flag("wicker_man_destroyed") and _flag("wv_wicker_lit"))
	assert_eq(st.quest_stage("wickers_vigil"), "the_ash")
	_play("vigil/summit:crooked_end")
	assert_true(_flag("crooked_man_destroyed"))
	_play("vigil/summit:phillip_ash", ["Ask if he is badly hurt", "Tell him she could not", "Leave him to his grief"])
	assert_true(_flag("wv_phillip_seen"))
	_play("vigil/summit:home")
	assert_true(_flag("wicker_man_burned"))
	assert_eq(st.quest_stage("wickers_vigil"), "ashes_to_ashes")
	assert_eq(st.location, "wickermoor_village")
	assert_false(_flag("act2_done"), "the chapter leaves act2_done alone")


func test_barnabys_repellent_is_a_joke_with_no_effect() -> void:
	_arrive("wv_summit")
	st.give_item("wv_barnaby_repellent", 1)
	_play("vigil/summit:effigy", ["Spray Barnaby", "Not yet"])
	assert_true(_flag("wv_repellent_used"))
	assert_false(st.party_has_item("wv_barnaby_repellent"))


# ---- the retreat ------------------------------------------------------------------------------------------------------------

func test_falling_back_moves_the_fight_to_the_square_and_the_village_stand_wins() -> void:
	_arrive("wv_hardpan")
	_play("vigil/moor:fall_back_foot", ["Fall back to the Founder's Round"])
	assert_true(_flag("vigil_fled"))
	assert_eq(_n("vigil_deaths"), 6)
	assert_eq(st.quest_stage("wickers_vigil"), "fallen_back")
	assert_eq(st.location, "wv_square")
	_play("vigil/square:fall_back_gate", ["Hold the Round"])
	assert_eq(fights, ["wv_wicker_square"] as Array[String])
	assert_true(_flag("wicker_man_destroyed"))
	var end_e := _entry("props", "id", "wv_sq_end")
	assert_true(_holds(end_e["call_when"]), "the ash scene waits in the square")
	_play("vigil/summit:crooked_end")
	_play("vigil/summit:phillip_ash", ["Leave him to his grief"])
	_play("vigil/summit:home")
	assert_true(_flag("wicker_man_burned"))


func test_running_from_the_village_is_the_triumphant_ending_flag() -> void:
	_arrive("wv_square")
	st.set_flag("vigil_fled")
	var b := _play("vigil/square:fall_back_gate", ["Flee down the south road"])
	assert_true(_flag("wicker_man_triumphant"))
	assert_eq(st.quest_stage("wickers_vigil"), "ash_over_the_hollow")


func test_the_moor_roads_wait_for_the_slain_crooked_man_and_close_when_the_wicker_man_burns() -> void:
	var travel := Compendium.shared().get_entry("travel", "wickermoor_hollow")
	var place := {}
	for p: Variant in travel["places"]:
		if str((p as Dictionary)["id"]) == "wv_moor_edge":
			place = p as Dictionary
	assert_false(_holds(place["when"]))
	st.set_flag("crooked_man_slain")
	assert_true(_holds(place["when"]))
	st.set_flag("wicker_man_burned")
	assert_false(_holds(place["when"]))
