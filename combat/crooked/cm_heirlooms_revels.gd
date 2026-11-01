class_name CmHeirloomsRevels
extends CmHeirloomPart
## The Fool's Day prizes (R21) and two cursed treasures whose properties need code: the Revelry Suit (a Cursed Curio), the
## Marotte of the Lord of Fools and the Amber Birdcage (a Cursed Curio from the Fields of the Crow, R13). The Cauldron of the
## Vermintoll Coven (R22) is all data: its bonus and Vermincall. Legendary properties wait: docs/rules/deviations.md.

const SUIT := "revelry_suit"
const MAROTTE := "marotte_of_the_lord_of_fools"
const CAGE := "amber_birdcage"

const DODGE := "cm_revelry_dodge"
const STEPS := "cm_revelry_steps"
const SENSE := "cm_birdcage_sense"
const CAPTURE := "cm_birdcage_capture"
const EAT := "cm_birdcage_eat"

## On the suit's inventory entry: the Dancing Curse's save DC (0 to start, 2 more for each use, once a Long Rest).
const DANCE_DC := "cm_dance_dc"
## On the birdcage's entry: the songbirds in it ({id, name, cr}) and how far its curse has grown.
const BIRDS := "cm_birds"
const CAGE_CURSE := "cm_curse"
const CAGE_KEY := "cm_birdcage_curse"
const CAPTURE_RANGE_FT := 30


func handles_item_power(custom: String) -> bool:
	return custom in [DODGE, STEPS, SENSE, CAPTURE, EAT]


func item_power_why(c: Combatant, p: Dictionary) -> String:
	match str((p["power"] as Dictionary).get("custom", "")):
		DODGE:
			return "Used when a Dexterity save fails"
		STEPS, SENSE:
			return "" if c.bonus_available else "No Bonus Action left"
		CAPTURE:
			return "" if _capturable(c, null) != null else "No Bloodied fiend within 30 ft"
		EAT:
			return "" if not (entry_of(c, CAGE).get(BIRDS, []) as Array).is_empty() else "No songbird in the cage"
	return ""


func item_power_use(c: Combatant, p: Dictionary, targets: Array, _point: Vector2, _opts: Dictionary) -> CombatResult:
	var picked: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
	match str((p["power"] as Dictionary).get("custom", "")):
		STEPS:
			return _wild_steps(c)
		SENSE:
			return _sense(c)
		CAPTURE:
			return _capture(c, picked)
		EAT:
			return _eat(c)
	return CombatResult.fail("Not available")


# --- The Revelry Suit ---------------------------------------------------------------------------------------------

## Wild Steps: a Bonus Action to dance the bearer's Speed without provoking Opportunity Attacks.
func _wild_steps(c: Combatant) -> CombatResult:
	var e := enc()
	if not c.bonus_available:
		return CombatResult.fail("No Bonus Action left")
	e.items._pay(c, "bonus")
	c.free_move_ft += c.speed()
	var r := CombatResult.new()
	r.lines.append(e.log.add("info", "%s kicks up a reel: %d ft of dancing that draws no Opportunity Attacks (Wild Steps)" % [c.name(), c.speed()], c.id))
	_dance_grows(c)
	return r


## Each use of the suit's magic tightens its curse: the Dancing Curse's DC goes up by 2, once a Long Rest (a hidden
## once-a-Long-Rest power counts it).
func _dance_grows(c: Combatant) -> void:
	var entry := entry_of(c, SUIT)
	if entry.is_empty() or not use_left(c, SUIT, "curse"):
		return
	spend_use(c, SUIT, "curse")
	entry[DANCE_DC] = int(entry.get(DANCE_DC, 0)) + 2
	_log("info", "The suit's tune gets louder in %s's head (the Dancing Curse: DC %d)" % [c.name(), int(entry[DANCE_DC])], c)


## The Dancing Curse: as Initiative is rolled, the bearer makes a Wisdom save against the curse's DC or spends its
## first turn in a folk dance: Incapacitated, Speed 0.
func initiative_rolled() -> void:
	for c in enc().combatants:
		if not holds(c, SUIT):
			continue
		var dc := int(entry_of(c, SUIT).get(DANCE_DC, 0))
		if saves(c, &"wis", dc, "the Dancing Curse"):
			continue
		var fx := item_fx(c, "The Dancing Curse", SUIT, "cm_dancing_curse").with_condition(&"incapacitated") \
			.with_modifier("speed_percent", {"value": 0})
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = c.id
		c.creature.add_effect(fx)
		_log("condition", "%s can't help it: the suit dances them through their first turn" % c.name(), c)


