extends TestCase
## The Crooked Moon's face follows the ritual track (plan G8, docs/tasks/G8-moon-stages.md): data/campaign.json's painted.moon_face
## is a list, the first entry whose condition holds is drawn, and every picture exists. G1 sets the flags (not built yet).

const SMIRK := "res://art/sky/moon_smirk.png"


func _face(st: StoryState) -> String:
	return str(PaintedFinish.moon_face_for(Look.painted_settings(), st)["face"])


func test_every_stage_has_its_picture() -> void:
	var stages := Look.painted_settings()["moon_face"] as Array
	assert_true(stages.size() >= 4, "the smirk, two grins and the scowl")
	for stage: Variant in stages:
		var face := str((stage as Dictionary)["face"])
		assert_true(ResourceLoader.exists(face), "%s exists" % face)
	assert_false((stages.back() as Dictionary).has("when"), "the last is the plain start")


func test_the_moon_widens_its_grin_with_the_track_and_scowls_after_the_ritual() -> void:
	var st := StoryState.new()
	assert_eq(_face(st), SMIRK, "a narrow smirk to begin with")
	st.set_flag("moon_grin", 1)
	assert_eq(_face(st), "res://art/sky/moon_grin2.png", "a wide grin after a first seal")
	st.set_flag("moon_grin", 2)
	assert_eq(_face(st), "res://art/sky/moon_grin3.png", "the widest at the end of the track")
	st.set_flag("moon_scowl", true)
	assert_eq(_face(st), "res://art/sky/moon_scowl.png", "a scowl once it is undone, whatever the grin was")
	assert_eq(_face(null), SMIRK, "without a story the start")
