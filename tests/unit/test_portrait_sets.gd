extends TestCase
## The photographs in the turn order and the Bestiary (addons/dnd_core/docs/reference/ui/portraits.md; the engine's PortraitArt): a monster's portrait
## is art/portraits/monsters/<stat block id>.webp, a character's art/portraits/characters/<art id>.webp or the one they
## already had, and until a picture exists the chip shows a silhouette. The art lane adds pictures one file at a time, so
## nothing here depends on which exist: it checks the lookup, the chips and the Bestiary entry with and without one.


func before_each() -> void:
	PortraitArt.reset()


func after_each() -> void:
	PortraitArt.reset()


func _fight() -> Encounter:
	var rows: Array[String] = []
	for z in 8:
		rows.append("............")
	return TestCombat.encounter(rows, 1)


func test_the_game_turns_the_photographs_on() -> void:
	assert_true(PortraitArt.photoreal())
	assert_true(PortraitArt.large())
	assert_eq(PortraitArt.rel_paths("wayward_haint", "wayward_haint")[0], "art/portraits/monsters/wayward_haint.webp")


func test_every_monster_id_names_a_file_the_art_lane_can_make() -> void:
	# The convention is the data file's name: lower snake case, so the lane's folder is a plain list of the bestiary.
	for f in DirAccess.get_files_at("res://data/monsters"):
		if f.ends_with(".json"):
			var id := f.get_basename()
			assert_eq(id, id.to_lower(), "%s is lower case" % id)
			assert_false(id.contains(" "), "%s has no spaces" % id)


func test_a_villager_has_her_photograph_cut_to_a_chip() -> void:
	var tex := PortraitArt.texture("adela_druskenvald")
	assert_true(tex != null, "the villagers' photographs are art/portraits/<id>.png")
	var chip := PortraitArt.square(tex)
	assert_eq(chip.get_width(), chip.get_height(), "square in a chip")
	assert_true(chip.get_width() <= tex.get_width())


func test_a_monster_without_a_picture_shows_a_silhouette_in_the_order_and_the_bestiary() -> void:
	var missing := "no_such_portrait"
	assert_true(PortraitArt.texture(missing, missing) == null)
	var chip := UiParts.framed_portrait(missing, 34.0, false, false, missing)
	assert_true(chip.find_child("Placeholder", true, false) != null)
	chip.free()


func test_a_foe_in_the_order_gets_a_chip() -> void:
	var e := _fight()
	var foe := e.add(TestCombat.monster("wayward_haint"), &"enemy", Vector2i(4, 4))
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2))
	for c: Combatant in [foe, hero]:
		var chip := UiParts.framed_portrait_of(c, 44.0)
		assert_eq(chip.custom_minimum_size, Vector2(44, 44))
		chip.free()
	assert_eq(PortraitArt.monster_id_of(foe), "wayward_haint")
	assert_eq(PortraitArt.monster_id_of(hero), "")


func test_a_bestiary_entry_leads_with_the_large_portrait() -> void:
	var st := StoryState.new()
	st.bestiary["wayward_haint"] = {"n": 0, "met": 1, "where": "", "defeated": 1}
	var entry := BestiaryPage.entry(st, "wayward_haint")
	var head := entry.get_child(0) as HBoxContainer
	var pic := head.get_child(0) as Control
	assert_eq(pic.custom_minimum_size.x, BestiaryPage.ENTRY_PORTRAIT_W, "the entry's portrait, not the small token")
	assert_true(pic.custom_minimum_size.y >= BestiaryPage.ENTRY_PORTRAIT_W * PortraitArt.LARGE_SHORT - 1.0)
	entry.free()
