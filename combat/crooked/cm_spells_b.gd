class_name CmSpellsB
extends CmPart
## The Crooked Moon's code for the other twenty of the book's spells (chapter 7), Harrowing Ballad to Veil of the Reaper: the parts of them data can't say.
## CrookedFeatures forwards every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start
## "sb_".
##
## Summer Winds and Scarlet Dawn split one area into healing and harm by side or creature type; Harrowing Ballad leaves
## a creature of Intelligence 3 or lower alone; Hungering Blade feeds on the first hit each turn; Intrusive Despair
## wastes a cursed creature's Attack or Magic action on a failed Wisdom save and ends after three successes; Isolation
## hides every other creature from its target; Martyr trades the caster's life for a dead creature's; Mirrored Agony and
## Sacrificial Siphon are Reactions to damage; Mist of Mourning's -1d8 reaches every damage roll, not only weapons';
## Murder of Crows' blindness ends with any healing; Puppet Master's puppet walks to the creature it must strike;
## Sanguine Secrets reads a creature and gives one Advantage against it; Veil of the Reaper hides its caster after a hit.
## Sanctum of the Flock and Sanctum of the Shepherd work only at a Long Rest (out of fight) and are not here.

const PREFIX := "sb_"

## The conditions Sanguine Secrets asks after (immunities).
const CONDITIONS: Array[String] = ["blinded", "charmed", "deafened", "exhaustion", "frightened", "grappled", "incapacitated",
	"invisible", "paralyzed", "petrified", "poisoned", "prone", "restrained", "stunned", "unconscious"]


func prefix() -> String:
	return PREFIX


## The effect spell `spell_id` put on `cr` (the given caster's, when `caster_id` is set), or null.
static func _spell_fx(cr: Creature, spell_id: String, caster_id: String = "") -> Effect:
	for fx: Effect in cr.effects:
		if fx.source_id == spell_id and (caster_id == "" or fx.caster_id == caster_id):
			return fx
	return null


## Ends `caster`'s spell `spell_id` (its Concentration), or only `fx` on `holder` when nothing else holds it.
func _end_spell(caster: Combatant, spell_id: String, fx: Effect, holder: Creature, why: String) -> void:
	if caster != null and caster.creature.concentration != null and caster.creature.concentration.source_id == spell_id:
		caster.creature.concentration.end(why)
	elif fx != null and holder != null:
		holder.remove_effect(fx)
	enc().spells.zones.prune()


# --- Spells resolved here -----------------------------------------------------------------------------------------

