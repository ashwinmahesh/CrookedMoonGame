extends Node
## Talking figures (vault Build/Talking Figures.md): the Vagrant greeting the party at the boarding, his portrait as the
## big bust beside the box, and his figure nodding and gesturing while the line is said, then Rook answering from the left.
##   make capture SCENE=res://tools/capture/talk_capture.tscn NAME=talk/x FRAMES=30
## Shots: <out>_screen_1.png and _screen_2.png (the whole screen on the Vagrant's line), <out>_close.png (on him, the box hidden),
## <out>_party.png (Rook's line);
## <out>_head_<nn>.png close-ups of the Vagrant's head every few frames, for a strip or a GIF.

const GAME := preload("res://world/game_root.gd")
const LOCATION := "ghostlight_boarding"
const DIALOGUE := "ghostlight_express/vagrant_boarding:menu"


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOCATION
	st.minute_of_day = 0
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	game.call("start_dialogue", DIALOGUE, "the_vagrant")
	var dlg := game.get("dialogue") as DialogueUI
	await tool.call("wait_frames", 40)   # the camera eases in on the two
	var view := game.get("view") as LocationView
	var vagrant := FigureTalk.token_of(view, "the_vagrant")
	var cam := get_viewport().get_camera_3d()
	var talk := game.get("talk_motion") as TalkMotion
	print("talk: speaking %s, nod %s, vagrant on screen at %s" % [talk.talking(), TalkMotion.nod_of(vagrant, false) != null,
		cam.unproject_position(vagrant.global_position) if vagrant != null and cam != null else Vector2(-1, -1)])
	tool.call("_shot", out + "_screen_1.png")
	# Close on the Vagrant for his head: the box and the busts hidden, the line said again (a capture draws slower than
	# the clock runs, so its made-up speaking time is spent before many frames are drawn).
	var rig := view.rig
	rig.follow = null
	rig.global_position = vagrant.global_position
	rig.distance = 4.0
	rig.snap_to_target()
	dlg.visible = false
	await tool.call("wait_frames", 10)
	talk.spoke(view, "the_vagrant", "x".repeat(200))
	for i in 24:
		await tool.call("wait_frames", 4)
		if vagrant != null and cam != null:
			_head_shot(tool, "%s_head_%02d.png" % [out, i], cam, vagrant)
		if i == 12:
			tool.call("_shot", out + "_close.png")
	dlg.visible = true
	rig.distance = 11.0
	rig.snap_to_target()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_screen_2.png")
	# Rook answers: a party line puts his bust on the left, lit, and the Vagrant's dims.
	dlg.call("_show", {"kind": "line", "speaker_id": "rook_coldwake", "name": "Rook Coldwake", "portrait": "rook_coldwake",
		"mood": "", "text": "Unlicensed track, no foundation under the ties, and a frog in a hat.", "narrator": false, "party": true})
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_party.png")


## A square close-up around the figure's head, cut from the screen.
func _head_shot(tool: Node, path: String, cam: Camera3D, tok: CombatToken) -> void:
	var top := tok.global_position + Vector3(0, 0.9, 0)
	var p := cam.unproject_position(top)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("talk: no image for %s" % path)
		return
	var half := 110
	var r := Rect2i(int(p.x) - half, int(p.y) - half, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x > 0 and r.size.y > 0:
		img.get_region(r).save_png(path)
