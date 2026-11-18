extends "res://scripts/level.gd"
## Feedback — run the mixing desk at the band's first gig. Faders really control the stems.

const NAMES := ["VOX", "GTR", "BASS", "DRUMS"]
const FX := [120.0, 280.0, 440.0, 600.0]
const TOP := 700.0
const BOT := 1160.0
var val := [0.5, 0.5, 0.5, 0.5]
var target := [0.5, 0.5, 0.5, 0.5]
var grab := -1
var crowd := 0.6
var squeal := -1
var squeal_t := 0.0
var next_squeal := 14.0
var phone_found := false
var failing := 0.0
var outs := 0
const BAG := Vector2(58, 392)
var squeal_snd: AudioStreamPlayer
var bar_len := 4.0 * 60.0 / 170.0
var plan := [["intro", 2], ["verse", 16], ["pre", 8], ["chorus", 16], ["verse", 16], ["pre", 8], ["chorus", 16], ["bridge", 16], ["chorus", 16], ["chorus", 16], ["outro", 2]]
const TGT := {
	"intro": [0.3, 0.8, 0.6, 0.6], "verse": [0.82, 0.45, 0.6, 0.55], "pre": [0.7, 0.7, 0.55, 0.8],
	"chorus": [0.85, 0.72, 0.65, 0.75], "bridge": [0.9, 0.25, 0.4, 0.2], "outro": [0.5, 0.5, 0.5, 0.5]}

func setup() -> void:
	G.play_song("c3", false, ["vocals", "guitar", "bass", "drums"])
	hint("Drag the faders into the lit zones.\nTap CUT when something squeals.", 6.0)
	squeal_snd = G.loop_sfx("squeal")
	squeal_snd.volume_db = -14
	add_child(squeal_snd)
	if G.songs.has("c3"):
		bar_len = float(G.songs["c3"]["dur"]) / 132.0

func section_at(time: float) -> String:
	var b := time / bar_len
	for p in plan:
		if b < p[1]:
			return p[0]
		b -= p[1]
	return "outro"

func phone_window(st: float) -> bool:
	var b := st / bar_len
	return b >= 42.0 and b < 58.0

func _restart() -> void:
	failing = 0.0
	crowd = 0.6
	val = [0.5, 0.5, 0.5, 0.5]
	grab = -1
	_end_squeal()
	next_squeal = 14.0
	t = 0.0
	G.play_song("c3", false, ["vocals", "guitar", "bass", "drums"])
	hint("Again.", 2.0)

func tick(dt: float) -> void:
	if failing > 0:
		failing -= dt
		if failing <= 0:
			_restart()
		return
	var st := G.song_time()
	var sec := section_at(st)
	var base: Array = TGT[sec]
	var wob := int(st / (bar_len * 8.0))
	for i in 4:
		var w := sin(wob * 2.1 + i * 1.7) * 0.1
		target[i] = lerp(float(target[i]), clamp(base[i] + w, 0.12, 0.92), dt * 2.0)
		if G.after and i == 0:
			# Wren's voice is gone
			val[i] = 0.0
			target[i] = 0.0
			G.stems[i].volume_db = -80.0
			continue
		G.stems[i].volume_db = linear_to_db(max(val[i], 0.0005)) + 2.0
	# mix quality
	outs = 0
	for i in 4:
		if abs(val[i] - target[i]) > 0.1:
			outs += 1
	var good := outs == 0
	if t > 4.0:
		crowd = clamp(crowd + (dt * 0.08 if good else -dt * 0.055 * outs), 0.0, 1.0)
	if crowd <= 0.0 and not finished:
		_fail()
		return
	# feedback
	if not finished:
		next_squeal -= dt
		if squeal < 0 and next_squeal <= 0 and sec != "bridge":
			squeal = (1 + rng.randi() % 3) if G.after else rng.randi() % 4
			squeal_t = 2.0
			squeal_snd.play()
		if squeal >= 0:
			squeal_t -= dt
			squeal_snd.pitch_scale = 1.0 + sin(t * 9.0) * 0.03
			if squeal_t <= 0:
				crowd = max(0.0, crowd - 0.25)
				_end_squeal()
	objective("Crowd" + ("  ▲" if good else "  ▼".repeat(outs)))
	if not finished and st >= G.song_len - 1.5:
		objective("They want an encore.")
		finish(1.0)

func _fail() -> void:
	failing = 3.0
	G.stop_song()
	_end_squeal()
	G.sfx("bad", -4, 0.7)
	objective("")
	hint("They walked out.", 3.0)

func _end_squeal() -> void:
	squeal = -1
	squeal_snd.stop()
	next_squeal = rng.randf_range(9.0, 16.0)

