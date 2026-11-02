extends TestCase
## The Crooked House is one place with its four floors in it (data/locations/crooked_house.json, map.floors; tools/content/
## merge_floors.py): each floor stands over the one below, its stairs join them, each floor keeps the id of the place it was,
## and a save made on one of those old places is mended into the house (SaveSystem.mend_merged_places).


func _house() -> Dictionary:
	return Compendium.shared().get_entry("locations", "crooked_house")


func test_the_four_floors_stand_over_each_other_joined_by_their_stairs() -> void:
	var map := _house()["map"] as Dictionary
	var floors := map["floors"] as Array
	assert_eq(floors.size(), 4, "first, second, third and the attic")
	var ids: Array[String] = []
	for i in floors.size():
		var fl := floors[i] as Dictionary
		ids.append(str(fl["id"]))
		assert_eq(int(fl["height_ft"]), 15 * i, "%s stands a storey over the one below" % fl["id"])
	assert_eq(ids, HouseFloors.FLOORS, "each floor keeps the id of the place it was")
	assert_eq((map["stairs"] as Array).size(), 3, "a stair between each floor and the next")
	var g := LocationView.grid_for(_house())
	for s: Variant in map["stairs"]:
		var a := LocationView._cell((s as Dictionary)["from"])
		var b := LocationView._cell((s as Dictionary)["to"])
		assert_eq(g.floor_index(b), g.floor_index(a) + 1, "%s climbs one floor" % [s])
		var wa := g.world_center(a)
		var wb := g.world_center(b)
		assert_true(Vector2(wa.x, wa.z).distance_to(Vector2(wb.x, wb.z)) <= 3.0, "%s comes out over where it starts" % [s])
	for old: String in HouseFloors.FLOORS:
		assert_false(Compendium.shared().has("locations", old), "%s is no longer a place of its own" % old)


func test_the_attic_hatch_waits_for_the_trapdoor_in_the_rules_too() -> void:
	var hatch: Dictionary = {}
	for s: Variant in (_house()["map"] as Dictionary)["stairs"]:
		if (s as Dictionary).has("when"):
			hatch = s as Dictionary
	assert_true(str(hatch.get("when", "")).contains("trapdoor_known"), "the stair to the attic opens once the trapdoor is known")


func test_a_save_made_on_an_old_floor_is_mended_into_the_house() -> void:
	var save := {"version": GameState.SAVE_VERSION, "story": {"location": "crooked_house_second", "positions": [[16, 24], [17, 24]],
		"visited": {"crooked_house_first": true, "crooked_house_second": true},
		"location_states": {"crooked_house_second": {"found": {"h10_closet": true}}, "crooked_house_first": {"looted": {"h4_box": true}}}}}
	var out := SaveSystem.upgrade(save)
	var st := out["story"] as Dictionary
	assert_eq(str(st["location"]), "crooked_house", "the party is in the house")
	assert_eq(st["positions"][0], [51.0, 24.0], "where it stood, on the second floor")
	var states := st["location_states"] as Dictionary
	assert_false(states.has("crooked_house_second"), "the old place's memory is the house's now")
	assert_true(bool(((states["crooked_house"] as Dictionary)["found"] as Dictionary).get("h10_closet", false)), "what was found stays found")
	assert_true(bool(((states["crooked_house"] as Dictionary)["looted"] as Dictionary).get("h4_box", false)), "and what was looted, looted")
	assert_true(bool((st["visited"] as Dictionary).get("crooked_house_second", false)), "the floor is still visited (the séance asks)")
	assert_true(bool((st["visited"] as Dictionary).get("crooked_house", false)), "and so is the house")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The floors over the party are out of sight; the party's own floor is solid; the floor it climbs to fades in on the way.
func test_the_floors_over_the_party_are_cut_away_and_fade_in_on_the_stairs() -> void:
	GameState.reset()
	var st := GameState.story
	for pid: String in preload("res://world/game_root.gd").PLACEHOLDER_PARTY:
		st.party.append(Pregens.build(pid, 3))
	st.location = "crooked_house"
	var view := LocationView.create("crooked_house", st, Narrator.new(), Dice.roller, "default")
	add_child(view)
	await _frames(4)
	var upstairs: Array[Node3D] = []
	for n in view.board.get_children():
		var y := (n as Node3D).global_position.y if n is Node3D else -1.0
		if y >= FloorCutaway.ABOVE and y < 3.0 + FloorCutaway.ABOVE:   # (the second floor's: over the first's cut, under the third's)
			upstairs.append(n as Node3D)
	assert_true(not upstairs.is_empty(), "the second floor has pieces")
	assert_true(upstairs.all(func(n: Node3D) -> bool: return not n.visible), "and they are out of sight from the first floor")
	LocationParty.move_within(view, "second_default")
	await get_tree().create_timer(FloorCutaway.CHECK_EVERY + 0.1).timeout
	var meshes: Array = []
	for n in upstairs:
		meshes.append_array(n.find_children("*", "GeometryInstance3D", true, false))
	assert_true(upstairs.all(func(n: Node3D) -> bool: return n.visible), "climbing, the second floor comes into sight")
	await get_tree().create_timer(FloorCutaway.FADE * 0.5 + 0.1).timeout
	assert_true(meshes.any(func(m: Variant) -> bool: return (m as GeometryInstance3D).transparency > 0.2),
		"slightly see-through while the party climbs")
	await get_tree().create_timer(FloorCutaway.FADE + FloorCutaway.CLIMB_HOLD + 0.3).timeout
	assert_true(meshes.all(func(m: Variant) -> bool: return (m as GeometryInstance3D).transparency == 0.0),
		"and stands solid once the party is on it")
	assert_true(bool(st.visited.get("crooked_house_second", false)), "the second floor is visited")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()
