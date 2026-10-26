class_name Fishing
extends Control
## Fishing minigame (minigames.md §3.2) on the harbor dock at dawn. Hold cast (click, Space/A, E/X)
## to charge and release to cast; wait for the bobber to go under (nibbles are fakes, pulling early
## spooks the fish); press on the bite to hook; then reel: hold to reel in, let go when the line
## strains, and lean the rod (A/D or stick) against the side the fish pulls to.
## Emits done(fish, tokens) — fish "" when it gets away or on Esc/B. `legendary` = Old Tom, the catfish.

signal done(fish: String, tokens: int)

enum { CAST, WAIT, BITE, REEL }

## name, tokens, weight (catch odds), strength (surge), reel speed (line per second)
const FISH := [["Perch", 5, 50, 0.45, 0.2], ["Trout", 12, 30, 0.6, 0.16], ["Pike", 25, 20, 0.8, 0.12]]
const OLD_TOM := ["Old Tom", 150, 0, 1.0, 0.08]
const REEL_ACTIONS: Array[StringName] = [&"fire", &"jump", &"interact"]
const SHOW := 1.4
const FADE := 0.4

var legendary := false
var state := CAST
var tension := 0.3
var line := 1.0  ## fish distance, 1 = where it bit, 0 = landed
var pull := 1.0  ## side the fish swims to: -1 left, 1 right
var rod := 0.0  ## rod lean -1..1
var _fish: Array = []
var _cast := 0.0  ## 0..1 charge, then cast distance
var _charge_t := 0.0
var _wait := 0.0
var _window := 0.0
var _dip := 0.0
var _fish_x := 0.0
var _turn := 0.0
var _surge := 0.0
var _slack := 0.0
var _was_held := true  ## needs a release first (the key that opened us may still be held)
var _t := 0.0
var _end_t := -1.0
var _result := ["", 0]
var _status := ""
var _font: Font


static func play(layer: Node, legendary := false) -> Fishing:
	var f := Fishing.new()
	f.legendary = legendary
	layer.add_child(f)
	return f


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	modulate.a = 0.0
	z_index = 10


func _input(event: InputEvent) -> void:
	if _end_t < 0.0 and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_finish("", 0, "")


func _process(delta: float) -> void:
	_t += delta
	if _end_t >= 0.0:
		_end_t += delta
		modulate.a = clampf(1.0 - (_end_t - SHOW) / FADE, 0.0, 1.0)
		if _end_t >= SHOW + FADE:
			set_process(false)
			set_process_input(false)
			done.emit(_result[0], _result[1])
			queue_free()
		queue_redraw()
		return
	modulate.a = minf(_t / 0.25, 1.0)
	var held := REEL_ACTIONS.any(func(a: StringName) -> bool: return Input.is_action_pressed(a))
	var pressed := held and not _was_held
	var released := _was_held and not held
	_was_held = held
	_dip = maxf(_dip - delta * 2.0, 0.0)
	match state:
		CAST:
			if held:
				_charge_t += delta
				_cast = pingpong(_charge_t * 1.1, 1.0)
				_status = "CHARGING"
			elif released and _charge_t > 0.0:
				state = WAIT
				Snd.sfx("fish_cast")
				_wait = randf_range(2.0, 3.5) + (1.0 - _cast) * 2.5 + (2.0 if legendary else 0.0)
				_status = "..."
		WAIT:
			_wait -= delta
			if randf() < delta * 0.7:
				_dip = 0.35  # nibble: a fake
			if pressed:
				_dip = 1.0
				_wait += 2.0
				_status = "TOO EARLY — IT SPOOKED"
			elif _wait <= 0.0:
				state = BITE
				Snd.sfx("fish_splash", null, -6.0)
				_window = 0.45 if legendary else 0.7
				_status = "!"
		BITE:
			_window -= delta
			_dip = 1.0
			if pressed:
				_fish = OLD_TOM if legendary else _roll()
				state = REEL
				Snd.sfx("fish_reel")
				_status = "HOOKED!"
				_turn = 0.0
			elif _window <= 0.0:
				_finish("", 0, "IT GOT AWAY")
		REEL:
			_reel(delta, held)
	queue_redraw()


func _roll() -> Array:
	var r := randi() % 100
	for f in FISH:
		r -= f[2]
		if r < 0:
			return f
	return FISH[0]


