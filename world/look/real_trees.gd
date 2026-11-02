class_name RealTrees
extends RefCounted
## Realistic trees everywhere the game draws trees (Ashwin 2026-11-02: "Go ahead with this", EZ-Tree): the trees made by
## EZ-Tree (MIT; tools/art/ez_trees.mjs writes art/plants/ez/) stand in for the painted ones, each in its own bark and
## leaf textures. The engine's Flora keeps one mesh per plant id and paints it with its own shaders; here, before it is
## asked, the realistic mesh is put in its place under the painted tree's id (art/plants/real_trees.json), so the maps'
## woods, the land past their edges and the overworld all draw it with nothing in the engine changed. Their shapes and
## where they stand are Flora's and the Woods' as before; the leaves don't sway in the wind.

const CONFIG := "res://art/plants/real_trees.json"
## The leaves' colour against their picture: EZ-Tree's own tints are made for daylight, and under the cold moon the
## leaves read pale teal.
const LEAF_SHADE := Color(0.62, 0.66, 0.55)

static var _done := false


## Puts the realistic trees in place (once; every caller before the first tree is drawn may ask).
static func install() -> void:
	if _done:
		return
	_done = true
	if not FileAccess.file_exists(CONFIG):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not parsed is Dictionary:
		return
	var made := {}
	var stand := (parsed as Dictionary).get("stand_in", {}) as Dictionary
	for painted: String in stand:
		var real := str(stand[painted])
		if not made.has(real):
			made[real] = _mesh(real)
		var m := made[real] as Mesh
		if m != null:
			Flora._meshes[painted] = m
	for real: String in made:
		if made[real] != null:
			Flora._meshes[real] = made[real]


## The realistic tree's mesh with the textures it was made with (Godot's glTF import gives each surface its material).
static func _mesh(id: String) -> Mesh:
	var info := Flora.manifest().get(id, {}) as Dictionary
	var path := ArtPaths.of(str(info.get("file", "")))
	if info.is_empty() or not ResourceLoader.exists(path):
		return null
	var root := (load(path) as PackedScene).instantiate()
	var out: Mesh = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		out = (n as MeshInstance3D).mesh
		break
	root.free()
	if out == null:
		return null
	out = out.duplicate() as Mesh
	for i in out.get_surface_count():
		var m := out.surface_get_material(i) as StandardMaterial3D
		if m != null and m.resource_name.begins_with("leaves"):
			m = m.duplicate() as StandardMaterial3D
			m.albedo_color *= LEAF_SHADE
			out.surface_set_material(i, m)
	return out
