class_name HouseFloors
extends RefCounted
## The Crooked House is one place with its four floors in it (data/locations/crooked_house.json, map.floors: Ashwin, 2026-11-02,
## "These can all be a single multi-floor area"). The house's tests still speak of its floors by the places they were
## (crooked_house_first ...): `place(id)` is that floor's share of the house as a location of its own (what stands, hangs, waits
## and leads out on it, its spawns under their old names, its rows), and any other id the place itself.

const PLACE := "crooked_house"
const FLOORS: Array[String] = ["crooked_house_first", "crooked_house_second", "crooked_house_third", "crooked_house_attic"]
## The lists of a location whose entries stand on a square.
const LISTS: Array[String] = ["areas", "doors", "props", "containers", "lights", "traps", "npcs", "encounters", "exits"]

## Where each floor's own map was laid in the house (tools/content/merge_floors.py: its columns' start plus its dx, its dz), so a
## square the tests knew on a floor is found in the house.
const OFFSETS := {"crooked_house_first": Vector2i(0, 0), "crooked_house_second": Vector2i(35, 0),
	"crooked_house_third": Vector2i(73, 1), "crooked_house_attic": Vector2i(129, 1)}

static var _views: Dictionary = {}


## Square `c` of floor `floor_id`'s own old map, in the house.
static func to_house(floor_id: String, c: Vector2i) -> Vector2i:
	return c + (OFFSETS[floor_id] as Vector2i)


static func is_floor(id: String) -> bool:
	return FLOORS.has(id)


## A location by id: a floor of the house as a place of its own, else the location itself.
static func place(id: String) -> Dictionary:
	if not is_floor(id):
		var loc := Compendium.shared().get_entry("locations", id)
		if id == PLACE or loc.is_empty():
			return loc
		# A way into the house leads to the floor it sets the party down on.
		var out := loc.duplicate(true)
		_floor_ways(out)
		return out
	if not _views.has(id):
		_views[id] = _view(id)
	return _views[id] as Dictionary


## Which floor (its old place id) square x of the house lies on.
static func floor_at(x: int) -> String:
	for f: Variant in (house()["map"] as Dictionary)["floors"]:
		var fl := f as Dictionary
		if x >= int(fl["x0"]) and x < int(fl["x0"]) + int(fl["width"]):
			return str(fl["id"])
	return ""


## The floor a spawn of the house sets the party down on.
static func floor_of_spawn(spawn: String) -> String:
	var at: Variant = (house().get("spawns", {}) as Dictionary).get(spawn, null)
	return floor_at(int((at as Array)[0])) if at != null else FLOORS[0]


## The house's name for a floor's spawn ("from_below" on the second floor is "second_from_below").
static func spawn_name(floor_id: String, spawn: String) -> String:
	var i := FLOORS.find(floor_id)
	return spawn if i <= 0 else "%s_%s" % [floor_id.trim_prefix("crooked_house_"), spawn]


static func house() -> Dictionary:
	return Compendium.shared().get_entry("locations", PLACE)


static func _view(id: String) -> Dictionary:
	var h := house()
	var out := h.duplicate(true)
	out["id"] = id
	for key in LISTS:
		var kept: Array = []
		for e: Variant in h.get(key, []):
			if _on(e as Dictionary, id):
				kept.append((e as Dictionary).duplicate(true))
		out[key] = kept
	var spawns := {}
	var prefix := "" if FLOORS.find(id) == 0 else id.trim_prefix("crooked_house_") + "_"
	for name: String in h.get("spawns", {}):
		var at := (h["spawns"] as Dictionary)[name] as Array
		if floor_at(int(at[0])) != id:
			continue
		spawns[name.trim_prefix(prefix) if prefix != "" else name] = at
	out["spawns"] = spawns
	_floor_ways(out)
	# Its rows: the house's, the other floors' squares void.
	var rows: Array = []
	var fl := {}
	for f: Variant in (h["map"] as Dictionary)["floors"]:
		if str((f as Dictionary)["id"]) == id:
			fl = f as Dictionary
	for r: Variant in (h["map"] as Dictionary)["rows"]:
		var row := str(r)
		var kept := ""
		for x in row.length():
			kept += row[x] if x >= int(fl["x0"]) and x < int(fl["x0"]) + int(fl["width"]) else " "
		rows.append(kept)
	(out["map"] as Dictionary)["rows"] = rows
	return out


## Whether entry `e` stands on floor `id`: by its square, its first square, or its first foe's square (a fight with no foes on
## the map, started by a conversation, is on every floor).
static func _on(e: Dictionary, id: String) -> bool:
	var at: Variant = null
	if e.has("cell"):
		at = e["cell"]
	elif e.has("cells") and not (e["cells"] as Array).is_empty():
		at = (e["cells"] as Array)[0]
	elif e.has("monsters") and not (e["monsters"] as Array).is_empty() and ((e["monsters"] as Array)[0] as Dictionary).has("cell"):
		at = ((e["monsters"] as Array)[0] as Dictionary)["cell"]
	if at == null:
		return true
	return floor_at(int((at as Array)[0])) == id


## The exits of `loc` into the house lead to the floors they set the party down on, at the floor's own spawn name.
static func _floor_ways(loc: Dictionary) -> void:
	for e: Variant in loc.get("exits", []):
		var ex := e as Dictionary
		if str(ex["to"]) == PLACE:
			var there := floor_of_spawn(str(ex.get("spawn", "default")))
			ex["to"] = there
			var p2 := "" if FLOORS.find(there) == 0 else there.trim_prefix("crooked_house_") + "_"
			ex["spawn"] = str(ex.get("spawn", "default")).trim_prefix(p2)
