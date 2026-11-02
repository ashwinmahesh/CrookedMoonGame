class_name MeleeHitFx
extends Node3D
## The Crooked Moon's melee hit effects (Ashwin's picks, 2026-11-02, from the melee effects demo page): a clean cut for a
## blade, a pierce ring for a point, a shock ring for a club or hammer and a ripple for a fist, in moonlight colours. They
## take the place of the engine's crescent (CampaignLook.melee_hit) and land on the swing's hit frame (data/campaign.json's
## game_feel strike_on_hit_frame). What each kind gets, its angle, the colours, size and length are in data/melee_fx.json.
## Each effect is drawn flat, facing the camera at the struck creature's chest, in the demo's own measures (pixels of
## a 150-pixel figure, y down) turned into world units; the shock ring's second ring lies on the ground.

const DATA := "res://data/melee_fx.json"
const STYLES: Array[String] = ["cut", "ring", "shock", "ripple"]
## World units per demo pixel for a figure 1.2 units tall (the demo's figure stands 150 pixels).
const PX := 0.008
const FIGURE := 1.2
## How bright the drawn light is (over 1 it blooms like the other spell light).
const ENERGY := 1.5
## Each style's life in seconds (at length 1).
const LIFE := {"cut": 0.4, "ring": 0.36, "shock": 0.7, "ripple": 0.3}

static var _cfg: Dictionary = {}

var style := ""
var critical := false
## The blow's direction on the screen (x right, y down) and its angle there.
var dir := Vector2.RIGHT
var ang := 0.0
## core, glow, edge.
var cols: Dictionary = {}
var size := 1.0
var length := 1.0
## World units per demo pixel for this target.
var unit := PX
var _face: MeshInstance3D
var _ground: MeshInstance3D
var _mat: StandardMaterial3D
## The triangles drawn this frame, as they are built.
var _verts := PackedVector3Array()
var _colours := PackedColorArray()


## The picks (data/melee_fx.json), read once; use() puts others in place for a test.
static func config() -> Dictionary:
	if _cfg.is_empty() and FileAccess.file_exists(DATA):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if d is Dictionary:
			_cfg = d as Dictionary
	return _cfg


static func use(cfg: Dictionary) -> void:
	_cfg = cfg


## The style a melee blow of `kind` gets ("blade", "point", "blunt", "unarmed"), or "" for the engine's own.
static func style_for(kind: String) -> String:
	var pick := (config().get("kinds", {}) as Dictionary).get(kind, {}) as Dictionary
	var s := str(pick.get("style", ""))
	return s if s in STYLES else ""


## A melee blow of `kind` lands on `target`: plays its effect under `fx` and returns true, or false when the kind has
## no pick (the engine draws its own).
static func play(fx: SpellFx, cue: Dictionary, attacker: CombatToken, target: CombatToken, crit: bool, kind: String) -> bool:
	var s := style_for(kind)
	if s == "" or fx == null or target == null or not fx.is_inside_tree():
		return false
	var cfg := config()
	var pick := (cfg["kinds"] as Dictionary)[kind] as Dictionary
	var at := SpellFx.chest(target)
	var cam := fx.get_viewport().get_camera_3d()
	var from := attacker.global_position if attacker != null else Vector3.INF
	var n := MeleeHitFx.new()
	n.style = s
	n.critical = crit
	var sd := GameFeel.screen_dir(cam, from, at)
	var base := Vector2(sd.x, -sd.y) if sd != Vector2.ZERO else Vector2.RIGHT
	# The pick's angle is for a blow travelling right (the demo's); a blow travelling left mirrors it.
	var rel := deg_to_rad(float(pick.get("angle", 0.0)))
	n.ang = base.angle() + (rel if base.x >= 0.0 else -rel)
	n.dir = Vector2.from_angle(n.ang)
	n.cols = colours(cue)
	n.size = float(cfg.get("size", 1.0))
	n.length = maxf(float(cfg.get("length", 1.0)), 0.1)
	n.unit = PX * clampf(SpellFx.height_of(target) / FIGURE, 0.8, 2.2)
	fx.add_child(n)
	n.global_position = at
	if cam != null:
		n.global_basis = cam.global_basis.orthonormalized()
	n._start(fx, target.global_position + Vector3(0, 0.03, 0))
	return true


