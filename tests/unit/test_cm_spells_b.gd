extends TestCase
## The Crooked Moon's spells Harrowing Ballad to Veil of the Reaper (combat/crooked/cm_spells_b.gd): what each does in a
## fight that its data alone can't say.


func before_each() -> void:
	GameFeatures.use(null)


static func _part(e: Encounter) -> CmSpellsB:
	for p in (e.game as CrookedFeatures).parts:
		if p is CmSpellsB:
			return p as CmSpellsB
	return null


## A foe for spell tests whose Intelligence is `int_score` (other scores 1, AC 1).
static func _foe(e: Encounter, cell: Vector2i, kind: String = "humanoid", int_score: int = 1) -> Combatant:
	var m := TestChars.dummy(80, false, {"type": kind, "ac": 1,
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": int_score, "wis": 1, "cha": 1}})
	return e.add(m, &"enemy", cell)


static func _logged(e: Encounter, words: String) -> bool:
	return e.log.entries.any(func(x: Dictionary) -> bool: return str(x.get("text", "")).contains(words))


func _melee(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]):
			return str(o["id"])
	return ""


# --- Companions' spells -------------------------------------------------------------------------------------------

func test_summer_winds_heals_allies_and_burns_only_hostile_undead() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["summer_winds"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var undead := _foe(e, Vector2i(4, 3), "undead")
	var living := TestCombat.punching_bag(e, Vector2i(4, 4))
	TestCombat.start_with(e, c)
	var cells := e.spells.area_for(c, Compendium.shared().spell_data("summer_winds"), Vector2.INF, Vector2.RIGHT, 2)
	for who: Combatant in [ally, undead, living]:
		assert_true(who.cell in cells, "%s stands in the Cone" % who.name())
	ally.creature.hp = 1
	assert_true(e.spells.cast(c, "summer_winds", 2, [], Vector2.INF, Vector2.RIGHT).ok)
	assert_between(ally.creature.hp, 3, 13, "the ally regains 2d6 Hit Points")
	assert_between(undead.creature.hp, 68, 79, "the hostile Undead takes 2d6 Radiant (half on a save)")
	assert_eq(living.creature.hp, 80, "a living foe is untouched")


func test_lucky_charm_gives_the_carrier_advantage_and_the_caster_disadvantage() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["lucky_charm"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "lucky_charm", 5, [ally]).ok)
	assert_false(ally.creature.modifiers_for(&"advantage").is_empty(), "the carrier has Advantage on D20 Tests")
	assert_false(c.creature.modifiers_for(&"disadvantage").is_empty(), "the caster has Disadvantage on them")
	var t := ally.creature.roll_save(e.dice, &"wis", 10)
	assert_true(t.advantage, "a save of the carrier's rolls with Advantage")
	var t2 := c.creature.roll_save(e.dice, &"wis", 10)
	assert_true(t2.disadvantage, "a save of the caster's rolls with Disadvantage")
	c.creature.concentration.end("test")
	assert_false(ally.creature.modifiers_for(&"advantage").any(func(m: Modifier) -> bool: return m.source_id == "lucky_charm"), "both end with the spell")
	assert_false(c.creature.modifiers_for(&"disadvantage").any(func(m: Modifier) -> bool: return m.source_id == "lucky_charm"))


func test_puppet_master_upkeep_is_a_bonus_action_and_lapses_without_it() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["puppet_master"], Vector2i(2, 3))
	var puppet := TestCombat.punching_bag(e, Vector2i(4, 3))
	var other := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(c, "puppet_master", 4, [puppet], Vector2.INF, Vector2.ZERO, {"crown_victim": other.id}).ok)
	assert_true(puppet.creature.has_flag("crowned"), "the strings take hold")
	assert_eq(str(puppet.get_meta("crown_victim", "")), other.id)
	e.end_turn()
	while e.current() != c:
		e.end_turn()
	var keep := e.spells.sustained_for(c, "puppet_master")
	assert_eq(str(keep.get("cost", "")), "bonus_action", "keeping control costs a Bonus Action")
	assert_true(bool(keep["legal"]))
	assert_true(e.spells.use_sustained(c, str(keep["id"]), [other]).ok)
	assert_false(c.bonus_available, "the Bonus Action is spent")
	e.end_turn()
	assert_true(c.creature.concentration != null and c.creature.concentration.source_id == "puppet_master", "kept")
	while e.current() != c:
		e.end_turn()
	e.end_turn()
	assert_true(c.creature.concentration == null, "a turn without the Bonus Action ends it")


