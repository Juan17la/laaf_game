class_name InventoryMenu
extends Control
## The inventory (Game._open_inventory puts it on the pause layer: Tab, I or the pad's Back; M opens it on the Map
## tab). The pause menu's dossier, wider, over the frozen game: the same blurred backdrop, logo, grain and
## scanlines, drawn with scripts/menu_draw.gd, with index tabs on the folder's edge like the main menu's:
##  · Weapons: fists and every weapon carried (its icon, what it does, damage, rounds loaded · in reserve); Enter /
##    a click on EQUIP puts it in hand
##  · Items: bottles, smoke cans, Elena's tea (drunk from here with the hotkey's rules), the gas mask and its filter,
##    the headlamp, the tokens
##  · Key items: the gate key's parts (x / 3), the chapel key, the hunters' keepsakes, Elena's jacket and tea tins
##  · Evidence: the twelve pieces, the missing ones as ???, x / 12
##  · Map: the town on paper (player/guide.gd draw_paper_map), where Alex is, the objective and how far
## Everything is read from the live game (the player, its Weapons, the director's flags) at every draw, so it's right
## after a save is loaded or a checkpoint restores. Q / E or LB / RB change tabs, W S (A D on Evidence) move, Enter
## uses, Esc / B / Start / Tab / I / right click close. Icons: ui/icons/*.png (tools/shot.gd --icons), else drawn.
## Null-safe: with no game (a test) closing frees it; with no player or director the pages are empty.

const TABS := [  ## id, tab label, page heading, tab icon
	["weapons", "WEAPONS", "Weapons", "revolver"], ["items", "ITEMS", "Items", "bottle"],
	["keys", "KEYS", "Key items", "key"], ["evidence", "EVIDENCE", "Evidence", "load"], ["map", "MAP", "Map", "pin"],
]
const LOGO_END := 292.0  ## px from the left: the logo, then room for the index tabs; the folder starts after it
const INV_W := [300.0, 420.0]  ## the folder's width range (the pause menu's is MenuDraw.FOLDER_W): as wide as the
## screen allows beside the logo
const LIST_W := 0.45  ## the list's share of the page (the rest is the detail)
const ROW_H := 27.0
const CELL_COLS := 6
const ICON_DIR := "res://ui/icons/%s.png"
const WEAPON_TEXT := {  ## id -> what it is, in a line or two
	"": "Bare hands. Alternating jabs; every third punch that lands hooks harder.",
	"revolver": "Six rounds. Steady, and loud enough to bring them running.",
	"flare": "One flare at a time. It burns, and fire stuns.",
	"shotgun": "Two shells, seven pellets each. Close range.",
	"bow": "Owen's hunting bow. Silent; a full draw hits hardest.",
	"axe": "Heavy, slow chops that stagger.",
	"bat": "Quick swings that stagger.",
}
const AMMO_ICON := {"revolver": "ammo", "flare": "flares", "shotgun": "shells", "bow": "arrow"}
const EVIDENCE := [  ## #1..#12: icon, name, what it says (from the scene where it's found)
	["ledger", "Hunting ledger", "Names and dates from the sawmill. The last column says \"delivered\"."],
	["note", "Moth's oilcloth", "Tied under the last tripwire stake: \"His wires. He marks whoever gets through.\""],
	["file", "Attendance list", "The week of the festival. Six names crossed out in red: \"Recruited.\""],
	["note", "Nora's letter", "Never sent. \"He says if I serve, she might come back.\""],
	["file", "Delivery list", "Sedatives, signed J.P. Destination: the quarry."],
	["toe_tag", "Toe tag", "From an empty body bag: \"Tomás R. Transferred. Quarry.\""],
	["ledger", "Bell register", "Every blackout rung since the festival. The last line: \"One. Elena.\""],
	["map", "Elena's quarry map", "Every cell and cage. One circled in red: \"L.M. — chapel, beside the altar.\""],
	["recorder", "Elena's recording", "Hidden under the static on channel 7: \"He's lying to us.\""],
	["tin_box", "Sunken box", "Photos sealed in wax: every boat in the harbor chained on the festival night."],
	["photo", "Lucía's camera", "One frame left. Her last photo: a chapel, in a quarry."],
	["note", "The Shepherd's letter", "Silas took it off the Shepherd's man. He never read it twice."],
]

