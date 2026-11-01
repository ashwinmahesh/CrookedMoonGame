extends TestCase
## R18, Hartsblight Forest: both hooks in Wickermoor, the commune and its Circle, the three stands, the wellspring, the den and the way home, each played through the DialogueRunner with dice that always roll high, the way test_r10_playthrough plays the
## Express: a person is only talked to while their entry's `when` holds and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")
const TOWN := "hb_patient_commune"

## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll 1: every check fails.
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


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once
## they run out, which is "leave" or "that's all" in every menu here). Returns what the conversation ended in.
func _play(ref: String, picks: Array[String] = []) -> Dictionary:
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	for i in 600:
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
						fail("%s: no option '%s' among %s" % [ref, want, opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))])
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
	if spec.has("quest"):
		st.set_quest_stage(str((spec["quest"] as Dictionary)["id"]), str((spec["quest"] as Dictionary)["stage"]))


func _arrive(id: String) -> void:
	st.location = id
	assert_true(not _loc().is_empty(), "%s is a place" % id)


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	st.location = TOWN


func after_each() -> void:
	GameState.reset()


func _has_flag(id: String) -> bool:
	return bool(st.get_flag(id))


func test_rain_hook_is_open_only_after_five_act_two_chapters() -> void:
	st.location = "wickermoor_village"
	var e := _entry("npcs", "dialogue", "hartsblight/hook:rain_start")
	assert_true(not e.is_empty(), "the village has Rain's hook")
	st.set_flag("act2_done", 4)
	assert_true(not _holds(e["when"]), "four chapters are not enough")
	st.set_flag("act2_done", 5)
	assert_true(_holds(e["when"]), "five chapters open it")
	_play("hartsblight/hook:rain_start", ["We will go"])
	assert_true(_has_flag("hb_asked"))
	assert_true(_has_flag("hb_rain_hook_accepted"))
	assert_eq(st.quest_stage("q_hartsblight"), "hook")
	assert_eq(int(st.get_flag("act2_done", 0)), 5, "the chapter does not count as an Act II chapter")


func test_refusing_rain_leaves_the_door_open_for_the_sporefall_offer() -> void:
	st.location = "wickermoor_village"
	st.set_flag("act2_done", 5)
	_play("hartsblight/hook:rain_start", ["Not yet"])
	assert_true(_has_flag("hb_refused"))
	assert_true(not _has_flag("hb_asked"))
	var again := _entry("npcs", "dialogue", "hartsblight/hook:rain_again")
	assert_true(_holds(again["when"]), "Rain asks again")
	st.location = "wickermoor_mayors_house"
	_play("hartsblight/hook:wendel_offer", ["We will end it"])
	assert_true(_has_flag("hb_sporefall"))
	assert_true(_has_flag("hb_asked"))
	assert_eq(st.quest_stage("q_hartsblight"), "hook")


func test_the_commune_circle_fought_or_left() -> void:
	_play("hartsblight/commune:arrival", ["Examine the bodies", "Study how they rotted", "Move on"])
	assert_true(_has_flag("hb_bodies_studied"))
	assert_eq(st.quest_stage("q_hartsblight"), "commune")
	_play("hartsblight/commune:circle_glimpse", ["Break up the ritual"])
	assert_eq(fights, ["hb_circle"] as Array[String])
	assert_true(_has_flag("hb_circle_done"))
	assert_eq(st.quest_stage("q_hartsblight"), "circle")


func test_walking_past_the_circle_lets_the_cloud_reach_the_village() -> void:
	_play("hartsblight/commune:circle_glimpse", ["Slip past"])
	assert_true(_has_flag("hb_circle_fled"))
	assert_true(_has_flag("hb_cloud_reached_village"))
	assert_eq(st.quest_stage("q_hartsblight"), "circle")
	st.location = "wickermoor_village"
	var sick := _entry("npcs", "dialogue", "hartsblight/village_after:rain_sick")
	st.set_flag("hb_asked")
	assert_true(_holds(sick["when"]), "Rain is tending the sick in the village")


func test_a_failed_search_of_the_bodies_costs_a_level_of_rot() -> void:
	dice = LowDice.new()
	_play("hartsblight/commune:arrival", ["Examine the bodies", "Study how they rotted", "Move on"])
	assert_eq(int(st.get_flag("hb_blight", 0)), 1)
	assert_true(not _has_flag("hb_bodies_studied"))


