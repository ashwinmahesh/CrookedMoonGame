class_name Storeys
extends RefCounted
## Buildings whose floors are one place (Ashwin, 2026-11-02: "we no longer need to separate floors into different areas ...
## These can all be a single multi-floor area"). The engine's grid holds one floor height per square, so each floor keeps
## its own map, but walking its stairs is a climb inside the building, not a change of place (GameRoot.enter_location's
## `storey`): no black, no loading card, no place name, the next floor built while this one stands, and the camera rising
## or sinking a storey into it as the party comes off the stair.

## A storey's height in world units: a room's walls (2.4, InteriorWalls' height for the village style) and its floor.
const STOREY := 2.6

## Each building's floors, from the lowest up.
const BUILDINGS := {
	"crooked_house": ["crooked_house_first", "crooked_house_second", "crooked_house_third", "crooked_house_attic"],
	"fw_windmill": ["fw_windmill_cellar", "fw_windmill"],
	"green_queen_inn": ["wickermoor_inn_cellar", "wickermoor_green_queen_inn", "wickermoor_green_queen_inn_upper"],
	"barber_shop": ["wickermoor_barber_cellar", "wickermoor_barber_shop"],
	"funeral_home": ["wickermoor_funeral_basement", "wickermoor_funeral_home"],
	"trading_post": ["wickermoor_trading_cellar", "wickermoor_trading_post"],
	"briar": ["dg_briar_cellar", "dg_briar", "dg_briar_upper"],
	"monastery": ["mon_ground", "mon_upper"],
	"bell_tower": ["mon_bell_tower", "mon_belfry"],
}


## The building place `id` is a floor of, or "".
static func building_of(id: String) -> String:
	for b: String in BUILDINGS:
		if (BUILDINGS[b] as Array).has(id):
			return b
	return ""


## How many storeys up (negative: down) going from place `from` to place `to` climbs, when they are floors of one
## building; 0 when they aren't (an ordinary change of place).
static func climb(from: String, to: String) -> int:
	var b := building_of(from)
	if b == "" or b != building_of(to):
		return 0
	var floors := BUILDINGS[b] as Array
	return floors.find(to) - floors.find(from)
