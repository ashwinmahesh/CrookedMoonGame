class_name CmHeirloomsRelics
extends CmHeirloomPart
## The Fabled Heirlooms of Memory's Rest (R17), Hartsblight Forest (R18) and Maidenmist Cemetery (R19) whose properties need
## code: the Mask of Lethica Nightborne, the Veil of the Weeping Widow, the Staff of Farryn of the Greenwood, the Idol of the
## Beast of Blight, the Shovel of Yorgrim and the Lantern of the Chained Reaper. Bonuses, Resistances and the spells they cast
## as they are are data (data/magic_items). Legendary properties (level 13, after these chapters) wait: docs/rules/deviations.md.

const MASK := "mask_of_lethica_nightborne"
const VEIL := "veil_of_the_weeping_widow"
const STAFF := "staff_of_farryn"
const IDOL := "idol_of_the_beast_of_blight"
const SHOVEL := "shovel_of_yorgrim"
const LANTERN := "lantern_of_the_chained_reaper"

const SERVANT := "cm_staff_servant"
const CYCLE := "cm_staff_cycle"
const OBLIVION := "cm_idol_oblivion"
const ROT := "cm_idol_rot"
const KENNING := "cm_shovel_kenning"
const SPIRIT := "cm_lantern_spirit"

const CYCLE_HIT_META := "cm_cycle_hit"
const CYCLE_BURST_META := "cm_cycle_burst"
const OBLIVION_META := "cm_oblivion"
const KENNING_META := "cm_kenning"
const ROT_KEY := "cm_rot_in_the_flesh"
const SPORES_KEY := "cm_spores"


func handles_item_power(custom: String) -> bool:
	return custom in [SERVANT, CYCLE, OBLIVION, ROT, KENNING, SPIRIT]


func item_power_why(c: Combatant, p: Dictionary) -> String:
	match str((p["power"] as Dictionary).get("custom", "")):
		OBLIVION:
			if not c.bonus_available:
				return "No Bonus Action left"
			return "" if _fresh_corpse(c) != null else "No fresh corpse within 5 ft"
		KENNING:
			if not c.bonus_available:
				return "No Bonus Action left"
			return "" if _kenning_target(c) != null else "Hit an Undead with the shovel this turn first"
	return ""


func item_power_use(c: Combatant, p: Dictionary, targets: Array, point: Vector2, _opts: Dictionary) -> CombatResult:
	match str((p["power"] as Dictionary).get("custom", "")):
		SERVANT:
			return _servant(c, p, targets, point)
		CYCLE:
			return _cycle(c, p, targets, point)
		OBLIVION:
			return _oblivion(c)
		ROT:
			return _rot(c, p)
		KENNING:
			return _kenning(c)
		SPIRIT:
			return _spirit(c, p)
	return CombatResult.fail("Not available")


## Casts the spell of an item power that the game also follows up (`custom` beside `spell`), as the engine would.
func _cast_power(c: Combatant, p: Dictionary, targets: Array, point: Vector2) -> CombatResult:
	var e := enc()
	var power := p["power"] as Dictionary
	var spell := Compendium.shared().spell_data(str(power.get("spell", "")))
	if spell.is_empty():
		return CombatResult.fail("Not available yet")
	var lvl := int(power.get("level", spell.get("level", 0)))
	var label := "%s (%s)" % [spell.get("name", ""), (p["data"] as Dictionary).get("name", "")]
	return e.items.cast(c, spell, lvl, targets, point, Vector2.ZERO, e.items.numbers(c, p, lvl), CombatItems.power_cost(power, spell), {}, label)


# --- Mask of Lethica Nightborne -----------------------------------------------------------------------------------

## Soothing Darkness: in Darkness its bearer cast, the bearer and its allies resist Psychic damage. Deny Death's Touch
## (Shovel, Very Rare): the bearer and allies within 10 ft resist Necrotic damage. The Staff's Servant of the Cycle adds
## its 1d10 Necrotic to the bearer's next hit.
func adjust_incoming(source: Combatant, target: Combatant, parts: Array) -> void:
	if target == null or parts.is_empty():
		return
	var e := enc()
	for b in e.combatants:
		if not b.is_alive() or (b != target and not b.allied_with(target)):
			continue
		if holds(b, MASK) and _in_darkness_of(b, target) and halve(target, parts, "psychic"):
			_log("info", "The mask's darkness soothes %s's mind (Psychic halved, Soothing Darkness)" % target.name(), target)
		if holds_at(b, SHOVEL, 2) and e.distance(b, target) <= 10 and halve(target, parts, "necrotic"):
			_log("info", "Yorgrim's shovel denies death's touch to %s (Necrotic halved)" % target.name(), target)
	if source != null and source.has_meta(CYCLE_HIT_META) and str(e.hit_context.get("attacker", "")) == source.id \
			and str(e.hit_context.get("target", "")) == target.id and source.hostile_to(target):
		source.remove_meta(CYCLE_HIT_META)
		var rolled := e._roll_damage_dice("1d10", false, 0, "Servant of the Cycle")
		var extra := {"amount": int(rolled["total"]), "type": "necrotic"}
		for k: String in ["weapon", "spell", "melee"]:
			if (parts[0] as Dictionary).has(k):
				extra[k] = (parts[0] as Dictionary)[k]
		parts.append(extra)
		_log("info", "The cycle turns: %d Necrotic more to %s (Servant of the Cycle)" % [int(rolled["total"]), target.name()], source, [str(rolled["text"])])


