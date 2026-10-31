extends Node
## The Bestiary with portraits (vault Build/Portrait UI Wiring.md): the journal's Bestiary page with three creatures met, one
## with a picture and two with the silhouette, then a fight's turn order beside the party.
##   make capture SCENE=res://tools/capture/portraits_capture.tscn NAME=portraits/x FRAMES=30
## Shots: <out>_bestiary_1.png (a creature with its picture), <out>_bestiary_2.png (one without).

const GAME := preload("res://world/game_root.gd")
const MET := ["soulfire_stoker", "wayward_haint", "ghostlight_locomotive"]


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = GAME.FIRST_LOCATION
	var n := 0
	for id: String in MET:
		st.bestiary[id] = {"n": n, "met": 1, "where": "", "defeated": 1, "studied": n == 0}
		n += 1
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 40)
	game.call("open_screen", "journal", 0)
	await tool.call("wait_frames", 5)
	var journal := game.get("screen") as Node
	journal.call("_turn_to", "Bestiary")
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_bestiary_1.png")
	journal.set("beast", MET[1])
	journal.call("_turn_to", "Bestiary")
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_bestiary_2.png")
