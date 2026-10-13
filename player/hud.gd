extends CanvasLayer
## Player HUD (gameplay.md §10): health/stamina, the Mark's "MARK +N%" notice, gun + ammo, crosshair and hit markers,
## objective, interaction prompt, subtitles (every line is on screen and babbled by Snd.voice), banners
## (DOUBLE TAP, chapter cards), boss bar, fades. Zone areas call show_zone via the "hud" group.
## Chapter 2: clock, QTE (mash prompt), gas mask filter bar + mask vignette, bottle count, takedown prompt.
## Chapter 3: the item belt line (bottles / smoke cans / tea).
## Feel (scripts/feel.gd): the drawn eye (HudEyes: Alex's visibility), off-screen threat arcs (ThreatArcs)
## and the screen effects of the Mark and of pain (ScreenFx, through the Post shader).

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
var _health: ColorRect
var _health_back: ColorRect
var _stamina: ColorRect
var _stamina_back: ColorRect
var _eyes: HudEyes
var _arcs: ThreatArcs
var _fx: ScreenFx
var _ammo: Label
var _gun: Label
var _slots: Label  ## every weapon carried, number keys to draw it; the drawn one in brackets
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
var _filter: ColorRect
var _filter_back: ColorRect
var _bottles: Label
var _mask: TextureRect
var _gas: ColorRect
var _t := 0.0
var _hint_shown := false
var _last_gun := ""
var _slot_count := 0
var _notes: VBoxContainer  ## old-paper notification slips, top left under the objective
var _wui: Control  ## weapon cards + ammo pips (drawn)
var _swap_t := 0.0  ## seconds since the drawn weapon changed (the card flares)
const TIP := "WASD move · Shift run · F light"  ## the only note at the start; the rest come when they matter
var _queue: Array = []  ## notes wait their turn: one slip on screen at a time
var _told_dry := false
const INK := Color(0.16, 0.11, 0.07)
const PAPER := Color(0.87, 0.8, 0.63)


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
	_health_back = _bar(Vector2(12, -30), Vector2(110, 6), Color(0.15, 0.02, 0.02, 0.8))
	_health = _bar(Vector2(12, -30), Vector2(110, 6), Color(0.7, 0.12, 0.1))
	_stamina_back = _bar(Vector2(12, -21), Vector2(110, 3), Color(0.1, 0.1, 0.1, 0.8))
	_stamina = _bar(Vector2(12, -21), Vector2(110, 3), Color(0.75, 0.75, 0.6))
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
	_filter_back = _bar(Vector2(12, -15), Vector2(110, 3), Color(0.05, 0.1, 0.08, 0.8))
	_filter = _bar(Vector2(12, -15), Vector2(110, 3), Color(0.45, 0.8, 0.6))
	_bottles = _label("", 9, Color(0.6, 0.85, 0.65), Control.PRESET_BOTTOM_LEFT, Vector2(12, -46), Vector2(240, 12))
	# bottom right: weapon cards (drawn, _draw_weapons), the drawn weapon's name, pips + ammo count
	_gun = _label("", 9, Color(0.75, 0.72, 0.65), Control.PRESET_BOTTOM_RIGHT, Vector2(-190, -52), Vector2(180, 12))
	_gun.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo = _label("", 16, Color(0.9, 0.88, 0.8), Control.PRESET_BOTTOM_RIGHT, Vector2(-130, -26), Vector2(120, 20))
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_slots = _label("", 7, Color(0.7, 0.68, 0.6), Control.PRESET_BOTTOM_RIGHT, Vector2(-330, -64), Vector2(320, 10))
	_slots.visible = false  # (replaced by the cards)
	_wui = Control.new()
	_wui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wui.draw.connect(_draw_weapons)
	_root.add_child(_wui)
	_eyes = HudEyes.new()
	_root.add_child(_eyes)
	_eyes.setup(player)
	_arcs = ThreatArcs.new()
	_root.add_child(_arcs)
	_arcs.setup(player)
	_notes = VBoxContainer.new()
	_notes.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_notes.position = Vector2(10, 40)
	_notes.custom_minimum_size = Vector2(190, 0)
	_notes.add_theme_constant_override("separation", 4)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_notes)
	_cross = _label("+", 12, Color(1, 1, 1, 0.8), Control.PRESET_CENTER, Vector2(-10, -9), Vector2(20, 18))
	_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hitmark = _label("x", 14, Color(1, 0.3, 0.2), Control.PRESET_CENTER, Vector2(-10, -10), Vector2(20, 18))
	_hitmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hitmark.modulate.a = 0.0
	_objective = _label("", 9, Color(0.85, 0.82, 0.7), Control.PRESET_TOP_LEFT, Vector2(12, 10), Vector2(300, 30))
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


