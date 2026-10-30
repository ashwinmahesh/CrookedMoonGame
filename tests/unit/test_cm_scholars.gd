extends TestCase
## The Crooked Moon's Horned King Patron, Occultist and Philosopher in a fight (combat/crooked/cm_scholars.gd):
## Malediction and its Reaction, Spiteful Curse, Crown of Horns, the Intrusion Die and its table, Reality Tear, Occult
## Presence, Quintessence, Vitriolic Enhancement and Albedo.


func before_each() -> void:
	GameFeatures.use(null)


func _part(e: Encounter) -> CmScholars:
	return (e.game as CrookedFeatures).owner_of("sh_anything") as CmScholars


func _find(e: Encounter, c: Combatant, id: String) -> Dictionary:
	return ActionCatalog.new(e).find(c, id)


func _do(e: Encounter, c: Combatant, id: String, t: Combatant, choice: String = "") -> CombatResult:
	var a := _find(e, c, "feat:gm:" + id)
	assert_false(a.is_empty(), "%s on the hotbar" % id)
	return ActionCatalog.new(e).perform(c, a, [t] if t != null else [], Vector2.INF, Vector2.ZERO, 0, {"choice": choice})


func _warlock(e: Encounter, level: int) -> Combatant:
	var ch := TestChars.custom("warlock", "human", level, {"warlock_subclass": ["horned_king_patron"]})
	return e.add(ch, &"party", Vector2i(2, 2))


func _wizard(e: Encounter, level: int, sub: String, picks: Dictionary = {}) -> Combatant:
	var p := picks.duplicate()
	p["wizard_subclass"] = [sub]
	var ch := TestChars.custom("wizard", "human", level, p)
	return e.add(ch, &"party", Vector2i(2, 2))


func _learn(c: Combatant, ids: Array) -> void:
	var prepared := ((c.creature as Character).spellcasting[0] as Dictionary)["prepared"] as Array
	for s: Variant in ids:
		if not str(s) in prepared:
			prepared.append(str(s))


## The first seed whose first roll of a d`sides` shows `value`.
func _seed_for(sides: int, value: int) -> int:
	for s in range(1, 5000):
		if DiceRoller.new(s).roll_one(sides) == value:
			return s
	return 1


static func _has(t: Combatant, source: String) -> bool:
	return t.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == source)


# --- Horned King Patron -------------------------------------------------------------------------------------------

func test_malediction_agony_gives_the_next_attack_disadvantage_and_spends_a_use() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 3)
	var foe := TestCombat.punching_bag(e, Vector2i(5, 2))
	TestCombat.start_with(e, w)
	var ch := w.creature as Character
	var uses := ch.resource_left("malediction")
	assert_eq(uses, maxi(1, ch.ability_mod(&"cha")), "Charisma modifier uses")
	assert_true(_do(e, w, "sh_malediction", foe, "agony").ok)
	assert_eq(ch.resource_left("malediction"), uses - 1)
	assert_false(w.action_available, "a Magic action")
	var t := foe.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, Breakdown.new("x"), 10, ["attack", "attack:melee"])
	assert_true(t.disadvantage, "Agony: Disadvantage on its next attack roll")
	assert_false(_has(foe, "sh_malediction"), "used up by that roll")


func test_malediction_hate_lands_on_the_chosen_save_only() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 3)
	var foe := TestCombat.punching_bag(e, Vector2i(5, 2))
	TestCombat.start_with(e, w)
	assert_true(_do(e, w, "sh_malediction", foe, "hate:wis").ok)
	var dex := foe.creature.roll_save(e.dice, &"dex", 10)
	assert_false(dex.disadvantage, "not a Dexterity save")
	var wis := foe.creature.roll_save(e.dice, &"wis", 10)
	assert_true(wis.disadvantage, "Hate: Disadvantage on its next Wisdom save")


