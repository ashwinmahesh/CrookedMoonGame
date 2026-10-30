extends TestCase
## The book's Dark Bargains in a fight (combat/crooked/cm_bargains.gd): each bargain is a dark gift a hero takes with
## accept_dark_gift, and its benefit's and cost's features act through the Crooked Moon module's hooks.


func before_each() -> void:
	GameFeatures.use(null)


## A level `level` human fighter who has taken `gifts`, with `picks` for the gifts' own choices (key -> picks).
func _hero(gifts: Array, level: int = 5, picks: Dictionary = {}) -> Character:
	var ch := TestChars.custom("fighter", "human", level)
	for g: Variant in gifts:
		ch.accept_dark_gift(str(g))
	for k: String in picks:
		ch.choices()[k] = picks[k]
	if not picks.is_empty():
		ch.refresh()
	return ch


func _ch(c: Combatant) -> Character:
	return c.creature as Character


func _has_fx(c: Combatant, source: String) -> bool:
	return c.creature.effects.any(func(x: Effect) -> bool: return x.source_id == source)


func _ids(e: Encounter, c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for x in e.feature_actions.list(c):
		out.append(str(x["id"]))
	return out


# --- Bestial Awakening --------------------------------------------------------------------------------------------

func test_beast_skin_free_polymorph_takes_only_its_bearer() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["bestial_awakening"], 5, {"gift.bestial_awakening.beast_skin": ["wis"]}), &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3))
	var entry := {}
	for k in e.spells.castable(c):
		if str(k["id"]) == "polymorph":
			entry = k
	assert_false(entry.is_empty(), "Polymorph is always prepared")
	assert_true(bool(entry.get("free", false)), "and free once a Long Rest")
	var tgt: Array[Combatant] = [foe]
	var ctx := {"c": c, "s": Compendium.shared().spell_data("polymorph"), "spent_slot": false, "targets": tgt}
	e.game.before_resolve(ctx)
	assert_eq(tgt.size(), 1)
	assert_true(tgt[0] == c, "the free casting turns on its bearer, not the foe")
	var tgt2: Array[Combatant] = [foe]
	e.game.before_resolve({"c": c, "s": Compendium.shared().spell_data("polymorph"), "spent_slot": true, "targets": tgt2})
	assert_true(tgt2[0] == foe, "with a slot it takes any target")


