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
	if view.st.location == CrookedMoonCampaign.limbo_place() and CrookedMoonCampaign.is_car(view.loc_id):
		view._say("switcheroo:arrive")


## The catalog's `set_piece` entries: "oak" is the Oak of Many Faces (OakOfManyFaces), planted over the middle of the squares
## the prop spans.
func place_special(_art: String, board: ArenaBoard, root: Node3D, cell: Vector2i, spec: Dictionary, look: Dictionary) -> Dictionary:
	match str(look.get("set_piece", "")):
		"oak":
			var centre: Variant = SetDressing.span_centre(board, spec)
			var at: Vector3 = centre as Vector3 if centre != null else board.cell_center(cell)
			OakOfManyFaces.build(root, at, ModelPiece.hash_cell(cell))
			return {"handled": true, "node": root}
	return {}
