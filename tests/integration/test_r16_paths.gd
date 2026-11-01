extends TestCase
## R16, Skitterdeep Mine: the street scene and Morgan's request in Wickermoor, Mrs. Oakum who guides and turns, the parcel rider, the camp, the winch and the
## lift, the eyeball and the hoard, the miasma and the sigils, Stonoga, the farewell and the reopening, the plague's clock and the two side quests. Each is played
## through the DialogueRunner with dice that always roll high (and a failure path with dice that always roll 1), the way test_r13_paths plays Foxwillow.

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


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out, which is "leave" in
## every menu here). Returns what the conversation ended in.
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


## The version of the encounter `id` this place would run now (the first whose `when` holds, as LocationFights.spec_for picks).
func _spec(id: String) -> Dictionary:
	var spec := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == id and (spec.is_empty() or not _holds(StoryConditions.encounter_when(spec))):
			spec = e as Dictionary
	return spec


## The encounter `id` of this place won, as LocationFights._end_encounter records a victory.
func _win(id: String) -> void:
	var spec := _spec(id)
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


## Whether the person is placed here now (the first entry whose `when` holds is the one that stands there).
func _talks(npc_id: String, dialogue: String) -> bool:
	for e: Variant in _loc().get("npcs", []):
		var d := e as Dictionary
		if str(d.get("npc", "")) == npc_id and _holds(d.get("when", "")):
			return str(d.get("dialogue", "")) == dialogue
	return false


func _count(item: String) -> int:
	var n := 0
	for ch in st.party:
		for e: Dictionary in ch.inventory:
			if str(e["id"]) == item:
				n += int(e.get("qty", 1))
	for e: Dictionary in st.stash:
		if str(e["id"]) == item:
			n += int(e.get("qty", 1))
	return n


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	dice = HighDice.new()
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	st.location = "wickermoor_village"
	st.set_flag("act2_done", 1)


func after_each() -> void:
	GameState.reset()


# ---- Wickermoor: the street, Morgan, the clock ---------------------------------------------------------------------------------------

func test_the_street_scene_starts_the_clock_and_finds_the_trail() -> void:
	_play("skitterdeep/hook:bitten", ["Follow the tiny"])
	assert_true(bool(st.get_flag("bitten_seen")))
	assert_true(int(st.get_flag("plague_started", 0)) > 0, "the clock is stamped")
	assert_eq(int(st.get_flag("plague_toll", 0)), 10)
	assert_true(bool(st.get_flag("skitter_trail_known")))
	assert_eq(st.quest_stage("skitter_plague"), "trail_of_corruption")


func test_the_trail_has_a_second_way_when_both_checks_fail() -> void:
	dice = LowDice.new()
	_play("skitterdeep/hook:bitten", ["Follow the tiny", "Study the pattern", "Holly", "barber"])
	assert_false(bool(st.get_flag("skitter_trail_known")), "both failed rolls found nothing")
	assert_eq(st.quest_stage("skitter_plague"), "the_bitten", "and the quest is open, not locked")
	st.location = "wickermoor_apothecary"
	_play("skitterdeep/hook:morgan_asks", ["start", "We will go"])
	assert_true(bool(st.get_flag("skitter_trail_known")), "Morgan points the way")
	assert_true(bool(st.get_flag("skitter_asked")))
	assert_eq(st.quest_stage("skitter_plague"), "trail_of_corruption")


func test_morgan_asks_and_pays_up_front_when_the_party_never_saw_the_street() -> void:
	st.location = "wickermoor_apothecary"
	assert_true(_talks("morgan", "skitterdeep/hook:morgan_asks"), "Morgan asks once the first chapter is done")
	var before := _count("potion_of_healing_greater")
	_play("skitterdeep/hook:morgan_asks", ["start", "We will go"])
	assert_eq(_count("potion_of_healing_greater") - before, 4)
	assert_true(int(st.get_flag("plague_started", 0)) > 0)


