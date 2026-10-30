extends Node
## Game feel before and after (the engine's GameFeel, Visual Polish Plan E39-E41, FX1/FX2): the same blows in the
## hillside fight played with the engine's defaults and with the game's "game_feel", as frame sequences
## (<out>_<stage>_<before|after>_NNN.jpg, every second frame at 60 a second).
##   make capture SCENE=res://tools/capture/feel_capture.tscn NAME=feel/a FRAMES=30 [ARGS='--feel_only=crit']

const GAME := preload("res://world/game_root.gd")
const LOCATION := "test_hillside"
const ENCOUNTER := "hillside_scarecrows"
const CLIP_FRAMES := 110
const EVERY := 2
## Each stage: who acts (a party index), the targets (cells along the camera's right, forward) and the events played,
## with "caster" and "t0", "t1"... filled in.
const STAGES := {
	"crit": {"caster": 0, "targets": [[1, 0]], "events": [
		{"type": "attack", "attacker": "caster", "target": "t0", "hit": true, "critical": true, "action": "weapon:longsword"},
		{"type": "damage", "id": "t0", "amount": 14, "critical": true}]},
	"light": {"caster": 0, "targets": [[1, 0]], "events": [
		{"type": "attack", "attacker": "caster", "target": "t0", "hit": true, "action": "weapon:longsword"},
		{"type": "damage", "id": "t0", "amount": 3}]},
	"fire_bolt": {"caster": 3, "targets": [[3, 0]], "events": [
		{"type": "spell", "spell": "fire_bolt", "caster": "caster", "targets": ["t0"]},
		{"type": "attack", "attacker": "caster", "target": "t0", "hit": true}, {"type": "damage", "id": "t0", "amount": 9}]},
	"fireball": {"caster": 3, "targets": [[4, 0], [5, 1]], "area": [5, 0], "events": [
		{"type": "spell", "spell": "fireball", "caster": "caster", "targets": ["t0", "t1"]},
		{"type": "damage", "id": "t0", "amount": 20}, {"type": "damage", "id": "t1", "amount": 20}]},
}
## The game feel shown on the "after" side.
const FEEL := {
	"hit_stop": {"light": 3, "medium": 5, "heavy": 7, "crit": 9, "kill": 10}, "kick": 0.12, "flash": 0.85, "knockback": 1.4,
	"dip": {"scale": 0.35, "seconds": 0.22}, "impact_frame": 2, "sway": 0.06,
	"spell_light": 1.4, "spell_reach": 1.3, "spell_shadows": true, "shapes": true,
}

var game: Node
var cv: CombatView


func capture_shots(tool: Node, out: String) -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--feel_only="):
			only = a.get_slice("=", 1)
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = LOCATION
	st.minute_of_day = 0
	Dice.reseed(7)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	for n in game.get_children():
		if n is CanvasLayer and n.name.begins_with("Place"):
			n.visible = false
	var view := game.get("view") as LocationView
	view.start_encounter(ENCOUNTER)
	cv = view.combat_view
	cv.input_locked = true
	for i in 2400:
		await tool.call("wait_frames", 1)
		if cv.mode == CombatView.Mode.IDLE:
			break
	await tool.call("wait_frames", 60)
	CombatImpact.enabled = true
	for key: String in STAGES:
		if only != "" and not key in only.split(","):
			continue
		var stage := STAGES[key] as Dictionary
		for after: bool in [false, true]:
			GameFeel.use(FEEL if after else {})
			var ids := _stage(stage)
			await tool.call("wait_frames", 30)
			await _record(stage, ids, "%s_%s_%s" % [out, key, "after" if after else "before"])
	GameFeel.use(null)


func _stage(st: Dictionary) -> Dictionary:
	var e := cv.e
	var heroes := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"party")
	var foes := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy")
	var caster := heroes[int(st["caster"]) % heroes.size()] as Combatant
	var spot := Vector2i(10, 15)
	var right := Vector2i(1, 0)
	var fwd := Vector2i(0, -1)
	_put(caster, spot)
	var ids := {"caster": caster.id}
	var i := 0
	for t: Variant in st["targets"]:
		var who := foes[i % foes.size()] as Combatant
		who.creature.hp = who.creature.max_hp()
		(cv.tokens[who.id] as CombatToken).refresh()
		_put(who, spot + right * int((t as Array)[0]) + fwd * int((t as Array)[1]))
		ids["t%d" % i] = who.id
		i += 1
	if st.has("area"):
		var a := st["area"] as Array
		var at := spot + right * int(a[0]) + fwd * int(a[1])
		ids["area"] = e.spells.area_for(caster, Compendium.shared().spell_data("fireball"), Vector2(at.x + 0.5, at.y + 0.5), Vector2.ZERO, 3)
	var mid := Vector3.ZERO
	for k: String in ids:
		if k != "area":
			mid += (cv.tokens[ids[k]] as Node3D).global_position
	mid /= float(ids.size() - (1 if ids.has("area") else 0))
	cv.rig.follow = null
	cv.rig.global_position = mid + Vector3(0, 0.3, 0)
	cv.rig.distance = 10.0 if st.has("area") else 7.5
	cv.overlay.clear_all()
	for id: String in cv.tokens:
		(cv.tokens[id] as CombatToken).set_active(false)
	return ids


func _put(c: Combatant, cell: Vector2i) -> void:
	c.cell = cell
	(cv.tokens[c.id] as CombatToken).position = cv.board.cell_center(cell, c.size_cells)


func _record(st: Dictionary, ids: Dictionary, prefix: String) -> void:
	var events: Array = []
	for ev: Variant in st["events"]:
		var d := (ev as Dictionary).duplicate(true)
		for k: String in ["caster", "attacker", "target", "id", "by"]:
			if d.has(k):
				d[k] = ids[str(d[k])]
		if d.has("targets"):
			d["targets"] = (d["targets"] as Array).map(func(x: Variant) -> String: return str(ids[str(x)]))
		if str(d["type"]) == "spell":
			d["cells"] = ids.get("area", [])
		events.append(d)
	cv.e.events.append_array(events)
	cv.call("_play_events")
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	for i in CLIP_FRAMES:
		await get_tree().process_frame
		if i % EVERY == 0:
			get_viewport().get_texture().get_image().save_jpg("%s_%03d.jpg" % [prefix, i / EVERY], 0.9)
	await get_tree().create_timer(1.2).timeout
	print("feel_capture: %s left %d marks on the ground" % [prefix.get_file(), GroundMarks.count()])
