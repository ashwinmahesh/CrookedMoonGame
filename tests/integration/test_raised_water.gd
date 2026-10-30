extends TestCase
## The test hillside's creek runs down the hill (the engine's water on raised ground, 2026-10-30): its water lies at its
## own squares' height, the banks beside it keep their ground instead of cutting a trench to the board's level, the
## difficult squares roll with the land, and the camera looks 30 degrees down.

const LOC := "test_hillside"
const GAME := preload("res://world/game_root.gd")

var view: LocationView


func before_each() -> void:
	GameState.reset()
	for id: String in GAME.PLACEHOLDER_PARTY:
		GameState.story.party.append(Pregens.build(id, 3))
	view = LocationView.create(LOC, GameState.story, null, Dice.roller, "default")
	add_child(view)


func after_each() -> void:
	view.queue_free()
	await get_tree().process_frame


func _shore() -> Shores:
	var relief := view.atmosphere.land.relief
	return relief.shore if relief != null else null


func test_the_creek_lies_at_its_own_height() -> void:
	var shore := _shore()
	assert_true(shore != null and shore.sloped(), "the creek is off the board's level")
	if shore == null:
		return
	for z in view.grid.depth:
		for x in view.grid.width:
			var c := Vector2i(x, z)
			if not view.grid.has_flag(c, CombatGrid.WATER):
				continue
			var own := view.grid.height(c) / float(CombatGrid.FEET)
			var y := shore.water_y(Vector2(x + 0.5, z + 0.5))
			assert_true(absf(y - own) < 1.2, "the water at %s lies near its own square's height (%.2f, square %.1f)" % [c, y, own])


func test_the_banks_keep_their_ground() -> void:
	var relief := view.atmosphere.land.relief
	var checked := 0
	for z in view.grid.depth:
		for x in view.grid.width:
			var c := Vector2i(x, z)
			if view.grid.has_flag(c, CombatGrid.WATER) or not view.grid.has_flag(c, CombatGrid.NATURAL) or view.grid.has_flag(c, CombatGrid.WALL):
				continue
			var beside := false
			for d: Vector2i in CombatGrid.DIRS:
				beside = beside or (view.grid.in_bounds(c + d) and view.grid.has_flag(c + d, CombatGrid.WATER))
			if not beside or view.grid.height(c) < 10:
				continue
			var mid := Vector2(x + 0.5, z + 0.5)
			assert_true(relief.height(mid) > view.board.ground_y(mid) - 0.3, "no trench at %s on raised ground" % c)
			checked += 1
	assert_true(checked > 5, "raised banks were checked (%d)" % checked)


func test_difficult_squares_roll_with_the_land() -> void:
	var relief := view.atmosphere.land.relief
	for z in view.grid.depth:
		for x in view.grid.width:
			var c := Vector2i(x, z)
			if view.grid.has_flag(c, CombatGrid.DIFFICULT) and view.board.rolling(c):
				assert_true(relief.draws(c), "the skin draws difficult square %s" % c)


func test_the_camera_looks_thirty_degrees_down() -> void:
	assert_between(view.rig.camera.rotation_degrees.x, -30.01, -29.99, "30 degrees")
