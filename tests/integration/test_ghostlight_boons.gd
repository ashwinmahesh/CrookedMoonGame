extends TestCase
## The Ghostlight Express's gifts to the heroes and the locomotive's retry (audit note section C, items 1 to 3):
## Bless for an hour from Adela's reading, 1d6 for every hero for each haint freed, and the immediate retry after a wipe at the
## Ghostlight Locomotive.

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
	Campaign.module().reading("hero_1", st)
	assert_false(_blessed(st.party[0]), "a finished reading blesses no one again")


# --- A haint freed ----------------------------------------------------------------------------------------------

func _quest(id: String, stage: String) -> void:
	st.set_quest_stage(id, "met")
	st.set_quest_stage(id, stage)


func test_a_freed_haint_heals_every_hero_and_the_overflow_is_temporary_hit_points() -> void:
	var told: Array[String] = []
	GhostlightBoons.watch(st, Dice.roller, func(t: String) -> void: told.append(t))
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
	assert_eq(told.size(), 1, "the player is told once")


func test_each_way_of_freeing_pays_once_and_bottling_or_destroying_pays_nothing() -> void:
	GhostlightBoons.watch(st, Dice.roller)
	var ilse := st.party[0]
	_quest("haint_sweetheart", "bottled")
	_quest("haint_harlequin", "destroyed")
	assert_eq(ilse.temp_hp, 0, "a bottled haint and a destroyed one heal no one")
	_quest("haint_songstress", "helped")
	var after_one := ilse.temp_hp
	assert_true(after_one >= 1, "talked round: healed")
	st.set_quest_stage("haint_songstress", "helped")
	assert_eq(ilse.temp_hp, after_one, "the same haint never pays twice")
	ilse.temp_hp = 0
	_quest("haint_jailbird", "token")
	assert_true(ilse.temp_hp >= 1, "a token pays too")


func test_the_freeing_dialogue_heals_through_the_real_quest_stage() -> void:
	GhostlightBoons.watch(st, Dice.roller)
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
