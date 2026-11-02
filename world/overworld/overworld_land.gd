class_name OverworldLand
extends RefCounted
## The overworld's land, worked out once from art/overworld/overworld.json and the travel map (Travel.map_data): a height for
## every sample of the whole map (one every `step` metres), which ground each shows, where the roads run and where the woods
## stand. Rolling hills from noise, a ridge along the north, lowlands round the swamp, the farmland and the prairie, each
## place's hollow, hill, fields, isle or forest, crags behind Dawn's Gate, lakes, a swamp of pools, and the roads between the
## places cut into the slopes as worn tracks. OverworldTerrain hands it to Terrain3D; OverworldView plants on it. Pure data
## (no nodes), so a test can check it without drawing anything.

const CONFIG := "res://art/overworld/overworld.json"
## The grounds in Terrain3D's texture order (tools/art/pack_terrain.py packs them in the same order).
const GROUNDS: Array[String] = ["meadow", "moor", "rock", "road", "woods", "hill"]
const MEADOW := 0
const MOOR := 1
const ROCK := 2
const ROAD := 3
const WOODS := 4
const HILL := 5
## How steep (rise over run) ground must be to show bare rock, and how high (metres) the grass turns to hill ground.
const ROCK_SLOPE := 0.75
const HIGH := 58.0
## What a sample of the land is part of (`zone`), and the names the plant lists in overworld.json give them.
const ZONE_NONE := 0
const ZONE_SWAMP := 1
const ZONE_FIELDS := 2
const ZONE_FOREST := 3
const ZONE_SCREE := 4
const ZONE_PRAIRIE := 5
const ZONE_NAMES: Array[String] = ["", "swamp", "fields", "forest", "scree", "prairie"]
## The slant of the farmland's furrows across the map (radians), and the ground of each of three furrow stripes.
const FIELD_ANGLE := 0.42
const STRIPE_BASE: Array[int] = [MEADOW, MOOR, HILL]
const STRIPE_OVER: Array[int] = [MOOR, MEADOW, MOOR]

var config: Dictionary = {}
var size := 2048        ## metres across
var step := 2.0         ## metres between two samples
var n := 1024           ## samples across (size / step)
var heights := PackedFloat32Array()   ## metres, one per sample, row by row (z then x)
var road_dist := PackedFloat32Array() ## metres to the nearest road's middle (a large number far from any road)
var woods := PackedFloat32Array()     ## 0..1, how deep in the woods each sample is
var zone := PackedByteArray()         ## ZONE_* of each sample
var places: Array[Dictionary] = []    ## {id, name, at: Vector2 (metres), spec}
var roads: Array[PackedVector2Array] = []
var road_ids: Array[String] = []   ## the travel map's road id of each line in `roads`
## Still water: {id, kind "lake" or "swamp", at: Vector2 (metres), radius, depth, level}. A level of -1000 is not worked out
## yet (a baked land takes them from the bake).
var waters: Array[Dictionary] = []
var field_stripe := 34.0
var _noise := FastNoiseLite.new()
var _woods_noise := FastNoiseLite.new()
var _bog_noise := FastNoiseLite.new()


## Only the places and the waters (no heights): for a baked overworld, whose heights are Terrain3D's own and whose roads
## come from the bake.
static func light() -> OverworldLand:
	var land := OverworldLand.new()
	land._read()
	return land


## The road's line from place `a` to place `b` (either way round), as metres; empty when the land has none.
func road_line(road_id: String, from_place: String) -> PackedVector2Array:
	var k := road_ids.find(road_id)
	if k < 0:
		return PackedVector2Array()
	var line := roads[k]
	for pl: Dictionary in places:
		if str(pl["id"]) == from_place and line[line.size() - 1].distance_to(pl["at"] as Vector2) < line[0].distance_to(pl["at"] as Vector2):
			var back := line.duplicate()
			back.reverse()
			return back
	return line


static func build(seed_: int = 1931) -> OverworldLand:
	var land := OverworldLand.new()
	land._read()
	land._noise.seed = seed_
	land._noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	land._noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	land._noise.fractal_octaves = 5
	land._woods_noise.seed = seed_ + 7
	land._woods_noise.fractal_octaves = 3
	land._bog_noise.seed = seed_ + 13
	land._bog_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	land._bog_noise.fractal_octaves = 3
	land._raise()
	land._lay_roads()
	return land