func test_no_plague_before_a_chapter_is_done() -> void:
	st.set_flag("act2_done", 0)
	st.location = "wickermoor_apothecary"
	assert_false(_talks("morgan", "skitterdeep/hook:morgan_asks"), "Morgan has nothing to ask yet")


func test_the_clock_runs_nights_while_the_party_is_away() -> void:
	st.day = 1
	st.minute_of_day = 20 * 60
	st.set_flag("plague_started", st.total_minutes())
	Schedule.memory(st)
	st.advance_minutes(24 * 60 * 2 + 30)
	Schedule.catch_up(st, "sk_camp")
	assert_eq(int(st.get_flag("plague_day", 0)), 2)
	assert_eq(int(st.get_flag("plague_toll", 0)), 12)
	st.advance_minutes(24 * 60 * 2)
	Schedule.catch_up(st, "sk_camp")
	assert_eq(int(st.get_flag("plague_day", 0)), 4)
	assert_eq(int(st.get_flag("plague_toll", 0)), 16)
	st.set_flag("stonoga_slain")
	st.advance_minutes(24 * 60)
	Schedule.catch_up(st, "sk_camp")
	assert_eq(int(st.get_flag("plague_day", 0)), 4, "the plague stops spreading once Stonoga is dead")


func test_the_pigeon_finds_a_party_that_is_away() -> void:
	st.day = 1
	st.minute_of_day = 20 * 60
	st.set_flag("plague_started", st.total_minutes())
	Schedule.memory(st)
	st.location = "sk_hills_trail"
	st.advance_minutes(36 * 60)   # day 3, the Twilight Hour: the pigeon comes on its hour, a day and a half in
	var shown := Schedule.catch_up(st, "sk_hills_trail")
	var letters := shown.filter(func(d: Dictionary) -> bool: return str((d["event"] as Dictionary)["id"]) == "sk_letter_pigeon_sk_hills_trail")
	assert_eq(letters.size(), 1, "the letter pigeon plays out on the trail")
	_play("skitterdeep/letter:arrives", ["Make for"])
	assert_true(bool(st.get_flag("skitter_letter_hook")))
	assert_true(bool(st.get_flag("skitter_trail_known")))
	assert_eq(_count("theodora_letter"), 1)


func test_the_midnight_swarm_is_a_fight_or_a_flight() -> void:
	_play("skitterdeep/clock:midnight_swarm", ["fight"])
	assert_eq(fights, ["sk_midnight_swarm"] as Array[String])
	assert_true(bool(st.get_flag("sk_midnight_done")))
	fights.clear()
	st.set_flag("sk_midnight_done", false)
	_play("skitterdeep/clock:midnight_swarm", ["Run"])
	assert_true(fights.is_empty())
	assert_true(bool(st.get_flag("sk_midnight_done")), "the swarm carried the body off")


func test_the_round_fight_scales_with_the_party_level() -> void:
	var low := _spec("sk_round_swarms")
	assert_eq((low["monsters"] as Array).size(), 2, "level 3 meets two swarms")
	st.party.clear()
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		st.party.append(ch)
	var high := _spec("sk_round_swarms")
	assert_eq((high["monsters"] as Array).size(), 4, "level 7 meets four")


# ---- Mrs. Oakum ----------------------------------------------------------------------------------------------------------------------

func test_oakum_tells_the_tale_gives_lye_and_guides() -> void:
	st.set_flag("bitten_seen")
	assert_true(_talks("mrs_oakum", "skitterdeep/guide:offer"), "Oakum comes to the party after the street")
	_play("skitterdeep/guide:offer", ["father", "guide"])
	assert_eq(_count("lye_soap_flask"), 2)
	assert_true(bool(st.get_flag("oakum_guiding")))
	assert_true(_holds("guest:mrs_oakum"), "she walks with the party")
	assert_eq(st.quest_stage("skitter_plague"), "into_the_hills")


