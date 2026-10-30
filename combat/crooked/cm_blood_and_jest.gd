class_name CmBloodAndJest
extends CmPart
## The Crooked Moon's code for three of the book's subclasses (chapter 3): Crimson Sorcery, Great Fool Patron and Circle of Wicker: the parts of them data can't say.
## CrookedFeatures forwards every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start
## "bj_".
##
## Crimson Sorcery: the Blood Well (1d8 more for one target's damage or healing, armed on the hotbar or spent on its own
## to lift a downed ally; back when the sorcerer deals 10+ Necrotic at once) and the Pool of Blood (a shape through
## ShapeChange: the sorcerer's own numbers, slow, slippery and harmless). Great Fool Patron: Killing Joke (Vicious
## Mockery as a Reaction), Jester's Japes (four curses, picked per use) and Mocking Banter. Circle of Wicker: the
## Bewitched Effigy (a Small object on the guest side with no turns of its own, like Bigby's Hand, and a Sacrifice,
## Soothe or Ward aura with a 30-ft glow), Wicker Rising's stronger auras, Wicker Tokens (the party carries them; touch
## spells reach their carriers through `spell_reach`) and the Soulbound Poppet.

const PREFIX := "bj_"

const DAMAGE_TYPES: Array[String] = ["acid", "bludgeoning", "cold", "fire", "force", "lightning", "necrotic", "piercing",
	"poison", "psychic", "radiant", "slashing", "thunder"]
## What Soothe can lift from a creature at Wicker Rising (for 5 of the effigy's Hit Points).
const SOOTHE_CONDITIONS: Array[StringName] = [&"charmed", &"frightened", &"paralyzed", &"poisoned", &"stunned"]
## Jester's Japes' curses: id -> [name, short words for the hotbar].
const JAPES := {
	"flower_spurt": ["Flower Spurt", "Blinded"],
	"clown_shoes": ["Clown Shoes", "half Speed, Dex Disadvantage"],
	"honk_honk": ["Honk Honk", "can't be Invisible"],
	"jolly_arms": ["Jolly Arms", "half weapon damage"],
}
const AURAS := {"sacrifice": "Sacrifice", "soothe": "Soothe", "ward": "Ward"}


func prefix() -> String:
	return PREFIX


func cf() -> ClassFeatures:
	return enc().class_features


## The player's rule for a benefit with a policy (Ask, Automatic, Off), else the data's own default.
func _mode(c: Combatant, id: String) -> String:
	if c.reaction_rules.has(id):
		return str(c.reaction_rules[id])
	var ch := _ch(c)
	if ch != null:
		for f in ch.features:
			if str(f.get("id", "")) == id:
				return str(f.get("policy", "auto"))
	return "auto"


## A queued Reaction's plan from its rule: "auto" fires it, "" asks (Off never queues it).
static func _plan(mode: String) -> String:
	return "auto" if mode == "auto" else ""


func _queued(reactor: Combatant, kind: String) -> bool:
	return enc().reaction_queue.any(func(q: Dictionary) -> bool: return str(q.get("kind", "")) == kind and str(q.get("reactor", "")) == reactor.id)


func _roll(expr: String, label: String) -> Dictionary:
	return enc()._roll_damage_dice(expr, false, 0, label)


# --- The hotbar ---------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	if has(c, "pool_of_blood") and not e.shapes.is_shaped(c):
		out.append(_act("pool_of_blood", "Pool of Blood", "Blood Well · 1 hour", "bonus", _first(bw, _res_why(c, "blood_well")), "none",
			"Bonus Action, your Blood Well: melt into a pool of blood. Speed 10 ft (climb and swim too), Resistance to Bludgeoning, Piercing and Slashing, no Prone, Advantage on Strength, Dexterity and Constitution saves, and you can slip into others' spaces; you can't attack, cast or speak. Ends at 0 Hit Points or when you leave the shape."))
	if has(c, "jesters_japes"):
		var jw := _first(aw, _res_why(c, "jesters_japes"))
		for k: String in JAPES:
			out.append(_act("japes:" + k, "Jester's Japes: %s" % JAPES[k][0], str(JAPES[k][1]), "action", jw, "enemy",
				"Magic action: a creature you see within 60 ft makes a Charisma save (DC %d) or is cursed for 1 minute: %s. It repeats the save at the end of each of its turns. Once per Short Rest." % [cf()._spell_dc(c, "warlock"), JAPES[k][1]], 60))
	if has(c, "bewitched_effigy"):
		_effigy_entries(c, out, bw)
	if has(c, "soulbound_poppet"):
		var pp := _act("poppet", "Soulbound Poppet", "doll · 60 ft", "action", _first(aw, _res_why(c, "wild_shape")), "enemy",
			"Magic action, a Wild Shape use: a wicker doll of a creature you see within 60 ft, for 1 minute. It has Disadvantage on attacks against whoever carries the doll, and the carrier's first damage to it each turn adds 2d10 Necrotic. You can hand the doll to an ally within 5 ft.", 60)
		var carriers: Array = [{"value": "", "label": "Keep it"}]
		for a in e.allies_of(c):
			if a.creature is Character and not a.is_down() and e.distance(c, a) <= 5:
				carriers.append({"value": a.id, "label": "Give it to %s" % a.name()})
		pp["choices"] = carriers
		pp["choice_label"] = "Carrier"
		out.append(pp)


