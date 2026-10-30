class_name CmFeats
extends CmPart
## The Crooked Moon's code for the book's origin and general feats (chapter 5): the parts of them data can't say. CrookedFeatures forwards
## every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start "ft_".
##
## In a fight: Grave Keeper's Divine Channel (Turn Undead for anyone, or one more Channel Divinity use for a class that
## has it), Hunter of Hunters' Dead Aim and Studied Quarry, Fate Gambler's Bet Big and Win Big, Dread Speech's
## Eldritch Word, Ghostlight Medium's Ghostly Touch and Spirit Sense, Death Defier's Cling to Life and Enduring
## Vitality, and Swift Witchcraft's Swift Invocation. Altered's Night Vision is data (a darkvision `extend`); the rest
## of those feats is data, or works outside fights (Last Rites, Twisted Hex, Fool's Mask, Unremarkable, Bottled Life).

const PREFIX := "ft_"

## Grave Keeper's own Channel Divinity use (the feat's resource).
const GRAVE_USE := "grave_keeper_channel"

## Saves and checks Fate Gambler's Bet Big waits on: {test, who, foe, kind ("save" or "check")}. The roll's offers
## (Legendary Resistance, Heroic Inspiration...) can still change it, so the reward comes once the result is final.
var _bets: Array[Dictionary] = []


func prefix() -> String:
	return PREFIX


## The pick of a feat's choice whose key ends in `suffix` (Dread Speech's spellcasting ability), or `fallback`.
static func _pick(c: Combatant, suffix: String, fallback: String) -> String:
	var ch := _ch(c)
	if ch == null:
		return fallback
	for cd in ch.choice_defs:
		if cd.key.ends_with(suffix) and not cd.picks.is_empty():
			return cd.picks[0]
	return fallback


## A creature that counts for Bet Big: it has a Challenge Rating above 0 (heroes and summons have none).
static func _rated(t: Combatant) -> bool:
	return t != null and t.creature is Monster and (t.creature as Monster).cr > 0.0


## Whether `t` has the Incorporeal Movement trait (a stat block's trait or a flag an effect gave it).
func _incorporeal(t: Combatant) -> bool:
	return t.creature.has_flag("incorporeal_movement") or (t.creature is Monster and enc().monster_actions.has_trait(t, "incorporeal_movement"))


# --- The hotbar ---------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	if has(c, "divine_channel") and not has(c, "channel_divinity"):
		var tw := _first(aw, "" if ch.resource_left(_grave_pool(c)) > 0 else "No Channel Divinity left")
		if tw == "" and c.magic_action_used:
			tw = "Only one Magic action this turn (Action Surge's action can't be Magic)"
		if tw == "" and _undead_near(c).is_empty():
			tw = "No Undead within 30 ft"
		out.append(_act("turn_undead", "Turn Undead", "Wis DC %d · 30 ft" % dc_of(c, &"wis"), "action", tw, "none",
			"Magic action and a Channel Divinity use (Grave Keeper): each Undead enemy within 30 ft makes a Wisdom save or is Frightened and Incapacitated for 1 minute, fleeing you; damage ends it."))
	if has(c, "dead_aim"):
		out.append(_act("dead_aim", "Dead Aim", "ignore Resistance", "bonus", bw, "creature",
			"Bonus Action: study a creature you can see. The next damage you deal it before your next turn ignores its Resistances."))
	if has(c, "win_big"):
		out.append(_act("win_big", "Win Big", "+%d Temp HP" % ch.character_level(), "bonus",
			_first(bw, "" if ch.heroic_inspiration else "No Heroic Inspiration"), "none",
			"Bonus Action: spend your Heroic Inspiration for Temporary Hit Points equal to your level (%d)." % ch.character_level()))
	if has(c, "eldritch_word"):
		var safe := ch.resource_left("eldritch_word") > 0
		var dc := _word_dc(c)
		out.append(_act("eldritch_word", "Eldritch Word" if safe else "Eldritch Word (1d6 HP)",
			"Wis DC %d · 60 ft%s" % [dc, "" if safe else " · costs you 1d6 HP"], "bonus", bw, "creature",
			"Bonus Action: a creature within 60 ft makes a Wisdom save (DC %d) or is Frightened until your next turn. %s" % [dc,
			"One safe use per Short or Long Rest." if safe else "No safe use left: you take 1d6 Necrotic damage that nothing can reduce."], 60))
	if has(c, "spirit_sense"):
		out.append(_act("spirit_sense", "Spirit Sense", "Undead · 60 ft", "bonus", _first(bw, _res_why(c, "spirit_sense")), "none",
			"Bonus Action: sense every Undead within 60 ft and any creature on the Ethereal Plane there; hidden ones are found. Spent only when something is sensed."))


