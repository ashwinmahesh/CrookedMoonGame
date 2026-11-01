class_name SetPieceLight
extends RefCounted
## A set piece's own light (a glow in a tree's boughs, a barrow's mouth, a giant's chest): a soft omni light with no shadow that
## breathes a little, so a place's lamp shadow budget never pays for it.


## `energy` is the light's middle; it swells and sinks about a third either way. `holder` owns the tween.
static func make(light_name: String, at: Vector3, colour: Color, energy: float, range_: float, holder: Node) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = light_name
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = range_
	l.shadow_enabled = false
	l.position = at
	l.set_meta("light_kind", "lantern")
	l.set_meta("no_shadow", true)
	var breathe := func() -> void:
		var t := holder.create_tween().set_loops()
		t.tween_property(l, "light_energy", energy * 1.35, 2.2).set_trans(Tween.TRANS_SINE)
		t.tween_property(l, "light_energy", energy * 0.7, 2.7).set_trans(Tween.TRANS_SINE)
	if holder.is_inside_tree():
		breathe.call()
	else:
		holder.tree_entered.connect(breathe, CONNECT_ONE_SHOT)   # (the board is put in the scene after it is built)
	return l
