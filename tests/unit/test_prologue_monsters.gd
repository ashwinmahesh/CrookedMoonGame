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


# --- The bestiary's own code (combat/bestiary/bestiary_features.gd, a part of CrookedFeatures) -------------------------

func test_the_bestiary_is_a_part_of_the_games_features() -> void:
	var e := _field()
	assert_true(e.game is CrookedFeatures, "the game names its features module")
	assert_true((e.game as CrookedFeatures).parts.any(func(p: GameFeatures) -> bool: return p is BestiaryFeatures), "and the bestiary is in it")


func test_a_hostile_haints_first_turn_is_a_wail() -> void:
	var e := _field()
	var haint := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(5, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 1)
	TestCombat.start_with(e, haint)
	var hp := hero.creature.hp
	e.ai.play_turn(haint)
	assert_eq(hero.creature.hp, hp, "the first turn hurts no one")
	assert_true(haint.has_meta(BestiaryFeatures.WAILED_META), "it wailed")
	e.end_turn()
	for c in e.order:
		if c != haint and c != hero:
			e.end_turn()
	assert_true(e.current() == haint or e.current() == hero, "the round came round")


func test_draining_regret_stops_at_five_levels_and_remembers_them() -> void:
	var e := _field()
	var haint := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(5, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 1)
	TestCombat.start_with(e, hero)
	var rd := {"do": "exhaustion", "params": {"levels": 1, "max": 5, "until": "rest"}}
	hero.creature.exhaustion = 3
	for i in 4:
		e.monster_actions._rider(haint, hero, rd, {}, "Draining Regret")
	assert_eq(hero.creature.exhaustion, 5, "never past 5")
	assert_eq(int(hero.creature.get_meta(BestiaryFeatures.REST_EXHAUSTION_META, 0)), 2, "the two levels it gave are counted for the rest")


func test_the_stoker_burns_a_corpse_it_sees() -> void:
	var e := _field()
	var stoker := e.add(TestCombat.monster("soulfire_stoker"), &"enemy", Vector2i(12, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 12), 3)
	var dead := e.add(TestCombat.monster("ghost"), &"enemy", Vector2i(9, 5))
	TestCombat.start_with(e, stoker)
	dead.creature.dead = true
	dead.creature.hp = 0
	e.ai.play_turn(stoker)
	assert_true(dead.has_meta(BestiaryFeatures.ASHED_META), "the body is ash")
	assert_true(e.distance(stoker, dead) <= 5, "the stoker went to it")


func test_a_can_eaten_feeds_the_locomotive_and_lets_out_an_echo() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(12, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 12), 3)
	var cans := BestiaryFeatures.place_soul_cans(e, [Vector2i(9, 6)] as Array[Vector2i])
	TestCombat.start_with(e, hero)
	_hurt(e, engine, 30)
	var before := engine.creature.hp
	e.end_turn()
	while e.current() != engine:
		e.end_turn()
	assert_true(cans[0].destroyed, "the can is gone")
	assert_eq(engine.creature.hp, before + 20, "20 Hit Points from it")
	var echoes := e.combatants.filter(func(c: Combatant) -> bool: return c.has_meta(BestiaryFeatures.ECHO_META))
	assert_eq(echoes.size(), 1, "an echo rose from it")
	assert_eq((echoes[0] as Combatant).creature.hp, 7, "at half Hit Points")
	assert_eq(str((echoes[0] as Combatant).get_meta("summoner")), engine.id, "and fights beside the engine")


func test_a_smashed_can_lets_out_an_echo_without_feeding_it() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(16, 9))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2), 3)
	var cans := BestiaryFeatures.place_soul_cans(e, [Vector2i(3, 2)] as Array[Vector2i])
	TestCombat.start_with(e, hero)
	e.objects.smash(cans[0], "smashed")
	var echoes := e.combatants.filter(func(c: Combatant) -> bool: return c.has_meta(BestiaryFeatures.ECHO_META))
	assert_eq(echoes.size(), 1, "the haint's echo")
	assert_eq(engine.creature.hp, engine.creature.max_hp(), "and the engine got nothing")


func test_ghostly_rails_grapples_whoever_the_locomotive_passes_through() -> void:
	var e := _field()
	# (100 ft of Speed, so that half of it covers the extra cost of crossing a creature's space: its whole body is inside the hero's square for four steps)
	var data := Compendium.shared().monster_data("ghostlight_locomotive").duplicate(true)
	(data["speed"] as Dictionary)["walk"] = 100
	var engine := e.add(Monster.from_data(data), &"enemy", Vector2i(14, 4))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(13, 5), 3)
	var far := TestCombat.hero(e, "ilse_varga", Vector2i(2, 12), 3)
	TestCombat.start_with(e, hero)
	var r := e.legendary.use(engine, "ghostly_rails", null, Vector2i(9, 4))
	assert_true(r.ok, "the rails run: %s" % r.reason)
	assert_true(engine.cell.x < 14, "the engine moved along them")
	assert_true(hero.creature.has_condition(&"grappled"), "the hero it passed through is held")
	assert_false(far.creature.has_condition(&"grappled"), "the far one is not")
