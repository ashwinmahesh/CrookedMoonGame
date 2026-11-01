extends TestCase
## The mine's Oppressive Gloom (data/locations/sk_upper.json, sk_deep.json; the engine's sight rules): every light at
## half its reach, Darkvision to 15 ft, and the hag and her marked denizens seeing as ever.


func test_both_underground_levels() -> void:
	for loc: String in ["sk_upper", "sk_deep"]:
		var s := (Compendium.shared().get_entry("locations", loc)["map"] as Dictionary)["sight"] as Dictionary
		assert_eq(float(s["light_scale"]), 0.5, loc)
		assert_eq(int(s["darkvision_cap"]), 15, loc)
		assert_true("centipede_hag" in ((s["immune"] as Dictionary)["names"] as Array), "%s: Stonoga sees as ever" % loc)


## The cemetery's Ghastly Mist: nothing seen past 60 ft outdoors, until the site's beacon is lit (on the roads and the
## sepulcher's hill, until all six are).
func test_the_cemetery_mist_lifts_with_the_beacons() -> void:
	var sites := {"mm_highborn_crypts": "not flag.beacon_crimson", "mm_cremation_gardens": "not flag.beacon_violet",
		"mm_potters_field": "not flag.beacon_amber", "mm_mausoleum_lanes": "not flag.beacon_magenta",
		"mm_burial_mounds": "not flag.beacon_emerald", "mm_gate": "flag.mm_beacons_lit < 6"}
	for loc: String in sites:
		var s := (Compendium.shared().get_entry("locations", loc)["map"] as Dictionary)["sight"] as Dictionary
		assert_eq(int(s["sight_ft"]), 60, loc)
		assert_eq(str(s["when"]), sites[loc], loc)
