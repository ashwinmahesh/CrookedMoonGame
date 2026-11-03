extends TestCase
## Up on a ladder's floor, a click lands on that floor (Ashwin, 2026-11-03: "the floor is opaque and when trying to move it selects an
## area downstairs (on the train)"): the real mouse pick (the camera ray) at a square of the floor the party is on picks that square.

const CAR := "ghostlight_g3_lounge"


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


func test_a_click_on_the_roof_picks_the_roof_not_the_car_under_it() -> void:
	var view := _view(CAR)
	await _frames(3)
	var ladders := LocationInteraction.ladders_here(view)
	var foot: Vector2i = ladders[0]["here"]
	var top: Vector2i = ladders[0]["there"]
	LocationParty.move_to_cell(view, foot)
	LocationInteraction.click(view, foot)
	await get_tree().create_timer(0.8).timeout   # the camera and the cutaway follow the climb
	await _frames(5)
	var up := view.grid.floor_index(view.leader().cell)
	assert_true(up > 0, "the party is up on the roof")
	var cam := view.rig.camera
	var tested := 0
	for dx in range(-3, 4):
		var c := view.leader().cell + Vector2i(dx, 0)
		if not view.grid.in_bounds(c) or view.grid.floor_index(c) != up or view.grid.is_solid(c):
			continue
		var screen := cam.unproject_position(view.board.cell_center(c))
		var picked := view.pick_cell(cam, screen)
		tested += 1
		assert_eq(view.grid.floor_index(picked), up, "a click on roof square %s picks a roof square (got %s)" % [c, picked])
	assert_true(tested >= 3, "enough roof squares were tried (%d)" % tested)
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()
