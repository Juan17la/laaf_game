class_name MenuDraw
extends RefCounted
## The dossier's hand (DESIGN.md): palette, the two typefaces, and the drawn pieces every menu page is made of (text,
## chips, the rust bar with its ENTER keycap, rows, the folder, the logo, the help bar), drawn into one CanvasItem from
## its _draw. The main menu (scripts/main_menu.gd) and the pause menu (scripts/pause_menu.gd) both draw with it, so they
## are one look. Each draw also lays out `hits`: [Rect2, kind, index] for what the mouse can point at (last on top).

const BONE := Color(0.914, 0.886, 0.827)
const MUTED := Color(0.7, 0.67, 0.61)  ## secondary text on the folder
const FAINT := Color(0.56, 0.53, 0.48)
const RUST := Color(0.62, 0.08, 0.06)
const RUST_HI := Color(0.77, 0.16, 0.11)
const AMBER := Color(1.0, 0.72, 0.3)
const FOLDER := Color(0.075, 0.064, 0.055)
const FOLDER_HI := Color(0.13, 0.114, 0.098)
const PRINT := Color(0.86, 0.83, 0.76)  ## the photo's white border
const FOLDER_W := 222.0
const PAD := 15.0
const BAR_H := 26.0
const LINE_H := 17.0
const LOGO_SCALE := 1.12  ## the logo's size against its 52 px base
const LOGO_DROP := 0.04  ## how far it sits below its first place, as a share of the screen height
const Guide := preload("res://player/guide.gd")

var ci: CanvasItem
var serif: Font
var serif_it: Font
var ui: Font
var bold: Font
var caps: FontVariation  ## bold, tracked: labels and keycaps
var wide: FontVariation  ## bold, wide-tracked: HOLLOWMERE under the logo
var logo_font: FontVariation
var a := 1.0  ## the page's alpha (a leaf turning, the dossier fading in)
var hits: Array = []  ## [Rect2, kind, index] laid out by the last draw
var hover := ""  ## the hit kind under the mouse
var hover_i := -1  ## ...and its index


func _init(canvas: CanvasItem) -> void:
	ci = canvas
	serif = load("res://fonts/IMFeENrm28P.ttf")
	serif_it = load("res://fonts/IMFeENit28P.ttf")
	ui = load("res://fonts/BarlowSemiCondensed-Medium.ttf")
	bold = load("res://fonts/BarlowSemiCondensed-Bold.ttf")
	caps = _tracked(bold, 1)
	wide = _tracked(bold, 4)
	logo_font = _tracked(serif, 16)


func _tracked(base: Font, spacing: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_glyph = spacing
	return v


# ------------------------------------------------------------------ the mouse

func hit(p: Vector2) -> Array:
	for i in range(hits.size() - 1, -1, -1):  # last drawn on top
		if (hits[i][0] as Rect2).has_point(p):
			return hits[i]
	return []


func point(p: Vector2) -> Array:
	## The hit under p, kept as the hover.
	var h := hit(p)
	hover = h[1] if not h.is_empty() else ""
	hover_i = h[2] if not h.is_empty() else -1
	return h


func hot(kind: String, i := 0) -> bool:
	return hover == kind and hover_i == i


static func cursor(on: bool) -> void:
	## The menus' pointer: a small bone arrow with a black edge, in chunky pixels like the town behind it. Off: the
	## system's arrow again (the minigames that show the mouse keep their own look).
	if DisplayServer.get_name() == "headless":
		return
	if not on:
		Input.set_custom_mouse_cursor(null)
		return
	var art := ["X.........", "XX........", "XOX.......", "XOOX......", "XOOOX.....", "XOOOOX....", "XOOOOOX...",
		"XOOOOOOX..", "XOOOOOOOX.", "XOOOOOXXXX", "XOOXOOX...", "XOX.XOOX..", "XX..XOOX..", "X....XOOX.",
		".....XOOX.", "......XX.."]
	var k := clampi(roundi(DisplayServer.window_get_size().y / 540.0), 2, 4)
	var img := Image.create(10 * k, art.size() * k, false, Image.FORMAT_RGBA8)
	for y in art.size():
		for x in 10:
			var ch: String = art[y][x]
			if ch != ".":
				img.fill_rect(Rect2i(x * k, y * k, k, k), Color.BLACK if ch == "X" else BONE)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2.ZERO)


# ------------------------------------------------------------------ text

func c(col: Color, k := 1.0) -> Color:
	## A colour at the page's current alpha (times k).
	return Color(col, col.a * k * a)


