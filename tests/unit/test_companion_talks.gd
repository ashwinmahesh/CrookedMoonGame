extends TestCase
## The six companions' camp talks (narrative/camp/<id>.dialogue and <id>_thread.dialogue, drafted in docs/plans/gemini_companions/):
## every file reads clean, every talk opens with an `if` that names its own companion, their Threads' Discovery and Confrontation
## play through to the quests Fateweaving pays on, and a Strained companion holds the Confrontation back until the word that mends it.

const IDS: Array[String] = ["rook_coldwake", "tobin_hayward", "silas_vane", "delphine_ravelle", "lucan_houndstooth", "cordelia_skein"]
const THREADS := {"rook_coldwake": "pilgrimage", "tobin_hayward": "rejuvenation", "silas_vane": "liberation",
	"delphine_ravelle": "ascendancy", "lucan_houndstooth": "slaughter", "cordelia_skein": "evolution"}
## The chapter flags the Discovery and the Confrontation wait for (data/threads, the lane's README).
const DISCOVERY_FLAG := {"rook_coldwake": "raum_slain", "tobin_hayward": "stonoga_slain", "silas_vane": "crossroads_done",
	"delphine_ravelle": "renathyr_slain", "lucan_houndstooth": "raum_slain", "cordelia_skein": "lethica_slain"}
const CONFRONTATION_FLAG := {"rook_coldwake": "nm_chapter_done", "tobin_hayward": "gorthos_slain", "silas_vane": "chuckles_dead",
	"delphine_ravelle": "chuckles_dead", "lucan_houndstooth": "gorthos_slain", "cordelia_skein": "nm_chapter_done"}
const THREAD_TALKS: Array[String] = ["talk_incitement", "talk_discovery", "talk_confrontation_wait", "talk_confrontation"]


func after_each() -> void:
	Campaign.use(null)


func _story(id: String) -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen(id, 5))
	return st


func _camp_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(DialogueFile.ROOT + "camp")
	assert_true(dir != null, "narrative/camp exists")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".dialogue"):
			out.append(f.get_basename())
	out.sort()
	return out


## The companion a camp file is for: its name without "_thread".
func _owner_of(file: String) -> String:
	return file.trim_suffix("_thread")


## Plays a talk to its end, picking option `pick` at its one menu. Returns the lines spoken.
func _play(st: StoryState, ref: String, pick: int) -> Array[String]:
	var lines: Array[String] = []
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start(ref), ref)
	var menus := 0
	for _i in 120:
		var beat := r.next()
		match str(beat["kind"]):
			"line":
				lines.append(str(beat["text"]))
			"options":
				menus += 1
				r.choose(pick)
			"end":
				assert_eq(menus, 1, "%s has one menu" % ref)
				return lines
	fail("%s didn't end" % ref)
	return lines


func test_every_camp_file_reads_with_no_errors() -> void:
	var files := _camp_files()
	assert_true(files.size() >= 6, "the companions' camp files are here")
	for f in files:
		var df := DialogueFile.load_key("camp/" + f)
		assert_true(df != null, f)
		if df != null:
			assert_true(df.errors.is_empty(), "%s: %s" % [f, str(df.errors)])


func test_every_talk_opens_with_an_if_naming_its_own_companion() -> void:
	var talks := 0
	for f in _camp_files():
		var id := _owner_of(f)
		assert_true(id in IDS, "%s is a roster companion's file" % f)
		var df := DialogueFile.load_key("camp/" + f)
		for node in df.order:
			if not node.begins_with(CampTalk.TALK):
				continue
			talks += 1
			var cond := CampTalk.opening_condition(df, node)
			assert_true(cond != "", "%s:%s opens with an if" % [f, node])
			var re := RegEx.create_from_string("\\bname:([a-z0-9_]+)")
			var m := re.search(cond)
			assert_true(m != null and m.get_string(1) == id, "%s:%s names %s first: %s" % [f, node, id, cond])
	assert_true(talks >= 24, "the Thread files alone hold 24 talks (%d)" % talks)


func test_each_thread_file_holds_the_four_talks_in_the_order_they_are_offered() -> void:
	for id in IDS:
		var df := DialogueFile.load_key("camp/%s_thread" % id)
		assert_true(df != null, id)
		var talks: Array[String] = []
		for node in df.order:
			if node.begins_with(CampTalk.TALK):
				talks.append(node)
		assert_eq(talks, THREAD_TALKS, id)


