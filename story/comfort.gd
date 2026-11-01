class_name Comfort
extends RefCounted
## Comfort settings and content notes (plan 3 and 13.6, G9; data/comfort/comfort.json). Five topics (burning alive,
## surgery and needles, insects, harm to children, hanging) can each be turned up for a playthrough with the option
## `show_<topic>`; they start off, so comfort is on by default. Scenes carry them in data: a cutscene take or Narrator
## variant written for the full version has `option:show_<topic>` in its `when`, and the softened one (a silhouette,
## sound, a cut away) follows it. Each region's loading card names the topics its chapter holds. Pure logic.

const DATA := "res://data/comfort/comfort.json"
const PREFIX := "show_"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = parsed as Dictionary if parsed is Dictionary else {"topics": [], "notes": {}}
	return _data


static func clear_cache() -> void:
	_data = {}


## The topics: [{id, name, tip}].
static func topics() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Variant in data().get("topics", []):
		out.append(t as Dictionary)
	return out


static func topic(id: String) -> Dictionary:
	for t: Dictionary in topics():
		if str(t.get("id", "")) == id:
			return t
	return {}


## The playthrough option that shows `topic` in full.
static func option_key(topic_id: String) -> String:
	return PREFIX + topic_id


## Whether scenes with `topic` are softened in this playthrough (true unless the player turned it up).
static func softened(st: StoryState, topic_id: String) -> bool:
	return st == null or not bool(st.options.get(option_key(topic_id), false))


## Turns `topic` up (shown in full) or back down (softened).
static func set_shown(st: StoryState, topic_id: String, shown: bool) -> void:
	st.options[option_key(topic_id)] = shown


## The settings rows for the comfort topics: [{key, label, tip, default}], `key` a playthrough option (st.options). The
## pause menu's Content rows show one checkbox each, "Show <name>", off by default.
static func options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in topics():
		out.append({"key": option_key(str(t["id"])), "label": "Show %s" % str(t.get("name", t["id"])).to_lower(),
			"tip": str(t.get("tip", "")), "default": false})
	return out


## The topic ids `region`'s chapter holds.
static func region_topics(region: String) -> Array[String]:
	var out: Array[String] = []
	var note := (data().get("notes", {}) as Dictionary).get(region, {}) as Dictionary
	for t: Variant in note.get("topics", []):
		out.append(str(t))
	return out


## The line a region's loading card shows ("" for a region with no notes): "Content: burning alive, harm to children.
## Restless dead, a train wreck." Topics the player has softened say so.
static func note(region: String, st: StoryState = null) -> String:
	var n := (data().get("notes", {}) as Dictionary).get(region, {}) as Dictionary
	if n.is_empty():
		return ""
	var names: Array[String] = []
	for id: String in region_topics(region):
		var nm := str(topic(id).get("name", id)).to_lower()
		names.append(nm + (" (softened)" if softened(st, id) else ""))
	var parts: Array[String] = []
	if not names.is_empty():
		parts.append("Content: %s." % ", ".join(names))
	if str(n.get("also", "")) != "":
		parts.append(str(n["also"]))
	return " ".join(parts)
