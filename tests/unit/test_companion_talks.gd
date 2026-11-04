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
const APPROVAL_TALKS: Array[String] = ["talk_strained", "talk_doubt", "talk_act1", "talk_act2", "talk_act3", "talk_warm", "talk_close", "talk_devoted"]
## Where each approval talk comes up: {approval score, flags} (the talk's own opening `if` says the rest). Devoted needs level 8.
const APPROVAL_STATE := {
	"talk_strained": {"score": -30}, "talk_doubt": {"score": -15}, "talk_act1": {"flags": {"gl_crashed": true}},
	"talk_act2": {"flags": {"act2_done": 2}}, "talk_act3": {"flags": {"act2_done": 5}},
	"talk_warm": {"score": 12}, "talk_close": {"score": 30}, "talk_devoted": {"score": 55},
}
const BANTER_ACTS := {"act1": "flag.gl_crashed and not flag.act2_done", "act2": "flag.vessla_slain and flag.act2_done < 5", "act3": "flag.act2_done >= 5"}


func after_each() -> void:
	Campaign.use(null)


func _story(id: String, level: int = 5) -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen(id, level))
	return st


## The raw text of a dialogue file, split into {node: [lines]} (comments and blanks dropped).
func _raw_nodes(path: String) -> Dictionary:
	var out := {}
	var cur := ""
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var l := line.strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		if l.begins_with("~ "):
			cur = l.substr(2)
			out[cur] = []
		elif cur != "":
			(out[cur] as Array).append(l)
	return out


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


# --- Approval and the acts (narrative/camp/<id>.dialogue) --------------------------------------------------------------------

func test_each_approval_file_holds_the_eight_talks_in_the_order_they_are_offered() -> void:
	for id in IDS:
		var df := DialogueFile.load_key("camp/" + id)
		assert_true(df != null, id)
		var talks: Array[String] = []
		for node in df.order:
			if node.begins_with(CampTalk.TALK):
				talks.append(node)
		assert_eq(talks, APPROVAL_TALKS, id)


func test_a_strained_companion_is_offered_the_strained_talk_first() -> void:
	for id in IDS:
		var st := _story(id)
		# Everything else that could hold at once holds too: the acts, and Warm's level.
		st.set_flag("gl_crashed", true)
		st.set_flag("act2_done", 5)
		st.approval[id] = {"score": -30, "memories": []}
		var offered := CampTalk.offered(DialogueFile.load_key("camp/" + id), st)
		assert_eq(str(offered.get("ref", "")), "camp/%s:talk_strained" % id, "%s is Strained" % id)
		assert_eq(CampTalk.label_for(CampTalk.opening_condition(DialogueFile.load_key("camp/" + id), "talk_strained"), st), "%s wants a word" % str(st.party[0].name).get_slice(" ", 0))


func test_a_doubtful_companion_is_offered_the_doubt_talk_before_the_acts() -> void:
	for id in IDS:
		var st := _story(id)
		st.set_flag("gl_crashed", true)
		st.approval[id] = {"score": -15, "memories": []}
		var offered := CampTalk.offered(DialogueFile.load_key("camp/" + id), st)
		assert_eq(str(offered.get("ref", "")), "camp/%s:talk_doubt" % id, id)


func test_the_acts_come_up_in_order_for_a_companion_in_good_standing() -> void:
	for id in IDS:
		var df := DialogueFile.load_key("camp/" + id)
		var st := _story(id)
		assert_true(CampTalk.offered(df, st).is_empty(), "%s: nothing at the start" % id)
		for step: Array in [["gl_crashed", true, "talk_act1"], ["act2_done", 2, "talk_act2"], ["act2_done", 5, "talk_act3"]]:
			st.set_flag(str(step[0]), step[1])
			var offered := CampTalk.offered(df, st)
			assert_eq(str(offered.get("ref", "")), "camp/%s:%s" % [id, step[2]], id)
			CampTalk.mark(st, str(offered["ref"]))
		assert_true(CampTalk.offered(df, st).is_empty(), "%s: the acts are done" % id)


