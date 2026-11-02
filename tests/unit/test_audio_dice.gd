extends TestCase
## The d20 is heard wherever it is thrown (checks in a conversation or out in the world, saves, attacks): the engine's
## die (ui/dice/d20_die.gd, ui/dice/dice_roll.gd) plays effect ids it ships no recording for, so the game must bring
## them (art/sourced/elevenlabs_dice). Without them every roll was silent without saying so; this says so.

const DIE_SCRIPTS: Array[String] = [
	"res://addons/dnd_core/ui/dice/d20_die.gd",
	"res://addons/dnd_core/ui/dice/dice_roll.gd",
]
const DIE_CUES: Array[String] = ["die_throw", "die_bounce", "die_land", "die_success", "die_fail", "die_crit", "die_fumble"]


func _cues_in_scripts() -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("\"(die_[a-z_]+)\"")
	for path: String in DIE_SCRIPTS:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			if not out.has(m.get_string(1)):
				out.append(m.get_string(1))
	return out


func test_every_die_cue_has_a_recording() -> void:
	var cues: Array[String] = []
	cues.append_array(DIE_CUES)
	for c: String in _cues_in_scripts():
		if not cues.has(c):
			cues.append(c)
	assert_true(cues.size() >= DIE_CUES.size(), "the die's cues are found")
	for id: String in cues:
		var paths := Audio.files("sfx", id)
		assert_false(paths.is_empty(), "%s has a recording" % id)
		for path: String in paths:
			assert_true(ResourceLoader.exists(path), "%s: %s exists" % [id, path])


func test_the_engine_still_plays_these_cues() -> void:
	var found := _cues_in_scripts()
	for id: String in DIE_CUES:
		assert_true(found.has(id), "the engine's die plays %s" % id)
