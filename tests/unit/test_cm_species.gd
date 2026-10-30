extends TestCase
## The Crooked Moon's species in a fight (combat/crooked/cm_species.gd): each trait that needs code, on a hero built
## with the book's species, with scripted d20s where the numbers matter.


func _hero(e: Encounter, class_id: String, species: String, cell: Vector2i, level: int = 3, picks: Dictionary = {}) -> Combatant:
	return e.add(TestChars.custom(class_id, species, level, picks), &"party", cell)


func _ch(c: Combatant) -> Character:
	return c.creature as Character


func _find(e: Encounter, c: Combatant, id: String) -> Dictionary:
	return ActionCatalog.new(e).find(c, id)


func _perform(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF) -> CombatResult:
	var a := _find(e, c, id)
	if a.is_empty():
		return CombatResult.fail("no action " + id)
	return ActionCatalog.new(e).perform(c, a, targets, point)


func _logged(e: Encounter, text: String) -> bool:
	return str(e.log.entries).contains(text)


func _has_fx(c: Combatant, source_id: String) -> bool:
	return c.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == source_id)


## A natural d20 that makes `attacker`'s first attack on `target` land exactly on AC (a hit by 0).
func _just_hit(e: Encounter, attacker: Combatant, target: Combatant) -> String:
	var opt := str(e.attack_options(attacker)[0]["id"])
	var bonus := (e.option_by_id(attacker, opt)["profile"] as WeaponProfile).attack.total()
	TestCombat.next_d20(e, clampi(target.creature.ac_value() - bonus, 2, 19))
	return opt


# --- Graveborn -------------------------------------------------------------------------------------------------------

func test_infused_drakkonite_ignores_resistance_and_adds_necrotic_once() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "graveborn", Vector2i(2, 3))
	var foe := e.add(TestChars.dummy(100, false, {"resistances": ["slashing"]}), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	var pb := c.creature.proficiency_bonus()
	var dr := e.deal_damage(c, foe, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Sword")
	assert_eq(dr.final, 10 + pb, "Resistance ignored, + PB Necrotic, on its own against a foe that resists")
	assert_eq(_ch(c).resource_left("infused_drakkonite"), 0, "once per Short Rest")
	var dr2 := e.deal_damage(c, foe, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Sword")
	assert_eq(dr2.final, 5, "spent: the Resistance holds again")


# --- Harvestborn -----------------------------------------------------------------------------------------------------

func test_culling_adds_a_d12_against_a_bloodied_foe() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "harvestborn", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	var pb := c.creature.proficiency_bonus()
	var fresh := e.deal_damage(c, foe, [{"amount": 5, "type": "fire", "spell": true}], false, "Spell")
	assert_eq(fresh.final, 5, "not Bloodied yet: nothing")
	assert_eq(_ch(c).resource_left("culling"), pb)
	foe.creature.hp = 60
	var dr := e.deal_damage(c, foe, [{"amount": 5, "type": "fire", "spell": true}], false, "Spell")
	assert_true(dr.final >= 6 and dr.final <= 17, "5 + 1d12 Necrotic: %d" % dr.final)
	assert_eq(_ch(c).resource_left("culling"), pb - 1, "a use spent")
	assert_eq(e.deal_damage(c, foe, [{"amount": 5, "type": "fire", "spell": true}], false, "Spell").final, 5, "on its own once a turn")
	c.armed.append("sp_culling")
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, str(e.attack_options(c)[0]["id"])).hit)
	assert_true(_logged(e, "Culling 1d12"), "an armed Culling rides the weapon hit")
	assert_eq(_ch(c).resource_left("culling"), pb - 2)


func test_gift_of_the_green_spends_a_hit_die_and_heals_roll_plus_pb() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "cleric", "harvestborn", Vector2i(2, 3))
	var ally := _hero(e, "fighter", "human", Vector2i(5, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	ally.creature.hp = 3
	var pb := c.creature.proficiency_bonus()
	var r := _perform(e, c, "feat:gm:sp_gift_of_the_green", [ally])
	assert_true(r.ok, r.reason)
	var healed := ally.creature.hp - 3
	assert_true(healed >= 1 + pb and healed <= 10 + pb, "a d10 Hit Point Die + %d: %d" % [pb, healed])
	assert_eq(int(_ch(ally).hit_dice()["10"]["spent"]), 1, "the ally's Hit Point Die is spent")
	assert_eq(_ch(c).resource_left("gift_of_the_green"), pb - 1)
	assert_false(c.bonus_available, "a Bonus Action")
	ally.altitude = 2
	c.bonus_available = true
	assert_false(_perform(e, c, "feat:gm:sp_gift_of_the_green", [ally]).ok, "not on a creature off the ground")


# --- Threadborn ------------------------------------------------------------------------------------------------------

func test_youve_got_a_friend_adds_guidance_to_an_allys_failed_skill_check() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "rogue", "threadborn", Vector2i(2, 3))
	var ally := _hero(e, "wizard", "human", Vector2i(4, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	var pb := c.creature.proficiency_bonus()
	var dc := 10 + ally.creature.skill_bonus(&"athletics").total() + 1
	TestCombat.next_d20(e, 10)
	var t := ally.creature.roll_check(e.dice, &"athletics", dc)
	assert_true(t.success, "1 short, + 1d4: a success")
	assert_eq(_ch(c).resource_left("youve_got_a_friend"), pb - 1)
	assert_false(c.reaction_available, "a Reaction")
	var t2 := ally.creature.roll_check(e.dice, &"athletics", 40)
	assert_false(t2.success)
	assert_eq(_ch(c).resource_left("youve_got_a_friend"), pb - 1, "no Reaction left, and too far short anyway")


func test_soothing_hearts_free_calm_emotions_takes_any_creature_type() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "threadborn", Vector2i(2, 3), 5)
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3), 80, "undead")
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(_ch(c).resource_left("spell:calm_emotions") > 0, "a free casting from level 5")
	var r := e.spells.cast(c, "calm_emotions", 2, [], Vector2(6.5, 3.5), Vector2.ZERO, {"free": true, "choice": "indifferent"})
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.has_flag("indifferent"), "an Undead is calmed too")
	assert_eq(_ch(c).resource_left("spell:calm_emotions"), 0, "the free use spent")


