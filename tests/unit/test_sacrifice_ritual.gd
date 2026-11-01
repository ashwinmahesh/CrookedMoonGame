extends TestCase
## The sacrifice ritual at the Crooked Tree (plan 5.7 and 13.11, G5; story/sacrifice_ritual.gd, data/ritual/sacrifice.json):
## each hero offers and rolls a d20 in the open; Kehlenn spends Ritual Points to pull rolls under the DC, capped by
## difficulty; six refusals fail the ritual; Heroic Inspiration rerolls once; a life is accepted without a roll; the
## fallen still offer.

const HEROES: Array[String] = ["rook_coldwake", "delphine_ravelle", "lucan_houndstooth", "cordelia_skein"]


class ScriptedDice extends DiceRoller:
	var d20s: Array[int] = []

	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		if sides == 20 and count == 1 and not d20s.is_empty():
			var out: Array[int] = [d20s.pop_front() as int]
			_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
			return out
		return super.roll(sides, count, reason)


func after_each() -> void:
	SacrificeRitual.clear_cache()
	Sin.clear_cache()


func _st(difficulty: String = "balanced") -> StoryState:
	var st := StoryState.new()
	st.options["difficulty"] = difficulty
	for id: String in HEROES:
		st.party.append(TestChars.pregen(id, 5))
	return st


func _dice(rolls: Array[int]) -> ScriptedDice:
	var d := ScriptedDice.new(1)
	d.d20s = rolls
	return d


func _points(st: StoryState) -> int:
	return int(SacrificeRitual.state(st)["points"])


func test_kehlenn_starts_with_the_base_and_the_party_s_sin() -> void:
	var st := _st()
	var clean := SacrificeRitual.starting_points(st)
	st.set_flag("innocents_slain", 8)
	assert_eq(SacrificeRitual.starting_points(st), clean + Sin.ritual_points(st))
	assert_true(SacrificeRitual.starting_points(st) > clean, "a wicked party arms her")


func test_her_cap_follows_the_difficulty() -> void:
	assert_eq(SacrificeRitual.cap(_st("story")), 3)
	assert_eq(SacrificeRitual.cap(_st("balanced")), 5)
	assert_true(SacrificeRitual.cap(_st("honour")) >= 20, "Tactician and Honour: all she has")


func test_every_hero_can_offer_ability_points_a_feature_and_a_life() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	var ids: Array[String] = []
	for o: Dictionary in SacrificeRitual.offerings(st, st.party[0]):
		ids.append(str(o["id"]))
	for want: String in ["ability", "feature", "life"]:
		assert_true(want in ids, "a hero can offer %s" % want)


func test_a_high_roll_she_can_t_afford_to_spoil_is_accepted() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	var ch := st.party[0]
	var before := _points(st)
	var res := SacrificeRitual.offer(st, ch, "feature", _first_choice(st, ch, "feature"), _dice([20]))
	assert_true(bool(res["accepted"]), "20 + 4 against 11: she'd need 14, her cap is 5")
	assert_eq(int(res["spent"]), 0)
	assert_eq(_points(st), before, "she keeps her points")
	assert_false(SacrificeRitual.waiting(st, ch))


func test_a_near_pass_is_pulled_under_and_refused() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	var ch := st.party[0]
	var before := _points(st)
	var res := SacrificeRitual.offer(st, ch, "ability", "str", _dice([9]))
	assert_false(bool(res["accepted"]), "9 + 3 = 12 against 11: two points pull it under")
	assert_eq(int(res["spent"]), 2)
	assert_eq(_points(st), before - 2)
	assert_eq(int(res["refusals"]), 1)
	assert_true(SacrificeRitual.waiting(st, ch), "a refused hero offers again")
	assert_false("str" in _choice_ids(st, ch, "ability"), "the same offering isn't made twice")


func test_heroic_inspiration_rerolls_a_refused_offering() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	var ch := st.party[0]
	ch.heroic_inspiration = true
	SacrificeRitual.offer(st, ch, "ability", "str", _dice([2]))
	assert_true(SacrificeRitual.can_reroll(st, ch))
	var res := SacrificeRitual.reroll(st, ch, _dice([20]))
	assert_true(bool(res["accepted"]))
	assert_eq(int(SacrificeRitual.state(st)["refusals"]), 0, "the refusal it replaced is taken back")
	assert_false(ch.heroic_inspiration, "spent")
	assert_false(SacrificeRitual.can_reroll(st, ch))


