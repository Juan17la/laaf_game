class_name AlertIcon
extends Node3D
## The enemy's state over its head, PS2-style pixel glyphs made here (no font): an amber "?" while it's noticing
## Alex (a meter under it fills with Enemy.awareness) or suspicious / searching, a red "!" that pops in with a
## sting when it spots him and stays up Feel.ICON_ALERT_HOLD s. Nothing while stunned, down or dead, in a
## cinematic, or further than Feel.ICON_SHOW_DIST. Rides over the model's head (crouched, kneeling, any height of
## character). Drawn over its owner and the clutter round it (no depth test), but not through the world: hidden
## while a wall stands between the camera and it. Added by Enemy._ready.

const QUESTION := [
	".#####.",
	"##...##",
	"##...##",
	".....##",
	"....##.",
	"...##..",
	"...##..",
	".......",
	"...##..",
	"...##..",
]
const BANG := [
	"..###..",
	"..###..",
	"..###..",
	"..###..",
	"..###..",
	"...#...",
	".......",
	"..###..",
	"..###..",
	".......",
]
const HEAD_TOP := 0.18  ## m from the Head joint up to where the capsule top is on the cast (ICON_GAP is measured from there)
const SIGHT_STEP := 0.15  ## s between checks that the camera can see it
const METER_W := 9  ## glyph pixels
const METER_H := 2

static var _tex := {}
static var _last_sting := -99.0

var _e: Enemy
var _glyph: Sprite3D
var _meter_back: Sprite3D
var _meter: Sprite3D
var _shown := ""  ## "", "?" or "!"
var _pop: Tween
var _head: Node3D  ## the model's Head joint, when the rig has one
var _hidden := false  ## the camera's view of it is blocked by the world (a wall, a floor)
var _sight_t := 0.0


func _ready() -> void:
	_e = get_parent() as Enemy
	var head := 1.8
	for c in _e.get_children():
		if c is CollisionShape3D and c.shape is CapsuleShape3D:
			head = c.position.y + (c.shape as CapsuleShape3D).height * 0.5
	position.y = head + Feel.ICON_GAP
	var model := _e.get_node_or_null("Model")
	if model:
		_head = model.find_child("Head", true, false) as Node3D
	_glyph = _sprite(_texture("?"), 0, 10)
	_meter_back = _sprite(_texture("meter"), -9, 9)  # the meter's empty track, under its fill
	_meter_back.modulate = Color(0.35, 0.3, 0.25, 0.9)
	_meter = _sprite(_texture("meter"), -9, 11)
	_meter.modulate = Feel.AMBER.lightened(0.2)
	visible = false


func _sprite(tex: Texture2D, dy: int, priority: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = Interactable.PX * Feel.ICON_PX
	s.fixed_size = true
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.render_priority = priority
	s.offset = Vector2(0, dy)
	add_child(s)
	return s


static func _texture(kind: String) -> Texture2D:
	## White glyph with a 1 px dark outline (tinted by modulate, the outline stays dark).
	if _tex.has(kind):
		return _tex[kind]
	var rows: Array = QUESTION if kind == "?" else BANG
	if kind == "meter":
		rows = []
		for i in METER_H:
			rows.append("#".repeat(METER_W))
	var w: int = (rows[0] as String).length() + 2
	var h: int = rows.size() + 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		for x in (rows[y] as String).length():
			if rows[y][x] == "#":
				for oy in [-1, 0, 1]:
					for ox in [-1, 0, 1]:
						if img.get_pixel(x + 1 + ox, y + 1 + oy).a == 0.0:
							img.set_pixel(x + 1 + ox, y + 1 + oy, Color(0.05, 0.03, 0.02, 0.9))
	for y in rows.size():
		for x in (rows[y] as String).length():
			if rows[y][x] == "#":
				img.set_pixel(x + 1, y + 1, Color.WHITE)
	_tex[kind] = ImageTexture.create_from_image(img)
	return _tex[kind]


func _process(delta: float) -> void:
	var want := _want()
	if want != _shown:
		_show(want)
	if _head and _shown != "":  # over the head as it is now, not the capsule's top: it never drifts off the body
		global_position = _head.global_position + Vector3.UP * (HEAD_TOP + Feel.ICON_GAP)
	_sight_t -= delta
	if _shown != "" and _sight_t <= 0.0:
		_sight_t = SIGHT_STEP
		_hidden = _blocked()
	visible = _shown != "" and not _hidden
	if want == "?":
		var a := clampf(_e.awareness, 0.0, 1.0)
		_meter.scale.x = maxf(a, 0.001)
		_meter.visible = a > 0.0  # (the empty track stays: "it's looking, not sure yet")
		_glyph.modulate.a = 0.55 + 0.45 * a if _e.state == Enemy.State.PATROL else 1.0  # firmer once it's looking


func _blocked() -> bool:
	## World geometry (layer 1) between the camera and the icon; the player and the enemy itself don't count.
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if not cam:
		return false
	var to := global_position
	var exclude: Array[RID] = [_e.get_rid()]
	if _e._player is CollisionObject3D:
		exclude.append((_e._player as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, to, 1, exclude)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _want() -> String:
	var p: Node3D = _e._player
	if not Feel.detection_icons or not p or not bool(p.get("controls_enabled")) \
			or _e.state in [Enemy.State.STUNNED, Enemy.State.DOWN, Enemy.State.DEAD] \
			or not _e.is_physics_processing() or p.global_position.distance_to(_e.global_position) > Feel.ICON_SHOW_DIST:
		return ""
	if _e.state == Enemy.State.CHASE:
		return "!" if _e.spotted_t < Feel.ICON_ALERT_HOLD else ""
	if not _e.question_icon:
		return ""
	if _e.state in [Enemy.State.SUSPICIOUS, Enemy.State.SEARCH] or _e.awareness > 0.02:
		return "?"
	return ""


func _show(kind: String) -> void:
	_shown = kind
	visible = kind != "" and not _hidden
	if kind == "":
		return
	_sight_t = 0.0  # check the view at once: a new icon never flashes up through a wall
	_glyph.texture = _texture(kind)
	_glyph.modulate = Feel.ALERT_RED if kind == "!" else Feel.AMBER
	_meter.visible = kind == "?"
	_meter_back.visible = kind == "?"
	if kind == "!":
		if _pop:
			_pop.kill()
		_glyph.scale = Vector3.ONE * Feel.ICON_POP
		_pop = create_tween()
		_pop.tween_property(_glyph, "scale", Vector3.ONE, Feel.ICON_POP_TIME).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_sting > Feel.SPOT_GAP:
			_last_sting = now
			Snd.sfx("spotted", null, Feel.SPOT_DB, Feel.pitch())
