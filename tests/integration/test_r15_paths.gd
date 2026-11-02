extends TestCase
## R15, The Drowned Crossroads: Adela's hook, the three swamp nights, Murkwater Bend, the Bayou King's fort and Liar's Dice, the Marshwinder shack and
## its wares, the lagoon, the riverboat and the boiler, the Sinner's table and the boss, the farewell, Adela's cure, and the five side quests, each played
## through the DialogueRunner with dice that always roll high, the way test_r10_playthrough plays the
## Express: a person is only talked to while their entry's `when` holds and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")
const TOWN := "dc_murkwater"

## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll 1: every check in a conversation misses.
class LowDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(1)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var st: StoryState
var dice: DiceRoller = HighDice.new()
var fights: Array[String] = []


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", st.location)


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


func _entry(list_key: String, id_key: String, id: String) -> Dictionary:
	for e: Variant in _loc().get(list_key, []):
		if str((e as Dictionary).get(id_key, "")) == id:
			return e as Dictionary
	return {}


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once
## they run out, which is "leave" or "that's all" in every menu here). Returns what the conversation ended in.
func _play(ref: String, picks: Array[String] = []) -> Dictionary:
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	for i in 600:
		match str(b["kind"]):
			"end":
				break
			"options":
				var opts := b["options"] as Array
				var pick := opts.size() - 1
				if not left.is_empty():
					var want := str(left.pop_front())
					pick = -1
					for j in opts.size():
						if bool((opts[j] as Dictionary)["enabled"]) and str((opts[j] as Dictionary)["text"]).contains(want):
							pick = j
							break
					if pick < 0:
						fail("%s: no option '%s' among %s" % [ref, want, opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))])
						return {}
				b = r.choose(pick)
			"guidance":
				b = r.answer_guidance(-1)
			"pick_member":
				b = r.pick_member(0)
			_:
				b = r.next()
	assert_eq(str(b["kind"]), "end", "%s ends" % ref)
	assert_true(left.is_empty(), "%s: picks left over %s" % [ref, left])
	var combat := str(b.get("combat", ""))
	if combat != "":
		_win(combat)
	var move := b.get("move", {}) as Dictionary
	if not move.is_empty():
		_arrive(str(move["location"]))
	return b


## The encounter `id` of this place won, as LocationFights._end_encounter records a victory (spec_for's pick).
func _win(id: String) -> void:
	var spec := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == id and (spec.is_empty() or not _holds(StoryConditions.encounter_when(spec))):
			spec = e as Dictionary
	assert_true(not spec.is_empty(), "%s has the fight %s" % [st.location, id])
	if spec.is_empty():
		return
	fights.append(id)
	(st.loc_state(st.location)["encounters"] as Dictionary)[id] = true
	if spec.has("flag"):
		st.set_flag(str(spec["flag"]))
	if spec.has("quest"):
		st.set_quest_stage(str((spec["quest"] as Dictionary)["id"]), str((spec["quest"] as Dictionary)["stage"]))


func _arrive(id: String) -> void:
	st.location = id
	assert_true(not _loc().is_empty(), "%s is a place" % id)


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	dice = HighDice.new()
	st.location = TOWN
	st.gold = 100.0


func after_each() -> void:
	GameState.reset()




const DC := "drowned_crossroads/"


func _flag(id: String) -> bool:
	return bool(st.get_flag(id))


func _sink(id: String, v: Variant) -> void:
	st.set_flag(id, v)


# ---- the hook and the village --------------------------------------------------------------------------------------------------------------

func test_adela_hook_with_secrecy() -> void:
	st.location = "wickermoor_village"
	_play(DC + "hook:adela_start", ["go down", "keep your counsel"])
	assert_true(_flag("crossroads_asked"))
	assert_true(_flag("adela_secret_kept"))
	assert_eq(st.quest_stage("withered_arm"), "asked")


func test_adela_hook_without_the_promise_and_the_polite_no() -> void:
	st.location = "wickermoor_village"
	_play(DC + "hook:adela_start", ["Not right now"])
	assert_true(not _flag("crossroads_asked"))
	_play(DC + "hook:adela_start", ["go down", "no promises"])
	assert_true(_flag("crossroads_asked"))
	assert_true(not _flag("adela_secret_kept"))


