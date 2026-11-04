extends TestCase
## The prologue's four monsters (package R10, section 10; vault Build/D2 notes): what the engine runs from their data
## alone, with no game code. The Locomotive's phase, its echoes going with it, the Stoker's Soul Burn and the haint's
## resistances, its Soul Fuel and the Soul Cans of the wreck fights. The parts that need the bestiary's own code (the
## bottle trap, Corpse Fuel, Ghostly Rails) are tested with it.

const LOCOMOTIVE_SWITCH := "phantom_in_the_machine"


## A field big enough for a Gargantuan engine (4 x 4 squares) and four heroes.
func _field() -> Encounter:
	var rows: Array[String] = []
	for z in 14:
		rows.append("....................")
	var e := TestCombat.encounter(rows, 3)
	e.default_player_reaction = "never"
	return e


func _hurt(e: Encounter, c: Combatant, amount: int, type: String = "force") -> void:
	e.deal_damage(null, c, [{"amount": amount, "type": type}], false, "test")


static func _has_action(c: Combatant, id: String) -> bool:
	for a: Variant in MonsterActions.data_of(c).get("actions", []):
		if str((a as Dictionary)["id"]) == id:
			return true
	return false


func test_the_prologue_blocks_are_the_books_numbers() -> void:
	var expected := {"wayward_haint": [11, 13], "soulfire_stoker": [14, 59], "wildpyre": [14, 58],
		"wildpyre_large": [14, 58], "ghostlight_locomotive": [15, 94]}
	for id: String in expected:
		var m := TestCombat.monster(id)
		assert_eq(m.ac_value(), int((expected[id] as Array)[0]), "%s's Armor Class" % id)
		assert_eq(m.max_hp(), int((expected[id] as Array)[1]), "%s's Hit Points" % id)


func test_a_haint_shrugs_off_weapons_and_not_radiant() -> void:
	var haint := TestCombat.monster("wayward_haint")
	for type: String in ["slashing", "piercing", "bludgeoning", "fire", "cold"]:
		assert_true(haint.resistance_source(StringName(type)) != "", "resists %s" % type)
	assert_eq(haint.resistance_source(&"radiant"), "", "radiant is the answer to a haint")
	assert_true(haint.immunity_source(&"poison") != "", "immune to poison")


func test_the_locomotive_switches_once_when_bloodied() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(12, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 3)
	TestCombat.start_with(e, hero)
	assert_false(_has_action(engine, "multiattack"), "no Multiattack in the first phase")
	engine.set_meta("legendary_resistance_used", 2)
	_hurt(e, engine, 40)
	assert_false(e.legendary.phases.is_active(engine, LOCOMOTIVE_SWITCH), "54 of 94 is not Bloodied")
	_hurt(e, engine, 10)
	assert_true(e.legendary.phases.is_active(engine, LOCOMOTIVE_SWITCH), "44 of 94 is Bloodied: the Crooked Switch")
	assert_true(_has_action(engine, "multiattack"), "two Rail Slams a turn from now on")
	assert_eq(int(engine.get_meta("legendary_resistance_used", 0)), 0, "its Legendary Resistance comes back")
	assert_true(bool(e.legendary.story_flags.get("gl_locomotive_switched", false)), "the cutscene's sting is told to the story")
	var told := e.events.filter(func(ev: Dictionary) -> bool: return str(ev["type"]) == "phase" and str(ev["phase"]) == LOCOMOTIVE_SWITCH)
	assert_eq(told.size(), 1, "the view is told once")
	assert_eq(str((told[0] as Dictionary)["say"]), "gl_locomotive_switch", "to say its line")
	assert_eq(str((told[0] as Dictionary)["cutscene"]), "gl_locomotive_wakes_3", "over its cutscene")
	engine.set_meta("legendary_resistance_used", 1)
	_hurt(e, engine, 5)
	assert_eq(int(engine.get_meta("legendary_resistance_used", 0)), 1, "the Switch happens once")


