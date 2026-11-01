class_name RitualTrack
extends RefCounted
## The ritual track (plan 5.5, G1): every chapter the party wins brings the Crooked Queen closer, because her prophecy
## wants twelve deaths (the six Fallen, the three hags, the fool and both Druskenvalds). Each death breaks a seal
## (data/ritual/track.json: a seal's `when` is a story condition on the flag its chapter sets). The seals broken pick
## the stage: how wide the moon grins and what colour its light is (the look lane reads grin() and light()), Adela's
## visions, how often the Crooked Man shows himself (story/crooked_man_visits.gd) and how much worse the night roads get
## (CampaignModule.presence_tier: road_day, road_night). Once Kehlenn is bound the moon scowls instead (the track's
## `after`). The engine's `attention` condition reads the seals broken: `attention >= wide` is a stage's name,
## `attention >= 6` a count. Pure logic: it only reads the story's flags.

const DATA := "res://data/ritual/track.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed as Dictionary if parsed is Dictionary else {"seals": [], "stages": []}
	return _data


## Drops the loaded file (tests that swap the track).
static func clear_cache() -> void:
	_data = {}


## Every seal, in the order the book's story usually breaks them: [{id, name, when}].
static func seals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Variant in data().get("seals", []):
		out.append(s as Dictionary)
	return out


## The ids of the seals broken now, in the track's order.
static func broken(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in seals():
		if StoryConditions.check(str(s.get("when", "false")), st):
			out.append(str(s["id"]))
	return out


## How many seals are broken (0 to 12): the engine's `attention`.
static func count(st: StoryState) -> int:
	return broken(st).size()


static func is_broken(st: StoryState, seal_id: String) -> bool:
	return broken(st).has(seal_id)


## Whether Kehlenn has been bound in the moon (the track's `after` holds): the grin is over and the moon scowls.
static func bound(st: StoryState) -> bool:
	var after := data().get("after", {}) as Dictionary
	return not after.is_empty() and StoryConditions.check(str(after.get("when", "false")), st)


## The stages, lowest first: [{id, min, name, grin, light, road_day, road_night, crooked_man, vision}].
static func stages() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Variant in data().get("stages", []):
		out.append(s as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("min", 0)) < int(b.get("min", 0)))
	return out


## The stage the story is at now: the highest whose `min` the seals broken reach, or the scowl once Kehlenn is bound.
static func stage(st: StoryState) -> Dictionary:
	if bound(st):
		return data().get("after", {}) as Dictionary
	return stage_for(count(st))


## The stage `seals_broken` seals reach (ignoring the scowl).
static func stage_for(seals_broken: int) -> Dictionary:
	var out: Dictionary = {}
	for s: Dictionary in stages():
		if seals_broken >= int(s.get("min", 0)):
			out = s
	return out


## The `min` of the stage named `id`, or -1 for a name that is no stage (the engine's `attention >= <name>`).
static func stage_min(id: String) -> int:
	for s: Dictionary in stages():
		if str(s.get("id", "")) == id:
			return int(s.get("min", 0))
	return -1


## How wide the moon grins, 0 (a sliver) to 1 (ear to ear); -1 is the scowl after Kehlenn is bound. For the look lane's moon.
static func grin(st: StoryState) -> float:
	return float(stage(st).get("grin", 0.0))


## The palette colour (art/palette/palette.json) of the moon's light at this stage.
static func light(st: StoryState) -> String:
	return str(stage(st).get("light", "moon_blue"))


## Adela's vision for this stage (her readings and talks put it in with `{tarokka.ritual.vision}`).
static func vision(st: StoryState) -> String:
	return str(stage(st).get("vision", ""))


## The chance (0 to 1) that the Crooked Man shows himself when a visit of his could come (story/crooked_man_visits.gd).
static func crooked_man_chance(st: StoryState) -> float:
	return float(stage(st).get("crooked_man", 0.0))


## The module's field for `ritual.<what>` (CrookedMoonCampaign.field): `stage` (its id), `seals` (the count), `vision`,
## `grin` (a share, two places), `light`, `bound` ("yes" or ""), and `seal.<id>` ("yes" while that seal is broken).
static func field(st: StoryState, what: String) -> String:
	if what.begins_with("seal."):
		return "yes" if is_broken(st, what.trim_prefix("seal.")) else ""
	match what:
		"stage":
			return str(stage(st).get("id", ""))
		"seals":
			return str(count(st))
		"vision":
			return vision(st)
		"grin":
			return "%.2f" % grin(st)
		"light":
			return light(st)
		"bound":
			return "yes" if bound(st) else ""
	return ""