func perform(c: Combatant, id: String, t: Combatant, _cell: Vector2i, _point: Vector2) -> CombatResult:
	if _ch(c) == null:
		return CombatResult.fail("Not available")
	match id.trim_prefix(PREFIX):
		"turn_undead":
			return _turn_undead(c)
		"dead_aim":
			return _dead_aim(c, t)
		"win_big":
			return _win_big(c)
		"eldritch_word":
			return _eldritch_word(c, t)
		"spirit_sense":
			return _spirit_sense(c)
	return CombatResult.fail("Not available")


# --- Grave Keeper: Divine Channel ---------------------------------------------------------------------------------

## Where Divine Channel's use lives: added to the Cleric's or the Paladin's Channel Divinity when the hero has one,
## else the feat's own use.
func _grave_pool(c: Combatant) -> String:
	var ch := _ch(c)
	if has(c, "channel_divinity"):
		return "channel_divinity"
	if ch != null and ch.resource_max("paladin_channel_divinity") > 0:
		return "paladin_channel_divinity"
	return GRAVE_USE


## Divine Channel's added use: once the class's Channel Divinity runs dry, the feat's use moves into it (both come back
## on rests as before, so the total is the class's uses plus one).
func _pool_grave_use(c: Combatant) -> void:
	var ch := _ch(c)
	if ch == null or not has(c, "divine_channel"):
		return
	var pool := _grave_pool(c)
	if pool == GRAVE_USE or ch.resource_left(pool) > 0 or ch.resource_left(GRAVE_USE) <= 0:
		return
	ch.spend_resource(GRAVE_USE)
	ch.restore_resource(pool)
	_log("info", "%s draws on one more Channel Divinity (Grave Keeper)" % c.name(), c)


func _pool_all() -> void:
	for o in enc().combatants:
		_pool_grave_use(o)


func _undead_near(c: Combatant) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for h in e.hostiles_of(c):
		if str(h.creature.creature_type) == "undead" and not h.is_down() and e.distance(c, h) <= 30:
			out.append(h)
	return out


## Turn Undead through Divine Channel: the Cleric's effect, with the feat's DC (8 + Wisdom modifier + Proficiency
## Bonus). Each Undead enemy within 30 ft makes a Wisdom save or is Frightened and Incapacitated for 1 minute, fleeing;
## damage ends it.
func _turn_undead(c: Combatant) -> CombatResult:
	var e := enc()
	var targets := _undead_near(c)
	if targets.is_empty():
		return CombatResult.fail("No Undead enemies within 30 ft")
	if not _ch(c).spend_resource(_grave_pool(c)):
		return CombatResult.fail("No Channel Divinity left")
	e.spend_action(c)
	c.magic_action_used = true
	if c.hidden:
		e.reveal(c, "used Channel Divinity")
	var dc := dc_of(c, &"wis")
	var r := CombatResult.new()
	r.lines.append(e.log.add("spell", "%s calls on the rites of the dead: Turn Undead (DC %d)" % [c.name(), dc], c.id))
	e.events.append({"type": "spell", "caster": c.id, "spell": "turn_undead", "cells": [],
		"targets": targets.map(func(x: Combatant) -> String: return x.id)})
	for t in targets:
		var s := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Turn Undead (%s)" % t.name(),
			["save_vs:turn_undead", "save_vs:frightened", "save_vs:incapacitated"])
		if s.success:
			r.lines.append(e.log.add("info", "%s resists the turning" % t.name(), t.id, [s.describe()]))
			continue
		# The engine's own turning ("turn_undead"): the creature flees, and the effect ends as the Cleric's does.
		var fx := Effect.new("Turned", &"feature", "turn_undead").with_condition(&"frightened").with_condition(&"incapacitated")
		fx.caster_id = c.id
		fx.lasting_rounds(10, c.id)
		fx.ends_on_damage = true
		fx.stack_key = "turn_undead:%s" % t.id
		if t.creature.add_effect(fx):
			r.lines.append(e.log.add("condition", "%s is Turned: Frightened and Incapacitated, fleeing %s" % [t.name(), c.name()], t.id, [s.describe()]))
			e.events.append({"type": "condition", "id": t.id})
	return r


