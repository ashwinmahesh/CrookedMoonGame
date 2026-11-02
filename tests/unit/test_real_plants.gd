extends TestCase
## The realistic trees and ground plants (RealTrees, PlantCards): every painted plant on the stand-in list draws a mesh
## wearing the game's wind shader, the ground plants stay light enough to be drawn by the thousand and keep the painted
## plants' size, and the wind and a place's tint reach them from Flora's own materials.

## Ground plants are drawn by the thousand: none may cost more than this many triangles.
const GROUND_TRIANGLES := 2000
const GROUND: Array[String] = ["grass_a", "grass_b", "grass_dry", "sedge", "reeds", "cattails", "fern_a", "fern_b",
	"fern_small", "bracken", "heather", "bush_a", "bush_b"]


func _triangles(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		n += (m.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


func test_every_stand_in_wears_the_wind_shader() -> void:
	RealTrees.install()
	var config := JSON.parse_string(FileAccess.get_file_as_string(RealTrees.CONFIG)) as Dictionary
	var ids: Array = (config["stand_in"] as Dictionary).keys() + (config["cards"] as Dictionary).keys()
	assert_true(ids.size() > 30, "trees and ground plants are listed")
	for id: String in ids:
		var m := Flora.mesh(id)
		assert_true(m != null, id + " has a mesh")
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i) as ShaderMaterial
			assert_true(mat != null, id + " surface %d wears a shader material" % i)
			assert_true(mat.shader == RealTrees.LEAF_SHADER or mat.shader == RealTrees.BARK_SHADER, id + " wears the game's shader")


func test_ground_plants_are_light_and_the_painted_ones_size() -> void:
	RealTrees.install()
	for id in GROUND:
		var m := Flora.mesh(id)
		assert_true(m != null, id + " has a mesh")
		assert_true(_triangles(m) <= GROUND_TRIANGLES, "%s is %d triangles" % [id, _triangles(m)])
		var painted := (Flora.manifest().get(id, {}) as Dictionary).get("size", [1, 1, 1]) as Array
		var box := m.get_aabb()
		assert_true(box.size.y <= float(painted[1]) * 1.3 and box.size.y >= float(painted[1]) * 0.5,
			"%s is %.2f tall against the painted %.2f" % [id, box.size.y, float(painted[1])])
		assert_true(box.size.x <= float(painted[0]) * 1.5, "%s is %.2f wide against the painted %.2f" % [id, box.size.x, float(painted[0])])
		assert_true(box.position.y >= -0.02, id + " stands on the ground")


func test_a_places_wind_and_tint_reach_the_realistic_plants() -> void:
	RealTrees.install()
	var leaf := Flora._material("leaf|grass")
	leaf.set_shader_parameter("wind_strength", 0.77)
	leaf.set_shader_parameter("tint", Color(0.5, 0.5, 1.0))
	RealTrees.sync()
	var mat := Flora.mesh("grass_a").surface_get_material(0) as ShaderMaterial
	assert_eq(float(mat.get_shader_parameter("wind_strength")), 0.77, "the wind is Flora's")
	var tint := mat.get_shader_parameter("tint") as Color
	assert_true(tint.b > tint.r, "the set's tint over the plant's own")
	leaf.set_shader_parameter("wind_strength", 0.3)
	leaf.set_shader_parameter("tint", Color.WHITE)
	RealTrees.sync()


func test_a_tree_in_the_wind_still_fades_by_transparency() -> void:
	RealTrees.install()
	var mi := MeshInstance3D.new()
	mi.mesh = Flora.mesh("oak_a")
	mi.transparency = 0.72
	assert_between(mi.transparency, 0.719, 0.721, "SeeThrough fades it as before")
	for i in mi.mesh.get_surface_count():
		var src := (mi.mesh.surface_get_material(i) as ShaderMaterial).shader.code
		assert_true("ALPHA" in src, "its shader writes ALPHA, so the instance's transparency reaches it")
	mi.free()
