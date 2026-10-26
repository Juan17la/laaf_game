extends CanvasLayer
## Navigation aids: minimap, full map (M / Back), compass and objective waypoint. HUD.objective() calls
## set_target(target, text) with a Vector3, a Node3D (follows it) or null (no waypoint).
## Everything hides while player.controls_enabled is false (cinematics).
## Zone names and the panel's words are English ids, drawn through tr() every frame (a language switch shows at once).

## maps/hollowmere_map.png is made by tools/map_image.py: square, north (-Z) up,
## px = (x - MAP_X0) * PPM, py = (z - MAP_Z0) * PPM. Keep these in sync with that script.
const MAP_TEX := preload("res://maps/hollowmere_map.png")
const MAP_X0 := -217.5
const MAP_Z0 := -220.0
const PPM := 2.0
const MAP_PX := 810.0
## Zone rects (x0, z0, x1, z1) as placed by tools/build_assets.py build_world().
const ZONES := [
	["Town Square", -35, -35, 35, 35], ["Lakeview Motel", -135, 40, -75, 105],
	["Pinewood Forest & Sawmill", -165, -70, -75, 45], ["Church & Cemetery", -113, -145, -45, -58],
	["St. Agnes Clinic", 44, -130, 110, -70], ["Hollowmere Elementary", 78, -35, 135, 45],
	["Harbor & Lighthouse", -70, 90, 40, 150], ["Collapsed Bridge", -125, 128, -75, 190],
	["Quarry & Veil's Chapel", -50, -225, 50, -145],
]
const MINI_R := 42.0  # minimap radius, px
const MINI_M := 55.0  # world metres from centre to rim
const INK := Color(0.1, 0.08, 0.06)
const PAPER := Color(0.86, 0.8, 0.66)
const MARK := Color(0.95, 0.72, 0.25)  # objective colour
const MINI_SHADER := """
shader_type canvas_item;
uniform sampler2D map : filter_nearest, repeat_disable;
uniform vec2 center;
uniform float angle;
uniform float span;
void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p);
	if (d > 0.5) discard;
	vec2 q = vec2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
	vec3 c = texture(map, center + q * span).rgb * 0.85;
	COLOR = vec4(mix(c, vec3(0.08, 0.06, 0.05), smoothstep(0.42, 0.5, d)), 0.92);
}
"""

var target: Variant = null
var text := ""
var map_open := false

@onready var player: Node = get_parent()
var _mini: ColorRect
var _canvas: Control
var _panel: Label
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	_mini = ColorRect.new()
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.size = Vector2.ONE * MINI_R * 2
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = MINI_SHADER
	mat.set_shader_parameter("map", MAP_TEX)
	mat.set_shader_parameter("span", MINI_M * 2 * PPM / MAP_PX)
	_mini.material = mat
	add_child(_mini)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)
	_panel = Label.new()
	_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_theme_font_size_override("font_size", 10)
	_panel.add_theme_color_override("font_color", PAPER)
	_panel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_panel.add_theme_constant_override("outline_size", 3)
	_panel.visible = false
	add_child(_panel)


func set_target(t: Variant, objective_text: String) -> void:
	target = t
	text = objective_text


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and (map_open or player.controls_enabled):
		map_open = not map_open
		get_viewport().set_input_as_handled()
	elif map_open and event.is_action_pressed("pause"):
		map_open = false
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var on: bool = player.controls_enabled
	if not on:
		map_open = false
	var view := _canvas.size
	_mini.visible = on and not map_open
	_mini.position = Vector2(view.x - 10 - MINI_R * 2, 8)  # the Mark meter and clock sit under it (hud.gd)
	_mini.material.set_shader_parameter("center", _to_uv(player.global_position))
	_mini.material.set_shader_parameter("angle", -_yaw())
	_panel.visible = map_open
	_canvas.visible = on
	_canvas.queue_redraw()


func _yaw() -> float:
	return player.pivot.global_rotation.y


func _to_uv(p: Vector3) -> Vector2:
	return Vector2(p.x - MAP_X0, p.z - MAP_Z0) * PPM / MAP_PX


func _goal() -> Variant:
	## Objective world position (waypoint height included), or null.
	if typeof(target) == TYPE_OBJECT:
		return target.global_position + Vector3.UP * 2.1 if is_instance_valid(target) and target is Node3D else null
	return target + Vector3.UP * 0.5 if target is Vector3 else null


func _facing() -> Vector2:
	## Player body facing as a map vector (x, z); the model faces +Z at yaw 0.
	var m: float = player.model.global_rotation.y
	return Vector2(sin(m), cos(m))


