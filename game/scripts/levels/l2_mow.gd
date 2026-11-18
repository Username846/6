extends "res://scripts/level.gd"
## Cut Grass — top-down mowing. Drag to steer the mower.

const CS := 30.0
const COLS := 24
const ROWS := 34
const OY := 190.0
var grid := PackedByteArray()   # 0 cut,1 uncut,2 blocked,3 flower,4 fake hedge(passable),5 dead flower
var lawn := 0
var timer := 0.0
var mp := Vector2(80, 1100)
var mdir := Vector2.UP
var stun := 0.0
var dog := Vector2(400, 700)
var dog_v := Vector2(40, 0)
var dog_t := 0.0
var trees: Array = []
var roses_said := false
var total := 0
var jar_found := false
var mower_snd: AudioStreamPlayer
const LAWN_TIME := 58.0

func setup() -> void:
	hint("Drag to push the mower.\nMind the roses. Mind Biscuit.", 6.0)
	mower_snd = G.loop_sfx("mower")
	mower_snd.volume_db = -60
	add_child(mower_snd)
	mower_snd.play()
	load_lawn(0)

func cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return 2
	return grid[y * COLS + x]

func setc(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < COLS and y < ROWS:
		grid[y * COLS + x] = v

func rect(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			setc(x, y, v)

func load_lawn(i: int) -> void:
	lawn = i
	grid.resize(COLS * ROWS)
	grid.fill(1)
	trees.clear()
	timer = LAWN_TIME
	roses_said = false
	match i:
		0:
			rect(1, 0, 22, 1, 3)
			rect(5, 19, 7, 21, 2)
			trees.append(Vector2(6.5, 20.5))
			mp = Vector2(360, OY + 32 * CS)
		1:
			rect(4, 8, 9, 11, 3)
			rect(14, 20, 19, 23, 3)
			rect(15, 5, 18, 8, 2)
			trees.append(Vector2(17, 7))
			rect(3, 26, 6, 29, 2)
			mp = Vector2(60, OY + 32 * CS)
		2:
			rect(17, 0, 21, 6, 2)      # shed
			rect(22, 0, 23, 20, 2)     # hedge
			rect(22, 2, 23, 9, 4)      # passable gap behind the shed (looks like hedge)
			rect(2, 14, 8, 15, 3)
			rect(10, 24, 12, 26, 2)
			trees.append(Vector2(11.5, 25.5))
			mp = Vector2(60, OY + 32 * CS)
	total = 0
	for v in grid:
		if v == 1:
			total += 1
	dog = Vector2(420, OY + 500)

func cut_frac() -> float:
	var left := 0
	for v in grid:
		if v == 1:
			left += 1
	return 1.0 - float(left) / max(1, total)

func blocked_at(p: Vector2) -> bool:
	var cx := int(floor(p.x / CS))
	var cy := int(floor((p.y - OY) / CS))
	return cell(cx, cy) == 2

func circle_free(p: Vector2) -> bool:
	if blocked_at(p):
		return false
	for a in 8:
		var q := p + Vector2.from_angle(a * PI / 4) * 22.0
		if blocked_at(q):
			return false
	return true

func tick(dt: float) -> void:
	if finished:
		mower_snd.volume_db = -60
		return
	timer -= dt
	stun -= dt
	var moving := false
	if pressed and stun <= 0:
		var to := ptr - mp
		if to.length() > 8:
			var step: Vector2 = to.normalized() * minf(to.length(), 250.0 * dt)
			mdir = mdir.lerp(to.normalized(), 0.2)
			var np: Vector2 = mp + step
			if circle_free(np):
				mp = np
			elif circle_free(Vector2(np.x, mp.y)):
				mp.x = np.x
			elif circle_free(Vector2(mp.x, np.y)):
				mp.y = np.y
			moving = true
	mower_snd.volume_db = lerp(mower_snd.volume_db, -12.0 if moving else -22.0, 0.1)
	# cut
	var cx := int(floor(mp.x / CS))
	var cy := int(floor((mp.y - OY) / CS))
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			var c := Vector2((x + 0.5) * CS, OY + (y + 0.5) * CS)
			if c.distance_to(mp) < 26:
				var v := cell(x, y)
				if v == 1:
					setc(x, y, 0)
				elif v == 3:
					setc(x, y, 5)
					if not roses_said:
						roses_said = true
						G.play_voice("x_roses")
						timer -= 4.0
	# secret: the far end of the gap behind the shed
	if lawn == 2 and not jar_found and mp.distance_to(Vector2(23 * CS, OY + 2.6 * CS)) < 26:
		jar_found = true
		secret()
	# dog
	dog_t -= dt
	if dog_t <= 0:
		dog_t = rng.randf_range(1.0, 3.0)
		dog_v = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20, 80)
	var nd := dog + dog_v * dt
	if circle_free(nd) and nd.x > 30 and nd.x < 690 and nd.y > OY + 30 and nd.y < OY + ROWS * CS - 30:
		dog = nd
	else:
		dog_v = -dog_v
	if dog.distance_to(mp) < 44 and stun <= 0:
		stun = 1.0
		G.sfx("bad", -6, 1.6)
		dog_v = (dog - mp).normalized() * 160
		dog_t = 0.8
	var f := cut_frac()
	objective("Lawn %d/3    %d%%    %d s" % [lawn + 1, int(f * 100), max(0, int(timer))])
	if f >= 0.93 or timer <= 0:
		G.sfx("ok", -4)
		if lawn < 2:
			load_lawn(lawn + 1)
			hint("Next lawn.", 2.0)
		else:
			objective("Forty lawns to go.")
			finish(2.0)

func _draw() -> void:
	grad_rect(Rect2(0, 0, 720, 1280), Color(0.16, 0.3, 0.14), Color(0.1, 0.2, 0.09))
	for y in ROWS:
		for x in COLS:
			var v := grid[y * COLS + x]
			var r := Rect2(x * CS, OY + y * CS, CS + 0.5, CS + 0.5)
			var n := (sin(x * 12.9898 + y * 78.233) * 43758.5453)
			n = n - floor(n)
			match v:
				1:
					draw_rect(r, Color(0.24 + n * 0.04, 0.48 + n * 0.06, 0.2))
					draw_line(r.position + Vector2(8 + n * 10, 24), r.position + Vector2(10 + n * 10, 10), Color(0.18, 0.38, 0.14), 2)
				0:
					var stripe := 0.06 if (x / 2) % 2 == 0 else 0.0
					draw_rect(r, Color(0.42 + stripe, 0.7 + stripe, 0.34 + stripe * 0.5))
				3:
					draw_rect(r, Color(0.32, 0.22, 0.14))
					draw_circle(r.get_center(), 9, Color(0.2, 0.45, 0.18))
					draw_circle(r.get_center() + Vector2(n * 4, -2), 6, Color(0.85, 0.2, 0.3))
				5:
					draw_rect(r, Color(0.32, 0.22, 0.14))
					draw_circle(r.get_center(), 4, Color(0.4, 0.15, 0.15))
				2, 4:
					draw_rect(r, Color(0.13, 0.28, 0.12))
					draw_circle(r.get_center() + Vector2(n * 6 - 3, 0), 15, Color(0.16, 0.34 + n * 0.05, 0.14))
	if lawn == 2:
		draw_rect(Rect2(17 * CS + 4, OY, 5 * CS - 8, 7 * CS - 4), Color(0.45, 0.32, 0.22))
		for i in 6:
			draw_line(Vector2(17 * CS + 4 + i * 24, OY), Vector2(17 * CS + 4 + i * 24, OY + 7 * CS - 4), Color(0.35, 0.24, 0.16), 2)
		if jar_found:
			var jp := Vector2(23 * CS, OY + 2.6 * CS)
			glow(jp, 60, Color(0.85, 1, 0.5, 0.9))
			draw_rect(Rect2(jp - Vector2(9, 12), Vector2(18, 24)), Color(0.8, 0.95, 1, 0.5))
			for i in 4:
				draw_circle(jp + Vector2(sin(t * 3 + i) * 5, cos(t * 2.3 + i * 2) * 7), 2.2, Color(0.95, 1, 0.6))
	for tr in trees:
		var tp := Vector2(tr.x * CS, OY + tr.y * CS)
		draw_circle(tp + Vector2(10, 14), 92, Color(0, 0, 0, 0.18))
		draw_circle(tp, 88, Color(0.12, 0.32, 0.12, 0.92))
		draw_circle(tp + Vector2(-20, -18), 50, Color(0.18, 0.42, 0.16, 0.8))
	# dog (top view)
	var da := dog_v.angle()
	draw_set_transform(dog, da)
	draw_rect(Rect2(-20, -9, 36, 18), Color(0.5, 0.34, 0.2))
	draw_circle(Vector2(20, 0), 10, Color(0.5, 0.34, 0.2))
	draw_circle(Vector2(18, -8), 5, Color(0.36, 0.22, 0.12))
	draw_circle(Vector2(18, 8), 5, Color(0.36, 0.22, 0.12))
	draw_line(Vector2(-20, 0), Vector2(-32, sin(t * 18.0) * 6), Color(0.5, 0.34, 0.2), 4)
	draw_set_transform(Vector2.ZERO)
	# mower
	var ang := mdir.angle()
	draw_set_transform(mp, ang)
	draw_rect(Rect2(-22, -20, 40, 40), Color(0.75, 0.16, 0.12))
	draw_rect(Rect2(-16, -14, 28, 28), Color(0.55, 0.1, 0.08))
	draw_circle(Vector2(0, 0), 7, Color(0.2, 0.2, 0.2))
	draw_line(Vector2(-22, -14), Vector2(-48, -14), Color(0.2, 0.2, 0.2), 3)
	draw_line(Vector2(-22, 14), Vector2(-48, 14), Color(0.2, 0.2, 0.2), 3)
	draw_line(Vector2(-48, -16), Vector2(-48, 16), Color(0.2, 0.2, 0.2), 4)
	if not G.after:
		draw_circle(Vector2(-64, 0), 15, Color(0.25, 0.18, 0.14))
		draw_circle(Vector2(-70, 0), 9, Color(0.18, 0.12, 0.1))
	draw_set_transform(Vector2.ZERO)
	if stun > 0:
		text(mp + Vector2(0, -40), "!", 30, Color(1, 0.9, 0.3))
