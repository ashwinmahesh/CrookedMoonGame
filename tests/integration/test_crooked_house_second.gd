extends TestCase
## R12, the Crooked House, second floor (the wiring step for H9 to H12): the clock, the children's room with its hide-and-seek,
## the bathroom and the master bedroom. The ids the package names are there, every fight's foes exist and start on floor the party
## can reach and spread out, the round events do what the digest lists, the lurker's hiding place is fixed by the playthrough's
## seed and covers all six places across seeds, and the six searches (or the right one) start the right version of its fight.

const PLACE := "crooked_house_second"
const SPOTS := ["h10_closet", "h10_bed_left", "h10_bed_right", "h10_chest", "h10_armoire", "h10_window"]


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", PLACE)


func _rows() -> Array:
	return (_loc()["map"] as Dictionary)["rows"] as Array


func _walkable(x: int, y: int) -> bool:
	var rows := _rows()
	return y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length() and ".~1234_=".contains((rows[y] as String)[x])


func _floor(c: Vector2i) -> bool:
	var rows := _rows()
	return c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < (rows[c.y] as String).length() and ".~1234_".contains((rows[c.y] as String)[c.x])


func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func _reach(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n) and _walkable(n.x, n.y):
				seen[n] = true
				todo.append(n)
	return seen


func _prop(id: String) -> Dictionary:
	for p: Dictionary in _loc().get("props", []):
		if str(p["id"]) == id:
			return p
	return {}


