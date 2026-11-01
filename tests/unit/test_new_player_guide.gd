extends TestCase
## The new-player guide (NewPlayerGuide; vault Build/New Player Guide.md): its cards follow the hero creator's steps and
## a new game's first fight, finish on what the player really does there, and never come back once run or turned off.


var _was_on := true
var _was_seen := false


func before_each() -> void:
	NewPlayerGuide.keep = false   # never the player's settings file
	_was_on = NewPlayerGuide.enabled()
	_was_seen = NewPlayerGuide.creator_seen()
	NewPlayerGuide.set_enabled(true)


func after_each() -> void:
	GameSettings.set_value(NewPlayerGuide.SETTING, _was_on, false)
	GameSettings.set_value(NewPlayerGuide.SEEN_CREATOR, _was_seen, false)
	NewPlayerGuide.keep = true


func _title(coach: TutorialCoach) -> String:
	return (coach.get("_title") as Label).text


func _objective(coach: TutorialCoach) -> String:
	return (coach.get("_objective") as Label).text


func test_the_creator_guide_follows_the_steps_and_says_when_one_is_done() -> void:
	var screen := CreationScreen.new()
	add_child(screen)
	screen.open_hero([] as Array[String])
	var guide := CreatorGuide.attach(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_title(guide.coach), "Your class", "the first step's card")
	assert_false(guide.coach.interaction_blocked(), "it never blocks the creator")
	screen.b().set_class("fighter")
	await get_tree().process_frame
	assert_true(_objective(guide.coach).contains("That's your hero's class"), "the card says the step is done: %s" % _objective(guide.coach))
	guide._next()
	await get_tree().process_frame
	assert_eq(screen.step, CharacterBuilder.Step.ORIGIN, "Next step moves the creator on")
	assert_eq(_title(guide.coach), "Where you come from", "and the card follows")
	screen.step = CharacterBuilder.Step.REVIEW
	screen._draw()
	await get_tree().process_frame
	assert_eq(_title(guide.coach), "Review", "a step picked from the list gets its own card")
	guide._next()
	await get_tree().process_frame
	assert_false(is_instance_valid(guide), "the last card closes the guide")
	screen.free()


func _fight() -> Dictionary:
	var rows: Array[String] = []
	for z in 6:
		rows.append("........")
	var e := Encounter.new(CombatGrid.from_rows(rows), DiceRoller.new(3))
	var hero := e.add(TestChars.dummy(20, false, {}), &"party", Vector2i(1, 1))
	var foe := e.add(TestChars.dummy(20, false, {}), &"enemy", Vector2i(4, 1))
	var view := CombatView.new()
	view.e = e
	var guide := FightGuide.new()
	add_child(guide)
	guide.view = view
	guide.coach = NewPlayerGuide.coach()
	guide.add_child(guide.coach)
	guide.coach.next_requested.connect(guide._next)
	return {"guide": guide, "view": view, "hero": hero, "foe": foe}


func _events(guide: FightGuide, events: Array) -> void:
	var typed: Array[Dictionary] = []
	typed.assign(events)
	guide._presented(typed)


func test_the_fight_guide_walks_the_first_turns_by_what_the_player_does() -> void:
	GameState.story.flags.erase(NewPlayerGuide.FIGHT_DONE)
	var f := _fight()
	var guide := f["guide"] as FightGuide
	var hero := f["hero"] as Combatant
	var foe := f["foe"] as Combatant
	_events(guide, [{"type": "turn", "id": foe.id}])
	assert_eq(guide.at, -1, "no card on a foe's turn")
	_events(guide, [{"type": "turn", "id": hero.id}])
	assert_eq(_title(guide.coach), "A fight, turn by turn", "the first card on the party's first turn")
	assert_true(guide.coach.complete, "a card to read is done at once, with Continue")
	guide._next()
	assert_eq(guide._id(), "move")
	_events(guide, [{"type": "move", "id": foe.id}])
	assert_false(guide.coach.complete, "a foe moving isn't the player moving")
	_events(guide, [{"type": "move", "id": hero.id, "undo": true}])
	assert_false(guide.coach.complete, "nor is taking a move back")
	_events(guide, [{"type": "move", "id": hero.id}])
	assert_true(guide.coach.complete, "the hero moved")
	guide._next()
	assert_eq(guide._id(), "attack")
	_events(guide, [{"type": "attack", "attacker": hero.id, "hit": false}])
	assert_true(guide.coach.complete, "an attack that missed still counts")
	guide._next()
	assert_eq(guide._id(), "shapes")
	guide._next()
	assert_eq(guide._id(), "end")
	_events(guide, [{"type": "turn", "id": foe.id}])
	assert_false(guide.coach.complete, "the foe's turn alone isn't the hero's next one")
	_events(guide, [{"type": "turn", "id": hero.id}])
	assert_true(guide.coach.complete, "the turn ended and came round again")
	guide._next()
	assert_eq(guide._id(), "log")
	guide._next()
	assert_true(bool(GameState.story.get_flag(NewPlayerGuide.FIGHT_DONE, false)), "once run, never again in this game")
	await get_tree().process_frame
	assert_false(is_instance_valid(guide), "and it goes")
	(f["view"] as CombatView).free()
	GameState.story.flags.erase(NewPlayerGuide.FIGHT_DONE)


func test_the_fight_guide_stops_when_the_fight_ends_or_it_is_turned_off() -> void:
	GameState.story.flags.erase(NewPlayerGuide.FIGHT_DONE)
	var f := _fight()
	var guide := f["guide"] as FightGuide
	_events(guide, [{"type": "turn", "id": (f["hero"] as Combatant).id}, {"type": "over", "outcome": "victory"}])
	assert_true(bool(GameState.story.get_flag(NewPlayerGuide.FIGHT_DONE, false)), "a fight won before the cards ran out ends the guide")
	(f["view"] as CombatView).free()
	GameState.story.flags.erase(NewPlayerGuide.FIGHT_DONE)
	f = _fight()
	guide = f["guide"] as FightGuide
	guide.coach.exit_requested.connect(guide._turn_off)
	guide.coach.exit_requested.emit()
	assert_false(NewPlayerGuide.enabled(), "Turn the guide off is kept for new games")
	(f["view"] as CombatView).free()
	GameState.story.flags.erase(NewPlayerGuide.FIGHT_DONE)
