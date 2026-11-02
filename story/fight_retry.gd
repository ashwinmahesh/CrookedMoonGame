class_name FightRetry
extends RefCounted
## A wipe in some fights is a retry, not a game over (package R10 sections 3 and 10 for the Ghostlight Locomotive, R12 section 1 for
## the Crooked House, where every fight is a no-exit fight). data/fight_retries.json lists the fights; the world asks `rule_for` when
## a fight is lost, and if there is a rule the party is put back on its feet (`restore`), the Narrator speaks over it (`keys`), the
## party goes back to the room's entry (`spawn_for`, when the rule names spawns) and the same fight begins afresh.

const PATH := "res://data/fight_retries.json"

static var _rules: Array = []
static var _read := false


## The rules in force: data/fight_retries.json's, or the ones a test put in place.
static func rules() -> Array:
	if not _read:
		_read = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_rules = (parsed as Dictionary).get("rules", []) as Array if parsed is Dictionary else []
	return _rules


## Puts `table` ({"rules": [...]}, the file's shape) in place of the file (tests); null reads the file again.
static func use_table(table: Variant) -> void:
	_read = table is Dictionary
	_rules = (table as Dictionary).get("rules", []) as Array if table is Dictionary else []


## The rule for a lost fight (the encounter's data) in `location_id`, or {} when the wipe is a game over.
static func rule_for(spec: Dictionary, location_id: String) -> Dictionary:
	var id := str(spec.get("id", ""))
	if id == "":
		return {}
	for r: Variant in rules():
		var rule := r as Dictionary
		if id in (rule.get("fights", []) as Array):
			return rule
		var prefix := str(rule.get("prefix", ""))
		if prefix != "" and id.begins_with(prefix):
			var where := rule.get("locations", []) as Array
			if where.is_empty() or location_id in where:
				return rule
	return {}


## Whether a lost fight retries.
static func applies(spec: Dictionary, location_id: String) -> bool:
	return not rule_for(spec, location_id).is_empty()


## The entry the retry begins: the rule's `restart`, else the fight that was lost.
static func restart_id(rule: Dictionary, spec: Dictionary) -> String:
	return str(rule.get("restart", spec.get("id", "")))


## The Narrator keys to try over the retry, in order, with {fight} the lost fight's id.
static func keys(rule: Dictionary, spec: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in rule.get("keys", []):
		out.append(str(k).replace("{fight}", str(spec.get("id", ""))))
	return out


## The spawn the party goes back to in `location`, the first of the rule's list for that place that the map has, "" when the rule
## names none (the party stays where it stands). In a multi-floor place (map.floors) with `floor` given, the first of the list on
## that floor: a wipe on a floor of the Crooked House begins the fight again at that floor's entry.
static func spawn_for(rule: Dictionary, location_id: String, location: Dictionary, floor: int = -1) -> String:
	var wanted := (rule.get("spawns", {}) as Dictionary).get(location_id, []) as Array
	if wanted.is_empty():
		return ""
	var have := location.get("spawns", {}) as Dictionary
	var floors := ((location.get("map", {}) as Dictionary).get("floors", []) as Array)
	for s: Variant in wanted:
		if not have.has(str(s)):
			continue
		if floor >= 0 and floor < floors.size():
			var x := int((have[str(s)] as Array)[0])
			var fl := floors[floor] as Dictionary
			if x < int(fl["x0"]) or x >= int(fl["x0"]) + int(fl["width"]):
				continue
		return str(s)
	return "default"


## Puts the party back as they were for the fight: the fallen alive, everyone at full Hit Points with their powers back (as after
## a Long Rest), no hold or effect of the fight left on them. Bless from a reading and other lasting effects stay. Whoever was
## already dead when the fight began (`dead_before`, from `dead_now` as it started) stays dead: the retry undoes this fight only.
static func restore(st: StoryState, rule: Dictionary, dead_before: Array[Character] = []) -> void:
	for ch in st.party:
		if ch.dead and ch in dead_before:
			continue
		if ch.dead:
			Services.bring_back(st, ch, true, false, "the retry")
		ch.finish_long_rest()
		EncounterSetup.clear_fight_effects(ch)
	var flag := str(rule.get("count_flag", ""))
	if flag != "":
		st.set_flag(flag, int(st.get_flag(flag, 0)) + 1)


## The party members dead right now (as a fight begins), for `restore`.
static func dead_now(st: StoryState) -> Array[Character]:
	var out: Array[Character] = []
	for ch in st.party:
		if ch.dead:
			out.append(ch)
	return out


## What a retry that began a different entry (`restart`) leaves of the fight that was lost: that one is over, not still
## "started" (RestRules.unfinished_fights would otherwise refuse every rest there once the retry is won).
static func close_lost(st: StoryState, location_id: String, rule: Dictionary, spec: Dictionary) -> void:
	var lost := str(spec.get("id", ""))
	if lost == "" or restart_id(rule, spec) == lost:
		return
	var fights := st.loc_state(location_id).get("encounters", {}) as Dictionary
	if str(fights.get(lost, "")) == "started":
		fights[lost] = true
