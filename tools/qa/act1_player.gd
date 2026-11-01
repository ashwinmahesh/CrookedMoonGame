extends Node
## Act 1 as a player plays it (QA lane, owner 2026-11-01: "get the game to work through act 1"): the real title screen,
## the roster page, the difficulty page, then the real game scene (scenes/game.tscn: GameRoot, LocationView, DialogueUI,
## CombatView) driven only through what a click or a key does: buttons pressed, the leader clicked onto people, props
## and exits (LocationView.click), Search, the dialogue box's options and Continue, and in a fight the party's turns
## played by the engine's PartyAutopilot at full ability (as the player would play them) with the fight's own view
## running the foes. Real dice, seeded. Nothing writes the story state behind the game's back.
##
## The route is the Ghostlight Express as the book plays it (test_r10_playthrough's picks), one plan per place, so the
## cars can come in the Switcheroo's own order. Everything that stops a player is written to the report as a blocker:
## a page or button that isn't there, a person, prop or exit the plan needs that isn't on the map or doesn't answer a
## click, an option missing, a conversation or a walk that never ends, a fight the party loses for good, a script error.
##
## Args after --: --out=/abs/act1.json [--seed=1] [--book-order=1] [--frames=40000] [--mode=balanced]

const GAME := preload("res://world/game_root.gd")

## Each place's plan: steps in order. A step: [kind, target, picks]. kind: talk (an NPC), use (click a prop: a call, a
## conversation, an examine), search (Search until the prop shows, then click it), exit (walk out by it). picks: at each
## menu the first enabled option containing one of the "a|b" words, in order; the last option once they run out.
const PLAN := {
	"ghostlight_boarding": [["talk", "the_vagrant", ["fare", "Tell him something true|Check our pockets", "Check our pockets|ready to board", "ready to board"]]],
	"ghostlight_g1_passenger": [["talk", "the_vagrant", ["Go on to your cab"]], ["search", "g1_marble_jar", []],
		["talk", "phantom_trainhopper", []], ["use", "grille_g1", ["Understood"]], ["exit", "front_door", []]],
	"ghostlight_g2_sleeper": [["use", "g2_phonograph", ["Carry it with us"]], ["talk", "haint_sweetheart", ["bottle"]],
		["exit", "front_door", []]],
	"ghostlight_g3_lounge": [["search", "g3_seascape", []], ["search", "g3_whiskey_bottle", []],
		["talk", "haint_songstress", ["help you finish", "Sing the melody", "Trace the magic", "Speak the lonely word"]], ["exit", "front_door", []]],
	"ghostlight_g4_dining": [["use", "g4_big_booth", []], ["use", "g4_booth_n1", ["Steak and eggs", "Get up"]],
		["talk", "haint_daydreamer", ["empty glass jar|bottle"]], ["exit", "front_door", []]],
	"ghostlight_g5_mail": [["search", "g5_pink_envelope", []], ["talk", "haint_mariner", ["painting"]], ["exit", "front_door", []]],
	"ghostlight_g6_baggage": [["talk", "haint_jailbird", ["talk with you", "gallows custom", "hot plate", "campfire skillets"]],
		["exit", "front_door", []]],
	"ghostlight_g7_circus": [["talk", "haint_harlequin", ["Draw a weapon"]], ["exit", "front_door", []]],
	"ghostlight_g8_tender": [["use", "g8_firebox", []], ["use", "g8_tank", []]],
	"ghostlight_wreckage": [["talk", "phillip_druskenvald", []], ["talk", "the_vagrant", ["hum", "We'll go now"]],
		["search", "wr_soul_can_1", []], ["search", "wr_soul_can_2", []], ["search", "wr_soul_can_3", []],
		["talk", "the_vagrant", ["We have the cans", "Ready. Do it."]], ["use", "wr_moon", []], ["exit", "to_wickermoor", []]],
}

var out_path := ""
var seed_value := 1
var book_order := true
var max_frames := 40000
var mode := "balanced"

