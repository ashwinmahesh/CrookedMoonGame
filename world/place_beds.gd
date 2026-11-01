class_name PlaceBeds
extends Node
## The sound a whole place sits in (Audio Plan, Act 1): the train's wheels on the rails in every car, the night wind and
## crickets on the boarding hill, the low drone of the limbo. art/audio.json "place_beds" names a place's bed (a
## location id, else its region, to an id in "loops"), and "bed_turns" a later one once the story allows (Wickermoor's
## crickets and a far dog at night); the engine's WorldSounds keeps the beds heard from where they are (fires, water),
## this is the one heard everywhere in a place. A place with no bed, or a bed with no recording, is silent, and the bed
## fades across a change of place instead of cutting.

## Seconds a bed takes to fade in or out.
const FADE := 1.4
const SILENT_DB := -60.0

## The bed id playing now, "" with none.
var bed_id := ""
var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _tweens: Array[Tween] = [null, null]
var _rng := RandomNumberGenerator.new()   # cosmetic: where in its loop a bed starts


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # a bed keeps going under a cutscene or the pause menu
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)


## The bed for a place: its own turn or entry, else its region's, else "". A turn (art/audio.json "bed_turns": a place
## or region to [{when, bed}]) is the first whose StoryConditions `when` holds and whose bed has a recording; with no
## story to ask (`st` null) there is none.
static func bed_for(location_id: String, st: StoryState = null) -> String:
	var beds := Audio._data.get("place_beds", {}) as Dictionary
	var region := str(Compendium.shared().get_entry("locations", location_id).get("region", ""))
	var turns := Audio._data.get("bed_turns", {}) as Dictionary
	if st != null:
		for key: String in [location_id, region]:
			for t: Variant in turns.get(key, []):
				var turn := t as Dictionary
				var bed := str(turn.get("bed", ""))
				if not Audio.files("loops", bed).is_empty() and StoryConditions.check(str(turn.get("when", "")), st):
					return bed
			if beds.has(key):
				break   # a place's own bed outranks its region's turns
	if beds.has(location_id):
		return str(beds[location_id])
	return str(beds.get(region, "")) if region != "" else ""


## Crossfades to the bed of `location_id`, or with `camped` to a camp's (art/audio.json loops "camp": its fire and the night
## round it); the same bed keeps playing where it is.
func enter(location_id: String, st: StoryState = null, camped: bool = false) -> void:
	var next := "camp" if camped and not Audio.files("loops", "camp").is_empty() else bed_for(location_id, st)
	if next == bed_id:
		return
	bed_id = next
	_fade(_current, SILENT_DB, true)
	if next == "" or not Audio.audible():
		return
	var stream := Audio.loop_stream(next)
	if stream == null:
		return
	_current = 1 - _current
	var p := _players[_current]
	p.stream = stream
	p.volume_db = SILENT_DB
	p.play(_rng.randf() * stream.get_length())
	_fade(_current, Audio.level_db(next), false)


## The effects a cutscene's picture brings as it shows (art/audio.json "scene_sfx": cutscene id -> effect ids): the
## train's whistle as it pulls in, the punch on the ticket, the crash. Returns the ids it played.
static func scene_sounds(cutscene_id: String) -> Array[String]:
	var played: Array[String] = []
	for id: Variant in (Audio._data.get("scene_sfx", {}) as Dictionary).get(cutscene_id, []):
		Audio.sfx(str(id), 0.0)
		played.append(str(id))
	return played


## The effect of walking from one place into another of the same region (art/audio.json "exit_sfx": region -> effect):
## the sliding door between two cars of the train, a creaking door into a Wickermoor shop. Walking between two open-air
## places (the village street and the orchard, two turns of the maze) passes no door. "" when it has none; the id
## otherwise, played.
static func exit_sound(from_id: String, to_id: String) -> String:
	var lib := Compendium.shared()
	var from := lib.get_entry("locations", from_id)
	var to := lib.get_entry("locations", to_id)
	var region := str(from.get("region", ""))
	if region == "" or str(to.get("region", "")) != region:
		return ""
	if CampSite.setting(from) != CampSite.INDOORS and CampSite.setting(to) != CampSite.INDOORS:
		return ""
	var id := str((Audio._data.get("exit_sfx", {}) as Dictionary).get(region, ""))
	Audio.sfx(id)
	return id


## The effect a conversation opens with (art/audio.json "dialogue_sfx": a dialogue file, the part of `ref` before its
## node, -> effect): the crackle of the brass grille before the Vagrant speaks over it. "" with none.
static func dialogue_sound(ref: String) -> String:
	var id := str((Audio._data.get("dialogue_sfx", {}) as Dictionary).get(ref.get_slice(":", 0), ""))
	Audio.sfx(id, 0.0)
	return id


## The sounds of the foes who open a fight (art/audio.json "fight_sfx": monster id -> effect), each kind once: the
## wildpyre's roar as it wakes, the Stoker's furnace roar. Returns the ids it played.
static func fight_sounds(combatants: Array[Combatant]) -> Array[String]:
	var own := Audio._data.get("fight_sfx", {}) as Dictionary
	var played: Array[String] = []
	for c in combatants:
		if c.side != &"enemy" or not c.creature is Monster:
			continue
		var id := str(own.get(str((c.creature as Monster).data.get("id", "")), ""))
		if id != "" and not played.has(id):
			Audio.sfx(id, 0.0)
			played.append(id)
	return played


## The effect a quest ending other than a failure plays (art/audio.json "quest_sfx": quest -> effect): a soft chime as a
## haint is laid to rest. "" with none.
static func quest_sound(quest_id: String, ending: String) -> String:
	if ending == "failure":
		return ""
	var id := str((Audio._data.get("quest_sfx", {}) as Dictionary).get(quest_id, ""))
	Audio.sfx(id, 0.0)
	return id


## The music a fight starts with where `location_id` is: the place's own fight mood (art/audio.json "place_fights": the
## Festival of Fools inside Wickermoor), else its region's ("region_fights"), each a fight mood (one of "boss_music"'s,
## so it swells like "combat"), else "combat". A foe's own music ("boss_music") and a boss's still take over once the
## fight is set up.
static func fight_music(location_id: String) -> String:
	var region := str(Compendium.shared().get_entry("locations", location_id).get("region", ""))
	for m: String in [str((Audio._data.get("place_fights", {}) as Dictionary).get(location_id, "")),
			str((Audio._data.get("region_fights", {}) as Dictionary).get(region, ""))]:
		if m != "" and Audio.is_fight_mood(m) and not Audio.entries("music", m).is_empty():
			return m
	return "combat"


## Fades the bed out (a fight's music over a quiet car keeps it; the title screen does not).
func stop() -> void:
	bed_id = ""
	_fade(_current, SILENT_DB, true)


func _fade(index: int, to_db: float, stop_after: bool) -> void:
	var p := _players[index]
	if _tweens[index] != null:
		_tweens[index].kill()
	if not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, FADE)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[index] = tw