func _effigy_entries(c: Combatant, out: Array[Dictionary], bw: String) -> void:
	var ew := _first(bw, _res_why(c, "wild_shape"))
	var lvl := ClassFeatures.level_of(c, "druid")
	var rising := has(c, "wicker_rising")
	var wis := c.creature.ability_mod(&"wis")
	var helps := {
		"sacrifice": "your Reaction deals %s + %d Fire to a hostile creature in it that takes damage" % ["2d8" if rising else "1d8", wis],
		"soothe": "it heals one creature in it %s now and as a Bonus Action later, %d times in all%s" % ["1d8" if rising else "1d6", _soothe_max(c),
			" (5 of its Hit Points can lift Charmed, Frightened, Paralyzed, Poisoned or Stunned)" if rising else ""],
		"ward": "you and allies in it have +1 AC%s" % (" and Resistance to the damage type you pick" if rising else ""),
	}
	for k: String in AURAS:
		var en := _act("effigy:" + k, "Bewitched Effigy: %s" % AURAS[k], "AC 15 · %d HP · 30 ft" % (5 * lvl), "bonus", ew, "place",
			"Bonus Action, a Wild Shape use: a Small wicker effigy (AC 15, %d Hit Points, Fire hurts it double) in a square you see within 30 ft for 1 minute, glowing dimly 30 ft round; %s. Foes can smash it." % [5 * lvl, helps[k]], 30)
		if k == "ward" and rising:
			var types: Array = [{"value": "", "label": "What the foes deal most"}]
			for ty in DAMAGE_TYPES:
				if ty != "force":
					types.append({"value": ty, "label": ty.capitalize()})
			en["choices"] = types
			en["choice_label"] = "Resistance"
		out.append(en)
	var eff := _effigy_of(c)
	if eff != null and str(eff.get_meta("bj_effigy")) == "soothe":
		var left := int(eff.get_meta("bj_soothe_left", 0))
		out.append(_act("soothe", "Effigy: Soothe", "%s · %d left" % ["1d8" if rising else "1d6", left], "bonus",
			_first(bw, "" if left > 0 else "The effigy has no healing left"), "creature",
			"Bonus Action: a creature you see within 30 ft of your effigy regains %s Hit Points." % ("1d8" if rising else "1d6")))


func perform(c: Combatant, id: String, t: Combatant, cell: Vector2i, _point: Vector2) -> CombatResult:
	var key := id.trim_prefix(PREFIX)
	var head := key.get_slice(":", 0)
	var arg := key.get_slice(":", 1) if key.contains(":") else ""
	match head:
		"pool_of_blood":
			return _pool_of_blood(c)
		"end_pool":
			if not enc().shapes.is_shaped(c):
				return CombatResult.fail("Not in the Pool of Blood")
			enc().shapes.revert(c, "it rose from the blood")
			return CombatResult.new()
		"japes":
			return _japes(c, t, arg)
		"effigy":
			return _make_effigy(c, arg, cell, choice_in)
		"soothe":
			var eff := _effigy_of(c)
			if eff == null or t == null or not _in_aura(eff, t) or not enc().can_see(c, t):
				return CombatResult.fail("Choose a creature you see within 30 ft of your effigy")
			if int(eff.get_meta("bj_soothe_left", 0)) <= 0:
				return CombatResult.fail("The effigy has no healing left")
			c.bonus_available = false
			_soothe(c, eff, t)
			return CombatResult.new()
		"poppet":
			return _poppet(c, t, choice_in)
	return CombatResult.fail("Not available")


# --- Crimson Sorcery: the Blood Well -----------------------------------------------------------------------------

func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if has(c, "blood_well") and _mode(c, "blood_well") != "never":
		out.append({"id": "bj_blood_well", "label": "Blood Well", "sub": "+1d8 to your next damage or healing, one target",
			"why": _res_why(c, "blood_well")})
	return out


## Damage on its way to one target: Jolly Arms halves a cursed creature's weapon blows, an armed Blood Well adds 1d8 of
## the blow's own type, and a Soulbound Poppet's carrier adds 2d10 Necrotic the first time each turn.
func adjust_incoming(source: Combatant, target: Combatant, parts: Array) -> void:
	if source == null or parts.is_empty():
		return
	var e := enc()
	if source.creature.has_flag("bj_jolly_arms") and source != target and _weapon_blow(source, parts):
		for p: Variant in parts:
			(p as Dictionary)["amount"] = int((p as Dictionary)["amount"]) / 2
		_log("info", "%s's floppy weapon only does half (Jolly Arms)" % source.name(), source)
	if source != target and "bj_blood_well" in source.armed and _well_ready(source):
		source.armed.erase("bj_blood_well")
		var rolled := _roll("1d8", "Blood Well")
		(_ch(source) as Character).spend_resource("blood_well")
		parts.append({"amount": int(rolled["total"]), "type": str((parts[0] as Dictionary).get("type", "necrotic"))})
		_log("damage", "%s pours the Blood Well into the blow: +%d damage to %s" % [source.name(), int(rolled["total"]), target.name()], source, [str(rolled["text"])])
	for d: Dictionary in _poppets_on(source):
		if str(d["target"]) == target.id and _once_per_turn(source, "bj_poppet_%s" % ClassFeatures.meta_key(target.id)):
			var hurt := _roll("2d10", "Soulbound Poppet")
			parts.append({"amount": int(hurt["total"]), "type": "necrotic"})
			_log("damage", "%s twists the wicker doll: +%d Necrotic to %s (Soulbound Poppet)" % [source.name(), int(hurt["total"]), target.name()], source, [str(hurt["text"])])
			e.events.append({"type": "condition", "id": target.id})
			break


