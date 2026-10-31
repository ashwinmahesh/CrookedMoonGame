class_name CmHeirlooms
extends CmPart
## The Fabled Heirlooms of the Fields of the Crow (R13) whose powers need code: the Banjo of Ol' Jericho Sticks (a dance that disengages, a
## charm that lands through a demon's immunity) and the Scythe of the Harvest Terror (a step to a Frightened creature). A part of
## CrookedFeatures; the items' powers name these as `custom` ids (data/magic_items/jericho_banjo.json and scythe_of_the_harvest_terror.json),
## and the engine asks handles_item_power, item_power_why and item_power_use (GameFeatures).

const DANCE := "cm_banjo_dance"
const CHARM := "cm_banjo_charm"
const STEP := "cm_scythe_step"
const CHARM_RANGE_FT := 30
const STEP_RANGE_FT := 60


func handles_item_power(custom: String) -> bool:
	return custom in [DANCE, CHARM, STEP]


func item_power_why(c: Combatant, p: Dictionary) -> String:
	var custom := str((p["power"] as Dictionary).get("custom", ""))
	match custom:
		DANCE:
			return "" if c.bonus_available else "No Bonus Action left"
		CHARM:
			return "" if _charm_target(c, null) != null else "No fiend or humanoid within 30 ft"
		STEP:
			if not c.bonus_available:
				return "No Bonus Action left"
			return "" if _frightened_near(c) != null else "No Frightened creature within 60 ft"
	return ""


func item_power_use(c: Combatant, p: Dictionary, targets: Array, _point: Vector2, _opts: Dictionary) -> CombatResult:
	var custom := str((p["power"] as Dictionary).get("custom", ""))
	var picked: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
	match custom:
		DANCE:
			return _dance(c, p)
		CHARM:
			return _charm(c, p, picked)
		STEP:
			return _step(c, p)
	return CombatResult.fail("Not available")


## The banjo's dance: a Bonus Action that Disengages its player.
func _dance(c: Combatant, _p: Dictionary) -> CombatResult:
	var e := enc()
	if not c.bonus_available:
		return CombatResult.fail("No Bonus Action left")
	e.items._pay(c, "bonus")
	c.disengaged = true
	var r := CombatResult.new()
	r.lines.append(e.log.add("info", "%s plays a reel and dances out of reach" % c.name(), c.id))
	return r


## The banjo's charm: a fiend or humanoid within 30 ft makes a Wisdom save against the player's Charisma save DC or is Charmed for a
## minute even if charm doesn't move it (the demon's immunity is pierced), the charm ending if it is hurt.
func _charm(c: Combatant, _p: Dictionary, picked: Combatant) -> CombatResult:
	var e := enc()
	var t := picked if picked != null and _charmable(c, picked) else _charm_target(c, null)
	if t == null:
		return CombatResult.fail("No fiend or humanoid within 30 ft")
	e.items._pay(c, "action")
	var dc := dc_of(c, &"cha")
	var r := CombatResult.new()
	var s := t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs the Banjo (%s)" % t.name(), ["save_vs:charmed"])
	if s.success:
		r.lines.append(e.log.add("info", "%s shrugs off the tune" % t.name(), t.id, [s.describe()]))
		return r
	var fx := Effect.new("Charmed by the Banjo", &"item", "jericho_banjo").with_condition(&"charmed")
	fx.caster_id = c.id
	fx.lasting_rounds(10, c.id)
	fx.ends_on_damage = true
	fx.data["pierce"] = true
	fx.stack_key = "banjo_charm:%s" % t.id
	if t.creature.add_effect(fx):
		r.lines.append(e.log.add("condition", "%s is charmed by %s's tune" % [t.name(), c.name()], t.id, [s.describe()]))
		e.events.append({"type": "condition", "id": t.id})
	return r


## The scythe's step: a Bonus Action to appear beside a Frightened creature within 60 ft.
func _step(c: Combatant, _p: Dictionary) -> CombatResult:
	var e := enc()
	var foe := _frightened_near(c)
	if foe == null or not c.bonus_available:
		return CombatResult.fail("No Frightened creature within 60 ft")
	var cell := e.spells._free_cell_near(foe.cell, c.size_cells)
	var r := CombatResult.new()
	e.items._pay(c, "bonus")
	r.lines.append(e.log.add("info", "%s steps through the dark to stand over %s" % [c.name(), foe.name()], c.id))
	e.spells._teleport(c, cell, r)
	return r


func _charmable(c: Combatant, t: Combatant) -> bool:
	if t == c or t.is_down() or not t in enc().hostiles_of(c) or enc().distance(c, t) > CHARM_RANGE_FT:
		return false
	return str(t.creature.creature_type) in ["fiend", "humanoid"]


func _charm_target(c: Combatant, _unused: Variant) -> Combatant:
	var best: Combatant = null
	for o in enc().combatants:
		if _charmable(c, o) and (best == null or enc().distance(c, o) < enc().distance(c, best)):
			best = o
	return best


func _frightened_near(c: Combatant) -> Combatant:
	var best: Combatant = null
	for o in enc().combatants:
		if o != c and not o.is_down() and o in enc().hostiles_of(c) and o.creature.has_condition(&"frightened") and enc().distance(c, o) <= STEP_RANGE_FT \
				and (best == null or enc().distance(c, o) < enc().distance(c, best)):
			best = o
	return best
