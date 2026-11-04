extends TestCase
## The dark fantasy grade's last cartoon leftovers retired (Ashwin, 2026-11-03): figures lit as solid things never take the
## painted figures' ink outline, the world's light falls off as plain Lambert rather than the painted lift, and the
## flat-coloured pieces are worn rather than smooth plastic.

var _was := ""


func before_each() -> void:
	_was = Look.style()
	Look.set_style("modern", false)
	Look.forget_grade()


func after_each() -> void:
	Look.set_style(_was, false)
	Look.forget_grade()


func test_the_game_grade_sets_real_light_and_worn_colours() -> void:
	var g := Look.grade_settings()
	assert_eq(float(g["light_lift"]), 1.0, "the world's light falls off as plain Lambert")
	assert_true(float(g["colour_wear"]) > 0.0, "flat-coloured pieces are worn")
	assert_true(Look.figures_real(), "figures are lit as solid things")


func test_a_flat_colour_is_worn_and_lit_without_the_painted_lift() -> void:
	var m := Look.cel("walnut")
	assert_eq(float(m.get_shader_parameter("wear")), float(Look.grade_settings()["colour_wear"]), "worn as the grade says")
	assert_eq(float(m.get_shader_parameter("light_lift")), 1.0, "no painted lift")


func test_a_real_figure_has_no_ink_outline() -> void:
	var src := StandardMaterial3D.new()
	src.albedo_color = Color(0.4, 0.3, 0.2)
	var m := ModelFigure.surface_material(src)
	assert_eq(m.shader, ModelFigure.REAL_SHADER, "lit as a solid thing")
	assert_true(m.next_pass == null, "no ink pass after it")


func test_the_twilight_hour_is_lifted_and_the_rest_of_the_night_kept() -> void:
	var lift := Look.grade_settings()["phase_lift"] as Dictionary
	assert_true(lift.has("dawn"), "the Twilight Hour (the calendar's dawn) is lifted")
	assert_true(float((lift["dawn"] as Dictionary).get("exposure", 1.0)) > 1.0, "a little brighter")
	assert_false(lift.has("night"), "the night hours keep their dark")


func test_indoor_places_are_lifted() -> void:
	var lift := Look.grade_settings()["phase_lift"] as Dictionary
	assert_true(lift.has("indoors"), "indoor places are lifted (Ashwin: too dark to see anything)")
	assert_true(float((lift["indoors"] as Dictionary).get("exposure", 1.0)) > 1.0, "brighter")