func test_malediction_rot_adds_1d10_necrotic_once_and_stops_healing() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 3)
	var foe := TestCombat.punching_bag(e, Vector2i(5, 2), 80)
	TestCombat.start_with(e, w)
	assert_true(_do(e, w, "sh_malediction", foe, "rot").ok)
	assert_true(foe.creature.has_flag("cant_regain_hp"))
	e.deal_damage(w, foe, [{"amount": 5, "type": "slashing"}], false, "test")
	var lost := 80 - foe.creature.hp
	assert_true(lost >= 6 and lost <= 15, "5 + 1d10 Necrotic (lost %d)" % lost)
	e.deal_damage(w, foe, [{"amount": 5, "type": "slashing"}], false, "test")
	assert_eq(80 - foe.creature.hp, lost + 5, "only the next damage festers")


func test_malediction_reaction_before_an_attack_gives_it_disadvantage() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 3)
	var foe := TestCombat.foe(e, "bandit", Vector2i(3, 2))
	w.reaction_rules["malediction"] = "auto"
	TestCombat.start_with(e, foe)
	var uses := (w.creature as Character).resource_left("malediction")
	var mark := e.log.entries.size()
	var r := e.attack(foe, w, str(e.attack_options(foe)[0]["id"]))
	assert_true(r.ok, r.reason)
	var said := e.log.entries.slice(mark).any(func(x: Variant) -> bool:
		return ((x as Dictionary).get("details", []) as Array).any(func(d: Variant) -> bool: return str(d).contains("Disadvantage: Malediction: Agony")))
	assert_true(said, "Agony gives the attack roll itself Disadvantage")
	assert_false(w.reaction_available)
	assert_eq((w.creature as Character).resource_left("malediction"), uses - 1)


func test_malediction_reaction_to_a_spell_attack_rolls_it_again_and_keeps_the_lower() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 3)
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, w)
	var t := D20Test.from_natural(D20Test.Kind.ATTACK_ROLL, 18, 4, 12)
	var out: Array = []
	_part(e).d20_offers(foe, t, ["attack", "attack:ranged", "attack:spell", "target:" + w.id], out)
	assert_eq(out.size(), 1, "offered against a spell attack at the warlock")
	var o := out[0] as Dictionary
	assert_eq(str(o["kind"]), "malediction", "follows Malediction's Ask/Automatic/Off rule")
	TestCombat.next_d20(e, 3)
	(o["use"] as Callable).call()
	assert_eq(t.kept, 3, "the lower die")
	assert_false(t.success)
	var none: Array = []
	_part(e).d20_offers(foe, t, ["attack", "attack:melee", "target:" + w.id], none)
	assert_true(none.is_empty(), "a weapon attack is answered before its roll instead")


func test_malediction_reaction_to_a_spell_save_curses_the_caster() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 3)
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, w)
	var t := D20Test.from_natural(D20Test.Kind.SAVING_THROW, 5, 0, 13)
	var out: Array = []
	var keys: Array[String] = ["save:wis", "save_vs:spell", "save_vs:spell:" + foe.id]
	_part(e).d20_offers(w, t, keys, out)
	assert_eq(out.size(), 1)
	var o := out[0] as Dictionary
	(o["select"] as Callable).call(["hate:cha"] as Array[String])
	(o["use"] as Callable).call()
	assert_true(foe.creature.roll_save(e.dice, &"cha", 10).disadvantage, "Hate on the caster")


func test_spiteful_curse_lands_bestow_curse_and_is_spent_on_a_failed_save() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 6)
	var foe := TestCombat.punching_bag(e, Vector2i(9, 2))
	TestCombat.start_with(e, w)
	var ch := w.creature as Character
	assert_eq(ch.resource_left("spiteful_curse"), 1)
	TestCombat.next_d20(e, 2)
	assert_true(_do(e, w, "sh_spiteful_curse", foe, "ability_wis").ok, "35 ft: Spiteful Curse reaches 60 ft")
	assert_true(foe.creature.effects.any(func(fx: Effect) -> bool: return fx.name == "Bestow Curse"), "the curse landed")
	assert_true(foe.creature.roll_save(e.dice, &"wis", 10).disadvantage, "Disadvantage on Wisdom saves")
	assert_eq(ch.resource_left("spiteful_curse"), 0)
	assert_true(w.creature.concentration == null, "no Concentration")


