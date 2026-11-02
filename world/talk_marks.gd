class_name TalkMarks
extends Node
## The talk mark over someone who waits to be talked to (Ashwin, 2026-11-02: on the hill and aboard the train the party looks
## round first and talks to the Vagrant when it is ready, so nobody speaks first there; the mark says who to walk up to).
## data/talk_marks.json lists them: {location, npc, when}. While the entry's `when` holds, and the party is exploring, a speech
## bubble (the engine's talk icon, as the camp's "wants a word" mark draws it) bobs over the person's head; once the talk has
## begun its `when` fails and the mark goes. The marks hang on the place's own figures, which every conversation builds again,
## so they are looked at a few times a second rather than built once.

const PATH := "res://data/talk_marks.json"
const NAME := "TalkMark"
const ICON := preload("res://addons/dnd_core/art/ui/icons/talk.png")
## How often the marks are looked at (seconds).
const CHECK_EVERY := 0.2

static var _marks: Array = []
static var _read := false

var view: LocationView
var _wait := 0.0


static func create(v: LocationView) -> TalkMarks:
	var t := TalkMarks.new()
	t.name = "TalkMarks"
	t.view = v
	return t


## The file's entries ([{location, npc, when}]), read once.
static func marks() -> Array:
	if not _read:
		_read = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_marks = (parsed as Dictionary).get("marks", []) as Array if parsed is Dictionary else []
	return _marks


## The npc ids in `location_id` that wear the mark now (their entry's `when` holds in `st`).
static func waiting(location_id: String, st: StoryState) -> Array[String]:
	var out: Array[String] = []
	for m: Variant in marks():
		var e := m as Dictionary
		if str(e.get("location", "")) == location_id and StoryConditions.check(str(e.get("when", "")), st):
			out.append(str(e["npc"]))
	return out


func _ready() -> void:
	refresh()


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_EVERY
	refresh()


## Puts the mark over everyone shown here who waits to be talked to, and takes it off everyone else.
func refresh() -> void:
	if view == null or not is_instance_valid(view):
		return
	var who: Array[String] = []
	if not view.in_combat and ModeController.mode == ModeController.Mode.EXPLORATION:
		who = waiting(view.loc_id, view.st)
	for id: String in view.npc_tokens:
		var tok := view.npc_tokens[id] as CombatToken
		if tok == null or not is_instance_valid(tok):
			continue
		var mark := tok.get_node_or_null(NAME)
		if who.has(id) and tok.visible:
			if mark == null:
				_mark(tok)
		elif mark != null:
			mark.queue_free()
			tok.remove_child(mark)


## The speech bubble (the talk icon, with a dark rim and an ellipsis in it), bobbing gently over the head.
static func _mark(tok: CombatToken) -> Node3D:
	var mark := Node3D.new()
	mark.name = NAME
	var top := CombatToken.height_of(tok.combatant) + 0.55
	mark.position = Vector3(0, top, 0)
	for layer: Array in [[0.0056, "void", 11], [0.0045, "parchment", 12]]:
		var sp := Sprite3D.new()
		sp.texture = ICON
		sp.pixel_size = float(layer[0])
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.render_priority = int(layer[2])
		sp.modulate = Look.color(str(layer[1]))
		mark.add_child(sp)
	var dots := Label3D.new()
	dots.text = "…"
	dots.font_size = 56
	dots.pixel_size = 0.005
	dots.position = Vector3(0, 0.04, 0)
	dots.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dots.no_depth_test = true
	dots.render_priority = 13
	dots.modulate = Look.color("void")
	dots.outline_size = 0
	mark.add_child(dots)
	tok.add_child(mark)
	var bob := mark.create_tween().set_loops()
	bob.tween_property(mark, "position:y", top + 0.08, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(mark, "position:y", top, 0.7).set_trans(Tween.TRANS_SINE)
	return mark
