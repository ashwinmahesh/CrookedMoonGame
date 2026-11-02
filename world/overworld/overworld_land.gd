class_name OverworldLand
extends RefCounted
## The overworld pilot's land, worked out once from art/overworld/overworld.json and the travel map (Travel.map_data):
## a height for every metre of the window, which ground each metre shows, where the roads run and where the woods
## stand. Rolling hills from noise, a ridge along the north, each place's hollow or hill, a lake basin, and the roads
## between the places cut into the slopes as worn tracks. OverworldTerrain hands it to Terrain3D; OverworldView plants on
## it. Pure data (no nodes), so a test can check it without drawing anything.

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

var config: Dictionary = {}
var size := 1024
var heights := PackedFloat32Array()   ## metres, row by row (z then x)
var road_dist := PackedFloat32Array() ## metres to the nearest road's middle (a large number far from any road)
var woods := PackedFloat32Array()     ## 0..1, how deep in the woods each metre is
var places: Array[Dictionary] = []    ## {id, name, at: Vector2 (metres), spec}
var roads: Array[PackedVector2Array] = []
var lake_level := -1000.0
var lake_at := Vector2.ZERO
var lake_radius := 0.0
var _noise := FastNoiseLite.new()
var _woods_noise := FastNoiseLite.new()


static func build(seed_: int = 1931) -> OverworldLand:
	var land := OverworldLand.new()
	land._read()
	land._noise.seed = seed_
	land._noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	land._noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	land._noise.fractal_octaves = 5
	land._woods_noise.seed = seed_ + 7
	land._woods_noise.fractal_octaves = 3
	land._raise()
	land._lay_roads()
	return land


## A travel map position (0-1 across its picture) as metres on the land.
func to_land(pos: Vector2) -> Vector2:
	var w := config.get("window", [0.0, 0.0, 1.0, 1.0]) as Array
	return Vector2((pos.x - float(w[0])) / (float(w[2]) - float(w[0])), (pos.y - float(w[1])) / (float(w[3]) - float(w[1]))) * float(size)


