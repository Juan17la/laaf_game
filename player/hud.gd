extends CanvasLayer
## Player HUD (gameplay.md §10): health/stamina, the Mark's "MARK +N%" notice, gun + ammo, crosshair and hit markers,
## objective, interaction prompt, subtitles (every line is on screen and babbled by Snd.voice), banners
## (DOUBLE TAP, chapter cards), boss bar, fades. Zone areas call show_zone via the "hud" group.
## Chapter 2: clock, QTE (mash prompt), gas mask filter bar + mask vignette, bottle count, takedown prompt.
## Chapter 3: the item belt line (bottles / smoke cans / tea).
## Feel (scripts/feel.gd): the drawn eye (HudEyes: Alex's visibility), off-screen threat arcs (ThreatArcs)
## and the screen effects of the Mark and of pain (ScreenFx, through the Post shader).
## Text: everything handed in here is an English id (locale/es.po has the Spanish), translated as it's shown, so
## the game's state keeps the ids; Labels that hold an id translate themselves again on a language switch. Sound
## captions are looked up from the id, never from the translated text.

const SPEAKERS := {
	"Alex": Color(0.85, 0.9, 1.0), "Moth": Color(1.0, 0.85, 0.25), "Grady": Color(0.85, 0.78, 0.62),
	"Owen": Color(0.6, 0.85, 0.55), "Shepherd": Color(1.0, 0.3, 0.25), "Radio": Color(0.7, 0.7, 0.7),
	"Elena": Color(1.0, 0.82, 0.3), "Nora": Color(0.9, 0.6, 0.8), "Julian": Color(0.55, 0.85, 0.85),
	"Marcus": Color(0.8, 0.55, 0.35), "Silas": Color(0.75, 0.65, 0.95), "PA": Color(0.8, 0.75, 0.6),
	"Patient": Color(0.7, 0.75, 0.65), "Tom": Color(0.55, 0.7, 0.9),
	"Lucía": Color(0.95, 0.6, 0.5), "Tomás": Color(0.65, 0.8, 0.95), "Dispatch": Color(0.6, 0.9, 0.6),
	"Marked One": Color(0.7, 0.6, 0.55),
}

@onready var zone_label: Label = $Zone
@onready var hint: Label = $Hint
@onready var player: Node = get_parent()

var _tween: Tween
var _root: Control
var _d: MenuDraw  ## the dossier's palette and fonts (DESIGN.md), shared with the menus and the wheel
var _eyes: HudEyes
var _arcs: ThreatArcs
var _fx: ScreenFx
var _ammo: Label  ## "6 / 18" on the weapon card (guns only)
var _hp_lag := 1.0  ## health share the bar's pale trail still shows: it drains down to the fill after a hit
var _hp_hold := 0.0  ## s the trail waits before it drains
var _st_a := 0.0  ## stamina row alpha: it shows while stamina is spent and fades once it's full again
var _wheel_hint := 0.0  ## s left on the "TAB Weapon wheel" hint by the card (a new weapon was picked up)
var _icons := {}
var _cross: Label
var _hitmark: Label
var _objective: Label
var _prompt: Label
var _prompt_box: HBoxContainer
var _key_style: StyleBoxFlat
var _key_tw: Tween
var _sub_panel: PanelContainer
var _sub: RichTextLabel
var _banner: Label
var _boss: Control
var _boss_fill: ColorRect
var _boss_name: Label
var _fade: ColorRect
var _bars: Array[ColorRect] = []
var _hurt: ColorRect
var _banner_tw: Tween
var _skip := false
var _clock: Label
var _mark_note: Label  ## "MARK +N%": flashes when the Mark rises, fades (Feel.MARK_NOTICE_*)
var _mark_tw: Tween
var _mark_n := 0.0  ## % the notice on screen adds up (rises while it's up merge into it)
var _mark_last := -1.0  ## the Mark last frame (< 0: not seen yet)
var _mark_hits := 0.0  ## % the hits since last frame marked (the rest of a rise is the slow creep)
var _mark_creep := 0.0  ## slow creep gathered toward the next notice
var _mask: TextureRect
var _gas: ColorRect
var _t := 0.0
var _hint_shown := false
var _last_gun := ""
var _slot_count := 0
var _notes: VBoxContainer  ## notification toasts, top left under the objective
var _obj_panel: PanelContainer  ## the objective: a dark panel that fades back to bare text once it's been read
var _obj_tw: Tween
var _wui: Control  ## drawn: health / stamina / filter bars, the weapon card, the belt chips (_draw_hud)
var _swap_t := 0.0  ## seconds since the drawn weapon changed (the card flares)
const TIP := "WASD move · Shift run · F light"  ## the only note at the start; the rest come when they matter
var _queue: Array = []  ## notes wait their turn: one slip on screen at a time
var _told_dry := false
var _objective_id := ""  ## the objective as handed in (an English id): shown translated, again on a language switch
var _line := 0  ## the subtitle on screen (a line that ends only clears the panel if no newer one took it over)
const BAR_X := 24.0  ## the vitals' tracks start here (their icons sit left of it); HudEyes sits just past their end
const BAR_W := 100.0
const HP := Color(0.84, 0.22, 0.17)
const FILTER := Color(0.45, 0.8, 0.6)
const CARD := Vector2(150, 36)  ## the weapon card, bottom right
const OBJ_HOLD := 6.0  ## s a new objective keeps its panel before it fades back to bare text
const BELT := [["bottle", "bottles", "G"], ["smoke", "smokes", "T"], ["tea", "teas", "H"]]