func _bar(pos: Vector2, size: Vector2, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	r.position = pos
	r.size = size
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
	for n in [_health, _health_back, _stamina, _stamina_back, _eyes, _arcs, _objective, _prompt_box, hint, _clock,
			_mark_note]:
		n.visible = play
	_t += delta
	_track_mark(play)
	var masked: bool = player.mask_on
	var owned: bool = player.gas_mask
	_filter.visible = play and owned
	_filter_back.visible = play and owned
	var low: bool = player.mask_filter < 0.25 and masked
	_filter.size.x = 110.0 * player.mask_filter
	_filter.color = Color(0.9, 0.3, 0.2) if low and fmod(_t, 0.6) < 0.3 else Color(0.45, 0.8, 0.6, 1.0 if masked else 0.45)
	_mask.visible = masked
	_mask.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(_t * 1.6))  # breathing fogs the lenses
	var choking: bool = player.in_gas() and not (masked and player.mask_filter > 0.0)
	_gas.color.a = move_toward(_gas.color.a, 0.22 if choking else 0.0, delta * 0.8)
	var items := []  # throwables / consumables on the belt
	for it in [[player.bottles, "Bottle", "G"], [player.smokes, "Smoke", "T"], [player.teas, "Tea", "H"]]:
		if it[0] > 0:
			items.append("%s ×%d [%s]" % [it[1], it[0], it[2]])
	_bottles.visible = play and not items.is_empty()
	_bottles.text = "  ".join(items)
	if play and not _hint_shown:  # the first time the player's in control: one line of controls
		_hint_shown = true
		get_tree().create_timer(1.0).timeout.connect(note.bind(TIP, "", 4.0))
	if play and _notes.get_child_count() == 0 and not _queue.is_empty():
		var n: Array = _queue.pop_front()
		_slip(n[0], n[1], n[2])
	_health.size.x = 110.0 * player.health / player.health_max
	_stamina.size.x = 110.0 * player.stamina / player.stamina_max
	var w: Weapons = player.weapons
	var g := w.gun()
	var sp := w.spec()
	_gun.visible = play
	_ammo.visible = play and sp.kind != "melee"
	_cross.visible = (g != "" or player.bottles > 0 or player.smokes > 0) and player.controls_enabled  # throws land on it too
	var title: String = sp.name.to_upper()
	if w.dry():
		title += "  · EMPTY"
		if not _told_dry:  # the moment it matters: the gun just ran dry
			_told_dry = true
			note("Empty. B strikes.", "", 3.0)
	elif w.reloading():
		title += "  · nocking" if g == "bow" else "  · reloading"
	_gun.text = title
	if g != _last_gun:  # drawn: the name takes the weapon's colour and flares up
		_gun.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65).lerp(sp.color, 0.6))
		create_tween().tween_property(_gun, "modulate", Color.WHITE, 0.5).from(Color(2.0, 2.0, 2.0))
	if g != _last_gun or w.owned.size() != _slot_count:
		_slot_count = w.owned.size()
		var slots := PackedStringArray()
		for i in w.owned.size():
			var n: String = Weapons.GUNS[w.owned[i]].name.to_upper()
			slots.append(("[%d %s]" if i == w.current else "%d %s") % [i + 1, n])
		_slots.text = "   ".join(slots)
	if sp.kind != "melee":
		_ammo.text = "%d / %d" % [w.loaded[g], w.reserve[g]]
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
		_prompt.text = "Takedown" if k else t.prompt  # keeps the last text while fading out
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
	zone_label.text = zone_name
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(zone_label, "modulate:a", 1.0, 1.0)
	_tween.tween_interval(2.5)
	_tween.tween_property(zone_label, "modulate:a", 0.0, 1.5)


func objective(text: String, target: Variant = null) -> void:
	## target (Vector3 / Node3D / null) is handed to the Guide (minimap, compass, waypoint marker).
	_objective.text = "> " + text if text != "" else ""
	var guide := player.get_node_or_null("Guide")
	if guide:
		guide.set_target(target, text)


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
	_mark_note.text = "MARK +%s%%" % pct(_mark_n)
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
	_fx.on_hurt()  # and the edges blur red, more the less health is left


func note(text: String, title := "", time := 3.5) -> void:
	## An old-paper slip, top left (tips, achievements): queued, one on screen at a time, a few seconds each.
	_queue.append([text, title, minf(time, 4.5)])


