extends TestCase
## The Crooked Moon's College of Whistles, Harvest Domain and Circle of the Old Ways in a fight (CmCasters), built
## through the real level-up path.


func _hero(e: Encounter, class_id: String, sub: String, level: int, cell: Vector2i, picks: Dictionary = {}) -> Combatant:
	var p := picks.duplicate()
	p["%s_subclass" % class_id] = [sub]
	return e.add(TestChars.custom(class_id, "human", level, p), &"party", cell)


func _do(e: Encounter, c: Combatant, id: String, targets: Array = [], point: Vector2 = Vector2.INF, choice: String = "") -> CombatResult:
	var a := ActionCatalog.new(e).find(c, id)
	if a.is_empty():
		return CombatResult.fail("no action " + id)
	return ActionCatalog.new(e).perform(c, a, targets, point, Vector2.ZERO, 0, {"choice": choice} if choice != "" else {})


## Hands the turn to `c` (its turn begins as the fight's would).
func _turn_of(e: Encounter, c: Combatant) -> void:
	e.turn_index = e.order.find(c)
	e._begin_turn()


## `r` once every prompt other options raise along the way (not this file's) is declined.
func _settled(e: Encounter, r: CombatResult) -> CombatResult:
	var out := r
	for guard in 10:
		if e.pending == null:
			break
		var hit := out.hit
		out = e.answer_reaction(false)
		out.hit = out.hit or hit
	return out


func _ch(c: Combatant) -> Character:
	return c.creature as Character


