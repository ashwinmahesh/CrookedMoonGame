extends TestCase
## Act 1's NPC figures (the look lane): the people who showed the gray-box villager walker now wear a figure, either a finished Tripo model
## or a shared body in a colour and size of its own (docs: the vault's "Act 1 NPC Figures Map"). The ones still waiting for a model of
## their own are listed here, so a new gray-box person turns this test red and a finished one just shortens the list.

const FINISHED: Array[String] = ["doris_squire", "wendel_somerton", "mori_shade", "weston_murdoch", "mrs_oakum", "theodora_mayville", "dani_jenkin", "gilly_jenkin", "crooked_man", "sally_lockwood", "conductor_understudy", "mrs_calloway"]
const REUSED: Array[String] = ["pip_oakum", "amos_dority", "bess_crumley", "brother_elias", "charlotte_murdoch", "gaston_doray", "george_hickock", "howie_butterman", "peter_murdoch", "sgt_gaunt", "rk_mob_b", "rk_posse_a", "rk_mob_c", "rk_posse_b", "rk_mob_a", "algernon_heyling", "arthur_lockwood", "branden_wells", "brother_spore", "cecil_marl", "eddie_wainwright", "granny_orla_pike", "haldor_vane", "hester_bolton", "jay_wells", "lark_wells", "lavender_aster", "lilian_vale", "margery_heyling", "marta_dunn", "myrtle_somerton", "olwen_pike", "ottilie_reed", "petunia_lockwood", "pim_fenwick", "robin_wells", "ronald_wainwright", "rose_somerton", "sheridan_heyling", "sofia_roderick", "rk_mob_round", "tobias_dibbs", "ulf_harga", "victoria_wainwright", "violet_aster", "wilma_wainwright", "wren_wells", "wynn_carter", "zachariah_wainwright"]
const STILL_GRAY: Array[String] = ["geneva_fairchild", "morgan", "sister_rain", "old_rusty", "holly_aster", "jeremiah_stover", "marianna_grey", "tamsin_ledger", "baltus_tolliver", "barnaby_pennywhistle", "finneas_trout", "hilda_brom", "ambrose_quill", "eleanor_heyling", "joan_murdoch", "melina", "randall_graham", "siv_harga", "solomon_roderick", "thomasin_ardor", "alda_farnum", "jean_myriel", "peeping_albert", "walter_jenkin", "beatrice_wells", "oswick_frey", "lottery_stranger", "wisp"]
## The finished models made without a head each wear a head of their own (a Tripo head model, art/figures/heads/<id>_head.glb) fitted to
## their own neck. Sister Rain's head is in too, her body is held (her head is checked with the others, her body is not asserted).
const HEADLESS: Array[String] = ["doris_squire", "wendel_somerton", "mori_shade", "weston_murdoch", "mrs_oakum", "theodora_mayville",
	"dani_jenkin", "gilly_jenkin", "crooked_man", "sally_lockwood"]


func _sprite_of(id: String) -> String:
	return str(Compendium.shared().get_entry("npcs", id).get("sprite", ""))


func test_each_finished_model_is_in_the_manifest_rigged_and_drawn() -> void:
	for id: String in FINISHED:
		assert_eq(_sprite_of(id), id, "%s wears its own figure" % id)
		assert_true(FigureModels.has(id), "%s has its model" % id)
		var packed := FigureModels.scene(id)
		assert_true(packed != null, "%s loads" % id)
		var root := packed.instantiate()
		var skeletons := root.find_children("*", "Skeleton3D", true, false)
		assert_true(skeletons.size() == 1 and (skeletons[0] as Skeleton3D).get_bone_count() >= 60, "%s is rigged on a full skeleton" % id)
		var players := root.find_children("*", "AnimationPlayer", true, false)
		assert_true(players.size() == 1 and (players[0] as AnimationPlayer).get_animation_list().size() >= 8, "%s has its clips" % id)
		root.free()


