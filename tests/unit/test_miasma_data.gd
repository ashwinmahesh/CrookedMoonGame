extends TestCase
## The Deep Drift's Putrid Miasma (data/locations/sk_deep.json; the engine's PlaceHazards): DC 16 Con on entering and
## every ten minutes or Poisoned, hourly Exhaustion while it lasts, gone once the sigils are broken.


func test_the_deep_level_air() -> void:
	var hz := Compendium.shared().get_entry("locations", "sk_deep")["hazard"] as Dictionary
	assert_eq(int(hz["every_min"]), 10)
	assert_eq([str((hz["save"] as Dictionary)["ability"]), int((hz["save"] as Dictionary)["dc"])], ["con", 16])
	assert_eq(str(hz["condition"]), "poisoned")
	assert_eq(int((hz["lasting"] as Dictionary)["every_min"]), 60)
	assert_eq(str(hz["when"]), "not flag.skitter_sigils_broken")
