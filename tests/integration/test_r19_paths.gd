extends TestCase
## R19, Maidenmist Cemetery: the raid and Mori's request, the gate and the Corpse Road, Yorgrim's briefing, the five kindling searches and Final
## Rites (won, lost and re-tried), the Balefire Chamber's count, the undercroft and depths, the Harrowing and the Azure Rites, Isolde's clock and
## walk, and the side quests (Doris's Militia, Names on Stones, The Epitaph Competition). Every conversation is played through the
## DialogueRunner with dice that always roll high (every check lands) or always roll low (every check fails), the way test_r13_paths does.

const GAME := preload("res://world/game_root.gd")
const HOOK_FLAGS: Array[String] = ["gorthos_slain", "raum_slain", "renathyr_slain", "lethica_slain", "briggsy_slain"]
const COLORS: Array[String] = ["crimson", "violet", "amber", "magenta", "emerald"]
const THEMES := {
	"crimson": ["Tell of the rides and the fights", "Speak the oath he kept", "Speak of the one who calmed him"],
	"violet": ["Speak of the cures she made", "Write the letter she never sent", "Sing the Nightmother's hymn"],
	"amber": ["Play one of his songs", "Tell one of his tall tales", "Speak of the work of his hands"],
	"magenta": ["Tell of his voyages", "Speak of his ruses and his swordwork", "Speak of his luck at the tables"],
	"emerald": ["Speak of her circle and the Green Queen", "Speak of the creatures she tended", "Carve something for Gwenna"],
}
const SITES := {"crimson": "mm_highborn_crypts", "violet": "mm_cremation_gardens", "amber": "mm_potters_field", "magenta": "mm_mausoleum_lanes", "emerald": "mm_burial_mounds"}
const MEM := {
	"crimson": ["mem_marius_feats", "mem_marius_oath", "mem_marius_love"], "violet": ["mem_lethica_healing", "mem_lethica_love", "mem_lethica_hymns"],
	"amber": ["mem_jericho_songs", "mem_jericho_tales", "mem_jericho_craft"], "magenta": ["mem_briggsy_exploits", "mem_briggsy_ruses", "mem_briggsy_luck"],
	"emerald": ["mem_farryn_circle", "mem_farryn_forest_love", "mem_farryn_gwenna"],
}

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


func _entry_for(loc_id: String, dialogue: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", loc_id).get("npcs", []):
		if str((e as Dictionary).get("dialogue", "")) == dialogue:
			return e as Dictionary
	return {}


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out).
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


## The option texts of the first menu `ref` reaches (after the picks), without choosing.
func _menu(ref: String, picks: Array[String] = []) -> Array[String]:
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	for i in 300:
		if str(b["kind"]) == "end":
			return []
		if str(b["kind"]) == "options":
			var opts := b["options"] as Array
			if left.is_empty():
				var out: Array[String] = []
				for o: Variant in opts:
					if bool((o as Dictionary)["enabled"]):
						out.append(str((o as Dictionary)["text"]))
				return out
			var want := str(left.pop_front())
			var pick := -1
			for j in opts.size():
				if bool((opts[j] as Dictionary)["enabled"]) and str((opts[j] as Dictionary)["text"]).contains(want):
					pick = j
					break
			if pick < 0:
				return []
			b = r.choose(pick)
		elif str(b["kind"]) == "guidance":
			b = r.answer_guidance(-1)
		else:
			b = r.next()
	return []


## The encounter `id` of this place won, as LocationFights._end_encounter records a victory (the variant whose `when` holds).
func _win(id: String) -> void:
	var spec := {}
	var any := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) != id:
			continue
		if any.is_empty():
			any = e as Dictionary
		if _holds(StoryConditions.encounter_when(e as Dictionary)):
			spec = e as Dictionary
	if spec.is_empty():
		spec = any
	assert_true(not spec.is_empty(), "%s has the fight %s" % [st.location, id])
	if spec.is_empty():
		return
	fights.append(id)
	(st.loc_state(st.location)["encounters"] as Dictionary)[id] = true
	if spec.has("flag"):
		st.set_flag(str(spec["flag"]))
	if spec.has("quest"):
		st.set_quest_stage(str((spec["quest"] as Dictionary)["id"]), str((spec["quest"] as Dictionary)["stage"]))
	_last_fight = spec