func test_puppet_master_walks_the_puppet_to_its_victim() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["puppet_master"], Vector2i(1, 3))
	var puppet := TestCombat.foe(e, "bandit", Vector2i(4, 3))
	var other := TestCombat.punching_bag(e, Vector2i(7, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(c, "puppet_master", 4, [puppet], Vector2.INF, Vector2.ZERO, {"crown_victim": other.id}).ok)
	e.end_turn()
	while e.current() != puppet:
		e.end_turn()
	var hp := other.creature.hp
	e.run_ai_turn()
	assert_true(e.distance(puppet, other) <= 5, "it walked up to the creature it must strike")
	assert_true(_logged(e, "Puppet Master"), "the marionette's attack is logged")
	assert_true(other.creature.hp < hp or _logged(e, "misses"), "it attacked")


func test_sacrificial_siphon_curses_and_feeds_the_caster_on_damage() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["sacrificial_siphon"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(c, "sacrificial_siphon", 4, [foe]).ok)
	assert_true(foe.creature.has_flag("sacrificial_siphon:" + c.id), "a failed Charisma save: cursed")
	assert_false(foe.creature.modifiers_for(&"penalty_die").is_empty(), "-1d4 on its attacks and checks")
	c.reaction_rules["sacrificial_siphon"] = "auto"
	e.deal_damage(ally, foe, [{"amount": 5, "type": "slashing"}], false, "Test")
	e.run_reaction_queue(CombatResult.new())
	assert_eq(c.creature.temp_hp, 10, "the Reaction gives 10 Temporary Hit Points")
	assert_false(c.reaction_available)


func test_sacrificial_siphon_on_a_success_gives_5_temporary_hit_points() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["sacrificial_siphon"], Vector2i(2, 3))
	var foe := _foe(e, Vector2i(3, 3))
	(foe.creature as Monster).data["abilities"] = {"cha": 30}
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 20)
	assert_true(e.spells.cast(c, "sacrificial_siphon", 4, [foe]).ok)
	assert_false(foe.creature.has_flag("sacrificial_siphon:" + c.id), "a success: not cursed")
	assert_eq(c.creature.temp_hp, 5)


func test_intrusive_despair_wastes_the_action_on_a_failed_save_and_ends_after_three_successes() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["intrusive_despair"], Vector2i(2, 3))
	var foe := TestCombat.foe(e, "bandit", Vector2i(5, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "intrusive_despair", 4, [foe]).ok)
	var part := _part(e)
	TestCombat.next_d20(e, 2)
	assert_true(part.despair_check(foe, "attack"), "a failed Wisdom save wastes the Attack action")
	for i in 3:
		foe.action_available = true
		TestCombat.next_d20(e, 20)
		assert_false(part.despair_check(foe, "magic"), "a success: the action goes ahead")
		assert_true(foe.action_available)
	assert_true(c.creature.concentration == null, "the third success ends the spell")
	assert_true(CmSpellsB._spell_fx(foe.creature, "intrusive_despair") == null)


func test_intrusive_despair_checks_a_monster_before_it_attacks() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["intrusive_despair"], Vector2i(2, 3))
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "intrusive_despair", 4, [foe]).ok)
	e.end_turn()
	while e.current() != foe:
		e.end_turn()
	var hp := c.creature.hp
	TestCombat.next_d20(e, 1)
	e.run_ai_turn()
	assert_true(_logged(e, "wastes its Attack action"), "the AI's Attack action meets the save first")
	assert_eq(c.creature.hp, hp, "no attack lands")


func test_intrusive_despair_wastes_a_heros_attack_and_magic_actions() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["intrusive_despair"], Vector2i(2, 3))
	var hero := TestCombat.high_caster(e, ["fire_bolt"], Vector2i(2, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 4))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "intrusive_despair", 4, [hero]).ok)
	(hero.creature as Character).heroic_inspiration = false
	e.end_turn()
	while e.current() != hero:
		e.end_turn()
	TestCombat.next_d20(e, 2)
	e.attack(hero, foe, _melee(e, hero))
	assert_false(hero.action_available, "a failed save wastes the Attack action")
	assert_eq(foe.creature.hp, 80, "no attack is made")
	assert_true(_logged(e, "wastes its Attack action"))
	hero.action_available = true
	hero.attacks_left = 0
	hero.cast_slot_spell_this_turn = false
	TestCombat.next_d20(e, 2)
	e.spells.cast(hero, "fire_bolt", 0, [foe])
	assert_false(hero.action_available, "and the Magic action")
	assert_eq(foe.creature.hp, 80, "the spell never goes off")
	assert_true(_logged(e, "wastes its Magic action"))


