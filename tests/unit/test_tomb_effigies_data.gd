extends TestCase
## The Harrowing's set pieces (data/locations/mm_tomb.json, the engine's ObjectCarry): five effigies to carry, and eight
## braziers that take them, harm those who come near, and tighten once the Reaper's second phase begins.


func _harrowing() -> Dictionary:
	for e: Dictionary in Compendium.shared().get_entry("locations", "mm_tomb")["encounters"]:
		if str(e["id"]) == "mm_harrowing":
			return e
	return {}


func test_five_effigies_to_carry() -> void:
	var objs := (_harrowing()["objects"] as Array).filter(func(o: Dictionary) -> bool: return o.has("carry"))
	assert_eq(objs.size(), 5, "the sixth coffin is empty")
	for o: Dictionary in objs:
		assert_eq(int((o["study"] as Dictionary)["dc"]), 13)


func test_eight_braziers_take_them() -> void:
	var rules := _harrowing()["object_rules"] as Array
	assert_eq(rules.size(), 8)
	for r: Dictionary in rules:
		assert_eq(str((r["takes"] as Dictionary)["tag"]), "fallen_effigy")
		assert_eq(int(((r["takes"] as Dictionary)["damage"] as Dictionary)["amount"]), 10)
		var dcs := (r["hazard"] as Array).map(func(h: Dictionary) -> int: return int((h["save"] as Dictionary)["dc"]))
		assert_eq(dcs, [13, 15, 15], "DC 13, then 15 in the second phase")
