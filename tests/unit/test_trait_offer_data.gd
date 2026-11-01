extends TestCase
## Monster traits that offer the heroes an action against the monster (a trait's `offers` block, the engine's
## TraitOffers): each names its check (a DC, or a save it contests) and what it does, and its ability event has a sound in art/audio.json.


func _offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in Compendium.shared().all("monsters"):
		for tr: Dictionary in m.get("traits", []):
			if tr.get("offers", null) is Dictionary:
				out.append({"monster": str(m.get("id", "")), "trait": tr})
	return out


func test_every_offer_has_its_check_and_its_sound() -> void:
	var found := _offers()
	assert_false(found.is_empty(), "some monster offers an action")
	for o in found:
		var tr := o["trait"] as Dictionary
		var offer := tr["offers"] as Dictionary
		var name := "%s.%s" % [o["monster"], tr["id"]]
		assert_true((offer.get("check", {}) as Dictionary).has("dc") or offer.get("contest", null) is Dictionary,
			"%s names its DC, or contests a save" % name)
		assert_true(not (offer.get("damage", []) as Array).is_empty() or not (offer.get("on_success", []) as Array).is_empty(),
			"%s does something on a success" % name)
		var key := str(offer.get("key", tr["id"]))
		assert_false((CombatSfx.own(key).get("cast", []) as Array).is_empty(), "%s's event (%s) plays a sound" % [name, key])


func test_the_court_dance_is_the_tall_mans() -> void:
	var tr := {}
	for t: Dictionary in Compendium.shared().monster_data("tall_man").get("traits", []):
		if str(t["id"]) == "memorys_dance":
			tr = t
	var offer := tr.get("offers", {}) as Dictionary
	assert_eq(str(offer.get("cost", "")), "bonus", "a Bonus Action")
	assert_eq(int((offer["check"] as Dictionary)["dc"]), 20, "DC 20 Performance")
	assert_eq(str((offer["check"] as Dictionary)["skill"]), "performance")
	var dmg := (offer["damage"] as Array)[0] as Dictionary
	assert_eq([int(dmg["amount"]), str(dmg["type"])], [20, "force"], "20 Force")
	assert_eq(str(((offer["on_success"] as Array)[0] as Dictionary)["until"]), "source_turn_start", "until the dancer's next turn")


func test_every_reveler_of_song_takes_up_a_music_contest() -> void:
	for form: String in ["bell", "drone", "drum"]:
		var offer := {}
		for t: Dictionary in Compendium.shared().monster_data("reveler_of_song_" + form).get("traits", []):
			if str(t["id"]) == "compelled_contest":
				offer = t.get("offers", {}) as Dictionary
		assert_eq(str(offer.get("key", "")), "reveler_contest", "%s: the contest's event" % form)
		assert_true(bool(offer.get("influence", false)), "%s: an Influence variant" % form)
		assert_eq(str(offer.get("needs", "")), "musical_instrument", "%s: played on an instrument" % form)
		assert_eq(str((offer["contest"] as Dictionary)["save"]), "cha", "%s: against its Charisma save" % form)
		var dmg := (offer["damage"] as Array)[0] as Dictionary
		assert_eq([int(dmg["amount"]), str(dmg["type"])], [20, "psychic"], "%s: 20 Psychic" % form)
		var rider := (offer["on_success"] as Array)[0] as Dictionary
		assert_eq([str(rider["condition"]), str(rider["until"])], ["stunned", "source_turn_end"], "%s: Stunned to the end of the player's next turn" % form)
