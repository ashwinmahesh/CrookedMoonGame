extends TestCase
## Act 2 batch 1 (Wickermoor during the plague): Quarantine Notices, Soup for the Sick, Oakum's Curse, Walder Pye's Letter, The Quack and Granny Orla.
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


func test_quarantine_notices_three_seals_then_filed() -> void:
	_play("wickermoor/quarantine:start", ["fetch the seals"])
	_play("wickermoor/quarantine:tamsin_seal", ["Take her word"])
	_play("wickermoor/quarantine:post_seal", ["Show Tamsin"])
	assert_true(bool(st.get_flag("seal_tamsin")) and bool(st.get_flag("seal_post")))
	_play("wickermoor/quarantine:file")
	assert_eq(st.quest_stage("quarantine_notices"), "done")


func test_a_forged_post_seal_still_files_the_notices() -> void:
	_play("wickermoor/quarantine:start", ["fetch the seals"])
	_play("wickermoor/quarantine:post_seal", ["Forge"])
	assert_true(bool(st.get_flag("seal_post")))


func test_soup_for_the_sick_remembers_who_won_the_bake_off() -> void:
	st.set_flag("feast_winner", "siv")
	_play("wickermoor/soup:holly_start", ["talk to Siv"])
	_play("wickermoor/soup:siv_talk", ["Remind him he won"])
	assert_true(bool(st.get_flag("soup_siv")))
	_play("wickermoor/soup:stove", ["Split the shifts"])
	_play("wickermoor/soup:serve")
	assert_eq(st.quest_stage("soup_for_the_sick"), "done")


func test_soup_can_be_bought_when_pride_will_not_move() -> void:
	st.set_flag("feast_winner", "holly")
	st.gold = 30.0
	_play("wickermoor/soup:holly_start", ["talk to Siv"])
	_play("wickermoor/soup:siv_talk", ["Pay for the bones"])
	assert_true(bool(st.get_flag("soup_siv")))
	assert_eq(st.gold, 20.0)


func test_oakums_curse_every_way_to_keep_faith() -> void:
	for pick: String in ["Keep her secret", "Tell Siv", "Promise to find a cure"]:
		GameState.reset()
		st = GameState.story
		for id: String in GAME.NEW_GAME_PARTY:
			var ch := Pregens.build(id, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		_play("wickermoor/oakum:start", ["keep out of it"])
		st.set_flag("oakum_known")
		_play("wickermoor/oakum:choose", [pick])
		assert_eq(st.quest_stage("oakums_curse"), "done", pick)


func test_walders_letter_sent_by_hilda_or_seized_at_the_counter() -> void:
	_play("wickermoor/letter:effects", ["Take the letter"])
	assert_eq(st.quest_stage("walders_letter"), "asked")
	_play("wickermoor/letter:hilda", ["Give her"])
	assert_eq(st.quest_stage("walders_letter"), "done")
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	_play("wickermoor/letter:effects", ["Take the letter"])
	_play("wickermoor/letter:counter", ["Hand it over"])
	assert_eq(st.quest_stage("walders_letter"), "lost")


func test_the_quack_is_settled_three_ways() -> void:
	st.gold = 10.0
	_play("wickermoor/quack:morgan_ask", ["look into it"])
	_play("wickermoor/quack:pitch", ["Buy a bottle"])
	_play("wickermoor/quack:verdict", ["Taste the bottle"])
	assert_true(bool(st.get_flag("quack_known")))
	_play("wickermoor/quack:settle", ["Expose him"])
	assert_eq(st.quest_stage("the_quack"), "done")


func test_granny_orla_judges_your_singing() -> void:
	_play("wickermoor/folk_plague:orla_start", ["sing yourself"])
	assert_true(bool(st.get_flag("orla_sang")))
