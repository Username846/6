extends "res://scripts/level.gd"
## Star Chart — redraw the constellations you and June invented.

var stars: Array = []          # {p: Vector2, b: float, r: float}
var cons: Array = []           # {name, idx:[star indices], edges:[Vector2i]}
var cur := 0
var made: Array = []           # Vector2i edges made for current (and done ones kept)
var done_edges: Array = []
var bad_edge := Vector2i(-1, -1)
var bad_t := 0.0
var chain := -1
var ghost_t := 4.0
var mistakes := 0
var secret_idx: Array = []
var secret_edges: Array = []
var secret_done := false
var clouds: Array = []

const SHAPES := [
	["The Kite", Vector2(190, 400), [Vector2(0, -90), Vector2(60, -15), Vector2(0, 85), Vector2(-60, -15), Vector2(15, 140), Vector2(-5, 195)], [[0, 1], [1, 2], [2, 3], [3, 0], [2, 4], [4, 5]]],
	["Biscuit", Vector2(520, 420), [Vector2(-90, 0), Vector2(-20, -10), Vector2(50, -5), Vector2(80, -50), Vector2(-80, 60), Vector2(40, 60), Vector2(-130, -40)], [[0, 1], [1, 2], [2, 3], [0, 4], [2, 5], [0, 6]]],
	["The Guitar", Vector2(190, 830), [Vector2(0, 90), Vector2(-50, 40), Vector2(0, -10), Vector2(50, 40), Vector2(0, -120), Vector2(0, -170)], [[0, 1], [1, 2], [2, 3], [3, 0], [2, 4], [4, 5]]],
	["Two Friends", Vector2(520, 840), [Vector2(-70, -90), Vector2(-70, 10), Vector2(-100, 90), Vector2(70, -90), Vector2(70, 10), Vector2(100, 90), Vector2(0, -30)], [[0, 1], [1, 2], [3, 4], [4, 5], [0, 6], [6, 3]]],
	["The Car", Vector2(370, 1080), [Vector2(-120, 30), Vector2(-90, -20), Vector2(-40, -60), Vector2(50, -60), Vector2(100, -20), Vector2(130, 30)], [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]]],
]

func setup() -> void:
	for s in SHAPES:
		var idx: Array = []
		for p in s[2]:
			idx.append(stars.size())
			stars.append({"p": s[1] + p, "b": rng.randf_range(0.85, 1.0), "r": rng.randf_range(6.0, 7.5)})
		var edges: Array = []
		for e in s[3]:
			edges.append(_key(idx[e[0]], idx[e[1]]))
		cons.append({"name": s[0], "edges": edges})
	var tries := 0
	while stars.size() < 150 and tries < 3000:
		tries += 1
		var p := Vector2(rng.randf_range(20, 700), rng.randf_range(190, 1250))
		var ok := true
		for s in stars:
			if s["p"].distance_to(p) < 34:
				ok = false
				break
		if ok:
			stars.append({"p": p, "b": rng.randf_range(0.3, 0.85), "r": rng.randf_range(1.5, 4.5)})
	for i in 5:
		clouds.append(Vector3(rng.randf_range(-200, 700), rng.randf_range(250, 1150), rng.randf_range(10, 22)))
	hint("Remember the shape.\nDrag from star to star to draw it.", 5.0)

func _key(a: int, b: int) -> Vector2i:
	return Vector2i(min(a, b), max(a, b))

func _is_target(i: int) -> bool:
	if cur >= cons.size():
		return false
	for e in cons[cur]["edges"]:
		if e.x == i or e.y == i:
			return true
	return false

func nearest(p: Vector2, tr := 80.0) -> int:
	## Only the current constellation's stars (and the faint ones) can be connected.
	var best := -1
	var bd := INF
	for i in stars.size():
		var r := 0.0
		if _is_target(i):
			r = tr
		elif secret_idx.has(i):
			r = 45.0
		else:
			continue
		var d: float = stars[i]["p"].distance_to(p)
		if d < r and d / r < bd:
			bd = d / r
			best = i
	return best

func tick(dt: float) -> void:
	ghost_t -= dt
	bad_t -= dt
	for i in clouds.size():
		var c: Vector3 = clouds[i]
		c.x += c.z * dt
		if c.x > 900:
			c.x = -300
		clouds[i] = c
	if cur < cons.size():
		objective("%s   (%d/5)" % [cons[cur]["name"], cur + 1])

