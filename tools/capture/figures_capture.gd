extends Node
## The 3D figures (art/figures/manifest.json, the engine's FigureModels and ModelFigure) at the play camera: the hill as
## it is with the party of companions, then every figure in a row in front of them, from the play view and close, turned
## round and tilted, and caught swinging, walking, running, talking, greeting, hit, falling and fallen.
##   make capture SCENE=res://tools/capture/figures_capture.tscn NAME=figures/f ARGS='--hour=8 --bands=2'
## --hour: the hour (8 the Twilight Hour, 23 the Midnight Hour); --place: a location id; --party=placeholder: the old 2D
## four instead of the companions, for sprites beside models; --ahead and --across: where the row stands from the leader
## (squares toward the camera and to its right); --follow=<art id> and --near=<distance>: the camera close on one
## figure; --ids=a,b: only those figures in the row; --each=dagger,spear: figure number n (the ids in order) holds the nth
## item in its main hand, round again after the last, - for none (a row of figures, one weapon each), and --off= the same for
## the off hand; --props=fp_barrel,fp_table: 3D props (art ids) in rows in front of them (--props-width squares a row); --bands, --ink, --flatten, --vivid, --floor, --rim: the figures' look
## (Look.figure_settings); --hold=hooded_lantern@off_hand,torch@main_hand: what the row holds (a figure whose entry
## shows `gear` wears its part); --only=reel steps the row through idle, walk, run, attack and talk at --fps (12) frames
## a second and then orbits it, a frame per shot (<out>_reel_<nnnn>.png, for a GIF); --only=place,lineup,turns,poses picks shots, and --only=clip --clip=slash freezes the row at
## points through one clip instead (to choose a manifest's window). Shots: <out>_<shot>.png.
## Headless with --probe it prints what each figure's model holds instead: its clips, the walk's stride and footfalls,
## and where its right hand moves fastest in its attack (for a manifest's attack window).

const GAME := preload("res://world/game_root.gd")
const PLACE := "ghostlight_boarding"


func _ready() -> void:
	if "--probe" in OS.get_cmdline_user_args():
		await _probe()
		get_tree().quit()


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return default


