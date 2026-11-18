extends "res://scripts/level.gd"
## After — wind comes in through the window. Hold a flame to cup your hands around it.

var candles: Array = []   # {p, life, out, ph}
var gust_t := 6.0
var warn := -1.0          # >0 while a gust is about to arrive
var gust := -1.0          # 0..1 while a gust sweeps the room
var gust_y0 := 0.0
var gust_y1 := 0.0
var gust_pow := 0.5
var dark_t := 0.0
var phone_msg := 0.0
var curtain := 0.0
var wind_snd: AudioStreamPlayer
var shield := -1
var gusts := 0
const WARN_TIME := 1.6
const SWEEP_TIME := 1.8
const POS := [Vector2(110, 830), Vector2(230, 900), Vector2(350, 840), Vector2(470, 910), Vector2(590, 850),
	Vector2(150, 1010), Vector2(290, 1060), Vector2(430, 1030), Vector2(570, 1080), Vector2(240, 1170)]
const PHONE := Vector2(560, 1190)

func setup() -> void:
	for p in POS:
		candles.append({"p": p, "life": 1.0, "out": false, "ph": rng.randf() * TAU})
	wind_snd = G.loop_sfx("amb_wind")
	wind_snd.volume_db = -30
	add_child(wind_snd)
	wind_snd.play()
	hint("Wind comes in from the window.\nHold a flame to shield it.", 6.0)

func lit() -> int:
	var n := 0
	for c in candles:
		if not c["out"]:
			n += 1
	return n

func gust_x() -> float:
	return 760.0 - gust * 900.0

func in_band(p: Vector2) -> bool:
	return p.y > gust_y0 and p.y < gust_y1

func tick(dt: float) -> void:
	phone_msg -= dt
	# which candle is being shielded
	shield = -1
	if pressed:
		var bd := 90.0
		for i in candles.size():
			var d: float = candles[i]["p"].distance_to(ptr + Vector2(0, 30))
			if not candles[i]["out"] and d < bd:
				bd = d
				shield = i
	var n := lit()
	objective("Flames left: %d" % n if n > 0 else "")
	if n == 0:
		dark_t += dt
		wind_snd.volume_db = lerpf(wind_snd.volume_db, -40.0, dt)
		if dark_t > 5.0:
			finish(0.5)
		return
	gust_t -= dt
	if warn < 0 and gust < 0 and gust_t <= 0:
		warn = WARN_TIME
		var span: float = clampf(200.0 + t * 3.0, 200.0, 700.0)
		var mid := rng.randf_range(800, 1150)
		gust_y0 = mid - span / 2
		gust_y1 = mid + span / 2
		gust_pow = 0.6 + t * 0.006
		gust_t = maxf(3.5, rng.randf_range(6.5, 9.0) - t * 0.03)
		G.sfx("whoosh", -6, 0.6)
	if warn >= 0:
		warn -= dt
		curtain = lerpf(curtain, 0.5, dt * 3.0)
		if warn < 0:
			gust = 0.0
	elif gust >= 0:
		gust += dt / SWEEP_TIME
		curtain = lerpf(curtain, 1.0, dt * 5.0)
		wind_snd.volume_db = lerpf(wind_snd.volume_db, -4.0, dt * 4.0)
		var gx := gust_x()
		for i in candles.size():
			var c: Dictionary = candles[i]
			if c["out"]:
				continue
			var p: Vector2 = c["p"]
			if in_band(p) and absf(p.x - gx) < 130.0 and i != shield:
				c["life"] -= gust_pow * dt * 1.4
		if gust >= 1.0:
			gust = -1.0
			gusts += 1
			if gusts == 1:
				hint("Hold the flames in the wind's path.", 3.5)
	else:
		curtain = lerpf(curtain, 0.0, dt * 1.5)
		wind_snd.volume_db = lerpf(wind_snd.volume_db, -24.0, dt)
	for c in candles:
		if not c["out"]:
			c["life"] -= dt * 0.004
			if c["life"] <= 0:
				c["out"] = true
				G.sfx("puff", -4)

func on_press(p: Vector2) -> void:
	if p.distance_to(PHONE) < 50:
		phone_msg = 3.0
		G.sfx("tap", -10)