func _ready() -> void:
	zone_label.modulate.a = 0.0
	hint.modulate.a = 0.0
	hint.text = ""  # the controls come as short paper notes instead (TIPS, note())
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_gas = _rect(Color(0.3, 0.45, 0.1, 0.0), Control.PRESET_FULL_RECT)
	_mask = TextureRect.new()  # gas mask: dark rounded lenses around the view
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0, 0, 0, 0))
	g.gradient.set_color(1, Color(0.02, 0.04, 0.03, 0.97))
	g.gradient.add_point(0.62, Color(0.02, 0.05, 0.03, 0.25))
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	_mask.texture = g
	_mask.stretch_mode = TextureRect.STRETCH_SCALE
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.visible = false
	_root.add_child(_mask)
	_hurt = _rect(Color(0.6, 0.0, 0.0, 0.0), Control.PRESET_FULL_RECT)
	_fx = ScreenFx.new()  # the Mark's figures sit under every widget
	_root.add_child(_fx)
	_fx.setup(player, $Post.material as ShaderMaterial)
	# bottom left: health / stamina / filter bars; bottom right: the weapon card and the belt chips (all drawn)
	_wui = Control.new()
	_wui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wui.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_wui.draw.connect(_draw_hud)
	_root.add_child(_wui)
	_d = MenuDraw.new(_wui)
	# top right: the minimap (guide.gd, x -94..-10, y 8..92), the clock right under its rim, and under the clock
	# the Mark's notice when it rises
	_clock = _label("", 10, Color(0.85, 0.82, 0.7), Control.PRESET_TOP_RIGHT, Vector2(-110, 95), Vector2(100, 14))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mark_note = _label("", 9, Feel.MARK_NOTICE_RED, Control.PRESET_TOP_RIGHT, Vector2(-110, 110), Vector2(100, 12))
	_mark_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mark_note.modulate.a = 0.0
	player.marked.connect(func(gain: float) -> void:
		_mark_hits += gain
		mark_notice(gain))
	_ammo = _label("", 14, MenuDraw.BONE, Control.PRESET_BOTTOM_RIGHT, Vector2(-86, -41), Vector2(70, 20))
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ammo.add_theme_font_override("font", _d.bold)
	_ammo.add_theme_constant_override("outline_size", 0)
	_eyes = HudEyes.new()
	_root.add_child(_eyes)
	_eyes.setup(player)
	_arcs = ThreatArcs.new()
	_root.add_child(_arcs)
	_arcs.setup(player)
	_build_objective()
	_cross = _label("+", 12, Color(1, 1, 1, 0.8), Control.PRESET_CENTER, Vector2(-10, -9), Vector2(20, 18))
	_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hitmark = _label("x", 14, Color(1, 0.3, 0.2), Control.PRESET_CENTER, Vector2(-10, -10), Vector2(20, 18))
	_hitmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hitmark.modulate.a = 0.0
	_build_prompt()
	_sub_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_sub_panel.add_theme_stylebox_override("panel", sb)
	_sub_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_panel.position = Vector2(-220, -78)
	_sub_panel.size = Vector2(440, 0)
	_sub_panel.custom_minimum_size = Vector2(440, 0)
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_panel.visible = false
	_root.add_child(_sub_panel)
	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.fit_content = true
	_sub.scroll_active = false
	_sub.add_theme_font_size_override("normal_font_size", 11)
	_sub.add_theme_font_size_override("bold_font_size", 11)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_panel.add_child(_sub)
	_banner = _label("", 26, Color(1, 1, 1, 0), Control.PRESET_CENTER, Vector2(-300, -60), Vector2(600, 40))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # (a long translation wraps instead of leaving the screen)
	_boss = Control.new()
	_boss.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss.position = Vector2(-120, 62)  # under the compass (y 28..55), not on it
	_boss.visible = false
	_root.add_child(_boss)
	var bb := ColorRect.new()
	bb.color = Color(0.1, 0.02, 0.02, 0.85)
	bb.size = Vector2(240, 5)
	bb.position = Vector2(0, 14)
	_boss.add_child(bb)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.75, 0.1, 0.08)
	_boss_fill.size = Vector2(240, 5)
	_boss_fill.position = Vector2(0, 14)
	_boss.add_child(_boss_fill)
	_boss_name = Label.new()
	_boss_name.add_theme_font_size_override("font_size", 10)
	_boss_name.size = Vector2(240, 12)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss.add_child(_boss_name)
	_fade = _rect(Color(0, 0, 0, 0), Control.PRESET_FULL_RECT)
	_root.move_child(_fade, _sub_panel.get_index())  # black fades sit under subtitles and banners
	for top in [true, false]:  # cinematic letterbox bars, closed by default
		var bar := _rect(Color.BLACK, Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		_root.move_child(bar, _sub_panel.get_index())
		_bars.append(bar)
	letterbox(false, 0.0)


func _rect(c: Color, preset: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(preset)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	return r


func _label(text: String, size: int, c: Color, preset: int, pos: Vector2, box: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.set_anchors_preset(preset)
	l.position += pos
	l.size = box
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _process(delta: float) -> void:
	# skip dialogue lines only while the player isn't in control (so jumping/using doesn't eat lines)
	if not player.controls_enabled and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact")):
		_skip = true
	# gameplay HUD only while the player is in control (cinematics stay clean)
	var play: bool = player.controls_enabled
	for n in [_eyes, _arcs, _obj_panel, _prompt_box, hint, _clock, _mark_note]:
		n.visible = play
	_obj_panel.visible = play and _objective_id != ""
	_t += delta
	_track_mark(play)
	var masked: bool = player.mask_on
	_mask.visible = masked
	_mask.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(_t * 1.6))  # breathing fogs the lenses
	var choking: bool = player.in_gas() and not (masked and player.mask_filter > 0.0)
	_gas.color.a = move_toward(_gas.color.a, 0.22 if choking else 0.0, delta * 0.8)
	if play and not _hint_shown:  # the first time the player's in control: one line of controls
		_hint_shown = true
		get_tree().create_timer(1.0).timeout.connect(note.bind(TIP, "", 4.0))
	if play and _notes.get_child_count() == 0 and not _queue.is_empty():
		var n: Array = _queue.pop_front()
		_slip(n[0], n[1], n[2])
	var hp: float = clampf(player.health / player.health_max, 0.0, 1.0)  # the trail: snaps up on a heal, waits, drains
	if hp >= _hp_lag:
		_hp_lag = hp
	elif _hp_hold > 0.0:
		_hp_hold -= delta
	else:
		_hp_lag = move_toward(_hp_lag, hp, delta * 0.5)
	var spent: bool = player.stamina < player.stamina_max - 0.5
	_st_a = move_toward(_st_a, 1.0 if spent else 0.0, delta * (6.0 if spent else 1.2))
	var w: Weapons = player.weapons
	var g := w.gun()
	var sp := w.spec()
	_ammo.visible = play and sp.kind != "melee"
	_cross.visible = (g != "" or player.bottles > 0 or player.smokes > 0) and player.controls_enabled  # throws land on it too
	if w.dry() and not _told_dry:  # the moment it matters: the gun just ran dry
		_told_dry = true
		note("Empty. B strikes.", "", 3.0)
	if w.owned.size() > _slot_count:  # a new weapon: the card points at the wheel that holds them all
		_wheel_hint = 5.0
	_slot_count = w.owned.size()
	_wheel_hint = maxf(_wheel_hint - delta, 0.0)
	if sp.kind != "melee":
		_ammo.text = "%d / %d" % [w.loaded[g], w.reserve[g]]
		_ammo.add_theme_color_override("font_color", MenuDraw.RUST_HI if w.dry() else MenuDraw.BONE)
	_cross.modulate.a = 1.0 if player.aiming else 0.45
	if g != _last_gun:
		_swap_t = 0.0
	_swap_t += delta
	_wui.visible = play
	_wui.queue_redraw()
	_last_gun = g
	var k: Node = player.takedown_target() if player.controls_enabled else null
	var t: Node = player.interact_target() if player.controls_enabled else null
	var vis: bool = k != null or (t != null and not t.auto)
	if vis:
		_prompt.text = tr("Takedown") if k else tr(t.prompt)  # keeps the last text while fading out
		_prompt.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45) if k else Color(0.95, 0.92, 0.8))
	_prompt_box.modulate.a = move_toward(_prompt_box.modulate.a, 1.0 if vis else 0.0, delta * 4.0)


