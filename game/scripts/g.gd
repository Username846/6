extends Node
## Global state, audio, lyrics overlay, save data.

const SAVE_PATH := "user://wren.cfg"

var story: Dictionary = {}
var chapters: Array = []
var secrets_text: Dictionary = {}
var songs: Dictionary = {}

# progress
var unlocked := 1
var completed := {}
var secrets := {}
var after := false
var ending_seen := false
var cheat_skip := false
var cheat_count := 0

# audio
var music: AudioStreamPlayer
var stems: Array = []
var amb: AudioStreamPlayer
var voice: AudioStreamPlayer
var sfx_pool: Array = []
var _sfx_i := 0
var song_id := ""
var song_len := 180.0
var _song_clock := 0.0
var _song_playing := false
var _song_loop := true

# overlays
var lyric_layer: CanvasLayer
var lyric_cur: Label
var lyric_next: Label
var lyric_bg: ColorRect
var lyrics_visible := true
var fx_layer: CanvasLayer
var fade_rect: ColorRect
var secret_label: Label
var desat_layer: CanvasLayer
var desat_rect: ColorRect

var _cache := {}
var dev := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search")
		dev = typeof(q) == TYPE_STRING and q.contains("dev")
	_load_story()
	_load_save()
	if dev:
		var q2 = JavaScriptBridge.eval("location.search")
		if str(q2).contains("after"):
			after = true
			unlocked = 10
	_build_audio()
	_build_overlays()
	set_after_visuals()

# ---------------------------------------------------------------- data
func _read_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing " + path)
		return null
	return JSON.parse_string(f.get_as_text())

func _load_story() -> void:
	story = _read_json("res://data/story.json")
	chapters = story["chapters"]
	secrets_text = story["secrets"]
	for id in ["title", "c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10", "c11"]:
		var d = _read_json("res://data/lyrics_%s.json" % id)
		if d != null:
			songs[id] = d

func chapter(i: int) -> Dictionary:
	return chapters[i - 1]

func secret_count() -> int:
	var n := 0
	for k in secrets:
		if secrets[k]:
			n += 1
	return n

func has_secret(i: int) -> bool:
	return secrets.get(str(i), false)

func all_secrets() -> bool:
	for i in range(1, 11):
		if not has_secret(i):
			return false
	return true

func chapter11_open() -> bool:
	return completed.get("10", false) and not after

# ---------------------------------------------------------------- save
func _load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	unlocked = cf.get_value("p", "unlocked", 1)
	completed = cf.get_value("p", "completed", {})
	secrets = cf.get_value("p", "secrets", {})
	after = cf.get_value("p", "after", false)
	ending_seen = cf.get_value("p", "ending_seen", false)
	cheat_skip = cf.get_value("p", "cheat_skip", false)

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "unlocked", unlocked)
	cf.set_value("p", "completed", completed)
	cf.set_value("p", "secrets", secrets)
	cf.set_value("p", "after", after)
	cf.set_value("p", "ending_seen", ending_seen)
	cf.set_value("p", "cheat_skip", cheat_skip)
	cf.save(SAVE_PATH)

func erase() -> void:
	unlocked = 1
	completed = {}
	secrets = {}
	after = false
	ending_seen = false
	save()

func complete_chapter(i: int) -> void:
	completed[str(i)] = true
	unlocked = max(unlocked, min(i + 1, 10))
	save()

func find_secret(i: int) -> bool:
	if after or has_secret(i):
		return false
	secrets[str(i)] = true
	save()
	sfx("secret")
	show_secret(secrets_text[str(i)])
	return true

# ---------------------------------------------------------------- resources
func res(path: String):
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

func tex(name: String) -> Texture2D:
	var p := "res://art/cut/%s.jpg" % name
	if after:
		var px := "res://art/cut/%s_x.jpg" % name
		if ResourceLoader.exists(px):
			p = px
	return res(p)

# ---------------------------------------------------------------- audio
func _build_audio() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in 4:
		var s := AudioStreamPlayer.new()
		add_child(s)
		stems.append(s)
	amb = AudioStreamPlayer.new()
	amb.volume_db = -10
	add_child(amb)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)

func play_song(id: String, loop := true, stem_names: Array = []) -> void:
	stop_song()
	song_id = id
	_song_loop = loop
	song_len = songs.get(id, {}).get("dur", 180.0)
	var pitch := 0.86 if after else 1.0
	if stem_names.is_empty():
		var st: AudioStreamOggVorbis = res("res://audio/music/%s.ogg" % id)
		st.loop = loop
		music.stream = st
		music.pitch_scale = pitch
		music.volume_db = -2.0 if not after else -5.0
		music.play()
	else:
		for i in stem_names.size():
			var st2: AudioStreamOggVorbis = res("res://audio/music/%s_%s.ogg" % [id, stem_names[i]])
			st2.loop = loop
			stems[i].stream = st2
			stems[i].pitch_scale = pitch
			stems[i].volume_db = 0.0
		for i in stem_names.size():
			stems[i].play()
	_song_clock = 0.0
	_song_playing = true

func stop_song() -> void:
	music.stop()
	for s in stems:
		s.stop()
	_song_playing = false
	song_id = ""

func fade_song(dur := 1.5) -> void:
	if not _song_playing:
		return
	var tw := create_tween()
	tw.tween_property(music, "volume_db", -40.0, dur)
	for s in stems:
		tw.parallel().tween_property(s, "volume_db", -40.0, dur)
	tw.tween_callback(stop_song)

