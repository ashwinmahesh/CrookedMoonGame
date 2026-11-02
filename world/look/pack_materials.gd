class_name PackMaterials
extends RefCounted
## The Quaternius packs' surfaces in their own realistic materials (Ashwin, 2026-11-02: "fully 3D now", "realistic
## lighting and texures", with the changes in this game, not the shared engine, which Curse of Strahd still draws HD-2D).
## The village kit's modules and the pack props name their surfaces after the game's texture sets "vkit/..." and "vpro/..."
## (art/textures/manifest.json, tools/art/pack_textures.py). The engine draws those as it draws every texture set, mapped by
## world position in its cel look; once a place is built, `apply` gives every such surface a plain lit material on the
## model's own UVs instead, so the trim sheets line up: the set's albedo, normal map and roughness (an ORM map's green, or a
## roughness map), its ambient occlusion from an ORM map, its vertex colours where the set says `vertex`. A set with
## `triplanar` (a house's core and gable ends, built in code without the pack's UVs) is mapped by world position.

const THEMES: Array[String] = ["vkit", "vpro"]

static var _made: Dictionary = {}


## Every pack surface under `root` in its own material (CrookedMoonLook.dress_place, for each place as it opens).
static func apply(root: Node) -> int:
	var n := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m == null or not m.has_meta("surface"):
				continue
			var real := material(str(m.get_meta("surface")))
			if real != null:
				mi.set_surface_override_material(i, real)
				n += 1
	return n


## The lit material of texture set `surface` ("vkit/plaster"), or null when it isn't one of the packs'.
static func material(surface: String) -> StandardMaterial3D:
	if _made.has(surface):
		return _made[surface] as StandardMaterial3D
	var parts := surface.split("/")
	var m: StandardMaterial3D = null
	if parts.size() == 2 and parts[0] in THEMES:
		var info := ((Look.textures().get("themes", {}) as Dictionary).get(parts[0], {}) as Dictionary).get(parts[1], {}) as Dictionary
		if bool(info.get("pack", false)):
			m = _build(surface, info)
	_made[surface] = m
	return m


static func _build(surface: String, info: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = surface
	m.set_meta("surface", surface)   # (still what the ground is, for footprints, and for the tests)
	if info.has("colour"):
		var c := info["colour"] as Array
		m.albedo_color = Color(float(c[0]), float(c[1]), float(c[2]))
	else:
		m.albedo_texture = _tex(str(info.get("file", "")))
	if info.has("normal_file"):
		m.normal_enabled = true
		m.normal_texture = _tex(str(info["normal_file"]))
	if info.has("orm_file"):
		var orm := _tex(str(info["orm_file"]))
		m.roughness_texture = orm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true
		m.ao_texture = orm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	elif info.has("rough_file"):
		m.roughness_texture = _tex(str(info["rough_file"]))
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = float(info.get("roughness", 1.0))
	m.metallic = float(info.get("metallic", 0.0))
	m.vertex_color_use_as_albedo = bool(info.get("vertex", false))
	if bool(info.get("triplanar", false)):
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		var s := 1.0 / float(info.get("tile_world_units", 2.0))
		m.uv1_scale = Vector3(s, s, s)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _tex(rel: String) -> Texture2D:
	var path := ArtPaths.of(rel)
	return load(path) as Texture2D if rel != "" and ResourceLoader.exists(path) else null
