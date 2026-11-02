extends TestCase
## The Quaternius pack people (tools/art/pack_figures.py, art/figures/pack/, the manifest's rigs.quaternius): a male and a female
## body in a peasant outfit with the pack's head and a hairstyle, all on one 65-joint skeleton the pack's own clips move. Each
## loads, wears its head, outfit and hair, has a model clip for every clip name the rig maps to a role, plays the roles the
## game asks for, and takes a head made apart (Tripo's) on its neck through the rig's bone names.

const PEOPLE: Array[String] = ["pack_man_peasant", "pack_woman_peasant"]
const BODIES: Array[String] = ["pack_male", "pack_female"]
const LAYERS := {"pack_man_peasant": ["pack_male_head", "pack_male_peasant", "pack_male_hair_parted"],
	"pack_woman_peasant": ["pack_female_head", "pack_female_peasant", "pack_female_hair_buns"]}


func _figure(id: String) -> ModelFigure:
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(id), 1.8) as ModelFigure
	add_child(fig)
	return fig


## Every clip name the figure's rig's `clips` maps roles to: a name, a list of names, or {"clip": name}.
static func _mapped(art_id: String) -> Array[String]:
	var out: Array[String] = []
	var clips := FigureModels.rig(art_id).get("clips", {}) as Dictionary
	for role: String in clips:
		var v: Variant = clips[role]
		for w: Variant in (v as Array if v is Array else [v]):
			var name := str((w as Dictionary).get("clip", "")) if w is Dictionary else str(w)
			if name != "" and not name in out:
				out.append(name)
	return out


func test_the_rig_and_the_figures_are_in_the_manifest() -> void:
	for id in BODIES + PEOPLE:
		assert_true(FigureModels.has(id), "%s is a model" % id)
		assert_eq(str(FigureModels.info(id).get("rig", "")), "quaternius", "%s is on the pack's rig" % id)
	var bones := FigureModels.rig_bones("pack_man_peasant")
	assert_eq(str(bones.get("Neck")), "neck_01", "the engine's Neck is neck_01")
	assert_eq(str(bones.get("RightHand")), "hand_r", "and RightHand is hand_r")
	assert_eq(str(bones.get("HeadTop_End", "x")), "", "the pack has no head-top bone")
	assert_true((FigureModels.rig("pack_man_peasant").get("head_top") as Array).size() == 3, "so the rig says where the head top is")


func test_each_person_loads_on_the_pack_skeleton_and_wears_head_outfit_and_hair() -> void:
	for id in PEOPLE:
		var packed := FigureModels.scene(id)
		assert_true(packed != null, "%s loads" % id)
		var fig := _figure(id)
		assert_true(fig._skeleton != null and fig._skeleton.get_bone_count() == 65, "%s is on the 65-joint skeleton" % id)
		var worn := fig.worn_parts()
		for part: String in LAYERS[id]:
			assert_true(part in worn, "%s wears %s" % [id, part])
			assert_true(ResourceLoader.exists(ArtPaths.of(str(FigureModels.part(part).get("file", "")))), "%s's model is there" % part)
		# The body's own mesh is hidden under its head and outfit (it still gives the figure its height).
		for mi in fig._own_meshes:
			assert_false(mi.visible, "the body's own %s is hidden under the head" % mi.name)
		assert_between(fig.model.scale.y * fig._rest_height, 1.7, 1.9, "%s is drawn about 1.8 tall" % id)
		fig.free()


func test_the_model_has_every_clip_the_rig_names_and_the_figure_plays_every_role() -> void:
	var fig := _figure("pack_man_peasant")
	var names := fig._player.get_animation_list()
	var mapped := _mapped("pack_man_peasant")
	assert_true(mapped.size() >= 12, "the rig maps its roles to clips (%d)" % mapped.size())
	for clip in mapped:
		assert_ne(ModelFigure.clip_named(names, clip), "", "the model has %s" % clip)
	for role: String in FigureModels.CLIPS:
		assert_true(fig._roles.has(role), "the figure plays a clip for %s" % role)
	assert_eq(str((fig._roles["attack"] as Array)[0]["name"]), ModelFigure.clip_named(names, "Sword_Attack"), "the attack is the sword attack")
	assert_true((fig._roles["talk"] as Array).size() >= 2, "it has several ways to talk")
	assert_eq(fig._player.get_animation(ModelFigure.clip_named(names, "Idle")).loop_mode, Animation.LOOP_LINEAR, "the idle loops (the importer reads _Loop)")
	fig.free()


func test_a_head_made_apart_fits_the_pack_body_on_its_neck_through_the_rigs_bone_names() -> void:
	FigureModels.register_part("test_pack_head", {"file": "art/figures/heads/rook_head.glb", "bone": "Head", "follow": "turn", "fit": "head"},
		FigureModels.part_scene("rook_head"))
	var fig := _figure("pack_male")
	fig.wear(["test_pack_head"])
	var holds := fig._skeleton.find_children("Holds_*", "Node3D", false, false)
	assert_eq(holds.size(), 1, "the head is held on the Head bone")
	var neck := FigureModels.bone(fig._skeleton, "Neck", FigureModels.rig_bones("pack_male"))
	assert_true(neck >= 0 and fig._skeleton.get_bone_name(neck) == "neck_01", "the Neck the engine means is neck_01")
	var piece := (holds[0] as Node3D).get_child(0) as Node3D
	var box := ModelFigure.rest_box(piece)
	var foot := (holds[0] as Node3D).transform * piece.transform * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var at := fig._skeleton.get_bone_global_pose(neck).origin
	var tall := fig._rest_height / fig._skeleton_scale()
	assert_between(foot.distance_to(at), 0.0, 0.06 * tall, "the head's foot is on the neck joint")
	var head_tall := (piece.transform * Vector3(0, box.size.y, 0) - piece.transform * Vector3.ZERO).length()
	assert_between(head_tall, 0.1 * tall, 0.25 * tall, "and it is about a head tall (%.2f of the body)" % (head_tall / tall))
	fig.free()
	FigureModels.unregister_part("test_pack_head")


func test_a_weapon_is_held_in_the_hand_the_rig_names() -> void:
	var fig := _figure("pack_male")
	fig.wear(["dagger"])
	var holds := fig._skeleton.find_children("Holds_*", "Node3D", false, false)
	assert_eq(holds.size(), 1, "the dagger is held")
	var spec := fig._upright[holds[0]] as Array   # [the bone it follows, whether it turns with it]
	assert_eq(fig._skeleton.get_bone_name(int(spec[0])), "hand_r", "in hand_r, the RightHand")
	fig.free()
