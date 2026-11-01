class_name Endings
extends RefCounted
## The campaign's endings and epilogues (the engine handbook's campaign contract, "Endings"). Each data/endings/<id>.json
## has a `when`, a `priority`, a narration node and epilogue slides. When the game ends (the `end_game` statement, a
## parley that ends it, a wipe in a final battle, a won fight that leaves the villain destroyed, or an `auto` ending's
## `when` coming true: auto_due) the highest-priority
## ending whose `when` holds is recorded in the flag `campaign_ending`; the ending screen (ui/screens/ending_screen.gd)
## plays its narration and the slides whose `when` holds, then marks the save finished. Pure logic, like all of story/.

const ROOT := "res://data/endings/"
## The flag that records the ending reached (data/flags/endings.json).
const FLAG := "campaign_ending"
## A dark gift whose bearer inherits the villain's place in an epilogue. None in this campaign: {name} is the leader.
const HEIR_GIFT := ""
## The flag a parley's answer is kept in (the engine's name; R24 keeps its answers in the flags below), and the flags that
## end the game instead of starting the battle: in the barrow the party sides with Kehlenn (kehlenn_sided: Kneel to the
## Crooked Queen), or kneels at the goat skull (ct_kneeled: Live Deliciously).
const PARLEY_FLAG := "parley_answer"
const PARLEY_ENDS: Array[String] = []
const PARLEY_END_FLAGS: Array[String] = ["kehlenn_sided", "ct_kneeled"]
## The flag set as the Crooked Tree's final battle begins (CrookedMoonCampaign.final_battle_begun): a wipe after it is All
## Will Be Crooked.
const FINAL_BATTLE_FLAG := "born_king_fight_begun"
## The flag that says the villain's last fight was won; set by the story, read by after_fight.
const VILLAIN_DESTROYED := "villain_destroyed"

static var _table: Dictionary = {}
static var _loaded := false


## Every ending, highest priority first (ties by id).
static func all() -> Array[Dictionary]:
	_load()
	var out: Array[Dictionary] = []
	for id: String in _table:
		out.append(_table[id] as Dictionary)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) > int(b["priority"])
		return str(a["id"]) < str(b["id"]))
	return out


static func get_ending(id: String) -> Dictionary:
	_load()
	return _table.get(id, {}) as Dictionary


## Drops the loaded files (tests that add or change endings).
static func clear_cache() -> void:
	_table.clear()
	_loaded = false


## Adds an ending as if it were a data file (tests and tools).
static func register(ending: Dictionary) -> void:
	_load()
	_table[str(ending["id"])] = ending


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + f))
		if parsed is Dictionary:
			var e := parsed as Dictionary
			_table[str(e.get("id", f.get_basename()))] = e
		else:
			push_error("Endings: %s is not a JSON object" % f)


## The highest-priority ending whose `when` holds now, or {} if none does. An ending the story has already gone on
## past (go_on) is never picked again.
static func pick(st: StoryState) -> Dictionary:
	var past := seen(st)
	for e in all():
		if str(e["id"]) in past:
			continue
		if StoryConditions.check(str(e.get("when", "")), st):
			return e
	return {}


# --- Endings the story goes on past (Moonfall, plan F8 and 5.7) ---------------------------------------------------

## The flag listing the endings the story went on past, comma-separated, oldest first.
const SEEN_FLAG := "endings_seen"


## What an ending offers instead of only The End: {label, flag} from its `continue` (the button's words, and the flag set
## when the player goes on), or {} for an ending that only ends.
static func continues(ending: Dictionary) -> Dictionary:
	var c: Variant = ending.get("continue", {})
	return c as Dictionary if c is Dictionary else {}