## Whether `t` stands in magical Darkness `b` cast.
func _in_darkness_of(b: Combatant, t: Combatant) -> bool:
	for o in enc().spells.zones.objects:
		if o.expired() or not bool(o.rule("darkness", false)) or o.caster_id != b.id:
			continue
		for cell in t.footprint():
			if cell in o.cells:
				return true
	return false


## Balm of Midnight (Very Rare): at the start of the mask bearer's turn, the nearest Frightened ally within 60 ft (or the
## bearer) makes a DC 15 Wisdom save to end it, and gains 2d10 Temporary Hit Points if it stands in magical Darkness.
func turn_start(c: Combatant) -> CombatResult:
	if not holds_at(c, MASK, 2) or c.is_down():
		return CombatResult.new()
	var e := enc()
	var best: Combatant = null
	var group: Array[Combatant] = [c]
	group.append_array(e.allies_of(c))
	for a in group:
		if a.creature.has_condition(&"frightened") and e.distance(c, a) <= 60 and (best == null or e.distance(c, a) < e.distance(c, best)):
			best = a
	if best == null:
		return CombatResult.new()
	_log("info", "%s's mask whispers a balm of midnight to %s" % [c.name(), best.name()], c)
	if saves(best, &"wis", 15, "Balm of Midnight"):
		e.spells.cure(best, &"frightened")
		_log("info", "%s's fear lifts (Balm of Midnight)" % best.name(), best)
	if in_darkness(best):
		var rolled := e._roll_damage_dice("2d10", false, 0, "Balm of Midnight")
		best.creature.add_temp_hp(int(rolled["total"]), "Balm of Midnight")
		_log("heal", "%s gains %d Temporary Hit Points in the dark (Balm of Midnight)" % [best.name(), int(rolled["total"])], best)
	return CombatResult.new()


# --- Veil of the Weeping Widow; the Staff's burst -----------------------------------------------------------------

## Psychic Shock (Veil, Very Rare): made to save against a charm or a fear, the bearer's Reaction deals 2d8 Psychic to
## whoever forced it. Cycle's Balance (Staff): the next save failed against its bearer's spell bursts.
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	if t.kind != D20Test.Kind.SAVING_THROW or "death_save" in keys:
		return
	if holds_at(c, VEIL, 2) and ("save_vs:charmed" in keys or "save_vs:frightened" in keys) and e.spells.can_react(c):
		var src := save_source(c, keys)
		if src != null and src.is_alive() and c.hostile_to(src):
			out.append({"kind": "cm_psychic_shock", "reactor": c, "trigger": src.id, "default": "auto",
				"title": "Reaction: Psychic Shock?",
				"text": "%s reaches into %s's mind. Lash back through the veil for 2d8 Psychic?" % [src.name(), c.name()],
				"cost": "Reaction (Veil of the Weeping Widow)",
				"still": func() -> bool: return e.spells.can_react(c) and src.is_alive(),
				"use": func() -> void: _psychic_shock(c, src)})
	for k in keys:
		if not k.begins_with("save_vs:spell:"):
			continue
		var caster := e.get_c(k.substr(14))
		if caster == null or not caster.has_meta(CYCLE_BURST_META) or not holds_at(caster, STAFF, 2) or not caster.hostile_to(c):
			continue
		if e.round_no > int(caster.get_meta(CYCLE_BURST_META, 0)):
			caster.remove_meta(CYCLE_BURST_META)
			continue
		out.append({"kind": "cm_cycle_burst", "reactor": caster, "forced": true,
			"use": func() -> void: _cycle_burst(caster, c, t)})
		return


func _psychic_shock(c: Combatant, src: Combatant) -> void:
	c.reaction_available = false
	_log("reaction", "%s's grief lashes back at %s (Psychic Shock)" % [c.name(), src.name()], c)
	hurt(c, src, "2d8", "psychic", "Psychic Shock")


