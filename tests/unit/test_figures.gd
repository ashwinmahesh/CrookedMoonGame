extends TestCase
## The game's 3D figures (art/figures/manifest.json, the Tripo models; the engine's FigureModels and ModelFigure): every
## one opens, stands as tall as its creature is drawn, has the clips the game plays (Tripo's combat set: a run, a hit and
## a fall too), and its attack window lies inside its swing; the companions wear theirs as their own art, and the Vagrant
## and the Druskenvalds wear theirs as people. The monsters' entries (a `sprite` fallback worn until Tripo delivers the model, a
## `base` body for the haint dressings, a `ghost` look) are listed before their models exist: the checks on them hold with
## or without the file, and the model checks run on the ones whose file is in the repo.

const QUADRUPEDS: Array[String] = ["barnaby"]


func _entries() -> Dictionary:
	return ArtPaths.json(FigureModels.MANIFEST_JSON).get("figures", {}) as Dictionary


## The leads: entries with no sprite fallback and no base body.
func _ids() -> Array:
	var out: Array = []
	for id: String in _entries():
		var entry := _entries()[id] as Dictionary
		if not entry.has("sprite") and not entry.has("base"):
			out.append(id)
	return out


## The monsters: entries that carry a sprite fallback or lie over a base body, other than the bodies made heroes wear
## (the manifest's "bodies"; test_hero_creator checks those).
func _monster_ids() -> Array:
	var bodies: Array = []
	for by: Variant in (ArtPaths.json(FigureModels.MANIFEST_JSON).get("bodies", {}) as Dictionary).values():
		bodies.append_array((by as Dictionary).values())
	var out: Array = []
	for id: String in _entries():
		if not id in _ids() and not id in bodies:
			out.append(id)
	return out


func test_every_figure_opens_with_its_clips() -> void:
	assert_true(_ids().size() >= 10, "the Act 1 figures")
	for id: String in _ids():
		assert_true(FigureModels.has(id), "%s: its model is in the repo" % id)
		var height := CombatToken.height_for(id)
		var fig := DirectionalSprite.create(DirectionalSprite.frames_for(id), height) as ModelFigure
		assert_true(fig != null, "%s: drawn as a 3D figure" % id)
		add_child(fig)
		# As it was sized: its own body, with a head made apart from it at rest (once a frame has run the head follows
		# the idle pose, started at a random point), and not a ghost over a shoulder, which stands above it.
		assert_between(fig._rest_height * fig.model.scale.y, height - 0.01, height + 0.01, "%s: as tall as it is drawn" % id)
		assert_true(fig.has_role("walk"), "%s: walks" % id)
		if not id in QUADRUPEDS:
			for role: String in ["idle", "attack", "talk", "greet", "run", "hurt", "die"]:
				assert_true(fig.has_role(role), "%s: has a clip to %s" % [id, role])
			var swing := (fig._roles["attack"] as Array)[0] as Dictionary
			var length := fig._player.get_animation(str(swing["name"])).length
			assert_true(float(swing["from"]) < float(swing["hit"]) and float(swing["hit"]) < float(swing["to"]) and float(swing["to"]) <= length,
				"%s: the blow lands inside the attack's window" % id)
		fig.free()


func test_the_companions_and_people_wear_their_figures() -> void:
	for id: String in ["rook_coldwake", "silas_vane", "cordelia_skein", "delphine_ravelle", "lucan_houndstooth", "tobin_hayward"]:
		assert_eq(CombatToken.art_for(Pregens.build(id, 1)), id, "%s wears their own figure" % id)
	for id: String in ["the_vagrant", "phillip_druskenvald", "adela_druskenvald"]:
		var npc := Compendium.shared().get_entry("npcs", id)
		assert_eq(str(npc.get("sprite", "")), id, "%s is drawn as their figure" % id)
		assert_true(FigureModels.has(id), "%s has one" % id)


func test_every_monster_entry_has_a_sprite_to_wear_until_its_model_comes() -> void:
	assert_true(_monster_ids().size() >= 12, "the six haints and the wayward haint, the trainhopper, stoker, passenger, crawler and the locomotive")
	for id: String in _monster_ids():
		var entry := _entries()[id] as Dictionary
		var sprite := str(entry.get("sprite", ""))
		assert_ne(sprite, "", "%s: names the sprite it wears while its model is missing" % id)
		assert_true(ArtPaths.exists("art/sprites/%s/walk.tres" % sprite), "%s: its fallback sprite %s has a walk sheet" % [id, sprite])
		assert_true(entry.has("file") or entry.has("base"), "%s: has a model file or lies over a base body" % id)
		if entry.has("source"):
			assert_true(entry.has("file"), "%s: a model to import says where it goes" % id)
		if entry.has("albedo"):
			assert_true(entry.has("base"), "%s: only a dressing is painted over a body" % id)