func test_spiteful_curse_saved_keeps_the_use_and_lands_a_malediction_curse() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 6)
	var foe := e.add(TestChars.dummy(50, false, {"abilities": {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 30, "cha": 10}}), &"enemy", Vector2i(5, 2))
	TestCombat.start_with(e, w)
	TestCombat.next_d20(e, 20)
	var r := _do(e, w, "sh_spiteful_curse", foe, "attacks")
	assert_true(r.ok)
	assert_true(e.pending != null, "asked which Malediction curse")
	e.answer_reaction(true)
	assert_true(_has(foe, "sh_malediction"), "Rot (the first pick) lands instead")
	assert_eq((w.creature as Character).resource_left("spiteful_curse"), 1, "the use is kept")


func test_crown_of_horns_dark_heart_once_a_turn_and_king_of_all() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 10)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 2), 200)
	TestCombat.start_with(e, w)
	var ch := w.creature as Character
	assert_true(_do(e, w, "sh_crown_of_horns", null).ok)
	assert_false(w.bonus_available, "a Bonus Action")
	assert_eq(ch.resource_left("horned_king_patron_crown_of_horns"), 0)
	e.deal_damage(w, foe, [{"amount": 10, "type": "slashing"}], false, "test")
	var first := 200 - foe.creature.hp
	assert_true(first >= 11 and first <= 18, "10 + 1d8 Necrotic (Dark Heart): %d" % first)
	e.deal_damage(w, foe, [{"amount": 10, "type": "slashing"}], false, "test")
	assert_eq(200 - foe.creature.hp, first + 10, "once a turn")
	assert_true(_do(e, w, "sh_king_of_all", foe, "wickedness").ok)
	assert_true(_has(foe, "sh_king_of_all"), "Cha 1 fails the save")
	var t := foe.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, Breakdown.new("x"), 10, ["attack"])
	assert_true(t.disadvantage, "Wickedness")
	assert_false(_find(e, w, "feat:gm:sh_king_of_all").is_empty())
	assert_ne(str(_find(e, w, "feat:gm:sh_king_of_all")["reason"]), "", "once on each of your turns")


func test_crown_of_horns_again_costs_a_pact_slot() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 10)
	TestCombat.punching_bag(e, Vector2i(9, 7))
	TestCombat.start_with(e, w)
	var ch := w.creature as Character
	ch.spend_resource("horned_king_patron_crown_of_horns")
	var pact := int(ch.pact_magic()["left"])
	assert_true(_do(e, w, "sh_crown_of_horns", null).ok)
	assert_eq(int(ch.pact_magic()["left"]), pact - 1)


func test_terror_frightens_and_sends_it_fleeing() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 10)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 2))
	TestCombat.start_with(e, w)
	assert_true(_do(e, w, "sh_crown_of_horns", null).ok)
	assert_true(_do(e, w, "sh_king_of_all", foe, "terror").ok)
	assert_true(foe.creature.has_condition(&"frightened"))
	assert_true(foe.creature.has_flag("fear_flee"))


# --- Occultist ----------------------------------------------------------------------------------------------------

func test_intrusion_die_starts_at_d6_and_tops_out_at_d8_from_level_5() -> void:
	var e := TestCombat.open_field()
	var c3 := _wizard(e, 3, "occultist")
	assert_eq(CmScholars._die(c3.creature as Character), 6)
	var c5 := _wizard(e, 5, "occultist")
	assert_eq(CmScholars._die(c5.creature as Character), 8)
	assert_eq(CmScholars._top(c5.creature as Character), 8)
	var ch := c5.creature as Character
	ch.spend_resource("intrusion_die", 2)
	assert_eq(CmScholars._die(ch), 4)
	ch.finish_short_rest()
	assert_eq(CmScholars._die(ch), 6, "a Short Rest grows it a step")
	ch.finish_long_rest()
	assert_eq(CmScholars._die(ch), 8, "a Long Rest resets it")


