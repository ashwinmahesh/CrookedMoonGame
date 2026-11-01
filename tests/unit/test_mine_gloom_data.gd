extends TestCase
## The mine's Oppressive Gloom (data/locations/sk_upper.json, sk_deep.json; the engine's sight rules): every light at
## half its reach, Darkvision to 15 ft, and the hag and her marked denizens seeing as ever.


func test_both_underground_levels() -> void:
	for loc: String in ["sk_upper", "sk_deep"]:
		var s := (Compendium.shared().get_entry("locations", loc)["map"] as Dictionary)["sight"] as Dictionary
		assert_eq(float(s["light_scale"]), 0.5, loc)
		assert_eq(int(s["darkvision_cap"]), 15, loc)
		assert_true("centipede_hag" in ((s["immune"] as Dictionary)["names"] as Array), "%s: Stonoga sees as ever" % loc)
