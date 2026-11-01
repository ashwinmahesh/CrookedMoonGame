extends TestCase
## The thirteen Connections (R11, after the Crooked House): each has an NPC entry gated on vessla_slain, plays through and closes its quest; the five that begin on the train wait first.
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


const THREADS := ["evolution", "ascendancy", "slaughter", "pilgrimage", "liberation", "rejuvenation", "apocalypse", "deliverance", "duality", "immortality", "kindred", "malediction", "rapture"]
const INCITED := ["evolution", "ascendancy", "liberation", "apocalypse", "deliverance"]


## Every NPC entry across the village and its rooms whose `when` names this thread's flag: [location id, entry].
func _entries_for(thread: String) -> Array:
	var out: Array = []
	for loc_id: String in Compendium.shared().all("locations").map(func(l: Dictionary) -> String: return str(l["id"])):
		if not loc_id.begins_with("wickermoor"):
			continue
		for n: Variant in Compendium.shared().get_entry("locations", loc_id).get("npcs", []):
			if str((n as Dictionary).get("when", "")).contains("not flag.connection_" + thread):
				out.append([loc_id, n])
	return out


func test_every_connection_has_one_entry_gated_on_the_crooked_house() -> void:
	for thread: String in THREADS:
		var found := _entries_for(thread)
		assert_eq(found.size(), 1, "%s has its one scene" % thread)
		if found.size() == 1:
			assert_true(str(((found[0] as Array)[1] as Dictionary)["when"]).contains("flag.vessla_slain"), "%s waits for the Crooked House" % thread)


func test_every_connection_scene_plays_through_and_closes_its_quest() -> void:
	for thread: String in THREADS:
		var found := _entries_for(thread)
		if found.is_empty():
			continue
		GameState.reset()
		st = GameState.story
		for id: String in GAME.NEW_GAME_PARTY:
			var ch := Pregens.build(id, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		st.set_flag("vessla_slain")
		if thread in INCITED:
			st.set_quest_stage("connection_" + thread, "waiting")
		var entry := (found[0] as Array)[1] as Dictionary
		_play(str(entry["dialogue"]))
		assert_true(bool(st.get_flag("connection_" + thread)), "%s sets its flag" % thread)
		assert_eq(st.quest_stage("connection_" + thread), "met", "%s closes its quest" % thread)


func test_the_waiting_stages_wait_on_the_crooked_house() -> void:
	for thread: String in INCITED:
		var q := Compendium.shared().get_entry("quests", "connection_" + thread)
		var waits := {}
		for s: Variant in q["stages"]:
			if (s as Dictionary).has("waits"):
				waits = (s as Dictionary)["waits"] as Dictionary
		assert_eq(str(waits.get("until", "")), "flag.vessla_slain", thread)
