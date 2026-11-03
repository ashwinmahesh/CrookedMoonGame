class_name FramedPicture
extends RefCounted
## A framed painting hung on a wall (the catalog's "framed_picture" set piece): a canvas showing a picture from the repo (the
## entry's `picture`, a path under res://), `width` units wide at the picture's own shape, in a moulded gilt frame, hung on the
## wall beside the prop's square with its middle at `height` (units off the floor). The Lounge Car's seascape (Winslow Homer's
## rocky coast) had been drawn as a glass-fronted cabinet (Ashwin, 2026-11-03).

## The frame's moulding: how wide and how deep (units).
const FRAME := 0.07
const FRAME_DEPTH := 0.05


static func build(board: ArenaBoard, root: Node3D, cell: Vector2i, look: Dictionary) -> Node3D:
	var path := str(look.get("picture", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	var wall := SetDressing.wall_side(board, cell)
	if wall == Vector2i.ZERO:
		wall = Vector2i(0, -1)
	var w := float(look.get("width", 1.0))
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var holder := Node3D.new()
	holder.name = "Picture"
	holder.set_meta("picture", path)
	root.add_child(holder)
	# On the wall's face (the wall square's edge, and any set-back the board draws it with), facing into the room.
	var inset := board.wall_inset_at(cell + wall, -wall)
	var face := board.cell_center(cell) + Vector3(float(wall.x), 0.0, float(wall.y)) * (0.5 - inset)
	holder.position = Vector3(face.x, board.floor_y(cell) + float(look.get("height", 1.0)), face.z)
	holder.rotation.y = atan2(float(-wall.x), float(-wall.y))
	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	canvas.mesh = quad
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = tex
	paint.roughness = 0.75
	canvas.material_override = paint
	canvas.position = Vector3(0.0, 0.0, FRAME_DEPTH * 0.6)
	holder.add_child(canvas)
	var gilt := ModelPiece.material(str(look.get("frame", "pal_deco_gold")))
	for side: Array in [[Vector3(0.0, (h + FRAME) / 2.0, 0.0), Vector3(w + FRAME * 2.0, FRAME, FRAME_DEPTH)],
			[Vector3(0.0, -(h + FRAME) / 2.0, 0.0), Vector3(w + FRAME * 2.0, FRAME, FRAME_DEPTH)],
			[Vector3((w + FRAME) / 2.0, 0.0, 0.0), Vector3(FRAME, h, FRAME_DEPTH)],
			[Vector3(-(w + FRAME) / 2.0, 0.0, 0.0), Vector3(FRAME, h, FRAME_DEPTH)]]:
		var bar := MeshInstance3D.new()
		bar.name = "Frame"
		var box := BoxMesh.new()
		box.size = side[1] as Vector3
		bar.mesh = box
		bar.material_override = gilt
		bar.position = (side[0] as Vector3) + Vector3(0.0, 0.0, FRAME_DEPTH / 2.0)
		holder.add_child(bar)
	return holder
