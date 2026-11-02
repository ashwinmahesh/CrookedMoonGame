extends Node
## The 3D overworld as the game opens it: the party at the Ghostlight Wreckage with the roads of the whole map open, the
## overworld opened to set out (GameRoot.open_travel), a far place chosen from each new region (the swamp, the cemetery, the
## shore, the fields, the woods, Dawn's Gate), the D-pad lighting a place, then Wickermoor chosen and the lantern part-way
## down the road.
##   make capture SCENE=res://tools/capture/overworld_screen_capture.tscn NAME=overworld/screen
## Shots: <out>_open.png, <out>_to_<place>.png for each far place, <out>_pad.png, <out>_chosen.png, <out>_walking.png,
## <out>_arrived.png (Wickermoor, by the game's own travel).

## Places far across the map, one for each region the whole-map land added.
const FAR_PLACES := ["dc_murkwater", "maidenmist_gate", "memorys_rest", "foxwillow", "hartsblight_forest", "dawns_gate"]

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
	for id: String in ["wickermoor_village", "dc_trail1", "dc_murkwater", "maidenmist_gate", "mr_shore", "foxwillow", "hb_patient_commune", "dawns_gate"]:
		st.visited[id] = true
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
	for far: String in FAR_PLACES:
		screen.select(far)
		await tool.call("wait_frames", 40)
		tool.call("_shot", out + "_to_" + far + ".png")
	screen.select("wickermoor_village")
	if PadNav.current != null:
		PadNav.current.set(&"_dpad_held", Vector2i.RIGHT)   # (what PadNav notes on a D-pad press, as against a stick lean)
	screen.pad_step(screen._holder, Vector2i.RIGHT)   # (a D-pad press from Wickermoor lights the next place east)
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_pad.png")
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