var game: Node  ## the Game autoload (resume)
var player: Node  ## player/player.gd
var director: Node  ## the running chapter director (its flags)
var tab := 0
var _sel := [0, 0, 0, 0, 0]  ## the selection on each tab
var _d: MenuDraw
var _deco: Control
var _pics: Control  ## over _deco, smoothly filtered: the item icons scaled down to the rows
var _queue: Array = []  ## [texture, rect, colour] the page asked for this draw, drawn by _pics
var _prev_tab := 0
var _page_t := 1.0
var _armed := []
var _born := 0
var _icons := {}  ## name -> Texture2D (or null: drawn instead)


static func tab_index(id: String) -> int:
	for i in TABS.size():
		if TABS[i][0] == id:
			return i
	return 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()  # the paused game, blurred and dimmed (as behind the pause menu)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.material = ShaderMaterial.new()
	(back.material as ShaderMaterial).shader = load("res://shaders/pause_blur.gdshader")
	add_child(back)
	_deco = Control.new()
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	_d = MenuDraw.new(_deco)
	_pics = Control.new()
	_pics.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pics.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pics.draw.connect(func() -> void:
		for q in _queue:
			_pics.draw_texture_rect(q[0], q[1], false, q[2]))
	add_child(_pics)
	var fresh := BackBufferCopy.new()
	fresh.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(fresh)
	var crt := ColorRect.new()
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.material = ShaderMaterial.new()
	(crt.material as ShaderMaterial).shader = load("res://shaders/menu_crt.gdshader")
	(crt.material as ShaderMaterial).set_shader_parameter("grain", 0.07)
	add_child(crt)
	_born = Engine.get_process_frames()
	_prev_tab = tab
	var w := _weapons()
	if w:  # Weapons opens on what's in hand (row 0 is the fists)
		_sel[0] = w.current + 1 if w.gun() != "" else 0


func _process(delta: float) -> void:
	_page_t = move_toward(_page_t, 1.0, delta / 0.18)
	_deco.queue_redraw()
	_pics.queue_redraw()


# ------------------------------------------------------------------ the game's state

func _weapons() -> Weapons:
	return player.get("weapons") as Weapons if player else null


func _flags() -> Dictionary:
	var f: Variant = director.get("flags") if director else null
	return f if f is Dictionary else {}


func key_parts() -> int:
	## Chapter 1 counts one part (key_part); Chapters 2-3 count them (key_parts).
	var f := _flags()
	return maxi(int(f.get("key_parts", 0)), 1 if f.get("key_part", false) else 0)


func evidence() -> Array:
	return (_flags().get("evidence", []) as Array).duplicate()


func entries(id: String) -> Array:
	## The rows of a list page, from the live state: {id, icon, name, sub, text, act (a verb or ""), ok, why}.
	match id:
		"weapons":
			return _weapon_rows()
		"items":
			return _item_rows()
		"keys":
			return _key_rows()
	return []


func _weapon_rows() -> Array:
	var w := _weapons()
	var out := []
	if not w:
		return out
	for id in [""] + w.owned:
		var sp: Dictionary = Weapons.GUNS[id] if id != "" else Weapons.FISTS
		var held: bool = w.gun() == id
		var row := {"id": id, "icon": id if id != "" else "fists", "name": tr(sp.name), "text": tr(WEAPON_TEXT.get(id, "")),
			"act": "" if held else "EQUIP", "ok": not held, "why": tr("In hand."), "melee": sp.kind == "melee"}
		var dmg: float = sp.damage
		row["damage"] = ("%d × %d" % [roundi(dmg), int(sp.pellets)]) if sp.has("pellets") else str(roundi(dmg))
		if sp.kind == "melee":
			row["sub"] = tr("Melee")
		else:
			row["sub"] = "%d · %d" % [int(w.loaded[id]), int(w.reserve[id])]
			row["loaded"] = int(w.loaded[id])
			row["reserve"] = int(w.reserve[id])
		out.append(row)
	return out


