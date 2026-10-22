extends Control
## Main menu (the game's first scene): the case file on Alex's sister, set down in the fog.
##  · behind it, the real town in heavy fog, playing staged scenes from the story one after another
##    (actors posed at the motel, the bridge, the church, the Harvester at the chapel), each fading in and
##    out of black with a caption, like the title FMVs
##  · a title screen first: the logo and a "press any key" keycap; any key opens the dossier
##  · the dossier: a dark folder on the right with rounded index tabs down its edge (drawn icons, scripts/icons.gd).
##    Continue (the last save: a map photo pinned where it was made, chapter, time, Mark, weapons, the objective),
##    New (difficulty with its numbers as meters), Load, Extra (achievements), Options (scripts/settings.gd),
##    Dev, Quit. W/S choose a tab, Enter / D opens it, Esc goes back; the mouse points and clicks.
##  · grain, dither and CRT scanlines over everything. The menu draws in canvas_items scale so its type is crisp at
##    any window size; the 3D town stays low-res (its SubViewport is 640×360) and the game's own scale comes back
##    on the way out.

const SCENES := [  ## caption, line, camera from → to, looking at, cast [model, pos, yaw, gesture], light [pos, colour, energy]
	["LAST POSTCARD", "\"Hollowmere is beautiful. Don't come.\"",
		Vector3(-98, 1.1, 150), Vector3(-100, 1.4, 146.5), Vector3(-105, 1.5, 136),
		[["char_alex", Vector3(-104.5, 0, 138.5), PI, "look_around"]], [Vector3(-103, 3.0, 141), Color(1.0, 0.7, 0.45), 1.6]],
	["ROOM 6", "A shape behind the glass. A hiss. The smell of burning.",
		Vector3(-88, 1.3, 58), Vector3(-90, 1.6, 54.5), Vector3(-95.5, 1.4, 50),
		[["char_owen", Vector3(-95.0, 0.1, 50.2), -PI / 2.0, "window_press"]], [Vector3(-94.5, 2.6, 49), Color(1.0, 0.8, 0.5), 1.4]],
	["FOR THE NINE", "Who never came home.",
		Vector3(-19.4, 1.5, 0.5), Vector3(-19.2, 1.4, -1.6), Vector3(-19, 0.7, -5.5),
		[["char_marked_woman", Vector3(-19, 0, -4.6), PI, "slump"]], [Vector3(-18.6, 0.6, -5.4), Color(1.0, 0.55, 0.25), 1.2]],
	["CHANNEL 7", "\"They marked you. Stay in the grass.\"",
		Vector3(12.5, 1.4, 130), Vector3(11.5, 1.6, 131.5), Vector3(8.6, 1.3, 134),
		[["char_elena", Vector3(8.6, 0, 134.0), PI * 0.75, "hand_to_face"]], [Vector3(9, 2.4, 134.5), Color(0.6, 0.8, 1.0), 1.0]],
	["ST. BRENDAN", "The doors were never locked. Nobody leaves.",
		Vector3(-50, 1.5, -98), Vector3(-52, 1.6, -99), Vector3(-56.5, 1.5, -100),
		[["char_marcus", Vector3(-56.5, 0, -100), PI / 2.0, "arms_crossed"]], [Vector3(-57.5, 3.0, -100), Color(1.0, 0.6, 0.3), 1.6]],
	["THE HARVEST", "It never talks. Its footsteps are the only loud thing.",
		Vector3(-21, 1.0, -189), Vector3(-21.6, 1.3, -193), Vector3(-22, 2.2, -199),
		[], [Vector3(-21, 3.2, -195.5), Color(1.0, 0.15, 0.1), 4.0]],
]
const SCENE_TIME := 11.0
const DEV_STEPS := [
	["I", "The Mark", ["intro", "room", "hunt", "square", "sawmill", "boss", "blackout"]],
	["II", "Moth", ["c2_intro", "channel7", "zones", "traitor"]],
	["III", "The Harvest", ["c3_bell", "run", "marcus", "static", "gate", "harvest", "harvester", "shepherd", "epilogue"]],
]
const CHAPTERS := ["", "I — The Mark", "II — Moth", "III — The Harvest"]
const TABS := [["continue", "CONTINUE"], ["new", "NEW"], ["load", "LOAD"], ["extra", "EXTRA"],
	["options", "OPTIONS"], ["dev", "DEV"], ["quit", "QUIT"]]
const ACH_ICONS := {"ch1": "axe", "ch2": "mark", "ch3": "continue", "evidence": "load", "keys": "key",
	"untouched": "heart", "mercy": "check", "hard": "skull", "arsenal": "revolver", "old_tom": "extra",
	"candles": "flame", "cardsharp": "extra", "hands_on": "fists"}
const BONE := Color(0.914, 0.886, 0.827)
const MUTED := Color(0.7, 0.67, 0.61)  ## secondary text on the folder
const FAINT := Color(0.56, 0.53, 0.48)
const RUST := Color(0.62, 0.08, 0.06)
const RUST_HI := Color(0.77, 0.16, 0.11)
const AMBER := Color(1.0, 0.72, 0.3)
const FOLDER := Color(0.075, 0.064, 0.055)
const FOLDER_HI := Color(0.13, 0.114, 0.098)
const PRINT := Color(0.86, 0.83, 0.76)  ## the photo's white border
const Guide := preload("res://player/guide.gd")
const FOLDER_W := 222.0
const PAD := 15.0
const BAR_H := 26.0
const LOAD_ROWS := 6
const OPT_LINES := 12
const LINE_H := 17.0

