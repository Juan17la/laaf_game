extends Control
## Main menu (the game's first scene): the case file on Alex's sister, set down in the fog.
##  · behind it, the real town in heavy fog, playing staged scenes from the story one after another
##    (actors posed at the motel, the bridge, the church, the Harvester at the chapel), each fading in and
##    out of black with a caption, like the title FMVs
##  · a title screen first: the logo and a "press any key" keycap; any key opens the dossier
##  · the dossier: a dark folder on the right with rounded index tabs down its edge (drawn icons, scripts/icons.gd).
##    Continue (the last save: a map photo pinned where it was made, chapter, time, Mark, weapons, the objective),
##    New (difficulty with its numbers as meters), Load, Extra (achievements), Options (scripts/settings.gd),
##    Dev, Quit. W/S choose a tab, Enter / D opens it, Esc goes back. The mouse shares that one selection: it points,
##    clicks, right-clicks back and scrolls (_gui_input).
##  · every word drawn goes through tr() (English ids, Spanish in locale/es.po): the page redraws each frame, so a
##    language switch on the Options page shows at once
##  · grain, dither and CRT scanlines over everything. The menu draws in canvas_items scale so its type is crisp at
##    any window size; the 3D town stays low-res (its SubViewport is 640×360) and the game's own scale comes back
##    on the way out.

