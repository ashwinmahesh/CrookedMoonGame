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
## The run goes on past the Express (QA lane act1-hub, coordinator 2026-11-02): out of the wreck clearing by the road, into
## Wickermoor (the goat and the wolves, the mayor's welcome, the Green Queen Inn with a save and a load made in it), up the
## hill road to the Druskenvald estate (the Jenkins, the Crooked Man), and through the Crooked House on all four floors: the
## six keepsakes, the seance, the attic, the ward and Vessla Browntooth, to the Lord's thanks and the level paid at 4.
##
## Args after --: --out=/abs/act1.json [--seed=1] [--book-order=1] [--frames=150000] [--mode=balanced]
##   [--checkpoint=/abs/dir/slot] saves the game where the Express ends (the wreck after the farewell, ready to take the road) for --resume
##   [--resume=/abs/dir/slot] starts from that save instead of the title: the Express is taken as played
##   [--revive=1] brings a fallen hero back between steps and says so in the notes (Services.bring_back): a stand-in, since no one
##   in Wickermoor raises the dead yet; without it a party that loses two heroes cannot go on through the house

const GAME := preload("res://world/game_root.gd")

## Each place's plan: steps in order. A step: [kind, target, picks, opts?]. kind: talk (an NPC), use (click a prop: a call, a
## conversation, an examine), open (click a container: its loot is taken), check (a skill check on a prop: the check's id is the
## one pick), search (Search until the prop shows, then click it), exit (walk out by it; a stair to another floor of the same
## place counts when the party stands on another floor), saveload (a save made and loaded at once), rest (the Rest screen).
## picks: at each menu an enabled option containing the first of the "a|b|c" words it offers (a haint's own way first, "Draw a
## weapon" when the token or bottle it needs wasn't found); the last option once they run out. A pick waits for a menu that has
## it. opts: {"if": a story condition the step needs, else it is skipped}.
const PLAN := {
	"ghostlight_boarding": [["talk", "the_vagrant", ["fare", "Tell him something true|Check our pockets", "Check our pockets|ready to board", "ready to board"]]],
	"ghostlight_g1_passenger": [["talk", "the_vagrant", ["Go on to your cab"]], ["search", "g1_marble_jar", []],
		["talk", "phantom_trainhopper", []], ["use", "grille_g1", ["Understood"]], ["exit", "front_door", []]],
	"ghostlight_g2_sleeper": [["use", "g2_phonograph", ["Carry it with us"]], ["talk", "haint_sweetheart", ["bottle|Draw a weapon"]],
		["exit", "front_door", []]],
	"ghostlight_g3_lounge": [["search", "g3_seascape", []], ["search", "g3_whiskey_bottle", []],
		["talk", "haint_songstress", ["help you finish|Draw a weapon", "Sing the melody", "Trace the magic", "Speak the lonely word"]], ["exit", "front_door", []]],
	"ghostlight_g4_dining": [["use", "g4_big_booth", []], ["use", "g4_booth_n1", ["Steak and eggs", "Get up"]],
		["talk", "haint_daydreamer", ["empty glass jar|bottle|Draw a weapon"]], ["exit", "front_door", []]],
	"ghostlight_g5_mail": [["search", "g5_pink_envelope", []], ["talk", "haint_mariner", ["painting|Draw a weapon"]], ["exit", "front_door", []]],
	"ghostlight_g6_baggage": [["talk", "haint_jailbird", ["talk with you|Draw a weapon", "gallows custom", "hot plate", "campfire skillets"]],
		["exit", "front_door", []]],
	"ghostlight_g7_circus": [["talk", "haint_harlequin", ["Draw a weapon"]], ["exit", "front_door", []]],
	"ghostlight_g8_tender": [["use", "g8_firebox", []], ["use", "g8_tank", []]],
	"ghostlight_wreckage": [["talk", "phillip_druskenvald", []], ["talk", "the_vagrant", ["hum", "We'll go now"]],
		["search", "wr_soul_can_1", []], ["search", "wr_soul_can_2", []], ["search", "wr_soul_can_3", []],
		["talk", "the_vagrant", ["We have the cans", "Ready. Do it."]], ["use", "wr_moon", []], ["exit", "to_wickermoor", []]],
	# R11: the goat and the wolves at the well, the mayor's welcome at the notice board, the inn, the hill road.
	"wickermoor_village": [
		["use", "wm_sacrifice_doll", ["Keep back"]],
		["use", "wm_notice_board", ["Ask about the village", "Thank him", "glad to come"]],
		["exit", "green_queen_inn", []],
		["exit", "road_to_estate", [], {"to": "druskenvald_estate"}],
	],
	"wickermoor_green_queen_inn": [
		["talk", "alda_farnum", ["Ask about rooms and the inn", "Take our leave"]],
		["rest", "", []],
		["saveload", "", []],
		["exit", "door", []],
	],
	# R12: the Jenkins at the gate, the Crooked Man on the porch, then the house (one place, four floors). After Vessla the way
	# home: the Jenkins again, and Old Rusty's errand for Joseph Patrini's son when the seance asked after him.
	"druskenvald_estate": [
		["talk", "gilly_jenkin", ["Where are the two of you", "Have you seen the Lord", "What is the house like", "Walter seems on edge",
			"We'll go up to the house"], {"if": "not flag.crooked_house_turned"}],
		["talk", "crooked_man", ["Who are you?", "Where are Lord Phillip", "What do you want with us?", "Study him closely", "Feel the air",
			"Go inside"], {"if": "flag.crooked_house_turned and not flag.crooked_man_met"}],
		["exit", "porch_steps", [], {"if": "flag.crooked_man_met and not flag.vessla_slain"}],
		["talk", "gilly_jenkin", ["The house looks different", "Lord Phillip and Lady Adela are safe", "How is Dani",
			"Did you notice anything in the grounds", "That's all for now"], {"if": "flag.vessla_slain"}],
		["talk", "old_rusty", ["Say the name aloud"], {"if": "flag.patrini_asked_find_son and not flag.rusty_told_patrini"}],
	],
	# The Crooked House, one place with four floors: the keepsakes in the spine's order (the peacock's bloodstone, the harpsichord's
	# key, Petunia's cup, Sally's doll, Arthur's bear, the stuffed bear's pin), each way tried until one lands on the real dice; then
	# the board (all eight questions), the hatch it names, the six circles and the hag.
	"crooked_house": [
		# first floor
		["use", "h4_peacock", [], {"if": "not flag.memento_gem", "expect": "flag.memento_gem"}],
		["open", "h4_peacock_stone", [], {"if": "flag.memento_gem", "expect": "item:memento_bloodstone"}],
		["use", "h5_harpsichord", ["Sit at the bench", "Ask the dead servant", "Draw upon the lingering music", "Wait quietly"],
			{"if": "not flag.memento_key", "expect": "item:memento_black_key"}],
		# Her gentle way is spent when it fails; the next pick then takes whichever other way the menu still offers (the doll and the bear
		# when both are held, else the threat).
		["talk", "petunia_lockwood", ["Ask after her children", "Speak gently of Sally|Set the doll and the bear|Tell her you mean to have that cup",
			"Tell her you mean to have that cup"], {"if": "not flag.memento_cup", "expect": "flag.petunia_at_peace or flag.petunia_destroyed"}],
		["use", "h8_cup", ["Pick up the green ribbon"], {"if": "flag.petunia_destroyed and not flag.memento_cup", "expect": "item:memento_porcelain_cup"}],
		# second floor: the six hiding places until the lurker comes out, then Sally's doll
		["exit", "stairs_up", []],
		["check", "h10_closet", ["h10_closet"], {"if": "not quest.sallys_monsters == lurker_dead"}],
		["check", "h10_bed_left", ["h10_bed_left"], {"if": "not quest.sallys_monsters == lurker_dead"}],
		["check", "h10_bed_right", ["h10_bed_right"], {"if": "not quest.sallys_monsters == lurker_dead"}],
		["check", "h10_chest", ["h10_chest"], {"if": "not quest.sallys_monsters == lurker_dead"}],
		["check", "h10_armoire", ["h10_armoire"], {"if": "not quest.sallys_monsters == lurker_dead"}],
		["check", "h10_window", ["h10_window"], {"if": "not quest.sallys_monsters == lurker_dead"}],
		["use", "h10_doll", ["The monster is gone"], {"if": "not flag.memento_doll", "expect": "item:memento_wooden_doll"}],
		# third floor: the nursery's toys and bear, Arthur, the trophy room's stuffed bear
		["exit", "stairs_up_second", []],
		["use", "h13_crib", [], {"if": "not flag.memento_bear", "expect": "flag.memento_bear"}],
		["open", "h13_crib_bear", [], {"if": "flag.memento_bear", "expect": "item:memento_blue_bear"}],
		["talk", "arthur_lockwood", ["Speak low and steady", "Sit down with him"], {"if": "not flag.arthur_rested", "expect": "flag.arthur_rested"}],
		["use", "h15_bear", ["Cut the stitches"], {"if": "not flag.memento_pin", "expect": "item:memento_silver_pin"}],
		# back down to the parlour for the board, then up again to the hatch
		["exit", "stairs_down_third", []],
		["exit", "stairs_down_second", []],
		["use", "h3_spirit_board", ["Lay our fingertips", "Who are you?", "Who did this to you?", "Where are Phillip", "Who is behind all of this?",
			"How do we get out of here", "Where is the door to the attic?", "Who is the grey cat?", "What is Shuck", "That is enough", "Let him go"],
			{"expect": "flag.seance_done"}],
		["exit", "stairs_up", []],
		["exit", "stairs_up_second", []],
		["exit", "up_to_attic", []],
		# the attic: six circles, the ward, the hag
		["use", "h16_sockets", ["Look the circles over", "Set the bloodstone"]],
		["use", "h16_sockets", ["Set the black key"]],
		["use", "h16_sockets", ["Set the porcelain cup"]],
		["use", "h16_sockets", ["Set the wooden doll"]],
		["use", "h16_sockets", ["Set the blue bear"]],
		["use", "h16_sockets", ["Set the silver pin"]],
		["talk", "adela_druskenvald_ruse", ["Kneel beside the fallen woman", "Ask what happened to her", "Take her hand"],
			{"if": "not flag.vessla_slain"}],
		["talk", "phillip_druskenvald", ["What do the two of you remember", "Look at these two names", "Will you stay on",
			"What can you tell us about the Ghostlight", "That is all we need"], {"if": "flag.vessla_slain"}],
		# home: down the ladder and the stairs, out of the porch
		["exit", "ladder_down", [], {"if": "flag.vessla_slain"}],
		["exit", "stairs_down_third", [], {"if": "flag.vessla_slain"}],
		["exit", "stairs_down_second", [], {"if": "flag.vessla_slain"}],
		["exit", "to_estate", [], {"if": "flag.vessla_slain"}],
	],
}

