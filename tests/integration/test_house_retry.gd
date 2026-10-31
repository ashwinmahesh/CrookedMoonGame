extends TestCase
## The generalised wipe retry (story/fight_retry.gd, data/fight_retries.json): a wipe in a fight the table lists begins the same fight
## again with the party on its feet at the room's entry; a wipe in any other fight is still a game over. The Crooked House's rule
## (every `ch_` fight in its five places) is read from the real table; the fights run on the test hillside with a stub table, so the
## test needs none of R12's places.

const GAME := preload("res://world/game_root.gd")
const LOC := "test_hillside"
const FIGHT := "hillside_scarecrows"
const HOUSE_PLACES: Array[String] = ["druskenvald_estate", "crooked_house_first", "crooked_house_second", "crooked_house_third",
	"crooked_house_attic"]

var st: StoryState
var root: Node


func _stub(prefix: String, places: Array[String]) -> Dictionary:
	return {"rules": [{"id": "stub", "prefix": prefix, "locations": places, "keys": ["defeat:{fight}", "defeat:crooked_house"],
		"count_flag": "stub_retries", "spawns": {LOC: ["from_nowhere", "from_creek"]}}]}


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOC
	Dice.reseed(7)


func after_each() -> void:
	FightRetry.use_table(null)
	if is_instance_valid(root):
		root.queue_free()
		await get_tree().process_frame
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot() -> LocationView:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	return root.get("view") as LocationView


## Starts the fight, knocks the whole party down and lets the fight report the defeat. Returns the combat view that lost.
func _wipe(view: LocationView) -> CombatView:
	assert_true(view.start_encounter(FIGHT), "the fight starts")
	await _frames(6)
	var cv := view.combat_view
	var first := cv.e
	for ch in st.party:
		ch.hp = 0
	st.party[1].dead = true
	first._check_over()
	assert_eq(first.outcome, "defeat", "the party is down")
	cv.finished.emit("defeat")
	return cv


# --- The table ---------------------------------------------------------------------------------------------------

func test_the_crooked_house_rule_covers_its_fights_in_its_five_places_only() -> void:
	FightRetry.use_table(null)
	for place in HOUSE_PLACES:
		for id: String in ["ch_peacock", "ch_vessla", "ch_roar"]:
			assert_true(FightRetry.applies({"id": id}, place), "%s in %s retries" % [id, place])
		assert_false(FightRetry.applies({"id": "wm_wolves"}, place), "another fight in %s is a game over" % place)
	assert_false(FightRetry.applies({"id": "ch_peacock"}, "wickermoor_village"), "a ch_ fight elsewhere is not the house's")
	assert_false(FightRetry.applies({}, HOUSE_PLACES[0]), "a fight with no id is not a retry")


func test_the_locomotive_keeps_its_rule() -> void:
	FightRetry.use_table(null)
	var rule := FightRetry.rule_for({"id": "gl_locomotive"}, "ghostlight_wreckage")
	assert_false(rule.is_empty(), "the boss retries")
	assert_eq(FightRetry.restart_id(rule, {"id": "gl_locomotive"}), GhostlightRetry.RETRY_FIGHT, "from the clearing's rim")
	assert_eq(FightRetry.keys(rule, {"id": "gl_locomotive"}), [GhostlightRetry.NARRATOR_KEY] as Array[String])
	assert_eq(str(rule["count_flag"]), GhostlightRetry.COUNT_FLAG)
	assert_eq(FightRetry.spawn_for(rule, "ghostlight_wreckage", {"spawns": {"default": [1, 1]}}), "", "it stays where the party stands")
	assert_true(FightRetry.applies({"id": "gl_locomotive_edge"}, "ghostlight_wreckage"))
	assert_false(FightRetry.applies({"id": "gl_stoker"}, "ghostlight_wreckage"))


func test_the_house_says_its_own_defeat_line_first_and_the_general_one_after() -> void:
	FightRetry.use_table(null)
	var spec := {"id": "ch_clock"}
	var rule := FightRetry.rule_for(spec, "crooked_house_second")
	assert_eq(FightRetry.keys(rule, spec), ["defeat:ch_clock", "defeat:crooked_house"] as Array[String])
	assert_eq(FightRetry.restart_id(rule, spec), "ch_clock", "the same fight begins again")


func test_the_party_goes_back_to_the_first_spawn_the_map_has() -> void:
	FightRetry.use_table(null)
	var rule := FightRetry.rule_for({"id": "ch_clock"}, "crooked_house_second")
	assert_eq(FightRetry.spawn_for(rule, "crooked_house_second", {"spawns": {"default": [1, 1], "from_below": [2, 2]}}), "from_below")
	assert_eq(FightRetry.spawn_for(rule, "crooked_house_second", {"spawns": {"default": [1, 1]}}), "default", "else the default")
	assert_eq(FightRetry.spawn_for(rule, "crooked_house_first", {"spawns": {"from_porch": [1, 1], "default": [3, 3]}}), "from_porch")


# --- A wipe ------------------------------------------------------------------------------------------------------

func test_a_wipe_in_a_listed_fight_restores_the_party_and_starts_it_again_at_the_entry() -> void:
	FightRetry.use_table(_stub("hillside_", [LOC]))
	var view := await _boot()
	var cv := await _wipe(view)
	for i in 240:
		await get_tree().process_frame
		if root.get("view") != view and (root.get("view") as LocationView).in_combat:
			break
	var after := root.get("view") as LocationView
	assert_true(after != view and after.in_combat, "the place is entered again and the fight is on")
	assert_true(after.combat_view != cv and after.combat_view != null, "a new fight")
	assert_eq(after.fight_id, FIGHT, "the same fight")
	var entry := Vector2i(14, 22)   # the hillside's `from_creek`
	for m in after.members:
		assert_true(maxi(absi(m.cell.x - entry.x), absi(m.cell.y - entry.y)) <= 3, "%s is at the entry (%s)" % [m.creature.name, m.cell])
	for ch in st.party:
		assert_false(ch.dead, "%s is on their feet" % ch.name)
		assert_eq(ch.hp, ch.max_hp(), "%s has all their Hit Points" % ch.name)
	assert_eq(int(st.get_flag("stub_retries", 0)), 1, "the retry is counted")
	assert_false(root.get("screen") is PauseMenu, "no game-over screen")


func test_a_wipe_in_another_fight_is_still_a_game_over() -> void:
	FightRetry.use_table(_stub("ch_", [LOC]))   # the table lists other fights than this one
	var view := await _boot()
	await _wipe(view)
	await _frames(12)
	var screen := root.get("screen") as Node
	assert_true(screen is PauseMenu and (screen as PauseMenu).game_over, "the game-over screen opens")
	assert_eq(int(st.get_flag("stub_retries", 0)), 0, "nothing was retried")


func test_a_listed_fight_in_an_unlisted_place_is_a_game_over() -> void:
	FightRetry.use_table(_stub("hillside_", HOUSE_PLACES))   # the right fight, the wrong place
	var view := await _boot()
	await _wipe(view)
	await _frames(12)
	var screen := root.get("screen") as Node
	assert_true(screen is PauseMenu and (screen as PauseMenu).game_over, "the game-over screen opens")
