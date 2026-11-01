class_name CrookedFeatures
extends GameFeatures
## The Crooked Moon's own fight code (E26): the book's species, subclasses, feats, spells and Dark Bargains that need
## more than data, and its bestiary. data/campaign.json names this script under "features"; the engine makes one with
## every encounter (`Encounter.game`) and calls the hooks of GameFeatures on it.
##
## The code is split into parts, each a GameFeatures of its own made with the same encounter (combat/crooked/*.gd and
## the bestiary's combat/bestiary/): this class forwards every hook to every part. A hotbar action, queued Reaction or
## sustained spell action goes to the part that `owns` its id (its "gm_" kind, or its sustained action's `mode`).
## Hooks that answer are combined: lists append, numbers add, weights multiply, the first part that handles a spell,
## a monster's turn or action wins, and turn starts run one after another, pausing for the player's answers.

var parts: Array[GameFeatures] = []


func _init(encounter: Encounter) -> void:
	super(encounter)
	for path: String in PART_PATHS:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			push_error("CrookedFeatures: %s doesn't load" % path)
			continue
		parts.append(script.new(encounter) as GameFeatures)


## The parts, in the order their hooks run. Loaded by path, so a part that doesn't compile is left out (and said so)
## instead of taking every fight's module with it.
const PART_PATHS: Array[String] = ["res://combat/crooked/cm_species.gd", "res://combat/crooked/cm_feats.gd",
	"res://combat/crooked/cm_grave_and_grim.gd", "res://combat/crooked/cm_blood_and_jest.gd", "res://combat/crooked/cm_warriors.gd",
	"res://combat/crooked/cm_casters.gd", "res://combat/crooked/cm_scholars.gd", "res://combat/crooked/cm_spells_a.gd",
	"res://combat/crooked/cm_spells_b.gd", "res://combat/crooked/cm_bargains.gd", "res://combat/bestiary/bestiary_features.gd", "res://combat/crooked/cm_heirlooms.gd",
	"res://combat/crooked/cm_heirlooms_arms.gd", "res://combat/crooked/cm_heirlooms_relics.gd", "res://combat/crooked/cm_heirlooms_revels.gd"]


## The part that owns the hotbar action, queued kind or sustained mode `id`, or null.
func owner_of(id: String) -> GameFeatures:
	for p in parts:
		if p.owns(id):
			return p
	return null


# --- The hotbar ---------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	for p in parts:
		p.list(c, out, aw, bw)


func perform(c: Combatant, id: String, t: Combatant, cell: Vector2i, point: Vector2) -> CombatResult:
	var p := owner_of(id)
	if p == null:
		return CombatResult.fail("Not available")
	p.targets_in = targets_in
	p.choice_in = choice_in
	return p.perform(c, id, t, cell, point)


func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in parts:
		out.append_array(p.rider_options(c))
	return out


# --- Attacks ------------------------------------------------------------------------------------------------------

func attack_situation(c: Combatant, target: Combatant, option: Dictionary, adv: Array[String], dis: Array[String]) -> void:
	for p in parts:
		p.attack_situation(c, target, option, adv, dis)


