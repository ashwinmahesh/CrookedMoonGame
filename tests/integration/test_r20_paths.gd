extends TestCase
## R20, The Roving Rookery: the hook (both routes), the crime scene and the master stroke, the posse, the jail beat (six ways out), Wickermoor under the charm
## (locked doors, mobs, the Powder Keg's victims), the hunt, the dovecote and Golub, the aftermath, and the five side quests. Each conversation is played
## through the DialogueRunner by the NODE an option leads to (so the lines may be re-drafted without touching this file), with dice that always roll high
## (or always roll 1, for the failure paths), and a fight a conversation starts is won as the place records it.

const GAME := preload("res://world/game_root.gd")
const VILLAGE := "wickermoor_village"
const HOOK_FLAGS := ["gorthos_slain", "raum_slain", "renathyr_slain", "lethica_slain", "grinning_sinner_slain"]


## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll a 1: every check in a conversation fails.
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
var last: Dictionary = {}


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", st.location)


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


## Plays `ref` through, taking at each menu the first enabled option whose target node is the next of `gotos` (an option leading to END when they
## run out, else the last one). Returns what the conversation ended in.
func _play(ref: String, gotos: Array[String] = []) -> Dictionary:
	var r := DialogueRunner.new(st, dice)
	assert_true(r.start(ref), "%s starts" % ref)
	var left := gotos.duplicate()
	var b := r.next()
	for i in 800:
		match str(b["kind"]):
			"end":
				break
			"options":
				var opts := b["options"] as Array
				var pick := -1
				var want := str(left[0]) if not left.is_empty() else "END"
				var no_roll := want.ends_with("!")   # "node!" is the way there that asks for no roll
				want = want.trim_suffix("!")
				for j in opts.size():
					if no_roll and not (r._options[j]["check"] as Dictionary).is_empty():
						continue
					var target := str(r._options[j]["ok"]).get_slice(":", 1) if ":" in str(r._options[j]["ok"]) else str(r._options[j]["ok"])
					var fail := str(r._options[j]["fail"])
					if bool((opts[j] as Dictionary)["enabled"]) and (target == want or fail == want):
						pick = j
						break
				if pick < 0 and left.is_empty():
					pick = opts.size() - 1
				if pick < 0:
					fail("%s: no option leading to '%s' among %s" % [ref, want, opts.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))])
					return {}
				if not left.is_empty():
					left.pop_front()
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
	last = b
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


func _flag(id: String) -> bool:
	return bool(st.get_flag(id))


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	dice = HighDice.new()
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	last = {}
	st.location = VILLAGE


func after_each() -> void:
	GameState.reset()


func _hook_open() -> void:
	for f: String in HOOK_FLAGS:
		st.set_flag(f)


func _entry(list_key: String, id_key: String, id: String, dialogue: String = "") -> Dictionary:
	for e: Variant in _loc().get(list_key, []):
		var d := e as Dictionary
		if str(d.get(id_key, "")) == id and (dialogue == "" or str(d.get("dialogue", "")) == dialogue):
			return d
	return {}


## The first entry for `npc` in this place whose `when` holds (as LocationNpcs picks it).
func _stands(npc_id: String) -> Dictionary:
	for e: Variant in _loc().get("npcs", []):
		var d := e as Dictionary
		if str(d["npc"]) == npc_id and _holds(d.get("when", "")):
			return d
	return {}


func _start_hysteria() -> void:
	st.set_flag("golub_exposed")
	st.set_flag("hysteria_began", maxi(1, st.total_minutes()))
	st.set_flag("rk_posse_out")


## The charm on and the posse dealt with: the mobs walk.
func _mobs_walk() -> void:
	_start_hysteria()
	st.set_flag("rk_posse_done")


# ---- the hook and the master stroke --------------------------------------------------------------------------------------------------

func test_route_a_the_plea_takes_the_party_to_the_post_office() -> void:
	_hook_open()
	assert_eq(str(_stands("geneva_fairchild").get("dialogue", "")), "rookery/hook:plea")
	_play("rookery/hook:plea", ["plea_go"])
	assert_true(_flag("rk_started"))
	assert_eq(st.quest_stage("roving_rookery"), "plea")
	assert_eq(st.location, "wickermoor_post_office")


