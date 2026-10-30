extends TestCase
## The Crooked Moon's Barrow Guard, Grim Harbinger and Warrior of the Pestilent Haze in fights (combat/crooked/
## cm_grave_and_grim.gd): Rook's Draugr Dice and ghost steed, Lucan's Omen of Doom and the Grim, Silas's plague.


## The part alone as the fight's module (GameFeatures.use), so these tests read only its own code; CrookedFeatures
## forwards the same hooks to it in play (tests/unit/test_crooked_features.gd).
func before_each() -> void:
	GameFeatures.use(CmGraveAndGrim)


func after_each() -> void:
	GameFeatures.use(null)


func _fighter(e: Encounter, level: int, cell: Vector2i = Vector2i(2, 3)) -> Combatant:
	return e.add(TestChars.custom("fighter", "human", level, {"fighter_subclass": ["barrow_guard"]}), &"party", cell)


func _ranger(e: Encounter, level: int, cell: Vector2i = Vector2i(2, 3)) -> Combatant:
	return e.add(TestChars.custom("ranger", "human", level, {"ranger_subclass": ["grim_harbinger"]}), &"party", cell)


func _monk(e: Encounter, level: int, cell: Vector2i = Vector2i(2, 3)) -> Combatant:
	return e.add(TestChars.custom("monk", "human", level, {"monk_subclass": ["warrior_of_the_pestilent_haze"]}), &"party", cell)


## A foe whose saves are fixed at `save` (-10: always fails, +30: always succeeds).
func _bag(e: Encounter, cell: Vector2i, save: int = -10, extra: Dictionary = {}) -> Combatant:
	var data := {"ac": 1, "saves": {"str": save, "dex": save, "con": save, "int": save, "wis": save, "cha": save}}
	data.merge(extra, true)
	return e.add(TestChars.dummy(200, false, data), &"enemy", cell)


func _gm(e: Encounter, c: Combatant, id: String, t: Combatant = null, point: Vector2 = Vector2.INF, choice: String = "") -> CombatResult:
	return e.feature_actions.perform(c, "gm:gg_" + id, t, point, choice)


func _part(e: Encounter) -> CmGraveAndGrim:
	return e.game as CmGraveAndGrim


func _logged(e: Encounter, needle: String) -> bool:
	for entry in e.log.entries:
		if str(entry.get("text", "")).contains(needle) or str(entry.get("details", [])).contains(needle):
			return true
	return false


# --- Barrow Guard -----------------------------------------------------------------------------------------------

func test_death_knight_pool_die_and_power_dc_follow_the_table() -> void:
	var e := TestCombat.open_field()
	for row: Array in [[3, 6, 4], [5, 8, 6], [9, 8, 8], [11, 10, 8], [13, 10, 10]]:
		var f := _fighter(e, int(row[0]), Vector2i(int(row[0]) % 10, 1))
		assert_eq(CmGraveAndGrim.draugr_die(f), int(row[1]), "die at %d" % int(row[0]))
		assert_eq(CmGraveAndGrim.dice_left(f), int(row[2]), "dice at %d" % int(row[0]))
		assert_eq(CmGraveAndGrim.power_dc(f), 8 + f.creature.proficiency_bonus() + f.creature.ability_mod(&"con"))


func test_dark_rider_calls_an_undead_steed_that_carries_its_rider_and_dashes_on_a_die() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 3)
	var bag := _bag(e, Vector2i(10, 6))
	TestCombat.start_with(e, f)
	assert_true(_gm(e, f, "dark_rider").ok)
	var steed := _part(e).steed_of(f)
	assert_true(steed != null, "the steed answers")
	assert_eq(steed.creature.creature_type, &"undead")
	assert_eq(steed.creature.max_hp(), 19, "a Warhorse's Hit Points")
	assert_ne(steed.creature.resistance_source(&"slashing"), "", "B/P/S Resistance")
	assert_true(e.attack_options(steed).is_empty(), "it can only Dash, Disengage or Dodge")
	assert_false(f.bonus_available)
	assert_eq((f.creature as Character).resource_left("dark_rider"), 0)
	assert_true(e.mount(f, steed).ok, "mounted through EncounterMounts")
	var before := steed.movement_left
	assert_true(_gm(e, f, "draugr_dash").ok)
	var gained := steed.movement_left - before
	assert_eq(CmGraveAndGrim.dice_left(f), 3, "a Draugr Die spent")
	assert_true(gained >= 60 + 5 and gained <= 60 + 30 and (gained - 60) % 5 == 0, "Speed + 5 x a d6: %d" % gained)
	assert_false(_gm(e, f, "draugr_dash").ok, "the steed's action this round is used")
	# Its own turn then has no action.
	e.end_turn()
	assert_eq(e.current(), steed)
	assert_false(steed.action_available)
	assert_true(bag.is_alive())


