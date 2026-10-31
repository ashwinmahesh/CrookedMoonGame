class_name BestiaryFeatures
extends CmPart
## The Crooked Moon's bestiary code (lane D2): the parts of the book's monsters that data can't say. A part of
## CrookedFeatures (combat/crooked_features.gd PART_PATHS); its action ids start "bs_". The stat blocks name what needs
## code with a `do` (vault Build/D2 - Bestiary Build Log.md lists them in the order the chapters need them).
##
## The wildpyre's Quenching Water (its stat block's trait of that name) is here too: a hero throws a jug of water at it
## from the hotbar and it burns as Holy Water does (bs_throw_water).
##
## Built so far: for the prologue (package R10) the Wayward Haint's opening wail and Exhaustion, the Soulfire Stoker's
## Corpse Fuel and the Ghostlight Locomotive's Ghostly Rails; for R11-R12 the shared Teleport and Dark Teleport bonus
## actions and the Boogleswarm's Tooth Theft. The Locomotive's Soul Fuel, its Soul Cans and the haint echoes they let out
## are data the engine runs (its block's `devours`, the wreck fights' `objects` with `releases`: ObjectFuel).

const PREFIX := "bs_"
const HAINT := "wayward_haint"
const STOKER := "soulfire_stoker"
const CORRUPTED_STOKER := "corrupted_soulfire_stoker"   ## the Tender's: 30 Hit Points, one Sear; the same burning of corpses
const LOCOMOTIVE := "ghostlight_locomotive"
## Set on a creature that has wailed.
const WAILED_META := "bs_wailed"
const ASHED_META := "bs_ashed"
## The creatures the Locomotive has already grappled on this charge (ids), cleared when its turn starts.
const RAILED_META := "bs_railed"
## Exhaustion levels a creature carries from a monster until its next rest.
const REST_EXHAUSTION_META := "cm_rest_exhaustion"
## The Boogleswarm: the ids of those whose teeth it wears; and on a creature, how many teeth it has lost.
const TEETH_META := "bs_teeth"
const TEETH_LOST_META := "bs_teeth_lost"
## Water as a weapon: the item the Dining Car hands out, the trait that makes a creature burn from it, and the throw's range.
const AMBER_CROW := "amber_crow"
## On Raum: the amber crows he has eaten.
const CROWS_EATEN_META := "bs_crows_eaten"
const WATER := "jug_of_water"
const QUENCHING_TRAIT := "quenching_water"
const WATER_RANGE_FT := 20


func prefix() -> String:
	return PREFIX


static func monster_id(c: Combatant) -> String:
	return str(MonsterActions.data_of(c).get("id", "")) if c.creature is Monster else ""


# --- Quenching Water -----------------------------------------------------------------------------------------------

## Whether water burns `t` as Holy Water would: its stat block has the Quenching Water trait (the wildpyre).
static func burns_from_water(t: Combatant) -> bool:
	if t == null or not t.creature is Monster:
		return false
	for tr: Variant in MonsterActions.data_of(t).get("traits", []):
		if str((tr as Dictionary).get("id", "")) == QUENCHING_TRAIT:
			return true
	return false


## A hero carrying a jug of water gets "Throw Water" while a creature that burns from it is in the fight.
func list(c: Combatant, out: Array[Dictionary], aw: String, _bw: String) -> void:
	var ch := _ch(c)
	if ch == null or enc().item_count(c, WATER) <= 0 or not enc().hostiles_of(c).any(func(h: Combatant) -> bool: return burns_from_water(h) and not h.is_down()):
		return
	var dc := dc_of(c, &"dex")
	out.append(_act("throw_water", "Throw Water", "Dex save DC %d · 2d8 Radiant · %d ft" % [dc, WATER_RANGE_FT], "action", aw, "creature",
		"Action: throw a jug of water at a creature you can see within %d ft. If it burns from water (the wildpyre) it makes a Dexterity save (DC %d) or takes 2d8 Radiant damage, as from Holy Water. The jug is used up." % [WATER_RANGE_FT, dc],
		WATER_RANGE_FT))


