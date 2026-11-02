extends Node
## The 3D overworld (world/overworld/) from the party's road, from high over the whole map, and close on the regions the
## whole-map land added: the swamp, Maidenmist's misty rise, Memory's Rest on its shore, Foxwillow's fields, the
## Hartsblight's dark woods, Dawn's Gate under its crags, the prairie and the foothills.
##   make capture SCENE=res://tools/capture/overworld_capture.tscn NAME=overworld/x
## Shots: <out>_road.png, _whole.png, _high.png, _estate.png, _village.png, _swamp.png, _swamp_close.png, _cemetery.png, _cemetery_close.png,
## _shore.png, _fields.png, _woods.png, _gate.png, _prairie.png, _foothills.png and _lakeshore.png.


func capture_shots(tool: Node, out: String) -> void:
	var t0 := Time.get_ticks_msec()
	var view := (load("res://scenes/overworld.tscn") as PackedScene).instantiate() as OverworldView
	add_child(view)
	print("overworld built in %d ms" % (Time.get_ticks_msec() - t0))
	await tool.call("wait_frames", 90)
	tool.call("_shot", out + "_road.png")
	view.look_from(Vector2(1024.0, 1000.0), 1750.0, 1950.0)
	await tool.call("wait_frames", 60)
	tool.call("_shot", out + "_whole.png")
	view.look_from(view.party_at, 420.0, 520.0)
	await tool.call("wait_frames", 60)
	tool.call("_shot", out + "_high.png")
	var spots := [
		["estate", "druskenvald_estate", Vector2(-30.0, 160.0), 70.0, 110.0],
		["village", "wickermoor_village", Vector2.ZERO, 120.0, 170.0],
		["swamp", "dc_trail1", Vector2(0.0, -120.0), 260.0, 420.0],
		["swamp_close", "dc_murkwater", Vector2(0.0, 30.0), 45.0, 90.0],
		["cemetery", "maidenmist_gate", Vector2(0.0, 40.0), 90.0, 190.0],
		["cemetery_close", "maidenmist_gate", Vector2(0.0, 30.0), 22.0, 75.0],
		["shore", "memorys_rest", Vector2(60.0, 0.0), 120.0, 260.0],
		["fields", "foxwillow", Vector2(0.0, 40.0), 150.0, 330.0],
		["woods", "hartsblight_forest", Vector2(0.0, 0.0), 90.0, 200.0],
		["gate", "dawns_gate", Vector2(-40.0, 40.0), 150.0, 300.0],
		["prairie", "rk_roost_prairie", Vector2(0.0, 40.0), 60.0, 150.0],
		["foothills", "rk_roost_foothills", Vector2(0.0, 80.0), 90.0, 220.0],
		["lakeshore", "rk_roost_lakeshore", Vector2(0.0, 0.0), 330.0, 230.0]]
	for s: Array in spots:
		view.look_from(view._place_at(str(s[1])) + (s[2] as Vector2), float(s[3]), float(s[4]))
		await tool.call("wait_frames", 50)
		tool.call("_shot", out + "_" + str(s[0]) + ".png")
