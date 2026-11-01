extends TestCase
## The Crooked Man's pit (data/locations/nm_pit.json; the engine's free-fall fights): everyone falling together.


func test_the_pit_is_a_free_fall() -> void:
	for e: Dictionary in Compendium.shared().get_entry("locations", "nm_pit")["encounters"]:
		assert_true(bool(e.get("free_fall", false)), str(e["id"]))
