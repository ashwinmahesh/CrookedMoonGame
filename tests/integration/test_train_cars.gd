extends TestCase
## The Ghostlight Express's cars dressed as what they are (Ashwin, 2026-11-03): every prop drawn as the thing its label names
## (a painting a painting, a trunk a trunk: the cars' "case" props had all been glass-fronted cabinets, the seascape among
## them), the Lounge Car's seascape a framed picture on the wall, and the Passenger Car's seats in facing pairs with pale
## passengers in some, the aisle still open from the boarding door to the far door.

const GAME := preload("res://world/game_root.gd")
const CARS: Array[String] = ["ghostlight_g1_passenger", "ghostlight_g2_sleeper", "ghostlight_g3_lounge", "ghostlight_g4_dining",
	"ghostlight_g5_mail", "ghostlight_g6_baggage", "ghostlight_g7_circus", "ghostlight_g8_tender", "ghostlight_wreckage", "ghostlight_boarding"]
## Furniture and fittings that are never a picture, and the art a picture may be drawn with.
const PICTURES: Array[String] = ["painting", "painting_row", "family_portrait", "portrait_couple", "portrait_jester", "portrait_tatyana"]
## Words in a label and the art that can't stand for it: the case for a few more mismatches found in the audit
## (docs/tasks/ghostlight_props_audit.md).
const NOT_FOR := {
	"painting": ["cabinet_glass", "letters_table"], "picture": ["cabinet_glass", "letters_table"],
	"trunk": ["cabinet_glass"], "luggage": ["cabinet_glass"], "chest": ["cabinet_glass"], "bag": ["cabinet_glass", "refuse_mound"],
	"crate": ["cabinet_glass"], "tank": ["cabinet_glass"], "silverware": ["oil_lamp"], "banner": ["letters_table"],
}

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open(place: String, found: Array[String] = []) -> ArenaBoard:
	GameState.reset()
	for id in found:
		(GameState.story.loc_state(place)["found"] as Dictionary)[id] = true
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = place
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	return (root.get("view") as LocationView).board


func test_every_train_prop_is_drawn_as_what_its_label_names() -> void:
	for place in CARS:
		var loc := Compendium.shared().get_entry("locations", place)
		for p: Variant in (loc.get("props", []) as Array) + (loc.get("containers", []) as Array):
			var spec := p as Dictionary
			var look := SetDressing.look_for(spec, loc.get("containers", []).has(p))
			var art := str(look.get("art", ""))
			var label := str(spec.get("label", "")).to_lower()
			for word: String in NOT_FOR:
				if label.contains(word):
					assert_false(art in (NOT_FOR[word] as Array), "%s (%s) is not drawn as %s" % [spec["id"], label, art])
			if label.contains("painting") or label.contains("picture"):
				assert_true(art in PICTURES or str(look.get("set_piece", "")) == "framed_picture",
					"%s (%s) is drawn as a picture, not %s" % [spec["id"], label, art])


func test_the_seascape_hangs_framed_on_the_lounge_wall() -> void:
	var board := await _open("ghostlight_g3_lounge", ["g3_seascape"] as Array[String])   # (a search spot shows once found)
	var dressing := board.find_child("Dressing_g3_seascape", true, false)
	assert_true(dressing != null, "the seascape is placed")
	var pictures: Array[Node] = []
	if dressing != null:
		pictures = dressing.find_children("Picture", "Node3D", true, false)
	assert_eq(pictures.size(), 1, "it is one framed picture")
	if pictures.is_empty():
		return
	var pic := pictures[0] as Node3D
	assert_true(str(pic.get_meta("picture")).ends_with("winslow_homer_rocky_coast_maine.jpg"), "the picture is the rocky coast")
	var canvas := (pic.find_child("Canvas", false, false) as MeshInstance3D)
	var size := (canvas.mesh as QuadMesh).size
	assert_true(size.x > 0.9 and size.x < 1.5 and size.y > 0.4, "a true-size painting, about 6 ft by 3 (%.2f x %.2f units)" % [size.x, size.y])
	assert_true(pic.global_position.y - board.floor_y(Vector2i(4, 1)) > 0.8, "it hangs at eye height on the wall")
	assert_true(dressing.find_children("*", "MeshInstance3D", true, false).size() <= 5, "and nothing else is drawn for it")