func test_adela_hex_scene_follows_a_first_chapter() -> void:
	st.location = "wickermoor_village"
	_sink("crossroads_asked", true)
	_sink("act2_done", 1)
	_play(DC + "hook:adela_hex", ["Ask how long"])
	assert_true(_flag("adela_hex_seen"))
	var found := false
	for e: Variant in _loc().get("npcs", []):
		if str((e as Dictionary)["npc"]) == "adela_druskenvald" and str((e as Dictionary).get("dialogue", "")).ends_with("hook:adela_hex"):
			found = true
			assert_true(_holds((e as Dictionary)["when"]) or _flag("adela_hex_seen"))
	assert_true(found, "Adela has the hex entry in Wickermoor")


func test_the_village_hook_is_gated_on_vessla() -> void:
	st.location = "wickermoor_village"
	var gates := {}
	for e: Variant in _loc().get("npcs", []):
		if str((e as Dictionary).get("dialogue", "")).ends_with("hook:adela_start"):
			gates = e as Dictionary
	assert_true(not gates.is_empty())
	assert_true(not _holds(gates["when"]))
	_sink("vessla_slain", true)
	assert_true(_holds(gates["when"]))


# ---- the trek --------------------------------------------------------------------------------------------------------------------------------

func test_night_one_touch_the_hand_then_the_bayou_beast() -> void:
	_arrive("dc_trail1")
	_play(DC + "trek:hand_comes", ["Touch the hand"])
	assert_true(_flag("withered_hand_taken"))
	assert_eq(fights, ["dc_beast_camp"] as Array[String])
	assert_eq(st.quest_stage("withered_arm"), "trek")
	_play(DC + "trek:beast_remains", ["Study the mask"])
	assert_true(_flag("dc_beast_lore"))


func test_night_one_leaving_the_hand_and_the_slow_way_to_the_mask() -> void:
	_arrive("dc_trail1")
	_play(DC + "trek:hand_comes", ["Leave it where"])
	assert_true(not _flag("withered_hand_taken"))
	assert_eq(fights, ["dc_beast_camp"] as Array[String])
	dice = LowDice.new()
	_play(DC + "trek:beast_remains", ["Study the mask"])
	assert_true(_flag("dc_beast_lore"), "a missed Arcana still gets the lore the slow way")


func test_the_crossing_seen_or_ambushed() -> void:
	_arrive("dc_trail2")
	_play(DC + "trek:crossing", ["Watch the water"])
	assert_true(not _flag("dc_croc_ambush"))
	assert_eq(fights, ["dc_croc_crossing"] as Array[String])
	_play(DC + "trek:croc_arcana", ["Read the glyphs"])
	assert_true(_flag("dc_croc_lore"))
	GameState.reset()
	before_each()
	_arrive("dc_trail2")
	_play(DC + "trek:crossing", ["Cross at once"])
	assert_true(_flag("dc_croc_ambush"))
	var spec := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == "dc_croc_crossing" and _holds((e as Dictionary)["when"]):
			spec = e as Dictionary
	assert_eq(str(spec.get("surprise", "")), "party", "missing the crocodiles means surprise")


func test_the_fog_ghouls_and_the_banner_clue() -> void:
	_arrive("dc_trail3")
	_play(DC + "trek:battlefield", ["Read the mud"])
	assert_eq(fights, ["dc_ghoul_ambush"] as Array[String])
	_play(DC + "trek:battlefield_clue", ["Look at the dead"])
	assert_true(_flag("dc_clue_banner"))


# ---- Murkwater, the fort, Liar's Dice ---------------------------------------------------------------------------------------------------------

func test_lyla_meets_the_party_and_takes_them_to_the_king() -> void:
	_play(DC + "town:reveal")
	assert_true(_flag("dc_town_seen"))
	_play(DC + "town:lyla_gate", ["Mister Crossroads", "Say nothing", "Take us to the King"])
	assert_true(_flag("lyla_met"))
	assert_eq(st.quest_stage("withered_arm"), "murkwater")
	assert_eq(st.location, "dc_fort")


func test_lyla_admits_her_patron_to_a_reader_of_charms_and_not_otherwise() -> void:
	_sink("lyla_met", true)
	_play(DC + "town:lyla_talk", ["Study the charms"])
	assert_true(_flag("lyla_jack_known"))
	GameState.reset()
	before_each()
	dice = LowDice.new()
	_play(DC + "town:lyla_talk", ["Study the charms"])
	assert_true(not _flag("lyla_jack_known"))


