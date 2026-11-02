extends TestCase
## What the floors of the multi-floor buildings settle for themselves, put back after the merge (their `map.floors` entries,
## the engine's PlaceFloors; tools/content/merge_floors.py reads them from the old floor places): the cellars' and upstairs'
## sound beds and footsteps, the Briar cellar's risky rest, the windmill cellar's manor theme, the belfry's open air and the
## Crooked House attic's darker mood; and the cellars' own moods, a little brighter than the house above.

## floor id -> what it says for itself.
const OWN := {
	"fw_windmill_cellar": {"bed": "windmill_cellar", "steps": "stone", "theme": "manor", "mood": "fw_cellar"},
	"wickermoor_inn_cellar": {"bed": "tavern_muffled", "steps": "stone", "mood": "wm_cellar"},
	"wickermoor_green_queen_inn_upper": {"bed": "tavern_muffled"},
	"dg_briar_cellar": {"bed": "tavern_muffled", "rest": "risky", "mood": "dg_cellar"},
	"dg_briar_upper": {"bed": "tavern_muffled"},
	"wickermoor_barber_cellar": {"steps": "stone", "mood": "wm_cellar"},
	"wickermoor_funeral_basement": {"steps": "stone", "mood": "wm_cellar"},
	"wickermoor_trading_cellar": {"steps": "stone", "mood": "wm_cellar"},
	"mon_belfry": {"bed": "mountain_wind", "outdoors": true},
	"crooked_house_attic": {"mood": "crooked_attic"},
}
const PLACES := ["crooked_house", "fw_windmill", "wickermoor_green_queen_inn", "dg_briar", "wickermoor_barber_shop",
	"wickermoor_funeral_home", "wickermoor_trading_post", "mon_ground", "mon_bell_tower"]


func _floor(place: String, id: String) -> Dictionary:
	for f: Variant in ((Compendium.shared().get_entry("locations", place)["map"] as Dictionary)["floors"] as Array):
		if str((f as Dictionary)["id"]) == id:
			return f as Dictionary
	return {}


func test_each_floor_says_what_it_had_before_its_building_was_one_place() -> void:
	for place: String in PLACES:
		for f: Variant in ((Compendium.shared().get_entry("locations", place)["map"] as Dictionary)["floors"] as Array):
			var fl := f as Dictionary
			var want := OWN.get(str(fl["id"]), {}) as Dictionary
			for key: String in ["mood", "bed", "steps", "rest", "rest_text", "theme", "outdoors"]:
				assert_eq(fl.get(key, null), want.get(key, null), "%s: %s" % [fl["id"], key])


func test_the_ground_floor_says_nothing_it_is_the_place() -> void:
	for place: String in PLACES:
		var floors := (Compendium.shared().get_entry("locations", place)["map"] as Dictionary)["floors"] as Array
		for f: Variant in floors:
			if str((f as Dictionary)["id"]) == place or str((f as Dictionary)["id"]) == "crooked_house_first":
				for key: String in ["mood", "bed", "steps", "rest", "theme", "outdoors"]:
					assert_false((f as Dictionary).has(key), "%s's ground floor has no %s of its own" % [place, key])


## The cellars: place -> its cellar floor's id.
const CELLARS := {"fw_windmill": "fw_windmill_cellar", "wickermoor_green_queen_inn": "wickermoor_inn_cellar",
	"dg_briar": "dg_briar_cellar", "wickermoor_barber_shop": "wickermoor_barber_cellar",
	"wickermoor_funeral_home": "wickermoor_funeral_basement", "wickermoor_trading_post": "wickermoor_trading_cellar"}


## A mood's Modern ambient for any hour.
func _modern_ambient(mood: String) -> float:
	var m := Atmosphere.resolve(mood)
	var modern := m.get("modern", {}) as Dictionary
	var any := ((modern.get("times", m.get("times", {})) as Dictionary).get("any", {})) as Dictionary
	return float(any.get("ambient_energy", 0.8))


func test_a_cellar_is_a_little_brighter_than_the_house_over_it_but_still_dim() -> void:
	for place: String in CELLARS:
		var loc := Compendium.shared().get_entry("locations", place)
		var mood := str(_floor(place, CELLARS[place]).get("mood", ""))
		var house := Atmosphere.mood_for(place, loc)
		assert_eq(str(Atmosphere.moods()["moods"][mood].get("like", "")), house, "%s's cellar is like the house over it" % place)
		var ratio := _modern_ambient(mood) / _modern_ambient(house)
		assert_true(ratio > 1.0 and ratio < 2.5, "%s's cellar is brighter, not bright (%.2f)" % [place, ratio])


func _story(place: String, at: Vector2i) -> StoryState:
	GameState.reset()
	var st := GameState.story
	st.location = place
	st.positions.append(at)
	return st


func test_the_briar_cellar_is_a_risky_place_to_sleep_under_a_safe_inn() -> void:
	var loc := Compendium.shared().get_entry("locations", "dg_briar")
	var spawns := loc["spawns"] as Dictionary
	assert_eq(RestRules.rule_of(loc, _story("dg_briar", LocationView._cell(spawns["cellar_default"]))), "risky", "in the cellar")
	assert_eq(RestRules.rule_of(loc, _story("dg_briar", LocationView._cell(spawns["default"]))), "safe", "in the taproom")
	assert_eq(RestRules.rule_of(loc, _story("dg_briar", LocationView._cell(spawns["upper_default"]))), "safe", "and upstairs")
	GameState.reset()


