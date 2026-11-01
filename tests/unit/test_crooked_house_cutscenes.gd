extends TestCase
## The Crooked House's cutscenes (package R12, contract section 8): nine sets, twenty pictures, and a tame alternate for each of
## the four graphic ones. Every set has the number of pictures the contract names (never fewer than two, the two-scenes rule), each
## picture has its file, its stand-in or real art and its prompt, and the noose and the beheading are marked `graphic: true`: with
## the playthrough option graphic_scenes off, the engine shows their `tame` picture instead.

## Each set: its first picture's id and how many pictures it has (the rest are <id>_2, <id>_3).
const SETS := {
	"ch_house_turns": 2, "ch_portraits": 3, "ch_apparition_1": 2, "ch_apparition_2": 2, "ch_apparition_3": 2,
	"ch_gail_freed": 2, "ch_arthur_sleeps": 2, "ch_petunia_ribbon": 2, "ch_house_unbends": 3,
}
## The sets with a hanging or a beheading: marked `graphic`, each picture with a tame alternate (<id>_tame) for graphic scenes off.
const GATED := ["ch_apparition_2", "ch_petunia_ribbon"]
const TAME_SUFFIX := "_tame"
const PROMPTS := "res://tools/content/crooked_house_cutscenes.json"


static func _pictures(first: String, count: int) -> Array[String]:
	var out: Array[String] = [first]
	for n in range(2, count + 1):
		out.append("%s_%d" % [first, n])
	return out


static func _graphic_ids() -> Array[String]:
	var out: Array[String] = []
	for first: String in GATED:
		out.append_array(_pictures(first, int(SETS[first])))
	return out


static func _all_ids() -> Array[String]:
	var out: Array[String] = []
	for first: String in SETS:
		out.append_array(_pictures(first, int(SETS[first])))
	for id in _graphic_ids():
		out.append(id + TAME_SUFFIX)
	return out


func test_every_set_has_two_or_more_pictures() -> void:
	for first: String in SETS:
		assert_true(int(SETS[first]) >= 2, "%s is at least two scenes" % first)
		var found := 0
		for id in _pictures(first, 4):
			if not Cutscenes.get_cutscene(id).is_empty():
				found += 1
		assert_eq(found, int(SETS[first]), "%s has the pictures the contract names, and no stray extra" % first)


func test_there_are_twenty_pictures_four_tame_ones_and_no_other_ch_cutscene() -> void:
	assert_eq(_all_ids().size(), 24, "the contract's twenty pictures and the four tame alternates")
	for c in Cutscenes.all():
		var id := str(c["id"])
		if id.begins_with("ch_"):
			assert_true(id in _all_ids(), "%s is one of the contract's ids" % id)


func test_every_picture_has_its_file_and_a_prompt() -> void:
	var prompts: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(PROMPTS)) as Dictionary)["pictures"]
	assert_eq(prompts.size(), 24, "one prompt per picture")
	for id in _all_ids():
		var c := Cutscenes.get_cutscene(id)
		assert_eq(str(c.get("id", "")), id, "%s's file names its own id" % id)
		assert_true(str(c.get("summary", "")).length() > 20, "%s has a summary" % id)
		var takes := c.get("images", []) as Array
		assert_eq(takes.size(), 1, "%s is one picture" % id)
		assert_eq(str((takes[0] as Dictionary)["image"]), id, "%s shows the picture of its own name" % id)
		assert_true(FileAccess.file_exists("res://art/cutscenes/%s.jpg" % id), "%s has a picture (a stand-in at least)" % id)
		assert_true(FileAccess.file_exists("res://art/cutscenes/%s.jpg.import" % id), "%s's import settings are committed" % id)
		assert_true(prompts.has(id) and str(prompts[id]).length() > 40, "%s has a prompt" % id)


func test_the_noose_and_the_beheading_are_graphic_with_a_tame_alternate() -> void:
	for first: String in SETS:
		for id in _pictures(first, int(SETS[first])):
			var c := Cutscenes.get_cutscene(id)
			assert_eq(str(((c["images"] as Array)[0] as Dictionary)["when"]), "", "%s has no condition of its own" % id)
			if first in GATED:
				assert_true(bool(c.get("graphic", false)), "%s is marked graphic" % id)
				assert_eq(str(c.get("tame", "")), id + TAME_SUFFIX, "%s names its tame alternate" % id)
				assert_true(str(Cutscenes.get_cutscene(id + TAME_SUFFIX).get("summary", "")).length() > 20, "%s exists" % (id + TAME_SUFFIX))
			else:
				assert_false(c.has("graphic"), "%s is not graphic" % id)
	for id in _graphic_ids():
		var tame := Cutscenes.get_cutscene(id + TAME_SUFFIX)
		assert_false(bool(tame.get("graphic", false)), "%s is tame" % (id + TAME_SUFFIX))
		assert_false(tame.has("tame"), "%s has no alternate of its own" % (id + TAME_SUFFIX))


func test_graphic_scenes_off_shows_the_tame_pictures() -> void:
	var st := StoryState.new()
	for first: String in SETS:
		for id in _pictures(first, int(SETS[first])):
			assert_eq(Cutscenes.image(id, st), "res://art/cutscenes/%s.jpg" % id, "%s plays by default (graphic scenes are on unless switched off)" % id)
	st.options["graphic_scenes"] = false
	for first: String in SETS:
		for id in _pictures(first, int(SETS[first])):
			if first in GATED:
				assert_eq(Cutscenes.image(id, st), "res://art/cutscenes/%s%s.jpg" % [id, TAME_SUFFIX], "%s shows its tame picture with graphic scenes off" % id)
			else:
				assert_eq(Cutscenes.image(id, st), "res://art/cutscenes/%s.jpg" % id, "%s still plays" % id)
	st.options["graphic_scenes"] = true
	for id in _graphic_ids():
		assert_eq(Cutscenes.image(id, st), "res://art/cutscenes/%s.jpg" % id, "%s plays with graphic scenes on" % id)
