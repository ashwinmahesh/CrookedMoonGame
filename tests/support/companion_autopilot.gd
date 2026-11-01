class_name CompanionAutopilot
extends PartyAutopilot
## The test autopilot for this game's companions, whose kits PartyAutopilot doesn't play: it has no sorcerer, so
## Cordelia drew her dagger and never cast, and its warlock walks toward the weakest foe even when another is in range,
## so Delphine hardly blasted. Here a sorcerer casts Magic Missile at a sturdy foe while her slots last and Ray of
## Frost (or Chill Touch in reach) otherwise, and a warlock hexes and blasts the weakest foe she can reach. Everyone
## else plays as PartyAutopilot plays them. Test-only, like PartyAutopilot: in the game the player controls every hero.

## A foe with at least this many Hit Points left is worth a Magic Missile.
const MISSILE_WORTH_HP := 20


func play(c: Combatant) -> CombatResult:
	var ch := c.creature as Character
	if ch == null or not c.can_act():
		return super.play(c)
	if ch.class_level_of("sorcerer") > 0:
		e.ground.ai_pick_up(c)
		return _sorcerer(c)
	if ch.class_level_of("warlock") > 0:
		e.ground.ai_pick_up(c)
		return _blaster(c)
	return super.play(c)


## The weakest foe within `ft`, or null.
func _weakest_within(c: Combatant, foes: Array[Combatant], ft: int) -> Combatant:
	var near: Array[Combatant] = []
	for f in foes:
		if e.distance(c, f) <= ft:
			near.append(f)
	return _weakest(near)


func _sorcerer(c: Combatant) -> CombatResult:
	var ch := c.creature as Character
	var foes := _enemies(c)
	if foes.is_empty() or not c.action_available:
		return _melee_turn(c)
	# Magic Missile never misses: at the sturdiest foe in range while it has Hit Points to spare, a dart a slot level.
	if ch.knows_spell("magic_missile") and not c.cast_slot_spell_this_turn:
		var big: Combatant = null
		for f in foes:
			if e.distance(c, f) <= 120 and f.creature.hp >= MISSILE_WORTH_HP \
					and (big == null or f.creature.hp > big.creature.hp):
				big = f
		if big != null:
			for slot: int in [2, 1]:
				if ch.slots_left(slot) <= 0:
					continue
				var darts: Array = []
				for i in slot + 2:
					darts.append(big)
				var r := _cast(c, "magic_missile", slot, darts)
				if r.ok:
					return r
	for cantrip: Array in [["chill_touch", 5], ["ray_of_frost", 60]]:
		var target := _weakest_within(c, foes, int(cantrip[1]))
		if target != null and ch.knows_spell(str(cantrip[0])):
			var r := _cast(c, str(cantrip[0]), 0, [target])
			if r.ok:
				return r
	return _melee_turn(c)


func _blaster(c: Combatant) -> CombatResult:
	var ch := c.creature as Character
	var foes := _enemies(c)
	if foes.is_empty() or not c.action_available:
		return _melee_turn(c)
	var target := _weakest_within(c, foes, 120)
	if target == null:
		return _melee_turn(c)
	# Hex (a Bonus Action) on the foe about to be blasted, kept on it while it stands.
	var hexed: Combatant = null
	for f in foes:
		for fx in f.creature.effects:
			if fx.source_id == "hex" and fx.caster_id == c.id:
				hexed = f
	if hexed != null and e.distance(c, hexed) <= 120:
		target = hexed
	elif c.bonus_available and not c.cast_slot_spell_this_turn and ch.knows_spell("hex") \
			and ch.slots_left(1) + int(ch.pact_magic()["left"]) > 0 and not _concentrating_on_anything(c):
		_cast(c, "hex", 1, [target])
	for beams: int in [4, 3, 2, 1]:
		var aim: Array = []
		for i in beams:
			aim.append(target)
		var r := _cast(c, "eldritch_blast", 0, aim)
		if r.ok:
			return r
	return _melee_turn(c)