func on_press(p: Vector2) -> void:
	if squeal >= 0 and abs(p.x - FX[squeal]) < 60 and abs(p.y - (TOP - 70)) < 40:
		G.sfx("tap", -4)
		_end_squeal()
		return
	if failing > 0:
		return
	for i in 4:
		if abs(p.x - FX[i]) < 70 and p.y > TOP - 40 and p.y < BOT + 40:
			grab = i
			on_drag(p, Vector2.ZERO)
			return

func on_drag(p: Vector2, _r: Vector2) -> void:
	if grab == 0 and G.after:
		return
	if grab >= 0:
		val[grab] = clamp((BOT - p.y) / (BOT - TOP), 0.0, 1.0)

func on_release(_p: Vector2) -> void:
	grab = -1

func _draw() -> void:
	# venue
	grad_rect(Rect2(0, 0, 720, 600), Color(0.03, 0.02, 0.06), Color(0.09, 0.05, 0.12))
	var beat := fmod(G.song_time(), 60.0 / 170.0) / (60.0 / 170.0)
	var energy: float = (val[0] + val[1] + val[2] + val[3]) / 4.0
	for i in 3:
		var lx := 160.0 + i * 200.0
		var col: Color = [Color(1, 0.25, 0.45), Color(0.95, 0.95, 1), Color(0.25, 0.7, 1)][i]
		col.a = 0.12 + 0.12 * energy * (1.0 - beat)
		draw_colored_polygon(PackedVector2Array([Vector2(lx - 12, 120), Vector2(lx + 12, 120), Vector2(lx + 130, 420), Vector2(lx - 130, 420)]), col)
	draw_rect(Rect2(0, 380, 720, 30), Color(0.05, 0.04, 0.06))
	var band_c := Color(0.02, 0.02, 0.03)
	if not G.after:
		person(Vector2(360, 386), 150, band_c, 0, true)
	person(Vector2(200, 386), 145, band_c, 0)
	person(Vector2(540, 386), 120, band_c, 0)
	# crowd
	for row in 3:
		for i in 14:
			var x := i * 54.0 + row * 18.0 + 10
			var jump: float = max(0.0, sin((G.song_time() * 170.0 / 60.0 + i * 0.37 + row) * PI)) * 18.0 * crowd * energy
			var y := 470.0 + row * 44 - jump
			draw_circle(Vector2(x, y), 20, Color(0.01, 0.01, 0.015))
			draw_rect(Rect2(x - 28, y + 14, 56, 120), Color(0.01, 0.01, 0.015))
	# desk
	grad_rect(Rect2(0, 600, 720, 680), Color(0.16, 0.16, 0.18), Color(0.08, 0.08, 0.09))
	bar(Rect2(60, 610, 600, 10), crowd, Color(1, 0.75, 0.3))
	for i in 4:
		var x: float = FX[i]
		var tg: float = target[i]
		var zone := Rect2(x - 34, BOT - (tg + 0.1) * (BOT - TOP), 68, 0.2 * (BOT - TOP))
		if not (G.after and i == 0):
			draw_rect(zone, Color(0.4, 1, 0.6, 0.16))
		draw_rect(Rect2(x - 4, TOP, 8, BOT - TOP), Color(0.02, 0.02, 0.02))
		for k in 11:
			var yy := TOP + k * (BOT - TOP) / 10.0
			draw_line(Vector2(x - 22, yy), Vector2(x - 12, yy), Color(1, 1, 1, 0.25), 1)
		var fy: float = BOT - val[i] * (BOT - TOP)
		var inz: bool = abs(val[i] - tg) < 0.1
		draw_rect(Rect2(x - 30, fy - 16, 60, 32), Color(0.85, 0.85, 0.88) if inz else Color(0.6, 0.6, 0.62))
		draw_line(Vector2(x - 26, fy), Vector2(x + 26, fy), Color(0.1, 0.1, 0.1), 3)
		text(Vector2(x - 60, BOT + 70), NAMES[i], 22, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 120)
		# meter
		var lvl: float = val[i] * (0.6 + 0.4 * (1.0 - beat) if i == 3 else 0.85 + 0.15 * sin(t * 13 + i))
		for k in 12:
			var on := k < int(lvl * 12)
			var mc := Color(0.3, 1, 0.4) if k < 8 else (Color(1, 0.85, 0.2) if k < 10 else Color(1, 0.25, 0.2))
			draw_rect(Rect2(x + 40, BOT - k * 38 - 30, 10, 30), mc if on else Color(0.15, 0.15, 0.15))
		# cut button
		var cb := Rect2(x - 46, TOP - 92, 92, 44)
		var sq := squeal == i
		draw_rect(cb, Color(0.9, 0.12, 0.1) if sq and fmod(t, 0.3) < 0.15 else Color(0.25, 0.08, 0.08))
		text(Vector2(x - 46, TOP - 62), "CUT", 22, Color(1, 1, 1, 0.9 if sq else 0.4), HORIZONTAL_ALIGNMENT_CENTER, 92)
