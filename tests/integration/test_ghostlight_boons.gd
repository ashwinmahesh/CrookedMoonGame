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
