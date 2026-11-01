extends TestCase
## Going on past an ending in an Honour run (EndingScreen.fork_honour): the sealed finished save is never written over;
## the run plays on in a new slot of its own.

var _story: StoryState
var _slot := ""
var _finished := ""


func before_each() -> void:
	_story = GameState.story
	_slot = SaveSystem.current_slot
	_finished = SaveSystem.finished_slot


func after_each() -> void:
	GameState.story = _story
	SaveSystem.current_slot = _slot
	SaveSystem.finished_slot = _finished


func test_an_honour_run_goes_on_in_a_new_slot_and_the_sealed_one_stays() -> void:
	var st := StoryState.new()
	st.options["difficulty"] = "honour"
	GameState.story = st
	SaveSystem.current_slot = ""
	assert_eq(SaveSystem.save_finished("underneath_the_crooked_moon", "Underneath the Crooked Moon"), OK)
	var sealed := SaveSystem.current_slot
	assert_eq(SaveSystem.finished_slot, sealed, "the ending seals the run's one save")
	var fresh := EndingScreen.fork_honour()
	assert_ne(fresh, "")
	assert_ne(fresh, sealed, "a new slot")
	assert_eq(SaveSystem.honour_slot(), fresh, "the run's one save from now on")
	var data := AtomicJson.read(SaveSystem.slot_path(sealed))
	assert_true(data.has("finished"), "the sealed save keeps its finished mark")


func test_outside_honour_nothing_forks() -> void:
	var st := StoryState.new()
	st.options["difficulty"] = "balanced"
	GameState.story = st
	SaveSystem.current_slot = "my_slot"
	assert_eq(EndingScreen.fork_honour(), "")
	assert_eq(SaveSystem.current_slot, "my_slot")