func test_the_party_can_go_without_oakum() -> void:
	st.set_flag("bitten_seen")
	_play("skitterdeep/guide:offer", ["alone"])
	assert_true(bool(st.get_flag("oakum_declined")))
	assert_false(_holds("guest:mrs_oakum"))
	assert_eq(st.quest_stage("skitter_plague"), "into_the_hills")


func test_oakums_turn_is_a_scene_and_the_choice_afterwards_is_the_party_s() -> void:
	st.location = "sk_hills_trail"
	st.set_flag("oakum_guiding")
	_play("skitterdeep/guide:turn", ["Let her go"])
	assert_true(bool(st.get_flag("oakum_wolf_seen")))
	assert_false(_holds("guest:mrs_oakum"), "she ran into the trees, ashamed")
	_arrive("sk_camp")
	assert_true(_talks("mrs_oakum", "skitterdeep/guide:ashamed"), "she waits at the camp's edge")
	_play("skitterdeep/guide:ashamed", ["Keep her secret"])
	assert_true(bool(st.get_flag("oakum_secret_kept")))
	assert_true(bool(st.get_flag("oakum_choice_done")))
	assert_false(_talks("mrs_oakum", "skitterdeep/guide:ashamed"))


func test_oakums_secret_can_be_told_or_helped_instead() -> void:
	_play("skitterdeep/guide:ashamed", ["Tell Siv"])
	assert_true(bool(st.get_flag("oakum_secret_told")))
	st.set_flag("oakum_choice_done", false)
	_play("skitterdeep/guide:ashamed", ["cure"])
	assert_true(bool(st.get_flag("oakum_help_offered")))


# ---- the road, the rider, the camp ---------------------------------------------------------------------------------------------------

func test_the_parcel_rider_can_be_bridled_calmed_or_fought() -> void:
	_arrive("sk_hills_trail")
	st.set_flag("skitter_letter_hook")
	st.give_item("sk_bridle", 1)
	_play("skitterdeep/trail:rider", ["bridle"])
	assert_true(bool(st.get_flag("parcel_rider_freed")))
	assert_eq(_count("sk_bridle"), 0)
	assert_eq(_count("theodora_letter"), 1)
	st.set_flag("parcel_rider_met", false)
	st.set_flag("parcel_rider_freed", false)
	_play("skitterdeep/trail:rider", ["steady hand"])
	assert_true(bool(st.get_flag("parcel_rider_met")))
	assert_false(bool(st.get_flag("parcel_rider_freed")))
	st.set_flag("parcel_rider_met", false)
	_play("skitterdeep/trail:rider", ["Draw steel"])
	assert_eq(fights, ["sk_rider_fight"] as Array[String])
	assert_true(bool(st.get_flag("parcel_rider_slain")))


func test_a_failed_calm_is_a_fight_not_a_dead_end() -> void:
	_arrive("sk_hills_trail")
	dice = LowDice.new()
	_play("skitterdeep/trail:rider", ["steady hand"])
	assert_eq(fights, ["sk_rider_fight"] as Array[String])


func test_the_rider_waits_in_the_lair_when_there_was_no_letter() -> void:
	_arrive("sk_machine_shop")
	assert_true(_talks("parcel_rider", "skitterdeep/trail:rider_bed"))
	st.give_item("sk_bridle", 1)
	_play("skitterdeep/trail:rider_bed", ["bridle"])
	assert_true(bool(st.get_flag("parcel_rider_freed")))
	assert_false(_talks("parcel_rider", "skitterdeep/trail:rider_bed"), "it is a horse now")


