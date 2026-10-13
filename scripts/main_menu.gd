extends Control
## Main menu (the game's first scene), after the PSX Silent Hill title screens:
##  · behind it, the real town in heavy fog, playing staged scenes from the story one after another
##    (actors posed at the motel, the bridge, the church, the Harvester at the chapel), each fading in and
##    out of black with a caption, like the title FMVs
##  · a title screen first: the logo and a blinking PRESS START; any key opens the menu
##  · the menu is a plain centred column of words: grey, the selected one white; a line of help underneath
##  · grain, dither and CRT scanlines over everything
## Pages: Main (Continue, New Game, Load Game, Extra, Dev Mode, Quit) → Difficulty, Load, Extra
## (achievements), Dev (every step of every chapter). Esc goes back; from Main, back to the title screen.

const SCENES := [  ## caption, line, camera from → to, looking at, cast [model, pos, yaw, gesture], light [pos, colour, energy]
	["LAST POSTCARD", "\"Hollowmere is beautiful. Don't come.\"",
		Vector3(-98, 1.1, 150), Vector3(-100, 1.4, 146.5), Vector3(-105, 1.5, 136),
		[["char_alex", Vector3(-104.5, 0, 138.5), PI, "look_around"]], [Vector3(-103, 3.0, 141), Color(1.0, 0.7, 0.45), 1.6]],
	["ROOM 6", "A shape behind the glass. A hiss. The smell of burning.",
		Vector3(-88, 1.3, 58), Vector3(-90, 1.6, 54.5), Vector3(-95.5, 1.4, 50),
		[["char_owen", Vector3(-95.0, 0.1, 50.2), -PI / 2.0, "window_press"]], [Vector3(-94.5, 2.6, 49), Color(1.0, 0.8, 0.5), 1.4]],
	["FOR THE NINE", "Who never came home.",
		Vector3(-19.4, 1.5, 0.5), Vector3(-19.2, 1.4, -1.6), Vector3(-19, 0.7, -5.5),
		[["char_marked_woman", Vector3(-19, 0, -4.6), PI, "slump"]], [Vector3(-18.6, 0.6, -5.4), Color(1.0, 0.55, 0.25), 1.2]],
	["CHANNEL 7", "\"They marked you. Stay in the grass.\"",
		Vector3(12.5, 1.4, 130), Vector3(11.5, 1.6, 131.5), Vector3(8.6, 1.3, 134),
		[["char_elena", Vector3(8.6, 0, 134.0), PI * 0.75, "hand_to_face"]], [Vector3(9, 2.4, 134.5), Color(0.6, 0.8, 1.0), 1.0]],
	["ST. BRENDAN", "The doors were never locked. Nobody leaves.",
		Vector3(-50, 1.5, -98), Vector3(-52, 1.6, -99), Vector3(-56.5, 1.5, -100),
		[["char_marcus", Vector3(-56.5, 0, -100), PI / 2.0, "arms_crossed"]], [Vector3(-57.5, 3.0, -100), Color(1.0, 0.6, 0.3), 1.6]],
	["THE HARVEST", "It never talks. Its footsteps are the only loud thing.",
		Vector3(-21, 1.0, -189), Vector3(-21.6, 1.3, -193), Vector3(-22, 2.2, -199),
		[], [Vector3(-21, 3.2, -195.5), Color(1.0, 0.15, 0.1), 4.0]],
]
const SCENE_TIME := 11.0
const DEV_STEPS := [
	["I", "The Mark", ["intro", "room", "hunt", "square", "sawmill", "boss", "blackout"]],
	["II", "Moth", ["c2_intro", "channel7", "zones", "traitor"]],
	["III", "The Harvest", ["c3_bell", "run", "marcus", "static", "gate", "harvest", "harvester", "shepherd", "epilogue"]],
]
const ROWS := 8  ## visible rows; longer lists scroll
const ROW_H := 17.0
const WHITE := Color(0.96, 0.95, 0.92)
const GREY := Color(0.48, 0.47, 0.45)
const DARK := Color(0.24, 0.23, 0.22)
const RED := Color(0.62, 0.08, 0.06)