# --- Silkborn --------------------------------------------------------------------------------------------------------

func test_bejeweled_carapace_turns_a_hit_by_less_than_pb_into_a_miss() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "silkborn", Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, z)
	var opt := _just_hit(e, z, c)
	var r := e.attack(z, c, opt)
	assert_false(r.hit, "+PB AC: the hit misses")
	assert_eq(_ch(c).resource_left("bejeweled_carapace"), 0)
	assert_false(c.reaction_available)


# --- Curseborn -------------------------------------------------------------------------------------------------------

func test_cursed_claws_curse_the_target_with_disadvantage() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "curseborn", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	var pb := c.creature.proficiency_bonus()
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:unarmed_strike").hit)
	assert_true(_logged(e, "1d6"), "claws: 1d6")
	assert_true(_has_fx(foe, "cursed_claws"), "cursed")
	var t := foe.creature.roll_save(e.dice, &"wis", 10)
	assert_true(t.disadvantage, "Disadvantage on its D20 Tests")
	assert_eq(_ch(c).resource_left("cursed_claws"), pb - 1)


func test_grey_balance_turns_a_failed_save_into_a_success_at_a_price() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "curseborn", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	c.reaction_rules["grey_balance"] = "auto"
	var t := c.creature.roll_save(e.dice, &"wis", 40)
	assert_true(t.success, "succeeds instead")
	assert_eq(_ch(c).resource_left("grey_balance"), 0)
	assert_true(_has_fx(c, "grey_balance"))
	assert_true(c.creature.roll_save(e.dice, &"str", 5).disadvantage, "Disadvantage on D20 Tests after")


# --- Ashborn ---------------------------------------------------------------------------------------------------------

func test_fiendish_fortune_makes_a_hit_miss_and_burns_the_attacker() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "ashborn", Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, z)
	var hp := z.creature.hp
	var opt := _just_hit(e, z, c)
	var r := e.attack(z, c, opt)
	assert_false(r.hit, "the hit misses")
	assert_eq(z.creature.hp, hp - c.creature.proficiency_bonus(), "PB Force to the attacker beside it")
	assert_eq(_ch(c).resource_left("fiendish_fortune"), 0)


