extends Node
## Phase 0's exit capture (plan section 10.4): the foundation's test hillside seen from the play camera, as the game shows it.
## The placeholder party arrives at seven in the evening, walks up the hill to the cottage under the clock, and the same place is
## shot again at midnight (lanterns only). Three more shots show it tilted to the horizon and whole from above.
##   make capture NAME=hillside/first          (this scene is the default of make capture)
## Shots: <out>_1_arrival.png, _2_walking.png, _3_cottage.png, _4_midnight.png, _4b_noon.png, _5_tilt.png, _6_whole.png, _7_fight.png.

const GAME := preload("res://world/game_root.gd")
const LOCATION := "test_hillside"

var game: Node
var st: StoryState


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOCATION
	st.minute_of_day = 19 * 60   # twilight
	Dice.reseed(7)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	var view := game.get("view") as LocationView
	_declutter()
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_1_arrival.png")
	var goal := Vector2i(18, 13)
	view.walk_to(goal)
	await tool.call("wait_frames", 140)
	tool.call("_shot", out + "_2_walking.png")
	for i in 60:
		await tool.call("wait_frames", 15)
		if view.leader().cell == goal:
			break
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_3_cottage.png")
	print("capture: the party walked to %s; the clock reads %d minutes of the day" % [view.leader().cell, st.minute_of_day])
	st.minute_of_day = 0   # midnight (the engine has one night mood so far; the hours of the eternal night are plan E2)
	view.update_daylight()
	view.atmosphere.settle()
	game.call("_refresh")   # the explore bar reads the clock
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_4_midnight.png")
	# The same view at noon (the day look), then back to midnight for the rest.
	st.minute_of_day = 12 * 60
	view.update_daylight()
	view.atmosphere.settle()
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_4b_noon.png")
	st.minute_of_day = 0
	view.update_daylight()
	view.atmosphere.settle()
	await tool.call("wait_frames", 20)
	var rig := view.rig
	rig.horizon = 1.0
	rig.distance = 22.0
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_5_tilt.png")
	rig.horizon = 0.0
	rig.follow = null
	rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
	rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
	rig.snap_to_target()
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_6_whole.png")
	# A fight on the same land: the scarecrow on the bench wakes, and the heroes fight it from the meadow.
	rig.horizon = 0.0
	rig.follow = null
	view.start_encounter("hillside_scarecrows")
	await tool.call("wait_frames", 120)
	tool.call("_shot", out + "_7_fight.png")


## The loading card and the place title are up for a moment on arrival; a capture of the place itself waits them out.
func _declutter() -> void:
	for n in game.get_children():
		if n is CanvasLayer and n.name.begins_with("Place"):
			n.visible = false
