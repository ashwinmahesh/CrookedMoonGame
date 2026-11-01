extends TestCase
## The look pass's moods (plan 8.3, the colour script): every place the game has takes a mood of its own region rather than
## the generic woods or room, the act four regions that have no maps yet already have theirs, every colour a mood names is
## in the palette, and no two neighbouring regions on the travel map share a mood.

const LOCATIONS := "res://data/locations/"
const MOODS := "res://art/atmosphere/moods.json"
const GENERIC := ["woods", "indoors", "tavern", "chapel", "crypt", "cave"]
## Regions whose maps are still to come (R23, R24): their moods wait for them.
const LATER := ["the_moors", "wickers_vigil", "the_wytchwood", "crooked_tree"]
## Pairs of regions that sit side by side on the travel map, which must not look alike.
const NEIGHBOURS := [["ghostlight_express", "wickermoor"], ["wickermoor", "crooked_house"], ["wickermoor", "foxwillow"],
	["foxwillow", "hartsblight_forest"], ["dawns_gate", "drowned_crossroads"], ["drowned_crossroads", "maidenmist_cemetery"],
	["memorys_rest", "maidenmist_cemetery"], ["the_moors", "wickers_vigil"], ["the_wytchwood", "wickers_vigil"]]
const COLOUR_KEYS := ["sky", "fog", "ambient", "key", "mist", "shadows", "lights", "shade", "colour", "core", "rim", "moon_colour"]


func _places() -> Dictionary:
	var out := {}
	for f: String in DirAccess.get_files_at(LOCATIONS):
		if not f.ends_with(".json"):
			continue
		var loc := JSON.parse_string(FileAccess.get_file_as_string(LOCATIONS + f)) as Dictionary
		out[str(loc["id"])] = loc
	return out


func test_every_place_has_a_mood_of_its_region() -> void:
	var places := _places()
	assert_true(places.size() > 100, "the places load")
	var generic: Array[String] = []
	for id: String in places:
		if id == "test_hillside":
			continue
		var mood := Atmosphere.mood_for(id, places[id] as Dictionary)
		if mood in GENERIC:
			generic.append("%s: %s" % [id, mood])
	assert_eq(generic, [] as Array[String], "no place falls back to a generic mood")


func test_the_regions_still_to_come_have_moods() -> void:
	var regions := (JSON.parse_string(FileAccess.get_file_as_string(MOODS)) as Dictionary)["regions"] as Dictionary
	for r: String in LATER:
		assert_true(regions.has(r), "%s has a mood before its maps" % r)


func test_moods_use_palette_colours() -> void:
	var palette := JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/palette.json")) as Dictionary
	var all := (JSON.parse_string(FileAccess.get_file_as_string(MOODS)) as Dictionary)["moods"] as Dictionary
	for id: String in all:
		var bad: Array[String] = []
		_check_colours(Atmosphere.resolve(id), palette, bad)
		assert_eq(bad, [] as Array[String], "%s uses only palette colours" % id)


func test_neighbours_look_different() -> void:
	for pair: Array in NEIGHBOURS:
		var a := Atmosphere.mood_for("", {"region": pair[0], "map": {"outdoors": true}})
		var b := Atmosphere.mood_for("", {"region": pair[1], "map": {"outdoors": true}})
		assert_ne(a, b, "%s and %s have moods of their own" % pair)


func _check_colours(node: Variant, palette: Dictionary, bad: Array[String]) -> void:
	if node is Dictionary:
		var d := node as Dictionary
		for k: Variant in d:
			var v: Variant = d[k]
			if str(k) in COLOUR_KEYS and v is String and not str(v).begins_with("#") and not palette.has(str(v)):
				bad.append("%s: %s" % [k, v])
			elif str(k) == "colours" and v is Array:
				for c: Variant in v as Array:
					if not palette.has(str(c)):
						bad.append("colours: %s" % c)
			else:
				_check_colours(v, palette, bad)
	elif node is Array:
		for v: Variant in node as Array:
			_check_colours(v, palette, bad)
