extends Node
## Any places seen from the play camera, as the game shows them: the placeholder party arrives at each location in the list and a shot is
## taken of the play view and of the whole place from above.
##   make capture SCENE=res://tools/capture/places_capture.tscn NAME=world/places ARGS='--places=ghostlight_boarding,wickermoor_village'
## --no-text hides the narration box. --found=a,b marks those search spots found first, so what they hide shows (the Lounge Car's seascape).
## --hour=8 shoots the Twilight Hour (the default is 23, the Midnight Hour).
## --party=placeholder stands the engine's placeholder party (Ilse, Tamsin, Hedda, Silvain, sprites) in the places; the default is a new
## game's party (Rook, Silas, Cordelia, Delphine), the 3D figures the game opens with.
## --tilts=10,30,60,85 adds a play shot at each of those camera tilts (degrees down): <out>_<place>_tilt_<n>.png.
## Shots: <out>_<place>_play.png and <out>_<place>_whole.png.

const GAME := preload("res://world/game_root.gd")


func capture_shots(tool: Node, out: String) -> void:
	var places: PackedStringArray = []
	var sky := false
	var travel := false
	var later := false
	var hour := 23
	var placeholder := false
	var turn := false
	var morphs: PackedStringArray = []
	var gallery := false
	var before := false
	var lineup := -1
	var npcs := 0
	var flags: PackedStringArray = []
	var found: PackedStringArray = []
	var no_text := false
	var focus := Vector2(-1, -1)
	var focus_distance := 8.0
	var tilts: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--places="):
			places = a.get_slice("=", 1).split(",")
		if a == "--no-text":
			no_text = true   # the narration box hidden, for shots of the place alone
		if a.begins_with("--found="):
			found = a.get_slice("=", 1).split(",")   # search spots already found, so their things show (g3_seascape)
		if a.begins_with("--flags="):
			flags = a.get_slice("=", 1).split(",")   # story flags to set first, name:value (moon_grin:2,moon_scowl:true)
		if a == "--party=placeholder":
			placeholder = true
		if a.begins_with("--tilts="):
			tilts = a.get_slice("=", 1).split(",")   # play shots at these tilts (degrees down), as the player tilts the camera
		if a.begins_with("--hour="):
			hour = int(a.get_slice("=", 1))   # the hour of the day (23 the Midnight Hour, the default; 8 the Twilight Hour)
		if a.begins_with("--morph="):
			morphs = a.get_slice("=", 1).split(",")   # the houses' morph weights to shoot from one fixed camera (with --focus)
		if a == "--turn":
			turn = true   # sets crooked_house_turned after the first shot and takes frames of the houses warping
		if a == "--later":
			later = true
		if a.begins_with("--lineup="):
			lineup = int(a.get_slice("=", 1))   # batch n (16 each) of the figures the manifest dresses as villagers, stood in two rows by the party
		if a.begins_with("--npcs="):
			npcs = int(a.get_slice("=", 1))   # a close shot of each of the first n people standing in the place (by id order)
		if a == "--before":
			before = true   # draws the NPCs that have a 3D figure as the old gray-box walker (the figures' `sprite` stand-in), for before shots
		if a == "--gallery":
			gallery = true   # lays every small prop (SmallProps) out in rows on the ground by the party and shoots them close
		if a == "--travel":
			travel = true   # one more shot per place of the travel map, every place known
		if a.begins_with("--focus="):
			var f := a.get_slice("=", 1).split(",")   # a close shot of that square: x,z[,distance]
			focus = Vector2(float(f[0]), float(f[1]))
			if f.size() > 2:
				focus_distance = float(f[2])
		if a == "--sky":
			sky = true   # one more shot per place with the camera tilted to the horizon: the sky and the moon in it
	var dressed: Array[String] = []
	for id: String in FigureModels.manifest().keys():
		var e := FigureModels.manifest()[id] as Dictionary
		if str(e.get("sprite", "")) == "villager" and not id.begins_with("haint"):
			dressed.append(id)
	if before:
		for id: String in FigureModels.manifest().keys():
			var e := FigureModels.manifest()[id] as Dictionary
			if str(e.get("sprite", "")) == "villager" and not id.begins_with("haint"):
				FigureModels.manifest()[id] = {"sprite": "villager"}
		FigureModels._entries.clear()
	for place in places:
		GameState.reset()
		var st := GameState.story
		for id: String in (GAME.PLACEHOLDER_PARTY if placeholder else GAME.NEW_GAME_PARTY):
			var ch := Pregens.build(id, 3)
			ch.finish_long_rest()
			st.party.append(ch)
		st.location = place
		for id in found:
			(st.loc_state(place)["found"] as Dictionary)[id] = true
		for f in flags:
			var v := f.get_slice(":", 1)
			st.set_flag(f.get_slice(":", 0), true if v == "true" else (int(v) if v.is_valid_int() else v))
		st.minute_of_day = hour * 60   # the Midnight Hour unless --hour says otherwise
		Dice.reseed(7)
		var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(game)
		await tool.call("wait_frames", 150)
		for n in game.get_children():
			if n is CanvasLayer and n.name.begins_with("Place"):
				n.visible = false
		await tool.call("wait_frames", 20)
		if no_text:
			for box in game.find_children("NarratorBox", "Control", true, false):
				(box as Control).visible = false
		tool.call("_shot", "%s_%s_play.png" % [out, place])
		if turn:
			st.set_flag("crooked_house_turned", true)
			for k in 8:
				await tool.call("wait_frames", 14)
				tool.call("_shot", "%s_%s_turn_%d.png" % [out, place, k])
				print("turn frame %d: morph weight %.3f" % [k, BuildingMorph.weight((game.get("view") as LocationView).board)])
		var view := game.get("view") as LocationView
		var rig := view.rig
		for t in tilts:
			rig.pitch_deg = -float(t)
			rig.snap_to_target()
			await tool.call("wait_frames", 30)
			tool.call("_shot", "%s_%s_tilt_%s.png" % [out, place, t])
		if not tilts.is_empty():
			rig.reset_view()
			rig.snap_to_target()
		if travel:
			for p: Variant in Travel.map_data().get("places", []) as Array:
				st.visited[str((p as Dictionary)["location"]).get_slice(":", 0)] = true
			var t := TravelScreen.new()
			game.add_child(t)
			t.open_map(st, Travel.place_for_location(st.location), false)
			await tool.call("wait_frames", 60)
			tool.call("_shot", "%s_%s_travel.png" % [out, place])
			t.queue_free()
			await tool.call("wait_frames", 5)
		if focus.x >= 0.0:
			rig.follow = null
			rig.horizon = 0.0
			rig.distance = focus_distance
			rig.global_position = view.board.cell_center(Vector2i(int(focus.x), int(focus.y)))
			rig.snap_to_target()
			await tool.call("wait_frames", 40)
			tool.call("_shot", "%s_%s_focus.png" % [out, place])
			for w in morphs:   # the houses at each morph weight from this same close camera
				BuildingMorph.set_weight(view.board, float(w))
				await tool.call("wait_frames", 10)
				tool.call("_shot", "%s_%s_morph_%s.png" % [out, place, w])
		if npcs > 0:
			var shown := 0
			var ids_here: Array = view.npc_tokens.keys()
			ids_here.sort()
			for nid: Variant in ids_here:
				if shown >= npcs:
					break
				var who := view.npc_tokens[nid] as Node3D
				rig.follow = null
				rig.horizon = 0.0
				rig.distance = 7.0
				rig.global_position = who.global_position
				rig.snap_to_target()
				await tool.call("wait_frames", 45)
				tool.call("_shot", "%s_%s_npc_%s.png" % [out, place, str(nid)])
				shown += 1
		if lineup >= 0:
			var base_cell := view.leader().cell
			var from := lineup * 16
			for k in range(from, mini(from + 16, dressed.size())):
				var cb := Combatant.new(Monster.from_data(Compendium.shared().monster_data("commoner")), &"neutral", base_cell + Vector2i(2 + (k - from) % 8, -1 + 2 * int((k - from) / 8.0)))
				var tok := LocationNpcs._npc_token(cb, dressed[k])
				tok.position = view.board.cell_center(cb.cell)
				view.add_child(tok)
			rig.follow = null
			rig.horizon = 0.0
			rig.distance = 7.0
			rig.global_position = view.board.cell_center(base_cell + Vector2i(5, 0))
			rig.snap_to_target()
			await tool.call("wait_frames", 60)
			tool.call("_shot", "%s_%s_lineup%d.png" % [out, place, lineup])
		if gallery:
			var base := view.leader().cell
			for k in SmallProps.KINDS.size():
				var spot := view.board.cell_center(base + Vector2i(2 + k, 0))   # (one row along an open aisle)
				SmallProps.build(SmallProps.KINDS[k], view.board, spot, 7 + k, Vector2i.ZERO)
			rig.follow = null
			rig.horizon = 0.0
			rig.distance = 8.0
			rig.global_position = view.board.cell_center(base + Vector2i(7, 0))
			rig.snap_to_target()
			await tool.call("wait_frames", 40)
			tool.call("_shot", "%s_%s_gallery.png" % [out, place])
		if sky:
			rig.horizon = 1.0
			rig.horizon_shown = 1.0
			rig.distance = rig.zoom_max
			await tool.call("wait_frames", 40)
			# The moon in a clear sky straight ahead (the weather's cloud and the moon's own bearing hide it), to see its face.
			var post := view.atmosphere.get("_post") as ShaderMaterial
			if post != null:
				post.set_shader_parameter("sky_cover", 0.0)
				post.set_shader_parameter("sky_moon", 1.0)
				var ahead := -view.rig.camera.global_basis.z
				post.set_shader_parameter("sky_moon_dir", Vector3(ahead.x, 0.07, ahead.z).normalized())
				await tool.call("wait_frames", 10)
			tool.call("_shot", "%s_%s_sky.png" % [out, place])
		rig.horizon = 0.0
		rig.horizon_shown = 0.0
		rig.follow = null
		rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
		rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
		rig.snap_to_target()
		await tool.call("wait_frames", 30)
		tool.call("_shot", "%s_%s_whole.png" % [out, place])

		if later:
			await tool.call("wait_frames", 50)
			tool.call("_shot", "%s_%s_whole_later.png" % [out, place])   # the same view a moment on, to see what moves
		game.queue_free()
		await tool.call("wait_frames", 5)
