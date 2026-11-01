extends TestCase
## The Ghostlight Locomotive's fight at the wreck, played on fixed seeds by the starting companions at level 3 on the
## test autopilot (CompanionAutopilot, sharp play, Balanced), begun the way the game begins it: the owner's target for a
## fight is about 5 wins in 8 (docs/handbook/testing.md, part 5). Prints a line per fight and a total; SEEDS=n plays
## seeds 1 to n (8 by default), DIFFICULTY=tactician another mode, and LOG_SEED=n LOG_FILE=<path> writes that fight's
## combat log. The walk-away fight from the clearing's edge (gl_locomotive_edge) plays the same way.

const LOC := "ghostlight_wreckage"
const GAME := preload("res://world/game_root.gd")

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(2)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seeds() -> int:
	return maxi(int(OS.get_environment("SEEDS")), 1) if OS.get_environment("SEEDS") != "" else 8


## One fight on `seed_`: {outcome, rounds, downs, cans, hp} (cans eaten, the engine's Hit Points left).
func _play(fight: String, seed_: int) -> Dictionary:
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOC
	if OS.get_environment("DIFFICULTY") != "":
		st.options["difficulty"] = OS.get_environment("DIFFICULTY")
		for ch in st.party:
			Difficulty.named(OS.get_environment("DIFFICULTY")).fit_party(ch)
	Dice.reseed(seed_)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter(fight), "%s starts" % fight)
	await _frames(4)
	var e := view.combat_view.e
	Dice.reseed(seed_)
	var r := CompanionAutopilot.new(e).run(30)
	var engine := e.combatants.filter(func(c: Combatant) -> bool: return c.id.begins_with("ghostlight_locomotive"))
	r["hp"] = (engine[0] as Combatant).creature.hp if not engine.is_empty() else -1
	r["cans"] = e.objects.list.filter(func(o: BattleObject) -> bool: return o.fuel == "soul_can" and o.destroyed).size()
	var echoes := e.combatants.filter(func(c: Combatant) -> bool: return c.has_meta(ObjectFuel.RELEASED_META))
	if OS.get_environment("LOG_SEED") == str(seed_):
		var f := FileAccess.open(OS.get_environment("LOG_FILE"), FileAccess.WRITE)
		for t: String in e.log.texts():
			f.store_line(t)
		f.close()
	print("  %s seed %d: %s in %d rounds, %d down, %d cans gone, %d echoes (%d standing), engine at %d" % [fight,
		seed_, r["outcome"], r["rounds"], r["downs"], r["cans"], echoes.size(),
		echoes.filter(func(c: Combatant) -> bool: return c.creature.hp > 0).size(), r["hp"]])
	root.queue_free()
	await _frames(2)
	return r


## Plays `fight` on every seed; its wins, after the guards every series holds: each fight finishes, and it can be won.
func _series(fight: String) -> int:
	var wins := 0
	var rounds := 0
	var n := _seeds()
	for s in range(1, n + 1):
		var r: Dictionary = await _play(fight, s)
		assert_ne(str(r["outcome"]), "timeout", "%s seed %d finishes" % [fight, s])
		if str(r["outcome"]) == "victory":
			wins += 1
		rounds += int(r["rounds"])
	print("%s: %d/%d won, %.1f rounds on average" % [fight, wins, n, float(rounds) / n])
	assert_true(wins > 0, "%s can be won" % fight)
	return wins


## Measured 2026-11-01 over seeds 1 to 16 on Balanced: 8 wins (4 of seeds 1 to 8), Story 8 of 8, Tactician and Honour
## 4 of 8. Before the companions cast their spells (PartyAutopilot alone) it was 4 in 16, the "1 in 4" reported.
func test_the_first_try() -> void:
	var wins: int = await _series("gl_locomotive")
	if _seeds() == 8 and OS.get_environment("DIFFICULTY") in ["", "balanced"]:
		assert_between(wins, 2, 6, "the first try stays near the target (4 of 8 when measured)")


## The retry after a wipe begins here, with the engine 30 ft off in the bowl and every can still on its square: 16 of 16
## won when measured.
func test_from_the_clearings_edge() -> void:
	await _series("gl_locomotive_edge")
