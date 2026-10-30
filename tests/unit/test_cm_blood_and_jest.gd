extends TestCase
## The Crooked Moon's Crimson Sorcery, Great Fool Patron and Circle of Wicker in a fight (combat/crooked/cm_blood_and_jest.gd):
## the Blood Well, the Pool of Blood, Killing Joke, Jester's Japes, Mocking Banter, the Bewitched Effigy and its auras,
## Wicker Rising, Wicker Tokens and the Soulbound Poppet.


func _part(e: Encounter) -> CmBloodAndJest:
	return (e.game as CrookedFeatures).owner_of("bj_") as CmBloodAndJest


func _field() -> Encounter:
	GameFeatures.use(null)
	return TestCombat.open_field(3)


func _hero(e: Encounter, class_id: String, sub: String, level: int, cell: Vector2i) -> Combatant:
	return e.add(TestChars.custom(class_id, "human", level, {"%s_subclass" % class_id: [sub]}), &"party", cell)


func _act(e: Encounter, c: Combatant, id: String, t: Combatant = null, point: Vector2 = Vector2.INF, choice: String = "") -> CombatResult:
	return e.feature_actions.perform(c, "gm:bj_" + id, t, point, choice)


func _at(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5)


func _logged(e: Encounter, words: String) -> bool:
	return e.log.entries.any(func(x: Dictionary) -> bool: return str(x["text"]).contains(words))


# --- Crimson Sorcery ----------------------------------------------------------------------------------------------

func test_blood_well_armed_adds_a_d8_to_one_blow_and_is_spent() -> void:
	var e := _field()
	var s := _hero(e, "sorcerer", "crimson_sorcery", 3, Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 80)
	var bag2 := TestCombat.punching_bag(e, Vector2i(6, 3), 80)
	TestCombat.start_with(e, s)
	var ch := s.creature as Character
	assert_eq(ch.resource_left("blood_well"), 1)
	assert_true(e.features.rider_options(s).any(func(o: Dictionary) -> bool: return str(o["id"]) == "bj_blood_well"), "armable on the hotbar")
	s.armed.append("bj_blood_well")
	e.deal_damage(s, bag, [{"amount": 5, "type": "fire"}], false, "Test")
	var lost := 80 - bag.creature.hp
	assert_true(lost >= 6 and lost <= 13, "5 + 1d8, got %d" % lost)
	assert_eq(ch.resource_left("blood_well"), 0)
	e.deal_damage(s, bag2, [{"amount": 5, "type": "fire"}], false, "Test")
	assert_eq(bag2.creature.hp, 75, "one target only")


func test_blood_well_refills_on_ten_necrotic_at_once() -> void:
	var e := _field()
	var s := _hero(e, "sorcerer", "crimson_sorcery", 3, Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 80)
	TestCombat.start_with(e, s)
	var ch := s.creature as Character
	ch.spend_resource("blood_well")
	e.deal_damage(s, bag, [{"amount": 9, "type": "necrotic"}], false, "Test")
	assert_eq(ch.resource_left("blood_well"), 0, "9 isn't enough")
	e.deal_damage(s, bag, [{"amount": 10, "type": "necrotic"}, {"amount": 3, "type": "fire"}], false, "Test")
	assert_eq(ch.resource_left("blood_well"), 1, "10 Necrotic at once fills it")


func test_blood_well_on_its_own_lifts_a_downed_ally_but_not_a_scratched_one() -> void:
	var e := _field()
	var s := _hero(e, "sorcerer", "crimson_sorcery", 3, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, s)
	var ch := s.creature as Character
	ally.creature.hp = ally.creature.max_hp() - 3
	var ctx := {"c": s, "s": Compendium.shared().spell_data("cure_wounds"), "slot": 1}
	assert_eq(_part(e).spell_healing(ctx, ally), 0, "Automatic keeps it for a downed ally")
	assert_eq(ch.resource_left("blood_well"), 1)
	ally.creature.hp = 0
	var extra := _part(e).spell_healing(ctx, ally)
	assert_true(extra >= 1 and extra <= 8, "1d8 more, got %d" % extra)
	assert_eq(ch.resource_left("blood_well"), 0)
	s.reaction_rules["blood_well"] = "never"
	ch.restore_resource("blood_well")
	assert_eq(_part(e).spell_healing(ctx, ally), 0, "Off never spends it")


