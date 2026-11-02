extends TestCase
## R12, the Crooked House: the data the maps, dialogue and wiring workers build on. The flags are registered and typed, the
## quests have a hint on every open stage and a success ending, the six mementos are quest items nobody can sell or drop, the
## new monsters load with the numbers of the blocks they vary, the eleven new people and the disguised Adela are in the
## Compendium, and the five places have a mood of their own in the crooked sepia-and-mildew look.

const REGION := "crooked_house"
const MEMENTOS := ["memento_bloodstone", "memento_black_key", "memento_porcelain_cup", "memento_wooden_doll", "memento_blue_bear",
	"memento_silver_pin"]
const QUESTS := ["the_crooked_house", "petunias_cup", "sallys_monsters", "arthurs_bear", "a_tale_for_wisp", "find_my_son"]
const NPCS := ["crooked_man", "vessla_browntooth", "filthy_jasper", "petunia_lockwood", "sally_lockwood", "arthur_lockwood",
	"keziah_endicott", "joseph_patrini", "gail_patrini", "wisp", "shuck", "adela_druskenvald_ruse"]
const PLACES := ["druskenvald_estate", "crooked_house_first", "crooked_house_second", "crooked_house_third", "crooked_house_attic"]

## The int flags and the string one; everything else in the registry is a bool.
const INTS := ["portrait_cursed", "mementos_placed", "wisp_tales", "moon_twists", "h15_challenge_successes", "seance_stings", "crooked_house_retries"]
const STRINGS := ["lurker_spot", "rook_inc_choice", "tobin_inc_choice", "lucan_inc_choice"]
## Words a `read_later` flag's summary must use to say who reads it.
const READERS := ["chapter", "Lane F", "world lane", "curse hook", "Twist"]


func _flags() -> Dictionary:
	var out := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/crooked_house.json"))
	assert_true(parsed is Dictionary, "the flag registry parses")
	for f: Variant in (parsed as Dictionary).get("flags", []):
		out[str((f as Dictionary)["id"])] = f
	return out


func _quest(id: String) -> Dictionary:
	return Compendium.shared().get_entry("quests", id)


func test_every_flag_of_the_contract_is_registered_and_typed() -> void:
	var flags := _flags()
	var wanted: Array[String] = ["crooked_house_turned", "crooked_man_met", "seance_done", "patrini_asked_find_son", "portrait_cursed",
		"mementos_placed", "petunia_at_peace", "petunia_destroyed", "green_ribbon_found", "sally_rested", "arthur_rested", "the_bag_taken",
		"jasper_fled", "jasper_slain", "wisp_tales", "wisp_exposed", "wisp_slain", "wisp_catch_pending", "vessla_ruse_seen",
		"vessla_tooth_gift", "vessla_slain", "coven_names_known", "druskenvald_manor_restored", "moon_twists", "trapdoor_known",
		"h15_challenge_successes", "lurker_spot", "weasels_in_village", "rook_inc_choice", "tobin_inc_choice", "lucan_inc_choice"]
	for n: int in range(1, 9):
		wanted.append("seance_asked_%d" % n)
	for k: String in ["gem", "key", "cup", "doll", "bear", "pin"]:
		wanted.append("memento_" + k)
	for t: String in ["pilgrimage", "rejuvenation", "slaughter", "duality", "immortality", "kindred", "malediction", "rapture"]:
		wanted.append("incitement_" + t)
	for t: String in ["pilgrimage", "rejuvenation", "slaughter"]:
		wanted.append("pending_%s_incitement" % t)
	for id: String in wanted:
		assert_true(flags.has(id), "%s is registered" % id)
	for id: String in flags:
		var f := flags[id] as Dictionary
		var want := "int" if id in INTS else ("string" if id in STRINGS else "bool")
		assert_eq(str(f.get("type")), want, "%s's type" % id)
		assert_true(str(f.get("summary", "")).length() > 20, "%s has an honest summary" % id)