# --- The rest -----------------------------------------------------------------------------------------------------

func test_harrowing_ballad_leaves_low_intelligence_alone() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["harrowing_ballad"], Vector2i(2, 3))
	var beast := _foe(e, Vector2i(4, 3), "beast", 3)
	var thinker := _foe(e, Vector2i(5, 3), "humanoid", 10)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "harrowing_ballad", 2, [beast]).ok)
	assert_false(beast.creature.has_condition(&"charmed"), "Intelligence 3: unaffected")
	assert_true(_logged(e, "too simple"))
	c.bonus_available = true
	c.cast_slot_spell_this_turn = false
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(c, "harrowing_ballad", 2, [thinker]).ok)
	assert_true(thinker.creature.has_condition(&"charmed"), "Intelligence 10 and a failed save: Charmed")


func test_hungering_blade_adds_necrotic_once_a_turn_and_temporary_hit_points() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["hungering_blade"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "hungering_blade", 1, [], Vector2.INF, Vector2.ZERO, {"choice": "unarmed"}).ok)
	var mod := int(e.spells.numbers(c, e.spells._entry_any(c, "hungering_blade"))["mod"])
	assert_true(mod > 0)
	var unarmed := ""
	for o in e.attack_options(c):
		if str(o["kind"]) == "unarmed":
			unarmed = str(o["id"])
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, unarmed).hit)
	assert_true(_logged(e, "Hungering Blade"))
	assert_eq(c.creature.temp_hp, mod, "Temporary Hit Points equal to the Necrotic damage dealt")
	c.attacks_left = 1
	c.creature.temp_hp = 0
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, unarmed).hit)
	assert_eq(c.creature.temp_hp, 0, "only the first hit on a turn")


func test_isolation_hides_everyone_from_its_target() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["isolation"], Vector2i(2, 3))
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(c, "isolation", 3, [foe]).ok)
	assert_true(foe.creature.has_flag("isolated"))
	assert_false(e.can_see(foe, c), "it perceives no one")
	var opt := e.option_by_id(c, _melee(e, c))
	assert_false((e.attack_situation(c, foe, opt)["advantage"] as Array).is_empty(), "attacks on it have Advantage")
	var fopt := e.attack_options(foe)[0]
	assert_false((e.attack_situation(foe, c, fopt)["disadvantage"] as Array).is_empty(), "its attacks have Disadvantage")
	foe.creature.base_senses["blindsight"] = 30
	assert_true("Isolation" in (e.attack_situation(foe, c, fopt)["disadvantage"] as Array), "not even Blindsight helps")


func test_martyr_trades_the_casters_life_for_the_dead() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["martyr"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	ally.creature.hp = 0
	ally.creature.dead = true
	ally.set_meta("died_round", e.round_no)
	c.creature.hp = 23
	TestCombat.next_d20(e, 15)
	var mr := e.spells.cast(c, "martyr", 3, [ally])
	assert_true(mr.ok, "a dead creature is Martyr's target: %s" % mr.reason)
	assert_false(ally.creature.dead)
	assert_eq(ally.creature.hp, mini(23, ally.creature.max_hp()), "back with the caster's Hit Points")
	assert_eq(c.creature.hp, 0)
	assert_eq(c.creature.death_failures, 2, "two failed Death Saving Throws")
	assert_eq(c.creature.death_successes, 1, "and the one made at once (15) succeeded")


func test_mirrored_agony_turns_the_damage_back() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["mirrored_agony"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3))
	TestCombat.start_with(e, c)
	var slots := (c.creature as Character).slots_left(5)
	e.deal_damage(foe, ally, [{"amount": 7, "type": "slashing"}], false, "Test")
	var r := e.run_reaction_queue(CombatResult.new())
	assert_true(r.pending != null and e.pending != null, "the caster is asked")
	TestCombat.next_d20(e, 2)
	e.answer_reaction(true)
	assert_eq(foe.creature.hp, 73, "a failed Wisdom save: Psychic damage equal to the 7 dealt")
	assert_eq((c.creature as Character).slots_left(5), slots - 1, "a level 5 slot")
	assert_false(c.reaction_available)


