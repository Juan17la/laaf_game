class_name WeaponWheel
extends Control
## The selection wheel (hold Tab, or the pad's Y; player.gd): the game slows to SLOW and greys out while it's up.
## The fists and every weapon carried sit round the ring (top first, clockwise, in the order of the number keys),
## then, past a divider, the items Alex has (bottles, smoke cans, Elena's tea, the gas mask, the headlamp). The mouse
## or the right stick points at one (an amber needle on the hub shows where); letting go draws the weapon or uses the
## item (a throw lands on the crosshair); a right click or the pad's B, or pausing, closes it without picking.
## Drawn with the dossier's hand (scripts/menu_draw.gd: its palette, Barlow and IM Fell, keycaps), in the crisp
## canvas_items scale while it's open, like the menus. The hub says what letting go does, to what, and its quick key;
## under the ring, what a picked item does; the help line shows the keyboard's keys or the pad's buttons, whichever
## was used last.

const SLOW := 0.25  ## Engine.time_scale while it's open
const R_IN := 56.0
const R_OUT := 140.0
const POP := 8.0  ## px the picked slot stands out
const GAP := 0.022  ## rad left between two slots
const DEAD := 14.0  ## px the pointer must move off the centre before it picks
const ICON_DIR := "res://ui/icons/%s.png"
const ICON_LIFT := {"headlamp": 2.4, "mask": 1.7, "revolver": 1.5, "smoke": 1.6, "shotgun": 1.3, "bat": 1.8,
	"bow": 1.6}  ## the darker
## PS2 icons brightened to read on the ring (a knob: tune by eye after re-rendering ui/icons)
const FADE := 0.09  ## s (real time, not slowed): the wheel and the grey fade in
const ITEM_KEYS := {"bottle": "G", "smoke": "T", "tea": "H", "mask": "X", "headlamp": "F"}
const ITEM_TEXT := {  ## what each item does, one line under the ring (the inventory's sentences, already translated)
	"bottle": "Thrown onto the crosshair. Whatever hears it shatter goes to look.",
	"smoke": "Thrown onto the crosshair: a cloud that hides everything in and behind it.",
	"tea": "Lowers the Mark by 15%.",
	"mask": "Worn in the gas, the filter wears down instead of you.",
	"headlamp": "Strapped to your head. It shines where you look.",
}

var player: Node  ## player/player.gd
var weapons: Weapons
var sel := 0  ## index into slots(): 0 the fists, then the weapons, then the items
var _slots: Array = []  ## slots() as it stood when the wheel opened
var _point := Vector2.ZERO  ## where the mouse has pushed the pointer, px from the centre
var _dir := Vector2.ZERO  ## the last direction pointed (the needle)
var _scale_mode := -1  ## the window's content scale before the wheel opened (-1: closed)
var _icons := {}
var _d: MenuDraw
var _open_t := 1.0  ## 0..1 through the fade-in
var _pad := false  ## the last input came from a gamepad: the help line shows its buttons


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	_d = MenuDraw.new(self)
	var back := ColorRect.new()  # the slowed game, greyed and darkened (under the ring)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.show_behind_parent = true
	back.material = ShaderMaterial.new()
	(back.material as ShaderMaterial).shader = load("res://shaders/wheel_grey.gdshader")
	add_child(back)


func _process(delta: float) -> void:
	if visible and _open_t < 1.0:
		_open_t = minf(_open_t + delta / maxf(Engine.time_scale, 0.01) / FADE, 1.0)
		modulate.a = ease(_open_t, 0.4)


func _input(e: InputEvent) -> void:
	var pad := e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.4)
	if pad != _pad and (pad or e is InputEventKey or e is InputEventMouseButton or e is InputEventMouseMotion):
		_pad = pad
		if visible:
			queue_redraw()


func slots() -> Array:
	## Every slot from the live state: {id, item, icon, name, count (under the icon), verb (what letting go does),
	## key (its quick key), ok, empty, why}.
	var out := []
	var ids: Array = [""] + weapons.owned
	for i in ids.size():
		var id: String = ids[i]
		var sp: Dictionary = Weapons.GUNS[id] if id != "" else Weapons.FISTS
		var held: bool = weapons.gun() == id
		var s := {"id": id, "item": false, "icon": id if id != "" else "fists", "name": tr(sp.name), "count": "",
			"verb": tr("In hand.").trim_suffix(".").to_upper() if held else tr("EQUIP"), "key": str(i), "ok": true,
			"empty": false, "why": ""}
		if sp.kind != "melee":
			s.count = "%d / %d" % [weapons.loaded[id], weapons.reserve[id]]
			s.empty = int(weapons.loaded[id]) + int(weapons.reserve[id]) <= 0
		out.append(s)
	if not player:
		return out
	for it in [["bottle", "bottles", "Bottle", "THROW"], ["smoke", "smokes", "Smoke can", "THROW"],
			["tea", "teas", "Elena's Tea", "DRINK"]]:
		var n := int(player.get(it[1]))
		if n > 0:
			var clear: bool = it[0] == "tea" and float(player.get("mark")) <= 0.0
			out.append({"id": it[0], "item": true, "icon": it[0], "name": tr(it[2]), "count": "×%d" % n,
				"verb": tr(it[3]), "key": ITEM_KEYS[it[0]], "ok": not clear, "empty": false,
				"why": tr("The Mark is already clear.") if clear else ""})
	if bool(player.get("gas_mask")):
		var on := bool(player.get("mask_on"))
		out.append({"id": "mask", "item": true, "icon": "mask", "name": tr("Gas mask"), "count": tr("On") if on else tr("Off"),
			"verb": tr("TAKE OFF") if on else tr("PUT ON"), "key": "X", "ok": true, "empty": false, "why": ""})
	var lamp: Node = player.get("flashlight")
	if lamp:
		var lit := bool(lamp.get("visible"))
		out.append({"id": "headlamp", "item": true, "icon": "headlamp", "name": tr("Headlamp"),
			"count": tr("On") if lit else tr("Off"), "verb": tr("TURN OFF") if lit else tr("TURN ON"), "key": "F",
			"ok": true, "empty": false, "why": ""})
	return out


