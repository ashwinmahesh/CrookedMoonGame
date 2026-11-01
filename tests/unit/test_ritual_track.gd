extends TestCase
## The ritual track and the Crooked Moon's gaze (plan 5.5, G1; story/ritual_track.gd, data/ritual/track.json): each of the
## twelve deaths the prophecy wants breaks a seal, the seals broken set the stage, and the stage is the engine's villain's
## attention, so roads, conditions and the moon all read it.


func after_each() -> void:
	RitualTrack.clear_cache()
	Campaign.use(null)


func _st(flags: Array[String]) -> StoryState:
	var st := StoryState.new()
	for f: String in flags:
		st.set_flag(f)
	return st


func test_there_are_twelve_seals_each_with_its_own_flag() -> void:
	var seals := RitualTrack.seals()
	assert_eq(seals.size(), 12, "six Fallen, three hags, the fool and both Druskenvalds")
	var ids := {}
	for s: Dictionary in seals:
		assert_false(ids.has(str(s["id"])), "seal ids are unique: %s" % s["id"])
		ids[str(s["id"])] = true
		assert_true(str(s.get("when", "")).begins_with("flag."), "%s breaks on a flag" % s["id"])


func test_no_seal_broken_is_a_sliver() -> void:
	var st := StoryState.new()
	assert_eq(RitualTrack.count(st), 0)
	assert_eq(str(RitualTrack.stage(st)["id"]), "sliver")
	assert_eq(RitualTrack.crooked_man_chance(st), 0.0, "he keeps away until the grin starts")


func test_each_death_widens_the_grin() -> void:
	var st := _st(["raum_slain", "vessla_slain"])
	assert_eq(RitualTrack.count(st), 2)
	assert_eq(str(RitualTrack.stage(st)["id"]), "grinning")
	var before := RitualTrack.grin(st)
	for f: String in ["renathyr_slain", "grinning_sinner_slain", "lethica_slain"]:
		st.set_flag(f)
	assert_eq(str(RitualTrack.stage(st)["id"]), "wide")
	assert_true(RitualTrack.grin(st) > before, "wider")
	assert_true(RitualTrack.is_broken(st, "crossroads"))
	assert_false(RitualTrack.is_broken(st, "golub"))


func test_every_seal_broken_is_the_full_grin_and_binding_kehlenn_turns_it_to_a_scowl() -> void:
	var flags: Array[String] = []
	for s: Dictionary in RitualTrack.seals():
		flags.append(str(s["when"]).get_slice(" ", 0).trim_prefix("flag."))   # the first of a seal's flags breaks it
	var st := _st(flags)
	assert_eq(RitualTrack.count(st), 12)
	assert_eq(str(RitualTrack.stage(st)["id"]), "full")
	assert_eq(RitualTrack.grin(st), 1.0)
	st.set_flag("kehlenn_bound")
	assert_eq(str(RitualTrack.stage(st)["id"]), "scowl")
	assert_true(RitualTrack.grin(st) < 0.0, "the scowl")
	assert_eq(RitualTrack.field(st, "bound"), "yes")


func test_stages_rise_with_their_mins_and_each_has_a_vision() -> void:
	var last := -1
	for s: Dictionary in RitualTrack.stages():
		assert_true(int(s["min"]) > last, "stages in order")
		last = int(s["min"])
		assert_true(str(s.get("vision", "")) != "", "%s has a vision for Adela" % s["id"])
		assert_true(float(s.get("road_night", 0.0)) >= float(s.get("road_day", 0.0)), "night roads are the worse")


func test_the_module_answers_the_engine_s_attention_with_the_track() -> void:
	Campaign.use(null)
	var m := Campaign.module()
	var st := _st(["raum_slain", "vessla_slain", "renathyr_slain", "grinning_sinner_slain", "lethica_slain"])
	assert_eq(m.presence_attention(st), 5)
	assert_eq(str(m.presence_tier(st)["id"]), "wide")
	assert_eq(m.presence_tier_min("leering"), 8)
	assert_eq(m.presence_tier_min("nonsense"), -1)
	assert_true(float(m.presence_tier(st)["road_night"]) > 0.0, "the night roads are worse")


func test_conditions_read_the_track_by_count_by_stage_and_by_field() -> void:
	Campaign.use(null)
	var st := _st(["raum_slain", "vessla_slain", "renathyr_slain"])
	assert_true(StoryConditions.check("attention >= grinning", st))
	assert_false(StoryConditions.check("attention >= wide", st))
	assert_true(StoryConditions.check("attention >= 3", st))
	assert_true(StoryConditions.check("tarokka.ritual.stage == grinning", st))
	assert_true(StoryConditions.check("tarokka.ritual.seal.raum", st))
	assert_false(StoryConditions.check("tarokka.ritual.seal.chuckles", st))


func test_adela_s_vision_follows_the_stage() -> void:
	Campaign.use(null)
	var st := StoryState.new()
	var sliver := Campaign.module().field(st, "ritual.vision")
	st.set_flag("raum_slain")
	st.set_flag("vessla_slain")
	assert_ne(Campaign.module().field(st, "ritual.vision"), sliver, "a darker vision")


func test_any_stretch_of_druskenvald_s_night_is_night() -> void:
	Campaign.use(null)
	var m := Campaign.module()
	assert_true(m.night_between(600, 600 + 8 * 60), "the night never lifts")
	assert_false(m.night_between(600, 600), "no time, no night")
