class_name OverworldView
extends Node3D
## The 3D overworld pilot (Ashwin 2026-11-02: "Wouldnt it make our overworld look so much more dynamic?"): a stretch of
## the travel map raised as real land under the moon, the party a lantern on the road. The land is OverworldLand drawn by
## Terrain3D (OverworldTerrain); its woods are the game's own trees (art/plants) planted in chunks; its rocks are Poly
## Haven's scanned ones (RealNature); each place on the map shows as a clearing with its lamps and its name. No battle
## grid: travel's fights still open on their own maps, so the rules never see any of this. Built in code on `_ready`.

const CHUNK := 128.0
## Beyond this many metres from the camera a tree is drawn from its lighter far copy.
const NEAR := 220.0

var land: OverworldLand
var terrain: Terrain3D
var camera: Camera3D
var party: Node3D
var party_at := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1931
	land = OverworldLand.build()
	terrain = OverworldTerrain.build(self, land)
	_sky()
	_lake()
	_plant()
	_rocks()
	_places()
	# The party a little way down the wreck road (the first road out of the wreckage), else beside the wreckage.
	var start := _place_at("ghostlight_wreckage") + Vector2(40.0, 45.0)
	for line: PackedVector2Array in land.roads:
		if line.size() > 120 and line[0].distance_to(_place_at("ghostlight_wreckage")) < 1.0:
			start = line[110]
			break
	_party(start)
	camera = Camera3D.new()
	camera.far = 3000.0
	camera.fov = 40.0
	add_child(camera)
	camera.current = true
	terrain.set_camera(camera)
	look_from(party_at, 38.0, 70.0)


## Puts the camera `back` metres behind and `up` metres above `at`, looking at it from the south.
func look_from(at: Vector2, up: float, back: float) -> void:
	var target := Vector3(at.x, land.height_at(at), at.y)
	camera.position = target + Vector3(-back * 0.35, up, back)
	camera.look_at(target + Vector3(0.0, 4.0, 0.0), Vector3.UP)


func _place_at(id: String) -> Vector2:
	for pl: Dictionary in land.places:
		if str(pl["id"]) == id:
			return pl["at"] as Vector2
	return Vector2(land.size, land.size) * 0.5


## Night under the moon: a cold moonlight with soft shadows, a dark sky that fades into the haze, filmic tone.
func _sky() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.03, 0.04, 0.09)
	mat.sky_horizon_color = Color(0.12, 0.13, 0.2)
	mat.ground_horizon_color = Color(0.08, 0.08, 0.12)
	mat.ground_bottom_color = Color(0.02, 0.02, 0.04)
	mat.sun_angle_max = 2.0
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.18, 0.26)
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 0.95)
	moon.light_energy = 1.5
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 600.0
	moon.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	add_child(moon)


func _lake() -> void:
	if land.lake_radius <= 0.0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Lake"
	var disc := CylinderMesh.new()   # a flat disc: its rim stays under the basin's banks
	disc.top_radius = land.lake_radius * 1.3
	disc.bottom_radius = disc.top_radius
	disc.height = 0.05
	disc.radial_segments = 96
	mi.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.06, 0.08)
	mat.roughness = 0.08
	mat.metallic = 0.3
	mi.material_override = mat
	mi.position = Vector3(land.lake_at.x, land.lake_level, land.lake_at.y)
	add_child(mi)


## Trees over the woods and a few in the open, ground plants under them and over the open ground near the party.
func _plant() -> void:
	var cfg := land.config.get("trees", {}) as Dictionary
	var tall := cfg.get("height", [11.0, 17.0]) as Array
	var items := {}   ## plant id -> Array of Transform3D
	var cell := 10.0   # one try per 10 m square per hectare-rate / 100
	var n := land.size
	for z in range(0, n, int(cell)):
		for x in range(0, n, int(cell)):
			var p := Vector2(x + _rng.randf() * cell, z + _rng.randf() * cell)
			var i := clampi(int(p.y), 0, n - 1) * n + clampi(int(p.x), 0, n - 1)
			if land.road_dist[i] < 7.0 or land.slope_at(int(p.x), int(p.y)) > 0.6 or _wet(p):
				continue
			var list := (cfg.get("woods", []) as Array) if land.woods[i] > 0.35 else (cfg.get("open", []) as Array)
			for pick: Variant in list:
				var per_try := float((pick as Array)[1]) / 100.0
				var count := floori(per_try) + (1 if _rng.randf() < per_try - floorf(per_try) else 0)
				for k in count:
					var q := p + Vector2(_rng.randf_range(-cell, cell), _rng.randf_range(-cell, cell)) * 0.5
					_add(items, str((pick as Array)[0]), q, _rng.randf_range(float(tall[0]), float(tall[1])), true)
	var plants := land.config.get("plants", {}) as Dictionary
	var reach := float(plants.get("reach", 250.0))
	for z in range(0, n, 4):
		for x in range(0, n, 4):
			var p := Vector2(x + _rng.randf() * 4.0, z + _rng.randf() * 4.0)
			var i := clampi(int(p.y), 0, n - 1) * n + clampi(int(p.x), 0, n - 1)
			if land.road_dist[i] < 3.0 or _wet(p):
				continue
			var in_woods := land.woods[i] > 0.35
			if not in_woods and p.distance_to(_place_at("ghostlight_wreckage")) > reach:
				continue
			for pick: Variant in plants.get("woods" if in_woods else "open", []) as Array:
				if _rng.randf() < float((pick as Array)[1]) * 16.0 / 10000.0:
					_add(items, str((pick as Array)[0]), p, _rng.randf_range(0.9, 1.6), false)
	for id: String in items:
		_draw(id, items[id] as Array)


