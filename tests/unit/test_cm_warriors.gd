extends TestCase
## The Crooked Moon's Path of the Experiment, Oath of Castigation and Sinner in a fight (combat/crooked/cm_warriors.gd):
## serums and compounds, Reactive Catalyst, the shackles' flare, Incite's Frighten, Kindling Aura, Hex Slinger's jinxes,
## Borrowed Luck, Pick Your Poison and the jinx weapon.


func _part(e: Encounter) -> CmWarriors:
	return (e.game as CrookedFeatures).owner_of("wr_x") as CmWarriors


func _barbarian(e: Encounter, level: int, cell: Vector2i) -> Combatant:
	return e.add(TestChars.custom("barbarian", "human", level, {"barbarian_subclass": ["path_of_the_experiment"]}), &"party", cell)


func _act(e: Encounter, c: Combatant, id: String, t: Combatant = null, point: Vector2 = Vector2.INF, choice: String = "") -> CombatResult:
	return e.feature_actions.perform(c, "gm:wr_" + id, t, point, choice)


func _ids(e: Encounter, c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for a in e.feature_actions.list(c):
		out.append(str(a["id"]))
	return out


func _melee(e: Encounter, c: Combatant) -> String:
	for o in e.attack_options(c):
		if bool(o["melee"]) and str(o["kind"]) == "weapon":
			return str(o["id"])
	return "weapon:unarmed_strike"


## A foe whose AC sits `above` over `c`'s attack bonus with `option_id`, so a d20 of `above - 1` misses by one.
func _target_for(e: Encounter, c: Combatant, option_id: String, above: int, cell: Vector2i, extra: Dictionary = {}) -> Combatant:
	var bonus := (e.option_by_id(c, option_id)["profile"] as WeaponProfile).attack.total()
	var data := {"ac": bonus + above, "abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}}
	data.merge(extra, true)
	return e.add(TestChars.dummy(200, false, data), &"enemy", cell)


func _logged(e: Encounter, text: String) -> bool:
	return e.log.dump().contains(text)


# --- Path of the Experiment ---------------------------------------------------------------------------------------

func test_rage_comes_with_a_serum_on_the_hotbar_and_ferocity_ignores_difficult_terrain() -> void:
	var e := TestCombat.open_field(3)
	var b := _barbarian(e, 3, Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, b)
	var ids := _ids(e, b)
	assert_false("feat:cf:rage" in ids, "the plain Rage gives way to a Rage per serum")
	for s: String in CmWarriors.SERUMS:
		assert_true(("feat:gm:wr_rage:" + s) in ids, s)
	var rages := (b.creature as Character).resource_left("rage")
	assert_true(_act(e, b, "rage:ferocity").ok)
	assert_true(ClassFeatures.raging(b))
	assert_eq((b.creature as Character).resource_left("rage"), rages - 1, "the serum costs no extra Rage use")
	assert_true(b.creature.has_flag("ignore_difficult_terrain"))
	assert_true("feat:gm:wr_serum:reconstruction" in _ids(e, b), "a Bonus Action switches serums while raging")


func test_ferocity_cleaves_off_a_weapon_without_cleave() -> void:
	var e := TestCombat.open_field(3)
	var b := _barbarian(e, 3, Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	var z := TestCombat.punching_bag(e, Vector2i(3, 4), 200)
	TestCombat.start_with(e, b)
	assert_true(_act(e, b, "rage:ferocity").ok)
	var opt := _melee(e, b)
	assert_ne((e.option_by_id(b, opt)["profile"] as WeaponProfile).mastery, "cleave", "a weapon of another mastery")
	TestCombat.next_d20(e, 15)
	assert_true(e.attack(b, a, opt).hit)
	assert_true(_logged(e, "Cleave (Ferocity)"))
	assert_true(z.creature.hp < 200 or _logged(e, "misses %s" % z.name()), "the second creature was attacked")


func test_monstrosity_grows_reaches_and_turns_a_near_miss_into_a_hit_once_a_turn() -> void:
	var e := TestCombat.open_field(3)
	var b := _barbarian(e, 3, Vector2i(4, 3))
	var opt := ""
	TestCombat.start_with(e, b)
	opt = _melee(e, b)
	var reach := (e.option_by_id(b, opt)["profile"] as WeaponProfile).reach
	assert_true(_act(e, b, "rage:path_of_the_experiment_monstrosity").ok)
	assert_eq(b.creature.size, &"large", "Large with room round it")
	assert_eq((e.option_by_id(b, opt)["profile"] as WeaponProfile).reach, reach + 5, "+5 ft reach")
	b.reaction_rules["wr_monstrosity"] = "auto"
	(b.creature as Character).heroic_inspiration = false   # no reroll prompt after the second miss
	var t := _target_for(e, b, opt, 12, Vector2i(6, 3))
	TestCombat.next_d20(e, 10)   # misses by two; the Rage Damage bonus (+2) makes it
	assert_true(e.attack(b, t, opt).hit, "Monstrosity adds +%d" % ClassFeatures.rage_bonus(b))
	assert_true(_logged(e, "Monstrosity"))
	b.attacks_left = 1
	TestCombat.next_d20(e, 10)
	assert_false(e.attack(b, t, opt).hit, "only once a turn")
	b.bonus_available = true
	var sr := _act(e, b, "serum:ferocity")
	assert_true(sr.ok, sr.reason)
	assert_eq(b.creature.size, &"medium", "back to size when the serum goes")


func test_monstrosity_reach_lengthens_a_reach_weapon_and_opportunity_attacks() -> void:
	var e := TestCombat.open_field(3)
	var ch := TestChars.custom("barbarian", "human", 3, {"barbarian_subclass": ["path_of_the_experiment"]})
	ch.add_item("glaive")
	ch.unequip_item(str(ch.equipped("off_hand").get("id", "")))
	ch.equip("glaive", "main_hand")
	var b := e.add(ch, &"party", Vector2i(4, 3))
	TestCombat.punching_bag(e, Vector2i(9, 6))
	TestCombat.start_with(e, b)
	var reach_ft := b.reach_ft()
	assert_true(_act(e, b, "rage:path_of_the_experiment_monstrosity").ok)
	assert_eq((e.option_by_id(b, "weapon:glaive")["profile"] as WeaponProfile).reach, 15, "a Reach weapon goes to 15 ft")
	assert_eq(b.reach_ft(), reach_ft + 5, "Opportunity Attacks reach further too")
	b.bonus_available = true
	assert_true(_act(e, b, "serum:ferocity").ok)
	assert_eq((e.option_by_id(b, "weapon:glaive")["profile"] as WeaponProfile).reach, 10, "back to 10 ft without the serum")


func test_reconstruction_spends_a_hit_point_die_and_overflows_into_temporary_hit_points() -> void:
	var e := TestCombat.open_field(3)
	var b := _barbarian(e, 3, Vector2i(2, 3))
	var ch := b.creature as Character
	TestCombat.punching_bag(e, Vector2i(6, 6))
	TestCombat.start_with(e, b)
	b.creature.hp = b.creature.max_hp()
	assert_true(_act(e, b, "rage:reconstruction").ok)
	assert_eq(int((ch.hit_dice()["12"] as Dictionary)["spent"]), 1, "one Hit Point Die on activation")
	assert_true(b.creature.temp_hp >= 1, "at full Hit Points it all becomes Temporary Hit Points")
	# Hurt, at the next turn start it heals; Fire damage stops the turn after.
	b.creature.hp = 5
	b.creature.temp_hp = 0
	e.end_turn()
	while e.current() != b:
		e.end_turn()
	assert_true(b.creature.hp > 5, "a Hit Point Die at the start of the turn")
	assert_eq(int((ch.hit_dice()["12"] as Dictionary)["spent"]), 2)
	b.set_meta("rage_kept", e.class_features._turn_key())
	e.deal_damage(null, b, [{"amount": 1, "type": "fire"}], false, "Test fire")
	var hp := b.creature.hp
	e.end_turn()
	while e.current() != b:
		e.end_turn()
	assert_eq(b.creature.hp, hp, "Fire stops it at the next turn start")
	assert_true(_logged(e, "keeps"))


func test_compounds_from_level_six_senses_fumes_and_expulsion() -> void:
	var e := TestCombat.open_field(3)
	var b := _barbarian(e, 6, Vector2i(2, 3))
	var foe := e.add(TestChars.dummy(200, false, {"abilities": {"str": 10, "dex": 1, "con": 10, "int": 10, "wis": 1, "cha": 10}}), &"enemy", Vector2i(4, 3))
	var ally := TestCombat.hero(e, "ilse_varga", Vector2i(2, 5))
	TestCombat.start_with(e, b)
	var rage := {}
	for a in e.feature_actions.list(b):
		if str(a["id"]) == "feat:gm:wr_rage:ferocity":
			rage = a
	assert_eq((rage.get("choices", []) as Array).size(), 3, "the compound is the Rage's right-click choice")
	assert_true(_act(e, b, "rage:ferocity", null, Vector2.INF, "stimulated_senses").ok)
	assert_eq(b.creature.sense_range("blindsight"), 30, "Stimulated Senses: Blindsight 30 ft")
	# Maddening Fumes: an enemy starting its turn inside has its Speed halved and, failing, attacks others at Disadvantage.
	b.bonus_available = true
	assert_true(_act(e, b, "serum:ferocity", null, Vector2.INF, "maddening_fumes").ok)
	assert_eq(b.creature.sense_range("blindsight"), 0)
	while e.current() != foe:
		e.end_turn()
	assert_eq(foe.movement_left, foe.speed() / 2, "Speed halved in the fumes")
	assert_true(CmWarriors._effect(foe, "wr_fumes") != null, "a Wis 1 foe fails the save")
	var adv: Array[String] = []
	var dis: Array[String] = []
	_part(e).attack_situation(foe, ally, {}, adv, dis)
	assert_true("Maddening Fumes" in dis, "Disadvantage against someone else")
	dis.clear()
	_part(e).attack_situation(foe, b, {}, adv, dis)
	assert_false("Maddening Fumes" in dis, "not against the barbarian")
	assert_true(_part(e).target_weight(foe, ally) < 1.0 and _part(e).target_weight(foe, b) == 1.0, "the AI is drawn to the barbarian")


func test_corrosive_expulsion_replaces_an_attack_with_an_acid_cone() -> void:
	var e := TestCombat.open_field(3)
	var b := _barbarian(e, 6, Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	TestCombat.start_with(e, b)
	assert_true(_act(e, b, "rage:ferocity", null, Vector2.INF, "corrosive_expulsion").ok)
	assert_true("feat:gm:wr_expel:line" in _ids(e, b))
	var r := _act(e, b, "expel:cone", null, e.center_of(foe))
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.hp < 200, "Acid in the cone")
	assert_true(_logged(e, "%dd8" % ClassFeatures.rage_bonus(b)), "Rage Damage bonus d8s")
	assert_true(b.took_attack_action, "one attack of the Attack action")


func test_reactive_catalyst_rages_before_damage_and_sheds_conditions() -> void:
	var e := TestCombat.open_field(3)
	var b := _barbarian(e, 10, Vector2i(2, 3))
	var foe := TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.start_with(e, b)
	b.set_meta("wr_serum", "ferocity")   # the serum it last used goes in
	var hp := b.creature.hp
	e.deal_damage(foe, b, [{"amount": 10, "type": "slashing"}], false, "Test blow")
	assert_true(ClassFeatures.raging(b), "the Rage starts with the Reaction")
	assert_false(b.reaction_available)
	assert_eq(b.creature.hp, hp - 5, "the Rage's Resistance halves the blow that set it off")
	assert_true(CmWarriors._effect(b, "wr_serum") != null, "a serum goes in")
	var gf := _part(e).before_d20(b, D20Test.Kind.SAVING_THROW, ["save:con"] as Array[String])
	assert_true("Reactive Catalyst" in (gf.get("advantage", []) as Array), "Advantage on Con saves while raging")
	# A fresh barbarian about to be Poisoned rages instead.
	var e2 := TestCombat.open_field(3)
	var b2 := _barbarian(e2, 10, Vector2i(2, 3))
	TestCombat.punching_bag(e2, Vector2i(6, 6))
	TestCombat.start_with(e2, b2)
	var fx := Effect.new("Poison", &"spell", "test_poison").with_condition(&"poisoned")
	fx.ends = Effect.Ends.NEVER
	b2.creature.add_effect(fx)
	assert_true(ClassFeatures.raging(b2))
	assert_false(b2.creature.has_condition(&"poisoned"), "entering the Rage ends Poisoned")


# --- Oath of Castigation ------------------------------------------------------------------------------------------

func test_castigate_shackles_and_the_flare_burns_every_bound_creature() -> void:
	var e := TestCombat.open_field(3)
	var p := e.add(TestChars.custom("paladin", "human", 3, {"paladin_subclass": ["oath_of_castigation"]}), &"party", Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(4, 3), 100)
	TestCombat.start_with(e, p)
	var r := e.feature_actions.perform(p, "recipe:castigate", null, Vector2.INF, "", [a])
	assert_true(r.ok, r.reason)
	assert_eq(a.speed(), 0, "the shackles hold it")
	assert_true("feat:gm:wr_flare" in _ids(e, p))
	assert_true(_act(e, p, "flare").ok)
	assert_true(a.creature.hp <= 98 and a.creature.hp >= 88, "2d6 Fire")
	assert_false(p.bonus_available)


func test_incite_frightens_and_damage_ends_it() -> void:
	var e := TestCombat.open_field(3)
	var p := e.add(TestChars.custom("paladin", "human", 3, {"paladin_subclass": ["oath_of_castigation"]}), &"party", Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(3, 3), 100)
	TestCombat.start_with(e, p)
	assert_false("feat:gm:wr_incite" in _ids(e, p), "only while Incite lasts")
	var r := e.feature_actions.perform(p, "recipe:incite", null, Vector2.INF)
	assert_true(r.ok, r.reason)
	p.bonus_available = true
	assert_true(_act(e, p, "incite", a).ok)
	assert_true(a.creature.has_condition(&"frightened"), "a Cha 1 creature fails")
	e.deal_damage(p, a, [{"amount": 1, "type": "fire"}], false, "Test")
	assert_false(a.creature.has_condition(&"frightened"), "damage ends it")


func test_kindling_aura_ignores_fire_resistance_and_turns_ally_blows_to_fire() -> void:
	var e := TestCombat.open_field(3)
	var p := e.add(TestChars.custom("paladin", "human", 7, {"paladin_subclass": ["oath_of_castigation"]}), &"party", Vector2i(2, 3))
	var f := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var foe := _target_for(e, f, _melee(e, f), 1, Vector2i(4, 3), {"resistances": ["slashing", "piercing", "bludgeoning", "fire"]})
	TestCombat.start_with(e, p)
	e.spells.zones.refresh_auras()
	var aura := CmWarriors._effect(f, "aura_of_protection")
	assert_true(aura != null and aura.data.has("wr_kindling"), "the ally's aura carries Kindling Aura")
	assert_true(f.creature.modifiers_for(&"ignore_resistance").size() >= 2)
	var ps: Array = [{"amount": 10, "type": "slashing", "weapon": true}]
	_part(e).adjust_incoming(f, foe, ps)
	assert_eq(str((ps[0] as Dictionary)["type"]), "fire", "Fire past a weapon Resistance")
	var hp := foe.creature.hp
	e.deal_damage(f, foe, [{"amount": 10, "type": "slashing", "weapon": true}], false, "Test blow")
	assert_eq(foe.creature.hp, hp - 10, "Fire Resistance ignored")


# --- Sinner -------------------------------------------------------------------------------------------------------

func _sinner(e: Encounter, level: int, cell: Vector2i, weapon: String = "jinx_infusion") -> Combatant:
	var ch := TestChars.custom("rogue", "human", level, {"rogue_subclass": ["sinner"], "jinx_weapon": [weapon]})
	if ch.equipped("main_hand").is_empty():
		ch.equip("shortsword", "main_hand")
	return e.add(ch, &"party", cell)


func test_the_jinx_table() -> void:
	var expect := {2: "snake_eyes", 3: "nightmare", 4: "nightmare", 5: "whiskey_bottle", 6: "whiskey_bottle", 7: "cheap_shot",
		8: "withered_arm", 9: "withered_arm", 10: "bad_luck", 11: "bad_luck", 12: "dead_man"}
	for n: int in expect:
		assert_eq(CmWarriors.jinx_of(n), str(expect[n]), "total %d" % n)


func test_hex_slinger_lays_a_jinx_from_the_marked_sneak_attack_dice() -> void:
	var e := TestCombat.open_field(3)
	var s := _sinner(e, 3, Vector2i(2, 2))
	TestCombat.hero(e, "ilse_varga", Vector2i(4, 2))
	var w := TestCombat.punching_bag(e, Vector2i(3, 2), 200)
	TestCombat.start_with(e, s)
	var ch := s.creature as Character
	var uses := ch.resource_left("hex_slinger")
	assert_true(uses >= 1)
	TestCombat.next_d20(e, 17)
	var r := e.attack(s, w, _melee(e, s))
	assert_true(r.hit)
	assert_eq(ch.resource_left("hex_slinger"), uses - 1, "a use spent")
	assert_true(_logged(e, "marked dice come up"), "the marked dice shown in the log")
	var jinxed := w.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id.begins_with("wr_")) \
		or CmWarriors._effect(s, "wr_dead_man") != null
	assert_true(jinxed, "a jinx laid")


func test_jinxes_do_what_the_table_says() -> void:
	var e := TestCombat.open_field(3)
	var s := _sinner(e, 3, Vector2i(2, 2))
	var w := TestCombat.punching_bag(e, Vector2i(3, 2), 200)
	TestCombat.start_with(e, s)
	var part := _part(e)
	assert_eq(part._lay_jinx(s, w, 7), "cheap_shot")
	assert_eq(w.speed(), 15, "Cheap Shot halves Speed")
	assert_eq(part._lay_jinx(s, w, 5), "cheap_shot", "Whiskey Bottle on an empty-handed creature")
	part._lay_jinx(s, w, 2)
	assert_true(w.creature.has_flag("dazed"), "Snake Eyes: one of move, action or Bonus Action")
	part._lay_jinx(s, w, 8)
	assert_true("Withered Arm" in (w.creature.d20_sources(["save:str"] as Array[String])["disadvantage"] as Array))
	part._lay_jinx(s, w, 10)
	assert_true(w.creature.modifiers_for(&"penalty_die").size() > 0, "Bad Luck: −1d6 on attacks and saves")
	part._lay_jinx(s, w, 3)
	while e.pending != null:
		e.answer_reaction(false)
	assert_true(w.creature.has_condition(&"frightened"))
	assert_ne(w.cell, Vector2i(3, 2), "it flees with its Reaction")
	assert_false(w.reaction_available)
	# Dead Man: the next attack's miss hits.
	part._lay_jinx(s, w, 12)
	var t := _target_for(e, s, _melee(e, s), 19, Vector2i(2, 3))
	TestCombat.next_d20(e, 2)
	assert_true(e.attack(s, t, _melee(e, s)).hit, "Dead Man turns the miss into a hit")
	assert_true(CmWarriors._effect(s, "wr_dead_man") == null, "only the next attack")


func test_borrowed_luck_inspires_and_pays_when_the_uses_are_gone() -> void:
	var e := TestCombat.open_field(3)
	var s := _sinner(e, 9, Vector2i(2, 2))
	var w := TestCombat.punching_bag(e, Vector2i(3, 2), 300)
	TestCombat.start_with(e, s)
	var ch := s.creature as Character
	ch.heroic_inspiration = false
	var r := CombatResult.new()
	r.damage = 5
	e.dice.log.append({"reason": "Sneak Attack damage", "sides": 6, "rolls": [3, 4, 1]})
	_part(e)._hex_slinger(s, w, {"sneak": true}, r)
	assert_true(ch.heroic_inspiration, "Heroic Inspiration from the jinx")
	while ch.resource_left("hex_slinger") > 0:
		ch.spend_resource("hex_slinger")
	e.dice.log.append({"reason": "Sneak Attack damage", "sides": 6, "rolls": [3, 4, 1]})
	_part(e)._hex_slinger(s, w, {"sneak": true}, r)
	assert_false(ch.heroic_inspiration, "spent in place of a use")
	assert_true(_logged(e, "Borrowed Luck"))


func test_pick_your_poison_twelve_is_free_and_doubles_add_psychic() -> void:
	var e := TestCombat.open_field(3)
	var s := _sinner(e, 13, Vector2i(2, 2))
	var w := TestCombat.punching_bag(e, Vector2i(3, 2), 300)
	TestCombat.start_with(e, s)
	var ch := s.creature as Character
	var uses := ch.resource_left("hex_slinger")
	var r := CombatResult.new()
	r.damage = 5
	e.dice.log.append({"reason": "Sneak Attack damage", "sides": 6, "rolls": [6, 6, 2]})
	_part(e)._hex_slinger(s, w, {"sneak": true}, r)
	assert_eq(ch.resource_left("hex_slinger"), uses, "a 12 costs no use")
	assert_eq(w.creature.hp, 300 - 6, "doubles: Psychic damage of half the level")
	assert_true(CmWarriors._effect(s, "wr_dead_man") != null, "Dead Man")
	assert_true(_logged(e, "Pick Your Poison rolls them again"))


func test_jinx_pistol_shoots_force_without_ammunition_or_loading() -> void:
	var e := TestCombat.open_field(3)
	var s := _sinner(e, 3, Vector2i(2, 2), "jinx_pistol")
	var ch := s.creature as Character
	for slot: String in ["main_hand", "off_hand"]:
		ch.unequip(slot)
	var w := TestCombat.punching_bag(e, Vector2i(6, 2), 300)
	TestCombat.start_with(e, s)
	assert_eq(ch.weapon_set_of("jinx_pistol"), 1, "made into empty hands")
	var opt := e.option_by_id(s, "weapon:jinx_pistol")
	assert_false(opt.is_empty())
	var p := opt["profile"] as WeaponProfile
	assert_eq(str(p.damage_type), "force")
	assert_true(p.proficient, "Pistol proficiency covers it")
	assert_false("loading" in p.properties)
	TestCombat.next_d20(e, 18)
	var r := e.attack(s, w, "weapon:jinx_pistol")
	assert_true(r.ok, r.reason)
	assert_true(r.hit)


func test_the_jinx_pistol_is_made_once_and_leaves_the_weapon_sets_alone() -> void:
	var e := TestCombat.open_field(3)
	var s := _sinner(e, 3, Vector2i(2, 2), "jinx_pistol")
	var ch := s.creature as Character
	ch.weapon_set_2 = {"main_hand": "shortbow"}
	var main := ch.held_id("main_hand")
	TestCombat.punching_bag(e, Vector2i(6, 2), 300)
	TestCombat.start_with(e, s)
	assert_eq(e.weapons.item_count(s, "jinx_pistol"), 1, "made into the pack")
	assert_eq(ch.weapon_set_of("jinx_pistol"), 0, "busy hands: it stays in the pack")
	assert_eq(ch.weapon_set_2, {"main_hand": "shortbow"}, "the second set untouched")
	assert_eq(ch.held_id("main_hand"), main, "the hands untouched")
	# Sold or lost, it isn't made again in the next fight.
	ch.remove_one("jinx_pistol")
	var e2 := TestCombat.open_field(3)
	var s2 := e2.add(ch, &"party", Vector2i(2, 2))
	TestCombat.punching_bag(e2, Vector2i(6, 2), 300)
	TestCombat.start_with(e2, s2)
	assert_eq(e2.weapons.item_count(s2, "jinx_pistol"), 0, "made only once")


func test_an_infused_jinx_weapon_deals_force() -> void:
	var e := TestCombat.open_field(3)
	var s := _sinner(e, 3, Vector2i(2, 2))
	var w := TestCombat.punching_bag(e, Vector2i(3, 2), 300)
	TestCombat.start_with(e, s)
	var item := str(s.get_meta("wr_jinx_item", ""))
	assert_ne(item, "", "the weapon in hand is the jinx weapon")
	var ps: Array = [{"amount": 5, "type": "piercing", "weapon": true, "item": item}]
	_part(e).adjust_incoming(s, w, ps)
	assert_eq(str((ps[0] as Dictionary)["type"]), "force")