func inside(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < float(size) and p.y < float(size)


func height_at(p: Vector2) -> float:
	var x := clampi(int(p.x), 0, size - 1)
	var z := clampi(int(p.y), 0, size - 1)
	return heights[z * size + x]


## Rise over run at a metre, from its neighbours.
func slope_at(x: int, z: int) -> float:
	var x0 := maxi(x - 1, 0)
	var x1 := mini(x + 1, size - 1)
	var z0 := maxi(z - 1, 0)
	var z1 := mini(z + 1, size - 1)
	var dx := (heights[z * size + x1] - heights[z * size + x0]) / float(x1 - x0)
	var dz := (heights[z1 * size + x] - heights[z0 * size + x]) / float(z1 - z0)
	return sqrt(dx * dx + dz * dz)


## Which ground a metre shows: [base, overlay, blend 0-255].
func ground_at(x: int, z: int) -> Array[int]:
	var i := z * size + x
	var h := heights[i]
	var slope := slope_at(x, z)
	var grass := MOOR
	var over := MEADOW
	var mix := clampi(int((_noise.get_noise_2d(x * 0.9 + 300.0, z * 0.9) * 0.5 + 0.5) * 255.0), 0, 255)
	if h > HIGH:
		grass = HILL
	if woods[i] > 0.25:
		grass = WOODS
		over = MOOR
		mix = clampi(int((1.0 - woods[i]) * 200.0), 0, 255)
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
	size = int(config.get("size", 1024))
	var own := config.get("places", {}) as Dictionary
	for p: Variant in Travel.map_data().get("places", []) as Array:
		var d := p as Dictionary
		var at := to_land(Vector2(float((d["pos"] as Array)[0]), float((d["pos"] as Array)[1])))
		if not inside(at) or not own.has(str(d["id"])):
			continue
		places.append({"id": str(d["id"]), "name": str(d.get("name", d["id"])), "at": at, "spec": own[str(d["id"])]})
	var lake := config.get("lake", {}) as Dictionary
	if not lake.is_empty():
		lake_at = to_land(Vector2(float((lake["at"] as Array)[0]), float((lake["at"] as Array)[1])))
		lake_radius = float(lake["radius"])


## Hills, the north ridge, the places' hollows and hills and the lake's basin.
func _raise() -> void:
	var relief := config.get("relief", {}) as Dictionary
	var hills := float(relief.get("hills", 40.0))
	var scale_ := 1.0 / float(relief.get("hill_scale", 260.0))
	var ridge := float(relief.get("ridge", 60.0))
	var band := relief.get("ridge_band", [0.0, 0.2]) as Array
	var woods_cut := float(relief.get("woods", 0.1))
	var woods_scale := 1.0 / float(relief.get("woods_scale", 180.0))
	heights.resize(size * size)
	woods.resize(size * size)
	road_dist.resize(size * size)
	road_dist.fill(1.0e6)
	for z in size:
		var north := 1.0 - smoothstep(float(band[0]), float(band[1]), float(z) / float(size))
		for x in size:
			var n := _noise.get_noise_2d(x * scale_ * 100.0, z * scale_ * 100.0)
			var h := (n * 0.5 + 0.5) * hills
			var r := 1.0 - absf(_noise.get_noise_2d(x * 0.6 + 900.0, z * 0.6))
			h += north * r * r * ridge
			var p := Vector2(x, z)
			var w := 0.0
			for pl: Dictionary in places:
				h = _shape_place(h, p, pl)
			if lake_radius > 0.0:
				var t := 1.0 - smoothstep(lake_radius * 0.55, lake_radius * 1.25, p.distance_to(lake_at))
				h = lerpf(h, minf(h, 2.0) - float((config["lake"] as Dictionary)["depth"]) * t, t)
			w = smoothstep(woods_cut, woods_cut + 0.25, _woods_noise.get_noise_2d(x * woods_scale * 100.0, z * woods_scale * 100.0))
			heights[z * size + x] = h
			woods[z * size + x] = w
	if lake_radius > 0.0:
		lake_level = height_at(lake_at) + float((config["lake"] as Dictionary)["depth"]) * 0.65
	# Clear the woods off the places and the lake.
	for z in size:
		for x in size:
			var p := Vector2(x, z)
			var keep := 1.0
			for pl: Dictionary in places:
				keep = minf(keep, smoothstep(float((pl["spec"] as Dictionary).get("radius", 50)) * 0.8,
					float((pl["spec"] as Dictionary).get("radius", 50)) * 1.4, p.distance_to(pl["at"] as Vector2)))
			if lake_radius > 0.0:
				keep = minf(keep, smoothstep(lake_radius, lake_radius * 1.3, p.distance_to(lake_at)))
			woods[z * size + x] *= keep


func _shape_place(h: float, p: Vector2, pl: Dictionary) -> float:
	var spec := pl["spec"] as Dictionary
	var r := float(spec.get("radius", 50))
	var d := p.distance_to(pl["at"] as Vector2)
	if d > r * 1.8:
		return h
	var t := 1.0 - smoothstep(r * 0.5, r * 1.8, d)
	match str(spec.get("lie", "flat")):
		"hollow":
			var floor_ := 16.0
			var bowl := floor_ - float(spec.get("depth", 10)) * (1.0 - smoothstep(0.0, r, d))
			return lerpf(h, bowl, t)
		"hill":
			var top := 30.0 + float(spec.get("rise", 30)) * (1.0 - smoothstep(0.0, r * 1.2, d))
			return lerpf(h, maxf(h, top), t)
	return lerpf(h, 12.0, t)


## The travel map's roads between places on the land, each a wandering track: its line bends by noise between its ends,
## and the ground along it is eased to the line's own smoothed height, so it climbs at a walking slope and cuts a bench
## into a hillside.
func _lay_roads() -> void:
	var by_id := {}
	for pl: Dictionary in places:
		by_id[pl["id"]] = pl["at"]
	var reach := float(config.get("road_reach", 14.0))
	for r: Variant in Travel.map_data().get("roads", []) as Array:
		var d := r as Dictionary
		if not by_id.has(str(d["from"])) or not by_id.has(str(d["to"])):
			continue
		var line := _wander(by_id[str(d["from"])] as Vector2, by_id[str(d["to"])] as Vector2)
		roads.append(line)
		# The line's height, smoothed along it.
		var raw := PackedFloat32Array()
		for p: Vector2 in line:
			raw.append(height_at(p))
		var smooth := PackedFloat32Array()
		for i in raw.size():
			var sum := 0.0
			var n := 0
			for k in range(maxi(i - 40, 0), mini(i + 41, raw.size())):
				sum += raw[k]
				n += 1
			smooth.append(sum / float(n))
		var targets := {}
		for i in line.size():
			var p := line[i]
			for dz in range(-int(reach), int(reach) + 1):
				for dx in range(-int(reach), int(reach) + 1):
					var x := int(p.x) + dx
					var z := int(p.y) + dz
					if x < 0 or z < 0 or x >= size or z >= size:
						continue
					var dist := Vector2(x, z).distance_to(p)
					var j := z * size + x
					if dist < road_dist[j]:
						road_dist[j] = dist
						targets[j] = smooth[i]
		for j: int in targets:
			var t := 1.0 - smoothstep(float(config.get("road_width", 4.0)) * 0.5, reach, road_dist[j])
			heights[j] = lerpf(heights[j], float(targets[j]) - 0.15, t)
			woods[j] *= 1.0 - t


## A road's line from `a` to `b` at a metre a step, bent sideways by noise (never at its ends).
func _wander(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var length := a.distance_to(b)
	var side := (b - a).normalized().orthogonal()
	var steps := maxi(int(length), 2)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var bend := _noise.get_noise_2d(a.x * 0.01 + t * length * 0.004, a.y * 0.01) * length * 0.18 * sin(t * PI)
		out.append(a.lerp(b, t) + side * bend)
	return out
