extends TestCase
## The towns' houses and rooms from Quaternius's Medieval Village MegaKit, its props from the Fantasy Props MegaKit, both in
## their own textures (tools/art/village_kit.py, fantasy_props.py, pack_textures.py; world/look/pack_materials.gd): a village
## board builds its houses in the "village" style from the pack's modules, they still bend and morph (the Crooked House's
## estate bends hardest), the pack surfaces come out lit on their own UVs, and the props the pack replaces are the pack's.

const ROWS := ["................", "................", "................", "...####.........", "...####.........", "...####.........",
	"................", "................", "................", "................"]
const ELEV := ["1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111",
	"1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111"]
const PLACE := "village_kit_test_place"

var _was := ""


func before_each() -> void:
	_was = Look.style()
	Look.set_style("modern", false)
	BuildingKit.forget()


func after_each() -> void:
	Look.set_style(_was, false)
	var bend := ((SetDressing.catalog()["building_kit"] as Dictionary)["bend"]) as Dictionary
	if bend.has("morph"):
		(bend["morph"] as Dictionary).erase(PLACE)


func _board(place: String = PLACE) -> ArenaBoard:
	var b := ArenaBoard.build(CombatGrid.from_rows(ROWS, ELEV), "village", place)
	add_child(b)
	return b


func test_every_module_the_manifest_lists_opens_with_a_mesh() -> void:
	var n := 0
	for id: String in BuildingKit.manifest():
		if not (id.begins_with("kit_village_") or id.begins_with("kit_vstone_") or id.begins_with("kit_vwood_") or id.begins_with("kit_pillar_v")):
			continue
		assert_true(BuildingKit.has(id), "%s has its file" % id)
		assert_true(BuildingKit.mesh(id) != null, "%s opens with a mesh" % id)
		n += 1
	assert_true(n >= 150, "three styles' walls, doors, windows, corners, roofs and gables, inside and out (%d)" % n)
	for style: String in ["village", "vstone", "vwood"]:
		for part: String in ["corner", "low_a", "up_a", "up_win", "window", "door", "door_top", "foot", "yard_arm", "yard_pier"]:
			assert_true(BuildingKit.has(BuildingKit.wall_id(style, part)), "%s has its %s" % [style, part])
		assert_true(BuildingKit.has("kit_pillar_" + style), "%s has its lone pillar" % style)
		for span in range(1, 13):
			assert_true(BuildingKit.roof_id(style, "slate", span, false) != "", "%s: a roof %d squares across" % [style, span])


func test_a_village_board_builds_its_houses_from_the_pack() -> void:
	var b := _board()
	assert_eq(BuildingKit.style_for(b), "village", "the village theme's style")
	assert_eq(b.buildings.size(), 1, "one house")
	var house := b.buildings[0]
	assert_eq(str(house["kit"]), "village", "built in it")
	var surfaces := _surfaces(house["root"] as Node3D)
	for want: String in ["vkit/plaster", "vkit/woodtrim", "vkit/roundtiles"]:
		assert_true(surfaces.has(want), "its walls and roof wear %s (%s)" % [want, surfaces.keys()])
	b.free()


func test_the_stilt_town_is_boards_and_the_mining_village_brick() -> void:
	var a := _board("dc_murkwater")
	assert_eq(BuildingKit.style_for(a), "vwood", "Murkwater's shacks are weathered boards")
	a.free()
	var b := _board("dawns_gate")
	assert_eq(BuildingKit.style_for(b), "vstone", "Dawn's Gate is brick and flat tiles")
	b.free()