func song_time() -> float:
	return _song_clock

func play_amb(name: String) -> void:
	if name == "":
		amb.stop()
		return
	var p := "res://audio/sfx/amb_%s.ogg" % name
	var st: AudioStreamOggVorbis = res(p)
	st.loop = true
	if amb.stream == st and amb.playing:
		return
	amb.stream = st
	amb.pitch_scale = 0.9 if after else 1.0
	amb.play()

func play_voice(id: String) -> float:
	var p := "res://audio/voice/%s.ogg" % id
	if not ResourceLoader.exists(p):
		return 0.0
	var st: AudioStream = res(p)
	voice.stream = st
	voice.pitch_scale = 0.9 if after else 1.0
	voice.play()
	return st.get_length() / voice.pitch_scale

func sfx(name: String, vol := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = sfx_pool[_sfx_i]
	_sfx_i = (_sfx_i + 1) % sfx_pool.size()
	p.stream = res("res://audio/sfx/%s.ogg" % name)
	p.volume_db = vol
	p.pitch_scale = pitch * (0.9 if after else 1.0)
	p.play()
	return p

func loop_sfx(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var st: AudioStreamOggVorbis = res("res://audio/sfx/%s.ogg" % name)
	st.loop = true
	p.stream = st
	return p

# ---------------------------------------------------------------- overlays
func _build_overlays() -> void:
	lyric_layer = CanvasLayer.new()
	lyric_layer.layer = 20
	add_child(lyric_layer)
	lyric_bg = ColorRect.new()
	lyric_bg.position = Vector2.ZERO
	lyric_bg.size = Vector2(720, 112)
	lyric_bg.color = Color(0, 0, 0, 0.55)
	lyric_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lyric_layer.add_child(lyric_bg)
	lyric_cur = _mk_label(30, Color(1, 0.97, 0.9))
	lyric_cur.position = Vector2(20, 14)
	lyric_cur.size = Vector2(680, 56)
	lyric_layer.add_child(lyric_cur)
	lyric_next = _mk_label(20, Color(1, 1, 1, 0.42))
	lyric_next.position = Vector2(20, 70)
	lyric_next.size = Vector2(680, 34)
	lyric_layer.add_child(lyric_next)

	desat_layer = CanvasLayer.new()
	desat_layer.layer = 18
	add_child(desat_layer)
	desat_rect = ColorRect.new()
	desat_rect.size = Vector2(720, 1280)
	desat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.88;
void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c.rgb, vec3(l) * vec3(0.9, 0.95, 1.02), amount);
	vec2 d = SCREEN_UV - vec2(0.5);
	g *= 0.82 - dot(d, d) * 0.9;
	COLOR = vec4(g, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	desat_rect.material = mat
	desat_layer.add_child(desat_rect)

	fx_layer = CanvasLayer.new()
	fx_layer.layer = 30
	add_child(fx_layer)
	secret_label = _mk_label(28, Color(1, 0.95, 0.8))
	secret_label.position = Vector2(50, 560)
	secret_label.size = Vector2(620, 200)
	secret_label.modulate.a = 0.0
	fx_layer.add_child(secret_label)
	fade_rect = ColorRect.new()
	fade_rect.size = Vector2(720, 1280)
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(fade_rect)

func _mk_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func label(text: String, size: int, col := Color.WHITE) -> Label:
	var l := _mk_label(size, col)
	l.text = text
	return l

func set_after_visuals() -> void:
	desat_layer.visible = after

func show_secret(text: String) -> void:
	secret_label.text = text
	var tw := create_tween()
	tw.tween_property(secret_label, "modulate:a", 1.0, 1.2)
	tw.tween_interval(4.5)
	tw.tween_property(secret_label, "modulate:a", 0.0, 1.5)

func fade_out(dur := 0.6) -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, dur)
	await tw.finished

func fade_in(dur := 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, dur)
	await tw.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if _song_playing:
		var pitch := 0.86 if after else 1.0
		_song_clock += delta * pitch
		if _song_loop and _song_clock >= song_len:
			_song_clock = fmod(_song_clock, song_len)
	_update_lyrics()

func _update_lyrics() -> void:
	var show: bool = lyrics_visible and _song_playing and songs.has(song_id) and not songs[song_id]["lyrics"].is_empty()
	lyric_layer.visible = show
	if not show:
		return
	var t := _song_clock
	var lines: Array = songs[song_id]["lyrics"]
	var cur := ""
	var nxt := ""
	for i in lines.size():
		var ln: Dictionary = lines[i]
		var st: float = ln["t"] - 0.35
		var en: float = ln["e"] + 0.8
		if i + 1 < lines.size():
			en = min(en, float(lines[i + 1]["t"]) - 0.35)
		if t >= st and t < en:
			cur = ln["text"]
			if i + 1 < lines.size() and float(lines[i + 1]["t"]) - t < 6.0:
				nxt = lines[i + 1]["text"]
			break
		if t < st:
			if st - t < 2.5:
				nxt = ln["text"]
			break
	if cur == "" and nxt == "":
		cur = "· · ·"
	lyric_cur.text = cur
	lyric_next.text = nxt
	if after:
		lyric_cur.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	else:
		lyric_cur.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
