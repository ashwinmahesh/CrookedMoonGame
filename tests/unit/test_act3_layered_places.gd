extends TestCase
## Act III's layered places (tools/content/add_decks.py): the Silent Church's choir loft over the back of the nave, up a stair,
## and the Crooked Bookshelf's shelf above, up the stack of books. Each is a deck of its place laid in new columns past the
## map's, so no square, arrival point or way out moves; its way up joins two squares to stand on, climbs, comes out beside where
## it starts and is reached on foot from where the party comes in.

## place -> [the deck's height in feet, the kind of its way up, whether it has a rail]
const LAYERS := {
	"fd_silent_church": [10, "stair", true],
	"nm_bookshelf": [10, "ladder", false],
}


func _place(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _laid(id: String) -> Dictionary:
	for f: Variant in ((_place(id)["map"] as Dictionary)["floors"] as Array):
		if (f as Dictionary).has("kind"):
			return f as Dictionary
	return {}


func _links(id: String) -> Array:
	return ((_place(id)["map"] as Dictionary).get("stairs", []) as Array).filter(func(s: Variant) -> bool: return (s as Dictionary).has("kind"))


func test_each_deck_is_a_floor_of_its_place() -> void:
	for id: String in LAYERS:
		var f := _laid(id)
		assert_false(f.is_empty(), "%s has its deck" % id)
		assert_eq(str(f.get("kind", "")), "deck", "%s: a deck" % id)
		assert_eq(int(f.get("height_ft", -1)), int((LAYERS[id] as Array)[0]), "%s: its height" % id)
		assert_eq(int(f.get("rail_ft", 0)) > 0, bool((LAYERS[id] as Array)[2]), "%s: its rail" % id)


func test_nothing_the_place_had_moved() -> void:
	for id: String in LAYERS:
		var place := _place(id)
		var laid := int(_laid(id)["x0"])
		for s: Variant in (place["spawns"] as Dictionary).values():
			assert_true(int((s as Array)[0]) < laid, "%s: an arrival point stays on the place's own squares" % id)
		for e: Variant in place["exits"]:
			assert_true(int(((e as Dictionary)["cell"] as Array)[0]) < laid, "%s: a way out stays where it was" % id)
		for p: Variant in place["props"]:
			if (p as Dictionary).has("cell"):
				assert_true(int(((p as Dictionary)["cell"] as Array)[0]) < laid, "%s: %s stays where it was" % [id, (p as Dictionary)["id"]])


func test_the_party_walks_up_each_way_up() -> void:
	for id: String in LAYERS:
		var place := _place(id)
		var g := LocationView.grid_for(place)
		var links := _links(id)
		assert_eq(links.size(), 1, "%s: one way up" % id)
		var start := LocationView._cell((place["spawns"] as Dictionary)["default"])
		var reach := g.reachable(start, 1, 4000, func(_c: Vector2i) -> bool: return false,
			func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
		for s: Variant in links:
			var a := LocationView._cell((s as Dictionary)["from"])
			var b := LocationView._cell((s as Dictionary)["to"])
			assert_eq(str((s as Dictionary)["kind"]), str((LAYERS[id] as Array)[1]), "%s: its kind" % id)
			assert_false(g.is_solid(a) or g.is_solid(b), "%s: it joins two squares to stand on" % id)
			assert_true(g.floor_index(b) > g.floor_index(a), "%s: it climbs to the deck" % id)
			var wa := g.world_center(a)
			var wb := g.world_center(b)
			assert_true(Vector2(wa.x, wa.z).distance_to(Vector2(wb.x, wb.z)) <= 1.5, "%s: it comes out beside where it starts" % id)
			assert_true(reach.has(b), "%s: the party walks up it from where it comes in" % id)
