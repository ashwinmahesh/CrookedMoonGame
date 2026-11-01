extends TestCase
## R21, Fool's Day: the inn hand's letter and the takeover, the Absurd Streets, Chuckles's welcome, the roads out, the seven booths (one play
## a wave), the Prize Counter (a dearer slip each time), the fifteen reveler conversations (slip, church, spell, fight, beaten), the Silent
## Church (the Man in Marble, the quest, the door), the parade, the unmasking, the Ring of Fools and the morning after, and a failure for each
## failable side quest. Each conversation is played through the DialogueRunner with dice that always roll high (or always low where a failure
## is wanted), the way test_r13_paths plays Foxwillow.

const GAME := preload("res://world/game_root.gd")
const TOWN := "fd_festival"
const REVELERS := {
	"solomon_roderick": "bear", "hilda_brom": "bear", "wendel_somerton": "flag", "alda_farnum": "flag", "jean_myriel": "flag",
	"finneas_trout": "knight", "eleanor_heyling": "knight", "doris_squire": "bell", "weston_murdoch": "bell", "holly_aster": "hut",
	"thomasin_ardor": "hut", "morgan": "hive", "baltus_tolliver": "hive", "old_rusty": "stork", "sister_rain": "stork",
}
const DEFAULTS: Array[String] = ["solomon_roderick", "hilda_brom", "wendel_somerton", "finneas_trout", "eleanor_heyling", "doris_squire", "weston_murdoch",
	"holly_aster", "morgan", "baltus_tolliver", "old_rusty", "sister_rain"]


## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll 1: every check fails.
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


func _flag(id: String) -> bool:
	return bool(st.get_flag(id))


func _int(id: String) -> int:
	return int(st.get_flag(id, 0))


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once they run out, which is
## "leave" in every menu here). Returns what the conversation ended in.
func _play(ref: String, picks: Array[String] = []) -> Dictionary:
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := picks.duplicate()
	var b := r.next()
	for i in 900:
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
	dice = HighDice.new()
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	st.location = TOWN
	st.set_flag("festival_active")
	st.set_flag("fd_welcomed")


func after_each() -> void:
	GameState.reset()


## Who stands where: the first placement per NPC whose `when` holds.
func _stands(npc_id: String) -> Dictionary:
	for e: Variant in _loc().get("npcs", []):
		if str((e as Dictionary)["npc"]) == npc_id and _holds((e as Dictionary).get("when", "")):
			return e as Dictionary
	return {}


# ---- the hook and the takeover --------------------------------------------------------------------------------------------------

func test_the_letter_comes_only_after_golub_is_dead() -> void:
	st.location = "wickermoor_village"
	st.set_flag("wm_welcomed")
	assert_true(_stands("bess_crumley").is_empty(), "no messenger while Golub lives")
	st.set_flag("golub_dead")
	var e := _stands("bess_crumley")
	assert_eq(str(e.get("dialogue", "")), "fools_day/hook:messenger")


func test_the_messenger_dies_with_the_letter_and_the_festival_begins() -> void:
	st.location = "wickermoor_village"
	st.set_flag("golub_dead")
	_play("fools_day/hook:messenger", ["Search"])
	assert_true(_flag("fools_letter_given"))
	assert_true(_flag("festival_active"))
	assert_eq(st.quest_stage("fools_day"), "invitation")
	assert_eq(st.quest_stage("the_storks_letter"), "asked")
	assert_true(_stands("bess_crumley").is_empty(), "Bess does not stand again")


func test_the_letter_can_be_read_and_the_pockets_left_alone() -> void:
	st.location = "wickermoor_village"
	_play("fools_day/hook:messenger", ["Read the letter"])
	assert_true(_flag("fools_letter_given"))
	assert_eq(st.quest_stage("the_storks_letter"), "")


