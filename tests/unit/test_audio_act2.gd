extends TestCase
## The sound after the train (vault Build/Audio Plan.md, "Sourced, batch 2"): every place in Wickermoor, the Crooked House
## and Foxwillow has music and a bed of sound by day and by night, the Crooked House's and Foxwillow's fights carry their
## own fight music while Raum keeps the boss's, doors creak between a street and a room but not between two open places,
## and every keyed monster sound names a real action.

const REGIONS: Array[String] = ["wickermoor", "crooked_house", "foxwillow"]
## The Crooked Moon's sky is always night, so its night music turns on the hour: 09:00 is the Twilight Hour, 20:00 the
## Evening Hour.
const DAY_MINUTE := 9 * 60
const NIGHT_MINUTE := 20 * 60


func _story(minute: int) -> StoryState:
	var st := StoryState.new()
	st.minute_of_day = minute
	return st


func _places() -> Array[String]:
	var out: Array[String] = []
	for loc: Dictionary in Compendium.shared().all("locations"):
		if str(loc.get("region", "")) in REGIONS:
			out.append(str(loc.get("id", "")))
	return out


func _mood(id: String, st: StoryState) -> String:
	var loc := Compendium.shared().get_entry("locations", id)
	return Audio.mood_for(id, ArenaBoard.theme_for(loc.get("map", {}) as Dictionary), st)


func _foe(id: String) -> Combatant:
	return Combatant.new(Monster.from_data(Compendium.shared().get_entry("monsters", id)), &"enemy", Vector2i.ZERO)


func test_every_place_has_music_and_a_bed_by_day_and_night() -> void:
	var places := _places()
	assert_true(places.size() >= 50, "the three regions' places are found")
	for minute: int in [DAY_MINUTE, NIGHT_MINUTE]:
		var st := _story(minute)
		for id in places:
			var m := _mood(id, st)
			assert_false(Audio.entries("music", m).is_empty(), "%s at %d plays %s, which has music" % [id, minute, m])
			var bed := PlaceBeds.bed_for(id, st)
			assert_ne(bed, "", "%s at %d has a bed of sound" % [id, minute])
			assert_false(Audio.files("loops", bed).is_empty(), "%s's bed %s has a recording" % [id, bed])


func test_every_mood_rotates_instead_of_looping_one_track() -> void:
	# A mood with one recording repeats it end to start; with two or more the engine crossfades from one to the next.
	var own := JSON.parse_string(FileAccess.get_file_as_string("res://art/audio.json")) as Dictionary
	for m: String in (own.get("music", {}) as Dictionary).keys():
		assert_true(Audio.entries("music", m).size() >= 2, "%s has at least two recordings" % m)


func test_wickermoor_turns_at_night_but_its_inn_does_not() -> void:
	var day := _story(DAY_MINUTE)
	var night := _story(NIGHT_MINUTE)
	assert_eq(_mood("wickermoor_village", day), "wickermoor", "the village by day")
	assert_eq(_mood("wickermoor_village", night), "wickermoor_night", "the village at night")
	assert_eq(_mood("wickermoor_green_queen_inn", night), "tavern", "the inn keeps its fiddles at night")
	assert_eq(_mood("wickermoor_church", night), "church", "the church keeps its organ")
	assert_eq(PlaceBeds.bed_for("wickermoor_village", day), "village_day", "birds by day")
	assert_eq(PlaceBeds.bed_for("wickermoor_village", night), "village_night", "crickets and a far dog at night")
	assert_eq(PlaceBeds.bed_for("wickermoor_shop_bakery", day), "village_indoor", "a shop hears the day through its walls")
	assert_eq(PlaceBeds.bed_for("wickermoor_shop_bakery", night), "village_indoor_night", "and the night")
	assert_eq(PlaceBeds.bed_for("wickermoor_green_queen_inn", night), "tavern", "the inn's room stays loud")
	assert_eq(PlaceBeds.bed_for("wickermoor_clock_chamber", day), "clock_chamber", "the clock ticks")
	assert_eq(PlaceBeds.bed_for("wickermoor_village"), "village_day", "with no story to ask, the place's own bed")


func test_foxwillow_rooms_do_not_take_the_street_bed() -> void:
	# The Foxwillow street and its region share an id.
	var day := _story(DAY_MINUTE)
	assert_eq(PlaceBeds.bed_for("foxwillow", day), "fields", "the street is out in the fields")
	assert_eq(PlaceBeds.bed_for("fw_hall", day), "fields_indoor", "the town hall hears them through its walls")
	assert_eq(PlaceBeds.bed_for("fw_hall", _story(NIGHT_MINUTE)), "fields_indoor", "the street's night does not reach in")
	assert_eq(PlaceBeds.bed_for("fw_maze_j1", day), "maze", "the maze rustles")
	assert_eq(PlaceBeds.bed_for("fw_windmill", day), "windmill", "the windmill creaks")
	assert_eq(_mood("fw_maze_j2", day), "maze", "the maze has its own music")
	assert_eq(_mood("fw_windmill", day), "mill", "and the mill")


