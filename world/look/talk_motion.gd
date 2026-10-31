class_name TalkMotion
extends Node
## The one speaking keeps talking for as long as their line is said (vault Build/Talking Figures.md). Tripo's figures have
## no mouth to move (the face is painted on and the Mixamo rig has no jaw), so a line shows on the figure as the head
## nodding and tilting with the voice, and as gestures (the talk clips: agree, complain) one after another while the line
## lasts. FigureTalk plays the first gesture as the line shows; this keeps it going.
##
## The head follows the voice's loudness on its bus while a recorded clip plays; a line nobody has voiced yet is given a
## speaking time from its length and a made-up rhythm of syllables and pauses between words. GameRoot calls spoke() as
## each line shows and stop() as the conversation ends. A sprite, or a figure without a Head bone, only gestures.

## Seconds a line without a clip is spoken for: its letters at this rate, within the bounds.
const LETTERS_PER_SECOND := 15.0
const MIN_SECONDS := 1.2
const MAX_SECONDS := 7.0
## Rest between one gesture ending and the next starting, so the hands settle for a moment.
const GESTURE_REST := 0.6
## The voice's loudness that counts as silence and as full voice (dB on the bus's peak meter).
const QUIET_DB := -42.0
const LOUD_DB := -8.0

## The figure talking now, and when its line stops being said (msec ticks; 0 while a clip plays, which ends it instead).
var _speaker: CombatToken = null
var _until := 0
var _with_clip := false
var _rest := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "TalkMotion"


## A line by `speaker_id` shows in `view`; `text` is what it says (for its speaking time when it has no clip).
func spoke(view: LocationView, speaker_id: String, text: String) -> void:
	_quiet()
	if view == null or view.in_combat:
		return
	var tok := FigureTalk.token_of(view, speaker_id)
	if tok == null:
		return
	_speaker = tok
	# DialogueUI starts the clip before it says who spoke, so a voiced line is already playing (or about to: its player
	# is added deferred the first time).
	_with_clip = VoiceOver.is_speaking() or _clip_starting()
	var seconds := clampf(text.strip_edges().length() / LETTERS_PER_SECOND, MIN_SECONDS, MAX_SECONDS)
	_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	_rest = GESTURE_REST
	var nod := nod_of(tok)
	if nod != null:
		nod.talking = true
		nod.loudness = 0.0


## The conversation ended: whoever was talking stops.
func stop() -> void:
	_quiet()


## Whether a figure is talking now (tests).
func talking() -> bool:
	return _speaker != null and is_instance_valid(_speaker) and _saying()


func _clip_starting() -> bool:
	var p := VoiceOver._player
	return p != null and is_instance_valid(p) and p.stream != null and not p.is_inside_tree()


func _saying() -> bool:
	if _with_clip:
		return VoiceOver.is_speaking() or _clip_starting()
	return Time.get_ticks_msec() < _until


func _quiet() -> void:
	if _speaker != null and is_instance_valid(_speaker):
		var nod := nod_of(_speaker, false)
		if nod != null:
			nod.talking = false
	_speaker = null


func _process(delta: float) -> void:
	if _speaker == null:
		return
	if not is_instance_valid(_speaker) or not _saying():
		_quiet()
		return
	var nod := nod_of(_speaker, false)
	if nod != null:
		nod.loudness = _voice_loudness() if _with_clip else _made_up_loudness()
	# The next gesture once the last has ended and the hands have rested (gesture() is false while a clip plays).
	_rest -= delta
	if _rest <= 0.0:
		_rest = 0.25 if not _speaker.gesture("talk") else GESTURE_REST + _rng.randf_range(0.0, 0.5)


## How loud the voice is now, 0 to 1, from the voice bus's peak meter.
func _voice_loudness() -> float:
	var bus := AudioServer.get_bus_index(VoiceOver.BUS)
	if bus < 0:
		return 0.0
	var db := maxf(AudioServer.get_bus_peak_volume_left_db(bus, 0), AudioServer.get_bus_peak_volume_right_db(bus, 0))
	return clampf(inverse_lerp(QUIET_DB, LOUD_DB, db), 0.0, 1.0)


