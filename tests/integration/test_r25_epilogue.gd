extends TestCase
## R25, the Epilogue and the Last Ride, and the endings of the whole game: which ending the flags pick (every `when`, by priority), what each
## narration plays, which slides the world's outcomes choose, and the walk from the village to the old station, the Vagrant's car and `end_game`.
## Conversations are played through the DialogueRunner with dice that always roll high, as test_r13_paths does.

const GAME := preload("res://world/game_root.gd")

class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var st: StoryState
var dice := HighDice.new()
var arrived := ""


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	Endings.clear_cache()
	arrived = ""
	st.location = "wickermoor_village"


func after_each() -> void:
	GameState.reset()
	Endings.clear_cache()


## Plays `ref` taking at each menu the first enabled option holding the next of `picks` (the last option when they run out).
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
	var move := b.get("move", {}) as Dictionary
	if not move.is_empty():
		arrived = str(move["location"])
		st.location = arrived
	return b


## The ending the flags pick, with `alive` heroes still travelling (the rest fell for good).
func _pick(flags: Dictionary, alive := 4) -> String:
	for id: String in flags:
		st.set_flag(id, flags[id])
	while st.party.size() > alive:
		st.lose_member(st.party[st.party.size() - 1], "test")
	return str(Endings.pick(st).get("id", ""))


# ---------------------------------------------------------------------------------------------- the endings and their priorities

func test_all_eleven_endings_are_loaded() -> void:
	var ids: Array[String] = []
	for e in Endings.all():
		ids.append(str(e["id"]))
	for want: String in ["empty_car", "embers_of_the_fallen", "under_the_crooked_moon", "queens_consort", "live_deliciously", "crooked_rebirth",
			"ash_over_the_hollow", "moon_unbent", "green_sea", "last_train_out", "moonfall"]:
		assert_true(want in ids, "%s is an ending" % want)
	assert_eq(ids.size(), 11)


func test_a_bound_queen_and_a_living_party_is_the_good_ending() -> void:
	assert_eq(_pick({"kehlenn_bound": true}), "under_the_crooked_moon")


func test_a_hero_given_at_the_skull_makes_it_embers_of_the_fallen() -> void:
	assert_eq(_pick({"kehlenn_bound": true, "last_act_count": 1}, 3), "embers_of_the_fallen")


func test_nobody_left_to_board_is_an_empty_car() -> void:
	assert_eq(_pick({"kehlenn_bound": true, "last_act_count": 4}, 0), "empty_car")


func test_empty_car_beats_embers_and_the_good_ending() -> void:
	st.set_flag("kehlenn_bound")
	st.set_flag("last_act_count", 4)
	var ids: Array[String] = []
	while st.party.size() > 0:
		st.lose_member(st.party[0], "the Last Act")
	for e in Endings.all():
		if StoryConditions.check(str(e["when"]), st):
			ids.append(str(e["id"]))
	assert_eq(ids, ["empty_car", "embers_of_the_fallen", "under_the_crooked_moon"] as Array[String])


func test_siding_with_the_queen() -> void:
	assert_eq(_pick({"kehlenn_sided": true}), "queens_consort")


func test_every_hero_taking_the_goats_offer() -> void:
	assert_eq(_pick({"horned_bargains": 4}), "live_deliciously")


func test_three_bargains_of_four_is_only_the_crooked_rebirth() -> void:
	assert_eq(_pick({"horned_bargains": 3}), "crooked_rebirth")


func test_all_bargains_count_the_fallen_too() -> void:
	assert_eq(_pick({"horned_bargains": 4}, 2), "live_deliciously")


func test_siding_beats_the_bargains() -> void:
	assert_eq(_pick({"kehlenn_sided": true, "horned_bargains": 4}), "queens_consort")


func test_a_lost_ritual_or_fight_is_the_crooked_rebirth() -> void:
	assert_eq(_pick({"crooked_cause": "wipe"}), "crooked_rebirth")


func test_nothing_set_is_the_crooked_rebirth() -> void:
	assert_eq(_pick({}), "crooked_rebirth")


func test_the_wicker_man_winning_is_ash_over_the_hollow() -> void:
	assert_eq(_pick({"wicker_man_triumphant": true}), "ash_over_the_hollow")


