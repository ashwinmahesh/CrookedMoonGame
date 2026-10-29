extends TestCase
## Phase 0's exit place (plan section 10.4): a natural test place (a hillside with a cottage, a creek and a fence) designed as a
## place first and laid into the grid and elevation rows afterwards, where a placeholder party walks under the night clock, at
## the game's own camera and look. The grid here is derived from the land: squares sample its height, water, trees and the
## things built on it, and the rules run on that.

const LOC := "test_hillside"
const GAME := preload("res://world/game_root.gd")

var root: Node
var st: StoryState


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOC
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _map() -> Dictionary:
	return (Compendium.shared().get_entry("locations", LOC)["map"]) as Dictionary


func test_the_place_is_designed_with_height_not_flat_squares() -> void:
	var map := _map()
	var elevation := map["elevation"] as Array
	var rows := map["rows"] as Array
	assert_eq(elevation.size(), rows.size(), "an elevation row for every row")
	var heights := {}
	for line: String in elevation:
		assert_eq(line.length(), (rows[0] as String).length())
		for ch in line:
			heights[ch] = true
	assert_true(heights.size() >= 5, "the land rises through at least five steps (found %d)" % heights.size())
	assert_true(bool(map.get("outdoors", false)), "an outdoor place")
	assert_true(rows.any(func(r: String) -> bool: return r.contains("w")), "there is deep water: the creek")


func test_neighbouring_land_never_steps_up_more_than_the_slopes_allow() -> void:
	# Natural ground 5 ft apart is a gentle slope; the walkable hillside has no cliffs between neighbours (the cliffs are the
	# creek's banks, which this place keeps at one step).
	var elevation := _map()["elevation"] as Array
	for y in elevation.size():
		for x in (elevation[y] as String).length():
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nx := x + d.x
				var ny := y + d.y
				if ny < elevation.size() and nx < (elevation[ny] as String).length():
					var a := int((elevation[y] as String)[x])
					var b := int((elevation[ny] as String)[nx])
					assert_true(absi(a - b) <= 1, "the land at %d,%d and %d,%d differs by %d steps" % [x, y, nx, ny, absi(a - b)])


func test_the_grid_is_derived_from_the_land() -> void:
	var view := _view()
	assert_true(view != null and view.loc_id == LOC, "the game starts on the test hillside")
	var grid := view.grid
	var spawn := Vector2i(22, 25)
	assert_true(grid.in_bounds(spawn) and not grid.is_solid(spawn), "the spawn is open ground")
	assert_true(grid.has_flag(Vector2i(9, 12), CombatGrid.WATER), "the creek's deep water is not walkable")
	for c: Vector2i in [Vector2i(17, 9), Vector2i(18, 10), Vector2i(19, 9)]:
		assert_true(grid.is_solid(c), "the cottage stands on %s" % c)
	assert_true(grid.is_solid(Vector2i(0, 0)), "the edge of the map is woods")
	# The bench sits two steps above the meadow's edge and the hill keeps rising behind it: height is in the rules.
	var low := grid.height(Vector2i(22, 24))
	var high := grid.height(Vector2i(22, 12))
	assert_true(high > low, "the bench is higher than the meadow (%d ft over %d ft)" % [high, low])
	assert_true(grid.has_flag(Vector2i(22, 12), CombatGrid.NATURAL), "the bench is natural ground, not a built floor")


func test_the_fence_has_a_gate_and_the_cottage_a_door_side() -> void:
	var view := _view()
	var rows := _map()["rows"] as Array
	var fence := rows[15] as String
	assert_eq(fence[18], ".", "the gate gap in the fence")
	assert_eq(fence[19], ".", "the gate gap in the fence")
	assert_eq(fence[12], "=", "fence rails are low cover")
	assert_true(view.grid.has_flag(Vector2i(12, 15), CombatGrid.LOW), "the fence stops a walker")
	var path := view._path(Vector2i(22, 25), Vector2i(18, 12))
	assert_false(path.is_empty(), "the party can walk from the meadow to the cottage through the gate")
	assert_true(path.any(func(c: Vector2i) -> bool: return c.y == 15 and (c.x == 18 or c.x == 19)), "and it goes through the gap")


