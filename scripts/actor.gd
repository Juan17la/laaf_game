class_name Actor
extends Node3D
## A character in a cinematic: model + procedural animation, with blocking helpers.
##   var g := Actor.make(self, "res://models/char_grady.glb", pos, yaw)
##   await g.walk_to(Vector3(...))          # walks, faces the direction, stops
##   g.face(alex.global_position)           # turns in place (not awaited)
##   g.look(alex)                           # head tracks a node (null = straight ahead)
##   g.gesture("point", 1.5)                # body language; see HumanoidAnim.gesture
## Yaw: 0 faces +Z, PI/2 faces +X.

const STEP := 0.35  ## m: the highest step up the feet take while walking (a stair, a kerb, a porch board)

var model: Node3D
var anim: HumanoidAnim
var grounded := true  ## feet stay on whatever floor is under them (skipped while lying down / carried)
var _look_at: Node3D
var _look_point := Vector3.INF
var _stride := 0.0
var _last := Vector3.INF  ## where _ground() left the feet last frame


static func make(parent: Node, scene: String, pos: Vector3, yaw := 0.0) -> Actor:
	var a := Actor.new()
	a.model = load(scene).instantiate()
	a.add_child(a.model)
	if scene.ends_with("char_alex.glb"):  # Alex's stand-in wears his headlamp too (off: the scene lights itself)
		Headlamp.wear(a.model)
	a.anim = HumanoidAnim.new()
	a.model.add_child(a.anim)
	a.anim.model_path = ^".."
	parent.add_child(a)
	a.global_position = pos
	a.model.rotation.y = yaw
	return a


func _process(delta: float) -> void:
	_ground()
	if anim.speed > 0.3 and grounded:  # footfalls: one per stride (the cinematics have no other feet)
		_stride += anim.speed * delta
		if _stride > 1.5 - 0.1 * anim.speed:
			_stride = 0.0
			Snd.step(self, -7.0 if anim.speed < 3.0 else -2.0)
	var p := _look_point
	if _look_at and is_instance_valid(_look_at):
		p = _look_at.global_position + Vector3.UP * 1.55
	if p == Vector3.INF:
		anim.look = anim.look.lerp(Vector2.ZERO, 0.1)
		return
	var to := p - (global_position + Vector3.UP * 1.6)
	var yaw := wrapf(atan2(to.x, to.z) - model.rotation.y, -PI, PI)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	anim.look = anim.look.lerp(Vector2(clampf(yaw, -1.1, 1.1), clampf(-pitch, -0.6, 0.6)), 0.15)


func yaw_to(p: Vector3) -> float:
	var to := p - global_position
	return atan2(to.x, to.z)


func face(p: Vector3, time := 0.4) -> Signal:
	var target := yaw_to(p)
	var from := model.rotation.y
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void: model.rotation.y = lerp_angle(from, target, k), 0.0, 1.0, time)
	return tw.finished


func look(target: Variant) -> void:
	## Head tracks a Node3D or a Vector3 point; null looks straight ahead.
	_look_at = target if target is Node3D else null
	_look_point = target if target is Vector3 else Vector3.INF


func _ground() -> void:
	## Floors inside buildings sit a few cm above the terrain: stand on the one underneath, not in it. Placed
	## somewhere new, the feet find the floor up to 0.7 m over them; walking, they only take a step (STEP): a
	## scripted walk that brushes a car or a crate goes on along the road, never up onto its hood.
	if not grounded or absf(model.rotation.x) > 0.01 or absf(model.rotation.z) > 0.01 or not is_inside_tree():
		_last = Vector3.INF
		return
	var walked := _last != Vector3.INF and Vector2(global_position.x - _last.x, global_position.z - _last.z).length() < 0.5
	var rise := STEP if walked else 0.7
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * rise, global_position + Vector3.DOWN * 0.6, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		global_position.y = hit.position.y
	_last = global_position