func _encounters(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _loc().get("encounters", []):
		if str(e["id"]) == id:
			out.append(e)
	return out


func _fresh() -> StoryState:
	GameState.reset()
	var st := GameState.story
	st.visited[PLACE] = true
	return st


# --- What is there -------------------------------------------------------------------------------------------------------------


func test_the_ids_the_package_names_are_all_there() -> void:
	for id: String in ["h9_clock", "h9_rail", "h10_closet", "h10_bed_left", "h10_bed_right", "h10_chest", "h10_armoire", "h10_window", "h10_doll",
			"the_bag", "h11_tub", "h12_bed", "h12_journal", "h12_scratchings", "h12_rope"]:
		assert_true(not _prop(id).is_empty(), "the prop %s" % id)
	for id: String in ["ch_clock", "ch_lurker", "ch_bath", "ch_jasper"]:
		assert_true(not _encounters(id).is_empty(), "the fight %s" % id)
	var boxes := {}
	for c: Dictionary in _loc().get("containers", []):
		boxes[str(c["id"])] = c
	assert_true(boxes.has("h11_duck"), "the duck's container")
	assert_eq(str(((boxes["h11_duck"] as Dictionary)["items"] as Array)[0]["id"]), "yellow_duck_figurine", "holds the figurine")
	var doors := {}
	for d: Dictionary in _loc().get("doors", []):
		doors[str(d["id"])] = d
	assert_eq(int((doors["h12_balcony_doors"] as Dictionary)["lock_dc"]), 15, "the balcony doors are locked at DC 15")
	var traps := {}
	for t: Dictionary in _loc().get("traps", []):
		traps[str(t["id"])] = t
	assert_true(traps.has("balcony_edge") and traps.has("balcony_edge_thunder"), "the balcony's storm, under the Narrator's id")


func test_the_examine_props_start_their_fights_and_the_gates_are_set() -> void:
	assert_eq(str(_encounters("ch_clock")[0]["trigger"]), "examine:h9_clock")
	assert_eq(str(_encounters("ch_bath")[0]["trigger"]), "examine:h11_tub")
	assert_eq(str(_encounters("ch_jasper")[0]["trigger"]), "examine:h12_bed")
	for e: Dictionary in _loc().get("encounters", []):
		# The lurker (like the peacock) carries no level gate: a smaller party must still be able to win its keepsake (test_r12_paths).
		assert_true(str(e["id"]) == "ch_lurker" or str(e.get("when", "")).begins_with("level >= 3"), "%s waits for level 3" % e["id"])
	var jasper := _encounters("ch_jasper")[0]
	var w := jasper["withdraw"] as Dictionary
	assert_eq(str(w["who"]), "vermin_familiar_weasel")
	assert_eq(str(w["flag"]), "jasper_fled")
	assert_true(int(w["at_hp_below"]) == 16, "Jasper leaves at Bloodied (15 of 31)")
	assert_eq((jasper["monsters"] as Array).size(), 13, "Jasper and twelve weasels")
	assert_eq((_encounters("ch_bath")[0]["monsters"] as Array).size(), 7, "seven weasels in the bath")


func test_the_doll_speaks_first_and_is_there_from_the_start() -> void:
	var doll := _prop("h10_doll")
	assert_eq(str(doll.get("dialogue")), "crooked_house/sally_doll:start")
	assert_eq(str(doll.get("call")), "crooked_house/sally_doll:start")
	assert_true(int(doll.get("approach", 0)) > 0, "she calls out as the party comes in")
	assert_true(not doll.has("when"), "she is not waiting on the doll memento: the conversation is what starts her quest")
	var lurker := _encounters("ch_lurker")[0]
	assert_eq(str((lurker["quest"] as Dictionary)["id"]), "sallys_monsters")
	assert_eq(str((lurker["quest"] as Dictionary)["stage"]), "lurker_dead")


func test_the_crooked_mans_second_floor_visit_waits_for_the_bed_fight_or_the_floors_memento() -> void:
	var rope := _prop("h12_rope")
	assert_eq(str(rope.get("call")), "crooked_house/crooked_man:floor2")
	var when := str(rope["call_when"])
	var st := _fresh()
	assert_true(not StoryConditions.check(when, st), "not yet")
	st.set_flag("memento_doll")
	assert_true(StoryConditions.check(when, st), "after the floor's memento")
	st.set_flag("memento_doll", false)
	st.set_flag("jasper_slain")
	assert_true(StoryConditions.check(when, st), "or after the bed fight")
	st.set_flag("crooked_man_seen_2")
	assert_true(not StoryConditions.check(when, st), "once")
	for room_word: String in ["h9", "h10", "h11", "h12", "gallery", "parlor"]:
		assert_true(not when.contains(room_word), "never gated on a named room")
	GameState.reset()


func test_the_checks_hand_out_teeth_and_finds() -> void:
	for id: String in SPOTS:
		var checks := _prop(id)["checks"] as Array
		var c := checks[0] as Dictionary
		assert_eq(str(c["id"]), id)
		assert_eq(str(c["skill"]), "perception")
		assert_eq(int(c["dc"]), 15)
		assert_eq(str((((c["failure"] as Dictionary)["items"] as Array)[0] as Dictionary)["id"]), "human_tooth", "%s: a miss leaves a tooth" % id)
	var closet := _prop("h10_closet")["checks"] as Array
	assert_eq(str((closet[1] as Dictionary)["id"]), "the_bag")
	assert_eq(str((closet[1] as Dictionary)["skill"]), "investigation")
	assert_eq(int((closet[1] as Dictionary)["dc"]), 15)
	var bag := _prop("the_bag")
	assert_eq(str(bag["kind"]), "search")
	assert_eq(str(bag["item"]), "the_bag")
	assert_eq(str(bag["flag"]), "the_bag_taken")
	var gears := (_prop("h9_clock")["checks"] as Array)[0] as Dictionary
	assert_eq(int(gears["dc"]), 10)
	assert_eq(str(gears["skill"]), "sleight_of_hand")
	assert_eq(str((((gears["success"] as Dictionary)["items"] as Array)[0] as Dictionary)["id"]), "gold_pocket_watch")
	var journal := _prop("h12_journal")["checks"] as Array
	assert_eq(journal.size(), 2, "the clasp can be picked or broken")
	for c2: Dictionary in journal:
		assert_eq(int(c2["dc"]), 10)
		assert_eq(str(((c2["success"] as Dictionary)["codex"] as Dictionary)["id"]), "phillip_journal")


# --- The fights ----------------------------------------------------------------------------------------------------------------


func test_every_foe_exists_and_starts_on_floor_the_party_can_reach() -> void:
	var reach := _reach(_cell((_loc()["spawns"] as Dictionary)["default"] as Array))
	for e: Dictionary in _loc().get("encounters", []):
		var seen := {}
		for m: Dictionary in e["monsters"]:
			assert_true(not Compendium.shared().monster_data(str(m["monster"])).is_empty(), "%s: %s is a monster" % [e["id"], m["monster"]])
			var c := _cell(m["cell"] as Array)
			assert_true(_floor(c), "%s: %s starts on open floor, not cover or wall (%s)" % [e["id"], m["monster"], c])
			assert_true(reach.has(c), "%s: %s starts where the party can walk to (%s)" % [e["id"], m["monster"], c])
			assert_true(not seen.has(c), "%s: nobody else starts on %s" % [e["id"], c])
			seen[c] = true
		for ev: Dictionary in e.get("round_events", []):
			if str(ev.get("kind", "")) == "summon":
				assert_true(not Compendium.shared().monster_data(str(ev["monster"])).is_empty(), "%s: the summoned %s is a monster" % [e["id"], ev["monster"]])
				for xy: Array in ev.get("cells", []):
					assert_true(_floor(_cell(xy)) and reach.has(_cell(xy)), "%s: reinforcements arrive on open floor %s" % [e["id"], xy])


## Foes of three or more start so that no 20 ft burst (four squares either way) catches them all, and of eight or more no more than
## three quarters (owner, 2026-10-14; Curse of Strahd's test_fight_spread).
func test_foes_start_spread_out() -> void:
	for e: Dictionary in _loc().get("encounters", []):
		var cells: Array[Vector2i] = []
		for m: Dictionary in e["monsters"]:
			cells.append(_cell(m["cell"] as Array))
		if cells.size() < 3:
			continue
		var most := 0
		for x in range(0, 40):
			for y in range(0, 40):
				var n := 0
				for c in cells:
					if maxi(absi(c.x - x), absi(c.y - y)) <= 4:
						n += 1
				most = maxi(most, n)
		var limit := cells.size() - 1 if cells.size() < 8 else int(floor(cells.size() * 0.75))
		assert_true(most <= limit, "%s: a burst catches %d of %d foes (limit %d)" % [e["id"], most, cells.size(), limit])


func test_nobody_starts_beside_the_prop_that_starts_the_fight() -> void:
	# The party walks up to the prop first and stands round it: no foe may start in the ring of squares beside it.
	var rings := {"ch_clock": "h9_clock", "ch_bath": "h11_tub", "ch_jasper": "h12_bed"}
	for id: String in rings:
		var p := _prop(str(rings[id]))
		var at := _cell(p["cell"] as Array)
		var span := p.get("span", [1, 1]) as Array
		for m: Dictionary in _encounters(id)[0]["monsters"]:
			var c := _cell(m["cell"] as Array)
			var near := c.x >= at.x - 1 and c.x <= at.x + int(span[0]) and c.y >= at.y - 1 and c.y <= at.y + int(span[1])
			assert_true(not near, "%s: %s is not beside %s (%s)" % [id, m["monster"], p["id"], c])


func _field(foes: Array) -> Array:
	var e := TestCombat.encounter(_rows(), 3)
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(7, 24), 3)
	for f: Dictionary in foes:
		TestCombat.foe(e, str(f["monster"]), _cell(f["cell"] as Array))
	return [e, hero]


