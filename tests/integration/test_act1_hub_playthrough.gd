extends TestCase
## Act I's second half in one story: test_r10_playthrough's whole Express walk, then the wreck's road to Wickermoor, R11's spine (the
## goat and the wolves at the well, the mayor's welcome at the notice board, the Green Queen Inn with a save made and loaded in it,
## the hill road) and R12's whole house (the Jenkins, the Crooked Man, the six keepsakes, the board, the hatch, the six circles, the
## hag, the Lord's thanks, the way home), to Vessla dead and the party at level 4. One StoryState goes through all of it: the helpers
## are the two walks' own (test_r10_playthrough, test_r12_paths: a person is only talked to while their entry's `when` holds, a
## prop's call fires once when its `when` and `call_when` hold, an exit only opens while its `when` does), and what this file adds
## is the joins between them: the road legs the way the game works them out (Travel), an exit's `sets_quest`, the heroes' level
## taken at the milestone count the story has paid, and the save and load at the inn. The dice always roll high, as in both walks.
## The same stretch is played in the real game by tools/qa/act1_player.gd (make qa-act1), with real dice.

const R10 := preload("res://tests/integration/test_r10_playthrough.gd")
const R12 := preload("res://tests/integration/test_r12_paths.gd")

const WRECK := "ghostlight_wreckage"
const TOWN := "wickermoor_village"
const INN := "wickermoor_green_queen_inn"
const ESTATE := "druskenvald_estate"

var st: StoryState
var r10: R10 = null
var r12: R12 = null


func after_each() -> void:
	for h: Node in [r10, r12]:
		if h != null and is_instance_valid(h):
			h.free()
	r10 = null
	r12 = null
	GameState.reset()


## The failures a helper walk recorded are this test's.
func _collect(from: TestCase, what: String) -> void:
	for f: String in from.failures:
		fail("%s: %s" % [what, f])
	from.failures.clear()


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", st.location)


func _exit_entry(id: String) -> Dictionary:
	for e: Variant in _loc().get("exits", []):
		if str((e as Dictionary).get("id", "")) == id:
			return e as Dictionary
	return {}


## Walks out by `exit` of the place the party stands in, as LocationWalk does: the exit must be open, its `sets_quest` moves the quest
## on from the stages it lists, a way to another place sets the party down at its spawn, and a road (`to: travel`) is worked out leg
## by leg as the game's travel does it (Travel.route: the hours pass, the party arrives at the place the road leads to).
func _go(exit: String, destination: String = "") -> void:
	var e := _exit_entry(exit)
	assert_true(not e.is_empty(), "%s has the exit %s" % [st.location, exit])
	if e.is_empty():
		return
	assert_true(StoryConditions.check(str(e.get("when", "")), st), "%s: the exit %s is open (%s)" % [st.location, exit, e.get("locked_text", "")])
	if str(e["to"]) != "travel":
		# Only a way to a place moves the quest on (LocationWalk._check_cell_events: a road out opens the travel map first and never reads
		# `sets_quest`), so the hill road's `dinner` stage is set where the party arrives (the Jenkins' talk), not here.
		var sq: Variant = e.get("sets_quest", null)
		if sq is Dictionary and ((sq as Dictionary).get("from", []) as Array).has(st.quest_stage(str((sq as Dictionary)["id"]))):
			st.set_quest_stage(str((sq as Dictionary)["id"]), str((sq as Dictionary)["stage"]))
	if str(e["to"]) == "travel":
		var from := Travel.place_for_location(st.location)
		var to := Travel.exit_destination(_loc(), e, st)
		if to == "":
			# A road that leads to none or several places opens the map to choose on: the one asked for must be one of the places an open
			# road leads to from here, and if the road faces a side of the map it is one of those it faces.
			var found := Travel.exit_places(_loc(), e, st)
			assert_true(destination != "" and (found.is_empty() or found.has(destination)), "%s: the road %s offers %s among %s" % [st.location, exit, destination, found])
			assert_true(Travel.neighbours(from, st).has(destination), "%s: the map offers %s (open roads lead to %s)" % [from, destination, Travel.neighbours(from, st)])
			to = destination
		else:
			assert_true(destination == "" or to == destination, "%s: the road %s goes straight to %s, not %s" % [st.location, exit, to, destination])
		var legs := Travel.route(from, to, st)
		assert_true(not legs.is_empty(), "%s to %s is a road the party can take now" % [from, to])
		for leg: Dictionary in legs:
			st.advance_minutes(roundi(float(leg["hours"]) * 60.0))
		var pl := Travel.place(to)
		st.location = str(pl.get("location", "")).get_slice(":", 0)
		st.visited[st.location] = true
		st.visited[to] = true
		return
	st.advance_minutes(5)
	st.location = Campaign.module().exit_target(st, st.location, str(e["to"]))
	st.visited[st.location] = true
	assert_true(not _loc().is_empty(), "%s is a place" % st.location)