func test_warm_close_and_devoted_wait_for_their_tier_and_level() -> void:
	for id in IDS:
		var df := DialogueFile.load_key("camp/" + id)
		var st := _story(id, 5)
		st.approval[id] = {"score": 12, "memories": []}
		assert_eq(str(CampTalk.offered(df, st).get("ref", "")), "camp/%s:talk_warm" % id, id)
		CampTalk.mark(st, "camp/%s:talk_warm" % id)
		assert_true(CampTalk.offered(df, st).is_empty(), "%s: Warm only unlocks Warm" % id)
		st.approval[id] = {"score": 30, "memories": []}
		assert_eq(str(CampTalk.offered(df, st).get("ref", "")), "camp/%s:talk_close" % id, id)
		CampTalk.mark(st, "camp/%s:talk_close" % id)
		st.approval[id] = {"score": 55, "memories": []}
		assert_true(CampTalk.offered(df, st).is_empty(), "%s: Devoted waits for level 8" % id)
		var late := _story(id, 8)
		late.approval[id] = {"score": 55, "memories": []}
		late.flags = st.flags.duplicate(true)
		assert_eq(str(CampTalk.offered(df, late).get("ref", "")), "camp/%s:talk_devoted" % id, id)


func test_every_approval_talk_plays_through_each_of_its_options() -> void:
	for id in IDS:
		for talk in APPROVAL_TALKS:
			for pick in 3:
				var state := APPROVAL_STATE[talk] as Dictionary
				var st := _story(id, 8)
				if state.has("score"):
					st.approval[id] = {"score": int(state["score"]), "memories": []}
				for f: String in (state.get("flags", {}) as Dictionary):
					st.set_flag(f, (state["flags"] as Dictionary)[f])
				var lines := _play(st, "camp/%s:%s" % [id, talk], pick)
				assert_true(lines.size() >= 3, "%s %s option %d speaks" % [id, talk, pick + 1])
				if talk == "talk_devoted":
					assert_true(st.party[0].heroic_inspiration, "%s: Devoted ends in Heroic Inspiration (option %d)" % [id, pick + 1])


# --- Party banter (narrative/banter/party_act1..3.dialogue) --------------------------------------------------------------------

func test_the_banter_files_read_with_nine_exchanges_each_gated_by_their_act_and_their_speakers() -> void:
	for act: String in BANTER_ACTS:
		var path := "res://narrative/banter/party_%s.dialogue" % act
		var df := DialogueFile.load_key("banter/party_" + act)
		assert_true(df != null, act)
		assert_true(df.errors.is_empty(), "%s: %s" % [act, str(df.errors)])
		var nodes := _raw_nodes(path)
		assert_eq(nodes.size(), 9, "%s: nine exchanges" % act)
		for node: String in nodes:
			var lines := nodes[node] as Array
			assert_true(str(lines[0]).begins_with("if "), "%s:%s opens with an if" % [act, node])
			var cond := str(lines[0]).substr(3)
			assert_true(cond.ends_with(BANTER_ACTS[act]), "%s:%s carries its act's gate: %s" % [act, node, cond])
			var spoken := {}
			var said := 0
			for l: Variant in lines:
				var m := RegEx.create_from_string("^interject name:([a-z0-9_]+): ").search(str(l))
				if m != null:
					spoken[m.get_string(1)] = true
					said += 1
			assert_true(spoken.size() >= 2 and spoken.size() <= 3, "%s:%s has two or three speakers" % [act, node])
			assert_true(said >= 4 and said <= 9, "%s:%s says 4 to 9 lines (%d)" % [act, node, said])
			for who: String in spoken:
				assert_true(cond.contains("name:" + who), "%s:%s opens by naming %s" % [act, node, who])
			assert_true(str(lines[lines.size() - 2]) == "endif" and str(lines[lines.size() - 1]) == "-> END", "%s:%s ends" % [act, node])


func test_all_fifteen_pairs_talk_somewhere_across_the_three_files() -> void:
	var pairs := {}
	for act: String in BANTER_ACTS:
		var nodes := _raw_nodes("res://narrative/banter/party_%s.dialogue" % act)
		for node: String in nodes:
			var who: Array[String] = []
			for l: Variant in nodes[node]:
				var m := RegEx.create_from_string("^interject name:([a-z0-9_]+): ").search(str(l))
				if m != null and not m.get_string(1) in who:
					who.append(m.get_string(1))
			for i in who.size():
				for j in range(i + 1, who.size()):
					var pair := [who[i], who[j]]
					pair.sort()
					pairs["%s+%s" % pair] = true
	assert_eq(pairs.size(), 15, "every pair: %s" % str(pairs.keys()))