func test_searing_silver_ignores_resistance_and_stops_healing() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["bestial_awakening", "skin_of_coffin_nails"], 5, {"gift.skin_of_coffin_nails.iron_grit": ["slashing"]}), &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	assert_ne(c.creature.resistance_source(&"slashing"), "", "Iron Grit's Resistance")
	var p := WeaponProfile.new()
	p.name = "Silvered Shortsword"
	p.damage_type = &"slashing"
	var option := {"profile": p, "action_id": "silvered_shortsword", "melee": true}
	assert_true(CmBargains.silvered(option))
	var plain := WeaponProfile.new()
	plain.name = "Shortsword"
	plain.item_id = "shortsword"
	assert_false(CmBargains.silvered({"profile": plain}), "an ordinary blade isn't")
	var st := {}
	e.game.hit_dice(foe, c, option, st)
	e.hit_context = {"attacker": foe.id, "target": c.id, "melee": true}
	var dr := e.deal_damage(foe, c, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Silvered Shortsword")
	e.hit_context = {}
	assert_eq(dr.final, 10, "the silver ignores the Resistance")
	var r := CombatResult.new()
	r.damage = dr.final
	e.game.after_hit(foe, c, option, st, r)
	assert_true(c.creature.has_flag("cant_regain_hp"), "no healing until a rest")
	var fx: Effect = null
	for x: Effect in c.creature.effects:
		if x.source_id == CmBargains.SILVER:
			fx = x
	assert_eq(fx.ends, Effect.Ends.SHORT_REST)
	var dr2 := e.deal_damage(foe, c, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Claw")
	assert_eq(dr2.final, 5, "an ordinary blow is resisted as before")


func test_searing_silver_hurts_even_through_immunity() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["bestial_awakening"]), &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	c.creature.add_effect(Effect.new("Stone Skin", &"feature", "test_immunity").with_modifier("immunity", {"value": "slashing"}))
	assert_eq(e.deal_damage(foe, c, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Claw").final, 0, "immune to an ordinary blade")
	var p := WeaponProfile.new()
	p.name = "Silvered Shortsword"
	p.damage_type = &"slashing"
	var option := {"profile": p, "melee": true}
	e.game.hit_dice(foe, c, option, {})
	e.hit_context = {"attacker": foe.id, "target": c.id, "melee": true}
	var dr := e.deal_damage(foe, c, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Silvered Shortsword")
	e.hit_context = {}
	assert_eq(dr.final, 10, "the silver ignores the Immunity")


# --- Call of the Lonely -------------------------------------------------------------------------------------------

func test_never_alone_calls_a_doppelganger_only_when_unseen_and_it_unsettles_friends() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["call_of_the_lonely"]), &"party", Vector2i(2, 3))
	var ally := e.add(TestChars.custom("fighter", "human", 3), &"party", Vector2i(2, 6))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(_ids(e, c).has("feat:gm:db_never_alone"))
	assert_false(e.feature_actions.perform(c, "gm:db_never_alone", null, Vector2.INF).ok, "seen: it won't come")
	c.creature.add_condition(&"invisible", "test")
	var r := e.feature_actions.perform(c, "gm:db_never_alone", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	var comp: Combatant = null
	for o in e.living():
		if str(o.get_meta("db_companion_of", "")) == c.id:
			comp = o
	assert_true(comp != null, "the companion is here")
	assert_eq(comp.side, &"guest")
	assert_eq(comp.creature.max_hp(), 52, "the Doppelganger's 52 Hit Points")
	assert_eq(comp.creature.armor_class().total(), 14)
	assert_eq(e.order.find(comp), e.order.find(c) + 1, "it acts right after its caller")
	assert_eq(_ch(c).resource_left("never_alone"), 0)
	TestCombat.next_d20(e, 1)
	e.game.turn_start(ally)
	assert_true(ally.creature.has_condition(&"frightened"), "a friend who sees them fails the DC 15 save")


# --- Crooked Fortune ----------------------------------------------------------------------------------------------

func test_cheat_fate_turns_a_failure_into_success_and_the_price_is_three_saves() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["crooked_fortune"]), &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	c.reaction_rules["cheat_fate"] = "auto"
	var ch := _ch(c)
	var t := c.creature.roll_save(e.dice, &"dex", 40, [], [], "test save")
	assert_true(t.success, "the failed save succeeds")
	assert_eq(ch.resource_left("cheat_fate"), 0)
	assert_eq(c.creature.damage_after_save(20, &"dex", true, true, false), 0, "half on a success becomes none")
	for i in 3:
		var before := c.creature.exhaustion
		var t2 := c.creature.roll_save(e.dice, &"con", 1, [], [], "price save %d" % i)
		assert_true("Delayed Price" in t2.disadvantage_sources, "Disadvantage on the price's saves")
		assert_eq(c.creature.exhaustion, before + 1, "a success costs a level of Exhaustion")
		assert_eq(ch.resource_left("cheat_fate"), 1 if i == 2 else 0, "back only after the third")
	var t3 := c.creature.roll_save(e.dice, &"con", 1, [], [], "free again")
	assert_false("Delayed Price" in t3.disadvantage_sources, "the price is paid")
	assert_eq(c.creature.damage_after_save(20, &"con", true, true, false), 10, "no lingering protection")


# --- Cult of Personality ------------------------------------------------------------------------------------------

func test_honeyed_words_turns_a_foe_until_hurt_and_the_charm_proof_are_shaken() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["cult_of_personality"]), &"party", Vector2i(2, 3))
	var ally := e.add(TestChars.custom("fighter", "human", 3), &"party", Vector2i(2, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3))
	TestCombat.start_with(e, c)
	var r := e.feature_actions.perform(c, "gm:db_honeyed_words", foe, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.has_condition(&"charmed"))
	assert_eq(foe.side, &"guest", "it fights on the party's side")
	assert_true(foe.is_player_controlled(), "under the player's command")
	e.deal_damage(ally, foe, [{"amount": 3, "type": "slashing"}], false, "test")
	assert_eq(foe.side, &"enemy", "hurt by the charmer's side, it turns back")
	assert_false(foe.creature.has_condition(&"charmed"))
	assert_true(_has_fx(foe, CmBargains.HONEYED_IMMUNE), "and won't listen again today")
	# The next fight that day: the same creature still won't listen.
	EncounterSetup.clear_fight_effects(foe.creature)
	var e3 := TestCombat.open_field()
	var c3 := e3.add(_ch(c), &"party", Vector2i(2, 3))
	var again := e3.add(foe.creature, &"enemy", Vector2i(5, 3))
	TestCombat.start_with(e3, c3)
	_ch(c3).restore_resource("honeyed_words")
	var r3 := e3.feature_actions.perform(c3, "gm:db_honeyed_words", again, Vector2.INF)
	assert_false(r3.ok, "immune for 24 hours, across fights")
	assert_eq(again.side, &"enemy")
	# A creature that can't be charmed is shaken instead, and the speaker gains Temporary Hit Points.
	var e2 := TestCombat.open_field()
	var c2 := e2.add(_hero(["cult_of_personality"]), &"party", Vector2i(2, 3))
	var proof := e2.add(TestChars.dummy(40, false, {"condition_immunities": ["charmed"]}), &"enemy", Vector2i(5, 3))
	TestCombat.start_with(e2, c2)
	assert_true(e2.feature_actions.perform(c2, "gm:db_honeyed_words", proof, Vector2.INF).ok)
	assert_eq(proof.side, &"enemy")
	assert_true(_has_fx(proof, "db_honeyed_unmoved"), "Disadvantage on its D20 Tests")
	assert_eq(c2.creature.temp_hp, 5, "Temporary Hit Points equal to the level")