func _build_prompt() -> void:
	## Interaction prompt: a drawn "E" keycap + action text, centred in the lower third, fades in/out.
	_prompt_box = HBoxContainer.new()
	_prompt_box.anchor_left = 0.0
	_prompt_box.anchor_right = 1.0
	_prompt_box.anchor_top = 1.0
	_prompt_box.anchor_bottom = 1.0
	_prompt_box.offset_top = -118
	_prompt_box.offset_bottom = -100
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_theme_constant_override("separation", 6)
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.modulate.a = 0.0
	_root.add_child(_prompt_box)
	var key := PanelContainer.new()
	_key_style = StyleBoxFlat.new()
	_key_style.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	_key_style.border_color = Color(0.88, 0.83, 0.7)
	_key_style.set_border_width_all(1)
	_key_style.border_width_bottom = 3
	_key_style.set_corner_radius_all(2)
	_key_style.content_margin_left = 5
	_key_style.content_margin_right = 5
	_key_style.content_margin_top = 0
	_key_style.content_margin_bottom = 0
	key.add_theme_stylebox_override("panel", _key_style)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_child(key)
	var e := Label.new()
	e.text = "E"
	e.add_theme_font_size_override("font_size", 11)
	e.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(e)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_child(_prompt)
	player.interacted.connect(_on_interacted.unbind(1))


