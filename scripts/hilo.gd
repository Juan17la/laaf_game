class_name HiLo
extends Control
## Lantern Hi-Lo vs Silas (minigames.md §3.4). Pick a stake, then call the next card Higher or Lower.
## Each right call climbs the chain (x1.5, x2, x3); cash out any time after one. A wrong call or the
## Veil card loses the stake. Cash out `wins_needed` hands to win; 10 hands a night. Esc quits (the
## stake of an unfinished hand is returned). Emits done(won, tokens_delta) after the fade, then frees.

signal done(won: bool, tokens_delta: int)

const STAKES := [5, 20, 50]
const MULT := [1.0, 1.5, 2.0, 3.0]
const MAX_HANDS := 10
const FADE := 0.4
const RANKS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const L_DEAL := ["Sit. Lanterns don't light themselves.", "Higher or lower. Like the lake.", "Your money. My table."]
const L_RIGHT := ["Hm. Lucky.", "The lake gives...", "Don't get used to it."]
const L_WRONG := ["House always wins. I'm the house.", "My boy used to guess like that.", "Pour one out for your tokens."]
const L_VEIL := ["The Veil. It takes everything, eventually.", "Fog card. Nobody sees through it."]
const L_CASH := ["Smart. Smarter than me.", "Walk away while you can. Nobody here does."]
const L_RUMOR := ["...the doctor walks his rounds on the hour. Regular as a heart.",
	"...the teacher can't see in the dark. She only listens for her girl.",
	"...Julian wheezes on the stairs. Always did."]

var wins_needed := 3
var tokens := 0  ## bankroll when sitting down
var _delta := 0
var _wins := 0
var _hands := 0
var _stake_i := 0
var _bet := 0
var _chain := 0
var _cur := 7
var _next := -1  ## -1 face down, 0 Veil, 1..13 rank
var _phase := "bet"  ## bet · guess · reveal · end · out
var _wait := 0.0
var _after := ""  ## what the reveal resolves to: right · push · lost
var _line := ""
var _t := 0.0
var _out_t := 0.0
var _prev_mouse := Input.MOUSE_MODE_CAPTURED
var _font: Font


static func play(layer: Node, wins_needed_ := 3, tokens_ := 0) -> HiLo:
	var h := HiLo.new()
	h.wins_needed = wins_needed_
	h.tokens = tokens_
	layer.add_child(h)
	return h


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	modulate.a = 0.0
	z_index = 10
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_line = L_DEAL.pick_random()
	_fit_stake(0)


func _bank() -> int:
	return tokens + _delta


func _fit_stake(dir: int) -> void:
	## cycles (dir ±1) or clamps (dir 0) within the stakes the bank covers; broke = -1, "for a drink"
	var n := STAKES.filter(func(st: int) -> bool: return st <= _bank()).size()  # ascending: a prefix
	_stake_i = -1 if n == 0 else (wrapi(_stake_i + dir, 0, n) if dir else clampi(_stake_i, 0, n - 1))


func _stake() -> int:
	return STAKES[_stake_i] if _stake_i >= 0 else 0


func _input(event: InputEvent) -> void:
	if _phase == "out" or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):  # Esc / B / Start, like Lockpick
		if _phase == "guess":
			_delta += _bet  # unfinished hand: only the chain is lost
		_close(_phase == "end" and _wins >= wins_needed)
		return
	var act := ""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position - _origin()
		for b in _buttons():
			if b[0].has_point(p):
				act = b[1]
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		act = "hi"
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		act = "lo"
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		act = "left"
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		act = "right"
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		act = "ok"
	if act != "":
		_act(act)


func _act(act: String) -> void:
	match _phase:
		"bet":
			if act in ["left", "right"]:
				_fit_stake(-1 if act == "left" else 1)
			elif act in ["ok", "deal"]:
				_bet = _stake()
				_delta -= _bet
				_hands += 1
				_chain = 0
				_cur = randi_range(1, 13)
				_next = -1
				_phase = "guess"
				_line = L_DEAL.pick_random()
		"guess":
			if act in ["hi", "lo"]:
				_next = randi_range(0, 13)  # 1 in 14: the Veil
				var right: bool = _next > _cur if act == "hi" else _next < _cur
				_after = "push" if _next == _cur else ("right" if right and _next != 0 else "lost")
				_line = "..."
				_phase = "reveal"
				_wait = 0.9
			elif act in ["ok", "cash"] and _chain > 0:
				_delta += int(_bet * MULT[mini(_chain, 3)])
				_wins += 1
				_line = L_CASH.pick_random()
				_end_hand()
		"end":
			if act in ["ok", "cash", "deal"]:
				_close(_wins >= wins_needed)


