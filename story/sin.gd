class_name Sin
extends RefCounted
## Sin (plan 5.5 and 13.10, G4; ours, built from the book's pieces; data/ritual/sin.json): a hidden tally of what the party
## has done in the dark. Accepting a Crooked Bargain, a deal at Mister Crossroads's shack, the Horned King's offers and his
## bargain at death's door, killing innocents and betraying a Connection all feed it. Its tier decides how hard the Horned
## King's temptations press, gives Kehlenn Ritual Points against the final sacrifice (story/sacrifice_ritual.gd) and colours
## the epilogue. Nothing on screen shows the number. Pure logic: it only reads the party and the story's flags.

const DATA := "res://data/ritual/sin.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed as Dictionary if parsed is Dictionary else {"sources": [], "tiers": []}
	return _data


static func clear_cache() -> void:
	_data = {}


## What each source adds now: {source id: points}.
static func by_source(st: StoryState) -> Dictionary:
	var out := {}
	for s: Variant in data().get("sources", []):
		var src := s as Dictionary
		var n := 0
		if str(src.get("count", "")) == "dark_gifts":
			n = _dark_gifts(st)
		elif src.has("flag"):
			var v: Variant = st.get_flag(str(src["flag"]), 0)
			n = int(v) if (v is int or v is float) else 0
		out[str(src["id"])] = maxi(0, n) * int(src.get("per", 1))
	return out


## The party's Sin now.
static func total(st: StoryState) -> int:
	var sum := 0
	for v: Variant in by_source(st).values():
		sum += int(v)
	return sum


## The tiers, lowest first: [{id, min, press, ritual_points}].
static func tiers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Variant in data().get("tiers", []):
		out.append(t as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("min", 0)) < int(b.get("min", 0)))
	return out


## The tier the party's Sin reaches.
static func tier(st: StoryState) -> Dictionary:
	var points := total(st)
	var out: Dictionary = {}
	for t: Dictionary in tiers():
		if points >= int(t.get("min", 0)):
			out = t
	return out


static func tier_index(id: String) -> int:
	var list := tiers()
	for i in list.size():
		if str(list[i].get("id", "")) == id:
			return i
	return -1


## How hard the Horned King's temptations press (0 to 4): his offers' scenes read it (`tarokka.sin.press == 3`).
static func press(st: StoryState) -> int:
	return int(tier(st).get("press", 0))


## The Ritual Points the party's Sin gives Kehlenn against the final sacrifice (on top of the sacrifice's base).
static func ritual_points(st: StoryState) -> int:
	return int(tier(st).get("ritual_points", 0))


## The module's field for `sin.<what>` (CrookedMoonCampaign.field): `tier` (its id), `press`, `points` (Kehlenn's from
## Sin), `total`, and `at_least.<tier>` ("yes" when the party's tier is that one or worse).
static func field(st: StoryState, what: String) -> String:
	if what.begins_with("at_least."):
		var want := tier_index(what.trim_prefix("at_least."))
		return "yes" if want >= 0 and tier_index(str(tier(st).get("id", ""))) >= want else ""
	match what:
		"tier":
			return str(tier(st).get("id", ""))
		"press":
			return str(press(st))
		"points":
			return str(ritual_points(st))
		"total":
			return str(total(st))
	return ""


## Crooked Bargains carried by every hero the party has: in it, on the bench and at camp.
static func _dark_gifts(st: StoryState) -> int:
	var n := 0
	var seen := {}
	for list: Array in [st.party, st.bench, st.camp_company]:
		for c: Variant in list:
			var ch := c as Character
			if ch == null or seen.has(ch):
				continue
			seen[ch] = true
			n += ch.dark_gifts().size()
	return n