var _last_fight: Dictionary = {}


func _arrive(id: String) -> void:
	st.location = id
	assert_true(not _loc().is_empty(), "%s is a place" % id)


func _hook() -> void:
	for f in HOOK_FLAGS:
		st.set_flag(f)


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 9)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	dice = HighDice.new()
	_last_fight = {}
	st.location = "wickermoor_village"


func after_each() -> void:
	GameState.reset()


# ---- Wickermoor: the raid and the request ----------------------------------------------------------------------------------------------

func test_the_raid_waits_for_the_last_fallen_and_names_every_flag_it_reads() -> void:
	var e := _entry_for("wickermoor_village", "maidenmist/raid:alarm")
	assert_true(not e.is_empty(), "Doris has the alarm entry")
	assert_false(_holds(e["when"]), "nothing yet")
	for f in HOOK_FLAGS.slice(0, 4):
		st.set_flag(f)
	assert_false(_holds(e["when"]), "four of the five are not enough")
	st.set_flag(HOOK_FLAGS[4])
	assert_true(_holds(e["when"]), "all five Fallen dead and the alarm rings")


func test_fighting_the_raid_starts_the_chapter_and_the_aftermath_closes_it() -> void:
	_hook()
	_play("maidenmist/raid:alarm", ["Fight beside the militia"])
	assert_eq(fights, ["mm_raid"] as Array[String])
	assert_eq(st.quest_stage("maidenmist_dead_rise"), "dusk_of_the_dead")
	_play("maidenmist/raid:aftermath")
	assert_true(bool(st.get_flag("mm_raid_done")))
	assert_eq(int(st.get_flag("act2_done", 0)), 0, "this chapter does not count as an Act II chapter")


func test_the_raid_can_be_put_off_up_to_four_nights_and_doubles_in_size() -> void:
	_hook()
	var small := 0
	var big := 0
	for e: Variant in (Compendium.shared().get_entry("locations", "wickermoor_village")["encounters"] as Array):
		if str((e as Dictionary)["id"]) == "mm_raid":
			var n := ((e as Dictionary)["monsters"] as Array).size()
			if str((e as Dictionary)["when"]).contains(">="):
				big = n
			else:
				small = n
	assert_eq(small, 8, "eight ghasts at first")
	assert_true(big > small, "more once the militia has lost nights")
	for i in 4:
		assert_true(_menu("maidenmist/raid:alarm_menu").any(func(t: String) -> bool: return t.contains("hold the lanes")), "night %d can still be put off" % i)
		_play("maidenmist/raid:delay")
		st.advance_minutes(601)
	assert_eq(int(st.get_flag("mm_nights_delayed", 0)), 4)
	assert_false(_menu("maidenmist/raid:alarm_menu").any(func(t: String) -> bool: return t.contains("hold the lanes")), "the fifth night cannot be put off")
	assert_eq(int(st.get_flag("mm_volunteers_lost", 0)), 8)


func test_doris_asks_again_only_after_the_night_has_passed() -> void:
	_hook()
	var e := _entry_for("wickermoor_village", "maidenmist/raid:alarm")
	_play("maidenmist/raid:delay")
	assert_false(_holds(e["when"]), "the night is still on")
	st.advance_minutes(601)
	assert_true(_holds(e["when"]), "next dusk she is back")


func test_the_militia_can_be_posted_well_or_badly_and_never_locks() -> void:
	_hook()
	_play("maidenmist/raid:alarm", ["Organise the militia", "Howie", "Hilda", "Jean", "Siv"])
	assert_eq(int(st.get_flag("mm_posts_held", 0)), 4)
	assert_eq(st.quest_stage("doris_militia"), "done")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 9))
	st.location = "wickermoor_village"
	_hook()
	_play("maidenmist/raid:alarm", ["Organise the militia", "Siv", "Siv", "Siv", "Hilda"])
	assert_eq(int(st.get_flag("mm_posts_held", 0)), 0)
	assert_eq(st.quest_stage("doris_militia"), "done", "wrong posts cost the village, not the quest")


func test_the_militia_can_be_left_to_doris_and_it_fails_visibly() -> void:
	_hook()
	_play("maidenmist/raid:alarm", ["Organise the militia", "Leave it to Doris"])
	assert_eq(st.quest_stage("doris_militia"), "lost")


