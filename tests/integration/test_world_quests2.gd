extends TestCase
## Side quests batch 2 (Wickermoor): A Fair Price, Weight on the Bell, the Field Trip, and the humorous locals.
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


func test_a_fair_price_every_way_to_settle_it() -> void:
	_play("wickermoor/fair_price:baltus_start", ["We will look"])
	assert_eq(st.quest_stage("a_fair_price"), "asked")
	_play("wickermoor/fair_price:eleanor_visit", ["Study her ledger"])
	assert_true(bool(st.get_flag("price_ledger_seen")))
	_play("wickermoor/fair_price:broker", ["Broker a truce", "Argue a fair price"])
	assert_eq(str(st.get_flag("price_outcome", "")), "truce")
	assert_eq(st.quest_stage("a_fair_price"), "done")


func test_a_fair_price_the_auditor_is_the_second_way() -> void:
	st.gold = 50.0
	_play("wickermoor/fair_price:baltus_start", ["We will look"])
	_play("wickermoor/fair_price:tamsin_audit", ["Pay ten gold"])
	assert_true(bool(st.get_flag("price_ledger_seen")))
	assert_eq(st.gold, 40.0)
	_play("wickermoor/fair_price:broker", ["Tell Baltus"])
	assert_eq(str(st.get_flag("price_outcome", "")), "baltus")


func test_the_bell_arrives_by_either_road_with_a_stowaway() -> void:
	_play("wickermoor/bell:start", ["We will carry it"])
	assert_eq(st.quest_stage("weight_on_the_bell"), "asked")
	_play("wickermoor/bell:cart", ["Take the moor road", "Pick the firm ground", "Let him ride"])
	assert_eq(st.quest_stage("weight_on_the_bell"), "done")
	assert_eq(str(st.get_flag("bell_pip", "")), "rides")


func test_abandoning_the_bell_fails_the_quest() -> void:
	_play("wickermoor/bell:start", ["We will carry it"])
	_play("wickermoor/bell:cart", ["Abandon"])
	assert_eq(st.quest_stage("weight_on_the_bell"), "lost")


func test_the_field_trip_gathers_four_things_and_asks_for_a_choice() -> void:
	_play("wickermoor/fieldtrip:start", ["We will gather"])
	_play("wickermoor/fieldtrip:pip_button", ["Tell him a story"])
	_play("wickermoor/fieldtrip:rusty_fact")
	_play("wickermoor/fieldtrip:rope", ["Ask Solomon"])
	_play("wickermoor/fieldtrip:chalk", ["Copy the mark"])
	assert_eq(int(st.get_flag("field_items", 0)), 4)
	_play("wickermoor/fieldtrip:report", ["Let Finneas decide"])
	assert_eq(st.quest_stage("field_trip"), "done")
	assert_eq(str(st.get_flag("field_outcome", "")), "silence")


func test_the_humorous_locals_have_something_to_say_and_a_way_out() -> void:
	for ref: String in ["wickermoor/folk:tamsin_start", "wickermoor/folk:gaunt_start", "wickermoor/folk:pip_start"]:
		_play(ref)
