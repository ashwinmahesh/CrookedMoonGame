class_name Clocktower
extends RefCounted
## Wickermoor's clocktower (plan 8.4, G8): the village's landmark, the engine's bell tower with a lit
## clock face on each of its four sides, drawn in code (a warm disc, a dark rim, the hours and two hands stopped just short of midnight)
## and a warm light at the clock. Built through CampaignLook.place_special for a prop whose catalog entry says `"set_piece": "clocktower"`;
## the tower itself is the entry's `art`. Cosmetic only: no square is claimed or moved.

const FACE_SIZE := 128
const HEIGHT := 7.1 * 0.8   ## where the clock sits on the engine's bell tower (7.1 units tall) when there is no model to measure
const OFFSET := 0.78                ## how far a face stands out from the middle of the tower's squares
const RADIUS := 0.55


static var _face: ImageTexture


## The four faces and the light, under `parent`, over `centre` (the middle of the squares the tower spans). The tower's own model is
## drawn after this runs, so the faces are fitted to it a moment later: on its middle, four fifths of the way up.
static func dress(parent: Node3D, centre: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "ClockFaces"
	holder.position = centre
	parent.add_child(holder)
	for i in 4:
		var s := Sprite3D.new()
		s.name = "Clock"
		s.texture = face()
		s.pixel_size = RADIUS * 2.0 / float(FACE_SIZE)
		s.shaded = false
		s.double_sided = false
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := float(i) * PI / 2.0
		s.rotation.y = a
		s.position = Vector3(sin(a), 0.0, cos(a)) * OFFSET
		holder.add_child(s)
	holder.add_child(SetPieceLight.make("ClockGlow", Vector3.ZERO, Look.color("wick"), 1.2, 9.0, holder))
	_fit.call_deferred(holder, parent)


## Moves the faces to the tower's middle and four fifths up its height, once its model is there.
static func _fit(holder_: Variant, parent_: Variant) -> void:
	if not is_instance_valid(holder_) or not is_instance_valid(parent_):
		return   # (the place was freed before the deferred call)
	var holder := holder_ as Node3D
	var parent := parent_ as Node3D
	if not holder.is_inside_tree():
		return
	var low := INF
	var high := -INF
	var sum := Vector3.ZERO
	var n := 0
	for m in parent.find_children("Model_*", "Node3D", false, false):
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var box := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			low = minf(low, box.position.y)
			high = maxf(high, box.end.y)
			sum += box.get_center()
			n += 1
	if n == 0:
		holder.position.y += HEIGHT   # no model (a headless run): where the engine's tower would have it
		return
	var mid := sum / float(n)
	holder.global_position = Vector3(mid.x, low + (high - low) * 0.8, mid.z)


## The clock face picture: a lit disc, a dark rim and twelve ticks, the hands at eleven fifty-five.
static func face() -> ImageTexture:
	if _face != null:
		return _face
	var n := FACE_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) / 2.0
	var lit := Look.color("wick").lerp(Color.WHITE, 0.25)
	var rim := Look.color("ink")
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (n / 2.0)
			if d > 1.0:
				continue
			img.set_pixel(x, y, rim if d > 0.9 else lit.darkened(0.25 * d))
	for h in 12:
		var a := float(h) * TAU / 12.0
		for r in range(int(n * 0.36), int(n * 0.44)):
			_dot(img, c + Vector2(sin(a), -cos(a)) * r, rim, 1)
	_hand(img, c, TAU * 55.0 / 60.0, n * 0.42, rim)   # the minute hand, at the five to
	_hand(img, c, TAU * 11.92 / 12.0, n * 0.27, rim)  # the hour hand, nearly at twelve
	_face = ImageTexture.create_from_image(img)
	return _face


static func _hand(img: Image, c: Vector2, a: float, length: float, col: Color) -> void:
	for r in range(0, int(length)):
		_dot(img, c + Vector2(sin(a), -cos(a)) * float(r), col, 2)


static func _dot(img: Image, p: Vector2, col: Color, size: int) -> void:
	for dy in range(-size / 2, size / 2 + 1):
		for dx in range(-size / 2, size / 2 + 1):
			var x := int(p.x) + dx
			var y := int(p.y) + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)
