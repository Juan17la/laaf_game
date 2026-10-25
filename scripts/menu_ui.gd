class_name MenuUI
extends RefCounted
## The menus' look (main menu, pause menu): a dark card with a paper-coloured title, buttons that glow on
## hover / focus with a lantern-amber edge, and old-paper list rows. Keyboard / pad focus works throughout.
## Titles and button names are English ids: Labels translate themselves, buttons through tr() as they're made
## (a page is built again to change language).

const PAPER := Color(0.88, 0.82, 0.66)
const INK := Color(0.12, 0.09, 0.06)
const AMBER := Color(1.0, 0.72, 0.3)
const DIM := Color(0.55, 0.52, 0.46)


static func panel(parent: Node, title: String, subtitle := "", width := 280.0) -> VBoxContainer:
	## Screen-dimming backdrop + a centred card; returns the card's button column.
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.62)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0)
	card.add_theme_stylebox_override("panel", box(Color(0.05, 0.045, 0.04, 0.94), Color(0.4, 0.33, 0.22), 1, 14))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	card.add_child(col)
	col.add_child(label(title, 20, PAPER, true))
	if subtitle != "":
		col.add_child(label(subtitle, 9, DIM, true))
	var rule := ColorRect.new()
	rule.color = Color(0.45, 0.36, 0.24, 0.7)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	return col


static func button(col: Control, id: String, cb: Callable) -> Button:
	## A PS1-style menu line: plain text, dim until selected; the selected one (keyboard, pad or mouse
	## hover) is bright, gets a ▶ and a soft bar behind it. Disabled lines are greyed out.
	var text := TranslationServer.translate(id)
	var b := Button.new()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (already translated, with its ▶ prefix)
	b.text = "   " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", Color(1, 0.96, 0.85))
	b.add_theme_color_override("font_focus_color", Color(1, 0.96, 0.85))
	b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.9, 0.6))
	b.add_theme_color_override("font_pressed_color", Color(1, 0.9, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(0.3, 0.29, 0.27))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 3)
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(0.55, 0.12, 0.08, 0.35)
	bar.border_color = Color(0.9, 0.3, 0.2, 0.6)
	bar.border_width_left = 3
	bar.set_content_margin_all(3)
	var none := StyleBoxEmpty.new()
	none.set_content_margin_all(3)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, none)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, bar)
	b.focus_entered.connect(func() -> void:
		b.text = " ▶ " + text
		Snd.sfx("move"))
	b.focus_exited.connect(func() -> void: b.text = "   " + text)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.pressed.connect(func() -> void:
		Snd.sfx("click")
		cb.call())
	col.add_child(b)
	return b


static func first_button(col: Control) -> Button:
	## The first usable button under col (keyboard / pad focus starts there).
	for c in col.find_children("*", "Button", true, false):
		if not (c as Button).disabled:
			return c
	return null


static func focus(col: Control) -> void:
	var b := (col as Button) if col is Button and not (col as Button).disabled else first_button(col)
	if b:
		b.grab_focus.call_deferred()


static func settings_list(col: Control, changed := Callable()) -> Control:
	## Every Settings row as a menu line under its group's heading, in a scrolling box: Enter / click and D / right
	## step it up, A / left down; the value sits at the right. Each row is a Button named "<section>_<key>".
	## `changed(id)` runs after a row changes. Returns the scroll box.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	scroll.add_child(rows)
	var help := label("", 8, DIM)
	help.custom_minimum_size = Vector2(0, 22)
	help.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for g in Settings.GROUPS:
		var head := label(g[1], 8, Color(0.75, 0.62, 0.4))
		rows.add_child(head)
		for r in Settings.ROWS:
			if r[0] != g[0]:
				continue
			var id := "%s/%s" % [r[0], r[1]]
			var value := label("", 11, PAPER)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			value.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
			value.offset_left = -90
			value.offset_right = -4
			value.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var show := func() -> void: value.text = setting_text(id)
			var change := func(dir: int) -> void:
				Settings.step(id, dir)
				Snd.sfx("move")
				show.call()
				if changed.is_valid():
					changed.call(id)
			var b := button(rows, r[2], change.bind(1))
			b.name = id.replace("/", "_")
			b.clip_text = true
			b.add_theme_font_size_override("font_size", 11)
			b.add_theme_constant_override("h_separation", 0)
			b.add_child(value)
			b.gui_input.connect(func(e: InputEvent) -> void:
				if e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
					change.call(-1)
					b.accept_event()
				elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
					change.call(1)
					b.accept_event())
			b.focus_entered.connect(func() -> void: help.text = TranslationServer.translate(r[6]))
			show.call()
	col.add_child(help)
	return scroll


static func setting_text(id: String) -> String:
	## A setting's value as the pause menu writes it (the main menu draws its own meters and switches).
	var r := Settings.row(id)
	match r[3] if not r.is_empty() else "":
		"percent":
			return "%d%%" % roundi(Settings.number(id) * 100.0)
	return Settings.text(id)


static func label(text: String, size: int, color: Color, centered := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func paper_row(col: Control, title: String, text: String, lit := true) -> PanelContainer:
	## An old-paper slip (save slots, achievements): ink title + a line of small print; faded when not lit.
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(PAPER if lit else Color(0.36, 0.34, 0.3), Color(0.5, 0.4, 0.25), 1, 5))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	v.add_child(label(title, 11, INK if lit else Color(0.15, 0.14, 0.12)))
	v.add_child(label(text, 8, Color(0.3, 0.24, 0.16) if lit else Color(0.2, 0.19, 0.17)))
	col.add_child(p)
	return p


static func box(bg: Color, edge: Color, w: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(w)
	s.set_content_margin_all(pad)
	s.corner_radius_top_left = 2
	s.corner_radius_bottom_right = 2
	return s
