extends TestCase
## The sleeping wildpyre in the Baggage Car (G6), played in the real location: it lies in plain view as a foe the party can
## strike or cast at (which opens its fight with the tiger surprised), a failed try at the ring still wakes it (the flag), and a
## party that slips past leaves it asleep. What the engine would have to add (going back to sleep when the party leaves the
## car or the hero who hurt it drops) is in the vault's Act 1 Audit, section C.

const LOC := "ghostlight_g6_baggage"
const GAME := preload("res://world/game_root.gd")
const TIGER := Vector2i(16, 3)

var root: Node
var st: StoryState
var view: LocationView


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOC
	Dice.reseed(7)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The game started in the car, and the party walked to the front door, where the tiger lies in view down the aisle.
func _arrive() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	view = root.get("view") as LocationView
	assert_true(view != null and view.loc_id == LOC, "the game starts in the Baggage Car")
	for m: Combatant in view.members:
		m.cell = Vector2i(18, 3)
	view._waiting_key = ""
	LocationStealth.refresh_waiting(view)


func _tiger() -> Dictionary:
	for w: Dictionary in view.waiting:
		if str(w["encounter"]) == "gl_wildpyre":
			return w
	return {}


func test_the_tiger_lies_in_plain_view_as_a_foe_waiting_to_be_struck() -> void:
	await _arrive()
	var w := _tiger()
	assert_true(not w.is_empty(), "the wildpyre waits as a foe")
	assert_true(LocationStealth.is_shown(w), "and shows once the party can see it")
	assert_eq((w["foe"] as Combatant).cell, TIGER, "on its square")
	assert_true(LocationStealth.is_asleep(view, w), "asleep: it notices nobody")
	var thing := view.thing_at(TIGER)
	assert_eq(str(thing.get("kind", "")), "foe", "the square holds a foe, not a person to talk to")
	var ids: Array[String] = []
	for a: Dictionary in (view.actions_at(TIGER)["actions"] as Array):
		ids.append(str(a["id"]))
	assert_true("strike" in ids, "the menu offers the attack that starts the fight")
	assert_true(not view.npc_tokens.has("wildpyre"), "and it is no sleeping NPC any more")


func test_striking_the_sleeping_tiger_opens_its_fight_with_it_surprised() -> void:
	await _arrive()
	var spec := LocationFights.spec_for(view, "gl_wildpyre")
	assert_eq(str(spec.get("surprise", "")), "enemies", "a sleeper is caught unawares")
	view.act(TIGER, "strike")
	await _frames(6)
	assert_true(view.in_combat, "the blow starts the fight")
	assert_eq(view.fight_id, "gl_wildpyre")
	var e := view.combat_view.e
	assert_true(e.combatants.any(func(c: Combatant) -> bool: return c.side == &"enemy" and c.name().to_lower().contains("wildpyre")), "the tiger is in it")


func test_a_spell_at_the_sleeping_tiger_opens_the_fight_too() -> void:
	await _arrive()
	var cast := false
	for a: Dictionary in (view.actions_at(TIGER)["actions"] as Array):
		if str(a["id"]).begins_with("strike_cast:") and bool(a.get("enabled", true)):
			cast = true
	assert_true(cast, "a spell at it is offered, and starts the fight (LocationNpcs.strike_with_spell)")


func test_a_slip_at_the_ring_still_wakes_it_by_the_flag() -> void:
	await _arrive()
	assert_true(not view.in_combat)
	st.set_flag("wildpyre_woken")
	assert_true(view.check_flag_encounters(), "the flag starts a fight")
	await _frames(6)
	assert_true(view.in_combat and view.fight_id == "gl_wildpyre", "the same fight")
	var woken := {}
	for e: Variant in view.loc.get("encounters", []):
		if str((e as Dictionary)["id"]) == "gl_wildpyre" and str((e as Dictionary)["trigger"]) == "flag:wildpyre_woken":
			woken = e as Dictionary
	assert_eq(str(woken.get("surprise", "")), "", "a tiger woken by a burned hand is not surprised")


func test_leaving_it_asleep_starts_nothing() -> void:
	await _arrive()
	for i in 4:
		await _frames(2)
		LocationStealth.after_step(view)
	assert_true(not view.in_combat, "a sleeping tiger notices nobody")
	assert_true(not _tiger().is_empty(), "and waits")


func test_a_dead_wildpyre_leaves_no_sleeper() -> void:
	(st.loc_state(LOC)["encounters"] as Dictionary)["gl_wildpyre"] = true
	st.set_flag("wildpyre_destroyed")
	await _arrive()
	assert_true(_tiger().is_empty(), "no foe waits once it has fallen")
