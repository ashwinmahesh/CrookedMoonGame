class_name PumpkinScarecrow
extends RefCounted
## A scarecrow put together as a farmer would (the catalog's "pumpkin_scarecrow" set piece; Ashwin, 2026-11-03, picked it of
## three): a cross post sunk in the ground, an old peasant's jerkin and breeches from the pack the townsfolk wear hung on it
## arms out, a carved pumpkin for a head, straw sticking out at the cuffs and the collar. Each one leans a little and tips its
## head its own way, the same every visit, so a field of them is not a row of copies.

const HALLOWEEN := "res://art/sourced/kaylousberg_halloween_bits/"
## The clothes, the head and the straw.
const OUTFIT := "res://art/figures/pack/pack_male_peasant3.glb"
const HEAD := HALLOWEEN + "Pumpkin Orange Jacko.glb"
const STRAW := "res://addons/dnd_core/art/models/straw.glb"
## A man a little under six feet hung a hand off the ground (units, 5 ft); the pack bodies are 1.8 of their own units tall.
const BODY_SCALE := 1.12 / 1.8
const HUNG := 0.28
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
	_beam(holder, wood, Vector3(0.0, (1.34 - SINK) / 2.0, -0.06), Vector3(0.09, 1.34 + SINK, 0.09))   # the post, up into the head
	_beam(holder, wood, Vector3(0.0, 1.0, -0.06), Vector3(1.05, 0.07, 0.07))   # the crossbar under the arms
	var outfit := (load(OUTFIT) as PackedScene).instantiate() as Node3D
	outfit.name = "Clothes"
	outfit.scale = Vector3.ONE * BODY_SCALE
	outfit.position.y = HUNG
	holder.add_child(outfit)
	var head := (load(HEAD) as PackedScene).instantiate() as Node3D
	head.name = "Head"
	head.scale = Vector3.ONE * 0.19
	head.position = Vector3(0.0, HUNG + 1.5 * BODY_SCALE - 0.04, 0.0)
	head.rotation = Vector3(deg_to_rad(rng.randf_range(-6.0, 12.0)), deg_to_rad(rng.randf_range(-20.0, 20.0)),
		deg_to_rad(rng.randf_range(-14.0, 14.0)))   # a tipped, lolling head
	holder.add_child(head)
	if ResourceLoader.exists(STRAW):
		var straw := load(STRAW) as PackedScene
		for p: Vector3 in [Vector3(0.52, 1.0, 0.0), Vector3(-0.52, 1.0, 0.0), Vector3(0.0, HUNG + 1.42 * BODY_SCALE, 0.03)]:
			var tuft := straw.instantiate() as Node3D
			tuft.name = "Straw"
			tuft.scale = Vector3.ONE * rng.randf_range(0.18, 0.26)
			tuft.rotation.y = rng.randf() * TAU
			tuft.position = p
			holder.add_child(tuft)
	return holder


## A material the entry names (`materials`: post, clothes, straw), else the given one.
static func _material(look: Dictionary, part: String, fallback: String) -> Material:
	return ModelPiece.material(str((look.get("materials", {}) as Dictionary).get(part, fallback)))


static func _beam(parent: Node3D, material: Material, at: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Post"
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = at
	parent.add_child(mi)