func _slip(text: String, title: String, time: float) -> void:
	Snd.sfx("save" if text.begins_with("Saved") else "notify", null, -4.0)
	var slip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = Color(0.45, 0.33, 0.18)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_content_margin_all(5)
	sb.content_margin_left = 9
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(2, 2)
	slip.add_theme_stylebox_override("panel", sb)
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	slip.add_child(col)
	if title != "":
		var t := Label.new()
		t.text = title.to_upper()
		t.add_theme_font_size_override("font_size", 8)
		t.add_theme_color_override("font_color", Color(0.55, 0.12, 0.08))
		col.add_child(t)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(176, 0)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", INK)
	col.add_child(l)
	_notes.add_child(slip)
	slip.rotation_degrees = randf_range(-1.2, 1.2)
	slip.modulate = Color(1.6, 1.5, 1.2, 0.0)  # fades in with a warm flash
	var tw := slip.create_tween()
	tw.tween_property(slip, "modulate", Color(1, 1, 1, 1), 0.35)
	tw.tween_interval(time)
	tw.tween_property(slip, "modulate:a", 0.0, 0.6)
	tw.tween_callback(slip.queue_free)


func _draw_weapons() -> void:
	## Weapon cards bottom right, one per carried weapon (number key, short name, colour stripe). The drawn one
	## sits raised and bright with a pulsing edge in its colour, and flares when it's just been drawn; the others
	## are dim. Under the name: a pip per round in the magazine (lit = loaded).
	var w: Weapons = player.weapons
	var c := _wui
	var font := ThemeDB.fallback_font
	var owned: Array = w.owned
	var cw := 54.0
	var gap := 4.0
	var right := c.size.x - 10.0
	var y := c.size.y - 80.0
	var n := maxi(owned.size(), 1)
	for i in n:
		var id: String = owned[i] if owned.size() > 0 else ""
		var sp: Dictionary = Weapons.GUNS[id] if id != "" else Weapons.FISTS
		var sel := (i == w.current and id != "") or owned.is_empty()
		var x := right - (n - i) * (cw + gap) + gap
		var flare := clampf(1.0 - _swap_t / 0.35, 0.0, 1.0) if sel else 0.0
		var r := Rect2(x, y - (5.0 if sel else 0.0) - flare * 3.0, cw, 22.0)
		var col: Color = sp.color
		c.draw_rect(r, Color(0.05, 0.045, 0.04, 0.92 if sel else 0.6))
		c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(cw, 3)), Color(col, 1.0 if sel else 0.35))
		if sel:  # glowing edge: pulses, and blazes for a moment on the swap
			var glow := 0.55 + 0.25 * sin(_t * 5.0) + flare * 0.8
			for k in 3:
				c.draw_rect(r.grow(1.0 + k * 1.5), Color(col, glow * (0.5 - k * 0.15)), false, 1.0)
		var short: String = {"revolver": "REVOLVER", "flare": "FLARE", "shotgun": "SHOTGUN", "bow": "BOW",
			"axe": "AXE", "bat": "BAT"}.get(id, "FISTS")
		var tc := Color(1, 0.96, 0.85) if sel else Color(0.6, 0.57, 0.5)
		c.draw_string(font, r.position + Vector2(3, 8), str(i + 1) if id != "" else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			Color(col, 0.9))
		c.draw_string(font, r.position + Vector2(0, 17), short, HORIZONTAL_ALIGNMENT_CENTER, cw, 7, tc)
		if id != "" and sp.kind != "melee" and w.reserve[id] + w.loaded[id] <= 0:
			c.draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 6), Color(0.8, 0.2, 0.15, 0.8), 1.0)  # dry
	var g := w.gun()
	if g != "" and Weapons.GUNS[g].kind != "melee":
		var mag: int = Weapons.GUNS[g].mag
		var loaded: int = w.loaded[g]
		for k in mag:  # the magazine: brass pips, lit while loaded
			var px := right - 124.0 - (mag - k) * 7.0
			var lit := k < loaded
			c.draw_rect(Rect2(px, c.size.y - 22.0, 4.0, 9.0), Color(1.0, 0.8, 0.4) if lit else Color(0.25, 0.22, 0.18))


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


func subtitle(speaker: String, text: String, time := -1.0) -> void:
	## Coroutine: shows one line and returns when it's done (or skipped with Enter / E).
	if time < 0.0:
		time = clampf(1.1 + text.length() * 0.055, 1.6, 6.5)
	var c: Color = SPEAKERS.get(speaker, Color.WHITE)
	if speaker == "":  # narration / sound captions: the ones that name a sound get it
		Snd.caption(text)
		_sub.text = "[i]%s[/i]" % text
	else:
		_sub.text = "[b][color=#%s]%s:[/color][/b] %s" % [c.to_html(false), speaker.to_upper(), text]
	_sub_panel.visible = true
	_skip = false
	Snd.voice(speaker, text, time)
	var left := time
	while left > 0.0 and not (_skip and left < time - 0.3):
		await get_tree().process_frame
		left -= get_process_delta_time()
	Snd.stop_voice()
	_sub_panel.visible = false


func say(lines: Array) -> void:
	## Coroutine: [[speaker, text], ...] one after another.
	for l in lines:
		await subtitle(l[0], l[1], l[2] if l.size() > 2 else -1.0)


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