func test_mori_asks_gives_salt_and_opens_the_road() -> void:
	_hook()
	st.set_flag("mm_raid_done")
	var e := _entry_for("wickermoor_funeral_home", "maidenmist/mori:request")
	st.location = "wickermoor_funeral_home"
	assert_true(_holds(e["when"]))
	_play("maidenmist/mori:request", ["We will go"])
	assert_true(bool(st.get_flag("mm_asked")))
	assert_eq(st.quest_stage("maidenmist_dead_rise"), "corpse_road")
	assert_true(_holds("item:grave_salt"), "the salt is in a pack")
	var travel := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	var place := {}
	for p: Variant in travel["places"]:
		if str((p as Dictionary)["id"]) == "maidenmist_gate":
			place = p as Dictionary
	assert_true(_holds(place["when"]), "the place is on the map once Mori has asked")
	assert_eq(str(place["location"]), "mm_gate")


# ---- the gate and the road ---------------------------------------------------------------------------------------------------------

func test_the_gate_chain_is_taken_whether_or_not_the_check_lands() -> void:
	_arrive("mm_gate")
	_play("maidenmist/road:gate_chain", ["Study how the chain broke"])
	assert_true(_holds("item:mm_iron_chain"))
	assert_true(bool(st.get_flag("mm_gate_burst_known")))
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 9))
	dice = LowDice.new()
	_arrive("mm_gate")
	_play("maidenmist/road:gate_chain", ["Study how the chain broke"])
	assert_true(_holds("item:mm_iron_chain"), "a failed look still takes the chain")
	assert_false(bool(st.get_flag("mm_gate_burst_known")))


func test_the_corpse_road_has_three_miles_and_a_fight_in_the_second() -> void:
	_arrive("mm_corpse_road")
	var loc := _loc()
	var area_ids: Array[String] = []
	for a: Variant in loc["areas"]:
		area_ids.append(str((a as Dictionary)["id"]))
	assert_eq(area_ids, ["mile_1", "mile_2", "mile_3"] as Array[String])
	_play("maidenmist/road:mile1")
	_play("maidenmist/road:mile3")
	var six := 0
	for e: Variant in loc["encounters"]:
		if str((e as Dictionary)["id"]) == "mm_mile2":
			six = ((e as Dictionary)["monsters"] as Array).size()
	assert_eq(six, 6)
	assert_true((loc["foe_spots"] as Array).size() >= 8)


func test_the_cold_of_the_third_mile_costs_a_failed_party_hours_not_the_road() -> void:
	_arrive("mm_corpse_road")
	dice = LowDice.new()
	_play("maidenmist/road:mile1")
	_play("maidenmist/road:mile3")
	assert_true(bool(st.get_flag("mm_mile3_done")))


# ---- Yorgrim and Isolde ---------------------------------------------------------------------------------------------------------------

func _meet_yorgrim() -> void:
	_arrive("mm_sepulcher")
	_play("maidenmist/isolde:door", ["Offer her a hand"])
	_play("maidenmist/yorgrim:arrive", ["Who are you", "What is this place", "Are you dead", "The hound", "What is the Shroud", "those things in the mist", "Your friends", "honour villains", "What do we do", "We will relight"])


func test_yorgrim_answers_every_question_then_joins_and_starts_isolde_s_sixteen_hours() -> void:
	_meet_yorgrim()
	assert_true(bool(st.get_flag("yorgrim_met")))
	assert_true(bool(st.get_flag("yorgrim_with_party")))
	assert_eq(st.quest_stage("maidenmist_dead_rise"), "beacons")
	assert_true(bool(st.get_flag("isolde_alive")))
	assert_true(st.minutes_since("isolde_alone_since") >= 0, "the clock is stamped")


func test_isolde_fades_after_sixteen_hours_and_the_lurkers_come() -> void:
	_meet_yorgrim()
	var fades := _entry_for("mm_sepulcher", "maidenmist/isolde:fades")
	assert_false(_holds(fades["when"]), "the clock has not run out")
	st.advance_minutes(15 * 60)
	assert_false(_holds(fades["when"]), "fifteen hours")
	st.advance_minutes(61 * 1)
	assert_true(_holds(fades["when"]), "sixteen hours and a minute")
	_play("maidenmist/isolde:fades")
	assert_true(bool(st.get_flag("isolde_faded")))
	assert_false(bool(st.get_flag("isolde_alive")))
	assert_true(bool(st.get_flag("mm_isolde_lurkers")))
	_win("mm_lurkers")
	assert_true(bool(st.get_flag("mm_lurkers_done")))


