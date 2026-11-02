extends TestCase
## The gnarled EZ-Tree set pieces (tools/art/ez_setpieces.mjs, art/plants/ez_setpiece): the Pine Barrens' dead_tree props, the
## raven oak and the lookout trees stand as real trees in the Modern finish, through the catalog's "real_tree" set piece.

const GAME := preload("res://world/game_root.gd")

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "hb_pine_barrens"
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _board() -> ArenaBoard:
	return (root.get("view") as LocationView).board


func _real(node: Node, prefix: String) -> Array[Node]:
	return node.find_children("Real_" + prefix + "*", "Node3D", true, false)


func test_the_pine_barrens_dead_trees_are_gnarled_ez_trees() -> void:
	var loc := Compendium.shared().get_entry("locations", "hb_pine_barrens")
	var dead := 0
	for p: Variant in loc.get("props", []) as Array:
		if str((p as Dictionary).get("model", "")).begins_with("dead_tree"):
			dead += 1
	assert_true(dead >= 4, "the map has dead_tree props (%d)" % dead)
	assert_eq(_real(_board(), "ez_sp_dead_").size(), dead, "each dead_tree prop stands as one of the EZ-Tree dead trees")


func test_the_raven_oak_and_the_lookout_trees_are_ez_trees() -> void:
	var board := _board()
	for pair: Array in [["raven_oak", "ez_sp_raven_oak"], ["ambush_lookout_tree", "ez_sp_lookout"], ["lzt_climbing_pine", "ez_sp_lookout"]]:
		var node := SetDressing.place(board, {"id": pair[0], "kind": "decor", "cell": [2, 2], "label": "a tree"})
		assert_true(node != null, "%s is placed" % pair[0])
		assert_eq(_real(node, str(pair[1])).size(), 1, "%s is the %s tree" % [pair[0], pair[1]])
		var tree := _real(node, str(pair[1]))[0] as Node3D
		assert_true(SeeThrough.marked(tree.find_children("*", "MeshInstance3D", true, false)[0] as GeometryInstance3D), "%s fades where it hides the party" % pair[0])
		node.queue_free()


func test_the_story_trees_stay_built_in_code() -> void:
	var board := _board()
	var node := SetDressing.place(board, {"id": "ct_tree", "kind": "decor", "cell": [3, 3], "label": "the crooked tree"})
	assert_true(node != null, "the Crooked Tree is placed")
	assert_eq(_real(node, "ez_sp_").size(), 0, "the Crooked Tree is not an EZ-Tree tree")
	node.queue_free()
