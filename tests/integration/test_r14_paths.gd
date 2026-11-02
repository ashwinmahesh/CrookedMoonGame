extends TestCase
## R14, The Crimson Monastery: Weston's hook, Dawn's Gate, the gate, the Night of Flames (rescue by three ways, the burning, the subdual and the Dead Larder), Crimson Favor,
## the clues to the way down, the altar, the sanctum door, the Abbot at three levels, the hellfire offer, the aftermath, the farewell and the return, and the side quests, each played through the DialogueRunner with dice that always roll high, the way test_r10_playthrough plays the
## Express: a person is only talked to while their entry's `when` holds and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")
const TOWN := "dawns_gate"

## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll 1: every check fails, so each gate shows its second way.
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
	dice = HighDice.new()
	st.location = TOWN


func after_each() -> void:
	GameState.reset()


func _flag(id: String, v: Variant = true) -> void:
	st.set_flag(id, v)


func _standing() -> int:
	return int(st.get_flag("standing_crimson_faith", 0))


# ---- the hook and the road -------------------------------------------------------------------------------------------------------------

func test_weston_sends_the_party_and_melina_gives_a_token() -> void:
	st.location = "wickermoor_village"
	_play("monastery/hook:weston_pilgrim", ["What does Gareth look like", "We will find him"])
	assert_true(bool(st.get_flag("gareth_asked")))
	assert_eq(st.quest_stage("crimson_monastery"), "heard")
	_play("monastery/hook:melina_wait", ["Ask for something"])
	assert_true(bool(st.get_flag("melina_met")))
	assert_true(bool(st.get_flag("melina_token")))


func test_the_road_to_dawns_gate_is_on_the_travel_map() -> void:
	var t := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	var place := false
	var hours := 0
	for p: Variant in t["places"]:
		if str((p as Dictionary)["id"]) == "dawns_gate":
			place = true
	for r: Variant in t["roads"]:
		if str((r as Dictionary)["id"]) == "wickermoor_to_dawns_gate":
			hours = int((r as Dictionary)["hours"])
	assert_true(place)
	assert_eq(hours, 14)


func test_arriving_in_dawns_gate_and_the_gate_has_three_ways() -> void:
	_play("monastery/arrival:dg_arrive", ["Head into the village"])
	assert_true(bool(st.get_flag("dg_arrived")))
	assert_eq(st.quest_stage("crimson_monastery"), "dawns_gate")
	st.location = "mon_pass"
	_play("monastery/arrival:gate_watch", ["came to see the bell"])
	assert_true(bool(st.get_flag("crimson_gate_open")))


func test_climbing_the_wall_unseen_or_caught_and_fighting_in() -> void:
	st.location = "mon_pass"
	_play("monastery/arrival:gate_watch", ["Climb the wall"])
	assert_true(bool(st.get_flag("crimson_sneaked")))
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	st.location = "mon_pass"
	dice = LowDice.new()
	_play("monastery/arrival:gate_watch", ["Climb the wall"])
	assert_true(bool(st.get_flag("crimson_gate_open")), "a failed climb still lets them in")
	assert_eq(int(st.get_flag("crimson_infractions", 0)), 1)
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	st.location = "mon_pass"
	_play("monastery/arrival:gate_watch", ["Fight our way in"])
	assert_eq(fights, ["mon_gate_fight"] as Array[String])


# ---- the Night of Flames ----------------------------------------------------------------------------------------------------------------

func test_gareth_is_saved_by_naming_melina() -> void:
	st.location = "mon_ground"
	_flag("melina_met")
	_play("monastery/flames:pyre_start", ["Call out to Gareth", "Plead", "Melina"])
	assert_eq(str(st.get_flag("gareth_fate")), "rescued")
	assert_true(bool(st.get_flag("crimson_in")))
	assert_eq(st.quest_stage("crimson_monastery"), "inside")
	assert_eq(_standing(), 5)