func test_dark_rider_again_costs_a_die_and_the_steed_fades_when_its_rider_is_incapacitated() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 3)
	_bag(e, Vector2i(10, 6))
	TestCombat.start_with(e, f)
	assert_true(_gm(e, f, "dark_rider").ok)
	var first := _part(e).steed_of(f)
	f.bonus_available = true
	assert_true(_gm(e, f, "dark_rider").ok, "a Draugr Die buys the use back")
	assert_eq(CmGraveAndGrim.dice_left(f), 3)
	assert_false(first.is_alive(), "the old steed fades for the new")
	var steed := _part(e).steed_of(f)
	var stun := Effect.new("Stunned", &"spell", "test").with_condition(&"stunned")
	f.creature.add_effect(stun)
	assert_false(steed.is_alive(), "gone when its rider is Incapacitated")


func test_soul_reaper_trades_an_attack_for_grappling_hands_at_60_ft() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 3, Vector2i(0, 3))
	var bag := _bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, f)
	var con := f.creature.ability_mod(&"con")
	assert_true(_gm(e, f, "soul_reaper", bag).ok)
	var lost := 200 - bag.creature.hp
	assert_true(lost >= 1 + con and lost <= 6 + con, "the die + Con: %d" % lost)
	assert_true(bag.creature.has_condition(&"grappled"))
	assert_false(e.grapples.has(bag.id), "the hands hold it, nobody drags it")
	var hold := bag.creature.effects.filter(func(x: Effect) -> bool: return x.source_id == CmGraveAndGrim.HANDS)[0] as Effect
	assert_eq(int(hold.escape["dc"]), CmGraveAndGrim.power_dc(f))
	assert_eq(hold.minutes_left, 1)
	assert_true(f.took_attack_action, "one attack of the Attack action")
	assert_eq(CmGraveAndGrim.dice_left(f), 3)
	# A save halves it and nothing holds.
	var strong := _bag(e, Vector2i(10, 6), 30)
	f.attacks_left = 1
	assert_true(_gm(e, f, "soul_reaper", strong).ok)
	var half := 200 - strong.creature.hp
	assert_true(half >= 0 and half <= (6 + con) / 2)
	assert_false(strong.creature.has_condition(&"grappled"))


func test_spectral_shrieking_hurts_the_held_as_its_turn_starts() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 10, Vector2i(0, 3))
	var bag := _bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, f)
	assert_true(_gm(e, f, "soul_reaper", bag).ok)
	f.reaction_rules["spectral_shrieking"] = "never"
	var hp := bag.creature.hp
	e.end_turn()
	assert_eq(e.current(), bag)
	assert_eq(hp - bag.creature.hp, f.creature.proficiency_bonus(), "PB Psychic")
	f.reaction_rules["spectral_shrieking"] = "auto"
	hp = bag.creature.hp
	var dice := CmGraveAndGrim.dice_left(f)
	_part(e).turn_start(bag)
	var lost := hp - bag.creature.hp
	assert_true(lost >= f.creature.proficiency_bonus() + 1 and lost <= f.creature.proficiency_bonus() + 8, "PB + a d8: %d" % lost)
	assert_eq(CmGraveAndGrim.dice_left(f), dice - 1)
	assert_false(f.reaction_available)


