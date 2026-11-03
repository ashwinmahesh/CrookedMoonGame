extends TestCase
## The statues Ashwin picked (2026-11-03): the saint, the knight, Mother Night and the headless figure are pack figures held in
## a pose, in stone, on plinths bedded in the ground (StoneStatue, the catalog's "stone_statue"), wherever a place uses them.

const GAME := preload("res://world/game_root.gd")
## Each statue art and its height on its plinth (feet; the catalog's `feet` where it has one).
const ARTS := {"statue_saint": 9.0, "statue_knight": 7.0, "statue_mother_night": 8.0, "statue_headless": 8.0}

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_every_statue_art_is_the_stone_figure() -> void:
	for art: String in ARTS:
		var look := SetDressing.look_for({"id": "a_statue", "cell": [1, 1], "model": art})
		assert_eq(str(look.get("set_piece", "")), "stone_statue", "%s is a stone figure" % art)
		assert_false((look.get("statue", {}) as Dictionary).is_empty(), "%s says which figure" % art)
	assert_eq(str(SetDressing.look_for({"id": "den_mother_night", "cell": [1, 1]}).get("set_piece", "")), "stone_statue",
		"the den's Mother Night too")
	var headless := SetDressing.look_for({"id": "a_statue", "cell": [1, 1], "model": "statue_headless"})
	for l: Variant in (headless["statue"] as Dictionary)["layers"] as Array:
		assert_false(str(l).ends_with("_head"), "the headless figure wears no head (%s)" % l)


func test_the_monasterys_statues_stand_seated_in_stone_and_true_size() -> void:
	GameState.reset()
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "mon_ground"
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	await get_tree().create_timer(StoneStatue.SETTLE + 0.4).timeout   # (each figure takes its pose, then is held)
	var board := (root.get("view") as LocationView).board
	var loc := Compendium.shared().get_entry("locations", "mon_ground")
	var seen := 0
	for p: Variant in loc.get("props", []) as Array:
		var spec := p as Dictionary
		var art := str(spec.get("model", ""))
		if not ARTS.has(art):
			continue
		var dressing := board.find_child("Dressing_" + str(spec["id"]), true, false)
		assert_true(dressing != null, "%s is placed" % spec["id"])
		var statue := dressing.find_child("Statue", true, false) as Node3D if dressing != null else null
		assert_true(statue != null, "%s is a stone statue" % spec["id"])
		if statue == null:
			continue
		seen += 1
		var figure := statue.find_child("Figure", false, false) as ModelFigure
		assert_true(figure != null and not figure.is_processing(), "%s's figure is held still in its pose" % spec["id"])
		for n in figure.find_children("*", "GeometryInstance3D", true, false):
			assert_true((n as GeometryInstance3D).material_override != null, "%s is stone all over" % spec["id"])
		# Bedded: the plinth reaches below the ground at every corner.
		var foot := INF
		var tip := -INF
		for n in statue.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if not mi.visible or mi.mesh == null:
				continue
			var box := mi.global_transform * mi.get_aabb()
			if mi.name == "Plinth":
				foot = minf(foot, box.position.y)
			tip = maxf(tip, box.end.y)
		var at := Vector2(statue.global_position.x, statue.global_position.z)
		for d: Vector2 in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
			assert_true(foot < board.ground_y(at + d), "%s's plinth is in the ground at its corner %s" % [spec["id"], d])
		var feet := (tip - board.ground_y(at)) * CombatGrid.FEET
		assert_true(absf(feet - float(ARTS[art])) < 1.6, "%s stands about %.0f ft on its plinth (%.1f)" % [spec["id"], ARTS[art], feet])
	assert_true(seen >= 9, "the monastery ground's statues are stone figures (%d)" % seen)
