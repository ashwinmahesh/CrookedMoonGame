class_name CmScholars
extends CmPart
## The Crooked Moon's code for three of the book's subclasses (chapter 3): Horned King Patron, Occultist and Philosopher: the parts of them data can't say.
## CrookedFeatures forwards every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start
## "sh_".
##
## Horned King Patron: Malediction (a Magic action, or a Reaction when a foe attacks the warlock, asked before the roll,
## or once its spell attack or the warlock's save against its spell is rolled), Spiteful Curse (a free Bestow Curse
## through it) and Crown of Horns (Dark Heart's extra Necrotic once a turn, King of All once on each of the warlock's
## turns).
## Occultist: the Intrusion Die is the resource "intrusion_die" (the subclass table "intrusion_steps" gives its top
## step): what is left is the die's step in DIE_SIZES, so a Long Rest resets it, a Short Rest grows it one step
## ("short_one") and it outlives the fight. Risks are riders the player arms (the autopilot never does); an Intrusion
## waits in the reaction queue until the spell or action that caused it is done, and asks when Occult Presence gives a
## choice.
## Philosopher: Quintessence is a count kept in the build ("quintessence"), since every resource refills on a Long Rest.

const PREFIX := "sh_"

## The Intrusion Die's sizes, smallest first; the resource's "left" is an index into this.
const DIE_SIZES: Array[int] = [2, 3, 4, 6, 8, 10, 12]

## Malediction's curses, picked per use: value -> label.
const CURSES := {
	"agony": "Agony: Disadvantage on its next attack roll",
	"agony_conc": "Agony: Disadvantage on its next Concentration save",
	"hate:int": "Hate: Disadvantage on its next Intelligence save",
	"hate:wis": "Hate: Disadvantage on its next Wisdom save",
	"hate:cha": "Hate: Disadvantage on its next Charisma save",
	"rot": "Rot: +1d10 Necrotic the next time it's hurt, no healing",
}

## Bestow Curse's options (its data's choice) for Spiteful Curse: value -> label.
const BESTOW := {
	"ability_str": "Bestow Curse: Strength", "ability_dex": "Bestow Curse: Dexterity", "ability_con": "Bestow Curse: Constitution",
	"ability_int": "Bestow Curse: Intelligence", "ability_wis": "Bestow Curse: Wisdom", "ability_cha": "Bestow Curse: Charisma",
	"attacks": "Bestow Curse: Disadvantage attacking you", "dodge": "Bestow Curse: wasted turns",
	"necrotic": "Bestow Curse: +1d8 Necrotic from you",
}

## King of All's effects, picked per turn.
const AURA := {"enticement": "Enticement: Charmed", "wickedness": "Wickedness: Disadvantage on attacks and checks",
	"terror": "Terror: Frightened, flees"}

## Intrusion's focus options (its data's choice) and the riders that arm them.
const RISKS := {"overwhelming_mind": "sh_risk_mind", "seeking_eye": "sh_risk_eye"}

const BENEFITS: Array[String] =["alien_consciousness", "cosmic_resistance", "spatial_domination"]

## The Intrusion table, in our own short words (row 1 first).
const INTRUSIONS: Array[String] = [
	"A whisper behind you: one of action, Bonus Action or move a turn until the end of your next turn",
	"Space melts: Speed halved within 30 ft (you too) until the end of your next turn",
	"The nearest creature within 60 ft: Con save or Necrotic damage you drink as healing",
	"Reality tears: you and all who see it, Wis save or Frightened until the end of your next turn",
	"An alien limb for 1 minute: Unarmed Strikes with Intelligence for Acid dice",
	"Alien landscapes: Blinded until the end of your next turn",
	"Unnatural thoughts: Incapacitated until the end of your next turn",
	"Terrible clarity: Psychic damage, and +2 spell save DC for 1 minute",
	"A spent slot (level 5 or lower) back, for Necrotic damage twice its level",
	"Pulses of space knock you and all within 15 ft Prone, now and at each of your turn ends for 1 minute",
	"Hateful whispers: Disadvantage on Wisdom checks and saves for 1 hour",
	"Something from beyond (an Aberration or a Fiend) steps through",
]


func prefix() -> String:
	return PREFIX


# --- Small helpers ------------------------------------------------------------------------------------------------

func _fx(by: Combatant, label: String, source: String) -> Effect:
	var fx := Effect.new(label, &"feature", source)
	fx.caster_id = by.id
	return fx


## "Until the end of `owner`'s next turn".
func _until_end(fx: Effect, owner: Combatant) -> Effect:
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = owner.id
	fx.skip_turn_ends = enc().own_turn_skip(owner)
	return fx


## "Until the start of `owner`'s next turn".
func _until_start(fx: Effect, owner: Combatant) -> Effect:
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = owner.id
	return fx


## Lasting `minutes`, counted on `owner`'s turns.
func _for_minutes(fx: Effect, owner: Combatant, minutes: int) -> Effect:
	fx.lasting({"kind": "minutes", "amount": minutes})
	fx.turn_owner_id = owner.id
	return fx


## Puts `fx` on `t` and says so.
func _land(t: Combatant, fx: Effect, text: String, details: Array = []) -> void:
	if t.creature.add_effect(fx):
		_log("condition", text, t, details)
		enc().events.append({"type": "condition", "id": t.id})


static func _effect_of(c: Combatant, source: String) -> Effect:
	for fx: Effect in c.creature.effects:
		if fx.source_id == source:
			return fx
	return null


## A saving throw against `by`'s feature (its keys name `by` as a spell's caster would, so Overwhelming Mind reaches it).
func _save(by: Combatant, t: Combatant, ab: StringName, dc: int, label: String, cond: String = "") -> D20Test:
	var keys: Array[String] = SpellSaves.spell_save_keys(by.id)
	if cond != "":
		keys.append("save_vs:%s" % cond)
	var sv := t.creature.roll_save(enc().dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, t.name()], keys)
	_log("save", "%s %s the %s save" % [t.name(), "succeeds on" if sv.success else "fails", label], t, [sv.describe()])
	return sv


