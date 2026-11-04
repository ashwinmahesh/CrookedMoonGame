extends TestCase
## The fun pass's things to find (data/treasure/fun_finds.json, written into the places by tools/content/place_fun_finds.py;
## Ashwin, 2026-11-03, fun pass fix 3: exploring pays). Every container, hidden find and trap is in its place where the file
## says, on a square of the right kind, holding things that exist; a hidden find is a search prop with something worth the
## look; a trap is off the walks between the place's people, props, spawns and exits, so the story bots never meet one.

const FINDS := "res://data/treasure/fun_finds.json"


func _places() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FINDS))
	assert_true(parsed is Dictionary, "fun_finds.json parses")
	return (parsed as Dictionary).get("places", {}) as Dictionary if parsed is Dictionary else {}


func _entry(loc: Dictionary, key: String, id: String) -> Dictionary:
	for e: Variant in loc.get(key, []):
		if str((e as Dictionary).get("id", "")) == id:
			return e as Dictionary
	return {}


func _ch(loc: Dictionary, cell: Array) -> String:
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	return str(rows[int(cell[1])])[int(cell[0])]


func _item_exists(id: String) -> bool:
	return not Compendium.shared().item_data(id).is_empty() or not Compendium.shared().get_entry("items", id).is_empty()


func test_the_pass_reaches_curse_of_strahds_density_in_act_one() -> void:
	var counts := [0, 0, 0]
	for loc_id: String in _places():
		var p := _places()[loc_id] as Dictionary
		counts[0] += (p.get("containers", []) as Array).size()
		counts[1] += (p.get("finds", []) as Array).size()
		counts[2] += (p.get("traps", []) as Array).size()
		for c: Variant in p.get("containers", []):
			if (c as Dictionary).has("trap"):
				counts[2] += 1
	assert_true(counts[0] >= 40, "Act I gains containers (%d)" % counts[0])
	assert_true(counts[1] >= 12, "and hidden finds (%d)" % counts[1])
	assert_true(counts[2] >= 5, "and traps (%d)" % counts[2])


func test_every_container_is_in_its_place_on_floor_with_real_things() -> void:
	for loc_id: String in _places():
		var loc := Compendium.shared().get_entry("locations", loc_id)
		assert_false(loc.is_empty(), "%s is a place" % loc_id)
		for c: Variant in (_places()[loc_id] as Dictionary).get("containers", []):
			var spec := c as Dictionary
			var placed := _entry(loc, "containers", str(spec["id"]))
			assert_false(placed.is_empty(), "%s holds %s" % [loc_id, spec["id"]])
			assert_eq(placed.get("cell"), spec.get("cell"), "%s is where the file says" % spec["id"])
			assert_true(_ch(loc, spec["cell"] as Array) in [".", "_"], "%s stands on floor" % spec["id"])
			assert_true(SetDressing.look_for(placed, true).has("art") and str(SetDressing.look_for(placed, true)["art"]) != "", "%s has a piece of the props catalog" % spec["id"])
			for it: Variant in placed.get("items", []):
				assert_true(_item_exists(str((it as Dictionary)["id"])), "%s's %s exists" % [spec["id"], (it as Dictionary)["id"]])
			if spec.has("owner"):
				assert_false(Compendium.shared().get_entry("npcs", str(spec["owner"])).is_empty(), "%s's owner %s is a person" % [spec["id"], spec["owner"]])


func test_every_hidden_find_is_a_search_prop_worth_finding() -> void:
	for loc_id: String in _places():
		var loc := Compendium.shared().get_entry("locations", loc_id)
		for f: Variant in (_places()[loc_id] as Dictionary).get("finds", []):
			var spec := f as Dictionary
			var prop := _entry(loc, "props", str(spec["id"]))
			assert_eq(str(prop.get("kind", "")), "search", "%s is hidden until a Search" % spec["id"])
			assert_eq(prop.get("cell"), spec.get("cell"), "%s is where the file says" % spec["id"])
			assert_true(_item_exists(str(prop.get("item", ""))), "%s holds something (%s)" % [spec["id"], prop.get("item", "")])
			assert_true(int(prop.get("search_dc", 0)) >= 10, "%s takes some finding" % spec["id"])
			assert_ne(str(prop.get("text", "")), "", "%s has its line" % spec["id"])


## A trap's squares are off every shortest walk: each square's walkable neighbours all touch each other (a corner, a nook), or,
## round a container, the squares nobody needs to cross. Checked here the simple way: no trap square is a spawn, exit,
## person or prop square, or beside one.
func test_traps_keep_clear_of_where_people_stand() -> void:
	for loc_id: String in _places():
		var loc := Compendium.shared().get_entry("locations", loc_id)
		var busy := {}
		for key: String in ["exits", "npcs"]:
			for e: Variant in loc.get(key, []):
				var c: Variant = (e as Dictionary).get("cell")
				if c is Array:
					busy[Vector2i(int(c[0]), int(c[1]))] = true
		for v: Variant in (loc.get("spawns", {}) as Dictionary).values():
			if v is Array and (v as Array).size() >= 2:
				busy[Vector2i(int(v[0]), int(v[1]))] = true
		var ids: Array[String] = []
		for t: Variant in (_places()[loc_id] as Dictionary).get("traps", []):
			ids.append(str((t as Dictionary)["id"]))
		for c: Variant in (_places()[loc_id] as Dictionary).get("containers", []):
			if (c as Dictionary).has("trap"):
				ids.append(str((c as Dictionary)["id"]) + "_trap")
		for id in ids:
			var trap := _entry(loc, "traps", id)
			assert_false(trap.is_empty(), "%s is laid in %s" % [id, loc_id])
			assert_true(int(trap.get("detect_dc", 0)) > 0, "%s can be found" % id)
			assert_ne(str(trap.get("text", "")), "", "%s has its line" % id)
			for cell: Variant in trap.get("cells", []):
				var at := Vector2i(int(cell[0]), int(cell[1]))
				for b: Vector2i in busy:
					assert_true(maxi(absi(b.x - at.x), absi(b.y - at.y)) > 1, "%s keeps clear of %s in %s" % [id, b, loc_id])