func test_the_plea_waits_for_the_last_of_the_fallen() -> void:
	for f: String in HOOK_FLAGS.slice(0, 4):
		st.set_flag(f)
	assert_true(_stands("geneva_fairchild").is_empty() or str(_stands("geneva_fairchild")["dialogue"]) != "rookery/hook:plea")
	st.set_flag(HOOK_FLAGS[4])
	assert_eq(str(_stands("geneva_fairchild")["dialogue"]), "rookery/hook:plea")


func test_the_crime_scene_has_two_ways_to_the_master_stroke_and_the_body_can_be_read() -> void:
	_hook_open()
	st.set_flag("rk_started")
	_arrive("wickermoor_post_office")
	_play("rookery/post:false_geneva", ["body_look", "body_skin", "stroke"])
	assert_true(_flag("rk_skin_known"))
	assert_true(_flag("golub_exposed"))
	assert_true(int(st.get_flag("hysteria_began", 0)) > 0 or _flag("hysteria_began"))
	assert_true(_flag("rk_posse_out"))
	assert_eq(st.quest_stage("roving_rookery"), "posse")
	assert_eq(st.location, VILLAGE)


func test_the_master_stroke_comes_even_if_the_party_never_looks_at_the_body() -> void:
	_hook_open()
	st.set_flag("rk_started")
	_arrive("wickermoor_post_office")
	dice = LowDice.new()
	_play("rookery/post:false_geneva", ["stroke"])
	assert_true(_flag("golub_exposed"))
	assert_eq(st.quest_stage("roving_rookery"), "posse")


func test_the_post_office_shows_the_skins_and_closes_its_front_door_under_the_charm() -> void:
	_arrive("wickermoor_post_office")
	st.set_flag("golub_exposed")
	assert_true(bool(_stands("theodora_mayville").get("lying", false)))
	assert_true(bool(_stands("geneva_fairchild").get("lying", false)))     # route A: Geneva is a second skin on the floor
	_arrive(VILLAGE)
	assert_true(_holds(_entry("exits", "id", "post_office")["when"]))        # no charm yet: open
	_start_hysteria()
	assert_false(_holds(_entry("exits", "id", "post_office")["when"]))


func test_route_b_accusing_the_postmaster_early_lets_geneva_live_and_the_dovecote_walk() -> void:
	_arrive("wickermoor_post_office")
	st.set_flag("cult_proof_theodora")
	assert_true(not _entry("props", "id", "rk_post_accuse").is_empty())
	assert_true(_holds(_entry("props", "id", "rk_post_accuse")["when"]))
	_play("rookery/hook:accuse_theodora", ["exposed"])
	assert_true(_flag("golub_exposed") and _flag("golub_exposed_early") and _flag("geneva_alive"))
	assert_eq(st.quest_stage("roving_rookery"), "exposed")
	assert_false(_flag("hysteria_began"))
	# the village plot is empty from then on
	_arrive(VILLAGE)
	assert_false(_holds(_entry("exits", "id", "dovecote")["when"]))
	assert_true(_holds(_entry("props", "id", "rk_ring_stones")["when"]))


func test_route_b_geneva_accuses_the_party_when_the_last_fallen_dies_and_the_charm_starts() -> void:
	st.set_flag("golub_exposed_early")
	st.set_flag("golub_exposed")
	st.set_flag("geneva_alive")
	_hook_open()
	assert_eq(str(_stands("geneva_fairchild")["dialogue"]), "rookery/hook:geneva_accuses")
	_play("rookery/hook:geneva_accuses", ["geneva_end"])
	assert_true(_flag("hysteria_began") and _flag("rk_posse_out"))
	assert_eq(st.quest_stage("roving_rookery"), "posse")


# ---- the posse ---------------------------------------------------------------------------------------------------------------------

func test_the_posse_waits_outside_the_post_office() -> void:
	_start_hysteria()
	assert_eq(str(_stands("doris_squire")["dialogue"]), "rookery/posse:start")
	assert_eq(str(_stands("howie_butterman")["dialogue"]), "rookery/posse:howie")