func test_pool_of_blood_is_a_slow_slippery_shape_that_cant_attack() -> void:
	var e := _field()
	var s := _hero(e, "sorcerer", "crimson_sorcery", 6, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, s)
	var r := _act(e, s, "pool_of_blood")
	assert_true(r.ok, r.reason)
	assert_true(e.shapes.is_shaped(s))
	assert_false(s.bonus_available)
	assert_eq((e.shapes.original(s) as Character).resource_left("blood_well"), 0)
	var pool := s.creature
	assert_eq(pool.speed().total(), 10)
	assert_eq(pool.speed("climb").total(), 10)
	assert_eq(pool.speed("swim").total(), 10)
	for ty: String in ["slashing", "piercing", "bludgeoning", "necrotic"]:
		assert_true(pool.resistance_source(StringName(ty)) != "", "resists %s" % ty)
	assert_true(pool.is_condition_immune(&"prone"))
	assert_true(pool.has_flag("enters_spaces"))
	assert_true(pool.has_flag("speechless"))
	assert_eq(pool.ac_value(), (e.shapes.original(s) as Character).ac_value(), "its own AC")
	TestCombat.next_d20(e, 5)
	var sv := pool.roll_save(e.dice, &"dex", 10)
	assert_true(sv.advantage, "Advantage on Dexterity saves")
	assert_true(e.attack_options(s).is_empty(), "no attacks as a pool")
	var bar := e.feature_actions.list(s)
	var leave := bar.filter(func(x: Dictionary) -> bool: return str(x["id"]) == "feat:gm:bj_end_pool")
	assert_eq(leave.size(), 1, "its own way out on the hotbar")
	assert_eq(str(leave[0]["cost"]), "free", "leaving takes no action")
	assert_false(bar.any(func(x: Dictionary) -> bool: return str(x["id"]) == "feat:cf:revert_shape"), "not the Bonus Action Wild Shape exit")
	var r2 := _act(e, s, "end_pool")
	assert_true(r2.ok, r2.reason)
	assert_false(e.shapes.is_shaped(s))
	(s.creature as Character).restore_resource("blood_well")
	s.bonus_available = true
	assert_true(_act(e, s, "pool_of_blood").ok)
	e.deal_damage(null, s, [{"amount": 9999, "type": "fire"}], false, "Test")
	assert_false(e.shapes.is_shaped(s), "it ends at 0 Hit Points")


# --- Great Fool Patron --------------------------------------------------------------------------------------------

func test_killing_joke_mocks_a_hurt_foe_but_not_a_hurt_ally() -> void:
	var e := _field()
	var w := _hero(e, "warlock", "great_fool_patron", 3, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(2, 5))
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, w)
	var ch := w.creature as Character
	var uses := ch.resource_left("killing_joke")
	assert_eq(uses, maxi(1, ch.ability_mod(&"cha")))
	e.deal_damage(bag, ally, [{"amount": 2, "type": "slashing"}], false, "Test")
	e.run_reaction_queue(CombatResult.new())
	assert_true(w.reaction_available, "Automatic never mocks an ally")
	e.deal_damage(ally, bag, [{"amount": 2, "type": "slashing"}], false, "Test")
	e.run_reaction_queue(CombatResult.new())
	assert_false(w.reaction_available)
	assert_eq(ch.resource_left("killing_joke"), uses - 1)
	assert_true(_logged(e, "Killing Joke"))
	assert_true(bag.creature.hp < 198, "Vicious Mockery bit (Wis 1 fails)")


func test_killing_joke_answers_a_failed_save_and_lets_a_saved_one_go() -> void:
	var e := _field()
	var w := _hero(e, "warlock", "great_fool_patron", 3, Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3), 200)
	TestCombat.start_with(e, w)
	e.class_features._save(bag, &"wis", 30, "Test")
	assert_eq(e.reaction_queue.size(), 1)
	(e.reaction_queue[0]["test"] as D20Test).success = true   # turned around afterwards (Legendary Resistance)
	e.run_reaction_queue(CombatResult.new())
	assert_true(w.reaction_available, "a save made after all")
	e.class_features._save(bag, &"wis", 30, "Test")
	e.run_reaction_queue(CombatResult.new())
	assert_false(w.reaction_available)
	assert_true(_logged(e, "Killing Joke"))


