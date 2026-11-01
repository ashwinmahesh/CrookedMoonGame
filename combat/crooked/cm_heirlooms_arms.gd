class_name CmHeirloomsArms
extends CmHeirloomPart
## The Fabled Heirlooms of the Crimson Monastery (R14) and the Drowned Crossroads (R15) whose properties need code: the
## Shield of Marius Renathyr, the Sword of the Crimson Abbot, the Cutlass of Briggsy Kratch and the Blunderbuss of the
## Grinning Sinner. Their bonuses, the Sword's Blood Drain and its Vampiric Charm are data (data/magic_items); the rest is here.
## Legendary properties (level 13, after these chapters) wait: docs/rules/deviations.md lists them.

const SHIELD := "shield_of_marius_renathyr"
const SWORD := "sword_of_the_crimson_abbot"
const CUTLASS := "cutlass_of_briggsy_kratch"
const BLUNDERBUSS := "blunderbuss_of_the_grinning_sinner"

const VANGUARD := "cm_shield_vanguard"
const STAKES := "cm_cutlass_stakes"
const JINXSHOT := "cm_blunderbuss_jinxshot"

const WRATH_META := "cm_wrath_vs"
const HURT_META := "cm_hurt_this_turn"
const STAKES_KEY := "cm_stakes:"
const JINX_KEY := "cm_sinners_jinx:"
const SEA_LEGS := "cm_sea_legs"


func handles_item_power(custom: String) -> bool:
	return custom in [VANGUARD, STAKES, JINXSHOT]


func item_power_why(c: Combatant, p: Dictionary) -> String:
	match str((p["power"] as Dictionary).get("custom", "")):
		VANGUARD:
			if enc().round_no > 1 or c.has_meta("cm_vanguard_used"):
				return "Only as the fight begins (round 1)"
			return "" if _vanguard_ally(c, null) != null else "No ally you can see within 60 ft"
		STAKES:
			if not c.bonus_available:
				return "No Bonus Action left"
			return "" if _stakes_target(c, null) != null else "No creature within 5 ft"
		JINXSHOT:
			return ""
	return ""


func item_power_use(c: Combatant, p: Dictionary, targets: Array, point: Vector2, _opts: Dictionary) -> CombatResult:
	var picked: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
	match str((p["power"] as Dictionary).get("custom", "")):
		VANGUARD:
			return _vanguard(c, picked)
		STAKES:
			return _raise_the_stakes(c, picked)
		JINXSHOT:
			return _jinxshot(c, p, point)
	return CombatResult.fail("Not available")


# --- Shield of Marius Renathyr ------------------------------------------------------------------------------------

