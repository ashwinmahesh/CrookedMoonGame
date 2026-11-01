class_name PlaceBeds
extends Node
## The sound a whole place sits in (Audio Plan, Act 1): the train's wheels on the rails in every car, the night wind and
## crickets on the boarding hill, the low drone of the limbo. art/audio.json "place_beds" names a place's bed (a
## location id, else its region, to an id in "loops"); the engine's WorldSounds keeps the beds heard from where they are
## (fires, water), this is the one heard everywhere in a place. A place with no bed, or a bed with no recording, is
## silent, and the bed fades across a change of place instead of cutting.

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


## The bed for a place: its own entry, else its region's, else "".
static func bed_for(location_id: String) -> String:
	var beds := Audio._data.get("place_beds", {}) as Dictionary
	if beds.has(location_id):
		return str(beds[location_id])
	var region := str(Compendium.shared().get_entry("locations", location_id).get("region", ""))
	return str(beds.get(region, "")) if region != "" else ""


## Crossfades to the bed of `location_id`; the same bed keeps playing where it is.
func enter(location_id: String) -> void:
	var next := bed_for(location_id)
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
## the sliding door between two cars of the train. "" when it has none; the id otherwise, played.
static func exit_sound(from_id: String, to_id: String) -> String:
	var lib := Compendium.shared()
	var region := str(lib.get_entry("locations", from_id).get("region", ""))
	if region == "" or str(lib.get_entry("locations", to_id).get("region", "")) != region:
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


## The effect a quest ending other than a failure plays (art/audio.json "quest_sfx": quest -> effect): a soft chime as a
## haint is laid to rest. "" with none.
static func quest_sound(quest_id: String, ending: String) -> String:
	if ending == "failure":
		return ""
	var id := str((Audio._data.get("quest_sfx", {}) as Dictionary).get(quest_id, ""))
	Audio.sfx(id, 0.0)
	return id


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
