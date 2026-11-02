class_name SmallProps
extends RefCounted
## The small things Act 1's rooms hold that no catalog picture draws (the look lane, plan 8.4): a jar of marbles, a whiskey bottle, a
## jug of haint hooch, a pink envelope, an iron ring, a whistle in the mud, a frayed rope, loose boards, a hay loft ladder, a curved
## stair, a cold place on the floor and black-veined mist. Each is a few meshes made here in code from palette colours, built through
## CampaignLook.place_special for a catalog entry whose `set_piece` is "small:<kind>" (its `art` stays the picture that stands in where it
## cannot be built). Units: 1 is five feet, so a bottle is 0.25 high. Cosmetic only: no square is claimed, moved or blocked.

const KINDS: Array[String] = ["marble_jar", "whiskey_bottle", "haint_hooch", "pink_envelope", "iron_ring", "whistle", "frayed_rope",
	"loose_boards", "hay_ladder", "curved_stair", "cold_place", "curse_mist"]


## How much bigger than life the smallest are drawn, so they read at the play camera (a marble jar is a hand high).
const READABLE := {"marble_jar": 1.7, "whiskey_bottle": 1.7, "haint_hooch": 1.6, "pink_envelope": 1.8, "iron_ring": 1.3, "whistle": 2.4}


## Builds `kind` over `at` (the square's middle, on its floor) under `parent`. `wall` is the side of the square a wall stands on
## (Vector2i.ZERO if none), for what leans or hangs on one. Returns the holder, or null for a kind not made here.
static func build(kind: String, parent: Node3D, at: Vector3, seed_: int, wall: Vector2i = Vector2i.ZERO) -> Node3D:
	if not kind in KINDS:
		return null
	var holder := Node3D.new()
	holder.name = "Small_" + kind
	holder.position = at
	holder.set_meta("set_piece", "small:" + kind)
	holder.scale = Vector3.ONE * float(READABLE.get(kind, 1.0))
	holder.set_meta("nature", true)
	parent.add_child(holder)
	match kind:
		"marble_jar":
			_marble_jar(holder, seed_, wall)
		"whiskey_bottle":
			_whiskey_bottle(holder, seed_, wall)
		"haint_hooch":
			_haint_hooch(holder, seed_, wall)
		"pink_envelope":
			_pink_envelope(holder, seed_, wall)
		"iron_ring":
			_iron_ring(holder, seed_, wall)
		"whistle":
			_whistle(holder, seed_, wall)
		"frayed_rope":
			_frayed_rope(holder, seed_, wall)
		"loose_boards":
			_loose_boards(holder, seed_, wall)
		"hay_ladder":
			_hay_ladder(holder, seed_, wall)
		"curved_stair":
			_curved_stair(holder, seed_, wall)
		"cold_place":
			_cold_place(holder, seed_, wall)
		"curse_mist":
			_curse_mist(holder, seed_, wall)
	return holder


# --- Parts -------------------------------------------------------------------------------------------------------------