func capture_shots(tool: Node, out: String) -> void:
	var s := Look.figure_settings()
	for key: String in ["bands", "ink", "flatten", "vivid", "floor", "rim"]:
		if _arg(key, "") != "":
			s[key] = float(_arg(key, "0")) if key != "bands" else int(_arg(key, "0"))
	var only := _arg("only", "place,lineup,turns,poses").split(",")
	GameState.reset()
	var st := GameState.story
	# --party=placeholder: the old 2D four, so a shot shows the sprites beside the models.
	for id: String in (GAME.PLACEHOLDER_PARTY if _arg("party", "") == "placeholder" else GAME.NEW_GAME_PARTY):
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = _arg("place", PLACE)
	st.minute_of_day = int(_arg("hour", "8")) * 60
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	for n in game.get_children():
		if n is CanvasLayer and n.name.begins_with("Place"):
			n.visible = false
	var view := game.get("view") as LocationView
	if "place" in only:
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s_place.png" % out)
	var line := _lineup(view)
	if line.is_empty():
		return
	var rig := view.rig
	rig.follow = line[line.size() / 2] as Node3D
	var near := 0.0
	if _arg("follow", "") != "":
		# --follow=<art id>: the camera close on one figure (--near=<distance>, closer than play allows).
		for t: CombatToken in line:
			if t.art_override == _arg("follow", ""):
				rig.follow = t
		near = float(_arg("near", "3.5"))
		rig.zoom_min = minf(rig.zoom_min, near)
	rig.snap_to_target()
	await tool.call("wait_frames", 40)
	if "lineup" in only:
		tool.call("_shot", "%s_lineup.png" % out)
		rig.distance = CameraRig.ZOOM_MIN
		await tool.call("wait_frames", 40)
		tool.call("_shot", "%s_lineup_close.png" % out)
		rig.distance = 13.0
	if "turns" in only:
		rig.distance = near if near > 0.0 else CameraRig.ZOOM_MIN + 1.0
		for turn: int in [90, 180, 270]:
			rig.turn_by(90.0)
			await tool.call("wait_frames", 50)
			tool.call("_shot", "%s_turn%d.png" % [out, turn])
		rig.turn_by(90.0)
		rig.tilt_by(-30.0)
		await tool.call("wait_frames", 50)
		tool.call("_shot", "%s_tilt_low.png" % out)
		rig.tilt_by(60.0)
		await tool.call("wait_frames", 50)
		tool.call("_shot", "%s_tilt_high.png" % out)
		rig.reset_view()
		rig.distance = 13.0
		await tool.call("wait_frames", 40)
	if "reel" in only:
		await _reel(tool, out, line, rig)
		return
	if "clip" in only:
		# --clip=slash: the row frozen at points through one clip, to pick a manifest's window from.
		rig.distance = CameraRig.ZOOM_MIN
		await tool.call("wait_frames", 30)
		var clip := _arg("clip", "slash")
		for at: float in [0.3, 0.8, 1.2, 1.5, 1.8, 2.0, 2.1, 2.2, 2.4, 2.8, 3.5, 4.5, 5.5, 6.3]:
			for t: CombatToken in line:
				var fig := t.sprite as ModelFigure
				if fig == null or fig._player == null or not fig._player.has_animation(clip):
					continue
				fig.set_process(false)
				fig._player.play(clip)
				fig._player.seek(at, true)
				fig._player.pause()
			await tool.call("wait_frames", 3)
			tool.call("_shot", "%s_%s_%04d.png" % [out, clip, int(at * 100)])
		return
	if "poses" in only:
		rig.distance = CameraRig.ZOOM_MIN + 1.5
		await tool.call("wait_frames", 30)
		var axes := rig.ground_basis()
		var side := Vector2((axes[1] as Vector3).x, (axes[1] as Vector3).z)
		var toward := -Vector2((axes[0] as Vector3).x, (axes[0] as Vector3).z)
		# A slow capture window draws a frame in far more than a sixtieth of a second, so each action is shot when its
		# clip reaches the moment wanted, not after a count of frames.
		for t: CombatToken in line:
			t.start_attack(toward + side * 0.7)
		await _until(tool, line, "attack", 1.95)
		tool.call("_shot", "%s_swing_1.png" % out)
		await _until(tool, line, "attack", 2.15)
		tool.call("_shot", "%s_swing_2.png" % out)
		await _until(tool, line, "", 0.0)
		# A townsfolk's stroll walks; the party's pace runs (ModelFigure.RUN_FROM).
		for t: CombatToken in line:
			t.face(side, true, 1.0 / NpcWalker.SPEED)
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s_walk.png" % out)
		for t: CombatToken in line:
			t.face(side, true, LocationView.STEP_TIME)
		await tool.call("wait_frames", 20)
		tool.call("_shot", "%s_run.png" % out)
		for t: CombatToken in line:
			t.face(toward, false)
		await tool.call("wait_frames", 10)
		for t: CombatToken in line:
			t.gesture("talk")
		await _until(tool, line, "talk", 1.6)
		tool.call("_shot", "%s_talk.png" % out)
		await _until(tool, line, "", 0.0)
		for t: CombatToken in line:
			t.gesture("greet")
		await _until(tool, line, "greet", 1.4)
		tool.call("_shot", "%s_greet.png" % out)
		await _until(tool, line, "", 0.0)
		for t: CombatToken in line:
			(t.sprite as DirectionalSprite).hurt()
		await _until(tool, line, "hurt", 0.45)
		tool.call("_shot", "%s_hit.png" % out)
		await _until(tool, line, "", 0.0)
		for t: CombatToken in line:
			t.fall()
		await _until(tool, line, "die", 1.5)
		tool.call("_shot", "%s_falling.png" % out)
		await _until(tool, line, "", 0.0)
		await tool.call("wait_frames", 10)
		tool.call("_shot", "%s_fallen.png" % out)


## Waits until the first of `line` playing clip `role` has it at `at` seconds or past (role "": until none plays one).
func _until(tool: Node, line: Array, role: String, at: float) -> void:
	for i in 600:
		var fig: ModelFigure = null
		for t: CombatToken in line:
			var f := t.sprite as ModelFigure
			if f != null and (role == "" and f._one_shot != "" or role != "" and f._one_shot == role):
				fig = f
				break
		if role == "" and fig == null:
			return
		if fig != null and role != "" and fig._player.current_animation_position >= at:
			return
		await tool.call("wait_frames", 1)


