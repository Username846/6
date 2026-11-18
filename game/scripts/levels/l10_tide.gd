extends "res://scripts/level.gd"
## Low Tide — drag to pile sand into walls. The water always wins.

const CS := 30.0
const COLS := 24
const ROWS := 32
const OY := 200.0
var h := PackedFloat32Array()
var castle := PackedByteArray()
var castle_hp := 100.0
var sand := 1.0
var waves: Array = []
var wave_t := 4.0
var tide := 0.0
var front := PackedFloat32Array()
var energy := PackedFloat32Array()
var wet := PackedFloat32Array()
var dig_taps := 0
var glass := false
var post := Vector2(60, OY + 7 * CS)
var gone := false

func setup() -> void:
	h.resize(COLS * ROWS)
	castle.resize(COLS * ROWS)
	front.resize(COLS)
	energy.resize(COLS)
	wet.resize(COLS * ROWS)
	for y in ROWS:
		for x in COLS:
			h[y * COLS + x] = clamp(1.6 - y * 0.05, 0.0, 2.0) + rng.randf() * 0.1
	for y in range(11, 16):
		for x in range(9, 15):
			castle[y * COLS + x] = 1
			h[y * COLS + x] = 3.0
	for x in COLS:
		front[x] = ROWS
	hint("Drag to pile up sand.\nProtect the castle.", 5.0)

func idx(x: int, y: int) -> int:
	return y * COLS + x

func tick(dt: float) -> void:
	tide += dt
	sand = min(1.0, sand + dt * 0.16)
	if gone:
		return
	wave_t -= dt
	if wave_t <= 0:
		wave_t = max(3.0, rng.randf_range(5.5, 8.0) - tide * 0.02)
		var base := 3.0 + tide * 0.09
		if tide > 165:
			base += 30.0
		for x in COLS:
			energy[x] = base * rng.randf_range(0.8, 1.2) + sin(x * 0.5 + tide) * 1.0
			front[x] = ROWS
		G.sfx("wave", -8, rng.randf_range(0.85, 1.1))
	# advance fronts
	for x in COLS:
		if energy[x] <= 0:
			front[x] = min(float(ROWS), front[x] + dt * 4.0)
			continue
		var nf: float = front[x] - dt * 9.0
		var cy := int(floor(nf))
		if cy < int(floor(front[x])) and cy >= 0:
			var i := idx(x, cy)
			var cost := h[i] * 1.0 + 0.35
			energy[x] -= cost
			h[i] = max(0.0, h[i] - 0.45)
			wet[i] = 1.0
			if castle[i] == 1:
				castle_hp -= 1.6 + max(0.0, energy[x]) * 0.4
				if h[i] < 0.6:
					castle[i] = 0
		front[x] = max(0.0, nf)
	for i in wet.size():
		wet[i] = max(0.0, wet[i] - dt * 0.15)
	var alive := 0
	for c in castle:
		alive += c
	if alive == 0:
		castle_hp = 0
	objective("Castle  %d%%" % max(0, int(castle_hp)))
	if castle_hp <= 0 and not gone:
		gone = true
		objective("")
		finish(4.0)

func _paint(p: Vector2, amt: float) -> void:
	var cx := int(floor(p.x / CS))
	var cy := int(floor((p.y - OY) / CS))
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			if x < 0 or y < 0 or x >= COLS or y >= ROWS:
				continue
			var i := idx(x, y)
			var k := 1.0 if (x == cx and y == cy) else 0.4
			if sand > 0.01:
				h[i] = min(4.0, h[i] + amt * k)
	sand = max(0.0, sand - amt * 0.5)

func on_drag(p: Vector2, r: Vector2) -> void:
	if gone:
		return
	_paint(p, min(0.25, r.length() * 0.004 + 0.03))

func on_release(p: Vector2) -> void:
	if p.distance_to(press_pos) < 12 and not gone:
		# a tap digs
		var cx := int(floor(p.x / CS))
		var cy := int(floor((p.y - OY) / CS))
		if cx >= 0 and cy >= 0 and cx < COLS and cy < ROWS:
			h[idx(cx, cy)] = max(0.0, h[idx(cx, cy)] - 0.4)
			G.sfx("tap", -16, 0.5)
		if p.distance_to(post + Vector2(0, 46)) < 34:
			dig_taps += 1
			if dig_taps >= 3 and not glass:
				glass = true
				secret()

func _draw() -> void:
	grad_rect(Rect2(0, 0, 720, OY), Color(0.42, 0.45, 0.5), Color(0.6, 0.62, 0.64))
	for y in ROWS:
		for x in COLS:
			var i := idx(x, y)
			var hh: float = h[i]
			var base := Color(0.78, 0.72, 0.6).lerp(Color(0.5, 0.46, 0.4), clamp(float(y) / ROWS, 0.0, 1.0))
			var c := base.lightened(clamp((hh - 1.0) * 0.12, -0.3, 0.3))
			c = c.lerp(Color(0.38, 0.36, 0.33), wet[i] * 0.6)
			draw_rect(Rect2(x * CS, OY + y * CS, CS + 0.5, CS + 0.5), c)
			if castle[i] == 1:
				draw_rect(Rect2(x * CS + 2, OY + y * CS + 2, CS - 4, CS - 4), Color(0.84, 0.76, 0.6).darkened(0.15 * (3.0 - min(hh, 3.0))))
	# castle towers
	if castle_hp > 0:
		for tp in [Vector2(9, 11), Vector2(14, 11), Vector2(9, 15), Vector2(14, 15)]:
			if castle[idx(int(tp.x), int(tp.y))] == 1:
				var p := Vector2((tp.x + 0.5) * CS, OY + (tp.y + 0.5) * CS)
				draw_circle(p, 18, Color(0.86, 0.78, 0.62))
				draw_circle(p, 10, Color(0.7, 0.62, 0.48))
	# water
	var tide_line := ROWS - 2.0 - tide * 0.03
	for x in COLS:
		var fy: float = min(front[x], tide_line + sin(t * 1.5 + x * 0.3) * 0.4)
		var top := OY + fy * CS
		grad_rect(Rect2(x * CS, top, CS + 0.5, 1280 - top), Color(0.55, 0.62, 0.66, 0.85), Color(0.18, 0.25, 0.3, 0.95))
		draw_line(Vector2(x * CS, top), Vector2(x * CS + CS, top), Color(0.92, 0.95, 0.96, 0.8), 4)
	# pier post
	draw_rect(Rect2(post - Vector2(14, 60), Vector2(28, 100)), Color(0.25, 0.2, 0.16))
	if glass:
		glow(post + Vector2(0, 46), 60, Color(0.5, 1, 0.75, 0.8))
		draw_circle(post + Vector2(0, 46), 7, Color(0.6, 1, 0.8))
	elif dig_taps > 0:
		draw_circle(post + Vector2(0, 46), 6 + dig_taps * 3, Color(0.35, 0.3, 0.25))
	# the old kite on the sand
	draw_colored_polygon(PackedVector2Array([Vector2(600, 260), Vector2(632, 290), Vector2(604, 340), Vector2(580, 292)]), Color(0.5, 0.15, 0.12))
	if not G.after:
		person(Vector2(470, 320), 110, Color(0.1, 0.1, 0.11), 0, true)
	bar(Rect2(20, 168, 200, 8), sand, Color(0.85, 0.78, 0.6))