func hit_dice(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in parts:
		out.append_array(p.hit_dice(c, target, option, st))
	return out


func after_hit(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary, r: CombatResult) -> void:
	for p in parts:
		p.after_hit(c, target, option, st, r)


func after_hit_target(st: Dictionary, miss: Callable, out: Array) -> void:
	for p in parts:
		p.after_hit_target(st, miss, out)


func before_roll(st: Dictionary, out: Array) -> void:
	for p in parts:
		p.before_roll(st, out)


func against_damage(st: Dictionary, total: Callable, cut: Callable, out: Array) -> void:
	for p in parts:
		p.against_damage(st, total, cut, out)


# --- Damage, drops and deaths -------------------------------------------------------------------------------------

func adjust_incoming(source: Combatant, target: Combatant, ps: Array) -> void:
	for p in parts:
		p.adjust_incoming(source, target, ps)


func after_damage(source: Combatant, target: Combatant, amount: int, ps: Array = [], dr: DamageResult = null) -> void:
	for p in parts:
		p.after_damage(source, target, amount, ps, dr)


func queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	for p in parts:
		p.queue_damage_reactions(source, target)


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var p := owner_of(str(q["kind"]))
	return p != null and p.queued_ok(q, reactor)


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	var p := owner_of(str(q["kind"]))
	return p.fire_queued(q, reactor, trigger) if p != null else CombatResult.new()


func queued_text(kind: String) -> Array:
	var p := owner_of(kind)
	return p.queued_text(kind) if p != null else super(kind)


func on_drop(by: Combatant, target: Combatant) -> void:
	for p in parts:
		p.on_drop(by, target)


func on_zero(target: Combatant, damage: int) -> bool:
	for p in parts:
		if p.on_zero(target, damage):
			return true
	return false


func on_death(source: Combatant, dead: Combatant) -> void:
	for p in parts:
		p.on_death(source, dead)


func cheats_death(target: Combatant) -> bool:
	for p in parts:
		if p.cheats_death(target):
			return true
	return false


func blocks_forced_move(target: Combatant) -> bool:
	return parts.any(func(p: GameFeatures) -> bool: return p.blocks_forced_move(target))


func object_broken(o: BattleObject, source: Combatant) -> void:
	for p in parts:
		p.object_broken(o, source)


# --- Turns, Initiative and D20 Tests ------------------------------------------------------------------------------

func initiative_advantage(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for p in parts:
		out.append_array(p.initiative_advantage(c))
	return out


func initiative_rolled() -> void:
	for p in parts:
		p.initiative_rolled()


func fight_started() -> void:
	for p in parts:
		p.fight_started()


func round_started(round_no: int) -> void:
	for p in parts:
		p.round_started(round_no)


func turn_start(c: Combatant) -> CombatResult:
	return enc().each(parts, func(p: Variant) -> CombatResult: return (p as GameFeatures).turn_start(c),
		func() -> CombatResult: return CombatResult.new())


func turn_end(c: Combatant) -> void:
	for p in parts:
		p.turn_end(c)


func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	var out := {}
	for p in parts:
		var d := p.before_d20(c, kind, keys)
		for side: String in ["advantage", "disadvantage"]:
			if d.has(side):
				out[side] = (out.get(side, []) as Array) + (d[side] as Array)
	return out


func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	for p in parts:
		p.d20_offers(c, t, keys, out)


func before_action(c: Combatant) -> void:
	for p in parts:
		p.before_action(c)


func wastes_action(c: Combatant, kind: String) -> bool:
	for p in parts:
		if p.wastes_action(c, kind):
			return true
	return false


func after_action(c: Combatant, action: Dictionary, targets: Array = []) -> void:
	for p in parts:
		p.after_action(c, action, targets)


# --- Monsters and movement ---------------------------------------------------------------------------------------

func monster_turn(c: Combatant) -> Variant:
	for p in parts:
		var r: Variant = p.monster_turn(c)
		if r != null:
			return r
	return null


func bonus_action(c: Combatant, act: Dictionary, plan: String) -> Variant:
	for p in parts:
		var r: Variant = p.bonus_action(c, act, plan)
		if r != null:
			return r
	return null


func special_action(c: Combatant, act: Dictionary, t: Combatant, cell: Vector2i) -> Variant:
	for p in parts:
		var r: Variant = p.special_action(c, act, t, cell)
		if r != null:
			return r
	return null


func rider(src: Combatant, t: Combatant, rd: Dictionary, by_type: Dictionary, act_name: String) -> bool:
	for p in parts:
		if p.rider(src, t, rd, by_type, act_name):
			return true
	return false


func entered_cell(c: Combatant, cell: Vector2i) -> void:
	for p in parts:
		p.entered_cell(c, cell)


func barrier_cells(c: Combatant) -> Dictionary:
	var out := {}
	for p in parts:
		out.merge(p.barrier_cells(c))
	return out


func target_weight(c: Combatant, t: Combatant) -> float:
	var w := 1.0
	for p in parts:
		w *= p.target_weight(c, t)
	return w


func shaped_list(c: Combatant, out: Array[Dictionary], bw: String) -> bool:
	for p in parts:
		if p.shaped_list(c, out, bw):
			return true
	return false


# --- Spells -------------------------------------------------------------------------------------------------------

func before_resolve(ctx: Dictionary) -> void:
	for p in parts:
		p.before_resolve(ctx)


func casting_unit(c: Combatant, s: Dictionary, unit: String) -> String:
	for p in parts:
		unit = p.casting_unit(c, s, unit)
	return unit


func spell_reach(c: Combatant, s: Dictionary, t: Combatant) -> bool:
	return parts.any(func(p: GameFeatures) -> bool: return p.spell_reach(c, s, t))


func skips_concentration(c: Combatant, s: Dictionary, free: bool) -> Dictionary:
	for p in parts:
		var d := p.skips_concentration(c, s, free)
		if not d.is_empty():
			return d
	return {}


func pays_component(c: Combatant, s: Dictionary, spend: bool) -> bool:
	for p in parts:
		if p.pays_component(c, s, spend):
			return true
	return false


func resolve_spell(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> bool:
	for p in parts:
		if p.resolve_spell(ctx, tgt, cells, r):
			return true
	return false


func after_cast(c: Combatant, s: Dictionary, slot: int, free: bool = false, ctx: Dictionary = {}) -> void:
	for p in parts:
		p.after_cast(c, s, slot, free, ctx)


func spell_damage_bonus(ctx: Dictionary, bonus: Breakdown) -> int:
	var n := 0
	for p in parts:
		n += p.spell_damage_bonus(ctx, bonus)
	return n


func spell_healing(ctx: Dictionary, t: Combatant) -> int:
	var n := 0
	for p in parts:
		n += p.spell_healing(ctx, t)
	return n


func sustained_why(c: Combatant, a: Dictionary, d: Dictionary, t: Combatant, point: Vector2) -> String:
	var p := owner_of(str(d.get("mode", "")))
	return p.sustained_why(c, a, d, t, point) if p != null else "Not available"


func sustained(c: Combatant, a: Dictionary, d: Dictionary, ctx: Dictionary, targets: Array, point: Vector2, dir: Vector2, r: CombatResult) -> CombatResult:
	var p := owner_of(str(d.get("mode", "")))
	return p.sustained(c, a, d, ctx, targets, point, dir, r) if p != null else CombatResult.fail("Not available")


func zone_failed_save(o: FieldObject, t: Combatant) -> void:
	for p in parts:
		p.zone_failed_save(o, t)


func after_save_ended(c: Combatant, fx: Effect) -> void:
	for p in parts:
		p.after_save_ended(c, fx)


func effect_added(cr: Creature, fx: Effect) -> void:
	for p in parts:
		p.effect_added(cr, fx)


func after_summon(ctx: Dictionary, m: Creature) -> void:
	for p in parts:
		p.after_summon(ctx, m)


# --- The game's own item powers -----------------------------------------------------------------------------------

func handles_item_power(custom: String) -> bool:
	for p in parts:
		if p.handles_item_power(custom):
			return true
	return false


func item_power_why(c: Combatant, p: Dictionary) -> String:
	for part in parts:
		if part.handles_item_power(str((p["power"] as Dictionary).get("custom", ""))):
			return part.item_power_why(c, p)
	return ""


func item_power_use(c: Combatant, p: Dictionary, targets: Array, point: Vector2, opts: Dictionary) -> CombatResult:
	for part in parts:
		if part.handles_item_power(str((p["power"] as Dictionary).get("custom", ""))):
			return part.item_power_use(c, p, targets, point, opts)
	return CombatResult.fail("Not available")
