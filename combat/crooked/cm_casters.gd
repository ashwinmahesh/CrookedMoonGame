class_name CmCasters
extends CmPart
## The Crooked Moon's code for three of the book's subclasses (chapter 3): College of Whistles, Harvest Domain and Circle of the Old Ways: the parts of them data can't say.
## CrookedFeatures forwards every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start
## "cs_".
##
## College of Whistles: a haint called with Bardic Inspiration is a zone round the inspired creature (spell id
## `HAINT`, its caster the inspired creature, so it follows it and counts its minute on that creature's turns; the bard
## in its `bard` rule). Grump's and Sad Sack's gifts inside are the zone's `inside` modifiers; their Reactions and
## Scamp's are offers of kind "handy_haints" (its policy). Ride the Rails is a hotbar Magic action.
## Harvest Domain: the aspect is the pick of Harvest Domain Spells' choice; Bountiful Harvest is a hotbar Magic action,
## Blessing of the Seasons an offer after a failed save. Circle of the Old Ways: Wood Wose is the data's activation
## (FeatureRecipes; its effect's source is "wood_wose"), with a rider that wakes it as Shillelagh is cast; the rest
## reads that effect.

const PREFIX := "cs_"
## The haints' zones (FieldObject.spell_id).
const HAINT := "cs_haint"
## The haints: id -> [name, zone colour, what calling it gives].
const HAINTS := {
	"grump": ["Grump", "flame", "Advantage on Strength saves and Intimidation in the aura; Reaction: a Bardic die + Cha more on a hit's damage"],
	"sad_sack": ["Sad Sack", "mist_blue", "Half Cover against ranged attacks in the aura; Reaction: cut damage by a Bardic die + Cha"],
	"scamp": ["Scamp", "candle", "+10 ft Speed for allies starting a turn in the aura; Reaction: reroll a failed save"],
}
## Blessing of the Seasons: the saves each harvest aspect answers.
const SEASON_SAVES := {"sowing": ["dex", "cha"], "growing": ["con", "int"], "reaping": ["wis", "str"]}
## The weapons Shillelagh fills.
const SHILLELAGH_WEAPONS := ["club", "quarterstaff"]
## The rider that wakes Wood Wose as Shillelagh is cast.
const WOSE_RIDER := "cs_wose_with_shillelagh"

## Grump's Reaction on an attack: target id -> the damage the haint adds as the blow lands (adjust_incoming).
var _grump_adds: Dictionary = {}


func prefix() -> String:
	return PREFIX


func cf() -> ClassFeatures:
	return enc().class_features


# --- The hotbar ---------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, _bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	var tw := e._turn_check(c)
	var magic := _first(aw, "Only one Magic action this turn" if c.magic_action_used else "")
	# Handy Haints: the Bardic Inspiration just given can call a haint round the creature it went to.
	if has(c, "handy_haints") and str(c.get_meta("cs_haint_window", "")) == _turn_key():
		var ally := e.get_c(str(c.get_meta("cs_haint_ally", "")))
		if ally != null and ally.is_alive():
			for form: String in HAINTS:
				var h := HAINTS[form] as Array
				out.append(_act("haint:" + form, "Haint: %s" % h[0], "15-ft aura on %s · 1 min" % ally.name(), "free", tw, "none",
					"Call the %s haint round %s, whom you just inspired: %s. It fades after a minute, when you call another, use its Reaction or are Incapacitated." % [h[0], ally.name(), h[2]]))
	if has(c, "ride_the_rails"):
		var why := _first(magic, _rails_why(ch))
		var sub := "%d left" % ch.resource_left("ride_the_rails") if ch.resource_left("ride_the_rails") > 0 else "a level %d slot" % _rails_slot(ch)
		out.append(_act("ride_the_rails", "Ride the Rails", "120-ft Line · %s" % sub, "action", why, "point",
			"Magic action: a spectral train runs a 120-ft, 10-ft-wide Line. You and up to six allies within 30 ft ride it to the space you pick; everyone else in it makes a Wisdom save or is Deafened, pushed 10 ft and takes three Bardic dice of Psychic damage.", 120))
		out.append(_act("ride_the_rails:alone", "Ride the Rails (alone)", "120-ft Line · no riders", "action", why, "point",
			"Ride the Rails, leaving your allies where they stand.", 120))
	if has(c, "bountiful_harvest"):
		var aspect := _aspect(c)
		var gifts := {"sowing": "Temporary Hit Points equal to your Proficiency Bonus + Wisdom modifier",
			"growing": "+1d4 to attack rolls and ability checks until the end of your next turn",
			"reaping": "extra Necrotic damage equal to your Proficiency Bonus the first time each damages a creature before the end of your next turn"}
		var bh := _act("bountiful_harvest", "Bountiful Harvest (%s)" % aspect.capitalize(), "Channel Divinity · 6 within 60 ft", "action",
			_first(magic, _res_why(c, "channel_divinity")), "none",
			"Magic action: up to six creatures within 60 ft (you and your nearest allies) gain Heroic Inspiration (once per Long Rest each) and one gift, your aspect's unless you pick another (your aspect then changes to it). %s: %s." % [aspect.capitalize(), gifts[aspect]])
		var opts: Array = []
		for g: String in SEASON_SAVES:
			opts.append({"value": g, "label": "%s%s" % [g.capitalize(), " (your aspect)" if g == aspect else ""]})
		bh["choices"] = opts
		bh["choice_label"] = "Gift"
		out.append(bh)


