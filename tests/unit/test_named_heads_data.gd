extends TestCase
## Heads in the campaign's stat blocks: the hydra's Reactive Heads, and the Vermintoll Abomination's three hag heads, each
## giving one legendary option that goes when that head dies.


func _trait(id: String, trait_id: String) -> Dictionary:
	for t: Dictionary in Compendium.shared().get_entry("monsters", id)["traits"]:
		if str(t["id"]) == trait_id:
			return t
	return {}


func test_the_hydra_strikes_back_with_every_head() -> void:
	assert_true(bool(_trait("hydra", "multiple_heads").get("oa_per_head", false)))


func test_each_hag_head_gives_its_own_option() -> void:
	for id: String in ["vermintoll_abomination", "vermintoll_abomination_dream"]:
		var names: Array = _trait(id, "multiple_heads")["head_names"]
		assert_eq(names.size(), 3, id)
		var needs := {}
		for o: Dictionary in Compendium.shared().get_entry("monsters", id)["legendary_actions"]["options"]:
			if o.has("requires_head"):
				assert_true(str(o["requires_head"]) in names, "%s: %s names a head it has" % [id, o["id"]])
				needs[str(o["requires_head"])] = true
		assert_eq(needs.size(), 3, "%s: one option for each head" % id)
