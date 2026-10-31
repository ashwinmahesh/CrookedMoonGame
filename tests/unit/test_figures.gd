extends TestCase
## The game's 3D figures (art/figures/manifest.json, the Tripo models; the engine's FigureModels and ModelFigure): every
## one opens, stands as tall as its creature is drawn, has the clips the game plays (Tripo's combat set: a run, a hit and
## a fall too), and its attack window lies inside its swing; the companions wear theirs as their own art, and the Vagrant
## and the Druskenvalds wear theirs as people. The monsters' entries (a `sprite` fallback worn until Tripo delivers the model, a
## `base` body a dressing would lie over, a `ghost` look) are listed before their models exist: the checks on them hold with
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
		assert_between(ModelFigure.rest_box(fig.model).size.y * fig.model.scale.y, height - 0.01, height + 0.01, "%s: as tall as it is drawn" % id)
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
	assert_true(_monster_ids().size() >= 11, "the six haints and the wayward haint, the trainhopper, stoker, passenger and crawler")
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
		assert_true(fig.has_role("walk"), "%s: walks" % id)
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