## The endings this playthrough has reached and gone on past, oldest first.
static func seen(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	for id: String in str(st.get_flag(SEEN_FLAG, "")).split(",", false):
		out.append(id)
	return out


## The player goes on past the ending reached (its `continue`): the ending is kept in `endings_seen`, its `continue`
## flag is set (Moonfall's start), and `campaign_ending` is cleared, so the game plays on and a later ending can come.
## False when the ending reached offers no way on.
static func go_on(st: StoryState) -> bool:
	var id := reached(st)
	var c := continues(get_ending(id))
	if id == "" or c.is_empty():
		return false
	var past := seen(st)
	if not past.has(id):
		past.append(id)
	st.set_flag(SEEN_FLAG, ",".join(past))
	if str(c.get("flag", "")) != "":
		st.set_flag(str(c["flag"]))
	st.set_flag(FLAG, "")
	return true


## The ending this playthrough reached, or "" while it goes on.
static func reached(st: StoryState) -> String:
	var v: Variant = st.get_flag(FLAG, "")
	return str(v) if v is String else ""


## Ends the game: picks the ending and records it (once; later calls return the same id). "" if no ending holds.
static func request(st: StoryState) -> String:
	var done := reached(st)
	if done != "":
		return done
	var e := pick(st)
	if e.is_empty():
		push_warning("Endings: the game ended but no ending's condition holds")
		return ""
	st.set_flag(FLAG, str(e["id"]))
	return str(e["id"])


## An ending marked `auto: true` whose `when` holds now ends the game without an `end_game` (the moon hitting at zero):
## the highest-priority such one is recorded as request() records it, and its id returned; "" while none holds (or the
## game has ended already).
static func auto_due(st: StoryState) -> String:
	if reached(st) != "":
		return ""
	var past := seen(st)
	for e in all():
		if str(e["id"]) in past:
			continue
		if bool(e.get("auto", false)) and StoryConditions.check(str(e.get("when", "")), st):
			st.set_flag(FLAG, str(e["id"]))
			return str(e["id"])
	return ""


## Whether the parley ended the game (a price paid or the party yielding: no battle).
static func parley_ends(st: StoryState) -> bool:
	for f: String in PARLEY_END_FLAGS:
		if bool(st.get_flag(f, false)):
			return true
	return str(st.get_flag(PARLEY_FLAG, "")) in PARLEY_ENDS


## A location encounter that is a final battle (`"final_battle": "<room id>"`).
static func is_final_battle(spec: Dictionary) -> bool:
	return str(spec.get("final_battle", "")) != ""


## After a fight: a wipe in a final battle, or any won fight that leaves the villain destroyed, ends the game. Returns the
## ending reached, or "" if the game goes on.
static func after_fight(st: StoryState, spec: Dictionary, outcome: String) -> String:
	if outcome == "defeat" and is_final_battle(spec):
		return request(st)
	if outcome == "victory" and bool(st.get_flag(VILLAIN_DESTROYED, false)):
		return request(st)
	return ""


## The party member who carries the heir's gift (the new lord in an epilogue), or null.
static func heir(st: StoryState) -> Character:
	if HEIR_GIFT == "":
		return null
	for ch in st.party:
		if HEIR_GIFT in ch.dark_gifts():
			return ch
	return null


## {name}: the heir's first name (else the leader's); {leader}: the leader's.
static func fill(text: String, st: StoryState) -> String:
	var lead := st.leader_character()
	var who := heir(st)
	if who == null:
		who = lead
	return text.replace("{name}", _first(who)).replace("{leader}", _first(lead))


static func _first(ch: Character) -> String:
	return ch.name.get_slice(" ", 0) if ch != null else "you"


## The epilogue slides to show, in order: this ending's slides whose `when` holds, then those of the ending it takes
## its epilogue from (`epilogue_from`, and so on). A slide's `topic` is shown once (the first that holds), so an
## ending's own slide replaces the inherited one. Last, the party members lost on the way, if any.
## Each slide: {topic, title, text, portrait} with {name} filled in ("{name}" as a portrait is the heir's portrait).
static func slides(ending: Dictionary, st: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var topics := {}
	var seen := {}
	var e := ending
	while not e.is_empty() and not seen.has(str(e.get("id", ""))):
		seen[str(e.get("id", ""))] = true
		for s: Variant in e.get("epilogue", []):
			var slide := s as Dictionary
			var topic := str(slide.get("topic", ""))
			if topic != "" and topics.has(topic):
				continue
			if not StoryConditions.check(str(slide.get("when", "")), st):
				continue
			if topic != "":
				topics[topic] = true
			out.append(_shown(slide, st))
		e = get_ending(str(e.get("epilogue_from", "")))
	if not st.fallen.is_empty():
		var names: Array[String] = []
		for f in st.fallen:
			names.append(str(f.get("name", "")))
		out.append({"topic": "fallen", "title": "The Fallen", "portrait": "",
			"text": "Not everyone who boarded the train walked out of this story. Remember %s." % _list(names)})
	return out


static func _shown(slide: Dictionary, st: StoryState) -> Dictionary:
	var portrait := str(slide.get("portrait", ""))
	if portrait == "{name}":
		var who := heir(st)
		if who == null:
			who = st.leader_character()
		portrait = DialogueRunner.portrait_of(who) if who != null else ""
	return {"topic": str(slide.get("topic", "")), "title": fill(str(slide.get("title", "")), st), "text": fill(str(slide["text"]), st),
		"portrait": portrait}


## "A", "A and B", "A, B and C".
static func _list(names: Array[String]) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]