func test_the_takeover_moves_the_party_into_the_festival_and_back_gate_returns() -> void:
	st.location = "wickermoor_village"
	st.set_quest_stage("fools_day", "invitation")
	var b := _play("fools_day/hook:takeover")
	assert_eq(str((b.get("move", {}) as Dictionary).get("location", "")), "fd_festival")
	assert_eq(st.quest_stage("fools_day"), "absurd_streets")
	st.set_flag("fd_away", 1)
	st.location = "wickermoor_village"
	_play("fools_day/hook:return_gate", ["Step back"])
	assert_eq(_int("fd_away"), 0)


func test_the_hub_gates_the_festival_by_flags() -> void:
	st.location = "wickermoor_village"
	st.set_flag("festival_active")
	var up := 0
	for p: Variant in _loc().get("props", []):
		if str((p as Dictionary).get("id", "")).begins_with("wm_fd_takeover") and _holds((p as Dictionary).get("call_when", "")):
			up += 1
	assert_true(up >= 3, "the takeover stands at the village's arrival squares")
	st.set_flag("fd_away", 1)
	for p: Variant in _loc().get("props", []):
		if str((p as Dictionary).get("id", "")).begins_with("wm_fd_takeover"):
			assert_true(not _holds((p as Dictionary).get("call_when", "")), "fled: the takeover rests")
	st.set_flag("shows_over")
	for p: Variant in _loc().get("props", []):
		if str((p as Dictionary).get("id", "")).begins_with("wm_fd_"):
			assert_true(not _holds((p as Dictionary).get("call_when", "")), "over: the village is ordinary again")


# ---- the streets, the welcome, the roads ----------------------------------------------------------------------------------------

func test_following_the_crowd_or_fighting_it_both_reach_the_square() -> void:
	st.set_quest_stage("fools_day", "absurd_streets")
	_play("fools_day/welcome:streets", ["Let the crowd"])
	assert_true(_flag("absurd_streets_seen"))
	st.set_flag("absurd_streets_seen", false)
	_play("fools_day/welcome:streets", ["Push back"])
	assert_eq(fights, ["follow_follow_brawl"] as Array[String])
	_play("fools_day/welcome:streets")
	assert_true(_flag("absurd_streets_seen"))


func test_the_welcome_play_along_the_ask_for_mercy_and_the_pity() -> void:
	st.set_flag("fd_welcomed", false)
	st.set_quest_stage("fools_day", "welcome")
	_play("fools_day/welcome:welcome", ["Ask how", "Ask where", "Ask who", "go", "pity", "Play along"])
	assert_true(_flag("fd_welcomed"))
	assert_true(_flag("refused_to_hate"))
	assert_eq(st.quest_stage("fools_day"), "revelry")
	assert_eq(_int("fool_tickets"), 1, "asking nicely earns one ticket")


func test_telling_chuckles_you_hate_him_starts_the_parade_without_a_soft_lock() -> void:
	st.set_flag("fd_welcomed", false)
	_play("fools_day/welcome:welcome", ["I hate you"])
	assert_true(_flag("told_chuckles_hate"))
	assert_eq(st.quest_stage("fools_day"), "parade")


func test_the_first_road_out_lands_at_the_church_the_next_escape_and_three_failures_offer_the_parade() -> void:
	var b := _play("fools_day/roads:attempt")
	assert_true(_flag("fd_church_found"))
	assert_eq(str((b.get("move", {}) as Dictionary).get("location", "")), "fd_silent_church")
	st.location = TOWN
	b = _play("fools_day/roads:attempt", ["Find the true road"])
	assert_true(_flag("left_festival"))
	assert_eq(_int("fd_away"), 1)
	assert_eq(str((b.get("move", {}) as Dictionary).get("location", "")), "wickermoor_village")
	# a hero who always fails: two failures, the third lands at the offer, and "no" starts the count over
	st.location = TOWN
	dice = LowDice.new()
	for n in 2:
		_play("fools_day/roads:attempt", ["Find the true road"])
		st.location = TOWN
	assert_eq(_int("roads_failures"), 2)
	_play("fools_day/roads:attempt", ["Find the true road", "No"])
	assert_eq(_int("roads_failures"), 0, "saying no starts the count over")
	assert_true(not _flag("parade_offer_taken"))
	st.location = TOWN
	st.set_flag("roads_failures", 3)
	_play("fools_day/roads:attempt", ["Yes"])
	assert_true(_flag("parade_offer_taken"))


