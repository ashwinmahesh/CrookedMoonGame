class_name OverworldBake
extends Resource
## The overworld worked out once (make overworld-bake, tools/overworld_bake.gd), so it opens at once instead of in 8 to
## 15 seconds: Terrain3D's regions saved beside this file (art/overworld/baked/terrain/), and here the roads' lines, the
## water levels, every plant's place (by chunk) and every rock's. `key` is a hash of what it was made from (art/overworld/overworld.json
## and the travel map); a bake whose key no longer matches is ignored and the land is worked out afresh.

const PATH := "res://art/overworld/baked/overworld_bake.res"
const TERRAIN_DIR := "res://art/overworld/baked/terrain"

@export var key := 0
@export var roads: Array[PackedVector2Array] = []
@export var road_ids: Array[String] = []
## The level of each of OverworldLand.waters, in order.
@export var water_levels := PackedFloat32Array()
## "plant id|chunk x|chunk z" -> a 128 m chunk's plants as a MultiMesh buffer (pack_xforms)
@export var chunks: Dictionary = {}
## [model id, Transform3D] for each rock
@export var rocks: Array = []


static func current_key() -> int:
	var text := FileAccess.get_file_as_string(OverworldLand.CONFIG)
	text += JSON.stringify(Travel.map_data())
	return hash(text)


## The bake, or null when there is none or it is out of date.
static func load_bake() -> OverworldBake:
	if not ResourceLoader.exists(PATH) or not DirAccess.dir_exists_absolute(TERRAIN_DIR):
		return null
	var b := load(PATH) as OverworldBake
	if b == null or b.key != current_key():
		return null
	return b


## A MultiMesh's own buffer layout (three rows of a 3 x 4 matrix, 12 floats a copy), so a chunk's plants go to it as they are.
static func pack_xforms(list: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t: Transform3D in list:
		out.append_array([t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x, t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y,
			t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z])
	return out
