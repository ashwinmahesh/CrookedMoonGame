extends TestCase
## R10's Fated Tarot (plan G1): Adela deals one of 22 cards to each hero at the table from the playthrough's seed, none twice, the same
## on a reload, the card's id is a flag conversations read, and every card has a verse and a hint.

var st: StoryState


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	st.playthrough_seed = 4242


func after_each() -> void:
	GameState.reset()


func test_the_deck_holds_twenty_two_cards_each_with_a_verse_and_a_hint() -> void:
	assert_eq(ReadingDeck.cards().size(), 22)
	var module := Campaign.module() as CrookedMoonCampaign
	for c: Dictionary in ReadingDeck.cards():
		st.tarokka = {"hero_1": str(c["id"])}
		var r := module.reading("hero_1", st)
		assert_true(str(r["verse"]).length() > 40, "%s has a verse" % c["id"])
		assert_true(module.field(st, "hero_1.hint").length() > 20, "%s has a hint" % c["id"])


func test_every_hero_gets_a_card_and_none_repeat() -> void:
	var module := Campaign.module()
	module.ensure_drawn(st)
	assert_eq(st.tarokka.size(), 4)
	var seen := {}
	for slot: String in ["hero_1", "hero_2", "hero_3", "hero_4"]:
		var card := str(st.tarokka[slot])
		assert_true(not seen.has(card), "no card is dealt twice")
		seen[card] = true
		assert_eq(str(st.get_flag("tarot_" + slot, "")), card, "the card is a flag the conversations read")


func test_the_same_seed_deals_the_same_cards_and_a_second_draw_changes_nothing() -> void:
	var module := Campaign.module()
	module.ensure_drawn(st)
	var first := st.tarokka.duplicate()
	module.ensure_drawn(st)
	assert_eq(st.tarokka, first, "the reading is drawn once")
	GameState.reset()
	st = GameState.story
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		st.party.append(ch)
	st.playthrough_seed = 4242
	module.ensure_drawn(st)
	assert_eq(st.tarokka, first, "the same seed deals the same cards")


func test_a_reading_names_the_hero_and_the_card() -> void:
	var module := Campaign.module()
	module.ensure_drawn(st)
	var r := module.reading("hero_2", st)
	assert_true(str(r["title"]).begins_with(str(r["slot_name"])), "the title leads with the hero's first name")
	assert_true(Campaign.module().reading("hero_9", st).is_empty(), "a slot nobody sits at holds nothing")