func test_yorgrim_can_be_asked_to_come_again() -> void:
	_meet_yorgrim()
	st.set_flag("yorgrim_with_party", false)
	_play("maidenmist/yorgrim:at_the_doors", ["Come with us"])
	assert_true(bool(st.get_flag("yorgrim_with_party")))


func test_the_clan_stones_tell_the_story_and_the_names() -> void:
	_arrive("mm_shadestone_sanctuary")
	_play("maidenmist/yorgrim:clan_stones")
	assert_true(bool(st.get_flag("yorgrim_told_story")))
	assert_true(bool(st.get_flag("mm_clan_names_learned")))
	var loc := _loc()
	assert_eq(str(loc["rest"]), "safe")


# ---- the five kindlings and the five rites -------------------------------------------------------------------------------------------------

func _get_kindling(color: String) -> void:
	_arrive(SITES[color])
	match color:
		"crimson":
			_play("maidenmist/sites:crypt_right", ["Pay the tithe"])
			_play("maidenmist/sites:rose_take")
		"violet":
			_play("maidenmist/sites:urn_right", ["Open it"])
		"amber":
			_play("maidenmist/sites:amber_find", ["Ask Yorgrim"])
			_play("maidenmist/sites:grave_right", ["Dig"])
		"magenta":
			_play("maidenmist/sites:vault_right", ["Force it"])
		"emerald":
			_play("maidenmist/sites:emerald_find", ["Ask Yorgrim"])
			_play("maidenmist/sites:mound_right", ["Dig"])
	_arrive(SITES[color])


const KINDLING := {"crimson": "mm_dried_rose", "violet": "mm_owl_feather", "amber": "mm_straw_bundle", "magenta": "mm_rum_bottle", "emerald": "mm_oak_branch"}


func _rite(color: String, rounds: int) -> void:
	var picks: Array[String] = []
	for i in rounds:
		picks.append(THEMES[color][i % 3])
		picks.append("the way you have heard it")
	_play("maidenmist/rites:%s_start" % color, picks)


func _light(color: String) -> void:
	_get_kindling(color)
	assert_true(_holds("item:" + KINDLING[color]), "%s kindling is in a pack" % color)
	_play("maidenmist/rites:%s_start" % color, ["Place the kindling"])
	assert_true(fights.has("mm_%s_rite" % color), "%s guardians fought" % color)
	assert_true(bool(st.get_flag("mm_%s_guardians_dead" % color)))
	_rite(color, 6)


func test_a_rite_without_memories_lights_a_glowing_beacon() -> void:
	_light("crimson")
	assert_eq(int(st.get_flag("beacon_crimson", 0)), 1)
	assert_eq(int(st.get_flag("mm_beacons_lit", 0)), 1)
	assert_false(_holds("item:mm_dried_rose"), "the kindling is used up")


func test_a_rite_backed_by_every_memory_roars() -> void:
	for m: String in MEM["crimson"]:
		st.set_flag(m)
	_light("crimson")
	assert_eq(int(st.get_flag("beacon_crimson", 0)), 3)


func test_a_rite_backed_by_two_themes_blazes() -> void:
	st.set_flag(MEM["violet"][0])
	st.set_flag(MEM["violet"][1])
	_light("violet")
	assert_eq(int(st.get_flag("beacon_violet", 0)), 2, "four of the six true words were remembered ones")


func test_all_five_beacons_open_the_sepulcher() -> void:
	for c in COLORS:
		_light(c)
	assert_eq(int(st.get_flag("mm_beacons_lit", 0)), 5)
	assert_true(bool(st.get_flag("sepulcher_open")))
	assert_eq(st.quest_stage("maidenmist_dead_rise"), "sepulcher")


