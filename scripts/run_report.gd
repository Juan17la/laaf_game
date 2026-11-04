class_name RunReport
extends Control
## The final report, on black after "Thank you for playing." (Ch3ScenesB.pop_1413): the ending, three columns of what
## the run counted (Game.run, fed by Game.tally) and a closing text: Groq's paragraph on the player's habits, labelled as
## AI-written (scripts/groq.gd), when a key is set, else local_verdict(). Enter, Esc, Start or a click on the bar moves on to free roam.
## Text: English ids, shown through tr() as drawn.

signal closed

const Guide := preload("res://player/guide.gd")
const ENDINGS := {"run": "RUN", "signal": "SIGNAL", "unveiled": "UNVEILED", "new_eye": "THE NEW EYE", "mixed": "MIXED"}
const TOP_ZONES := 3
const HABIT_NAMES := {"dodge": "rolling on cue", "ranged": "shooting from afar", "stealth": "sneaking", "hide": "hiding",
	"melee": "fighting up close", "stun": "stunning enemies"}
const ROW_H := 12.5
const GUARD := 1.0  ## seconds it ignores Enter (the last subtitle's key mashing shouldn't skip it)

var run := {}
var flags := {}
var ask_groq := true  ## (off in the tests: no network)
var verdict := ""  ## "" while the text is on its way
var verdict_ai := false  ## the text is Groq's: the report says so
var test := false  ## the DEV tab's AI result: random data, and why the AI failed if it did
var _d: MenuDraw
var _age := 0.0


static func present(parent: Node, run_flags: Dictionary, test_run := {}) -> void:
	## Coroutine: shows the report and returns once the player moves on. test_run: made-up stats instead of Game.run.
	var g := G.game()
	var layer := CanvasLayer.new()
	layer.layer = 40
	var r := RunReport.new()
	r.test = not test_run.is_empty()
	r.run = test_run if r.test else (g.run if g else {})
	r.flags = run_flags
	layer.add_child(r)
	parent.add_child(layer)
	await r.closed
	layer.queue_free()


# ------------------------------------------------------------------ the numbers

static func _n(run: Dictionary, key: String) -> int:
	return int(run.get(key, 0))


static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t / 60.0), int(t) % 60]


static func _accuracy(run: Dictionary) -> int:
	return roundi(100.0 * _n(run, "shots_hit") / _n(run, "shots")) if _n(run, "shots") > 0 else 0


static func _fates(flags: Dictionary) -> Array:
	return Chapter3Director.MEMBERS.map(func(m: String) -> String: return str(flags.get(m, "active")))


static func sections(run: Dictionary, flags: Dictionary) -> Array:
	## [[title, [[label, value], ...]], ...]: the three columns. Labels are English ids.
	var zones: Dictionary = run.get("zones", {})
	var names := zones.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return zones[a][0] > zones[b][0])
	var town := [
		["Time exploring", _clock(float(run.get("explore", 0.0)))],
		["Distance on foot", "%.1f km" % (float(run.get("distance", 0.0)) / 1000.0)],
		["Places visited", "%d / %d" % [names.size(), Guide.ZONES.size()]],
	]
	for z: String in names.slice(0, TOP_ZONES):  # where they lingered, and how many times they walked back in
		town.append([z, "%s · %d×" % [_clock(zones[z][0]), zones[z][1]]])
	town.append(["Times you hid", str(_n(run, "hides"))])
	town.append(["Evidence found", "%d / 12" % (flags.get("evidence", []) as Array).size()])
	var fates := _fates(flags)
	var shots := _n(run, "shots")
	return [["THE TOWN", town],
		["THE HUNT", [
			["Enemies killed", str(_n(run, "kills"))],
			["Shots fired", str(shots)],
			["Accuracy", "%d%%" % _accuracy(run) if shots > 0 else "—"],
			["Headshots", str(_n(run, "headshots"))],
			["Melee blows landed", str(_n(run, "melee_hits"))],
			["Stealth takedowns", str(_n(run, "takedowns"))],
			["Hunters spared", str(fates.count("spared"))],
			["Hunters killed", str(fates.count("killed"))],
		]],
		["THE ENEMY", [
			["Shots they dodged", str(_n(run, "shots_dodged"))],
			["Dives out of your aim", str(_n(run, "aim_dodges"))],
			["Backsteps from your blows", str(_n(run, "swing_dodges"))],
			["Times they came for you", str(_n(run, "spotted"))],
			["Hits you rolled through", str(_n(run, "rolled_through"))],
			["Damage taken", str(roundi(float(run.get("damage", 0.0))))],
			["Times you died", str(_n(run, "deaths"))],
			["Elena's tea drunk", str(_n(run, "teas"))],
		]]]


