extends Node
## Conversation close-ups and the box (TalkCamera.close_up_shot): the Vagrant's menu at the boarding, his close-up with
## his options filling the box, then each of --speakers saying a short line, then a line with a long set of options, so
## the head shows (or doesn't) above the box at this window's size.
##   make capture SCENE=res://tools/capture/talk_frame_capture.tscn NAME=talk/frame FRAMES=1 ARGS='--size=1600x900'
## --speakers=a,b: party members or people on the map (Rook, Cordelia and the Vagrant by default).
## Shots: <out>_<n>_<speaker>.png.

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
	st.location = "ghostlight_boarding"
	st.minute_of_day = 8 * 60
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	game.call("start_dialogue", "ghostlight_express/vagrant_boarding:menu", "the_vagrant")
	var dlg := game.get("dialogue") as DialogueUI
	await tool.call("wait_frames", 60)
	tool.call("_shot", "%s_0_the_vagrant.png" % out)
	var n := 1
	var speakers := _arg("speakers", "rook_coldwake,cordelia_skein,the_vagrant").split(",", false)
	for speaker: String in speakers:
		var party := st.party.any(func(c: Character) -> bool: return c.id == speaker)
		dlg.call("_show", {"kind": "line", "speaker_id": speaker, "name": speaker.capitalize(), "portrait": speaker, "mood": "",
			"text": "A line long enough to fill the box for a moment while the camera holds on whoever says it.",
			"narrator": false, "party": party})
		await tool.call("wait_frames", 60)
		tool.call("_shot", "%s_%d_%s.png" % [out, n, speaker])
		n += 1
	var last := str(speakers[speakers.size() - 1]) if speakers.size() > 0 else "the_vagrant"
	var options: Array = []
	for i in 6:
		options.append({"label": "", "text": "A question the party might ask him, number %d of them." % (i + 1), "check": {}})
	dlg.call("_show", {"kind": "line", "speaker_id": last, "name": last.capitalize(), "portrait": last, "mood": "",
		"text": "And what would you like to know?", "narrator": false, "party": false})
	await tool.call("wait_frames", 30)
	dlg.call("_show", {"kind": "options", "options": options})
	await tool.call("wait_frames", 60)
	tool.call("_shot", "%s_%d_%s_options.png" % [out, n, last])