func test_the_trail_leads_to_the_camp_and_the_road_is_on_the_map() -> void:
	var travel := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	var ids: Array[String] = []
	for p: Variant in travel["places"]:
		ids.append(str((p as Dictionary)["id"]))
	assert_true("sk_hills_trail" in ids and "sk_camp" in ids)
	var roads: Array[String] = []
	for r: Variant in travel["roads"]:
		roads.append(str((r as Dictionary)["id"]))
	assert_true("wickermoor_to_sk_trail" in roads and "sk_trail_to_camp" in roads)
	var trail_hours := 0
	for r: Variant in travel["roads"]:
		if str((r as Dictionary)["id"]) in ["wickermoor_to_sk_trail", "sk_trail_to_camp"]:
			trail_hours += int((r as Dictionary)["hours"])
	assert_eq(trail_hours, 8, "eight hours at a Fast pace, as the book has it")


func test_arriving_at_the_camp_moves_the_quest() -> void:
	_arrive("sk_camp")
	_play("skitterdeep/camp:arrival")
	assert_true(bool(st.get_flag("sk_arrived")))
	assert_eq(st.quest_stage("skitter_plague"), "skitterdeep")


func test_the_winch_is_loud_unless_oiled_and_the_lift_is_only_one_way_down() -> void:
	_arrive("sk_machine_shop")
	st.give_item("oil", 1)
	_play("skitterdeep/camp:winch", ["Oil"])
	assert_true(bool(st.get_flag("sk_lift_ready")))
	assert_eq(int(st.get_flag("skitterdeep_alert", 0)), 0, "oiled, the mine did not hear")
	st.set_flag("sk_lift_ready", false)
	_play("skitterdeep/camp:winch", ["Throw the lever"])
	assert_true(bool(st.get_flag("sk_lift_ready")))
	assert_true(int(st.get_flag("skitterdeep_alert", 0)) > 0, "the whole mine is alert for two hours")
	assert_true(_holds("minutes_since.skitterdeep_alert < 120"))


func test_a_failed_jam_is_loud_but_the_chain_and_the_drift_are_always_open() -> void:
	_arrive("sk_machine_shop")
	dice = LowDice.new()
	_play("skitterdeep/camp:winch", ["Jam"])
	assert_true(bool(st.get_flag("sk_lift_ready")))
	var camp := Compendium.shared().get_entry("locations", "sk_camp")
	var open: Array[String] = []
	for e: Variant in camp["exits"]:
		var d := e as Dictionary
		if not d.has("when") or str(d["when"]) == "":
			open.append(str(d["id"]))
	assert_true("chain_down" in open and "old_drift" in open, "two ways down never wait on a roll or a flag")
	var up := Compendium.shared().get_entry("locations", "sk_upper")
	var up_open: Array[String] = []
	for e: Variant in up["exits"]:
		if not (e as Dictionary).has("when"):
			up_open.append(str((e as Dictionary)["id"]))
	assert_true("chain_down" in up_open and "chain_up" in up_open, "the rungs and chain run both ways whatever happens to the lift")


func test_overloading_the_lift_drops_the_party_to_the_bottom() -> void:
	_arrive("sk_upper")
	st.set_flag("sk_lift_ready")
	st.set_flag("sk_hoard_taken")
	_play("skitterdeep/camp:lift", ["ore boxes"])
	assert_true(bool(st.get_flag("skitterdeep_lift_fell")))
	assert_eq(st.location, "sk_deep")
	var camp := Compendium.shared().get_entry("locations", "sk_camp")
	for e: Variant in camp["exits"]:
		if str((e as Dictionary)["id"]) == "lift_down":
			assert_false(_holds((e as Dictionary)["when"]), "the lift is gone")


func test_the_camp_fights_scale_by_level() -> void:
	_arrive("sk_upper")
	assert_eq((_spec("sk_landing")["monsters"] as Array).size(), 6, "level 3 meets the short landing")
	st.party.clear()
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		st.party.append(ch)
	assert_eq((_spec("sk_landing")["monsters"] as Array).size(), 13, "level 7 meets the fleshdobbin, two deepdrecks and ten centipedes")
	assert_eq((_spec("sk_drift_diggers")["monsters"] as Array).size(), 5)
	st.set_flag("thirteen_returned")
	assert_eq((_spec("sk_drift_diggers")["monsters"] as Array).size(), 3, "the diggers lose heart when Thirteen comes home")


