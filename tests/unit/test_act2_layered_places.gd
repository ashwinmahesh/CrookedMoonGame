extends TestCase
## Act II's layered places (the full 3D grid build, 2026-11-02): the places that were a stack of separate places are one place each
## (tools/content/merge_floors.py), their floors over each other and their stairs and ladders meeting; and the decks laid into a
## place as layers of their own (tools/content/layer_decks.py): open air but for the deck, over squares that are still there.

## place id -> its floors from the lowest up, and the kind of each stair between them ("" for a stair).
const MERGED := {
	"dc_boat_promenade": {"floors": ["dc_boat_lower", "dc_boat_hall", "dc_boat_promenade", "dc_boat_captain"], "stairs": ["", "", ""]},
	"rk_dovecote_r1": {"floors": ["rk_dovecote_r1", "rk_dovecote_r2", "rk_dovecote_walkway"], "stairs": ["ladder", "ladder"]},
	"mr_ground": {"floors": ["mr_ground", "mr_upper"], "stairs": []},
	"sk_upper": {"floors": ["sk_deep", "sk_upper"], "stairs": ["ladder"]},
	"dc_shack_approach": {"floors": ["dc_shack_approach", "dc_shack"], "stairs": ["ladder"]},
	"mm_highborn_crypts": {"floors": ["mm_crypt_below", "mm_highborn_crypts"], "stairs": [""]},
}
## place id -> its decks: id -> how far over the floor under it (ft).
const DECKS := {
	"dc_casino": {"dc_casino_balcony": 10},
	"rk_dovecote_r1": {"rk_dovecote_walkway": 10},
	"mr_grotto": {"mr_grotto_bridge": 5},
	"mm_tomb": {"mm_tomb_first_platform": 10, "mm_tomb_hanging_platform": 20},
}


func _place(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _floor_ids(id: String) -> Array:
	return (((_place(id)["map"] as Dictionary)["floors"] as Array)).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))


func _check_stairs(id: String) -> void:
	var g := LocationView.grid_for(_place(id))
	for s: Variant in (_place(id)["map"] as Dictionary)["stairs"]:
		var a := LocationView._cell((s as Dictionary)["from"])
		var b := LocationView._cell((s as Dictionary)["to"])
		assert_true(g.floor_index(b) > g.floor_index(a), "%s %s climbs to a higher floor" % [id, s])
		var wa := g.world_center(a)
		var wb := g.world_center(b)
		assert_true(Vector2(wa.x, wa.z).distance_to(Vector2(wb.x, wb.z)) <= 3.0, "%s %s comes out over where it starts" % [id, s])
		assert_true(g.height(b) > g.height(a), "%s %s goes up" % [id, s])
		assert_false(g.is_solid(a) or g.is_solid(b), "%s %s joins two squares to stand on" % [id, s])
		assert_true((g.stairs.get(a, []) as Array).has(b), "%s %s is a way in the grid" % [id, s])
		assert_true(str((s as Dictionary).get("kind", "stair")) in ["stair", "ladder", "ramp"], "%s %s is a stair, a ladder or a ramp" % [id, s])


func test_every_merged_place_holds_its_floors_and_the_old_places_are_gone() -> void:
	for id: String in MERGED:
		var spec := MERGED[id] as Dictionary
		var floors := _floor_ids(id)
		for want: Variant in spec["floors"]:
			assert_true(floors.has(str(want)), "%s holds %s" % [id, want])
			if str(want) != id and not str(want).ends_with("walkway"):
				assert_false(Compendium.shared().has("locations", str(want)), "%s is no longer a place of its own" % want)
		var kinds := ((_place(id)["map"] as Dictionary)["stairs"] as Array).map(
			func(s: Variant) -> String: var k := str((s as Dictionary).get("kind", "")); return "" if k == "stair" else k)
		assert_eq(kinds, spec["stairs"], "%s: its stairs and ladders" % id)
		_check_stairs(id)
		var heights := ((_place(id)["map"] as Dictionary)["floors"] as Array).map(func(f: Variant) -> int: return int((f as Dictionary)["height_ft"]))
		for i in range(1, (spec["floors"] as Array).size()):
			assert_true(int(heights[i]) > int(heights[i - 1]), "%s: each floor stands over the one below" % id)