func test_the_locomotives_echoes_go_with_it() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(12, 5))
	var echo := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(8, 9))
	echo.set_meta("summoner", engine.id)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 3)
	TestCombat.start_with(e, hero)
	_hurt(e, engine, 400)
	assert_true(engine.creature.dead, "the engine falls")
	assert_eq(str(e.legendary.departed.get(echo.id, "")), "vanish", "and the echo it held goes with it")


func test_the_stokers_soul_burn_scorches_whoever_stands_close() -> void:
	var e := _field()
	var stoker := e.add(TestCombat.monster("soulfire_stoker"), &"enemy", Vector2i(6, 5))
	var near := TestCombat.hero(e, "hedda_ironvow", Vector2i(5, 5), 3)
	var far := TestCombat.hero(e, "ilse_varga", Vector2i(12, 9), 3)
	TestCombat.start_with(e, stoker)
	var near_hp := near.creature.hp
	var far_hp := far.creature.hp
	e.end_turn()
	assert_true(near.creature.hp < near_hp, "5 ft from the stoker at the end of its turn: Necrotic damage")
	assert_eq(far.creature.hp, far_hp, "out of reach: untouched")


# --- The bestiary's own code (combat/bestiary/bestiary_features.gd, a part of CrookedFeatures) -------------------------

func test_the_bestiary_is_a_part_of_the_games_features() -> void:
	var e := _field()
	assert_true(e.game is CrookedFeatures, "the game names its features module")
	assert_true((e.game as CrookedFeatures).parts.any(func(p: GameFeatures) -> bool: return p is BestiaryFeatures), "and the bestiary is in it")


func test_a_hostile_haints_first_turn_is_a_wail() -> void:
	var e := _field()
	var haint := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(5, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 1)
	TestCombat.start_with(e, haint)
	var hp := hero.creature.hp
	e.ai.play_turn(haint)
	assert_eq(hero.creature.hp, hp, "the first turn hurts no one")
	assert_true(haint.has_meta(BestiaryFeatures.WAILED_META), "it wailed")
	e.end_turn()
	for c in e.order:
		if c != haint and c != hero:
			e.end_turn()
	assert_true(e.current() == haint or e.current() == hero, "the round came round")


func test_draining_regret_stops_at_five_levels_and_remembers_them() -> void:
	var e := _field()
	var haint := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(5, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 1)
	TestCombat.start_with(e, hero)
	var rd := {"do": "exhaustion", "params": {"levels": 1, "max": 5, "until": "rest"}}
	hero.creature.exhaustion = 3
	for i in 4:
		e.monster_actions._rider(haint, hero, rd, {}, "Draining Regret")
	assert_eq(hero.creature.exhaustion, 5, "never past 5")
	assert_eq(int(hero.creature.get_meta(BestiaryFeatures.REST_EXHAUSTION_META, 0)), 2, "the two levels it gave are counted for the rest")


func test_the_stoker_burns_a_corpse_it_sees() -> void:
	var e := _field()
	var stoker := e.add(TestCombat.monster("soulfire_stoker"), &"enemy", Vector2i(12, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 12), 3)
	var dead := e.add(TestCombat.monster("ghost"), &"enemy", Vector2i(9, 5))
	TestCombat.start_with(e, stoker)
	dead.creature.dead = true
	dead.creature.hp = 0
	e.ai.play_turn(stoker)
	assert_true(dead.has_meta(BestiaryFeatures.ASHED_META), "the body is ash")
	assert_true(e.distance(stoker, dead) <= 5, "the stoker went to it")


