extends TestCase
## Side quests batch 4 (Foxwillow): Two Curses, The Scarecrows' Choir, Rosemary's Crow and the Foxwillow locals.
##
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


func test_two_curses_every_way_to_lift_it() -> void:
	_play("foxwillow/two_curses:start", ["look at it"])
	assert_eq(st.quest_stage("two_curses"), "asked")
	_play("foxwillow/two_curses:circle", ["Unpick the hex"])
	assert_eq(st.quest_stage("two_curses"), "done")
	assert_eq(str(st.get_flag("curses_outcome", "")), "unpicked")


func test_two_curses_talking_to_the_butcher_is_the_other_way() -> void:
	_play("foxwillow/two_curses:start", ["look at it"])
	_play("foxwillow/two_curses:malachai", ["Tell him the hex hurt"])
	assert_eq(str(st.get_flag("curses_outcome", "")), "truth")
	assert_eq(st.quest_stage("two_curses"), "done")


func test_the_choir_wakes_only_when_sung_in_order() -> void:
	_play("foxwillow/choir:start", ["We will teach"])
	assert_eq(st.quest_stage("scarecrows_choir"), "asked")
	_play("foxwillow/choir:teach", ["first verse", "Corn", "Crow", "Moon"])
	assert_true(bool(st.get_flag("choir_woken")))
	assert_eq(st.quest_stage("scarecrows_choir"), "done")


func test_a_wrong_verse_costs_ten_minutes_and_nothing_else() -> void:
	_play("foxwillow/choir:start", ["We will teach"])
	_play("foxwillow/choir:teach", ["first verse", "Moon", "first verse", "Corn", "Crow", "Moon"])
	assert_true(bool(st.get_flag("choir_woken")))


func test_rosemarys_crow_tom_then_a_choice() -> void:
	_play("foxwillow/rosemary:start", ["We will help"])
	_play("foxwillow/rosemary:old_tom")
	assert_true(bool(st.get_flag("crow_tom_heard")))
	_play("foxwillow/rosemary:decide", ["let it fly free"])
	assert_eq(st.quest_stage("rosemarys_crow"), "done")
	assert_eq(str(st.get_flag("crow_outcome", "")), "freed")


func test_the_foxwillow_locals_have_a_way_out() -> void:
	for ref: String in ["foxwillow/folk_foxwillow:agatha_start", "foxwillow/folk_foxwillow:tom_start"]:
		_play(ref)
