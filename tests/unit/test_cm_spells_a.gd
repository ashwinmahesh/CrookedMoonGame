extends TestCase
## The Crooked Moon's spells Ancestral Communion to Harvest Moonglow (CmSpellsA): what each does in a fight beyond its
## data, cast with the real data by a level 9 caster that knows them.


func _part(e: Encounter) -> CmSpellsA:
	return (e.game as CrookedFeatures).owner_of("sa_anything") as CmSpellsA


func _order(e: Encounter, first: Combatant, rest: Array) -> void:
	e.shared_turns = false
	TestCombat.start_with(e, first)
	var init := 20
	for x: Variant in rest:
		(x as Combatant).initiative = init
		init -= 1
	e.order.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.initiative > b.initiative)


func _cast(e: Encounter, c: Combatant, id: String, slot: int, targets: Array = [], point: Vector2 = Vector2.INF, opts: Dictionary = {}) -> CombatResult:
	c.action_available = true
	c.bonus_available = true
	c.magic_action_used = false
	c.cast_slot_spell_this_turn = false
	var r := e.spells.cast(c, id, slot, targets, point, Vector2.ZERO, opts)
	while e.pending != null:
		r = e.answer_reaction(true)
	return r


func _logged(e: Encounter, words: String) -> bool:
	return e.log.texts().any(func(t: String) -> bool: return t.contains(words))


func test_ancestral_communion_inspires_on_the_cast_and_each_turn() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["ancestral_communion"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3), 500)
	_order(e, c, [foe])
	var ch := c.creature as Character
	ch.heroic_inspiration = false
	assert_true(_cast(e, c, "ancestral_communion", 1).ok)
	assert_true(ch.heroic_inspiration, "Heroic Inspiration as it's cast")
	ch.heroic_inspiration = false
	e.end_turn()
	e.end_turn()
	assert_eq(e.current(), c)
	assert_true(ch.heroic_inspiration, "and again as the caster's turn starts")


func test_blood_bolt_gives_temp_hp_equal_to_the_proficiency_bonus_on_a_hit() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["blood_bolt"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3), 500)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 18)
	assert_true(_cast(e, c, "blood_bolt", 0, [foe]).ok)
	assert_true(foe.creature.hp < 500, "1d6+ Necrotic")
	assert_eq(c.creature.temp_hp, c.creature.proficiency_bonus(), "Temporary Hit Points = PB, not the dice")


func test_blood_sacrifice_hurts_through_temp_hp_then_adds_dice_to_one_target() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["blood_sacrifice", "blood_bolt"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3), 500)
	TestCombat.start_with(e, c)
	c.creature.add_temp_hp(20, "test")
	var hp := c.creature.hp
	assert_true(_cast(e, c, "blood_sacrifice", 3).ok)
	assert_true(c.creature.hp < hp, "the Necrotic goes past Temporary Hit Points")
	assert_eq(c.creature.temp_hp, 20, "which are left as they were")
	assert_true(hp - c.creature.hp <= 12, "2d6 with a level 3 slot")
	assert_true(c.creature.has_flag("blood_sacrifice"))
	TestCombat.next_d20(e, 18)
	assert_true(_cast(e, c, "blood_bolt", 0, [foe]).ok)
	var blows := e.log.texts().filter(func(t: String) -> bool: return t.contains("hits %s for" % foe.name()))
	assert_eq(blows.size(), 2, "the bolt, then Blood Sacrifice's 2d6 on its one target: %s" % [blows])


func test_buried_alive_buries_and_the_buried_dig_out_prone() -> void:
	var e := TestCombat.open_field(1)
	e.outdoors = true
	var c := TestCombat.caster_with(e, ["buried_alive"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "buried_alive", 4, [foe]).ok)
	assert_true(foe.creature.has_condition(&"restrained") and foe.creature.has_condition(&"blinded"), "Restrained and Blinded")
	assert_false(e.can_see(c, foe), "Total Cover: out of sight and reach")
	var part := _part(e)
	TestCombat.next_d20(e, 20)
	part._dig(foe)
	assert_true(CmSpellsA._grave(foe) != null, "20 - 5 = 15 meets DC 15: 5 ft up, not out")
	assert_eq(int(CmSpellsA._grave(foe).data["sa_depth"]), 5)
	TestCombat.next_d20(e, 20)
	part._dig(foe)
	assert_true(CmSpellsA._grave(foe) == null, "out of the grave")
	assert_true(foe.creature.has_condition(&"prone") and not foe.creature.has_condition(&"restrained"), "out Prone")


