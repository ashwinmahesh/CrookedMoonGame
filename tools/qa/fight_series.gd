extends Node
## The fight series (QA lane): every fight in the places' data, begun the way the game begins it (LocationView, its board,
## its scenery, the playthrough's difficulty), played to the end by the engine's PartyAutopilot for the companions the
## new game starts with, on fixed seeds and at each difficulty. One JSON line per fight goes to --out; tools/qa/qa.py
## starts it (sharded over a few processes) and writes the win-rate table.
##
## Args after --: --out=/abs/fights.jsonl [--seeds=1-8] [--modes=story,balanced,tactician,honour] [--only=loc:fight,loc:fight]
## [--regions=a,b] [--levels=/abs/levels.json] [--shard=i/n] [--rounds=30] [--play=sharp|full|plain]
##
## The party's level at a fight: the level the story bot reached it at (--levels, written by story_bot.gd), else the
## chapter's level from the chapter packages' table (REGION_LEVEL). Every version of a fight (entries sharing an id with
## different `when`s) is played as its own row, each at the level its `when` asks for when it names one.

const GAME := preload("res://world/game_root.gd")
## The chapter packages' "Order and levels" table: the level a party arrives at each region with.
const REGION_LEVEL := {
	"ghostlight_express": 1, "wickermoor": 3, "crooked_house": 3, "foxwillow": 5, "crimson_monastery": 5, "dawns_gate": 5,
	"drowned_crossroads": 5, "skitterdeep_mine": 6, "memorys_rest": 7, "hartsblight_forest": 8, "maidenmist_cemetery": 9,
	"crooked_nightmare": 11,
}
const SKIP_REGIONS := ["test_grounds"]

var out_path := ""
var seeds: Array[int] = []
var modes: Array[String] = ["story", "balanced", "tactician", "honour"]
var only: Dictionary = {}
var regions: Dictionary = {}
var levels: Dictionary = {}
var shard := 0
var shards := 1
var max_rounds := 30
var play := "auto"
var _out: FileAccess


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	out_path = str(args.get("out", "user://qa_fights.jsonl"))
	seeds = _range(str(args.get("seeds", "1-8")))
	if args.has("modes"):
		modes.assign(str(args["modes"]).split(",", false))
	for k: String in str(args.get("only", "")).split(",", false):
		only[k] = true
	for k: String in str(args.get("regions", "")).split(",", false):
		regions[k] = true
	if args.has("levels") and FileAccess.file_exists(str(args["levels"])):
		levels = JSON.parse_string(FileAccess.get_file_as_string(str(args["levels"]))) as Dictionary
	if args.has("shard"):
		shard = int(str(args["shard"]).get_slice("/", 0))
		shards = maxi(1, int(str(args["shard"]).get_slice("/", 1)))
	max_rounds = int(args.get("rounds", max_rounds))
	play = str(args.get("play", play))
	# Never the player's saves or settings: a folder of this process's own, removed at the end (as the test runner does).
	SaveSystem.save_dir = "user://qa_saves/%d/" % OS.get_process_id()
	GameSettings.path = SaveSystem.save_dir.path_join("settings.cfg")
	Dice.deterministic = true
	_out = FileAccess.open(out_path, FileAccess.WRITE)
	if _out == null:
		push_error("qa: cannot write %s" % out_path)
		get_tree().quit(2)
		return
	await _run()
	_out.close()
	print("qa: fight series done")
	_clean_saves()
	get_tree().quit(0)


static func _clean_saves() -> void:
	var dir := ProjectSettings.globalize_path(SaveSystem.save_dir)
	if DirAccess.dir_exists_absolute(dir):
		for f: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)


static func _range(s: String) -> Array[int]:
	var out: Array[int] = []
	for part: String in s.split(",", false):
		if part.contains("-"):
			for i in range(int(part.get_slice("-", 0)), int(part.get_slice("-", 1)) + 1):
				out.append(i)
		else:
			out.append(int(part))
	return out


## Every fight version in the places' data: {loc, id, version, spec, region}, in a stable order.
func _fights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array = Compendium.shared().table("locations").keys()
	ids.sort()
	for loc_id: Variant in ids:
		var loc := Compendium.shared().get_entry("locations", str(loc_id))
		var region := str(loc.get("region", ""))
		if region in SKIP_REGIONS or (not regions.is_empty() and not regions.has(region)):
			continue
		var seen := {}
		for en: Variant in loc.get("encounters", []):
			var spec := en as Dictionary
			var id := str(spec["id"])
			var version := int(seen.get(id, 0))
			seen[id] = version + 1
			if not only.is_empty() and not only.has("%s:%s" % [loc_id, id]) and not only.has(id):
				continue
			out.append({"loc": str(loc_id), "id": id, "version": version, "spec": spec, "region": region})
	return out


