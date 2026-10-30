class_name CmWarriors
extends CmPart
## The Crooked Moon's code for three of the book's subclasses (chapter 3): Path of the Experiment, Oath of Castigation and Sinner: the parts of them data can't say.
## CrookedFeatures forwards every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start
## "wr_".
##
## Path of the Experiment: a Rage is entered with a serum picked on the hotbar (one Rage entry per serum, the compound
## from level 6 as the entry's right-click choice), a Bonus Action switches it, and Reactive Catalyst enters the Rage
## on its own when damage or a condition lands. Oath of Castigation: Castigate and Incite are data recipes; the
## shackles' flare and Incite's Frighten are Bonus Actions here, and Kindling Aura rides on the Aura of Protection.
## Sinner: Hex Slinger reads the first two Sneak Attack dice (the marked ones) and lays the jinx; the jinx weapon is a
## build choice (a jinx pistol, or Force on the weapon in hand).

const PREFIX := "wr_"

## The serums (Volatile Serum's options, by their data ids) and the compounds (Augmentation Compounds').
const SERUMS: Array[String] = ["ferocity", "path_of_the_experiment_monstrosity", "reconstruction"]
const COMPOUNDS: Array[String] = ["stimulated_senses", "maddening_fumes", "corrosive_expulsion"]
const NAMES := {"ferocity": "Ferocity", "path_of_the_experiment_monstrosity": "Monstrosity", "reconstruction": "Reconstruction",
	"stimulated_senses": "Stimulated Senses", "maddening_fumes": "Maddening Fumes", "corrosive_expulsion": "Corrosive Expulsion"}
## The conditions Reactive Catalyst answers, and that entering the Rage ends.
const CATALYST_CONDITIONS: Array[StringName] = [&"blinded", &"deafened", &"poisoned", &"stunned"]
const PHYSICAL: Array[String] = ["bludgeoning", "piercing", "slashing"]
const JINX_NAMES := {"snake_eyes": "Snake Eyes", "nightmare": "The Nightmare", "whiskey_bottle": "Whiskey Bottle",
	"cheap_shot": "Cheap Shot", "withered_arm": "Withered Arm", "bad_luck": "Bad Luck", "dead_man": "Dead Man"}


func prefix() -> String:
	return PREFIX


func cf() -> ClassFeatures:
	return enc().class_features


## The effect from `source` on `c` (the first), or null.
static func _effect(c: Combatant, source: String) -> Effect:
	for fx: Effect in c.creature.effects:
		if fx.source_id == source:
			return fx
	return null


# --- The hotbar ---------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], _aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	if has(c, "volatile_serum"):
		_experiment_list(c, ch, out, bw)
	if has(c, "castigate") or has(c, "incite"):
		_castigation_list(c, out, bw)


## Rage with a serum (the engine's plain Rage entry gives way to one per serum), switching serums while raging, and
## Corrosive Expulsion in place of an attack.
func _experiment_list(c: Combatant, ch: Character, out: Array[Dictionary], bw: String) -> void:
	var compounds := has(c, "augmentation_compounds")
	var choices: Array = []
	if compounds:
		for k: String in COMPOUNDS:
			choices.append({"value": k, "label": str(NAMES[k])})
	if not ClassFeatures.raging(c):
		var rw := _first(bw, _res_why(c, "rage"))
		for i in range(out.size() - 1, -1, -1):
			if str(out[i]["id"]) == "feat:cf:rage":
				rw = str(out[i]["why"])
				out.remove_at(i)
		if rw == "" and str(ch.armor_situation().get("armor", "")) == "heavy":
			rw = "Not in Heavy armor"
		for s: String in SERUMS:
			var en := _act("rage:" + s, "Rage: %s" % NAMES[s], "+%d damage · %s serum" % [ClassFeatures.rage_bonus(c), NAMES[s]], "bonus", rw, "none",
				"Bonus Action: enter your Rage and inject the %s serum. %s" % [NAMES[s], _serum_help(s)])
			if compounds:
				en["choices"] = choices
				en["choice_label"] = "Compound"
			out.append(en)
		return
	var now := _serum(c)
	for s2: String in SERUMS:
		var sw := bw
		if sw == "" and s2 == now and not compounds:
			sw = "Already injected"
		var en2 := _act("serum:" + s2, "Serum: %s" % NAMES[s2], "Bonus Action" + (" · active" if s2 == now else ""), "bonus", sw, "none",
			"Bonus Action: switch to the %s serum. %s" % [NAMES[s2], _serum_help(s2)])
		if compounds:
			en2["choices"] = choices
			en2["choice_label"] = "Compound"
		out.append(en2)
	if _compound(c) == "corrosive_expulsion":
		var n := ClassFeatures.rage_bonus(c)
		var ew := enc().features_attack_why(c)
		out.append(_act("expel:cone", "Corrosive Expulsion (Cone)", "15 ft · %dd8 Acid" % n, "attack", ew, "direction",
			"Replaces one attack: a 15-ft Cone of caustic spray, Dex save (DC %d), half on a success." % dc_of(c, &"con")))
		out.append(_act("expel:line", "Corrosive Expulsion (Line)", "30 ft · %dd8 Acid" % n, "attack", ew, "direction",
			"Replaces one attack: a 30-ft × 5-ft Line of caustic spray, Dex save (DC %d), half on a success." % dc_of(c, &"con")))