func test_the_passenger_car_has_facing_seats_and_an_open_aisle() -> void:
	var board := await _open("ghostlight_g1_passenger")
	var seats: Array[Node] = []
	var passengers := 0
	for n in board.find_children("*", "Node3D", true, false):
		if n.has_meta("seat"):
			seats.append(n)
		if n.has_meta("passenger"):
			passengers += 1
	assert_true(seats.size() >= TrainSeats.seat_squares(board).size() - 2, "the furniture squares along the walls are seats")
	assert_true(seats.size() >= 20, "rows of seats down both sides (%d)" % seats.size())
	assert_true(passengers > 0 and passengers < seats.size(), "pale passengers in some of the seats (%d of %d)" % [passengers, seats.size()])
	for s in seats:
		var c := s.get_meta("seat") as Vector2i
		assert_true(board.grid.has_flag(c, CombatGrid.LOW), "a seat at %s stands on a furniture square, off the walked floor" % c)
	# The same passengers in the same seats every visit.
	var first := _passengers(board)
	root.queue_free()
	await _frames(1)
	var again := await _open("ghostlight_g1_passenger")
	assert_eq(_passengers(again), first, "the passengers sit where they sat before")
	# The aisle: open floor from where the party comes aboard to the door on.
	var loc := Compendium.shared().get_entry("locations", "ghostlight_g1_passenger")
	var from := Vector2i(int((loc["spawns"]["from_boarding"] as Array)[0]), int((loc["spawns"]["from_boarding"] as Array)[1]))
	var to := Vector2i(int((loc["exits"][0]["cell"] as Array)[0]), int((loc["exits"][0]["cell"] as Array)[1]))
	assert_true(_open_path(again, from, to), "an open aisle runs from %s to the door at %s" % [from, to])


func _passengers(board: ArenaBoard) -> Dictionary:
	var out := {}
	for n in board.find_children("*", "Node3D", true, false):
		if n.has_meta("passenger"):
			out["%.2f,%.2f" % [(n as Node3D).global_position.x, (n as Node3D).global_position.z]] = str(n.get_meta("passenger"))
	return out


## Whether open floor (no wall, no furniture) joins `a` to `b`, the exit square itself open to step on.
func _open_path(board: ArenaBoard, a: Vector2i, b: Vector2i) -> bool:
	var seen := {a: true}
	var todo: Array[Vector2i] = [a]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		if c == b:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n) or not board.grid.in_bounds(n):
				continue
			if n != b and (board.grid.has_flag(n, CombatGrid.WALL) or board.grid.has_flag(n, CombatGrid.LOW)):
				continue
			seen[n] = true
			todo.append(n)
	return false


func test_the_cars_furniture_squares_stay_furniture() -> void:
	# A '=' square holding only small decor is opened to walk on (LocationBuilder.SMALL_DECOR): the cars' own furniture and
	# their props on '=' squares are never small things, so no walked square changes (the jar of marbles always was one).
	var sets := SetDressing.catalog().get("low_cover", {}) as Dictionary
	for key: String in sets:
		if key.begins_with("ghostlight_"):
			for art: Variant in sets[key] as Array:
				assert_false(str(art) in LocationBuilder.SMALL_DECOR, "%s's furniture %s is not a small thing walked over" % [key, art])
	for place in CARS:
		var loc := Compendium.shared().get_entry("locations", place)
		var rows := (loc["map"] as Dictionary)["rows"] as Array
		for p: Variant in loc.get("props", []) as Array:
			var spec := p as Dictionary
			var cell := spec["cell"] as Array
			if str(rows[int(cell[1])])[int(cell[0])] != "=" or spec["id"] == "g1_marble_jar":
				continue
			var art := str(SetDressing.look_for(spec).get("art", ""))
			assert_false(art in LocationBuilder.SMALL_DECOR, "%s on a furniture square is not a small thing (%s)" % [spec["id"], art])


func test_the_ghost_passengers_sit_on_their_benches() -> void:
	var board := await _open("ghostlight_g1_passenger")
	await get_tree().create_timer(TrainSeats.SETTLE + 0.5).timeout   # (each takes its pose, then is rested on its bench)
	var seen := 0
	for n in board.find_children("*", "Node3D", true, false):
		if not n.has_meta("passenger"):
			continue
		var ghost := n as ModelFigure
		seen += 1
		assert_true(ghost.has_meta("seat_top"), "%s was rested on its bench" % ghost.name)
		if not ghost.has_meta("seat_top"):
			continue
		var bench := ghost.get_meta("bench") as Node3D
		var f := signf(ghost.facing.x)
		var hip := TrainSeats.hip_of(ghost)
		var above := hip.y - float(ghost.get_meta("seat_top"))
		assert_true(above > 0.02 and above < 0.14, "%s's hips rest on the cushion (%.3f above it)" % [ghost.name, above])
		var from_back := (hip.x - float(ghost.get_meta("back_face"))) * f
		assert_true(from_back > 0.04 and from_back < 0.25, "%s sits back against the backrest, not in it (%.3f)" % [ghost.name, from_back])
		# The feet: the pose's lowest bones, near the floor the bench stands on.
		var sk := ghost.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var floor_y := bench.global_position.y
		for foot: String in ["LeftFoot", "RightFoot"]:
			var b := FigureModels.bone(sk, foot, FigureModels.rig_bones(ghost.art_id))
			var at := sk.global_transform * sk.get_bone_global_pose(b).origin
			assert_true(absf(at.y - floor_y) < 0.16, "%s's %s is near the floor (%.3f off it)" % [ghost.name, foot, at.y - floor_y])
	assert_true(seen > 0, "there are passengers to check")