func test_a_flag_for_a_later_reader_names_who_reads_it() -> void:
	var flags := _flags()
	var later := 0
	for id: String in flags:
		var f := flags[id] as Dictionary
		if not bool(f.get("read_later", false)):
			continue
		later += 1
		var said := false
		for w: String in READERS:
			if str(f["summary"]).contains(w):
				said = true
		assert_true(said, "%s is read later: its summary says by whom" % id)
	# The chapter's own flags (seance questions, mementos, the ward's count) are read inside the chapter.
	for id: String in ["mementos_placed", "trapdoor_known", "memento_gem", "seance_asked_3", "wisp_tales"]:
		assert_false(bool((flags[id] as Dictionary).get("read_later", false)), "%s is read in this chapter" % id)
	assert_true(later >= 10, "the flags later chapters read are marked")
	assert_true(bool((flags["vessla_slain"] as Dictionary)["read_later"]), "vessla_slain is read by chapters 13, 16 and 20")
	assert_eq(str((flags["lurker_spot"] as Dictionary).get("set_by")), "engine", "the lurker's spot is the game's answer, never data's")


func test_the_quests_have_hints_and_a_success() -> void:
	for id: String in QUESTS:
		var q := _quest(id)
		assert_true(not q.is_empty(), "%s is data" % id)
		assert_eq(str(q.get("region")), REGION, "%s is filed under the house" % id)
		assert_eq(str(q.get("kind")), "main" if id == "the_crooked_house" else "side", "%s's kind" % id)
		var succeeds := false
		for s: Dictionary in q["stages"]:
			assert_true(str(s.get("journal", "")).length() > 20, "%s/%s has a journal line" % [id, s["id"]])
			if str(s.get("ends", "")) == "":
				assert_true(str(s.get("hint", "")).strip_edges() != "", "%s/%s has a hint" % [id, s["id"]])
			elif str(s["ends"]) == "success":
				succeeds = true
		assert_true(succeeds, "%s can end in success" % id)


func test_the_main_quest_runs_in_the_contracts_order() -> void:
	var ids: Array[String] = []
	for s: Dictionary in _quest("the_crooked_house")["stages"]:
		ids.append(str(s["id"]))
	assert_eq(ids, ["invited", "arrived", "trapped", "mementos", "attic", "vessla", "done"] as Array[String], "the stages")
	assert_eq(str(_quest("the_crooked_house")["stages"][-1]["ends"]), "success", "the last stage is the success")


func test_the_mementos_are_quest_items_nobody_sells_or_drops() -> void:
	for id: String in MEMENTOS:
		var d := Compendium.shared().item_data(id)
		assert_true(not d.is_empty(), "%s is an item" % id)
		assert_eq(str(d.get("category")), "quest", "%s is a quest item" % id)
		assert_true(InventoryScreen.is_quest(d), "%s can't be dropped or sold" % id)
		assert_eq(float(d.get("cost_gp", -1)), 0.0, "%s has no price" % id)


func test_the_loot_has_its_prices() -> void:
	var items := Compendium.shared()
	assert_eq(float(items.item_data("gold_ring_75")["cost_gp"]), 75.0, "the ring is worth 75 gp")
	assert_eq(float(items.item_data("gold_pocket_watch")["cost_gp"]), 100.0, "the watch is worth 100 gp")
	assert_true(bool(items.item_data("human_tooth").get("stackable", false)), "teeth pile up")
	var duck := items.item_data("yellow_duck_figurine")
	assert_eq(str(((duck["powers"] as Array)[0] as Dictionary)["custom"]), "summon_monster", "the duck animates like the raven figurine")