## Summer Winds, Scarlet Dawn, Harrowing Ballad's Intelligence gate and Martyr. True when handled.
func resolve_spell(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> bool:
	match str((ctx["s"] as Dictionary)["id"]):
		"summer_winds":
			_summer_winds(ctx, cells, r)
			return true
		"scarlet_dawn":
			_scarlet_dawn(ctx, cells, r)
			return true
		"harrowing_ballad":
			return _ballad_unheard(tgt, r)
		"martyr":
			if not tgt.is_empty():
				martyr(ctx, tgt[0], r)
			return true
	return false


## Summer Winds: the caster's allies in the Cone regain Hit Points; only Undead hostile to the caster make the
## Constitution save against the Radiant damage. Anyone else in it is untouched.
func _summer_winds(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var undead: Array[Combatant] = []
	for t in e.spells._area_victims(c, s, cells):
		if t == c:
			continue
		if c.allied_with(t):
			e.spells.damage._heal(ctx, t, r)
		elif c.hostile_to(t) and t.creature.creature_type == &"undead":
			undead.append(t)
	if not undead.is_empty():
		e.spells._save_spell(ctx, undead, r)


## Scarlet Dawn: Constructs and Undead in the Cylinder regain 4d10 Hit Points; every other creature in it, friend or
## foe, makes the Constitution save against the Necrotic damage. Its light (the zone) dispels overlapping Darkness of
## the slot's level or lower as it falls (`dispels_darkness`) and fades at the end of the caster's turn.
func _scarlet_dawn(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	e.spells._place_zone(ctx, cells, r)
	var living: Array[Combatant] = []
	for t in e.spells._area_victims(c, s, cells):
		if t.creature.creature_type in [&"construct", &"undead"]:
			e.spells.damage._heal(ctx, t, r)
		else:
			living.append(t)
	if not living.is_empty():
		e.spells._save_spell(ctx, living, r)


## Harrowing Ballad: a creature with an Intelligence of 3 or lower doesn't hear the song (true: nothing more happens).
func _ballad_unheard(tgt: Array[Combatant], r: CombatResult) -> bool:
	if tgt.is_empty() or tgt[0].creature.ability_score(&"int") >= 4:
		return false
	var t := tgt[0]
	r.lines.append(enc().log.add("info", "%s's mind is too simple to hear the ballad (Intelligence %d; Harrowing Ballad)" % [t.name(),
		t.creature.ability_score(&"int")], t.id))
	return true


## Martyr: the creature that died within the last minute returns with Hit Points equal to the caster's; the caster
## drops to 0 Hit Points (nothing prevents it) with two failed Death Saving Throws and makes one at once, so nothing
## heals or stabilizes it before that save.
func martyr(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	if not t.creature.dead or t == c:
		r.lines.append(e.log.add("info", "Martyr needs a creature that has died", t.id))
		return
	if e.round_no - int(t.get_meta("died_round", e.round_no)) > 10:
		r.lines.append(e.log.add("info", "%s has been dead too long for Martyr" % t.name(), t.id))
		return
	var gift := c.creature.hp
	t.creature.dead = false
	t.creature.death_failures = 0
	t.creature.death_successes = 0
	t.creature.stable = false
	t.creature.hp = 0
	var got := t.creature.heal(gift, "Martyr")
	r.lines.append(e.log.add("heal", "%s returns to life with %d Hit Points (Martyr)" % [t.name(), got], t.id))
	e.events.append({"type": "heal", "id": t.id, "amount": got})
	# The caster's life goes with it.
	if c.creature.concentration != null:
		c.creature.concentration.end("gave its life away (Martyr)")
	c.creature.hp = 0
	c.creature.stable = false
	c.creature.death_successes = 0
	c.creature.death_failures = 2
	c.creature.add_condition(&"unconscious", "0 Hit Points")
	c.creature.add_condition(&"prone", "0 Hit Points")
	e.ground.drop_held(c, "Unconscious")
	r.lines.append(e.log.add("death", "%s falls to 0 Hit Points with two failed Death Saving Throws (Martyr)" % c.name(), c.id))
	e.events.append({"type": "down", "id": c.id})
	var ds := c.creature.roll_death_save_d20(e.dice)
	if ds == null:
		return
	c.creature.apply_death_save(ds)
	var status := "dies" if c.creature.dead else ("regains 1 Hit Point" if c.creature.hp > 0 else "%d ✓ %d ✗" % [c.creature.death_successes, c.creature.death_failures])
	r.lines.append(e.log.add("roll", "%s makes a Death Saving Throw at once: %s" % [c.name(), status], c.id, [ds.describe()]))
	e.events.append({"type": "death_save", "id": c.id, "success": ds.success})
	if c.creature.dead:
		e.events.append({"type": "death", "id": c.id})


## After a cast: what the effects need from it (Hungering Blade's weapon and modifier, Intrusive Despair's save DC)
## and what Sanguine Secrets reveals.
func after_cast(c: Combatant, s: Dictionary, _slot: int, _free: bool = false, ctx: Dictionary = {}) -> void:
	var nums := ctx.get("nums", {}) as Dictionary
	match str(s["id"]):
		"hungering_blade":
			var fx := _spell_fx(c.creature, "hungering_blade", c.id)
			if fx == null:
				return
			var weapon := "unarmed_strike"
			var ch := _ch(c)
			if str(ctx.get("choice", "weapon")) == "weapon" and ch != null and not ch.equipped("main_hand").is_empty():
				weapon = str(ch.equipped("main_hand").get("id", "unarmed_strike"))
			fx.data["sb_weapon"] = weapon
			fx.data["sb_mod"] = maxi(0, int(nums.get("mod", 0)))
			var what := "Unarmed Strikes" if weapon == "unarmed_strike" else str(Compendium.shared().item_data(weapon).get("name", weapon))
			_log("spell", "%s's %s hungers for a first hit each turn (Hungering Blade)" % [c.name(), what], c)
		"intrusive_despair":
			for t: Variant in ctx.get("targets", []):
				var fx2 := _spell_fx((t as Combatant).creature, "intrusive_despair", c.id)
				if fx2 != null and nums.has("dc"):
					fx2.data["sb_dc"] = (nums["dc"] as Breakdown).total()
		"sanguine_secrets":
			for t: Variant in ctx.get("targets", []):
				_read_blood(c, t as Combatant)


# --- Sanguine Secrets ---------------------------------------------------------------------------------------------

## What the drop of blood tells about `t`: its kind and creature type, Hit Points, conditions, and its damage and
## condition Vulnerabilities, Resistances and Immunities. A monster counts as studied (the Bestiary shows its defenses).
func _read_blood(c: Combatant, t: Combatant) -> void:
	var cr := t.creature
	var kind := t.name()
	if cr is Character:
		kind = str((cr as Character).build.get("species", kind)).capitalize()
	elif cr is Monster:
		kind = str((cr as Monster).data.get("name", kind))
	var lines: Array = ["%s · %s · %d / %d Hit Points" % [kind, str(cr.creature_type).capitalize(), cr.hp, cr.max_hp()]]
	var conds := cr.active_conditions().map(func(x: StringName) -> String: return str(x).capitalize())
	lines.append("Conditions: %s" % (", ".join(conds) if not conds.is_empty() else "none"))
	var vul: Array[String] = []
	var res: Array[String] = []
	var imm: Array[String] = []
	for ty: String in PartyCoverage.DAMAGE_TYPES:
		if cr.immunity_source(StringName(ty)) != "":
			imm.append(ty.capitalize())
		elif cr.resistance_source(StringName(ty)) != "":
			res.append(ty.capitalize())
		if cr.vulnerability_source(StringName(ty)) != "":
			vul.append(ty.capitalize())
	for cond: String in CONDITIONS:
		if cr.is_condition_immune(StringName(cond)):
			imm.append(cond.capitalize())
	lines.append("Vulnerable: %s · Resistant: %s · Immune: %s" % [_list(vul), _list(res), _list(imm)])
	var id := Bestiary.monster_id(t)
	if id != "":
		enc().studied[id] = true
	_log("info", "%s reads %s's blood (Sanguine Secrets)" % [c.name(), t.name()], c, lines)


static func _list(names: Array[String]) -> String:
	return ", ".join(names) if not names.is_empty() else "none"


## Sanguine Secrets' mark on `c` against `t` (its Advantage not yet used), or null.
static func _secret_vs(c: Combatant, t: Combatant) -> Effect:
	for fx: Effect in c.creature.effects:
		if fx.source_id != "sanguine_secrets":
			continue
		for m in fx.modifiers:
			if m.stat == &"flag" and m.text("value") == "sanguine_secrets" and m.text("vs") == t.id:
				return fx
	return null


# --- Attacks ------------------------------------------------------------------------------------------------------

## Isolation: its target perceives no one, not even by Blindsight or Truesight (the "cant_see" flag covers sight), so
## it attacks as if they were Invisible and is attacked as if it couldn't see them. Sanguine Secrets: the next attack
## against the read creature has Advantage (shown here; the roll itself uses the mark up, before_d20). Pure: hit
## chances and the AI's scoring read this too, on a worker thread.
func attack_situation(c: Combatant, target: Combatant, _option: Dictionary, adv: Array[String], dis: Array[String]) -> void:
	var e := enc()
	if c.creature.has_flag("isolated") and e.can_see(c, target):
		dis.append("Isolation")
	if target.creature.has_flag("isolated") and e.can_see(target, c) and not c.hidden:
		adv.append("Isolation")
	if _secret_vs(c, target) != null:
		adv.append("Sanguine Secrets")


## Sanguine Secrets: an attack roll (weapon or spell) against the read creature has Advantage and uses the mark up.
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	if kind != D20Test.Kind.ATTACK_ROLL:
		return {}
	for k in keys:
		if not k.begins_with("target:"):
			continue
		var t := enc().get_c(k.substr(7))
		var secret := _secret_vs(c, t) if t != null else null
		if secret != null:
			c.creature.remove_effect(secret)
			return {"advantage": ["Sanguine Secrets"]}
	return {}


## Hungering Blade: the first hit on a turn with the empowered weapon (or Unarmed Strike) adds Necrotic damage equal to
## the caster's spellcasting modifier, and the caster gains the Necrotic damage dealt as Temporary Hit Points.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, _st: Dictionary, _r: CombatResult) -> void:
	var fx := _spell_fx(c.creature, "hungering_blade")
	if fx == null or not target.is_alive():
		return
	var p := option.get("profile") as WeaponProfile
	if p == null or p.item_id != str(fx.data.get("sb_weapon", "unarmed_strike")):
		return
	var amount := int(fx.data.get("sb_mod", 0))
	if amount <= 0 or not _once_per_turn(c, "sb_hungering_blade"):
		return
	var dr := enc().deal_damage(c, target, [{"amount": amount, "type": "necrotic"}], false, "Hungering Blade")
	if dr.final > 0 and c.creature.add_temp_hp(dr.final, "Hungering Blade"):
		_log("heal", "%s drinks %d Temporary Hit Points (Hungering Blade)" % [c.name(), dr.final], c)


# --- Damage -------------------------------------------------------------------------------------------------------

## Mist of Mourning: a melancholy creature subtracts 1d8 from all its damage rolls; the engine takes it from weapon and
## Unarmed Strike hits, this from the rest (spells, breath, features). Veil of the Reaper: a hit with an attack roll is
## noted for the end of the turn.
func adjust_incoming(source: Combatant, target: Combatant, ps: Array) -> void:
	if source == null:
		return
	var e := enc()
	if str(e.hit_context.get("attacker", "")) == source.id and str(e.hit_context.get("target", "")) == target.id \
			and source.creature.has_flag("veil_of_the_reaper"):
		source.set_meta("sb_veil_hit", _turn_key())
	if ps.any(func(p: Variant) -> bool: return bool((p as Dictionary).get("weapon", false))):
		return
	for m in source.creature.modifiers_for(&"damage_penalty_die"):
		if m.source_id != "mist_of_mourning":
			continue
		var cut := int(e.dice.roll_expr(m.text("dice", "1d8"), "Mist of Mourning")["total"])
		var taken := 0
		for p: Variant in ps:
			var d := p as Dictionary
			var off := mini(cut - taken, int(d["amount"]))
			if off > 0:
				d["amount"] = int(d["amount"]) - off
				taken += off
		if taken > 0:
			_log("info", "%s's melancholy saps %d damage (Mist of Mourning: -%d)" % [source.name(), taken, cut], source)


## Mirrored Agony: a caster within 60 ft that sees the creature that hurt its ally may answer (queued; after_damage
## sets the amount once the damage is known).
func queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	var e := enc()
	for w in e.living():
		if w == target or w == source or not w.allied_with(target) or not w.hostile_to(source):
			continue
		var ch := _ch(w)
		if ch == null or not ch.knows_spell("mirrored_agony") or not e.spells.can_cast_reaction(w, "mirrored_agony"):
			continue
		if e.distance(w, source) > 60 or not e.can_see(w, source):
			continue
		e.reaction_queue.append({"kind": "gm_sb_mirrored_agony", "reactor": w.id, "trigger": source.id, "ally": target.id})


## The damage just dealt: the amount for the Mirrored Agony Reactions it queued, and Sacrificial Siphon's Reaction when
## the cursed creature takes damage.
func after_damage(source: Combatant, target: Combatant, amount: int, _ps: Array = [], _dr: DamageResult = null) -> void:
	var e := enc()
	if source != null:
		for q: Dictionary in e.reaction_queue:
			if str(q.get("kind", "")) == "gm_sb_mirrored_agony" and str(q["trigger"]) == source.id and str(q.get("ally", "")) == target.id \
					and not q.has("amount"):
				q["amount"] = amount
	if amount <= 0:
		return
	for m in target.creature.modifiers_for(&"flag"):
		var v := m.text("value")
		if not v.begins_with("sacrificial_siphon:"):
			continue
		var w := e.get_c(v.substr(19))
		if w == null or not w.is_alive() or w == target:
			continue
		e.reaction_queue.append({"kind": "gm_sb_sacrificial_siphon", "reactor": w.id, "trigger": target.id if target.is_alive() else w.id})


## A queued Reaction's standing rule, from its spell's policy on the class tab: Off skips it, Automatic takes it unasked.
func _policy(q: Dictionary, reactor: Combatant, spell_id: String) -> bool:
	if not reactor.is_player_controlled():
		return true
	var rule := str(reactor.reaction_rules.get(spell_id, Compendium.shared().spell_data(spell_id).get("policy", "ask")))
	if rule == "never":
		return false
	if rule == "auto":
		q["plan"] = "auto"
	return true


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var e := enc()
	match str(q["kind"]):
		"gm_sb_mirrored_agony":
			var src := e.get_c(str(q["trigger"]))
			return int(q.get("amount", 0)) > 0 and src != null and e.spells.can_cast_reaction(reactor, "mirrored_agony") \
				and e.distance(reactor, src) <= 60 and e.can_see(reactor, src) and _policy(q, reactor, "mirrored_agony")
		"gm_sb_sacrificial_siphon":
			return e.spells.can_react(reactor) and reactor.creature.concentration != null \
				and reactor.creature.concentration.source_id == "sacrificial_siphon" and _policy(q, reactor, "sacrificial_siphon")
	return false


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	match str(q["kind"]):
		"gm_sb_mirrored_agony":
			return mirrored_agony(reactor, trigger, int(q.get("amount", 0)))
		"gm_sb_sacrificial_siphon":
			reactor.reaction_available = false
			if reactor.creature.add_temp_hp(10, "Sacrificial Siphon"):
				_log("heal", "%s siphons 10 Temporary Hit Points from the cursed (Sacrificial Siphon)" % reactor.name(), reactor)
			else:
				_log("info", "%s already has 10 or more Temporary Hit Points (Sacrificial Siphon)" % reactor.name(), reactor)
	return CombatResult.new()


func queued_text(kind: String) -> Array:
	match kind:
		"gm_sb_mirrored_agony":
			return ["Reaction: Mirrored Agony?", "%s hurt an ally of %s. Turn the pain back on it (Wisdom save; Psychic damage equal to the damage, half on a success)?",
				"Reaction and a level 5+ spell slot"]
		"gm_sb_sacrificial_siphon":
			return ["Reaction: Sacrificial Siphon?", "%s, the cursed creature, takes damage. Should %s drink 10 Temporary Hit Points from it?", "Reaction"]
	return super(kind)


## Mirrored Agony: `src` makes a Wisdom save against `reactor`'s spell and takes Psychic damage equal to the `amount` it
## dealt, half on a success. The Reaction and the slot are spent here.
func mirrored_agony(reactor: Combatant, src: Combatant, amount: int) -> CombatResult:
	var e := enc()
	if not e.spells.can_cast_reaction(reactor, "mirrored_agony"):
		return CombatResult.new()
	reactor.reaction_available = false
	if not e.spells.casting_gate(reactor):
		return CombatResult.new()
	var paid := e.spells.reaction_spells.pay(reactor, "mirrored_agony")
	var slot := int(paid["level"])
	var nums := e.spells.numbers(reactor, e.spells._entry_any(reactor, "mirrored_agony"))
	e.log.add("spell", "%s answers with Mirrored Agony (level %d slot)" % [reactor.name(), slot], reactor.id)
	e.events.append({"type": "spell", "caster": reactor.id, "spell": "mirrored_agony", "cells": [], "targets": [src.id]})
	e.spells.trigger_ends(reactor, "cast_spell")
	var s := Compendium.shared().spell_data("mirrored_agony").duplicate(true)
	s["damage"] = [{"dice": "1d4", "type": "psychic"}]   # the type; the amount is the damage dealt (shared_damage)
	var ctx := {"c": reactor, "s": s, "slot": slot, "nums": nums, "conc": null, "opts": {}, "choice": "", "point": Vector2.INF,
		"shared_damage": {"total": amount, "text": "Mirrored Agony: the %d damage it dealt" % amount}}
	var r := CombatResult.new()
	var tgt: Array[Combatant] = [src]
	return e.then(e.spells._save_spell(ctx, tgt, r, true), func() -> CombatResult:
		e._check_over()
		return r)


# --- Effects and turns --------------------------------------------------------------------------------------------

## Murder of Crows: its blindness also ends when the creature regains any Hit Points.
func effect_added(_cr: Creature, fx: Effect) -> void:
	if fx.source_id == "murder_of_crows":
		fx.data["ends_on_heal"] = true


## Veil of the Reaper: at the end of any turn in which its caster hit a creature with an attack roll, it is Invisible
## until the start of its next turn (and no longer than the spell).
func turn_end(_c: Combatant) -> void:
	var e := enc()
	for v in e.living():
		if str(v.get_meta("sb_veil_hit", "")) != _turn_key() or not v.creature.has_flag("veil_of_the_reaper"):
			continue
		v.remove_meta("sb_veil_hit")
		var fx := Effect.new("Veil of the Reaper", &"spell", "veil_of_the_reaper:veil").with_condition(&"invisible")
		fx.caster_id = v.id
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = v.id
		var conc := v.creature.concentration
		var ok := conc.attach(v.creature, fx) if conc != null and conc.source_id == "veil_of_the_reaper" else v.creature.add_effect(fx)
		if ok:
			_log("condition", "%s fades into the shadows: Invisible until its next turn (Veil of the Reaper)" % v.name(), v)
			e.events.append({"type": "condition", "id": v.id})


## An AI-run creature's turn: Puppet Master's walk to the creature it must strike.
func monster_turn(c: Combatant) -> Variant:
	return _puppet_turn(c)


# --- Intrusive Despair --------------------------------------------------------------------------------------------

## Anyone's Attack or Magic action as it begins, heroes' and the AI's alike (the engine spends the action when this
## says it's wasted): Intrusive Despair's save.
func wastes_action(c: Combatant, kind: String) -> bool:
	return despair_check(c, kind)


## Intrusive Despair: as the cursed creature takes the Attack or Magic action (`kind`) it makes a Wisdom save against
## its curser's spell save DC or wastes that action. The third success ends the spell. True when the action is wasted
## (the engine's hook spends it).
func despair_check(c: Combatant, kind: String) -> bool:
	var e := enc()
	var fx := _spell_fx(c.creature, "intrusive_despair")
	if fx == null or kind == "":
		return false
	var caster := e.get_c(fx.caster_id)
	var dc := int(fx.data.get("sb_dc", 0))
	if dc <= 0 and caster != null:
		dc = (e.spells.numbers(caster, e.spells._entry_any(caster, "intrusive_despair"))["dc"] as Breakdown).total()
	var sv := c.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Intrusive Despair (%s)" % c.name(),
		SpellCaster.spell_save_keys(fx.caster_id))
	if not sv.success:
		_log("save", "%s sinks into despair and wastes its %s action (Intrusive Despair)" % [c.name(), kind.capitalize()], c, [sv.describe()])
		return true
	var wins := int(fx.data.get("sb_successes", 0)) + 1
	fx.data["sb_successes"] = wins
	_log("save", "%s shakes off the despair (%d of 3; Intrusive Despair)" % [c.name(), wins], c, [sv.describe()])
	if wins >= 3:
		_end_spell(caster, "intrusive_despair", fx, c.creature, "%s threw off the despair three times" % c.name())
		_log("info", "Intrusive Despair ends on %s" % c.name(), c)
	return false


# --- Puppet Master ------------------------------------------------------------------------------------------------

## Puppet Master: the puppet must make a melee attack on the creature its caster chose (an AI caster's: the nearest
## creature hostile to it), walking to reach it first. The engine's crowned turn has already struck a chosen creature
## in reach; this is the walk. Null when it acts normally (no one chosen, or no square in reach this turn).
func _puppet_turn(c: Combatant) -> Variant:
	var e := enc()
	if not c.creature.has_flag("crowned") or _spell_fx(c.creature, "puppet_master") == null or not c.can_act() or not c.action_available:
		return null
	var caster := e.get_c(str(c.get_meta("crowned_by", "")))
	var victim: Combatant = null
	if caster != null and caster.is_player_controlled():
		victim = e.get_c(str(c.get_meta("crown_victim", "")))
	else:
		for o in e.living():
			if o == c or o == caster or o.is_down() or (caster != null and not caster.hostile_to(o)):
				continue
			if victim == null or e.distance(c, o) < e.distance(c, victim):
				victim = o
	if victim == null or not victim.is_alive() or victim == c or victim == caster:
		return null
	var opt := e.best_melee_option(c, victim)
	if opt.is_empty():
		return null
	var reach := (opt["profile"] as WeaponProfile).reach
	var sq := e.ai._approach_square(c, {"target": victim, "dash": false})
	var cell: Vector2i = sq["cell"]
	if e.grid.distance_ft(cell, c.size_cells, victim.cell, victim.size_cells, c.altitude, victim.altitude) > reach:
		return null
	var strike := func() -> CombatResult:
		if e.state != Encounter.State.ACTIVE or e.current() != c or not c.can_act() or not victim.is_alive() or e.distance(c, victim) > reach:
			return CombatResult.new()
		_log("info", "Marionette strings make %s lash out at %s (Puppet Master)" % [c.name(), victim.name()], c)
		if c.creature is Monster:
			return e.monster_attack(c, victim, str(opt.get("action_id", "")))
		return e.attack(c, victim, str(opt["id"]))
	if cell == c.cell:
		return strike.call() as CombatResult
	_log("info", "Marionette strings drag %s toward %s (Puppet Master)" % [c.name(), victim.name()], c)
	var moved := e.move(c, cell, sq.get("avoid", {}) as Dictionary)
	if not moved.ok:
		return null
	return e.then(moved, strike)
