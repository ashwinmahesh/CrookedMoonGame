extends TestCase
## R12, the Crooked House: its five places load and hang together (the maps worker's checks). Every place exists with its spawns, every
## row is as long as the first, every spawn, exit, door, prop, container and trap can be walked to from where the party arrives, nothing
## shares a square, the stairs and the hatch pair up, the contract's ids are all there, the estate's land has height and no square pond
## and no row of trees, the porch and the ward open on the flags the package names, and the game really starts every place.

const GAME := preload("res://world/game_root.gd")
const ESTATE := "druskenvald_estate"
const FLOORS := ["crooked_house_first", "crooked_house_second", "crooked_house_third", "crooked_house_attic"]
const PLACES := ["druskenvald_estate", "crooked_house_first", "crooked_house_second", "crooked_house_third", "crooked_house_attic"]

## The package contract's spawns (section 2), prop ids (section 3), doors, containers, traps and areas, by place.
const SPAWNS := {
	"druskenvald_estate": ["from_village", "default"],
	"crooked_house_first": ["from_porch", "from_above", "default"],
	"crooked_house_second": ["from_below", "from_above", "default"],
	"crooked_house_third": ["from_below", "default"],
	"crooked_house_attic": ["from_ladder", "default"],
}
const PROPS := {
	"crooked_house_first": ["h1_porch_edge", "h2_portrait_lockwood", "h2_portrait_druskenvald", "h2_portrait_party", "h2_chandelier",
		"h2_stair", "h3_spirit_board", "h3_crystal_ball", "h3_fireplace", "h4_peacock", "h4_bust", "h4_paintings", "h5_harpsichord",
		"h5_mirror", "h6_table", "h6_table_loot", "h7_shelf", "h8_bergamot", "h8_cup"],
	"crooked_house_second": ["h9_clock", "h9_rail", "h10_closet", "h10_bed_left", "h10_bed_right", "h10_chest", "h10_armoire",
		"h10_window", "h10_doll", "h11_tub", "h12_bed", "h12_journal", "h12_scratchings"],
	"crooked_house_third": ["h13_crib", "h14_cart", "h14_tome", "h14_desk", "h15_trapdoor", "h15_bear", "h15_trophy_crow"],
	"crooked_house_attic": ["h16_sockets", "h16_runes", "h17_cauldron", "h17_phillip", "h17_adela", "h17_scratchings"],
}
const DOORS := {
	"crooked_house_second": ["h11_door", "h12_balcony_doors"],
	"crooked_house_attic": ["h16_ward"],
}
const AREAS := {
	"crooked_house_first": ["h5_floor"],
	"crooked_house_second": ["balcony_edge"],
	"crooked_house_attic": ["h17_cauldron_area"],
}

var root: Node