func test_grave_guard_cuts_damage_and_death_knell_hits_back() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 10)
	var foe := _bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, f)
	f.reaction_rules["grave_guard"] = "auto"
	var con := f.creature.ability_mod(&"con")
	var hp := f.creature.hp
	e.deal_damage(foe, f, [{"amount": 30, "type": "fire"}], false, "Test blast")
	var taken := hp - f.creature.hp
	assert_true(taken >= 30 - 8 - con and taken <= 30 - 1 - con, "cut by a d8 + Con: %d" % taken)
	assert_false(f.reaction_available)
	assert_eq(CmGraveAndGrim.dice_left(f), 7)
	assert_eq(200 - foe.creature.hp, (30 - taken) / 2, "Death Knell: half of what was turned aside")


func test_grave_guard_answers_an_attack_hit() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 3)
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 3))
	TestCombat.start_with(e, foe)
	f.reaction_rules["grave_guard"] = "auto"
	var opt: Dictionary = e.attack_options(foe).filter(func(o: Dictionary) -> bool: return bool(o["melee"]))[0]
	TestCombat.next_d20(e, 20)
	e._resolve_attack(foe, f, opt, {})
	assert_false(f.reaction_available, "Grave Guard spent the Reaction")
	assert_eq(CmGraveAndGrim.dice_left(f), 3)
	assert_true(_logged(e, "Grave Guard"))


func test_mortal_coil_takes_a_die_back_when_a_living_foe_dies_near() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 7)
	var living := _bag(e, Vector2i(4, 3))
	var dead_thing := _bag(e, Vector2i(5, 3), -10, {"type": "undead"})
	TestCombat.start_with(e, f)
	(f.creature as Character).spend_resource("draugr_dice", 2)
	e.deal_damage(f, dead_thing, [{"amount": 500, "type": "force"}], false, "Test")
	assert_eq(CmGraveAndGrim.dice_left(f), 4, "not from an Undead")
	e.deal_damage(f, living, [{"amount": 500, "type": "force"}], false, "Test")
	assert_eq(CmGraveAndGrim.dice_left(f), 5, "one die back")
	assert_false(f.reaction_available)


func test_whisper_of_the_departed_adds_a_die_to_a_check() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 7)
	_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, f)
	f.reaction_rules["whisper_of_the_departed"] = "auto"
	var bonus := f.creature.skill_bonus(&"athletics").total()
	assert_false(f.creature.roll_check(e.dice, &"athletics", 40).success)
	assert_eq(CmGraveAndGrim.dice_left(f), 6, "no die on a check it can't save (six d8s at 7)")
	TestCombat.next_d20(e, 5)
	var t := f.creature.roll_check(e.dice, &"athletics", 5 + bonus + 2)
	assert_eq(CmGraveAndGrim.dice_left(f), 5, "a die spent on the failed check")
	assert_true(t.total >= 5 + bonus + 1 and t.total <= 5 + bonus + 8, "the d8 is added: %d" % t.total)


func test_phantom_charger_teleports_steed_and_rider_and_bursts_necrotic() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 10, Vector2i(0, 0))
	var bag := _bag(e, Vector2i(10, 6))
	TestCombat.start_with(e, f)
	assert_true(_gm(e, f, "dark_rider").ok)
	var steed := _part(e).steed_of(f)
	assert_true(steed.creature.has_flag("ignore_difficult_terrain"), "Phantom Charger: no Difficult Terrain")
	assert_true(e.mount(f, steed).ok)
	var con := f.creature.ability_mod(&"con")
	var r := _gm(e, f, "phantom_charge", null, Vector2(8.5, 6.5), "dodge")
	assert_true(r.ok, r.reason)
	assert_eq(steed.cell, Vector2i(8, 6))
	assert_eq(f.cell, steed.cell, "the rider comes along")
	assert_true(steed.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "dodge"), "the steed Dodged")
	var lost := 200 - bag.creature.hp
	assert_true(lost >= 1 + con and lost <= 8 + con, "the die + Con Necrotic: %d" % lost)


# --- Grim Harbinger ---------------------------------------------------------------------------------------------