func _item_rows() -> Array:
	var out := []
	if not player:
		return out
	var bottles := int(player.get("bottles"))
	var smokes := int(player.get("smokes"))
	var teas := int(player.get("teas"))
	if bottles > 0:
		out.append({"id": "bottle", "icon": "bottle", "name": tr("Bottle"), "sub": "×%d" % bottles, "key": "G",
			"text": tr("Thrown onto the crosshair. Whatever hears it shatter goes to look."), "act": "", "ok": false, "why": ""})
	if smokes > 0:
		out.append({"id": "smoke", "icon": "smoke", "name": tr("Smoke can"), "sub": "×%d" % smokes, "key": "T",
			"text": tr("Thrown onto the crosshair: a cloud that hides everything in and behind it."), "act": "",
			"ok": false, "why": ""})
	if teas > 0:
		var clear: bool = float(player.get("mark")) <= 0.0
		out.append({"id": "tea", "icon": "tea", "name": tr("Elena's Tea"), "sub": "×%d" % teas, "key": "H",
			"text": tr("Lowers the Mark by 15%."), "act": "DRINK", "ok": not clear,
			"why": tr("The Mark is already clear.")})
	if bool(player.get("gas_mask")):
		var on := bool(player.get("mask_on"))
		var filt := roundi(float(player.get("mask_filter")) * 100.0)
		out.append({"id": "mask", "icon": "mask", "name": tr("Gas mask"), "sub": tr("Filter %d%%") % filt, "key": "X",
			"text": tr("Worn in the gas, the filter wears down instead of you."), "act": "TAKE OFF" if on else "PUT ON",
			"ok": true, "why": "", "filter": filt})
	var lamp: Node = player.get("flashlight")
	var lit := lamp != null and bool(lamp.get("visible"))
	out.append({"id": "headlamp", "icon": "headlamp", "name": tr("Headlamp"), "sub": tr("On") if lit else tr("Off"),
		"key": "F", "text": tr("Strapped to your head. It shines where you look."), "act": "TURN OFF" if lit else "TURN ON",
		"ok": lamp != null, "why": ""})
	out.append({"id": "tokens", "icon": "", "name": tr("Lantern Tokens"), "sub": str(int(_flags().get("tokens", 0))),
		"text": tr("The town's festival tokens. Silas plays for them."), "act": "", "ok": false, "why": ""})
	return out


