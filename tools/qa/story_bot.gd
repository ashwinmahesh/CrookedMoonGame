extends Node
## The story bot (QA lane): plays the whole campaign from a new game with no script of its own, the way a curious player
## would, over the places' data the way the game reads it: a person is only talked to while their entry's `when` holds,
## a prop's call only fires while its `call_when` does, an exit only opens while its `when` does, a fight walked into
## starts when its `when` holds, the travel map only offers the places it knows, and every conversation runs through
## the DialogueRunner. It is the chapter walks (tests/integration/test_rNN_paths.gd) without their picks: at every menu it
## takes what it has tried least, and in every place it does what it hasn't done since the story last moved.
##
## A fight is won as LocationFights records a victory (its encounter, flag and quest stage); the party's level at each
## one goes to the report, and tools/qa/fight_series.gd then plays those fights at that level. The party levels up when
## the story's milestones allow it (rebuilt from its pregen at the new level, as the quick start builds it).
##
## It stops when the goal quest ends (the last main quest on main), when the game ends, or when the story stops moving:
## nothing new to do anywhere it can reach, after waiting and resting. The report says where it got to, what it saw, and
## where and why it stuck.
##
## Args after --: --out=/abs/story.json [--steps=6000] [--dice=high|seeded] [--seed=1] [--goal=crooked_nightmare]
## [--patience=400] [--trace=1]

const GAME := preload("res://world/game_root.gd")

## Rolls the highest face: every check lands (a walk of the paths the writers meant). --dice=seeded rolls real dice.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var st: StoryState
var dice: DiceRoller
var max_steps := 6000
var patience := 400
var goal := "crooked_nightmare"
var trace_on := false
var out_path := ""

var step := 0
var _tried: Dictionary = {}          ## "sig|action" -> true: done since the story last looked like this
var _opt_count: Dictionary = {}      ## "ref|option text" -> times chosen
var _since_progress := 0
var _last_sig := ""
var _travel_from := ""
var _waits := 0
## What the report collects.
var timeline: Array[Dictionary] = []      ## each main quest's stage as it moved: {step, quest, stage, location, level}
var fights: Array[Dictionary] = []        ## each fight won: {step, loc, id, level, trigger, stage}
var problems: Array[Dictionary] = []      ## {kind, where, detail}
var nodes_seen: Dictionary = {}           ## "file:node" -> true
var talked: Dictionary = {}               ## "loc:npc" -> true
var trace: Array[String] = []
var _problem_keys: Dictionary = {}


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	out_path = str(args.get("out", "user://qa_story.json"))
	max_steps = int(args.get("steps", max_steps))
	patience = int(args.get("patience", patience))
	goal = str(args.get("goal", goal))
	trace_on = str(args.get("trace", "0")) == "1"
	# Never the player's saves or settings: a folder of this process's own, removed at the end (as the test runner does).
	SaveSystem.save_dir = "user://qa_saves/%d/" % OS.get_process_id()
	GameSettings.path = SaveSystem.save_dir.path_join("settings.cfg")
	Dice.deterministic = true
	Dice.reseed(int(args.get("seed", 1)))
	if str(args.get("dice", "high")) == "seeded":
		dice = DiceRoller.new(int(args.get("seed", 1)))
	else:
		dice = HighDice.new()
	var t0 := Time.get_ticks_msec()
	var end := _run()
	var report := _report(end, Time.get_ticks_msec() - t0, str(args.get("dice", "high")))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("qa: cannot write %s" % out_path)
		get_tree().quit(2)
		return
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("qa: story bot %s after %d steps at %s" % [end, step, st.location])
	_clean_saves()
	get_tree().quit(0)


static func _clean_saves() -> void:
	var dir := ProjectSettings.globalize_path(SaveSystem.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for f: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)


# --- The campaign as data --------------------------------------------------------------------------

func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", st.location)


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


func _level() -> int:
	return st.party[0].character_level() if not st.party.is_empty() else 0


