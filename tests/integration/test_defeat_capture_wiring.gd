extends TestCase
## A fight lost by being taken (an encounter's `defeat`, the engine's DefeatCapture): the party falls, there is no
## game over, the fallen come round, the flag is stamped and the party is carried where the rule says.

const LOC := "test_hillside"
const FIGHT := "hillside_scarecrows"

var st: StoryState
var root: Node


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in (preload("res://world/game_root.gd")).PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOC
	Dice.reseed(7)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		await get_tree().process_frame
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_a_wipe_in_a_capture_fight_is_no_game_over() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	for enc: Dictionary in view.loc["encounters"]:
		if str(enc.get("id", "")) == FIGHT:
			enc["defeat"] = {"move": LOC + ":from_creek", "set": "test_taken"}
	assert_true(view.start_encounter(FIGHT), "the fight starts")
	await _frames(6)
	var cv := view.combat_view
	for ch in st.party:
		ch.hp = 0
	cv.e._check_over()
	assert_eq(cv.e.outcome, "defeat")
	cv.finished.emit("defeat")
	await _frames(60)
	assert_false(root.get("screen") is PauseMenu, "no game-over screen")
	assert_true(st.flags.has("test_taken"), "the flag is stamped")
	for ch in st.party:
		assert_eq(ch.hp, 1, "%s comes round at 1 HP" % ch.name)
	assert_eq((preload("res://world/game_root.gd")).sting_for(DefeatCapture.OUTCOME), "defeat", "it sounds like a loss")
