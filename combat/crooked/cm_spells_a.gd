class_name CmSpellsA
extends CmPart
## The Crooked Moon's code for the first twenty of the book's spells (chapter 7), Ancestral Communion to Harvest Moonglow: the parts of them data can't say.
## CrookedFeatures forwards every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start
## "sa_".
##
## What each spell leaves to the data and what it takes over here:
## - Ancestral Communion: Heroic Inspiration as it's cast and at each of the caster's turn starts (its flag keeps it).
## - Blood Bolt: Temporary Hit Points equal to the Proficiency Bonus on a hit.
## - Blood Sacrifice: the self-harm nothing can lessen, then an extra 1d6 (+1d6 a slot level above 2) on one creature each
##   later damaging spell of the minute hurts.
## - Buried Alive: the grave (Total Cover, Restrained, Blinded, no air), digging out by Athletics; boards or stone indoors.
##   Total Cover is the engine's "ethereal" flag: no game hook can refuse an attack or add Total Cover of its own.
## - Call of the Wild: Beasts only; the dominated follow one command a turn, a new one by a Magic action.
## - Captivate Undead: Charmed despite immunity; the spell ends once the caster's side hurts it or forces a save; a
##   success makes its next attack against the caster worse.
## - Chain of Conviction: Advantage for the caster against the chained creature, which can't walk beyond 30 ft of it.
## - Consuming Pyre: both flames each turn start, smothering them by an action, ash.
## - Creeping Rot: the tendrils leap only 30 ft from the first target, one each.
## - Crimson Harvest: half the damage roll heals one creature of the caster's side in the wave.
## - Crooked Ward: only Aberrations, Fey, Fiends, Monstrosities and Undead feel it (its zone's sa_crooked_ward entry).
## - Culling Sickle: Temporary Hit Points equal to half the damage each strike deals.
## - Cursed Cacophony: the first failed D20 Test each turn lets the cursed creature save again, a straight roll.
## - Devil's Due: the Reaction when a creature within 30 ft takes damage (a Hit Point Die, doubled after a Critical Hit).
## - Eye Burn: the Reaction when a creature attacks the caster, before the roll (before_roll).
## - Field of Reaping: the curse at a turn's end in the field, the first damage each turn reaped and given to an ally.
## - Harvest Moonglow: an ally in the light absorbs it as a Bonus Action.
## Chorus of the Lost, Dissolution and Ghastly Charge are data alone.

const PREFIX := "sa_"

## The creature types Crooked Ward torments when its data names none.
const WARD_TYPES := ["aberration", "fey", "fiend", "monstrosity", "undead"]
## Consuming Pyre's flames at a turn's start, each part.
const PYRE_DICE := "2d8"
## Buried Alive: how deep the grave is, the dig's DC and how far one success digs.
const GRAVE_FT := 10
const DIG_DC := 15
const DIG_FT := 5


func prefix() -> String:
	return PREFIX


# --- Small helpers -------------------------------------------------------------------------------------------------

static func _sid(ctx: Dictionary) -> String:
	return str((ctx["s"] as Dictionary)["id"])


## The first effect of spell `spell_id` on `t` (cast by `caster_id` when given), or null.
static func _fx(t: Combatant, spell_id: String, caster_id: String = "") -> Effect:
	if t == null:
		return null
	for fx: Effect in t.creature.effects:
		if fx.source_id == spell_id and (caster_id == "" or fx.caster_id == caster_id):
			return fx
	return null


## Whether the effect `fx` carries the flag `value`.
static func _flagged(fx: Effect, value: String) -> bool:
	return fx.modifiers.any(func(m: Modifier) -> bool: return m.stat == &"flag" and m.text("value") == value)


## Ends `caster`'s Concentration when it is on `spell_id`.
func _end_spell(caster: Combatant, spell_id: String, why: String) -> void:
	if caster != null and caster.creature.concentration != null and caster.creature.concentration.source_id == spell_id:
		caster.creature.concentration.end(why)
		enc().spells.zones.prune()


## The spellcasting numbers `c` casts `spell_id` with ({dc, attack, mod}).
func _nums(c: Combatant, spell_id: String) -> Dictionary:
	return enc().spells.numbers(c, enc().spells._entry_any(c, spell_id))


## Whether `c` could cast the cantrip `spell_id` as a Reaction now: it knows it, has its Reaction, can speak and cast.
func _cantrip_react_ok(c: Combatant, spell_id: String) -> bool:
	var e := enc()
	var ch := _ch(c)
	if ch == null or not ch.knows_spell(spell_id) or not e.spells.can_react(c):
		return false
	if c.creature.has_flag("cant_cast") or e.spells.specials.high.in_antimagic(c) or ch.armor_cast_blocker() != "":
		return false
	return e.spells.reaction_spells._voice_ok(c, Compendium.shared().spell_data(spell_id))


