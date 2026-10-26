class_name RadioTuning
extends Control
## Radio tuning minigame (minigames.md §3.6), short version: move the dial (A/D, mouse or stick)
## until the static clears; hold the signal clean for HOLD seconds. Emits `done` on success.
## Presentation: an old portable short-wave set drawn in _draw, centered on the HUD layer over a dim.

signal done

const HOLD := 1.5
const CH_STEP := 0.075  ## dial distance between channels; CH 7 sits on `target`
const LOCK_SHOW := 0.9  ## "SIGNAL LOCKED" stays up this long, then the fade
const FADE := 0.45
const NOISE_CHARS := "~#%*=:/\\"

var target := 0.62  ## 0..1 position of the station on the dial
var dial := 0.1
var _clean := 0.0
var _strength := 0.0
var _meter := 0.0  ## smoothed meter needle 0..1
var _t := 0.0
var _locked_t := -1.0  ## >= 0 once locked
var _status := ""
var _font: Font
var _snd: AudioStreamPlayer  ## the static, quieter the closer the dial is to the station


static func play(layer: Node, station := 0.62) -> RadioTuning:
	var r := RadioTuning.new()
	r.target = station
	layer.add_child(r)
	return r


func _ready() -> void:
	# direct child of a CanvasLayer: full-rect anchors resolve against the viewport rect
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	modulate.a = 0.0
	z_index = 10  # above HUD labels spawned later (banners, zone names)
	_snd = Snd.sfx("radio_static", null, -6.0) as AudioStreamPlayer
	tree_exiting.connect(func() -> void: Snd.stop(_snd))


func _input(event: InputEvent) -> void:
	if _locked_t < 0.0 and event is InputEventMouseMotion:
		dial = clampf(dial + event.relative.x * 0.0015, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _locked_t < 0.0:
		dial = clampf(dial + Input.get_axis("move_left", "move_right") * 0.35 * delta, 0.0, 1.0)
	_strength = clampf(1.0 - absf(dial - target) / 0.18, 0.0, 1.0)
	var jitter := (randf() - 0.5) * 0.25 * (1.0 - _strength)
	_meter = lerpf(_meter, clampf(_strength + jitter, 0.0, 1.0), minf(delta * 8.0, 1.0))
	var clean := _strength > 0.85
	if _snd and is_instance_valid(_snd):
		_snd.volume_db = linear_to_db(0.03 + (1.0 - _strength) * 0.7) - 4.0
		_snd.pitch_scale = 0.9 + 0.2 * _strength
	if _locked_t >= 0.0:
		_locked_t += delta
		_status = "SIGNAL LOCKED"
		modulate.a = clampf(1.0 - (_locked_t - LOCK_SHOW) / FADE, 0.0, 1.0)
		if _locked_t >= LOCK_SHOW + FADE:
			set_process(false)
			set_process_input(false)
			done.emit()
			queue_free()
			return
	else:
		modulate.a = minf(_t / 0.25, 1.0)
		_clean = _clean + delta if clean else maxf(_clean - delta * 2.0, 0.0)
		if clean:
			_status = tr("HOLD STEADY") + " " + ".".repeat(int(_clean / HOLD * 4.0))
		elif Engine.get_process_frames() % 3 == 0:  # static text flicker
			_status = ""
			for i in 18:
				var c := NOISE_CHARS[randi() % NOISE_CHARS.length()]
				_status += c if randf() > _strength * 0.8 else " "
		if _clean >= HOLD:
			_locked_t = 0.0
			Snd.stop(_snd)
			Snd.sfx("radio_lock", null, -3.0)
	queue_redraw()


# ------------------------------------------------------------------ drawing
# Local origin = screen center (radio body spans x -170..170, y -100..82, hint at y 100).

const WOOD := Color(0.34, 0.19, 0.09)
const WOOD_DARK := Color(0.2, 0.1, 0.05)
const WOOD_WORN := Color(0.55, 0.36, 0.2)
const BAKELITE := Color(0.13, 0.09, 0.07)
const CHROME := Color(0.62, 0.6, 0.55)
const CHROME_DARK := Color(0.3, 0.29, 0.26)
const AMBER := Color(0.95, 0.62, 0.2)
const INK := Color(0.2, 0.1, 0.04)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.62))
	draw_set_transform((size / 2.0 - Vector2(0, 8)).floor())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # stable wear/grain every frame
	_draw_case(rng)
	_draw_speaker()
	_draw_dial()
	_draw_meter()
	_draw_scope()
	_draw_lock_and_band()
	_draw_knobs()
	_draw_status()
	_text(Vector2(-200, 104), 400, "A/D or mouse — tune · hold on the signal", 10, Color(0.85, 0.82, 0.72), true)