func test_gareth_is_saved_with_no_roll_by_the_songbird() -> void:
	st.location = "mon_ground"
	dice = LowDice.new()
	_play("monastery/hook:melina_wait", ["Ask for something"])
	_play("monastery/flames:pyre_start", ["Call out to Gareth", "Plead", "creed", "songbird"])
	assert_eq(str(st.get_flag("gareth_fate")), "rescued")


func test_watching_the_pyre_burns_gareth_and_the_party_is_still_taken_in() -> void:
	st.location = "mon_ground"
	_play("monastery/flames:pyre_start", ["Watch in silence"])
	assert_eq(str(st.get_flag("gareth_fate")), "burned")
	assert_true(bool(st.get_flag("night_of_flames_done")))
	assert_true(bool(st.get_flag("crimson_in")))


func test_forcing_the_pyre_is_a_subdual_with_a_way_out_of_the_larder() -> void:
	st.location = "mon_ground"
	_play("monastery/flames:pyre_start", ["Cry out"])
	assert_true(bool(st.get_flag("crimson_captured")))
	dice = LowDice.new()
	_play("monastery/captives:larder_wake", ["Look at our shackles", "Axel's trick"])
	assert_true(bool(st.get_flag("larder_out")))


func test_the_atonement_can_be_recanted_or_fought() -> void:
	st.location = "mon_ground"
	_play("monastery/captives:pyre_atonement", ["Recant"])
	assert_true(bool(st.get_flag("crimson_recanted")))
	_play("monastery/captives:pyre_atonement", ["Refuse"])
	assert_eq(fights, ["mon_pyre_fight"] as Array[String])


# ---- Crimson Favor ----------------------------------------------------------------------------------------------------------------------

func test_infractions_cost_favor_and_amends_win_it_back_once_devotions_are_made() -> void:
	st.location = "mon_ground"
	_flag("crimson_in")
	_play("monastery/faithful:novice", ["monstrous"])
	assert_eq(int(st.get_flag("crimson_infractions", 0)), 1)
	assert_eq(_standing(), -1)
	_flag("crimson_devotions", 3)
	_play("monastery/faithful:novice", ["Make amends", "Speak with conviction"])
	assert_eq(_standing(), 2)
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	st.location = "mon_ground"
	dice = LowDice.new()
	_flag("crimson_devotions", 3)
	_play("monastery/faithful:novice", ["Make amends", "Speak with conviction"])
	assert_eq(_standing(), 0, "a failed amends is never worse")


func test_the_halls_turn_hostile_only_when_the_faithful_are() -> void:
	st.location = "mon_ground"
	_flag("standing_crimson_faith", -4)
	_play("monastery/faithful:parishioners", ["Fight"])
	assert_eq(fights, ["mon_halls_clergy"] as Array[String])


# ---- the way down -------------------------------------------------------------------------------------------------------------------------

func test_the_altar_opens_by_search_or_by_what_we_were_told() -> void:
	st.location = "mon_ground"
	_play("monastery/clues:altar", ["Search the altar", "own blood"])
	assert_true(bool(st.get_flag("altar_open")))
	assert_eq(st.quest_stage("crimson_monastery"), "holy_vein")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	st.location = "mon_ground"
	dice = LowDice.new()
	_play("monastery/captives:axel_start", ["how to get down"])
	assert_true(bool(st.get_flag("src_axel")))
	assert_eq(st.quest_stage("crimson_monastery"), "the_way_down")
	_play("monastery/clues:altar", ["Use what we were told", "faithful"])
	assert_true(bool(st.get_flag("altar_open")))


func test_the_scriptorium_and_the_missal_name_the_altar_without_a_roll() -> void:
	dice = LowDice.new()
	st.location = "mon_ground"
	_play("monastery/clues:scriptorium", ["Read slowly"])
	assert_true(bool(st.get_flag("src_scriptorium")))
	_play("monastery/clues:missal")
	assert_true(bool(st.get_flag("src_missal")))


