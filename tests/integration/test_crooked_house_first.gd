extends TestCase
## R12, the first floor of the Crooked House, wired (data/locations/crooked_house_first.json): the people stand where the
## conversations expect them, every prop's talk names a real node, the fights have the contract's ids with foes that exist,
## stand on open floor, start spread out and can be walked to, and each round event loads through LocationFights and does what
## it says to a party that fails every save.

const PLACE := "crooked_house_first"
const SAVES: Array[String] = ["str", "dex", "con", "int", "wis", "cha"]
const FIGHTS: Array[String] = ["ch_peacock", "ch_dance", "ch_feast", "ch_petunia"]


func _loc() -> Dictionary:
	return HouseFloors.place(PLACE)


func _rows() -> Array:
	return (_loc()["map"] as Dictionary)["rows"] as Array


func _walkable(x: int, y: int) -> bool:
	var rows := _rows()
	return y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length() and ".~1234_".contains((rows[y] as String)[x])


func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


## The squares a party arriving at the porch can walk to (a shut door's square counts as floor: its lock is a skill check).
func _reach() -> Dictionary:
	var start := _cell((_loc()["spawns"] as Dictionary)["from_porch"] as Array)
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	var doors := {}
	for d: Dictionary in _loc().get("doors", []):
		doors[_cell(d["cell"] as Array)] = true
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + step
			if not seen.has(n) and (_walkable(n.x, n.y) or doors.has(n)):
				seen[n] = true
				todo.append(n)
	return seen


## Every square a prop (with its span), container, door, exit or spawn holds, by what holds it.
func _held() -> Dictionary:
	var held := {}
	for p: Dictionary in _loc().get("props", []):
		var c := _cell(p["cell"] as Array)
		var span := p.get("span", [1, 1]) as Array
		for i: int in int(span[0]):
			for j: int in int(span[1]):
				held[c + Vector2i(i, j)] = str(p["id"])
	for ct: Dictionary in _loc().get("containers", []):
		held[_cell(ct["cell"] as Array)] = str(ct["id"])
	for d: Dictionary in _loc().get("doors", []):
		held[_cell(d["cell"] as Array)] = str(d["id"])
	for e: Dictionary in _loc().get("exits", []):
		held[_cell(e["cell"] as Array)] = str(e["id"])
	for sp: Variant in (_loc()["spawns"] as Dictionary).values():
		held[_cell(sp as Array)] = "a spawn"
	return held


func _prop(id: String) -> Dictionary:
	for p: Dictionary in _loc().get("props", []):
		if str(p["id"]) == id:
			return p
	return {}


