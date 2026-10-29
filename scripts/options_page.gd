class_name OptionsPage
extends RefCounted
## The Options page (scripts/settings.gd's rows under their group headings), one page for both menus: the main menu's
## OPTIONS tab and the pause menu draw this same page with MenuDraw and send it their input, so they look and behave
## alike. Every change applies at once and is kept. Keys: W/S move, A/D or Enter step the setting. Mouse: a row is
## chosen under the pointer and stepped by a click; a meter's track is clicked or dragged to a value, a multiplier is
## dragged sideways; the wheel over a value adjusts it, elsewhere it scrolls.

const LINES := 12  ## lines in view

var lines: Array = []  ## ["h", title] group headers and ["r", "section/key"] rows
var ids: Array = []  ## the selectable rows' ids, in order
var sel := 0
var top := 0  ## first line in view
var _drag := {}  ## the value being dragged: {id, x0, v0, moved, track}


func _init() -> void:
	for g in Settings.GROUPS:
		lines.append(["h", g[1]])
		for r in Settings.ROWS:
			if r[0] == g[0]:
				lines.append(["r", "%s/%s" % [r[0], r[1]]])
				ids.append("%s/%s" % [r[0], r[1]])


func enter() -> void:
	sel = 0
	top = 0
	scroll()


# ------------------------------------------------------------------ drawing

func draw(d: MenuDraw, r: Rect2, focused: bool) -> void:
	d.heading(r.position.x, r.position.y + 16, tr("Options"))
	var sel_id: String = ids[sel] if focused else ""
	var y := r.position.y + 30.0
	for li in range(top, mini(top + LINES, lines.size())):
		var line: Array = lines[li]
		if line[0] == "h":
			if li == top + LINES - 1:
				break
			d.text(d.caps, Vector2(r.position.x, y + 11), tr(line[1]), 7, d.c(MenuDraw.MUTED))
		else:
			var id: String = line[1]
			var row := Rect2(r.position.x - 4, y, r.size.x + 8, MenuDraw.LINE_H - 1)
			if id == sel_id:
				d.row_box(row, true)
			d.hits.append([row, "row", ids.find(id)])
			var spec := Settings.row(id)
			d.text(d.ui, Vector2(r.position.x + 2, y + 11), d.fit(d.ui, tr(spec[2]), 7, r.size.x - 66.0),
				7, d.c(MenuDraw.BONE if id == sel_id else MenuDraw.MUTED))
			_value(d, Rect2(r.end.x - 62, y, 60, MenuDraw.LINE_H - 1), id, spec)
		y += MenuDraw.LINE_H
	var help: String = tr(Settings.row(sel_id)[6]) if sel_id != "" \
		else tr("Changes apply at once and are kept.")
	d.wrap(d.ui, Vector2(r.position.x, r.end.y - 12), help, 7, d.c(MenuDraw.MUTED), r.size.x, 2)


func _value(d: MenuDraw, r: Rect2, id: String, spec: Array) -> void:
	## A setting's value, drawn: a meter for a percentage, a switch for a toggle, the number for a multiplier.
	var mid := r.get_center().y
	var i := ids.find(id)
	match spec[3]:
		"percent":
			var v := Settings.number(id)
			var track := Rect2(r.position.x, mid - 1.5, 36, 3)
			Icons.fill_round(d.ci, track, 1.5, d.c(MenuDraw.BONE, 0.12))
			if v > 0.0:
				Icons.fill_round(d.ci, Rect2(track.position, Vector2(36 * v, 3)), 1.5, d.c(MenuDraw.AMBER))
			d.text(d.ui, Vector2(r.position.x, mid + 2.5), "%d%%" % roundi(v * 100.0), 7, d.c(MenuDraw.BONE), r.size.x,
				HORIZONTAL_ALIGNMENT_RIGHT)
			d.hits.append([Rect2(track.position.x - 4, r.position.y, track.size.x + 8, r.size.y), "track", i])
			d.hits.append([Rect2(track.end.x + 4, r.position.y, r.end.x - track.end.x - 4, r.size.y), "value", i])
		"times":
			d.text(d.ui, Vector2(r.position.x, mid + 2.5), "×%.1f" % Settings.number(id), 7, d.c(MenuDraw.BONE), r.size.x,
				HORIZONTAL_ALIGNMENT_RIGHT)
			d.hits.append([r, "value", i])
		"toggle":
			var on := Settings.flag(id)
			var sw := Rect2(r.end.x - 18, mid - 4.5, 18, 9)
			Icons.fill_round(d.ci, sw, 4.5, d.c(MenuDraw.AMBER) if on else d.c(MenuDraw.BONE, 0.15))
			d.ci.draw_circle(Vector2(sw.end.x - 4.5 if on else sw.position.x + 4.5, mid), 3.2,
				d.c(MenuDraw.FOLDER if on else MenuDraw.BONE, 1.0 if on else 0.6), true, -1.0, true)
		_:
			d.text(d.ui, Vector2(r.position.x, mid + 2.5), Settings.text(id), 7, d.c(MenuDraw.BONE), r.size.x,
				HORIZONTAL_ALIGNMENT_RIGHT)


