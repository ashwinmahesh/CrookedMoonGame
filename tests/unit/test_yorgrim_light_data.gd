extends TestCase
## Yorgrim's balefire lantern (data/npcs/yorgrim.json; the engine's WardLights): 30 ft of Bright Light that the shrouded
## can't enter and are hindered in, 5 and 15 ft once all six beacons burn, and dark in the corrupted tomb.


func test_his_lantern() -> void:
	var w := Compendium.shared().get_entry("npcs", "yorgrim")["ward_light"] as Dictionary
	assert_eq([int(w["bright"]), int(w["dim"])], [30, 30])
	for id: String in ["shrouded_devourer", "shrouded_reaper", "shrouded_whisperer"]:
		assert_true(id in (w["keep_out"] as Array) and id in (w["disadvantage"] as Array), id)
	var small := w["small"] as Dictionary
	assert_eq([int(small["bright"]), int(small["dim"])], [5, 15])
	assert_true("mm_tomb" in (w["off_at"] as Array))
