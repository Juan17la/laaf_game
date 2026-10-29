class_name PauseMenu
extends Control
## The in-game pause menu (Game._open_pause puts it on its pause layer): the main menu's dossier set down over the
## paused game, drawn with the same pieces (scripts/menu_draw.gd) and the same Options page (scripts/options_page.gd).
##  · behind it, the game as it froze, blurred and dimmed; letterbox bars, the logo, grain and scanlines over all
##  · the folder: "Paused", the chapter, the run's time, difficulty and exact Mark as chips, the objective, then
##    Save game (greyed when saving isn't allowed: dev runs, no control), Options, Main menu (asks first) and the
##    rust RESUME bar
##  · W/S move, Enter picks, Esc / Start goes back (on the first page: resumes). The mouse points and clicks like on
##    the main menu; whatever lets the game go on fires on the button's release, so that click never reaches the gun
## Game is null-safe: with none (a test) RESUME just frees the menu.

const Menu := preload("res://scripts/main_menu.gd")
const ITEMS := [  ## id, label, icon, line under it (the last item, RESUME, is the rust bar)
	["save", "Save game", "load", "Keep your place in a new save."],
	["options", "Options", "options", "Sound, controls, language and video."],
	["menu", "Main menu", "quit", "Leave this run for the title screen."],
]
const RESUME := 3  ## the bar's place in the selection

var game: Node  ## the Game autoload (resume, save_game, to_menu)
var info := {}  ## chapter, time (a clock string), difficulty, mark, objective, pos [x, z], can_save, dev: set before it's added
var _d: MenuDraw
var _deco: Control
var _opt := OptionsPage.new()
var _page := "pause"  ## "pause", "options", "leave" (Main menu's confirmation)
var _prev_page := "pause"
var _page_t := 1.0  ## 0 → 1 after a page change (the leaf turn)
var _sel := RESUME
var _armed := []  ## [kind, index] a press landed on: its release over the same thing acts
var _born := 0  ## the frame it opened on (the Esc that opened it isn't one to close it)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # (in the tree already: offsets too, or it stays 0×0)
	mouse_filter = Control.MOUSE_FILTER_STOP  # every click is the menu's: none reaches the game
	var back := ColorRect.new()  # the paused game, blurred and dimmed
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.material = ShaderMaterial.new()
	(back.material as ShaderMaterial).shader = load("res://shaders/pause_blur.gdshader")
	add_child(back)
	_deco = Control.new()
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	_d = MenuDraw.new(_deco)
	var fresh := BackBufferCopy.new()  # re-copy the screen so the folder is in what the scanlines read
	fresh.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(fresh)
	var crt := ColorRect.new()  # scanlines over everything, UI included, as on the main menu
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.material = ShaderMaterial.new()
	(crt.material as ShaderMaterial).shader = load("res://shaders/menu_crt.gdshader")
	(crt.material as ShaderMaterial).set_shader_parameter("grain", 0.07)
	add_child(crt)
	_born = Engine.get_process_frames()
	if not _can_save() and _sel == 0:
		_sel = RESUME


func _process(delta: float) -> void:
	_page_t = move_toward(_page_t, 1.0, delta / 0.18)
	_deco.queue_redraw()


func mark_text() -> String:
	## The Mark as the chip reads it: exact to a tenth (the HUD only flashes its rises).
	return tr("Mark %.1f%%") % float(info.get("mark", 0.0))


func _can_save() -> bool:
	return bool(info.get("can_save", false))


# ------------------------------------------------------------------ drawing

func _draw_deco() -> void:
	var W := _deco.size.x
	var H := _deco.size.y
	_d.hits.clear()
	_d.a = 1.0
	_d.letterbox(W, H)
	_d.logo(W, H, 1.0)
	var f := Rect2(W - 36.0 - MenuDraw.FOLDER_W, 34, MenuDraw.FOLDER_W, H - 68)
	_d.folder(f, 1.0)
	var inner := f.grow(-MenuDraw.PAD)
	var k := ease(_page_t, 0.3)
	if k < 1.0 and _prev_page != _page:  # the leaf turn, as between the main menu's tabs
		var n := _d.hits.size()
		_d.a = 1.0 - k
		_draw_page(_prev_page, Rect2(inner.position - Vector2(k * 14.0, 0), inner.size))
		_d.hits.resize(n)  # what's leaving can't be clicked
	_d.a = k
	_draw_page(_page, Rect2(inner.position + Vector2((1.0 - k) * 14.0, 0), inner.size))
	_d.a = 1.0
	var keys: Array
	match _page:
		"pause":
			keys = [["ESC", tr("Resume"), "back"], ["ENTER", tr("Select"), "accept"], ["W S", tr("Move")]]
		"options":
			keys = [["ESC", tr("Back"), "back"], ["ENTER", tr("Select"), "accept"], ["A D", tr("Adjust")], ["W S", tr("Move")]]
		_:
			keys = [["ESC", tr("Back"), "back"], ["ENTER", tr("Select"), "accept"]]
	_d.help(keys, W - 36.0, H - 9.0, 1.0)