func perform(c: Combatant, id: String, _t: Combatant, cell: Vector2i, point: Vector2) -> CombatResult:
	if id.begins_with(PREFIX + "haint:"):
		return _call_haint(c, id.get_slice(":", 1))
	match id:
		"cs_ride_the_rails":
			return _ride_the_rails(c, cell, point, true)
		"cs_ride_the_rails:alone":
			return _ride_the_rails(c, cell, point, false)
		"cs_bountiful_harvest":
			return _bountiful_harvest(c)
	return CombatResult.fail("Not available")


## Wood Wose "as part of casting Shillelagh": armed, the next Shillelagh this turn wakes it too.
func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := _ch(c)
	if ch != null and has(c, "wood_wose") and not in_wose(c):
		out.append({"id": WOSE_RIDER, "label": "Wood Wose with Shillelagh", "sub": "a Wild Shape use: wakes as you cast Shillelagh",
			"why": "" if ch.resource_left("wild_shape") > 0 else "No Wild Shape left"})
	return out


## Handy Haints: giving Bardic Inspiration opens the haint picks for the rest of the turn.
func after_action(c: Combatant, action: Dictionary, targets: Array = []) -> void:
	if ActionCatalog.ability_key(action) == "bardic_inspiration" and has(c, "handy_haints") and not targets.is_empty() and targets[0] is Combatant:
		c.set_meta("cs_haint_window", _turn_key())
		c.set_meta("cs_haint_ally", (targets[0] as Combatant).id)


# --- College of Whistles: Handy Haints ----------------------------------------------------------------------------

## Calls the haint `form` round the creature just inspired, sending any haint of this bard's away first.
func _call_haint(c: Combatant, form: String) -> CombatResult:
	var e := enc()
	if not HAINTS.has(form) or str(c.get_meta("cs_haint_window", "")) != _turn_key():
		return CombatResult.fail("Only right after giving Bardic Inspiration")
	var ally := e.get_c(str(c.get_meta("cs_haint_ally", "")))
	if ally == null or not ally.is_alive():
		return CombatResult.fail("The inspired creature is gone")
	for old in _haints():
		if str(old.rule("bard", "")) == c.id:
			old.ended = true
	e.spells.zones.prune()
	c.remove_meta("cs_haint_window")
	var h := HAINTS[form] as Array
	var o := FieldObject.new(FieldObject.Kind.ZONE, HAINT, "Haint (%s)" % h[0])
	o.caster_id = ally.id
	o.follows_caster = true
	o.cell = ally.cell
	o.cells = e.grid.area_cells("emanation", 15, e.center_of(ally), Vector2.RIGHT, 5, ally.cell, ally.size_cells)
	o.rounds_left = Effect.ROUNDS_PER_MINUTE
	o.rules = {"size": 15, "affects": "allies", "triggers": [], "haint": form, "bard": c.id, "colour": h[1]}
	match form:
		"grump":
			o.rules["inside"] = {"modifiers": [{"stat": "advantage", "on": ["save:str", "check:intimidation"]}]}
		"sad_sack":
			# EncounterAttacks: at least Half Cover against ranged attacks.
			o.rules["inside"] = {"modifiers": [{"stat": "flag", "value": "half_cover_ranged"}]}
	e.spells.zones.add(o, CombatResult.new())
	_log("info", "%s whistles up a haint: %s drifts round %s" % [c.name(), h[0], ally.name()], c)
	return CombatResult.new()


