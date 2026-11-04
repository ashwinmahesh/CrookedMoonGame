extends TestCase
## The haints have hair (Ashwin, 2026-11-03: every haint was bald): each kind wears a hairstyle from the pack the townsfolk wear,
## its own (a songstress's bob, a sweetheart's long hair, the mariner's white fringe and beard; a fringe under the jailbird's and the harlequin's caps), held on the head bone so it
## follows every clip, drawn in the haint's own ghost look, and sitting on the head: over the crown, not floating or sunk.

const HAINTS: Array[String] = ["haint", "haint_songstress", "haint_sweetheart", "haint_mariner", "haint_jailbird", "haint_harlequin",
	"haint_daydreamer"]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _box(nodes: Array) -> AABB:
	var box := AABB()
	var first := true
	for n: Variant in nodes:
		var mi := n as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func test_every_haint_wears_its_own_hair_on_its_head() -> void:
	var styles := {}
	for id in HAINTS:
		var f := DirectionalSprite.create(FigureModels.frames(id), 1.2) as ModelFigure
		add_child(f)
		await _frames(3)
		var hair: Array[String] = []
		for part in f.worn_parts():
			if part.begins_with("haint_hair") or part.begins_with("haint_beard"):
				hair.append(part)
		assert_false(hair.is_empty(), "%s wears hair" % id)
		styles[",".join(hair)] = true
		var body := _box(f._own_meshes)
		for part in hair:
			var meshes := (f._layers[part] as Dictionary)["meshes"] as Array
			assert_false(meshes.is_empty(), "%s's %s has meshes" % [id, part])
			if meshes.is_empty():
				continue
			var box := _box(meshes)
			# On the head: inside the figure's top fifth, not above it or down at the shoulders.
			assert_true(box.get_center().y > body.position.y + body.size.y * 0.72 and box.end.y < body.end.y + body.size.y * 0.1,
				"%s's %s sits on the head (%.2f to %.2f, the figure %.2f tall)" % [id, part, box.position.y, box.end.y, body.end.y])
			for m: Variant in meshes:
				var mi := m as MeshInstance3D
				var ghost: Variant = mi.get_instance_shader_parameter("ghost")
				assert_true(ghost != null and float(ghost) > 0.0, "%s's %s is drawn in the haint's ghost look" % [id, part])
		f.queue_free()
		await _frames(1)
	assert_true(styles.size() >= 5, "the haints don't all wear the same hair (%d styles)" % styles.size())
