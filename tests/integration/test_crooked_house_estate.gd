extends TestCase
## R12, the Crooked House: the estate's people are wired. Gilly and Walter at the gate until the house turns (Gilly speaks first),
## the Crooked Man on the porch from the turn until the storm breaks, the Jenkins back at the gate once Vessla is dead; the porch
## steps into the house open only after the Crooked Man has been met; every conversation they start has the node it names, and
## every npc the conversations call up exists. The estate has no fight of its own (its fights are inside the house).

const ESTATE := "druskenvald_estate"


func _loc() -> Dictionary:
	return Compendium.shared().get_entry("locations", ESTATE)


func _state(flags: Dictionary) -> StoryState:
	GameState.reset()
	var st := GameState.story
	for k: String in flags:
		st.set_flag(k, flags[k])
	return st


func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


## Who stands where under these flags: the first entry per npc whose `when` holds (the game's own rule), npc id -> entry.
func _standing(flags: Dictionary) -> Dictionary:
	var st := _state(flags)
	var out := {}
	for n: Dictionary in _loc().get("npcs", []):
		var id := str(n["npc"])
		if out.has(id):
			continue
		var w := str(n.get("when", ""))
		if w == "" or StoryConditions.check(w, st):
			out[id] = n
	GameState.reset()
	return out


func test_the_jenkins_wait_at_the_gate_until_the_house_turns() -> void:
	var now := _standing({})
	assert_true(now.has("gilly_jenkin") and now.has("walter_jenkin"), "both are at the gate on the first night")
	assert_true(not now.has("crooked_man"), "and the Crooked Man is not yet on the porch")
	assert_eq(str((now["gilly_jenkin"] as Dictionary)["dialogue"]), "crooked_house/jenkins_gate:start", "Gilly starts the gate talk")
	assert_eq(str((now["walter_jenkin"] as Dictionary)["dialogue"]), "crooked_house/jenkins_gate:start", "Walter answers to the same talk")
	assert_true(int((now["gilly_jenkin"] as Dictionary).get("approach", 0)) > 0, "Gilly speaks first")
	assert_true(not (now["walter_jenkin"] as Dictionary).has("approach"), "Walter does not (he has no lines of his own)")
	var turned := _standing({"crooked_house_turned": true})
	assert_true(not turned.has("gilly_jenkin") and not turned.has("walter_jenkin"), "once the house has turned they have gone down the hill")


func test_the_crooked_man_stands_on_the_porch_from_the_turn_until_the_storm() -> void:
	var turned := _standing({"crooked_house_turned": true})
	assert_true(turned.has("crooked_man"), "the turn puts him on the porch")
	var man := turned["crooked_man"] as Dictionary
	assert_eq(str(man["dialogue"]), "crooked_house/crooked_man:porch", "he opens with the porch talk")
	assert_true(int(man.get("approach", 0)) > 0, "and speaks when the party comes up")
	var porch: Array = []
	for a: Dictionary in _loc().get("areas", []):
		if str(a["id"]) == "manor_porch":
			porch = a["cells"] as Array
	var c := _cell(man["cell"] as Array)
	assert_true(c.x >= int((porch[0] as Array)[0]) and c.x <= int((porch[1] as Array)[0]) and c.y >= int((porch[0] as Array)[1]) and c.y <= int((porch[1] as Array)[1]), "he stands on the porch")
	assert_true(not _standing({"crooked_house_turned": true, "crooked_man_met": true}).has("crooked_man"), "the storm sends him off")


func test_the_jenkins_come_back_after_vessla() -> void:
	var back := _standing({"crooked_house_turned": true, "crooked_man_met": true, "vessla_slain": true})
	assert_true(back.has("gilly_jenkin") and back.has("walter_jenkin"), "they are in the grounds once the hag is dead")
	assert_eq(str((back["gilly_jenkin"] as Dictionary)["dialogue"]), "crooked_house/jenkins_after:start", "Gilly starts the after talk")
	assert_eq(str((back["walter_jenkin"] as Dictionary)["dialogue"]), "crooked_house/jenkins_after:start", "Walter the same")
	assert_true(int((back["gilly_jenkin"] as Dictionary).get("approach", 0)) > 0, "Gilly greets the party first")


func test_the_porch_steps_open_only_after_the_crooked_man() -> void:
	var porch: Dictionary = {}
	for e: Dictionary in _loc().get("exits", []):
		if str(e["to"]) == "crooked_house_first":
			porch = e
	assert_true(not porch.is_empty(), "the steps lead into the house")
	assert_true(str(porch.get("locked_text", "")).length() > 20, "and say why they are shut")
	var when := str(porch["when"])
	assert_true(not StoryConditions.check(when, _state({})), "shut on the first night")
	assert_true(not StoryConditions.check(when, _state({"crooked_house_turned": true})), "shut while the Crooked Man waits")
	assert_true(StoryConditions.check(when, _state({"crooked_house_turned": true, "crooked_man_met": true})), "open once the storm has broken")
	GameState.reset()
	var village := false
	for e: Dictionary in _loc().get("exits", []):
		if str(e["id"]) == "to_village":
			village = str(e["to"]) == "travel" and not e.has("when")
	assert_true(village, "the hill road to the village stays as it was")


func test_every_conversation_has_its_node_and_every_npc_exists() -> void:
	var seen := {}
	for n: Dictionary in _loc().get("npcs", []):
		assert_true(not Compendium.shared().get_entry("npcs", str(n["npc"])).is_empty(), "%s is an npc" % n["npc"])
		var ref := str(n["dialogue"])
		var key := ref.substr(0, ref.rfind(":"))
		var node := ref.substr(ref.rfind(":") + 1)
		var file := DialogueFile.load_key(key)
		assert_true(file != null, "%s is a dialogue file" % key)
		if file != null:
			assert_true(file.errors.is_empty(), "%s parses clean" % key)
			assert_true(file.nodes.has(node), "%s has node %s" % [key, node])
			seen[key] = file
	# The people the gate talk and the porch talk call up.
	for key: String in ["crooked_house/jenkins_gate", "crooked_house/crooked_man", "crooked_house/jenkins_after"]:
		var file := DialogueFile.load_key(key)
		assert_true(file != null, "%s exists" % key)
		if file == null:
			continue
		for id: String in file.nodes:
			for s: Dictionary in file.nodes[id]:
				if str(s.get("t")) in ["appear", "vanish"]:
					assert_true(not Compendium.shared().get_entry("npcs", str(s["npc"])).is_empty(), "%s: %s is an npc" % [key, s["npc"]])


func test_the_gate_talk_sets_what_the_estate_reads() -> void:
	var file := DialogueFile.load_key("crooked_house/jenkins_gate")
	var sets := {}
	for id: String in file.nodes:
		for s: Dictionary in file.nodes[id]:
			if str(s.get("t")) == "set":
				sets[str(s["flag"])] = true
	assert_true(sets.has("crooked_house_turned"), "the gate talk ends by turning the house")
	var porch := DialogueFile.load_key("crooked_house/crooked_man")
	var porch_sets := {}
	for id: String in porch.nodes:
		for s: Dictionary in porch.nodes[id]:
			if str(s.get("t")) == "set":
				porch_sets[str(s["flag"])] = true
	assert_true(porch_sets.has("crooked_man_met"), "the porch talk ends in the storm")
