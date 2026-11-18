extends Control
signal finished

var t := 0.0
var lines := [
	["WREN", 72],
	["", 20],
	["a story in ten summers", 26],
	["", 40],
	["Made with Godot", 22],
	["Music, voices and pictures generated for this game", 22],
]
var box: VBoxContainer
var done := false

func _ready() -> void:
	size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.size = size
	add_child(bg)
	box = VBoxContainer.new()
	box.position = Vector2(40, 1300)
	box.size = Vector2(640, 900)
	add_child(box)
	for l in lines:
		var lb := G.label(l[0], l[1], Color(0.9, 0.9, 0.92, 0.85))
		lb.custom_minimum_size = Vector2(640, l[1] * 1.6)
		box.add_child(lb)
	G.lyrics_visible = false

func _process(delta: float) -> void:
	t += delta
	box.position.y = 1300 - t * 55.0
	if box.position.y < 380 and not done:
		box.position.y = 380
		if t > 22.0:
			_finish()

func _input(e: InputEvent) -> void:
	if G.fade_rect.color.a > 0.1:
		return
	if e is InputEventMouseButton and e.pressed and t > 6.0:
		_finish()

func _finish() -> void:
	if done:
		return
	done = true
	G.lyrics_visible = true
	finished.emit()