const SCENES := [  ## caption, line, camera from → to, looking at, cast [model, pos, yaw, gesture], light [pos, colour, energy]
	["Last Postcard", "\"Hollowmere is beautiful. Don't come.\"",
		Vector3(-98, 1.1, 150), Vector3(-100, 1.4, 146.5), Vector3(-105, 1.5, 136),
		[["char_alex", Vector3(-104.5, 0, 138.5), PI, "look_around"]], [Vector3(-103, 3.0, 141), Color(1.0, 0.7, 0.45), 1.6]],
	["Room 6", "A shape behind the glass. A hiss. The smell of burning.",
		Vector3(-88, 1.3, 58), Vector3(-90, 1.6, 54.5), Vector3(-95.5, 1.4, 50),
		[["char_owen", Vector3(-95.0, 0.1, 50.2), -PI / 2.0, "window_press"]], [Vector3(-94.5, 2.6, 49), Color(1.0, 0.8, 0.5), 1.4]],
	["For The Nine", "Who never came home.",
		Vector3(-19.4, 1.5, 0.5), Vector3(-19.2, 1.4, -1.6), Vector3(-19, 0.7, -5.5),
		[["char_marked_woman", Vector3(-19, 0, -4.6), PI, "slump"]], [Vector3(-18.6, 0.6, -5.4), Color(1.0, 0.55, 0.25), 1.2]],
	["Channel 7", "\"They marked you. Stay in the grass.\"",
		Vector3(12.5, 1.4, 130), Vector3(11.5, 1.6, 131.5), Vector3(8.6, 1.3, 134),
		[["char_elena", Vector3(8.6, 0, 134.0), PI * 0.75, "hand_to_face"]], [Vector3(9, 2.4, 134.5), Color(0.6, 0.8, 1.0), 1.0]],
	["St. Brendan", "The doors were never locked. Nobody leaves.",
		Vector3(-50, 1.5, -98), Vector3(-52, 1.6, -99), Vector3(-56.5, 1.5, -100),
		[["char_marcus", Vector3(-56.5, 0, -100), PI / 2.0, "arms_crossed"]], [Vector3(-57.5, 3.0, -100), Color(1.0, 0.6, 0.3), 1.6]],
	["The Harvest", "It never talks. Its footsteps are the only loud thing.",
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
## A save made before any objective is on screen reads as its step, the way String.capitalize() writes the step id:
## these are those names (English ids for tr(); locale/es.po has them in Spanish).
const STEP_TITLES := ["Intro", "Room", "Hunt", "Square", "Sawmill", "Boss", "Blackout", "Free", "C 2 Intro",
	"Channel 7", "Zones", "Traitor", "C 3 Bell", "Run", "Marcus", "Static", "Gate", "Harvest", "Harvester", "Shepherd",
	"Epilogue"]
const TABS := [["continue", "CONTINUE"], ["new", "NEW"], ["load", "LOAD"], ["extra", "EXTRA"],
	["options", "OPTIONS"], ["dev", "DEV"], ["quit", "QUIT"]]
const ACH_ICONS := {"ch1": "axe", "ch2": "mark", "ch3": "continue", "evidence": "load", "keys": "key",
	"untouched": "heart", "mercy": "check", "hard": "skull", "arsenal": "revolver", "old_tom": "extra",
	"candles": "flame", "cardsharp": "extra", "hands_on": "fists"}
const BONE := MenuDraw.BONE  ## (the palette and the pieces are scripts/menu_draw.gd's, shared with the pause menu)
const MUTED := MenuDraw.MUTED
const FAINT := MenuDraw.FAINT
const RUST := MenuDraw.RUST
const RUST_HI := MenuDraw.RUST_HI
const AMBER := MenuDraw.AMBER
const FOLDER := MenuDraw.FOLDER
const FOLDER_HI := MenuDraw.FOLDER_HI
const PRINT := MenuDraw.PRINT
const Guide := preload("res://player/guide.gd")
const FOLDER_W := MenuDraw.FOLDER_W
const PAD := MenuDraw.PAD
const BAR_H := MenuDraw.BAR_H
const LOAD_ROWS := 6
const OPT_LINES := 12
const LINE_H := MenuDraw.LINE_H

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
var _d: MenuDraw  ## draws into _deco
var _serif: Font
var _serif_it: Font
var _ui: Font
var _bold: Font
var _caps: FontVariation  ## bold, tracked: labels and keycaps
var _title := true  ## on the PRESS ANY KEY screen
var _fade := 0.0  ## 0 title → 1 dossier
var _tab := 0
var _focus := "tabs"  ## "tabs": W/S change tab · "page": W/S move inside it
var _sel := 0  ## the selection inside the page
var _top := 0  ## first visible line of a scrolled list
var _page_t := 1.0  ## 0 → 1 after a tab change (the leaf turn)
var _prev_tab := 0  ## the page turning away
var _saves: Array = []
var _hits: Array = []  ## (_d.hits) [Rect2, kind, index] laid out by the last draw: what the mouse can point at
var _opt := OptionsPage.new()  ## the Options page (the pause menu shows the same one)


func _ready() -> void:
	_g = G.game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MenuDraw.cursor(true)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_saves = _g.saves() if _g else []
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
	_d = MenuDraw.new(_deco)
	_hits = _d.hits
	_serif = _d.serif
	_serif_it = _d.serif_it
	_ui = _d.ui
	_bold = _d.bold
	_caps = _d.caps
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
	MenuDraw.cursor(false)


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

static func _place(pos: Variant) -> String:
	## The zone a save was made in (guide.gd's zone rects), "Hollowmere" outside them or without a position.
	if pos == null:
		return "Hollowmere"
	for z in Guide.ZONES:
		if pos[0] >= z[1] and pos[0] <= z[3] and pos[1] >= z[2] and pos[1] <= z[4]:
			return z[0]
	return "Hollowmere"


func _objective(s: Dictionary, translated := true) -> String:
	## The objective a save was made on, in the current language (`translated` false: its English id). Saves keep
	## the English ("objective"; older ones only have it inside "label", "Ch.N · objective"), so a save loads and
	## reads the same in any language.
	var text := str(s.get("objective", ""))
	if not s.has("objective"):
		var label := str(s.get("label", ""))
		text = label.split(" · ", true, 1)[1] if " · " in label else label
	if text == "" or text == str(s.get("step", "")):  # (no objective on screen: the step's name, STEP_TITLES)
		text = str(s.get("step", "")).capitalize()
	return tr(text) if translated else text


func _save_title(s: Dictionary) -> String:
	## A load row's name: the objective it was saved on; an autosave with none on screen, the place it was made.
	if _objective(s, false).to_lower() == str(s.get("step", "")).to_lower() and s.get("pos", null) != null:
		return tr(_place(s.pos))
	return _objective(s)


# ------------------------------------------------------------------ drawing

func _draw_deco() -> void:
	var W := _deco.size.x
	var H := _deco.size.y
	var e := ease(_fade, -2.2)
	_hits.clear()
	_d.a = 1.0
	_d.letterbox(W, H)
	_d.logo(W, H, e)
	# the scene's caption, bottom left, in and out with the shot
	var cap := clampf(_shot_t - 2.0, 0.0, 1.0) * clampf(SCENE_TIME - 2.0 - _shot_t, 0.0, 1.0)
	var s: Array = SCENES[_shot]
	_d.shadowed(_serif_it, Vector2(32, H - 36), tr(s[1]), 11, Color(0.82, 0.79, 0.72, cap * 0.9))
	_d.shadowed(_ui, Vector2(32, H - 25), "— " + tr(s[0]), 7, Color(0.85, 0.5, 0.44, cap * 0.95))
	if _fade < 1.0:
		var ta := 1.0 - e
		var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.6))
		var label := tr("PRESS ANY KEY")
		var tw := _caps.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(W / 2.0 - tw / 2.0 - 12.0, 248, tw + 24.0, 19)
		Icons.fill_round(_deco, r, 9.5, Color(0, 0, 0, 0.45 * ta))
		_deco.draw_polyline(Icons.round_rect(r, 9.5), Color(BONE, 0.35 * ta * pulse), 1.0, true)
		_d.text(_caps, Vector2(r.position.x + 12.0, r.position.y + 12.8), label, 8, Color(BONE, ta * pulse))
		_d.shadowed(_caps, Vector2(0, H - 6), tr("HOLLOWMERE  ·  POP. 1413"), 7, Color(MUTED, 0.8 * ta), W,
			HORIZONTAL_ALIGNMENT_CENTER)
	if _fade <= 0.0:
		return
	_draw_folder(W, H, e)
	_draw_help(W, H, e)


