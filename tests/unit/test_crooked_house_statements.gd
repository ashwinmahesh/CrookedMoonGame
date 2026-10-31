extends TestCase
## R12's dialogue uses the engine's real statements where it once had stand-ins (r12-statements): the séance's psychic stings
## (`damage` stepping up 1d4 to 1d12 and capping at five), the portraits' gaze (1d6 psychic on the failed branch), Petunia's appeal and
## Arthur's lullaby at DC 15 with Advantage (`adv`), and Wisp's Hit Dice boon (`hit_dice restore all party`).

const CH := "crooked_house/"
## The séance's stings 1..5: the largest the damage die can take from each hero.
const STING_DIE := [4, 6, 8, 10, 12]


func _story() -> StoryState:
	var st := StoryState.new()
	for id: String in ["thistle", "hedda_ironvow"]:
		st.party.append(TestChars.pregen(id, 4))
	return st


## Runs the node until the conversation stops for the player (or ends).
func _run(st: StoryState, key: String) -> Array[Dictionary]:
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start(key), key)
	var beats: Array[Dictionary] = []
	for _i in 30:
		var beat := r.next()
		beats.append(beat)
		if str(beat["kind"]) in ["options", "end"]:
			break
	return beats


func test_the_files_read() -> void:
	for name: String in ["seance", "portraits", "petunia", "arthur", "wisp"]:
		var f := DialogueFile.load_key(CH + name)
		assert_true(f != null, name)
		assert_true(f.errors.is_empty(), "%s: %s" % [name, str(f.errors)])


func test_every_sting_hurts_every_hand_by_a_bigger_die() -> void:
	for n in range(1, 8):
		var st := _story()
		st.set_flag("seance_stings", n - 1)
		var before: Array[int] = []
		for ch in st.party:
			before.append(ch.hp)
		var beats := _run(st, CH + "seance:sting")
		var hurt := false
		for b in beats:
			hurt = hurt or str(b.get("text", "")).contains("Psychic damage")
		assert_true(hurt, "sting %d tells the damage" % n)
		var die: int = STING_DIE[mini(n, 5) - 1]
		for i in st.party.size():
			var lost := before[i] - st.party[i].hp
			assert_true(lost >= 1 and lost <= die, "sting %d: %s lost %d, within 1d%d" % [n, st.party[i].name, lost, die])
		assert_eq(int(st.get_flag("seance_stings", 0)), n)


func test_a_sting_never_fells_a_hero() -> void:
	var st := _story()
	st.set_flag("seance_stings", 4)
	for ch in st.party:
		ch.hp = 2
	_run(st, CH + "seance:sting")
	for ch in st.party:
		assert_true(ch.hp >= 1 and not ch.dead, "%s stands" % ch.name)


func test_the_failed_gaze_hurts_the_hero_in_the_conversation_only() -> void:
	for node: String in ["lockwood_cursed", "druskenvald_cursed", "party_cursed"]:
		var st := _story()
		var lead := st.leader_character()
		var other := st.party[1] if st.party[1] != lead else st.party[0]
		var before := lead.hp
		var other_before := other.hp
		_run(st, CH + "portraits:" + node)
		assert_true(lead.hp < before and before - lead.hp <= 6, "%s: 1d6 psychic" % node)
		assert_eq(other.hp, other_before, "%s: only the hero in the conversation" % node)
		assert_eq(int(st.get_flag("portrait_cursed", 0)), 1, node)


func _checks_of(key: String, node: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Variant in DialogueFile.load_key(key).nodes[node] as Array:
		var d := s as Dictionary
		if str(d.get("t", "")) == "option" and not (d["check"] as Dictionary).is_empty():
			out.append(d)
	return out


func test_petunias_appeal_is_dc_15_with_advantage() -> void:
	var appeals := _checks_of(CH + "petunia", "children_menu")
	assert_eq(appeals.size(), 1)
	var c := appeals[0]["check"] as Dictionary
	assert_eq(str(c["skill"]), "persuasion")
	assert_eq(int(c["dc"]), 15)
	assert_eq(str(c["edge"]), "adv")


func test_arthurs_lullaby_has_advantage_only_for_a_hero_who_heard_the_lament() -> void:
	var sung: Array[Dictionary] = []
	for o in _checks_of(CH + "arthur", "calm"):
		if str((o["check"] as Dictionary)["skill"]) == "performance":
			sung.append(o)
	assert_eq(sung.size(), 2, "two lullaby options")
	for o in sung:
		assert_eq(int((o["check"] as Dictionary)["dc"]), 15)
	var heard := sung[0] if str(sung[0]["cond"]) == "flag.memento_key" else sung[1]
	var unheard := sung[1] if heard == sung[0] else sung[0]
	assert_eq(str(heard["cond"]), "flag.memento_key")
	assert_eq(str((heard["check"] as Dictionary)["edge"]), "adv")
	assert_eq(str(unheard["cond"]), "not flag.memento_key")
	assert_eq(str((unheard["check"] as Dictionary)["edge"]), "", "no Advantage without the lament")


func test_wisps_boon_gives_every_hit_die_back() -> void:
	var st := _story()
	for ch in st.party:
		for k: String in ch.hit_dice():
			ch.hit_dice_spent[k] = 2
	var wisp := DialogueFile.load_key(CH + "wisp")
	var found := false
	for s: Variant in wisp.nodes["finale"] as Array:
		var d := s as Dictionary
		if str(d.get("t", "")) == "hit_dice":
			found = true
			assert_eq(str(d["how"]), "restore")
			assert_eq(int(d["count"]), -1, "all")
			assert_true(bool(d["party"]))
		assert_false(str(d.get("t", "")) == "time", "no time +60 stand-in")
	assert_true(found, "the finale restores Hit Dice")