func test_the_landing_and_the_spy_leave_their_finds() -> void:
	_arrive("sk_upper")
	_win("sk_landing")
	_win("sk_spy")
	var found := {}
	for p: Variant in _loc()["props"]:
		var d := p as Dictionary
		if str(d.get("item", "")) != "" and _holds(d.get("when", "")):
			found[str(d["item"])] = true
	assert_true(found.has("sk_iron_key") and found.has("ring_of_evasion"), "the key and the ring can be taken once their owners are down")


# ---- the Crosscut -----------------------------------------------------------------------------------------------------------------------

func test_the_eyeball_can_be_found_unpicked_or_cut() -> void:
	_arrive("sk_upper")
	_play("skitterdeep/camp:eyeball", ["Look closer", "Unpick"])
	assert_true(bool(st.get_flag("sk_eyeball_found")))
	assert_true(bool(st.get_flag("sk_eyeball_dealt")))
	st.set_flag("sk_eyeball_dealt", false)
	dice = LowDice.new()
	_play("skitterdeep/camp:eyeball", ["Look closer", "Unpick", "Cut it down"])
	assert_true(bool(st.get_flag("sk_eyeball_dealt")), "a blade does what the checks could not")


func test_the_hoard_pays_450_and_wakes_oswald_with_or_without_the_trap() -> void:
	_arrive("sk_upper")
	_play("skitterdeep/camp:hoard", ["Look closely", "real box"])
	assert_true(bool(st.get_flag("sk_hoard_seen")))
	assert_true(bool(st.get_flag("sk_hoard_taken")))
	assert_eq(int(st.gold), 450)
	assert_eq(fights, ["sk_oswald"] as Array[String])
	assert_true(int(st.get_flag("skitterdeep_alert", 0)) > 0, "the eye was not dealt with, so the mine knows")
	assert_true(bool(st.get_flag("oswald_slain")))


func test_the_hoard_can_be_taken_quietly_and_a_grab_is_a_fight() -> void:
	_arrive("sk_upper")
	st.set_flag("sk_eyeball_dealt")
	_play("skitterdeep/camp:hoard", ["Look closely", "real box"])
	assert_eq(int(st.get_flag("skitterdeep_alert", 0)), 0, "no alarm with the eye cut")
	st.set_flag("oswald_slain", false)
	fights.clear()
	_play("skitterdeep/camp:hoard", ["handful"])
	assert_eq(fights, ["sk_oswald"] as Array[String])


# ---- the deep level and Stonoga ------------------------------------------------------------------------------------------------------------

func test_the_bottom_moves_the_quest_and_the_miasma_never_fells_a_hero() -> void:
	_arrive("sk_deep")
	_play("skitterdeep/deep:arrive")
	assert_eq(st.quest_stage("skitter_plague"), "the_hags_lair")
	dice = LowDice.new()
	_play("skitterdeep/deep:miasma_a")
	assert_true(bool(st.get_flag("sk_miasma_a")))
	for ch in st.party:
		assert_true(ch.hp > 0, "the haze hurts and does not kill")


func test_the_sigils_break_by_a_blow_a_working_or_fire_and_a_miss_just_tries_again() -> void:
	_arrive("sk_deep")
	dice = LowDice.new()
	_play("skitterdeep/deep:sigils", ["Hack", "Unpick"])
	assert_false(bool(st.get_flag("skitter_sigils_broken")), "two misses, still standing")
	st.give_item("alchemists_fire", 1)
	_play("skitterdeep/deep:sigils", ["Alchemist"])
	assert_true(bool(st.get_flag("skitter_sigils_broken")))
	assert_true(int(st.get_flag("skitterdeep_alert", 0)) > 0, "Stonoga knows the moment they go")