## The haints in play. One whose bard is down or Incapacitated fades first.
func _haints() -> Array[FieldObject]:
	var e := enc()
	var out: Array[FieldObject] = []
	var gone := false
	for o in e.spells.zones.live():
		if o.spell_id != HAINT:
			continue
		var bard := e.get_c(str(o.rule("bard", "")))
		if bard == null or not bard.can_act():
			o.ended = true
			gone = true
			continue
		out.append(o)
	if gone:
		e.spells.zones.prune()
	return out


## The live haint of `form` whose aura holds `t`, the inspired creature or one of its allies, or null.
func _haint_round(t: Combatant, form: String) -> FieldObject:
	if t == null:
		return null
	for o in _haints():
		if str(o.rule("haint", "")) == form and o.covers(t) and enc().spells.zones.affects(o, t):
			return o
	return null


func _bard_of(o: FieldObject) -> Combatant:
	return enc().get_c(str(o.rule("bard", "")))


## Using the haint's Reaction sends it away.
func _end_haint(o: FieldObject) -> void:
	o.ended = true
	enc().spells.zones.prune()


## A roll of the bard's Bardic Inspiration die plus its Charisma modifier (at least 0).
func _haint_roll(bard: Combatant, label: String) -> int:
	return maxi(0, enc().dice.roll_one(ClassFeatures.bardic_die(bard), label) + bard.creature.ability_mod(&"cha"))


## The haints' Reactions on an attack's damage: Sad Sack cuts what a creature in its aura takes, Grump adds to what a
## creature in its aura deals.
func against_damage(st: Dictionary, total: Callable, cut: Callable, out: Array) -> void:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var sad := _haint_round(target, "sad_sack")
	if sad != null:
		var bard := _bard_of(sad)
		if e.spells.can_react(bard):
			out.append({"kind": "handy_haints", "reactor": bard, "trigger": c.id, "default": "ask", "title": "Reaction: Sad Sack?",
				"text": func() -> String: return "%s hits %s for %d. The Sad Sack haint can soak a Bardic die (d%d) + %d of it." % [c.name(), target.name(), int(total.call()), ClassFeatures.bardic_die(bard), bard.creature.ability_mod(&"cha")],
				"cost": "Your Reaction (the haint then fades)",
				"still": func() -> bool: return not sad.expired() and e.spells.can_react(bard) and int(total.call()) > 0,
				"use": func() -> void:
					bard.reaction_available = false
					var n := _haint_roll(bard, "Sad Sack")
					cut.call(n, "Sad Sack")
					_log("reaction", "The Sad Sack haint sighs over %s: %d less damage" % [target.name(), n], bard)
					_end_haint(sad)})
	var grump := _haint_round(c, "grump")
	if grump != null:
		var gb := _bard_of(grump)
		if gb.hostile_to(target) and e.spells.can_react(gb):
			out.append({"kind": "handy_haints", "reactor": gb, "trigger": c.id, "default": "ask", "title": "Reaction: Grump?",
				"text": func() -> String: return "%s hits %s for %d. The Grump haint can add a Bardic die (d%d) + %d." % [c.name(), target.name(), int(total.call()), ClassFeatures.bardic_die(gb), gb.creature.ability_mod(&"cha")],
				"cost": "Your Reaction (the haint then fades)",
				"still": func() -> bool: return not grump.expired() and e.spells.can_react(gb),
				"use": func() -> void:
					gb.reaction_available = false
					var n := _haint_roll(gb, "Grump")
					_grump_adds[target.id] = int(_grump_adds.get(target.id, 0)) + n
					_log("reaction", "The Grump haint bellows at %s: +%d damage" % [target.name(), n], gb)
					_end_haint(grump)})


