extends TestCase
## Ashwin, 2026-11-02: the opening shouldn't open straight into the Vagrant's talk; the party looks round the hill and talks to him
## when it is ready, and the same aboard the train. Neither of his entries speaks first, the ways on stay shut until he has been
## talked to, and a talk mark (world/talk_marks.gd, data/talk_marks.json) hangs over him until then. Ashwin, 2026-11-03: the same for
## everyone in the opening act: the haints, the Druskenvalds and the Vagrant at the wreck wait to be clicked, the companions' scenes on the
## train start from the things they are about, and only the story's own beats (the Phantom's ambush, the briefing after it, the Tender,
## the crash, the farewell, the clearing's rim and the banter Ashwin asked for in the Passenger Car) still begin by themselves.

const HILL := "ghostlight_boarding"
const CAR := "ghostlight_g1_passenger"


func after_each() -> void:
	GameState.reset()


func _party() -> StoryState:
	GameState.reset()
	var st := GameState.story
	for id: String in ["rook_coldwake", "cordelia_skein", "delphine_ravelle", "lucan_houndstooth"]:
		var ch := Pregens.build(id, 1)
		if ch != null:
			ch.finish_long_rest()
			st.party.append(ch)
	return st


func _vagrant(loc: String) -> Dictionary:
	for n: Variant in Compendium.shared().get_entry("locations", loc).get("npcs", []):
		if str((n as Dictionary)["npc"]) == "the_vagrant":
			return n as Dictionary
	return {}


