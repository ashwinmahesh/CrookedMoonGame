extends TestCase
## R10, the Ghostlight Express, played from a new game (its party of companions) to the Wickermoor road: the opening, the boarding, the Phantom, the six
## haints (two by talking them round, one by a token, two bottled, one put down last), the Tender, the crash, the Soul Cans,
## the locomotive and the farewell. A walk over the places' own data the way the game reads it: a person is only talked to
## while their entry's `when` holds, a prop's call only fires while its `call_when` does, an exit only opens while its `when`
## does, and every conversation runs through the DialogueRunner. A fight a conversation starts is won as LocationFights
## records a victory (the place's won encounter, its flag and its quest stage); the dice always roll high, so every check lands.

const GAME := preload("res://world/game_root.gd")

## Dice that always roll the highest face: every check in a conversation lands.
class HighDice extends DiceRoller:
	func roll(sides: int, count: int = 1, reason: String = "") -> Array[int]:
		var out: Array[int] = []
		for i in count:
			out.append(sides)
		_record({"reason": reason, "sides": sides, "rolls": out.duplicate()})
		return out


var st: StoryState
var dice := HighDice.new()
var fights: Array[String] = []


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	fights.clear()
	st.playthrough_seed = _seed_for_book_order()
	GhostlightBoons.watch(st, Dice.roller)   # as the game connects it: a freed haint heals the party


func after_each() -> void:
	GameState.reset()


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


## Talks to `npc` here, as clicking them does: their entry must be on the map now.
func _talk(npc: String, picks: Array[String] = []) -> Dictionary:
	var e := _entry("npcs", "npc", npc)
	assert_true(not e.is_empty() and _holds(e.get("when")), "%s is in %s to talk to" % [npc, st.location])
	if e.is_empty() or not _holds(e.get("when")):
		return {}
	return _play(str(e["dialogue"]), picks)


## A prop's call, as walking up to it fires it (LocationNpcs._check_calls): its `when` and `call_when` must hold.
func _called_by(prop: String, picks: Array[String] = []) -> Dictionary:
	var p := _entry("props", "id", prop)
	var ok := not p.is_empty() and _holds(p.get("when")) and _holds(p.get("call_when"))
	assert_true(ok, "%s calls out in %s now" % [prop, st.location])
	if not ok:
		return {}
	return _play(str(p["call"]), picks)


## Uses a prop with a conversation of its own (a booth, a phonograph).
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
	if p.has("flag"):
		st.set_flag(str(p["flag"]))
	if p.has("item"):
		st.gain_item(str(p["item"]), 1, st.party[0])


## A playthrough seed that shuffles the six middle cars into the order this walk visits them (the book's: sleeper, lounge, dining, mail,
## baggage, circus), so the walk below can go car to car by name. The Switcheroo's own order is tested in test_ghostlight_express.
func _seed_for_book_order() -> int:
	var want := ["ghostlight_g1_passenger", "ghostlight_g2_sleeper", "ghostlight_g3_lounge", "ghostlight_g4_dining", "ghostlight_g5_mail",
		"ghostlight_g6_baggage", "ghostlight_g7_circus", "ghostlight_g8_tender"]
	for candidate: int in 100000:
		if str(CrookedMoonCampaign.switcheroo_chain(candidate)) == str(want):
			return candidate
	return 0


## Walks out through `exit`: it must be open now.
func _exit(exit: String) -> void:
	var e := _entry("exits", "id", exit)
	assert_true(not e.is_empty() and _holds(e.get("when")), "%s: the exit %s is open (%s)" % [st.location, exit, e.get("locked_text", "")])
	if e.is_empty():
		return
	if str(e["to"]) == "travel":
		st.location = "travel"
		return
	_arrive(Campaign.module().exit_target(st, st.location, str(e["to"])))


func _stage() -> String:
	return st.quest_stage("ghostlight_express")