func test_buried_alive_fails_on_a_floor_and_air_runs_out() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["buried_alive"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(8, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "buried_alive", 4, [foe]).ok)
	assert_true(CmSpellsA._grave(foe) == null, "indoors the floor holds: an automatic success")
	assert_true(foe.creature.has_condition(&"prone"), "Prone all the same")
	e.outdoors = true
	foe.creature.remove_condition(&"prone")
	assert_true(_cast(e, c, "buried_alive", 4, [foe]).ok)
	var grave := CmSpellsA._grave(foe)
	assert_true(grave != null)
	grave.data["sa_turns"] = CmSpellsA._breath_turns(foe)
	_part(e)._grave_turn_end(foe)
	assert_eq(foe.creature.exhaustion, 1, "out of breath: Exhaustion")
	_part(e)._surface(foe, grave)
	assert_eq(foe.creature.exhaustion, 0, "and it goes when it can breathe")


func test_call_of_the_wild_commands_beasts_one_turn_at_a_time() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["call_of_the_wild"], Vector2i(2, 3))
	var wolf := TestCombat.punching_bag(e, Vector2i(5, 3), 500, "beast")
	var man := TestCombat.punching_bag(e, Vector2i(5, 5), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "call_of_the_wild", 4).ok)
	assert_true(CmSpellsA._wild_hold(wolf) != null, "the Beast fails and is held")
	assert_eq(wolf.side, &"guest", "on the caster's side")
	assert_true(wolf.creature.effects.all(func(fx: Effect) -> bool: return fx.repeat_save.is_empty()), "no save when it's hurt")
	assert_false(man.creature.has_condition(&"charmed"), "a Humanoid doesn't answer")
	var part := _part(e)
	part._wild_turn_start(wolf)
	assert_false(wolf.creature.has_condition(&"incapacitated"), "its first turn follows the cast's command")
	part._wild_turn_start(wolf)
	assert_true(wolf.creature.has_condition(&"incapacitated"), "without a new command it waits")
	var a := e.spells.sustained_for(c, "call_of_the_wild")
	assert_false(a.is_empty(), "the Magic action to command")
	var d := {"mode": "sa_call_of_the_wild"}
	part.sustained(c, a, d, {}, [], Vector2.INF, Vector2.ZERO, CombatResult.new())
	assert_true(bool(wolf.get_meta("sa_wild_orders")), "a new command for its next turn")


func test_captivate_undead_charms_through_immunity_and_ends_when_hurt() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["captivate_undead"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var ghoul := e.add(TestChars.dummy(500, false, {"type": "undead", "ac": 1, "condition_immunities": ["charmed"],
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}}), &"enemy", Vector2i(6, 3))
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "captivate_undead", 1, [ghoul]).ok)
	assert_true(ghoul.creature.has_condition(&"charmed"), "Charmed despite its immunity")
	assert_true(ghoul.creature.has_flag("friendly:%s" % c.id), "and Friendly to the caster")
	e.deal_damage(ally, ghoul, [{"amount": 3, "type": "slashing"}], false, "test")
	assert_true(c.creature.concentration == null, "an ally's blow ends the spell")
	assert_false(ghoul.creature.has_condition(&"charmed"))


func test_captivate_undead_success_spoils_the_next_attack_on_the_caster_only() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["captivate_undead"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 4))
	var ghoul := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	ghoul.creature.creature_type = &"undead"
	TestCombat.start_with(e, c)
	var fx := Effect.new("Captivate Undead", &"spell", "captivate_undead").with_modifier("flag", {"value": "sa_wary_of:%s" % c.id})
	ghoul.creature.add_effect(fx)
	var opt := e.attack_options(ghoul)[0] as Dictionary
	var vs_ally := e.attack_situation(ghoul, ally, opt)
	assert_false((vs_ally["disadvantage"] as Array).has("Captivate Undead"), "not against an ally")
	var vs_caster := e.attack_situation(ghoul, c, opt)
	assert_true((vs_caster["disadvantage"] as Array).has("Captivate Undead"), "against the caster")
	ghoul.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, Breakdown.new("x"), 10, ["attack", "target:%s" % ally.id])
	assert_true(fx in ghoul.creature.effects, "an attack on someone else leaves it")
	ghoul.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, Breakdown.new("x"), 10, ["attack", "target:%s" % c.id])
	assert_false(fx in ghoul.creature.effects, "used up by the roll against the caster")