func test_the_incitement_echo_pays_what_the_scene_pays() -> void:
	for id in IDS:
		var t: String = THREADS[id]
		var st := _story(id)
		st.set_flag("pending_%s_incitement" % t, true)
		var df := DialogueFile.load_key("camp/%s_thread" % id)
		var offered := CampTalk.offered(df, st)
		assert_eq(str(offered.get("ref", "")), "camp/%s_thread:talk_incitement" % id, id)
		assert_false(st.party[0].heroic_inspiration, id)
		_play(st, str(offered["ref"]), 0)
		assert_true(bool(st.get_flag("incitement_%s" % t, false)), "%s: the Incitement is told" % id)
		assert_true(st.party[0].heroic_inspiration, "%s: Heroic Inspiration" % id)
		# The train's Incitements also open the Connection (as the car's own scene does).
		if t in ["liberation", "evolution", "ascendancy"]:
			assert_eq(st.quest_stage("connection_%s" % t), "waiting", "%s: the Connection waits" % id)
		CampTalk.mark(st, str(offered["ref"]))
		assert_true(CampTalk.offered(df, st).is_empty(), "%s: once a playthrough" % id)


func test_the_discovery_plays_when_its_chapter_is_done_and_pays_a_twist_of_fate() -> void:
	for id in IDS:
		var t: String = THREADS[id]
		for pick in 3:
			var st := _story(id)
			var df := DialogueFile.load_key("camp/%s_thread" % id)
			assert_true(CampTalk.offered(df, st).is_empty(), "%s: nothing before the Connection" % id)
			st.set_flag("connection_%s" % t, true)
			assert_true(CampTalk.offered(df, st).is_empty(), "%s: nothing before the chapter is done" % id)
			st.set_flag(DISCOVERY_FLAG[id], true)
			var offered := CampTalk.offered(df, st)
			assert_eq(str(offered.get("ref", "")), "camp/%s_thread:talk_discovery" % id, id)
			_play(st, str(offered["ref"]), pick)
			assert_true(Fateweaving.beat_done(st, t, "discovery"), "%s option %d: the Discovery is done" % [id, pick + 1])
			assert_eq(st.quest_stage("discovery_%s" % t), "done", id)
			assert_eq(st.quest_stage("confrontation_%s" % t), "waiting", id)
			assert_eq(Fateweaving.twists_owed(st, id), 1, "%s option %d: a Twist of Fate" % [id, pick + 1])


func test_the_confrontation_plays_in_its_chapter_and_raises_the_ability() -> void:
	for id in IDS:
		var t: String = THREADS[id]
		for pick in 3:
			var st := _story(id)
			st.set_flag("connection_%s" % t, true)
			st.set_flag("discovery_%s" % t, true)
			var df := DialogueFile.load_key("camp/%s_thread" % id)
			assert_true(CampTalk.offered(df, st).is_empty(), "%s: not before the chapter" % id)
			st.set_flag(CONFRONTATION_FLAG[id], true)
			var offered := CampTalk.offered(df, st)
			assert_eq(str(offered.get("ref", "")), "camp/%s_thread:talk_confrontation" % id, id)
			var ability := StringName(str(Fateweaving.thread(t)["confrontation_ability"]))
			var before := st.party[0].ability_score(ability)
			_play(st, str(offered["ref"]), pick)
			assert_true(Fateweaving.beat_done(st, t, "confrontation"), "%s option %d" % [id, pick + 1])
			assert_eq(st.quest_stage("confrontation_%s" % t), "done", id)
			assert_true(st.party[0].ability_score(ability) > before, "%s option %d: %s rises" % [id, pick + 1, ability])


func test_a_strained_companion_holds_the_confrontation_back_until_the_word_that_mends_it() -> void:
	for id in IDS:
		var t: String = THREADS[id]
		var st := _story(id)
		st.set_flag("connection_%s" % t, true)
		st.set_flag("discovery_%s" % t, true)
		st.set_flag(CONFRONTATION_FLAG[id], true)
		st.approval[id] = {"score": -30, "memories": []}
		var df := DialogueFile.load_key("camp/%s_thread" % id)
		var offered := CampTalk.offered(df, st)
		assert_eq(str(offered.get("ref", "")), "camp/%s_thread:talk_confrontation_wait" % id, "%s waits while Strained" % id)
		# Whatever the party answers, the word is had and the Confrontation is offered next (even with approval still low).
		_play(st, str(offered["ref"]), 1)
		CampTalk.mark(st, str(offered["ref"]))
		assert_true(bool(st.get_flag("%s_confrontation_waited" % id, false)), id)
		assert_false(Fateweaving.beat_done(st, t, "confrontation"), "%s: nothing is paid by waiting" % id)
		offered = CampTalk.offered(df, st)
		assert_eq(str(offered.get("ref", "")), "camp/%s_thread:talk_confrontation" % id, "%s: nothing is lost for good" % id)
