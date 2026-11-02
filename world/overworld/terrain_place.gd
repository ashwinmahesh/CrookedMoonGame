class_name TerrainPlace
extends RefCounted
## A walkable map's ground and the land round it drawn by Terrain3D (the overworld pilot's terrain; Ashwin 2026-11-02 asked
## to see the way up to the Ghostlight Express "redone with terrain3d"). Inside the map the terrain follows the board's
## own ground exactly (ArenaBoard.ground_y, a hair above it), so tokens, rings, templates and every rule stand where they
## did: the grid, the walking and the fights don't change. Past the map's edge it carries on as real land, rising into
## wooded hills, with the place's lane running on down out of the map. The engine's ground skin and the land it drew past
## the edge are hidden; its trees, props and figures stay. art/overworld/terrain_places.json says which places and how.

const CONFIG := "res://art/overworld/terrain_places.json"
## Terrain vertices per world unit (a 5 ft square), and how far past the map the land reaches (units).
const PER_UNIT := 4
const MARGIN := 64
## How far above the board's ground the terrain lies inside the map (units), so the old skin never shows through.
const LIFT := 0.02

static var _config: Dictionary = {}
## Set by art QA tools only, to shoot a place as it was before.
static var off := false


static func config() -> Dictionary:
	if _config.is_empty() and FileAccess.file_exists(CONFIG):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		if parsed is Dictionary:
			_config = parsed as Dictionary
	return _config


static func dress(view: LocationView) -> Terrain3D:
	var spec := (config().get("places", {}) as Dictionary).get(view.loc_id, {}) as Dictionary
	if off or spec.is_empty() or not Look.modern() or OS.get_cmdline_user_args().has("--no-terrain3d"):
		return null
	var board := view.board
	var grid := board.grid
	var noise := FastNoiseLite.new()
	noise.seed = hash(view.loc_id)
	noise.fractal_octaves = 5
	var lane := _lane(spec, grid)
	var w := (grid.width + MARGIN * 2) * PER_UNIT
	var d := (grid.depth + MARGIN * 2) * PER_UNIT
	var height := Image.create_empty(w, d, false, Image.FORMAT_RF)
	var control := Image.create_empty(w, d, false, Image.FORMAT_RF)
	var roads := _road_field(lane, w, d)
	var rise := float(spec.get("rise", 6.0))
	var edge := _edge_height(board)
	for j in d:
		for i in w:
			var p := Vector2(float(i) / PER_UNIT - MARGIN, float(j) / PER_UNIT - MARGIN)
			var inside := p.x >= 0.0 and p.y >= 0.0 and p.x < grid.width and p.y < grid.depth
			var out := _outside(p, grid)
			var land := edge + (noise.get_noise_2d(p.x * 4.0, p.y * 4.0) * 0.5 + 0.5) * rise * smoothstep(0.0, 30.0, out)
			var road := roads[j * w + i]
			var h := land
			if inside:
				h = board.ground_y(p) + LIFT
			else:
				var near := board.ground_y(Vector2(clampf(p.x, 0.0, grid.width - 0.01), clampf(p.y, 0.0, grid.depth - 0.01)))
				h = lerpf(near, land, smoothstep(0.0, 6.0, out))
				h = lerpf(h, minf(h, near + out * 0.08), 1.0 - smoothstep(1.5, 5.0, road))   # the lane falls gently away
			height.set_pixel(i, j, Color(h, 0.0, 0.0, 1.0))
			var g := _ground(view, p, inside, out, road, noise)
			var bits := Terrain3DUtil.enc_base(g[0]) | Terrain3DUtil.enc_overlay(g[1]) | Terrain3DUtil.enc_blend(g[2])
			control.set_pixel(i, j, Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0))
	var terrain := Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.free_editor_textures = false   # (built in code: there is no saved assets file to free them for)
	terrain.region_size = Terrain3D.SIZE_1024
	terrain.vertex_spacing = 1.0 / PER_UNIT
	board.add_child(terrain)
	terrain.material.world_background = Terrain3DMaterial.NONE
	for k in OverworldLand.GROUNDS.size():
		var ta := OverworldTerrain.ground(OverworldLand.GROUNDS[k])
		ta.uv_scale *= 1.5   # a square is 1.5 m: the grounds keep their real size
		terrain.assets.set_texture_asset(k, ta)
	terrain.data.import_images([height, control, null], Vector3(-MARGIN, 0.0, -MARGIN), 0.0, 1.0)
	var cam := view.get_viewport().get_camera_3d() if view.is_inside_tree() else null
	if cam != null:
		terrain.set_camera(cam)
	_hide_old(view)
	_plant(view, terrain, roads, w, noise)
	return terrain


## The lane out of the map as points (units): from the spec's `lane` square straight off the map's edge in its
## `heading`, then wandering on downhill.
static func _lane(spec: Dictionary, grid: CombatGrid) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not spec.has("lane"):
		return out
	var at := Vector2(float((spec["lane"] as Array)[0]) + 0.5, float((spec["lane"] as Array)[1]) + 0.5)
	var dir := Vector2(float((spec["heading"] as Array)[0]), float((spec["heading"] as Array)[1])).normalized()
	for k in 240:
		out.append(at)
		var t := float(k) / 240.0
		dir = dir.rotated(sin(t * 9.0) * 0.03)
		at += dir * 0.35
		if at.x < -MARGIN or at.y < -MARGIN or at.x > grid.width + MARGIN or at.y > grid.depth + MARGIN:
			break
	return out