func test_scorpion_sting_adds_poison_to_an_unarmed_strike() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "ashborn", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	var pb := c.creature.proficiency_bonus()
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, "weapon:unarmed_strike").hit)
	assert_true(_logged(e, "Scorpion Sting 1d6"), "+1d6 Poison")
	assert_eq(_ch(c).resource_left("scorpion_sting"), pb - 1)


# --- Azureborn and Stoneborn -----------------------------------------------------------------------------------------

func test_winged_species_fly_but_not_in_medium_or_heavy_armour() -> void:
	for row: Array in [["azureborn", 30], ["stoneborn", 15]]:
		var e := TestCombat.open_field(2)
		var light := _hero(e, "wizard", str(row[0]), Vector2i(2, 3))
		var heavy := _hero(e, "fighter", str(row[0]), Vector2i(2, 5))
		TestCombat.punching_bag(e, Vector2i(10, 3))
		assert_true(str(heavy.creature.armor_situation().get("armor", "")) in ["medium", "heavy"], "the fighter wears Medium or Heavy armour")
		TestCombat.start_with(e, light)
		assert_eq(light.creature.speed("fly").total(), int(row[1]), "%s flies" % row[0])
		assert_eq(heavy.creature.speed("fly").total(), 0, "%s in heavy armour doesn't" % row[0])


func test_glimpse_fate_gives_pb_creatures_advantage_on_initiative() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "wizard", "azureborn", Vector2i(2, 3))
	var ally := _hero(e, "fighter", "human", Vector2i(3, 3))
	var far := _hero(e, "rogue", "human", Vector2i(8, 3))
	var third := _hero(e, "cleric", "human", Vector2i(2, 4))
	TestCombat.punching_bag(e, Vector2i(10, 6))
	e.start()
	var seen := func(x: Combatant) -> bool: return str(x.initiative_test.advantage_sources).contains("Glimpse Fate")
	assert_true(seen.call(c) and seen.call(ally), "the seer and the nearest ally (PB 2)")
	assert_false(seen.call(far) or seen.call(third), "no more than PB creatures")
	assert_eq(_ch(c).resource_left("glimpse_fate"), 0)


func test_winds_of_magic_dashes_with_ten_more_feet_of_flight() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "wizard", "azureborn", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	var before := c.movement_left
	assert_true(_perform(e, c, "feat:gm:sp_winds_of_magic").ok)
	assert_eq(c.creature.speed("fly").total(), 40, "Fly Speed 30 + 10 this turn")
	assert_eq(c.movement_left - before, 50, "Dash at 40, plus the 10 more of this turn's flight")
	assert_false(c.bonus_available)


# --- Bogborn and Gnarlborn -------------------------------------------------------------------------------------------

func test_bog_bulk_and_towering_size_help_break_a_grapple() -> void:
	for row: Array in [["bogborn", "Bog Bulk"], ["gnarlborn", "Towering Size"]]:
		var e := TestCombat.open_field(2)
		var c := _hero(e, "fighter", str(row[0]), Vector2i(2, 3))
		var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
		TestCombat.start_with(e, c)
		c.creature.add_condition(&"grappled", foe.name())
		e.grapples[c.id] = foe.id
		assert_true(e.escape_grapple(c).ok)
		assert_true(_logged(e, "adv [%s]" % row[1]), "%s: Advantage on the escape check" % row[0])
		var t := c.creature.roll_check(e.dice, &"athletics", 10)
		assert_false(str(row[1]) in t.advantage_sources, "%s: not on other Athletics checks" % row[0])


func test_guiding_bond_adds_a_d4_to_attacks_on_the_marked_creature() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "bogborn", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	assert_true(_perform(e, c, "feat:gm:sp_guiding_bond", [foe]).ok)
	assert_eq(_ch(c).resource_left("guiding_bond"), c.creature.proficiency_bonus() - 1)
	TestCombat.next_d20(e, 10)
	e.attack(c, foe, str(e.attack_options(c)[0]["id"]))
	assert_true(_logged(e, "Guiding Bond: +"), "+1d4 on the attack roll")