## The row stepped through its clips a frame at a time (the clip seeked, so a slow capture window still shows every
## moment), then the camera orbiting it, each frame a shot. Walks and runs are held in place, as in play.
func _reel(tool: Node, out: String, line: Array, rig: CameraRig) -> void:
	var fps := float(_arg("fps", "12"))
	var mid := Node3D.new()
	add_child(mid)
	var centre := Vector3.ZERO
	for t: CombatToken in line:
		centre += t.global_position
	mid.global_position = centre / float(line.size())
	rig.follow = mid
	rig.distance = CameraRig.ZOOM_MIN
	rig.snap_to_target()
	await tool.call("wait_frames", 30)
	var n := 0
	# role, clip, from, to (seconds; a looping clip runs on past its end)
	for seg: Array in [["idle", "idle", 0.0, 2.5], ["walk", "walk", 0.0, 2.4], ["run", "run", 0.0, 2.6],
			["attack", "slash", 1.25, 2.85], ["talk", "agree", 0.0, 3.0]]:
		var steps := int(round((float(seg[3]) - float(seg[2])) * fps))
		for k in steps:
			for t: CombatToken in line:
				var fig := t.sprite as ModelFigure
				if fig == null or fig._player == null:
					continue
				fig.set_process(false)
				var clip := ModelFigure.clip_named(fig._player.get_animation_list(), str(seg[1]))
				if clip == "":
					continue
				var length := fig._player.get_animation(clip).length
				fig._player.play(clip)
				fig._player.seek(fmod(float(seg[2]) + float(k) / fps, maxf(length, 0.01)), true)
				fig._player.pause()
			await tool.call("wait_frames", 2)
			tool.call("_shot", "%s_reel_%04d_%s.png" % [out, n, seg[0]])
			n += 1
	# All the way round: the figures turned on the spot, idling (the camera would pass behind the place's trees).
	for k in 48:
		for t: CombatToken in line:
			var fig := t.sprite as ModelFigure
			if fig == null or fig._player == null:
				continue
			var clip := ModelFigure.clip_named(fig._player.get_animation_list(), "idle")
			if clip != "":
				fig._player.play(clip)
				fig._player.seek(fmod(float(k) / fps, fig._player.get_animation(clip).length), true)
				fig._player.pause()
			fig._turn.rotation.y = deg_to_rad(7.5 * float(k + 1))
		await tool.call("wait_frames", 2)
		tool.call("_shot", "%s_reel_%04d_turn.png" % [out, n])
		n += 1


## Every figure in the manifest in a row across the screen in front of the party, facing the camera; their tokens,
## left to right.
func _lineup(view: LocationView) -> Array:
	var ids := (ArtPaths.json(FigureModels.MANIFEST_JSON).get("figures", {}) as Dictionary).keys()
	if _arg("ids", "") != "":
		ids = Array(_arg("ids", "").split(","))   # --ids=a,b: only these
	ids.sort()
	var axes := view.rig.ground_basis()
	var toward := -(axes[0] as Vector3)
	var right := axes[1] as Vector3
	var mid := view.board.cell_center(view.leader().cell) + toward * float(_arg("ahead", "2.5")) + right * float(_arg("across", "3"))
	var out: Array = []
	for i in ids.size():
		var id := str(ids[i])
		var ch := Pregens.build("rook_coldwake", 1)
		ch.name = id.capitalize()
		for held: String in _arg("hold", "").split(",", false):
			ch.add_item(held.get_slice("@", 0))
			ch.equip(held.get_slice("@", 0), held.get_slice("@", 1))
		for slot: String in ["each", "off"]:
			var items := _arg(slot, "").split(",", false)
			if not items.is_empty() and items[i % items.size()] != "-":
				ch.add_item(items[i % items.size()])
				ch.equip(items[i % items.size()], "main_hand" if slot == "each" else "off_hand")
		var at := mid + right * (float(i) - (ids.size() - 1) / 2.0) * 0.95
		var cell := Vector2i(floori(at.x), floori(at.z))
		var cb := Combatant.new(ch, &"neutral", cell)
		var tok := CombatToken.create(cb, id)
		tok.position = Vector3(at.x, view.board.cell_center(cell).y, at.z)
		view.add_child(tok)
		tok.face(Vector2(toward.x, toward.z), false)
		out.append(tok)
	_props(view, mid + toward * 1.1, right)
	return out


