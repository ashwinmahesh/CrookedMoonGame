class_name CrookedTree
extends RefCounted
## The Crooked Tree (plan 8.4, G8): the hag's tree in the Wytchwood, a bare dead tree grown huge, stout and leaning, a crooked
## grin carved into its bark with the cuts glowing amber, and an ember light breathing in its boughs. Built in code through
## CampaignLook.place_special for any prop whose catalog entry says `"set_piece": "crooked_tree"`; cosmetic only.

const TREE := "dead_a"
const GROW := Vector3(3.0, 2.6, 3.0)
const GRIN := "res://art/props/crooked_tree/tree_grin.png"


static func build(parent: Node3D, centre: Vector3, seed_: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = "CrookedTree"
	holder.position = centre
	holder.set_meta("set_piece", "crooked_tree")
	holder.set_meta("nature", true)
	parent.add_child(holder)
	var trunk := Flora.instance(TREE, 1.0)
	trunk.scale = GROW
	trunk.name = "Trunk"
	trunk.rotation = Vector3(deg_to_rad(5.0), float(seed_ % 360) * PI / 180.0, deg_to_rad(-7.0))   # a lean either way: crooked
	holder.add_child(trunk)
	if ResourceLoader.exists(GRIN) and trunk.mesh != null:
		var grin := load(GRIN) as Texture2D
		for i in 2:
			var y := 0.55 + 0.5 * float(i)
			var round_ := OakOfManyFaces.trunk_at(trunk.mesh, y)
			var angle := PI * 0.75 + float(i) * 0.9
			var out := Vector3(cos(angle), 0.0, sin(angle))
			var at := Vector3(round_.centre.x * GROW.x, y * GROW.y, round_.centre.y * GROW.z) + out * round_.radius * GROW.x
			holder.add_child(OakOfManyFaces.decal(grin, at, out, 1.5 - 0.5 * float(i), Color(1.0, 0.8, 0.5), 1.1))
	holder.add_child(SetPieceLight.make("CrookedGlow", Vector3(0, 2.6, 0), Look.color("ember"), 0.55, 8.0, holder))
	return holder
