class_name CmGraveAndGrim
extends CmPart
## The Crooked Moon's code for three of the book's subclasses (chapter 3): Barrow Guard, Grim Harbinger and Warrior of the Pestilent Haze: the parts of them data can't say.
## CrookedFeatures forwards every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start
## "gg_".
##
## Barrow Guard (Rook): Draugr Dice pay for every power (death_knight: the pool, its die from the subclass table, the
## power save DC 8 + PB + Con). Dark Rider calls a ghost steed (a Warhorse, but Undead with B/P/S Resistance and only
## Dash, Disengage and Dodge), mounted through EncounterMounts; a die on its Dash adds 5 x the roll in feet, and from 10
## (Phantom Charger) a die on its Dash, Disengage or Dodge teleports it with its rider and bursts Necrotic round where
## it lands. Grave Guard cuts damage taken (Death Knell hurts the one who dealt it), Soul Reaper gives up an attack for
## ghostly hands that grapple at 60 ft (Spectral Shrieking hurts the held at the start of their turns), Mortal Coil
## takes a die back when a living foe dies near, Whisper of the Departed adds a die to a check.
## Grim Harbinger (Lucan): Omen of Doom marks a creature (1d6 Necrotic once a turn on hits) and calls the Grim, a
## spectral hound built per Ranger level that only Dodges unless commanded (as part of the Omen, with a Bonus Action,
## or for one of the ranger's attacks), howls at foes leaving its reach, and vanishes with its doomed, its own drop or a
## new Omen. Mortal Reminder turns damage to the doomed Necrotic when that does more; Mounting Dread lets the Grim's
## Necrotic past Resistance; Inescapable Fate rerolls the doomed's successful save.
## Pestilent Haze (Silas): Claws of Pestilence (Slashing when it does more; a Flurry hit adds a Martial Arts die of
## Necrotic), Miasmic Plague (two riders: 1 Focus Point, or free on a Flurry hit by giving up the claws' die; Con save or
## cursed: Poisoned and a Martial Arts die of Necrotic from your Unarmed Strikes once a turn), Tolling Censer, Choking
## Miasma (Disadvantage on the plague's saves) and Scurrying Spread (Step of the Wind with Focus spreads it).

const PREFIX := "gg_"
## Effect sources: the Omen's mark, Soul Reaper's ghostly hands, the Miasmic Plague's curse.
const DOOM := "gg_doom"
const HANDS := "gg_soul_reaper"
const PLAGUE := "gg_plague"
## Phantom Charger's ways to go: the steed's action, then the teleport.
const CHARGES: Array[String] = ["dash", "disengage", "dodge"]


func prefix() -> String:
	return PREFIX


# --- Shared helpers ---------------------------------------------------------------------------------------------

## Death Knight: the size of a Draugr Die (the subclass table's column), 0 without the feature.
static func draugr_die(c: Combatant) -> int:
	var ch := _ch(c)
	if ch == null or not has(c, "death_knight"):
		return 0
	var v: Variant = ch.class_column("fighter", "draugr_die")
	var text := str(v) if v != null else ""
	return int(text.trim_prefix("d")) if text.begins_with("d") else 0


## Draugr Dice left to spend.
static func dice_left(c: Combatant) -> int:
	var ch := _ch(c)
	return ch.resource_left("draugr_dice") if ch != null and draugr_die(c) > 0 else 0


## Spends and rolls one Draugr Die for `label`; 0 when none is left.
func _spend_draugr(c: Combatant, label: String) -> int:
	if dice_left(c) <= 0:
		return 0
	_ch(c).spend_resource("draugr_dice")
	var v := enc().dice.roll_one(draugr_die(c), "%s (Draugr Die)" % label)
	_log("info", "%s spends a Draugr Die on %s: %d (%d left)" % [c.name(), label, v, dice_left(c)], c)
	return v


## The Death Knight power save DC: 8 + Proficiency Bonus + Constitution modifier.
static func power_dc(c: Combatant) -> int:
	return dc_of(c, &"con")


## A summon of `owner`'s whose stat block carries `flag` (the ghost steed, the Grim), alive, or null.
func _summon_of(owner: Combatant, flag: String) -> Combatant:
	var e := enc()
	if owner == null:
		return null
	for sid: Variant in e.spells.summoned.get(owner.id, []):
		var s := e.get_c(str(sid))
		if s != null and s.is_alive() and s.creature is Monster and bool((s.creature as Monster).data.get(flag, false)):
			return s
	return null


func steed_of(c: Combatant) -> Combatant:
	return _summon_of(c, "gg_dark_steed")


func grim_of(c: Combatant) -> Combatant:
	return _summon_of(c, "gg_grim")


## Who called `s` (a summon's `summoner`), or null.
func _maker(s: Combatant) -> Combatant:
	return enc().get_c(str(s.get_meta("summoner", ""))) if s != null and s.has_meta("summoner") else null


static func _flagged(c: Combatant, flag: String) -> bool:
	return c != null and c.creature is Monster and bool((c.creature as Monster).data.get(flag, false))


## Places `m` as `c`'s summon near `near` (a guest of the party), acting right after `c`, as Beast Master's companion does.
func _call(c: Combatant, m: Monster, near: Vector2i) -> Combatant:
	var e := enc()
	var size := CombatGrid.size_cells_for(m.size)
	var spot := _spot_beside(near, size)
	var sc := e.add(m, &"guest" if c.side == &"party" else c.side, spot)
	sc.controller = c.controller
	sc.set_meta("summoner", c.id)
	sc.set_meta("vanishes", true)
	if not e.spells.summoned.has(c.id):
		e.spells.summoned[c.id] = []
	(e.spells.summoned[c.id] as Array).append(sc.id)
	if e.state == Encounter.State.ACTIVE:
		e.insert_after(c, sc)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": spot, "caster": c.id})
	return sc


## The free square for a creature `size` across that sits closest to `near`: a steed called beside its rider is within the
## 5 ft Mount needs, not the first free corner in a scan that may leave a gap.
func _spot_beside(near: Vector2i, size: int) -> Vector2i:
	var e := enc()
	var best := e.spells._free_cell_near(near, size)
	var best_gap := e.grid.distance_ft(near, 1, best, size) if e.spells._room_for(best, size) else 1 << 30
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var cand := near + Vector2i(dx, dy)
			if not e.spells._room_for(cand, size):
				continue
			var gap := e.grid.distance_ft(near, 1, cand, size)
			if gap < best_gap:
				best_gap = gap
				best = cand
	return best


