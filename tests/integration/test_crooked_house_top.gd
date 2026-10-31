extends TestCase
## R12, the Crooked House's top two floors are wired (crooked_house_third and crooked_house_attic). The ids the package names are there;
## every conversation a prop or person starts has its node, every person and foe is a real one on open floor that can be walked to; the
## foes start spread out and each fight has its last, plain version; the roar, Arthur's wail and Wisp's catch run as round events in a
## real encounter; and the floors play through: the toys and the bear, Arthur, Wisp's tales and his fight, the trapdoor and the roar,
## Gail, the runes, the three versions of Vessla's fight, her last word and the restored manor.

const GAME := preload("res://world/game_root.gd")
const THIRD := "crooked_house_third"
const ATTIC := "crooked_house_attic"
const FIGHTS := {"ch_quasits": THIRD, "ch_roar": THIRD, "ch_wisp": THIRD, "ch_vessla": ATTIC}

## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out

var st: StoryState
var dice: DiceRoller = HighDice.new()
var won: Array[String] = []


func before_each() -> void:
	_fresh(THIRD)


func after_each() -> void:
	GameState.reset()


## A new story with four level 3 heroes at `place`, the dice high.
func _fresh(place: String, level: int = 3) -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = place
	st.visited[place] = true
	st.playthrough_seed = 1
	won.clear()
	dice = HighDice.new()


func _loc(id: String = "") -> Dictionary:
	return Compendium.shared().get_entry("locations", id if id != "" else st.location)


func _rows(id: String) -> Array:
	return (_loc(id)["map"] as Dictionary)["rows"] as Array


func _cell(a: Variant) -> Vector2i:
	var arr := a as Array
	return Vector2i(int(arr[0]), int(arr[1]))


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


func _entry(list_key: String, id_key: String, id: String, place: String = "") -> Dictionary:
	for e: Variant in _loc(place).get(list_key, []):
		if str((e as Dictionary).get(id_key, "")) == id:
			return e as Dictionary
	return {}


