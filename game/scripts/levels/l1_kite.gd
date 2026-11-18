extends "res://scripts/level.gd"
## Updraft — kite flying. Hold to pull, drag to steer.

const PX := 3.0
var kx := 360.0
var alt := 20.0
var vy := 0.0
var vx := 0.0
var target_x := 360.0
var tumble := 0.0
var bands := [Vector2(70, 110), Vector2(170, 215), Vector2(265, 320)]
var band_i := 0
var band_prog := 0.0
const BAND_NEED := 7.0
var drafts: Array = []
var gulls: Array = []
var clouds: Array = []
var trail: Array = []

func setup() -> void:
	hint("Hold to pull the string.\nDrag to steer. Let go to drift.", 6.0)
	for i in 7:
		drafts.append({"x": rng.randf_range(80, 640), "w": rng.randf_range(50, 90), "a0": rng.randf_range(0, 500), "a1": 0.0, "s": rng.randf_range(0.8, 1.4), "v": rng.randf_range(-12, 12)})
		drafts[i]["a1"] = drafts[i]["a0"] + rng.randf_range(90, 200)
	drafts.append({"x": 600.0, "w": 70.0, "a0": 360.0, "a1": 600.0, "s": 1.5, "v": -6.0})
	for i in 26:
		clouds.append(Vector3(rng.randf_range(-100, 820), rng.randf_range(160, 620), rng.randf_range(0.6, 1.4)))

func wind_at(a: float) -> float:
	return 4.0 + a * 0.012 + sin(t * 0.7 + a * 0.02) * 1.2

func draft_at(x: float, a: float) -> float:
	var s := 0.0
	for d in drafts:
		if a > d["a0"] and a < d["a1"] and abs(x - d["x"]) < d["w"]:
			s += d["s"] * (1.0 - abs(x - d["x"]) / d["w"])
	return s

func tick(dt: float) -> void:
	if finished:
		return
	for d in drafts:
		d["x"] += d["v"] * dt
		if d["x"] < 60 or d["x"] > 660:
			d["v"] = -d["v"]
	if pressed:
		target_x = ptr.x
	var up := draft_at(kx, alt)
	if tumble > 0:
		tumble -= dt
		vy -= 40.0 * dt
	elif pressed:
		var acc: float = 11.0 + up * 32.0 - maxf(0.0, alt - 300.0) * 0.09
		if alt > 430.0:
			acc -= 14.0
		vy += acc * dt * 2.0
	else:
		vy += (-9.0 + up * 26.0) * dt * 2.0
	if alt > 360:
		vx += rng.randf_range(-1, 1) * (alt - 360) * 0.12 * dt * 60
	vy *= pow(0.4, dt)
	vy = clamp(vy, -45, 45)
	alt = clamp(alt + vy * dt, 4.0, 600.0)
	vx += (target_x - kx) * 2.2 * dt
	vx *= pow(0.15, dt)
	kx = clamp(kx + vx * dt, 40, 680)
	# gulls
	if rng.randf() < dt * 0.55:
		var dir := -1.0 if rng.randf() < 0.5 else 1.0
		gulls.append(Vector3(-40.0 if dir > 0 else 760.0, alt + rng.randf_range(-90, 120), dir * rng.randf_range(90, 160)))
	for i in range(gulls.size() - 1, -1, -1):
		var g: Vector3 = gulls[i]
		g.x += g.z * dt
		gulls[i] = g
		if g.x < -80 or g.x > 800:
			gulls.remove_at(i)
			continue
		if tumble <= 0 and abs(g.x - kx) < 36 and abs(g.y - alt) * PX < 34:
			tumble = 1.1
			vy = -20
			G.sfx("bad", -8)
	# bands
	if band_i < bands.size():
		var b: Vector2 = bands[band_i]
		if alt >= b.x and alt <= b.y and tumble <= 0:
			band_prog += dt
			if band_prog >= BAND_NEED:
				band_i += 1
				band_prog = 0.0
				G.sfx("ok", -6)
				if band_i >= bands.size():
					objective("Higher than the gulls.")
					finish(3.0)
	if band_i < bands.size():
		objective("Hold the kite in the golden band  %d/3" % (band_i + 1))
	trail.push_front(Vector2(kx, alt))
	if trail.size() > 24:
		trail.pop_back()

func cam() -> float:
	return max(0.0, alt - 177.0)

func sy(a: float) -> float:
	return 1180.0 - (a - cam()) * PX