func test_solitary_weakness_strips_temp_hp_and_gives_disadvantage_when_alone() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["cult_of_personality"]), &"party", Vector2i(2, 3))
	var ally := e.add(TestChars.custom("fighter", "human", 3), &"party", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	c.creature.add_temp_hp(7, "test")
	e.game.turn_start(c)
	assert_eq(c.creature.temp_hp, 7, "an ally within 20 ft")
	ally.cell = Vector2i(11, 7)
	e.game.turn_start(c)
	assert_eq(c.creature.temp_hp, 0, "alone: the Temporary Hit Points are gone")
	assert_true(_has_fx(c, "db_solitary_weakness"), "and D20 Tests have Disadvantage")


# --- Hand of Death ------------------------------------------------------------------------------------------------

func test_cling_to_life_halves_healing_until_a_humanoid_dies_nearby() -> void:
	var e := TestCombat.open_field()
	var ch := _hero(["hand_of_death"])
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 5)
	ch.hp = 0
	ch.add_condition(&"unconscious", "0 Hit Points")
	e.game.turn_start(c)
	assert_eq(ch.hp, ch.max_hp() / 2, "back with half the maximum")
	assert_eq(ch.resource_left("hand_of_death_cling_to_life"), 0)
	e.game.before_action(c)
	ch.heal(10, "test")
	e.game.after_action(c, {})
	assert_eq(ch.hp, ch.max_hp() / 2 + 5, "only half the healing takes")
	e.deal_damage(c, foe, [{"amount": 50, "type": "slashing"}], false, "test")
	assert_true(foe.creature.dead)
	assert_eq(ch.resource_left("hand_of_death_cling_to_life"), 1, "a Humanoid's death within 30 ft gives it back")
	e.game.before_action(c)
	ch.heal(4, "test")
	e.game.after_action(c, {})
	assert_eq(ch.hp, ch.max_hp() / 2 + 9, "and healing is whole again")


