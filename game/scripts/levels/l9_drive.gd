extends "res://scripts/level.gd"
## Highway Nine — drive home through the rain. Drag to steer. Tap to blink yourself awake.

const HOR := 560.0
const GOAL := 75.0
var miles := 0.0
var lane_x := 0.0
var target := 0.0
var drowsy := 0.0
var curve := 0.0
var curve_t := 0.0
var traffic: Array = []
var spawn := 2.0
var hit_t := 0.0
var tap_t := 0.0
var wiper := 0.0
var exit_taken := true
var rest_t := 0.0
var awake_said := 0.0
var engine: AudioStreamPlayer
var drops: Array = []

func setup() -> void:
	engine = G.loop_sfx("engine")
	engine.volume_db = -14
	add_child(engine)
	engine.play()
	for i in 60:
		drops.append(Vector3(rng.randf() * 720, rng.randf() * 1280, rng.randf()))
	hint("Drag to steer.\nTap quickly to stay awake.", 5.0)

func exit_open() -> bool:
	return miles > 30.0 and miles < 31.2 and not exit_taken

func tick(dt: float) -> void:
	if finished:
		return
	if rest_t > 0:
		rest_t -= dt
		if rest_t <= 0:
			drowsy = 0.0
		return
	var spd := 0.5 if hit_t <= 0 else 0.2
	miles += dt * spd
	hit_t -= dt
	tap_t += dt
	wiper += dt * 1.6
	drowsy = clamp(drowsy + dt * (0.018 + miles / GOAL * 0.022), 0.0, 1.0)
	curve_t -= dt
	if curve_t <= 0:
		curve_t = rng.randf_range(3, 7)
		curve = rng.randf_range(-1.0, 1.0)
	if pressed:
		target = clamp((ptr.x - 360.0) / 150.0, -1.6, 2.2 if exit_open() else 1.45)
	var lag: float = lerp(4.0, 0.8, drowsy)
	var drift := sin(t * 0.7) * drowsy * 0.9 + curve * 0.25
	lane_x += ((target - lane_x) * lag + drift) * dt
	lane_x = clamp(lane_x, -1.7, 2.3 if exit_open() else 1.6)
	if not exit_open() and lane_x > 1.5 and miles > 31.2:
		lane_x = 1.5
	if exit_open() and lane_x > 1.85:
		exit_taken = true
		rest_t = 4.0
		secret()
	if abs(lane_x) > 1.45 and not exit_open():
		drowsy = max(0.0, drowsy - dt * 0.05)
	# traffic
	spawn -= dt
	if spawn <= 0:
		spawn = rng.randf_range(1.2, 3.0)
		traffic.append({"z": 60.0, "lane": float(rng.randi_range(-1, 1)), "truck": rng.randf() < 0.5})
	for i in range(traffic.size() - 1, -1, -1):
		var c: Dictionary = traffic[i]
		c["z"] -= dt * 9.0 * (spd / 0.5)
		if c["z"] < 1.0 and c["z"] > 0.0 and abs(c["lane"] - lane_x) < 0.6 and hit_t <= 0:
			hit_t = 1.5
			G.sfx("horn", -4)
			lane_x += 0.8 if lane_x < c["lane"] else -0.8
			drowsy = max(0.0, drowsy - 0.3)
		if c["z"] < -1:
			traffic.remove_at(i)
	if drowsy > 0.75 and t - awake_said > 12.0:
		awake_said = t
		G.play_voice("x_awake")
	engine.pitch_scale = 0.9 + spd * 0.4
	objective("Exit 9    %d mi" % max(0, int(GOAL - miles)))
	if miles >= GOAL:
		objective("Home.")
		engine.stop()
		finish(2.5)

func on_release(p: Vector2) -> void:
	if p.distance_to(press_pos) < 14:
		drowsy = max(0.0, drowsy - 0.09)
		G.sfx("tap", -18, 0.6)

func proj(x: float, z: float) -> Vector2:
	var zz: float = max(z, 0.3)
	var cx := 360.0 + curve * zz * zz * 0.08
	return Vector2(cx + (x - lane_x) * 260.0 / zz, HOR + 520.0 / zz)

