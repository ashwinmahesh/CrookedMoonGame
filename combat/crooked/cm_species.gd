class_name CmSpecies
extends CmPart
## The Crooked Moon's code for the book's species (chapter 2): the parts of them data can't say. CrookedFeatures forwards
## every GameFeatures hook here; hotbar actions, queued Reactions and sustained modes here start "sp_".
##
## Graveborn's Infused Drakkonite, Harvestborn's Culling and Gift of the Green, Threadborn's You've Got a Friend,
## Silkborn's Bejeweled Carapace, Curseborn's Cursed Claws and Grey Balance, Ashborn's Fiendish Fortune and Scorpion
## Sting, Azureborn's Flight rule, Glimpse Fate and Winds of Magic, Bogborn's Bog Bulk, Guiding Bond and Regeneration,
## Deepborn's Eldritch Gibbering and Endless Hunger, Gnarlborn's Deep Roots, Grasping Branches and Towering Size,
## Plagueborn's Born in Filth and Plague Bearer, Relicborn's Dance of Death and Moment of Remembrance, Stoneborn's
## Flight rule, Argent Gleam and Silver Bulwark. The rest of each species is data (spells, resistances, senses).

const PREFIX := "sp_"
const BPS: Array[String] = ["bludgeoning", "piercing", "slashing"]
## The two winged species whose flight the game takes away in Medium or Heavy armour (designer's call).
const WINGED: Array[String] = ["azureborn_flight", "stoneborn_flight"]
## Bog Bulk and Towering Size: Advantage on checks to end the Grappled condition.
const BULKY := {"bog_bulk": "Bog Bulk", "towering_size": "Towering Size"}



func prefix() -> String:
	return PREFIX


func cf() -> ClassFeatures:
	return enc().class_features


# --- Helpers --------------------------------------------------------------------------------------------------------

func _effect(c: Combatant, name: String, source: String) -> Effect:
	var fx := Effect.new(name, &"feature", source)
	fx.caster_id = c.id
	return fx


## "Until the start of `owner`'s next turn".
func _until_start(fx: Effect, owner: Combatant) -> Effect:
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = owner.id
	return fx


## "Until the end of `owner`'s next turn".
func _until_end(fx: Effect, owner: Combatant) -> Effect:
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = owner.id
	fx.skip_turn_ends = enc().own_turn_skip(owner)
	return fx


## "Until the end of this turn" (the owner's own turn).
func _this_turn(fx: Effect, owner: Combatant) -> Effect:
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = owner.id
	fx.skip_turn_ends = 0
	return fx


func _condition(t: Combatant, fx: Effect, text: String) -> void:
	if t.creature.add_effect(fx):
		_log("condition", text, t)
		enc().events.append({"type": "condition", "id": t.id})


func _end_effects(c: Combatant, source_id: String) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == source_id:
			c.creature.remove_effect(fx)


func _has_effect(c: Combatant, source_id: String, caster_id: String = "") -> bool:
	return c.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == source_id and (caster_id == "" or fx.caster_id == caster_id))


## A save against one of these traits, with extra keys (a plague is a magical contagion).
func _save(t: Combatant, ab: StringName, dc: int, label: String, keys: Array[String] = []) -> bool:
	var sv := t.creature.roll_save(enc().dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, t.name()], keys)
	_log("info", "%s %s the %s save" % [t.name(), "succeeds on" if sv.success else "fails", label], t, [sv.describe()])
	return sv.success


## The save DC of a species trait that uses the mental ability chosen with the species: 8 + PB + its modifier.
static func mental_dc(c: Combatant) -> int:
	var ch := _ch(c)
	var picks: Array[String] = []
	if ch != null:
		picks = ch.picks_for("species.spellcasting_ability")
	var ab := StringName(picks[0]) if not picks.is_empty() else &"cha"
	return dc_of(c, ab)


## The biggest Hit Point Die `ch` has unspent (0 when none); `spent_too`: any die it has.
static func _hit_die(ch: Character, spent_too: bool = false) -> int:
	var best := 0
	var pool := ch.hit_dice()
	for die: String in pool:
		var entry := pool[die] as Dictionary
		if spent_too or int(entry["spent"]) < int(entry["total"]):
			best = maxi(best, int(die))
	return best


static func _resists(t: Combatant, ty: String) -> bool:
	return t.creature.resistance_source(StringName(ty)) != "" or t.creature.immunity_source(StringName(ty)) != ""


## The creature `c`'s attack roll was made against (its "target:<id>" key), or none.
func _attacked(keys: Array[String]) -> Combatant:
	for k in keys:
		if k.begins_with("target:"):
			return enc().get_c(k.substr(7))
	return null


static func _weapon_part(parts: Array) -> bool:
	return parts.any(func(p: Variant) -> bool: return bool((p as Dictionary).get("weapon", false)))


static func _unarmed(option: Dictionary) -> bool:
	return option.has("profile") and (option["profile"] as WeaponProfile).item_id == "unarmed_strike"


## An armed rider (spent with the hit) or, on Automatic, `auto` (the rule's moment for it): whether to use it now.
func _rider_or_auto(c: Combatant, id: String, auto: bool) -> bool:
	if (PREFIX + id) in c.armed:
		c.armed.erase(PREFIX + id)
		return true
	return auto and allowed(c, id)


