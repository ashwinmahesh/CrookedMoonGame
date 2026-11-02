extends Node
## The 3D overworld as the game opens it: the party at the Ghostlight Wreckage with the road to Wickermoor open, the
## overworld opened to set out (GameRoot.open_travel), Wickermoor chosen, and the lantern part-way down the road.
##   make capture SCENE=res://tools/capture/overworld_screen_capture.tscn NAME=overworld/screen
## Shots: <out>_open.png, <out>_chosen.png, <out>_walking.png, <out>_arrived.png (Wickermoor, by the game's own travel).

const GAME := preload("res://world/game_root.gd")


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = "ghostlight_wreckage"
	st.visited["ghostlight_wreckage"] = true
	st.set_flag("gl_last_stop", true)
	st.minute_of_day = 23 * 60
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 120)
	var t0 := Time.get_ticks_msec()
	game.call("open_travel", true)
	print("overworld opened in %d ms" % (Time.get_ticks_msec() - t0))
	var screen := game.get("screen") as OverworldScreen
	await tool.call("wait_frames", 60)
	tool.call("_shot", out + "_open.png")
	if screen == null:
		push_error("the overworld didn't open")
		return
	screen.select("wickermoor_village")
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_chosen.png")
	var go := screen.find_child("SetOut", true, false) as Button
	if go != null:
		go.pressed.emit()
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_walking.png")
	await tool.call("wait_frames", 260)
	tool.call("_shot", out + "_arrived.png")
