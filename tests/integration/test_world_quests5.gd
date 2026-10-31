extends TestCase
## Side quests batch 5 (the Ghostlight Express): The Conductor's Punch, A Seat for the Lord and Lady and Mrs. Calloway.
##
## Express: a person is only talked to while their entry's `when` holds and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")
const TOWN := "ghostlight_g1_passenger"

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


func test_the_conductors_punch_by_clue_and_return() -> void:
	_play("ghostlight_express/punch:start", ["look for the punch"])
	assert_eq(st.quest_stage("conductors_punch"), "asked")
	_play("ghostlight_express/punch:stub")
	_play("ghostlight_express/punch:stub_mail")
	assert_eq(int(st.get_flag("punch_clue", 0)), 2)
	_play("ghostlight_express/punch:chest", ["Open it with the stubs"])
	assert_true(bool(st.get_flag("punch_found")))
	assert_eq(st.quest_stage("conductors_punch"), "found")
	_play("ghostlight_express/punch:return", ["Give it to the understudy"])
	assert_eq(st.quest_stage("conductors_punch"), "done")
	assert_eq(str(st.get_flag("punch_outcome", "")), "understudy")


func test_the_punch_chest_opens_by_search_too() -> void:
	_play("ghostlight_express/punch:start", ["look for the punch"])
	_play("ghostlight_express/punch:chest", ["Search the chest"])
	assert_true(bool(st.get_flag("punch_found")))


func test_a_seat_for_the_lord_peaceful_and_loud_both_end_the_quest() -> void:
	_play("ghostlight_express/seating:start", ["see to it"])
	assert_eq(st.quest_stage("a_seat_for_the_lord"), "asked")
	_play("ghostlight_express/seating:seat", ["songstress first"])
	assert_eq(st.quest_stage("a_seat_for_the_lord"), "done")
	assert_eq(str(st.get_flag("seating_outcome", "")), "peaceful")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	_play("ghostlight_express/seating:start", ["see to it"])
	_play("ghostlight_express/seating:seat", ["harlequin first"])
	assert_eq(str(st.get_flag("seating_outcome", "")), "loud")
	assert_eq(st.quest_stage("a_seat_for_the_lord"), "done")


func test_mrs_calloway_has_a_supper_and_a_way_out() -> void:
	_play("ghostlight_express/folk_train:calloway_start", ["Sit and eat"])