var _g: Node  ## the Game autoload
var _t := 0.0
var _town: Node3D
var _cam: Camera3D
var _light: OmniLight3D
var _cast: Array[Node3D] = []
var _shot := -1
var _shot_t := 0.0
var _black: ColorRect
var _deco: Control
var _font: Font
var _title := true  ## on the PRESS START screen
var _fade := 0.0  ## menu text fade-in
var _page := ""
var _heading := ""
var _items: Array = []  ## [label, help, callback, enabled]
var _sel := 0
var _top := 0


func _ready() -> void:
	_g = G.game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sf := SystemFont.new()  # a book serif if the system has one, the default font otherwise
	sf.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"])
	_font = sf
	_build_town()
	var post := ColorRect.new()  # the game's own grain / dither over the town
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.material = ShaderMaterial.new()
	(post.material as ShaderMaterial).shader = load("res://shaders/ps2_post.gdshader")
	add_child(post)
	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_deco = Control.new()
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	var fresh := BackBufferCopy.new()  # the screen texture is copied once per frame otherwise: re-copy so the UI is in it
	fresh.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(fresh)
	var crt := ColorRect.new()  # scanlines over everything, UI included
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.material = ShaderMaterial.new()
	(crt.material as ShaderMaterial).shader = load("res://shaders/menu_crt.gdshader")
	(crt.material as ShaderMaterial).set_shader_parameter("grain", 0.09)
	add_child(crt)
	_next_shot()
	_main()
	Snd.music("menu", 2.5)


func _build_town() -> void:
	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var sub := SubViewport.new()
	view.add_child(sub)
	_town = load("res://maps/hollowmere.tscn").instantiate()
	for n in ["Chapter1", "Chapter2", "Chapter3", "Player"]:
		var c := _town.get_node_or_null(n)
		if c:
			_town.remove_child(c)
			c.free()
	sub.add_child(_town)
	var we := _town.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:  # thicker, paler fog: you see a few metres and then nothing
		var env: Environment = we.environment.duplicate()
		env.fog_light_color = Color(0.32, 0.31, 0.29)
		env.fog_density = 0.045
		env.volumetric_fog_density = 0.04
		env.volumetric_fog_albedo = Color(0.8, 0.78, 0.74)
		env.adjustment_saturation = 0.35
		we.environment = env
	_cam = Camera3D.new()
	_cam.fov = 50.0
	sub.add_child(_cam)
	_cam.current = true
	_light = OmniLight3D.new()
	_light.omni_range = 7.0
	_light.shadow_enabled = true
	_town.add_child(_light)


# ------------------------------------------------------------------ the scenes

func _next_shot() -> void:
	_shot = (_shot + 1) % SCENES.size()
	_shot_t = 0.0
	var s: Array = SCENES[_shot]
	for a in _cast:
		a.queue_free()
	_cast.clear()
	for c in s[5]:
		var a := Actor.make(_town, "res://models/%s.glb" % c[0], c[1], c[2])
		if c[3] != "":
			a.gesture(c[3])
		_cast.append(a)
	_light.position = s[6][0]
	_light.light_color = s[6][1]


func _process(delta: float) -> void:
	_t += delta
	_shot_t += delta
	var s: Array = SCENES[_shot]
	var k := clampf(_shot_t / SCENE_TIME, 0.0, 1.0)
	_cam.position = (s[2] as Vector3).lerp(s[3], k)
	_cam.look_at(s[4])
	_cam.rotation.z = sin(_t * 0.7) * 0.01  # a held camera, not a dolly
	var dark := clampf(1.5 - _shot_t, 0.0, 1.0) + clampf(_shot_t - (SCENE_TIME - 1.5), 0.0, 1.0)
	_black.color = Color(0, 0, 0, 0.2 + 0.8 * dark)
	# the light hums, now and then it stutters
	var stutter := 0.15 if fmod(_t * 7.3 + _shot * 1.7, 9.0) < 0.35 and randf() < 0.6 else 1.0
	_light.light_energy = float(s[6][2]) * stutter * (0.9 + 0.1 * sin(_t * 23.0))
	if _shot_t >= SCENE_TIME:
		_next_shot()
	_fade = move_toward(_fade, 0.0 if _title else 1.0, delta * 2.5)
	_deco.queue_redraw()


# ------------------------------------------------------------------ drawing

