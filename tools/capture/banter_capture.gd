extends Node
## The companions talking (fun pass lane A): a region banter exchange in the Narrator's box on Wickermoor's square, then
## Rook's first camp talk, its opening line and its choice.
##   make capture SCENE=res://tools/capture/banter_capture.tscn NAME=companions/x FRAMES=30
## Shots: <out>_banter.png, <out>_camp_1.png (the talk's first line), <out>_camp_2.png (a few lines on).

const GAME := preload("res://world/game_root.gd")
const BANTER := "banter/wickermoor:wickermoor_village_03_silas_cordelia"
const CAMP := "camp/rook_coldwake:talk_act1"


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = "wickermoor_village"
	st.minute_of_day = 0
	st.set_flag("gl_crashed")
	st.set_flag("vessla_slain")
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	var lines := Banter._lines(BANTER, st)
	print("banter: %d lines" % lines.size())
	game.call("_show_banter", lines)
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_banter.png")
	# Rook's first-act talk wants the house still haunted.
	st.flags.erase("vessla_slain")
	game.call("start_dialogue", CAMP, "rook_coldwake")
	var dlg := game.get("dialogue") as DialogueUI
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_camp_1.png")
	for i in 3:
		if dlg != null and is_instance_valid(dlg) and dlg.has_method("_advance"):
			dlg.call("_advance")
		await tool.call("wait_frames", 15)
	tool.call("_shot", out + "_camp_2.png")
