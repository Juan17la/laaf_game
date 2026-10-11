class_name ThreatArcs
extends Control
## Off-screen threat arcs: a short arc at the screen edge toward every enemy that is onto Alex but out of the
## camera's view. Amber while it's noticing / suspicious / searching (brighter the surer it is), red while it
## hunts him. Values: scripts/feel.gd (ARC_*). Owned by the HUD (hud.gd); hidden in cinematics.

const STEPS := 7  ## segments per arc
const PULSE_HZ := 5.0  ## a hunting enemy's arc throbs

var player: Node
var _t := 0.0


func setup(p: Node) -> void:
	player = p
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func threats() -> Array:
	## [[direction on screen (unit, +y down), colour], ...] for every enemy onto Alex and off-screen.
	var out := []
	var cam := get_viewport().get_camera_3d()
	if not cam or not player or not Feel.threat_arcs:
		return out
	var view := get_viewport_rect()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.state in [Enemy.State.DEAD, Enemy.State.DOWN, Enemy.State.STUNNED] \
				or not e.is_physics_processing():
			continue
		var hunting: bool = e.state == Enemy.State.CHASE
		var level: float = 1.0 if hunting else (maxf(e.awareness, 0.5) if e.state in [Enemy.State.SUSPICIOUS,
			Enemy.State.SEARCH] else e.awareness)
		if level <= 0.02:
			continue
		var at: Vector3 = e.global_position + Vector3.UP * 1.2
		if not cam.is_position_behind(at) and view.grow(-Feel.ARC_MARGIN).has_point(cam.unproject_position(at)):
			continue  # on screen: its icon says it
		var local: Vector3 = cam.global_transform.affine_inverse() * at
		var dir := Vector2(local.x, local.z)  # ahead (-z) is up the screen
		if dir.length() < 0.01:
			continue
		var col := Feel.ALERT_RED if hunting else Feel.AMBER
		var a := level * (0.75 + 0.25 * sin(_t * TAU * PULSE_HZ)) if hunting else 0.35 + 0.55 * level
		out.append([dir.normalized(), Color(col, a)])
	return out


func _draw() -> void:
	var r := get_rect().size
	var c := r * 0.5
	var radii := c - Vector2.ONE * Feel.ARC_MARGIN
	for th in threats():
		var d: Vector2 = th[0]
		var ang := atan2(d.x, -d.y)
		var pts := PackedVector2Array()
		for i in STEPS + 1:
			var a := ang - Feel.ARC_SPAN * 0.5 + Feel.ARC_SPAN * i / STEPS
			pts.append(c + Vector2(sin(a) * radii.x, -cos(a) * radii.y))
		draw_polyline(pts, Color(0, 0, 0, th[1].a * 0.6), Feel.ARC_WIDTH + 2.0)
		draw_polyline(pts, th[1], Feel.ARC_WIDTH)
