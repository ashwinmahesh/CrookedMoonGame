extends Node
## Which creatures the campaign spawns have a finished 3D model (Ashwin, 2026-11-03: the Wildpyre and the Soulfire Stoker showed a
## placeholder). Every monster an encounter spawns (the places' own and data/encounters) and every NPC a place stands, by the art
## id the game draws it with (CombatToken.monster_art, an NPC's `sprite` else its id): "model" (FigureModels.has), "stand_in" (a
## sprite while the model isn't there: FigureModels.stand_in), "sprite" (an old 2D sprite) or "none" (the generic placeholder).
##   make figure-audit            (headless; prints the lists and writes captures/qa/figure_audit.json, or OUT=dir)
## Args after --: --out=/abs/figure_audit.json


func _ready() -> void:
	var out_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.get_slice("=", 1)
	var comp := Compendium.shared()
	var monsters: Dictionary = {}   # art id -> {monster, places: [..]}
	var npcs: Dictionary = {}
	for loc: Dictionary in comp.all("locations"):
		var lid := str(loc["id"])
		for n: Variant in loc.get("npcs", []):
			var spec := n as Dictionary
			var nid := str(spec.get("npc", ""))
			var art := str(comp.get_entry("npcs", nid).get("sprite", nid))
			_add(npcs, art, nid, lid)
		for e: Variant in loc.get("encounters", []):
			for m: Variant in (e as Dictionary).get("monsters", []):
				_add_monster(monsters, comp, m as Dictionary, lid)
	for enc: Dictionary in comp.all("encounters"):
		for m: Variant in enc.get("monsters", []):
			_add_monster(monsters, comp, m as Dictionary, "encounter:" + str(enc.get("id", "")))
	var report := {"monsters": _tiers(monsters), "npcs": _tiers(npcs)}
	for kind: String in report:
		var t := report[kind] as Dictionary
		print("%s: %d with a model, %d on a stand-in sprite, %d on an old sprite, %d with nothing" % [kind, (t["model"] as Array).size(),
			(t["stand_in"] as Array).size(), (t["sprite"] as Array).size(), (t["none"] as Array).size()])
		for tier: String in ["stand_in", "sprite", "none"]:
			for row: Variant in t[tier]:
				print("  [%s] %s (%s) in %s" % [tier, (row as Dictionary)["art"], (row as Dictionary)["id"], str((row as Dictionary)["places"]).left(110)])
	if out_path != "":
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	get_tree().quit()


func _add_monster(into: Dictionary, comp: Compendium, spec: Dictionary, place: String) -> void:
	var mid := str(spec.get("monster", ""))
	if mid == "":
		return
	var data := comp.monster_data(mid).duplicate()
	if spec.has("art"):
		data["art"] = spec["art"]   # a named foe drawn as itself
	_add(into, CombatToken.monster_art(data), mid, place)


func _add(into: Dictionary, art: String, id: String, place: String) -> void:
	if not into.has(art):
		into[art] = {"id": id, "ids": [], "places": []}
	if not id in (into[art]["ids"] as Array):
		(into[art]["ids"] as Array).append(id)
	if not place in (into[art]["places"] as Array) and (into[art]["places"] as Array).size() < 6:
		(into[art]["places"] as Array).append(place)


func _tiers(seen: Dictionary) -> Dictionary:
	var t := {"model": [], "stand_in": [], "sprite": [], "none": []}
	for art: String in seen:
		var row := {"art": art, "id": seen[art]["id"], "ids": seen[art]["ids"], "places": seen[art]["places"]}
		if FigureModels.has(art):
			(t["model"] as Array).append(row)
		elif FigureModels.stand_in(art) != "":
			(t["stand_in"] as Array).append(row)
		elif ArtPaths.exists("art/sprites/%s/walk.tres" % art):
			(t["sprite"] as Array).append(row)
		else:
			(t["none"] as Array).append(row)
	return t