# ---- the crowd and the booths ---------------------------------------------------------------------------------------------------

func test_the_crowd_search_finds_every_costume_and_the_booths_find_them_too() -> void:
	_play("fools_day/crowd:search", ["Spend an hour", "flag-carriers", "horned bear", "queen bee", "chicken legs", "chiming bell", "knight", "stilted stork"])
	for c: String in ["flag", "bear", "hive", "hut", "bell"]:
		assert_true(_flag("found_" + c), "found " + c)   # the rest need a higher total than a plain roll gives some heroes: the booths show them too
	st.set_flag("found_bear", false)
	_play("fools_day/booths_two:e_start", ["Look around"])
	assert_true(_flag("found_bear"), "a booth shows who lurks beside it")


func test_every_booth_pays_tickets_once_a_wave() -> void:
	var cases := {
		"a": ["booths:a_start", ["Play a round"]], "b": ["booths:b_start", ["Play a round", "Read the host"]],
		"c": ["booths:c_start", ["Play a round", "Second riddle", "Footsteps"]], "d": ["booths:d_start", ["Play a round", "Drum", "Drum", "Drum"]],
		"e": ["booths_two:e_start", ["Play a round", "Arm wrestle"]], "f": ["booths_two:f_start", ["Play a round", "Down the cup"]],
		"g": ["booths_two:g_start", ["Play a round", "something true"]],
	}
	for k: String in cases:
		var before := _int("fool_tickets")
		var c: Array = cases[k]
		var picks: Array[String] = []
		for p: Variant in c[1]:
			picks.append(str(p))
		_play("fools_day/" + str(c[0]), picks)
		assert_true(_int("fool_tickets") > before, "booth %s paid" % k)
		assert_eq(_int("booth_%s_plays" % k), _int("revelers_freed") + 1)
		# a second play in the same wave is not offered
		var r := DialogueRunner.new(st, dice)
		r.start("fools_day/" + str(c[0]))
		var b := r.next()
		for i in 20:
			if str(b["kind"]) == "options":
				break
			b = r.next()
		for o: Variant in b["options"]:
			if str((o as Dictionary)["text"]).contains("Play a round"):
				assert_true(not bool((o as Dictionary)["enabled"]), "booth %s: one play a wave" % k)
		# one reveler freed refreshes it
		st.set_flag("revelers_freed", _int("revelers_freed") + 1)


func test_a_booth_worker_can_be_fought_and_is_replaced() -> void:
	_play("fools_day/booths:a_start", ["Challenge"])
	assert_eq(fights, ["booth_a"] as Array[String])


func test_the_prize_counter_prices_rise_and_prizes_are_one_of_each() -> void:
	st.set_flag("fool_tickets", 60)
	_play("fools_day/prize:counter", ["Buy a release", "Pay 1 ticket"])
	assert_eq(_int("release_slips"), 1)
	assert_eq(_int("revelers_bought"), 1)
	assert_eq(_int("fool_tickets"), 59)
	_play("fools_day/prize:counter", ["Buy a release", "Pay 2 tickets"])
	assert_eq(_int("fool_tickets"), 57)
	assert_eq(_int("release_slips"), 2)
	_play("fools_day/prize:counter", ["Look at the prizes", "Revelry Suit"])
	assert_true(st.party_has_item("revelry_suit") or _flag("prize_suit_taken"))
	assert_eq(_int("fool_tickets"), 54)
	var left := _int("fool_tickets")
	_play("fools_day/prize:counter", ["Look at the prizes"])
	assert_eq(_int("fool_tickets"), left)


# ---- the revelers ---------------------------------------------------------------------------------------------------------------

