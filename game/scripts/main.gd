extends Node
## Screen flow.

const LEVELS := {
	1: "res://scripts/levels/l1_kite.gd",
	2: "res://scripts/levels/l2_mow.gd",
	3: "res://scripts/levels/l3_mix.gd",
	4: "res://scripts/levels/l4_stars.gd",
	5: "res://scripts/levels/l5_sort.gd",
	6: "res://scripts/levels/l6_cranes.gd",
	7: "res://scripts/levels/l7_boxes.gd",
	8: "res://scripts/levels/l8_radio.gd",
	9: "res://scripts/levels/l9_drive.gd",
	10: "res://scripts/levels/l10_tide.gd",
	11: "res://scripts/levels/l11_candles.gd",
}

var current: Node = null

func _ready() -> void:
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search")
		if typeof(q) == TYPE_STRING and q.begins_with("?lv=") and not q.contains("dev"):
			_test_level(int(q.substr(4)))
			return
		if typeof(q) == TYPE_STRING and q.begins_with("?ch="):
			start_chapter(int(q.substr(4)))
			return
	show_title(true)

func _test_level(i: int) -> void:
	var lv = load(LEVELS[i]).new()
	lv.chapter = i
	_swap(lv)
	if i != 3:
		G.play_song("c%d" % i)
	await G.fade_in(0.3)
	if not lv.emitted:
		await lv.done
	G.stop_song()
	show_menu()

func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)

func show_title(first := false) -> void:
	if not first:
		await G.fade_out(0.8)
	var t = preload("res://scripts/title.gd").new()
	t.go.connect(func(): show_menu(true))
	_swap(t)
	await G.fade_in(1.2)

func show_menu(keep_music := false) -> void:
	await G.fade_out(0.5)
	var m = preload("res://scripts/menu.gd").new()
	m.pick.connect(start_chapter)
	m.back.connect(func(): show_title())
	m.reload.connect(func(): show_menu(false))
	_swap(m)
	if not keep_music or G.song_id != "title":
		G.play_song("title")
	G.play_amb("")
	await G.fade_in(0.6)

func start_chapter(i: int) -> void:
	if i != 1:
		G.cheat_count = 0
	G.fade_song(0.8)
	await G.fade_out(0.8)
	var ch: Dictionary = G.chapter(i)
	await _cut(ch["intro"], i, true)
	await G.fade_out(0.5)
	var lv = load(LEVELS[i]).new()
	lv.chapter = i
	_swap(lv)
	G.play_amb("")
	if i == 3:
		pass  # mixing desk starts its own stems
	else:
		G.play_song("c%d" % i)
	await G.fade_in(0.8)
	if not lv.emitted:
		await lv.done
	if lv.quit_requested:
		G.cheat_count = G.cheat_count + 1 if i == 1 else 0
		G.stop_song()
		G.play_amb("")
		G.voice.stop()
		show_menu()
		return
	G.fade_song(2.0)
	await G.fade_out(1.6)
	await _cut(ch["outro"], i, false)
	G.complete_chapter(i)
	G.cheat_count = 0
	if i == 10:
		await show_credits()
	elif i == 11:
		await show_after_turn()
		return
	show_menu()

func _cut(panels: Array, i: int, intro: bool) -> void:
	var c = preload("res://scripts/cutscene.gd").new()
	c.panels = panels
	c.chapter = i
	c.show_card = intro
	_swap(c)
	await G.fade_in(0.8)
	await c.finished
	G.voice.stop()
	await G.fade_out(0.8)

func show_credits() -> void:
	var c = preload("res://scripts/credits.gd").new()
	_swap(c)
	G.play_amb("sea")
	await G.fade_in(1.5)
	await c.finished
	G.play_amb("")
	G.ending_seen = true
	G.save()
	await G.fade_out(1.0)

func show_after_turn() -> void:
	G.after = true
	G.save()
	var c := Control.new()
	c.size = Vector2(720, 1280)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(720, 1280)
	c.add_child(bg)
	_swap(c)
	G.play_amb("wind")
	await G.fade_in(0.1)
	await get_tree().create_timer(6.0).timeout
	G.play_amb("")
	await get_tree().create_timer(3.0).timeout
	G.set_after_visuals()
	show_title()
