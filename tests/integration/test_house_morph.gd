extends TestCase
## The Crooked House's turn, on screen (plan G8): the estate's houses are built tidy and warp into their true crooked shape when
## crooked_house_turned is set (CrookedMoonLook.refresh -> BuildingMorph), tidy again once the manor is restored. The rules grid is
## never touched; a view built after the change starts settled.

const GAME := preload("res://world/game_root.gd")
const ESTATE := "druskenvald_estate"


func before_each() -> void:
	Look.set_style("modern", false)


func _view(flags: Dictionary) -> LocationView:
	GameState.reset()
	var st := GameState.story
	for pid: String in GAME.PLACEHOLDER_PARTY:
		st.party.append(Pregens.build(pid, 3))
	for k: String in flags:
		st.set_flag(k, flags[k])
	st.location = ESTATE
	var view := LocationView.create(ESTATE, st, Narrator.new(), Dice.roller, "default")
	add_child(view)
	return view


func test_the_catalog_names_the_estate_for_the_morph() -> void:
	var morph := (((SetDressing.catalog()["building_kit"] as Dictionary)["bend"] as Dictionary)["morph"]) as Dictionary
	assert_true(morph.has(ESTATE), "the estate's houses carry a tidy shape")
	assert_true(CrookedMoonLook.MORPHING.has(ESTATE), "and the look asks for it")


func test_the_houses_start_tidy_and_warp_when_the_house_turns() -> void:
	var view := _view({})
	await get_tree().process_frame
	assert_true(BuildingMorph.has_morph(view.board), "the houses carry the tidy shape")
	CrookedMoonLook.new().refresh(view)
	assert_eq(BuildingMorph.weight(view.board), 1.0, "before the turn they are tidy")
	view.st.set_flag("crooked_house_turned", true)
	CrookedMoonLook.new().refresh(view)
	assert_eq(float(view.board.get_meta(BuildingMorph.META_TARGET)), 0.0, "the turn sends them to their crooked shape")
	await get_tree().create_timer(3.5).timeout
	assert_between(absf(BuildingMorph.weight(view.board)), 0.0, 0.05, "and they settle there")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_a_place_built_after_the_turn_is_already_crooked_and_the_grid_is_untouched() -> void:
	var tidy := _view({})
	var cells := {}
	for z in tidy.grid.depth:
		for x in tidy.grid.width:
			cells[Vector2i(x, z)] = tidy.grid.flags(Vector2i(x, z))
	tidy.queue_free()
	await get_tree().process_frame
	var view := _view({"crooked_house_turned": true})
	await get_tree().process_frame
	CrookedMoonLook.new().refresh(view)
	assert_eq(BuildingMorph.weight(view.board), 0.0, "already crooked, no warp to watch")
	for c: Vector2i in cells:
		assert_eq(view.grid.flags(c), cells[c], "square %s unchanged" % c)
	view.st.set_flag("druskenvald_manor_restored", true)
	CrookedMoonLook.new().refresh(view)
	assert_eq(float(view.board.get_meta(BuildingMorph.META_TARGET)), 1.0, "restored, the manor goes tidy again")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()