# --- Hunter of Hunters --------------------------------------------------------------------------------------------

## Dead Aim: a Bonus Action marks a creature; the next damage `c` deals it before `c`'s next turn ignores Resistance.
func _dead_aim(c: Combatant, t: Combatant) -> CombatResult:
	if t == null or t == c or not enc().can_see(c, t):
		return CombatResult.fail("Choose a creature you can see")
	c.bonus_available = false
	c.set_meta("ft_dead_aim", t.id)
	_log("info", "%s studies %s for a weak spot (Dead Aim)" % [c.name(), t.name()], c)
	return CombatResult.new()


## Studied Quarry: Advantage on checks to recall what a creature is (the Study action).
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	if kind == D20Test.Kind.ABILITY_CHECK and "study" in keys and has(c, "studied_quarry"):
		return {"advantage": ["Studied Quarry"]}
	return {}


## Dead Aim's marked creature and Ghostly Touch's incorporeal ones: the damage ignores their Resistances.
func adjust_incoming(source: Combatant, target: Combatant, ps: Array) -> void:
	if source == null or target == null or source == target:
		return
	var why := ""
	if str(source.get_meta("ft_dead_aim", "")) == target.id:
		source.remove_meta("ft_dead_aim")   # the next time it deals that creature damage, resisted or not
		why = "Dead Aim"
	elif has(source, "ghostly_touch") and _incorporeal(target):
		why = "Ghostly Touch"
	if why == "":
		return
	for p: Variant in ps:
		var d := p as Dictionary
		d["ignore_resistance"] = true
		d["ignore_source"] = why


# --- Fate Gambler -------------------------------------------------------------------------------------------------

## Win Big: spend Heroic Inspiration for Temporary Hit Points equal to the hero's level.
func _win_big(c: Combatant) -> CombatResult:
	var ch := _ch(c)
	if not ch.heroic_inspiration:
		return CombatResult.fail("No Heroic Inspiration")
	ch.heroic_inspiration = false
	c.bonus_available = false
	_log("info", "%s cashes in Heroic Inspiration (Win Big)" % c.name(), c)
	enc().class_features._temp(c, ch.character_level(), "Win Big")
	return CombatResult.new()


## Bet Big: Heroic Inspiration when `c`, lacking it, beats a creature with a Challenge Rating; at most once per turn
## (the designer's limit), unless its owner turned it Off.
func _bet_big(c: Combatant, why: String) -> void:
	var ch := _ch(c)
	if ch == null or not has(c, "bet_big") or not allowed(c, "bet_big") or ch.heroic_inspiration or ch.dead:
		return
	if not _once_per_turn(c, "ft_bet_big"):
		return
	_inspire(c, c, "Bet Big: %s" % why)


## Who made `roller` roll the save: a spell's caster (its keys name it), else whoever's turn it is.
func _forcer(roller: Combatant, keys: Array[String]) -> Combatant:
	var e := enc()
	for k in keys:
		if k.begins_with("save_vs:spell:"):
			return e.get_c(k.substr(14))
	var cur := e.current()
	return cur if cur != roller else null


## The creature a check of `c`'s is made against: the one grappling it, or the maker of what holds it (Web...).
func _opponent(c: Combatant) -> Combatant:
	var e := enc()
	if e.grapples.has(c.id):
		return e.get_c(str(e.grapples[c.id]))
	for fx: Effect in c.creature.effects:
		if not fx.escape.is_empty() and fx.caster_id != "":
			return e.get_c(fx.caster_id)
	return null


