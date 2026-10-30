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


## One slot as the card face shows it: the card, whose it is, and Adela's verse.
func reading(slot: String, st: StoryState) -> Dictionary:
	var card_id := str(st.tarokka.get(slot, ""))
	if card_id == "":
		return {}
	var hero := _hero_name(slot, st)
	var info := _outcome(card_id)
	return {"card": card_id, "slot": slot, "slot_name": hero, "title": "%s: %s" % [hero, str(ReadingDeck.card(card_id).get("name", card_id))],
		"verse": str(info.get("verse", ""))}


## The journal's one line for a hero's card, for `{tarokka.hero_1.hint}` in quest text.
func field(st: StoryState, path: String) -> String:
	var parts := path.split(".")
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


func _hero_name(slot: String, st: StoryState) -> String:
	var n := int(slot.trim_prefix("hero_")) - 1
	return (st.party[n] as Character).name.get_slice(" ", 0) if n >= 0 and n < st.party.size() else slot


static func _outcome(card_id: String) -> Dictionary:
	if _outcomes.is_empty():
		var f := FileAccess.open(OUTCOMES, FileAccess.READ)
		if f != null:
			_outcomes = ((JSON.parse_string(f.get_as_text()) as Dictionary).get("outcomes", {}) as Dictionary)
	return _outcomes.get(card_id, {}) as Dictionary
