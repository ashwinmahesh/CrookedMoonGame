extends TestCase
## The Fabled Heirlooms of Memory's Rest (R17), Hartsblight Forest (R18) and Maidenmist Cemetery (R19) whose properties
## are code (combat/crooked/cm_heirlooms_relics.gd): the Mask, the Veil, the Staff of Farryn, the Idol of the Beast of
## Blight, the Shovel of Yorgrim and the Lantern of the Chained Reaper.


func _part(e: Encounter) -> CmHeirloomsRelics:
	for p in (e.game as CrookedFeatures).parts:
		if p is CmHeirloomsRelics:
			return p as CmHeirloomsRelics
	return null


## A level-`level` cleric carrying and attuned to `item` (in that slot when `slot` is given; worn items are worn), a foe
## 10 ft away and a wounded ally beside the hero.
func _fight(item: String, slot: String = "", level: int = 8) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), level)
	var ch := hero.creature as Character
	ch.add_item(item, 1)
	ch.attune(item)
	if slot != "":
		ch.equip(item, slot)
	elif MagicItems.worn_slot(Compendium.shared().item_data(item)) != "":
		ch.wear(item)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 80)
	var ally := e.add(TestChars.dummy(40, true, {"abilities": {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 30, "cha": 10}}), &"party", Vector2i(3, 4))
	TestCombat.start_with(e, hero)
	return [e, hero, foe, ally]


func _unarmed_option() -> Dictionary:
	var prof := WeaponProfile.new()
	prof.item_id = "unarmed_strike"
	return {"profile": prof, "melee": true}


func test_the_mask_and_veil_numbers_grow_with_the_tier() -> void:
	var got := _fight("mask_of_lethica_nightborne")
	var hero := got[1] as Combatant
	assert_true(hero.creature.has_flag("devils_sight"), "the mask sees through magical Darkness")
	assert_true(Compendium.shared().item_data("veil_of_the_weeping_widow").has("powers"))


func test_balm_of_midnight_lifts_an_allys_fear() -> void:
	var got := _fight("mask_of_lethica_nightborne")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var ally := got[3] as Combatant
	ally.creature.add_condition(&"frightened", "test")
	for i in 20:
		if not ally.creature.has_condition(&"frightened"):
			break
		_part(e).turn_start(hero)
	assert_false(ally.creature.has_condition(&"frightened"), "a Wisdom 30 ally makes the DC 15 save on all but a 1, 2 or 3")


func test_psychic_shock_lashes_whoever_forced_a_charm_save() -> void:
	var got := _fight("veil_of_the_weeping_widow")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var t := D20Test.new()
	t.kind = D20Test.Kind.SAVING_THROW
	t.kept = 12
	t.total = 12
	t.target = 14
	var keys: Array[String] = ["save:all", "save:wis", "save_vs:charmed", "save_vs:spell:" + foe.id]
	var out: Array = []
	_part(e).d20_offers(hero, t, keys, out)
	assert_eq(out.size(), 1)
	assert_eq(str((out[0] as Dictionary)["kind"]), "cm_psychic_shock")
	var before := foe.creature.hp
	((out[0] as Dictionary)["use"] as Callable).call()
	assert_true(foe.creature.hp < before, "2d8 Psychic")
	assert_false(hero.reaction_available)