func test_cling_to_life_cheats_death_outright() -> void:
	var e := TestCombat.open_field()
	var ch := _hero(["hand_of_death"])
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	e.deal_damage(foe, c, [{"amount": ch.max_hp() * 3, "type": "slashing"}], false, "Massive blow")
	assert_false(ch.dead, "Massive Damage doesn't kill: Cling to Life")
	assert_eq(ch.hp, ch.max_hp() / 2, "back up with half the maximum")
	assert_eq(ch.resource_left("hand_of_death_cling_to_life"), 0)
	e.deal_damage(foe, c, [{"amount": ch.max_hp() * 3, "type": "slashing"}], false, "Massive blow")
	assert_true(ch.dead, "once used, death comes")


func test_death_knell_hampers_death_saves_and_no_healing_lifts_the_fallen() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["hand_of_death"]), &"party", Vector2i(2, 3))
	var ally := e.add(TestChars.custom("fighter", "human", 3), &"party", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	ally.creature.hp = 0
	var keys: Array[String] = ["save:all", "death_save"]
	var d := e.game.before_d20(ally, D20Test.Kind.SAVING_THROW, keys)
	assert_true(str(d.get("disadvantage", [])).contains("Death Knell"), "within 10 ft: Disadvantage on Death Saves")
	e.game.before_action(c)
	ally.creature.heal(8, "Lay on Hands")
	e.game.after_action(c, {})
	assert_eq(ally.creature.hp, 0, "the knell-bearer can't bring them up")
	ally.cell = Vector2i(8, 7)
	d = e.game.before_d20(ally, D20Test.Kind.SAVING_THROW, keys)
	assert_false(d.has("disadvantage"), "out of reach")


# --- Might of the Old ---------------------------------------------------------------------------------------------

func test_primeval_strength_brings_strength_25_and_the_pyres_price() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["might_of_the_old"]), &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_eq(c.creature.vulnerability_source(&"fire"), "", "no Vulnerability before")
	var r := e.feature_actions.perform(c, "recipe:primeval_strength", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_eq(c.creature.ability_score(&"str"), 25)
	assert_true(c.creature.has_flag("siege_monster"), "double damage to objects")
	assert_ne(c.creature.vulnerability_source(&"fire"), "", "bark skin: Vulnerable to Fire")
	var bark: Effect = null
	for x: Effect in c.creature.effects:
		if x.source_id == CmBargains.PYRE:
			bark = x
	assert_eq(bark.ends, Effect.Ends.LONG_REST, "until a Long Rest")


# --- Self-Serving Sacrifice ---------------------------------------------------------------------------------------

func test_critical_savior_swaps_places_and_trades_the_toll() -> void:
	var e := TestCombat.open_field()
	var p := e.add(_hero(["self_serving_sacrifice"], 4), &"party", Vector2i(2, 3))
	var ally := e.add(TestChars.custom("fighter", "human", 3), &"party", Vector2i(6, 5))
	var foe := TestCombat.punching_bag(e, Vector2i(7, 5))
	TestCombat.start_with(e, p)
	p.reaction_rules["critical_savior"] = "auto"
	var p_cell := p.cell
	var a_cell := ally.cell
	var p_hp := p.creature.hp
	_ch(p).heroic_inspiration = false
	p.creature.exhaustion = 1
	e.deal_damage(foe, ally, [{"amount": 6, "type": "slashing"}], true, "test crit")
	var a_hp := ally.creature.hp
	e.run_reaction_queue(CombatResult.new())
	assert_eq(_ch(p).resource_left("critical_savior"), 0, "used")
	assert_eq(p.cell, a_cell, "the savior stands where the ally stood")
	assert_eq(ally.cell, p_cell, "and the ally where the savior stood")
	var toll := p_hp - p.creature.hp
	assert_true(toll >= 2 and toll <= 12, "2d6 Force at level 4 (%d)" % toll)
	assert_eq(ally.creature.hp - a_hp, mini(toll, ally.creature.max_hp() - a_hp), "the ally regains as much")
	assert_true(_ch(p).heroic_inspiration, "Heroic Inspiration")
	assert_eq(p.creature.exhaustion, 0, "a level of Exhaustion gone")
	assert_eq(ally.creature.exhaustion, 1, "the ally gains one")


# --- Shrouded Spirit ----------------------------------------------------------------------------------------------

func test_inured_to_undeath_advantage_on_saves_against_undead() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["shrouded_spirit"]), &"party", Vector2i(2, 3))
	var ghoul := TestCombat.punching_bag(e, Vector2i(5, 3), 30, "undead")
	var man := TestCombat.punching_bag(e, Vector2i(6, 3), 30, "humanoid")
	assert_ne(c.creature.resistance_source(&"necrotic"), "", "Resistance to Necrotic")
	var keys: Array[String] = ["save:all", "save:wis", "save_vs:spell", "save_vs:spell:" + ghoul.id]
	assert_true("Inured to Undeath" in (e.game.before_d20(c, D20Test.Kind.SAVING_THROW, keys).get("advantage", []) as Array))
	var keys2: Array[String] = ["save:all", "save:wis", "save_vs:spell", "save_vs:spell:" + man.id]
	assert_false(e.game.before_d20(c, D20Test.Kind.SAVING_THROW, keys2).has("advantage"), "not against the living")


