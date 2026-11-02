class_name OverworldScreen
extends CanvasLayer
## The travel map as real land (Ashwin 2026-11-02, "Sure do it": the 3D overworld in place of the painted map). The game
## opens it instead of TravelScreen when the party sets out from, or looks round from, a place the overworld holds (covers:
## every place of the travel map now); the painted map is a button away. It keeps the travel
## rules exactly: the places shown are the ones the party knows (Travel.known), the way and its hours are Travel.route's,
## and Set out hands the destination to the game's own travel() (the hours, the road's encounters and the arrival), after
## the party's lantern has walked the road on the land. The land is OverworldView, in a viewport and world of its own.

signal travel_chosen(place_id: String)
signal closed
## The painted map instead (the game opens TravelScreen).
signal painted_map_wanted

## Metres the party's lantern walks a second on the land when it sets out, and the shortest and longest the walk is drawn
## for (seconds).
const WALK_SPEED := 200.0
const WALK_MIN := 2.5
const WALK_MAX := 5.0
## How far the camera hangs back from what it looks at (metres): closest, farthest and at first.
const NEAR := 70.0
const FAR := 1500.0
## How far right of the middle (a share of the camera's distance) what it frames sits, clear of the panel on the right.
const PANEL_SHIFT := 0.4
## The pad: how far the left stick pans the land a second at a full lean (a share of the camera's distance), the right
## stick's share of a push, and how much a trigger zooms.
const PAD_PAN := 0.8
const PAD_SCROLL := 0.0008
const PAD_ZOOM := 1.25

var st: StoryState
var here := ""
var setting_out := false
var view: OverworldView
var _viewport: SubViewport
var _info: VBoxContainer
var _target := ""
var _focus := Vector2.ZERO
var _distance := 260.0
var _walking := false
var _drag_from := Vector2(-1, -1)
var _holder: SubViewportContainer
var _hover := ""   ## the place the D-pad has lit (A plans the way to it)


## Whether the overworld holds this travel place (and so opens in place of the painted map from there).
static func covers(place_id: String) -> bool:
	if place_id == "":
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OverworldLand.CONFIG))
	if not parsed is Dictionary or not bool((parsed as Dictionary).get("enabled", true)):
		return false
	return ((parsed as Dictionary).get("places", {}) as Dictionary).has(place_id)


func open(state: StoryState, from_place: String, can_travel: bool) -> void:
	st = state
	here = from_place
	setting_out = can_travel
	layer = 20
	var root := Control.new()
	root.name = "Overworld"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var holder := SubViewportContainer.new()
	holder.name = "Land"
	holder.stretch = true
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.gui_input.connect(_on_land_input)
	# The pad (PadNav): the land is a choice of its own that it opens on, and A plans the way to the place lit.
	holder.set_meta(&"pad_target", true)
	holder.set_meta(&"pad_first", true)
	holder.set_meta(&"pad_accept", _pad_pick)
	root.add_child(holder)
	_holder = holder
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	holder.add_child(_viewport)
	view = OverworldView.new()
	for p in Travel.known(st):
		view.shown[str(p["id"])] = true
	view.start_place = here
	_viewport.add_child(view)
	_focus = view.party_at
	_frame()
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var ps := UiKit.style("ui_black", "gilt", 2, 0.86)
	ps.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -360
	panel.offset_top = 24
	panel.offset_bottom = -24
	panel.offset_right = -24
	root.add_child(panel)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 8)
	panel.add_child(_info)
	_show_info()


## The places the party knows that the land holds, but where it is now.
func destinations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in Travel.known(st):
		if str(p["id"]) != here and view.has_place(str(p["id"])):
			out.append(p)
	return out


## Chooses a place to go: its name lit on the land, the camera framing the way there, the way and its hours in the panel.
func select(place_id: String) -> void:
	if _walking:
		return
	_target = place_id
	view.light_place(place_id)
	if view.has_place(place_id):
		var a := view.party_at
		var b := view._place_at(place_id)
		_focus = a.lerp(b, 0.5)
		_distance = clampf(a.distance_to(b) * 1.1 + 120.0, NEAR, FAR)
		_frame()
	_hover = place_id
	_show_info()


func _frame() -> void:
	_focus = _focus.clamp(Vector2.ZERO, Vector2(view.land.size, view.land.size))
	view.look_from(_focus + Vector2(_distance * PANEL_SHIFT, 0.0), _distance * 0.62, _distance)