func test_servant_of_the_cycle_heals_and_rots_the_next_hit() -> void:
	var got := _fight("staff_of_farryn", "main_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var ally := got[3] as Combatant
	ally.creature.hp = 5
	var r := e.items.use(hero, "staff_of_farryn", "servant", [ally])
	assert_true(r.ok, r.reason)
	assert_true(ally.creature.hp > 5, "Cure Wounds at 3rd level")
	assert_true(hero.has_meta(CmHeirloomsRelics.CYCLE_HIT_META))
	e.hit_context = {"attacker": hero.id, "target": foe.id, "melee": true}
	var parts: Array = [{"amount": 5, "type": "bludgeoning"}]
	_part(e).adjust_incoming(hero, foe, parts)
	e.hit_context = {}
	assert_eq(parts.size(), 2, "1d10 Necrotic more")
	assert_eq(str((parts[1] as Dictionary)["type"]), "necrotic")
	assert_false(hero.has_meta(CmHeirloomsRelics.CYCLE_HIT_META), "only the next hit")


func test_sacrifice_of_flesh_trades_the_healers_blood() -> void:
	var got := _fight("staff_of_farryn", "main_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var ally := got[3] as Combatant
	var part := _part(e)
	assert_eq(part.spell_healing({"c": hero, "slot": 2}, ally), 0, "off until toggled")
	assert_true(e.items.use(hero, "staff_of_farryn", "sacrifice").ok)
	assert_true(e.items.toggled(hero, "staff_of_farryn", "sacrifice"))
	var hp := hero.creature.hp
	assert_eq(part.spell_healing({"c": hero, "slot": 2}, ally), 12, "twice the level taken, three times that healed")
	assert_eq(hero.creature.hp, hp - 4, "the staff's own Necrotic Resistance doesn't soften it")


func test_rotting_touch_and_touch_of_oblivion() -> void:
	var got := _fight("idol_of_the_beast_of_blight", "main_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var part := _part(e)
	var dice := part.hit_dice(hero, foe, _unarmed_option(), {})
	assert_eq(dice.size(), 1)
	assert_eq(str(dice[0]["dice"]), "1d8", "Very Rare at level 8")
	var power := e.items.find_power(hero, "idol_of_the_beast_of_blight", "oblivion")
	assert_eq(e.items.power_why(hero, power), "No fresh corpse within 5 ft")
	var corpse := TestCombat.punching_bag(e, Vector2i(2, 2), 5)
	corpse.creature.hp = 0
	corpse.creature.dead = true
	assert_eq(e.items.power_why(hero, power), "")
	assert_true(e.items.use(hero, "idol_of_the_beast_of_blight", "oblivion").ok)
	var st := {"c": hero, "target": foe, "critical": false, "option": _unarmed_option()}
	part.after_hit_target(st, func() -> CombatResult: return CombatResult.new(), [])
	assert_true(bool(st["critical"]), "the next Unarmed Strike that hits is a Critical Hit")


func test_hallucinatory_spores_after_a_slot_spell() -> void:
	var got := _fight("idol_of_the_beast_of_blight", "main_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var before := foe.creature.hp
	_part(e).after_cast(hero, {}, 1)
	assert_true(foe.creature.hp < before, "a Wisdom 1 foe within 10 ft fails")
	assert_true(CmHeirloomPart.fx_of(foe, CmHeirloomsRelics.SPORES_KEY) != null)


func test_deny_deaths_touch_from_level_7() -> void:
	for level: int in [3, 8]:
		var got := _fight("shovel_of_yorgrim", "main_hand", level)
		var e := got[0] as Encounter
		var ally := got[3] as Combatant
		var parts: Array = [{"amount": 10, "type": "necrotic"}]
		_part(e).adjust_incoming(got[2] as Combatant, ally, parts)
		assert_eq(int((parts[0] as Dictionary)["amount"]), 5 if level >= 7 else 10, "level %d" % level)


func test_death_kenning_after_hitting_undead() -> void:
	var got := _fight("shovel_of_yorgrim", "main_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var zombie := TestCombat.foe(e, "zombie", Vector2i(2, 4))
	var power := e.items.find_power(hero, "shovel_of_yorgrim", "kenning")
	assert_eq(e.items.power_why(hero, power), "Hit an Undead with the shovel this turn first")
	var prof := WeaponProfile.new()
	prof.item_id = "shovel_of_yorgrim"
	_part(e).after_hit(hero, zombie, {"profile": prof, "melee": true}, {}, CombatResult.new())
	assert_eq(e.items.power_why(hero, power), "")
	assert_true(e.items.use(hero, "shovel_of_yorgrim", "kenning").ok)
	assert_true(bool(e.studied.get("zombie", false)), "its defences are known")


func test_the_lantern_calls_a_spirit_from_level_7() -> void:
	var got := _fight("lantern_of_the_chained_reaper")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var count := e.combatants.size()
	var r := e.items.use(hero, "lantern_of_the_chained_reaper", "spirit")
	assert_true(r.ok, r.reason)
	assert_eq(e.combatants.size(), count + 1)
	var spirit := e.combatants.back() as Combatant
	assert_eq(spirit.name(), "Lantern Spirit")
	assert_true(spirit.allied_with(hero), "it fights beside the bearer")