func test_wrong_searches_add_a_reinforcement_and_a_right_one_still_finds_the_kindling() -> void:
	_arrive("mm_highborn_crypts")
	_play("maidenmist/sites:crypt_wrong_a", ["Pay the tithe"])
	_play("maidenmist/sites:crypt_wrong_c", ["Pay the tithe"])
	_play("maidenmist/sites:crypt_wrong_a", ["Pay the tithe"])
	assert_eq(int(st.get_flag("mm_crimson_fails", 0)), 2, "two reinforcements at most")
	_play("maidenmist/sites:crypt_right", ["Pay the tithe"])
	_play("maidenmist/sites:rose_take")
	_arrive("mm_highborn_crypts")
	_play("maidenmist/rites:crimson_start", ["Place the kindling"])
	assert_eq(fights, ["mm_crimson_rite"] as Array[String])
	var n := (_last_fight["monsters"] as Array).size()
	assert_eq(n, 7, "five night creatures and two ghouls")


func test_a_rite_that_runs_out_of_time_costs_a_soul_fragment_and_never_the_quest() -> void:
	_get_kindling("crimson")
	_play("maidenmist/rites:crimson_start", ["Place the kindling"])
	dice = LowDice.new()
	_rite("crimson", 10)
	assert_eq(int(st.get_flag("mm_soul_fragments", 0)), 1)
	assert_eq(int(st.get_flag("beacon_crimson", 0)), 0)
	assert_false(bool(st.get_flag("mm_yorgrim_spent")))
	_rite("crimson", 10)
	assert_eq(int(st.get_flag("mm_soul_fragments", 0)), 2)
	assert_true(bool(st.get_flag("mm_yorgrim_spent")), "after the second failed minute Yorgrim spends himself")
	dice = HighDice.new()
	_rite("crimson", 4)
	assert_eq(int(st.get_flag("beacon_crimson", 0)), 1, "four true words are enough now")


func test_the_banjo_and_every_memory_are_read_from_flags_that_may_not_exist() -> void:
	for m: String in MEM["amber"]:
		assert_false(bool(st.get_flag(m)), "%s defaults false" % m)
	_light("amber")
	assert_eq(int(st.get_flag("beacon_amber", 0)), 1)


func test_site_hazards_never_block_what_they_guard() -> void:
	_arrive("mm_cremation_gardens")
	dice = LowDice.new()
	_play("maidenmist/sites:fountain", ["Take the coins"])
	_play("maidenmist/sites:urn_wrong_a", ["Open it anyway"])
	_play("maidenmist/sites:urn_right", ["Open it"])
	assert_true(_holds("item:mm_owl_feather"))
	_arrive("mm_potters_field")
	_play("maidenmist/sites:amber_find", ["Read where the lights gather"])
	assert_true(bool(st.get_flag("mm_amber_found")), "a bad hour in the fog still finds the brazier")
	_arrive("mm_burial_mounds")
	_play("maidenmist/sites:emerald_find", ["Find the way through the mounds"])
	assert_true(bool(st.get_flag("mm_emerald_found")))
	_arrive("mm_mausoleum_lanes")
	_play("maidenmist/sites:vault_right", ["take the hex"])
	assert_true(_holds("item:mm_rum_bottle"), "a hexed door opens anyway")
	_play("maidenmist/sites:muck")
	_arrive("mm_burial_mounds")
	_play("maidenmist/sites:apple_tree", ["Eat one"])


func test_the_moth_the_nightshade_and_the_lavender_are_scavenged() -> void:
	_arrive("mm_mausoleum_lanes")
	_play("maidenmist/sites:moth_vault")
	assert_true(_holds("item:mm_moth_wing"))
	_arrive("mm_cremation_gardens")
	_play("maidenmist/sites:lavender")
	_play("maidenmist/sites:lilies")
	_arrive("mm_burial_mounds")
	_play("maidenmist/sites:nightshade")
	assert_true(_holds("item:mm_lavender and item:mm_lilies and item:mm_nightshade"))


# ---- the shortcuts and the hordes ----------------------------------------------------------------------------------------------------------

func test_the_gravestone_shortcuts_hold_eight_different_hordes() -> void:
	var ids: Dictionary = {}
	for g in ["mm_gravestones_a", "mm_gravestones_b"]:
		var loc := Compendium.shared().get_entry("locations", g)
		assert_true((loc["foe_spots"] as Array).size() >= 8)
		var enc := loc["encounters"] as Array
		assert_eq(enc.size(), 4)
		for e: Variant in enc:
			ids[str((e as Dictionary)["id"])] = ((e as Dictionary)["monsters"] as Array).size()
	assert_eq(ids.size(), 8)
	assert_eq(int(ids["mm_horde_ghost"]), 13)
	assert_eq(int(ids["mm_horde_wights"]), 8)