func test_the_party_walks_up_the_hill_under_the_night_clock() -> void:
	var view := _view()
	st.minute_of_day = 22 * 60   # ten at night
	view.update_daylight()
	assert_eq(view.time_phase(), "night", "the clock says night and the world follows it")
	assert_true(view.lantern.visible, "the first hero carries the party's lantern in the dark")
	var start := view.leader().cell
	var goal := Vector2i(18, 12)
	assert_true(view.walk_to(goal), "a way to the cottage")
	for i in 900:
		await get_tree().process_frame
		if view.leader().cell == goal:
			break
	assert_eq(view.leader().cell, goal, "the leader reached the bench from %s" % start)
	assert_eq(st.minute_of_day, 22 * 60, "walking about a place is free of game time (the engine's rule); rests, waits and journeys spend it")
	for m in view.members:
		assert_true(Vector2(m.cell).distance_to(Vector2(goal)) < 8.0, "%s kept up" % m.name())
	root.call("_refresh")
	var hud_text := str((root.get("hud") as ExploreHud).get("_mode").get("text"))
	assert_true(hud_text.contains("22:00"), "the explore bar shows the clock: %s" % hud_text)


func test_the_clock_takes_the_place_from_noon_through_the_night() -> void:
	var view := _view()
	st.minute_of_day = 12 * 60
	view.update_daylight()
	assert_eq(view.time_phase(), "day")
	assert_false(view.lantern.visible, "no lantern at noon")
	st.advance_minutes(10 * 60)
	view.update_daylight()
	assert_eq(st.minute_of_day, 22 * 60)
	assert_eq(view.time_phase(), "night")
	assert_true(view.lantern.visible)
	st.advance_minutes(8 * 60)
	view.update_daylight()
	assert_eq(view.time_phase(), "dawn", "six in the morning")


func test_the_schedule_fires_at_its_hour_on_the_hillside() -> void:
	st.minute_of_day = 22 * 60 + 30
	Schedule.catch_up(st, LOC)   # now
	st.advance_minutes(45)
	var plays := Schedule.catch_up(st, LOC)
	var ids := plays.map(func(p: Dictionary) -> String: return str((p["event"] as Dictionary)["id"]))
	assert_true("test_cottage_lamp_out" in ids, "the cottage window goes dark at eleven: %s" % [ids])
	st.advance_minutes(24 * 60)
	assert_true(Schedule.catch_up(st, LOC).is_empty(), "and only once")


## The plan's exit: "a fight on it". The scarecrow on the bench comes alive when it is examined; the fight is fought on the same
## land: the foes stand on the bench, the party in the meadow below, and height counts.
func test_a_fight_on_the_hillside_is_fought_on_its_land() -> void:
	var view := _view()
	assert_true(view.start_encounter("hillside_scarecrows"), "the fight starts")
	await _frames(6)
	assert_true(view.in_combat)
	var e := view.combat_view.e
	assert_eq(e.combatants.size(), 7, "four heroes and three scarecrows")
	var foes := e.combatants.filter(func(c: Combatant) -> bool: return c.side != &"party")
	var heroes := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"party")
	assert_eq(foes.size(), 3)
	var foe_ft := 0
	for c: Combatant in foes:
		foe_ft = maxi(foe_ft, e.grid.height(c.cell))
	var hero_ft := 0
	for c: Combatant in heroes:
		hero_ft = maxi(hero_ft, e.grid.height(c.cell))
	assert_true(foe_ft > hero_ft, "the scarecrows hold the bench (%d ft) over the heroes in the meadow (%d ft): the grid has the land's height" % [foe_ft, hero_ft])
	var res := PartyAutopilot.new(e).run(30)
	assert_ne(str(res["outcome"]), "timeout", "the fight on the hillside ends")
