extends Node
## The Visual Polish Plan's first tier (vault Build/Visual Polish Plan.md: the painted finish, bough shadows, the moon in the
## water, lantern strings) on the test hillside at midnight, from the game's own settings, beside the same view without them.
##   make capture SCENE=res://tools/capture/polish_capture.tscn NAME=polish/x
## Shots: <out>_<view>_a_before.png (none of it), _b_high.png (the game's settings on High), _c_medium.png (Medium: no
## brush strokes), for the views cottage and pond.

const GAME := preload("res://world/game_root.gd")
const LOCATION := "test_hillside"


func capture_shots(tool: Node, out: String) -> void:
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOCATION
	st.minute_of_day = 0
	Dice.reseed(7)
	Graphics.set_preset("high", false)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	for n in game.get_children():
		if n is CanvasLayer:
			n.visible = false
	var view := game.get("view") as LocationView
	view.update_daylight()
	view.atmosphere.settle()
	var atmo := view.atmosphere
	var post := atmo.get("_post") as ShaderMaterial
	var strings := get_tree().root.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is LightString)
	print("polish: %d lantern strings" % strings.size())
	var rig := view.rig
	rig.follow = null
	for spot: Array in [["cottage", Vector3(17.5, 0, 14.5), 11.0], ["pond", Vector3(15.5, 0, 20.0), 9.0]]:
		rig.global_position = spot[1]
		rig.distance = spot[2]
		rig.snap_to_target()
		await tool.call("wait_frames", 30)
		var name_: String = spot[0]
		var own: Dictionary = atmo.painted
		atmo.painted = Look.PAINTED   # (the atmosphere aims the moon each frame from its own settings)
		_show(strings, false)
		PaintedFinish.apply(post, Look.PAINTED)
		await _shot(tool, "%s_%s_a_before.png" % [out, name_], post, Look.PAINTED, false)
		atmo.painted = own
		_show(strings, true)
		PaintedFinish.apply(post, atmo.painted)
		await _shot(tool, "%s_%s_b_high.png" % [out, name_], post, atmo.painted, true)
		Graphics.set_preset("medium", false)
		PaintedFinish.apply(post, atmo.painted)
		await _shot(tool, "%s_%s_c_medium.png" % [out, name_], post, atmo.painted, true)
		Graphics.set_preset("high", false)


func _show(nodes: Array, on: bool) -> void:
	for n: Node in nodes:
		(n as Node3D).visible = on
		for l in n.find_children("*", "OmniLight3D", true, false):
			(l as OmniLight3D).visible = on


func _shot(tool: Node, path: String, post: ShaderMaterial, s: Dictionary, moon: bool) -> void:
	await tool.call("wait_frames", 10)
	if not moon:
		post.set_shader_parameter("moon_water", 0.0)
	else:
		PaintedFinish.aim_moon(post, s, get_viewport().get_camera_3d())
	await tool.call("wait_frames", 2)
	tool.call("_shot", path)