func walk_to(p: Vector3, speed := 1.4) -> Signal:
	## Walks over the ground (x / z; the feet follow the floor), facing the way, then stops.
	var d := Vector2(global_position.x - p.x, global_position.z - p.z).length()
	model.rotation.y = yaw_to(p)
	anim.speed = speed
	var tw := create_tween()
	var from := Vector2(global_position.x, global_position.z)
	tw.tween_method(func(t: float) -> void:
		var xz := from.lerp(Vector2(p.x, p.z), t)
		global_position = Vector3(xz.x, global_position.y, xz.y), 0.0, 1.0, maxf(d / speed, 0.05))
	tw.tween_callback(func() -> void: anim.speed = 0.0)
	return tw.finished


func walk_path(points: Array, speed := 1.4) -> void:
	## Coroutine: walk_to each point in turn (round a car's nose, a table's corner). Not awaited, it walks on
	## while the scene goes on; HumanoidAnim.speed stays up until the last leg is done.
	for p in points:
		await walk_to(p, speed)


func run_to(p: Vector3) -> Signal:
	return walk_to(p, 4.5)


static func settle(walk: Signal) -> void:
	## Coroutine: waits out a walk_to / face (or any tween's `finished`) started earlier and awaited only now. It
	## may be over already: its tween is then gone, and awaiting a freed tween's signal ends the caller with an
	## error, the scene never returning (a cinematic soft-lock). A paused tween (pause menu) is still waited for.
	var tw := walk.get_object() as Tween
	if tw and tw.is_valid():
		await walk


func gesture(g: String, hold := -1.0) -> void:
	## Starts a gesture; with hold > 0 it ends by itself after hold seconds.
	anim.gesture = g
	if hold > 0.0:  # a bound method (not a lambda): the timer is ignored if the actor is freed first
		get_tree().create_timer(hold).timeout.connect(_end_gesture.bind(g))


func _end_gesture(g: String) -> void:
	if anim.gesture == g:
		anim.gesture = ""


func crouch(on: bool) -> void:
	anim.crouching = on


func hold(item: Variant, pose := "show") -> Node3D:
	## An item (a Node3D, or an ItemFx kind for its model) into the right hand, arm posed: see HumanoidAnim.hold.
	var n: Node3D = item if item is Node3D else HumanoidAnim.ItemFx.model(item)
	return anim.hold(n, pose)


func take(item: Node3D, pose := "show") -> void:
	## Coroutine: turn to an item (lying in the world, or held out by someone), step up to it, bend (crouch for
	## the floor), reach, close the hand on it and bring it up to `pose`. The real item, not a copy from nowhere.
	if not is_instance_valid(item):
		return
	var at := item.global_position
	look(item)  # eyes on it the whole way
	await face(at, 0.25)
	var flat := Vector3(at.x, global_position.y, at.z)
	if global_position.distance_to(flat) > 0.8:
		# step up to it, but stop short of the desk / shelf / crate it lies on
		var hip := global_position + Vector3.UP * 0.5
		var stop := flat + (global_position - flat).normalized() * 0.6
		var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(hip, Vector3(at.x, hip.y, at.z), 1))
		if hit and hip.distance_to(hit.position) < hip.distance_to(Vector3(stop.x, hip.y, stop.z)) + 0.35:
			stop = Vector3(hit.position.x, global_position.y, hit.position.z) + (hip - hit.position).normalized() * 0.35
			stop.y = global_position.y
		if global_position.distance_to(stop) > 0.15:
			await walk_to(stop, 1.3)
	var low := at.y - global_position.y < 0.6
	crouch(low)
	gesture("lean" if at.y - global_position.y < 1.0 else "")
	anim.reach_to = item.global_transform * HumanoidAnim.ItemFx.grip(item).affine_inverse()
	anim.hold_pose = "reach"
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(item):
		anim.hold(item, pose)
	else:
		anim.hold_pose = ""
	gesture("")
	crouch(false)
	if pose != "show":
		look(null)
	await get_tree().create_timer(0.35).timeout


func let_go() -> void:
	anim.let_go()