## The Tender's stoker is the book's corrupted one: 30 Hit Points and one Sear for each Multiattack, and it still burns the dead.
func test_the_tenders_stoker_is_the_corrupted_one() -> void:
	var m := TestCombat.monster("corrupted_soulfire_stoker")
	assert_eq(m.max_hp(), 30, "30 Hit Points")
	var e := _field()
	var stoker := e.add(m, &"enemy", Vector2i(12, 5))
	var data := MonsterActions.data_of(stoker)
	var sears := 0
	for a: Variant in data.get("actions", []):
		if str((a as Dictionary)["id"]) == "multiattack":
			for part: Variant in (a as Dictionary)["multiattack"]:
				sears += int((part as Dictionary).get("count", 0))
	assert_eq(sears, 1, "one Sear for a Multiattack")
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 12), 3)
	var dead := e.add(TestCombat.monster("ghost"), &"enemy", Vector2i(9, 5))
	TestCombat.start_with(e, stoker)
	dead.creature.dead = true
	dead.creature.hp = 0
	e.ai.play_turn(stoker)
	assert_true(dead.has_meta(BestiaryFeatures.ASHED_META), "it burns a corpse it sees, like its elder")
	assert_true(hero != null)
	var fights := Compendium.shared().get_entry("locations", "ghostlight_g8_tender").get("encounters", []) as Array
	for en: Variant in fights:
		for mon: Variant in (en as Dictionary)["monsters"]:
			assert_true(str((mon as Dictionary)["monster"]) != "soulfire_stoker", "the Tender's fights use the corrupted stoker")


## The wreck fight's own entry for `id` (data/locations/ghostlight_wreckage.json, gl_locomotive's `objects`), moved to
## `cell` when given.
static func _wreck_object(id: String, cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	for en: Variant in Compendium.shared().get_entry("locations", "ghostlight_wreckage").get("encounters", []):
		if str((en as Dictionary)["id"]) != "gl_locomotive":
			continue
		for x: Variant in (en as Dictionary).get("objects", []):
			if str((x as Dictionary).get("id", "")) == id:
				var entry := (x as Dictionary).duplicate(true)
				if cell.x >= 0:
					entry["cell"] = [cell.x, cell.y]
				return entry
	return {}


static func _echoes(e: Encounter) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in e.combatants:
		if c.has_meta(ObjectFuel.RELEASED_META):
			out.append(c)
	return out


## The wreck fights put down three Soul Cans, a bottled haint's jar standing in for one: never more than three fuel
## between them for up to three bottled.
func test_the_wreck_fights_put_down_three_cans_less_one_for_each_jar() -> void:
	var st := StoryState.new()
	var lay := func() -> Array[String]:
		var out: Array[String] = []
		for en: Variant in Compendium.shared().get_entry("locations", "ghostlight_wreckage").get("encounters", []):
			if str((en as Dictionary)["id"]) != "gl_locomotive":
				continue
			for x: Variant in (en as Dictionary).get("objects", []):
				if StoryConditions.check(str((x as Dictionary).get("when", "")), st):
					out.append(str((x as Dictionary)["id"]))
		return out
	assert_eq(lay.call(), ["soul_can_1", "soul_can_2", "soul_can_3"], "nothing bottled: the three cans")
	st.set_flag("haint_mariner_how", "bottled")
	st.set_flag("gl_bottled", 1)
	assert_eq(lay.call(), ["soul_can_1", "soul_can_2", "jar_mariner"], "the Mariner's jar stands in for the third can")
	for h: String in ["sweetheart", "jailbird"]:
		st.set_flag("haint_%s_how" % h, "bottled")
	st.set_flag("gl_bottled", 3)
	assert_eq(lay.call(), ["jar_sweetheart", "jar_mariner", "jar_jailbird"], "three bottled: three jars, no cans")
	for en: Variant in Compendium.shared().get_entry("locations", "ghostlight_wreckage").get("encounters", []):
		if str((en as Dictionary)["id"]) == "gl_locomotive_edge":
			assert_eq((en as Dictionary).get("objects", []), _wreck_spec_objects(), "the walk-away fight lays the same cans")


static func _wreck_spec_objects() -> Array:
	for en: Variant in Compendium.shared().get_entry("locations", "ghostlight_wreckage").get("encounters", []):
		if str((en as Dictionary)["id"]) == "gl_locomotive":
			return (en as Dictionary).get("objects", []) as Array
	return []


func test_a_can_eaten_feeds_the_locomotive_and_lets_out_an_echo() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(12, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 12), 3)
	var can := e.objects.put(_wreck_object("soul_can_1", Vector2i(9, 6)))
	TestCombat.start_with(e, hero)
	_hurt(e, engine, 30)
	var before := engine.creature.hp
	e.end_turn()
	while e.current() != engine:
		e.end_turn()
	assert_true(can.destroyed, "the can is gone")
	assert_eq(engine.creature.hp, before + 20, "20 Hit Points from it")
	var echoes := _echoes(e)
	assert_eq(echoes.size(), 1, "an echo rose from it")
	assert_eq(echoes[0].creature.hp, 7, "at half Hit Points")
	assert_eq(e.order.find(echoes[0]), e.order.find(engine) + 1, "and fights beside the engine")
	_hurt(e, engine, 400)
	assert_eq(str(e.legendary.departed.get(echoes[0].id, "")), "vanish", "and goes with it")


