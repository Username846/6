extends Control
signal finished

var panels: Array = []
var chapter := 1
var show_card := true

var img: TextureRect
var box: ColorRect
var name_l: Label
var text_l: Label
var sms_l: Label
var sms_bg: ColorRect
var skip_l: Label
var t := 0.0
var panel_t := 0.0
var typing := 0.0
var full_text := ""
var advance := false
var skipping := false
var kb_from := Vector2.ZERO
var kb_to := Vector2.ZERO

func _ready() -> void:
	size = Vector2(720, 1280)
	G.lyrics_visible = false
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = size
	add_child(bg)
	img = TextureRect.new()
	img.size = Vector2(720, 1280)
	img.pivot_offset = Vector2(360, 640)
	add_child(img)
	box = ColorRect.new()
	box.color = Color(0.02, 0.02, 0.03, 0.72)
	box.position = Vector2(30, 1010)
	box.size = Vector2(660, 220)
	box.visible = false
	add_child(box)
	name_l = G.label("", 26, Color(1, 0.82, 0.55))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(60, 1022)
	name_l.size = Vector2(600, 40)
	add_child(name_l)
	text_l = G.label("", 32, Color(1, 1, 1))
	text_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text_l.position = Vector2(60, 1068)
	text_l.size = Vector2(600, 150)
	add_child(text_l)
	sms_bg = ColorRect.new()
	sms_bg.visible = false
	add_child(sms_bg)
	sms_l = G.label("", 30, Color(1, 1, 1))
	sms_l.visible = false
	sms_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	sms_l.clip_text = false
	add_child(sms_l)
	skip_l = G.label("skip ›", 22, Color(1, 1, 1, 0.5))
	skip_l.position = Vector2(590, 1236)
	skip_l.size = Vector2(110, 40)
	add_child(skip_l)
	_run()

func _process(delta: float) -> void:
	t += delta
	panel_t += delta
	var k: float = clamp(panel_t / 14.0, 0.0, 1.0)
	img.scale = Vector2.ONE * (1.04 + 0.05 * k)
	img.position = kb_from.lerp(kb_to, k)
	if typing >= 0.0 and full_text != "":
		typing += delta * 38.0
		var n := int(typing)
		text_l.text = full_text.substr(0, n)
		if n >= full_text.length():
			typing = -1.0

func _input(e: InputEvent) -> void:
	if G.fade_rect.color.a > 0.1:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.position.y > 1220 and e.position.x > 560:
			skipping = true
			advance = true
			return
		if typing >= 0.0 and full_text != "":
			typing = -1.0
			text_l.text = full_text
		else:
			advance = true

func _wait(sec: float) -> void:
	advance = false
	var w := 0.0
	while w < sec and not advance and not skipping:
		await get_tree().process_frame
		w += get_process_delta_time()

func _run() -> void:
	await get_tree().process_frame
	if show_card:
		await _card()
	for p in panels:
		if skipping:
			break
		await _panel(p)
	G.play_amb("")
	G.lyrics_visible = true
	finished.emit()

func _card() -> void:
	var ch: Dictionary = G.chapter(chapter)
	var a := G.label(str(int(ch["age"])), 30, Color(1, 1, 1, 0.5))
	a.position = Vector2(0, 520)
	a.size = Vector2(720, 60)
	var b := G.label(ch["title"], 64, Color(1, 0.96, 0.9))
	b.position = Vector2(0, 580)
	b.size = Vector2(720, 120)
	add_child(a)
	add_child(b)
	a.modulate.a = 0
	b.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(a, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(b, "modulate:a", 1.0, 1.2)
	await _wait(2.6)
	var tw2 := create_tween()
	tw2.tween_property(a, "modulate:a", 0.0, 0.6)
	tw2.parallel().tween_property(b, "modulate:a", 0.0, 0.6)
	await tw2.finished
	a.queue_free()
	b.queue_free()

func _panel(p: Dictionary) -> void:
	img.texture = G.tex(p["img"])
	panel_t = 0.0
	var r := RandomNumberGenerator.new()
	r.seed = hash(p["img"])
	kb_from = Vector2(r.randf_range(-18, 18), r.randf_range(-24, 24))
	kb_to = Vector2(r.randf_range(-18, 18), r.randf_range(-24, 24))
	img.modulate.a = 0.0
	G.play_amb(p.get("amb", ""))
	var tw := create_tween()
	tw.tween_property(img, "modulate:a", 1.0, 0.9)
	await _wait(1.0)
	var shown := 0
	for ln in p["lines"]:
		if skipping:
			break
		if G.after and ln["who"] == "Wren":
			continue
		shown += 1
		if ln["who"] == "":
			await _caption(ln)
		elif ln["sms"]:
			await _sms(ln)
		else:
			await _say(ln)
	box.visible = false
	name_l.text = ""
	text_l.text = ""
	sms_l.visible = false
	sms_bg.visible = false
	if shown == 0:
		await _wait(3.5)
	var tw2 := create_tween()
	tw2.tween_property(img, "modulate:a", 0.0, 0.6)
	await tw2.finished

func _caption(ln: Dictionary) -> void:
	box.visible = false
	var c := G.label(ln["text"], 40, Color(0.85, 0.85, 0.88))
	c.position = Vector2(0, 560)
	c.size = Vector2(720, 120)
	c.modulate.a = 0.0
	add_child(c)
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 2.5)
	await _wait(7.0)
	var tw2 := create_tween()
	tw2.tween_property(c, "modulate:a", 0.0, 1.5)
	await tw2.finished
	c.queue_free()

func _say(ln: Dictionary) -> void:
	sms_l.visible = false
	sms_bg.visible = false
	box.visible = true
	name_l.text = ln["who"]
	full_text = ln["text"]
	text_l.text = ""
	typing = 0.0
	var dur := G.play_voice(ln["voice"])
	await _wait(max(dur + 0.9, 1.8 + full_text.length() * 0.03))
	if skipping:
		return
	if typing >= 0.0:
		typing = -1.0
		text_l.text = full_text

func _sms(ln: Dictionary) -> void:
	box.visible = false
	name_l.text = ""
	text_l.text = ""
	var mine: bool = ln["who"] == "Wren"
	var msg: String = ln["text"]
	var fs := 30
	var font: Font = sms_l.get_theme_font("font")
	var tw := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > 600.0 and fs > 18:
		fs -= 2
		tw = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	sms_l.add_theme_font_size_override("font_size", fs)
	var w: float = clamp(tw + 44.0, 140.0, 660.0)
	var x := 690.0 - w if mine else 30.0
	sms_bg.color = Color(0.24, 0.44, 0.82, 0.95) if mine else Color(0.18, 0.2, 0.26, 0.95)
	sms_bg.position = Vector2(x, 1040)
	sms_bg.size = Vector2(w, 90)
	sms_l.text = msg
	sms_l.reset_size()
	sms_l.size = Vector2(w, 90)
	sms_l.position = Vector2(x, 1040)
	sms_bg.visible = true
	sms_l.visible = true
	if not mine:
		var tl := G.label(ln["who"], 20, Color(1, 1, 1, 0.5))
		tl.position = Vector2(x, 1006)
		tl.size = Vector2(w, 30)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(tl)
		G.sfx("tap", -6, 1.4)
		await _wait(3.2)
		tl.queue_free()
	else:
		G.sfx("tap", -8, 1.1)
		await _wait(3.2)