func _start(e: Encounter, hero: Combatant, events: Array) -> void:
	e.legendary.set_round_events(events)
	TestCombat.start_with(e, hero)
	e.legendary.round_events.done.clear()


func _event(events: Array, id: String) -> Dictionary:
	for ev: Dictionary in events:
		if str(ev["id"]) == id:
			return ev
	return {}


## Whether the event acts in round `round_no`, as RoundEvents does: from its first round, every `every` rounds, to its last, and no more than `times` in all.
func _acts_in(ev: Dictionary, round_no: int) -> bool:
	var first := int(ev.get("from_round", 1))
	var acted := 0
	for r in range(first, round_no + 1):
		if ev.has("until_round") and r > int(ev["until_round"]):
			return false
		if (r - first) % maxi(1, int(ev.get("every", 1))) != 0:
			continue
		if ev.has("times") and acted >= int(ev["times"]):
			return false
		if r == round_no:
			return true
		acted += 1
	return false


func test_the_clock_chimes_every_round_calls_help_every_fifth_and_frightens_on_the_twelfth() -> void:
	GameState.reset()
	var spec := _encounters("ch_clock")[0]
	var events := LocationFights.round_events_for(GameState.story, spec)
	var chime := _event(events, "chime")
	var brood := _event(events, "chime_brood")
	var twelfth := _event(events, "twelfth_chime")
	for ev: Dictionary in [chime, brood, twelfth]:
		assert_true(not ev.is_empty())
		assert_eq(int(ev.get("at", 20)), 20, "on initiative 20")
	for r in range(1, 16):
		assert_true(_acts_in(chime, r), "it chimes in round %d" % r)
		assert_eq(_acts_in(brood, r), r % 5 == 0, "a new swarm comes on the fifth chime only (round %d)" % r)
		assert_eq(_acts_in(twelfth, r), r == 12, "the twelfth chime frightens once, in round 12 (round %d)" % r)
	assert_eq(int(twelfth["times"]), 1, "and it happens once")
	# Run them: the summon adds a swarm, the twelfth chime frightens a hero who fails the save.
	var got := _field(spec["monsters"] as Array)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	_start(e, hero, events)
	var before := e.living().filter(func(c: Combatant) -> bool: return c.side == &"enemy").size()
	e.legendary.round_events.act(brood, false)
	var after := e.living().filter(func(c: Combatant) -> bool: return c.side == &"enemy").size()
	assert_eq(after, before + 1, "another boogleswarm joins")
	TestCombat.next_d20(e, 1)
	e.legendary.round_events.act(twelfth, false)
	assert_true(hero.creature.has_condition(&"frightened"), "a failed save leaves the hero Frightened")
	GameState.reset()


