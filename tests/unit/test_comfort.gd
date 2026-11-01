extends TestCase
## Comfort settings and content notes (plan 13.6, G9; story/comfort.gd, data/comfort/comfort.json): five topics, softened
## unless the player turns them up, scenes that test `option:show_<topic>`, and a content note on each region's card.


func after_each() -> void:
	Comfort.clear_cache()
	Campaign.use(null)


func test_the_five_topics_start_softened() -> void:
	var st := StoryState.new()
	var ids: Array[String] = []
	for t: Dictionary in Comfort.topics():
		ids.append(str(t["id"]))
		assert_true(Comfort.softened(st, str(t["id"])), "%s is softened by default" % t["id"])
		assert_true(str(t.get("tip", "")) != "", "%s says how it's softened" % t["id"])
	assert_eq(ids, ["burning", "surgery", "insects", "children", "hanging"] as Array[String])


func test_turning_a_topic_up_shows_it_and_scenes_can_ask() -> void:
	var st := StoryState.new()
	assert_false(StoryConditions.check("option:show_burning", st), "a full take's condition fails while softened")
	Comfort.set_shown(st, "burning", true)
	assert_false(Comfort.softened(st, "burning"))
	assert_true(StoryConditions.check("option:show_burning", st))
	assert_true(Comfort.softened(st, "insects"), "the others stay as they were")


func test_the_settings_rows_are_playthrough_options() -> void:
	Campaign.use(null)
	var rows := (Campaign.module() as CrookedMoonCampaign).comfort_options()
	assert_eq(rows.size(), 5)
	for r: Dictionary in rows:
		assert_true(str(r["key"]).begins_with("show_"))
		assert_false(bool(r["default"]), "comfort on by default")


func test_every_note_names_a_real_region_and_real_topics() -> void:
	var regions := {}
	for loc: Dictionary in Compendium.shared().all("locations"):
		regions[str(loc.get("region", ""))] = true
	for region: String in (Comfort.data()["notes"] as Dictionary):
		assert_true(regions.has(region), "%s is a region" % region)
		for id: String in Comfort.region_topics(region):
			assert_false(Comfort.topic(id).is_empty(), "%s: %s is a topic" % [region, id])


func test_the_card_line_says_what_is_softened() -> void:
	var st := StoryState.new()
	var line := Comfort.note("skitterdeep_mine", st)
	assert_true(line.begins_with("Content: insects and crawling things (softened)."), line)
	Comfort.set_shown(st, "insects", true)
	assert_false(Comfort.note("skitterdeep_mine", st).contains("softened"))
	assert_eq(Comfort.note("test_grounds", st), "", "no notes, no line")
