extends TestCase
## R17, Memory's Rest: the three hooks in Wickermoor, the crossing, the front desk and the Code, Catherine and the Moon Porch, the twelve patients, the Matron's office, Godlee's
## dilemma (every ending), Belkin, the first and second floors' set pieces and their ways down, the antidote bench and its triage, the boss, Hugo, the farewell and the
## village after-beat. Each conversation is played through the DialogueRunner with dice that always roll high (or always low, for the failure paths) the way
## test_r13_paths plays Foxwillow: a person is only talked to while their entry's `when` holds and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")

## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll a 1: every check in a conversation fails.
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
var moves: Array[String] = []


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", st.location)


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out, which is
## "leave" in every menu here). Returns what the conversation ended in.
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
		moves.append(str(move["location"]))
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


func _flag(id: String) -> bool:
	return bool(st.get_flag(id))


func _n(id: String) -> int:
	return int(st.get_flag(id, 0))


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	dice = HighDice.new()
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 7)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	moves.clear()
	st.location = "mr_ground"
	st.set_flag("vessla_slain")


func after_each() -> void:
	GameState.reset()


# ---- the hooks and the crossing ------------------------------------------------------------------------------------------------------

func test_amos_asks_and_the_road_opens() -> void:
	st.location = "wickermoor_village"
	_play("memorys_rest/hook:amos_start", ["find her"])
	assert_true(_flag("amos_asked"))
	assert_true(_flag("mr_hook_open"))
	assert_eq(st.quest_stage("all_is_well"), "to_moonsong")
	assert_eq(st.quest_stage("amos_cousin"), "asked")


func test_morgans_pamphlet_is_a_second_way_and_the_abbots_journal_a_third_voice() -> void:
	st.location = "wickermoor_apothecary"
	st.set_flag("renathyr_journal")
	_play("memorys_rest/hook:morgan_pamphlet", ["Crimson Abbot", "Take the pamphlet"])
	assert_true(_flag("mr_hook_open"))
	assert_eq(st.quest_stage("all_is_well"), "to_moonsong")
	# Amos still has his own request after Morgan's: it starts his quest without moving the main one back
	st.location = "wickermoor_village"
	_play("memorys_rest/hook:amos_start", ["find her"])
	assert_eq(st.quest_stage("all_is_well"), "to_moonsong")
	assert_eq(st.quest_stage("amos_cousin"), "asked")


func test_the_travel_map_holds_the_shore_and_its_road() -> void:
	var t := Compendium.shared().get_entry("travel", "wickermoor_hollow")
	var places: Array = (t.get("places", []) as Array).map(func(p: Variant) -> String: return str((p as Dictionary)["id"]))
	assert_true("memorys_rest" in places)
	var roads: Array = (t.get("roads", []) as Array).map(func(p: Variant) -> String: return str((p as Dictionary)["id"]))
	assert_true("wickermoor_to_memorys_rest" in roads)


func test_the_crossing_has_three_ways_over() -> void:
	_arrive("mr_shore")
	_play("memorys_rest/shore:arrive")
	assert_eq(st.quest_stage("all_is_well"), "the_crossing")
	_play("memorys_rest/shore:boat", ["Row to the isle", "Keep to the clear water"])
	assert_true(_flag("mr_crossed"))
	assert_eq(st.location, "mr_isle")
	assert_true(not _flag("mr_dredger_roused"))
	# no skill: the Dredger rises, loses interest, and the party lands anyway
	dice = LowDice.new()
	st.set_flag("mr_crossed", false)
	_arrive("mr_shore")
	_play("memorys_rest/shore:boat", ["Row to the isle", "Row hard"])
	assert_true(_flag("mr_dredger_roused"))
	assert_eq(st.location, "mr_isle")
	# the fisher's carving is the third way
	_arrive("mr_shore")
	_play("memorys_rest/shore:hut")
	_play("memorys_rest/shore:boat", ["Hang the fisher"])
	assert_eq(st.location, "mr_isle")
	_play("memorys_rest/shore:isle_arrive")
	assert_eq(st.quest_stage("all_is_well"), "sign_in")


# ---- the front desk, the Code, the cousin ------------------------------------------------------------------------------------------