func perform(c: Combatant, id: String, t: Combatant, _cell: Vector2i, _point: Vector2) -> CombatResult:
	if id.trim_prefix(PREFIX) == "throw_water":
		return _throw_water(c, t)
	return CombatResult.fail("Not available")


## The jug leaves the hand; a creature that burns from water saves against the thrower's Dexterity DC or takes 2d8 Radiant.
func _throw_water(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if ch == null or e.item_count(c, WATER) <= 0:
		return CombatResult.fail("No water to throw")
	if t == null or not burns_from_water(t) or t.is_down():
		return CombatResult.fail("Choose a creature that burns from water")
	if e.distance(c, t) > WATER_RANGE_FT or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within %d ft" % WATER_RANGE_FT)
	e.spend_action(c)
	for en: Dictionary in ch.inventory:
		if str(en["id"]) == WATER and int(en["qty"]) > 0:
			en["qty"] = int(en["qty"]) - 1
			if int(en["qty"]) <= 0:
				ch.inventory.erase(en)
			break
	ch.items_changed()
	if c.hidden:
		e.reveal(c, "threw water")
	var dc := dc_of(c, &"dex")
	if _save(t, &"dex", dc, "the thrown water"):
		_log("info", "%s throws a jug of water at %s, which twists clear of most of it" % [c.name(), t.name()], c)
		return CombatResult.new()
	var rolled := enc()._roll_damage_dice("2d8", false, 0, "Water")
	e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "radiant"}], false, "Water", [str(rolled["text"])])
	_log("info", "%s throws a jug of water at %s, and it burns like Holy Water" % [c.name(), t.name()], c)
	return CombatResult.new()


# --- Turns ---------------------------------------------------------------------------------------------------------

func monster_turn(c: Combatant) -> Variant:
	match monster_id(c):
		HAINT:
			return _haint_turn(c)
		STOKER, CORRUPTED_STOKER:
			return _stoker_turn(c)
	return null


func turn_start(c: Combatant) -> CombatResult:
	c.remove_meta(RAILED_META)
	return CombatResult.new()


## The haint's first turn in a fight is a wail and nothing else (R10 decision 28); an echo out of a Soul Can or a jar
## fights at once.
func _haint_turn(c: Combatant) -> Variant:
	if c.has_meta(WAILED_META) or c.has_meta(ObjectFuel.RELEASED_META):
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


# --- Teleporting ----------------------------------------------------------------------------------------------------

## A `teleport` or `dark_teleport` Bonus Action (Ketgrinn, the Lurker in the Dark, the Lord of Fools, the Beast of Blight).
## The AI uses it once, at the start of its turn (the engine asks every Bonus Action plan in turn; "shift" comes first), to
## close a gap it can't walk: when the nearest hero it can see is farther than its Speed and reach, it appears in a free
## square it can see beside that hero. A dark teleport is not for bright light.
func bonus_action(c: Combatant, act: Dictionary, plan: String) -> Variant:
	var kind := str(act.get("do", ""))
	if kind == "eat_crow":
		return _eat_crow(c, act)
	if plan != "shift" or not kind in ["teleport", "dark_teleport"] or not c.bonus_available:
		return null
	var e := enc()
	if kind == "dark_teleport" and e.light_at(c.cell) == "bright":
		return null
	var foe: Combatant = null
	for h in e.hostiles_of(c):
		if not h.is_down() and e.can_see(c, h) and (foe == null or e.distance(c, h) < e.distance(c, foe)):
			foe = h
	if foe == null or e.distance(c, foe) <= c.speed() + c.reach_ft():
		return null
	var range_ft := int((act.get("targets", {}) as Dictionary).get("range", 30))
	var best := Vector2i(-1, -1)
	var best_d := 100000
	for x in e.grid.width:
		for y in e.grid.depth:
			var cell := Vector2i(x, y)
			if e.grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells) > range_ft or not e.spells._room_for(cell, c.size_cells):
				continue
			if e.grid.distance_ft(cell, c.size_cells, foe.cell, foe.size_cells) > c.reach_ft() or not e.can_see_space(c, cell, c.size_cells):
				continue
			var d := e.grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells)
			if d < best_d:
				best = cell
				best_d = d
	if best.x < 0:
		return null
	c.bonus_available = false
	e.monster_actions.spend(c, act)
	var r := CombatResult.new()
	_log("info", "%s %s" % [c.name(), "slips through the dark" if kind == "dark_teleport" else "vanishes and reappears"], c)
	e.spells._teleport(c, best, r)
	return r