var root: Node = null       ## GameRoot once the game scene is up
var frame := 0
var blockers: Array[Dictionary] = []
var notes: Array[String] = []
var steps: Array[Dictionary] = []
var fights: Array[Dictionary] = []
var toasts: Array[String] = []
var roster: Array[String] = []
var _pilot: PartyAutopilot = null
var _pilot_e: Encounter = null
var _fight_rounds := 0
var _done: Dictionary = {}   ## "loc|i" -> true


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	out_path = str(args.get("out", "user://qa_act1.json"))
	seed_value = int(args.get("seed", 1))
	book_order = str(args.get("book-order", "1")) == "1"
	max_frames = int(args.get("frames", max_frames))
	mode = str(args.get("mode", mode))
	SaveSystem.save_dir = "user://qa_saves/%d/" % OS.get_process_id()
	GameSettings.path = SaveSystem.save_dir.path_join("settings.cfg")
	Dice.deterministic = true
	Dice.reseed(seed_value)
	_go.call_deferred()


func _go() -> void:
	var t0 := Time.get_ticks_msec()
	var end := await _play()
	var report := {"end": end, "seed": seed_value, "book_order": book_order, "mode": mode, "frames": frame,
		"ms": Time.get_ticks_msec() - t0, "roster": roster, "blockers": blockers, "notes": notes, "steps": steps,
		"fights": fights, "toasts": toasts, "stage": GameState.story.quest_stage("ghostlight_express"),
		"location": GameState.story.location}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("qa: act 1 %s, %d blockers, stage %s at %s" % [end, blockers.size(), report["stage"], report["location"]])
	get_tree().quit(0)


func _block(what: String, detail: String) -> void:
	var st := GameState.story
	blockers.append({"what": what, "detail": detail, "location": st.location, "stage": st.quest_stage("ghostlight_express"),
		"frame": frame, "screen": _screen()})
	print("qa: BLOCKER %s: %s" % [what, detail])


## What's up on screen, in words, for a blocker.
func _screen() -> String:
	if root == null:
		return "title"
	var parts: Array[String] = []
	var d: DialogueUI = root.get("dialogue")
	if d != null:
		parts.append("dialogue")
		if d.runner != null and d.runner.file != null:
			parts.append("at %s:%s" % [d.runner.file.key, d.runner.node])
		var shown: Array[String] = []
		for o: Variant in d.options_shown:
			shown.append(str((o as Dictionary).get("text", "")))
		if not shown.is_empty():
			parts.append("options: " + " / ".join(shown))
	if root.get("screen") != null:
		parts.append("screen %s" % (root.get("screen") as Node).get_class())
	if root.get("loot") != null:
		parts.append("loot window")
	var v: LocationView = root.get("view")
	if v != null:
		parts.append("in %s%s%s" % [v.loc_id, " (fighting)" if v.in_combat else "", " (busy)" if v.busy else ""])
	return ", ".join(parts)


func _frames(n: int) -> void:
	for i in n:
		frame += 1
		await get_tree().process_frame


## Waits until `cond` holds, driving what comes up meanwhile (conversations, fights, loot). False after `limit` frames.
func _until(cond: Callable, limit: int, picks: Array = []) -> bool:
	var left := picks   # shared with the caller's later waits: a pick is used once
	for i in limit:
		if bool(cond.call()):
			return true
		if frame > max_frames:
			return false
		await _drive(left)
		await _frames(1)
	return bool(cond.call())


# --- The title, as clicked ---------------------------------------------------------------------------

static func _buttons(n: Node, out: Array[Button]) -> void:
	if n is Button and (n as Button).is_visible_in_tree():
		out.append(n as Button)
	for c in n.get_children():
		_buttons(c, out)


func _press(host: Node, text_start: String) -> bool:
	var all: Array[Button] = []
	_buttons(host, all)
	for b in all:
		if b.text.begins_with(text_start) and not b.disabled:
			b.pressed.emit()
			return true
	var seen: Array[String] = []
	for b in all:
		seen.append(b.text + (" (disabled)" if b.disabled else ""))
	_block("button", "no button '%s' on the page (buttons: %s)" % [text_start, ", ".join(seen)])
	return false