func _key_rows() -> Array:
	var f := _flags()
	var out := []
	var parts := key_parts()
	if parts > 0:
		out.append({"id": "key_part", "icon": "key_part", "name": tr("Key parts"), "sub": "%d / 3" % parts,
			"text": tr("Pieces of the tunnel gate's key. It takes all three.")})
	if f.get("has_chapel_key", false):
		out.append({"id": "chapel_key", "icon": "chapel_key", "name": tr("Chapel key"), "sub": "",
			"text": tr("Iron, heavy, an eye cast into the bow. Marcus kept it.")})
	if f.get("lantern", false):
		out.append({"id": "lantern", "icon": "lantern", "name": tr("The Clarkes' lantern"), "sub": "",
			"text": tr("A festival lantern, burnt black. Two names scratched in the brass: Clarke.")})
	if f.get("drawing", false):
		out.append({"id": "drawing", "icon": "drawing", "name": tr("Lily's drawing"), "sub": "",
			"text": tr("Crayon on paper, from classroom 3. She'll want this back.")})
	if f.get("sam_file", false):
		out.append({"id": "sam_file", "icon": "file", "name": tr("Sam's file"), "sub": "",
			"text": tr("\"Samantha Kim. Released to the Shepherd. Alive.\"")})
	if f.get("clara_photo", false):
		out.append({"id": "clara_photo", "icon": "photo", "name": tr("Clara's photo"), "sub": "",
			"text": tr("A woman in a choir robe, laughing. On the back: \"Marcus — sing with me. C.\"")})
	if int(f.get("tea", 0)) > 0:
		out.append({"id": "tea_tins", "icon": "tea", "name": tr("Elena's tea tins"), "sub": "×%d" % int(f.tea),
			"text": tr("From the clinic pharmacy, her name on the lids. For Elena.")})
	if f.get("jacket", false):
		out.append({"id": "jacket", "icon": "", "name": tr("Elena's jacket"), "sub": "",
			"text": tr("Her yellow rain jacket. Worn, the Mark takes hold slower.")})
	for r in out:
		r["act"] = ""
		r["ok"] = false
		r["why"] = ""
	return out


# ------------------------------------------------------------------ drawing

func _icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := ICON_DIR % name
		_icons[name] = load(path) if name != "" and ResourceLoader.exists(path) else null
	return _icons[name]


func _picture(name: String, drawn: String, at: Vector2, size: float, dim := false) -> void:
	## An item's rendered icon (ui/icons) centred on at, else its drawn one (scripts/icons.gd).
	var tex := _icon(name)
	if tex:
		_queue.append([tex, Rect2(at - Vector2.ONE * size / 2.0, Vector2.ONE * size), _d.c(Color(1, 1, 1, 0.45 if dim else 1.0))])
	else:
		Icons.draw(_deco, drawn, at, size * 0.6, _d.c(MenuDraw.FAINT if dim else MenuDraw.BONE), 1.3)