## Valorous Guard: the shield's bearer spends its Reaction when an ally within 5 ft is hit, adding 2 + the tier to its AC
## against that attack (it misses if that's enough). Very Rare: Righteous Wrath readies on the attacker.
func after_hit_target(st: Dictionary, miss: Callable, out: Array) -> void:
	var e := enc()
	var attacker := st["c"] as Combatant
	var target := st["target"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	if bool(st["critical"]):
		return
	for b in e.allies_of(target):
		if b == target or not holds(b, SHIELD) or e.distance(b, target) > 5 or not e.spells.can_react(b) or b.is_down():
			continue
		var bonus := 2 + tier(b)
		if t.total >= ac + bonus:
			continue
		var guard := b
		out.append({"kind": "cm_valorous_guard", "reactor": guard, "trigger": attacker.id, "default": "auto",
			"title": "Reaction: Valorous Guard?",
			"text": "%s hits %s: %d vs AC %d. %s can raise the shield: +%d AC against this attack, so it misses." % [attacker.name(), target.name(), t.total, ac, guard.name(), bonus],
			"cost": "Reaction (Shield of Marius Renathyr)",
			"still": func() -> bool: return e.spells.can_react(guard) and holds(guard, SHIELD),
			"use": func() -> void: _guarded(guard, target, attacker, bonus),
			"stop": func() -> CombatResult:
				st["ac"] = ac + bonus
				return miss.call() as CombatResult})
		break
	_panache(st, miss, out)


## The guard is raised: the Reaction is spent, and a Very Rare shield readies Righteous Wrath on the attacker.
func _guarded(guard: Combatant, target: Combatant, attacker: Combatant, bonus: int) -> void:
	guard.reaction_available = false
	_log("reaction", "%s's golden shield turns the blow from %s (+%d AC, Valorous Guard)" % [guard.name(), target.name(), bonus], guard)
	if tier(guard) >= 2:
		guard.set_meta(WRATH_META, attacker.id)


## Valorous Guard on a save: an ally within 5 ft fails a Dexterity save, and the shield's bonus would carry it.
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	_guard_save(c, t, keys, out)


func _guard_save(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	if t.kind != D20Test.Kind.SAVING_THROW or t.target <= 0 or t.success or not "save:dex" in keys or "death_save" in keys:
		return
	for b in e.allies_of(c):
		if not holds(b, SHIELD) or e.distance(b, c) > 5 or not e.spells.can_react(b) or b.is_down():
			continue
		var bonus := 2 + tier(b)
		if t.total + bonus < t.target:
			continue
		var guard := b
		out.append({"kind": "cm_valorous_guard", "reactor": guard, "trigger": c.id, "default": "auto",
			"title": "Reaction: Valorous Guard?",
			"text": "%s fails a Dexterity save (%d vs DC %d). %s can cover them with the shield: +%d." % [c.name(), t.total, t.target, guard.name(), bonus],
			"cost": "Reaction (Shield of Marius Renathyr)",
			"still": func() -> bool: return not t.success and e.spells.can_react(guard),
			"use": func() -> void:
				guard.reaction_available = false
				t.add_bonus(bonus, "Valorous Guard (%s)" % guard.name())
				_log("reaction", "%s shields %s (Valorous Guard)" % [guard.name(), c.name()], guard)})
		return


## Righteous Wrath (Very Rare): the shield bearer's next hit on an attacker it turned aside deals 1d8 Radiant more
## (3d8 when Legendary). The Cutlass's Raise the Stakes counts hits here too.
func hit_dice(c: Combatant, target: Combatant, _option: Dictionary, _st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if target != null and str(c.get_meta(WRATH_META, "")) == target.id and holds_at(c, SHIELD, 2):
		c.remove_meta(WRATH_META)
		out.append({"dice": "3d8" if tier(c) >= 3 else "1d8", "type": "radiant", "label": "Righteous Wrath"})
	return out


## Honor of the Vanguard (Very Rare): as the fight begins, the bearer steps through light to an ally's side and gains
## 5 x the tier in Temporary Hit Points.
func _vanguard(c: Combatant, picked: Combatant) -> CombatResult:
	var e := enc()
	var ally := _vanguard_ally(c, picked)
	if ally == null:
		return CombatResult.fail("No ally you can see within 60 ft")
	e.items._pay(c, "free")
	c.set_meta("cm_vanguard_used", true)
	var r := CombatResult.new()
	r.lines.append(e.log.add("info", "%s flashes to %s's side (Honor of the Vanguard)" % [c.name(), ally.name()], c.id))
	e.spells._teleport(c, e.spells._free_cell_near(ally.cell, c.size_cells), r)
	c.creature.add_temp_hp(5 * tier(c), "Honor of the Vanguard")
	return r


func _vanguard_ally(c: Combatant, picked: Combatant) -> Combatant:
	var e := enc()
	var ok := func(o: Combatant) -> bool:
		return o != c and not o.is_down() and o in e.allies_of(c) and e.distance(c, o) <= 60 and e.can_see(c, o)
	if picked != null:
		return picked if bool(ok.call(picked)) else null
	var best: Combatant = null
	for o in e.allies_of(c):
		if bool(ok.call(o)) and (best == null or e.distance(c, o) < e.distance(c, best)):
			best = o
	return best


# --- Sword of the Crimson Abbot -----------------------------------------------------------------------------------

## Irresistible Hunger (Very Rare): the sword's bearer's Necrotic damage ignores Resistance.
func adjust_incoming(source: Combatant, target: Combatant, parts: Array) -> void:
	if source == null or target == null or source == target or not holds_at(source, SWORD, 2):
		return
	for raw: Variant in parts:
		var d := raw as Dictionary
		if str(d["type"]) == "necrotic":
			d["ignore_resistance"] = true
			d["ignore_source"] = "Irresistible Hunger"


# --- Cutlass of Briggsy Kratch ------------------------------------------------------------------------------------

## Raise the Stakes: a Bonus Action marks a creature within 5 ft until the bearer's next turn. Whoever lands more hits on
## the other by then makes the other take 2d10 Psychic; a tie hurts both. Once a dusk.
func _raise_the_stakes(c: Combatant, picked: Combatant) -> CombatResult:
	var e := enc()
	var t := _stakes_target(c, picked)
	if t == null:
		return CombatResult.fail("No creature within 5 ft")
	e.items._pay(c, "bonus")
	var fx := item_fx(c, "Stakes raised by %s" % c.name(), CUTLASS, STAKES_KEY + c.id)
	fx.data["mine"] = 0
	fx.data["theirs"] = 0
	fx.data["by"] = c.id
	t.creature.add_effect(fx)
	var r := CombatResult.new()
	r.lines.append(e.log.add("info", "%s points the cutlass at %s: the stakes are raised (more hits wins, until %s's next turn)" % [c.name(), t.name(), c.name()], c.id))
	e.events.append({"type": "condition", "id": t.id})
	return r


func _stakes_target(c: Combatant, picked: Combatant) -> Combatant:
	var e := enc()
	if picked != null:
		return picked if picked != c and picked.is_alive() and e.distance(c, picked) <= 5 else null
	var best: Combatant = null
	for o in e.hostiles_of(c):
		if not o.is_down() and e.distance(c, o) <= 5 and best == null:
			best = o
	return best


## The creature `c` raised the stakes against, or null.
func _marked_by(c: Combatant) -> Combatant:
	for o in enc().combatants:
		if o.is_alive() and fx_of(o, STAKES_KEY + c.id) != null:
			return o
	return null


## Counts the hits of a raised stake; Sinner's Jinx rides the Blunderbuss's damage.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, _st: Dictionary, _r: CombatResult) -> void:
	if target == null:
		return
	var mark := fx_of(target, STAKES_KEY + c.id)
	if mark != null:
		mark.data["mine"] = int(mark.data.get("mine", 0)) + 1
	var back := fx_of(c, STAKES_KEY + target.id)
	if back != null:
		back.data["theirs"] = int(back.data.get("theirs", 0)) + 1
	if option.has("profile") and (option["profile"] as WeaponProfile).item_id == BLUNDERBUSS:
		_sinners_jinx(c, target)


## Double Down (Very Rare): the turn's first attack roll against the creature its bearer raised the stakes on earns one
## more attack this turn.
func before_roll(st: Dictionary, _out: Array) -> void:
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	if c != enc().current() or not c.took_attack_action or not holds_at(c, CUTLASS, 2) or fx_of(target, STAKES_KEY + c.id) == null:
		return
	if _once_per_turn(c, "cm_double_down"):
		c.attacks_left += 1
		_log("info", "%s doubles down on %s: one more attack this turn (Double Down)" % [c.name(), target.name()], c)


## The stake settles at the start of its bearer's next turn.
func turn_start(c: Combatant) -> CombatResult:
	_settle_stakes(c)
	return CombatResult.new()


func _settle_stakes(c: Combatant) -> void:
	var e := enc()
	for o in e.combatants:
		var mark := fx_of(o, STAKES_KEY + c.id)
		if mark == null:
			continue
		o.creature.remove_effect(mark)
		if not o.is_alive() or c.creature.dead:
			continue
		var mine := int(mark.data.get("mine", 0))
		var theirs := int(mark.data.get("theirs", 0))
		_log("info", "The stakes settle: %s landed %d, %s landed %d" % [c.name(), mine, o.name(), theirs], c)
		if mine >= theirs:
			hurt(c, o, "2d10", "psychic", "Raise the Stakes")
		if theirs >= mine and c.is_alive():
			hurt(o, c, "2d10", "psychic", "Raise the Stakes")


## Jinxcraft Panache (Very Rare): a Reaction adds 2 x the tier to the bearer's AC against a hit from a creature that has
## already hurt it this turn.
func _panache(st: Dictionary, miss: Callable, out: Array) -> void:
	var e := enc()
	var attacker := st["c"] as Combatant
	var target := st["target"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	if not holds_at(target, CUTLASS, 2) or not e.spells.can_react(target) or not _hurt_by(target, attacker):
		return
	var bonus := 2 * tier(target)
	if t.total >= ac + bonus:
		return
	out.append({"kind": "cm_jinxcraft_panache", "reactor": target, "trigger": attacker.id, "default": "auto",
		"title": "Reaction: Jinxcraft Panache?",
		"text": "%s hits %s again: %d vs AC %d. A flourish of the cutlass: +%d AC against this attack, so it misses." % [attacker.name(), target.name(), t.total, ac, bonus],
		"cost": "Reaction (Cutlass of Briggsy Kratch)",
		"still": func() -> bool: return e.spells.can_react(target),
		"use": func() -> void:
			target.reaction_available = false
			_log("reaction", "%s parries with a pirate's flourish (+%d AC, Jinxcraft Panache)" % [target.name(), bonus], target),
		"stop": func() -> CombatResult:
			st["ac"] = ac + bonus
			return miss.call() as CombatResult})


## Who has hurt the Cutlass's bearer this turn (Jinxcraft Panache).
func after_damage(source: Combatant, target: Combatant, amount: int, _parts: Array = [], _dr: DamageResult = null) -> void:
	if source == null or target == null or amount <= 0 or not holds(target, CUTLASS):
		return
	var seen := target.get_meta(HURT_META, {}) as Dictionary
	if str(seen.get("turn", "")) != _turn_key():
		seen = {"turn": _turn_key(), "ids": []}
	(seen["ids"] as Array).append(source.id)
	target.set_meta(HURT_META, seen)


func _hurt_by(c: Combatant, source: Combatant) -> bool:
	var seen := c.get_meta(HURT_META, {}) as Dictionary
	return str(seen.get("turn", "")) == _turn_key() and source.id in (seen.get("ids", []) as Array)


## Sea Legs: a bearer who Disengages ignores Difficult Terrain for the rest of the turn.
func after_action(c: Combatant, _action: Dictionary, _targets: Array = []) -> void:
	if c.disengaged and holds(c, CUTLASS) and fx_of(c, SEA_LEGS) == null:
		var fx := item_fx(c, "Sea Legs", CUTLASS, SEA_LEGS).with_modifier("flag", {"value": "ignore_difficult_terrain"})
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = c.id
		c.creature.add_effect(fx)
		_log("info", "%s finds their sea legs: Difficult Terrain doesn't slow them this turn" % c.name(), c)


# --- Blunderbuss of the Grinning Sinner ---------------------------------------------------------------------------

## Jinxshot: in place of one attack, a 30-ft Cone of grave-shot. Each creature in it makes a Dexterity save against the
## heirloom's DC: 2d4 Necrotic (3d6 when Very Rare), half on a success.
func _jinxshot(c: Combatant, p: Dictionary, point: Vector2) -> CombatResult:
	var e := enc()
	var aim := (point - e.center_of(c)) if point != Vector2.INF else Vector2.ZERO
	if aim.length() < 0.01:
		return CombatResult.fail("Choose a direction")
	var cells := e.grid.area_cells("cone", 30, e.center_of(c), aim.normalized())
	e.items._pay(c, "attack")
	var label := "Jinxshot"
	var dc := heirloom_dc(c)
	var dice := "3d6" if tier(c) >= 2 else "2d4"
	e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": str(p["item_id"]), "targets": [], "cells": cells})
	_log("info", "%s's blunderbuss roars: a cone of grave-shot" % c.name(), c)
	var rolled := e._roll_damage_dice(dice, false, 0, label)
	for t in e.combatants:
		if t == c or not t.is_alive() or not t.footprint().any(func(cell: Vector2i) -> bool: return cell in cells):
			continue
		var made := saves(t, &"dex", dc, label)
		var amount := int(rolled["total"]) / (2 if made else 1)
		var dr := e.deal_damage(c, t, [{"amount": amount, "type": "necrotic"}], false, label, [str(rolled["text"])])
		if dr.final > 0:
			_sinners_jinx(c, t)
	return CombatResult.new()


## Sinner's Jinx (Very Rare): once a turn, when the Blunderbuss hurts a creature, it makes a Charisma save against the
## heirloom's DC or is cursed for a minute: 1d4 off its D20 Tests. One creature at a time.
func _sinners_jinx(c: Combatant, t: Combatant) -> void:
	if not t.is_alive() or t == c or not holds_at(c, BLUNDERBUSS, 2) or not c.hostile_to(t) or not _once_per_turn(c, "cm_sinners_jinx"):
		return
	if saves(t, &"cha", heirloom_dc(c), "Sinner's Jinx"):
		return
	for o in enc().combatants:
		var old := fx_of(o, JINX_KEY + c.id)
		if old != null:
			o.creature.remove_effect(old)
	var fx := item_fx(c, "Sinner's Jinx", BLUNDERBUSS, JINX_KEY + c.id) \
		.with_modifier("penalty_die", {"dice": "1d4", "on": ["attack", "save:all", "check:all"]})
	fx.lasting_rounds(10, c.id)
	t.creature.add_effect(fx)
	_log("condition", "%s is jinxed by the Grinning Sinner: 1d4 off its D20 Tests for a minute" % t.name(), t)
	enc().events.append({"type": "condition", "id": t.id})

