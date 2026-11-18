extends "res://scripts/level.gd"
## Static — drag across the dial to find voices in the night.

const FMIN := 87.5
const FMAX := 108.0
const DX0 := 110.0
const DX1 := 610.0
var freq := 95.0
var stations: Array = []
var found := 0
var lock_t := 0.0
var static_snd: AudioStreamPlayer
var playing := -1
var voice_gap := 0.0
var secret_t := 0.0
var secret_done := false
var dawn := 0.0
const LINES := ["x_radio1", "x_radio2", "x_radio5", "x_radio3", "x_radio6", "x_radio4"]

func setup() -> void:
	static_snd = G.loop_sfx("static")
	static_snd.volume_db = -12
	add_child(static_snd)
	static_snd.play()
	var fs := [89.3, 92.9, 96.1, 99.7, 103.3, 106.5]
	fs.shuffle()
	for i in 6:
		stations.append({"f": fs[i] + rng.randf_range(-0.6, 0.6), "line": LINES[i], "got": false, "ph": rng.randf() * TAU})
	G.music.volume_db = -11.0
	hint("Drag left and right to tune.\nHold still on a voice.", 5.0)

func fx(f: float) -> float:
	return DX0 + (f - FMIN) / (FMAX - FMIN) * (DX1 - DX0)

func sig_of(s: Dictionary) -> float:
	var sf: float = s["f"] + sin(t * 0.12 + s["ph"]) * 0.35
	return clamp(1.0 - abs(freq - sf) / 0.45, 0.0, 1.0)

func on_drag(_p: Vector2, r: Vector2) -> void:
	freq = clamp(freq + r.x * 0.022, 87.5, 108.0)

func tick(dt: float) -> void:
	dawn = min(1.0, dawn + dt / 170.0)
	var best := 0.0
	var bi := -1
	for i in stations.size():
		var s: float = sig_of(stations[i])
		if s > best:
			best = s
			bi = i
	var in_secret := freq < 86.5 and freq > 85.7
	if in_secret:
		best = clamp(1.0 - abs(freq - 86.1) / 0.4, 0.0, 1.0)
	static_snd.volume_db = linear_to_db(max(0.02, 1.0 - best)) - 10.0
	voice_gap -= dt
	if best > 0.55:
		if in_secret:
			if voice_gap <= 0 and not G.voice.playing:
				G.play_voice("x_radio7")
				voice_gap = 4.0
			secret_t += dt
			if secret_t > 3.0 and not secret_done:
				secret_done = true
				secret()
		elif bi >= 0:
			if playing != bi or (voice_gap <= 0 and not G.voice.playing):
				playing = bi
				G.play_voice(stations[bi]["line"])
				voice_gap = 2.5
			if not stations[bi]["got"]:
				lock_t += dt
				if lock_t > 2.5:
					stations[bi]["got"] = true
					found += 1
					lock_t = 0
					G.sfx("ok", -10)
	else:
		lock_t = max(0.0, lock_t - dt)
		secret_t = 0.0
		if G.voice.playing and best < 0.3:
			G.voice.volume_db = -20
		playing = -1
	G.voice.volume_db = linear_to_db(max(0.05, best)) if best > 0.3 else -30.0
	objective("Voices found: %d / 6" % found)
	if found >= 6 and not finished:
		objective("Morning.")
		G.voice.volume_db = 0
		finish(3.0)

func _exit_tree() -> void:
	G.voice.volume_db = 0
	G.music.volume_db = -2.0

func _draw() -> void:
	var night := Color(0.02, 0.025, 0.05).lerp(Color(0.2, 0.18, 0.26), dawn)
	grad_rect(Rect2(0, 0, 720, 1280), night, Color(0.02, 0.02, 0.03))
	# window
	draw_rect(Rect2(420, 150, 260, 300), Color(0.05, 0.06, 0.12).lerp(Color(0.5, 0.38, 0.45), dawn))
	for i in 9:
		var bx := 425.0 + i * 30.0
		var bh := 60.0 + fmod(i * 53.0, 120.0)
		draw_rect(Rect2(bx, 450 - bh, 26, bh), Color(0.02, 0.02, 0.04))
		if fmod(i * 7.0, 3.0) < 1.0:
			draw_rect(Rect2(bx + 8, 450 - bh + 14, 6, 8), Color(1, 0.8, 0.45, 0.8 - dawn * 0.6))
	draw_rect(Rect2(410, 140, 280, 320), Color(0.03, 0.03, 0.04), false, 10)
	# radio body
	var body := Rect2(50, 520, 620, 560)
	draw_rect(body, Color(0.32, 0.2, 0.12))
	draw_rect(body.grow(-14), Color(0.42, 0.27, 0.16))
	for i in 9:
		draw_line(Vector2(100, 840 + i * 22), Vector2(620, 840 + i * 22), Color(0.2, 0.12, 0.07), 6)
	# dial window
	var dial := Rect2(DX0 - 30, 600, DX1 - DX0 + 60, 170)
	draw_rect(dial, Color(0.05, 0.04, 0.03))
	draw_rect(dial.grow(-6), Color(0.95, 0.8, 0.5, 0.18 + 0.1 * (1.0 if found > 0 else 0.0)))
	glow(dial.get_center(), 320, Color(1, 0.7, 0.3, 0.5))
	for f in range(88, 109):
		var x := fx(f)
		var big := f % 2 == 0
		draw_line(Vector2(x, 640), Vector2(x, 640 + (34 if big else 18)), Color(0.15, 0.1, 0.05), 2)
		if big:
			text(Vector2(x - 30, 720), str(f), 20, Color(0.15, 0.1, 0.05), HORIZONTAL_ALIGNMENT_CENTER, 60)
	for s in stations:
		if s["got"]:
			draw_circle(Vector2(fx(s["f"]), 750), 5, Color(0.9, 0.3, 0.2))
	# needle (hidden behind bezel when off the scale)
	var nx := fx(freq)
	if nx > dial.position.x + 6:
		draw_line(Vector2(nx, 612), Vector2(nx, 760), Color(0.8, 0.1, 0.05), 4)
	draw_rect(Rect2(dial.position.x - 40, 590, 46, 190), Color(0.32, 0.2, 0.12))
	draw_rect(Rect2(dial.end.x - 6, 590, 46, 190), Color(0.32, 0.2, 0.12))
	# knobs
	for kx in [150.0, 570.0]:
		draw_circle(Vector2(kx, 1010), 46, Color(0.12, 0.08, 0.05))
		var a := freq * 0.9 if kx > 300 else t * 0.0
		draw_line(Vector2(kx, 1010), Vector2(kx, 1010) + Vector2.from_angle(a) * 38, Color(0.8, 0.7, 0.5), 4)
	# signal lamp
	var sig := 1.0 - db_to_linear(static_snd.volume_db + 10.0)
	glow(Vector2(360, 1010), 60, Color(1, 0.6, 0.2, clamp(sig, 0.05, 1.0)))
	bar(Rect2(260, 1060, 200, 8), lock_t / 2.5, Color(1, 0.75, 0.35))
	if not G.after:
		person(Vector2(110, 1270), 150, Color(0.01, 0.01, 0.015), 0, true)