func test_chain_of_conviction_gives_advantage_and_holds_within_30_ft() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["chain_of_conviction"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(7, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "chain_of_conviction", 2, [foe]).ok)
	assert_true(foe.creature.has_flag("chained:%s" % c.id), "bound by the chain")
	assert_true(e.distance(c, foe) < 25, "pulled toward the caster")
	var sit := e.attack_situation(c, foe, e.attack_options(c)[0] as Dictionary)
	assert_true((sit["advantage"] as Array).has("Chain of Conviction"))
	var blocked := _part(e).barrier_cells(foe)
	assert_true(blocked.has(Vector2i(11, 3)), "45 ft from the caster: out of bounds")
	assert_false(blocked.has(Vector2i(6, 3)), "20 ft: fine")


func test_consuming_pyre_burns_each_turn_and_smothering_ends_it() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["consuming_pyre"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	_order(e, c, [foe])
	assert_true(_cast(e, c, "consuming_pyre", 4, [foe], Vector2.INF, {"choice": "radiant"}).ok)
	var fx := CmSpellsA._pyre(foe)
	assert_true(fx != null, "the flames linger")
	assert_eq(str(fx.data["sa_pyre_type"]), "radiant")
	var hp := foe.creature.hp
	e.end_turn()
	assert_eq(e.current(), foe)
	assert_true(foe.creature.hp <= hp - 4, "Fire and Radiant again as its turn starts")
	assert_true(_logged(e, "Consuming Pyre"))
	fx.repeat_save["dc"] = -20
	_part(e)._smother(foe, foe, true)
	assert_true(CmSpellsA._pyre(foe) == null, "a success puts it out")
	assert_true(c.creature.concentration == null, "and ends the spell")


func test_consuming_pyre_leaves_ash() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["consuming_pyre"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 3)
	TestCombat.punching_bag(e, Vector2i(9, 6), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "consuming_pyre", 4, [foe]).ok)
	assert_true(foe.creature.dead and foe.has_meta("sa_ash"), "killed by it: ash")


func test_creeping_rot_leaps_only_30_ft_from_the_first() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["creeping_rot"], Vector2i(0, 3))
	var a := TestCombat.punching_bag(e, Vector2i(3, 3), 500)
	var b := TestCombat.punching_bag(e, Vector2i(6, 3), 500)
	var far := TestCombat.punching_bag(e, Vector2i(11, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "creeping_rot", 3, [a, b, far]).ok)
	assert_true(a.creature.hp < 500 and b.creature.hp < 500, "the first and one 15 ft on")
	assert_eq(far.creature.hp, 500, "40 ft from the first: no tendril")
	assert_true(a.creature.has_condition(&"poisoned"))


func test_crimson_harvest_heals_an_ally_half_the_roll() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["crimson_harvest"], Vector2i(4, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(4, 4))
	TestCombat.start_with(e, c)
	ally.creature.hp = 5
	assert_true(_cast(e, c, "crimson_harvest", 3).ok)
	var lost := 500 - foe.creature.hp
	assert_true(lost > 0)
	assert_true(ally.creature.hp > 5, "the ally in the wave is healed")
	assert_true(ally.creature.hp - 5 <= 15, "half of 3d10")
	assert_eq(ally.creature.hp, 5 + lost / 2, "half the roll the failed save took whole")


func test_crooked_ward_torments_only_twisted_creatures() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["crooked_ward"], Vector2i(2, 3))
	var ghost := TestCombat.punching_bag(e, Vector2i(4, 3), 500, "undead")
	var man := TestCombat.punching_bag(e, Vector2i(4, 4), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "crooked_ward", 3, [], Vector2(3.5, 3.5)).ok)
	var inside := func(t: Combatant) -> bool: return t.creature.effects.any(func(fx: Effect) -> bool: return fx.stack_key.begins_with("zone:"))
	assert_true(inside.call(ghost), "an Undead has Disadvantage on checks and attacks")
	assert_false(inside.call(man), "a Humanoid doesn't")
	assert_false(inside.call(c), "nor the caster")


