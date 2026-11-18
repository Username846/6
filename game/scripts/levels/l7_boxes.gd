extends "res://scripts/level.gd"
## Boxes — pack what you can. Tap a piece to rotate it. Drag it into a box, or to the curb.

const CS := 44.0
const BOX_N := 4
var boxes := [Vector2(32, 300), Vector2(268, 300), Vector2(504, 300)]
var occ: Array = []      # per box: Array of 16 (item name or "")
var placed: Array = []   # {cells:[Vector2i], box:int, col:Color, name}
const ITEMS := [
	["Mom's coat", [[0, 0], [0, 1], [0, 2], [1, 2]], Color(0.55, 0.35, 0.4)],
	["Photo albums", [[0, 0], [1, 0], [0, 1], [1, 1]], Color(0.4, 0.5, 0.7)],
	["Records", [[0, 0], [1, 0], [2, 0]], Color(0.2, 0.2, 0.22)],
	["The kite", [[1, 0], [0, 1], [1, 1], [2, 1], [1, 2]], Color(0.8, 0.22, 0.2)],
	["Biscuit's leash", [[0, 0], [1, 0]], Color(0.6, 0.45, 0.25)],
	["Guitar", [[0, 0], [0, 1], [0, 2], [0, 3]], Color(0.75, 0.5, 0.25)],
	["Dad's mug", [[0, 0]], Color(0.85, 0.85, 0.8)],
	["Sewing box", [[0, 0], [1, 0], [0, 1], [1, 1]], Color(0.75, 0.6, 0.75)],
	["Blanket", [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]], Color(0.45, 0.6, 0.5)],
	["Candle stub", [[0, 0]], Color(0.95, 0.9, 0.75)],
	["Books", [[0, 0], [1, 0], [1, 1], [2, 1]], Color(0.5, 0.3, 0.25)],
	["Porch lamp", [[0, 0], [0, 1], [0, 2]], Color(0.8, 0.75, 0.4)],
	["Winter boots", [[0, 0], [1, 0], [0, 1], [1, 1]], Color(0.35, 0.28, 0.22)],
	["June's mixtapes", [[0, 0], [1, 0]], Color(0.9, 0.5, 0.6)],
	["Mom's recipe tin", [[0, 0], [1, 0], [0, 1]], Color(0.7, 0.3, 0.3)],
	["Dining chair", [[0, 0], [0, 1], [1, 1], [0, 2], [1, 2], [1, 3]], Color(0.45, 0.32, 0.2)],
	["Alarm clock", [[0, 0]], Color(0.9, 0.4, 0.3)],
	["Family photo", [[0, 0], [1, 0], [2, 0], [1, 1]], Color(0.85, 0.8, 0.7)],
]
var queue_i := 0
var cur = null          # {name, cells:Array[Vector2i], col, pos}
var dragging := false
var drag_off := Vector2.ZERO
var curb: Array = []
var kept_candle := false
var timer := 150.0
var summary := false
var bounce := 0.0
var msg := ""
var msg_t := 0.0
const TRAY := Vector2(360, 780)
const CURB := Rect2(470, 1040, 240, 220)
const POCKET := Rect2(560, 150, 150, 140)

func setup() -> void:
	for b in 3:
		var a: Array = []
		a.resize(BOX_N * BOX_N)
		a.fill("")
		occ.append(a)
	hint("Drag into a box. Tap to turn it.\nWhat won't fit goes to the curb.", 6.0)
	_next()

func _next() -> void:
	if queue_i >= ITEMS.size():
		cur = null
		_end()
		return
	var it: Array = ITEMS[queue_i]
	queue_i += 1
	var cells: Array = []
	for c in it[1]:
		cells.append(Vector2i(c[0], c[1]))
	cur = {"name": it[0], "cells": cells, "col": it[2], "pos": TRAY}

func _end() -> void:
	if summary:
		return
	summary = true
	if cur != null:
		curb.append(cur["name"])
		cur = null
	while queue_i < ITEMS.size():
		curb.append(ITEMS[queue_i][0])
		queue_i += 1
	finish(7.0)

func _bounds(cells: Array) -> Vector2i:
	var m := Vector2i.ZERO
	for c in cells:
		m.x = max(m.x, c.x)
		m.y = max(m.y, c.y)
	return m

func _rotate() -> void:
	var b := _bounds(cur["cells"])
	var out: Array = []
	for c in cur["cells"]:
		out.append(Vector2i(b.y - c.y, c.x))
	cur["cells"] = out
	G.sfx("tap", -8, 1.3)

func tick(dt: float) -> void:
	msg_t -= dt
	if summary:
		objective("Left on the curb: %d things" % curb.size())
		return
	timer -= dt
	if not dragging and cur != null:
		cur["pos"] = cur["pos"].lerp(TRAY, 0.2)
	objective("The truck leaves in %d s" % max(0, int(timer)))
	if timer <= 0:
		_end()

func _origin_for(pos: Vector2) -> Vector2:
	var b := _bounds(cur["cells"])
	return pos - Vector2((b.x + 1) * CS, (b.y + 1) * CS) / 2.0