func _dice_rounds(start_ref: String, opening: Array[String], tricks: Array[String]) -> void:
	var picks := opening.duplicate()
	picks.append_array(tricks)
	_play(start_ref, picks)


func test_dice_with_the_king_won_by_the_truth_and_the_secrecy_money() -> void:
	_arrive("dc_fort")
	_sink("adela_secret_kept", true)
	_dice_rounds(DC + "vander:dice_start", ["Play properly"] as Array[String], ["Hard read", "Watch the charm", "Measure the pause"] as Array[String])
	assert_eq(str(st.get_flag("vander_dice")), "won")
	# the stakes come after the win: rerun the stakes node itself
	_play(DC + "vander:dice_win", ["Tell him the truth"])
	assert_eq(int(st.get_flag("vander_pay", 0)), 200)


func test_dice_with_the_king_won_by_a_good_lie() -> void:
	_arrive("dc_fort")
	_play(DC + "vander:dice_win", ["Tell him 300"])
	assert_eq(int(st.get_flag("vander_pay", 0)), 300)
	assert_eq(str(st.get_flag("vander_dice")), "won")


func test_dice_with_the_king_lost_is_a_way_on_and_costs_only_pay() -> void:
	_arrive("dc_fort")
	dice = LowDice.new()
	_dice_rounds(DC + "vander:dice_start", ["Play properly"] as Array[String], ["Bid cautiously", "Keep your bid low", "Play the safe"] as Array[String])
	assert_eq(str(st.get_flag("vander_dice")), "lost")
	assert_eq(int(st.get_flag("vander_pay", 0)), 0)


func test_the_quick_roll_is_a_second_way_through_the_game() -> void:
	_arrive("dc_fort")
	_play(DC + "vander:dice_start", ["Let fate decide", "Pull the lucky cup", "Tell him the truth"])
	assert_eq(str(st.get_flag("vander_dice")), "won")


func test_the_king_dinner_the_rest_and_the_night_the_dead_come() -> void:
	_arrive("dc_fort")
	_play(DC + "vander:throne", ["Accept dinner"])
	assert_true(_flag("vander_met"))
	assert_true(_flag("vander_dinner"))
	_play(DC + "vander:dinner_rest", ["Run north"])
	assert_true(_flag("dc_fort_rested"))
	assert_true(_flag("screams_done"))
	assert_true(_flag("screams_fled"))
	assert_eq(st.quest_stage("withered_arm"), "the_shack")
	assert_eq(st.location, "dc_murkwater")


func test_staying_to_fight_beside_lyla_is_an_option_not_a_trap() -> void:
	_arrive("dc_fort")
	_sink("vander_met", true)
	_play(DC + "vander:screams", ["Stay and fight"])
	assert_eq(fights, ["dc_screams"] as Array[String])
	assert_eq(st.quest_stage("withered_arm"), "the_shack")
	assert_true(_flag("screams_done"))
	_play(DC + "vander:fort_after")


# ---- the shack and the wares -----------------------------------------------------------------------------------------------------------------

func test_taking_a_bargain_and_a_potion_buys_passage() -> void:
	_arrive("dc_shack_approach")
	_play(DC + "shack:arrive")
	assert_true(_flag("shack_met"))
	_play(DC + "shack:parley", ["wares", "bargain", "Bestial Awakening", "potion", "Lilypad", "That is all of us"])
	assert_eq(int(st.get_flag("sinner_deals", 0)), 2)
	assert_true(_flag("deal_bestial_awakening"))
	assert_true(_flag("ware_lilypad_tonic"))
	assert_true(_flag("deal_taken_blind"), "the small print was not read first")
	assert_true(_flag("crossroads_passage"))
	assert_true(_flag("sinner_gone"))
	assert_true(st.party[0].dark_gifts().has("bestial_awakening") or st.party.any(func(c: Variant) -> bool: return (c as Character).dark_gifts().has("bestial_awakening")))


func test_with_the_small_print_read_nothing_is_taken_blind() -> void:
	_arrive("dc_shack_approach")
	_sink("small_print_read", true)
	_play(DC + "shack:parley", ["wares", "curio", "The Bag", "That is all of us"])
	assert_true(not _flag("deal_taken_blind"))
	assert_true(_flag("ware_the_bag"))