func test_the_sanctum_door_gives_way_to_pushing_or_to_time() -> void:
	st.location = "mon_holy_vein"
	_play("monastery/clues:sanctum_door", ["Push it"])
	assert_true(bool(st.get_flag("sanctum_door_open")))
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	dice = LowDice.new()
	st.location = "mon_holy_vein"
	_play("monastery/clues:sanctum_door", ["Push it"])
	assert_true(not bool(st.get_flag("sanctum_door_open")), "a failed push does not open it")
	_play("monastery/clues:sanctum_door", ["Shove it together"])
	assert_true(bool(st.get_flag("sanctum_door_open")))


func test_the_bell_tower_gate_has_a_roll_or_the_invitation() -> void:
	st.location = "mon_ground"
	dice = LowDice.new()
	_flag("cathedral_audience_done")
	_flag("standing_crimson_faith", 5)
	_play("monastery/clues:bell_gate", ["invitation"])
	assert_true(bool(st.get_flag("bell_gate_open")))


# ---- the Abbot -----------------------------------------------------------------------------------------------------------------------------

func test_the_abbot_is_fought_at_three_strengths() -> void:
	var loc := JSON.parse_string(FileAccess.get_file_as_string("res://data/locations/mon_sanctum.json")) as Dictionary
	var hps := {}
	for e: Variant in loc["encounters"]:
		var d := e as Dictionary
		if str(d["id"]) == "mon_abbot":
			hps[str(d["when"])] = int(((d["monsters"] as Array)[0] as Dictionary)["hp"])
	assert_eq(hps.size(), 3)
	assert_true(hps.values().has(85) and hps.values().has(110) and hps.values().has(140))


func test_the_sanctum_fight_geyser_and_the_refused_offer() -> void:
	st.location = "mon_sanctum"
	_play("monastery/sanctum:prefight", ["come to end this"])
	assert_eq(fights, ["mon_abbot"] as Array[String])
	assert_eq(st.quest_stage("crimson_monastery"), "bloody_tears")
	_play("monastery/sanctum:geyser")
	assert_eq(st.location, "mon_cathedral_moon")
	assert_true(bool(st.get_flag("renathyr_slain")))
	_play("monastery/sanctum:hellfire", ["Refuse her"])
	assert_eq(str(st.get_flag("viraxys_offer")), "refused")
	assert_true(bool(st.get_flag("hellfire_done")))
	_play("monastery/sanctum:sword_altar")
	assert_true(bool(st.get_flag("sword_taken")))


func test_a_hero_who_accepts_the_gift_is_asked_twice_and_leaves() -> void:
	st.location = "mon_cathedral_moon"
	var before := st.party.size()
	_play("monastery/sanctum:hellfire", ["Accept her gift", "No", "Refuse her"])
	assert_eq(st.party.size(), before, "a no changes nothing")
	_play("monastery/sanctum:hellfire", ["Accept her gift", "Yes", "Yes, I accept"])
	assert_eq(str(st.get_flag("viraxys_offer")), "accepted")
	assert_eq(st.party.size(), before - 1)


func test_the_fiend_can_be_read_by_insight_or_religion_or_divine_sense() -> void:
	st.location = "mon_cathedral_moon"
	_play("monastery/sanctum:hellfire", ["She is a fiend", "Refuse her"])
	assert_eq(str(st.get_flag("viraxys_offer")), "refused")


# ---- the aftermath, the farewell and the return ---------------------------------------------------------------------------------

func test_the_successor_is_the_strongest_prior_left() -> void:
	st.location = "mon_ground"
	_play("monastery/aftermath:courtyard", ["Say nothing"])
	assert_eq(str(st.get_flag("crimson_successor")), "olaf")
	assert_eq(st.quest_stage("crimson_monastery"), "aftermath")
	_flag("mon_olaf_done")
	_play("monastery/aftermath:successor")
	assert_eq(str(st.get_flag("crimson_successor")), "cromwell")
	_flag("mon_cromwell_done")
	_play("monastery/aftermath:successor")
	assert_eq(str(st.get_flag("crimson_successor")), "jaeger")
	_flag("mon_jaeger_done")
	_play("monastery/aftermath:successor")
	assert_eq(str(st.get_flag("crimson_successor")), "none")