func _melee(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			return str(o["id"])
	return "weapon:unarmed_strike"


func _haints(e: Encounter) -> Array:
	return e.spells.zones.live().filter(func(o: FieldObject) -> bool: return o.spell_id == CmCasters.HAINT)


## The number in the first log line holding `needle` ("+N damage", "N less damage"), or -1.
func _logged(e: Encounter, needle: String) -> int:
	for line in e.log.texts():
		if line.contains(needle):
			var m := RegEx.create_from_string("(\\d+)( less damage| damage)").search(line)
			if m != null:
				return int(m.get_string(1))
	return -1


## A Whistles bard (level 6), an inspired fighter beside it and a foe; the haint `form` called round the fighter.
func _haint_scene(form: String, seed_value: int = 5) -> Dictionary:
	var e := TestCombat.open_field(seed_value)
	var b := _hero(e, "bard", "college_of_whistles", 6, Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(4, 3))
	TestCombat.start_with(e, b)
	assert_true(_do(e, b, "feat:cf:bardic_inspiration", [a]).ok, "Bardic Inspiration")
	var r := _do(e, b, "feat:gm:cs_haint:" + form)
	assert_true(r.ok, "the haint comes: %s" % r.reason)
	return {"e": e, "b": b, "a": a, "z": z}


# --- College of Whistles -------------------------------------------------------------------------------------------

func test_a_haint_is_called_with_bardic_inspiration_and_grump_gives_advantage() -> void:
	var s := _haint_scene("grump")
	var e := s["e"] as Encounter
	var a := s["a"] as Combatant
	var b := s["b"] as Combatant
	assert_eq(_haints(e).size(), 1)
	var adv := a.creature.modifiers_for(&"advantage").filter(func(m: Modifier) -> bool: return m.source_name == "Haint (Grump)")
	assert_eq(adv.size(), 1, "the inspired fighter has Grump's Advantage")
	assert_true("save:str" in (adv[0].data["on"] as Array) and "check:intimidation" in (adv[0].data["on"] as Array))
	assert_true(ActionCatalog.new(e).find(b, "feat:gm:cs_haint:scamp").is_empty(), "one haint per Bardic Inspiration")
	# Calling a new haint sends the old one away; an Incapacitated bard's haint fades.
	b.creature.hp = 0
	e.game.turn_end(b)
	assert_eq(_haints(e).size(), 0, "the bard dropped: the haint is gone")


func test_grump_adds_a_bardic_die_and_charisma_to_a_hit() -> void:
	var losses: Array[int] = []
	var added := 0
	for rule: String in ["never", "auto"]:
		var s := _haint_scene("grump")
		var e := s["e"] as Encounter
		var b := s["b"] as Combatant
		var a := s["a"] as Combatant
		var z := s["z"] as Combatant
		b.reaction_rules["handy_haints"] = rule
		z.creature.hp = 200
		_turn_of(e, a)
		TestCombat.next_d20(e, 18)
		assert_true(_settled(e, e.attack(a, z, _melee(e, a))).hit)
		losses.append(200 - z.creature.hp)
		if rule == "auto":
			added = _logged(e, "Grump haint")
			assert_false(b.reaction_available, "Grump spends the Reaction")
			assert_eq(_haints(e).size(), 0, "and the haint fades")
	assert_between(added, 1, 8 + 5, "a d8 + Charisma")
	assert_eq(losses[1], losses[0] + added, "the same blow, %d more" % added)


func test_sad_sack_cuts_damage_to_a_creature_in_its_aura() -> void:
	var losses: Array[int] = []
	var cut := 0
	for rule: String in ["never", "auto"]:
		var s := _haint_scene("sad_sack")
		var e := s["e"] as Encounter
		var b := s["b"] as Combatant
		var a := s["a"] as Combatant
		var z := s["z"] as Combatant
		b.reaction_rules["handy_haints"] = rule
		a.creature.hp = a.creature.max_hp()
		_turn_of(e, z)
		TestCombat.next_d20(e, 19)
		assert_true(_settled(e, e.attack(z, a, e.attack_options(z)[0]["id"])).hit)
		losses.append(a.creature.max_hp() - a.creature.hp)
		if rule == "auto":
			cut = _logged(e, "Sad Sack haint")
			assert_false(b.reaction_available)
	assert_between(cut, 1, 8 + 5, "a d8 + Charisma")
	assert_eq(losses[1], maxi(0, losses[0] - cut), "the blow less %d" % cut)
	var s2 := _haint_scene("sad_sack")
	var e2 := s2["e"] as Encounter
	var a2 := s2["a"] as Combatant
	var z2 := s2["z"] as Combatant
	var ranged := {"melee": false, "profile": WeaponProfile.new(), "kind": "weapon"}
	var sit := e2.attack_situation(z2, a2, ranged)
	assert_eq(int(sit["cover"]), CombatGrid.Cover.HALF, "Half Cover against a ranged attack inside the aura")
	assert_eq(str(sit["cover_by"]), "Haint (Sad Sack)")
	var close := e2.attack_situation(z2, a2, e2.attack_options(z2)[0])
	assert_eq(int(close["cover"]), CombatGrid.Cover.NONE, "none against a melee one")


func test_scamp_speeds_allies_and_rerolls_a_failed_save() -> void:
	var s := _haint_scene("scamp")
	var e := s["e"] as Encounter
	var b := s["b"] as Combatant
	var a := s["a"] as Combatant
	var spd := a.speed()
	e.game.turn_start(a)
	assert_eq(a.speed(), spd + 10, "+10 ft starting a turn in the aura")
	b.reaction_rules["handy_haints"] = "auto"
	TestCombat.next_d20(e, 2)
	var t := a.creature.roll_save(e.dice, &"dex", 40, [], [], "Test save")
	assert_false(t.success)
	assert_eq(t.rerolls.size(), 1, "Scamp rerolled the d20")
	assert_false(b.reaction_available)
	assert_eq(_haints(e).size(), 0, "the haint fades after its Reaction")


func test_ride_the_rails_carries_the_party_and_runs_down_foes() -> void:
	var e := TestCombat.open_field(4)
	var b := _hero(e, "bard", "college_of_whistles", 6, Vector2i(1, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(1, 4))
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 80)
	TestCombat.start_with(e, b)
	TestCombat.next_d20(e, 3)
	var r := _do(e, b, "feat:gm:cs_ride_the_rails", [], Vector2(10.5, 3.5))
	assert_true(r.ok, r.reason)
	assert_eq(b.cell, Vector2i(10, 3), "the bard gets off where it chose")
	assert_true(e.distance(a, b) <= 10, "the fighter rides along: %s" % str(a.cell))
	assert_true(bag.creature.has_condition(&"deafened"), "the foe in the Line is Deafened")
	assert_eq(bag.cell, Vector2i(7, 3), "and pushed 10 ft away from where the train began")
	var lost := 80 - bag.creature.hp
	assert_between(lost, 3, 24, "three Bardic dice (d8) of Psychic")
	assert_eq(_ch(b).resource_left("ride_the_rails"), 0)
	# Again, with a level 3 slot.
	b.action_available = true
	b.magic_action_used = false
	var slots := _ch(b).slots_left(3)
	assert_true(_do(e, b, "feat:gm:cs_ride_the_rails:alone", [], Vector2(1.5, 1.5)).ok)
	assert_eq(_ch(b).slots_left(3), slots - 1, "a level 3 slot restores the use")


# --- Harvest Domain ------------------------------------------------------------------------------------------------

func test_bountiful_harvest_sowing_inspires_and_shields() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "cleric", "harvest_domain", 3, Vector2i(2, 3), {"aspect": ["sowing"]})
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	_ch(c).heroic_inspiration = false
	_ch(a).heroic_inspiration = false
	var cd := _ch(c).resource_left("channel_divinity")
	assert_true(_do(e, c, "feat:gm:cs_bountiful_harvest").ok)
	assert_true(_ch(a).heroic_inspiration and _ch(c).heroic_inspiration, "Heroic Inspiration for both")
	assert_eq(_ch(c).resource_left("channel_divinity"), cd - 1)
	var want := c.creature.proficiency_bonus() + c.creature.ability_mod(&"wis")
	assert_eq(a.creature.temp_hp, want, "Sowing: PB + Wis Temporary Hit Points")
	# Once per Long Rest each: a second harvest gives no new Heroic Inspiration.
	_ch(a).heroic_inspiration = false
	c.action_available = true
	c.magic_action_used = false
	_ch(c).restore_resource("channel_divinity", 1)
	assert_true(_do(e, c, "feat:gm:cs_bountiful_harvest").ok)
	assert_false(_ch(a).heroic_inspiration, "already had this harvest's gift since the last Long Rest")


