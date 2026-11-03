class_name TrainSeats
extends RefCounted
## A railway car's seats (the catalog's "train_seats" set piece, on a car's seats prop): every furniture square along the car's
## walls is a red leather seat, the seats of a run in facing pairs (two benches looking at each other across a little table
## of floor, as in an old passenger car), the aisle between the walls left open. Some seats hold a pale passenger: one of
## the ghost figures (art/figures/manifest.json `ghost_passenger_*`, the pack bodies the townsfolk wear, in a ghost's blue
## and see-through), sitting, the same ones in the same seats every visit. They are scenery, not people: nothing to talk to
## or fight. Ashwin (2026-11-03): the passenger car was empty.
##
## The catalog entry's `seats` holds the seat's art (`art`, a settee: a bench with a back), its surfaces (`swap`), how many
## seats in a hundred hold a passenger (`filled`) and the passengers (`ghosts`, figure ids).

## A seated passenger's height (units, 5 ft: a person a little under six feet) and how far into the seat their hips sit from
## its back (units).
const PASSENGER_HEIGHT := 1.12
const SIT_IN := 0.18
## A seated passenger's pelvis joint over the cushion it sits on and in front of the backrest it leans on (units): the joint
## is inside the body, a hand above the seat and a little more than that from the back.
const HIP_ABOVE := 0.07
const HIP_FROM_BACK := 0.13
## How long a passenger is left to take its pose and turn before it is rested on its bench (seconds).
const SETTLE := 0.35


## Seats every furniture square of the car beside a wall under `root`. Returns the number of seats.
static func build(board: ArenaBoard, root: Node3D, loc_id: String, look: Dictionary) -> int:
	var spec := look.get("seats", {}) as Dictionary
	var art := str(spec.get("art", "settee"))
	var model := ModelPiece.for_art(board, art)
	if model == "":
		return 0
	var ghosts := spec.get("ghosts", []) as Array
	var filled := int(spec.get("filled", 0))
	var seats := 0
	_others = {}
	var loc := Compendium.shared().get_entry("locations", loc_id)
	for p: Variant in (loc.get("props", []) as Array) + (loc.get("containers", []) as Array):
		var cell := (p as Dictionary).get("cell", []) as Array
		if cell.size() == 2 and str((p as Dictionary).get("set_piece", "")) == "" and SetDressing.look_for(p as Dictionary).get("set_piece", "") != "train_seats":
			_others[Vector2i(int(cell[0]), int(cell[1]))] = true
	for c: Vector2i in seat_squares(board):
		if _others.has(c):
			continue   # (another prop stands there: a jar of marbles on a seat leaves the seat to it)
		var faces := _faces(board, c)
		var seat := ModelPiece.stand(board, root, model, art, c, null, 1.0, atan2(float(faces.x), 0.0))
		seat.name = "Seat_%d_%d" % [c.x, c.y]
		seat.set_meta("seat", c)
		if spec.has("swap"):
			ModelPiece.swap_surfaces(seat, spec["swap"] as Dictionary)
		seats += 1
		var pick := absi(hash("%s|%d|%d" % [loc_id, c.x, c.y]))
		if not ghosts.is_empty() and pick % 100 < filled:
			var box := _box(board, seat)   # (a seat against a wall stands back in its square, its back away from the seat it faces)
			var back := box.get_center().x - float(faces.x) * box.size.x / 2.0
			_seat_ghost(root, str(ghosts[(pick / 100) % ghosts.size()]), seat, Vector3(back + float(faces.x) * SIT_IN, seat.position.y, box.get_center().z), faces)
	return seats


static var _others: Dictionary = {}


## The car's furniture squares that are seats: low squares beside the car's long walls (north and south).
static func seat_squares(board: ArenaBoard) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in board.grid.depth:
		for x in board.grid.width:
			var c := Vector2i(x, y)
			if not board.grid.has_flag(c, CombatGrid.LOW):
				continue
			if board.grid.has_flag(c + Vector2i(0, -1), CombatGrid.WALL) or board.grid.has_flag(c + Vector2i(0, 1), CombatGrid.WALL):
				out.append(c)
	return out


