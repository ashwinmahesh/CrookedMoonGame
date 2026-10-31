extends TestCase
## The Banjo of Ol' Jericho Sticks and the Scythe of the Harvest Terror (R13): the powers that need the game's code.


func _fight(item: String) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 8)
	(hero.creature as Character).add_item(item, 1)
	(hero.creature as Character).attune(item)
	if item.begins_with("scythe"):
		(hero.creature as Character).equip(item, "main_hand")
	var foe := e.add(TestCombat.monster("corvodaemon"), &"enemy", Vector2i(6, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, foe]


func test_the_banjo_charms_a_demon_through_its_immunity() -> void:
	var got := _fight("jericho_banjo")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	foe.creature.base_condition_immunities.append("charmed")
	assert_eq(e.items.power_why(hero, e.items.find_power(hero, "jericho_banjo", "charm")), "")
	for i in 30:
		if foe.creature.has_condition(&"charmed"):
			break
		hero.action_available = true
		(e.items.find_power(hero, "jericho_banjo", "charm")["entry"] as Dictionary).erase("uses")
		assert_true(e.items.use(hero, "jericho_banjo", "charm", [foe]).ok)
	assert_true(foe.creature.has_condition(&"charmed"), "charmed even though immune")


func test_the_banjo_dance_disengages() -> void:
	var got := _fight("jericho_banjo")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	assert_true(e.items.use(hero, "jericho_banjo", "dance").ok)
	assert_true(hero.disengaged)
	assert_false(hero.bonus_available)


func test_the_scythe_steps_to_a_frightened_creature_only() -> void:
	var got := _fight("scythe_of_the_harvest_terror")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var power := e.items.find_power(hero, "scythe_of_the_harvest_terror", "step")
	assert_eq(e.items.power_why(hero, power), "No Frightened creature within 60 ft")
	foe.creature.add_condition(&"frightened", "test")
	assert_eq(e.items.power_why(hero, power), "")
	assert_true(e.items.use(hero, "scythe_of_the_harvest_terror", "step").ok)
	assert_true(e.distance(hero, foe) <= 5, "beside it now")


func test_the_banjo_traps_what_it_charmed() -> void:
	var got := _fight("jericho_banjo")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var power := e.items.find_power(hero, "jericho_banjo", "trap")
	assert_eq(e.items.power_why(hero, power), "No creature charmed by the banjo within 30 ft")
	var fx := Effect.new("Charmed by the Banjo", &"item", "jericho_banjo").with_condition(&"charmed")
	fx.caster_id = hero.id
	foe.creature.add_effect(fx)
	assert_eq(e.items.power_why(hero, power), "")
	assert_true(e.items.use(hero, "jericho_banjo", "trap", [foe]).ok)
	assert_true(foe.creature.dead or str(foe.get_meta("left_fight", "")) == "vanish", "drawn out of the fight")


func test_the_scythe_hears_a_frightened_creatures_secret() -> void:
	var got := _fight("scythe_of_the_harvest_terror")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	foe.creature.add_condition(&"frightened", "test")
	assert_true(e.items.use(hero, "scythe_of_the_harvest_terror", "secret", [foe]).ok)
	assert_true(bool(e.legendary.story_flags.get("scythe_secret_corvodaemon", false)))