func on_press(p: Vector2) -> void:
	if cur == null or summary:
		return
	var o := _origin_for(cur["pos"])
	for c in cur["cells"]:
		if Rect2(o + Vector2(c) * CS, Vector2(CS, CS)).grow(14).has_point(p):
			dragging = true
			drag_off = cur["pos"] - p
			return

func on_drag(p: Vector2, _r: Vector2) -> void:
	if dragging and cur != null:
		cur["pos"] = p + drag_off

func on_release(p: Vector2) -> void:
	if not dragging or cur == null:
		return
	dragging = false
	if p.distance_to(press_pos) < 12:
		_rotate()
		return
	var name: String = cur["name"]
	if CURB.has_point(p):
		curb.append(name)
		G.sfx("thud", -6, 0.8)
		_next()
		return
	if POCKET.has_point(p) and name == "Candle stub" and not G.after:
		kept_candle = true
		G.sfx("pickup", -6)
		secret()
		_next()
		return
	var o := _origin_for(cur["pos"])
	for bi in 3:
		var bo: Vector2 = boxes[bi]
		var gx := int(round((o.x - bo.x) / CS))
		var gy := int(round((o.y - bo.y) / CS))
		if gx < -1 or gy < -1 or gx > BOX_N or gy > BOX_N:
			continue
		if name == "Candle stub":
			msg = "It won't sit right."
			msg_t = 2.0
			G.sfx("bad", -12)
			return
		var ok := true
		for c in cur["cells"]:
			var x: int = gx + c.x
			var y: int = gy + c.y
			if x < 0 or y < 0 or x >= BOX_N or y >= BOX_N or occ[bi][y * BOX_N + x] != "":
				ok = false
				break
		if ok:
			var cells: Array = []
			for c in cur["cells"]:
				occ[bi][(gy + c.y) * BOX_N + gx + c.x] = name
				cells.append(Vector2i(gx + c.x, gy + c.y))
			placed.append({"cells": cells, "box": bi, "col": cur["col"], "name": name})
			G.sfx("thud", -4)
			_next()
			return
	G.sfx("bad", -14)

func _draw() -> void:
	grad_rect(Rect2(0, 0, 720, 1280), Color(0.42, 0.4, 0.38), Color(0.22, 0.2, 0.19))
	# floorboards
	for i in 16:
		draw_line(Vector2(0, 600 + i * 46), Vector2(720, 600 + i * 46), Color(0, 0, 0, 0.12), 2)
	# Wren by the door
	if not G.after:
		person(Vector2(640, 290), 120, Color(0.12, 0.1, 0.1), 0, true)
	for bi in 3:
		var bo: Vector2 = boxes[bi]
		var r := Rect2(bo - Vector2(10, 10), Vector2(CS * BOX_N + 20, CS * BOX_N + 20))
		draw_rect(r, Color(0.62, 0.46, 0.28))
		draw_rect(Rect2(bo, Vector2(CS * BOX_N, CS * BOX_N)), Color(0.36, 0.26, 0.16))
		for k in BOX_N + 1:
			draw_line(bo + Vector2(k * CS, 0), bo + Vector2(k * CS, BOX_N * CS), Color(0, 0, 0, 0.2), 1)
			draw_line(bo + Vector2(0, k * CS), bo + Vector2(BOX_N * CS, k * CS), Color(0, 0, 0, 0.2), 1)
	for pl in placed:
		var bo2: Vector2 = boxes[pl["box"]]
		for c in pl["cells"]:
			draw_rect(Rect2(bo2 + Vector2(c) * CS + Vector2(2, 2), Vector2(CS - 4, CS - 4)), pl["col"])
	# curb
	draw_rect(CURB, Color(0.3, 0.3, 0.32, 0.8))
	text(CURB.position + Vector2(0, 40), "CURB", 26, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER, CURB.size.x)
	for i in curb.size():
		text(CURB.position + Vector2(10, 74 + i * 22), curb[i], 17, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_LEFT, CURB.size.x - 20)
	if cur != null:
		var o := _origin_for(cur["pos"])
		for c in cur["cells"]:
			var rr := Rect2(o + Vector2(c) * CS + Vector2(2, 2), Vector2(CS - 4, CS - 4))
			draw_rect(rr, cur["col"])
			draw_rect(rr, Color(0, 0, 0, 0.3), false, 2)
		if cur["name"] == "Candle stub":
			glow(o + Vector2(CS / 2, CS / 2), 50, Color(1, 0.8, 0.4, 0.5))
		text(Vector2(0, 640), cur["name"], 30, Color(1, 0.96, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 470)
	if kept_candle:
		glow(Vector2(652, 230), 40, Color(1, 0.8, 0.4, 0.6))
	if msg_t > 0:
		text(Vector2(0, 640), msg, 28, Color(1, 0.9, 0.8, clamp(msg_t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 720)
	if summary:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, min(0.75, t * 0.0 + 0.75)))
		text(Vector2(0, 380), "Left behind", 36, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 720)
		for i in curb.size():
			text(Vector2(0, 450 + i * 40), curb[i], 28, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER, 720)