func test_the_houses_still_bend_and_morph() -> void:
	var bent := _board("druskenvald_estate")   # the Crooked House's hill: the catalog bends it hardest
	assert_true(bent.buildings[0].get("bend") != null, "the estate's house is bent")
	bent.free()
	var bend := ((SetDressing.catalog()["building_kit"] as Dictionary)["bend"]) as Dictionary
	if not bend.has("morph"):
		bend["morph"] = {}
	(bend["morph"] as Dictionary)[PLACE] = {"tidy": 0.05}
	var b := _board()
	assert_true(BuildingMorph.has_morph(b), "the pack's walls and roof carry the morph's tidy shape")
	var checked := 0
	for mi in BuildingMorph.meshes(b):
		var mesh := mi.mesh as ArrayMesh
		var base := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var tidy := (mesh.surface_get_blend_shape_arrays(0)[0] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var far := 0.0
		for i in base.size():
			far = maxf(far, base[i].distance_to(tidy[i]))
		assert_true(far > 0.02, "the tidy shape moves the pack's points (%.3f)" % far)
		checked += 1
	assert_true(checked >= 2, "walls and roof both morph (%d)" % checked)
	b.free()


func test_houses_differ_in_their_plaster_tint() -> void:
	var colours := {}
	for pick in 42:
		colours[PackMaterials.material("vkit/plaster", pick).albedo_color.to_html()] = true
	assert_true(colours.size() >= 4, "the houses' plaster comes in several tints (%d)" % colours.size())
	assert_eq(PackMaterials.material("vkit/plaster", 0), PackMaterials.material("vkit/plaster", 0),
		"the same house always takes the same material")


func test_variant_texture_sets_all_load() -> void:
	var vkit := (Look.textures().get("themes", {}) as Dictionary).get("vkit", {}) as Dictionary
	assert_eq((vkit["plaster"] as Dictionary).get("variants"), (vkit["plaster_core"] as Dictionary).get("variants"),
		"a house's walls and its core take the same variants, in the same order")
	var listed := 0
	for set_name: String in vkit:
		var variants := (vkit[set_name] as Dictionary).get("variants", []) as Array
		for n in variants.size():
			var v := variants[n] as Dictionary
			assert_true(bool(v.get("triplanar", false)) and float(v.get("tile_world_units", 0.0)) > 0.0,
				"%s variant %d is mapped by world position at a real size" % [set_name, n])
			var m := PackMaterials.material("vkit/%s" % set_name, n + 1)
			assert_true(m.albedo_texture != null and m.normal_texture != null and m.roughness_texture != null,
				"%s variant %d has its albedo, normal and ARM maps" % [set_name, n])
			assert_true(m.uv1_triplanar and m.ao_enabled, "%s variant %d is triplanar with occlusion" % [set_name, n])
			listed += 1
	assert_true(listed >= 40, "the village sets list their variants (%d)" % listed)


func test_pack_surfaces_come_out_lit_on_their_own_uvs() -> void:
	var b := _board()
	var swapped := PackMaterials.apply(b)
	assert_true(swapped > 0, "the house's pack surfaces are swapped (%d)" % swapped)
	var plaster := PackMaterials.material("vkit/plaster")
	assert_true(plaster != null and plaster.albedo_texture != null, "plaster has its albedo")
	assert_true(plaster.normal_enabled and plaster.normal_texture != null, "and its normal map")
	assert_true(plaster.roughness_texture != null and plaster.ao_enabled, "and its ORM map's roughness and occlusion")
	assert_false(plaster.uv1_triplanar, "on the model's own UVs")
	assert_true(PackMaterials.material("vkit/plaster_core").uv1_triplanar, "the core, built without UVs, by world position")
	assert_true(PackMaterials.material("vpro/props_v").vertex_color_use_as_albedo, "the props' tinted trims keep their colours")
	assert_eq(PackMaterials.material("kit/plaster"), null, "the engine's own sets stay as they are")
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat != null and mat.has_meta("surface") and str(mat.get_meta("surface")).begins_with("vkit/"):
				assert_true(mat is StandardMaterial3D, "%s is lit, not cel" % mat.get_meta("surface"))
	b.free()


func test_the_props_the_pack_replaces_are_the_packs() -> void:
	var art := ((SetDressing.catalog()["models3d"] as Dictionary)["art"]) as Dictionary
	for id: String in ["barrel", "crate", "chest", "table", "bed", "bookshelf", "wagon"]:
		var model := str(art[id])
		assert_true(model.begins_with("pp_"), "%s is the pack's (%s)" % [id, model])
		var piece := ModelPiece.instance(model)
		var surfaces := _surfaces(piece)
		assert_true(surfaces.keys().any(func(s: String) -> bool: return s.begins_with("vpro/")), "%s wears the pack's trims" % id)
		piece.free()


func _surfaces(root: Node) -> Dictionary:
	var out := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m != null and m.has_meta("surface"):
				out[str(m.get_meta("surface"))] = true
	return out


func test_houses_are_rebuilt_at_their_natural_size() -> void:
	var b := _board()
	var before := (b.buildings[0]["rect"] as Rect2i)
	assert_eq(NaturalHouses.rebuild(b), 1, "the village house is rebuilt")
	var house := b.buildings[0]
	assert_eq(house["rect"], before, "on the same squares")
	assert_true(is_equal_approx(float(house["height"]), 2 * NaturalHouses.STOREY), "a 12-square house is two pack storeys")
	var walls := house["walls"] as MeshInstance3D
	assert_true(walls != null and walls.mesh.get_aabb().size.x > before.size.x, "its walls stand round the outside of its squares")
	var roof: Node = (house["upper"] as Node3D).get_node_or_null("Roof")
	assert_true(roof != null, "under a pack roof")
	for slot: Array in NaturalHouses._slots(0.0, 4.0, []):
		var w := float(slot[1])
		assert_true(w > NaturalHouses.PIECE * 0.7 and w < NaturalHouses.PIECE * 1.35, "each piece near its own 2 m (%.2f)" % w)
	b.free()
