extends TestCase
## A bonded companion in the real game (the engine's Companions): it walks at the back of the line and comes into a fight
## beside its hero on the party's side.

const GAME := preload("res://world/game_root.gd")
const LOC := "test_hillside"
const FIGHT := "hillside_scarecrows"

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


func test_a_companion_follows_and_fights() -> void:
	Companions.bond(st, st.party[1].id, "wolf", "Test Pup")
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	var walking := view.guest_members.filter(func(g: Combatant) -> bool: return g.has_meta("companion_of"))
	assert_eq(walking.size(), 1, "it walks with the party")
	assert_eq((walking[0] as Combatant).name(), "Test Pup")
	assert_true(view.start_encounter(FIGHT), "the fight starts")
	await _frames(6)
	var e := view.combat_view.e
	var pup := e.combatants.filter(func(c: Combatant) -> bool: return c.has_meta("companion_of"))
	assert_eq(pup.size(), 1, "it fights")
	assert_eq((pup[0] as Combatant).side, &"party")
	assert_eq(e.combatants.filter(func(c: Combatant) -> bool: return c.name() == "Test Pup").size(), 1, "once, not also as a guest")
