class_name OverworldTerrain
extends RefCounted
## The overworld's land drawn by Terrain3D (addons/terrain_3d, MIT; the GPU clipmap terrain made for wide outdoor worlds):
## OverworldLand's heights and grounds imported as one region, the six scanned grounds (art/overworld/ground, packed by
## tools/art/pack_terrain.py) blended by the control map, with detiling so a field of grass never shows its tile.

const GROUND_DIR := "res://art/overworld/ground/"
## How many metres one copy of each ground's picture covers (its uv scale is the inverse).
const TILE_METRES := {"meadow": 3.0, "moor": 3.0, "rock": 4.0, "road": 3.0, "woods": 2.5, "hill": 6.0}
## Each ground's picture darkened and warmed toward an autumn night (the withered grass is near white in daylight and read
## as snow under the moon).
const TINTS := {"meadow": Color(0.62, 0.6, 0.5), "moor": Color(0.5, 0.42, 0.3), "rock": Color(0.8, 0.8, 0.8),
	"road": Color(0.85, 0.8, 0.75), "woods": Color(0.8, 0.75, 0.7), "hill": Color(0.7, 0.68, 0.6)}


static func build(parent: Node3D, land: OverworldLand) -> Terrain3D:
	var terrain := _new(parent, "")
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


## The land as the bake saved it (OverworldBake.TERRAIN_DIR): Terrain3D reads its regions straight in.
static func from_bake(parent: Node3D) -> Terrain3D:
	return _new(parent, OverworldBake.TERRAIN_DIR)


static func _new(parent: Node3D, data_dir: String) -> Terrain3D:
	var terrain := Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.free_editor_textures = false   # (built in code: there is no saved assets file to free them for)
	terrain.region_size = Terrain3D.SIZE_1024
	if data_dir != "":
		terrain.data_directory = data_dir
	parent.add_child(terrain)
	terrain.material.world_background = Terrain3DMaterial.NONE
	terrain.material.auto_shader_enabled = false
	for i in OverworldLand.GROUNDS.size():
		terrain.assets.set_texture_asset(i, ground(OverworldLand.GROUNDS[i]))
	return terrain


static func ground(name: String) -> Terrain3DTextureAsset:
	var ta := Terrain3DTextureAsset.new()
	ta.name = name
	ta.albedo_texture = _packed(GROUND_DIR + name + "_albedo_height.png")
	ta.normal_texture = _packed(GROUND_DIR + name + "_normal_rough.png")
	ta.uv_scale = 1.0 / float(TILE_METRES.get(name, 3.0))
	ta.albedo_color = TINTS.get(name, Color.WHITE) as Color
	ta.detiling_rotation = 0.4
	ta.detiling_shift = 0.3
	return ta


## A packed ground picture as Terrain3D wants it: imported lossless with mipmaps (the .import files say so), so its height
## and roughness alpha come through untouched and all twelve share one size and format.
static func _packed(path: String) -> Texture2D:
	return load(path) as Texture2D