func _exit(loc: String, id: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", loc).get("exits", []):
		if str((e as Dictionary)["id"]) == id:
			return e as Dictionary
	return {}


func test_the_vagrant_waits_to_be_talked_to_on_the_hill_and_aboard() -> void:
	for loc: String in [HILL, CAR]:
		var spec := _vagrant(loc)
		assert_false(spec.is_empty(), "the Vagrant stands in %s" % loc)
		assert_eq(int(spec.get("approach", 0)), 0, "%s: he doesn't speak first" % loc)
		assert_true(str(spec.get("dialogue", "")) != "", "%s: walking up to him starts his talk" % loc)


func test_the_ways_on_stay_shut_until_he_has_been_talked_to() -> void:
	var st := _party()
	var board := _exit(HILL, "board_train")
	assert_false(StoryConditions.check(str(board["when"]), st), "nobody boards before he shows them aboard")
	st.set_flag("gl_boarded")
	assert_true(StoryConditions.check(str(board["when"]), st))
	var door := _exit(CAR, "front_door")
	assert_false(StoryConditions.check(str(door["when"]), st), "the next car waits for the Phantom, which waits for his welcome")
	assert_true(str(door.get("locked_text", "")).contains("Vagrant"), "before his welcome the door says who is waiting")


func test_the_talk_mark_hangs_over_him_until_the_talk_begins() -> void:
	var st := _party()
	assert_eq(TalkMarks.waiting(HILL, st), ["the_vagrant"] as Array[String], "on the hill, before the greeting")
	st.set_flag("gl_greeted")
	assert_true(TalkMarks.waiting(HILL, st).is_empty(), "greeted: no mark")
	st.set_flag("gl_boarded")
	assert_eq(TalkMarks.waiting(CAR, st), ["the_vagrant"] as Array[String], "in the car, before the welcome")
	st.set_flag("gl_aboard_welcomed")
	assert_true(TalkMarks.waiting(CAR, st).is_empty(), "welcomed: no mark")


## On the hill the party walks right up beside him and nothing starts; the mark is over him, and goes once he has greeted them.
func test_walking_up_to_him_on_the_hill_starts_nothing() -> void:
	var st := _party()
	st.location = ""
	var view := LocationView.create(HILL, st, Narrator.new(), Dice.roller, "default")
	add_child(view)
	await get_tree().process_frame
	var asked: Array[String] = []
	view.dialogue_requested.connect(func(ref: String, _npc: String) -> void: asked.append(ref))
	var marks := TalkMarks.create(view)
	view.add_child(marks)
	var at := LocationView._cell(_vagrant(HILL)["cell"])
	for step: Vector2i in [Vector2i(-4, 2), Vector2i(-2, 1), Vector2i(-1, 0)]:
		view.leader().cell = at + step
		LocationWalk._check_cell_events(view)
	assert_true(asked.is_empty(), "coming up beside him starts no talk (got %s)" % [asked])
	var tok := view.npc_tokens["the_vagrant"] as CombatToken
	marks.refresh()
	assert_true(tok.get_node_or_null(TalkMarks.NAME) != null, "the talk mark is over him")
	st.set_flag("gl_greeted")
	marks.refresh()
	assert_true(tok.get_node_or_null(TalkMarks.NAME) == null, "and goes once he has greeted the party")
	view.queue_free()
	await get_tree().process_frame


## Ashwin, 2026-11-02: the brass grille floated in the middle of every car. It draws nothing now, and its square still brings the
## Vagrant over the intercom.
func test_the_grille_draws_nothing_and_still_answers() -> void:
	for n: int in range(1, 8):
		var id := "grille_g%d" % n
		assert_true(SetDressing.look_for({"id": id, "model": "window"}) == {"art": ""}, "%s is an unseen spot" % id)
	for p: Variant in Compendium.shared().get_entry("locations", CAR).get("props", []):
		if str((p as Dictionary)["id"]) == "grille_g1":
			assert_eq(str((p as Dictionary).get("dialogue", "")), "ghostlight_express/vagrant_intercom:grille", "the grille still talks")
			return
	assert_true(false, "the Passenger Car keeps its grille")


const TRAIN: Array[String] = ["ghostlight_boarding", "ghostlight_g1_passenger", "ghostlight_g2_sleeper", "ghostlight_g3_lounge",
	"ghostlight_g4_dining", "ghostlight_g5_mail", "ghostlight_g6_baggage", "ghostlight_g7_circus", "ghostlight_g8_tender",
	"ghostlight_wreckage"]
## The beats that still start by themselves, and why: the Phantom is an ambush (a fight, not a talk).
const SPEAKS_FIRST: Array[String] = ["phantom_trainhopper"]
## Props that still call out: the banter halfway down the Passenger Car (Ashwin, 2026-11-02), the Vagrant's briefing straight after
## the Phantom's fight, the Tender's opening and the crash, the farewell once the engine is free, and the clearing's rim (walking off).
const CALLS: Array[String] = ["g1_windows", "grille_g1", "grille_g2", "grille_g3", "grille_g4", "grille_g5", "grille_g6", "grille_g7",
	"g8_firebox", "g8_tank", "wr_moon", "wr_rim_w", "wr_rim_n", "wr_rim_s"]


func test_nobody_on_the_train_speaks_first_but_the_phantom() -> void:
	for loc: String in TRAIN:
		for n: Variant in Compendium.shared().get_entry("locations", loc).get("npcs", []):
			var spec := n as Dictionary
			if int(spec.get("approach", 0)) > 0:
				assert_true(SPEAKS_FIRST.has(str(spec["npc"])), "%s: %s waits to be clicked" % [loc, spec["npc"]])


func test_only_the_story_beats_call_out_on_the_train() -> void:
	for loc: String in TRAIN:
		for p: Variant in Compendium.shared().get_entry("locations", loc).get("props", []):
			var prop := p as Dictionary
			if int(prop.get("approach", 0)) > 0 and str(prop.get("call", "")) != "":
				assert_true(CALLS.has(str(prop["id"])), "%s: %s starts nothing on walking past" % [loc, prop["id"]])


## The companions' scenes on the train begin when the party looks at the thing they are about; once had (or noted for the camp,
## without the companion) the same look gives the object's plain line.
func test_the_companions_scenes_start_from_their_objects() -> void:
	var scenes := {"ghostlight_g1_passenger": ["g1_curse_mist", "deliverance"], "ghostlight_g5_mail": ["g5_gambler_letter", "liberation"],
		"ghostlight_g6_baggage": ["g6_medical_bag", "evolution"], "ghostlight_g7_circus": ["g7_poster", "ascendancy"]}
	for loc: String in scenes:
		var want := scenes[loc] as Array
		var found := false
		for p: Variant in Compendium.shared().get_entry("locations", loc).get("props", []):
			var prop := p as Dictionary
			if str(prop["id"]) != str(want[0]):
				continue
			found = true
			assert_eq(str(prop.get("dialogue", "")), "ghostlight_express/incitements:%s_enter" % want[1], "%s: a click starts it" % want[0])
			assert_eq(int(prop.get("approach", 0)), 0, "%s: walking in starts nothing" % want[0])
		assert_true(found, "%s keeps %s" % [loc, want[0]])
	var file := DialogueFile.load_key("ghostlight_express/incitements")
	assert_true(file != null, "the incitements file reads")
	if file != null:
		for t: String in ["deliverance", "liberation", "evolution", "ascendancy"]:
			assert_true(file.nodes.has("%s_enter" % t), "%s_enter is there" % t)


func test_the_train_folk_wear_the_talk_mark_until_talked_to() -> void:
	var st := _party()
	for pair: Array in [["ghostlight_g2_sleeper", "haint_sweetheart"], ["ghostlight_g3_lounge", "haint_songstress"],
			["ghostlight_g4_dining", "haint_daydreamer"], ["ghostlight_g5_mail", "haint_mariner"], ["ghostlight_g6_baggage", "haint_jailbird"],
			["ghostlight_g7_circus", "haint_harlequin"]]:
		var loc := str(pair[0])
		var who := str(pair[1])
		assert_true(TalkMarks.waiting(loc, st).has(who), "%s waits to be talked to" % who)
		st.set_flag(who + "_met")
		assert_false(TalkMarks.waiting(loc, st).has(who), "%s: met, no mark" % who)
	assert_true(TalkMarks.waiting("ghostlight_g3_lounge", st).has("phillip_druskenvald"), "the Druskenvalds at the bar")
	st.set_flag("gl_lounge_met")
	assert_false(TalkMarks.waiting("ghostlight_g3_lounge", st).has("phillip_druskenvald"))
	var wreck := TalkMarks.waiting("ghostlight_wreckage", st)
	assert_true(wreck.has("the_vagrant") and wreck.has("phillip_druskenvald"), "the Vagrant and the Druskenvalds at the wreck")
	st.set_flag("gl_wreck_met")
	st.set_flag("gl_wreck_pair_met")
	assert_true(TalkMarks.waiting("ghostlight_wreckage", st).is_empty(), "both talked to: no marks")
