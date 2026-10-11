class_name HudEyes
extends Control
## Alex's eye on the HUD, by the health bar (no font, hard pixels like the rest of it): how visible he is
## (player.visibility()): shut = hidden, half = crouched, open = seen, glowing = the flashlight on.
## (The Mark has no gauge of its own any more: the HUD flashes "MARK +N%" when it rises, the pause menu shows it.)
## Owned by the HUD (hud.gd); hidden in cinematics.

const SEE_X := 136.0  ## px from the left: just right of the health bar
const SEE_BOTTOM := 26.0  ## px from the bottom
const SEE_W := 8.0
const SEE_H := 4.5
const EASE := 6.0  ## how fast the eye follows its value (per s)
const BONE := Color(0.82, 0.77, 0.62)
const LID := Color(0.08, 0.05, 0.04, 0.9)

var player: Node
var _see := 1.0
var _glow := 0.0


func setup(p: Node) -> void:
	player = p
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not player:
		return
	var k := minf(EASE * delta, 1.0)
	var v: float = player.visibility()
	_see = lerpf(_see, clampf(v, 0.0, 1.0), k)
	var fl: Node3D = player.get("flashlight")
	_glow = lerpf(_glow, 1.0 if fl and fl.visible and v > 0.0 else 0.0, k)
	queue_redraw()


func _draw() -> void:
	if player and Feel.visibility_eye:
		_see_eye(Vector2(SEE_X, get_rect().size.y - SEE_BOTTOM))


func _see_eye(c: Vector2) -> void:
	var col := BONE.lerp(Color(1.0, 0.95, 0.6), _glow)
	if _glow > 0.05:  # the flashlight: it shines
		for i in 5:
			var ang := -PI * 0.15 - PI * 0.7 * i / 4.0
			var d := Vector2(cos(ang), sin(ang))
			draw_line(c + d * (SEE_W + 1.5), c + d * (SEE_W + 3.5), Color(1.0, 0.9, 0.5, _glow), 1.0)
	if _see < 0.08:  # hidden: the lid's shut, lashes down
		var pts := _lid(c, SEE_W, SEE_H * 0.5, 1.0)
		draw_polyline(pts, Color(col, 0.7), 1.0)
		for x in [-0.5, 0.0, 0.5]:
			var p := c + Vector2(x * SEE_W, SEE_H * 0.5 * (1.0 - x * x))
			draw_line(p, p + Vector2(x * 1.5, 2.0), Color(col, 0.7), 1.0)
		return
	almond_eye(self, c, SEE_W, SEE_H, _see, col.darkened(0.3), LID, false, col)


static func almond_eye(canvas: CanvasItem, c: Vector2, w: float, h: float, open: float, iris: Color, fill: Color,
		rays: bool, white := Color(0, 0, 0, 0)) -> void:
	## The almond eye: lids, the white (if given), an iris and a slit pupil, optional painted rays over the top lid.
	var top := _lid(c, w, -h * open, 1.0)
	var bottom := _lid(c, w, h * open * 0.8, 1.0)
	var shape := PackedVector2Array(top)
	for i in range(bottom.size() - 2, 0, -1):
		shape.append(bottom[i])
	if shape.size() >= 3 and h * open >= 1.0:  # thinner than a pixel: just the lids (no degenerate fill)
		canvas.draw_colored_polygon(shape, fill)
		if white.a > 0.0:
			canvas.draw_colored_polygon(_shrink(shape, c, 0.8), Color(white, white.a * 0.35))
		var ir := minf(h * open * 0.85, w * 0.45)
		canvas.draw_circle(c, ir, iris)
		canvas.draw_rect(Rect2(c - Vector2(0.75, ir * 0.85), Vector2(1.5, ir * 1.7)), Color(0.02, 0.0, 0.0, iris.a))
	var line := Color(white if white.a > 0.0 else iris, maxf(iris.a, 0.0))
	canvas.draw_polyline(top, line, 1.0)
	canvas.draw_polyline(bottom, line, 1.0)
	if rays:
		for i in 5:
			var x := (i - 2) / 2.0 * 0.7
			var base := c + Vector2(x * w, -h * open * (1.0 - x * x) - 1.0)
			canvas.draw_line(base, base + Vector2(x * 3.0, -2.5 - 1.5 * (1.0 - absf(x))), Color(iris, iris.a * 0.85), 1.0)


static func _lid(c: Vector2, w: float, dy: float, _k: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 9:
		var x := -1.0 + 2.0 * i / 8.0
		pts.append(c + Vector2(x * w, dy * (1.0 - x * x)))
	return pts


static func _shrink(pts: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k)
	return out