func _play() -> String:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames(10)
	if not _press(menu, "New game"):
		return "blocked_title"
	await _frames(5)
	roster = Pregens.roster_ids()
	notes.append("Roster on the new-game page: %s" % ", ".join(roster.map(func(id: String) -> String:
		return str(Compendium.shared().get_entry("pregens", id).get("name", id)))))
	var companions := ["rook_coldwake", "silas_vane", "cordelia_skein", "delphine_ravelle", "tobin_hayward", "lucan_houndstooth"]
	var strangers := roster.filter(func(id: String) -> bool: return not id in companions)
	if not strangers.is_empty():
		_block("roster", "the new-game page offers heroes who aren't this game's companions: %s" % ", ".join(strangers))
	if not _press(menu, "Go on"):
		return "blocked_roster"
	await _frames(5)
	if mode != Difficulty.DEFAULT:
		menu.call("_set_difficulty", mode)
		await _frames(3)
	if not _press(menu, "Begin on"):
		return "blocked_difficulty"
	# The game scene replaces the title.
	var up := await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.get("view") != null, 600)
	if not up:
		_block("start", "the game scene never came up after Begin")
		return "blocked_start"
	root = get_tree().current_scene
	var party: Array[String] = []
	for ch: Character in GameState.story.party:
		party.append(ch.name)
	notes.append("The party that boards: %s" % ", ".join(party))
	_listen(root.get("view") as LocationView)
	if book_order:
		GameState.story.playthrough_seed = _seed_for_book_order()
	# The Calls to Adventure play first.
	await _until(func() -> bool: return root.get("dialogue") != null, 300)
	if not await _until(_idle, 4000):
		_block("opening", "the opening conversation never ended")
		return "blocked_opening"
	# The plan, place by place, until the Express is over and the party is on the road.
	var guard := 0
	while frame < max_frames and guard < 200:
		guard += 1
		var st := GameState.story
		if st.quest_ended("ghostlight_express") and st.location in ["travel", ""] or _travel_open():
			return "done"
		if root.get("ending") != null or _game_over():
			_block("game_over", "the game ended (the party fell where no retry catches it)")
			return "game_over"
		var here := st.location
		var plan := PLAN.get(here, []) as Array
		if plan.is_empty():
			if here == CrookedMoonCampaign.limbo_place():
				await _do(["exit", "onward", []], "mist")
				continue
			_block("place", "no plan for '%s' (the party arrived somewhere the book's route doesn't go)" % here)
			return "blocked_place"
		await _level_ups()
		var acted := false
		for i in plan.size():
			var key := "%s|%d" % [here, i]
			if _done.has(key):
				continue
			_done[key] = true
			await _do(plan[i] as Array, here)
			acted = true
			break
		if not acted:
			_block("stuck", "every step of %s's plan is done and the party is still here (stage %s)" % [here, st.quest_stage("ghostlight_express")])
			return "stuck"
	return "out_of_frames"


var _listening: Dictionary = {}


## What the place says to the player (toasts, the Narrator's lines, rolls), kept for the report: a view is made anew
## on every change of place, so each one is listened to as it comes.
func _listen(v: LocationView) -> void:
	if v == null or _listening.has(v.get_instance_id()):
		return
	_listening[v.get_instance_id()] = true
	v.toast.connect(func(t: String) -> void: toasts.append("%s: %s" % [v.loc_id, t]))
	v.narration.connect(func(t: String) -> void: toasts.append("%s (narration): %s" % [v.loc_id, t]))
	v.check_rolled.connect(func(t: String) -> void: toasts.append("%s (roll): %s" % [v.loc_id, t]))


func _travel_open() -> bool:
	return root != null and root.get("screen") != null and str((root.get("screen") as Node).get_class()).contains("Travel")


func _game_over() -> bool:
	var s: Variant = root.get("screen")
	return s != null and s is PauseMenu and bool((s as PauseMenu).game_over)


## The party as it stands: "Name hp/max" with "dead" or "down".
func _party_line() -> String:
	var out: Array[String] = []
	for ch: Character in GameState.story.party:
		out.append("%s L%d %d/%d%s" % [ch.name.get_slice(" ", 0), ch.character_level(), ch.hp, ch.max_hp(),
			" dead" if ch.dead else (" down" if ch.hp <= 0 else "")])
	return ", ".join(out)


