class_name CrookedMoonCampaign
extends CampaignModule
## The Crooked Moon's answers to the story engine (CampaignModule, named in data/campaign.json). The base class answers for a game with
## no reading, no watching villain, ordinary spells and no ending of its own; plan G1 fills this in as the chapters need each part.
## So far: the Fated Tarot, Adela's reading of the party's cards (R10). The ritual track, the Crooked Moon's gaze, the endings, the
## parley before the Born King, fight barks and achievements come with the packages that use them.

const OUTCOMES := "res://data/tarot/outcomes.json"

static var _outcomes: Dictionary = {}


## The party screen's words about the land (the engine's PartyCoverage gaps), in the Vagrant's voice: Druskenvald's night never
## lifts. The engine's own words name Barovia, so this module gives its own (CampaignModule.coverage_words; an older engine
## never asks).
func coverage_words() -> Dictionary:
	return {"dark": "out here in Druskenvald the night don't ever lift, so y'all carry a light.",
		"radiant": "No Radiant damage, and there's a mess of restless dead out here that can't abide it."}


## The reading: one card for every hero at the table, in party order (slots hero_1 to hero_N), drawn once from the playthrough's seed so
## a reload never changes it. Each slot's card id is also a string flag, tarot_hero_N, which conversations and places read.
func ensure_drawn(st: StoryState) -> void:
	if not st.tarokka.is_empty():
		return
	st.tarokka = ReadingDeck.draw(ReadingDeck.hero_slots(st.party.size()), st.playthrough_seed)
	for slot: String in st.tarokka:
		st.set_flag("tarot_" + slot, str(st.tarokka[slot]))


## One slot as the card face shows it: the card, whose it is, and Adela's verse. The dialogue's `reading read` asks this once for each
## card it turns.
func reading(slot: String, st: StoryState) -> Dictionary:
	var card_id := str(st.tarokka.get(slot, ""))
	if card_id == "":
		return {}
	var hero := _hero_name(slot, st)
	var info := _outcome(card_id)
	return {"card": card_id, "slot": slot, "slot_name": hero, "title": "%s: %s" % [hero, str(ReadingDeck.card(card_id).get("name", card_id))],
		"verse": str(info.get("verse", ""))}


## Every card of the reading has been turned: everyone at the table took part, so every hero gains Bless for an hour, starting now
## (the book: all who take part).
func reading_finished(st: StoryState) -> void:
	GhostlightBoons.bless_party(st)


## A quest ended: a freed haint heals every hero 1d6 (story/ghostlight_boons.gd); the journal's notice carries what it says.
func quest_finished(st: StoryState, quest_id: String, _ending: String, dice: DiceRoller) -> String:
	return GhostlightBoons.haint_freed(st, quest_id, dice)


## The journal's one line for a hero's card, for `{tarokka.hero_1.hint}` in quest text.
func field(st: StoryState, path: String) -> String:
	var parts := path.split(".")
	# The last of the six middle cars, whichever the playthrough's seed makes it (`tarokka.last_car.<place id>` in a door's `when`): its
	# front door is the Tender's, so that door is the one that waits for the haints.
	if parts.size() == 2 and parts[0] == "last_car":
		var chain := switcheroo_chain(st.playthrough_seed)
		return "yes" if chain.size() > 1 and chain[chain.size() - 2] == parts[1] else ""
	# The children's room's hide-and-seek (R12, H10): which of its six hiding places holds the Lurker in the Dark
	# (`tarokka.lurker_spot.<n>`, n = 1 to 6, in the order of LURKER_SPOTS), and whether every place has been searched
	# (`tarokka.lurker_hunt.searched`: then it drops from the ceiling).
	if parts.size() == 2 and parts[0] == "lurker_spot":
		return "yes" if lurker_spot(st.playthrough_seed) == int(parts[1]) else ""
	if parts.size() == 2 and parts[0] == "lurker_hunt" and parts[1] == "searched":
		return "yes" if lurker_places_searched(st) >= LURKER_SPOTS.size() else ""
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


## The module's exit out of the mist between cars (data/locations/ghostlight_limbo.json): it leads on to the next car the party has not
## been in yet.
const LIMBO_ONWARD := "module_switcheroo_onward"
## Its way back (Ashwin, 2026-11-02: the mist went only one way): to the car the party stepped out of, the last one before the first
## car not yet been in, in at its front door with everything there as the party left it.
const LIMBO_BACK := "module_switcheroo_back"


