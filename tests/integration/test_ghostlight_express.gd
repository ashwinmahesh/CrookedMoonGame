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
			st.visited = {chain[i + 1]: true}   # a car already been in: its doors are plain
			assert_eq(module.exit_target(st, chain[i], "module_switcheroo_next"), chain[i + 1])
			assert_eq(module.exit_target(st, chain[i + 1], "module_switcheroo_previous"), chain[i])
		st.visited = {}
	assert_true(seen.size() > 1, "different playthroughs shuffle the cars differently")
	for id: String in CARS:
		for e: Dictionary in _loc(id).get("exits", []):
			assert_true(str(e["to"]).begins_with("module_switcheroo_"), "%s's doors are the module's" % id)


## The mist between cars (E23): the first forward crossing into a car not yet visited goes through it and on into that car; later
## crossings, and every way back, are plain doors. The query changes nothing (menus ask it for the door's label).
func test_a_first_crossing_goes_through_the_mist_and_later_ones_do_not() -> void:
	GameState.reset()
	var module := Campaign.module() as CrookedMoonCampaign
	var st := GameState.story
	var limbo := CrookedMoonCampaign.limbo_place()
	assert_eq(limbo, "ghostlight_limbo")
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		st.playthrough_seed = seed_value
		var chain := CrookedMoonCampaign.switcheroo_chain(seed_value)
		st.visited = {chain[0]: true}
		for i in chain.size() - 1:
			var before := st.visited.duplicate()
			assert_eq(module.exit_target(st, chain[i], "module_switcheroo_next"), limbo, "the first way into %s is the mist" % chain[i + 1])
			assert_eq(module.exit_target(st, chain[i], "module_switcheroo_next"), limbo, "asking twice changes nothing")
			assert_eq(st.visited, before, "the query leaves the story alone")
			st.visited[limbo] = true
			assert_eq(module.exit_target(st, limbo, CrookedMoonCampaign.LIMBO_ONWARD), chain[i + 1], "the mist leads on to the next car not been in")
			st.visited[chain[i + 1]] = true
			assert_eq(module.exit_target(st, chain[i], "module_switcheroo_next"), chain[i + 1], "a second crossing is a plain door")
			assert_eq(module.exit_target(st, chain[i + 1], "module_switcheroo_previous"), chain[i], "and so is the way back")
	GameState.reset()


func test_the_mist_is_a_closed_stretch_with_one_way_on() -> void:
	var loc := _loc("ghostlight_limbo")
	assert_true(not loc.is_empty(), "the mist is a place")
	assert_eq(str(loc.get("region")), "ghostlight_express")
	var exits := loc.get("exits", []) as Array
	assert_eq(exits.size(), 1, "one way, and it is on")
	var out := exits[0] as Dictionary
	assert_eq(str(out["to"]), CrookedMoonCampaign.LIMBO_ONWARD)
	assert_eq(str(out.get("when", "")), "", "nothing bars it")
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	var start := _cell((loc["spawns"] as Dictionary)["from_rear"] as Array)
	var reach := _reach(rows, start)
	var door := _cell(out["cell"] as Array)
	var near := false
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			near = near or reach.has(Vector2i(door.x + dx, door.y + dy))
	assert_true(near, "the way on can be walked to")
	for x: int in (rows[0] as String).length():
		for y: int in rows.size():
			if (x == 0 or y == 0 or x == (rows[0] as String).length() - 1 or y == rows.size() - 1) and not (x == door.x and y == door.y):
				assert_true(not _walkable(rows, x, y), "the mist's edge is walled at %d,%d" % [x, y])
	for id: String in CARS.slice(1):
		assert_true(((_loc(id)["spawns"] as Dictionary)).has("from_rear"), "%s has the spawn the mist lets out at" % id)
	var narrator := Narrator.new()
	assert_true(narrator.has_trigger("enter:ghostlight_limbo"), "the Narrator speaks in the mist")
	assert_true(narrator.has_trigger("switcheroo:arrive"), "and as the new car comes clear")


## Coming out of the mist into a car plays the Narrator's `switcheroo:arrive`; coming into it from another car does not.
func test_the_narrator_says_the_car_changed_only_when_coming_out_of_the_mist() -> void:
	for from: String in [CrookedMoonCampaign.limbo_place(), "ghostlight_g1_passenger"]:
		GameState.reset()
		var st := GameState.story
		for pid: String in GAME.PLACEHOLDER_PARTY:
			st.party.append(Pregens.build(pid, 3))
		st.location = from
		var view := LocationView.create("ghostlight_g2_sleeper", st, Narrator.new(), Dice.roller, "from_rear")
		var said: Array[String] = []
		view.narration.connect(func(t: String) -> void: said.append(t))
		add_child(view)
		assert_eq(st.narrator.has("switcheroo:arrive"), from == CrookedMoonCampaign.limbo_place(), "the arrival line plays only out of the mist (from %s)" % from)
		assert_true(st.visited.has("ghostlight_g2_sleeper"), "the car is recorded as visited")
		assert_true(not said.is_empty(), "the car speaks")
		view.queue_free()
		await get_tree().process_frame
	GameState.reset()


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


## Every place's props: examine/decor and search finds the Narrator has a line for, with no class or companion in the party at all.
func test_a_plain_party_hears_the_narrator_at_every_look_and_find() -> void:
	var asked := 0
	for place: String in PLACES:
		for p: Dictionary in _loc(place).get("props", []):
			var kind := str(p.get("kind", ""))
			if str(p.get("dialogue", "")) != "" or not kind in ["examine", "decor", "search"]:
				continue
			var key := "%s:%s" % ["search" if kind == "search" else "examine", p["id"]]
			var narrator := Narrator.new()
			if not narrator.has_trigger(key):
				continue
			var st := StoryState.new()
			asked += 1
			assert_true(narrator.line(key, st, null) != "", "%s speaks for a party with no class or name to match" % key)
	assert_true(asked > 60, "the check looked at the Act 1 props (%d)" % asked)


## No `examine:` or `search:` key in the Act 1 Narrator file names a prop that is not there (the grille is grille_g1; there is no locomotive
## prop). A prop may also name its line with `say` (the six dining booths share examine:g4_booth).
func test_every_look_and_find_line_belongs_to_a_prop() -> void:
	var keys: Dictionary = {}
	for place: String in PLACES:
		for p: Dictionary in _loc(place).get("props", []):
			keys["examine:" + str(p["id"])] = true
			keys["search:" + str(p["id"])] = true
			if str(p.get("say", "")) != "":
				keys[str(p["say"])] = true
	var file := DialogueFile.load_key("narrator/ghostlight_express")
	for key: String in file.order:
		if key.begins_with("examine:") or key.begins_with("search:"):
			assert_true(keys.has(key), "%s belongs to a prop in Act 1" % key)