func _on_interacted() -> void:
	## "Press" feedback: the keycap flashes and settles back.
	if _key_tw:
		_key_tw.kill()
	_key_style.bg_color = Color(1.0, 0.88, 0.55, 0.95)
	_key_style.border_width_bottom = 1
	_key_tw = create_tween()
	_key_tw.tween_property(_key_style, "bg_color", Color(0.08, 0.07, 0.06, 0.85), 0.35)
	_key_tw.parallel().tween_property(_key_style, "border_width_bottom", 3, 0.12)


# ------------------------------------------------------------------ API used by player / chapters

func show_zone(zone_name: String) -> void:
	if not player.controls_enabled:
		return  # zone volumes fire as cinematics teleport the stand-in: no stale titles over a shot
	if zone_label.text == zone_name and zone_label.modulate.a > 0.0:
		return
	zone_label.text = zone_name  # (an English id: the Label shows it translated)
	var fs := 20
	var shown := tr(zone_name)
	if shown != zone_name:  # a longer translation shrinks (to 16) to stay clear of the note slips on the left
		while fs > 16 and zone_label.get_theme_font("font").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1,
				fs).x > 250.0:
			fs -= 1
	zone_label.add_theme_font_size_override("font_size", fs)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(zone_label, "modulate:a", 1.0, 1.0)
	_tween.tween_interval(2.5)
	_tween.tween_property(zone_label, "modulate:a", 0.0, 1.5)


func objective(text: String, target: Variant = null) -> void:
	## target (Vector3 / Node3D / null) is handed to the Guide (minimap, compass, waypoint marker).
	## A new one comes in with its panel lit and a warm flash, holds OBJ_HOLD s, then the panel fades and the line
	## stays as bare shadowed text, out of the way.
	var fresh := text != _objective_id and text != ""
	_objective_id = text
	_objective.text = tr(text) if text != "" else ""
	if fresh:
		if _obj_tw:
			_obj_tw.kill()
		_obj_panel.modulate = Color(1.5, 1.35, 1.1, 0.0)
		_obj_panel.self_modulate.a = 1.0
		_obj_tw = create_tween()
		_obj_tw.tween_property(_obj_panel, "modulate", Color.WHITE, 0.4)
		_obj_tw.tween_interval(OBJ_HOLD)
		_obj_tw.tween_property(_obj_panel, "self_modulate:a", 0.0, 1.2)
	var guide := player.get_node_or_null("Guide")
	if guide:
		guide.set_target(target, text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _objective:  # a language switch (Settings): the objective again
		_objective.text = tr(_objective_id) if _objective_id != "" else ""
		(_obj_panel.get_child(0).get_child(0) as Label).text = tr("Objective").to_upper()


func _build_objective() -> void:
	## Top left, one column: the objective panel (an amber edge, OBJECTIVE over the line), the toasts under it.
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_LEFT)
	col.position = Vector2(10, 10)
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	_obj_panel = _toast_panel(Color(MenuDraw.AMBER, 0.9))
	_obj_panel.visible = false
	col.add_child(_obj_panel)
	var lines := _obj_panel.get_child(0)
	lines.add_child(_caps("Objective", MenuDraw.AMBER))
	_objective = _toast_text("")
	lines.add_child(_objective)
	_notes = VBoxContainer.new()
	_notes.add_theme_constant_override("separation", 4)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_notes)


func _toast_panel(edge: Color) -> PanelContainer:
	## The HUD's one panel: dark, rounded, a 2 px coloured edge on its left; holds a VBox for its lines.
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(MenuDraw.FOLDER, 0.78)
	sb.set_corner_radius_all(5)
	sb.border_color = edge
	sb.border_width_left = 2
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lines)
	return p


