extends TestCase
## Act 1's sound (vault Build/Audio Plan.md): every recording art/audio.json names exists, every Act 1 place has music
## and a bed of sound under it, and every effect a cutscene picture, an object or a place's ambience calls for has a
## recording. A mood or effect with no file would be silent without saying so; this says so.

const ACT1_REGION := "ghostlight_express"
const MOODS: Array[String] = ["title", "combat", "boss"]


func _act1_places() -> Array[String]:
	var out: Array[String] = []
	for loc: Dictionary in Compendium.shared().all("locations"):
		if str(loc.get("region", "")) == ACT1_REGION:
			out.append(str(loc.get("id", "")))
	return out


func test_every_named_recording_exists() -> void:
	for section: String in ["music", "sfx", "loops"]:
		for id: String in (Audio._data.get(section, {}) as Dictionary).keys():
			for path: String in Audio.files(section, id):
				assert_true(ResourceLoader.exists(path), "%s %s: %s exists" % [section, id, path])


func test_the_core_moods_have_music() -> void:
	for m in MOODS:
		assert_false(Audio.entries("music", m).is_empty(), "%s has music" % m)


func test_every_act1_place_has_music_and_a_bed() -> void:
	var places := _act1_places()
	assert_true(places.size() >= 10, "Act 1's places are found")
	for id in places:
		var loc := Compendium.shared().get_entry("locations", id)
		var m := Audio.mood_for(id, ArenaBoard.theme_for(loc.get("map", {}) as Dictionary))
		assert_false(Audio.entries("music", m).is_empty(), "%s plays %s, which has music" % [id, m])
		var bed := PlaceBeds.bed_for(id)
		assert_ne(bed, "", "%s has a bed of sound" % id)
		assert_false(Audio.files("loops", bed).is_empty(), "%s's bed %s has a recording" % [id, bed])


func test_story_and_talk_moods_have_music() -> void:
	for section: String in ["scenes", "place_scenes"]:
		for cut: String in (Audio._data.get(section, {}) as Dictionary).keys():
			var m := str((Audio._data[section] as Dictionary)[cut])
			assert_false(Audio.entries("music", m).is_empty(), "%s %s plays %s, which has music" % [section, cut, m])
	for place_mood: String in (Audio._data.get("talk_moods", {}) as Dictionary).keys():
		var m := str(((Audio._data["talk_moods"] as Dictionary)[place_mood] as Dictionary).get("mood", ""))
		assert_false(Audio.entries("music", m).is_empty(), "talk mood %s has music" % m)


func test_every_called_effect_has_a_recording() -> void:
	var called: Array[String] = []
	for cut: String in (Audio._data.get("scene_sfx", {}) as Dictionary).keys():
		for id: Variant in (Audio._data["scene_sfx"] as Dictionary)[cut]:
			called.append(str(id))
	for key: String in (Audio._data.get("objects", {}) as Dictionary).keys():
		for id: Variant in ((Audio._data["objects"] as Dictionary)[key] as Dictionary).values():
			called.append(str(id))
	for section: String in ["exit_sfx", "dialogue_sfx", "quest_sfx"]:
		for id: Variant in (Audio._data.get(section, {}) as Dictionary).values():
			called.append(str(id))
	for m: String in (Audio._data.get("ambient", {}) as Dictionary).keys():
		for id: Variant in (Audio._data["ambient"] as Dictionary)[m]:
			called.append(str(id))
	for id in called:
		assert_false(Audio.files("sfx", id).is_empty(), "effect %s has a recording" % id)


func test_cutscene_pictures_play_their_effects() -> void:
	var played := PlaceBeds.scene_sounds("gl_arrives")
	assert_true(played.has("train_whistle"), "the train whistles as it pulls in")
	assert_eq(PlaceBeds.scene_sounds("no_such_cutscene"), [] as Array[String], "a picture with no entry plays nothing")


func test_doors_grilles_and_haints_have_their_sounds() -> void:
	assert_eq(PlaceBeds.exit_sound("ghostlight_g1_passenger", "ghostlight_g2_sleeper"), "car_door", "a door slides between two cars")
	assert_eq(PlaceBeds.exit_sound("ghostlight_wreckage", "wickermoor_village"), "", "leaving the act's region is not a car door")
	assert_eq(PlaceBeds.dialogue_sound("ghostlight_express/vagrant_intercom:grille"), "intercom", "the grille crackles")
	assert_eq(PlaceBeds.dialogue_sound("ghostlight_express/vagrant_boarding:start"), "", "a face-to-face talk does not")
	assert_eq(PlaceBeds.quest_sound("haint_mariner", "success"), "haint_rest", "a haint laid to rest chimes")
	assert_eq(PlaceBeds.quest_sound("haint_mariner", "failure"), "", "a failure keeps the toll alone")