func test_omen_of_doom_marks_calls_the_grim_and_adds_1d6_once_a_turn() -> void:
	var e := TestCombat.open_field()
	var r := _ranger(e, 3)
	var bag := _bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, r)
	var uses := (r.creature as Character).resource_left("omen_of_doom")
	assert_true(_gm(e, r, "omen", bag).ok)
	assert_eq((r.creature as Character).resource_left("omen_of_doom"), uses - 1)
	var part := _part(e)
	assert_eq(part.doomed_of(r), bag)
	var g := part.grim_of(r)
	assert_true(g != null)
	assert_eq(g.creature.max_hp(), 5 + 5 * 3)
	assert_eq(g.creature.armor_class().total(), 13 + r.creature.ability_mod(&"wis"))
	assert_eq(g.creature.creature_type, &"undead")
	assert_true(e.distance(g, bag) <= 30)
	var opt := e.option_by_id(r, "weapon:" + str(((r.creature as Character).wielded_attacks()[0]["profile"] as WeaponProfile).item_id))
	var first := e.game.hit_dice(r, bag, opt, {})
	assert_true(first.any(func(d: Dictionary) -> bool: return str(d["label"]) == "Omen of Doom" and str(d["dice"]) == "1d6" and str(d["type"]) == "necrotic"))
	var second := e.game.hit_dice(r, bag, opt, {})
	assert_false(second.any(func(d: Dictionary) -> bool: return str(d["label"]) == "Omen of Doom"), "once a turn")


func test_the_grim_acts_when_commanded_and_only_dodges_otherwise() -> void:
	var e := TestCombat.open_field()
	var r := _ranger(e, 3)
	var bag := _bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, r)
	assert_true(_gm(e, r, "omen", bag).ok)
	var g := _part(e).grim_of(r)
	e.end_turn()
	assert_eq(e.current(), g, "the Grim acts right after its ranger")
	assert_true(g.action_available, "commanded with the Omen")
	while e.current() != r:
		e.end_turn()
	e.end_turn()
	assert_eq(e.current(), g)
	assert_false(g.action_available, "uncommanded, it Dodges")
	assert_true(g.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "dodge"))
	# Its ranger Incapacitated: free again.
	while e.current() != r:
		e.end_turn()
	r.creature.add_effect(Effect.new("Stunned", &"spell", "test").with_condition(&"stunned"))
	e.end_turn()
	assert_eq(e.current(), g)
	assert_true(g.action_available, "acts on its own while the ranger is Incapacitated")


func test_trading_an_attack_sends_the_grims_ominous_rend_and_it_frightens() -> void:
	var e := TestCombat.open_field()
	var r := _ranger(e, 7)
	var bag := _bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, r)
	assert_true(_gm(e, r, "omen", bag).ok)
	var g := _part(e).grim_of(r)
	assert_true(e.distance(g, bag) <= 5, "the Grim rises beside its doomed")
	var rend := (g.creature as Monster).action("ominous_rend")
	assert_eq((rend["damage"] as Array).size(), 2, "Graveyard Hunter's extra 1d6")
	TestCombat.next_d20(e, 19)
	var res := _gm(e, r, "grim_rend", bag)
	assert_true(res.ok, res.reason)
	assert_true(r.took_attack_action)
	assert_true(bag.creature.hp < 200)
	assert_true(bag.creature.has_condition(&"frightened"))


func test_the_grim_vanishes_with_its_doomed_and_a_new_omen_replaces_it() -> void:
	var e := TestCombat.open_field()
	var r := _ranger(e, 5)
	var a := _bag(e, Vector2i(8, 3))
	var b := _bag(e, Vector2i(8, 6))
	TestCombat.start_with(e, r)
	assert_true(_gm(e, r, "omen", a).ok)
	var g1 := _part(e).grim_of(r)
	r.bonus_available = true
	assert_true(_gm(e, r, "omen", b).ok)
	assert_false(g1.is_alive(), "a new Omen ends the last Grim")
	assert_false(a.creature.effects.any(func(x: Effect) -> bool: return x.source_id == CmGraveAndGrim.DOOM), "the doom never moves on")
	var g2 := _part(e).grim_of(r)
	e.deal_damage(r, b, [{"amount": 500, "type": "force"}], false, "Test")
	assert_false(g2.is_alive(), "gone when the doomed dies")
	assert_true(_part(e).doomed_of(r) == null)