func _caps(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = tr(text).to_upper()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (already translated, upper-cased)
	l.add_theme_font_override("font", _d.caps)
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _toast_text(text: String) -> Label:
	## A toast's body: Barlow 9 in Bone, wrapped to the column, with a shadow that holds once the panel has faded.
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(160, 0)  # (the column ends at x 188: clear of the compass, 210..430)
	l.add_theme_font_override("font", _d.ui)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", MenuDraw.BONE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func hit_marker(double_tap: bool) -> void:
	_hitmark.add_theme_color_override("font_color", Color(1, 0.8, 0.2) if double_tap else Color(1, 0.3, 0.2))
	_hitmark.modulate.a = 1.0
	create_tween().tween_property(_hitmark, "modulate:a", 0.0, 0.25)


func mark_spike(amount: float) -> void:
	## A flare of the Mark's distortion that fades by itself (ScreenFx.spike): story beats, a reveal.
	_fx.spike(amount)


func mark_notice(gain: float) -> void:
	## "MARK +N%" under the clock: a red flash that holds a moment and fades. A rise while it's still up adds to it
	## and starts it over, so a flurry of hits reads as one notice.
	if gain <= 0.0:
		return
	_mark_n = (_mark_n if _mark_tw and _mark_tw.is_running() else 0.0) + gain
	_mark_note.text = tr("MARK +%s%%") % pct(_mark_n)
	if _mark_tw:
		_mark_tw.kill()
	_mark_note.modulate = Color(2.2, 1.6, 1.4, 1.0)  # the flash
	_mark_tw = create_tween()
	_mark_tw.tween_property(_mark_note, "modulate", Color.WHITE, 0.3)
	_mark_tw.tween_interval(Feel.MARK_NOTICE_HOLD)
	_mark_tw.tween_property(_mark_note, "modulate:a", 0.0, Feel.MARK_NOTICE_FADE)


static func pct(v: float) -> String:
	## A Mark percentage as the HUD writes it: "4", "0.5", "37.4" (one decimal, none when it's whole).
	var r := snappedf(v, 0.1)
	return str(roundi(r)) if is_equal_approx(r, roundf(r)) else "%.1f" % r


func _track_mark(play: bool) -> void:
	## Rises that aren't hits (player.marked) are the slow creep of Chapter 3's nights: gathered and told every
	## Feel.MARK_NOTICE_CREEP %. A jump that is neither (a save / dev start, a checkpoint restore) is not a rise.
	var m: float = player.mark
	var creep := m - _mark_last - _mark_hits if _mark_last >= 0.0 else 0.0
	_mark_last = m
	_mark_hits = 0.0
	if play and creep > 0.0 and creep < 0.5:
		_mark_creep += creep
		if _mark_creep >= Feel.MARK_NOTICE_CREEP:
			mark_notice(_mark_creep)
			_mark_creep = 0.0


func damage_flash() -> void:
	_hurt.color.a = 0.35
	create_tween().tween_property(_hurt, "color:a", 0.0, 0.5)
	_hp_hold = 0.45  # the health bar's trail holds what was lost a moment, then drains
	_fx.on_hurt()  # and the edges blur red, more the less health is left


func note(text: String, title := "", time := 3.5) -> void:
	## An old-paper slip, top left (tips, achievements): queued, one on screen at a time, a few seconds each.
	_queue.append([text, title, minf(time, 4.5)])


func _slip(text: String, title: String, time: float) -> void:
	## A toast: the objective's panel with a bone edge (amber with a title: an achievement, a new rule), slides in
	## from the left, holds, fades.
	Snd.sfx("save" if text.begins_with("Saved") else "notify", null, -4.0)
	var slip := _toast_panel(Color(MenuDraw.AMBER, 0.9) if title != "" else Color(MenuDraw.BONE, 0.45))
	var lines := slip.get_child(0)
	if title != "":
		lines.add_child(_caps(title, MenuDraw.AMBER))
	lines.add_child(_toast_text(text))
	var wrap := Control.new()  # (the box lays the wrap out; the slip slides inside it)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(slip)
	_notes.add_child(wrap)
	wrap.custom_minimum_size = slip.get_combined_minimum_size()
	slip.position.x = -14.0
	slip.modulate.a = 0.0
	var tw := slip.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(slip, "position:x", 0.0, 0.3)
	tw.parallel().tween_property(slip, "modulate:a", 1.0, 0.25)
	tw.tween_interval(time)
	tw.tween_property(slip, "modulate:a", 0.0, 0.5)
	tw.tween_callback(wrap.queue_free)


func _icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := WeaponWheel.ICON_DIR % id
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]


