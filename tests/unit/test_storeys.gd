extends TestCase
## Buildings whose floors are one place (Storeys): every floor listed is a place, each floor's stairs reach the next one up
## or down, and going up or down them is a climb inside the building, while leaving it is an ordinary change of place.


func test_every_floor_is_a_place_and_its_stairs_reach_the_next() -> void:
	for b: String in Storeys.BUILDINGS:
		var floors := Storeys.BUILDINGS[b] as Array
		assert_true(floors.size() >= 2, "%s has floors" % b)
		for i in floors.size():
			var id := str(floors[i])
			assert_true(Compendium.shared().has("locations", id), "%s is a place" % id)
			if i == 0:
				continue
			var below := str(floors[i - 1])
			assert_true(_reaches(below, id), "%s's stair goes up to %s" % [below, id])
			assert_true(_reaches(id, below), "%s's stair goes down to %s" % [id, below])


func test_a_stair_is_a_climb_and_a_door_out_is_not() -> void:
	assert_eq(Storeys.climb("wickermoor_green_queen_inn", "wickermoor_green_queen_inn_upper"), 1, "one storey up")
	assert_eq(Storeys.climb("wickermoor_green_queen_inn_upper", "wickermoor_green_queen_inn"), -1, "one down")
	assert_eq(Storeys.climb("fw_windmill", "fw_windmill_cellar"), -1, "the mill's cellar is below it")
	assert_eq(Storeys.climb("wickermoor_green_queen_inn", "wickermoor_village"), 0, "out of the inn is a change of place")
	assert_eq(Storeys.building_of("crooked_house"), "", "the Crooked House is one place, its floors in it")
	assert_eq(Storeys.climb("wickermoor_village", "wickermoor_green_queen_inn"), 0, "and so is going in")
	assert_eq(Storeys.building_of("wickermoor_green_queen_inn_upper"), "green_queen_inn")


func _reaches(from: String, to: String) -> bool:
	for e: Variant in Compendium.shared().get_entry("locations", from).get("exits", []):
		if str((e as Dictionary).get("to", "")) == to:
			return true
	return false
