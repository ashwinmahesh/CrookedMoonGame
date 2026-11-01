extends Node
## Any places seen from the play camera, as the game shows them: the placeholder party arrives at each location in the list and a shot is
## taken of the play view and of the whole place from above.
##   make capture SCENE=res://tools/capture/places_capture.tscn NAME=world/places ARGS='--places=ghostlight_boarding,wickermoor_village'
## Shots: <out>_<place>_play.png and <out>_<place>_whole.png. `--flags=a:3,b:true` sets story flags first (a counter, a
## stage of the story).

const GAME := preload("res://world/game_root.gd")


func capture_shots(tool: Node, out: String) -> void:
	var places: PackedStringArray = []
	var flags := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--places="):
			places = a.get_slice("=", 1).split(",")
		if a.begins_with("--flags="):
			for pair in a.get_slice("=", 1).split(","):
				var v := pair.get_slice(":", 1)
				flags[pair.get_slice(":", 0)] = int(v) if v.is_valid_int() else (v == "true")
	for place in places:
		GameState.reset()
		var st := GameState.story
		for id: String in GAME.PLACEHOLDER_PARTY:
			var ch := Pregens.build(id, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		st.location = place
		st.flags.merge(flags, true)
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
		rig.horizon = 0.0
		rig.follow = null
		rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
		rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
		rig.snap_to_target()
		await tool.call("wait_frames", 30)
		tool.call("_shot", "%s_%s_whole.png" % [out, place])
		game.queue_free()
		await tool.call("wait_frames", 5)