func test_regeneration_heals_with_a_hit_die_until_fire_stops_it() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "bogborn", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, c)
	c.creature.hp = 5
	assert_true(_perform(e, c, "feat:gm:sp_bogborn_regeneration").ok)
	assert_true(c.creature.hp >= 6, "the Hit Point Die's roll + Con")
	assert_eq(int(_ch(c).hit_dice()["10"]["spent"]), 1)
	e.deal_damage(foe, c, [{"amount": 1, "type": "fire"}], false, "Torch")
	c.bonus_available = true
	assert_eq(str(_find(e, c, "feat:gm:sp_bogborn_regeneration").get("reason", "")), "Acid or Fire stopped it")


# --- Deepborn --------------------------------------------------------------------------------------------------------

func test_eldritch_gibbering_is_spent_only_when_someone_fails() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "wizard", "deepborn", Vector2i(2, 3))
	var wise := e.add(TestChars.dummy(50, false, {"abilities": {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 30, "cha": 10}}), &"enemy", Vector2i(4, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 15)
	assert_true(_perform(e, c, "feat:gm:sp_eldritch_gibbering").ok)
	assert_false(_has_fx(wise, "eldritch_gibbering"))
	assert_eq(_ch(c).resource_left("eldritch_gibbering"), 1, "no one failed: not spent")
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3))
	c.action_available = true
	assert_true(_perform(e, c, "feat:gm:sp_eldritch_gibbering").ok)
	assert_true(_has_fx(bag, "eldritch_gibbering"), "the feeble foe reels")
	assert_eq(_ch(c).resource_left("eldritch_gibbering"), 0, "spent once someone failed")


func test_endless_hunger_takes_disadvantage_off_attacks_on_the_living() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "deepborn", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	c.creature.add_condition(&"poisoned", "test")
	assert_true(_perform(e, c, "feat:gm:sp_endless_hunger").ok)
	e.attack(c, foe, str(e.attack_options(c)[0]["id"]))
	assert_true(_logged(e, "Endless Hunger: "), "the Poisoned Disadvantage is gone")
	assert_eq(_ch(c).resource_left("endless_hunger"), 0)


# --- Gnarlborn and Plagueborn ----------------------------------------------------------------------------------------

func test_deep_roots_and_born_in_filth_give_advantage_on_prone_and_plague_saves() -> void:
	var e := TestCombat.open_field(2)
	var g := _hero(e, "fighter", "gnarlborn", Vector2i(2, 3))
	var p := _hero(e, "fighter", "plagueborn", Vector2i(2, 5))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, g)
	var prone: Array[String] = ["save_vs:prone"]
	assert_true(g.creature.roll_save(e.dice, &"str", 10, [], [], "", prone).advantage, "and against Prone (data)")
	var plague: Array[String] = ["save_vs:contagion"]
	assert_true("Born in Filth" in p.creature.roll_save(e.dice, &"con", 10, [], [], "", plague).advantage_sources)


func test_grasping_branches_restrain_on_a_failure_and_slow_on_a_success() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "gnarlborn", Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(6, 3))
	var strong := e.add(TestChars.dummy(50, false, {"abilities": {"str": 30, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}}), &"enemy", Vector2i(6, 5))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 2)
	assert_true(_perform(e, c, "feat:gm:sp_grasping_branches", [bag]).ok)
	assert_true(bag.creature.has_condition(&"restrained"), "Restrained")
	var fx := bag.creature.effects.filter(func(x: Effect) -> bool: return x.source_id == "grasping_branches")[0] as Effect
	assert_eq(str(fx.repeat_save.get("ability", "")), "str", "a Strength save again at each turn end")
	assert_eq(_ch(c).resource_left("grasping_branches"), 0)
	_ch(c).restore_resource("grasping_branches")
	c.bonus_available = true
	TestCombat.next_d20(e, 15)
	assert_true(_perform(e, c, "feat:gm:sp_grasping_branches", [strong]).ok)
	assert_false(strong.creature.has_condition(&"restrained"))
	assert_eq(strong.creature.speed().total(), 15, "Speed halved")


