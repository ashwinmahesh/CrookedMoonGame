extends TestCase
## R10, the Ghostlight Express: the routes the one book-order playthrough (test_r10_playthrough) does not take. Each test plays its
## own path the same way that file does (a walk over the places' own data: a person is only talked to while their entry's `when`
## holds, a prop's call only fires while its `call_when` does, an exit only opens while its `when` does, every conversation
## runs through the DialogueRunner, a fight a conversation starts is won as LocationFights records a victory). The helpers are
## that file's, with two additions: a conversation can be left at the fight it starts (`win = false`) so the stage and flags
## the fight starts with can be read, and the dice can be switched to ones that always roll 1, so every check fails.
##
## Covered: the six middle cars walked in other orders (with the Tender's door shut until all six haints are gone); each
## haint resolved by the token, three successes, a bottle and a fight; three failures and the truth about the coal turning
## one hostile; the Tender's Corrupted Fuel reading haints_destroyed; the wildpyre; the walk-away and refuse-search branches at
## the wreck; the Fated Tarot and The Fool's whistle; the milestones at three haints and at the crash.

const GAME := preload("res://world/game_root.gd")

## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


## Dice that always roll 1: no check lands.
class LowDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(1)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


const HAINTS: Array[String] = ["sweetheart", "songstress", "daydreamer", "mariner", "jailbird", "harlequin"]
const MIDDLE_CARS: Array[String] = ["ghostlight_g2_sleeper", "ghostlight_g3_lounge", "ghostlight_g4_dining", "ghostlight_g5_mail",
	"ghostlight_g6_baggage", "ghostlight_g7_circus"]
const TENDER := "ghostlight_g8_tender"
const WRECK := "ghostlight_wreckage"

## The car each haint rides in (the cars are shuffled, the haints do not change cars).
const CAR_OF := {"sweetheart": "ghostlight_g2_sleeper", "songstress": "ghostlight_g3_lounge", "daydreamer": "ghostlight_g4_dining",
	"mariner": "ghostlight_g5_mail", "jailbird": "ghostlight_g6_baggage", "harlequin": "ghostlight_g7_circus"}
const TOKEN_ITEM := {"sweetheart": "jakob_braun_letter", "songstress": "ghost_phonograph", "daydreamer": "toad_faced_stone",
	"mariner": "seascape_painting", "jailbird": "steak_and_eggs", "harlequin": "wildpyre_iron_ring"}
## What each haint's menu says for handing over the token, opening the Help menu and offering a bottle (a part of the option's text).
const TOKEN_OPTION := {"sweetheart": "pink letter", "songstress": "phonograph", "daydreamer": "toad stone", "mariner": "painting",
	"jailbird": "steak and eggs", "harlequin": "iron ring"}
const HELP_OPTION := {"sweetheart": "keep you company", "songstress": "help you finish", "daydreamer": "sort this out",
	"mariner": "keep you company with the work", "jailbird": "talk with you", "harlequin": "put this night behind you"}
const BOTTLE_OPTION := {"sweetheart": "empty glass bottle", "songstress": "open bottle", "daydreamer": "empty glass jar",
	"mariner": "empty bottle", "jailbird": "empty glass bottle", "harlequin": "empty glass jar"}
## Three of each haint's listed approaches (none needs a kit): with high dice three wins, with low dice three misses.
const APPROACHES := {
	"sweetheart": ["love song", "parted lovers", "honestly about loss"],
	"songstress": ["Sing the melody", "Trace the magic", "Speak the lonely word"],
	"daydreamer": ["Neighbours forgive", "Every grown-up", "Walk me through"],
	"mariner": ["hard weather", "sea shanty", "worse tale"],
	"jailbird": ["gallows custom", "hot plate", "campfire skillets"],
	"harlequin": ["great cat", "watched den", "Swear on your life"],
}

var st: StoryState
var dice: DiceRoller = HighDice.new()
var fights: Array[String] = []


func before_each() -> void:
	_fresh()


func after_each() -> void:
	GameState.reset()


## A new game's party on a clean story, the dice high again.
func _fresh() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	dice = HighDice.new()
	st.playthrough_seed = 1


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", st.location)


func _holds(expr: Variant) -> bool:
	return StoryConditions.check(str(expr if expr != null else ""), st)


func _entry(list_key: String, id_key: String, id: String) -> Dictionary:
	for e: Variant in _loc().get(list_key, []):
		if str((e as Dictionary).get(id_key, "")) == id:
			return e as Dictionary
	return {}


func _strs(a: Variant) -> Array[String]:
	var out: Array[String] = []
	out.assign(a as Array)
	return out


