extends "res://scripts/level.gd"
## Night Shift — swipe parcels to the right chute. The rules change every hour.

const COLS := [Color(0.25, 0.5, 0.95), Color(0.9, 0.25, 0.22), Color(0.95, 0.8, 0.2)]
const CNAME := ["BLUE", "RED", "YELLOW"]
var parcels: Array = []
var spawn_t := 1.0
var spawned := 0
var hour := 0
var per_hour := 12
var speed := 95.0
var grabbed = null
var hold_t := 0.0
var wrong_streak := 0
var score := 0
var flash: Array = []
var w_found := false
var w_spawned := false
var fly: Array = []

func setup() -> void:
	hint("Swipe each parcel ← → or ↓\nFollow tonight's rule.", 5.0)

func rule_text() -> String:
	match hour:
		0: return "BLUE ←    RED →    YELLOW ↓"
		1: return "● ←    ■ →    ▲ ↓"
		2: return "BLUE →    RED ←    YELLOW ↓"
		3: return "FRAGILE ↓    else BLUE ←  RED/YELLOW →"
		_: return "HEAVY ↓    ● ←    everything else →"

func correct_dir(p: Dictionary) -> int:
	# -1 left, 1 right, 2 down
	var c: int = p["c"]
	var s: int = p["s"]
	match hour:
		0: return [-1, 1, 2][c]
		1: return [-1, 1, 2][s]
		2: return [1, -1, 2][c]
		3:
			if p["fragile"]:
				return 2
			return -1 if c == 0 else 1
		_:
			if p["heavy"]:
				return 2
			return -1 if s == 0 else 1

func tick(dt: float) -> void:
	for i in range(flash.size() - 1, -1, -1):
		flash[i].z -= dt
		if flash[i].z <= 0:
			flash.remove_at(i)
	for i in range(fly.size() - 1, -1, -1):
		var f: Dictionary = fly[i]
		f["pos"] += f["v"] * dt
		f["life"] -= dt
		if f["life"] <= 0:
			fly.remove_at(i)
	if finished:
		return
	var total := per_hour * 5
	spawn_t -= dt
	if spawned >= (hour + 1) * per_hour and parcels.is_empty() and spawned < total:
		hour += 1
		hint("%d AM. New rule." % (hour + 1), 2.5)
		spawn_t = 2.2
	if spawn_t <= 0 and spawned < (hour + 1) * per_hour:
		var w := false
		var p := {"pos": Vector2(360, 230), "c": rng.randi() % 3, "s": rng.randi() % 3, "fragile": rng.randf() < 0.3,
			"heavy": rng.randf() < 0.3, "w": w, "rot": rng.randf_range(-0.1, 0.1), "size": rng.randf_range(0.85, 1.15)}
		if w:
			w_spawned = true
		parcels.append(p)
		spawned += 1
		spawn_t = max(0.85, 2.3 - hour * 0.3 - (spawned % per_hour) * 0.02)
	speed = 95.0 + hour * 22.0
	for i in range(parcels.size() - 1, -1, -1):
		var p: Dictionary = parcels[i]
		if p == grabbed:
			continue
		p["pos"].y += speed * dt
		if p["pos"].y > 1120:
			parcels.remove_at(i)
			if not p["w"]:
				_wrong(p["pos"])
	if grabbed != null and grabbed["w"] and pressed and ptr.distance_to(press_pos) < 24:
		hold_t += dt
		if hold_t > 1.4 and not w_found:
			w_found = true
			parcels.erase(grabbed)
			fly.append({"pos": grabbed["pos"], "v": Vector2(0, -20), "life": 6.0, "lamp": true})
			grabbed = null
			secret()
	objective("%d AM    sorted %d" % [hour + 1, score])
	if spawned >= total and parcels.is_empty():
		objective("6 AM. The bus.")
		finish(2.0)

func _wrong(at: Vector2) -> void:
	wrong_streak += 1
	flash.append(Vector3(at.x, at.y, 0.5))
	G.sfx("bad", -10)
	if wrong_streak == 3:
		G.play_voice("x_sort")

func on_press(p: Vector2) -> void:
	grabbed = null
	hold_t = 0.0
	var best := 90.0
	for q in parcels:
		var d: float = q["pos"].distance_to(p)
		if d < best:
			best = d
			grabbed = q

func on_release(p: Vector2) -> void:
	if grabbed == null:
		return
	var d := p - press_pos
	var q: Dictionary = grabbed
	grabbed = null
	if d.length() < 60:
		return
	var dir := 0
	if abs(d.x) > abs(d.y):
		dir = -1 if d.x < 0 else 1
	elif d.y > 0:
		dir = 2
	else:
		return
	parcels.erase(q)
	var v := Vector2(-900, 0) if dir == -1 else (Vector2(900, 0) if dir == 1 else Vector2(0, 900))
	fly.append({"pos": q["pos"], "v": v, "life": 0.6, "p": q})
	if q["w"]:
		G.sfx("whoosh", -8)
		return
	if dir == correct_dir(q):
		score += 1
		wrong_streak = 0
		G.sfx("ok", -12, 1.2)
	else:
		_wrong(q["pos"])