func test_the_last_harvest_done_and_given_up() -> void:
	_arrive("hb_commune_longhouse")
	_play("hartsblight/harvest:elder_start", ["We can help with the seeds"])
	assert_eq(st.quest_stage("hb_commune_harvest"), "asked")
	_play("hartsblight/harvest:seed_iron", ["Drive a trap"])
	_play("hartsblight/harvest:seed_fire", ["burn the mould off slowly"])
	_play("hartsblight/harvest:seed_song", ["Sing to the reeds"])
	assert_true(_has_flag("hb_seed_iron") and _has_flag("hb_seed_fire") and _has_flag("hb_seed_song"))
	var before := st.gold
	_play("hartsblight/harvest:elder_progress", ["Hand over the jar"])
	assert_eq(st.quest_stage("hb_commune_harvest"), "done")
	assert_true(st.gold > before)


func test_the_harvest_can_fail_visibly_and_every_seed_has_a_second_way() -> void:
	_play("hartsblight/harvest:elder_start", ["We can help with the seeds"])
	_play("hartsblight/harvest:elder_progress", ["We give up"])
	assert_eq(st.quest_stage("hb_commune_harvest"), "lost")
	_play("hartsblight/harvest:seed_iron", ["Pry a spike"])
	_play("hartsblight/harvest:seed_song", ["bare hands"])
	assert_true(_has_flag("hb_seed_iron") and _has_flag("hb_seed_song"))


func test_the_elder_gives_the_likeness_and_the_memory() -> void:
	_play("hartsblight/harvest:elder_start", ["hiding something", "Leave"])
	assert_true(_has_flag("hb_has_likeness"))
	assert_true(_has_flag("mem_farryn_gwenna"))
	before_each()
	_play("hartsblight/harvest:elder_start", ["keepsakes", "Leave"])
	assert_true(_has_flag("hb_has_likeness"), "there is a second way to the sketch")


func test_the_effigy_burns_and_a_failed_save_costs_a_level() -> void:
	_arrive("hb_altar_of_rot")
	_play("hartsblight/forest1:effigy", ["Burn the effigy down"])
	assert_true(_has_flag("hb_effigy_burned"))
	assert_eq(int(st.get_flag("hb_blight", 0)), 0)
	before_each()
	_arrive("hb_altar_of_rot")
	dice = LowDice.new()
	_play("hartsblight/forest1:effigy", ["Burn the effigy down"])
	assert_true(_has_flag("hb_effigy_burned"))
	assert_eq(int(st.get_flag("hb_blight", 0)), 1)


func test_the_stag_carcass_parleys() -> void:
	_arrive("hb_altar_of_rot")
	_play("hartsblight/forest1:altar_look", ["Speak to the carcass", "Why let us walk here", "End this talk"])
	assert_true(_has_flag("hb_parley1"))
	assert_true(_has_flag("mem_farryn_circle"))


func test_the_leash_hides_a_devilbone_button() -> void:
	_arrive("hb_pine_barrens")
	_play("hartsblight/forest1:leash", ["Search the roots"])
	assert_true(_has_flag("hb_button_found"))


func test_the_outcrop_camp_gives_its_loot_and_the_beetles_come_when_the_bottle_is_taken() -> void:
	_arrive("hb_infested_outcrop")
	_play("hartsblight/forest1:camp", ["Search the tents", "Read the field journal", "Study it for an hour", "Take the Eversmoking Bottle"])
	assert_true(_has_flag("hb_tents_searched"))
	assert_true(_has_flag("hb_journal_read"))
	assert_true(_has_flag("hb_camp_seen"))
	assert_eq(fights, ["hb_beetles"] as Array[String])
	assert_true(_has_flag("hb_beetles_done"))


func test_leaving_the_outcrop_after_the_camp_starts_the_beetles_anyway() -> void:
	_arrive("hb_infested_outcrop")
	st.set_flag("hb_camp_seen")
	var e := {}
	for x: Variant in _loc().get("encounters", []):
		if str((x as Dictionary)["id"]) == "hb_beetles_leave":
			e = x as Dictionary
	assert_true(not e.is_empty() and _holds(e["when"]), "the way out is watched once the camp is seen")