func _reel(delta: float, held: bool) -> void:
	rod = move_toward(rod, Input.get_axis("move_left", "move_right"), delta * 4.0)
	_turn -= delta
	if _turn <= 0.0:  # the fish changes side and surges
		pull = -pull if randf() < 0.7 else pull
		_turn = randf_range(1.0, 2.5)
		_surge = randf_range(0.3, 1.0) * _fish[3]
	_fish_x = move_toward(_fish_x, pull, delta * 0.8)
	var counter := clampf(-rod * pull, 0.0, 1.0)  # leaning against the pull eases the strain
	tension += ((0.45 if held else -0.7) + _surge * (1.0 - 0.7 * counter) * 0.5) * delta
	if held and tension < 0.85:
		line -= _fish[4] * (1.0 - _surge * 0.5) * delta
	elif not held:
		line = minf(line + _surge * 0.05 * delta, 1.0)
	_slack = _slack + delta if tension < 0.1 else 0.0
	tension = maxf(tension, 0.0)
	_status = "REEL" if tension < 0.6 else ("EASE OFF" if tension < 0.85 else "IT'S GOING TO SNAP")
	if tension >= 1.0:
		_finish("", 0, "THE LINE SNAPPED")
	elif _slack > 2.5:
		_finish("", 0, "IT SPAT THE HOOK")
	elif line <= 0.0:
		_finish(_fish[0], _fish[1], tr("%s! +%d TOKENS") % [tr(String(_fish[0])).to_upper(), _fish[1]])


func _finish(fish: String, tokens: int, text: String) -> void:
	if fish != "":
		Snd.sfx("fish_splash")
	_result = [fish, tokens]
	_status = text
	_end_t = 0.0 if text != "" else SHOW  # a quit skips straight to the fade


# ------------------------------------------------------------------ drawing
# Local origin = screen center. Scene window x -200..200, y -112..82 (horizon y -34); bars below.

const HORIZON := -34.0
const PAPER := Color(0.88, 0.84, 0.72)
const PINE := Color(0.1, 0.1, 0.14)
const WOOD := Color(0.3, 0.19, 0.11)


func _bobber_pos() -> Vector2:
	var depth := _cast * (line if state == REEL else 1.0)
	var y := lerpf(70.0, HORIZON + 8.0, depth)
	var x := _fish_x * 110.0 * depth if state == REEL else sin(_t * 0.8) * 3.0 - 20.0
	return Vector2(x, y + _dip * 4.0).round()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.66))
	draw_set_transform((size / 2.0 - Vector2(0, 14)).floor())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	draw_rect(Rect2(-204, -116, 408, 202), Color(0.08, 0.06, 0.05))
	# dawn sky bands
	var sky := [Color(0.16, 0.16, 0.3), Color(0.3, 0.25, 0.4), Color(0.55, 0.36, 0.44), Color(0.85, 0.52, 0.4), Color(0.98, 0.72, 0.45)]
	for i in 5:
		draw_rect(Rect2(-200, -112 + i * 16, 400, 16), sky[i])
	draw_circle(Vector2(70, HORIZON), 14.0, Color(1, 0.88, 0.6))
	# far shore: pines and the lighthouse (lamp blinking)
	for i in 40:
		var x := -200.0 + i * 10.0 + rng.randf_range(-3, 3)
		var h := rng.randf_range(8, 18)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, HORIZON), Vector2(x + 5, HORIZON), Vector2(x, HORIZON - h)]), PINE)
	draw_colored_polygon(PackedVector2Array([Vector2(-158, HORIZON), Vector2(-146, HORIZON), Vector2(-149, HORIZON - 40), Vector2(-155, HORIZON - 40)]), Color(0.18, 0.16, 0.2))
	draw_rect(Rect2(-157, HORIZON - 46, 10, 6), Color(0.12, 0.1, 0.12))
	if int(_t * 1.5) % 2 == 0:
		draw_circle(Vector2(-152, HORIZON - 43), 5.0, Color(1, 0.9, 0.5, 0.35))
		draw_rect(Rect2(-154, HORIZON - 45, 4, 3), Color(1, 0.95, 0.7))
	# water, sun glitter, fog
	draw_rect(Rect2(-200, HORIZON, 400, 116), Color(0.14, 0.2, 0.26))
	for i in 8:
		draw_rect(Rect2(-200, HORIZON + i * 14, 400, 14), Color(0.3, 0.32, 0.38).darkened(i * 0.09))
	for i in 60:
		var y := HORIZON + 2 + rng.randf() * 110.0
		var x := fposmod(rng.randf_range(-200, 200) + _t * rng.randf_range(2, 6), 400.0) - 200.0
		var near_sun := absf(x - 70.0) < 18.0 + (y - HORIZON) * 0.3
		draw_rect(Rect2(Vector2(x, y).floor(), Vector2(rng.randi_range(3, 9), 1)), Color(1, 0.8, 0.55, 0.7) if near_sun else Color(0.55, 0.6, 0.7, 0.35))
	for i in 3:
		draw_rect(Rect2(-200, HORIZON - 8 + i * 7 + sin(_t * 0.3 + i) * 2.0, 400, 6), Color(0.85, 0.82, 0.85, 0.12))
	_draw_fish_and_bobber()
	# dock planks + rod
	draw_rect(Rect2(-200, 64, 400, 18), WOOD)
	for x in range(-200, 200, 24):
		draw_line(Vector2(x, 64), Vector2(x + 4, 82), Color(0.15, 0.09, 0.05))
	draw_rect(Rect2(-200, 64, 400, 2), Color(0.45, 0.3, 0.18))
	var base := Vector2(150, 82)
	var tip := Vector2(92 + rod * 40.0, -10 + tension * 26.0).round()
	var mid := base.lerp(tip, 0.5) + Vector2(-tension * 12.0, 4)
	var rod_pts := PackedVector2Array()
	for k in 9:
		var s := k / 8.0
		rod_pts.append(base.lerp(mid, s).lerp(mid.lerp(tip, s), s))
	draw_polyline(rod_pts, Color(0.2, 0.13, 0.08), 3.0)
	draw_polyline(rod_pts, Color(0.5, 0.36, 0.2), 1.0)
	draw_rect(Rect2(base + Vector2(-16, -22), Vector2(8, 8)), Color(0.35, 0.36, 0.38))  # reel
	if state != CAST:
		var line_col := Color(1, 0.35, 0.3, 0.9) if tension > 0.85 else Color(0.9, 0.9, 0.85, 0.7)
		draw_line(tip, _bobber_pos(), line_col, 1.0)
	draw_rect(Rect2(-200, -112, 400, 194), Color(0, 0, 0, 0), false, 2.0)
	_draw_ui()


