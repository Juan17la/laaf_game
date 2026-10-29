extends SceneTree
## Headless check of the Spanish localization (locale/es.po, tools/l10n.py, locale/glossary.md):
##   every message in locale/laaf.pot has a Spanish translation in es.po, with the same placeholders (%d %s %.1f %%),
##   key letters ((E) [M]), bbcode and line breaks, and Godot serves it (TranslationServer, the locale es)
##   switching the language changes the menus (tr, the pause menu, Settings), the HUD (objective, again on a live switch),
##   the compass and a world sign; switching back gives the English again
##   sound captions still play their sound in Spanish (they're found from the English id, scripts/audio.gd)
##   a translated line stays up longer than its English, never shorter (hud.gd subtitle)
##   a save made in English loads and reads in Spanish and the other way round (saves keep English ids; the
##   menu's line for it is translated, older saves with only a "label" too)
##   the language setting is saved in the settings file and put into effect at boot (Settings.load_file + apply)
## godot --headless --path . -s tests/l10n_test.gd   (any --language: it sets the locale itself and puts it back)

const PO := "res://locale/es.po"
const POT := "res://locale/laaf.pot"
const SLOT := "l10n_test_slot"
const CFG := "user://l10n_test_settings.cfg"

var _boot_locale := ""
var _bad := 0