## A travel map position (0-1 across its picture) as metres on the land.
func to_land(pos: Vector2) -> Vector2:
	var w := config.get("window", [0.0, 0.0, 1.0, 1.0]) as Array
	return Vector2((pos.x - float(w[0])) / (float(w[2]) - float(w[0])), (pos.y - float(w[1])) / (float(w[3]) - float(w[1]))) * float(size)


func inside(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < float(size) and p.y < float(size)


## The index of the sample nearest `p` (metres).
func cell_of(p: Vector2) -> int:
	return clampi(roundi(p.y / step), 0, n - 1) * n + clampi(roundi(p.x / step), 0, n - 1)


## The height at `p` (metres), blended between the four samples round it.
func height_at(p: Vector2) -> float:
	var fx := clampf(p.x / step, 0.0, float(n - 1))
	var fz := clampf(p.y / step, 0.0, float(n - 1))
	var x0 := mini(int(fx), n - 2)
	var z0 := mini(int(fz), n - 2)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var i := z0 * n + x0
	return lerpf(lerpf(heights[i], heights[i + 1], tx), lerpf(heights[i + n], heights[i + n + 1], tx), tz)


func road_dist_at(p: Vector2) -> float:
	return road_dist[cell_of(p)]


func woods_at(p: Vector2) -> float:
	return woods[cell_of(p)]


func zone_at(p: Vector2) -> int:
	return zone[cell_of(p)]


## Rise over run at the sample nearest `p`.
func slope_near(p: Vector2) -> float:
	return slope_at(roundi(p.x / step), roundi(p.y / step))


## Rise over run at a sample, from its neighbours.
func slope_at(x_: int, z_: int) -> float:
	var x := clampi(x_, 0, n - 1)
	var z := clampi(z_, 0, n - 1)
	var x0 := maxi(x - 1, 0)
	var x1 := mini(x + 1, n - 1)
	var z0 := maxi(z - 1, 0)
	var z1 := mini(z + 1, n - 1)
	var dx := (heights[z * n + x1] - heights[z * n + x0]) / (float(x1 - x0) * step)
	var dz := (heights[z1 * n + x] - heights[z0 * n + x]) / (float(z1 - z0) * step)
	return sqrt(dx * dx + dz * dz)


## Whether `p` lies under (or at the edge of) one of the waters.
func is_wet(p: Vector2) -> bool:
	for w: Dictionary in waters:
		var reach := float(w["radius"]) * (1.4 if str(w["kind"]) == "lake" else 1.15)
		if p.distance_to(w["at"] as Vector2) < reach and height_at(p) < float(w["level"]) + 0.3:
			return true
	return false


## The level of the swamp water nearest `p`, or -1000.
func swamp_level_near(p: Vector2) -> float:
	var best := -1000.0
	var best_d := INF
	for w: Dictionary in waters:
		if str(w["kind"]) == "swamp" and p.distance_to(w["at"] as Vector2) < best_d:
			best_d = p.distance_to(w["at"] as Vector2)
			best = float(w["level"])
	return best


## Which furrow stripe of the plough land `p` is in, as a fraction (the whole part counts stripes).
func field_u(p: Vector2) -> float:
	return (p.x * cos(FIELD_ANGLE) + p.y * sin(FIELD_ANGLE)) / field_stripe


## Which ground a sample shows: [base, overlay, blend 0-255].
func ground_at(x: int, z: int) -> Array[int]:
	var i := z * n + x
	var h := heights[i]
	var slope := slope_at(x, z)
	var wx := float(x) * step
	var wz := float(z) * step
	var grass := MOOR
	var over := MEADOW
	var mix := clampi(int((_noise.get_noise_2d(wx * 0.9 + 300.0, wz * 0.9) * 0.5 + 0.5) * 255.0), 0, 255)
	if h > HIGH:
		grass = HILL
	if woods[i] > 0.25:
		grass = WOODS
		over = MOOR
		mix = clampi(int((1.0 - woods[i]) * 200.0), 0, 255)
	match zone[i]:
		ZONE_SWAMP:
			grass = WOODS   # dark mulch, with reed grass on the higher bits
			over = MOOR
			mix = clampi(int((_bog_noise.get_noise_2d(wx * 2.2, wz * 2.2) * 0.5 + 0.5) * 255.0), 0, 255)
		ZONE_FIELDS:
			var u := field_u(Vector2(wx, wz))
			var s := posmod(floori(u), 3)
			var edge := minf(u - floorf(u), ceilf(u) - u) * field_stripe
			grass = STRIPE_BASE[s]
			over = STRIPE_OVER[s]
			mix = clampi(int((_noise.get_noise_2d(wx * 1.7, wz * 1.7) * 0.5 + 0.5) * 140.0), 0, 255)
			if edge < 2.0:
				grass = WOODS   # the hedge line between two fields
				over = MOOR
				mix = 90
		ZONE_PRAIRIE:
			grass = MOOR
			over = MEADOW
		ZONE_SCREE:
			grass = MOOR
			over = ROCK
			mix = clampi(205 + int(_noise.get_noise_2d(wx * 1.3, wz * 1.3) * 50.0), 0, 255)
	if slope > ROCK_SLOPE:
		over = ROCK
		mix = clampi(int((slope - ROCK_SLOPE) * 600.0), 0, 255)
	var half := float(config.get("road_width", 4.0)) * 0.5
	if road_dist[i] < half + 2.0:
		over = ROAD
		mix = clampi(int((1.0 - smoothstep(half - 0.5, half + 2.0, road_dist[i])) * 255.0), 0, 255)
	return [grass, over, mix]


func _read() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	config = parsed as Dictionary if parsed is Dictionary else {}
	size = int(config.get("size", 2048))
	step = float(config.get("step", 2.0))
	n = int(size / step)
	var own := config.get("places", {}) as Dictionary
	for p: Variant in Travel.map_data().get("places", []) as Array:
		var d := p as Dictionary
		var at := to_land(Vector2(float((d["pos"] as Array)[0]), float((d["pos"] as Array)[1])))
		if not inside(at) or not own.has(str(d["id"])):
			continue
		places.append({"id": str(d["id"]), "name": str(d.get("name", d["id"])), "at": at, "spec": own[str(d["id"])]})
		if (own[str(d["id"])] as Dictionary).has("stripe"):
			field_stripe = float((own[str(d["id"])] as Dictionary)["stripe"])
	for w: Variant in config.get("waters", []) as Array:
		var d := w as Dictionary
		var at := to_land(Vector2(float((d["at"] as Array)[0]), float((d["at"] as Array)[1])))
		waters.append({"id": str(d.get("id", "")), "kind": "lake", "at": at, "radius": float(d["radius"]),
			"depth": float(d["depth"]), "level": -1000.0})
	for w: Variant in config.get("swamps", []) as Array:
		var d := w as Dictionary
		var at := to_land(Vector2(float((d["at"] as Array)[0]), float((d["at"] as Array)[1])))
		waters.append({"id": str(d.get("id", "")), "kind": "swamp", "at": at, "radius": float(d["radius"]), "depth": 0.0,
			"level": float(d["level"]), "base": float(d.get("base", 3.0)), "amp": float(d.get("amp", 1.5))})


## The samples (x0, z0, width, height as a Rect2i, inclusive of its far edge) within `reach` metres of `at`.
func _box(at: Vector2, reach: float) -> Rect2i:
	var x0 := clampi(floori((at.x - reach) / step), 0, n - 1)
	var z0 := clampi(floori((at.y - reach) / step), 0, n - 1)
	var x1 := clampi(ceili((at.x + reach) / step), 0, n - 1)
	var z1 := clampi(ceili((at.y + reach) / step), 0, n - 1)
	return Rect2i(x0, z0, x1 - x0, z1 - z0)


## Hills, the north ridge, the lowlands, then the swamp, each place's lie, the crags and the lakes, then what stands where.
func _raise() -> void:
	var relief := config.get("relief", {}) as Dictionary
	var hills := float(relief.get("hills", 40.0))
	var scale_ := 1.0 / float(relief.get("hill_scale", 260.0))
	var ridge := float(relief.get("ridge", 60.0))
	var band := relief.get("ridge_band", [0.0, 0.2]) as Array
	var woods_cut := float(relief.get("woods", 0.1))
	var woods_scale := 1.0 / float(relief.get("woods_scale", 180.0))
	heights.resize(n * n)
	woods.resize(n * n)
	zone.resize(n * n)
	zone.fill(ZONE_NONE)
	road_dist.resize(n * n)
	road_dist.fill(1.0e6)
	# How much of the hills each sample keeps (lowlands lower them).
	var keep_hills := PackedFloat32Array()
	keep_hills.resize(n * n)
	keep_hills.fill(1.0)
	for low: Variant in relief.get("lowlands", []) as Array:
		var d := low as Dictionary
		var at := to_land(Vector2(float((d["at"] as Array)[0]), float((d["at"] as Array)[1])))
		var r := float(d["radius"])
		var drop := float(d["drop"])
		var box := _box(at, r)
		for z in range(box.position.y, box.end.y + 1):
			for x in range(box.position.x, box.end.x + 1):
				var t := 1.0 - smoothstep(0.0, r, Vector2(float(x) * step, float(z) * step).distance_to(at))
				keep_hills[z * n + x] *= 1.0 - drop * t
	for z in n:
		var wz := float(z) * step
		var north := 1.0 - smoothstep(float(band[0]), float(band[1]), wz / float(size))
		for x in n:
			var wx := float(x) * step
			var i := z * n + x
			var h := (_noise.get_noise_2d(wx * scale_ * 100.0, wz * scale_ * 100.0) * 0.5 + 0.5) * hills * keep_hills[i]
			var r := 1.0 - absf(_noise.get_noise_2d(wx * 0.6 + 900.0, wz * 0.6))
			h += north * r * r * ridge
			heights[i] = h
			woods[i] = smoothstep(woods_cut, woods_cut + 0.25, _woods_noise.get_noise_2d(wx * woods_scale * 100.0, wz * woods_scale * 100.0))
	for w: Dictionary in waters:
		if str(w["kind"]) == "swamp":
			_shape_swamp(w)
	for pl: Dictionary in places:
		_shape_place(pl)
	for pl: Dictionary in places:
		_shape_crags(pl)
	for w: Dictionary in waters:
		if str(w["kind"]) == "lake":
			_shape_lake(w)
	_mark_zones()


## A swamp: low ground with noise dips, under a flat water plane at its level, so the dips fill as pools and channels.
func _shape_swamp(w: Dictionary) -> void:
	var at := w["at"] as Vector2
	var r := float(w["radius"])
	var box := _box(at, r * 1.2)
	for z in range(box.position.y, box.end.y + 1):
		for x in range(box.position.x, box.end.x + 1):
			var p := Vector2(float(x) * step, float(z) * step)
			var t := 1.0 - smoothstep(r * 0.55, r * 1.15, p.distance_to(at))
			if t <= 0.0:
				continue
			var i := z * n + x
			var low := float(w["base"]) + _bog_noise.get_noise_2d(p.x * 0.9, p.y * 0.9) * float(w["amp"]) * 1.6
			heights[i] = lerpf(heights[i], low, t)
			if t > 0.4:
				zone[i] = ZONE_SWAMP
			woods[i] *= 1.0 - t


func _shape_place(pl: Dictionary) -> void:
	var spec := pl["spec"] as Dictionary
	var at := pl["at"] as Vector2
	var lie := str(spec.get("lie", "flat"))
	var r := float(spec.get("radius", 50))
	if lie == "fields":
		r = float(spec.get("fields", 280))
	var box := _box(at, r * 1.8)
	for z in range(box.position.y, box.end.y + 1):
		for x in range(box.position.x, box.end.x + 1):
			var p := Vector2(float(x) * step, float(z) * step)
			var d := p.distance_to(at)
			if d > r * 1.8:
				continue
			var i := z * n + x
			var t := 1.0 - smoothstep(r * 0.5, r * 1.8, d)
			match lie:
				"hollow":
					var floor_ := 16.0
					var bowl := floor_ - float(spec.get("depth", 10)) * (1.0 - smoothstep(0.0, r, d))
					heights[i] = lerpf(heights[i], bowl, t)
				"hill":
					var top := float(spec.get("top", 30.0)) + float(spec.get("rise", 30)) * (1.0 - smoothstep(0.0, r * 1.2, d))
					heights[i] = lerpf(heights[i], maxf(heights[i], top), t)
				"fields":
					var tf := 1.0 - smoothstep(r * 0.6, r * 1.5, d)
					heights[i] = lerpf(heights[i], 14.0 + _bog_noise.get_noise_2d(p.x * 0.4, p.y * 0.4) * 1.6, tf)
				"isle":
					var level := swamp_level_near(at)
					var ti := 1.0 - smoothstep(r * 0.7, r * 1.6, d)
					heights[i] = lerpf(heights[i], level + float(spec.get("rise", 1.3)) + _bog_noise.get_noise_2d(p.x * 0.5, p.y * 0.5) * 0.25, ti)
				"forest":
					var tfo := 1.0 - smoothstep(r * 0.5, r * 1.8, d)
					heights[i] = lerpf(heights[i], 12.0, tfo)
				_:
					heights[i] = lerpf(heights[i], float(spec.get("height", 12.0)), t)


## Crags: rock rising on one side of a place (spec crags: dir, rise, reach), as a ridge of its own.
func _shape_crags(pl: Dictionary) -> void:
	var spec := pl["spec"] as Dictionary
	if not spec.has("crags"):
		return
	var cr := spec["crags"] as Dictionary
	var at := pl["at"] as Vector2
	var dir := Vector2(float((cr["dir"] as Array)[0]), float((cr["dir"] as Array)[1])).normalized()
	var reach := float(cr.get("reach", 300.0))
	var rise := float(cr.get("rise", 70.0))
	var r0 := float(spec.get("radius", 50))
	var box := _box(at, reach * 1.5)
	for z in range(box.position.y, box.end.y + 1):
		for x in range(box.position.x, box.end.x + 1):
			var p := Vector2(float(x) * step, float(z) * step)
			var off := p - at
			var along := off.dot(dir)
			var across := absf(off.dot(dir.orthogonal()))
			var up := smoothstep(r0 * 0.8, reach * 0.8, along) * (1.0 - smoothstep(reach * 0.7, reach * 1.4, across))
			up *= 1.0 - smoothstep(reach * 0.9, reach * 1.5, along)
			if up <= 0.0:
				continue
			var r := 1.0 - absf(_noise.get_noise_2d(p.x * 0.7 + 400.0, p.y * 0.7 + 50.0))
			heights[z * n + x] += up * (0.35 + r * r * 0.9) * rise


func _shape_lake(w: Dictionary) -> void:
	var at := w["at"] as Vector2
	var r := float(w["radius"])
	var depth := float(w["depth"])
	var box := _box(at, r * 1.3)
	for z in range(box.position.y, box.end.y + 1):
		for x in range(box.position.x, box.end.x + 1):
			var p := Vector2(float(x) * step, float(z) * step)
			var t := 1.0 - smoothstep(r * 0.55, r * 1.25, p.distance_to(at))
			if t <= 0.0:
				continue
			var i := z * n + x
			heights[i] = lerpf(heights[i], minf(heights[i], 2.0) - depth * t, t)
	w["level"] = height_at(at) + depth * 0.65


## What each sample is part of (fields, forest, scree, prairie), and the woods cleared round the places and the lakes.
func _mark_zones() -> void:
	for pl: Dictionary in places:
		var spec := pl["spec"] as Dictionary
		var at := pl["at"] as Vector2
		var r := float(spec.get("radius", 50))
		var z_r := 0.0
		var kind := ZONE_NONE
		if spec.has("fields"):
			z_r = float(spec["fields"])
			kind = ZONE_FIELDS
		elif spec.has("forest"):
			z_r = float(spec["forest"])
			kind = ZONE_FOREST
		elif spec.has("scree"):
			z_r = float(spec["scree"])
			kind = ZONE_SCREE
		elif spec.has("prairie"):
			z_r = float(spec["prairie"])
			kind = ZONE_PRAIRIE
		var clear_r := float(spec.get("clear", z_r if kind != ZONE_FOREST and kind != ZONE_NONE else r))
		var box := _box(at, maxf(z_r, clear_r) * 1.5)
		for z in range(box.position.y, box.end.y + 1):
			for x in range(box.position.x, box.end.x + 1):
				var d := Vector2(float(x) * step, float(z) * step).distance_to(at)
				var i := z * n + x
				if kind != ZONE_NONE and d < z_r * 0.95 and zone[i] != ZONE_SWAMP:
					zone[i] = kind
				if kind == ZONE_FOREST:
					woods[i] = maxf(woods[i], 1.0 - smoothstep(z_r * 0.7, z_r, d))
				woods[i] *= smoothstep(clear_r * 0.8, clear_r * 1.4, d)
	# High ground the swamp's falloff reached (Maidenmist's rise) is not swamp.
	for w: Dictionary in waters:
		if str(w["kind"]) != "swamp":
			continue
		var box := _box(w["at"] as Vector2, float(w["radius"]) * 1.2)
		for z in range(box.position.y, box.end.y + 1):
			for x in range(box.position.x, box.end.x + 1):
				var i := z * n + x
				if zone[i] == ZONE_SWAMP and heights[i] > float(w["level"]) + 3.2 + float(w["amp"]):
					zone[i] = ZONE_NONE
					woods[i] = maxf(woods[i], 0.0)
	for w: Dictionary in waters:
		if str(w["kind"]) != "lake":
			continue
		var at := w["at"] as Vector2
		var r := float(w["radius"])
		var box := _box(at, r * 1.4)
		for z in range(box.position.y, box.end.y + 1):
			for x in range(box.position.x, box.end.x + 1):
				woods[z * n + x] *= smoothstep(r, r * 1.3, Vector2(float(x) * step, float(z) * step).distance_to(at))


## The travel map's roads between places on the land, each a wandering track: its line bends by noise between its ends,
## and the ground along it is eased to the line's own smoothed height, so it climbs at a walking slope and cuts a bench
## into a hillside (and runs on a causeway above the swamp's water).
func _lay_roads() -> void:
	var by_id := {}
	for pl: Dictionary in places:
		by_id[pl["id"]] = pl["at"]
	var reach := float(config.get("road_reach", 14.0))
	var cells := ceili(reach / step)
	for r: Variant in Travel.map_data().get("roads", []) as Array:
		var d := r as Dictionary
		if not by_id.has(str(d["from"])) or not by_id.has(str(d["to"])):
			continue
		var line := _wander(by_id[str(d["from"])] as Vector2, by_id[str(d["to"])] as Vector2)
		roads.append(line)
		road_ids.append(str(d["id"]))
		# The line's height, smoothed along it (a point every `step` metres is enough).
		var pts := PackedVector2Array()
		for k in range(0, line.size(), maxi(int(step), 1)):
			pts.append(line[k])
		var raw := PackedFloat32Array()
		for p: Vector2 in pts:
			raw.append(height_at(p))
		var smooth := PackedFloat32Array()
		var win := roundi(40.0 / step)
		for i in raw.size():
			var sum := 0.0
			var cnt := 0
			for k in range(maxi(i - win, 0), mini(i + win + 1, raw.size())):
				sum += raw[k]
				cnt += 1
			var hh := sum / float(cnt)
			if zone[cell_of(pts[i])] == ZONE_SWAMP:
				hh = maxf(hh, swamp_level_near(pts[i]) + 0.55)   # a causeway above the water
			smooth.append(hh)
		var targets := {}
		for i in pts.size():
			var p := pts[i]
			var cx := roundi(p.x / step)
			var cz := roundi(p.y / step)
			for dz in range(-cells, cells + 1):
				for dx in range(-cells, cells + 1):
					var x := cx + dx
					var z := cz + dz
					if x < 0 or z < 0 or x >= n or z >= n:
						continue
					var dist := Vector2(float(x) * step, float(z) * step).distance_to(p)
					var j := z * n + x
					if dist < road_dist[j]:
						road_dist[j] = dist
						targets[j] = smooth[i]
		for j: int in targets:
			var t := 1.0 - smoothstep(float(config.get("road_width", 4.0)) * 0.5, reach, road_dist[j])
			heights[j] = lerpf(heights[j], float(targets[j]) - 0.15, t)
			woods[j] *= 1.0 - t


## A road's line from `a` to `b` at a metre a step, bent sideways by noise (never at its ends, never off the land).
func _wander(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var length := a.distance_to(b)
	var side := (b - a).normalized().orthogonal()
	var steps := maxi(int(length), 2)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var bend := _noise.get_noise_2d(a.x * 0.01 + t * length * 0.004, a.y * 0.01) * length * 0.18 * sin(t * PI)
		var p := a.lerp(b, t) + side * bend
		out.append(Vector2(clampf(p.x, 2.0, float(size) - 3.0), clampf(p.y, 2.0, float(size) - 3.0)))
	return out
