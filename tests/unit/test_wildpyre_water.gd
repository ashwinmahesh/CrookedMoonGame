extends TestCase
## The wildpyre's Quenching Water (data/monsters/wildpyre.json, combat/bestiary/bestiary_features.gd): a hero carrying a jug of
## water (the Dining Car hands them out) can throw it from the hotbar, and only at a creature that burns from water.

const THROW := "feat:gm:bs_throw_water"


func _field() -> Encounter:
	var rows: Array[String] = []
	for z in 8:
		rows.append("........................")
	var e := TestCombat.encounter(rows, 3)
	e.default_player_reaction = "never"
	return e


func _hero_with_jugs(e: Encounter, cell: Vector2i, jugs: int = 2) -> Combatant:
	var c := TestCombat.hero(e, "hedda_ironvow", cell, 3)
	if jugs > 0:
		(c.creature as Character).add_item("jug_of_water", jugs)
	return c


func _jugs(c: Combatant) -> int:
	var n := 0
	for en: Dictionary in (c.creature as Character).inventory:
		if str(en["id"]) == "jug_of_water":
			n += int(en["qty"])
	return n


func _throw(e: Encounter, c: Combatant, t: Combatant) -> CombatResult:
	var a := ActionCatalog.new(e).find(c, THROW)
	if a.is_empty():
		return CombatResult.fail("not on the hotbar")
	return ActionCatalog.new(e).perform(c, a, [t], Vector2.INF)


func test_the_wildpyre_burns_from_water_and_the_haint_does_not() -> void:
	var e := _field()
	var tiger := e.add(TestCombat.monster("wildpyre"), &"enemy", Vector2i(8, 3))
	var haint := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(9, 3))
	assert_true(BestiaryFeatures.burns_from_water(tiger), "the tiger burns")
	assert_true(not BestiaryFeatures.burns_from_water(haint), "a haint, though undead, does not (water is not holy water to it)")


func test_a_jug_is_a_hotbar_action_only_while_a_wildpyre_is_in_the_fight() -> void:
	var e := _field()
	var hero := _hero_with_jugs(e, Vector2i(3, 3))
	var haint := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(8, 3))
	TestCombat.start_with(e, hero)
	assert_true(ActionCatalog.new(e).find(hero, THROW).is_empty(), "nothing to throw it at: no button")
	var tiger := e.add(TestCombat.monster("wildpyre"), &"enemy", Vector2i(9, 3))
	assert_true(not ActionCatalog.new(e).find(hero, THROW).is_empty(), "with a wildpyre in the fight there is")
	var bare := e.add(TestChars.pregen("silvain_aster", 3), &"party", Vector2i(2, 3))
	assert_true(ActionCatalog.new(e).find(bare, THROW).is_empty(), "and a hero with no jug has none")
	assert_true(haint != null and tiger != null)


func test_a_failed_save_burns_the_wildpyre_and_the_jug_is_used_up() -> void:
	var e := _field()
	var hero := _hero_with_jugs(e, Vector2i(3, 3))
	var tiger := e.add(TestCombat.monster("wildpyre"), &"enemy", Vector2i(8, 3))
	TestCombat.start_with(e, hero)
	var hp := tiger.creature.hp
	var r: CombatResult = CombatResult.fail("never thrown")
	var hurt := false
	# The save is a real Dexterity roll: try seeds until it fails, so the damage path is the one under test.
	for seed_value in range(1, 40):
		e = _field()
		hero = _hero_with_jugs(e, Vector2i(3, 3))
		tiger = e.add(TestCombat.monster("wildpyre"), &"enemy", Vector2i(6, 3))
		e.dice.reseed(seed_value)
		TestCombat.start_with(e, hero)
		hp = tiger.creature.hp
		r = _throw(e, hero, tiger)
		assert_true(r.ok, "the throw is legal: %s" % r.reason)
		assert_eq(_jugs(hero), 1, "one jug is gone, win or lose")
		assert_true(not hero.action_available, "and it took the action")
		if tiger.creature.hp < hp:
			hurt = true
			break
	assert_true(hurt, "some throw gets through the save")
	assert_true(hp - tiger.creature.hp >= 2 and hp - tiger.creature.hp <= 16, "2d8 Radiant")


func test_water_wont_go_at_a_haint_or_from_too_far_off() -> void:
	var e := _field()
	var hero := _hero_with_jugs(e, Vector2i(1, 3))
	var tiger := e.add(TestCombat.monster("wildpyre"), &"enemy", Vector2i(20, 3))
	var haint := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	assert_true(not _throw(e, hero, haint).ok, "a haint doesn't burn")
	assert_true(not _throw(e, hero, tiger).ok, "and the tiger is 95 ft away")
	assert_eq(_jugs(hero), 2, "nothing was spent")
