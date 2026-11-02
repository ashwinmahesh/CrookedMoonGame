class_name CrookedMoonLook
extends CampaignLook
## The Crooked Moon's scenery for the engine's world code (CampaignLook, named in data/campaign.json). Plan G8: the Crooked
## Moon in every sky (data/campaign.json's painted moon_face), the Oak of Many Faces, the Crooked House's bend and morph, the
## Ghostlight Express, the Wicker Man, the Crooked Tree and its barrow. The pieces are built in code, keyed through the props
## catalog (a catalog `ids` entry with a `set_piece`, art/sprites/props/catalog.json) so any map can use them; the entry's
## `art` is the picture that stands in where the piece cannot be built.


## Coming out of the mist between the Ghostlight Express's cars into the next one (E23): the Narrator says the car has changed before the
## car's own words. The place the party left is still the story's `location` here (LocationView sets the new one just after).
func dress_place(view: LocationView) -> void:
	if CrookedMoonCampaign.is_car(view.loc_id):
		ExpressWindows.hang(view.board, view.board)   # the Shroud streams past the cars' windows
	if view.st.location == CrookedMoonCampaign.limbo_place() and CrookedMoonCampaign.is_car(view.loc_id):
		view._say("switcheroo:arrive")


## The catalog's `set_piece` entries, planted over the middle of the squares the prop spans: "oak" is the Oak of Many Faces
## (OakOfManyFaces) and "crooked_tree" the Wytchwood's Crooked Tree (CrookedTree), each built in code (`handled`); "barrow_glow"
## and "wicker_man" only add their light and leave the catalog's own picture (the barrow, the painted Wicker Man) to be drawn, and
## "clocktower" adds its lit clock faces to the catalog's bell tower (Clocktower), and "small:<kind>" builds one of the small things
## of Act 1's rooms from a few meshes (SmallProps).
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