func _draw_deco() -> void:
	var W := _deco.size.x
	var H := _deco.size.y
	_d.hits.clear()
	_queue.clear()
	_d.a = 1.0
	_d.letterbox(W, H)
	_d.logo(W, H, 1.0)
	var fw := clampf(W - 36.0 - LOGO_END, INV_W[0], INV_W[1])
	var f := Rect2(W - 36.0 - fw, 34, fw, H - 68)
	var ty := f.position.y + 18.0
	for i in TABS.size():  # the closed tabs behind the folder
		if i == tab:
			continue
		var r := Rect2(f.position.x - 40.0, ty + i * 32.0, 44.0, 28.0)
		_d.index_tab(r, Color(0.06, 0.052, 0.045, 0.94) if not _d.hot("tab", i) else Color(0.1, 0.088, 0.076, 0.96))
		_d.tab_face(r, TABS[i][3], tr(TABS[i][1]), false, 1.0)
		_d.hits.append([r, "tab", i])
	_d.folder(f, 1.0)
	_d.shadowed(_d.caps, Vector2(f.position.x, f.position.y - 6.0), tr("INVENTORY"), 7, _d.c(MenuDraw.MUTED), f.size.x,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var open := Rect2(f.position.x - 44.0, ty + tab * 32.0, 45.0, 28.0)
	_d.index_tab(open, Color(MenuDraw.FOLDER_HI.lerp(MenuDraw.FOLDER, (open.position.y + 14.0 - f.position.y) / f.size.y),
		0.97), false)
	_d.tab_face(open, TABS[tab][3], tr(TABS[tab][1]), true, 1.0)
	_d.hits.append([open, "tab", tab])
	var inner := f.grow(-MenuDraw.PAD)
	var k := ease(_page_t, 0.3)
	if k < 1.0 and _prev_tab != tab:  # the leaf turn
		var n := _d.hits.size()
		_d.a = 1.0 - k
		_draw_page(_prev_tab, Rect2(inner.position - Vector2(k * 14.0, 0), inner.size))
		_d.hits.resize(n)
	_d.a = k
	_draw_page(tab, Rect2(inner.position + Vector2((1.0 - k) * 14.0, 0), inner.size))
	_d.a = 1.0
	var keys: Array = [["ESC", tr("Close"), "back"]]
	var row := _current()
	if not row.is_empty() and row.get("act", "") != "" and row.get("ok", false):
		var verb := tr(row.act)
		keys.append(["ENTER", verb.left(1) + verb.substr(1).to_lower(), "accept"])
	keys.append(["Q E", tr("Tabs")])
	if TABS[tab][0] != "map":
		keys.append(["W A S D" if TABS[tab][0] == "evidence" else "W S", tr("Move")])
	_d.help(keys, W - 36.0, H - 9.0, 1.0)


func _draw_page(t: int, r: Rect2) -> void:
	var id: String = TABS[t][0]
	match id:
		"evidence":
			_page_evidence(r, t)
		"map":
			_page_map(r)
		_:
			_page_list(r, t, id)


func _heading(r: Rect2, title: String, right := "") -> void:
	_d.text(_d.serif, Vector2(r.position.x, r.position.y + 16), title, 17, _d.c(MenuDraw.BONE))
	if right != "":
		_d.text(_d.ui, Vector2(r.position.x, r.position.y + 15), right, 7, _d.c(MenuDraw.MUTED), r.size.x,
			HORIZONTAL_ALIGNMENT_RIGHT)


func _page_list(r: Rect2, t: int, id: String) -> void:
	var rows := entries(id)
	var right := ""
	if id == "weapons" and _weapons():
		right = tr("%d carried") % _weapons().owned.size()
	elif id == "keys":
		right = tr("Gate key %d / 3") % key_parts()
	_heading(r, tr(TABS[t][2]), right)
	if rows.is_empty():
		_d.wrap(_d.serif_it, Vector2(r.position.x, r.position.y + 40), tr("Nothing yet."), 10, _d.c(MenuDraw.MUTED),
			r.size.x, 2)
		return
	var sel := clampi(_sel[t], 0, rows.size() - 1)
	var y0 := r.position.y + 26.0
	var lw := roundf(r.size.x * LIST_W)
	var w := _weapons()
	for i in rows.size():
		var e: Dictionary = rows[i]
		var row := Rect2(r.position.x, y0 + i * (ROW_H + 3.0), lw, ROW_H)
		if row.end.y > r.end.y:
			break
		var on := i == sel
		_d.row_box(row, on)
		_d.hits.append([row, "row", i])
		var drawn: String = {"tokens": "token", "jacket": "jacket"}.get(e.id, e.icon)
		_picture(e.icon, drawn, row.position + Vector2(15, ROW_H / 2.0), 24.0)
		var tx := row.position.x + 31.0
		var name := str(e.name).to_upper()
		var room := row.end.x - tx - (22.0 if e.has("key") else 14.0)
		var font: Font = _d.caps  # tracked caps as on every menu row; a long name (Spanish) steps down, then untracked
		var fs := 8
		for f in [[_d.caps, 8], [_d.caps, 7], [_d.bold, 8], [_d.bold, 7]]:
			font = f[0]
			fs = f[1]
			if font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room:
				break
		_d.text(font, Vector2(tx, row.position.y + 12), _d.fit(font, name, fs, room), fs, _d.c(MenuDraw.BONE))
		_d.text(_d.ui, Vector2(tx, row.position.y + 22), _d.fit(_d.ui, str(e.get("sub", "")), 7, room), 7,
			_d.c(MenuDraw.MUTED))
		if id == "weapons" and w and w.gun() == e.id:  # in hand: an amber hand-mark at the row's end
			_deco.draw_circle(Vector2(row.end.x - 9.0, row.get_center().y), 2.6, _d.c(MenuDraw.AMBER), true, -1.0, true)
		elif e.has("key"):
			_d.key(row.end.x - 5.0, row.get_center().y, e.key, _d.c(MenuDraw.MUTED, 0.9))
	_detail(Rect2(r.position.x + lw + 8.0, y0, r.size.x - lw - 8.0, r.end.y - y0), rows[sel], id)


func _detail(r: Rect2, e: Dictionary, id: String) -> void:
	Icons.fill_round(_deco, r, 8.0, _d.c(MenuDraw.BONE, 0.04))
	var drawn: String = {"tokens": "token", "jacket": "jacket"}.get(e.id, e.icon)
	_picture(e.icon, drawn, Vector2(r.get_center().x, r.position.y + 34.0), 56.0)
	var x := r.position.x + 9.0
	var cw := r.size.x - 18.0
	var y := r.position.y + 76.0
	_d.text(_d.serif, Vector2(x, y), _d.fit(_d.serif, str(e.name), 13, cw), 13, _d.c(MenuDraw.BONE))
	y += 6.0
	if id == "weapons":
		var cx := x
		cx += _d.chip(cx, y, "skull", tr("Damage %s") % e.damage) + 4.0
		if not e.melee:
			_d.chip(cx, y, "bullet", "%d · %d" % [e.loaded, e.reserve])
		y += 18.0
	elif str(e.get("sub", "")) != "":
		_d.chip(x, y, "check", str(e.sub))
		y += 18.0
	_d.wrap(_d.ui, Vector2(x, y + 9.0), str(e.text), 8, _d.c(MenuDraw.MUTED), cw, 4)
	if id == "weapons" and not e.melee:
		var line := tr("Rounds loaded · in reserve")
		_d.text(_d.ui, Vector2(x, r.end.y - MenuDraw.BAR_H - 8.0), _d.fit(_d.ui, line, 7, cw - 20.0), 7, _d.c(MenuDraw.FAINT))
		_picture(AMMO_ICON.get(e.id, "ammo"), "bullet", Vector2(r.end.x - 15.0, r.end.y - MenuDraw.BAR_H - 12.0), 22.0)
	var bar := Rect2(r.position.x + 6.0, r.end.y - MenuDraw.BAR_H - 4.0, r.size.x - 12.0, MenuDraw.BAR_H)
	if str(e.get("act", "")) != "" and e.get("ok", false):
		_d.bar(bar, tr(e.act), "check" if id == "weapons" else "play", true)
	elif str(e.get("why", "")) != "":
		Icons.fill_round(_deco, bar, 8.0, _d.c(MenuDraw.BONE, 0.03))
		_d.text(_d.ui, bar.position + Vector2(10, 16), _d.fit(_d.ui, str(e.why), 8, bar.size.x - 20.0), 8, _d.c(MenuDraw.FAINT))


func _page_evidence(r: Rect2, t: int) -> void:
	var got := evidence()
	_heading(r, tr("Evidence"), tr("%d of %d") % [got.size(), 12])
	var track := Rect2(r.position.x, r.position.y + 24, r.size.x, 3.5)
	Icons.fill_round(_deco, track, 1.75, _d.c(MenuDraw.BONE, 0.1))
	if got.size() > 0:
		Icons.fill_round(_deco, Rect2(track.position, Vector2(track.size.x * minf(got.size() / 12.0, 1.0), 3.5)), 1.75,
			_d.c(MenuDraw.AMBER))
	var sel := clampi(_sel[t], 0, 11)
	var cw := r.size.x / CELL_COLS
	for i in 12:
		var cell := Rect2(r.position.x + (i % CELL_COLS) * cw + 2.0, r.position.y + 34.0 + (i / CELL_COLS) * 52.0, cw - 4.0, 48.0)
		var found: bool = (i + 1) in got
		_d.row_box(cell, i == sel)
		_d.hits.append([cell, "cell", i])
		_d.text(_d.caps, cell.position + Vector2(5, 10), "#%d" % (i + 1), 6, _d.c(MenuDraw.AMBER if found else MenuDraw.FAINT))
		if found:
			_picture(EVIDENCE[i][0], "load", cell.get_center() + Vector2(0, 4), 34.0)
		else:
			_d.text(_d.serif, Vector2(cell.position.x, cell.get_center().y + 8.0), "???", 13, _d.c(MenuDraw.FAINT), cell.size.x,
				HORIZONTAL_ALIGNMENT_CENTER)
	var y := r.position.y + 150.0
	var found_sel: bool = (sel + 1) in got
	_d.text(_d.caps, Vector2(r.position.x, y), tr("EVIDENCE #%d") % (sel + 1), 7, _d.c(MenuDraw.AMBER))
	_d.text(_d.serif, Vector2(r.position.x, y + 17), tr(EVIDENCE[sel][1]) if found_sel else "???", 13, _d.c(MenuDraw.BONE))
	_d.wrap(_d.ui, Vector2(r.position.x, y + 31), tr(EVIDENCE[sel][2]) if found_sel else tr("Not found yet."), 8,
		_d.c(MenuDraw.MUTED), r.size.x, 3)
	_d.wrap(_d.serif_it, Vector2(r.position.x, r.end.y - 14.0), tr("Elena's broadcast needs all twelve."), 9,
		_d.c(MenuDraw.FAINT), r.size.x, 1)


func _page_map(r: Rect2) -> void:
	## Heading and where Alex is; the objective and how far on one line; the town under them.
	var guide: Node = player.get_node_or_null("Guide") if player else null
	var here: String = guide.here() if guide else ""
	_heading(r, tr("Map"), tr("Near: %s") % tr(here) if here != "" else tr("Outside town"))
	var objective := str(director.get("_objective_text")) if director and director.get("_objective_text") != null else ""
	var goal: Variant = guide.goal() if guide else null
	var y := r.position.y + 32.0
	var next := tr("NEXT")
	var nx := _d.caps.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8.0
	_d.text(_d.caps, Vector2(r.position.x, y), next, 7, _d.c(MenuDraw.AMBER))
	var far := tr("%s away") % guide.distance(goal) if goal != null else ""
	var fw := _d.ui.get_string_size(far, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_d.text(_d.ui, Vector2(r.position.x + nx, y), _d.fit(_d.ui, tr(objective) if objective != "" else "—", 8,
		r.size.x - nx - fw - 10.0), 8, _d.c(MenuDraw.BONE))
	_d.text(_d.ui, Vector2(r.position.x, y), far, 8, _d.c(MenuDraw.MUTED), r.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	var side := minf(r.end.y - y - 12.0, r.size.x)
	var m := Rect2(Vector2(r.get_center().x - side / 2.0, y + 9.0), Vector2(side, side))
	if guide and guide.has_method("draw_paper_map"):
		guide.draw_paper_map(_deco, m, Color(1, 1, 1, _d.a))


# ------------------------------------------------------------------ input

func _current() -> Dictionary:
	var id: String = TABS[tab][0]
	var rows := entries(id)
	if rows.is_empty():
		return {}
	return rows[clampi(_sel[tab], 0, rows.size() - 1)]


func _count() -> int:
	match TABS[tab][0]:
		"evidence":
			return 12
		"map":
			return 0
	return entries(TABS[tab][0]).size()


func _unhandled_input(e: InputEvent) -> void:
	if Engine.get_process_frames() == _born:
		return
	var k := e as InputEventKey
	var j := e as InputEventJoypadButton
	if e.is_action_pressed("inventory") or e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause") \
			or (e.is_action_pressed("map") and TABS[tab][0] == "map"):
		close()
	elif e.is_action_pressed("map"):
		set_tab(tab_index("map"))
	elif (k and k.pressed and not k.echo and k.physical_keycode == KEY_Q) or (j and j.pressed and j.button_index == JOY_BUTTON_LEFT_SHOULDER):
		set_tab(wrapi(tab - 1, 0, TABS.size()))
	elif (k and k.pressed and not k.echo and k.physical_keycode == KEY_E) or (j and j.pressed and j.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		set_tab(wrapi(tab + 1, 0, TABS.size()))
	elif e.is_action_pressed("ui_down") or e.is_action_pressed("move_back"):
		_nav(0, 1)
	elif e.is_action_pressed("ui_up") or e.is_action_pressed("move_forward"):
		_nav(0, -1)
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		_nav(1, 0)
	elif e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		_nav(-1, 0)
	elif e.is_action_pressed("ui_accept"):
		use()
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _gui_input(e: InputEvent) -> void:
	## The mouse, as in the pause menu: pointing selects, a left click picks (on the release), a right click closes,
	## the wheel moves the selection.
	if not e is InputEventMouse:
		return
	accept_event()
	var h := _d.point(e.position)
	if e is InputEventMouseMotion:
		if not h.is_empty() and h[1] in ["row", "cell"] and h[2] != _sel[tab]:
			_sel[tab] = h[2]
			Snd.sfx("move")
		return
	var b := e as InputEventMouseButton
	if b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if b.pressed:
			_nav(0, -1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		return
	if b.pressed:
		_armed = ["right", 0] if b.button_index == MOUSE_BUTTON_RIGHT else ([h[1], h[2]] if not h.is_empty() and b.button_index == MOUSE_BUTTON_LEFT else [])
		return
	var armed := _armed
	_armed = []
	if armed.is_empty():
		return
	if armed[0] == "right":
		if b.button_index == MOUSE_BUTTON_RIGHT:
			close()
	elif b.button_index == MOUSE_BUTTON_LEFT and not h.is_empty() and h[1] == armed[0] and h[2] == armed[1]:
		match h[1]:
			"tab":
				set_tab(h[2])
			"row", "cell":
				_sel[tab] = h[2]
			"bar":
				use()
			"hint":
				if h[2] == 0:
					close()
				else:
					use()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _d:
		_d.point(Vector2(-1e6, -1e6))


func set_tab(i: int) -> void:
	if i == tab:
		return
	_prev_tab = tab
	tab = i
	_page_t = 0.0
	Snd.sfx("click")


func _nav(dx: int, dy: int) -> void:
	var n := _count()
	if TABS[tab][0] == "evidence":
		var s: int = _sel[tab]
		if dx != 0:
			_sel[tab] = wrapi(s + dx, 0, 12)
		else:
			_sel[tab] = wrapi(s + dy * CELL_COLS, 0, 12)
	elif dx != 0 or n == 0:  # (lists and the map: left / right turn the tabs too)
		if dx != 0:
			set_tab(wrapi(tab + dx, 0, TABS.size()))
		return
	else:
		_sel[tab] = wrapi(clampi(_sel[tab], 0, n - 1) + dy, 0, n)
	Snd.sfx("move")


func select(t: String, i: int) -> void:
	## Tests and the mouse: the row / cell i on tab t, made current.
	tab = tab_index(t)
	_sel[tab] = i


func use() -> bool:
	## What Enter does on the selected row: equip a weapon, drink a tea, the mask on / off, the lamp on / off. The
	## same calls the hotkeys make, so the same rules. False when there's nothing to do.
	var e := _current()
	if e.is_empty() or not e.get("ok", false) or str(e.get("act", "")) == "":
		return false
	var w := _weapons()
	match TABS[tab][0]:
		"weapons":
			if not w:
				return false
			if e.id == "":
				w.holster()
			else:
				w.swap(w.owned.find(e.id))
		"items":
			match e.id:
				"tea":
					player.drink_tea()
				"mask":
					player.toggle_mask()
				"headlamp":
					player.toggle_flashlight()
	Snd.sfx("click")
	return true


func close() -> void:
	Snd.sfx("click")
	if game:
		game.resume()
	else:
		queue_free()
