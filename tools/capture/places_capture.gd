extends Node
## Any places seen from the play camera, as the game shows them: the placeholder party arrives at each location in the list and a shot is
## taken of the play view and of the whole place from above.
##   make capture SCENE=res://tools/capture/places_capture.tscn NAME=world/places ARGS='--places=ghostlight_boarding,wickermoor_village'
## --hour=8 shoots the Twilight Hour (the default is 23, the Midnight Hour).
## Shots: <out>_<place>_play.png and <out>_<place>_whole.png.

const GAME := preload("res://world/game_root.gd")


func capture_shots(tool: Node, out: String) -> void:
	var places: PackedStringArray = []
	var sky := false
	var travel := false
	var later := false
	var hour := 23
	var turn := false
	var morphs: PackedStringArray = []
	var flags: PackedStringArray = []
	var focus := Vector2(-1, -1)
	var focus_distance := 8.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--places="):
			places = a.get_slice("=", 1).split(",")
		if a.begins_with("--flags="):
			flags = a.get_slice("=", 1).split(",")   # story flags to set first, name:value (moon_grin:2,moon_scowl:true)
		if a.begins_with("--hour="):
			hour = int(a.get_slice("=", 1))   # the hour of the day (23 the Midnight Hour, the default; 8 the Twilight Hour)
		if a.begins_with("--morph="):
			morphs = a.get_slice("=", 1).split(",")   # the houses' morph weights to shoot from one fixed camera (with --focus)
		if a == "--turn":
			turn = true   # sets crooked_house_turned after the first shot and takes frames of the houses warping
		if a == "--later":
			later = true
		if a == "--travel":
			travel = true   # one more shot per place of the travel map, every place known
		if a.begins_with("--focus="):
			var f := a.get_slice("=", 1).split(",")   # a close shot of that square: x,z[,distance]
			focus = Vector2(float(f[0]), float(f[1]))
			if f.size() > 2:
				focus_distance = float(f[2])
		if a == "--sky":
			sky = true   # one more shot per place with the camera tilted to the horizon: the sky and the moon in it
	for place in places:
		GameState.reset()
		var st := GameState.story
		for id: String in GAME.PLACEHOLDER_PARTY:
			var ch := Pregens.build(id, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		st.location = place
		for f in flags:
			var v := f.get_slice(":", 1)
			st.set_flag(f.get_slice(":", 0), true if v == "true" else (int(v) if v.is_valid_int() else v))
		st.minute_of_day = hour * 60   # the Midnight Hour unless --hour says otherwise
		Dice.reseed(7)
		var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(game)
		await tool.call("wait_frames", 150)
		for n in game.get_children():
			if n is CanvasLayer and n.name.begins_with("Place"):
				n.visible = false
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s_%s_play.png" % [out, place])
		if turn:
			st.set_flag("crooked_house_turned", true)
			for k in 8:
				await tool.call("wait_frames", 14)
				tool.call("_shot", "%s_%s_turn_%d.png" % [out, place, k])
				print("turn frame %d: morph weight %.3f" % [k, BuildingMorph.weight((game.get("view") as LocationView).board)])
		var view := game.get("view") as LocationView
		var rig := view.rig
		if travel:
			for p: Variant in Travel.map_data().get("places", []) as Array:
				st.visited[str((p as Dictionary)["location"]).get_slice(":", 0)] = true
			var t := TravelScreen.new()
			game.add_child(t)
			t.open_map(st, Travel.place_for_location(st.location), false)
			await tool.call("wait_frames", 60)
			tool.call("_shot", "%s_%s_travel.png" % [out, place])
			t.queue_free()
			await tool.call("wait_frames", 5)
		if focus.x >= 0.0:
			rig.follow = null
			rig.horizon = 0.0
			rig.distance = focus_distance
			rig.global_position = view.board.cell_center(Vector2i(int(focus.x), int(focus.y)))
			rig.snap_to_target()
			await tool.call("wait_frames", 40)
			tool.call("_shot", "%s_%s_focus.png" % [out, place])
			for w in morphs:   # the houses at each morph weight from this same close camera
				BuildingMorph.set_weight(view.board, float(w))
				await tool.call("wait_frames", 10)
				tool.call("_shot", "%s_%s_morph_%s.png" % [out, place, w])
		if sky:
			rig.horizon = 1.0
			rig.horizon_shown = 1.0
			rig.distance = rig.zoom_max
			await tool.call("wait_frames", 40)
			# The moon in a clear sky straight ahead (the weather's cloud and the moon's own bearing hide it), to see its face.
			var post := view.atmosphere.get("_post") as ShaderMaterial
			if post != null:
				post.set_shader_parameter("sky_cover", 0.0)
				post.set_shader_parameter("sky_moon", 1.0)
				var ahead := -view.rig.camera.global_basis.z
				post.set_shader_parameter("sky_moon_dir", Vector3(ahead.x, 0.07, ahead.z).normalized())
				await tool.call("wait_frames", 10)
			tool.call("_shot", "%s_%s_sky.png" % [out, place])
		rig.horizon = 0.0
		rig.horizon_shown = 0.0
		rig.follow = null
		rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
		rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
		rig.snap_to_target()
		await tool.call("wait_frames", 30)
		tool.call("_shot", "%s_%s_whole.png" % [out, place])

		if later:
			await tool.call("wait_frames", 50)
			tool.call("_shot", "%s_%s_whole_later.png" % [out, place])   # the same view a moment on, to see what moves
		game.queue_free()
		await tool.call("wait_frames", 5)