func test_mortal_reminder_and_mounting_dread_get_past_resistance() -> void:
	var e := TestCombat.open_field()
	var r := _ranger(e, 7)
	var bag := _bag(e, Vector2i(8, 3), -10, {"resistances": ["piercing", "necrotic"]})
	TestCombat.start_with(e, r)
	assert_true(_gm(e, r, "omen", bag).ok)
	var ps: Array = [{"amount": 10, "type": "piercing", "weapon": true}]
	e.game.adjust_incoming(r, bag, ps)
	assert_eq(str(ps[0]["type"]), "necrotic", "Mortal Reminder: Necrotic does more")
	assert_eq(bag.creature.preview_damage_parts(ps).final, 10)
	var g := _part(e).grim_of(r)
	var gp: Array = [{"amount": 8, "type": "necrotic"}]
	e.game.adjust_incoming(g, bag, gp)
	assert_eq(bag.creature.preview_damage_parts(gp).final, 8, "the Grim's Necrotic ignores Resistance")


func test_ghastly_hound_and_inescapable_fate() -> void:
	var e := TestCombat.open_field()
	var r := _ranger(e, 11)
	var bag := _bag(e, Vector2i(8, 3), 30)
	TestCombat.start_with(e, r)
	assert_true(_gm(e, r, "omen", bag).ok)
	var g := _part(e).grim_of(r)
	assert_ne(g.creature.resistance_source(&"piercing"), "", "Ghastly Hound")
	var t := bag.creature.roll_save(e.dice, &"wis", 10, [], [], "Test save")
	assert_true(t.success, "+30 still succeeds")
	assert_false(r.reaction_available, "Inescapable Fate forced a reroll")
	assert_true(t.reroll_note.contains("Inescapable Fate"))
	assert_false(bool(r.get_meta("gg_fate_spent", false)), "not spent until a save fails")


func test_baleful_howl_roots_a_creature_leaving_the_grims_reach() -> void:
	var e := TestCombat.open_field()
	var r := _ranger(e, 3, Vector2i(0, 0))
	var bag := _bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, r)
	assert_true(_gm(e, r, "omen", bag).ok)
	var g := _part(e).grim_of(r)
	g.reaction_rules["opportunity_attack"] = "never"
	while e.current() != bag:
		e.end_turn()
	var dest := bag.cell + (bag.cell - g.cell) * 3
	e.move(bag, Vector2i(clampi(dest.x, 0, 11), clampi(dest.y, 0, 7)))
	assert_false(g.reaction_available, "the Grim howled")
	assert_eq(bag.movement_left, 0, "Speed 0 for the rest of the turn")
	assert_true(e.distance(g, bag) <= 10, "stopped a step out of reach")


# --- Warrior of the Pestilent Haze ------------------------------------------------------------------------------

func test_claws_slash_when_it_does_more_and_flurry_hits_add_necrotic() -> void:
	var e := TestCombat.open_field()
	var m := _monk(e, 3)
	var bag := _bag(e, Vector2i(3, 3), -10, {"resistances": ["bludgeoning"]})
	TestCombat.start_with(e, m)
	var ps: Array = [{"amount": 6, "type": "bludgeoning", "weapon": true, "item": "unarmed_strike"}]
	e.game.adjust_incoming(m, bag, ps)
	assert_eq(str(ps[0]["type"]), "slashing")
	var opt := e.option_by_id(m, "weapon:unarmed_strike")
	assert_false(e.game.hit_dice(m, bag, opt, {}).any(func(d: Dictionary) -> bool: return str(d["label"]) == "Claws of Pestilence"))
	m.set_meta("flurry_turn", "%d:%d" % [e.round_no, e.turn_index])
	var dice := e.game.hit_dice(m, bag, opt, {})
	assert_true(dice.any(func(d: Dictionary) -> bool: return str(d["label"]) == "Claws of Pestilence" and str(d["dice"]) == "1d%d" % ClassFeatures.martial_die(m)))


