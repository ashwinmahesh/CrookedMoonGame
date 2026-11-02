extends Node3D
## A test bench for how fast figures animate (WalkPace.anim, the campaign's `anim_speed` in data/campaign.json): the
## heroes in front and enemies behind, each walking a few squares, swinging, casting, flinching, falling and getting up
## again, in turn, while a slider sets the speed live. Walking covers ground at the game's fight pace times the speed,
## so the walk cycle keeps its feet planted. Skeletons only by default (the bones drawn, the bodies hidden).
##   make anim-demo            (a window, for Ashwin to pick a speed)
##   make capture SCENE=res://tools/anim_speed/anim_speed_demo.tscn NAME=anim_speed/demo
## Keys: left and right nudge the speed by 0.05; 1 to 7 pick what the figures do.

const HEROES: Array[String] = ["rook_coldwake", "delphine_ravelle", "silas_vane", "tobin_hayward"]
const ENEMIES: Array[String] = ["phantom_trainhopper", "soulfire_stoker", "corrupted_passenger", "haint", "ghost_crawler"]
const ACTIONS: Array[String] = ["Everything in turn", "Walk", "Attack", "Cast", "Hurt", "Fall and get up", "Stand idle"]
const SQUARES := 3
const MIN_SPEED := 0.5
const MAX_SPEED := 3.0
## A bone shorter than this (model units after scaling) is left undrawn: fingers and twist bones clutter the stick figure.
const MIN_BONE := 0.035

var _slider: HSlider
var _value: Label
var _action: OptionButton
var _skeletons: CheckBox
var _figs: Array[ModelFigure] = []
var _enemy: Dictionary = {}       ## figure -> true for an enemy
var _bones: Dictionary = {}       ## figure -> [Skeleton3D, MultiMeshInstance3D, [[bone, parent]]]
var _rng := RandomNumberGenerator.new()   # cosmetic: when each figure starts


func _ready() -> void:
	_rng.seed = 11
	_stage()
	_ui()
	_set_speed(float(Campaign.setting("anim_speed", 1.0)))
	var row := 0
	for list: Array[String] in [HEROES, ENEMIES]:
		var ids: Array[String] = []
		for id in list:
			if FigureModels.scene(id) != null:
				ids.append(id)
		for i in ids.size():
			var fig := DirectionalSprite.create(FigureModels.frames(ids[i]), CombatToken.height_for(ids[i])) as ModelFigure
			if fig == null:
				continue
			add_child(fig)
			fig.position = Vector3((float(i) - (ids.size() - 1) / 2.0) * 1.6 - SQUARES / 2.0, 0.0, -3.0 * row)
			fig.facing = Vector3(0, 0, 1)
			_figs.append(fig)
			if row == 1:
				_enemy[fig] = true
			_rig_bones(fig, Look.color("ember") if row == 1 else Look.color("moonlight"))
		row += 1
	_show_skeletons(true)
	for fig in _figs:
		_run(fig)


func _exit_tree() -> void:
	WalkPace.speed_override = -1.0


func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Look.color("night_deep")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Look.color("moonlight")
	env.ambient_light_energy = 0.35
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-35.0), 0.0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Look.color("bog_deep")
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)
	# The camera about 30 degrees down at the rows, as in play (campaign camera pitch).
	var cam := Camera3D.new()
	cam.fov = 35.0
	var target := Vector3(0.0, 0.8, -1.5)
	var pitch := deg_to_rad(float((Campaign.setting("camera", {}) as Dictionary).get("pitch", 30)))
	var eye := target + Vector3(0.0, sin(pitch), cos(pitch)) * 10.5
	cam.transform = Transform3D(Basis.looking_at(target - eye), eye)
	add_child(cam)
	cam.make_current()


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Look.color("void")
	style.bg_color.a = 0.8
	style.set_content_margin_all(12)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiKit.label("Animation speed", 20, "parchment"))
	var row := HBoxContainer.new()
	box.add_child(row)
	_slider = HSlider.new()
	_slider.min_value = MIN_SPEED
	_slider.max_value = MAX_SPEED
	_slider.step = 0.05
	_slider.custom_minimum_size = Vector2(320, 24)
	_slider.value_changed.connect(_set_speed)
	row.add_child(_slider)
	_value = UiKit.label("", 20, "candle")
	_value.custom_minimum_size = Vector2(70, 0)
	row.add_child(_value)
	_action = OptionButton.new()
	for a in ACTIONS:
		_action.add_item(a)
	box.add_child(_action)
	_skeletons = CheckBox.new()
	_skeletons.text = "Skeletons only"
	_skeletons.button_pressed = true
	_skeletons.toggled.connect(_show_skeletons)
	box.add_child(_skeletons)
	box.add_child(UiKit.label("Heroes in front, enemies behind. The game now uses %.2fx.\nLeft and right nudge the speed; 1 to 7 pick an action." %
		float(Campaign.setting("anim_speed", 1.0)), 14, "vellum"))