# ---- below the sepulcher ---------------------------------------------------------------------------------------------------------------------

func _set_beacons(levels: Array[int]) -> void:
	for i in 5:
		st.set_flag("beacon_" + COLORS[i], levels[i])


func test_the_balefire_chamber_counts_ten_shrouded_less_what_the_beacons_burn() -> void:
	_arrive("mm_balefire_chamber")
	_set_beacons([3, 3, 3, 3, 3])
	_play("maidenmist/descent:chamber")
	assert_eq(int(st.get_flag("mm_chamber_n", -1)), 0)
	assert_true(bool(st.get_flag("mm_chamber_done")), "five roaring beacons empty the room")
	assert_eq(fights.size(), 0)


func test_a_dim_set_of_beacons_leaves_the_whole_ten() -> void:
	_arrive("mm_balefire_chamber")
	_set_beacons([1, 1, 1, 1, 1])
	_play("maidenmist/descent:chamber")
	assert_eq(int(st.get_flag("mm_chamber_n", -1)), 10)
	assert_eq(fights, ["mm_chamber"] as Array[String])
	assert_eq((_last_fight["monsters"] as Array).size(), 10)


func test_blazing_and_roaring_each_burn_some_away() -> void:
	_arrive("mm_balefire_chamber")
	_set_beacons([3, 2, 2, 1, 1])
	_play("maidenmist/descent:chamber")
	assert_eq(int(st.get_flag("mm_chamber_n", -1)), 10 - 2 - 1 - 1)
	assert_eq((_last_fight["monsters"] as Array).size(), 6)


func test_the_rubble_clears_by_effort_or_by_hour() -> void:
	_arrive("mm_balefire_chamber")
	_play("maidenmist/descent:rubble", ["Clear it together"])
	assert_true(bool(st.get_flag("mm_rubble_cleared")))
	assert_eq(st.quest_stage("maidenmist_dead_rise"), "undercroft")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 9))
	dice = LowDice.new()
	_arrive("mm_balefire_chamber")
	_play("maidenmist/descent:rubble", ["Clear it together"])
	assert_true(bool(st.get_flag("mm_rubble_cleared")), "a failed haul takes an hour and still opens")


func test_the_undercroft_is_a_real_maze_with_dead_ends_that_drop_to_a_cave_with_a_way_on() -> void:
	_arrive("mm_undercroft")
	var loc := _loc()
	var cracks := 0
	for p: Variant in loc["props"]:
		if str((p as Dictionary)["id"]).begins_with("mm_crack"):
			cracks += 1
	assert_true(cracks >= 4, "cracked floors in the dead ends")
	dice = LowDice.new()
	var b := _play("maidenmist/descent:crack")
	assert_eq(st.location, "mm_necropolis_depths", "a fall lands in the depths")
	var exits := (_loc()["exits"] as Array)
	var to_descent := false
	for e: Variant in exits:
		if str((e as Dictionary)["to"]) == "mm_tomb":
			to_descent = true
	assert_true(to_descent, "the cave has its own way on")
	assert_true(b.has("move"))


func test_the_necrolisk_can_be_met_plain_or_sickened_by_herbs() -> void:
	_arrive("mm_necropolis_depths")
	_play("maidenmist/descent:depths_arrive", ["Hold still"])
	assert_eq(fights, ["mm_necrolisk"] as Array[String])
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 9))
	fights.clear()
	_arrive("mm_cremation_gardens")
	_play("maidenmist/sites:lavender")
	_play("maidenmist/sites:lilies")
	_arrive("mm_burial_mounds")
	_play("maidenmist/sites:nightshade")
	_arrive("mm_necropolis_depths")
	_play("maidenmist/descent:depths_arrive", ["Mix the herbs"])
	assert_eq(fights, ["mm_necrolisk_sick"] as Array[String])
	assert_false(_holds("item:mm_lavender"), "the herbs are used up")
	_play("maidenmist/descent:wall")
	assert_true(bool(st.get_flag("mm_wall_broken")))
	_play("maidenmist/descent:slime")
	assert_true(_holds("item:necrolisk_slime"))


# ---- the Harrowing and the Azure Rites ----------------------------------------------------------------------------------------------------------