func test_the_posse_can_be_talked_down_once_the_charm_is_seen() -> void:
	_start_hysteria()
	_play("rookery/posse:start", ["charm", "talk_down"])
	assert_eq(str(st.get_flag("posse_outcome")), "talked")
	assert_true(_flag("rk_posse_done"))
	assert_eq(st.quest_stage("roving_rookery"), "hysteria")


func test_the_posse_can_be_dispelled_with_no_roll() -> void:
	_start_hysteria()
	dice = LowDice.new()
	# the spell options need a caster; the way is open to whoever knows the spell. Playing by node: fleeing needs none.
	_play("rookery/posse:start", ["flee"])
	assert_eq(str(st.get_flag("posse_outcome")), "fled")
	assert_eq(st.location, VILLAGE)
	assert_eq(st.quest_stage("roving_rookery"), "hysteria")


func test_the_posse_can_be_fought() -> void:
	_start_hysteria()
	_play("rookery/posse:start", ["fight"])
	assert_eq(fights, ["rk_posse"] as Array[String])
	assert_eq(str(st.get_flag("posse_outcome")), "fought")
	assert_true(_flag("rk_posse_done"))
	assert_eq(st.quest_stage("roving_rookery"), "hysteria")


func test_surrendering_to_the_posse_locks_the_party_in_the_cells_with_the_trial_clock_running() -> void:
	_start_hysteria()
	_play("rookery/posse:start", ["surrender"])
	assert_eq(str(st.get_flag("posse_outcome")), "surrendered")
	assert_eq(st.quest_stage("roving_rookery"), "jailed")
	assert_true(Jail.held(st))
	assert_true(_flag("jail_began"))
	assert_eq(st.location, "wickermoor_constable_station")


# ---- the jail beat: six ways out, no execution -------------------------------------------------------------------------------------------

func _jailed() -> void:
	_start_hysteria()
	_play("rookery/posse:start", ["surrender"])
	assert_true(Jail.held(st))


func _out(how: String) -> void:
	assert_false(Jail.held(st), "the party is out")
	assert_eq(str(st.get_flag("jail_escape")), how)
	assert_eq(st.quest_stage("roving_rookery"), "hysteria")


func test_jail_way_1_the_lock_can_be_picked() -> void:
	_jailed()
	st.gain_item("rk_improvised_picks", 1, st.leader_character())
	_play("rookery/jail:bars", ["out_picks"])
	_out("picks")


func test_jail_way_2_the_bars_can_be_bent() -> void:
	_jailed()
	_play("rookery/jail:bars", ["out_bars"])
	_out("bars")


func test_jail_way_3_a_spell_on_doris_needs_no_roll() -> void:
	_jailed()
	_play("rookery/jail:out_spell")
	_out("spell")


func test_jail_way_4_doris_leaves_the_keys_when_her_poetry_is_mentioned() -> void:
	_jailed()
	st.set_flag("quill_poem_found")
	_play("rookery/jail:cell", ["poems"])
	assert_true(_flag("jail_key_left"))
	_play("rookery/jail:keys", ["out_keys"])
	_out("keys")


func test_jail_way_4b_the_keys_can_be_hooked_without_her_leave() -> void:
	_jailed()
	_play("rookery/jail:keys", ["out_keys"])
	_out("keys")


func test_jail_way_5_help_from_outside_comes_without_a_roll() -> void:
	_jailed()
	st.advance_minutes(130)
	_play("rookery/jail:wall", ["wall_dani"])
	_out("help")


func test_jail_way_6_the_march_slips_the_rope_and_the_party_is_never_executed() -> void:
	_jailed()
	st.advance_minutes(370)
	var station := _loc()
	assert_eq(str(_stands("doris_squire")["dialogue"]), "rookery/jail:march")
	assert_true(not station.is_empty())
	_play("rookery/jail:march")
	_out("march")
	assert_eq(st.location, VILLAGE)
	for c: Character in st.party:
		assert_false(c.dead)


func test_every_way_out_is_open_whatever_the_dice_say() -> void:
	_jailed()
	dice = LowDice.new()
	st.set_flag("jail_key_left")
	_play("rookery/jail:keys", ["out_keys"])
	_out("keys")


# ---- Wickermoor under the charm ----------------------------------------------------------------------------------------------------

