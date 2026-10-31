extends TestCase
## R10, the Ghostlight Express: its ten places load and hang together. Data checks over all of them (every spawn, exit, person and
## search prop can be walked to from the arrival square, the doors chain car to car, the wreck's way out is the travel map), and
## the game really starts the hill, the first car and the wreck.

const GAME := preload("res://world/game_root.gd")
const PLACES := ["ghostlight_boarding", "ghostlight_g1_passenger", "ghostlight_g2_sleeper", "ghostlight_g3_lounge", "ghostlight_g4_dining",
	"ghostlight_g5_mail", "ghostlight_g6_baggage", "ghostlight_g7_circus", "ghostlight_g8_tender", "ghostlight_wreckage"]
const CARS := ["ghostlight_g1_passenger", "ghostlight_g2_sleeper", "ghostlight_g3_lounge", "ghostlight_g4_dining",
	"ghostlight_g5_mail", "ghostlight_g6_baggage", "ghostlight_g7_circus", "ghostlight_g8_tender"]

var root: Node


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _walkable(rows: Array, x: int, y: int) -> bool:
	return y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length() and ".~1234_=".contains((rows[y] as String)[x])


## Squares reachable from `start` in 8 directions over open floor (low cover counts: it is walked round or over).
func _reach(rows: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				var n := Vector2i(c.x + dx, c.y + dy)
				if not seen.has(n) and _walkable(rows, n.x, n.y):
					seen[n] = true
					todo.append(n)
	return seen


func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func test_every_place_exists_and_has_a_default_spawn() -> void:
	for id: String in PLACES:
		var loc := _loc(id)
		assert_true(not loc.is_empty(), "%s is data" % id)
		assert_eq(str(loc.get("region")), "ghostlight_express")
		assert_true((loc.get("spawns", {}) as Dictionary).has("default"), "%s has a default spawn" % id)


func test_people_exits_and_finds_can_be_walked_to_from_the_arrival() -> void:
	for id: String in PLACES:
		var loc := _loc(id)
		var rows := (loc["map"] as Dictionary)["rows"] as Array
		var reach := _reach(rows, _cell((loc["spawns"] as Dictionary)["default"] as Array))
		for n: Dictionary in loc.get("npcs", []):
			if bool(n.get("asleep", false)) or bool(n.get("lying", false)):
				continue
			var c := _cell(n["cell"] as Array)
			var near := false
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					near = near or reach.has(Vector2i(c.x + dx, c.y + dy))
			assert_true(near, "%s: %s can be reached" % [id, n["npc"]])
		for p: Dictionary in loc.get("props", []):
			if str(p.get("kind")) == "search":
				var c := _cell(p["cell"] as Array)
				var near := false
				for dx: int in [-1, 0, 1]:
					for dy: int in [-1, 0, 1]:
						near = near or reach.has(Vector2i(c.x + dx, c.y + dy))
				assert_true(near, "%s: the search prop %s can be reached" % [id, p["id"]])


func test_the_cars_chain_front_to_back_in_an_order_the_seed_fixes() -> void:
	var module := Campaign.module() as CrookedMoonCampaign
	var st := GameState.story
	var seen := {}
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var chain := CrookedMoonCampaign.switcheroo_chain(seed_value)
		assert_eq(chain.size(), 8)
		assert_eq(chain[0], CARS[0], "the Passenger Car is always the rear")
		assert_eq(chain[7], CARS[7], "the Tender is always last")
		assert_eq(chain, CrookedMoonCampaign.switcheroo_chain(seed_value), "the same seed gives the same order")
		var sorted_middle := chain.slice(1, 7)
		sorted_middle.sort()
		var want := CARS.slice(1, 7)
		want.sort()
		assert_eq(sorted_middle, want, "every middle car appears once")
		seen[str(chain)] = true
		st.playthrough_seed = seed_value
		for i in chain.size() - 1:
			assert_eq(module.exit_target(st, chain[i], "module_switcheroo_next"), chain[i + 1])
			assert_eq(module.exit_target(st, chain[i + 1], "module_switcheroo_previous"), chain[i])
	assert_true(seen.size() > 1, "different playthroughs shuffle the cars differently")
	for id: String in CARS:
		for e: Dictionary in _loc(id).get("exits", []):
			assert_true(str(e["to"]).begins_with("module_switcheroo_"), "%s's doors are the module's" % id)


func test_the_tenders_door_waits_for_all_six_haints() -> void:
	var door: Dictionary = {}
	for e: Dictionary in _loc("ghostlight_g7_circus").get("exits", []):
		if e["id"] == "front_door":
			door = e
	var when := str(door.get("when", ""))
	for h: String in ["sweetheart", "songstress", "daydreamer", "mariner", "jailbird", "harlequin"]:
		assert_true(when.contains("haint_%s_done" % h) and when.contains("haint_%s_destroyed" % h), "the door waits on the %s" % h)


func test_the_wreck_leads_out_to_the_travel_map_and_the_hill_to_the_train() -> void:
	var out := (_loc("ghostlight_wreckage")["exits"] as Array)[0] as Dictionary
	assert_eq(str(out["to"]), "travel")
	var board := (_loc("ghostlight_boarding")["exits"] as Array)[0] as Dictionary
	assert_eq(str(board["to"]), "ghostlight_g1_passenger")


func test_each_place_starts_in_the_game() -> void:
	for id: String in ["ghostlight_boarding", "ghostlight_g1_passenger", "ghostlight_wreckage"]:
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
		for i in 12:
			await get_tree().process_frame
		var view := root.get("view") as LocationView
		assert_true(view != null and view.loc_id == id, "the game starts at %s" % id)
		root.queue_free()
		await get_tree().process_frame
	GameState.reset()
