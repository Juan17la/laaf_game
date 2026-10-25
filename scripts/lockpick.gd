class_name Lockpick
extends Control
## Lockpicking minigame (minigames.md §3.1): a pin-tumbler lock in cross-section. Rotate the pick
## (A/D, mouse or stick) to find the current pin's sweet spot (the pin trembles as you get close),
## hold lift (W, click, Space/A, E/X) to push it to the shear line. Tension builds while lifting;
## at the top the pick snaps and every set pin drops. 3+ pins: the sweet spot drifts.
## Emits done(true) when all pins are set; done(false) on Esc/B or when the picks run out.

signal done(success: bool)

const SPOT := 0.12  ## sweet-spot half width in pick units (0..1); "Steady Hands" would widen it
const LIFT := 1.25  ## pin rise per second dead on the spot
const STRAIN := 0.55  ## tension per second while lifting
const SHOW := 1.0  ## result text stays up this long, then the fade
const FADE := 0.4
const LIFT_ACTIONS: Array[StringName] = [&"move_forward", &"fire", &"jump", &"interact"]

var pins := 3
var picks := 3  ## bobby pins left; set right after play() to change
var pick := 0.5  ## pick rotation 0..1
var tension := 0.0
var _sweet: Array[float] = []
var _height: Array[float] = []  ## 0..1 per pin, 1 = at the shear line
var _cur := 0
var _armed := false  ## lift ignored until released once (the key that opened us may still be held)
var _snap := 0.0
var _t := 0.0
var _end_t := -1.0
var _won := false
var _status := ""
var _font: Font


static func play(layer: Node, pins := 3) -> Lockpick:
	var l := Lockpick.new()
	l.pins = clampi(pins, 1, 5)
	layer.add_child(l)
	return l


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	modulate.a = 0.0
	z_index = 10
	for i in pins:
		_sweet.append(randf_range(0.15, 0.85))
		_height.append(0.0)


func _input(event: InputEvent) -> void:
	if _end_t >= 0.0:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish(false, "")
	elif event is InputEventMouseMotion:
		pick = clampf(pick + event.relative.x * 0.0012, 0.0, 1.0)


func sweet_spot(i: int) -> float:
	var drift := sin(_t * 0.9 + i * 2.0) * 0.05 if pins >= 3 else 0.0
	return clampf(_sweet[i] + drift, 0.0, 1.0)


## 0..1: how close the pick sits to the current pin's sweet spot.
func feel() -> float:
	return clampf(1.0 - absf(pick - sweet_spot(_cur)) / SPOT, 0.0, 1.0) if _cur < pins else 0.0


func _process(delta: float) -> void:
	_t += delta
	_snap = maxf(_snap - delta, 0.0)
	if _end_t >= 0.0:
		_end_t += delta
		modulate.a = clampf(1.0 - (_end_t - SHOW) / FADE, 0.0, 1.0)
		if _end_t >= SHOW + FADE:
			set_process(false)
			set_process_input(false)
			done.emit(_won)
			queue_free()
		queue_redraw()
		return
	modulate.a = minf(_t / 0.25, 1.0)
	pick = clampf(pick + Input.get_axis("move_left", "move_right") * 0.4 * delta, 0.0, 1.0)
	var held := LIFT_ACTIONS.any(func(a: StringName) -> bool: return Input.is_action_pressed(a))
	_armed = _armed or not held
	if held and _armed:
		tension += STRAIN * delta
		_height[_cur] = minf(_height[_cur] + LIFT * feel() * delta, 1.0)
		if tension >= 1.0:
			_break()
		elif _height[_cur] >= 1.0:
			_cur += 1
			tension = 0.0
			_armed = false  # release between pins
			_status = "CLICK"
			Snd.sfx("pick_set")
			if _cur == pins:
				_finish(true, "UNLOCKED")
	else:
		tension = maxf(tension - delta * 0.9, 0.0)
		_height[_cur] = maxf(_height[_cur] - delta * 0.8, 0.0)
	queue_redraw()


