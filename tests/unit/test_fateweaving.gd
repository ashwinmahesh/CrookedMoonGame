extends TestCase
## Fateweaving (story/fateweaving.gd, plan 5.4): the six companions' Threads of Fate in data/threads, their beats' quests, and the rewards
## each beat pays its hero when its quest ends (through CrookedMoonCampaign.quest_finished), once a playthrough, wherever the hero is.

const SIX: Array[String] = ["pilgrimage", "rejuvenation", "liberation", "ascendancy", "slaughter", "evolution"]


func after_each() -> void:
	Campaign.use(null)


func _story(ids: Array[String], bench: Array[String] = []) -> StoryState:
	var st := StoryState.new()
	for id in ids:
		st.party.append(TestChars.pregen(id, 5))
	for id in bench:
		st.bench.append(TestChars.pregen(id, 5))
	return st


func _blessed(ch: Character) -> bool:
	return ch.effects.any(func(e: Effect) -> bool: return e.source_id == "bless")


func test_six_threads_each_carried_by_a_roster_companion() -> void:
	var c := Compendium.shared()
	var heroes: Array[String] = []
	for id in SIX:
		var t := Fateweaving.thread(id)
		assert_false(t.is_empty(), "data/threads/%s.json" % id)
		var hero := str(t.get("hero", ""))
		assert_true(bool(c.get_entry("pregens", hero).get("roster", false)), "%s's hero %s is a roster companion" % [id, hero])
		assert_false(hero in heroes, "one Thread each: %s" % hero)
		heroes.append(hero)
		assert_eq(Fateweaving.thread_of(hero), id)
		assert_true(Creature.ABILITY_NAMES.has(StringName(str(t.get("confrontation_ability", "")))), "%s: a real ability" % id)
		assert_false(c.get_entry("feats", str(t.get("climax_feat", ""))).is_empty(), "%s: the Climax's feat exists" % id)
		var beats := t.get("beats", {}) as Dictionary
		for beat in Fateweaving.BEATS:
			assert_true(beats.has(beat), "%s has its %s" % [id, beat])


func test_the_middle_beats_have_quests_that_wait_for_their_chapter() -> void:
	var c := Compendium.shared()
	for id in SIX:
		for beat: String in ["connection", "discovery", "confrontation"]:
			var q := c.get_entry("quests", "%s_%s" % [beat, id])
			assert_false(q.is_empty(), "%s_%s quest" % [beat, id])
			var stages := q.get("stages", []) as Array
			assert_eq(str((stages[stages.size() - 1] as Dictionary).get("ends", "")), "success", "%s_%s ends well" % [beat, id])


func test_a_quest_id_reads_back_as_its_thread_and_beat() -> void:
	assert_eq(Fateweaving.beat_of_quest("discovery_pilgrimage"), {"thread": "pilgrimage", "beat": "discovery"})
	assert_eq(Fateweaving.beat_of_quest("connection_evolution"), {"thread": "evolution", "beat": "connection"})
	assert_true(Fateweaving.beat_of_quest("haint_jailbird").is_empty())
	assert_true(Fateweaving.beat_of_quest("discovery_nobody").is_empty())


func test_the_connection_blesses_its_hero_for_a_day() -> void:
	var st := _story(["rook_coldwake", "cordelia_skein"])
	st.set_quest_stage("connection_pilgrimage", "waiting")
	assert_true(st.set_quest_stage("connection_pilgrimage", "met"))
	assert_true(_blessed(st.party[0]), "Rook is blessed")
	assert_false(_blessed(st.party[1]), "only the Thread's hero")
	assert_true(st.quest_notice().contains("Rook carries a blessing"), st.quest_notice())
	assert_true(Fateweaving.beat_done(st, "pilgrimage", "connection"))


func test_the_discovery_owes_a_twist_of_fate_once() -> void:
	var st := _story(["silas_vane"])
	st.set_quest_stage("discovery_liberation", "waiting")
	st.set_quest_stage("discovery_liberation", "done")
	assert_eq(Fateweaving.twists_owed(st, "silas_vane"), 1)
	assert_eq(Fateweaving.quest_finished(st, "discovery_liberation", "success"), "", "paid once a playthrough")
	assert_eq(Fateweaving.twists_owed(st, "silas_vane"), 1)


func test_the_confrontation_raises_the_threads_ability_past_twenty() -> void:
	var st := _story(["delphine_ravelle"])
	var ch := st.party[0]
	# Her origin increases are clamped at 20 until the story's boon lifts the limit, then they land too: start from a base that already
	# totals exactly 20, so the +2 is the only thing that moves.
	ch.build["base_scores"]["cha"] = 8
	ch.refresh()
	ch.build["base_scores"]["cha"] = 8 + 20 - ch.ability_score(&"cha")
	ch.refresh()
	assert_eq(ch.ability_score(&"cha"), 20, "starts at the old limit")
	var before := ch.ability_score(&"cha")
	var said := Fateweaving.quest_finished(st, "confrontation_ascendancy", "success")
	assert_eq(ch.ability_score(&"cha"), mini(before + 2, Campaign.boon_ability_max()))
	assert_true(said.contains("Charisma rises by"), said)


func test_a_benched_hero_is_still_paid() -> void:
	var st := _story(["rook_coldwake"], ["tobin_hayward"])
	var said := Fateweaving.quest_finished(st, "discovery_rejuvenation", "success")
	assert_eq(Fateweaving.twists_owed(st, "tobin_hayward"), 1, said)


func test_a_hero_not_in_the_company_gets_nothing_but_the_beat_counts() -> void:
	var st := _story(["rook_coldwake"])
	assert_eq(Fateweaving.quest_finished(st, "discovery_evolution", "success"), "")
	assert_eq(Fateweaving.twists_owed(st, "cordelia_skein"), 0)
	assert_true(Fateweaving.beat_done(st, "evolution", "discovery"))


func test_a_failed_beat_quest_pays_nothing() -> void:
	var st := _story(["lucan_houndstooth"])
	assert_eq(Fateweaving.quest_finished(st, "discovery_slaughter", "failure"), "")
	assert_eq(Fateweaving.twists_owed(st, "lucan_houndstooth"), 0)


func test_the_climax_owes_the_threads_feat() -> void:
	var st := _story(["lucan_houndstooth"])
	var said := Fateweaving.quest_finished(st, "climax_slaughter", "success")
	assert_eq(Fateweaving.feats_owed(st, "lucan_houndstooth"), ["sharpshooter"] as Array[String])
	assert_true(said.contains("Sharpshooter"), said)


func test_the_beats_come_in_order() -> void:
	var st := _story(["rook_coldwake"])
	assert_eq(Fateweaving.next_beat(st, "pilgrimage"), "incitement")
	st.set_flag("incitement_pilgrimage", true)
	st.set_flag("connection_pilgrimage", true)
	assert_eq(Fateweaving.next_beat(st, "pilgrimage"), "discovery")
	assert_eq(Fateweaving.beats_done(st, "pilgrimage"), ["incitement", "connection"] as Array[String])


func test_the_campaign_names_the_six_for_approval() -> void:
	var a := Campaign.config().get("approval", {}) as Dictionary
	var ids := a.get("companions", []) as Array
	assert_eq(ids.size(), 6)
	for id in SIX:
		assert_true(str(Fateweaving.thread(id).get("hero", "")) in ids, "%s's hero has approval" % id)