func test_halden_torso_speaks_and_the_hunt_is_solved_without_a_fight() -> void:
	_arrive("hb_noxious_hollow")
	_play("hartsblight/halden:journal_find")
	assert_eq(st.quest_stage("hb_halden_hunt"), "asked")
	_play("hartsblight/forest1:corpse", ["Wait a moment", "End this talk"])
	assert_true(_has_flag("hb_halden_torso_seen"))
	assert_true(_has_flag("hb_parley2"))
	_play("hartsblight/halden:journal_read", ["Follow the trail"])
	assert_eq(st.quest_stage("hb_halden_hunt"), "traced")
	_play("hartsblight/halden:den_prop", ["Lure them away"])
	assert_eq(st.quest_stage("hb_halden_hunt"), "done")
	assert_true(fights.is_empty())


func test_halden_hunt_has_a_second_way_when_the_trail_is_lost() -> void:
	_arrive("hb_noxious_hollow")
	_play("hartsblight/halden:journal_find")
	dice = LowDice.new()
	_play("hartsblight/halden:journal_read", ["Follow the trail", "Leave"])
	assert_eq(st.quest_stage("hb_halden_hunt"), "asked")
	_play("hartsblight/night:shriek", ["Stay put"])
	assert_eq(st.quest_stage("hb_halden_hunt"), "traced", "the screams themselves point to the ridge")


func test_the_hollow_has_the_owlbears_ready() -> void:
	_arrive("hb_noxious_hollow")
	_play("hartsblight/halden:den_prop", ["Burn the den"])
	assert_eq(fights, ["hb_owlbears"] as Array[String])


func test_the_ravine_crossed_clean_or_the_jellies_drop() -> void:
	_arrive("hb_oozing_ravine")
	_play("hartsblight/forest2:ravine", ["Cross single file"])
	assert_true(fights.is_empty())
	assert_true(_has_flag("hb_ravine_done"))
	before_each()
	_arrive("hb_oozing_ravine")
	dice = LowDice.new()
	_play("hartsblight/forest2:ravine", ["Cross single file"])
	assert_eq(fights, ["hb_jellies"] as Array[String])


func test_the_clear_pool_cleans_and_then_turns_on_the_greedy() -> void:
	_arrive("hb_stinking_quagmire")
	st.set_flag("hb_blight", 3)
	_play("hartsblight/forest2:pool", ["Immerse"])
	assert_eq(int(st.get_flag("hb_blight", 0)), 2)
	dice = LowDice.new()
	_play("hartsblight/forest2:pool", ["Immerse"])
	assert_true(_has_flag("hb_pool_fouled"))
	assert_eq(fights, ["hb_mounds"] as Array[String])


func test_the_gloomwood_can_be_talked_down_for_a_price_or_fought() -> void:
	_arrive("hb_fungal_grove")
	_play("hartsblight/forest2:gloom_start", ["Talk it down", "let you pass", "Leave it be"])
	assert_true(_has_flag("hb_gloomwood_talked_down"))
	assert_eq(int(st.get_flag("hb_blight", 0)), 4)
	assert_true(_has_flag("hb_parley3"))
	before_each()
	_arrive("hb_fungal_grove")
	_play("hartsblight/forest2:gloom_start", ["Fight it"])
	assert_eq(fights, ["hb_gloomwood"] as Array[String])


func test_the_gloomwood_is_blunted_by_the_greenwoods_name() -> void:
	_arrive("hb_fungal_grove")
	st.set_flag("hb_knows_greenwood")
	_play("hartsblight/forest2:gloom_start", ["Carve the name"])
	assert_true(_has_flag("hb_gloom_carved"))
	assert_eq(fights, ["hb_gloomwood"] as Array[String])


func test_the_druid_garb_skips_the_big_fight_at_the_druids_commune() -> void:
	_arrive("hb_druid_commune")
	var e := {}
	for x: Variant in _loc().get("encounters", []):
		if str((x as Dictionary)["id"]) == "hb_f5":
			e = x as Dictionary
	assert_true(_holds(e["when"]), "the commune fights an unmasked party")
	_play("hartsblight/forest2:dwelling", ["Try on the druid clothes", "Leave"])
	assert_true(_has_flag("hb_garb_taken"))
	assert_true(not _holds(e["when"]), "a disguised party passes")


