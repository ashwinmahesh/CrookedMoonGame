class_name PumpkinScarecrow
extends RefCounted
## A scarecrow put together as a farmer would (the catalog's "pumpkin_scarecrow" set piece; Ashwin, 2026-11-03, picked it of
## three): a cross post sunk in the ground, an old peasant's jerkin and breeches from the pack the townsfolk wear stuffed and
## hung on it by the arms, the crossbar through the sleeves at the shoulders and the body slumping from it, its feet off the
## ground; a carved pumpkin for a head; straw poking out at the cuffs, the collar, the hem and the ankles. Each one leans a little and tips its
## head its own way, the same every visit, so a field of them is not a row of copies.

const HALLOWEEN := "res://art/sourced/kaylousberg_halloween_bits/"
## The clothes, the head and the straw.
const OUTFIT := "res://art/figures/pack/pack_male_peasant3.glb"
const HEAD := HALLOWEEN + "Pumpkin Orange Jacko.glb"
const STRAW := "res://addons/dnd_core/art/models/straw.glb"
## A man a little under six feet hung his feet a foot and a half off the ground (units, 5 ft); the pack bodies are 1.8 of their own units tall.
const BODY_SCALE := 1.12 / 1.8
const HUNG := 0.3
## The pack body's arms in its T-pose, its collar and its hem (heights in its own units, of 1.8).
const ARMS := 1.43
const NECK := 1.5
const HEM := 0.95
## The post's foot sunk below the lowest ground under it (units).
const SINK := 0.25


static func build(board: ArenaBoard, root: Node3D, cell: Vector2i, spec: Dictionary, look: Dictionary) -> Node3D:
	if not ResourceLoader.exists(OUTFIT) or not ResourceLoader.exists(HEAD):
		return null
	var seed_ := ModelPiece.hash_cell(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var scale_ := clampf(float(spec.get("scale", 1.0)), 0.25, 8.0)
	var centre: Variant = SetDressing.span_centre(board, spec)
	var at: Vector3 = centre as Vector3 if centre != null else board.cell_center(cell)
	var ground := INF
	for d: Vector2 in [Vector2.ZERO, Vector2(0.12, 0.0), Vector2(-0.12, 0.0), Vector2(0.0, 0.12), Vector2(0.0, -0.12)]:
		ground = minf(ground, board.ground_y(Vector2(at.x, at.z) + d))
	var holder := Node3D.new()
	holder.name = "Scarecrow"
	holder.set_meta("scarecrow", true)
	root.add_child(holder)
	holder.position = Vector3(at.x, ground, at.z)
	var yaw: Variant = SetDressing.facing_yaw(spec)
	holder.rotation = Vector3(deg_to_rad(rng.randf_range(-4.0, 4.0)),
		(0.0 if yaw == null else float(yaw)) + deg_to_rad(rng.randf_range(-14.0, 14.0)), deg_to_rad(rng.randf_range(-5.0, 5.0)))
	holder.scale = Vector3.ONE * scale_
	var wood := _material(look, "post", "tex_vkit__woodtrim")
	var shoulder := HUNG + ARMS * BODY_SCALE
	_beam(holder, wood, Vector3(0.0, (shoulder + 0.34 - SINK) / 2.0, -0.07), Vector3(0.09, shoulder + 0.34 + SINK, 0.09))   # the post, up into the head
	_beam(holder, wood, Vector3(0.0, shoulder - 0.02, -0.01), Vector3(1.3, 0.07, 0.07), "Crossbar")   # through the sleeves
	# The body hangs from the bar by its arms: a pivot at the shoulders, the rest slumping forward and a little to one side.
	var hang := Node3D.new()
	hang.name = "Hung"
	hang.position = Vector3(0.0, shoulder, 0.0)
	hang.rotation = Vector3(deg_to_rad(rng.randf_range(6.0, 11.0)), 0.0, deg_to_rad(rng.randf_range(-4.0, 4.0)))
	holder.add_child(hang)
	var outfit := (load(OUTFIT) as PackedScene).instantiate() as Node3D
	outfit.name = "Clothes"
	outfit.scale = Vector3.ONE * BODY_SCALE
	outfit.position.y = HUNG - shoulder
	hang.add_child(outfit)
	var head := (load(HEAD) as PackedScene).instantiate() as Node3D
	head.name = "Head"
	head.scale = Vector3.ONE * 0.19
	head.position = Vector3(0.0, HUNG + 1.5 * BODY_SCALE - 0.06, 0.03)
	head.rotation = Vector3(deg_to_rad(rng.randf_range(8.0, 18.0)), deg_to_rad(rng.randf_range(-20.0, 20.0)),
		deg_to_rad(rng.randf_range(-16.0, 16.0)))   # lolling forward and to one side
	holder.add_child(head)
	if ResourceLoader.exists(STRAW):
		var straw := load(STRAW) as PackedScene
		var waist := HUNG + HEM * BODY_SCALE - shoulder
		var tufts: Array = [
			[Vector3(0.6, 0.0, 0.0), 0.2], [Vector3(-0.6, 0.0, 0.0), 0.2],   # the cuffs
			[Vector3(0.0, NECK * BODY_SCALE + HUNG - shoulder, 0.03), 0.22],   # the collar
			[Vector3(0.1, waist, 0.09), 0.16], [Vector3(-0.12, waist, 0.08), 0.15], [Vector3(0.0, waist, -0.09), 0.15],   # the hem
			[Vector3(0.07, HUNG - shoulder + 0.03, 0.0), 0.13], [Vector3(-0.07, HUNG - shoulder + 0.03, 0.0), 0.13],   # the ankles
		]
		for t: Array in tufts:
			var tuft := straw.instantiate() as Node3D
			tuft.name = "Straw"
			tuft.set_meta("straw", true)
			tuft.scale = Vector3.ONE * float(t[1]) * rng.randf_range(0.85, 1.2)
			tuft.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
			tuft.position = t[0] as Vector3
			hang.add_child(tuft)
			if (look.get("materials", {}) as Dictionary).has("straw"):
				for n in tuft.find_children("*", "MeshInstance3D", true, false):
					(n as MeshInstance3D).material_override = _material(look, "straw", "")
	return holder


## A material the entry names (`materials`: post, clothes, straw), else the given one.
static func _material(look: Dictionary, part: String, fallback: String) -> Material:
	return ModelPiece.material(str((look.get("materials", {}) as Dictionary).get(part, fallback)))


static func _beam(parent: Node3D, material: Material, at: Vector3, size: Vector3, name := "Post") -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = at
	parent.add_child(mi)
