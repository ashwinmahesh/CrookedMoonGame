extends Node
## The gnarled EZ-Tree set pieces up close (art/plants/ez_setpiece): the Pine Barrens with the raven oak, the lookout tree and
## each kind of dead tree set down beside the party, one close shot of each and one of the lot from the play camera.
##   make capture SCENE=res://tools/capture/set_piece_trees_capture.tscn NAME=trees/set FRAMES=60
## Shots: <out>_play.png, <out>_<tree>.png.

const GAME := preload("res://world/game_root.gd")
const PLACE := "hb_pine_barrens"   # (--place=test_hillside for open ground)
## [catalog prop id, model (for a dead_tree prop), offset from the leader in squares]
const TREES: Array = [["raven_oak", "", Vector2i(4, -3)], ["ambush_lookout_tree", "", Vector2i(-4, -2)],
	["dead_a", "dead_tree_a", Vector2i(3, 3)], ["dead_b", "dead_tree_b", Vector2i(-3, 3)]]


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	var place := PLACE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--place="):
			place = a.get_slice("=", 1)
	st.location = place
	st.minute_of_day = 23 * 60
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	for n in game.get_children():
		if n is CanvasLayer and n.name.begins_with("Place"):
			n.visible = false
	var view := game.get("view") as LocationView
	var lead := view.leader().cell
	for t: Array in TREES:
		var cell := lead + (t[2] as Vector2i)
		var spec := {"id": str(t[0]), "kind": "decor", "cell": [cell.x, cell.y], "label": "a tree"}
		if str(t[1]) != "":
			spec["model"] = str(t[1])
		SetDressing.place(view.board, spec)
	await tool.call("wait_frames", 40)
	tool.call("_shot", "%s_play.png" % out)
	var rig := view.rig
	rig.follow = null
	rig.horizon = 0.0
	for t: Array in TREES:
		var cell := lead + (t[2] as Vector2i)
		rig.distance = 8.0
		rig.global_position = view.board.cell_center(cell) + Vector3(0.0, 1.6, 0.0)
		rig.snap_to_target()
		await tool.call("wait_frames", 30)
		tool.call("_shot", "%s_%s.png" % [out, t[0]])
	game.queue_free()
	await tool.call("wait_frames", 5)