func _pill(r: Rect2, col: Color) -> void:
	if r.size.x >= 0.5:
		Icons.fill_round(_wui, r, minf(r.size.y, r.size.x) / 2.0, col)


func _draw_hud() -> void:
	var c := _wui
	var H := c.size.y
	# vitals, bottom left: a heart and a pill track per bar; health keeps a pale trail of what a hit just took, and
	# beats under 30%. Stamina shows while it's spent. The gas mask's filter under them, once Alex has the mask.
	var hp: float = clampf(player.health / player.health_max, 0.0, 1.0)
	var low := hp < 0.3
	var beat := 0.5 + 0.5 * sin(_t * 7.0) if low else 0.0
	var y := H - 30.0
	Icons.draw(c, "heart", Vector2(16, y + 2.5), 9.0 + beat, Color(HP.lerp(Color.WHITE, beat * 0.3), 0.95))
	_pill(Rect2(BAR_X, y, BAR_W, 5), Color(0, 0, 0, 0.45))
	_pill(Rect2(BAR_X, y, BAR_W * _hp_lag, 5), Color(MenuDraw.BONE, 0.55))
	_pill(Rect2(BAR_X, y, BAR_W * hp, 5), HP.lerp(Color(1, 0.55, 0.45), beat * 0.4))
	if _st_a > 0.01:
		var st: float = clampf(player.stamina / player.stamina_max, 0.0, 1.0)
		var tired: bool = player.get("_exhausted")
		var sc := Color(MenuDraw.RUST_HI, _st_a) if tired else Color(MenuDraw.BONE, 0.85 * _st_a)
		Icons.draw(c, "run", Vector2(16, y + 11.5), 8.0, Color(MenuDraw.BONE, 0.75 * _st_a))
		_pill(Rect2(BAR_X, y + 10, BAR_W, 3), Color(0, 0, 0, 0.4 * _st_a))
		_pill(Rect2(BAR_X, y + 10, BAR_W * st, 3), sc)
	if player.gas_mask:
		var f: float = clampf(player.mask_filter, 0.0, 1.0)
		var on: bool = player.mask_on
		var warn: bool = on and f < 0.25 and fmod(_t, 0.6) < 0.3
		var tex := _icon("filter")
		if tex:
			c.draw_texture_rect(tex, Rect2(11, y + 15, 10, 10), false, Color(1.6, 1.6, 1.6, 1.0 if on else 0.5))
		_pill(Rect2(BAR_X, y + 18.5, BAR_W, 3), Color(0, 0, 0, 0.4))
		_pill(Rect2(BAR_X, y + 18.5, BAR_W * f, 3), MenuDraw.RUST_HI if warn else Color(FILTER, 1.0 if on else 0.45))
	_draw_weapon(c)