## Cycle's Balance: the failed save bursts with 4d10 Necrotic on the bearer's foes within 20 ft of the creature.
func _cycle_burst(caster: Combatant, c: Combatant, t: D20Test) -> void:
	if t.success or not caster.has_meta(CYCLE_BURST_META):
		return
	caster.remove_meta(CYCLE_BURST_META)
	var e := enc()
	_log("info", "Rot blooms from %s: the cycle balances (Cycle's Balance)" % c.name(), caster)
	var rolled := e._roll_damage_dice("4d10", false, 0, "Cycle's Balance")
	for o in e.hostiles_of(caster):
		if not o.is_down() and e.distance(c, o) <= 20:
			e.deal_damage(caster, o, [{"amount": int(rolled["total"]), "type": "necrotic"}], false, "Cycle's Balance", [str(rolled["text"])])


# --- Staff of Farryn of the Greenwood -----------------------------------------------------------------------------

## Servant of the Cycle: Cure Wounds at 3rd level (three a dusk), and the bearer's next hit deals 1d10 Necrotic more.
func _servant(c: Combatant, p: Dictionary, targets: Array, point: Vector2) -> CombatResult:
	var r := _cast_power(c, p, targets, point)
	if r.ok:
		c.set_meta(CYCLE_HIT_META, true)
	return r


## Cycle's Balance (Very Rare): Revivify once a dusk; for an hour after, the next creature to fail a save against the
## bearer's spell bursts with rot.
func _cycle(c: Combatant, p: Dictionary, targets: Array, point: Vector2) -> CombatResult:
	var r := _cast_power(c, p, targets, point)
	if r.ok:
		c.set_meta(CYCLE_BURST_META, enc().round_no + 600)
	return r


## Sacrifice of Flesh (Very Rare, a toggle on the staff): while it's on, the bearer's healing spell costs it twice the
## spell's level in Necrotic damage (its Resistance doesn't help) and heals the target three times what it took.
func spell_healing(ctx: Dictionary, t: Combatant) -> int:
	var c := ctx.get("c") as Combatant
	var slot := int(ctx.get("slot", 0))
	if c == null or t == null or t == c or slot <= 0 or bool(ctx.get("cm_sacrificed", false)) or not holds_at(c, STAFF, 2) \
			or not enc().items.toggled(c, STAFF, "sacrifice"):
		return 0
	ctx["cm_sacrificed"] = true
	var dr := enc().deal_damage(c, c, [{"amount": 2 * slot, "type": "necrotic", "ignore_resistance": true}], false, "Sacrifice of Flesh")
	if dr.final <= 0:
		return 0
	_log("heal", "%s gives %d of their own flesh: %s heals %d more (Sacrifice of Flesh)" % [c.name(), dr.final, t.name(), 3 * dr.final], c)
	return 3 * dr.final


# --- Idol of the Beast of Blight ----------------------------------------------------------------------------------

