extends Node
## The new-player guide (NewPlayerGuide) on screen: its cards over the hero creator's first two steps, then over the
## hillside test fight, one shot per fight card with what it points at.
##   make capture SCENE=res://tools/capture/guide_capture.tscn NAME=guide/a FRAMES=10
## Shots: <out>_creator_class.png, <out>_creator_origin.png, <out>_fight_<card>.png. Nothing it changes is kept.

const GAME := preload("res://world/game_root.gd")


func capture_shots(tool: Node, out: String) -> void:
	NewPlayerGuide.keep = false
	NewPlayerGuide.set_enabled(true)
	var screen := CreationScreen.new()
	add_child(screen)
	screen.open_hero([] as Array[String])
	var g := CreatorGuide.attach(screen)
	await tool.call("wait_frames", 40)
	tool.call("_shot", "%s_creator_class.png" % out)
	screen.b().set_class("fighter")
	await tool.call("wait_frames", 10)
	g._next()
	await tool.call("wait_frames", 30)
	tool.call("_shot", "%s_creator_origin.png" % out)
	screen.queue_free()
	await tool.call("wait_frames", 5)

	GameState.reset()
	var st := GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = "test_hillside"
	st.options[NewPlayerGuide.OPTION] = true
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	for n in game.get_children():
		if n is CanvasLayer and n.name.begins_with("Place"):
			n.visible = false
	var view := game.get("view") as LocationView
	view.start_encounter("hillside_scarecrows")
	var cv := view.combat_view
	cv.input_locked = true
	for i in 2400:
		await tool.call("wait_frames", 1)
		if cv.mode == CombatView.Mode.IDLE and cv.e.current() != null and cv.e.current().is_player_controlled():
			break
	var guide := game.find_children("*", "FightGuide", true, false)[0] as FightGuide
	await tool.call("wait_frames", 30)
	for i in FightGuide.CARDS.size():
		guide._present(i)
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s_fight_%s.png" % [out, str(FightGuide.CARDS[i]["id"])])
	NewPlayerGuide.keep = true