func test_refusing_the_wares_brings_the_stalkers_and_one_idol_can_be_stolen() -> void:
	_arrive("dc_shack_approach")
	_play(DC + "shack:parley", ["Refuse any deal"])
	assert_eq(fights, ["dc_shack_stalkers"] as Array[String])
	assert_true(_flag("crossroads_refused"))
	assert_true(not _flag("crossroads_passage"))
	_play(DC + "shack:steal_one", ["Take one tagged idol"])
	assert_true(_flag("crossroads_passage"))


func test_straying_off_the_bottle_path_wakes_the_beast_in_the_bay() -> void:
	_arrive("dc_shack_approach")
	var found := false
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == "dc_beast_bay":
			found = true
			assert_eq(str((e as Dictionary)["trigger"]), "enter_area:dc_beast_bay")
	assert_true(found)


# ---- the lagoon and the boat ----------------------------------------------------------------------------------------------------------------

func test_without_a_token_the_lagoon_is_a_wreck_and_the_gangplank_is_shut() -> void:
	_arrive("dc_lagoon")
	_play(DC + "lagoon:view")
	assert_true(_flag("lagoon_seen"))
	_play(DC + "lagoon:wreck", ["Read the faded letters"])
	var gangplank := _entry("exits", "id", "gangplank")
	assert_true(not _holds(gangplank["when"]))


func test_with_a_token_the_ferryman_takes_the_party_aboard() -> void:
	_arrive("dc_lagoon")
	_sink("crossroads_passage", true)
	_play(DC + "lagoon:dock", ["Board"])
	assert_true(_flag("dc_boarded"))
	assert_eq(st.quest_stage("withered_arm"), "aboard")
	assert_eq(st.location, "dc_boat_promenade")


func test_bellhops_let_guests_in_three_ways_and_fight_the_rest() -> void:
	_arrive("dc_boat_promenade")
	_sink("crossroads_refused", true)
	_play(DC + "lagoon:bellhops", ["We are expected"])
	assert_true(_flag("dc_bellhops_ok"))
	GameState.reset()
	before_each()
	_arrive("dc_boat_promenade")
	_sink("crossroads_refused", true)
	_play(DC + "lagoon:bellhops", ["Tip them"])
	assert_true(_flag("dc_bellhops_ok"))
	assert_eq(st.gold, 75.0)
	GameState.reset()
	before_each()
	_arrive("dc_boat_promenade")
	_sink("crossroads_refused", true)
	_play(DC + "lagoon:bellhops", ["Fight the bellhops"])
	assert_eq(fights, ["dc_bellhops"] as Array[String])


func test_the_ferryman_vouches_once_paid() -> void:
	_arrive("dc_boat_promenade")
	_sink("crossroads_refused", true)
	_sink("ferryman_paid", true)
	_play(DC + "lagoon:bellhops", ["Ferryman vouched"])
	assert_true(_flag("dc_bellhops_ok"))


func test_elias_leads_with_the_hand_and_without_it() -> void:
	_arrive("dc_boat_promenade")
	_sink("withered_hand_taken", true)
	_play(DC + "boat:elias_mute", ["Show him the withered hand"])
	assert_true(_flag("elias_met"))
	assert_true(_flag("dc_boiler_lead"))
	assert_eq(st.quest_stage("withered_arm"), "elias")
	assert_eq(st.location, "dc_boat_promenade")
	GameState.reset()
	before_each()
	_arrive("dc_boat_promenade")
	_play(DC + "boat:elias_mute", ["Follow him down"])
	assert_true(_flag("dc_boiler_lead"), "Elias leads even when the hand was left behind")


func test_the_boiler_room_fight_and_the_freeing_of_elias() -> void:
	_arrive("dc_boat_promenade")
	_play(DC + "boat:engineer", ["Draw weapons"])
	assert_eq(fights, ["dc_boiler_fight"] as Array[String])
	assert_true(_flag("dc_boiler_done"))
	_play(DC + "boat:boiler_open", ["Let him rest"])
	assert_true(_flag("elias_freed"))
	assert_true(_flag("dc_ring_taken"))
	assert_true(_flag("dc_hall_help"))


func test_the_engineer_can_be_talked_down_with_the_xp_for_the_fight() -> void:
	_arrive("dc_boat_promenade")
	_play(DC + "boat:engineer", ["Ask her to stand down"])
	assert_true(_flag("dc_boiler_done"))
	assert_eq(fights.size(), 0)