func _draw_fish_and_bobber() -> void:
	var b := _bobber_pos()
	if state == REEL:
		var big := 2.0 if legendary else 1.0
		var sx := 12.0 * big * (1.0 - _cast * line * 0.5)
		draw_set_transform((size / 2.0 - Vector2(0, 14)).floor() + b + Vector2(pull * 4.0, 6), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, sx, Color(0.03, 0.06, 0.08, 0.6))
		draw_set_transform((size / 2.0 - Vector2(0, 14)).floor())
		for i in 2:
			draw_arc(b, 4.0 + fmod(_t * 12.0 + i * 5.0, 10.0), 0, TAU, 12, Color(0.9, 0.95, 1, 0.4))
		return
	if state == CAST:
		return
	if _dip > 0.2:
		draw_arc(b, 4.0 + (1.0 - _dip) * 8.0, 0, TAU, 12, Color(0.9, 0.95, 1, 0.5))
	var under := state == BITE
	draw_rect(Rect2(b + Vector2(-3, -6), Vector2(6, 6 if under else 7)), Color(0.9, 0.12, 0.08))
	if not under:
		draw_rect(Rect2(b + Vector2(-3, 1), Vector2(6, 3)), Color(0.95, 0.95, 0.9))
	else:
		_text(b + Vector2(-10, -10), 20, "!", 14, Color(1, 0.9, 0.3), true)


func _draw_ui() -> void:
	if state == CAST:  # charge meter
		var r := Rect2(-80, 90, 160, 8)
		draw_rect(r.grow(1), PAPER)
		draw_rect(r, Color(0.05, 0.04, 0.03))
		draw_rect(Rect2(r.position, Vector2(roundf(160.0 * _cast), 8)), Color(0.95, 0.62, 0.2))
		_text(Vector2(-80, 108), 160, "CAST DISTANCE", 7, PAPER)
	elif state == REEL:  # tension bar with the safe zone
		var r := Rect2(-120, 90, 240, 8)
		draw_rect(r.grow(1), PAPER)
		draw_rect(r, Color(0.35, 0.08, 0.05))
		draw_rect(Rect2(-120 + 24, 90, 240 * 0.75, 8), Color(0.2, 0.5, 0.22))
		var mx := roundf(-120.0 + 240.0 * minf(tension, 1.0))
		draw_rect(Rect2(mx - 1, 86, 3, 16), Color(1, 0.95, 0.8))
		_text(Vector2(-120, 110), 90, tr("LINE %d m") % roundi(line * _cast * 30.0 + 2.0), 8, PAPER, false, HORIZONTAL_ALIGNMENT_LEFT)
		var arrow := "<<< PULLS LEFT" if pull < 0.0 else "PULLS RIGHT >>>"
		_text(Vector2(0, 110), 120, arrow, 8, Color(1, 0.8, 0.4), false, HORIZONTAL_ALIGNMENT_RIGHT)
	var col := Color(0.4, 1.0, 0.45) if _result[1] > 0 else (Color(1, 0.35, 0.25) if _end_t >= 0.0 or tension > 0.85 else Color(1, 0.85, 0.5))
	_text(Vector2(-200, -94), 400, _status, 12, col, true)
	if legendary and state != CAST:
		_text(Vector2(-200, -78), 400, "Something big is down there.", 8, PAPER, true)
	var hints := {CAST: "Hold click / Space — charge · release — cast · Esc — quit",
		WAIT: "Wait for the bobber to go under…", BITE: "NOW — click / Space!",
		REEL: "Hold click / Space — reel · let go when it strains · A/D — lean against the pull"}
	_text(Vector2(-200, 128), 400, hints[state], 9, PAPER, true)


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
