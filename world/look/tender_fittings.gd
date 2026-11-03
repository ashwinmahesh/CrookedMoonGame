class_name TenderFittings
extends RefCounted
## The Tender's iron fittings, built from meshes (the catalog's "porthole" and "pipes" set pieces): a riveted porthole on the
## wall, its brass ring round a pane the Shroud's green light comes through, and pipes run along the walls and up across the
## ceiling, with flanges at their joints. They had been drawn as plain marker boxes (Ashwin, 2026-11-03).

## The porthole's glass across and its ring's thickness (units, 5 ft), and its middle's height over the floor.
const PORT := 0.32
const RING := 0.05
const PORT_HEIGHT := 1.1
## A pipe's radius and how far it stands off the wall (units).
const PIPE := 0.05
const OFF := 0.12


## A porthole on the wall beside the prop's square.
static func porthole(board: ArenaBoard, root: Node3D, cell: Vector2i, look: Dictionary) -> Node3D:
	var wall := _wall(board, cell)
	var holder := _on_wall(board, root, cell, wall, PORT_HEIGHT, "Porthole")
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = PORT / 2.0
	torus.outer_radius = PORT / 2.0 + RING
	ring.mesh = torus
	ring.rotation.x = PI / 2.0   # (a torus lies flat: stood up against the wall)
	ring.material_override = ModelPiece.material(str(look.get("ring", "tex_props__track_rail")))
	holder.add_child(ring)
	var pane := MeshInstance3D.new()
	pane.name = "Pane"
	var disc := CylinderMesh.new()
	disc.top_radius = PORT / 2.0
	disc.bottom_radius = PORT / 2.0
	disc.height = 0.01
	pane.mesh = disc
	pane.rotation.x = PI / 2.0
	pane.position.z = -0.01
	pane.material_override = ModelPiece.material(str(look.get("pane", "glow_moon_green")))
	holder.add_child(pane)
	for k in 8:   # its rivets round the ring
		var a := TAU * float(k) / 8.0
		var rivet := MeshInstance3D.new()
		rivet.name = "Rivet"
		var s := SphereMesh.new()
		s.radius = 0.014
		s.height = 0.028
		rivet.mesh = s
		rivet.position = Vector3(cos(a), sin(a), 0.0) * (PORT / 2.0 + RING * 1.6) + Vector3(0.0, 0.0, 0.01)
		rivet.material_override = ring.material_override
		holder.add_child(rivet)
	holder.set_meta("porthole", true)
	return holder


## Pipes along the wall beside the prop's square, three squares of it, and one up the wall and across the ceiling.
static func pipes(board: ArenaBoard, root: Node3D, cell: Vector2i, look: Dictionary) -> Node3D:
	var wall := _wall(board, cell)
	var iron := ModelPiece.material(str(look.get("iron", "tex_props__track_rail")))
	var holder := _on_wall(board, root, cell, wall, 0.0, "Pipes")
	for run: Array in [[0.55, 3.0], [0.85, 3.0], [1.6, 3.0]]:   # [height, length]
		var p := _pipe(iron, float(run[1]))
		p.rotation.z = PI / 2.0
		p.position = Vector3(0.0, float(run[0]), 0.0)
		holder.add_child(p)
		for x: float in [-1.0, 0.0, 1.0]:   # a flange at each joint
			var f := _pipe(iron, 0.06, PIPE * 1.8)
			f.rotation.z = PI / 2.0
			f.position = Vector3(x, float(run[0]), 0.0)
			holder.add_child(f)
	var up := _pipe(iron, 1.6)
	up.position = Vector3(0.8, 0.8 + 0.85, 0.0)
	holder.add_child(up)
	holder.set_meta("pipes", true)
	return holder


static func _pipe(material: Material, length: float, radius := PIPE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Pipe"
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = material
	return mi


## The wall beside a square (the one a piece hangs on), north when it has none.
static func _wall(board: ArenaBoard, cell: Vector2i) -> Vector2i:
	var wall := SetDressing.wall_side(board, cell)
	return wall if wall != Vector2i.ZERO else Vector2i(0, -1)


## A holder on the wall's face beside `cell`, `height` over the floor, its +z looking into the room.
static func _on_wall(board: ArenaBoard, root: Node3D, cell: Vector2i, wall: Vector2i, height: float, name: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = name
	root.add_child(holder)
	var inset := board.wall_inset_at(cell + wall, -wall)
	var face := board.cell_center(cell) + Vector3(float(wall.x), 0.0, float(wall.y)) * (0.5 - inset - OFF)
	holder.position = Vector3(face.x, board.floor_y(cell) + height, face.z)
	holder.rotation.y = atan2(float(-wall.x), float(-wall.y))
	return holder