func _draw_case(rng: RandomNumberGenerator) -> void:
	# carrying handle (leather strap on chrome lugs)
	draw_rect(Rect2(-118, -102, 236, 8), Color(0.16, 0.09, 0.05))
	draw_rect(Rect2(-118, -102, 236, 2), Color(0.3, 0.18, 0.1))
	draw_rect(Rect2(-126, -104, 10, 20), CHROME_DARK)
	draw_rect(Rect2(116, -104, 10, 20), CHROME_DARK)
	draw_rect(Rect2(-125, -103, 3, 18), CHROME)
	draw_rect(Rect2(117, -103, 3, 18), CHROME)
	# shadow + wooden cabinet
	draw_rect(Rect2(-166, -84, 340, 172), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-170, -88, 340, 170), WOOD)
	for y in range(-88, 82, 3):  # grain
		var shade := rng.randf_range(-0.05, 0.05)
		draw_rect(Rect2(-170, y, 340, 1), WOOD.lightened(shade) if shade > 0 else WOOD.darkened(-shade))
	draw_rect(Rect2(-170, -88, 340, 2), WOOD_WORN)  # bevel light
	draw_rect(Rect2(-170, -88, 2, 170), WOOD_WORN)
	draw_rect(Rect2(-170, 80, 340, 2), WOOD_DARK)
	draw_rect(Rect2(168, -88, 2, 170), WOOD_DARK)
	# worn corners and edge scuffs showing bare wood
	for c in [Vector2(-170, -88), Vector2(164, -88), Vector2(-170, 76), Vector2(164, 76)]:
		draw_rect(Rect2(c, Vector2(6, 6)), WOOD_WORN)
		draw_rect(Rect2(c + Vector2(1, 1), Vector2(3, 3)), WOOD_WORN.lightened(0.15))
	for i in 26:
		var on_top := rng.randf() < 0.5
		var p := Vector2(rng.randf_range(-166, 160), -88 if on_top else 80)
		if rng.randf() < 0.4:
			p = Vector2(-170 if on_top else 168, rng.randf_range(-84, 76))
			draw_rect(Rect2(p, Vector2(2, rng.randi_range(2, 6))), WOOD_WORN)
		else:
			draw_rect(Rect2(p, Vector2(rng.randi_range(2, 8), 2)), WOOD_WORN)
	# bakelite faceplate with chrome rim + corner screws
	draw_rect(Rect2(-162, -80, 324, 154), CHROME_DARK)
	draw_rect(Rect2(-161, -79, 322, 152), BAKELITE)
	draw_rect(Rect2(-161, -79, 322, 1), Color(0.3, 0.22, 0.17))
	for s in [Vector2(-157, -75), Vector2(155, -75), Vector2(-157, 67), Vector2(155, 67)]:
		draw_circle(s, 2.5, CHROME_DARK)
		draw_line(s - Vector2(2, 0), s + Vector2(2, 0), Color(0.1, 0.1, 0.1))
	for i in 14:  # scratches on the plate
		var p := Vector2(rng.randf_range(-158, 150), rng.randf_range(-76, 66))
		draw_line(p, p + Vector2(rng.randf_range(2, 9), rng.randf_range(-2, 2)), Color(0.24, 0.18, 0.14))


func _draw_speaker() -> void:
	var c := Vector2(-104, -20)
	draw_rect(Rect2(-152, -72, 96, 100), Color(0.07, 0.05, 0.04))
	draw_circle(c, 45.0, CHROME_DARK)
	draw_circle(c, 43.0, Color(0.2, 0.16, 0.12))
	for y in range(-42, 43, 5):
		for x in range(-42, 43, 5):
			if Vector2(x, y).length() < 40.0:
				draw_rect(Rect2(c + Vector2(x, y), Vector2(2, 2)), Color(0.05, 0.035, 0.03))
	draw_arc(c, 44.0, PI * 1.05, PI * 1.45, 10, CHROME, 1.0)  # rim glint
	draw_circle(c, 4.0, CHROME_DARK)
	# brass maker's plate
	draw_rect(Rect2(-154, 34, 100, 16), Color(0.42, 0.3, 0.12))
	draw_rect(Rect2(-153, 35, 98, 14), Color(0.72, 0.56, 0.26))
	draw_rect(Rect2(-153, 35, 98, 1), Color(0.9, 0.78, 0.45))
	_plate(Vector2(-153, 45), 98, "LANTERN RADIO CO.", 8, Color(0.25, 0.15, 0.05))
	_plate(Vector2(-153, 62), 98, "MODEL 7 · SHORT WAVE", 6, Color(0.55, 0.48, 0.38))


