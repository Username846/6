extends "res://scripts/level.gd"
## Low Tide — hold and drag to build sand walls in front of the castle. The tide keeps rising.

const CS := 30.0
const COLS := 24
const ROWS := 34
const OY := 200.0
const CX0 := 9
const CX1 := 14
const CY0 := 10
const CY1 := 14
var wall := PackedFloat32Array()     # built-up sand on each cell (0..3)
var chp := PackedFloat32Array()      # castle health per cell (0..1)
var wet := PackedFloat32Array()
var castle_total := 0.0
var sand := 3.0
const SAND_MAX := 3.0
var sea := 28.0                      # row where the sea starts (rises toward the top)
var front := PackedFloat32Array()    # per column: wave edge row
var energy := PackedFloat32Array()   # per column: remaining wave push (in rows)
var advancing := PackedByteArray()
var wave_t := 3.0
var dig_taps := 0
var glass := false
var post := Vector2(60, OY + 6 * CS)
var gone := false
var last_cell := Vector2i(-1, -1)

func setup() -> void:
	wall.resize(COLS * ROWS)
	chp.resize(COLS * ROWS)
	wet.resize(COLS * ROWS)
	front.resize(COLS)
	energy.resize(COLS)
	advancing.resize(COLS)
	for y in range(CY0, CY1 + 1):
		for x in range(CX0, CX1 + 1):
			chp[idx(x, y)] = 1.0
			castle_total += 1.0
	for x in COLS:
		front[x] = sea
	hint("Hold and drag to build sand walls.\nKeep the water off the castle.", 6.0)

func idx(x: int, y: int) -> int:
	return y * COLS + x

func castle_frac() -> float:
	var s := 0.0
	for v in chp:
		s += v
	return s / castle_total

func tick(dt: float) -> void:
	sand = minf(SAND_MAX, sand + dt * 0.45)
	if gone:
		return
	# the tide rises steadily
	sea = maxf(CY0 - 1.0, sea - dt * 0.105)
	# building: holding still keeps piling sand
	if pressed:
		_build(ptr, dt)
	# new wave
	wave_t -= dt
	if wave_t <= 0:
		wave_t = rng.randf_range(4.0, 6.0)
		var reach := 4.0 + t * 0.045
		for x in COLS:
			energy[x] = reach * rng.randf_range(0.85, 1.15) + sin(x * 0.45 + t) * 0.8
			front[x] = sea
			advancing[x] = 1
		G.sfx("wave", -8, rng.randf_range(0.85, 1.1))
	for x in COLS:
		if advancing[x] == 1:
			var prev := int(floor(front[x]))
			front[x] -= dt * 7.0
			var cy := int(floor(front[x]))
			if cy < prev:
				if cy < 0:
					advancing[x] = 0
					continue
				var i := idx(x, cy)
				wet[i] = 1.0
				var w: float = wall[i]
				energy[x] -= 1.0 + w * 2.2
				wall[i] = maxf(0.0, w - 0.55)
				if chp[i] > 0:
					chp[i] = maxf(0.0, chp[i] - 0.22 - maxf(0.0, energy[x]) * 0.06)
					energy[x] -= 1.5
				if energy[x] <= 0:
					advancing[x] = 0
		else:
			front[x] = minf(sea, front[x] + dt * 3.0)
	# anything under the sea slowly washes away
	for y in range(max(0, int(ceil(sea))), ROWS):
		for x in COLS:
			var j := idx(x, y)
			wall[j] = maxf(0.0, wall[j] - dt * 0.25)
			if chp[j] > 0:
				chp[j] = maxf(0.0, chp[j] - dt * 0.12)
	for i in wet.size():
		if wet[i] > 0:
			wet[i] = maxf(0.0, wet[i] - dt * 0.12)
	var cf := castle_frac()
	objective("Castle  %d%%" % int(ceil(cf * 100.0)))
	if cf <= 0.001:
		gone = true
		objective("")
		finish(4.0)

func _build(p: Vector2, dt: float) -> void:
	if sand <= 0.02:
		return
	var cx := int(floor(p.x / CS))
	var cy := int(floor((p.y - OY) / CS))
	if cx < 0 or cy < 0 or cx >= COLS or cy >= ROWS or cy >= int(sea):
		return
	var used := 0.0
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			if x < 0 or y < 0 or x >= COLS or y >= ROWS or chp[idx(x, y)] > 0:
				continue
			var k := 1.0 if (x == cx and y == cy) else 0.35
			var i := idx(x, y)
			var add := minf(3.0 - wall[i], 3.2 * dt * k)
			wall[i] += add
			used += add
	sand = maxf(0.0, sand - used * 0.5)