func test_the_coin_keeper_gives_a_key_or_a_fight() -> void:
	_arrive("dc_boat_promenade")
	_play(DC + "boat:keeper", ["Tell him to open it"])
	var key_there := false
	for ch in st.party:
		for it: Variant in (ch as Character).inventory:
			if str((it as Dictionary).get("id", "")) == "coin_keepers_key":
				key_there = true
	assert_true(key_there, "the Coin Keeper hands the key over")
	GameState.reset()
	before_each()
	_arrive("dc_boat_promenade")
	_play(DC + "boat:keeper", ["Fight"])
	assert_eq(fights, ["dc_vault_fight"] as Array[String])


func test_the_casino_tables_pay_and_may_charm_and_elias_breaks_it() -> void:
	_arrive("dc_boat_promenade")
	_play(DC + "boat:wager", ["Ante five gold", "Play the hand"])
	assert_eq(st.gold, 105.0)
	dice = LowDice.new()
	_play(DC + "boat:wager", ["Ante ten gold", "Play the hand"])
	assert_eq(st.gold, 95.0)
	assert_eq(int(st.get_flag("high_roller_cursed", 0)), 1)
	assert_true(_flag("dc_hall_help"))
	_play(DC + "boat:curse_lift")
	assert_eq(int(st.get_flag("high_roller_cursed", 0)), 0)


func test_the_hall_brawl_and_the_galley() -> void:
	_arrive("dc_boat_promenade")
	_play(DC + "boat:gambler", ["Overturn the table"])
	assert_eq(fights, ["dc_hall_brawl"] as Array[String])
	_arrive("dc_boat_promenade")
	_play(DC + "boat:galley", ["Eat and drink", "Another round"])
	assert_eq(st.gold, 95.0)


func test_the_mirrored_window_and_the_hexed_deck() -> void:
	_arrive("dc_boat_promenade")
	_play(DC + "boat:window")
	assert_true(_flag("dc_window_seen"))
	_play(DC + "boat:hexed_deck", ["Let your shadow cheat"])
	assert_eq(st.gold, 150.0)


# ---- the Sinner ------------------------------------------------------------------------------------------------------------------------------

func test_the_sinners_table_won_gives_jacks_boon_and_leads_to_the_boss() -> void:
	_arrive("dc_boat_promenade")
	_play(DC + "sinner:invite", ["Take the table", "Hard read", "Hard read", "Hard read"])
	assert_eq(str(st.get_flag("sinner_dice")), "won")
	assert_true(bool(int(st.get_flag("jack_boon", 0))))
	assert_eq(st.quest_stage("withered_arm"), "bayou_boogie")
	assert_eq(st.location, "dc_casino")


func test_the_sinners_table_lost_still_ends_in_the_same_fight() -> void:
	_arrive("dc_boat_promenade")
	dice = LowDice.new()
	_play(DC + "sinner:invite", ["Take the table", "Bid cautiously", "Bid cautiously", "Bid cautiously"])
	assert_eq(str(st.get_flag("sinner_dice")), "lost")
	assert_true(not bool(int(st.get_flag("jack_boon", 0))))
	assert_eq(st.location, "dc_casino")


func test_not_yet_leaves_the_challenge_standing_and_attacking_skips_the_dice() -> void:
	_arrive("dc_boat_promenade")
	_play(DC + "sinner:invite", ["Not yet"])
	assert_true(_flag("sinner_roll_started"))
	assert_eq(st.quest_stage("withered_arm"), "roll_the_bones")
	_play(DC + "sinner:invite_again", ["Draw steel"])
	assert_eq(st.location, "dc_casino")


func test_the_boss_has_three_level_variants_that_partition_the_levels() -> void:
	_arrive("dc_casino")
	var whens: Array[String] = []
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == "dc_sinner":
			whens.append(str((e as Dictionary)["when"]))
	assert_eq(whens.size(), 3)
	for lvl: int in [3, 5, 6, 7, 8]:
		var holds := 0
		for e: Variant in _loc().get("encounters", []):
			if str((e as Dictionary)["id"]) == "dc_sinner":
				var w := str((e as Dictionary)["when"])
				if (w == "level <= 5" and lvl <= 5) or (w == "level == 6" and lvl == 6) or (w == "level >= 7" and lvl >= 7):
					holds += 1
		assert_eq(holds, 1, "level %d meets one boss variant" % lvl)


