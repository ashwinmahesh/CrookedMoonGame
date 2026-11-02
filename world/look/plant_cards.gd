class_name PlantCards
extends RefCounted
## Realistic ground plants built in code from Poly Haven's cut-out leaf pictures (CC0: fern_02's fronds and
## grass_medium_02's blades, art/plants/real/SOURCE.md): a clump of grass is a dozen curved blades, a fern a ring of
## arching fronds, each one a thin strip of a few triangles carrying one leaf's picture. Flora draws these by the
## thousand, so each stays under 200 triangles. RealTrees puts them under the painted plants' ids
## (art/plants/real_trees.json `cards`) and gives them the wind shader. Their size is the painted plant's (the
## manifest's `size`), so they stand where the painted ones did.
##
## Every vertex carries what real_leaf.gdshader reads: UV2 (x how free it is in the wind, y a phase for its leaf),
## COLOR alpha (how much light reaches it: the foot of a plant is darker) and a normal leaning up and out, so a clump
## takes the light as one soft volume.

const SIDES := 3   ## strips along a blade or frond: enough to bend in the wind and curve over

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _uv2s := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _rng := RandomNumberGenerator.new()


## The mesh for plant `id`: `spec` (a `cards` entry of real_trees.json), `size` the painted plant's [width, height, depth],
## `rects` the picture's named leaf rectangles ([x0, y0, x1, y1] as shares of the picture), or null if `spec` is unknown.
static func build(id: String, spec: Dictionary, size: Vector3, rects: Dictionary) -> ArrayMesh:
	var c := PlantCards.new()
	c._rng.seed = hash(id)
	var list: Array = []
	for r: Variant in spec.get("leaves", []) as Array:
		var named := rects.get(str(r), []) as Array
		if named.size() == 4:
			list.append(named)
	if list.is_empty():
		return null
	match str(spec.get("build", "")):
		"grass":
			c._grass(spec, size, list)
		"fern":
			c._fern(spec, size, list)
		_:
			return null
	if str(spec.get("head", "")) != "":
		c._heads(spec, size, rects.get(str(spec["head"]), []) as Array)
	c._fit_width(size.x * 1.15)
	return c._mesh()


## Draws in the plant in if it spreads wider than `limit` (a wide blade leaning out reaches past the painted plant's size).
func _fit_width(limit: float) -> void:
	var reach := 0.0
	for v in _verts:
		reach = maxf(reach, maxf(absf(v.x), absf(v.z)) * 2.0)
	if reach <= limit:
		return
	var k := limit / reach
	for i in _verts.size():
		_verts[i].x *= k
		_verts[i].z *= k


func _mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A strip along `pts` (feet first), `width` wide at `side` (a unit vector across it) with a leaf picture `rect` on it,
## its base at the rect's bottom edge. `shade` is the light at its foot and tip, `phase` its leaf's phase in the wind.
func _strip(pts: Array[Vector3], side: Vector3, width: float, taper: float, rect: Array, normal: Vector3, shade: Vector2, phase: float, tint: Color) -> void:
	var first := _verts.size()
	var n := pts.size()
	for i in n:
		var t := float(i) / float(n - 1)
		var half := width * 0.5 * lerpf(1.0, taper, t * t)
		for s in 2:
			var x := -half if s == 0 else half
			_verts.append(pts[i] + side * x)
			_normals.append(normal)
			_uvs.append(Vector2(lerpf(float(rect[0]), float(rect[2]), float(s)), lerpf(float(rect[3]), float(rect[1]), t)))
			_uv2s.append(Vector2(t, phase))
			_colors.append(Color(tint.r, tint.g, tint.b, lerpf(shade.x, shade.y, t)))
	for i in n - 1:
		var a := first + i * 2
		_indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))


## A clump of blades: `blades` of them, up to the painted plant's height, leaning out from the middle.
func _grass(spec: Dictionary, size: Vector3, rects: Array) -> void:
	var count := int(spec.get("blades", 12))
	var lean := float(spec.get("lean", 0.45))
	var spread := float(spec.get("spread", 0.6)) * size.x * 0.5
	var low := float(spec.get("low", 0.55))
	var wide := float(spec.get("wide", 1.0))
	for b in count:
		var rect := rects[_rng.randi() % rects.size()] as Array
		var h := size.y * _rng.randf_range(low, 1.0)
		var aspect := (float(rect[2]) - float(rect[0])) / maxf(float(rect[3]) - float(rect[1]), 0.01)
		var ang := _rng.randf() * TAU
		var r := spread * sqrt(_rng.randf())
		var foot := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		# Out from the middle, give or take; across the blade at a random turn from that.
		var out := ang + _rng.randf_range(-0.7, 0.7)
		var dir := Vector3(cos(out), 0.0, sin(out))
		var side := dir.rotated(Vector3.UP, PI * 0.5 + _rng.randf_range(-0.6, 0.6))
		var tilt := _rng.randf_range(0.08, 1.0) * lean
		var pts: Array[Vector3] = []
		var at := foot
		var pitch := tilt
		for i in SIDES + 1:
			pts.append(at)
			# Each stretch leans a little further over than the one below it.
			at += (Vector3.UP * cos(pitch) + dir * sin(pitch)) * (h / float(SIDES))
			pitch += 0.35 * lean + 0.1
		var tint := Color.WHITE.darkened(_rng.randf_range(0.0, 0.18))
		var up_out := (Vector3.UP * 0.8 + dir * 0.45).normalized()
		_strip(pts, side, h * aspect * wide, 0.5, rect, up_out, Vector2(0.55, 1.0), _rng.randf(), tint)