var out_path := ""
var seed_value := 1
var book_order := true
var max_frames := 150000   ## frames to give the whole run: the Express alone is about 23000, the house up to 40000 more when fights run long
var mode := "balanced"
var checkpoint_path := ""    ## --checkpoint: where to save the game as the Express ends (a directory and a slot)
var resume_path := ""        ## --resume: a save to start from instead of the title
var revive := false          ## --revive=1: a fallen hero is brought back between steps (a QA stand-in; nothing in the game raises one yet)

var root: Node = null       ## GameRoot once the game scene is up
var frame := 0
var blockers: Array[Dictionary] = []
var notes: Array[String] = []
var steps: Array[Dictionary] = []
var fights: Array[Dictionary] = []
var toasts: Array[String] = []
var _tried_help: Dictionary = {}
var choices: Array[String] = []   ## every option chosen: "<place> <file>:<node> > <text>"
var roster: Array[String] = []
var _pilot: PartyAutopilot = null
var _pilot_e: Encounter = null
var _fight_rounds := 0
var _done: Dictionary = {}   ## "loc|i" -> true
var _rolls := 0              ## skill checks the view has rolled
var _tries: Dictionary = {}  ## "loc|i" -> how many times a step with an `expect` has been tried
var _map_busy := false       ## the travel map is showing the party's walk to the place it set out for
var _want_destination := ""  ## the place to pick if the travel map opens (an exit step's opts "to")
var _checkpointed := false


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
	checkpoint_path = str(args.get("checkpoint", ""))
	resume_path = str(args.get("resume", ""))
	revive = str(args.get("revive", "0")) == "1"
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
		"fights": fights, "toasts": toasts, "stage": _stage_key(),
		"location": GameState.story.location, "quests": _quests(), "party": _party_line(), "choices": choices}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("qa: act 1 %s, %d blockers, stage %s at %s, party %s" % [end, blockers.size(), report["stage"], report["location"], report["party"]])
	get_tree().quit(0)


