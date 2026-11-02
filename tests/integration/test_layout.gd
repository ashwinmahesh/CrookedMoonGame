extends TestCase
## Layout checks: every screen the game has so far, opened at 1080p, 1440p, a small window, 16:10 and 4:3, fails when text or
## buttons spill out of their boxes (the engine's tests/support/layout_check.gd says what counts). A new screen or panel
## goes in here. The game draws at 1600x900 and stretches, so the three 16:9 sizes lay out alike and are checked once.
## Foundation scope: the title's pages, the exploration screen on the test hillside and the party screens. The chapter lanes add
## theirs (conversations, shops, the travel map, the endings).

const GAME := preload("res://world/game_root.gd")

## Spills found when these checks arrived, each waiting on the lane that owns the screen: [what was opened (its start), words in
## the problem, why]. They print as known instead of failing, and an entry fails once its spill is gone, so the list only
## shrinks.
const KNOWN := [
]

var root: Node
var _window := Vector2i.ZERO
var _known_seen := {}   ## KNOWN index -> true, this test
var _opened: Array[String] = []   ## what this test checked


func before_each() -> void:
	InputActions.ensure()
	_window = get_tree().root.size


func after_each() -> void:
	for i in KNOWN.size():
		var k := KNOWN[i] as Array
		if not _known_seen.has(i) and _opened.any(func(w: String) -> bool: return w.begins_with(str(k[0]))):
			fail("%s no longer has its known spill (%s): take it out of KNOWN" % [k[0], k[1]])
	get_tree().root.size = _window
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()
	SaveSystem.current_slot = ""


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The window sizes that lay out differently, each with the names of the sizes that give it.
func _layouts() -> Dictionary:
	var out := {}
	for size_name: String in LayoutCheck.SIZES:
		get_tree().root.size = LayoutCheck.SIZES[size_name]
		var logical := get_tree().root.get_visible_rect().size
		var key := "%dx%d" % [logical.x, logical.y]
		if not out.has(key):
			out[key] = {"size": LayoutCheck.SIZES[size_name], "names": []}
		(out[key]["names"] as Array).append(size_name)
	return out


## Opens something with `open` (which returns the node to check, or null) at each window size and fails on whatever spills out
## of its box. `close` puts things back between sizes.
func _check(what: String, open: Callable, close: Callable = Callable()) -> void:
	var layouts := _layouts()
	for key: String in layouts:
		var l := layouts[key] as Dictionary
		get_tree().root.size = l["size"] as Vector2i
		await _frames(2)
		var node: Variant = await open.call()
		if not node is Node:
			fail("%s didn't open at %s" % [what, key])
			continue
		await _frames(3)
		if not what in _opened:
			_opened.append(what)
		for p in LayoutCheck.problems(node as Node, get_tree().root.get_visible_rect()):
			var known := _known(what, p)
			if known >= 0:
				if not _known_seen.has(known):
					print("  known: %s: %s" % [what, (KNOWN[known] as Array)[2]])
				_known_seen[known] = true
				continue
			fail("%s at %s (%s): %s" % [what, ", ".join(l["names"] as Array), key, p])
		if close.is_valid():
			await close.call()
			await _frames(1)


## The KNOWN entry a problem is, or -1.
static func _known(what: String, problem: String) -> int:
	for i in KNOWN.size():
		var k := KNOWN[i] as Array
		if what.begins_with(str(k[0])) and problem.contains(str(k[1])):
			return i
	return -1


## The game on the test hillside with the placeholder party.
func _game() -> void:
	if root != null:
		root.queue_free()
		root = null
		await _frames(1)
	GameState.reset()
	for id: String in GAME.PLACEHOLDER_PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = GAME.FIRST_LOCATION
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(8)