func test_a_bound_queen_overrules_the_wicker_man() -> void:
	assert_eq(_pick({"wicker_man_triumphant": true, "kehlenn_bound": true}), "under_the_crooked_moon")


func test_the_moon_unbent_needs_all_eight_fears_and_a_refusal() -> void:
	assert_eq(_pick({"kehlenn_bound": true, "moonfall_started": true, "old_fears_slain": 8, "moonfall_offer": "refused"}), "moon_unbent")


func test_seven_fears_do_not_unbend_the_moon() -> void:
	st.set_flag("kehlenn_bound")
	st.set_flag("moonfall_started")
	st.set_flag("old_fears_slain", 7)
	st.set_flag("moonfall_offer", "refused")
	st.set_flag("moonfall_nights_left", 3)
	assert_eq(str(Endings.pick(st).get("id", "")), "under_the_crooked_moon")


func test_the_green_sea_is_the_accepted_offer() -> void:
	assert_eq(_pick({"kehlenn_bound": true, "moonfall_started": true, "moonfall_offer": "accepted"}), "green_sea")


func test_fleeing_on_the_last_night_is_the_last_train_out() -> void:
	assert_eq(_pick({"kehlenn_bound": true, "moonfall_started": true, "moonfall_fled": true, "moonfall_nights_left": 0}), "last_train_out")


func test_the_nights_running_out_is_moonfall() -> void:
	assert_eq(_pick({"kehlenn_bound": true, "moonfall_started": true, "moonfall_nights_left": 0}), "moonfall")


func test_moonfall_with_nights_left_is_not_yet_an_ending_of_its_own() -> void:
	assert_eq(_pick({"kehlenn_bound": true, "moonfall_started": true, "moonfall_nights_left": 4}), "under_the_crooked_moon")


func test_request_records_once_and_never_changes() -> void:
	st.set_flag("kehlenn_bound")
	assert_eq(Endings.request(st), "under_the_crooked_moon")
	st.set_flag("kehlenn_sided")
	assert_eq(Endings.request(st), "under_the_crooked_moon")
	assert_eq(str(st.get_flag("campaign_ending")), "under_the_crooked_moon")


func test_the_campaign_module_records_the_ending_for_end_game() -> void:
	st.set_flag("kehlenn_bound")
	Campaign.module().request_ending(st)
	assert_eq(Endings.reached(st), "under_the_crooked_moon")


# ---------------------------------------------------------------------------------------------- narration and slides

func test_every_ending_narration_plays_to_its_end_without_a_choice() -> void:
	var variants := [{}, {"crooked_cause": "wipe"}, {"crooked_cause": "ritual_failed"}, {"crooked_cause": "refused"}, {"last_act_count": 2},
			{"last_ride_destination": "home"}, {"last_ride_destination": "province"}, {"last_ride_destination": "beyond"},
			{"moonfall_realm": "wild"}, {"moonfall_realm": "city"}, {"moonfall_realm": "farm"}, {"moonfall_realm": "home"}]
	for e in Endings.all():
		for v: Dictionary in variants:
			GameState.reset()
			st = GameState.story
			for id: String in GAME.NEW_GAME_PARTY:
				st.party.append(Pregens.build(id, 3))
			for k: String in v:
				st.set_flag(k, v[k])
			var r := DialogueRunner.new(st, dice)
			assert_true(r.start(str(e["narration"])), "%s starts" % e["narration"])
			var b := r.next()
			var lines := 0
			for i in 80:
				if str(b["kind"]) == "end":
					break
				assert_true(str(b["kind"]) != "options", "%s offers no choice" % e["id"])
				if str(b["kind"]) == "line":
					lines += 1
				b = r.next()
			assert_eq(str(b["kind"]), "end", "%s ends" % e["id"])
			assert_true(lines >= 5, "%s has a narration of %d lines" % [e["id"], lines])


func _topics(ending_id: String) -> Array[String]:
	var out: Array[String] = []
	for s in Endings.slides(Endings.get_ending(ending_id), st):
		out.append(str(s["topic"]))
	return out


func _slide(ending_id: String, topic: String) -> String:
	for s in Endings.slides(Endings.get_ending(ending_id), st):
		if str(s["topic"]) == topic:
			return str(s["text"])
	return ""