func on_press(p: Vector2) -> void:
	if finished or cur >= cons.size():
		return
	chain = nearest(p)

func on_drag(p: Vector2, _r: Vector2) -> void:
	if cur >= cons.size():
		return
	if chain < 0:
		chain = nearest(p)
		return
	var n := nearest(p, 62.0)
	if n >= 0 and n != chain:
		if _try_edge(chain, n):
			chain = n

func on_release(_p: Vector2) -> void:
	chain = -1

func _try_edge(a: int, b: int) -> bool:
	var k := _key(a, b)
	if made.has(k) or secret_edges.has(k):
		return true
	if secret_idx.has(a) and secret_idx.has(b):
		secret_edges.append(k)
		G.sfx("tap", -10, 0.8)
		if secret_edges.size() >= 3 and not secret_done:
			secret_done = true
			secret()
		return true
	if cons[cur]["edges"].has(k):
		made.append(k)
		G.sfx("tap", -6, 1.0 + made.size() * 0.08)
		if made.size() >= cons[cur]["edges"].size():
			G.sfx("ok", -4)
			done_edges.append_array(made)
			made.clear()
			cur += 1
			chain = -1
			if cur >= cons.size():
				objective("The whole summer sky.")
				finish(3.0)
			else:
				ghost_t = 3.5
			return false
		return true
	else:
		if k == bad_edge and bad_t > -0.6:
			return false
		bad_edge = k
		bad_t = 0.5
		mistakes += 1
		G.sfx("bad", -14)
		if mistakes % 2 == 0:
			ghost_t = 2.5
		return false

func _draw() -> void:
	grad_rect(Rect2(0, 0, 720, 1280), Color(0.01, 0.015, 0.05), Color(0.05, 0.07, 0.17))
	# milky way
	for i in 40:
		var p := Vector2(fmod(i * 97.0, 720.0), 200 + i * 26.0)
		draw_circle(p + Vector2(sin(i) * 60, 0), 70, Color(0.4, 0.45, 0.7, 0.025))
	for s in stars:
		var tw := 0.75 + 0.25 * sin(t * 2.0 + s["p"].x * 0.13)
		var c := Color(1, 1, 0.95, s["b"] * tw)
		draw_circle(s["p"], s["r"], c)
		if s["r"] > 2.5:
			draw_circle(s["p"], s["r"] * 2.4, Color(0.8, 0.85, 1, 0.08 * tw))
	for e in done_edges:
		draw_line(stars[e.x]["p"], stars[e.y]["p"], Color(1, 0.85, 0.5, 0.55), 2)
	for e in made:
		draw_line(stars[e.x]["p"], stars[e.y]["p"], Color(0.7, 0.85, 1, 0.9), 3)
	for e in secret_edges:
		draw_line(stars[e.x]["p"], stars[e.y]["p"], Color(1, 1, 1, 0.35 if not secret_done else 0.9), 1.5)
	if secret_done:
		glow(Vector2(95, 1170), 80, Color(1, 0.95, 0.8, 0.7))
	if bad_t > 0:
		draw_line(stars[bad_edge.x]["p"], stars[bad_edge.y]["p"], Color(1, 0.3, 0.3, bad_t * 2), 3)
	if ghost_t > 0 and cur < cons.size():
		var a: float = clamp(ghost_t, 0.0, 1.0) * 0.55
		for e in cons[cur]["edges"]:
			draw_line(stars[e.x]["p"], stars[e.y]["p"], Color(1, 1, 1, a), 2)
	if chain >= 0 and pressed:
		draw_line(stars[chain]["p"], ptr, Color(0.7, 0.85, 1, 0.5), 2)
	for c in clouds:
		for j in 6:
			draw_circle(Vector2(c.x + j * 45, c.y + sin(j * 1.7) * 18), 60, Color(0.08, 0.1, 0.18, 0.28))
	# rooftop silhouettes
	draw_colored_polygon(PackedVector2Array([Vector2(0, 1240), Vector2(720, 1200), Vector2(720, 1280), Vector2(0, 1280)]), Color(0.005, 0.005, 0.01))
	if not G.after:
		person(Vector2(250, 1250), 60, Color(0, 0, 0), 1, true)
	person(Vector2(300, 1248), 60, Color(0, 0, 0), 0)
