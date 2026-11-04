extends TestCase
## Standing stones stand in the ground (SeatedStones, the catalog's "stone_ring" set piece): Barrow Hill's ring sits on a sloping
## crown, and every stone in it is bedded under its own foot, none hanging in the air on the low side (Ashwin, 2026-11-03).

const GAME := preload("res://world/game_root.gd")
## The ring's stones: five copies of the menhirs model, three stones each, as the ring was before it was seated.
const RING_STONES := 15

var root: Node


func _open(place: String) -> void:
	GameState.reset()
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = place
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


func _stones(board: ArenaBoard, prop_id: String) -> Array[Node]:
	var dressing := board.find_child("Dressing_" + prop_id, true, false)
	if dressing == null:
		return []
	return dressing.find_children("*", "MeshInstance3D", true, false)


func test_every_stone_of_the_barrow_hill_ring_is_bedded_in_the_ground() -> void:
	await _open("ghostlight_boarding")
	var board := _board()
	var stones := _stones(board, "bd_stone_ring")
	assert_eq(stones.size(), RING_STONES, "the ring keeps all its stones")
	for n in stones:
		var stone := n as MeshInstance3D
		var gap := SeatedStones.bed_gap(board, stone)
		assert_true(gap <= SeatedStones.FOOT - SeatedStones.SINK + 0.01, "%s: no part of its foot stands above the ground (worst %.3f)" % [stone.name, gap])
		# Its lowest point is just under the ground there: bedded, not swallowed.
		var lowest := Vector3(0.0, INF, 0.0)
		for p: Vector3 in SeatedStones.foot_points(board, stone):
			if p.y < lowest.y:
				lowest = p
		var at := Vector2(lowest.x, lowest.z)
		var depth := board.ground_y(at) - lowest.y
		assert_true(depth >= 0.1 and depth <= 0.6, "%s: its base is bedded %.2f under the ground at its foot" % [stone.name, depth])
		# No hole under a stone: each stood on a blocking square whose ground had been left at 0, a pit five levels deep in
		# the hill's crown (the stones hung over it). The ground at its foot is the hill's, as high as the ground round it.
		var round_ := 0.0
		for d: Vector2 in [Vector2(1.5, 0.0), Vector2(-1.5, 0.0), Vector2(0.0, 1.5), Vector2(0.0, -1.5)]:
			round_ += board.ground_y(at + d) / 4.0
		assert_true(absf(board.ground_y(at) - round_) < 1.0, "%s: the ground under it (%.2f) is the hill round it (%.2f), not a pit" % [stone.name, board.ground_y(at), round_])


func test_the_shadestone_sanctuarys_standing_stones_stand_in_the_ground() -> void:
	await _open("mm_shadestone_sanctuary")
	var board := _board()
	var loc := Compendium.shared().get_entry("locations", "mm_shadestone_sanctuary")
	var seen := 0
	for p: Variant in loc.get("props", []) as Array:
		var spec := p as Dictionary
		if str(spec.get("model", "")) != "standing_stones":
			continue
		for n in _stones(board, str(spec["id"])):
			seen += 1
			var gap := SeatedStones.bed_gap(board, n as MeshInstance3D)
			assert_true(gap <= SeatedStones.FOOT - SeatedStones.SINK + 0.01, "%s: no part of its foot stands above the ground (worst %.3f)" % [spec["id"], gap])
	assert_true(seen >= 9, "the sanctuary's standing stones are 3D pieces (%d)" % seen)
