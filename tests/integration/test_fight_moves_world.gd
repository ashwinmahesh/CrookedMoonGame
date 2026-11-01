extends TestCase
## A boss phase that moves the fight, in the real game (the engine's BossPhases `move`, LocationFights.continue_moved):
## the fight ends where it was, the party is carried to the place the phase names, and the same fight goes on there with
## everyone as they were.

const GAME := preload("res://world/game_root.gd")
const LOC := "test_hillside"
const FIGHT := "hillside_scarecrows"

var st: StoryState
var root: Node
var _kept: Dictionary = {}


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOC


func after_each() -> void:
	if not _kept.is_empty():
		Compendium.shared().table("monsters")["scarecrow"] = _kept
		_kept = {}
	if is_instance_valid(root):
		root.queue_free()
		await get_tree().process_frame
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_the_fight_goes_on_where_the_phase_sends_it() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	var block := Compendium.shared().table("monsters")["scarecrow"] as Dictionary
	_kept = block.duplicate(true)
	block["phases"] = [{"id": "test_geyser", "when": {"bloodied": true}, "move": {"location": LOC, "spawn": "from_creek", "encounter": FIGHT}}]
	assert_true(view.start_encounter(FIGHT), "the fight starts")
	await _frames(6)
	var e := view.combat_view.e
	var foe: Combatant = null
	for c in e.combatants:
		if c.side == &"enemy":
			foe = c
	var hurt := foe.creature.max_hp() - 1
	e.deal_damage(e.combatants[0], foe, [{"amount": foe.creature.max_hp() / 2 + 1, "type": "force"}], false, "test")
	var left := foe.creature.hp
	assert_eq(e.outcome, "moved")
	st.party[0].hp = 3
	view.combat_view.finished.emit("moved")
	for i in 300:
		await get_tree().process_frame
		var now := root.get("view") as LocationView
		if now != view and now.in_combat:
			break
	var after := root.get("view") as LocationView
	assert_true(after != view and after.in_combat, "the place is entered and the fight is on again")
	var again := after.combat_view.e
	var same: Combatant = null
	for c in again.combatants:
		if c.side == &"enemy" and c.name() == foe.name():
			same = c
	assert_true(same != null, "the same foe")
	assert_eq(same.creature.hp, left, "with the Hit Points it had")
	assert_eq(st.party[0].hp, 3, "and the heroes theirs")
	assert_false(st.flags.has("_fight_moved"), "picked up once")
	assert_true(hurt > 0)