func _draw() -> void:
	var c := cam()
	var mid_alt := c + 170.0
	var k: float = clamp(mid_alt / 560.0, 0.0, 1.0)
	var top := Color(0.36, 0.64, 0.92).lerp(Color(0.02, 0.05, 0.2), k)
	var bot := Color(0.74, 0.88, 0.97).lerp(Color(0.12, 0.25, 0.55), k)
	grad_rect(Rect2(0, 0, 720, 1280), top, bot)
	# sun
	glow(Vector2(560, 300 + c * 0.3), 260, Color(1, 0.95, 0.8, 0.9 - k * 0.5))
	# high stars appear as sky darkens
	if k > 0.55:
		var r2 := RandomNumberGenerator.new()
		r2.seed = 7
		for i in 60:
			var p := Vector2(r2.randf() * 720, r2.randf() * 1280)
			draw_circle(p, r2.randf_range(0.6, 1.6), Color(1, 1, 1, (k - 0.55) * 1.6 * r2.randf()))
	# drafts (shimmer)
	for d in drafts:
		var y0 := sy(d["a1"])
		var y1 := sy(d["a0"])
		if y1 < 0 or y0 > 1280:
			continue
		for j in 5:
			var xx: float = d["x"] + sin(t * 2.0 + j * 1.7) * d["w"] * 0.5
			var yy := fmod(t * 120.0 + j * 97.0, max(1.0, y1 - y0)) + y0
			draw_line(Vector2(xx, yy), Vector2(xx + 3, yy - 50), Color(1, 1, 1, 0.07), 3)
	# bands
	if band_i < bands.size():
		var b: Vector2 = bands[band_i]
		var r := Rect2(0, sy(b.y), 720, sy(b.x) - sy(b.y))
		draw_rect(r, Color(1, 0.82, 0.35, 0.13 + 0.05 * sin(t * 3.0)))
		draw_line(r.position, Vector2(720, r.position.y), Color(1, 0.85, 0.4, 0.5), 2)
		draw_line(Vector2(0, r.end.y), r.end, Color(1, 0.85, 0.4, 0.5), 2)
	# clouds
	for cl in clouds:
		var cy := sy(cl.y)
		if cy < -120 or cy > 1400:
			continue
		var cx := fposmod(cl.x + t * 10.0 * cl.z, 920.0) - 100.0
		for j in 5:
			draw_circle(Vector2(cx + (j - 2) * 34 * cl.z, cy + sin(j * 1.3) * 10), 34 * cl.z, Color(1, 1, 1, 0.22))
	# ground & sea
	var gy := sy(0)
	if gy < 1400:
		grad_rect(Rect2(0, gy - 140, 720, 140), Color(0.36, 0.62, 0.78), Color(0.2, 0.45, 0.62))
		grad_rect(Rect2(0, gy - 10, 720, 400), Color(0.95, 0.82, 0.6), Color(0.78, 0.6, 0.36))
	var hand := Vector2(360, gy - 70)
	if gy < 1400:
		if not G.after:
			person(Vector2(340, gy + 30), 110, Color(0.18, 0.14, 0.13), 1, true)
			hand = Vector2(362, gy - 58)
			person(Vector2(250, gy + 26), 150, Color(0.22, 0.17, 0.15), 0)
			person(Vector2(450, gy + 34), 112, Color(0.22, 0.17, 0.15), 0)
		else:
			draw_line(Vector2(360, gy + 30), Vector2(360, gy - 20), Color(0.3, 0.25, 0.2), 6)
			hand = Vector2(360, gy - 20)
	else:
		hand = Vector2(360, 1300)
	# string
	var kp := Vector2(kx, sy(alt))
	var ctrl := (hand + kp) / 2 + Vector2(40 + vx * 0.2, 60)
	var pts := PackedVector2Array()
	for i in 21:
		var u := i / 20.0
		pts.append(hand.lerp(ctrl, u).lerp(ctrl.lerp(kp, u), u))
	draw_polyline(pts, Color(0.15, 0.15, 0.2, 0.7), 1.5)
	# gulls
	for g in gulls:
		var gp := Vector2(g.x, sy(g.y))
		var f := sin(t * 12.0 + g.x * 0.05) * 6
		draw_polyline(PackedVector2Array([gp + Vector2(-16, -4 - f), gp, gp + Vector2(16, -4 - f)]), Color(0.12, 0.12, 0.16), 3)
	# kite
	var rot := vx * 0.004 + (sin(t * 20.0) * 0.6 if tumble > 0 else sin(t * 2.0) * 0.08)
	var tr := Transform2D(rot, kp)
	var body := PackedVector2Array([Vector2(0, -34), Vector2(22, -6), Vector2(0, 40), Vector2(-22, -6)])
	draw_set_transform_matrix(tr)
	draw_colored_polygon(body, Color(0.85, 0.2, 0.17))
	draw_line(Vector2(0, -34), Vector2(0, 40), Color(0.3, 0.1, 0.1), 2)
	draw_line(Vector2(-22, -6), Vector2(22, -6), Color(0.3, 0.1, 0.1), 2)
	draw_set_transform_matrix(Transform2D())
	var prev := kp + tr.basis_xform(Vector2(0, 40))
	for i in range(1, trail.size()):
		var tp: Vector2 = trail[i]
		var p2 := Vector2(tp.x, sy(tp.y)) + Vector2(sin(t * 6.0 + i) * 4, 40 + i * 9 - (alt - tp.y) * PX)
		draw_line(prev, p2, Color(0.2, 0.1, 0.1, 0.8), 2)
		if i % 4 == 0:
			draw_circle(p2, 5, [Color(0.95, 0.78, 0.3), Color(0.3, 0.64, 0.85), Color(0.9, 0.42, 0.54)][(i / 4) % 3])
		prev = p2
	# altimeter
	draw_rect(Rect2(684, 200, 14, 900), Color(0, 0, 0, 0.25))
	var ay: float = 1100 - clamp(alt / 600.0, 0.0, 1.0) * 900
	if band_i < bands.size():
		var b2: Vector2 = bands[band_i]
		draw_rect(Rect2(684, 1100 - b2.y / 600.0 * 900, 14, (b2.y - b2.x) / 600.0 * 900), Color(1, 0.8, 0.3, 0.7))
	draw_rect(Rect2(678, ay - 3, 26, 6), Color.WHITE)
	text(Vector2(600, ay + 8), "%dm" % int(alt), 20, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 70)
	if band_i < bands.size():
		bar(Rect2(160, 168, 400, 8), band_prog / BAND_NEED, Color(1, 0.82, 0.35))
