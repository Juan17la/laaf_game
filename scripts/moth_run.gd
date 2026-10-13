class_name MothRun
extends Control
## "Moth Run" arcade cabinet in the diner (minigames.md §3.3). A moth flies right through the dark:
## W/S, stick or mouse steer it up/down, lanterns are +150 (the moth drifts toward them), hands reaching
## from the dark cost a life. Distance scores too. 3 lives. Game over shows the high-score table; at
## 10,000+ it also shows Elena's hidden message (`goodbye` = the post-C2.2 wording).
## Esc mid-run quits with nothing (done(0)); after game over E/Esc leaves with done(score).

signal done(score: int)

const SW := 240.0  ## CRT screen size (game space)
const SH := 150.0
const MOTH_X := 44.0
const SECRET := 10000
const FADE := 0.4
const TABLE := [["LILY V.", 9120], ["TOMAS R.", 7450], ["SAM K.", 5300], ["LUCIA M.", 3980],
	["OWEN B.", 2210], ["NORA H.", 1500], ["GRADY", 640]]
const MSG := "ALEX. IF YOU GOT THIS FAR YOU'RE WASTING DAYLIGHT. GOOD. SOMEBODY SHOULD. TRUST THE RADIO, NOT THE LANTERNS. CH 7.  - E."
const MSG_BYE := "ALEX. IF YOU'RE READING THIS, I'M ALREADY GONE. I'M SORRY. FIND LUCIA. TELL THEM HIS NAME WAS TOMAS.  - E."

var goodbye := false
var _score := 0.0
var _lives := 3
var _y := SH / 2.0
var _speed := 60.0
var _run_t := 0.0
var _hurt_t := 0.0  ## invulnerable while > 0
var _spawn := 60.0  ## px of travel until the next hand
var _hands: Array = []  ## {x, top, len}
var _lanterns: Array = []  ## Vector2
var _mouse_y := -1.0  ## screen-space target while the mouse steers
var _phase := "run"  ## run · over · out
var _result := 0
var _t := 0.0
var _out_t := 0.0
var _prev_mouse := Input.MOUSE_MODE_CAPTURED
var _font: Font


static func play(layer: Node, goodbye_ := false) -> MothRun:
	var m := MothRun.new()
	m.goodbye = goodbye_
	layer.add_child(m)
	return m


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	modulate.a = 0.0
	z_index = 10
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if _phase == "out":
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		_mouse_y = (event.position - _screen_origin()).y
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):  # Esc / B / Start, like Lockpick
		_close(0 if _phase == "run" else int(_score))
	elif _phase == "over" and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
			or (event is InputEventMouseButton and event.pressed)):
		_close(int(_score))
	elif event is InputEventJoypadMotion or event is InputEventKey:
		_mouse_y = -1.0  # keys/stick take over from the mouse


func _close(score: int) -> void:
	_result = score
	_phase = "out"
	Input.mouse_mode = _prev_mouse


func hurt() -> void:
	## loses a life (hand touched); the last one ends the run
	_lives -= 1
	_hurt_t = 1.5
	if _lives <= 0:
		_phase = "over"


func _process(delta: float) -> void:
	_t += delta
	if _phase == "out":
		_out_t += delta
		modulate.a = clampf(1.0 - _out_t / FADE, 0.0, 1.0)
		if _out_t >= FADE:
			set_process(false)
			set_process_input(false)
			done.emit(_result)
			queue_free()
			return
	else:
		modulate.a = minf(_t / 0.25, 1.0)
	if _phase == "run" and _t > 1.0:  # 1 s "READY"
		_step(delta)
	queue_redraw()


