class_name GhostlightTrain
extends RefCounted
## The Ghostlight Express waiting at Barrow Hill (the catalog's "ghostlight_train" set piece, on the boarding car's prop): one
## long train on one line, the rear car the party boards and seven more cars, the tender and the engine coupled on ahead of
## it, all on rails laid standard gauge apart, the wheels on the rails, the rails on a ballast bank that follows the ground,
## and a timber trestle where the line crosses the gully east of the shelf. Ashwin (2026-11-03): the tracks were tiny, the
## train didn't sit on them, and the car the party boards stood apart from the engine. The cars ahead run on past the map's
## edge, where TerrainPlace lays the rail bed (art/overworld/terrain_places.json `rail`).
##
## The catalog entry's `train` holds the line: `z` (the line's middle, units), `rear` (the rear car's back end, x), `rails`
## ([from x, to x]), `bed` (the square whose ground the rail bed is level with), `trestle` (the x of each timber bent), and
## `cars` (rear first: "carriage", "wagon", "tender", "engine").

const PACK := "res://art/sourced/quaternius_modular_train_pack/"
## The pack's straight track at this size lays its rail heads 0.94 units (4 ft 8.5 in, standard gauge) apart, its ties 7 ft long.
const TRACK_SCALE := 1.18
## The pack track's ties' underside and its rails' top (pack units).
const TRACK_FOOT := -0.0715
const RAIL_TOP := 0.0715
## Between one car's end and the next (units): the couplers' reach.
const GAP := 0.35
## How deep the ballast bank under the ties is where the ground is level (units), and how wide its top.
const BALLAST := 0.12
const BALLAST_TOP := 1.25

## Each kind of car: the pack's model, its size (x along the line, y, z across; the cars are short to stand on the shelf's
## six squares, with a car's true height and width) and its surfaces in the game's colours. `turn`: it faces the other way
## (the engine's chimney leads, east).
const KINDS := {
	"carriage": {"file": "Locomotive Passenger Carriage.glb", "scale": Vector3(0.744, 0.92, 0.97),
		"swap": {"Black": "pal_night", "Windows": "glow_candle", "LightWood": "pal_walnut", "Red": "pal_blood_deep", "Green": "pal_bog",
			"DarkGreen": "pal_bog_deep", "Grey": "pal_stone_deep", "Steel": "pal_pewter", "Wood": "pal_walnut"}},
	"wagon": {"file": "Locomotive Wagon.glb", "scale": Vector3(0.744, 0.92, 0.97),
		"swap": {"Black": "pal_night", "LightWood": "pal_walnut", "Grey": "pal_stone_deep", "DarkWood": "pal_umber"}},
	"tender": {"file": "Cargo Train Coal Conta.glb", "scale": Vector3(0.62, 0.86, 0.9),
		"swap": {"Black": "pal_night", "Base": "pal_night", "Container": "pal_night_deep", "Coal": "glow_moon_green"}},
	"engine": {"file": "Locomotive Front.glb", "scale": Vector3(0.9, 0.8, 0.72), "turn": true,
		"swap": {"Black": "pal_night", "Grey": "pal_pewter"}},
}
## The rails, the ties, the ballast and the trestle's timber in their own CC0 textures (art/sourced/polyhaven_*,
## tools/art/fetch_prop_textures.py).
const TRACK_SWAP := {"Steel": "tex_props__track_rail", "Wood": "tex_props__track_sleeper"}
const BALLAST_SURFACE := "tex_props__track_ballast"
const TIMBER_SURFACE := "tex_props__track_sleeper"

static var _parts: Dictionary = {}