func test_mist_of_mourning_takes_1d8_from_every_damage_roll() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["mist_of_mourning"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(7, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(c, "mist_of_mourning", 3, [], Vector2(7.5, 3.5)).ok)
	assert_false(foe.creature.modifiers_for(&"damage_penalty_die").is_empty(), "melancholy")
	ally.creature.hp = 100
	ally.creature.temp_hp = 0
	e.deal_damage(foe, ally, [{"amount": 20, "type": "fire", "spell": true}], false, "Test")
	assert_between(100 - ally.creature.hp, 12, 19, "a spell's damage loses 1d8")
	var before := ally.creature.hp
	e.deal_damage(foe, ally, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Test")
	assert_eq(before - ally.creature.hp, 10, "a weapon hit's parts were cut where it was rolled, not again here")


func test_murder_of_crows_blindness_ends_with_healing() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["murder_of_crows"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(e.spells.cast(c, "murder_of_crows", 4, [], Vector2.INF, Vector2.RIGHT).ok)
	assert_true(foe.creature.has_condition(&"blinded"))
	assert_between(foe.creature.hp, 50, 75, "5d6 Force")
	foe.creature.heal(1, "test")
	assert_false(foe.creature.has_condition(&"blinded"), "any Hit Points regained end it")


func test_sanguine_secrets_reads_the_creature_and_gives_one_advantage() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["sanguine_secrets"], Vector2i(2, 3))
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "sanguine_secrets", 2, [foe]).ok)
	assert_true(_logged(e, "reads Bandit's blood"))
	assert_true(e.studied.has("bandit"), "its defenses show")
	var opt := e.option_by_id(c, _melee(e, c))
	assert_true("Sanguine Secrets" in (e.attack_situation(c, foe, opt)["advantage"] as Array))
	e.hit_chance(c, foe, opt)
	assert_true("Sanguine Secrets" in (e.attack_situation(c, foe, opt)["advantage"] as Array), "a hit chance or a look doesn't use it up")
	TestCombat.next_d20(e, 10)
	e.attack(c, foe, _melee(e, c))
	assert_true(e.log.entries.any(func(x: Dictionary) -> bool: return str(x.get("details", [])).contains("Sanguine Secrets")), "the attack rolled with it")
	assert_false("Sanguine Secrets" in (e.attack_situation(c, foe, opt)["advantage"] as Array), "one attack only")


func test_scarlet_dawn_hurts_the_living_and_heals_undead_and_constructs() -> void:
	var e := TestCombat.open_field(4)
	# A wizard without the Evoker's Sculpt Spells, which would spare the ally.
	var c := TestCombat.high_caster(e, ["scarlet_dawn"], Vector2i(1, 1))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(6, 3))
	var undead := _foe(e, Vector2i(7, 3), "undead")
	var golem := _foe(e, Vector2i(7, 4), "construct")
	var living := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	undead.creature.hp = 40
	golem.creature.hp = 40
	ally.creature.hp = 60
	assert_true(e.spells.cast(c, "scarlet_dawn", 3, [], Vector2(7.5, 3.5)).ok)
	while e.pending != null:
		e.answer_reaction(false)
	assert_between(undead.creature.hp, 44, 80, "Undead regain 4d10")
	assert_between(golem.creature.hp, 44, 80, "Constructs regain 4d10")
	assert_true(living.creature.hp < 80, "a living foe takes Necrotic")
	assert_true(ally.creature.hp < 60, "and so does a living ally")


func test_veil_of_the_reaper_hides_its_caster_after_a_hit() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["veil_of_the_reaper"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "veil_of_the_reaper", 2).ok)
	e.end_turn()
	assert_false(c.creature.has_condition(&"invisible"), "no hit, no veil")
	while e.current() != c:
		e.end_turn()
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, _melee(e, c)).hit)
	e.end_turn()
	assert_true(c.creature.has_condition(&"invisible"), "a hit this turn: Invisible")
	while e.current() != c:
		e.end_turn()
	assert_false(c.creature.has_condition(&"invisible"), "until the start of its next turn")


func test_mysterious_presence_makes_a_search_subtract_1d4() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["mysterious_presence"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var foe := TestCombat.foe(e, "bandit", Vector2i(8, 3))
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "mysterious_presence", 0, [ally]).ok)
	assert_false(ally.creature.modifiers_for(&"perceived_penalty_die").is_empty(), "shrouded")
	e.end_turn()
	while e.current() != foe:
		e.end_turn()
	ally.hidden = true
	ally.stealth_total = 30
	assert_true(e.search(foe).ok)
	assert_true(_logged(e, "hard to make out"), "the search subtracts the die to find the shrouded hero")
