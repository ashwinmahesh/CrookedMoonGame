class_name CmBargains
extends CmPart
## The Crooked Moon's code for the book's Dark Bargains (chapter 6): the parts of them data can't say.
## CrookedFeatures forwards every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start
## "db_".
##
## A bargain is a dark gift (data/dark_gifts/): its benefit's and cost's features are walked like species traits, so
## `has(c, id)` sees them and their resources exist. In a fight this part plays Beast Skin's free Polymorph (on yourself
## only), Searing Silver, Never Alone's Doppelganger and its Unsettling Presence, Cheat Fate and its Delayed Price,
## Honeyed Words and Solitary Weakness, Hand of Death (Cling to Life, Death Knell), Pyre's Price, Critical Savior,
## Inured to Undeath, Iron Grit and Watery Doom, Tenuous Psyche under Calm Emotions, Furious Onslaught and the Red Haze,
## and Murderous Flight's crows (Whispered Secrets). What happens only between fights (Hoarded Stories, the Final
## Sacrifice's haunting, Draining Presence, Unholy Appetite, Withering Soul's detection, Precocious Friend) isn't here.

const PREFIX := "db_"

## Effect sources this part puts on creatures (each is also a flag where code reads it).
const FURY := "db_fury"
const HONEYED := "db_honeyed_words"
## Honeyed Words' 24 hours of immunity once the charm ends: an effect on the creature, so it outlives the fight.
const HONEYED_IMMUNE := "db_honeyed_immune"
const CLING_TOLL := "db_cling_toll"
const SILVER := "db_searing_silver"
const RUSTED := "db_rusted"
const CROWS := "db_crows"
const PYRE := "db_pyres_price"
const CHEATED := "db_cheated_fate"
const KNELL_BLOCK := "db_death_knell_block"

## The choice that names Iron Grit's damage type.
const IRON_GRIT_KEY := "gift.skin_of_coffin_nails.iron_grit"

## Hit Points seen before an action or spell: creature id -> {hp, zero, s, f, stable} (Cling to Life's halved healing,
## Death Knell).
var _hp_seen: Dictionary = {}


func prefix() -> String:
	return PREFIX


func cf() -> ClassFeatures:
	return enc().class_features


func _fx(c: Combatant, name: String, source: String) -> Effect:
	var fx := Effect.new(name, &"feature", source)
	fx.caster_id = c.id if c != null else ""
	return fx


## "Until the start of `owner`'s next turn".
func _until_start(fx: Effect, owner: Combatant) -> Effect:
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = owner.id
	return fx


## Puts `fx` on `t` and tells the log and the view.
func _condition(t: Combatant, fx: Effect, text: String) -> void:
	if t.creature.add_effect(fx):
		_log("condition", text, t)
		enc().events.append({"type": "condition", "id": t.id})


static func _has_effect(c: Combatant, source: String) -> bool:
	return c != null and c.creature.effects.any(func(x: Effect) -> bool: return x.source_id == source)


static func _end_effects(c: Combatant, source: String) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == source:
			c.creature.remove_effect(fx)


static func _up(c: Combatant) -> bool:
	return c != null and c.is_alive() and not c.is_down()


# --- The hotbar ---------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	if has(c, "never_alone"):
		var mine := _companion_of(c)
		if mine == null:
			out.append(_act("never_alone", "Never Alone", "Doppelganger · 1 hour", "bonus", _first(bw, _first(_res_why(c, "never_alone"), _seen_why(c))),
				"none", "Bonus Action, once a Long Rest, when no one else can see you: a companion steps out beside you (a Doppelganger), on your side, acting after you. While it's here, those who aren't your foes may be frightened (Unsettling Presence)."))
		else:
			out.append(_act("dismiss_companion", "Dismiss Companion", mine.name(), "action", aw, "none", "An action: you politely send your companion away."))
	if has(c, "honeyed_words"):
		var hw := _first(aw, _res_why(c, "honeyed_words"))
		if hw == "" and c.magic_action_used:
			hw = "Only one Magic action this turn"
		out.append(_act("honeyed_words", "Honeyed Words", "Charmed · 60 ft", "action", hw, "creature",
			"Magic action, once a Short Rest: a creature within 60 ft is Charmed and fights on your side for a day, until you or your allies hurt it or force a save on it. One that can't be charmed (or a boss) has Disadvantage on D20 Tests until your next turn instead, and you gain Temporary Hit Points equal to your level.", 60))
	if has(c, "furious_onslaught") and not _has_effect(c, FURY):
		var free := enc().current() == c and c.took_attack_action
		out.append(_act("furious_onslaught", "Furious Onslaught", "fury", "free" if free else "bonus",
			_first(enc()._turn_check(c) if free else bw, _res_why(c, "furious_onslaught")), "none",
			"Bonus Action (or free as you take the Attack action), once a Long Rest or after you kill a Humanoid: one more attack with each Attack action, and %d less damage from every hit. The Red Haze tests your will each turn (DC 15 Wisdom)." % c.creature.proficiency_bonus()))
	if _has_effect(c, FURY) and not c.has_meta("db_red_haze"):
		out.append(_act("end_fury", "End Fury", "", "free", "", "none", "Let the fury go."))
	if has(c, "murderous_flight") and ch.resource_left("murderous_flight") <= 0 and not _has_effect(c, "murderous_flight"):
		out.append(_act("murderous_flight_again", "Murderous Flight", "1 Exhaustion", "bonus", bw, "none",
			"Bonus Action: take flight again before your rest, for a level of Exhaustion."))


