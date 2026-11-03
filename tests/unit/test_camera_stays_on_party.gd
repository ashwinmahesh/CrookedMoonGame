extends TestCase
## The camera does not stop following the party (Ashwin, 2026-11-03: "the camera detachment issue happened again, multiple times,
## seems to be triggered randomly"): the rig follows a node, and a node freed under it (a token rebuilt) or a follow a fight left
## cleared used to leave it frozen where it was. Outside a fight it is pointed at the leader's token again each frame; the free
## camera (the player's own choice) is left alone.

const PLACE := "wickermoor_village"


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	GameState.reset()
	var st := GameState.story
	for pid: String in preload("res://world/game_root.gd").PLACEHOLDER_PARTY:
		st.party.append(Pregens.build(pid, 3))
	st.location = PLACE
	var view := LocationView.create(PLACE, st, Narrator.new(), Dice.roller, "default")
	add_child(view)
	return view


func test_a_freed_follow_is_picked_up_again() -> void:
	var view := _view()
	await _frames(3)
	var leader_token := view.tokens[view.leader().id] as Node3D
	assert_eq(view.rig.follow, leader_token, "it follows the leader to begin with")
	var gone := Node3D.new()
	view.add_child(gone)
	view.rig.follow = gone
	gone.free()   # the token it followed is rebuilt: the old one is freed
	await _frames(3)
	assert_eq(view.rig.follow, leader_token, "the camera follows the leader again")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_a_cleared_follow_is_picked_up_again() -> void:
	var view := _view()
	await _frames(3)
	view.rig.follow = null
	await _frames(3)
	assert_eq(view.rig.follow, view.tokens[view.leader().id], "a follow something cleared is the leader's again")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()


func test_the_camera_follows_a_new_leader_and_the_free_camera_is_left_alone() -> void:
	var view := _view()
	await _frames(3)
	view.rig.free_cam = true
	view.rig.follow = null
	await _frames(3)
	assert_true(not is_instance_valid(view.rig.follow), "the free camera stays where the player put it")
	view.rig.free_cam = false
	await _frames(3)
	assert_eq(view.rig.follow, view.tokens[view.leader().id], "and comes back to the party when it is switched off")
	view.queue_free()
	await get_tree().process_frame
	GameState.reset()
