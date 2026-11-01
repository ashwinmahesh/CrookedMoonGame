extends TestCase
## The seven regions past Foxwillow have their own sound (vault Build/Audio Plan.md, batch 5): every place in the Crimson
## Monastery, Dawn's Gate, the Drowned Crossroads, Skitterdeep Mine, Memory's Rest, Hartsblight Forest and Maidenmist
## Cemetery plays its region's music (or a room's own: the Briar's tavern, the riverboat's gramophone), sits in a bed of
## sound, and starts its fights on its region's fight music, which counts as a fight mood and rises to the harder track.

const REGIONS := {"crimson_monastery": "crimson_monastery", "dawns_gate": "dawns_gate", "drowned_crossroads": "drowned_crossroads",
	"skitterdeep_mine": "skitterdeep", "memorys_rest": "memorys_rest", "hartsblight_forest": "hartsblight",
	"maidenmist_cemetery": "maidenmist"}


func _places(region: String) -> Array[String]:
	var out: Array[String] = []
	for loc: Dictionary in Compendium.shared().all("locations"):
		if str(loc.get("region", "")) == region:
			out.append(str(loc.get("id", "")))
	return out


func _mood(id: String, st: StoryState) -> String:
	var loc := Compendium.shared().get_entry("locations", id)
	return Audio.mood_for(id, ArenaBoard.theme_for(loc.get("map", {}) as Dictionary), st)


func test_every_place_has_music_a_bed_and_a_fight_mood() -> void:
	for minute: int in [9 * 60, 20 * 60]:
		var st := StoryState.new()
		st.minute_of_day = minute
		for region: String in REGIONS.keys():
			var places := _places(region)
			assert_false(places.is_empty(), "%s has places" % region)
			for id in places:
				var m := _mood(id, st)
				assert_true(Audio.entries("music", m).size() >= 2, "%s plays %s, which rotates" % [id, m])
				var bed := PlaceBeds.bed_for(id, st)
				assert_false(Audio.files("loops", bed).is_empty(), "%s sits in a bed (%s) with a recording" % [id, bed])
				assert_eq(PlaceBeds.fight_music(id), str(REGIONS[region]) + "_combat", "%s's fights start on its region's music" % id)


func test_region_moods_and_rooms() -> void:
	var st := StoryState.new()
	for region: String in REGIONS.keys():
		assert_eq(str((Audio._data["regions"] as Dictionary).get(region, "")), str(REGIONS[region]), "%s has its own mood" % region)
	assert_eq(_mood("dg_briar", st), "tavern", "the Briar keeps its tavern music")
	assert_eq(_mood("dc_casino", st), "train_lounge", "the casino plays the worn gramophone")
	assert_eq(_mood("dc_shack", st), "drowned_crossroads", "a marsh shack is no inn")
	assert_eq(PlaceBeds.bed_for("mon_sanctum", st), "cave_drips", "the blood-soaked sanctum drips")
	assert_eq(PlaceBeds.bed_for("sk_upper", st), "mine", "the mine's picks and timbers")
	assert_eq(PlaceBeds.bed_for("dc_lagoon", st), "bayou", "the lagoon's frogs")


func test_region_fights_are_fight_moods_that_rise() -> void:
	for region: String in REGIONS.keys():
		var m := str(REGIONS[region]) + "_combat"
		assert_true(Audio.is_fight_mood(m), "%s counts as a fight mood" % m)
		assert_eq(Audio.music_for(m, Audio.Intensity.FULL), "combat_hard", "%s rises to the harder track at full intensity" % m)
		assert_eq(Audio.music_for(m, Audio.Intensity.FIGHT), m, "and plays its own otherwise")
	assert_true(Audio.entries("music", "combat_hard").size() >= 2, "the harder track rotates")


func test_the_abbot_has_his_own_and_the_others_the_boss_music() -> void:
	var abbot: Array[Combatant] = [Combatant.new(Monster.from_data(Compendium.shared().get_entry("monsters", "crimson_abbot_boss")), &"enemy", Vector2i.ZERO)]
	assert_eq(Audio.fight_mood(abbot), "crimson_abbot", "the Crimson Abbot's choir and organ")
	for id: String in ["grinning_sinner_boss", "beast_of_blight", "necrolisk", "chained_reaper_harrowing", "weeping_widow", "centipede_hag"]:
		assert_false(Compendium.shared().get_entry("monsters", id).is_empty(), "%s is a monster" % id)
		assert_eq(str((Audio._data["boss_music"] as Dictionary).get(id, "")), "boss", "%s plays the boss music" % id)


