extends TestCase
## A passage that comes while the Narrator is still being heard waits for the voice to finish instead of cutting it off (Ashwin,
## 2026-11-03: "when we do a search check, it shouldn't interrupt dialogue that's ongoing").

const SPOKEN := "She is already fanning the worn deck across the table, and reckon nobody here has agreed to a thing."
const RESULT := "Nothing here but dust."


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_a_search_result_waits_for_the_line_being_said() -> void:
	GameState.reset()
	var st := GameState.story
	for pid: String in preload("res://world/game_root.gd").NEW_GAME_PARTY:
		st.party.append(Pregens.build(pid, 3))
	st.location = "ghostlight_g3_lounge"
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _frames(20)
	var hud := game.get("hud") as ExploreHud
	assert_true(VoiceOver.has_clip(VoiceOver.NARRATOR, SPOKEN), "the line has a recording")
	# This run has no audio device for VoiceOver to make its own player on, so a player is made to stand in for it.
	var speaker := AudioStreamPlayer.new()
	add_child(speaker)
	VoiceOver._player = speaker
	hud.close_narration()   # whatever the arrival said is put away first
	hud.narrate(SPOKEN)
	await _frames(3)
	assert_true(VoiceOver.is_speaking(), "the Narrator is being heard")
	hud.narrate(RESULT)   # a search's result comes in meanwhile
	await _frames(3)
	assert_true(VoiceOver.is_speaking(), "the line is not cut off")
	assert_true(str(hud.get("_narr").text).contains("fanning"), "the box still shows the line being said")
	assert_eq((hud.get("_narr_queue") as Array).size(), 1, "the result waits its turn")
	speaker.stop()   # the voice is done
	for i in 60:
		await get_tree().process_frame
		if (hud.get("_narr_queue") as Array).is_empty():
			break
	assert_true(str(hud.get("_narr").text).contains("dust"), "and is shown once the voice is done")
	VoiceOver._player = null
	speaker.queue_free()
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()