func _quests() -> Dictionary:
	var out := {}
	for q: String in GameState.story.quests:
		out[q] = GameState.story.quest_stage(q)
	return out


## The three main quests' stages in one line: any change of it is the story moving on.
func _stage_key() -> String:
	var st := GameState.story
	return "%s/%s/%s" % [st.quest_stage("ghostlight_express"), st.quest_stage("wickermoor_arrival"), st.quest_stage("the_crooked_house")]


func _block(what: String, detail: String) -> void:
	var st := GameState.story
	blockers.append({"what": what, "detail": detail, "location": st.location, "stage": _stage_key(),
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
	if resume_path != "":
		return await _play_from_save(menu)
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
	return await _plan_loop()


## Starts from a save (--resume=<dir>/<slot>) the way the title's Load does; the Express is taken as played.
func _play_from_save(menu: Node) -> String:
	var slot := resume_path.get_file()
	var dir := resume_path.get_base_dir()
	var err := SaveSystem.load_from(dir, slot)
	if err != OK:
		_block("resume", "the save %s didn't load (error %d)" % [resume_path, err])
		return "blocked_resume"
	var menu_id := menu.get_instance_id()   # the menu is freed when the game replaces it: only its id is kept
	menu.get_tree().change_scene_to_file("res://scenes/game.tscn")
	var up := await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.get("view") != null \
		and get_tree().current_scene.get_instance_id() != menu_id, 900)
	if not up:
		_block("start", "the game scene never came up after loading %s" % resume_path)
		return "blocked_start"
	root = get_tree().current_scene
	Dice.reseed(seed_value)   # the save held the dice where the first run left them: every seed plays its own rolls from here
	notes.append("Resumed from %s: %s" % [resume_path, _party_line()])
	_listen(root.get("view") as LocationView)
	for place: String in PLAN:
		if place.begins_with("ghostlight_"):
			var plan := PLAN[place] as Array
			for i in plan.size():
				if not (place == "ghostlight_wreckage" and i == plan.size() - 1):
					_done["%s|%d" % [place, i]] = true
	await _until(_idle, 1200)
	return await _plan_loop()


## The plan, place by place, until the Crooked House is done (Vessla dead, the Lord thanked, the party home at the estate).
func _plan_loop() -> String:
	var guard := 0
	while frame < max_frames and guard < 400:
		guard += 1
		var st := GameState.story
		if root.get("ending") != null or _game_over():
			_block("game_over", "the game ended (the party fell where no retry catches it)")
			return "game_over"
		if checkpoint_path != "" and not _checkpointed and bool(st.get_flag("gl_last_stop")) and st.location == "ghostlight_wreckage" \
				and _idle():
			_checkpointed = true
			DirAccess.make_dir_recursive_absolute(checkpoint_path.get_base_dir())
			var err := AtomicJson.write(checkpoint_path.get_base_dir().path_join(checkpoint_path.get_file() + ".json"), GameState.to_dict())
			notes.append("Checkpoint %s saved (error %d)" % [checkpoint_path, err])
		var here := st.location
		if Travel.is_road_scene(here):
			# A journey stopped on its road by a meeting or a fight; the road goes on by itself once that is dealt with.
			notes.append("on the road at %s (stage %s)" % [here, _stage_key()])
			if not await _until(func() -> bool: return not Travel.is_road_scene(st.location) and _idle(), 6000):
				_block("road", "the journey stopped at %s and never went on (screen: %s)" % [here, _screen()])
				return "stuck_on_road"
			continue
		if st.quest_stage("the_crooked_house") == "done" and bool(st.get_flag("druskenvald_manor_restored")) and here == "druskenvald_estate" \
				and _next_step(here) < 0:
			await _level_ups()
			return "done"
		var plan := PLAN.get(here, []) as Array
		if plan.is_empty():
			if here == CrookedMoonCampaign.limbo_place():
				await _do(["exit", "onward", []], "mist")
				continue
			_block("place", "no plan for '%s' (the party arrived somewhere the book's route doesn't go)" % here)
			return "blocked_place"
		await _level_ups()
		_revive_the_fallen()
		await _rest_if_hurt()
		var at := _next_step(here)
		if at < 0:
			_block("stuck", "every step of %s's plan is done or not due and the party is still here (stages %s)" % [here, _stage_key()])
			return "stuck"
		var key := "%s|%d" % [here, at]
		_done[key] = true
		var step := plan[at] as Array
		await _do(step, here)
		# A step that names what it should have brought (opts "expect") is tried again, up to three times, then reported.
		if step.size() > 3 and (step[3] as Dictionary).has("expect") and not StoryConditions.check(str((step[3] as Dictionary)["expect"]), st):
			_tries[key] = int(_tries.get(key, 0)) + 1
			if int(_tries[key]) < 3:
				_done.erase(key)
				notes.append("%s %s did not bring %s; trying again" % [step[0], step[1], (step[3] as Dictionary)["expect"]])
			else:
				_block("expect", "%s %s in %s three times and still not %s (stages %s)" % [step[0], step[1], here, (step[3] as Dictionary)["expect"], _stage_key()])
	return "out_of_frames"


## --revive: heroes who are dead come back at full Hit Points, each time noted.
func _revive_the_fallen() -> void:
	if not revive:
		return
	var st := GameState.story
	for ch in st.party:
		if ch.dead:
			Services.bring_back(st, ch, true, false, "QA stand-in")
			notes.append("%s: %s was dead and is brought back (the --revive stand-in) at stage %s" % [st.location, ch.name, _stage_key()])


## The first step of this place's plan not done yet whose condition (opts "if") holds, or -1.
func _next_step(here: String) -> int:
	var plan := PLAN.get(here, []) as Array
	for i in plan.size():
		if _done.has("%s|%d" % [here, i]):
			continue
		var step := plan[i] as Array
		if _tries.has("%s|%d" % [here, i]):
			return i   # a step tried again for what it should have brought, whatever its condition says now
		if step.size() > 3 and not StoryConditions.check(str((step[3] as Dictionary).get("if", "")), GameState.story):
			continue
		return i
	return -1


var _listening: Dictionary = {}


## What the place says to the player (toasts, the Narrator's lines, rolls), kept for the report: a view is made anew
## on every change of place, so each one is listened to as it comes.
func _listen(v: LocationView) -> void:
	if v == null or _listening.has(v.get_instance_id()):
		return
	_listening[v.get_instance_id()] = true
	v.toast.connect(func(t: String) -> void: toasts.append("%s: %s" % [v.loc_id, t]))
	v.narration.connect(func(t: String) -> void: toasts.append("%s (narration): %s" % [v.loc_id, t]))
	v.check_rolled.connect(func(t: String) -> void:
		_rolls += 1
		toasts.append("%s (roll): %s" % [v.loc_id, t]))


func _travel_open() -> bool:
	var scr: Variant = root.get("screen") if root != null else null
	return scr is TravelScreen or scr is OverworldScreen


## The travel map is up (a road out that leads to a choice of places opens it): picks `to` as a player does, its name on the map and
## then Set out. False, with a blocker, when the map doesn't offer it or won't let the party set out.
func _choose_destination(to: String) -> bool:
	var scr: Node = root.get("screen")
	var offered: Array[String] = []
	if scr is OverworldScreen:
		for p: Dictionary in (scr as OverworldScreen).destinations():
			offered.append(str(p["id"]))
	if to == "" or (scr is OverworldScreen and not to in offered):
		_block("travel", "the travel map doesn't offer %s (it offers: %s)" % [to, ", ".join(offered)])
		root.call("close_screen")
		return false
	scr.call("select", to)
	await _frames(3)
	if not _press(scr, "Set out"):
		root.call("close_screen")
		return false
	_map_busy = true
	notes.append("%s: on the travel map chose %s and set out" % [GameState.story.location, to])
	return true


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


## A hurt party rests as a player would: the Rest screen, a Short Rest (Hit Point Dice spent as it plans them), and a
## Long Rest when the place allows one and someone is still under half. What the screen refuses, and why, is noted.
var _rested_at := -1


func _rest_if_hurt() -> void:
	var st := GameState.story
	var hurt := st.party.any(func(ch: Character) -> bool: return not ch.dead and ch.hp * 2 < ch.max_hp())
	if not hurt or _rested_at == st.total_minutes():
		return
	_rested_at = st.total_minutes()
	root.call("open_screen", "rest", 0)
	await _frames(4)
	var scr: Variant = root.get("screen")
	if not scr is RestScreen:
		notes.append("%s: the Rest screen didn't open" % st.location)
		return
	var rs := scr as RestScreen
	var before := _party_line()
	var why := rs._short_refusals()
	if why.is_empty():
		rs.heal_up()
		rs._finish_short()
		await _frames(4)
	else:
		notes.append("%s: Short Rest refused: %s" % [st.location, " ".join(why)])
	var long_why := RestRules.long_rest_refusals(st)
	if long_why.is_empty() and st.party.any(func(ch: Character) -> bool: return not ch.dead and ch.hp * 2 < ch.max_hp()):
		var all: Array[Button] = []
		_buttons(rs, all)
		for b in all:
			if (b.text.begins_with("Take a Long Rest") or b.text.begins_with("Make camp") or b.text.begins_with("Sleep")) and not b.disabled:
				b.pressed.emit()
				break
		await _until(_idle, 3000)
	elif not long_why.is_empty():
		notes.append("%s: Long Rest refused: %s" % [st.location, " ".join(long_why)])
	if root.get("screen") != null:
		root.call("close_screen")
		await _frames(2)
	if before != _party_line():
		notes.append("%s: rested. Before: %s. After: %s" % [st.location, before, _party_line()])


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
			var why := ""
			if scr is LevelUpScreen and (scr as LevelUpScreen).ctl != null:
				var ctl := (scr as LevelUpScreen).ctl
				# Picks start blank by design; the player presses Use Recommended to fill every open one.
				var use := _button_named(scr as Node, "Use Recommended")
				if use != null and not use.disabled:
					use.pressed.emit()
					await _frames(2)
				elif ctl.errors().size() > 0:
					notes.append("%s, going to level %d: no Use Recommended button to press" % [ch.name, ch.character_level() + 1])
				why = "; ".join(ctl.errors())
				if why != "":
					# What Use Recommended left open, the player picks by hand: here the first legal options.
					_block("level_up", "%s, going to level %d: Use Recommended leaves choices open (%s); the run picks the first options by hand" % [
						ch.name, ch.character_level() + 1, why])
					for guard2 in 6:
						var open := ctl.pending_choices()
						if open.is_empty():
							break
						for c in open:
							var picks: Array = c.picks.duplicate()
							for o in c.options:
								if picks.size() >= c.count:
									break
								if o.legal and not o.id in picks:
									picks.append(o.id)
							ctl.choose(c.key, picks)
				(scr as LevelUpScreen)._confirm()
			else:
				why = "the screen had no level to take"
			await _frames(4)
			if root.get("screen") != null:
				root.call("close_screen")
				await _frames(2)
			if ch.character_level() == was:
				_block("level_up", "%s can go up to level %d, but the Level Up screen won't confirm even with every choice filled: %s" % [
					ch.name, st.target_level(), "; ".join((scr as LevelUpScreen).ctl.errors()) if scr is LevelUpScreen and (scr as LevelUpScreen).ctl != null else why])
				break
			notes.append("%s levels up to %d" % [ch.name, ch.character_level()])


static func _button_named(n: Node, text: String) -> BaseButton:
	if n is Button and (n as Button).text == text:
		return n as BaseButton
	for c in n.get_children():
		var b := _button_named(c, text)
		if b != null:
			return b
	return null


func _idle() -> bool:
	var v: LocationView = root.get("view")
	return root.get("dialogue") == null and root.get("loot") == null and v != null and not v.busy and not v.in_combat \
		and not bool(root.get("moving")) and v._queue.is_empty() and not v._on_arrive.is_valid() \
		and not _prompt_up() and root.get("screen") == null


## A question over the place that waits for an answer: Guidance before a check, or an aid to spend on a failed one.
func _prompt_up() -> bool:
	var g: Variant = root.get("guidance")
	var a: Variant = root.get("_prompting")
	return (g != null and is_instance_valid(g as Object)) or (a != null and is_instance_valid(a as Object))


# --- Steps -------------------------------------------------------------------------------------------

## The square of a prop, container, door or exit of this place by its id, or null.
func _cell_of(v: LocationView, id: String) -> Variant:
	var c: Variant = v.prop_cell(id)
	if c != null:
		return c
	for key: String in ["containers", "doors"]:
		for t: Variant in v.loc.get(key, []):
			if str((t as Dictionary).get("id", "")) == id:
				return LocationView._cell((t as Dictionary)["cell"])
	return null


## The floor of the place the leader stands on (a multi-floor place's stairs are exits to the place itself).
func _floor_of(v: LocationView) -> int:
	return v.grid.floor_index(v.leader().cell)


func _do(step: Array, here: String) -> void:
	var kind := str(step[0])
	var target := str(step[1])
	var picks := (step[2] as Array).duplicate()
	var st := GameState.story
	var before := _stage_key()
	var rec := {"place": here, "step": "%s %s" % [kind, target], "frame": frame}
	printerr("qa: step %s %s in %s at frame %d" % [kind, target, here, frame])   # on stderr, so it lands among the engine's own errors in the log
	await _until(_idle, 1200)
	var v: LocationView = root.get("view")
	_listen(v)
	if kind == "saveload":
		await _save_and_load()
		rec["result"] = "saved and loaded"
		steps.append(rec)
		return
	if kind == "rest":
		await _take_a_room()
		rec["result"] = "rested"
		steps.append(rec)
		return
	var cell := Vector2i(-1, -1)
	var exit_within := false
	_want_destination = str((step[3] as Dictionary).get("to", "")) if step.size() > 3 else ""
	match kind:
		"talk":
			for e: Dictionary in v._npc_shown:
				if str((e["spec"] as Dictionary).get("npc", "")) == target:
					cell = e["cell"] as Vector2i
					break
			if cell.x < 0:
				# Not a blocker by itself: the story may have moved past them (the Phantom comes at the party on its own).
				notes.append("%s isn't standing in %s to talk to (stage %s); step skipped" % [target, here, _stage_key()])
		"use", "open", "check":
			var c: Variant = _cell_of(v, target)
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
					exit_within = str(e["to"]) == v.loc_id
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
	var floor_before := _floor_of(v)
	var rolls_before := _rolls
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
	var check_id := target
	if kind == "check":
		check_id = str(picks[0]) if not picks.is_empty() else target
		picks = []   # the check's id is not a menu pick
	var heard := [false]
	var settle := [0]
	var toasts_before := toasts.size()
	var reached := func() -> bool:
		if st.location != loc_before:
			return true
		if kind == "exit":
			return exit_within and _floor_of(root.get("view") as LocationView) != floor_before
		if kind == "search":
			return bool((st.loc_state(st.location)["props"] as Dictionary).get(target, false))
		if kind == "open":
			return bool((st.loc_state(st.location)["looted"] as Dictionary).get(target, false))
		if kind == "check":
			return _rolls > rolls_before
		if str(root.get("_dialogue_ref")) in want_refs and root.get("dialogue") != null:
			heard[0] = true
		if heard[0] or _stage_key() != before:
			return true
		var lv: LocationView = root.get("view")
		if lv != null and lv.in_combat:
			return true
		if kind == "use" and want_refs.all(func(r: String) -> bool: return r == "") and lv != null and lv.leader() != null:
			# A prop with no conversation of its own is used by standing beside it with nothing more coming (a fight, a line).
			var at := lv.leader().cell
			if maxi(absi(at.x - cell.x), absi(at.y - cell.y)) <= 1 and _idle():
				settle[0] += 1
			else:
				settle[0] = 0
			return settle[0] >= 8
		return false
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
		if kind == "check":
			root.call("world_action", cell, "check:" + check_id)
		else:
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
	rec["stage"] = _stage_key()
	rec["now_at"] = st.location
	rec["party"] = _party_line()
	rec["quests"] = _quests()
	steps.append(rec)


## A save made through the game's own quick save and loaded again as the Continue button does (the scene is rebuilt): nothing the
## story holds may differ, and the party must stand where it stood.
func _save_and_load() -> void:
	var st := GameState.story
	var v: LocationView = root.get("view")
	var where := st.location
	var at := v.leader().cell
	var before := JSON.stringify(st.to_dict().get("story", {}), "", true)
	root.call("_quick_save")
	await _frames(5)
	var slot := SaveSystem.current_slot
	if slot == "" or not SaveSystem.has_slot(slot):
		_block("save", "the quick save wrote no slot (current slot '%s')" % slot)
		return
	var err := SaveSystem.load_slot(slot)
	if err != OK:
		_block("load", "the save %s didn't load (error %d)" % [slot, err])
		return
	var old_id := root.get_instance_id()   # the old game scene is freed by the reload: only its id is kept
	get_tree().reload_current_scene()
	var up := await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.get_instance_id() != old_id \
		and get_tree().current_scene.get("view") != null, 900)
	if not up:
		_block("load", "the game scene never came back after loading %s" % slot)
		return
	root = get_tree().current_scene
	await _until(_idle, 1200)
	_listen(root.get("view") as LocationView)
	st = GameState.story
	v = root.get("view")
	var after := JSON.stringify(st.to_dict().get("story", {}), "", true)
	if st.location != where:
		_block("load", "the load put the party in %s, not %s" % [st.location, where])
	elif v.leader().cell != at:
		notes.append("%s: saved with the leader at %s, loaded at %s" % [where, at, v.leader().cell])
	var diffs: Array[String] = []
	_differences(JSON.parse_string(before), JSON.parse_string(after), "", diffs)
	if not diffs.is_empty():
		_block("load", "after a save and a load the story differs (%d): %s" % [diffs.size(), "; ".join(diffs.slice(0, 8))])
	else:
		notes.append("%s: saved to %s and loaded; the story, the party and the place are as they were" % [where, slot])
	# The game goes on from the loaded scene: the plan's progress is the driver's own, and the story's flags came back with it.