func test_bountiful_harvest_growing_and_reaping() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "cleric", "harvest_domain", 3, Vector2i(2, 3), {"aspect": ["growing"], "harvest_domain_spells": ["growing"]})
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	assert_true(_do(e, c, "feat:gm:cs_bountiful_harvest").ok)
	assert_eq(CmCasters._aspect(c), "growing")
	var dies := a.creature.modifiers_for(&"bonus_die").filter(func(m: Modifier) -> bool: return m.source_name == "Growing")
	assert_eq(dies.size(), 1, "Growing: +1d4")
	if dies.is_empty():
		return
	assert_eq(str(dies[0].data["dice"]), "1d4")
	assert_true("attack" in (dies[0].data["on"] as Array) and "check:all" in (dies[0].data["on"] as Array))
	var e2 := TestCombat.open_field(3)
	var c2 := _hero(e2, "cleric", "harvest_domain", 3, Vector2i(2, 3), {"aspect": ["reaping"], "harvest_domain_spells": ["reaping"]})
	var a2 := TestCombat.hero(e2, "ilse_varga", Vector2i(5, 3))
	var bag := TestCombat.punching_bag(e2, Vector2i(6, 3), 80)
	TestCombat.start_with(e2, c2)
	assert_true(_do(e2, c2, "feat:gm:cs_bountiful_harvest").ok)
	e2.deal_damage(a2, bag, [{"amount": 5, "type": "slashing"}], false, "Test")
	assert_eq(bag.creature.hp, 80 - 5 - c2.creature.proficiency_bonus(), "Reaping: +PB Necrotic on the first damage")
	e2.deal_damage(a2, bag, [{"amount": 5, "type": "slashing"}], false, "Test")
	assert_eq(bag.creature.hp, 80 - 10 - c2.creature.proficiency_bonus(), "only the first")


func test_bountiful_harvest_picks_another_gift_and_the_aspect_follows() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "cleric", "harvest_domain", 3, Vector2i(2, 3), {"aspect": ["sowing"], "harvest_domain_spells": ["sowing"]})
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	var entry := ActionCatalog.new(e).find(c, "feat:gm:cs_bountiful_harvest")
	assert_eq((entry.get("choices", []) as Array).size(), 3, "a pick of the three gifts")
	assert_true(_do(e, c, "feat:gm:cs_bountiful_harvest", [], Vector2.INF, "reaping").ok)
	assert_eq(CmCasters._aspect(c), "reaping", "the aspect switches to the gift picked")
	assert_true(a.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "cs_reaping"), "Reaping's gift")
	assert_eq(a.creature.temp_hp, 0, "not Sowing's")
	assert_true(_ch(c).knows_spell("inflict_wounds"), "Reaping's spells are prepared now")


