extends TestCase
## Sin (plan 5.5 and 13.10, G4; story/sin.gd, data/ritual/sin.json): a hidden tally fed by Crooked Bargains, Mister
## Crossroads's deals, the Horned King's offers and death bargains, slain innocents and betrayed Connections. Its tier sets
## how hard the temptations press and gives Kehlenn Ritual Points.


func after_each() -> void:
	Sin.clear_cache()
	Campaign.use(null)


func _hero(gifts: Array[String]) -> Character:
	var ch := Character.new()
	ch.name = "Test Hero"
	ch.build["dark_gifts"] = gifts
	return ch


func test_a_clean_party_has_no_sin() -> void:
	var st := StoryState.new()
	assert_eq(Sin.total(st), 0)
	assert_eq(str(Sin.tier(st)["id"]), "clean")
	assert_eq(Sin.ritual_points(st), 0)
	assert_eq(Sin.press(st), 0)


func test_each_source_counts_its_points() -> void:
	var st := StoryState.new()
	st.party.append(_hero(["crooked_fortune"]))
	st.bench.append(_hero(["hand_of_death", "might_of_the_old"]))
	assert_eq(Sin.total(st), 3, "every bargain carried, benched heroes too")
	st.set_flag("sinner_deals", 2)
	st.set_flag("horned_bargains", 1)
	st.set_flag("connections_betrayed", 1)
	assert_eq(Sin.total(st), 3 + 2 + 2 + 2)
	assert_eq(int(Sin.by_source(st)["horned_bargains"]), 2, "the goat's offers weigh double")


func test_the_tier_rises_with_the_tally_and_so_do_its_effects() -> void:
	var st := StoryState.new()
	var last_points := -1
	var last_press := -1
	for n: int in [0, 1, 4, 8, 12]:
		st.set_flag("sin_other", n)
		assert_true(Sin.ritual_points(st) > last_points, "more Ritual Points for Kehlenn at %d" % n)
		assert_true(Sin.press(st) > last_press, "the temptations press harder at %d" % n)
		last_points = Sin.ritual_points(st)
		last_press = Sin.press(st)
	assert_eq(str(Sin.tier(st)["id"]), "damned")


func test_a_flag_that_isn_t_a_number_counts_nothing() -> void:
	var st := StoryState.new()
	st.set_flag("innocents_slain", true)
	assert_eq(Sin.total(st), 0)


func test_conditions_read_the_tier() -> void:
	Campaign.use(null)
	var st := StoryState.new()
	st.set_flag("innocents_slain", 5)
	assert_true(StoryConditions.check("tarokka.sin.tier == stained", st))
	assert_true(StoryConditions.check("tarokka.sin.at_least.tempted", st))
	assert_true(StoryConditions.check("tarokka.sin.at_least.stained", st))
	assert_false(StoryConditions.check("tarokka.sin.at_least.wicked", st))
	assert_eq(Campaign.module().field(st, "sin.points"), str(Sin.ritual_points(st)))