func test_banter_plays_only_in_its_act_and_only_what_the_party_can_say() -> void:
	var st := StoryState.new()
	for id in IDS:
		st.party.append(TestChars.pregen(id, 5))
	var b := Banter.new(3)
	assert_true(b.next(st, "party").is_empty(), "no act yet: nothing plays")
	st.set_flag("gl_crashed", true)
	var played := 0
	for _i in 30:
		var lines := b.next(st)
		if lines.is_empty():
			break
		played += 1
		for line in lines:
			assert_true(str(line["speaker_id"]) in IDS or bool(line["narrator"]), str(line))
	assert_eq(played, 9, "all nine of act one play for a party of all six, and no other act")
	st.set_flag("vessla_slain", true)
	st.set_flag("act2_done", 2)
	played = 0
	for _i in 30:
		if b.next(st).is_empty():
			break
		played += 1
	assert_eq(played, 9, "act two's nine")
	st.set_flag("act2_done", 5)
	played = 0
	for _i in 30:
		if b.next(st).is_empty():
			break
		played += 1
	assert_eq(played, 9, "act three's nine")
	# A party of two hears only what the two can say.
	var two := StoryState.new()
	two.party.append(TestChars.pregen("rook_coldwake", 5))
	two.party.append(TestChars.pregen("silas_vane", 5))
	two.set_flag("gl_crashed", true)
	var b2 := Banter.new(5)
	var n := 0
	for _i in 30:
		var lines := b2.next(two)
		if lines.is_empty():
			break
		n += 1
		for line in lines:
			assert_true(str(line["speaker_id"]) in ["rook_coldwake", "silas_vane"], str(line))
	assert_eq(n, 1, "Rook and Silas have one act-one exchange to themselves")


# --- Region banter (narrative/banter/<region>.dialogue) ----------------------------------------------------------------------

const REGIONS: Array[String] = ["ghostlight_express", "wickermoor", "crooked_house", "foxwillow", "crimson_monastery", "drowned_crossroads", "skitterdeep_mine",
	"memorys_rest", "dawns_gate", "hartsblight_forest", "maidenmist_cemetery", "crooked_nightmare"]


## {location id: region} for every location in data/locations.
func _location_regions() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://data/locations")
	for f in dir.get_files():
		if f.ends_with(".json"):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/locations/" + f))
			if d is Dictionary:
				out[str((d as Dictionary).get("id", ""))] = str((d as Dictionary).get("region", ""))
	return out


## A state in which `cond`'s story gate holds: every positive flag set (a count for a `>=`), the place named by its first `at:`, the whole company in the party.
func _state_for(cond: String) -> StoryState:
	var st := StoryState.new()
	for id in IDS:
		st.party.append(TestChars.pregen(id, 5))
	var at := RegEx.create_from_string("\\bat:([a-z0-9_]+)").search(cond)
	if at != null:
		st.location = at.get_string(1)
	for m in RegEx.create_from_string("(not\\s+)?flag\\.([a-z0-9_]+)(?:\\s*(>=|>|==)\\s*(\\d+))?").search_all(cond):
		if m.get_string(1) != "":
			continue
		st.set_flag(m.get_string(2), maxi(int(m.get_string(4)), 1) if m.get_string(3) != "" else true)
	return st