func test_a_dressing_lies_over_a_figure_with_its_own_model() -> void:
	for id: String in _monster_ids():
		var entry := _entries()[id] as Dictionary
		if not entry.has("base"):
			continue
		var base := str(entry["base"])
		assert_true(_entries().has(base), "%s: its base %s is an entry" % [id, base])
		assert_false((_entries()[base] as Dictionary).has("base"), "%s: its base %s is a body, not another dressing" % [id, base])
		assert_true((_entries()[base] as Dictionary).has("file"), "%s: its base %s has a model file" % [id, base])
		assert_false(entry.has("file"), "%s: a dressing has no model of its own" % id)
		assert_true(str(entry.get("albedo", "")).begins_with("art/figures/"), "%s: its paint is in art/figures" % id)


func test_ghost_looks_use_palette_colours_and_sane_amounts() -> void:
	var palette := ArtPaths.json("art/palette/palette.json")
	assert_true(palette.size() > 10, "the palette is read")
	for id: String in _monster_ids():
		var ghost := (_entries()[id] as Dictionary).get("ghost", {}) as Dictionary
		if ghost.is_empty():
			continue
		if ghost.has("colour"):
			assert_true(palette.has(str(ghost["colour"])), "%s: ghost colour %s is a palette colour" % [id, ghost["colour"]])
		for key: String in ["wash", "glow", "see_through", "rim", "pulse"]:
			if ghost.has(key):
				assert_between(float(ghost[key]), 0.0, 1.0, "%s: ghost %s is a share" % [id, key])


func test_monsters_stand_at_their_height_and_wear_models_that_are_there() -> void:
	for id: String in _monster_ids():
		assert_true(CombatToken.HEIGHTS.has(id), "%s: has a height in art/creature_looks.json" % id)
		if not FigureModels.has(id):
			continue
		var height := CombatToken.height_for(id)
		var fig := DirectionalSprite.create(DirectionalSprite.frames_for(id), height) as ModelFigure
		assert_true(fig != null, "%s: drawn as a 3D figure" % id)
		add_child(fig)
		if not bool((_entries()[id] as Dictionary).get("static", false)):
			assert_true(fig.has_role("walk"), "%s: walks" % id)   # (a `static` one, the locomotive, has no rig: it glides)
		fig.free()


## Every art id a ghostlight person or foe names has a manifest entry: the people wear the sprite their file names, the
## Phantom and the Corrupted Passengers wear the art their foe entries name.
func test_the_trainhopper_and_the_haints_are_drawn_as_their_own_figures() -> void:
	for npc_id: String in ["haint_sweetheart", "haint_songstress", "haint_daydreamer", "haint_mariner", "haint_jailbird",
			"haint_harlequin", "phantom_trainhopper"]:
		var npc := Compendium.shared().get_entry("npcs", npc_id)
		assert_eq(str(npc.get("sprite", "")), npc_id, "%s is drawn as their own figure" % npc_id)
		assert_true(_entries().has(npc_id), "%s has a manifest entry" % npc_id)
	var arts: Dictionary = {}
	for loc: Dictionary in Compendium.shared().all("locations"):
		if str(loc["id"]).begins_with("ghostlight_"):
			_collect_foe_arts(loc, arts)
	assert_true(arts.has("corrupted_passenger") and arts.has("phantom_trainhopper"), "the Phantom and the passengers name their art")
	for art: String in arts:
		assert_true(_entries().has(art), "%s: a foe's art has a manifest entry" % art)
	assert_true("Corrupted Passenger" in (arts.get("corrupted_passenger", []) as Array), "the passengers wear their own art")
	for foe_name: String in ["The Phantom Trainhopper", "The Phantom, re-formed"]:
		assert_true(foe_name in (arts.get("phantom_trainhopper", []) as Array), "%s wears the Phantom's art" % foe_name)


## Foe entries (a dictionary with a "monster" and an "art") anywhere in `node`: art id -> the names of the foes that wear it.
func _collect_foe_arts(node: Variant, out: Dictionary) -> void:
	if node is Dictionary:
		var d := node as Dictionary
		if d.has("monster") and d.has("art"):
			var names := out.get(str(d["art"]), []) as Array
			names.append(str(d.get("name", "")))
			out[str(d["art"])] = names
		for k: Variant in d:
			_collect_foe_arts(d[k], out)
	elif node is Array:
		for v: Variant in node:
			_collect_foe_arts(v, out)


## Tripo's greet raises the right hand: a figure holding something there (a sword, a cane, a lantern, a syringe) would
## seem to aim it, so it greets with the nod instead; the empty-handed wave.
func test_figures_holding_something_greet_with_a_nod() -> void:
	for id: String in ["rook_coldwake", "silas_vane", "cordelia_skein", "tobin_hayward", "lucan_houndstooth", "the_vagrant",
			"phillip_druskenvald"]:
		var fig := DirectionalSprite.create(DirectionalSprite.frames_for(id), 1.2) as ModelFigure
		add_child(fig)
		assert_eq(str((fig._roles["greet"] as Array)[0]["name"]), "agree", "%s nods" % id)
		fig.free()
	for id: String in ["delphine_ravelle", "adela_druskenvald"]:
		var fig := DirectionalSprite.create(DirectionalSprite.frames_for(id), 1.2) as ModelFigure
		add_child(fig)
		assert_eq(str((fig._roles["greet"] as Array)[0]["name"]), "greet_01", "%s waves" % id)
		fig.free()


