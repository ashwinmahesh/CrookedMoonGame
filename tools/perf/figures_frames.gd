extends Node
## What a crowd of 3D figures costs (the engine's ModelFigure): the quick-start party on Barrow Hill at the play camera,
## then a crowd of `--count` people around them (default 60), drawn as the manifest's 3D figures (each model in turn,
## half walking on the spot, half idle) or as 2D villagers, and nobody. The three take turns, `--rounds` times
## (default 3), so a busy Mac drifts across all of them alike; each sample is `--frames` frames after a warm-up.
##   make capture SCENE=res://tools/perf/figures_frames.tscn NAME=perf/figures ARGS='--count=60 --rounds=3 --samples=240'
## Prints, for each kind: mean and 95th-percentile frame time (wall clock: a capture window draws each frame itself, so
## it holds the whole frame), the draw calls and triangles a frame, each the median over the rounds; vsync off and no
## frame cap while it measures. A capture window reports no GPU time.

const GAME := preload("res://world/game_root.gd")
const PLACE := "ghostlight_boarding"


func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return default


func capture_shots(tool: Node, out: String) -> void:
	var count := int(_arg("count", "60"))
	var rounds := int(_arg("rounds", "3"))
	var frames := int(_arg("samples", "240"))
	GameState.reset()
	var st := GameState.story
	for id: String in GAME.NEW_GAME_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = PLACE
	st.minute_of_day = 8 * 60
	Dice.reseed(7)
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await tool.call("wait_frames", 150)
	var view := game.get("view") as LocationView
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var results := {"none": [], "models": [], "sprites": []}
	for r in rounds:
		for kind: String in ["none", "models", "sprites"]:
			var crowd := _crowd(view, kind, count)
			await tool.call("wait_frames", 60)
			results[kind].append(await _sample(tool, vp, frames))
			if r == 0:
				tool.call("_shot", "%s_%s.png" % [out, kind])
			for t: Node in crowd:
				t.queue_free()
			await tool.call("wait_frames", 10)
	print("figures_frames: %d people, %d rounds of %d frames, 1600x900" % [count, rounds, frames])
	for kind: String in results:
		var med := {}
		for key: String in ["mean", "p95", "draws", "tris"]:
			var vals: Array = (results[kind] as Array).map(func(s: Dictionary) -> float: return float(s[key]))
			vals.sort()
			med[key] = vals[vals.size() / 2]
		print("figures_frames: %-8s frame %.2f ms (p95 %.2f), %d draw calls, %d k triangles a frame" % [kind,
			med["mean"], med["p95"], int(med["draws"]), int(med["tris"] / 1000.0)])
	Engine.max_fps = 60


## `count` people in rings round the party's leader: the manifest's figures in turn (or 2D villagers), every other one
## walking on the spot. None for "none".
func _crowd(view: LocationView, kind: String, count: int) -> Array:
	var out: Array = []
	if kind == "none":
		return out
	var ids := (ArtPaths.json(FigureModels.MANIFEST_JSON).get("figures", {}) as Dictionary).keys()
	ids.sort()
	var mid := view.board.cell_center(view.leader().cell)
	for i in count:
		var ring := 2.0 + float(i / 12)
		var angle := TAU * float(i % 12) / 12.0 + float(i / 12) * 0.26
		var at := mid + Vector3(cos(angle), 0.0, sin(angle)) * ring
		var cell := Vector2i(floori(at.x), floori(at.z))
		var ch := Pregens.build("rook_coldwake", 1)
		var cb := Combatant.new(ch, &"neutral", cell)
		var tok := CombatToken.create(cb, str(ids[i % ids.size()]) if kind == "models" else "villager")
		tok.position = Vector3(at.x, view.board.cell_center(cell).y, at.z)
		view.add_child(tok)
		tok.face(Vector2(-cos(angle), -sin(angle)), i % 2 == 0, 0.6)
		out.append(tok)
	return out


## Frame times over `frames` frames: mean and 95th percentile (ms, wall clock), and the mean draw calls and triangles.
func _sample(tool: Node, _vp: RID, frames: int) -> Dictionary:
	var times: Array[float] = []
	var draws := 0.0
	var tris := 0.0
	var last := Time.get_ticks_usec()
	for i in frames:
		await tool.call("wait_frames", 1)
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var sorted := times.duplicate()
	sorted.sort()
	var mean := 0.0
	for t in times:
		mean += t
	return {"mean": mean / frames, "p95": sorted[int(frames * 0.95)], "draws": draws / frames, "tris": tris / frames}