func test_a_smashed_jar_lets_out_its_haints_echo_without_feeding_it() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(16, 9))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2), 3)
	var jar := e.objects.put(_wreck_object("jar_mariner", Vector2i(3, 2)))
	TestCombat.start_with(e, hero)
	e.objects.damage(jar, [{"amount": 4, "type": "lightning"}], hero, "a spark")
	assert_false(jar.destroyed, "lightning doesn't harm it")
	e.objects.damage(jar, [{"amount": 4, "type": "bludgeoning"}], hero, "a blow")
	var echoes := _echoes(e)
	assert_eq(echoes.size(), 1, "the haint's echo")
	assert_eq(echoes[0].name(), "The Mariner's Echo", "with the haint's own name")
	assert_eq(engine.creature.hp, engine.creature.max_hp(), "and the engine got nothing")
	assert_eq(e.game.monster_turn(echoes[0]), null, "an echo fights at once: no opening wail")
	assert_false(echoes[0].has_meta(BestiaryFeatures.WAILED_META))


func test_the_locomotive_fights_a_hero_beside_it_instead_of_running_to_a_can() -> void:
	# Ashwin, 2026-11-03: "Why does ghostlight locomotive keep running away and not attacking?" It walked to a Soul Can ahead of
	# striking and ended its turn there with nobody in reach; a hero it can strike where it stands now keeps it fighting.
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(2, 2))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(6, 3), 3)
	e.objects.put(_wreck_object("soul_can_1", Vector2i(15, 12)))
	TestCombat.start_with(e, engine)
	var start := engine.cell
	e.ai.play_turn(engine)
	assert_ne(str(e.ai.last_plan.get("kind", "")), "fuel", "the hero beside it, not the can")
	assert_eq(engine.cell, start, "it did not walk off to the can")


func test_the_locomotive_goes_for_a_can_when_no_hero_is_in_reach() -> void:
	var e := _field()
	var engine := e.add(TestCombat.monster("ghostlight_locomotive"), &"enemy", Vector2i(2, 2))
	TestCombat.hero(e, "hedda_ironvow", Vector2i(19, 1), 3)
	var can := e.objects.put(_wreck_object("soul_can_1", Vector2i(15, 12)))
	TestCombat.start_with(e, engine)
	e.ai.play_turn(engine)
	assert_eq(str(e.ai.last_plan.get("kind", "")), "fuel", "with no one to strike it feeds")
	assert_true(e.objects.distance_ft(engine, can) <= 10, "it ends its move within 10 ft of the can")