# --- The free CC0 models (Quaternius and KayKit; tools/art/free_figures.py): the pilot of held weapons, a gray-box villager in
# two outfits and a warhorse, beside the Tripo figures -----------------------------------------------------------------------

const FREE_PACKS: Array[String] = ["quaternius_universal_base_characters", "quaternius_universal_animation_library",
		"quaternius_universal_animation_library_2", "quaternius_fantasy_props_megakit", "quaternius_modular_weapons_pack",
		"quaternius_medieval_village_megakit", "quaternius_ultimate_animated_animal_pack", "kaykit_medieval_builder_pack",
		"kaykit_dungeon_pack", "kaykit_adventurers", "kaykit_skeletons"]
## The weapons held, by the item that shows them: the engine's item ids, and the part each is drawn as (no mace, scimitar or
## sickle: none of the free packs has one).
const FREE_WEAPONS := {"dagger": "dagger", "spear": "spear", "quarterstaff": "staff", "greataxe": "greataxe", "shortbow": "bow",
		"longbow": "bow"}
const TRIANGLE_LIMIT := 50000


func _triangles(node: Node) -> int:
	var total := 0
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var index := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			total += floori((index.size() if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3.0)
	return total


func test_every_free_pack_keeps_its_licence_and_source_and_is_credited() -> void:
	var credits := FileAccess.get_file_as_string("res://art/credits.json")
	for pack: String in FREE_PACKS:
		assert_true(FileAccess.file_exists("res://art/sourced/%s/License.txt" % pack), "%s: keeps its licence" % pack)
		assert_true(FileAccess.file_exists("res://art/sourced/%s/SOURCE.md" % pack), "%s: says where it came from" % pack)
	for credit: String in ["Universal Base Characters", "Universal Animation Library 1 and 2", "Modular Weapons Pack",
			"Ultimate Animated Animal Pack", "Quaternius", "Kay Lousberg"]:
		assert_true(credit in credits, "art/credits.json credits %s" % credit)


func test_the_free_weapons_are_held_on_the_right_hand_and_shown_for_their_items() -> void:
	for item: String in FREE_WEAPONS:
		var part := str(FREE_WEAPONS[item])
		assert_true(FigureModels.has_part(part), "%s: its model is in the repo" % part)
		assert_eq(str(FigureModels.part(part).get("bone", "")), "RightHand", "%s: held on the right hand" % part)
		var packed := FigureModels.part_scene(part)
		var model := packed.instantiate()
		var tris := _triangles(model)
		assert_between(float(tris), 1.0, float(TRIANGLE_LIMIT), "%s: %d triangles" % [part, tris])
		model.free()
		var ch := Pregens.build("rook_coldwake", 1)
		ch.add_item(item)
		ch.equip(item, "main_hand")
		for art: String in ["villager_gray", "rook_coldwake", "the_vagrant"]:
			assert_true(part in FigureModels.gear_for(art, ch), "%s wears the %s for a %s" % [art, part, item])


func test_the_villager_rig_has_the_bones_the_parts_and_heads_look_for() -> void:
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for("villager_gray"), CombatToken.height_for("villager_gray")) as ModelFigure
	add_child(fig)
	var skeletons := fig.model.find_children("*", "Skeleton3D", true, false)
	assert_eq(skeletons.size(), 1, "one skeleton")
	var skeleton := skeletons[0] as Skeleton3D
	for bone: String in ["RightHand", "LeftHand", "Head"]:
		assert_true(FigureModels.bone(skeleton, bone) >= 0, "the rig has a %s bone" % bone)
	fig.wear(["dagger", "dagger@off"])
	assert_eq(fig.worn_parts().size(), 2, "a dagger in each hand is worn")
	fig.free()


func test_the_villager_outfits_lie_over_one_gray_body() -> void:
	for id: String in ["villager_brown", "villager_red"]:
		var entry := _entries()[id] as Dictionary
		assert_eq(str(entry.get("base", "")), "villager_gray", "%s wears the gray body" % id)
		assert_true(ArtPaths.exists(str(entry.get("albedo", ""))), "%s: its paint is in the repo" % id)
		assert_true(FigureModels.has(id), "%s: has its model through the base" % id)


func test_the_free_models_stay_within_fifty_thousand_triangles() -> void:
	for id: String in ["villager_gray", "warhorse"]:
		var model := (load(ArtPaths.of(str((_entries()[id] as Dictionary)["file"]))) as PackedScene).instantiate()
		var tris := _triangles(model)
		assert_between(float(tris), 1.0, float(TRIANGLE_LIMIT), "%s: %d triangles" % [id, tris])
		model.free()