func test_plague_bearer_poisons_each_turn_until_a_save() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "plagueborn", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(c, foe, str(e.attack_options(c)[0]["id"])).hit)
	assert_true(_has_fx(foe, "plague_bearer"), "the plague takes hold")
	assert_eq(_ch(c).resource_left("plague_bearer"), 0)
	assert_true(foe.creature.roll_check(e.dice, &"str", 5).disadvantage, "Disadvantage on ability checks")
	var hp := foe.creature.hp
	e.game.turn_start(foe)
	assert_true(hp - foe.creature.hp >= 1 and hp - foe.creature.hp <= 4, "1d4 Poison at the start of its turn")


# --- Relicborn -------------------------------------------------------------------------------------------------------

func test_dance_of_death_gives_advantage_and_temporary_hit_points() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "bard", "relicborn", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	TestCombat.next_d20(e, 20)
	assert_true(_perform(e, c, "feat:gm:sp_dance_of_death").ok)
	assert_true(_has_fx(c, "dance_of_death"), "Advantage on the next attack this turn")
	assert_true(c.creature.temp_hp > 0, "beat DC 15 by 5: a Hit Point Die's roll in Temporary Hit Points")
	assert_false(c.bonus_available)


func test_moment_of_remembrance_adds_a_d4_and_spends_only_on_a_success() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "relicborn", Vector2i(2, 3))
	var ally := _hero(e, "wizard", "human", Vector2i(4, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	var dc := 10 + ally.creature.save_bonus(&"str").total() + 1
	TestCombat.next_d20(e, 10)
	var t := ally.creature.roll_save(e.dice, &"str", dc)
	assert_true(t.success, "1 short, + 1d4")
	assert_eq(_ch(c).resource_left("moment_of_remembrance"), 0, "spent: it turned the roll")
	assert_false(c.reaction_available)


# --- Stoneborn -------------------------------------------------------------------------------------------------------

func test_argent_gleam_paths_grace_blesses() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "stoneborn", Vector2i(2, 3))
	var ally := _hero(e, "wizard", "human", Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	var r := _perform(e, c, "feat:gm:sp_argent_gleam_grace", [c, ally])
	assert_true(r.ok, r.reason)
	assert_true(ally.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "bless"), "Blessed")
	assert_eq(_ch(c).resource_left("argent_gleam"), 0)
	c.bonus_available = true
	assert_eq(str(_find(e, c, "feat:gm:sp_argent_gleam_charge").get("reason", "")), "None left", "one use for both")


func test_argent_gleam_zealous_charge_burns_even_on_a_miss() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "stoneborn", Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, c)
	var before := c.movement_left
	assert_true(_perform(e, c, "feat:gm:sp_argent_gleam_charge").ok)
	assert_eq(c.movement_left - before, c.speed(), "Dash")
	TestCombat.next_d20(e, 1)
	var r := e.attack(c, foe, str(e.attack_options(c)[0]["id"]))
	assert_false(r.hit)
	assert_true(200 - foe.creature.hp >= 2 and 200 - foe.creature.hp <= 12, "2d6 Radiant on a miss")


func test_silver_bulwark_resists_the_blow_that_called_it() -> void:
	var e := TestCombat.open_field(2)
	var c := _hero(e, "fighter", "stoneborn", Vector2i(2, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 3))
	TestCombat.start_with(e, z)
	TestCombat.next_d20(e, 19)
	var r := e.attack(z, c, str(e.attack_options(z)[0]["id"]))
	assert_true(r.hit)
	assert_true(_has_fx(c, "silver_bulwark"), "Resistance to Bludgeoning, Piercing and Slashing")
	assert_eq(_ch(c).resource_left("silver_bulwark"), 0)
	assert_true(_logged(e, "Resistance"), "the slam is resisted")