func _draw() -> void:
	grad_rect(Rect2(0, 0, 720, HOR), Color(0.01, 0.01, 0.025), Color(0.04, 0.05, 0.08))
	draw_rect(Rect2(0, HOR, 720, 1280 - HOR), Color(0.02, 0.02, 0.025))
	if rest_t > 0:
		draw_rect(Rect2(0, 0, 720, 1280), Color(0.02, 0.02, 0.03))
		glow(Vector2(360, 600), 300, Color(0.7, 0.85, 1, 0.8))
		draw_rect(Rect2(290, 440, 140, 300), Color(0.75, 0.88, 1, 0.9))
		draw_rect(Rect2(305, 460, 110, 180), Color(0.95, 0.98, 1))
		text(Vector2(0, 860), "Rest Area", 30, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 720)
		return
	# road segments far to near
	var n := 40
	for i in range(n, 0, -1):
		var z0 := 0.4 + i * 1.5
		var z1 := 0.4 + (i - 1) * 1.5
		var wide := false
		var rw := 2.4 if wide else 1.6
		var a0 := proj(-1.6, z0)
		var b0 := proj(rw, z0)
		var a1 := proj(-1.6, z1)
		var b1 := proj(rw, z1)
		var shade := 0.05 + 0.02 * (int(i + miles * 40.0) % 2)
		draw_colored_polygon(PackedVector2Array([a0, b0, b1, a1]), Color(shade, shade, shade * 1.1))
		if int(i + miles * 40.0) % 4 < 2:
			for lx in [-0.5, 0.5]:
				var p0 := proj(lx, z0)
				var p1 := proj(lx, z1)
				draw_line(p0, p1, Color(0.85, 0.85, 0.7, 0.7), max(1.0, 8.0 / z1))
		draw_line(a0, a1, Color(0.9, 0.9, 0.85, 0.6), max(1.0, 6.0 / z1))
		draw_line(proj(1.6, z0), proj(1.6, z1), Color(0.9, 0.9, 0.85, 0.6), max(1.0, 6.0 / z1))
	# signs
	if false:
		var zz := 40.0 - (miles - 28.5) * 24.0
		if zz > 0.5:
			var sp := proj(2.6, zz)
			var s := 120.0 / zz
			draw_rect(Rect2(sp - Vector2(s * 1.4, s * 1.6), Vector2(s * 2.8, s)), Color(0.1, 0.4, 0.2))
			text(sp - Vector2(s * 1.4, s * 0.9), "REST AREA  1 MI", int(max(8.0, s * 0.32)), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s * 2.8)
	if miles > 52.0 and miles < 54.0:
		var zm := 40.0 - (miles - 52.0) * 24.0
		if zm > 0.5:
			var mp := proj(1.75, zm)
			var ms := 60.0 / zm
			for k in 5:
				draw_circle(mp + Vector2(k * ms * 0.4 - ms, -ms * 0.6), ms * 0.25, [Color(0.95, 0.95, 0.95), Color(0.9, 0.75, 0.8), Color(0.95, 0.9, 0.6)][k % 3])
			glow(mp + Vector2(0, -ms), ms * 2.0, Color(1, 0.7, 0.3, 0.6))
	# traffic
	for c in traffic:
		var z: float = c["z"]
		if z < 0.4:
			continue
		var p := proj(c["lane"], z)
		var w := 200.0 / z
		var h := w * (0.9 if c["truck"] else 0.5)
		draw_rect(Rect2(p - Vector2(w / 2, h), Vector2(w, h)), Color(0.05, 0.05, 0.06))
		glow(p + Vector2(-w * 0.38, -h * 0.25), w * 0.35, Color(1, 0.1, 0.05, 0.9))
		glow(p + Vector2(w * 0.38, -h * 0.25), w * 0.35, Color(1, 0.1, 0.05, 0.9))
	# headlight wash
	glow(Vector2(360, 1000), 500, Color(1, 0.95, 0.8, 0.12))
	# rain on glass
	for d in drops:
		var y := fmod(d.y + t * (200 + d.z * 300), 1280.0)
		draw_line(Vector2(d.x, y), Vector2(d.x - 3, y + 14 + d.z * 20), Color(0.7, 0.8, 0.9, 0.25), 1.5)
	var wa := sin(wiper) * 1.2
	draw_line(Vector2(360, 1150), Vector2(360, 1150) + Vector2.from_angle(-PI / 2 + wa) * 700, Color(0, 0, 0, 0.9), 10)
	# dashboard
	draw_colored_polygon(PackedVector2Array([Vector2(0, 1080), Vector2(720, 1080), Vector2(720, 1280), Vector2(0, 1280)]), Color(0.01, 0.01, 0.015))
	glow(Vector2(520, 1140), 60, Color(0.2, 0.8, 1, 0.5))
	if not G.after:
		draw_arc(Vector2(200, 1200), 130, PI, TAU, 40, Color(0, 0, 0), 26)
	if hit_t > 0:
		draw_rect(Rect2(0, 0, 720, 1280), Color(1, 1, 1, hit_t * 0.15))
	# eyelids
	var lid: float = clamp((drowsy - 0.45) / 0.55, 0.0, 1.0)
	lid *= 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 1.3))
	if lid > 0:
		draw_rect(Rect2(0, 0, 720, 640 * lid), Color(0, 0, 0, 0.97))
		draw_rect(Rect2(0, 1280 - 640 * lid, 720, 640 * lid), Color(0, 0, 0, 0.97))
