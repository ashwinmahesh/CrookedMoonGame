extends TestCase
## A ladder between floors is something the player uses (Ashwin, 2026-11-03: "I can't interact with the ladders in the train cars to
## climb to the 2nd floors"): it is pointed at, hovered as "Climb up the ladder", and clicked to walk to its foot and climb it, and
## clicked again up top to come down. Before this the ladders were only drawn and laid into the pathfinding, and the floor above is
## out of sight from below, so there was nothing to click.

const CAR := "ghostlight_g3_lounge"
const LOFT := "wickermoor_stable"


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view(id: String) -> LocationView:
	GameState.reset()
	var st := GameState.story
	for pid: String in preload("res://world/game_root.gd").PLACEHOLDER_PARTY:
		st.party.append(Pregens.build(pid, 3))
	st.location = id
	var view := LocationView.create(id, st, Narrator.new(), Dice.roller, "default")
	add_child(view)
	return view


func _floor_of_leader(view: LocationView) -> int:
	return view.grid.floor_index(view.leader().cell)


func _check_ladder(id: String) -> void:
	var view := _view(id)
	await _frames(3)
	var ladders := LocationInteraction.ladders_here(view)
	assert_true(ladders.size() >= 1, "%s: a ladder reaches the floor the party stands on" % id)
	if ladders.is_empty():
		view.queue_free()
		return
	var foot: Vector2i = ladders[0]["here"]
	var top: Vector2i = ladders[0]["there"]
	var start_floor := _floor_of_leader(view)
	assert_true(bool(ladders[0]["up"]), "%s: from the ground it climbs up" % id)
	var thing := LocationInteraction.thing_at(view, foot)
	assert_eq(str(thing.get("kind", "")), "ladder", "%s: the foot of the ladder is a thing to use" % id)
	assert_true(str(thing.get("label", "")).contains("up"), "%s: it says it climbs up" % id)
	assert_true(LocationInteraction._pickables(view).any(func(e: Array) -> bool: return e[1] == foot), "%s: the drawn ladder can be pointed at" % id)
	var menu := LocationInteraction.actions_at(view, foot)
	assert_true((menu["actions"] as Array).any(func(a: Dictionary) -> bool: return str(a["id"]) == "climb_ladder"), "%s: the right-click menu offers it" % id)
	# Standing at the foot, one click climbs it.
	LocationParty.move_to_cell(view, foot)
	LocationInteraction.click(view, foot)
	assert_true(_floor_of_leader(view) > start_floor, "%s: the party is up on the floor above" % id)
	assert_eq(view.grid.floor_index(top), _floor_of_leader(view), "%s: on the floor the ladder comes out on" % id)
	# Up there the same ladder takes them down again.
	var back := LocationInteraction.ladders_here(view).filter(func(l: Dictionary) -> bool: return l["there"] == foot)
	assert_eq(back.size(), 1, "%s: the ladder can be used from the top too" % id)
	assert_false(bool(back[0]["up"]), "%s: and from there it climbs down" % id)
	LocationInteraction.click(view, back[0]["here"])
	assert_eq(_floor_of_leader(view), start_floor, "%s: the party is back on the ground floor" % id)
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_the_ladder_on_a_train_car_is_used_by_clicking_it() -> void:
	await _check_ladder(CAR)


func test_the_hay_loft_ladder_is_used_by_clicking_it() -> void:
	await _check_ladder(LOFT)


func test_clicking_a_ladder_from_across_the_car_walks_to_it_and_climbs() -> void:
	var view := _view(CAR)
	await _frames(3)
	var ladders := LocationInteraction.ladders_here(view)
	var foot: Vector2i = ladders[0]["here"]
	# Away from the foot but past the car's talkers, whose approach would stop a longer walk (that is the game, not the ladder).
	LocationParty.move_to_cell(view, foot + Vector2i(-5, 0))
	assert_true(view.leader().cell != foot, "the party starts away from the ladder")
	var start_floor := _floor_of_leader(view)
	LocationInteraction.click(view, foot)
	for i in 3000:   # the party walks a square a step-time: frames, as the hillside walk test waits
		await get_tree().process_frame
		if _floor_of_leader(view) > start_floor:
			break
	assert_true(_floor_of_leader(view) > start_floor, "the party walked to the ladder and went up it")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_a_ladder_is_never_walked_onto_or_across() -> void:
	var view := _view(CAR)
	await _frames(3)
	var ladders := LocationInteraction.ladders_here(view)
	var foot: Vector2i = ladders[0]["here"]
	var top: Vector2i = ladders[0]["there"]
	LocationParty.move_to_cell(view, foot + Vector2i(-2, 0))
	var start_floor := _floor_of_leader(view)
	assert_false(view.walk_to(top), "no walk reaches the roof: a ladder is no step in a path")
	assert_eq(_floor_of_leader(view), start_floor, "the party stays on the floor it was on")
	# Walking onto the foot itself does not climb it either.
	assert_true(view.walk_to(foot), "the foot of the ladder is an ordinary square to walk to")
	for i in 600:
		await get_tree().process_frame
		if view.leader().cell == foot:
			break
	await _frames(10)
	assert_eq(_floor_of_leader(view), start_floor, "and standing at the foot of a ladder is not climbing it")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()
