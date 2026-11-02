extends TestCase
## Act I's layered places (the full 3D grid build, lane B1; tools/content/add_decks.py and the engine's Decks): a hay loft over
## the stable's stalls, a gallery over the bookstore's shelves, a walkway of perches round the dovecote and the windmill's stone
## floor. Each is a floor of its place, a deck (open air but for its own squares) or a storey, laid in new columns past the map's
## so no square, arrival point or way out the place had moves; a ladder joins it to the floor below, the party can walk up it,
## and the board draws its boards, rails and ladder.

## place -> [the layer's height in feet, its kind]
const LAYERS := {
	"wickermoor_stable": [10, "deck"],
	"wickermoor_bookstore": [10, "deck"],
	"wickermoor_dovecote": [10, "deck"],
	"fw_windmill": [30, "storey"],
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


func test_each_layer_is_a_floor_of_its_place() -> void:
	for id: String in LAYERS:
		var f := _laid(id)
		assert_false(f.is_empty(), "%s has its layer" % id)
		assert_eq(int(f.get("height_ft", -1)), int((LAYERS[id] as Array)[0]), "%s: its height" % id)
		assert_eq(str(f.get("kind", "")), str((LAYERS[id] as Array)[1]), "%s: its kind" % id)
		var floors := (_place(id)["map"] as Dictionary)["floors"] as Array
		for i in range(1, floors.size()):
			assert_true(int((floors[i] as Dictionary)["height_ft"]) >= int((floors[i - 1] as Dictionary)["height_ft"]) \
				or i == 1, "%s: its floors are listed lowest first" % id)


func test_nothing_the_place_had_moved() -> void:
	for id: String in LAYERS:
		var place := _place(id)
		var first := int(((place["map"] as Dictionary)["floors"] as Array)[0]["x0"])
		var laid := int(_laid(id)["x0"])
		for s: Variant in (place["spawns"] as Dictionary).values():
			assert_true(int((s as Array)[0]) < laid and int((s as Array)[0]) >= first, "%s: an arrival point stays on the place's own squares" % id)
		for e: Variant in place["exits"]:
			assert_true(int(((e as Dictionary)["cell"] as Array)[0]) < laid, "%s: a way out stays where it was" % id)


func test_a_ladder_joins_each_layer_and_the_party_can_climb_it() -> void:
	for id: String in LAYERS:
		var place := _place(id)
		var g := LocationView.grid_for(place)
		var links := _links(id)
		assert_true(links.size() >= 1, "%s: a way up" % id)
		var start := LocationView._cell((place["spawns"] as Dictionary)["default"])
		var reach := g.reachable(start, 1, 4000, func(_c: Vector2i) -> bool: return false,
			func(_c: Vector2i) -> bool: return false, func(_c: Vector2i) -> bool: return false)
		for s: Variant in links:
			var a := LocationView._cell((s as Dictionary)["from"])
			var b := LocationView._cell((s as Dictionary)["to"])
			assert_eq(str((s as Dictionary)["kind"]), "ladder", "%s: a ladder" % id)
			assert_false(g.is_solid(a) or g.is_solid(b), "%s: the ladder joins two squares to stand on" % id)
			assert_true(g.floor_index(b) > g.floor_index(a), "%s: it climbs to the layer" % id)
			var wa := g.world_center(a)
			var wb := g.world_center(b)
			assert_true(Vector2(wa.x, wa.z).distance_to(Vector2(wb.x, wb.z)) <= 1.5, "%s: it comes out beside where it starts" % id)
			assert_true(reach.has(b), "%s: the party walks up it from where it comes in" % id)


func test_the_board_draws_the_decks_and_their_ladders() -> void:
	for id: String in LAYERS:
		var place := _place(id)
		var board := ArenaBoard.build(LocationView.grid_for(place), str((place["map"] as Dictionary).get("theme", "manor")), id)
		var deck_squares := 0
		var ladders := 0
		for n in board.get_children():
			if n.name.begins_with("Deck_"):
				deck_squares += 1
				assert_true(n.has_meta(&"deck_at"), "%s: a deck square says where it stands" % id)
			if n.name.begins_with("Ladder_"):
				ladders += 1
		if str(_laid(id)["kind"]) == "deck":
			assert_true(deck_squares > 0, "%s: the deck's squares are drawn" % id)
			assert_true(Decks.is_deck(board, ((place["map"] as Dictionary)["floors"] as Array).find(_laid(id))), "%s: the board knows its deck" % id)
		assert_eq(ladders, _links(id).size(), "%s: each ladder is drawn" % id)
		board.free()


func test_a_storey_is_not_a_deck() -> void:
	var place := _place("fw_windmill")
	var board := ArenaBoard.build(LocationView.grid_for(place), "manor", "fw_windmill")
	for i in ((place["map"] as Dictionary)["floors"] as Array).size():
		assert_false(Decks.is_deck(board, i), "the windmill's floors are storeys")
	board.free()