## Damage that isn't an attack's (a spell's save, a breath): the haints' Reactions where nobody can be asked, on
## Automatic only.
func _haints_sync(source: Combatant, target: Combatant, ps: Array) -> void:
	var e := enc()
	if source != null and source != target and not ps.is_empty():
		var grump := _haint_round(source, "grump")
		if grump != null:
			var gb := _bard_of(grump)
			if gb.hostile_to(target) and e.spells.can_react(gb) and e._reaction_decision(gb, "handy_haints", "ask") == "auto":
				gb.reaction_available = false
				var n := _haint_roll(gb, "Grump")
				ps.append({"amount": n, "type": str((ps[0] as Dictionary)["type"])})
				_log("reaction", "The Grump haint bellows at %s: +%d damage" % [target.name(), n], gb)
				_end_haint(grump)
	var sad := _haint_round(target, "sad_sack")
	if sad != null:
		var bard := _bard_of(sad)
		if e.spells.can_react(bard) and e._reaction_decision(bard, "handy_haints", "ask") == "auto" and _sum(ps) > 0:
			bard.reaction_available = false
			var n := _haint_roll(bard, "Sad Sack")
			var left := n
			for raw: Variant in ps:
				var part := raw as Dictionary
				var take := mini(left, int(part["amount"]))
				part["amount"] = int(part["amount"]) - take
				left -= take
			_log("reaction", "The Sad Sack haint sighs over %s: %d less damage" % [target.name(), n - left], bard)
			_end_haint(sad)


static func _sum(ps: Array) -> int:
	var n := 0
	for raw: Variant in ps:
		n += int((raw as Dictionary)["amount"])
	return n


# --- College of Whistles: Ride the Rails --------------------------------------------------------------------------

## Why Ride the Rails can't be paid for: no use left and no slot of level 3 or higher to restore it.
func _rails_why(ch: Character) -> String:
	return "" if ch.resource_left("ride_the_rails") > 0 or _rails_slot(ch) > 0 else "None left"


## The lowest slot of level 3 or higher left, or 0.
static func _rails_slot(ch: Character) -> int:
	for l in range(3, 10):
		if ch.slots_left(l) > 0:
			return l
	return 0


## Ride the Rails: the train runs a 120 x 10 ft Line toward `point`; the bard (and, with `riders`, up to six allies
## within 30 ft) teleport along it, and every other creature in it saves or is Deafened, pushed and hurt.
func _ride_the_rails(c: Combatant, cell: Vector2i, point: Vector2, riders: bool) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var why := _first(e._action_check(c), "Only one Magic action this turn" if c.magic_action_used else "")
	why = _first(why, _rails_why(ch))
	if why != "":
		return CombatResult.fail(why)
	if point == Vector2.INF:
		return CombatResult.fail("Pick where the train runs")
	var origin := e.center_of(c)
	var dir := point - origin
	if dir.length() < 0.01:
		return CombatResult.fail("Pick a point away from you")
	var line := e.grid.area_cells("line", 120, origin, dir, 10)
	var dest := _rail_stop(c, line, cell, point)
	if dest.x < 0:
		return CombatResult.fail("No room on the line")
	var party: Array[Combatant] = []
	if riders:
		for raw: Variant in targets_in:
			var a := raw as Combatant
			if a != null and a != c and c.allied_with(a) and a.can_act() and e.distance(c, a) <= 30 and not a in party:
				party.append(a)
		if party.is_empty():
			for a in e.allies_of(c):
				if a.can_act() and e.distance(c, a) <= 30:
					party.append(a)
			party.sort_custom(func(a: Combatant, b: Combatant) -> bool: return e.distance(c, a) < e.distance(c, b))
		party = party.slice(0, 6)
	if ch.resource_left("ride_the_rails") > 0:
		ch.spend_resource("ride_the_rails")
	else:
		var slot := _rails_slot(ch)
		ch.expend_slot(slot)
		_log("info", "%s spends a level %d slot to whistle the train again" % [c.name(), slot], c)
	e.spend_action(c)
	c.magic_action_used = true
	var struck: Array[Combatant] = []
	for t in e.spells.creatures_in(line):
		if t != c and not t in party:
			struck.append(t)
	e.events.append({"type": "spell", "caster": c.id, "spell": "ride_the_rails", "cells": line,
		"targets": struck.map(func(x: Combatant) -> String: return x.id)})
	_log("info", "%s whistles up a spectral train (Ride the Rails)" % c.name(), c)
	var r := CombatResult.new()
	e.spells._teleport(c, dest, r)
	for a in party:
		var spot := _nearest_free(a, dest)
		if spot.x >= 0:
			e.spells._teleport(a, spot, r)
	var die := ClassFeatures.bardic_die(c)
	var dc := cf()._spell_dc(c, "bard")
	for t in struck:
		if not t.is_alive() or cf()._save(t, &"wis", dc, "Ride the Rails", "deafened"):
			continue
		var deaf := cf()._timed(c, "Ride the Rails", "cs_ride_the_rails", Effect.Ends.START_OF_TURN, c).with_condition(&"deafened")
		t.creature.add_effect(deaf)
		e.forced_move(t, origin, 10)
		var rolled := e._roll_damage_dice("3d%d" % die, false, 0, "Ride the Rails")
		e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "psychic"}], false, "Ride the Rails", [str(rolled["text"])])
	return r