static func _serum_help(s: String) -> String:
	return str({"ferocity": "Ignore Difficult Terrain; melee and Unarmed hits can also Cleave.",
		"path_of_the_experiment_monstrosity": "+5 ft reach, Large if there's room; once a turn add the Rage Damage bonus to a missed Strength attack.",
		"reconstruction": "Spend a Hit Point Die now and at each turn start to heal (extra as Temporary Hit Points); Acid or Fire stops it next turn."}[s])


## The shackles' flare while anyone is bound by your Castigate, and Incite's Frighten while Incite lasts.
func _castigation_list(c: Combatant, out: Array[Dictionary], bw: String) -> void:
	if has(c, "castigate"):
		var bound := _shackled(c)
		if not bound.is_empty():
			out.append(_act("flare", "Castigate: Flare", "2d6 Fire to %d bound" % bound.size(), "bonus", bw, "none",
				"Bonus Action: the fiery shackles flare; each creature bound by your Castigate takes 2d6 Fire damage."))
	if has(c, "incite") and _effect(c, "incite") != null:
		out.append(_act("incite", "Incite: Frighten", "Cha save · 1 minute", "bonus", bw, "creature",
			"Bonus Action: a creature you can see within 10 ft makes a Charisma save (DC %d) or is Frightened of you for 1 minute; it ends if the creature takes damage or you use this again." % cf()._spell_dc(c, "paladin"), 10))


