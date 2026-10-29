class_name Icons
extends RefCounted
## The game's drawn icon set: one stroke weight, rounded joins, a 24-unit grid scaled to any size, so the
## menus and the HUD share one hand. Icons.draw(canvas_item, "revolver", centre, size, colour) from any _draw.
## Commands per icon: ["l", pts] open line · ["c", pts] closed outline · ["f", pts] filled shape ·
## ["o", cx, cy, r] circle · ["d", cx, cy, r] dot · ["a", cx, cy, r, from°, to°] arc · ["r", x, y, w, h, radius] rounded box.

const SET := {
	# menu
	"continue": [["a", 12, 6, 3, 180, 360], ["l", [9, 6, 9, 8]], ["l", [15, 6, 15, 8]], ["r", 7, 8, 10, 11, 2],
		["l", [5, 21, 19, 21]], ["f", [12, 10.5, 14.2, 14.5, 12, 17, 9.8, 14.5]]],
	"new": [["r", 3, 6, 18, 12, 2], ["l", [3.5, 7.5, 12, 13.5, 20.5, 7.5]]],
	"load": [["r", 5, 3, 14, 18, 2], ["l", [9, 3, 9, 21]], ["l", [12, 8, 16, 8]], ["l", [12, 11.5, 16, 11.5]]],
	"extra": [["o", 12, 15, 6], ["l", [8, 2.5, 10, 9.6]], ["l", [16, 2.5, 14, 9.6]], ["d", 12, 15, 2]],
	"options": [["l", [4, 7, 6.6, 7]], ["o", 9, 7, 2.4], ["l", [11.4, 7, 20, 7]],
		["l", [4, 12, 12.6, 12]], ["o", 15, 12, 2.4], ["l", [17.4, 12, 20, 12]],
		["l", [4, 17, 8.6, 17]], ["o", 11, 17, 2.4], ["l", [13.4, 17, 20, 17]]],
	"quit": [["l", [15, 8, 15, 3, 5, 3, 5, 21, 15, 21, 15, 16]], ["l", [10, 12, 21, 12]], ["l", [18, 9, 21, 12, 18, 15]]],
	"dev": [["r", 3, 5, 18, 14, 2], ["l", [7, 10, 10, 12, 7, 14]], ["l", [12, 14.5, 16, 14.5]]],
	"play": [["f", [8, 5, 19, 12, 8, 19]]],
	"clock": [["o", 12, 12, 8.5], ["l", [12, 7, 12, 12, 15.5, 14]]],
	"mark": [["c", [2, 12, 6, 8, 12, 6.2, 18, 8, 22, 12, 18, 16, 12, 17.8, 6, 16]], ["o", 12, 12, 3.4], ["d", 12, 12, 1.4]],
	"flame": [["c", [12, 2.5, 15.5, 7.5, 17.5, 12.5, 16, 18, 12, 21, 8, 18, 6.5, 13, 8.5, 9, 10.5, 11.5]]],
	"lock": [["r", 6, 11, 12, 10, 2], ["l", [8, 11, 8, 8]], ["a", 12, 8, 4, 180, 360], ["l", [16, 8, 16, 11]]],
	"check": [["l", [5, 12.5, 10, 17, 19, 7]]],
	"pin": [["c", [12, 21, 7, 13, 6.2, 9.5, 8, 5.5, 12, 3.8, 16, 5.5, 17.8, 9.5, 17, 13]], ["d", 12, 9.5, 2.2]],
	"skull": [["c", [6, 15, 5, 10, 7, 5.5, 12, 3.5, 17, 5.5, 19, 10, 18, 15, 16, 16, 16, 20, 8, 20, 8, 16]],
		["d", 9.5, 11, 2], ["d", 14.5, 11, 2]],
	"bullet": [["c", [9, 21, 9, 9, 10, 5, 12, 2.5, 14, 5, 15, 9, 15, 21]], ["l", [9, 17, 15, 17]]],
	"heart": [["f", [12, 20, 4.5, 12.5, 3.5, 8, 5.5, 5, 9, 4.5, 12, 7.5, 15, 4.5, 18.5, 5, 20.5, 8, 19.5, 12.5]]],
	"run": [["d", 14, 4.5, 2.2], ["l", [8, 10, 12, 8, 15, 11, 13, 15, 16, 20]], ["l", [13, 15, 9, 17, 6, 21]],
		["l", [15, 11, 19, 12]]],
	"key": [["o", 7.5, 12, 4.5], ["l", [12, 12, 21, 12, 21, 15]], ["l", [17.5, 12, 17.5, 14.5]]],
	# weapons, drawn side-on facing right
	"revolver": [["c", [3, 8, 21, 8, 21, 11, 13.5, 11, 12.5, 13, 10.5, 13, 8.5, 19.5, 4.5, 19.5, 6.5, 12, 3, 11]],
		["a", 11.5, 13, 1.8, 0, 180]],
	"flare": [["c", [4, 8, 17, 8, 17, 7, 20.5, 7, 20.5, 13, 17, 13, 17, 12, 12, 12, 11, 14, 9, 19.5, 5, 19.5, 7, 13, 4, 12]]],
	"shotgun": [["c", [1, 10, 21, 10, 23, 10.5, 23, 12.5, 10, 12.5, 9, 14, 6, 15, 2.5, 17.5, 1, 16.5, 3, 13.5, 1, 12.5]],
		["l", [12, 12.5, 12, 14, 18, 14, 18, 12.5]]],
	"bow": [["a", 3, 12, 11, 305, 415], ["l", [9.3, 3, 9.3, 21]], ["l", [5, 12, 21.5, 12]], ["l", [18.5, 9.5, 21.5, 12, 18.5, 14.5]]],
	"axe": [["l", [5, 21.5, 15.5, 4.5]], ["c", [12, 4, 19.5, 1.5, 21.5, 8.5, 15, 9.2]]],
	"bat": [["c", [3, 19.5, 4.5, 21, 21.5, 7, 19, 3]], ["l", [17, 4.2, 15.6, 2]], ["l", [20, 7.2, 22.2, 5.6]],
		["l", [18.8, 5.5, 20.5, 3]]],
	"fists": [["r", 5, 8, 14, 11, 3], ["l", [8.5, 8, 8.5, 12]], ["l", [12, 8, 12, 12]], ["l", [15.5, 8, 15.5, 12]],
		["l", [5, 13, 9, 13]]],
	"bottle": [["c", [10, 3, 14, 3, 14, 8, 16.5, 11, 16.5, 21, 7.5, 21, 7.5, 11, 10, 8]], ["l", [7.5, 14, 16.5, 14]]],
	"smoke": [["r", 7, 7, 10, 14, 3], ["l", [10, 7, 10, 4, 14, 4, 14, 7]], ["l", [7, 12, 17, 12]]],
	"token": [["o", 12, 12, 8.5], ["c", [12, 7, 14.2, 10.5, 13.6, 14, 12, 16.5, 10.4, 14, 9.8, 10.5]]],
	"jacket": [["c", [8, 3.5, 12, 6, 16, 3.5, 20.5, 6.5, 21.5, 20.5, 17.5, 20.5, 17, 11, 16.5, 20.5, 7.5, 20.5, 7, 11, 6.5, 20.5,
		2.5, 20.5, 3.5, 6.5]], ["l", [12, 6, 12, 20.5]]],
	"tea": [["r", 5, 9, 11, 11, 3], ["a", 17, 13.5, 2.6, 270, 450], ["l", [8, 6.5, 8.5, 4.5]], ["l", [12, 6.5, 12.5, 4.5]]],
}


