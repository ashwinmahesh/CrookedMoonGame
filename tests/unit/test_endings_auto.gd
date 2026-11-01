extends TestCase
## An ending that comes by itself (`auto: true`; Endings.auto_due): once its `when` holds the game ends without an
## `end_game`, the highest-priority such ending recorded, once.


func before_each() -> void:
	Endings.clear_cache()
	Endings.register({"id": "test_auto_low", "priority": 1, "auto": true, "when": "flag.test_moon_days <= 0"})
	Endings.register({"id": "test_auto_high", "priority": 5, "auto": true, "when": "flag.test_moon_days <= 0 and flag.test_alone"})
	Endings.register({"id": "test_plain", "priority": 9, "when": "flag.test_moon_days <= 0"})


func after_each() -> void:
	Endings.clear_cache()


func test_it_waits_for_its_condition_then_records_the_highest() -> void:
	var st := StoryState.new()
	st.set_flag("test_moon_days", 3)
	assert_eq(Endings.auto_due(st), "", "not yet")
	st.set_flag("test_moon_days", 0)
	st.set_flag("test_alone", true)
	assert_eq(Endings.auto_due(st), "test_auto_high", "the highest auto ending; a plain one never comes by itself")
	assert_eq(Endings.reached(st), "test_auto_high")
	assert_eq(Endings.auto_due(st), "", "once")
	assert_eq(Endings.request(st), "test_auto_high", "the ending screen plays the one recorded")


func test_a_plain_ending_needs_end_game() -> void:
	Endings.clear_cache()
	Endings.register({"id": "test_plain", "priority": 9, "when": "true"})
	assert_eq(Endings.auto_due(StoryState.new()), "")