func _draw_all() -> void:
	var goal: Variant = _goal()
	if map_open:
		_draw_map(goal)
		return
	_draw_minimap(goal)
	var hud := player.get_node_or_null("HUD")
	if not (hud and hud._boss and hud._boss.visible):  # the boss bar sits in the same spot
		_draw_compass(goal)
	if goal != null:
		_draw_waypoint(goal)


func _arrow(c: Control, at: Vector2, dir: Vector2, s: float, col: Color) -> void:
	var side := dir.orthogonal()
	var pts := PackedVector2Array([at + dir * s, at - dir * s * 0.7 + side * s * 0.7, at - dir * s * 0.3,
		at - dir * s * 0.7 - side * s * 0.7])
	c.draw_colored_polygon(pts, INK)
	c.draw_colored_polygon(PackedVector2Array([at + dir * s * 0.7, at - dir * s * 0.45 + side * s * 0.45,
		at - dir * s * 0.2, at - dir * s * 0.45 - side * s * 0.45]), col)


func _diamond(c: Control, at: Vector2, s: float) -> void:
	var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
	s *= pulse
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s - 1.5), at + Vector2(s + 1.5, 0),
		at + Vector2(0, s + 1.5), at + Vector2(-s - 1.5, 0)]), INK)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s),
		at + Vector2(-s, 0)]), MARK)


func _text(c: Control, at: Vector2, s: String, size: int, col: Color, width := -1.0, rim := Color(0, 0, 0, 0.85)) -> void:
	## Centred on at.x when width > 0 (at.x is then the left edge minus width / 2).
	var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0 else HORIZONTAL_ALIGNMENT_LEFT
	var p := at - Vector2(width / 2 if width > 0 else 0.0, 0)
	c.draw_string_outline(_font, p, s, align, width, size, 3, rim)
	c.draw_string(_font, p, s, align, width, size, col)


func _dist(goal: Vector3) -> String:
	var p: Vector3 = player.global_position
	return "%dm" % roundi(Vector2(goal.x - p.x, goal.z - p.z).length())


func _draw_minimap(goal: Variant) -> void:
	var c := _canvas
	var ctr := _mini.position + Vector2.ONE * MINI_R
	var yaw := _yaw()
	var k := MINI_R / MINI_M
	c.draw_arc(ctr, MINI_R, 0, TAU, 48, INK, 2.0)
	c.draw_arc(ctr, MINI_R - 1.5, 0, TAU, 48, Color(PAPER, 0.35), 1.0)
	var n := Vector2(0, -1).rotated(yaw) * (MINI_R - 6)
	_text(c, ctr + n + Vector2(0, 4), "N", 9, Color(0.85, 0.3, 0.25), 12)
	if goal != null:
		var d := Vector2(goal.x - player.global_position.x, goal.z - player.global_position.z).rotated(yaw) * k
		if d.length() > MINI_R - 5:
			d = d.normalized() * (MINI_R - 5)
		_diamond(c, ctr + d, 3.5)
	_arrow(c, ctr, _facing().rotated(yaw), 7.0, Color(0.95, 0.3, 0.22))


func _draw_compass(goal: Variant) -> void:
	var c := _canvas
	const HALF_W := 110.0
	const HALF_A := PI / 2  # half of the visible arc
	var cx := c.size.x / 2
	var y := 28.0  # below the HUD objective line (y 10..24)
	var heading := -_yaw()  # bearing the camera looks along: 0 = north (-Z), PI/2 = east (+X)
	c.draw_rect(Rect2(cx - HALF_W, y, HALF_W * 2, 14), Color(0, 0, 0, 0.45))
	c.draw_line(Vector2(cx - HALF_W, y + 14), Vector2(cx + HALF_W, y + 14), Color(PAPER, 0.4))
	for i in 24:
		var rel := wrapf(i * TAU / 24 - heading, -PI, PI)
		if absf(rel) > HALF_A:
			continue
		var x := cx + rel / HALF_A * HALF_W
		if i % 6 == 0:
			_text(c, Vector2(x, y + 11), _bearings()[int(i / 6.0)], 10, Color(0.9, 0.35, 0.28) if i == 0 else PAPER, 14)
		else:
			c.draw_line(Vector2(x, y + (8 if i % 3 == 0 else 10)), Vector2(x, y + 14), Color(PAPER, 0.6))
	c.draw_line(Vector2(cx, y - 2), Vector2(cx, y + 2), PAPER, 1.0)
	if goal != null:
		var p: Vector3 = player.global_position
		var rel := wrapf(atan2(goal.x - p.x, -(goal.z - p.z)) - heading, -PI, PI)
		var x := cx + clampf(rel / HALF_A, -1, 1) * HALF_W
		if absf(rel) > HALF_A:
			_arrow(c, Vector2(x - signf(rel) * 6, y + 7), Vector2(signf(rel), 0), 5.0, MARK)
		else:
			_diamond(c, Vector2(x, y + 7), 3.5)
		_text(c, Vector2(x, y + 25), _dist(goal), 9, MARK, 40)