func test_stonoga_falls_the_sigils_break_and_the_plague_lifts() -> void:
	_arrive("sk_deep")
	_play("skitterdeep/stonoga:enter", ["Talk", "Draw steel"])
	assert_eq(fights, ["sk_stonoga"] as Array[String])
	assert_true(bool(st.get_flag("stonoga_slain")))
	assert_eq(st.quest_stage("skitter_plague"), "the_sigils", "the sigils still stand: the plague only ends with both")
	_play("skitterdeep/stonoga:after")
	assert_true(bool(st.get_flag("oswald_slain")))
	assert_eq(st.quest_stage("skitter_plague"), "the_sigils")
	_play("skitterdeep/deep:sigils", ["Hack"])
	assert_eq(st.quest_stage("skitter_plague"), "exterminated")
	assert_true(bool(st.get_flag("plague_lifted")))


func test_breaking_the_sigils_first_still_ends_the_plague_when_she_falls() -> void:
	_arrive("sk_deep")
	_play("skitterdeep/deep:sigils", ["Hack"])
	_play("skitterdeep/stonoga:enter", ["Draw steel"])
	_play("skitterdeep/stonoga:after")
	assert_eq(st.quest_stage("skitter_plague"), "exterminated")
	assert_true(bool(st.get_flag("plague_lifted")))


func test_the_boss_fight_grows_with_the_level_and_the_alarm() -> void:
	_arrive("sk_deep")
	var low := _spec("sk_stonoga")
	assert_eq((low["monsters"] as Array).size(), 4, "level 3: Stonoga, two swarms and Oswald")
	st.set_flag("oswald_slain")
	assert_eq((_spec("sk_stonoga")["monsters"] as Array).size(), 3, "without Oswald")
	st.set_flag("oswald_slain", false)
	st.party.clear()
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		st.party.append(ch)
	assert_eq((_spec("sk_stonoga")["monsters"] as Array).size(), 5, "level 7: Stonoga, three swarms and Oswald")
	st.set_flag("skitterdeep_alert", st.total_minutes())
	assert_eq((_spec("sk_stonoga")["monsters"] as Array).size(), 6, "the alarm raised brings a fourth swarm")
	assert_true((_spec("sk_stonoga")["round_events"] as Array).size() >= 2, "the lair: a swarm every second round and a miasma surge")


func test_the_taunt_needs_something_to_taunt_with() -> void:
	_arrive("sk_deep")
	var r := DialogueRunner.new(st, dice)
	r.start("skitterdeep/stonoga:enter")
	var b := r.next()
	var texts: Array[String] = []
	for i in 40:
		if str(b["kind"]) == "options":
			for o: Variant in b["options"]:
				if bool((o as Dictionary)["enabled"]):
					texts.append(str((o as Dictionary)["text"]))
			break
		b = r.next()
	assert_false(texts.any(func(t: String) -> bool: return t.contains("sister")), "nothing to taunt with yet")
	st.set_flag("skitter_letter_hook")
	_play("skitterdeep/stonoga:enter", ["sister"])
	assert_true(bool(st.get_flag("stonoga_taunted")))
	assert_true(bool(st.get_flag("stonoga_talked")))


func test_the_notes_the_cage_and_the_discoveries() -> void:
	_arrive("sk_deep")
	st.set_flag("stonoga_slain")
	_play("skitterdeep/stonoga:notes")
	assert_true(bool(st.get_flag("stonoga_notes_read")))
	assert_true(bool(st.get_flag("golub_clue")), "Golub hides among the villagers: chapter 20's lead")
	assert_true(bool(st.get_flag("fate_rejuvenation_found")))
	_play("skitterdeep/stonoga:cage")
	assert_true(bool(st.get_flag("fate_kindred_found")))
	assert_eq(_count("stonoga_notes"), 1)


# ---- home --------------------------------------------------------------------------------------------------------------------------------