func _fights(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _loc().get("encounters", []):
		if str(e["id"]) == id:
			out.append(e)
	return out


func _state(flags: Dictionary) -> StoryState:
	GameState.reset()
	var st := GameState.story
	for k: String in flags:
		st.set_flag(k, flags[k])
	return st


## A dialogue ref ("crooked_house/petunia:start") names a file and a node that exist.
func _ref_is_real(ref: String) -> bool:
	var file := DialogueFile.load_key(ref.get_slice(":", 0))
	return file != null and file.nodes.has(ref.get_slice(":", 1))


func _size_of(monster: String) -> int:
	return CombatGrid.size_cells_for(StringName(str(Compendium.shared().monster_data(monster).get("size", "medium"))))


# --- The people -----------------------------------------------------------------------------------------------------------

func test_the_crooked_man_waits_on_the_porch_and_petunia_in_the_conservatory() -> void:
	var by := {}
	for n: Dictionary in _loc().get("npcs", []):
		by[str(n["npc"])] = n
	assert_true(by.has("crooked_man") and by.has("petunia_lockwood"), "both stand in the house")
	var man := by["crooked_man"] as Dictionary
	assert_eq(str(man["dialogue"]), "crooked_house/crooked_man:porch")
	assert_true(_ref_is_real(str(man["dialogue"])), "his porch node exists")
	assert_true(int(man.get("approach", 0)) >= 6, "he speaks first, as the party comes up the steps")
	var porch := _cell(man["cell"] as Array)
	assert_true(porch.y >= 35 and porch.y <= 39, "on the porch")
	assert_true(StoryConditions.check(str(man["when"]), _state({})), "he is there on arrival")
	assert_true(not StoryConditions.check(str(man["when"]), _state({"crooked_man_met": true})), "and gone once he has welcomed them")
	var pet := by["petunia_lockwood"] as Dictionary
	assert_eq(str(pet["dialogue"]), "crooked_house/petunia:start")
	assert_true(_ref_is_real(str(pet["dialogue"])))
	var hers := _cell(pet["cell"] as Array)
	assert_true(hers.x >= 6 and hers.x <= 18 and hers.y >= 2 and hers.y <= 12, "in the conservatory")
	assert_true(StoryConditions.check(str(pet["when"]), _state({})), "she sits there until...")
	assert_true(not StoryConditions.check(str(pet["when"]), _state({"petunia_at_peace": true})), "she is at peace")
	assert_true(not StoryConditions.check(str(pet["when"]), _state({"petunia_destroyed": true})), "or she is destroyed")
	var held := _held()
	for id: String in by:
		var c := _cell((by[id] as Dictionary)["cell"] as Array)
		assert_true(not held.has(c), "%s stands on %s" % [id, held.get(c, "")])
		assert_true(_reach().has(c), "%s can be walked up to" % id)
	GameState.reset()


func test_every_conversation_a_prop_starts_or_calls_names_a_real_node() -> void:
	var wanted := {"h2_portrait_lockwood": "crooked_house/portraits:lockwood", "h2_portrait_druskenvald": "crooked_house/portraits:druskenvald",
		"h2_portrait_party": "crooked_house/portraits:party", "h3_spirit_board": "crooked_house/seance:start",
		"h4_paintings": "crooked_house/keziah:paintings", "h5_harpsichord": "crooked_house/patrini_lament:harpsichord",
		"h8_cup": "crooked_house/petunia:cup"}
	for id: String in wanted:
		assert_eq(str(_prop(id).get("dialogue", "")), wanted[id], "%s starts its talk" % id)
	# The incitements' objects start their scenes on a click (Ashwin, 2026-11-03: in the house only the key beats start by themselves).
	var looks := {"h3_crystal_ball": "crooked_house/incitements:pilgrimage_enter", "h8_bergamot": "crooked_house/incitements:rejuvenation_enter",
		"h5_mirror": "crooked_house/incitements:duality_enter", "h4_bust": "crooked_house/incitements:rapture_enter"}
	for id: String in looks:
		assert_eq(str(_prop(id).get("dialogue", "")), looks[id], "%s starts its scene on a click" % id)
		assert_eq(int(_prop(id).get("approach", 0)), 0, "%s starts nothing on walking past" % id)
	var calls := {"h4_peacock_rubble": "crooked_house/keziah:peacock_fall", "h_d02": "crooked_house/crooked_man:floor1",
		"h8_cup": "crooked_house/petunia:cup"}
	for id: String in calls:
		var p := _prop(id)
		assert_eq(str(p.get("call", "")), calls[id], "%s calls its node" % id)
		assert_true(int(p.get("approach", 0)) > 0, "%s speaks as the party comes near" % id)
		assert_true(str(p.get("call_when", "")) != "", "%s says when" % id)
	for p: Dictionary in _loc().get("props", []):
		for key: String in ["dialogue", "call"]:
			if p.has(key):
				assert_true(_ref_is_real(str(p[key])), "%s's %s %s is a real node" % [p["id"], key, p[key]])
	var hall := _cell(_prop("h_d02")["cell"] as Array)
	assert_true(hall.x in [20, 21] and hall.y >= 13 and hall.y <= 33, "the apparition's call hangs in the long hall")


## Each incitement's `_enter` node holds its own gate now that a click starts it: a companion's beat plays while only pending (the home scene on a
## later look), and once played (or for anyone else) the look is the object's plain Narrator line.
func test_the_incitements_stay_armed_until_their_own_flag_is_set() -> void:
	var file := DialogueFile.load_key("crooked_house/incitements")
	assert_true(file != null, "the incitements file reads")
	if file == null:
		return
	var text := FileAccess.get_file_as_string("res://narrative/crooked_house/incitements.dialogue")
	for pair: Array in [["pilgrimage", "h3_crystal_ball"], ["rejuvenation", "h8_bergamot"], ["slaughter", "h15_trophy_crow"], ["rapture", "h4_bust"],
			["duality", "h5_mirror"], ["immortality", "h17_cauldron"], ["kindred", "h12_scratchings"], ["malediction", "h14_tome"]]:
		var node := "%s_enter" % pair[0]
		assert_true(file.nodes.has(node), "%s is there" % node)
		var body := text.substr(text.find("~ " + node), 400)
		assert_true(body.contains("if flag.incitement_%s" % pair[0]), "%s: played once" % node)
		assert_true(body.contains("narrate examine:%s" % pair[1]), "%s: otherwise the plain look" % node)
		assert_true(not body.contains("pending_%s_incitement\n-> END" % pair[0]), "%s: pending alone does not shut it" % node)
	GameState.reset()


func test_the_first_floor_apparition_follows_the_seance_or_the_second_of_three_mementos() -> void:
	var when := str(_prop("h_d02")["call_when"])
	assert_true(not StoryConditions.check(when, _state({})), "not at the start")
	assert_true(StoryConditions.check(when, _state({"seance_done": true})), "after the seance")
	for pair: Array in [["memento_gem", "memento_key"], ["memento_gem", "memento_cup"], ["memento_key", "memento_cup"]]:
		assert_true(StoryConditions.check(when, _state({pair[0]: true, pair[1]: true})), "any two of the three: %s and %s" % pair)
	for one: String in ["memento_gem", "memento_key", "memento_cup"]:
		assert_true(not StoryConditions.check(when, _state({one: true})), "one memento (%s) is not enough on its own" % one)
	assert_true(not StoryConditions.check(when, _state({"seance_done": true, "crooked_man_seen_1": true})), "once, and no more")
	for other: String in ["memento_doll", "memento_bear", "memento_pin"]:
		assert_true(not StoryConditions.check(when, _state({other: true})), "a memento from another floor does nothing")
	GameState.reset()


# --- The props that give things -------------------------------------------------------------------------------------------

func test_the_dining_rooms_find_pays_the_pearl_and_the_ring_and_a_miss_turns_up_a_tooth() -> void:
	var p := _prop("h6_table_loot")
	var checks := p.get("checks", []) as Array
	assert_eq(checks.size(), 1)
	var c := checks[0] as Dictionary
	assert_eq(str(c["skill"]), "perception")
	assert_eq(int(c["dc"]), 10)
	assert_eq(str(c["id"]), "h6_table_loot", "its id is the one the Narrator's miss line is keyed on")
	var got: Array[String] = []
	for it: Dictionary in (c["success"] as Dictionary)["items"]:
		got.append(str(it["id"]))
	assert_eq(got, ["pearl_of_power", "gold_ring_75"] as Array[String])
	assert_eq(str((((c["failure"] as Dictionary)["items"] as Array)[0] as Dictionary)["id"]), "human_tooth")
	for id: String in got + ["human_tooth"] as Array[String]:
		assert_true(not Compendium.shared().item_data(id).is_empty(), "%s is an item" % id)


func test_the_oven_holds_ruined_kitchenware_and_the_glyph_can_be_read_with_arcana() -> void:
	var oven: Dictionary = {}
	for ct: Dictionary in _loc().get("containers", []):
		if str(ct["id"]) == "h7_oven_contents":
			oven = ct
	assert_true(not (oven.get("items", []) as Array).is_empty(), "something is in it, and none of it is worth much")
	var check := (oven["checks"] as Array)[0] as Dictionary
	assert_eq(str(check["skill"]), "arcana")
	assert_eq(int(check["dc"]), 15)
	var traps := {}
	for t: Dictionary in _loc().get("traps", []):
		traps[str(t["id"])] = true
	for id: Variant in (check["success"] as Dictionary)["disarm"]:
		assert_true(traps.has(str(id)), "the glyph disarms %s" % id)
	assert_true(traps.has("h7_oven_trap") and traps.has("h7_oven_trap_acid"), "both halves of the trap")


func test_each_portrait_has_its_psychic_gaze_on_the_square_before_it() -> void:
	var gazes := 0
	for t: Dictionary in _loc().get("traps", []):
		if not str(t["id"]).begins_with("h2_gaze_"):
			continue
		gazes += 1
		assert_eq(str(t["damage_type"]), "psychic")
		assert_eq(str(t["damage"]), "1d6")
		assert_eq(str((t["save"] as Dictionary)["ability"]), "cha")
		assert_eq(int((t["save"] as Dictionary)["dc"]), 10)
		var c := _cell((t["cells"] as Array)[0] as Array)
		assert_true(_prop("h2_portrait_" + str(t["id"]).trim_prefix("h2_gaze_")).has("cell"), "%s has its portrait" % t["id"])
		assert_eq(c.x, _cell(_prop("h2_portrait_" + str(t["id"]).trim_prefix("h2_gaze_"))["cell"] as Array).x, "%s stands before it" % t["id"])
		assert_true(_reach().has(c), "%s can be stepped on" % t["id"])
	assert_eq(gazes, 3, "three portraits")


func test_the_peacocks_gravel_waits_where_the_bird_stood_and_the_bird_goes_with_the_gem() -> void:
	var bird := _prop("h4_peacock")
	var gravel := _prop("h4_peacock_rubble")
	assert_true(StoryConditions.check(str(bird["when"]), _state({})), "the bird stands until..")
	assert_true(not StoryConditions.check(str(bird["when"]), _state({"memento_gem": true})), "..the gem is won")
	assert_true(not StoryConditions.check(str(gravel["when"]), _state({})), "no gravel before")
	assert_true(StoryConditions.check(str(gravel["when"]), _state({"memento_gem": true})), "gravel after")
	var d := (_cell(bird["cell"] as Array) - _cell(gravel["cell"] as Array)).abs()
	assert_true(maxi(d.x, d.y) == 1, "the gravel lies beside the plinth")
	GameState.reset()


# --- The fights -----------------------------------------------------------------------------------------------------------

func test_the_contracts_fights_are_all_here_with_their_triggers_and_the_level_gate() -> void:
	var triggers := {"ch_peacock": "examine:h4_peacock", "ch_dance": "enter_area:h5_floor", "ch_feast": "examine:h6_table", "ch_petunia": "dialogue"}
	var props := {}
	var areas := {}
	for p: Dictionary in _loc().get("props", []):
		props[str(p["id"])] = true
	for a: Dictionary in _loc().get("areas", []):
		areas[str(a["id"])] = true
	for id: String in FIGHTS:
		var versions := _fights(id)
		assert_true(not versions.is_empty(), "%s is an encounter" % id)
		for spec: Dictionary in versions:
			assert_eq(str(spec["trigger"]), triggers[id], "%s's trigger" % id)
			# The peacock carries no level gate: a smaller party must still be able to win its keepsake (test_r12_paths).
			assert_true(id == "ch_peacock" or str(spec["when"]).begins_with("level >= 3"), "%s waits for level 3" % id)
			var trig := str(spec["trigger"])
			if trig.begins_with("examine:"):
				assert_true(props.has(trig.get_slice(":", 1)), "%s: its prop is here" % id)
			if trig.begins_with("enter_area:"):
				assert_true(areas.has(trig.get_slice(":", 1)), "%s: its area is here" % id)
			for m: Dictionary in spec["monsters"]:
				assert_true(not Compendium.shared().monster_data(str(m["monster"])).is_empty(), "%s: %s is a monster" % [id, m["monster"]])
	assert_eq((_fights("ch_dance")[0]["monsters"] as Array).size(), 7, "seven weasels")
	var feast: Array[String] = []
	for m: Dictionary in _fights("ch_feast")[0]["monsters"]:
		feast.append(str(m["monster"]))
	assert_eq(feast, ["ochre_jelly", "rug_of_smothering"] as Array[String])


func test_the_peacock_pays_the_bloodstone_and_sets_the_gem_flag_and_the_quest_moves_only_from_trapped() -> void:
	var versions := _fights("ch_peacock")
	assert_eq(versions.size(), 2, "one version moves the quest, one leaves it")
	var moving := versions[0]
	var plain := versions[1]
	for spec: Dictionary in versions:
		assert_eq(str(spec["flag"]), "memento_gem")
		assert_true(not spec.has("loot"), "the stone is not the fight's loot: it lies in a container that shows once the gem is won")
	var stone := {}
	for c: Dictionary in _loc().get("containers", []):
		if str(c["id"]) == "h4_peacock_stone":
			stone = c
	assert_eq(str((((stone["items"] as Array)[0]) as Dictionary)["id"]), "memento_bloodstone", "the bloodstone")
	assert_eq(str(stone["when"]), "flag.memento_gem and not flag.memento_gem_placed", "shown once the gem is won, until it is set in the runes")
	assert_eq(str((moving["quest"] as Dictionary)["stage"]), "mementos")
	assert_true(not plain.has("quest"), "later, with the quest past 'trapped', it never moves it back")
	var st := _state({})
	st.set_quest_stage("the_crooked_house", "trapped")
	st.party.append(Pregens.build("hedda_ironvow", 3))
	assert_true(StoryConditions.check(str(moving["when"]), st), "from trapped the first version holds")
	st.set_quest_stage("the_crooked_house", "attic")
	assert_true(not StoryConditions.check(str(moving["when"]), st), "from attic it does not")
	assert_true(StoryConditions.check(str(plain.get("when", "")), st), "the plain one does (it has no gate at all)")
	GameState.reset()


func test_petunias_fight_sets_only_her_own_flag() -> void:
	var spec := _fights("ch_petunia")[0]
	assert_eq(str(spec["flag"]), "petunia_destroyed")
	assert_true(not spec.has("quest"), "the cup's talk moves her quest when it hands the cup over")
	assert_eq((spec["monsters"] as Array).size(), 1)
	var at := _cell(((spec["monsters"] as Array)[0] as Dictionary)["cell"] as Array)
	assert_true(_walkable(at.x, at.y) and at.y <= 12, "she fights in the conservatory")


func test_every_foe_stands_on_open_floor_clear_of_props_and_each_other_and_can_be_reached() -> void:
	var held := _held()
	var reach := _reach()
	var rows := _rows()
	for id: String in FIGHTS:
		for spec: Dictionary in _fights(id):
			var taken := {}
			for m: Dictionary in spec["monsters"]:
				var c := _cell(m["cell"] as Array)
				var size := _size_of(str(m["monster"]))
				for i in size:
					for j in size:
						var at := c + Vector2i(i, j)
						assert_true(_walkable(at.x, at.y) and (rows[at.y] as String)[at.x] != "=", "%s: %s at %s is on open floor" % [id, m["monster"], at])
						assert_true(reach.has(at), "%s: %s at %s can be reached" % [id, m["monster"], at])
						assert_true(not taken.has(at), "%s: %s overlaps another foe at %s" % [id, m["monster"], at])
						taken[at] = true
						if str(m["monster"]) != "marble_peacock":   # (the statue's own square: the bird is the plinth's figure)
							assert_true(not held.has(at), "%s: %s at %s stands on %s" % [id, m["monster"], at, held.get(at, "")])


func test_foes_start_spread_out_so_no_twenty_foot_burst_catches_a_crowd() -> void:
	for id: String in FIGHTS:
		for spec: Dictionary in _fights(id):
			var foes := (spec["monsters"] as Array).size()
			if foes < 3:
				continue
			var lo := Vector2i(1000, 1000)
			var hi := Vector2i(-1000, -1000)
			for m: Dictionary in spec["monsters"]:
				var c := _cell(m["cell"] as Array)
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
			# A burst reaches 20 ft (four squares) each way from its centre: nine squares across.
			assert_true(hi.x - lo.x > 8 or hi.y - lo.y > 8, "%s: no 20 ft burst reaches all %d foes (they span %d by %d)" % [id, foes, hi.x - lo.x + 1, hi.y - lo.y + 1])
	# and the weasels really use the whole width of the room
	var xs: Array[int] = []
	for m: Dictionary in _fights("ch_dance")[0]["monsters"]:
		xs.append(_cell(m["cell"] as Array).x)
	assert_true(xs.min() <= 23 and xs.max() >= 32, "from the door side to the far wall")


# --- Round events ---------------------------------------------------------------------------------------------------------

## The outcomes an event can have: itself, or each entry of its table.
func _outcomes(ev: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if (ev.get("table", []) as Array).is_empty():
		out.append(ev)
	else:
		for t: Dictionary in ev["table"]:
			out.append(t)
	return out


func test_round_events_load_through_location_fights_and_are_well_formed() -> void:
	var st := _state({})
	var seen := 0
	for id: String in ["ch_peacock", "ch_dance", "ch_feast"]:
		for spec: Dictionary in _fights(id):
			var events := LocationFights.round_events_for(st, spec)
			assert_true(not events.is_empty(), "%s has round events" % id)
			var ids := {}
			for ev: Dictionary in events:
				assert_true(not ids.has(str(ev["id"])), "%s: event id %s is used once" % [id, ev["id"]])
				ids[str(ev["id"])] = true
				assert_eq(int(ev.get("at", 20)), 20, "%s: %s acts on initiative 20" % [id, ev["id"]])
				assert_true(str(ev.get("name", "")) != "", "%s: %s is named for the log" % [id, ev["id"]])
				var entries := _outcomes(ev)
				var entry_ids := {}
				for o: Dictionary in entries:
					seen += 1
					assert_true(str(o.get("summary", ev.get("summary", ""))) != "", "%s: %s says what it does" % [id, o.get("id", ev["id"])])
					assert_true(not entry_ids.has(str(o["id"])), "%s: %s repeats an outcome" % [id, ev["id"]])
					entry_ids[str(o["id"])] = true
					var kind := str(o.get("kind", "save" if o.has("save") else "text"))
					assert_true(kind in ["save", "summon", "text"], "%s: %s kind %s" % [id, o["id"], kind])
					assert_true(str(o.get("affects", "party")) in ["party", "enemies", "all"])
					if kind == "save":
						var sv := o["save"] as Dictionary
						assert_true(str(sv["ability"]) in SAVES, "%s: %s a real save" % [id, o["id"]])
						assert_true(int(sv["dc"]) > 0, "%s: %s has a DC" % [id, o["id"]])
						assert_true(o.has("damage") or o.has("condition") or o.has("exhaustion"), "%s: %s does something on a failure" % [id, o["id"]])
						if o.has("condition"):
							assert_true(not Compendium.shared().get_entry("conditions", str(o["condition"])).is_empty(), "%s: %s is a condition" % [id, o["condition"]])
							assert_true(str(o.get("until", "target_turn_end")) in ["target_turn_end", "minute", "permanent"])
						if o.has("damage"):
							assert_true(str((o["damage"] as Dictionary)["dice"]).contains("d"), "%s: %s rolls dice" % [id, o["id"]])
					if o.has("area"):
						var rect := (o["area"] as Dictionary).get("rect", []) as Array
						assert_eq(rect.size(), 4, "%s: %s area is a rectangle" % [id, o["id"]])
						assert_true(int(rect[0]) <= int(rect[2]) and int(rect[1]) <= int(rect[3]))
						var floor_in_it := false
						for x in range(int(rect[0]), int(rect[2]) + 1):
							for y in range(int(rect[1]), int(rect[3]) + 1):
								floor_in_it = floor_in_it or _walkable(x, y)
						assert_true(floor_in_it, "%s: %s area is on the map" % [id, o["id"]])
	assert_true(seen >= 11, "the events were read (%d outcomes)" % seen)


func test_keziahs_shade_cycles_five_lines_in_the_order_the_conversation_gives_them() -> void:
	var file := DialogueFile.load_key("crooked_house/keziah")
	assert_true(file != null, "her conversation loads")
	var spoken: Array[String] = []
	for stmt: Dictionary in file.nodes["peacock_round"]:
		if str(stmt.get("t", "")) == "line":
			spoken.append(str(stmt.get("text", "")))
	assert_eq(spoken.size(), 5, "five lines")
	for spec: Dictionary in _fights("ch_peacock"):
		var voice: Dictionary = {}
		var pull: Dictionary = {}
		for ev: Dictionary in spec["round_events"]:
			if str(ev["id"]) == "keziah_voice":
				voice = ev
			if str(ev["id"]) == "keziah_pull":
				pull = ev
		assert_eq(str(voice["pick"]), "cycle", "in turn")
		var table := voice["table"] as Array
		assert_eq(table.size(), 5)
		for i in 5:
			assert_eq(str((table[i] as Dictionary)["text"]), spoken[i], "line %d is Keziah's, word for word" % (i + 1))
		assert_eq(str((pull["save"] as Dictionary)["ability"]), "cha")
		assert_eq(int((pull["save"] as Dictionary)["dc"]), 10)
		assert_eq(str(pull["condition"]), "incapacitated")
		assert_eq(str(pull["until"]), "target_turn_end", "until the end of their next turn")


func test_the_dance_ends_by_itself_after_ten_rounds_and_wears_the_party_down_every_third() -> void:
	var events := LocationFights.round_events_for(_state({}), _fights("ch_dance")[0])
	var music: Dictionary = {}
	var wears: Dictionary = {}
	for ev: Dictionary in events:
		if str(ev["id"]) == "dance_music":
			music = ev
		if str(ev["id"]) == "dance_wears":
			wears = ev
	assert_eq(int(music["until_round"]), 10, "the tune gives out after ten rounds")
	assert_eq(str((music["save"] as Dictionary)["ability"]), "wis")
	assert_eq(int((music["save"] as Dictionary)["dc"]), 10)
	assert_eq(str((music["damage"] as Dictionary)["type"]), "psychic")
	assert_eq(int(wears["every"]), 3, "Exhaustion on every third turn")
	assert_eq(int(wears["exhaustion"]), 1)
	GameState.reset()


## A fight with two heroes and one foe, everyone out of the way of the event's own area, and the first turn begun.
func _fight() -> Array:
	var e := TestCombat.open_field(3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 3), 5)
	var other := TestCombat.hero(e, "ilse_varga", Vector2i(3, 5), 5)
	var foe := TestCombat.foe(e, "ghost", Vector2i(9, 3))
	TestCombat.start_with(e, hero)
	return [e, hero, other, foe]


func test_every_round_event_does_what_it_says_to_a_party_that_fails_every_save() -> void:
	var acted := 0
	for id: String in ["ch_peacock", "ch_dance", "ch_feast"]:
		var spec := _fights(id)[0]
		for ev: Dictionary in LocationFights.round_events_for(_state({}), spec):
			for o: Dictionary in _outcomes(ev):
				var one := o.duplicate(true)
				one.erase("area")
				one["at"] = 20
				if one.has("save"):
					(one["save"] as Dictionary)["dc"] = 40
				var got := _fight()
				var e := got[0] as Encounter
				var hero := got[1] as Combatant
				var other := got[2] as Combatant
				var foe := got[3] as Combatant
				var hp_before := hero.creature.hp
				e.legendary.round_events.act(one, false)
				acted += 1
				assert_true(e.events.any(func(x: Variant) -> bool: return str((x as Dictionary).get("type", "")) == "round_event"), "%s: %s is heard" % [id, one["id"]])
				assert_true(foe.creature.hp == foe.creature.max_hp(), "%s: %s reaches the party only" % [id, one["id"]])
				if str(one.get("kind", "save" if one.has("save") else "text")) != "save":
					assert_eq(hero.creature.hp, hp_before, "%s: %s is only words" % [id, one["id"]])
					continue
				for who: Combatant in [hero, other]:
					if one.has("condition"):
						assert_true(who.creature.has_condition(StringName(str(one["condition"]))), "%s: %s leaves %s %s" % [id, one["id"], who.name(), one["condition"]])
					if one.has("exhaustion"):
						assert_eq(who.creature.exhaustion, int(one["exhaustion"]), "%s: %s tires %s" % [id, one["id"], who.name()])
				if one.has("damage"):
					assert_true(hero.creature.hp < hp_before, "%s: %s hurts" % [id, one["id"]])
	assert_true(acted >= 11, "every outcome was acted (%d)" % acted)


func test_a_party_that_passes_its_saves_is_left_alone() -> void:
	var spec := _fights("ch_dance")[0]
	for ev: Dictionary in LocationFights.round_events_for(_state({}), spec):
		var one := ev.duplicate(true)
		one.erase("area")
		(one["save"] as Dictionary)["dc"] = -10
		var got := _fight()
		var e := got[0] as Encounter
		var hero := got[1] as Combatant
		var hp_before := hero.creature.hp
		e.legendary.round_events.act(one, false)
		assert_eq(hero.creature.hp, hp_before, "%s: a save that cannot fail is passed" % one["id"])
		assert_eq(hero.creature.exhaustion, 0)
		assert_false(hero.creature.has_condition(&"charmed"))