# --- The hotbar -----------------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var pb := c.creature.proficiency_bonus()
	if has(c, "gift_of_the_green"):
		out.append(_act("gift_of_the_green", "Gift of the Green", "Hit Point Die + %d · 30 ft" % pb, "bonus",
			_first(bw, _first(_res_why(c, "gift_of_the_green"), "You must touch the ground" if c.altitude > 0 else "")), "ally",
			"Bonus Action: touch the ground; a creature on the ground within 30 ft can spend a Hit Point Die and heal the roll + %d." % pb, 30))
	if has(c, "guiding_bond"):
		out.append(_act("guiding_bond", "Guiding Bond", "+1d4 vs it · 1 min", "bonus", _first(bw, _res_why(c, "guiding_bond")), "enemy",
			"Bonus Action: mark a creature you see within 60 ft for 1 minute; your attack rolls against it add 1d4.", 60))
	if has(c, "bogborn_regeneration"):
		var rw := ""
		if c.creature.has_flag("sp_regeneration_off"):
			rw = "Acid or Fire stopped it"
		elif _hit_die(ch) == 0:
			rw = "No Hit Point Dice left"
		out.append(_act("bogborn_regeneration", "Regeneration", "spend a Hit Point Die", "bonus", _first(bw, rw), "none",
			"Bonus Action: spend a Hit Point Die and regain the roll + your Constitution modifier (at least 1). Acid or Fire damage stops it until the end of your next turn."))
	if has(c, "eldritch_gibbering"):
		out.append(_act("eldritch_gibbering", "Eldritch Gibbering", "30 ft · Wis DC %d" % mental_dc(c), "action",
			_first(aw, _res_why(c, "eldritch_gibbering")), "none",
			"Magic action: foes within 30 ft make a Wisdom save or roll a d6 until your next turn: Disadvantage on attacks (1-2), Speed 0 (3-4) or no Reactions (5-6). Spent only once someone fails."))
	if has(c, "endless_hunger"):
		out.append(_act("endless_hunger", "Endless Hunger", "until your next turn", "bonus", _first(bw, _res_why(c, "endless_hunger")), "none",
			"Bonus Action: until your next turn you sense the living within 60 ft, and your attack rolls against any of them that isn't a Construct or Undead can't have Disadvantage."))
	if has(c, "grasping_branches"):
		out.append(_act("grasping_branches", "Grasping Branches", "Str DC %d · 30 ft" % dc_of(c, &"con"), "bonus",
			_first(bw, _res_why(c, "grasping_branches")), "enemy",
			"Bonus Action: a Large or smaller creature within 30 ft makes a Strength save or is Restrained for 1 minute (save again at each of its turn ends); on a success its Speed is halved until the end of its next turn.", 30))
	if has(c, "dance_of_death"):
		out.append(_act("dance_of_death", "Dance of Death", "Cha DC 15", "bonus", bw, "none",
			"Bonus Action: a DC 15 Charisma (Performance) check. Success: Advantage on your next attack roll this turn; by 5 or more, also a Hit Point Die's roll in Temporary Hit Points."))
	if has(c, "winds_of_magic"):
		out.append(_act("winds_of_magic", "Winds of Magic", "Dash · +10 ft fly", "bonus", _first(bw, _res_why(c, "winds_of_magic")), "none",
			"Bonus Action: Dash, and your Fly Speed is 10 ft higher until the end of the turn."))
	if has(c, "argent_gleam"):
		var gw := _first(bw, _res_why(c, "argent_gleam"))
		var grace := _act("argent_gleam_grace", "Argent Gleam: Path's Grace", "Bless · up to 3", "bonus", gw, "multi",
			"Bonus Action: cast Bless on up to three creatures within 30 ft, no Material component. Shares its once-a-Long-Rest use with Zealous Charge.", 30)
		grace["count"] = 3
		out.append(grace)
		out.append(_act("argent_gleam_charge", "Argent Gleam: Zealous Charge", "Dash · +2d6 Radiant", "bonus", gw, "none",
			"Bonus Action: Dash; the first attack roll you make this turn deals 2d6 Radiant to its target, hit or miss. Shares its once-a-Long-Rest use with Path's Grace."))


