class_name OakOfManyFaces
extends RefCounted
## The Oak of Many Faces (plan 8.4, G8): the village's ancient oak, a bare gnarled trunk of the engine's own dead-tree set grown
## huge, with a dozen pale faces pressed into its bark (painted decals lying on the trunk, glowing faintly) and a cold light that
## breathes among its roots. Built in code through CampaignLook.place_special for any prop whose catalog entry says
## `"set_piece": "oak"`, so any map can plant one; the catalog's `art` stays the fallback picture. Cosmetic only: no square
## is claimed, moved or blocked.

const TREE := "dead_b"
## How many times the plant's own size: the dead tree is about 5 units (25 ft) tall, so this is a 45 foot oak.
const GROW := 1.8
const FACES_DIR := "res://art/props/oak_faces/"
const FACE_COUNT := 8
## Heights up the trunk the faces sit at, in the plant's own units, and the light's height.
const BANDS: Array[float] = [0.30, 0.55, 0.85, 1.15, 1.45, 0.45, 0.95, 1.30, 0.70, 1.05, 0.25, 1.60]


## Builds the oak over `centre` (the middle of the squares it spans) under `parent`. Returns the node that holds it all.
static func build(parent: Node3D, centre: Vector3, seed_: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = "OakOfManyFaces"
	holder.position = centre
	holder.set_meta("set_piece", "oak")
	holder.set_meta("nature", true)
	parent.add_child(holder)
	var trunk := Flora.instance(TREE, GROW)
	trunk.name = "Trunk"
	trunk.rotation.y = float(seed_ % 360) * PI / 180.0
	holder.add_child(trunk)
	var mesh := trunk.mesh
	for i in BANDS.size():
		var face := _face(i)
		if face == null or mesh == null:
			continue
		var y := BANDS[i]
		var round_ := _round(mesh, y)
		var angle := float(i) * 2.399963 + float(seed_ % 7)   # the golden angle: no two faces side by side
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var at := Vector3(round_.centre.x, y, round_.centre.y) * GROW + out * round_.radius * GROW
		holder.add_child(_decal(face, at, out, 0.9 + 0.1 * float(i % 3)))
	holder.add_child(_light(holder))
	return holder


## One face's picture (art/props/oak_faces/face_<n>.png, a pale face on alpha), or null before they are painted.
static func _face(i: int) -> Texture2D:
	var path := "%sface_%d.png" % [FACES_DIR, i % FACE_COUNT]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## A face lying on the bark at `at`, looking out along `out`: a decal whose box straddles the surface, so it paints the trunk
## wherever the trunk is within a third of a unit either way, and glows a little of its own.
static func _decal(face: Texture2D, at: Vector3, out: Vector3, size: float) -> Decal:
	var d := Decal.new()
	d.name = "Face"
	d.texture_albedo = face
	d.texture_emission = face
	d.emission_energy = 1.6
	d.modulate = Color(0.85, 0.92, 1.0)
	var x := Vector3.UP.cross(out).normalized()
	d.transform = Transform3D(Basis(x, out, x.cross(out)), at)
	d.size = Vector3(size, 0.7, size)
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	return d


## The cold light among the roots: pale, low and slowly breathing.
static func _light(holder: Node3D) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "OakGlow"
	l.light_color = Look.color("moon_blue").lerp(Color.WHITE, 0.3)
	l.light_energy = 1.1
	l.omni_range = 7.5
	l.shadow_enabled = false
	l.position = Vector3(0, 1.4, 0)
	l.set_meta("light_kind", "lantern")
	l.set_meta("no_shadow", true)
	var breathe := func() -> void:
		var t := holder.create_tween().set_loops()
		t.tween_property(l, "light_energy", 1.5, 2.4).set_trans(Tween.TRANS_SINE)
		t.tween_property(l, "light_energy", 0.8, 2.9).set_trans(Tween.TRANS_SINE)
	if holder.is_inside_tree():
		breathe.call()
	else:
		holder.tree_entered.connect(breathe, CONNECT_ONE_SHOT)   # (the board is put in the scene after it is built)
	return l


## Where the trunk is at height `y` in the plant's own units: the middle of its vertices in a thin slab there (x and z) and
## how far the farthest reach, so a face lies on the bark whatever the model.
static func _round(mesh: Mesh, y: float) -> _Round:
	var r := _Round.new()
	var pts: Array[Vector2] = []
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if absf(v.y - y) < 0.18:
				pts.append(Vector2(v.x, v.z))
	if pts.is_empty():
		r.radius = 0.35
		return r
	var sum := Vector2.ZERO
	for p in pts:
		sum += p
	r.centre = sum / float(pts.size())
	var dists: Array[float] = []
	for p in pts:
		dists.append(p.distance_to(r.centre))
	dists.sort()
	r.radius = dists[int(float(dists.size() - 1) * 0.8)]   # (not the farthest: a bough may reach out at that height)
	return r


class _Round:
	var centre := Vector2.ZERO
	var radius := 0.35