func on_drag(p: Vector2, _r: Vector2) -> void:
	if grabbed != null and not grabbed["w"]:
		grabbed["pos"] = grabbed["pos"].lerp(Vector2(grabbed["pos"].x + (p.x - press_pos.x) * 0.1, grabbed["pos"].y), 0.3)

func _draw_parcel(p: Dictionary, pos: Vector2) -> void:
	var s: float = 70.0 * p["size"]
	draw_set_transform(pos, p["rot"])
	draw_rect(Rect2(-s, -s * 0.7, s * 2, s * 1.4), Color(0.62, 0.45, 0.28))
	draw_rect(Rect2(-s, -6, s * 2, 12), Color(0.75, 0.62, 0.42))
	if p["w"]:
		text(Vector2(-s, 12), "W.", 34, Color(0.15, 0.1, 0.08), HORIZONTAL_ALIGNMENT_CENTER, s * 2)
	else:
		draw_rect(Rect2(-s * 0.7, -s * 0.5, s * 0.8, s * 0.55), Color(0.95, 0.95, 0.92))
		draw_rect(Rect2(-s * 0.7, -s * 0.5, s * 0.8, 10), COLS[p["c"]])
		var sp := Vector2(-s * 0.3, -s * 0.1)
		match int(p["s"]):
			0: draw_circle(sp, 13, Color(0.1, 0.1, 0.1))
			1: draw_rect(Rect2(sp - Vector2(12, 12), Vector2(24, 24)), Color(0.1, 0.1, 0.1))
			2: draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -14), sp + Vector2(14, 12), sp + Vector2(-14, 12)]), Color(0.1, 0.1, 0.1))
		if p["fragile"]:
			draw_rect(Rect2(s * 0.2, -s * 0.5, s * 0.7, 22), Color(0.85, 0.15, 0.15))
			text(Vector2(s * 0.2, -s * 0.5 + 17), "FRAGILE", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s * 0.7)
		if p["heavy"]:
			draw_rect(Rect2(s * 0.3, s * 0.15, 34, 30), Color(0.15, 0.15, 0.15))
			text(Vector2(s * 0.3, s * 0.15 + 22), "kg", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 34)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	grad_rect(Rect2(0, 0, 720, 1280), Color(0.07, 0.06, 0.05), Color(0.03, 0.03, 0.03))
	glow(Vector2(360, 120), 600, Color(1, 0.6, 0.25, 0.5))
	# chutes
	for side in [-1, 1]:
		var x := 0.0 if side < 0 else 640.0
		draw_rect(Rect2(x, 420, 80, 520), Color(0.12, 0.12, 0.13))
		draw_rect(Rect2(x + (60 if side < 0 else 0), 420, 20, 520), Color(0.95, 0.7, 0.15, 0.4))
	draw_rect(Rect2(220, 1140, 280, 140), Color(0.12, 0.12, 0.13))
	draw_rect(Rect2(220, 1140, 280, 16), Color(0.95, 0.7, 0.15, 0.4))
	# belt
	draw_rect(Rect2(240, 180, 240, 960), Color(0.13, 0.13, 0.14))
	var off := fmod(t * speed, 48.0)
	for i in 21:
		var y := 180 + i * 48 + off
		if y < 1140:
			draw_line(Vector2(240, y), Vector2(480, y), Color(0.2, 0.2, 0.22), 3)
	# rule board
	draw_rect(Rect2(30, 170, 660, 64), Color(0, 0, 0, 0.6))
	text(Vector2(30, 213), rule_text(), 26, Color(1, 0.85, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 660)
	for p in parcels:
		_draw_parcel(p, p["pos"])
	for f in fly:
		if f.has("lamp"):
			var a: float = clamp(f["life"] / 2.0, 0.0, 1.0)
			glow(f["pos"], 120, Color(1, 0.9, 0.6, a))
			draw_circle(f["pos"], 16, Color(1, 0.95, 0.75, a))
		else:
			_draw_parcel(f["p"], f["pos"])
	for fl in flash:
		draw_circle(Vector2(fl.x, fl.y), 90, Color(1, 0.2, 0.2, fl.z * 0.5))
	if grabbed != null and grabbed["w"] and hold_t > 0.2:
		draw_arc(grabbed["pos"], 95, -PI / 2, -PI / 2 + TAU * clamp(hold_t / 1.4, 0.0, 1.0), 40, Color(1, 0.9, 0.7, 0.6), 4)