func _wet(p: Vector2) -> bool:
	return land.lake_radius > 0.0 and p.distance_to(land.lake_at) < land.lake_radius * 1.4 \
		and land.height_at(p) < land.lake_level + 0.3


## One plant `id` standing at `p`: trees are sized to `size` metres tall, ground plants grown `size` times their model.
func _add(items: Dictionary, id: String, p: Vector2, size: float, tree: bool) -> void:
	var m := Flora.mesh(id)
	if m == null or not land.inside(p):
		return
	var s := size / maxf(m.get_aabb().size.y, 0.1) if tree else size * 2.2
	var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s)
	basis = Basis(Vector3(1, 0, 0), _rng.randf_range(-0.05, 0.05)) * basis
	if not items.has(id):
		items[id] = []
	(items[id] as Array).append(Transform3D(basis, Vector3(p.x, land.height_at(p) - 0.2, p.y)))


## Draws one plant's copies in chunks of CHUNK metres, each chunk near (the full model) and far (its lighter copy).
func _draw(id: String, xforms: Array) -> void:
	var chunks := {}
	for t: Transform3D in xforms:
		var key := Vector2i(floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(t)
	var far_id := str((Flora.manifest().get(id, {}) as Dictionary).get("far", ""))
	for key: Vector2i in chunks:
		var list := chunks[key] as Array
		_multi(id, Flora.mesh(id), list, 0.0, NEAR if far_id != "" else 0.0)
		if far_id != "" and Flora.mesh(far_id) != null:
			_multi(far_id, Flora.mesh(far_id), list, NEAR, 0.0)


func _multi(id: String, mesh: Mesh, list: Array, begin: float, end: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i] as Transform3D)
		mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Plants_" + id
	mmi.multimesh = mm
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	add_child(mmi)


## Scanned rocks on the steep ground and a few in the open.
func _rocks() -> void:
	var cfg := land.config.get("rocks", {}) as Dictionary
	var models := cfg.get("models", []) as Array
	var size := cfg.get("size", [1.5, 4.5]) as Array
	if models.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "Rocks"
	add_child(holder)
	var n := land.size
	for z in range(0, n, 20):
		for x in range(0, n, 20):
			var p := Vector2(x + _rng.randf() * 20.0, z + _rng.randf() * 20.0)
			var i := clampi(int(p.y), 0, n - 1) * n + clampi(int(p.x), 0, n - 1)
			if land.road_dist[i] < 5.0 or _wet(p):
				continue
			var steep := land.slope_at(int(p.x), int(p.y)) > OverworldLand.ROCK_SLOPE * 0.7
			var rate := float(cfg.get("per_hectare_slope" if steep else "per_hectare_open", 1.0)) * 400.0 / 10000.0
			if _rng.randf() >= rate:
				continue
			var rock := RealNature.build(holder, str(models[_rng.randi() % models.size()]), Vector3(p.x, land.height_at(p), p.y), _rng.randi())
			if rock != null:
				rock.scale *= _rng.randf_range(float(size[0]), float(size[1]))


## Each place: a clearing (the land already made it), its lamps, and its name over it.
func _places() -> void:
	for pl: Dictionary in land.places:
		var at := pl["at"] as Vector2
		var spec := pl["spec"] as Dictionary
		var lamps := int(spec.get("lights", 1))
		for k in lamps:
			var a := _rng.randf_range(0.0, TAU)
			var r := _rng.randf_range(0.0, float(spec.get("radius", 40)) * 0.45) if lamps > 1 else 0.0
			var q := at + Vector2(cos(a), sin(a)) * r
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.62, 0.3)
			lamp.light_energy = 2.2
			lamp.omni_range = 16.0
			lamp.position = Vector3(q.x, land.height_at(q) + 3.0, q.y)
			add_child(lamp)
		var label := Label3D.new()
		label.text = str(pl["name"])
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 160
		label.outline_size = 24
		label.pixel_size = 0.02
		label.modulate = Color(0.95, 0.9, 0.78)
		label.no_depth_test = true
		label.position = Vector3(at.x, land.height_at(at) + 22.0, at.y)
		add_child(label)


## The party on the road: a lantern-bearer's glow and a small figure, at `p`.
func _party(p: Vector2) -> void:
	party_at = p
	party = Node3D.new()
	party.name = "Party"
	party.position = Vector3(p.x, land.height_at(p), p.y)
	add_child(party)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8
	body.mesh = cap
	body.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.17, 0.15)
	body.material_override = mat
	party.add_child(body)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.7, 0.35)
	lantern.light_energy = 3.0
	lantern.omni_range = 14.0
	lantern.shadow_enabled = true
	lantern.position = Vector3(0.5, 1.6, 0.0)
	party.add_child(lantern)
