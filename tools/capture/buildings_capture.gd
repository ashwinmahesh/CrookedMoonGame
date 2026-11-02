extends Node
## Each building that is one place with several floors (the location's map.floors), on every floor: the placeholder party stands on
## each floor's way in (a spawn that lies on it), and a shot is taken from the play camera and of the whole floor from above, with the
## floors over it out of sight as they are in the game.
##   make capture SCENE=res://tools/capture/buildings_capture.tscn NAME=buildings/x ARGS='--buildings=fw_windmill,dg_briar'
## --hour=8 shoots the Twilight Hour (the default is 23, the Midnight Hour).
## Shots: <out>_<place>_<floor id>_play.png and <out>_<place>_<floor id>_whole.png.

const GAME := preload("res://world/game_root.gd")


func capture_shots(tool: Node, out: String) -> void:
	var places: PackedStringArray = []
	var hour := 23
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--buildings="):
			places = a.get_slice("=", 1).split(",")
		if a.begins_with("--hour="):
			hour = int(a.get_slice("=", 1))
	for place in places:
		GameState.reset()
		var st := GameState.story
		for id: String in GAME.PLACEHOLDER_PARTY:
			var ch := Pregens.build(id, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		st.location = place
		st.minute_of_day = hour * 60
		Dice.reseed(7)
		var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(game)
		await tool.call("wait_frames", 150)
		for n in game.get_children():
			if n is CanvasLayer and n.name.begins_with("Place"):
				n.visible = false
		var view := game.get("view") as LocationView
		var rig := view.rig
		var distance := rig.distance
		var floors := (view.loc["map"] as Dictionary).get("floors", []) as Array
		for fi in floors.size():
			var fl := floors[fi] as Dictionary
			var spawn := _spawn_on(view, fl)
			if spawn == "":
				continue
			LocationParty.move_within(view, spawn)
			rig.follow = view.tokens.get(view.leader().id) as Node3D
			rig.horizon = 0.0
			rig.distance = distance
			rig.snap_to_target()
			await tool.call("wait_frames", 80)
			tool.call("_shot", "%s_%s_%s_play.png" % [out, place, fl["id"]])
			rig.follow = null
			rig.distance = maxf(float(fl["width"]), float(view.grid.depth)) * 1.05
			rig.global_position = Vector3(float(fl["width"]) / 2.0, float(fl["height_ft"]) / float(CombatGrid.FEET), view.grid.depth / 2.0)
			rig.snap_to_target()
			await tool.call("wait_frames", 30)
			tool.call("_shot", "%s_%s_%s_whole.png" % [out, place, fl["id"]])
		game.queue_free()
		await tool.call("wait_frames", 5)


## A spawn that lies on floor `fl`: the place's default if it does, else the first.
func _spawn_on(view: LocationView, fl: Dictionary) -> String:
	var spawns := view.loc.get("spawns", {}) as Dictionary
	var names: Array = spawns.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool: return (str(a) != "default") and (str(b) == "default" or str(a) < str(b)))
	for n: Variant in names:
		var x := int((spawns[n] as Array)[0])
		if x >= int(fl["x0"]) and x < int(fl["x0"]) + int(fl["width"]):
			return str(n)
	return ""