func test_culling_sickle_gives_half_its_damage_as_temp_hp() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["culling_sickle"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(7, 3), 500)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 18)
	assert_true(_cast(e, c, "culling_sickle", 3, [foe]).ok, "a creature 25 ft away")
	var dealt := 500 - foe.creature.hp
	assert_true(dealt > 0)
	assert_eq(c.creature.temp_hp, dealt / 2, "half the damage dealt")
	assert_false(e.spells.sustained_for(c, "culling_sickle").is_empty(), "and the Bonus Action strike after")


func test_cursed_cacophony_resaves_on_the_first_failure_each_turn() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["cursed_cacophony"], Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "cursed_cacophony", 3, [foe]).ok)
	var fx := CmSpellsA._fx(foe, "cursed_cacophony")
	assert_true(fx != null, "cursed")
	assert_false(foe.creature.modifiers_for(&"disadvantage").is_empty(), "Disadvantage on D20 Tests")
	fx.repeat_save["dc"] = 99
	foe.creature.roll_check(e.dice, &"athletics", 99)
	assert_true(_logged(e, "can't shake the music"), "a failed roll: a save again, failed")
	var tries := e.log.texts().filter(func(t: String) -> bool: return t.contains("Cursed Cacophony")).size()
	foe.creature.roll_check(e.dice, &"athletics", 99)
	assert_eq(e.log.texts().filter(func(t: String) -> bool: return t.contains("Cursed Cacophony")).size(), tries, "only the first failure of a turn")
	foe.remove_meta("sa_cacophony_turn")
	fx.repeat_save["dc"] = -20
	foe.creature.roll_check(e.dice, &"athletics", 99)
	assert_false(fx in foe.creature.effects, "a success ends it")
	assert_true(c.creature.concentration == null)


func test_devils_due_heals_with_a_hit_die_when_someone_near_is_hurt() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["devils_due"], Vector2i(2, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3), 500)
	TestCombat.start_with(e, c)
	c.reaction_rules["devils_due"] = "auto"
	c.creature.hp = 5
	var ch := c.creature as Character
	var slots := ch.slots_left(1)
	e.deal_damage(foe, ally, [{"amount": 4, "type": "slashing"}], true, "test")
	assert_true(e.reaction_queue.any(func(q: Dictionary) -> bool: return str(q["kind"]) == "gm_sa_devils_due" and bool(q["crit"])), "queued, a Critical Hit noted")
	e.run_reaction_queue(CombatResult.new())
	assert_true(c.creature.hp > 5, "a Hit Point Die and the modifier, doubled")
	assert_eq(ch.slots_left(1), slots - 1, "a level 1 slot")
	assert_false(c.reaction_available)
	var spent := 0
	for die: String in ch.hit_dice():
		spent += int((ch.hit_dice()[die] as Dictionary)["spent"])
	assert_eq(spent, 1, "one Hit Point Die")


func test_eye_burn_answers_an_attack_before_the_roll() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["eye_burn"], Vector2i(2, 3))
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, foe)
	c.reaction_rules["eye_burn"] = "auto"
	# Burned once already: it passes the save, so the attack takes −1d4 instead.
	_part(e)._mark_eye_burn_resisted(foe, c)
	var opt := str((e.attack_options(foe)[0] as Dictionary)["id"])
	var r := e.attack(foe, c, opt)
	while e.pending != null:
		r = e.answer_reaction(true)
	assert_false(c.reaction_available, "Eye Burn took the Reaction before the roll")
	assert_true(_logged(e, "takes −1d4"), "a success: −1d4 on the attack")
	assert_true(foe.creature.modifiers_for(&"penalty_die").is_empty(), "the −1d4 used up by that roll")
	assert_false(foe.creature.has_condition(&"blinded"))


