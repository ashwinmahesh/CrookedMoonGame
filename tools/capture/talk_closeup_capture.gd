extends Node
## Conversation close-ups (vault Build/Character Creator and Layered Figures.md, 3.5b): the party on the boarding
## ground, a conversation opened (TalkCamera.open), then each of --speakers saying a line in turn: the camera comes in
## close on them, they turn to face it and talk (TalkMotion: the jaw, the nod, the gestures), wearing their close-up
## look; a frame per shot for a GIF, then the camera easing back out.
##   make capture SCENE=res://tools/capture/talk_closeup_capture.tscn NAME=talk/x FRAMES=10 ARGS='--speakers=rook_coldwake,delphine_ravelle'
## Shots: <out>_<nnnn>.png.

const GAME := preload("res://world/game_root.gd")


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return default


func capture_shots(tool: Node, out: String) -> void:
	TalkCamera.headless_too = true
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = _arg("place", "ghostlight_boarding")
	st.minute_of_day = int(_arg("hour", "8")) * 60
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	for n in game.get_children():
		if n is CanvasLayer and n.name.begins_with("Place"):
			n.visible = false
	var view := game.get("view") as LocationView
	var talk := game.get("talk_motion") as TalkMotion
	var hud: Variant = game.get("hud")
	if hud is Object:
		(hud as Object).set("visible", false)   # as in a conversation
	view.rig.snap_to_target()
	await tool.call("wait_frames", 20)
	var n := 0
	TalkCamera.open(view, "")
	for k in 12:
		await tool.call("wait_frames", 2)
		tool.call("_shot", "%s_%04d.png" % [out, n])
		n += 1
	for speaker: String in _arg("speakers", "rook_coldwake,delphine_ravelle").split(",", false):
		TalkCamera.speaker(view, speaker)
		talk.spoke(view, speaker, "A line long enough to be said for about three seconds while the camera holds on them.")
		for k in 40:
			await tool.call("wait_frames", 2)
			tool.call("_shot", "%s_%04d.png" % [out, n])
			n += 1
	talk.stop()
	TalkCamera.close(view)
	for k in 14:
		await tool.call("wait_frames", 2)
		tool.call("_shot", "%s_%04d.png" % [out, n])
		n += 1
