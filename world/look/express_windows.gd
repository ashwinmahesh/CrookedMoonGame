class_name ExpressWindows
extends RefCounted
## The Ghostlight Express's windows (plan 8.4, G8): the cars are closed boxes, so nothing showed the Shroud streaming past. A
## deco window painting (art/props/express/train_window.png: a brass and ebony frame, curtains, the lantern's reflection) is hung
## as a flat picture on the inner face of a car's far (north) wall, every third square (above any booth or counter there), with a
## glass mask over its panes named `Decal_glass`: the engine's WindowView lays the map's moving `window_view` (three banks of
## Shroud smoke streaming past) over the glass, the frame and sash bars showing through. A car map without a `window_view` keeps the
## painting's own still smoke. Cosmetic only: no square, prop or door is claimed or moved.

const PICTURE := "res://art/props/express/train_window.png"
const GLASS := "res://art/props/express/train_window_glass.png"
const STEP := 3
## A window's height on the wall and how high its middle hangs over the floor (units).
const HEIGHT := 1.75
const MID := 1.05


## Hangs the windows under `parent`; returns the node holding them, or null where there is no picture or no wall to hang them on.
static func hang(board: ArenaBoard, parent: Node3D) -> Node3D:
	if not ResourceLoader.exists(PICTURE):
		return null
	var tex := load(PICTURE) as Texture2D
	var glass_tex := load(GLASS) as Texture2D if ResourceLoader.exists(GLASS) else null
	if tex == null:
		return null
	var spec := WindowView.spec_of(board)
	var pixel := HEIGHT / float(tex.get_height())
	var holder := Node3D.new()
	holder.name = "ShroudWindows"
	var g := board.grid
	var x := 3
	while x < g.width - 2:
		var wall := Vector2i(x, 0)
		var room := Vector2i(x, 1)
		if g.has_flag(wall, CombatGrid.WALL) and not g.has_flag(room, CombatGrid.WALL):
			var win := Sprite3D.new()
			win.name = "Window"
			win.texture = tex
			win.pixel_size = pixel
			win.shaded = false
			win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			win.position = board.cell_center(wall) + Vector3(0.0, MID, 0.51)   # just off the wall's inner face (half a square from the middle)
			holder.add_child(win)
			if glass_tex != null:
				var glass := Sprite3D.new()
				glass.name = "Decal_glass"
				glass.texture = glass_tex
				glass.pixel_size = pixel
				glass.shaded = false
				glass.modulate = Color(1, 1, 1, 0)   # only its picture is wanted: the view reads it as the mask
				glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				win.add_child(glass)
				if not spec.is_empty():
					WindowView.dress_with(win, spec, "window_express")
		x += STEP
	if holder.get_child_count() == 0:
		holder.free()
		return null
	parent.add_child(holder)
	return holder
