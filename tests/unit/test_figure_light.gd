extends TestCase
## The 3D figures' light in the Crooked Moon's fully 3D look (data/campaign.json "figures", engine Look.figure_settings): no ink, and the
## rim a lamp behind a figure draws along its edge and the light it keeps in the dark are turned right down. At the engine's defaults
## (rim 1.2, floor 0.25, made for HD-2D sprites and Curse of Strahd) a lantern behind Phillip and Adela in the lounge car drew a bright
## orange edge on them and filled them with their own light, which read as a glow or a reflection.


func test_the_figures_are_lit_by_the_scene_not_by_a_rim_or_a_glow_of_their_own() -> void:
	Look.forget_toon_settings()
	var s := Look.figure_settings()
	assert_eq(float(s["ink"]), 0.0, "no outline on figures in the fully 3D look")
	assert_true(float(s["rim"]) <= 0.3, "a light behind a figure draws only a faint edge (%.2f)" % float(s["rim"]))
	assert_true(float(s["floor"]) <= 0.2, "a figure keeps little light of its own in the dark (%.2f)" % float(s["floor"]))
	assert_true(float(s["light_cap"]) <= 0.9, "no light washes a figure out")
	Look.forget_toon_settings()
