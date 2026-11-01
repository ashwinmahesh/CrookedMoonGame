extends TestCase
## The monastery's blood (data/locations/mon_holy_vein.json, mon_sanctum.json; the engine's AreaHazards): ending a turn
## in it is a DC 13 Con save or Poisoned while there, sparing fiends and undead.


func _hazard(loc: String, area: String) -> Dictionary:
	for a: Dictionary in Compendium.shared().get_entry("locations", loc)["areas"]:
		if str(a["id"]) == area:
			return a.get("hazard", {})
	return {}


func test_the_vein_and_the_moat() -> void:
	for pair: Array in [["mon_holy_vein", "vein"], ["mon_sanctum", "moat"]]:
		var hz := _hazard(pair[0], pair[1])
		assert_eq(int((hz["save"] as Dictionary)["dc"]), 13, pair[0])
		assert_eq(str(hz["condition"]), "poisoned")
		assert_eq(hz["except_types"], ["fiend", "undead"])
		assert_true(bool(hz["only_difficult"]), "the blood squares only")