func test_a_cellar_that_was_always_risky_stays_so_and_the_monastery_gives_no_rest() -> void:
	var barber := Compendium.shared().get_entry("locations", "wickermoor_barber_shop")
	var bs := barber["spawns"] as Dictionary
	assert_eq(RestRules.rule_of(barber, _story("wickermoor_barber_shop", LocationView._cell(bs["cellar_default"]))), "risky", "the barber's cellar")
	var mon := Compendium.shared().get_entry("locations", "mon_ground")
	assert_eq(RestRules.rule_of(mon, _story("mon_ground", LocationView._cell((mon["spawns"] as Dictionary)["upper_default"]))), "no", "the upper floor of the monastery")
	GameState.reset()


func _view(id: String) -> LocationView:
	GameState.reset()
	var st := GameState.story
	for pid: String in preload("res://world/game_root.gd").PLACEHOLDER_PARTY:
		st.party.append(Pregens.build(pid, 3))
	st.location = id
	var view := LocationView.create(id, st, Narrator.new(), Dice.roller, "default")
	add_child(view)
	return view


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _settle() -> void:
	await get_tree().create_timer(FloorCutaway.CHECK_EVERY + 0.15).timeout


func test_the_belfry_is_under_the_open_sky_and_the_tower_is_not() -> void:
	var view := _view("mon_bell_tower")
	await _frames(4)
	var heard: Array[int] = []
	view.floor_changed.connect(func(i: int) -> void: heard.append(i))
	assert_false(view.outdoors(), "the tower's landing is indoors")
	assert_false(view.atmosphere.outdoors, "and so is its atmosphere")
	LocationParty.move_within(view, "belfry_from_ladder")
	await _settle()
	assert_true(view.outdoors(), "the belfry is open to the sky")
	assert_true(view.atmosphere.outdoors, "and its atmosphere follows")
	assert_eq(heard, [1], "the party's coming to the belfry was told")
	LocationParty.move_within(view, "default")
	await _settle()
	assert_false(view.outdoors(), "down the ladder it is indoors again")
	assert_false(view.atmosphere.outdoors, "and the atmosphere with it")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_the_attic_has_its_own_darker_mood() -> void:
	var view := _view("crooked_house")
	await _frames(4)
	assert_eq(view.atmosphere.mood_id, "crooked_house", "the house's own mood on its first floor")
	LocationParty.move_within(view, "attic_from_ladder")
	await _settle()
	assert_eq(view.atmosphere.mood_id, "crooked_attic", "the attic's, up the ladder")
	assert_eq(str(view.atmosphere.mood.get("name", view.atmosphere.mood_id)), str(view.atmosphere.mood.get("name", "crooked_attic")), "dressed from it")
	LocationParty.move_within(view, "third_from_below")
	await _settle()
	assert_eq(view.atmosphere.mood_id, "crooked_house", "and the house's again below")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_the_footsteps_and_the_bed_follow_the_floor() -> void:
	var view := _view("fw_windmill")
	await _frames(4)
	assert_eq(str(view.floor_setting("steps", "")), "", "the mill's boards: the place's own sound")
	assert_eq(PlaceBeds.bed_for("fw_windmill", GameState.story, str(view.floor_setting("bed", ""))), "windmill", "and bed")
	LocationParty.move_within(view, "cellar_default")
	assert_eq(str(view.floor_setting("steps", "")), "stone", "the cellar's stone")
	assert_eq(PlaceBeds.bed_for("fw_windmill", GameState.story, str(view.floor_setting("bed", ""))), "windmill_cellar", "and its own bed")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_a_floor_bed_stands_for_the_places_and_outranks_its_regions_turns() -> void:
	var st := _story("wickermoor_green_queen_inn", Vector2i(30, 12))
	assert_eq(PlaceBeds.bed_for("wickermoor_green_queen_inn", st, "tavern_muffled"), "tavern_muffled", "upstairs at the Green Queen")
	assert_eq(PlaceBeds.bed_for("wickermoor_green_queen_inn", st), PlaceBeds.bed_for("wickermoor_green_queen_inn", st, ""), "no floor bed: the place's")
	GameState.reset()


func test_the_windmills_cellar_is_built_in_its_own_theme() -> void:
	var view := _view("fw_windmill")
	await _frames(4)
	var board := view.board
	assert_eq(board.theme, "tavern", "the board stays in the mill's theme once built")
	var base := board._theme_state({})
	var own := board._floor_themes(base)
	assert_eq(own.keys(), [0], "only the cellar has a theme of its own")
	assert_eq(str((own[0] as Dictionary)["theme"]), "manor", "the cellar's")
	assert_eq(board.theme, "tavern", "and asking leaves the board as it was")
	assert_true((own[0] as Dictionary)["floor_tex"] != null and (own[0] as Dictionary)["wall_tex"] != null, "with the surfaces the theme names")
	assert_eq(str(base["theme"]), "tavern", "against the mill's own")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()