func _well_ready(c: Combatant) -> bool:
	var ch := _ch(c)
	return ch != null and has(c, "blood_well") and ch.resource_left("blood_well") > 0 and _mode(c, "blood_well") != "never"


## Whether `parts` come from `source`'s weapon or Unarmed Strike hit (the attack being dealt now, not a spell).
func _weapon_blow(source: Combatant, parts: Array) -> bool:
	if parts.any(func(p: Variant) -> bool: return bool((p as Dictionary).get("weapon", false))):
		return true
	var hc := enc().hit_context
	return str(hc.get("attacker", "")) == source.id and not bool(hc.get("spell", false)) \
		and not parts.any(func(p: Variant) -> bool: return bool((p as Dictionary).get("spell", false)))


## The Blood Well on a spell's healing of `t`: when armed, or on its own (Automatic) when the heal lifts a downed ally.
func spell_healing(ctx: Dictionary, t: Combatant) -> int:
	var c := ctx.get("c") as Combatant
	if c == null or t == null or not _well_ready(c):
		return 0
	var armed := "bj_blood_well" in c.armed
	if not armed and not (_mode(c, "blood_well") == "auto" and t.creature.hp <= 0 and not t.creature.dead):
		return 0
	c.armed.erase("bj_blood_well")
	(_ch(c) as Character).spend_resource("blood_well")
	var rolled := enc().heal_roll("1d8", t, "Blood Well")
	_log("heal", "%s pours the Blood Well into the healing: +%d for %s" % [c.name(), int(rolled["total"]), t.name()], c, [str(rolled["text"])])
	return int(rolled["total"])


## The Blood Well fills again when a creature takes 10 or more Necrotic damage from the sorcerer at once.
func _refill_well(source: Combatant, target: Combatant, parts: Array) -> void:
	var ch := _ch(source)
	if ch == null or not has(source, "blood_well") or ch.resource_left("blood_well") >= ch.resource_max("blood_well"):
		return
	var necrotic: Array = []
	for p: Variant in parts:
		if str((p as Dictionary).get("type", "")) == "necrotic" and int((p as Dictionary).get("amount", 0)) > 0:
			necrotic.append({"amount": int((p as Dictionary)["amount"]), "type": "necrotic"})
	if necrotic.is_empty():
		return
	var taken := target.creature.preview_damage_parts(necrotic).final
	if taken >= 10:
		ch.restore_resource("blood_well")
		_log("info", "%s drinks in %d Necrotic: the Blood Well fills again" % [source.name(), taken], source)


# --- Crimson Sorcery: Pool of Blood ------------------------------------------------------------------------------