func _step(delta: float) -> void:
	_run_t += delta
	_speed = minf(60.0 + _run_t * 0.6, 150.0)
	var dx := _speed * delta
	_score += dx * 0.5
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	# steering: keys/stick, or follow the mouse
	var axis := clampf(Input.get_axis("move_forward", "move_back") + Input.get_axis("ui_up", "ui_down"), -1.0, 1.0)
	if _mouse_y >= 0.0 and absf(axis) < 0.1:
		_y = move_toward(_y, _mouse_y, 120.0 * delta)
	else:
		_y += axis * 120.0 * delta
	for l: Vector2 in _lanterns:  # a moth can't help it
		if absf(l.x - MOTH_X) < 50.0:
			_y = lerpf(_y, l.y, 0.6 * delta)
	_y = clampf(_y, 6.0, SH - 6.0)
	# scroll + spawn
	for h: Dictionary in _hands:
		h.x -= dx
	for i in _lanterns.size():
		_lanterns[i].x -= dx
	_hands = _hands.filter(func(h: Dictionary) -> bool: return h.x > -20.0)
	_spawn -= dx
	if _spawn <= 0.0:
		var top := randf() < 0.5
		var reach := randf_range(40.0, 60.0 + minf(_run_t * 0.25, 30.0))
		_hands.append({"x": SW + 10.0, "top": top, "len": reach})
		if randf() < 0.6:  # lantern in the open side of the gap
			_lanterns.append(Vector2(SW + 10.0 + randf_range(30.0, 50.0),
				randf_range(reach + 12.0, SH - 12.0) if top else randf_range(12.0, SH - reach - 12.0)))
		_spawn = randf_range(80.0, 120.0)
	# collisions
	var moth := Vector2(MOTH_X, _y)
	for i in range(_lanterns.size() - 1, -1, -1):
		if _lanterns[i].distance_to(moth) < 9.0:
			_score += 150.0
			_lanterns.remove_at(i)
		elif _lanterns[i].x < -10.0:
			_lanterns.remove_at(i)
	if _hurt_t <= 0.0:
		for h: Dictionary in _hands:
			if _hand_rect(h).grow(3.0).has_point(moth):
				hurt()
				break


func _hand_rect(h: Dictionary) -> Rect2:
	return Rect2(h.x, 0.0 if h.top else SH - h.len, 12.0, h.len)


# ------------------------------------------------------------------ drawing
# Local origin = screen center; cabinet spans x -150..150, y -172..172, CRT at the top half.

const BODY := Color(0.1, 0.09, 0.12)
const TRIM := Color(0.55, 0.12, 0.1)
const GLOW := Color(1.0, 0.75, 0.3)
const SCR_BG := Color(0.02, 0.02, 0.05)
const PALE := Color(0.85, 0.9, 0.8)