func _draw_folder(W: float, H: float, e: float) -> void:
	var slide := (1.0 - e) * 260.0
	var f := Rect2(W - 36.0 - FOLDER_W + slide, 34, FOLDER_W, H - 68)
	# tabs (behind the folder; the open one is drawn over it, joined to the page)
	var ty := f.position.y + 18.0
	for i in TABS.size():
		var r := Rect2(f.position.x - 36.0, ty + i * 32.0, 40.0, 28.0)
		if i == _tab:
			continue
		var hot := _d.hot("tab", i)
		_tab_shape(r, Color(0.06, 0.052, 0.045, 0.94 * e) if not hot else Color(0.1, 0.088, 0.076, 0.96 * e))
		_tab_face(r, i, false, e)
		_hits.append([r, "tab", i])
	_d.folder(f, e)
	var open := Rect2(f.position.x - 40.0, ty + _tab * 32.0, 41.0, 28.0)
	_tab_shape(open, Color(FOLDER_HI.lerp(FOLDER, (open.position.y + 14.0 - f.position.y) / f.size.y), 0.97 * e), false)
	_tab_face(open, _tab, true, e)
	_hits.append([open, "tab", _tab])
	# the page turn: the old leaf slides out to the left as the new one slides in from the right
	var k := ease(_page_t, 0.3)
	var inner := Rect2(f.position.x + PAD, f.position.y + PAD, FOLDER_W - PAD * 2.0, f.size.y - PAD * 2.0)
	if k < 1.0 and _prev_tab != _tab:
		var n := _hits.size()
		_d.a = e * (1.0 - k)
		_draw_page(_prev_tab, Rect2(inner.position - Vector2(k * 14.0, 0), inner.size))
		_hits.resize(n)  # what's leaving can't be clicked
	_d.a = e * k
	_draw_page(_tab, Rect2(inner.position + Vector2((1.0 - k) * 14.0, 0), inner.size))
	_d.a = 1.0


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
	_d.index_tab(r, col, stroke)  # (scripts/menu_draw.gd: the inventory's tabs are the same)


func _tab_face(r: Rect2, i: int, open: bool, e: float) -> void:
	_d.tab_face(r, TABS[i][0], tr(TABS[i][1]), open, e)


