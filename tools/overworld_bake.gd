extends Node
## Works the overworld out once and saves it (make overworld-bake): Terrain3D's regions in OverworldBake.TERRAIN_DIR and
## the roads, lake, plants and rocks in OverworldBake.PATH, so the overworld opens at once (world/overworld/). A scene, not a
## --script tool, so the game's autoloads are there.


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var view := OverworldView.new()
	view.land = OverworldLand.build()
	view.lake_level = view.land.lake_level
	view._rng.seed = 1931   # (as _ready would: the view is never put in the tree here)
	await get_tree().process_frame
	var holder := Node3D.new()
	add_child(holder)
	var terrain := OverworldTerrain.build(holder, view.land)
	view.plan()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OverworldBake.TERRAIN_DIR))
	terrain.data.save_directory(OverworldBake.TERRAIN_DIR)
	var bake := OverworldBake.new()
	bake.key = OverworldBake.current_key()
	bake.roads = view.land.roads
	bake.road_ids = view.land.road_ids
	bake.lake_level = view.land.lake_level
	bake.plants = view.baked_plants()
	bake.rocks = view.baked_rocks()
	var err := ResourceSaver.save(bake, OverworldBake.PATH)
	print("overworld bake: %s in %d ms, %d plant kinds, %d rocks" % [error_string(err), Time.get_ticks_msec() - t0, bake.plants.size(), bake.rocks.size()])
	view.free()
	get_tree().quit(0 if err == OK else 1)