# --- Skin of Coffin Nails -----------------------------------------------------------------------------------------

func test_iron_grit_turns_a_critical_of_its_type_into_a_hit() -> void:
	var e := TestCombat.open_field()
	var foe := e.add(TestChars.custom("fighter", "human", 3), &"enemy", Vector2i(3, 3))
	var option := e.attack_options(foe)[0]
	var ty := str((option["profile"] as WeaponProfile).damage_type)
	var c := e.add(_hero(["skin_of_coffin_nails"], 5, {"gift.skin_of_coffin_nails.iron_grit": [ty]}), &"party", Vector2i(2, 3))
	assert_ne(c.creature.resistance_source(StringName(ty)), "", "Resistance to the chosen type")
	TestCombat.start_with(e, foe)
	TestCombat.next_d20(e, 20)
	var r := e.attack(foe, c, str(option["id"]))
	assert_true(r.hit, "a natural 20 hits")
	assert_false(r.critical, "but Iron Grit makes it a normal hit")
	var other := ["bludgeoning", "piercing", "slashing"].filter(func(x: String) -> bool: return x != ty)[0] as String
	_ch(c).choices()[CmBargains.IRON_GRIT_KEY] = [other]
	_ch(c).refresh()
	foe.action_available = true
	foe.attacks_left = 0
	TestCombat.next_d20(e, 20)
	assert_true(e.attack(foe, c, str(option["id"])).critical, "another type still crits")


func test_watery_doom_rusts_the_skin_in_deep_water() -> void:
	var rows: Array[String] = ["......", "..w...", "......"]
	var e := TestCombat.encounter(rows)
	var c := e.add(_hero(["skin_of_coffin_nails"], 5, {"gift.skin_of_coffin_nails.iron_grit": ["slashing"]}), &"party", Vector2i(0, 0))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 2))
	var speed := c.creature.speed().total()
	assert_eq(e.deal_damage(foe, c, [{"amount": 10, "type": "slashing"}], false, "test").final, 5, "resisted while dry")
	c.cell = Vector2i(2, 1)
	e.game.entered_cell(c, c.cell)
	assert_true(c.creature.has_flag(CmBargains.RUSTED), "soaked")
	assert_eq(c.creature.speed().total(), speed / 2, "half Speed")
	assert_eq(e.deal_damage(foe, c, [{"amount": 10, "type": "slashing"}], false, "test").final, 20, "the Resistance is Vulnerability now")


# --- Stilled Hungers ----------------------------------------------------------------------------------------------

