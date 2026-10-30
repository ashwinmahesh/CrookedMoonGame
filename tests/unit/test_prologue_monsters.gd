extends TestCase
## The prologue's four monsters (package R10, section 10; vault Build/D2 notes): what the engine runs from their data
## alone, with no game code. The Locomotive's phase, its echoes going with it, the Stoker's Soul Burn and the haint's
## resistances. The parts that need the bestiary's own code (the bottle trap, Corpse Fuel, Soul Fuel, Ghostly Rails)
## are tested with it.

const LOCOMOTIVE_SWITCH := "phantom_in_the_machine"


## A field big enough for a Gargantuan engine (4 x 4 squares) and four heroes.
func _field() -> Encounter:
	var rows: Array[String] = []
	for z in 14:
		rows.append("....................")
	var e := TestCombat.encounter(rows, 3)
	e.default_player_reaction = "never"
	return e


func _hurt(e: Encounter, c: Combatant, amount: int, type: String = "force") -> void:
	e.deal_damage(null, c, [{"amount": amount, "type": type}], false, "test")


static func _has_action(c: Combatant, id: String) -> bool:
	for a: Variant in MonsterActions.data_of(c).get("actions", []):
		if str((a as Dictionary)["id"]) == id:
			return true
	return false


func test_the_prologue_blocks_are_the_books_numbers() -> void:
	var expected := {"wayward_haint": [11, 13], "soulfire_stoker": [14, 59], "wildpyre": [14, 58],
		"wildpyre_large": [14, 58], "ghostlight_locomotive": [15, 94]}
	for id: String in expected:
		var m := TestCombat.monster(id)
		assert_eq(m.ac_value(), int((expected[id] as Array)[0]), "%s's Armor Class" % id)
		assert_eq(m.max_hp(), int((expected[id] as Array)[1]), "%s's Hit Points" % id)


func test_a_haint_shrugs_off_weapons_and_not_radiant() -> void:
	var haint := TestCombat.monster("wayward_haint")
	for type: String in ["slashing", "piercing", "bludgeoning", "fire", "cold"]:
		assert_true(haint.resistance_source(StringName(type)) != "", "resists %s" % type)
	assert_eq(haint.resistance_source(&"radiant"), "", "radiant is the answer to a haint")
	assert_true(haint.immunity_source(&"poison") != "", "immune to poison")


func test_the_locomotive_switches_once_when_bloodied() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(12, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 3)
	TestCombat.start_with(e, hero)
	assert_false(_has_action(engine, "multiattack"), "no Multiattack in the first phase")
	engine.set_meta("legendary_resistance_used", 2)
	_hurt(e, engine, 40)
	assert_false(e.legendary.phases.is_active(engine, LOCOMOTIVE_SWITCH), "54 of 94 is not Bloodied")
	_hurt(e, engine, 10)
	assert_true(e.legendary.phases.is_active(engine, LOCOMOTIVE_SWITCH), "44 of 94 is Bloodied: the Crooked Switch")
	assert_true(_has_action(engine, "multiattack"), "two Rail Slams a turn from now on")
	assert_eq(int(engine.get_meta("legendary_resistance_used", 0)), 0, "its Legendary Resistance comes back")
	assert_true(bool(e.legendary.story_flags.get("gl_locomotive_switched", false)), "the cutscene's sting is told to the story")
	engine.set_meta("legendary_resistance_used", 1)
	_hurt(e, engine, 5)
	assert_eq(int(engine.get_meta("legendary_resistance_used", 0)), 1, "the Switch happens once")


func test_the_locomotives_echoes_go_with_it() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(12, 5))
	var echo := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(8, 9))
	echo.set_meta("summoner", engine.id)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 3)
	TestCombat.start_with(e, hero)
	_hurt(e, engine, 400)
	assert_true(engine.creature.dead, "the engine falls")
	assert_eq(str(e.legendary.departed.get(echo.id, "")), "vanish", "and the echo it held goes with it")


func test_the_stokers_soul_burn_scorches_whoever_stands_close() -> void:
	var e := _field()
	var stoker := e.add(TestCombat.monster("soulfire_stoker"), &"enemy", Vector2i(6, 5))
	var near := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 5), 3)
	var far := TestCombat.hero(e, "ilse_varga", Vector2i(12, 9), 3)
	TestCombat.start_with(e, stoker)
	var near_hp := near.creature.hp
	var far_hp := far.creature.hp
	e.end_turn()
	assert_true(near.creature.hp < near_hp, "5 ft from the stoker at the end of its turn: Necrotic damage")
	assert_eq(far.creature.hp, far_hp, "out of reach: untouched")
