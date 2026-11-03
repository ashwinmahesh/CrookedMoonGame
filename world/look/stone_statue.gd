class_name StoneStatue
extends RefCounted
## A statue carved as a real person would be (the catalog's "stone_statue" set piece; Ashwin, 2026-11-03: the old statues
## looked weird, and he picked these four): one of the pack bodies the townsfolk wear, dressed and held in a pose, every
## surface in stone, on a plinth bedded in the ground under it. The catalog entry's `statue` holds the figure (`figure`, a
## pack body, and `layers`, its head, outfit and hair: no head for the headless one), its `pose` (a clip of the pack rig,
## held at its first beat), the stone (`stone`, a texture set or a palette material), what it holds (`gear`), its height
## (`height`, units: the figure from heel to crown) and the plinth's (`plinth`). A prop's `scale` makes it that much bigger.

## How long a statue's figure is left to take its pose and face its way before it is held still (seconds).
const SETTLE := 0.4
## How far the plinth reaches below the lowest ground under it, so no slope shows a gap under it (units).
const BED := 0.25

static var _registered: Dictionary = {}


static func build(board: ArenaBoard, root: Node3D, cell: Vector2i, spec: Dictionary, look: Dictionary) -> Node3D:
	var info := look.get("statue", {}) as Dictionary
	if info.is_empty():
		return null
	var figure := _figure_id(info)
	if not FigureModels.has(figure):
		return null
	var scale_ := clampf(float(spec.get("scale", 1.0)), 0.25, 8.0)
	var height := float(info.get("height", 1.3)) * scale_
	var plinth_h := float(info.get("plinth", 0.5)) * scale_
	var width := 0.8 * maxf(scale_, 1.0) if scale_ > 1.0 else 0.8
	var centre: Variant = SetDressing.span_centre(board, spec)
	var at: Vector3 = centre as Vector3 if centre != null else board.cell_center(cell)
	var holder := Node3D.new()
	holder.name = "Statue"
	holder.set_meta("statue", figure)
	root.add_child(holder)
	# The plinth stands on the lowest ground under it and reaches down into it.
	var ground := INF
	for d: Vector2 in [Vector2.ZERO, Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
		ground = minf(ground, board.ground_y(Vector2(at.x, at.z) + d * width / 0.8))
	var top := board.ground_y(Vector2(at.x, at.z)) + plinth_h
	holder.position = Vector3(at.x, 0.0, at.z)
	var stone := _stone(str(info.get("stone", "mountain/cliff")))
	var block := top - ground + BED - 0.06 * scale_
	_block(holder, stone, Vector3(0.0, ground - BED + block / 2.0, 0.0), Vector3(width, block, width))
	_block(holder, stone, Vector3(0.0, top - 0.03 * scale_, 0.0), Vector3(width + 0.1 * scale_, 0.06 * scale_, width + 0.1 * scale_))
	var f := DirectionalSprite.create(FigureModels.frames(figure), height) as ModelFigure
	f.name = "Figure"
	f.position = Vector3(0.0, top, 0.0)
	var yaw: Variant = SetDressing.facing_yaw(spec)
	var turn := 0.0 if yaw == null else float(yaw)
	f.facing = Vector3(sin(turn), 0.0, cos(turn))
	holder.add_child(f)
	if str(info.get("gear", "")) != "":
		f.wear([str(info["gear"])])
	_in_stone(f, stone)
	var hold := func() -> void:
		await f.get_tree().create_timer(SETTLE).timeout
		if not is_instance_valid(f):
			return
		_in_stone(f, stone)   # (and anything it put on as it took its pose)
		for p in f.find_children("*", "AnimationPlayer", true, false):
			(p as AnimationPlayer).pause()
		f.set_process(false)   # held: no breath, no turning
	if f.is_inside_tree():
		hold.call()
	else:
		f.tree_entered.connect(hold, CONNECT_ONE_SHOT)
	return holder


## The figure entry a statue is drawn with: registered once per look of figure, layers and pose.
static func _figure_id(info: Dictionary) -> String:
	var layers := info.get("layers", []) as Array
	var key := "%s|%s|%s" % [info.get("figure", "pack_male"), ",".join(layers.map(func(l: Variant) -> String: return str(l))), info.get("pose", "Idle")]
	if not _registered.has(key) or not FigureModels.has(str(_registered[key])):   # (registered figures can be forgotten)
		var id := str(_registered.get(key, "stone_statue_%d" % _registered.size()))
		FigureModels.register(id, {"base": str(info.get("figure", "pack_male")), "layers": layers, "sprite": "villager",
			"clips": {"idle": str(info.get("pose", "Idle"))}})
		_registered[key] = id
	return str(_registered[key])


## A stone: a texture set ("mountain/cliff") mapped by world position, or a palette material ("pal_night", iron).
static func _stone(name: String) -> Material:
	if name.begins_with("pal_"):
		return ModelPiece.material(name)
	var m := Look.cel_textured(name)
	return m if m != null else ModelPiece.material("pal_stone")


static func _in_stone(f: ModelFigure, stone: Material) -> void:
	for n in f.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).material_override = stone


static func _block(parent: Node3D, material: Material, at: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Plinth"
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = material
	mi.position = at
	parent.add_child(mi)