## Levels the story allows are taken as the player takes them: the level-up screen for each hero who can, its
## recommended picks confirmed.
func _level_ups() -> void:
	var st := GameState.story
	for i in st.party.size():
		var ch := st.party[i]
		var guard := 0
		while not ch.dead and st.can_level_up(ch) and guard < 4:
			guard += 1
			var was := ch.character_level()
			root.call("open_screen", "level_up", i)
			await _frames(4)
			var scr: Variant = root.get("screen")
			if scr is LevelUpScreen and (scr as LevelUpScreen).ctl != null:
				(scr as LevelUpScreen)._confirm()
			await _frames(4)
			if root.get("screen") != null:
				root.call("close_screen")
				await _frames(2)
			if ch.character_level() == was:
				_block("level_up", "%s could level up but the level-up screen's recommended picks didn't confirm" % ch.name)
				break
			notes.append("%s levels up to %d" % [ch.name, ch.character_level()])


func _idle() -> bool:
	var v: LocationView = root.get("view")
	return root.get("dialogue") == null and root.get("loot") == null and v != null and not v.busy and not v.in_combat \
		and not bool(root.get("moving")) and v._queue.is_empty() and not v._on_arrive.is_valid()


# --- Steps -------------------------------------------------------------------------------------------

func _do(step: Array, here: String) -> void:
	var kind := str(step[0])
	var target := str(step[1])
	var picks := (step[2] as Array).duplicate()
	var st := GameState.story
	var before := st.quest_stage("ghostlight_express")
	var rec := {"place": here, "step": "%s %s" % [kind, target], "frame": frame}
	await _until(_idle, 1200)
	var v: LocationView = root.get("view")
	_listen(v)
	var cell := Vector2i(-1, -1)
	match kind:
		"talk":
			for e: Dictionary in v._npc_shown:
				if str((e["spec"] as Dictionary).get("npc", "")) == target:
					cell = e["cell"] as Vector2i
					break
			if cell.x < 0:
				# Not a blocker by itself: the story may have moved past them (the Phantom comes at the party on its own).
				notes.append("%s isn't standing in %s to talk to (stage %s); step skipped" % [target, here, st.quest_stage("ghostlight_express")])
		"use":
			var c: Variant = v.prop_cell(target)
			if c == null:
				_block("prop", "%s isn't in %s" % [target, here])
			else:
				cell = c as Vector2i
		"search":
			var c: Variant = v.prop_cell(target)
			if c == null:
				_block("prop", "%s isn't in %s" % [target, here])
			else:
				cell = c as Vector2i
				# Walk beside it and Search until it turns up (a search prop is hidden until found).
				var found := func() -> bool: return bool((st.loc_state(st.location)["found"] as Dictionary).get(target, false))
				for attempt in 8:
					if found.call():
						break
					# A find missed by one hero can still be found by another: the player makes the next one leader.
					if attempt > 0:
						root.call("world_action", Vector2i.ZERO, "lead:%d" % (attempt % st.party.size()))
						await _frames(3)
					var stand := LocationInteraction._adjacent_free(v, cell)
					for w in 8:
						v = root.get("view")
						if stand.x < 0 or v.leader().cell == stand:
							break
						v.walk_to(stand)
						await _frames(3)
						await _until(_idle, 3000)
					v = root.get("view")
					if attempt == 0:
						notes.append("search %s: prop at %s, stood at %s" % [target, cell, v.leader().cell])
					v.search()
					await _frames(30)
					await _until(_idle, 600)
				if not found.call():
					_block("search", "Searching beside %s in %s never found it" % [target, here])
		"exit":
			for x: Variant in v.loc.get("exits", []):
				var e := x as Dictionary
				if str(e["id"]) == target:
					cell = Vector2i(int((e["cell"] as Array)[0]), int((e["cell"] as Array)[1]))
					if not StoryConditions.check(str(e.get("when", "")), st):
						_block("exit", "the way out '%s' of %s is shut: %s" % [target, here, e.get("locked_text", e.get("when", ""))])
						cell = Vector2i(-1, -1)
			if cell.x < 0 and blockers.is_empty() or (cell.x < 0 and blockers.back()["what"] != "exit"):
				_block("exit", "%s has no way out called %s" % [here, target])
	if kind == "search" and cell.x >= 0 and not bool((st.loc_state(st.location)["found"] as Dictionary).get(target, false)):
		cell = Vector2i(-1, -1)
	if cell.x < 0:
		rec["result"] = "blocked"
		steps.append(rec)
		return
	var loc_before := st.location
	# What the click should bring: the person's or prop's own conversation, else (an examine) anything said or set.
	var want_refs: Array[String] = []
	if kind == "talk":
		for e: Dictionary in v._npc_shown:
			if str((e["spec"] as Dictionary).get("npc", "")) == target:
				want_refs.append(str((e["spec"] as Dictionary).get("dialogue", "")))
	elif kind == "use":
		for p: Variant in v.loc.get("props", []):
			if str((p as Dictionary)["id"]) == target:
				want_refs.append(str((p as Dictionary).get("dialogue", "")))
				want_refs.append(str((p as Dictionary).get("call", "")))
	var heard := [false]
	var toasts_before := toasts.size()
	var reached := func() -> bool:
		if st.location != loc_before:
			return true
		if kind == "exit":
			return false
		if kind == "search":
			return bool((st.loc_state(st.location)["props"] as Dictionary).get(target, false))
		if str(root.get("_dialogue_ref")) in want_refs and root.get("dialogue") != null:
			heard[0] = true
		if heard[0] or st.quest_stage("ghostlight_express") != before:
			return true
		var lv: LocationView = root.get("view")
		if kind == "use" and want_refs.all(func(r: String) -> bool: return r == "") and toasts.size() > toasts_before:
			return true
		return lv != null and lv.in_combat
	var trail: Array[String] = []
	var ok := false
	for attempt in 8:
		var lv: LocationView = root.get("view")
		if lv == null or not _idle():
			await _until(_idle, 20000, picks)
			lv = root.get("view")
		if bool(reached.call()):
			ok = true
			break
		if attempt == 0:
			notes.append("%s %s at %s: leader at %s, path %d squares" % [kind, target, cell, lv.leader().cell,
				lv._path(lv.leader().cell, cell).size()])
		# A walk cut short (a call, an area's line, a fight) is clicked again, as a player would.
		lv.click(cell)
		await _frames(3)
		await _until(func() -> bool: return bool(reached.call()) or _idle(), 3000, picks)
		trail.append(str(lv.leader().cell) if is_instance_valid(lv) and lv.leader() != null else "-")
		if bool(reached.call()):
			ok = true
			break
	if not ok:
		notes.append("%s %s: the leader stood at %s after each click" % [kind, target, ", ".join(trail)])
		if kind == "exit":
			_block("walk", "clicking the way out '%s' of %s eight times never took the party through it" % [target, here])
		else:
			_block(kind, "clicking %s in %s eight times never brought its conversation or anything else (toasts: %s)" % [
				target, here, " | ".join(toasts.slice(toasts_before).slice(-3))])
	if not await _until(_idle, 20000, picks):
		_block("hang", "after %s %s the game never came back to exploring (screen: %s)" % [kind, target, _screen()])
	rec["stage"] = st.quest_stage("ghostlight_express")
	rec["now_at"] = st.location
	rec["party"] = _party_line()
	steps.append(rec)


