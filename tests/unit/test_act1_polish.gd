extends TestCase
## Act 1's look polish (look lane): every prop that names a model is drawn by something (the sweep found 90 that drew nothing: the
## estate's trees, the Express's lamps), the village's clocktower is lit, and every region's loading card has a picture and the tips
## name nothing of the old game.

## Models that the engine draws specially or that are deliberately bare (stairs are built from the map, a hay ladder is a prop of its own).
const BARE_OK := ["stairs_up", "stairs_down", "ladder"]


func _act1_places() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://data/locations"):
		if not f.ends_with(".json"):
			continue
		var id := f.get_basename()
		if id.begins_with("ghostlight_") or id.begins_with("wickermoor_") or id.begins_with("crooked_house_") or id == "druskenvald_estate":
			out.append(id)
	return out


func test_every_act1_prop_that_names_a_model_is_drawn_by_something() -> void:
	var bare: Array[String] = []
	for id in _act1_places():
		var loc := Compendium.shared().get_entry("locations", id)
		var specs: Array = (loc.get("props", []) as Array) + (loc.get("containers", []) as Array)
		for p: Variant in specs:
			var spec := p as Dictionary
			var model := str(spec.get("model", ""))
			if model == "" or model in BARE_OK:
				continue
			if SetDressing.look_for(spec, (loc.get("containers", []) as Array).has(p)).is_empty():
				bare.append("%s: %s (%s)" % [id, spec.get("id", ""), model])
	assert_true(bare.is_empty(), "props whose model draws nothing: %s" % ", ".join(bare.slice(0, 8)))


func test_the_villages_clocktower_is_a_bell_tower_with_lit_faces() -> void:
	var ids := (SetDressing.catalog()["ids"] as Dictionary)
	var entry := ids["wm_clocktower"] as Dictionary
	assert_eq(str(entry["set_piece"]), "clocktower")
	assert_true(SetDressing.has_art(str(entry["art"])), "a tower stands there whatever else happens")
	var b := ArenaBoard.build(CombatGrid.from_rows(["............", "............", "............", "............"],
		["111111111111", "111111111111", "111111111111", "111111111111"]), "village", "clock_test")
	add_child(b)
	var root := Node3D.new()
	b.add_child(root)
	var out := CrookedMoonLook.new().place_special("bell_tower", b, root, Vector2i(5, 1), {"id": "wm_clocktower", "cell": [5, 1], "span": [2, 2]}, entry)
	assert_true(out.is_empty(), "the catalog's tower is still drawn")
	var faces := root.get_node_or_null("ClockFaces") as Node3D
	assert_true(faces != null, "the faces hang")
	assert_eq(faces.find_children("*", "Sprite3D", true, false).size(), 4, "one on each side")
	assert_true(faces.get_node_or_null("ClockGlow") is OmniLight3D, "and a warm light")
	b.free()


func test_every_region_has_a_loading_picture_and_the_tips_name_nothing_of_the_old_game() -> void:
	var cards := JSON.parse_string(FileAccess.get_file_as_string("res://data/loading/cards.json")) as Dictionary
	assert_true(ResourceLoader.exists(LoadingCard.picture_for("no_such_region")), "the default picture exists")
	var regions := {}
	for f in DirAccess.get_files_at("res://data/locations"):
		if f.ends_with(".json"):
			regions[str(Compendium.shared().get_entry("locations", f.get_basename()).get("region", ""))] = true
	for r: String in regions:
		if r == "" or r == "test_grounds":
			continue
		assert_true((cards["regions"] as Dictionary).has(r), "%s has a card of its own" % r)
		assert_true(ResourceLoader.exists(LoadingCard.picture_for(r)), "%s's picture exists" % r)
	for tip: Variant in cards["tips"] as Array:
		assert_false(str(tip).contains("Barovia") or str(tip).contains("Strahd"), "tip: %s" % tip)
