extends TestCase
## Every music mood the game can ask for has music (vault Build/Audio Plan.md, batch 4). The list is derived, not written
## down: the moods named in code (Audio.play_music("..."), an ending's `get("music", "...")`, the scene that means "back
## to camp"), every mood art/audio.json can hand out (places, regions and their turns, map themes, scenes, talk, foes'
## and regions' fights), each ending's own, and the mood every place resolves to by day and by night. A new mood with no
## music fails here instead of playing silence.

const CODE_DIRS: Array[String] = ["res://world", "res://ui", "res://story", "res://addons/dnd_core/world", "res://addons/dnd_core/ui",
	"res://addons/dnd_core/story", "res://addons/dnd_core/core"]
const PATTERNS: Array[String] = ["play_music\\(\"([a-z_]+)\"\\)", "get\\(\"music\", \"([a-z_]+)\"\\)"]
## The scene that means "back to camp" (GameRoot._scene_music), named only there.
const SCENE_PATTERN := "if m == \"([a-z_]+)\":"


func _scripts(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub != "tests" and not sub.begins_with("."):
			_scripts(dir.path_join(sub), out)


## Moods named as literals in code.
func _code_moods() -> Dictionary:
	var found := {}
	var files: Array[String] = []
	for dir in CODE_DIRS:
		_scripts(dir, files)
	for pat in PATTERNS:
		var re := RegEx.create_from_string(pat)
		for f in files:
			for m in re.search_all(FileAccess.get_file_as_string(f)):
				found[m.get_string(1)] = f.get_file()
	var scene := RegEx.create_from_string(SCENE_PATTERN)
	for m in scene.search_all(FileAccess.get_file_as_string("res://world/game_root.gd")):
		found[m.get_string(1)] = "game_root.gd"
	for m: String in Audio.FIGHT_MOODS:
		found[m] = "Audio.FIGHT_MOODS (a fight's own, and PlaceBeds.fight_music's fallback)"
	found.erase("")
	return found


## Moods art/audio.json can hand out, each with where it came from.
func _data_moods() -> Dictionary:
	var d := Audio._data
	var found := {}
	for section: String in ["places", "regions", "themes", "scenes", "place_scenes", "region_fights", "boss_music"]:
		for k: String in (d.get(section, {}) as Dictionary).keys():
			found[str((d[section] as Dictionary)[k])] = "%s %s" % [section, k]
	for section: String in ["region_turns", "place_turns"]:
		for k: String in (d.get(section, {}) as Dictionary).keys():
			for t: Variant in (d[section] as Dictionary)[k]:
				found[str((t as Dictionary).get("mood", ""))] = "%s %s" % [section, k]
	for k: String in (d.get("talk_moods", {}) as Dictionary).keys():
		found[str(((d["talk_moods"] as Dictionary)[k] as Dictionary).get("mood", ""))] = "talk_moods %s" % k
	found["wilds"] = "the themes fallback"   # Audio.mood_for's last resort
	var endings := DirAccess.open(Endings.ROOT)   # data/endings/<id>.json: an ending may name its own music
	if endings != null:
		for f in endings.get_files():
			if f.ends_with(".json"):
				var e := JSON.parse_string(FileAccess.get_file_as_string(Endings.ROOT + f)) as Dictionary
				found[str(e.get("music", "ending"))] = "ending %s" % f
	found.erase("")
	return found


func test_the_derived_list_finds_the_known_moods() -> void:
	var code := _code_moods()
	for m: String in ["title", "combat", "boss", "ending", "camp"]:
		assert_true(code.has(m), "the code asks for %s" % m)
	assert_true(_data_moods().size() >= 20, "the data hands out its moods")


func test_every_mood_code_can_ask_for_has_music() -> void:
	var code := _code_moods()
	for m: String in code.keys():
		assert_false(Audio.entries("music", m).is_empty(), "%s (named in %s) has music" % [m, code[m]])


func test_every_mood_the_data_hands_out_has_music() -> void:
	var data := _data_moods()
	for m: String in data.keys():
		assert_false(Audio.entries("music", m).is_empty(), "%s (%s) has music" % [m, data[m]])


func test_every_place_plays_music_by_day_and_night() -> void:
	for minute: int in [9 * 60, 20 * 60]:
		var st := StoryState.new()
		st.minute_of_day = minute
		for loc: Dictionary in Compendium.shared().all("locations"):
			var id := str(loc.get("id", ""))
			var m := Audio.mood_for(id, ArenaBoard.theme_for(loc.get("map", {}) as Dictionary), st)
			assert_false(Audio.entries("music", m).is_empty(), "%s at %d plays %s, which has music" % [id, minute, m])


func test_a_camp_and_its_fire_have_sound() -> void:
	assert_false(Audio.entries("music", "camp").is_empty(), "a camp's quiet music")
	for bed: String in ["camp", "hearth", "river"]:
		assert_false(Audio.files("loops", bed).is_empty(), "the %s bed has a recording (WorldSounds and PlaceBeds ask for it)" % bed)
