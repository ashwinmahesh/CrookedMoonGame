extends TestCase
## The Crooked House's cutscenes (package R12, contract section 8): nine sets, twenty pictures. Every set has the number of
## pictures the contract names (never fewer than two, the two-scenes rule), each picture has its file, its stand-in or real art
## and its prompt, and the noose and the beheading only show when the graphic-scenes content setting is on.

## Each set: its first picture's id and how many pictures it has (the rest are <id>_2, <id>_3).
const SETS := {
	"ch_house_turns": 2, "ch_portraits": 3, "ch_apparition_1": 2, "ch_apparition_2": 2, "ch_apparition_3": 2,
	"ch_gail_freed": 2, "ch_arthur_sleeps": 2, "ch_petunia_ribbon": 2, "ch_house_unbends": 3,
}
## The sets with a hanging or a beheading: shown only when the player turns graphic scenes on.
const GATED := ["ch_apparition_2", "ch_petunia_ribbon"]
const SETTING := "option:graphic_scenes"
const PROMPTS := "res://tools/content/crooked_house_cutscenes.json"


static func _pictures(first: String, count: int) -> Array[String]:
	var out: Array[String] = [first]
	for n in range(2, count + 1):
		out.append("%s_%d" % [first, n])
	return out


static func _all_ids() -> Array[String]:
	var out: Array[String] = []
	for first: String in SETS:
		out.append_array(_pictures(first, int(SETS[first])))
	return out


func test_every_set_has_two_or_more_pictures() -> void:
	for first: String in SETS:
		assert_true(int(SETS[first]) >= 2, "%s is at least two scenes" % first)
		var found := 0
		for id in _pictures(first, 4):
			if not Cutscenes.get_cutscene(id).is_empty():
				found += 1
		assert_eq(found, int(SETS[first]), "%s has the pictures the contract names, and no stray extra" % first)


func test_there_are_twenty_pictures_and_no_other_ch_cutscene() -> void:
	assert_eq(_all_ids().size(), 20, "the contract's twenty pictures")
	for c in Cutscenes.all():
		var id := str(c["id"])
		if id.begins_with("ch_"):
			assert_true(id in _all_ids(), "%s is one of the contract's ids" % id)


func test_every_picture_has_its_file_and_a_prompt() -> void:
	var prompts: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(PROMPTS)) as Dictionary)["pictures"]
	assert_eq(prompts.size(), 20, "one prompt per picture")
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


func test_the_noose_and_the_beheading_wait_for_the_setting() -> void:
	var st := StoryState.new()
	for first: String in SETS:
		for id in _pictures(first, int(SETS[first])):
			var when := str(((Cutscenes.get_cutscene(id)["images"] as Array)[0] as Dictionary)["when"])
			if first in GATED:
				assert_eq(when, SETTING, "%s is gated on the content setting" % id)
				assert_eq(Cutscenes.image(id, st), "", "%s is skipped with the setting off" % id)
			else:
				assert_eq(when, "", "%s always plays" % id)
				assert_eq(Cutscenes.image(id, st), "res://art/cutscenes/%s.jpg" % id, "%s plays" % id)
	st.options["graphic_scenes"] = true
	for id in _pictures("ch_apparition_2", 2) + _pictures("ch_petunia_ribbon", 2):
		assert_eq(Cutscenes.image(id, st), "res://art/cutscenes/%s.jpg" % id, "%s plays with the setting on" % id)