func test_the_bathroom_door_slams_the_blood_rises_and_then_fills_the_room() -> void:
	GameState.reset()
	var spec := _encounters("ch_bath")[0]
	var events := LocationFights.round_events_for(GameState.story, spec)
	var slam := _event(events, "door_slam")
	var rises := _event(events, "blood_rises")
	var fills := _event(events, "blood_fills")
	for r in range(1, 9):
		assert_eq(_acts_in(slam, r), r == 1, "the door slams in the first round only (round %d)" % r)
		assert_eq(_acts_in(rises, r), r in [2, 3], "the blood rises in rounds 2 and 3 (round %d)" % r)
		assert_eq(_acts_in(fills, r), r >= 4, "and fills the room from round 4 (round %d)" % r)
	assert_eq(str((fills["save"] as Dictionary)["ability"]), "con")
	assert_eq(int(fills["dc_step"]), 1, "the choking gets harder")
	assert_eq(int(fills["exhaustion"]), 1)
	var got := _field(spec["monsters"] as Array)
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	_start(e, hero, events)
	TestCombat.next_d20(e, 1)
	e.legendary.round_events.act(fills, false)
	assert_eq(hero.creature.exhaustion, 1, "a failed Constitution save is a level of Exhaustion")
	GameState.reset()


# --- The lurker's hiding place --------------------------------------------------------------------------------------------------


func test_the_lurkers_place_is_fixed_by_the_seed_and_covers_all_six_across_seeds() -> void:
	var st := _fresh()
	var seen := {}
	for seed_value in range(1, 121):
		st.playthrough_seed = seed_value
		var yes: Array[int] = []
		for n in range(1, 7):
			if StoryConditions.check("tarokka.lurker_spot.%d" % n, st):
				yes.append(n)
		assert_eq(yes.size(), 1, "seed %d has exactly one hiding place" % seed_value)
		assert_eq(yes[0], CrookedMoonCampaign.lurker_spot(seed_value), "and it is the module's pick")
		seen[yes[0]] = int(seen.get(yes[0], 0)) + 1
		# Stable: asking again, or from a fresh state with the same seed, gives the same place.
		for n in range(1, 7):
			assert_eq(StoryConditions.check("tarokka.lurker_spot.%d" % n, st), n == yes[0], "seed %d: asked twice" % seed_value)
		assert_eq(CrookedMoonCampaign.lurker_spot(seed_value), yes[0], "seed %d: a reload keeps it" % seed_value)
	for n in range(1, 7):
		assert_true(int(seen.get(n, 0)) > 0, "some seed hides it in place %d" % n)
	assert_true(not StoryConditions.check("tarokka.lurker_spot.7", st), "there is no seventh place")
	GameState.reset()