func test_tenuous_psyche_is_held_off_by_calm_emotions() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["stilled_hungers"]), &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(5, 3))
	assert_eq(e.deal_damage(foe, c, [{"amount": 10, "type": "psychic"}], false, "test").final, 20, "Vulnerable to Psychic")
	c.creature.add_effect(Effect.new("Calm Emotions", &"spell", "calm_emotions"))
	assert_eq(e.deal_damage(foe, c, [{"amount": 10, "type": "psychic"}], false, "test").final, 10, "suppressed while calmed")
	var keys: Array[String] = ["save:all", "save:wis", "save_vs:frightened"]
	assert_true(e.game.before_d20(c, D20Test.Kind.SAVING_THROW, keys).has("advantage"), "the fear save's Disadvantage is cancelled")


# --- Unquenchable Fury --------------------------------------------------------------------------------------------

func test_furious_onslaught_adds_an_attack_and_cuts_damage() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["unquenchable_fury"]), &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, c)
	var before := e.attacks_per_action(c)
	var r := e.feature_actions.perform(c, "gm:db_furious_onslaught", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_false(c.bonus_available, "a Bonus Action")
	assert_eq(e.attacks_per_action(c), before + 1, "one more attack with the Attack action")
	var pb := c.creature.proficiency_bonus()
	assert_eq(e.deal_damage(foe, c, [{"amount": 10, "type": "slashing"}], false, "test").final, 10 - pb, "the Proficiency Bonus off")
	assert_eq(_ch(c).resource_left("furious_onslaught"), 0)
	e.deal_damage(c, foe, [{"amount": 500, "type": "slashing"}], false, "test")
	assert_eq(_ch(c).resource_left("furious_onslaught"), 1, "killing a Humanoid gives it back")


func test_red_haze_hands_the_hero_to_its_rage_against_the_nearest() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["unquenchable_fury"]), &"party", Vector2i(2, 3))
	var friend := e.add(TestChars.custom("fighter", "human", 3), &"party", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	assert_true(e.feature_actions.perform(c, "gm:db_furious_onslaught", null, Vector2.INF).ok)
	TestCombat.next_d20(e, 1)
	e.game.turn_start(c)
	assert_true(c.has_meta("db_red_haze"), "the DC 15 save failed")
	assert_false(c.is_player_controlled(), "the rage plays the turn")
	var hp := friend.creature.hp
	c.action_available = true
	for i in 4:
		TestCombat.next_d20(e, 20)
	var turn: Variant = e.game.monster_turn(c)
	assert_true(turn is CombatResult)
	assert_true(friend.creature.hp < hp, "the nearest creature, an ally, is the enemy now")
	e.game.on_death(null, c)
	assert_true(c.is_player_controlled(), "with the fury gone, the player has the hero back")


# --- Wings of Whispers --------------------------------------------------------------------------------------------

func test_murderous_flight_leaves_whispering_crows() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_hero(["wings_of_whispers"]), &"party", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(9, 3))
	TestCombat.start_with(e, c)
	var r := e.feature_actions.perform(c, "recipe:murderous_flight", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_true(c.creature.has_flag(CmBargains.CROWS), "the crows stay")
	var keys: Array[String] = c.creature.check_keys(&"stealth")
	var src := c.creature.d20_sources(keys)
	assert_true(str(src["disadvantage"]).contains("Whispering Crows"), "Disadvantage on Stealth")
	c.hidden = true
	var skeys: Array[String] = ["check:all", "check:perception", "check:wis", "search"]
	assert_true("Whispered Secrets" in (e.game.before_d20(foe, D20Test.Kind.ABILITY_CHECK, skeys).get("advantage", []) as Array),
		"a searcher has Advantage to find the hero")
	# Again before a rest, for a level of Exhaustion.
	c.bonus_available = true
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == "murderous_flight":
			c.creature.remove_effect(fx)
	assert_true(_ids(e, c).has("feat:gm:db_murderous_flight_again"))
	assert_true(e.feature_actions.perform(c, "gm:db_murderous_flight_again", null, Vector2.INF).ok)
	assert_eq(c.creature.exhaustion, 1)