func _draw_page(page: String, r: Rect2) -> void:
	match page:
		"pause": _page_pause(r)
		"options": _opt.draw(_d, r, true)
		"leave": _page_leave(r)


func _page_pause(r: Rect2) -> void:
	var x := r.position.x
	_d.heading(x, r.position.y + 16, tr("Paused"))
	var ch := clampi(int(info.get("chapter", 1)), 1, 3)
	_d.text(_d.serif_it, Vector2(x, r.position.y + 32), _d.fit(_d.serif_it, tr("Chapter %s") % tr(Menu.CHAPTERS[ch]), 10,
		r.size.x), 10, _d.c(MenuDraw.MUTED))
	var y := r.position.y + 40.0
	var cx := x
	cx += _d.chip(cx, y, "clock", str(info.get("time", "0:00:00"))) + 4.0
	cx += _d.chip(cx, y, "flame", tr(str(info.get("difficulty", "Normal")))) + 4.0
	_d.chip(cx, y, "mark", mark_text(), Color(MenuDraw.RUST, 0.32))
	y += 22.0
	var objective := str(info.get("objective", ""))
	if objective != "":  # what's next, as the Continue page shows it
		var nb := Rect2(x, y, r.size.x, 30)
		Icons.fill_round(_deco, nb, 8.0, _d.c(MenuDraw.AMBER, 0.08))
		var next := tr("NEXT")
		var nx := maxf(34.0, _d.caps.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 14.0)
		_d.text(_d.caps, nb.position + Vector2(8, 12), next, 7, _d.c(MenuDraw.AMBER))
		_d.wrap(_d.ui, nb.position + Vector2(nx, 12.5), tr(objective), 8, _d.c(MenuDraw.BONE), nb.size.x - nx - 8.0, 2)
		y += 40.0
	for i in ITEMS.size():
		var it: Array = ITEMS[i]
		var row := Rect2(x, y + i * 34.0, r.size.x, 30)
		var off := i == 0 and not _can_save()  # greyed: a fainter slip, a lock, and why in its line
		var on := i == _sel and not off
		if off:
			Icons.fill_round(_deco, row, 7.0, _d.c(MenuDraw.BONE, 0.02))
		else:
			_d.row_box(row, on)
			_d.hits.append([row, "row", i])
		Icons.draw(_deco, "lock" if off else it[2], row.position + Vector2(17, 15), 12.0,
			_d.c(MenuDraw.FAINT if off else (MenuDraw.AMBER if on else MenuDraw.MUTED)), 1.3)
		var tx := row.position.x + 38.0
		_d.text(_d.caps, Vector2(tx, row.position.y + 13), tr(it[1]).to_upper(), 8,
			_d.c(MenuDraw.MUTED if off else MenuDraw.BONE))
		var line: String = tr(it[3])
		if off:
			line = tr("Dev runs aren't saved.") if info.get("dev", false) else tr("You can't save right now.")
		_d.text(_d.ui, Vector2(tx, row.position.y + 23.5), _d.fit(_d.ui, line, 7, row.end.x - tx - 6.0), 7,
			_d.c(MenuDraw.MUTED))
	_d.bar(Rect2(x, r.end.y - MenuDraw.BAR_H, r.size.x, MenuDraw.BAR_H), tr("RESUME"), "play", _sel == RESUME)


func _page_leave(r: Rect2) -> void:
	_d.heading(r.position.x, r.position.y + 16, tr("Leave this run?"))
	_d.wrap(_d.serif_it, Vector2(r.position.x, r.position.y + 36),
		tr("Back to the title screen. Anything since your last save is lost."), 10, _d.c(MenuDraw.MUTED), r.size.x, 3)
	var pos: Variant = info.get("pos", null)  # where you'd be leaving off, as the main menu's Quit page shows it
	_d.photo(Rect2(r.position.x + 10, r.position.y + 70, r.size.x - 20, 104), pos, 0.03, tr(Menu._place(pos)))
	_d.bar(Rect2(r.position.x, r.end.y - MenuDraw.BAR_H, r.size.x, MenuDraw.BAR_H), tr("Main menu").to_upper(), "quit",
		true)


