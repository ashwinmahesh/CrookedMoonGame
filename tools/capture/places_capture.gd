extends Node
## Any places seen from the play camera, as the game shows them: the placeholder party arrives at each location in the list and a shot is
## taken of the play view and of the whole place from above.
##   make capture SCENE=res://tools/capture/places_capture.tscn NAME=world/places ARGS='--places=ghostlight_boarding,wickermoor_village'
## Shots: <out>_<place>_play.png and <out>_<place>_whole.png.

const GAME := preload("res://world/game_root.gd")


func capture_shots(tool: Node, out: String) -> void:
	var places: PackedStringArray = []
	var sky := false
	var travel := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--places="):
			places = a.get_slice("=", 1).split(",")
		if a == "--travel":
			travel = true   # one more shot per place of the travel map, every place known
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
		st.minute_of_day = 23 * 60   # the Midnight Hour
		Dice.reseed(7)
		var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(game)
		await tool.call("wait_frames", 150)
		for n in game.get_children():
			if n is CanvasLayer and n.name.begins_with("Place"):
				n.visible = false
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s_%s_play.png" % [out, place])
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
		if sky:
			rig.horizon = 1.0
			rig.horizon_shown = 1.0
			rig.distance = rig.zoom_max
			await tool.call("wait_frames", 40)
			tool.call("_shot", "%s_%s_sky.png" % [out, place])
		rig.horizon = 0.0
		rig.horizon_shown = 0.0
		rig.follow = null
		rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
		rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
		rig.snap_to_target()
		await tool.call("wait_frames", 30)
		tool.call("_shot", "%s_%s_whole.png" % [out, place])
		game.queue_free()
		await tool.call("wait_frames", 5)
