extends "res://scripts/level.gd"
## After — hold your hand over a flame to shield it from the window.

var candles: Array = []   # {p, life, out}
var gust_t := 7.0
var gust := -1.0
var gust_y0 := 0.0
var gust_y1 := 0.0
var gust_pow := 0.5
var dark_t := 0.0
var phone_msg := 0.0
var curtain := 0.0
var wind_snd: AudioStreamPlayer
const POS := [Vector2(110, 820), Vector2(220, 900), Vector2(330, 840), Vector2(450, 920), Vector2(560, 850),
	Vector2(150, 1010), Vector2(290, 1060), Vector2(420, 1030), Vector2(560, 1080), Vector2(240, 1170)]
const PHONE := Vector2(560, 1190)

func setup() -> void:
	for p in POS:
		candles.append({"p": p, "life": 1.0, "out": false, "ph": rng.randf() * TAU})
	wind_snd = G.loop_sfx("amb_wind")
	wind_snd.volume_db = -30
	add_child(wind_snd)
	wind_snd.play()
	hint("Hold a flame to keep it lit.", 5.0)

func lit() -> int:
	var n := 0
	for c in candles:
		if not c["out"]:
			n += 1
	return n

func tick(dt: float) -> void:
	phone_msg -= dt
	var n := lit()
	if n == 0:
		dark_t += dt
		wind_snd.volume_db = lerp(wind_snd.volume_db, -40.0, dt)
		if dark_t > 5.0:
			finish(0.5)
		return
	gust_t -= dt
	if gust < 0 and gust_t <= 0:
		gust = 0.0
		var span: float = clamp(180.0 + t * 3.2, 180.0, 700.0)
		var mid := rng.randf_range(780, 1180)
		gust_y0 = mid - span / 2
		gust_y1 = mid + span / 2
		gust_pow = 0.55 + t * 0.006
		gust_t = max(2.8, rng.randf_range(6.0, 9.0) - t * 0.03)
	if gust >= 0:
		gust += dt / 1.6
		curtain = lerp(curtain, 1.0, dt * 4.0)
		wind_snd.volume_db = lerp(wind_snd.volume_db, -6.0, dt * 3.0)
		var gx: float = 720.0 - gust * 820.0
		for c in candles:
			if c["out"]:
				continue
			var p: Vector2 = c["p"]
			if p.y > gust_y0 and p.y < gust_y1 and abs(p.x - gx) < 120:
				var shielded := pressed and ptr.distance_to(p) < 80
				if not shielded:
					c["life"] -= gust_pow * dt * 1.25
		if gust >= 1.0:
			gust = -1.0
	else:
		curtain = lerp(curtain, 0.0, dt * 1.5)
		wind_snd.volume_db = lerp(wind_snd.volume_db, -24.0, dt)
	for c in candles:
		if not c["out"]:
			c["life"] -= dt * 0.0035
			if c["life"] <= 0:
				c["out"] = true
				G.sfx("puff", -6)

func on_press(p: Vector2) -> void:
	if p.distance_to(PHONE) < 50:
		phone_msg = 3.0
		G.sfx("tap", -10)

func _draw() -> void:
	var n := lit()
	var amb: float = n / 10.0
	grad_rect(Rect2(0, 0, 720, 1280), Color(0.01, 0.01, 0.012), Color(0.02, 0.018, 0.016))
	# window
	var wr := Rect2(470, 230, 220, 360)
	draw_rect(wr, Color(0.03, 0.04, 0.07))
	glow(Vector2(600, 330), 40, Color(0.8, 0.85, 0.95, 0.4))
	draw_rect(wr, Color(0.02, 0.02, 0.02), false, 8)
	var cw := 60.0 + curtain * 120.0
	draw_colored_polygon(PackedVector2Array([Vector2(470, 230), Vector2(470 + 30, 230), Vector2(470 - cw * 0.6, 590 + curtain * 120), Vector2(470 - cw, 560 + curtain * 120)]), Color(0.12, 0.13, 0.16, 0.9))
	# floor
	draw_rect(Rect2(0, 760, 720, 520), Color(0.03, 0.025, 0.02).lerp(Color(0.14, 0.09, 0.05), amb * 0.5))
	for c in candles:
		var p: Vector2 = c["p"]
		draw_rect(Rect2(p - Vector2(9, 34), Vector2(18, 36)), Color(0.85, 0.8, 0.68).darkened(0.7 - amb * 0.5))
		if not c["out"]:
			var l: float = clamp(c["life"], 0.0, 1.0)
			var flick := 0.8 + 0.2 * sin(t * 13.0 + c["ph"])
			var lean := 0.0
			if gust >= 0 and p.y > gust_y0 and p.y < gust_y1:
				lean = -10.0
			glow(p + Vector2(lean, -50), 140 * l * flick, Color(1, 0.6, 0.25, 0.7))
			var fp := p + Vector2(lean, -46)
			draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -22 * l * flick), fp + Vector2(7, 0), fp + Vector2(0, 7), fp + Vector2(-7, 0)]), Color(1, 0.85, 0.5))
		else:
			draw_line(p + Vector2(0, -36), p + Vector2(4 + sin(t + p.x) * 6, -80), Color(0.5, 0.5, 0.5, 0.08), 2)
	if pressed:
		draw_circle(ptr, 70, Color(0.05, 0.03, 0.02, 0.5))
	# phone
	draw_rect(Rect2(PHONE - Vector2(36, 14), Vector2(72, 28)), Color(0.05, 0.05, 0.06))
	if phone_msg > 0:
		glow(PHONE, 90, Color(0.5, 0.65, 1, 0.5))
		text(PHONE + Vector2(-200, -40), "No contacts.", 26, Color(0.75, 0.82, 1, clamp(phone_msg, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 400)
	# Wren
	var wc := Color(0, 0, 0)
	person(Vector2(360, 760), 220, wc, 0, true)
	objective("")
