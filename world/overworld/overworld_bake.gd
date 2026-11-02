class_name OverworldBake
extends Resource
## The overworld worked out once (make overworld-bake, tools/overworld_bake.gd), so it opens at once instead of in 8 to
## 15 seconds: Terrain3D's regions saved beside this file (art/overworld/baked/terrain/), and here the roads' lines, the
## lake's level, every plant's place and every rock's. `key` is a hash of what it was made from (art/overworld/overworld.json
## and the travel map); a bake whose key no longer matches is ignored and the land is worked out afresh.

const PATH := "res://art/overworld/baked/overworld_bake.res"
const TERRAIN_DIR := "res://art/overworld/baked/terrain"

@export var key := 0
@export var roads: Array[PackedVector2Array] = []
@export var road_ids: Array[String] = []
@export var lake_level := -1000.0
## plant id -> PackedFloat32Array of 12 floats a copy (basis x, y, z, origin)
@export var plants: Dictionary = {}
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


static func pack_xforms(list: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t: Transform3D in list:
		out.append_array([t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
			t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z])
	return out


static func unpack_xforms(data: PackedFloat32Array) -> Array:
	var out := []
	for i in range(0, data.size(), 12):
		out.append(Transform3D(Basis(Vector3(data[i], data[i + 1], data[i + 2]), Vector3(data[i + 3], data[i + 4], data[i + 5]),
			Vector3(data[i + 6], data[i + 7], data[i + 8])), Vector3(data[i + 9], data[i + 10], data[i + 11])))
	return out