func test_the_boss_falls_the_farewell_pays_the_chapter_and_adela_is_healed() -> void:
	_arrive("dc_casino")
	_sink("adela_secret_kept", true)
	_play(DC + "boat:boiler_open", ["Let him rest"])
	assert_true(_flag("elias_freed"))
	_win("dc_sinner")
	assert_true(_flag("dc_sinner_done"))
	_play(DC + "sinner:after")
	assert_true(_flag("grinning_sinner_slain"))
	assert_eq(int(st.get_flag("act2_done", 0)), 1)
	assert_eq(st.quest_stage("withered_arm"), "return")
	assert_true(_flag("crossroads_done"))
	st.location = "wickermoor_village"
	var before := st.gold
	_play(DC + "village_after:adela_cure", ["Return her wedding ring", "Take our leave"])
	assert_true(_flag("adela_cured"))
	assert_eq(st.quest_stage("withered_arm"), "done")
	assert_true(st.gold > before)


func test_the_ring_can_be_kept_and_is_worth_a_thousand() -> void:
	st.location = "wickermoor_village"
	_sink("grinning_sinner_slain", true)
	_play(DC + "boat:boiler_open", ["Let him rest"])
	_play(DC + "village_after:adela_cure", ["Take our leave"])
	_play(DC + "village_after:adela_ring_menu", ["Keep her ring", "Take our leave"])
	assert_eq(str(st.get_flag("adela_ring")), "kept")
	assert_eq(int(Compendium.shared().get_entry("items", "adelas_wedding_ring")["cost_gp"]), 1000)


func test_vander_pays_what_the_dice_decided() -> void:
	_sink("grinning_sinner_slain", true)
	_sink("vander_dice", "won")
	_sink("vander_pay", 300)
	var before := st.gold
	_play(DC + "vander:vander_after")
	assert_true(_flag("vander_settled"))
	assert_true(st.gold >= before + 300.0)


func test_vander_lost_at_dice_owes_nothing() -> void:
	_sink("grinning_sinner_slain", true)
	_sink("vander_dice", "lost")
	var before := st.gold
	_play(DC + "vander:vander_after")
	assert_eq(st.gold, before)


# ---- side quests -----------------------------------------------------------------------------------------------------------------------------

func test_a_hand_with_the_king_three_ways_to_use_the_proof() -> void:
	_play(DC + "side_king:lou_start", ["We will watch the table"])
	assert_eq(st.quest_stage("a_hand_with_the_king"), "asked")
	_arrive("dc_fort")
	_sink("vander_dice", "won")
	_play(DC + "side_king:table_watch", ["Watch the way they hold"])
	assert_true(_flag("king_proof"))
	assert_eq(st.quest_stage("a_hand_with_the_king"), "proof")
	_play(DC + "side_king:lou_proof", ["Tell Vander quietly"])
	assert_eq(st.quest_stage("a_hand_with_the_king"), "done")
	assert_eq(str(st.get_flag("king_outcome")), "rematch")


func test_a_hand_with_the_king_proof_can_also_be_bought_from_tibby_and_kept_for_gold() -> void:
	_sink("king_asked", true)
	st.set_quest_stage("a_hand_with_the_king", "asked")
	_play(DC + "side_king:tibby_tells", ["Pay a coin"])
	assert_true(_flag("king_proof"))
	var before := st.gold
	_play(DC + "side_king:lou_proof", ["Keep it"])
	assert_eq(str(st.get_flag("king_outcome")), "kept")
	assert_true(st.gold >= before + 50.0)


func test_a_hand_with_the_king_fails_for_a_rash_accusation_without_proof() -> void:
	_sink("king_asked", true)
	st.set_quest_stage("a_hand_with_the_king", "asked")
	_play(DC + "side_king:lou_progress", ["Accuse Vander publicly"])
	assert_eq(st.quest_stage("a_hand_with_the_king"), "lost")


func test_a_failed_search_at_the_table_is_not_a_dead_end() -> void:
	_sink("king_asked", true)
	_sink("vander_dice", "won")
	dice = LowDice.new()
	_play(DC + "side_king:table_watch", ["Watch the way they hold", "Leave"])
	assert_true(not _flag("king_proof"))
	_play(DC + "side_king:tibby_tells", ["Pay a coin"])
	assert_true(_flag("king_proof"))


