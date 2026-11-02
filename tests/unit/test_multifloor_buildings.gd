extends TestCase
## The buildings with a cellar or an upper floor are one place each, as the Crooked House is (tools/content/merge_floors.py, the
## location's map.floors and map.stairs): each floor stands over the one below, its stairs join them, each floor keeps the id of
## the place it was (the ground floor's is the place's own, so the exits, flags, quests and music that name it still do), the
## old places are gone, a save made on one of them is mended into the building (SaveSystem.mend_merged_places), and the floors
## over the party are out of sight. The bell tower is a place of its own (the book gives it its own map), two floors.

## place id -> its floors from the lowest up (the cellar at 0 ft, the ground floor over it) and the ground floor's index.
const BUILDINGS := {
	"fw_windmill": {"floors": ["fw_windmill_cellar", "fw_windmill"], "ground": 1, "lowest_spawn": "cellar_default"},
	"wickermoor_green_queen_inn": {"floors": ["wickermoor_inn_cellar", "wickermoor_green_queen_inn", "wickermoor_green_queen_inn_upper"],
		"ground": 1, "lowest_spawn": "cellar_default"},
	"dg_briar": {"floors": ["dg_briar_cellar", "dg_briar", "dg_briar_upper"], "ground": 1, "lowest_spawn": "cellar_default"},
	"wickermoor_barber_shop": {"floors": ["wickermoor_barber_cellar", "wickermoor_barber_shop"], "ground": 1, "lowest_spawn": "cellar_default"},
	"wickermoor_funeral_home": {"floors": ["wickermoor_funeral_basement", "wickermoor_funeral_home"], "ground": 1,
		"lowest_spawn": "basement_default"},
	"wickermoor_trading_post": {"floors": ["wickermoor_trading_cellar", "wickermoor_trading_post"], "ground": 1, "lowest_spawn": "cellar_default"},
	"mon_ground": {"floors": ["mon_ground", "mon_upper"], "ground": 0, "lowest_spawn": "default"},
	"mon_bell_tower": {"floors": ["mon_bell_tower", "mon_belfry"], "ground": 0, "lowest_spawn": "default"},
	"wickermoor_mayors_house": {"floors": ["wickermoor_mayors_house", "wickermoor_clock_chamber"], "ground": 0, "lowest_spawn": "default"},
}
## How many stair links each has (the monastery's two spiral stairs both meet: the west one's two landings were 23 squares apart).
const STAIRS := {"fw_windmill": 1, "wickermoor_green_queen_inn": 2, "dg_briar": 2, "wickermoor_barber_shop": 1, "wickermoor_funeral_home": 1,
	"wickermoor_trading_post": 1, "mon_ground": 2, "mon_bell_tower": 1,
	"wickermoor_mayors_house": 1}