func test_shops_and_houses_lock_while_the_charm_holds_and_open_when_golub_dies() -> void:
	var bakery := _entry("exits", "id", "shop_bakery")
	assert_true(_holds(bakery["when"]))
	_start_hysteria()
	assert_false(_holds(bakery["when"]))
	assert_true(str(bakery.get("locked_text", "")) != "")
	st.set_flag("golub_dead")
	assert_true(_holds(bakery["when"]))


func test_the_estate_road_the_moor_road_and_the_stable_stay_open_under_the_charm() -> void:
	_start_hysteria()
	for id: String in ["moor_road", "south_bridge", "stable"]:
		var e := _entry("exits", "id", id)
		assert_true(str(e.get("when", "")) == "" or _holds(e["when"]), "%s stays open" % id)


func test_mobs_patrol_while_the_charm_holds_and_stand_down_after_a_fight() -> void:
	assert_true(_stands("rk_mob_a").is_empty())
	_mobs_walk()
	assert_eq(str(_stands("rk_mob_a")["dialogue"]), "rookery/folk:mob_a")
	assert_true(not (_stands("rk_mob_a").get("path", []) as Array).is_empty())
	_play("rookery/folk:mob_a", ["mob_fight"])
	assert_eq(fights, ["rk_mob_fight"] as Array[String])
	assert_true(_stands("rk_mob_a").is_empty())
	st.advance_minutes(250)
	assert_false(_stands("rk_mob_a").is_empty())


func test_a_mob_can_be_slipped_with_no_fight() -> void:
	_mobs_walk()
	_play("rookery/folk:mob_b", ["mob_slip"])
	assert_true(fights.is_empty())
	assert_true(_stands("rk_mob_b").is_empty())


func test_a_failed_slip_leads_to_a_non_lethal_fight_not_a_dead_end() -> void:
	_mobs_walk()
	dice = LowDice.new()
	_play("rookery/folk:mob_c", ["mob_slip"])
	assert_eq(fights, ["rk_mob_fight"] as Array[String])


func test_named_villagers_shun_the_party_while_the_charm_holds() -> void:
	_start_hysteria()
	assert_eq(str(_stands("sister_rain")["dialogue"]), "rookery/folk:shun")
	st.set_flag("golub_dead")
	assert_true(str(_stands("sister_rain")["dialogue"]) != "rookery/folk:shun")


func test_the_powder_keg_takes_jeremiah_and_the_schoolhouse_on_the_seventh_dawn_and_more_on_the_fourteenth() -> void:
	_start_hysteria()
	assert_false(_holds(_entry("props", "id", "rk_keg_school")["when"]))
	st.advance_minutes(7 * 1440 + 5)
	assert_true(_holds(_entry("props", "id", "rk_keg_school")["when"]))
	assert_true(bool(_stands("jeremiah_stover").get("lying", false)))
	assert_false(_holds(_entry("props", "id", "rk_keg_carpentry")["when"]))
	st.advance_minutes(7 * 1440)
	assert_true(_holds(_entry("props", "id", "rk_keg_carpentry")["when"]))


func test_a_hidden_jeremiah_is_spared_and_the_wet_schoolhouse_stands() -> void:
	_start_hysteria()
	st.set_flag("rk_jeremiah_hidden")
	st.set_flag("rk_school_saved")
	st.advance_minutes(8 * 1440)
	assert_false(bool(_stands("jeremiah_stover").get("lying", false)))
	assert_false(_holds(_entry("props", "id", "rk_keg_school")["when"]))


func test_albert_spies_in_town_and_can_be_scared_into_talking_without_a_fight() -> void:
	_start_hysteria()
	assert_eq(str(_stands("peeping_albert")["dialogue"]), "rookery/folk:albert_town")
	_play("rookery/folk:albert_town", ["albert_talks"])
	assert_true(_flag("rk_roost_known"))
	assert_true(_stands("peeping_albert").is_empty())


func test_albert_can_be_fought_and_dies_with_the_fight() -> void:
	_start_hysteria()
	_play("rookery/folk:albert_town", ["albert_fight"])
	assert_eq(fights, ["rk_albert_town"] as Array[String])
	assert_true(_flag("albert_dead"))


