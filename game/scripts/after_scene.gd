extends Node2D
## After — not a game. Wren looks at a photo of each person and puts their candle out,
## then goes to the window.
signal finished

const FONT = preload("res://fonts/DejaVuSans.ttf")
const CANDLES := [Vector2(170, 1080), Vector2(390, 1130), Vector2(590, 1070)]
const PEOPLE := [
	["photo_mom", "c6_i0_2", "Fold them slowly. Stay a while."],
	["photo_june", "c8_i0_1", "Hey, it's me. It's been months. Are you okay? Call me back. Please."],
	["photo_dad", "x_dad_drunk", "Not now, kiddo. I can't... not tonight. I'll deal with it tomorrow."],
]
const SEG := 11.0
const START := 2.0
var t := 0.0
var lit := [true, true, true]
var photo := -1
var photo_a := 0.0
var line := ""
var line_a := 0.0
var done_seg := [false, false, false]
var voiced := [false, false, false]
var out_done := [false, false, false]
var fly_said := false
var gone := false
var ended := false
var moon := 0.0

func _ready() -> void:
	G.lyrics_visible = false

func _end_t() -> float:
	return START + SEG * 3.0

func _process(dt: float) -> void:
	t += dt
	for k in 3:
		var s := START + k * SEG
		if t >= s and t < s + 7.5:
			photo = k
		if t >= s + 1.2 and not voiced[k]:
			voiced[k] = true
			G.play_voice(PEOPLE[k][1])
			line = PEOPLE[k][2]
			line_a = 1.0
		if t >= s + 9.0 and not out_done[k]:
			out_done[k] = true
			lit[k] = false
			G.sfx("puff", -4)
	var in_photo := false
	for k in 3:
		var s2 := START + k * SEG
		if t >= s2 and t < s2 + 7.5:
			in_photo = true
	photo_a = move_toward(photo_a, 1.0 if in_photo else 0.0, dt * 1.2)
	line_a = maxf(0.0, line_a - dt * 0.14)
	var e := _end_t()
	if t > e + 1.0:
		moon = minf(1.0, moon + dt * 0.35)
	if t > e + 7.0 and not fly_said:
		fly_said = true
		G.play_voice("x_fly")
	if t > e + 11.0 and not gone:
		gone = true
		G.sfx("whoosh", -2, 0.5)
		G.fade_song(1.0)
	if t > e + 14.0 and not ended:
		ended = true
		finished.emit()
	queue_redraw()

func _sitting(p: Vector2, h: float, col: Color, lean: float) -> void:
	var head := p + Vector2(lean * 30.0, -h * 0.82 + absf(lean) * 20.0)
	draw_circle(head, h * 0.085, col)
	draw_circle(head + Vector2(-h * 0.08, h * 0.03), h * 0.045, col)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-h * 0.14, h * 0.1), head + Vector2(h * 0.14, h * 0.1),
		p + Vector2(h * 0.2, -h * 0.1), p + Vector2(-h * 0.22, -h * 0.05)]), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-h * 0.24, 0), p + Vector2(h * 0.34, -h * 0.28), p + Vector2(h * 0.46, -h * 0.2), p + Vector2(h * 0.4, h * 0.02)]), col)
	# arms holding something up
	draw_line(head + Vector2(h * 0.1, h * 0.16), head + Vector2(h * 0.3, h * 0.05), col, h * 0.06)

func _standing(feet: Vector2, h: float, col: Color) -> void:
	var head := feet + Vector2(0, -h * 0.9)
	draw_circle(head, h * 0.075, col)
	draw_circle(head + Vector2(-h * 0.07, h * 0.02), h * 0.04, col)
	var sh := feet + Vector2(0, -h * 0.8)
	var hip := feet + Vector2(0, -h * 0.48)
	draw_colored_polygon(PackedVector2Array([sh + Vector2(-h * 0.12, 0), sh + Vector2(h * 0.12, 0), hip + Vector2(h * 0.08, 0), hip + Vector2(-h * 0.08, 0)]), col)
	draw_line(hip + Vector2(-h * 0.05, 0), feet + Vector2(-h * 0.06, 0), col, h * 0.08)
	draw_line(hip + Vector2(h * 0.05, 0), feet + Vector2(h * 0.06, 0), col, h * 0.08)
	draw_line(sh + Vector2(-h * 0.11, 0), hip + Vector2(-h * 0.13, 0), col, h * 0.06)
	draw_line(sh + Vector2(h * 0.11, 0), hip + Vector2(h * 0.13, 0), col, h * 0.06)

