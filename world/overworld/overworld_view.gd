class_name OverworldView
extends Node3D
## The 3D overworld (Ashwin 2026-11-02: "Wouldnt it make our overworld look so much more dynamic?", then "Sure do it" to
## making it the real one): a stretch of the travel map raised as real land under the moon, the party a lantern on the
## road. The land is OverworldLand drawn by Terrain3D (OverworldTerrain); its woods are the game's own trees (art/plants)
## drawn in chunks; its rocks are Poly Haven's scanned ones (RealNature); each place the party knows shows as a clearing
## with its lamps and its name. OverworldScreen holds it in a viewport of its own and walks the party along the roads. No
## battle grid: travel's fights still open on their own maps. Opens from the bake (OverworldBake) when there is one,
## else works the land out afresh.

const CHUNK := 128.0
## Beyond this many metres from the camera a tree is drawn from its lighter far copy.
const NEAR := 220.0
## How far from a place the open ground has its grass and heather (metres).
const PLANT_REACH := 170.0

var land: OverworldLand
var terrain: Terrain3D
var camera: Camera3D
var party: Node3D
var party_at := Vector2.ZERO
## The places to show (id -> true); empty shows them all. Set before the view enters the tree.
var shown: Dictionary = {}
## Where the party stands at first: a place's id ("" puts it on the wreck road).
var start_place := ""
var labels: Dictionary = {}   ## place id -> Label3D
var lake_level := -1000.0
var _rng := RandomNumberGenerator.new()
var _items: Dictionary = {}   ## plant id -> Array of Transform3D
var _rocks_list: Array = []   ## [model id, Transform3D]


func _ready() -> void:
	_rng.seed = 1931
	var bake := OverworldBake.load_bake()
	if bake != null:
		land = OverworldLand.light()
		land.roads = bake.roads
		land.road_ids = bake.road_ids
		lake_level = bake.lake_level
		terrain = OverworldTerrain.from_bake(self)
		for id: String in bake.plants:
			_items[id] = OverworldBake.unpack_xforms(bake.plants[id] as PackedFloat32Array)
		_rocks_list = bake.rocks
	else:
		land = OverworldLand.build()
		lake_level = land.lake_level
		terrain = OverworldTerrain.build(self, land)
		plan()
	_sky()
	_lake()
	for id: String in _items:
		_draw(id, _items[id] as Array)
	_place_rocks()
	_places()
	var start := _place_at(start_place) if start_place != "" else _place_at("ghostlight_wreckage") + Vector2(40.0, 45.0)
	_party(start)
	camera = Camera3D.new()
	camera.far = 3000.0
	camera.fov = 40.0
	add_child(camera)
	camera.current = true
	terrain.set_camera(camera)
	look_from(party_at, 38.0, 70.0)


## Works out every plant's and rock's place (what the bake keeps): plan() fills them from the land.
func plan() -> void:
	_items = _plan_plants()
	_rocks_list = _plan_rocks()


## What a bake keeps: the plants as packed transforms and the rocks.
func baked_plants() -> Dictionary:
	var out := {}
	for id: String in _items:
		out[id] = OverworldBake.pack_xforms(_items[id] as Array)
	return out


func baked_rocks() -> Array:
	return _rocks_list


## The ground's height at `p` (metres): the land's when it was worked out here, else Terrain3D's (a baked land).
func ground_y(p: Vector2) -> float:
	if not land.heights.is_empty():
		return land.height_at(p)
	var h := terrain.data.get_height(Vector3(p.x, 0.0, p.y)) if terrain != null else 0.0
	return 0.0 if is_nan(h) else h


## Puts the camera `back` metres behind and `up` metres above `at`, looking at it from the south.
func look_from(at: Vector2, up: float, back: float) -> void:
	var target := Vector3(at.x, ground_y(at), at.y)
	camera.position = target + Vector3(-back * 0.35, up, back)
	camera.look_at(target + Vector3(0.0, 4.0, 0.0), Vector3.UP)


func _place_at(id: String) -> Vector2:
	for pl: Dictionary in land.places:
		if str(pl["id"]) == id:
			return pl["at"] as Vector2
	return Vector2(land.size, land.size) * 0.5


func has_place(id: String) -> bool:
	for pl: Dictionary in land.places:
		if str(pl["id"]) == id:
			return true
	return false