func _end_hand() -> void:
	if _wins >= wins_needed or _hands >= MAX_HANDS:
		_phase = "end"
		_line = "Take it. You earned more than tokens tonight." if _wins >= wins_needed \
			else "Last call. Come back when your luck sobers up."
	else:
		_phase = "bet"
		_fit_stake(0)


func _close(won: bool) -> void:
	_phase = "out"
	Input.mouse_mode = _prev_mouse
	_after = "won" if won else "lost"


func _process(delta: float) -> void:
	_t += delta
	if _phase == "out":
		_out_t += delta
		modulate.a = clampf(1.0 - _out_t / FADE, 0.0, 1.0)
		if _out_t >= FADE:
			set_process(false)
			set_process_input(false)
			done.emit(_after == "won", _delta)
			queue_free()
			return
	else:
		modulate.a = minf(_t / 0.25, 1.0)
	if _phase == "reveal":
		_wait -= delta
		if _wait <= 0.0:
			if _after == "right":
				_chain += 1
				_cur = _next
				_next = -1
				_line = L_RIGHT.pick_random()
				_phase = "guess"
			elif _after == "push":
				_cur = _next
				_next = -1
				_line = "Same card. Nobody wins, kid. Again."
				_phase = "guess"
			else:
				_line = L_VEIL.pick_random() if _next == 0 else L_WRONG.pick_random()
				if _bet > 0 and randf() < 0.5:  # Silas talks when he's winning
					_line += " " + L_RUMOR.pick_random()
				_end_hand()
	queue_redraw()


# ------------------------------------------------------------------ drawing
# Local origin = screen center; table spans x -200..200, y -120..110.

const FELT := Color(0.09, 0.22, 0.14)
const WOOD := Color(0.26, 0.14, 0.07)
const CREAM := Color(0.9, 0.85, 0.7)
const BRASS := Color(0.78, 0.6, 0.26)
const INK := Color(0.12, 0.08, 0.05)
const RED := Color(0.62, 0.08, 0.06)


func _origin() -> Vector2:
	return (size / 2.0).floor()


func _buttons() -> Array:
	match _phase:
		"bet": return [[Rect2(-150, 66, 40, 18), "left", "<"], [Rect2(110, 66, 40, 18), "right", ">"],
			[Rect2(-50, 66, 100, 18), "deal", "DEAL  %d" % _stake() if _stake_i >= 0 else "DEAL  (a drink)"]]
		"guess": return [[Rect2(-150, 66, 90, 18), "hi", "HIGHER  W"], [Rect2(-45, 66, 90, 18), "lo", "LOWER  S"],
			[Rect2(60, 66, 90, 18), "cash", "CASH OUT  E" if _chain > 0 else "--"]]
		"end": return [[Rect2(-50, 66, 100, 18), "ok", "LEAVE THE TABLE"]]
	return []


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65))
	draw_set_transform(_origin())
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	# lamp glow from above + wooden rim + felt with wear
	draw_circle(Vector2(0, -20), 190.0, Color(0.95, 0.65, 0.25, 0.06))
	draw_rect(Rect2(-204, -96, 408, 196), WOOD.darkened(0.4))
	draw_rect(Rect2(-200, -92, 400, 188), WOOD)
	draw_rect(Rect2(-200, -92, 400, 2), WOOD.lightened(0.25))
	draw_rect(Rect2(-190, -82, 380, 168), FELT)
	for i in 40:
		var p := Vector2(rng.randf_range(-186, 180), rng.randf_range(-78, 80))
		draw_rect(Rect2(p, Vector2(rng.randi_range(2, 7), 1)), FELT.lightened(0.07))
	draw_circle(Vector2(150, -50), 14.0, Color(0.06, 0.15, 0.1))  # glass ring stain
	draw_arc(Vector2(150, -50), 14.0, 0, TAU, 20, Color(0.05, 0.12, 0.08), 2.0)
	# Silas's line + stats
	_text(Vector2(-200, -104), 400, "SILAS: " + _line, 8, CREAM, true)
	_text(Vector2(-186, -66), 120, "BANK  %d" % _bank(), 8, BRASS, false, HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(-186, -54), 120, "STAKE %d" % (_bet if _phase != "bet" else _stake()), 8, BRASS, false, HORIZONTAL_ALIGNMENT_LEFT)
	_text(Vector2(66, -66), 120, "HANDS WON %d/%d" % [_wins, wins_needed], 8, CREAM, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(66, -54), 120, "HAND %d/%d" % [_hands, MAX_HANDS], 8, CREAM, false, HORIZONTAL_ALIGNMENT_RIGHT)
	# Silas's token stack (shrinks as you win)
	for i in clampi(12 - int(_delta / 10.0), 2, 20):
		draw_rect(Rect2(-178, 40 - i * 3, 18, 3), BRASS if i % 2 else BRASS.darkened(0.3))
	# deck, current card, next card
	for i in 4:
		_card_back(Vector2(-110 - i, -40 - i))
	if _phase != "bet":
		_card(Vector2(-40, -40), _cur)
		if _next < 0:
			_card_back(Vector2(20, -40))
		else:
			_card(Vector2(20, -40), _next)
	else:
		_text(Vector2(-60, 0), 120, "Place your stake", 8, CREAM.darkened(0.3))
	# chain ladder
	for i in 3:
		var lit := _chain > i and _phase != "bet"
		var r := Rect2(100, 16 - i * 20, 50, 16)
		draw_rect(r, BRASS if lit else Color(0.05, 0.12, 0.08))
		draw_rect(r, BRASS.darkened(0.4), false)
		_text(Vector2(100, 28 - i * 20), 50, ["x1.5", "x2", "x3"][i], 8, INK if lit else BRASS.darkened(0.3))
	for b in _buttons():
		var hot: bool = b[0].has_point(get_local_mouse_position() - _origin())
		draw_rect(b[0], Color(0.35, 0.2, 0.08) if hot else Color(0.18, 0.1, 0.05))
		draw_rect(b[0], BRASS, false)
		_text(b[0].position + Vector2(0, 13), b[0].size.x, b[2], 8, CREAM)
	var hint := "A/D stake · E deal" if _phase == "bet" else ("W higher · S lower · E cash out" if _phase != "end" else "E leave")
	_text(Vector2(-200, 104), 400, hint + " · Esc quit", 8, Color(0.85, 0.82, 0.72), true)


