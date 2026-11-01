class_name CrookedMoonVisits
extends RefCounted
## The Crooked Moon's visits (plan 5.5, G1; data/ritual/visits.json): the Crooked Man, the queen's mouthpiece and only an
## apparition until the Wicker Man, shows himself on the roads, at the village's edge and in dreams at rest; Gorthos and
## the Horned King are second and third voices. How often the Crooked Man comes is the ritual track's stage (its
## `crooked_man` chance, story/ritual_track.gd); the others carry their own `chance`. None of them comes to blows: an
## apparition is told by the Narrator (`visit:<id>`, narrative/narrator/crooked_moon_visits.dialogue) or plays a
## conversation (`dialogue`). Pure logic: the game root asks due() when a visit could come and plays what it returns.
## What has come is kept in the flag `_moon_visits` ({last: minute, seen: {id: [minutes]}}), so a reload never repeats one.

const DATA := "res://data/ritual/visits.json"
const MEMORY := "_moon_visits"
## What a visit is on: a leg of a journey, arriving somewhere, a night's rest.
const ON: Array[String] = ["road", "arrive", "rest"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed as Dictionary if parsed is Dictionary else {"visits": []}
	return _data


## Drops the loaded file (tests).
static func clear_cache() -> void:
	_data = {}


## Uses `d` in place of the data file (tests).
static func use(d: Dictionary) -> void:
	_data = d


static func visits() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Variant in data().get("visits", []):
		out.append(v as Dictionary)
	return out


static func get_visit(id: String) -> Dictionary:
	for v: Dictionary in visits():
		if str(v.get("id", "")) == id:
			return v
	return {}


static func _memory(st: StoryState) -> Dictionary:
	var m: Variant = st.flags.get(MEMORY, {})
	return m as Dictionary if m is Dictionary else {}


## The game minutes each time `id` has come, oldest first.
static func times_seen(st: StoryState, id: String) -> Array[int]:
	var out: Array[int] = []
	for t: Variant in (_memory(st).get("seen", {}) as Dictionary).get(id, []):
		out.append(int(t))
	return out


## Whether `v` may come now, before its chance is rolled: it's on `on`, its condition holds, it hasn't used up its `once`
## or `max`, its own cooldown has passed, and so has the gap since the last visit of any kind.
static func may_come(st: StoryState, v: Dictionary, on: String) -> bool:
	if str(v.get("on", "")) != on:
		return false
	var now := st.total_minutes()
	var seen := times_seen(st, str(v.get("id", "")))
	if bool(v.get("once", false)) and not seen.is_empty():
		return false
	if v.has("max") and seen.size() >= int(v["max"]):
		return false
	if not seen.is_empty() and now - seen[seen.size() - 1] < int(float(v.get("cooldown_hours", 0.0)) * 60.0):
		return false
	var mem := _memory(st)
	if mem.has("last") and now - int(mem["last"]) < int(float(data().get("gap_hours", 0.0)) * 60.0):
		return false
	return StoryConditions.check(str(v.get("when", "")), st)


## The chance (0 to 1) that `v` comes when it may: the Crooked Man's is the ritual track's stage; anyone else's is its own.
static func chance(st: StoryState, v: Dictionary) -> float:
	if v.has("chance"):
		return float(v["chance"])
	if str(v.get("who", "")) == "crooked_man":
		return RitualTrack.crooked_man_chance(st)
	return 0.0


## The visit that comes now on `on` (road, arrive, rest), or {}: the first in the file that may come, if the d100 falls
## within its chance. A visit that comes is remembered at once. `dice` is the story's DiceRoller.
static func due(st: StoryState, on: String, dice: DiceRoller) -> Dictionary:
	for v: Dictionary in visits():
		if not may_come(st, v, on):
			continue
		var c := chance(st, v)
		if c <= 0.0:
			continue
		var d100 := dice.roll_one(100, "A visit under the Crooked Moon (%s)" % str(v.get("who", "")))
		if d100 > roundi(c * 100.0):
			return {}
		note(st, str(v["id"]))
		return v
	return {}


## Remembers that `id` came now.
static func note(st: StoryState, id: String) -> void:
	var mem := _memory(st).duplicate(true)
	var seen := mem.get("seen", {}) as Dictionary
	var list: Array = (seen.get(id, []) as Array).duplicate()
	list.append(st.total_minutes())
	seen[id] = list
	mem["seen"] = seen
	mem["last"] = st.total_minutes()
	st.flags[MEMORY] = mem


## The Narrator's trigger that tells `v` ("" when it plays a conversation instead).
static func narrator_key(v: Dictionary) -> String:
	return "" if str(v.get("dialogue", "")) != "" else "visit:" + str(v.get("id", ""))


## A road visit waits to be told until the party arrives (the journey never stops for an apparition): the game root keeps
## its id here and tells it on arriving.
const PENDING := "pending"


static func hold_for_arrival(st: StoryState, id: String) -> void:
	var mem := _memory(st).duplicate(true)
	mem[PENDING] = id
	st.flags[MEMORY] = mem


## The road visit waiting to be told, taken (so it's told once), or {}.
static func take_pending(st: StoryState) -> Dictionary:
	var mem := _memory(st).duplicate(true)
	var id := str(mem.get(PENDING, ""))
	if id == "":
		return {}
	mem.erase(PENDING)
	st.flags[MEMORY] = mem
	return get_visit(id)