## Sends `s` away (its rider, if any, steps down beside it first).
func _vanish(s: Combatant, why: String) -> void:
	var e := enc()
	if s == null or not s.is_alive():
		return
	var rider := e.rider_of(s)
	if rider != null:
		e.dismount(rider, false, false)
	_log("info", "%s fades away (%s)" % [s.name(), why], s)
	e.spells._dismiss(s.id)


## A save the book's features force: rolled at once and logged, with Disadvantage sources `dis`.
func _save(t: Combatant, ab: StringName, dc: int, label: String, dis: Array[String] = [], keys: Array[String] = []) -> bool:
	var e := enc()
	var adv: Array[String] = []
	var sv := t.creature.roll_save(e.dice, ab, dc, adv, dis, "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, t.name()], keys)
	_log("info", "%s %s the %s save" % [t.name(), "succeeds on" if sv.success else "fails", label], t, [sv.describe()])
	return sv.success


static func _unarmed(option: Dictionary) -> bool:
	return option.has("profile") and (option["profile"] as WeaponProfile).item_id == "unarmed_strike"


# --- Barrow Guard -----------------------------------------------------------------------------------------------

## Dark Rider: the ghost steed, a Warhorse (2025) that is Undead, resists Bludgeoning, Piercing and Slashing, has no
## attacks, and carries its Draugr Die actions for its own turns; from 10 it ignores Difficult Terrain.
func _steed_block(c: Combatant) -> Dictionary:
	var traits: Array = [{"id": "spectral_mount", "name": "Spectral Mount", "action": "passive",
		"summary": "Only its rider can mount it; it can only Dash, Disengage or Dodge."}]
	var actions: Array = [{"id": "gg_draugr_dash", "name": "Draugr Dash", "do": "gg_draugr_dash", "sub": "Dash + 5 x a Draugr Die ft",
		"targeting": "none", "summary": "Dash, and the rider spends a Draugr Die: +5 ft of Speed per point rolled for this move."}]
	if has(c, "phantom_charger"):
		traits.append({"id": "phantom_charger", "name": "Phantom Charger", "action": "passive",
			"modifiers": [{"stat": "flag", "value": "ignore_difficult_terrain"}], "summary": "Ignores Difficult Terrain."})
		actions.append({"id": "gg_phantom_charge", "name": "Phantom Charge", "do": "gg_phantom_charge", "sub": "teleport 60 ft + Necrotic burst",
			"targeting": "point", "range": 60,
			"summary": "Dash, and the rider spends a Draugr Die: teleport up to 60 ft; foes within 10 ft of where it lands make a Con save or take the die + Con Necrotic (half on a success)."})
	return {"id": "gg_dark_steed", "name": "Ghost Steed", "size": "large", "type": "undead", "ac": 11,
		"hp": {"average": 19, "dice": "19"}, "speed": {"walk": 60},
		"abilities": {"str": 18, "dex": 12, "con": 13, "int": 2, "wis": 12, "cha": 7}, "saves": {"wis": 3},
		"passive_perception": 11, "cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 1, "summon": true,
		"gg_dark_steed": true, "resistances": ["bludgeoning", "piercing", "slashing"], "traits": traits, "actions": actions,
		"ai_profile": "brute", "summary": "A ghostly warhorse only its rider can mount.", "text": "Dark Rider."}


## Dark Rider: a Bonus Action and the use (or a Draugr Die to get the use back) calls the steed beside the fighter; a
## steed already out fades first.
func _dark_rider(c: Combatant) -> CombatResult:
	var ch := _ch(c)
	if ch.resource_left("dark_rider") <= 0:
		if _spend_draugr(c, "Dark Rider") <= 0:
			return CombatResult.fail("No Dark Rider use or Draugr Die left")
		ch.restore_resource("dark_rider")
	ch.spend_resource("dark_rider")
	c.bonus_available = false
	_vanish(steed_of(c), "a new steed is called")
	var m := Monster.from_data(_steed_block(c), enc().dice)
	var sc := _call(c, m, c.cell)
	sc.set_meta("only_rider", c.id)
	_log("info", "%s calls a ghost steed from the grave (Dark Rider)" % c.name(), c)
	return CombatResult.new()


## Why the steed can't take an action on its rider's turn: it already acted since its own turn began, or no die is left.
func _steed_why(f: Combatant, steed: Combatant) -> String:
	var why := enc()._turn_check(f)
	if why != "":
		return why
	if steed == null:
		return "No ghost steed"
	if bool(steed.get_meta("gg_steed_used", false)):
		return "The steed has already acted this round"
	if dice_left(f) <= 0:
		return "No Draugr Dice left"
	return ""


## The steed's Dash with a Draugr Die (its Speed + 5 x the roll more to move), or Phantom Charger's action (Dash,
## Disengage or Dodge) with a teleport of up to 60 ft and a Necrotic burst where it lands. `f` is its fighter; on the
## fighter's turn the steed's action for the round is spent (its own turn then has none).
func _steed_act(f: Combatant, steed: Combatant, kind: String, charge: bool, cell: Vector2i, own_turn: bool) -> CombatResult:
	var e := enc()
	if steed == null:
		return CombatResult.fail("No ghost steed")
	if dice_left(f) <= 0:
		return CombatResult.fail("No Draugr Dice left")
	if charge:
		if cell.x < 0 or not e.feature_actions.room_at(steed, cell):
			return CombatResult.fail("Choose an unoccupied square")
		if e.grid.distance_ft(steed.cell, steed.size_cells, cell, steed.size_cells) > 60:
			return CombatResult.fail("At most 60 ft")
		if not e.can_see_space(f, cell, steed.size_cells):
			return CombatResult.fail("You must see where it lands")
	if own_turn:
		var why := e._action_check(steed)
		if why != "":
			return CombatResult.fail(why)
		e.spend_action(steed)
	else:
		steed.set_meta("gg_steed_used", true)
	var roll := _spend_draugr(f, "Phantom Charger" if charge else "Dark Rider's Dash")
	var r := CombatResult.new()
	match kind:
		"disengage":
			steed.disengaged = true
			_log("info", "%s takes the Disengage action" % steed.name(), steed)
		"dodge":
			e.actions.apply_dodge(steed)
		_:
			var extra := steed.speed() + (0 if charge else 5 * roll)
			steed.movement_left += extra
			_log("info", "%s takes the Dash action (+%d ft%s)" % [steed.name(), extra, "" if charge else ", %d from the Draugr Die" % (5 * roll)], steed)
	if charge:
		_phantom_charge(f, steed, cell, roll, r)
	return r


## Phantom Charger: the steed (and its rider) teleports to `cell`; each foe within 10 ft of it there makes a Con save
## against the power DC, taking the die + Con Necrotic, half on a success.
func _phantom_charge(f: Combatant, steed: Combatant, cell: Vector2i, roll: int, r: CombatResult) -> void:
	var e := enc()
	var rider := e.rider_of(steed)
	e.spells._teleport(steed, cell, r)
	if rider != null:
		var from := rider.cell
		rider.cell = steed.cell
		e.events.append({"type": "teleport", "id": rider.id, "from": from, "to": rider.cell, "mounted": true})
	var dmg := maxi(0, roll + f.creature.ability_mod(&"con"))
	var dc := power_dc(f)
	for h in e.hostiles_of(f):
		if not h.is_alive() or e.grid.distance_ft(steed.cell, steed.size_cells, h.cell, h.size_cells) > 10:
			continue
		var ok := _save(h, &"con", dc, "Phantom Charger")
		e.deal_damage(f, h, [{"amount": dmg / 2 if ok else dmg, "type": "necrotic"}], false, "Phantom Charger")


## Soul Reaper: in place of one attack, ghostly hands round a creature within 60 ft: a Strength save against the power
## DC or the Draugr Die + Con Necrotic and Grappled for 1 minute (escape DC = the power DC; the hands hold it where it
## is, nobody drags it); half the damage and nothing more on a success.
func _soul_reaper(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or t == c:
		return CombatResult.fail("Choose a creature within 60 ft")
	e.use_one_attack(c)
	var roll := _spend_draugr(c, "Soul Reaper")
	var dmg := maxi(0, roll + c.creature.ability_mod(&"con"))
	var dc := power_dc(c)
	_log("info", "%s calls ghostly hands round %s (Soul Reaper)" % [c.name(), t.name()], c)
	var dis: Array[String] = []
	var ok := _save(t, &"str", dc, "Soul Reaper", dis, ["save_vs:grappled"] as Array[String])
	e.deal_damage(c, t, [{"amount": dmg / 2 if ok else dmg, "type": "necrotic"}], false, "Soul Reaper")
	if not ok and t.is_alive() and not t.is_down():
		var hold := Effect.new("Grappled (Soul Reaper)", &"feature", HANDS).with_condition(&"grappled")
		hold.caster_id = c.id
		hold.stack_key = "%s:%s" % [HANDS, c.id]
		hold.lasting({"kind": "minutes", "amount": 1})
		hold.turn_owner_id = c.id
		var skill := "athletics" if t.creature.skill_bonus(&"athletics").total() >= t.creature.skill_bonus(&"acrobatics").total() else "acrobatics"
		hold.escape = {"skill": skill, "dc": dc}
		if t.creature.add_effect(hold):
			_log("condition", "Ghostly hands hold %s (escape DC %d)" % [t.name(), dc], t)
			e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## Spectral Shrieking: a creature Soul Reaper holds takes the fighter's PB in Psychic as its turn starts; the fighter's
## Reaction and a Draugr Die add the roll (asked, or by the rule in the class tab).
func _shrieking(c: Combatant) -> CombatResult:
	var e := enc()
	for fx: Effect in c.creature.effects:
		if fx.source_id != HANDS:
			continue
		var f := e.get_c(fx.caster_id)
		if f == null or not f.is_alive() or not has(f, "spectral_shrieking"):
			continue
		var add := {"n": 0}
		var offer := {"kind": "spectral_shrieking", "reactor": f, "trigger": c.id, "default": "ask",
			"title": "Reaction: Spectral Shrieking?",
			"text": "The hands holding %s shriek for %d Psychic. Add a Draugr Die (d%d)?" % [c.name(), f.creature.proficiency_bonus(), draugr_die(f)],
			"cost": "Reaction and a Draugr Die",
			"still": func() -> bool: return e.spells.can_react(f) and dice_left(f) > 0 and c.is_alive(),
			"use": func() -> void:
				f.reaction_available = false
				add["n"] = _spend_draugr(f, "Spectral Shrieking")}
		return e.reactions.offer([offer], func() -> CombatResult:
			if c.is_alive():
				e.deal_damage(f, c, [{"amount": f.creature.proficiency_bonus() + int(add["n"]), "type": "psychic"}], false, "Spectral Shrieking")
			return CombatResult.new(), CombatResult.new())
	return CombatResult.new()


## Grave Guard's cut: the Draugr Die + Con off `before` damage; Death Knell keeps half of what it took off for the one
## who dealt it (dealt once that damage has landed: after_damage).
func _grave_guard(target: Combatant, source: Combatant, before: int, cut: Callable, total: Callable) -> void:
	target.reaction_available = false
	var v := _spend_draugr(target, "Grave Guard") + target.creature.ability_mod(&"con")
	cut.call(maxi(0, v), "Grave Guard")
	var reduced := before - int(total.call())
	_log("reaction", "%s turns aside %d damage (Grave Guard)" % [target.name(), reduced], target)
	if source != null and source != target and has(target, "death_knell") and allowed(target, "death_knell") and reduced / 2 > 0:
		target.set_meta("gg_knell", {"by": source.id, "amount": reduced / 2})


func _grave_guard_ok(c: Combatant) -> bool:
	return has(c, "grave_guard") and enc().spells.can_react(c) and dice_left(c) > 0


# --- Grim Harbinger ---------------------------------------------------------------------------------------------

## The Grim (the book's stat block, per Ranger level): AC 13 + Wis, HP 5 + 5 x level, Speed 40, saves with the ranger's
## PB (Shared Fate), Immune to Necrotic and six conditions, Incorporeal Movement; Ominous Rend uses the ranger's spell
## attack for 1d6 + 3 + Wis Necrotic (Graveyard Hunter: 1d6 more) and frightens; Ghastly Hound adds B/P/S Resistance.
func _grim_block(c: Combatant) -> Dictionary:
	var e := enc()
	var lvl := _ch(c).class_level_of("ranger")
	var wis := c.creature.ability_mod(&"wis")
	var pb := c.creature.proficiency_bonus()
	var atk := (e.spells.numbers(c, {"class_id": "ranger"})["attack"] as Breakdown).total()
	var damage: Array = [{"dice": "1d6+%d" % (3 + wis), "type": "necrotic"}]
	if has(c, "graveyard_hunter"):
		damage.append({"dice": "1d6", "type": "necrotic"})
	var hp := 5 + 5 * lvl
	var block := {"id": "gg_grim", "name": "The Grim", "size": "medium", "type": "undead", "ac": 13 + wis,
		"hp": {"average": hp, "dice": str(hp)}, "speed": {"walk": 40},
		"abilities": {"str": 16, "dex": 16, "con": 14, "int": 14, "wis": 10, "cha": 10},
		"saves": {"str": 3 + pb, "dex": 3 + pb, "con": 2 + pb, "int": 2 + pb, "wis": pb, "cha": pb},
		"immunities": ["necrotic"], "condition_immunities": ["frightened", "grappled", "petrified", "poisoned", "prone", "restrained"],
		"senses": {"darkvision": 60}, "passive_perception": 10, "cr": 0, "xp": 0, "proficiency_bonus": pb, "initiative": 3,
		"summon": true, "gg_grim": true,
		"traits": [
			{"id": "incorporeal_movement", "name": "Incorporeal Movement", "action": "passive",
				"modifiers": [{"stat": "flag", "value": "incorporeal_movement"}],
				"summary": "Moves through creatures and objects as Difficult Terrain; 1d10 Force if it ends its turn inside an object."},
			{"id": "shared_fate", "name": "Shared Fate", "action": "passive", "summary": "Adds its ranger's Proficiency Bonus to its saves."},
			{"id": "baleful_howl", "name": "Baleful Howl", "action": "passive",
				"summary": "Reaction when a creature leaves its reach: a Wisdom save against its ranger's spell save DC or that creature's Speed is 0 for the rest of the turn."}],
		"actions": [{"id": "ominous_rend", "name": "Ominous Rend", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
			"damage": damage, "on_hit": [{"do": "gg_rend_fright"}],
			"summary": "Melee attack with its ranger's spell attack; Necrotic, and the creature is Frightened until the start of the ranger's next turn."}],
		"ai_profile": "brute", "summary": "A spectral hound, the herald of a sealed doom.", "text": "Omen of Doom."}
	if has(c, "ghastly_hound"):
		block["resistances"] = ["bludgeoning", "piercing", "slashing"]
	return block


## The creature `ranger` has doomed, or null.
func doomed_of(ranger: Combatant) -> Combatant:
	if ranger == null or not ranger.has_meta("gg_doomed"):
		return null
	var t := enc().get_c(str(ranger.get_meta("gg_doomed")))
	if t == null or not t.is_alive() or not t.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == DOOM and fx.caster_id == ranger.id):
		return null
	return t


## The ranger whose Omen of Doom `t` bears, or null.
func doomer_of(t: Combatant) -> Combatant:
	for fx: Effect in t.creature.effects:
		if fx.source_id == DOOM:
			var r := enc().get_c(fx.caster_id)
			if r != null and r.is_alive():
				return r
	return null


## Ends `ranger`'s Omen: its mark comes off, its Grim fades, Inescapable Fate is ready again.
func _end_omen(ranger: Combatant, why: String) -> void:
	var e := enc()
	var t := e.get_c(str(ranger.get_meta("gg_doomed", "")))
	if t != null:
		for fx: Effect in t.creature.effects.duplicate():
			if fx.source_id == DOOM and fx.caster_id == ranger.id:
				t.creature.remove_effect(fx)
				e.events.append({"type": "condition", "id": t.id})
	ranger.remove_meta("gg_doomed")
	ranger.remove_meta("gg_fate_spent")
	_vanish(grim_of(ranger), why)


## Omen of Doom: a Bonus Action and a use dooms a creature within 90 ft for an hour and calls the Grim beside it,
## commanded at once (it acts freely on its turn right after the ranger's). A new Omen ends the last; the doom never
## moves to another creature.
func _omen(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or t == c or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 90 ft")
	if c.has_meta("gg_doomed") or grim_of(c) != null:
		_end_omen(c, "a new Omen of Doom")
	_ch(c).spend_resource("omen_of_doom")
	c.bonus_available = false
	var mark := Effect.new("Doomed (Omen of Doom)", &"feature", DOOM)
	mark.caster_id = c.id
	mark.stack_key = "%s:%s" % [DOOM, c.id]
	mark.lasting({"kind": "minutes", "amount": 60})
	mark.turn_owner_id = c.id
	mark.data["mark_by"] = c.id
	mark.data["mark_of"] = "omen_of_doom"
	t.creature.add_effect(mark)
	c.set_meta("gg_doomed", t.id)
	e.events.append({"type": "condition", "id": t.id})
	_log("info", "%s seals the doom of %s (Omen of Doom)" % [c.name(), t.name()], c)
	var g := _call(c, Monster.from_data(_grim_block(c), e.dice), t.cell)
	g.set_meta("gg_commanded", true)
	_log("info", "The Grim rises beside %s" % t.name(), g)
	return CombatResult.new()


## The Grim strikes `t` with Ominous Rend now (a Bonus Action command, or an attack the ranger gave up).
func _rend(c: Combatant, g: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var opt := e.option_by_id(g, "monster:ominous_rend")
	if opt.is_empty():
		return CombatResult.fail("The Grim has no Ominous Rend")
	_log("info", "%s sends the Grim at %s" % [c.name(), t.name()], c)
	return e._resolve_attack(g, t, opt, {})


## Command the Grim (Bonus Action): it strikes `t` now if it's in reach, else it may act freely on its own turn.
func _command(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var g := grim_of(c)
	if g == null:
		return CombatResult.fail("No Grim")
	c.bonus_available = false
	var opt := e.option_by_id(g, "monster:ominous_rend")
	if t != null and not opt.is_empty() and e.attack_legal(g, t, opt) == "":
		return _rend(c, g, t)
	g.set_meta("gg_commanded", true)
	_log("info", "%s commands the Grim: it acts freely on its turn" % c.name(), c)
	return CombatResult.new()


## The Grim's turn: unless commanded (or its ranger is Incapacitated) its action is the Dodge.
func _grim_turn(g: Combatant) -> void:
	var e := enc()
	var ranger := _maker(g)
	if bool(g.get_meta("gg_commanded", false)) or (ranger != null and ranger.creature.has_condition(&"incapacitated")):
		g.remove_meta("gg_commanded")
		return
	e.actions.apply_dodge(g)
	g.action_available = false
	g.attacks_left = 0


## Baleful Howl: a hostile creature moving on its own turn out of the Grim's reach makes a Wisdom save against the
## ranger's spell save DC or its Speed is 0 for the rest of the turn (the Grim's Reaction, used on its own).
func _howl(c: Combatant) -> void:
	var e := enc()
	if c.approach_path.size() < 2 or e.current() != c:
		return
	var from := c.approach_path[-2]
	for g in e.combatants:
		if not _flagged(g, "gg_grim") or not g.is_alive() or not g.hostile_to(c) or not e.spells.can_react(g) or not e.can_see(g, c):
			continue
		var before := e.grid.distance_ft(g.cell, g.size_cells, from, c.size_cells)
		var after := e.grid.distance_ft(g.cell, g.size_cells, c.cell, c.size_cells)
		if before > 5 or after <= 5:
			continue
		var ranger := _maker(g)
		if ranger == null:
			continue
		g.reaction_available = false
		_log("reaction", "The Grim howls as %s breaks away (Baleful Howl)" % c.name(), g)
		if not _save(c, &"wis", e.class_features._spell_dc(ranger, "ranger"), "Baleful Howl"):
			var fx := Effect.new("Rooted by a howl (Baleful Howl)", &"feature", "gg_baleful_howl").with_modifier("speed_set", {"value": 0})
			fx.caster_id = g.id
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = c.id
			c.creature.add_effect(fx)
			c.movement_left = 0
			e.events.append({"type": "condition", "id": c.id})
		return


# --- Warrior of the Pestilent Haze ------------------------------------------------------------------------------

func _monk_dc(c: Combatant) -> int:
	return enc().class_features._spell_dc(c, "monk")


## The Miasmic Plague `monk` laid on `t`, or null.
func _plague_on(t: Combatant, monk: Combatant) -> Effect:
	for fx: Effect in t.creature.effects:
		if fx.source_id == PLAGUE and fx.caster_id == monk.id:
			return fx
	return null


## A Constitution save against the Miasmic Plague (Choking Miasma: with Disadvantage); on a failure `t` is cursed
## for 1 minute: Poisoned, and the monk's Unarmed Strikes add a Martial Arts die of Necrotic once a turn. True when cursed.
## One the monk already cursed makes no new save.
func _plague_save(monk: Combatant, t: Combatant, label: String) -> bool:
	if not t.is_alive() or t.is_down() or _plague_on(t, monk) != null:
		return false
	if _plague_saved(monk, t, label):
		return false
	_curse(monk, t)
	return true


## The plague's Constitution save against the monk's DC (Choking Miasma: Disadvantage): true on a success.
func _plague_saved(monk: Combatant, t: Combatant, label: String) -> bool:
	var dis: Array[String] = []
	if has(monk, "choking_miasma"):
		dis.append("Choking Miasma")
	return _save(t, &"con", _monk_dc(monk), label, dis, ["save_vs:poisoned"] as Array[String])


## The Miasmic Plague's curse on `t` for 1 minute.
func _curse(monk: Combatant, t: Combatant) -> void:
	var fx := Effect.new("Miasmic Plague", &"feature", PLAGUE).with_condition(&"poisoned")
	fx.caster_id = monk.id
	fx.stack_key = "%s:%s" % [PLAGUE, monk.id]
	fx.lasting({"kind": "minutes", "amount": 1})
	fx.turn_owner_id = t.id
	t.creature.add_effect(fx)
	_log("condition", "%s is cursed with %s's Miasmic Plague" % [t.name(), monk.name()], t)
	enc().events.append({"type": "condition", "id": t.id})


## Tolling Censer: a Magic action and 2 Focus Points; each foe within 20 ft makes the plague's Con save: two Martial
## Arts dice of Necrotic and cursed on a failure (one already cursed stays so), half the damage and no curse on a success.
func _censer(c: Combatant) -> CombatResult:
	var e := enc()
	_ch(c).spend_resource("focus_points", 2)
	e.spend_action(c)
	c.magic_action_used = true
	var die := ClassFeatures.martial_die(c)
	_log("info", "%s swings the Tolling Censer: miasma rolls out 20 ft" % c.name(), c)
	for h in e.hostiles_of(c):
		if not h.is_alive() or h.is_down() or e.distance(c, h) > 20:
			continue
		var rolled := e._roll_damage_dice("2d%d" % die, false, 0, "Tolling Censer")
		var saved := _plague_saved(c, h, "Tolling Censer")
		if not saved and _plague_on(h, c) == null:
			_curse(c, h)
		var amount := int(rolled["total"]) / 2 if saved else int(rolled["total"])
		e.deal_damage(c, h, [{"amount": amount, "type": "necrotic"}], false, "Tolling Censer", [str(rolled["text"])])
	return CombatResult.new()


# --- The hotbar -------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	if has(c, "dark_rider"):
		var uses := ch.resource_left("dark_rider")
		var dw := "" if uses > 0 or dice_left(c) > 0 else "No use or Draugr Die left"
		out.append(_act("dark_rider", "Dark Rider", "ghost steed" + ("" if uses > 0 else " · 1 Draugr Die"), "bonus", _first(bw, dw), "none",
			"Bonus Action: call a ghostly warhorse only you can mount (Undead, Resistance to Bludgeoning, Piercing and Slashing; it can only Dash, Disengage or Dodge). Once per Short Rest, or spend a Draugr Die for another."))
	var steed := steed_of(c)
	if steed != null and e.mount_of(c) == steed:
		out.append(_act("draugr_dash", "Steed: Draugr Dash", "Dash + 5 x d%d ft" % draugr_die(c), "free", _steed_why(c, steed), "none",
			"Your steed takes the Dash action (its action this round) and you spend a Draugr Die: its Speed grows by 5 ft per point rolled for the move."))
		if has(c, "phantom_charger"):
			var pc := _act("phantom_charge", "Steed: Phantom Charge", "teleport 60 ft · d%d + %d Necrotic" % [draugr_die(c), c.creature.ability_mod(&"con")], "free",
				_steed_why(c, steed), "point",
				"Your steed takes the Dash (or Disengage, or Dodge: right-click) and you spend a Draugr Die: it teleports you both up to 60 ft; foes within 10 ft of where it lands make a Con save (DC %d) or take the die + Con Necrotic, half on a success." % power_dc(c), 60)
			var picks: Array = []
			for k: String in CHARGES:
				picks.append({"value": k, "label": k.capitalize()})
			pc["choices"] = picks
			pc["choice_label"] = "Steed's action"
			out.append(pc)
	if has(c, "soul_reaper"):
		out.append(_act("soul_reaper", "Soul Reaper", "Str DC %d · d%d + %d Necrotic" % [power_dc(c), draugr_die(c), c.creature.ability_mod(&"con")], "attack",
			_first(e.features_attack_why(c), "" if dice_left(c) > 0 else "No Draugr Dice left"), "enemy",
			"Give up one attack and spend a Draugr Die: ghostly hands seize a creature within 60 ft. Strength save or the die + Con Necrotic and Grappled for 1 minute (escape DC %d); half the damage on a success." % power_dc(c), 60))
	if has(c, "omen_of_doom"):
		out.append(_act("omen", "Omen of Doom", "%d left · 90 ft" % ch.resource_left("omen_of_doom"), "bonus", _first(bw, _res_why(c, "omen_of_doom")), "enemy",
			"Bonus Action: doom a creature within 90 ft (once a turn your hits on it add 1d6 Necrotic) and call the Grim beside it, ready to act. A new Omen ends the last.", 90))
		if grim_of(c) != null:
			out.append(_act("command_grim", "Command the Grim", "Ominous Rend", "bonus", bw, "enemy",
				"Bonus Action: the Grim strikes a creature in its reach now, or (none in reach) acts freely on its turn instead of Dodging.", 120))
			out.append(_act("grim_rend", "Grim: Ominous Rend", "for one of your attacks", "attack", e.features_attack_why(c), "enemy",
				"Give up one of your attacks: the Grim makes its Ominous Rend against a creature in its reach.", 120))
		var lvl := e.spells._lowest_slot(ch, 1)
		if ch.resource_left("omen_of_doom") < ch.resource_max("omen_of_doom"):
			out.append(_act("restore_omen", "Restore Omen of Doom", "a level %d slot" % lvl if lvl > 0 else "a spell slot", "free",
				_first(e._turn_check(c), "" if lvl > 0 else "No spell slots left"), "none", "Spend a spell slot (no action) to regain a use of Omen of Doom."))
	if has(c, "tolling_censer"):
		var tw := _first(aw, "Only one Magic action this turn" if c.magic_action_used else "")
		if tw == "" and ch.resource_left("focus_points") < 2:
			tw = "Needs 2 Focus Points"
		out.append(_act("tolling_censer", "Tolling Censer", "20 ft · 2d%d Necrotic · 2 Focus" % ClassFeatures.martial_die(c), "action", tw, "none",
			"Magic action, 2 Focus Points: foes within 20 ft make a Constitution save (DC %d): two Martial Arts dice of Necrotic and cursed by your Miasmic Plague, or half the damage." % _monk_dc(c)))


func perform(c: Combatant, id: String, t: Combatant, cell: Vector2i, _point: Vector2) -> CombatResult:
	var e := enc()
	match id.trim_prefix(PREFIX):
		"dark_rider":
			return _dark_rider(c)
		"draugr_dash":
			return _steed_act(c, steed_of(c), "dash", false, cell, false)
		"phantom_charge":
			return _steed_act(c, steed_of(c), choice_in if choice_in in CHARGES else "dash", true, cell, false)
		"soul_reaper":
			return _soul_reaper(c, t)
		"omen":
			return _omen(c, t)
		"command_grim":
			return _command(c, t)
		"grim_rend":
			var g := grim_of(c)
			var opt := e.option_by_id(g, "monster:ominous_rend") if g != null else {}
			if g == null or t == null or opt.is_empty() or e.attack_legal(g, t, opt) != "":
				return CombatResult.fail("The Grim must have the creature in its reach")
			e.use_one_attack(c)
			return _rend(c, g, t)
		"restore_omen":
			var lvl := e.spells._lowest_slot(_ch(c), 1)
			if lvl <= 0:
				return CombatResult.fail("No spell slots left")
			_ch(c).expend_slot(lvl)
			_ch(c).restore_resource("omen_of_doom")
			_log("info", "%s spends a level %d slot to renew Omen of Doom" % [c.name(), lvl], c)
			return CombatResult.new()
		"tolling_censer":
			return _censer(c)
	return CombatResult.fail("Not available")


func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has(c, "miasmic_plague"):
		return out
	out.append({"id": PREFIX + "plague", "label": "Miasmic Plague", "sub": "1 Focus · Con save or cursed",
		"why": "" if _ch(c).resource_left("focus_points") > 0 else "No Focus Points left"})
	out.append({"id": PREFIX + "plague_free", "label": "Miasmic Plague (claws)", "sub": "free on a Flurry hit, no claw Necrotic",
		"why": ""})
	return out


## The ghost steed's Draugr actions from its own hotbar, on its own turn.
func special_action(c: Combatant, act: Dictionary, _t: Combatant, cell: Vector2i) -> Variant:
	if not _flagged(c, "gg_dark_steed") or not c.is_player_controlled():
		return null
	var f := _maker(c)
	if f == null:
		return CombatResult.fail("Its rider is gone")
	match str(act.get("do", "")):
		"gg_draugr_dash":
			return _steed_act(f, c, "dash", false, cell, true)
		"gg_phantom_charge":
			return _steed_act(f, c, "dash", true, cell, true)
	return null


## Ominous Rend's fright: Frightened until the start of the ranger's next turn.
func rider(src: Combatant, t: Combatant, rd: Dictionary, _by_type: Dictionary, _act_name: String) -> bool:
	if str(rd.get("do", "")) != "gg_rend_fright":
		return false
	var ranger := _maker(src)
	var fx := Effect.new("Frightened (Ominous Rend)", &"monster", "gg_ominous_rend").with_condition(&"frightened")
	fx.caster_id = src.id
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = ranger.id if ranger != null else src.id
	if t.creature.add_effect(fx):
		_log("condition", "%s is Frightened by the Grim" % t.name(), t)
	return true


# --- Attacks and damage -----------------------------------------------------------------------------------------

func hit_dice(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Omen of Doom: once a turn, a hit on the doomed adds 1d6 Necrotic.
	if has(c, "omen_of_doom") and doomed_of(c) == target and _once_per_turn(c, "gg_doom_hit"):
		out.append({"dice": "1d6", "type": "necrotic", "label": "Omen of Doom"})
	if not _unarmed(option) or not has(c, "claws_of_pestilence"):
		return out
	var die := ClassFeatures.martial_die(c)
	var flurry := str(c.get_meta("flurry_turn", "")) == _turn_key()
	var claws := flurry
	# Miasmic Plague, armed: free on a Flurry hit for the claws' die, else for a Focus Point.
	if has(c, "miasmic_plague") and _plague_on(target, c) == null:
		if flurry and PREFIX + "plague_free" in c.armed:
			c.armed.erase(PREFIX + "plague_free")
			claws = false
			st["gg_plague"] = true
		elif PREFIX + "plague" in c.armed and _ch(c).resource_left("focus_points") > 0:
			c.armed.erase(PREFIX + "plague")
			_ch(c).spend_resource("focus_points")
			st["gg_plague"] = true
	if claws:
		out.append({"dice": "1d%d" % die, "type": "necrotic", "label": "Claws of Pestilence"})
	# A creature the plague curses takes a Martial Arts die of Necrotic from the monk's Unarmed Strikes once a turn.
	if _plague_on(target, c) != null and _once_per_turn(target, ClassFeatures.meta_key("gg_plague_hit_" + c.id)):
		out.append({"dice": "1d%d" % die, "type": "necrotic", "label": "Miasmic Plague"})
	return out


func after_hit(c: Combatant, target: Combatant, _option: Dictionary, st: Dictionary, _r: CombatResult) -> void:
	if bool(st.get("gg_plague", false)):
		st.erase("gg_plague")
		_plague_save(c, target, "Miasmic Plague")


func against_damage(st: Dictionary, total: Callable, cut: Callable, out: Array) -> void:
	var target := st["target"] as Combatant
	var c := st["c"] as Combatant
	if not _grave_guard_ok(target):
		return
	out.append({"kind": "grave_guard", "reactor": target, "trigger": c.id, "default": "ask",
		"title": "Reaction: Grave Guard?",
		"text": func() -> String: return "%s hits %s for %d. Spend a Draugr Die to cut it by d%d + %d?" % [c.name(), target.name(), total.call(), draugr_die(target), target.creature.ability_mod(&"con")],
		"cost": "Reaction and a Draugr Die",
		"still": func() -> bool: return _grave_guard_ok(target) and int(total.call()) > 0,
		"use": func() -> void: _grave_guard(target, c, int(total.call()), cut, total)})


## Damage about to land: Grave Guard on Automatic against damage that isn't an attack's (spells, hazards), Claws of
## Pestilence's Slashing, Mortal Reminder's Necrotic (each only when it does more), and Mounting Dread for the Grim.
func adjust_incoming(source: Combatant, target: Combatant, ps: Array) -> void:
	if str(target.reaction_rules.get("grave_guard", "ask")) == "auto" and _grave_guard_ok(target):
		var sum := func() -> int:
			var n := 0
			for p: Variant in ps:
				n += maxi(0, int((p as Dictionary)["amount"]))
			return n
		var cut := func(amount: int, _why: String) -> void:
			var left := amount
			for p: Variant in ps:
				var d := p as Dictionary
				var take := mini(left, maxi(0, int(d["amount"])))
				d["amount"] = int(d["amount"]) - take
				left -= take
		if int(sum.call()) > 0:
			_grave_guard(target, source, int(sum.call()), cut, sum)
	if source == null:
		return
	if has(source, "claws_of_pestilence") and allowed(source, "claws_of_pestilence"):
		for p: Variant in ps:
			var d := p as Dictionary
			if str(d.get("item", "")) == "unarmed_strike" and str(d["type"]) == "bludgeoning" and _more_as(target, d, "slashing", false):
				d["type"] = "slashing"
	if has(source, "mortal_reminder") and doomed_of(source) == target:
		var dread := has(source, "mounting_dread")
		for p: Variant in ps:
			var d := p as Dictionary
			if str(d["type"]) != "necrotic" and _more_as(target, d, "necrotic", dread):
				d["type"] = "necrotic"
				if dread:
					d["ignore_resistance"] = true
					d["ignore_source"] = "Mounting Dread"
	if _flagged(source, "gg_grim") and has(_maker(source), "mounting_dread"):
		for p: Variant in ps:
			var d := p as Dictionary
			if str(d["type"]) == "necrotic":
				d["ignore_resistance"] = true
				d["ignore_source"] = "Mounting Dread"


## Whether the part `d` would hurt `t` more as `type` (Resistance ignored with `ignore`).
static func _more_as(t: Combatant, d: Dictionary, type: String, ignore: bool) -> bool:
	var now := t.creature.preview_damage_parts([d]).final
	var other := d.duplicate()
	other["type"] = type
	if ignore:
		other["ignore_resistance"] = true
	return t.creature.preview_damage_parts([other]).final > now


## Death Knell: what Grave Guard turned aside comes back on its dealer as Psychic, half of it.
func after_damage(_source: Combatant, target: Combatant, _amount: int, _ps: Array = [], _dr: DamageResult = null) -> void:
	if not target.has_meta("gg_knell"):
		return
	var k := target.get_meta("gg_knell") as Dictionary
	target.remove_meta("gg_knell")
	var by := enc().get_c(str(k["by"]))
	if by != null and by.is_alive():
		_log("info", "The dead wail back at %s (Death Knell)" % by.name(), target)
		enc().deal_damage(target, by, [{"amount": int(k["amount"]), "type": "psychic"}], false, "Death Knell")


## A death: Mortal Coil (a living foe dying within 30 ft gives a Barrow Guard a spent die back, its Reaction), the
## doomed or its ranger dying ends the Omen, a fighter dying sends its steed away.
func on_death(_source: Combatant, dead: Combatant) -> void:
	var e := enc()
	for f in e.combatants:
		if f == dead or not f.is_alive() or not has(f, "mortal_coil") or not allowed(f, "mortal_coil") or not f.hostile_to(dead):
			continue
		if dead.creature.creature_type in [&"construct", &"undead"] or e.distance(f, dead) > 30:
			continue
		var ch := _ch(f)
		if ch.resource_left("draugr_dice") >= ch.resource_max("draugr_dice") or not e.spells.can_react(f):
			continue
		f.reaction_available = false
		ch.restore_resource("draugr_dice")
		_log("reaction", "%s draws in the fleeing soul of %s: a Draugr Die back (Mortal Coil)" % [f.name(), dead.name()], f)
	var ranger := doomer_of(dead)
	if ranger != null:
		_end_omen(ranger, "its doomed is dead")
	if dead.has_meta("gg_doomed"):
		_end_omen(dead, "its ranger is dead")
	_vanish(steed_of(dead), "its rider is dead")


# --- Turns and D20 Tests ----------------------------------------------------------------------------------------

func turn_start(c: Combatant) -> CombatResult:
	_riders_check()
	if _flagged(c, "gg_dark_steed") and bool(c.get_meta("gg_steed_used", false)):
		c.remove_meta("gg_steed_used")
		c.action_available = false
		_log("info", "%s already acted on its rider's turn" % c.name(), c)
	if _flagged(c, "gg_grim"):
		_grim_turn(c)
	return _shrieking(c)


## The end of a cursed creature's turn: a Con save (Choking Miasma: Disadvantage) ends the Miasmic Plague.
func turn_end(c: Combatant) -> void:
	var e := enc()
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id != PLAGUE or not fx in c.creature.effects:
			continue
		var monk := e.get_c(fx.caster_id)
		var dis: Array[String] = []
		if monk != null and has(monk, "choking_miasma"):
			dis.append("Choking Miasma")
		var dc := _monk_dc(monk) if monk != null else 10
		if _save(c, &"con", dc, "Miasmic Plague", dis, ["save_vs:poisoned"] as Array[String]):
			c.creature.remove_effect(fx)
			_log("info", "%s shakes off the Miasmic Plague" % c.name(), c)
			e.events.append({"type": "condition", "id": c.id})


## Dark Rider's steed fades when its fighter is Incapacitated.
func _riders_check() -> void:
	for f in enc().combatants:
		if f.is_alive() and f.creature.has_condition(&"incapacitated"):
			_vanish(steed_of(f), "its rider can't hold it")


func effect_added(cr: Creature, _fx: Effect) -> void:
	var e := enc()
	var c := e.get_c(cr.id) if e != null else null
	if c != null and c.creature == cr and cr.has_condition(&"incapacitated"):
		_vanish(steed_of(c), "its rider can't hold it")


## Step of the Wind with a Focus Point starts Scurrying Spread for the rest of the turn.
func after_action(c: Combatant, action: Dictionary, _targets: Array = []) -> void:
	if has(c, "scurrying_spread") and str(action.get("id", "")).ends_with("step_of_the_wind_focus"):
		c.set_meta("gg_scurry", _turn_key())
		_log("info", "%s scurries off in a cloud of plague (Scurrying Spread)" % c.name(), c)


## Each step: Baleful Howl against one leaving a Grim's reach; Scurrying Spread's save for each foe the monk comes
## within 5 ft of (once a turn each).
func entered_cell(c: Combatant, _cell: Vector2i) -> void:
	var e := enc()
	_howl(c)
	if str(c.get_meta("gg_scurry", "")) != _turn_key() or not has(c, "scurrying_spread"):
		return
	for h in e.hostiles_of(c):
		if h.is_alive() and not h.is_down() and e.distance(c, h) <= 5 and _plague_on(h, c) == null and _once_per_turn(h, ClassFeatures.meta_key("gg_scurried_" + c.id)):
			_plague_save(c, h, "Scurrying Spread")


func d20_offers(c: Combatant, t: D20Test, _keys: Array[String], out: Array) -> void:
	var e := enc()
	# Whisper of the Departed: a Draugr Die added to the fighter's own failed check.
	if t.kind == D20Test.Kind.ABILITY_CHECK and t.target > 0 and has(c, "whisper_of_the_departed") and dice_left(c) > 0:
		var die := draugr_die(c)
		var once := {"used": false}
		out.append({"kind": "whisper_of_the_departed", "reactor": c, "default": "ask", "sync": "explicit",
			"title": "Whisper of the Departed?", "text": "%s. Spend a Draugr Die and add d%d?" % [D20Responses.line(c, t), die],
			"cost": "A Draugr Die (%d left)" % dice_left(c), "spends_reaction": false,
			"still": func() -> bool: return not bool(once["used"]) and not t.success and dice_left(c) > 0 and t.total + die >= t.target,
			"helps": func() -> bool: return t.total + die >= t.target,
			"use": func() -> void:
				once["used"] = true
				var v := _spend_draugr(c, "Whisper of the Departed")
				t.add_bonus(v, "Whisper of the Departed")})
	# Inescapable Fate: the doomed's successful save, rerolled with Disadvantage (the ranger's Reaction).
	if t.kind != D20Test.Kind.SAVING_THROW or not t.success or t.target <= 0:
		return
	var ranger := doomer_of(c)
	if ranger == null or not has(ranger, "inescapable_fate") or bool(ranger.get_meta("gg_fate_spent", false)):
		return
	out.append({"kind": "inescapable_fate", "reactor": ranger, "trigger": c.id, "default": "auto",
		"title": "Reaction: Inescapable Fate?", "text": "%s. Force a reroll with Disadvantage?" % D20Responses.line(c, t),
		"cost": "Reaction",
		"still": func() -> bool: return t.success and e.spells.can_react(ranger) and not bool(ranger.get_meta("gg_fate_spent", false)),
		"use": func() -> void:
			ranger.reaction_available = false
			var rolls := e.dice.roll(20, 2, "Inescapable Fate")
			t.set_natural(mini(rolls[0], rolls[1]), "Inescapable Fate (%d, %d)" % [rolls[0], rolls[1]])
			if not t.success:
				ranger.set_meta("gg_fate_spent", true)
			_log("reaction", "%s seals %s's fate: a reroll with Disadvantage (Inescapable Fate)" % [ranger.name(), c.name()], ranger, [t.describe()])})
