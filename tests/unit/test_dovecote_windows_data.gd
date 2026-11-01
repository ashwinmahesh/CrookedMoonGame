extends TestCase
## The dovecote's windows (data/locations/rk_dovecote_r2.json; the engine's FightOpenings): Golub throws a held hero out
## of one, 20 ft to the ground, and they climb back in (Athletics DC 15).


func test_golub_and_her_windows() -> void:
	var fights := (Compendium.shared().get_entry("locations", "rk_dovecote_r2")["encounters"] as Array).filter(
		func(e: Dictionary) -> bool: return str(e["id"]) == "rk_golub")
	assert_eq(fights.size(), 2, "with Albert and without")
	for f: Dictionary in fights:
		var op := (f["openings"] as Array)[0] as Dictionary
		assert_eq((op["cells"] as Array).size(), 4, "four windows")
		assert_eq(int(op["drop_ft"]), 20)
		assert_eq(int((op["climb"] as Dictionary)["dc"]), 15)
	var traits := Compendium.shared().get_entry("monsters", "pigeon_hag")["traits"] as Array
	assert_true(traits.any(func(t: Dictionary) -> bool: return t.has("throws_out")))
