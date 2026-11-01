extends TestCase
## The made hero in 3D (vault Build/Character Creator and Layered Figures.md): the creator opens with this game's own
## looks catalog, its Appearance step shows the hero as a 3D figure on a turntable (a clay stand-in body for each
## gender until the species' own bodies are made), and a made hero is drawn in the world as that figure, at their
## species' height, wearing what they hold.


func _app(gender: String) -> Dictionary:
	var app := HeroLook.default_appearance(gender)
	assert_true(bool(app.get("custom", false)), "a made hero's look")
	return app


func test_the_creator_opens_a_made_hero_and_its_appearance_step_shows_a_figure() -> void:
	var screen := CreationScreen.new()
	add_child(screen)
	screen.open_hero([] as Array[String])
	assert_eq(screen.builders.size(), 1, "one hero being made")
	screen.step = CharacterBuilder.Step.APPEARANCE
	screen._draw()
	await get_tree().process_frame
	var panels := screen.find_children("*", "AppearancePanel", true, false)
	assert_eq(panels.size(), 1, "the Appearance step")
	var panel := panels[0] as AppearancePanel
	assert_true(panel._preview.is_figure(), "the hero stands as a 3D figure")
	assert_eq(panel._preview._fig_body, "hero_body_female", "the woman's body by default")
	assert_false("Head" in panel._tabs() or "Outfit" in panel._tabs(), "no tabs for picks only the paper doll draws")
	panel._pick("gender", "male")
	assert_eq(panel._preview._fig_body, "hero_body_male", "the man's body once Man is picked")
	screen.queue_free()


func test_each_gender_has_a_body_and_the_species_sets_the_height() -> void:
	assert_eq(HeroLook.figure_for(_app("female"), "curseborn"), "hero_body_female", "a woman")
	assert_eq(HeroLook.figure_for(_app("male"), "ashborn"), "hero_body_male", "a man, of any species until its own body comes")
	assert_eq(HeroLook.offered_ids(_app("female"), "genders", "curseborn"), ["female", "male"] as Array[String],
		"both genders offered, for the bodies")
	assert_true(HeroLook.height_units(_app("male"), "bogborn") > HeroLook.height_units(_app("male"), "curseborn"),
		"a Bogborn stands taller than a Curseborn")
	assert_true(HeroLook.height_units(_app("male"), "ashborn") < HeroLook.height_units(_app("male"), "curseborn"),
		"an Ashborn smaller")


func test_a_made_hero_is_drawn_as_their_body_and_wears_what_they_hold() -> void:
	var ch := Character.new()
	ch.name = "Test Hero"
	ch.build["species"] = "curseborn"
	var app := _app("male")
	app["portrait"] = "hero_01"
	app["art"] = "hero_01"
	ch.build["appearance"] = app
	ch.add_item("hooded_lantern")
	ch.equip("hooded_lantern", "off_hand")
	var tok := CombatToken.create(Combatant.new(ch, &"party", Vector2i.ZERO))
	add_child(tok)
	assert_true(tok.sprite is ModelFigure, "a 3D figure")
	var fig := tok.sprite as ModelFigure
	assert_eq(fig.art_id, "hero_01", "known by the hero's own art id")
	assert_eq(str(FigureModels.info("hero_01").get("base", "")), "hero_body_male", "wearing the man's body")
	assert_between(ModelFigure.rest_box(fig.model).size.y * fig.model.scale.y, HeroLook.height_units(app, "curseborn") - 0.01,
		HeroLook.height_units(app, "curseborn") + 0.01, "as tall as a Curseborn of their height")
	assert_eq(fig.worn_parts(), ["lantern" + FigureModels.OFF_HAND], "the lantern in their other hand")
	tok.free()
	FigureModels.unregister("hero_01")


func test_the_stand_in_bodies_open_with_their_clips_in_clay() -> void:
	for id: String in ["hero_body_female", "hero_body_male"]:
		assert_true(FigureModels.has(id), "%s: its base model is in the repo" % id)
		assert_true(FigureModels.albedo_of(id) != null, "%s: painted plain clay" % id)
		var fig := DirectionalSprite.create(FigureModels.frames(id), 1.2) as ModelFigure
		add_child(fig)
		for role: String in ["idle", "walk", "run", "attack", "hurt", "die"]:
			assert_true(fig.has_role(role), "%s: %s" % [id, role])
		fig.free()


func test_a_build_draws_the_body_broader_or_slighter_at_the_same_height() -> void:
	var app := _app("female")
	assert_eq(HeroLook.offered_ids(app, "builds", "curseborn"), ["slender", "average", "broad"] as Array[String],
		"every build offered on the 3D body")
	var widths := {}
	for build: String in ["slender", "average", "broad"]:
		app["build"] = build
		FigureModels.register("test_build", HeroLook.figure_entry(app, "curseborn"))
		var fig := DirectionalSprite.create(FigureModels.frames("test_build"), 1.2) as ModelFigure
		add_child(fig)
		widths[build] = fig.model.scale.x / fig.model.scale.y
		assert_between(ModelFigure.rest_box(fig.model).size.y * fig.model.scale.y, 1.19, 1.21, "%s: the same height" % build)
		fig.free()
	FigureModels.unregister("test_build")
	assert_between(float(widths["average"]), 0.999, 1.001, "average as the body was made")
	assert_true(float(widths["slender"]) < 1.0 and float(widths["broad"]) > 1.0, "slender narrower, broad wider: %s" % [widths])