func _text(at_y: float, text: String, size: int, col: Color, x := -1.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := _deco.size.x if x < 0.0 else 400.0
	var p := Vector2(0.0 if x < 0.0 else x, at_y)
	_deco.draw_string(_font, p + Vector2(1, 1), text, align, w, size, Color(0, 0, 0, col.a * 0.85))
	_deco.draw_string(_font, p, text, align, w, size, col)


func _draw_deco() -> void:
	var W := _deco.size.x
	var H := _deco.size.y
	# letterbox bars, like the FMVs
	_deco.draw_rect(Rect2(0, 0, W, 22), Color.BLACK)
	_deco.draw_rect(Rect2(0, H - 22, W, 22), Color.BLACK)
	# the logo: wide-spaced letters, a thin red rule, the town under it
	var logo_y := 110.0 - 40.0 * ease(_fade, -2.0)
	_text(logo_y, "L  A  A  F", 46, Color(WHITE, 0.92))
	_deco.draw_rect(Rect2(W / 2 - 90, logo_y + 10, 180, 1), Color(RED, 0.9))
	_text(logo_y + 24, "H O L L O W M E R E", 9, Color(0.7, 0.68, 0.64, 0.9))
	# the scene's caption, bottom left, in and out with the shot
	var cap := clampf(_shot_t - 2.0, 0.0, 1.0) * clampf(SCENE_TIME - 2.0 - _shot_t, 0.0, 1.0)
	var s: Array = SCENES[_shot]
	_text(H - 46, s[0], 9, Color(RED.lightened(0.35), cap * 0.9), 26, HORIZONTAL_ALIGNMENT_LEFT)
	_text(H - 34, s[1], 8, Color(0.75, 0.72, 0.66, cap * 0.8), 26, HORIZONTAL_ALIGNMENT_LEFT)
	if _title:
		if fmod(_t, 1.6) < 1.0:
			_text(240, "PRESS START", 13, Color(WHITE, 1.0 - _fade))
		_text(H - 8, "HOLLOWMERE  POP. 1413", 7, Color(GREY, 1.0 - _fade))
		return
	var a := _fade
	if _heading != "":
		_text(152, _heading, 9, Color(0.72, 0.62, 0.5, a))
	for i in range(_top, mini(_top + ROWS, _items.size())):
		var it: Array = _items[i]
		var col := DARK if not it[3] else (WHITE if i == _sel else GREY)
		_text(_row_y(i), it[0], 13, Color(col, a))
	if _top > 0:
		_text(_row_y(_top) - 13, "▲", 7, Color(GREY, a))
	if _top + ROWS < _items.size():
		_text(_row_y(_top + ROWS - 1) + 10, "▼", 7, Color(GREY, a))
	if _sel < _items.size():
		_text(H - 8, _items[_sel][1], 8, Color(0.66, 0.63, 0.58, a))


func _row_y(i: int) -> float:
	return 176.0 + (i - _top) * ROW_H


# ------------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	var vp := get_viewport()  # taken first: an option can change the scene, after which we're out of the tree
	if _title:
		if (e is InputEventKey or e is InputEventJoypadButton or e is InputEventMouseButton) and e.is_pressed() \
				and not e.is_echo():
			_title = false
			Snd.sfx("save", null, -8.0)
			vp.set_input_as_handled()
		return
	if e.is_action_pressed("ui_down"):
		_move(1)
	elif e.is_action_pressed("ui_up"):
		_move(-1)
	elif e.is_action_pressed("ui_accept"):
		_activate()
	elif e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		if _page == "main":
			_title = true
		else:
			_main()
	elif e is InputEventMouseMotion or (e is InputEventMouseButton and e.pressed):
		var i := _top + floori((e.position.y - _row_y(_top) + ROW_H * 0.75) / ROW_H)
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				_move(1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			return
		if i < _top or i >= mini(_top + ROWS, _items.size()) or absf(e.position.x - size.x / 2) > 110 \
				or not _items[i][3]:
			return
		_sel = i
		if e is InputEventMouseButton:
			_activate()
	else:
		return
	vp.set_input_as_handled()


func _move(d: int) -> void:
	var i := _sel
	for n in _items.size():  # skip the greyed-out lines
		i = wrapi(i + d, 0, _items.size())
		if _items[i][3]:
			break
	_sel = i
	Snd.sfx("move")
	_top = clampi(_top, _sel - ROWS + 1, _sel)


func _activate() -> void:
	if _sel < _items.size() and _items[_sel][3]:
		Snd.sfx("click")
		(_items[_sel][2] as Callable).call()


func _set_page(page: String, heading: String, items: Array, sel := -1) -> void:
	_page = page
	_heading = heading
	_items = items
	_sel = sel if sel >= 0 else maxi(0, _items.find_custom(func(it: Array) -> bool: return it[3]))  # the first line you can choose
	_top = maxi(0, _sel - ROWS + 1)


# ------------------------------------------------------------------ pages

func _main() -> void:
	var saves: Array = _g.saves()
	var last: Dictionary = saves[0][1] if not saves.is_empty() else {}
	_set_page("main", "", [
		["CONTINUE", last.get("label", "No saved game yet."), func() -> void: _g.start("", "story", last), not last.is_empty()],
		["NEW GAME", "Dusk. The bridge is out. Your sister's postcard says don't come.", _difficulty, true],
		["LOAD GAME", "%d saves." % saves.size(), _load, not saves.is_empty()],
		["EXTRA", "What you've done in Hollowmere, kept across every run.", _achievements, true],
		["DEV MODE", "Start any step of any chapter. Nothing is saved, nothing unlocks.", _dev, true],
		["QUIT", "Check out of room six.", get_tree().quit, true],
	])


func _difficulty() -> void:
	var items := []
	for i in 3:
		var d: Dictionary = _g.DIFFICULTY[i]
		var blurb: String = ["Forgiving. For the story.", "As it was meant to be.", "Every round counts."][i]
		items.append([str(d.name).to_upper(), "%s   Damage ×%.1f · Enemies ×%.2f · Ammo ×%.1f" % [blurb, d.hurt, d.enemy, d.ammo],
			func() -> void:
				_g.difficulty = i
				_g.start("intro", "story"), true])
	_set_page("difficulty", "SELECT DIFFICULTY", items, 1)


func _load() -> void:
	var items := []
	for entry in _g.saves():
		var s: Dictionary = entry[1]
		var when := Time.get_datetime_string_from_unix_time(int(s.time), true).substr(5, 11)
		items.append(["No.%02d   %s   %s" % [items.size() + 1, s.get("kind", "Save"), when],
			"%s · %s · %s" % [s.label, _g.DIFFICULTY[int(s.difficulty)].name, _g._clock(float(s.run.time))],
			func() -> void: _g.start("", "story", s), true])
	_set_page("load", "LOAD GAME", items)


func _achievements() -> void:
	var items := []
	var got := 0
	for id in _g.ACHIEVEMENTS:
		var a: Array = _g.ACHIEVEMENTS[id]
		var on: bool = _g.unlocked(id)
		got += int(on)
		items.append([a[0] if on else "- - - - -", a[1] if on else "Locked. " + a[1], func() -> void: pass, true])
	_set_page("extra", "EXTRA   %d / %d" % [got, items.size()], items)


func _dev(sel := -1) -> void:
	var items := [["ALL 12 EVIDENCE: %s" % ("ON" if _g.dev_evidence else "OFF"),
		"Start holding every piece of evidence: the transmitter and the Signal ending (try CH3 · STATIC).",
		func() -> void:
			_g.dev_evidence = not _g.dev_evidence
			_dev(0), true],
		["START MARK: %s" % ("STORY" if _g.dev_mark < 0.0 else "%d%%" % int(_g.dev_mark)),
		"Start with the Mark at a set level (its notices, whispers, the heartbeat, the sightings).",
		func() -> void:
			var steps := [-1.0, 30.0, 60.0, 95.0]
			_g.dev_mark = steps[(steps.find(_g.dev_mark) + 1) % steps.size()]
			_dev(1), true]]
	for ch in DEV_STEPS:
		for st in ch[2]:
			items.append(["%s · %s" % [ch[0], st.to_upper()], "Chapter %s — %s. Normal, nothing saved." % [ch[0], ch[1]],
				func() -> void:
					_g.difficulty = 1
					_g.start(st, "dev"), true])
	_set_page("dev", "DEV MODE", items, sel)