## Which way a seat looks along the car (+x or -x): the seats of a run of furniture squares pair off from its west end, the
## west one of each pair looking east at the east one; a seat left over looks at its neighbour in the run.
static func _faces(board: ArenaBoard, c: Vector2i) -> Vector2i:
	var start := c.x
	while board.grid.has_flag(Vector2i(start - 1, c.y), CombatGrid.LOW):
		start -= 1
	var end := c.x
	while board.grid.has_flag(Vector2i(end + 1, c.y), CombatGrid.LOW):
		end += 1
	var i := c.x - start
	if end == start:
		return Vector2i(1, 0) if board.grid.has_flag(c + Vector2i(1, 0), CombatGrid.WALL) == false else Vector2i(-1, 0)
	if i % 2 == 0:
		return Vector2i(1, 0) if c.x < end else Vector2i(-1, 0)
	return Vector2i(-1, 0)


## The seat's meshes' box on the board.
static func _box(board: ArenaBoard, seat: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in seat.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := SeatedStones.on_board(board, mi) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## A ghost passenger sitting on `seat`, looking along `faces`: stood near the seat at first, then, once it has taken its
## sitting pose and turned, rested on the bench as the bench is made (_rest_on).
static func _seat_ghost(root: Node3D, figure: String, seat: Node3D, at: Vector3, faces: Vector2i) -> void:
	if not FigureModels.has(figure):
		return
	var ghost := DirectionalSprite.create(FigureModels.frames(figure), PASSENGER_HEIGHT) as ModelFigure
	ghost.name = "Passenger_" + figure
	ghost.set_meta("passenger", figure)
	ghost.set_meta("bench", seat)
	ghost.facing = Vector3(float(faces.x), 0.0, 0.0)
	ghost.position = at
	root.add_child(ghost)
	var settle := func() -> void:
		await ghost.get_tree().create_timer(SETTLE).timeout
		if is_instance_valid(ghost) and is_instance_valid(seat):
			_rest_on(ghost, seat, faces)
	if ghost.is_inside_tree():
		settle.call()
	else:
		ghost.tree_entered.connect(settle, CONNECT_ONE_SHOT)


## Rests a seated ghost on its bench as the bench is made: rays find the seat's top and the backrest's face, and the ghost
## is moved so its hips are on the cushion, its back against the backrest (the pose's own legs then reach for the floor).
## The seat's top and the backrest's face are kept on the ghost (meta `seat_top`, `back_face`) for the tests.
static func _rest_on(ghost: ModelFigure, seat: Node3D, faces: Vector2i) -> void:
	var hip := hip_of(ghost)
	if hip == Vector3.INF:
		return
	var box := AABB()
	var first := true
	for n in seat.find_children("*", "MeshInstance3D", true, false):
		var b := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var f := float(faces.x)
	var mid := box.get_center()
	# The seat's top: straight down onto the bench a little in front of its middle, below the backrest's top.
	var from := Vector3(mid.x + f * box.size.x * 0.2, box.end.y + 0.05, mid.z)
	var down := ModelPiece.hit(seat, from, Vector3.DOWN)
	var top := from.y - down if down < INF else box.position.y + box.size.y * 0.45
	# The backrest's face: back along the bench from in front of it, a hand above the seat.
	var front := Vector3(mid.x + f * (box.size.x / 2.0 + 0.1), top + 0.25, mid.z)
	var back_hit := ModelPiece.hit(seat, front, Vector3(-f, 0.0, 0.0))
	var back := front.x - f * back_hit if back_hit < INF else mid.x - f * box.size.x / 2.0
	ghost.set_meta("seat_top", top)
	ghost.set_meta("back_face", back)
	ghost.global_position += Vector3(back + f * HIP_FROM_BACK, top + HIP_ABOVE, mid.z) - hip


## Where a figure's hips (its pelvis joint) are now, or INF.
static func hip_of(ghost: ModelFigure) -> Vector3:
	var sk := ghost.find_children("*", "Skeleton3D", true, false)
	if sk.is_empty():
		return Vector3.INF
	var skel := sk[0] as Skeleton3D
	var b := FigureModels.bone(skel, "Hips", FigureModels.rig_bones(ghost.art_id))
	if b < 0:
		return Vector3.INF
	return skel.global_transform * skel.get_bone_global_pose(b).origin