func test_the_good_ending_reads_the_village_outcomes() -> void:
	st.set_flag("kehlenn_bound")
	st.set_flag("feast_winner", "both")
	st.set_flag("price_outcome", "eleanor")
	st.set_flag("mori_outcome", "burn")
	st.set_flag("oakum_outcome", "kept")
	st.set_flag("curses_outcome", "unpicked")
	st.set_flag("crow_outcome", "freed")
	st.set_flag("quarantine_forged")
	st.set_flag("quack_outcome", "partner")
	st.set_flag("letter_outcome", "sent")
	st.set_flag("bell_outcome", "restored")
	st.set_flag("field_outcome", "truth")
	st.set_flag("punch_outcome", "kept")
	st.set_flag("seating_outcome", "loud")
	st.set_flag("golub_dead")
	st.set_flag("chuckles_dead")
	var topics := _topics("under_the_crooked_moon")
	for t: String in ["village_feast", "village_price", "village_mori", "village_oakum", "village_curses", "foxwillow", "village_quack", "village_quarantine",
			"village_letter", "village_bell", "foxwillow_fields", "village_punch", "village_seating", "village_golub", "village_chuckles"]:
		assert_true(t in topics, "the slide %s is shown" % t)
	assert_true(_slide("under_the_crooked_moon", "village_feast").contains("both"))
	assert_true(_slide("under_the_crooked_moon", "village_mori").contains("burned"))


func test_a_topic_is_shown_once_and_the_most_specific_variant_wins() -> void:
	st.set_flag("kehlenn_bound")
	st.set_flag("vigil_deaths", 14)
	var topics := _topics("under_the_crooked_moon")
	assert_eq(topics.count("wickermoor_village"), 1)
	assert_true(_slide("under_the_crooked_moon", "wickermoor_village").contains("barely"))
	GameState.reset()
	st = GameState.story
	st.set_flag("kehlenn_bound")
	st.set_flag("vigil_deaths", 5)
	assert_true(_slide("under_the_crooked_moon", "wickermoor_village").contains("quiet"))
	st.set_flag("vigil_fled")
	assert_true(_slide("under_the_crooked_moon", "wickermoor_village").contains("rebuilt"))


func test_each_thread_has_a_slide_for_taken_and_declined() -> void:
	for tid: String in ["apocalypse", "ascendancy", "deliverance", "duality", "evolution", "immortality", "kindred", "liberation", "malediction", "pilgrimage", "rapture",
			"rejuvenation", "slaughter"]:
		for answer: String in ["taken", "declined"]:
			GameState.reset()
			st = GameState.story
			st.set_flag("kehlenn_bound")
			st.set_flag("thread_%s_catharsis" % tid, answer)
			assert_true(("thread_" + tid) in _topics("under_the_crooked_moon"), "%s %s has a slide" % [tid, answer])
	GameState.reset()
	st = GameState.story
	st.set_flag("kehlenn_bound")
	assert_true(not ("thread_apocalypse" in _topics("under_the_crooked_moon")), "no Thread chosen, no slide")


func test_the_embers_ending_adds_its_own_slides_to_the_good_set() -> void:
	st.set_flag("kehlenn_bound")
	st.set_flag("last_act_count", 2)
	var topics := _topics("embers_of_the_fallen")
	assert_true("embers" in topics)
	assert_true("wickermoor_village" in topics, "the sealed set follows")
	assert_true(_slide("embers_of_the_fallen", "embers").contains("embers of the fallen"))


func test_the_lost_heroes_close_the_slides() -> void:
	st.set_flag("kehlenn_bound")
	st.lose_member(st.party[3], "the Last Act")
	var slides := Endings.slides(Endings.get_ending("embers_of_the_fallen"), st)
	assert_eq(str(slides[slides.size() - 1]["topic"]), "fallen")


func test_the_crooked_endings_inherit_the_crooked_set() -> void:
	for id: String in ["queens_consort", "live_deliciously", "ash_over_the_hollow"]:
		var topics := _topics(id)
		assert_true("foxwillow" in topics, "%s follows the crooked set" % id)
		assert_true(not ("village_feast" in topics), "%s shows no good-ending village slides" % id)