static func facts(run: Dictionary, flags: Dictionary) -> Dictionary:
	## What Groq is told: the run's numbers and nothing else.
	var fates := _fates(flags)
	var zones: Dictionary = run.get("zones", {})
	var names := zones.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return zones[a][0] > zones[b][0])
	var places := names.slice(0, TOP_ZONES).map(func(z: String) -> Dictionary:
		return {"place": TranslationServer.translate(z), "minutes": roundi(zones[z][0] / 60.0), "visits": zones[z][1]})
	var habits: Dictionary = run.get("habits", {})
	var read := {}  # in words (as numbers, models report them as stats: "65% accuracy"), at Enemy.learn's thresholds
	for k: String in HABIT_NAMES:
		var v := float(habits.get(k, 0.0))
		read[HABIT_NAMES[k]] = "strong" if v >= 0.6 else ("moderate" if v >= 0.35 else "faint")
	return {"ending": ENDINGS.get(flags.get("ending", ""), "MIXED"), "minutes_played": roundi(float(run.get("time", 0.0)) / 60.0),
		"minutes_exploring": roundi(float(run.get("explore", 0.0)) / 60.0), "enemies_killed": _n(run, "kills"),
		"shots_fired": _n(run, "shots"), "accuracy_percent": _accuracy(run), "headshots": _n(run, "headshots"),
		"shots_enemies_dodged": _n(run, "shots_dodged"), "stealth_takedowns": _n(run, "takedowns"),
		"times_hid": _n(run, "hides"), "times_died": _n(run, "deaths"), "hunters_spared": fates.count("spared"),
		"hunters_killed": fates.count("killed"), "evidence_of_12": (flags.get("evidence", []) as Array).size(),
		"distance_km": snappedf(float(run.get("distance", 0.0)) / 1000.0, 0.1), "places_most_visited": places,
		"melee_blows": _n(run, "melee_hits"), "rolls": _n(run, "rolls"), "hits_rolled_through": _n(run, "rolled_through"),
		"enemy_dives_from_aim": _n(run, "aim_dodges"), "enemy_backsteps_from_blows": _n(run, "swing_dodges"),
		"times_enemies_came_for_player": _n(run, "spotted"), "teas_drunk": _n(run, "teas"),
		"mark_peak_percent": roundi(float(run.get("mark_peak", 0.0))), "habits_enemies_learned": read}


static func local_verdict(run: Dictionary, flags: Dictionary) -> String:
	## The closing line without Groq: the first thing about the run that stands out (an English id).
	var fates := _fates(flags)
	var shots := _n(run, "shots")
	if not run.get("damaged", false) and _n(run, "deaths") == 0:
		return "Not a scratch on you. Hollowmere will remember that, and hold it against you."
	if flags.get("ending", "") == "run":
		return "You left. The fog closed behind you, and it has not stopped asking where you went."
	if fates.count("spared") == 4:
		return "You spared every one of them. The town still doesn't know what to do with that."
	if fates.count("killed") == 4:
		return "Four old friends, and you buried them all. The Veil has seen worse. Not often."
	if _n(run, "deaths") >= 10:
		return "%d times the town put you down, and %d times you got back up. It is starting to take that personally." % [_n(run, "deaths"), _n(run, "deaths")]
	if _n(run, "shots_dodged") > _n(run, "shots_hit"):
		return "They learned to read your hands. Most of your bullets only ever met the fog."
	if shots >= 20 and _accuracy(run) >= 70:
		return "%d%% of your shots found someone. Nobody here will call that mercy." % _accuracy(run)
	if (flags.get("evidence", []) as Array).size() >= 12:
		return "You read every page they tried to burn. Now you carry it too."
	if _n(run, "kills") == 0:
		return "You came through without killing anyone. The town calls that a debt."
	return "You walked out of Hollowmere. Some of you did, anyway."


static func random_run() -> Dictionary:
	## {run, flags}: a believable made-up run, a different style of play each time, for testing the AI (DEV tab).
	var explore := randf_range(600.0, 3600.0)
	var names := Guide.ZONES.map(func(z: Array) -> String: return z[0])
	names.shuffle()
	var seen := names.slice(0, randi_range(2, names.size()))
	var zones := {}
	for z: String in seen:
		zones[z] = [explore * randf_range(0.2, 1.0) / seen.size(), randi_range(1, 15)]
	var habits := {}
	for k: String in HABIT_NAMES:
		habits[k] = randf()
	var shots := randi_range(0, 400)
	var hit := roundi(shots * randf_range(0.15, 0.9))
	var dodged := randi_range(0, (shots - hit) / 2)
	var untouched := randf() < 0.1
	var deaths := 0 if untouched else randi_range(0, 25)
	var run := {"time": explore * randf_range(1.2, 1.8), "explore": explore, "zones": zones, "habits": habits,
		"distance": explore * randf_range(1.0, 3.0), "shots": shots, "shots_hit": hit, "shots_dodged": dodged,
		"aim_dodges": dodged + randi_range(0, 40), "swing_dodges": randi_range(0, 40), "kills": randi_range(0, 80),
		"headshots": randi_range(0, hit), "melee_hits": randi_range(0, 120), "takedowns": randi_range(0, 25),
		"hides": randi_range(0, 60), "rolls": randi_range(0, 300), "rolled_through": randi_range(0, 40),
		"spotted": randi_range(5, 120), "teas": randi_range(0, 6), "deaths": deaths, "damaged": not untouched,
		"damage": 0.0 if untouched else randf_range(20.0, 300.0) * (deaths + 1), "mark_peak": randf_range(0.0, 99.0)}
	var flags := {"evidence": range(randi_range(0, 12)), "ending": "run" if randf() < 0.15 else ""}
	for m: String in Chapter3Director.MEMBERS:
		flags[m] = ["spared", "killed", "active"].pick_random()
	flags.ending = Chapter3Director.pick_ending(flags)
	return {"run": run, "flags": flags}