## The story as it stands: flags (the spent-check and XP bookkeeping left out), quest stages and what's been won and
## found. An action is tried again only once this has changed.
func _sig() -> String:
	var parts: Array[String] = []
	for k: String in st.flags:
		if k.begins_with("_xp/") or k.begins_with("_failed/"):
			continue
		parts.append("%s=%s" % [k, str(st.flags[k])])
	for q: String in st.quests:
		parts.append("q:%s=%s" % [q, st.quest_stage(q)])
	parts.sort()
	return str(hash(",".join(parts)))


func _problem(kind: String, detail: String) -> void:
	var key := "%s|%s|%s" % [kind, st.location, detail]
	if _problem_keys.has(key):
		return
	_problem_keys[key] = true
	problems.append({"kind": kind, "where": st.location, "step": step, "detail": detail,
		"main": _main_state()})


func _t(s: String) -> void:
	if trace_on:
		trace.append("%d %s: %s" % [step, st.location, s])


func _main_quests() -> Array[String]:
	var out: Array[String] = []
	for q: Variant in Compendium.shared().table("quests").values():
		if str((q as Dictionary).get("kind", "")) == "main":
			out.append(str((q as Dictionary)["id"]))
	out.sort()
	return out


func _main_state() -> Dictionary:
	var out := {}
	for q in _main_quests():
		var s := st.quest_stage(q)
		if s != "":
			out[q] = s
	return out


# --- The run ---------------------------------------------------------------------------------------

func _run() -> String:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	var stages := {}
	var b := _play(GAME.OPENING)
	if bool(b.get("end_game", false)):
		return "game_over"
	if st.location == "":
		st.location = GAME.FIRST_LOCATION
	_arrive(st.location)
	_last_sig = _sig()
	while step < max_steps:
		step += 1
		_note_stages(stages)
		if st.quest_ended(goal):
			return "goal"
		_level_up()
		var did := _act()
		if did == "game_over":
			return "game_over"
		var sig := _sig()
		if sig != _last_sig:
			_last_sig = sig
			_since_progress = 0
			_waits = 0
		else:
			_since_progress += 1
		if did == "" or _since_progress > patience:
			# Nothing new here or anywhere reachable: let time pass (people keep hours), then rest, then give up.
			if _waits < 6:
				_waits += 1
				st.advance_minutes(180)
				_t("waits three hours")
				_tried.clear()
				_since_progress = 0
				continue
			if _waits < 8:
				_waits += 1
				_long_rest()
				_tried.clear()
				_since_progress = 0
				continue
			_stuck()
			return "stuck"
	_note_stages(stages)
	return "out_of_steps"


func _note_stages(seen: Dictionary) -> void:
	for q in _main_quests():
		var s := st.quest_stage(q)
		if s != "" and str(seen.get(q, "")) != s:
			seen[q] = s
			timeline.append({"step": step, "quest": q, "stage": s, "location": st.location, "level": _level()})


func _level_up() -> void:
	var target := st.target_level()
	for i in st.party.size():
		var ch := st.party[i]
		if ch.character_level() < target and Compendium.shared().has("pregens", ch.id):
			var fresh := Pregens.build(ch.id, target)
			if fresh != null:
				fresh.finish_long_rest()
				st.party[i] = fresh
				_t("%s reaches level %d" % [ch.id, target])


func _long_rest() -> void:
	for ch in st.party:
		ch.finish_long_rest()
	st.advance_minutes(8 * 60)
	_t("long rest")


## One thing done: the first of this place's actions not tried since the story last moved, else a step toward a place
## that has one. "" when there is nothing left anywhere reachable.
func _act() -> String:
	if st.location == "travel" or st.location == "":
		return _travel()
	var loc := _loc()
	if loc.is_empty():
		_problem("missing_location", "no location data for '%s'" % st.location)
		st.location = "travel"
		return "moved"
	if _flag_fights():
		return "fight"
	var sig := _last_sig
	for a: Dictionary in _actions(loc):
		var key := "%s|%s|%s" % [sig, st.location, a["key"]]
		if _tried.has(key):
			continue
		_tried[key] = true
		return _do(a)
	# Everything here is done: walk on toward somewhere with something left.
	return _walk_on(sig)


