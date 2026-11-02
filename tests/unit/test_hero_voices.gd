extends TestCase
## The heroes speak their own lines (VoiceOver.voice_for). Until 2026-11-02 the engine only knew an older roster, so Rook, Tobin,
## Silas, Delphine, Lucan and Cordelia were silent in a new game; the campaign's roster pregens now speak in their own voices, and a
## custom hero in the creator voice picked for them.


func test_every_roster_hero_speaks_in_their_own_voice() -> void:
	assert_eq(Pregens.roster_ids().size(), 6)
	for id: String in Pregens.roster_ids():
		var ch := Pregens.build(id, 1)
		assert_eq(VoiceOver.voice_for(ch), id, "%s speaks in their own voice" % id)
		assert_true(DirAccess.dir_exists_absolute(VoiceOver.DIR + id), "%s has recorded lines in audio/voice" % id)


func test_a_custom_hero_speaks_in_the_creator_voice_picked_for_them() -> void:
	var ch := Pregens.build("rook_coldwake", 1)
	ch.id = "made_hero"
	ch.name = "Ada Quill"
	ch.build["appearance"] = {"custom": true, "voice": "hero_female"}
	assert_eq(VoiceOver.voice_for(ch), "hero_female")