func test_ghostly_rails_grapples_whoever_the_locomotive_passes_through() -> void:
	var e := _field()
	# (100 ft of Speed, so that half of it covers the extra cost of crossing a creature's space: its whole body is inside the hero's square for four steps)
	var data := Compendium.shared().monster_data("ghostlight_locomotive").duplicate(true)
	(data["speed"] as Dictionary)["walk"] = 100
	var engine := e.add(Monster.from_data(data), &"enemy", Vector2i(14, 4))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(13, 5), 3)
	var far := TestCombat.hero(e, "ilse_varga", Vector2i(2, 12), 3)
	TestCombat.start_with(e, hero)
	var r := e.legendary.use(engine, "ghostly_rails", null, Vector2i(9, 4))
	assert_true(r.ok, "the rails run: %s" % r.reason)
	assert_true(engine.cell.x < 14, "the engine moved along them")
	assert_true(hero.creature.has_condition(&"grappled"), "the hero it passed through is held")
	assert_false(far.creature.has_condition(&"grappled"), "the far one is not")


# --- R11-R12: Teleport, Dark Teleport and Tooth Theft ----------------------------------------------------------------------

func test_ketgrinn_teleports_beside_a_hero_it_cant_walk_to() -> void:
	var e := _field()
	var ketgrinn := e.add(TestCombat.monster("ketgrinn"), &"enemy", Vector2i(1, 1))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(13, 1), 3)
	TestCombat.start_with(e, ketgrinn)
	e.ai.play_turn(ketgrinn)
	assert_true(e.distance(ketgrinn, hero) <= 5, "it stands beside the hero (%d ft)" % e.distance(ketgrinn, hero))


func test_ketgrinn_walks_when_it_can() -> void:
	var e := _field()
	var ketgrinn := e.add(TestCombat.monster("ketgrinn"), &"enemy", Vector2i(1, 1))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(6, 1), 3)
	TestCombat.start_with(e, ketgrinn)
	e.ai.play_turn(ketgrinn)
	assert_true(e.distance(ketgrinn, hero) <= 5 and ketgrinn.cell.x < 6, "it walked there (cell %s)" % ketgrinn.cell)


func test_the_lurker_does_not_teleport_in_bright_light() -> void:
	var e := _field()
	var lurker := e.add(TestCombat.monster("lurker_in_the_dark"), &"enemy", Vector2i(1, 1))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(19, 1), 3)
	e.ambient_light = "bright"
	TestCombat.start_with(e, lurker)
	e.ai.play_turn(lurker)
	assert_true(e.distance(lurker, hero) > 10, "in bright light it can only run (%d ft off)" % e.distance(lurker, hero))
	var e2 := _field()
	var lurker2 := e2.add(TestCombat.monster("lurker_in_the_dark"), &"enemy", Vector2i(1, 1))
	var hero2 := TestCombat.hero(e2, "hedda_ironvow", Vector2i(19, 1), 3)
	e2.ambient_light = "dim"
	TestCombat.start_with(e2, lurker2)
	e2.ai.play_turn(lurker2)
	assert_true(e2.distance(lurker2, hero2) <= 10, "out of bright light it steps through to the hero (%d ft)" % e2.distance(lurker2, hero2))


func test_tooth_theft_takes_one_tooth_and_saves_only_once() -> void:
	var e := _field()
	var swarm := e.add(TestCombat.monster("boogleswarm"), &"enemy", Vector2i(5, 5))
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(4, 5), 1)
	TestCombat.start_with(e, hero)
	var rd := {"do": "tooth_theft", "params": {"save": {"ability": "con", "dc": 30}, "auto_success_if_already_lost": true, "implant": true}}
	e.monster_actions._rider(swarm, hero, rd, {}, "Bite")
	assert_eq(int(hero.creature.get_meta(BestiaryFeatures.TEETH_LOST_META, 0)), 1, "DC 30: a tooth is lost")
	e.monster_actions._rider(swarm, hero, rd, {}, "Bite")
	assert_eq(int(hero.creature.get_meta(BestiaryFeatures.TEETH_LOST_META, 0)), 1, "and no second one")
	assert_true(hero.id in (swarm.get_meta(BestiaryFeatures.TEETH_META) as Array), "the swarm wears it")
