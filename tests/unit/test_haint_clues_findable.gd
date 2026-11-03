extends TestCase
## The haint quest items that sit in hidden props must be findable with the F key the player really uses (Ashwin, 2026-11-03:
## "I am searching the entire mail room (pressing the F key with higher than 13 perception rolls). Still not finding the lover's
## letter"): Jakob Braun's letter (the pink envelope in the Mail Car) and the toad-faced stone (the marionette chest in the
## Circus Car) were Investigation finds, which the F key's Perception roll never counted, and a miss shut that hero out for good.
## Now the F search's own roll finds them, a miss can be tried again, and a small glint shows where each is until it is found.

class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


class LowDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(1)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


const PROPS := {
	"ghostlight_g5_mail": ["g5_pink_envelope", "jakob_braun_letter"],
	"ghostlight_g7_circus": ["g7_marionette_chest", "toad_faced_stone"],
}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view(id: String, dice: Variant) -> LocationView:
	GameState.reset()
	var st := GameState.story
	for pid: String in preload("res://world/game_root.gd").PLACEHOLDER_PARTY:
		st.party.append(Pregens.build(pid, 3))
	st.location = id
	var view := LocationView.create(id, st, Narrator.new(), dice, "default")
	add_child(view)
	return view


func _prop(loc: String, pid: String) -> Dictionary:
	for p: Variant in Compendium.shared().get_entry("locations", loc)["props"]:
		if str((p as Dictionary)["id"]) == pid:
			return p as Dictionary
	return {}


## The party on the nearest walkable square within the F search's reach (15 ft) of the prop.
func _stand_beside(view: LocationView, prop: Dictionary) -> void:
	var cell := LocationView._cell(prop["cell"])
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var c := cell + Vector2i(dx, dy)
			if c == cell or not view.grid.in_bounds(c) or view.grid.is_solid(c):
				continue
			var d := absi(dx) + absi(dy)
			if view.grid.distance_ft(c, 1, cell, 1) <= LocationTraps.SEARCH_FT and d < best_d:
				best = c
				best_d = d
	assert_true(best.x >= 0, "there is a square the search reaches it from")
	LocationParty.move_to_cell(view, best)


func test_the_quest_props_are_clues_the_f_search_can_find() -> void:
	for loc: String in PROPS:
		var pid := str((PROPS[loc] as Array)[0])
		var prop := _prop(loc, pid)
		assert_true(bool(prop.get("clue", false)), "%s is marked as a clue" % pid)
		assert_true(bool(prop.get("retry", false)), "%s can be looked for again after a miss" % pid)
		assert_ne(str(prop.get("skill", "")), "investigation", "%s is found with the Perception roll the F key makes" % pid)


func test_a_good_f_search_beside_each_finds_it_and_the_glint_goes() -> void:
	for loc: String in PROPS:
		var pid := str((PROPS[loc] as Array)[0])
		var prop := _prop(loc, pid)
		var view := _view(loc, HighDice.new())
		await _frames(3)
		assert_true(view.prop_nodes.has(pid + "#glint"), "%s: a glint shows where it is" % pid)
		_stand_beside(view, prop)
		view.search()
		await _frames(2)
		assert_true(bool((view.st.loc_state(loc)["found"] as Dictionary).get(pid, false)), "%s is found by the F key's search" % pid)
		assert_false(view.prop_nodes.has(pid + "#glint"), "%s: the glint goes once it is found" % pid)
		assert_true(view.prop_nodes.has(pid), "%s is drawn once found" % pid)
		view.queue_free()
		await get_tree().process_frame
	GameState.reset()


func test_a_miss_does_not_shut_the_hero_out() -> void:
	for loc: String in PROPS:
		var pid := str((PROPS[loc] as Array)[0])
		var prop := _prop(loc, pid)
		var view := _view(loc, LowDice.new())
		await _frames(3)
		_stand_beside(view, prop)
		view.search()
		await _frames(2)
		assert_false(bool((view.st.loc_state(loc)["found"] as Dictionary).get(pid, false)), "%s: a bad roll misses it" % pid)
		var who := view.leader().creature as Character
		assert_true(LocationTraps.hidden_within(view, view.leader().cell, LocationTraps.SEARCH_FT, who).any(func(p: Dictionary) -> bool: return str(p["id"]) == pid),
			"%s: the same hero can look again" % pid)
		view.queue_free()
		await get_tree().process_frame
	GameState.reset()
