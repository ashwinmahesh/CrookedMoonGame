extends TestCase
## The Ghostlight Express at Barrow Hill (GhostlightTrain, the catalog's "ghostlight_train"): one train on one line, coupled
## end to end from the car the party boards to the engine, on rails standard gauge apart, its wheels on them, standing on its
## bed, with nothing of it on a square the party walks (Ashwin, 2026-11-03).

const GAME := preload("res://world/game_root.gd")
## Standard gauge, 4 ft 8.5 in between the rail heads' inner faces (units, 5 ft).
const GAUGE := 4.708 / 5.0

var root: Node


func before_each() -> void:
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


## The cars, rear first (they are laid west to east).
func _cars(board: ArenaBoard) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in board.find_children("*", "Node3D", true, false):
		if n.has_meta("car"):
			out.append(n as Node3D)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	return out


## A node's meshes' points on the board, those whose name passes `keep`.
func _points(node: Node3D, keep: Callable) -> PackedVector3Array:
	var out := PackedVector3Array()
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not keep.call(mi):
			continue
		for s in mi.mesh.get_surface_count():
			out.append_array(mi.global_transform * (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array))
	return out


func _rail_top(board: ArenaBoard) -> float:
	var top := -INF
	for t in board.find_children("Track", "Node3D", true, false):
		for p: Vector3 in _points(t as Node3D, func(_m: MeshInstance3D) -> bool: return true):
			top = maxf(top, p.y)
	return top


func test_it_is_one_train_coupled_end_to_end() -> void:
	var board := _board()
	var cars := _cars(board)
	assert_eq(cars.size(), 9, "the rear car, six more cars, the tender and the engine")
	assert_eq(str(cars[0].get_meta("car")), "carriage", "the car the party boards is the rear one")
	assert_eq(str(cars[cars.size() - 1].get_meta("car")), "engine", "the engine leads")
	assert_eq(str(cars[0].get_parent().name), "Dressing_bd_passenger_car", "the rear car is the boarding car's prop")
	var z := cars[0].global_position.z
	for i in cars.size():
		assert_true(absf(cars[i].global_position.z - z) < 0.01, "%s stands on the line" % cars[i].name)
		if i == 0:
			continue
		var gap := (cars[i].get_meta("span") as Vector2).x + cars[i].global_position.x \
			- ((cars[i - 1].get_meta("span") as Vector2).y + cars[i - 1].global_position.x)
		assert_true(gap > 0.0 and gap < 0.5, "%s is coupled to the car behind it (%.2f between them)" % [cars[i].name, gap])
	# The way aboard is at the rear car's side.
	var span := cars[0].get_meta("span") as Vector2
	assert_true(21.0 >= cars[0].global_position.x + span.x and 22.0 <= cars[0].global_position.x + span.y,
		"the boarding square's side of the shelf is the rear car's")


func test_the_rails_are_standard_gauge_and_the_wheels_on_them() -> void:
	var board := _board()
	var track := board.find_child("Track", true, false) as Node3D
	assert_true(track != null, "the line has rails")
	var z := _cars(board)[0].global_position.z
	var top := _rail_top(board)
	# The rail heads: the track's highest points, either side of the line.
	var inner := INF
	for p: Vector3 in _points(track, func(_m: MeshInstance3D) -> bool: return true):
		if p.y > top - 0.02:
			inner = minf(inner, absf(p.z - z))
	assert_true(absf(inner * 2.0 - GAUGE) < 0.08, "the rail heads are standard gauge apart (%.2f, want %.2f)" % [inner * 2.0, GAUGE])
	for car in _cars(board):
		var wheels := _points(car, func(m: MeshInstance3D) -> bool: return m.has_meta("wheel"))
		assert_true(not wheels.is_empty(), "%s has wheels" % car.name)
		var foot := INF
		var reach := 0.0
		for p: Vector3 in wheels:
			foot = minf(foot, p.y)
			reach = maxf(reach, absf(p.z - z))
		assert_true(absf(foot - top) < 0.04, "%s: its wheels stand on the rails (%.3f over them)" % [car.name, foot - top])
		assert_true(reach >= inner, "%s: its wheels reach the rails (%.2f out, the rails %.2f)" % [car.name, reach, inner])


func test_nothing_of_the_train_stands_on_a_walked_square() -> void:
	var board := _board()
	# The trestle's posts stand only on blocked squares; the gully under it stays open to walk.
	for n in board.find_children("Timber", "MeshInstance3D", true, false):
		var post := n as MeshInstance3D
		if (post.mesh as BoxMesh).size.y < 1.0 or absf(post.rotation.x) > 0.01:
			continue
		var c := Vector2i(floori(post.global_position.x), floori(post.global_position.z))
		if board.grid.in_bounds(c):
			assert_true(board.grid.has_flag(c, CombatGrid.WALL), "a trestle post at %s stands on a blocked square" % c)
	# The cars on the map stand over blocked squares only, or high over the gully; the way aboard is at the rear car's side.
	var top := _rail_top(board)
	var aboard: Array[Vector2i] = []
	for e: Variant in (root.get("view") as LocationView).loc.get("exits", []) as Array:
		aboard.append(Vector2i(int(((e as Dictionary)["cell"] as Array)[0]), int(((e as Dictionary)["cell"] as Array)[1])))
	for car in _cars(board):
		var span := car.get_meta("span") as Vector2
		for x in range(int(ceilf(car.global_position.x + span.x + 0.05)), int(ceilf(car.global_position.x + span.y - 0.05))):
			for zz: int in [9, 10]:
				var c := Vector2i(x, zz)
				if not board.grid.in_bounds(c) or board.grid.has_flag(c, CombatGrid.WALL) or c in aboard:
					continue
				assert_true(board.ground_y(Vector2(x + 0.5, zz + 0.5)) < top - 2.5, "%s over open square %s is high over the gully" % [car.name, c])


func test_the_line_runs_on_its_bed_past_the_map() -> void:
	var board := _board()
	var terrain := board.find_child("Terrain3D", true, false) as Terrain3D
	if terrain == null:
		return   # (Classic finish: no land past the map)
	var cars := _cars(board)
	var z := cars[0].global_position.z
	var top := _rail_top(board)
	var x := float(board.grid.width) + 1.0
	while x < cars[cars.size() - 1].global_position.x + 4.0:
		var h := terrain.data.get_height(Vector3(x, 0.0, z))
		assert_true(h < top and h > top - 0.45, "the rail bed at x %.0f carries the ties (ground %.2f, rail top %.2f)" % [x, h, top])
		x += 2.0