func _show_info() -> void:
	for c in _info.get_children():
		_info.remove_child(c)
		c.queue_free()
	var cur := Travel.place(here)
	_info.add_child(UiKit.label("You are at" if here != "" else "You are", 14, "parchment"))
	var where := UiKit.header(str(cur.get("name", "off the roads")))
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.custom_minimum_size = Vector2(300, 0)
	_info.add_child(where)
	_info.add_child(UiKit.label("Day %d · %s · %s" % [st.day, Calendar.clock(st.minute_of_day),
		"night" if st.is_night() else "day"], 15, "vellum"))
	_info.add_child(UiKit.divider(300))
	var list := VBoxContainer.new()
	list.name = "Places"
	list.add_theme_constant_override("separation", 4)
	for p in destinations():
		var id := str(p["id"])
		var b := UiKit.button(str(p["name"]), func() -> void: select(id), 15)
		b.name = "Place_" + id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(b)
	if list.get_child_count() == 0:
		list.add_child(UiKit.label("No road you know leads on from here.", 15, "vellum", 300))
	_info.add_child(list)
	if _target != "":
		_info.add_child(UiKit.divider(300))
		var to := Travel.place(_target)
		var t := UiKit.title(str(to.get("name", _target)))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(300, 0)
		_info.add_child(t)
		if str(to.get("summary", "")) != "":
			_info.add_child(UiKit.label(str(to["summary"]), 14, "vellum", 300))
		var legs: Array[Dictionary] = Travel.route(here, _target, st) if here != "" else []
		if legs.is_empty():
			_info.add_child(UiKit.label("No road you know leads there from here.", 15, "gilt", 300))
		else:
			var h := Travel.hours(legs)
			var arrive := (st.minute_of_day + roundi(h * 60.0)) % (24 * 60)
			var names: Array[String] = []
			for l in legs:
				var rn := str((l["road"] as Dictionary).get("name", "a road"))
				if names.is_empty() or names.back() != rn:
					names.append(rn)
			_info.add_child(UiKit.label(TravelScreen.route_line(names), 14, "parchment", 300))
			_info.add_child(UiKit.label("%s hours on the road, arriving about %s" % [TravelScreen._hours_text(h),
				Calendar.clock(arrive)], 16, "gilt_light", 300))
			if Calendar.is_night(arrive):
				_info.add_child(UiKit.label("After dark: the roads are worse at night.", 14, "rose", 300))
			var go := UiKit.button("Set out", func() -> void: _set_out(legs), 18, "map")
			go.name = "SetOut"
			go.disabled = not setting_out
			if not setting_out:
				go.tooltip_text = "Set out from a road out of town."
			_info.add_child(go)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_child(spacer)
	var how := UiKit.label("", 13, "parchment", 300)
	PadGlyphs.hint(how, "Click a place's name to plan a journey. Wheel: zoom · Drag: pan",
		"D-pad: a place · {a} plans a journey · {lt} {rt}: zoom · left stick: pan")
	_info.add_child(how)
	var painted := UiKit.button("The painted map", func() -> void:
		painted_map_wanted.emit()
		queue_free(), 15)
	painted.name = "PaintedMap"
	_info.add_child(painted)
	var close := UiKit.button("Close", func() -> void:
		closed.emit()
		queue_free(), 15)
	close.name = "Close"
	_info.add_child(close)


## The lantern walks the way on the land (each leg's road, as far as the land holds it), the camera behind it, then the
## game takes the journey on.
func _set_out(legs: Array[Dictionary]) -> void:
	if _walking:
		return
	_walking = true
	(_info.get_parent() as Control).visible = false   # the land alone while the party walks
	var path := PackedVector2Array()
	for l in legs:
		var line := view.land.road_line(str((l["road"] as Dictionary).get("id", "")), str(l["from"]))
		path.append_array(line)
	if path.size() >= 2:
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		var seconds := clampf(length / WALK_SPEED, WALK_MIN, WALK_MAX)
		_distance = 160.0
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void: _walk_to(path, t * length), 0.0, 1.0, seconds)
		await tween.finished
	var to := _target
	travel_chosen.emit(to)
	queue_free()