func _versions(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in _loc(str(FIGHTS[id])).get("encounters", []):
		if str((e as Dictionary)["id"]) == id:
			out.append(e as Dictionary)
	return out


## The version of fight `id` the game starts now: LocationFights.spec_for's pick, the first whose `when` holds, else the last.
func _spec(id: String) -> Dictionary:
	var spec := {}
	for e: Dictionary in _versions(id):
		if spec.is_empty() or not _holds(StoryConditions.encounter_when(spec)):
			spec = e
	return spec


func _walkable(rows: Array, x: int, y: int) -> bool:
	return y >= 0 and y < rows.size() and x >= 0 and x < (rows[y] as String).length() and ".~1234_=".contains((rows[y] as String)[x])


func _floor(rows: Array, c: Vector2i) -> bool:
	return c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < (rows[c.y] as String).length() and (rows[c.y] as String)[c.x] == "."


func _reach(rows: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n) and _walkable(rows, n.x, n.y):
				seen[n] = true
				todo.append(n)
	return seen


## The radius, in squares, of the smallest circle round the squares' centres (brute force over pairs and triples: a few points).
func _enclosing_radius(pts: Array[Vector2]) -> float:
	var best := INF
	var n := pts.size()
	var circles: Array = []
	for i in n:
		for j in range(i + 1, n):
			circles.append([(pts[i] + pts[j]) / 2.0, pts[i].distance_to(pts[j]) / 2.0])
			for k in range(j + 1, n):
				var a := pts[i]
				var b := pts[j]
				var c := pts[k]
				var d := 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
				if absf(d) < 0.0001:
					continue
				var ux := ((a.length_squared()) * (b.y - c.y) + b.length_squared() * (c.y - a.y) + c.length_squared() * (a.y - b.y)) / d
				var uy := ((a.length_squared()) * (c.x - b.x) + b.length_squared() * (a.x - c.x) + c.length_squared() * (b.x - a.x)) / d
				var centre := Vector2(ux, uy)
				circles.append([centre, centre.distance_to(a)])
	for cc: Variant in circles:
		var centre: Vector2 = (cc as Array)[0]
		var r: float = (cc as Array)[1]
		var ok := true
		for p in pts:
			if p.distance_to(centre) > r + 0.0001:
				ok = false
		if ok:
			best = minf(best, r)
	return best


# --- The ids the package names ------------------------------------------------------------------------------------------------------

func test_the_floors_hold_what_the_package_names() -> void:
	for id: String in FIGHTS:
		assert_true(not _versions(id).is_empty(), "%s is an encounter of %s" % [id, FIGHTS[id]])
		for e: Dictionary in _versions(id):
			assert_true(e.has("round_events") or id in ["ch_wisp", "ch_vessla"], "%s has its round events" % id)
	assert_eq(str(_versions("ch_quasits")[0]["trigger"]), "examine:h13_crib", "the crib starts the toys")
	assert_eq(str(_versions("ch_roar")[0]["trigger"]), "examine:h15_trapdoor", "touching the ring starts the roar")
	assert_eq(str(_versions("ch_wisp")[0]["trigger"]), "dialogue", "Wisp fights only when his talk says so")
	assert_eq(str(_versions("ch_vessla")[0]["trigger"]), "dialogue", "so does the hag, from her pre-fight talk")
	for pid: String in ["h13_crib", "h13_apparition", "h14_cart", "h14_tome", "h14_desk", "h15_trapdoor", "h15_bear", "h15_trophy_crow"]:
		assert_true(not _entry("props", "id", pid, THIRD).is_empty(), "%s is a prop of the third floor" % pid)
	for pid: String in ["h16_sockets", "h16_runes", "h17_cauldron", "h17_phillip", "h17_adela", "h17_scratchings"]:
		assert_true(not _entry("props", "id", pid, ATTIC).is_empty(), "%s is a prop of the attic" % pid)
	assert_true(not _entry("containers", "id", "h14_cart_stock", THIRD).is_empty(), "the liquor cart's bottles")
	assert_true(not _entry("containers", "id", "h13_crib_bear", THIRD).is_empty(), "the bear waits in the crib")
	for npc: String in ["arthur_lockwood", "wisp"]:
		assert_true(not _entry("npcs", "npc", npc, THIRD).is_empty(), "%s is on the third floor" % npc)
	for npc: String in ["adela_druskenvald_ruse", "phillip_druskenvald", "adela_druskenvald"]:
		assert_true(not _entry("npcs", "npc", npc, ATTIC).is_empty(), "%s is in the attic" % npc)
	var disguise := Compendium.shared().get_entry("npcs", "adela_druskenvald_ruse")
	assert_eq(str(disguise.get("monster")), "weasel_hag", "the Adela who is not Adela is the hag")


func test_every_conversation_has_its_node_and_every_person_exists() -> void:
	for place: String in [THIRD, ATTIC]:
		var refs: Array[String] = []
		for n: Dictionary in _loc(place).get("npcs", []):
			assert_true(not Compendium.shared().get_entry("npcs", str(n["npc"])).is_empty(), "%s is an npc" % n["npc"])
			refs.append(str(n.get("dialogue", "")))
			assert_true(str(n.get("dialogue", "")) != "", "%s has something to say (talking to them does nothing without it)" % n["npc"])
		for p: Dictionary in _loc(place).get("props", []):
			for k: String in ["dialogue", "call"]:
				if p.has(k):
					refs.append(str(p[k]))
		for ref in refs:
			var key := ref.substr(0, ref.rfind(":"))
			var node := ref.substr(ref.rfind(":") + 1)
			var file := DialogueFile.load_key(key)
			assert_true(file != null, "%s is a dialogue file" % key)
			if file != null:
				assert_true(file.errors.is_empty(), "%s parses clean" % key)
				assert_true(file.nodes.has(node), "%s has node %s" % [key, node])
	# The fights the talks start are the encounters the floors define.
	for key: String in ["crooked_house/wisp", "crooked_house/vessla"]:
		var file := DialogueFile.load_key(key)
		for id: String in file.nodes:
			for s: Dictionary in file.nodes[id]:
				if str(s.get("t")) == "combat":
					assert_true(FIGHTS.has(str(s["encounter"])), "%s:%s starts %s, which these floors define" % [key, id, s["encounter"]])


func test_every_fight_names_real_foes_a_real_quest_stage_and_a_last_plain_version() -> void:
	for id: String in FIGHTS:
		var versions := _versions(id)
		assert_true(str(versions[versions.size() - 1].get("when", "")) == "" or id == "ch_wisp", "%s: its last version has no `when` (the fallback)" % id)
		for e: Dictionary in versions:
			assert_true(not (e["monsters"] as Array).is_empty(), "%s has foes" % id)
			for m: Dictionary in e["monsters"]:
				assert_true(not Compendium.shared().monster_data(str(m["monster"])).is_empty(), "%s: %s is a monster" % [id, m["monster"]])
				if m.has("steps_down"):
					var npc := str((m["steps_down"] as Dictionary)["npc"])
					assert_true(not _entry("npcs", "npc", npc, str(FIGHTS[id])).is_empty(), "%s: %s is a person of the place who steps down" % [id, npc])
			if e.has("quest"):
				var q := e["quest"] as Dictionary
				var quest := Compendium.shared().get_entry("quests", str(q["id"]))
				assert_true(not quest.is_empty(), "%s moves a real quest" % id)
				var stages: Array[String] = []
				for s: Dictionary in quest.get("stages", []):
					stages.append(str(s["id"]))
				assert_true(stages.has(str(q["stage"])), "%s: %s has the stage %s" % [id, q["id"], q["stage"]])
	assert_eq((_versions("ch_vessla")).size(), 6, "three versions of the boss, each with and without Jasper")
	assert_eq(str(_spec("ch_wisp")["when"]), "level >= 3", "Wisp's fight is level-gated like the rest")


func test_the_level_gate_and_the_lighter_version_for_a_smaller_party() -> void:
	for id: String in ["ch_quasits", "ch_roar"]:
		var full := _spec(id)
		assert_true(str(full["when"]).contains("level >= 3"), "%s waits for level 3" % id)
		_fresh(THIRD, 2)
		var light := _spec(id)
		assert_true((light["monsters"] as Array).size() < (full["monsters"] as Array).size(), "%s: a level 2 party meets fewer foes" % id)
		assert_eq(str(light.get("when", "")), "", "and it is the plain fallback")
		_fresh(THIRD)


# --- Cells ---------------------------------------------------------------------------------------------------------------------------

func test_people_and_foes_stand_on_open_floor_that_can_be_walked_to() -> void:
	for place: String in [THIRD, ATTIC]:
		var loc := _loc(place)
		var rows := _rows(place)
		var reach := _reach(rows, _cell((loc["spawns"] as Dictionary)["default"]))
		var taken := {}
		for p: Dictionary in loc["props"]:
			var s := p.get("span", [1, 1]) as Array
			for i in int(s[0]):
				for j in int(s[1]):
					taken[_cell(p["cell"]) + Vector2i(i, j)] = str(p["id"])
		for c: Dictionary in loc.get("containers", []):
			taken[_cell(c["cell"])] = str(c["id"])
		for kind: String in ["exits", "doors"]:
			for x: Dictionary in loc.get(kind, []):
				taken[_cell(x["cell"])] = str(x["id"])
		for sp: Variant in (loc["spawns"] as Dictionary).values():
			taken[_cell(sp)] = "a spawn"
		for n: Dictionary in loc.get("npcs", []):
			var c := _cell(n["cell"])
			assert_true(_floor(rows, c), "%s stands on open floor at %s" % [n["npc"], c])
			assert_true(reach.has(c), "%s can be walked to" % n["npc"])
			assert_true(not taken.has(c), "%s stands on %s" % [n["npc"], taken.get(c, "")])
		for e: Dictionary in loc.get("encounters", []):
			var cells := {}
			for m: Dictionary in e["monsters"]:
				var c := _cell(m["cell"])
				assert_true(_floor(rows, c), "%s: %s starts on open floor (not a wall or low cover) at %s" % [e["id"], m["monster"], c])
				assert_true(reach.has(c), "%s: %s at %s can be walked to" % [e["id"], m["monster"], c])
				assert_true(not taken.has(c), "%s: %s at %s stands on %s" % [e["id"], m["monster"], c, taken.get(c, "")])
				assert_true(not cells.has(c), "%s: two foes at %s" % [e["id"], c])
				cells[c] = true
				var trig := str(e["trigger"])
				if trig.begins_with("examine:"):
					var at := _cell(_entry("props", "id", trig.substr(8))["cell"])
					assert_true(maxi(absi(at.x - c.x), absi(at.y - c.y)) >= 3, "%s: %s starts at least 3 squares from the %s the party stands beside" % [e["id"], m["monster"], trig])
		for p: Dictionary in loc["props"]:
			assert_true(reach.has(_cell(p["cell"])), "%s: prop %s can be walked to" % [place, p["id"]])
		for c: Dictionary in loc.get("containers", []):
			assert_true(reach.has(_cell(c["cell"])), "%s: container %s can be walked to" % [place, c["id"]])


func test_foes_start_spread_out() -> void:
	for id: String in FIGHTS:
		for e: Dictionary in _versions(id):
			var pts: Array[Vector2] = []
			for m: Dictionary in e["monsters"]:
				var c := _cell(m["cell"])
				pts.append(Vector2(c.x, c.y))
			if pts.size() >= 3:
				assert_true(_enclosing_radius(pts) > 4.5, "%s: no 20 ft burst catches all %d foes (they fit a circle of %.1f squares)" % [id, pts.size(), _enclosing_radius(pts)])


# --- Round events ---------------------------------------------------------------------------------------------------------------------

## An encounter on the place's own map with a hero on the fight's first foe's side of nothing, the spec's events in place, and combat begun.
func _fight(id: String) -> Array:
	var spec := _spec(id)
	var e := TestCombat.encounter(_rows(str(FIGHTS[id])), 3)
	e.default_player_reaction = "never"
	var hero := TestCombat.hero(e, "hedda_ironvow", Vector2i(22, 7) if FIGHTS[id] == THIRD else Vector2i(9, 9), 3)
	for m: Dictionary in spec["monsters"]:
		TestCombat.foe(e, str(m["monster"]), _cell(m["cell"]))
	e.legendary.set_round_events(LocationFights.round_events_for(st, spec))
	TestCombat.start_with(e, hero)
	return [e, hero, spec]


func _due(e: Encounter, round_no: int) -> Array[Dictionary]:
	e.round_no = round_no
	e.legendary.round_events.done.clear()
	return e.legendary.round_events.due(-1000)


func test_the_roar_climbs_a_step_a_round_and_gail_gives_the_bear_away_after_round_six() -> void:
	var got := _fight("ch_roar")
	var e := got[0] as Encounter
	var want := [[10, "1"], [11, "1d4"], [12, "1d6"], [13, "1d8"], [13, "1d8"]]
	for r in 5:
		var due := _due(e, r + 1)
		assert_eq(due.size(), 1, "round %d: one roar" % (r + 1))
		var ev := due[0]
		assert_eq(str(ev["id"]).begins_with("bears_roar_"), true, "round %d is the roar" % (r + 1))
		assert_eq(str((ev["save"] as Dictionary)["ability"]), "int", "an Intelligence save")
		assert_eq(int((ev["save"] as Dictionary)["dc"]), int((want[r] as Array)[0]), "round %d: its DC" % (r + 1))
		assert_eq(str((ev["damage"] as Dictionary)["dice"]), str((want[r] as Array)[1]), "round %d: its damage" % (r + 1))
		assert_eq(str((ev["damage"] as Dictionary)["type"]), "psychic", "psychic")
		assert_eq(int(ev["at"]), 20, "on initiative 20")
	var late := _due(e, 8)
	assert_eq(late.size(), 2, "from round 6 the roar is joined by the bear giving itself away")
	assert_true(late.any(func(ev: Dictionary) -> bool: return str(ev["id"]) == "gail_gives_way"), "Gail's own roar")
	assert_eq(_due(e, 6).size(), 2, "it starts in round 6")
	assert_eq(_due(e, 5).size(), 1, "and not before")


func test_the_roar_hurts_a_hero_who_fails_the_save() -> void:
	var got := _fight("ch_roar")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	for r: int in [1, 4]:
		var before := hero.creature.hp
		var ev := _due(e, r)[0]
		TestCombat.next_d20(e, 1)
		e.legendary.round_events.done.clear()
		e.legendary.round_events.act(ev, false)
		var lost := before - hero.creature.hp
		assert_true(lost >= 1 and lost <= (1 if r == 1 else 8), "round %d: a failed save costs %d" % [r, lost])


func test_arthurs_wail_stuns_whoever_fails_and_wisps_catch_is_a_rider_on_the_next_fight() -> void:
	var got := _fight("ch_quasits")
	var e := got[0] as Encounter
	var hero := got[1] as Combatant
	var due := _due(e, 1)
	assert_eq(due.size(), 1, "the wail alone")
	var wail := due[0]
	assert_eq(str(wail["id"]), "arthurs_wail")
	assert_eq(int((wail["save"] as Dictionary)["dc"]), 10, "DC 10")
	assert_eq(str((wail["save"] as Dictionary)["ability"]), "wis", "Wisdom")
	assert_eq(str(wail["condition"]), "stunned", "Stunned")
	assert_eq(str(wail["until"]), "target_turn_end", "until the end of their next turn")
	TestCombat.next_d20(e, 1)
	e.legendary.round_events.act(wail, false)
	assert_true(hero.creature.has_condition(&"stunned"), "a failed save: Stunned")
	# Wisp's catch rides the same fight only once his tales have been told.
	assert_eq(_versions("ch_quasits").size(), 3)
	st.set_flag("wisp_catch_pending")
	var with_catch := _spec("ch_quasits")
	assert_true((with_catch["round_events"] as Array).any(func(ev: Dictionary) -> bool: return str(ev["id"]) == "wisps_catch"), "the catch is in")
	st.set_flag("wisp_catch_pending", false)
	assert_true(not (_spec("ch_quasits")["round_events"] as Array).any(func(ev: Dictionary) -> bool: return str(ev["id"]) == "wisps_catch"), "and out without the tales")


# --- The floors played through -------------------------------------------------------------------------------------------------------

func _win(id: String) -> void:
	var spec := _spec(id)
	assert_true(not spec.is_empty(), "%s is a fight here" % id)
	if spec.is_empty():
		return
	won.append(id)
	(st.loc_state(st.location)["encounters"] as Dictionary)[id] = true
	if spec.has("flag"):
		st.set_flag(str(spec["flag"]))
	if spec.has("quest"):
		st.set_quest_stage(str((spec["quest"] as Dictionary)["id"]), str((spec["quest"] as Dictionary)["stage"]))


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out).
## Returns what the conversation ended in; a fight it starts is won as the game records a win, unless `win` is false.
func _play(ref: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	for i in 600:
		match str(b["kind"]):
			"end":
				break
			"options":
				var opts := b["options"] as Array
				var pick := opts.size() - 1
				if not left.is_empty():
					var want := str(left.pop_front())
					pick = -1
					for j in opts.size():
						if bool((opts[j] as Dictionary)["enabled"]) and str((opts[j] as Dictionary)["text"]).contains(want):
							pick = j
							break
					if pick < 0:
						fail("%s: no option '%s' among %s" % [ref, want, opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))])
						return {}
				b = r.choose(pick)
			"guidance":
				b = r.answer_guidance(-1)
			"pick_member":
				b = r.pick_member(0)
			_:
				b = r.next()
	assert_eq(str(b["kind"]), "end", "%s ends" % ref)
	assert_true(left.is_empty(), "%s: picks left over %s" % [ref, left])
	var combat := str(b.get("combat", ""))
	if combat != "" and win:
		_win(combat)
	return b