func test_jesters_japes_curses_on_a_failed_charisma_save() -> void:
	var e := _field()
	var w := _hero(e, "warlock", "great_fool_patron", 6, Vector2i(2, 3))
	var foe := TestCombat.foe(e, "scarecrow", Vector2i(6, 3))
	TestCombat.start_with(e, w)
	w.reaction_rules["killing_joke"] = "never"
	TestCombat.next_d20(e, 1)
	var r := _act(e, w, "japes:jolly_arms", foe)
	assert_true(r.ok, r.reason)
	assert_eq((w.creature as Character).resource_left("jesters_japes"), 0, "once per Short Rest")
	assert_true(foe.creature.has_flag("bj_jolly_arms"))
	var fx: Effect = foe.creature.effects.filter(func(x: Effect) -> bool: return x.source_id == "jesters_japes")[0]
	assert_eq(str(fx.repeat_save.get("ability", "")), "cha")
	assert_eq(fx.rounds_left, 10, "1 minute")
	var hp := w.creature.hp
	e.deal_damage(foe, w, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Claw")
	assert_eq(hp - w.creature.hp, 5, "Jolly Arms: half damage")
	# The other curses.
	var foe2 := TestCombat.foe(e, "scarecrow", Vector2i(6, 5))
	(w.creature as Character).restore_resource("jesters_japes")
	w.action_available = true
	w.magic_action_used = false
	var speed := foe2.creature.speed().total()
	TestCombat.next_d20(e, 1)
	assert_true(_act(e, w, "japes:clown_shoes", foe2).ok)
	assert_eq(foe2.creature.speed().total(), speed / 2)
	assert_true(foe2.creature.d20_sources(foe2.creature.save_keys(&"dex"))["disadvantage"].size() > 0, "Dexterity saves at Disadvantage")
	var foe3 := TestCombat.foe(e, "scarecrow", Vector2i(6, 6))
	(w.creature as Character).restore_resource("jesters_japes")
	w.action_available = true
	w.magic_action_used = false
	TestCombat.next_d20(e, 1)
	assert_true(_act(e, w, "japes:flower_spurt", foe3).ok)
	assert_true(foe3.creature.has_condition(&"blinded"))
	var foe4 := TestCombat.foe(e, "scarecrow", Vector2i(7, 6))
	(w.creature as Character).restore_resource("jesters_japes")
	w.action_available = true
	w.magic_action_used = false
	TestCombat.next_d20(e, 1)
	assert_true(_act(e, w, "japes:honk_honk", foe4).ok)
	assert_true(foe4.creature.has_flag("no_invisible"))


func test_mocking_banter_throws_the_hurt_back() -> void:
	var e := _field()
	var w := _hero(e, "warlock", "great_fool_patron", 10, Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, w)
	w.reaction_rules["killing_joke"] = "never"
	e.deal_damage(bag, w, [{"amount": 12, "type": "slashing"}], false, "Test")
	var r := e.run_reaction_queue(CombatResult.new())
	assert_true(r.pending != null and r.pending.title.contains("Mocking Banter"), "Ask: offered")
	e.answer_reaction(true)
	assert_eq(bag.creature.hp, 188, "Wis 1 fails: 12 Psychic")
	assert_eq((w.creature as Character).resource_left("mocking_banter"), 0)


# --- Circle of Wicker ---------------------------------------------------------------------------------------------

func test_effigy_is_an_object_foes_can_smash_and_it_lasts_a_minute() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 3, Vector2i(2, 3))
	var foe := TestCombat.foe(e, "scarecrow", Vector2i(8, 3))
	TestCombat.start_with(e, d)
	var uses := (d.creature as Character).resource_left("wild_shape")
	var r := _act(e, d, "effigy:ward", null, _at(Vector2i(4, 3)))
	assert_true(r.ok, r.reason)
	assert_eq((d.creature as Character).resource_left("wild_shape"), uses - 1)
	var eff := _part(e)._effigy_of(d)
	assert_true(eff != null)
	assert_eq(eff.creature.max_hp(), 15, "5 x Druid level")
	assert_eq(eff.creature.ac_value(), 15)
	assert_true(eff.creature.vulnerability_source(&"fire") != "")
	assert_true(eff.creature.immunity_source(&"psychic") != "")
	assert_true(eff.hostile_to(foe), "foes can attack it")
	assert_false(eff in e.order, "it takes no turns")
	assert_true(_part(e).target_weight(foe, eff) < 1.0, "a Ward effigy is worth less than a hero")
	assert_eq(str(e.spells.zones.spell_light(Vector2i(4, 8))["level"]), "dim", "its glow reaches 25 ft")
	var base := d.creature.effects.filter(func(x: Effect) -> bool: return x.stack_key.begins_with("bj_ward:")).size()
	assert_eq(base, 1, "the druid stands in its Ward")
	e.round_no += 10
	_part(e).turn_start(d)
	assert_false(eff.is_alive(), "gone after a minute")
	assert_eq(d.creature.effects.filter(func(x: Effect) -> bool: return x.stack_key.begins_with("bj_ward:")).size(), 0, "its Ward with it")


