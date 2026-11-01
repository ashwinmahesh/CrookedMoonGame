extends Node
## The made hero's Appearance step (vault Build/Character Creator and Layered Figures.md): the creator opened on one
## hero, the look step showing the hero as a 3D figure on its turntable, as a woman and as a man, standing, walking,
## running and swinging.
##   make capture SCENE=res://tools/capture/creator_capture.tscn NAME=creator/x FRAMES=10 ARGS='--species=curseborn --class=fighter'
## --species and --class: what the hero is (the height follows the species); --build: a build pick (slender, broad). Shots: <out>_woman.png, <out>_woman_turned.png,
## <out>_man.png, <out>_walk.png, <out>_run.png, <out>_swing.png.


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return default


func capture_shots(tool: Node, out: String) -> void:
	var screen := CreationScreen.new()
	add_child(screen)
	screen.open_hero([] as Array[String])
	var b := screen.builders[0]
	b.set_class(_arg("class", "fighter"))
	b.set_species(_arg("species", "curseborn"))
	screen.step = CharacterBuilder.Step.APPEARANCE
	screen._draw()
	await tool.call("wait_frames", 10)
	var panel := screen.find_children("*", "AppearancePanel", true, false)[0] as AppearancePanel
	if _arg("build", "") != "":
		panel._pick("build", _arg("build", ""))
		panel = screen.find_children("*", "AppearancePanel", true, false)[0] as AppearancePanel
	await tool.call("wait_frames", 50)
	tool.call("_shot", "%s_woman.png" % out)
	panel._preview.turn(3)
	await tool.call("wait_frames", 20)
	tool.call("_shot", "%s_woman_turned.png" % out)
	panel._pick("gender", "male")
	await tool.call("wait_frames", 40)
	tool.call("_shot", "%s_man.png" % out)
	panel._preview.set_mode("walk")
	await tool.call("wait_frames", 30)
	tool.call("_shot", "%s_walk.png" % out)
	panel._preview.set_mode("run")
	await tool.call("wait_frames", 30)
	tool.call("_shot", "%s_run.png" % out)
	panel._preview.set_mode("attack")
	var fig := panel._preview._fig
	var waited := 0
	while fig != null and fig._player != null and fig._player.current_animation_position < 2.0 and waited < 400:
		await tool.call("wait_frames", 1)
		waited += 1
	tool.call("_shot", "%s_swing.png" % out)
