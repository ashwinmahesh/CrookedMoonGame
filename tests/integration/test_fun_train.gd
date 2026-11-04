extends TestCase
## The fun pass on the Ghostlight Express (lane B, 2026-11-03; vault Build/Fun Pass - Lane B Train Plan.md): every car its own
## kind of challenge and each haint its own way to fight. Played in the real cars: each haint's fight puts the haint in its
## state, which names its AI profile, and its trick (a round event) goes off; the Shroud breach after the third haint waits in
## every middle car and lets a passenger in on round 2; the Sleeper's night porter dozes in the corridor for a sneaking party to slip past; the Baggage
## Car's luggage stacks topple, the Circus's rig drops and its keg bursts, and the Tender's vents scald. Correctness only:
## no fight is played out or measured.

const GAME := preload("res://world/game_root.gd")
const HAINTS := {
	"ghostlight_g2_sleeper": ["gl_haint_sweetheart", "lovelorn", "skirmisher"],
	"ghostlight_g3_lounge": ["gl_haint_songstress", "last_song", "brute"],
	"ghostlight_g4_dining": ["gl_haint_daydreamer", "food_fight", "skirmisher"],
	"ghostlight_g5_mail": ["gl_haint_mariner", "heaving_deck", "brute"],
	"ghostlight_g6_baggage": ["gl_haint_jailbird", "flung_baggage", "brute"],
	"ghostlight_g7_circus": ["gl_haint_harlequin", "pratfall_panic", "skirmisher"],
}

var root: Node
var st: StoryState
var view: LocationView


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 2)
		ch.finish_long_rest()
		st.party.append(ch)
	Dice.reseed(11)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open(place: String) -> void:
	if is_instance_valid(root):
		root.queue_free()
		await _frames(1)
	st.location = place
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	view = root.get("view") as LocationView
	assert_true(view != null and view.loc_id == place, "the game starts in %s" % place)


func _fight(id: String) -> Encounter:
	assert_true(view.start_encounter(id), "%s starts" % id)
	await _frames(6)
	assert_true(view.in_combat and view.combat_view != null, "%s is on the board" % id)
	return view.combat_view.e


func _haint(e: Encounter) -> Combatant:
	for c in e.combatants:
		if BestiaryFeatures.monster_id(c) == "wayward_haint":
			return c
	return null


func _end(e: Encounter) -> void:
	for c in e.combatants:
		if c.side == &"enemy":
			c.creature.hp = 0
	e._check_over()
	view.combat_view.finished.emit(e.outcome)
	await _frames(6)


func test_each_haint_fights_its_own_way() -> void:
	for place: String in HAINTS:
		var spec := HAINTS[place] as Array
		await _open(place)
		var e := await _fight(str(spec[0]))
		var h := _haint(e)
		assert_true(h != null, "%s: the haint is in its fight" % place)
		assert_eq(BestiaryFeatures.state_profile(h), str(spec[2]), "%s: its state names its AI" % spec[1])
		e.game.monster_turn(h)   # the wail, which sets the profile as well
		assert_eq(str(h.ai_profile), str(spec[2]), "%s plays as a %s" % [spec[1], spec[2]])
		var events := e.legendary.round_events.events
		assert_eq(events.size(), 1, "%s: one trick" % spec[1])
		e.round_no = 2
		e.legendary.round_events.act(events[0], false)
		assert_eq(int((e.legendary.round_events.done.get(str(events[0]["id"]), {}) as Dictionary).get("times", 0)), 1,
			"%s's trick goes off" % spec[1])
		await _end(e)


func test_the_shroud_breaks_in_once_after_the_third_haint() -> void:
	for place: String in HAINTS:
		var loc := Compendium.shared().get_entry("locations", place)
		var entry: Dictionary = {}
		for en: Variant in loc["encounters"]:
			if str((en as Dictionary)["id"]) == "gl_shroud_breach":
				entry = en
		assert_false(entry.is_empty(), "%s holds the breach" % place)
		st.flags["haints_resolved"] = 2
		assert_false(StoryConditions.check(str(entry["when"]), st), "not before the third haint")
		st.flags["haints_resolved"] = 3
		assert_true(StoryConditions.check(str(entry["when"]), st), "after it")
		st.flags["gl_breach_done"] = true
		assert_false(StoryConditions.check(str(entry["when"]), st), "and only once")
		st.flags.erase("gl_breach_done")
	st.flags["haints_resolved"] = 3
	await _open("ghostlight_g4_dining")
	# The party arrives in the booths' area, so the window bursts as it steps in.
	await _frames(6)
	assert_true(view.in_combat and view.fight_id == "gl_shroud_breach", "the breach opens as the party arrives")
	var e := view.combat_view.e
	var before := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy").size()
	assert_eq(before, 2, "a corrupted passenger and a sliver of the Phantom")
	e.round_no = 2
	e.legendary.round_events.act(e.legendary.round_events.events[0], false)
	var after := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy").size()
	assert_eq(after, 3, "the mist turns another passenger")
	await _end(e)


func test_the_night_porter_dozes_in_the_sleeper_corridor() -> void:
	await _open("ghostlight_g2_sleeper")
	var loc := view.loc
	var porter: Dictionary = {}
	for en: Variant in loc["encounters"]:
		if str((en as Dictionary)["id"]) == "gl_night_porter":
			porter = en
	assert_true(bool(porter.get("waiting", false)), "a fight that waits in view")
	var m := (porter["monsters"] as Array)[0] as Dictionary
	assert_true(str(porter.get("surprise", "")) == "enemies" and m.has("facing"), "asleep in his chair, facing the cabins")
	view._waiting_key = ""
	LocationStealth.refresh_waiting(view)
	assert_true(view.waiting.any(func(w: Dictionary) -> bool: return str(w["encounter"]) == "gl_night_porter"), "he stands in the corridor")


func test_the_cars_rooms_fight_back() -> void:
	await _open("ghostlight_g6_baggage")
	var e := await _fight("gl_haint_jailbird")
	var stacks := e.objects.list.filter(func(o: BattleObject) -> bool: return o.prop_id.begins_with("g6_stack_"))
	assert_eq(stacks.size(), 4, "four luggage stacks on the board")
	for o: BattleObject in stacks:
		assert_eq(o.moves, "topple", "%s topples" % o.prop_id)
	await _end(e)
	await _open("ghostlight_g7_circus")
	e = await _fight("gl_haint_harlequin")
	var rig := e.objects.list.filter(func(o: BattleObject) -> bool: return o.prop_id == "g7_lighting_rig")
	assert_true(rig.size() == 1 and (rig[0] as BattleObject).hangs, "the lighting rig hangs over the ring")
	var keg := e.objects.list.filter(func(o: BattleObject) -> bool: return o.prop_id == "g7_powder_keg")
	assert_true(keg.size() == 1 and not (keg[0] as BattleObject).bursts.is_empty(), "the powder keg bursts")
	await _end(e)
	var tender := Compendium.shared().get_entry("locations", "ghostlight_g8_tender")
	var vents := (tender["areas"] as Array).filter(func(a: Variant) -> bool: return (a as Dictionary).has("hazard"))
	assert_eq(vents.size(), 2, "two steam vents in the Tender")
