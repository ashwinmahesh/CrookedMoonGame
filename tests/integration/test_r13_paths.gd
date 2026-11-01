extends TestCase
## R13, Fields of the Crow: the hook in Wickermoor, the arrival, the mill, the town's clues, the gate, the seeded maze, Raum, the farewell and
## the way home, each played through the DialogueRunner with dice that always roll high, the way test_r10_playthrough plays the
## Express: a person is only talked to while their entry's `when` holds and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")
const TOWN := "foxwillow"

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


func test_the_hook_sets_the_ride_out() -> void:
	st.location = "wickermoor_village"
	_play("foxwillow/hook:jeremiah_start", ["ride out"])
	assert_true(bool(st.get_flag("foxwillow_asked")))
	assert_eq(st.quest_stage("fields_of_the_crow"), "asked")


func test_arriving_shows_the_body_rule_and_the_burning_town() -> void:
	_play("foxwillow/arrival:start", ["what we are looking at", "Ride in"])
	assert_true(bool(st.get_flag("fw_arrived")))
	assert_true(bool(st.get_flag("body_rule_told")))
	assert_eq(st.quest_stage("fields_of_the_crow"), "burning")


func test_martha_sends_the_party_to_the_mill_and_the_mill_can_be_won() -> void:
	_play("foxwillow/arrival:martha_plea", ["We will get him out"])
	assert_true(bool(st.get_flag("fw_mill_asked")))
	_arrive("fw_windmill")
	_play("foxwillow/extras:mill_start", ["Climb to Jonah"])
	assert_eq(fights, ["fw_mill"] as Array[String])
	assert_eq(st.quest_stage("the_burning_mill"), "rescued")
	_play("foxwillow/windmill:jonah_rescued", ["get out"])
	assert_true(bool(st.get_flag("jonah_saved")))


func test_turning_back_loses_jonah() -> void:
	_arrive("fw_windmill")
	_play("foxwillow/extras:mill_start", ["turn back"])
	assert_true(bool(st.get_flag("jonah_dead")))
	assert_eq(st.quest_stage("the_burning_mill"), "lost")


func test_the_town_gives_the_tender_secrets() -> void:
	_play("foxwillow/townsfolk:hall_notice")
	assert_true(bool(st.get_flag("tender_certificate")))
	_play("foxwillow/townsfolk:lib_song", [])
	_play("foxwillow/townsfolk:librarian", ["Ask for the song"])
	assert_true(bool(st.get_flag("song_known")))


func test_the_gate_takes_a_secret_and_opens_the_maze() -> void:
	_play("foxwillow/gate:start", ["of my own"])
	assert_true(bool(st.get_flag("maze_open")))
	assert_eq(int(st.get_flag("secrets_paid", 0)), 1)


func test_each_secret_told_to_raum_is_remembered() -> void:
	st.set_flag("secret_martha")
	_play("foxwillow/gate:start", ["Martha"])
	assert_true(bool(st.get_flag("told_raum_martha")))


func test_the_maze_has_one_way_on_at_every_junction_and_dead_ends_that_lead_back() -> void:
	var maze := (JSON.parse_string(FileAccess.get_file_as_string("res://data/maze.json")) as Dictionary)
	var junctions := maze["junctions"] as Array
	for seed_value: int in [1, 7, 42, 20261031]:
		for at in junctions.size():
			var j := str(junctions[at])
			var ways := 0
			for mouth: String in ["left", "centre", "right"]:
				var to := CrookedMoonCampaign.maze_target(seed_value, j, mouth)
				if to == (str(junctions[at + 1]) if at + 1 < junctions.size() else str(maze["circle"])):
					ways += 1
					assert_eq(mouth, CrookedMoonCampaign.maze_way_on(seed_value, j))
				else:
					assert_eq(to, str((maze["dead"] as Array)[at]))
			assert_eq(ways, 1, "junction %s has one way on for seed %d" % [j, seed_value])


func test_adelaide_can_be_talked_free() -> void:
	_arrive("fw_maze_j2")
	_play("foxwillow/maze:adelaide", ["Remind her of Martha"])
	assert_true(bool(st.get_flag("adelaide_freed")))


func test_the_lost_soul_is_saved_once() -> void:
	_arrive("fw_maze_j3")
	_play("foxwillow/maze:lost_soul")
	assert_eq(int(st.get_flag("lost_souls_saved", 0)), 1)
	assert_true(bool(st.get_flag("fw_lost_soul_saved")))


func test_raum_falls_jericho_rests_and_the_town_is_freed() -> void:
	_arrive("fw_circle")
	st.set_flag("song_known")
	_play("foxwillow/raum:prefight", ["Sing the song"])
	assert_eq(fights, ["fw_raum"] as Array[String])
	assert_true(bool(st.get_flag("raum_song_sung")))
	_play("foxwillow/raum:jericho_farewell", ["Bid him farewell"])
	assert_true(bool(st.get_flag("raum_slain")))
	assert_true(bool(st.get_flag("jericho_at_rest")))
	_arrive("foxwillow")
	_play("foxwillow/raum:coming_home")
	assert_eq(st.quest_stage("fields_of_the_crow"), "done")
	assert_eq(int(st.get_flag("act2_done", 0)), 1)


func test_the_reward_in_wickermoor() -> void:
	st.location = "wickermoor_village"
	st.set_flag("raum_slain")
	var before := st.gold
	_play("foxwillow/village_after:jeremiah_reward")
	assert_true(bool(st.get_flag("foxwillow_paid")))
	assert_true(st.gold > before)