## The heroes take the level the story has paid (the real game's Level Up screen is played by the QA driver; here each hero is built
## again at the level, as the story bot does).
func _take_levels() -> void:
	var target := st.target_level()
	for i in st.party.size():
		var ch := st.party[i]
		if ch.character_level() < target:
			var fresh := Pregens.build(ch.id, target)
			fresh.finish_long_rest()
			st.party[i] = fresh


## A save made and loaded the way the Save and Continue buttons do (SaveSystem, into this run's own folder); the story that comes back
## is the one the walk goes on with, and it is the same story.
func _save_and_load(slot: String) -> void:
	var before := JSON.stringify(st.to_dict(), "", true)
	assert_eq(SaveSystem.save(slot), OK, "the game saves at %s" % st.location)
	assert_eq(SaveSystem.load_slot(slot), OK, "and loads again")
	SaveSystem.delete_slot(slot)
	st = GameState.story
	r10.st = st
	r12.st = st
	var diffs: Array[String] = []
	_differences(JSON.parse_string(before), JSON.parse_string(JSON.stringify(st.to_dict(), "", true)), "", diffs)
	if not diffs.is_empty():
		fail("the save and the load changed what the story holds (%d differences): %s" % [diffs.size(), "; ".join(diffs.slice(0, 8))])


## Where two saved values differ, as paths: "flags.x: true -> <none>".
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