func _class_dc(c: Combatant, class_id: String) -> int:
	return enc().class_features._spell_dc(c, class_id)


static func _choices(d: Dictionary) -> Array:
	var out: Array = []
	for k: String in d:
		out.append({"value": k, "label": str(d[k])})
	return out


## A prompt's picks from a {value: label} table.
static func _picks(d: Dictionary) -> Array:
	var out: Array = []
	for k: String in d:
		out.append({"id": k, "label": str(d[k])})
	return out


# --- The hotbar ---------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	var magic := _first(aw, "Only one Magic action this turn" if c.magic_action_used else "")
	if has(c, "malediction"):
		var m := _act("malediction", "Malediction", "curse · 60 ft · %d left" % ch.resource_left("malediction"), "action",
			_first(magic, _res_why(c, "malediction")), "creature",
			"Magic action and a use: curse a creature you can see within 60 ft until the end of its next turn. Agony: Disadvantage on its next attack roll (or Concentration save). Hate: Disadvantage on its next Intelligence, Wisdom or Charisma save. Rot: its next damage adds 1d10 Necrotic, and it can't heal. The same curse can answer a foe's attack or spell as your Reaction.", 60)
		m["choices"] = _choices(CURSES)
		m["choice_label"] = "Curse"
		out.append(m)
		if has(c, "spiteful_curse"):
			var sp := _act("spiteful_curse", "Spiteful Curse", "Bestow Curse · Wis DC %d · 60 ft" % _class_dc(c, "warlock"), "action",
				_first(_first(magic, _res_why(c, "malediction")), _res_why(c, "spiteful_curse")), "creature",
				"Magic action and a use of Malediction: Bestow Curse without a slot, 60 ft, 1 minute, no Concentration. If the creature saves, a Malediction curse lands instead and Spiteful Curse is kept.", 60)
			sp["choices"] = _choices(BESTOW)
			sp["choice_label"] = "Curse"
			out.append(sp)
	if has(c, "horned_king_patron_crown_of_horns"):
		if _effect_of(c, "sh_crown") == null:
			var left := ch.resource_left("horned_king_patron_crown_of_horns")
			var cw := "None left (and no Pact Magic slot)" if left <= 0 and int(ch.pact_magic()["left"]) <= 0 else ""
			out.append(_act("crown_of_horns", "Crown of Horns", "1 min" + ("" if left > 0 else " · a Pact slot"), "bonus", _first(bw, cw), "none",
				"Bonus Action for 1 minute: once on each of your turns your damage adds 1d8 Necrotic (Dark Heart), and once on each of your turns a creature within 20 ft makes a Charisma save or is Charmed, shamed (Disadvantage on attacks and checks) or Frightened until your next turn (King of All). Once per Long Rest, or spend a Pact Magic slot."))
		else:
			var kw := e._turn_check(c)
			if kw == "" and str(c.get_meta("sh_king_turn", "")) == _turn_key():
				kw = "Already used this turn"
			var k := _act("king_of_all", "King of All", "20 ft · Cha DC %d" % _class_dc(c, "warlock"), "free", kw, "creature",
				"Once on each of your turns while the Crown lasts: a creature you can see within 20 ft makes a Charisma save or suffers the effect you pick until the start of your next turn.", 20)
			k["choices"] = _choices(AURA)
			k["choice_label"] = "Effect"
			out.append(k)
	if has(c, "occult_presence") and _die(ch) > 0:
		var cur := _presence(ch)
		var opts: Array = []
		for b in BENEFITS:
			if b != cur:
				opts.append({"value": b, "label": b.replace("_", " ").capitalize()})
		var p := _act("occult_presence", "Change Presence", "automatic Intrusion · d%d" % _die(ch), "bonus", bw, "none",
			"Bonus Action: cause an automatic Intrusion (the die grows a step) to swap your Occult Presence benefit (now %s)." % cur.replace("_", " ").capitalize())
		p["choices"] = opts
		p["choice_label"] = "Benefit"
		out.append(p)


