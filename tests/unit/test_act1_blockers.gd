extends TestCase
## What the Act 1 playthrough QA found in the way of finishing the Ghostlight Express (2026-11-01), each kept fixed: a level-1
## hero drained to a Hit Point maximum of 0 by the Phantom's passengers, the drain lasting all of Act 1, a wipe at the Stoker or a
## haint ending the game, a retry raising the long dead, the lost locomotive fight left "started" so the wreck refused every
## rest, a find all four heroes missed lost for good, and the lamps' check-in stopping the first walk in every car.

const CARS: Array[String] = ["ghostlight_g1_passenger", "ghostlight_g2_sleeper", "ghostlight_g3_lounge", "ghostlight_g4_dining",
	"ghostlight_g5_mail", "ghostlight_g6_baggage", "ghostlight_g7_circus", "ghostlight_g8_tender"]


func after_each() -> void:
	GameState.reset()


func _party(level: int) -> StoryState:
	GameState.reset()
	var st := GameState.story
	for id: String in ["rook_coldwake", "cordelia_skein", "delphine_ravelle", "lucan_houndstooth"]:
		var ch := Pregens.build(id, level)
		if ch == null:
			continue
		ch.finish_long_rest()
		st.party.append(ch)
	return st


# --- The drain -----------------------------------------------------------------------------------------------------

func test_the_trains_drainers_are_this_games_softened_blocks() -> void:
	for f: String in ["ghostlight_g1_passenger", "ghostlight_g8_tender"]:
		for en: Variant in Compendium.shared().get_entry("locations", f).get("encounters", []):
			for m: Variant in (en as Dictionary).get("monsters", []):
				var id := str((m as Dictionary)["monster"])
				assert_false(id in ["specter", "shadow"], "%s in %s uses the Act 1 block, not the plain %s" % [(en as Dictionary)["id"], f, id])
	for id: String in ["corrupted_passenger", "phantom_trainhopper"]:
		var mon := Monster.from_data(Compendium.shared().monster_data(id))
		var rider := {}
		for a: Variant in Compendium.shared().monster_data(id).get("actions", []):
			for r: Variant in (a as Dictionary).get("on_hit", []):
				rider = r as Dictionary
		assert_eq(int(rider.get("floor", 0)), 1, "%s's drain stops at 1" % id)
		assert_eq(str(rider.get("until", "")), "fight", "%s's drain ends with the fight" % id)
		assert_true(mon != null)


func test_two_touches_no_longer_kill_a_level_1_hero_and_the_drain_ends_with_the_fight() -> void:
	var e := TestCombat.open_field(3)
	var s := TestCombat.foe(e, "corrupted_passenger", Vector2i(3, 3))
	var h := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.start_with(e, s)
	var top := h.creature.max_hp()
	for i in 4:
		TestCombat.next_d20(e, 19)
		e.monster_attack(s, h, "life_drain")
	assert_false(h.creature.dead, "the drain alone can't kill")
	assert_true(h.creature.max_hp() >= ceili(top * 0.5), "the maximum stops at half")
	EncounterSetup.clear_fight_effects(h.creature)
	assert_eq(h.creature.max_hp(), top, "the maximum comes back when the fight is over")


# --- Retries -------------------------------------------------------------------------------------------------------

func test_every_fight_on_the_train_retries() -> void:
	for car in CARS:
		for en: Variant in Compendium.shared().get_entry("locations", car).get("encounters", []):
			var spec := en as Dictionary
			assert_true(FightRetry.applies(spec, car), "%s in %s retries" % [spec["id"], car])
	var stoker := FightRetry.rule_for({"id": "gl_stoker"}, "ghostlight_g8_tender")
	assert_eq(FightRetry.restart_id(stoker, {"id": "gl_stoker"}), "gl_stoker", "the same fight begins again")
	assert_eq(str(FightRetry.rule_for({"id": "gl_phantom_strikes"}, "ghostlight_g1_passenger")["id"]), "ghostlight_phantom",
		"the Phantom keeps its own rule")


