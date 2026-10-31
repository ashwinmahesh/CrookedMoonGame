extends TestCase
## Raum's crows (R13): his Devour Crow Bonus Action eats an amber crow within 30 ft for 10, 20 and 30 Temporary Hit Points, and the third
## ends his first phase; six crows gone does too, however they went.


func _field() -> Encounter:
	var rows: Array[String] = []
	for z in 12:
		rows.append("....................")
	var e := TestCombat.encounter(rows, 3)
	e.default_player_reaction = "never"
	return e


func _devour(e: Encounter, raum: Combatant) -> Variant:
	raum.bonus_available = true
	var act: Dictionary = {}
	for a: Variant in MonsterActions.data_of(raum).get("bonus_actions", []):
		if str((a as Dictionary)["id"]) == "eat_crow":
			act = a as Dictionary
	return e.game.bonus_action(raum, act, "")


func test_three_crows_eaten_end_the_murder_phase() -> void:
	var e := _field()
	var raum := e.add(TestCombat.monster("harvest_terror"), &"enemy", Vector2i(10, 5))
	for i in 3:
		e.add(TestCombat.monster("amber_crow"), &"enemy", Vector2i(8 + i, 7))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 5), 3)
	TestCombat.start_with(e, hero)
	var want := [10, 20, 30]
	for n in 3:
		assert_false(e.legendary.phases.is_active(raum, "demon_of_secrets"), "still the murder before crow %d" % (n + 1))
		assert_true(_devour(e, raum) != null, "crow %d is eaten" % (n + 1))
		assert_eq(raum.creature.temp_hp, int(want[n]), "temporary Hit Points after crow %d" % (n + 1))
		assert_eq(int(raum.get_meta("area_bonus_ft", 0)), 5 * (n + 1), "his areas grow 5 ft a crow")
	assert_true(bool(e.legendary.story_flags.get("fw_crows_eaten_3", false)))
	assert_true(e.legendary.phases.is_active(raum, "demon_of_secrets"), "the third crow bursts the murder")
	assert_true(_devour(e, raum) == null, "no fourth")


func test_nothing_to_eat_without_a_crow_in_reach() -> void:
	var e := _field()
	var raum := e.add(TestCombat.monster("harvest_terror"), &"enemy", Vector2i(18, 5))
	e.add(TestCombat.monster("amber_crow"), &"enemy", Vector2i(1, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 8), 3)
	TestCombat.start_with(e, hero)
	assert_true(_devour(e, raum) == null)


func test_six_crows_gone_end_it_too() -> void:
	var e := _field()
	var raum := e.add(TestCombat.monster("harvest_terror"), &"enemy", Vector2i(10, 5))
	var crows: Array[Combatant] = []
	for i in 6:
		crows.append(e.add(TestCombat.monster("amber_crow"), &"enemy", Vector2i(2 + i, 9)))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2), 3)
	TestCombat.start_with(e, hero)
	for i in 5:
		e.deal_damage(null, crows[i], [{"amount": 50, "type": "force"}], false, "test")
	assert_false(e.legendary.phases.is_active(raum, "demon_of_secrets"), "five is not enough")
	e.deal_damage(null, crows[5], [{"amount": 50, "type": "force"}], false, "test")
	assert_true(e.legendary.phases.is_active(raum, "demon_of_secrets"))