## --props=fp_barrel,fp_crate: those 3D props (art ids the catalog maps to a model) in a row behind the figures, left to
## right, each as wide as its model, standing on the board's ground there.
func _props(view: LocationView, at: Vector3, right: Vector3) -> void:
	var ids := _arg("props", "").split(",", false)
	if ids.is_empty():
		return
	# Rows no wider than --props-width (7 squares), each one a little further back.
	var toward := -(view.rig.ground_basis()[0] as Vector3)
	var limit := float(_arg("props-width", "7"))
	var rows: Array = [[]]
	var row_width := 0.0
	for art: String in ids:
		var size := (ModelPiece.manifest().get(art, {}) as Dictionary).get("size", [0.6, 0.6, 0.6]) as Array
		var width := maxf(float(size[0]), float(size[2])) + 0.3
		if row_width + width > limit and not (rows[-1] as Array).is_empty():
			rows.append([])
			row_width = 0.0
		(rows[-1] as Array).append([art, width])
		row_width += width
	for r in rows.size():
		var total := 0.0
		for e: Array in rows[r]:
			total += float(e[1])
		var x := -total / 2.0
		for e: Array in rows[r]:
			var model := str(e[0])
			if ModelPiece.has_model(model):
				var piece := ModelPiece.instance(model)
				var pos := at + toward * (1.5 * r) + right * (x + float(e[1]) / 2.0)
				var cell := Vector2i(floori(pos.x), floori(pos.z))
				piece.position = Vector3(pos.x, view.board.cell_center(cell).y, pos.z)
				view.add_child(piece)
			else:
				push_warning("figures_capture: no 3D model for %s" % model)
			x += float(e[1])


## What each figure's model holds (headless): its clips by role, the walk's stride and footfalls, the attack's fastest
## hand.
func _probe() -> void:
	var ids := (ArtPaths.json(FigureModels.MANIFEST_JSON).get("figures", {}) as Dictionary).keys()
	for id: String in ids:
		var fig := DirectionalSprite.create(DirectionalSprite.frames_for(id), CombatToken.height_for(id)) as ModelFigure
		add_child(fig)
		await get_tree().process_frame
		var players := fig.model.find_children("*", "AnimationPlayer", true, false)
		var skeletons := fig.model.find_children("*", "Skeleton3D", true, false)
		if players.is_empty() or skeletons.is_empty():
			print("== %s has no clips or skeleton (a static model)" % id)
			fig.queue_free()
			continue
		var player := players[0] as AnimationPlayer
		var sk := skeletons[0] as Skeleton3D
		var roles := {}
		for role: String in FigureModels.CLIPS:
			if fig.has_role(role):
				roles[role] = (fig._roles[role] as Array).map(func(c: Dictionary) -> String: return str(c["name"]))
		print("== %s height %.2f scale %.3f roles %s" % [id, fig._height, fig._scale, roles])
		print("   clips %s" % [Array(player.get_animation_list())])
		if fig.has_role("walk"):
			var walk := player.get_animation(str((fig._roles["walk"] as Array)[0]["name"]))
			fig.set_step_time(LocationView.STEP_TIME)
			var party := fig.walk_speed
			fig.set_step_time(CombatView.STEP_TIME)
			print("   walk %.2fs stride %.3f (model) steps %s; rate at the party's pace %.2f, a fight's %.2f" % [walk.length,
				float(walk.get_meta("figure_stride", 0.0)), walk.get_meta("figure_steps"), party, fig.walk_speed])
		var hand := -1
		for b in sk.get_bone_count():
			if sk.get_bone_name(b).ends_with("RightHand"):
				hand = b
		if fig.has_role("attack") and hand >= 0:
			var clip := str((fig._roles["attack"] as Array)[0]["name"])
			var anim := player.get_animation(clip)
			player.play(clip)
			var prev := Vector3.INF
			var speeds: Array[String] = []
			var best := 0.0
			var best_t := 0.0
			var t := 0.0
			while t <= anim.length:
				player.seek(t, true)
				var p := sk.get_bone_global_pose(hand).origin
				if prev != Vector3.INF:
					var v := (p - prev).length() / 0.05
					speeds.append("%.1f:%.2f" % [t, v])
					if v > best:
						best = v
						best_t = t
				prev = p
				t += 0.05
			print("   %s %.2fs fastest hand at %.2fs (%.2f units/s); speeds %s" % [clip, anim.length, best_t, best,
				" ".join(speeds.filter(func(x: String) -> bool: return float(x.get_slice(":", 1)) > best * 0.3))])
		fig.queue_free()