func test_the_wreck_to_wickermoor_to_the_crooked_house_to_vessla_dead_at_level_four() -> void:
	# --- R10: the Express, from a new game to the wreck, played by its own walk ---
	r10 = R10.new()
	r10.before_each()
	r10.test_the_express_plays_from_a_new_game_to_the_wickermoor_road()
	_collect(r10, "the Express")
	st = r10.st
	assert_true(st.quest_ended("ghostlight_express"), "the Express is over")
	assert_eq(st.milestones, 2, "two levels paid on the train (the third haint, the crash)")
	assert_eq(st.target_level(), 3, "the party may rise to level 3")
	r12 = R12.new()
	r12.st = st
	r12.dice = R12.HighDice.new()
	# The walk's last step leaves the party on the road; the road is worked out here, from the wreck's exit.
	st.location = WRECK
	_take_levels()
	for ch in st.party:
		assert_eq(ch.character_level(), 3, "%s is level 3 at the wreck" % ch.name)

	# --- The road to Wickermoor (4 hours), and the arrival ---
	var clock := st.total_minutes()
	_go("to_wickermoor", TOWN)
	assert_eq(st.location, TOWN, "the wreck road leads to Wickermoor")
	assert_true(st.total_minutes() > clock, "the road takes time")

	# --- R11: the goat and the wolves at the well, the mayor at the notice board ---
	r12._called_by("wm_well", ["Keep back"])
	assert_eq(str(st.get_flag("goat_fate", "")), "eaten", "holding back leaves the goat to the wolves")
	assert_true(bool(st.get_flag("wm_first_sacrifice_done")), "the first rite is over")
	assert_eq(st.quest_stage("wickermoor_arrival"), "welcome")
	assert_true(not StoryConditions.check(str(r12._entry("props", "id", "wm_well").get("call_when")), st), "the well does not call again")
	r12._called_by("wm_notice_board", ["Ask about the village", "Thank him", "glad to come"])
	assert_true(bool(st.get_flag("wm_welcomed")), "the mayor has welcomed the party")
	assert_eq(st.quest_stage("wickermoor_arrival"), "parting", "the journal waits at the parting until the inn")
	_collect(r12, "R11 arrival")

	# --- The inn: the keeper, a night's rest where the house rules allow it, a save and a load ---
	_go("green_queen_inn")
	assert_eq(st.location, INN)
	assert_eq(st.quest_stage("wickermoor_arrival"), "free_roam", "taking the inn's door moves the journal on")
	r12._talk("alda_farnum", ["Ask about rooms and the inn", "Take our leave"])
	assert_true(bool(st.get_flag("alda_farnum_met")), "the keeper is met")
	_save_and_load("act1_hub_inn")
	assert_eq(st.location, INN, "the party is still at the inn after the load")
	assert_eq(st.quest_stage("wickermoor_arrival"), "free_roam")
	assert_true(bool(st.get_flag("wm_welcomed")) and bool(st.get_flag("alda_farnum_met")), "what was done is still done")

	# --- Out of the inn, up the hill road to the estate ---
	_go("door")
	assert_eq(st.location, TOWN)
	var hours_before := st.total_minutes()
	_go("road_to_estate", ESTATE)
	assert_eq(st.location, ESTATE, "the hill road leads to the estate")
	assert_eq(st.quest_stage("wickermoor_arrival"), "free_roam", "the road itself leaves the journal where it was")
	assert_true(st.total_minutes() > hours_before)
	assert_eq(st.quest_stage("the_crooked_house"), "", "the Jenkins have not yet spoken")

	# --- R12: the gate, the porch, the house (the same steps as test_r12_paths' spine, on this story) ---
	r12.fights.clear()
	r12.apparitions.clear()
	r12.stage_floor = 0
	r12.on_floor = R12.FIRST
	r12._arrive(ESTATE)
	assert_true(not r12._npc_here("gilly_jenkin").is_empty() and r12._npc_here("crooked_man").is_empty(), "the Jenkins wait at the gate")
	assert_true(not r12._exit_open("porch_steps"), "the porch steps are shut until the Crooked Man has been met")
	r12._talk("gilly_jenkin", ["Where are the two of you", "Have you seen the Lord", "What is the house like", "Walter seems on edge",
		"We'll go up to the house"])
	assert_eq(r12._stage(), "arrived", "the Jenkins' talk sets the gate stage on its own")
	assert_eq(st.quest_stage("wickermoor_arrival"), "dinner", "and the arrival quest knows the party has climbed the hill")
	assert_true(bool(st.get_flag("crooked_house_turned")), "the house has turned")
	r12._talk("crooked_man", ["Who are you?", "Where are Lord Phillip", "What do you want with us?", "Study him closely", "Feel the air", "Go inside"])
	assert_eq(r12._stage(), "trapped", "the storm shuts the party in")
	r12._exit("porch_steps")
	assert_eq(r12._where(), R12.FIRST, "the steps lead into the house")
	r12._check_stage("the porch")
	r12._calls()
	var ways := {"gem": "peacock", "key": "perf", "cup": "persuade", "doll": "found", "bear": "persuade", "pin": "cut"}
	for m: String in R12.MEMENTOS:
		r12._go(str(R12.FLOOR_OF[m]))
		r12._expect_gates("before %s" % m)
		r12._acquire(m, str(ways[m]))
		r12._calls()
		r12._check_stage("after %s" % m)
	for floor_id: String in [R12.FIRST, R12.SECOND, R12.THIRD]:
		r12._go(floor_id)
		r12._calls()
	for f: String in ["crooked_man_seen_1", "crooked_man_seen_2", "crooked_man_seen_3"]:
		assert_true(bool(st.get_flag(f)), "%s played" % f)
	r12._seance(R12.SEANCE_ASKS)
	assert_true(bool(st.get_flag("patrini_asked_find_son")), "Patrini's son is asked after")
	r12._open_hatch("seance")
	r12._place_all(R12.MEMENTOS)
	var spec := r12._confront("kneel")
	r12._win_spec(spec, "ch_vessla")
	r12._unbend()
	_collect(r12, "the Crooked House")

	# --- Vessla dead at level 4, the story saved and loaded once more at the estate ---
	assert_true(bool(st.get_flag("vessla_slain")), "Vessla is dead")
	assert_eq(r12._stage(), "done", "the Crooked House is done")
	assert_eq(st.milestones, 3, "level 4 is paid")
	assert_eq(st.target_level(), 4, "the party may rise to level 4")
	_take_levels()
	for ch in st.party:
		assert_eq(ch.character_level(), 4, "%s is level 4" % ch.name)
	assert_eq(st.location, ESTATE, "the party is home from the house")
	_save_and_load("act1_hub_end")
	assert_eq(st.quest_stage("the_crooked_house"), "done", "and still done after the load")
	assert_true(bool(st.get_flag("druskenvald_manor_restored")), "the manor stays restored")
	# Old Rusty's errand for Patrini's son waits on the estate road, and the road down to the village is open again.
	assert_true(not r12._npc_here("old_rusty").is_empty(), "Old Rusty waits on the estate road")
	r12._talk("old_rusty", ["Say the name aloud"])
	assert_eq(st.quest_stage("find_my_son"), "told")
	_go("to_village", TOWN)
	assert_eq(st.location, TOWN, "the hill road leads back to Wickermoor")
	# The way on into Act II opens with Vessla's death (the road to Dawn's Gate).
	assert_true(not Travel.route("wickermoor_village", "dawns_gate", st).is_empty(), "the Silverbell river road opens once Vessla is dead")
