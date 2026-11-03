extends Node
## The village houses' variety: two rows of houses built from the village kit under plain daylight, shot with the texture sets'
## `variants` stripped (the houses differ only by tint, as before) and again with them (art/textures/manifest.json, themes.vkit),
## from high above and from two close 3/4 views.
##   make capture SCENE=res://tools/capture/village_variety_capture.tscn NAME=variety/x
## Shots: <out>_<before|after>_whole.png, _left.png and _right.png.

const COLUMNS := 6
const HOUSE := 4
const GAP := 3
const WIDTH := COLUMNS * (HOUSE + GAP) + 2
const DEPTH := 2 * (HOUSE + 3) + 2

var _board: ArenaBoard
var _cam: Camera3D


func _rows() -> Array:
	var rows: Array = []
	for z in DEPTH:
		var line := ""
		for x in WIDTH:
			var col := (x - 1) / (HOUSE + GAP)
			var in_x := x >= 1 and (x - 1) % (HOUSE + GAP) < HOUSE and col < COLUMNS
			var row := (z - 1) / (HOUSE + 3)
			var in_z := z >= 1 and (z - 1) % (HOUSE + 3) < HOUSE and row < 2
			line += "#" if in_x and in_z else "."
		rows.append(line)
	return rows


func capture_shots(tool: Node, out: String) -> void:
	Look.set_style("modern", false)
	var vkit := (Look.textures().get("themes", {}) as Dictionary).get("vkit", {}) as Dictionary
	var variants := {}
	for set_name: String in vkit:
		var info := vkit[set_name] as Dictionary
		if info.has("variants"):
			variants[set_name] = info["variants"]
			info.erase("variants")
	await _round(tool, out + "_before")
	for set_name: String in variants:
		(vkit[set_name] as Dictionary)["variants"] = variants[set_name]
	await _round(tool, out + "_after")


func _round(tool: Node, out: String) -> void:
	PackMaterials._made.clear()
	BuildingKit.forget()
	if _board != null:
		_board.free()
	var elev: Array = []
	for z in DEPTH:
		elev.append("1".repeat(WIDTH))
	_board = ArenaBoard.build(CombatGrid.from_rows(_rows(), elev), "village", "village_variety_capture")
	add_child(_board)
	PackMaterials.apply(_board)
	if _cam == null:
		_light()
	await tool.call("wait_frames", 40)
	var mid := Vector3(WIDTH / 2.0, 0.0, DEPTH / 2.0)
	_look(Vector3(mid.x, 34.0, DEPTH + 22.0), mid)
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_whole.png")
	_look(Vector3(WIDTH * 0.25, 8.0, DEPTH + 9.0), Vector3(WIDTH * 0.25, 2.0, DEPTH * 0.45))
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_left.png")
	_look(Vector3(WIDTH * 0.75, 8.0, DEPTH + 9.0), Vector3(WIDTH * 0.75, 2.0, DEPTH * 0.45))
	await tool.call("wait_frames", 20)
	tool.call("_shot", out + "_right.png")


func _look(from: Vector3, at: Vector3) -> void:
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)


func _light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.23, 0.25, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.72)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.far = 400.0
	add_child(_cam)
	_cam.make_current()
