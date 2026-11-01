extends TestCase
## The Crooked Moon's visits (plan 5.5, G1; story/crooked_moon_visits.gd, data/ritual/visits.json): the Crooked Man on the
## roads, at the village's edge and in dreams, more often as the ritual track's grin widens; once-only visits come once,
## the others keep their cooldowns, and nothing comes before the grin starts.


class FixedDice extends DiceRoller:
	var value := 1

	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for _i in count:
			out.append(mini(value, sides))
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


func after_each() -> void:
	CrookedMoonVisits.clear_cache()
	RitualTrack.clear_cache()
	Campaign.use(null)


func _dice(v: int) -> FixedDice:
	var d := FixedDice.new()
	d.value = v
	return d


func _grinning() -> StoryState:
	var st := StoryState.new()
	st.set_flag("raum_slain")
	st.set_flag("vessla_slain")
	return st


func test_every_visit_has_its_narrator_line() -> void:
	var n := Narrator.new()
	for v: Dictionary in CrookedMoonVisits.visits():
		assert_true(str(v.get("on", "")) in CrookedMoonVisits.ON, "%s is on road, arrive or rest" % v["id"])
		assert_true(bool(v.get("once", false)) or v.has("cooldown_hours"), "%s is limited" % v["id"])
		if str(v.get("dialogue", "")) == "":
			assert_true(n.has_trigger(CrookedMoonVisits.narrator_key(v)), "%s has lines" % v["id"])


func test_nobody_comes_before_the_first_seals() -> void:
	var st := StoryState.new()
	for on: String in CrookedMoonVisits.ON:
		assert_true(CrookedMoonVisits.due(st, on, _dice(1)).is_empty(), "the moon is only a sliver: %s" % on)


func test_the_crooked_man_dreams_come_once_each_then_the_repeating_one() -> void:
	var st := _grinning()
	var first := CrookedMoonVisits.due(st, "rest", _dice(1))
	assert_eq(str(first.get("id", "")), "cm_dream_counting", "the first dream")
	st.advance_minutes(24 * 60)
	var second := CrookedMoonVisits.due(st, "rest", _dice(1))
	assert_eq(str(second.get("id", "")), "cm_dream_again", "the tree's dream waits for a wider grin; the repeating dream comes")
	st.advance_minutes(24 * 60)
	assert_ne(str(CrookedMoonVisits.due(st, "rest", _dice(1)).get("id", "")), "cm_dream_again", "its cooldown holds it back")


func test_the_gap_keeps_two_visits_apart() -> void:
	var st := _grinning()
	assert_false(CrookedMoonVisits.due(st, "rest", _dice(1)).is_empty())
	assert_true(CrookedMoonVisits.due(st, "road", _dice(1)).is_empty(), "too soon after the last")
	st.advance_minutes(11 * 60)
	assert_eq(str(CrookedMoonVisits.due(st, "road", _dice(1)).get("id", "")), "cm_road_milestone")


func test_a_high_roll_means_no_visit_and_nothing_is_used_up() -> void:
	var st := _grinning()
	assert_true(CrookedMoonVisits.due(st, "rest", _dice(100)).is_empty(), "the grin's chance is small")
	assert_eq(CrookedMoonVisits.times_seen(st, "cm_dream_counting").size(), 0)
	assert_eq(str(CrookedMoonVisits.due(st, "rest", _dice(1)).get("id", "")), "cm_dream_counting", "it can still come")


func test_he_comes_more_often_as_the_grin_widens() -> void:
	var st := _grinning()
	var v := CrookedMoonVisits.get_visit("cm_road_glimpse")
	var low := CrookedMoonVisits.chance(st, v)
	for f: String in ["renathyr_slain", "grinning_sinner_slain", "lethica_slain", "stonoga_slain", "gorthos_slain", "golub_dead"]:
		st.set_flag(f)
	assert_true(CrookedMoonVisits.chance(st, v) > low)


func test_a_road_visit_waits_to_be_told_on_arrival() -> void:
	var st := _grinning()
	var v := CrookedMoonVisits.due(st, "road", _dice(1))
	assert_eq(str(v.get("id", "")), "cm_road_milestone")
	CrookedMoonVisits.hold_for_arrival(st, str(v["id"]))
	assert_eq(str(CrookedMoonVisits.take_pending(st).get("id", "")), "cm_road_milestone")
	assert_true(CrookedMoonVisits.take_pending(st).is_empty(), "told once")


func test_the_village_edge_needs_the_village() -> void:
	var st := _grinning()
	assert_true(CrookedMoonVisits.due(st, "arrive", _dice(1)).is_empty(), "nowhere in particular: no visit at the edge")


func test_gorthos_stops_coming_once_he_is_slain() -> void:
	var st := _grinning()
	var v := CrookedMoonVisits.get_visit("gorthos_camp")
	assert_true(StoryConditions.check(str(v["when"]), st))
	st.set_flag("gorthos_slain")
	assert_false(StoryConditions.check(str(v["when"]), st))


func test_what_came_survives_a_save() -> void:
	var st := _grinning()
	CrookedMoonVisits.due(st, "rest", _dice(1))
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(CrookedMoonVisits.times_seen(back, "cm_dream_counting").size(), 1)