## Pool of Blood: a Bonus Action and the Blood Well; the sorcerer becomes a pool with its own numbers (ShapeChange),
## Speed 10 ft with Climb and Swim 10 ft, Resistance to Bludgeoning, Piercing and Slashing (and what it already
## resists), immune to Prone, Advantage on Strength, Dexterity and Constitution saves, into others' spaces; no attacks,
## spells or speech. It ends at 0 Hit Points (ShapeChange) or when the sorcerer leaves the shape.
func _pool_of_blood(c: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if e.shapes.is_shaped(c):
		return CombatResult.fail("You're already in another shape")
	if ch.resource_left("blood_well") <= 0:
		return CombatResult.fail("Your Blood Well is spent")
	ch.spend_resource("blood_well")
	c.bonus_available = false
	c.creature.remove_condition(&"prone", "Prone")
	e.shapes.transform(c, pool_form(c), {"label": "Pool of Blood", "keep_mind": true})
	_log("info", "%s melts into a pool of blood" % c.name(), c)
	return CombatResult.new()


## Ending the Pool of Blood takes no action: its own way out on the shaped hotbar, in place of "Leave Wild Shape".
func shaped_list(c: Combatant, out: Array[Dictionary], _bw: String) -> bool:
	var e := enc()
	if not e.shapes.is_shaped(c) or str((e.shapes.originals[c.id] as Dictionary).get("label", "")) != "Pool of Blood":
		return false
	out.append(_act("end_pool", "Leave the Pool of Blood", "true form", "free", e._turn_check(c), "none",
		"Rise from the pool into your own body again (no action)."))
	return true


## The pool's stat block: `c`'s own scores, saves, AC and defences with the Pool of Blood's changes.
static func pool_form(c: Combatant) -> Dictionary:
	var cr := c.creature
	var abilities := {}
	var saves := {}
	for k: String in ["str", "dex", "con", "int", "wis", "cha"]:
		abilities[k] = cr.ability_score(StringName(k))
		saves[k] = cr.save_bonus(StringName(k)).total()
	var resist: Array = ["bludgeoning", "piercing", "slashing"]
	var immune: Array = []
	for ty in DAMAGE_TYPES:
		if cr.immunity_source(StringName(ty)) != "":
			immune.append(ty)
		elif cr.resistance_source(StringName(ty)) != "" and not ty in resist:
			resist.append(ty)
	var mods: Array = [{"stat": "advantage", "on": "save:str"}, {"stat": "advantage", "on": "save:dex"}, {"stat": "advantage", "on": "save:con"},
		{"stat": "flag", "value": "enters_spaces"}, {"stat": "flag", "value": "spider_climb"}, {"stat": "flag", "value": "speechless"}]
	return {"id": "pool_of_blood", "name": "pool of blood", "art": "black_pudding", "size": str(cr.size), "type": str(cr.creature_type),
		"ac": cr.ac_value(), "hp": {"average": cr.max_hp(), "dice": str(cr.max_hp())}, "speed": {"walk": 10, "climb": 10, "swim": 10},
		"abilities": abilities, "saves": saves, "resistances": resist, "immunities": immune, "condition_immunities": ["prone"],
		"senses": {"darkvision": cr.darkvision()}, "cr": 0, "xp": 0, "proficiency_bonus": cr.proficiency_bonus(),
		"initiative": cr.initiative_bonus().total(),
		"traits": [{"id": "pool_of_blood", "name": "Pool of Blood", "action": "passive", "modifiers": mods,
			"summary": "Slips through cracks and into others' spaces; can't attack, cast spells or speak."}],
		"actions": [], "summary": "A sorcerer melted into a slick of living blood.", "text": "Pool of Blood."}


# --- Great Fool Patron -------------------------------------------------------------------------------------------

## Jester's Japes: a Magic action, once per Short Rest; a Charisma save against the warlock's spell DC or a 1-minute
## curse of the warlock's pick, saved again at the end of each of the creature's turns.
func _japes(c: Combatant, t: Combatant, kind: String) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if not JAPES.has(kind):
		return CombatResult.fail("Not available")
	if t == null or t == c or not e.can_see(c, t) or e.distance(c, t) > 60:
		return CombatResult.fail("Choose a creature you can see within 60 ft")
	ch.spend_resource("jesters_japes")
	e.spend_action(c)
	c.magic_action_used = true
	var dc := cf()._spell_dc(c, "warlock")
	var label := "Jester's Japes: %s" % JAPES[kind][0]
	_log("info", "%s plays a jape on %s" % [c.name(), t.name()], c)
	if cf()._save(t, &"cha", dc, label):
		return CombatResult.new()
	var fx := cf()._minutes(c, label, "jesters_japes", 1)
	fx.repeat_save = {"ability": "cha", "dc": dc, "when": "end"}
	match kind:
		"flower_spurt":
			fx.with_condition(&"blinded")
		"clown_shoes":
			fx.with_modifier("speed_percent", {"value": 50}).with_modifier("disadvantage", {"on": "check:dex"}) \
				.with_modifier("disadvantage", {"on": "save:dex"})
		"honk_honk":
			fx.with_modifier("flag", {"value": "no_invisible"})
		"jolly_arms":
			fx.with_modifier("flag", {"value": "bj_jolly_arms"})
	if t.creature.add_effect(fx):
		_log("condition", "%s is cursed: %s" % [t.name(), JAPES[kind][0]], t)
		e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## Killing Joke: a creature the warlock sees within 60 ft fails a save. It waits in the queue with its roll, so a save
## turned into a success afterwards (Legendary Resistance) is let go.
func d20_offers(c: Combatant, t: D20Test, _keys: Array[String], _out: Array) -> void:
	if t.kind == D20Test.Kind.SAVING_THROW and not t.success and enc().state == Encounter.State.ACTIVE:
		_queue_killing_joke(c, t)


## Killing Joke when a creature takes damage; Sacrifice when a hostile creature in an effigy's aura does.
func queue_damage_reactions(_source: Combatant, target: Combatant) -> void:
	_queue_killing_joke(target, null)
	_queue_sacrifice(target)


func _queue_killing_joke(t: Combatant, test: D20Test) -> void:
	var e := enc()
	if t == null or not t.is_alive() or t.creature.hp <= 0:
		return
	for w in e.combatants:
		if w == t or not has(w, "killing_joke") or _ch(w).resource_left("killing_joke") <= 0 or not e.spells.can_react(w):
			continue
		var mode := _mode(w, "killing_joke")
		# Automatic mocks only foes; Ask offers it on anyone.
		if mode == "never" or (mode == "auto" and not w.hostile_to(t)) or _queued(w, "gm_bj_killing_joke"):
			continue
		if e.distance(w, t) > 60 or not e.can_see(w, t) or not _can_mock(w):
			continue
		var q := {"kind": "gm_bj_killing_joke", "reactor": w.id, "trigger": t.id, "plan": _plan(mode)}
		if test != null:
			q["test"] = test
		e.reaction_queue.append(q)


## Whether the warlock can cast Vicious Mockery now (a voice, no Antimagic, nothing stopping its spells).
func _can_mock(w: Combatant) -> bool:
	var e := enc()
	if e.spells.caster_char(w) == null or w.creature.has_flag("cant_cast") or e.spells.specials.high.in_antimagic(w):
		return false
	return e.spells.reaction_spells._voice_ok(w, Compendium.shared().spell_data("vicious_mockery"))


## Vicious Mockery cast with the Reaction and a Killing Joke use (a cantrip: no slot).
func _killing_joke(w: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var spells := e.spells
	_ch(w).spend_resource("killing_joke")
	w.reaction_available = false
	if not spells.casting_gate(w):
		return CombatResult.new()
	var s := Compendium.shared().spell_data("vicious_mockery")
	_log("spell", "%s answers with a cruel joke at %s (Killing Joke)" % [w.name(), t.name()], w)
	e.events.append({"type": "spell", "caster": w.id, "spell": "vicious_mockery", "cells": [], "targets": [t.id]})
	spells.trigger_ends(w, "cast_spell")
	var ctx := {"c": w, "s": s, "slot": 0, "nums": spells.numbers(w, spells._entry_any(w, "vicious_mockery")), "conc": null, "opts": {},
		"point": e.center_of(t), "cells": [], "choice": "", "direction": (e.center_of(t) - e.center_of(w)).normalized(), "cell": t.cell}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [t]
	return e.then(spells._resolve(ctx, tgt, [], r, true), func() -> CombatResult:
		e._check_over()
		return r)


## After damage lands: the Blood Well's refill, and Mocking Banter (a creature damaged the warlock: queued here,
## where the damage taken is known).
func after_damage(source: Combatant, target: Combatant, amount: int, ps: Array = [], _dr: DamageResult = null) -> void:
	var e := enc()
	if source != null and source != target:
		_refill_well(source, target, ps)
	if source == null or source == target or amount <= 0 or not target.is_alive() or target.creature.hp <= 0:
		return
	if has(target, "mocking_banter") and _ch(target).resource_left("mocking_banter") > 0 and e.spells.can_react(target) \
			and source.is_alive() and not source.is_down():
		var mode := _mode(target, "mocking_banter")
		if mode != "never" and not _queued(target, "gm_bj_mocking_banter"):
			e.reaction_queue.append({"kind": "gm_bj_mocking_banter", "reactor": target.id, "trigger": source.id, "amount": amount, "plan": _plan(mode)})


## Mocking Banter: a Wisdom save against the warlock's spell DC; Psychic damage equal to what the warlock took, half
## on a success.
func _mocking_banter(w: Combatant, t: Combatant, amount: int) -> CombatResult:
	var e := enc()
	_ch(w).spend_resource("mocking_banter")
	w.reaction_available = false
	_log("info", "%s mocks %s without mercy (Mocking Banter)" % [w.name(), t.name()], w)
	var ok := cf()._save(t, &"wis", cf()._spell_dc(w, "warlock"), "Mocking Banter")
	var dealt := amount / 2 if ok else amount
	if dealt > 0:
		e.deal_damage(w, t, [{"amount": dealt, "type": "psychic"}], false, "Mocking Banter")
	return CombatResult.new()


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var e := enc()
	var t := e.get_c(str(q["trigger"]))
	if t == null or not t.is_alive() or not e.spells.can_react(reactor) or _ch(reactor) == null:
		return false
	match str(q["kind"]):
		"gm_bj_killing_joke":
			if q.has("test") and (q["test"] as D20Test).success:
				return false
			return _ch(reactor).resource_left("killing_joke") > 0 and t.creature.hp > 0 and e.distance(reactor, t) <= 60 \
				and e.can_see(reactor, t) and _can_mock(reactor)
		"gm_bj_mocking_banter":
			return _ch(reactor).resource_left("mocking_banter") > 0 and reactor.creature.hp > 0
		"gm_bj_sacrifice":
			var eff := _effigy_of(reactor)
			return eff != null and str(eff.get_meta("bj_effigy")) == "sacrifice" and t.creature.hp > 0 and _in_aura(eff, t)
	return false


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	match str(q["kind"]):
		"gm_bj_killing_joke":
			return _killing_joke(reactor, trigger)
		"gm_bj_mocking_banter":
			return _mocking_banter(reactor, trigger, int(q.get("amount", 0)))
		"gm_bj_sacrifice":
			return _sacrifice(reactor, trigger)
	return CombatResult.new()


func queued_text(kind: String) -> Array:
	match kind:
		"gm_bj_killing_joke":
			return ["Reaction: Killing Joke?", "%s is hurt or reeling. %s can mock it with Vicious Mockery.", "Reaction and a Killing Joke use"]
		"gm_bj_mocking_banter":
			return ["Reaction: Mocking Banter?", "%s hurt %s. Mock it back: a Wisdom save or Psychic damage as large as the hurt.", "Reaction and the once-per-rest use"]
		"gm_bj_sacrifice":
			return ["Reaction: Sacrifice?", "%s bleeds by the effigy. %s can set it alight.", "Reaction"]
	return ["Reaction?", "%s acts; %s can react.", "Reaction"]


# --- Circle of Wicker: the Bewitched Effigy ----------------------------------------------------------------------

## The druid's effigy standing now, or null.
func _effigy_of(c: Combatant) -> Combatant:
	for o in enc().combatants:
		if o.is_alive() and o.has_meta("bj_effigy") and str(o.get_meta("summoner", "")) == c.id:
			return o
	return null


## Whether `t` stands in the effigy's 30-ft Emanation.
func _in_aura(eff: Combatant, t: Combatant) -> bool:
	return t != eff and enc().grid.in_emanation(eff.cell, eff.size_cells, 30, t.cell, t.size_cells, eff.altitude, t.altitude)


func _soothe_max(c: Combatant) -> int:
	return 2 * maxi(1, c.creature.ability_mod(&"wis"))


## Bewitched Effigy: a Bonus Action and a Wild Shape use; a Small object on the druid's side in a square within 30 ft
## for 1 minute (AC 15, 5 Hit Points per Druid level, Fire Vulnerability, no Poison or Psychic damage), with the aura
## picked now. A new one ends the old. It takes no turns (Bigby's Hand's way): the druid's turn counts its minute.
func _make_effigy(c: Combatant, aura: String, cell: Vector2i, choice: String) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if not AURAS.has(aura):
		return CombatResult.fail("Not available")
	if cell.x < 0 or not e.grid.in_bounds(cell) or e.grid.is_solid(cell):
		return CombatResult.fail("Choose an open square")
	if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) > 30:
		return CombatResult.fail("At most 30 ft away")
	if e.occupant_at(cell) != null:
		return CombatResult.fail("That square is occupied")
	if not e.can_see_space(c, cell):
		return CombatResult.fail("You must see the square")
	ch.spend_resource("wild_shape")
	c.bonus_available = false
	var old := _effigy_of(c)
	if old != null:
		_end_effigy(old, "a new one takes its place")
	var hp := 5 * maxi(1, ch.class_level_of("druid"))
	var m := Monster.from_data({"id": "wicker_effigy", "name": "Wicker Effigy (%s)" % AURAS[aura], "art": "scarecrow", "size": "small",
		"type": "object", "ac": 15, "hp": {"average": hp, "dice": str(hp)}, "speed": {"walk": 0},
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1},
		"vulnerabilities": ["fire"], "immunities": ["poison", "psychic"],
		"condition_immunities": ["blinded", "charmed", "deafened", "exhaustion", "frightened", "grappled", "incapacitated", "paralyzed",
			"petrified", "poisoned", "prone", "restrained", "stunned", "unconscious"],
		"cr": 0, "xp": 0, "proficiency_bonus": c.creature.proficiency_bonus(), "summon": true,
		"traits": [{"id": "wicker_object", "name": "Wicker Object", "action": "passive", "modifiers": [{"stat": "flag", "value": "spell_object"}],
			"summary": "An object: it takes no turns, and it burns easily."}],
		"actions": [], "summary": "A wicker figure humming with the druid's craft.", "text": "Bewitched Effigy."})
	var sc := e.add(m, &"guest" if c.side == &"party" else c.side, cell)
	sc.controller = &"ai"
	sc.set_meta("summoner", c.id)
	sc.set_meta("vanishes", true)
	sc.set_meta("bj_effigy", aura)
	sc.set_meta("bj_effigy_until", e.round_no + Effect.ROUNDS_PER_MINUTE)
	if aura == "soothe":
		sc.set_meta("bj_soothe_left", _soothe_max(c))
	if aura == "ward" and has(c, "wicker_rising"):
		sc.set_meta("bj_ward_type", choice if choice in DAMAGE_TYPES and choice != "force" else likely_damage_type(c))
	if not e.spells.summoned.has(c.id):
		e.spells.summoned[c.id] = []
	(e.spells.summoned[c.id] as Array).append(sc.id)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": cell, "caster": c.id})
	# The glow: a 30-ft Emanation of Dim Light round the effigy (as Light's, a zone with no squares of its own).
	var glow := FieldObject.new(FieldObject.Kind.ZONE, "bewitched_effigy", "Effigy's glow")
	glow.caster_id = c.id
	glow.cell = cell
	glow.rules = {"light": {"bright": 0, "dim": 30}, "light_on": "target", "light_target": sc.id}
	e.spells.zones.add(glow, CombatResult.new())
	sc.set_meta("bj_effigy_glow", glow.id)
	_log("info", "%s weaves a wicker effigy; its %s aura spreads 30 ft" % [c.name(), AURAS[aura]], c)
	if aura == "soothe":
		var hurt := _most_hurt(c, sc)
		if hurt != null:
			_soothe(c, sc, hurt)
	refresh_wards()
	return CombatResult.new()