func open(p: Node) -> void:
	player = p
	weapons = p.weapons
	_slots = slots()
	sel = weapons.current + 1 if weapons.gun() != "" else 0
	_point = Vector2.ZERO
	_dir = Vector2.ZERO
	visible = true
	_open_t = 0.0
	modulate.a = 0.0
	Engine.time_scale = SLOW
	_scale_mode = get_window().content_scale_mode  # crisp text and icons while it's up, as in the menus
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	Snd.sfx("click")
	queue_redraw()


func close(apply: bool) -> void:
	if not visible:
		return
	visible = false
	Engine.time_scale = 1.0
	if _scale_mode >= 0 and is_inside_tree():
		get_window().content_scale_mode = _scale_mode as Window.ContentScaleMode
	_scale_mode = -1
	if not apply:
		Snd.sfx("click")
	if not apply or not weapons or sel >= _slots.size():
		return
	var s: Dictionary = _slots[sel]
	if not s.item:
		if s.id == "":
			weapons.holster()
		else:
			weapons.swap(weapons.owned.find(s.id))
		return
	match s.id:
		"bottle":
			player.throw_bottle()
		"smoke":
			player.throw_smoke()
		"tea":
			player.drink_tea()
		"mask":
			player.toggle_mask()
		"headlamp":
			player.toggle_flashlight()


func mouse(rel: Vector2) -> void:
	_point = (_point + rel).limit_length(R_OUT)
	aim(_point)


func aim(v: Vector2) -> void:
	## Points the wheel along v (screen space, y down): the slot it points at is picked.
	if v.length() < DEAD or _slots.is_empty():
		return
	_dir = v.normalized()
	var n := _slots.size()
	var i := wrapi(roundi((v.angle() + PI / 2.0) / (TAU / n)), 0, n)
	if i != sel:
		sel = i
		Snd.sfx("move")
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		close(false)  # (never leaves the game slowed under a menu or after a scene change)


func _icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := ICON_DIR % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]


func _arc(c: Vector2, a0: float, a1: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := maxi(8, ceili(absf(a1 - a0) * 24.0))  # (smooth however wide the slot)
	for k in steps + 1:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(k) / steps)) * r)
	return pts


func _keycap(x: float, mid_y: float, label: String, col: Color) -> float:
	## A keycap starting at x, centred on mid_y, its label at the 7px floor; returns its width.
	var w := _d.caps.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 9.0
	var r := Rect2(x, mid_y - 6.5, w, 13)
	draw_polyline(Icons.round_rect(r, 3.0), Color(col, col.a * 0.55), 1.0, true)
	_d.text(_d.caps, Vector2(x + 4.5, mid_y + 2.6), label, 7, col)
	return w