## The effect's colours: the picks' (moonlight) for a plain steel blow, else the cue's own (a fiery claw keeps its fire).
static func colours(cue: Dictionary) -> Dictionary:
	var own := cue.get("colours", {}) as Dictionary
	if str(cue.get("flavour", "steel")) != "steel" and not own.is_empty():
		return own
	var names := config().get("colours", {}) as Dictionary
	var out := {}
	for k: String in ["core", "glow", "edge"]:
		out[k] = Look.color(str(names.get(k, "frost")))
	return out


func _start(fx: SpellFx, feet: Vector3) -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_color = Color(ENERGY, ENERGY, ENERGY)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = true
	_mat.render_priority = FxKit.PRIORITY
	_face = _mesh()
	add_child(_face)
	if style == "shock":
		_ground = _mesh()
		fx.add_child(_ground)
		_ground.global_position = feet
		tree_exiting.connect(_ground.queue_free)
	var pace := GameSettings.combat_pace()
	var life := float(LIFE[style]) * length
	var tw := create_tween()
	tw.tween_method(_draw, 0.0, life, life * pace)
	tw.tween_callback(queue_free)
	_extras(fx, pace)


func _mesh() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## What goes with the drawing: a quick light on the blow, sparks off a cut, dust off a heavy blow.
func _extras(fx: SpellFx, pace: float) -> void:
	var at := global_position
	var light := cols["glow"] as Color
	match style:
		"cut":
			FxKit.flash(fx, at, light, 1.4, 1.6, 0.02, 0.25 * pace)
			var across := Vector2.from_angle(ang + PI / 2.0)
			var sparks := FxKit.particles({"amount": 11 if critical else 7, "lifetime": 0.32, "dir": _world(across), "spread": 55.0,
				"speed": Vector2(1.2, 2.6), "damping": Vector2(2.0, 4.0), "gravity": Vector3(0, -6.0, 0), "size": Vector2(0.02, 0.1),
				"align": true, "colours": [cols["core"], cols["glow"]], "material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"] as Color, 3.0, false)})
			fx.emit(sparks, at)
		"shock":
			FxKit.flash(fx, at, light, 2.0, 2.2, 0.02, 0.35 * pace)
			var bone := Look.color("bone")
			var dust := FxKit.particles({"amount": 6, "lifetime": 0.7, "emit": "sphere", "radius": 0.2, "speed": Vector2(0.2, 0.7),
				"dir": Vector3.UP, "spread": 70.0, "damping": Vector2(1.0, 2.0), "size": 0.35, "colours": [bone, bone.darkened(0.3)],
				"material": FxKit.glow_material(FxKit.Shape.PUFF, bone, 0.5)})
			fx.emit(dust, (_ground.global_position if _ground != null else at) + Vector3(0, 0.1, 0))
		_:
			FxKit.flash(fx, at, light, 1.2, 1.4, 0.02, 0.2 * pace)


## A direction on the screen (y down) as one in the world.
func _world(v: Vector2) -> Vector3:
	return (global_basis.x * v.x - global_basis.y * v.y).normalized()


# --- Drawing (the demo's measures: pixels, y down; t in seconds since the blow) ------------------------------------

func _draw(t: float) -> void:
	_begin()
	var k := (1.3 if critical else 1.0)
	var s := size
	var ln := length
	match style:
		"cut":
			_cut(t, k, s, ln)
		"ring":
			_ring(t, k, s, ln)
		"shock":
			_shock(t, k, s, ln)
		"ripple":
			_ripple(t, k, s, ln)
	_end(_face)