func _draw_weapon(c: Control) -> void:
	## Bottom right: one card for what's in hand (the wheel, Tab, holds the rest): its icon, its name, a pip per round
	## in the magazine or what it's busy with, and the ammo count (_ammo). It flares amber on a swap. Over it, the belt:
	## a chip per throwable / tea carried, with its count and quick key.
	var w: Weapons = player.weapons
	var g := w.gun()
	var sp := w.spec()
	var r := Rect2(c.size - CARD - Vector2(10, 12), CARD)
	var flare := clampf(1.0 - _swap_t / 0.4, 0.0, 1.0)
	Icons.fill_round(c, r, 6.0, Color(MenuDraw.FOLDER, 0.78))
	c.draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(2, r.size.y - 12)), Color(sp.color, 0.9))  # its colour
	if flare > 0.0:
		c.draw_polyline(Icons.round_rect(r.grow(flare * 2.0), 6.0), Color(MenuDraw.AMBER, flare), 1.0, true)
	var icon_r := Rect2(r.position + Vector2(6, 2), Vector2(32, 32))
	var id := g if g != "" else "fists"
	var tex := _icon(id)
	if tex:
		var lift: float = WeaponWheel.ICON_LIFT.get(id, 1.0)
		c.draw_texture_rect(tex, icon_r, false, Color(lift, lift, lift))
	else:
		Icons.draw(c, id, icon_r.get_center(), 20.0, MenuDraw.BONE, 1.4)
	var x := r.position.x + 42.0
	var ranged: bool = sp.kind != "melee"
	var name_w := r.end.x - x - (_ammo.get_minimum_size().x + 12.0 if ranged else 8.0)
	var name_y := r.position.y + (16.0 if ranged else 21.0)
	_d.text(_d.caps, Vector2(x, name_y), _d.fit(_d.caps, tr(sp.name).to_upper(), 8, name_w), 8, MenuDraw.BONE)
	if ranged:
		var py := r.position.y + 21.0
		if w.dry() or w.reloading():
			var busy := tr("EMPTY") if w.dry() else (tr("nocking") if g == "bow" else tr("reloading")).to_upper()
			_d.text(_d.caps, Vector2(x, py + 6.0), busy, 7, MenuDraw.RUST_HI if w.dry() else MenuDraw.AMBER)
		else:
			var mag: int = sp.mag
			for k in mag:
				_pill(Rect2(x + k * 6.0, py, 3.5, 7), MenuDraw.AMBER if k < int(w.loaded[g]) else Color(MenuDraw.BONE, 0.18))
	if _wheel_hint > 0.0:  # just picked up: left of the card, the key that opens them all
		var a := minf(_wheel_hint, 1.0)
		var label := tr("Weapon wheel")
		var tx := r.position.x - 8.0 - _d.ui.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_d.shadowed(_d.ui, Vector2(tx, r.get_center().y + 3.0), label, 8, Color(MenuDraw.BONE, a))
		var kw := _d.caps.get_string_size("TAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 9.0
		var kr := Rect2(tx - 5.0 - kw, r.get_center().y - 6.5, kw, 13)
		Icons.fill_round(c, kr, 3.0, Color(0, 0, 0, 0.5 * a))
		c.draw_polyline(Icons.round_rect(kr, 3.0), Color(MenuDraw.BONE, 0.55 * a), 1.0, true)
		_d.text(_d.caps, kr.position + Vector2(4.5, 9.1), "TAB", 7, Color(MenuDraw.BONE, a))
	var right := r.end.x
	for it in BELT:  # right to left over the card
		var n := int(player.get(it[1]))
		if n <= 0:
			continue
		var count := "×%d" % n
		var cw := _d.bold.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var kw := _d.caps.get_string_size(it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 7.0
		var chip := Rect2(right - (19.0 + cw + 5.0 + kw + 5.0), r.position.y - 19.0, 19.0 + cw + 5.0 + kw + 5.0, 15)
		Icons.fill_round(c, chip, 7.5, Color(MenuDraw.FOLDER, 0.78))
		var t := _icon(it[0])
		if t:
			var lift: float = WeaponWheel.ICON_LIFT.get(it[0], 1.0) * 1.5  # (small on a dark chip: brighter still)
			c.draw_texture_rect(t, Rect2(chip.position + Vector2(3, 0.5), Vector2(14, 14)), false, Color(lift, lift, lift))
		_d.text(_d.bold, chip.position + Vector2(19, 10.5), count, 8, MenuDraw.BONE)
		var kr := Rect2(chip.end.x - 5.0 - kw, chip.position.y + 2.5, kw, 10)
		c.draw_polyline(Icons.round_rect(kr, 2.5), Color(MenuDraw.BONE, 0.4), 1.0, true)
		_d.text(_d.caps, kr.position + Vector2(3.5, 7.6), it[2], 7, MenuDraw.MUTED)
		right = chip.position.x - 4.0


func banner(text: String, color := Color.WHITE, hold := 1.5) -> void:
	if _banner_tw:
		_banner_tw.kill()
	Snd.caption(text)
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 0.0
	_banner_tw = create_tween()
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.1)
	_banner_tw.tween_interval(hold)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func boss_active() -> bool:
	## A boss fight is on (its bar is up).
	return _boss.visible


func boss_bar(title: String, frac: float) -> void:
	if (frac >= 0.0) != _boss.visible:  # the fight starts / ends
		if frac >= 0.0:
			Snd.stinger("boss", -12.0)
			Snd.push_music("boss", 0.8)
		else:
			Snd.pop_music(3.0)
	_boss.visible = frac >= 0.0
	_boss_name.text = title
	_boss_fill.size.x = 240.0 * clampf(frac, 0.0, 1.0)


func letterbox(on: bool, time := 0.7) -> void:
	## Cinematic bars (6% of the height each) slide in / out.
	var h := 22.0 if on else 0.0
	for i in _bars.size():
		var prop := "offset_bottom" if i == 0 else "offset_top"
		var to := h if i == 0 else -h
		if time <= 0.0:
			_bars[i].set(prop, to)
		else:
			create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_bars[i], prop, to, time)


func fade(alpha: float, time := 0.6) -> Signal:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	return tw.finished


