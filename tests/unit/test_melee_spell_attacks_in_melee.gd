extends TestCase
## The melee spell attacks (2024 PHB: Chill Touch, Shocking Grasp) are made at a creature within reach, so an enemy within 5 ft gives
## them no Disadvantage (that is for Ranged attacks made with a hostile within 5 ft; Ashwin, 2026-11-03: "Chill Touch is a melee spell
## attack, there shouldn't be disadvantage if an enemy is within 5 ft"). The roll and the target tooltip both read the same rule, and
## a ranged spell (Fire Bolt) still has it. Cordelia, the pregen who knows Chill Touch, is checked as the game builds her.


func _wizard() -> Character:
	var ch := TestChars.custom("wizard", "human", 4, {})
	var prepared := ch.spellcasting[0]["prepared"] as Array
	for sid: String in ["chill_touch", "shocking_grasp", "fire_bolt"]:
		if not sid in prepared:
			prepared.append(sid)
	return ch


func _preview(e: Encounter, c: Combatant, spell_id: String, t: Combatant) -> Dictionary:
	var prev := (c.creature as Character).spell_preview(spell_id, 0)
	return ActionCatalog.new(e).spell_attack_preview(c, spell_id, t, prev["attack"] as Breakdown)


func _roll_edge(e: Encounter) -> String:
	var kind := "none"
	for x: Dictionary in e.events:
		if str(x["type"]) == "attack":
			kind = str((x.get("edge", {}) as Dictionary).get("kind", ""))
	return kind


func _check_no_disadvantage(ch: Character, sid: String, who: String) -> void:
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 3))
	var near := TestCombat.punching_bag(e, Vector2i(3, 3))
	TestCombat.punching_bag(e, Vector2i(2, 4))   # a second foe beside them too
	TestCombat.start_with(e, c)
	var pv := _preview(e, c, sid, near)
	assert_eq(str(pv["edge"]), "", "%s's %s: the tooltip shows no Disadvantage: %s" % [who, sid, str(pv["lines"])])
	e.events.clear()
	assert_true(e.spells.cast(c, sid, 0, [near]).ok, "%s casts %s" % [who, sid])
	assert_eq(_roll_edge(e), "", "%s's %s: the roll has no Disadvantage" % [who, sid])


func test_chill_touch_and_shocking_grasp_have_no_disadvantage_with_a_foe_beside_the_caster() -> void:
	for sid: String in ["chill_touch", "shocking_grasp"]:
		_check_no_disadvantage(_wizard(), sid, "a wizard")


func test_cordelia_as_the_game_builds_her_casts_chill_touch_without_disadvantage() -> void:
	_check_no_disadvantage(Pregens.build("cordelia_skein", 3), "chill_touch", "Cordelia")


func test_a_ranged_spell_attack_still_has_it() -> void:
	var e := TestCombat.open_field()
	var c := e.add(_wizard(), &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(3, 3))
	var far := TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	assert_eq(str(_preview(e, c, "fire_bolt", far)["edge"]), "disadvantage", "Fire Bolt with a foe beside the caster")
