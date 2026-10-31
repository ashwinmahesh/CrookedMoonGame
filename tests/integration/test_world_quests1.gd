extends TestCase
## Side quests batch 1 (Wickermoor): the three connection-style hooks, the Grey Mare, Misdelivered, Bread and Circuses, Ambrose Quill and the Connections as quests.
##
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


func test_connection_quests_wait_then_close() -> void:
	st.set_flag("wm_welcomed", false)
	st.set_quest_stage("connection_evolution", "waiting")
	assert_eq(st.quest_stage("connection_evolution"), "waiting")
	_play("wickermoor/connections:thomasin_cordelia_start", ["Thank the tailor"])
	assert_eq(st.quest_stage("connection_evolution"), "met")


func test_the_grey_mare_found_caught_and_returned() -> void:
	_play("wickermoor/mare:start", ["We will find her"])
	assert_eq(st.quest_stage("the_grey_mare"), "asked")
	_play("wickermoor/mare:tracks", ["Follow them"])
	assert_true(bool(st.get_flag("mare_found")))
	_play("wickermoor/mare:mare_there", ["Offer oats"])
	assert_true(bool(st.get_flag("mare_caught")))
	_play("wickermoor/mare:return")
	assert_eq(st.quest_stage("the_grey_mare"), "done")
	assert_true(bool(st.get_flag("mare_returned")))


func test_giving_up_on_the_mare_fails_the_quest_and_costs_standing() -> void:
	_play("wickermoor/mare:start", ["We will find her"])
	var before := int(st.get_flag("standing_patient_lady", 0))
	_play("wickermoor/mare:progress", ["could not find her"])
	assert_eq(st.quest_stage("the_grey_mare"), "lost")
	assert_eq(int(st.get_flag("standing_patient_lady", 0)), before - 1)


func test_misdelivered_all_three_letters_and_every_ending() -> void:
	_play("wickermoor/misdelivered:start", ["We will help"])
	_play("wickermoor/misdelivered:doris_desk", ["Ask Doris"])
	_play("wickermoor/misdelivered:mori_ask", ["Ask for the letter"])
	_play("wickermoor/misdelivered:goat", ["Coax"])
	assert_true(bool(st.get_flag("letter_doris")) and bool(st.get_flag("letter_mori")) and bool(st.get_flag("letter_goat")))
	_play("wickermoor/misdelivered:deliver", ["Tell Howie the truth"])
	assert_eq(st.quest_stage("misdelivered"), "done")
	assert_eq(str(st.get_flag("misdelivered_outcome", "")), "truth")


func test_bread_and_circuses_runs_to_the_ode() -> void:
	_play("wickermoor/feast:holly_start", ["We will help"])
	assert_eq(st.quest_stage("bread_and_circuses"), "asked")
	_play("wickermoor/feast:siv_visit", ["Taste", "Carry a roll"])
	_play("wickermoor/feast:mayor_judges", ["Praise Holly"])
	assert_eq(st.quest_stage("bread_and_circuses"), "done")
	assert_true(bool(st.get_flag("feast_done")))
	assert_eq(str(st.get_flag("feast_winner", "")), "holly")


func test_ambrose_quill_reads_one_more_verse_each_visit() -> void:
	for i in 4:
		_play("wickermoor/quill:start", ["verse"])
		assert_eq(int(st.get_flag("quill_verses", 0)), i + 1)
