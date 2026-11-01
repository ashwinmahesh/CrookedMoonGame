class_name ExpressWindows
extends RefCounted
## The Ghostlight Express's windows (plan 8.4, G8): the cars are closed boxes, so nothing showed the Shroud streaming past. A
## window painting (art/props/express/train_window.png: a deco frame, curtains, thick teal smoke behind the glass) is laid on the
## inner face of a car's far (north) wall as a glowing decal, every third square (above any booth or counter there). Cosmetic only:
## no square, prop or door is claimed or moved.

const PICTURE := "res://art/props/express/train_window.png"
## What shines of it (the smoke and the lantern; the frame stays dark).
const GLOW := "res://art/props/express/train_window_glow.png"
const STEP := 3
## A window's size on the wall (width, depth of the projection, height) and how high its middle hangs over the floor.
const SIZE := Vector3(1.3, 0.5, 1.75)
const MID := 1.05


## Hangs the windows under `parent`; returns the node holding them, or null where there is no picture or no wall to hang them on.
static func hang(board: ArenaBoard, parent: Node3D) -> Node3D:
	if not ResourceLoader.exists(PICTURE):
		return null
	var tex := load(PICTURE) as Texture2D
	if tex == null:
		return null
	var glow := load(GLOW) as Texture2D if ResourceLoader.exists(GLOW) else tex
	var holder := Node3D.new()
	holder.name = "ShroudWindows"
	var g := board.grid
	var x := 3
	while x < g.width - 2:
		var wall := Vector2i(x, 0)
		var room := Vector2i(x, 1)
		if g.has_flag(wall, CombatGrid.WALL) and not g.has_flag(room, CombatGrid.WALL):
			var d := Decal.new()
			d.name = "Window"
			d.texture_albedo = tex
			d.texture_emission = glow
			d.emission_energy = 1.6
			var out := Vector3(0, 0, 1)   # into the room, off the wall's inner face
			d.transform = Transform3D(Basis(Vector3.RIGHT, out, Vector3.RIGHT.cross(out)),
				board.cell_center(wall) + Vector3(0.0, MID, 0.5))   # the inner face lies half a square south of the wall square's middle
			d.size = SIZE
			d.upper_fade = 0.2
			d.lower_fade = 0.2
			holder.add_child(d)
		x += STEP
	if holder.get_child_count() == 0:
		holder.free()
		return null
	parent.add_child(holder)
	return holder
