extends "res://scripts/level.gd"
## A Thousand Cranes — swipe along each fold.

const C := Vector2(360, 700)
const SHAPES := [
	[Vector2(-150, -150), Vector2(0, -150), Vector2(150, -150), Vector2(150, 0), Vector2(150, 150), Vector2(0, 150), Vector2(-150, 150), Vector2(-150, 0)],
	[Vector2(-150, -150), Vector2(-75, -75), Vector2(0, 0), Vector2(75, 75), Vector2(150, 150), Vector2(0, 150), Vector2(-150, 150), Vector2(-150, 0)],
	[Vector2(-150, -150), Vector2(-112, -112), Vector2(-75, -75), Vector2(-37, -37), Vector2(0, 0), Vector2(-50, 50), Vector2(-100, 100), Vector2(-150, 150)],
	[Vector2(0, -150), Vector2(55, -75), Vector2(110, 0), Vector2(55, 75), Vector2(0, 150), Vector2(-55, 75), Vector2(-110, 0), Vector2(-55, -75)],
	[Vector2(0, -170), Vector2(40, -60), Vector2(80, 20), Vector2(40, 70), Vector2(0, 180), Vector2(-40, 70), Vector2(-80, 20), Vector2(-40, -60)],
	[Vector2(0, -170), Vector2(25, -60), Vector2(45, 20), Vector2(25, 90), Vector2(0, 180), Vector2(-25, 90), Vector2(-45, 20), Vector2(-25, -60)],
	[Vector2(-170, -120), Vector2(-60, 10), Vector2(0, -170), Vector2(30, 0), Vector2(170, -110), Vector2(60, 40), Vector2(0, 70), Vector2(-60, 40)],
]
const DIRS := [Vector2(-1, 1), Vector2(-1, -1), Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(0, -1)]
const COUNTS := [1, 60, 140, 260, 390, 530, 660, 780, 880, 950, 999]
const PAPERS := [Color(0.92, 0.35, 0.35), Color(0.35, 0.6, 0.92), Color(0.95, 0.78, 0.3), Color(0.55, 0.82, 0.55), Color(0.92, 0.55, 0.82), Color(0.95, 0.95, 0.92)]
var step := 0
var anim := 1.0
var crane_i := 0
var count := 0
var shown_count := 0.0
var paper_col := PAPERS[0]
var gold := false
var gold_found := false
var stack_open := 0.0
var stack_drag := false
var flying: Array = []
var day := 0.0
var bpm := 64.0
var beat_t := 0.0
var flat := false
var fade := 0.0
var sill: Array = []

func setup() -> void:
	hint("Swipe along the arrow to fold.", 4.0)
	G.play_amb("")

func tick(dt: float) -> void:
	anim = min(1.0, anim + dt * 3.0)
	shown_count = move_toward(shown_count, count, dt * 120.0)
	day += dt * 0.05
	beat_t += dt
	var interval := 60.0 / bpm
	if not flat and beat_t > interval:
		beat_t = 0.0
		G.sfx("tap", -22, 1.7)
	for i in range(flying.size() - 1, -1, -1):
		var f: Dictionary = flying[i]
		f["k"] += dt * 0.7
		if f["k"] >= 1.0:
			sill.append(f["c"])
			flying.remove_at(i)
	if flat:
		fade += dt
	objective("Cranes: %d" % int(shown_count))

func on_press(p: Vector2) -> void:
	if finished or flat:
		return
	var sp := Vector2(100, 1130)
	if p.distance_to(sp) < 90 and step == 0:
		stack_drag = true

func on_drag(p: Vector2, _r: Vector2) -> void:
	if stack_drag:
		stack_open = clamp((p.x - press_pos.x) / 160.0, 0.0, 1.0)

func on_release(p: Vector2) -> void:
	if finished or flat:
		return
	if stack_drag:
		stack_drag = false
		if stack_open < 0.5:
			stack_open = 0.0
		return
	if stack_open >= 0.5 and not gold_found and p.distance_to(Vector2(270, 1150)) < 60 and step == 0:
		gold = true
		paper_col = Color(1, 0.82, 0.3)
		stack_open = 0.0
		G.sfx("pickup", -6)
		return
	var d := p - press_pos
	if d.length() < 90 or anim < 1.0:
		return
	if press_pos.distance_to(C) > 330:
		return
	var want: Vector2 = DIRS[step].normalized()
	if d.normalized().dot(want) > 0.8:
		step += 1
		anim = 0.0
		G.sfx("fold", -4, rng.randf_range(0.9, 1.1))
		if crane_i == COUNTS.size() and step == 3:
			_flatline()
			return
		if step >= DIRS.size():
			_crane_done()
	else:
		G.sfx("tap", -14, 0.6)

func _crane_done() -> void:
	G.sfx("ok", -10)
	flying.append({"k": 0.0, "c": paper_col})
	if gold and not gold_found:
		gold_found = true
		secret()
	gold = false
	count = COUNTS[min(crane_i, COUNTS.size() - 1)]
	crane_i += 1
	bpm = 64.0 + crane_i * 3.0
	step = 0
	anim = 1.0
	paper_col = PAPERS[crane_i % PAPERS.size()]
	if crane_i == COUNTS.size():
		hint("One more.", 2.5)

func _flatline() -> void:
	flat = true
	G.sfx("flatline", -6)
	G.fade_song(3.0)
	finish(6.0)

func shape_now() -> PackedVector2Array:
	var a: Array = SHAPES[max(0, step - 1)] if anim < 1.0 else SHAPES[step]
	var b: Array = SHAPES[step]
	var out := PackedVector2Array()
	for i in 8:
		var pa: Vector2 = a[i]
		var pb: Vector2 = b[i]
		out.append(C + pa.lerp(pb, ease(anim, 0.4)))
	return out