## Where the bard gets off: the picked square when it's on the Line and free, else the free square of the Line nearest
## the point; (-1, -1) when none is.
func _rail_stop(c: Combatant, line: Array[Vector2i], cell: Vector2i, point: Vector2) -> Vector2i:
	var e := enc()
	if cell in line and e.space_available(cell, c.size_cells, [c]):
		return cell
	var best := Vector2i(-1, -1)
	var best_d := INF
	for sq in line:
		if not e.space_available(sq, c.size_cells, [c]):
			continue
		var d := (Vector2(sq.x + 0.5, sq.y + 0.5) - point).length()
		if d < best_d:
			best_d = d
			best = sq
	return best


## The free square nearest `at` for `a` (within 30 ft of it), or (-1, -1).
func _nearest_free(a: Combatant, at: Vector2i) -> Vector2i:
	var e := enc()
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var sq := at + Vector2i(dx, dz)
			if not e.grid.in_bounds(sq) or not e.space_available(sq, a.size_cells, [a]):
				continue
			var d := Vector2(dx, dz).length()
			if d < best_d:
				best_d = d
				best = sq
	return best


# --- Harvest Domain ------------------------------------------------------------------------------------------------

## The cleric's harvest aspect: the pick of Harvest Domain Spells' choice (Sowing when there's none).
static func _aspect(c: Combatant) -> String:
	var ch := _ch(c)
	if ch != null:
		for cd in ch.choice_defs:
			if cd.key.contains("harvest_domain_spells") and not cd.picks.is_empty() and SEASON_SAVES.has(str(cd.picks[0])):
				return str(cd.picks[0])
	return "sowing"