func test_a_retry_brings_back_only_who_fell_in_that_fight() -> void:
	var st := _party(1)
	st.party[0].dead = true   # fell for good in an earlier fight
	var before := FightRetry.dead_now(st)
	st.party[1].dead = true   # fell in this one
	for ch in st.party:
		ch.hp = 0
	FightRetry.restore(st, FightRetry.rule_for({"id": "gl_stoker"}, "ghostlight_g8_tender"), before)
	assert_true(st.party[0].dead, "the long dead stay dead")
	assert_false(st.party[1].dead, "this fight's fallen get up")
	assert_eq(st.party[2].hp, st.party[2].max_hp())
	assert_eq(int(st.get_flag("gl_car_retries", 0)), 1)


func test_the_lost_locomotive_fight_is_closed_when_its_retry_begins() -> void:
	var st := _party(1)
	var rule := FightRetry.rule_for({"id": "gl_locomotive"}, "ghostlight_wreckage")
	(st.loc_state("ghostlight_wreckage")["encounters"] as Dictionary)["gl_locomotive"] = "started"
	FightRetry.close_lost(st, "ghostlight_wreckage", rule, {"id": "gl_locomotive"})
	st.location = "ghostlight_wreckage"
	st.set_flag("gl_locomotive_done")
	assert_false("gl_locomotive" in RestRules.unfinished_fights(st), "no fight left unfinished at the wreck once the retry is won")
	# A retry of the same fight leaves its state alone: it is begun again.
	(st.loc_state("ghostlight_g8_tender")["encounters"] as Dictionary)["gl_stoker"] = "started"
	FightRetry.close_lost(st, "ghostlight_g8_tender", FightRetry.rule_for({"id": "gl_stoker"}, "ghostlight_g8_tender"), {"id": "gl_stoker"})
	assert_eq(str((st.loc_state("ghostlight_g8_tender")["encounters"] as Dictionary)["gl_stoker"]), "started")


func test_the_wrecks_rest_text_moves_on_after_the_locomotive() -> void:
	var st := _party(1)
	var loc := Compendium.shared().get_entry("locations", "ghostlight_wreckage")
	assert_true(RestRules.text_of(loc, st).contains("cans"))
	st.set_flag("gl_locomotive_done")
	assert_false(RestRules.text_of(loc, st).contains("cans"), "no more talk of the cans once they're done with")
	assert_eq(RestRules.rule_of(loc, st), "no")


# --- Searching and walking ----------------------------------------------------------------------------------------

func test_a_missed_find_can_be_searched_for_again_after_a_rest() -> void:
	var st := _party(1)
	var found := st.loc_state("ghostlight_g1_passenger")["found"] as Dictionary
	found["missed:g1_marble_jar:rook_coldwake"] = true
	found["g1_other_find"] = true
	RestRules.note_short_rest(st)
	assert_false(found.has("missed:g1_marble_jar:rook_coldwake"), "rested eyes look again")
	assert_true(bool(found.get("g1_other_find", false)), "what was found stays found")


func test_the_lamps_call_only_when_the_vagrant_has_something_to_say() -> void:
	var st := _party(1)
	st.set_flag("gl_vagrant_briefed")
	for car in CARS:
		for p: Variant in Compendium.shared().get_entry("locations", car).get("props", []):
			var prop := p as Dictionary
			if str(prop.get("call", "")) != "ghostlight_express/vagrant_intercom:router":
				continue
			var when := str(prop.get("call_when", ""))
			assert_false(StoryConditions.check(when, st), "%s: nothing to say yet, so no call" % prop["id"])
			st.set_flag("haints_resolved", 1)
			assert_true(StoryConditions.check(when, st), "%s: the first haint's check-in" % prop["id"])
			st.set_flag("gl_checkin_first")
			assert_false(StoryConditions.check(when, st), "%s: said already" % prop["id"])
			st.flags.erase("haints_resolved")
			st.flags.erase("gl_checkin_first")


# --- Death on the train ---------------------------------------------------------------------------------------------

## Ashwin, 2026-11-02: a hero who dies stays dead until raised; one at 0 Hit Points follows the 2024 rules (Stable: 1 Hit
## Point after 1d4 hours, `stable_wakes`).
func test_on_the_train_the_dead_stay_dead_and_the_downed_come_round() -> void:
	var st := _party(1)
	st.party[0].dead = true
	st.party[0].hp = 0
	st.party[1].hp = 0
	st.party[1].stable = true
	for i in 4:
		st.advance_minutes(60)
	assert_true(st.party[0].dead, "the dead stay dead")
	assert_eq(st.party[1].hp, 1, "the downed come round")