func test_the_cursed_curios_say_so_and_the_ribbon_helps_the_dying() -> void:
	var ribbon := Compendium.shared().item_data("green_ribbon")
	var magic := ribbon["magic"] as Dictionary
	assert_eq(str(magic["rarity"]), "rare", "the ribbon is Rare")
	assert_true(bool(magic["cursed"]) and bool(magic["attunement"]), "cursed, and it asks to be attuned")
	var bonus := 0
	for m: Dictionary in ribbon["modifiers"]:
		if str(m["stat"]) == "bonus_die" and "death_save" in (m["on"] as Array):
			bonus = int(DiceRoller.parse_expr(str(m["dice"]))["modifier"])
	assert_eq(bonus, 5, "+5 on death saves")
	var bag := Compendium.shared().item_data("the_bag")
	assert_eq(str((bag["magic"] as Dictionary)["rarity"]), "very_rare", "The Bag is Very Rare")
	assert_true(bool((bag["magic"] as Dictionary)["cursed"]), "and cursed")
	assert_true((bag["container"] as Dictionary).has("capacity_lb"), "and it holds things")


func test_the_peacock_is_a_basilisk_made_of_stone() -> void:
	var peacock := TestCombat.monster("marble_peacock")
	var basilisk := TestCombat.monster("basilisk")
	assert_eq(peacock.max_hp(), 52, "52 Hit Points")
	assert_eq(peacock.ac_value(), 15, "Armor Class 15")
	assert_eq(peacock.max_hp(), basilisk.max_hp(), "the basilisk's Hit Points")
	assert_eq(str(peacock.data["type"]), "construct", "a Construct")
	assert_eq(int(peacock.data["cr"]), 3, "Challenge 3")
	var ids: Array[String] = []
	for t: Dictionary in peacock.data["traits"]:
		ids.append(str(t["id"]))
	assert_true("stone_dies_with_it" in ids, "what it petrified is freed when it crumbles")
	assert_true(not (peacock.data["bonus_actions"] as Array).is_empty(), "it keeps its Petrifying Gaze")


func test_petunia_is_a_wight_with_only_life_drain() -> void:
	var petunia := TestCombat.monster("petunia_lockwood")
	var wight := TestCombat.monster("wight")
	assert_eq(petunia.max_hp(), wight.max_hp(), "the wight's 82 Hit Points")
	assert_eq(petunia.ac_value(), 14, "Armor Class 14")
	assert_eq(str(petunia.data["alignment"]), "neutral", "Neutral")
	var actions: Array[String] = []
	for a: Dictionary in petunia.data["actions"]:
		actions.append(str(a["id"]))
	assert_eq(actions, ["life_drain"] as Array[String], "Life Drain is all she has")
	var traits: Array[String] = []
	for t: Dictionary in petunia.data["traits"]:
		traits.append(str(t["id"]))
	assert_true("green_ribbon" in traits, "the ribbon is her weakness")


func test_the_three_quasit_toys_are_quasits() -> void:
	var quasit := TestCombat.monster("quasit")
	var names := {}
	for id: String in ["quasit_goat", "quasit_bunny", "quasit_crow"]:
		var m := TestCombat.monster(id)
		assert_eq(m.max_hp(), quasit.max_hp(), "%s has a quasit's Hit Points" % id)
		assert_eq(m.ac_value(), quasit.ac_value(), "%s has a quasit's Armor Class" % id)
		assert_eq(int(m.data["cr"]), 1, "%s is Challenge 1" % id)
		assert_eq((m.data["actions"] as Array).size(), (quasit.data["actions"] as Array).size(), "%s has a quasit's actions" % id)
		assert_true(str(m.data.get("art", "")) != "" and str(m.data["art"]) != "quasit_familiar", "%s wears a toy's look" % id)
		names[str(m.data["name"])] = true
	assert_eq(names.size(), 3, "three different toys")