func perform(c: Combatant, id: String, t: Combatant, _cell: Vector2i, _point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if ch == null:
		return CombatResult.fail("Not available")
	match id.trim_prefix(PREFIX):
		"gift_of_the_green":
			return _gift_of_the_green(c, t)
		"guiding_bond":
			if t == null or t == c or not e.can_see(c, t) or e.distance(c, t) > 60:
				return CombatResult.fail("Choose a creature you can see within 60 ft")
			ch.spend_resource("guiding_bond")
			c.bonus_available = false
			var fx := _effect(c, "Guiding Bond", "guiding_bond").with_modifier("flag", {"value": "sp_bond:%s" % t.id})
			fx.lasting({"kind": "minutes", "amount": 1})
			fx.turn_owner_id = c.id
			c.creature.add_effect(fx)
			_log("info", "%s marks %s with a Guiding Bond (+1d4 to attack rolls against it)" % [c.name(), t.name()], c)
		"bogborn_regeneration":
			var die := _hit_die(ch)
			if die == 0:
				return CombatResult.fail("No Hit Point Dice left")
			c.bonus_available = false
			var got := ch.spend_hit_die(e.dice, die)
			if got > 0 and c.creature.hp > 0:
				c.creature.remove_condition(&"unconscious", "0 Hit Points")
			_log("heal", "Regeneration: %s regains %d Hit Points (a d%d Hit Point Die)" % [c.name(), got, die], c)
			e.events.append({"type": "heal", "id": c.id, "amount": got})
		"eldritch_gibbering":
			e.spend_action(c)
			_gibber(c)
		"endless_hunger":
			ch.spend_resource("endless_hunger")
			c.bonus_available = false
			var fx2 := _until_start(_effect(c, "Endless Hunger", "endless_hunger"), c).with_modifier("flag", {"value": "sp_endless_hunger"})
			c.creature.add_effect(fx2)
			_log("info", "%s opens to the Hungering Ones: the living within 60 ft can't hide from its attacks" % c.name(), c)
		"grasping_branches":
			return _grasping_branches(c, t)
		"dance_of_death":
			c.bonus_available = false
			_dance(c)
		"winds_of_magic":
			if c.creature.has_flag("cannot_dash"):
				return CombatResult.fail("Cannot Dash while affected")
			ch.spend_resource("winds_of_magic")
			c.bonus_available = false
			var flies := c.creature.speed("fly").total() > 0
			c.creature.add_effect(_this_turn(_effect(c, "Winds of Magic", "winds_of_magic"), c).with_modifier("speed", {"kind": "fly", "value": 10}))
			var extra := c.speed() + (10 if flies else 0)
			c.movement_left += extra
			_log("info", "%s rides the Winds of Magic: Dash (+%d ft)" % [c.name(), extra], c)
		"argent_gleam_grace":
			var picks: Array = []
			for x: Variant in targets_in:
				if x is Combatant and not picks.has(x) and picks.size() < 3:
					picks.append(x)
			if picks.is_empty():
				picks.append(t if t != null else c)
			var res := e.spells.cast_free(c, "bless", picks, Vector2.INF)
			if not res.ok:
				return res
			ch.spend_resource("argent_gleam")
			c.bonus_available = false
			_log("info", "%s calls on the Silver Path: Path's Grace" % c.name(), c)
			return res
		"argent_gleam_charge":
			if c.creature.has_flag("cannot_dash"):
				return CombatResult.fail("Cannot Dash while affected")
			ch.spend_resource("argent_gleam")
			c.bonus_available = false
			c.movement_left += c.speed()
			c.set_meta("sp_zealous", _turn_key())
			_log("info", "%s charges in the Silver Path's light: Dash (+%d ft), and the first attack roll this turn burns" % [c.name(), c.speed()], c)
		_:
			return CombatResult.fail("Not available")
	return CombatResult.new()


## Gift of the Green (Harvestborn): a creature on the ground within 30 ft spends a Hit Point Die and heals the roll + PB.
func _gift_of_the_green(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or e.distance(c, t) > 30:
		return CombatResult.fail("Choose a creature within 30 ft")
	if t.altitude > 0 or c.altitude > 0:
		return CombatResult.fail("Both of you must touch the ground")
	var tch := _ch(t)
	var die := _hit_die(tch) if tch != null else 0
	if die == 0:
		return CombatResult.fail("%s has no Hit Point Dice to spend" % t.name())
	_ch(c).spend_resource("gift_of_the_green")
	c.bonus_available = false
	tch.hit_dice_spent[str(die)] = int(tch.hit_dice_spent.get(str(die), 0)) + 1
	var roll := e.dice.roll_one(die, "Gift of the Green")
	cf()._heal(c, t, roll + c.creature.proficiency_bonus(), "Gift of the Green")
	return CombatResult.new()


## Eldritch Gibbering (Deepborn): each foe within 30 ft (or the ones picked) saves or rolls a d6 for an effect until
## the start of the deepborn's next turn. The use is spent only once someone fails.
func _gibber(c: Combatant) -> void:
	var e := enc()
	var dc := mental_dc(c)
	var picked: Array[Combatant] = []
	for x: Variant in targets_in:
		if x is Combatant and x != c:
			picked.append(x as Combatant)
	if picked.is_empty():
		for h in e.hostiles_of(c):
			if not h.is_down() and e.distance(c, h) <= 30:
				picked.append(h)
	_log("info", "%s gibbers in Deep Speech" % c.name(), c)
	var failed := false
	for t in picked:
		if e.distance(c, t) > 30 or _save(t, &"wis", dc, "Eldritch Gibbering"):
			continue
		failed = true
		var roll := e.dice.roll_one(6, "Eldritch Gibbering")
		var fx := _until_start(_effect(c, "Eldritch Gibbering", "eldritch_gibbering"), c)
		var what := ""
		if roll <= 2:
			fx.with_modifier("disadvantage", {"on": "attack"})
			what = "Disadvantage on attack rolls"
		elif roll <= 4:
			fx.with_modifier("speed_set", {"value": 0})
			what = "Speed 0"
		else:
			fx.with_modifier("flag", {"value": "no_reactions"})
			what = "no Reactions"
		_condition(t, fx, "%s reels from the gibbering (d6 %d): %s until %s's next turn" % [t.name(), roll, what, c.name()])
	if failed:
		_ch(c).spend_resource("eldritch_gibbering")
	else:
		_log("info", "No one failed: Eldritch Gibbering isn't spent", c)


## Grasping Branches (Gnarlborn): Strength save or Restrained for 1 minute (saves again at each turn end); on a
## success, Speed halved until the end of the creature's next turn.
func _grasping_branches(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or t == c or e.distance(c, t) > 30:
		return CombatResult.fail("Choose a creature within 30 ft")
	if Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(&"large"):
		return CombatResult.fail("%s is too big for the branches" % t.name())
	_ch(c).spend_resource("grasping_branches")
	c.bonus_available = false
	var dc := dc_of(c, &"con")
	var keys: Array[String] = ["save_vs:restrained"]
	if not _save(t, &"str", dc, "Grasping Branches", keys):
		var fx := _effect(c, "Grasping Branches", "grasping_branches").with_condition(&"restrained")
		fx.lasting({"kind": "minutes", "amount": 1})
		fx.turn_owner_id = c.id
		fx.repeat_save = {"ability": "str", "dc": dc, "when": "end"}
		_condition(t, fx, "Branches burst from the ground and bind %s (Restrained)" % t.name())
	else:
		var slow := _until_end(_effect(c, "Grasping Branches", "grasping_branches"), t).with_modifier("speed_percent", {"value": 50})
		_condition(t, slow, "%s tears free of the branches, slowed until the end of its next turn" % t.name())
	return CombatResult.new()


## Dance of Death (Relicborn): a DC 15 Charisma (Performance, or a Musical Instrument it's proficient with) check.
## Success: Advantage on the next attack roll this turn; success by 5: a Hit Point Die's roll as Temporary Hit Points.
func _dance(c: Combatant) -> void:
	var e := enc()
	var ch := _ch(c)
	var skill := &"performance"
	var instrument := ch.skill_rank(&"performance") == 0 and ch.proficiency_list("tools").any(func(id: String) -> bool:
		return str((Compendium.shared().item_data(id).get("tool", {}) as Dictionary).get("kind", "")) == "musical_instrument")
	if instrument:
		skill = &"cha"
	var test := c.creature.roll_check(e.dice, skill, 15, [], [], "Dance of Death (%s)" % c.name())
	if instrument:
		test.add_bonus(c.creature.proficiency_bonus(), "Musical Instrument")
	_log("info", "%s dances with death: %s" % [c.name(), "a success" if test.success else "a stumble"], c, [test.describe()])
	if not test.success:
		return
	var fx := _this_turn(_effect(c, "Dance of Death", "dance_of_death"), c).with_modifier("advantage", {"on": "attack"})
	fx.consume_on = ["attack"]
	c.creature.add_effect(fx)
	if test.total >= 20:
		var die := _hit_die(ch, true)
		if die > 0:
			cf()._temp(c, e.dice.roll_one(die, "Dance of Death"), "Dance of Death")


# --- Riders on a hit -------------------------------------------------------------------------------------------------

func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := _ch(c)
	if ch == null:
		return out
	var rows := [["infused_drakkonite", "Infused Drakkonite", "ignore Resistance, +%d Necrotic" % c.creature.proficiency_bonus()],
		["culling", "Culling", "+1d12 Necrotic vs a Bloodied foe"],
		["cursed_claws", "Cursed Claws", "claws: Disadvantage on its D20 Tests"],
		["scorpion_sting", "Scorpion Sting", "sting: +%s Poison" % _sting_dice(c)],
		["plague_bearer", "Plague Bearer", "Con DC %d or your plague" % dc_of(c, &"con")]]
	for row: Array in rows:
		var id := str(row[0])
		if has(c, id):
			out.append({"id": PREFIX + id, "label": str(row[1]), "sub": str(row[2]), "why": _res_why(c, id)})
	return out


static func _sting_dice(c: Combatant) -> String:
	var ch := _ch(c)
	return "2d6" if ch != null and ch.character_level() >= 10 else "1d6"


## Dice on a weapon or Unarmed Strike hit: Culling on a Bloodied foe, Scorpion Sting on a sting, Zealous Charge's
## Radiant on the turn's first attack roll that hit.
func hit_dice(c: Combatant, target: Combatant, option: Dictionary, _st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := _ch(c)
	if ch == null or target == null:
		return out
	if has(c, "culling") and ch.resource_left("culling") > 0 and target.creature.is_bloodied() and c.hostile_to(target) \
			and _rider_or_auto(c, "culling", _once_per_turn(c, "sp_culling_auto")):
		ch.spend_resource("culling")
		out.append({"dice": "1d12", "type": "necrotic", "label": "Culling"})
	if has(c, "scorpion_sting") and _unarmed(option) and ch.resource_left("scorpion_sting") > 0 \
			and _rider_or_auto(c, "scorpion_sting", not _resists(target, "poison")):
		ch.spend_resource("scorpion_sting")
		out.append({"dice": _sting_dice(c), "type": "poison", "label": "Scorpion Sting"})
	if str(c.get_meta("sp_zealous_hit", "")) == "%s>%s" % [_turn_key(), target.id]:
		c.remove_meta("sp_zealous_hit")
		out.append({"dice": "2d6", "type": "radiant", "label": "Zealous Charge"})
	return out


## After a weapon or Unarmed Strike hit: Cursed Claws' curse, Plague Bearer's contagion.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, _st: Dictionary, _r: CombatResult) -> void:
	var ch := _ch(c)
	if ch == null or target == null or not target.is_alive() or target.is_down():
		return
	if has(c, "cursed_claws") and _unarmed(option) and ch.resource_left("cursed_claws") > 0 \
			and _rider_or_auto(c, "cursed_claws", not _has_effect(target, "cursed_claws", c.id)):
		ch.spend_resource("cursed_claws")
		var fx := _until_start(_effect(c, "Cursed Claws", "cursed_claws"), c) \
			.with_modifier("disadvantage", {"on": ["attack", "save:all", "check:all"]})
		_condition(target, fx, "Grey fog trails from %s: Disadvantage on its D20 Tests until %s's next turn (Cursed Claws)" % [target.name(), c.name()])
	if has(c, "plague_bearer") and ch.resource_left("plague_bearer") > 0 \
			and _rider_or_auto(c, "plague_bearer", c.hostile_to(target) and not _resists(target, "poison") and not target.creature.is_bloodied() \
				and not _has_effect(target, "plague_bearer")):
		ch.spend_resource("plague_bearer")
		var dc := dc_of(c, &"con")
		var keys: Array[String] = ["save_vs:contagion", "save_vs:magic"]
		if _save(target, &"con", dc, "Plague Bearer", keys):
			return
		var fx2 := _effect(c, "Plague (%s)" % c.name(), "plague_bearer") \
			.with_modifier("disadvantage", {"on": ["attack", "check:all"]})
		fx2.lasting({"kind": "minutes", "amount": 1})
		fx2.turn_owner_id = c.id
		fx2.data["dc"] = dc
		_condition(target, fx2, "%s carries %s's plague: Disadvantage on attack rolls and ability checks, 1d4 Poison each turn" % [target.name(), c.name()])


# --- Attacks against the species -------------------------------------------------------------------------------------

## Bejeweled Carapace (Silkborn): +PB AC against a hit, when that makes it miss. Fiendish Fortune (Ashborn): a hit
## that isn't a Critical Hit misses, and a creature within 5 ft takes PB Force damage.
func after_hit_target(st: Dictionary, miss: Callable, out: Array) -> void:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	var ch := _ch(target)
	if ch == null or bool(st["critical"]) or not e.spells.can_react(target):
		return
	var pb := target.creature.proficiency_bonus()
	if has(target, "bejeweled_carapace") and ch.resource_left("bejeweled_carapace") > 0 and t.total < ac + pb:
		out.append({"kind": "bejeweled_carapace", "reactor": target, "trigger": c.id, "default": "auto",
			"title": "Reaction: Bejeweled Carapace?",
			"text": "%s hits %s: %d vs AC %d. The carapace turns it: +%d AC against this attack, so it misses." % [c.name(), target.name(), t.total, ac, pb],
			"cost": "Reaction and Bejeweled Carapace (once per Short Rest)",
			"still": func() -> bool: return e.spells.can_react(target) and ch.resource_left("bejeweled_carapace") > 0,
			"use": func() -> void:
				target.reaction_available = false
				ch.spend_resource("bejeweled_carapace")
				_log("reaction", "%s's jewelled carapace turns the blow (+%d AC)" % [target.name(), pb], target),
			"stop": func() -> CombatResult:
				st["ac"] = ac + pb
				return miss.call() as CombatResult})
	if has(target, "fiendish_fortune") and ch.resource_left("fiendish_fortune") > 0:
		out.append({"kind": "fiendish_fortune", "reactor": target, "trigger": c.id, "default": "auto",
			"title": "Reaction: Fiendish Fortune?",
			"text": "%s hits %s: %d vs AC %d. Make it miss, and burn a creature within 5 ft for %d Force?" % [c.name(), target.name(), t.total, ac, pb],
			"cost": "Reaction and Fiendish Fortune (once per Short Rest)",
			"still": func() -> bool: return e.spells.can_react(target) and ch.resource_left("fiendish_fortune") > 0,
			"use": func() -> void:
				target.reaction_available = false
				ch.spend_resource("fiendish_fortune")
				_log("reaction", "Hellish luck: the attack misses %s (Fiendish Fortune)" % target.name(), target),
			"stop": func() -> CombatResult:
				var res := miss.call() as CombatResult
				_fortune_burn(target, c)
				return res})


## Fiendish Fortune's Force damage: the attacker when it's within 5 ft, else the nearest foe within 5 ft.
func _fortune_burn(ashborn: Combatant, attacker: Combatant) -> void:
	var e := enc()
	var victim: Combatant = null
	if attacker != null and attacker.is_alive() and ashborn.hostile_to(attacker) and e.distance(ashborn, attacker) <= 5:
		victim = attacker
	else:
		var best := 999
		for h in e.hostiles_of(ashborn):
			var d := e.distance(ashborn, h)
			if not h.is_down() and d <= 5 and d < best:
				best = d
				victim = h
	if victim == null:
		return
	e.deal_damage(ashborn, victim, [{"amount": ashborn.creature.proficiency_bonus(), "type": "force"}], false, "Fiendish Fortune")


## Silver Bulwark (Stoneborn): against an attack's Bludgeoning, Piercing or Slashing damage, Resistance to all three
## until the start of its next turn, this blow included.
func against_damage(st: Dictionary, total: Callable, _cut: Callable, out: Array) -> void:
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	if not option.has("profile") or not str((option["profile"] as WeaponProfile).damage_type) in BPS or not _bulwark_ready(target):
		return
	out.append({"kind": "silver_bulwark", "reactor": target, "trigger": c.id, "default": "auto",
		"title": "Reaction: Silver Bulwark?",
		"text": "%s hits %s for %d damage. Harden against Bludgeoning, Piercing and Slashing until your next turn?" % [c.name(), target.name(), total.call()],
		"cost": "Reaction and Silver Bulwark (once per Short Rest)",
		"still": func() -> bool: return _bulwark_ready(target) and int(total.call()) > 0,
		"use": func() -> void: _bulwark(target)})


func _bulwark_ready(t: Combatant) -> bool:
	var ch := _ch(t)
	return ch != null and has(t, "silver_bulwark") and ch.resource_left("silver_bulwark") > 0 and enc().spells.can_react(t)


func _bulwark(t: Combatant) -> void:
	t.reaction_available = false
	_ch(t).spend_resource("silver_bulwark")
	var fx := _until_start(_effect(t, "Silver Bulwark", "silver_bulwark"), t)
	for ty in BPS:
		fx.with_modifier("resistance", {"value": ty})
	t.creature.add_effect(fx)
	_log("reaction", "%s hardens to silver-blessed stone (Resistance to Bludgeoning, Piercing and Slashing)" % t.name(), t)


# --- Damage ----------------------------------------------------------------------------------------------------------

## Damage about to land: Infused Drakkonite (ignore Resistance, + PB Necrotic), Culling on a spell or other damage
## (weapon hits add it in hit_dice), Silver Bulwark against Bludgeoning, Piercing or Slashing that isn't an attack's.
func adjust_incoming(source: Combatant, target: Combatant, parts: Array) -> void:
	if target == null or parts.is_empty():
		return
	var weapon := _weapon_part(parts)
	var dealt := parts.any(func(p: Variant) -> bool: return int((p as Dictionary)["amount"]) > 0)
	var sch := _ch(source)
	if sch != null and source != target and dealt and source.hostile_to(target):
		if has(source, "infused_drakkonite") and sch.resource_left("infused_drakkonite") > 0:
			var resisted := parts.any(func(p: Variant) -> bool:
				return target.creature.resistance_source(StringName(str((p as Dictionary)["type"]))) != "")
			if (weapon and (PREFIX + "infused_drakkonite") in source.armed) or (resisted and allowed(source, "infused_drakkonite")):
				source.armed.erase(PREFIX + "infused_drakkonite")
				sch.spend_resource("infused_drakkonite")
				var pb := source.creature.proficiency_bonus()
				var extra := {"amount": pb, "type": "necrotic"}
				for k: String in ["weapon", "spell", "melee"]:
					if (parts[0] as Dictionary).has(k):
						extra[k] = (parts[0] as Dictionary)[k]
				parts.append(extra)
				for p: Variant in parts:
					(p as Dictionary)["ignore_resistance"] = true
					(p as Dictionary)["ignore_source"] = "Infused Drakkonite"
				_log("info", "Infused Drakkonite: %s's blow ignores Resistance and adds %d Necrotic" % [source.name(), pb], source)
		if not weapon and has(source, "culling") and sch.resource_left("culling") > 0 and target.creature.is_bloodied() \
				and allowed(source, "culling") and _once_per_turn(source, "sp_culling_auto"):
			sch.spend_resource("culling")
			var rolled := enc()._roll_damage_dice("1d12", false, 0, "Culling")
			parts.append({"amount": int(rolled["total"]), "type": "necrotic", "spell": bool((parts[0] as Dictionary).get("spell", false))})
			_log("info", "Culling: +%d Necrotic on the Bloodied %s" % [int(rolled["total"]), target.name()], source)
	if not weapon and dealt and _bulwark_ready(target) and allowed(target, "silver_bulwark") \
			and parts.any(func(p: Variant) -> bool: return str((p as Dictionary)["type"]) in BPS and int((p as Dictionary)["amount"]) > 0):
		_bulwark(target)


## After damage: Acid or Fire stops a Bogborn's Regeneration until the end of its next turn.
func after_damage(_source: Combatant, target: Combatant, amount: int, ps: Array = [], _dr: DamageResult = null) -> void:
	if target == null or amount <= 0 or not has(target, "bogborn_regeneration"):
		return
	if not ps.any(func(p: Variant) -> bool: return str((p as Dictionary).get("type", "")) in ["acid", "fire"] and int((p as Dictionary).get("amount", 0)) > 0):
		return
	_end_effects(target, "sp_regeneration_off")
	var fx := _until_end(_effect(target, "Regeneration stopped", "sp_regeneration_off"), target).with_modifier("flag", {"value": "sp_regeneration_off"})
	target.creature.add_effect(fx)
	_log("info", "Acid or Fire: %s's Regeneration stops until the end of its next turn" % target.name(), target)


# --- Turns, Initiative and D20 Tests ---------------------------------------------------------------------------------

## The fight begins: the winged species can't fly in Medium or Heavy armour.
func fight_started() -> void:
	for c in enc().combatants:
		flight_rule(c)


## Azureborn and Stoneborn Flight (designer's call): no flying in Medium or Heavy armour, read where the fly Speed is
## (a cap of 0 on it while such armour is worn).
func flight_rule(c: Combatant) -> void:
	if not WINGED.any(func(id: String) -> bool: return has(c, id)):
		return
	var heavy := str(c.creature.armor_situation().get("armor", "")) in ["medium", "heavy"]
	var capped := _has_effect(c, "sp_armoured_wings")
	if heavy and not capped:
		var fx := _effect(c, "Too heavily armoured to fly", "sp_armoured_wings").with_modifier("speed_cap", {"kind": "fly", "value": 0})
		c.creature.add_effect(fx)
		_log("info", "%s can't fly in Medium or Heavy armour" % c.name(), c)
	elif not heavy and capped:
		_end_effects(c, "sp_armoured_wings")


## Glimpse Fate (Azureborn): when Initiative is rolled, up to PB creatures the seer sees (itself and its allies, the
## nearest first) roll with Advantage. Once per Short Rest. Settled once every roll is made, when the engine has marked
## who is surprised (a surprised seer can't use it): each pick's roll gains its second d20 (or loses a surprised
## creature's Disadvantage, the two cancelling), before the order is sorted.
func initiative_rolled() -> void:
	var e := enc()
	var done := {}
	for s in e.combatants:
		var ch := _ch(s)
		if ch == null or s.surprised or not s.is_alive() or not has(s, "glimpse_fate") or ch.resource_left("glimpse_fate") <= 0 \
				or not allowed(s, "glimpse_fate"):
			continue
		var pool: Array[Combatant] = [s]
		var others := e.allies_of(s).filter(func(a: Combatant) -> bool: return e.can_see(s, a))
		others.sort_custom(func(a: Combatant, b: Combatant) -> bool: return e.distance(s, a) < e.distance(s, b))
		pool.append_array(others)
		var names: Array[String] = []
		for a: Combatant in pool.slice(0, s.creature.proficiency_bonus()):
			if not done.has(a.id) and a.initiative_test != null:
				done[a.id] = true
				_glimpse_roll(a, "Glimpse Fate (%s)" % s.name())
				names.append(a.name())
		if names.is_empty():
			continue
		ch.spend_resource("glimpse_fate")
		_log("info", "%s glimpses fate: %s roll Initiative with Advantage" % [s.name(), ", ".join(names)], s)


## Advantage given to Initiative `a` has already rolled.
func _glimpse_roll(a: Combatant, source: String) -> void:
	var t := a.initiative_test
	if t.advantage:
		return
	t.advantage_sources.append(source)
	if t.disadvantage:
		t.disadvantage = false
		t.set_natural(t.rolls[0], source)
	else:
		var second := enc().dice.d20(source)
		var first := t.kept
		t.rolls.assign([first, second])
		t.advantage = true
		t.set_natural(maxi(first, second), source)
	a.initiative = t.total
	_log("roll", "%s's Initiative with Advantage: %d" % [a.name(), t.total], a, [t.describe()])


## Start of a creature's turn: a Plagueborn's plague burns 1d4 Poison.
func turn_start(c: Combatant) -> CombatResult:
	var e := enc()
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id != "plague_bearer" or not c.is_alive():
			continue
		var rolled := e._roll_damage_dice("1d4", false, 0, "Plague")
		e.deal_damage(e.get_c(fx.caster_id), c, [{"amount": int(rolled["total"]), "type": "poison"}], false, "Plague", [str(rolled["text"])])
	return CombatResult.new()


## End of a creature's turn: a Zealous Charge left by a turned hit burns; a plagued creature saves again to end the
## plague (a magical contagion).
func turn_end(c: Combatant) -> void:
	_zealous_left(c)
	var keys: Array[String] = ["save_vs:contagion", "save_vs:magic"]
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id != "plague_bearer" or not c.is_alive():
			continue
		if _save(c, &"con", int(fx.data.get("dc", 10)), "the plague", keys):
			c.creature.remove_effect(fx)
			_log("info", "%s throws off the plague" % c.name(), c)
			enc().events.append({"type": "condition", "id": c.id})


## Before a D20 Test: Born in Filth against a plague, Bog Bulk and Towering Size breaking a grapple, Deep Roots against
## being moved.
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	var adv: Array[String] = []
	if kind == D20Test.Kind.SAVING_THROW and "save_vs:contagion" in keys and has(c, "born_in_filth"):
		adv.append("Born in Filth")
	if ("save_vs:moved" in keys or "check_vs:moved" in keys) and has(c, "deep_roots"):
		adv.append("Deep Roots")
	if kind == D20Test.Kind.ABILITY_CHECK and "escape:grappled" in keys:
		for id: String in BULKY:
			if has(c, id):
				adv.append(str(BULKY[id]))
				break
	return {"advantage": adv} if not adv.is_empty() else {}


## After a D20 Test: Grey Balance on a failed save, Moment of Remembrance and You've Got a Friend for a failing ally,
## and on an attack roll Endless Hunger (no Disadvantage), Guiding Bond (+1d4) and Zealous Charge (2d6 Radiant).
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	if c == null:
		return
	if t.kind == D20Test.Kind.ATTACK_ROLL:
		_attack_offers(c, t, keys, out)
	if t.target <= 0 or t.auto_failed:
		return
	var e := enc()
	var ch := _ch(c)
	if ch != null and t.kind == D20Test.Kind.SAVING_THROW and has(c, "grey_balance"):
		out.append({"kind": "grey_balance", "reactor": c, "default": "ask", "sync": "decision", "spends_reaction": true,
			"title": "Reaction: Grey Balance?",
			"text": func() -> String: return "%s. Grey Balance: succeed instead, then Disadvantage on D20 Tests until the end of your next turn?" % D20Responses.line(c, t),
			"cost": "Reaction and Grey Balance (once per Long Rest)",
			"still": func() -> bool: return not t.success and ch.resource_left("grey_balance") > 0 and e.spells.can_react(c),
			"use": func() -> void:
				c.reaction_available = false
				ch.spend_resource("grey_balance")
				t.auto_failed = false
				t.success = true
				t.reroll_note = ("%s; " % t.reroll_note if t.reroll_note != "" else "") + "Grey Balance: succeeds instead"
				var fx := _until_end(_effect(c, "Grey Balance", "grey_balance"), c) \
					.with_modifier("disadvantage", {"on": ["attack", "save:all", "check:all"]})
				c.creature.add_effect(fx)
				_log("reaction", "%s tips the Grey Balance: the save succeeds, and the Grey takes its due (Disadvantage on D20 Tests until the end of its next turn)" % c.name(), c)})
	var skill := t.kind == D20Test.Kind.ABILITY_CHECK and keys.any(func(k: String) -> bool:
		return k.begins_with("check:") and Abilities.SKILLS.has(StringName(k.substr(6))))
	for r in e.living():
		if _ch(r) == null or not (r == c or r.allied_with(c)):
			continue
		if r != c and has(r, "moment_of_remembrance"):
			_helper_offer(r, c, t, "moment_of_remembrance", "Moment of Remembrance", true, out)
		if skill and has(r, "youve_got_a_friend"):
			_helper_offer(r, c, t, "youve_got_a_friend", "You've Got a Friend", false, out)


## A Reaction adding 1d4 to a failing ally's roll within 30 ft (Moment of Remembrance: its use spent only when the roll
## then succeeds; You've Got a Friend: Guidance cast on the roller, its use spent either way).
func _helper_offer(r: Combatant, roller: Combatant, t: D20Test, id: String, name: String, only_on_success: bool, out: Array) -> void:
	var e := enc()
	var rch := _ch(r)
	var still := func() -> bool:
		return not t.success and rch.resource_left(id) > 0 and e.spells.can_react(r) and t.total + 4 >= t.target \
			and (r == roller or (e.distance(r, roller) <= 30 and e.can_see(r, roller)))
	out.append({"kind": id, "reactor": r, "trigger": roller.id, "default": "auto", "spends_reaction": true,
		"title": "Reaction: %s?" % name,
		"text": func() -> String: return "%s. %s: add 1d4 to the roll?" % [D20Responses.line(roller, t), name],
		"cost": "Reaction%s" % (" (a use only if it then succeeds)" if only_on_success else " and a use of %s" % name),
		"still": still,
		"helps": func() -> bool: return t.total + 4 >= t.target,
		"use": func() -> void:
			r.reaction_available = false
			var v := e.dice.roll_one(4, name)
			t.add_bonus(v, name)
			if not only_on_success or t.success:
				rch.spend_resource(id)
			var tail := "" if t.success else (", still short: no use spent" if only_on_success else ", still short")
			_log("reaction", "%s: %s adds %d to %s's roll%s" % [name, r.name(), v, roller.name(), tail], r, [t.describe()])})


## On `c`'s own attack roll: Endless Hunger takes Disadvantage away, Guiding Bond adds 1d4, Zealous Charge burns.
func _attack_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	var hit := _attacked(keys)
	if hit == null or hit == c:
		return
	if c.creature.has_flag("sp_endless_hunger") and t.disadvantage and not hit.creature.creature_type in [&"construct", &"undead"] \
			and e.distance(c, hit) <= 60:
		out.append({"kind": "endless_hunger", "reactor": c, "forced": true,
			"use": func() -> void:
				t.disadvantage = false
				t.advantage = not t.advantage_sources.is_empty()
				var keep := t.rolls[0] if t.rolls.size() < 2 or not t.advantage else maxi(t.rolls[0], t.rolls[1])
				t.disadvantage_sources.clear()
				t.set_natural(keep, "Endless Hunger")
				_log("info", "Endless Hunger: %s's attack can't have Disadvantage" % c.name(), c, [t.describe()])})
	if c.creature.has_flag("sp_bond:%s" % hit.id):
		out.append({"kind": "guiding_bond", "reactor": c, "forced": true,
			"use": func() -> void:
				var v := e.dice.roll_one(4, "Guiding Bond")
				t.add_bonus(v, "Guiding Bond")
				_log("info", "Guiding Bond: +%d to %s's attack roll" % [v, c.name()], c, [t.describe()])})
	if str(c.get_meta("sp_zealous", "")) == _turn_key():
		var spell := "attack:spell" in keys
		out.append({"kind": "argent_gleam", "reactor": c, "forced": true,
			"use": func() -> void:
				c.remove_meta("sp_zealous")
				if t.success and not spell:
					# Rides the hit's damage (hit_dice); a Reaction that turns the hit into a miss leaves it to
					# _zealous_left, as the action ends.
					c.set_meta("sp_zealous_hit", "%s>%s" % [_turn_key(), hit.id])
					return
				_zealous_burn(c, hit)})


## Zealous Charge's 2d6 Radiant, dealt on its own (a miss, or a spell attack).
func _zealous_burn(c: Combatant, t: Combatant) -> void:
	var e := enc()
	if t == null or not t.is_alive():
		return
	var rolled := e._roll_damage_dice("2d6", false, 0, "Zealous Charge")
	e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "radiant"}], false, "Zealous Charge", [str(rolled["text"])])


## A Zealous Charge hit whose damage never came (a Reaction turned it into a miss): the Radiant lands anyway, hit or
## miss, once the action (or at the latest the turn) is over.
func _zealous_left(c: Combatant) -> void:
	var mark := str(c.get_meta("sp_zealous_hit", ""))
	if mark == "":
		return
	c.remove_meta("sp_zealous_hit")
	_zealous_burn(c, enc().get_c(mark.get_slice(">", 1)))


func after_action(c: Combatant, _action: Dictionary, _targets: Array = []) -> void:
	if c != null:
		_zealous_left(c)
