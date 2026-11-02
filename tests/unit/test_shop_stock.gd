extends TestCase
## Every item that isn't the story's is for sale somewhere (Ashwin, 2026-11-02): mundane gear, magic items and a Spell Scroll of
## every spell, at the Wickermoor Hollow counters and the Act II ones (data/treasure/shop_stock.json, written into data/npcs by
## tools/content/build_shop_stock.py). A magic item shows at its rarity's level (Trade.magic_stock), so a level 1 party sees no
## rare stock and a party past level 10 sees all of it.

const STOCK := "res://data/treasure/shop_stock.json"


func _stock() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STOCK))
	assert_true(parsed is Dictionary, "shop_stock.json parses")
	return parsed as Dictionary if parsed is Dictionary else {}


func _merchants() -> Array[String]:
	var out: Array[String] = []
	for k: String in (_stock().get("merchants", {}) as Dictionary):
		if not k.begins_with("_") and k != "fallback":
			out.append(k)
	return out


## The rule build_shop_stock.py follows: what some counter must carry.
func _for_sale(d: Dictionary, banned: Dictionary) -> bool:
	if banned.has(str(d["id"])) or not Compendium.playable(d) or str(d.get("category", "")) == "quest" or bool(d.get("quest_locked", false)):
		return false
	if MagicItems.is_magic(d):
		if MagicItems.rarity(d) == "artifact" or not bool((d.get("treasure", {}) as Dictionary).get("random", true)):
			return false
		if str((d.get("template", {}) as Dictionary).get("on", "")) == "spell":
			return false
	return true


## Every id a merchant's file names, mundane and magic.
func _on_counters() -> Dictionary:
	var out := {}
	for m in _merchants():
		var shop := Compendium.shared().get_entry("npcs", m).get("shop", {}) as Dictionary
		assert_false(shop.is_empty(), "%s has a shop" % m)
		for w: Variant in shop.get("sells", []):
			out[str((w as Dictionary)["id"])] = m
		for v: Variant in shop.get("magic", []):
			out[str(v)] = m
	return out


func _party_of(level: int) -> StoryState:
	var st := StoryState.new()
	st.start_level = level
	return st


func test_every_item_that_isnt_the_storys_is_on_a_counter() -> void:
	var banned := {}
	for v: Variant in (_stock().get("not_for_sale", {}) as Dictionary).get("items", []):
		banned[str(v)] = true
	var sold := _on_counters()
	var missing: Array[String] = []
	var comp := Compendium.shared()
	for folder: String in ["items", "magic_items"]:
		for d in comp.all(folder):
			if _for_sale(d, banned) and not sold.has(str(d["id"])):
				missing.append(str(d["id"]))
	assert_eq(missing, [] as Array[String], "every item for sale is on some counter")
	assert_true(sold.size() > 900, "the counters hold the whole catalogue (%d)" % sold.size())


func test_a_scroll_of_every_spell_is_for_sale() -> void:
	var sold := _on_counters()
	var missing: Array[String] = []
	for sp in Compendium.shared().all_playable("spells"):
		var classes := sp.get("classes", []) as Array
		if classes.is_empty():
			continue
		var id := "spell_scroll%s%s" % [MagicItems.SEP, sp["id"]]
		if not sold.has(id):
			missing.append(id)
			continue
		var data := Compendium.shared().item_data(id)
		assert_eq(str(data.get("scroll_spell", "")), str(sp["id"]), "%s is a scroll of its spell" % id)
	assert_eq(missing, [] as Array[String], "a scroll of every spell")


