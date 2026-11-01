extends TestCase
## Wickermoor's night sound comes in as the hour strikes (vault Build/Audio Plan.md, batch 3): standing in a shop at ten to
## three, the clock passing 15:00 turns the music to the village's night and the bed to the night heard through the walls,
## and 07:00 turns them back, with no change of place. A conversation keeps its own music until it ends.

const GAME := preload("res://world/game_root.gd")
const LOC := "wickermoor_shop_bakery"

var root: Node
var st: StoryState


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		st.party.append(Pregens.build(id, 3))
	st.location = LOC
	st.minute_of_day = 14 * 60 + 50
	Dice.reseed(7)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _arrive() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	assert_true(view != null and view.loc_id == LOC, "the game starts in the bakery")


func _bed() -> String:
	return str((root.get("place_beds") as PlaceBeds).bed_id)


func test_the_night_comes_in_as_the_hour_strikes() -> void:
	await _arrive()
	assert_eq(Audio.mood, "wickermoor", "ten to three: the village's day music")
	assert_eq(_bed(), "village_indoor", "and the day through the walls")
	st.advance_minutes(15)   # the walking clock's own small steps
	await _frames(3)
	assert_eq(Audio.mood, "wickermoor_night", "three o'clock: the night music, without leaving the shop")
	assert_eq(_bed(), "village_indoor_night", "and the night through the walls")
	st.minute_of_day = 6 * 60 + 55
	await _frames(3)
	assert_eq(Audio.mood, "wickermoor_night", "five to seven: still night")
	st.advance_minutes(10)
	await _frames(3)
	assert_eq(Audio.mood, "wickermoor", "seven o'clock: the day again")
	assert_eq(_bed(), "village_indoor", "and its bed")


func test_a_conversation_keeps_its_music_until_it_ends() -> void:
	await _arrive()
	root.set("dialogue", DialogueUI.new())   # stands in for an open conversation: _process holds the place's sound
	st.advance_minutes(15)
	await _frames(3)
	assert_eq(Audio.mood, "wickermoor", "no turn while someone is talking")
	(root.get("dialogue") as Node).free()
	root.set("dialogue", null)
	await _frames(3)
	assert_eq(Audio.mood, "wickermoor_night", "the night comes in once the talk is over")