func test_region_fights_carry_their_own_music() -> void:
	var house: Array[Combatant] = [_foe("weasel_hag")]
	assert_eq(Audio.fight_mood(house), "crooked_house_combat", "Vessla's fight")
	var fields: Array[Combatant] = [_foe("pumpkin_head")]
	assert_eq(Audio.fight_mood(fields), "foxwillow_combat", "a scarecrow brawl")
	var raum: Array[Combatant] = []
	for m: Variant in (_encounter("fw_circle", "fw_raum").get("monsters", []) as Array):
		raum.append(_foe(str((m as Dictionary)["monster"])))
	assert_eq(Audio.fight_mood(raum), "boss", "Raum keeps the boss music over his crows")
	var village: Array[Combatant] = [_foe("wolf")]
	assert_eq(Audio.fight_mood(village), "", "Wickermoor's wolves bring no music of their own (plain combat)")
	for m: String in (Audio._data.get("boss_music", {}) as Dictionary).values():
		assert_true(Audio.entries("music", m).size() >= 2, "fight music %s rotates" % m)


func _encounter(loc_id: String, enc_id: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", loc_id).get("encounters", []):
		if str((e as Dictionary).get("id", "")) == enc_id:
			return e as Dictionary
	return {}


func test_doors_creak_between_street_and_room_only() -> void:
	assert_eq(PlaceBeds.exit_sound("wickermoor_village", "wickermoor_green_queen_inn"), "door_creak", "into the inn")
	assert_eq(PlaceBeds.exit_sound("wickermoor_village", "wickermoor_orchard"), "", "street to orchard passes no door")
	assert_eq(PlaceBeds.exit_sound("fw_maze_j1", "fw_maze_j2"), "", "nor one turn of the maze to the next")
	assert_eq(PlaceBeds.exit_sound("crooked_house_first", "crooked_house_second"), "door_creak", "up a floor of the house")
	assert_eq(PlaceBeds.exit_sound("ghostlight_g1_passenger", "ghostlight_g2_sleeper"), "car_door", "the train's doors still slide")


func test_foes_that_open_a_fight_sound_once() -> void:
	var foes: Array[Combatant] = [_foe("wildpyre"), _foe("wildpyre"), _foe("wolf")]
	assert_eq(PlaceBeds.fight_sounds(foes), ["wildpyre_wake"] as Array[String], "the wildpyre roars once as it wakes")
	for mid: String in (Audio._data.get("fight_sfx", {}) as Dictionary).keys():
		assert_false(Compendium.shared().get_entry("monsters", mid).is_empty(), "fight_sfx %s is a monster" % mid)
		assert_false(Audio.files("sfx", str(Audio._data["fight_sfx"][mid])).is_empty(), "%s's sound has a recording" % mid)


func test_keyed_monster_sounds_name_real_actions() -> void:
	# A monster action's sounds are keyed "<monster>.<action>" (MonsterActions.action_key).
	var keys := ((Audio._data.get("combat", {}) as Dictionary).get("keys", {}) as Dictionary)
	var found := 0
	for key: String in keys.keys():
		if not key.contains("."):
			continue
		found += 1
		var block := Compendium.shared().get_entry("monsters", key.get_slice(".", 0))
		assert_false(block.is_empty(), "%s names a monster" % key)
		var ids: Array[String] = []
		for section: String in ["actions", "bonus_actions", "reactions"]:
			for a: Variant in block.get(section, []):
				ids.append(str((a as Dictionary).get("id", "")))
		assert_true(ids.has(key.get_slice(".", 1)), "%s names one of its actions" % key)
		for moment: String in (keys[key] as Dictionary).keys():
			for entry: Variant in (keys[key] as Dictionary)[moment]:
				assert_false(Audio.files("sfx", str(entry).get_slice("@", 0)).is_empty(), "%s %s has a recording" % [key, entry])
	assert_true(found >= 5, "the Ghostlight's, the wildpyre's and the Stoker's actions are keyed")


func test_scene_entries_name_real_cutscenes() -> void:
	for section: String in ["scenes", "scene_sfx"]:
		for id: String in (Audio._data.get(section, {}) as Dictionary).keys():
			assert_true(FileAccess.file_exists("res://data/cutscenes/%s.json" % id), "%s %s is a cutscene" % [section, id])


func test_fights_play_their_regions_music() -> void:
	assert_eq(PlaceBeds.fight_music("crooked_house_first"), "crooked_house_combat", "a fight in the Crooked House plays its own")
	assert_eq(PlaceBeds.fight_music("fw_maze_j1"), "foxwillow_combat", "and in Foxwillow")
	assert_eq(PlaceBeds.fight_music("ghostlight_g1_passenger"), "combat", "a region with none plays the plain fight music")
	assert_false((Audio._data.get("boss_music", {}) as Dictionary).has("weasel"), "a common weasel brings no region's music elsewhere")