# ------------------------------------------------------------------ the screen

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_d = MenuDraw.new(self)
	var fresh := BackBufferCopy.new()  # as on the pause menu: the scanlines read the page just drawn
	fresh.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(fresh)
	var crt := ColorRect.new()
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.material = ShaderMaterial.new()
	(crt.material as ShaderMaterial).shader = load("res://shaders/menu_crt.gdshader")
	(crt.material as ShaderMaterial).set_shader_parameter("grain", 0.07)
	add_child(crt)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MenuDraw.cursor(true)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	_write_verdict()


func _write_verdict() -> void:
	var line := ""
	if ask_groq:
		var language := "Spanish" if TranslationServer.get_locale().begins_with("es") else "English"
		line = await Groq.verdict(self, facts(run, flags), language)
	verdict_ai = line != ""
	verdict = line if verdict_ai else tr(local_verdict(run, flags))
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta


func _unhandled_input(e: InputEvent) -> void:
	## Everything is the report's while it's up (Esc mustn't open the pause menu over it).
	get_viewport().set_input_as_handled()
	if _age >= GUARD and (e.is_action_pressed("ui_accept") or e.is_action_pressed("pause")):
		_close()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_d.point(e.position)
		queue_redraw()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed \
			and _age >= GUARD and _d.hit(e.position).size() > 0:
		_close()


func _close() -> void:
	set_process_unhandled_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuDraw.cursor(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _draw() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color.BLACK)
	_d.hits.clear()
	var fw := minf(W - 40.0, 590.0)
	var f := Rect2((W - fw) / 2.0, 14, fw, H - 28)
	_d.folder(f, 1.0)
	var r := f.grow(-MenuDraw.PAD)
	var x := r.position.x
	_d.text(_d.serif, Vector2(x, r.position.y + 13), tr("Final report"), 17, _d.c(MenuDraw.BONE))
	var sub := tr("Ending: %s") % tr(ENDINGS.get(flags.get("ending", ""), "MIXED"))
	if test:
		sub = tr("AI test: random data, %s") % Groq.MODEL
	_d.text(_d.serif_it, Vector2(x, r.position.y + 27), sub, 10, _d.c(MenuDraw.AMBER if test else MenuDraw.MUTED))
	var chips := [["mark", tr("Mark peak %d%%") % roundi(float(run.get("mark_peak", 0.0)))],
		["flame", tr(G.settings().name)], ["clock", _clock(float(run.get("time", 0.0)))]]
	var cx := r.end.x
	for c: Array in chips:
		cx -= _d.ui.get_string_size(c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 23.0
		_d.chip(cx, r.position.y + 4, c[0], c[1])
		cx -= 4.0
	var cols := sections(run, flags)
	var gap := 16.0
	var cw := (r.size.x - gap * 2.0) / 3.0
	var top := r.position.y + 45.0
	for i in cols.size():
		_column(cols[i], Vector2(x + i * (cw + gap), top), cw)
	var bar_y := r.end.y - MenuDraw.BAR_H
	var qy := top + 11.0 + ROW_H * 9.0
	draw_rect(Rect2(x, qy, r.size.x, 1), _d.c(MenuDraw.RUST_HI, 0.8))
	var line := verdict if verdict != "" else tr("The town is making up its mind…")
	draw_multiline_string(_d.serif_it, Vector2(x + 24.0, qy + 22.0), line, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x - 48.0, 12, 6, _d.c(MenuDraw.BONE if verdict != "" else MenuDraw.FAINT))
	var note := ""
	if verdict_ai:
		note = tr("Written by AI from the way you played")
	elif test and verdict != "":
		note = tr("The AI failed (%s): this is a built-in line.") % Groq.last_error
	if note != "":
		_d.text(_d.ui, Vector2(x, bar_y - 6.0), note, 7, _d.c(MenuDraw.MUTED if verdict_ai else MenuDraw.AMBER), r.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
	var bw := 170.0
	_d.bar(Rect2(x + (r.size.x - bw) / 2.0, bar_y, bw, MenuDraw.BAR_H), tr("CONTINUE"), "play", false)


func _column(col: Array, at: Vector2, w: float) -> void:
	_d.text(_d.caps, at + Vector2(0, 7), tr(col[0]), 7, _d.c(MenuDraw.AMBER))
	var y := at.y + 19.0
	for row: Array in col[1]:
		var vw := _d.bold.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_d.text(_d.ui, Vector2(at.x, y), _d.fit(_d.ui, tr(row[0]), 8, w - vw - 6.0), 8, _d.c(MenuDraw.MUTED))
		_d.text(_d.bold, Vector2(at.x, y), row[1], 8, _d.c(MenuDraw.BONE), w, HORIZONTAL_ALIGNMENT_RIGHT)
		y += ROW_H