func perform(c: Combatant, id: String, t: Combatant, _cell: Vector2i, _point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if ch == null:
		return CombatResult.fail("Not available")
	match id.trim_prefix(PREFIX):
		"never_alone":
			var why := _first(e._bonus_check(c), _first(_res_why(c, "never_alone"), _seen_why(c)))
			if why != "" or _companion_of(c) != null:
				return CombatResult.fail(_first(why, "Your companion is already here"))
			ch.spend_resource("never_alone")
			c.bonus_available = false
			return _call_companion(c)
		"dismiss_companion":
			var mine := _companion_of(c)
			var why2 := e._action_check(c)
			if mine == null or why2 != "":
				return CombatResult.fail(_first(why2, "No companion"))
			e.spend_action(c)
			_log("info", "%s sends the companion away" % c.name(), c)
			e.spells.summons._dismiss(mine.id)
			return CombatResult.new()
		"honeyed_words":
			var why3 := _first(e._action_check(c), _res_why(c, "honeyed_words"))
			if why3 == "" and c.magic_action_used:
				why3 = "Only one Magic action this turn"
			if why3 != "":
				return CombatResult.fail(why3)
			if t == null or t == c or t.allied_with(c) or not _up(t) or e.distance(c, t) > 60:
				return CombatResult.fail("Choose a creature that isn't your ally within 60 ft")
			if _has_effect(t, HONEYED_IMMUNE):
				return CombatResult.fail("%s won't listen to sweet words again today" % t.name())
			e.spend_action(c)
			c.magic_action_used = true
			ch.spend_resource("honeyed_words")
			return _honeyed_words(c, t)
		"furious_onslaught":
			var free := e.current() == c and c.took_attack_action
			var why4 := _first(e._turn_check(c) if free else e._bonus_check(c), _res_why(c, "furious_onslaught"))
			if why4 != "" or _has_effect(c, FURY):
				return CombatResult.fail(_first(why4, "Already in a fury"))
			if not free:
				c.bonus_available = false
			ch.spend_resource("furious_onslaught")
			_enter_fury(c)
			return CombatResult.new()
		"end_fury":
			if not _has_effect(c, FURY) or c.has_meta("db_red_haze"):
				return CombatResult.fail("Not available")
			_end_fury(c, "let go")
			return CombatResult.new()
		"murderous_flight_again":
			var why5 := e._bonus_check(c)
			if why5 != "" or ch.resource_left("murderous_flight") > 0:
				return CombatResult.fail(_first(why5, "Use Murderous Flight"))
			c.creature.add_exhaustion(1)
			ch.restore_resource("murderous_flight")
			_log("info", "%s pays a level of Exhaustion to fly again (Murderous Flight)" % c.name(), c)
			return e.feature_recipes.perform(c, "murderous_flight", [])
	return CombatResult.fail("Not available")


# --- Never Alone and Unsettling Presence (Call of the Lonely) -----------------------------------------------------

## Why Never Alone can't be called: another creature (not your own companion) can see you.
func _seen_why(c: Combatant) -> String:
	var e := enc()
	for o in e.living():
		if o != c and not o.is_down() and str(o.get_meta("db_companion_of", "")) != c.id and e.can_see(o, c):
			return "%s can see you" % o.name()
	return ""


## The companion `c` called that is still here, or null.
func _companion_of(c: Combatant) -> Combatant:
	for o in enc().living():
		if str(o.get_meta("db_companion_of", "")) == c.id:
			return o
	return null


## The Doppelganger (2025 Monster Manual) that answers Never Alone, built as Beast Master's companion is.
static func doppelganger_block() -> Dictionary:
	return {"id": "doppelganger", "name": "Lonely Companion", "size": "medium", "type": "monstrosity", "alignment": "neutral",
		"ac": 14, "initiative": 4, "hp": {"average": 52, "dice": "52"}, "speed": {"walk": 30},
		"abilities": {"str": 11, "dex": 18, "con": 14, "int": 11, "wis": 12, "cha": 14},
		"skills": {"deception": 6, "insight": 3}, "condition_immunities": ["charmed"], "senses": {"darkvision": 60},
		"passive_perception": 11, "cr": 3, "xp": 0, "proficiency_bonus": 2, "summon": true, "ai_profile": "brute",
		"actions": [
			{"id": "multiattack", "name": "Multiattack", "kind": "multiattack", "multiattack": [{"action": "slam", "count": 2}],
				"summary": "Two Slam attacks."},
			{"id": "slam", "name": "Slam", "kind": "melee", "attack": {"bonus": 6, "reach": 5},
				"damage": [{"average": 11, "dice": "2d6+4", "type": "bludgeoning"}], "summary": "A heavy blow."},
			{"id": "unsettling_visage", "name": "Unsettling Visage", "kind": "save", "recharge": "6",
				"save": {"ability": "wis", "dc": 12, "success": "none"}, "area": {"shape": "emanation", "size": 15},
				"targets": {"range": 15, "sees_source": true},
				"on_fail": [{"do": "condition", "condition": "frightened", "until": "minute", "repeat_save": {"ability": "wis", "dc": 12, "when": "end"}}],
				"summary": "Recharge 6. Those within 15 ft who see its face: DC 12 Wis save or Frightened (saving again each turn)."}],
		"summary": "A companion that looks like a person, or a vague silhouette.", "text": "Never Alone."}


## Never Alone: the companion steps into a free space beside its caller, on its side, after it in Initiative.
func _call_companion(c: Combatant) -> CombatResult:
	var e := enc()
	var m := Monster.from_data(doppelganger_block(), e.dice)
	var spot := e.spells._free_cell_near(c.cell, CombatGrid.size_cells_for(m.size))
	var sc := e.add(m, &"guest" if c.side == &"party" else c.side, spot)
	sc.controller = c.controller
	sc.set_meta("summoner", c.id)
	sc.set_meta("vanishes", true)
	sc.set_meta("db_companion_of", c.id)
	if not e.spells.summoned.has(c.id):
		e.spells.summoned[c.id] = []
	(e.spells.summoned[c.id] as Array).append(sc.id)
	if e.state == Encounter.State.ACTIVE:
		e.insert_after(c, sc)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": spot, "caster": c.id})
	_log("info", "Someone steps out of the dark beside %s (Never Alone)" % c.name(), c)
	return CombatResult.new()


## Unsettling Presence: a creature that isn't hostile to the caller and starts its turn seeing it or its companion makes a
## DC 15 Wisdom save or is Frightened until its next turn starts.
func _unsettling_presence(t: Combatant) -> void:
	var e := enc()
	for h in e.living():
		var mine := _companion_of(h)
		if mine == null or not has(h, "unsettling_presence") or t == h or t == mine or t.hostile_to(h):
			continue
		if not (e.can_see(t, h) or e.can_see(t, mine)) or t.creature.is_condition_immune(&"frightened"):
			continue
		if cf()._save(t, &"wis", 15, "Unsettling Presence", "frightened"):
			continue
		var fx := _until_start(_fx(h, "Frightened (Unsettling Presence)", "db_unsettling_presence").with_condition(&"frightened"), t)
		_condition(t, fx, "A cold dread grips %s near %s and the companion" % [t.name(), h.name()])
		return


# --- Honeyed Words and Solitary Weakness (Cult of Personality) ----------------------------------------------------

## Whether Honeyed Words can't charm `t`: Immunity to Charmed, a boss or Legendary Resistance (designer's call).
func _charm_proof(t: Combatant) -> bool:
	if t.creature.is_condition_immune(&"charmed"):
		return true
	return t.creature is Monster and (Difficulty.is_boss(t.creature as Monster) or Legendary.resistances_of(t, enc().lair) > 0)


func _honeyed_words(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	e.events.append({"type": "ability", "id": c.id, "key": "honeyed_words", "targets": [t.id]})
	if _charm_proof(t):
		var fx := _until_start(_fx(c, "Unmoved (Honeyed Words)", "db_honeyed_unmoved"), c).with_modifier("disadvantage", {"on": "attack"}) \
			.with_modifier("disadvantage", {"on": "save:all"}).with_modifier("disadvantage", {"on": "check:all"})
		_condition(t, fx, "%s shrugs off %s's sweet words, shaken: Disadvantage on D20 Tests" % [t.name(), c.name()])
		cf()._temp(c, _ch(c).character_level(), "Honeyed Words")
		return CombatResult.new()
	var fx2 := _fx(c, "Charmed (Honeyed Words)", HONEYED).with_condition(&"charmed")
	fx2.ends = Effect.Ends.MINUTES
	fx2.minutes_left = 24 * 60
	if not t.creature.add_effect(fx2):
		_log("info", "%s can't be charmed: Honeyed Words has no effect" % t.name(), t)
		return CombatResult.new()
	t.set_meta("dominated_from", [str(t.side), str(t.controller)])
	t.side = &"guest" if c.side == &"party" else c.side
	t.controller = c.controller
	var tid := t.id
	fx2.on_end = func() -> void: _honeyed_ends(tid)
	_log("condition", "%s hangs on %s's every word: Charmed, and fights at their side" % [t.name(), c.name()], t)
	e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## The charm is over: the creature goes back to its own side and won't listen again for a day (a timed effect on the
## creature, kept from fight to fight).
func _honeyed_ends(tid: String) -> void:
	var e := enc()
	if e == null:
		return
	var t := e.get_c(tid)
	if t == null:
		return
	if not _has_effect(t, HONEYED_IMMUNE):
		var wary := Effect.new("Wary of Sweet Words", &"feature", HONEYED_IMMUNE)
		wary.ends = Effect.Ends.MINUTES
		wary.minutes_left = 24 * 60
		t.creature.add_effect(wary)
	e.spells.specials.undominate(tid)


## Ends Honeyed Words on `t` when `by` (the charmer or one of its allies) hurt it or forced a save on it.
func _break_honey(t: Combatant, by: Combatant, why: String) -> void:
	if by == null or by == t or t == null:
		return
	for fx: Effect in t.creature.effects.duplicate():
		if fx.source_id != HONEYED:
			continue
		var charmer := enc().get_c(fx.caster_id)
		if charmer != null and (by == charmer or by.allied_with(charmer)):
			_log("info", "The sweet words lose their hold on %s (%s)" % [t.name(), why], t)
			t.creature.remove_effect(fx)


## Solitary Weakness: no ally within 20 ft to see or hear as the turn starts: Temporary Hit Points gone, Disadvantage on
## D20 Tests until the next turn.
func _solitary_weakness(c: Combatant) -> void:
	var e := enc()
	for o in e.living():
		if o != c and o.allied_with(c) and not o.is_down() and e.distance(c, o) <= 20 \
				and (e.can_see(c, o) or not c.creature.has_condition(&"deafened")):
			return
	if c.creature.temp_hp > 0:
		c.creature.temp_hp = 0
		_log("info", "%s's borrowed vigour drains away, alone" % c.name(), c)
	var fx := _until_start(_fx(c, "Alone (Solitary Weakness)", "db_solitary_weakness"), c).with_modifier("disadvantage", {"on": "attack"}) \
		.with_modifier("disadvantage", {"on": "save:all"}).with_modifier("disadvantage", {"on": "check:all"})
	_condition(c, fx, "%s stands alone: Disadvantage on D20 Tests (Solitary Weakness)" % c.name())


# --- Cheat Fate and Delayed Price (Crooked Fortune) ---------------------------------------------------------------

## Cheat Fate: the failed save succeeds, and where a success would halve the damage none is taken (Evasion's and Circle
## of Power's flags make the half none for this save, Dexterity or magic; they go before the next D20 Test).
func _cheat_fate(c: Combatant, t: D20Test) -> void:
	var ch := _ch(c)
	ch.spend_resource("cheat_fate")
	ch.restore_resource("delayed_price", ch.resource_max("delayed_price"))
	t.success = true
	t.reroll_note = ("%s; " % t.reroll_note if t.reroll_note != "" else "") + "Cheat Fate: succeeds instead"
	var fx := _fx(c, "Cheated Fate", CHEATED).with_modifier("flag", {"value": "evasion"}).with_modifier("flag", {"value": "circle_of_power"})
	var cur := enc().current()
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = cur.id if cur != null else c.id
	c.creature.add_effect(fx)
	_log("info", "%s cheats fate: the failed save succeeds. The price comes due on the next %d saves." % [c.name(), ch.resource_max("delayed_price")], c, [t.describe()])


## Delayed Price: one of the saves after Cheat Fate. It can't have Advantage (a second d20, the lower kept, where Advantage
## cancelled the Disadvantage), a success costs a level of Exhaustion, and the last gives Cheat Fate back.
func _pay_price(c: Combatant, t: D20Test) -> void:
	var e := enc()
	var ch := _ch(c)
	if not t.advantage_sources.is_empty() and not t.disadvantage:
		var other := e.dice.d20("Delayed Price")
		if other < t.kept:
			t.set_natural(other, "Delayed Price (no Advantage)")
	ch.spend_resource("delayed_price")
	var paid := ch.resource_max("delayed_price") - ch.resource_left("delayed_price")
	if t.success:
		c.creature.add_exhaustion(1)
	_log("info", "Delayed Price: save %d of %d%s" % [paid, ch.resource_max("delayed_price"), ", and the success costs a level of Exhaustion" if t.success else ""], c, [t.describe()])
	if ch.resource_left("delayed_price") <= 0:
		ch.restore_resource("cheat_fate")
		ch.restore_resource("delayed_price", ch.resource_max("delayed_price"))
		_log("info", "%s's debt to fate is paid: Cheat Fate is back" % c.name(), c)


static func _price_owed(c: Combatant) -> bool:
	var ch := _ch(c)
	return ch != null and has(c, "delayed_price") and has(c, "cheat_fate") and ch.resource_left("cheat_fate") <= 0


# --- Hand of Death ------------------------------------------------------------------------------------------------

## Cling to Life: back up with half the Hit Point maximum; until a Humanoid dies nearby, healing is halved.
func _cling(c: Combatant, why: String) -> void:
	var e := enc()
	_ch(c).spend_resource("hand_of_death_cling_to_life")
	c.creature.dead = false
	var amount := c.creature.max_hp() / 2
	e.feature_actions._back_up(c, amount)
	if not _has_effect(c, CLING_TOLL):
		c.creature.add_effect(_fx(c, "Death's Toll (Cling to Life)", CLING_TOLL).with_modifier("flag", {"value": CLING_TOLL}))
	_hp_seen.erase(c.id)
	_log("heal", "%s refuses death %s: back up with %d Hit Points (Cling to Life). Healing is halved until a Humanoid dies nearby." % [c.name(), why, amount], c)
	e.events.append({"type": "heal", "id": c.id, "amount": amount})


func _can_cling(c: Combatant) -> bool:
	var ch := _ch(c)
	return ch != null and has(c, "hand_of_death_cling_to_life") and ch.resource_left("hand_of_death_cling_to_life") > 0 \
		and allowed(c, "hand_of_death_cling_to_life")


## Who might be healed by what comes next: creatures under Cling to Life's toll, and (for a Death Knell healer) those at 0.
func _snapshot(healer: Combatant) -> void:
	_hp_seen.clear()
	var knell := healer != null and has(healer, "hand_of_death_death_knell")
	for o in enc().combatants:
		if o.creature.dead:
			continue
		if o.creature.has_flag(CLING_TOLL) or (knell and o.creature.hp == 0):
			_hp_seen[o.id] = {"hp": o.creature.hp, "zero": knell and o.creature.hp == 0,
				"s": o.creature.death_successes, "f": o.creature.death_failures, "stable": o.creature.stable}


## After an action or spell: a creature at 0 that a Death Knell healer brought up goes back down (by any means: Lay on
## Hands, a potion), and healing on one under Cling to Life's toll is halved.
func _settle_healing() -> void:
	var e := enc()
	for id: String in _hp_seen.keys():
		var o := e.get_c(id)
		var seen := _hp_seen[id] as Dictionary
		if o == null or o.creature.dead:
			continue
		var gain := o.creature.hp - int(seen["hp"])
		if gain <= 0:
			continue
		if bool(seen["zero"]):
			o.creature.hp = 0
			o.creature.add_condition(&"unconscious", "0 Hit Points")
			o.creature.death_successes = int(seen["s"])
			o.creature.death_failures = int(seen["f"])
			o.creature.stable = bool(seen["stable"])
			_log("info", "Death Knell: %s can't be brought back from 0 Hit Points by that hand" % o.name(), o)
			e.events.append({"type": "down", "id": o.id})
		elif o.creature.has_flag(CLING_TOLL):
			o.creature.hp -= gain - gain / 2
			_log("info", "Cling to Life's toll: %s keeps only %d of the %d Hit Points" % [o.name(), gain / 2, gain], o)
	_hp_seen.clear()


# --- Critical Savior (Self-Serving Sacrifice) ---------------------------------------------------------------------

## Switch places with `t` by teleport; roll half your level in d6: you take that much Force damage, gain Heroic
## Inspiration and lose a level of Exhaustion; `t` regains that much and gains a level of Exhaustion.
func _critical_savior(p: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	p.reaction_available = false
	_ch(p).spend_resource("critical_savior")
	var from := p.cell
	var to := t.cell
	if p.size_cells == t.size_cells:
		t.cell = from
		t.clear_run()
		e.events.append({"type": "teleport", "id": t.id, "from": to, "to": from})
		e.spells._teleport(p, to, r)
		e.spells.zones.on_moved(t, to)
	var n := maxi(1, _ch(p).character_level() / 2)
	var rolled := e._roll_damage_dice("%dd6" % n, false, 0, "Critical Savior")
	var total := int(rolled["total"])
	_log("reaction", "%s trades places with %s and takes the blow's toll (Critical Savior)" % [p.name(), t.name()], p, [str(rolled["text"])])
	cf()._heal(p, t, total, "Critical Savior")
	t.creature.add_exhaustion(1)
	e.deal_damage(null, p, [{"amount": total, "type": "force"}], false, "Critical Savior", [str(rolled["text"])])
	if p.is_alive():
		_inspire(p, p, "Critical Savior")
		if p.creature.exhaustion > 0:
			p.creature.exhaustion -= 1
			_log("info", "%s sheds a level of Exhaustion (Critical Savior)" % p.name(), p)
	return r


# --- Furious Onslaught and the Red Haze (Unquenchable Fury) -------------------------------------------------------

## The fury: one more attack with each Attack action, the Proficiency Bonus off every hit. It lasts the fight unless it
## ends sooner (Incapacitated, death, a turn ended with nobody near).
func _enter_fury(c: Combatant) -> void:
	var e := enc()
	var more := e.attacks_per_action(c) + 1
	var fx := _fx(c, "Fury (Furious Onslaught)", FURY).with_modifier("flag", {"value": FURY}) \
		.with_modifier("attacks_per_action", {"value": more})
	fx.lasting_rounds(100, c.id)
	fx.ends_when_incapacitated = true
	var cid := c.id
	fx.on_end = func() -> void: _fury_over(cid)
	c.creature.add_effect(fx)
	# Entered as the Attack action is taken: its extra attack comes with this action.
	if e.current() == c and c.took_attack_action and _once_per_turn(c, "db_fury_extra"):
		c.attacks_left += 1
	_log("info", "%s's blood boils over: Furious Onslaught" % c.name(), c)
	e.events.append({"type": "ability", "id": c.id, "key": "furious_onslaught"})


func _end_fury(c: Combatant, why: String) -> void:
	if _has_effect(c, FURY):
		_log("info", "%s's fury ends (%s)" % [c.name(), why], c)
	_end_effects(c, FURY)


## The fury is over: a hero the Red Haze took is the player's again.
func _fury_over(cid: String) -> void:
	var e := enc()
	if e == null:
		return
	var c := e.get_c(cid)
	if c == null or not c.has_meta("db_red_haze"):
		return
	c.remove_meta("db_red_haze")
	c.controller = StringName(str(c.get_meta("db_haze_from", "player")))
	c.remove_meta("db_haze_from")
	c.remove_meta("db_haze_target")


## Red Haze: in a fury, a DC 15 Wisdom save as each turn starts; a failure hands the hero to its rage (the AI plays it,
## monster_turn) and there are no more saves.
func _red_haze_save(c: Combatant) -> void:
	if cf()._save(c, &"wis", 15, "Red Haze"):
		return
	c.set_meta("db_red_haze", true)
	c.set_meta("db_haze_from", str(c.controller))
	c.controller = &"ai"
	_log("condition", "The Red Haze takes %s: the nearest creature is the enemy now" % c.name(), c)
	enc().events.append({"type": "condition", "id": c.id})


## The creature the hazed hero hunts: the one it had while it's up and seen, else the nearest it sees (a tie: a die).
func _haze_target(c: Combatant) -> Combatant:
	var e := enc()
	var old := e.get_c(str(c.get_meta("db_haze_target", "")))
	if _up(old) and e.can_see(c, old):
		return old
	var near: Array[Combatant] = []
	var best := 1 << 30
	for o in e.living():
		if o == c or o.is_down() or not e.can_see(c, o):
			continue
		var d := e.distance(c, o)
		if d < best:
			best = d
			near.clear()
		if d == best:
			near.append(o)
	if near.is_empty():
		return null
	var pick := near[0] if near.size() == 1 else near[e.dice.roll_one(near.size(), "Red Haze target") - 1]
	c.set_meta("db_haze_target", pick.id)
	_log("info", "%s's rage fixes on %s" % [c.name(), pick.name()], c)
	return pick


## A hazed hero's turn: as close to its target as it can get, then the Attack action against it, every attack.
func _haze_turn(c: Combatant) -> CombatResult:
	var e := enc()
	var t := _haze_target(c)
	if t == null or not c.can_act():
		return CombatResult.new()
	var opt := e.best_melee_option(c, t)
	if opt.is_empty():
		return CombatResult.new()
	if e.distance(c, t) > (opt["profile"] as WeaponProfile).reach:
		var best := c.cell
		var best_d := e.distance(c, t)
		var best_cost := 0
		var reach_map := e.reachable_for(c)
		for cell: Vector2i in reach_map:
			var d := e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells)
			var cost := int((reach_map[cell] as Dictionary).get("cost", 999))
			if d < best_d or (d == best_d and cost < best_cost):
				best = cell
				best_d = d
				best_cost = cost
		if best != c.cell:
			return e.then(e.move(c, best), func() -> CombatResult: return _haze_strike(c, t))
	return _haze_strike(c, t)


func _haze_strike(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if not c.can_act() or e.state != Encounter.State.ACTIVE or not (c.action_available or c.attacks_left > 0):
		return CombatResult.new()
	if not _up(t):
		t = _haze_target(c)
	if t == null:
		return CombatResult.new()
	var opt := e.best_melee_option(c, t)
	if opt.is_empty() or e.distance(c, t) > (opt["profile"] as WeaponProfile).reach:
		c.movement_left = 0
		return CombatResult.new()
	var r := e.attack(c, t, str(opt["id"]))
	if not r.ok:
		return CombatResult.new()
	return e.then(r, func() -> CombatResult: return _haze_strike(c, t))


# --- Searing Silver, Iron Grit, Watery Doom -----------------------------------------------------------------------

## Whether an attack is made with a silvered weapon: an item whose data says `"silvered": true`, or whose id, name or
## stat-block action names silver (a "Silvered Shortsword", a hunter's "silvered_longsword").
static func silvered(option: Dictionary) -> bool:
	var p := option.get("profile") as WeaponProfile
	var names: Array[String] = [str(option.get("action_id", ""))]
	if p != null:
		names.append_array([p.item_id, p.base_item, p.name.to_lower()])
		if bool(Compendium.shared().item_data(p.item_id).get("silvered", false)):
			return true
	return names.any(func(n: String) -> bool: return n.contains("silver"))


## Iron Grit's damage type ("" before it's chosen).
static func iron_grit_type(c: Combatant) -> String:
	var ch := _ch(c)
	if ch == null:
		return ""
	var picks := ch.picks_for(IRON_GRIT_KEY)
	return picks[0] if not picks.is_empty() else ""


## Watery Doom: in deep water the skin rusts until a rest: half Speed, and Iron Grit's Resistance becomes Vulnerability.
func _soak(c: Combatant) -> void:
	if not has(c, "watery_doom") or _has_effect(c, RUSTED) or not enc().movement.in_running_water(c):
		return
	var fx := _fx(c, "Rusted (Watery Doom)", RUSTED).with_modifier("flag", {"value": RUSTED}).with_modifier("speed_percent", {"value": 50})
	var ty := iron_grit_type(c)
	if ty != "":
		fx.with_modifier("vulnerability", {"value": ty})
	fx.ends = Effect.Ends.SHORT_REST
	_condition(c, fx, "Water seeps into %s's iron skin: it tightens and rusts (Watery Doom)" % c.name())


# --- Hooks: turns -------------------------------------------------------------------------------------------------

func turn_start(c: Combatant) -> CombatResult:
	if c.creature.dead:
		return CombatResult.new()
	if c.creature.hp == 0 and _can_cling(c):
		_cling(c, "at 0 Hit Points")
	if not _up(c):
		return CombatResult.new()
	_unsettling_presence(c)
	if has(c, "solitary_weakness"):
		_solitary_weakness(c)
	if _has_effect(c, FURY) and has(c, "red_haze") and not c.has_meta("db_red_haze"):
		_red_haze_save(c)
	_soak(c)
	return CombatResult.new()


## The fury ends on a turn ended with no creature within 60 ft in sight.
func turn_end(c: Combatant) -> void:
	var e := enc()
	_end_effects(c, CHEATED)
	if not _has_effect(c, FURY):
		return
	for o in e.living():
		if o != c and not o.is_down() and e.distance(c, o) <= 60 and e.can_see(c, o):
			return
	_end_fury(c, "nobody left near")


func entered_cell(c: Combatant, _cell: Vector2i) -> void:
	_soak(c)


## A hazed hero's turn belongs to its rage.
func monster_turn(c: Combatant) -> Variant:
	if not c.has_meta("db_red_haze") or not c.creature is Character:
		return null
	return _haze_turn(c)


# --- Hooks: D20 Tests ---------------------------------------------------------------------------------------------

## Delayed Price's Disadvantage, Inured to Undeath, Death Knell on Death Saves, Tenuous Psyche held off, Whispered
## Secrets on a search; a save forced by the charmer's side breaks Honeyed Words.
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	var e := enc()
	var out := {}
	var adv: Array[String] = []
	var dis: Array[String] = []
	_end_effects(c, CHEATED)
	if kind == D20Test.Kind.SAVING_THROW:
		if _has_effect(c, HONEYED):
			_break_honey(c, e.current(), "made to save")
		if _price_owed(c) and not "death_save" in keys:
			dis.append("Delayed Price")
		if has(c, "inured_to_undeath"):
			var from := _save_source(c, keys)
			if from != null and from.creature.creature_type == &"undead":
				adv.append("Inured to Undeath")
		if "death_save" in keys:
			for o in e.living():
				if o != c and has(o, "hand_of_death_death_knell") and e.distance(o, c) <= 10:
					dis.append("Death Knell (%s)" % o.name())
					break
		if "save_vs:frightened" in keys and _psyche_calmed(c):
			adv.append("Calm Emotions (Tenuous Psyche held off)")
	if kind == D20Test.Kind.ABILITY_CHECK and "search" in keys:
		for h in e.hostiles_of(c):
			if h.hidden and h.creature.has_flag(CROWS):
				adv.append("Whispered Secrets")
				break
	if not adv.is_empty():
		out["advantage"] = adv
	if not dis.is_empty():
		out["disadvantage"] = dis
	return out


## The creature behind a save: the caster of the spell it's against, else whoever's turn it is.
func _save_source(c: Combatant, keys: Array[String]) -> Combatant:
	for k in keys:
		if k.begins_with("save_vs:spell:"):
			return enc().get_c(k.substr(14))
	var cur := enc().current()
	return cur if cur != c else null


## Cheat Fate on a failed save (asked, or as its rule says); the Delayed Price on the saves after it.
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var ch := _ch(c)
	if ch == null or t.kind != D20Test.Kind.SAVING_THROW or t.target <= 0 or "death_save" in keys:
		return
	if _price_owed(c):
		out.append({"kind": "delayed_price", "reactor": c, "forced": true, "use": func() -> void: _pay_price(c, t)})
		return
	if has(c, "cheat_fate") and ch.resource_left("cheat_fate") > 0 and not t.auto_failed:
		out.append({"kind": "cheat_fate", "reactor": c, "title": "Cheat Fate?", "spends_reaction": false, "sync": "explicit", "default": "ask",
			"text": func() -> String: return "%s. Succeed instead? Your next three saves pay for it." % D20Responses.line(c, t),
			"cost": "Cheat Fate (back once its price is paid)",
			"still": func() -> bool: return not t.success and ch.resource_left("cheat_fate") > 0,
			"use": func() -> void: _cheat_fate(c, t)})


# --- Hooks: attacks and damage ------------------------------------------------------------------------------------

## A silvered weapon's hit on a Searing Silver bearer: its Resistances don't count (adjust_incoming), and the hit stops
## its healing until it rests (after_hit).
func hit_dice(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary) -> Array[Dictionary]:
	if has(target, "searing_silver") and silvered(option):
		st["db_silver"] = true
		c.set_meta("db_silver_vs", target.id)
	return []


func after_hit(c: Combatant, target: Combatant, _option: Dictionary, st: Dictionary, r: CombatResult) -> void:
	if not bool(st.get("db_silver", false)):
		return
	c.remove_meta("db_silver_vs")
	if r.damage > 0 and target.is_alive() and not _has_effect(target, SILVER):
		var fx := _fx(c, "Seared by Silver", SILVER).with_modifier("flag", {"value": "cant_regain_hp"})
		fx.ends = Effect.Ends.SHORT_REST
		_condition(target, fx, "Silver sears %s: no healing until a rest (Searing Silver)" % target.name())


## Iron Grit: a Critical Hit of the chosen type is a normal hit.
func after_hit_target(st: Dictionary, _miss: Callable, _out: Array) -> void:
	var target := st["target"] as Combatant
	if not bool(st["critical"]) or not has(target, "iron_grit"):
		return
	var p := (st["option"] as Dictionary)["profile"] as WeaponProfile
	if str(p.damage_type) == iron_grit_type(target):
		st["critical"] = false
		_log("info", "Iron Grit: the blow glances off %s's iron skin, a normal hit" % target.name(), target)


## Searing Silver, Watery Doom and Tenuous Psyche on the damage's defenses; Furious Onslaught's cut.
func adjust_incoming(source: Combatant, target: Combatant, parts: Array) -> void:
	var e := enc()
	# Searing Silver: the silvered hit ignores every Resistance and Immunity.
	if source != null and str(source.get_meta("db_silver_vs", "")) == target.id and str(e.hit_context.get("attacker", "")) == source.id:
		for raw: Variant in parts:
			(raw as Dictionary)["ignore_resistance"] = true
			(raw as Dictionary)["ignore_immunity"] = true
			(raw as Dictionary)["ignore_source"] = "Silver (Searing Silver)"
	# Watery Doom: rusted, Iron Grit's Resistance is gone (its Vulnerability is on the effect).
	if target.creature.has_flag(RUSTED):
		var ty := iron_grit_type(target)
		for raw2: Variant in parts:
			if str((raw2 as Dictionary)["type"]) == ty:
				(raw2 as Dictionary)["ignore_resistance"] = true
				(raw2 as Dictionary)["ignore_source"] = "Watery Doom"
	# Tenuous Psyche held off by Calm Emotions: halving first undoes the Psychic Vulnerability (to within 1).
	if _psyche_calmed(target):
		for raw3: Variant in parts:
			var d3 := raw3 as Dictionary
			if str(d3["type"]) == "psychic" and int(d3["amount"]) > 0:
				d3["amount"] = ceili(int(d3["amount"]) / 2.0)
	# Furious Onslaught: the Proficiency Bonus off the damage.
	if _has_effect(target, FURY):
		var pb := target.creature.proficiency_bonus()
		var cut := pb
		for raw4: Variant in parts:
			var d4 := raw4 as Dictionary
			var off := mini(cut, maxi(0, int(d4["amount"])))
			d4["amount"] = int(d4["amount"]) - off
			cut -= off
		if cut < pb:
			_log("info", "%s's fury shrugs off %d damage" % [target.name(), pb - cut], target)


static func _psyche_calmed(c: Combatant) -> bool:
	return has(c, "tenuous_psyche") and _has_effect(c, "calm_emotions")


## Honeyed Words breaks when the charmer's side hurts the charmed; Cling to Life at death from damage taken at 0 (death
## outright is cheats_death's); Critical Savior's Reaction
## queued for a Critical Hit or a drop to 0.
func after_damage(source: Combatant, target: Combatant, amount: int, _parts: Array = [], dr: DamageResult = null) -> void:
	var e := enc()
	if amount > 0:
		_break_honey(target, source, "hurt")
	if target.creature.dead and _can_cling(target):
		_cling(target, "at death's door")
	if dr == null or target.creature.dead or not (dr.critical or dr.dropped_to_zero):
		return
	for p in e.living():
		var ch := _ch(p)
		if p == target or ch == null or not has(p, "critical_savior") or ch.resource_left("critical_savior") <= 0 or p.is_down() \
				or p.hostile_to(target) or e.distance(p, target) > 120 or not e.spells.can_react(p):
			continue
		var q := {"kind": "gm_db_critical_savior", "reactor": p.id, "trigger": target.id}
		var rule := str(p.reaction_rules.get("critical_savior", "ask"))
		if rule in ["auto", "never"]:
			q["plan"] = rule
		e.reaction_queue.append(q)


## Cling to Life against death outright (Massive Damage, a slaying effect): back up with half the maximum.
func cheats_death(target: Combatant) -> bool:
	if not _can_cling(target):
		return false
	_cling(target, "as death comes for it")
	return true


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var e := enc()
	var t := e.get_c(str(q["trigger"]))
	return str(q["kind"]) == "gm_db_critical_savior" and t != null and t.is_alive() and e.spells.can_react(reactor) \
		and _ch(reactor) != null and _ch(reactor).resource_left("critical_savior") > 0 and e.distance(reactor, t) <= 120


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	if str(q["kind"]) == "gm_db_critical_savior":
		return _critical_savior(reactor, trigger)
	return CombatResult.new()


func queued_text(kind: String) -> Array:
	if kind == "gm_db_critical_savior":
		return ["Reaction: Critical Savior?", "%s is struck hard. %s can trade places with them by magic, take the toll in Force damage and heal them as much?",
			"Reaction and Critical Savior (once a Short Rest)"]
	return super(kind)


## A death: Cling to Life back after a Humanoid dies within 30 ft; Furious Onslaught back after its bearer kills one; the
## companion leaves with its caller; the fury ends.
func on_death(source: Combatant, dead: Combatant) -> void:
	var e := enc()
	if dead.creature.creature_type == &"humanoid":
		for p in e.living():
			var ch := _ch(p)
			if p == dead or ch == null or not has(p, "hand_of_death_cling_to_life") or e.distance(p, dead) > 30:
				continue
			if ch.resource_left("hand_of_death_cling_to_life") <= 0 or _has_effect(p, CLING_TOLL):
				ch.restore_resource("hand_of_death_cling_to_life")
				_end_effects(p, CLING_TOLL)
				_log("info", "%s feels %s's death settle the debt: Cling to Life is back" % [p.name(), dead.name()], p)
		if source != null and source != dead and has(source, "furious_onslaught") and _ch(source) != null \
				and _ch(source).resource_left("furious_onslaught") <= 0:
			_ch(source).restore_resource("furious_onslaught")
			_log("info", "%s's kill feeds the fury: Furious Onslaught is back" % source.name(), source)
	var mine := _companion_of(dead)
	if mine != null:
		e.spells.summons._dismiss(mine.id)
	_end_fury(dead, "death")


# --- Hooks: actions and spells ------------------------------------------------------------------------------------

func before_action(c: Combatant) -> void:
	_snapshot(c)


func after_action(_c: Combatant, _action: Dictionary, _targets: Array = []) -> void:
	_settle_healing()


## Beast Skin's free Polymorph takes only its bearer; a Death Knell healer's spell can't lift a creature from 0.
func before_resolve(ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var tgt := ctx.get("targets", []) as Array
	if str(s.get("id", "")) == "polymorph" and not bool(ctx.get("spent_slot", true)) and has(c, "beast_skin") \
			and not (tgt.size() == 1 and tgt[0] == c):
		tgt.clear()
		tgt.append(c)
		_log("info", "Beast Skin's free Polymorph can only change %s" % c.name(), c)
	_snapshot(c)
	if has(c, "hand_of_death_death_knell") and s.has("heal"):
		for raw: Variant in tgt:
			var t := raw as Combatant
			if t.creature.hp == 0 and not t.creature.dead:
				t.creature.add_effect(_fx(c, "Death Knell", KNELL_BLOCK).with_modifier("flag", {"value": "cant_regain_hp"}))
				_log("info", "Death Knell: %s's magic can't lift %s from 0 Hit Points" % [c.name(), t.name()], t)


func after_cast(_c: Combatant, _s: Dictionary, _slot: int, _free: bool = false, _ctx: Dictionary = {}) -> void:
	for o in enc().combatants:
		_end_effects(o, KNELL_BLOCK)
	_settle_healing()


## Pyre's Price comes with Primeval Strength; Whispered Secrets with Murderous Flight.
func effect_added(cr: Creature, fx: Effect) -> void:
	if enc() == null:
		return
	var c := enc().get_c(cr.id)
	if c == null:
		return
	if fx.source_id == "primeval_strength" and has(c, "pyres_price") and not _has_effect(c, PYRE):
		var bark := _fx(c, "Bark Skin (Pyre's Price)", PYRE).with_modifier("vulnerability", {"value": "fire"})
		bark.ends = Effect.Ends.LONG_REST
		cr.add_effect(bark)
		_log("info", "%s's skin turns to bark: Vulnerable to Fire until a Long Rest (Pyre's Price)" % c.name(), c)
	elif fx.source_id == "murderous_flight" and has(c, "whispered_secrets") and not _has_effect(c, CROWS):
		var birds := _fx(c, "Whispering Crows", CROWS).with_modifier("flag", {"value": CROWS}) \
			.with_modifier("disadvantage", {"on": "check:stealth"})
		birds.ends = Effect.Ends.SHORT_REST
		cr.add_effect(birds)
		_log("info", "Shadow-crows whirl about %s and whisper its secrets (Whispered Secrets)" % c.name(), c)
