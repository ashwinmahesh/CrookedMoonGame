extends TestCase
## R11, Wickermoor Village: the town and its rooms hang together. Every door has a way back, every person can be walked to from where the
## party arrives, the arrival fight's foes stand on open ground and apart, the estate road waits for the mayor's welcome, and the game
## starts the town and a room.

const GAME := preload("res://world/game_root.gd")
const TOWN := "wickermoor_village"

var root: Node


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _rooms() -> Array[String]:
	var out: Array[String] = []
	for loc: Dictionary in Compendium.shared().all("locations"):
		var id := str(loc["id"])
		if id.begins_with("wickermoor_") and id != TOWN:
			out.append(id)
	return out


func _open(rows: Array, x: int, y: int) -> bool:
	return y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length() and ".~1234_=".contains((rows[y] as String)[x])


func _reach(rows: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				var n := Vector2i(c.x + dx, c.y + dy)
				if not seen.has(n) and _open(rows, n.x, n.y):
					seen[n] = true
					todo.append(n)
	return seen


func _beside(reach: Dictionary, a: Array) -> bool:
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if reach.has(Vector2i(int(a[0]) + dx, int(a[1]) + dy)):
				return true
	return false


func test_the_town_and_its_rooms_exist() -> void:
	assert_true(not _loc(TOWN).is_empty())
	var rooms := _rooms()
	assert_true(rooms.size() >= 19, "nineteen rooms or more (found %d)" % rooms.size())
	var map := _loc(TOWN)["map"] as Dictionary
	assert_eq((map["rows"] as Array).size(), 50)
	assert_eq(((map["rows"] as Array)[0] as String).length(), 60)
	assert_true(bool(map.get("outdoors", false)))


func test_every_door_has_a_way_back() -> void:
	var town := _loc(TOWN)
	for e: Dictionary in town["exits"]:
		var to := str(e["to"])
		if to == "travel":
			continue
		var back := false
		for x: Dictionary in _loc(to).get("exits", []):
			back = back or str(x["to"]) == TOWN
		assert_true(back, "%s leads back to the village" % to)
	for id: String in _rooms():
		for e: Dictionary in _loc(id).get("exits", []):
			var dest := _loc(str(e["to"]))
			assert_true(not dest.is_empty(), "%s: %s leads somewhere" % [id, e["id"]])
			assert_true((dest["spawns"] as Dictionary).has(str(e.get("spawn", "default"))), "%s: %s's arrival square exists" % [id, e["id"]])


func test_people_can_be_walked_to_from_the_arrival() -> void:
	var all: Array[String] = [TOWN]
	all.append_array(_rooms())
	for id: String in all:
		var loc := _loc(id)
		var reach := _reach((loc["map"] as Dictionary)["rows"] as Array, Vector2i(int((loc["spawns"]["default"] as Array)[0]), int((loc["spawns"]["default"] as Array)[1])))
		for n: Dictionary in loc.get("npcs", []):
			assert_true(_beside(reach, n["cell"] as Array), "%s: %s can be reached" % [id, n["npc"]])
		for e: Dictionary in loc.get("exits", []):
			assert_true(_beside(reach, e["cell"] as Array), "%s: the exit %s can be reached" % [id, e["id"]])


func test_the_arrival_fight_stands_on_open_ground_and_apart() -> void:
	var rows := (_loc(TOWN)["map"] as Dictionary)["rows"] as Array
	var enc: Dictionary = {}
	for e: Dictionary in _loc(TOWN)["encounters"]:
		if e["id"] == "wm_first_sacrifice":
			enc = e
	var cells: Array[Vector2i] = []
	for m: Dictionary in enc["monsters"]:
		var c := Vector2i(int((m["cell"] as Array)[0]), int((m["cell"] as Array)[1]))
		assert_true(_open(rows, c.x, c.y) and (rows[c.y] as String)[c.x] != "=", "%s stands on open ground" % m["name"])
		assert_true(not cells.has(c), "no two foes share a square")
		cells.append(c)
	assert_eq(cells.size(), 7, "six wolves and the pack leader")


func test_the_estate_road_waits_for_the_welcome() -> void:
	var road := {}
	for e: Dictionary in _loc(TOWN)["exits"]:
		if e["id"] == "road_to_estate":
			road = e
	assert_eq(str(road["when"]), "flag.wm_welcomed")


func test_the_town_and_a_room_start_in_the_game() -> void:
	for id: String in [TOWN, "wickermoor_green_queen_inn"]:
		GameState.reset()
		var st := GameState.story
		for pid: String in GAME.PLACEHOLDER_PARTY:
			var ch := Pregens.build(pid, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		st.location = id
		Dice.reseed(7)
		root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(root)
		for i in 15:
			await get_tree().process_frame
		var view := root.get("view") as LocationView
		assert_true(view != null and view.loc_id == id, "the game starts at %s" % id)
		root.queue_free()
		await get_tree().process_frame
	GameState.reset()
