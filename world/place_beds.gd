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
