extends TestCase
## The Crooked Moon's set pieces (CrookedMoonLook.place_special, plan G8): built in code through a catalog `set_piece`, over
## the squares the prop spans, and never claiming, moving or blocking one.

const ROWS := ["..........", "..........", "..........", "..........", "..........", "..........", "..........", ".........."]
const ELEV := ["1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111111111", "1111111111"]


func _board() -> ArenaBoard:
	var b := ArenaBoard.build(CombatGrid.from_rows(ROWS, ELEV), "village", "set_piece_test")
	add_child(b)
	return b


func _catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://art/sprites/props/catalog.json")) as Dictionary


func test_the_catalog_gives_the_village_oak_its_set_piece_and_a_fallback_picture() -> void:
	var ids := _catalog()["ids"] as Dictionary
	var oak := ids["wm_oak"] as Dictionary
	assert_eq(str(oak["set_piece"]), "oak")
	assert_true(SetDressing.has_art(str(oak["art"])), "the fallback art exists, so the oak is always drawn")
	assert_true(ids.has("wm_oak_roots_call") and ids["wm_oak_roots_call"] == null, "the second oak spot is only a clickable spot")


func test_the_oak_stands_over_its_squares_and_leaves_the_rules_alone() -> void:
	var b := _board()
	var root := Node3D.new()
	b.add_child(root)
	var spec := {"id": "wm_oak", "cell": [4, 3], "span": [2, 2]}
	var heights := []
	for z in 8:
		for x in 10:
			heights.append(b.grid.height(Vector2i(x, z)))
	var out := CrookedMoonLook.new().place_special("pine_clawed", b, root, Vector2i(4, 3), spec, {"art": "pine_clawed", "set_piece": "oak"})
	assert_true(bool(out.get("handled", false)), "the look built it")
	var oak := root.get_node_or_null("OakOfManyFaces") as Node3D
	assert_true(oak != null, "an oak stands there")
	var want := b.cell_center(Vector2i(4, 3)) + Vector3(0.5, 0.0, 0.5)
	assert_between(oak.position.distance_to(want), 0.0, 0.001, "over the middle of the squares it spans")
	var trunk := oak.get_node_or_null("Trunk") as MeshInstance3D
	assert_true(trunk != null and trunk.mesh != null, "a trunk from the engine's dead tree")
	assert_true(trunk.get_aabb().size.y * trunk.scale.y > 7.0, "a tall one")
	assert_true(oak.get_node_or_null("OakGlow") is OmniLight3D, "its cold light")
	var faces := oak.find_children("Face", "Decal", true, false).size()
	if ResourceLoader.exists(OakOfManyFaces.FACES_DIR + "face_0.png"):
		assert_eq(faces, OakOfManyFaces.BANDS.size(), "a face on the bark for each band")
	else:
		assert_eq(faces, 0, "no faces until they are painted")
	var i := 0
	for z in 8:
		for x in 10:
			assert_eq(b.grid.height(Vector2i(x, z)), heights[i], "no square's height moved")
			i += 1
	b.free()


func test_a_prop_without_a_set_piece_is_left_to_the_catalog() -> void:
	var l := CrookedMoonLook.new()
	assert_true(l.place_special("pine_clawed", null, null, Vector2i.ZERO, {}, {"art": "pine_clawed"}).is_empty())
	assert_true(l.place_special("anything", null, null, Vector2i.ZERO, {}, {}).is_empty())