func _search(st: StoryState, id: String, success: bool) -> void:
	var check: Dictionary = {}
	for c: Dictionary in _prop(id)["checks"]:
		if str(c["id"]) == id:
			check = c
	var who := st.party[0]
	WorldChecks.record(st, PLACE, check, who, success)


## What `_trigger_encounter` would start for `trigger` (the first entry of the trigger whose condition holds), or {}.
func _fight_for(st: StoryState, trigger: String) -> Dictionary:
	for e: Dictionary in _loc().get("encounters", []):
		if str(e["trigger"]) != trigger:
			continue
		if StoryConditions.check(StoryConditions.encounter_when(e, str(_loc().get("region", ""))), st):
			return e
	return {}


func _party(st: StoryState) -> void:
	st.party.clear()
	st.party.append(TestChars.pregen("hedda_ironvow", 3))
	st.party.append(TestChars.pregen("ilse_varga", 3))


func test_finding_the_lurker_starts_its_fight_only_at_its_own_place() -> void:
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
		var st := _fresh()
		_party(st)
		st.playthrough_seed = seed_value
		var at := CrookedMoonCampaign.lurker_spot(seed_value)
		for i in SPOTS.size():
			var fight := _fight_for(st, "check:%s:success" % SPOTS[i])
			if i + 1 == at:
				assert_eq(str(fight.get("id", "")), "ch_lurker", "seed %d: it is found at %s" % [seed_value, SPOTS[i]])
				assert_eq(str(fight.get("surprise", "")), "", "found, nobody is surprised")
			else:
				assert_true(fight.is_empty(), "seed %d: nothing at %s" % [seed_value, SPOTS[i]])
			assert_true(_fight_for(st, "check:%s:failure" % SPOTS[i]).is_empty(), "a miss starts no fight until the six are searched")
	GameState.reset()


func test_after_six_searches_it_drops_from_the_ceiling_with_surprise_wherever_it_hid() -> void:
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var st := _fresh()
		_party(st)
		st.playthrough_seed = seed_value
		for i in SPOTS.size() - 1:
			_search(st, SPOTS[i], i % 2 == 0)
			assert_eq(CrookedMoonCampaign.lurker_places_searched(st), i + 1, "%d places searched" % (i + 1))
			assert_true(not StoryConditions.check("tarokka.lurker_hunt.searched", st))
		# The sixth, a miss or a hit, whichever place is last.
		for last_result: bool in [false, true]:
			var s2 := _fresh()
			_party(s2)
			s2.playthrough_seed = seed_value
			for i in SPOTS.size() - 1:
				_search(s2, SPOTS[i], false)
			_search(s2, SPOTS[5], last_result)
			assert_true(StoryConditions.check("tarokka.lurker_hunt.searched", s2), "all six are searched")
			var fight := _fight_for(s2, "check:%s:%s" % [SPOTS[5], "success" if last_result else "failure"])
			assert_eq(str(fight.get("id", "")), "ch_lurker", "seed %d: it drops from the ceiling" % seed_value)
			var at := CrookedMoonCampaign.lurker_spot(seed_value)
			if last_result and at == 6:
				assert_eq(str(fight.get("surprise", "")), "", "found at the sixth place: found, not an ambush")
			else:
				assert_eq(str(fight.get("surprise", "")), "party", "seed %d: it catches the party unawares" % seed_value)
	GameState.reset()


func test_the_lurker_fight_can_be_won_and_moves_sallys_quest() -> void:
	# Its foe exists and the stat block can end: a plain single foe on open floor, with the quest stage the doll's conversation reads.
	var st := _fresh()
	_party(st)
	var fights := _encounters("ch_lurker")
	assert_eq(fights.size(), 6 + 12, "six found versions and twelve ceiling versions")
	for f: Dictionary in fights:
		assert_eq((f["monsters"] as Array).size(), 1)
		assert_eq(str(((f["monsters"] as Array)[0] as Dictionary)["monster"]), "lurker_in_the_dark")
		assert_eq(str((f["quest"] as Dictionary)["stage"]), "lurker_dead")
	GameState.reset()