func subtitle(speaker: String, text: String, time := -1.0, args := []) -> void:
	## Coroutine: shows one line and returns when it's done (or skipped with Enter / E). `text` is the English id
	## (with `args`: a template, "%d of 12." and [n]): the line shows (and is babbled) translated. A translation
	## that runs longer stays up longer, fixed times too: the English time plus the reading pace (0.055 s a letter,
	## as for an untimed line) for every extra letter. English keeps its timing exactly.
	var line := tr(text) % args if not args.is_empty() else tr(text)
	if not args.is_empty():
		text = text % args
	var extra := maxf(line.length() - text.length(), 0) * 0.055
	if time < 0.0:
		time = clampf(1.1 + text.length() * 0.055, 1.6, 6.5)
	time += extra
	var c: Color = SPEAKERS.get(speaker, Color.WHITE)
	if speaker == "":  # narration / sound captions: the ones that name a sound get it (found from the id)
		Snd.caption(text)
		_sub.text = "[i]%s[/i]" % line
	else:
		_sub.text = "[b][color=#%s]%s:[/color][/b] %s" % [c.to_html(false), tr(speaker).to_upper(), line]
	_sub_panel.visible = true
	_skip = false
	_line += 1
	var me := _line
	Snd.voice(speaker, line, time)
	var left := time
	while left > 0.0 and not (_skip and left < time - 0.3):
		await get_tree().process_frame
		left -= get_process_delta_time()
	if me == _line:  # (a newer line took the panel over: it stays, with its voice)
		Snd.stop_voice()
		_sub_panel.visible = false


func say(lines: Array) -> void:
	## Coroutine: [[speaker, text], ...] one after another ([speaker, text, time, args] for a template).
	for l in lines:
		await subtitle(l[0], l[1], l[2] if l.size() > 2 else -1.0, l[3] if l.size() > 3 else [])


func clock(text: String) -> void:
	## Small in-game clock under the minimap ("" hides it); flashes when it changes.
	_clock.text = text
	_clock.modulate = Color(1.6, 1.4, 0.9)
	create_tween().tween_property(_clock, "modulate", Color.WHITE, 1.2)


func qte(action: String, presses: int, time: float) -> bool:
	## Coroutine: mash `action` `presses` times within `time` s. Big keycap + fill bar + timer;
	## reads Input directly, so it works inside cinematics (controls disabled).
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(0, 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var key := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.07, 0.06, 0.9)
	st.border_color = Color(1.0, 0.85, 0.55)
	st.set_border_width_all(2)
	st.border_width_bottom = 5
	st.set_corner_radius_all(3)
	st.content_margin_left = 10
	st.content_margin_right = 10
	key.add_theme_stylebox_override("panel", st)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(key)
	var kl := Label.new()
	kl.text = _key_name(action)
	kl.add_theme_font_size_override("font_size", 22)
	kl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_child(kl)
	key.size = key.get_combined_minimum_size()
	key.position = Vector2(-key.size.x / 2.0, -40)
	key.pivot_offset = key.size / 2.0
	var cap := Label.new()
	cap.text = "MASH!"
	cap.add_theme_font_size_override("font_size", 9)
	cap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cap.add_theme_constant_override("outline_size", 3)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(120, 12)
	cap.position = Vector2(-60, 0)
	box.add_child(cap)
	var bars: Array[ColorRect] = []
	for spec in [[Color(0.1, 0.08, 0.06, 0.85), 16, 6], [Color(1.0, 0.8, 0.4), 16, 6], [Color(0.8, 0.8, 0.75), 24, 2]]:
		var r := ColorRect.new()
		r.color = spec[0]
		r.position = Vector2(-60, spec[1])
		r.size = Vector2(120, spec[2])
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(r)
		bars.append(r)
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 0.12)
	var n := 0
	var left := time
	var was := Input.is_action_pressed(action)  # count press edges (a held key doesn't count)
	while left > 0.0 and n < presses:
		await get_tree().process_frame
		left -= get_process_delta_time()
		key.scale = key.scale.move_toward(Vector2.ONE * (1.0 + 0.06 * sin(_t * 14.0)), get_process_delta_time() * 3.0)
		var down := Input.is_action_pressed(action)
		if down and not was:
			n += 1
			key.scale = Vector2.ONE * 1.3
			st.bg_color = Color(1.0, 0.88, 0.55, 0.95)
			create_tween().tween_property(st, "bg_color", Color(0.08, 0.07, 0.06, 0.9), 0.15)
		was = down
		bars[1].size.x = 120.0 * n / presses
		bars[2].size.x = 120.0 * maxf(left, 0.0) / time
		bars[2].color = Color(0.9, 0.3, 0.2) if left < time * 0.3 else Color(0.8, 0.8, 0.75)
	var ok := n >= presses
	cap.text = "OK" if ok else "FAILED"
	cap.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.35, 0.3))
	bars[1].color = cap.get_theme_color("font_color")
	var tw := create_tween()
	tw.tween_property(key, "scale", Vector2.ONE * (1.5 if ok else 0.8), 0.25)
	tw.parallel().tween_property(box, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tw.tween_callback(box.queue_free)
	return ok


func _key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return action.to_upper()
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.as_text_physical_keycode()
	return action.to_upper()