func test_ward_gives_plus_one_ac_only_in_the_aura() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 3, Vector2i(0, 0))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(1, 0))
	TestCombat.punching_bag(e, Vector2i(11, 7))
	TestCombat.start_with(e, d)
	var ac := ally.creature.ac_value()
	assert_true(_act(e, d, "effigy:ward", null, _at(Vector2i(2, 0))).ok)
	assert_eq(ally.creature.ac_value(), ac + 1)
	ally.cell = Vector2i(11, 0)
	_part(e).refresh_wards()
	assert_eq(ally.creature.ac_value(), ac, "outside the 30 ft")


func test_sacrifice_burns_a_hostile_creature_hurt_in_the_aura() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 3, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(2, 5))
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 100)
	TestCombat.start_with(e, d)
	assert_true(_act(e, d, "effigy:sacrifice", null, _at(Vector2i(4, 4))).ok)
	var eff := _part(e)._effigy_of(d)
	assert_eq(_part(e).target_weight(bag, eff), 1.1, "foes in a Sacrifice aura want it gone")
	e.deal_damage(ally, bag, [{"amount": 5, "type": "slashing"}], false, "Test")
	e.run_reaction_queue(CombatResult.new())
	var burn := 95 - bag.creature.hp
	var wis := d.creature.ability_mod(&"wis")
	assert_true(burn >= 1 + wis and burn <= 8 + wis, "1d8 + Wis Fire, got %d" % burn)
	assert_false(d.reaction_available)
	# Never an ally.
	d.reaction_available = true
	e.deal_damage(bag, ally, [{"amount": 1, "type": "slashing"}], false, "Test")
	assert_true(e.reaction_queue.is_empty(), "Sacrifice never strikes an ally")


func test_soothe_lifts_a_downed_ally_on_creation_and_counts_its_heals() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 6, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(2, 5))
	TestCombat.punching_bag(e, Vector2i(11, 7))
	TestCombat.start_with(e, d)
	ally.creature.hp = 0
	ally.creature.add_condition(&"unconscious", "0 Hit Points")
	assert_true(_act(e, d, "effigy:soothe", null, _at(Vector2i(3, 4))).ok)
	assert_true(ally.creature.hp >= 1 and ally.creature.hp <= 8, "1d8 at Wicker Rising")
	assert_false(ally.creature.has_condition(&"unconscious"))
	var eff := _part(e)._effigy_of(d)
	var most := 2 * maxi(1, d.creature.ability_mod(&"wis"))
	assert_eq(int(eff.get_meta("bj_soothe_left")), most - 1)
	# A later Bonus Action that also lifts Frightened for 5 of the effigy's Hit Points.
	d.reset_turn()
	ally.creature.add_condition(&"frightened", "Test")
	var hp := eff.creature.hp
	var r := _act(e, d, "soothe", ally)
	assert_true(r.ok, r.reason)
	assert_false(ally.creature.has_condition(&"frightened"))
	assert_eq(eff.creature.hp, hp - 5)
	assert_eq(int(eff.get_meta("bj_soothe_left")), most - 2)


func test_wicker_rising_sacrifice_two_d8_and_ward_resistance_of_choice() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 6, Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 100)
	TestCombat.start_with(e, d)
	assert_true(_act(e, d, "effigy:ward", null, _at(Vector2i(3, 3)), "cold").ok)
	assert_true(d.creature.resistance_source(&"cold") != "")
	# A second effigy ends the first.
	d.reset_turn()
	var first := _part(e)._effigy_of(d)
	assert_true(_act(e, d, "effigy:sacrifice", null, _at(Vector2i(3, 5))).ok)
	assert_false(first.is_alive())
	assert_eq(d.creature.resistance_source(&"cold"), "", "the old Ward is gone")
	e.deal_damage(d, bag, [{"amount": 1, "type": "slashing"}], false, "Test")
	e.run_reaction_queue(CombatResult.new())
	var burn := 99 - bag.creature.hp
	var wis := d.creature.ability_mod(&"wis")
	assert_true(burn >= 2 + wis and burn <= 16 + wis, "2d8 + Wis, got %d" % burn)