static func draw(ci: CanvasItem, id: String, at: Vector2, size: float, col: Color, width := -1.0) -> void:
	## Draws icon `id` centred on `at`, `size` units across. width < 0: the set's stroke (2 units on the grid).
	var cmds: Array = SET.get(id, [])
	var k := size / 24.0
	var o := at - Vector2(12, 12) * k
	var w := (2.0 * k) if width < 0.0 else width
	w = maxf(w, 1.0)
	for c: Array in cmds:
		match c[0]:
			"l", "c", "f":
				var pts := _pts(c[1], o, k)
				if c[0] == "f":
					ci.draw_colored_polygon(pts, col)
				else:
					if c[0] == "c":
						pts.append(pts[0])
					ci.draw_polyline(pts, col, w, true)
			"o":
				ci.draw_arc(o + Vector2(c[1], c[2]) * k, c[3] * k, 0.0, TAU, 32, col, w, true)
			"d":
				ci.draw_circle(o + Vector2(c[1], c[2]) * k, c[3] * k, col, true, -1.0, true)
			"a":
				ci.draw_arc(o + Vector2(c[1], c[2]) * k, c[3] * k, deg_to_rad(c[4]), deg_to_rad(c[5]), 24, col, w, true)
			"r":
				var r := Rect2(o + Vector2(c[1], c[2]) * k, Vector2(c[3], c[4]) * k)
				ci.draw_polyline(round_rect(r, c[5] * k), col, w, true)


static func round_rect(r: Rect2, rad: float, closed := true) -> PackedVector2Array:
	## A rounded rectangle's outline as points (closed: the first point repeated at the end).
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad),
		Vector2(r.position.x + rad, r.end.y - rad), r.position + Vector2(rad, rad)]
	for i in 4:
		for s in 5:
			var a := -PI / 2 + i * PI / 2 + s * (PI / 2) / 4.0
			pts.append(cs[i] + Vector2(cos(a), sin(a)) * rad)
	if closed:
		pts.append(pts[0])
	return pts


static func fill_round(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	## A filled rounded rectangle.
	ci.draw_colored_polygon(round_rect(r, rad, false), col)


static func _pts(flat: Array, o: Vector2, k: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		pts.append(o + Vector2(flat[i], flat[i + 1]) * k)
	return pts