func _cut(t: float, k: float, s: float, ln: float) -> void:
	var life := 0.26 * ln
	var kk := t / life
	if kk <= 1.0:
		var L := 70.0 * k * s
		var reach := _ease_out(minf(t / (0.05 * ln), 1.0))
		var a := dir * -L
		var b := dir * lerpf(-L, L, reach)
		var w := (lerpf(1.2, 4.5, kk / 0.25) if kk < 0.25 else lerpf(4.5, 0.6, (kk - 0.25) / 0.75)) * k * s
		var pts := PackedVector2Array()
		for i in 17:
			pts.append(a.lerp(b, float(i) / 16.0))
		var first := pts.slice(0, 9)
		var second := pts.slice(8)
		_ribbon(first, 0.0, w * 3.0, _a(cols["glow"], 0.3 * (1.0 - kk)))
		_ribbon(second, w * 3.0, 0.0, _a(cols["glow"], 0.3 * (1.0 - kk)))
		_ribbon(first, 0.0, w, _a(cols["core"], 1.0 - kk * kk))
		_ribbon(second, w, 0.0, _a(cols["core"], 1.0 - kk * kk))
	_flash(t, k, s, ln, 30.0, 0.55, 0.06)


func _ring(t: float, k: float, s: float, ln: float) -> void:
	var life := 0.28 * ln
	var kk := t / life
	if kk > 1.0:
		return
	for j in (2 if critical else 1):
		var q := kk - j * 0.18
		if q < 0.0:
			continue
		var c := dir * _ease_out(q) * 46.0 * s
		var ry := lerpf(10.0, 30.0, _ease_out(q)) * k * s
		_ellipse(c, ry * 0.32, ry, ang, 4.0 * (1.0 - q) * s, _a(cols["glow"], 0.5 * (1.0 - q)))
		_ellipse(c, ry * 0.32, ry, ang, 1.6 * s, _a(cols["core"], 0.9 * (1.0 - q)))
	var head := _ease_out(minf(t / (0.06 * ln), 1.0))
	_glow_line(dir * -40.0 * s, dir * lerpf(-40.0, 60.0, head) * s, 2.0 * s, 1.0 - kk, 2.6)


func _shock(t: float, k: float, s: float, ln: float) -> void:
	_flash(t, k, s, ln, 30.0, 0.7, 0.07)
	var kk := t / (0.36 * ln)
	if kk < 1.0:
		var r := _ease_out(kk) * 58.0 * k * s
		_ellipse(Vector2.ZERO, r, r * 0.55, ang - PI / 2.0, 7.0 * (1.0 - kk) * s, _a(cols["glow"], 0.45 * (1.0 - kk)))
		_ellipse(Vector2.ZERO, r, r * 0.55, ang - PI / 2.0, 2.0 * s, _a(cols["core"], 1.0 - kk))
	# The second ring spreads over the ground round the target's feet (a true circle on the floor).
	if _ground != null:
		var mesh := _ground.mesh as ImmediateMesh
		mesh.clear_surfaces()
		var k2 := (t - 0.04) / (0.5 * ln)
		if k2 > 0.0 and k2 < 1.0:
			var verts := PackedVector3Array()
			var colours := PackedColorArray()
			var r := _ease_out(k2) * 80.0 * k * s * unit
			var w := maxf(3.0 * (1.0 - k2) * s * unit, 0.004)
			var col := _a(cols["glow"], 0.6 * (1.0 - k2))
			for i in 48:
				var a0 := TAU * i / 48.0
				var a1 := TAU * (i + 1) / 48.0
				var o0 := Vector3(cos(a0), 0, sin(a0))
				var o1 := Vector3(cos(a1), 0, sin(a1))
				for v: Vector3 in [o0 * (r - w), o0 * (r + w), o1 * (r + w), o0 * (r - w), o1 * (r + w), o1 * (r - w)]:
					verts.append(v)
					colours.append(col)
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
			for i in verts.size():
				mesh.surface_set_color(colours[i])
				mesh.surface_add_vertex(verts[i])
			mesh.surface_end()