## Puts the lantern `along` metres down `path`, facing the way it goes, and the camera after it.
func _walk_to(path: PackedVector2Array, along: float) -> void:
	var left := along
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if left <= seg or i == path.size() - 1:
			var p := path[i - 1].lerp(path[i], clampf(left / maxf(seg, 0.001), 0.0, 1.0))
			view.set_party(p, path[i] - path[i - 1])
			_focus = p
			_frame()
			return
		left -= seg


## Clicks on a place's name choose it; the wheel zooms; dragging pans.
func _on_land_input(event: InputEvent) -> void:
	if _walking:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance * (0.88 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14), NEAR, FAR)
			_frame()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = mb.position
	elif mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _drag_from.distance_to(mb.position) < 6.0:
			var id := place_at_screen(mb.position)
			if id != "" and id != here:
				select(id)
		_drag_from = Vector2(-1, -1)
	var mm := event as InputEventMouseMotion
	if mm != null and _drag_from.x >= 0.0 and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_focus -= Vector2(mm.relative.x, mm.relative.y) * _distance * 0.0016
		_frame()


## The place whose name is drawn nearest `at` (screen pixels, within 70), or "".
func place_at_screen(at: Vector2) -> String:
	var best := ""
	var best_d := 70.0
	for id: String in view.labels:
		var label := view.labels[id] as Label3D
		if view.camera.is_position_behind(label.global_position):
			continue
		var d := view.camera.unproject_position(label.global_position).distance_to(at)
		if d < best_d:
			best_d = d
			best = id
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel") and not _walking:
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()


# --- The pad (PadNav, U6) --------------------------------------------------------------------------
# The same as TravelScreen's: the D-pad goes from place to place, A plans the way, the triggers zoom, the right stick
# pans; here the left stick pans too (held down it keeps the land moving).

func _process(delta: float) -> void:
	if _walking or _holder == null or PadNav.current == null or not PadNav.current.pad:
		return
	var owner_ := get_viewport().gui_get_focus_owner()
	if owner_ != null and owner_ != _holder:
		return   # focus is in the panel: the stick moves it there
	var lean := Vector2.ZERO
	for d: int in Input.get_connected_joypads():
		var v := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if v.length() > lean.length():
			lean = v
	if lean.length() < 0.2:
		return
	_focus += lean * _distance * PAD_PAN * delta
	_frame()


## On the land, the D-pad goes from place to place: the nearest known one that way (north is up). With none that way it
## leaves the land for the side panel. A left-stick lean is the land's pan, so it moves no focus.
func pad_step(f: Control, dir: Vector2i) -> bool:
	if f != _holder:
		return false
	if _walking:
		return true
	if PadNav.current != null and PadNav.current.get(&"_dpad_held") == Vector2i.ZERO:
		return true
	var now := _hover if _hover != "" else (_target if _target != "" else here)
	var from := view._place_at(now) if now != "" and view.has_place(now) else _focus
	var best := ""
	var best_s := INF
	for p in Travel.known(st):
		var id := str(p["id"])
		if id == now or not view.has_place(id):
			continue
		var v := view._place_at(id) - from
		var along := v.dot(Vector2(dir))
		var side := absf(v.dot(Vector2(dir.y, dir.x)))
		if along <= 4.0 or side > along * 2.0:
			continue   # only within about 60 degrees of the way pressed
		if along + side * 1.5 < best_s:
			best_s = along + side * 1.5
			best = id
	if best == "":
		return false
	_hover = best
	view.light_place(best)
	_focus = view._place_at(best)
	_frame()
	Audio.sfx("hover", 0.08)
	return true


## A on the land: the way to the place lit, and focus on Set out when the party can.
func _pad_pick() -> void:
	if _hover == "" or _walking or _hover == here:
		return
	select(_hover)
	var go := _info.find_child("SetOut", true, false) as Button
	if go != null and not go.disabled and PadNav.current != null:
		PadNav.current.focus_on(go)


## LT/RT: zoom out or in.
func pad_trigger(step: int) -> void:
	if _walking:
		return
	_distance = clampf(_distance / PAD_ZOOM if step > 0 else _distance * PAD_ZOOM, NEAR, FAR)
	_frame()


## The right stick pans the land.
func pad_scroll(by: Vector2) -> void:
	if _walking:
		return
	_focus += by * _distance * PAD_SCROLL
	_frame()


func pad_prompts() -> Array:
	return [["dpad", "Places"], ["lt+rt", "Zoom"], ["stick_l", "Pan"]]