func test_the_last_ride_slide_follows_the_destination() -> void:
	st.set_flag("kehlenn_bound")
	st.set_flag("last_ride_destination", "beyond")
	assert_true(_slide("under_the_crooked_moon", "last_ride").contains("beyond"))
	assert_true(_slide("under_the_crooked_moon", "newcomers").contains("climb aboard"))


func test_the_green_sea_slide_follows_the_realm_chosen() -> void:
	st.set_flag("moonfall_started")
	st.set_flag("moonfall_offer", "accepted")
	st.set_flag("moonfall_realm", "city")
	assert_true(_slide("green_sea", "green_sea_realm").contains("city of light"))


# ---------------------------------------------------------------------------------------------- the village after the finale

func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


func _village_npcs(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Variant in Compendium.shared().get_entry("locations", "wickermoor_village").get("npcs", []):
		if str((n as Dictionary)["npc"]) == npc_id and str((n as Dictionary).get("dialogue", "")).begins_with("epilogue/"):
			out.append(n as Dictionary)
	return out


func test_the_fair_and_the_closing_talks_wait_for_the_bound_queen() -> void:
	for n: Variant in Compendium.shared().get_entry("locations", "wickermoor_village").get("npcs", []):
		if str((n as Dictionary).get("dialogue", "")).begins_with("epilogue/"):
			assert_true(not _holds((n as Dictionary)["when"]), "%s waits for the finale" % (n as Dictionary)["dialogue"])
	st.set_flag("kehlenn_bound")
	assert_eq(_village_npcs("old_rusty").size(), 1)
	assert_true(_holds(_village_npcs("old_rusty")[0]["when"]))


func test_old_rusty_opens_the_epilogue_and_the_fair() -> void:
	st.set_flag("kehlenn_bound")
	_play("epilogue/hook:start", ["That is all"])
	assert_true(bool(st.get_flag("ep_started")))
	assert_eq(st.quest_stage("ep_the_last_ride"), "loose_ends")
	assert_eq(st.quest_stage("ep_fair_on_the_round"), "open")
	assert_true(not _holds(_village_npcs("old_rusty")[0]["when"]), "he does not meet them twice")


func test_the_old_station_exit_waits_and_then_moves_the_quest() -> void:
	var loc := Compendium.shared().get_entry("locations", "wickermoor_village")
	var ex := {}
	for e: Variant in loc["exits"]:
		if str((e as Dictionary)["id"]) == "old_station":
			ex = e as Dictionary
	assert_true(not ex.is_empty())
	assert_true(not _holds(ex["when"]))
	st.set_flag("kehlenn_bound")
	st.set_flag("ep_started")
	assert_true(_holds(ex["when"]))
	assert_eq((ex["sets_quest"] as Dictionary)["stage"], "the_last_ride")
	assert_true((loc["spawns"] as Dictionary).has("from_fog"))


func test_every_closing_talk_plays_once_and_counts() -> void:
	var ids: Array[String] = []
	for n: Variant in Compendium.shared().get_entry("locations", "wickermoor_village").get("npcs", []):
		var d := str((n as Dictionary).get("dialogue", ""))
		if d.begins_with("epilogue/closing:"):
			ids.append(d.get_slice(":", 1))
	assert_eq(ids.size(), 18)
	st.set_flag("kehlenn_bound")
	st.set_flag("ep_started")
	var done := 0
	for id: String in ids:
		_play("epilogue/closing:" + id)
		assert_true(bool(st.get_flag("ep_closing_" + id)), "%s's talk is marked" % id)
		done += 1
		assert_eq(int(st.get_flag("ep_closings", 0)), done)
		for n in _village_npcs(id):
			assert_true(not _holds(n["when"]), "%s does not repeat" % id)


func test_a_closing_talk_reads_the_outcomes() -> void:
	st.set_flag("kehlenn_bound")
	var r := DialogueRunner.new(st, dice)
	st.set_flag("alda_will_delivered")
	assert_true(r.start("epilogue/closing:marianna_grey"))
	var text := ""
	var b := r.next()
	for i in 40:
		if str(b["kind"]) == "end":
			break
		text += str(b.get("text", "")) + "\n"
		b = r.next()
	assert_true(text.contains("Green Queen Inn"), "Marianna speaks of the inn she was left")


func test_the_fair_audit_passes_with_the_permit_and_is_fined_without_it() -> void:
	st.set_flag("kehlenn_bound")
	_play("epilogue/fair:quill_start", ["Hear the verse"])
	assert_true(bool(st.get_flag("ep_fair_verse")))
	assert_eq(st.quest_stage("ep_fair_on_the_round"), "open")
	_play("epilogue/fair:notice_start", ["Take the permit down"])
	assert_true(bool(st.get_flag("ep_fair_permit_safe")))
	var gold := st.gold
	_play("epilogue/fair:audit_start", ["Show the permit"])
	assert_eq(str(st.get_flag("ep_fair_outcome")), "passed")
	assert_eq(int(st.gold), int(gold) + 10)
	assert_eq(st.quest_stage("ep_fair_on_the_round"), "done")


func test_the_goat_eating_the_permit_costs_ten_gold_and_locks_nothing() -> void:
	st.set_flag("kehlenn_bound")
	st.set_quest_stage("ep_fair_on_the_round", "open")
	_play("epilogue/fair:notice_start", ["Let the goat have it"])
	assert_true(bool(st.get_flag("ep_fair_permit_eaten")))
	st.gold = 50
	_play("epilogue/fair:audit_start", ["Admit the goat"])
	assert_eq(str(st.get_flag("ep_fair_outcome")), "fined")
	assert_eq(int(st.gold), 40)
	assert_eq(st.quest_stage("ep_fair_on_the_round"), "done")


func test_the_audit_has_a_way_out_and_a_bribe_that_works() -> void:
	st.set_flag("kehlenn_bound")
	_play("epilogue/fair:audit_start", ["Come back later"])
	assert_true(not st.get_flag("ep_fair_outcome", false))
	_play("epilogue/fair:audit_start", ["slice of pie"])
	assert_eq(str(st.get_flag("ep_fair_outcome")), "bribed")


func test_the_graves_for_the_fallen_open_the_empty_seats_quest_and_close_it() -> void:
	st.set_flag("kehlenn_bound")
	st.lose_member(st.party[3], "the Last Act")
	_play("epilogue/graves:start", ["Say a few words"])
	assert_true(bool(st.get_flag("ep_fallen_graves_seen")))
	assert_true(bool(st.get_flag("ep_goodbyes_said")))
	assert_eq(st.quest_stage("ep_empty_seats"), "done")


func test_the_graves_can_be_left_without_a_word_and_show_the_vigil_when_nobody_fell() -> void:
	st.set_flag("kehlenn_bound")
	_play("epilogue/graves:start", ["Walk on"])
	assert_true(not st.get_flag("ep_fallen_graves_seen", false))
	st.lose_member(st.party[3], "the Last Act")
	_play("epilogue/graves:start", ["Walk on"])
	assert_eq(st.quest_stage("ep_empty_seats"), "graves")


# ---------------------------------------------------------------------------------------------- the old station and the Last Ride

func test_the_vagrant_comes_out_of_the_fog_and_waits_if_asked() -> void:
	st.location = "ep_fog"
	st.set_flag("kehlenn_bound")
	_play("epilogue/vagrant:arrive", ["Not yet"])
	assert_true(bool(st.get_flag("ep_vagrant_met")))
	assert_true(not st.get_flag("ep_boarded", false))
	assert_eq(arrived, "", "he does not take them anywhere")
	_play("epilogue/vagrant:again", ["Not yet"])


func test_the_rumours_come_back_to_the_menu() -> void:
	st.location = "ep_fog"
	_play("epilogue/vagrant:arrive", ["Ask about the rumours", "Not yet"])


func test_boarding_takes_the_party_to_the_car_with_the_ticket() -> void:
	st.location = "ep_fog"
	st.set_flag("kehlenn_bound")
	st.set_quest_stage("ep_the_last_ride", "loose_ends")
	_play("epilogue/vagrant:arrive", ["Board the train"])
	assert_eq(arrived, "ep_car")
	assert_true(bool(st.get_flag("ep_boarded")))
	assert_true(st.party_has_item("ghostlight_ticket_unknown"))
	assert_eq(st.quest_stage("ep_the_last_ride"), "the_last_ride")
	assert_true(not Compendium.shared().get_entry("locations", "ep_car").is_empty())


func test_the_car_door_leads_back_and_the_ride_can_be_postponed() -> void:
	st.location = "ep_car"
	st.set_flag("kehlenn_bound")
	_play("epilogue/last_ride:start", ["Not yet"])
	assert_eq(arrived, "wickermoor_village")
	assert_eq(Endings.reached(st), "", "nothing ended")
	assert_true(bool(st.get_flag("ep_last_ride_asked")))


func test_the_last_ride_to_each_destination_ends_the_game_with_the_good_ending() -> void:
	for pair: Array in [["Home", "home"], ["Another province", "province"], ["Another world", "beyond"]]:
		GameState.reset()
		st = GameState.story
		for id: String in GAME.NEW_GAME_PARTY:
			st.party.append(Pregens.build(id, 3))
		Endings.clear_cache()
		st.location = "ep_car"
		st.set_flag("kehlenn_bound")
		var end := _play("epilogue/last_ride:start", [pair[0]])
		assert_true(bool(end.get("end_game", false)), "the ride ends the game")
		assert_eq(str(st.get_flag("last_ride_destination")), pair[1])
		assert_eq(Endings.reached(st), "under_the_crooked_moon")
		assert_eq(st.quest_stage("ep_the_last_ride"), "done")


func test_the_last_ride_with_fallen_heroes_ends_in_the_embers_ending() -> void:
	st.location = "ep_car"
	st.set_flag("kehlenn_bound")
	st.set_flag("last_act_count", 1)
	st.lose_member(st.party[3], "the Last Act")
	var end := _play("epilogue/last_ride:start", ["Home"])
	assert_true(bool(end.get("end_game", false)))
	assert_eq(Endings.reached(st), "embers_of_the_fallen")


func test_a_hero_whose_thread_took_them_is_missed_on_the_platform() -> void:
	st.location = "ep_car"
	st.set_flag("kehlenn_bound")
	st.set_flag("thread_malediction_catharsis", "taken")
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start("epilogue/last_ride:start"))
	var text := ""
	var b := r.next()
	for i in 40:
		if str(b["kind"]) == "options" or str(b["kind"]) == "end":
			break
		text += str(b.get("text", "")) + "\n"
		b = r.next()
	assert_true(text.contains("beyond the stars"))