## Syllables at about five a second, words of two to four of them, a short breath between words.
func _made_up_loudness() -> float:
	var t := Time.get_ticks_msec() / 1000.0
	var syllable := maxf(0.0, sin(t * TAU * 4.8))
	var word := sin(t * TAU * 1.3) + 0.6 * sin(t * TAU * 0.47 + 1.7)
	return syllable * (1.0 if word > -0.35 else 0.15)


## The head nod on `tok`'s figure, added the first time when `make` (null for a sprite or a figure with no Head bone).
static func nod_of(tok: CombatToken, make: bool = true) -> HeadNod:
	if tok == null or not (tok.sprite is ModelFigure):
		return null
	var skel: Skeleton3D = null
	for n in tok.sprite.find_children("*", "Skeleton3D", true, false):
		skel = n as Skeleton3D
		break
	if skel == null:
		return null
	for c in skel.get_children():
		if c is HeadNod:
			return c as HeadNod
	if not make:
		return null
	var head := HeadNod.bone_named(skel, "Head")
	if head < 0:
		return null
	var nod := HeadNod.new()
	nod.head = head
	nod.neck = HeadNod.bone_named(skel, "Neck")
	skel.add_child(nod)
	return nod


## Turns the head (and a little of the neck) on top of whatever clip the figure plays: small nods on each syllable's
## stress, a slow tilt and turn while the line goes on, all easing away when the line ends.
class HeadNod extends SkeletonModifier3D:
	## Degrees of nod at full voice, and of the slow tilt and turn.
	const NOD := 7.0
	const SWAY := 4.0
	## How fast the head follows the voice up and down (per second), and fades in and out with the line.
	const ATTACK := 18.0
	const RELEASE := 7.0
	const FADE := 4.0

	var head := -1
	var neck := -1
	var talking := false
	## How loud the voice is now (0 to 1), set each frame while talking.
	var loudness := 0.0
	var _env := 0.0
	var _on := 0.0
	var _t := 0.0

	## The skeleton's bone whose name ends in `bone` after a library or armature prefix (mixamorig:Head, which Godot's
	## import makes mixamorig_Head; Armature|Head).
	static func bone_named(skel: Skeleton3D, bone: String) -> int:
		for i in skel.get_bone_count():
			var n := skel.get_bone_name(i)
			if n == bone or n.ends_with(":" + bone) or n.ends_with("|" + bone) or n.ends_with("_" + bone):
				return i
		return -1

	func _process_modification_with_delta(delta: float) -> void:
		_t += delta
		_on = move_toward(_on, 1.0 if talking else 0.0, FADE * delta)
		var want := loudness if talking else 0.0
		_env = lerpf(_env, want, 1.0 - exp(-(ATTACK if want > _env else RELEASE) * delta))
		if _on <= 0.001:
			return
		var skel := get_skeleton()
		if skel == null or head < 0:
			return
		# A nod down on the stress, the head lifting between; a slow tilt to one side and a turn, out of step.
		var nod := deg_to_rad(NOD) * (_env - 0.35) * _on
		var tilt := deg_to_rad(SWAY) * sin(_t * 0.9) * _on
		var turn := deg_to_rad(SWAY) * sin(_t * 0.55 + 1.1) * _on
		var q := Quaternion(Vector3.RIGHT, nod) * Quaternion(Vector3.FORWARD, tilt) * Quaternion(Vector3.UP, turn)
		skel.set_bone_pose_rotation(head, skel.get_bone_pose_rotation(head) * q)
		if neck >= 0:
			var half := Quaternion(Vector3.RIGHT, nod * 0.4) * Quaternion(Vector3.UP, turn * 0.5)
			skel.set_bone_pose_rotation(neck, skel.get_bone_pose_rotation(neck) * half)