## Bets whose roll is settled: a save the bettor forced that failed, or the bettor's check that succeeded.
func _settle_bets() -> void:
	if _bets.is_empty():
		return
	var open: Array[Dictionary] = []
	var due := _bets
	_bets = open
	for b in due:
		var t := b["test"] as D20Test
		if t.awaiting:
			open.append(b)
			continue
		var who := b["who"] as Combatant
		if str(b["kind"]) == "save" and not t.success:
			_bet_big(who, "%s failed a save" % (b["foe"] as Combatant).name())
		elif str(b["kind"]) == "check" and t.success:
			_bet_big(who, "a check against %s" % (b["foe"] as Combatant).name())


## After a D20 Test: Cling to Life on Death Saving Throws, and the rolls Bet Big waits on.
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	_settle_bets()
	if t.kind == D20Test.Kind.SAVING_THROW and "death_save" in keys:
		if has(c, "cling_to_life"):
			var bonus := maxi(1, c.creature.ability_mod(&"con"))
			out.append({"kind": "ft_cling_to_life", "reactor": c, "forced": true,
				"use": func() -> void: t.add_bonus(bonus, "Cling to Life")})
		return
	if t.target <= 0:
		return
	if t.kind == D20Test.Kind.SAVING_THROW and _rated(c):
		var by := _forcer(c, keys)
		if by != null and has(by, "bet_big"):
			_bets.append({"test": t, "who": by, "foe": c, "kind": "save"})
	elif t.kind == D20Test.Kind.ABILITY_CHECK and has(c, "bet_big"):
		var foe := _opponent(c)
		if _rated(foe):
			_bets.append({"test": t, "who": c, "foe": foe, "kind": "check"})


func on_drop(by: Combatant, target: Combatant) -> void:
	_settle_bets()
	if by != null and by != target and _rated(target):
		_bet_big(by, "dropped %s" % target.name())


func after_damage(_source: Combatant, _target: Combatant, _amount: int, _ps: Array = [], _dr: DamageResult = null) -> void:
	_settle_bets()


func effect_added(_cr: Creature, _fx: Effect) -> void:
	_settle_bets()


func after_cast(c: Combatant, s: Dictionary, _slot: int, _free: bool = false, _ctx: Dictionary = {}) -> void:
	_swift_spent(c, s)
	_settle_bets()


func after_hit(_c: Combatant, _target: Combatant, _option: Dictionary, _st: Dictionary, _r: CombatResult) -> void:
	_settle_bets()


func after_action(_c: Combatant, _action: Dictionary, _targets: Array = []) -> void:
	_settle_bets()
	_pool_all()


func fight_started() -> void:
	_pool_all()


# --- Dread Speech: Eldritch Word ----------------------------------------------------------------------------------

## 8 + Proficiency Bonus + the ability picked for the feat.
func _word_dc(c: Combatant) -> int:
	return dc_of(c, StringName(_pick(c, "eldritch_word.spellcasting_ability", "cha")))


