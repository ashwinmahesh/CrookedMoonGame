extends Node
## Close-ups of 3D figures' heads and shoulders (vault Build/Character Creator and Layered Figures.md, 3.5a), side by side
## on a plain stage, to check how a head made apart from its body sits: turned to four sides at rest, then caught in its
## clips (talking, swinging, walking, hit).
##   make capture SCENE=res://tools/capture/figure_closeup.tscn NAME=heads/x FRAMES=10 ARGS='--ids=old_rook,rook_coldwake'
## --ids: the figures, left to right; --frame=head|body: head and shoulders (the default) or the whole figure.
## Shots: <out>_front.png, _left.png, _back.png, _right.png, _talk.png, _swing.png, _walk.png, _hit.png.
## --only=talk: instead, the figures talking a frame at a time (their jaws opening with a made-up voice, TalkMotion's
## JawOpen, and the head nodding), <out>_talk_<nnnn>.png for a GIF.

const PANEL := 640


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return default


func capture_shots(tool: Node, out: String) -> void:
	var ids := _arg("ids", "rook_coldwake").split(",", false)
	var head := _arg("frame", "head") == "head"
	var back := ColorRect.new()
	back.color = Look.color("ui_black")
	back.size = Vector2(PANEL * ids.size(), PANEL)
	add_child(back)
	var tables: Array[Node3D] = []
	var figs: Array[ModelFigure] = []
	for i in ids.size():
		var view := SubViewportContainer.new()
		view.stretch = true
		view.position = Vector2(PANEL * i, 0)
		view.size = Vector2(PANEL, PANEL)
		add_child(view)
		var port := SubViewport.new()
		port.own_world_3d = true
		port.msaa_3d = Viewport.MSAA_4X
		view.add_child(port)
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Look.color("ui_wine")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Look.color("parchment")
		env.ambient_light_energy = 0.22
		var cam := Camera3D.new()
		cam.environment = env
		cam.fov = 30.0
		port.add_child(cam)
		var key := DirectionalLight3D.new()
		key.light_energy = 1.25
		key.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(-62.0), 0.0)
		port.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.light_energy = 0.6
		rim.light_color = Color(0.62, 0.7, 0.95)
		rim.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(160.0), 0.0)
		port.add_child(rim)
		var table := Node3D.new()
		port.add_child(table)
		var h := CombatToken.height_for(ids[i])
		var fig := DirectionalSprite.create(FigureModels.frames(ids[i]), h) as ModelFigure
		table.add_child(fig)
		var target := Vector3(0.0, h * (0.86 if head else 0.5), 0.0)
		var fit := h * (0.42 if head else 1.15)
		var dist := fit * 0.5 / tan(deg_to_rad(cam.fov * 0.5))
		var eye := target + Vector3(0.0, dist * sin(deg_to_rad(10.0)), dist * cos(deg_to_rad(10.0)))
		cam.transform = Transform3D(Basis.looking_at(target - eye), eye)
		var label := UiKit.label(ids[i], 16, "parchment")
		label.position = Vector2(PANEL * i + 12, 8)
		add_child(label)
		tables.append(table)
		figs.append(fig)
	await tool.call("wait_frames", 30)
	if _arg("only", "") == "talk":
		await _talk(tool, out, figs, tables)
		return
	for side: Array in [["front", 0.0], ["left", 90.0], ["back", 180.0], ["right", 270.0]]:
		for t in tables:
			t.rotation.y = deg_to_rad(float(side[1]))
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%s.png" % [out, side[0]])
	for t in tables:
		t.rotation.y = deg_to_rad(25.0)
	for f in figs:
		f.gesture("talk")
	await tool.call("wait_frames", 50)
	tool.call("_shot", "%s_talk.png" % out)
	for f in figs:
		f.attack()
	var waited := 0
	while waited < 600 and figs[0]._player != null and figs[0]._player.current_animation_position < 2.05:
		await tool.call("wait_frames", 1)
		waited += 1
	tool.call("_shot", "%s_swing.png" % out)
	await tool.call("wait_frames", 60)
	for f in figs:
		f.moving = true
		f.set_step_time(1.0 / 1.3)
	await tool.call("wait_frames", 40)
	tool.call("_shot", "%s_walk.png" % out)
	for f in figs:
		f.moving = false
		f.hurt()
	await tool.call("wait_frames", 14)
	tool.call("_shot", "%s_hit.png" % out)


## The figures saying a line, a frame per shot: syllables about five a second in words of two to four, the jaw following
## them, the head nodding, a talk gesture under it; turned a little toward the left at first, then facing.
func _talk(tool: Node, out: String, figs: Array[ModelFigure], tables: Array[Node3D]) -> void:
	var jaws: Array = []
	var nods: Array = []
	for f in figs:
		var jaw := TalkMotion.jaw_on(f)
		if jaw != null:
			jaw.talking = true
		jaws.append(jaw)
		var skel := f.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var nod := TalkMotion.HeadNod.new()
		nod.head = TalkMotion.HeadNod.bone_named(skel, "Head")
		nod.neck = TalkMotion.HeadNod.bone_named(skel, "Neck")
		nod.talking = true
		skel.add_child(nod)
		nods.append(nod)
		f.gesture("talk")
	for t in tables:
		t.rotation.y = deg_to_rad(20.0)
	for k in 72:
		var t := float(k) / 12.0
		var syllable := maxf(0.0, sin(t * TAU * 4.8))
		var word := sin(t * TAU * 1.3) + 0.6 * sin(t * TAU * 0.47 + 1.7)
		var loud := syllable * (1.0 if word > -0.35 else 0.15)
		for i in figs.size():
			if jaws[i] != null:
				(jaws[i] as TalkMotion.JawOpen).loudness = loud
			(nods[i] as TalkMotion.HeadNod).loudness = loud
		for tb in tables:
			tb.rotation.y = deg_to_rad(20.0 * maxf(0.0, 1.0 - float(k) / 24.0))
		await tool.call("wait_frames", 2)
		tool.call("_shot", "%s_talk_%04d.png" % [out, k])
