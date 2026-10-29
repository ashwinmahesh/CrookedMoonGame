extends TestCase
## The campaign plug (the engine handbook, new_game.md section 2): data/campaign.json names this game's module and look, and
## the engine asks them. Both are empty subclasses for now (plan G1 and G8 fill them in), so every answer is the base class's.


func after_each() -> void:
	Campaign.use(null)
	CampaignLook.use(null)


func test_the_configured_module_is_the_crooked_moons() -> void:
	Campaign.use(null)
	assert_true(Campaign.module() is CrookedMoonCampaign, "data/campaign.json names story/crooked_moon_campaign.gd")


func test_the_configured_look_is_the_crooked_moons() -> void:
	CampaignLook.use(null)
	assert_true(CampaignLook.current() is CrookedMoonLook, "data/campaign.json names world/look/crooked_moon_look.gd")


func test_the_empty_module_answers_as_a_game_with_no_campaign_facts() -> void:
	var m := Campaign.module()
	assert_eq(m.fill("{x}", GameState.story), "{x}")
	assert_eq(m.final_room(GameState.story), "")
	assert_true(m.reading("any", GameState.story).is_empty())
	assert_eq(m.presence_attention(GameState.story), 0)
	assert_false(m.handles_spell("detect_magic"))
	assert_true(m.endings().is_empty())
	assert_eq(m.guard_monster(), "guard")


func test_the_empty_look_builds_and_claims_nothing() -> void:
	var l := CampaignLook.current()
	assert_false(l.plan(null))
	assert_false(l.walk_at(null, Vector2i.ZERO))
	assert_false(l.claims(null, Vector2i.ZERO))
	assert_true(l.place_special("anything", null, null, Vector2i.ZERO, {}, {}).is_empty(), "no special art: the catalog's own")


func test_the_campaign_file_names_the_bug_report_folder() -> void:
	var cfg := JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json")) as Dictionary
	var bug := cfg.get("bug_reports", {}) as Dictionary
	assert_eq(str(bug.get("env", "")), "CROOKED_MOON_BUG_REPORTS")
	assert_eq(str(bug.get("vault", "")), "Documents/Obsidian Vault/Crooked Moon")