static func _mi(holder: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(m)
	return m


static func _box(holder: Node3D, size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(holder, b, mat, pos, rot)


static func _cyl(holder: Node3D, radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 1
	return _mi(holder, c, mat, pos, rot)


static func _ball(holder: Node3D, radius: float, mat: Material, pos: Vector3, squash: float = 1.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 * squash
	s.radial_segments = 14
	s.rings = 8
	return _mi(holder, s, mat, pos)


static func _ring(holder: Node3D, major: float, minor: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = major - minor
	t.outer_radius = major + minor
	t.rings = 20
	t.ring_segments = 8
	return _mi(holder, t, mat, pos, rot)


## A palette colour as a lit cel material.
static func _cel(name: String) -> Material:
	return Look.cel(name)


## A palette colour see-through (glass, mist): lit, with an alpha.
static func _glass(name: String, alpha: float, glow: float = 0.0) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(Look.color(name), alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Look.color(name)
		m.emission_energy_multiplier = glow
	return m


## A palette colour that shines of itself.
static func _glow(name: String, energy: float) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Look.color(name)
	m.emission_enabled = true
	m.emission = Look.color(name)
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	return m


static func _rng(seed_: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_ + 4242
	return r


# --- The things --------------------------------------------------------------------------------------------------------

## A glass jar of marbles with a pewter lid.
static func _marble_jar(h: Node3D, seed_: int, _wall: Vector2i) -> void:
	_cyl(h, 0.105, 0.24, _glass("mist_blue", 0.28), Vector3(0, 0.12, 0))
	_cyl(h, 0.112, 0.035, _cel("pewter"), Vector3(0, 0.255, 0))
	var colours := ["crimson", "moon_green", "orchid", "candle", "moon_blue", "flame", "bone"]
	var r := _rng(seed_)
	for i in 16:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * 0.07
		_ball(h, 0.03, _cel(str(colours[i % colours.size()])), Vector3(cos(a) * d, 0.035 + float(floori(float(i) / 6.0)) * 0.055, sin(a) * d))


## An empty amber bottle with a paper label.
static func _whiskey_bottle(h: Node3D, _seed: int, _wall: Vector2i) -> void:
	_cyl(h, 0.055, 0.2, _glass("rust", 0.8, 0.1), Vector3(0, 0.1, 0))
	_cyl(h, 0.022, 0.1, _glass("rust", 0.8, 0.1), Vector3(0, 0.25, 0))
	_cyl(h, 0.027, 0.02, _cel("bone_dark"), Vector3(0, 0.31, 0))
	_box(h, Vector3(0.09, 0.07, 0.006), _cel("parchment"), Vector3(0, 0.1, 0.056))


## A stoneware jug with three crossed marks, giving off a thin ghostly green.
static func _haint_hooch(h: Node3D, _seed: int, _wall: Vector2i) -> void:
	_cyl(h, 0.09, 0.2, _cel("tan"), Vector3(0, 0.1, 0))
	_ball(h, 0.095, _cel("tan"), Vector3(0, 0.2, 0), 0.7)
	_cyl(h, 0.035, 0.07, _cel("tan"), Vector3(0, 0.3, 0))
	_ring(h, 0.05, 0.013, _cel("tan"), Vector3(0.1, 0.2, 0), Vector3(PI / 2.0, 0, PI / 2.0))
	for i in 3:
		var x := -0.045 + float(i) * 0.045
		for a: float in [PI / 4.0, -PI / 4.0]:
			_box(h, Vector3(0.05, 0.008, 0.006), _cel("ink"), Vector3(x, 0.13, 0.092), Vector3(0, 0, a))
	h.add_child(SetPieceLight.make("HoochGlow", Vector3(0, 0.3, 0.1), Look.color("moon_green"), 0.25, 1.6, h))


## A bright pink envelope lying on a surface, with a wax seal.
static func _pink_envelope(h: Node3D, seed_: int, _wall: Vector2i) -> void:
	var turn := float(seed_ % 40 - 20) * PI / 180.0
	_box(h, Vector3(0.3, 0.014, 0.2), _glow("rose", 0.35), Vector3(0, 0.007, 0), Vector3(0, turn, 0))
	_box(h, Vector3(0.3, 0.006, 0.075), _cel("orchid"), Vector3(0, 0.017, -0.06), Vector3(0, turn, 0))
	_cyl(h, 0.022, 0.01, _cel("crimson"), Vector3(0, 0.02, -0.01).rotated(Vector3.UP, turn), Vector3(0, turn, 0))


## An iron ring hanging from a bracket.
static func _iron_ring(h: Node3D, _seed: int, wall: Vector2i) -> void:
	_box(h, Vector3(0.16, 0.16, 0.04), _cel("slate"), Vector3(0, 0.55, 0))
	_ring(h, 0.17, 0.032, _cel("stone_deep"), Vector3(0, 0.38, 0.04), Vector3(PI / 2.0, 0, 0))
	_cyl(h, 0.03, 0.06, _cel("pewter"), Vector3(0, 0.55, 0.03), Vector3(PI / 2.0, 0, 0))
	if wall != Vector2i.ZERO:
		h.rotation.y = atan2(float(wall.x), float(wall.y)) + PI
		h.position += Vector3(float(wall.x), 0, float(wall.y)) * 0.42


## A small tin whistle half in the mud, with a glint.
static func _whistle(h: Node3D, seed_: int, _wall: Vector2i) -> void:
	var turn := float(seed_ % 90) * PI / 180.0
	_cyl(h, 0.014, 0.13, _cel("silver"), Vector3(0, 0.012, 0), Vector3(0, turn, PI / 2.0))
	_box(h, Vector3(0.03, 0.02, 0.022), _cel("pewter"), Vector3(0.06, 0.016, 0).rotated(Vector3.UP, -turn), Vector3(0, turn, 0))
	_ring(h, 0.015, 0.004, _cel("pewter"), Vector3(-0.07, 0.014, 0).rotated(Vector3.UP, -turn), Vector3(PI / 2.0, turn, 0))
	h.add_child(SetPieceLight.make("WhistleGlint", Vector3(0, 0.12, 0), Look.color("moonlight"), 0.35, 1.2, h))


## A rope hanging down from the ceiling with a frayed end.
static func _frayed_rope(h: Node3D, seed_: int, _wall: Vector2i) -> void:
	_cyl(h, 0.024, 1.5, _cel("tan"), Vector3(0, 1.65, 0))
	for k in 12:
		_ring(h, 0.026, 0.006, _cel("umber"), Vector3(0, 0.95 + float(k) * 0.12, 0), Vector3(deg_to_rad(float((k * 37 + seed_) % 40) - 20.0), 0, 0))
	var r := _rng(seed_)
	for i in 6:
		var a := float(i) * TAU / 6.0
		_cyl(h, 0.007, 0.16, _cel("tan"), Vector3(cos(a) * 0.03, 0.88, sin(a) * 0.03), Vector3(r.randf_range(0.2, 0.5) * cos(a), 0, r.randf_range(0.2, 0.5) * sin(a)))


## Loose floorboards, one lifted over the dark below.
static func _loose_boards(h: Node3D, seed_: int, _wall: Vector2i) -> void:
	_box(h, Vector3(0.56, 0.01, 0.46), _cel("void"), Vector3(0, 0.006, 0))
	var wood := ["walnut", "peat", "umber", "walnut"]
	for i in 4:
		var lift := 0.0
		var tilt := 0.0
		if i == 1:
			lift = 0.045
			tilt = deg_to_rad(10.0)
		_box(h, Vector3(0.56, 0.03, 0.1), _cel(str(wood[i])), Vector3(0, 0.02 + lift, -0.17 + float(i) * 0.115), Vector3(tilt, deg_to_rad(float((seed_ + i * 7) % 7 - 3)), 0))


## A hay loft ladder, leaning on the wall beside it.
static func _hay_ladder(h: Node3D, _seed: int, wall: Vector2i) -> void:
	var lean := deg_to_rad(11.0)
	var ladder := Node3D.new()
	ladder.rotation.x = -lean   # (the top tips toward +z, the wall side)
	h.add_child(ladder)
	for x: float in [-0.16, 0.16]:
		_box(ladder, Vector3(0.04, 1.9, 0.04), _cel("walnut"), Vector3(x, 0.95, 0))
	for k in 8:
		_box(ladder, Vector3(0.32, 0.028, 0.028), _cel("umber"), Vector3(0, 0.2 + float(k) * 0.22, 0))
	h.rotation.y = atan2(float(wall.x), float(wall.y)) if wall != Vector2i.ZERO else 0.0
	if wall != Vector2i.ZERO:
		h.position += Vector3(float(wall.x), 0, float(wall.y)) * 0.38


## The curved stair of the Crooked House's hall: a short spiral of steps round a leaning post.
static func _curved_stair(h: Node3D, _seed: int, _wall: Vector2i) -> void:
	var post := _cyl(h, 0.07, 1.5, _cel("walnut"), Vector3(0, 0.75, 0))
	post.rotation = Vector3(deg_to_rad(4.0), 0, deg_to_rad(-5.0))
	var steps := 9
	for i in steps:
		var a := float(i) * (PI * 1.15 / float(steps - 1)) - PI * 0.6
		var y := 0.09 + float(i) * 0.14
		var pivot := Node3D.new()
		pivot.rotation.y = a
		pivot.position = Vector3(0, y, 0)
		h.add_child(pivot)
		_box(pivot, Vector3(0.5, 0.07, 0.26), _cel("peat" if i % 2 == 0 else "walnut"), Vector3(0.3, 0, 0))
		if i % 3 == 0:
			_cyl(pivot, 0.018, 0.5, _cel("umber"), Vector3(0.52, 0.25, 0))   # a baluster


## A cold place on the boards: a pale ring on the floor, wisps rising and a faint cold light.
static func _cold_place(h: Node3D, seed_: int, _wall: Vector2i) -> void:
	_cyl(h, 0.4, 0.004, _glass("mist_blue", 0.2, 0.5), Vector3(0, 0.004, 0))
	_ring(h, 0.4, 0.012, _glass("moon_blue", 0.45, 0.8), Vector3(0, 0.008, 0))
	var r := _rng(seed_)
	for i in 3:
		var a := float(i) * TAU / 3.0 + r.randf() * 0.6
		var w := _cyl(h, 0.05, 0.7 + float(i) * 0.2, _glass("mist_blue", 0.16, 0.6), Vector3(cos(a) * 0.18, 0.42 + float(i) * 0.1, sin(a) * 0.18))
		w.rotation = Vector3(r.randf_range(-0.25, 0.25), 0, r.randf_range(-0.25, 0.25))
	h.add_child(SetPieceLight.make("ColdLight", Vector3(0, 0.5, 0), Look.color("mist_blue"), 0.4, 2.6, h))


## Black-veined mist: a low cloud of dark, see-through balls crossed with thin black veins.
static func _curse_mist(h: Node3D, seed_: int, _wall: Vector2i) -> void:
	var r := _rng(seed_)
	for i in 7:
		_ball(h, r.randf_range(0.22, 0.4), _glass("shroud_teal" if i % 3 == 0 else "void", 0.3), Vector3(r.randf_range(-0.35, 0.35), 0.3 + r.randf() * 0.55, r.randf_range(-0.35, 0.35)))
	for i in 7:
		var v := _cyl(h, 0.007, r.randf_range(0.5, 0.9), _cel("ink"), Vector3(r.randf_range(-0.3, 0.3), 0.55, r.randf_range(-0.3, 0.3)))
		v.rotation = Vector3(r.randf_range(-1.2, 1.2), r.randf() * TAU, r.randf_range(-1.2, 1.2))
	h.add_child(SetPieceLight.make("MistGlow", Vector3(0, 0.6, 0), Look.color("shroud_teal"), 0.25, 2.2, h))