func _glow(p: Vector2, r: float, c: Color) -> void:
	for i in 8:
		var k := 1.0 - float(i) / 8.0
		draw_circle(p, r * k, Color(c.r, c.g, c.b, c.a * 0.18 * (1.0 - k * 0.6)))

func _draw() -> void:
	var nlit := 0
	for l in lit:
		if l:
			nlit += 1
	var warm: float = nlit / 3.0
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.01, 0.01, 0.014))
	# window, curtain moving a little
	var wr := Rect2(470, 230, 220, 360)
	draw_rect(wr, Color(0.04, 0.05, 0.09).lerp(Color(0.12, 0.15, 0.24), moon))
	_glow(Vector2(600, 330), 50 + moon * 220, Color(0.8, 0.85, 0.95, 0.5 + moon * 0.3))
	draw_rect(wr, Color(0.02, 0.02, 0.02), false, 8)
	var cw := 60.0 + 40.0 * sin(t * 0.7) + moon * 80.0
	draw_colored_polygon(PackedVector2Array([Vector2(470, 230), Vector2(500, 230), Vector2(470 - cw * 0.6, 600 + moon * 100), Vector2(470 - cw, 570 + moon * 100)]), Color(0.14, 0.15, 0.19, 0.92))
	# floor
	draw_rect(Rect2(0, 760, 720, 520), Color(0.03, 0.025, 0.02).lerp(Color(0.14, 0.09, 0.05), warm * 0.6))
	if moon > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(470, 590), Vector2(690, 590), Vector2(560, 1280), Vector2(120, 1280)]), Color(0.6, 0.68, 0.85, 0.08 * moon))
	for k in 3:
		var p: Vector2 = CANDLES[k]
		draw_rect(Rect2(p - Vector2(10, 38), Vector2(20, 40)), Color(0.85, 0.8, 0.68).darkened(0.65 - warm * 0.45))
		if lit[k]:
			var flick := 0.85 + 0.15 * sin(t * 11.0 + k * 2.0)
			_glow(p + Vector2(0, -56), 170 * flick, Color(1, 0.6, 0.25, 0.75))
			var fp := p + Vector2(0, -50)
			draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -40 * flick), fp + Vector2(9, 0), fp + Vector2(0, 9), fp + Vector2(-9, 0)]), Color(1, 0.86, 0.5))
		else:
			draw_line(p + Vector2(0, -38), p + Vector2(4 + sin(t + p.x) * 6, -90), Color(0.5, 0.5, 0.5, 0.1), 2)
	# Wren
	var col := Color(0.005, 0.005, 0.008)
	var e := _end_t()
	if t < e + 2.5:
		var lean := 0.0
		for k in 3:
			var s := START + k * SEG
			if t > s + 8.0 and t < s + 9.6:
				lean = (CANDLES[k].x - 380.0) / 220.0 * sin((t - s - 8.0) / 1.6 * PI)
		_sitting(Vector2(380, 1000), 260, col, lean)
	elif not gone:
		var w := clampf((t - e - 2.5) / 4.0, 0.0, 1.0)
		var feet := Vector2(380, 1000).lerp(Vector2(580, 592), ease(w, -1.6))
		_standing(feet, lerpf(240.0, 165.0, w), col)
	# the photo she is looking at
	if photo >= 0 and photo_a > 0.01:
		var tex: Texture2D = G.tex(PEOPLE[photo][0])
		var sz := Vector2(440, 540) * 0.95
		draw_set_transform(Vector2(360, 470), -0.05 + photo * 0.05)
		draw_rect(Rect2(-sz / 2 + Vector2(10, 14), sz), Color(0, 0, 0, 0.5 * photo_a))
		draw_texture_rect(tex, Rect2(-sz / 2, sz), false, Color(1, 0.92, 0.82, photo_a))
		draw_set_transform(Vector2.ZERO)
	if line_a > 0.01:
		draw_string(FONT, Vector2(40, 175), line, HORIZONTAL_ALIGNMENT_CENTER, 640, 22, Color(0.85, 0.82, 0.78, minf(line_a, 0.8)))
	if gone:
		draw_rect(Rect2(0, 0, 720, 1280), Color.BLACK)