func _to_the_tomb() -> void:
	_arrive("mm_tomb")
	st.set_flag("yorgrim_with_party")
	_play("maidenmist/descent:tomb_door", ["We are ready"])
	assert_true(bool(st.get_flag("mm_tomb_door_open")))
	assert_eq(st.quest_stage("maidenmist_dead_rise"), "harrowing")
	_play("maidenmist/descent:harrowing")


func test_yorgrim_breaks_and_the_reaper_is_fought() -> void:
	_to_the_tomb()
	assert_eq(fights, ["mm_harrowing"] as Array[String])
	assert_true(bool(st.get_flag("yorgrim_fallen")))
	assert_false(bool(st.get_flag("yorgrim_with_party")), "he is no longer a guest")
	assert_true(bool(st.get_flag("chained_reaper_destroyed")))
	assert_eq(st.quest_stage("maidenmist_dead_rise"), "azure_rites")
	var boss := (_last_fight["monsters"] as Array)[0] as Dictionary
	assert_eq(str(boss["monster"]), "chained_reaper_harrowing")
	assert_eq((boss["steps_down"] as Dictionary)["npc"], "yorgrim", "the reaper takes Yorgrim's place on the board")


func test_the_azure_rites_seal_the_tear_and_pay_the_milestone_once() -> void:
	_to_the_tomb()
	var picks: Array[String] = []
	for i in 6:
		picks.append(["Speak of his care for the dead", "Speak the names on his stone", "Speak of his friends and his hound"][i % 3])
		picks.append("from what you learned of him")
	_play("maidenmist/descent:azure_rites", picks)
	assert_true(bool(st.get_flag("shroud_tear_sealed")))
	assert_true(bool(st.get_flag("fallen_yorgrim_dead")))
	assert_eq(st.quest_stage("maidenmist_dead_rise"), "done")
	assert_eq(int(st.get_flag("act2_done", 0)), 0, "R19 is not an Act II chapter")


func test_a_run_of_bad_words_brings_the_shrouded_but_the_rites_can_still_be_finished() -> void:
	_to_the_tomb()
	dice = LowDice.new()
	var picks: Array[String] = []
	for i in 3:
		picks.append(["Speak of his care for the dead", "Speak the names on his stone", "Speak of his friends and his hound"][i % 3])
		picks.append("from what you learned of him")
	_play("maidenmist/descent:azure_rites", picks)
	assert_true(fights.has("mm_tear_wave"), "three misses bring a wave")
	assert_false(bool(st.get_flag("shroud_tear_sealed")))
	dice = HighDice.new()
	var more: Array[String] = []
	for i in 6:
		more.append(["Speak of his care for the dead", "Speak the names on his stone", "Speak of his friends and his hound"][i % 3])
		more.append("from what you learned of him")
	_play("maidenmist/descent:azure_rites", more)
	assert_true(bool(st.get_flag("shroud_tear_sealed")))


func test_the_boss_is_two_phase_with_cutscenes_that_exist() -> void:
	var m := Compendium.shared().get_entry("monsters", "chained_reaper_harrowing")
	var phases := m["phases"] as Array
	assert_eq(phases.size(), 1)
	assert_true(bool((phases[0]["when"] as Dictionary)["bloodied"]))
	assert_true(not Compendium.shared().get_entry("cutscenes", str(phases[0]["cutscene"])).is_empty())
	for c in ["mm_dusk_of_the_dead", "mm_broken_gate", "mm_gravedigger_door", "mm_beacon_lit", "mm_isolde_fades", "mm_penitent_pilgrim", "mm_six_beacons", "mm_stygian_descent",
			"mm_harrowing", "mm_azure_defiance", "mm_tear_sealed", "mm_isolde_farewell"]:
		var cs := Compendium.shared().get_entry("cutscenes", c)
		assert_eq((cs["images"] as Array).size(), 2, "%s has two scenes" % c)


# ---- the epilogue and the side quests ------------------------------------------------------------------------------------------------------------