func test_seeking_eye_safe_risk_shrinks_the_die_and_gives_advantage() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 3, "occultist")
	_learn(c, ["ray_of_sickness"])
	var foe := TestCombat.punching_bag(e, Vector2i(6, 2))
	TestCombat.start_with(e, c)
	var labels := _part(e).rider_options(c).map(func(o: Dictionary) -> String: return str(o["sub"]))
	assert_true(labels.any(func(s: String) -> bool: return s.contains("d6")), "the die size shows")
	c.armed.append("sh_risk_eye")
	var adv := [false]
	var prev := c.creature.d20_after
	c.creature.d20_after = func(cr: Creature, t: D20Test, k: Array[String]) -> void:
		if t.kind == D20Test.Kind.ATTACK_ROLL:
			adv[0] = t.advantage
		prev.call(cr, t, k)
	e.dice.reseed(_seed_for(6, 4))
	var r := e.spells.cast(c, "ray_of_sickness", 1, [foe])
	assert_true(r.ok, r.reason)
	assert_true(adv[0], "Advantage on the spell's attack roll")
	assert_eq(CmScholars._die(c.creature as Character), 4, "a 4 shrinks the d6 to a d4")
	assert_false("sh_risk_eye" in c.armed)


func test_a_risked_1_grows_the_die_and_rolls_the_table() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 5, "occultist")
	var ch := c.creature as Character
	ch.spend_resource("intrusion_die", 4)   # down to a d2
	TestCombat.punching_bag(e, Vector2i(9, 7))
	TestCombat.start_with(e, c)
	var part := _part(e)
	e.dice.reseed(_seed_for(2, 1))
	part._risk(c, "test")
	assert_eq(CmScholars._die(ch), 3, "a 1 grows the d2 to a d3")
	assert_eq(e.reaction_queue.size(), 1, "the Intrusion waits for the spell to finish")
	e.run_reaction_queue(CombatResult.new())
	assert_true(e.reaction_queue.is_empty())


func test_intrusion_rows() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 5, "occultist")
	var foe := TestCombat.punching_bag(e, Vector2i(4, 2), 200)
	TestCombat.start_with(e, c)
	var part := _part(e)
	part._apply_intrusion(c, 1)
	assert_true(c.creature.has_flag("dazed"), "1: one thing a turn")
	part._apply_intrusion(c, 2)
	assert_true(foe.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "sh_intrusion_warp"), "2: Speed halved within 30 ft")
	part._apply_intrusion(c, 6)
	assert_true(c.creature.has_condition(&"blinded"), "6")
	part._apply_intrusion(c, 7)
	assert_true(c.creature.has_condition(&"incapacitated"), "7")
	var dc := (c.creature as Character).spell_save_dc("wizard").total()
	part._apply_intrusion(c, 8)
	assert_eq((c.creature as Character).spell_save_dc("wizard").total(), dc + 2, "8: +2 spell save DC")
	part._apply_intrusion(c, 10)
	assert_true(foe.creature.has_condition(&"prone") and c.creature.has_condition(&"prone"), "10: Prone within 15 ft")
	part._apply_intrusion(c, 11)
	assert_true(c.creature.roll_save(e.dice, &"wis", 10).disadvantage, "11: Wisdom saves")
	EncounterSetup.clear_fight_effects(c.creature)
	assert_true(_has(c, "sh_intrusion_whispers"), "11: an hour outlives the fight")
	part._apply_intrusion(c, 5)
	var p := WeaponProfile.unarmed(c.creature)
	assert_eq(str(p.damage_type), "acid", "5: an Acid limb")
	assert_eq(str(p.ability), "int", "the spell attack bonus")
	assert_true(p.damage_dice.begins_with("%dd8" % c.creature.proficiency_bonus()), "PB Intrusion dice at starting size: %s" % p.damage_dice)
	var hp := foe.creature.hp
	part._apply_intrusion(c, 3)
	assert_true(foe.creature.hp < hp, "3: Con 1 fails, Necrotic")