func text(font: Font, at: Vector2, s: String, size: int, col: Color, w := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(font, at, s, align, w, size, col)


func shadowed(font: Font, at: Vector2, s: String, size: int, col: Color, w := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	## Text straight on the fog: a soft dark shadow under it so it holds on the bright patches.
	ci.draw_string(font, at + Vector2(0, 1), s, align, w, size, Color(0, 0, 0, col.a * 0.7))
	ci.draw_string(font, at, s, align, w, size, col)


func fit(font: Font, s: String, size: int, w: float) -> String:
	## s cut to width w with an ellipsis.
	if font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= w:
		return s
	while s.length() > 1 and font.get_string_size(s + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
		s = s.left(-1)
	return s.strip_edges() + "…"


func wrap(font: Font, at: Vector2, s: String, size: int, col: Color, w: float, lines := 2) -> void:
	ci.draw_multiline_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, w, size, lines, col)


func heading(x: float, y: float, s: String, right := "") -> void:
	text(serif, Vector2(x, y), s, 17, c(BONE))
	if right != "":
		text(ui, Vector2(x, y - 1.0), right, 7, c(MUTED), FOLDER_W - PAD * 2.0, HORIZONTAL_ALIGNMENT_RIGHT)


# ------------------------------------------------------------------ pieces

func key(right: float, mid_y: float, label: String, col: Color) -> float:
	## A keycap ending at x = right, centred on mid_y; returns its width.
	var w := caps.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x + 8.0
	var r := Rect2(right - w, mid_y - 5.5, w, 11)
	ci.draw_polyline(Icons.round_rect(r, 3.0), Color(col, col.a * 0.55), 1.0, true)
	text(caps, Vector2(r.position.x + 4.0, mid_y + 2.2), label, 6, col)
	return w


func chip(x: float, y: float, icon: String, s: String, tint := Color(0, 0, 0, 0)) -> float:
	## A pill: drawn icon + a short fact. Returns its width.
	var tw := ui.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var r := Rect2(x, y, tw + 23.0, 14.0)
	Icons.fill_round(ci, r, 7.0, c(BONE, 0.08) if tint.a == 0.0 else c(tint))
	var ink := MUTED if tint.a == 0.0 else Color(0.96, 0.74, 0.68)
	Icons.draw(ci, icon, Vector2(x + 9.5, y + 7.0), 9.0, c(ink), 1.1)
	text(ui, Vector2(x + 16.5, y + 9.8), s, 7, c(ink))
	return r.size.x


func bar(r: Rect2, label: String, icon: String, armed: bool) -> void:
	## The page's one primary action: a rust bar with its drawn icon, its name and the ENTER keycap.
	hits.append([r, "bar", 0])
	var top := RUST_HI if armed or hover == "bar" else RUST.lerp(RUST_HI, 0.35)
	var pts := Icons.round_rect(r, 8.0, false)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(c(top.lerp(RUST.darkened(0.25), (p.y - r.position.y) / r.size.y)))
	ci.draw_polygon(pts, cols)
	Icons.draw(ci, icon, Vector2(r.position.x + 15.0, r.get_center().y), 10.0, c(BONE), 1.4)
	text(caps, Vector2(r.position.x + 27.0, r.get_center().y + 3.4), label, 9, c(BONE))
	key(r.end.x - 9.0, r.get_center().y, "ENTER", c(BONE, 0.9))


func index_tab(r: Rect2, col: Color, stroke := true) -> void:
	## An index tab on the folder's left edge: rounded on the outside (left) edge, square where it meets the folder.
	## The open one has no stroke: it's the folder's own leaf.
	var pts := Icons.round_rect(Rect2(r.position, r.size + Vector2(10, 0)), 7.0, false)
	var edge := PackedVector2Array([r.end])
	for i in pts.size():
		pts[i].x = minf(pts[i].x, r.end.x)
		if i >= 10:  # the bottom-left and top-left corners, in order
			edge.append(pts[i])
	edge.append(Vector2(r.end.x, r.position.y))
	ci.draw_colored_polygon(pts, col)
	if stroke:
		ci.draw_polyline(edge, Color(BONE, 0.08 * col.a), 1.0, true)


func tab_face(r: Rect2, icon: String, label: String, open: bool, e: float) -> void:
	## A tab's drawn icon over its short name (amber and bright when open).
	var at := r.get_center() + Vector2(0 if open else -2, -3.5)
	var ink := AMBER if open else MUTED
	Icons.draw(ci, icon, at, 12.0, Color(ink, (1.0 if open else 0.75) * e), 1.3)
	text(bold, Vector2(r.position.x, r.end.y - 3.5), label, 7, Color(BONE if open else MUTED, e),
		r.size.x - (0 if open else 4), HORIZONTAL_ALIGNMENT_CENTER)


func row_box(r: Rect2, on: bool) -> void:
	## A list row: faint fill, the selected one brighter with a fine amber outline.
	Icons.fill_round(ci, r, 7.0, c(BONE, 0.095 if on else 0.04))
	if on:
		ci.draw_polyline(Icons.round_rect(r, 7.0), c(AMBER, 0.85), 1.0, true)


func photo(r: Rect2, pos: Variant, rot: float, label: String) -> void:
	## A print of the town map pinned where `pos` ([x, z]) is; no pos: the whole town, no pin.
	ci.draw_set_transform(r.get_center(), rot, Vector2.ONE)
	var local := Rect2(-r.size / 2.0, r.size)
	Icons.fill_round(ci, Rect2(local.position + Vector2(1, 3), local.size), 3.0, Color(0, 0, 0, 0.45 * a))
	Icons.fill_round(ci, local, 3.0, c(PRINT))
	var img := Rect2(local.position + Vector2(4, 4), local.size - Vector2(8, 8 + (11.0 if label != "" else 0.0)))
	var span := Vector2(img.size.x, img.size.y) * (2.2 if pos != null else 2.4)  # map pixels across the print
	var at0 := Vector2(0, 0) if pos == null else Vector2(pos[0], pos[1])
	var px := (at0 - Vector2(Guide.MAP_X0, Guide.MAP_Z0)) * Guide.PPM
	var region := Rect2(px - span / 2.0, span)
	region.position = region.position.clamp(Vector2.ZERO, Vector2(Guide.MAP_PX, Guide.MAP_PX) - span)
	ci.draw_texture_rect_region(Guide.MAP_TEX, img, region, c(Color(0.78, 0.74, 0.66)))
	ci.draw_rect(img, c(Color(0.1, 0.07, 0.04), 0.18))  # aged
	if pos != null:
		var at := img.position + (px - region.position) / span * img.size
		ci.draw_circle(at + Vector2(0, 1), 4.6, Color(0, 0, 0, 0.4 * a), true, -1.0, true)
		ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-3.2, -4), at + Vector2(3.2, -4), at + Vector2(0, 3)]),
			c(RUST_HI))
		ci.draw_circle(at + Vector2(0, -5.5), 4.0, c(RUST_HI), true, -1.0, true)
		ci.draw_circle(at + Vector2(0, -5.5), 1.4, c(PRINT), true, -1.0, true)
	if label != "":
		text(serif_it, Vector2(local.position.x + 6, local.end.y - 4.5), label, 9, c(Color(0.2, 0.15, 0.1)))
	ci.draw_set_transform(Vector2.ZERO)


