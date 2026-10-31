extends TestCase
## R12, the Crooked House: the whole house played from the Jenkins at the gate to the unbent manor, and the routes a single walk does
## not take. Each scenario plays the places' own data the way the game reads it: a person is only talked to while their entry's `when`
## holds, a prop's call fires once, when its `when` and `call_when` hold (LocationNpcs._check_calls), an exit only opens while its `when`
## does, a hiding place is searched by the leader's roll, a world check is rolled by the party's best hand who has not tried it
## (WorldChecks.attempt, then its outcome), a fight a prop, a check, an area or a conversation starts is the entry whose `when` holds
## and is won as LocationFights._end_encounter records a victory (its flag and its quest stage), and every conversation runs
## through the DialogueRunner (traced node by node). The helpers are test_r10_paths' with the House's own additions: world checks,
## containers, once-only calls, a save made and loaded in the middle of the house, and the dice switched in the middle of a
## conversation (a pick "@low" or "@high" in the list).
##
## Covered: (1) the spine, invited to done, level 4 paid once; (2) the six mementos won in eight seeded orders, the seance done early,
## late, in part or skipped, the ward opening at six, the ladder's every way, the Crooked Man's apparition once on each floor from its
## gate; (3) each memento's second way and failure branch; (4) Vessla's three versions and Jasper's Hit Points; (5) the porch steps and
## the porch exit in every flag state, and from a save made inside the house; (6) a wipe on every floor; (7) every conversation node of
## narrative/crooked_house/ reached by some path here, or listed in ALLOWED_UNPLAYED with the reason. The last tests are what the walk found:
## the board's last word, Wisp turned down, and (still open) a party under level 3.

const GAME := preload("res://world/game_root.gd")

## Dice that always roll the highest face: every check lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll 1: no check lands.
class LowDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(1)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## The game's DialogueRunner, remembering every node it enters (the coverage test reads `seen`).
class TraceRunner extends DialogueRunner:
	static var seen: Dictionary = {}
	static var log: Array[String] = []

	func _goto(ref: String) -> bool:
		var ok: bool = super(ref)
		if ok and ref != "END" and ref != "" and file != null:
			seen["%s:%s" % [file.key, node]] = true
			log.append("%s:%s" % [file.key, node])
		return ok


const ESTATE := "druskenvald_estate"
const FIRST := "crooked_house_first"
const SECOND := "crooked_house_second"
const THIRD := "crooked_house_third"
const ATTIC := "crooked_house_attic"
const HOUSE: Array[String] = [FIRST, SECOND, THIRD, ATTIC]
const PARTY: Array[String] = ["rook_coldwake", "tobin_hayward", "lucan_houndstooth", "silas_vane"]
const MEMENTOS: Array[String] = ["gem", "key", "cup", "doll", "bear", "pin"]
const ITEM := {"gem": "memento_bloodstone", "key": "memento_black_key", "cup": "memento_porcelain_cup", "doll": "memento_wooden_doll",
	"bear": "memento_blue_bear", "pin": "memento_silver_pin"}
const FLAG := {"gem": "memento_gem", "key": "memento_key", "cup": "memento_cup", "doll": "memento_doll", "bear": "memento_bear",
	"pin": "memento_pin"}
const SOCKET_OPTION := {"gem": "Set the bloodstone", "key": "Set the black key", "cup": "Set the porcelain cup", "doll": "Set the wooden doll",
	"bear": "Set the blue bear", "pin": "Set the silver pin"}
const FLOOR_OF := {"gem": FIRST, "key": FIRST, "cup": FIRST, "doll": SECOND, "bear": THIRD, "pin": THIRD}
## The Crooked Man's gate on each floor, the node it calls, and the flag that says it played.
const APPARITION := {FIRST: ["h_d02", "crooked_man_seen_1"], SECOND: ["h12_rope", "crooked_man_seen_2"], THIRD: ["h13_apparition", "crooked_man_seen_3"]}
## Ways to each memento (an order run takes them in turn).
const KEY_WAYS: Array[String] = ["perf", "religion", "arcana", "patience", "perf_miss_arcana"]
const CUP_WAYS: Array[String] = ["persuade", "both", "threat", "grab", "persuade_miss_both", "persuade_miss_threat"]
const DOLL_WAYS: Array[String] = ["found", "six"]
const BEAR_WAYS: Array[String] = ["persuade", "lullaby", "patient", "ignore", "miss_then_patient", "hush_first"]
const PIN_WAYS: Array[String] = ["cut", "look_then_cut"]
const SEANCE_ASKS: Array[String] = ["Who are you?", "Who did this to you?", "Where are Phillip", "Who is behind all of this?",
	"How do we get out of here", "Where is the door to the attic?", "Who is the grey cat?", "What is Shuck"]

## Conversation nodes no path here plays, and why (everything else must be reached).
const ALLOWED_UNPLAYED := {
	"crooked_house/arthur:done": "defensive: Arthur's entry is off the map once he sleeps (`when: not flag.arthur_rested`), so nobody can start it",
	"crooked_house/wisp:gone": "defensive: Wisp's entry is off the map once he is thanked, fled or slain, so nobody can start it",
	"crooked_house/keziah:peacock_round": "its five lines are lifted into the peacock fight's round event text (test_crooked_house_first checks they match)",
	"crooked_house/keziah:peacock_pull": "its lines are the peacock fight's Keziah's pull event text, said by the fight, not played as a conversation",
	"crooked_house/keziah:peacock_return": "its lines are the peacock fight's painting return, said by the fight, not played as a conversation",
}

var st: StoryState
var dice: DiceRoller = HighDice.new()
var fights: Array[String] = []
var apparitions: Array[String] = []
var auto_calls := true


func before_each() -> void:
	_fresh()


func after_each() -> void:
	GameState.reset()


## A new story: four level 3 heroes (Rook, Tobin, Lucan and Silas) at the estate's gate with level 4 two milestones away.
func _fresh(ids: Array[String] = PARTY, level: int = 3) -> void:
	GameState.reset()
	st = GameState.story
	for id: String in ids:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	apparitions.clear()
	auto_calls = true
	dice = HighDice.new()
	st.playthrough_seed = 1
	st.milestones = 2
	st.location = ESTATE
	st.visited[ESTATE] = true


# --- The helpers (test_r10_paths', with the House's own) ---------------------------------------------------------------------------


func _loc_of(id: String) -> Dictionary:
	return Compendium.shared().get_entry("locations", id)


func _loc() -> Dictionary:
	return _loc_of(st.location)


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


func _entry(list_key: String, id_key: String, id: String) -> Dictionary:
	for e: Variant in _loc().get(list_key, []):
		if str((e as Dictionary).get(id_key, "")) == id:
			return e as Dictionary
	return {}


## The entry that has `npc` on the map now (the first whose `when` holds), or {}.
func _npc_here(npc: String) -> Dictionary:
	for n: Variant in _loc().get("npcs", []):
		if str((n as Dictionary).get("npc", "")) == npc and _holds((n as Dictionary).get("when")):
			return n as Dictionary
	return {}