## The most hurt of `among` (Hit Points against the maximum), or null when none is hurt.
static func _most_hurt(among: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for a in among:
		if a.creature.dead or a.creature.hp >= a.creature.max_hp():
			continue
		if best == null or float(a.creature.hp) / maxf(1.0, a.creature.max_hp()) < float(best.creature.hp) / maxf(1.0, best.creature.max_hp()):
			best = a
	return best


func _heal(t: Combatant, amount: int, label: String, details: Array = []) -> void:
	var got := t.creature.heal(amount, label)
	if got > 0:
		_log("heal", "%s regains %d Hit Points (%s)" % [t.name(), got, label], t, details)
		enc().events.append({"type": "heal", "id": t.id, "amount": got})


# --- Casting -------------------------------------------------------------------------------------------------------

## Before a spell's targets resolve: Blood Sacrifice starts noting who the spell hurts.
func before_resolve(ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	if c.creature.has_flag("blood_sacrifice") and _sid(ctx) != "blood_sacrifice":
		c.set_meta("sa_blood_hits", {})


## The spells whose whole resolution is here. True when handled.
func resolve_spell(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> bool:
	match _sid(ctx):
		"ancestral_communion":
			_ancestral_communion(ctx, r)
		"blood_bolt":
			_blood_bolt(ctx, tgt, r)
		"blood_sacrifice":
			_blood_sacrifice(ctx, r)
		"buried_alive":
			for t in tgt:
				_buried_alive(ctx, t, r)
		"call_of_the_wild":
			_call_of_the_wild(ctx, cells, r)
		"captivate_undead":
			_captivate_undead(ctx, tgt, r)
		"consuming_pyre":
			_consuming_pyre(ctx, tgt, r)
		"creeping_rot":
			if tgt.is_empty():
				return false
			_creeping_rot(ctx, tgt, r)
		"crimson_harvest":
			_crimson_harvest(ctx, cells, r)
		"crooked_ward":
			_crooked_ward(ctx, cells, r)
		_:
			return false
	return true


## After a spell is cast: Blood Sacrifice's extra damage on one creature the spell hurt.
func after_cast(c: Combatant, s: Dictionary, _slot: int, _free: bool = false, _ctx: Dictionary = {}) -> void:
	if not c.has_meta("sa_blood_hits"):
		return
	var hits := c.get_meta("sa_blood_hits") as Dictionary
	c.remove_meta("sa_blood_hits")
	if hits.is_empty() or str(s["id"]) == "blood_sacrifice":
		return
	_blood_extra(c, hits)


# --- Ancestral Communion, Blood Bolt, Blood Sacrifice ------------------------------------------------------------

## Ancestral Communion: its flag held by Concentration, and Heroic Inspiration now if the caster lacks it.
func _ancestral_communion(ctx: Dictionary, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	enc().spells.apply_effect_entries(ctx, c, (ctx["s"] as Dictionary).get("effects", []) as Array, "cast", r)
	_inspire(c, c, "Ancestral Communion")


## Blood Bolt: a ranged spell attack; a hit gives the caster Temporary Hit Points equal to its Proficiency Bonus.
func _blood_bolt(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	for t in e.spells.attack_shots(ctx, tgt):
		if not t.is_alive():
			continue
		var before := r.hit
		r.hit = false
		e.spells.spell_attack(ctx, t, r)
		if r.hit:
			var pb := c.creature.proficiency_bonus()
			if c.creature.add_temp_hp(pb, "Blood Bolt"):
				r.lines.append(e.log.add("heal", "%s gains %d Temporary Hit Points (Blood Bolt)" % [c.name(), pb], c.id))
		r.hit = r.hit or before


## Blood Sacrifice: its flag for the minute (the extra dice on it), then the caster's own blood: 1d6 Necrotic (+1d6 a
## slot level above 2) that no Resistance, Temporary Hit Points or ward can lessen.
func _blood_sacrifice(ctx: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var dice := 1 + maxi(0, int(ctx["slot"]) - 2)
	e.spells.apply_effect_entries(ctx, c, (ctx["s"] as Dictionary).get("effects", []) as Array, "cast", r)
	var fx := _fx(c, "blood_sacrifice")
	if fx != null:
		fx.data["sa_dice"] = dice
	var rolled := e._roll_damage_dice("%dd6" % dice, false, 0, "Blood Sacrifice")
	var temp := c.creature.temp_hp
	var ward := c.creature.ward_hp
	c.creature.temp_hp = 0
	c.creature.ward_hp = 0
	e.deal_damage(c, c, [{"amount": int(rolled["total"]), "type": "necrotic", "ignore_resistance": true, "ignore_source": "Blood Sacrifice"}],
		false, "Blood Sacrifice", [str(rolled["text"])])
	c.creature.temp_hp += temp
	c.creature.ward_hp += ward


## Blood Sacrifice's extra damage after a damaging spell: on one creature it hurt (an enemy still up, the weakest
## first), Blood Sacrifice's dice of the damage type it took the most of.
func _blood_extra(c: Combatant, hits: Dictionary) -> void:
	var e := enc()
	var fx := _fx(c, "blood_sacrifice")
	if fx == null:
		return
	var pick: Combatant = null
	for id: String in hits:
		var t := e.get_c(id)
		if t == null or not t.is_alive() or t.creature.hp <= 0:
			continue
		var better := pick == null or (c.hostile_to(t) and not c.hostile_to(pick)) \
			or (c.hostile_to(t) == c.hostile_to(pick) and t.creature.hp < pick.creature.hp)
		if better:
			pick = t
	if pick == null:
		return
	var dice := int(fx.data.get("sa_dice", 1))
	var rolled := e._roll_damage_dice("%dd6" % dice, false, 0, "Blood Sacrifice")
	e.deal_damage(c, pick, [{"amount": int(rolled["total"]), "type": str(hits[pick.id]), "spell": true}], false, "Blood Sacrifice",
		[str(rolled["text"])])


# --- Buried Alive --------------------------------------------------------------------------------------------------

## Whether the ground under a fight is stone, metal or boards: any fight indoors (a map not marked outdoors).
func _hard_floor() -> bool:
	return not enc().outdoors


## Buried Alive on `t`: a creature on the ground saves (Strength) or is swallowed 10 ft down; a success knocks it Prone
## with Speed 0 to the end of its next turn (the data). On stone, metal or boards it succeeds on its own.
func _buried_alive(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	if not t.is_alive():
		return
	if t.altitude > 0:
		r.lines.append(e.log.add("info", "%s isn't standing on the ground (Buried Alive)" % t.name(), t.id))
		return
	var saved := true
	var details: Array[String] = []
	if _hard_floor():
		details.append("%s stands on a floor the ground can't open through: it succeeds automatically" % t.name())
	else:
		var keys := SpellCaster.spell_save_keys(c.id)
		keys.append_array(["save_vs:restrained", "save_vs:blinded"])
		var sv := t.creature.roll_save(e.dice, &"str", ((ctx["nums"] as Dictionary)["dc"] as Breakdown).total(), [], [],
			"Strength save vs Buried Alive (%s)" % t.name(), keys)
		saved = sv.success
		details.append(sv.describe())
	if saved:
		r.lines.append(e.log.add("info", "%s keeps its feet as the ground heaves (Buried Alive)" % t.name(), t.id, details))
		e.spells.apply_effect_entries(ctx, t, s.get("effects", []) as Array, "success", r)
		return
	var fx := Effect.new("Buried Alive", &"spell", "buried_alive")
	fx.caster_id = c.id
	fx.spell_level = int(ctx["slot"])
	fx.stack_key = "spell:buried_alive:grave"
	fx.ends = Effect.Ends.NEVER
	fx.conditions.append(&"restrained")
	fx.conditions.append(&"blinded")
	# Total Cover under the earth: nothing sees or reaches it (the engine's "ethereal" flag), and it knows it's buried.
	fx.modifiers.append(Modifier.of("flag", {"value": "ethereal"}, "Buried Alive", &"spell"))
	fx.modifiers.append(Modifier.of("flag", {"value": "sa_buried"}, "Buried Alive", &"spell"))
	fx.data = {"sa_depth": GRAVE_FT, "sa_turns": 0, "sa_exhaustion": 0}
	t.creature.add_effect(fx)
	r.lines.append(e.log.add("condition", "The ground swallows %s %d ft down (Buried Alive)" % [t.name(), GRAVE_FT], t.id, details))
	e.events.append({"type": "condition", "id": t.id})


## The grave `t` lies in, or null.
static func _grave(t: Combatant) -> Effect:
	for fx: Effect in t.creature.effects:
		if fx.source_id == "buried_alive" and _flagged(fx, "sa_buried"):
			return fx
	return null


## How many turns `t` can hold its breath: 1 + its Constitution modifier minutes (10 turns each), at least 30 seconds.
static func _breath_turns(t: Combatant) -> int:
	return maxi(5, (1 + t.creature.ability_mod(&"con")) * 10)


## A buried creature's action: a DC 15 Strength (Athletics) check digs 5 ft up, or out at once when it beats the DC by 5.
func _dig(c: Combatant) -> CombatResult:
	var e := enc()
	var fx := _grave(c)
	if fx == null:
		return CombatResult.fail("Not buried")
	e.spend_action(c)
	var t := c.creature.roll_check(e.dice, &"athletics", DIG_DC, [], [], "Strength (Athletics) to dig out (%s)" % c.name())
	var depth := int(fx.data.get("sa_depth", GRAVE_FT))
	if not t.success:
		_log("info", "%s claws at the earth but gets nowhere (%d ft down)" % [c.name(), depth], c, [t.describe()])
		return CombatResult.new()
	depth -= DIG_FT
	if t.total >= DIG_DC + 5 or depth <= 0:
		_surface(c, fx, [t.describe()])
	else:
		fx.data["sa_depth"] = depth
		_log("info", "%s digs 5 ft closer to the surface (%d ft to go)" % [c.name(), depth], c, [t.describe()])
	return CombatResult.new()


## Out of the grave: Prone, and the Exhaustion the lack of air gave goes again.
func _surface(c: Combatant, fx: Effect, details: Array = []) -> void:
	var gasped := int(fx.data.get("sa_exhaustion", 0))
	c.creature.remove_effect(fx)
	c.creature.exhaustion = maxi(0, c.creature.exhaustion - gasped)
	c.creature.add_condition(&"prone", "Buried Alive")
	_log("condition", "%s breaks out of the grave, Prone" % c.name(), c, details)
	enc().events.append({"type": "condition", "id": c.id})


## At the end of a buried creature's turn: once its breath runs out, a level of Exhaustion each turn (2024 suffocation).
func _grave_turn_end(c: Combatant) -> void:
	var fx := _grave(c)
	if fx == null:
		return
	fx.data["sa_turns"] = int(fx.data.get("sa_turns", 0)) + 1
	if int(fx.data["sa_turns"]) <= _breath_turns(c):
		return
	if c.creature.add_exhaustion(1):
		fx.data["sa_exhaustion"] = int(fx.data.get("sa_exhaustion", 0)) + 1
		_log("condition", "%s is suffocating in the grave: Exhaustion %d" % [c.name(), c.creature.exhaustion], c)


# --- Call of the Wild ----------------------------------------------------------------------------------------------

## Call of the Wild: each Beast in the howl saves (Wisdom). The failures are dominated (Charmed, on the caster's side,
## following its commands) with no save on taking damage, and each follows one command: the cast's, then a new one each
## time the caster takes the Magic action. The successes are Charmed until the caster's next turn (the data).
func _call_of_the_wild(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var beasts: Array[Combatant] = []
	for v in e.spells.targeting._area_victims(c, s, cells, str(ctx.get("choice", "")), (ctx.get("opts", {}) as Dictionary).get("chosen")):
		if v.creature.creature_type == &"beast":
			beasts.append(v)
	if beasts.is_empty():
		r.lines.append(e.log.add("info", "No Beast hears the call (Call of the Wild)", c.id))
		return
	e.spells._save_spell(ctx, beasts, r)
	var held: Array[Combatant] = []
	for b in beasts:
		var fx := _wild_hold(b, c.id)
		if fx == null:
			continue
		fx.repeat_save = {}
		b.set_meta("sa_wild_orders", true)
		held.append(b)
	if not held.is_empty():
		e.spells._grant_sustained(ctx, held)


## The domination Call of the Wild holds `b` with (by `caster_id` when given), or null.
static func _wild_hold(b: Combatant, caster_id: String = "") -> Effect:
	for fx: Effect in b.creature.effects:
		if fx.source_id == "call_of_the_wild" and (caster_id == "" or fx.caster_id == caster_id) and _flagged(fx, "dominated"):
			return fx
	return null


## A Beast held by Call of the Wild starts its turn: it follows the command it was given, or, with none, waits.
func _wild_turn_start(b: Combatant) -> void:
	if _wild_hold(b) == null:
		return
	if bool(b.get_meta("sa_wild_orders", false)):
		b.set_meta("sa_wild_orders", false)
		_log("info", "%s follows its orders (Call of the Wild)" % b.name(), b)
		return
	var wait := Effect.new("Awaiting a command", &"spell", "call_of_the_wild").with_condition(&"incapacitated") \
		.with_modifier("speed_set", {"value": 0})
	wait.stack_key = "spell:call_of_the_wild:waiting"
	wait.ends = Effect.Ends.END_OF_TURN
	wait.turn_owner_id = b.id
	b.creature.add_effect(wait)
	_log("info", "%s waits for a command (Call of the Wild)" % b.name(), b)
	enc().events.append({"type": "condition", "id": b.id})


# --- Captivate Undead ----------------------------------------------------------------------------------------------

## Captivate Undead: the save and its effects come from the data; a failure's Charmed holds even against an immunity.
func _captivate_undead(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	e.spells._save_spell(ctx, tgt, r)
	for t in tgt:
		var fx := _captivated(t, c.id)
		if fx != null and not &"charmed" in fx.conditions:
			fx.conditions.append(&"charmed")
			r.lines.append(e.log.add("condition", "%s is Charmed all the same: its own unlife answers %s (Captivate Undead)" % [t.name(), c.name()], t.id))
			e.events.append({"type": "condition", "id": t.id})


## Captivate Undead's hold on `t` (by `caster_id` when given), or null.
static func _captivated(t: Combatant, caster_id: String = "") -> Effect:
	for fx: Effect in t.creature.effects:
		if fx.source_id == "captivate_undead" and (caster_id == "" or fx.caster_id == caster_id) and _flagged(fx, "friendly:%s" % fx.caster_id):
			return fx
	return null


## The spell ends once its caster or an ally of the caster's hurts the captivated creature or makes it save.
func _break_captivation(t: Combatant, by: Combatant, how: String) -> void:
	var fx := _captivated(t)
	if fx == null or by == null:
		return
	var caster := enc().get_c(fx.caster_id)
	if caster == null or not (by == caster or by.allied_with(caster)):
		return
	_log("info", "Captivate Undead ends: %s %s %s" % [by.name(), how, t.name()], t)
	_end_spell(caster, "captivate_undead", "%s %s %s" % [by.name(), how, t.name()])


# --- Consuming Pyre ------------------------------------------------------------------------------------------------

## Consuming Pyre: the save and the first flames from the data; on whoever fails, the flames linger (the type picked),
## and it gets the action to smother them.
func _consuming_pyre(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var ty := str(ctx.get("choice", ""))
	if not ty in ["necrotic", "radiant"]:
		ty = "necrotic"
	c.set_meta("sa_pyre_casting", true)
	e.spells._save_spell(ctx, tgt, r)
	c.remove_meta("sa_pyre_casting")
	for t in tgt:
		var fx := _fx(t, "consuming_pyre", c.id)
		if fx != null:
			fx.data["sa_pyre_type"] = ty
	e.spells._grant_sustained(ctx, tgt)


## The lingering flames on `t`, or null.
static func _pyre(t: Combatant) -> Effect:
	for fx: Effect in t.creature.effects:
		if fx.source_id == "consuming_pyre" and fx.data.has("sa_pyre_type"):
			return fx
	return null


## The flames bite again as the burning creature's turn starts: 2d8 Fire and 2d8 of the chosen type, one blow.
func _pyre_burn(c: Combatant) -> void:
	var e := enc()
	var fx := _pyre(c)
	if fx == null or not c.is_alive():
		return
	var ty := str(fx.data["sa_pyre_type"])
	var fire := e._roll_damage_dice(PYRE_DICE, false, 0, "Consuming Pyre (Fire)")
	var other := e._roll_damage_dice(PYRE_DICE, false, 0, "Consuming Pyre (%s)" % ty.capitalize())
	e.deal_damage(e.get_c(fx.caster_id), c, [{"amount": int(fire["total"]), "type": "fire", "spell": true},
		{"amount": int(other["total"]), "type": ty, "spell": true}], false, "Consuming Pyre", [str(fire["text"]), str(other["text"])])
	if c.creature.dead:
		_ash(c)


## Smothering the flames: an action of the burning creature (`pay` false: the sustained action already paid) or of one
## within 5 ft of it; the burning creature saves again (Dexterity), and a success ends the spell.
func _smother(actor: Combatant, burning: Combatant, pay: bool) -> CombatResult:
	var e := enc()
	var fx := _pyre(burning)
	if fx == null:
		return CombatResult.fail("%s isn't burning" % burning.name())
	if pay:
		e.spend_action(actor)
	_log("info", "%s beats at the flames on %s" % [actor.name(), burning.name() if actor != burning else "itself"], actor)
	return e.spells.saves._repeat_save(burning, fx, [])


## Killed by the pyre: ash, and the gear it wore with it.
func _ash(t: Combatant) -> void:
	if t.has_meta("sa_ash"):
		return
	t.set_meta("sa_ash", true)
	t.set_meta("no_undead", true)
	_log("death", "%s burns away to ash (Consuming Pyre)" % t.name(), t)
	enc().events.append({"type": "vanish", "id": t.id})


# --- Creeping Rot, Crimson Harvest, Crooked Ward ----------------------------------------------------------------------

## Creeping Rot: the first target, then tendrils to others within 30 ft of it, each struck by one only; then the save
## and the rot from the data (a Plant fails it). Withering plants that aren't creatures is out of fights.
func _creeping_rot(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var first := tgt[0]
	var struck: Array[Combatant] = []
	for t in tgt:
		if t in struck:
			continue
		if t != first and e.distance(first, t) > 30:
			r.lines.append(e.log.add("info", "The rot can't leap from %s to %s: more than 30 ft" % [first.name(), t.name()], t.id))
			continue
		struck.append(t)
	e.spells._save_spell(ctx, struck, r)


## Crimson Harvest: one damage roll for the wave (the data's save and halving); if it hurt a Small or larger creature,
## one creature of the caster's side it can see in the wave regains half that roll (the most hurt).
func _crimson_harvest(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var victims := e.spells.targeting._area_victims(c, s, cells, str(ctx.get("choice", "")), (ctx.get("opts", {}) as Dictionary).get("chosen"))
	var rolled := e.spells.damage._roll_spell_damage(ctx, null, false)
	ctx["shared_damage"] = rolled
	var before := {}
	for v in victims:
		before[v.id] = v.creature.hp + v.creature.temp_hp
	e.spells._save_spell(ctx, victims, r)
	var fed := victims.any(func(v: Combatant) -> bool:
		return v.creature.hp + v.creature.temp_hp < int(before[v.id]) and Creature.SIZES.find(v.creature.size) >= Creature.SIZES.find(&"small"))
	if not fed:
		return
	var near: Array[Combatant] = []
	for a in e.living():
		if a != c and c.allied_with(a) and e.can_see(c, a) and a.footprint().any(func(cl: Vector2i) -> bool: return cl in cells):
			near.append(a)
	var who := _most_hurt(near)
	if who != null:
		_heal(who, int(rolled["total"]) / 2, "Crimson Harvest", ["half the damage roll of %d" % int(rolled["total"])])


## Crooked Ward: the Sphere from the data, felt only by the twisted (_ward_types); the others in the field are
## spared, the caster's side included. A warning when the caster's own side has such a creature in it.
func _crooked_ward(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	e.spells._place_zone(ctx, cells, r)
	var o := e.spells.zones.object_of(c.id, "crooked_ward")
	if o == null:
		return
	_ward_spare(o)
	e.spells.zones.refresh_auras()
	for a in e.living():
		if (a == c or c.allied_with(a)) and o.covers(a) and str(a.creature.creature_type) in _ward_types(o):
			r.lines.append(e.log.add("info", "%s is one the ward torments too (Crooked Ward)" % a.name(), a.id))


## The types a Crooked Ward torments: its zone's `sa_crooked_ward` entry's `only_types`, else the book's five.
static func _ward_types(o: FieldObject) -> Array:
	for raw: Variant in o.rule("effects", []) as Array:
		var p := (raw as Dictionary).get("params", {}) as Dictionary
		if str(p.get("id", "")) == "sa_crooked_ward":
			return p.get("only_types", WARD_TYPES) as Array
	return WARD_TYPES


## Crooked Ward spares every creature that isn't one of its types (new ones too: checked as each turn starts).
func _ward_spare(o: FieldObject) -> void:
	var types := _ward_types(o)
	for t in enc().combatants:
		if str(t.creature.creature_type) in types:
			o.spared.erase(t.id)
		elif not t.id in o.spared:
			o.spared.append(t.id)


# --- Field of Reaping ----------------------------------------------------------------------------------------------

## The curse of a Field of Reaping on `t` (cast by `caster_id` when given), or null.
static func _reaping(t: Combatant, caster_id: String = "") -> Effect:
	for fx: Effect in t.creature.effects:
		if fx.source_id == "field_of_reaping" and (caster_id == "" or fx.caster_id == caster_id) and _flagged(fx, "reaped:%s" % fx.caster_id):
			return fx
	return null


## A hostile creature ending its turn in the field is cursed until the end of its next turn (the field's own triggers
## curse it as it appears and as it walks in).
func _reaping_turn_end(c: Combatant) -> void:
	var e := enc()
	for o in e.spells.zones.live():
		if o.spell_id != "field_of_reaping" or not o.covers(c):
			continue
		var caster := e.get_c(o.caster_id)
		if caster == null or not caster.hostile_to(c) or not c.is_alive():
			continue
		var old := _reaping(c, caster.id)
		if old != null:
			c.creature.remove_effect(old)
		var fx := Effect.new("Field of Reaping", &"spell", "field_of_reaping")
		fx.caster_id = caster.id
		fx.spell_level = o.slot
		fx.stack_key = "spell:field_of_reaping:0"
		fx.modifiers.append(Modifier.of("flag", {"value": "reaped:%s" % caster.id}, "Field of Reaping", &"spell"))
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = c.id
		if o.concentration != null and not o.concentration.ended:
			o.concentration.attach(c.creature, fx)
		else:
			c.creature.add_effect(fx)
		_log("condition", "%s is cursed by the Field of Reaping until the end of its next turn" % c.name(), c)
		e.events.append({"type": "condition", "id": c.id})


## The first damage a cursed creature takes in a turn: an extra 1d6 Necrotic (+1d6 a slot level above 5), and the
## caster's most hurt uncursed creature in the field regains what it took.
func _reap(t: Combatant, amount: int) -> void:
	var e := enc()
	if amount <= 0 or t.creature.dead:
		return
	var fx := _reaping(t)
	if fx == null or not _once_per_turn(t, "sa_reaped_turn"):
		return
	var caster := e.get_c(fx.caster_id)
	var dice := 1 + maxi(0, fx.spell_level - 5)
	var rolled := e._roll_damage_dice("%dd6" % dice, false, 0, "Field of Reaping")
	var dr := e.deal_damage(caster, t, [{"amount": int(rolled["total"]), "type": "necrotic", "spell": true}], false, "Field of Reaping",
		[str(rolled["text"])])
	if dr == null or dr.final <= 0 or caster == null:
		return
	var field := e.spells.zones.object_of(caster.id, "field_of_reaping")
	if field == null:
		return
	var near: Array[Combatant] = []
	for a in e.living():
		if (a == caster or caster.allied_with(a)) and field.covers(a) and _reaping(a, caster.id) == null:
			near.append(a)
	var who := _most_hurt(near)
	if who != null:
		_heal(who, dr.final, "Field of Reaping", ["the life reaped from %s" % t.name()])


# --- Damage --------------------------------------------------------------------------------------------------------

## After damage: who a Blood Sacrifice spell hurt, Culling Sickle's Temporary Hit Points, Captivate Undead broken,
## ash from the pyre, Devil's Due offered, the Field of Reaping's harvest.
func after_damage(source: Combatant, target: Combatant, amount: int, parts: Array = [], dr: DamageResult = null) -> void:
	if source != null and amount > 0 and target != source:
		if source.has_meta("sa_blood_hits"):
			var hits := source.get_meta("sa_blood_hits") as Dictionary
			if not hits.has(target.id):
				hits[target.id] = _main_type(parts)
		if parts.any(func(p: Variant) -> bool: return str((p as Dictionary).get("spell_id", "")) == "culling_sickle"):
			var gain := amount / 2
			if gain > 0 and source.creature.add_temp_hp(gain, "Culling Sickle"):
				_log("heal", "%s gains %d Temporary Hit Points (Culling Sickle)" % [source.name(), gain], source)
		_break_captivation(target, source, "hurts")
	if source != null and source.has_meta("sa_pyre_casting") and target.creature.dead:
		_ash(target)
	_queue_devils_due(target, amount, dr)
	_reap(target, amount)


## The damage type that carries the most of `parts`.
static func _main_type(parts: Array) -> String:
	var best := ""
	var most := -1
	for raw: Variant in parts:
		var p := raw as Dictionary
		if int(p.get("amount", 0)) > most:
			most = int(p.get("amount", 0))
			best = str(p.get("type", "necrotic"))
	return best if best != "" else "necrotic"


## A save that puts out Consuming Pyre's flames ends the spell.
func after_save_ended(c: Combatant, fx: Effect) -> void:
	if fx.source_id == "consuming_pyre":
		_end_spell(enc().get_c(fx.caster_id), "consuming_pyre", "the flames on %s are out" % c.name())


# --- Devil's Due (a queued Reaction) -----------------------------------------------------------------------------

## Devil's Due's Reaction: a caster within 30 ft of `target` (another creature) that took damage, hurt itself and with
## a Hit Point Die and a slot to spend, is offered it once the blow is done. The trigger is the caster (the creature hurt
## may be dead by then); a Critical Hit is remembered.
func _queue_devils_due(target: Combatant, amount: int, dr: DamageResult) -> void:
	var e := enc()
	if amount <= 0:
		return
	var crit := dr != null and dr.critical
	for p in e.living():
		var ch := _ch(p)
		if p == target or ch == null or not ch.knows_spell("devils_due") or e.distance(p, target) > 30:
			continue
		if p.creature.hp <= 0 or p.creature.hp >= p.creature.max_hp() or _hit_dice_left(ch) <= 0:
			continue
		if not e.spells.can_cast_reaction(p, "devils_due"):
			continue
		var queued := false
		for q in e.reaction_queue:
			if str(q.get("kind", "")) == "gm_sa_devils_due" and str(q.get("reactor", "")) == p.id:
				queued = true
				q["crit"] = bool(q.get("crit", false)) or crit
		if queued:
			continue
		var plan := str(p.reaction_rules.get("devils_due", "ask")) if p.is_player_controlled() else "auto"
		if plan == "never":
			continue
		var q2 := {"kind": "gm_sa_devils_due", "reactor": p.id, "trigger": p.id, "hurt": target.id, "crit": crit}
		if plan == "auto":
			q2["plan"] = "auto"
		e.reaction_queue.append(q2)


static func _hit_dice_left(ch: Character) -> int:
	var n := 0
	var pool := ch.hit_dice()
	for die: String in pool:
		n += int((pool[die] as Dictionary)["total"]) - int((pool[die] as Dictionary)["spent"])
	return n


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	if str(q["kind"]) == "gm_sa_devils_due":
		return _ch(reactor) != null and _hit_dice_left(_ch(reactor)) > 0 and enc().spells.can_cast_reaction(reactor, "devils_due")
	return false


func queued_text(kind: String) -> Array:
	if kind == "gm_sa_devils_due":
		return ["Reaction: Devil's Due?", "Life spills out beside %s. Should %s drink some in with Devil's Due (spend a Hit Point Die: regain what it rolls plus the spellcasting modifier, doubled after a Critical Hit)?",
			"Reaction and a level 1+ spell slot"]
	return super(kind)


## Devil's Due: the slot (the lowest), one Hit Point Die and one more a slot level above 1 (the largest left), and the
## caster regains their roll plus its spellcasting modifier, twice that after a Critical Hit.
func fire_queued(q: Dictionary, reactor: Combatant, _trigger: Combatant) -> CombatResult:
	var e := enc()
	if str(q["kind"]) != "gm_sa_devils_due":
		return CombatResult.new()
	var ch := _ch(reactor)
	reactor.reaction_available = false
	if not e.spells.casting_gate(reactor):
		return CombatResult.new()
	var paid := e.spells.reaction_spells.pay(reactor, "devils_due")
	var slot := maxi(1, int(paid["level"]))
	e.spells.trigger_ends(reactor, "cast_spell")
	var rolls: Array[String] = []
	var total := 0
	for i in slot:
		var best := 0
		var pool := ch.hit_dice()
		for die: String in pool:
			if int((pool[die] as Dictionary)["spent"]) < int((pool[die] as Dictionary)["total"]) and int(die) > best:
				best = int(die)
		if best == 0:
			break
		ch.hit_dice_spent[str(best)] = int(ch.hit_dice_spent.get(str(best), 0)) + 1
		var roll := e.dice.roll_one(best, "Devil's Due (d%d)" % best)
		rolls.append("d%d: %d" % [best, roll])
		total += roll
	var amount := total + int(_nums(reactor, "devils_due").get("mod", 0))
	if bool(q.get("crit", false)):
		amount *= 2
		rolls.append("doubled: a Critical Hit")
	_log("spell", "%s casts Devil's Due (%s)" % [reactor.name(), "free casting" if bool(paid["free"]) else "level %d slot" % slot], reactor)
	_heal(reactor, maxi(0, amount), "Devil's Due", rolls)
	return CombatResult.new()


# --- Eye Burn (a Reaction before an attack roll) ------------------------------------------------------------------

## Eye Burn, asked when a creature within 30 ft that the caster sees attacks it, before the roll. The attacker saves
## (Constitution; Blindsight, an immunity to Blinded or an earlier casting's 24 hours pass it): a failure Blinds it to
## the end of the turn, so this attack has Disadvantage; a success takes 1d4 off this attack roll.
func before_roll(st: Dictionary, out: Array) -> void:
	var e := enc()
	var attacker := st["c"] as Combatant
	var target := st["target"] as Combatant
	if attacker == target or not _cantrip_react_ok(target, "eye_burn"):
		return
	if e.distance(target, attacker) > 30 or not e.can_see(target, attacker):
		return
	var dis := (st["sit"] as Dictionary)["disadvantage"] as Array[String]
	out.append({"kind": "eye_burn", "reactor": target, "trigger": attacker.id, "title": "Reaction: Eye Burn?", "default": "ask",
		"text": "%s attacks %s. Sting its eyes? A Constitution save or it's Blinded to the end of the turn (Disadvantage on this attack); a success still takes 1d4 off the roll." \
			% [attacker.name(), target.name()],
		"cost": "Reaction (a cantrip)",
		"still": func() -> bool: return _cantrip_react_ok(target, "eye_burn"),
		"use": func() -> void: _eye_burn(target, attacker, dis)})


func _eye_burn(caster: Combatant, attacker: Combatant, dis: Array[String]) -> void:
	var e := enc()
	caster.reaction_available = false
	if not e.spells.casting_gate(caster):
		return
	e.spells.trigger_ends(caster, "cast_spell")
	var details: Array[String] = []
	var saved := true
	if attacker.creature.sense_range("blindsight") > 0 or attacker.creature.is_condition_immune(&"blinded") or _resists_eye_burn(attacker, caster):
		details.append("%s succeeds automatically" % attacker.name())
	else:
		var keys := SpellCaster.spell_save_keys(caster.id)
		keys.append("save_vs:blinded")
		var sv := attacker.creature.roll_save(e.dice, &"con", e.spells.reaction_spells.reaction_dc(caster, "eye_burn"), [], [],
			"Constitution save vs Eye Burn (%s)" % attacker.name(), keys)
		saved = sv.success
		details.append(sv.describe())
	_mark_eye_burn_resisted(attacker, caster)
	var who := e.current()
	var fx := Effect.new("Eye Burn", &"spell", "eye_burn")
	fx.caster_id = caster.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = who.id if who != null else attacker.id
	if saved:
		# −1d4 on this attack roll only: used up as it's rolled.
		fx.modifiers.append(Modifier.of("penalty_die", {"dice": "1d4", "on": ["attack"]}, "Eye Burn", &"spell"))
		fx.consume_on = ["attack"]
		attacker.creature.add_effect(fx)
		_log("spell", "%s casts Eye Burn: %s blinks it away, but its attack takes −1d4" % [caster.name(), attacker.name()], caster, details)
		return
	fx.name = "Blinded (Eye Burn)"
	fx.conditions.append(&"blinded")
	attacker.creature.add_effect(fx)
	dis.append("Eye Burn (Blinded)")
	e.events.append({"type": "condition", "id": attacker.id})
	_log("spell", "%s casts Eye Burn: %s is Blinded to the end of the turn" % [caster.name(), attacker.name()], caster, details)


## Whether `t` passes `caster`'s Eye Burn on its own: it was the target of one in the last 24 hours (on the creature, so
## the next fight that day remembers it).
static func _resists_eye_burn(t: Combatant, caster: Combatant) -> bool:
	return t.creature.has_flag("sa_eye_burn_resists:%s" % caster.id)


## Eye Burn's 24 hours: a timed effect on the creature that outlives the fight (game time counts it down).
func _mark_eye_burn_resisted(t: Combatant, caster: Combatant) -> void:
	if _resists_eye_burn(t, caster):
		return
	var fx := Effect.new("Eye Burn (stung, 24 hours)", &"spell", "eye_burn").lasting({"kind": "hours", "amount": 24})
	fx.caster_id = caster.id
	fx.stack_key = "spell:eye_burn:resists:%s" % caster.id
	fx.modifiers.append(Modifier.of("flag", {"value": "sa_eye_burn_resists:%s" % caster.id}, "Eye Burn", &"spell"))
	t.creature.add_effect(fx)


# --- Rolls ---------------------------------------------------------------------------------------------------------

## Before a D20 Test: a creature that passed Captivate Undead's save loses its wariness once it attacks the caster, and
## a save the captivator's side forces on a captivated creature ends the spell.
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	if kind == D20Test.Kind.ATTACK_ROLL:
		for k in keys:
			if not k.begins_with("target:"):
				continue
			for fx: Effect in c.creature.effects.duplicate():
				if fx.source_id == "captivate_undead" and _flagged(fx, "sa_wary_of:%s" % k.substr(7)):
					c.creature.remove_effect(fx)
	if kind == D20Test.Kind.SAVING_THROW and _captivated(c) != null:
		for k in keys:
			if k.begins_with("save_vs:spell:"):
				_break_captivation(c, enc().get_c(k.substr(14)), "makes a save")
	return {}


## Cursed Cacophony: the first D20 Test the cursed creature fails in a turn, it saves again (Wisdom, a straight roll
## whatever the curse says); a success ends the spell.
func d20_offers(c: Combatant, t: D20Test, _keys: Array[String], out: Array) -> void:
	if t.success:
		return
	var fx := _fx(c, "cursed_cacophony")
	if fx == null or fx.repeat_save.is_empty() or str(c.get_meta("sa_cacophony_turn", "")) == _turn_key():
		return
	out.append({"kind": "sa_cursed_cacophony", "reactor": c, "trigger": c.id, "title": "Cursed Cacophony", "forced": true,
		"text": "%s fails a roll under the curse and fights the music again." % c.name(), "cost": "Nothing", "spends_reaction": false,
		"still": func() -> bool: return not t.success and fx in c.creature.effects and str(c.get_meta("sa_cacophony_turn", "")) != _turn_key(),
		"use": func() -> void: _cacophony_resave(c, fx)})


func _cacophony_resave(c: Combatant, fx: Effect) -> void:
	var e := enc()
	c.set_meta("sa_cacophony_turn", _turn_key())
	var sv := D20Test.roll(e.dice, D20Test.Kind.SAVING_THROW, c.creature.save_bonus(&"wis").total(), int(fx.repeat_save.get("dc", 10)), 0, 0,
		"Wisdom save to end Cursed Cacophony (%s)" % c.name())
	if not sv.success:
		_log("info", "%s can't shake the music (Cursed Cacophony)" % c.name(), c, [sv.describe()])
		return
	c.creature.remove_effect(fx)
	_log("info", "%s shakes off the music (Cursed Cacophony)" % c.name(), c, [sv.describe()])
	e.events.append({"type": "condition", "id": c.id})
	_end_spell(e.get_c(fx.caster_id), "cursed_cacophony", "%s shook it off" % c.name())


# --- Attacks and movement ------------------------------------------------------------------------------------------

## Chain of Conviction: Advantage for the caster against the creature it chained. Captivate Undead's success: Disadvantage
## on the creature's next attack against the caster (used up as that roll is made: before_d20).
func attack_situation(c: Combatant, target: Combatant, _option: Dictionary, adv: Array[String], dis: Array[String]) -> void:
	if target.creature.has_flag("chained:%s" % c.id):
		adv.append("Chain of Conviction")
	if c.creature.has_flag("sa_wary_of:%s" % target.id):
		dis.append("Captivate Undead")


## Chain of Conviction: the chained creature can't move more than 30 ft from the caster.
func barrier_cells(c: Combatant) -> Dictionary:
	var out := {}
	var e := enc()
	for m in c.creature.modifiers_for(&"flag"):
		var v := m.text("value")
		if not v.begins_with("chained:"):
			continue
		var holder := e.get_c(v.substr(8))
		if holder == null:
			continue
		for x in e.grid.width:
			for y in e.grid.depth:
				var cell := Vector2i(x, y)
				if e.grid.distance_ft(cell, c.size_cells, holder.cell, holder.size_cells) > 30:
					out[cell] = true
	return out


# --- Turns ---------------------------------------------------------------------------------------------------------

## As a turn starts: Crooked Ward's spared kept current, Ancestral Communion's inspiration, the pyre's flames, a
## commanded Beast, a buried creature the AI plays digging.
func turn_start(c: Combatant) -> CombatResult:
	for o in enc().spells.zones.live():
		if o.spell_id == "crooked_ward":
			_ward_spare(o)
	if c.creature.has_flag("ancestral_communion"):
		_inspire(c, c, "Ancestral Communion")
	_pyre_burn(c)
	_wild_turn_start(c)
	if _grave(c) != null and not c.is_player_controlled() and c.can_act() and c.action_available:
		_dig(c)
	return CombatResult.new()


func turn_end(c: Combatant) -> void:
	_reaping_turn_end(c)
	_grave_turn_end(c)


## A burning creature the AI plays smothers its own flames when the next burst could fell it.
func monster_turn(c: Combatant) -> Variant:
	if _pyre(c) != null and c.can_act() and c.action_available and c.creature.hp <= 18:
		return _smother(c, c, true)
	return null


# --- The hotbar and sustained actions ------------------------------------------------------------------------------

## A buried creature's dig, smothering a burning creature beside you, absorbing an ally's harvest moonlight.
func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var e := enc()
	var grave := _grave(c)
	if grave != null:
		out.append(_act("dig", "Dig out", "DC %d Athletics" % DIG_DC, "action", aw, "none",
			"An action: a DC %d Strength (Athletics) check digs 5 ft up out of the grave (%d ft to go), or all the way when it beats the DC by 5. You come out Prone." \
				% [DIG_DC, int(grave.data.get("sa_depth", GRAVE_FT))]))
	if e.living().any(func(b: Combatant) -> bool: return b != c and _pyre(b) != null and e.distance(c, b) <= 5):
		out.append(_act("smother", "Smother the flames", "Consuming Pyre", "action", aw, "creature",
			"An action: beat at the flames on a burning creature within 5 ft; it repeats the Dexterity save and a success ends the spell.", 5))
	var glow := _moonglow_over(c)
	if glow != null:
		out.append(_act("moonglow", "Absorb the moonlight", "%dd6 Temporary Hit Points" % _moonglow_dice(glow), "bonus", bw, "none",
			"A Bonus Action: drink in the harvest moon's light for %dd6 Temporary Hit Points." % _moonglow_dice(glow)))


func perform(c: Combatant, id: String, t: Combatant, _cell: Vector2i, _point: Vector2) -> CombatResult:
	var e := enc()
	match id:
		"sa_dig":
			return _dig(c)
		"sa_smother":
			if t == null or t == c or _pyre(t) == null or e.distance(c, t) > 5:
				return CombatResult.fail("Choose a burning creature within 5 ft")
			return _smother(c, t, true)
		"sa_moonglow":
			var glow := _moonglow_over(c)
			if glow == null:
				return CombatResult.fail("You aren't in the moonlight")
			c.bonus_available = false
			var rolled := e._roll_damage_dice("%dd6" % _moonglow_dice(glow), false, 0, "Harvest Moonglow")
			var n := int(rolled["total"])
			if c.creature.add_temp_hp(n, "Harvest Moonglow"):
				_log("heal", "%s absorbs the moonlight: %d Temporary Hit Points (Harvest Moonglow)" % [c.name(), n], c, [str(rolled["text"])])
			else:
				_log("info", "%s absorbs the moonlight but keeps its %d Temporary Hit Points" % [c.name(), c.creature.temp_hp], c, [str(rolled["text"])])
			return CombatResult.new()
	return CombatResult.fail("Not available")


## The Harvest Moonglow `c` stands in whose caster it's an ally of, or null.
func _moonglow_over(c: Combatant) -> FieldObject:
	var e := enc()
	for o in e.spells.zones.live():
		if o.spell_id != "harvest_moonglow" or not o.covers(c):
			continue
		var caster := e.get_c(o.caster_id)
		if caster != null and caster != c and caster.allied_with(c):
			return o
	return null


## Harvest Moonglow's dice: 2d6, and 1d6 more a slot level above 3.
static func _moonglow_dice(o: FieldObject) -> int:
	return 2 + maxi(0, o.slot - 3)


func sustained_why(c: Combatant, a: Dictionary, d: Dictionary, _t: Combatant, _point: Vector2) -> String:
	match str(d.get("mode", "")):
		"sa_call_of_the_wild":
			if not enc().living().any(func(b: Combatant) -> bool: return _wild_hold(b, str(a["caster_id"])) != null):
				return "No Beast follows the call"
		"sa_consuming_pyre":
			if _pyre(c) == null:
				return "Not burning"
	return ""


## Call of the Wild's new command (every Beast it holds follows it on its next turn); Consuming Pyre's smothering by the
## burning creature itself.
func sustained(c: Combatant, a: Dictionary, d: Dictionary, _ctx: Dictionary, _targets: Array, _point: Vector2, _dir: Vector2, _r: CombatResult) -> CombatResult:
	match str(d.get("mode", "")):
		"sa_call_of_the_wild":
			for b in enc().living():
				if _wild_hold(b, str(a["caster_id"])) != null:
					b.set_meta("sa_wild_orders", true)
			_log("spell", "%s howls a new command to the Beasts (Call of the Wild)" % c.name(), c)
		"sa_consuming_pyre":
			_smother(c, c, false)
	return CombatResult.new()
