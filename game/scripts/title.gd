extends Control
signal go

var bg: TextureRect
var title: Label
var hint: Label
var t := 0.0
var started := false
var motes: Array[Vector3] = []

func _ready() -> void:
	size = Vector2(720, 1280)
	bg = TextureRect.new()
	bg.texture = G.tex("title_bg")
	bg.size = Vector2(720, 1280)
	bg.pivot_offset = Vector2(360, 900)
	add_child(bg)
	title = G.label("WREN", 120, Color(1, 0.96, 0.88))
	title.position = Vector2(0, 190)
	title.size = Vector2(720, 200)
	add_child(title)
	hint = G.label("tap to begin", 28, Color(1, 1, 1, 0.8))
	hint.position = Vector2(0, 1150)
	hint.size = Vector2(720, 60)
	add_child(hint)
	if G.after:
		title.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
	var r := RandomNumberGenerator.new()
	for i in 40:
		motes.append(Vector3(r.randf() * 720, r.randf() * 1280, r.randf()))
	if G.song_id == "title":
		started = true
		hint.text = "tap to continue"

func _process(delta: float) -> void:
	t += delta
	bg.scale = Vector2.ONE * (1.0 + 0.03 * sin(t * 0.15) + 0.03)
	hint.modulate.a = 0.45 + 0.4 * sin(t * 2.4)
	if G.after:
		title.modulate.a = 0.75 + 0.25 * sin(t * 13.0) * (1.0 if fmod(t, 7.0) < 0.4 else 0.0)
		title.text = "WREN" if fmod(t, 11.0) > 0.3 else "W   EN"
	for i in motes.size():
		var m: Vector3 = motes[i]
		m.y -= delta * (8 + m.z * 14)
		m.x += sin(t * 0.5 + i) * delta * 6
		if m.y < -10:
			m.y = 1290
		motes[i] = m
	queue_redraw()

func _draw() -> void:
	for m in motes:
		var a := 0.15 + 0.25 * m.z
		draw_circle(Vector2(m.x, m.y), 1.5 + m.z * 2.0, Color(1, 0.85, 0.6, a) if not G.after else Color(0.7, 0.7, 0.75, a * 0.6))

func _input(e: InputEvent) -> void:
	if G.fade_rect.color.a > 0.1:
		return
	if e is InputEventMouseButton and e.pressed:
		G.sfx("tap", -8)
		if not started:
			started = true
			G.play_song("title")
			hint.text = "tap to continue"
		else:
			go.emit()