func test_intrusion_12_brings_an_aberration_or_fiend() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 5, "occultist")
	TestCombat.punching_bag(e, Vector2i(9, 7))
	TestCombat.start_with(e, c)
	var before := e.combatants.size()
	var came := false
	for s in range(1, 40):
		e.dice.reseed(s)
		_part(e)._apply_intrusion(c, 12)
		if e.combatants.size() > before:
			came = true
			break
	assert_true(came, "something steps through on a mood of 1-3 or 6")
	var it := e.combatants.back() as Combatant
	assert_true(str(it.creature.creature_type) in ["aberration", "fiend"])
	assert_true(CmScholars._cr((it.creature as Monster).data.get("cr", 0)) <= 5.0, "CR up to the Wizard level")


func test_reality_tear_drops_concentration_and_free_cast_causes_an_intrusion() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 6, "occultist", {"reality_tear": ["hold_person"]})
	var ch := c.creature as Character
	assert_eq(CmScholars._tear_spell(ch), "hold_person")
	var foe := TestCombat.punching_bag(e, Vector2i(5, 2))
	TestCombat.start_with(e, c)
	var held := c.creature.begin_concentration("web", "Web", {"kind": "hours", "amount": 1, "concentration": true})
	c.armed.append("sh_tear_unbound")
	var r := e.spells.cast(c, "hold_person", 3, [foe])
	assert_true(r.ok, r.reason)
	assert_true(c.creature.concentration == held, "no Concentration: the Web it held goes on")
	assert_true(foe.creature.has_condition(&"paralyzed"), "the spell still holds")
	# The free casting, once per Long Rest: an automatic Intrusion (the die grows a step).
	ch.spend_resource("intrusion_die")
	var before := CmScholars._die(ch)
	_part(e).after_cast(c, Compendium.shared().spell_data("hold_person"), 2, true)
	assert_true(CmScholars._die(ch) > before, "the die grows")
	assert_eq(e.reaction_queue.size(), 1, "an Intrusion queued")


func test_occult_presence_rolls_twice_and_can_negate_for_exhaustion() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 10, "occultist", {"occult_presence": ["cosmic_resistance"]})
	TestCombat.punching_bag(e, Vector2i(9, 7))
	TestCombat.start_with(e, c)
	_part(e)._intrusion(c)
	var r := e.run_reaction_queue(CombatResult.new())
	assert_true(r.pending != null, "asked which Intrusion")
	assert_eq(r.pending.target_choices.size(), 3, "two rows and the Exhaustion")
	r.pending.selected_ids.assign(["negate"])
	e.answer_reaction(true)
	assert_eq(c.creature.exhaustion, 1)


func test_occult_presence_swaps_its_benefit_with_an_automatic_intrusion() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 10, "occultist", {"occult_presence": ["cosmic_resistance"]})
	TestCombat.punching_bag(e, Vector2i(9, 7))
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	assert_eq(CmScholars._presence(ch), "cosmic_resistance")
	ch.spend_resource("intrusion_die")
	ch.set_resource("sh_test_counter", "A once-per-rest counter", 1, "long")
	ch.spend_resource("sh_test_counter")
	var before := CmScholars._die(ch)
	assert_true(_do(e, c, "sh_occult_presence", null, "alien_consciousness").ok)
	assert_true(ch.resources.has("sh_test_counter") and ch.resource_left("sh_test_counter") == 0, "a spent counter the data doesn't define stays spent")
	assert_eq(CmScholars._presence(ch), "alien_consciousness")
	assert_true(CmScholars._die(ch) > before, "the die grows")
	assert_false(c.bonus_available)
	while e.pending != null:
		e.answer_reaction(false)


# --- Philosopher --------------------------------------------------------------------------------------------------

func test_dissolution_destroys_a_creature_and_leaves_quintessence() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 3, "philosopher")
	var ch := c.creature as Character
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2), 1)
	TestCombat.start_with(e, c)
	assert_eq(CmScholars.quintessence(ch), 0)
	TestCombat.next_d20(e, 15)
	var r := e.spells.cast(c, "dissolution", 0, [foe])
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.dead, "destroyed")
	assert_eq(CmScholars.quintessence(ch), 1)
	assert_eq(CmScholars.quintessence_cap(ch), maxi(2, 2 * ch.ability_mod(&"int")))