func on_release(p: Vector2) -> void:
	if p.distance_to(press_pos) < 12 and not gone:
		if p.distance_to(post + Vector2(0, 46)) < 36:
			dig_taps += 1
			G.sfx("tap", -14, 0.5)
			if dig_taps >= 3 and not glass:
				glass = true
				secret()

func _draw() -> void:
	grad_rect(Rect2(0, 0, 720, OY), Color(0.42, 0.45, 0.5), Color(0.62, 0.64, 0.66))
	# sand
	for y in ROWS:
		var base := Color(0.8, 0.74, 0.62).lerp(Color(0.6, 0.55, 0.47), float(y) / ROWS)
		for x in COLS:
			var i := idx(x, y)
			var c := base.lerp(Color(0.45, 0.42, 0.37), wet[i] * 0.7)
			draw_rect(Rect2(x * CS, OY + y * CS, CS + 0.5, CS + 0.5), c)
	# walls (raised mounds with shadow)
	for y in ROWS:
		for x in COLS:
			var w: float = wall[idx(x, y)]
			if w < 0.15:
				continue
			var r := Rect2(x * CS, OY + y * CS, CS, CS)
			var hgt := w * 5.0
			draw_rect(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.18 * minf(w, 1.0)))
			draw_rect(Rect2(r.position - Vector2(0, hgt), r.size), Color(0.86, 0.78, 0.6).darkened(0.1 - w * 0.03))
			draw_rect(Rect2(r.position - Vector2(0, hgt), Vector2(CS, 4)), Color(0.95, 0.9, 0.75, 0.8))
	# castle
	for y in range(CY0, CY1 + 1):
		for x in range(CX0, CX1 + 1):
			var hp: float = chp[idx(x, y)]
			if hp <= 0.02:
				continue
			var r2 := Rect2(x * CS + 1, OY + y * CS + 1 - hp * 14.0, CS - 2, CS - 2)
			draw_rect(Rect2(r2.position + Vector2(0, hp * 14.0 + 3), r2.size), Color(0, 0, 0, 0.2))
			draw_rect(r2, Color(0.88, 0.8, 0.63).darkened((1.0 - hp) * 0.35))
	for tp in [Vector2i(CX0, CY0), Vector2i(CX1, CY0), Vector2i(CX0, CY1), Vector2i(CX1, CY1)]:
		var hp2: float = chp[idx(tp.x, tp.y)]
		if hp2 > 0.3:
			var p := Vector2((tp.x + 0.5) * CS, OY + (tp.y + 0.5) * CS - 22.0 * hp2)
			draw_circle(p, 17, Color(0.9, 0.82, 0.66))
			draw_circle(p, 9, Color(0.72, 0.64, 0.5))
	# water
	for x in COLS:
		var fy: float = minf(front[x], sea) + sin(t * 1.4 + x * 0.35) * 0.15
		var top := OY + fy * CS
		grad_rect(Rect2(x * CS, top, CS + 0.5, 1280 - top), Color(0.5, 0.6, 0.66, 0.88), Color(0.16, 0.23, 0.29, 0.97))
		draw_rect(Rect2(x * CS, top - 3, CS + 0.5, 7), Color(0.94, 0.96, 0.97, 0.85 if advancing[x] == 1 else 0.5))
	# pier post
	draw_rect(Rect2(post - Vector2(14, 60), Vector2(28, 100)), Color(0.25, 0.2, 0.16))
	if glass:
		glow(post + Vector2(0, 46), 60, Color(0.5, 1, 0.75, 0.8))
		draw_circle(post + Vector2(0, 46), 7, Color(0.6, 1, 0.8))
	elif dig_taps > 0:
		draw_circle(post + Vector2(0, 46), 6 + dig_taps * 3, Color(0.4, 0.35, 0.28))
	# the old kite on the sand
	draw_colored_polygon(PackedVector2Array([Vector2(600, 250), Vector2(632, 280), Vector2(604, 330), Vector2(580, 282)]), Color(0.5, 0.15, 0.12))
	if not G.after:
		person(Vector2(470, 300), 100, Color(0.1, 0.1, 0.11), 0, true)
	# sand supply
	text(Vector2(500, 190), "sand", 18, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 60)
	bar(Rect2(550, 178, 150, 10), sand / SAND_MAX, Color(0.9, 0.82, 0.62))