func perform(c: Combatant, id: String, t: Combatant, _cell: Vector2i, point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if ch == null:
		return CombatResult.fail("Not available")
	var head := id.trim_prefix(PREFIX).get_slice(":", 0)
	var arg := id.get_slice(":", 1) if id.contains(":") else ""
	match head:
		"rage":
			if not arg in SERUMS or not has(c, "volatile_serum"):
				return CombatResult.fail("Not available")
			var why := _first(e._bonus_check(c), _res_why(c, "rage"))
			if why == "" and str(ch.armor_situation().get("armor", "")) == "heavy":
				why = "Not in Heavy armor"
			if why == "" and ClassFeatures.raging(c):
				why = "Already raging"
			if why != "":
				return CombatResult.fail(why)
			c.set_meta("wr_pick", {"serum": arg, "compound": _compound_pick(c)})
			return cf()._start_rage(c, "")
		"serum":
			if not arg in SERUMS or not ClassFeatures.raging(c):
				return CombatResult.fail("Only while raging")
			var bw := e._bonus_check(c)
			if bw != "":
				return CombatResult.fail(bw)
			if arg == _serum(c) and not has(c, "augmentation_compounds"):
				return CombatResult.fail("Already injected")
			c.bonus_available = false
			_inject(c, arg, _compound_pick(c), true)
			return CombatResult.new()
		"expel":
			return _expel(c, arg, point)
		"flare":
			return _flare(c)
		"incite":
			return _incite(c, t)
	return CombatResult.fail("Not available")


# --- Path of the Experiment ---------------------------------------------------------------------------------------

## The compound a Rage or serum switch takes: the right-click choice, else the last one, else Maddening Fumes; "" before
## level 6.
func _compound_pick(c: Combatant) -> String:
	if not has(c, "augmentation_compounds"):
		return ""
	if choice_in in COMPOUNDS:
		return choice_in
	return str(c.get_meta("wr_compound", "maddening_fumes"))


## The serum in `c`'s veins ("" when not raging).
func _serum(c: Combatant) -> String:
	var fx := _effect(c, "wr_serum")
	return str(fx.data.get("serum", "")) if fx != null and ClassFeatures.raging(c) else ""


## The compound active in `c` ("" when not raging).
func _compound(c: Combatant) -> String:
	var fx := _effect(c, "wr_compound")
	return str(fx.data.get("compound", "")) if fx != null and ClassFeatures.raging(c) else ""


## A Rage just began (any way: the hotbar, Relentless Rage, Reactive Catalyst): the serum goes in. A fresh Rage takes
## the hotbar's pick (or the last serum) with its activation; one put back by Relentless Rage keeps the serum it had.
## Reactive Catalyst: entering the Rage ends Blinded, Deafened, Poisoned and Stunned.
func _rage_started(c: Combatant) -> void:
	var pick := c.get_meta("wr_pick", {}) as Dictionary
	var fresh := c.has_meta("wr_pick") or not c.has_meta("rage_effect")
	c.remove_meta("wr_pick")
	if has(c, "reactive_catalyst"):
		for cond in CATALYST_CONDITIONS:
			if c.creature.has_condition(cond):
				enc().spells.cure(c, cond)
				_log("info", "%s's implants flush out %s (Reactive Catalyst)" % [c.name(), str(cond).capitalize()], c)
	var serum := str(pick.get("serum", c.get_meta("wr_serum", "ferocity")))
	var compound := str(pick.get("compound", c.get_meta("wr_compound", "")))
	if not has(c, "augmentation_compounds"):
		compound = ""
	if not fresh and _effect(c, "wr_serum") != null:
		return
	_inject(c, serum, compound, fresh)


## Injects `serum` (and `compound` from level 6), replacing what was in: its effect while the Rage lasts.
## `fresh`: an activation (Reconstruction's first Hit Point Die).
func _inject(c: Combatant, serum: String, compound: String, fresh: bool) -> void:
	_clear_serum(c)
	c.set_meta("wr_serum", serum)
	var fx := Effect.new("%s serum" % NAMES[serum], &"feature", "wr_serum")
	fx.caster_id = c.id
	fx.ends = Effect.Ends.NEVER
	fx.data["serum"] = serum
	match serum:
		"ferocity":
			fx.with_modifier("flag", {"value": "ignore_difficult_terrain"})
		"path_of_the_experiment_monstrosity":
			# +5 ft reach for every melee attack (weapons, Unarmed Strikes) and Opportunity Attacks.
			fx.with_modifier("reach", {"value": 5})
			_grow(c, fx)
		"reconstruction":
			fx.with_modifier("flag", {"value": "wr_reconstruction"})
	c.creature.add_effect(fx)
	_log("info", "%s injects the %s serum" % [c.name(), NAMES[serum]], c)
	if compound in COMPOUNDS:
		c.set_meta("wr_compound", compound)
		var cx := Effect.new("%s compound" % NAMES[compound], &"feature", "wr_compound")
		cx.caster_id = c.id
		cx.ends = Effect.Ends.NEVER
		cx.data["compound"] = compound
		if compound == "stimulated_senses":
			var had := c.creature.sense_range("blindsight")
			cx.with_modifier("sense", {"kind": "blindsight", "value": had + 30})
		else:
			cx.with_modifier("flag", {"value": "wr_" + compound})
		c.creature.add_effect(cx)
		_log("info", "%s activates the %s compound" % [c.name(), NAMES[compound]], c)
	enc().events.append({"type": "condition", "id": c.id})
	if serum == "reconstruction" and fresh:
		_reconstruct(c)


func _clear_serum(c: Combatant) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id in ["wr_serum", "wr_compound"]:
			c.creature.remove_effect(fx)


## The serum and compound go once the Rage has ended.
func _tidy(c: Combatant) -> void:
	if not ClassFeatures.raging(c) and (_effect(c, "wr_serum") != null or _effect(c, "wr_compound") != null):
		_clear_serum(c)


## Monstrosity: a creature smaller than Large becomes Large when a 10-ft square round it is clear (it shrinks back when
## the serum goes).
func _grow(c: Combatant, fx: Effect) -> void:
	var e := enc()
	var steps := Creature.SIZES.find(&"large") - Creature.SIZES.find(c.creature.size)
	if steps <= 0:
		return
	var anchor := e.feature_actions._large_anchor(c)
	if anchor.x < 0:
		_log("info", "%s has no room to grow (Monstrosity)" % c.name(), c)
		return
	c.cell = anchor
	e.spells._resize(c, steps, fx)


## Reconstruction: spend and roll the largest Hit Point Die left; heal roll + Con (at least 1), the rest beyond the
## maximum as Temporary Hit Points.
func _reconstruct(c: Combatant) -> void:
	var e := enc()
	var ch := _ch(c)
	var best := 0
	var pool := ch.hit_dice()
	for die: String in pool:
		var entry := pool[die] as Dictionary
		if int(entry["spent"]) < int(entry["total"]) and int(die) > best:
			best = int(die)
	if best == 0:
		_log("info", "%s has no Hit Point Dice left for Reconstruction" % c.name(), c)
		return
	ch.hit_dice_spent[str(best)] = int(ch.hit_dice_spent.get(str(best), 0)) + 1
	var roll := e.dice.roll_one(best, "Reconstruction")
	var amount := maxi(1, roll + c.creature.ability_mod(&"con"))
	var room := maxi(0, c.creature.max_hp() - c.creature.hp)
	_log("info", "%s spends a Hit Point Die for Reconstruction: d%d rolls %d, %d in all" % [c.name(), best, roll, amount], c)
	if room > 0:
		cf()._heal(c, c, mini(amount, room), "Reconstruction")
	if amount > room:
		cf()._temp(c, amount - room, "Reconstruction")


## Reactive Catalyst: `c` enters its Rage with its Reaction (a Rage use as usual), the serum it last used going in.
func _catalyst(c: Combatant, why: String) -> void:
	var keep := c.bonus_available
	c.reaction_available = false
	c.set_meta("wr_pick", {"serum": str(c.get_meta("wr_serum", "reconstruction")), "compound": str(c.get_meta("wr_compound", "maddening_fumes"))})
	_log("reaction", "%s's implants flood it with stimulants as %s (Reactive Catalyst)" % [c.name(), why], c)
	cf()._start_rage(c, "")
	c.bonus_available = keep


## Whether Reactive Catalyst can fire for `c` now: not raging, a Rage use and its Reaction left, not in Heavy armor.
func _catalyst_ready(c: Combatant) -> bool:
	var ch := _ch(c)
	if ch == null or not has(c, "reactive_catalyst") or not allowed(c, "reactive_catalyst") or ClassFeatures.raging(c):
		return false
	if c.creature.hp <= 0 or ch.resource_left("rage") <= 0 or not enc().spells.can_react(c):
		return false
	return str(ch.armor_situation().get("armor", "")) != "heavy"


## Corrosive Expulsion: one attack becomes a 15-ft Cone or a 30-ft Line of acid, Dex save (8 + Con + PB), Rage Damage
## bonus d8s, half on a success.
func _expel(c: Combatant, shape: String, point: Vector2) -> CombatResult:
	var e := enc()
	if _compound(c) != "corrosive_expulsion":
		return CombatResult.fail("Only with the Corrosive Expulsion compound")
	var why := e.features_attack_why(c)
	if why != "":
		return CombatResult.fail(why)
	e.use_one_attack(c)
	var dir := (point - e.center_of(c)).normalized() if point != Vector2.INF else c.facing
	var cells := e.grid.cone_from(c.cell, c.size_cells, e.center_of(c) + dir, 15) if shape == "cone" \
		else e.grid.area_cells("line", 30, CombatGrid.line_origin(c.cell, c.size_cells, dir), dir, 5)
	var dice := "%dd8" % ClassFeatures.rage_bonus(c)
	var dc := dc_of(c, &"con")
	var rolled := e._roll_damage_dice(dice, false, 0, "Corrosive Expulsion")
	e.events.append({"type": "spell", "caster": c.id, "spell": "corrosive_expulsion", "cells": cells, "targets": []})
	_log("spell", "%s sprays caustic chemicals (%s, Dex DC %d)" % [c.name(), dice, dc], c)
	for o in e.spells.creatures_in(cells):
		if o == c:
			continue
		var test := o.creature.roll_save(e.dice, &"dex", dc, [], [], "Dexterity save vs Corrosive Expulsion (%s)" % o.name())
		var amount := int(rolled["total"]) / (2 if test.success else 1)
		if o.creature.has_flag("evasion"):
			amount = 0 if test.success else int(rolled["total"]) / 2
		e.deal_damage(c, o, [{"amount": amount, "type": "acid"}], false, "Corrosive Expulsion", [test.describe(), str(rolled["text"])])
	cf().kept_rage(c)
	return CombatResult.new()


## The barbarians whose Maddening Fumes are on.
func _fumers() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for b in enc().living():
		if _compound(b) == "maddening_fumes" and b.creature.hp > 0:
			out.append(b)
	return out


func _in_fumes(b: Combatant, t: Combatant) -> bool:
	return enc().grid.in_emanation(b.cell, b.size_cells, 30, t.cell, t.size_cells, b.altitude, t.altitude)


## Maddening Fumes halve an enemy's Speed while it's inside: what movement it has left is halved once a turn, as its
## turn starts there or as it steps in.
func _fumes_slow(t: Combatant, b: Combatant) -> void:
	if _once_per_turn(t, "wr_fumes_slow"):
		t.movement_left /= 2
		_log("info", "%s wades through %s's fumes: Speed halved" % [t.name(), b.name()], t)


## An enemy starting its turn in the fumes: its Speed halves, and on a failed Wis save it has Disadvantage on attacks
## against anyone but the barbarian until its next turn starts.
func _fumes_turn_start(t: Combatant) -> void:
	for b in _fumers():
		if not t.hostile_to(b) or not _in_fumes(b, t):
			continue
		_fumes_slow(t, b)
		if not cf()._save(t, &"wis", dc_of(b, &"con"), "Maddening Fumes"):
			var fx := Effect.new("Maddened (%s)" % b.name(), &"feature", "wr_fumes")
			fx.caster_id = b.id
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = t.id
			fx.with_modifier("flag", {"value": "wr_maddened"})
			t.creature.add_effect(fx)
			_log("condition", "%s can think only of %s (Maddening Fumes)" % [t.name(), b.name()], t)


# --- Oath of Castigation ------------------------------------------------------------------------------------------

## The creatures bound by `c`'s Castigate (its data recipe's shackles).
func _shackled(c: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in enc().living():
		if o.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "castigate" and fx.caster_id == c.id):
			out.append(o)
	return out


## Castigate's flare: a Bonus Action, 2d6 Fire to every creature the shackles bind.
func _flare(c: Combatant) -> CombatResult:
	var e := enc()
	var bw := e._bonus_check(c)
	if bw != "":
		return CombatResult.fail(bw)
	var bound := _shackled(c)
	if bound.is_empty():
		return CombatResult.fail("No one is shackled")
	c.bonus_available = false
	var rolled := e._roll_damage_dice("2d6", false, 0, "Castigate flare")
	_log("spell", "%s makes the fiery shackles flare" % c.name(), c)
	for o in bound:
		e.deal_damage(c, o, [{"amount": int(rolled["total"]), "type": "fire"}], false, "Castigate", ["Shackles flare 2d6: %s" % rolled["text"]])
	return CombatResult.new()


## Incite's Bonus Action: a creature within 10 ft makes a Cha save or is Frightened of the paladin for 1 minute, ending
## when it takes damage or the paladin uses this again.
func _incite(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if _effect(c, "incite") == null:
		return CombatResult.fail("Only while Incite lasts")
	var bw := e._bonus_check(c)
	if bw != "":
		return CombatResult.fail(bw)
	if t == null or t == c or e.distance(c, t) > 10 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 10 ft")
	c.bonus_available = false
	for o in e.combatants:
		for fx: Effect in o.creature.effects.duplicate():
			if fx.source_id == "wr_incite" and fx.caster_id == c.id:
				o.creature.remove_effect(fx)
	if cf()._save(t, &"cha", cf()._spell_dc(c, "paladin"), "Incite", "frightened"):
		return CombatResult.new()
	var fx2 := cf()._minutes(c, "Frightened (Incite)", "wr_incite", 1).with_condition(&"frightened")
	fx2.ends_on_damage = true
	if t.creature.add_effect(fx2):
		_log("condition", "%s is Frightened of %s and can't lie (Incite)" % [t.name(), c.name()], t)
		e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## Kindling Aura: the Aura of Protection's effect on an ally of a paladin with it also ignores Fire and Radiant
## Resistance and adds the paladin's Charisma modifier (at least +1) to Investigation and Insight. The paladin's own
## come from its data.
func _kindle(t: Combatant, fx: Effect) -> void:
	if not fx.stack_key.begins_with("aura:"):
		return
	var p := enc().get_c(fx.stack_key.substr(5))
	if p == null or p == t or not has(p, "kindling_aura"):
		return
	fx.data["wr_kindling"] = p.id
	for ty: String in ["fire", "radiant"]:
		fx.modifiers.append(Modifier.of("ignore_resistance", {"value": ty}, "Kindling Aura", &"feature"))
	for sk: String in ["investigation", "insight"]:
		fx.modifiers.append(Modifier.of("check", {"skill": sk, "value": maxi(1, p.creature.ability_mod(&"cha"))}, "Kindling Aura", &"feature"))


## Whether `c`'s weapon hits burn with Kindling Aura: the paladin itself, or a creature carrying its aura.
func _kindled(c: Combatant) -> bool:
	if has(c, "kindling_aura") and c.creature.hp > 0 and not c.creature.has_condition(&"incapacitated"):
		return true
	return c.creature.effects.any(func(fx: Effect) -> bool: return fx.data.has("wr_kindling"))


## How much of a `type` part `t` takes: 0 immune, 2 vulnerable, half when it resists (unless that's ignored).
static func _factor(t: Combatant, type: String, ignored: bool) -> float:
	if t.creature.immunity_source(StringName(type)) != "":
		return 0.0
	var f := 1.0
	if t.creature.resistance_source(StringName(type)) != "" and not ignored:
		f *= 0.5
	if t.creature.vulnerability_source(StringName(type)) != "":
		f *= 2.0
	return f


# --- Sinner -------------------------------------------------------------------------------------------------------

## The jinx a total of the two marked dice lays (the Hex Slinger Jinxes table).
static func jinx_of(total: int) -> String:
	if total <= 2:
		return "snake_eyes"
	if total <= 4:
		return "nightmare"
	if total <= 6:
		return "whiskey_bottle"
	if total == 7:
		return "cheap_shot"
	if total <= 9:
		return "withered_arm"
	if total <= 11:
		return "bad_luck"
	return "dead_man"


## The two marked Sneak Attack dice: the first two of the last Sneak Attack roll.
func _marked_dice() -> Array[int]:
	var out: Array[int] = []
	var rolled := enc().dice.log
	for i in range(rolled.size() - 1, -1, -1):
		if str(rolled[i].get("reason", "")) == "Sneak Attack damage":
			var rolls := rolled[i]["rolls"] as Array
			for j in mini(2, rolls.size()):
				out.append(int(rolls[j]))
			break
	return out


## How good a jinx is against `t`, for Pick Your Poison's choice: Dead Man first, Snake Eyes, The Nightmare, then the
## rest; doubles (Psychic damage) break ties upward.
func _jinx_worth(t: Combatant, pair: Array[int]) -> float:
	var worth := {"dead_man": 10.0, "snake_eyes": 9.0, "nightmare": 7.0, "bad_luck": 6.0, "cheap_shot": 5.0, "withered_arm": 4.0,
		"whiskey_bottle": 5.5 if not enc().ground.held(t).is_empty() else 5.0}
	return float(worth[jinx_of(pair[0] + pair[1])]) + (0.5 if pair[0] == pair[1] else 0.0)


## Hex Slinger after a Sneak Attack that dealt damage: the marked dice's total lays its jinx on the target (a use, or
## Heroic Inspiration with Borrowed Luck when the uses are gone). Pick Your Poison rolls the marked dice again and keeps
## the better jinx; doubles add Psychic damage of half the level, and a 2 or a 12 costs nothing.
func _hex_slinger(c: Combatant, t: Combatant, st: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var ch := _ch(c)
	if ch == null or not has(c, "hex_slinger") or not allowed(c, "hex_slinger") or not bool(st.get("sneak", false)) or r.damage <= 0:
		return
	if not t.is_alive() or t.is_down():
		return
	var luck := has(c, "borrowed_luck") and ch.heroic_inspiration
	if ch.resource_left("hex_slinger") <= 0 and not luck:
		return
	var marked := _marked_dice()
	if marked.size() < 2:
		return
	var pair := marked
	var details: Array[String] = ["Marked Sneak Attack dice: %d and %d (total %d)" % [marked[0], marked[1], marked[0] + marked[1]]]
	if has(c, "pick_your_poison"):
		var again := e.dice.roll(6, 2, "Pick Your Poison")
		details.append("Pick Your Poison rolls them again: %d and %d (total %d)" % [again[0], again[1], again[0] + again[1]])
		if _jinx_worth(t, again) > _jinx_worth(t, marked):
			pair = again
	var total := pair[0] + pair[1]
	var free := has(c, "pick_your_poison") and total in [2, 12]
	var paid := "nothing (Pick Your Poison)"
	var spent_luck := false
	if not free:
		if ch.resource_left("hex_slinger") > 0:
			ch.spend_resource("hex_slinger")
			paid = "a use of Hex Slinger"
		else:
			ch.heroic_inspiration = false
			spent_luck = true
			paid = "Heroic Inspiration (Borrowed Luck)"
	details.append("Paid with %s" % paid)
	var jinx := _lay_jinx(c, t, total, r)
	_log("info", "%s's marked dice come up %d and %d: %s on %s (Hex Slinger)" % [c.name(), pair[0], pair[1], JINX_NAMES[jinx], t.name()], c, details)
	if has(c, "borrowed_luck") and not spent_luck:
		_inspire(c, c, "Borrowed Luck")
	if has(c, "pick_your_poison") and pair[0] == pair[1] and t.is_alive():
		var psy := c.creature.character_level() / 2
		e.deal_damage(c, t, [{"amount": psy, "type": "psychic"}], false, "Pick Your Poison", ["Doubles: Psychic damage of half the level"])


## Lays the jinx for `total` on `t` (Whiskey Bottle on a creature holding nothing falls back to Cheap Shot); returns
## the jinx laid. Each lasts until the end of the target's next turn; Dead Man sits on the rogue until the end of its own.
func _lay_jinx(c: Combatant, t: Combatant, total: int, r: CombatResult = null) -> String:
	var e := enc()
	var jinx := jinx_of(total)
	var until := Effect.Ends.END_OF_TURN
	if jinx == "whiskey_bottle" and e.ground.held(t).is_empty():
		_log("info", "%s holds nothing to drop: Cheap Shot instead" % t.name(), t)
		jinx = "cheap_shot"
	match jinx:
		"snake_eyes":
			var se := cf()._timed(c, "Snake Eyes", "wr_snake_eyes", until, t).with_modifier("flag", {"value": "dazed"})
			se.data["rogue"] = c.id
			t.creature.add_effect(se)
		"nightmare":
			var nm := cf()._timed(c, "Frightened (The Nightmare)", "wr_nightmare", until, t).with_condition(&"frightened")
			if t.creature.add_effect(nm) and t.reaction_available and t.can_act() and not t.creature.has_flag("no_reactions") and t.speed() > 0:
				t.reaction_available = false
				_log("info", "%s flees in terror (The Nightmare)" % t.name(), t)
				e.flee(t, c, t.speed(), r if r != null else CombatResult.new())
		"whiskey_bottle":
			e.ground.drop_held(t, "Whiskey Bottle")
			t.creature.add_effect(cf()._timed(c, "Whiskey Bottle", "wr_whiskey", until, t).with_modifier("flag", {"value": "wr_whiskey"}))
		"cheap_shot":
			t.creature.add_effect(cf()._timed(c, "Cheap Shot", "wr_cheap_shot", until, t).with_modifier("speed_percent", {"value": 50}) \
				.with_modifier("attacked_with", {"value": "advantage"}))
		"withered_arm":
			t.creature.add_effect(cf()._timed(c, "Withered Arm", "wr_withered_arm", until, t) \
				.with_modifier("disadvantage", {"on": ["attack:str", "save:str", "check:str", "check:athletics"]}))
		"bad_luck":
			t.creature.add_effect(cf()._timed(c, "Bad Luck", "wr_bad_luck", until, t).with_modifier("penalty_die", {"dice": "1d6", "on": ["attack", "save:all"]}))
		"dead_man":
			c.creature.add_effect(cf()._timed(c, "Dead Man", "wr_dead_man", until, c).with_modifier("flag", {"value": "wr_dead_man"}))
	e.events.append({"type": "condition", "id": t.id})
	return jinx


## Whiskey Bottle: a jinxed creature holding something again (it picked it up) makes a DC 15 Dex save or drops it.
func _whiskey(c: Combatant) -> void:
	var fx := _effect(c, "wr_whiskey")
	if fx == null or bool(fx.data.get("held_ok", false)) or enc().ground.held(c).is_empty():
		return
	if cf()._save(c, &"dex", 15, "Whiskey Bottle"):
		fx.data["held_ok"] = true
	else:
		enc().ground.drop_held(c, "Whiskey Bottle")


## The jinx weapon (Get Jinxed), made out of the fight and chosen in the build. The jinx pistol is made once
## (`build["jinx_pistol_made"]`): it goes into the pack, and into the main hand when both hands are free then; it is
## never made again if lost or sold, and never pushes aside the player's weapon sets. An infused weapon is the one in
## hand as the fight starts.
func _arm_jinx_weapon(c: Combatant) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	if "jinx_pistol" in ClassFeatures.picks(c, "jinx_weapon"):
		if bool(ch.build.get("jinx_pistol_made", false)):
			return
		ch.build["jinx_pistol_made"] = true
		ch.add_item("jinx_pistol")
		var where := "in the pack"
		if ch.equipped("main_hand").is_empty() and ch.equipped("off_hand").is_empty():
			ch.equip("jinx_pistol", "main_hand")
			where = "in hand"
		_log("info", "%s's jinx pistol is made, %s" % [c.name(), where], c)
		return
	var held := ch.equipped("main_hand")
	if not held.is_empty() and held.has("weapon") and ch.weapon_proficient(held):
		c.set_meta("wr_jinx_item", str(held.get("id", "")))


# --- Hooks --------------------------------------------------------------------------------------------------------

func fight_started() -> void:
	for c in enc().combatants:
		if has(c, "get_jinxed"):
			_arm_jinx_weapon(c)


func effect_added(cr: Creature, fx: Effect) -> void:
	var c := enc().get_c(cr.id)
	if c == null or c.creature != cr:
		return
	if fx.source_id == "rage":
		if has(c, "volatile_serum"):
			_rage_started(c)
		return
	if fx.source_id == "aura_of_protection":
		_kindle(c, fx)
		return
	var hits := fx.conditions.filter(func(x: StringName) -> bool: return x in CATALYST_CONDITIONS)
	if not hits.is_empty() and _catalyst_ready(c):
		for cond in CATALYST_CONDITIONS:
			if c.creature.has_condition(cond):
				enc().spells.cure(c, cond)
		_catalyst(c, "it is %s" % str(hits[0]).capitalize())
		return
	_tidy(c)


func turn_start(c: Combatant) -> CombatResult:
	_tidy(c)
	if _serum(c) == "reconstruction":
		if c.has_meta("wr_recon_off"):
			c.remove_meta("wr_recon_off")
			_log("info", "Acid or Fire keeps %s's Reconstruction from working this turn" % c.name(), c)
		elif c.creature.hp < c.creature.max_hp():
			_reconstruct(c)
	_fumes_turn_start(c)
	return CombatResult.new()


func turn_end(c: Combatant) -> void:
	_whiskey(c)
	for o in enc().combatants:
		_tidy(o)


func monster_turn(c: Combatant) -> Variant:
	_whiskey(c)
	return null


func entered_cell(c: Combatant, _cell: Vector2i) -> void:
	if enc().current() != c:
		return
	for b in _fumers():
		if c.hostile_to(b) and _in_fumes(b, c):
			_fumes_slow(c, b)
			return


func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	if kind == D20Test.Kind.SAVING_THROW and "save:con" in keys and has(c, "reactive_catalyst") and ClassFeatures.raging(c):
		return {"advantage": ["Reactive Catalyst"]}
	return {}


func attack_situation(c: Combatant, target: Combatant, _option: Dictionary, _adv: Array[String], dis: Array[String]) -> void:
	for fx: Effect in c.creature.effects:
		if fx.source_id == "wr_fumes" and fx.caster_id != target.id:
			dis.append("Maddening Fumes")
			break
	# Snake Eyes: what the jinxed creature is about to attack (read by its attack roll's offers).
	if Thread.is_main_thread() and _effect(c, "wr_snake_eyes") != null:
		c.set_meta("wr_aimed", target.id)


func target_weight(c: Combatant, t: Combatant) -> float:
	for fx: Effect in c.creature.effects:
		if fx.source_id == "wr_fumes" and fx.caster_id != t.id:
			return 0.2
	return 1.0


func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	if t.kind != D20Test.Kind.ATTACK_ROLL:
		return
	var e := enc()
	# Monstrosity: once a turn, the Rage Damage bonus on a missed attack roll that relies on Strength.
	if _serum(c) == "path_of_the_experiment_monstrosity" and "attack:str" in keys and t.target > 0:
		var bonus := ClassFeatures.rage_bonus(c)
		out.append({"kind": "wr_monstrosity", "reactor": c, "title": "Monstrosity?",
			"text": "%s. Add your Rage Damage bonus (+%d) to the roll?" % [D20Responses.line(c, t), bonus],
			"cost": "Once a turn", "spends_reaction": false,
			"still": func() -> bool: return not t.success and _serum(c) == "path_of_the_experiment_monstrosity" and str(c.get_meta("wr_monstrous", "")) != _turn_key(),
			"helps": func() -> bool: return not t.natural_one and t.total + bonus >= t.target,
			"use": func() -> void:
				c.set_meta("wr_monstrous", _turn_key())
				t.add_bonus(bonus, "Monstrosity")
				_log("info", "%s's swollen muscles drive the blow home: +%d (Monstrosity)" % [c.name(), bonus], c, [t.describe()])})
	# Dead Man: the rogue's next attack roll hits; a hit is a Critical Hit; a natural 20 rolls the dice three times.
	var dm := _effect(c, "wr_dead_man")
	if dm != null:
		out.append({"kind": "wr_dead_man", "reactor": c, "forced": true, "use": func() -> void:
			c.creature.remove_effect(dm)
			if t.kept == 20:
				c.set_meta("wr_triple", true)
			if t.success:
				t.critical = true
				_log("info", "Dead Man: %s's attack is a Critical Hit" % c.name(), c)
			else:
				t.success = true
				t.reroll_note = "Dead Man: the miss hits"
				_log("info", "Dead Man: %s's miss hits instead" % c.name(), c)})
	# Snake Eyes: the jinxed creature attacking the rogue or an ally of the rogue takes 2d6 Psychic.
	var se := _effect(c, "wr_snake_eyes")
	if se != null and e.current() == c and not bool(se.data.get("stung", false)):
		var rogue := e.get_c(str(se.data.get("rogue", "")))
		var aimed := e.get_c(str(c.get_meta("wr_aimed", "")))
		if rogue != null and aimed != null and (aimed == rogue or aimed.allied_with(rogue)):
			out.append({"kind": "wr_snake_eyes", "reactor": c, "forced": true, "use": func() -> void:
				se.data["stung"] = true
				var rolled := e._roll_damage_dice("2d6", false, 0, "Snake Eyes")
				e.deal_damage(rogue, c, [{"amount": int(rolled["total"]), "type": "psychic"}], false, "Snake Eyes", ["Snake Eyes 2d6: %s" % rolled["text"]])})


func after_hit(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var p := option["profile"] as WeaponProfile
	var opts := st.get("opts", {}) as Dictionary
	# Ferocity: a melee weapon or Unarmed Strike hit also Cleaves (the weapon's own Cleave does it itself).
	if _serum(c) == "ferocity" and bool(option["melee"]) and p.mastery != "cleave" and not bool(opts.get("cleave", false)) \
			and e.current() == c and e.features._once(c, "cleave"):
		for o in e.hostiles_of(c):
			if o != target and not o.is_down() and e.distance(o, target) <= 5 and e.attack_legal(c, o, option) == "":
				_log("info", "Cleave (Ferocity): %s swings on into %s" % [c.name(), o.name()], c)
				e.cleave_queue.append({"c": c, "target": o, "option": option})
				break
	# Dead Man on a natural 20: the attack's damage dice a third time.
	if c.has_meta("wr_triple"):
		c.remove_meta("wr_triple")
		var dice: Array[String] = [p.damage_dice]
		if bool(st.get("sneak", false)) and _ch(c) != null:
			var v: Variant = _ch(c).class_column("rogue", "sneak_attack")
			if v != null:
				dice.append(str(v))
		var total := 0
		var texts: Array[String] = []
		for d in dice:
			if int(DiceRoller.parse_expr(d)["count"]) <= 0:
				continue
			var rolled := e._roll_damage_dice(d, false, 0, "Dead Man")
			total += int(rolled["total"])
			texts.append("%s: %s" % [d, rolled["text"]])
		if total > 0 and target.is_alive():
			e.deal_damage(c, target, [{"amount": total, "type": str(p.damage_type), "weapon": true}], false, "Dead Man", texts)
	_hex_slinger(c, target, st, r)


func adjust_incoming(source: Combatant, target: Combatant, ps: Array) -> void:
	var total := 0
	for raw: Variant in ps:
		total += int((raw as Dictionary).get("amount", 0))
	# Reactive Catalyst: the Rage comes before the damage (its Resistances apply to it).
	if total > 0 and _catalyst_ready(target):
		_catalyst(target, "it is hurt")
	if source == null:
		return
	# Get Jinxed: the infused weapon deals Force.
	var jinx := str(source.get_meta("wr_jinx_item", ""))
	if jinx != "":
		for raw2: Variant in ps:
			var d := raw2 as Dictionary
			if str(d.get("item", "")) == jinx and str(d["type"]) in PHYSICAL:
				d["type"] = "force"
	# Kindling Aura: a weapon hit can deal Fire instead, taken whenever Fire hurts the target more.
	if _kindled(source):
		for raw3: Variant in ps:
			var d2 := raw3 as Dictionary
			if not bool(d2.get("weapon", false)) or not str(d2["type"]) in PHYSICAL:
				continue
			if _factor(target, "fire", true) > _factor(target, str(d2["type"]), bool(d2.get("ignore_resistance", false))):
				d2["type"] = "fire"
				d2["ignore_resistance"] = true
				d2["ignore_source"] = "Kindling Aura"


func after_damage(_source: Combatant, target: Combatant, amount: int, ps: Array = [], _dr: DamageResult = null) -> void:
	if amount > 0 and _serum(target) == "reconstruction":
		for raw: Variant in ps:
			var d := raw as Dictionary
			if str(d.get("type", "")) in ["acid", "fire"] and int(d.get("amount", 0)) > 0:
				target.set_meta("wr_recon_off", true)
	_tidy(target)