# --- What comes up: conversations, fights, loot --------------------------------------------------------

func _drive(picks: Array) -> void:
	var d: DialogueUI = root.get("dialogue") if root != null else null
	if d != null and is_instance_valid(d):
		_talk(d, picks)
		return
	var lw: Variant = root.get("loot") if root != null else null
	if lw != null and is_instance_valid(lw as Object):
		(lw as Object).call("_take_all")
		return
	var v: LocationView = root.get("view") if root != null else null
	if v != null and v.in_combat and v.combat_view != null and is_instance_valid(v.combat_view):
		await _fight(v)


func _talk(d: DialogueUI, picks: Array) -> void:
	if d.guidance != null and is_instance_valid(d.guidance):
		d.guidance.call("_answer", -1)
		return
	if d._waiting_continue:
		d._advance()
		return
	if d.cutscene != null and is_instance_valid(d.cutscene) and d.options_shown.is_empty():
		return   # a picture playing: it hands back by itself
	if d.options_shown.is_empty() or d._option_buttons.is_empty():
		return
	var opts := d.options_shown
	var pick := -1
	var last := -1
	for j in d._option_buttons.size():
		if not d._option_buttons[j].disabled:
			last = j
	if not picks.is_empty():
		# The next pick is used only by a menu that offers it: a call or a companion's aside that comes up in between
		# is left by its last option and the pick waits for its own conversation.
		var want := str(picks[0])
		for j in d._option_buttons.size():
			if d._option_buttons[j].disabled or j >= opts.size():
				continue
			var text := str((opts[j] as Dictionary).get("text", ""))
			for w: String in want.split("|"):
				if text.contains(w):
					pick = j
					break
			if pick >= 0:
				break
		if pick >= 0:
			picks.pop_front()
		else:
			var shown: Array[String] = []
			for o: Variant in opts:
				shown.append(str((o as Dictionary).get("text", "")))
			notes.append("%s at %s: no option '%s' (had: %s); took the last" % [GameState.story.location,
				d.runner.node if d.runner != null else "?", want, " / ".join(shown)])
	if pick < 0:
		pick = last
	if pick < 0:
		_block("menu", "a menu with nothing to choose (%s)" % _screen())
		return
	d._option_buttons[pick].pressed.emit()