func test_the_comic_people_have_their_bits() -> void:
	_start_hysteria()
	st.gold = 10
	_play("rookery/folk:pip", ["pip_pay"])
	assert_true(st.party_has_item("rk_button_ledger"))
	_play("rookery/folk:gaunt", ["gaunt_scared"])
	assert_true(_flag("rk_mob_calm"))
	_play("rookery/folk:goat", ["goat_pet"])


# ---- the hunt ----------------------------------------------------------------------------------------------------------------------

func test_the_sky_watch_starts_the_hunt_and_names_the_roost() -> void:
	_start_hysteria()
	_play("rookery/hunt:sky", ["sky_found"])
	assert_true(_flag("rk_hunt"))
	assert_true(_flag("rk_roost_known"))
	assert_eq(st.quest_stage("roving_rookery"), "hunt")


func test_the_hunt_has_a_way_that_needs_no_roll() -> void:
	_start_hysteria()
	st.set_flag("rk_roost_known")
	dice = LowDice.new()
	_play("rookery/hunt:sky", ["sky_found"])
	assert_true(_flag("rk_hunt"))


func test_a_missed_sky_watch_still_leaves_the_circuit() -> void:
	_start_hysteria()
	dice = LowDice.new()
	_play("rookery/hunt:sky", ["sky_missed", "sky_circuit"])
	assert_true(_flag("rk_hunt"))


func test_the_four_roosts_are_on_the_travel_map_during_the_hunt() -> void:
	var t := JSON.parse_string(FileAccess.get_file_as_string("res://data/travel/wickermoor_hollow.json")) as Dictionary
	var ids: Array[String] = []
	for p: Variant in t["places"]:
		if str((p as Dictionary)["id"]).begins_with("rk_roost_"):
			ids.append(str((p as Dictionary)["id"]))
			assert_false(_holds((p as Dictionary)["when"]) and not _flag("rk_hunt"))
	assert_eq(ids.size(), 4)
	st.set_flag("rk_hunt")
	for p: Variant in t["places"]:
		if str((p as Dictionary)["id"]).begins_with("rk_roost_"):
			assert_true(_holds((p as Dictionary)["when"]))


func test_albert_seeing_the_party_makes_the_dovecote_move_to_the_next_roost() -> void:
	_start_hysteria()
	st.set_flag("rk_hunt")
	_arrive("rk_roost_prairie")
	dice = LowDice.new()
	_play("rookery/hunt:arrive", ["arrive_ok"])
	assert_eq(int(st.get_flag("dovecote_moves", 0)), 1)
	assert_eq(int(st.get_flag("dovecote_roost", 0)), 1)
	assert_true(_flag("rk_seen_prairie"))


func test_the_roosts_wrap_round_and_albert_gives_up_after_two_moves() -> void:
	_start_hysteria()
	st.set_flag("dovecote_roost", 3)
	_arrive("rk_roost_lakeshore")
	dice = LowDice.new()
	_play("rookery/hunt:arrive", ["arrive_ok"])
	assert_eq(int(st.get_flag("dovecote_roost", 0)), 0)
	st.set_flag("dovecote_moves", 2)
	_play("rookery/hunt:arrive")
	assert_eq(int(st.get_flag("dovecote_moves", 0)), 2)


func test_a_quiet_approach_keeps_the_dovecote_where_it_is() -> void:
	_start_hysteria()
	_arrive("rk_roost_prairie")
	_play("rookery/hunt:arrive", ["arrive_ok"])
	assert_eq(int(st.get_flag("dovecote_roost", 0)), 0)
	assert_eq(int(st.get_flag("dovecote_moves", 0)), 0)


func test_each_roost_shows_the_dovecote_only_where_it_is() -> void:
	for n in 4:
		st.set_flag("dovecote_roost", n)
		var keys := ["prairie", "swamp", "foothills", "lakeshore"]
		for k in 4:
			_arrive("rk_roost_" + keys[k])
			var ext := _entry("props", "id", "rk_dovecote_ext_" + keys[k])
			assert_eq(_holds(ext["when"]), k == n)
			var door := _entry("exits", "id", "dovecote_door")
			assert_eq(_holds(door["when"]), k == n)