func test_switching_aspect_keeps_the_days_heroic_inspiration_spent() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "cleric", "harvest_domain", 3, Vector2i(2, 3), {"aspect": ["sowing"], "harvest_domain_spells": ["sowing"]})
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(5, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	_ch(c).heroic_inspiration = false
	_ch(a).heroic_inspiration = false
	assert_true(_do(e, c, "feat:gm:cs_bountiful_harvest").ok, "the first harvest (Sowing)")
	assert_true(_ch(a).heroic_inspiration and _ch(c).heroic_inspiration)
	_ch(c).heroic_inspiration = false
	_ch(a).heroic_inspiration = false
	c.action_available = true
	c.magic_action_used = false
	_ch(c).restore_resource("channel_divinity", 1)
	assert_true(_do(e, c, "feat:gm:cs_bountiful_harvest", [], Vector2.INF, "growing").ok, "the second, switching aspect")
	assert_eq(CmCasters._aspect(c), "growing")
	assert_false(_ch(a).heroic_inspiration, "the ally had this feature's Heroic Inspiration today")
	assert_false(_ch(c).heroic_inspiration, "and so had the cleric, though its sheet was rebuilt")


func test_blessing_of_the_seasons_rerolls_and_heals() -> void:
	var e := TestCombat.open_field(3)
	var c := _hero(e, "cleric", "harvest_domain", 6, Vector2i(2, 3), {"aspect": ["sowing"]})
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(4, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, c)
	c.reaction_rules["blessing_of_the_seasons"] = "auto"
	a.reaction_rules["heroic_inspiration"] = "never"
	a.creature.hp = 5
	var uses := _ch(c).resource_left("blessing_of_the_seasons")
	TestCombat.next_d20(e, 2)
	var wis := a.creature.roll_save(e.dice, &"wis", 40, [], [], "Not the season's")
	assert_eq(wis.rerolls.size(), 0, "Sowing answers Dexterity and Charisma saves only")
	TestCombat.next_d20(e, 2)
	var t := a.creature.roll_save(e.dice, &"dex", 40, [], [], "Test save")
	assert_eq(t.rerolls.size(), 1, "rerolled")
	assert_false(c.reaction_available)
	assert_eq(_ch(c).resource_left("blessing_of_the_seasons"), uses - 1)
	var pb := c.creature.proficiency_bonus()
	assert_between(a.creature.hp - 5, pb, pb * 4, "healed PB d4 even though it still failed")


# --- Circle of the Old Ways ----------------------------------------------------------------------------------------

func _druid(e: Encounter, level: int, cell: Vector2i) -> Combatant:
	var d := _hero(e, "druid", "circle_of_the_old_ways", level, cell)
	var ch := _ch(d)
	ch.unequip("off_hand")
	if not str(ch.equipped("main_hand").get("item_id", ch.equipped("main_hand").get("id", ""))) in CmCasters.SHILLELAGH_WEAPONS:
		ch.add_item("quarterstaff")
		ch.equip("quarterstaff", "main_hand")
	return d


func test_bough_and_branch_grows_a_shield_with_shillelagh() -> void:
	var e := TestCombat.open_field(3)
	var d := _druid(e, 3, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, d)
	var ac := d.creature.ac_value()
	var r := e.spells.cast(d, "shillelagh", 0)
	assert_true(r.ok, r.reason)
	assert_eq(d.creature.ac_value(), ac + 2, "a wooden Shield in the free hand")
	assert_true(d.creature.has_flag("keeps_hold"), "can't be made to drop it")
	var held := _ch(d).equipped("main_hand")
	assert_false(e.ground.disarm(d, null, "Disarming Attack"), "a disarm fails while it can act")
	assert_eq(_ch(d).equipped("main_hand"), held, "the Shillelagh stays in hand")


func test_wood_wose_wakes_with_shillelagh_when_armed() -> void:
	var e := TestCombat.open_field(3)
	var d := _druid(e, 3, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(10, 3))
	TestCombat.start_with(e, d)
	var ws := _ch(d).resource_left("wild_shape")
	var ids := e.features.rider_options(d).map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true(CmCasters.WOSE_RIDER in ids, "the rider is offered")
	var recipes := ActionCatalog.new(e).actions_for(d).filter(func(a: Dictionary) -> bool: return str(a["id"]) == "feat:recipe:wood_wose")
	assert_eq(recipes.size(), 1, "Wood Wose's Bonus Action shows once")
	d.armed.append(CmCasters.WOSE_RIDER)
	assert_true(e.spells.cast(d, "shillelagh", 0).ok)
	assert_true(CmCasters.in_wose(d), "Wood Wose woke with the cast")
	assert_eq(_ch(d).resource_left("wild_shape"), ws - 1)
	assert_false(d.bonus_available, "one Bonus Action for both")


func test_wood_wose_sap_and_oak_and_thorn() -> void:
	var e := TestCombat.open_field(3)
	var d := _druid(e, 6, Vector2i(2, 3))
	var a := TestCombat.hero(e, "ilse_varga", Vector2i(2, 5))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, d)
	assert_true(_do(e, d, "feat:recipe:wood_wose").ok, "Wood Wose")
	assert_eq(e.attacks_per_action(d), 2, "Oakenfist: two attacks")
	d.bonus_available = true
	assert_true(e.spells.cast(d, "shillelagh", 0).ok)
	TestCombat.next_d20(e, 15)
	var r := e.attack(d, bag, _melee(e, d))
	assert_true(r.hit)
	assert_eq(CmCasters.sapped_by(bag), d.id, "coated in Elderwood sap")
	var sit := e.attack_situation(bag, a, e.attack_options(a)[0])
	assert_true("Elderwood Sap" in (sit["disadvantage"] as Array), "Disadvantage on anyone but the druid")
	var sit2 := e.attack_situation(bag, d, e.attack_options(a)[0])
	assert_false("Elderwood Sap" in (sit2["disadvantage"] as Array))
	assert_true(e.game.target_weight(bag, a) < e.game.target_weight(bag, d), "the AI would rather strike the druid")
	assert_true(e.log.dump().contains("Gnarled Thorns"), "1d6 Piercing on the first melee hit")
	TestCombat.next_d20(e, 15)
	var log_n := e.log.entries.size()
	assert_true(e.attack(d, bag, _melee(e, d)).hit)
	var later := e.log.entries.slice(log_n).map(func(x: Dictionary) -> String: return str(x))
	assert_false(str(later).contains("Gnarled Thorns"), "once a turn")