## Where two saved values differ, as paths ("flags.x: true -> <none>").
func _differences(a: Variant, b: Variant, path: String, out: Array[String]) -> void:
	if a is Dictionary and b is Dictionary:
		var keys: Dictionary = {}
		for k: Variant in (a as Dictionary).keys() + (b as Dictionary).keys():
			keys[k] = true
		for k: Variant in keys:
			_differences((a as Dictionary).get(k, "<none>"), (b as Dictionary).get(k, "<none>"), "%s.%s" % [path, k], out)
	elif a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for i in (a as Array).size():
			_differences((a as Array)[i], (b as Array)[i], "%s[%d]" % [path, i], out)
	elif typeof(a) != typeof(b) or a != b:
		out.append("%s: %s -> %s" % [path.trim_prefix("."), str(a).left(60), str(b).left(60)])


## The night at the inn: the services screen's room if the keeper lets one, else the Rest screen; what is refused is noted.
func _take_a_room() -> void:
	var st := GameState.story
	root.call("open_screen", "rest", 0)
	await _frames(4)
	var scr: Variant = root.get("screen")
	if not scr is RestScreen:
		notes.append("%s: the Rest screen didn't open" % st.location)
		return
	var rs := scr as RestScreen
	var long_why := RestRules.long_rest_refusals(st)
	if long_why.is_empty():
		var all: Array[Button] = []
		_buttons(rs, all)
		var taken := false
		for b in all:
			if (b.text.begins_with("Take a Long Rest") or b.text.begins_with("Make camp") or b.text.begins_with("Sleep")) and not b.disabled:
				b.pressed.emit()
				taken = true
				break
		if taken:
			await _until(_idle, 3000)
			notes.append("%s: took a Long Rest from the Rest screen" % st.location)
		else:
			var seen: Array[String] = []
			for b in all:
				seen.append(b.text + (" (disabled)" if b.disabled else ""))
			notes.append("%s: the Rest screen offers no Long Rest button (buttons: %s)" % [st.location, ", ".join(seen)])
	else:
		notes.append("%s: Long Rest refused: %s" % [st.location, " ".join(long_why)])
	if root.get("screen") != null:
		root.call("close_screen")
		await _frames(2)