# ------------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	## Keys and pad (the mouse comes in through _gui_input).
	if Engine.get_process_frames() == _born:
		return
	if e.is_action_pressed("ui_down") or e.is_action_pressed("move_back"):
		_nav(0, 1)
	elif e.is_action_pressed("ui_up") or e.is_action_pressed("move_forward"):
		_nav(0, -1)
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		_nav(1, 0)
	elif e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		_nav(-1, 0)
	elif e.is_action_pressed("ui_accept"):
		_accept()
	elif e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		_back()
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _gui_input(e: InputEvent) -> void:
	## The mouse, as on the main menu: pointing selects, a left click picks, a right click goes back, the wheel scrolls
	## or adjusts on the Options page. Picks act on the release (over the same thing they were pressed on).
	if not e is InputEventMouse:
		return
	accept_event()
	var h := _d.point(e.position)
	var b := e as InputEventMouseButton
	if e is InputEventMouseMotion:
		if _opt.dragging():
			_opt.motion(e.position)
		else:
			_point(h)
		return
	if b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if b.pressed and _page == "options":
			_opt.wheel(h, 1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		return
	if b.pressed:
		_armed = []
		if b.button_index == MOUSE_BUTTON_RIGHT:
			_armed = ["right", 0]
		elif b.button_index == MOUSE_BUTTON_LEFT and not h.is_empty():
			if _page == "options" and h[1] in ["row", "track", "value"]:
				_opt.press(h, e.position)
			else:
				_armed = [h[1], h[2]]
		return
	if b.button_index == MOUSE_BUTTON_LEFT:
		_opt.release()
	var armed := _armed
	_armed = []
	if armed.is_empty():
		return
	if armed[0] == "right":
		if b.button_index == MOUSE_BUTTON_RIGHT:
			_back()
	elif b.button_index == MOUSE_BUTTON_LEFT and not h.is_empty() and h[1] == armed[0] and h[2] == armed[1]:
		_click(h)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _d:  # the pointer left the window: nothing stays lit under it
		_d.point(Vector2(-1e6, -1e6))


func _point(h: Array) -> void:
	if h.is_empty():
		return
	match _page:
		"pause":
			var i: int = RESUME if h[1] == "bar" else (h[2] if h[1] == "row" else _sel)
			if i != _sel:
				_sel = i
				Snd.sfx("move")
		"options":
			_opt.hover(h)


func _click(h: Array) -> void:
	match h[1]:
		"hint":
			if h[2] == 0:
				_back()
			else:
				_accept()
		"bar":
			if _page == "leave":
				_accept()
			else:
				_act(RESUME)
		"row":
			if _page == "pause":
				_act(h[2])


func _nav(dx: int, dy: int) -> void:
	match _page:
		"pause":
			if dy == 0:
				return
			_sel = wrapi(_sel + dy, 0, RESUME + 1)
			if _sel == 0 and not _can_save():  # (a greyed Save game is passed over)
				_sel = wrapi(_sel + dy, 0, RESUME + 1)
			Snd.sfx("move")
		"options":
			_opt.nav(dx, dy)


func _accept() -> void:
	match _page:
		"pause": _act(_sel)
		"options": _opt.accept()
		"leave":
			Snd.sfx("click")
			if game:
				game.to_menu()


func _act(i: int) -> void:
	match i:
		0:
			if not _can_save():
				return
			Snd.sfx("click")
			if game:
				game.save_game(game.manual_slot(), "Manual save")
			_resume()
		1:
			_opt.enter()
			_turn("options")
		2:
			_turn("leave")
		RESUME:
			_resume()


func _back() -> void:
	match _page:
		"pause":
			_resume()
		"options":
			_sel = 1
			_turn("pause")
		"leave":
			_sel = 2
			_turn("pause")


func _turn(page: String) -> void:
	_prev_page = _page
	_page = page
	_page_t = 0.0
	Snd.sfx("click" if page != "pause" else "move")


func _resume() -> void:
	Snd.sfx("click")
	if game:
		game.resume()
	else:
		queue_free()