func test_lylas_ledger_right_accusation() -> void:
	_sink("vander_met", true)
	_play(DC + "side_ledger:lyla_start")
	assert_eq(st.quest_stage("lylas_ledger"), "asked")
	_play(DC + "side_ledger:tally_board", ["Read the columns"])
	_play(DC + "side_ledger:maude")
	_play(DC + "side_ledger:bo_tally")
	_play(DC + "side_ledger:report", ["Name Odell"])
	assert_eq(st.quest_stage("lylas_ledger"), "done")
	assert_eq(str(st.get_flag("ledger_outcome")), "right")


func test_lylas_ledger_wrong_accusation_needs_a_second_yes_and_closes_the_pits() -> void:
	_sink("ledger_boathouse", true)
	_sink("ledger_pits", true)
	_sink("ledger_traders", true)
	st.set_quest_stage("lylas_ledger", "asked")
	_play(DC + "side_ledger:report", ["Name Maude", "Look again", "Name Odell"])
	assert_eq(st.quest_stage("lylas_ledger"), "done")
	GameState.reset()
	before_each()
	_sink("ledger_boathouse", true)
	_sink("ledger_pits", true)
	_sink("ledger_traders", true)
	st.set_quest_stage("lylas_ledger", "asked")
	_play(DC + "side_ledger:report", ["Name Maude", "it was Maude"])
	assert_eq(st.quest_stage("lylas_ledger"), "lost")
	assert_true(_flag("pits_closed"))


func test_the_ledger_cannot_be_decided_on_a_guess_and_odells_boots_have_a_plain_route() -> void:
	st.set_quest_stage("lylas_ledger", "asked")
	_play(DC + "side_ledger:report", ["Ask what is left"])
	assert_eq(st.quest_stage("lylas_ledger"), "asked")
	dice = LowDice.new()
	_play(DC + "side_ledger:odell", ["Ask about the boots plainly"])
	_play(DC + "side_ledger:tally_board", ["Read them slowly"])
	assert_true(_flag("ledger_boathouse"))


func test_the_ferrymans_coins_paid_with_four_coppers() -> void:
	_play(DC + "side_coins:ferryman_start", ["gather the four"])
	assert_eq(st.quest_stage("the_ferrymans_coins"), "asked")
	_play(DC + "side_coins:pit_coin", ["Palm a copper"])
	_play(DC + "side_coins:odell_coin", ["Ask politely"])
	_play(DC + "side_coins:bo_coin", ["Ask for a copper"])
	_play(DC + "side_coins:thibault_coin")
	assert_eq(int(st.get_flag("ferry_coins", 0)), 4)
	_play(DC + "side_coins:ferryman_progress", ["Give him the four"])
	assert_eq(st.quest_stage("the_ferrymans_coins"), "paid")
	assert_true(_flag("ferryman_paid"))


func test_the_ferrymans_coins_gold_insults_him_and_each_coin_has_a_second_way() -> void:
	dice = LowDice.new()
	_play(DC + "side_coins:pit_coin", ["Leave a silver"])
	_play(DC + "side_coins:odell_coin", ["Pay a gold piece"])
	_play(DC + "side_coins:bo_coin", ["Buy a smoked eel"])
	assert_eq(int(st.get_flag("ferry_coins", 0)), 3)
	st.set_quest_stage("the_ferrymans_coins", "asked")
	_play(DC + "side_coins:ferryman_start", ["Offer him a gold piece"])
	assert_eq(st.quest_stage("the_ferrymans_coins"), "lost")


func test_the_small_print_posted_for_the_town() -> void:
	_play(DC + "side_print:cora_start", ["gather the tales"])
	assert_eq(st.quest_stage("the_sinners_small_print"), "asked")
	_play(DC + "side_print:lou_tale")
	_play(DC + "side_print:odell_tale")
	assert_true(not _flag("small_print_read"))
	_play(DC + "side_print:mama_tale")
	assert_true(_flag("small_print_read"))
	assert_eq(st.quest_stage("the_sinners_small_print"), "read")
	_play(DC + "side_print:cora_progress", ["Give her the three tales"])
	assert_eq(st.quest_stage("the_sinners_small_print"), "done")
	assert_eq(str(st.get_flag("print_outcome")), "posted")


