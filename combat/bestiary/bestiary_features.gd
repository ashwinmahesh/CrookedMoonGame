class_name BestiaryFeatures
extends CmPart
## The Crooked Moon's bestiary code (lane D2): the parts of the book's monsters that data can't say. A part of
## CrookedFeatures (combat/crooked_features.gd PART_PATHS); its action ids start "bs_". The stat blocks name what needs
## code with a `do` (vault Build/D2 - Bestiary Build Log.md lists them in the order the chapters need them).
##
## Built so far, for the prologue (package R10): the Wayward Haint's opening wail and Exhaustion, the Soulfire Stoker's
## Corpse Fuel, the Ghostlight Locomotive's Soul Fuel, Soul Cans, haint echoes and Ghostly Rails.

const PREFIX := "bs_"
const HAINT := "wayward_haint"
const STOKER := "soulfire_stoker"
const LOCOMOTIVE := "ghostlight_locomotive"
## What a Soul Can's prop id starts with; a bottled haint stands in for one (its prop id ends with the haint's id).
const CAN_PREFIX := "soul_can_"
const BOTTLE_PREFIX := "bottled_haint_"
## Set on a haint echo (the haint it was) and on a creature that has wailed.
const ECHO_META := "bs_echo_of"
const WAILED_META := "bs_wailed"
const ASHED_META := "bs_ashed"
## The creatures the Locomotive has already grappled on this charge (ids), cleared when its turn starts.
const RAILED_META := "bs_railed"
## Exhaustion levels a creature carries from a monster until its next rest.
const REST_EXHAUSTION_META := "cm_rest_exhaustion"


func prefix() -> String:
	return PREFIX


static func monster_id(c: Combatant) -> String:
	return str(MonsterActions.data_of(c).get("id", "")) if c.creature is Monster else ""


# --- Placing Soul Cans ----------------------------------------------------------------------------------------------

## Lays Soul Cans on `cells` (Tiny objects: AC 11, 1 Hit Point, immune to lightning, poison and psychic); a cell paired with
## a haint id in `bottled` holds that haint's jar instead. Returns the objects.
static func place_soul_cans(e: Encounter, cells: Array[Vector2i], bottled: Dictionary = {}) -> Array[BattleObject]:
	var out: Array[BattleObject] = []
	var n := 0
	for cell in cells:
		n += 1
		var haint := str(bottled.get(cell, ""))
		var o := e.objects.add("crate", [cell], {
			"name": "a bottled haint's jar" if haint != "" else "a Soul Can", "size": "tiny", "ac": 11, "hp": 1, "hp_max": 1,
			"blocks": 0, "resilient": false, "prop_id": (BOTTLE_PREFIX + haint) if haint != "" else "%s%d" % [CAN_PREFIX, n]})
		o.immune.append("lightning")
		out.append(o)
	return out


static func is_can(o: BattleObject) -> bool:
	return not o.destroyed and (o.prop_id.begins_with(CAN_PREFIX) or o.prop_id.begins_with(BOTTLE_PREFIX))


## The nearest uneaten Soul Can to `c`: {object, feet}, or {}.
func _nearest_can(c: Combatant) -> Dictionary:
	var best := {}
	for o in enc().objects.list:
		if not is_can(o):
			continue
		var ft := enc().objects.distance_ft(c, o)
		if best.is_empty() or ft < int(best["feet"]):
			best = {"object": o, "feet": ft}
	return best


# --- Turns ---------------------------------------------------------------------------------------------------------

func monster_turn(c: Combatant) -> Variant:
	match monster_id(c):
		HAINT:
			return _haint_turn(c)
		STOKER:
			return _stoker_turn(c)
		LOCOMOTIVE:
			return _locomotive_turn(c)
	return null


func turn_start(c: Combatant) -> CombatResult:
	c.remove_meta(RAILED_META)
	if monster_id(c) == LOCOMOTIVE and c.is_alive():
		var can := _nearest_can(c)
		if not can.is_empty() and int(can["feet"]) <= 10:
			_eat(c, can["object"] as BattleObject)
	return CombatResult.new()


## The haint's first turn in a fight is a wail and nothing else (R10 decision 28); an echo fights at once.
func _haint_turn(c: Combatant) -> Variant:
	if c.has_meta(WAILED_META) or c.has_meta(ECHO_META):
		return null
	c.set_meta(WAILED_META, true)
	_log("info", "%s wails its grief, and the cold of it fills the room" % c.name(), c)
	return CombatResult.new()


## Corpse Fuel: a Stoker that starts its turn able to see a corpse moves as far into its space as it can and burns it.
func _stoker_turn(c: Combatant) -> Variant:
	var e := enc()
	var corpse: Combatant = null
	for o in e.combatants:
		if o.creature.dead and not o.has_meta(ASHED_META) and e.can_see(c, o) and (corpse == null or e.distance(c, o) < e.distance(c, corpse)):
			corpse = o
	if corpse == null:
		return null
	var r := _walk_toward(c, corpse.cell)
	if e.distance(c, corpse) <= 5:
		corpse.set_meta(ASHED_META, true)
		e.spend_action(c)
		_log("info", "%s burns %s down to ash" % [c.name(), corpse.name()], c)
		e.events.append({"type": "condition", "id": corpse.id})
	return r