var _g: Node  ## the Game autoload
var _t := 0.0
var _town: Node3D
var _cam: Camera3D
var _light: OmniLight3D
var _cast: Array[Node3D] = []
var _shot := -1
var _shot_t := 0.0
var _black: ColorRect
var _deco: Control
var _serif: Font
var _serif_it: Font
var _ui: Font
var _bold: Font
var _caps: FontVariation  ## bold, tracked: labels and keycaps
var _wide: FontVariation  ## bold, wide-tracked: HOLLOWMERE under the logo
var _logo: FontVariation
var _title := true  ## on the PRESS ANY KEY screen
var _fade := 0.0  ## 0 title → 1 dossier
var _tab := 0
var _focus := "tabs"  ## "tabs": W/S change tab · "page": W/S move inside it
var _sel := 0  ## the selection inside the page
var _top := 0  ## first visible line of a scrolled list
var _page_t := 1.0  ## 0 → 1 after a tab change (the leaf turn)
var _prev_tab := 0  ## the page turning away
var _a := 1.0  ## the page's alpha while it turns
var _saves: Array = []
var _hits: Array = []  ## [Rect2, kind, index] laid out by the last draw: what the mouse can point at
var _hover := ""  ## the hit kind under the mouse ("bar", "tab", "row")
var _opt_lines: Array = []  ## options page: ["h", title] group headers and ["r", "section/key"] rows
var _opt_ids: Array = []  ## the selectable rows' ids, in order


func _ready() -> void:
	_g = G.game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_serif = load("res://fonts/IMFeENrm28P.ttf")
	_serif_it = load("res://fonts/IMFeENit28P.ttf")
	_ui = load("res://fonts/BarlowSemiCondensed-Medium.ttf")
	_bold = load("res://fonts/BarlowSemiCondensed-Bold.ttf")
	_caps = _tracked(_bold, 1)
	_wide = _tracked(_bold, 4)
	_logo = _tracked(_serif, 16)
	for g in Settings.GROUPS:
		_opt_lines.append(["h", g[1]])
		for r in Settings.ROWS:
			if r[0] == g[0]:
				_opt_lines.append(["r", "%s/%s" % [r[0], r[1]]])
				_opt_ids.append("%s/%s" % [r[0], r[1]])
	_saves = _g.saves()
	_build_town()
	var post := ColorRect.new()  # the game's own grain / dither over the town
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.material = ShaderMaterial.new()
	(post.material as ShaderMaterial).shader = load("res://shaders/ps2_post.gdshader")
	add_child(post)
	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_deco = Control.new()
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	var fresh := BackBufferCopy.new()  # the screen texture is copied once per frame otherwise: re-copy so the UI is in it
	fresh.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(fresh)
	var crt := ColorRect.new()  # scanlines over everything, UI included
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.material = ShaderMaterial.new()
	(crt.material as ShaderMaterial).shader = load("res://shaders/menu_crt.gdshader")
	(crt.material as ShaderMaterial).set_shader_parameter("grain", 0.07)
	add_child(crt)
	_next_shot()
	Snd.music("menu", 2.5)


func _exit_tree() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT  # the game's own low-res look