func _screen_origin() -> Vector2:
	return (size / 2.0).floor() + Vector2(-SW / 2.0, -118.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	draw_set_transform((size / 2.0).floor())
	# cabinet: side panels with red trim, marquee, bezel, control deck
	draw_rect(Rect2(-150, -172, 300, 344), BODY)
	draw_rect(Rect2(-150, -172, 6, 344), TRIM)
	draw_rect(Rect2(144, -172, 6, 344), TRIM)
	draw_rect(Rect2(-140, -170, 280, 26), Color(0.2, 0.08, 0.05))
	draw_rect(Rect2(-138, -168, 276, 22), GLOW.darkened(0.55))
	_text(Vector2(-140, -151), 280, "M O T H   R U N", 16, GLOW, true)
	draw_rect(Rect2(-SW / 2 - 10, -128, SW + 20, SH + 20), Color(0.04, 0.04, 0.05))  # bezel
	draw_rect(Rect2(-140, 46, 280, 50), Color(0.16, 0.14, 0.18))  # control deck
	draw_rect(Rect2(-140, 46, 280, 2), Color(0.3, 0.28, 0.32))
	draw_circle(Vector2(-70, 74), 10.0, Color(0.05, 0.05, 0.06))  # stick
	draw_line(Vector2(-70, 74), Vector2(-70 + _stick() * 4, 60), Color(0.4, 0.4, 0.42), 3.0)
	draw_circle(Vector2(-70 + _stick() * 4, 58), 6.0, TRIM)
	for i in 2:
		draw_circle(Vector2(40 + i * 30, 74), 9.0, Color(0.05, 0.05, 0.06))
		draw_circle(Vector2(40 + i * 30, 73), 7.0, [Color(0.85, 0.7, 0.1), Color(0.2, 0.45, 0.8)][i])
	draw_rect(Rect2(-24, 106, 48, 34), Color(0.06, 0.06, 0.07))  # coin door
	draw_rect(Rect2(-4, 114, 8, 14), GLOW.darkened(0.3) if int(_t * 2.0) % 2 else Color(0.3, 0.2, 0.08))
	_text(Vector2(-60, 154), 120, "1 TOKEN · NOISE 15 m", 6, Color(0.6, 0.55, 0.5))
	# CRT
	draw_set_transform(_screen_origin())
	draw_rect(Rect2(0, 0, SW, SH), SCR_BG)
	if _phase == "run" or (_phase == "out" and _result == 0):
		_draw_game()
	else:
		_draw_scores()
	for y in range(0, int(SH), 2):  # scanlines
		draw_rect(Rect2(0, y, SW, 1), Color(0, 0, 0, 0.28))
	for c in [Vector2(0, 0), Vector2(SW - 6, 0), Vector2(0, SH - 6), Vector2(SW - 6, SH - 6)]:
		draw_rect(Rect2(c, Vector2(6, 6)), Color(0.04, 0.04, 0.05))  # rounded tube corners
	draw_line(Vector2(12, 8), Vector2(44, 8), Color(1, 1, 1, 0.12), 2.0)  # glass glare
	draw_set_transform((size / 2.0).floor())
	var hint := "W/S or mouse — fly · Esc quit" if _phase == "run" else "E — leave the cabinet"
	_text(Vector2(-200, 170), 400, hint, 8, Color(0.85, 0.82, 0.72), true)


func _stick() -> float:
	## the cabinet stick leans with the moth's steering (up/down shown as a sideways lean)
	return Input.get_axis("move_forward", "move_back") if _phase == "run" else 0.0


func _draw_game() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 30:  # parallax fog specks
		var x := fposmod(rng.randf() * SW - _run_t * 20.0 * rng.randf_range(0.3, 1.0), SW)
		draw_rect(Rect2(x, rng.randf() * SH, 1, 1), Color(0.3, 0.32, 0.4))
	for l: Vector2 in _lanterns:
		draw_circle(l, 7.0, Color(GLOW, 0.18))
		draw_rect(Rect2(l + Vector2(-2, -4), Vector2(4, 7)), GLOW)
		draw_rect(Rect2(l + Vector2(-3, -6), Vector2(6, 2)), Color(0.5, 0.35, 0.15))
	for h: Dictionary in _hands:
		var r := _hand_rect(h)
		draw_rect(r, Color(0.28, 0.3, 0.3))
		draw_rect(Rect2(r.position.x + 9, r.position.y, 3, r.size.y), Color(0.18, 0.2, 0.2))
		var tip := r.end.y if h.top else r.position.y  # fingers reaching
		var dir := 1.0 if h.top else -1.0
		for f in 4:
			draw_rect(Rect2(h.x - 1 + f * 3.5, tip if h.top else tip - 6, 2, 6), Color(0.35, 0.38, 0.36))
		draw_rect(Rect2(h.x - 3, tip - dir * 8, 3, 5), Color(0.35, 0.38, 0.36))  # thumb
	if _hurt_t <= 0.0 or int(_t * 12.0) % 2:
		var flap := 3.0 if int(_t * 10.0) % 2 else -1.0
		var m := Vector2(MOTH_X, _y)
		draw_colored_polygon(PackedVector2Array([m, m + Vector2(-6, -3 - flap), m + Vector2(-2, 2)]), Color(0.8, 0.75, 0.6))
		draw_colored_polygon(PackedVector2Array([m, m + Vector2(4, -4 - flap), m + Vector2(2, 2)]), Color(0.9, 0.85, 0.7))
		draw_rect(Rect2(m - Vector2(3, 1), Vector2(6, 2)), Color(0.5, 0.42, 0.3))
	_text(Vector2(4, 11), 120, "%06d" % int(_score), 8, PALE, false, HORIZONTAL_ALIGNMENT_LEFT)
	for i in _lives:
		draw_rect(Rect2(SW - 12 - i * 9, 5, 6, 6), GLOW)
	if _t < 1.0:
		_text(Vector2(0, SH / 2), SW, "READY", 16, GLOW)


func _draw_scores() -> void:
	var rows := TABLE.duplicate()
	rows.append(["YOU", int(_score)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var secret := int(_score) >= SECRET
	_text(Vector2(0, 14), SW, "HIGH SCORES", 8, GLOW)
	for i in mini(rows.size(), 5 if secret else 8):
		var you: bool = rows[i][0] == "YOU"
		var col := GLOW if you and int(_t * 3.0) % 2 else PALE
		_text(Vector2(40, 28 + i * 11), 80, "%d. %s" % [i + 1, rows[i][0]], 8, col, false, HORIZONTAL_ALIGNMENT_LEFT)
		_text(Vector2(120, 28 + i * 11), 80, str(rows[i][1]), 8, col, false, HORIZONTAL_ALIGNMENT_RIGHT)
	if secret:  # Elena's message hidden in the table memory
		draw_rect(Rect2(8, 84, SW - 16, SH - 92), Color(0.12, 0.1, 0.02))
		draw_rect(Rect2(8, 84, SW - 16, SH - 92), GLOW.darkened(0.3), false)
		draw_multiline_string(_font, Vector2(12, 95), MSG_BYE if goodbye else MSG, HORIZONTAL_ALIGNMENT_LEFT,
			SW - 24, 7, -1, Color(1.0, 0.85, 0.5))
	else:
		_text(Vector2(0, SH - 10), SW, "GAME OVER", 8, TRIM.lightened(0.3))


func _text(pos: Vector2, width: float, s: String, fsize: int, col: Color, outline := false,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if outline:
		draw_string_outline(_font, pos, s, align, width, fsize, 3, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, align, width, fsize, col)
