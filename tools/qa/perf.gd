extends Node
## The performance pass (QA lane), headless: for each place, the game scene is opened there as a new game's party
## would arrive, and the run records how long the place takes to build (to the first frame it shows), the slowest frame
## while it settles, then each frame's wall time over a few seconds of standing still with no frame cap, the node and
## object counts and static memory. (Performance's TIME_PROCESS refreshes about once a second, so frames are timed directly.)
## The frame times are each frame's process step (every node's _process), not physics or drawing.
## Headless Godot draws nothing, so these are the game's own costs (scripts, scene building, AI), never the GPU's:
## the Mac's frame rate needs `make capture` or a windowed run there.
##
## Args after --: --out=/abs/perf.jsonl [--regions=a,b] [--only=loc,loc] [--frames=180]

const GAME := preload("res://world/game_root.gd")

var out_path := ""
var regions: Dictionary = {}
var only: Dictionary = {}
var frames := 180
## Each frame's process step, timed from the tree's process_frame signal (the step's start) to this node's own
## _process, which runs last (the highest process_priority). Headless Godot sleeps between frames in low-processor mode,
## so a frame's wall time would only show that sleep.
var _step_start := 0
var _steps: Array[float] = []
var _timing := false


func _enter_tree() -> void:
	process_priority = 1 << 30
	get_tree().process_frame.connect(func() -> void: _step_start = Time.get_ticks_usec())


func _process(_delta: float) -> void:
	if _timing and _step_start > 0:
		_steps.append((Time.get_ticks_usec() - _step_start) / 1000.0)


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	out_path = str(args.get("out", "user://qa_perf.jsonl"))
	for k: String in str(args.get("regions", "")).split(",", false):
		regions[k] = true
	for k: String in str(args.get("only", "")).split(",", false):
		only[k] = true
	frames = int(args.get("frames", frames))
	SaveSystem.save_dir = "user://qa_saves/%d/" % OS.get_process_id()
	GameSettings.path = SaveSystem.save_dir.path_join("settings.cfg")
	Dice.deterministic = true
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("qa: cannot write %s" % out_path)
		get_tree().quit(2)
		return
	var ids: Array = Compendium.shared().table("locations").keys()
	ids.sort()
	for id: Variant in ids:
		var loc := Compendium.shared().get_entry("locations", str(id))
		var region := str(loc.get("region", ""))
		if region == "test_grounds" or (not regions.is_empty() and not regions.has(region)) \
				or (not only.is_empty() and not only.has(str(id))):
			continue
		var row := await _measure(str(id), region)
		f.store_line(JSON.stringify(row))
		f.flush()
		print("qa perf: %s" % JSON.stringify(row))
	f.close()
	var dir := ProjectSettings.globalize_path(SaveSystem.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)
	get_tree().quit(0)


func _measure(loc_id: String, region: String) -> Dictionary:
	GameState.reset()
	var st := GameState.story
	for pid: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(pid, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = loc_id
	var t0 := Time.get_ticks_usec()
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	var built_frames := 0
	while built_frames < 600:
		await get_tree().process_frame
		built_frames += 1
		var v: Variant = root.get("view")
		if v is LocationView and (v as LocationView).loc_id == loc_id:
			break
	var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
	# The first frames after the place appears (lights, figures, the first AI pass): the hitch a player sees on arrival.
	_steps.clear()
	_timing = true
	for i in 30:
		await get_tree().process_frame
	await get_tree().process_frame
	var settle: Array[float] = _steps.duplicate()
	_steps.clear()
	for i in frames:
		await get_tree().process_frame
	await get_tree().process_frame
	_timing = false
	var wall: Array[float] = _steps.duplicate()
	var row := {"loc": loc_id, "region": region, "build_ms": snappedf(build_ms, 0.1), "build_frames": built_frames,
		"settle_ms_max": _pct(settle, 1.0), "frame_ms_median": _pct(wall, 0.5), "frame_ms_p95": _pct(wall, 0.95),
		"frame_ms_max": _pct(wall, 1.0),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)}
	root.queue_free()
	for i in 3:
		await get_tree().process_frame
	return row


static func _pct(xs: Array[float], q: float) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return snappedf(float(s[mini(s.size() - 1, int(q * (s.size() - 1)))]), 0.01)
