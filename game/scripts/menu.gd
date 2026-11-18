extends Control
signal pick(i: int)
signal back

var t := 0.0
var rows: Array = []
var erase_armed := 0.0
var erase_btn: Label

func _ready() -> void:
	size = Vector2(720, 1280)
	var bg := TextureRect.new()
	bg.texture = G.tex("title_bg")
	bg.size = Vector2(720, 1280)
	bg.modulate = Color(0.35, 0.35, 0.4)
	add_child(bg)
	var y := 170.0
	var n := 11 if (G.chapter11_open() or G.after) else 10
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
		if G.has_secret(i) and not G.after:
			var st := G.label("✦", 26, Color(1, 0.85, 0.5))
			st.position = Vector2(545, 0)
			st.size = Vector2(50, 86)
			row.add_child(st)
		row.set_meta("i", i)
		row.set_meta("open", open)
		rows.append(row)
		y += 92
	if not G.after:
		erase_btn = G.label("erase progress", 20, Color(1, 1, 1, 0.3))
		erase_btn.position = Vector2(0, 1210)
		erase_btn.size = Vector2(720, 50)
		add_child(erase_btn)

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
	for r in rows:
		if Rect2(r.position, r.size).has_point(p):
			if r.get_meta("open"):
				G.sfx("ok", -6)
				pick.emit(r.get_meta("i"))
			else:
				G.sfx("tap", -12, 0.7)
			return
	if erase_btn and p.y > 1200:
		if erase_armed > 0:
			G.erase()
			G.sfx("bad", -10)
			back.emit()
		else:
			erase_armed = 3.0
			erase_btn.text = "tap again to erase everything"