func test_deep_roots_gives_advantage_on_the_save_against_a_shove_away() -> void:
	var e := TestCombat.open_field(2)
	var g := _hero(e, "fighter", "gnarlborn", Vector2i(2, 3))
	var foe := e.add(TestChars.dummy(50), &"enemy", Vector2i(3, 3))
	TestCombat.start_with(e, foe)
	assert_true(e.unarmed_special(foe, g, "shove").ok)
	assert_true(_logged(e, "adv [Deep Roots]"), "Advantage against being pushed")


func test_a_relicborn_hero_can_be_put_to_sleep_but_not_a_harvestborn() -> void:
	var e := TestCombat.open_field(12)
	var foe := e.add(TestChars.pregen("silvain_aster", 3), &"enemy", Vector2i(1, 3))
	var relic := _hero(e, "fighter", "relicborn", Vector2i(6, 3))
	var harvest := _hero(e, "fighter", "harvestborn", Vector2i(6, 4))
	TestCombat.start_with(e, foe)
	TestCombat.next_d20(e, 2)
	var r := e.spells.cast(foe, "sleep", 1, [], Vector2(7, 4))
	assert_true(r.ok, r.reason)
	assert_true(relic.creature.has_condition(&"incapacitated"), "an Undead hero still sleeps (Eternal Party isn't a trance)")
	assert_false(harvest.creature.has_condition(&"incapacitated"), "Watchful Rest: magic can't put a Harvestborn to sleep")


func test_revivify_brings_back_a_dead_graveborn_hero() -> void:
	var e := TestCombat.open_field(3)
	var cleric := TestChars.custom("cleric", "human", 9)
	var prepared := (cleric.spellcasting[0] as Dictionary)["prepared"] as Array
	if not "revivify" in prepared:
		prepared.append("revivify")
	TestCombat.give_components(cleric, ["revivify"])
	var c := e.add(cleric, &"party", Vector2i(2, 2))
	var fallen := _hero(e, "fighter", "graveborn", Vector2i(3, 2))
	TestCombat.punching_bag(e, Vector2i(9, 5))
	TestCombat.start_with(e, c)
	fallen.creature.hp = 0
	fallen.creature.dead = true
	fallen.set_meta("died_round", e.round_no)
	var r := e.spells.cast(c, "revivify", 3, [fallen])
	assert_true(r.ok, r.reason)
	assert_false(fallen.creature.dead, "an Undead hero comes back")
	assert_eq(fallen.creature.hp, 1)


func test_a_surprised_azureborn_glimpses_nothing_and_keeps_the_use() -> void:
	var e := TestCombat.open_field(2)
	var ally := _hero(e, "fighter", "human", Vector2i(3, 3))
	var c := _hero(e, "wizard", "azureborn", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 6))
	e.start([c.id])
	var seen := func(x: Combatant) -> bool: return str(x.initiative_test.advantage_sources).contains("Glimpse Fate")
	assert_false(seen.call(c) or seen.call(ally), "surprised: no Glimpse Fate, though the seer comes second")
	assert_eq(_ch(c).resource_left("glimpse_fate"), 1, "the use is kept")


func test_zealous_charge_burns_a_hit_turned_into_a_miss() -> void:
	var e := TestCombat.open_field(2)
	var c := e.add(TestChars.custom("fighter", "stoneborn", 3), &"enemy", Vector2i(2, 3))
	var silk := _hero(e, "fighter", "silkborn", Vector2i(3, 3))
	TestCombat.start_with(e, c)
	# A foe's Zealous Charge (the hotbar is the player's; the module takes it the same way).
	var pr := e.game.perform(c, "sp_argent_gleam_charge", null, Vector2i(-1, -1), Vector2.INF)
	assert_true(pr.ok, "charge: " + pr.reason)
	var hp := silk.creature.hp
	var opt := _just_hit(e, c, silk)
	var r := e.attack(c, silk, opt)
	assert_false(r.hit, "Bejeweled Carapace turns the hit into a miss")
	assert_eq(_ch(silk).resource_left("bejeweled_carapace"), 0)
	e.end_turn()
	assert_true(hp - silk.creature.hp >= 2 and hp - silk.creature.hp <= 12, "the 2d6 Radiant lands anyway: %d" % (hp - silk.creature.hp))
	assert_true(_logged(e, "Radiant damage"), "dealt as Radiant")