func test_the_express_plays_from_a_new_game_to_the_wickermoor_road() -> void:
	# A new game: each hero's Call, then the hill.
	_play(GAME.OPENING)
	assert_eq(st.location, GAME.FIRST_LOCATION, "the opening ends on the hill")
	assert_eq(_stage(), "boarding")
	_talk("the_vagrant", ["fare", "Tell him something true", "Check our pockets", "ready to board"])
	assert_eq(st.location, "ghostlight_g1_passenger", "the party boards")
	assert_eq(_stage(), "aboard")

	# The Passenger Car: the Vagrant's welcome, a jar of marbles, the Phantom.
	_talk("the_vagrant", ["Go on to your cab"])
	_search("g1_marble_jar")
	_talk("phantom_trainhopper")
	assert_eq(fights, ["gl_phantom_strikes"] as Array[String])
	assert_eq(_stage(), "phantom_struck")
	_called_by("grille_g1", ["Understood"])
	assert_true(bool(st.get_flag("gl_vagrant_briefed")), "the Vagrant explains the haints")
	_exit("front_door")

	# The Sleeper Car: the Sweetheart bottled.
	_use("g2_phonograph", ["Carry it with us"])
	_talk("haint_sweetheart", ["bottle"])
	assert_eq(_stage(), "haints", "meeting a haint starts the haints stage")
	assert_eq(st.quest_stage("haint_sweetheart"), "bottled")
	assert_eq(st.party[0].temp_hp, 0, "a bottled haint heals no one")
	_exit("front_door")

	# The Lounge: the Songstress talked round; the seascape and an empty bottle found.
	_search("g3_seascape")
	_search("g3_whiskey_bottle")
	_talk("haint_songstress", ["help you finish", "Sing the melody", "Trace the magic", "Speak the lonely word"])
	assert_eq(st.quest_stage("haint_songstress"), "helped")
	for ch in st.party:
		assert_true(ch.temp_hp >= 1 and ch.temp_hp <= 6, "%s: the freed Songstress heals 1d6, all of it Temporary Hit Points at full health" % ch.name)
	_exit("front_door")

	# The Dining Car: the Daydreamer bottled; steak and eggs ordered.
	_use("g4_big_booth")
	_use("g4_booth_n1", ["Steak and eggs", "Get up"])
	_talk("haint_daydreamer", ["empty glass jar"])
	assert_eq(st.quest_stage("haint_daydreamer"), "bottled")
	_exit("front_door")

	# The Mail Car: the Mariner given his painting.
	_search("g5_pink_envelope")
	_talk("haint_mariner", ["painting"])
	assert_eq(st.quest_stage("haint_mariner"), "token")
	_exit("front_door")

	# The Baggage Car: the Jailbird talked round.
	_talk("haint_jailbird", ["talk with you", "gallows custom", "hot plate", "campfire skillets"])
	assert_eq(st.quest_stage("haint_jailbird"), "helped")
	_exit("front_door")

	# The Circus Car: the Harlequin put down, the last of the six, by a fight; nobody touches a grille after it.
	_talk("haint_harlequin", ["Draw a weapon"])
	assert_eq(st.quest_stage("haint_harlequin"), "destroyed")
	assert_true(st.flags.has(GhostlightBoons.PAID + "haint_mariner") and not st.flags.has(GhostlightBoons.PAID + "haint_harlequin"),
		"the freed Mariner paid and the haint put down did not")
	for h: String in ["sweetheart", "songstress", "daydreamer", "mariner", "jailbird", "harlequin"]:
		assert_true(bool(st.get_flag("haint_%s_done" % h)) or bool(st.get_flag("haint_%s_destroyed" % h)), "the %s is gone" % h)
	_exit("front_door")

	# The Tender: the curse in the fuel, the Stoker, the crash.
	assert_eq(st.location, "ghostlight_g8_tender")
	_called_by("g8_firebox")
	assert_eq(st.get_flag("haints_destroyed"), 1, "the haint put down is counted before the Stoker's fight")
	assert_true(fights.has("gl_stoker"), "the Stoker fights")
	assert_eq(_stage(), "crashed")
	_called_by("g8_tank")
	assert_eq(st.location, "ghostlight_wreckage", "the train crashes in the woods")
	assert_eq(_stage(), "crashed")

	# The wreck: the Vagrant's council, three Soul Cans, the locomotive.
	_talk("phillip_druskenvald")
	_talk("the_vagrant", ["hum", "We'll go now"])
	assert_eq(_stage(), "soul_cans")
	for i: int in [1, 2, 3]:
		_search("wr_soul_can_%d" % i)
		assert_true(bool(st.get_flag("gl_can_%d_found" % i)), "Soul Can %d counts once it is picked up" % i)
	_talk("the_vagrant", ["We have the cans", "Ready. Do it."])
	assert_true(fights.has("gl_locomotive"), "the locomotive fights")
	assert_eq(_stage(), "last_stop")

	# The farewell, and the road to Wickermoor.
	_called_by("wr_moon")
	assert_true(bool(st.get_flag("gl_last_stop")), "the train leaves")
	assert_true(st.quest_ended("ghostlight_express"), "the Express is over")
	_exit("to_wickermoor")
	assert_eq(st.location, "travel")


## The real game, started fresh: the quick start's companions are the party, on the hill, with the opening under way.
func test_a_new_game_starts_the_companions_on_the_hill() -> void:
	GameState.reset()
	Dice.reseed(7)
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 12:
		await get_tree().process_frame
	var ids: Array[String] = []
	for ch: Character in GameState.story.party:
		ids.append(ch.id)
	assert_eq(ids, GAME.NEW_GAME_PARTY, "a new game's party is the companions")
	var view := root.get("view") as LocationView
	assert_true(view != null and view.loc_id == GAME.FIRST_LOCATION, "a new game starts on the hill")
	assert_eq(str(root.get("_dialogue_ref")), GAME.OPENING, "the Calls to Adventure play first")
	root.queue_free()
	await get_tree().process_frame
	GameState.reset()
