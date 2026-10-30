extends TestCase
## The Crooked Moon's own fight code (E26): data/campaign.json names combat/crooked_features.gd, every encounter makes
## one, and it hands each hotbar action to the part that owns its prefix.


func test_every_fight_gets_the_crooked_moon_module_and_its_parts() -> void:
	GameFeatures.use(null)
	var e := TestCombat.open_field()
	assert_true(e.game is CrookedFeatures, "the module data/campaign.json names")
	var cf := e.game as CrookedFeatures
	assert_eq(cf.parts.size(), CrookedFeatures.PART_PATHS.size(), "every part loads")
	assert_true(cf.owner_of("sp_anything") is CmSpecies)
	assert_true(cf.owner_of("gm_gg_anything") is CmGraveAndGrim, "a queued Reaction's kind")
	assert_true(cf.owner_of("bj_anything") is CmBloodAndJest)
	assert_true(cf.owner_of("wr_anything") is CmWarriors)
	assert_true(cf.owner_of("cs_anything") is CmCasters)
	assert_true(cf.owner_of("sh_anything") is CmScholars)
	assert_true(cf.owner_of("sa_anything") is CmSpellsA)
	assert_true(cf.owner_of("sb_anything") is CmSpellsB)
	assert_true(cf.owner_of("db_anything") is CmBargains)
	assert_true(cf.owner_of("ft_anything") is CmFeats)
	assert_true(cf.owner_of("nobody") == null)
	assert_false(cf.perform(null, "nobody", null, Vector2i.ZERO, Vector2.ZERO).ok, "an action no part owns")