## A ring of arching fronds: each rises from the middle, then droops, and the whole is fitted to the painted fern's size.
func _fern(spec: Dictionary, size: Vector3, rects: Array) -> void:
	var count := int(spec.get("fronds", 9))
	var wide := float(spec.get("wide", 1.0))
	var rise := float(spec.get("rise", 0.9))
	var reach := 0.0
	var top := 0.0
	var frond_lists: Array = []
	for f in count:
		var rect := rects[f % rects.size()] as Array
		var ang := (float(f) + _rng.randf_range(-0.3, 0.3)) / float(count) * TAU
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var length := _rng.randf_range(0.75, 1.0)
		var pitch := _rng.randf_range(0.5, 1.15) * rise
		var pts: Array[Vector3] = []
		var at := dir * 0.02
		for i in 5:
			pts.append(at)
			at += (Vector3.UP * sin(pitch) + dir * cos(pitch)) * (length / 4.0)
			pitch -= 0.55 + _rng.randf() * 0.2
		for p in pts:
			reach = maxf(reach, Vector2(p.x, p.z).length())
			top = maxf(top, p.y)
		frond_lists.append([pts, rect, dir, length])
	# Fitted to the painted fern: half its width of reach, its height of rise.
	var kx := size.x * 0.5 / maxf(reach, 0.01)
	var ky := size.y / maxf(top, 0.01)
	for rec: Array in frond_lists:
		var pts := rec[0] as Array[Vector3]
		var rect := rec[1] as Array
		var dir := rec[2] as Vector3
		var length := float(rec[3])
		var scaled: Array[Vector3] = []
		for p in pts:
			scaled.append(Vector3(p.x * kx, p.y * ky, p.z * kx))
		var aspect := (float(rect[2]) - float(rect[0])) / maxf(float(rect[3]) - float(rect[1]), 0.01)
		var side := Vector3(-dir.z, _rng.randf_range(-0.25, 0.25), dir.x).normalized()
		var span := size.x * 0.5 * length
		var up_out := (Vector3.UP * 0.75 + dir * 0.3).normalized()
		_strip(scaled, side, span * aspect * 1.9 * wide, 0.9, rect, up_out, Vector2(0.45, 1.0), _rng.randf(), Color.WHITE.darkened(_rng.randf_range(0.0, 0.15)))
	# The strips' width tilts some of them below the ground and above the painted fern's top: stand the whole fern on the
	# ground at the painted height.
	var low := 1e9
	var high := -1e9
	for v in _verts:
		low = minf(low, v.y)
		high = maxf(high, v.y)
	for i in _verts.size():
		_verts[i].y = (_verts[i].y - low) / maxf(high - low, 0.001) * size.y

## A few seed heads (cattails): small brown spindles on the tallest stalks, coloured from a patch of the picture.
func _heads(spec: Dictionary, size: Vector3, rect: Array) -> void:
	if rect.size() != 4:
		return
	var n := int(spec.get("heads", 3))
	var u := lerpf(float(rect[0]), float(rect[2]), 0.5)
	var v := lerpf(float(rect[1]), float(rect[3]), 0.5)
	var r := size.x * 0.035
	var len := size.y * 0.2
	for h in n:
		var ang := _rng.randf() * TAU
		var rr := size.x * 0.5 * 0.35 * sqrt(_rng.randf())
		var base := Vector3(cos(ang) * rr, size.y * _rng.randf_range(0.6, 0.78), sin(ang) * rr)
		var sides := 6
		var first := _verts.size()
		for ring in 3:
			var t := float(ring) / 2.0
			var rad := r * (1.0 if ring == 1 else 0.15)
			for s in sides:
				var a := float(s) / float(sides) * TAU
				var out := Vector3(cos(a), 0.0, sin(a))
				_verts.append(base + Vector3.UP * (t * len) + out * rad)
				_normals.append(out)
				_uvs.append(Vector2(u, v))
				_uv2s.append(Vector2(0.9, 0.3))
				_colors.append(Color(0.42, 0.27, 0.16, 0.9))
		for ring in 2:
			for s in sides:
				var a := first + ring * sides + s
				var b := first + ring * sides + (s + 1) % sides
				_indices.append_array(PackedInt32Array([a, b, a + sides, b, b + sides, a + sides]))