func test_isolde_walks_the_beacons_and_finds_a_letter() -> void:
	st.set_flag("isolde_alive")
	_arrive("mm_sepulcher")
	_play("maidenmist/isolde:farewell")
	_play("maidenmist/epilogue:walk_ask", ["Walk with her"])
	assert_eq(st.quest_stage("isolde_walk"), "asked")
	_arrive("mm_highborn_crypts")
	_play("maidenmist/epilogue:walk_crimson")
	_arrive("mm_cremation_gardens")
	_play("maidenmist/epilogue:walk_violet")
	_arrive("mm_burial_mounds")
	_play("maidenmist/epilogue:walk_emerald")
	assert_eq(int(st.get_flag("mm_isolde_walk_sites", 0)), 3)
	_arrive("mm_shadestone_sanctuary")
	_play("maidenmist/epilogue:walk_end")
	assert_eq(st.quest_stage("isolde_walk"), "done")
	assert_true(_holds("item:yorgrims_letter"))


func test_leaving_isolde_waiting_fails_the_walk_with_a_visible_consequence() -> void:
	st.set_flag("isolde_alive")
	_play("maidenmist/epilogue:walk_ask", ["Not now", "Leave her"])
	assert_eq(st.quest_stage("isolde_walk"), "gone_quiet")
	assert_true(bool(st.get_flag("mm_isolde_walk_gone")))


func test_the_epitaph_competition_has_four_winners_and_a_way_to_call_it_off() -> void:
	st.location = "wickermoor_funeral_home"
	_play("maidenmist/folk:dibbs", ["anything we can help"])
	assert_eq(st.quest_stage("epitaph_competition"), "asked")
	_arrive("mm_cremation_gardens")
	_play("maidenmist/folk:epitaph_plaque_a")
	_play("maidenmist/folk:epitaph_judge", ["neighbours"])
	assert_eq(st.quest_stage("epitaph_competition"), "done")
	assert_eq(int(st.get_flag("mm_epitaph_winner", 0)), 2)
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 9))
	st.location = "wickermoor_funeral_home"
	_play("maidenmist/folk:dibbs", ["anything we can help"])
	_play("maidenmist/folk:epitaph_judge", ["Call it off"])
	assert_eq(st.quest_stage("epitaph_competition"), "lost")


func test_names_on_stones_can_be_done_by_hand_or_by_the_ledger_or_dropped() -> void:
	_play("maidenmist/folk:names_start")
	assert_eq(st.quest_stage("names_on_stones"), "asked")
	_arrive("mm_potters_field")
	_play("maidenmist/folk:names_graves", ["first token", "second token", "third token"])
	assert_true(bool(st.get_flag("mm_names_a")) and bool(st.get_flag("mm_names_b")) and bool(st.get_flag("mm_names_c")))
	_play("maidenmist/folk:names_tell_holly")
	_play("maidenmist/folk:names_tell_rusty")
	_play("maidenmist/folk:names_tell_thomasin")
	_play("maidenmist/folk:names_done")
	assert_eq(st.quest_stage("names_on_stones"), "done")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 9))
	_play("maidenmist/folk:names_start")
	dice = LowDice.new()
	_arrive("mm_potters_field")
	_play("maidenmist/folk:names_graves", ["first token"])
	_play("maidenmist/folk:names_graves", ["Ask Mori"])
	assert_true(bool(st.get_flag("mm_names_a")) and bool(st.get_flag("mm_names_c")), "the ledger places them when the tokens will not")
	_play("maidenmist/folk:names_drop")
	assert_eq(st.quest_stage("names_on_stones"), "lost")


func test_hester_wants_her_rent_and_the_grammar_stone_corrects() -> void:
	st.set_flag("mm_raid_done")
	_play("maidenmist/folk:hester", ["Pay the rent"])
	assert_true(bool(st.get_flag("mm_hester_paid")))
	_arrive("mm_gate")
	_play("maidenmist/folk:grammar_stone", ["Misspell"])


func test_the_epilogue_beats_hang_off_the_sealed_tear() -> void:
	st.set_flag("shroud_tear_sealed")
	for who in [["epilogue:adela", "adela_druskenvald"], ["epilogue:weston", "weston_murdoch"], ["epilogue:doris_after", "doris_squire"]]:
		var e := _entry_for("wickermoor_village", "maidenmist/" + str(who[0]))
		assert_true(not e.is_empty(), "%s has an entry" % who[0])
		assert_true(_holds(e["when"]))
		_play("maidenmist/" + str(who[0]))
	_play("maidenmist/mori:return")
	assert_true(bool(st.get_flag("mm_mori_caretaker")))
	_play("maidenmist/epilogue:golub_tease")
	assert_true(bool(st.get_flag("mm_epilogue_golub")))