## Plays `ref` through, taking at each menu the first enabled option holding the next of `picks` (the last option once
## they run out, which is "leave" or "that's all" in most menus here: name the picks that matter). Returns what the conversation ended
## in. A fight it starts is won as the game records a win, unless `win` is false (then `combat` of the result names the fight, still to
## be won with _win).
func _play(ref: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
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
	if combat != "" and win:
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
	st.visited[id] = true   # as LocationView records an arrival: the Switcheroo reads it to tell a first crossing from a later one
	assert_true(not _loc().is_empty(), "%s is a place" % id)


## Talks to `npc` here, as clicking them does: their entry must be on the map now.
func _talk(npc: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
	var e := _entry("npcs", "npc", npc)
	assert_true(not e.is_empty() and _holds(e.get("when")), "%s is in %s to talk to" % [npc, st.location])
	if e.is_empty() or not _holds(e.get("when")):
		return {}
	return _play(str(e["dialogue"]), picks, win)


## A prop's call, as walking up to it fires it (LocationNpcs._check_calls): its `when` and `call_when` must hold.
func _called_by(prop: String, picks: Array[String] = [], win: bool = true) -> Dictionary:
	var p := _entry("props", "id", prop)
	var ok := not p.is_empty() and _holds(p.get("when")) and _holds(p.get("call_when"))
	assert_true(ok, "%s calls out in %s now" % [prop, st.location])
	if not ok:
		return {}
	return _play(str(p["call"]), picks, win)


## Uses a prop with a conversation of its own (a booth, a phonograph, a grille).
func _use(prop: String, picks: Array[String] = []) -> Dictionary:
	var p := _entry("props", "id", prop)
	assert_true(not p.is_empty() and _holds(p.get("when")), "%s can be used in %s" % [prop, st.location])
	return _play(str(p.get("dialogue", "")), picks) if not p.is_empty() else {}


## A search that finds the prop, then using it as LocationInteraction._use_prop does: its flag set, its item taken.
func _search(prop: String) -> void:
	var p := _entry("props", "id", prop)
	assert_true(not p.is_empty() and str(p.get("kind")) == "search" and _holds(p.get("when")), "%s can be searched for in %s" % [prop, st.location])
	if p.is_empty():
		return
	(st.loc_state(st.location)["found"] as Dictionary)[prop] = true
	_take(prop)


## Using a prop that gives something (LocationInteraction._use_prop): its flag set, its item taken.
func _take(prop: String) -> void:
	var p := _entry("props", "id", prop)
	assert_true(not p.is_empty() and _holds(p.get("when")), "%s can be taken from %s" % [prop, st.location])
	if p.is_empty():
		return
	if p.has("flag"):
		st.set_flag(str(p["flag"]))
	if p.has("item"):
		st.gain_item(str(p["item"]), 1, st.party[0])


## Walks out through `exit`: it must be open now.
func _exit(exit: String) -> void:
	var e := _entry("exits", "id", exit)
	assert_true(not e.is_empty() and _holds(e.get("when")), "%s: the exit %s is open (%s)" % [st.location, exit, e.get("locked_text", "")])
	if e.is_empty():
		return
	if str(e["to"]) == "travel":
		st.location = "travel"
		return
	var target: String = Campaign.module().exit_target(st, st.location, str(e["to"]))
	_arrive(target)
	if target == CrookedMoonCampaign.limbo_place():
		# The first crossing into a car the party has not been in goes through the mist between cars, and out of it into that car.
		var out := _entry("exits", "id", "onward")
		assert_true(not out.is_empty() and _holds(out.get("when")), "the mist has a way on")
		_arrive(Campaign.module().exit_target(st, st.location, str(out["to"])))


## Whether `exit` of `car` would open now, wherever the party stands.
func _exit_open_at(car: String, exit: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", car).get("exits", []):
		if str((e as Dictionary)["id"]) == exit:
			return _holds((e as Dictionary).get("when"))
	fail("%s has no exit %s" % [car, exit])
	return false


func _stage() -> String:
	return st.quest_stage("ghostlight_express")


## The party has boarded and the Phantom has been dealt with and the Vagrant has explained the haints (the flags that opening leaves),
## so the cars' doors are open and the haints can be met.
func _after_phantom() -> void:
	for f: String in ["gl_boarded", "gl_aboard_welcomed", "gl_phantom_done", "gl_vagrant_briefed"]:
		st.set_flag(f)
	st.set_quest_stage("ghostlight_express", "phantom_struck")
	_arrive("ghostlight_g1_passenger")


## The train has crashed and the party stands at the wreck, as the Tender's last conversation leaves them.
func _at_the_wreck() -> void:
	for f: String in ["gl_boarded", "gl_aboard_welcomed", "gl_phantom_done", "gl_vagrant_briefed", "gl_crashed", "gl_tender_opened"]:
		st.set_flag(f)
	st.set_quest_stage("ghostlight_express", "crashed")
	_arrive(WRECK)


## The grille in the car you stand in (its recount counts any haint a fight ended since the last one).
func _grille() -> void:
	_use("grille_" + st.location.get_slice("_", 1))


## A playthrough seed per distinct car order that puts `car` last of the six middle cars (just before the Tender).
func _seeds_with_last_car(car: String, count: int) -> Array[int]:
	var out: Array[int] = []
	var seen: Array[String] = []
	for candidate: int in 100000:
		var chain := CrookedMoonCampaign.switcheroo_chain(candidate)
		if chain[chain.size() - 2] == car and not seen.has(str(chain)):
			seen.append(str(chain))
			out.append(candidate)
			if out.size() == count:
				break
	return out


## Finds a tester seed for the reading: one that deals The Fool to some hero (`fool`), or to none.
func _seed_for_reading(fool: bool) -> int:
	var slots := ReadingDeck.hero_slots(GAME.NEW_GAME_PARTY.size())
	for candidate: int in 100000:
		if ReadingDeck.draw(slots, candidate).values().has("the_fool") == fool:
			return candidate
	return -1


func _car(haint: String) -> String:
	return str(CAR_OF[haint])


# --- Getting each haint's token and a bottle -----------------------------------------------------------------------------------


## Gets the token for `haint` where the car it lies in keeps it (the party ends in that car).
func _get_token(haint: String) -> void:
	match haint:
		"sweetheart":
			_arrive("ghostlight_g5_mail")
			_search("g5_pink_envelope")
		"songstress":
			_arrive("ghostlight_g2_sleeper")
			_use("g2_phonograph", ["Carry it with us"])
		"daydreamer":
			_arrive("ghostlight_g7_circus")
			_search("g7_marionette_chest")
		"mariner":
			_arrive("ghostlight_g3_lounge")
			_search("g3_seascape")
		"jailbird":
			_arrive("ghostlight_g4_dining")
			_use("g4_booth_n1", ["Steak and eggs", "Get up"])
		"harlequin":
			_arrive("ghostlight_g6_baggage")
			var tried := _ring_check()
			assert_true(bool(tried["success"]), "the ring comes off a sleeping tail on a high roll")


## The Sleight of Hand check on the sleeping tiger's ring, rolled and applied as LocationChecks does (WorldChecks.attempt, then the
## outcome). {success, hurt}.
func _ring_check() -> Dictionary:
	var prop := _entry("props", "id", "g6_iron_ring")
	var check := WorldChecks.find(prop, "g6_iron_ring")
	assert_true(not check.is_empty() and WorldChecks.open(st, st.location, check), "the ring can be tried for")
	var res := WorldChecks.attempt(st, st.location, check, dice)
	assert_true(not res.is_empty(), "someone rolls it")
	var success := bool(res["success"])
	var applied := WorldChecks.apply(st, check["success" if success else "failure"] as Dictionary, res["who"] as Character, dice, "the ring")
	return {"success": success, "hurt": applied["hurt"]}


## Resolves `haint` (the party stands in its car) by `route`: "help" (three wins), "bottle", "destroy" (a fight, won) or "token"
## (taken from where it lies first, which moves the party). Returns the conversation's end.
func _resolve(haint: String, route: String) -> void:
	match route:
		"token":
			_get_token(haint)
			_arrive(_car(haint))
			_talk("haint_" + haint, [str(TOKEN_OPTION[haint])])
		"help":
			var picks: Array[String] = [str(HELP_OPTION[haint])]
			picks.append_array(_strs(APPROACHES[haint]))
			_talk("haint_" + haint, picks)
		"bottle":
			st.gain_item("marble_jar", 1, st.party[0])
			_talk("haint_" + haint, [str(BOTTLE_OPTION[haint])])
		"destroy":
			_talk("haint_" + haint, ["Draw a weapon"])
		_:
			fail("no route %s" % route)


## What a resolved haint leaves: its done (or destroyed) flag, its quest stage, how it ended and the running counts.
func _assert_gone(haint: String, how: String, stage: String, resolved: int, destroyed: int) -> void:
	var flag := "haint_%s_%s" % [haint, "destroyed" if stage == "destroyed" else "done"]
	assert_true(bool(st.get_flag(flag)), "the %s is gone (%s)" % [haint, flag])
	assert_eq(st.quest_stage("haint_" + haint), stage, "the %s's quest" % haint)
	if how != "":
		assert_eq(st.get_flag("haint_%s_how" % haint), how, "the %s went by %s" % [haint, how])
	assert_eq(st.get_flag("haints_resolved"), resolved, "%d haints resolved after the %s" % [resolved, haint])
	assert_eq(st.get_flag("haints_destroyed"), destroyed, "%d haints destroyed after the %s" % [destroyed, haint])


# --- (1) Other car orders ------------------------------------------------------------------------------------------------------


## Walks the cars rear to front for each of two seeds that put `last` last of the middle cars: out through every front door (each open
## but the last car's, which stays shut for the Tender while any haint is left, and says why), then back down the train by the
## rear doors, resolving the haint of every car (help, a fight and a bottle in turn, so the last car's haint is not always the same
## kind), and forward again once the sixth is gone: the last car's front door now opens on the Tender.
func _walk_with_last_car(last: String) -> void:
	var routes: Array[String] = ["help", "destroy", "bottle"]
	var seeds := _seeds_with_last_car(last, 2)
	assert_eq(seeds.size(), 2, "two different car orders end with %s" % last)
	for n in seeds.size():
		_fresh()
		st.playthrough_seed = seeds[n]
		var chain := CrookedMoonCampaign.switcheroo_chain(seeds[n])
		assert_eq(chain[6], last, "seed %d puts %s last" % [seeds[n], last])
		_after_phantom()
		for i in 6:
			_exit("front_door")
			assert_eq(st.location, chain[i + 1], "seed %d: the front door of %s leads to %s" % [seeds[n], chain[i], chain[i + 1]])
		var door := _entry("exits", "id", "front_door")
		assert_true(not _holds(door.get("when")), "seed %d: %s's front door is shut with no haint gone" % [seeds[n], last])
		assert_true(str(door.get("locked_text", "")) != "", "and says why")
		for k in range(6, 0, -1):
			assert_eq(st.location, chain[k])
			var haint: String = ""
			for h: String in HAINTS:
				if _car(h) == chain[k]:
					haint = h
			_resolve(haint, routes[(k + n) % 3])
			_grille()
			if k > 1:
				assert_true(not _exit_open_at(last, "front_door"), "seed %d: still shut with %d haints left" % [seeds[n], k - 1])
				_exit("rear_door")
				assert_eq(st.location, chain[k - 1], "the rear door of %s leads back to %s" % [chain[k], chain[k - 1]])
		assert_true(_exit_open_at(last, "front_door"), "seed %d: %s's door opens with all six gone" % [seeds[n], last])
		assert_eq(_stage(), "tender_open", "the Tender is unsealed")
		for i in range(1, 7):
			_exit("front_door")
			assert_eq(st.location, chain[i + 1])
		assert_eq(st.location, TENDER, "seed %d: the last car's front door opens on the Tender" % seeds[n])


func test_the_walk_with_the_sleeper_car_last() -> void:
	_walk_with_last_car("ghostlight_g2_sleeper")


func test_the_walk_with_the_lounge_car_last() -> void:
	_walk_with_last_car("ghostlight_g3_lounge")


func test_the_walk_with_the_dining_car_last() -> void:
	_walk_with_last_car("ghostlight_g4_dining")


func test_the_walk_with_the_mail_car_last() -> void:
	_walk_with_last_car("ghostlight_g5_mail")


func test_the_walk_with_the_baggage_car_last() -> void:
	_walk_with_last_car("ghostlight_g6_baggage")


func test_the_walk_with_the_circus_car_last() -> void:
	_walk_with_last_car("ghostlight_g7_circus")


# --- (2) The four routes, the hostile ones, the Tender's fuel --------------------------------------------------------------------


func test_every_haint_is_freed_by_its_token() -> void:
	_after_phantom()
	var done := 0
	for h: String in HAINTS:
		var item := str(TOKEN_ITEM[h])
		assert_true(not st.party_has_item(item), "no %s yet" % item)
		_get_token(h)
		assert_true(st.party_has_item(item), "the %s's token (%s) is found" % [h, item])
		_arrive(_car(h))
		_talk("haint_" + h, [str(TOKEN_OPTION[h])])
		done += 1
		_assert_gone(h, "token", "token", done, 0)
		assert_true(not st.party_has_item(item), "the token is given up")
	assert_true(bool(st.get_flag("haints_all_gone")), "six tokens clear the train")
	assert_true(fights.is_empty(), "no fights")


func test_every_haint_is_helped_by_three_successes() -> void:
	_after_phantom()
	var done := 0
	for h: String in HAINTS:
		_arrive(_car(h))
		_resolve(h, "help")
		done += 1
		assert_eq(st.get_flag("haint_%s_wins" % h), 3, "the %s took three wins" % h)
		assert_true(not bool(st.get_flag("haint_%s_fails" % h)), "and no misses")
		_assert_gone(h, "helped", "helped", done, 0)
	assert_true(fights.is_empty(), "no fights")


## Two wins leave a haint where it is; the third frees it.
func test_two_successes_are_not_enough() -> void:
	_after_phantom()
	_arrive(_car("songstress"))
	var picks: Array[String] = [str(HELP_OPTION["songstress"]), "Sing the melody", "Trace the magic", "Step back"]
	_talk("haint_songstress", picks)
	assert_eq(st.get_flag("haint_songstress_wins"), 2)
	assert_true(not bool(st.get_flag("haint_songstress_done")), "two wins do not free her")
	assert_eq(st.quest_stage("haint_songstress"), "met")
	_talk("haint_songstress", ["help you finish", "Speak the lonely word"])
	assert_eq(st.quest_stage("haint_songstress"), "helped", "the third does")


func test_every_haint_can_be_bottled() -> void:
	_after_phantom()
	_search("g1_marble_jar")
	assert_true(st.party_has_item("marble_jar"), "the marble jar is found")
	var done := 0
	for h: String in HAINTS:
		_arrive(_car(h))
		var glass := "marble_jar"
		if h == "harlequin":
			# The last one goes into the Lounge's empty bottle, and no jar is left over.
			_arrive("ghostlight_g3_lounge")
			_search("g3_whiskey_bottle")
			_arrive(_car(h))
			glass = "empty_whiskey_bottle"
		elif done > 0:
			st.gain_item("marble_jar", 1, st.party[0])
		_talk("haint_" + h, [str(BOTTLE_OPTION[h])])
		done += 1
		assert_true(st.party_has_item("bottled_haint_" + h), "the %s is carried in a bottle" % h)
		assert_true(not st.party_has_item(glass), "the %s was used up" % glass)
		assert_eq(st.get_flag("gl_bottled"), done, "%d bottled" % done)
		_assert_gone(h, "bottled", "bottled", done, 0)
	assert_true(fights.is_empty(), "no fights")


func test_every_haint_can_be_put_down() -> void:
	_after_phantom()
	var done := 0
	for h: String in HAINTS:
		_arrive(_car(h))
		_talk("haint_" + h, ["Draw a weapon"], false)
		assert_eq(st.quest_stage("haint_" + h), "hostile", "striking the %s first makes it hostile" % h)
		_win("gl_haint_" + h)
		_grille()
		done += 1
		assert_eq(fights[fights.size() - 1], "gl_haint_" + h)
		_assert_gone(h, "", "destroyed", done, done)
		assert_true(not bool(st.get_flag("haint_%s_done" % h)), "a destroyed haint is not 'done'")
	assert_true(bool(st.get_flag("haints_all_gone")), "six fights clear the train as well")


func test_three_failures_turn_a_haint_hostile() -> void:
	_after_phantom()
	dice = LowDice.new()
	for h: String in HAINTS:
		_arrive(_car(h))
		var picks: Array[String] = [str(HELP_OPTION[h])]
		picks.append_array(_strs(APPROACHES[h]))
		var ended := _talk("haint_" + h, picks, false)
		assert_eq(str(ended.get("combat", "")), "gl_haint_" + h, "three misses start the %s's fight" % h)
		assert_eq(st.get_flag("haint_%s_fails" % h), 3, "three misses")
		assert_true(not bool(st.get_flag("haint_%s_wins" % h)), "no wins")
		assert_true(bool(st.get_flag("haint_%s_hostile" % h)), "the %s is hostile" % h)
		assert_eq(st.quest_stage("haint_" + h), "hostile")
		assert_true(not bool(st.get_flag("haint_%s_done" % h)), "not freed")
		_win("gl_haint_" + h)
		assert_eq(st.quest_stage("haint_" + h), "destroyed", "and put down")
		assert_true(bool(st.get_flag("haint_%s_destroyed" % h)))
		assert_true(not bool(st.get_flag("told_haints_soul_coal")), "talking is not telling")


func test_telling_a_haint_about_the_coal_turns_it_hostile() -> void:
	_after_phantom()
	var done := 0
	for h: String in HAINTS:
		_arrive(_car(h))
		assert_true(not bool(st.get_flag("told_haints_soul_coal")), "nobody has been told before the %s" % h)
		var ended := _talk("haint_" + h, ["fuel"], false)
		assert_eq(str(ended.get("combat", "")), "gl_haint_" + h, "the truth about the coal starts the %s's fight" % h)
		assert_true(bool(st.get_flag("told_haints_soul_coal")), "the %s was told" % h)
		assert_true(bool(st.get_flag("haint_%s_hostile" % h)))
		assert_eq(st.quest_stage("haint_" + h), "hostile")
		_win("gl_haint_" + h)
		_grille()
		done += 1
		_assert_gone(h, "", "destroyed", done, done)
		# The flag is the Druskenvalds' memory of it; each haint is told in turn here, so clear it for the next.
		st.set_flag("told_haints_soul_coal", false)


## The Tender's Corrupted Fuel reads haints_destroyed: 5 + 2 for each haint put down, whichever way the rest went.
func test_the_tenders_corrupted_fuel_grows_with_each_haint_destroyed() -> void:
	for destroyed: int in [0, 2, 6]:
		_fresh()
		_after_phantom()
		for i in HAINTS.size():
			_arrive(_car(HAINTS[i]))
			_resolve(HAINTS[i], "destroy" if i < destroyed else ("help" if i % 2 == 0 else "bottle"))
		_arrive(TENDER)
		_called_by("g8_firebox")
		assert_true(fights.has("gl_stoker"), "the Stoker fights")
		assert_eq(st.get_flag("haints_destroyed"), destroyed, "%d haints put down are counted before the Stoker's fight" % destroyed)
		assert_eq(st.get_flag("haints_resolved"), 6)
		var versions := 0
		for e: Variant in _loc().get("encounters", []):
			var spec := e as Dictionary
			if str(spec["id"]) != "gl_stoker":
				continue
			versions += 1
			var events := LocationFights.round_events_for(st, spec)
			assert_eq(events.size(), 1, "one round event")
			var ev := events[0] as Dictionary
			assert_eq(str(ev["id"]), "corrupted_fuel")
			assert_eq(int((ev["save"] as Dictionary)["dc"]), 5 + 2 * destroyed, "Corrupted Fuel's DC with %d put down" % destroyed)
			assert_eq(int(ev["at"]), 20, "at initiative 20")
		assert_eq(versions, 2, "both versions of the Stoker's fight read it")


# --- (3) The wildpyre ----------------------------------------------------------------------------------------------------------


func test_a_failed_ring_check_wakes_the_wildpyre_and_its_ring_is_left_for_the_harlequin() -> void:
	_after_phantom()
	_arrive("ghostlight_g6_baggage")
	var woken_fight := {}
	for e: Variant in _loc().get("encounters", []):
		if str((e as Dictionary)["id"]) == "gl_wildpyre":
			woken_fight = e as Dictionary
	assert_eq(str(woken_fight.get("trigger", "")), "flag:wildpyre_woken", "waking it starts gl_wildpyre")
	assert_true(_holds(_entry("props", "id", "g6_tiger").get("when")), "the tiger sleeps in the car")
	assert_true(not _holds(_entry("props", "id", "g6_iron_ring_loose").get("when")), "no loose ring while it sleeps")
	dice = LowDice.new()
	var hp_before := 0
	for ch: Character in st.party:
		hp_before += ch.hp
	var tried := _ring_check()
	assert_true(not bool(tried["success"]), "the ring check fails on low dice")
	assert_true(not (tried["hurt"] as Dictionary).is_empty(), "the flames burn whoever tried")
	var hp_after := 0
	for ch: Character in st.party:
		hp_after += ch.hp
	assert_true(hp_after < hp_before, "and it costs hit points")
	assert_true(bool(st.get_flag("wildpyre_woken")), "the tiger wakes")
	assert_true(not st.party_has_item("wildpyre_iron_ring"), "the ring stays on its tail")
	var prop := _entry("props", "id", "g6_iron_ring")
	assert_true(WorldChecks.open_checks(st, st.location, prop).is_empty(), "and the check is spent")
	# The fight the flag starts, won.
	_win("gl_wildpyre")
	assert_true(bool(st.get_flag("wildpyre_destroyed")), "the wildpyre falls")
	assert_true(not _holds(_entry("npcs", "npc", "wildpyre").get("when")), "it is gone from the car")
	assert_true(not _holds(_entry("props", "id", "g6_tiger").get("when")), "and so is the sleeping tiger")
	var loose := _entry("props", "id", "g6_iron_ring_loose")
	assert_true(_holds(loose.get("when")), "the ring lies in the cinders")
	_take("g6_iron_ring_loose")
	assert_true(st.party_has_item("wildpyre_iron_ring"), "the ring is picked up")
	assert_true(not _holds(loose.get("when")), "and is not offered twice")
	# The Harlequin accepts it as she would the one lifted off the tail.
	dice = HighDice.new()
	_arrive("ghostlight_g7_circus")
	_talk("haint_harlequin", ["iron ring"])
	assert_eq(st.quest_stage("haint_harlequin"), "token")
	assert_eq(st.get_flag("haint_harlequin_how"), "token")
	assert_true(not st.party_has_item("wildpyre_iron_ring"), "she keeps it")


func test_lifting_the_ring_cleanly_leaves_the_tiger_asleep() -> void:
	_after_phantom()
	_arrive("ghostlight_g6_baggage")
	var tried := _ring_check()
	assert_true(bool(tried["success"]), "a high roll slips the ring off")
	assert_true(st.party_has_item("wildpyre_iron_ring"), "the ring is in hand")
	assert_true(not bool(st.get_flag("wildpyre_woken")), "the tiger sleeps on")
	assert_true(not _holds(_entry("props", "id", "g6_iron_ring_loose").get("when")), "nothing lies loose")


# --- (4) and (5) The wreck: walking away and refusing to search --------------------------------------------------------------------


func test_walking_away_from_the_wreck_wakes_the_engine_at_the_edge() -> void:
	_at_the_wreck()
	var rims := ["wr_rim_w", "wr_rim_n", "wr_rim_s"]
	for rim: String in rims:
		var p := _entry("props", "id", rim)
		assert_true(not _holds(p.get("call_when")), "%s keeps quiet before the Vagrant has been met" % rim)
	_talk("the_vagrant", ["We'll go now"])
	assert_true(bool(st.get_flag("gl_wreck_met")), "the Vagrant has been met")
	assert_eq(_stage(), "soul_cans")
	for rim: String in rims:
		assert_true(_holds(_entry("props", "id", rim).get("call_when")), "%s calls out now" % rim)
	# Backing off at the rim: no fight.
	var stayed := _called_by("wr_rim_n", ["Stay", "We'll go now"])
	assert_eq(str(stayed.get("combat", "")), "", "staying starts nothing")
	assert_true(not bool(st.get_flag("abandoned_wreck")))
	assert_eq(_stage(), "soul_cans")
	# Leaving anyway.
	var left := _called_by("wr_rim_w", ["Leave anyway"], false)
	assert_eq(str(left.get("combat", "")), "gl_locomotive_edge", "the engine comes for the party")
	assert_true(bool(st.get_flag("abandoned_wreck")), "the wreck is abandoned")
	assert_eq(_stage(), "locomotive", "the quest moves to the locomotive")
	_win("gl_locomotive_edge")
	assert_true(bool(st.get_flag("gl_locomotive_done")), "the fight ends the engine")
	assert_eq(_stage(), "last_stop", "and the Express reaches its last stop")
	for rim: String in rims:
		assert_true(not _holds(_entry("props", "id", rim).get("call_when")), "%s is quiet again" % rim)


func test_refusing_to_search_has_the_druskenvalds_fetch_the_cans() -> void:
	_at_the_wreck()
	var can_props := ["wr_soul_can_1", "wr_soul_can_2", "wr_soul_can_3"]
	for can: String in can_props:
		assert_true(_holds(_entry("props", "id", can).get("when")), "%s lies in the brush" % can)
	var before := st.total_minutes()
	var ended := _talk("the_vagrant", ["We're not doing this", "Ready. Do it."], false)
	assert_true(bool(st.get_flag("gl_cans_by_druskenvalds")), "the Lord and Lady go")
	for i: int in [1, 2, 3]:
		assert_true(bool(st.get_flag("gl_can_%d_found" % i)), "Soul Can %d is counted" % i)
	assert_true(st.total_minutes() - before >= 30, "and half an hour passes")
	assert_eq(st.get_flag("gl_cans_have"), 3, "three cans in hand")
	assert_eq(_stage(), "locomotive", "the engine is next")
	assert_eq(str(ended.get("combat", "")), "gl_locomotive", "and the party is ready for it")
	for can: String in can_props:
		assert_true(not _holds(_entry("props", "id", can).get("when")), "%s can no longer be searched for" % can)
	_win("gl_locomotive")
	assert_eq(_stage(), "last_stop")


# --- (6) The Fated Tarot ------------------------------------------------------------------------------------------------------


func _assert_every_hero_has_a_card() -> void:
	var seen: Array[String] = []
	var ids: Array[String] = []
	for c: Dictionary in ReadingDeck.cards():
		ids.append(str(c["id"]))
	for i in GAME.NEW_GAME_PARTY.size():
		var card := str(st.get_flag("tarot_hero_%d" % (i + 1), ""))
		assert_true(ids.has(card), "hero %d holds a card of the deck (%s)" % [i + 1, card])
		assert_true(not seen.has(card), "no card twice (%s)" % card)
		seen.append(card)
		assert_eq(str(st.tarokka.get("hero_%d" % (i + 1), "")), card, "the flag and the draw agree for hero %d" % (i + 1))
	assert_true(bool(st.get_flag("tarot_full_reading")), "the reading is done")


func test_after_the_reading_every_hero_has_a_card_and_the_fool_reveals_the_whistle() -> void:
	st.playthrough_seed = _seed_for_reading(true)
	assert_true(st.playthrough_seed >= 0, "some seed deals The Fool")
	_after_phantom()
	_arrive("ghostlight_g3_lounge")
	_talk("phillip_druskenvald", ["tarot", "deal the cards"])
	_assert_every_hero_has_a_card()
	var fool_holders: Array[int] = []
	for i in GAME.NEW_GAME_PARTY.size():
		if str(st.get_flag("tarot_hero_%d" % (i + 1), "")) == "the_fool":
			fool_holders.append(i + 1)
	assert_eq(fool_holders.size(), 1, "one hero holds The Fool")
	assert_true((Campaign.module().treasures_at(WRECK, st) as Array).has("the_fool"), "the wreck keeps The Fool's prize")
	_at_the_wreck()
	var whistle := _entry("props", "id", "wr_whistle")
	assert_true(not _holds(whistle.get("when")), "the whistle waits until the danger there has passed")
	st.set_flag("gl_locomotive_done")
	assert_true(_holds(whistle.get("when")), "then it shows at the wreck")
	_search("wr_whistle")
	assert_true(st.party_has_item("whistle_of_the_vagrant"), "the Whistle of the Vagrant is found")


func test_without_the_fool_the_wreck_keeps_no_whistle() -> void:
	st.playthrough_seed = _seed_for_reading(false)
	_after_phantom()
	_arrive("ghostlight_g3_lounge")
	_talk("phillip_druskenvald", ["tarot", "deal the cards"])
	_assert_every_hero_has_a_card()
	_at_the_wreck()
	assert_true(not _holds(_entry("props", "id", "wr_whistle").get("when")), "no whistle in the mud")


## The reading put off in the Lounge is Adela's insistence at the wreck, and The Fool's whistle is there all the same.
func test_a_reading_put_off_is_given_at_the_wreck() -> void:
	st.playthrough_seed = _seed_for_reading(true)
	_after_phantom()
	_arrive("ghostlight_g3_lounge")
	_talk("phillip_druskenvald", ["tarot", "Later"])
	assert_true(bool(st.get_flag("gl_reading_deferred")), "the reading is put off")
	assert_true(not bool(st.get_flag("tarot_full_reading")), "nothing is dealt yet")
	assert_true(st.tarokka.is_empty(), "the cards are still in the deck")
	_at_the_wreck()
	_talk("the_vagrant")
	_assert_every_hero_has_a_card()
	st.set_flag("gl_locomotive_done")
	_search("wr_whistle")
	assert_true(st.party_has_item("whistle_of_the_vagrant"), "the Whistle of the Vagrant is found")


# --- (7) Levels ---------------------------------------------------------------------------------------------------------------


## The first milestone: the third haint gone, the party may advance to level 2; no more for the other three.
func test_a_milestone_comes_with_the_third_haint() -> void:
	_after_phantom()
	assert_eq(st.milestones, 0)
	assert_eq(st.target_level(), 1)
	for i in HAINTS.size():
		_arrive(_car(HAINTS[i]))
		_resolve(HAINTS[i], "help")
		var want := 0 if i < 2 else 1
		assert_eq(st.milestones, want, "%d haints gone: %d milestones" % [i + 1, want])
		assert_eq(st.target_level(), 1 + want, "and the party may reach level %d" % (1 + want))
	assert_true(bool(st.get_flag("gl_level2_given")))


## The same milestone when fights ended the haints (nothing but the grille or the Tender recounts them).
func test_a_milestone_comes_with_the_third_haint_put_down_in_a_fight() -> void:
	_after_phantom()
	for i in 3:
		_arrive(_car(HAINTS[i]))
		_resolve(HAINTS[i], "destroy")
		_grille()
	assert_eq(st.get_flag("haints_resolved"), 3)
	assert_eq(st.milestones, 1, "three haints put down earn the level 2 milestone at the grille")
	assert_eq(st.target_level(), 2)


## Fights never recount through the Vagrant's router, so the Tender's own recount has to pay the level 2 milestone: the party stands at
## level 2 when the Stoker's fight begins, and at level 3 after the crash. (Reads the fix to haint_common:recount that act1-audit's
## coordinator made; it fails on a lane without it.)
func _fights_then_tender(routes: Array[String]) -> void:
	_after_phantom()
	for i in HAINTS.size():
		_arrive(_car(HAINTS[i]))
		_resolve(HAINTS[i], routes[i])
	_arrive(TENDER)
	var opened := _called_by("g8_firebox", [], false)
	assert_eq(str(opened.get("combat", "")), "gl_stoker", "the Stoker is next")
	assert_eq(st.get_flag("haints_resolved"), 6)
	assert_eq(st.milestones, 1, "level 2 is paid before the Stoker's fight begins")
	assert_eq(st.target_level(), 2)
	_win("gl_stoker")
	_called_by("g8_tank")
	assert_eq(st.location, WRECK, "the train crashes")
	assert_eq(st.milestones, 2, "and the crash pays level 3")
	assert_eq(st.target_level(), 3)


func test_the_milestone_is_not_lost_when_every_haint_is_put_down_in_a_fight() -> void:
	_fights_then_tender(["destroy", "destroy", "destroy", "destroy", "destroy", "destroy"])


func test_the_milestone_is_not_lost_with_two_tokens_and_four_fights() -> void:
	_fights_then_tender(["token", "token", "destroy", "destroy", "destroy", "destroy"])


## The second milestone: the crash.
func test_a_milestone_comes_with_the_crash() -> void:
	_after_phantom()
	for h: String in HAINTS:
		_arrive(_car(h))
		_resolve(h, "help")
	assert_eq(st.milestones, 1, "one milestone before the Tender")
	_arrive(TENDER)
	_called_by("g8_firebox")
	assert_eq(_stage(), "crashed", "the Stoker's fall moves the quest")
	assert_eq(st.milestones, 1, "the fuel fight pays nothing by itself")
	_called_by("g8_tank")
	assert_eq(st.location, WRECK, "the train crashes in the woods")
	assert_true(bool(st.get_flag("gl_level3_given")))
	assert_eq(st.milestones, 2, "two milestones at the crash")
	assert_eq(st.target_level(), 3, "level 3, before the boss (the book's count)")
	# The crash is only paid once.
	_play("ghostlight_express/tender:crash")
	assert_eq(st.milestones, 2, "a second crash scene pays nothing more")
