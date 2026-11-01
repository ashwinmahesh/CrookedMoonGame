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
	st.set_quest_stage("all_is_well", "find_the_cousin")
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
	_play("memorys_rest/godlee:quarters", ["Show her a memento", "and keep them", "Insist she is wrong"])
	assert_eq(st.quest_stage("godlees_mementos"), "caught", "a lie told on low dice is heard, and the player may still insist")
	assert_true(_flag("mr_staff_hostile"))
	# a caught lie is not a locked door: confessing still reaches the destroyed ending
	GameState.reset()
	before_each()
	dice = LowDice.new()
	st.location = "mr_upper"
	st.set_flag("mr_has_memento")
	_play("memorys_rest/godlee:quarters", ["Show her a memento", "and keep them", "Confess"])
	assert_eq(st.quest_stage("godlees_mementos"), "destroyed")


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


# ---- the antidote, the boss, the farewell ------------------------------------------------------------------------------------------------

func _stock() -> void:
	st.set_flag("mr_antidote_known")
	st.set_flag("mnemonic_residue", 3)
	st.set_flag("noetic_extract", 4)
	st.set_flag("unrefined_ichor", 2)
	st.set_quest_stage("the_lethic_antidote", "learned")


func test_the_bench_brews_a_dose_by_arcana_or_by_kit_and_a_failed_brew_wastes_only_one_ingredient() -> void:
	_arrive("mr_upper")
	_stock()
	_play("memorys_rest/workbench:bench", ["Brew one dose", "arcane knowledge"])
	assert_eq(_n("lethic_antidote_doses"), 1)
	assert_eq(_n("mnemonic_residue"), 2)
	assert_eq(_n("noetic_extract"), 3)
	assert_eq(st.quest_stage("the_lethic_antidote"), "brewed")
	assert_true(_flag("mr_cure_found"))
	_play("memorys_rest/workbench:bench", ["Brew one dose", "Alchemist"])
	assert_eq(_n("lethic_antidote_doses"), 2, "the kit is a second way to the same dose")
	dice = LowDice.new()
	st.set_flag("unrefined_ichor", 3)
	_play("memorys_rest/workbench:bench", ["Brew one dose", "arcane knowledge"])
	assert_eq(_n("lethic_antidote_doses"), 2, "a failed brew makes nothing")
	assert_eq(_n("unrefined_ichor"), 2, "and eats one ingredient")
	assert_eq(_n("mnemonic_residue"), 1, "keeping the rest")


func test_the_bench_will_not_brew_without_the_recipe() -> void:
	st.set_flag("mnemonic_residue", 3)
	st.set_flag("noetic_extract", 4)
	st.set_flag("unrefined_ichor", 2)
	_play("memorys_rest/workbench:bench")
	assert_eq(_n("lethic_antidote_doses"), 0)


func test_the_triage_gives_doses_to_catherine_the_patients_or_an_orderly() -> void:
	st.set_flag("lethic_antidote_doses", 3)
	_play("memorys_rest/workbench:triage", ["Catherine", "patients first", "mutant orderly", "slow cure"])
	assert_true(_flag("amos_cousin_cured"))
	assert_eq(_n("mr_patients_cured"), 2, "Catherine's dose and the patients' dose")
	assert_eq(_n("mr_orderly_cured"), 1)
	assert_eq(_n("lethic_antidote_doses"), 0)


func test_the_widow_falls_and_the_worm_goes() -> void:
	_arrive("mr_grotto")
	_play("memorys_rest/grotto:arrival", ["Study the worm", "Gather the ichor", "Step back", "Draw weapons"])
	assert_eq(_n("unrefined_ichor"), 2)
	assert_eq(fights, ["mr_widow"] as Array[String])
	assert_eq(st.quest_stage("all_is_well"), "the_weeping_widow")
	_play("memorys_rest/grotto:lethica_dies")
	assert_true(_flag("lethica_slain"))
	assert_true(_flag("white_worm_escaped"))
	assert_eq(st.quest_stage("all_is_well"), "unforgettable")


func test_the_boss_has_a_bloodied_phase_and_a_level_eight_variant() -> void:
	var w := Compendium.shared().get_entry("monsters", "weeping_widow")
	var phases := w.get("phases", []) as Array
	assert_eq(phases.size(), 1)
	assert_eq(int(((phases[0] as Dictionary)["summon"] as Dictionary)["count"]), 3)
	var variants := 0
	for e: Variant in (Compendium.shared().get_entry("locations", "mr_grotto")["encounters"] as Array):
		if str((e as Dictionary)["id"]) == "mr_widow":
			variants += 1
	assert_eq(variants, 2)