func test_vitriolic_enhancement_turns_the_damage_to_force() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 3, "philosopher")
	var ch := c.creature as Character
	_learn(c, ["ray_of_frost"])
	ch.build["quintessence"] = 2
	var foe := e.add(TestChars.dummy(80, false, {"ac": 1, "immunities": ["cold"]}), &"enemy", Vector2i(6, 2))
	TestCombat.start_with(e, c)
	c.armed.append("sh_vitriol")
	TestCombat.next_d20(e, 15)
	assert_true(e.spells.cast(c, "ray_of_frost", 0, [foe]).ok)
	assert_true(foe.creature.hp < 80, "Force gets past the Cold immunity")
	assert_eq(CmScholars.quintessence(ch), 1)


func test_albedo_raises_the_slot_by_the_measures_spent() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 6, "philosopher")
	var ch := c.creature as Character
	_learn(c, ["magic_missile"])
	ch.build["quintessence"] = 3
	var foe := TestCombat.punching_bag(e, Vector2i(6, 2), 200)
	TestCombat.start_with(e, c)
	assert_eq(CmScholars._albedo_cap(c), 2, "half of PB 3, rounded up")
	var ids := _part(e).rider_options(c).map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true("sh_albedo_2" in ids and not "sh_albedo_3" in ids)
	c.armed.append("sh_albedo_2")
	var mark := e.log.entries.size()
	assert_true(e.spells.cast(c, "magic_missile", 1, [foe]).ok)
	assert_eq(CmScholars.quintessence(ch), 1, "two measures spent")
	var said := e.log.entries.slice(mark).any(func(x: Variant) -> bool: return str((x as Dictionary).get("text", "")).contains("level 3 slot (Albedo)"))
	assert_true(said, "cast as with a level 3 slot")


func test_quintessence_pays_a_costly_material_component() -> void:
	var e := TestCombat.open_field()
	var c := _wizard(e, 3, "philosopher")
	var ch := c.creature as Character
	_learn(c, ["protection_from_evil_and_good"])
	TestCombat.punching_bag(e, Vector2i(9, 7))
	TestCombat.start_with(e, c)
	var ward := func() -> Dictionary:
		for k in e.spells.castable(c):
			if str(k["id"]) == "protection_from_evil_and_good":
				return k
		return {}
	assert_true(str(ward.call()["reason"]).begins_with("Needs"), "no holy water or powdered silver, no Quintessence")
	ch.build["quintessence"] = 1
	assert_true(bool(ward.call()["legal"]), "a measure stands in for the 25 gp component")
	var r := e.spells.cast(c, "protection_from_evil_and_good", 1, [c])
	assert_true(r.ok, r.reason)
	assert_eq(CmScholars.quintessence(ch), 0, "spent")


func test_queued_choices_survive_their_owner_being_hurt() -> void:
	var e := TestCombat.open_field()
	var w := _warlock(e, 6)
	var foe := TestCombat.punching_bag(e, Vector2i(3, 2))
	TestCombat.start_with(e, w)
	_part(e)._ask_curse(w, foe)
	e.deal_damage(foe, w, [{"amount": 3, "type": "slashing"}], false, "test")
	var r := e.run_reaction_queue(CombatResult.new())
	assert_true(r.pending != null, "the curse pick is still asked")
	e.answer_reaction(true)
	assert_true(_has(foe, "sh_malediction"))
	var e2 := TestCombat.open_field()
	var c := _wizard(e2, 5, "occultist")
	var foe2 := TestCombat.punching_bag(e2, Vector2i(3, 2))
	TestCombat.start_with(e2, c)
	_part(e2)._intrusion(c)
	e2.deal_damage(foe2, c, [{"amount": 3, "type": "slashing"}], false, "test")
	e2.run_reaction_queue(CombatResult.new())
	while e2.pending != null:
		e2.answer_reaction(false)
	assert_true(e2.reaction_queue.is_empty(), "the Intrusion settled")
