class_name RealNature
extends RefCounted
## Realistic nature for the wild places (Ashwin 2026-11-02: no toon look, "realistic lighting and texures", and changes
## that leave the engine's HD-2D look stay in this game, since Curse of Strahd keeps it): Poly Haven's scanned rocks,
## roots, stumps, logs, ferns and branches (CC0, art/sourced/polyhaven_forest, untouched) drawn in their own PBR
## materials. art/nature/real_nature.json names the models and, for each place, what is strewn over its ground. A catalog
## prop whose `ids` entry says `"set_piece": "real"` is drawn as one of the models its `real` list names (CrookedMoonLook);
## the strewing comes once the place's props are up (CrookedMoonLook.dress_place). Cosmetic only: the rules grid never
## sees any of it, the middle of every walkable square stays clear for feet and the selection ring, and the woods are
## dressed only along their edge, where the camera sees under the crowns.

const CONFIG := "res://art/nature/real_nature.json"
## How far from a walkable square's middle anything strewn on it stands (the open ground's pieces sit at its rim).
const MIDDLE_CLEAR := 0.33
const RIM := 0.48

static var _config: Dictionary = {}
static var _scenes: Dictionary = {}   ## model id -> PackedScene
static var _boxes: Dictionary = {}    ## model id -> its AABB as modelled (metres, Poly Haven's own scale)
static var _shaded: Dictionary = {}   ## "model id|surface" -> the leaf material shaded down for night
## Set by art QA tools only, to shoot a place without it.
static var off := false


static func config() -> Dictionary:
	if _config.is_empty() and FileAccess.file_exists(CONFIG):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		if parsed is Dictionary:
			_config = parsed as Dictionary
	return _config


static func has_model(id: String) -> bool:
	return (config().get("models", {}) as Dictionary).has(id)


## One model `id` standing at `at` (its foot on the ground there), sized and turned by `seed_`; null for an unknown id.
static func build(parent: Node3D, id: String, at: Vector3, seed_: int) -> Node3D:
	var spec := (config().get("models", {}) as Dictionary).get(id, {}) as Dictionary
	var scene := _scene(id, spec)
	if scene == null:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var piece := scene.instantiate() as Node3D
	piece.name = "Real_" + id
	piece.set_meta("nature", true)
	piece.set_meta("real", id)
	var box := _boxes[id] as AABB
	var grow := spec.get("grow", [1.0, 1.0]) as Array
	var across := maxf(box.size.x, box.size.z)
	var s := float(spec.get("fit", 1.0)) / maxf(across, 0.01) * rng.randf_range(float(grow[0]), float(grow[1]))
	piece.scale = Vector3.ONE * s
	piece.rotation.y = rng.randf_range(0.0, TAU)
	if not bool(spec.get("lie", false)):
		var tilt := float(spec.get("tilt", 0.12))   # (a set-piece tree stands nearly upright: `tilt`)
		piece.rotation.x = rng.randf_range(-tilt, tilt)
		piece.rotation.z = rng.randf_range(-tilt, tilt)
	if spec.has("leaf_shade"):
		_shade_leaves(piece, id, spec["leaf_shade"] as Array)
	_economise(piece, spec)
	piece.position = at - Vector3(0.0, box.position.y * s + float(spec.get("sink", 0.0)), 0.0)
	parent.add_child(piece)
	return piece


## What a model costs the GPU: `shadow` false keeps it out of every shadow map (the sun's splits and the party lantern's six
## cube faces redraw each shadow caster, and the scanned pieces run to 40k-225k triangles), and `range` is the distance past
## which it is not drawn at all (world units, with a short fade). Ground clutter is small, so neither shows.
static func _economise(piece: Node3D, spec: Dictionary) -> void:
	var shadow := bool(spec.get("shadow", true))
	var reach := float(spec.get("range", 0.0))
	if shadow and reach <= 0.0:
		return
	for n in piece.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not shadow:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if reach > 0.0:
			g.visibility_range_end = reach
			g.visibility_range_end_margin = 4.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## A model's leaves (a glTF material named "leaves...") in a colour of their own: EZ-Tree's leaf tints are made for
## daylight, and under the cold moon they would read pale. The shaded material is made once per model and surface.
static func _shade_leaves(piece: Node3D, id: String, shade: Array) -> void:
	var mult := Color(float(shade[0]), float(shade[1]), float(shade[2]))
	for n in piece.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m == null or not m.resource_name.begins_with("leaves"):
				continue
			var key := "%s|%d" % [id, i]
			if not _shaded.has(key):
				var d := m.duplicate() as StandardMaterial3D
				d.albedo_color *= mult
				_shaded[key] = d
			mi.set_surface_override_material(i, _shaded[key] as Material)


## One model `id` set down with a transform already worked out (a baked overworld's rocks).
static func place(parent: Node3D, id: String, xform: Transform3D) -> Node3D:
	var spec := (config().get("models", {}) as Dictionary).get(id, {}) as Dictionary
	var scene := _scene(id, spec)
	if scene == null:
		return null
	var piece := scene.instantiate() as Node3D
	piece.name = "Real_" + id
	piece.set_meta("nature", true)
	piece.transform = xform
	parent.add_child(piece)
	return piece