func test_the_bodies_made_without_a_head_wear_a_head() -> void:
	var clay := FigureModels.part("clay_head")
	assert_true(ResourceLoader.exists(ArtPaths.of(str(clay.get("file", "")))), "the neutral clay head is still there for a body whose head is not made yet")
	for id: String in HEADLESS:
		var layers := FigureModels.info(id).get("layers", []) as Array
		assert_true(layers.has(id + "_head"), "%s wears its own head" % id)
		assert_false(layers.has("clay_head"), "%s has no blank head under it" % id)
		assert_true(float((FigureModels.info(id).get("bones", {}) as Dictionary).get("Head", 1.0)) < 0.05, "and its own stub of a head is shrunk away")


func test_the_head_models_are_fitted_parts_with_their_pictures() -> void:
	var ids: Array[String] = HEADLESS.duplicate()
	ids.append("sister_rain")
	for id: String in ids:
		var part := FigureModels.part(id + "_head")
		assert_true(ResourceLoader.exists(ArtPaths.of(str(part.get("file", "")))), "%s's head model is there" % id)
		assert_eq(str(part.get("bone", "")), "Head", "%s's head is held on the head bone" % id)
		assert_eq(str(part.get("fit", "")), "head", "%s's head is fitted to its body's neck" % id)
		assert_true(float(part.get("size", 0.0)) > 1.0, "%s's head is sized up to hide the body's neck stub" % id)
		var pic := str((part.get("close_up", {}) as Dictionary).get("albedo", ""))
		assert_true(pic != "" and ResourceLoader.exists(ArtPaths.of(pic)), "%s's head has its close-up picture" % id)
	assert_false(FigureModels.has("sister_rain"), "Sister Rain's body is still held: she keeps the walker with her head waiting")
	assert_eq(float(FigureModels.info("sally_lockwood").get("scale", 1.0)), 0.5, "Sally the doll is small")


func test_the_reused_people_wear_a_shared_body_in_their_own_colour_and_size() -> void:
	for id: String in REUSED:
		assert_eq(_sprite_of(id), id, "%s wears its own dressing" % id)
		var info := FigureModels.info(id)
		assert_true(FigureModels.has(id), "%s is drawn as a model" % id)
		assert_true(str(info.get("base", "")) in ["hero_body_male", "hero_body_female", "haint"], "%s is on a built body (%s)" % [id, info.get("base", "")])
		assert_ne(FigureModels.tint_of(id), Color.WHITE, "%s has a colour of its own" % id)
		assert_eq(str(info.get("sprite", "")), "villager", "%s keeps the walker as its stand-in where the model is missing" % id)
	for id: String in ["pip_oakum", "robin_wells", "sofia_roderick", "rose_somerton", "zachariah_wainwright"]:
		assert_eq(float(FigureModels.info(id).get("scale", 1.0)), 0.6, "%s is a child's size" % id)
	assert_eq(float(FigureModels.info("arthur_lockwood").get("scale", 1.0)), 0.35, "the spectral baby is a baby's size")
	assert_eq(float(FigureModels.info("dani_jenkin").get("scale", 1.0)), 0.62, "Dani's own model is a child's size")


func test_only_the_people_still_waiting_for_a_model_show_the_gray_box_walker_in_act_1() -> void:
	var gray := {}
	for f in DirAccess.get_files_at("res://data/locations"):
		var id := f.get_basename()
		if not f.ends_with(".json") or not (id.begins_with("ghostlight_") or id.begins_with("wickermoor_") or id.begins_with("crooked_house_") or id == "druskenvald_estate"):
			continue
		for n: Variant in Compendium.shared().get_entry("locations", id).get("npcs", []) as Array:
			var npc := str((n as Dictionary)["npc"])
			if _sprite_of(npc) == "villager":
				gray[npc] = true
	var extra: Array[String] = []
	for npc: String in gray:
		if not npc in STILL_GRAY:
			extra.append(npc)
	assert_true(extra.is_empty(), "gray-box people not on the waiting list: %s" % ", ".join(extra))
	assert_true(gray.size() <= STILL_GRAY.size(), "the waiting list only shrinks (%d of %d)" % [gray.size(), STILL_GRAY.size()])