## Distance (units) from every terrain vertex to the lane, worked out by stamping round each of its points.
static func _road_field(line: PackedVector2Array, w: int, d: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * d)
	out.fill(1.0e6)
	var reach := 6 * PER_UNIT
	for q: Vector2 in line:
		var ci := int((q.x + MARGIN) * PER_UNIT)
		var cj := int((q.y + MARGIN) * PER_UNIT)
		for j in range(maxi(cj - reach, 0), mini(cj + reach + 1, d)):
			for i in range(maxi(ci - reach, 0), mini(ci + reach + 1, w)):
				var p := Vector2(float(i) / PER_UNIT - MARGIN, float(j) / PER_UNIT - MARGIN)
				out[j * w + i] = minf(out[j * w + i], p.distance_to(q))
	return out


static func _road_at(roads: PackedFloat32Array, w: int, p: Vector2) -> float:
	var i := clampi(int((p.x + MARGIN) * PER_UNIT), 0, w - 1)
	var j := clampi(int((p.y + MARGIN) * PER_UNIT), 0, roads.size() / w - 1)
	return roads[j * w + i]


## How far point `p` lies outside the map (units), 0 inside.
static func _outside(p: Vector2, grid: CombatGrid) -> float:
	var dx := maxf(maxf(-p.x, p.x - grid.width), 0.0)
	var dz := maxf(maxf(-p.y, p.y - grid.depth), 0.0)
	return sqrt(dx * dx + dz * dz)


## The map edge's mean ground height, where the land beyond starts from.
static func _edge_height(board: ArenaBoard) -> float:
	var sum := 0.0
	var n := 0
	for x in board.grid.width:
		sum += board.ground_y(Vector2(x + 0.5, 0.5)) + board.ground_y(Vector2(x + 0.5, board.grid.depth - 0.5))
		n += 2
	return sum / float(n)


## [base, overlay, blend] for a point: the map's own squares by kind, the land beyond by noise and woods.
static func _ground(view: LocationView, p: Vector2, inside: bool, out: float, road: float, noise: FastNoiseLite) -> Array[int]:
	var mix := clampi(int((noise.get_noise_2d(p.x * 9.0 + 77.0, p.y * 9.0) * 0.5 + 0.5) * 255.0), 0, 255)
	if road < 1.6:
		return [OverworldLand.ROAD, OverworldLand.MOOR, clampi(int(smoothstep(0.9, 1.6, road) * 255.0), 0, 255)]
	if inside:
		var c := Vector2i(int(p.x), int(p.y))
		var f := view.grid.flags(c)
		if (f & CombatGrid.WALL) != 0:
			return [OverworldLand.WOODS, OverworldLand.MOOR, 60]
		if (f & CombatGrid.DIFFICULT) != 0:
			return [OverworldLand.WOODS, OverworldLand.ROCK, 70]
		return [OverworldLand.MOOR, OverworldLand.MEADOW, mix]
	if _woods(p, noise) > 0.3:
		return [OverworldLand.WOODS, OverworldLand.MOOR, 50]
	return [OverworldLand.MOOR, OverworldLand.MEADOW, mix]


static func _woods(p: Vector2, noise: FastNoiseLite) -> float:
	return smoothstep(-0.1, 0.25, noise.get_noise_2d(p.x * 2.0 + 500.0, p.y * 2.0))


## The engine's ground skin and the land it drew past the map give way to the terrain.
static func _hide_old(view: LocationView) -> void:
	var ground := view.board.get_node_or_null("Ground") as Node3D
	if ground != null:
		ground.visible = false
	var surround := view.find_child("Surround", true, false) as Node3D
	if surround != null:
		surround.visible = false


## Trees over the land's woods past the map, kept off the lane, and ground plants under them.
static func _plant(view: LocationView, terrain: Terrain3D, roads: PackedFloat32Array, w: int, noise: FastNoiseLite) -> void:
	var grid := view.grid
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(view.loc_id) + 3
	var items := {}
	var trees: Array[String] = ["oak_a", "oak_b", "dead_a", "spruce_b", "oak_a", "dead_b"]
	var plants: Array[String] = ["fern_a", "bracken", "grass_dry", "heather"]
	for z in range(-MARGIN, grid.depth + MARGIN):
		for x in range(-MARGIN, grid.width + MARGIN):
			var p := Vector2(x + rng.randf(), z + rng.randf())
			var out := _outside(p, grid)
			if out < 1.2 or _road_at(roads, w, p) < 2.2:
				continue
			var wd := _woods(p, noise)
			if rng.randf() < wd * 0.55:
				_add(items, trees[rng.randi() % trees.size()], p, terrain, rng.randf_range(2.6, 4.2), true, rng)
			if rng.randf() < 0.5 and out < 40.0:
				_add(items, plants[rng.randi() % plants.size()], p, terrain, rng.randf_range(0.8, 1.3), false, rng)
	for id: String in items:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Flora.mesh(id)
		var list := items[id] as Array
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i] as Transform3D)
			mm.set_instance_color(i, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "TerrainPlants_" + id
		mmi.multimesh = mm
		view.board.add_child(mmi)


static func _add(items: Dictionary, id: String, p: Vector2, terrain: Terrain3D, size: float, tree: bool, rng: RandomNumberGenerator) -> void:
	var m := Flora.mesh(id)
	if m == null:
		return
	var s := size / maxf(m.get_aabb().size.y, 0.1) if tree else size
	var y := terrain.data.get_height(Vector3(p.x, 0.0, p.y))
	if is_nan(y):
		return
	if not items.has(id):
		items[id] = []
	(items[id] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3(p.x, y - 0.05, p.y)))