## The train's cars, rear to Tender: the six middle cars in an order the playthrough's seed fixes (a reload never reshuffles it). An exit
## `module_switcheroo_next` or `:previous` leads to the car after or before the one it is in. The first time the party goes forward
## into a car it has not been in, the way leads through the mist between cars (the Switcheroo's limbo) and out of it into that car, or
## back out of it into the car it came from; every later crossing is a plain door. A pure query (menus ask it for the door's label too): it only reads which places the party has
## visited, which the place itself records on arrival.
func exit_target(st: StoryState, from_location: String, to: String) -> String:
	if to.begins_with("module_maze_"):
		return maze_target(st.playthrough_seed, from_location, to.trim_prefix("module_maze_"))
	if not to.begins_with("module_switcheroo_"):
		return to
	var chain := switcheroo_chain(st.playthrough_seed)
	if to == LIMBO_ONWARD:
		for car: String in chain:
			if not st.visited.has(car):
				return car
		return chain[chain.size() - 1]
	if to == LIMBO_BACK:
		for i: int in range(1, chain.size()):
			if not st.visited.has(chain[i]):
				return chain[i - 1]
		return chain[chain.size() - 2]
	var at := chain.find(from_location)
	if at < 0:
		return from_location
	var forward := to.ends_with("_next")
	var target := chain[clampi(at + (1 if forward else -1), 0, chain.size() - 1)]
	if forward and target != from_location and not st.visited.has(target):
		return limbo_place()
	return target


## Raum's corn maze (R13, data/maze.json): three junctions, each with a left, a centre and a right mouth. One mouth at each junction is
## the way on (fixed by the playthrough's seed, so a reload never changes it); the other two end in that junction's dead end, whose own
## exit leads straight back. The way on from the last junction is the Circle of Secrets. `mouth` is left, centre or right.
static func maze_target(seed_value: int, from_location: String, mouth: String) -> String:
	var maze := _maze()
	var junctions: Array = maze.get("junctions", [])
	var at := junctions.find(from_location)
	if at < 0:
		return from_location
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 13 * (at + 1)
	var right_mouth: String = ["left", "centre", "right"][rng.randi_range(0, 2)]
	if mouth != right_mouth:
		return str((maze.get("dead", []) as Array)[at])
	return str(junctions[at + 1]) if at + 1 < junctions.size() else str(maze.get("circle", from_location))


## The mouth that is the way on at a junction (for tests and the journal's hint to a hero who found it by ear).
static func maze_way_on(seed_value: int, junction: String) -> String:
	var at := (_maze().get("junctions", []) as Array).find(junction)
	if at < 0:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 13 * (at + 1)
	return ["left", "centre", "right"][rng.randi_range(0, 2)]


## The children's room (data/locations/crooked_house_second.json): the six places the Lurker in the Dark may hide, in the order the
## digest lists them (closet, under the left bed, under the right bed, toy chest, armoire, outside the window); each is the id of
## the prop that is searched there and of the world check that searches it.
const LURKER_PLACE := "crooked_house_second"
## The place whose world checks hold the hiding places' (the house is one place now; its second floor is still marked visited).
const LURKER_RECORDS := "crooked_house"
const LURKER_SPOTS: Array[String] = ["h10_closet", "h10_bed_left", "h10_bed_right", "h10_chest", "h10_armoire", "h10_window"]


## Which of the six hiding places (1 to 6) holds the lurker in the playthrough with this seed: fixed by the seed, so a reload
## or a second visit never moves it.
static func lurker_spot(seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 12 * 101
	return rng.randi_range(1, LURKER_SPOTS.size())


## How many of the six hiding places someone in the party has searched (a world check on each, tried by anyone), found or not.
static func lurker_places_searched(st: StoryState) -> int:
	if not st.visited.has(LURKER_PLACE):
		return 0
	var records := WorldChecks.records(st, LURKER_RECORDS)
	var searched := 0
	for id: String in LURKER_SPOTS:
		var tried := str(records.get(id, "")) == "done"
		for key: Variant in records:
			if str(key).begins_with("tried:%s:" % id):
				tried = true
		if tried:
			searched += 1
	return searched


static func _maze() -> Dictionary:
	var f := FileAccess.open("res://data/maze.json", FileAccess.READ)
	return (JSON.parse_string(f.get_as_text()) as Dictionary) if f != null else {}


## The mist between cars, a place of its own that the party passes through on a first crossing.
static func limbo_place() -> String:
	return str(_cars().get("limbo", ""))


## Whether `place` is one of the train's cars (the rear car, the six middle ones or the Tender).
static func is_car(place: String) -> bool:
	var cars := _cars()
	return place == str(cars["rear"]) or place == str(cars["last"]) or (cars["middle"] as Array).has(place)


static func _cars() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/switcheroo.json")) as Dictionary


static func switcheroo_chain(seed_value: int) -> Array[String]:
	var cars := _cars()
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
