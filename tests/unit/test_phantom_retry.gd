extends TestCase
## The Phantom Trainhopper's first fight (R10, section 3) retries like the Ghostlight Locomotive: a wipe puts the party back
## on its feet and the same fight begins afresh, rather than a game over (data/fight_retries.json, story/fight_retry.gd).

const PHANTOM_FIGHT := "gl_phantom_strikes"
const PASSENGER_CAR := "ghostlight_g1_passenger"


func test_the_phantom_fight_retries_from_its_own_entry() -> void:
	var spec := {"id": PHANTOM_FIGHT}
	var rule := FightRetry.rule_for(spec, PASSENGER_CAR)
	assert_false(rule.is_empty(), "a lost Phantom fight is a retry, not a game over")
	assert_eq(FightRetry.restart_id(rule, spec), PHANTOM_FIGHT, "the same fight begins afresh")
	assert_eq(str(rule.get("count_flag", "")), "gl_phantom_retries", "its losses are counted")


func test_the_locomotive_still_retries() -> void:
	var rule := FightRetry.rule_for({"id": "gl_locomotive"}, "ghostlight_wreckage")
	assert_eq(str(rule.get("id", "")), "ghostlight_locomotive", "the locomotive keeps its own rule")


func test_an_unrelated_fight_is_still_a_game_over() -> void:
	assert_true(FightRetry.rule_for({"id": "gl_some_other_fight"}, PASSENGER_CAR).is_empty(), "no rule, so a wipe is a game over")