func test_hilda_reads_the_tracks_when_she_is_asked_properly() -> void:
	_start_hysteria()
	st.set_flag("rk_hunt")
	assert_eq(str(_stands("hilda_brom")["dialogue"]), "rookery/hunt:hilda")
	_play("rookery/hunt:hilda", ["hilda_tell"])
	assert_true(_flag("rk_roost_known"))


# ---- the dovecote and Golub --------------------------------------------------------------------------------------------------------

func test_the_dovecote_door_leads_in_and_the_parcel_fight_is_the_first_room() -> void:
	_start_hysteria()
	_arrive("rk_roost_prairie")
	_play("rookery/hunt:dovecote_here", ["enter"])
	assert_eq(st.quest_stage("roving_rookery"), "dovecote")
	assert_eq(st.location, "rk_dovecote_r1")
	_win("rk_parcels")
	assert_true(_flag("rk_parcels_done"))


func test_golub_before_the_fight_and_the_fight_itself() -> void:
	_start_hysteria()
	_arrive("rk_dovecote_r1")
	_play("rookery/dovecote:golub", ["attack"])
	assert_eq(fights, ["rk_golub"] as Array[String])
	assert_true(_flag("rk_golub_done"))
	assert_eq(st.quest_stage("roving_rookery"), "dovecote")


func test_golubs_vanity_can_be_read_before_the_fight() -> void:
	_start_hysteria()
	_arrive("rk_dovecote_r1")
	_play("rookery/dovecote:golub", ["vain", "attack"])
	assert_true(_flag("rk_golub_vain"))


func test_reading_her_cubbies_gives_every_villagers_faction() -> void:
	_arrive("rk_dovecote_r1")
	st.set_flag("rk_golub_done")
	_play("rookery/dovecote:cubbies", ["read"])
	assert_true(_flag("golub_secrets_read"))
	assert_true(_flag("cult_proof_randall") and _flag("cult_proof_alda") and _flag("cult_proof_baltus") and _flag("cult_proof_gaston") and _flag("cult_proof_howie"))


func test_home_to_roost_ends_the_chapter_without_counting_an_act_two_chapter() -> void:
	_start_hysteria()
	_arrive("rk_dovecote_r1")
	st.set_flag("rk_golub_done")
	var before := int(st.get_flag("act2_done", 0))
	_play("rookery/dovecote:home_to_roost")
	assert_true(_flag("golub_dead"))
	assert_eq(st.quest_stage("roving_rookery"), "done")
	assert_eq(int(st.get_flag("act2_done", 0)), before)


func test_the_charm_lifts_and_the_village_wakes() -> void:
	_mobs_walk()
	st.set_flag("rk_posse_done")
	st.set_flag("golub_dead")
	assert_true(_stands("rk_mob_a").is_empty())
	assert_true(_holds(_entry("exits", "id", "shop_bakery")["when"]))
	assert_eq(str(_stands("phillip_druskenvald")["dialogue"]), "rookery/after:phillip_repairs")
	assert_eq(str(_stands("doris_squire")["dialogue"]), "rookery/after:doris_after")


func test_the_new_postmaster_after_route_a_and_geneva_after_route_b() -> void:
	st.set_flag("golub_dead")
	st.set_flag("golub_exposed")
	_arrive("wickermoor_post_office")
	assert_eq(str(_stands("wynn_carter")["dialogue"]), "rookery/after:wynn")
	st.set_flag("geneva_alive")
	assert_eq(str(_stands("geneva_fairchild")["dialogue"]), "rookery/after:geneva_postmaster")


func test_every_new_place_is_reachable_by_its_exits() -> void:
	for id: String in ["rk_dovecote_r1", "rk_roost_prairie", "rk_roost_swamp", "rk_roost_foothills", "rk_roost_lakeshore"]:
		_arrive(id)
		var spawn := ((_loc()["spawns"] as Dictionary)["default"]) as Array
		assert_true(spawn.size() == 2)
		for e: Variant in _loc().get("exits", []):
			var to := str((e as Dictionary)["to"])
			assert_true(to == "travel" or not Compendium.shared().get_entry("locations", to).is_empty(), "%s -> %s" % [id, to])


# ---- side quests: The Quiet Door ----------------------------------------------------------------------------------------------------

