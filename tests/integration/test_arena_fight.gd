extends TestCase
## The arena fight (the foundation's first fight, plan section 10.4): four of the companions (Rook, Silas, Cordelia, Delphine) at level 3 against three
## scarecrows and a swarm of ravens in a trampled clearing in the corn, loaded from data/encounters/arena_wolves_and_zombies.json
## (the engine's fixed arena id) and played to the end many times over.

const ARENA := "arena_wolves_and_zombies"


func test_arena_loads_from_data() -> void:
	var errors: Array[String] = []
	var e := EncounterSetup.load_id(ARENA, DiceRoller.new(1), errors)
	assert_true(errors.is_empty(), str(errors))
	assert_eq(e.combatants.size(), 8)
	var names := e.combatants.map(func(c: Combatant) -> String: return c.name())
	assert_true("Scarecrow 1" in names and "Scarecrow 3" in names, str(names))
	for hero: String in ["Rook Coldwake", "Silas Vane", "Cordelia Skein", "Delphine Ravelle"]:
		assert_true(hero in names, "%s fights in the arena, not the first game's heroes: %s" % [hero, names])
	for c in e.combatants:
		for cell in c.footprint():
			assert_false(e.grid.is_solid(cell), "%s stands on open floor" % c.name())
	assert_true(e.grid.highest_ground() > 0, "the clearing is on a rise: the map has elevation rows")


## The fights in two halves, so make test can run them side by side. Each half must be won at least once.
func test_arena_fights_1_to_4_finish_with_sensible_results() -> void:
	_fights(range(1, 5))


func test_arena_fights_5_to_8_finish_with_sensible_results() -> void:
	_fights(range(5, 9))


## Plays the arena once per seed with the autopilot, to the end.
func _fights(seeds: Array) -> void:
	var wins := 0
	var rounds := 0
	var downs := 0
	var runs := seeds.size()
	for seed_value: int in seeds:
		var e := EncounterSetup.load_id(ARENA, DiceRoller.new(seed_value))
		var res := PartyAutopilot.new(e).run(30)
		assert_ne(str(res["outcome"]), "timeout", "seed %d finished" % seed_value)
		if str(res["outcome"]) == "victory":
			wins += 1
		rounds += int(res["rounds"])
		downs += int(res["downs"])
		for c in e.combatants:
			assert_true(c.creature.hp >= 0 and c.creature.hp <= c.creature.max_hp(), "%s HP in range" % c.name())
		assert_true(e.pending == null)
	print("        arena seeds %d-%d: %d/%d victories, %.1f rounds on average, %.1f party members dropped per fight" % [
		seeds[0], seeds[-1], wins, runs, rounds / float(runs), downs / float(runs)])
	assert_true(wins >= 1, "the party can win it (%d/%d)" % [wins, runs])
