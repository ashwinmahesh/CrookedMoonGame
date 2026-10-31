class_name CrookedMoonCampaign
extends CampaignModule
## The Crooked Moon's answers to the story engine (CampaignModule, named in data/campaign.json). The base class answers for a game with
## no reading, no watching villain, ordinary spells and no ending of its own; plan G1 fills this in as the chapters need each part.
## So far: the Fated Tarot, Adela's reading of the party's cards (R10). The ritual track, the Crooked Moon's gaze, the endings, the
## parley before the Born King, fight barks and achievements come with the packages that use them.

const OUTCOMES := "res://data/tarot/outcomes.json"

static var _outcomes: Dictionary = {}


## The reading: one card for every hero at the table, in party order (slots hero_1 to hero_N), drawn once from the playthrough's seed so
## a reload never changes it. Each slot's card id is also a string flag, tarot_hero_N, which conversations and places read.
func ensure_drawn(st: StoryState) -> void:
	if not st.tarokka.is_empty():
		return
	st.tarokka = ReadingDeck.draw(ReadingDeck.hero_slots(st.party.size()), st.playthrough_seed)
	for slot: String in st.tarokka:
		st.set_flag("tarot_" + slot, str(st.tarokka[slot]))


## One slot as the card face shows it: the card, whose it is, and Adela's verse. The dialogue's `reading read` asks this once for each
## card it turns, and the hero whose card it is takes part in the reading, so they gain Bless for an hour (the book: all who take
## part). The story engine has no hook for "the reading is finished"; this call is the nearest thing it makes, and no time passes
## between the cards, so every hero's hour starts together.
func reading(slot: String, st: StoryState) -> Dictionary:
	var card_id := str(st.tarokka.get(slot, ""))
	if card_id == "":
		return {}
	GhostlightBoons.bless_slot(slot, st)
	var hero := _hero_name(slot, st)
	var info := _outcome(card_id)
	return {"card": card_id, "slot": slot, "slot_name": hero, "title": "%s: %s" % [hero, str(ReadingDeck.card(card_id).get("name", card_id))],
		"verse": str(info.get("verse", ""))}


## The journal's one line for a hero's card, for `{tarokka.hero_1.hint}` in quest text.
func field(st: StoryState, path: String) -> String:
	var parts := path.split(".")
	# The last of the six middle cars, whichever the playthrough's seed makes it (`tarokka.last_car.<place id>` in a door's `when`): its
	# front door is the Tender's, so that door is the one that waits for the haints.
	if parts.size() == 2 and parts[0] == "last_car":
		var chain := switcheroo_chain(st.playthrough_seed)
		return "yes" if chain.size() > 1 and chain[chain.size() - 2] == parts[1] else ""
	if parts.size() == 2 and parts[0] in st.tarokka:
		var card_id := str(st.tarokka[parts[0]])
		match parts[1]:
			"card":
				return card_id
			"hint":
				return str(_outcome(card_id).get("hint", ""))
			"place":
				return str(_outcome(card_id).get("place", ""))
	return ""


## Where a card's treasure or boon lies (a place id, or boon:<foe> for a gift when that foe falls): the party's cards that name `place`.
func treasures_at(place: String, st: StoryState) -> Array[String]:
	var out: Array[String] = []
	for slot: String in st.tarokka:
		if str(_outcome(str(st.tarokka[slot])).get("place", "")) == place:
			out.append(str(st.tarokka[slot]))
	return out


## The train's cars, rear to Tender: the six middle cars in an order the playthrough's seed fixes (a reload never reshuffles it). An exit
## `module_switcheroo_next` or `:previous` leads to the car after or before the one it is in.
func exit_target(st: StoryState, from_location: String, to: String) -> String:
	if not to.begins_with("module_switcheroo_"):
		return to
	var chain := switcheroo_chain(st.playthrough_seed)
	var at := chain.find(from_location)
	if at < 0:
		return from_location
	return chain[clampi(at + (1 if to.ends_with("_next") else -1), 0, chain.size() - 1)]


static func switcheroo_chain(seed_value: int) -> Array[String]:
	var cars := ((JSON.parse_string(FileAccess.get_file_as_string("res://data/switcheroo.json")) as Dictionary))
	var middle: Array[String] = []
	for c: Variant in cars["middle"]:
		middle.append(str(c))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(middle.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := middle[i]
		middle[i] = middle[j]
		middle[j] = t
	var out: Array[String] = [str(cars["rear"])]
	out.append_array(middle)
	out.append(str(cars["last"]))
	return out


func _hero_name(slot: String, st: StoryState) -> String:
	var n := int(slot.trim_prefix("hero_")) - 1
	return (st.party[n] as Character).name.get_slice(" ", 0) if n >= 0 and n < st.party.size() else slot


static func _outcome(card_id: String) -> Dictionary:
	if _outcomes.is_empty():
		var f := FileAccess.open(OUTCOMES, FileAccess.READ)
		if f != null:
			_outcomes = ((JSON.parse_string(f.get_as_text()) as Dictionary).get("outcomes", {}) as Dictionary)
	return _outcomes.get(card_id, {}) as Dictionary
