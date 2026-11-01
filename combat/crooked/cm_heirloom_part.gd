class_name CmHeirloomPart
extends CmPart
## What the Fabled Heirlooms' parts share (combat/crooked/cm_heirlooms_*.gd): whether an heirloom is working for a creature,
## its tier by its bearer's level (1, 2 from level 7, 3 from level 13: Rare, Very Rare, Legendary), the save DC its own
## properties set (16 + the tier), and its once-a-dusk properties that have no button: each is a `hidden` power in the item's
## data, so the engine counts its uses and gives them back at dusk (or at a Long Rest) as it does a power's.


## The heirloom `item_id` working for `c` (attuned, and worn or held where it must be): {id, data, entry}, or {}.
func held(c: Combatant, item_id: String) -> Dictionary:
	if c == null or _ch(c) == null or not c.is_alive():
		return {}
	return enc().items.active_item(c, item_id)


func holds(c: Combatant, item_id: String) -> bool:
	return not held(c, item_id).is_empty()


## `c` holds the heirloom and has reached tier `t` (2: Very Rare, from level 7; 3: Legendary, from level 13).
func holds_at(c: Combatant, item_id: String, t: int) -> bool:
	return holds(c, item_id) and tier(c) >= t


## The heirloom's tier for its bearer: 1 below level 7, 2 from 7, 3 from 13.
static func tier(c: Combatant) -> int:
	var ch := _ch(c)
	return Creature.tier_for(ch.character_level()) if ch != null else 1


## The save DC an heirloom's own property sets: 16 + its bonus (17, 18, 19).
static func heirloom_dc(c: Combatant) -> int:
	return 16 + tier(c)


## The item's inventory entry for `c` (where captured creatures, a curse's level and the like are kept), or {}.
func entry_of(c: Combatant, item_id: String) -> Dictionary:
	var it := held(c, item_id)
	return it["entry"] as Dictionary if not it.is_empty() else {}


## Whether the item's (hidden) power `power_id` has a use left.
func use_left(c: Combatant, item_id: String, power_id: String) -> bool:
	var p := enc().items.find_power(c, item_id, power_id)
	return not p.is_empty() and CombatItems.uses_spent(p) < CombatItems.use_count(p)


func spend_use(c: Combatant, item_id: String, power_id: String) -> void:
	var p := enc().items.find_power(c, item_id, power_id)
	if not p.is_empty():
		CombatItems.spend_use(p)


## Gives a spent use of power `power_id` back (the Marotte's laughter on a natural 1).
func restore_use(c: Combatant, item_id: String, power_id: String) -> bool:
	var p := enc().items.find_power(c, item_id, power_id)
	if p.is_empty() or CombatItems.uses_spent(p) <= 0:
		return false
	var uses := (p["entry"] as Dictionary).get("uses", {}) as Dictionary
	uses[power_id] = int(uses.get(power_id, 0)) - 1
	return true


## An Effect from the item, keyed so it can be found again.
static func item_fx(c: Combatant, label: String, item_id: String, key: String) -> Effect:
	var fx := Effect.new(label, &"item", item_id)
	fx.caster_id = c.id if c != null else ""
	fx.stack_key = key
	return fx


static func fx_of(t: Combatant, key: String) -> Effect:
	if t == null:
		return null
	for fx in t.creature.effects:
		if fx.stack_key == key:
			return fx
	return null


## A save against an heirloom's property; true when `t` makes it.
func saves(t: Combatant, ab: StringName, dc: int, label: String, keys: Array[String] = []) -> bool:
	var e := enc()
	var s := t.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_SHORT[ab], label, t.name()], keys)
	e.log.add("roll", "%s %s the %s save against %s (DC %d)" % [t.name(), "makes" if s.success else "fails", Creature.ABILITY_SHORT[ab], label, dc], t.id, [s.describe()])
	return s.success


## Rolls `dice` and deals it as `type` from `source` to `t`; the damage dealt.
func hurt(source: Combatant, t: Combatant, dice: String, type: String, label: String, extra: Dictionary = {}) -> int:
	var e := enc()
	var rolled := e._roll_damage_dice(dice, false, 0, label)
	var part := {"amount": int(rolled["total"]), "type": type}
	part.merge(extra, true)
	return e.deal_damage(source, t, [part], false, label, [str(rolled["text"])]).final


## The creature behind a save `c` is making: the caster of the spell it's against, else whoever's turn it is.
func save_source(c: Combatant, keys: Array[String]) -> Combatant:
	for k in keys:
		if k.begins_with("save_vs:spell:"):
			return enc().get_c(k.substr(14))
	var cur := enc().current()
	return cur if cur != c else null


## Whether `t` stands in magical Darkness.
func in_darkness(t: Combatant) -> bool:
	for cell in t.footprint():
		if enc().spells.zones.magical_darkness(cell):
			return true
	return false


## Halves the parts of `type` in incoming damage (a Resistance an heirloom grants for a moment), unless `t` already resists it.
static func halve(t: Combatant, parts: Array, type: String) -> bool:
	if t.creature.resistance_source(StringName(type)) != "":
		return false
	var done := false
	for raw: Variant in parts:
		var d := raw as Dictionary
		if str(d["type"]) == type and int(d["amount"]) > 0 and not bool(d.get("ignore_resistance", false)):
			d["amount"] = int(d["amount"]) / 2
			done = true
	return done