func _loc(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _rows(id: String) -> Array:
	return (_loc(id)["map"] as Dictionary)["rows"] as Array


func _walkable(rows: Array, x: int, y: int) -> bool:
	return y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length() and ".~1234_=".contains((rows[y] as String)[x])


func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


## Squares reachable from `start` over open floor, one square at a time (no cutting a wall's corner). Low cover is walked over;
## a door's square is floor, so a shut door counts as a way through (its lock is a skill check, not a wall).
func _reach(rows: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n) and _walkable(rows, n.x, n.y):
				seen[n] = true
				todo.append(n)
	return seen


## Whether the square is reached, or a wall square (an exit in a wall) with a reached square beside it.
func _reached_or_beside(reach: Dictionary, rows: Array, c: Vector2i) -> bool:
	if reach.has(c):
		return true
	if _walkable(rows, c.x, c.y):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if reach.has(c + d):
			return true
	return false


func _flag_state(flags: Dictionary) -> StoryState:
	GameState.reset()
	var st := GameState.story
	for k: String in flags:
		st.set_flag(k, flags[k])
	return st


func test_every_place_exists_with_its_spawns_and_rests_no() -> void:
	for id: String in PLACES:
		var loc := _loc(id)
		assert_true(not loc.is_empty(), "%s is data" % id)
		assert_eq(str(loc.get("region")), "crooked_house", "%s is in the region" % id)
		var spawns := loc.get("spawns", {}) as Dictionary
		assert_true(spawns.has("default"), "%s has a default spawn" % id)
		for s: String in SPAWNS[id]:
			assert_true(spawns.has(s), "%s has the spawn %s" % [id, s])
		assert_eq(str(loc.get("rest")), "no", "%s: no Long Rest (the house won't let you sleep)" % id)
		assert_true(str(loc.get("rest_text", "")).length() > 20, "%s says why in its own words" % id)


func test_every_row_is_as_long_as_the_first() -> void:
	for id: String in PLACES:
		var rows := _rows(id)
		var w := (rows[0] as String).length()
		for z in rows.size():
			assert_eq((rows[z] as String).length(), w, "%s row %d" % [id, z])
		var el := ((_loc(id)["map"] as Dictionary).get("elevation", []) as Array)
		if not el.is_empty():
			assert_eq(el.size(), rows.size(), "%s: one elevation row a map row" % id)
			for z in el.size():
				assert_eq((el[z] as String).length(), w, "%s elevation row %d" % [id, z])
	assert_eq(_rows(ESTATE).size(), 36, "the estate is 36 deep")
	assert_eq((_rows(ESTATE)[0] as String).length(), 40, "and 40 across")


func test_everything_can_be_walked_to_from_the_arrival() -> void:
	for id: String in PLACES:
		var loc := _loc(id)
		var rows := _rows(id)
		var spawns := loc["spawns"] as Dictionary
		var reach := _reach(rows, _cell(spawns["default"] as Array))
		for s: String in spawns:
			assert_true(reach.has(_cell(spawns[s] as Array)), "%s: spawn %s can be walked to from the default" % [id, s])
		for e: Dictionary in loc.get("exits", []):
			assert_true(_reached_or_beside(reach, rows, _cell(e["cell"] as Array)), "%s: exit %s can be walked to" % [id, e["id"]])
		for d: Dictionary in loc.get("doors", []):
			assert_true(reach.has(_cell(d["cell"] as Array)), "%s: door %s can be walked to" % [id, d["id"]])
		for p: Dictionary in loc.get("props", []):
			var c := _cell(p["cell"] as Array)
			assert_true(reach.has(c), "%s: prop %s at %s can be walked to" % [id, p["id"], c])
			if p.has("span"):
				for i: int in int((p["span"] as Array)[0]):
					for j: int in int((p["span"] as Array)[1]):
						assert_true(_walkable(rows, c.x + i, c.y + j), "%s: prop %s's whole span is floor" % [id, p["id"]])
		for ct: Dictionary in loc.get("containers", []):
			assert_true(_reached_or_beside(reach, rows, _cell(ct["cell"] as Array)), "%s: container %s can be walked to" % [id, ct["id"]])
		for t: Dictionary in loc.get("traps", []):
			for tc: Array in t["cells"]:
				assert_true(reach.has(_cell(tc)), "%s: trap %s at %s can be walked to" % [id, t["id"], tc])
		for n: Dictionary in loc.get("npcs", []):
			if bool(n.get("asleep", false)) or bool(n.get("lying", false)):
				continue
			assert_true(_reached_or_beside(reach, rows, _cell(n["cell"] as Array)), "%s: %s can be reached" % [id, n["npc"]])
		for a: Dictionary in loc.get("areas", []):
			for c: Array in a["cells"]:
				assert_true(_cell(c).x < (rows[0] as String).length() and _cell(c).y < rows.size(), "%s: area %s is on the map" % [id, a["id"]])


func test_no_prop_container_or_person_shares_a_square() -> void:
	for id: String in PLACES:
		var loc := _loc(id)
		var seen := {}
		for p: Dictionary in loc.get("props", []):
			var c := _cell(p["cell"] as Array)
			var w := 1
			var h := 1
			if p.has("span"):
				w = int((p["span"] as Array)[0])
				h = int((p["span"] as Array)[1])
			for i in w:
				for j in h:
					var at := Vector2i(c.x + i, c.y + j)
					assert_true(not seen.has(at), "%s: %s shares %s with %s" % [id, p["id"], at, seen.get(at, "")])
					seen[at] = str(p["id"])
		for ct: Dictionary in loc.get("containers", []):
			var c := _cell(ct["cell"] as Array)
			assert_true(not seen.has(c), "%s: container %s shares %s with %s" % [id, ct["id"], c, seen.get(c, "")])
			seen[c] = str(ct["id"])
		for n: Dictionary in loc.get("npcs", []):
			var c := _cell(n["cell"] as Array)
			assert_true(not seen.has(c), "%s: %s stands on %s" % [id, n["npc"], seen.get(c, "")])
		for kind: String in ["props", "containers", "doors", "exits", "traps", "areas"]:
			var local := {}
			for e: Dictionary in loc.get(kind, []):
				assert_true(not local.has(str(e["id"])), "%s: %s id %s is used twice" % [id, kind, e["id"]])
				local[str(e["id"])] = true


func test_the_contracts_ids_are_all_there() -> void:
	for id: String in PROPS:
		var have := {}
		for p: Dictionary in _loc(id).get("props", []):
			have[str(p["id"])] = true
		for pid: String in PROPS[id]:
			assert_true(have.has(pid), "%s has the prop %s" % [id, pid])
	for id: String in DOORS:
		var have := {}
		for d: Dictionary in _loc(id).get("doors", []):
			have[str(d["id"])] = true
		for did: String in DOORS[id]:
			assert_true(have.has(did), "%s has the door %s" % [id, did])
	for id: String in AREAS:
		var have := {}
		for a: Dictionary in _loc(id).get("areas", []):
			have[str(a["id"])] = true
		for aid: String in AREAS[id]:
			assert_true(have.has(aid), "%s has the area %s" % [id, aid])
	var first := _loc("crooked_house_first")
	var traps := {}
	for t: Dictionary in first.get("traps", []):
		traps[str(t["id"])] = t
	assert_true(traps.has("h7_oven_trap"), "the kitchen's oven trap")
	assert_eq(int(((traps["h7_oven_trap"] as Dictionary)["save"] as Dictionary)["dc"]), 13, "Constitution DC 13")
	assert_eq(int((traps["h7_oven_trap"] as Dictionary)["disarm_dc"]), 15, "disarmed at DC 15")
	var boxes := {}
	for c: Dictionary in first.get("containers", []):
		boxes[str(c["id"])] = true
	assert_true(boxes.has("h7_oven_contents"), "what the oven holds")
	assert_true(not (_loc("crooked_house_third").get("containers", []) as Array).is_empty(), "the cart's bottles")
	var edge := false
	for t: Dictionary in first.get("traps", []):
		edge = edge or (str(t["id"]).begins_with("h1_") and str(t.get("damage_type")) == "lightning")
	assert_true(edge, "the porch's edge is a lightning trap")
	var balcony := false
	for t: Dictionary in _loc("crooked_house_second").get("traps", []):
		balcony = balcony or str(t.get("damage_type")) == "lightning"
	assert_true(balcony, "and so is the balcony's")


func test_the_stairs_pair_up_and_the_hatch_waits_for_the_trapdoor() -> void:
	for id: String in PLACES:
		for e: Dictionary in _loc(id).get("exits", []):
			var to := str(e["to"])
			if to == "travel":
				continue
			assert_true(PLACES.has(to), "%s: %s leads into the house or its grounds" % [id, e["id"]])
			var dest := _loc(to)
			assert_true((dest["spawns"] as Dictionary).has(str(e.get("spawn", "default"))), "%s: %s's arrival square exists" % [id, e["id"]])
			var back := false
			for x: Dictionary in dest.get("exits", []):
				back = back or str(x["to"]) == id
			assert_true(back, "%s leads back from %s" % [id, to])
	var up: Dictionary = {}
	var down: Dictionary = {}
	for e: Dictionary in _loc("crooked_house_third").get("exits", []):
		if str(e["to"]) == "crooked_house_attic":
			up = e
	for e: Dictionary in _loc("crooked_house_attic").get("exits", []):
		if str(e["to"]) == "crooked_house_third":
			down = e
	assert_true(str(up.get("when", "")).contains("trapdoor_known"), "the hatch up opens once the trapdoor is known")
	assert_eq(str(down.get("when", "")), "", "the way down is never shut")
	assert_eq(str(up.get("spawn")), "from_ladder")
	var st := _flag_state({})
	assert_true(not StoryConditions.check(str(up["when"]), st), "unknown, the hatch is plaster")
	st.set_flag("trapdoor_known")
	assert_true(StoryConditions.check(str(up["when"]), st), "known, the hatch is a way up")
	GameState.reset()


func test_the_porch_exit_is_shut_by_the_storm_until_vessla_dies() -> void:
	var out: Dictionary = {}
	for e: Dictionary in _loc("crooked_house_first").get("exits", []):
		if str(e["to"]) == ESTATE:
			out = e
	assert_true(not out.is_empty(), "the porch has its steps down")
	assert_true(str(out.get("locked_text", "")).length() > 20, "and says why they are shut")
	var when := str(out["when"])
	assert_true(StoryConditions.check(when, _flag_state({})), "before the house turns, the steps are free")
	assert_true(not StoryConditions.check(when, _flag_state({"crooked_house_turned": true})), "once it has turned, the storm holds the porch")
	assert_true(StoryConditions.check(when, _flag_state({"crooked_house_turned": true, "vessla_slain": true})), "and lets go when Vessla is dead")
	GameState.reset()
	var porch: Dictionary = {}
	for e: Dictionary in _loc(ESTATE).get("exits", []):
		if str(e["to"]) == "crooked_house_first":
			porch = e
	assert_eq(str(porch.get("spawn")), "from_porch", "the estate's steps land on the porch")
	var road: Dictionary = {}
	for e: Dictionary in _loc(ESTATE).get("exits", []):
		if str(e["to"]) == "travel":
			road = e
	assert_true(not road.is_empty(), "the hill road is the travel map")
	for t: Dictionary in _loc("crooked_house_first").get("traps", []):
		if str(t["id"]).begins_with("h1_"):
			assert_true(str(t.get("when", "")).contains("crooked_house_turned"), "the storm's edge waits for the house to turn")
			assert_true(str(t.get("when", "")).contains("vessla_slain"), "and ends with Vessla")


func test_the_ward_door_opens_on_six_mementos() -> void:
	var ward: Dictionary = {}
	for d: Dictionary in _loc("crooked_house_attic").get("doors", []):
		if str(d["id"]) == "h16_ward":
			ward = d
	assert_true(not ward.is_empty(), "the ward is a door")
	assert_eq(str(ward.get("leaf")), "none", "drawn as light, with no leaf")
	for n: int in [0, 5]:
		assert_true(not StoryConditions.check(str(ward["when"]), _flag_state({"mementos_placed": n})), "%d mementos: shut" % n)
	for n: int in [6, 7]:
		assert_true(StoryConditions.check(str(ward["when"]), _flag_state({"mementos_placed": n})), "%d mementos: open" % n)
	GameState.reset()
	var rows := _rows("crooked_house_attic")
	var reach := _reach(rows, _cell((_loc("crooked_house_attic")["spawns"] as Dictionary)["default"] as Array))
	var cauldron := _cell(_prop("crooked_house_attic", "h17_cauldron")["cell"] as Array)
	assert_true(reach.has(cauldron), "the cauldron room is reached through the ward's square")
	var wall_row := _cell(ward["cell"] as Array).y
	for x: int in (rows[wall_row] as String).length():
		if x != _cell(ward["cell"] as Array).x:
			assert_true(not _walkable(rows, x, wall_row), "the ward's square is the only way through the wall at %d,%d" % [x, wall_row])


func _prop(place: String, id: String) -> Dictionary:
	for p: Dictionary in _loc(place).get("props", []):
		if str(p["id"]) == id:
			return p
	return {}


func test_the_foyer_has_the_stair_and_every_room_is_walked_into_from_the_porch() -> void:
	var first := _loc("crooked_house_first")
	var stair: Dictionary = {}
	for e: Dictionary in first["exits"]:
		if str(e["to"]) == "crooked_house_second":
			stair = e
	assert_eq(str(stair.get("spawn")), "from_below")
	var foyer: Dictionary = {}
	for a: Dictionary in first["areas"]:
		if str(a["id"]) == "h2_foyer":
			foyer = a
	var corner := (foyer["cells"] as Array)[0] as Array
	var far := (foyer["cells"] as Array)[1] as Array
	assert_true(_cell(stair["cell"] as Array).x >= int(corner[0]) and _cell(stair["cell"] as Array).x <= int(far[0]), "the stair is in the foyer")
	# every room has a way into its hall: some floor square of each room area touches a door or gap on the room's wall line
	var rows := _rows("crooked_house_first")
	var reach := _reach(rows, _cell((first["spawns"] as Dictionary)["default"] as Array))
	for a: Dictionary in first["areas"]:
		var c0 := _cell((a["cells"] as Array)[0] as Array)
		var found := false
		for z: int in range(c0.y, _cell((a["cells"] as Array)[1] as Array).y + 1):
			for x: int in range(c0.x, _cell((a["cells"] as Array)[1] as Array).x + 1):
				found = found or reach.has(Vector2i(x, z))
		assert_true(found, "%s can be walked into from the porch" % a["id"])


func test_the_estate_is_land_with_height_water_that_wanders_and_no_row_of_trees() -> void:
	var rows := _rows(ESTATE)
	var el := (_loc(ESTATE)["map"] as Dictionary)["elevation"] as Array
	var digits := {}
	for z in el.size():
		for ch: String in (el[z] as String):
			digits[ch] = true
	assert_true(digits.size() >= 6, "the grounds climb through at least six heights (found %d)" % digits.size())
	for z in rows.size():
		for x in (rows[z] as String).length():
			if not _walkable(rows, x, z):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nx := x + d.x
				var nz := z + d.y
				if _walkable(rows, nx, nz):
					var a := "0123456789abcdefghijklmnopqrstuvwxyz".find((el[z] as String)[x])
					var b := "0123456789abcdefghijklmnopqrstuvwxyz".find((el[nz] as String)[nx])
					assert_true(absi(a - b) < 3, "no cliff between walked squares at %d,%d" % [x, z])
	# water: every body of it is a wandering shape, never a filled rectangle
	var seen := {}
	var bodies := 0
	for z in rows.size():
		for x in (rows[z] as String).length():
			var c := Vector2i(x, z)
			if (rows[z] as String)[x] != "w" or seen.has(c):
				continue
			bodies += 1
			var todo: Array[Vector2i] = [c]
			seen[c] = true
			var count := 0
			var lo := c
			var hi := c
			while not todo.is_empty():
				var at: Vector2i = todo.pop_back()
				count += 1
				lo = Vector2i(mini(lo.x, at.x), mini(lo.y, at.y))
				hi = Vector2i(maxi(hi.x, at.x), maxi(hi.y, at.y))
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := at + d
					if n.y >= 0 and n.y < rows.size() and n.x >= 0 and n.x < (rows[0] as String).length() and (rows[n.y] as String)[n.x] == "w" and not seen.has(n):
						seen[n] = true
						todo.append(n)
			assert_true(count < 4 or count < (hi.x - lo.x + 1) * (hi.y - lo.y + 1), "the water at %s is not a filled rectangle" % c)
	assert_true(bodies >= 1, "the estate has its pond")
	# trees: no four in a line at an even step, and none side by side
	var trees := {}
	for p: Dictionary in _loc(ESTATE).get("props", []):
		if str(p["id"]).begins_with("estate_tree_"):
			trees[_cell(p["cell"] as Array)] = true
	assert_true(trees.size() >= 30, "the grounds are wooded (found %d trees)" % trees.size())
	for c: Vector2i in trees:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			assert_true(not trees.has(c + d), "no two trees side by side at %s" % c)
			for step: int in [2, 3]:
				assert_true(not (trees.has(c + d * step) and trees.has(c + d * step * 2) and trees.has(c + d * step * 3)), "no row of trees at %s" % c)
	# the manor is a block of wall with its porch deck in front
	var porch := 0
	for z in rows.size():
		porch += (rows[z] as String).count("_")
	assert_true(porch >= 40, "the wrap-around porch is a raised deck (%d squares)" % porch)
	var welcome := 0
	var ruined := 0
	for p: Dictionary in _loc(ESTATE).get("props", []):
		var w := str(p.get("when", ""))
		if w.begins_with("not flag.crooked_house_turned"):
			welcome += 1
		elif w.begins_with("flag.crooked_house_turned"):
			ruined += 1
	assert_true(welcome >= 8 and ruined >= 8, "the grounds are dressed both ways, keyed on the turning (%d, %d)" % [welcome, ruined])


func test_the_game_starts_every_place() -> void:
	for id: String in PLACES:
		GameState.reset()
		var st := GameState.story
		for pid: String in GAME.PLACEHOLDER_PARTY:
			st.party.append(Pregens.build(pid, 3))
		st.location = id
		var view := LocationView.create(id, st, Narrator.new(), Dice.roller, "default")
		add_child(view)
		var spawn := _cell(((_loc(id)["spawns"] as Dictionary)["default"] as Array))
		assert_eq(view.leader().cell, spawn, "%s: the party arrives on the default spawn" % id)
		view.queue_free()
		await get_tree().process_frame
	GameState.reset()