func test_the_farewell_pays_milestones_and_counts_the_chapter() -> void:
	st.location = "wickermoor_apothecary"
	st.set_flag("plague_started", st.total_minutes())
	st.set_flag("stonoga_slain")
	st.set_flag("plague_lifted")
	assert_true(_talks("morgan", "skitterdeep/farewell:morgan_thanks"))
	var ms := st.milestones
	var before := int(st.get_flag("act2_done", 0))
	_play("skitterdeep/farewell:morgan_thanks")
	assert_eq(int(st.get_flag("act2_done", 0)), before + 1)
	assert_eq(st.milestones, ms + 1, "the milestone is paid here")
	assert_eq(st.quest_stage("skitter_plague"), "done")
	assert_true(bool(st.get_flag("skitter_farewell")))
	assert_eq(_count("potion_of_healing_greater"), 2)
	assert_false(_talks("morgan", "skitterdeep/farewell:morgan_thanks"), "paid once")


func test_phillip_and_the_mayor_reopen_glitterdeep() -> void:
	st.set_flag("skitter_farewell")
	_play("skitterdeep/farewell:reopening", ["luck"])
	assert_true(bool(st.get_flag("glitterdeep_reopening")))


func test_theodora_pays_fifty_each_only_if_her_letter_brought_the_party() -> void:
	st.location = "wickermoor_post_office"
	st.set_flag("stonoga_slain")
	assert_false(_talks("theodora_mayville", "skitterdeep/letter:theodora_pays"))
	st.set_flag("skitter_letter_hook")
	assert_true(_talks("theodora_mayville", "skitterdeep/letter:theodora_pays"))
	_play("skitterdeep/letter:theodora_pays", ["Watch her face"])
	assert_eq(int(st.gold), 200)
	assert_true(bool(st.get_flag("theodora_paid")))
	assert_true(bool(st.get_flag("theodora_tell_seen")))


# ---- the two side quests --------------------------------------------------------------------------------------------------------------------

func _talk_to_the_queue() -> void:
	st.location = "wickermoor_apothecary"
	_play("skitterdeep/queue:morgan_start", ["see to it"])
	assert_eq(st.quest_stage("quarantine_queue"), "asked")
	st.location = "wickermoor_village"
	for who: String in ["haldor", "ottilie", "pim"]:
		_play("skitterdeep/queue:" + who, ["Look at"])
	assert_true(bool(st.get_flag("queue_talked")))
	st.location = "wickermoor_apothecary"


func test_the_queue_in_triage_order() -> void:
	st.set_flag("plague_started", st.total_minutes())
	_talk_to_the_queue()
	assert_true(_talks("morgan", "skitterdeep/queue:morgan_order"))
	_play("skitterdeep/queue:morgan_order", ["Haldor, then"])
	assert_eq(st.quest_stage("quarantine_queue"), "done")
	assert_eq(str(st.get_flag("queue_outcome", "")), "fair")
	assert_false(bool(st.get_flag("queue_haldor_worse")))


func test_the_queue_by_rank_costs_haldor_and_pleases_the_mayor() -> void:
	st.set_flag("plague_started", st.total_minutes())
	_talk_to_the_queue()
	_play("skitterdeep/queue:morgan_order", ["Pim first"])
	assert_eq(st.quest_stage("quarantine_queue"), "done")
	assert_true(bool(st.get_flag("queue_haldor_worse")), "a visible, local cost")
	assert_true(Factions.standing(st, "old_ways") >= 1)


func test_the_queue_left_to_itself_fails_with_mourning_ribbons() -> void:
	st.set_flag("plague_started", st.total_minutes())
	_talk_to_the_queue()
	_play("skitterdeep/queue:morgan_order", ["sort it out"])
	assert_eq(st.quest_stage("quarantine_queue"), "lost")
	assert_true(bool(st.get_flag("queue_lost")))
	assert_eq(str(st.get_flag("queue_outcome", "")), "lost")