func _arrive(id: String) -> void:
	st.location = id
	st.visited[id] = true
	assert_true(not _loc().is_empty(), "%s is a place" % id)


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out, which
## is "leave" in every menu here). A pick "@low" or "@high" switches the conversation's dice before the next menu. A fight it starts is
## won as the game records a win, unless `win` is false. Returns what the conversation ended in.
func _play(ref: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
	var r := TraceRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	for i in 800:
		match str(b["kind"]):
			"end":
				break
			"options":
				while not left.is_empty() and str(left[0]).begins_with("@"):
					r.dice = LowDice.new() if str(left.pop_front()) == "@low" else HighDice.new()
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
	var move := b.get("move", {}) as Dictionary
	if not move.is_empty():
		_arrive(str(move["location"]))
	return b


## The entry of fight `id` as LocationFights.spec_for picks it: the first of the entries sharing the id whose `when` holds, else the last.
func _spec(id: String) -> Dictionary:
	var spec := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == id and (spec.is_empty() or not _holds(StoryConditions.encounter_when(spec))):
			spec = e as Dictionary
	return spec


func _win(id: String) -> void:
	_win_spec(_spec(id), id)


## Records a victory as LocationFights._end_encounter does: the place's won encounter, its flag and its quest stage.
func _win_spec(spec: Dictionary, id: String) -> void:
	assert_true(not spec.is_empty(), "%s has the fight %s" % [st.location, id])
	if spec.is_empty():
		return
	fights.append(id)
	(st.loc_state(st.location)["encounters"] as Dictionary)[id] = true
	if spec.has("flag"):
		st.set_flag(str(spec["flag"]))
	if spec.has("quest"):
		st.set_quest_stage(str((spec["quest"] as Dictionary)["id"]), str((spec["quest"] as Dictionary)["stage"]))


## What LocationFights._trigger_encounter starts for `trigger` here (the first entry of the trigger, not yet won, whose `when` holds):
## its entry, won at once unless `win` is false; {} when nothing starts.
func _trigger(trigger: String, win: bool = true) -> Dictionary:
	var won := st.loc_state(st.location)["encounters"] as Dictionary
	for en: Variant in _loc().get("encounters", []):
		var spec := en as Dictionary
		if str(spec["trigger"]) != trigger or bool(won.get(str(spec["id"]), false)) == true:
			continue
		if not _holds(StoryConditions.encounter_when(spec, str(_loc().get("region", "")))):
			continue
		if win:
			_win_spec(spec, str(spec["id"]))
		return spec
	return {}


## Talks to `npc`, as clicking them does: the entry that has them on the map now. Their approach talk, if any, is spent.
func _talk(npc: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
	var e := _npc_here(npc)
	assert_true(not e.is_empty(), "%s is in %s to talk to" % [npc, st.location])
	if e.is_empty():
		return {}
	(st.loc_state(st.location)["props"] as Dictionary)["approach:%s:%s" % [npc, e["dialogue"]]] = true
	return _play(str(e["dialogue"]), picks, win)


## A prop's call, as walking up to it fires it (LocationNpcs._check_calls): its `when` and `call_when` must hold and it speaks once.
func _called_by(prop: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
	var p := _entry("props", "id", prop)
	var seen := st.loc_state(st.location)["props"] as Dictionary
	var ok := not p.is_empty() and _holds(p.get("when")) and _holds(p.get("call_when")) and not bool(seen.get("call:" + prop, false))
	assert_true(ok, "%s calls out in %s now" % [prop, st.location])
	if not ok:
		return {}
	seen["call:" + prop] = true
	return _play(str(p["call"]), picks, win)


## Every call on this floor that is due (the party has walked up to it): played once each, with the picks named for it by prop id.
## Returns the props that spoke.
func _calls(picks: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	if not auto_calls:
		return out
	var again := true
	while again:
		again = false
		var seen := st.loc_state(st.location)["props"] as Dictionary
		for p: Variant in _loc().get("props", []):
			var spec := p as Dictionary
			if int(spec.get("approach", 0)) <= 0 or str(spec.get("call", "")) == "" or bool(seen.get("call:" + str(spec["id"]), false)):
				continue
			if not _holds(spec.get("when")) or not _holds(spec.get("call_when")):
				continue
			var list: Array[String] = []
			list.assign(picks.get(str(spec["id"]), []) as Array)
			_called_by(str(spec["id"]), list)
			out.append(str(spec["id"]))
			if str(spec["id"]) in ["h_d02", "h12_rope", "h13_apparition"]:
				apparitions.append(str(spec["id"]))
			again = true
			break
	return out


## Using a prop (LocationInteraction._use_prop): its flag set, its item taken once, its conversation played, else the fight it starts
## by being examined. A hidden find has to be found first. Returns the conversation's end, or {fight: id}.
func _use_prop(prop: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
	var p := _entry("props", "id", prop)
	assert_true(not p.is_empty() and _holds(p.get("when")), "%s can be used in %s" % [prop, st.location])
	if p.is_empty():
		return {}
	if str(p.get("kind")) == "search":
		assert_true(bool((st.loc_state(st.location)["found"] as Dictionary).get(prop, false)), "%s is found before it is used" % prop)
	var used := st.loc_state(st.location)["props"] as Dictionary
	if p.has("flag"):
		st.set_flag(str(p["flag"]))
	if p.has("item") and not bool(used.get(prop, false)):
		st.gain_item(str(p["item"]), 1, st.party[0])
	used[prop] = true
	if str(p.get("dialogue", "")) != "":
		return _play(str(p["dialogue"]), picks, win)
	var spec := _trigger("examine:" + prop, win)
	return {"fight": str(spec.get("id", ""))}


## The leader's Search (LocationTraps._search): Perception against the hidden find's DC; found things stay found. Whether it was found.
func _search_for(prop: String) -> bool:
	var p := _entry("props", "id", prop)
	assert_true(not p.is_empty() and str(p.get("kind")) == "search" and _holds(p.get("when")), "%s can be searched for in %s" % [prop, st.location])
	if p.is_empty():
		return false
	var t := st.party[0].roll_check(dice, &"perception", 0, [] as Array[String], [] as Array[String], "search", ["search"] as Array[String], [])
	var found := t.total >= int(p.get("search_dc", 10))
	if found:
		(st.loc_state(st.location)["found"] as Dictionary)[prop] = true
	return found


## A world check on a prop, rolled and applied as LocationChecks does, then the fight it sets off. {success, fight, who}.
func _world_check(prop: String, check_id: String, roll_with: DiceRoller = null) -> Dictionary:
	var spec := _entry("props", "id", prop)
	var check := WorldChecks.find(spec, check_id)
	var open := not check.is_empty() and WorldChecks.open(st, st.location, check)
	assert_true(open, "%s's check %s can be tried in %s" % [prop, check_id, st.location])
	if not open:
		return {}
	var rolls: DiceRoller = roll_with if roll_with != null else dice
	var res := WorldChecks.attempt(st, st.location, check, rolls)
	assert_true(not res.is_empty(), "someone rolls %s" % check_id)
	if res.is_empty():
		return {}
	var success := bool(res["success"])
	var outcome := check.get("success" if success else "failure", {}) as Dictionary
	WorldChecks.apply(st, outcome, res["who"] as Character, rolls, str(check.get("label", "")))
	for r: Variant in outcome.get("reveal", []):
		if not str(r).contains(":"):
			(st.loc_state(st.location)["found"] as Dictionary)[str(r)] = true
	var fight := _trigger("check:%s:%s" % [check_id, "success" if success else "failure"])
	return {"success": success, "fight": str(fight.get("id", "")), "spec": fight}


## Takes what a container holds (it must be on the map now), once.
func _loot(container: String) -> void:
	var c := _entry("containers", "id", container)
	var looted := st.loc_state(st.location)["looted"] as Dictionary
	assert_true(not c.is_empty() and _holds(c.get("when")) and not bool(looted.get(container, false)), "%s can be looted in %s" % [container, st.location])
	if c.is_empty():
		return
	for it: Variant in c.get("items", []):
		st.gain_item(str((it as Dictionary)["id"]), int((it as Dictionary).get("qty", 1)), st.party[0])
	looted[container] = true


func _exit_open(exit: String, place: String = "") -> bool:
	for e: Variant in _loc_of(place if place != "" else st.location).get("exits", []):
		if str((e as Dictionary)["id"]) == exit:
			return _holds((e as Dictionary).get("when"))
	fail("%s has no exit %s" % [place if place != "" else st.location, exit])
	return false


## Walks out through `exit`: it must be open now.
func _exit(exit: String) -> void:
	var e := _entry("exits", "id", exit)
	assert_true(not e.is_empty() and _holds(e.get("when")), "%s: the exit %s is open (%s)" % [st.location, exit, e.get("locked_text", "")])
	if e.is_empty():
		return
	if str(e["to"]) == "travel":
		st.location = "travel"
		return
	_arrive(Campaign.module().exit_target(st, st.location, str(e["to"])))


## Up or down the stairs to the floor `place` of the house (each stair open), the calls that are due on every floor passed through.
func _go(place: String) -> void:
	var guard := 0
	while st.location != place and guard < 8:
		guard += 1
		var here := HOUSE.find(st.location)
		var there := HOUSE.find(place)
		assert_true(here >= 0 and there >= 0, "%s to %s is a walk inside the house" % [st.location, place])
		if here < 0 or there < 0:
			return
		if there > here:
			_exit("up_to_attic" if st.location == THIRD else "stairs_up")
		else:
			_exit("ladder_down" if st.location == ATTIC else "stairs_down")
		_calls()
	_calls()


func _stage() -> String:
	return st.quest_stage("the_crooked_house")


func _have(m: String) -> bool:
	return st.party_has_item(str(ITEM[m]))


## How many of an item the party and its stash hold.
func _count(item: String) -> int:
	var n := 0
	for ch in st.party:
		for e: Dictionary in ch.inventory:
			if str(e["id"]) == item:
				n += int(e.get("qty", 1))
	for e: Dictionary in st.stash:
		if str(e["id"]) == item:
			n += int(e.get("qty", 1))
	return n


## A save made right now and loaded again (the JSON file's round trip): the story the rest of the scenario plays on.
func _reload() -> void:
	var data := JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary
	var kept := dice
	st = StoryState.from_dict(data)
	GameState.story = st
	dice = kept


## The party at the estate gate with the road up the hill behind it (R11's road_to_estate sets the first stage).
func _on_the_hill() -> void:
	_arrive(ESTATE)
	st.set_quest_stage("the_crooked_house", "invited")


# --- The way in: the gate, the turn, the porch, the storm ----------------------------------------------------------------------------


## Gilly at the gate, the house turning, the Crooked Man on the porch, the storm, the porch steps and the foyer. `strike`: the party
## swings at the Crooked Man instead of walking in.
func _gate_to_the_house(strike: bool = false) -> void:
	_on_the_hill()
	assert_true(not _npc_here("gilly_jenkin").is_empty() and _npc_here("crooked_man").is_empty(), "the Jenkins wait at the gate on the first evening")
	assert_true(not _exit_open("porch_steps"), "the porch steps are shut until the Crooked Man has been met")
	_talk("gilly_jenkin", ["Where are the two of you", "Have you seen the Lord", "What is the house like", "Walter seems on edge",
		"We'll go up to the house"])
	assert_true(bool(st.get_flag("crooked_house_turned")), "the house has turned")
	assert_eq(_stage(), "arrived", "the gate stage")
	assert_true(_npc_here("gilly_jenkin").is_empty() and _npc_here("walter_jenkin").is_empty(), "the Jenkins have gone down the hill")
	assert_true(not _npc_here("crooked_man").is_empty(), "the Crooked Man waits on the porch")
	assert_true(not _exit_open("porch_steps"), "and the steps are still shut before he has spoken")
	var picks: Array[String] = ["Who are you?", "Where are Lord Phillip", "What do you want with us?", "Study him closely", "Feel the air"]
	picks.append("Strike at him" if strike else "Go inside")
	_talk("crooked_man", picks)
	assert_true(bool(st.get_flag("crooked_man_met")), "the Crooked Man has been met")
	assert_eq(_stage(), "trapped", "the storm shuts the party in")
	assert_true(_npc_here("crooked_man").is_empty(), "he is gone from the porch")
	_exit("porch_steps")
	assert_eq(st.location, FIRST, "the steps lead into the house")
	assert_true(not _exit_open("to_estate"), "the way back down is shut in the storm")


# --- The mementos --------------------------------------------------------------------------------------------------------------------


func _get_gem() -> void:
	_go(FIRST)
	var out := _use_prop("h4_peacock")
	assert_eq(str(out.get("fight", "")), "ch_peacock", "the peacock fights")
	assert_true(bool(st.get_flag("memento_gem")), "the gem is won")
	_calls()
	_loot("h4_peacock_stone")
	assert_true(_have("gem"), "the bloodstone is in hand")


func _get_key(way: String) -> void:
	_go(FIRST)
	_trigger("enter_area:h5_floor")   # every way to the harpsichord crosses the dance floor, and the weasels fall first
	var picks: Array[String] = []
	var spent_hour := 0
	match way:
		"perf":
			picks = ["@high", "Sit at the bench"]
		"religion":
			picks = ["@high", "Ask the dead servant"]
		"arcana":
			picks = ["@high", "Draw upon the lingering music"]
		"patience":
			picks = ["@low", "Sit at the bench", "Ask the dead servant", "Draw upon the lingering music", "Wait quietly"]
			spent_hour = 60 + 30
		"perf_miss_arcana":
			picks = ["@low", "Sit at the bench", "@high", "Draw upon the lingering music"]
			spent_hour = 10
	var before := st.total_minutes()
	_use_prop("h5_harpsichord", picks)
	assert_true(bool(st.get_flag("memento_key")) and _have("key"), "the black key (%s)" % way)
	assert_true(st.total_minutes() - before >= spent_hour, "%s: the night passes as the misses and the wait cost it" % way)
	assert_true(_stage() != "trapped", "the lament moves the quest on from trapped")
	_use_prop("h5_harpsichord")   # a second look is the played-out line


func _persuade_picks() -> Array[String]:
	return ["Ask after her children", "Speak gently of Sally"]


func _get_cup(way: String) -> void:
	_go(FIRST)
	var picks: Array[String] = []
	var fight := false
	match way:
		"persuade":
			picks = _persuade_picks()
		"both":
			picks = ["Set the doll and the bear"]
		"threat":
			picks = ["Tell her you mean to have that cup"]
			fight = true
		"grab":
			picks = ["Reach out and take the cup"]
			fight = true
		"persuade_miss_both":
			picks = ["@low", "Ask after her children", "Speak gently of Sally", "@high", "Set the doll and the bear"]
		"persuade_miss_threat":
			picks = ["@low", "Ask after her children", "Speak gently of Sally", "Tell her you mean to have that cup"]
			fight = true
	var had_pair := _have("doll") and _have("bear")
	_talk("petunia_lockwood", picks)
	if fight:
		assert_true(fights.has("ch_petunia"), "%s: her fight is won" % way)
		assert_true(bool(st.get_flag("petunia_destroyed")), "%s: she is destroyed" % way)
		assert_true(not _have("cup"), "the cup is left behind on the tiles")
		assert_eq(_calls({"h8_cup": ["Pick up the green ribbon"] as Array[String]}), ["h8_cup"] as Array[String], "the cup calls out after the fight")
		assert_true(st.party_has_item("green_ribbon"), "the ribbon is picked up")
	else:
		assert_true(bool(st.get_flag("petunia_at_peace")), "%s: she is at peace" % way)
		assert_eq(st.quest_stage("petunias_cup"), "peace")
	assert_true(bool(st.get_flag("memento_cup")) and _have("cup"), "the cup (%s)" % way)
	assert_true(_npc_here("petunia_lockwood").is_empty(), "her chair is empty")
	if way.ends_with("both") or way == "both":
		assert_true(had_pair, "the doll and the bear were in hand")


func _spot_order(n: int) -> Array[String]:
	var spots: Array[String] = []
	spots.assign(CrookedMoonCampaign.LURKER_SPOTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + n
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := spots[i]
		spots[i] = spots[j]
		spots[j] = t
	return spots


func _get_doll(way: String, n: int = 0) -> void:
	_go(SECOND)
	var at := CrookedMoonCampaign.LURKER_SPOTS[CrookedMoonCampaign.lurker_spot(st.playthrough_seed) - 1]
	var found := {}
	var searched := 0
	for id: String in _spot_order(n):
		searched += 1
		# "six": the place it hides is searched and missed, so only the sixth search brings it down on the party.
		var roll_with: DiceRoller = LowDice.new() if (way == "six" and id == at) else HighDice.new()
		found = _world_check(id, id, roll_with)
		if found["fight"] != "":
			break
	assert_eq(str(found.get("fight", "")), "ch_lurker", "%s: the lurker comes out" % way)
	if way == "found":
		assert_eq(str((found["spec"] as Dictionary).get("surprise", "")), "", "found at %s, nobody is surprised" % at)
		assert_true(bool(found["success"]), "found by a successful look")
	else:
		assert_eq(searched, 6, "it drops from the ceiling only at the sixth search")
		assert_eq(str((found["spec"] as Dictionary).get("surprise", "")), "party", "and catches the party unawares")
	assert_eq(st.quest_stage("sallys_monsters"), "lurker_dead", "Sally's quest knows")
	_use_prop("h10_doll", ["The monster is gone"])
	assert_true(bool(st.get_flag("sally_rested")) and _have("doll"), "the doll (%s)" % way)
	assert_eq(st.quest_stage("sallys_monsters"), "rested")


func _get_bear(way: String) -> void:
	_go(THIRD)
	if way == "hush_first":
		_talk("arthur_lockwood", ["Try to hush him"])
		assert_true(not bool(st.get_flag("arthur_rested")), "a hush without the bear does nothing")
	var out := _use_prop("h13_crib")
	assert_eq(str(out.get("fight", "")), "ch_quasits", "the toys fight")
	assert_true(bool(st.get_flag("memento_bear")), "the bear is the memento")
	_loot("h13_crib_bear")
	assert_true(_have("bear"), "the blue bear is in hand")
	var picks: Array[String] = []
	match way:
		"persuade":
			picks = ["@high", "Speak low and steady"]
		"lullaby":
			picks = ["@high", "Sing him the harpsichord's lament" if bool(st.get_flag("memento_key")) else "Sing him a lullaby"]
		"patient", "hush_first":
			picks = ["Sit down with him"]
		"miss_then_patient":
			picks = ["@low", "Speak low and steady", "Sit down with him"]
	if way == "ignore":
		assert_true(not _npc_here("arthur_lockwood").is_empty(), "Arthur is still wailing in the nursery")
		assert_true(_have("bear"), "and the bear is the memento all the same")
	else:
		_talk("arthur_lockwood", picks)
		assert_true(bool(st.get_flag("arthur_rested")), "Arthur sleeps (%s)" % way)
		assert_true(_npc_here("arthur_lockwood").is_empty(), "the crib is only a crib")
		assert_true(_have("bear"), "the bear stays with the party")


func _get_pin(way: String) -> void:
	_go(THIRD)
	var picks: Array[String] = ["Cut the stitches"]
	if way == "look_then_cut":
		picks = ["@high", "Look past the roar", "Cut the stitches"]
	_use_prop("h15_bear", picks)
	assert_true(bool(st.get_flag("memento_pin")) and _have("pin"), "the silver pin (%s)" % way)
	_use_prop("h15_bear")   # a second look at the bear is the moths' nest


func _acquire(m: String, way: String, n: int = 0) -> void:
	match m:
		"gem":
			_get_gem()
		"key":
			_get_key(way)
		"cup":
			_get_cup(way)
		"doll":
			_get_doll(way, n)
		"bear":
			_get_bear(way)
		"pin":
			_get_pin(way)
	assert_true(bool(st.get_flag(str(FLAG[m]))), "%s is won" % m)
	assert_true(_have(m), "%s is in the pack" % m)


# --- The seance, the hatch and the ward ------------------------------------------------------------------------------------------------


## The spirit board (H3) with the questions `asks` (parts of the menu's lines), then goodbye if `goodbye`. The conversation is the prop's.
func _seance(asks: Array[String], goodbye: bool = true) -> void:
	_go(FIRST)
	var picks: Array[String] = ["Lay our fingertips"]
	picks.append_array(asks)
	var everything := asks.size() >= 8   # all eight asked: his last words follow by themselves
	if goodbye and not everything:
		picks.append_array(["That is enough", "Let him go"] as Array[String])
	_use_prop("h3_spirit_board", picks)
	if goodbye:
		assert_true(bool(st.get_flag("seance_done")), "the board goes quiet for good")


## The ladder's way up: the hatch is shut until one of its ways is taken. `way`: search (the leader finds the seam, and the roar
## answers when it is used), hearth_perception and hearth_investigation (the world checks reveal the seam, a miss first for the first
## of them), seance (already asked), roar (the search found it and the roar was won).
func _open_hatch(way: String) -> void:
	_go(THIRD)
	if way == "seance":
		assert_true(bool(st.get_flag("trapdoor_known")), "the board named the attic door")
		assert_true(_exit_open("up_to_attic"), "so the hatch is a way up")
		return
	assert_true(not _exit_open("up_to_attic"), "%s: the ceiling is only plaster before it is found" % way)
	var seam := _entry("props", "id", "h15_trapdoor")
	assert_true(not bool((st.loc_state(st.location)["found"] as Dictionary).get("h15_trapdoor", false)), "the seam is hidden")
	match way:
		"search", "roar":
			assert_true(_search_for("h15_trapdoor"), "the leader's search finds the seam")
		"hearth_perception":
			var miss := _world_check("h15_d01", "h15_trapdoor", LowDice.new())
			assert_true(not bool(miss["success"]), "a miss at the hearth turns up a tooth")
			assert_true(st.party_has_item("human_tooth"), "the house leaves a tooth")
			assert_true(not bool((st.loc_state(st.location)["found"] as Dictionary).get("h15_trapdoor", false)), "and the seam stays hidden")
			var hit := _world_check("h15_d01", "h15_trapdoor", HighDice.new())
			assert_true(bool(hit["success"]), "someone else finds the seam above the hearth")
		"hearth_investigation":
			var study := _world_check("h15_d01", "h15_ceiling_study", HighDice.new())
			assert_true(bool(study["success"]), "the stain's edges give the seam away")
	assert_true(not seam.is_empty() and bool((st.loc_state(st.location)["found"] as Dictionary).get("h15_trapdoor", false)), "%s: the seam is found" % way)
	assert_true(not _exit_open("up_to_attic"), "%s: found is not yet known: the ring has to be tried" % way)
	var out := _use_prop("h15_trapdoor")
	assert_eq(str(out.get("fight", "")), "ch_roar", "%s: the ring starts the roar's fight" % way)
	assert_true(bool(st.get_flag("trapdoor_known")), "the hatch is known")
	assert_true(_exit_open("up_to_attic"), "%s: and open" % way)
	assert_true(_stage() in ["attic", "vessla", "done"], "the quest has moved on to the attic")


## Sets the mementos `order` into the runes: the ward stays down for five and opens with the sixth. `reload_at`: a save made and loaded
## after that many are set.
func _place_all(order: Array[String], reload_at: int = -1) -> void:
	_go(ATTIC)
	var ward := _entry("doors", "id", "h16_ward")
	assert_true(not ward.is_empty(), "the ward is a door here")
	for i in order.size():
		assert_true(not _holds(ward.get("when")), "the ward holds with %d set" % i)
		assert_eq(int(st.get_flag("mementos_placed", 0)), i, "%d circles are lit" % i)
		var set_it: Array[String] = [str(SOCKET_OPTION[order[i]])]
		if i == 0:
			set_it.push_front("Look the circles over")   # a look first: the Narrator says what the circles want
		_use_prop("h16_sockets", set_it)
		assert_eq(int(st.get_flag("mementos_placed", 0)), i + 1, "%s is set" % order[i])
		assert_true(not _have(order[i]), "and out of the pack")
		if i + 1 == reload_at:
			_reload()
			ward = _entry("doors", "id", "h16_ward")
	assert_true(_holds(_entry("doors", "id", "h16_ward").get("when")), "the sixth opens the ward")
	assert_eq(_stage(), "vessla", "the quest turns to the hag")
	_use_prop("h16_sockets")   # a look at the lit circles
	assert_eq(int(st.get_flag("mementos_placed", 0)), 6, "nothing more to set")


## The cauldron room: how the party meets Vessla. Returns the fight's entry as it stands when the conversation ends (not yet won).
func _confront(way: String) -> Dictionary:
	_go(ATTIC)
	assert_true(not _npc_here("adela_druskenvald_ruse").is_empty(), "the woman on the floor speaks as the ward opens")
	var picks: Array[String] = []
	match way:
		"kneel":
			picks = ["Kneel beside the fallen woman", "Ask what happened to her", "Take her hand"]
		"seen_from_afar":
			picks = ["@high", "Study the woman on the floor"]
		"seen_up_close":
			picks = ["Kneel beside the fallen woman", "@high", "Watch how she holds herself"]
		"missed_then_kneel":
			picks = ["@low", "Study the woman on the floor", "Kneel beside the fallen woman", "Take her hand"]
		"missed_close_then_help":
			picks = ["@low", "Kneel beside the fallen woman", "Watch how she holds herself", "Take her hand"]
		"phillip_first":
			picks = ["Go to Phillip by the cauldron", "Kneel beside the fallen woman", "Take her hand"]
		"tooth":
			picks = ["@high", "Search our memories", "Work a tooth loose", "Strike her"]
		"tooth_talk_cut":
			picks = ["@high", "Search our memories", "Work a tooth loose", "Speak with her", "Cut Phillip loose", "Strike her"]
		"tooth_cut_talk":
			picks = ["@high", "Search our memories", "Work a tooth loose", "Cut Phillip loose", "Speak with her", "Strike her"]
		"lore_missed_then_seen":
			picks = ["@low", "Search our memories", "@high", "Study the woman on the floor"]
	var ended := _talk("adela_druskenvald_ruse", picks, false)
	assert_eq(str(ended.get("combat", "")), "ch_vessla", "%s: the talk ends in the boss fight" % way)
	var spec := _spec("ch_vessla")
	var tooth := bool(st.get_flag("vessla_tooth_gift"))
	var seen := bool(st.get_flag("vessla_ruse_seen"))
	var want := "enemies" if tooth else ("" if seen else "party")
	assert_eq(str(spec.get("surprise", "")), want, "%s: tooth %s, ruse seen %s" % [way, tooth, seen])
	var fled := bool(st.get_flag("jasper_fled"))
	var monsters := spec["monsters"] as Array
	assert_eq(monsters.size(), 2 if fled else 1, "%s: Jasper joins only if he fled" % way)
	if fled:
		assert_eq(int((monsters[1] as Dictionary)["hp"]), 15, "at the Hit Points he left with")
	assert_eq(str((monsters[0] as Dictionary)["monster"]), "weasel_hag")
	return spec


## After the hag falls: her last word, the unbent house, Phillip's thanks (once), the runes letting the six go, the way home.
func _unbend() -> void:
	assert_true(bool(st.get_flag("vessla_slain")), "the hag is dead")
	assert_eq(_stage(), "done", "the fight ends the quest in success")
	assert_true(_npc_here("adela_druskenvald_ruse").is_empty(), "the woman on the floor is gone")
	var gold := st.gold
	assert_eq(st.milestones, 2, "level 4 is not paid until the Lord speaks")
	_talk("phillip_druskenvald", ["What do the two of you remember", "Look at these two names", "Will you stay on", "What can you tell us about the Ghostlight",
		"That is all we need"])
	assert_true(bool(st.get_flag("druskenvald_manor_restored")), "the house unbends")
	assert_true(bool(st.get_flag("coven_names_known")), "the names are read")
	assert_eq(st.milestones, 3, "level 4 is paid")
	assert_eq(st.target_level(), 4, "the party may rise to level 4")
	assert_eq(st.gold, gold + 300.0, "75 gp to each of four heroes")
	assert_true(bool(st.get_flag("phillip_reward_used")) and bool(st.get_flag("vessla_level_given")), "once")
	assert_eq(str(_npc_here("phillip_druskenvald")["dialogue"]), "crooked_house/druskenvalds_after:chat", "later visits are the restored manor's")
	_talk("adela_druskenvald")
	_play("crooked_house/druskenvalds_after:thanks")   # the thanks again pays nothing more
	assert_eq(st.milestones, 3, "level 4 is paid once")
	assert_eq(st.gold, gold + 300.0, "so is the purse")
	# the runes let the keepsakes go
	_use_prop("h16_sockets")
	assert_true(bool(st.get_flag("mementos_released")), "the runes release the six")
	for m: String in MEMENTOS:
		assert_true(_have(m), "%s is handed back" % m)
	_use_prop("h16_sockets")
	for m: String in MEMENTOS:
		assert_eq(_count(str(ITEM[m])), 1, "%s is handed back once" % m)
	# the way home: down the ladder and out of the porch, the Jenkins in the grounds
	_go(FIRST)
	assert_true(_exit_open("to_estate"), "the storm has gone: the porch exit is open")
	_exit("to_estate")
	assert_eq(st.location, ESTATE)
	_talk("gilly_jenkin", ["The house looks different", "Lord Phillip and Lady Adela are safe", "How is Dani", "Did you notice anything in the grounds",
		"That's all for now"])
	_talk("gilly_jenkin")   # the second talk
	assert_true(_exit_open("porch_steps"), "the steps stay open")


# --- One whole walk --------------------------------------------------------------------------------------------------------------

var stage_floor := 0


## The quest never goes back a stage, in any order.
func _check_stage(note: String) -> void:
	var at := st.quest_stage_index("the_crooked_house", _stage())
	assert_true(at >= stage_floor, "%s: the quest went back a stage to %s" % [note, _stage()])
	stage_floor = maxi(stage_floor, at)


## Shuffles the six mementos with a seeded generator (Fisher-Yates on our own, so every run gives the same orders).
func _shuffled(seed_value: int) -> Array[String]:
	var out: Array[String] = []
	out.assign(MEMENTOS)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := out[i]
		out[i] = out[j]
		out[j] = t
	return out


## The checks a floor's apparition has to pass: it is due exactly when the contract says (the first floor after the seance or the second
## of its three mementos, the others after any one of theirs), once, and the gate is the same prop whichever room the party came from.
func _expect_gates(note: String) -> void:
	var first := 0
	for m: String in ["gem", "key", "cup"]:
		first += 1 if bool(st.get_flag(str(FLAG[m]))) else 0
	var due := {
		FIRST: bool(st.get_flag("seance_done")) or first >= 2,
		SECOND: bool(st.get_flag("memento_doll")) or bool(st.get_flag("jasper_slain")) or bool(st.get_flag("jasper_fled")),
		THIRD: bool(st.get_flag("memento_bear")) or bool(st.get_flag("memento_pin")),
	}
	var seen := st.loc_state(st.location)["props"] as Dictionary
	for floor_id: String in [FIRST, SECOND, THIRD]:
		if st.location != floor_id:
			continue
		var gate := _entry("props", "id", str((APPARITION[floor_id] as Array)[0]))
		var played := bool(st.get_flag(str((APPARITION[floor_id] as Array)[1])))
		var on := _holds(gate.get("call_when")) and not bool(seen.get("call:" + str(gate["id"]), false))
		assert_eq(on, bool(due[floor_id]) and not played, "%s: the %s apparition is %s" % [note, floor_id, "due" if due[floor_id] else "not yet due"])


## Other things the house offers, done on the way: the dining room's feast and its table, the clock, the bath, the portraits, the
## paintings, Wisp's three tales.
func _extras(list: Array[String]) -> void:
	for what: String in list:
		match what:
			"feast":
				_go(FIRST)
				assert_eq(str(_use_prop("h6_table").get("fight", "")), "ch_feast")
				var loot := _world_check("h6_table_loot", "h6_table_loot")
				assert_true(bool(loot["success"]) and st.party_has_item("pearl_of_power") and st.party_has_item("gold_ring_75"), "the table's pearl and ring")
			"portraits":
				_go(FIRST)
				for p: String in ["h2_portrait_lockwood", "h2_portrait_druskenvald", "h2_portrait_party"]:
					var plaque: Array[String] = []
					if p == "h2_portrait_lockwood":
						plaque.append("Read the brass plaque")
					_use_prop(p, plaque)
					_use_prop(p)
			"paintings":
				_go(FIRST)
				_use_prop("h4_paintings", ["Look closer at the painted skies"] as Array[String])
			"clock":
				_go(SECOND)
				assert_eq(str(_use_prop("h9_clock").get("fight", "")), "ch_clock")
				_world_check("h9_clock", "h9_gears")
				assert_true(st.party_has_item("gold_pocket_watch"), "the watch is in the gears")
			"bath":
				_go(SECOND)
				assert_eq(str(_use_prop("h11_tub").get("fight", "")), "ch_bath")
			"wisp_tales":
				_go(THIRD)
				_talk("wisp", ["Tell him a tale", "Tell a ghost story", "Act out a comic", "Sing a long ballad"])
				assert_true(bool(st.get_flag("wisp_catch_pending")), "his catch rides the next fights")
				var spec := _spec("ch_quasits")
				assert_true((spec["round_events"] as Array).any(func(ev: Dictionary) -> bool: return str(ev["id"]) == "wisps_catch"), "Wisp's catch is in the toys' fight")
			"wisp_fight":
				_go(THIRD)
				_talk("wisp", ["Draw a weapon"])
				assert_true(bool(st.get_flag("wisp_slain")))


## The whole house in one order. `cfg`: order (the six, in the order they are won), seance (none | start | start_part | late_full |
## late_part), hatch (search | hearth_perception | hearth_investigation | seance | roar), shift (into the ways), seed (the playthrough's),
## place (the order they are set in the runes), reload (a save is made and loaded after that many are set; and in the middle of the
## walk), jasper (none | kill | flee), vessla (a way to meet her), extras (see _extras), strike (swing at the Crooked Man).
func _run_order(cfg: Dictionary) -> void:
	_fresh()
	stage_floor = 0
	st.playthrough_seed = int(cfg["seed"])
	var order: Array[String] = []
	order.assign(cfg["order"] as Array)
	var shift := int(cfg.get("shift", 0))
	var note := "order %s" % [order]
	_gate_to_the_house(bool(cfg.get("strike", false)))
	_check_stage(note)
	_calls()
	var extras: Array[String] = []
	extras.assign(cfg.get("extras", []) as Array)
	_extras(extras.filter(func(x: String) -> bool: return x != "wisp_tales" and x != "wisp_fight") as Array[String])
	if str(cfg["seance"]) in ["start", "start_part"]:
		_go(FIRST)
		_expect_gates("%s before the board" % note)
		# in full: the hag, the six, the door (then his son is asked after); in part: only who he is and where the couple is (his last word is
		# the six keepsakes, and the door is not named)
		var early: Array[String] = ["Who are you?", "Where are Phillip"]
		if cfg["seance"] == "start":
			early.append_array(["Who is behind all of this?", "How do we get out of here", "Where is the door to the attic?"])
		_seance(early)
		assert_eq(bool(st.get_flag("trapdoor_known")), cfg["seance"] == "start", "%s: the board names the door only when asked" % note)
		_expect_gates("%s after the board" % note)
		_check_stage(note)
	for w: String in ["wisp_tales", "wisp_fight"]:
		if extras.has(w):
			_extras([w] as Array[String])
	for i in order.size():
		var m := order[i]
		var ways: Array[String] = []
		match m:
			"key":
				ways.assign(KEY_WAYS)
			"cup":
				ways.assign(CUP_WAYS)
			"doll":
				ways.assign(DOLL_WAYS)
			"bear":
				ways.assign(BEAR_WAYS)
			"pin":
				ways.assign(PIN_WAYS)
			_:
				ways.assign(["peacock"])
		var way := ways[(i + shift) % ways.size()]
		if way in ["both", "persuade_miss_both"] and not (_have("doll") and _have("bear")):
			way = "persuade"
		_go(str(FLOOR_OF[m]))
		_expect_gates("%s before %s" % [note, m])
		_acquire(m, way, shift)
		_calls()
		_expect_gates("%s after %s (%s)" % [note, m, way])
		_check_stage("%s after %s" % [note, m])
		if m == "pin" and str(cfg["hatch"]) == "roar":
			_open_hatch("roar")
			_check_stage(note)
		if i == 2 and int(cfg.get("reload", -1)) >= 0:
			_reload()
		if i == 3 and str(cfg["jasper"]) != "none":
			_go(SECOND)
			var out := _use_prop("h12_bed", [], str(cfg["jasper"]) == "kill")
			assert_eq(str(out.get("fight", "")), "ch_jasper", "the bed starts Jasper's fight")
			if str(cfg["jasper"]) == "flee":
				st.set_flag("jasper_fled")   # he withdrew below 16 Hit Points (the fight's own withdraw) and the party won the rest
				_win("ch_jasper")
			_calls()
			_expect_gates("%s after Jasper" % note)
	for m: String in MEMENTOS:
		assert_true(_have(m), "%s: all six are in the pack (%s)" % [note, m])
	# every floor's apparition has played, whichever order the mementos came in
	for floor_id: String in [FIRST, SECOND, THIRD]:
		_go(floor_id)
		_calls()
	for f: String in ["crooked_man_seen_1", "crooked_man_seen_2", "crooked_man_seen_3"]:
		assert_true(bool(st.get_flag(f)), "%s: %s played" % [note, f])
	assert_eq(apparitions.size(), 3, "%s: one apparition on each floor, no more" % note)
	if str(cfg["seance"]) in ["late_full", "late_part"]:
		var asks: Array[String] = []
		if cfg["seance"] == "late_full":
			asks.assign(SEANCE_ASKS)
		else:
			asks.assign(["Who are you?", "Where are Phillip", "Who is behind all of this?", "How do we get out of here", "Who is the grey cat?", "What is Shuck"])
		_seance(asks)
		assert_eq(bool(st.get_flag("patrini_asked_find_son")), cfg["seance"] == "late_full", "%s: Patrini's son is asked after only when nothing was missed" % note)
	if str(cfg["hatch"]) != "roar":
		_open_hatch(str(cfg["hatch"]))
	_check_stage(note)
	_go(THIRD)
	assert_true(_exit_open("up_to_attic"), "%s: the ladder is open" % note)
	var placing: Array[String] = []
	placing.assign(cfg["place"] as Array)
	_place_all(placing, int(cfg.get("reload", -1)))
	_check_stage(note)
	var spec := _confront(str(cfg["vessla"]))
	_win_spec(spec, "ch_vessla")
	_unbend()
	_check_stage(note)
	if bool(st.get_flag("patrini_asked_find_son")):
		assert_true(not _npc_here("old_rusty").is_empty(), "%s: Old Rusty waits on the estate road" % note)
		_talk("old_rusty", ["Say the name aloud"])
		assert_eq(st.quest_stage("find_my_son"), "told")
	assert_eq(_stage(), "done", "%s: the Crooked House ends in success" % note)


# --- The tests -------------------------------------------------------------------------------------------------------------------


func test_the_spine_from_the_gate_to_the_unbent_house() -> void:
	_run_order({"order": MEMENTOS, "seance": "late_full", "hatch": "seance", "seed": 1, "place": MEMENTOS, "reload": -1, "jasper": "none",
		"vessla": "kneel", "shift": 0})


## Eight orders: the seance early, late, in part or never; every way up; a save in the middle; Jasper killed, driven off or not met.
func _orders() -> Array[Dictionary]:
	return [
		{"order": _shuffled(11), "seance": "none", "hatch": "search", "seed": 2, "shift": 1, "place": _shuffled(31), "reload": 3, "jasper": "none",
			"vessla": "seen_from_afar", "extras": ["feast", "portraits"]},
		{"order": _shuffled(12), "seance": "start", "hatch": "seance", "seed": 3, "shift": 2, "place": _shuffled(32), "reload": -1, "jasper": "kill",
			"vessla": "tooth", "extras": ["clock", "paintings"]},
		{"order": _shuffled(13), "seance": "late_full", "hatch": "seance", "seed": 4, "shift": 3, "place": _shuffled(33), "reload": 5, "jasper": "flee",
			"vessla": "tooth_talk_cut", "extras": ["bath", "wisp_tales"]},
		{"order": _shuffled(14), "seance": "none", "hatch": "hearth_perception", "seed": 5, "shift": 4, "place": _shuffled(34), "reload": 1, "jasper": "none",
			"vessla": "kneel", "strike": true},
		{"order": _shuffled(15), "seance": "start_part", "hatch": "hearth_investigation", "seed": 6, "shift": 5, "place": _shuffled(35), "reload": 2,
			"jasper": "flee", "vessla": "seen_up_close", "extras": ["wisp_fight"]},
		{"order": _shuffled(16), "seance": "late_part", "hatch": "seance", "seed": 7, "shift": 0, "place": _shuffled(36), "reload": -1, "jasper": "kill",
			"vessla": "missed_then_kneel"},
		{"order": _shuffled(17), "seance": "none", "hatch": "roar", "seed": 8, "shift": 2, "place": _shuffled(37), "reload": 4, "jasper": "none",
			"vessla": "phillip_first", "extras": ["wisp_tales"]},
		{"order": _shuffled(18), "seance": "start", "hatch": "seance", "seed": 9, "shift": 3, "place": _shuffled(38), "reload": 6, "jasper": "flee",
			"vessla": "tooth_cut_talk", "extras": ["feast", "clock"]},
	]


func test_the_six_mementos_in_eight_seeded_orders() -> void:
	var seen: Array[String] = []
	for cfg: Dictionary in _orders():
		var key := str(cfg["order"])
		assert_true(not seen.has(key), "the orders differ: %s" % key)
		seen.append(key)
		_run_order(cfg)


# --- Helpers for the single routes -----------------------------------------------------------------------------------------------


## A house with the storm shut behind the party, at `place`, a new story.
func _inside(place: String = FIRST, ids: Array[String] = PARTY) -> void:
	_fresh(ids)
	stage_floor = 0
	st.set_flag("crooked_house_turned")
	st.set_flag("crooked_man_met")
	st.set_quest_stage("the_crooked_house", "trapped")
	_arrive(place)


## The lines of the menu a conversation stands at after `picks` (the enabled options' texts), without choosing from it; [] if it ends first.
func _menu(ref: String, picks: Array[String] = []) -> Array[String]:
	var r := TraceRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	var out: Array[String] = []
	for i in 400:
		match str(b["kind"]):
			"end":
				return out
			"options":
				while not left.is_empty() and str(left[0]).begins_with("@"):
					r.dice = LowDice.new() if str(left.pop_front()) == "@low" else HighDice.new()
				var opts := b["options"] as Array
				if left.is_empty():
					for o: Variant in opts:
						if bool((o as Dictionary)["enabled"]):
							out.append(str((o as Dictionary)["text"]))
					return out
				var want := str(left.pop_front())
				var pick := -1
				for j in opts.size():
					if bool((opts[j] as Dictionary)["enabled"]) and str((opts[j] as Dictionary)["text"]).contains(want):
						pick = j
						break
				assert_true(pick >= 0, "%s: no option '%s'" % [ref, want])
				if pick < 0:
					return out
				b = r.choose(pick)
			"guidance":
				b = r.answer_guidance(-1)
			_:
				b = r.next()
	return out


func _has(lines: Array[String], part: String) -> bool:
	return lines.any(func(l: String) -> bool: return l.contains(part))


# --- (3) Each memento's second way and failure branch ---------------------------------------------------------------------------------


func test_the_harpsichord_a_miss_is_spent_the_calling_is_not_and_patience_needs_no_roll() -> void:
	_inside(FIRST)
	_trigger("enter_area:h5_floor")
	var ref := "crooked_house/patrini_lament:harpsichord"
	var menu := _menu(ref)
	for part: String in ["Sit at the bench", "Ask the dead servant", "Draw upon the lingering music", "Wait quietly", "Leave the instrument"]:
		assert_true(_has(menu, part), "the harpsichord offers: %s" % part)
	var t0 := st.total_minutes()
	_use_prop("h5_harpsichord", ["@low", "Sit at the bench"] as Array[String])
	assert_true(st.total_minutes() - t0 >= 10, "a failed Performance costs ten minutes of the night")
	assert_true(not bool(st.get_flag("memento_key")), "and no key")
	menu = _menu(ref)
	assert_true(not _has(menu, "Sit at the bench"), "a failed Performance is spent: it is not offered again")
	assert_true(_has(menu, "Ask the dead servant") and _has(menu, "Draw upon the lingering music"), "the calling is still there")
	_use_prop("h5_harpsichord", ["@low", "Ask the dead servant"] as Array[String])
	_use_prop("h5_harpsichord", ["@low", "Draw upon the lingering music"] as Array[String])
	menu = _menu(ref)
	assert_true(_has(menu, "Ask the dead servant") and _has(menu, "Draw upon the lingering music"), "a missed calling can be tried again, without limit")
	assert_true(not bool(st.get_flag("memento_key")), "still no key")
	t0 = st.total_minutes()
	_use_prop("h5_harpsichord", ["Wait quietly"] as Array[String])
	assert_true(st.total_minutes() - t0 >= 60, "an hour of waiting")
	assert_true(bool(st.get_flag("memento_key")) and _have("key"), "and the tune comes without a roll")
	assert_eq(_menu(ref), [] as Array[String], "afterwards the harpsichord is played out")
	assert_eq(_stage(), "mementos", "the first keepsake moves the quest on")


func test_the_cup_by_persuasion_by_both_keepsakes_and_by_threat() -> void:
	var ref := "crooked_house/petunia:start"
	# a missed appeal is spent; both keepsakes need no roll
	_inside(FIRST)
	_talk("petunia_lockwood", ["@low", "Ask after her children", "Speak gently of Sally"])
	assert_eq(st.quest_stage("petunias_cup"), "refused", "the cup is refused")
	assert_true(not bool(st.get_flag("memento_cup")))
	assert_true(not _has(_menu(ref, ["Ask after her children"]), "Speak gently of Sally"), "a failed appeal is spent")
	assert_true(not _has(_menu(ref), "Set the doll and the bear"), "no doll and bear to show her yet")
	st.gain_item("memento_wooden_doll", 1, st.party[0])
	assert_true(not _has(_menu(ref), "Set the doll and the bear"), "the doll alone is not enough")
	st.gain_item("memento_blue_bear", 1, st.party[0])
	assert_true(_has(_menu(ref), "Set the doll and the bear"), "the doll and the bear together are")
	_talk("petunia_lockwood", ["@low", "Set the doll and the bear"])
	assert_true(bool(st.get_flag("memento_cup")) and bool(st.get_flag("petunia_at_peace")) and _have("cup"), "both keepsakes win the cup on the worst dice")
	assert_true(_have("doll") and _have("bear"), "and the keepsakes are not taken")
	assert_eq(st.quest_stage("petunias_cup"), "peace")
	_use_prop("h8_cup", ["Pick up the green ribbon"])
	assert_true(st.party_has_item("green_ribbon") and bool(st.get_flag("green_ribbon_found")), "the ribbon on the chair")
	assert_true(not _has(_menu("crooked_house/petunia:cup"), "Pick up the green ribbon"), "and only once")
	# a threat is a fight, and the cup is left on the tiles; talking to her again before it is won is the same fight
	_inside(FIRST)
	var ended := _talk("petunia_lockwood", ["Tell her you mean to have that cup"], false)
	assert_eq(str(ended.get("combat", "")), "ch_petunia", "a threat starts her fight")
	assert_eq(st.attitude("petunia_lockwood"), "hostile")
	ended = _talk("petunia_lockwood", [], false)
	assert_eq(str(ended.get("combat", "")), "ch_petunia", "she is hostile until she falls")
	_win("ch_petunia")
	assert_true(bool(st.get_flag("petunia_destroyed")) and not bool(st.get_flag("memento_cup")), "the cup waits on the tiles")
	assert_true(_npc_here("petunia_lockwood").is_empty(), "she is gone from the chair")
	_calls({"h8_cup": ["Pick up the green ribbon"] as Array[String]})
	assert_true(bool(st.get_flag("memento_cup")) and _have("cup") and st.party_has_item("green_ribbon"), "the cup and the ribbon")
	assert_eq(st.quest_stage("petunias_cup"), "destroyed")
	# taking it from her hands while she lives is the same
	_inside(FIRST)
	var out := _use_prop("h8_cup", ["Take it out of her hands"], false)
	assert_eq(str(out.get("combat", "")), "ch_petunia", "grabbing the cup starts her fight")
	_win("ch_petunia")
	# her small talk and a long look
	_inside(FIRST)
	_talk("petunia_lockwood", ["Who are you?", "What are you holding?", "What happened in this house?", "Look past the manners", "@low", "Look past the manners"])
	_talk("petunia_lockwood", ["Ask after her children", "Say no more of it"])
	assert_eq(st.quest_stage("petunias_cup"), "met")


func test_the_doll_by_the_lurker_found_at_its_place_and_by_six_searches() -> void:
	var found_at: Array[int] = []
	for seed_value in range(1, 15):
		_inside(SECOND)
		st.playthrough_seed = seed_value
		_get_doll("found")
		found_at.append(CrookedMoonCampaign.lurker_spot(seed_value))
	for n in range(1, 7):
		assert_true(found_at.has(n), "some seed hides it in place %d and the walk finds it there" % n)
	# six searches, with the place it hides searched first, in the middle and last
	var seeded_at := {}
	for n in range(0, 60):
		_inside(SECOND)
		var spot := CrookedMoonCampaign.LURKER_SPOTS[CrookedMoonCampaign.lurker_spot(st.playthrough_seed) - 1]
		var index := _spot_order(n).find(spot)
		if seeded_at.has(index):
			continue
		seeded_at[index] = n
		_get_doll("six", n)
	assert_true(seeded_at.has(0) and seeded_at.has(5), "the hiding place was searched first once and last once")
	# the first hero misses the place it hides and the next finds it: found, not an ambush
	_inside(SECOND)
	var at := str(CrookedMoonCampaign.LURKER_SPOTS[CrookedMoonCampaign.lurker_spot(st.playthrough_seed) - 1])
	var miss := _world_check(at, at, LowDice.new())
	assert_true(not bool(miss["success"]) and str(miss["fight"]) == "", "a miss starts nothing while the others are unsearched")
	assert_true(st.party_has_item("human_tooth"), "the house leaves a tooth")
	var hit := _world_check(at, at, HighDice.new())
	assert_eq(str(hit["fight"]), "ch_lurker", "someone else finds it there")
	assert_eq(str((hit["spec"] as Dictionary).get("surprise", "")), "", "found, nobody surprised")
	# Sally: asking before and after
	var ref := "crooked_house/sally_doll:start"
	_inside(SECOND)
	assert_true(_has(_menu(ref), "We will check every corner"), "she asks first")
	_use_prop("h10_doll", ["Who are you?", "What is hiding in here?", "We will check every corner"])
	assert_eq(st.quest_stage("sallys_monsters"), "hiding")
	_use_prop("h10_doll")   # back again: her second greeting
	assert_true(not _has(_menu(ref), "The monster is gone"), "the monster is not gone yet")
	st.set_quest_stage("sallys_monsters", "lurker_dead")
	_use_prop("h10_doll", ["Not just yet"])
	assert_true(not bool(st.get_flag("sally_rested")), "not yet")
	_use_prop("h10_doll", ["The monster is gone"])
	assert_true(bool(st.get_flag("sally_rested")) and _have("doll"))
	_use_prop("h10_doll")   # an empty room
	assert_eq(_count("memento_wooden_doll"), 1, "she is not asked twice for the doll")


func test_the_bear_whether_or_not_arthur_is_calmed() -> void:
	for way in BEAR_WAYS:
		_inside(THIRD)
		if way == "lullaby":
			st.set_flag("memento_key")   # the lament was heard
		_get_bear(way)
		assert_true(_have("bear"), "%s: the bear is the memento" % way)
		assert_eq(bool(st.get_flag("arthur_rested")), way != "ignore", "%s: Arthur" % way)
	# a lullaby: DC 10 with the lament in the ears, DC 15 without
	var ref := "crooked_house/arthur:start"
	_inside(THIRD)
	st.party[0].add_item("memento_blue_bear", 1)
	var plain := _menu(ref)
	assert_true(_has(plain, "Sing him a lullaby") and not _has(plain, "harpsichord's lament"), "without the lament: the plain lullaby")
	st.set_flag("memento_key")
	var lament := _menu(ref)
	assert_true(_has(lament, "harpsichord's lament") and not _has(lament, "Sing him a lullaby"), "with the lament: the harpsichord's tune")
	# a missed Persuasion is spent, a missed lullaby is spent too, and the patient way is open all the time
	_talk("arthur_lockwood", ["@low", "Speak low and steady", "Sing him the harpsichord's lament"])
	var after := _menu(ref)
	assert_true(not _has(after, "Speak low and steady") and not _has(after, "harpsichord's lament"), "both misses are spent")
	assert_true(_has(after, "Sit down with him"), "an hour's sitting is still there")
	_talk("arthur_lockwood", ["Sit down with him"])
	assert_true(bool(st.get_flag("arthur_rested")))
	assert_eq(st.quest_stage("arthurs_bear"), "asleep")


func test_the_pin_through_the_bear_and_the_roar_that_gives_it_away() -> void:
	for way in PIN_WAYS:
		_inside(THIRD)
		_get_pin(way)
		assert_true(_have("pin"))
	# the bear's look: a miss reads nothing, the pin is still there to cut free
	_inside(THIRD)
	_use_prop("h15_bear", ["@low", "Look past the roar", "Cut the stitches"])
	assert_true(_have("pin"))
	# the roar fight is the trapdoor's: it needs no bear, and the bear needs no roar
	_inside(THIRD)
	assert_true(_search_for("h15_trapdoor"))
	var spec := _trigger("examine:h15_trapdoor", false)
	assert_eq(str(spec["id"]), "ch_roar")
	assert_eq((spec["round_events"] as Array).size(), 5, "the roar climbs and Gail gives the bear away")
	_get_pin("cut")
	assert_true(not bool(st.get_flag("trapdoor_known")), "the pin does not open the hatch")


# --- The ladder ------------------------------------------------------------------------------------------------------------------


func test_the_attic_ladder_shut_until_one_of_its_ways_is_taken() -> void:
	for way: String in ["search", "hearth_perception", "hearth_investigation", "roar"]:
		_inside(THIRD)
		_open_hatch(way)
		assert_eq(_stage(), "attic", "%s: the ladder moves the quest to the attic" % way)
		assert_true(fights.has("ch_roar"), "%s: the ring starts the roar" % way)
	# the board's answer opens it without the roar, and the roar is still there to be had
	_inside(FIRST)
	assert_true(not _exit_open("up_to_attic", THIRD))
	_seance(["Where are Phillip", "Who is behind all of this?", "Where is the door to the attic?"] as Array[String])
	assert_true(bool(st.get_flag("trapdoor_known")) and not bool(st.get_flag("seance_asked_5")), "the answer names the door without the rest being asked")
	assert_eq(_stage(), "attic", "and the quest moves on")
	assert_true(_exit_open("up_to_attic", THIRD), "the hatch is open")
	_open_hatch("seance")
	assert_true(not fights.has("ch_roar"), "with no roar")
	# its last word does too, when only the door was missed
	_inside(FIRST)
	_seance(["Where are Phillip", "Who is behind all of this?", "How do we get out of here"] as Array[String])
	assert_true(bool(st.get_flag("trapdoor_known")), "the last word names the door when the rest was asked")
	# a party that asked nothing of the board is told the six keepsakes, then the hag, then the door, in that order
	for asked: Array in [[], ["Where are Phillip"], ["Where are Phillip", "Who is behind all of this?"],
			["Where are Phillip", "Who is behind all of this?", "How do we get out of here"]]:
		_inside(FIRST)
		var picks: Array[String] = []
		picks.assign(asked)
		_seance(picks)
		assert_eq(bool(st.get_flag("trapdoor_known")), asked.size() == 3, "%s: the last word" % [asked])
	# nothing opens it but a way: the ceiling is plaster
	_inside(THIRD)
	st.set_flag("memento_bear")
	st.set_flag("memento_pin")
	assert_true(not _exit_open("up_to_attic"), "the third floor's keepsakes do not open the ceiling")
	var locked := str(_entry("exits", "id", "up_to_attic").get("locked_text", ""))
	assert_true(locked != "", "and the shut hatch says why")


func test_the_seance_on_the_worst_dice_stings_more_each_time_and_closes_for_good() -> void:
	_inside(FIRST)
	dice = LowDice.new()
	st.visited[SECOND] = true
	st.visited[THIRD] = true
	var everything: Array[String] = ["Recall how a sitting", "Lay our fingertips"]
	everything.append_array(SEANCE_ASKS)
	_use_prop("h3_spirit_board", everything)
	assert_true(int(st.get_flag("seance_stings")) >= 5, "eight cold answers, eight bites at least five deep")
	assert_true(bool(st.get_flag("seance_done")), "his last word is said")
	_use_prop("h3_spirit_board")   # the dead board
	assert_true(_menu("crooked_house/seance:start").is_empty(), "the board is deaf and dumb")
	_inside(FIRST)
	_use_prop("h3_spirit_board", ["@high", "Recall how a sitting", "Leave the board alone"] as Array[String])
	_use_prop("h3_spirit_board", ["Lay our fingertips", "That is enough", "Wait. Let us ask something else", "Who are you?", "That is enough", "Let him go"] as Array[String])
	assert_true(bool(st.get_flag("seance_done")))


# --- (4) The boss: three versions, Jasper, the last word ---------------------------------------------------------------------------


func _ward_down() -> void:
	_inside(ATTIC)
	st.set_flag("mementos_placed", 6)
	st.set_quest_stage("the_crooked_house", "vessla")
	for m: String in MEMENTOS:
		st.set_flag(str(FLAG[m]))
		st.set_flag("%s_placed" % str(FLAG[m]))


func test_vessla_every_way_in_picks_the_version_and_jasper_comes_only_if_he_fled() -> void:
	var ways: Array[String] = ["kneel", "seen_from_afar", "seen_up_close", "missed_then_kneel", "missed_close_then_help", "phillip_first",
		"tooth", "tooth_talk_cut", "tooth_cut_talk", "lore_missed_then_seen"]
	for fled: bool in [false, true]:
		for way: String in ways:
			_ward_down()
			if fled:
				st.set_flag("jasper_fled")
			var spec := _confront(way)
			_win_spec(spec, "ch_vessla")
			assert_true(bool(st.get_flag("vessla_slain")), "%s: the hag falls" % way)
			assert_eq(_stage(), "done", "%s: the fight ends the quest" % way)
			assert_true(_exit_open("to_estate", FIRST), "%s: and the porch exit opens" % way)
	# the three versions as the party meets them
	_ward_down()
	assert_eq(str(_spec("ch_vessla").get("surprise", "")), "party", "a party that walks up to the woman on the floor is surprised")
	st.set_flag("vessla_ruse_seen")
	assert_eq(str(_spec("ch_vessla").get("surprise", "")), "", "seen through: neither side is")
	st.set_flag("vessla_tooth_gift")
	assert_eq(str(_spec("ch_vessla").get("surprise", "")), "enemies", "the tooth wins over the ruse: she is dazed")
	# the other two people in the room
	_ward_down()
	_talk("phillip_druskenvald", ["Kneel beside the fallen woman", "Take her hand"], false)
	_ward_down()
	_talk("adela_druskenvald", ["Go to Phillip by the cauldron", "Kneel beside the fallen woman", "Take her hand"], false)
	_ward_down()
	_talk("adela_druskenvald_ruse", ["Kneel beside the fallen woman", "Ask what happened to her", "Step back from her", "Go to Phillip by the cauldron",
		"Kneel beside the fallen woman", "@low", "Watch how she holds herself", "Take her hand"], false)
	# the last word, called alone as the house plays it, and the thanks that pay once
	_ward_down()
	st.set_flag("vessla_slain")
	_unbend_alone()


## After the hag, with nothing else done: Phillip's talk through to the thanks, level 4 and the purse paid once.
func _unbend_alone() -> void:
	var gold := st.gold
	var ended := _talk("phillip_druskenvald", [])
	assert_true(ended.has("kind"), "his last-word talk ends")
	assert_true(bool(st.get_flag("druskenvald_manor_restored")))
	assert_eq(st.milestones, 3)
	assert_eq(st.gold, gold + 300.0)
	assert_eq(_stage(), "done")


# --- (5) The porch steps, the porch exit and a save made inside the house -----------------------------------------------------------


func test_the_porch_steps_and_the_porch_exit_in_every_flag_state_and_from_a_save_made_inside() -> void:
	# [flags, the estate's steps open, the first floor's way down open]
	var cases: Array[Array] = [
		[{}, false, true],
		[{"crooked_house_turned": true}, false, false],
		[{"crooked_house_turned": true, "crooked_man_met": true}, true, false],
		[{"crooked_house_turned": true, "crooked_man_met": true, "vessla_slain": true}, true, true],
		[{"crooked_house_turned": true, "crooked_man_met": true, "vessla_slain": true, "druskenvald_manor_restored": true}, true, true],
	]
	for c: Array in cases:
		_fresh()
		for k: String in c[0]:
			st.set_flag(k, c[0][k])
		assert_eq(_exit_open("porch_steps", ESTATE), c[1], "%s: the estate's steps" % [c[0]])
		assert_eq(_exit_open("to_estate", FIRST), c[2], "%s: the porch exit" % [c[0]])
	# in the house: shut, and shut after a save is loaded, then open once the hag falls, and still open after another save
	_fresh()
	_gate_to_the_house()
	assert_true(not _exit_open("to_estate"), "shut in the storm")
	_go(SECOND)
	_reload()
	assert_eq(st.location, SECOND, "the save is made inside the house")
	_go(FIRST)
	assert_true(not _exit_open("to_estate"), "the load keeps it shut")
	assert_true(_exit_open("porch_steps", ESTATE), "the steps stay open on the load")
	# the hag falls in the loaded game, by the board's door and the six placed
	for m: String in MEMENTOS:
		st.party[0].add_item(str(ITEM[m]), 1)
	st.set_flag("trapdoor_known")
	_place_all(MEMENTOS)
	_reload()
	_go(ATTIC)
	var spec := _confront("kneel")
	_win_spec(spec, "ch_vessla")
	_reload()
	_go(FIRST)
	assert_true(_exit_open("to_estate"), "from a save made inside, the exit opens when the hag falls")
	_exit("to_estate")
	assert_eq(st.location, ESTATE)
	_reload()
	assert_true(_exit_open("porch_steps"), "and the steps still stand open on the next load")
	assert_true(not _npc_here("gilly_jenkin").is_empty(), "the Jenkins are back at the gate")
	assert_true(_npc_here("crooked_man").is_empty())


# --- The talks the spine does not take -----------------------------------------------------------------------------------------------


func test_the_gate_the_porch_and_the_apparitions_in_their_other_branches() -> void:
	# Walter, read and not read; the Crooked Man read and not read, struck at; the apparitions' three menu lines on each floor
	_fresh()
	_on_the_hill()
	_talk("gilly_jenkin", ["@low", "Walter seems on edge", "We'll go up to the house"])
	_talk("crooked_man", ["@low", "Study him closely", "Feel the air", "@high", "Feel the air", "Strike at him"])
	assert_eq(_stage(), "trapped", "a blow ends in the storm all the same")
	_fresh()
	_gate_to_the_house(true)
	_fresh()
	_on_the_hill()
	_talk("gilly_jenkin", ["We'll go up to the house"])
	_talk("crooked_man", ["@high", "Study him closely", "Feel the air", "Go inside"])
	assert_eq(_stage(), "trapped")
	# a conversation node that can also be played alone: the cat and the turn
	_fresh()
	_play("crooked_house/jenkins_gate:after")
	assert_true(bool(st.get_flag("crooked_house_turned")), "the turn can be played from its own node")
	var wants: Array[String] = ["What do you want from us?", "Strike at", "Stand and wait"]
	for i in 3:
		_inside(FIRST)
		_play("crooked_house/crooked_man:floor1", [wants[i]] as Array[String])
		_play("crooked_house/crooked_man:floor2", [wants[i]] as Array[String])
		_play("crooked_house/crooked_man:floor3", [wants[i]] as Array[String])
		_play("crooked_house/crooked_man:floor1")   # he plays once: a second call is nothing
		assert_true(bool(st.get_flag("crooked_man_seen_1")) and bool(st.get_flag("crooked_man_seen_2")) and bool(st.get_flag("crooked_man_seen_3")))


func test_the_portraits_the_paintings_gail_and_the_foyer_curse() -> void:
	for dice_kind: String in ["high", "low"]:
		_inside(FIRST)
		dice = HighDice.new() if dice_kind == "high" else LowDice.new()
		for p: String in ["h2_portrait_lockwood", "h2_portrait_druskenvald", "h2_portrait_party"]:
			var plaque: Array[String] = []
			if p == "h2_portrait_lockwood":
				plaque = ["Read the brass plaque"]
			_use_prop(p, plaque)
			_use_prop(p, plaque)
		assert_eq(int(st.get_flag("portrait_cursed", 0)), 0 if dice_kind == "high" else 3, "%s dice: the painted stares" % dice_kind)
	_inside(FIRST)
	_use_prop("h4_paintings", ["@low", "Look closer at the painted skies", "@high", "Look closer at the painted skies"] as Array[String])
	_use_prop("h4_peacock", [] as Array[String])
	_calls()   # Keziah's farewell at the rubble
	# Gail: the look with a hit and a miss, the cut, the empty nest
	_inside(THIRD)
	_use_prop("h15_bear", ["@high", "Look past the roar", "@low", "Look past the roar", "Step back from the bear"] as Array[String])
	assert_true(not _have("pin"))
	_use_prop("h15_bear", ["Cut the stitches"] as Array[String])
	_use_prop("h15_bear")


func test_wisp_every_tale_every_miss_the_threat_the_fight_and_the_refusal() -> void:
	# run A: a miss in History, then Performance; Performance missed (spent), History; a History miss and a Performance miss, then History
	_inside(THIRD)
	_talk("wisp", ["Who are you?", "Why do you sound like that?", "What do you want from us?", "@low", "Study him closely", "Pose him a riddle", "@high",
		"Tell him a tale",
		"@low", "Tell the old tale of a siege", "@high", "Tell a ghost story",
		"@low", "Act out a comic tale", "Tell the tale of a king's lost crown", "@high", "Tell the tale of a king's lost crown",
		"@low", "Tell how a town came by its name", "Sing a long ballad", "@high", "Tell how a town came by its name"])
	assert_eq(st.quest_stage("a_tale_for_wisp"), "thanked")
	# run B: Performance missed, History; History missed, Performance; Performance; the riddle read through
	_inside(THIRD)
	_talk("wisp", ["@high", "Pose him a riddle", "Tell him a tale",
		"@low", "Tell a ghost story", "@high", "Tell the old tale of a siege",
		"@low", "Tell the tale of a king's lost crown", "@high", "Act out a comic tale",
		"@high", "Sing a long ballad"])
	assert_true(bool(st.get_flag("wisp_exposed")), "the riddle told the truth")
	assert_eq(int(st.get_flag("wisp_tales")), 3)
	# the cat read through by a look
	_inside(THIRD)
	_talk("wisp", ["@high", "Study him closely", "Not just now"])
	assert_true(bool(st.get_flag("wisp_exposed")))
	# the refusal, the return and the threat
	_inside(THIRD)
	_talk("wisp", ["We want no part"])
	assert_eq(st.quest_stage("a_tale_for_wisp"), "refused")
	_talk("wisp", ["Tell him a tale", "Take it back for now", "Not just now"])
	_inside(THIRD)
	_talk("wisp", ["Warn the cat"])
	assert_eq(st.quest_stage("a_tale_for_wisp"), "fled")
	assert_true(_npc_here("wisp").is_empty(), "he leaves by the window")
	# a conversation left at the fight he starts (he is hostile until he falls)
	_inside(THIRD)
	var ended := _talk("wisp", ["Draw a weapon"], false)
	assert_eq(str(ended.get("combat", "")), "ch_wisp")
	ended = _talk("wisp", [], false)
	assert_eq(str(ended.get("combat", "")), "ch_wisp", "hostile until he falls")


func test_the_companions_beats_and_the_custom_heros_stubs() -> void:
	# each companion's beat, with each of its three answers; every prop's call plays once and the room is then done
	var beats: Array = [
		["h3_crystal_ball", FIRST, "incitement_pilgrimage", ["What are the spirits telling you", "Hand on the glass", "Leave it. We need a way out"]],
		["h8_bergamot", FIRST, "incitement_rejuvenation", ["What did that tree just show you", "Your hand shook", "Leave the tree"]],
		["h15_trophy_crow", THIRD, "incitement_slaughter", ["What's your hound pointing at", "Did your omen of death", "Leave the mounts"]],
	]
	for b: Array in beats:
		for pick: String in b[3]:
			_inside(str(b[1]))
			var out := _called_by(str(b[0]), [pick] as Array[String])
			assert_true(out.has("kind"), "%s: %s ends" % [b[0], pick])
			assert_true(bool(st.get_flag(str(b[2]))), "%s: %s sets %s" % [b[0], pick, b[2]])
			assert_true(not _holds(_entry("props", "id", str(b[0])).get("call_when")), "and the beat is done")
	# without the companion the beat is only noted for the camp, and the flag the home scene reads stays down
	for b: Array in beats:
		_inside(str(b[1]), ["silas_vane", "hedda_ironvow", "ilse_varga", "tamsin_tealeaf"] as Array[String])
		_called_by(str(b[0]))
		assert_true(not bool(st.get_flag(str(b[2]))), "%s: no companion, no beat" % b[0])
		assert_true(bool(st.get_flag(str(b[2]).replace("incitement_", "pending_") + "_incitement")), "%s: noted for the camp" % b[0])
	# the custom hero's stubs: the right background gets its own lines, anyone else the prop's plain look
	var stubs: Array = [
		["h5_mirror", FIRST, "incitement_duality", "reflected_wanderer", ["Ask the reflection", "Smash the cracked glass", "Turn my back"]],
		["h17_cauldron", ATTIC, "incitement_immortality", "crimson_aspirant", ["Etch the pale soul-glyphs", "Ask the being in the flask", "Cork the vessel"]],
		["h12_scratchings", SECOND, "incitement_kindred", "druskenvald_dweller", ["Read the scratched nightmares", "Trace the last line", "Leave the plaster wall"]],
		["h14_tome", THIRD, "incitement_malediction", "scholar_of_the_forbidden", ["Lay my stolen page", "Study the margin notes", "Shut the heavy tome"]],
		["h4_bust", FIRST, "incitement_rapture", "cultist", ["Read the missionary's plaque", "Bow my head", "Walk on through the gallery"]],
	]
	for b: Array in stubs:
		for pick: String in b[4]:
			_inside(str(b[1]))
			st.party[3].build["background"] = str(b[3])
			_called_by(str(b[0]), [pick] as Array[String])
			assert_true(bool(st.get_flag(str(b[2]))), "%s: %s" % [b[0], pick])
		_inside(str(b[1]))
		_called_by(str(b[0]))
		assert_true(not bool(st.get_flag(str(b[2]))), "%s: another hero gets the plain look" % b[0])


func test_the_village_errand_and_the_jenkins_come_home() -> void:
	# the board's last word asks after Joseph Patrini's son; Old Rusty on the estate road hears his name
	_inside(FIRST)
	st.visited[SECOND] = true
	st.visited[THIRD] = true
	_seance(SEANCE_ASKS)
	assert_true(bool(st.get_flag("patrini_asked_find_son")))
	assert_eq(st.quest_stage("find_my_son"), "asked")
	_arrive(ESTATE)
	st.set_flag("vessla_slain")
	assert_true(not _npc_here("old_rusty").is_empty(), "Old Rusty is on the estate road")
	_talk("old_rusty", ["Ask where he was before", "Study the old scar", "@low", "Study the old scar", "Say the name aloud"])
	assert_eq(st.quest_stage("find_my_son"), "told")
	assert_true(_npc_here("old_rusty").is_empty(), "he is told once")
	_play("crooked_house/find_my_son:start", ["Leave him to his sweeping"] as Array[String])   # the village's second call to Rusty: his rhyme
	# the Jenkins in the grounds: with Walter's voice back when Wisp is dead
	for wisp_slain: bool in [false, true]:
		_fresh()
		st.set_flag("crooked_house_turned")
		st.set_flag("vessla_slain")
		st.set_flag("wisp_slain", wisp_slain)
		_arrive(ESTATE)
		_talk("gilly_jenkin", ["The house looks different", "Lord Phillip and Lady Adela are safe", "How is Dani", "Did you notice anything in the grounds",
			"That's all for now"])
		_talk("walter_jenkin")   # Walter's entry plays the same talk: now the second


# --- (6) A wipe in the house: the same fight again from the floor's entry -----------------------------------------------------------


## Where a wipe puts the party back, by floor (the first spawn of the rule's list that the map has).
const ENTRY := {FIRST: "from_porch", SECOND: "from_below", THIRD: "from_below", ATTIC: "from_ladder"}


func test_every_house_fight_is_a_retry_from_its_floors_entry_with_a_line_for_the_narrator() -> void:
	FightRetry.use_table(null)
	_fresh()
	var narrator := Narrator.new()
	var count := 0
	for place: String in HOUSE:
		var loc := _loc_of(place)
		assert_true((loc["spawns"] as Dictionary).has(ENTRY[place]), "%s has its entry %s" % [place, ENTRY[place]])
		var done: Array[String] = []
		for e: Variant in loc.get("encounters", []):
			var spec := e as Dictionary
			var id := str(spec["id"])
			if done.has(id):
				continue
			done.append(id)
			count += 1
			var rule := FightRetry.rule_for(spec, place)
			assert_true(not rule.is_empty(), "a wipe in %s (%s) is a retry, not a game over" % [id, place])
			assert_eq(FightRetry.restart_id(rule, spec), id, "%s: the same fight begins again" % id)
			assert_eq(FightRetry.spawn_for(rule, place, loc), str(ENTRY[place]), "%s: the party goes back to %s" % [id, ENTRY[place]])
			var said := ""
			for key in FightRetry.keys(rule, spec):
				said = narrator.line(key, st)
				if said != "":
					break
			assert_true(said != "", "%s: the Narrator speaks over the retry" % id)
	assert_true(count >= 12, "the house's fights were all seen (%d)" % count)
	# the count of retries rides a flag, and a fight outside the house is still a game over
	assert_eq(str(FightRetry.rule_for({"id": "ch_vessla"}, ATTIC)["count_flag"]), "crooked_house_retries")
	assert_true(not FightRetry.applies({"id": "wm_wolves"}, FIRST))
	GameState.reset()


var root: Node


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Boots the game on `place` with the party and the fight `id`, loses the fight and waits for the retry: the same fight on again at the
## floor's entry, the party on its feet.
func _wipe_on(place: String, id: String, away: Vector2i) -> void:
	_inside(place)
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	assert_true(view != null and view.loc_id == place, "%s: the game is on the floor" % place)
	if view == null:
		return
	for m in view.members:
		m.cell = away   # somewhere else on the floor, so the entry is not where they started
	assert_true(view.start_encounter(id), "%s: the fight starts" % id)
	await _frames(6)
	var cv := view.combat_view
	var first := cv.e
	for ch in st.party:
		ch.hp = 0
	st.party[1].dead = true
	first._check_over()
	assert_eq(first.outcome, "defeat", "%s: the party is down" % id)
	cv.finished.emit("defeat")
	for i in 240:
		await get_tree().process_frame
		if root.get("view") != view and (root.get("view") as LocationView).in_combat:
			break
	var after := root.get("view") as LocationView
	assert_true(after != view and after.in_combat, "%s: the floor is entered again and the fight is on" % id)
	assert_eq(after.fight_id, id, "%s: the same fight" % id)
	var entry_cell := Vector2i(int((after.loc["spawns"] as Dictionary)[ENTRY[place]][0]), int((after.loc["spawns"] as Dictionary)[ENTRY[place]][1]))
	for m in after.members:
		assert_true(maxi(absi(m.cell.x - entry_cell.x), absi(m.cell.y - entry_cell.y)) <= 3, "%s: %s stands at %s, the entry (%s)" % [id, m.creature.name, m.cell, entry_cell])
	for ch in st.party:
		assert_true(not ch.dead and ch.hp == ch.max_hp(), "%s: %s is on their feet with every Hit Point" % [id, ch.name])
	assert_true(int(st.get_flag("crooked_house_retries", 0)) >= 1, "%s: the retry is counted" % id)
	assert_true(not (root.get("screen") is PauseMenu), "%s: no game-over screen" % id)
	root.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_a_wipe_on_each_floor_begins_the_fight_again_at_that_floors_entry() -> void:
	FightRetry.use_table(null)
	await _wipe_on(FIRST, "ch_peacock", Vector2i(20, 20))
	await _wipe_on(SECOND, "ch_clock", Vector2i(15, 15))
	await _wipe_on(THIRD, "ch_quasits", Vector2i(22, 8))
	await _wipe_on(ATTIC, "ch_vessla", Vector2i(8, 15))


# --- (7) Every node ----------------------------------------------------------------------------------------------------------------


func test_every_conversation_node_is_reached_by_some_path_here_or_listed_with_its_reason() -> void:
	TraceRunner.seen.clear()
	var skip: Array[String] = ["test_every_conversation_node_is_reached_by_some_path_here_or_listed_with_its_reason",
		"test_a_wipe_on_each_floor_begins_the_fight_again_at_that_floors_entry"]
	var names: Array[String] = []
	for m: Dictionary in get_method_list():
		var n := str(m["name"])
		if n.begins_with("test_") and not skip.has(n):
			names.append(n)
	names.sort()
	for n in names:
		_fresh()
		call(n)
		GameState.reset()
	var all: Array[String] = []
	var dir := DirAccess.open("res://narrative/crooked_house")
	for f in dir.get_files():
		if f.ends_with(".dialogue"):
			var key := "crooked_house/" + f.get_basename()
			var file := DialogueFile.load_key(key)
			for node: Variant in file.nodes.keys():
				all.append("%s:%s" % [key, node])
	assert_true(all.size() > 250, "the conversations were read (%d nodes)" % all.size())
	var missing: Array[String] = []
	for n in all:
		if not TraceRunner.seen.has(n) and not ALLOWED_UNPLAYED.has(n):
			missing.append(n)
	assert_eq(missing, [] as Array[String], "conversation nodes no path here plays (play them, or list them in ALLOWED_UNPLAYED with the reason)")
	for n: String in ALLOWED_UNPLAYED:
		assert_true(all.has(n), "%s is listed as unplayed but is not a node" % n)
		assert_true(not TraceRunner.seen.has(n), "%s is listed as unplayed but a path here plays it: take it off the list" % n)


# --- Found by the walk, fixed in the same commit ------------------------------------------------------------------------------------


## The board's last word is the first thing the party missed, in the order the questions open: the hag, then the keepsakes, then the
## door, and the hag's disguise (with his son) when nothing was missed. Asking after the keepsakes needs the hag asked first, so a
## party that asked nothing hears about the hag.
func test_the_boards_last_word_names_the_first_thing_missed() -> void:
	var cases: Array[Array] = [
		[[] as Array[String], false, "urgent_hag"],
		[["Where are Phillip"] as Array[String], false, "urgent_hag"],
		[["Where are Phillip", "Who is behind all of this?"] as Array[String], false, "urgent_mementos"],
		[["Where are Phillip", "Who is behind all of this?", "How do we get out of here"] as Array[String], false, "urgent_door"],
		[["Where are Phillip", "Who is behind all of this?", "How do we get out of here"] as Array[String], true, "urgent_face"],
		[["Where are Phillip", "Who is behind all of this?", "How do we get out of here", "Where is the door to the attic?"] as Array[String], false, "urgent_face"],
	]
	for c: Array in cases:
		_inside(FIRST)
		if c[1]:
			st.set_flag("trapdoor_known")
		var from := TraceRunner.log.size()
		_seance(c[0] as Array[String])
		var played := TraceRunner.log.slice(from)
		assert_true(played.has("crooked_house/seance:" + str(c[2])), "asked %s (door known %s): his last word is %s" % [c[0], c[1], c[2]])
		for other: String in ["urgent_hag", "urgent_mementos", "urgent_door", "urgent_face"]:
			if other != str(c[2]):
				assert_true(not played.has("crooked_house/seance:" + other), "asked %s: only one last word is said (%s too)" % [c[0], other])
		assert_true(bool(st.get_flag("seance_done")))
		assert_eq(bool(st.get_flag("patrini_asked_find_son")), str(c[2]) == "urgent_face", "his son is asked after only on the last word of a board that missed nothing")


## Wisp turned down is still in the library, smiling: the quest's failure names the stages it may come back to (`then`), and every one of
## them can be reached from it. (A stage listed before the failure used to be refused as a step back.)
func test_wisp_turned_down_can_still_be_told_tales_driven_off_or_fought() -> void:
	_inside(THIRD)
	_talk("wisp", ["We want no part"])
	assert_eq(st.quest_stage("a_tale_for_wisp"), "refused", "turned down")
	assert_true(not _npc_here("wisp").is_empty(), "he is still in the library")
	_talk("wisp", ["Warn the cat"])
	assert_eq(st.quest_stage("a_tale_for_wisp"), "fled", "a threat drives him out of the window after all")
	assert_true(_npc_here("wisp").is_empty(), "and the desk is bare")
	_inside(THIRD)
	_talk("wisp", ["We want no part"])
	_talk("wisp", ["Tell him a tale", "Tell a ghost story"])
	assert_eq(st.quest_stage("a_tale_for_wisp"), "telling", "a tale after the refusal begins the telling")
	_talk("wisp", ["Tell him a tale", "Act out a comic tale", "Sing a long ballad"])
	assert_eq(st.quest_stage("a_tale_for_wisp"), "thanked", "and three end it in thanks")
	_inside(THIRD)
	_talk("wisp", ["We want no part"])
	_talk("wisp", ["Draw a weapon"])
	assert_eq(st.quest_stage("a_tale_for_wisp"), "slain", "or in his death")


# --- Known and open: a party under level 3 --------------------------------------------------------------------------------------------


## Every fight waits for the lowest hero to be level 3 (the contract's level gate). The toys and the roar have a plain fallback for a
## smaller party; the peacock and the lurker do not, so a party with a hero under level 3 can start neither fight and win neither the
## bloodstone nor the doll (OPEN: R12 needs a fallback version, or the gate dropped, for those two; see the report). This test holds the
## list, so that mending one shrinks it.
const NO_FALLBACK_UNDER_LEVEL_3: Array[String] = ["gem", "doll"]


func test_under_level_three_the_toys_and_the_roar_have_a_fallback_and_the_peacock_and_the_lurker_do_not_yet() -> void:
	_fresh(PARTY, 2)
	st.set_flag("crooked_house_turned")
	st.set_flag("crooked_man_met")
	st.set_quest_stage("the_crooked_house", "trapped")
	var stuck: Array[String] = []
	_arrive(FIRST)
	if _trigger("examine:h4_peacock", false).is_empty():
		stuck.append("gem")
	_arrive(SECOND)
	st.playthrough_seed = 1
	var at := str(CrookedMoonCampaign.LURKER_SPOTS[CrookedMoonCampaign.lurker_spot(1) - 1])
	if _trigger("check:%s:success" % at, false).is_empty():
		stuck.append("doll")
	_arrive(THIRD)
	assert_true(not _trigger("examine:h13_crib", false).is_empty(), "the toys have a plain version for a smaller party")
	assert_true(not _trigger("examine:h15_trapdoor", false).is_empty(), "so does the roar")
	assert_eq(stuck, NO_FALLBACK_UNDER_LEVEL_3, "the keepsakes that cannot be won under level 3 (shrink NO_FALLBACK_UNDER_LEVEL_3 when one is mended)")