func _talk(npc: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
	var e := {}
	for n: Dictionary in _loc().get("npcs", []):
		if str(n["npc"]) == npc and _holds(n.get("when")):
			e = n
			break
	assert_true(not e.is_empty(), "%s is in %s to talk to" % [npc, st.location])
	if e.is_empty():
		return {}
	return _play(str(e["dialogue"]), picks, win)


func _here(npc: String) -> Dictionary:
	for n: Dictionary in _loc().get("npcs", []):
		if str(n["npc"]) == npc and _holds(n.get("when")):
			return n
	return {}


func test_the_toys_the_bear_and_arthur() -> void:
	var bear := _entry("containers", "id", "h13_crib_bear")
	assert_true(not _holds(bear.get("when")), "the bear is not in reach while the toys stand guard")
	var app := _entry("props", "id", "h13_apparition")
	assert_true(not _holds(app.get("call_when")), "the Crooked Man waits")
	assert_true(not _here("arthur_lockwood").is_empty() and int(_here("arthur_lockwood").get("approach", 0)) > 0, "Arthur wails to whoever comes in")
	_win("ch_quasits")
	assert_true(bool(st.get_flag("memento_bear")), "the toys' defeat is the bear")
	assert_true(_holds(bear.get("when")), "and it shows in the crib")
	assert_eq(str((bear["items"] as Array)[0]["id"]), "memento_blue_bear")
	assert_true(_holds(app.get("call_when")), "the Crooked Man's third-floor visit is due after the nursery")
	assert_eq(str(app["call"]), "crooked_house/crooked_man:floor3")
	# any one third-floor memento will do: the pin alone, before the nursery
	_fresh(THIRD)
	st.set_flag("memento_pin")
	assert_true(_holds(app.get("call_when")), "the pin alone brings him too")
	# Arthur, with the bear in the pack, is calmed the patient way
	_fresh(THIRD)
	_win("ch_quasits")
	st.party[0].add_item("memento_blue_bear", 1)
	_talk("arthur_lockwood", ["Sit down with him"])
	assert_true(bool(st.get_flag("arthur_rested")), "Arthur sleeps")
	assert_true(_here("arthur_lockwood").is_empty(), "and the crib is only a crib")
	assert_eq(st.quest_stage("arthurs_bear"), "asleep")


func test_wisps_three_tales_his_thanks_and_his_catch() -> void:
	assert_true(not _here("wisp").is_empty(), "the cat is in the library")
	_talk("wisp", ["Tell him a tale", "Tell a ghost story", "Act out a comic", "Sing a long ballad"])
	assert_eq(int(st.get_flag("wisp_tales")), 3, "three books are full")
	assert_eq(st.quest_stage("a_tale_for_wisp"), "thanked")
	assert_true(bool(st.get_flag("wisp_catch_pending")), "and his catch is waiting")
	assert_true(_here("wisp").is_empty(), "he winks out")
	assert_true((_spec("ch_quasits")["round_events"] as Array).any(func(ev: Dictionary) -> bool: return str(ev["id"]) == "wisps_catch"), "it rides the next fight")


func test_wisp_attacked_fights_and_his_fall_frees_walters_voice() -> void:
	var b := _talk("wisp", ["Draw a weapon"], false)
	assert_eq(str(b.get("combat")), "ch_wisp", "the talk ends in his fight")
	var spec := _spec("ch_wisp")
	assert_eq(str(((spec["monsters"] as Array)[0] as Dictionary)["monster"]), "ketgrinn", "a Ketgrinn")
	_win("ch_wisp")
	assert_true(bool(st.get_flag("wisp_slain")), "slain")
	assert_eq(st.quest_stage("a_tale_for_wisp"), "slain")
	assert_true(_here("wisp").is_empty(), "the desk is bare")


func test_wisp_threatened_leaves_by_the_window_without_a_fight() -> void:
	var b := _talk("wisp", ["Warn the cat"])
	assert_eq(str(b.get("combat", "")), "", "no fight")
	assert_eq(st.quest_stage("a_tale_for_wisp"), "fled")
	assert_true(_here("wisp").is_empty(), "gone")


func test_the_trapdoor_the_roar_the_ladder_and_gail() -> void:
	var door := _entry("props", "id", "h15_trapdoor")
	assert_eq(str(door["kind"]), "search", "the seam is a hidden find")
	assert_eq(int(door["search_dc"]), 10, "Perception DC 10")
	assert_eq(str(door["flag"]), "trapdoor_known", "touching it makes the hatch known")
	var up := _entry("exits", "id", "up_to_attic")
	assert_true(not _holds(up["when"]), "the plaster is only plaster at first")
	# the second ways: two checks on the hearth bring the seam to light; a miss turns up a tooth
	var hearth := _entry("props", "id", "h15_d01")
	var checks := hearth["checks"] as Array
	assert_eq(checks.size(), 2, "two world checks")
	for c: Dictionary in checks:
		assert_eq(((c["success"] as Dictionary)["reveal"] as Array)[0], "h15_trapdoor", "%s brings the seam to light" % c["id"])
	assert_eq(str((checks[0] as Dictionary)["skill"]), "perception")
	assert_eq(str((checks[0] as Dictionary)["id"]), "h15_trapdoor", "its Narrator key is check:perception:h15_trapdoor:failure")
	assert_eq((((checks[0] as Dictionary)["failure"] as Dictionary)["items"] as Array)[0]["id"], "human_tooth", "the house leaves a tooth on a miss")
	assert_true(not Compendium.shared().get_entry("items", "human_tooth").is_empty())
	# the roar fight's victory makes the hatch known (the weasels run into the ceiling)
	_win("ch_roar")
	assert_true(_holds(up["when"]), "the hatch is a way up")
	# the bear: cutting her out gives the pin and sets the flag
	var bear := _entry("props", "id", "h15_bear")
	assert_eq(str(bear["dialogue"]), "crooked_house/gail:start")
	_play("crooked_house/gail:start", ["Cut the stitches"])
	assert_true(bool(st.get_flag("memento_pin")), "Gail leaves the pin")
	assert_true(st.party_has_item("memento_silver_pin"), "in the party's hands")
	# the crow calls only while Lucan's beat is still to play
	var crow := _entry("props", "id", "h15_trophy_crow")
	assert_true(_holds(crow["call_when"]))
	st.set_flag("incitement_slaughter")
	assert_true(not _holds(crow["call_when"]))


func test_the_attic_runes_the_three_versions_of_the_boss_and_the_restored_manor() -> void:
	_fresh(ATTIC)
	for item: String in ["memento_bloodstone", "memento_black_key", "memento_porcelain_cup", "memento_wooden_doll", "memento_blue_bear", "memento_silver_pin"]:
		st.party[0].add_item(item, 1)
	var ward := _entry("doors", "id", "h16_ward")
	assert_true(not _holds(ward["when"]), "the ward holds")
	for what: String in ["bloodstone", "black key", "porcelain cup", "wooden doll", "blue bear", "silver pin"]:
		_play("crooked_house/sockets:place", ["Set the %s" % what])
	assert_eq(int(st.get_flag("mementos_placed")), 6, "six set")
	assert_true(_holds(ward["when"]), "the ward is down")
	# the ruse speaks first from the door; kneeling by her ends in the fight, not seen through, so she strikes first
	var ruse := _here("adela_druskenvald_ruse")
	assert_true(not ruse.is_empty() and int(ruse.get("approach", 0)) >= 8, "the woman on the floor speaks as the ward opens")
	var b := _talk("adela_druskenvald_ruse", ["Kneel beside", "Take her hand"], false)
	assert_eq(str(b.get("combat")), "ch_vessla", "the pre-fight talk ends in the boss fight")
	var plain := _spec("ch_vessla")
	assert_eq(str(plain.get("surprise")), "party", "unseen, the party is caught")
	assert_eq(((plain["monsters"] as Array).size()), 1, "Vessla alone")
	var hag := (plain["monsters"] as Array)[0] as Dictionary
	assert_eq(str(hag["monster"]), "weasel_hag")
	assert_eq(str((hag["steps_down"] as Dictionary)["npc"]), "adela_druskenvald_ruse", "she rises from the floor")
	assert_eq(_cell(hag["cell"]), _cell(ruse["cell"]), "where the woman lay")
	# the ruse seen through
	st.set_flag("vessla_ruse_seen")
	assert_eq(str(_spec("ch_vessla").get("surprise", "")), "", "seen through: nobody is surprised")
	# the tooth wins over the ruse: she is dazed and the party has the first move
	st.set_flag("vessla_tooth_gift")
	assert_eq(str(_spec("ch_vessla").get("surprise")), "enemies", "a tooth given: she is surprised")
	# Jasper, at 15 of his 31, joins in whichever version
	for flags: Array in [[], ["vessla_ruse_seen"], ["vessla_tooth_gift"]]:
		_fresh(ATTIC)
		for f: Variant in flags:
			st.set_flag(str(f))
		assert_eq((_spec("ch_vessla")["monsters"] as Array).size(), 1, "%s: no Jasper unless he fled" % [flags])
		st.set_flag("jasper_fled")
		var with_jasper := _spec("ch_vessla")["monsters"] as Array
		assert_eq(with_jasper.size(), 2, "%s: Jasper joins" % [flags])
		assert_eq(int((with_jasper[1] as Dictionary)["hp"]), 15, "at the Hit Points he left with")
		assert_eq(str((with_jasper[1] as Dictionary)["monster"]), "vermin_familiar_weasel")
	# win, and the rest of the scene follows
	_fresh(ATTIC)
	_win("ch_vessla")
	assert_true(bool(st.get_flag("vessla_slain")), "the hag is dead")
	assert_eq(st.quest_stage("the_crooked_house"), "done", "the quest ends in success")
	assert_true(_here("adela_druskenvald_ruse").is_empty(), "the woman on the floor is gone")
	var phillip := _here("phillip_druskenvald")
	assert_eq(str(phillip["dialogue"]), "crooked_house/vessla:death", "Phillip is where the hag's last word is heard")
	assert_true(int(phillip.get("approach", 0)) > 0, "and speaks as the party comes near")
	_talk("phillip_druskenvald", ["That is all we need"])
	assert_true(bool(st.get_flag("druskenvald_manor_restored")), "the house unbends")
	assert_true(bool(st.get_flag("phillip_reward_used")), "Phillip pays once")
	assert_eq(str(_here("phillip_druskenvald")["dialogue"]), "crooked_house/druskenvalds_after:chat", "later visits are the restored manor's")
	assert_eq(str(_here("adela_druskenvald")["dialogue"]), "crooked_house/druskenvalds_after:chat")


func test_the_scratchings_and_the_cauldron() -> void:
	_fresh(ATTIC)
	assert_eq(str(_entry("props", "id", "h17_scratchings")["flag"]), "coven_names_known", "reading the names is knowing them")
	var cauldron := _entry("props", "id", "h17_cauldron")
	assert_eq(str(cauldron["call"]), "crooked_house/incitements:immortality_enter")
	assert_true(_holds(cauldron["call_when"]))
	st.set_flag("incitement_immortality")
	assert_true(not _holds(cauldron["call_when"]))
	for pid: String in ["h17_phillip", "h17_adela"]:
		assert_eq(str(_entry("props", "id", pid)["kind"]), "examine", "%s has the Narrator's line" % pid)