func test_miasmic_plague_rider_curses_and_its_die_lands_once_a_turn() -> void:
	var e := TestCombat.open_field()
	var m := _monk(e, 3)
	var bag := _bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, m)
	var ch := m.creature as Character
	var focus := ch.resource_left("focus_points")
	assert_true(e.game.rider_options(m).any(func(o: Dictionary) -> bool: return str(o["id"]) == "gg_plague"))
	m.armed.append("gg_plague")
	var opt := e.option_by_id(m, "weapon:unarmed_strike")
	var st := {}
	e.game.hit_dice(m, bag, opt, st)
	assert_eq(ch.resource_left("focus_points"), focus - 1)
	e.game.after_hit(m, bag, opt, st, CombatResult.new())
	assert_true(bag.creature.has_condition(&"poisoned"), "cursed: Poisoned")
	var dice := e.game.hit_dice(m, bag, opt, {})
	assert_true(dice.any(func(d: Dictionary) -> bool: return str(d["label"]) == "Miasmic Plague"))
	assert_false(e.game.hit_dice(m, bag, opt, {}).any(func(d: Dictionary) -> bool: return str(d["label"]) == "Miasmic Plague"), "once a turn")


func test_miasmic_plague_is_free_on_a_flurry_hit_for_the_claws_die() -> void:
	var e := TestCombat.open_field()
	var m := _monk(e, 3)
	var bag := _bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, m)
	var ch := m.creature as Character
	var focus := ch.resource_left("focus_points")
	m.armed.append("gg_plague_free")
	m.set_meta("flurry_turn", "%d:%d" % [e.round_no, e.turn_index])
	var opt := e.option_by_id(m, "weapon:unarmed_strike")
	var st := {}
	var dice := e.game.hit_dice(m, bag, opt, st)
	assert_false(dice.any(func(d: Dictionary) -> bool: return str(d["label"]) == "Claws of Pestilence"), "the claws' die given up")
	assert_eq(ch.resource_left("focus_points"), focus, "no Focus Point")
	e.game.after_hit(m, bag, opt, st, CombatResult.new())
	assert_true(bag.creature.has_condition(&"poisoned"))
	# The save at the end of each of its turns: a failure keeps it, a success ends it.
	e.game.turn_end(bag)
	assert_true(bag.creature.has_condition(&"poisoned"), "a -10 save keeps it")
	((bag.creature as Monster).data["saves"] as Dictionary)["con"] = 30
	e.game.turn_end(bag)
	assert_false(bag.creature.has_condition(&"poisoned"), "a success ends it")


func test_tolling_censer_and_choking_miasma() -> void:
	var e := TestCombat.open_field()
	var m := _monk(e, 11)
	var near := _bag(e, Vector2i(5, 3))
	var far := _bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, m)
	var ch := m.creature as Character
	var focus := ch.resource_left("focus_points")
	var res := _gm(e, m, "tolling_censer")
	assert_true(res.ok, res.reason)
	assert_eq(ch.resource_left("focus_points"), focus - 2)
	assert_true(m.magic_action_used)
	var lost := 200 - near.creature.hp
	var die := ClassFeatures.martial_die(m)
	assert_true(lost >= 2 and lost <= 2 * die, "two Martial Arts dice: %d" % lost)
	assert_true(near.creature.has_condition(&"poisoned"))
	assert_eq(far.creature.hp, 200, "outside 20 ft")
	assert_true(_logged(e, "Choking Miasma"), "the plague's saves have Disadvantage")


func test_scurrying_spread_curses_foes_passed_after_step_of_the_wind() -> void:
	var e := TestCombat.open_field()
	var m := _monk(e, 11, Vector2i(0, 3))
	var bag := _bag(e, Vector2i(4, 2))
	TestCombat.start_with(e, m)
	var cat := ActionCatalog.new(e)
	var step := cat.find(m, "feat:cf:step_of_the_wind_focus")
	assert_false(step.is_empty())
	assert_true(cat.perform(m, step).ok)
	assert_true(e.move(m, Vector2i(5, 3)).ok)
	assert_true(bag.creature.has_condition(&"poisoned"), "cursed as the monk passed")