func test_the_queue_has_a_way_on_when_every_medicine_check_fails() -> void:
	st.set_flag("plague_started", st.total_minutes())
	dice = LowDice.new()
	_talk_to_the_queue()
	_play("skitterdeep/queue:morgan_order", ["list", "Haldor, then"])
	assert_eq(st.quest_stage("quarantine_queue"), "done", "Morgan's list is the second way")


func test_thirteen_goes_home_to_the_diggers() -> void:
	_arrive("sk_camp")
	_play("skitterdeep/thirteen:kennel")
	assert_eq(st.quest_stage("thirteenth_centipede"), "asked")
	assert_true(_talks("thirteenth_centipede", "skitterdeep/thirteen:meet"))
	st.give_item("sk_miners_lunch", 1)
	_play("skitterdeep/thirteen:meet", ["lunch pail", "diggers"])
	assert_true(bool(st.get_flag("thirteen_returned")))
	assert_eq(st.quest_stage("thirteenth_centipede"), "done")
	assert_false(_talks("thirteenth_centipede", "skitterdeep/thirteen:meet"))


func test_thirteen_kennel_or_woods_and_a_failed_settle_only_costs_a_bite() -> void:
	_arrive("sk_camp")
	_play("skitterdeep/thirteen:kennel")
	dice = LowDice.new()
	_play("skitterdeep/thirteen:meet", ["Settle", "Settle"])
	dice = HighDice.new()
	_play("skitterdeep/thirteen:meet", ["Settle", "Buckle"])
	assert_eq(str(st.get_flag("thirteen_outcome", "")), "kennel")
	assert_eq(st.quest_stage("thirteenth_centipede"), "done")


func test_putting_thirteen_down_fails_the_quest() -> void:
	_arrive("sk_camp")
	_play("skitterdeep/thirteen:kennel")
	_play("skitterdeep/thirteen:meet", ["Put the creature down"])
	assert_eq(fights, ["sk_thirteen_fight"] as Array[String])
	assert_eq(st.quest_stage("thirteenth_centipede"), "lost")
	assert_eq(str(st.get_flag("thirteen_outcome", "")), "slain")


# ---- the places themselves -------------------------------------------------------------------------------------------------------------------

func test_every_exit_in_the_mine_leads_somewhere_and_comes_back() -> void:
	for id: String in ["sk_camp", "sk_hills_trail", "sk_warehouse", "sk_machine_shop", "sk_upper", "sk_deep"]:
		var loc := Compendium.shared().get_entry("locations", id)
		assert_true(not loc.is_empty(), id)
		for e: Variant in loc["exits"]:
			var to := str((e as Dictionary)["to"])
			if to == "travel":
				continue
			var there := Compendium.shared().get_entry("locations", to)
			assert_true(not there.is_empty(), "%s exit %s leads to %s" % [id, (e as Dictionary)["id"], to])
			var back := false
			for e2: Variant in there["exits"]:
				if str((e2 as Dictionary)["to"]) == id:
					back = true
			assert_true(back, "%s has a way back to %s" % [to, id])


func test_the_deep_level_is_always_reachable_even_if_the_lift_falls() -> void:
	# the chain and the rungs never wait on the lift: from the surface to the landing, and from the landing to the bottom, and back up
	var camp := Compendium.shared().get_entry("locations", "sk_camp")
	var up := Compendium.shared().get_entry("locations", "sk_upper")
	var deep := Compendium.shared().get_entry("locations", "sk_deep")
	var chain_down := false
	for e: Variant in camp["exits"]:
		if str((e as Dictionary)["id"]) == "chain_down" and str((e as Dictionary).get("when", "")) == "":
			chain_down = true
	var landing_down := false
	for e: Variant in up["exits"]:
		if str((e as Dictionary)["id"]) == "chain_down" and str((e as Dictionary).get("when", "")) == "":
			landing_down = true
	var deep_up := false
	for e: Variant in deep["exits"]:
		if str((e as Dictionary)["id"]) == "chain_up":
			deep_up = true
	assert_true(chain_down and landing_down and deep_up)
