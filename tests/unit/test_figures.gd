extends TestCase
## The game's 3D figures (art/figures/manifest.json, the Tripo models; the engine's FigureModels and ModelFigure): every
## one opens, stands as tall as its creature is drawn, has the clips the game plays (Tripo's combat set: a run, a hit and
## a fall too), and its attack window lies inside its swing; the companions wear theirs as their own art, and the Vagrant
## and the Druskenvalds wear theirs as people.

const QUADRUPEDS: Array[String] = ["barnaby"]


func _ids() -> Array:
	return (ArtPaths.json(FigureModels.MANIFEST_JSON).get("figures", {}) as Dictionary).keys()


func test_every_figure_opens_with_its_clips() -> void:
	assert_true(_ids().size() >= 9, "the Act 1 figures")
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
	for id: String in ["rook_coldwake", "silas_vane", "cordelia_skein", "delphine_ravelle", "lucan_houndstooth"]:
		assert_eq(CombatToken.art_for(Pregens.build(id, 1)), id, "%s wears their own figure" % id)
	for id: String in ["the_vagrant", "phillip_druskenvald", "adela_druskenvald"]:
		var npc := Compendium.shared().get_entry("npcs", id)
		assert_eq(str(npc.get("sprite", "")), id, "%s is drawn as their figure" % id)
		assert_true(FigureModels.has(id), "%s has one" % id)