# ------------------------------------------------------------------ keys

func nav(dx: int, dy: int) -> void:
	if dx != 0:
		step(dx)
	elif dy != 0:
		sel = wrapi(sel + dy, 0, ids.size())
		scroll()
		Snd.sfx("move")


func accept() -> void:
	step(1)


func step(dir: int) -> void:
	Settings.step(ids[sel], dir)
	Snd.sfx("move")


func scroll() -> void:
	## Keeps the selection in view, its group's heading too when it's the group's first row.
	var line := lines.find(["r", ids[sel]])
	var first := line - 1 if line > 0 and lines[line - 1][0] == "h" else line
	top = clampi(top, line - LINES + 1, first)


# ------------------------------------------------------------------ the mouse

func hover(h: Array) -> bool:
	## The pointer moved onto h: its row becomes the selection. True when that changed it.
	if h.is_empty() or not h[1] in ["row", "track", "value"] or h[2] == sel:
		return false
	sel = h[2]
	Snd.sfx("move")
	return true


func press(h: Array, at: Vector2) -> void:
	## A left press on h: a row steps like Enter, a meter's track jumps to the point, a value starts a drag.
	if h.is_empty() or not h[1] in ["row", "track", "value"]:
		return
	sel = h[2]
	var id: String = ids[sel]
	var kind: String = Settings.row(id)[3]
	if h[1] == "track":
		_drag = {"id": id, "track": h[0], "moved": true}
		_set_from_track(at)
	elif h[1] == "value" and kind in ["percent", "times"]:
		_drag = {"id": id, "x0": at.x, "v0": Settings.number(id), "moved": false}
	else:
		accept()


func motion(at: Vector2) -> void:
	if _drag.is_empty():
		return
	if _drag.has("track"):
		_set_from_track(at)
		return
	if absf(at.x - float(_drag.x0)) < 2.0 and not _drag.moved:
		return
	_drag.moved = true
	var e: Array = Settings.row(_drag.id)[5]
	_put(_drag.id, float(_drag.v0) + (at.x - float(_drag.x0)) / 60.0 * (float(e[1]) - float(e[0])))


func release() -> void:
	## The end of a drag: kept to the file once; a value pressed without moving steps like Enter.
	if _drag.is_empty():
		return
	var id: String = _drag.id
	var moved: bool = _drag.moved
	_drag = {}
	if moved:
		Settings.save_file()
	elif ids.find(id) == sel:
		accept()


func dragging() -> bool:
	return not _drag.is_empty()


func wheel(h: Array, dir: int) -> void:
	## The wheel (dir 1 up, -1 down): over a meter or a multiplier it adjusts that setting; anywhere else it scrolls.
	if not h.is_empty() and h[1] in ["track", "value"]:
		sel = h[2]
		step(dir)
		return
	top = clampi(top - dir, 0, maxi(lines.size() - LINES, 0))
	var first := top
	var last := mini(top + LINES, lines.size()) - 1
	var line := lines.find(["r", ids[sel]])
	if line < first or line > last:  # the selection stays in view: the nearest row that is
		for li in (range(first, last + 1) if line < first else range(last, first - 1, -1)):
			if lines[li][0] == "r":
				sel = ids.find(lines[li][1])
				break


func _set_from_track(at: Vector2) -> void:
	var t: Rect2 = _drag.track
	var e: Array = Settings.row(_drag.id)[5]
	var k := clampf((at.x - (t.position.x + 4.0)) / (t.size.x - 8.0), 0.0, 1.0)
	_put(_drag.id, lerpf(float(e[0]), float(e[1]), k))


func _put(id: String, v: float) -> void:
	## A dragged value: applied while it moves (only when it lands on a new notch), saved when the drag ends.
	var e: Array = Settings.row(id)[5]
	v = clampf(snappedf(v, float(e[2])), float(e[0]), float(e[1]))
	if not is_equal_approx(v, Settings.number(id)):
		Settings.set_value(id, v, false)
		Snd.sfx("move")