func test_every_region_has_a_banter_file_of_six_to_eight_exchanges_about_its_own_places() -> void:
	var where := _location_regions()
	for region in REGIONS:
		var df := DialogueFile.load_key("banter/" + region)
		assert_true(df != null, region)
		assert_true(df.errors.is_empty(), "%s: %s" % [region, str(df.errors)])
		var nodes := _raw_nodes("res://narrative/banter/%s.dialogue" % region)
		assert_true(nodes.size() >= 6 and nodes.size() <= 8, "%s: six to eight exchanges (%d)" % [region, nodes.size()])
		var heard := {}
		for node: String in nodes:
			var lines := nodes[node] as Array
			assert_true(str(lines[0]).begins_with("if "), "%s:%s opens with an if" % [region, node])
			var cond := str(lines[0]).substr(3)
			var places := RegEx.create_from_string("\\bat:([a-z0-9_]+)").search_all(cond)
			assert_true(places.size() >= 1, "%s:%s names its place: %s" % [region, node, cond])
			for m in places:
				assert_eq(str(where.get(m.get_string(1), "(no such place)")), region, "%s:%s: %s is in this region" % [region, node, m.get_string(1)])
			var said := 0
			var spoken := {}
			for l: Variant in lines:
				var m := RegEx.create_from_string("^interject name:([a-z0-9_]+): ").search(str(l))
				if m != null:
					said += 1
					spoken[m.get_string(1)] = true
					heard[m.get_string(1)] = true
			assert_true(spoken.size() >= 2 and spoken.size() <= 3, "%s:%s has two or three speakers" % [region, node])
			assert_true(said >= 4 and said <= 9, "%s:%s says 4 to 9 lines (%d)" % [region, node, said])
			for who: String in spoken:
				assert_true(cond.contains("name:" + who), "%s:%s opens by naming %s" % [region, node, who])
		for id in IDS:
			assert_true(heard.has(id), "%s: %s speaks somewhere" % [region, id])


func test_a_region_exchange_plays_only_in_its_place_with_its_speakers_and_once_its_story_state_holds() -> void:
	for region in REGIONS:
		var nodes := _raw_nodes("res://narrative/banter/%s.dialogue" % region)
		for node: String in nodes:
			var cond := str((nodes[node] as Array)[0]).substr(3)
			var st := _state_for(cond)
			assert_true(StoryConditions.check(cond, st), "%s:%s holds in its own state: %s" % [region, node, cond])
			var elsewhere := _state_for(cond)
			elsewhere.location = "wickermoor_village" if st.location != "wickermoor_village" else "foxwillow"
			assert_false(StoryConditions.check(cond, elsewhere), "%s:%s holds only in its place" % [region, node])
			var short := _state_for(cond)
			short.party.remove_at(short.party.size() - 1 if not StoryState.member_matches(short.party[short.party.size() - 1], "name:rook_coldwake") else 0)
			var missing := ""
			for id in IDS:
				if not short.party.any(func(c: Character) -> bool: return c.id == id):
					missing = id
			if cond.contains("name:" + missing):
				assert_false(StoryConditions.check(cond, short), "%s:%s needs %s" % [region, node, missing])
			# A remark gated on a flag being unset stops the moment the story moves on.
			for m in RegEx.create_from_string("not\\s+flag\\.([a-z0-9_]+)").search_all(cond):
				var later := _state_for(cond)
				later.set_flag(m.get_string(1), true)
				assert_false(StoryConditions.check(cond, later), "%s:%s stops once %s" % [region, node, m.get_string(1)])


func test_region_banter_plays_through_the_banter_engine_in_its_region_only() -> void:
	for region in REGIONS:
		var nodes := _raw_nodes("res://narrative/banter/%s.dialogue" % region)
		var first := str((nodes[nodes.keys()[0]] as Array)[0]).substr(3)
		var st := _state_for(first)
		var b := Banter.new(7)
		# Banter.next plays this region's files and the party's; ask for another region and this one's stay silent.
		var other := "dawns_gate" if region != "dawns_gate" else "foxwillow"
		var got := false
		for _i in 40:
			var lines := b.next(st, region)
			if lines.is_empty():
				break
			got = true
			for line in lines:
				assert_true(str(line["speaker_id"]) in IDS, "%s: %s" % [region, str(line)])
		assert_true(got, "%s plays something in its own first state" % region)
		var st2 := _state_for(first)
		var b2 := Banter.new(7)
		for _i in 40:
			var lines := b2.next(st2, other)
			if lines.is_empty():
				break
			assert_false(str(lines[0]["text"]) in FileAccess.get_file_as_string("res://narrative/banter/%s.dialogue" % region), "%s's lines don't play in %s" % [region, other])