func test_reception_has_three_ways_in_and_the_matron_check_is_not_the_only_one() -> void:
	_play("memorys_rest/reception:desk", ["visiting", "Catherine"])
	assert_eq(str(st.get_flag("mr_signed_in")), "visitor")
	assert_eq(st.quest_stage("all_is_well"), "find_the_cousin")
	st.set_flag("mr_signed_in", "")
	_play("memorys_rest/reception:desk", ["check in"])
	assert_true(_flag("mr_admitted"))
	st.set_flag("mr_signed_in", "")
	_play("memorys_rest/reception:desk", ["to see the Matron"])
	assert_eq(str(st.get_flag("mr_signed_in")), "matron")
	# a failed lie still leaves the desk open
	dice = LowDice.new()
	st.set_flag("mr_signed_in", "")
	_play("memorys_rest/reception:desk", ["to see the Matron", "visiting then", "Catherine"])
	assert_eq(str(st.get_flag("mr_signed_in")), "visitor")


func test_the_code_has_two_strikes() -> void:
	_play("memorys_rest/reception:strike")
	assert_eq(_n("mr_conduct_strikes"), 1)
	assert_true(not _flag("mr_staff_hostile"))
	_play("memorys_rest/reception:strike")
	assert_true(_flag("mr_staff_hostile"))
	assert_eq(fights, ["mr_patrol_ground"] as Array[String])


func test_catherine_counts_once_and_the_porch_note_teaches_the_antidote() -> void:
	_arrive("mr_ground")
	_play("memorys_rest/cousin:visit", ["Study the way", "let you rest"])
	assert_true(_flag("amos_cousin_met"))
	assert_eq(st.quest_stage("amos_cousin"), "found")
	assert_eq(_n("mr_register_named"), 1)
	_play("memorys_rest/cousin:visit", ["let you rest"])
	assert_eq(_n("mr_register_named"), 1, "a second visit does not count her twice")
	_play("memorys_rest/cousin:porch_note")
	assert_true(_flag("mr_antidote_known"))
	assert_eq(st.quest_stage("the_lethic_antidote"), "learned")
	assert_eq(st.quest_stage("all_is_well"), "the_truth", "two clues (her words, the note) open the truth")


func test_the_register_closes_at_twelve() -> void:
	for node: String in ["samuel", "thomas_a", "victor", "emily_h", "wendy", "agnes", "james", "geoffrey", "thomas_r", "emily_v", "harold"]:
		_play("memorys_rest/patients:" + node)
	assert_eq(_n("mr_register_named"), 11)
	assert_eq(st.quest_stage("patients_register"), "started")
	_play("memorys_rest/cousin:visit", ["let you rest"])
	assert_eq(_n("mr_register_named"), 12)
	_play("memorys_rest/patients:samuel")
	assert_eq(st.quest_stage("patients_register"), "done")


func test_asking_about_a_past_breaks_the_code() -> void:
	_play("memorys_rest/patients:samuel", ["old life"])
	assert_eq(_n("mr_conduct_strikes"), 1)


func test_the_escaping_patient_has_three_ways() -> void:
	_play("memorys_rest/patients:escapee", ["Stand aside"])
	assert_true(_flag("mr_hatch_found"))
	st.set_flag("mr_escapee_seen", false)
	_play("memorys_rest/patients:escapee", ["Help them"])
	assert_eq(_n("mr_conduct_strikes"), 1)
	_play("memorys_rest/patients:escapee", ["Stop them"])
	assert_true(_flag("mr_powdered"))


# ---- the Matron's office -------------------------------------------------------------------------------------------------------------

func test_the_matron_takes_patients_gives_tours_and_ends_the_meeting_at_the_abbots_name() -> void:
	_play("memorys_rest/lethica:office", ["check in"])
	assert_true(_flag("mr_admitted"))
	_play("memorys_rest/lethica:office", ["see the building"])
	assert_true(_flag("mr_toured"))
	_play("memorys_rest/lethica:office", ["Crimson Abbot", "Press her"])
	assert_true(_flag("lethica_renathyr_named"))
	assert_true(_flag("mr_escorted_off"))
	assert_eq(st.location, "mr_isle")


# ---- Godlee's mementos: every ending -------------------------------------------------------------------------------------------------

func test_godlee_destroy() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/godlee:quarters", ["Win her trust", "Agree to destroy"])
	assert_true(_flag("godlee_trust"))
	assert_true(_flag("godlee_mementos_destroyed"))
	assert_eq(st.quest_stage("godlees_mementos"), "destroyed")


func test_godlee_keep_and_lie() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/godlee:quarters", ["Win her trust", "and keep them"])
	assert_eq(st.quest_stage("godlees_mementos"), "kept")


