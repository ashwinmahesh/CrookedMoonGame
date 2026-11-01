extends TestCase
## The campaign's afflictions (data/afflictions, the engine's Afflictions): the Hartsblight's numbers as the book has
## them.


func test_the_hartsblight_by_level() -> void:
	var d := Compendium.shared().get_entry("afflictions", "hartsblight")
	assert_false(d.is_empty(), "defined")
	var per := {}
	for m: Dictionary in d["modifiers"]:
		per[str(m["stat"]) + ":" + str(m.get("ability", ""))] = int(m["per_level"])
	assert_eq(per, {"save:con": -1, "attack:": -1, "healing_received:": -1}, "1 per level off Con saves, attacks and healing")
	var th := (d["thresholds"] as Array)[0] as Dictionary
	assert_eq(int(th["at"]), 6, "halved at 6 or more")
	assert_true(bool(th["halve_hp"]))
	var rest := d["long_rest"] as Dictionary
	assert_eq([str(rest["success"]), str(rest["failure"]), int(rest["min"])], ["mod:con", "half_mod:con", 1], "the Long Rest save")
	assert_eq(int((rest["save"] as Dictionary)["dc"]), 10)
	assert_false(d.has("blocked_by"), "poison immunity doesn't keep it out")


func test_the_rotten_hearts_symptoms() -> void:
	var sy := Compendium.shared().get_entry("afflictions", "hartsblight")["symptoms"] as Dictionary
	assert_eq((sy["table"] as Array).size(), 6, "six, as the book's d6")
	assert_eq(int((sy["save"] as Dictionary)["dc"]), 10)
	assert_true(str(sy["when"]).contains("at:hb_wellspring") and str(sy["when"]).contains("at:hb_den"), "only in the Rotten Heart")
	for loc: String in ["hb_wellspring", "hb_den"]:
		assert_false(Compendium.shared().get_entry("locations", loc).is_empty(), loc)


func test_the_symptoms_that_act_in_a_fight() -> void:
	var by := {}
	for t: Dictionary in (Compendium.shared().get_entry("afflictions", "hartsblight")["symptoms"] as Dictionary)["table"]:
		by[str(t["id"])] = t
	assert_eq(str((by["addled"]["on_initiative"] as Dictionary)["flag"]), "confused", "Confusion as Initiative is rolled")
	assert_eq(str((by["bleeding"]["on_hurt"] as Dictionary)["dice"]), "1d10", "1d10 Necrotic with every wound")
	assert_true((by["fever"]["modifiers"] as Array).any(func(m: Dictionary) -> bool: return str(m["on"]) == "attack:str"))
	assert_true((by["shakes"]["modifiers"] as Array).any(func(m: Dictionary) -> bool: return str(m["on"]) == "attack:dex"))


func test_the_skitter_plague() -> void:
	var d := Compendium.shared().get_entry("afflictions", "skitter_plague")
	assert_false(d.is_empty())
	assert_eq([int(d["onset_hours"]), int(d["onset_exhaustion"]), bool(d["exhaustion_lock"])], [2, 1, true], "a fever that won't break")
	assert_eq(str((d["long_rest"] as Dictionary)["max_hp_loss"]), "1d4", "blisters with every night's sleep")
	var daily := d["daily"] as Dictionary
	assert_eq([int(daily["hour"]), int((daily["save"] as Dictionary)["dc"]), int(daily["successes_to_end"])], [7, 15, 3],
		"DC 15 at the Twilight Hour, three to end it")
	assert_true("lesser_restoration" in (d["held_off_by"] as Array))