func _tracked(base: Font, spacing: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_glyph = spacing
	return v


func _build_town() -> void:
	var view := SubViewportContainer.new()
	view.stretch = true
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # the town keeps its chunky pixels under crisp type
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var sub := SubViewport.new()
	view.add_child(sub)
	_town = load("res://maps/hollowmere.tscn").instantiate()
	for n in ["Chapter1", "Chapter2", "Chapter3", "Player"]:
		var c := _town.get_node_or_null(n)
		if c:
			_town.remove_child(c)
			c.free()
	sub.add_child(_town)
	var we := _town.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:  # thicker, paler fog: you see a few metres and then nothing
		var env: Environment = we.environment.duplicate()
		env.fog_light_color = Color(0.32, 0.31, 0.29)
		env.fog_density = 0.045
		env.volumetric_fog_density = 0.04
		env.volumetric_fog_albedo = Color(0.8, 0.78, 0.74)
		env.adjustment_saturation = 0.35
		we.environment = env
	_cam = Camera3D.new()
	_cam.fov = 50.0
	sub.add_child(_cam)
	_cam.current = true
	_light = OmniLight3D.new()
	_light.omni_range = 7.0
	_light.shadow_enabled = true
	_town.add_child(_light)


# ------------------------------------------------------------------ the scenes

func _next_shot() -> void:
	_shot = (_shot + 1) % SCENES.size()
	_shot_t = 0.0
	var s: Array = SCENES[_shot]
	for a in _cast:
		a.queue_free()
	_cast.clear()
	for c in s[5]:
		var a := Actor.make(_town, "res://models/%s.glb" % c[0], c[1], c[2])
		if c[3] != "":
			a.gesture(c[3])
		_cast.append(a)
	_light.position = s[6][0]
	_light.light_color = s[6][1]


func _process(delta: float) -> void:
	_t += delta
	_shot_t += delta
	var s: Array = SCENES[_shot]
	var k := clampf(_shot_t / SCENE_TIME, 0.0, 1.0)
	_cam.position = (s[2] as Vector3).lerp(s[3], k)
	_cam.look_at(s[4])
	_cam.rotation.z = sin(_t * 0.7) * 0.01  # a held camera, not a dolly
	var dark := clampf(1.5 - _shot_t, 0.0, 1.0) + clampf(_shot_t - (SCENE_TIME - 1.5), 0.0, 1.0)
	_black.color = Color(0, 0, 0, 0.2 + 0.8 * dark)
	# the light hums, now and then it stutters
	var stutter := 0.15 if fmod(_t * 7.3 + _shot * 1.7, 9.0) < 0.35 and randf() < 0.6 else 1.0
	_light.light_energy = float(s[6][2]) * stutter * (0.9 + 0.1 * sin(_t * 23.0))
	if _shot_t >= SCENE_TIME:
		_next_shot()
	_fade = move_toward(_fade, 0.0 if _title else 1.0, delta * 2.2)
	_page_t = move_toward(_page_t, 1.0, delta / 0.18)
	_deco.queue_redraw()


# ------------------------------------------------------------------ drawing: helpers

func _c(col: Color, a := 1.0) -> Color:
	## A colour at the page's current alpha (times a).
	return Color(col, col.a * a * _a)


func _str(font: Font, at: Vector2, text: String, size: int, col: Color, w := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_deco.draw_string(font, at, text, align, w, size, col)


func _shadowed(font: Font, at: Vector2, text: String, size: int, col: Color, w := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	## Text straight on the fog: a soft dark shadow under it so it holds on the bright patches.
	_deco.draw_string(font, at + Vector2(0, 1), text, align, w, size, Color(0, 0, 0, col.a * 0.7))
	_deco.draw_string(font, at, text, align, w, size, col)


func _fit(font: Font, text: String, size: int, w: float) -> String:
	## text cut to width w with an ellipsis.
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= w:
		return text
	while text.length() > 1 and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
		text = text.left(-1)
	return text.strip_edges() + "…"


func _wrap(font: Font, at: Vector2, text: String, size: int, col: Color, w: float, lines := 2) -> void:
	_deco.draw_multiline_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, w, size, lines, col)


func _key(right: float, mid_y: float, label: String, col: Color) -> float:
	## A keycap ending at x = right, centred on mid_y; returns its width.
	var w := _caps.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x + 8.0
	var r := Rect2(right - w, mid_y - 5.5, w, 11)
	_deco.draw_polyline(Icons.round_rect(r, 3.0), Color(col, col.a * 0.55), 1.0, true)
	_str(_caps, Vector2(r.position.x + 4.0, mid_y + 2.2), label, 6, col)
	return w


func _chip(x: float, y: float, icon: String, text: String, tint := Color(0, 0, 0, 0)) -> float:
	## A pill: drawn icon + a short fact. Returns its width.
	var tw := _ui.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var r := Rect2(x, y, tw + 23.0, 14.0)
	Icons.fill_round(_deco, r, 7.0, _c(BONE, 0.08) if tint.a == 0.0 else _c(tint))
	var ink := MUTED if tint.a == 0.0 else Color(0.96, 0.74, 0.68)
	Icons.draw(_deco, icon, Vector2(x + 9.5, y + 7.0), 9.0, _c(ink), 1.1)
	_str(_ui, Vector2(x + 16.5, y + 9.8), text, 7, _c(ink))
	return r.size.x


func _bar(r: Rect2, label: String, icon: String, armed: bool) -> void:
	## The page's one primary action: a rust bar with its drawn icon, its name and the ENTER keycap.
	_hits.append([r, "bar", 0])
	var hot := armed or _hover == "bar"
	var top := RUST_HI if hot else RUST.lerp(RUST_HI, 0.35)
	var pts := Icons.round_rect(r, 8.0, false)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(_c(top.lerp(RUST.darkened(0.25), (p.y - r.position.y) / r.size.y)))
	_deco.draw_polygon(pts, cols)
	Icons.draw(_deco, icon, Vector2(r.position.x + 15.0, r.get_center().y), 10.0, _c(BONE), 1.4)
	_str(_caps, Vector2(r.position.x + 27.0, r.get_center().y + 3.4), label, 9, _c(BONE))
	_key(r.end.x - 9.0, r.get_center().y, "ENTER", _c(BONE, 0.9))


func _heading(x: float, y: float, text: String, right := "") -> void:
	_str(_serif, Vector2(x, y), text, 17, _c(BONE))
	if right != "":
		_str(_ui, Vector2(x, y - 1.0), right, 7, _c(MUTED), FOLDER_W - PAD * 2.0, HORIZONTAL_ALIGNMENT_RIGHT)


func _photo(r: Rect2, pos: Variant, rot: float, label: String) -> void:
	## A print of the town map pinned where `pos` ([x, z]) is; no pos: the whole town, no pin.
	_deco.draw_set_transform(r.get_center(), rot, Vector2.ONE)
	var local := Rect2(-r.size / 2.0, r.size)
	Icons.fill_round(_deco, Rect2(local.position + Vector2(1, 3), local.size), 3.0, Color(0, 0, 0, 0.45 * _a))
	Icons.fill_round(_deco, local, 3.0, _c(PRINT))
	var img := Rect2(local.position + Vector2(4, 4), local.size - Vector2(8, 8 + (11.0 if label != "" else 0.0)))
	var span := Vector2(img.size.x, img.size.y) * (2.2 if pos != null else 2.4)  # map pixels across the print
	var c := Vector2(0, 0) if pos == null else Vector2(pos[0], pos[1])
	var px := (c - Vector2(Guide.MAP_X0, Guide.MAP_Z0)) * Guide.PPM
	var region := Rect2(px - span / 2.0, span)
	region.position = region.position.clamp(Vector2.ZERO, Vector2(Guide.MAP_PX, Guide.MAP_PX) - span)
	_deco.draw_texture_rect_region(Guide.MAP_TEX, img, region, _c(Color(0.78, 0.74, 0.66)))
	_deco.draw_rect(img, _c(Color(0.1, 0.07, 0.04), 0.18))  # aged
	if pos != null:
		var at := img.position + (px - region.position) / span * img.size
		_deco.draw_circle(at + Vector2(0, 1), 4.6, Color(0, 0, 0, 0.4 * _a), true, -1.0, true)
		_deco.draw_colored_polygon(PackedVector2Array([at + Vector2(-3.2, -4), at + Vector2(3.2, -4), at + Vector2(0, 3)]),
			_c(RUST_HI))
		_deco.draw_circle(at + Vector2(0, -5.5), 4.0, _c(RUST_HI), true, -1.0, true)
		_deco.draw_circle(at + Vector2(0, -5.5), 1.4, _c(PRINT), true, -1.0, true)
	if label != "":
		_str(_serif_it, Vector2(local.position.x + 6, local.end.y - 4.5), label, 9, _c(Color(0.2, 0.15, 0.1)))
	_deco.draw_set_transform(Vector2.ZERO)


func _place(pos: Variant) -> String:
	## The zone a save was made in (guide.gd's zone rects), "Hollowmere" outside them or without a position.
	if pos == null:
		return "Hollowmere"
	for z in Guide.ZONES:
		if pos[0] >= z[1] and pos[0] <= z[3] and pos[1] >= z[2] and pos[1] <= z[4]:
			return z[0]
	return "Hollowmere"


func _objective(s: Dictionary) -> String:
	var label := str(s.get("label", ""))
	var text := label.split(" · ", true, 1)[1] if " · " in label else label
	return text.capitalize() if text == str(s.get("step", "")) else text  # (no objective on screen: the step's name)


func _save_title(s: Dictionary) -> String:
	## A load row's name: the objective it was saved on; an autosave with none on screen, the place it was made.
	var text := _objective(s)
	if text.to_lower() == str(s.get("step", "")).to_lower() and s.get("pos", null) != null:
		return _place(s.pos)
	return text


func _row_box(r: Rect2, on: bool) -> void:
	## A list row: faint fill, the selected one brighter with a fine amber outline.
	Icons.fill_round(_deco, r, 7.0, _c(BONE, 0.095 if on else 0.04))
	if on:
		_deco.draw_polyline(Icons.round_rect(r, 7.0), _c(AMBER, 0.85), 1.0, true)


# ------------------------------------------------------------------ drawing

func _draw_deco() -> void:
	var W := _deco.size.x
	var H := _deco.size.y
	var e := ease(_fade, -2.2)
	_hits.clear()
	_a = 1.0
	# letterbox bars, like the FMVs
	_deco.draw_rect(Rect2(0, 0, W, 18), Color.BLACK)
	_deco.draw_rect(Rect2(0, H - 18, W, 18), Color.BLACK)
	_draw_logo(W, H, e)
	# the scene's caption, bottom left, in and out with the shot
	var cap := clampf(_shot_t - 2.0, 0.0, 1.0) * clampf(SCENE_TIME - 2.0 - _shot_t, 0.0, 1.0)
	var s: Array = SCENES[_shot]
	_shadowed(_serif_it, Vector2(32, H - 36), s[1], 11, Color(0.82, 0.79, 0.72, cap * 0.9))
	_shadowed(_ui, Vector2(32, H - 25), "— " + str(s[0]).capitalize(), 7, Color(0.85, 0.5, 0.44, cap * 0.95))
	if _fade < 1.0:
		var ta := 1.0 - e
		var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.6))
		var label := "PRESS ANY KEY"
		var tw := _caps.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(W / 2.0 - tw / 2.0 - 12.0, 248, tw + 24.0, 19)
		Icons.fill_round(_deco, r, 9.5, Color(0, 0, 0, 0.45 * ta))
		_deco.draw_polyline(Icons.round_rect(r, 9.5), Color(BONE, 0.35 * ta * pulse), 1.0, true)
		_str(_caps, Vector2(r.position.x + 12.0, r.position.y + 12.8), label, 8, Color(BONE, ta * pulse))
		_shadowed(_caps, Vector2(0, H - 6), "HOLLOWMERE  ·  POP. 1413", 7, Color(MUTED, 0.8 * ta), W,
			HORIZONTAL_ALIGNMENT_CENTER)
	if _fade <= 0.0:
		return
	_draw_folder(W, H, e)
	_draw_help(W, H, e)