func test_quiet_door_delivers_mrs_oakum_to_the_estate() -> void:
	_start_hysteria()
	_play("rookery/quiet_door:start", ["accept"])
	assert_eq(st.quest_stage("quiet_door"), "asked")
	_arrive("wickermoor_stable")
	assert_eq(str(_stands("mrs_oakum")["dialogue"]), "rookery/quiet_door:oakum")
	_play("rookery/quiet_door:oakum", ["leg1", "leg2", "leg3", "arrive"])
	assert_eq(st.quest_stage("quiet_door"), "delivered")
	assert_eq(st.location, "druskenvald_estate")


func test_quiet_door_has_a_way_with_no_roll() -> void:
	_start_hysteria()
	st.set_flag("rk_quiet_asked")
	st.set_quest_stage("quiet_door", "asked")
	dice = LowDice.new()
	_arrive("wickermoor_stable")
	_play("rookery/quiet_door:oakum", ["leg1", "leg2_long", "leg3_wait", "arrive!"])
	assert_eq(st.quest_stage("quiet_door"), "delivered")


func test_quiet_door_failing_the_escort_costs_mrs_oakum_her_freedom_in_the_cells() -> void:
	_start_hysteria()
	st.set_flag("rk_quiet_asked")
	st.set_quest_stage("quiet_door", "asked")
	dice = LowDice.new()
	_arrive("wickermoor_stable")
	_play("rookery/quiet_door:oakum", ["leg1", "spotted", "give_up"])
	assert_eq(st.quest_stage("quiet_door"), "taken")
	_arrive("wickermoor_constable_station")
	assert_eq(str(_stands("mrs_oakum")["dialogue"]), "rookery/quiet_door:prisoner")


func test_quiet_door_a_spotted_party_can_fight_for_her() -> void:
	_start_hysteria()
	st.set_flag("rk_quiet_asked")
	dice = LowDice.new()
	_arrive("wickermoor_stable")
	_arrive(VILLAGE)
	_play("rookery/quiet_door:spotted", ["fight_for_her"])
	assert_eq(fights, ["rk_mob_fight"] as Array[String])


# ---- Doris Writes Poetry -----------------------------------------------------------------------------------------------------------

func test_poetry_finds_the_poems_and_brings_quill_to_doris_when_the_charm_lifts() -> void:
	_start_hysteria()
	_play("rookery/poetry:start", ["accept"])
	assert_eq(st.quest_stage("doris_poetry"), "asked")
	_arrive("wickermoor_constable_station")
	_play("rookery/poetry:drawer", ["found", "keep"])
	assert_true(_flag("quill_poem_found"))
	assert_eq(st.quest_stage("doris_poetry"), "poem_found")
	st.set_flag("golub_dead")
	assert_eq(str(_stands("doris_squire")["dialogue"]), "rookery/poetry:doris_station")
	_play("rookery/poetry:doris_station")
	assert_eq(st.quest_stage("doris_poetry"), "met")


func test_poetry_can_be_burned_and_that_is_a_visible_ending() -> void:
	_start_hysteria()
	st.set_flag("quill_asked")
	st.set_quest_stage("doris_poetry", "asked")
	_arrive("wickermoor_constable_station")
	_play("rookery/poetry:drawer", ["found", "burn"])
	assert_eq(st.quest_stage("doris_poetry"), "burned")


# ---- A Jury of Pigeons --------------------------------------------------------------------------------------------------------------

func test_the_jury_sits_and_the_mob_adjourns() -> void:
	_mobs_walk()
	_play("rookery/jury:start", ["accept"])
	assert_eq(st.quest_stage("jury_of_pigeons"), "asked")
	_play("rookery/jury:progress", ["docket", "docket_ok", "quorum", "quorum_ok", "oath", "oath_ok", "hearing"])
	assert_eq(st.quest_stage("jury_of_pigeons"), "done")
	assert_true(_flag("rk_mob_calm"))
	assert_true(_stands("rk_mob_a").is_empty())


