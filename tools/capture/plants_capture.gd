extends Node
## The realistic plants (RealTrees) on their own, in plain daylight on flat ground with the wind blowing, side by side: the
## ground plants against their painted stand-ins' sizes, and the trees. For checking shapes, sizes and materials (a white or
## black leaf, a plant floating or buried) away from a place's night.
##   make capture SCENE=res://tools/capture/plants_capture.tscn NAME=plants/own
## Shots: <out>_ground1.png, _ground2.png, _trees.png, _painted_ground1.png (the painted plants, for the same view), and
## _ground1_later.png, _ground2_later.png (the same views a moment on, to see them sway).

const GROUND_1: Array[String] = ["grass_a", "grass_b", "grass_dry", "sedge", "reeds", "cattails", "heather"]
const GROUND_2: Array[String] = ["fern_a", "fern_b", "fern_small", "bracken", "bush_a", "bush_b"]
const TREES: Array[String] = ["oak_a", "spruce_a", "birch_a", "dead_a", "oak_b", "spruce_b"]


func capture_shots(tool: Node, out: String) -> void:
	Look.set_style("modern", false)
	RealTrees.install()
	var world := Node3D.new()
	add_child(world)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.26, 0.2)
	floor_mesh.material_override = floor_mat
	world.add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.65)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	var all_ids: Array[String] = []
	all_ids.append_array(GROUND_1)
	all_ids.append_array(GROUND_2)
	all_ids.append_array(TREES)
	# Every material in Flora's own wind, as a windy place sets it.
	for key: String in Flora._all_material_keys():
		var m := Flora._material(key)
		m.set_shader_parameter("wind_strength", 0.5)
	await tool.call("wait_frames", 5)
	var shots: Array = [["ground1", GROUND_1, 1.1, 2.6], ["ground2", GROUND_2, 1.5, 3.4], ["trees", TREES, 5.0, 14.0]]
	for painted: bool in [false, true]:
		for s: Array in shots:
			if painted and s[0] == "trees":
				continue
			var holder := Node3D.new()
			world.add_child(holder)
			var ids := s[1] as Array
			var gap := float(s[2])
			for i in ids.size():
				for c in 3:
					var mi := MeshInstance3D.new()
					mi.mesh = _painted_mesh(str(ids[i])) if painted else Flora.mesh(str(ids[i]))
					mi.position = Vector3((float(i) - float(ids.size() - 1) * 0.5) * gap, 0.0, float(c) * gap * 0.8 - gap * 0.8)
					mi.rotation.y = float(c) * 1.9
					holder.add_child(mi)
			cam.position = Vector3(0, float(s[3]) * 0.55, float(s[3]) * 1.15)
			cam.look_at(Vector3(0, float(s[3]) * 0.08, 0))
			await tool.call("wait_frames", 40)
			tool.call("_shot", "%s_%s%s.png" % [out, "painted_" if painted else "", s[0]])
			if not painted and s[0] != "trees":
				# A moment later in the wind: the plants have moved (compare the two).
				await tool.call("wait_frames", 50)
				tool.call("_shot", "%s_%s_later.png" % [out, s[0]])
			holder.queue_free()
			await tool.call("wait_frames", 3)


## The painted plant's own mesh (Flora's, made from its glb with the engine's shaders).
func _painted_mesh(id: String) -> Mesh:
	var saved: Variant = Flora._meshes.get(id)
	Flora._meshes.erase(id)
	var m := Flora.mesh(id)
	Flora._meshes[id] = saved
	return m