## The effigy's damage type for Ward at Wicker Rising when the player didn't pick one: the type the foes' attacks deal
## most (Slashing when they show none).
func likely_damage_type(c: Combatant) -> String:
	var count := {}
	for h in enc().hostiles_of(c):
		if not h.creature is Monster:
			continue
		for a: Variant in (h.creature as Monster).data.get("actions", []):
			for d: Variant in (a as Dictionary).get("damage", []):
				var ty := str((d as Dictionary).get("type", ""))
				if ty in DAMAGE_TYPES and ty != "force":
					count[ty] = int(count.get(ty, 0)) + 1
	var best := "slashing"
	for ty: String in count:
		if int(count[ty]) > int(count.get(best, 0)):
			best = ty
	return best


## The creature in the aura that most needs Soothe's healing: a downed one first, then the lowest share of Hit Points.
func _most_hurt(c: Combatant, eff: Combatant) -> Combatant:
	var best: Combatant = null
	var best_share := 2.0
	var pool: Array[Combatant] = [c]
	pool.append_array(enc().allies_of(c))
	for o in pool:
		if o == eff or o.creature.dead or o.creature.has_flag("spell_object") or not _in_aura(eff, o) or o.creature.hp >= o.creature.max_hp():
			continue
		var share := -1.0 if o.creature.hp <= 0 else float(o.creature.hp) / maxf(1.0, float(o.creature.max_hp()))
		if share < best_share:
			best_share = share
			best = o
	return best


