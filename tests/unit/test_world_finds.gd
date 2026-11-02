extends TestCase
## The magic laid in the world by hand in Acts I and II (data/treasure/world_finds.json, written into the places by
## tools/content/place_world_finds.py; Ashwin, 2026-11-02: more magic items to find, every one usable in a fight). Each find
## is in its container in its place, on a floor square the party can stand beside, and does something in a fight; random
## finds never roll an item that does nothing in one (levels.json support_weight 0).

const FINDS := "res://data/treasure/world_finds.json"
const LEVELS := "res://data/treasure/levels.json"
const ACTS_I_AND_II: Array[String] = ["ghostlight_express", "wickermoor", "crooked_house", "foxwillow", "crimson_monastery", "dawns_gate",
	"drowned_crossroads", "skitterdeep_mine", "memorys_rest"]


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s parses" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _finds() -> Array:
	return _json(FINDS).get("finds", []) as Array


func _container(loc: Dictionary, id: String) -> Dictionary:
	for c: Variant in loc.get("containers", []):
		if str((c as Dictionary)["id"]) == id:
			return c as Dictionary
	return {}


## Whether an item does something in a fight: a power a fight can use, a modifier, a weapon's or armor's rules, or a magic
## weapon, armor or shield built on a base.
func _works_in_a_fight(data: Dictionary) -> bool:
	for p: Variant in data.get("powers", []):
		if bool((p as Dictionary).get("combat", true)):
			return true
	if not (data.get("modifiers", []) as Array).is_empty() or data.has("weapon_rules") or data.has("armor_rules"):
		return true
	return str(data.get("category", "")) in ["weapon", "armor", "shield", "ammunition"]


func test_every_find_is_in_its_place_in_acts_one_and_two() -> void:
	assert_true(_finds().size() >= 15, "a find in each of the places that had few or none")
	for f: Variant in _finds():
		var e := f as Dictionary
		var loc := Compendium.shared().get_entry("locations", str(e["loc"]))
		assert_false(loc.is_empty(), "%s is a place" % e["loc"])
		assert_true(str(loc.get("region", "")) in ACTS_I_AND_II, "%s is in Act I or II" % e["loc"])
		var c := _container(loc, str(e.get("container", e.get("id", ""))))
		assert_false(c.is_empty(), "%s holds its find's container" % e["loc"])
		var held := {}
		for it: Variant in c.get("items", []):
			held[str((it as Dictionary)["id"])] = true
		for id: Variant in e["items"]:
			assert_true(held.has(str(id)), "%s is in %s" % [id, e["loc"]])


func test_a_new_container_stands_on_floor_without_taking_a_square() -> void:
	for f: Variant in _finds():
		var e := f as Dictionary
		if e.has("container"):
			continue
		var loc := Compendium.shared().get_entry("locations", str(e["loc"]))
		var cell := e["cell"] as Array
		var rows := (loc["map"] as Dictionary)["rows"] as Array
		var ch := str(rows[int(cell[1])])[int(cell[0])]
		assert_true(ch in [".", "_"], "%s's find stands on floor (%s)" % [e["loc"], ch])
		assert_eq(_container(loc, str(e["id"]))["cell"], cell, "%s's container is where the file says" % e["loc"])


func test_every_find_works_in_a_fight() -> void:
	var support := _json(LEVELS).get("support_items", []) as Array
	for f: Variant in _finds():
		for id: Variant in (f as Dictionary)["items"]:
			var made := MagicItems.concrete(str(id), Compendium.shared())
			var data := Compendium.shared().item_data(made)
			assert_true(MagicItems.is_magic(data), "%s is a magic item" % id)
			assert_true(Compendium.playable(data), "%s is playable" % id)
			assert_false(str(id).get_slice(MagicItems.SEP, 0) in support, "%s is not one of the items that do nothing in a fight" % id)
			var own := Compendium.shared().get_entry("magic_items", str(id).get_slice(MagicItems.SEP, 0))
			assert_true(_works_in_a_fight(own), "%s does something in a fight" % id)


func test_random_finds_never_roll_an_item_with_no_use_in_a_fight() -> void:
	assert_eq(float(_json(LEVELS).get("support_weight", 1.0)), 0.0, "support items have no weight on the random tables")
	Treasure.reset()
	var support := {}
	for id: Variant in _json(LEVELS).get("support_items", []):
		support[str(id)] = true
	for rarity: String in Treasure.pools():
		for th: String in (Treasure.pools()[rarity] as Dictionary):
			for it: Variant in (Treasure.pools()[rarity] as Dictionary)[th]:
				var e := it as Dictionary
				if support.has(str(e["id"])):
					assert_eq(float(e["weight"]), 0.0, "%s never rolls" % e["id"])
