extends TestCase
## The Fabled Heirlooms of the Crimson Monastery (R14) and the Drowned Crossroads (R15) whose properties are code
## (combat/crooked/cm_heirlooms_arms.gd): the Shield of Marius Renathyr, the Sword of the Crimson Abbot, the Cutlass of
## Briggsy Kratch and the Blunderbuss of the Grinning Sinner.


func _part(e: Encounter) -> CmHeirloomsArms:
	for p in (e.game as CrookedFeatures).parts:
		if p is CmHeirloomsArms:
			return p as CmHeirloomsArms
	return null


## A level-`level` hero carrying and attuned to `item` (in hand when `slot` is given), a foe, and an ally beside the hero.
func _fight(item: String, slot: String, level: int = 8) -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), level)
	var ch := hero.creature as Character
	ch.add_item(item, 1)
	ch.attune(item)
	if slot != "":
		ch.equip(item, slot)
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 80)
	var ally := e.add(TestChars.dummy(40, true), &"party", Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, foe, ally]


func _hit(attacker: Combatant, target: Combatant, total: int, ac: int) -> Dictionary:
	var t := D20Test.new()
	t.kind = D20Test.Kind.ATTACK_ROLL
	t.kept = total
	t.total = total
	t.target = ac
	t.success = true
	return {"c": attacker, "target": target, "t": t, "ac": ac, "critical": false, "option": {"melee": true}}


func test_valorous_guard_turns_a_hit_on_an_ally_aside() -> void:
	var got := _fight("shield_of_marius_renathyr", "off_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var ally := got[3] as Combatant
	var st := _hit(foe, ally, 14, 12)
	var out: Array = []
	var missed := [false]
	var miss := func() -> CombatResult:
		missed[0] = true
		return CombatResult.new()
	_part(e).after_hit_target(st, miss, out)
	var offer: Dictionary = {}
	for o: Variant in out:
		if str((o as Dictionary)["kind"]) == "cm_valorous_guard":
			offer = o as Dictionary
	assert_false(offer.is_empty(), "the shield's bearer is offered the guard")
	assert_true(offer["reactor"] == hero)
	(offer["use"] as Callable).call()
	(offer["stop"] as Callable).call()
	assert_true(bool(missed[0]), "the hit misses")
	assert_eq(int(st["ac"]), 12 + 2 + 2, "+2 + the tier (2 at level 8)")
	assert_false(hero.reaction_available)
	assert_eq(str(hero.get_meta(CmHeirloomsArms.WRATH_META, "")), foe.id, "Righteous Wrath readies on the attacker")
	var dice := _part(e).hit_dice(hero, foe, {}, {})
	assert_eq(dice.size(), 1)
	assert_eq(str(dice[0]["type"]), "radiant")


func test_valorous_guard_is_not_offered_when_it_would_not_be_enough() -> void:
	var got := _fight("shield_of_marius_renathyr", "off_hand")
	var e := got[0] as Encounter
	var st := _hit(got[2] as Combatant, got[3] as Combatant, 30, 12)
	var out: Array = []
	_part(e).after_hit_target(st, func() -> CombatResult: return CombatResult.new(), out)
	assert_true(out.filter(func(o: Variant) -> bool: return str((o as Dictionary)["kind"]) == "cm_valorous_guard").is_empty())


func test_irresistible_hunger_from_level_7_only() -> void:
	for level: int in [3, 8]:
		var got := _fight("sword_of_the_crimson_abbot", "main_hand", level)
		var e := got[0] as Encounter
		var parts: Array = [{"amount": 10, "type": "necrotic"}, {"amount": 6, "type": "slashing"}]
		_part(e).adjust_incoming(got[1] as Combatant, got[2] as Combatant, parts)
		assert_eq(bool((parts[0] as Dictionary).get("ignore_resistance", false)), level >= 7, "level %d" % level)
		assert_false(bool((parts[1] as Dictionary).get("ignore_resistance", false)), "only Necrotic")


func test_raise_the_stakes_settles_for_the_one_with_more_hits() -> void:
	var got := _fight("cutlass_of_briggsy_kratch", "main_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	foe.cell = Vector2i(2, 4)
	assert_eq(e.items.power_why(hero, e.items.find_power(hero, "cutlass_of_briggsy_kratch", "stakes")), "")
	assert_true(e.items.use(hero, "cutlass_of_briggsy_kratch", "stakes", [foe]).ok)
	assert_false(hero.bonus_available)
	var mark := CmHeirloomPart.fx_of(foe, CmHeirloomsArms.STAKES_KEY + hero.id)
	assert_true(mark != null, "the creature is marked")
	var part := _part(e)
	part.after_hit(hero, foe, {}, {}, CombatResult.new())
	part.after_hit(hero, foe, {}, {}, CombatResult.new())
	part.after_hit(foe, hero, {}, {}, CombatResult.new())
	assert_eq(int(mark.data["mine"]), 2)
	assert_eq(int(mark.data["theirs"]), 1)
	var foe_hp := foe.creature.hp
	var hero_hp := hero.creature.hp
	part.turn_start(hero)
	assert_true(foe.creature.hp < foe_hp, "the loser takes the Psychic damage")
	assert_eq(hero.creature.hp, hero_hp, "the winner doesn't")
	assert_true(CmHeirloomPart.fx_of(foe, CmHeirloomsArms.STAKES_KEY + hero.id) == null, "the stake is settled")


func test_jinxcraft_panache_against_someone_who_already_hurt_the_bearer() -> void:
	var got := _fight("cutlass_of_briggsy_kratch", "main_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var part := _part(e)
	var st := _hit(foe, hero, 15, 14)
	var out: Array = []
	part.after_hit_target(st, func() -> CombatResult: return CombatResult.new(), out)
	assert_true(out.is_empty(), "not hurt yet this turn")
	part.after_damage(foe, hero, 5)
	part.after_hit_target(st, func() -> CombatResult: return CombatResult.new(), out)
	assert_eq(out.size(), 1)
	assert_eq(str((out[0] as Dictionary)["kind"]), "cm_jinxcraft_panache")


func test_jinxshot_sprays_a_cone_and_the_sinner_jinxes() -> void:
	var got := _fight("blunderbuss_of_the_grinning_sinner", "main_hand")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var ally := got[3] as Combatant
	ally.cell = Vector2i(2, 6)
	foe.cell = Vector2i(5, 3)
	var before := foe.creature.hp
	var r := e.items.use(hero, "blunderbuss_of_the_grinning_sinner", "jinxshot", [], e.center_of(foe))
	assert_true(r.ok, r.reason)
	assert_true(foe.creature.hp < before, "the cone's Necrotic lands")
	assert_true(CmHeirloomPart.fx_of(foe, CmHeirloomsArms.JINX_KEY + hero.id) != null, "a Charisma 1 creature can't shake the jinx")
