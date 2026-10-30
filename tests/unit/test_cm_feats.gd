extends TestCase
## The Crooked Moon's feats in a fight (combat/crooked/cm_feats.gd): Grave Keeper's Turn Undead and added Channel
## Divinity, Hunter of Hunters, Fate Gambler, Altered's Night Vision, Dread Speech, Ghostlight Medium, Death Defier and
## Swift Witchcraft.


func before_each() -> void:
	GameFeatures.use(null)


## A hero of `class_id` whose background brings the feat (or `picks` give it), in a fight with one foe 10 ft away.
func _fight(class_id: String, background: String, picks: Dictionary = {}, level: int = 1, species: String = "dwarf", foe_data: Dictionary = {}) -> Dictionary:
	var e := TestCombat.open_field()
	var ch := TestChars.custom(class_id, species, level, picks, background)
	ch.heroic_inspiration = false
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var m := TestChars.dummy(80, false, foe_data)
	var foe := e.add(m, &"enemy", Vector2i(4, 3))
	return {"e": e, "c": c, "ch": ch, "foe": foe}


func _ids(e: Encounter, c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for x in e.feature_actions.list(c):
		out.append(str(x["id"]))
	return out


func _logged(e: Encounter, needle: String) -> bool:
	for en in e.log.entries:
		if str(en.get("text", "")).contains(needle) or str(en.get("details", [])).contains(needle):
			return true
	return false


# --- Grave Keeper ---------------------------------------------------------------------------------------------------

func test_grave_keeper_turns_undead_for_a_fighter_with_its_own_dc() -> void:
	var sc := _fight("fighter", "rest_warden", {}, 1, "dwarf", {"type": "undead"})
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	var foe := sc["foe"] as Combatant
	TestCombat.start_with(e, c)
	assert_eq(ch.resource_left("grave_keeper_channel"), 1, "the feat's one use")
	assert_true("feat:gm:ft_turn_undead" in _ids(e, c))
	var dc := 8 + ch.proficiency_bonus() + ch.ability_mod(&"wis")
	TestCombat.next_d20(e, 1)
	var r := e.feature_actions.perform(c, "gm:ft_turn_undead", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "turn_undead" and fx.caster_id == c.id), "Turned")
	assert_true(foe.creature.has_condition(&"frightened") and foe.creature.has_condition(&"incapacitated"))
	assert_true(_logged(e, "DC %d" % dc), "DC 8 + Wis + PB = %d" % dc)
	assert_eq(ch.resource_left("grave_keeper_channel"), 0, "the use is spent")
	assert_false(c.action_available, "a Magic action")


func test_grave_keeper_adds_a_use_to_a_clerics_channel_divinity() -> void:
	var sc := _fight("cleric", "rest_warden", {}, 2)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	TestCombat.start_with(e, c)
	assert_false("feat:gm:ft_turn_undead" in _ids(e, c), "the Cleric turns undead with its own entry")
	var base := ch.resource_max("channel_divinity")
	assert_true(base > 0)
	ch.spend_resource("channel_divinity", base)
	e.game.turn_end(c)
	assert_eq(ch.resource_left("channel_divinity"), 1, "one more use once the class's run dry")
	assert_eq(ch.resource_left("grave_keeper_channel"), 0)
	ch.spend_resource("channel_divinity")
	e.game.turn_end(c)
	assert_eq(ch.resource_left("channel_divinity"), 0, "only one")


# --- Hunter of Hunters --------------------------------------------------------------------------------------------

