extends Node
## The plants (art/plants/manifest.json, Flora.mesh) set in a row on a plain stage under a sun and a sky, with the game's own leaf and bark
## materials, from a low three-quarter view: to check a new model or a repainted leaf card before a set plants it.
##   make capture SCENE=res://tools/capture/plant_stage_capture.tscn NAME=plants/x ARGS='--plants=corn_a,corn_b,wytch_a'
## --plants: the ids, left to right, spaced by their widths; --scale (1); --wind (0.25: the wind strength the materials bend with);
## --tint (a leaf tint such as #f4ecc0, the way a set tints its plants), --set (a flora.json set id such as corn, fungal or willows: its
## tints, bark colours and scanned barks, as Flora applies them to a place). Shots: <out>_front.png (low, near) and _high.png (the game's
## camera angle, from above).


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return default


func capture_shots(tool: Node, out: String) -> void:
	var ids := _arg("plants", "corn_a").split(",", false)
	var scale_up := float(_arg("scale", "1"))
	var root := Node3D.new()
	add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.52, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(-35.0), 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 40)
	floor_mi.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.27, 0.22)
	floor_mat.roughness = 1.0
	floor_mi.material_override = floor_mat
	root.add_child(floor_mi)
	var wind := float(_arg("wind", "0.25"))
	var tint := Color(_arg("tint", "#ffffff"))
	var set_id := _arg("set", "")
	if set_id != "":
		var f := Flora.new()
		f.spec = Flora.resolve(set_id)
		f._apply(Vector2(0.9, 0.35).normalized(), wind)
	var width := 0.0
	var gap := 0.6
	var placed: Array[MeshInstance3D] = []
	for id: String in ids:
		var mesh := Flora.mesh(id)
		if mesh == null:
			push_warning("plants_capture: no plant %s" % id)
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as ShaderMaterial
			if m != null and set_id == "":
				m.set_shader_parameter("wind_dir", Vector2(0.9, 0.35).normalized())
				m.set_shader_parameter("wind_strength", wind)
				if m.get_shader_parameter("tint") != null:
					m.set_shader_parameter("tint", tint)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = id
		mi.scale = Vector3.ONE * scale_up
		root.add_child(mi)
		var w := float(((Flora.manifest().get(id, {}) as Dictionary).get("size", [1.0, 1.0, 1.0]) as Array)[0]) * scale_up
		mi.position = Vector3(width + w / 2.0, 0, 0)
		width += w + gap
		placed.append(mi)
	for mi in placed:
		mi.position.x -= width / 2.0
	var tallest := 1.0
	for id: String in ids:
		tallest = maxf(tallest, Flora.height_of(id) * scale_up)
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	# Wood and leaves nearer the camera than about 5 units thin away (the game's near fade, so a camera tilted down sees past trees): keep
	# the camera beyond that, and narrow its view to keep small plants in frame.
	var natural := maxf(width * 0.62, tallest * 1.5)
	var reach := maxf(natural, 6.0)
	cam.fov = clampf(40.0 * natural / reach, 8.0, 40.0)
	var look := Vector3(0, tallest * 0.4, 0)
	cam.position = look + Vector3(0, tallest * 0.15, reach)
	cam.look_at(look)
	await tool.call("wait_frames", 60)
	tool.call("_shot", "%s_front.png" % out)
	cam.position = look + Vector3(0, reach * 0.8, reach * 0.8)
	cam.look_at(look - Vector3(0, tallest * 0.2, 0))
	await tool.call("wait_frames", 20)
	tool.call("_shot", "%s_high.png" % out)