func test_the_reveal_with_the_journal_disbands_the_faith() -> void:
	st.location = "mon_ground"
	_flag("renathyr_journal")
	_play("monastery/aftermath:courtyard", ["journal as proof"])
	assert_true(bool(st.get_flag("crimson_rose_revealed")))
	assert_true(bool(st.get_flag("crimson_faith_disbanded")))


func test_the_farewell_pays_the_milestone_and_wickermoor_celebrates_or_mourns() -> void:
	_play("monastery/aftermath:farewell")
	assert_eq(int(st.get_flag("act2_done", 0)), 1)
	assert_true(bool(st.get_flag("crimson_farewell")))
	assert_eq(st.quest_stage("crimson_monastery"), "return")
	st.location = "wickermoor_village"
	_flag("gareth_fate", "rescued")
	var before := st.gold
	_play("monastery/hook:weston_return")
	assert_eq(st.quest_stage("crimson_monastery"), "done")
	assert_true(bool(st.get_flag("phillip_dinner_invited")))
	assert_true(st.gold > before)
	_play("monastery/hook:melina_reunion")


func test_a_burned_gareth_is_mourned() -> void:
	st.location = "wickermoor_village"
	_flag("gareth_fate", "burned")
	_play("monastery/hook:weston_return")
	assert_eq(st.quest_stage("crimson_monastery"), "done")


# ---- the captives and the priors ----------------------------------------------------------------------------------------------------

func test_captives_can_be_freed_and_led_out_quietly_or_seen() -> void:
	st.location = "mon_ground"
	_play("monastery/captives:group", ["Pick the shackles", "Wait until the Evening bell"])
	assert_eq(st.quest_stage("free_the_captives"), "freed")
	assert_true(bool(st.get_flag("crimson_captives_freed")))


func test_leading_the_captives_out_in_plain_sight_costs_favor() -> void:
	st.location = "mon_ground"
	dice = LowDice.new()
	_play("monastery/captives:group", ["Leave them"])
	_flag("axel_freed")
	_play("monastery/captives:freed", ["Over the east wall"])
	assert_eq(st.quest_stage("free_the_captives"), "freed")
	assert_eq(int(st.get_flag("crimson_infractions", 0)), 1)


func test_cromwell_is_made_to_talk_by_force_or_by_her_past() -> void:
	st.location = "mon_ground"
	_play("monastery/priors:cromwell_room", ["Make her tell"])
	assert_true(bool(st.get_flag("src_cromwell")))
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	st.location = "mon_ground"
	_play("monastery/priors:cromwell_start", ["bandit queen"])
	assert_true(bool(st.get_flag("src_cromwell_leverage")))
	dice = LowDice.new()
	_play("monastery/priors:cromwell_room", ["Speak of Leona"])
	assert_true(bool(st.get_flag("src_cromwell")))


func test_the_priors_fight_when_refused() -> void:
	st.location = "mon_ground"
	_play("monastery/priors:jaeger_start", ["want no part"])
	assert_eq(fights, ["mon_jaeger"] as Array[String])


func test_the_priors_second_form_is_in_the_data() -> void:
	for id: String in ["prior_jaeger", "prior_olaf", "prior_cromwell"]:
		var m := Compendium.shared().get_entry("monsters", id)
		assert_true(not m.is_empty(), id)
		var ph := (m["phases"] as Array)[0] as Dictionary
		assert_true(bool((ph["when"] as Dictionary).get("at_zero", false)), id)
		assert_eq(int(ph["hp"]), 75)


# ---- Dawn's Gate side quests ----------------------------------------------------------------------------------------------------------