## Soothe: `t` regains 1d6 (1d8 at Wicker Rising); at Wicker Rising 5 of the effigy's Hit Points lift one of the
## conditions on it, while the effigy has more than that to give.
func _soothe(c: Combatant, eff: Combatant, t: Combatant) -> void:
	var e := enc()
	var rising := has(c, "wicker_rising")
	eff.set_meta("bj_soothe_left", int(eff.get_meta("bj_soothe_left", 0)) - 1)
	var rolled := e.heal_roll("1d8" if rising else "1d6", t, "Soothe")
	cf()._heal(c, t, int(rolled["total"]), "Soothe (Bewitched Effigy)")
	if not rising or eff.creature.hp <= 5:
		return
	for cond in SOOTHE_CONDITIONS:
		if t.creature.has_condition(cond):
			eff.creature.hp -= 5
			t.creature.end_condition(cond)
			_log("condition", "The effigy gives up some of its straw: %s is no longer %s" % [t.name(), str(cond).capitalize()], t)
			e.events.append({"type": "condition", "id": t.id})
			e.events.append({"type": "damage", "id": eff.id, "amount": 5})
			return


## Sacrifice: a hostile creature in the aura that takes damage can be set alight with the druid's Reaction.
func _queue_sacrifice(t: Combatant) -> void:
	var e := enc()
	if t == null or not t.is_alive() or t.creature.hp <= 0:
		return
	for eff in e.combatants:
		if not eff.is_alive() or str(eff.get_meta("bj_effigy", "")) != "sacrifice" or not _in_aura(eff, t):
			continue
		var d := e.get_c(str(eff.get_meta("summoner", "")))
		if d == null or not d.hostile_to(t) or not e.spells.can_react(d) or _queued(d, "gm_bj_sacrifice"):
			continue
		var mode := _mode(d, "bewitched_effigy")
		if mode != "never":
			e.reaction_queue.append({"kind": "gm_bj_sacrifice", "reactor": d.id, "trigger": t.id, "plan": _plan(mode)})


