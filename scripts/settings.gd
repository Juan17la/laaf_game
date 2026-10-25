class_name Settings
extends RefCounted
## The player's settings: kept in user://settings.cfg, loaded and applied at boot (Game._ready, the buses once
## Audio has made them) and on every change (the Settings screen, scripts/settings_menu.gd). Static, like Feel: the
## gameplay code reads it with no autoload, so the headless tests run on the defaults, which are the game as designed.
## ROWS is the whole screen, one setting per row, grouped by its section: a new one (a language, key bindings) is a
## row here plus the line in apply() that puts it into effect. The cfg keeps one [section] per group, key = value.
## Labels and help are English message ids: the screens show them through tr() (locale/es.po, tools/l10n.py).
## The language row's default is the system's (Spanish when the OS locale is Spanish, else English); a language
## forced on the command line (`--language es`: tests, dev runs) wins over the saved one.

const PATH := "user://settings.cfg"
const GROUPS := [["general", "GENERAL"], ["audio", "AUDIO"], ["controls", "CONTROLS"], ["gameplay", "GAMEPLAY & ACCESSIBILITY"], ["video", "VIDEO"]]
## [section, key, label, kind, default, extra, help]. kind: "slider" (extra [min, max, step]; "percent" shows a bar,
## "times" a multiplier), "toggle" (bool), "choice" (extra [[value, label], ...]).
const ROWS := [
	["general", "language", "Language", "choice", "en", LANGUAGES, "The game's text: menus, subtitles, notes, signs."],
	["audio", "master", "Master volume", "percent", 1.0, [0.0, 1.0, 0.1], "Everything you hear."],
	["audio", "music", "Music", "percent", 1.0, [0.0, 1.0, 0.1], "The score: exploring, the hunts, the bosses."],
	["audio", "sfx", "Sound effects", "percent", 1.0, [0.0, 1.0, 0.1], "Steps, shots, doors, the town around you."],
	["audio", "voice", "Voices", "percent", 1.0, [0.0, 1.0, 0.1], "The characters' babble and the Mark's whispers."],
	["controls", "mouse_sensitivity", "Mouse sensitivity", "times", 1.0, [0.2, 3.0, 0.1], "How far the camera turns per mouse move."],
	["controls", "stick_sensitivity", "Gamepad look sensitivity", "times", 1.0, [0.2, 3.0, 0.1], "How fast the right stick turns the camera."],
	["controls", "invert_y", "Invert look up / down", "toggle", false, null, "Mouse and right stick: up looks down."],
	["gameplay", "shake", "Camera shake", "percent", 1.0, [0.0, 1.0, 0.1], "Shots, blows and hits shaking the view. 0% = none."],
	["gameplay", "hitstop", "Hit-stop", "percent", 1.0, [0.0, 1.0, 0.1], "The split-second freeze when a blow or a shot lands."],
	["gameplay", "mark_fx", "Mark screen effects", "percent", 1.0, [0.0, 1.0, 0.1], "The Mark's vignette, pulse, colour split and wobble."],
	["gameplay", "hurt_fx", "Hurt screen edges", "percent", 1.0, [0.0, 1.0, 0.1], "The red, blurred edges when you're hurt."],
	["gameplay", "whispers", "Mark whispers", "toggle", true, null, "Voices behind you as the Mark grows (past 25%)."],
	["gameplay", "hallucinations", "Mark sightings", "toggle", true, null, "A figure standing far off in the dark (past 70%). Cosmetic."],
	["gameplay", "detection_icons", "Enemy alert icons", "toggle", true, null, "\"?\" and \"!\" over enemies that notice you."],
	["gameplay", "threat_arcs", "Off-screen threat arcs", "toggle", true, null, "Red arcs at the screen edge toward enemies onto you."],
	["gameplay", "visibility_eye", "Visibility eye", "toggle", true, null, "The HUD eye showing how visible you are."],
	["video", "fullscreen", "Fullscreen", "toggle", false, null, "Fullscreen or a window."],
	["video", "vsync", "VSync", "toggle", true, null, "Sync to the monitor: no tearing (a frame of latency)."],
	["video", "post_fx", "Film grain & vignette", "percent", 1.0, [0.0, 1.0, 0.1], "The grain and the dark corners over the picture."],
]
const LANGUAGES := [["en", "English"], ["es", "Español"]]  ## each in its own language (never translated)
const BUS_DB := {"Master": 0.0, "Music": -5.0, "SFX": -2.0, "Voice": 0.0}  ## each bus at 100% (the mix as designed)
const BUSES := {"master": "Master", "music": "Music", "sfx": "SFX", "voice": "Voice"}

static var values := {}  ## "section/key" -> value (every row's, defaults until load())
static var version := 0  ## bumped by every apply(): what caches a setting (the post shader) re-reads it on a change


static func row(id: String) -> Array:
	for r in ROWS:
		if "%s/%s" % [r[0], r[1]] == id:
			return r
	return []


static func value(id: String) -> Variant:
	## A setting by "section/key" (its default before anything was loaded).
	if values.is_empty():
		reset()
	return values.get(id, null)