# --- Raum's crows -----------------------------------------------------------------------------------------------

## Raum's Bonus Action (R13): he eats an amber crow within 30 ft, gaining 10, then 20, then 30 Temporary Hit Points. The third crow
## ends his first phase (the story flag fw_crows_eaten_3, which the phase's `when` reads beside six crows gone). Null when none is near.
func _eat_crow(c: Combatant, act: Dictionary) -> Variant:
	var e := enc()
	var eaten := int(c.get_meta(CROWS_EATEN_META, 0))
	if eaten >= 3 or not c.bonus_available:
		return null
	var crow: Combatant = null
	for o in e.combatants:
		if o != c and not o.is_down() and monster_id(o) == AMBER_CROW and e.distance(c, o) <= 30 and (crow == null or e.distance(c, o) < e.distance(c, crow)):
			crow = o
	if crow == null:
		return null
	c.bonus_available = false
	e.monster_actions.spend(c, act)
	eaten += 1
	c.set_meta(CROWS_EATEN_META, eaten)
	e.legendary.vanish(crow, "%s is swallowed whole" % crow.name())
	c.creature.add_temp_hp(10 * eaten, "Devour Crow")
	_log("info", "%s eats an amber crow (%d of 3)" % [c.name(), eaten], c)
	if eaten >= 3:
		e.legendary.story_flags["fw_crows_eaten_3"] = true
		e.legendary.phases.turn_start(c)   # a phase waiting on a story flag begins now
	return CombatResult.new()


# --- Riders --------------------------------------------------------------------------------------------------------

func rider(src: Combatant, t: Combatant, rd: Dictionary, _by_type: Dictionary, act_name: String) -> bool:
	match str(rd.get("do", "")):
		"exhaustion":
			_exhaustion(src, t, rd, act_name)
			return true
		"tooth_theft":
			_tooth_theft(src, t, rd, act_name)
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


## Tooth Theft (the Boogleswarm's Bite): a Constitution save or the target loses a tooth, which the swarm implants. A target
## that has already lost one to this swarm doesn't save again. The swarm's implants (target ids) are kept as meta `bs_teeth`
## for its Mimicry; what a target has lost, on the creature as `bs_teeth_lost`.
func _tooth_theft(src: Combatant, t: Combatant, rd: Dictionary, act_name: String) -> void:
	var p := rd.get("params", rd) as Dictionary
	var teeth := src.get_meta(TEETH_META, []) as Array
	if bool(p.get("auto_success_if_already_lost", false)) and t.id in teeth:
		return
	var sv := p.get("save", {"ability": "con", "dc": 12}) as Dictionary
	if _save(t, StringName(str(sv.get("ability", "con"))), int(sv.get("dc", 12)), act_name):
		return
	t.creature.set_meta(TEETH_LOST_META, int(t.creature.get_meta(TEETH_LOST_META, 0)) + 1)
	if bool(p.get("implant", false)):
		teeth.append(t.id)
		src.set_meta(TEETH_META, teeth)
	_log("condition", "%s's bite takes one of %s's teeth" % [src.name(), t.name()], src)


func _save(t: Combatant, ab: StringName, dc: int, label: String) -> bool:
	var e := enc()
	var sv := t.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, t.name()], [] as Array[String])
	e.log.add("info", "%s %s the %s save" % [t.name(), "succeeds on" if sv.success else "fails", label], t.id, [sv.describe()])
	return sv.success
