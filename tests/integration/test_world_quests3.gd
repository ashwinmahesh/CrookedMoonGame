extends TestCase
## Side quests batch 3 (Wickermoor): What Mori Keeps, Hair of the Dog, Brother Elias and the Rusty/Connection gates.
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


func test_what_mori_keeps_waits_for_the_crooked_house_then_closes() -> void:
	_play("wickermoor/mori:start", ["Look at the list", "Burn the list"])
	assert_eq(st.quest_stage("what_mori_keeps"), "decided")
	assert_eq(str(st.get_flag("mori_outcome", "")), "burn")
	st.set_flag("vessla_slain")
	_play("wickermoor/mori:later")
	assert_eq(st.quest_stage("what_mori_keeps"), "done")


func test_every_choice_about_moris_list_is_available() -> void:
	for pick: String in ["Warn", "Burn", "Doris", "Say nothing"]:
		GameState.reset()
		st = GameState.story
		for id: String in GAME.NEW_GAME_PARTY:
			var ch := Pregens.build(id, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		_play("wickermoor/mori:start", ["Look at the list", pick])
		assert_eq(st.quest_stage("what_mori_keeps"), "decided", pick)


func test_hair_of_the_dog_two_clues_then_every_ending() -> void:
	_play("wickermoor/hair:start", ["look into it"])
	_play("wickermoor/hair:clue_barber", ["Read the labels"])
	_play("wickermoor/hair:clue_funeral")
	assert_true(bool(st.get_flag("hair_clue_a")) and bool(st.get_flag("hair_clue_b")))
	st.gold = 80.0
	_play("wickermoor/hair:confront", ["Offer to pay"])
	assert_eq(st.quest_stage("hair_of_the_dog"), "done")
	assert_eq(st.gold, 30.0)


func test_a_failed_clue_check_never_locks_the_mystery() -> void:
	# the funeral home's jar needs no check, and the barber's labels have a fail line that points on
	_play("wickermoor/hair:start", ["look into it"])
	_play("wickermoor/hair:clue_funeral")
	st.set_flag("hair_clue_a")
	_play("wickermoor/hair:confront", ["Keep his secret"])
	assert_eq(str(st.get_flag("hair_outcome", "")), "kept")


func test_brother_elias_and_his_crow() -> void:
	_play("wickermoor/elias:start", ["which faith"])


func test_the_connections_wait_for_the_crooked_house() -> void:
	var town := Compendium.shared().get_entry("locations", "wickermoor_village")
	var found := 0
	for n: Variant in town["npcs"]:
		if str((n as Dictionary).get("when", "")).contains("connection_"):
			found += 1
			assert_true(str((n as Dictionary)["when"]).contains("flag.vessla_slain"), str(n))
	assert_true(found >= 3)


func test_rusty_takes_up_find_my_son_after_the_seance_asks() -> void:
	st.set_flag("patrini_asked_find_son")
	var town := Compendium.shared().get_entry("locations", "wickermoor_village")
	var first := {}
	for n: Variant in town["npcs"]:
		if str((n as Dictionary)["npc"]) == "old_rusty" and (first.is_empty() and _holds((n as Dictionary).get("when", ""))):
			first = n as Dictionary
	assert_eq(str(first.get("dialogue", "")), "crooked_house/find_my_son:start")