func test_the_matron_shown_a_portrait_falters() -> void:
	_arrive("mr_grotto")
	st.set_flag("mr_has_memento")
	st.set_flag("lethica_mementos_carried")
	_play("memorys_rest/grotto:widow_arrives", ["wedding portrait"])
	assert_true(_flag("mr_memento_shown"))
	assert_eq(fights, ["mr_widow"] as Array[String])


func test_the_farewell_pays_the_chapter_once_and_amos_waits_in_the_village() -> void:
	_arrive("mr_isle")
	st.set_flag("lethica_slain")
	st.set_quest_stage("the_lethic_antidote", "learned")
	_play("memorys_rest/ending:farewell", ["with Catherine"])
	assert_eq(_n("act2_done"), 1)
	assert_true(_flag("mr_farewell_done"))
	assert_eq(st.location, "wickermoor_village")
	assert_eq(st.quest_stage("the_lethic_antidote"), "lost", "no antidote was made, and the worm took its ichor")
	_arrive("mr_isle")
	_play("memorys_rest/ending:farewell", ["with Catherine"])
	assert_eq(_n("act2_done"), 1, "the counter moves once")
	_arrive("wickermoor_village")
	var gold := st.gold
	_play("memorys_rest/ending:amos_reward")
	assert_eq(st.quest_stage("amos_cousin"), "home_hollow")
	assert_eq(st.quest_stage("all_is_well"), "back_in_wickermoor")
	assert_true(st.gold > gold)


func test_a_cured_cousin_comes_home_herself_and_the_mayor_pays_for_a_cure() -> void:
	st.set_flag("lethica_slain")
	st.set_flag("amos_cousin_cured")
	st.set_flag("mr_cure_found")
	st.set_quest_stage("amos_cousin", "found")
	_arrive("wickermoor_village")
	_play("memorys_rest/ending:amos_reward")
	assert_eq(st.quest_stage("amos_cousin"), "home_cured")
	_arrive("wickermoor_mayors_house")
	_play("memorys_rest/ending:mayor_amulet")
	assert_true(_flag("mayor_amulet_given"))
	_arrive("wickermoor_apothecary")
	_play("memorys_rest/ending:morgan_slow_cure")
	assert_true(_flag("mr_morgan_cure"))


func test_leaving_catherine_on_the_island_is_a_marked_failure_with_a_visible_end() -> void:
	_arrive("mr_isle")
	st.set_flag("lethica_slain")
	st.set_quest_stage("amos_cousin", "found")
	_play("memorys_rest/ending:farewell", ["without Catherine"])
	assert_eq(st.quest_stage("amos_cousin"), "left")
	_arrive("wickermoor_village")
	_play("memorys_rest/ending:amos_reward")
	assert_eq(st.quest_stage("amos_cousin"), "left")
	assert_eq(st.quest_stage("all_is_well"), "back_in_wickermoor")


# ---- the places ------------------------------------------------------------------------------------------------------------------------

