extends TestCase
## The journal's region order for this campaign (data/campaign.json `quest_regions`): the Other tab files quests under their region,
## in the order the story reaches them (the Ghostlight Express, Wickermoor, the Crooked House, then the later chapters), not
## alphabetically. The engine's QuestRegions reads the list once it has the hook (Build/Engine Request - Quest Region Order.md);
## until then these tests hold the game's side: the list is complete and in the right order, and every quest's region is on it.

func _config() -> Dictionary:
	return Campaign.setting("quest_regions", {}) as Dictionary


func _order() -> Array:
	return _config().get("order", []) as Array


func test_the_campaign_names_the_order_and_a_heading_for_each_region() -> void:
	var order := _order()
	assert_false(order.is_empty(), "data/campaign.json has quest_regions.order")
	var names := _config().get("names", {}) as Dictionary
	var seen := {}
	for r: Variant in order:
		assert_false(seen.has(r), "%s is listed once" % r)
		seen[r] = true
		assert_true(names.has(r) and str(names[r]) != "", "%s has a heading" % r)


func test_the_story_comes_in_the_order_it_is_played() -> void:
	var order := _order()
	var chain: Array[String] = ["ghostlight_express", "wickermoor", "crooked_house", "foxwillow", "crimson_monastery",
		"drowned_crossroads", "skitterdeep_mine", "memorys_rest", "hartsblight_forest", "maidenmist_cemetery"]
	var last := -1
	for r in chain:
		var at := order.find(r)
		assert_true(at > last, "%s comes after the region before it" % r)
		last = at
	assert_eq(order.back(), "companions", "the companions' own quests are last")


func test_every_quest_is_filed_under_a_region_on_the_list() -> void:
	var order := _order()
	for q: Dictionary in Compendium.shared().all("quests"):
		var region := str(q.get("region", ""))
		if region != "":
			assert_true(region in order, "quest %s is filed under %s, which is not in quest_regions.order" % [str(q.get("id", "")), region])


## The engine's side, once QuestRegions reads the campaign's list (the request names `QuestRegions.order()`): the three regions that
## exist today sort in play order, not alphabetically (crooked_house, ghostlight_express, wickermoor).
func test_the_journal_sorts_the_regions_in_play_order() -> void:
	if not QuestRegions.new().has_method("order"):
		return   # the engine has no hook yet: the request is written, nothing to check on this side
	assert_true(QuestRegions.before("ghostlight_express", "wickermoor"))
	assert_true(QuestRegions.before("wickermoor", "crooked_house"))
	assert_true(QuestRegions.before("crooked_house", "companions"))
	assert_true(QuestRegions.before("crooked_house", "foxwillow"))
	var regions: Array[String] = ["crooked_house", "wickermoor", "ghostlight_express"]
	regions.sort_custom(func(a: String, b: String) -> bool: return QuestRegions.before(a, b))
	assert_eq(regions, ["ghostlight_express", "wickermoor", "crooked_house"] as Array[String])
