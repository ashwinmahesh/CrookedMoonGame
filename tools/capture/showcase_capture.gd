extends Node
## Every built place for a showcase: the companions arrive at each place in the list and it is shot from the play
## camera, then the camera turns once round the party (a slow orbit, saved frame by frame for a GIF or a film), and the
## whole place is shot from above.
##   make capture SCENE=res://tools/capture/showcase_capture.tscn NAME=showcase/x ARGS='--places=ghostlight_boarding,fw_hall'
## --close_prop=<prop id> or --close_cell=x,z: also close shots of that spot from three sides (<out>_<place>_close*.png),
## and with --still=N, N frames of it from the camera standing still (<out>_<place>_still_<nnn>.jpg, for a GIF).
## --hour: the hour (8 the Twilight Hour); --orbit: frames in the orbit (0 for none; default 60), each saved at
## --orbit_size (default 800x450) as JPEG. Shots: <out>_<place>_play.png, <out>_<place>_whole.png and
## <out>_<place>_orbit_<nnn>.jpg. tools/capture/frames_to_gif.py makes a GIF of each orbit.

const GAME := preload("res://world/game_root.gd")


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return default


## Where --close_prop (a prop's id) or --close_cell (x,z) puts the camera for a close look, or INF for none.
func _close_on(view: LocationView) -> Vector3:
	var prop := _arg("close_prop", "")
	if prop != "" and view.prop_cell(prop) != null:
		return view.board.cell_center(view.prop_cell(prop) as Vector2i)
	var cell := _arg("close_cell", "").split(",")
	if cell.size() == 2:
		return view.board.cell_center(Vector2i(int(cell[0]), int(cell[1])))
	return Vector3.INF


func capture_shots(tool: Node, out: String) -> void:
	var orbit := int(_arg("orbit", "60"))
	var size := _arg("orbit_size", "800x450").split("x")
	for place in _arg("places", "").split(",", false):
		GameState.reset()
		var st := GameState.story
		for id: String in GAME.NEW_GAME_PARTY:
			var ch := Pregens.build(id, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		st.location = place
		st.minute_of_day = int(_arg("hour", "8")) * 60
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
		var close := _close_on(view)
		if close != Vector3.INF:
			rig.follow = null
			rig.global_position = close
			rig.distance = float(_arg("close_distance", "9"))
			rig.snap_to_target()
			await tool.call("wait_frames", 40)
			tool.call("_shot", "%s_%s_close.png" % [out, place])
			for turn: int in [90, 180]:
				rig.turn_by(90.0)
				rig.snap_to_target()
				await tool.call("wait_frames", 30)
				tool.call("_shot", "%s_%s_close_%d.png" % [out, place, turn])
			rig.turn_by(180.0)
			rig.snap_to_target()
			# --still=N: N frames of the close spot from where the camera stands, for a GIF of something that moves
			# there (running water, a flame).
			for i in int(_arg("still", "0")):
				await tool.call("wait_frames", 3)
				var img := get_viewport().get_texture().get_image()
				img.resize(int(size[0]), int(size[1]), Image.INTERPOLATE_LANCZOS)
				img.save_jpg("%s_%s_still_%03d.jpg" % [out, place, i], 0.85)
			rig.follow = view.tokens.get(view.leader().id) as Node3D
			rig.distance = 13.0
		for i in orbit:
			rig.turn_by(360.0 / orbit)
			rig.snap_to_target()
			await tool.call("wait_frames", 2)
			var img := get_viewport().get_texture().get_image()
			img.resize(int(size[0]), int(size[1]), Image.INTERPOLATE_LANCZOS)
			img.save_jpg("%s_%s_orbit_%03d.jpg" % [out, place, i], 0.85)
		rig.horizon = 0.0
		rig.follow = null
		rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
		rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
		rig.snap_to_target()
		await tool.call("wait_frames", 30)
		tool.call("_shot", "%s_%s_whole.png" % [out, place])
		print("showcase: ", place)
		game.queue_free()
		await tool.call("wait_frames", 5)
