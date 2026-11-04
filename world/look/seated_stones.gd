class_name SeatedStones
extends RefCounted
## Standing stones bedded in the ground they stand on (the catalog's "stone_ring" set piece): the piece is stood as the catalog
## would stand it, then every stone in it is dropped on its own to the lowest ground under its foot and sunk a little more, as
## real menhirs are bedded. One rigid piece on a slope (Barrow Hill's ring, Ashwin 2026-11-03) left the downhill stones hanging
## in the air; each stone seated by itself sits on any slope.

## How deep a stone's lowest point is bedded below the lowest ground under its foot (units, 5 ft).
const SINK := 0.2
## How high above a stone's lowest point its foot is measured (units): the ground is sampled under every point of the stone
## that low.
const FOOT := 0.25


## Stands the catalog's piece for `art` over the prop's squares and seats each stone. Null when the art has no 3D model.
static func build(board: ArenaBoard, root: Node3D, art: String, cell: Vector2i, spec: Dictionary, look: Dictionary) -> Node3D:
	var model := ModelPiece.for_art(board, art, ModelPiece.hash_cell(cell))
	if model == "":
		return null
	var holder := ModelPiece.stand(board, root, model, art, cell, null, clampf(float(spec.get("scale", 1.0)), 0.25, 8.0),
		SetDressing.facing_yaw(spec), SetDressing.span_centre(board, spec))
	if spec.has("tint"):
		ModelPiece.tint(holder, ModelPiece.tint_colour(str(spec["tint"])))
	if look.has("swap"):
		ModelPiece.swap_surfaces(holder, look["swap"] as Dictionary)
	var under: Dictionary = {}
	for n in holder.find_children("*", "MeshInstance3D", true, false):
		seat(board, n as MeshInstance3D)
		for p: Vector3 in foot_points(board, n as MeshInstance3D):
			under[Vector2i(floori(p.x), floori(p.z))] = true
	# The stones' squares block in the rules (woods squares on a wild map): the trees the board drew there give way to the
	# stones, as they do for a real tree set piece, and come back if the ring goes.
	for c: Vector2i in under:
		if board.grid.in_bounds(c) and board.grid.has_flag(c, CombatGrid.WALL) and not board.door_cells.has(c):
			board.clear_cell(c)
			root.tree_exiting.connect(func() -> void:
				if is_instance_valid(board):
					board.restore_cell(c))
	return holder


## Moves one stone up or down so its lowest point lies SINK below the lowest ground under its foot: the foot is then in the
## ground all round (no point of it more than FOOT - SINK over the ground).
static func seat(board: ArenaBoard, stone: MeshInstance3D) -> void:
	var lowest := INF
	var ground := INF
	for p: Vector3 in foot_points(board, stone):
		lowest = minf(lowest, p.y)
		ground = minf(ground, board.ground_y(Vector2(p.x, p.z)))
	var drop := lowest - ground + SINK
	var parent := stone.get_parent() as Node3D
	stone.position += on_board(board, parent).basis.inverse() * Vector3(0.0, -drop, 0.0)


## How far (units) a stone's foot stands above the ground at its worst point (the point of its foot highest over the ground
## under it): 0 when the foot just touches, negative when the whole foot is sunk. The tests read it too.
static func bed_gap(board: ArenaBoard, stone: MeshInstance3D) -> float:
	var gap := -INF
	for p: Vector3 in foot_points(board, stone):
		gap = maxf(gap, p.y - board.ground_y(Vector2(p.x, p.z)))
	return gap


## The stone's points (on the board) within FOOT of its lowest one.
static func foot_points(board: ArenaBoard, stone: MeshInstance3D) -> PackedVector3Array:
	var xf := on_board(board, stone)
	var points := PackedVector3Array()
	for s in stone.mesh.get_surface_count():
		points.append_array(xf * (stone.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array))
	var lowest := INF
	for p: Vector3 in points:
		lowest = minf(lowest, p.y)
	var out := PackedVector3Array()
	for p: Vector3 in points:
		if p.y <= lowest + FOOT:
			out.append(p)
	return out


## A node's transform on the board (the board's own space, where ground_y is measured), whether or not it is in the tree yet.
static func on_board(board: ArenaBoard, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != board:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