## Sacrifice's flames: 1d8 (2d8 at Wicker Rising) + the druid's Wisdom modifier Fire.
func _sacrifice(d: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	d.reaction_available = false
	var rolled := _roll("2d8" if has(d, "wicker_rising") else "1d8", "Sacrifice")
	var amount := int(rolled["total"]) + d.creature.ability_mod(&"wis")
	_log("info", "The effigy's flames leap at %s (Sacrifice)" % t.name(), d)
	e.deal_damage(d, t, [{"amount": maxi(0, amount), "type": "fire"}], false, "Sacrifice", [str(rolled["text"])])
	return CombatResult.new()


## Ward: +1 AC (and Wicker Rising's Resistance) for the druid and allies in each Ward effigy's aura; taken off those who
## left it, and from everyone once the effigy is gone.
func refresh_wards() -> void:
	var e := enc()
	if e == null:
		return
	var wards: Array[Combatant] = []
	for o in e.combatants:
		if o.is_alive() and str(o.get_meta("bj_effigy", "")) == "ward":
			wards.append(o)
	for t in e.combatants:
		for fx: Effect in t.creature.effects.duplicate():
			if fx.stack_key.begins_with("bj_ward:"):
				var eff := e.get_c(fx.stack_key.substr(8))
				if eff == null or not eff in wards or not _in_aura(eff, t):
					t.creature.remove_effect(fx)
	for eff in wards:
		var d := e.get_c(str(eff.get_meta("summoner", "")))
		if d == null:
			continue
		var key := "bj_ward:%s" % eff.id
		for t in e.living():
			if t == eff or t.creature.has_flag("spell_object") or not (t == d or d.allied_with(t)) or not _in_aura(eff, t):
				continue
			if t.creature.effects.any(func(x: Effect) -> bool: return x.stack_key == key):
				continue
			var fx := Effect.new("Ward (Bewitched Effigy)", &"feature", "bewitched_effigy")
			fx.stack_key = key
			fx.caster_id = d.id
			# Counted in rounds to the effigy's own end, so it never outlives the fight (clear_fight_effects).
			fx.lasting_rounds(maxi(1, int(eff.get_meta("bj_effigy_until", e.round_no + 1)) - e.round_no), d.id)
			fx.with_modifier("ac", {"value": 1})
			if eff.has_meta("bj_ward_type"):
				fx.with_modifier("resistance", {"value": str(eff.get_meta("bj_ward_type"))})
			t.creature.add_effect(fx)


## The effigy goes: it vanishes, its glow ends and its Ward comes off.
func _end_effigy(eff: Combatant, why: String) -> void:
	var e := enc()
	if eff.is_alive():
		eff.creature.dead = true
		_log("info", "The wicker effigy crumbles (%s)" % why, eff)
		e.events.append({"type": "vanish", "id": eff.id})
	_tidy_effigy(eff)


func _tidy_effigy(eff: Combatant) -> void:
	var e := enc()
	var glow := e.spells.zones.get_object(str(eff.get_meta("bj_effigy_glow", "")))
	if glow != null and not glow.ended:
		glow.ended = true
		e.spells.zones.prune()
	refresh_wards()


## An effigy smashed to 0 Hit Points.
func on_death(_source: Combatant, dead: Combatant) -> void:
	if dead.has_meta("bj_effigy"):
		_tidy_effigy(dead)


## A creature stepping in or out of a Ward aura.
func entered_cell(_c: Combatant, _cell: Vector2i) -> void:
	if enc().combatants.any(func(o: Combatant) -> bool: return o.has_meta("bj_effigy")):
		refresh_wards()


## Foes weigh smashing an effigy by what its aura does to them: a Sacrifice burning them where they stand is worth
## breaking, a Soothe with healing left nearly so, a Ward less; otherwise an object is worth less than a hero.
func target_weight(c: Combatant, t: Combatant) -> float:
	if not t.has_meta("bj_effigy"):
		return 1.0
	match str(t.get_meta("bj_effigy")):
		"sacrifice":
			return 1.1 if enc().grid.in_emanation(t.cell, t.size_cells, 30, c.cell, c.size_cells, t.altitude, c.altitude) else 0.6
		"soothe":
			return 0.9 if int(t.get_meta("bj_soothe_left", 0)) > 0 else 0.4
	return 0.7


# --- Circle of Wicker: the Soulbound Poppet and the tokens --------------------------------------------------------

## The poppets `c` carries: [{target, druid, until}].
static func _poppets_on(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Variant in c.get_meta("bj_poppets", []):
		out.append(d as Dictionary)
	return out


## Soulbound Poppet: a Magic action and a Wild Shape use; a doll of a creature within 60 ft, kept or handed to an ally
## within 5 ft as part of the action, for 1 minute.
func _poppet(c: Combatant, t: Combatant, carrier_id: String) -> CombatResult:
	var e := enc()
	if t == null or t == c or not e.can_see(c, t) or e.distance(c, t) > 60:
		return CombatResult.fail("Choose a creature you can see within 60 ft")
	var carrier := c
	if carrier_id != "":
		carrier = e.get_c(carrier_id)
		if carrier == null or carrier.is_down() or not c.allied_with(carrier) or e.distance(c, carrier) > 5:
			return CombatResult.fail("Hand the doll to an ally within 5 ft")
	_ch(c).spend_resource("wild_shape")
	e.spend_action(c)
	c.magic_action_used = true
	var dolls := _poppets_on(carrier)
	dolls.append({"target": t.id, "druid": c.id, "until": e.round_no + Effect.ROUNDS_PER_MINUTE})
	carrier.set_meta("bj_poppets", dolls)
	_log("info", "%s weaves a wicker doll of %s%s (Soulbound Poppet)" % [c.name(), t.name(), "" if carrier == c else " and hands it to %s" % carrier.name()], c)
	e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## The doll's creature has Disadvantage on attacks against whoever carries it.
func attack_situation(c: Combatant, target: Combatant, _option: Dictionary, _adv: Array[String], dis: Array[String]) -> void:
	for d in _poppets_on(target):
		if str(d["target"]) == c.id:
			dis.append("Soulbound Poppet")
			return


## A fight begins: Wards left from another fight come off; the party carries the druid's Wicker Tokens (as many as were
## made: Proficiency Bonus a Long Rest), one each, the druid's allies in the order they stand in the fight.
func fight_started() -> void:
	var e := enc()
	# No Ward from an earlier fight carries into this one.
	for c in e.combatants:
		for fx: Effect in c.creature.effects.duplicate():
			if fx.stack_key.begins_with("bj_ward:"):
				c.creature.remove_effect(fx)
	for d in e.combatants:
		var ch := _ch(d)
		if ch == null or not has(d, "wicker_token"):
			continue
		var left := ch.resource_left("wicker_tokens")
		for a in e.allies_of(d):
			if left <= 0:
				break
			if a.creature.has_flag("spell_object"):
				continue
			a.set_meta(token_key(d), true)
			left -= 1


static func token_key(druid: Combatant) -> String:
	return "bj_token_%s" % ClassFeatures.meta_key(druid.id)


## Whether a touch spell of `c`'s reaches `t` wherever it stands, line of effect or not: `t` carries one of `c`'s Wicker
## Tokens (SpellTargeting's target check asks).
func spell_reach(c: Combatant, s: Dictionary, t: Combatant) -> bool:
	if c == null or t == null or t == c or str((s.get("range", {}) as Dictionary).get("kind", "")) != "touch":
		return false
	return has(c, "wicker_token") and bool(t.get_meta(token_key(c), false))


# --- Turns ---------------------------------------------------------------------------------------------------------

## At the druid's turn start its effigy's and dolls' minute may be up; the Ward aura is checked for everyone.
func turn_start(c: Combatant) -> CombatResult:
	var e := enc()
	var eff := _effigy_of(c)
	if eff != null and e.round_no >= int(eff.get_meta("bj_effigy_until", 0)):
		_end_effigy(eff, "its minute is up")
	for o in e.combatants:
		var dolls := _poppets_on(o)
		if dolls.is_empty():
			continue
		var kept: Array[Dictionary] = []
		for d in dolls:
			if str(d["druid"]) == c.id and e.round_no >= int(d["until"]):
				var who := e.get_c(str(d["target"]))
				_log("info", "The wicker doll of %s falls apart" % (who.name() if who != null else "a creature"), o)
				continue
			kept.append(d)
		o.set_meta("bj_poppets", kept)
	if e.combatants.any(func(o: Combatant) -> bool: return o.has_meta("bj_effigy")):
		refresh_wards()
	return CombatResult.new()