func test_every_way_within_a_place_sets_the_party_down() -> void:
	for id: String in MERGED:
		for e: Variant in _place(id)["exits"]:
			var ex := e as Dictionary
			assert_true(Compendium.shared().has("locations", str(ex["to"])) or str(ex["to"]) == "travel", "%s: %s leads to a place" % [id, ex["id"]])
			if str(ex["to"]) == id:
				assert_true((_place(id)["spawns"] as Dictionary).has(str(ex.get("spawn", "default"))), "%s: %s sets the party down" % [id, ex["id"]])
	assert_eq(str(_exit("dc_casino", "back_to_hall")["to"]), "dc_boat_promenade", "the casino lets the party back into the boat's hall")
	assert_eq(str(_exit("mr_grotto", "lift_up")["to"]), "mr_ground", "the Plunge Platform rises to Memory's Rest's second floor")


func _exit(id: String, eid: String) -> Dictionary:
	for e: Variant in _place(id)["exits"]:
		if str((e as Dictionary)["id"]) == eid:
			return e as Dictionary
	return {}


func test_the_conversations_move_the_party_to_squares_that_are_there() -> void:
	var moves := {"skitterdeep/camp": ["sk_upper", "deep_from_shaft"], "memorys_rest/rooms2c": ["mr_ground", "upper_from_lab"],
		"memorys_rest/rooms1": ["mr_ground", "upper_from_elevator"], "maidenmist/sites": ["mm_highborn_crypts", "below_from_stair"],
		"drowned_crossroads/boat": ["dc_boat_promenade", "lower_from_hall"]}
	for file: String in moves:
		var text := FileAccess.get_file_as_string("res://narrative/%s.dialogue" % file)
		var want := moves[file] as Array
		assert_true(text.contains("move %s:%s" % [want[0], want[1]]), "%s moves the party to %s:%s" % [file, want[0], want[1]])
		assert_true((_place(str(want[0]))["spawns"] as Dictionary).has(str(want[1])), "%s has %s" % [want[0], want[1]])


func test_the_crypt_stair_waits_for_the_tithe() -> void:
	var s := ((_place("mm_highborn_crypts")["map"] as Dictionary)["stairs"] as Array)[0] as Dictionary
	assert_eq(str(s.get("when", "")), "flag.mm_crypt_open")
	var text := FileAccess.get_file_as_string("res://narrative/maidenmist/sites.dialogue")
	assert_eq(text.count("set mm_crypt_open\nmove mm_highborn_crypts:below_from_stair"), 2, "both ways past the bats open the stair")


func test_every_deck_is_open_air_but_its_deck_and_stands_over_its_floor() -> void:
	for id: String in DECKS:
		var loc := _place(id)
		var map := loc["map"] as Dictionary
		var g := LocationView.grid_for(loc)
		for f: Variant in map["floors"]:
			var fl := f as Dictionary
			if not (DECKS[id] as Dictionary).has(str(fl["id"])):
				continue
			assert_eq(str(fl.get("kind", "")), "deck", "%s is a deck" % fl["id"])
			var under := int(fl["height_ft"]) - int((DECKS[id] as Dictionary)[str(fl["id"])])
			var deck := 0
			for z in g.depth:
				for x in range(int(fl["x0"]), int(fl["x0"]) + int(fl["width"])):
					var c := Vector2i(x, z)
					var ch := str((map["rows"] as Array)[z])[x]
					assert_true(ch == " " or ch == "." or ch in "1234", "%s: %s is deck or open air (%s)" % [fl["id"], c, ch])
					if ch != " ":
						deck += 1
						assert_true(g.height(c) >= int(fl["height_ft"]), "%s: %s stands at its height" % [fl["id"], c])
			assert_true(deck > 0, "%s has a deck" % fl["id"])
			assert_true(under >= 0, "%s stands over a floor" % fl["id"])
		_check_stairs(id)


func test_the_tombs_platforms_hang_over_the_tomb_floor() -> void:
	var loc := _place("mm_tomb")
	var g := LocationView.grid_for(loc)
	var rows := (loc["map"] as Dictionary)["rows"] as Array
	for z in rows.size():
		for x in 22:
			assert_false(str(rows[z])[x] in "234", "the tomb floor has no raised block left at (%d, %d)" % [x, z])
	var shrouded := {}
	for e: Variant in loc["encounters"]:
		for m: Variant in (e as Dictionary).get("monsters", []):
			var md := m as Dictionary
			if bool(md.get("boss", false)):
				shrouded[str(md["monster"])] = g.floor_index(LocationView._cell(md["cell"]))
	assert_false(shrouded.is_empty(), "the harrowing has its boss")
	for mid: String in shrouded:
		assert_eq(int(shrouded[mid]), 1, "%s stands on the first platform, as it did on the raised block" % mid)