func test_kristoffs_cellar_kept_or_betrayed() -> void:
	st.location = "dg_briar"
	_play("monastery/cellar:refugees", ["keep your secret"])
	assert_eq(st.quest_stage("kristoffs_cellar"), "kept")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	var before := st.gold
	_play("monastery/cellar:refugees", ["Turn them over"])
	assert_eq(st.quest_stage("kristoffs_cellar"), "betrayed")
	assert_true(st.gold > before)


func test_kristoff_shows_the_cellar_by_insight_or_by_asking() -> void:
	dice = LowDice.new()
	_play("monastery/kristoff:start", ["keeps glancing"])
	assert_true(not bool(st.get_flag("cellar_asked")))
	_play("monastery/kristoff:cellar_admit", ["Show us"])
	assert_true(bool(st.get_flag("cellar_asked")))


func test_the_hunt_is_ambushed_or_let_ride() -> void:
	_play("monastery/villagers:hunt_ambush", ["Ambush"])
	assert_eq(fights, ["dg_hunt"] as Array[String])
	assert_eq(st.quest_stage("sanguine_hunt"), "ambushed")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	st.location = TOWN
	_play("monastery/villagers:hunt_ambush", ["ride out"])
	assert_eq(st.quest_stage("sanguine_hunt"), "rode_out")


func test_quills_ode_is_fixed_or_recited() -> void:
	_play("monastery/poet:quill_ode")
	_play("monastery/poet:quill_help", ["plain rhyme"])
	assert_eq(st.quest_stage("pilgrims_bad_poetry"), "done")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	_play("monastery/poet:quill_help", ["recite it as it is"])
	assert_eq(st.quest_stage("pilgrims_bad_poetry"), "burned")


func test_brother_quiets_message_is_carried_or_dropped() -> void:
	_play("monastery/quiet:quiet_who")
	_play("monastery/quiet:quiet_carry")
	st.location = "wickermoor_village"
	_flag("gareth_asked")
	_play("monastery/quiet:melina_message")
	assert_eq(st.quest_stage("friar_quiet"), "done")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	_play("monastery/quiet:quiet_who")
	_play("monastery/quiet:quiet_start", ["cannot carry it"])
	assert_eq(st.quest_stage("friar_quiet"), "lost")


func test_the_silver_bells_name_is_restored_or_left() -> void:
	st.location = "mon_bell_tower"
	dice = LowDice.new()
	_play("monastery/bell:orrin_bell")
	_play("monastery/bell:inscription", ["Scrape"])
	assert_true(bool(st.get_flag("bell_inscription_read")))
	_play("monastery/bell:orrin_report", ["true name"])
	assert_eq(st.quest_stage("silver_bells_name"), "restored")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	_play("monastery/bell:orrin_bell")
	_play("monastery/bell:orrin_report", ["Let it lie"])
	assert_eq(st.quest_stage("silver_bells_name"), "left")


func test_axels_debts_are_paid_in_three_small_kindnesses() -> void:
	_flag("axel_freed")
	_play("monastery/captives:axel_debts")
	assert_eq(st.quest_stage("axels_debts"), "asked")
	_play("monastery/villagers:toma_hat")
	_play("monastery/villagers:halka_letter")
	_play("monastery/hounds:dagny_leash")
	assert_eq(st.quest_stage("axels_debts"), "done")


func test_daggy_calms_the_hounds_by_handling_or_by_coin() -> void:
	dice = LowDice.new()
	st.gold = 50
	_play("monastery/hounds:dagny_calm", ["Pay her ten gold"])
	assert_true(bool(st.get_flag("dagny_hounds_calmed")))


func test_ser_maric_loosens_his_saddle_once_helped() -> void:
	_play("monastery/maric:maric_help")
	assert_true(bool(st.get_flag("maric_helped")))
	_play("monastery/maric:maric_deal")
	assert_true(bool(st.get_flag("maric_loosened")))
