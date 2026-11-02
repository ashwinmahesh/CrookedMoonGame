class_name RealTrees
extends RefCounted
## Realistic trees and ground plants everywhere the game draws them (Ashwin 2026-11-02: "Go ahead with this", EZ-Tree): the
## trees and bushes made by EZ-Tree (MIT; tools/art/ez_trees.mjs writes art/plants/ez/) and the grass, sedge, reeds and
## ferns built from Poly Haven's leaf pictures (CC0; PlantCards) stand in for the painted ones, each in its own pictures.
## The engine's Flora keeps one mesh per plant id and paints it with its own shaders; here, before it is asked, the
## realistic mesh is put in its place under the painted plant's id (art/plants/real_trees.json), so the maps' woods, the
## land past their edges and the overworld all draw it with nothing in the engine changed. Their shapes and where they
## stand are Flora's and the Woods' as before.
##
## They sway in the wind like the painted ones. Each surface wears a game shader (real_leaf.gdshader, real_bark.gdshader)
## that keeps the glTF's own pictures (colour, and for bark normal and ambient occlusion) and runs the engine's own wind
## code (wind.gdshaderinc), a plant bending from its foot more the higher a point stands. The place's wind and the figures
## walking among the plants are the engine's, copied every frame from Flora's own materials of the same kind (sync), so
## the weather of a place moves these too. GeometryInstance3D.transparency still fades them (both shaders write ALPHA), so
## SeeThrough fades a tree standing between the camera and the party as it did.

const CONFIG := "res://art/plants/real_trees.json"
const LEAF_SHADER := preload("res://world/look/real_leaf.gdshader")
const BARK_SHADER := preload("res://world/look/real_bark.gdshader")
## The leaves' colour against their picture: EZ-Tree's own tints are made for daylight, and under the cold moon the
## leaves read pale teal.
const LEAF_SHADE := Color(0.62, 0.66, 0.55)
## Poly Haven's own leaf pictures are not tinted for daylight, so they need only a little of that.
const CARD_SHADE := Color(0.82, 0.86, 0.78)
## The kinds of plant that take their set's tint (Flora's `tints`: the moor's straw-coloured grass, the marsh's yellowed one).
const GROUND_KINDS: Array[String] = ["fern", "grass", "bush", "reeds"]
## What is copied from Flora's material of a plant's kind each frame.
const SYNCED: Array[StringName] = [&"wind_dir", &"wind_strength", &"figures", &"figure_count", &"figure_part"]

static var _done := false
static var _materials: Dictionary = {}   ## "<kind>|<picture>|<leaf or bark>" -> ShaderMaterial
static var _live: Array = []             ## [ShaderMaterial, kind, takes the set's tint?, base tint] of every material made


## Puts the realistic plants in place (once; every caller before the first plant is drawn may ask).
static func install() -> void:
	if _done:
		return
	_done = true
	if not FileAccess.file_exists(CONFIG):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not parsed is Dictionary:
		return
	var config := parsed as Dictionary
	var made := {}
	var stand := config.get("stand_in", {}) as Dictionary
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
	var textures := config.get("textures", {}) as Dictionary
	var cards := config.get("cards", {}) as Dictionary
	for painted: String in cards:
		var spec := cards[painted] as Dictionary
		var picture := textures.get(str(spec.get("texture", "")), {}) as Dictionary
		var info := Flora.manifest().get(painted, {}) as Dictionary
		var file := str(picture.get("file", ""))
		if info.is_empty() or not ResourceLoader.exists("res://" + file):
			continue
		var size := info.get("size", [1, 1, 1]) as Array
		var cm := PlantCards.build(painted, spec, Vector3(float(size[0]), float(size[1]), float(size[2])),
			picture.get("rects", {}) as Dictionary)
		if cm == null:
			continue
		cm.surface_set_material(0, _leaf_material(load("res://" + file) as Texture2D, str(info.get("kind", "grass")), CARD_SHADE))
		Flora._meshes[painted] = cm
	var loop := Engine.get_main_loop() as SceneTree
	if loop != null:
		loop.process_frame.connect(sync)


## The realistic tree's mesh with the textures it was made with (Godot's glTF import gives each surface its material,
## which is swapped here for the game's wind shader carrying the same pictures).
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
	var kind := str(info.get("kind", "tree"))
	for i in out.get_surface_count():
		var m := out.surface_get_material(i) as StandardMaterial3D
		if m == null:
			continue
		if m.resource_name.begins_with("leaves"):
			out.surface_set_material(i, _leaf_material(m.albedo_texture, kind, m.albedo_color * LEAF_SHADE))
		else:
			out.surface_set_material(i, _bark_material(m, kind))
	return out


## The wind shader's material for leaves in picture `tex` on a plant of Flora kind `kind` (kept: plants of one kind and
## picture share it, as Flora's own do).
static func _leaf_material(tex: Texture2D, kind: String, tint: Color) -> ShaderMaterial:
	var key := "%s|%s|leaf|%s" % [kind, tex.resource_path if tex != null else "", tint.to_html()]
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = LEAF_SHADER
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint", tint)
	# Ground plants are lit more evenly than a tree's crown, which shades its own inside.
	m.set_shader_parameter("shade_floor", 0.65 if kind in Flora.TREES else 0.7)
	_sway(m, kind)
	_materials[key] = m
	_live.append([m, kind, kind in GROUND_KINDS, tint])
	return m


static func _bark_material(src: StandardMaterial3D, kind: String) -> ShaderMaterial:
	var key := "%s|%s|bark" % [kind, src.albedo_texture.resource_path if src.albedo_texture != null else ""]
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = BARK_SHADER
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	if src.normal_texture != null:
		m.set_shader_parameter("normal_tex", src.normal_texture)
	if src.ao_texture != null:
		m.set_shader_parameter("ao_tex", src.ao_texture)
	m.set_shader_parameter("tint", src.albedo_color)
	_sway(m, kind)
	_materials[key] = m
	_live.append([m, kind, false, src.albedo_color])
	return m


## How a kind of plant bends in the wind (the engine's own numbers, Flora.SWAY).
static func _sway(m: ShaderMaterial, kind: String) -> void:
	var sway := Flora.SWAY.get(kind, [0.01, 0.03]) as Array
	m.set_shader_parameter("stiffness", float(sway[0]))
	m.set_shader_parameter("flutter_amount", float(sway[1]))


## Copies the place's wind, and the figures walking among the plants, from Flora's own material of each kind to ours
## (and a ground plant's set tint, over its own), once a frame: Flora sets them when it plants a place.
static func sync() -> void:
	for rec: Array in _live:
		var m := rec[0] as ShaderMaterial
		var src := Flora._material("leaf|" + str(rec[1]))
		for p in SYNCED:
			m.set_shader_parameter(p, src.get_shader_parameter(p))
		if bool(rec[2]):
			var set_tint: Variant = src.get_shader_parameter("tint")
			if set_tint is Color:
				m.set_shader_parameter("tint", (rec[3] as Color) * (set_tint as Color))
