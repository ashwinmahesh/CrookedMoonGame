extends TestCase
## The scarecrow Ashwin picked (2026-11-03): a post, a peasant's old clothes hung arms out, straw and a carved pumpkin head
## (PumpkinScarecrow, the catalog's "pumpkin_scarecrow"), wherever a place has a scarecrow; sunk in the ground, about seven
## feet tall, and no two in a field leaning quite alike.

const GAME := preload("res://world/game_root.gd")

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_the_scarecrow_art_is_the_pumpkin_scarecrow() -> void:
	for spec: Dictionary in [{"id": "a_scarecrow", "cell": [1, 1], "model": "scarecrow"}, {"id": "scarecrow_mid", "cell": [1, 1]},
			{"id": "a_scarecrow", "cell": [1, 1], "model": "scarecrow_stitched"}]:
		assert_eq(str(SetDressing.look_for(spec).get("set_piece", "")), "pumpkin_scarecrow", "%s is the pumpkin scarecrow" % spec)
	assert_ne(str(SetDressing.look_for({"id": "nm_feast_guest_0", "cell": [1, 1], "model": "scarecrow_stitched"}).get("set_piece", "")),
		"pumpkin_scarecrow", "the masked wedding guests stay masked guests")


func test_barrow_hills_scarecrow_stands_sunk_and_true_size() -> void:
	GameState.reset()
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "ghostlight_boarding"
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var board := (root.get("view") as LocationView).board
	var crows: Array[Node3D] = []
	var one := board.find_child("Dressing_bd_scarecrow", true, false)
	assert_true(one != null and one.find_child("Scarecrow", true, false) != null, "the graves' scarecrow is the pumpkin scarecrow")
	crows.append(one.find_child("Scarecrow", true, false) as Node3D)
	for c: Vector2i in [Vector2i(6, 14), Vector2i(7, 15)]:
		var more := SetDressing.place(board, {"id": "test_crow_%d" % c.x, "cell": [c.x, c.y], "model": "scarecrow", "kind": "decor"})
		crows.append(more.find_child("Scarecrow", true, false) as Node3D)
	for s in crows:
		var foot := INF
		var tip := -INF
		for n in s.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var box := mi.global_transform * mi.get_aabb()
			if mi.name == "Post":
				foot = minf(foot, box.position.y)
			tip = maxf(tip, box.end.y)
		var ground := board.ground_y(Vector2(s.global_position.x, s.global_position.z))
		assert_true(foot < ground - 0.1, "%s's post is sunk in the ground (%.2f under it)" % [s.get_parent().name, ground - foot])
		var feet := (tip - ground) * CombatGrid.FEET
		assert_true(feet > 6.0 and feet < 8.5, "%s stands about seven feet (%.1f)" % [s.get_parent().name, feet])
	assert_false(crows[1].rotation.is_equal_approx(crows[2].rotation), "two scarecrows don't lean alike")
	var head_1 := crows[1].find_child("Head", false, false) as Node3D
	var head_2 := crows[2].find_child("Head", false, false) as Node3D
	assert_false(head_1.rotation.is_equal_approx(head_2.rotation), "nor tip their heads alike")