## Bountiful Harvest: Channel Divinity; up to six creatures within 60 ft gain Heroic Inspiration (each once per Long
## Rest) and one aspect's gift (the right-click pick, else the cleric's aspect), and the cleric's aspect becomes it.
func _bountiful_harvest(c: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var why := _first(e._action_check(c), "Only one Magic action this turn" if c.magic_action_used else "")
	why = _first(why, _res_why(c, "channel_divinity"))
	if why != "":
		return CombatResult.fail(why)
	var picks: Array[Combatant] = []
	for raw: Variant in targets_in:
		var t := raw as Combatant
		if t != null and t.is_alive() and e.distance(c, t) <= 60 and not t in picks:
			picks.append(t)
	if picks.is_empty():
		picks.append(c)
		var near: Array[Combatant] = []
		for a in e.allies_of(c):
			if e.distance(c, a) <= 60:
				near.append(a)
		near.sort_custom(func(a: Combatant, b: Combatant) -> bool: return e.distance(c, a) < e.distance(c, b))
		picks.append_array(near)
	picks = picks.slice(0, 6)
	ch.spend_resource("channel_divinity")
	e.spend_action(c)
	c.magic_action_used = true
	var aspect := choice_in if SEASON_SAVES.has(choice_in) else _aspect(c)
	if aspect != _aspect(c):
		_set_aspect(c, aspect)
	var pb := c.creature.proficiency_bonus()
	_log("info", "%s raises the holy symbol: Bountiful Harvest (%s)" % [c.name(), aspect.capitalize()], c)
	for t in picks:
		if _ch(t) != null and cf()._uses(t, "cs_harvest_inspiration", "Bountiful Harvest's Heroic Inspiration", 1, "long") > 0 \
				and _inspire(c, t, "Bountiful Harvest"):
			_ch(t).spend_resource("cs_harvest_inspiration")
		match aspect:
			"sowing":
				cf()._temp(t, pb + c.creature.ability_mod(&"wis"), "Bountiful Harvest")
			"growing":
				_season_gift(c, t, "Growing", "cs_growing", Modifier.of("bonus_die", {"dice": "1d4", "on": ["attack", "check:all"]}, "Growing", &"feature"))
				_log("info", "%s adds 1d4 to attacks and checks (Growing)" % t.name(), t)
			"reaping":
				var fx := _season_gift(c, t, "Reaping", "cs_reaping", Modifier.of("flag", {"value": "cs_reaping"}, "Reaping", &"feature"))
				fx.data["pb"] = pb
				_log("info", "%s's next blow reaps %d Necrotic (Reaping)" % [t.name(), pb], t)
	return CombatResult.new()


## The cleric's aspect changes to `pick`: Harvest Domain Spells' build choice changes (as at a rest) and the sheet is
## rebuilt, so its prepared spells follow.
func _set_aspect(c: Combatant, pick: String) -> void:
	var ch := _ch(c)
	for d in ch.choice_defs:
		if d.key.contains("harvest_domain_spells") and (d.picks.is_empty() or SEASON_SAVES.has(str(d.picks[0]))):
			ch.choices()[d.key] = [pick]
	CmPart.refresh_keeping(ch)
	_log("info", "%s's harvest turns to %s" % [c.name(), pick.capitalize()], c)
	enc().events.append({"type": "condition", "id": c.id})


## A Bountiful Harvest gift on `t` until the end of the cleric's next turn (a fresh one replaces the old).
func _season_gift(c: Combatant, t: Combatant, label: String, source: String, m: Modifier) -> Effect:
	for old: Effect in t.creature.effects.duplicate():
		if old.source_id == source:
			t.creature.remove_effect(old)
	var fx := cf()._timed(c, label, source, Effect.Ends.END_OF_TURN, c)
	fx.stack_key = source
	fx.modifiers.append(m)
	t.creature.add_effect(fx)
	return fx


# --- Damage --------------------------------------------------------------------------------------------------------

## Grump's Reaction lands with its blow; Reaping's extra Necrotic on the first damage dealt; the haints where the
## damage isn't an attack's.
func adjust_incoming(source: Combatant, target: Combatant, ps: Array) -> void:
	if target == null:
		return
	if _grump_adds.has(target.id):
		var n := int(_grump_adds[target.id])
		_grump_adds.erase(target.id)
		ps.append({"amount": n, "type": str((ps[0] as Dictionary)["type"]) if not ps.is_empty() else "force"})
	if source != null and source != target:
		for fx: Effect in source.creature.effects.duplicate():
			if fx.source_id == "cs_reaping":
				source.creature.remove_effect(fx)
				var pb := int(fx.data.get("pb", 2))
				ps.append({"amount": pb, "type": "necrotic"})
				_log("info", "Reaping: +%d Necrotic from %s" % [pb, source.name()], source)
				break
	if enc().hit_context.is_empty():
		_haints_sync(source, target, ps)


## Primeval Wrath and Bramblebark answer a melee hit (Encounter.hit_context names it while its damage is dealt).
func after_damage(source: Combatant, target: Combatant, _amount: int, _ps: Array = [], _dr: DamageResult = null) -> void:
	var e := enc()
	var hc := e.hit_context
	if source == null or target == null or source == target or hc.is_empty() or not bool(hc.get("melee", false)):
		return
	if str(hc.get("attacker", "")) != source.id or str(hc.get("target", "")) != target.id:
		return
	# Primeval Wrath: once a turn, a Strength save or Prone.
	if in_wose(source) and has(source, "deepwood_elder") and allowed(source, "deepwood_elder") and not target.is_down() \
			and not target.creature.has_condition(&"prone") and _once_per_turn(source, "cs_wrath"):
		if not cf()._save(target, &"str", cf()._spell_dc(source, "druid"), "Primeval Wrath", "prone"):
			target.creature.add_condition(&"prone", "Primeval Wrath")
			_log("condition", "Primeval Wrath: %s is thrown Prone" % target.name(), target)
	# Bramblebark: a melee attacker within 5 ft takes 1d8 Piercing, once a turn.
	if in_wose(target) and has(target, "deepwood_elder") and source.is_alive() and e.distance(source, target) <= 5 \
			and _once_per_turn(source, "cs_bramble_" + ClassFeatures.meta_key(target.id)):
		var rolled := e._roll_damage_dice("1d8", false, 0, "Bramblebark")
		e.deal_damage(target, source, [{"amount": int(rolled["total"]), "type": "piercing"}], false, "Bramblebark", [str(rolled["text"])])


# --- D20 Tests -----------------------------------------------------------------------------------------------------

## Scamp lets a creature in its aura reroll a failed save; Blessing of the Seasons rerolls a failed save of the
## cleric's aspect and heals either way.
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	if c == null or t.kind != D20Test.Kind.SAVING_THROW or t.target <= 0:
		return
	var sc := _haint_round(c, "scamp")
	if sc != null:
		var bard := _bard_of(sc)
		if e.spells.can_react(bard):
			out.append({"kind": "handy_haints", "reactor": bard, "trigger": c.id, "default": "ask", "title": "Reaction: Scamp?",
				"text": func() -> String: return "%s. The Scamp haint can let %s roll the d20 again." % [D20Responses.line(c, t), c.name()],
				"cost": "Your Reaction (the haint then fades)",
				"still": func() -> bool: return not t.success and not sc.expired() and e.spells.can_react(bard),
				"helps": func() -> bool: return D20Responses.could_reach(t),
				"use": func() -> void:
					bard.reaction_available = false
					t.reroll(e.dice, "Scamp", false, c.creature.has_flag("luck"))
					_log("reaction", "The Scamp haint tugs %s's luck: a reroll" % c.name(), bard, [t.describe()])
					_end_haint(sc)})
	for p in e.combatants:
		if not p.is_alive() or not p.allied_with(c) or _ch(p) == null or not has(p, "blessing_of_the_seasons"):
			continue
		if p != c and (e.distance(p, c) > 30 or not e.can_see(p, c)):
			continue
		var aspect := _aspect(p)
		var fits := false
		for ab: String in SEASON_SAVES[aspect]:
			fits = fits or ("save:" + ab) in keys
		if not fits:
			continue
		var cleric := p
		var pc := _ch(p)
		out.append({"kind": "blessing_of_the_seasons", "reactor": cleric, "trigger": c.id, "default": "ask",
			"title": "Reaction: Blessing of the Seasons?",
			"text": func() -> String: return "%s. %s can let it reroll the d20, then heal it %dd4 either way." % [D20Responses.line(c, t), cleric.name(), cleric.creature.proficiency_bonus()],
			"cost": func() -> String: return "Your Reaction and a use (%d left)" % pc.resource_left("blessing_of_the_seasons"),
			"still": func() -> bool: return not t.success and e.spells.can_react(cleric) and pc.resource_left("blessing_of_the_seasons") > 0,
			"use": func() -> void:
				cleric.reaction_available = false
				pc.spend_resource("blessing_of_the_seasons")
				t.reroll(e.dice, "Blessing of the Seasons", false, c.creature.has_flag("luck"))
				_log("reaction", "%s blesses %s with the season (%s): a reroll" % [cleric.name(), c.name(), aspect.capitalize()], cleric, [t.describe()])
				var healed := e.heal_roll("%dd4" % cleric.creature.proficiency_bonus(), c, "Blessing of the Seasons")
				cf()._heal(cleric, c, int(healed["total"]), "Blessing of the Seasons")})


# --- Circle of the Old Ways ----------------------------------------------------------------------------------------

## Whether `c` is in Wood Wose (the data's activation, its effect's source "wood_wose").
static func in_wose(c: Combatant) -> bool:
	return c != null and c.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "wood_wose")