# --- What comes up: conversations, fights, loot --------------------------------------------------------

func _drive(picks: Array) -> void:
	if root != null and not _travel_open():
		_map_busy = false
	if root != null and _travel_open():
		if _map_busy:
			return   # the party is walking the map to the place it set out for; the map hands back when it arrives
		if _want_destination == "":
			_block("travel", "a travel map opened where the plan wanted none (stage %s)" % _stage_key())
			root.call("close_screen")
		else:
			var to := _want_destination
			_want_destination = ""   # one try; a refusal is a blocker
			await _choose_destination(to)
		return
	if root != null:
		var g: Variant = root.get("guidance")
		if g != null and is_instance_valid(g as Object):
			(g as Object).call("_answer", -1)   # no Guidance cast
			return
		var a: Variant = root.get("_prompting")
		if a != null and is_instance_valid(a as Object):
			(a as Object).call("_answer", "")   # the failure stands
			return
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
		for w: String in want.split("|"):
			for j in d._option_buttons.size():
				if d._option_buttons[j].disabled or j >= opts.size():
					continue
				if str((opts[j] as Dictionary).get("text", "")).contains(w):
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
	# Out of picks while talking a haint round (its `help` menu): the approaches not tried yet, before stepping back,
	# as a player keeps at it until three land or three fall flat.
	if pick < 0 and picks.is_empty() and d.runner != null and d.runner.node == "help":
		for j in d._option_buttons.size():
			if j == last or d._option_buttons[j].disabled or j >= opts.size():
				continue
			var key := "%s:%s" % [d.runner.file.key if d.runner.file != null else "", str((opts[j] as Dictionary).get("text", ""))]
			if not _tried_help.has(key):
				_tried_help[key] = true
				pick = j
				break
	if pick < 0:
		pick = last
	if pick < 0:
		_block("menu", "a menu with nothing to choose (%s)" % _screen())
		return
	choices.append("%s %s:%s > %s" % [GameState.story.location, d.runner.file.key if d.runner != null and d.runner.file != null else "?",
		d.runner.node if d.runner != null else "?", str((opts[pick] as Dictionary).get("text", "")) if pick < opts.size() else "?"])
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