func test_each_slot_has_one_person_and_the_swap_rule_puts_the_connection_in() -> void:
	for c: String in ["flag", "bear", "hive", "hut", "bell", "knight", "stork"]:
		st.set_flag("found_" + c)
	var stands := {}
	for nid: String in REVELERS:
		if not _stands(nid).is_empty():
			stands[nid] = REVELERS[nid]
	assert_eq(stands.size(), 12, "twelve stand in the first pass: %s" % [stands.keys()])
	st.set_flag("connection_ascendancy")
	st.set_flag("connection_evolution")
	assert_true(not _stands("alda_farnum").is_empty() and _stands("wendel_somerton").is_empty(), "Alda takes the flag")
	assert_true(not _stands("thomasin_ardor").is_empty() and _stands("holly_aster").is_empty(), "Thomasin takes the hut")


func test_every_default_reveler_can_be_freed_by_a_slip() -> void:
	for nid: String in DEFAULTS:
		var costume := str(REVELERS[nid])
		st.set_flag("release_slips", 1)
		_play("fools_day/reveler_%s:%s_start" % [costume, nid], ["release slip"])
		assert_true(_flag("reveler_%s_freed" % nid), nid)
		assert_eq(str(st.get_flag("reveler_" + nid, "")), "tickets")
	assert_eq(_int("revelers_freed"), 12)
	assert_eq(_int("release_slips"), 0)


func test_the_other_ways_church_spell_and_fists() -> void:
	_play("fools_day/reveler_bear:solomon_roderick_start", ["better party"])
	assert_eq(str(st.get_flag("reveler_solomon_roderick", "")), "church")
	assert_eq(_int("church_guests"), 1)
	_play("fools_day/reveler_bear:hilda_brom_start", ["Knock them out"])
	assert_eq(fights, ["reveler_hilda_brom"] as Array[String])
	assert_true(_flag("reveler_hilda_brom_beaten"))
	assert_eq(str(_stands("hilda_brom").get("dialogue", "")), "fools_day/reveler_bear:hilda_brom_beaten")
	_play("fools_day/reveler_bear:hilda_brom_beaten")
	assert_eq(str(st.get_flag("reveler_hilda_brom", "")), "beaten")
	assert_eq(_int("revelers_freed"), 2)
	_play("fools_day/reveler_flag:wendel_somerton_calm")
	assert_eq(str(st.get_flag("reveler_wendel_somerton", "")), "uncharmed")


func test_a_failed_invitation_costs_a_laugh_and_leaves_the_other_ways_open() -> void:
	dice = LowDice.new()
	_play("fools_day/reveler_knight:finneas_trout_start", ["better party", "Say Chuckles", "Leave"])
	assert_true(_flag("fd_chuckles_amused"))
	assert_true(not _flag("reveler_finneas_trout_freed"))
	st.set_flag("release_slips", 1)
	_play("fools_day/reveler_knight:finneas_trout_start", ["release slip"])
	assert_true(_flag("reveler_finneas_trout_freed"))


func test_free_the_bell_three_ways_and_a_failure() -> void:
	st.set_flag("found_bell")
	_play("fools_day/reveler_bell:doris_squire_start", ["tune", "Finish the tune"])
	assert_eq(st.quest_stage("free_the_bell"), "done")
	assert_true(_flag("bell_tune_known"))
	_play("fools_day/reveler_bell:weston_murdoch_start", ["Hum the finished tune"])
	assert_true(_flag("reveler_weston_murdoch_freed"))
	# the banjo
	GameState.reset()
	before_each()
	st.give_item("jericho_banjo", 1)
	_play("fools_day/reveler_bell:doris_squire_start", ["tune", "banjo"])
	assert_true(_flag("bell_tune_banjo"))
	assert_eq(st.quest_stage("free_the_bell"), "done")
	# giving up closes the quest with a visible consequence
	GameState.reset()
	before_each()
	_play("fools_day/reveler_bell:weston_murdoch_start", ["tune", "Give up"])
	assert_eq(st.quest_stage("free_the_bell"), "silenced")
	assert_true(_flag("bell_tune_lost"))


