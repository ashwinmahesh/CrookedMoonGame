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
