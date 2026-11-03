extends TestCase
## The story guests' lines while they walk with the party (narrative/banter/guest_<id>.dialogue, story/banter.gd): every file
## reads clean, every node opens with an `if` that needs its own guest and is named for a moment Banter draws on, and each
## node plays through Banter.guest_next in a state where its opening holds, and stays silent once its guest has gone.

const GUESTS: Array[String] = ["adela_druskenvald", "phillip_druskenvald", "william_lodge", "yorgrim", "mrs_oakum"]
const COMPANIONS: Array[String] = ["rook_coldwake", "tobin_hayward", "silas_vane", "delphine_ravelle", "lucan_houndstooth", "cordelia_skein"]
const MOMENT_OF := {"quest_": "enter", "place_": "enter", "fight_": "fight", "idle_": "idle"}


## {node: opening condition} for a guest's file.
func _openings(guest: String) -> Dictionary:
	var out := {}
	var cur := ""
	for line in FileAccess.get_file_as_string("res://narrative/banter/guest_%s.dialogue" % guest).split("\n"):
		var l := line.strip_edges()
		if l.begins_with("~ "):
			cur = l.substr(2)
		elif cur != "" and not out.has(cur) and l.begins_with("if "):
			out[cur] = l.substr(3)
	return out


## A state where `cond` holds: the guests it names along, the party the six, the first place it names, its flags set and
## its quest at the stage it names (`not` parts and the other places of an `or` are left alone).
func _state_for(cond: String) -> StoryState:
	var st := StoryState.new()
	for id in COMPANIONS:
		st.party.append(TestChars.pregen(id, 9))
	for m in RegEx.create_from_string("guest:([a-z_]+)").search_all(cond):
		st.guest_ids.append(m.get_string(1))
	var at := RegEx.create_from_string("\\bat:([a-z0-9_]+)").search(cond)
	if at != null:
		st.location = at.get_string(1)
	for m in RegEx.create_from_string("(not\\s+)?flag\\.([a-z0-9_]+)").search_all(cond):
		if m.get_string(1) == "":
			st.set_flag(m.get_string(2), true)
	for m in RegEx.create_from_string("quest\\.([a-z0-9_]+) == ([a-z0-9_]+)").search_all(cond):
		st.set_quest_stage(m.get_string(1), m.get_string(2))
	return st


func test_every_guest_file_reads_with_no_errors() -> void:
	for guest in GUESTS:
		var df := DialogueFile.load_key("banter/guest_" + guest)
		assert_true(df != null, guest)
		assert_true(df.errors.is_empty(), "%s: %s" % [guest, str(df.errors)])
		assert_true(df.order.size() >= 1, guest)


func test_every_node_needs_its_guest_and_is_named_for_a_moment() -> void:
	for guest in GUESTS:
		var openings := _openings(guest)
		assert_eq(openings.size(), DialogueFile.load_key("banter/guest_" + guest).order.size(), "%s: every node opens with an if" % guest)
		for node: String in openings:
			assert_true(str(openings[node]).contains("guest:" + guest), "%s:%s needs %s along" % [guest, node, guest])
			var prefix := node.get_slice("_", 0) + "_"
			assert_true(MOMENT_OF.has(prefix), "%s:%s is named for a moment (quest_, place_, fight_ or idle_)" % [guest, node])


func test_each_node_plays_through_banter_in_its_moment_and_not_once_its_guest_has_gone() -> void:
	for guest in GUESTS:
		var openings := _openings(guest)
		for node: String in openings:
			var cond := str(openings[node])
			var st := _state_for(cond)
			assert_true(StoryConditions.check(cond, st), "%s:%s holds in its own state: %s" % [guest, node, cond])
			var moment := str(MOMENT_OF[node.get_slice("_", 0) + "_"])
			# Mark every other node of the moment played, so this one is the one Banter picks.
			for other: String in openings:
				if other != node:
					st.flags["_banter/banter/guest_%s:%s" % [guest, other]] = true
			var lines := Banter.new(3).guest_next(st, moment, guest)
			assert_false(lines.is_empty(), "%s:%s plays at its moment (%s)" % [guest, node, moment])
			for line in lines:
				var who := str(line["speaker_id"])
				assert_true(who in GUESTS or who in COMPANIONS, "%s:%s: %s" % [guest, node, str(line)])
			var gone := _state_for(cond)
			gone.guest_ids.erase(guest)
			assert_true(Banter.new(3).guest_next(gone, moment, guest).is_empty(), "%s:%s is silent once %s has gone" % [guest, node, guest])
