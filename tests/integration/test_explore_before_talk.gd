extends TestCase
## Ashwin, 2026-11-02: the opening shouldn't open straight into the Vagrant's talk; the party looks round the hill and talks to him
## when it is ready, and the same aboard the train. Neither of his entries speaks first, the ways on stay shut until he has been
## talked to, and a talk mark (world/talk_marks.gd, data/talk_marks.json) hangs over him until then.

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