## One step of a fight as the player would take it: the hero whose turn it is plays (the autopilot, at full ability),
## prompts are answered, the turn ends, and the fight's own view carries on; Continue at the end.
func _fight(v: LocationView) -> void:
	var cv := v.combat_view
	var e := cv.e
	if e == null:
		return
	if _pilot_e != e:
		_pilot_e = e
		_pilot = PartyAutopilot.new(e)
		PartyAutopilot.sharp = true
		PartyAutopilot.full = true
		e.default_player_reaction = "auto"
		fights.append({"id": v.fight_id, "place": v.loc_id, "frame": frame, "outcome": "", "rounds": 0, "party_before": _party_line()})
	if cv.mode == CombatView.Mode.OVER:
		(fights.back() as Dictionary)["outcome"] = e.outcome
		(fights.back() as Dictionary)["rounds"] = e.round_no
		(fights.back() as Dictionary)["party_after"] = _party_line()
		cv.hud.banner("", 0.0)
		cv.finished.emit(e.outcome)
		_pilot_e = null
		return
	if cv.hud.death_save_shown():
		cv.hud.death_save_pressed.emit()
		return
	if cv.mode == CombatView.Mode.PROMPT and e.pending != null:
		e.answer_reaction(true)
		await cv._play_events()
		cv._advance()
		return
	if cv.mode != CombatView.Mode.IDLE:
		return
	var c := e.current()
	if not c.is_player_controlled():
		return
	if e.round_no > 40:
		_block("fight", "%s ran past 40 rounds" % v.fight_id)
	_pilot.play(c)
	await cv._play_events()
	while e.pending != null:
		e.answer_reaction(true)
		await cv._play_events()
	if e.state == Encounter.State.ACTIVE and e.current() == c:
		e.end_turn()
		await cv._play_events()
	cv._advance()


## A playthrough seed that shuffles the six middle cars into the book's order (test_r10_playthrough's).
func _seed_for_book_order() -> int:
	var want := ["ghostlight_g1_passenger", "ghostlight_g2_sleeper", "ghostlight_g3_lounge", "ghostlight_g4_dining", "ghostlight_g5_mail",
		"ghostlight_g6_baggage", "ghostlight_g7_circus", "ghostlight_g8_tender"]
	for candidate: int in 100000:
		if str(CrookedMoonCampaign.switcheroo_chain(candidate)) == str(want):
			return candidate
	return 0