func _draw() -> void:
	var light: float = 0.5 + 0.5 * sin(day)
	if flat:
		light = 0.0
	grad_rect(Rect2(0, 0, 720, 1280), Color(0.55, 0.6, 0.6).lerp(Color(0.12, 0.14, 0.18), 1.0 - light), Color(0.4, 0.44, 0.44).lerp(Color(0.06, 0.07, 0.09), 1.0 - light))
	# window + sill
	var sky := Color(0.6, 0.75, 0.9).lerp(Color(0.05, 0.07, 0.16), 1.0 - light)
	draw_rect(Rect2(390, 170, 300, 260), sky)
	draw_rect(Rect2(380, 430, 320, 16), Color(0.85, 0.86, 0.84))
	for i in sill.size():
		var x := 395.0 + fmod(i * 23.0, 290.0)
		var y := 428.0 - floorf(i * 23.0 / 290.0) * 10.0
		var c: Color = sill[i]
		draw_colored_polygon(PackedVector2Array([Vector2(x - 9, y), Vector2(x, y - 8), Vector2(x + 11, y - 2), Vector2(x + 2, y + 2)]), c)
	var extra := int(shown_count) - sill.size()
	for i in clamp(extra / 6, 0, 120):
		var x2 := 395.0 + fmod(i * 17.0 + 7.0, 290.0)
		var y2 := 420.0 - floorf(i * 17.0 / 290.0) * 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(x2 - 7, y2), Vector2(x2, y2 - 6), Vector2(x2 + 8, y2 - 1), Vector2(x2 + 1, y2 + 2)]), PAPERS[i % PAPERS.size()] * Color(1, 1, 1, 0.8))
	# monitor
	draw_rect(Rect2(40, 190, 200, 140), Color(0.06, 0.07, 0.08))
	draw_rect(Rect2(52, 202, 176, 116), Color(0.01, 0.06, 0.04))
	var pts := PackedVector2Array()
	for i in 60:
		var x3 := 56.0 + i * 2.9
		var ph := fmod(i / 60.0 * 3.0 - t * bpm / 60.0, 1.0)
		if ph < 0:
			ph += 1.0
		var y3 := 262.0
		if not flat:
			y3 -= (34.0 if ph > 0.45 and ph < 0.5 else (-14.0 if ph >= 0.5 and ph < 0.55 else 0.0))
		pts.append(Vector2(x3, y3))
	draw_polyline(pts, Color(0.4, 1, 0.6), 2)
	# bed edge & Mom's hand
	draw_rect(Rect2(0, 470, 300, 120), Color(0.85, 0.88, 0.86).lerp(Color(0.2, 0.22, 0.24), 1.0 - light))
	draw_circle(Vector2(240, 560), 22, Color(0.7, 0.58, 0.5).lerp(Color(0.2, 0.18, 0.18), 1.0 - light))
	# table
	draw_rect(Rect2(60, 980, 600, 300), Color(0.5, 0.4, 0.3).lerp(Color(0.14, 0.11, 0.09), 1.0 - light))
	# paper stack (bottom-left)
	var sp := Vector2(100, 1150)
	for i in 6:
		var o := Vector2(stack_open * i * 34.0, -i * 3.0)
		var col: Color = PAPERS[(i + 2) % PAPERS.size()]
		if i == 5 and not gold_found:
			col = Color(1, 0.82, 0.3)
		var idx := 5 - i
		var oo := Vector2(stack_open * idx * 34.0, -idx * 3.0)
		draw_rect(Rect2(sp + oo - Vector2(46, 46), Vector2(92, 92)), (Color(1, 0.82, 0.3) if idx == 5 and not gold_found else PAPERS[(idx + 2) % PAPERS.size()]).darkened(0.1 * (1.0 - light)))
	if flat:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, clamp(fade / 5.0, 0.0, 0.85)))
	# paper being folded
	var poly := shape_now()
	if not flat or fade < 2.0:
		var drop := Vector2(0, fade * fade * 120.0) if flat else Vector2.ZERO
		var pp := PackedVector2Array()
		for q in poly:
			pp.append(q + drop)
		draw_colored_polygon(pp, paper_col)
		var cl := pp.duplicate()
		cl.append(pp[0])
		draw_polyline(cl, paper_col.darkened(0.3), 2)
		if gold:
			glow(C, 260, Color(1, 0.85, 0.4, 0.5))
	# fold guide
	if not flat and step < DIRS.size() and anim >= 1.0:
		var d: Vector2 = DIRS[step].normalized()
		var perp := Vector2(-d.y, d.x)
		for k in range(-6, 7):
			var a := C + perp * k * 28.0
			draw_line(a, a + perp * 14.0, Color(1, 1, 1, 0.6), 2)
		var ph2 := fmod(t * 1.2, 1.0)
		var a0 := C - d * 160.0
		var a1 := C + d * 160.0
		var head := a0.lerp(a1, ph2)
		draw_line(a0, head, Color(1, 0.9, 0.5, 0.8), 6)
		draw_colored_polygon(PackedVector2Array([head + d * 26, head + perp * 16, head - perp * 16]), Color(1, 0.9, 0.5, 0.9))
	for f in flying:
		var k: float = f["k"]
		var p := C.lerp(Vector2(540, 400), k) + Vector2(0, -sin(k * PI) * 200)
		var s := 1.0 - k * 0.85
		draw_colored_polygon(PackedVector2Array([p + Vector2(-40, -20) * s, p + Vector2(0, -50) * s, p + Vector2(46, -12) * s, p + Vector2(4, 12) * s]), f["c"])