func test_the_new_people_are_in_the_house_and_the_ruse_is_a_hag() -> void:
	var monsters := {"vessla_browntooth": "weasel_hag", "filthy_jasper": "vermin_familiar_weasel", "petunia_lockwood": "petunia_lockwood",
		"wisp": "ketgrinn", "shuck": "wolf", "adela_druskenvald_ruse": "weasel_hag"}
	for id: String in NPCS:
		var npc := Compendium.shared().get_entry("npcs", id)
		assert_true(not npc.is_empty(), "%s is an NPC" % id)
		assert_eq(str(npc.get("region")), REGION, "%s's region" % id)
		assert_true(["hostile", "indifferent", "friendly"].has(str(npc.get("attitude"))), "%s has an attitude" % id)
		assert_true(str(npc.get("title", "")) != "" and str(npc.get("summary", "")) != "", "%s has a title and a summary" % id)
		if monsters.has(id):
			assert_eq(str(npc.get("monster")), monsters[id], "%s's stat block" % id)
			assert_false(Compendium.shared().monster_data(str(npc["monster"])).is_empty(), "%s's block exists" % id)
		else:
			assert_false(npc.has("monster"), "%s has no stat block" % id)
	var crooked := Compendium.shared().get_entry("npcs", "crooked_man")
	assert_ne(str(crooked["attitude"]), "hostile", "the Crooked Man is never a target")
	var ruse := Compendium.shared().get_entry("npcs", "adela_druskenvald_ruse")
	var real := Compendium.shared().get_entry("npcs", "adela_druskenvald")
	# Legendary.same_person drops "Lady", so a hag named Adela Druskenvald takes this record's figure; test_data_integrity keeps names unique.
	assert_true(Legendary.same_person(str(ruse["name"]), str(real["name"])), "the ruse wears Adela's name")
	assert_ne(str(ruse["name"]), str(real["name"]), "but display names stay unique")
	assert_eq(str(ruse["sprite"]), str(real["sprite"]), "and her figure")
	assert_false(bool(ruse.get("guest", false)), "and is no guest")
	assert_eq(str(Compendium.shared().get_entry("npcs", "vessla_browntooth")["name"]), "Vessla Browntooth", "the boss's name")


func test_the_five_places_have_a_crooked_mood() -> void:
	var palette := (JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/palette.json")) as Dictionary)
	var moods := {}
	# The house is one place now with its four floors in it (HouseFloors), so it has the one look; the attic's own (crooked_attic)
	# waits on a mood per floor.
	for id: String in ["druskenvald_estate", HouseFloors.PLACE]:
		var mood := Atmosphere.mood_for(id, {})
		assert_true(["crooked_estate", "crooked_house", "crooked_attic"].has(mood), "%s has a mood of the house, not %s" % [id, mood])
		moods[mood] = true
	assert_eq(moods.size(), 2, "the grounds and the house look different")
	assert_eq(Atmosphere.mood_for("some_new_floor", {"region": REGION, "map": {"outdoors": false}}), "crooked_house", "a new floor takes the house's look")
	assert_eq(Atmosphere.mood_for("some_new_yard", {"region": REGION, "map": {"outdoors": true}}), "crooked_estate", "and a new yard the grounds'")
	for mood: String in moods:
		var resolved := Atmosphere.resolve(mood)
		assert_true(resolved.has("times") or resolved.has("modern"), "%s has light" % mood)
		var bad: Array[String] = []
		_check_colours(resolved, palette, bad)
		assert_eq(bad, [] as Array[String], "%s uses only palette colours" % mood)


## Every colour a mood names (sky, fog, ambient, key, mist, grade, tone, flame_tint...) is a palette name (or a #hex tint).
func _check_colours(node: Variant, palette: Dictionary, bad: Array[String]) -> void:
	const COLOUR_KEYS := ["sky", "fog", "ambient", "key", "mist", "shadows", "lights", "shade", "colour", "core", "rim", "moon_colour"]
	if node is Dictionary:
		var d := node as Dictionary
		for k: Variant in d:
			var v: Variant = d[k]
			if str(k) in COLOUR_KEYS and v is String and not palette.has(str(v)):
				bad.append("%s: %s" % [k, v])
			else:
				_check_colours(v, palette, bad)
	elif node is Array:
		for v: Variant in node as Array:
			_check_colours(v, palette, bad)