## Rotting Touch: the bearer's Unarmed Strikes deal 1d6 Necrotic more (1d8 Very Rare, 1d10 Legendary).
func hit_dice(c: Combatant, _target: Combatant, option: Dictionary, _st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _unarmed(option) and holds(c, IDOL):
		out.append({"dice": ["1d6", "1d8", "1d10"][tier(c) - 1], "type": "necrotic", "label": "Rotting Touch"})
	return out


static func _unarmed(option: Dictionary) -> bool:
	return option.has("profile") and (option["profile"] as WeaponProfile).item_id == "unarmed_strike"


## Touch of Oblivion: the Bonus Action over a fresh corpse makes the bearer's next Unarmed Strike hit a Critical Hit.
func after_hit_target(st: Dictionary, _miss: Callable, _out: Array) -> void:
	var c := st["c"] as Combatant
	if bool(st["critical"]) or not c.has_meta(OBLIVION_META) or not _unarmed(st["option"] as Dictionary):
		return
	c.remove_meta(OBLIVION_META)
	st["critical"] = true
	_log("info", "Oblivion's touch: %s's strike lands as a Critical Hit" % c.name(), c)


func _oblivion(c: Combatant) -> CombatResult:
	var corpse := _fresh_corpse(c)
	if corpse == null:
		return CombatResult.fail("No fresh corpse within 5 ft")
	enc().items._pay(c, "bonus")
	corpse.set_meta("cm_oblivion_spent", true)
	c.set_meta(OBLIVION_META, true)
	var r := CombatResult.new()
	r.lines.append(enc().log.add("info", "%s draws oblivion from %s's body: the next Unarmed Strike that hits is a Critical Hit" % [c.name(), corpse.name()], c.id))
	return r


## A creature that died in this fight, within 5 ft, not drawn on yet.
func _fresh_corpse(c: Combatant) -> Combatant:
	var e := enc()
	for o in e.combatants:
		if o != c and o.creature.dead and str(o.get_meta("left_fight", "")) == "" and not o.has_meta("cm_oblivion_spent") and e.distance(c, o) <= 5:
			return o
	return null


## Rot in the Flesh (Very Rare): Barkskin on the bearer once a dusk, and while it lasts a creature that hits the bearer in
## melee takes 1d8 Necrotic.
func _rot(c: Combatant, p: Dictionary) -> CombatResult:
	var r := _cast_power(c, p, [c], Vector2.INF)
	if r.ok:
		var fx := item_fx(c, "Rot in the Flesh", IDOL, ROT_KEY)
		fx.lasting({"kind": "hours", "amount": 1})
		c.creature.add_effect(fx)
	return r


## Rot in the Flesh strikes back; Death-Kenning readies on a shovel's hit on an Undead.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, _st: Dictionary, _r: CombatResult) -> void:
	if target == null:
		return
	if fx_of(target, ROT_KEY) != null and bool(option.get("melee", false)) and c.is_alive() and c.hostile_to(target):
		hurt(target, c, "1d8", "necrotic", "Rot in the Flesh")
	if option.has("profile") and (option["profile"] as WeaponProfile).item_id == SHOVEL and target.creature.creature_type == &"undead" \
			and holds(c, SHOVEL):
		c.set_meta(KENNING_META, "%s>%s" % [_turn_key(), target.id])


## Hallucinatory Spores (Very Rare): after the bearer casts a spell with a slot, the nearest foe within 10 ft makes a
## Wisdom save against the heirloom's DC or takes 2d6 Psychic and has Disadvantage on attack rolls until its turn ends.
func after_cast(c: Combatant, _s: Dictionary, slot: int, free: bool = false, _ctx: Dictionary = {}) -> void:
	if slot <= 0 or free or not holds_at(c, IDOL, 2):
		return
	var e := enc()
	var best: Combatant = null
	for o in e.hostiles_of(c):
		if not o.is_down() and e.distance(c, o) <= 10 and (best == null or e.distance(c, o) < e.distance(c, best)):
			best = o
	if best == null:
		return
	_log("info", "Spores burst from %s's idol at %s (Hallucinatory Spores)" % [c.name(), best.name()], c)
	if saves(best, &"wis", heirloom_dc(c), "Hallucinatory Spores"):
		return
	hurt(c, best, "2d6", "psychic", "Hallucinatory Spores")
	if best.is_alive():
		var fx := item_fx(c, "Hallucinatory Spores", IDOL, SPORES_KEY).with_modifier("disadvantage", {"on": ["attack"]})
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = best.id
		best.creature.add_effect(fx)


# --- Shovel of Yorgrim --------------------------------------------------------------------------------------------

## Death-Kenning: after the shovel hits an Undead, a Bonus Action learns its defences (as a successful Study).
func _kenning(c: Combatant) -> CombatResult:
	var e := enc()
	var t := _kenning_target(c)
	if t == null:
		return CombatResult.fail("Hit an Undead with the shovel this turn first")
	e.items._pay(c, "bonus")
	c.remove_meta(KENNING_META)
	var info: Array[String] = []
	if t.creature is Monster:
		var m := t.creature as Monster
		e.studied[str(m.data.get("id", ""))] = true
		for k: String in ["resistances", "vulnerabilities", "immunities", "condition_immunities"]:
			var v := m.data.get(k, []) as Array
			if not v.is_empty():
				info.append("%s: %s" % [k.replace("_", " ").capitalize(), ", ".join(v)])
	var r := CombatResult.new()
	r.lines.append(e.log.add("info", "%s reads the grave-dirt on %s: its defences are known (Death-Kenning)" % [c.name(), t.name()], c.id, info))
	return r


func _kenning_target(c: Combatant) -> Combatant:
	var mark := str(c.get_meta(KENNING_META, ""))
	if mark.get_slice(">", 0) != _turn_key():
		return null
	var t := enc().get_c(mark.get_slice(">", 1))
	return t if t != null and t.is_alive() else null


# --- Lantern of the Chained Reaper --------------------------------------------------------------------------------

## Summon Spirit (Very Rare): a Ghost answers the lantern and fights beside its bearer for a minute, once a dusk.
func _spirit(c: Combatant, p: Dictionary) -> CombatResult:
	var e := enc()
	var block := Compendium.shared().monster_data("ghost").duplicate(true)
	if block.is_empty():
		return CombatResult.fail("Not available yet")
	block["name"] = "Lantern Spirit"
	e.items._pay(c, "magic")
	var spell := {"id": SPIRIT, "name": "Summon Spirit", "duration": {"kind": "minutes", "amount": 1}}
	var ctx := {"c": c, "s": spell, "slot": 0, "nums": e.items.numbers(c, p, 0), "conc": null, "opts": {}, "summon_block": block}
	var r := CombatResult.new()
	e.spells.summons._summon(ctx, Vector2i(-1, -1), r)
	r.lines.append(e.log.add("info", "Blue-green fire gutters in %s's lantern: a spirit steps out of it" % c.name(), c.id))
	return r