func _set_speed(v: float) -> void:
	v = clampf(snappedf(v, 0.05), MIN_SPEED, MAX_SPEED)
	WalkPace.speed_override = v
	if _slider != null and not is_equal_approx(_slider.value, v):
		_slider.set_value_no_signal(v)
	if _value != null:
		_value.text = "%.2fx" % v


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_RIGHT:
		_set_speed(WalkPace.anim() + 0.05)
	elif key.keycode == KEY_LEFT:
		_set_speed(WalkPace.anim() - 0.05)
	elif key.keycode >= KEY_1 and key.keycode < KEY_1 + ACTIONS.size():
		_action.select(key.keycode - KEY_1)


# --- What each figure does ---------------------------------------------------------------------------------------------

## The figure's loop: the chosen action, over and over (or each in turn), at the speed of the moment.
func _run(fig: ModelFigure) -> void:
	await get_tree().create_timer(_rng.randf_range(0.0, 0.6)).timeout
	var step := 0
	var out := true
	while is_instance_valid(fig) and is_inside_tree():
		var pick := _action.selected
		var beat := pick if pick > 0 else 1 + step % 5
		step += 1
		match beat:
			1:
				await _walk(fig, 1.0 if out else -1.0)
				out = not out
			2:
				await _once(fig, fig.attack())
			3:
				await _once(fig, fig.cast())
			4:
				await _once(fig, fig.hurt())
			5:
				await _fall_and_rise(fig)
			_:
				await get_tree().create_timer(1.0).timeout
		await get_tree().create_timer(0.35 / WalkPace.anim()).timeout


## A few squares sideways, a square at a time at a fight's pace for its side, times the speed.
func _walk(fig: ModelFigure, dir: float) -> void:
	fig.facing = Vector3(dir, 0, 0)
	fig.moving = true
	for i in SQUARES:
		var seconds := CombatView.STEP_TIME / (WalkPace.FOES if _enemy.has(fig) else WalkPace.HEROES) / WalkPace.anim()
		fig.set_step_time(seconds)
		var tw := create_tween()
		tw.tween_property(fig, "position:x", fig.position.x + dir, seconds)
		await tw.finished
	fig.moving = false
	fig.facing = Vector3(0, 0, 1)


## Waits out a one-shot clip (at most a few seconds); a short pause when the figure has no clip for it.
func _once(fig: ModelFigure, started: bool) -> void:
	if not started:
		await get_tree().create_timer(0.4).timeout
		return
	var waited := 0.0
	while is_instance_valid(fig) and fig._one_shot != "" and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _fall_and_rise(fig: ModelFigure) -> void:
	fig.die()
	await _once(fig, true)
	await get_tree().create_timer(0.8 / WalkPace.anim()).timeout
	fig.pose = ""
	var waited := 0.0
	while is_instance_valid(fig) and (fig._one_shot != "" or fig._lie > 0.0) and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


# --- The skeletons ----------------------------------------------------------------------------------------------------

## A stick for every bone of the model's skeleton, drawn from its joint to its parent's.
func _rig_bones(fig: ModelFigure, colour: Color) -> void:
	if fig.model == null:
		return
	var skels := fig.model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	var pairs: Array = []
	for b in skel.get_bone_count():
		var p := skel.get_bone_parent(b)
		if p >= 0:
			pairs.append([b, p])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var stick := BoxMesh.new()
	stick.size = Vector3(1, 1, 1)
	mm.mesh = stick
	mm.instance_count = pairs.size()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	_bones[fig] = [skel, mmi, pairs]


func _show_skeletons(on: bool) -> void:
	for fig: ModelFigure in _bones:
		fig.model.visible = not on
		((_bones[fig] as Array)[1] as Node3D).visible = on


func _process(_delta: float) -> void:
	if _skeletons == null or not _skeletons.button_pressed:
		return
	for fig: ModelFigure in _bones:
		var entry := _bones[fig] as Array
		var skel := entry[0] as Skeleton3D
		var mm := (entry[1] as MultiMeshInstance3D).multimesh
		var pairs := entry[2] as Array
		var at := skel.global_transform
		for i in pairs.size():
			var a := at * skel.get_bone_global_pose(int((pairs[i] as Array)[0])).origin
			var b := at * skel.get_bone_global_pose(int((pairs[i] as Array)[1])).origin
			var length := a.distance_to(b)
			if length < MIN_BONE:
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), a))
				continue
			var along := (a - b) / length
			var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
			var turn := Basis(side * 0.05, along * length, along.cross(side).normalized() * 0.05)
			mm.set_instance_transform(i, Transform3D(turn, (a + b) * 0.5))


## make capture: the rows at the game's speed, then at 1x and 2x (a moment into the cycle each).
func capture_shots(tool: Node, out: String) -> void:
	for speed: float in [float(Campaign.setting("anim_speed", 1.0)), 1.0, 2.0]:
		_set_speed(speed)
		await tool.call("wait_frames", 90)
		tool.call("_shot", "%s_%d.png" % [out, roundi(speed * 100)])
	_skeletons.button_pressed = false
	await tool.call("wait_frames", 30)
	tool.call("_shot", "%s_models.png" % out)