## The Locomotive goes for an uneaten can (the +20 Hit Points) before it looks for a hero; once it is within 10 ft the
## can is eaten as its next turn starts.
func _locomotive_turn(c: Combatant) -> Variant:
	var can := _nearest_can(c)
	if can.is_empty() or int(can["feet"]) <= 10:
		return null
	var o := can["object"] as BattleObject
	_walk_toward(c, o.cells[0])
	return null


## Walks `c` as near to `dest` as its movement lets it.
func _walk_toward(c: Combatant, dest: Vector2i) -> CombatResult:
	var e := enc()
	var reach := e.reachable_for(c)
	var best := c.cell
	var best_d := e.grid.distance_ft(c.cell, c.size_cells, dest, 1)
	for cell: Vector2i in reach:
		if bool((reach[cell] as Dictionary)["occupied"]):
			continue
		var d := e.grid.distance_ft(cell, c.size_cells, dest, 1)
		if d < best_d:
			best = cell
			best_d = d
	if best == c.cell:
		return CombatResult.new()
	return e._walk(c, CombatGrid.path_to(reach, best), 1, CombatResult.new(), {"willing": true})


# --- Soul Fuel and the echoes ---------------------------------------------------------------------------------------

## The Locomotive devours a can: +20 Hit Points and Advantage on its attacks until its next turn starts. The can's
## breaking lets out its echo (object_broken).
func _eat(c: Combatant, can: BattleObject) -> void:
	var e := enc()
	_log("info", "%s devours %s" % [c.name(), can.the()], c)
	var healed := c.creature.heal(20, "Soul Fuel")
	if healed > 0:
		e.events.append({"type": "heal", "id": c.id, "amount": healed})
	e.monster_actions._timed_condition(c, c, "", "source_turn_start", "Soul Fuel", [{"stat": "advantage", "on": "attack"}], {})
	e.objects.smash(can, "eaten")


## A can broken, eaten or smashed lets out the echo of the haint it held, at half Hit Points, on the can's square.
func object_broken(o: BattleObject, _source: Combatant) -> void:
	if not (o.prop_id.begins_with(CAN_PREFIX) or o.prop_id.begins_with(BOTTLE_PREFIX)):
		return
	var e := enc()
	var engine: Combatant = null
	for c in e.combatants:
		if c.is_alive() and monster_id(c) == LOCOMOTIVE:
			engine = c
	if engine == null:
		return
	var haint := o.prop_id.trim_prefix(BOTTLE_PREFIX) if o.prop_id.begins_with(BOTTLE_PREFIX) else HAINT
	var data := Compendium.shared().monster_data(HAINT)
	var m := Monster.from_data(data, e.dice)
	m.hp = ceili(m.max_hp() / 2.0)
	var at := e.spells._free_cell_near(o.cells[0], 1)
	var echo := e.add(m, &"enemy", at)
	echo.set_meta("summoner", engine.id)
	echo.set_meta(ECHO_META, haint)
	if e.state == Encounter.State.ACTIVE:
		e.insert_after(engine, echo)
	e.events.append({"type": "summon_creature", "id": echo.id, "cell": at, "caster": engine.id})
	_log("info", "The echo of %s rises from %s" % ["a wayward haint" if haint == HAINT else haint.replace("_", " "), o.the()], engine)


# --- Ghostly Rails -------------------------------------------------------------------------------------------------

## The Locomotive charging along its spectral rails (a legendary move that provokes nothing): every Large or smaller
## creature it passes through is Grappled by the rails (escape DC 14).
func entered_cell(c: Combatant, _cell: Vector2i) -> void:
	if not c.has_meta(Legendary.NO_OA_MOVE) or monster_id(c) != LOCOMOTIVE:
		return
	var e := enc()
	var mine := c.footprint()
	var railed := c.get_meta(RAILED_META, []) as Array
	for o in e.combatants:
		if o == c or not o.is_alive() or o.size_cells > 2 or o.id in railed:
			continue
		if o.footprint().any(func(cell: Vector2i) -> bool: return cell in mine):
			railed.append(o.id)
			c.set_meta(RAILED_META, railed)
			e.monster_actions._timed_condition(c, o, "grappled", "minute", "Ghostly Rails", [], {"escape": {"skill": "athletics", "dc": 14}})
			_log("condition", "Spectral rails coil round %s" % o.name(), c)


# --- Riders --------------------------------------------------------------------------------------------------------

func rider(src: Combatant, t: Combatant, rd: Dictionary, _by_type: Dictionary, act_name: String) -> bool:
	match str(rd.get("do", "")):
		"exhaustion":
			_exhaustion(src, t, rd, act_name)
			return true
	return false


## `levels` of Exhaustion, never past `max` (5 for the haint), that go away at the next rest: the levels it gave are
## counted on the creature (cm_rest_exhaustion) for the rest hook to take off.
func _exhaustion(src: Combatant, t: Combatant, rd: Dictionary, act_name: String) -> void:
	var p := rd.get("params", rd) as Dictionary
	var room := int(p.get("max", 6)) - t.creature.exhaustion
	var n := mini(int(p.get("levels", 1)), room)
	if n <= 0:
		return
	if t.creature.add_exhaustion(n) and str(p.get("until", "")) == "rest":
		t.creature.set_meta(REST_EXHAUSTION_META, int(t.creature.get_meta(REST_EXHAUSTION_META, 0)) + n)
	_log("condition", "%s is worn down by %s (Exhaustion %d)" % [t.name(), act_name, t.creature.exhaustion], src)