func test_godlee_caught_and_refused_are_visible_failures_and_trust_has_a_second_way() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/godlee:quarters", ["Win her trust", "Refuse"])
	assert_eq(st.quest_stage("godlees_mementos"), "refused")
	GameState.reset()
	before_each()
	_arrive("mr_upper")
	_play("memorys_rest/godlee:quarters", ["Win her trust", "and keep them"])
	assert_eq(st.quest_stage("godlees_mementos"), "kept")
	# low dice: no trust by words, but a memento is a second way in, and the diary is under the bed either way
	GameState.reset()
	before_each()
	dice = LowDice.new()
	st.location = "mr_upper"
	_play("memorys_rest/godlee:quarters", ["Win her trust", "Tell her we share"])
	assert_true(not _flag("godlee_trust"))
	st.set_flag("mr_has_memento")
	_play("memorys_rest/godlee:quarters", ["Show her a memento", "and keep them"])
	assert_eq(st.quest_stage("godlees_mementos"), "caught", "a lie told on low dice is heard")
	assert_true(_flag("mr_staff_hostile"))


func test_the_diary_opens_the_laboratory_knowledge() -> void:
	st.location = "mr_upper"
	_play("memorys_rest/godlee:quarters", ["Look for her diary", "Search under the bed"])
	assert_true(_flag("mr_lab_open_known"))


# ---- Belkin and Hugo -----------------------------------------------------------------------------------------------------------------

func test_belkins_exam_and_his_offer() -> void:
	_play("memorys_rest/belkin:exam", ["Watch his cap"])
	assert_true(_flag("mr_belkin_read"))
	st.location = "mr_upper"
	_play("memorys_rest/belkin:lab_offer", ["Ask what the offer costs", "Refuse politely"])
	assert_eq(str(st.get_flag("belkin_offer")), "refused")
	assert_eq(fights, ["mr_amalgam"] as Array[String])


func test_hugo_can_be_talked_down_in_three_steps_or_with_remove_curse_or_fought() -> void:
	_arrive("mr_grotto")
	_play("memorys_rest/hugo:peace", ["she would not want", "what he did for her", "he can rest"])
	assert_eq(str(st.get_flag("hugo_fate")), "gone")
	GameState.reset()
	before_each()
	_arrive("mr_grotto")
	_play("memorys_rest/hugo:peace", ["Defend yourselves"])
	assert_eq(str(st.get_flag("hugo_fate")), "dead")
	assert_eq(fights, ["mr_hugo_after"] as Array[String])
	# failing every word never closes the way: he roars and the menu returns
	GameState.reset()
	before_each()
	dice = LowDice.new()
	_arrive("mr_grotto")
	_play("memorys_rest/hugo:peace", ["she would not want", "Defend yourselves"])
	assert_eq(str(st.get_flag("hugo_fate")), "dead")


# ---- the first floor ------------------------------------------------------------------------------------------------------------------

func test_the_station_gives_garb_a_slip_and_a_lockdown_switch() -> void:
	_play("memorys_rest/rooms1:l5_station", ["orderly garb", "Put them on"])
	assert_true(_flag("mr_disguised"))
	_play("memorys_rest/rooms1:l5_station", ["desk cabinet", "Pick the lock"])
	assert_true(_flag("mr_code_behavioral"))
	_play("memorys_rest/rooms1:l5_station", ["Lockdown switch"])
	assert_true(_flag("mr_lockdown"))


func test_the_elevators_wait_for_their_codes_and_stop_in_lockdown() -> void:
	_play("memorys_rest/rooms1:l6_elevator_a", ["Leave"])
	assert_eq(st.location, "mr_ground")
	_play("memorys_rest/rooms1:l9_chanter")
	assert_true(_flag("mr_code_convalescent"))
	_play("memorys_rest/rooms1:l6_elevator_b", ["9536"])
	assert_eq(st.location, "mr_upper")


func test_the_hatch_has_three_ways_to_it() -> void:
	_play("memorys_rest/rooms1:l11d_bed", ["Search under the bed", "Read the glyphs"])
	assert_eq(st.location, "mr_grotto")
	assert_eq(st.quest_stage("all_is_well"), "the_way_down")
	# low dice: Hugo carried the escaper there, so the bed is found anyway; the words come from Belkin's journal
	GameState.reset()
	before_each()
	dice = LowDice.new()
	st.set_flag("mr_hatch_found")
	st.set_flag("mr_hatch_words")
	_play("memorys_rest/rooms1:l11d_bed", ["Look under the bed", "Speak the words"])
	assert_eq(st.location, "mr_grotto")


func test_the_theater_fight_and_the_pharmacy() -> void:
	_play("memorys_rest/rooms1:l13_theatre", ["Stay and watch"])
	assert_eq(fights, ["mr_theatre"] as Array[String])
	_play("memorys_rest/rooms1:l8_pharmacy", ["tranquilizer", "healing potions"])
	assert_eq(_loc().get("id"), "mr_ground")