func test_the_crooked_moon_module_routes_these_actions_here() -> void:
	GameFeatures.use(null)
	var e := TestCombat.open_field()
	var r := _ranger(e, 3)
	var bag := _bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, r)
	var res := _gm(e, r, "omen", bag)
	assert_true(res.ok, res.reason)
	assert_true(bag.creature.effects.any(func(x: Effect) -> bool: return x.source_id == CmGraveAndGrim.DOOM))


func test_only_rook_can_mount_his_ghost_steed() -> void:
	var e := TestCombat.open_field()
	var f := _fighter(e, 3)
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 5))
	_bag(e, Vector2i(10, 6))
	TestCombat.start_with(e, f)
	assert_true(_gm(e, f, "dark_rider").ok)
	var steed := _part(e).steed_of(f)
	ally.cell = e.spells._free_cell_near(steed.cell, 1)
	assert_true(e.distance(ally, steed) <= 5, "the ally stands beside it")
	assert_true(e.mount_why(ally, steed).contains("Only its own rider"), e.mount_why(ally, steed))
	assert_eq(e.mount_why(f, steed), "", "its fighter can")
	assert_true(e.mount(f, steed).ok)


func test_inescapable_fate_uses_the_new_roll_even_on_a_save_with_advantage() -> void:
	var e := TestCombat.open_field()
	var r := _ranger(e, 11)
	var bag := _bag(e, Vector2i(8, 3), 30)
	TestCombat.start_with(e, r)
	assert_true(_gm(e, r, "omen", bag).ok)
	TestCombat.next_d20(e, 20)
	var adv: Array[String] = ["Test"]
	var t := bag.creature.roll_save(e.dice, &"wis", 10, adv, [], "Test save")
	assert_false(r.reaction_available, "Inescapable Fate was used")
	var rx := RegEx.create_from_string("Inescapable Fate \\((\\d+), (\\d+)\\)")
	var m := rx.search(t.reroll_note)
	assert_true(m != null, t.reroll_note)
	if m == null:
		return
	assert_eq(t.kept, mini(int(m.get_string(1)), int(m.get_string(2))), "the lower new die, not the old Advantage die")


## The damage line of the Tolling Censer on the creature named `who`: [dealt, rolled].
func _censer_hit(e: Encounter, who: String) -> Array[int]:
	for entry in e.log.entries:
		if str(entry["kind"]) == "hit" and str(entry["text"]).contains(who):
			var details := entry["details"] as Array
			var rolled := int(str(details[0]).get_slice("= ", 1))
			var dealt := int(str(entry["text"]).get_slice(" for ", 1).get_slice(" ", 0))
			return [dealt, rolled]
	return [-1, -1]


func test_tolling_censer_makes_already_cursed_foes_save_too() -> void:
	var e := TestCombat.open_field()
	var m := _monk(e, 6)
	var weak := _bag(e, Vector2i(4, 3), -10, {"name": "Weakling"})
	var tough := _bag(e, Vector2i(4, 5), 30, {"name": "Toughling"})
	TestCombat.start_with(e, m)
	var part := _part(e)
	part._curse(m, weak)
	part._curse(m, tough)
	assert_true(_gm(e, m, "tolling_censer").ok)
	var w := _censer_hit(e, "Weakling")
	assert_eq(w[0], w[1], "a failed save: full damage")
	var t := _censer_hit(e, "Toughling")
	assert_eq(t[0], t[1] / 2, "a success: half")
	assert_true(_logged(e, "Weakling fails the Tolling Censer save"))
	assert_true(_logged(e, "Toughling succeeds on the Tolling Censer save"))
	assert_true(weak.creature.has_condition(&"poisoned"), "still cursed, not twice")
	assert_eq(weak.creature.effects.filter(func(x: Effect) -> bool: return x.source_id == CmGraveAndGrim.PLAGUE).size(), 1)
