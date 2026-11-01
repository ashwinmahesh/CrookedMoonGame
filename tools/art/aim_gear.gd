extends Node
## Hand sockets for held gear, one per figure with `gear` slots: each rig holds its hands its own way at idle, so a
## blade turned to sit right in Rook's hand points elsewhere in another's (out sideways, through the floor). This
## measures each figure's idle hands and prints the `sockets` that turn a held long piece (the longsword) to point as
## it does in Rook's right hand: ahead and down. The left hand gets the mirror. Figures within a few degrees already
## get none.
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/art/aim_gear.tscn
## Prints a JSON line per figure ("SOCKETS <id> {...}"); copy them into the figure entries of art/figures/manifest.json.

const REFERENCE := "rook_coldwake"
const PIECE := "longsword"
const ENOUGH := 8.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var figures := ArtPaths.json(FigureModels.MANIFEST_JSON).get("figures", {}) as Dictionary
	var turn := ModelFigure._euler(FigureModels.part(PIECE).get("turn"))
	var ref := await _held(REFERENCE, "RightHand", turn)
	var aim := ref[1] as Vector3
	print("reference %s: ahead %.2f up %.2f out %.2f" % [REFERENCE, aim.x, aim.y, aim.z])
	for id: String in figures:
		if ((figures[id] as Dictionary).get("gear", []) as Array).is_empty():
			continue
		var sockets := {}
		for hand: String in ["RightHand", "LeftHand"]:
			var right := hand == "RightHand"
			var t := turn if right else ModelFigure._euler(FigureModels.mirrored(FigureModels.part(PIECE)).get("turn"))
			var got := await _held(id, hand, t)
			if got.is_empty():
				continue
			var want := Vector3(aim.x, aim.y, aim.z if right else -aim.z)
			var frame := got[2] as Array
			var f0 := frame[0] as Vector3
			var f1 := frame[1] as Vector3
			var f2 := frame[2] as Vector3
			var now := got[1] as Vector3
			var off := rad_to_deg(now.angle_to(want))
			if off < ENOUGH:
				continue
			var w := f0 * want.x + f1 * want.y + f2 * want.z
			var n := f0 * now.x + f1 * now.y + f2 * now.z
			var axis := n.cross(w).normalized()
			var r := Basis(axis, n.angle_to(w))
			var h := got[0] as Basis
			var e := (h.inverse() * r * h).get_euler()
			sockets[hand] = {"turn": [roundi(rad_to_deg(e.x)), roundi(rad_to_deg(e.y)), roundi(rad_to_deg(e.z))]}
			print("   %s %s: %.0f degrees off" % [id, hand, off])
		print("SOCKETS %s %s" % [id, JSON.stringify(sockets)])
	get_tree().quit(0)


## [the hand's basis, the piece's long axis as (ahead, up, out to that figure's right), [ahead, up, right] in the
## world] at the middle of `id`'s idle; [] without the bones.
func _held(id: String, hand: String, turn: Basis) -> Array:
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(id), CombatToken.height_for(id)) as ModelFigure
	add_child(fig)
	await get_tree().process_frame
	var out := []
	var sk := fig.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var players := fig.model.find_children("*", "AnimationPlayer", true, false)
	var b := FigureModels.bone(sk, hand)
	var foot := FigureModels.bone(sk, "LeftFoot")
	var toe := FigureModels.bone(sk, "LeftToeBase")
	if b >= 0 and foot >= 0 and toe >= 0 and not players.is_empty() and fig.has_role("idle"):
		var player := players[0] as AnimationPlayer
		player.play(str((fig._roles["idle"] as Array)[0]["name"]))
		player.seek(player.current_animation_length * 0.5, true)
		var ahead := sk.global_transform * sk.get_bone_global_pose(toe).origin - sk.global_transform * sk.get_bone_global_pose(foot).origin
		ahead.y = 0.0
		ahead = ahead.normalized()
		var right := ahead.cross(Vector3.UP).normalized()
		var h := (sk.global_basis * sk.get_bone_global_pose(b).basis).orthonormalized()
		var d := (h * turn * Vector3.UP).normalized()
		out = [h, Vector3(d.dot(ahead), d.y, d.dot(right)), [ahead, Vector3.UP, right]]
	fig.queue_free()
	return out