func _break() -> void:
	picks -= 1
	tension = 0.0
	_snap = 0.5
	_cur = 0
	_armed = false
	_height.fill(0.0)
	_status = "THE PICK SNAPPED"
	Snd.sfx("pick_snap")
	if picks <= 0:
		_finish(false, "OUT OF PICKS")


func _finish(won: bool, text: String) -> void:
	if won:
		Snd.sfx("pick_open")
	_won = won
	_status = text
	_end_t = 0.0 if text != "" else SHOW  # a quit skips straight to the fade


# ------------------------------------------------------------------ drawing
# Local origin = screen center. Lock body x -150..110, y -92..34; shear line y -20; keyway y 22..30.

const BRASS := Color(0.62, 0.47, 0.18)
const BRASS_LIGHT := Color(0.82, 0.66, 0.3)
const BRASS_DARK := Color(0.36, 0.26, 0.09)
const STEEL := Color(0.58, 0.6, 0.62)
const STEEL_DARK := Color(0.26, 0.27, 0.29)
const PAPER := Color(0.88, 0.84, 0.72)


func _pin_x(i: int) -> float:
	return roundf(-120.0 + (i + 0.5) * 200.0 / pins)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.66))
	draw_set_transform((size / 2.0 - Vector2(0, 16)).floor())
	# housing (upper) and plug (lower), cut-away brass
	draw_rect(Rect2(-154, -96, 268, 134), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-150, -92, 260, 72), BRASS_DARK)
	draw_rect(Rect2(-148, -90, 256, 68), BRASS)
	draw_rect(Rect2(-148, -90, 256, 2), BRASS_LIGHT)
	draw_rect(Rect2(-150, -20, 260, 54), BRASS_DARK)
	draw_rect(Rect2(-146, -18, 252, 50), BRASS.lightened(0.08))
	for y in range(-86, 32, 4):  # machining marks
		draw_rect(Rect2(-146, y, 252, 1), Color(0, 0, 0, 0.06))
	draw_line(Vector2(-150, -20), Vector2(110, -20), Color(0.12, 0.08, 0.02), 2.0)
	_text(Vector2(62, -24), 50, "SHEAR", 6, BRASS_DARK)
	draw_rect(Rect2(-150, 22, 260, 8), Color(0.08, 0.06, 0.03))  # keyway
	for i in pins:
		_draw_pin(i)
	_draw_wrench()
	_draw_pick()
	if _snap > 0.0:
		draw_rect(Rect2(-150, -92, 260, 126), Color(0.8, 0.05, 0.02, _snap * 0.5))
	# tension gauge
	var g := Rect2(122, -92, 14, 126)
	draw_rect(g.grow(1), STEEL_DARK)
	draw_rect(g, Color(0.05, 0.04, 0.03))
	var col := Color(0.35, 0.8, 0.3) if tension < 0.6 else (Color(1, 0.65, 0.15) if tension < 0.85 else Color(0.95, 0.15, 0.08))
	var fh := roundf(124.0 * minf(tension, 1.0))
	draw_rect(Rect2(123, 33 - fh, 12, fh), col)
	draw_line(Vector2(120, -92), Vector2(138, -92), Color(0.95, 0.15, 0.08), 2.0)
	_text(Vector2(110, 46), 40, "TENSION", 6, PAPER)
	# picks left: little bobby pins
	for i in maxi(picks, 0) + (1 if _snap > 0.0 else 0):
		var p := Vector2(-146 + i * 14, 42)
		var c := STEEL if i < picks else Color(0.6, 0.1, 0.05)
		draw_line(p, p + Vector2(0, 14), c, 2.0)
		draw_line(p + Vector2(4, 0), p + Vector2(4, 14), c, 2.0)
		draw_arc(p + Vector2(2, 0), 2.0, PI, TAU, 4, c, 2.0)
	_text(Vector2(-150, 66), 80, tr("PICKS x%d") % maxi(picks, 0), 8, PAPER, false, HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(-60, 66), 120, tr("PIN %d / %d") % [mini(_cur + 1, pins), pins], 8, PAPER)
	var sc := Color(0.4, 1.0, 0.45) if _won else (Color(1, 0.3, 0.2) if _snap > 0.0 or _end_t >= 0.0 else Color(1, 0.8, 0.4))
	_text(Vector2(-150, 88), 300, _status, 12, sc, true)
	_text(Vector2(-200, 112), 400, "A/D or mouse — feel for the pin · hold W / click — lift · Esc — quit", 9, PAPER, true)