## Whether `option` is a melee attack with a weapon Shillelagh fills while `c` has the spell on it.
static func _shillelagh_hit(c: Combatant, option: Dictionary) -> bool:
	var p := option.get("profile") as WeaponProfile
	if p == null or not bool(option.get("melee", false)):
		return false
	if not (p.item_id in SHILLELAGH_WEAPONS or p.base_item in SHILLELAGH_WEAPONS):
		return false
	return c.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "shillelagh")


## Bough and Branch: Shillelagh grows a wooden Shield in a free hand (+2 AC) and the grip can't be broken. Wood Wose:
## Oakenfist's Extra Attack and Rampant Growth's Temporary Hit Points as it wakes.
func effect_added(cr: Creature, fx: Effect) -> void:
	var c := enc().get_c(cr.id)
	if c == null or c.creature != cr:
		return
	if fx.source_id == "shillelagh" and has(c, "bough_and_branch"):
		var ch := _ch(c)
		if ch != null and ch.equipped("off_hand").is_empty():
			fx.modifiers.append(Modifier.of("ac", {"value": 2}, "Bough and Branch (wooden Shield)", &"feature"))
			# GroundItems.disarm won't make it let go while it can act.
			fx.modifiers.append(Modifier.of("flag", {"value": "keeps_hold"}, "Bough and Branch", &"feature"))
			_log("info", "A shield of gnarled wood grows on %s's arm (+2 AC)" % c.name(), c)
	elif fx.source_id == "wood_wose":
		if has(c, "oak_and_thorn"):
			fx.modifiers.append(Modifier.of("attacks_per_action", {"value": 2}, "Oakenfist", &"feature"))
		if has(c, "deepwood_elder"):
			_rampant_growth(c)