func perform(c: Combatant, id: String, t: Combatant, _cell: Vector2i, _point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var r := CombatResult.new()
	if ch == null:
		return CombatResult.fail("Not available")
	match id.trim_prefix(PREFIX):
		"malediction":
			if t == null or t == c or not e.can_see(c, t):
				return CombatResult.fail("Choose a creature you can see within 60 ft")
			ch.spend_resource("malediction")
			e.spend_action(c)
			c.magic_action_used = true
			_curse(c, t, choice_in if CURSES.has(choice_in) else "agony")
		"spiteful_curse":
			if t == null or t == c or not e.can_see(c, t):
				return CombatResult.fail("Choose a creature you can see within 60 ft")
			ch.spend_resource("malediction")
			e.spend_action(c)
			c.magic_action_used = true
			_spiteful(c, t, choice_in if BESTOW.has(choice_in) else "attacks", r)
			return e.run_reaction_queue(r)
		"crown_of_horns":
			if ch.resource_left("horned_king_patron_crown_of_horns") > 0:
				ch.spend_resource("horned_king_patron_crown_of_horns")
			else:
				var pl := int(ch.pact_magic()["level"])
				if pl <= 0 or not ch.expend_slot(pl):
					return CombatResult.fail("None left")
				_log("info", "%s spends a level %d Pact Magic slot to call the Crown again" % [c.name(), pl], c)
			c.bonus_available = false
			_land(c, _for_minutes(_fx(c, "Crown of Horns", "sh_crown"), c, 1).with_modifier("flag", {"value": "sh_crown"}),
				"%s is crowned with the Horned King's antlers (Crown of Horns, 1 minute)" % c.name())
		"king_of_all":
			if t == null or t == c or not e.can_see(c, t) or e.distance(c, t) > 20:
				return CombatResult.fail("Choose a creature you can see within 20 ft")
			c.set_meta("sh_king_turn", _turn_key())
			_king_of_all(c, t, choice_in if AURA.has(choice_in) else "wickedness")
		"occult_presence":
			if not choice_in in BENEFITS or choice_in == _presence(ch):
				return CombatResult.fail("Choose a different benefit")
			c.bonus_available = false
			_set_presence(c, choice_in)
			_automatic(c, "Occult Presence")
			return e.run_reaction_queue(r)
		_:
			return CombatResult.fail("Not available")
	return r


# --- Horned King Patron: Malediction ------------------------------------------------------------------------------

## Malediction's curse `kind` from `by` on `t`, until the end of `t`'s next turn.
func _curse(by: Combatant, t: Combatant, kind: String) -> void:
	var fx := _until_end(_fx(by, "Malediction (%s)" % str(CURSES.get(kind, kind)).get_slice(":", 0), "sh_malediction"), t)
	fx.stack_key = "sh_malediction:%s:%s" % [by.id, kind]
	match kind:
		"agony":
			fx.with_modifier("disadvantage", {"on": "attack"})
			fx.consume_on = ["attack"]
		"agony_conc":
			fx.with_modifier("disadvantage", {"on": "concentration"})
			fx.consume_on = ["concentration"]
		"hate:int", "hate:wis", "hate:cha":
			var key := "save:" + kind.substr(5)
			fx.with_modifier("disadvantage", {"on": key})
			fx.consume_on = [key]
		"rot":
			fx.with_modifier("flag", {"value": "cant_regain_hp"})
			# The festering half, spent by the next damage (adjust_incoming).
			var sore := _until_end(_fx(by, "Rot (festering)", "sh_rot"), t)
			sore.stack_key = "sh_rot:%s" % by.id
			t.creature.add_effect(sore)
	_land(t, fx, "%s curses %s: %s" % [by.name(), t.name(), str(CURSES.get(kind, kind))])


## Spiteful Curse: Bestow Curse without a slot (60 ft, 1 minute, no Concentration). A save turns it into a Malediction
## curse the warlock picks, and the feature is kept.
func _spiteful(c: Combatant, t: Combatant, option: String, r: CombatResult) -> void:
	var e := enc()
	var s := Compendium.shared().spell_data("bestow_curse").duplicate(true)
	s["duration"] = {"kind": "minutes", "amount": 1}
	_log("spell", "%s casts Bestow Curse through Malediction (Spiteful Curse, no slot): %s" % [c.name(), str(BESTOW[option]).trim_prefix("Bestow Curse: ")], c)
	e.events.append({"type": "spell", "caster": c.id, "spell": "bestow_curse", "cells": [], "outline": {}, "targets": [t.id]})
	if not _save(c, t, &"wis", _class_dc(c, "warlock"), "Bestow Curse").success:
		_ch(c).spend_resource("spiteful_curse")
		var ctx := {"c": c, "s": s, "slot": 3, "nums": e.spells.numbers(c, {"class_id": "warlock"}), "conc": null, "opts": {},
			"choice": option, "point": Vector2.INF, "cells": [], "direction": Vector2.ZERO, "cell": t.cell}
		e.spells.apply_effect_entries(ctx, t, s.get("effects", []) as Array, "fail", r)
		e.events.append({"type": "condition", "id": t.id})
		return
	_log("info", "%s shrugs off Bestow Curse; Spiteful Curse is kept, and a Malediction curse lands instead" % t.name(), t)
	_ask_curse(c, t)


## The Malediction curse a saved Spiteful Curse leaves: asked once the action is done (the reaction queue), Rot when
## nobody is asked.
func _ask_curse(c: Combatant, t: Combatant) -> void:
	var box := {"pick": "rot"}
	var select := func(ids: Array[String]) -> void:
		if not ids.is_empty():
			box["pick"] = ids[0]
	var settle := func() -> void:
		if t.is_alive():
			_curse(c, t, str(box["pick"]))
	var offer := {"kind": "sh_spiteful_pick", "reactor": c, "trigger": t.id, "title": "Spiteful Curse: which curse?",
		"text": "%s saved against Bestow Curse. Pick the Malediction curse it suffers instead." % t.name(), "cost": "Nothing",
		"spends_reaction": false, "default": "ask", "target_choices": _picks(CURSES), "min_targets": 1, "max_targets": 1,
		"selected_ids": ["rot"], "select": select, "use": func() -> void: pass}
	enc().reaction_queue.append({"kind": "gm_sh_spiteful_pick", "reactor": c.id, "trigger": t.id, "offers": [offer], "settle": settle})


## Rot's extra 1d10 Necrotic rides on the next damage the cursed creature takes; Vitriolic Enhancement turns the
## Philosopher's marked damage type into Force.
func adjust_incoming(source: Combatant, target: Combatant, ps: Array) -> void:
	_vitriol(source, ps)
	var sore := _effect_of(target, "sh_rot")
	if sore == null or not ps.any(func(p: Variant) -> bool: return int((p as Dictionary).get("amount", 0)) > 0):
		return
	target.creature.remove_effect(sore)
	var rolled := enc()._roll_damage_dice("1d10", false, 0, "Rot")
	ps.append({"amount": int(rolled["total"]), "type": "necrotic"})
	_log("hit", "Rot festers in %s: +%d Necrotic" % [target.name(), int(rolled["total"])], target, [str(rolled["text"])])


## The Malediction Reaction when a foe targets the warlock with an attack: asked before the roll, so Agony gives that
## very attack Disadvantage.
func before_roll(st: Dictionary, out: Array) -> void:
	var foe := st["c"] as Combatant
	var w := st["target"] as Combatant
	if foe == null or w == null or foe == w or not has(w, "malediction") or not w.hostile_to(foe):
		return
	var dis := (st["sit"] as Dictionary)["disadvantage"] as Array[String]
	var now := func() -> void:
		dis.append("Malediction: Agony (%s)" % w.name())
		_log("reaction", "%s curses %s with Agony: Disadvantage on this attack" % [w.name(), foe.name()], w)
	_malediction_offer(w, foe, "%s attacks %s" % [foe.name(), w.name()], "Agony: Disadvantage on this attack", now, out)


## The Malediction Reaction where no hook comes before the roll: a foe's spell attack roll at the warlock (its key
## "target:<id>"; Agony rolls that attack again and keeps the lower die) and the warlock's save against a foe's spell
## (the curse is for what the caster does next).
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	if c == null or t.auto_failed:
		return
	if t.kind == D20Test.Kind.ATTACK_ROLL and "attack:spell" in keys:
		for k in keys:
			if not k.begins_with("target:"):
				continue
			var w := e.get_c(k.substr(7))
			if w != null and w != c and has(w, "malediction") and w.hostile_to(c):
				var again := func() -> void:
					var before := t.describe()
					var roll := e.dice.d20("Malediction (Agony)")
					if roll < t.kept:
						t.set_natural(roll, "Malediction (Agony)")
					_log("reaction", "%s curses %s with Agony: the spell attack is rolled again and the lower die kept (%d)" % [w.name(), c.name(), t.kept], w, [before, t.describe()])
				_malediction_offer(w, c, "%s's spell attack at %s (%d)" % [c.name(), w.name(), t.total], "Agony: roll this attack again, keep the lower", again, out)
		return
	if t.kind == D20Test.Kind.SAVING_THROW and has(c, "malediction"):
		for k in keys:
			if k.begins_with("save_vs:spell:"):
				var caster := e.get_c(k.substr(14))
				if caster != null and caster != c and caster.hostile_to(c):
					_malediction_offer(c, caster, "%s's spell reaches %s (%d)" % [caster.name(), c.name(), t.total], "", Callable(), out)
				return


## One Malediction Reaction offer from `w` against `foe`. `agony_now` (with its label) is what Agony does to the roll
## that triggered it; without one Agony curses the foe's next attack as usual. Spiteful Curse's Bestow Curse is a pick
## while it's left.
func _malediction_offer(w: Combatant, foe: Combatant, why: String, agony_label: String, agony_now: Callable, out: Array) -> void:
	var e := enc()
	var ch := _ch(w)
	if ch == null or ch.resource_left("malediction") <= 0 or not e.spells.can_react(w) or e.distance(w, foe) > 60 or not e.can_see(w, foe):
		return
	var box := {"pick": "agony" if agony_now.is_valid() else "rot"}
	var choices: Array = []
	for k: String in CURSES:
		choices.append({"id": k, "label": agony_label if k == "agony" and agony_now.is_valid() else str(CURSES[k])})
	if has(w, "spiteful_curse") and ch.resource_left("spiteful_curse") > 0:
		for k2: String in BESTOW:
			choices.append({"id": "bestow:" + k2, "label": "Spiteful Curse · " + str(BESTOW[k2])})
	var select := func(ids: Array[String]) -> void:
		if not ids.is_empty():
			box["pick"] = ids[0]
	var use := func() -> void:
		w.reaction_available = false
		ch.spend_resource("malediction")
		var pick := str(box["pick"])
		if pick.begins_with("bestow:"):
			_spiteful(w, foe, pick.substr(7), CombatResult.new())
		elif pick == "agony" and agony_now.is_valid():
			agony_now.call()
		else:
			_curse(w, foe, pick)
	out.append({"kind": "malediction", "reactor": w, "trigger": foe.id, "title": "Reaction: Malediction?", "default": "ask", "sync": "explicit",
		"text": "%s. Curse %s until the end of its next turn?" % [why, foe.name()],
		"cost": "Your Reaction and a use of Malediction (%d left)" % ch.resource_left("malediction"),
		"target_choices": choices, "min_targets": 1, "max_targets": 1, "selected_ids": [box["pick"]],
		"still": func() -> bool: return e.spells.can_react(w) and ch.resource_left("malediction") > 0 and foe.is_alive(),
		"select": select, "use": use})


# --- Horned King Patron: Crown of Horns -------------------------------------------------------------------------

## King of All: a Charisma save, or the picked effect until the start of the warlock's next turn.
func _king_of_all(c: Combatant, t: Combatant, kind: String) -> void:
	var sv := _save(c, t, &"cha", _class_dc(c, "warlock"), "King of All", {"enticement": "charmed", "terror": "frightened"}.get(kind, "") as String)
	if sv.success:
		return
	var fx := _until_start(_fx(c, "King of All (%s)" % str(AURA[kind]).get_slice(":", 0), "sh_king_of_all"), c)
	match kind:
		"enticement":
			fx.with_condition(&"charmed")
		"wickedness":
			fx.with_modifier("disadvantage", {"on": "attack"}).with_modifier("disadvantage", {"on": "check:all"})
		"terror":
			fx.with_condition(&"frightened").with_modifier("flag", {"value": "fear_flee"})
	_land(t, fx, "%s bows to the Horned King's crown: %s" % [t.name(), str(AURA[kind])], [sv.describe()])


## Dark Heart: once on each of the warlock's turns, damage it deals adds 1d8 Necrotic.
func after_damage(source: Combatant, target: Combatant, amount: int, _ps: Array = [], _dr: DamageResult = null) -> void:
	var e := enc()
	if source == null or target == null or source == target or amount <= 0 or e.current() != source or target.creature.dead:
		return
	if _effect_of(source, "sh_crown") == null or not _once_per_turn(source, "sh_dark_heart"):
		return
	var rolled := e._roll_damage_dice("1d8", false, 0, "Dark Heart")
	e.deal_damage(source, target, [{"amount": int(rolled["total"]), "type": "necrotic"}], false, "Dark Heart", [str(rolled["text"])])


# --- Occultist: the Intrusion Die ---------------------------------------------------------------------------------

## The die's size now (2 to 12), or 0 without one.
static func _die(ch: Character) -> int:
	if ch == null or not ch.resources.has("intrusion_die"):
		return 0
	return DIE_SIZES[clampi(ch.resource_left("intrusion_die"), 0, DIE_SIZES.size() - 1)]


## Its starting (largest) size.
static func _top(ch: Character) -> int:
	if ch == null or not ch.resources.has("intrusion_die"):
		return 0
	return DIE_SIZES[clampi(ch.resource_max("intrusion_die"), 0, DIE_SIZES.size() - 1)]


## Risks Intrusion: a 2 or more shrinks the die a step; a 1 grows it a step and reality fractures.
func _risk(c: Combatant, why: String) -> void:
	var ch := _ch(c)
	var size := _die(ch)
	if size <= 0:
		return
	var roll := enc().dice.roll_one(size, "Intrusion Die")
	if roll >= 2:
		ch.spend_resource("intrusion_die")
		_log("info", "%s risks Intrusion (%s): d%d rolls %d, nothing intrudes; the die shrinks to d%d" % [c.name(), why, size, roll, _die(ch)], c)
		return
	ch.restore_resource("intrusion_die")
	_log("info", "%s risks Intrusion (%s): d%d rolls 1! The die grows to d%d and reality fractures" % [c.name(), why, size, _die(ch)], c)
	_intrusion(c)


## An automatic Intrusion: the die grows a step (up to its starting size) and the table is rolled.
func _automatic(c: Combatant, why: String) -> void:
	var ch := _ch(c)
	if _die(ch) <= 0:
		return
	ch.restore_resource("intrusion_die")
	_log("info", "%s causes an Intrusion (%s); the die grows to d%d" % [c.name(), why, _die(ch)], c)
	_intrusion(c)


## Rolls the Intrusion table and queues the result for when the current spell or action is done. With Occult Presence
## the table is rolled twice and the wizard picks one or negates it for a level of Exhaustion (anyone not asked takes
## the first row).
func _intrusion(c: Combatant) -> void:
	var e := enc()
	var rows: Array[int] = [e.dice.roll_one(12, "Intrusion")]
	var offers: Array = []
	var box := {"pick": "row:%d" % rows[0]}
	if has(c, "occult_presence"):
		rows.append(e.dice.roll_one(12, "Intrusion (Occult Presence)"))
		var choices: Array = []
		for n in rows:
			choices.append({"id": "row:%d" % n, "label": "%d: %s" % [n, INTRUSIONS[n - 1]]})
		choices.append({"id": "negate", "label": "Negate it: gain 1 level of Exhaustion"})
		var select := func(ids: Array[String]) -> void:
			if not ids.is_empty():
				box["pick"] = ids[0]
		offers.append({"kind": "sh_intrusion", "reactor": c, "trigger": c.id, "title": "Intrusion: which one?",
			"text": "Reality fractures around %s (rolled %d and %d). Pick the Intrusion, or negate it with Exhaustion." % [c.name(), rows[0], rows[1]],
			"cost": "Nothing", "spends_reaction": false, "default": "ask", "target_choices": choices, "min_targets": 1, "max_targets": 1,
			"selected_ids": [box["pick"]], "select": select, "use": func() -> void: pass})
	var said: Array[String] = []
	for n in rows:
		said.append("%d (%s)" % [n, INTRUSIONS[n - 1]])
	_log("info", "Intrusion: %s" % ", ".join(said), c)
	var settle := func() -> void:
		var pick := str(box["pick"])
		if pick == "negate":
			c.creature.add_exhaustion(1)
			_log("info", "%s forces the Intrusion back and gains a level of Exhaustion" % c.name(), c)
		else:
			_apply_intrusion(c, int(pick.get_slice(":", 1)))
	e.reaction_queue.append({"kind": "gm_sh_intrusion", "reactor": c.id, "trigger": c.id, "offers": offers, "settle": settle})


## One row of the Intrusion table, for `c` (its saves use the Wizard spell save DC; "at starting size" is the top die).
func _apply_intrusion(c: Combatant, row: int) -> void:
	var e := enc()
	var ch := _ch(c)
	if c.creature.dead:
		return
	var dc := _class_dc(c, "wizard")
	var top := _top(ch)
	var tag := "Intrusion %d" % row
	match row:
		1:
			_land(c, _until_end(_fx(c, tag, "sh_intrusion"), c).with_modifier("flag", {"value": "dazed"}),
				"Something whispers behind %s: only one of action, Bonus Action or move a turn" % c.name())
		2:
			for o in e.living():
				if o == c or e.distance(c, o) <= 30:
					_land(o, _until_end(_fx(c, tag, "sh_intrusion_warp"), c).with_modifier("speed_percent", {"value": 50}),
						"Space melts around %s: Speed halved" % o.name())
		3:
			var near: Combatant = null
			for o in e.living():
				if o != c and not o.is_down() and e.distance(c, o) <= 60 and (near == null or e.distance(c, o) < e.distance(c, near)):
					near = o
			if near == null:
				_log("info", "%s: nobody is near enough to drain" % tag, c)
			elif not _save(c, near, &"con", dc, tag).success:
				var a := e.dice.roll_one(top, tag)
				var b := e.dice.roll_one(top, tag)
				var dr := e.deal_damage(c, near, [{"amount": a + b, "type": "necrotic"}], false, tag, ["2d%d: %d + %d" % [top, a, b]])
				if dr != null and dr.final > 0:
					e.class_features._heal(c, c, dr.final, tag)
		4:
			for o in e.living():
				if o == c or (not o.is_down() and e.can_see(o, c)):
					if not _save(c, o, &"wis", dc, tag, "frightened").success:
						_land(o, _until_end(_fx(c, tag + " (the tear)", "sh_intrusion_tear"), c).with_condition(&"frightened"),
							"%s is Frightened by the tear in reality" % o.name())
		5:
			var n := c.creature.proficiency_bonus()
			var mod := c.creature.ability_mod(&"int")
			# Intelligence carries the attack (the spell attack bonus); its modifier is taken back off the damage.
			var dice := "%dd%d" % [n, top] + ("-%d" % mod if mod > 0 else "")
			_land(c, _for_minutes(_fx(c, "Alien Limb", "sh_alien_limb"), c, 1).with_modifier("weapon_override",
				{"items": ["unarmed_strike"], "die": dice, "ability": "int", "damage_type": "acid"}),
				"%s's arm twists into something alien: Unarmed Strikes with Intelligence for %dd%d Acid (1 minute)" % [c.name(), n, top])
		6:
			_land(c, _until_end(_fx(c, tag, "sh_intrusion"), c).with_condition(&"blinded"), "Alien landscapes blind %s" % c.name())
		7:
			_land(c, _until_end(_fx(c, tag, "sh_intrusion"), c).with_condition(&"incapacitated"), "Unnatural thoughts leave %s Incapacitated" % c.name())
		8:
			var a8 := e.dice.roll_one(top, tag)
			var b8 := e.dice.roll_one(top, tag)
			e.deal_damage(c, c, [{"amount": a8 + b8, "type": "psychic"}], false, tag, ["2d%d: %d + %d" % [top, a8, b8]])
			if not c.creature.dead:
				_land(c, _for_minutes(_fx(c, "Terrible Clarity", "sh_intrusion_clarity"), c, 1).with_modifier("spell_dc", {"value": 2}),
					"%s sees with terrible clarity: spell save DC +2 for 1 minute" % c.name())
		9:
			for l in range(5, 0, -1):
				if ch != null and ch.expended_slots(l) > 0 and ch.recover_slot(l):
					_log("info", "%s regains a level %d spell slot (%s)" % [c.name(), l, tag], c)
					e.deal_damage(c, c, [{"amount": 2 * l, "type": "necrotic", "ignore_resistance": true, "ignore_source": tag}], false, tag)
					return
			_log("info", "%s: no spent slot to regain" % tag, c)
		10:
			_land(c, _for_minutes(_fx(c, "Space Pulses", "sh_pulse"), c, 1), "Space begins to pulse around %s (1 minute)" % c.name())
			_pulse(c)
		11:
			# An hour: counted in minutes, so it outlives the fight (Effect.Ends.MINUTES).
			var whispers := _fx(c, "Hateful Whispers", "sh_intrusion_whispers").lasting({"kind": "hours", "amount": 1})
			whispers.turn_owner_id = c.id
			_land(c, whispers.with_modifier("disadvantage", {"on": "check:wis"}) \
				.with_modifier("disadvantage", {"on": "save:wis"}),
				"Hateful whispers fill %s's head: Disadvantage on Wisdom checks and saves for 1 hour" % c.name())
		12:
			_from_beyond(c)


## Intrusion 10's pulse: `c` and every creature within 15 ft fall Prone.
func _pulse(c: Combatant) -> void:
	var e := enc()
	for o in e.living():
		if (o == c or e.distance(c, o) <= 15) and not o.creature.has_condition(&"prone") and o.creature.add_condition(&"prone", "Space Pulses"):
			_log("condition", "A pulse of space knocks %s Prone" % o.name(), o)
			e.events.append({"type": "condition", "id": o.id})


## Intrusion 12: an Aberration or Fiend of CR up to the Wizard level steps through within 30 ft. A d6 sets its mood
## (designer's call): 1-3 it attacks everyone, 4-5 it ignores everyone and leaves, 6 it serves the wizard for 1 minute.
func _from_beyond(c: Combatant) -> void:
	var e := enc()
	var ch := _ch(c)
	var cap := float(ch.class_level_of("wizard") if ch != null else 1)
	var pool: Array[Dictionary] = []
	for m in Compendium.shared().all("monsters"):
		if str(m.get("type", "")).to_lower() in ["aberration", "fiend"] and not bool(m.get("summon", false)) and _cr(m.get("cr", 99)) <= cap:
			pool.append(m)
	if pool.is_empty():
		_log("info", "Something pushes at reality around %s, but nothing comes through" % c.name(), c)
		return
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	var data := pool[e.dice.roll_one(pool.size(), "Intrusion: what comes") - 1]
	var mood := e.dice.roll_one(6, "Intrusion: its mood")
	if mood in [4, 5]:
		_log("info", "A %s steps out of nowhere beside %s, looks about with contempt and leaves" % [data.get("name", "creature"), c.name()], c, ["d6 for its mood: %d" % mood])
		return
	var m2 := Monster.from_data(data, e.dice)
	var spot := e.spells._free_cell_near(c.cell, CombatGrid.size_cells_for(m2.size))
	if spot.x < 0 or e.grid.distance_ft(c.cell, c.size_cells, spot, 1) > 30:
		_log("info", "A %s tries to step through beside %s, but there is no room" % [data.get("name", "creature"), c.name()], c)
		return
	var friendly := mood == 6
	# Hostile to everyone: a side of its own (Combatant.hostile_to sets it against both the party and its foes).
	var sc := e.add(m2, ((&"guest" if c.side == &"party" else c.side) if friendly else &"intruder"), spot)
	sc.set_meta("summoner", c.id)
	sc.set_meta("vanishes", true)
	if friendly:
		sc.controller = c.controller
		sc.set_meta("sh_leaves_round", e.round_no + 10)
	if e.state == Encounter.State.ACTIVE:
		e.insert_after(c, sc)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": spot, "caster": c.id})
	_log("info", "A %s steps through a rent in reality beside %s: %s" % [m2.name, c.name(), ("it serves %s for 1 minute" % c.name()) if friendly else "it attacks everyone in sight"], c,
		["d6 for its mood: %d" % mood])


static func _cr(v: Variant) -> float:
	var s := str(v)
	if s.contains("/"):
		return float(s.get_slice("/", 0)) / maxf(1.0, float(s.get_slice("/", 1)))
	return float(s)


## A friendly creature from beyond leaves when its minute is up.
func round_started(round_no: int) -> void:
	var e := enc()
	for o: Combatant in e.combatants.duplicate():
		if o.has_meta("sh_leaves_round") and round_no >= int(o.get_meta("sh_leaves_round")) and o.is_alive() and not o.has_meta("left_fight"):
			_log("info", "%s's minute is up: it slips back beyond reality" % o.name(), o)
			e.movement.leave_grid(o, "vanished")


## Intrusion 10 pulses again at the end of each of the wizard's turns; a spell's markers never outlast the turn.
func turn_end(c: Combatant) -> void:
	if _effect_of(c, "sh_pulse") != null:
		_pulse(c)
	c.remove_meta("sh_dissolving")
	c.remove_meta("sh_vitriol")


## Occult Presence's benefit now (its build choice).
static func _presence(ch: Character) -> String:
	for d in ch.choice_defs:
		if (d.key.ends_with("occult_presence") or d.key.ends_with("benefit")) and not d.picks.is_empty() and str(d.picks[0]) in BENEFITS:
			return str(d.picks[0])
	return ""


## Swaps the benefit: its build choice changes (it would at the next Long Rest anyway) and the sheet is rebuilt,
## keeping what the fight and the day have spent.
func _set_presence(c: Combatant, pick: String) -> void:
	var ch := _ch(c)
	for d in ch.choice_defs:
		if (d.key.ends_with("occult_presence") or d.key.ends_with("benefit")) and (d.picks.is_empty() or str(d.picks[0]) in BENEFITS):
			ch.choices()[d.key] = [pick]
	CmPart.refresh_keeping(ch)
	_log("info", "%s's presence shifts: %s" % [c.name(), pick.replace("_", " ").capitalize()], c)
	enc().events.append({"type": "condition", "id": c.id})


## Reality Tear's spell (its build choice), or "".
static func _tear_spell(ch: Character) -> String:
	if ch == null:
		return ""
	for d in ch.choice_defs:
		if (d.key.ends_with("reality_tear") or d.key.ends_with("tear_spell")) and not d.picks.is_empty():
			return str(d.picks[0])
	return ""


# --- Riders armed before casting --------------------------------------------------------------------------------

func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := _ch(c)
	if ch == null:
		return out
	if has(c, "intrusion") and _die(ch) > 0:
		out.append({"id": RISKS["overwhelming_mind"], "label": "Overwhelming Mind", "why": "",
			"sub": "risk Intrusion (d%d) · next slot spell: one target has Disadvantage on its first save" % _die(ch)})
		out.append({"id": RISKS["seeking_eye"], "label": "Seeking Eye", "why": "",
			"sub": "risk Intrusion (d%d) · next slot spell: Advantage on its first attack roll" % _die(ch)})
		var tear := _tear_spell(ch)
		if has(c, "reality_tear") and tear != "":
			out.append({"id": "sh_tear_unbound", "label": "Reality Tear: no Concentration", "why": "",
				"sub": "risk Intrusion (d%d) · %s lasts up to 1 minute without Concentration" % [_die(ch), Compendium.shared().display_name("spells", tear)]})
	if has(c, "quintessence"):
		var q := quintessence(ch)
		out.append({"id": "sh_vitriol", "label": "Vitriolic Enhancement", "why": "" if q > 0 else "No Quintessence",
			"sub": "1 Quintessence (%d) · the next damaging spell deals Force" % q})
		if has(c, "albedo"):
			for n in range(1, _albedo_cap(c) + 1):
				out.append({"id": "sh_albedo_%d" % n, "label": "Albedo +%d" % n, "why": "" if q >= n else "Not enough Quintessence",
					"sub": "%d Quintessence (%d) · the next slot spell %d level%s higher" % [n, q, n, "" if n == 1 else "s"]})
	return out


## Albedo's limit per spell: half the Proficiency Bonus, rounded up.
static func _albedo_cap(c: Combatant) -> int:
	return ceili(c.creature.proficiency_bonus() / 2.0)


## The armed riders take hold as a spell resolves: Overwhelming Mind or Seeking Eye (a slot spell; Intrusion risked),
## Albedo's higher slot, Vitriolic Enhancement's Force, and Dissolution's watch (Reality Tear: skips_concentration).
func before_resolve(ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	if ch == null:
		return
	var s := ctx["s"] as Dictionary
	var slotted := bool(ctx.get("spent_slot", false))
	if slotted and has(c, "intrusion") and ("sh_risk_mind" in c.armed or "sh_risk_eye" in c.armed):
		var mind := "sh_risk_mind" in c.armed
		c.armed.erase("sh_risk_mind")
		c.armed.erase("sh_risk_eye")
		if mind:
			var first := _first_target(ctx)
			if first != null:
				var key := "save_vs:spell:%s" % c.id
				var om := _until_end(_fx(c, "Overwhelming Mind", "sh_overwhelming_mind"), c).with_modifier("disadvantage", {"on": key})
				om.consume_on = [key]
				_land(first, om, "%s's alien will presses on %s: Disadvantage on the first save against %s" % [c.name(), first.name(), s["name"]])
		else:
			var eye := _until_end(_fx(c, "Seeking Eye", "sh_seeking_eye"), c).with_modifier("advantage", {"on": "attack:spell"})
			eye.consume_on = ["attack:spell"]
			_land(c, eye, "%s's eye seeks beyond: Advantage on the first attack roll of %s" % [c.name(), s["name"]])
		_risk(c, "Overwhelming Mind" if mind else "Seeking Eye")
	if slotted and has(c, "albedo"):
		for n in range(_albedo_cap(c), 0, -1):
			if not "sh_albedo_%d" % n in c.armed:
				continue
			for k in range(1, 10):
				c.armed.erase("sh_albedo_%d" % k)
			var raise := mini(mini(n, quintessence(ch)), 9 - int(ctx["slot"]))
			if raise > 0:
				_spend_quintessence(ch, raise)
				ctx["slot"] = int(ctx["slot"]) + raise
				_log("info", "%s purifies %d Quintessence: %s is cast as if with a level %d slot (Albedo)" % [c.name(), raise, s["name"], int(ctx["slot"])], c)
			break
	if "sh_vitriol" in c.armed and has(c, "quintessence") and quintessence(ch) > 0 and s.get("damage") is Array and not (s["damage"] as Array).is_empty():
		c.armed.erase("sh_vitriol")
		var ty := str(((s["damage"] as Array)[0] as Dictionary).get("type", ""))
		if ty != "" and ty != "force":
			_spend_quintessence(ch, 1)
			c.set_meta("sh_vitriol", ty)
			_log("info", "%s adds Quintessence to %s: its %s damage becomes Force (Vitriolic Enhancement)" % [c.name(), s["name"], ty.capitalize()], c)
	if str(s.get("id", "")) == "dissolution" and has(c, "quintessence"):
		c.set_meta("sh_dissolving", true)


## Reality Tear's spell with the rider armed: no Concentration (so none the wizard holds ends), at most 1 minute, and
## Intrusion risked.
func skips_concentration(c: Combatant, s: Dictionary, _free: bool) -> Dictionary:
	if not "sh_tear_unbound" in c.armed or not has(c, "reality_tear") or str(s.get("id", "")) != _tear_spell(_ch(c)):
		return {}
	c.armed.erase("sh_tear_unbound")
	_risk(c, "Reality Tear")
	var d := s.get("duration", {}) as Dictionary
	if str(d.get("kind", "")) == "rounds" and int(d.get("amount", 1)) <= Effect.ROUNDS_PER_MINUTE:
		return {"kind": "rounds", "amount": int(d.get("amount", 1))}
	return {"kind": "minutes", "amount": 1}


## The creature Overwhelming Mind presses on: the spell's first target, or the first foe in its area.
func _first_target(ctx: Dictionary) -> Combatant:
	var c := ctx["c"] as Combatant
	for t: Variant in ctx.get("targets", []):
		if t is Combatant and t != c:
			return t as Combatant
	var cells: Array[Vector2i] = []
	cells.assign(ctx.get("cells", []))
	if not cells.is_empty():
		for v in enc().spells._area_victims(c, ctx["s"] as Dictionary, cells):
			if v.hostile_to(c):
				return v
	return null


## A spell's markers end with it; Reality Tear's free casting brings an automatic Intrusion.
func after_cast(c: Combatant, s: Dictionary, _slot: int, free: bool = false, _ctx: Dictionary = {}) -> void:
	c.remove_meta("sh_dissolving")
	c.remove_meta("sh_vitriol")
	var ch := _ch(c)
	if free and int(s.get("level", 0)) > 0 and has(c, "reality_tear") and str(s.get("id", "")) == _tear_spell(ch):
		_automatic(c, "Reality Tear's free casting")


## Vitriolic Enhancement: the marked damage type of the caster's spell becomes Force.
func _vitriol(source: Combatant, ps: Array) -> void:
	if source == null or not source.has_meta("sh_vitriol"):
		return
	var ty := str(source.get_meta("sh_vitriol"))
	for raw: Variant in ps:
		var p := raw as Dictionary
		if str(p.get("type", "")) == ty and bool(p.get("spell", false)):
			p["type"] = "force"


# --- Philosopher: Quintessence ------------------------------------------------------------------------------------

## Measures of Quintessence `ch` holds (kept in its build, so it outlives fights and rests).
static func quintessence(ch: Character) -> int:
	return int(ch.build.get("quintessence", 0)) if ch != null else 0


## How much it can hold: twice the Intelligence modifier, at least 2.
static func quintessence_cap(ch: Character) -> int:
	return maxi(2, 2 * ch.ability_mod(&"int"))


static func _spend_quintessence(ch: Character, n: int) -> void:
	ch.build["quintessence"] = maxi(0, quintessence(ch) - n)


## Dissolution destroys a creature it drops; a Small or larger body leaves a measure of Quintessence (past the cap the
## oldest measure goes). The body's loot stays where it fell.
func on_drop(by: Combatant, target: Combatant) -> void:
	if by == null or target == null or by == target or not by.has_meta("sh_dissolving"):
		return
	var ch := _ch(by)
	if ch == null:
		return
	if target.creature is Monster:
		target.creature.dead = true
	_log("info", "%s dissolves into crystalline powder (Dissolution)" % target.name(), by)
	if Creature.SIZES.find(target.creature.size) >= Creature.SIZES.find(&"small"):
		ch.build["quintessence"] = mini(quintessence_cap(ch), quintessence(ch) + 1)
		_log("info", "%s gathers a measure of Quintessence (%d of %d)" % [by.name(), quintessence(ch), quintessence_cap(ch)], by)


## Quintessence paying a spell's costly Material component, 100 gp a measure: true when it does (with `spend` false,
## when it could).
func pays_component(c: Combatant, s: Dictionary, spend: bool) -> bool:
	var ch := _ch(c)
	if ch == null or not has(c, "quintessence"):
		return false
	var cc := Character.costly_component(s)
	if cc.is_empty() or ch.component_why(s) == "":
		return false
	var need := ceili(float(cc["cost_gp"]) / 100.0)
	if quintessence(ch) < need:
		return false
	if spend:
		_spend_quintessence(ch, need)
		_log("info", "%s spends %d Quintessence as the Material component of %s" % [c.name(), need, s.get("name", "")], c)
	return true