func test_the_small_print_kept_and_the_blind_buyer_loses_cora() -> void:
	_sink("small_print_read", true)
	st.set_quest_stage("the_sinners_small_print", "read")
	_play(DC + "side_print:cora_progress", ["Keep the tales"])
	assert_eq(str(st.get_flag("print_outcome")), "kept")
	GameState.reset()
	before_each()
	_sink("deal_taken_blind", true)
	st.set_quest_stage("the_sinners_small_print", "asked")
	_play(DC + "side_print:cora_progress", ["we took a bargain"])
	assert_eq(st.quest_stage("the_sinners_small_print"), "lost")


func test_the_wedding_in_full_and_with_gaps() -> void:
	_play(DC + "side_wedding:thibault_start", ["We will help"])
	assert_eq(st.quest_stage("a_wedding_at_the_mud_church"), "asked")
	_play(DC + "side_wedding:lou_ring", ["Talk him into"])
	_play(DC + "side_wedding:music", ["Pay Tibby"])
	_play(DC + "folk:mama_gumbo")
	_play(DC + "side_wedding:supper", ["Ask her to cook"])
	assert_eq(int(st.get_flag("wedding_score", 0)), 3)
	var before := st.gold
	_play(DC + "side_wedding:thibault_progress", ["Begin the wedding"])
	assert_eq(st.quest_stage("a_wedding_at_the_mud_church"), "done")
	assert_true(st.gold >= before + 80.0)


func test_the_wedding_with_one_thing_ready_and_the_wedding_called_off() -> void:
	_play(DC + "side_wedding:thibault_start", ["We will help"])
	dice = LowDice.new()
	_play(DC + "side_wedding:lou_ring", ["Buy the pawn ticket"])
	assert_eq(int(st.get_flag("wedding_score", 0)), 1)
	_play(DC + "side_wedding:thibault_progress", ["Begin the wedding"])
	assert_eq(st.quest_stage("a_wedding_at_the_mud_church"), "done")
	GameState.reset()
	before_each()
	_play(DC + "side_wedding:thibault_start", ["We will help"])
	_play(DC + "side_wedding:thibault_progress", ["Call the wedding off"])
	assert_eq(st.quest_stage("a_wedding_at_the_mud_church"), "lost")


# ---- data ------------------------------------------------------------------------------------------------------------------------------------

func test_every_fight_has_the_three_level_variants() -> void:
	for id: String in ["dc_trail1", "dc_trail2", "dc_trail3", "dc_fort", "dc_shack_approach", "dc_boat_promenade", "dc_casino"]:
		var by_id := {}
		for e: Variant in Compendium.shared().get_entry("locations", id).get("encounters", []):
			var eid := str((e as Dictionary)["id"])
			by_id[eid] = int(by_id.get(eid, 0)) + 1
		for eid: String in by_id:
			assert_true(int(by_id[eid]) in [3, 6], "%s/%s has 3 level variants (6 with the ambush)" % [id, eid])


func test_the_road_and_the_places_are_on_the_hollow_travel_map() -> void:
	var t := Compendium.shared().get_entry("travel", "wickermoor_hollow")
	var places := (t["places"] as Array).map(func(p: Variant) -> String: return str((p as Dictionary)["id"]))
	assert_true("dc_trail1" in places)
	assert_true("dc_murkwater" in places)
	var roads := (t["roads"] as Array).map(func(r: Variant) -> String: return str((r as Dictionary)["id"]))
	assert_true("wickermoor_to_crossroads" in roads)


func test_each_chapter_map_has_its_exits_to_real_places_and_open_squares() -> void:
	for id: String in ["dc_trail1", "dc_trail2", "dc_trail3", "dc_murkwater", "dc_fort", "dc_shack_approach", "dc_lagoon", "dc_boat_promenade", "dc_casino"]:
		var loc := Compendium.shared().get_entry("locations", id)
		assert_true(not loc.is_empty(), id)
		assert_eq(str(loc["region"]), "drowned_crossroads")
		for x: Variant in loc.get("exits", []):
			var to := str((x as Dictionary)["to"])
			assert_true(to == "travel" or not Compendium.shared().get_entry("locations", to).is_empty(), "%s exit to %s" % [id, to])
		for n: Variant in loc.get("npcs", []):
			var c := (n as Dictionary)["cell"] as Array
			var row := ((loc["map"] as Dictionary)["rows"] as Array)[int(c[1])] as String
			assert_true(row[int(c[0])] in ".~_", "%s: %s stands on an open square" % [id, (n as Dictionary)["npc"]])
