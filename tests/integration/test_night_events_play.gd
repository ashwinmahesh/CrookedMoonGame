extends TestCase
## Named night events in the game (data/camp/night_events.json, NightEvents): a real Long Rest at a Hartsblight camp
## map breaks for the Dead of Night's talk before its benefits, and the party sleeps on once the talk is over.

const GAME := preload("res://world/game_root.gd")

var root: Node


func test_a_rest_in_the_forest_plays_the_dead_of_night_then_sleeps_on() -> void:
	GameState.reset()
	var st := GameState.story
	for pid: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(pid, 5)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = "hb_altar_of_rot"
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 15:
		await get_tree().process_frame
	var hero := st.party[0]
	hero.hp = 1
	var res := LongRest.take(st, "safe", Dice.roller)
	assert_eq(str(res["how"]), LongRest.VISIT, "the night breaks")
	assert_eq(hero.hp, 1, "before the rest's benefits")
	root.call("visit_after_rest", int(res["minutes"]))
	await get_tree().process_frame
	assert_true(root.get("dialogue") != null, "the Dead of Night's talk opens")
	assert_true(bool(st.flags.get("hb_night_drums", false)), "the first night's event: the drums")
	assert_false(LongRest.event_waiting(st))
	(root.get("dialogue") as DialogueUI).ended.emit("")
	for i in 3:
		await get_tree().process_frame
	assert_false(LongRest.broken(st), "the party slept on")
	assert_eq(hero.hp, hero.max_hp(), "and has the rest's benefits")
	root.queue_free()
	await get_tree().process_frame
	GameState.reset()