func _initialize() -> void:
	_boot_locale = TranslationServer.get_locale()
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_bad += 1
		push_error("L10N FAIL: " + msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _lang(code: String) -> void:
	TranslationServer.set_locale(code)
	await process_frame
	await process_frame


# ------------------------------------------------------------------ the .po file

func _unquote(lines: PackedStringArray) -> String:
	var s := ""
	for l in lines:
		s += l.substr(1, l.length() - 2)
	return s.replace("\\n", "\n").replace("\\t", "\t").replace("\\\"", "\"").replace("\\\\", "\\")


func _read_po(path: String) -> Array:
	## [{ctx, id, plural, str: [..]}] (the header skipped).
	var out := []
	var cur := {}
	var field := ""
	var buf := PackedStringArray()
	var text := FileAccess.get_file_as_string(path)
	for raw in (text + "\n\n").split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("\""):
			buf.append(line)
			continue
		if field != "":
			var v := _unquote(buf)
			if field.begins_with("msgstr"):
				cur.str = cur.get("str", []) + [v]
			else:
				cur[field] = v
			field = ""
			buf = PackedStringArray()
		if line == "" or line.begins_with("#"):
			if line == "" and cur.get("msgid", "") != "":
				out.append({"ctx": cur.get("msgctxt", ""), "id": cur.msgid, "plural": cur.get("msgid_plural", ""),
					"str": cur.get("str", [])})
			if line == "":
				cur = {}
			continue
		field = line.get_slice(" ", 0)
		buf = PackedStringArray([line.substr(field.length() + 1)])
	return out


func _sorted(a: Array) -> Array:
	a.sort()
	return a


func _matches(re: RegEx, s: String) -> Array:
	return _sorted(re.search_all(s).map(func(m: RegExMatch) -> String: return m.get_string()))


func _check_po() -> void:
	var placeholder := RegEx.create_from_string("%(?:%|[-+ 0#]*\\d*(?:\\.\\d+)?[sdfxXcov])")
	var keycap := RegEx.create_from_string("[\\[(](?:[A-Z]|[A-Z]/[A-Z]|Esc|Shift|Space|Tab|Enter)[\\])]")
	var bbcode := RegEx.create_from_string("\\[/?[a-z]+[^\\]]*\\]")
	var po := _read_po(PO)
	var pot := _read_po(POT)
	_check(po.size() > 1000, "es.po has only %d messages" % po.size())
	var in_po := {}
	for e in po:
		in_po[e.ctx + "\u0004" + e.id] = e
	for e in pot:
		_check(in_po.has(e.ctx + "\u0004" + e.id), "in laaf.pot but not es.po: %s" % e.id)
	TranslationServer.set_locale("es")
	for e in po:
		var strs: Array = e.str
		_check(not strs.is_empty() and strs.all(func(s: String) -> bool: return s.strip_edges() != ""),
			"no Spanish for '%s'" % e.id)
		for i in strs.size():
			var src: String = e.plural if i > 0 and e.plural != "" else e.id
			var es: String = strs[i]
			_check(_matches(placeholder, src) == _matches(placeholder, es),
				"placeholders differ: '%s' / '%s'" % [src, es])
			_check(_matches(keycap, src) == _matches(keycap, es), "key letters differ: '%s' / '%s'" % [src, es])
			_check(_matches(bbcode, src) == _matches(bbcode, es), "bbcode differs: '%s' / '%s'" % [src, es])
			if src.contains("\n"):
				_check(src.count("\n") == es.count("\n"), "line breaks differ: '%s'" % src)
		if e.ctx == "" and e.plural == "" and not strs.is_empty():
			_check(TranslationServer.translate(e.id) == strs[0], "Godot doesn't serve '%s' (got '%s')" %
				[e.id, TranslationServer.translate(e.id)])
	print("  po: %d messages, all translated, placeholders agree" % po.size())


# ------------------------------------------------------------------ the rest

func _run() -> void:
	_check_po()
	# menus: tr, the pause menu's words, the settings' values
	await _lang("en")
	_check(tr("PRESS ANY KEY") == "PRESS ANY KEY", "English title prompt")
	_check(Settings.text("video/vsync") == "ON", "English toggle: %s" % Settings.text("video/vsync"))
	var pm := PauseMenu.new()
	pm.info = {"mark": 12.5}
	_check(pm.tr("Paused") == "Paused" and pm.mark_text() == "Mark 12.5%", "English pause menu: '%s'" % pm.mark_text())
	await _lang("es")
	_check(tr("PRESS ANY KEY") == "PULSA CUALQUIER TECLA", "Spanish title prompt: %s" % tr("PRESS ANY KEY"))
	_check(Settings.text("video/vsync") == "SÍ", "Spanish toggle: %s" % Settings.text("video/vsync"))
	_check(pm.tr("Paused") == "Pausa", "Spanish pause title: '%s'" % pm.tr("Paused"))
	_check(pm.mark_text() == "Marca 12.5%", "Spanish pause Mark: '%s'" % pm.mark_text())
	_check(Settings.text("general/language") in ["English", "Español"], "language row value")
	pm.free()
	# the game: HUD objective (and its live refresh), compass, a localized sign
	var g: Node = G.game()
	if not g:
		g = load("res://scripts/game.gd").new()
		g.name = "Game"
		root.add_child(g)
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "zones"
	root.add_child(world)
	await _frames(90)
	var ch2: Chapter2Director = world.get_node("Chapter2")
	var player: CharacterBody3D = world.get_node("Player")
	var hud: Node = player.hud
	var guide: Node = player.get_node("Guide")
	hud.objective("Talk to Grady at the General Store")
	_check(hud._objective.text == "> Habla con Grady en su tienda", "Spanish objective: '%s'" % hud._objective.text)
	await _lang("en")
	_check(hud._objective.text == "> Talk to Grady at the General Store", "live switch to English: '%s'" %
		hud._objective.text)
	_check(guide._bearings() == "NESW", "English compass: %s" % guide._bearings())
	await _lang("es")
	_check(hud._objective.text == "> Habla con Grady en su tienda", "live switch to Spanish: '%s'" % hud._objective.text)
	_check(guide._bearings() == "NESO", "Spanish compass: %s" % guide._bearings())
	var sign: Label3D = null
	for n in world.get_node("Signs").get_children():
		if n is Label3D and n.text == "PRIVATE LAND":
			sign = n
	_check(sign != null and sign.get_script() != null, "PRIVATE LAND is not a localized sign")
	if sign:
		var es_px := sign.pixel_size
		await _lang("en")
		_check(sign.pixel_size > es_px, "the sign isn't sized per language (%f / %f)" % [sign.pixel_size, es_px])
		await _lang("es")
	# sound captions: found from the English id, whatever the Spanish says
	var audio: Node = root.get_node_or_null("Audio")
	if not audio:
		audio = load("res://scripts/audio.gd").new()
		audio.name = "Audio"
		root.add_child(audio)
		await process_frame
	for c in [["BONG.", "bell"], ["The cage swings open.", "door_open"], ["CLUNK.", "thud"], ["Click.", "pick_set"]]:
		audio.last_caption = ""
		await hud.subtitle("", c[0], 0.05)
		_check(audio.last_caption == c[1], "caption '%s' in Spanish played '%s', not %s" % [c[0], audio.last_caption, c[1]])
	audio.last_caption = ""
	hud.banner("CLANG")
	_check(audio.last_caption == "bell", "banner CLANG in Spanish played '%s'" % audio.last_caption)
	# pacing: "Deal." (1.2 s) reads "Trato hecho." in Spanish, so it stays up longer; English keeps its 1.2 s
	var t0 := Time.get_ticks_msec()
	await hud.subtitle("Alex", "Deal.", 1.2)
	var es_t := (Time.get_ticks_msec() - t0) / 1000.0
	await _lang("en")
	t0 = Time.get_ticks_msec()
	await hud.subtitle("Alex", "Deal.", 1.2)
	var en_t := (Time.get_ticks_msec() - t0) / 1000.0
	_check(es_t > en_t + 0.25 and en_t < 1.45, "subtitle pacing: Spanish %.2f s, English %.2f s" % [es_t, en_t])
	# saves: made in English, loaded in Spanish; made in Spanish, loaded in English
	await _lang("en")
	ch2.objective("Get inside the school")
	_check(g.save_game(SLOT, "Manual save"), "save_game failed")
	var s_en: Dictionary = g.load_save(SLOT)
	_check(s_en.get("objective", "") == "Get inside the school" and s_en.get("kind", "") == "Manual save",
		"the save holds translated text: %s / %s" % [s_en.get("objective"), s_en.get("kind")])
	await _lang("es")
	_check(g.save_game(SLOT + "_es", "Manual save"), "save_game (Spanish) failed")
	var s_es: Dictionary = g.load_save(SLOT + "_es")
	_check(s_es.get("objective", "") == s_en.get("objective", "") and s_es.get("label", "") == s_en.get("label", ""),
		"a save made in Spanish differs from the English one: %s / %s" % [s_es.get("label"), s_en.get("label")])
	var menu: Control = load("res://scripts/main_menu.gd").new()  # (out of the tree: only its save lines are asked for)
	var old_save := s_en.duplicate()
	old_save.erase("objective")  # a save from before this build: only "Ch.2 · <objective>"
	_check(menu._objective(s_en) == "Entra a la escuela", "English save read in Spanish: '%s'" % menu._objective(s_en))
	_check(menu._objective(old_save) == "Entra a la escuela", "older save read in Spanish: '%s'" % menu._objective(old_save))
	await _lang("en")
	_check(menu._objective(s_es) == "Get inside the school", "Spanish save read in English: '%s'" % menu._objective(s_es))
	menu.free()
	for slot in [s_en, s_es]:
		world.queue_free()
		await _frames(5)
		await _lang("es" if slot == s_en else "en")
		g.pending = slot.duplicate(true)
		g.loading = true
		world = load("res://maps/hollowmere.tscn").instantiate()
		world.get_node("Chapter1").start_step = "intro"
		root.add_child(world)
		await _frames(90)
		ch2 = world.get_node("Chapter2")
		_check(ch2.step == "zones", "save loaded into step '%s'" % ch2.step)
	DirAccess.remove_absolute("user://saves/%s.sav" % SLOT)
	DirAccess.remove_absolute("user://saves/%s_es.sav" % SLOT)
	world.queue_free()
	await _frames(5)
	# the setting: saved in the file, in effect at boot (what Game._ready does: load_file + apply)
	var forced: bool = Settings._forced
	Settings._forced = false  # (as a normal run: the file decides, not this run's --language)
	Settings.reset()
	Settings.set_value("general/language", "es", false)
	_check(Settings.save_file(CFG), "settings file not written")
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	_check(cfg.get_value("general", "language", "") == "es", "language not in the settings file")
	await _lang("en")
	Settings.load_file(CFG)
	Settings.apply()
	_check(TranslationServer.get_locale() == "es", "boot didn't apply the saved language: %s" % TranslationServer.get_locale())
	Settings.set_value("general/language", "en", false)
	Settings.save_file(CFG)
	Settings.load_file(CFG)
	Settings.apply()
	_check(TranslationServer.get_locale() == "en", "boot didn't apply English: %s" % TranslationServer.get_locale())
	cfg.set_value("general", "language", "fr")  # a value this build doesn't offer: the system's language
	cfg.save(CFG)
	Settings.load_file(CFG)
	_check(Settings.value("general/language") == Settings.system_language(), "unknown language kept")
	Settings._forced = forced
	DirAccess.remove_absolute(CFG)
	Settings.reset()
	TranslationServer.set_locale(_boot_locale)
	if _bad > 0:
		push_error("L10N FAIL: %d problems" % _bad)
		quit(1)
		return
	print("L10N OK")
	quit(0)