func test_the_station_and_the_car_are_places_with_their_vagrant() -> void:
	for id: String in ["ep_fog", "ep_car"]:
		var loc := Compendium.shared().get_entry("locations", id)
		assert_true(not loc.is_empty(), "%s exists" % id)
		var found := false
		for n: Variant in loc["npcs"]:
			found = found or str((n as Dictionary)["npc"]) == "the_vagrant"
		assert_true(found, "%s has the Vagrant" % id)


func test_the_empty_seats_are_named_only_when_a_hero_fell() -> void:
	for fallen: bool in [false, true]:
		GameState.reset()
		st = GameState.story
		for id: String in GAME.NEW_GAME_PARTY:
			st.party.append(Pregens.build(id, 3))
		st.set_flag("kehlenn_bound")
		if fallen:
			st.lose_member(st.party[3], "the Last Act")
		var r := DialogueRunner.new(st, dice)
		assert_true(r.start("epilogue/last_ride:start"))
		var text := ""
		var b := r.next()
		for i in 40:
			if str(b["kind"]) == "options" or str(b["kind"]) == "end":
				break
			text += str(b.get("text", "")) + "\n"
			b = r.next()
		assert_eq(text.contains("aired"), fallen, "the Vagrant keeps the seats aired only for the fallen")


func test_party_terms_compare_the_company() -> void:
	assert_true(not _holds("party_size > party_alive"))
	st.lose_member(st.party[0], "test")
	assert_true(_holds("party_size > party_alive"))
	assert_true(_holds("party_alive == 3"))
	assert_true(_holds("party_size == 4"))
	st.set_flag("horned_bargains", 4)
	assert_true(_holds("flag.horned_bargains >= party_size"))
	st.set_flag("horned_bargains", 3)
	assert_true(not _holds("flag.horned_bargains >= party_size"))
	assert_true(_holds("flag.horned_bargains == party_alive"))