func _draw_help(W: float, H: float, e: float) -> void:
	## The keys that work right now, in the bottom letterbox, right-aligned under the folder (Esc and Enter click too).
	var keys: Array = [["ESC", tr("Back") if _focus == "page" else tr("Title"), "back"], ["ENTER", tr("Select"), "accept"]]
	if _focus == "page" and TABS[_tab][0] == "options":
		keys.append(["A D", tr("Adjust")])
	keys.append(["W A S D" if _focus == "page" and TABS[_tab][0] == "extra" else "W S", tr("Move") if _focus == "page" else tr("Tabs")])
	_d.help(keys, W - 36.0, H - 9.0, e)


# ------------------------------------------------------------------ the pages

func _page_continue(r: Rect2) -> void:
	if _saves.is_empty():
		_d.heading(r.position.x, r.position.y + 16, tr("No case open"))
		_d.wrap(_serif_it, Vector2(r.position.x, r.position.y + 36), tr("Nothing saved yet. Start a new case and Hollowmere will keep your place."), 10, _d.c(MUTED), r.size.x, 3)
		_d.photo(Rect2(r.position.x + 8, r.position.y + 76, r.size.x - 16, 104), null, -0.02, "Hollowmere")
		_d.bar(Rect2(r.position.x, r.end.y - BAR_H, r.size.x, BAR_H), tr("NEW CASE"), "new", _focus == "tabs")
		return
	var s: Dictionary = _saves[0][1]
	var pos: Variant = s.get("pos", null)
	_d.photo(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 108), pos, -0.025, tr(_place(pos)))
	var ch := clampi(int(s.get("chapter", 1)), 1, 3)
	_d.text(_serif, Vector2(r.position.x, r.position.y + 132), _d.fit(_serif, tr("Chapter %s") % tr(CHAPTERS[ch]), 16, r.size.x), 16, _d.c(BONE))
	var x := r.position.x
	var y := r.position.y + 140.0
	x += _d.chip(x, y, "clock", _g._clock(float(s.run.time))) + 4.0
	x += _d.chip(x, y, "flame", tr(str(_g.DIFFICULTY[int(s.difficulty)].name))) + 4.0
	var mark := float(s.get("player", {}).get("mark", 0.0))
	_d.chip(x, y, "mark", tr("Mark %d%%") % roundi(mark), Color(RUST, 0.32))
	_weapons(Vector2(r.position.x, r.position.y + 161), s.get("weapons", {}))
	var nb := Rect2(r.position.x, r.position.y + 196, r.size.x, 30)
	Icons.fill_round(_deco, nb, 8.0, _d.c(AMBER, 0.08))
	var next := tr("NEXT")
	var nx := maxf(34.0, _caps.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 14.0)
	_d.text(_caps, nb.position + Vector2(8, 12), next, 7, _d.c(AMBER))
	_d.wrap(_ui, nb.position + Vector2(nx, 12.5), _objective(s), 8, _d.c(BONE), nb.size.x - nx - 8.0, 2)
	_d.bar(Rect2(r.position.x, r.end.y - BAR_H, r.size.x, BAR_H), tr("RESUME"), "play", _focus == "tabs")


func _weapons(at: Vector2, w: Dictionary) -> void:
	## What the save carries: each weapon's drawn icon, rounds loaded / in reserve for the ones that shoot.
	var owned: Array = w.get("owned", [])
	if owned.is_empty():
		_d.text(_ui, at + Vector2(0, 12), tr("Empty-handed."), 7, _d.c(MUTED))
		return
	var cur := int(w.get("current", 0))
	for i in mini(owned.size(), 6):
		var id: String = owned[i]
		var cell := Rect2(at + Vector2(i * 32.0, 0), Vector2(29, 22))
		Icons.fill_round(_deco, cell, 6.0, _d.c(BONE, 0.1 if i == cur else 0.04))
		Icons.draw(_deco, id, cell.position + Vector2(14.5, 11.0), 16.0, _d.c(BONE if i == cur else MUTED), 1.2)
		var spec: Dictionary = Weapons.GUNS.get(id, {})
		if spec.get("kind", "") != "melee":
			var n := "%d·%d" % [int(w.get("loaded", {}).get(id, 0)), int(w.get("reserve", {}).get(id, 0))]
			_d.text(_ui, Vector2(cell.position.x, cell.end.y + 7.0), n, 8, _d.c(MUTED), cell.size.x,
				HORIZONTAL_ALIGNMENT_CENTER)