func _draw_pin(i: int) -> void:
	var x := _pin_x(i)
	draw_rect(Rect2(x - 8, -86, 16, 108), Color(0.1, 0.07, 0.03))  # chamber bore
	draw_rect(Rect2(x - 8, -86, 1, 108), BRASS_DARK)
	var lift := 20.0 * _height[i]
	var jit := 0.0
	if i == _cur and _end_t < 0.0:
		jit = roundf(sin(_t * 70.0) * 1.4 * feel())
	var key_top := -lift + jit
	# spring from the chamber top to the driver pin
	var pts := PackedVector2Array()
	var top := -84.0
	var bottom := key_top - 22.0
	for k in 11:
		pts.append(Vector2(x + (0.0 if k in [0, 10] else (-5.0 if k % 2 else 5.0)), lerpf(top, bottom, k / 10.0)))
	draw_polyline(pts, STEEL, 1.0)
	# driver pin (steel) and key pin (brass, pointed tip)
	draw_rect(Rect2(x - 6, key_top - 22, 12, 22), STEEL_DARK)
	draw_rect(Rect2(x - 5, key_top - 21, 10, 20), STEEL)
	draw_rect(Rect2(x - 5, key_top - 21, 2, 20), Color(0.85, 0.87, 0.9))
	draw_rect(Rect2(x - 6, key_top, 12, 18), BRASS_DARK)
	draw_rect(Rect2(x - 5, key_top + 1, 10, 16), BRASS_LIGHT)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 6, key_top + 18), Vector2(x + 6, key_top + 18), Vector2(x, key_top + 23)]), BRASS_DARK)
	if i < _cur:  # set: a green glint on the shear line
		draw_rect(Rect2(x - 7, -21, 14, 2), Color(0.4, 1.0, 0.45))


func _draw_wrench() -> void:
	# tension wrench in the bottom of the keyway, bends as tension rises
	var bend := tension * 6.0
	draw_line(Vector2(-190, 29), Vector2(-150, 29), STEEL_DARK, 3.0)
	draw_line(Vector2(-190, 29), Vector2(-194, 44 + bend), STEEL_DARK, 3.0)
	draw_line(Vector2(-190, 28), Vector2(-150, 28), STEEL, 1.0)


func _draw_pick() -> void:
	var tip_x := _pin_x(mini(_cur, pins - 1))
	var shaft_y := 25.0
	var col := STEEL if _snap <= 0.0 else Color(0.6, 0.1, 0.05)
	var end_x := tip_x if _snap <= 0.0 else -120.0
	draw_rect(Rect2(-230, shaft_y - 3, 40, 7), Color(0.15, 0.1, 0.07))  # handle
	draw_line(Vector2(-190, shaft_y), Vector2(end_x - 4, shaft_y), col, 2.0)
	if _snap > 0.0:
		return
	# hook: its tilt shows the pick rotation, its tip lifts the key pin
	var ang := -PI / 2.0 + (pick - 0.5) * 1.2
	var base := Vector2(tip_x - 4, shaft_y)
	var key_bottom := -20.0 * (_height[_cur] if _cur < pins else 1.0) + 23.0
	var tip := base + Vector2.from_angle(ang) * maxf(base.y - key_bottom, 2.0)
	draw_line(base, tip, col, 2.0)
	draw_rect(Rect2(tip - Vector2(1, 1), Vector2(2, 2)), Color(0.9, 0.92, 0.95))


func _text(pos: Vector2, width: float, s: String, fsize: int, col: Color, outline := false,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	## s: an English id (drawn translated) or text already put together with tr(). A translation too wide for
	## `width` is drawn a size or two smaller (never below 7, or its own size if that's smaller).
	var t := tr(s)
	if t != s and width > 0.0:
		while fsize > 7 and _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > width:
			fsize -= 1
	if outline:
		draw_string_outline(_font, pos, t, align, width, fsize, 3, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, t, align, width, fsize, col)