func _draw_logo(W: float, H: float, e: float) -> void:
	## Centred and large on the title screen; drifts up to the top left as the dossier opens.
	var big := Vector2(W / 2.0, 150)
	var small := Vector2(32, 70)
	var at := big.lerp(small, e)
	var sc := lerpf(1.35, 1.0, e)
	var size := 52
	var text := "LAAF"
	var tw := _logo.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x - 16.0  # the last letter's tracking
	var off := lerpf(-tw / 2.0, 0.0, e)  # centred → left aligned
	_deco.draw_set_transform(at, 0.0, Vector2(sc, sc))
	_shadowed(_logo, Vector2(off, 0), text, size, Color(BONE, 0.95))
	var sw := _wide.get_string_size("HOLLOWMERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x - 4.0
	_deco.draw_rect(Rect2(lerpf(-tw * 0.4, 0.0, e), 9, tw * 0.8, 1.2), Color(RUST_HI, 0.95))  # centred under it, then flush left
	_shadowed(_wide, Vector2(lerpf(-sw / 2.0, 0.0, e), 23), "HOLLOWMERE", 7, Color(MUTED, 0.95))
	_deco.draw_set_transform(Vector2.ZERO)


func _draw_folder(W: float, H: float, e: float) -> void:
	var slide := (1.0 - e) * 260.0
	var f := Rect2(W - 36.0 - FOLDER_W + slide, 34, FOLDER_W, H - 68)
	# tabs (behind the folder; the open one is drawn over it, joined to the page)
	var ty := f.position.y + 18.0
	for i in TABS.size():
		var r := Rect2(f.position.x - 36.0, ty + i * 32.0, 40.0, 28.0)
		if i == _tab:
			continue
		var hot := _hover == "tab" and _hit_index("tab") == i
		_tab_shape(r, Color(0.06, 0.052, 0.045, 0.94 * e) if not hot else Color(0.1, 0.088, 0.076, 0.96 * e))
		_tab_face(r, i, false, e)
		_hits.append([r, "tab", i])
	# soft offset shadow: three widening layers
	for k in 3:
		Icons.fill_round(_deco, f.grow(2.0 + k * 3.0).grow_side(SIDE_TOP, -2.0 - k * 3.0), 12.0 + k * 3.0,
			Color(0, 0, 0, 0.16 * e))
	var pts := Icons.round_rect(f, 11.0, false)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(Color(FOLDER_HI.lerp(FOLDER, (p.y - f.position.y) / f.size.y), 0.97 * e))
	_deco.draw_polygon(pts, cols)
	var open := Rect2(f.position.x - 40.0, ty + _tab * 32.0, 41.0, 28.0)
	_tab_shape(open, Color(FOLDER_HI.lerp(FOLDER, (open.position.y + 14.0 - f.position.y) / f.size.y), 0.97 * e), false)
	_tab_face(open, _tab, true, e)
	_hits.append([open, "tab", _tab])
	# the page turn: the old leaf slides out to the left as the new one slides in from the right
	var k := ease(_page_t, 0.3)
	var inner := Rect2(f.position.x + PAD, f.position.y + PAD, FOLDER_W - PAD * 2.0, f.size.y - PAD * 2.0)
	if k < 1.0 and _prev_tab != _tab:
		var n := _hits.size()
		_a = e * (1.0 - k)
		_draw_page(_prev_tab, Rect2(inner.position - Vector2(k * 14.0, 0), inner.size))
		_hits.resize(n)  # what's leaving can't be clicked
	_a = e * k
	_draw_page(_tab, Rect2(inner.position + Vector2((1.0 - k) * 14.0, 0), inner.size))
	_a = 1.0


func _draw_page(tab: int, inner: Rect2) -> void:
	var keep := _tab
	_tab = tab  # (the pages read _tab for their focus state)
	match TABS[tab][0]:
		"continue": _page_continue(inner)
		"new": _page_new(inner)
		"load": _page_load(inner)
		"extra": _page_extra(inner)
		"options": _page_options(inner)
		"dev": _page_dev(inner)
		"quit": _page_quit(inner)
	_tab = keep


func _tab_shape(r: Rect2, col: Color, stroke := true) -> void:
	## An index tab: rounded on the outside (left) edge, square where it meets the folder. The open one has no
	## stroke: it's the folder's own leaf.
	var pts := Icons.round_rect(Rect2(r.position, r.size + Vector2(10, 0)), 7.0, false)
	var edge := PackedVector2Array([r.end])
	for i in pts.size():
		pts[i].x = minf(pts[i].x, r.end.x)
		if i >= 10:  # the bottom-left and top-left corners, in order
			edge.append(pts[i])
	edge.append(Vector2(r.end.x, r.position.y))
	_deco.draw_colored_polygon(pts, col)
	if stroke:
		_deco.draw_polyline(edge, Color(BONE, 0.08 * col.a), 1.0, true)


func _tab_face(r: Rect2, i: int, open: bool, e: float) -> void:
	var c := r.get_center() + Vector2(0 if open else -2, -3.5)
	var ink := AMBER if open else MUTED
	Icons.draw(_deco, TABS[i][0], c, 12.0, Color(ink, (1.0 if open else 0.75) * e), 1.3)
	_str(_bold, Vector2(r.position.x, r.end.y - 3.5), TABS[i][1], 7, Color(BONE if open else MUTED, e),
		r.size.x - (0 if open else 4), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_help(W: float, H: float, e: float) -> void:
	## The keys that work right now, in the bottom letterbox, right-aligned under the folder.
	var keys: Array = [["ESC", "Back" if _focus == "page" else "Title"], ["ENTER", "Select"]]
	if _focus == "page" and TABS[_tab][0] == "options":
		keys.append(["A D", "Adjust"])
	keys.append(["W A S D" if _focus == "page" and TABS[_tab][0] == "extra" else "W S", "Move" if _focus == "page" else "Tabs"])
	var x := W - 36.0
	var y := H - 9.0
	for k in keys:
		var tw := _ui.get_string_size(k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		_str(_ui, Vector2(x - tw, y + 2.5), k[1], 7, Color(MUTED, e))
		x -= tw + 4.0
		x -= _key(x, y, k[0], Color(BONE, 0.85 * e)) + 12.0


# ------------------------------------------------------------------ the pages

func _page_continue(r: Rect2) -> void:
	if _saves.is_empty():
		_heading(r.position.x, r.position.y + 16, "No case open")
		_wrap(_serif_it, Vector2(r.position.x, r.position.y + 36), "Nothing saved yet. Start a new case and Hollowmere will keep your place.", 10, _c(MUTED), r.size.x, 3)
		_photo(Rect2(r.position.x + 8, r.position.y + 76, r.size.x - 16, 104), null, -0.02, "Hollowmere")
		_bar(Rect2(r.position.x, r.end.y - BAR_H, r.size.x, BAR_H), "NEW CASE", "new", _focus == "tabs")
		return
	var s: Dictionary = _saves[0][1]
	var pos: Variant = s.get("pos", null)
	_photo(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 108), pos, -0.025, _place(pos))
	var ch := clampi(int(s.get("chapter", 1)), 1, 3)
	_str(_serif, Vector2(r.position.x, r.position.y + 132), "Chapter " + CHAPTERS[ch], 16, _c(BONE))
	var x := r.position.x
	var y := r.position.y + 140.0
	x += _chip(x, y, "clock", _g._clock(float(s.run.time))) + 4.0
	x += _chip(x, y, "flame", str(_g.DIFFICULTY[int(s.difficulty)].name)) + 4.0
	var mark := float(s.get("player", {}).get("mark", 0.0))
	_chip(x, y, "mark", "Mark %d%%" % roundi(mark), Color(RUST, 0.32))
	_weapons(Vector2(r.position.x, r.position.y + 161), s.get("weapons", {}))
	var nb := Rect2(r.position.x, r.position.y + 196, r.size.x, 30)
	Icons.fill_round(_deco, nb, 8.0, _c(AMBER, 0.08))
	_str(_caps, nb.position + Vector2(8, 12), "NEXT", 7, _c(AMBER))
	_wrap(_ui, nb.position + Vector2(34, 12.5), _objective(s), 8, _c(BONE), nb.size.x - 42.0, 2)
	_bar(Rect2(r.position.x, r.end.y - BAR_H, r.size.x, BAR_H), "RESUME", "play", _focus == "tabs")


func _weapons(at: Vector2, w: Dictionary) -> void:
	## What the save carries: each weapon's drawn icon, rounds loaded / in reserve for the ones that shoot.
	var owned: Array = w.get("owned", [])
	if owned.is_empty():
		_str(_ui, at + Vector2(0, 12), "Empty-handed.", 7, _c(MUTED))
		return
	var cur := int(w.get("current", 0))
	for i in mini(owned.size(), 6):
		var id: String = owned[i]
		var cell := Rect2(at + Vector2(i * 32.0, 0), Vector2(29, 22))
		Icons.fill_round(_deco, cell, 6.0, _c(BONE, 0.1 if i == cur else 0.04))
		Icons.draw(_deco, id, cell.position + Vector2(14.5, 11.0), 16.0, _c(BONE if i == cur else MUTED), 1.2)
		var spec: Dictionary = Weapons.GUNS.get(id, {})
		if spec.get("kind", "") != "melee":
			var n := "%d·%d" % [int(w.get("loaded", {}).get(id, 0)), int(w.get("reserve", {}).get(id, 0))]
			_str(_ui, Vector2(cell.position.x, cell.end.y + 7.0), n, 8, _c(MUTED), cell.size.x,
				HORIZONTAL_ALIGNMENT_CENTER)


func _page_new(r: Rect2) -> void:
	_heading(r.position.x, r.position.y + 16, "A new case")
	_wrap(_serif_it, Vector2(r.position.x, r.position.y + 34), "Dusk. The bridge is out. Your sister's postcard says don't come.", 10, _c(MUTED), r.size.x, 2)
	var pick: int = _sel if _focus == "page" else _g.difficulty
	var blurbs := ["Forgiving. For the story.", "As it was meant to be.", "Every round counts."]
	for i in 3:
		var row := Rect2(r.position.x, r.position.y + 54 + i * 34.0, r.size.x, 30)
		_row_box(row, i == pick)
		_hits.append([row, "row", i])
		for f in i + 1:
			Icons.draw(_deco, "flame", row.position + Vector2(11 + f * 7.0, 15), 10.0,
				_c(AMBER if i == pick else FAINT), 1.1)
		var tx := row.position.x + 38.0
		_str(_caps, Vector2(tx, row.position.y + 13), str(_g.DIFFICULTY[i].name).to_upper(), 8, _c(BONE))
		_str(_ui, Vector2(tx, row.position.y + 23.5), blurbs[i], 7, _c(MUTED))
	var d: Dictionary = _g.DIFFICULTY[pick]
	var meters := [["Damage you take", float(d.hurt)], ["Enemy toughness", float(d.enemy)], ["Ammo you find", float(d.ammo)]]
	for i in 3:
		var y := r.position.y + 165 + i * 15.0
		_str(_ui, Vector2(r.position.x, y), meters[i][0], 7, _c(MUTED))
		_str(_caps, Vector2(r.position.x, y), "×%.2f" % meters[i][1] if i == 1 else "×%.1f" % meters[i][1], 7, _c(BONE),
			r.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
		var track := Rect2(r.position.x + 78, y - 4.0, r.size.x - 108, 3.5)
		Icons.fill_round(_deco, track, 1.75, _c(BONE, 0.1))
		Icons.fill_round(_deco, Rect2(track.position, Vector2(track.size.x * meters[i][1] / 1.5, 3.5)), 1.75, _c(BONE, 0.7))
	_bar(Rect2(r.position.x, r.end.y - BAR_H, r.size.x, BAR_H), "BEGIN", "play", _focus == "page")


func _page_load(r: Rect2) -> void:
	_heading(r.position.x, r.position.y + 16, "Load game", "%d saved" % _saves.size() if not _saves.is_empty() else "")
	if _saves.is_empty():
		_wrap(_serif_it, Vector2(r.position.x, r.position.y + 36), "Nothing saved yet. Save from the pause menu; the game also saves on its own as you go.", 10, _c(MUTED), r.size.x, 3)
		return
	for i in range(_top, mini(_top + LOAD_ROWS, _saves.size())):
		var s: Dictionary = _saves[i][1]
		var row := Rect2(r.position.x, r.position.y + 26 + (i - _top) * 36.0, r.size.x, 32)
		var on := _focus == "page" and i == _sel
		_row_box(row, on)
		_hits.append([row, "row", i])
		var pos: Variant = s.get("pos", null)
		var ch := clampi(int(s.get("chapter", 1)), 1, 3)
		var thumb := Rect2(row.position + Vector2(4, 4), Vector2(36, 24))
		if pos != null:
			_mini_map(thumb, pos)
		else:  # older saves don't know where they were made: the chapter's numeral
			Icons.fill_round(_deco, thumb, 5.0, _c(BONE, 0.07))
			_str(_serif, Vector2(thumb.position.x, thumb.position.y + 17), CHAPTERS[ch].split(" ")[0], 14, _c(MUTED),
				thumb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var tx := row.position.x + 47.0
		_str(_bold, Vector2(tx, row.position.y + 13.5), _fit(_bold, "Ch.%s · %s" % [CHAPTERS[ch].split(" ")[0], _save_title(s)], 8, row.size.x - 52.0), 8, _c(BONE))
		var when := Time.get_datetime_string_from_unix_time(int(s.time), true).substr(5, 11)
		_str(_ui, Vector2(tx, row.position.y + 25.5), "%s · %s · %s · %s" % [s.get("kind", "Save"),
			_g.DIFFICULTY[int(s.difficulty)].name, _g._clock(float(s.run.time)), when], 7, _c(MUTED))
	if _top + LOAD_ROWS < _saves.size():
		_str(_ui, Vector2(r.position.x, r.end.y - 2), "%d more below" % (_saves.size() - _top - LOAD_ROWS), 7, _c(MUTED),
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _mini_map(r: Rect2, pos: Variant) -> void:
	var span := r.size * (2.0 if pos != null else 10.0)
	var c := Vector2.ZERO if pos == null else Vector2(pos[0], pos[1])
	var px := (c - Vector2(Guide.MAP_X0, Guide.MAP_Z0)) * Guide.PPM
	var region := Rect2(px - span / 2.0, span)
	region.position = region.position.clamp(Vector2.ZERO, Vector2(Guide.MAP_PX, Guide.MAP_PX) - span)
	_deco.draw_texture_rect_region(Guide.MAP_TEX, r, region, _c(Color(0.7, 0.66, 0.58)))
	_deco.draw_rect(r, _c(BONE, 0.25), false, 1.0)
	if pos != null:
		_deco.draw_circle(r.position + (px - region.position) / span * r.size, 2.2, _c(RUST_HI), true, -1.0, true)


func _page_extra(r: Rect2) -> void:
	var ids: Array = _g.ACHIEVEMENTS.keys()
	var got := 0
	for id in ids:
		got += int(_g.unlocked(id))
	_heading(r.position.x, r.position.y + 16, "Extra", "%d of %d" % [got, ids.size()])
	var track := Rect2(r.position.x, r.position.y + 24, r.size.x, 3.5)
	Icons.fill_round(_deco, track, 1.75, _c(BONE, 0.1))
	if got > 0:
		Icons.fill_round(_deco, Rect2(track.position, Vector2(track.size.x * got / ids.size(), 3.5)), 1.75, _c(AMBER))
	var pick := _sel if _focus == "page" else -1
	for i in ids.size():
		var cell := Rect2(r.position.x + (i % 4) * (r.size.x / 4.0), r.position.y + 34 + (i / 4) * 38.0, r.size.x / 4.0, 36)
		var c := cell.get_center()
		var on: bool = _g.unlocked(ids[i])
		_deco.draw_circle(c, 14.0, _c(BONE, 0.1 if on else 0.035), true, -1.0, true)
		_deco.draw_arc(c, 14.0, 0, TAU, 40, _c(AMBER if on else FAINT, 0.9 if on else 0.4), 1.0, true)
		if i == pick:
			_deco.draw_arc(c, 17.0, 0, TAU, 40, _c(BONE, 0.9), 1.0, true)
		Icons.draw(_deco, ACH_ICONS.get(ids[i], "extra") if on else "lock", c, 13.0, _c(BONE if on else FAINT), 1.2)
		_hits.append([cell, "row", i])
	var show := pick if pick >= 0 else -1
	if show < 0:
		_wrap(_ui, Vector2(r.position.x, r.position.y + 202), "What you've done in Hollowmere, kept across every run.", 7, _c(MUTED), r.size.x, 2)
		return
	var a: Array = _g.ACHIEVEMENTS[ids[show]]
	var on2: bool = _g.unlocked(ids[show])
	_str(_bold, Vector2(r.position.x, r.position.y + 204), a[0] if on2 else "Locked", 9, _c(BONE if on2 else MUTED))
	_wrap(_ui, Vector2(r.position.x, r.position.y + 216), a[1], 7, _c(MUTED), r.size.x, 2)


func _page_options(r: Rect2) -> void:
	_heading(r.position.x, r.position.y + 16, "Options")
	var sel_id: String = _opt_ids[_sel] if _focus == "page" else ""
	var y := r.position.y + 30.0
	for li in range(_top, mini(_top + OPT_LINES, _opt_lines.size())):
		var line: Array = _opt_lines[li]
		if line[0] == "h":
			if li == _top + OPT_LINES - 1:
				break
			_str(_caps, Vector2(r.position.x, y + 11), line[1], 7, _c(MUTED))
		else:
			var id: String = line[1]
			var row := Rect2(r.position.x - 4, y, r.size.x + 8, LINE_H - 1)
			if id == sel_id:
				_row_box(row, true)
			_hits.append([row, "row", _opt_ids.find(id)])
			var spec := Settings.row(id)
			_str(_ui, Vector2(r.position.x + 2, y + 11), spec[2], 7, _c(BONE if id == sel_id else MUTED))
			_value(Rect2(r.end.x - 62, y, 60, LINE_H - 1), id, spec)
		y += LINE_H
	var help: String = Settings.row(sel_id)[6] if sel_id != "" else "Changes apply at once and are kept."
	_wrap(_ui, Vector2(r.position.x, r.end.y - 12), help, 7, _c(MUTED), r.size.x, 2)


func _value(r: Rect2, id: String, spec: Array) -> void:
	## A setting's value, drawn: a meter for a percentage, a switch for a toggle, the number for a multiplier.
	var mid := r.get_center().y
	match spec[3]:
		"percent":
			var v := Settings.number(id)
			var track := Rect2(r.position.x, mid - 1.5, 36, 3)
			Icons.fill_round(_deco, track, 1.5, _c(BONE, 0.12))
			if v > 0.0:
				Icons.fill_round(_deco, Rect2(track.position, Vector2(36 * v, 3)), 1.5, _c(AMBER))
			_str(_ui, Vector2(r.position.x, mid + 2.5), "%d%%" % roundi(v * 100.0), 7, _c(BONE), r.size.x,
				HORIZONTAL_ALIGNMENT_RIGHT)
		"times":
			_str(_ui, Vector2(r.position.x, mid + 2.5), "×%.1f" % Settings.number(id), 7, _c(BONE), r.size.x,
				HORIZONTAL_ALIGNMENT_RIGHT)
		"toggle":
			var on := Settings.flag(id)
			var sw := Rect2(r.end.x - 18, mid - 4.5, 18, 9)
			Icons.fill_round(_deco, sw, 4.5, _c(AMBER) if on else _c(BONE, 0.15))
			_deco.draw_circle(Vector2(sw.end.x - 4.5 if on else sw.position.x + 4.5, mid), 3.2,
				_c(FOLDER if on else BONE, 1.0 if on else 0.6), true, -1.0, true)
		_:
			_str(_ui, Vector2(r.position.x, mid + 2.5), Settings.text(id), 7, _c(BONE), r.size.x,
				HORIZONTAL_ALIGNMENT_RIGHT)


func _dev_items() -> Array:
	## [label, help, callback]
	var items := [["All 12 evidence: %s" % ("on" if _g.dev_evidence else "off"),
		"Start holding every piece of evidence: the transmitter and the Signal ending (try III · Static).",
		func() -> void: _g.dev_evidence = not _g.dev_evidence],
		["Start Mark: %s" % ("as the story has it" if _g.dev_mark < 0.0 else "%d%%" % int(_g.dev_mark)),
		"Start with the Mark at a set level (its notices, whispers, the heartbeat, the sightings).",
		func() -> void:
			var steps := [-1.0, 30.0, 60.0, 95.0]
			_g.dev_mark = steps[(steps.find(_g.dev_mark) + 1) % steps.size()]]]
	for ch in DEV_STEPS:
		for st in ch[2]:
			items.append(["%s · %s" % [ch[0], st.trim_prefix("c2_").trim_prefix("c3_").capitalize()], "Chapter %s — %s. Normal, nothing saved." % [ch[0], ch[1]],
				func() -> void:
					_g.difficulty = 1
					_g.start(st, "dev")])
	return items


func _page_dev(r: Rect2) -> void:
	_heading(r.position.x, r.position.y + 16, "Dev mode")
	var items := _dev_items()
	var y := r.position.y + 28.0
	for i in range(_top, mini(_top + OPT_LINES, items.size())):
		var row := Rect2(r.position.x - 4, y, r.size.x + 8, LINE_H - 1)
		var on := _focus == "page" and i == _sel
		if on:
			_row_box(row, true)
		_hits.append([row, "row", i])
		_str(_ui, Vector2(r.position.x + 2, y + 11), items[i][0], 7, _c(BONE if on else MUTED))
		y += LINE_H
	var help: String = items[_sel][1] if _focus == "page" else "Start any step of any chapter. Nothing is saved, nothing unlocks."
	_wrap(_ui, Vector2(r.position.x, r.end.y - 12), help, 7, _c(MUTED), r.size.x, 2)


func _page_quit(r: Rect2) -> void:
	_heading(r.position.x, r.position.y + 16, "Leave Hollowmere?")
	_wrap(_serif_it, Vector2(r.position.x, r.position.y + 36), "Check out of room six. Your saves stay where you left them.", 10, _c(MUTED), r.size.x, 3)
	if not _saves.is_empty():  # where you'd be leaving off
		var pos: Variant = _saves[0][1].get("pos", null)
		_photo(Rect2(r.position.x + 10, r.position.y + 70, r.size.x - 20, 104), pos, 0.03, _place(pos))
	_bar(Rect2(r.position.x, r.end.y - BAR_H, r.size.x, BAR_H), "QUIT TO DESKTOP", "quit", _focus == "tabs")


# ------------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	var vp := get_viewport()  # taken first: an option can change the scene, after which we're out of the tree
	if _title:
		if (e is InputEventKey or e is InputEventJoypadButton or e is InputEventMouseButton) and e.is_pressed() \
				and not e.is_echo():
			_title = false
			_focus = "tabs"
			_page_t = 0.0
			Snd.sfx("save", null, -8.0)
			vp.set_input_as_handled()
		return
	if e is InputEventMouseMotion or e is InputEventMouseButton:
		_mouse(e)
	elif e.is_action_pressed("ui_down") or e.is_action_pressed("move_back"):
		_nav(0, 1)
	elif e.is_action_pressed("ui_up") or e.is_action_pressed("move_forward"):
		_nav(0, -1)
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		_nav(1, 0)
	elif e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		_nav(-1, 0)
	elif e.is_action_pressed("ui_accept"):
		_accept()
	elif e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		_back()
	else:
		return
	if is_inside_tree():
		vp.set_input_as_handled()


func _hit(p: Vector2) -> Array:
	for i in range(_hits.size() - 1, -1, -1):  # last drawn on top
		if (_hits[i][0] as Rect2).has_point(p):
			return _hits[i]
	return []


func _hit_index(kind: String) -> int:
	var h := _hit(get_local_mouse_position())
	return h[2] if not h.is_empty() and h[1] == kind else -1


func _mouse(e: InputEventMouse) -> void:
	var h := _hit(e.position)
	_hover = h[1] if not h.is_empty() else ""
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if not b.pressed:
			return
		if b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if _focus == "page":
				_nav(0, 1 if b.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			return
		if h.is_empty():
			return
		match h[1]:
			"tab":
				if h[2] != _tab:
					_set_tab(h[2])
			"bar":
				if TABS[_tab][0] == "new":
					_sel = _g.difficulty if _focus != "page" else _sel
					_focus = "page"
				_accept()
			"row":
				_focus = "page"
				_sel = h[2]
				if TABS[_tab][0] == "options":
					Settings.step(_opt_ids[_sel], -1 if b.button_index == MOUSE_BUTTON_RIGHT else 1)
					Snd.sfx("move")
				elif TABS[_tab][0] in ["load", "dev"]:
					_accept()
				else:
					Snd.sfx("move")
	elif not h.is_empty() and h[1] == "row" and _focus == "page" and h[2] != _sel:
		_sel = h[2]
		Snd.sfx("move")


func _set_tab(i: int) -> void:
	_prev_tab = _tab
	_tab = i
	_focus = "tabs"
	_sel = 0
	_top = 0
	_page_t = 0.0
	Snd.sfx("move")


func _count() -> int:
	## How many things the open page's selection moves over.
	match TABS[_tab][0]:
		"new": return 3
		"load": return _saves.size()
		"extra": return _g.ACHIEVEMENTS.size()
		"options": return _opt_ids.size()
		"dev": return _dev_items().size()
	return 0


func _nav(dx: int, dy: int) -> void:
	var page: String = TABS[_tab][0]
	if _focus == "tabs":
		if dy != 0:
			_set_tab(wrapi(_tab + dy, 0, TABS.size()))
		elif dx > 0:
			_accept()
		return
	if page == "options" and dx != 0:
		Settings.step(_opt_ids[_sel], dx)
		Snd.sfx("move")
		return
	if page == "extra":
		var n := _count()
		_sel = clampi(_sel + dx + dy * 4, 0, n - 1)
		Snd.sfx("move")
		return
	if dx < 0:
		_back()
		return
	if dy == 0:
		return
	_sel = wrapi(_sel + dy, 0, _count())
	_scroll()
	if page == "new":
		_g.difficulty = _sel
	Snd.sfx("move")


func _scroll() -> void:
	## Keeps the selection in view (options: its group's heading too, when it's the group's first row).
	match TABS[_tab][0]:
		"load":
			_top = clampi(_top, _sel - LOAD_ROWS + 1, _sel)
		"dev":
			_top = clampi(_top, _sel - OPT_LINES + 1, _sel)
		"options":
			var line := _opt_lines.find(["r", _opt_ids[_sel]])
			var first := line - 1 if line > 0 and _opt_lines[line - 1][0] == "h" else line
			_top = clampi(_top, line - OPT_LINES + 1, first)


func _accept() -> void:
	var page: String = TABS[_tab][0]
	if _focus == "tabs":
		match page:
			"continue":
				Snd.sfx("click")
				if _saves.is_empty():
					_set_tab(1)
					_enter(_g.difficulty)
				else:
					_g.start("", "story", _saves[0][1])
			"quit":
				Snd.sfx("click")
				get_tree().quit()
			"load":
				if not _saves.is_empty():
					_enter(0)
			_:
				_enter(_g.difficulty if page == "new" else 0)
		return
	match page:
		"new":
			Snd.sfx("click")
			_g.difficulty = _sel
			_g.start("intro", "story")
		"load":
			Snd.sfx("click")
			_g.start("", "story", _saves[_sel][1])
		"options":
			Settings.step(_opt_ids[_sel], 1)
			Snd.sfx("move")
		"dev":
			Snd.sfx("click")
			(_dev_items()[_sel][2] as Callable).call()


func _enter(sel: int) -> void:
	_focus = "page"
	_sel = sel
	_top = 0
	_scroll()
	Snd.sfx("click")


func _back() -> void:
	if _focus == "page":
		_focus = "tabs"
		Snd.sfx("move")
	else:
		_title = true