func test_deepwood_elder_growth_wrath_and_brambles() -> void:
	var e := TestCombat.open_field(3)
	var d := _druid(e, 10, Vector2i(2, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	var z := TestCombat.foe(e, "zombie", Vector2i(2, 4))
	TestCombat.start_with(e, d)
	assert_true(_do(e, d, "feat:recipe:wood_wose").ok)
	var want := d.creature.ability_mod(&"wis") + d.creature.proficiency_bonus()
	assert_eq(d.creature.temp_hp, want, "Rampant Growth as it wakes")
	d.creature.temp_hp = 0
	e.game.turn_start(d)
	assert_eq(d.creature.temp_hp, want, "and at each turn's start")
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(d, bag, _melee(e, d)).hit)
	assert_true(bag.creature.has_condition(&"prone"), "Primeval Wrath: Strength save or Prone")
	z.creature.hp = 40
	_turn_of(e, z)
	TestCombat.next_d20(e, 19)
	assert_true(_settled(e, e.attack(z, d, e.attack_options(z)[0]["id"])).hit, "the zombie hits")
	assert_between(40 - z.creature.hp, 1, 8, "Bramblebark: 1d8 Piercing back")
	var hp := z.creature.hp
	z.action_available = true
	z.attacks_left = 1
	TestCombat.next_d20(e, 19)
	_settled(e, e.attack(z, d, e.attack_options(z)[0]["id"]))
	assert_eq(z.creature.hp, hp, "once a turn")
