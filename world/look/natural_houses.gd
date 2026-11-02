class_name NaturalHouses
extends RefCounted
## The towns' houses built at their natural size (Ashwin, 2026-11-02: "we are not building for the 5 foot grid. We are
## building a world that looks natural and then putting the grid on top of it afterwards"). The engine's TownBuilder puts
## a house together one module per square side; once a place is built, each village-kit house is rebuilt here from the
## Medieval Village MegaKit's pieces at their own size (1 unit = 5 ft = 1.524 m, the figures' scale): each wall run laid
## with as many 2 m pieces as its real length holds, fitted to it; a storey 3.12 m high, two for a big house; the pack's
## roofs over the real span with their own pitch, its timbered gable fronts, a brick chimney. The squares under the house,
## its doors and the rules grid are untouched: the house's footprint is the grid's, its walls stand on the outside of it.
## Bending (BuildingBend) and the morph's tidy shape (BuildingMorph) carry over: the pieces go through BuildingKit.merge.

const STYLES: Array[String] = ["village", "vstone", "vwood"]
const REAL := 1.0 / 1.524
## A storey: the pack's walls, 3.12 m.
const STOREY := 3.12 * REAL
## A wall piece's width, 2 m, and its thickness (inner face to outer), 0.4 m, and where its own middle plane lies.
const PIECE := 2.0 * REAL
const THICK := 0.4 * REAL
const WALL_Z0 := 0.31 * REAL
## How far the roof runs out past each gable.
const VERGE := 0.3
## A house this many squares or more is two storeys.
const TWO_STOREYS := 12
## The pack door that fits its door walls (the leaf the place hangs is resized to it).
const DOOR_W := 1.12 * REAL
const DOOR_H := 2.13 * REAL
## Where a pack window's glass is (its middle over the storey's foot, out from the wall's inner face).
const GLASS := Vector2(1.73 * REAL, 0.4 * REAL)
## Each roof's ridge over its eaves line, by the wall span it was made for (m): the pieces' highest points.
const ROOF_TOP := {4: 3.71, 6: 4.89, 8: 6.1}


## Every village-kit house on `board` rebuilt at its natural size (CrookedMoonLook.dress_place, once its doors are hung).
static func rebuild(board: ArenaBoard) -> int:
	var n := 0
	for i in board.buildings.size():
		var b := board.buildings[i]
		if STYLES.has(str(b.get("kit", ""))) and BuildingKit.has("kit_nat_%s_low" % str(b["kit"])):
			_house(board, b)
			n += 1
	return n


static func _house(board: ArenaBoard, b: Dictionary) -> void:
	var style := str(b["kit"])
	var r := b["rect"] as Rect2i
	var root := b["root"] as Node3D
	var upper := b["upper"] as Node3D
	var bend := b.get("bend") as BuildingBend
	var tidy := b.get("tidy") as BuildingBend
	var seed := int(b.get("seed", 0))
	var area := r.get_area()
	var storeys := 2 if area >= TWO_STOREYS else 1
	var h := storeys * STOREY
	_clear(board, b)
	var parts: Array = []
	var marks: Array = []
	for run: Dictionary in _runs(board, b):
		_lay_run(board, b, run, style, storeys, seed, parts, marks)
	for corner: Array in _corners(b):
		var xf := Transform3D(Basis.from_scale(Vector3(2.0, h / (3.0 * REAL), 2.0)), corner[0] as Vector3)
		parts.append(["kit_nat_%s_corner" % style, xf])
	if parts.is_empty():
		return
	var walls := BuildingKit.merge_morph(parts, "", bend, tidy, Vector2.ZERO, false)
	walls.name = "Walls"
	root.add_child(walls)
	root.move_child(walls, 0)
	SeeThrough.mark(walls)
	b["walls"] = walls
	for m: Variant in marks:
		var mark := m as Marker3D
		if bend != null:
			mark.transform = bend.frame(mark.position, mark.rotation.y)
		upper.add_child(mark)
		(b["markers"] as Array).append(mark)
	var rise := _roof(b, style, h, seed, upper, bend, tidy)
	b["height"] = h
	b["rise"] = rise
	var over := THICK + VERGE + 0.6
	b["aabb"] = AABB(Vector3(r.position.x - over, root.position.y, r.position.y - over),
		Vector3(r.size.x + 2 * over, h + rise + 2.2, r.size.y + 2 * over))
	_fit_doors(board, b)


