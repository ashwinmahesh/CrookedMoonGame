extends TestCase
## The Ghostlight Locomotive's fight at the wreck, begun the way the game begins it (package R10 section 10.3, decision
## 15): the Soul Cans lie on the three can squares, drawn on the board, a bottled haint's jar standing in for one, and the
## engine goes for them.

const LOC := "ghostlight_wreckage"
const GAME := preload("res://world/game_root.gd")
const CAN_SQUARES := [Vector2i(7, 7), Vector2i(26, 7), Vector2i(23, 19)]

var root: Node
var st: StoryState


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOC
	Dice.reseed(7)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _start(fight: String = "gl_locomotive") -> Encounter:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter(fight), "the fight starts")
	await _frames(6)
	return view.combat_view.e


static func _fuel(e: Encounter) -> Array[BattleObject]:
	var out: Array[BattleObject] = []
	for o in e.objects.list:
		if o.fuel == "soul_can":
			out.append(o)
	return out


func test_the_cans_lie_on_their_squares_drawn_on_the_board() -> void:
	var e: Encounter = await _start()
	var cans := _fuel(e)
	assert_eq(cans.size(), 3, "three Soul Cans")
	for o in cans:
		assert_true(o.cells[0] in CAN_SQUARES, "%s on a can square: %s" % [o.id, o.cells[0]])
	var view := root.get("view") as LocationView
	for o in cans:
		assert_true(view.combat_view.objects_view.has_node("Dressing_fight_" + o.id), "%s is drawn on the board" % o.id)
	PartyAutopilot.new(e).run(3)
	assert_true(cans.any(func(o: BattleObject) -> bool: return o.destroyed), "off its bank and at a can within three rounds")


## The walk-away fight: the engine wakes in the bowl's west side. Its Spectral Rails carry its 4 x 4 body over the roots and
## soul-mist (before them it covered about 5 squares a turn and reached no can), so it gets to one and eats it.
func test_the_engine_goes_for_a_can_and_eats_it() -> void:
	var e: Encounter = await _start("gl_locomotive_edge")
	var cans := _fuel(e)
	assert_eq(cans.size(), 3, "the same three cans")
	PartyAutopilot.new(e).run(3)
	var eaten := cans.filter(func(o: BattleObject) -> bool: return o.destroyed)
	assert_false(eaten.is_empty(), "within three rounds a can is gone")
	var echoes := e.combatants.filter(func(c: Combatant) -> bool: return c.has_meta(ObjectFuel.RELEASED_META))
	assert_eq(echoes.size(), eaten.size(), "and each one let out an echo")


func test_a_bottled_haints_jar_stands_in_for_a_can() -> void:
	st.set_flag("haint_songstress_how", "bottled")
	st.set_flag("gl_bottled", 1)
	var e: Encounter = await _start()
	var ids := _fuel(e).map(func(o: BattleObject) -> String: return o.id)
	assert_eq(ids, ["soul_can_1", "soul_can_2", "jar_songstress"], "two cans and the Songstress's jar")