## Moves the party's lantern to `p` (metres), turned to face along `facing`.
func set_party(p: Vector2, facing: Vector2 = Vector2.ZERO) -> void:
	party_at = p
	party.position = Vector3(p.x, ground_y(p), p.y)
	if facing.length() > 0.01:
		party.rotation.y = atan2(-facing.x, -facing.y)


## Lights one place's name (the one chosen) and dims the rest.
func light_place(id: String) -> void:
	for k: String in labels:
		(labels[k] as Label3D).modulate = Color(1.0, 0.8, 0.45) if k == id else Color(0.95, 0.9, 0.78, 0.8)


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
	env.fog_density = 0.0009
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
	mi.position = Vector3(land.lake_at.x, lake_level, land.lake_at.y)
	add_child(mi)


## Trees over the woods and a few in the open, ground plants under them and over the open ground near the places.
func _plan_plants() -> Dictionary:
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
	var reach := float(plants.get("reach", PLANT_REACH))
	for z in range(0, n, 4):
		for x in range(0, n, 4):
			var p := Vector2(x + _rng.randf() * 4.0, z + _rng.randf() * 4.0)
			var i := clampi(int(p.y), 0, n - 1) * n + clampi(int(p.x), 0, n - 1)
			if land.road_dist[i] < 3.0 or _wet(p):
				continue
			var in_woods := land.woods[i] > 0.35
			if not in_woods and not _near_place(p, reach):
				continue
			for pick: Variant in plants.get("woods" if in_woods else "open", []) as Array:
				if _rng.randf() < float((pick as Array)[1]) * 16.0 / 10000.0:
					_add(items, str((pick as Array)[0]), p, _rng.randf_range(0.9, 1.6), false)
	return items


func _near_place(p: Vector2, reach: float) -> bool:
	for pl: Dictionary in land.places:
		if p.distance_to(pl["at"] as Vector2) < reach:
			return true
	return false


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


## Scanned rocks on the steep ground and a few in the open, as [model id, Transform3D].
func _plan_rocks() -> Array:
	var out := []
	var cfg := land.config.get("rocks", {}) as Dictionary
	var models := cfg.get("models", []) as Array
	var size := cfg.get("size", [1.5, 4.5]) as Array
	if models.is_empty():
		return out
	var probe := Node3D.new()
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
			var model := str(models[_rng.randi() % models.size()])
			var rock := RealNature.build(probe, model, Vector3(p.x, land.height_at(p), p.y), _rng.randi())
			if rock != null:
				rock.scale *= _rng.randf_range(float(size[0]), float(size[1]))
				out.append([model, rock.transform])
	probe.free()
	return out


func _place_rocks() -> void:
	var holder := Node3D.new()
	holder.name = "Rocks"
	add_child(holder)
	for r: Variant in _rocks_list:
		RealNature.place(holder, str((r as Array)[0]), (r as Array)[1] as Transform3D)


## Each place: a clearing (the land already made it), its lamps, and its name over it.
func _places() -> void:
	for pl: Dictionary in land.places:
		if not shown.is_empty() and not shown.has(str(pl["id"])):
			continue
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
			lamp.position = Vector3(q.x, ground_y(q) + 3.0, q.y)
			add_child(lamp)
		var label := Label3D.new()
		label.text = str(pl["name"])
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.outline_size = 10
		label.fixed_size = true   # the same size on screen however far the camera hangs back
		label.pixel_size = 0.00045
		label.modulate = Color(0.95, 0.9, 0.78)
		label.no_depth_test = true
		label.position = Vector3(at.x, ground_y(at) + 22.0, at.y)
		add_child(label)
		labels[str(pl["id"])] = label


## The party on the road: a lantern-bearer's glow and a small figure, at `p`.
func _party(p: Vector2) -> void:
	party_at = p
	party = Node3D.new()
	party.name = "Party"
	party.position = Vector3(p.x, ground_y(p), p.y)
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
	var glow := MeshInstance3D.new()   # the lantern itself, so the party can be found from high over the land
	var bulb := SphereMesh.new()
	bulb.radius = 0.6
	bulb.height = 1.2
	glow.mesh = bulb
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.75, 0.4)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.6, 0.25)
	hot.emission_energy_multiplier = 6.0
	glow.material_override = hot
	glow.position = Vector3(0.5, 2.2, 0.0)
	party.add_child(glow)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.7, 0.35)
	lantern.light_energy = 6.0
	lantern.omni_range = 28.0
	lantern.shadow_enabled = true
	lantern.position = Vector3(0.5, 1.6, 0.0)
	party.add_child(lantern)