## The engine's walls, roof, chimney and window marks of house `b`, gone (the stub a cut-away house shows stays as it was).
static func _clear(board: ArenaBoard, b: Dictionary) -> void:
	if b["walls"] != null and is_instance_valid(b["walls"]):
		(b["walls"] as Node).free()
	b["walls"] = null
	for n in (b["upper"] as Node3D).get_children():
		if n.name in [&"Roof", &"Chimney"]:
			n.free()
	for m: Variant in b["markers"]:
		if is_instance_valid(m):
			for key: String in board.windows.keys():
				if board.windows[key] == m:
					board.windows.erase(key)
			(m as Node).free()
	(b["markers"] as Array).clear()


## The house's walls as straight runs: the faces the kit worked out (its outside, the sides no other part of the building
## stands against), joined along each side. A run: {"dir", "line", "from", "to" (squares along it), "doors" (squares along
## it with a door), "open" (squares along it over open ground)}.
static func _runs(board: ArenaBoard, b: Dictionary) -> Array[Dictionary]:
	var by_side := {}
	for key: String in b["faces"]:
		var face := b["faces"][key] as Dictionary
		var c := face["cell"] as Vector2i
		var d := face["dir"] as Vector2i
		var line := c.y if d.y != 0 else c.x
		var along := c.x if d.y != 0 else c.y
		var side := "%d,%d,%d" % [d.x, d.y, line]
		if not by_side.has(side):
			by_side[side] = {"dir": d, "line": line, "cells": {}}
		var out := c + d
		(by_side[side]["cells"] as Dictionary)[along] = {"door": str(face["door"]) != "",
			"open": board.grid.in_bounds(out) and not board.grid.has_flag(out, CombatGrid.WALL)}
	var runs: Array[Dictionary] = []
	for side: String in by_side:
		var s := by_side[side] as Dictionary
		var cells := s["cells"] as Dictionary
		var keys: Array = cells.keys()
		keys.sort()
		var start := int(keys[0])
		var prev := start
		for i in range(1, keys.size() + 1):
			var k := int(keys[i]) if i < keys.size() else 1 << 30
			if k == prev + 1:
				prev = k
				continue
			var run := {"dir": s["dir"], "line": s["line"], "from": start, "to": prev + 1, "doors": [], "open": []}
			for a in range(start, prev + 1):
				if bool(cells[a]["door"]):
					(run["doors"] as Array).append(a)
				if bool(cells[a]["open"]):
					(run["open"] as Array).append(a)
			runs.append(run)
			start = k
			prev = k
	return runs


## One run of wall, every storey: door pieces centred on the doors, the lengths between filled with as many 2 m pieces
## as they hold (fitted to them), windows on every other piece over open ground.
static func _lay_run(board: ArenaBoard, b: Dictionary, run: Dictionary, style: String, storeys: int, seed: int,
		parts: Array, marks: Array) -> void:
	var d := run["dir"] as Vector2i
	var nv := Vector3(d.x, 0, d.y)
	var yaw := atan2(nv.x, nv.z)
	var along_x := d.y != 0
	var plane := float(int(run["line"]) + (1 if (d.x + d.y) > 0 else 0))
	# The run reaches past the house's corners by the walls' thickness, so its ends meet the side walls' outer faces.
	var a0 := float(run["from"]) - THICK
	var a1 := float(run["to"]) + THICK
	var slots := _slots(a0, a1, run["doors"] as Array)
	var n := 0
	for slot: Array in slots:
		var mid := float(slot[0])
		var width := float(slot[1])
		var is_door := bool(slot[2])
		var cell_along := int(floor(mid))
		var open := (run["open"] as Array).has(cell_along)
		for k in storeys:
			var at := Vector3(mid, k * STOREY, plane) if along_x else Vector3(plane, k * STOREY, mid)
			var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(width / PIECE, 1.0, 1.0)), at)
			var lower := k == 0
			if is_door and lower:
				parts.append(["kit_nat_%s_door" % style, xf])
				continue
			var window := open and not is_door and width >= PIECE * 0.6 and (n + seed + k) % 2 == 0
			parts.append(["kit_nat_%s_%s" % [style, ("low" if lower else "up") + ("_win" if window else "")], xf])
			if window:
				var w := "window_lit" if (n * 7 + seed + k) % 5 == 0 else ("window_shut" if (n * 3 + seed) % 4 == 0 else "window")
				parts.append(["kit_nat_" + w, xf])
				var mark := Marker3D.new()
				mark.name = "Window"
				mark.position = at + Vector3(0, GLASS.x, 0) + nv * GLASS.y
				mark.rotation.y = yaw
				mark.set_meta("lit", w == "window_lit")
				marks.append(mark)
				board.windows["nat:%d,%d,%d,%d,%d" % [int(run["line"]), d.x, d.y, n, k]] = mark
		n += 1