func test_dead_aim_ignores_resistance_on_the_next_damage_only() -> void:
	var sc := _fight("fighter", "night_stalker", {}, 1, "dwarf", {"resistances": ["slashing"]})
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	TestCombat.start_with(e, c)
	var r := e.feature_actions.perform(c, "gm:ft_dead_aim", foe, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_false(c.bonus_available, "a Bonus Action")
	var hp := foe.creature.hp
	e.deal_damage(c, foe, [{"amount": 10, "type": "slashing"}], false, "Test")
	assert_eq(hp - foe.creature.hp, 10, "Resistance ignored")
	hp = foe.creature.hp
	e.deal_damage(c, foe, [{"amount": 10, "type": "slashing"}], false, "Test")
	assert_eq(hp - foe.creature.hp, 5, "only the next damage")


func test_dead_aim_ends_at_the_start_of_the_hunters_next_turn() -> void:
	var sc := _fight("fighter", "night_stalker", {}, 1, "dwarf", {"resistances": ["slashing"]})
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	TestCombat.start_with(e, c)
	e.feature_actions.perform(c, "gm:ft_dead_aim", foe, Vector2.INF)
	e.game.turn_start(c)
	var hp := foe.creature.hp
	e.deal_damage(c, foe, [{"amount": 10, "type": "slashing"}], false, "Test")
	assert_eq(hp - foe.creature.hp, 5, "the mark is gone")


func test_studied_quarry_gives_advantage_on_the_study_check() -> void:
	var sc := _fight("fighter", "night_stalker")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	TestCombat.start_with(e, c)
	assert_true(e.study(c, sc["foe"] as Combatant).ok)
	assert_true(_logged(e, "Studied Quarry"), "Advantage from Studied Quarry")


# --- Fate Gambler -------------------------------------------------------------------------------------------------

func test_bet_big_on_a_drop_and_a_forced_failed_save_once_per_turn() -> void:
	var sc := _fight("fighter", "crossroads_gambler")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	var foe := sc["foe"] as Combatant
	TestCombat.start_with(e, c)
	e.class_features._save(foe, &"wis", 30, "Test")
	e.game.turn_end(c)
	assert_true(ch.heroic_inspiration, "a CR 1 foe failed a save the hero forced")
	ch.heroic_inspiration = false
	e.class_features._save(foe, &"wis", 30, "Test")
	e.game.turn_end(c)
	assert_false(ch.heroic_inspiration, "once per turn")
	e.round_no += 1
	e.deal_damage(c, foe, [{"amount": 500, "type": "force"}], false, "Test")
	assert_true(ch.heroic_inspiration, "dropping a CR 1 foe")


func test_bet_big_ignores_creatures_without_a_challenge_rating() -> void:
	var sc := _fight("fighter", "crossroads_gambler")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	var foe := sc["foe"] as Combatant
	(foe.creature as Monster).cr = 0.0
	TestCombat.start_with(e, c)
	e.class_features._save(foe, &"wis", 30, "Test")
	e.deal_damage(c, foe, [{"amount": 500, "type": "force"}], false, "Test")
	e.game.turn_end(c)
	assert_false(ch.heroic_inspiration, "CR 0")


func test_win_big_trades_inspiration_for_temporary_hit_points_equal_to_level() -> void:
	var sc := _fight("fighter", "crossroads_gambler", {}, 3)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	TestCombat.start_with(e, c)
	assert_false(e.feature_actions.perform(c, "gm:ft_win_big", null, Vector2.INF).ok, "needs Heroic Inspiration")
	ch.heroic_inspiration = true
	var r := e.feature_actions.perform(c, "gm:ft_win_big", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_eq(ch.temp_hp, 3)
	assert_false(ch.heroic_inspiration)
	assert_false(c.bonus_available)


# --- Altered ------------------------------------------------------------------------------------------------------

func test_night_vision_adds_30_ft_to_darkvision_a_hero_already_has() -> void:
	var picks := {"altered_augmentation": ["night_vision"]}
	var sc := _fight("fighter", "experiment", picks, 1, "elf")
	var e := sc["e"] as Encounter
	var ch := sc["ch"] as Character
	var before := TestChars.custom("fighter", "elf", 1).darkvision()
	assert_true(before > 0, "an elf sees in the dark")
	TestCombat.start_with(e, sc["c"] as Combatant)
	assert_eq(ch.darkvision(), before + 30)
	var sc2 := _fight("fighter", "experiment", picks, 1, "human")
	TestCombat.start_with(sc2["e"] as Encounter, sc2["c"] as Combatant)
	assert_eq((sc2["ch"] as Character).darkvision(), 60, "without Darkvision: 60 ft")


# --- Dread Speech -------------------------------------------------------------------------------------------------

func test_eldritch_word_frightens_then_costs_hit_points_once_the_safe_use_is_gone() -> void:
	var sc := _fight("fighter", "scholar_of_the_forbidden", {"eldritch_word.spellcasting_ability": ["int"]})
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	var foe := sc["foe"] as Combatant
	TestCombat.start_with(e, c)
	var dc := 8 + ch.proficiency_bonus() + ch.ability_mod(&"int")
	TestCombat.next_d20(e, 1)
	var r := e.feature_actions.perform(c, "gm:ft_eldritch_word", foe, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.has_condition(&"frightened"))
	assert_true(_logged(e, "vs DC %d" % dc), "DC 8 + PB + Int = %d" % dc)
	assert_eq(ch.resource_left("eldritch_word"), 0)
	var label := ""
	for x in e.feature_actions.list(c):
		if str(x["id"]) == "feat:gm:ft_eldritch_word":
			label = "%s %s" % [x["label"], x["sub"]]
	assert_true(label.contains("1d6"), "the button shows the price: %s" % label)
	c.bonus_available = true
	var hp := ch.hp
	r = e.feature_actions.perform(c, "gm:ft_eldritch_word", foe, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_true(hp - ch.hp >= 1 and hp - ch.hp <= 6, "1d6 Necrotic: %d" % (hp - ch.hp))


func test_eldritch_word_fear_ends_at_the_start_of_the_speakers_next_turn() -> void:
	var sc := _fight("fighter", "scholar_of_the_forbidden")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 1)
	e.feature_actions.perform(c, "gm:ft_eldritch_word", foe, Vector2.INF)
	var fx: Effect = null
	for x: Effect in foe.creature.effects:
		if x.source_id == "ft_eldritch_word":
			fx = x
	assert_true(fx != null)
	assert_eq(fx.ends, Effect.Ends.START_OF_TURN)
	assert_eq(fx.turn_owner_id, c.id)


# --- Ghostlight Medium --------------------------------------------------------------------------------------------

func test_ghostly_touch_ignores_an_incorporeal_creatures_resistance() -> void:
	var ghost := {"type": "undead", "resistances": ["slashing"], "traits": [{"id": "incorporeal_movement", "name": "Incorporeal Movement",
		"modifiers": [{"stat": "flag", "value": "incorporeal_movement"}]}]}
	var sc := _fight("fighter", "ghostlight_passenger", {}, 1, "dwarf", ghost)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var foe := sc["foe"] as Combatant
	TestCombat.start_with(e, c)
	var hp := foe.creature.hp
	e.deal_damage(c, foe, [{"amount": 10, "type": "slashing"}], false, "Test")
	assert_eq(hp - foe.creature.hp, 10)
	var sc2 := _fight("fighter", "soldier", {}, 1, "dwarf", ghost)
	var e2 := sc2["e"] as Encounter
	TestCombat.start_with(e2, sc2["c"] as Combatant)
	var foe2 := sc2["foe"] as Combatant
	hp = foe2.creature.hp
	e2.deal_damage(sc2["c"] as Combatant, foe2, [{"amount": 10, "type": "slashing"}], false, "Test")
	assert_eq(hp - foe2.creature.hp, 5, "without the feat it resists")


func test_spirit_sense_finds_hidden_undead_and_is_spent_only_when_it_senses_one() -> void:
	var sc := _fight("fighter", "ghostlight_passenger")
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	TestCombat.start_with(e, c)
	var r := e.feature_actions.perform(c, "gm:ft_spirit_sense", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_eq(ch.resource_left("spirit_sense"), 1, "nothing sensed: not spent")
	var sc2 := _fight("fighter", "ghostlight_passenger", {}, 1, "dwarf", {"type": "undead"})
	var e2 := sc2["e"] as Encounter
	var c2 := sc2["c"] as Combatant
	var ghoul := sc2["foe"] as Combatant
	TestCombat.start_with(e2, c2)
	ghoul.hidden = true
	r = e2.feature_actions.perform(c2, "gm:ft_spirit_sense", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	assert_false(ghoul.hidden, "found")
	assert_eq((sc2["ch"] as Character).resource_left("spirit_sense"), 0)


# --- Death Defier -------------------------------------------------------------------------------------------------

func test_cling_to_life_adds_constitution_to_death_saves() -> void:
	var sc := _fight("fighter", "soldier", {".4.ability_score_improvement": ["death_defier"]}, 4)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	TestCombat.start_with(e, c)
	e.deal_damage(sc["foe"] as Combatant, c, [{"amount": ch.hp, "type": "force"}], false, "Test")
	assert_eq(ch.hp, 0)
	TestCombat.next_d20(e, 9)
	var r := e.death_save(c, false)
	assert_true(r.ok, r.reason)
	assert_eq(ch.death_successes, 1, "9 + Con (at least 1) reaches 10")
	assert_true(_logged(e, "Cling to Life %d" % maxi(1, ch.ability_mod(&"con"))))


func test_enduring_vitality_turns_massive_damage_into_hit_points_equal_to_level_once() -> void:
	var sc := _fight("fighter", "soldier", {".4.ability_score_improvement": ["death_defier"]}, 4)
	var e := sc["e"] as Encounter
	var c := sc["c"] as Combatant
	var ch := sc["ch"] as Character
	TestCombat.start_with(e, c)
	e.deal_damage(sc["foe"] as Combatant, c, [{"amount": ch.hp + ch.max_hp() + 5, "type": "force"}], false, "Test")
	assert_false(ch.dead, "Enduring Vitality")
	assert_eq(ch.hp, 4, "Hit Points equal to level")
	assert_eq(ch.resource_left("enduring_vitality"), 0)
	e.deal_damage(sc["foe"] as Combatant, c, [{"amount": ch.hp + ch.max_hp() + 5, "type": "force"}], false, "Test")
	assert_true(ch.dead, "once per Long Rest")


# --- Swift Witchcraft ---------------------------------------------------------------------------------------------

func test_swift_invocation_casts_a_one_minute_spell_as_an_action_once() -> void:
	# A 1-minute healing spell made for the test (the 1-minute spells the fight can run need corpses or high levels).
	var spells := Compendium.shared().table("spells")
	var slow := Compendium.shared().spell_data("cure_wounds").duplicate(true)
	slow["id"] = "test_slow_mending"
	slow["name"] = "Slow Mending"
	slow["classes"] = ["wizard"]
	slow["casting_time"] = {"unit": "minute", "amount": 1}
	spells["test_slow_mending"] = slow
	var e := TestCombat.open_field()
	var ch := TestChars.custom("wizard", "dwarf", 5, {".4.ability_score_improvement": ["swift_witchcraft"]})
	((ch.spellcasting[0] as Dictionary)["prepared"] as Array).append("test_slow_mending")
	var c := e.add(ch, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3))
	var plain := TestChars.custom("wizard", "dwarf", 5)
	((plain.spellcasting[0] as Dictionary)["prepared"] as Array).append("test_slow_mending")
	var p := e.add(plain, &"party", Vector2i(2, 5))
	TestCombat.start_with(e, c)
	assert_false(bool(_spell_entry(e, p, "test_slow_mending")["legal"]), "too long to cast in a fight without the feat")
	assert_true(bool(_spell_entry(e, c, "test_slow_mending")["legal"]), "an action with Swift Invocation: %s" % _spell_entry(e, c, "test_slow_mending")["reason"])
	ch.hp = 1
	var slots := ch.slots_left(1)
	var r := e.spells.cast(c, "test_slow_mending", 1, [c])
	assert_true(r.ok, r.reason)
	assert_true(ch.hp > 1, "the spell works")
	assert_false(c.action_available, "a Magic action")
	assert_eq(ch.slots_left(1), slots - 1, "its slot")
	assert_eq(ch.resource_left("swift_invocation"), 0)
	assert_true(str(_spell_entry(e, c, "test_slow_mending")["reason"]).begins_with("Takes too long"), "once per Long Rest")
	spells.erase("test_slow_mending")


func _spell_entry(e: Encounter, c: Combatant, spell_id: String) -> Dictionary:
	for x in e.spells.castable(c):
		if str(x["id"]) == spell_id:
			return x
	return {}