## The cutscenes a conversation plays (a `cutscene <id>` line in narrative/<chapter>/*.dialogue), first pictures only.
func _dialogue_cutscenes(chapter: String) -> Array[String]:
	var out: Array[String] = []
	var dir := "res://narrative/" + chapter
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var re := RegEx.create_from_string("(?m)^\\s*cutscene\\s+([a-z0-9_]+)")
	for f in d.get_files():
		if not f.ends_with(".dialogue"):
			continue
		for m in re.search_all(FileAccess.get_file_as_string(dir.path_join(f))):
			var id := m.get_string(1)
			if id != "end" and not RegEx.create_from_string("_\\d+$").search(id) and not out.has(id):
				out.append(id)
	return out


func test_every_chapter_conversation_cutscene_has_a_mood() -> void:
	var scenes := Audio._data.get("scenes", {}) as Dictionary
	var count := 0
	for chapter: String in ["crooked_house", "drowned_crossroads", "hartsblight", "maidenmist", "memorys_rest", "monastery", "skitterdeep", "nightmare", "fools_day", "rookery"]:
		for id in _dialogue_cutscenes(chapter):
			count += 1
			assert_true(scenes.has(id), "%s (%s) has a scene mood" % [id, chapter])
			assert_false(Audio.entries("music", str(scenes.get(id, ""))).is_empty(), "%s's mood has music" % id)
	assert_true(count >= 60, "the chapters' cutscenes are found (%d)" % count)


func test_villains_turn_the_music() -> void:
	for place_mood: String in (Audio._data.get("talk_moods", {}) as Dictionary).keys():
		for npc: Variant in ((Audio._data["talk_moods"] as Dictionary)[place_mood] as Dictionary).get("npcs", []):
			assert_false(Compendium.shared().get_entry("npcs", str(npc)).is_empty(), "talk_moods %s: %s is a person" % [place_mood, npc])
	assert_eq(Audio.talk_mood("crimson_monastery", "father_renathyr"), "dread", "the Abbot's words turn the music")
	assert_eq(Audio.talk_mood("train_lounge", "mister_crossroads"), "dread", "Mister Crossroads in his casino")
	assert_eq(Audio.talk_mood("drowned_crossroads", "maude_ledoux"), "", "a townsperson does not")


func test_the_bayou_has_its_old_steel_guitar() -> void:
	assert_true(Audio.files("music", "drowned_crossroads").has("res://art/sourced/wikimedia_commons/southern_blues_ferera.ogg"), "Southern Blues (1924)")


func test_the_nightmare_the_festival_and_the_rookery() -> void:
	var st := StoryState.new()
	st.minute_of_day = 20 * 60
	assert_eq(_mood("nm_pit", st), "crooked_nightmare", "the nightmare's own music")
	assert_eq(PlaceBeds.fight_music("nm_pit"), "crooked_nightmare_combat", "and fights")
	assert_eq(_mood("fd_festival", st), "fools_day", "the festival plays its carnival even at night in Wickermoor")
	assert_eq(PlaceBeds.bed_for("fd_festival", st), "festival", "and its crowd, not the village's crickets")
	assert_eq(PlaceBeds.fight_music("fd_ring_of_fools"), "fools_day_combat", "the Ring of Fools fights to the carnival")
	assert_eq(PlaceBeds.fight_music("wickermoor_village"), "wickermoor_combat", "while the village keeps its own")
	assert_eq(PlaceBeds.bed_for("rk_dovecote_r2", st), "dovecote", "pigeons in Golub's roost")
	assert_eq(PlaceBeds.bed_for("rk_roost_swamp", st), "bayou", "a roost in a swamp sounds like one")
	var crooked: Array[Combatant] = [Combatant.new(Monster.from_data(Compendium.shared().get_entry("monsters", "crooked_man")), &"enemy", Vector2i.ZERO)]
	assert_eq(Audio.fight_mood(crooked), "crooked_man", "the Crooked Man's own")
	assert_eq(Audio.talk_mood("fools_day", "chuckles"), "dread", "Chuckles turns the carnival")
