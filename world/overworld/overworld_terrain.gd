class_name OverworldTerrain
extends RefCounted
## The overworld's land drawn by Terrain3D (addons/terrain_3d, MIT; the GPU clipmap terrain made for wide outdoor worlds):
## OverworldLand's heights and grounds imported as one region, the six scanned grounds (art/overworld/ground, packed by
## tools/art/pack_terrain.py) blended by the control map, with detiling so a field of grass never shows its tile.

const GROUND_DIR := "res://art/overworld/ground/"
## How many metres one copy of each ground's picture covers (its uv scale is the inverse).
const TILE_METRES := {"meadow": 3.0, "moor": 3.0, "rock": 4.0, "road": 3.0, "woods": 2.5, "hill": 6.0}


static func build(parent: Node3D, land: OverworldLand) -> Terrain3D:
	var terrain := Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.region_size = Terrain3D.SIZE_1024
	parent.add_child(terrain)
	terrain.material.world_background = Terrain3DMaterial.NONE
	terrain.material.auto_shader_enabled = false
	for i in OverworldLand.GROUNDS.size():
		terrain.assets.set_texture_asset(i, _ground(OverworldLand.GROUNDS[i]))
	var n := land.size
	var height := Image.create_empty(n, n, false, Image.FORMAT_RF)
	var control := Image.create_empty(n, n, false, Image.FORMAT_RF)
	for z in n:
		for x in n:
			height.set_pixel(x, z, Color(land.heights[z * n + x], 0.0, 0.0, 1.0))
			var g := land.ground_at(x, z)
			var bits := Terrain3DUtil.enc_base(g[0]) | Terrain3DUtil.enc_overlay(g[1]) | Terrain3DUtil.enc_blend(g[2])
			control.set_pixel(x, z, Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0))
	terrain.data.import_images([height, control, null], Vector3.ZERO, 0.0, 1.0)
	return terrain


static func _ground(name: String) -> Terrain3DTextureAsset:
	var ta := Terrain3DTextureAsset.new()
	ta.name = name
	ta.albedo_texture = _packed(GROUND_DIR + name + "_albedo_height.png")
	ta.normal_texture = _packed(GROUND_DIR + name + "_normal_rough.png")
	ta.uv_scale = 1.0 / float(TILE_METRES.get(name, 3.0))
	ta.detiling_rotation = 0.4
	ta.detiling_shift = 0.3
	return ta


## A packed ground picture as Terrain3D wants it: uncompressed RGBA with mipmaps, read straight from the PNG so the import
## step's compression never touches its alpha.
static func _packed(path: String) -> ImageTexture:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path)) if not OS.has_feature("template") else (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