func test_the_river_toll_is_paid_in_blood_or_in_rot() -> void:
	_arrive("hb_wellspring")
	_play("hartsblight/wellspring:river", ["Wade across"])
	assert_true(_has_flag("hb_river_paid"))
	before_each()
	_arrive("hb_wellspring")
	_play("hartsblight/wellspring:river", ["Drink and take the rot"])
	assert_eq(int(st.get_flag("hb_blight", 0)), 1)


func test_gwenna_rises_and_the_pool_remembers() -> void:
	_arrive("hb_wellspring")
	_play("hartsblight/wellspring:stones", ["Approach the pool"])
	assert_eq(fights, ["hb_festerhulk"] as Array[String])
	assert_true(_has_flag("hb_festerhulk_done"))
	_play("hartsblight/wellspring:pool_memory")
	assert_eq(int(st.get_flag("hb_blight", 0)), 2)
	assert_true(_has_flag("mem_farryn_gwenna"))
	var gate := _entry("exits", "id", "to_den")
	assert_true(_holds(gate["when"]), "the slime trail opens")


func test_the_forest_stands_open_in_order_and_the_dryad_shortens_them() -> void:
	_arrive("hb_altar_of_rot")
	var gate := _entry("exits", "id", "to_druids")
	assert_true(not _holds(gate["when"]))
	st.visited["hb_pine_barrens"] = true
	st.visited["hb_infested_outcrop"] = true
	assert_true(not _holds(gate["when"]), "two of three is not enough")
	st.set_flag("hb_dryad_shortcut")
	assert_true(_holds(gate["when"]), "the dryad's shortcut skips one")
	st.set_flag("hb_dryad_shortcut", false)
	st.visited["hb_noxious_hollow"] = true
	assert_true(_holds(gate["when"]), "all three open it")


func test_the_dead_of_night_plays_four_events_once_each() -> void:
	_arrive("hb_altar_of_rot")
	_play("hartsblight/night:camp", ["Make camp", "Follow the drums"])
	assert_eq(fights, ["hb_drums"] as Array[String])
	_play("hartsblight/night:camp", ["Make camp", "Listen to her", "Take the bargain"])
	assert_true(_has_flag("hb_shadow_bargain"))
	assert_eq(int(st.get_flag("hb_blight", 0)), 1)
	_play("hartsblight/night:camp", ["Make camp", "not a human voice"])
	assert_true(_has_flag("hb_heard_halden"))
	_play("hartsblight/night:camp", ["Make camp", "courtly bow", "We have nothing else"])
	assert_true(_has_flag("hb_dryad_friendly"))
	assert_true(_has_flag("hb_dryad_shortcut"))
	_play("hartsblight/night:camp", ["Make camp"])
	assert_eq(fights.size(), 1, "a fifth night is quiet")


func test_the_shadows_bargain_can_be_refused() -> void:
	_play("hartsblight/gorthos:shadow", ["Listen to her", "Refuse it"])
	assert_true(not _has_flag("hb_shadow_bargain"))
	assert_eq(int(st.get_flag("hb_blight", 0)), 0)


func test_the_dryad_reviews_grow_warmer_with_honesty() -> void:
	_play("hartsblight/harvest:elder_start", ["We can help with the seeds"])
	_play("hartsblight/dryad:dryad_review_start", ["Hold out a weapon", "kept us alive", "Offer a travel ration", "wet boot leather", "jar of seeds", "final verdict"])
	assert_eq(st.quest_stage("hb_dryad_review"), "done")
	assert_true(_has_flag("hb_dryad_cleansed"))


func test_a_cool_dryad_still_leaves_a_way_on() -> void:
	dice = LowDice.new()
	_play("hartsblight/dryad:dryad_arrive", ["courtly bow"])
	assert_true(_has_flag("hb_dryad_hostile"))
	_play("hartsblight/dryad:dryad_arrive", ["Show us something"])
	assert_eq(st.quest_stage("hb_dryad_review"), "asked")


