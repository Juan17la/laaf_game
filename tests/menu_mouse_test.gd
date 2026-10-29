extends SceneTree
## Headless check of the mouse in the menus, with real input events pushed through the viewport (the GUI pass first,
## as a player's mouse goes):
##   main menu: a click leaves the title screen; a click opens a tab; pointing at a row selects it (the one selection
##   the keys move too); the wheel scrolls a list, adjusts a meter under it and scrolls Options elsewhere; a meter's
##   track is dragged to a value and a multiplier dragged sideways; a toggle flips on a click; a right click and the
##   ESC hint go back; on New, pointing at a card only shows it, a click picks it and BEGIN starts with that one;
##   the keys still work after all of it
##   pause menu (scripts/pause_menu.gd): pointing selects, a greyed Save game can't be pointed at or reached by keys,
##   Options opens the same Options page (dragged the same way), a right click goes back, Main menu asks first,
##   RESUME acts on the button's release (so the click never reaches the gun), not on its press
## The settings file is put back as it was. godot --headless --path . -s tests/menu_mouse_test.gd

const CFG := "user://settings.cfg"
const GAME_STUB := """extends "res://scripts/game.gd"
var started := []
func start(step: String, run_mode: String, save := {}) -> void:
	started = [step, run_mode]
"""
const PAUSE_STUB := """extends Node
var resumed := false
var left := false
func resume() -> void:
	resumed = true
func to_menu() -> void:
	left = true
func save_game(slot: String, kind := "Save") -> bool:
	return false
func manual_slot() -> String:
	return "none"
"""