func _page_new(r: Rect2) -> void:
	_d.heading(r.position.x, r.position.y + 16, tr("A new case"))
	_d.wrap(_serif_it, Vector2(r.position.x, r.position.y + 34), tr("Dusk. The bridge is out. Your sister's postcard says don't come."), 10, _d.c(MUTED), r.size.x, 2)
	var pick: int = _sel if _focus == "page" else _g.difficulty
	var blurbs := ["Forgiving. For the story.", "As it was meant to be.", "Every round counts."]
	for i in 3:
		var row := Rect2(r.position.x, r.position.y + 54 + i * 34.0, r.size.x, 30)
		_d.row_box(row, i == pick)
		_hits.append([row, "row", i])
		for f in i + 1:
			Icons.draw(_deco, "flame", row.position + Vector2(11 + f * 7.0, 15), 10.0,
				_d.c(AMBER if i == pick else FAINT), 1.1)
		var tx := row.position.x + 38.0
		_d.text(_caps, Vector2(tx, row.position.y + 13), tr(str(_g.DIFFICULTY[i].name)).to_upper(), 8, _d.c(BONE))
		_d.text(_ui, Vector2(tx, row.position.y + 23.5), tr(blurbs[i]), 7, _d.c(MUTED))
	var d: Dictionary = _g.DIFFICULTY[pick]
	var meters := [["Damage you take", float(d.hurt)], ["Enemy toughness", float(d.enemy)], ["Ammo you find", float(d.ammo)]]
	for i in 3:
		var y := r.position.y + 165 + i * 15.0
		_d.text(_ui, Vector2(r.position.x, y), tr(meters[i][0]), 7, _d.c(MUTED))
		_d.text(_caps, Vector2(r.position.x, y), "×%.2f" % meters[i][1] if i == 1 else "×%.1f" % meters[i][1], 7, _d.c(BONE),
			r.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
		var lw := maxf(78.0, _ui.get_string_size(tr(meters[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 6.0)
		var track := Rect2(r.position.x + lw, y - 4.0, r.size.x - lw - 30.0, 3.5)
		Icons.fill_round(_deco, track, 1.75, _d.c(BONE, 0.1))
		Icons.fill_round(_deco, Rect2(track.position, Vector2(track.size.x * meters[i][1] / 1.5, 3.5)), 1.75, _d.c(BONE, 0.7))
	_d.bar(Rect2(r.position.x, r.end.y - BAR_H, r.size.x, BAR_H), tr("BEGIN"), "play", _focus == "page")


func _page_load(r: Rect2) -> void:
	_d.heading(r.position.x, r.position.y + 16, tr("Load game"), tr("%d saved") % _saves.size() if not _saves.is_empty() else "")
	if _saves.is_empty():
		_d.wrap(_serif_it, Vector2(r.position.x, r.position.y + 36), tr("Nothing saved yet. Save from the pause menu; the game also saves on its own as you go."), 10, _d.c(MUTED), r.size.x, 3)
		return
	for i in range(_top, mini(_top + LOAD_ROWS, _saves.size())):
		var s: Dictionary = _saves[i][1]
		var row := Rect2(r.position.x, r.position.y + 26 + (i - _top) * 36.0, r.size.x, 32)
		var on := _focus == "page" and i == _sel
		_d.row_box(row, on)
		_hits.append([row, "row", i])
		var pos: Variant = s.get("pos", null)
		var ch := clampi(int(s.get("chapter", 1)), 1, 3)
		var thumb := Rect2(row.position + Vector2(4, 4), Vector2(36, 24))
		if pos != null:
			_mini_map(thumb, pos)
		else:  # older saves don't know where they were made: the chapter's numeral
			Icons.fill_round(_deco, thumb, 5.0, _d.c(BONE, 0.07))
			_d.text(_serif, Vector2(thumb.position.x, thumb.position.y + 17), CHAPTERS[ch].split(" ")[0], 14, _d.c(MUTED),
				thumb.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var tx := row.position.x + 47.0
		_d.text(_bold, Vector2(tx, row.position.y + 13.5), _d.fit(_bold, tr("Ch.%s · %s") % [CHAPTERS[ch].split(" ")[0], _save_title(s)], 8, row.size.x - 52.0), 8, _d.c(BONE))
		var when := Time.get_datetime_string_from_unix_time(int(s.time), true).substr(5, 11)
		_d.text(_ui, Vector2(tx, row.position.y + 25.5), _d.fit(_ui, "%s · %s · %s · %s" % [tr(str(s.get("kind", "Save"))),
			tr(_g.DIFFICULTY[int(s.difficulty)].name), _g._clock(float(s.run.time)), when], 7, row.size.x - 52.0), 7, _d.c(MUTED))
	if _top + LOAD_ROWS < _saves.size():
		_d.text(_ui, Vector2(r.position.x, r.end.y - 2), tr("%d more below") % (_saves.size() - _top - LOAD_ROWS), 7, _d.c(MUTED),
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _mini_map(r: Rect2, pos: Variant) -> void:
	var span := r.size * (2.0 if pos != null else 10.0)
	var c := Vector2.ZERO if pos == null else Vector2(pos[0], pos[1])
	var px := (c - Vector2(Guide.MAP_X0, Guide.MAP_Z0)) * Guide.PPM
	var region := Rect2(px - span / 2.0, span)
	region.position = region.position.clamp(Vector2.ZERO, Vector2(Guide.MAP_PX, Guide.MAP_PX) - span)
	_deco.draw_texture_rect_region(Guide.MAP_TEX, r, region, _d.c(Color(0.7, 0.66, 0.58)))
	_deco.draw_rect(r, _d.c(BONE, 0.25), false, 1.0)
	if pos != null:
		_deco.draw_circle(r.position + (px - region.position) / span * r.size, 2.2, _d.c(RUST_HI), true, -1.0, true)


func _page_extra(r: Rect2) -> void:
	var ids: Array = _g.ACHIEVEMENTS.keys()
	var got := 0
	for id in ids:
		got += int(_g.unlocked(id))
	_d.heading(r.position.x, r.position.y + 16, tr("Extra"), tr("%d of %d") % [got, ids.size()])
	var track := Rect2(r.position.x, r.position.y + 24, r.size.x, 3.5)
	Icons.fill_round(_deco, track, 1.75, _d.c(BONE, 0.1))
	if got > 0:
		Icons.fill_round(_deco, Rect2(track.position, Vector2(track.size.x * got / ids.size(), 3.5)), 1.75, _d.c(AMBER))
	var pick := _sel if _focus == "page" else -1
	for i in ids.size():
		var cell := Rect2(r.position.x + (i % 4) * (r.size.x / 4.0), r.position.y + 34 + (i / 4) * 38.0, r.size.x / 4.0, 36)
		var c := cell.get_center()
		var on: bool = _g.unlocked(ids[i])
		_deco.draw_circle(c, 14.0, _d.c(BONE, 0.1 if on else 0.035), true, -1.0, true)
		_deco.draw_arc(c, 14.0, 0, TAU, 40, _d.c(AMBER if on else FAINT, 0.9 if on else 0.4), 1.0, true)
		if i == pick:
			_deco.draw_arc(c, 17.0, 0, TAU, 40, _d.c(BONE, 0.9), 1.0, true)
		Icons.draw(_deco, ACH_ICONS.get(ids[i], "extra") if on else "lock", c, 13.0, _d.c(BONE if on else FAINT), 1.2)
		_hits.append([cell, "row", i])
	var show := pick if pick >= 0 else -1
	if show < 0:
		_d.wrap(_ui, Vector2(r.position.x, r.position.y + 202), tr("What you've done in Hollowmere, kept across every run."), 7, _d.c(MUTED), r.size.x, 2)
		return
	var a: Array = _g.ACHIEVEMENTS[ids[show]]
	var on2: bool = _g.unlocked(ids[show])
	_d.text(_bold, Vector2(r.position.x, r.position.y + 204), tr(a[0]) if on2 else tr("Locked"), 9, _d.c(BONE if on2 else MUTED))
	_d.wrap(_ui, Vector2(r.position.x, r.position.y + 216), tr(a[1]), 7, _d.c(MUTED), r.size.x, 2)


func _page_options(r: Rect2) -> void:
	_opt.draw(_d, r, _focus == "page")


func _dev_items() -> Array:
	## [label, help, callback]
	var items := [[tr("All 12 evidence: %s") % (tr("on") if _g.dev_evidence else tr("off")),
		tr("Start holding every piece of evidence: the transmitter and the Signal ending (try III · Static)."),
		func() -> void: _g.dev_evidence = not _g.dev_evidence],
		[tr("Start Mark: %s") % (tr("as the story has it") if _g.dev_mark < 0.0 else "%d%%" % int(_g.dev_mark)),
		tr("Start with the Mark at a set level (its notices, whispers, the heartbeat, the sightings)."),
		func() -> void:
			var steps := [-1.0, 30.0, 60.0, 95.0]
			_g.dev_mark = steps[(steps.find(_g.dev_mark) + 1) % steps.size()]]]
	for ch in DEV_STEPS:
		for st in ch[2]:
			items.append(["%s · %s" % [ch[0], st.trim_prefix("c2_").trim_prefix("c3_").capitalize()], tr("Chapter %s — %s. Normal, nothing saved.") % [ch[0], tr(ch[1])],
				func() -> void:
					_g.difficulty = 1
					_g.start(st, "dev")])
	return items


func _page_dev(r: Rect2) -> void:
	_d.heading(r.position.x, r.position.y + 16, tr("Dev mode"))
	var items := _dev_items()
	var y := r.position.y + 28.0
	for i in range(_top, mini(_top + OPT_LINES, items.size())):
		var row := Rect2(r.position.x - 4, y, r.size.x + 8, LINE_H - 1)
		var on := _focus == "page" and i == _sel
		if on:
			_d.row_box(row, true)
		_hits.append([row, "row", i])
		_d.text(_ui, Vector2(r.position.x + 2, y + 11), items[i][0], 7, _d.c(BONE if on else MUTED))
		y += LINE_H
	var help: String = items[_sel][1] if _focus == "page" else tr("Start any step of any chapter. Nothing is saved, nothing unlocks.")
	_d.wrap(_ui, Vector2(r.position.x, r.end.y - 12), help, 7, _d.c(MUTED), r.size.x, 2)


func _page_quit(r: Rect2) -> void:
	_d.heading(r.position.x, r.position.y + 16, tr("Leave Hollowmere?"))
	_d.wrap(_serif_it, Vector2(r.position.x, r.position.y + 36), tr("Check out of room six. Your saves stay where you left them."), 10, _d.c(MUTED), r.size.x, 3)
	if not _saves.is_empty():  # where you'd be leaving off
		var pos: Variant = _saves[0][1].get("pos", null)
		_d.photo(Rect2(r.position.x + 10, r.position.y + 70, r.size.x - 20, 104), pos, 0.03, tr(_place(pos)))
	_d.bar(Rect2(r.position.x, r.end.y - BAR_H, r.size.x, BAR_H), tr("QUIT TO DESKTOP"), "quit", _focus == "tabs")


# ------------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	## Keys and pad (the mouse comes in through _gui_input).
	var vp := get_viewport()  # taken first: an option can change the scene, after which we're out of the tree
	if _title:
		if (e is InputEventKey or e is InputEventJoypadButton) and e.is_pressed() and not e.is_echo():
			_open_dossier()
			vp.set_input_as_handled()
		return
	if e.is_action_pressed("ui_down") or e.is_action_pressed("move_back"):
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


func _gui_input(e: InputEvent) -> void:
	## The mouse. It shares the keyboard's one selection: pointing at a row selects it (the same amber outline),
	## a left click acts like Enter on it, a right click goes back like Esc, the wheel scrolls a list or adjusts the
	## setting under it. It only takes the selection when it moves, so a still mouse never fights the keys.
	if not e is InputEventMouse:
		return
	accept_event()
	var h := _d.point(e.position) if _d else []
	var b := e as InputEventMouseButton
	if _title:
		if b and b.pressed and b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_open_dossier()
		return
	if e is InputEventMouseMotion:
		if _opt.dragging():
			_opt.motion(e.position)
		else:
			_point(h)
	elif b.button_index == MOUSE_BUTTON_LEFT and not b.pressed:
		_opt.release()
	elif b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_wheel(h, 1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
	elif b.pressed and b.button_index == MOUSE_BUTTON_RIGHT:
		_back()
	elif b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
		_click(h, e.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _d:  # the pointer left the window: nothing stays lit under it
		_d.point(Vector2(-1e6, -1e6))


func _open_dossier() -> void:
	_title = false
	_focus = "tabs"
	_page_t = 0.0
	Snd.sfx("save", null, -8.0)


func _point(h: Array) -> void:
	## The mouse moved onto h: a page's row becomes the selection. On New a card is only shown while pointed at
	## (the difficulty itself changes on a click), so crossing Hard on the way to BEGIN doesn't pick it.
	var page: String = TABS[_tab][0]
	var row: bool = not h.is_empty() and h[1] in ["row", "track", "value"]
	if page == "new":
		if _focus == "page":
			var pick: int = h[2] if row else _g.difficulty
			if pick != _sel:
				_sel = pick
				Snd.sfx("move")
		elif row:
			_focus = "page"
			_sel = h[2]
			Snd.sfx("move")
		return
	if not row:
		return
	var was := _focus
	_focus = "page"
	if page == "options":
		if not _opt.hover(h) and was != "page":
			Snd.sfx("move")
	elif h[2] != _sel or was != "page":
		_sel = h[2]
		Snd.sfx("move")


func _click(h: Array, at: Vector2) -> void:
	if h.is_empty():
		return
	var page: String = TABS[_tab][0]
	match h[1]:
		"tab":
			if h[2] != _tab:
				_set_tab(h[2])
		"bar":
			if page == "new":
				_sel = _g.difficulty if _focus != "page" else _sel
				_focus = "page"
			_accept()
		"hint":
			if h[2] == 0:
				_back()
			else:
				_accept()
		"row", "track", "value":
			_focus = "page"
			if page == "options":
				_opt.press(h, at)
				return
			_sel = h[2]
			match page:
				"new":
					_g.difficulty = _sel
					Snd.sfx("move")
				"load", "dev":
					_accept()
				_:
					Snd.sfx("move")


func _wheel(h: Array, dir: int) -> void:
	## dir 1: up. Load and Dev scroll (the selection kept in view), Options scrolls or adjusts, Extra moves a row.
	if not h.is_empty() and h[1] in ["tab", "hint"]:
		return
	var page: String = TABS[_tab][0]
	match page:
		"options":
			if not h.is_empty() and h[1] in ["track", "value"]:
				_focus = "page"
			_opt.wheel(h, dir)
		"load", "dev":
			var rows := LOAD_ROWS if page == "load" else OPT_LINES
			_top = clampi(_top - dir, 0, maxi(_count() - rows, 0))
			_sel = clampi(_sel, _top, _top + rows - 1)
		"extra":
			if _focus == "page":
				_nav(0, -dir)


func _set_tab(i: int) -> void:
	_prev_tab = _tab
	_tab = i
	_focus = "tabs"
	_sel = 0
	_top = 0
	_opt.enter()
	_page_t = 0.0
	Snd.sfx("move")


func _count() -> int:
	## How many things the open page's selection moves over.
	match TABS[_tab][0]:
		"new": return 3
		"load": return _saves.size()
		"extra": return _g.ACHIEVEMENTS.size()
		"options": return _opt.ids.size()
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
	if page == "options":
		_opt.nav(dx, dy)
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
	## Keeps the selection in view (the Options page keeps its own, OptionsPage.scroll).
	match TABS[_tab][0]:
		"load":
			_top = clampi(_top, _sel - LOAD_ROWS + 1, _sel)
		"dev":
			_top = clampi(_top, _sel - OPT_LINES + 1, _sel)


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
			_opt.accept()
		"dev":
			Snd.sfx("click")
			(_dev_items()[_sel][2] as Callable).call()


func _enter(sel: int) -> void:
	_focus = "page"
	_sel = sel
	_top = 0
	_scroll()
	if TABS[_tab][0] == "options":
		_opt.enter()
	Snd.sfx("click")


func _back() -> void:
	if _focus == "page":
		_focus = "tabs"
		Snd.sfx("move")
	else:
		_title = true