## Builds the train. The rear car stands under `root` (the boarding car's prop: it is what the party looks at and opens round
## them); the rest of the line stands on the board beside it and goes with it. Returns the rear car, or null.
static func build(board: ArenaBoard, root: Node3D, look: Dictionary) -> Node3D:
	var line := look.get("train", {}) as Dictionary
	var cars := line.get("cars", []) as Array
	if cars.is_empty():
		return null
	var z := float(line.get("z", 0.0))
	var bed_at := line.get("bed", [0, 0]) as Array
	var bed := board.ground_y(Vector2(float(bed_at[0]) + 0.5, float(bed_at[1]) + 0.5))
	var rail_top := bed + (RAIL_TOP - TRACK_FOOT) * TRACK_SCALE
	var rest := Node3D.new()
	rest.name = "GhostlightTrain"
	board.add_child(rest)
	root.tree_exiting.connect(func() -> void:
		if is_instance_valid(rest):
			rest.queue_free())
	var rails := line.get("rails", [0.0, 0.0]) as Array
	_lay_track(board, rest, float(rails[0]), float(rails[1]), z, bed)
	_trestle(board, rest, line.get("trestle", []) as Array, z, bed)
	var at := float(line.get("rear", 0.0))
	var rear: Node3D = null
	for i in cars.size():
		var car := _car(str(cars[i]), rail_top)
		if car == null:
			continue
		car.name = "Car_%d_%s" % [i + 1, cars[i]]   # (rear first)
		var span := car.get_meta("span") as Vector2   # (its body's x from and to, as it stands)
		car.position = Vector3(at - span.x, car.position.y, z)
		(root if i == 0 else rest).add_child(car)
		SeeThrough.mark(car)
		if i == 0:
			rear = car
		else:
			rest.add_child(_coupler(Vector3(at - GAP / 2.0, rail_top + 0.45, z)))
		at += span.y - span.x + GAP
	return rear