var _bad := 0
var _cfg_backup: Variant = null


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_bad += 1
		push_error("MOUSE FAIL: " + msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _stub(src: String) -> Object:
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s.new()


# ------------------------------------------------------------------ events

func _move(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	root.push_input(m, true)
	await _frames(2)


func _button(p: Vector2, index: MouseButton, pressed: bool) -> void:
	var b := InputEventMouseButton.new()
	b.position = p
	b.global_position = p
	b.button_index = index
	b.pressed = pressed
	root.push_input(b, true)
	await _frames(2)


func _click(p: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	await _button(p, index, true)
	await _button(p, index, false)


func _wheel(p: Vector2, up: bool) -> void:
	await _button(p, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, true)
	await _button(p, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, false)


func _key(action: String) -> void:
	var a := InputEventAction.new()
	a.action = action
	a.pressed = true
	root.push_input(a)
	await _frames(2)


func _at(hits: Array, kind: String, i := 0) -> Rect2:
	## Where the last draw put hit (kind, i); an empty rect (and a failure) if it isn't there.
	for h in hits:
		if h[1] == kind and h[2] == i:
			return h[0]
	_check(false, "nothing drawn for %s %d" % [kind, i])
	return Rect2()


# ------------------------------------------------------------------ main menu

func _main_menu() -> void:
	var menu: Control = load("res://maps/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _frames(3)
	var g: Object = _stub(GAME_STUB)
	menu._g = g
	menu._saves = []
	await _click(Vector2(100, 100))
	_check(not menu._title, "a click didn't leave the title screen")
	while menu._fade < 1.0:
		await process_frame
	await _frames(2)
	var hits: Array = menu._hits
	# a tab, clicked
	var dev: int = menu.TABS.find_custom(func(t: Array) -> bool: return t[0] == "dev")
	await _click(_at(hits, "tab", dev).get_center())
	_check(menu._tab == dev, "a click on the DEV tab opened tab %d" % menu._tab)
	while menu._page_t < 1.0:
		await process_frame
	await _frames(2)
	# pointing selects; the keys go on from there
	_check(menu._focus == "tabs", "focus before pointing: %s" % menu._focus)
	await _move(_at(hits, "row", 3).get_center())
	_check(menu._focus == "page" and menu._sel == 3, "pointing at row 3: focus %s, sel %d" % [menu._focus, menu._sel])
	await _key("ui_down")
	_check(menu._sel == 4, "the keys after pointing: sel %d, not 4" % menu._sel)
	await _frames(2)
	await _move(_at(hits, "row", 4).get_center() + Vector2(1, 0))  # (the same row: nothing changes)
	_check(menu._sel == 4, "a still row moved the selection to %d" % menu._sel)
	# the wheel scrolls the list
	await _wheel(_at(hits, "row", 4).get_center(), false)
	_check(menu._top == 1, "the wheel didn't scroll Dev (top %d)" % menu._top)
	await _wheel(_at(hits, "row", 4).get_center(), true)
	_check(menu._top == 0, "the wheel didn't scroll Dev back (top %d)" % menu._top)
	# a right click goes back, like Esc; then the keys change tabs again
	await _click(Vector2(10, 200), MOUSE_BUTTON_RIGHT)
	_check(menu._focus == "tabs", "a right click didn't go back (focus %s)" % menu._focus)
	await _key("ui_up")
	var options: int = menu.TABS.find_custom(func(t: Array) -> bool: return t[0] == "options")
	_check(menu._tab == options, "the keys after the mouse: tab %d, not Options" % menu._tab)
	while menu._page_t < 1.0:
		await process_frame
	await _frames(2)
	# Options: the same page the pause menu shows
	var opt: OptionsPage = menu._opt
	var music: int = opt.ids.find("audio/music")
	var sens: int = opt.ids.find("controls/mouse_sensitivity")
	var invert: int = opt.ids.find("controls/invert_y")
	await _move(_at(hits, "row", music).position + Vector2(10, 8))
	_check(menu._focus == "page" and opt.sel == music, "pointing at Music: focus %s, sel %d" % [menu._focus, opt.sel])
	var track := _at(hits, "track", music)
	await _button(track.position + Vector2(4, 8), MOUSE_BUTTON_LEFT, true)
	_check(is_zero_approx(Settings.number("audio/music")), "a press at the track's start: %.2f" % Settings.number("audio/music"))
	await _move(track.get_center())
	await _button(track.get_center(), MOUSE_BUTTON_LEFT, false)
	_check(is_equal_approx(Settings.number("audio/music"), 0.5), "dragged to the middle: %.2f" % Settings.number("audio/music"))
	await _wheel(track.get_center(), true)
	_check(is_equal_approx(Settings.number("audio/music"), 0.6), "the wheel over the meter: %.2f" % Settings.number("audio/music"))
	var v := _at(hits, "value", sens)
	var before := Settings.number("controls/mouse_sensitivity")
	await _button(v.get_center(), MOUSE_BUTTON_LEFT, true)
	await _move(v.get_center() + Vector2(15, 0))
	await _button(v.get_center() + Vector2(15, 0), MOUSE_BUTTON_LEFT, false)
	_check(Settings.number("controls/mouse_sensitivity") > before + 0.4, "dragging the sensitivity: %.1f → %.1f" %
		[before, Settings.number("controls/mouse_sensitivity")])
	var inv := Settings.flag("controls/invert_y")
	await _click(_at(hits, "row", invert).position + Vector2(10, 8))
	_check(Settings.flag("controls/invert_y") != inv and opt.sel == invert, "a click on Invert didn't flip it")
	await _key("ui_down")
	_check(opt.sel == invert + 1, "the keys on Options after the mouse: sel %d" % opt.sel)
	var label_at := _at(hits, "row", opt.sel).position + Vector2(10, 8)
	var top: int = opt.top
	await _wheel(label_at, false)
	_check(opt.top == top + 1, "the wheel off a value didn't scroll Options (%d → %d)" % [top, opt.top])
	# the ESC hint is a back button
	await _click(_at(hits, "hint", 0).get_center())
	_check(menu._focus == "tabs", "the ESC hint didn't go back (focus %s)" % menu._focus)
	# New: a card only shows while pointed at, a click picks it, BEGIN starts with it
	var new: int = menu.TABS.find_custom(func(t: Array) -> bool: return t[0] == "new")
	await _click(_at(hits, "tab", new).get_center())
	while menu._page_t < 1.0:
		await process_frame
	await _frames(2)
	g.difficulty = 1
	await _click(_at(hits, "row", 2).get_center())
	_check(g.difficulty == 2 and menu._sel == 2, "a click on Hard: difficulty %d" % g.difficulty)
	await _move(_at(hits, "row", 0).get_center())
	_check(menu._sel == 0 and g.difficulty == 2, "pointing at Easy picked it (difficulty %d)" % g.difficulty)
	var bar := _at(hits, "bar")
	await _move(bar.get_center())
	_check(menu._sel == 2, "off the cards, the shown card isn't the picked one (%d)" % menu._sel)
	await _click(bar.get_center())
	_check(g.started == ["intro", "story"] and g.difficulty == 2, "BEGIN: %s, difficulty %d" % [g.started, g.difficulty])
	menu.queue_free()
	await _frames(3)
	g.free()  # (after the menu: it draws with it to the last)


# ------------------------------------------------------------------ pause menu

func _pause_menu() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var game: Node = _stub(PAUSE_STUB)
	root.add_child(game)
	var pm := PauseMenu.new()
	pm.game = game
	pm.info = {"chapter": 2, "time": "0:12:34", "difficulty": "Normal", "mark": 37.4,
		"objective": "Get inside the school", "can_save": false, "dev": true}
	layer.add_child(pm)
	await _frames(3)
	var hits: Array = pm._d.hits
	_check(pm._sel == PauseMenu.RESUME, "the pause menu doesn't open on RESUME (%d)" % pm._sel)
	_check(not hits.any(func(h: Array) -> bool: return h[1] == "row" and h[2] == 0), "a greyed Save game can be pointed at")
	await _move(_at(hits, "row", 1).get_center())
	_check(pm._sel == 1, "pointing at Options: sel %d" % pm._sel)
	await _key("ui_down")
	await _key("ui_down")
	_check(pm._sel == PauseMenu.RESUME, "keys after pointing: sel %d" % pm._sel)
	await _key("ui_down")
	_check(pm._sel == 1, "the keys stopped on a greyed Save game (sel %d)" % pm._sel)
	# Options: the shared page, dragged the same way
	await _click(_at(hits, "row", 1).get_center())
	_check(pm._page == "options", "a click on Options opened '%s'" % pm._page)
	while pm._page_t < 1.0:
		await process_frame
	await _frames(2)
	var music: int = pm._opt.ids.find("audio/music")
	var track := _at(hits, "track", music)
	await _button(track.position + Vector2(4, 8), MOUSE_BUTTON_LEFT, true)
	await _move(track.end - Vector2(4, 8))
	await _button(track.end - Vector2(4, 8), MOUSE_BUTTON_LEFT, false)
	_check(is_equal_approx(Settings.number("audio/music"), 1.0), "dragged to the end in the pause menu: %.2f" %
		Settings.number("audio/music"))
	await _click(Vector2(10, 200), MOUSE_BUTTON_RIGHT)
	_check(pm._page == "pause" and pm._sel == 1, "a right click on Options: page '%s', sel %d" % [pm._page, pm._sel])
	while pm._page_t < 1.0:
		await process_frame
	await _frames(2)
	# Main menu asks first; Esc takes it back
	await _click(_at(hits, "row", 2).get_center())
	_check(pm._page == "leave" and not game.left, "Main menu didn't ask first (page '%s')" % pm._page)
	await _key("ui_cancel")
	_check(pm._page == "pause" and pm._sel == 2 and not game.left, "Esc on the question: page '%s'" % pm._page)
	while pm._page_t < 1.0:
		await process_frame
	await _frames(2)
	# RESUME goes on the release
	var bar := _at(hits, "bar")
	await _button(bar.get_center(), MOUSE_BUTTON_LEFT, true)
	_check(not game.resumed, "RESUME acted on the press")
	await _button(bar.get_center(), MOUSE_BUTTON_LEFT, false)
	_check(game.resumed, "RESUME didn't act on the release")
	layer.queue_free()
	game.queue_free()
	await _frames(3)


func _run() -> void:
	_cfg_backup = FileAccess.get_file_as_bytes(CFG) if FileAccess.file_exists(CFG) else null
	var keep := Settings.values.duplicate()
	await _main_menu()
	await _pause_menu()
	Settings.values = keep  # the settings (and the file) as they were
	Settings.apply()
	if _cfg_backup != null:
		var f := FileAccess.open(CFG, FileAccess.WRITE)
		f.store_buffer(_cfg_backup)
		f.close()
	elif FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(CFG)
	if _bad > 0:
		push_error("MOUSE FAIL: %d problems" % _bad)
		quit(1)
		return
	print("MOUSE OK")
	quit(0)
