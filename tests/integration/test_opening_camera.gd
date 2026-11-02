extends TestCase
## A new game's opening room (the Ghostlight boarding hill, after the Calls to Adventure): the play camera follows the
## party's leader as they walk about, with the motion of play on (the covers, the conversation's camera).

const GAME := preload("res://world/game_root.gd")

var st: StoryState
var root: Node


func before_each() -> void:
	GameState.reset()
	st = GameState.story
	for id: String in Pregens.roster_ids().slice(0, StoryState.PARTY_CAP):   # the title's party, as it starts picked
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = ""   # a new game: the opening plays
	UiMotion.on()
	UiMotion.reduced = false


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		await get_tree().process_frame
	UiMotion.reduced = true
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Moves every conversation on until none is open and the place has settled.
func _talk_through() -> void:
	var quiet := 0
	for i in 4000:
		await get_tree().process_frame
		var d: Variant = root.get("dialogue")
		if d == null:
			quiet += 1
			if quiet > 30 and root.get("view") != null and not bool(root.get("moving")):
				return
			continue
		quiet = 0
		var ui := d as DialogueUI
		if i % 3 != 0:
			continue
		if not ui.options_shown.is_empty():
			ui._choose(ui.options_shown.size() - 1)
		else:
			ui.skip_cutscene()
			ui._advance()


## Walks the leader a few squares one way or another; true if a walk started.
func _walk_somewhere(view: LocationView) -> bool:
	for r in range(5, 1, -1):
		for dir: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			if view.walk_to(view.leader().cell + dir):
				return true
	return false


func test_the_camera_follows_the_leader_round_the_boarding_hill() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _talk_through()   # the Calls to Adventure
	var view := root.get("view") as LocationView
	assert_eq(view.loc_id, "ghostlight_boarding", "the opening ends on the boarding hill")
	# The Vagrant has had his word (he calls the party over at the first step otherwise).
	(st.loc_state(view.loc_id)["props"] as Dictionary)["approach:the_vagrant:ghostlight_express/vagrant_boarding:boarding"] = true
	var lead := view.tokens[view.leader().id] as Node3D
	assert_true(view.rig.follow == lead, "the camera follows the leader")
	for i in 4:
		var walked_from := lead.global_position
		var cam_from := view.rig.camera.global_position
		assert_true(_walk_somewhere(view), "the leader walks")
		for f in 400:
			await get_tree().process_frame
			if lead.global_position.distance_to(view.rig.global_position) < 0.05 and view._queue.is_empty() and view._glides.is_empty():
				break
		var moved := lead.global_position - walked_from
		var cam_moved := view.rig.camera.global_position - cam_from
		assert_true(Vector2(moved.x, moved.z).length() > 0.9, "the leader went somewhere (%s)" % moved)
		assert_true(Vector2(cam_moved.x - moved.x, cam_moved.z - moved.z).length() < 0.5,
			"the camera went with them (leader %s, camera %s)" % [moved, cam_moved])