func _ripple(t: float, k: float, s: float, ln: float) -> void:
	for j in (3 if critical else 2):
		var q := (t - j * 0.045) / (0.2 * ln)
		if q < 0.0 or q > 1.0:
			continue
		var c := dir * (j * 10.0 + _ease_out(q) * 14.0) * s
		var rr := lerpf(5.0, 22.0, _ease_out(q)) * k * s
		_ellipse(c, rr * 0.5, rr, ang, 2.2 * s, _a(cols["glow"] if j > 0 else cols["core"], 1.0 - q))
	_flash(t, k, s, ln, 16.0, 0.6, 0.05)


# --- Shapes ----------------------------------------------------------------------------------------------------------

static func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


static func _a(c: Variant, alpha: float) -> Color:
	var col := c as Color
	return Color(col.r, col.g, col.b, clampf(alpha, 0.0, 1.0))


## A quick soft glow on the blow: `r` pixels across at full weight, fading over `dur` seconds.
func _flash(t: float, k: float, s: float, ln: float, r: float, a: float, dur: float) -> void:
	var q := t / (dur * ln)
	if q < 0.0 or q > 1.0:
		return
	_dot(Vector2.ZERO, r * k * s * (0.7 + q * 0.6), _a(cols["core"], a * (1.0 - q)))


func _begin() -> void:
	_verts.clear()
	_colours.clear()


func _end(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if _verts.is_empty():
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for i in _verts.size():
		mesh.surface_set_color(_colours[i])
		mesh.surface_add_vertex(_verts[i])
	mesh.surface_end()


func _v(p: Vector2) -> Vector3:
	return Vector3(p.x * unit, -p.y * unit, 0.0)


func _tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	_verts.append(_v(a))
	_verts.append(_v(b))
	_verts.append(_v(c))
	_colours.append(ca)
	_colours.append(cb)
	_colours.append(cc)


## A strip along `pts`, `w0` wide at the first point to `w1` at the last.
func _ribbon(pts: PackedVector2Array, w0: float, w1: float, col: Color, closed: bool = false) -> void:
	var n := pts.size()
	if n < 2 or col.a <= 0.0:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var before := pts[(i - 1 + n) % n] if closed else pts[maxi(0, i - 1)]
		var after := pts[(i + 1) % n] if closed else pts[mini(n - 1, i + 1)]
		var d := (after - before).normalized()
		var side := Vector2(-d.y, d.x) * lerpf(w0, w1, float(i) / float(n - 1)) * 0.5
		left.append(pts[i] + side)
		right.append(pts[i] - side)
	var last := n if closed else n - 1
	for i in last:
		var j := (i + 1) % n
		_tri(left[i], right[i], right[j], col, col, col)
		_tri(left[i], right[j], left[j], col, col, col)


## A glowing line: a wide faint stroke under a thin bright one.
func _glow_line(a: Vector2, b: Vector2, w: float, alpha: float, glow: float) -> void:
	if alpha <= 0.0 or a.distance_to(b) < 0.01:
		return
	var pts := PackedVector2Array([a, b])
	_ribbon(pts, w * glow, w * glow, _a(cols["glow"], alpha * 0.22))
	_ribbon(pts, w * 1.6, w * 1.6, _a(cols["glow"], alpha * 0.5))
	_ribbon(pts, w, w, _a(cols["core"], alpha))


## An ellipse's outline round `c`, `rx` by `ry`, turned by `rot`, `w` wide.
func _ellipse(c: Vector2, rx: float, ry: float, rot: float, w: float, col: Color) -> void:
	if rx <= 0.0 or ry <= 0.0 or w <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	_ribbon(pts, w, w, col, true)


## A soft round glow: bright in the middle, gone at its edge.
func _dot(c: Vector2, r: float, col: Color) -> void:
	if r <= 0.0 or col.a <= 0.0:
		return
	var edge := _a(col, 0.0)
	for i in 20:
		var a0 := TAU * i / 20.0
		var a1 := TAU * (i + 1) / 20.0
		_tri(c, c + Vector2.from_angle(a0) * r, c + Vector2.from_angle(a1) * r, col, edge, edge)
