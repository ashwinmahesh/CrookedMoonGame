extends TestCase
## A guide who leads without a word (an NPC placement's `leads`; GameRoot.world_action "follow"): the party follows the
## figure across the map with no conversation, and the lead's flag is set once it has.

const GAME := preload("res://world/game_root.gd")
const LOC := "test_hillside"

var st: StoryState
var root: Node


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOC


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		await get_tree().process_frame
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_following_a_mute_guide_across_the_map() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	var cell := Vector2i(20, 24)
	(view.loc["npcs"] as Array).append({"npc": "adelaide_langtree", "cell": [cell.x, cell.y],
		"leads": {"to": "14,22", "flag": "test_followed_guide"}})
	view.refresh_npcs()
	await _frames(4)
	var thing := view.thing_at(cell)
	assert_eq(str(thing.get("kind", "")), "npc", "the guide stands there")
	root.call("world_action", cell, "follow")
	for i in 600:
		await get_tree().process_frame
		if st.flags.has("test_followed_guide"):
			break
	assert_true(st.flags.has("test_followed_guide"), "the party followed, and the lead's flag is set")
	assert_true((root.get("_mute_lead") as Dictionary).is_empty(), "the walk is over")
	assert_true(root.get("dialogue") == null, "no conversation was opened")