func test_eye_burn_failed_save_blinds_and_gives_disadvantage() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["eye_burn"], Vector2i(2, 3))
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, foe)
	var dis: Array[String] = []
	TestCombat.next_d20(e, 1)
	_part(e)._eye_burn(c, foe, dis)
	assert_true(foe.creature.has_condition(&"blinded"), "Blinded to the end of the turn")
	assert_true(dis.has("Eye Burn (Blinded)"), "so the attack about to be rolled has Disadvantage")
	assert_true(CmSpellsA._resists_eye_burn(foe, c), "it passes the caster's next one for 24 hours")
	e.end_turn()
	assert_false(foe.creature.has_condition(&"blinded"), "gone as the turn ends")



func test_eye_burn_resistance_lasts_into_the_next_fight_that_day() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["eye_burn"], Vector2i(2, 3))
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, foe)
	var dis: Array[String] = []
	TestCombat.next_d20(e, 1)
	_part(e)._eye_burn(c, foe, dis)
	# A new fight later that day, the same two creatures.
	var e2 := TestCombat.open_field(2)
	var c2 := e2.add(c.creature, &"party", Vector2i(2, 3))
	var foe2 := e2.add(foe.creature, &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e2, foe2)
	assert_true(CmSpellsA._resists_eye_burn(foe2, c2), "the 24 hours are on the creature, not the fight")
	foe2.creature.remove_condition(&"blinded")
	foe2.creature.remove_effects_named("Blinded (Eye Burn)")
	var dis2: Array[String] = []
	TestCombat.next_d20(e2, 1)
	_part(e2)._eye_burn(c2, foe2, dis2)
	assert_false(foe2.creature.has_condition(&"blinded"), "it succeeds automatically, even rolling a 1")
	assert_true(dis2.is_empty())
	foe2.creature.advance_minutes(24 * 60)
	assert_false(CmSpellsA._resists_eye_burn(foe2, c2), "and it wears off after 24 hours")


func test_field_of_reaping_reaps_the_first_damage_and_heals_an_ally() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["field_of_reaping"], Vector2i(1, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(7, 3), 500)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(8, 3))
	_order(e, c, [foe, ally])
	assert_true(_cast(e, c, "field_of_reaping", 5, [], Vector2(6.0, 3.5)).ok)
	assert_true(foe.creature.has_flag("reaped:%s" % c.id), "cursed as the field appears")
	assert_false(ally.creature.has_flag("reaped:%s" % c.id), "not the caster's side")
	ally.creature.hp = 5
	e.deal_damage(c, foe, [{"amount": 2, "type": "slashing"}], false, "test")
	assert_true(foe.creature.hp < 498, "an extra 1d6 Necrotic")
	assert_eq(ally.creature.hp, 5 + (498 - foe.creature.hp), "the ally regains the Necrotic it took")
	var hp := foe.creature.hp
	e.deal_damage(c, foe, [{"amount": 2, "type": "slashing"}], false, "test")
	assert_eq(foe.creature.hp, hp - 2, "only the first damage in a turn")
	e.end_turn()
	assert_eq(e.current(), foe)
	e.end_turn()
	assert_true(foe.creature.has_flag("reaped:%s" % c.id), "ending its turn there curses it again")


func test_harvest_moonglow_lets_allies_in_the_light_absorb_it() -> void:
	var e := TestCombat.open_field(1)
	var c := TestCombat.caster_with(e, ["harvest_moonglow"], Vector2i(1, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	TestCombat.punching_bag(e, Vector2i(11, 7), 500)
	TestCombat.start_with(e, c)
	assert_true(_cast(e, c, "harvest_moonglow", 4, [], Vector2(5.5, 3.5)).ok)
	var mine: Array[Dictionary] = []
	_part(e).list(c, mine, "", "")
	assert_true(mine.is_empty(), "not for the caster")
	var theirs: Array[Dictionary] = []
	_part(e).list(ally, theirs, "", "")
	assert_eq(theirs.size(), 1)
	assert_eq(str(theirs[0]["sub"]), "3d6 Temporary Hit Points", "2d6 and 1d6 for the level 4 slot")
	ally.bonus_available = true
	assert_true(_part(e).perform(ally, "sa_moonglow", null, Vector2i.ZERO, Vector2.INF).ok)
	assert_true(ally.creature.temp_hp >= 3)
	assert_false(ally.bonus_available, "a Bonus Action")