static func number(id: String) -> float:
	return float(value(id))


static func flag(id: String) -> bool:
	return bool(value(id))


static func reset() -> void:
	## Every row back to its default (not applied, not saved).
	values.clear()
	for r in ROWS:
		values["%s/%s" % [r[0], r[1]]] = system_language() if r[1] == "language" else r[4]


static func system_language() -> String:
	## The language a first run starts in: Spanish when the system is (or `--language es`), English otherwise.
	return "es" if _boot_locale.begins_with("es") else "en"


static var _boot_locale := TranslationServer.get_locale()  ## (before apply() first sets it)
static var _forced := _boot_locale != OS.get_locale()  ## `--language` was given (the engine takes the flag itself)


static func set_value(id: String, v: Variant, save_now := true) -> void:
	## Changes one setting (clamped / snapped to its row), applies it at once and, by default, saves.
	var r := row(id)
	if r.is_empty():
		return
	if r[3] in ["percent", "times"]:
		var e: Array = r[5]
		v = clampf(snappedf(float(v), float(e[2])), float(e[0]), float(e[1]))
	elif r[3] == "toggle":
		v = bool(v)
	if values.is_empty():
		reset()
	values[id] = v
	apply()
	if save_now:
		save_file()


static func step(id: String, dir: int) -> void:
	## One notch up (dir 1) or down (-1): a slider moves by its step, a toggle flips, a choice cycles.
	var r := row(id)
	match r[3] if not r.is_empty() else "":
		"percent", "times":
			set_value(id, number(id) + float(r[5][2]) * dir)
		"toggle":
			set_value(id, not flag(id))
		"choice":
			var opts: Array = r[5]
			var i := opts.find_custom(func(o: Array) -> bool: return o[0] == value(id))
			set_value(id, opts[wrapi(i + dir, 0, opts.size())][0])


static func load_file(path := PATH) -> void:
	## Defaults, overwritten by whatever the cfg has (unknown keys ignored, missing ones stay default). Not applied.
	reset()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for r in ROWS:
		if cfg.has_section_key(r[0], r[1]):
			var v: Variant = cfg.get_value(r[0], r[1])
			if r[3] == "choice" and not (r[5] as Array).any(func(o: Array) -> bool: return o[0] == v):
				continue  # (a value this build doesn't offer: the default stays)
			if typeof(v) == typeof(r[4]) or (r[4] is float and v is int):
				values["%s/%s" % [r[0], r[1]]] = float(v) if r[4] is float else v
	if _forced:
		values["general/language"] = system_language()


static func save_file(path := PATH) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(path)  # (keeps sections a later build adds that this one doesn't know)
	for r in ROWS:
		cfg.set_value(r[0], r[1], value("%s/%s" % [r[0], r[1]]))
	return cfg.save(path) == OK


static func apply() -> void:
	## Puts every setting into effect: Feel's knobs, the audio buses (once Audio made them), the window. The look
	## sensitivities and invert are read by the player as he turns; the post FX by ScreenFx (version).
	if values.is_empty():
		reset()
	if TranslationServer.get_locale() != str(value("general/language")):
		TranslationServer.set_locale(str(value("general/language")))  # every Label / Label3D re-translates itself
	Feel.shake = number("gameplay/shake")
	Feel.hitstop = number("gameplay/hitstop")
	Feel.mark_fx = number("gameplay/mark_fx")
	Feel.hurt_fx = number("gameplay/hurt_fx")
	Feel.whispers = flag("gameplay/whispers")
	Feel.hallucinations = flag("gameplay/hallucinations")
	Feel.detection_icons = flag("gameplay/detection_icons")
	Feel.threat_arcs = flag("gameplay/threat_arcs")
	Feel.visibility_eye = flag("gameplay/visibility_eye")
	apply_audio()
	_apply_window()
	version += 1


static func apply_audio() -> void:
	## The buses' volumes: each at its designed level × the slider (0 mutes it). No-op before the buses exist.
	for k in BUSES:
		var i := AudioServer.get_bus_index(BUSES[k])
		if i < 0:
			continue
		var v := number("audio/" + k)
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, BUS_DB[BUSES[k]] + linear_to_db(maxf(v, 0.001)))


static func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full := flag("video/fullscreen")
	var mode := DisplayServer.window_get_mode()
	var is_full := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if flag("video/vsync") else DisplayServer.VSYNC_DISABLED)


static func text(id: String) -> String:
	## How a row's value reads on the screen.
	var r := row(id)
	match r[3] if not r.is_empty() else "":
		"percent":
			var n := roundi(number(id) * 10.0)
			return "■".repeat(n) + "□".repeat(10 - n) + "  %3d%%" % roundi(number(id) * 100.0)
		"times":
			return "%.1f×" % number(id)
		"toggle":
			return TranslationServer.translate("ON") if flag(id) else TranslationServer.translate("OFF")
		"choice":
			for o in r[5]:
				if o[0] == value(id):
					return str(o[1]) if r[1] == "language" else TranslationServer.translate(str(o[1]))
	return str(value(id))