func _card(p: Vector2, v: int) -> void:
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(40, 56)), Color(0, 0, 0, 0.5))
	if v == 0:  # the Veil: black card, fog bands, one pale eye
		draw_rect(Rect2(p, Vector2(40, 56)), Color(0.06, 0.06, 0.07))
		for y in range(8, 50, 7):
			draw_rect(Rect2(p + Vector2(3, y), Vector2(34, 2)), Color(0.5, 0.52, 0.55, 0.25))
		draw_circle(p + Vector2(20, 26), 5.0, Color(0.7, 0.72, 0.7))
		draw_circle(p + Vector2(20, 26), 2.0, Color(0.05, 0.05, 0.05))
		_text(p + Vector2(0, 50), 40, "VEIL", 6, Color(0.7, 0.72, 0.7))
		return
	draw_rect(Rect2(p, Vector2(40, 56)), CREAM)
	draw_rect(Rect2(p, Vector2(40, 56)), CREAM.darkened(0.4), false)
	var col := RED if v % 2 else INK
	_text(p + Vector2(2, 11), 20, RANKS[v], 8, col, false, HORIZONTAL_ALIGNMENT_LEFT)
	_text(p + Vector2(0, 32), 40, RANKS[v], 16, col)
	# lantern pip: ring, cap, glass body
	var c := p + Vector2(30, 44)
	draw_arc(c + Vector2(0, -7), 2.0, PI, TAU, 6, col)
	draw_rect(Rect2(c + Vector2(-3, -5), Vector2(6, 2)), col)
	draw_rect(Rect2(c + Vector2(-2, -3), Vector2(4, 6)), col)
	draw_rect(Rect2(c + Vector2(-1, -2), Vector2(2, 3)), BRASS)


func _card_back(p: Vector2) -> void:
	draw_rect(Rect2(p, Vector2(40, 56)), Color(0.32, 0.08, 0.06))
	draw_rect(Rect2(p + Vector2(3, 3), Vector2(34, 50)), Color(0.45, 0.12, 0.08), false)
	for i in range(6, 50, 6):
		draw_line(p + Vector2(4, i), p + Vector2(36, i), Color(0.4, 0.1, 0.07))


func _text(pos: Vector2, width: float, s: String, fsize: int, col: Color, outline := false,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if outline:
		draw_string_outline(_font, pos, s, align, width, fsize, 3, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, align, width, fsize, col)