func _draw() -> void:
	if _slots.is_empty():
		return
	var c := size / 2.0 - Vector2(0, 8)  # (a little high: room under the ring for the item's line and the help)
	var n := _slots.size()
	var step := TAU / n
	var first_item := n
	for i in n:
		if _slots[i].item:
			first_item = i
			break
	for i in n:
		var s: Dictionary = _slots[i]
		var on := i == sel
		var mid := -PI / 2.0 + i * step
		var a0 := mid - step / 2.0 + GAP
		var a1 := mid + step / 2.0 - GAP
		var out := R_OUT + (POP if on else 0.0)
		var wedge := _arc(c, a0, a1, out)  # the slot: a wedge of the ring, the picked one pushed out and lit amber
		wedge.append_array(_arc(c, a1, a0, R_IN))
		draw_colored_polygon(wedge, Color(MenuDraw.FOLDER_HI, 0.94) if not on else Color(0.22, 0.18, 0.13, 0.97))
		if on:
			var edge := wedge.duplicate()
			edge.append(wedge[0])
			draw_polyline(edge, Color(MenuDraw.AMBER, 0.85), 1.0, true)
			draw_polyline(_arc(c, a0 + 0.01, a1 - 0.01, out - 1.5), MenuDraw.AMBER, 3.0, true)
		var dir := Vector2.from_angle(mid)
		var dim := 1.0 if on else (0.85 if s.ok else 0.35)
		var at := c + dir * (R_IN + 34.0)
		Icons.fill_round(self, Rect2(at - Vector2(22, 22), Vector2(44, 44)), 22.0, Color(MenuDraw.BONE, 0.12 if on else 0.07))
		var side := 46.0 if on else 40.0
		var tex := _icon(s.icon)
		if tex:
			var lift: float = ICON_LIFT.get(s.icon, 1.0)
			draw_texture_rect(tex, Rect2(at - Vector2(side, side) / 2.0, Vector2(side, side)), false,
				Color(lift, lift, lift, dim))
		else:
			Icons.draw(self, s.icon, at, side * 0.6, Color(MenuDraw.BONE, dim), 1.5)
		var label: String = tr("EMPTY") if s.empty else s.count
		if label != "":
			var lc: Color = MenuDraw.RUST_HI if s.empty else (MenuDraw.BONE if on else MenuDraw.MUTED)
			_d.text(_d.bold, c + dir * (R_IN + 70.0) + Vector2(-40, 4), label, 10, Color(lc, maxf(dim, 0.6)), 80,
				HORIZONTAL_ALIGNMENT_CENTER)
		if not s.item and weapons.gun() == s.id:  # in hand: the inventory's amber hand-mark, on the slot's rim
			draw_circle(c + dir * (R_IN + 8.0), 3.0, MenuDraw.AMBER, true, -1.0, true)
	if first_item > 0 and first_item < n:  # weapons | items: a faint rule through the gap at both ends of the items
		for k in [first_item, n]:
			var a: float = -PI / 2.0 + (k - 0.5) * step
			draw_line(c + Vector2.from_angle(a) * (R_IN + 6.0), c + Vector2.from_angle(a) * (R_OUT - 6.0),
				Color(MenuDraw.BONE, 0.3), 1.0, true)
	var s: Dictionary = _slots[sel]  # the hub: what letting go does, to what, and the quick key that does it too
	var hr := R_IN - 5.0
	draw_circle(c, hr, Color(0.035, 0.03, 0.026, 0.96), true, -1.0, true)
	draw_arc(c, hr, 0, TAU, 64, Color(MenuDraw.AMBER, 0.5), 1.0, true)
	if _dir != Vector2.ZERO:  # the needle: where the mouse or the stick points
		var tip := c + _dir * (hr - 2.0)
		var side_v := _dir.orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([tip, tip - _dir * 8.0 + side_v, tip - _dir * 8.0 - side_v]),
			MenuDraw.AMBER)
	var w := hr * 1.6  # (clear of the needle)
	var verb: String = s.verb  # (faint when it can't: the line under the ring says why; an empty gun still equips)
	_d.text(_d.caps, c + Vector2(-w / 2.0, -20), verb, 8, MenuDraw.AMBER if s.ok else MenuDraw.FAINT, w,
		HORIZONTAL_ALIGNMENT_CENTER)
	var fs := 17
	while fs > 11 and _d.serif.get_string_size(s.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	_d.text(_d.serif, c + Vector2(-w / 2.0, 3), _d.fit(_d.serif, s.name, fs, w), fs, MenuDraw.BONE, w,
		HORIZONTAL_ALIGNMENT_CENTER)
	if not _pad:  # (the quick keys are the keyboard's)
		var kw := _d.caps.get_string_size(s.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 9.0
		_keycap(c.x - kw / 2.0, c.y + 22.0, s.key, Color(MenuDraw.BONE, 0.8))
	var y := c.y + R_OUT + POP + 15.0  # under the ring: why not (rust), else what the item does
	var line: String = s.why if s.why != "" else tr(ITEM_TEXT.get(s.id, "")) if s.item else ""
	if line != "":
		_d.shadowed(_d.ui, Vector2(0, y), _d.fit(_d.ui, line, 9, size.x - 32.0), 9,
			MenuDraw.RUST_HI if s.why != "" else MenuDraw.BONE, size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var keys := [["Y", tr("Release to pick")], ["B", tr("Cancel")]] if _pad else \
		[["TAB", tr("Release to pick")], [tr("RIGHT CLICK"), tr("Cancel")]]  # the help line, centred
	var widths := []
	var total := 0.0
	for k in keys:
		var kw2: float = _d.caps.get_string_size(k[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 9.0
		var tw: float = _d.ui.get_string_size(k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		widths.append([kw2, tw])
		total += kw2 + 5.0 + tw + 16.0
	var x := c.x - (total - 16.0) / 2.0
	var hy := size.y - 12.0
	for i in keys.size():
		x += _keycap(x, hy, keys[i][0], Color(MenuDraw.BONE, 0.85)) + 5.0
		_d.shadowed(_d.ui, Vector2(x, hy + 3.0), keys[i][1], 9, MenuDraw.MUTED)
		x += widths[i][1] + 16.0
