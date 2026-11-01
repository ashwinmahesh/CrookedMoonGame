extends TestCase
## The Crooked Moon's endings (plan 5.7; data/endings/, story/endings.gd): six for the story and four for Moonfall. The
## good ones wait for the Last Ride's end_game; the ritual's flags (story/sacrifice_ritual.gd) and the barrow's parley pick
## which one plays, and a wipe once the Born King's fight has begun is All Will Be Crooked.

const STORY: Array[String] = ["underneath_the_crooked_moon", "embers_of_the_fallen", "an_empty_car",
	"kneel_to_the_crooked_queen", "live_deliciously", "all_will_be_crooked"]
const MOONFALL: Array[String] = ["the_moon_unbent", "a_green_sea", "the_last_train_out", "moonfall"]


func before_each() -> void:
	Endings.clear_cache()


func after_each() -> void:
	Endings.clear_cache()
	Campaign.use(null)


func _bound(lives: int, heroes: int = 4) -> StoryState:
	var st := StoryState.new()
	st.set_flag("ritual_done")
	st.set_flag("kehlenn_bound")
	st.set_flag("ritual_heroes", heroes)
	st.set_flag("ritual_lives_given", lives)
	st.set_flag("ritual_all_gave", lives >= heroes)
	return st


func test_all_ten_endings_are_written_with_a_narration() -> void:
	for id: String in STORY + MOONFALL:
		var e := Endings.get_ending(id)
		assert_false(e.is_empty(), "%s exists" % id)
		var ref := str(e.get("narration", ""))
		var file := DialogueFile.load_key(ref.get_slice(":", 0))
		assert_true(file != null and file.nodes.has(ref.get_slice(":", 1)), "%s's narration is written" % id)
		assert_false((e.get("epilogue", []) as Array).is_empty(), "%s has slides" % id)


func test_the_module_lists_them_for_the_achievements() -> void:
	Campaign.use(null)
	assert_eq(Campaign.module().endings().size(), STORY.size() + MOONFALL.size())
	assert_eq(str(Campaign.module().ending("an_empty_car").get("title", "")), "An Empty Car")


func test_nothing_ends_the_game_before_its_end() -> void:
	var st := StoryState.new()
	assert_true(Endings.pick(st).is_empty(), "no ending holds with the story still going")
	assert_eq(Endings.auto_due(st), "")


func test_kehlenn_bound_with_no_life_given_is_underneath_the_crooked_moon() -> void:
	var st := _bound(0)
	assert_eq(Endings.auto_due(st), "", "a good ending waits for the Last Ride")
	assert_eq(Endings.request(st), "underneath_the_crooked_moon")


func test_a_life_given_is_embers_of_the_fallen_and_keeps_the_world_s_slides() -> void:
	Campaign.use(null)
	var st := _bound(1)
	var e := Endings.pick(st)
	assert_eq(str(e["id"]), "embers_of_the_fallen")
	var topics: Array[String] = []
	for s: Dictionary in Endings.slides(e, st):
		topics.append(str(s["topic"]))
	assert_true("sacrifice" in topics, "its own")
	assert_true("village" in topics and "the_moon" in topics, "the world's, from Underneath the Crooked Moon")
	assert_eq(topics.count("last_ride"), 1, "its own Last Ride replaces the inherited one")


func test_every_life_given_is_an_empty_car_at_once() -> void:
	var st := _bound(4)
	assert_eq(Endings.auto_due(st), "an_empty_car", "nobody is left to board: it ends at once")


func test_a_failed_ritual_is_all_will_be_crooked_at_once() -> void:
	var st := StoryState.new()
	st.set_flag("ritual_done")
	st.set_flag("ritual_failed")
	assert_eq(Endings.request(st), "all_will_be_crooked")


func test_a_wipe_in_the_born_king_s_fight_is_all_will_be_crooked() -> void:
	Campaign.use(null)
	var st := StoryState.new()
	Campaign.module().final_battle_begun(st)
	assert_eq(Endings.after_fight(st, {"final_battle": "crooked_tree"}, "defeat"), "all_will_be_crooked")


func test_winning_the_born_king_s_fight_does_not_end_the_game() -> void:
	Campaign.use(null)
	var st := StoryState.new()
	Campaign.module().final_battle_begun(st)
	assert_eq(Endings.after_fight(st, {"final_battle": "crooked_tree"}, "victory"), "", "the ritual comes next")


func test_the_parley_s_two_kneelings_end_the_game_without_a_fight() -> void:
	Campaign.use(null)
	var m := Campaign.module()
	var st := StoryState.new()
	assert_true(m.parley_allows_fight(st))
	st.set_flag("parley_answer", "kneel_queen")
	assert_false(m.parley_allows_fight(st))
	assert_true(Endings.parley_ends(st))
	assert_eq(Endings.request(st), "kneel_to_the_crooked_queen")
	var goat := StoryState.new()
	goat.set_flag("parley_answer", "kneel_goat")
	assert_eq(Endings.request(goat), "live_deliciously")
	var fight := StoryState.new()
	fight.set_flag("parley_answer", "fight")
	assert_true(m.parley_allows_fight(fight))


func test_moonfall_s_outcomes_pick_its_four_endings() -> void:
	Campaign.use(null)
	var want := {"unbent": "the_moon_unbent", "green_sea": "a_green_sea", "last_train": "the_last_train_out"}
	for outcome: String in want:
		var st := StoryState.new()
		st.set_flag("moonfall_outcome", outcome)
		assert_eq(str(Endings.pick(st).get("id", "")), str(want[outcome]))
	var fallen := StoryState.new()
	fallen.set_flag("moonfall_outcome", "fallen")
	assert_eq(Endings.auto_due(fallen), "moonfall", "the countdown running out ends it at once")


func test_the_epilogue_reads_the_world() -> void:
	Campaign.use(null)
	var st := _bound(0)
	st.set_flag("crooked_house_destroyed")
	st.set_flag("innocents_slain", 12)
	var texts := {}
	for s: Dictionary in Endings.slides(Endings.get_ending("underneath_the_crooked_moon"), st):
		texts[str(s["topic"])] = str(s["text"])
	assert_true(str(texts.get("crooked_house", "")).contains("cellar hole"), "the house is gone")
	assert_true(str(texts.get("sin", "")).contains("bargains"), "a wicked party's slide")
	assert_false(texts.has("foxwillow"), "Raum still stands: no slide for a harvest without him")