func test_gwennas_garden_tended_moved_or_burned() -> void:
	_play("hartsblight/garden:bed_find", ["Tend the bed", "Water it from your own flask"])
	assert_eq(st.quest_stage("hb_gwennas_garden"), "done")
	assert_eq(str(st.get_flag("hb_garden_outcome", "")), "tended")
	before_each()
	_play("hartsblight/garden:bed_find", ["Dig it up", "Carry it in a sack"])
	assert_eq(str(st.get_flag("hb_garden_outcome", "")), "moved")
	before_each()
	_play("hartsblight/garden:bed_find", ["Burn it.", "for the commune"])
	assert_eq(st.quest_stage("hb_gwennas_garden"), "lost")
	assert_eq(str(st.get_flag("hb_garden_outcome", "")), "burned")


func test_brother_spore_has_a_secret_and_the_goat_does_not_mind() -> void:
	_play("hartsblight/spore:spore_start", ["You do not look well", "Leave"])
	assert_true(_has_flag("hb_spore_secret"))
	_play("hartsblight/spore:goat", ["Pet the goat"])
	assert_true(_has_flag("hb_goat_petted"))


func test_the_den_fight_after_a_hearing_and_the_farewell() -> void:
	_arrive("hb_den")
	_play("hartsblight/gorthos:den_arrive", ["Search the torso", "Hear her out", "Reject her"])
	assert_eq(fights, ["hb_gorthos"] as Array[String])
	assert_true(_has_flag("hb_gorthos_started"))
	assert_true(_has_flag("hb_gorthos_done"))
	st.set_flag("hb_blight", 5)
	_play("hartsblight/gorthos:den_farewell")
	assert_true(_has_flag("gorthos_slain"))
	assert_eq(int(st.get_flag("hb_blight", 9)), 0, "her death takes every level of rot")
	assert_eq(st.quest_stage("q_hartsblight"), "gorthos_destroyed")
	assert_eq(int(st.get_flag("act2_done", 0)), 0, "the forest is not an Act II chapter")


func test_the_den_has_a_cold_way_in_with_the_likeness() -> void:
	_arrive("hb_den")
	st.set_flag("hb_has_likeness")
	_play("hartsblight/gorthos:den_arrive", ["Strike first"])
	assert_eq(fights, ["hb_gorthos"] as Array[String])


func test_accepting_the_blight_takes_two_confirmations_and_a_hero() -> void:
	_arrive("hb_den")
	var before := st.party.size()
	_play("hartsblight/gorthos:den_plea", ["Accept the Blight", "No"])
	assert_eq(st.party.size(), before, "backing out on the first prompt costs nothing")
	_play("hartsblight/gorthos:den_plea", ["Accept the Blight", "I am sure", "No"])
	assert_eq(st.party.size(), before, "backing out on the second prompt costs nothing")
	assert_true(not _has_flag("hb_accepted_blight"))


func test_the_village_after_beat_pays_and_closes_the_quest() -> void:
	st.location = "wickermoor_village"
	st.set_flag("gorthos_slain")
	st.set_quest_stage("q_hartsblight", "gorthos_destroyed")
	_play("hartsblight/village_after:rain_report", ["We are done"])
	assert_eq(st.quest_stage("q_hartsblight"), "reported")
	assert_true(_has_flag("hb_rain_done"))
	st.location = "wickermoor_mayors_house"
	st.set_flag("hb_sporefall")
	var before := st.gold
	_play("hartsblight/village_after:wendel_pay")
	assert_true(_has_flag("hb_wendel_paid"))
	assert_true(st.gold > before)


func test_rain_asks_after_the_garden_by_how_it_ended() -> void:
	st.location = "wickermoor_village"
	st.set_flag("hb_garden_burned")
	_play("hartsblight/village_after:rain_garden")
	assert_true(_has_flag("hb_garden_told"))


func test_the_road_to_the_forest_is_on_the_travel_map() -> void:
	var t := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	var place := false
	var road := false
	for p: Variant in t["places"]:
		place = place or str((p as Dictionary)["id"]) == "hartsblight_forest"
	for r: Variant in t["roads"]:
		road = road or str((r as Dictionary)["id"]) == "wickermoor_to_hartsblight"
	assert_true(place and road)