## Rampant Growth: Temporary Hit Points equal to the Wisdom modifier plus the Proficiency Bonus.
func _rampant_growth(c: Combatant) -> void:
	cf()._temp(c, c.creature.ability_mod(&"wis") + c.creature.proficiency_bonus(), "Rampant Growth")


## Wood Wose armed on Shillelagh: the Wild Shape use and the waking go with the cast (no Bonus Action of its own).
func after_cast(c: Combatant, s: Dictionary, _slot: int, _free: bool = false, _ctx: Dictionary = {}) -> void:
	if str(s.get("id", "")) != "shillelagh" or not WOSE_RIDER in c.armed:
		return
	c.armed.erase(WOSE_RIDER)
	var ch := _ch(c)
	if ch == null or in_wose(c) or ch.resource_left("wild_shape") <= 0:
		return
	var had := c.bonus_available
	c.bonus_available = true
	var r := enc().feature_recipes.perform(c, "wood_wose", [])
	c.bonus_available = had if not r.ok else false
	if r.ok:
		_log("info", "%s wakes the Wood Wose with the Shillelagh" % c.name(), c)


## Elderwood Sap: a Shillelagh hit in Wood Wose coats the target until the druid's next turn.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, _st: Dictionary, _r: CombatResult) -> void:
	if not in_wose(c) or not _shillelagh_hit(c, option) or not target.is_alive():
		return
	for old: Effect in target.creature.effects.duplicate():
		if old.source_id == "cs_sap":
			target.creature.remove_effect(old)
	var sap := cf()._timed(c, "Elderwood Sap", "cs_sap", Effect.Ends.START_OF_TURN, c).with_modifier("flag", {"value": "cs_sapped_by:%s" % c.id})
	target.creature.add_effect(sap)
	_log("condition", "Elderwood sap coats %s: Disadvantage on attacks against anyone but %s" % [target.name(), c.name()], target)


## Gnarled Thorns: once on each of the druid's turns in Wood Wose, a melee weapon hit adds 1d6 Piercing.
func hit_dice(c: Combatant, _target: Combatant, option: Dictionary, _st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p := option.get("profile") as WeaponProfile
	if p != null and bool(option.get("melee", false)) and p.item_id != "unarmed_strike" and has(c, "oak_and_thorn") and in_wose(c) \
			and enc().current() == c and _once_per_turn(c, "cs_thorns"):
		out.append({"dice": "1d6", "type": "piercing", "label": "Gnarled Thorns"})
	return out


## The sap's Disadvantage on attacks against anyone but the druid who coated it.
func attack_situation(c: Combatant, target: Combatant, _option: Dictionary, _adv: Array[String], dis: Array[String]) -> void:
	var by := sapped_by(c)
	if by != "" and by != target.id:
		dis.append("Elderwood Sap")


## A sap-coated foe would rather strike the druid (pure: reads flags).
func target_weight(c: Combatant, t: Combatant) -> float:
	var by := sapped_by(c)
	return 0.6 if by != "" and by != t.id else 1.0


## The id of the druid whose Elderwood sap coats `c`, or "".
static func sapped_by(c: Combatant) -> String:
	for m in c.creature.modifiers_for(&"flag"):
		var v := m.text("value")
		if v.begins_with("cs_sapped_by:"):
			return v.substr(13)
	return ""


# --- Turns ---------------------------------------------------------------------------------------------------------

## Rampant Growth each turn in Wood Wose; Scamp's +10 ft for a creature starting its turn in the aura.
func turn_start(c: Combatant) -> CombatResult:
	if in_wose(c) and has(c, "deepwood_elder"):
		_rampant_growth(c)
	var sc := _haint_round(c, "scamp")
	if sc != null:
		for old: Effect in c.creature.effects.duplicate():
			if old.source_id == "cs_scamp":
				c.creature.remove_effect(old)
		var fx := cf()._timed(_bard_of(sc), "Scamp", "cs_scamp", Effect.Ends.END_OF_TURN, c).with_modifier("speed", {"value": 10})
		c.creature.add_effect(fx)
		c.regain_speed()
		_log("info", "The Scamp haint quickens %s: +10 ft Speed" % c.name(), c)
	return CombatResult.new()


## A Grump's extra that never landed is dropped; a haint whose bard can't act fades.
func turn_end(_c: Combatant) -> void:
	_grump_adds.clear()
	_haints()