## Dancing Dodge: once a dusk, a failed Dexterity save succeeds while the bearer's Speed isn't 0. Coulrophobia (Marotte):
## after the bearer saves against fear, its source makes the same save or is Frightened. Fortune's Fool (Marotte): a
## natural 1 gives Hideous Laughter back.
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	if "death_save" in keys:
		return
	_dodge(c, t, keys, out)
	_coulrophobia(c, t, keys, out)
	if t.kept == 1 and holds(c, MAROTTE):
		out.append({"kind": "cm_fortunes_fool", "reactor": c, "forced": true, "use": func() -> void: _fools_luck(c)})


func _dodge(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	if t.kind != D20Test.Kind.SAVING_THROW or t.target <= 0 or t.success or not "save:dex" in keys or not holds(c, SUIT) \
			or c.speed() <= 0 or not use_left(c, SUIT, "dodge"):
		return
	out.append({"kind": "cm_dancing_dodge", "reactor": c, "title": "Dancing Dodge?", "spends_reaction": false, "default": "ask",
		"text": "%s fails a Dexterity save (%d vs DC %d). Dance out of the way and succeed instead? (Once a dusk; the curse grows.)" % [c.name(), t.total, t.target],
		"cost": "Dancing Dodge (once a dusk)",
		"still": func() -> bool: return not t.success and use_left(c, SUIT, "dodge"),
		"use": func() -> void: _dodged(c, t)})


func _dodged(c: Combatant, t: D20Test) -> void:
	spend_use(c, SUIT, "dodge")
	t.success = true
	t.reroll_note = ("%s; " % t.reroll_note if t.reroll_note != "" else "") + "Dancing Dodge: succeeds instead"
	_log("info", "%s twirls clear (Dancing Dodge): the save succeeds" % c.name(), c, [t.describe()])
	_dance_grows(c)


# --- The Marotte of the Lord of Fools -----------------------------------------------------------------------------

func _coulrophobia(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	if t.kind != D20Test.Kind.SAVING_THROW or not "save_vs:frightened" in keys or not t.success or not holds(c, MAROTTE) \
			or not e.spells.can_react(c):
		return
	var src := save_source(c, keys)
	if src == null or not src.is_alive() or not c.hostile_to(src):
		return
	var ab: StringName = &"wis"
	for k in keys:
		if k.begins_with("save:") and k != "save:all":
			ab = StringName(k.substr(5))
	var dc := t.target
	out.append({"kind": "cm_coulrophobia", "reactor": c, "trigger": src.id, "default": "auto",
		"title": "Reaction: Coulrophobia?",
		"text": "%s shrugs off %s's terror. Turn the marotte's grin on them: the same save (DC %d) or they're Frightened?" % [c.name(), src.name(), dc],
		"cost": "Reaction (Marotte of the Lord of Fools)",
		"still": func() -> bool: return t.success and e.spells.can_react(c) and src.is_alive(),
		"use": func() -> void: _coulro(c, src, ab, dc)})


func _coulro(c: Combatant, src: Combatant, ab: StringName, dc: int) -> void:
	c.reaction_available = false
	_log("reaction", "The marotte's painted face leers at %s (Coulrophobia)" % src.name(), c)
	var keys: Array[String] = ["save_vs:frightened"]
	if saves(src, ab, dc, "Coulrophobia", keys):
		return
	var fx := item_fx(c, "Coulrophobia", MAROTTE, "cm_coulrophobia:" + c.id).with_condition(&"frightened")
	fx.lasting_rounds(10, src.id)
	fx.repeat_save = {"ability": str(ab), "dc": dc, "when": "end"}
	src.creature.add_effect(fx)
	_log("condition", "%s is Frightened of %s's grinning fool (Coulrophobia)" % [src.name(), c.name()], src)
	enc().events.append({"type": "condition", "id": src.id})


func _fools_luck(c: Combatant) -> void:
	if restore_use(c, MAROTTE, "laughter"):
		_log("info", "A natural 1 tickles the marotte: Fortune's Fool's laughter is ready again", c)


# --- The Amber Birdcage -------------------------------------------------------------------------------------------

## Sense fiends: a Bonus Action names every Fiend within 60 ft.
func _sense(c: Combatant) -> CombatResult:
	var e := enc()
	e.items._pay(c, "bonus")
	var found: Array[String] = []
	for o in e.combatants:
		if o != c and o.is_alive() and o.creature.creature_type == &"fiend" and e.distance(c, o) <= 60:
			found.append("%s (%d ft)" % [o.name(), e.distance(c, o)])
	var r := CombatResult.new()
	if found.is_empty():
		r.lines.append(e.log.add("info", "The amber cage stays still: no fiend within 60 ft", c.id))
	else:
		r.lines.append(e.log.add("info", "The amber cage hums toward %s" % ", ".join(found), c.id))
	return r


## Capture Fiend: a Bloodied Fiend within 30 ft makes a DC 15 Charisma save or becomes an amber songbird in the cage (out
## of the fight; kept on the cage's entry). The curse grows.
func _capture(c: Combatant, picked: Combatant) -> CombatResult:
	var e := enc()
	var t := _capturable(c, picked)
	if t == null:
		return CombatResult.fail("No Bloodied fiend within 30 ft")
	e.items._pay(c, "action")
	var r := CombatResult.new()
	r.lines.append(e.log.add("info", "%s opens the amber cage at %s" % [c.name(), t.name()], c.id))
	if not saves(t, &"cha", 15, "the Amber Birdcage"):
		var entry := entry_of(c, CAGE)
		var birds := entry.get(BIRDS, []) as Array
		var cr := (t.creature as Monster).cr if t.creature is Monster else 0.0
		birds.append({"id": str(MonsterActions.data_of(t).get("id", t.name())), "name": t.name(), "cr": cr})
		entry[BIRDS] = birds
		e.legendary.vanish(t, "%s shrinks to an amber songbird behind the bars" % t.name())
		r.lines.append(e.log.add("info", "%s is caught in the cage, a songbird of amber" % t.name(), c.id))
		_cage_grows(c)
	return r


func _capturable(c: Combatant, picked: Combatant) -> Combatant:
	var e := enc()
	var ok := func(o: Combatant) -> bool:
		return o != c and o.is_alive() and not o.is_down() and o.creature.creature_type == &"fiend" and o.creature.is_bloodied() \
			and e.distance(c, o) <= CAPTURE_RANGE_FT
	if picked != null:
		return picked if bool(ok.call(picked)) else null
	for o in e.combatants:
		if bool(ok.call(o)):
			return o
	return null


## Eat a songbird: the fiend it was dies for good, and the bearer regains a spell slot of up to half its CR (the highest
## spent one), or Temporary Hit Points equal to its CR when there's no such slot. The curse grows.
func _eat(c: Combatant) -> CombatResult:
	var e := enc()
	var entry := entry_of(c, CAGE)
	var birds := entry.get(BIRDS, []) as Array
	if birds.is_empty():
		return CombatResult.fail("No songbird in the cage")
	e.items._pay(c, "action")
	var bird := birds.pop_back() as Dictionary
	entry[BIRDS] = birds
	var cr := float(bird.get("cr", 0.0))
	var r := CombatResult.new()
	r.lines.append(e.log.add("info", "%s swallows the amber songbird that was %s; somewhere a fiend dies for good" % [c.name(), bird.get("name", "a fiend")], c.id))
	var ch := _ch(c)
	var top := mini(9, floori(cr / 2.0))
	var got := 0
	for lvl in range(top, 0, -1):
		if ch != null and ch.recover_slot(lvl):
			got = lvl
			break
	if got > 0:
		r.lines.append(e.log.add("heal", "%s regains a level %d spell slot" % [c.name(), got], c.id))
	else:
		var thp := maxi(1, ceili(cr))
		c.creature.add_temp_hp(thp, "Amber Birdcage")
		r.lines.append(e.log.add("heal", "%s gains %d Temporary Hit Points" % [c.name(), thp], c.id))
	_cage_grows(c)
	return r


## The cage's curse: 1 off Wisdom saves (the item's data), 1 more for each capture or meal (an Effect each fight).
func _cage_grows(c: Combatant) -> void:
	var entry := entry_of(c, CAGE)
	if entry.is_empty():
		return
	entry[CAGE_CURSE] = int(entry.get(CAGE_CURSE, 0)) + 1
	_cage_curse(c)
	_log("info", "The cage's bars press closer about %s's heart (Wisdom saves -%d)" % [c.name(), 1 + int(entry[CAGE_CURSE])], c)


func _cage_curse(c: Combatant) -> void:
	var n := int(entry_of(c, CAGE).get(CAGE_CURSE, 0))
	var old := fx_of(c, CAGE_KEY)
	if old != null:
		c.creature.remove_effect(old)
	if n <= 0:
		return
	c.creature.add_effect(item_fx(c, "The Amber Birdcage's curse", CAGE, CAGE_KEY).with_modifier("save", {"ability": "wis", "value": -n}))


func fight_started() -> void:
	for c in enc().combatants:
		if holds(c, CAGE):
			_cage_curse(c)
