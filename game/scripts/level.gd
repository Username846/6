extends Node2D
## Base for all chapter mini-games.
signal done
const FONT = preload("res://fonts/DejaVuSans.ttf")

var chapter := 1
var t := 0.0
var finished := false
var pressed := false
var press_pos := Vector2.ZERO
var ptr := Vector2.ZERO
var ui: Control
var obj_label: Label
var hint_label: Label
var _hint_t := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1234 + chapter
	ui = Control.new()
	ui.size = Vector2(720, 1280)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	obj_label = G.label("", 26, Color(1, 1, 1, 0.9))
	obj_label.position = Vector2(20, 118)
	obj_label.size = Vector2(680, 44)
	ui.add_child(obj_label)
	hint_label = G.label("", 30, Color(1, 0.95, 0.85))
	hint_label.position = Vector2(40, 900)
	hint_label.size = Vector2(640, 120)
	ui.add_child(hint_label)
	setup()

func setup() -> void:
	pass

func hint(text: String, dur := 4.5) -> void:
	hint_label.text = text
	hint_label.modulate.a = 1.0
	_hint_t = dur

func objective(text: String) -> void:
	obj_label.text = text

func _process(delta: float) -> void:
	t += delta
	if _hint_t > 0:
		_hint_t -= delta
		hint_label.modulate.a = clamp(_hint_t / 0.8, 0.0, 1.0)
	tick(delta)
	queue_redraw()

func tick(_delta: float) -> void:
	pass

func _input(e: InputEvent) -> void:
	if finished:
		return
	if G.dev and e is InputEventKey and e.pressed:
		if e.keycode == KEY_N:
			finish(0.2)
		elif e.keycode == KEY_S:
			secret()
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var le := make_input_local(e)
		ptr = le.position
		if e.pressed:
			pressed = true
			press_pos = ptr
			on_press(ptr)
		else:
			pressed = false
			on_release(ptr)
	elif e is InputEventMouseMotion:
		var le2 := make_input_local(e)
		var old := ptr
		ptr = le2.position
		if pressed:
			on_drag(ptr, ptr - old)

func on_press(_p: Vector2) -> void:
	pass

func on_release(_p: Vector2) -> void:
	pass

func on_drag(_p: Vector2, _rel: Vector2) -> void:
	pass

func finish(delay := 1.5) -> void:
	if finished:
		return
	finished = true
	await get_tree().create_timer(delay).timeout
	done.emit()

func secret() -> void:
	G.find_secret(chapter)

# ---------------- drawing helpers ----------------
func grad_rect(r: Rect2, top: Color, bot: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([top, top, bot, bot]))

func hgrad_rect(r: Rect2, left: Color, right: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([left, right, right, left]))

func glow(p: Vector2, r: float, c: Color, steps := 8) -> void:
	for i in steps:
		var k := 1.0 - float(i) / steps
		draw_circle(p, r * k, Color(c.r, c.g, c.b, c.a * 0.18 * (1.0 - k * 0.6)))

func soft_circle(p: Vector2, r: float, c: Color) -> void:
	for i in 6:
		var k := 1.0 - i * 0.12
		draw_circle(p, r * k, Color(c.r, c.g, c.b, c.a * 0.25))

func bar(r: Rect2, frac: float, fg: Color, bg := Color(1, 1, 1, 0.15)) -> void:
	draw_rect(r, bg)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clamp(frac, 0.0, 1.0), r.size.y)), fg)

func person(feet: Vector2, h: float, col: Color, pose := 0, pony := false) -> void:
	## tiny silhouette (pose 0 stand, 1 arm up)
	var head := feet + Vector2(0, -h * 0.9)
	draw_circle(head, h * 0.075, col)
	if pony:
		draw_circle(head + Vector2(-h * 0.07, h * 0.02), h * 0.04, col)
	var sh := feet + Vector2(0, -h * 0.8)
	var hip := feet + Vector2(0, -h * 0.48)
	draw_colored_polygon(PackedVector2Array([sh + Vector2(-h * 0.12, 0), sh + Vector2(h * 0.12, 0), hip + Vector2(h * 0.08, 0), hip + Vector2(-h * 0.08, 0)]), col)
	draw_line(hip + Vector2(-h * 0.05, 0), feet + Vector2(-h * 0.07, 0), col, h * 0.08)
	draw_line(hip + Vector2(h * 0.05, 0), feet + Vector2(h * 0.07, 0), col, h * 0.08)
	draw_line(sh + Vector2(-h * 0.11, 0), hip + Vector2(-h * 0.14, -h * 0.02), col, h * 0.06)
	if pose == 1:
		draw_line(sh + Vector2(h * 0.11, 0), sh + Vector2(h * 0.22, -h * 0.28), col, h * 0.06)
	else:
		draw_line(sh + Vector2(h * 0.11, 0), hip + Vector2(h * 0.14, -h * 0.02), col, h * 0.06)

func text(p: Vector2, s: String, size := 24, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0) -> void:
	var f: Font = FONT
	draw_string(f, p, s, align, width, size, col)