## Strews the place's ground with its `places` entry: under the trees along the woods' edge, over the difficult squares
## and, sparsely, at the rim of the open ground. Squares a prop, a door, a person or a starting place takes are left alone.
static func strew(view: LocationView) -> Node3D:
	var plan := plan_for(view.loc_id, view.loc)
	if off or plan.is_empty() or not Look.modern():
		return null
	var board := view.board
	var grid := board.grid
	var holder := Node3D.new()
	holder.name = "RealNature"
	board.add_child(holder)
	var taken := _taken(view.loc)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(view.loc_id)
	for y in grid.depth:
		for x in grid.width:
			var c := Vector2i(x, y)
			if taken.has(c):
				continue
			var kind := _kind(board, c)
			if kind == "":
				continue
			if kind == "low":
				# The board's own low cover (a low-poly boulder, a woodpile) gives way to one scanned piece.
				var lows := plan.get("low", []) as Array
				if lows.is_empty():
					continue
				for n: Variant in board.dressing.get(c, []) as Array:
					if n is Node3D:
						(n as Node3D).visible = false
				var at := Vector2(c.x + 0.5 + rng.randf_range(-0.1, 0.1), c.y + 0.5 + rng.randf_range(-0.1, 0.1))
				build(holder, str(lows[rng.randi() % lows.size()]), Vector3(at.x, board.ground_y(at), at.y), rng.randi())
				continue
			for entry: Variant in plan.get(kind, []) as Array:
				var pick := entry as Array
				var n := _count(float(pick[1]), rng)
				for i in n:
					var p := _spot(kind, c, rng)
					build(holder, str(pick[0]), Vector3(p.x, board.ground_y(p), p.y), rng.randi())
	return holder


## Which list a square takes: "woods" for a tree square beside walkable ground, "low" for low cover ('='), "difficult",
## "open", or "" for none.
static func _kind(board: ArenaBoard, c: Vector2i) -> String:
	var grid := board.grid
	if grid.has_flag(c, CombatGrid.VOID) or grid.has_flag(c, CombatGrid.WATER):
		return ""
	if grid.has_flag(c, CombatGrid.LOW):
		return "low"
	if grid.has_flag(c, CombatGrid.WALL):
		if not board.is_tree(c):
			return ""
		for d: Vector2i in CombatGrid.DIRS:
			var o := c + d
			if grid.in_bounds(o) and not grid.has_flag(o, CombatGrid.WALL) and not grid.has_flag(o, CombatGrid.VOID):
				return "woods"
		return ""
	return "difficult" if grid.has_flag(c, CombatGrid.DIFFICULT) else "open"


## Where in square `c` a piece stands (x, z): anywhere under the trees and in the thicket, at the rim of open ground.
static func _spot(kind: String, c: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	if kind == "open":
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(MIDDLE_CLEAR, RIM)
		return Vector2(c.x + 0.5 + cos(a) * r, c.y + 0.5 + sin(a) * r)
	return Vector2(c.x + rng.randf_range(0.08, 0.92), c.y + rng.randf_range(0.08, 0.92))


## A whole number of pieces averaging `mean`.
static func _count(mean: float, rng: RandomNumberGenerator) -> int:
	var n := floori(mean)
	return n + (1 if rng.randf() < mean - float(n) else 0)


## The map themes that are wild land (not a town, a house or a dungeon): only these take a region's set.
const WILD_THEMES: Array[String] = ["forest", "wilderness", "road", "riverside"]


## What is strewn over place `id`: its own entry in `places`, else the set its region names when its map is wild land.
static func plan_for(id: String, loc: Dictionary) -> Dictionary:
	var own := (config().get("places", {}) as Dictionary).get(id, {}) as Dictionary
	if not own.is_empty():
		return own
	var map := loc.get("map", {}) as Dictionary
	if not bool(map.get("outdoors", false)) or not str(map.get("theme", "")) in WILD_THEMES:
		return {}
	var set_id := str((config().get("regions", {}) as Dictionary).get(str(loc.get("region", "")), ""))
	return (config().get("sets", {}) as Dictionary).get(set_id, {}) as Dictionary


## The squares the place's own things stand on.
static func _taken(loc: Dictionary) -> Dictionary:
	var out := {}
	for key: String in ["props", "containers", "npcs", "exits", "doors", "traps"]:
		for e: Variant in loc.get(key, []) as Array:
			if e is Dictionary and (e as Dictionary).get("cell") is Array:
				var cell := (e as Dictionary)["cell"] as Array
				var span := (e as Dictionary).get("span", [1, 1]) as Array
				for dx in int(span[0]):
					for dz in int(span[1]):
						out[Vector2i(int(cell[0]) + dx, int(cell[1]) + dz)] = true
	var spawns: Variant = loc.get("spawns", {})
	if spawns is Dictionary:
		for s: Variant in (spawns as Dictionary).values():
			if s is Array and (s as Array).size() >= 2 and not (s as Array)[0] is Array:
				out[Vector2i(int((s as Array)[0]), int((s as Array)[1]))] = true
	return out


static func _scene(id: String, spec: Dictionary) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id] as PackedScene
	var path := ArtPaths.of(str(spec.get("file", "")))
	if spec.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	var probe := scene.instantiate() as Node3D
	var box := AABB()
	var first := true
	for n in probe.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := mi.transform
		var p := mi.get_parent()
		while p != probe and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	probe.free()
	_scenes[id] = scene
	_boxes[id] = box
	return scene