## A run from a0 to a1 (squares along it) as [middle, width, door?] pieces: a piece a door wide on each door, the gaps
## filled with 2 m pieces fitted to them; a gap too short to hold a piece's narrowest is taken up by its neighbours.
static func _slots(a0: float, a1: float, doors: Array) -> Array:
	var cuts: Array = []   # [from, to, door?]
	var at := a0
	var sorted_doors := doors.duplicate()
	sorted_doors.sort()
	for door: Variant in sorted_doors:
		var mid := float(door) + 0.5
		var lo := clampf(mid - PIECE / 2.0, a0, a1)
		var hi := clampf(mid + PIECE / 2.0, a0, a1)
		if lo > at:
			cuts.append([at, lo, false])
		cuts.append([maxf(lo, at), hi, true])
		at = hi
	if at < a1:
		cuts.append([at, a1, false])
	# A sliver of plain wall beside a door goes to the door piece.
	var merged: Array = []
	for c: Array in cuts:
		var len := float(c[1]) - float(c[0])
		if not bool(c[2]) and len < PIECE * 0.35 and not merged.is_empty():
			(merged[merged.size() - 1] as Array)[1] = c[1]
			continue
		merged.append(c)
	if merged.size() > 1 and not bool((merged[0] as Array)[2]) and float(merged[0][1]) - float(merged[0][0]) < PIECE * 0.35:
		(merged[1] as Array)[0] = merged[0][0]
		merged.remove_at(0)
	var out: Array = []
	for c: Array in merged:
		var from := float(c[0])
		var to := float(c[1])
		if bool(c[2]):
			out.append([(from + to) / 2.0, to - from, true])
			continue
		var count := maxi(1, roundi((to - from) / PIECE))
		var w := (to - from) / count
		for i in count:
			out.append([from + (i + 0.5) * w, w, false])
	return out


## The house's outer corners, where a post stands over the meeting of two walls' outer faces.
static func _corners(b: Dictionary) -> Array:
	var r := b["rect"] as Rect2i
	var joined := b.get("joined", {}) as Dictionary
	var out: Array = []
	for c: Array in [[Vector2(r.position.x, r.position.y), Vector2(-1, -1)], [Vector2(r.end.x, r.position.y), Vector2(1, -1)],
			[Vector2(r.position.x, r.end.y), Vector2(-1, 1)], [Vector2(r.end.x, r.end.y), Vector2(1, 1)]]:
		var at := c[0] as Vector2
		var out_dir := c[1] as Vector2
		# Not where another part of the same building carries on past the corner.
		var beyond := Vector2i(int(at.x + (out_dir.x - 1) / 2.0), int(at.y + (out_dir.y - 1) / 2.0))
		if joined.has(beyond) or joined.has(beyond + Vector2i(int(-out_dir.x), 0)) or joined.has(beyond + Vector2i(0, int(-out_dir.y))):
			continue
		var p := at + out_dir * (THICK * 0.6)
		out.append([Vector3(p.x, 0, p.y)])
	return out