func test_wicker_tokens_go_to_the_party_and_carry_touch_spells() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 3, Vector2i(0, 0))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(11, 7))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, d)
	assert_true(bool(ally.get_meta(CmBloodAndJest.token_key(d), false)), "the ally carries a token")
	assert_false(foe.has_meta(CmBloodAndJest.token_key(d)))
	var cure := Compendium.shared().spell_data("cure_wounds")
	assert_true(_part(e).spell_reach(d, cure, ally), "Cure Wounds reaches across the field")
	assert_false(_part(e).spell_reach(d, cure, foe))
	assert_false(_part(e).spell_reach(d, Compendium.shared().spell_data("healing_word"), ally), "only touch spells")


func test_soulbound_poppet_handed_to_an_ally() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 10, Vector2i(2, 3))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(3, 3))
	var foe := TestCombat.foe(e, "scarecrow", Vector2i(7, 3))
	foe.creature.hp = 200
	TestCombat.start_with(e, d)
	var entry: Dictionary = e.feature_actions.list(d).filter(func(x: Dictionary) -> bool: return str(x["id"]) == "feat:gm:bj_poppet")[0]
	assert_true((entry["choices"] as Array).any(func(ch: Dictionary) -> bool: return str(ch["value"]) == ally.id), "the ally beside can take it")
	var r := _act(e, d, "poppet", foe, Vector2.INF, ally.id)
	assert_true(r.ok, r.reason)
	var sit := e.attacks.attack_situation(foe, ally, e.option_by_id(foe, "monster:fearsome_claw"))
	assert_true("Soulbound Poppet" in (sit["disadvantage"] as Array))
	var sit2 := e.attacks.attack_situation(foe, d, e.option_by_id(foe, "monster:fearsome_claw"))
	assert_false("Soulbound Poppet" in (sit2["disadvantage"] as Array), "only against the carrier")
	e.deal_damage(ally, foe, [{"amount": 1, "type": "slashing"}], false, "Test")
	var first := 199 - foe.creature.hp
	assert_true(first >= 2 and first <= 20, "2d10 Necrotic, got %d" % first)
	var hp := foe.creature.hp
	e.deal_damage(ally, foe, [{"amount": 1, "type": "slashing"}], false, "Test")
	assert_eq(foe.creature.hp, hp - 1, "once per turn")


func test_a_touch_spell_reaches_a_token_carrier_across_the_field() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 3, Vector2i(0, 0))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(11, 7))
	TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, d)
	var prepared := ((d.creature as Character).spellcasting[0] as Dictionary)["prepared"] as Array
	if not "cure_wounds" in prepared:
		prepared.append("cure_wounds")
	ally.creature.hp = 1
	var r := e.spells.cast(d, "cure_wounds", 1, [ally])
	assert_true(r.ok, r.reason)
	assert_true(ally.creature.hp > 1, "healed from 55 ft away")
	# Without a token, touch is touch.
	ally.remove_meta(CmBloodAndJest.token_key(d))
	d.reset_turn()
	assert_false(e.spells.cast(d, "cure_wounds", 1, [ally]).ok, "out of reach without the token")


func test_a_ward_never_outlasts_the_fight() -> void:
	var e := _field()
	var d := _hero(e, "druid", "circle_of_wicker", 6, Vector2i(0, 0))
	var ally := TestCombat.hero(e, "silvain_aster", Vector2i(1, 0))
	var bag := TestCombat.punching_bag(e, Vector2i(11, 7), 5)
	TestCombat.start_with(e, d)
	var ac := ally.creature.ac_value()
	assert_true(_act(e, d, "effigy:ward", null, _at(Vector2i(2, 0)), "cold").ok)
	assert_eq(ally.creature.ac_value(), ac + 1)
	e.deal_damage(d, bag, [{"amount": 50, "type": "slashing"}], false, "Test")
	assert_true(e.is_over(), "won with the effigy still up")
	for c: Combatant in [d, ally]:
		EncounterSetup.clear_fight_effects(c.creature)   # what the game does once a fight is over
	assert_eq(ally.creature.ac_value(), ac, "no +1 AC after the fight")
	assert_eq(d.creature.resistance_source(&"cold"), "", "nor the Resistance")
	# And a Ward somehow left on a hero is swept as the next fight starts.
	var stale := Effect.new("Ward (Bewitched Effigy)", &"feature", "bewitched_effigy")
	stale.stack_key = "bj_ward:gone"
	stale.with_modifier("ac", {"value": 1})
	ally.creature.add_effect(stale)
	var e2 := _field()
	var a2 := e2.add(ally.creature, &"party", Vector2i(1, 1))
	TestCombat.punching_bag(e2, Vector2i(9, 5))
	TestCombat.start_with(e2, a2)
	assert_eq(ally.creature.ac_value(), ac)