func _dial_x(v: float) -> float:
	return -40.0 + 196.0 * v


func _draw_dial() -> void:
	var r := Rect2(-44, -72, 204, 48)
	draw_rect(r.grow(2), CHROME_DARK)
	draw_rect(r.grow(1), CHROME)
	draw_rect(r, AMBER.darkened(0.25))
	draw_rect(r.grow(-4), AMBER)
	draw_rect(Rect2(r.position.x + 30, r.position.y + 8, r.size.x - 60, 20), AMBER.lightened(0.18))  # bulb glow
	_plate(Vector2(-42, -65), 60, "SW  CH", 6, INK)
	_plate(Vector2(98, -65), 60, "MHz", 6, INK, false, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_line(Vector2(-40, -40), Vector2(156, -40), INK)
	for i in 41:  # fine ticks
		var x := roundf(_dial_x(i / 40.0))
		draw_line(Vector2(x, -40), Vector2(x, -43 if i % 2 else -45), INK)
	for ch in range(1, 13):
		var v := target + (ch - 7) * CH_STEP
		if v < 0.0 or v > 1.0:
			continue
		var x := roundf(_dial_x(v))
		var col := Color(0.75, 0.08, 0.05) if ch == 7 else INK
		draw_rect(Rect2(x, -48, 1, 8), col)
		_plate(Vector2(x - 8, -51), 16, str(ch), 8, col)
		if ch == 7:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -36), Vector2(x + 4, -36), Vector2(x, -32)]), col)
			_plate(Vector2(x - 10, -26.5), 20, "CH 7", 6, col)
	# static specks on the glass while off-station
	for i in int((1.0 - _strength) * 14.0):
		draw_rect(Rect2(Vector2(randf_range(-42, 156), randf_range(-70, -28)).floor(), Vector2(1, 1)), Color(1, 0.95, 0.8, 0.8))
	# red needle
	var nx := roundf(_dial_x(dial))
	draw_rect(Rect2(nx - 1, -71, 3, 46), Color(0.35, 0.02, 0.02, 0.5))
	draw_rect(Rect2(nx, -71, 1, 46), Color(0.9, 0.1, 0.06))
	# glass glare
	draw_line(Vector2(-30, -70), Vector2(-14, -26), Color(1, 1, 0.9, 0.25), 3.0)
	draw_line(Vector2(-8, -70), Vector2(0, -50), Color(1, 1, 0.9, 0.18), 2.0)


func _draw_meter() -> void:
	var r := Rect2(-44, -16, 64, 44)
	draw_rect(r.grow(1), CHROME_DARK)
	draw_rect(r, Color(0.88, 0.82, 0.64))
	var pivot := Vector2(-12, 24)
	for i in 11:
		var a := lerpf(-PI * 0.8, -PI * 0.2, i / 10.0)
		var inner := 22.0 if i % 5 else 19.0
		draw_line(pivot + Vector2.from_angle(a) * inner, pivot + Vector2.from_angle(a) * 26.0, Color(0.7, 0.1, 0.05) if i >= 8 else INK)
	draw_arc(pivot, 26.0, -PI * 0.8, -PI * 0.2, 16, INK)
	_plate(Vector2(-44, -8), 64, "SIGNAL", 6, INK)
	var a := lerpf(-PI * 0.8, -PI * 0.2, _meter)
	draw_line(pivot, pivot + Vector2.from_angle(a) * 27.0, Color(0.6, 0.05, 0.03), 2.0)
	draw_rect(Rect2(pivot - Vector2(3, 2), Vector2(7, 4)), Color(0.15, 0.12, 0.1))
	_plate(Vector2(-44, 44), 64, "S-METER", 6, CHROME)


func _draw_scope() -> void:
	var r := Rect2(26, -16, 64, 44)
	draw_rect(r.grow(1), CHROME_DARK)
	draw_rect(r, Color(0.02, 0.08, 0.04))
	for x in range(34, 90, 8):
		draw_line(Vector2(x, -15), Vector2(x, 27), Color(0.05, 0.2, 0.1))
	for y in range(-8, 28, 8):
		draw_line(Vector2(27, y), Vector2(89, y), Color(0.05, 0.2, 0.1))
	var pts := PackedVector2Array()
	for i in 61:
		var clean := sin(i * 0.42 - _t * 9.0) * 14.0 * _strength
		var noise := randf_range(-18.0, 18.0) * (1.0 - _strength)
		pts.append(Vector2(27 + i, clampf(6.0 + clean + noise, -14.0, 26.0)).floor())
	draw_polyline(pts, Color(0.3, 1.0, 0.45, 0.35), 3.0)
	draw_polyline(pts, Color(0.55, 1.0, 0.6))
	_plate(Vector2(26, 44), 64, "WAVE", 6, CHROME)


