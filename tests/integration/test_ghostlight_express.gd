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


const HAINTS := ["sweetheart", "songstress", "daydreamer", "mariner", "jailbird", "harlequin"]


func _front_door(car: String) -> Dictionary:
	for e: Dictionary in _loc(car).get("exits", []):
		if e["id"] == "front_door":
			return e
	return {}


## A seed whose Switcheroo puts `car` last of the six middle cars (just before the Tender).
func _seed_with_last_car(car: String) -> int:
	for candidate: int in 100000:
		var chain := CrookedMoonCampaign.switcheroo_chain(candidate)
		if chain[chain.size() - 2] == car:
			return candidate
	return -1


func _front_door_open(car: String, st: StoryState) -> bool:
	return StoryConditions.check(str(_front_door(car).get("when", "")), st)


## The Tender's door is the front door of whichever middle car the seed puts last: that door waits for all six haints (put down or
## helped), whichever car it is, and the other middle cars' doors never wait.
func test_the_tenders_door_waits_for_all_six_haints_whichever_car_is_last() -> void:
	GameState.reset()
	var st := GameState.story
	for last: String in CARS.slice(1, 7):
		st.playthrough_seed = _seed_with_last_car(last)
		assert_true(st.playthrough_seed >= 0, "some seed puts %s last" % last)
		for car: String in CARS.slice(1, 7):
			var has_gate := car == last
			assert_eq(_front_door_open(car, st), not has_gate, "%s's front door %s with no haint gone" % [car, "waits" if has_gate else "is open"])
		for h: String in HAINTS:
			assert_true(not _front_door_open(last, st), "%s's door still waits with the %s unresolved" % [last, h])
			st.set_flag("haint_%s_done" % h if h != "harlequin" else "haint_harlequin_destroyed")
		assert_true(_front_door_open(last, st), "%s's door opens when all six are gone, helped or put down" % last)
		for h: String in HAINTS:
			st.set_flag("haint_%s_done" % h, false)
			st.set_flag("haint_%s_destroyed" % h, false)
	GameState.reset()


func test_the_first_car_keeps_the_party_for_the_phantom() -> void:
	GameState.reset()
	var st := GameState.story
	var door := _front_door("ghostlight_g1_passenger")
	assert_true(not StoryConditions.check(str(door.get("when", "")), st), "the Passenger Car's front door is shut until the Phantom is dealt with")
	assert_true(str(door.get("locked_text", "")) != "", "and says why")
	st.set_flag("gl_phantom_done")
	assert_true(StoryConditions.check(str(door.get("when", "")), st), "it opens after the fight")
	GameState.reset()


func test_the_iron_ring_stays_for_whoever_kills_the_wildpyre() -> void:
	GameState.reset()
	var st := GameState.story
	var loose: Dictionary = {}
	for p: Dictionary in _loc("ghostlight_g6_baggage").get("props", []):
		if p["id"] == "g6_iron_ring_loose":
			loose = p
	assert_true(not loose.is_empty(), "the ring lies loose once the tiger is gone")
	var when := str(loose.get("when", ""))
	assert_true(not StoryConditions.check(when, st), "not while it sleeps")
	st.set_flag("wildpyre_destroyed")
	assert_true(StoryConditions.check(when, st), "after it falls")
	st.set_flag("haint_harlequin_done")
	assert_true(not StoryConditions.check(when, st), "not once the Harlequin has had hers")
	GameState.reset()


func test_the_baggage_car_holds_the_books_loot() -> void:
	var cases: Dictionary = {}
	for c: Dictionary in _loc("ghostlight_g6_baggage").get("containers", []):
		if c["id"] == "g6_abandoned_cases":
			cases = c
	assert_true(not cases.is_empty(), "abandoned luggage holds a container")
	assert_eq(float(cases.get("gold", 0)), 7.5, "75 silver")
	var ids: Array[String] = []
	for it: Dictionary in cases.get("items", []):
		ids.append("%s x%d" % [it["id"], int(it["qty"])])
	assert_eq(ids, ["ruby_silver_ring x1", "travelers_clothes x10"] as Array[String])


func test_the_fabled_whistle_and_the_hooch_do_something() -> void:
	var whistle := Compendium.shared().get_entry("items", "whistle_of_the_vagrant")
	assert_true(not (whistle.get("modifiers", []) as Array).is_empty(), "the Whistle adds to saving throws")
	var hooch := Compendium.shared().get_entry("items", "haint_hooch")
	assert_true(not (hooch.get("effects", []) as Array).is_empty(), "the Hooch makes the drinker insubstantial")


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