## This place's actions, in the order a player would get to them: people, the props that call out, the props with
## something to use, searches, then examining what holds a flag, an item or a fight.
func _actions(loc: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Variant in loc.get("npcs", []):
		var e := n as Dictionary
		if str(e.get("dialogue", "")) != "" and _holds(e.get("when")):
			out.append({"key": "talk:" + str(e["npc"]), "kind": "talk", "ref": str(e["dialogue"]), "npc": str(e["npc"])})
	var found := st.loc_state(st.location)["found"] as Dictionary
	var used := st.loc_state(st.location)["props"] as Dictionary
	for p: Variant in loc.get("props", []):
		var pr := p as Dictionary
		if not _holds(pr.get("when")):
			continue
		var id := str(pr["id"])
		if str(pr.get("call", "")) != "" and _holds(pr.get("call_when")):
			out.append({"key": "call:" + id, "kind": "call", "ref": str(pr["call"]), "prop": pr})
		if str(pr.get("kind", "")) == "search":
			if not bool(found.get(id, false)):
				out.append({"key": "search:" + id, "kind": "search", "prop": pr})
			continue
		if str(pr.get("dialogue", "")) != "":
			out.append({"key": "use:" + id, "kind": "use", "ref": str(pr["dialogue"]), "prop": pr})
		elif str(pr.get("kind", "")) in ["examine", "book"] and (pr.has("flag") or pr.has("item") or _has_trigger(loc, "examine:" + id)) \
				and not bool(used.get(id, false)):
			out.append({"key": "examine:" + id, "kind": "examine", "prop": pr})
	return out


static func _has_trigger(loc: Dictionary, trigger: String) -> bool:
	for en: Variant in loc.get("encounters", []):
		if str((en as Dictionary).get("trigger", "")) == trigger:
			return true
	return false


func _do(a: Dictionary) -> String:
	match str(a["kind"]):
		"talk":
			talked["%s:%s" % [st.location, a["npc"]]] = true
			_t("talks to " + str(a["npc"]))
			return _after_talk(_play(str(a["ref"])))
		"call", "use":
			_t("%s %s" % [a["kind"], (a["prop"] as Dictionary)["id"]])
			return _after_talk(_play(str(a["ref"])))
		"search":
			var pr := a["prop"] as Dictionary
			(st.loc_state(st.location)["found"] as Dictionary)[str(pr["id"])] = true
			_take_prop(pr)
			_t("finds " + str(pr["id"]))
			return "did"
		"examine":
			var pr := a["prop"] as Dictionary
			_take_prop(pr)
			(st.loc_state(st.location)["props"] as Dictionary)[str(pr["id"])] = true
			_t("examines " + str(pr["id"]))
			_trigger("examine:" + str(pr["id"]))
			return "did"
	return ""


## A prop used as LocationInteraction._use_prop does: its flag set, its item taken once.
func _take_prop(pr: Dictionary) -> void:
	if pr.has("flag"):
		st.set_flag(str(pr["flag"]))
	if pr.has("item") and not bool((st.loc_state(st.location)["props"] as Dictionary).get(str(pr["id"]), false)):
		st.gain_item(str(pr["item"]), 1, st.party[0])


func _after_talk(b: Dictionary) -> String:
	if b.is_empty():
		return "did"
	if bool(b.get("end_game", false)):
		return "game_over"
	var combat := str(b.get("combat", ""))
	if combat != "":
		_win(combat, "dialogue")
	var move := b.get("move", {}) as Dictionary
	if not move.is_empty():
		_arrive(str(move["location"]))
	return "did"


## Plays `ref` through. At each menu: the enabled option chosen least often before, not yet chosen in this conversation;
## the last option (the way out) once every other has been tried here; an option that starts a fight right away only once
## the story has stalled for a while (a curious player doesn't draw on the innkeeper first).
func _play(ref: String) -> Dictionary:
	var r := DialogueRunner.new(st, dice)
	if not r.start(ref):
		_problem("dialogue_missing", "conversation '%s' doesn't start" % ref)
		return {}
	var here := {}
	var b := r.next()
	for i in 800:
		if r.file != null:
			nodes_seen["%s:%s" % [r.file.key, r.node]] = true
		match str(b.get("kind", "")):
			"end":
				return b
			"options":
				var opts := b["options"] as Array
				if opts.is_empty():
					_problem("empty_menu", "%s: a menu with no options" % ref)
					return {}
				var pick := _pick(r, ref, opts, here)
				if pick < 0:
					_problem("dead_menu", "%s at %s: no option is enabled (%s)" % [ref, r.node, _texts(opts)])
					return {}
				var text := str((opts[pick] as Dictionary)["text"])
				here[text] = true
				_opt_count["%s|%s" % [ref, text]] = int(_opt_count.get("%s|%s" % [ref, text], 0)) + 1
				_t("  > " + text)
				b = r.choose(pick)
			"guidance":
				b = r.answer_guidance(-1)
			"pick_member":
				b = r.pick_member(0)
			"":
				if r.finished:
					return r._end_beat()
				b = r.next()
			_:
				b = r.next()
	_problem("dialogue_loop", "%s never ended in 800 beats (last node %s)" % [ref, r.node])
	return {}


static func _texts(opts: Array) -> String:
	return ", ".join(opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"])))


var _fight_memo: Dictionary = {}


## Whether the option's own node starts a fight before any other menu (its `ok` target, a hop or two).
func _starts_fight(r: DialogueRunner, opt: Dictionary) -> bool:
	var file_key := r.file.key if r.file != null else ""
	var target := DialoguePathBot.full_ref(str(opt.get("ok", "")), file_key)
	if target == "" or target == "END":
		return false
	if _fight_memo.has(target):
		return bool(_fight_memo[target])
	var bot := DialoguePathBot.new()
	var d := bot.distance(target, func(s: Dictionary) -> bool: return str(s.get("t", "")) == "combat")
	var menu := bot.distance(target, func(s: Dictionary) -> bool: return str(s.get("t", "")) == "option")
	var hit := d >= 0 and d <= 1 and (menu < 0 or menu > d)
	_fight_memo[target] = hit
	return hit


func _pick(r: DialogueRunner, ref: String, opts: Array, here: Dictionary) -> int:
	var best := -1
	var best_score := 1 << 30
	var last := -1
	for j in opts.size():
		if bool((opts[j] as Dictionary)["enabled"]):
			last = j
	if last < 0:
		return -1
	var bold := _since_progress > patience / 2
	for j in opts.size():
		var o := opts[j] as Dictionary
		if not bool(o["enabled"]):
			continue
		var text := str(o["text"])
		if here.has(text):
			continue
		var score := int(_opt_count.get("%s|%s" % [ref, text], 0)) * 10
		if j == last:
			score += 15
		if j < r._options.size() and _starts_fight(r, r._options[j]):
			score += 5 if bold else 1000
		if score < best_score:
			best_score = score
			best = j
	if best < 0 or best_score >= 1000:
		return last
	return best


# --- Fights ----------------------------------------------------------------------------------------

## The fight `id` of this place won (the place's first entry of that id whose `when` holds, as spec_for picks it).
func _win(id: String, trigger: String) -> void:
	var spec := {}
	var region := str(_loc().get("region", ""))
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == id and (spec.is_empty() or not _holds(StoryConditions.encounter_when(spec, region))):
			spec = e as Dictionary
	var custom := st.loc_state(st.location).get("custom_fights", {}) as Dictionary
	if spec.is_empty() and custom.has(id):
		spec = custom[id] as Dictionary
	if spec.is_empty():
		_problem("missing_fight", "a conversation starts the fight '%s', which this place doesn't have" % id)
		return
	fights.append({"step": step, "loc": st.location, "id": id, "level": _level(), "trigger": trigger,
		"main": _main_state(), "boss": _has_boss(spec)})
	_t("wins the fight " + id)
	(st.loc_state(st.location)["encounters"] as Dictionary)[id] = true
	if spec.has("flag"):
		st.set_flag(str(spec["flag"]))
	if spec.has("quest"):
		st.set_quest_stage(str((spec["quest"] as Dictionary)["id"]), str((spec["quest"] as Dictionary)["stage"]))
	for ch in st.party:
		ch.hp = maxi(ch.hp, 1)


static func _has_boss(spec: Dictionary) -> bool:
	for m: Variant in spec.get("monsters", []):
		var md := Compendium.shared().monster_data(str((m as Dictionary).get("id", (m as Dictionary).get("monster", ""))))
		if not (md.get("legendary_actions", []) as Array).is_empty() or float(md.get("cr", 0)) >= Difficulty.BOSS_CR:
			return true
	return false


## The fights a trigger here starts (`examine:<prop>`, `enter_area:<area>`, `flag:<flag>`), as _trigger_encounter
## picks them: not yet won and their `when` holding.
func _trigger(trigger: String) -> bool:
	var region := str(_loc().get("region", ""))
	for en: Variant in _loc().get("encounters", []):
		var spec := en as Dictionary
		if str(spec["trigger"]) != trigger:
			continue
		var done: Variant = (st.loc_state(st.location)["encounters"] as Dictionary).get(str(spec["id"]), false)
		if done is bool and bool(done):
			continue
		if not _holds(StoryConditions.encounter_when(spec, region)):
			continue
		_win(str(spec["id"]), trigger)
		return true
	return false


func _flag_fights() -> bool:
	Jail.settle(st)
	for en: Variant in _loc().get("encounters", []):
		var trig := str((en as Dictionary)["trigger"])
		if trig.begins_with("flag:") and StoryConditions._truthy(st.get_flag(trig.substr(5))):
			if _trigger(trig):
				return true
	return false


# --- Moving ----------------------------------------------------------------------------------------

func _arrive(id: String) -> void:
	st.location = id
	st.visited[id] = true
	if _loc().is_empty():
		_problem("missing_location", "moved to '%s', which has no location data" % id)
		return
	# The party walks every corner it can: a fight that starts on stepping into its area starts.
	for en: Variant in _loc().get("encounters", []):
		var trig := str((en as Dictionary)["trigger"])
		if trig.begins_with("enter_area:"):
			_trigger(trig)


func _exits(loc: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for x: Variant in loc.get("exits", []):
		var e := x as Dictionary
		if _holds(e.get("when")):
			out.append(e)
	return out


func _take_exit(e: Dictionary) -> void:
	if str(e["to"]) == "travel":
		_travel_from = st.location
		st.location = "travel"
		_t("takes the road out (%s)" % e["id"])
		return
	if e.has("sets_quest"):
		var q := e["sets_quest"] as Dictionary
		st.set_quest_stage(str(q.get("id", "")), str(q.get("stage", "")))
	var target: String = Campaign.module().exit_target(st, st.location, str(e["to"]))
	_t("walks out by %s to %s" % [e["id"], target])
	_arrive(target)


## Has `loc_id` anything not tried at `sig`?
func _fresh_at(loc_id: String, sig: String) -> bool:
	var keep := st.location
	st.location = loc_id
	var loc := _loc()
	var fresh := false
	if not loc.is_empty():
		for a: Dictionary in _actions(loc):
			if not _tried.has("%s|%s|%s" % [sig, loc_id, a["key"]]):
				fresh = true
				break
	st.location = keep
	return fresh


## A step along the shortest open way (exits) to the nearest place with something left to try; else the road out, if
## this place has one and the travel map has somewhere fresh.
func _walk_on(sig: String) -> String:
	var start := st.location
	var prev := {start: ""}
	var first_exit := {}
	var queue: Array[String] = [start]
	var road_out: Dictionary = {}
	var limit := 0
	while not queue.is_empty() and limit < 400:
		limit += 1
		var here := queue.pop_front() as String
		var keep := st.location
		st.location = here
		var loc := _loc()
		var exits := _exits(loc) if not loc.is_empty() else ([] as Array[Dictionary])
		st.location = keep
		for e in exits:
			if str(e["to"]) == "travel":
				if road_out.is_empty():
					road_out = e if here == start else first_exit[here] as Dictionary
				continue
			st.location = here
			var to: String = Campaign.module().exit_target(st, here, str(e["to"]))
			st.location = keep
			if prev.has(to):
				continue
			prev[to] = here
			first_exit[to] = e if here == start else first_exit[here]
			if _fresh_at(to, sig) or not st.visited.has(to):
				_take_exit(first_exit[to] as Dictionary)
				return "moved"
			queue.append(to)
	# The road out (or the first step toward the nearest place that has one), when the map has somewhere fresh.
	if not road_out.is_empty() and _travel_target(sig) != "":
		_take_exit(road_out)
		return "moved"
	return ""


## A known place on the travel map, other than where the party left, with something fresh (or never visited).
func _travel_target(sig: String) -> String:
	var here := Travel.place_for_location(_travel_from if st.location == "travel" else st.location)
	var best := ""
	for p in Travel.known(st):
		var loc_id := str(p["location"]).get_slice(":", 0)
		if str(p["id"]) == here:
			continue
		if here != "" and Travel.route(here, str(p["id"]), st).is_empty():
			continue
		if not st.visited.has(loc_id):
			return str(p["id"])
		if best == "" and _fresh_at(loc_id, _last_sig):
			best = str(p["id"])
	return best


func _travel() -> String:
	var target := _travel_target(_last_sig)
	if target == "":
		# Back where it came from, or nowhere.
		if _travel_from != "":
			_arrive(_travel_from)
			_travel_from = ""
			return ""
		_problem("travel_nowhere", "on the road with no known place to go")
		return ""
	var p := Travel.place(target)
	var legs := Travel.route(Travel.place_for_location(_travel_from), target, st) if _travel_from != "" else ([] as Array[Dictionary])
	st.advance_minutes(int(Travel.hours(legs) * 60.0))
	_t("travels to " + target)
	_travel_from = ""
	_arrive(str(p["location"]).get_slice(":", 0))
	return "moved"


# --- The report ------------------------------------------------------------------------------------

func _stuck() -> void:
	var loc := _loc()
	var locked: Array[String] = []
	for x: Variant in loc.get("exits", []):
		var e := x as Dictionary
		if not _holds(e.get("when")):
			locked.append("%s (when %s%s)" % [e["id"], e.get("when", ""), "; says: " + str(e["locked_text"]) if e.has("locked_text") else ""])
	var people: Array[String] = []
	for n: Variant in loc.get("npcs", []):
		var e := n as Dictionary
		people.append("%s%s" % [e["npc"], "" if _holds(e.get("when")) else " (away: %s)" % e.get("when", "")])
	var hints: Array[String] = []
	for q: String in _main_state():
		if st.quest_ended(q):
			continue
		var qd := Compendium.shared().get_entry("quests", q)
		for s: Variant in qd.get("stages", []):
			if str((s as Dictionary)["id"]) == st.quest_stage(q):
				hints.append("%s/%s: %s" % [q, st.quest_stage(q), (s as Dictionary).get("hint", "")])
	_problem("stuck", "the story stopped moving. People here: %s. Locked exits: %s. Open main quests: %s" % [
		", ".join(people), ", ".join(locked) if not locked.is_empty() else "none", " | ".join(hints)])


func _report(end: String, ms: int, dice_kind: String) -> Dictionary:
	var all_locs: Array = Compendium.shared().table("locations").keys()
	var unvisited: Array[String] = []
	for l: Variant in all_locs:
		if not st.visited.has(str(l)):
			unvisited.append(str(l))
	unvisited.sort()
	var levels := {}
	for f: Dictionary in fights:
		levels["%s:%s" % [f["loc"], f["id"]]] = f["level"]
	var ended: Array[String] = []
	for q in _main_quests():
		if st.quest_ended(q):
			ended.append(q)
	return {"end": end, "steps": step, "ms": ms, "dice": dice_kind, "goal": goal, "location": st.location, "level": _level(),
		"main_quests": _main_state(), "main_ended": ended, "timeline": timeline, "fights": fights, "levels": levels,
		"problems": problems, "visited": st.visited.size(), "locations": all_locs.size(), "unvisited": unvisited,
		"dialogue_nodes_seen": nodes_seen.size(), "talked": talked.size(), "trace": trace}