func test_two_points_of_an_ability_are_taken_and_named() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	var ch := st.party[0]
	var before := ch.ability_score(&"wis")
	SacrificeRitual.offer(st, ch, "ability", "wis", _dice([20]))
	assert_eq(ch.ability_score(&"wis"), before - 2)


func test_six_refusals_fail_the_ritual() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	var ch := st.party[0]
	var rolls: Array[int] = [1, 1, 1, 1, 1, 1]
	var dice := _dice(rolls)
	for ab: String in ["str", "dex", "con", "int", "wis", "cha"]:
		SacrificeRitual.offer(st, ch, "ability", ab, dice)
	assert_true(SacrificeRitual.over(st))
	assert_eq(SacrificeRitual.finish(st), "failed")
	assert_eq(str(st.get_flag("crooked_cause", "")), "ritual_failed")
	assert_eq(int(st.get_flag("ritual_fails", 0)), 6)
	assert_false(bool(st.get_flag("kehlenn_bound", false)))


func test_every_offering_accepted_binds_kehlenn_and_the_last_act_costs_a_life() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	var gave := st.party[3]
	for i in 3:
		SacrificeRitual.offer(st, st.party[i], "ability", "cha", _dice([20]))
	assert_false(SacrificeRitual.over(st))
	var res := SacrificeRitual.offer(st, gave, "life", "life", _dice([]))
	assert_true(bool(res["accepted"]), "a life needs no roll")
	assert_eq(SacrificeRitual.finish(st), "bound")
	assert_true(bool(st.get_flag("kehlenn_bound", false)))
	assert_eq(int(st.get_flag("last_act_count", 0)), 1)
	assert_eq(int(st.get_flag("party_size", 0)), 4)
	assert_false(bool(st.get_flag("ritual_all_gave", false)))
	assert_false(st.party.has(gave), "lost for good")
	assert_eq(str(st.fallen[0].get("id", "")), gave.id)


func test_a_fallen_hero_offers_as_a_spirit_but_has_no_life_to_give() -> void:
	var st := _st()
	var spirit := st.party[1]
	spirit.dead = true
	SacrificeRitual.begin(st)
	assert_true(SacrificeRitual.waiting(st, spirit), "the fallen still offer")
	assert_false("life" in _offering_ids(st, spirit))


func test_a_hero_who_won_t_offer_fails_it_at_once() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	SacrificeRitual.refuse(st, st.party[2])
	assert_eq(SacrificeRitual.finish(st), "unwilling")
	assert_eq(str(st.get_flag("crooked_cause", "")), "refused")


func test_the_ritual_s_gift_once_kehlenn_is_bound() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	for ch: Character in st.party:
		SacrificeRitual.offer(st, ch, "feature", _first_choice(st, ch, "feature"), _dice([20]))
	SacrificeRitual.finish(st)
	var ch := st.party[0]
	var before := ch.ability_score(&"str")
	assert_eq(SacrificeRitual.grant_boon(st, ch, "str"), ch.ability_score(&"str") - before)
	assert_true(ch.ability_score(&"str") > before)
	assert_eq(SacrificeRitual.grant_boon(st, ch, "str"), 0, "once")


func test_the_ritual_survives_a_save() -> void:
	var st := _st()
	SacrificeRitual.begin(st)
	SacrificeRitual.offer(st, st.party[0], "ability", "str", _dice([1]))
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(int(SacrificeRitual.state(back)["refusals"]), 1)
	assert_true(SacrificeRitual.waiting(back, back.party[0]))


func _offering_ids(st: StoryState, ch: Character) -> Array[String]:
	var out: Array[String] = []
	for o: Dictionary in SacrificeRitual.offerings(st, ch):
		out.append(str(o["id"]))
	return out


func _choice_ids(st: StoryState, ch: Character, kind: String) -> Array[String]:
	var out: Array[String] = []
	for o: Dictionary in SacrificeRitual.offerings(st, ch):
		if str(o["id"]) == kind:
			for c: Variant in o["choices"]:
				out.append(str((c as Dictionary)["id"]))
	return out


func _first_choice(st: StoryState, ch: Character, kind: String) -> String:
	var ids := _choice_ids(st, ch, kind)
	return ids[0] if not ids.is_empty() else ""