func test_spells_on_divine_lists_are_at_the_chapel_and_arcane_ones_at_the_bookstore() -> void:
	var weston := (Compendium.shared().get_entry("npcs", "weston_murdoch")["shop"] as Dictionary)["magic"] as Array
	var eleanor := (Compendium.shared().get_entry("npcs", "eleanor_heyling")["shop"] as Dictionary)["magic"] as Array
	assert_true("spell_scroll__cure_wounds" in weston and "spell_scroll__cure_wounds" in eleanor, "a spell on both kinds of list is at both")
	assert_true("spell_scroll__fireball" in eleanor and not "spell_scroll__fireball" in weston, "an arcane spell at the bookstore only")
	assert_true("spell_scroll__spirit_guardians" in weston and not "spell_scroll__spirit_guardians" in eleanor, "a divine spell at the chapel only")


func test_every_line_on_a_counter_is_a_real_item() -> void:
	var comp := Compendium.shared()
	for id: String in _on_counters():
		assert_false(comp.item_data(id).is_empty(), "%s is an item" % id)


func test_magic_stock_opens_with_the_partys_level() -> void:
	var low := _party_of(1)
	var high := _party_of(12)
	var rarities_low := {}
	var count_high := 0
	var count_low := 0
	for m in _merchants():
		for w in Trade.magic_stock(low, m):
			rarities_low[MagicItems.rarity(Compendium.shared().item_data(str(w["id"])))] = true
			count_low += 1
		count_high += Trade.magic_stock(high, m).size()
	assert_false(rarities_low.has("rare") or rarities_low.has("very_rare") or rarities_low.has("legendary"), "nothing rare at level 1")
	assert_true(rarities_low.has("uncommon") and rarities_low.has("common"), "common and uncommon from the start")
	assert_true(count_high > count_low + 300, "a level 12 party sees the rare and greater stock (%d against %d)" % [count_high, count_low])


func test_the_wares_price_and_list_at_every_counter() -> void:
	var st := _party_of(12)
	st.set_flag("lyla_met", true)
	for m in _merchants():
		var wares := st.shop_wares(m)
		assert_true(wares.size() > 0, "%s has wares" % m)
		for w in wares:
			assert_true(float(w["price"]) > 0.0, "%s prices %s" % [m, w["id"]])


func test_the_smith_makes_magic_arms_to_order_and_the_apothecary_has_every_potion() -> void:
	var jean := Trade.magic_stock(_party_of(12), "jean_myriel")
	var flame := jean.filter(func(w: Dictionary) -> bool: return str(w["id"]) == "flame_tongue")
	assert_eq(flame.size(), 1, "the Flame Tongue is on the smith's counter")
	assert_true(flame.size() == 1 and (flame[0]["bases"] as Array).size() > 3, "made on the weapon the party picks")
	var morgan := (Compendium.shared().get_entry("npcs", "morgan")["shop"] as Dictionary)["magic"] as Array
	for p: String in ["potion_of_healing_greater", "lilypad_tonic", "haint_hooch", "potion_of_heroism"]:
		assert_true(p in morgan, "Morgan sells %s" % p)


func test_lyla_trades_only_once_the_party_has_met_her() -> void:
	var shop := Compendium.shared().get_entry("npcs", "lyla_webb")["shop"] as Dictionary
	assert_eq(str(shop.get("closed", "")), "not flag.lyla_met")
	assert_true(bool(shop.get("hide_closed", false)), "no Trade at all before")
	var st := StoryState.new()
	assert_true(StoryConditions.check(str(shop["closed"]), st), "closed before they meet")
	st.set_flag("lyla_met", true)
	assert_false(StoryConditions.check(str(shop["closed"]), st), "open after")


func test_the_story_keeps_its_own_things() -> void:
	var sold := _on_counters()
	for id: String in ["adelas_wedding_ring", "whistle_of_the_vagrant", "sword_of_the_crimson_abbot", "the_bag", "grave_salt"]:
		assert_false(sold.has(id), "%s is the story's, not a shop's" % id)
	for d in Compendium.shared().all("items"):
		if str(d.get("category", "")) == "quest":
			assert_false(sold.has(str(d["id"])), "quest item %s is not for sale" % d["id"])
