extends TestCase
## The Ghostlight Express's gifts to the heroes and the locomotive's retry (audit note section C, items 1 to 3):
## Bless for an hour from Adela's reading, 1d6 for every hero for each haint freed, and the immediate retry after a wipe at the
## Ghostlight Locomotive. The engine tells the campaign module when each moment comes (CampaignModule.reading_finished, once the last
## card is turned, and quest_finished, which pays the haint's heal and adds what it says to the journal's notice), so nothing here
## connects a signal by hand.

const GAME := preload("res://world/game_root.gd")
const LOC := "ghostlight_wreckage"

var st: StoryState
var root: Node


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	st.playthrough_seed = 4242
	Dice.reseed(11)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		await get_tree().process_frame
	GameState.reset()


func _blessed(ch: Character) -> bool:
	return ch.effects.any(func(fx: Effect) -> bool: return fx.source_id == "bless")


# --- Bless from the reading -------------------------------------------------------------------------------------

## Plays Adela's reading through the real conversation, picking "deal the cards" and leaving the lounge's menu when it comes back.
func _read_the_cards() -> void:
	var r := DialogueRunner.new(st, Dice.roller)
	assert_true(r.start("ghostlight_express/adela_reading:offer"), "the reading starts")
	var b := r.next()
	for i in 400:
		if str(b["kind"]) == "end" or bool(st.get_flag("tarot_full_reading", false)):
			break
		if str(b["kind"]) == "options":
			var opts := b["options"] as Array
			var pick := 0
			for j in opts.size():
				if str((opts[j] as Dictionary)["text"]).contains("deal the cards"):
					pick = j
			b = r.choose(pick)
		else:
			b = r.next()
	assert_true(bool(st.get_flag("tarot_full_reading", false)), "the reading finishes")


func test_the_reading_blesses_every_hero_for_an_hour() -> void:
	for ch in st.party:
		assert_false(_blessed(ch), "%s is not blessed before the cards" % ch.name)
	_read_the_cards()
	for ch in st.party:
		assert_true(_blessed(ch), "%s is blessed after the reading" % ch.name)
		var fx := ch.effects.filter(func(e: Effect) -> bool: return e.source_id == "bless")[0] as Effect
		assert_eq(fx.minutes_left, 60, "an hour")
		assert_false(ch.modifiers_for(&"bonus_die").is_empty(), "the 1d4 on attacks and saves is there")


func test_bless_runs_out_after_an_hour_of_game_time_and_survives_a_fight_ending() -> void:
	_read_the_cards()
	var ilse := st.party[0]
	EncounterSetup.clear_fight_effects(ilse)
	assert_true(_blessed(ilse), "a fight ending does not take it")
	st.advance_minutes(59)
	assert_true(_blessed(ilse), "59 minutes in")
	st.advance_minutes(1)
	for ch in st.party:
		assert_false(_blessed(ch), "an hour later it is gone from %s" % ch.name)


func test_a_dead_hero_is_not_blessed_and_a_second_reading_blesses_no_one_again() -> void:
	st.party[1].dead = true
	_read_the_cards()
	assert_true(_blessed(st.party[0]))
	assert_false(_blessed(st.party[1]), "the dead take no part")
	st.advance_minutes(61)
	Campaign.module().reading_finished(st)
	assert_false(_blessed(st.party[0]), "a finished reading blesses no one again")


func test_the_blessing_starts_when_the_last_card_is_turned_not_at_the_first() -> void:
	Campaign.module().ensure_drawn(st)
	var slots: Array = st.tarokka.keys()
	for slot: Variant in slots:
		var card := Campaign.module().reading(str(slot), st)
		assert_false(card.is_empty(), "%s's card is turned" % slot)
	for ch in st.party:
		assert_false(_blessed(ch), "turning cards blesses no one: %s" % ch.name)
	Campaign.module().reading_finished(st)
	for ch in st.party:
		assert_true(_blessed(ch), "the finished reading blesses %s" % ch.name)


func test_in_the_real_conversation_only_the_last_card_starts_the_blessing() -> void:
	var r := DialogueRunner.new(st, Dice.roller)
	assert_true(r.start("ghostlight_express/adela_reading:offer"))
	var b := r.next()
	var cards := 0
	for i in 400:
		if str(b["kind"]) == "end" or bool(st.get_flag("tarot_full_reading", false)):
			break
		if str(b["kind"]) == "options":
			var opts := b["options"] as Array
			var pick := 0
			for j in opts.size():
				if str((opts[j] as Dictionary)["text"]).contains("deal the cards"):
					pick = j
			b = r.choose(pick)
		else:
			b = r.next()
		if b.has("card"):   # a card has just been turned (the beat that shows it)
			cards += 1
			for ch in st.party:
				assert_eq(_blessed(ch), cards == st.tarokka.size(), "%s after card %d of %d" % [ch.name, cards, st.tarokka.size()])
	assert_eq(cards, st.tarokka.size(), "every card was turned")