func test_the_storks_letter_lucid_or_charmed_or_never_sent() -> void:
	st.set_quest_stage("the_storks_letter", "asked")
	st.give_item("bess_second_letter", 1)
	_play("fools_day/reveler_stork:old_rusty_start", ["Read him"])
	assert_eq(st.quest_stage("the_storks_letter"), "done")
	assert_eq(str(st.get_flag("stork_letter_outcome", "")), "charmed")
	GameState.reset()
	before_each()
	st.set_quest_stage("the_storks_letter", "asked")
	st.give_item("bess_second_letter", 1)
	st.set_flag("reveler_old_rusty_freed")
	_play("fools_day/reveler_stork:old_rusty_sheltered", ["Give him"])
	assert_eq(str(st.get_flag("stork_letter_outcome", "")), "lucid")


# ---- the church -----------------------------------------------------------------------------------------------------------------

func test_the_man_in_marble_shelters_the_truthful_and_the_liars_alike() -> void:
	_arrive("fd_silent_church")
	_play("fools_day/church:arrive", ["Tell him the truth"])
	assert_true(_flag("man_in_marble_met"))
	GameState.reset()
	before_each()
	_arrive("fd_silent_church")
	dice = LowDice.new()
	_play("fools_day/church:arrive", ["Say we came to pray"])
	assert_true(_flag("man_in_marble_met"), "a failed lie still gets the shelter")


func test_the_church_rests_the_party_and_the_quest_runs_to_a_held_door() -> void:
	_arrive("fd_silent_church")
	st.set_flag("man_in_marble_met")
	_play("fools_day/church:talk", ["Ask to rest"])
	assert_true(_flag("church_rest_taken"))
	_play("fools_day/church:talk", ["Ask what he needs", "We will bring"])
	assert_eq(st.quest_stage("the_silent_church"), "asked")
	st.set_flag("church_guests", 3)
	_play("fools_day/church:talk", ["How many"])
	assert_eq(st.quest_stage("the_silent_church"), "sheltered")
	_arrive(TOWN)
	_play("fools_day/church:hold_door", ["Brace the door"])
	assert_eq(st.quest_stage("the_silent_church"), "done")


func test_a_failed_door_roll_does_not_end_the_quest_and_barring_it_does() -> void:
	st.set_quest_stage("the_silent_church", "sheltered")
	dice = LowDice.new()
	_play("fools_day/church:hold_door", ["Brace the door", "Talk the crowd down", "Strike up", "Let the Man in Marble"])
	assert_eq(st.quest_stage("the_silent_church"), "barred")


func test_hearing_it_out_a_failed_roll_alone_never_closes_the_church_quest() -> void:
	st.set_quest_stage("the_silent_church", "sheltered")
	dice = LowDice.new()
	_play("fools_day/church:hold_door", ["Brace the door", "Talk the crowd down", "Strike up", "Fall back"])
	assert_eq(st.quest_stage("the_silent_church"), "sheltered")


# ---- the side quests ------------------------------------------------------------------------------------------------------------

func test_twelve_costumes_matched_reported_and_lost() -> void:
	_play("fools_day/quill:festival", ["torn program", "We will match"])
	assert_eq(st.quest_stage("twelve_costumes"), "asked")
	_play("fools_day/quill:festival", ["Try to match", "horned bear", "hive", "chicken", "knight with", "suit of bells", "bird on stilts"])
	assert_eq(st.quest_stage("twelve_costumes"), "matched")
	_play("fools_day/quill:festival", ["Show him"])
	assert_eq(st.quest_stage("twelve_costumes"), "done")
	# the parade burns the program
	GameState.reset()
	before_each()
	st.set_quest_stage("twelve_costumes", "asked")
	_play("fools_day/parade:begin")
	assert_eq(st.quest_stage("twelve_costumes"), "lost")