## Eldritch Word: a creature within 60 ft makes a Wisdom save or is Frightened until the start of `c`'s next turn. Once
## per Short or Long Rest it is safe; past that it costs 1d6 Necrotic damage that nothing reduces.
func _eldritch_word(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or t == c or not t.is_alive():
		return CombatResult.fail("Choose a creature within 60 ft")
	var safe := _ch(c).spend_resource("eldritch_word")
	c.bonus_available = false
	if c.hidden:
		e.reveal(c, "spoke an Eldritch Word")
	var dc := _word_dc(c)
	var s := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Eldritch Word (%s)" % t.name(), ["save_vs:frightened"])
	if s.success:
		_log("info", "%s speaks a forbidden word; %s shrugs it off" % [c.name(), t.name()], c, [s.describe()])
	else:
		var fx := Effect.new("Eldritch Word", &"feature", "ft_eldritch_word").with_condition(&"frightened")
		fx.caster_id = c.id
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = c.id
		if t.creature.add_effect(fx):
			_log("condition", "%s speaks a forbidden word: %s is Frightened" % [c.name(), t.name()], c, [s.describe()])
			e.events.append({"type": "condition", "id": t.id})
		else:
			_log("info", "%s speaks a forbidden word, but %s can't be Frightened" % [c.name(), t.name()], c, [s.describe()])
	if not safe:
		var n := e.dice.roll_one(6, "Eldritch Word")
		e.deal_damage(c, c, [{"amount": n, "type": "necrotic", "ignore_resistance": true, "ignore_source": "Eldritch Word"}],
			false, "Eldritch Word", ["The word's price: 1d6 = %d" % n])
	return CombatResult.new()


# --- Ghostlight Medium: Spirit Sense ------------------------------------------------------------------------------

## Spirit Sense in a fight: every Undead within 60 ft, and any creature on the Ethereal Plane there, is sensed (where it
## is); hidden ones are found. The use is spent only when it senses something.
func _spirit_sense(c: Combatant) -> CombatResult:
	var e := enc()
	c.bonus_available = false
	var found: Array[String] = []
	for o in e.living():
		if o == c or e.distance(c, o) > 60:
			continue
		if str(o.creature.creature_type) != "undead" and not o.creature.has_flag("ethereal"):
			continue
		found.append("%s, %d ft" % [o.name(), e.distance(c, o)])
		if o.hidden:
			e.reveal(o, "%s's Spirit Sense" % c.name())
	if found.is_empty():
		_log("info", "%s reaches out for spirits and senses none" % c.name(), c)
		return CombatResult.new()
	_ch(c).spend_resource("spirit_sense")
	_log("info", "%s senses the dead nearby (Spirit Sense)" % c.name(), c, found)
	return CombatResult.new()


# --- Death Defier -------------------------------------------------------------------------------------------------

## Enduring Vitality: something that would kill `t` outright (Massive Damage) leaves it at Hit Points equal to its
## level instead, once per Long Rest.
func cheats_death(t: Combatant) -> bool:
	var ch := _ch(t)
	if ch == null or not has(t, "enduring_vitality") or not allowed(t, "enduring_vitality"):
		return false
	if not ch.spend_resource("enduring_vitality"):
		return false
	ch.dead = false
	ch.hp = mini(ch.character_level(), ch.max_hp())
	ch.remove_condition(&"unconscious", "0 Hit Points")
	ch.death_failures = 0
	ch.death_successes = 0
	ch.stable = false
	_log("heal", "%s refuses death: Enduring Vitality (%d Hit Points)" % [t.name(), ch.hp], t)
	enc().events.append({"type": "heal", "id": t.id, "amount": ch.hp})
	return true


# --- Swift Witchcraft: Swift Invocation ---------------------------------------------------------------------------

## Whether `s` is a spell Swift Invocation speeds up: a casting time of exactly 1 minute.
static func _one_minute(s: Dictionary) -> bool:
	var ct := s.get("casting_time", {}) as Dictionary
	return str(ct.get("unit", "")) == "minute" and int(ct.get("amount", 1)) == 1


## Swift Invocation: while its use is left, a 1-minute spell is cast in a fight as a Magic action (the spell menu
## offers it as one).
func casting_unit(c: Combatant, s: Dictionary, unit: String) -> String:
	if unit != "minute" or not _one_minute(s) or not has(c, "swift_invocation"):
		return unit
	var ch := _ch(c)
	return "action" if ch != null and ch.resource_left("swift_invocation") > 0 else unit


## A 1-minute spell cast mid-fight spends Swift Invocation's use (once per Long Rest).
func _swift_spent(c: Combatant, s: Dictionary) -> void:
	if enc().peaceful or not _one_minute(s) or not has(c, "swift_invocation"):
		return
	if _ch(c).spend_resource("swift_invocation"):
		_log("info", "%s weaves %s in moments (Swift Invocation)" % [c.name(), s.get("name", "")], c)


# --- Turns --------------------------------------------------------------------------------------------------------

func turn_start(c: Combatant) -> CombatResult:
	_settle_bets()
	# Dead Aim lasts until the start of its user's next turn.
	if c.has_meta("ft_dead_aim"):
		c.remove_meta("ft_dead_aim")
	return CombatResult.new()


func turn_end(_c: Combatant) -> void:
	_settle_bets()
	_pool_all()