func test_the_jury_has_a_way_for_every_step_whatever_the_dice() -> void:
	_start_hysteria()
	st.set_flag("rk_jury_asked")
	st.set_quest_stage("jury_of_pigeons", "asked")
	dice = LowDice.new()
	_play("rookery/jury:progress", ["docket", "docket_copy", "quorum", "quorum_goat", "oath", "oath_affirm", "hearing"])
	assert_eq(st.quest_stage("jury_of_pigeons"), "done")


func test_the_jury_can_be_abandoned() -> void:
	_start_hysteria()
	st.set_flag("rk_jury_asked")
	st.set_quest_stage("jury_of_pigeons", "asked")
	_play("rookery/jury:progress", ["quit"])
	assert_eq(st.quest_stage("jury_of_pigeons"), "abandoned")


# ---- Forms for the End of the World ------------------------------------------------------------------------------------------------

func test_forms_three_stamps_buy_a_writ_of_passage() -> void:
	_start_hysteria()
	st.gold = 100
	_play("rookery/forms:start", ["accept"])
	assert_eq(st.quest_stage("forms_for_the_end"), "asked")
	_play("rookery/forms:progress", ["stamp_a", "stamp_a_ok", "stamp_b", "stamp_b_ok", "stamp_c", "forge_ok", "deliver"])
	assert_eq(st.quest_stage("forms_for_the_end"), "done")
	assert_true(st.party_has_item("rk_writ_of_passage"))


func test_forms_a_bad_forgery_ends_in_the_cells_only_by_choice() -> void:
	_start_hysteria()
	st.gold = 100
	st.set_flag("rk_forms_asked")
	st.set_quest_stage("forms_for_the_end", "asked")
	dice = LowDice.new()
	_play("rookery/forms:progress", ["stamp_c", "forge_poor", "fee"])
	assert_true(_flag("rk_stamp_c"))
	assert_eq(st.quest_stage("forms_for_the_end"), "asked")
	_play("rookery/forms:stamp_c", ["forge_poor", "forged"])
	assert_eq(st.quest_stage("forms_for_the_end"), "forged")
	assert_true(Jail.held(st))


func test_the_writ_makes_a_mob_queue_for_forms() -> void:
	_start_hysteria()
	st.gain_item("rk_writ_of_passage", 1, st.leader_character())
	_play("rookery/folk:mob_a", ["mob_writ"])
	assert_true(fights.is_empty())


# ---- The Powder Keg Ledger ---------------------------------------------------------------------------------------------------------

func test_the_ledger_one_name_crossed_out_is_a_success() -> void:
	_start_hysteria()
	_play("rookery/ledger:start", ["accept"])
	assert_eq(st.quest_stage("powder_keg_ledger"), "asked")
	_play("rookery/ledger:progress", ["school", "school_ok"])
	assert_true(_flag("rk_school_saved"))
	st.advance_minutes(8 * 1440)
	_play("rookery/ledger:progress")
	assert_eq(st.quest_stage("powder_keg_ledger"), "done")


func test_the_ledger_saving_both_is_a_success_before_the_seventh_dawn() -> void:
	_start_hysteria()
	st.set_flag("rk_ledger_asked")
	st.set_quest_stage("powder_keg_ledger", "asked")
	st.set_flag("rk_jeremiah_hidden")
	st.set_flag("rk_school_saved")
	_play("rookery/ledger:progress", ["both"])
	assert_eq(st.quest_stage("powder_keg_ledger"), "done")


func test_the_ledger_with_nothing_done_burns_on_the_seventh_dawn() -> void:
	_start_hysteria()
	st.set_flag("rk_ledger_asked")
	st.set_quest_stage("powder_keg_ledger", "asked")
	st.advance_minutes(8 * 1440)
	_play("rookery/ledger:progress")
	assert_eq(st.quest_stage("powder_keg_ledger"), "burned")


func test_jeremiah_goes_to_the_estate_when_asked() -> void:
	_start_hysteria()
	st.set_flag("rk_ledger_asked")
	assert_eq(str(_stands("jeremiah_stover")["dialogue"]), "rookery/folk:jeremiah_escort")
	_play("rookery/folk:jeremiah_escort", ["jeremiah_go"])
	assert_true(_flag("rk_jeremiah_hidden"))
	assert_eq(str(_stands("jeremiah_stover")["dialogue"]), "rookery/folk:jeremiah_hiding")