func folder(f: Rect2, e: float) -> void:
	## The dossier: a soft offset shadow in three widening layers, then the folder's own gradient.
	for k in 3:
		Icons.fill_round(ci, f.grow(2.0 + k * 3.0).grow_side(SIDE_TOP, -2.0 - k * 3.0), 12.0 + k * 3.0,
			Color(0, 0, 0, 0.16 * e))
	var pts := Icons.round_rect(f, 11.0, false)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(Color(FOLDER_HI.lerp(FOLDER, (p.y - f.position.y) / f.size.y), 0.97 * e))
	ci.draw_polygon(pts, cols)


func letterbox(W: float, H: float) -> void:
	## Black bars top and bottom, like the FMVs.
	ci.draw_rect(Rect2(0, 0, W, 18), Color.BLACK)
	ci.draw_rect(Rect2(0, H - 18, W, 18), Color.BLACK)


func logo(W: float, H: float, e: float) -> void:
	## "LAAF" with its rust rule and HOLLOWMERE: centred and large on the title screen (e 0), at the top left of the
	## dossier (e 1), drifting between the two as the dossier opens.
	var drop := H * LOGO_DROP
	var at := Vector2(W / 2.0, 150 + drop).lerp(Vector2(32, 70 + drop), e)
	var sc := lerpf(1.35, 1.0, e) * LOGO_SCALE
	var size := 52
	var s := "LAAF"
	var tw := logo_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x - 16.0  # the last letter's tracking
	var off := lerpf(-tw / 2.0, 0.0, e)  # centred → left aligned
	ci.draw_set_transform(at, 0.0, Vector2(sc, sc))
	shadowed(logo_font, Vector2(off, 0), s, size, Color(BONE, 0.95))
	var sw := wide.get_string_size("HOLLOWMERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x - 4.0
	ci.draw_rect(Rect2(lerpf(-tw * 0.4, 0.0, e), 9, tw * 0.8, 1.2), Color(RUST_HI, 0.95))  # centred under it, then flush left
	shadowed(wide, Vector2(lerpf(-sw / 2.0, 0.0, e), 23), "HOLLOWMERE", 7, Color(MUTED, 0.95))
	ci.draw_set_transform(Vector2.ZERO)


func help(keys: Array, right: float, y: float, e: float) -> void:
	## The keys that work right now, right-aligned in the bottom letterbox: [keycap, word, action]. A pair with an
	## action ("back", "accept") can be clicked too: it brightens under the mouse.
	var x := right
	for k in keys:
		var act: String = k[2] if k.size() > 2 else ""
		var lit := act != "" and hover == "hint" and hover_i == ["back", "accept"].find(act)
		var tw := ui.get_string_size(k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		text(ui, Vector2(x - tw, y + 2.5), k[1], 7, Color(BONE if lit else MUTED, e))
		var end := x
		x -= tw + 4.0
		x -= key(x, y, k[0], Color(BONE, (1.0 if lit else 0.85) * e))
		if act != "":
			hits.append([Rect2(x - 2.0, y - 8.0, end - x + 4.0, 16.0), "hint", ["back", "accept"].find(act)])
		x -= 12.0