func _place(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


## The building's floors that were places of their own (a deck or storey laid since, tools/content/add_decks.py, says its kind).
func _floors(id: String) -> Array:
	return ((_place(id)["map"] as Dictionary)["floors"] as Array).filter(func(f: Variant) -> bool: return not (f as Dictionary).has("kind"))


func _check_one_place(id: String) -> void:
	var spec := BUILDINGS[id] as Dictionary
	var want := spec["floors"] as Array
	var floors := _floors(id)
	assert_eq(floors.size(), want.size(), "%s has its floors in it" % id)
	for i in floors.size():
		var fl := floors[i] as Dictionary
		assert_eq(str(fl["id"]), str(want[i]), "%s's floor %d keeps the id of the place it was" % [id, i])
		assert_eq(int(fl["height_ft"]), 15 * i, "%s stands a storey over the one below" % fl["id"])
		assert_true(fl.has("offset"), "%s says where its squares moved (a save made there is mended)" % fl["id"])
	assert_eq(str(want[int(spec["ground"])]), id, "the ground floor's id is the place's own")
	if int(spec["ground"]) > 0:
		assert_true((_place(id)["spawns"] as Dictionary).has(str(spec["lowest_spawn"])), "%s has a way down to its lowest floor" % id)
	var map := _place(id)["map"] as Dictionary
	var stairs := (map["stairs"] as Array).filter(func(st: Variant) -> bool: return not (st as Dictionary).has("kind"))
	assert_eq(stairs.size(), int(STAIRS[id]), "%s: its stairs" % id)
	var g := LocationView.grid_for(_place(id))
	for s: Variant in stairs:
		var a := LocationView._cell((s as Dictionary)["from"])
		var b := LocationView._cell((s as Dictionary)["to"])
		assert_eq(g.floor_index(b), g.floor_index(a) + 1, "%s climbs one floor" % [s])
		var wa := g.world_center(a)
		var wb := g.world_center(b)
		assert_true(Vector2(wa.x, wa.z).distance_to(Vector2(wb.x, wb.z)) <= 3.0, "%s comes out over where it starts" % [s])
		assert_false(g.is_solid(a) or g.is_solid(b), "%s joins two squares to stand on" % [s])
	for e: Variant in _place(id)["exits"]:
		var ex := e as Dictionary
		if str(ex["to"]) == id:
			assert_true((_place(id)["spawns"] as Dictionary).has(str(ex.get("spawn", "default"))), "%s: a way within the place sets the party down" % ex["id"])
	for old: Variant in want:
		if str(old) != id:
			assert_false(Compendium.shared().has("locations", str(old)), "%s is no longer a place of its own" % old)


func test_the_windmill_and_its_cellar_are_one_place() -> void:
	_check_one_place("fw_windmill")


func test_the_green_queen_is_one_place_with_a_cellar_and_an_upper_floor() -> void:
	_check_one_place("wickermoor_green_queen_inn")


func test_the_briar_is_one_place_with_a_cellar_and_an_upper_floor() -> void:
	_check_one_place("dg_briar")


func test_the_barber_shop_and_its_cellar_are_one_place() -> void:
	_check_one_place("wickermoor_barber_shop")


func test_the_funeral_home_and_its_basement_are_one_place() -> void:
	_check_one_place("wickermoor_funeral_home")


func test_the_trading_post_and_its_cellar_are_one_place() -> void:
	_check_one_place("wickermoor_trading_post")


func test_the_monastery_is_one_place_with_its_upper_floor() -> void:
	_check_one_place("mon_ground")


func test_the_bell_tower_is_one_place_with_its_belfry() -> void:
	_check_one_place("mon_bell_tower")


func test_the_mayors_house_is_one_place_with_its_clock_chamber() -> void:
	_check_one_place("wickermoor_mayors_house")


## No sunken room shows beside a building: every square of a cellar has a square of the ground floor over it (the old maps' stairs put
## some cellars partly outside the house, so the ground floor is walled out over them, tools/content/merge_floors.py `cover`).
func test_every_cellar_lies_under_the_ground_floors_walls() -> void:
	for id: String in BUILDINGS:
		var ground := int((BUILDINGS[id] as Dictionary)["ground"])
		if ground == 0:
			continue
		var map := _place(id)["map"] as Dictionary
		var rows := map["rows"] as Array
		var floors := map["floors"] as Array
		var low := floors[0] as Dictionary
		var top := floors[ground] as Dictionary
		var outside := 0
		for r: Variant in rows:
			var row := str(r)
			for x in range(int(low["x0"]), mini(int(low["x0"]) + int(low["width"]), row.length())):
				if row[x] == " ":
					continue
				var over := int(top["x0"]) + (x - int(low["x0"]))
				if over >= row.length() or row[over] == " ":
					outside += 1
		assert_eq(outside, 0, "%s: the cellar's squares with no ground floor over them" % id)


## The monastery's west stair is a real stair like the east one: its ground landing moved ten squares down its corridor and the
## upper floor's two squares (the landing and the way back down) to the hall's north edge over it; nothing else was moved.
func test_the_monasterys_west_stair_meets_like_the_east_one() -> void:
	var mon := _place("mon_ground")
	var g := LocationView.grid_for(mon)
	var spawns := mon["spawns"] as Dictionary
	var floors := _floors("mon_ground")
	var ground := floors[0]["offset"] as Array
	var upper := floors[1]["offset"] as Array
	assert_eq(LocationView._cell(spawns["from_upstairs_a"]), Vector2i(19 + int(ground[0]), 22 + int(ground[1])), "the way down arrives at the stair's new foot")
	assert_eq(LocationView._cell(spawns["upper_from_down_a"]), Vector2i(22 + int(upper[0]), 29 + int(upper[1])), "and the way up at its new landing")
	var seen := 0
	for s: Variant in (mon["map"] as Dictionary)["stairs"]:
		var a := LocationView._cell((s as Dictionary)["from"])
		var b := LocationView._cell((s as Dictionary)["to"])
		var wa := g.world_center(a)
		var wb := g.world_center(b)
		assert_eq(Vector2(wa.x, wa.z), Vector2(wb.x, wb.z), "%s comes out exactly over where it starts" % [s])
		seen += 1
	assert_eq(seen, 2, "both stairs")
	for e: Variant in mon["exits"]:
		var ex := e as Dictionary
		if str(ex["id"]) == "stairs_up_a":
			assert_eq(LocationView._cell(ex["cell"]), LocationView._cell(spawns["from_upstairs_a"]), "the exit stands on the foot of the stair")
			assert_eq(str(ex["spawn"]), "upper_from_down_a", "and still leads up to its landing")
		if str(ex["id"]) == "down_a":
			assert_eq(LocationView._cell(ex["cell"]), Vector2i(22 + int(upper[0]), 30 + int(upper[1])), "the way back down is beside the landing")
			assert_eq(str(ex["spawn"]), "from_upstairs_a", "and leads to the foot")


func test_the_cellar_stair_waits_for_what_opened_it() -> void:
	for pair: Array in [["fw_windmill", "flag.fw_mill_done"], ["wickermoor_barber_shop", "flag.barber_cellar_found"], ["mon_ground", "not jailed"]]:
		var stair: Dictionary = (((_place(str(pair[0])))["map"] as Dictionary)["stairs"] as Array)[0]
		assert_eq(str(stair.get("when", "")), str(pair[1]), "%s's stair opens on its condition" % pair[0])
	var barber := ((_place("wickermoor_barber_shop")["map"] as Dictionary)["stairs"] as Array)[0] as Dictionary
	assert_eq(str(barber.get("locked_text", "")), "There is only a wall there.", "and says what is there until then")


func test_a_door_out_of_a_building_is_still_a_change_of_place() -> void:
	for id: String in BUILDINGS:
		var outside := 0
		for e: Variant in _place(id)["exits"]:
			if str((e as Dictionary)["to"]) != id:
				outside += 1
		assert_true(outside > 0, "%s still opens onto somewhere else" % id)
	var door_to_inn := false
	for e: Variant in _place("wickermoor_village")["exits"]:
		if str((e as Dictionary)["to"]) == "wickermoor_green_queen_inn":
			door_to_inn = true
	assert_true(door_to_inn, "the village's door to the inn leads to the inn's own id as it always did")


# --- Saves ------------------------------------------------------------------------------------------------------------

func _mend(location: String, at: Array, extra: Dictionary = {}) -> Dictionary:
	var story := {"location": location, "positions": [at.duplicate(), [float(at[0]) + 1.0, float(at[1])]], "visited": {location: true}, "location_states": {}}
	story.merge(extra, true)
	return SaveSystem.upgrade({"version": GameState.SAVE_VERSION, "story": story})["story"] as Dictionary


## A save made on any old floor is in the building at the squares the floor's own squares moved to.
func test_a_save_made_on_an_old_floor_is_mended_into_its_building() -> void:
	for id: String in BUILDINGS:
		for fl: Variant in _floors(id):
			var f := fl as Dictionary
			var st := _mend(str(f["id"]), [3, 4])
			var off := f["offset"] as Array
			assert_eq(str(st["location"]), id, "a save in %s is in %s" % [f["id"], id])
			assert_eq(st["positions"][0], [3.0 + float(off[0]), 4.0 + float(off[1])], "%s: where it stood, on that floor" % f["id"])
			assert_true(bool((st["visited"] as Dictionary).get(id, false)), "%s: the building is visited" % f["id"])
			assert_true(bool((st["visited"] as Dictionary).get(str(f["id"]), false)), "%s: and the floor still is" % f["id"])


## The ground floor kept the building's id, so a save made after the merge (it names the place in `merged_places`) is not moved
## again, and mending a mended save changes nothing.
func test_a_save_made_since_the_merge_is_left_where_it_stands() -> void:
	for id: String in BUILDINGS:
		var ground := ((_floors(id))[int((BUILDINGS[id] as Dictionary)["ground"])]) as Dictionary
		var old := _mend(id, [3, 4])
		var off := ground["offset"] as Array
		assert_eq(old["positions"][0], [3.0 + float(off[0]), 4.0 + float(off[1])], "%s: an older save's party moves by the floor's offset" % id)
		assert_true((old["merged_places"] as Array).has(id), "%s: a mended save says it is in the building's squares" % id)
		var again := SaveSystem.upgrade({"version": GameState.SAVE_VERSION, "story": old})["story"] as Dictionary
		assert_eq(again["positions"], old["positions"], "%s: mending it twice moves nothing" % id)
		var fresh := _mend(id, [3, 4], {"merged_places": MergedPlaces.ids()})
		assert_eq(fresh["positions"][0], [3, 4], "%s: a save the building's own build wrote is left alone" % id)


func test_every_save_names_the_buildings_it_holds() -> void:
	var names := MergedPlaces.ids()
	for id: String in BUILDINGS:
		assert_true(names.has(id), "%s is named in a save" % id)
	assert_true(names.has("crooked_house"), "so is the Crooked House")
	GameState.reset()
	assert_eq((GameState.to_dict()["story"] as Dictionary)["merged_places"], names, "a save the game writes carries them")


func test_what_an_old_floor_remembered_is_the_buildings_now() -> void:
	var st := _mend("wickermoor_inn_cellar", [8, 12], {"location_states": {
		"wickermoor_inn_cellar": {"found": {"inn_cask": true}}, "wickermoor_green_queen_inn": {"looted": {"inn_bar": true}}}})
	var states := st["location_states"] as Dictionary
	assert_false(states.has("wickermoor_inn_cellar"), "the cellar's memory is the inn's")
	assert_true(bool(((states["wickermoor_green_queen_inn"] as Dictionary)["found"] as Dictionary).get("inn_cask", false)), "what was found stays found")
	assert_true(bool(((states["wickermoor_green_queen_inn"] as Dictionary)["looted"] as Dictionary).get("inn_bar", false)), "and what was looted, looted")
	var ground := _mend("wickermoor_green_queen_inn", [14, 19], {"location_states": {"wickermoor_green_queen_inn": {"looted": {"inn_bar": true}}}})
	assert_true(((ground["location_states"] as Dictionary).has("wickermoor_green_queen_inn")), "the ground floor's own memory is never mended away")


# --- The floors over the party ------------------------------------------------------------------------------------------

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


## Pieces of the board standing at least `from` (world units) over the ground and under `to`.
func _pieces(view: LocationView, from: float, to: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in view.board.get_children():
		var y := (n as Node3D).global_position.y if n is Node3D else -1.0
		if y >= from and y < to:
			out.append(n as Node3D)
	return out


## How many things drawn over the floor the party stands on (from `height`, world units) are still in sight: every mesh and light
## in the place, props and furnishings too, which stand in nodes at ground level and hold their parts where they stand. (The exits'
## own stair pieces are left out: LocationBuilder.refresh_exits shows them again whatever the cutaway did, and the stairs are drawn
## another way soon.)
func _in_sight_over(view: LocationView, height: float) -> int:
	var n := 0
	for node in view.find_children("*", "Node3D", true, false):
		var nn := node as Node3D
		if not (nn is MeshInstance3D or nn is MultiMeshInstance3D or nn is OmniLight3D or nn is SpotLight3D):
			continue
		if nn.global_position.y >= height and nn.is_visible_in_tree() and not _under(nn, "Exit_"):
			n += 1
	return n


## Whether `n` is under the camera rig, or under a node whose name starts with `prefix` (when it is not "").
func _under(n: Node, prefix: String) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is CameraRig or (prefix != "" and str(p.name).begins_with(prefix)):
			return true
		p = p.get_parent()
	return false


## The party comes in on the ground floor, the floors over it are out of sight; down in the cellar the ground floor is too, and it
## fades back in as the party climbs to it.
func _check_cutaway(id: String, climb_to: String) -> void:
	var view := _view(id)
	await _frames(4)
	var ground := int((BUILDINGS[id] as Dictionary)["ground"])
	var floors := _floors(id)
	if ground + 1 < floors.size():
		var above := _pieces(view, 3.0 * (ground + 1), 3.0 * (ground + 2))
		assert_true(not above.is_empty(), "%s: the floor over the ground floor has pieces" % id)
		assert_true(above.all(func(n: Node3D) -> bool: return not n.visible), "%s: the floor over the ground floor is out of sight" % id)
	var lowest := str((BUILDINGS[id] as Dictionary)["lowest_spawn"])
	if ground > 0:
		LocationParty.move_within(view, lowest)
		await get_tree().create_timer(FloorCutaway.CHECK_EVERY + FloorCutaway.FADE + 0.3).timeout   # (going down, the floor over fades out first)
		var over := _pieces(view, 3.0, 3.0 * floors.size() + 1.0)
		assert_true(not over.is_empty(), "%s: the ground floor has pieces over the cellar" % id)
		assert_true(over.all(func(n: Node3D) -> bool: return not n.visible), "%s: and they are out of sight from the cellar" % id)
		assert_eq(_in_sight_over(view, 2.9), 0, "%s: nothing of the floors over the cellar is in sight, its props and furnishings too" % id)
		LocationParty.move_within(view, climb_to)
		await get_tree().create_timer(FloorCutaway.CHECK_EVERY + 0.1).timeout
		await get_tree().create_timer(FloorCutaway.FADE + 0.3).timeout
		assert_true(_pieces(view, 3.0, 3.0 + FloorCutaway.ABOVE).all(func(n: Node3D) -> bool: return n.visible), "%s: the ground floor is in sight once the party climbs to it" % id)
		assert_true(bool(GameState.story.visited.get(str(floors[0]["id"]), false)), "%s: the cellar is visited" % id)
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_the_floors_over_the_party_are_cut_away_in_the_windmill() -> void:
	await _check_cutaway("fw_windmill", "from_cellar_stair")


func test_the_floors_over_the_party_are_cut_away_in_the_green_queen() -> void:
	await _check_cutaway("wickermoor_green_queen_inn", "from_cellar")


func test_the_floors_over_the_party_are_cut_away_in_the_briar() -> void:
	await _check_cutaway("dg_briar", "from_cellar")


func test_the_floors_over_the_party_are_cut_away_in_the_barber_shop() -> void:
	await _check_cutaway("wickermoor_barber_shop", "from_cellar")


func test_the_floors_over_the_party_are_cut_away_in_the_funeral_home() -> void:
	await _check_cutaway("wickermoor_funeral_home", "from_basement")


func test_the_floors_over_the_party_are_cut_away_in_the_trading_post() -> void:
	await _check_cutaway("wickermoor_trading_post", "from_cellar")


func test_the_upper_floor_of_the_monastery_is_out_of_sight_from_the_ground_floor() -> void:
	await _check_cutaway("mon_ground", "default")
	var view := _view("mon_ground")
	await _frames(4)
	var upper := _pieces(view, 3.0, 6.0)
	assert_true(upper.all(func(n: Node3D) -> bool: return not n.visible), "the monastery's upper floor is out of sight")
	assert_eq(_in_sight_over(view, 2.9), 0, "with its props and furnishings")
	LocationParty.move_within(view, "upper_from_down_b")
	await get_tree().create_timer(FloorCutaway.CHECK_EVERY + 0.1).timeout
	assert_true(upper.all(func(n: Node3D) -> bool: return n.visible), "and comes into sight as the party climbs to it")
	assert_true(bool(GameState.story.visited.get("mon_upper", false)), "the upper floor is visited")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_the_belfry_is_out_of_sight_from_the_bell_tower() -> void:
	await _check_cutaway("mon_bell_tower", "default")
	var view := _view("mon_bell_tower")
	await _frames(4)
	var belfry := _pieces(view, 3.0, 6.0)
	assert_true(not belfry.is_empty() and belfry.all(func(n: Node3D) -> bool: return not n.visible), "the belfry is out of sight from the tower")
	assert_eq(_in_sight_over(view, 2.9), 0, "with its props")
	LocationParty.move_within(view, "belfry_from_ladder")
	await get_tree().create_timer(FloorCutaway.CHECK_EVERY + 0.1).timeout
	assert_true(belfry.all(func(n: Node3D) -> bool: return n.visible), "and comes into sight as the party climbs up")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()