## The 3D overworld holds the whole travel map: every place and every road of it has land.
func test_the_overworld_covers_the_map() -> void:
	var land := OverworldLand.light()
	var data := Travel.map_data()
	for p: Variant in data.get("places", []) as Array:
		var id := str((p as Dictionary)["id"])
		assert_true(OverworldScreen.covers(id), "the overworld covers " + id)
		var held := false
		for pl: Dictionary in land.places:
			held = held or str(pl["id"]) == id
		assert_true(held, "the land holds " + id)
	for r: Variant in data.get("roads", []) as Array:
		var ends := 0
		for pl: Dictionary in land.places:
			ends += 1 if str(pl["id"]) in [str((r as Dictionary)["from"]), str((r as Dictionary)["to"])] else 0
		assert_true(ends >= 2, "the land holds both ends of " + str((r as Dictionary)["id"]))
	# With every place shown, no two labels share a spot (the estate's three states draw one).
	var view := OverworldView.new()
	add_child(view)
	await _frames(2)
	var ids: Array = view.labels.keys()
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			assert_true(view._place_at(str(ids[a])).distance_to(view._place_at(str(ids[b]))) >= OverworldView.SAME_SPOT,
				"labels %s and %s coincide" % [ids[a], ids[b]])
	assert_true(view.labels.has("nm_estate_ruins") and not view.labels.has("druskenvald_estate"), "the latest estate state wins")
	view.queue_free()
	var bake := OverworldBake.load_bake()
	assert_true(bake != null, "the bake is current (make overworld-bake)")
	if bake != null:
		for r: Variant in data.get("roads", []) as Array:
			assert_true(bake.road_ids.has(str((r as Dictionary)["id"])), "the bake has the road " + str((r as Dictionary)["id"]))


## The 3D overworld (world/overworld/) opened to set out from the Ghostlight Wreckage, with Wickermoor chosen: its panel
## of places, the way there and its buttons. The pad's triggers zoom it and a D-pad press lights a place.
func test_the_overworld() -> void:
	GameState.reset()
	for id: String in GAME.PLACEHOLDER_PARTY:
		GameState.story.party.append(Pregens.build(id, 3))
	GameState.story.location = "ghostlight_wreckage"
	GameState.story.visited["ghostlight_wreckage"] = true
	GameState.story.set_flag("gl_last_stop", true)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(8)
	await _check("the overworld", func() -> Variant:
		root.call("open_travel", true)
		await _frames(2)
		var screen := root.get("screen") as OverworldScreen
		if screen == null:
			return null
		screen.select("wickermoor_village")
		var before := screen._distance
		screen.pad_trigger(1)
		if screen._distance >= before:
			return null   # the triggers must zoom in
		await _frames(2)
		return screen, func() -> void:
			var screen := root.get("screen") as Node
			if screen != null:
				screen.queue_free()
			root.set("screen", null))


func test_what_counts_as_spilling() -> void:
	var box := Control.new()
	add_child(box)
	box.size = Vector2(1600, 900)
	var cut := Button.new()
	cut.text = "A very long button label that cannot possibly fit in eighty pixels"
	cut.clip_text = true
	cut.position = Vector2(10, 10)
	box.add_child(cut)
	cut.size = Vector2(80, 30)
	await _frames(2)
	assert_false(LayoutCheck.problems(box, Rect2(Vector2.ZERO, Vector2(1600, 900))).is_empty(), "a cut-off label is a spill")
	box.queue_free()


func test_the_title_screen() -> void:
	var menu: Node = null
	for step: String in ["_title", "_new_game", "_pick_difficulty"]:
		await _check("the title screen (%s)" % step.trim_prefix("_"), func() -> Variant:
			if menu != null:
				menu.queue_free()
				await _frames(1)
			menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
			add_child(menu)
			await _frames(2)
			if step != "_title":
				menu.call(step)
			await _frames(2)
			return menu)
	if menu != null:
		menu.queue_free()


func test_the_exploration_screen() -> void:
	await _check("the exploration screen", func() -> Variant:
		await _game()
		return root)


func test_the_party_screens() -> void:
	await _game()
	for screen: String in ["sheet", "inventory", "journal", "party"]:
		await _check("the %s screen" % screen, func() -> Variant:
			root.call("open_screen", screen, 0)
			await _frames(2)
			return root.get("screen"), func() -> void: root.call("close_screen"))


## The journal's Bestiary with a few creatures met: its entry leads with the large portrait (their silhouettes until the art lane's
## pictures exist) and the words beside it still fit.
func test_the_bestiary_with_portraits() -> void:
	await _game()
	var st := GameState.story
	var n := 0
	for id: String in ["wayward_haint", "soulfire_stoker", "ghostlight_locomotive"]:
		st.bestiary[id] = {"n": n, "met": 1, "where": "", "defeated": 1, "studied": n == 0}
		n += 1
	await _check("the bestiary with portraits", func() -> Variant:
		root.call("open_screen", "journal", 0)
		await _frames(2)
		var journal := root.get("screen") as Node
		journal.call("_turn_to", "Bestiary")
		await _frames(2)
		return journal, func() -> void: root.call("close_screen"))