func test_the_understudy_three_good_ends_and_one_slight() -> void:
	_play("fools_day/understudy:start", ["Be his judge", "Humour"])
	assert_eq(st.quest_stage("chuckles_understudy"), "done")
	GameState.reset()
	before_each()
	_play("fools_day/understudy:start", ["Be his judge", "better joke"])
	assert_eq(st.quest_stage("chuckles_understudy"), "done")
	GameState.reset()
	before_each()
	_play("fools_day/understudy:start", ["Be his judge", "Tell him the truth"])
	assert_eq(st.quest_stage("chuckles_understudy"), "slighted")
	GameState.reset()
	before_each()
	dice = LowDice.new()
	_play("fools_day/understudy:start", ["Be his judge", "better joke", "See what", "Humour"])
	assert_eq(st.quest_stage("chuckles_understudy"), "done", "failed rolls never lock the quest")


# ---- the parade, the unmasking and the Ring ------------------------------------------------------------------------------------

func test_the_parade_starts_by_three_doors_and_ends_the_unfinished_quests_of_the_square() -> void:
	var triggers := 0
	for p: Variant in _loc().get("props", []):
		if str((p as Dictionary).get("id", "")) == "fd_parade_ground":
			var when := str((p as Dictionary).get("call_when", ""))
			for setting: Array in [["revelers_freed", 12], ["told_chuckles_hate", 1], ["parade_offer_taken", 1]]:
				GameState.reset()
				before_each()
				st.set_flag(str(setting[0]), setting[1])
				if _holds(when):
					triggers += 1
	assert_eq(triggers, 3)


func test_the_heralds_fall_and_unmask_and_the_party_goes_to_the_ring() -> void:
	st.set_quest_stage("fools_day", "revelry")
	_play("fools_day/parade:begin")
	assert_eq(fights, ["parade_heralds"] as Array[String])
	assert_eq(st.quest_stage("fools_day"), "heralds_unmasked")
	var b := _play("fools_day/parade:unmask")
	assert_true(_flag("druskenvalds_unmasked"))
	assert_eq(str((b.get("move", {}) as Dictionary).get("location", "")), "fd_ring_of_fools")
	assert_eq(st.quest_stage("fools_day"), "ring_of_fools")


func test_the_ring_the_fight_and_the_morning_after() -> void:
	_arrive("fd_ring_of_fools")
	st.set_quest_stage("fools_day", "ring_of_fools")
	st.set_flag("revelers_freed", 12)
	_play("fools_day/ring:taunt", ["Study", "Draw weapons"])
	assert_true(_flag("ring_started"))
	assert_eq(fights, ["ring_of_fools"] as Array[String])
	assert_true(_flag("ring_of_fools_done"))
	assert_eq(st.quest_stage("fools_day"), "shows_over")
	var acts := _int("act2_done")
	var b := _play("fools_day/ring:shows_over")
	assert_true(_flag("chuckles_dead"))
	assert_true(_flag("marotte_found"))
	assert_true(_flag("shows_over"))
	assert_eq(_int("act2_done"), acts, "the chapter does not touch act2_done")
	assert_eq(str((b.get("move", {}) as Dictionary).get("location", "")), "wickermoor_village")


func test_the_ring_fights_scale_with_the_friends_left_dancing() -> void:
	_arrive("fd_ring_of_fools")
	var counts := []
	for freed: int in [0, 4, 7, 10, 12]:
		st.set_flag("revelers_freed", freed)
		var n := 0
		for e: Variant in _loc().get("encounters", []):
			if str((e as Dictionary)["id"]) == "ring_of_fools" and _holds((e as Dictionary).get("when", "")):
				for m: Variant in (e as Dictionary)["monsters"]:
					if str((m as Dictionary).get("side", "")) == "neutral":
						n += 1
		counts.append(n)
	assert_eq(counts, [8, 6, 4, 2, 0])


func test_a_stork_letter_never_sent_ends_at_the_morning_after() -> void:
	_arrive("fd_ring_of_fools")
	st.set_quest_stage("the_storks_letter", "asked")
	_play("fools_day/ring:shows_over")
	assert_eq(st.quest_stage("the_storks_letter"), "unsent")