## The level the party fights `f` at (see the header).
func _level_for(f: Dictionary) -> int:
	var key := "%s:%s" % [f["loc"], f["id"]]
	var when := str((f["spec"] as Dictionary).get("when", ""))
	var asked := _level_in_when(when)
	if asked > 0:
		return asked
	if levels.has(key):
		return int(levels[key])
	if levels.has("%s:%s" % [f["loc"], str(f["id"]).trim_suffix("_edge")]):
		return int(levels["%s:%s" % [f["loc"], str(f["id"]).trim_suffix("_edge")]])
	return int(REGION_LEVEL.get(str(f["region"]), 3))


## A `when` naming the party's level ("party.level < 5", "party.level >= 7"): a level inside what it asks for.
static func _level_in_when(when: String) -> int:
	var re := RegEx.create_from_string("level\\s*(<=|>=|<|>|==)\\s*(\\d+)")
	var m := re.search(when)
	if m == null:
		return 0
	var n := int(m.get_string(2))
	match m.get_string(1):
		"<":
			return n - 1
		">":
			return n + 1
		_:
			return n


func _run() -> void:
	var all := _fights()
	print("qa: %d fight versions, shard %d/%d" % [all.size(), shard, shards])
	var n := 0
	for i in all.size():
		if i % shards != shard:
			continue
		var f := all[i]
		for mode in modes:
			for s in seeds:
				var row := await _play_one(f, mode, s)
				_out.store_line(JSON.stringify(row))
				_out.flush()
				n += 1
	print("qa: %d fights played" % n)


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


func _play_one(f: Dictionary, mode: String, seed_value: int) -> Dictionary:
	var level := _level_for(f)
	var row := {"loc": f["loc"], "id": f["id"], "version": f["version"], "region": f["region"], "mode": mode, "seed": seed_value,
		"level": level, "when": str((f["spec"] as Dictionary).get("when", "")), "quest": (f["spec"] as Dictionary).get("quest", {})}
	var t0 := Time.get_ticks_msec()
	GameState.reset()
	var st := GameState.story
	# The heroes a player run picked on the roster page (levels.json "_party", written by qa.py act1), else the quick start's.
	var party: Array = levels.get("_party", GAME.NEW_GAME_PARTY) as Array
	for pid: Variant in party:
		var ch := Pregens.build(str(pid), level)
		ch.finish_long_rest()
		st.party.append(ch)
	st.location = str(f["loc"])
	st.options["difficulty"] = mode
	Dice.reseed(seed_value * 7919 + int(f["version"]))
	var root := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(12)
	var view := root.get("view") as LocationView
	if view == null or view.loc_id != str(f["loc"]):
		row["outcome"] = "no_view"
	elif not LocationFights.start_encounter(view, str(f["id"]), f["spec"] as Dictionary):
		row["outcome"] = "not_started"
	else:
		await _frames(2)
		var e: Encounter = view.combat_view.e if view.combat_view != null else null
		if e == null:
			row["outcome"] = "no_encounter"
		else:
			var ap := PartyAutopilot.new(e)
			match play:
				"plain":
					PartyAutopilot.sharp = false
					PartyAutopilot.full = false
				"sharp":
					PartyAutopilot.sharp = true
					PartyAutopilot.full = false
				"full":
					PartyAutopilot.sharp = true
					PartyAutopilot.full = true
				_:
					# As the engine's series play them: bosses at full ability, the rest sharp (testing.md section 5).
					PartyAutopilot.sharp = true
					PartyAutopilot.full = e.combatants.any(func(c: Combatant) -> bool:
						return c.side == &"enemy" and c.creature is Monster and Difficulty.is_boss(c.creature as Monster))
			row["play"] = "full" if PartyAutopilot.full else ("sharp" if PartyAutopilot.sharp else "plain")
			var r := ap.run(max_rounds)
			row.merge(r, true)
			var dead := 0
			var hp_left := 0
			var hp_max := 0
			for c in e.combatants:
				if c.side == &"party":
					dead += 1 if c.creature.dead else 0
					hp_left += maxi(0, c.creature.hp)
					hp_max += c.creature.max_hp()
			row["deaths"] = dead
			row["hp_left"] = snappedf(float(hp_left) / maxf(1.0, float(hp_max)), 0.01)
			row["foes"] = e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy").size()
	row["ms"] = Time.get_ticks_msec() - t0
	root.queue_free()
	await _frames(1)
	return row