## One car on the rails: the pack's model at its kind's size, its wheels widened onto the rails, standing with its wheels' foot
## on the rails' top. Its meta `span` is its body's x reach about its middle.
static func _car(kind: String, rail_top: float) -> Node3D:
	if not KINDS.has(kind):
		return null
	var info := KINDS[kind] as Dictionary
	var sc := info["scale"] as Vector3
	var car := _model(str(info["file"]), info["swap"] as Dictionary)
	car.name = "Car_" + kind
	car.set_meta("car", kind)
	car.scale = sc
	if bool(info.get("turn", false)):
		car.rotation.y = PI
	var wheel_foot := INF
	var lo := INF
	var hi := -INF
	for n in car.get_children():
		var mi := n as MeshInstance3D
		if str(mi.name).contains("Wheel"):
			for s in mi.mesh.get_surface_count():
				for p: Vector3 in mi.transform * (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					wheel_foot = minf(wheel_foot, p.y)
			# (the pack's wheels sit over its rails at the pack's own size: across the line they keep the rails' size)
			mi.transform = Transform3D(Basis.from_scale(Vector3(1.0, 1.0, TRACK_SCALE / sc.z)), Vector3.ZERO) * mi.transform
			mi.set_meta("wheel", true)
		else:
			var box := mi.transform * mi.mesh.get_aabb()
			lo = minf(lo, box.position.x)
			hi = maxf(hi, box.end.x)
	car.position.y = rail_top - wheel_foot * sc.y
	var span := Vector2(lo * sc.x, hi * sc.x)
	if bool(info.get("turn", false)):
		span = Vector2(-hi * sc.x, -lo * sc.x)
	car.set_meta("span", span)
	return car


## The pack's straight track end to end along the line, its ties on the bed, with the ballast bank under them.
static func _lay_track(board: ArenaBoard, parent: Node3D, from_x: float, to_x: float, z: float, bed: float) -> void:
	var piece := 18.0 * TRACK_SCALE
	var x := from_x
	while x < to_x:
		var t := _model("Railway Track Straight.glb", TRACK_SWAP)
		t.name = "Track"
		t.set_meta("track", true)
		t.scale = Vector3.ONE * TRACK_SCALE
		t.position = Vector3(x + piece / 2.0, bed - TRACK_FOOT * TRACK_SCALE, z)
		parent.add_child(t)
		x += piece
	var ballast := _ballast(board, from_x, minf(to_x, float(board.grid.width)), z, bed)
	if ballast != null:
		parent.add_child(ballast)


## The ballast bank inside the map: its top level with the bed, its sides running down to the ground beside it, so the ties
## never hang over a dip; over the gully (ground far below) the trestle carries the line instead.
static func _ballast(board: ArenaBoard, from_x: float, to_x: float, z: float, bed: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := BALLAST_TOP / 2.0
	var any := false
	var x := from_x
	while x < to_x:
		var x2 := minf(x + 0.5, to_x)
		var drops := [_drop(board, x, z, bed), _drop(board, x2, z, bed)]
		if drops[0] < 1.2 and drops[1] < 1.2:
			any = true
			var ring: Array = []
			for k in 2:
				var px := x if k == 0 else x2
				var foot := half + 0.5 + float(drops[k]) * 1.2   # (a bank's sides at a gravel heap's slope)
				ring.append([Vector3(px, board.ground_y(Vector2(px, z - foot)) - 0.05, z - foot), Vector3(px, bed, z - half),
					Vector3(px, bed, z + half), Vector3(px, board.ground_y(Vector2(px, z + foot)) - 0.05, z + foot)])
			for s in 3:
				var a := ring[0][s] as Vector3
				var b := ring[0][s + 1] as Vector3
				var c := ring[1][s + 1] as Vector3
				var d := ring[1][s] as Vector3
				for v: Vector3 in [a, b, c, a, c, d]:
					st.set_uv(Vector2(v.x, v.z + v.y) / 1.6)
					st.add_vertex(v)
		x = x2
	if not any:
		return null
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Ballast"
	mi.mesh = st.commit()
	mi.material_override = ModelPiece.material(BALLAST_SURFACE)
	return mi


## How far the ground at x on the line lies under the bed (units, 0 or more).
static func _drop(board: ArenaBoard, x: float, z: float, bed: float) -> float:
	var lowest := INF
	for dz: float in [-0.6, 0.0, 0.6]:
		lowest = minf(lowest, board.ground_y(Vector2(x, z + dz)))
	return maxf(bed + BALLAST - lowest, 0.0)


## The timber trestle over the gully: a bent of two posts, a cap and cross braces at each x, standing on the ground there, and
## two stringers along the line under the rails from the first bent to the last.
static func _trestle(board: ArenaBoard, parent: Node3D, bents: Array, z: float, bed: float) -> void:
	if bents.is_empty():
		return
	var wood := ModelPiece.material(TIMBER_SURFACE)
	var cap_top := bed - 0.02
	var holder := Node3D.new()
	holder.name = "Trestle"
	parent.add_child(holder)
	for b: Variant in bents:
		var x := float(b)
		for side: float in [-1.0, 1.0]:
			var pz := z + side * 0.72
			var foot := board.ground_y(Vector2(x, pz)) - 0.3
			_beam(holder, wood, Vector3(x, (foot + cap_top - 0.42) / 2.0, pz), Vector3(0.24, cap_top - 0.42 - foot, 0.24))
		_beam(holder, wood, Vector3(x, cap_top - 0.35, z), Vector3(0.28, 0.14, 1.9))   # the cap
		var low := maxf(board.ground_y(Vector2(x, z)), cap_top - 3.2)
		var mid := Vector3(x, (low + cap_top - 0.45) / 2.0, z)
		var rise := cap_top - 0.45 - low
		var length := sqrt(rise * rise + 1.44 * 1.44)
		for tilt: float in [1.0, -1.0]:
			var brace := _beam(holder, wood, mid, Vector3(0.1, length, 0.16))
			brace.rotation.x = tilt * atan2(1.44, rise)
	var first := float(bents[0])
	var last := float(bents[bents.size() - 1])
	for side: float in [-1.0, 1.0]:
		_beam(holder, wood, Vector3((first + last) / 2.0, cap_top - 0.14, z + side * 0.47), Vector3(last - first + 0.6, 0.28, 0.24))


static func _beam(parent: Node3D, material: Material, at: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Timber"
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = at
	parent.add_child(mi)
	return mi


## The iron coupling between two cars' ends.
static func _coupler(at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Coupler"
	var bar := CylinderMesh.new()
	bar.top_radius = 0.06
	bar.bottom_radius = 0.06
	bar.height = GAP + 0.3
	mi.mesh = bar
	mi.rotation.z = PI / 2.0
	mi.position = at
	mi.material_override = ModelPiece.material("pal_night")
	return mi


## A copy of a pack model: its meshes under one node, each surface in the game material its name maps to in `swap`.
static func _model(file: String, swap: Dictionary) -> Node3D:
	if not _parts.has(file):
		var scene := (load(PACK + file) as PackedScene).instantiate() as Node3D
		var parts: Array = []
		for n in scene.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var xf := mi.transform
			var p := mi.get_parent()
			while p != scene and p is Node3D:
				xf = (p as Node3D).transform * xf
				p = p.get_parent()
			parts.append([mi.mesh, xf, mi.name])
		scene.free()
		_parts[file] = parts
	var root := Node3D.new()
	for part: Array in _parts[file]:
		var mi := MeshInstance3D.new()
		mi.name = str(part[2])
		mi.mesh = part[0] as Mesh
		mi.transform = part[1] as Transform3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var name := src.resource_name if src != null else ""
			mi.set_surface_override_material(i, ModelPiece.material(str(swap.get(name, "pal_night"))))
		root.add_child(mi)
	return root
