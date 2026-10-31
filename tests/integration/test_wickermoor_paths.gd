extends TestCase
## R11, Wickermoor: the arrival's branches, the welcome, the four subplots (Gory Gus, the Play, a Bad Seed, the Lottery), the Oak, and every
## person's first conversation, each played through the DialogueRunner with dice that always roll high, the way test_r10_playthrough plays the
## Express: a person is only talked to while their entry's `when` holds and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")
const TOWN := "wickermoor_village"

## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var st: StoryState
var dice := HighDice.new()
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


func test_holding_back_lets_the_wolves_take_the_doll_and_there_is_no_fight() -> void:
	_play("wickermoor/arrival:start", ["Keep back"])
	assert_eq(str(st.get_flag("goat_fate", "")), "eaten")
	assert_true(bool(st.get_flag("wm_first_sacrifice_done")))
	assert_true(fights.is_empty(), "no fight")
	assert_eq(st.quest_stage("wickermoor_arrival"), "welcome")


func test_cutting_the_doll_open_starts_the_wolves_and_spoils_the_rite() -> void:
	_play("wickermoor/arrival:start", ["Cut the bound shape free"])
	assert_eq(fights, ["wm_first_sacrifice"] as Array[String])
	assert_eq(str(st.get_flag("goat_fate", "")), "freed")
	assert_true(bool(st.get_flag("old_ways_offended")))
	assert_eq(st.quest_stage("wickermoor_arrival"), "welcome")


func test_a_close_look_at_the_doll_is_had_once() -> void:
	_play("wickermoor/arrival:start", ["Look closer", "Leave the offering alone"])
	assert_true(bool(st.get_flag("wm_doll_inspected")))
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start("wickermoor/arrival:start"))
	var b := r.next()
	while str(b["kind"]) != "options" and str(b["kind"]) != "end":
		b = r.next()
	for o: Variant in (b["options"] as Array):
		assert_true(not str((o as Dictionary)["text"]).contains("Look closer"), "the look is spent")


func test_the_welcome_opens_the_estate_road_and_the_parting_waits_for_the_inn() -> void:
	_play("wickermoor/arrival:start", ["Keep back"])
	_play("wickermoor/mayor_welcome:start", ["Ask about the village", "Thank him", "glad to come"])
	assert_true(bool(st.get_flag("wm_welcomed")))
	assert_eq(st.quest_stage("wickermoor_arrival"), "parting", "the journal waits at the parting until the inn")


func test_gory_gus_from_the_body_to_marta() -> void:
	st.set_flag("gus_body_found")
	_play("wickermoor/gus:body", ["Offer to help"])
	assert_eq(st.quest_stage("gory_gus"), "clues")
	_play("wickermoor/gus:mori")
	_play("wickermoor/gus:beatrice")
	assert_true(bool(st.get_flag("gus_clue_hair")) and bool(st.get_flag("gus_clue_axe")))
	_play("wickermoor/gus:marta", ["Draw weapons"])
	assert_eq(fights, ["wm_gus_marta"] as Array[String])
	assert_true(bool(st.get_flag("gus_marta_down")))
	_play("wickermoor/gus:solved")
	assert_eq(st.quest_stage("gory_gus"), "solved")


func test_the_play_from_the_pitch_to_the_finale() -> void:
	_arrive("wickermoor_green_queen_inn")
	st.set_flag("play_arrived")
	_play("wickermoor/play:hickock_pitch")
	assert_eq(st.quest_stage("the_play"), "arrival")
	st.set_flag("play_victim_dead")
	_play("wickermoor/play:body", ["Examine the fallen cup", "Check Barnaby", "Say we have what we need", "Accuse Olwen", "Take Barnaby's part"])
	assert_true(bool(st.get_flag("play_accused_olwen")))
	assert_eq(st.quest_stage("the_play"), "solved")


func test_a_bad_seed_from_morgan_to_the_orchard() -> void:
	st.set_flag("picnic_sick")
	_play("wickermoor/bad_seed:morgan_apples", ["We will go"])
	assert_eq(st.quest_stage("bad_seed"), "orchard")
	_arrive("wickermoor_orchard")
	_play("wickermoor/bad_seed:cecil", ["Draw your weapon"])
	assert_eq(fights, ["wm_bad_seed"] as Array[String])
	assert_true(bool(st.get_flag("seed_fought")))
	_play("wickermoor/bad_seed:cured")
	assert_eq(st.quest_stage("bad_seed"), "cured")


