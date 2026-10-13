class_name Apparition
extends Node3D
## The Mark's sightings (Feel.APPARITION_*): the Harvester — its real model, red eyes in the dark — standing still
## 20-40 m off, to one side of where Alex looks (never on his path), somewhere dark that he has a clear line to.
## It stays a second or two with a faint whisper, and is gone sooner if he looks straight at it or walks toward
## it, or the moment he isn't in control / something starts hunting him. No collision, no group, no gameplay:
## atmosphere only. Started by ScreenFx (the Mark, Feel.hallucinations); try_spawn() returns null when no spot fits.

const MODEL := "res://models/char_boss.glb"
const TRIES := 24
const HEIGHT := 2.8  ## m (its capsule as an enemy: the spot must fit it)
const RADIUS := 0.6
const EYES_Y := 2.6
const CHEST_Y := 1.6
const EYE_POS := [Vector3(-0.06, 2.55, 0.3), Vector3(0.06, 2.55, 0.3)]  ## model space, just in front of the face
const EYE_PX := 2.0  ## each eye is this many screen pixels at any distance (the model's own are sub-pixel at 30 m)
const MAX_RISE := 0.6  ## m above Alex's feet: on the ground he walks, never up on a porch roof or a wall
const WATER_Y := -0.3
const SCREEN_MARGIN := 0.08  ## fraction of the view kept clear at each edge: it stands inside the picture

var player: Node3D
var _actor: Actor
var _life := 0.0
var _start_dist := 0.0


static func try_spawn(p: Node3D) -> Apparition:
	var cam: Camera3D = p.get("camera")
	if not cam:
		return null
	var at := find_spot(p, cam)
	if at == Vector3.INF:
		return null
	var a := Apparition.new()
	a.player = p
	p.get_parent().add_child(a)
	a._show_at(at)
	return a


static func find_spot(p: Node3D, cam: Camera3D) -> Vector3:
	## A dark, open, visible patch of ground off to the side of the view, or INF.
	var space := p.get_world_3d().direct_space_state
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return Vector3.INF
	fwd = fwd.normalized()
	var lights := _lights(p.get_parent())
	for i in TRIES:
		var side := randf_range(Feel.APPARITION_SIDE.x, Feel.APPARITION_SIDE.y) * (1.0 if randf() < 0.5 else -1.0)
		var dir := fwd.rotated(Vector3.UP, deg_to_rad(side))
		var want := p.global_position + dir * randf_range(Feel.APPARITION_DIST.x, Feel.APPARITION_DIST.y)
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(want + Vector3.UP * 20.0,
			want + Vector3.DOWN * 20.0, 1, [p.get_rid()]))
		if down.is_empty() or (down.normal as Vector3).y < 0.8:
			continue
		var g: Vector3 = down.position
		if g.y > p.global_position.y + MAX_RISE or g.y < WATER_Y:
			continue
		var q := PhysicsShapeQueryParameters3D.new()  # room to stand (not in a wall, a tree, a car)
		var cap := CapsuleShape3D.new()
		cap.radius = RADIUS
		cap.height = HEIGHT
		q.shape = cap
		q.transform = Transform3D(Basis(), g + Vector3.UP * (HEIGHT * 0.5 + 0.05))
		q.collision_mask = 1
		if not space.intersect_shape(q, 1).is_empty():
			continue
		var head := g + Vector3.UP * EYES_Y
		if not _in_view(cam, head) or not _in_view(cam, g):
			continue  # (the view is wider / narrower than the angles: check the picture itself)
		var seen := true
		for at in [head, g + Vector3.UP * CHEST_Y]:  # its head and chest in clear view, not just a peeking head
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, at, 1,
					[p.get_rid()])).is_empty():
				seen = false
		if not seen:
			continue
		if _lit(head, lights) or _lit(g + Vector3.UP, lights):
			continue
		return g
	return Vector3.INF


static func _in_view(cam: Camera3D, at: Vector3) -> bool:
	if cam.is_position_behind(at):
		return false
	var view := cam.get_viewport().get_visible_rect()
	var p := cam.unproject_position(at)
	return view.grow_individual(-view.size.x * SCREEN_MARGIN, -view.size.y * SCREEN_MARGIN,
		-view.size.x * SCREEN_MARGIN, -view.size.y * SCREEN_MARGIN).has_point(p)


static func _lights(world: Node) -> Array:
	var out := []
	for l in world.find_children("*", "Light3D", true, false):
		if l is OmniLight3D or l is SpotLight3D:
			out.append(l)
	return out


static func _lit(at: Vector3, lights: Array) -> bool:
	for l in lights:
		if not is_instance_valid(l) or not l.is_visible_in_tree() or l.light_energy < Feel.APPARITION_DARK:
			continue
		var r: float = l.omni_range if l is OmniLight3D else l.spot_range
		if l.global_position.distance_to(at) < r:
			return true
	return false


func _show_at(at: Vector3) -> void:
	global_position = at
	var to := player.global_position - at
	_actor = Actor.make(self, MODEL, at, atan2(to.x, to.z))  # facing Alex
	var eyes := OmniLight3D.new()  # the red lenses, the only thing that really reads in the dark
	eyes.light_color = Color(1.0, 0.1, 0.05)
	eyes.light_energy = 1.2
	eyes.omni_range = 2.0
	eyes.position = Vector3(0, EYES_Y, 0.35)
	_actor.model.add_child(eyes)
	for p in EYE_POS:  # two red points that cut through the fog
		_actor.model.add_child(_eye(p))
	_cut_out(_actor.model)
	_life = randf_range(Feel.APPARITION_TIME.x, Feel.APPARITION_TIME.y)
	_start_dist = player.global_position.distance_to(at)
	Snd.sfx("whisper", at + Vector3.UP * EYES_Y, Feel.APPARITION_DB, 0.7, "Voice")


static func _cut_out(model: Node3D) -> void:
	## Fog doesn't touch it: a black shape against the grey murk, where the real thing would have melted into it.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m:
				var c := m.duplicate() as BaseMaterial3D
				c.disable_fog = true
				mi.set_surface_override_material(i, c)


static func _eye(at: Vector3) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Feel.ALERT_RED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.fixed_size = true
	m.disable_fog = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE * Interactable.PX * EYE_PX
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or not is_instance_valid(player) or not player.get("controls_enabled") or _seen() \
			or player.global_position.distance_to(global_position) < _start_dist - Feel.APPARITION_CLOSER \
			or _hunted():
		queue_free()


func _seen() -> bool:
	## Looked at straight on: it isn't there any more.
	var cam: Camera3D = player.get("camera")
	if not cam:
		return false
	var to := global_position + Vector3.UP * EYES_Y - cam.global_position
	return rad_to_deg((-cam.global_basis.z).angle_to(to)) < Feel.APPARITION_LOOK


func _hunted() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.state == Enemy.State.CHASE and e.is_physics_processing():
			return true
	return false
