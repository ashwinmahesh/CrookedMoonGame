extends Node
## The 3D overworld pilot (world/overworld/) from the party's road, from high over the hollow, and close on the road
## climbing to the estate.
##   make capture SCENE=res://tools/capture/overworld_capture.tscn NAME=overworld/x
## Shots: <out>_road.png, <out>_high.png, <out>_estate.png and <out>_village.png.


func capture_shots(tool: Node, out: String) -> void:
	var t0 := Time.get_ticks_msec()
	var view := (load("res://scenes/overworld.tscn") as PackedScene).instantiate() as OverworldView
	add_child(view)
	print("overworld built in %d ms" % (Time.get_ticks_msec() - t0))
	await tool.call("wait_frames", 90)
	tool.call("_shot", out + "_road.png")
	view.look_from(view.party_at, 420.0, 520.0)
	await tool.call("wait_frames", 60)
	tool.call("_shot", out + "_high.png")
	view.look_from(view._place_at("druskenvald_estate") + Vector2(-30.0, 160.0), 70.0, 110.0)
	await tool.call("wait_frames", 60)
	tool.call("_shot", out + "_estate.png")
	view.look_from(view._place_at("wickermoor_village"), 120.0, 170.0)
	await tool.call("wait_frames", 60)
	tool.call("_shot", out + "_village.png")