func test_the_lottery_pays_a_winner_and_ends_when_the_ledger_is_torn() -> void:
	st.gold = 20.0
	_play("wickermoor/lottery:start", ["Buy a slip"])
	assert_eq(st.gold, 110.0, "ten for the slip, a hundred for the win")
	assert_true(bool(st.get_flag("wm_lottery_done")))
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		st.party.append(Pregens.build(id, 3))
	_play("wickermoor/lottery:start", ["Look closer", "Tear the ledger"])
	assert_true(bool(st.get_flag("wm_lottery_broken")))


func test_the_oak_wakes_only_for_a_party_of_level_six() -> void:
	st.set_flag("old_ways_offended")
	_play("wickermoor/oak:start", ["Hold still"])
	assert_true(fights.is_empty(), "a low party is only warned")
	assert_eq(st.quest_stage("souls_of_the_oak"), "whispers")


func test_doris_acts_on_a_cultist_only_with_both_a_tell_and_a_proof() -> void:
	_arrive("wickermoor_constable_station")
	_play("wickermoor/doris_squire:start", ["Report a suspicion", "Alda Farnum", "Never mind"])
	assert_true(not bool(st.get_flag("accused_alda")), "a bare accusation is not enough")
	st.set_flag("cult_clue_alda_farnum")
	st.set_flag("cult_proof_alda")
	_play("wickermoor/doris_squire:start", ["Report a suspicion", "Alda Farnum", "Never mind"])
	assert_true(bool(st.get_flag("accused_alda")))
	_play("wickermoor/doris_squire:start", ["Report a suspicion", "Theodora Mayville", "Never mind"])
	assert_true(not bool(st.get_flag("accused_theodora")), "the postmaster cannot be accused early")


func test_the_pyethymer_gate_is_looked_at_and_stays_chained() -> void:
	_play("wickermoor/pyethymer:gate", ["Ask what folk say", "Leave it"])
	assert_eq(st.quest_stage("the_pyethymer_place"), "rumour")
	_play("wickermoor/pyethymer:gate", ["Try the chain"])
	assert_eq(st.quest_stage("the_pyethymer_place"), "chained")


func test_every_persons_first_conversation_plays_through() -> void:
	var seen := 0
	for loc: Dictionary in Compendium.shared().all("locations"):
		var id := str(loc["id"])
		if not id.begins_with("wickermoor_"):
			continue
		st.location = id
		for n: Dictionary in loc.get("npcs", []):
			if str(n.get("dialogue", "")) == "":
				continue
			var r := DialogueRunner.new(st, dice)
			assert_true(r.start(str(n["dialogue"])), "%s starts (%s)" % [n["dialogue"], n["npc"]])
			seen += 1
	assert_true(seen >= 60, "sixty or more conversations are placed (found %d)" % seen)


func test_a_freed_goat_runs_loose_in_the_wolf_fight_and_can_be_caught() -> void:
	st.set_flag("goat_fate", "freed")
	var goat := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == "wm_first_sacrifice" and (e as Dictionary).has("when"):
			for m: Variant in (e as Dictionary)["monsters"]:
				if str((m as Dictionary)["monster"]) == "goat":
					goat = m as Dictionary
			assert_true(_holds(str((e as Dictionary)["when"])), "the loose-goat fight is the one picked")
	assert_eq(str((goat.get("catch", {}) as Dictionary).get("flag", "")), "goat_caught")


func test_giving_in_to_the_watch_jails_the_party_and_doris_lets_them_out() -> void:
	st.set_flag("crime_wickermoor", 2)
	Jail.lock_up(st, "wickermoor_constable_station", "cells", "days_since.jailed >= 1", false)
	assert_true(_holds("jailed"))
	st.location = "wickermoor_constable_station"
	var exit := _entry("exits", "id", "door")
	assert_false(_holds(str(exit.get("when", ""))), "the door is shut while held")
	_play("watch/wickermoor:jail_talk", ["Ask for our gear"])
	assert_false(_holds("jailed"))
	assert_true(_holds(str(exit.get("when", ""))))