func _draw_lock_and_band() -> void:
	# lock lamp: dark red off-station, flickering amber while holding, solid green once locked
	var col := Color(0.35, 0.05, 0.04)
	if _locked_t >= 0.0:
		col = Color(0.3, 1.0, 0.35)
	elif _clean > 0.0:
		col = Color(1.0, 0.7, 0.15) if int(_t * 10.0) % 2 else Color(0.6, 0.35, 0.08)
	var p := Vector2(107, -6)
	draw_circle(p, 6.0, CHROME_DARK)
	if _locked_t >= 0.0:
		draw_circle(p, 9.0, Color(col, 0.25))
	draw_circle(p, 4.0, col)
	draw_rect(Rect2(p - Vector2(2, 2), Vector2(1, 1)), Color(1, 1, 1, 0.6))
	_plate(Vector2(95, 10), 24, "LOCK", 6, CHROME)
	# band switch (stuck on SW)
	draw_rect(Rect2(126, -12, 30, 10), Color(0.04, 0.03, 0.02))
	draw_rect(Rect2(142, -11, 13, 8), CHROME)
	draw_rect(Rect2(142, -11, 13, 1), Color(0.9, 0.9, 0.85))
	_plate(Vector2(122, 4), 20, "MW", 6, Color(0.45, 0.4, 0.35))
	_plate(Vector2(139, 4), 20, "SW", 6, AMBER)


func _draw_knobs() -> void:
	# small volume knob
	var v := Vector2(-28, 60)
	draw_circle(v, 8.0, Color(0.05, 0.04, 0.03))
	draw_circle(v, 6.0, Color(0.25, 0.2, 0.16))
	draw_line(v, v + Vector2.from_angle(-PI * 0.3) * 6.0, Color(0.9, 0.85, 0.7))
	_plate(Vector2(-40, 76), 24, "VOL", 6, CHROME)
	# big tuning knob, rotates with the dial
	var c := Vector2(128, 40)
	var rot := dial * TAU * 1.75
	draw_circle(c + Vector2(2, 2), 25.0, Color(0, 0, 0, 0.5))
	draw_circle(c, 25.0, Color(0.06, 0.045, 0.035))
	for i in 24:  # knurled edge
		var a := rot + i * TAU / 24.0
		draw_line(c + Vector2.from_angle(a) * 20.0, c + Vector2.from_angle(a) * 25.0, Color(0.22, 0.17, 0.13), 2.0)
	draw_circle(c, 18.0, Color(0.2, 0.15, 0.11))
	draw_arc(c, 17.0, PI * 1.0, PI * 1.5, 10, Color(0.42, 0.34, 0.26), 2.0)  # top-left light
	draw_circle(c, 7.0, CHROME_DARK)
	draw_circle(c, 5.0, CHROME)
	var tip := c + Vector2.from_angle(rot - PI / 2.0) * 17.0
	draw_line(c + Vector2.from_angle(rot - PI / 2.0) * 8.0, tip, Color(0.95, 0.9, 0.75), 2.0)
	_plate(Vector2(108, 77), 40, "TUNING", 6, CHROME)


func _draw_status() -> void:
	var r := Rect2(-10, 50, 96, 14)
	draw_rect(r.grow(1), CHROME_DARK)
	draw_rect(r, Color(0.05, 0.04, 0.03))
	var col := Color(0.4, 1.0, 0.45) if _locked_t >= 0.0 else (AMBER if _clean > 0.0 else Color(0.75, 0.7, 0.6))
	if _locked_t >= 0.0 and int(_locked_t * 6.0) % 2 == 1 and _locked_t < 0.5:
		col = Color(col, 0.3)
	_text(Vector2(-10, 60), 96, _status, 8, col)


func _plate(pos: Vector2, width: float, s: String, fsize: int, col: Color, outline := false,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	## What's printed on the set itself (maker, bands, dials, meters): the radio's own English, never translated.
	if outline:
		draw_string_outline(_font, pos, s, align, width, fsize, 3, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, align, width, fsize, col)


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
