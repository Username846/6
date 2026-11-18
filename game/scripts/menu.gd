extends Control
signal pick(i: int)
signal back
signal reload

var t := 0.0
var rows: Array = []
var erase_armed := 0.0
var erase_btn: Label
var cheats_btn: Label
const CHEATS_RECT := Rect2(10, 1200, 170, 64)
const ERASE_RECT := Rect2(220, 1200, 280, 64)
var cheat_panel: Control = null
var cheat_rows: Array = []
var top_taps := 0
var bottom_taps := 0

func _ready() -> void:
	size = Vector2(720, 1280)
	var bg := TextureRect.new()
	bg.texture = G.tex("title_bg")
	bg.size = Vector2(720, 1280)
	bg.modulate = Color(0.35, 0.35, 0.4)
	add_child(bg)
	var y := 170.0
	var n := 10
	for i in range(1, n + 1):
		var ch: Dictionary = G.chapter(i)
		var open := i <= G.unlocked or (i == 11 and G.chapter11_open())
		if G.after and i == 11:
			open = false
		var row := Control.new()
		row.position = Vector2(60, y)
		row.size = Vector2(600, 86)
		add_child(row)
		var num := G.label(str(i), 30, Color(1, 1, 1, 0.5))
		num.position = Vector2(0, 0)
		num.size = Vector2(60, 86)
		row.add_child(num)
		var name: String = "· · ·" if not open else str(ch["title"])
		if G.after and i == 11:
			name = "———"
		var lb := G.label(name, 38, Color(1, 0.96, 0.9) if open else Color(1, 1, 1, 0.25))
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb.position = Vector2(70, 0)
		lb.size = Vector2(420, 86)
		row.add_child(lb)
		if open and i <= 10:
			var age := G.label(str(int(ch["age"])), 24, Color(1, 1, 1, 0.45))
			age.position = Vector2(480, 0)
			age.size = Vector2(70, 86)
			row.add_child(age)
		row.set_meta("i", i)
		row.set_meta("open", open)
		rows.append(row)
		y += 92
	if not G.after:
		erase_btn = G.label("erase progress", 20, Color(1, 1, 1, 0.3))
		erase_btn.position = Vector2(0, 1210)
		erase_btn.size = Vector2(720, 50)
		add_child(erase_btn)
	if G.cheats_unlocked:
		cheats_btn = G.label("cheats", 22, Color(1, 0.85, 0.5, 0.55))
		cheats_btn.position = CHEATS_RECT.position + Vector2(0, 8)
		cheats_btn.size = Vector2(CHEATS_RECT.size.x, 48)
		add_child(cheats_btn)

func _cheat_options() -> Array:
	return [
		["Unlock all chapters", func():
			G.unlocked = 10
			G.after = false],
		["Changed world: " + ("ON" if G.after else "OFF"), func():
			G.after = not G.after],
		["Level skip button: " + ("ON" if G.cheat_skip else "OFF"), func():
			G.cheat_skip = not G.cheat_skip],
		["Erase progress", func():
			G.erase()],
		["Erase progress + lock cheats", func():
			G.erase()
			G.cheats_unlocked = false
			G.cheat_skip = false],
		["Close", func(): pass],
	]

func _open_cheats() -> void:
	G.cheats_unlocked = true
	G.save()
	G.sfx("secret", -10)
	cheat_panel = Control.new()
	cheat_panel.size = Vector2(720, 1280)
	cheat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cheat_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.size = Vector2(720, 1280)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cheat_panel.add_child(dim)
	var title := G.label("CHEATS", 44, Color(1, 0.85, 0.5))
	title.position = Vector2(0, 200)
	title.size = Vector2(720, 70)
	cheat_panel.add_child(title)
	var y := 320.0
	for opt in _cheat_options():
		var bg := ColorRect.new()
		bg.color = Color(1, 1, 1, 0.08)
		bg.position = Vector2(110, y)
		bg.size = Vector2(500, 84)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cheat_panel.add_child(bg)
		var lb := G.label(opt[0], 30, Color(1, 1, 1, 0.9))
		lb.position = bg.position
		lb.size = bg.size
		cheat_panel.add_child(lb)
		cheat_rows.append([Rect2(bg.position, bg.size), opt[1], opt[0]])
		y += 100.0

func _pick_cheat(row: Array) -> void:
	var f: Callable = row[1]
	f.call()
	G.save()
	G.set_after_visuals()
	G.sfx("ok", -8)
	cheat_panel.queue_free()
	cheat_panel = null
	cheat_rows.clear()
	if row[2] != "Close":
		reload.emit()

func _process(delta: float) -> void:
	t += delta
	if erase_armed > 0:
		erase_armed -= delta
		if erase_armed <= 0 and erase_btn:
			erase_btn.text = "erase progress"

func _input(e: InputEvent) -> void:
	if G.fade_rect.color.a > 0.1:
		return
	if not (e is InputEventMouseButton and e.pressed):
		return
	var p: Vector2 = e.position
	if cheat_panel != null:
		for cr in cheat_rows:
			if cr[0].has_point(p):
				_pick_cheat(cr)
				return
		return
	# secret: 3 taps at the very top, then 3 taps at the very bottom
	if p.y < 150:
		if bottom_taps > 0:
			top_taps = 0
			bottom_taps = 0
		top_taps += 1
		return
	if p.y > 1190 and top_taps >= 3:
		bottom_taps += 1
		if bottom_taps >= 3:
			top_taps = 0
			bottom_taps = 0
			_open_cheats()
		return
	top_taps = 0
	bottom_taps = 0
	for r in rows:
		if Rect2(r.position, r.size).has_point(p):
			if r.get_meta("open"):
				G.sfx("ok", -6)
				pick.emit(r.get_meta("i"))
			else:
				G.sfx("tap", -12, 0.7)
			return
	if cheats_btn and CHEATS_RECT.has_point(p):
		_open_cheats()
		return
	if erase_btn and ERASE_RECT.has_point(p):
		if erase_armed > 0:
			G.erase()
			G.sfx("bad", -10)
			back.emit()
		else:
			erase_armed = 3.0
			erase_btn.text = "tap again to erase everything"