func _draw() -> void:
	var n := lit()
	var amb: float = n / 10.0
	grad_rect(Rect2(0, 0, 720, 1280), Color(0.012, 0.012, 0.016), Color(0.025, 0.02, 0.018))
	# window (where the wind comes from)
	var wr := Rect2(470, 230, 220, 360)
	draw_rect(wr, Color(0.04, 0.05, 0.09))
	glow(Vector2(600, 330), 40, Color(0.8, 0.85, 0.95, 0.5))
	draw_rect(wr, Color(0.02, 0.02, 0.02), false, 8)
	var cw := 50.0 + curtain * 170.0
	draw_colored_polygon(PackedVector2Array([Vector2(470, 230), Vector2(500, 230), Vector2(470 - cw * 0.6, 600 + curtain * 140), Vector2(470 - cw, 570 + curtain * 140)]), Color(0.16, 0.17, 0.21, 0.92))
	# floor
	draw_rect(Rect2(0, 760, 720, 520), Color(0.035, 0.03, 0.025).lerp(Color(0.16, 0.1, 0.06), amb * 0.6))
	# incoming wind: warning band, then a moving wall of streaks
	if warn >= 0 or gust >= 0:
		var a := 0.06 if warn >= 0 else 0.1
		draw_rect(Rect2(0, gust_y0, 720, gust_y1 - gust_y0), Color(0.55, 0.65, 0.9, a + (0.04 * sin(t * 18.0) if warn >= 0 else 0.0)))
		draw_line(Vector2(0, gust_y0), Vector2(720, gust_y0), Color(0.6, 0.7, 1, 0.25), 2)
		draw_line(Vector2(0, gust_y1), Vector2(720, gust_y1), Color(0.6, 0.7, 1, 0.25), 2)
		var front := 760.0 if warn >= 0 else gust_x()
		for k in 26:
			var yy := gust_y0 + fmod(k * 37.0, maxf(1.0, gust_y1 - gust_y0))
			var xx := front + fmod(k * 53.0 + t * 400.0, 260.0)
			var sl := 60.0 + fmod(k * 29.0, 80.0)
			draw_line(Vector2(xx, yy), Vector2(xx + sl, yy), Color(0.8, 0.85, 1, 0.35 if gust >= 0 else 0.15), 2)
		if gust >= 0:
			draw_rect(Rect2(front - 130, gust_y0, 260, gust_y1 - gust_y0), Color(0.7, 0.8, 1, 0.07))
	for i in candles.size():
		var c: Dictionary = candles[i]
		var p: Vector2 = c["p"]
		draw_rect(Rect2(p - Vector2(10, 38), Vector2(20, 40)), Color(0.85, 0.8, 0.68).darkened(0.65 - amb * 0.45))
		if not c["out"]:
			var l: float = clampf(c["life"], 0.0, 1.0)
			var hit: bool = gust >= 0 and in_band(p) and absf(p.x - gust_x()) < 130.0 and i != shield
			var flick := 0.8 + 0.2 * sin(t * 13.0 + c["ph"])
			if hit:
				flick = 0.5 + 0.5 * absf(sin(t * 40.0 + c["ph"]))
			var lean := -16.0 if hit else 0.0
			glow(p + Vector2(lean, -56), 160 * l * flick, Color(1, 0.6, 0.25, 0.75))
			var fp := p + Vector2(lean, -50)
			var fh := (12.0 + 30.0 * l) * flick
			draw_colored_polygon(PackedVector2Array([fp + Vector2(lean * 0.6, -fh), fp + Vector2(9, 0), fp + Vector2(0, 9), fp + Vector2(-9, 0)]), Color(1, 0.86, 0.5))
			draw_circle(fp + Vector2(0, 2), 4, Color(1, 1, 0.9))
			# how much flame is left
			draw_arc(p + Vector2(0, 14), 18, PI, PI + PI * l, 16, Color(1, 0.7, 0.3, 0.6), 3)
		else:
			draw_line(p + Vector2(0, -38), p + Vector2(4 + sin(t + p.x) * 6, -90), Color(0.5, 0.5, 0.5, 0.1), 2)
	# cupped hands around the shielded flame
	if shield >= 0:
		var sp: Vector2 = candles[shield]["p"] + Vector2(0, -50)
		draw_circle(sp, 54, Color(1, 0.8, 0.5, 0.08))
		for side in [-1.0, 1.0]:
			var hp := sp + Vector2(side * 40, -6)
			draw_colored_polygon(PackedVector2Array([hp + Vector2(0, -44), hp + Vector2(side * 16, -30), hp + Vector2(side * 18, 30), hp + Vector2(0, 40), hp + Vector2(-side * 8, 0)]), Color(0.08, 0.05, 0.04))
			draw_line(hp + Vector2(-side * 6, -40), hp + Vector2(-side * 8, 30), Color(1, 0.65, 0.3, 0.6), 2)
	# phone
	draw_rect(Rect2(PHONE - Vector2(36, 14), Vector2(72, 28)), Color(0.06, 0.06, 0.07))
	if phone_msg > 0:
		glow(PHONE, 90, Color(0.5, 0.65, 1, 0.5))
		text(PHONE + Vector2(-200, -40), "No contacts.", 26, Color(0.75, 0.82, 1, clampf(phone_msg, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 400)
	# Wren, sitting with the flames
	person(Vector2(360, 760), 220, Color(0, 0, 0), 0, true)
