extends TestCase
## The Crooked Moon's own words on the party screen's gaps (CrookedMoonCampaign.coverage_words): Druskenvald, never Barovia.


func test_the_vagrants_words_name_druskenvald() -> void:
	var words := CrookedMoonCampaign.new().coverage_words()
	assert_true(str(words["dark"]).contains("Druskenvald"))
	for k: String in ["dark", "radiant"]:
		assert_false(str(words[k]).contains("Barovia"), k)
