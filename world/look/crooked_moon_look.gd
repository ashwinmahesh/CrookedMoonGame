class_name CrookedMoonLook
extends CampaignLook
## The Crooked Moon's scenery for the engine's world code (CampaignLook, named in data/campaign.json). Plan G8: the Crooked
## Moon in every sky (data/campaign.json's painted moon_face), the Oak of Many Faces, the Crooked House's bend and morph, the
## Ghostlight Express, the Wicker Man, the Crooked Tree and its barrow. The pieces are built in code, keyed through the props
## catalog (a catalog `ids` entry with a `set_piece`, art/sprites/props/catalog.json) so any map can use them; the entry's
## `art` is the picture that stands in where the piece cannot be built.


## Coming out of the mist between the Ghostlight Express's cars into the next one (E23): the Narrator says the car has changed before the
## car's own words. The place the party left is still the story's `location` here (LocationView sets the new one just after).
## The places whose houses warp (the catalog's building_kit.bend.morph names them too).
const MORPHING: Array[String] = ["druskenvald_estate"]


func dress_place(view: LocationView) -> void:
	if CrookedMoonCampaign.is_car(view.loc_id):
		ExpressWindows.hang(view.board, view.board)   # the Shroud streams past the cars' windows
	if view.st.location == CrookedMoonCampaign.limbo_place() and CrookedMoonCampaign.is_car(view.loc_id) \
			and not view.st.visited.has(view.loc_id):   # (back out of the mist into the car it left, nothing has changed)
		view._say("switcheroo:arrive")
	RealNature.strew(view)   # the realistic rocks, roots and ferns of a wild place (art/nature/real_nature.json)
	TerrainPlace.dress(view)   # Terrain3D ground and land past the edge (art/overworld/terrain_places.json)


## The catalog's `set_piece` entries, planted over the middle of the squares the prop spans: "oak" is the Oak of Many Faces
## (OakOfManyFaces) and "crooked_tree" the Wytchwood's Crooked Tree (CrookedTree), each built in code (`handled`); "barrow_glow"
## and "wicker_man" only add their light and leave the catalog's own picture (the barrow, the painted Wicker Man) to be drawn, and
## "clocktower" adds its lit clock faces to the catalog's bell tower (Clocktower), and "small:<kind>" builds one of the small things
## of Act 1's rooms from a few meshes (SmallProps).
## and "wicker_man" only add their light and leave the catalog's own picture (the barrow, the painted Wicker Man) to be drawn.
## "real" is one of the scanned rocks and roots of RealNature in the Modern finish (the catalog's art in Classic).
func place_special(_art: String, board: ArenaBoard, root: Node3D, cell: Vector2i, spec: Dictionary, look: Dictionary) -> Dictionary:
	var piece := str(look.get("set_piece", ""))
	if piece == "":
		return {}
	var centre: Variant = SetDressing.span_centre(board, spec)
	var at: Vector3 = centre as Vector3 if centre != null else board.cell_center(cell)
	if piece.begins_with("small:"):
		var made := SmallProps.build(piece.substr(6), root, at, ModelPiece.hash_cell(cell), ModelPiece.backing_side(board, cell))
		if made != null:
			return {"handled": true, "node": root}
		return {}
	match piece:
		"real":
			# One of Poly Haven's scanned pieces in its own materials (RealNature), picked by square from the entry's `real`.
			var picks := look.get("real", []) as Array
			if not picks.is_empty() and Look.modern():
				var seed_ := ModelPiece.hash_cell(cell)
				RealNature.build(root, str(picks[seed_ % picks.size()]), Vector3(at.x, board.ground_y(Vector2(at.x, at.z)), at.z), seed_)
				return {"handled": true, "node": root}
		"oak":
			OakOfManyFaces.build(root, at, ModelPiece.hash_cell(cell))
			return {"handled": true, "node": root}
		"crooked_tree":
			CrookedTree.build(root, at, ModelPiece.hash_cell(cell))
			return {"handled": true, "node": root}
		"barrow_glow":
			root.add_child(SetPieceLight.make("BarrowGlow", at + Vector3(0.0, 0.9, 0.4), Look.color("moon_green"), 1.1, 6.5, root))
		"wicker_man":
			root.add_child(SetPieceLight.make("WickerLantern", at + Vector3(0.0, 5.2, 0.5), Look.color("flame"), 0.9, 9.0, root))
		"clocktower":
			Clocktower.dress(root, at)
	return {}


## The Crooked House turning (plan G8; the house's gate talk ends with `set crooked_house_turned`): the estate's houses are built with
## a tidy shape too (the catalog's building_kit.bend.morph), tidy until the house has turned and again once the manor is restored; the
## change plays as a warp that overshoots and settles (BuildingMorph). Asked every quarter second.
func refresh(view: LocationView) -> void:
	if view.board != null and view.loc_id in MORPHING:
		var ruined := StoryConditions.check("flag.crooked_house_turned and not flag.druskenvald_manor_restored", view.st)
		BuildingMorph.follow(view.board, 0.0 if ruined else 1.0, 2.8)


## A melee blow: Ashwin's picks per kind of blow (MeleeHitFx, data/melee_fx.json) in place of the engine's crescent.
func melee_hit(fx: SpellFx, cue: Dictionary, attacker: CombatToken, target: CombatToken, critical: bool, kind: String) -> bool:
	return MeleeHitFx.play(fx, cue, attacker, target, critical, kind)
