extends TestCase
## The Revelry Suit, the Marotte of the Lord of Fools (R21) and the Amber Birdcage (R13), whose properties are code
## (combat/crooked/cm_heirlooms_revels.gd), and the Cauldron of the Vermintoll Coven's data.


func _part(e: Encounter) -> CmHeirloomsRevels:
	for p in (e.game as CrookedFeatures).parts:
		if p is CmHeirloomsRevels:
			return p as CmHeirloomsRevels
	return null


func _fight(item: String, level: int = 8, foe_kind: String = "humanoid") -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), level)
	var ch := hero.creature as Character
	ch.add_item(item, 1)
	ch.attune(item)
	var data := Compendium.shared().item_data(item)
	if MagicItems.worn_slot(data) != "":
		ch.wear(item)
	elif MagicItems.is_held(data):
		ch.equip(item, "main_hand")
	var foe := TestCombat.punching_bag(e, Vector2i(4, 3), 80, foe_kind)
	TestCombat.start_with(e, hero)
	return [e, hero, foe]


func _save(kept: int, target: int) -> D20Test:
	var t := D20Test.new()
	t.kind = D20Test.Kind.SAVING_THROW
	t.kept = kept
	t.total = kept
	t.target = target
	t.success = kept >= target
	return t


func test_dancing_dodge_turns_a_failed_dex_save_and_the_curse_grows() -> void:
	var got := _fight("revelry_suit")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var t := _save(5, 15)
	var keys: Array[String] = ["save:all", "save:dex"]
	var out: Array = []
	_part(e).d20_offers(hero, t, keys, out)
	assert_eq(out.size(), 1)
	((out[0] as Dictionary)["use"] as Callable).call()
	assert_true(t.success, "the save succeeds instead")
	var entry := (hero.creature as Character).entry_of("revelry_suit")
	assert_eq(int(entry.get(CmHeirloomsRevels.DANCE_DC, 0)), 2, "the Dancing Curse's DC grows by 2")
	out.clear()
	_part(e).d20_offers(hero, _save(5, 15), keys, out)
	assert_true(out.is_empty(), "once a dusk")


func test_wild_steps_gives_free_movement() -> void:
	var got := _fight("revelry_suit")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	assert_true(e.items.use(hero, "revelry_suit", "steps").ok)
	assert_eq(hero.free_move_ft, hero.speed(), "the bearer's Speed without Opportunity Attacks")
	assert_false(hero.bonus_available)


func test_the_dancing_curse_takes_the_first_turn() -> void:
	var got := _fight("revelry_suit")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	(hero.creature as Character).entry_of("revelry_suit")[CmHeirloomsRevels.DANCE_DC] = 40
	_part(e).initiative_rolled()
	assert_true(hero.creature.has_condition(&"incapacitated"), "no save reaches DC 40")


func test_fortunes_fool_comes_back_on_a_natural_1() -> void:
	var got := _fight("marotte_of_the_lord_of_fools")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var part := _part(e)
	part.spend_use(hero, "marotte_of_the_lord_of_fools", "laughter")
	assert_false(part.use_left(hero, "marotte_of_the_lord_of_fools", "laughter"))
	var t := _save(1, 10)
	var keys: Array[String] = ["save:all", "save:con"]
	var out: Array = []
	part.d20_offers(hero, t, keys, out)
	for o: Variant in out:
		((o as Dictionary)["use"] as Callable).call()
	assert_true(part.use_left(hero, "marotte_of_the_lord_of_fools", "laughter"), "the laughter is ready again")


func test_coulrophobia_turns_fear_on_its_source() -> void:
	var got := _fight("marotte_of_the_lord_of_fools")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var t := _save(18, 16)
	var keys: Array[String] = ["save:all", "save:wis", "save_vs:frightened", "save_vs:spell:" + foe.id]
	var out: Array = []
	_part(e).d20_offers(hero, t, keys, out)
	assert_eq(out.size(), 1)
	((out[0] as Dictionary)["use"] as Callable).call()
	assert_true(foe.creature.has_condition(&"frightened"), "a Wisdom 1 creature can't reach DC 16")
	assert_false(hero.reaction_available)


func test_the_birdcage_catches_a_bloodied_fiend_and_eats_it() -> void:
	var got := _fight("amber_birdcage", 8, "fiend")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var foe := got[2] as Combatant
	var capture := e.items.find_power(hero, "amber_birdcage", "capture")
	assert_eq(e.items.power_why(hero, capture), "No Bloodied fiend within 30 ft")
	foe.creature.hp = 20
	assert_eq(e.items.power_why(hero, capture), "")
	for i in 20:
		if str(foe.get_meta("left_fight", "")) == "vanish":
			break
		hero.action_available = true
		assert_true(e.items.use(hero, "amber_birdcage", "capture", [foe]).ok)
	assert_eq(str(foe.get_meta("left_fight", "")), "vanish", "caught in the cage (Charisma 1 fails DC 15 on all but a 20)")
	var entry := (hero.creature as Character).entry_of("amber_birdcage")
	assert_eq((entry.get(CmHeirloomsRevels.BIRDS, []) as Array).size(), 1)
	assert_eq(int(entry.get(CmHeirloomsRevels.CAGE_CURSE, 0)), 1, "the curse grows")
	hero.action_available = true
	var thp := hero.creature.temp_hp
	assert_true(e.items.use(hero, "amber_birdcage", "eat").ok)
	assert_true((entry.get(CmHeirloomsRevels.BIRDS, []) as Array).is_empty())
	assert_true(hero.creature.temp_hp > thp, "a CR 1 fiend: no slot of level 0, so Temporary Hit Points")
	assert_eq(int(entry.get(CmHeirloomsRevels.CAGE_CURSE, 0)), 2)


func test_the_cauldrons_vermincall_and_saves() -> void:
	var data := Compendium.shared().item_data("cauldron_of_the_vermintoll_coven")
	var powers := data.get("powers", []) as Array
	assert_eq(str((powers[0] as Dictionary)["spell"]), "conjure_animals")
	assert_eq(str(((data["modifiers"] as Array)[0] as Dictionary)["value"]), "tier")