func _bearings() -> String:
	## N E S W as the language writes them (four letters: Spanish's west is O).
	var b := tr("NESW")
	return b if b.length() == 4 else "NESW"


func _draw_waypoint(goal: Vector3) -> void:
	var c := _canvas
	var cam: Camera3D = player.camera
	var p: Vector3 = player.global_position
	if cam.is_position_behind(goal) or Vector2(goal.x - p.x, goal.z - p.z).length() < 2.5:
		return
	var s := cam.unproject_position(goal)
	var rect := Rect2(Vector2(14, 62), c.size - Vector2(28, 100))
	if rect.has_point(s):
		_diamond(c, s, 4.0)
		_text(c, s + Vector2(0, 16), _dist(goal), 9, MARK, 40)
		return
	var ctr := c.size / 2
	var e := Vector2(clampf(s.x, rect.position.x, rect.end.x), clampf(s.y, rect.position.y, rect.end.y))
	_arrow(c, e, (s - ctr).normalized(), 6.0, MARK)
	_text(c, e - (s - ctr).normalized() * 16 + Vector2(0, 3), _dist(goal), 9, MARK, 40)


func _draw_map(goal: Variant) -> void:
	var c := _canvas
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.03, 0.03, 0.03, 0.88))
	var side := minf(c.size.y - 16, c.size.x * 0.6)
	var r := Rect2(Vector2(10, (c.size.y - side) / 2), Vector2(side, side))
	var k := side / (MAP_PX / PPM)  # screen px per metre
	var to_screen := func(x: float, z: float) -> Vector2: return r.position + Vector2(x - MAP_X0, z - MAP_Z0) * k
	c.draw_rect(r.grow(2), INK)
	c.draw_texture_rect(MAP_TEX, r, false)
	c.draw_rect(r.grow(1), Color(PAPER, 0.5), false, 1.0)
	var p: Vector3 = player.global_position
	var here := ""
	for z in ZONES:
		var mid: Vector2 = to_screen.call((z[1] + z[3]) / 2.0, (z[2] + z[4]) / 2.0)
		_zone_label(c, mid + Vector2(0, 3), tr(z[0]).to_upper())
		if p.x > z[1] and p.x < z[3] and p.z > z[2] and p.z < z[4]:
			here = z[0]
	_text(c, r.position + Vector2(side - 14, 16), "N", 11, Color(0.6, 0.12, 0.1), 12)
	c.draw_line(r.position + Vector2(side - 14, 19), r.position + Vector2(side - 14, 30), Color(0.6, 0.12, 0.1), 1.5)
	if goal != null:
		_diamond(c, to_screen.call(goal.x, goal.z), 4.5)
	_arrow(c, to_screen.call(p.x, p.z), _facing(), 6.5, Color(0.95, 0.25, 0.2))
	var px := r.end.x + 14
	_panel.position = Vector2(px, r.position.y + 10)
	_panel.size = Vector2(c.size.x - px - 12, 0)
	_panel.text = tr("HOLLOWMERE\n\n%s\n\nOBJECTIVE\n%s%s\n\n\n[M] close") % [
		tr("You are near: %s") % tr(here) if here != "" else tr("Outside town"), tr(text) if text != "" else "—",
		"\n" + tr("%s away") % _dist(goal) if goal != null else ""]


func _zone_label(c: Control, at: Vector2, s: String) -> void:
	## A zone's name on the paper map, centred on at; one too wide for its 110 px breaks onto a second line.
	if _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x <= 110.0 or not " " in s:
		_text(c, at, s, 8, Color(0.2, 0.12, 0.08), 110, Color(PAPER, 0.8))
		return
	var words := s.split(" ")
	var best := 1
	for i in range(1, words.size()):  # the break that leaves the longer line shortest
		var a := " ".join(words.slice(0, i))
		var b := " ".join(words.slice(i))
		var w := maxf(_font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x,
			_font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		var bw := maxf(_font.get_string_size(" ".join(words.slice(0, best)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x,
			_font.get_string_size(" ".join(words.slice(best)), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		if w < bw:
			best = i
	_text(c, at - Vector2(0, 4.5), " ".join(words.slice(0, best)), 8, Color(0.2, 0.12, 0.08), 110, Color(PAPER, 0.8))
	_text(c, at + Vector2(0, 4.5), " ".join(words.slice(best)), 8, Color(0.2, 0.12, 0.08), 110, Color(PAPER, 0.8))
