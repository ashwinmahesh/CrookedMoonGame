extends TestCase
## What grows in each region (art/plants/flora.json, plan 8.3, the look lane): every mood grows a set that exists, the regions' own
## sets are the ones the colour script names, every plant a set names is a built plant, the sets' autumn colours are palette
## names, and the leaf cards that carry a region's look (bracken's fungal fronds, the corn) are painted in the atlas.

const REGIONS := {"wickermoor": "wickermoor", "foxwillow": "corn", "hartsblight": "fungal", "wytchwood": "wytchwood",
	"memorys_rest": "willows", "bayou": "willows", "maidenmist": "maidenmist", "moors": "moor", "gl_wreck": "wreck",
	"crooked_tree": "wytchwood", "dawns_gate": "mountain"}


func test_every_mood_grows_a_set_that_exists() -> void:
	var sets := Flora.config()["sets"] as Dictionary
	for mood: String in (Atmosphere.moods()["moods"] as Dictionary):
		assert_true(sets.has(Flora.set_for(mood)), "%s grows %s" % [mood, Flora.set_for(mood)])


func test_the_regions_grow_their_own_sets() -> void:
	for mood: String in REGIONS:
		assert_eq(Flora.set_for(mood), str(REGIONS[mood]), "%s" % mood)


func test_every_plant_a_set_names_is_built_and_every_autumn_colour_a_palette_name() -> void:
	var plants := Flora.manifest()
	var palette := JSON.parse_string(FileAccess.get_file_as_string("res://art/palette/palette.json")) as Dictionary
	for id: String in (Flora.config()["sets"] as Dictionary):
		var spec := Flora.resolve(id)
		for key: String in ["land", "under", "open", "edge", "shore"]:
			for e: Variant in spec.get(key, []) as Array:
				assert_true(plants.has(str((e as Array)[0])), "%s.%s: %s is a plant" % [id, key, (e as Array)[0]])
		for kind: String in (spec.get("trees", {}) as Dictionary):
			for t: Variant in (spec["trees"] as Dictionary)[kind] as Array:
				assert_true(plants.has(str(t)), "%s trees: %s is a plant" % [id, t])
		for c: Variant in spec.get("autumn_colours", []) as Array:
			assert_true(palette.has(str(c)), "%s: %s is a palette colour" % [id, c])


func test_only_the_fungal_and_wytch_sets_grow_bracken_and_only_the_corn_grows_sedge() -> void:
	for id: String in (Flora.config()["sets"] as Dictionary):
		if id in ["fungal", "wytchwood", "corn"]:
			continue
		var spec := Flora.resolve(id)
		for key: String in ["land", "under", "open", "edge", "shore"]:
			for e: Variant in spec.get(key, []) as Array:
				assert_true(str((e as Array)[0]) != "bracken", "%s.%s grows no fungal fronds" % [id, key])
				assert_true(not str((e as Array)[0]) in ["sedge", "grass_dry"] or id == "corn", "%s.%s grows no cornstalks" % [id, key])


func test_the_leaf_cards_that_carry_a_regions_look_are_painted() -> void:
	var cards := JSON.parse_string(FileAccess.get_file_as_string("res://art/plants/cards.json")) as Dictionary
	var atlas := Image.load_from_file(ProjectSettings.globalize_path("res://art/plants/cards.png"))   # (the imported texture is compressed)
	for name: String in ["fern_brown", "grass_dry", "sedge", "vine_leaves", "oak_leaves", "willow_strand"]:
		var box := (cards["cells"] as Dictionary)[name] as Array
		var w := atlas.get_width()
		var h := atlas.get_height()
		var x0 := int(float(box[0]) * w)
		var x1 := int(float(box[2]) * w)
		var y0 := int(float(box[1]) * h)
		var y1 := int(float(box[3]) * h)
		var opaque := 0
		var total := 0
		for y in range(y0, y1, 4):
			for x in range(x0, x1, 4):
				total += 1
				if atlas.get_pixel(x, y).a > 0.5:
					opaque += 1
		assert_true(float(opaque) / float(total) > 0.12, "%s has a card drawn (%d of %d samples)" % [name, opaque, total])


## The Crooked Moon's own 3D plants (blender/plants_crooked_moon.py): built, each tree with its far copy, small enough for a crowd,
## and planted by the regions they were made for: corn at Foxwillow, wytch trees and briar in the Wytchwood, fungal stumps at
## Hartsblight, bald cypress in the bayou.
const OWN := {"corn": ["corn_a", "corn_b", "corn_c"], "wytchwood": ["wytch_a", "wytch_b", "briar_a"], "fungal": ["fungal_a", "fungal_b"],
	"willows": ["cypress_a"]}


func test_the_crooked_moons_own_plants_are_built_with_their_far_copies_and_stay_light() -> void:
	var plants := Flora.manifest()
	for id: String in ["corn_a", "corn_b", "corn_c", "wytch_a", "wytch_b", "fungal_a", "fungal_b", "briar_a", "cypress_a"]:
		assert_true(plants.has(id), "%s is in the manifest" % id)
		var info := plants[id] as Dictionary
		assert_true(ResourceLoader.exists(ArtPaths.of(str(info["file"]))), "%s's model is there" % id)
		assert_true(int(info["triangles"]) <= 1500, "%s stays light (%d triangles)" % [id, int(info["triangles"])])
		assert_true(Flora.mesh(id) != null and Flora.mesh(id).get_surface_count() >= 1, "%s makes a mesh" % id)
		if info.has("far"):
			assert_true(plants.has(str(info["far"])) and str((plants[str(info["far"])] as Dictionary).get("far_of", "")) == id,
				"%s has its far copy" % id)


func test_each_region_plants_its_own() -> void:
	for set_id: String in OWN:
		var spec := Flora.resolve(set_id)
		var named := {}
		for key: String in ["land", "under", "open", "edge", "shore"]:
			for e: Variant in spec.get(key, []) as Array:
				named[str((e as Array)[0])] = true
		for kind: String in (spec.get("trees", {}) as Dictionary):
			for t: Variant in (spec["trees"] as Dictionary)[kind] as Array:
				named[str(t)] = true
		for id: String in OWN[set_id]:
			assert_true(named.has(id), "%s plants %s" % [set_id, id])