## The roof over house `b`: the pack's modular roof for the nearest span, fitted across the house's walls, laid along
## its ridge, its gable fronts at the ends, a chimney on some. Returns the rise.
static func _roof(b: Dictionary, style: String, h: float, seed: int, upper: Node3D, bend: BuildingBend, tidy: BuildingBend) -> float:
	var r := b["rect"] as Rect2i
	var along_x := r.size.x >= r.size.y
	var span := float(r.size.y if along_x else r.size.x) + 2.0 * THICK
	var length := float(r.size.x if along_x else r.size.y) + 2.0 * THICK + 2.0 * VERGE
	var butts := b.get("butts", {}) as Dictionary
	var best := 4
	for w: int in [4, 6, 8]:
		if absf(w * REAL - span) < absf(best * REAL - span):
			best = w
	var across := span / (best * REAL)
	var rise := float(ROOF_TOP[best]) * REAL * across
	var count := maxi(1, roundi(length / PIECE))
	var slice := length / count
	var cx := r.position.x + r.size.x / 2.0
	var cz := r.position.y + r.size.y / 2.0
	var turn := Basis(Vector3.UP, 0.0 if along_x else PI / 2.0)
	var parts: Array = []
	for i in count:
		var t := -length / 2.0 + (i + 0.5) * slice
		var at := Vector3(cx + t, h, cz) if along_x else Vector3(cx, h, cz + t)
		parts.append(["kit_nat_%s_roof%d" % [style, best], Transform3D(turn * Basis.from_scale(Vector3(slice / PIECE, across, across)), at)])
	var half := float(r.size.x if along_x else r.size.y) / 2.0
	for end: Array in [[1.0, "+x" if along_x else "+z"], [-1.0, "-x" if along_x else "-z"]]:
		if butts.has(str(end[1])):
			continue
		var s := float(end[0])
		var out := Vector3(s, 0, 0) if along_x else Vector3(0, 0, s)
		var at := Vector3(cx, h, cz) + out * (half + WALL_Z0)
		var yaw := atan2(out.x, out.z)
		parts.append(["kit_nat_%s_gable%d" % [style, best], Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(across, across, 1.0)), at)])
	var roof := BuildingKit.merge_morph(parts, "", bend, tidy, Vector2.ZERO, false) if tidy != null \
		else BuildingKit.merge(parts, "", bend, Vector2.ZERO, false)
	if roof != null:
		roof.name = "Roof"
		upper.add_child(roof)
		SeeThrough.mark(roof)
	if seed % 3 != 2 and BuildingKit.has("kit_nat_chimney"):
		var t := (0.22 + float(seed % 5) * 0.12 - 0.5) * (length - 2.0 * VERGE)
		var at := Vector3(cx + t, h + rise * 0.45, cz - span * 0.18) if along_x else Vector3(cx - span * 0.18, h + rise * 0.45, cz + t)
		var ch := BuildingKit.merge([["kit_nat_chimney", Transform3D(Basis(), Vector3.ZERO)]])
		if ch != null:
			ch.name = "Chimney"
			ch.transform = bend.frame(at, 0.0) if bend != null else Transform3D(Basis(), at)
			upper.add_child(ch)
			SeeThrough.mark(ch)
	return rise


## The door leaves hung on house `b`'s doors, resized to the pack's doorway.
static func _fit_doors(board: ArenaBoard, b: Dictionary) -> void:
	var r := b["rect"] as Rect2i
	var grown := Rect2(Vector2(r.position) - Vector2(1, 1), Vector2(r.size) + Vector2(2, 2))
	for node in board.find_children("*", "Node3D", true, false):
		var holder := node as Node3D
		if not holder.has_meta("model") or holder.get_child_count() == 0:
			continue
		var info := ModelPiece.manifest().get(str(holder.get_meta("model")), {}) as Dictionary
		if str(info.get("mount", "")) != "door":
			continue
		var p := holder.global_position
		if not grown.has_point(Vector2(p.x, p.z)):
			continue
		var size := info.get("size", [0.86, 1.15, 0.1]) as Array
		(holder.get_child(0) as Node3D).scale = Vector3(DOOR_W / float(size[0]), DOOR_H / float(size[1]), 1.0)