# --- A haint freed ----------------------------------------------------------------------------------------------

func _quest(id: String, stage: String) -> void:
	st.set_quest_stage(id, "met")
	st.set_quest_stage(id, stage)


func test_a_freed_haint_heals_every_hero_and_the_overflow_is_temporary_hit_points() -> void:
	var hurt := st.party[0]
	var full := st.party[1]
	var gone := st.party[2]
	hurt.hp = 1
	gone.dead = true
	gone.hp = 0
	_quest("haint_mariner", "token")
	assert_true(hurt.hp > 1, "the hurt hero mends")
	var amount := hurt.hp - 1 + hurt.temp_hp
	assert_true(amount >= 1 and amount <= 6, "one 1d6: %d" % amount)
	assert_eq(full.temp_hp, amount, "a hero at full health gets all of it as Temporary Hit Points")
	assert_eq(gone.hp, 0, "the dead are not healed")
	assert_eq(gone.temp_hp, 0)
	assert_true(st.quest_notice().contains("The freed haint heals each hero %d" % amount), "the journal's notice tells the player: %s" % st.quest_notice())
	assert_true(st.quest_notice().begins_with("Quest complete"), "after the quest's own notice: %s" % st.quest_notice())


func test_each_way_of_freeing_pays_once_and_bottling_or_destroying_pays_nothing() -> void:
	var ilse := st.party[0]
	_quest("haint_sweetheart", "bottled")
	_quest("haint_harlequin", "destroyed")
	assert_eq(ilse.temp_hp, 0, "a bottled haint and a destroyed one heal no one")
	assert_false(st.quest_notice().contains("heals"), "and say nothing of it")
	_quest("haint_songstress", "helped")
	var after_one := ilse.temp_hp
	assert_true(after_one >= 1, "talked round: healed")
	st.set_quest_stage("haint_songstress", "helped")
	assert_eq(ilse.temp_hp, after_one, "the same haint never pays twice")
	ilse.temp_hp = 0
	_quest("haint_jailbird", "token")
	assert_true(ilse.temp_hp >= 1, "a token pays too")


func test_the_freeing_dialogue_heals_through_the_real_quest_stage() -> void:
	st.party[0].hp = 1
	var r := DialogueRunner.new(st, Dice.roller)
	assert_true(r.start("ghostlight_express/haint_songstress:token_freed"))
	var b := r.next()
	for i in 80:
		if str(b["kind"]) == "end":
			break
		b = r.next()
	assert_eq(st.quest_stage("haint_songstress"), "token")
	assert_true(st.party[0].hp > 1 or st.party[0].temp_hp > 0, "the songstress's blessing reaches the party")
	assert_true(st.party[1].temp_hp > 0, "and a hero at full health keeps it as Temporary Hit Points")


# --- The locomotive's retry -------------------------------------------------------------------------------------

func test_a_wipe_at_the_locomotive_restores_the_party_and_starts_the_fight_again() -> void:
	for ch in st.party:
		ch.finish_long_rest()
	st.location = LOC
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 12:
		await get_tree().process_frame
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter("gl_locomotive"), "the fight starts")
	for i in 6:
		await get_tree().process_frame
	var cv := view.combat_view
	var first := cv.e
	for ch in st.party:
		ch.hp = 0
	st.party[2].dead = true
	first._check_over()
	assert_eq(first.outcome, "defeat", "the party is down")
	cv.finished.emit("defeat")
	for i in 12:
		await get_tree().process_frame
	assert_true(view.in_combat, "the fight begins again at once")
	assert_true(view.combat_view != cv and view.combat_view != null and view.combat_view.e != first, "a new fight")
	assert_eq(view.fight_id, GhostlightRetry.RETRY_FIGHT, "from the clearing's rim")
	for ch in st.party:
		assert_false(ch.dead, "%s is on their feet" % ch.name)
		assert_eq(ch.hp, ch.max_hp(), "%s has all their Hit Points" % ch.name)
	assert_eq(int(st.get_flag(GhostlightRetry.COUNT_FLAG, 0)), 1, "the retry is counted")
	assert_false(root.get("screen") is PauseMenu, "no game-over screen")


func test_any_other_wipe_is_still_a_game_over() -> void:
	assert_false(GhostlightRetry.applies({"id": "gl_stoker"}))
	assert_true(GhostlightRetry.applies({"id": "gl_locomotive"}))
	assert_true(GhostlightRetry.applies({"id": "gl_locomotive_edge"}))


func test_the_heal_is_rolled_from_the_playthrough_so_a_reload_rolls_the_same() -> void:
	_quest("haint_daydreamer", "token")
	var first := st.party[0].temp_hp
	assert_true(first >= 1 and first <= 6)
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	st.playthrough_seed = 4242
	Dice.reseed(99)   # the table's dice differ; the haint's roll does not read them
	_quest("haint_daydreamer", "token")
	assert_eq(st.party[0].temp_hp, first, "the same playthrough, the same roll")