func _walkable(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= str(rows[y]).length():
		return false
	return not (str(rows[y])[x] in ["#", "w", " ", "="])


## Flood fill from a spawn over open squares (doors count as open), for the squares beside every prop, person, door and exit.
func test_every_prop_person_door_and_exit_can_be_reached_from_the_way_in() -> void:
	var starts := {"mr_shore": "from_road", "mr_isle": "from_boat", "mr_ground": "from_isle", "mr_upper": "from_elevator", "mr_grotto": "from_hatch"}
	for loc_id: String in starts:
		var loc := Compendium.shared().get_entry("locations", loc_id)
		var rows := (loc["map"] as Dictionary)["rows"] as Array
		var sp := ((loc["spawns"] as Dictionary)[starts[loc_id]]) as Array
		var seen := {Vector2i(int(sp[0]), int(sp[1])): true}
		var q: Array[Vector2i] = [Vector2i(int(sp[0]), int(sp[1]))]
		while not q.is_empty():
			var c: Vector2i = q.pop_back()
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := c + d
				if not seen.has(n) and _walkable(rows, n.x, n.y):
					seen[n] = true
					q.append(n)
		for kind: String in ["props", "npcs", "exits", "doors"]:
			for e: Variant in loc.get(kind, []):
				var cell := (e as Dictionary)["cell"] as Array
				var at := Vector2i(int(cell[0]), int(cell[1]))
				var near := seen.has(at)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					near = near or seen.has(at + d)
				assert_true(near, "%s: %s at %s can be reached" % [loc_id, str((e as Dictionary).get("id", (e as Dictionary).get("npc", ""))), at])


func test_every_floor_is_joined_to_the_next() -> void:
	var ground := Compendium.shared().get_entry("locations", "mr_ground")
	var exits := (ground["exits"] as Array).map(func(e: Variant) -> String: return str((e as Dictionary)["to"]))
	assert_true("mr_isle" in exits)
	var isle := Compendium.shared().get_entry("locations", "mr_isle")
	assert_true("mr_ground" in (isle["exits"] as Array).map(func(e: Variant) -> String: return str((e as Dictionary)["to"])))
	var shore := Compendium.shared().get_entry("locations", "mr_shore")
	assert_true("travel" in (shore["exits"] as Array).map(func(e: Variant) -> String: return str((e as Dictionary)["to"])))
	var grotto := Compendium.shared().get_entry("locations", "mr_grotto")
	var to := (grotto["exits"] as Array).map(func(e: Variant) -> String: return str((e as Dictionary)["to"]))
	assert_true("mr_ground" in to and "mr_upper" in to)


func test_the_register_has_twelve_names_and_catherine_is_amos_cousin() -> void:
	var names: Array[String] = ["catherine_winthrop", "samuel_blake", "thomas_adams", "victor_lane", "emily_hale", "wendy_holden", "agnes_thorpe",
		"james_pelham", "geoffrey_barnes", "thomas_redding", "emily_voss", "harold_stiles"]
	for n in names:
		assert_true(not Compendium.shared().get_entry("npcs", n).is_empty(), "%s is a person" % n)
	assert_eq(names.size(), 12)


# ---- the second floor ----------------------------------------------------------------------------------------------------------------

func test_the_apartments_can_be_passed_by_stealth_or_uniform_or_fought() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/rooms2a:l14_apartments", ["Slip past"])
	assert_eq(fights.size(), 0)
	dice = LowDice.new()
	_play("memorys_rest/rooms2a:l14_apartments", ["Slip past"])
	assert_eq(fights, ["mr_patrol_up"] as Array[String])
	GameState.reset()
	before_each()
	dice = LowDice.new()
	st.location = "mr_upper"
	st.set_flag("mr_disguised")
	_play("memorys_rest/rooms2a:l14_apartments", ["Walk through in uniform"])
	assert_eq(fights.size(), 0)


func test_the_restrained_patient_can_be_cured_spared_the_clock_or_lost_to_it() -> void:
	_arrive("mr_upper")
	st.set_flag("lethic_antidote_doses", 1)
	_play("memorys_rest/rooms2a:l15_patient", ["Give a dose"])
	assert_eq(str(st.get_flag("l15_patient_fate")), "cured")
	assert_eq(_n("lethic_antidote_doses"), 0)
	GameState.reset()
	before_each()
	st.location = "mr_upper"
	_play("memorys_rest/rooms2a:l15_patient", ["Calm them and leave"])
	assert_true(_flag("mr_l15_left"))
	assert_true(not _flag("l15_patient_fate"), "walking away does not decide it yet")
	st.advance_minutes(150)
	_play("memorys_rest/rooms2a:l15_patient")
	assert_eq(str(st.get_flag("l15_patient_fate")), "mutated", "two hours on, the change has come")


func test_the_cremator_gives_a_key_and_the_ash_once() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/rooms2a:l18_ash", ["ward key", "Scoop the ash"])
	assert_true(_flag("mr_ward_key"))
	assert_eq(_n("mnemonic_residue"), 3)
	_play("memorys_rest/rooms2a:l18_ash", ["Scoop the ash"])
	assert_eq(_n("mnemonic_residue"), 3)


func test_the_diagrams_the_log_and_the_register_each_teach_the_truth() -> void:
	_arrive("mr_upper")
	st.set_quest_stage("all_is_well", "find_the_cousin")
	_play("memorys_rest/rooms2b:l19_diagrams", ["Study them"])
	assert_true(_flag("mr_antidote_known"))
	_play("memorys_rest/extras:l15_log")
	assert_eq(st.quest_stage("all_is_well"), "the_truth")
	assert_eq(st.quest_stage("the_lethic_antidote"), "learned")


func test_the_shrine_gives_mementos_once_and_godlees_pyre_empties_it() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/rooms2b:l19_shrine", ["Take the mementos", "ring and mask", "phial"])
	assert_true(_flag("lethica_mementos_carried"))
	assert_eq(_n("unrefined_ichor"), 1)
	_play("memorys_rest/rooms2b:l19_shrine")
	assert_eq(_n("unrefined_ichor"), 1, "the phial is taken once, and the shrine offers nothing twice")
	_play("memorys_rest/godlee:quarters", ["Win her trust", "Agree to destroy"])
	assert_true(not _flag("lethica_mementos_carried"), "destroyed with Godlee's help")


func test_the_engineering_room_throws_lockdown_on_off_or_breaks_into_mouthers() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/rooms2b:l20_unit", ["lever OFF"])
	assert_true(_flag("mr_lockdown"))
	_play("memorys_rest/rooms2b:l20_unit", ["lever ON"])
	assert_true(not _flag("mr_lockdown"))
	_play("memorys_rest/rooms2b:l20_unit", ["Smash the unit"])
	assert_eq(fights, ["mr_mouthers"] as Array[String])
	assert_true(_flag("mr_engineering_broken"))


func test_hugos_den_containment_and_belkins_office() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/rooms2b:l21_file", ["stabilizer", "Look under the mat"])
	assert_true(_flag("mr_hugo_file_read"))
	_play("memorys_rest/rooms2b:l22_chamber", ["noetic extract"])
	assert_eq(_n("noetic_extract"), 4)
	_play("memorys_rest/rooms2b:l22_chamber", ["Open the chamber"])
	assert_eq(fights, ["mr_otyugh"] as Array[String])
	_play("memorys_rest/rooms2c:l23_journal", ["Read the journal"])
	assert_true(_flag("mr_hatch_words"))
	_play("memorys_rest/rooms2c:l23_journal", ["larvae"])
	assert_eq(fights, ["mr_otyugh", "mr_swarm"] as Array[String])


func test_the_glass_patient_is_saved_by_medicine_or_by_serum_and_the_pods_show_the_grotto() -> void:
	_arrive("mr_upper")
	_play("memorys_rest/rooms2c:l25_glass", ["Treat them"])
	assert_eq(str(st.get_flag("l25_patient_fate")), "saved")
	GameState.reset()
	before_each()
	dice = LowDice.new()
	st.location = "mr_upper"
	st.set_flag("lethic_antidote_doses", 1)
	_play("memorys_rest/rooms2c:l25_glass", ["Treat them"])
	assert_eq(str(st.get_flag("l25_patient_fate")), "lost", "a failed treatment loses them, and the serum was a second way")
	_play("memorys_rest/rooms2c:l24_pods", ["gel"])
	assert_true(_flag("mr_worm_seen"))


func test_the_laboratory_opens_to_serum_and_every_way_down_ends_in_the_grotto() -> void:
	_arrive("mr_upper")
	st.set_flag("mr_lab_open_known")
	st.give_item("mr_lethic_serum", 1)
	_play("memorys_rest/rooms2c:l27_eye", ["Inject the owl"])
	assert_true(_flag("mr_lab_open"))
	_play("memorys_rest/rooms2c:l27_lab", ["unrefined ichor"])
	assert_eq(_n("unrefined_ichor"), 6)
	_play("memorys_rest/rooms2c:l27_lab", ["Plunge Platform"])
	assert_eq(st.location, "mr_grotto")
	assert_eq(st.quest_stage("all_is_well"), "the_way_down")
	GameState.reset()
	before_each()
	st.location = "mr_upper"
	_play("memorys_rest/rooms2c:l27_lab", ["foot lever", "Find the foot lever"])
	assert_eq(st.location, "mr_grotto")
	assert_true(_flag("mr_wile_used"))


func test_the_owl_eye_has_a_second_way_in_by_search() -> void:
	_arrive("mr_upper")
	st.give_item("mr_lethic_serum", 1)
	_play("memorys_rest/rooms2c:l27_eye", ["Search the mural"])
	assert_true(_flag("mr_eye_found"))
	_play("memorys_rest/rooms2c:l27_eye", ["Inject the owl"])
	assert_true(_flag("mr_lab_open"))
